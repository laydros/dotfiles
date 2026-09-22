---
name: syncthing-diagnostics
description: Diagnose Syncthing sync problems via the REST API - a device stuck "out of sync", items that never transfer, folders that disagree about what exists, ignore patterns that are not taking effect, and receive-only folders holding local changes. Use whenever a Syncthing folder or device is not converging, before changing any configuration.
---

# Syncthing diagnostics

Read-only investigation first. Do not change folder types, run Override or Revert,
or delete anything until the cause is named and the user has agreed.

## Setup

The config directory differs per platform:

| Platform | Path |
|---|---|
| macOS | `~/Library/Application Support/Syncthing` |
| Linux (modern) | `~/.local/state/syncthing` |
| Linux (older) | `~/.config/syncthing` |

```bash
KEY=$(grep -o '<apikey>[^<]*' "<configdir>/config.xml" | sed 's/<apikey>//')
curl -s -H "X-API-Key: $KEY" http://127.0.0.1:8384/rest/system/status
```

For a remote host, copy a script over with `scp` and run it. Do **not** interpolate
filenames into `ssh "...$F..."` — the local shell eats them and `/rest/db/file`
answers `No such object in the index`, which reads exactly like a real finding.
Single-quote the whole remote command, or send a script.

## Step 1 — get both sides before theorising

Never diagnose from one host. Collect, for every host involved:

```bash
curl -s -H "X-API-Key: $KEY" /rest/config/folders          # id, label, type, path, devices
curl -s -H "X-API-Key: $KEY" /rest/db/status?folder=<id>   # that host's own view
curl -s -H "X-API-Key: $KEY" /rest/system/connections      # connected, clientVersion
curl -s -H "X-API-Key: $KEY" /rest/system/error
curl -s -H "X-API-Key: $KEY" /rest/folder/errors?folder=<id>
```

Compare `globalFiles` for the same folder across hosts. If they differ, the hosts
disagree about what exists and the rest of this skill applies.

## Step 2 — read the out-of-sync number correctly

The UI's per-device "out of sync items" is **`needItems + needDeletes`**, from:

```bash
curl -s -H "X-API-Key: $KEY" "/rest/db/completion?folder=<id>&device=<devid>"
```

Only the total is displayed. A count dominated by `needDeletes` looks like missing
files when it is really pending *deletions*. Always print the fields separately.

`/rest/db/completion` is **this host's opinion about that remote**. The remote's own
`/rest/db/status` can say `needFiles=0, needDeletes=0` at the same time. That is not a
contradiction — each host answers about its own index, and indexes diverge.

## Step 3 — diff the trees

```bash
# on each host
cd <folder path> && find . -type f | sed 's|^\./||' | sort > /tmp/host.txt
comm -13 a.txt b.txt   # only on B
comm -23 a.txt b.txt   # only on A
```

Bucket the difference by top-level directory (`awk -F/ '{print $1"/"}' | sort | uniq -c`)
before reading individual paths. One directory usually explains almost all of it.

Expect `.stversions/` to account for large one-sided counts — that is Syncthing's own
versioning archive of files it already deleted, not missing data.

## Step 4 — name the cause with version vectors

For one disputed path, on **both** hosts:

```bash
curl -s -H "X-API-Key: $KEY" --get \
  --data-urlencode "folder=<id>" --data-urlencode "file=<path>" \
  http://127.0.0.1:8384/rest/db/file
```

Read `global.version`, `global.deleted`, `global.modifiedBy`.

- **One vector is a superset of the other** — normal propagation, just not finished.
  Check connectivity and whether the folder is paused.
- **Concurrent vectors** (neither contains the other) — a conflict. The extra
  `DEVID:counter` term that one side has and the other lacks **names the device that
  caused it**. Typically a device that was offline with a stale index came back and
  re-announced files another device had deleted.
- **A conflict involving a device that is offline cannot resolve.** It stays stuck
  forever and the out-of-sync count never clears.

Sample ~20 paths spread across the difference (`awk 'NR%N==1'`), not one, and confirm
the same `DEVID:counter` appears throughout. An identical counter across many files
means a single bulk event.

Check `lastSeen` in `/rest/system/connections`: the zero value
`0001-01-01T00:00:00Z` means that device has **never** connected to this host.

## Step 5 — check ignores are actually loaded

```bash
curl -s -H "X-API-Key: $KEY" "/rest/db/ignores?folder=<id>"
```

`expanded` empty while the folder has patterns on disk means **nothing is being
ignored**. The usual cause:

> **`.stignore` does not sync. `#include` is read only from `.stignore`.**

A shared pattern file (`.stignore-shared`) propagates as ordinary content, but each
device still needs its own one-line `.stignore` containing `#include .stignore-shared`.
Miss it on one device and that device ignores nothing — and syncs everything the
patterns were meant to exclude. Verify per device, never assume.

Compare `expanded` counts across hosts; they should match.

### Adding a device (including iOS) to a folder that uses a shared pattern file

**Do not put `#include .stignore-shared` on a device before that file has synced.**
Verified 2026-09-22: pointing `#include` at a file that is not there yet gives

```
parse error: failed to load include file .stignore-shared: file not found
```

and **zero patterns in effect**. The folder starts normally and ignores nothing, which
is the exact outcome the include was meant to prevent. On a fresh folder the shared file
cannot be present yet, so the include is a chicken-and-egg.

Paste the literal patterns into the new device's ignore list for the first sync, then
switch to the one-line include once the shared file has arrived. Confirm `expanded` is
non-zero and `error` is null before trusting either form.

Related: **set ignores before the first sync, never after.** A fresh folder computes
"need" from the global index rather than from who is actually offering, so with no
ignores it will queue files no connected device will serve and park there.
 Order matters — Syncthing
takes the first matching pattern, which is why keeping rules in one shared file is
what keeps behaviour identical everywhere.

## Step 6 — receive-only folders

```bash
/rest/db/status?folder=<id>   # receiveOnlyChangedFiles / receiveOnlyChangedBytes
```

Non-zero means someone edited a receive-only folder locally. That change can never
propagate out; it sits there and makes the folder permanently "out of sync". Fix it at
the source host and let it sync down, or Revert on the receive-only side.

The mirror case: a **send-only** folder showing `needFiles` is holding a version a
remote pushed that it will never accept. **Override Changes** on the send-only host
re-asserts it as authoritative:

```bash
curl -X POST -H "X-API-Key: $KEY" "/rest/db/override?folder=<id>"
```

Compare content hashes on both sides *before* overriding. If the bytes already match,
only the version vectors differ and nothing can be lost. If they differ, Override
discards the remote's content — confirm with the user first.

## Ignore rules and deletion — the ordering trap

**An ignored file is never deleted.** Add a pattern for something already synced and
every existing copy freezes on every device, permanently, and Syncthing will no longer
remove them.

- To purge *and* ignore: **delete first, let the tombstones propagate, then add the
  pattern.** In that order.
- Or prefix the pattern with `(?d)`: `(?d).DS_Store` marks matches as deletable, so
  Syncthing may remove them rather than protecting them.

Deleting files while a folder is still shared propagates the deletion to every device.
To retire a folder locally: **remove it from the config first, verify it is gone, then
delete from disk.** Never the reverse.

```bash
curl -X DELETE -H "X-API-Key: $KEY" /rest/config/folders/<id>
curl -s -o /dev/null -w "%{http_code}\n" -H "X-API-Key: $KEY" /rest/config/folders/<id>  # expect 404
grep -c '<id>' <configdir>/config.xml                                                     # expect 0
```

Back up `config.xml` outside any synced folder before editing config.

## Reporting

Give per-folder `needFiles` / `needDeletes` / `needBytes` / `errors` for each host, the
folder types before and after, and name the device responsible when there is one.

Two measurement traps worth stating honestly rather than papering over:

- On macOS, `df` will not show space freed by `rm -rf` while Time Machine local
  snapshots still reference the blocks (`tmutil listlocalsnapshots /`). Report the
  measured directory size and say the free-space figure lags.
- A `0` from a command that did not actually run reads the same as a real zero. Confirm
  the query returned data before reporting an absence.
