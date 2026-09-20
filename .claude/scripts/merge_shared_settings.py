#!/usr/bin/env python3
"""Merge the yadm-tracked Claude Code settings into the per-machine settings file.

~/.claude/settings.json is deliberately untracked: Claude Code writes machine-local
state into it (/model, /effort, plugin toggles, permission approvals) and, worse,
auto-mode environment profiles under the `autoMode` key, which can carry internal
hostnames and credential scopes. This dotfiles repo has a public remote.

~/.claude/settings.shared.json is tracked and holds only what should be identical on
every machine: hooks, status line, env, attribution, worktree defaults. This script
folds it into the live file. Shared keys win; everything else in the live file is
left alone.

Merge rules, applied recursively:
  - objects merge key by key
  - arrays and scalars in the shared file replace the local value outright
  - keys only in the local file survive
  - a key removed from the shared file is NOT removed locally; delete it by hand

yadm's post_clone and post_pull hooks run it. To run it by hand:

    python3 ~/.claude/scripts/merge_shared_settings.py

Exit 0 on success (changed or not), 1 on a refusal. It never writes a file it could
not parse, and it writes atomically via a temp file and rename.
"""

import copy
import json
import os
import sys
import tempfile

HOME = os.path.expanduser("~")
SHARED = os.path.join(HOME, ".claude", "settings.shared.json")
LOCAL = os.path.join(HOME, ".claude", "settings.json")


class MergeError(Exception):
    pass


def merge(local, shared):
    """Return a new dict: `local` with `shared` folded in, shared winning."""
    out = copy.deepcopy(local)
    for key, value in shared.items():
        if isinstance(value, dict) and isinstance(out.get(key), dict):
            out[key] = merge(out[key], value)
        else:
            out[key] = copy.deepcopy(value)
    return out


def load_object(path, required):
    if not os.path.exists(path):
        if required:
            raise MergeError(f"missing: {path}")
        return {}
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError) as e:
        raise MergeError(f"cannot parse {path}: {e}") from e
    if not isinstance(data, dict):
        raise MergeError(f"expected a JSON object at top level: {path}")
    return data


def write_atomic(path, data):
    directory = os.path.dirname(path)
    fd, tmp = tempfile.mkstemp(prefix=".settings-", suffix=".tmp", dir=directory)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
            f.write("\n")
        if os.path.exists(path):
            os.chmod(tmp, os.stat(path).st_mode)
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def apply(shared_path=SHARED, local_path=LOCAL):
    """Merge shared into local on disk. Returns True if the local file changed."""
    shared = load_object(shared_path, required=True)
    local = load_object(local_path, required=False)
    merged = merge(local, shared)
    if merged == local and os.path.exists(local_path):
        return False
    write_atomic(local_path, merged)
    return True


def main():
    try:
        changed = apply()
    except MergeError as e:
        print(f"merge_shared_settings: {e}", file=sys.stderr)
        return 1
    print("merge_shared_settings: " + ("updated " if changed else "already current: ") + LOCAL)
    return 0


if __name__ == "__main__":
    sys.exit(main())
