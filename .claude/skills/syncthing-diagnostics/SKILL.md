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

and **zero patterns in effect**. On Synctrain (iOS) it is worse: the folder stops
pulling entirely, so the shared file can never arrive, and editing the patterns in the
app keeps erroring (2026-10-07). Remove the folder on the device, which sends no
deletions to other devices, and re-add it.

The working sequence: accept the folder with **no patterns**, let it reach 100%, then
add the one-line include. Confirm `expanded` is non-zero and `error` is null.

That is only safe when every existing host reads `globalFiles == localFiles` for the
folder. A fresh folder computes "need" from the global index rather than from who is
actually offering, so if the index holds entries no device will serve, it queues them
and parks there. Clear those first (see the trap section below), or paste the literal
patterns for the first sync instead.
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

A rule added to a shared pattern file reaches every device that includes it at once.
If the plan is delete-then-ignore, do the delete **before** touching the shared file,
or the receiving devices ignore the path first and their delete writes no tombstone.

### Two blocked-delete errors that need opposite fixes

Read the error string:

- `...but contains ignored files (see ignore documentation for (?d) prefix)`: the
  contents are ignored **locally**. A `(?d)` prefix on the pattern fixes it.
- `...but is not empty; the contents are probably ignored on that remote device, but
  not locally`: the contents are live **here**. `(?d)` does nothing. Delete the real
  files locally while their entries are still valid, which writes the child tombstones
  the ignoring remote could not.

A file pattern like `*.db` never matches a directory, so a remote can tombstone a
directory while the files inside it stay alive in the global index. That produces the
second error.

### Stuck index entries

An entry gets stuck when every device that could delete it has it ignored. An ignored
entry is `invalid`: a parked record, not a claim to hold the file, so deleting it there
writes no tombstone. Ways out, in order of preference:

1. **Delete on a device whose entry is still valid.** That writes a real tombstone that
   wins everywhere. Find candidates in the file's `availability` list from
   `/rest/db/file`, then confirm on the device itself that its entry is valid:
   `availability` shows what a device last announced, not what is on its disk, and an
   invalid entry cannot be served even when it is listed.
2. **Open a window on one device.** Put `!/path/to/file` negations *above* the
   `#include` in that device's local `.stignore`, rescan so the on-disk file becomes
   valid, delete it, then restore the plain include. Un-ignoring only works while the
   files are still on disk; un-ignoring after they are gone makes Syncthing conclude it
   needs them.
3. **Remove the device sustaining the entry from the folder.** A device's index data
   for the folder is dropped when it leaves, along with any entry only it sustained.
   This can also roll back tombstones that only that device holds, so let the index
   settle first.

While a cleanup is in progress, keep one device with no ignore patterns for the folder.
It is the only device that can still write tombstones.

An entry only strands when some device, usually an offline one, still holds a valid
copy. When every device holding a file ignores it at once, the global entry simply
disappears.

### Deleted files that come back

A device carrying a stale copy can re-announce files deleted elsewhere. If the folder
holds a git repo that auto-commits, the resurrection gets committed and looks
authoritative. The signature is concurrent version vectors that never resolve while both
hosts report idle and converged with different file counts. Diff the two hosts'
`/rest/db/browse?levels=-1` trees to find the files.

### Secrets that synced

When adding a rule to stop secrets syncing, search the folder for the actual key values
(`find ... | xargs grep -F -f <file of values>`), not just the file names. A rule
anchored to the folder root (`/.env*`) misses copies deeper down, and BSD `grep -r`
has silently missed matches. Delete the files first, then add the rule. Then check
`.stversions` on every device with versioning: a receiving device archives what you
delete.

## Reporting

Give per-folder `needFiles` / `needDeletes` / `needBytes` / `errors` for each host, the
folder types before and after, and name the device responsible when there is one.

Two measurement traps worth stating honestly rather than papering over:

- On macOS, `df` will not show space freed by `rm -rf` while Time Machine local
  snapshots still reference the blocks (`tmutil listlocalsnapshots /`). Report the
  measured directory size and say the free-space figure lags.
- A `0` from a command that did not actually run reads the same as a real zero. Confirm
  the query returned data before reporting an absence.
