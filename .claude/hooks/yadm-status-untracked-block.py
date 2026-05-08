#!/usr/bin/env python3
"""PreToolUse guard: block `yadm status -u` (and variants).

Reason: `yadm status -u` (or -uall, --untracked-files) walks the entire
home directory looking for untracked files. On Jason's machine this
takes long enough that it holds the yadm index lock and blocks
subsequent yadm commands. The default `yadm status` (no -u) is fine.

Uses shlex to tokenize the command so we don't false-positive on
substrings inside quoted arguments (e.g., a commit message that
mentions "yadm status -u").

See ~/.claude/CLAUDE.md — "Yadm".
"""
import json
import shlex
import sys

SHELL_SEPARATORS = {"|", "||", "&", "&&", ";", "(", ")", "{", "}"}


def is_blocked(tokens):
    """Walk tokens, watching for `yadm status` followed by an -u flag
    in the same command segment (separators reset state)."""
    i = 0
    while i < len(tokens):
        if tokens[i] in SHELL_SEPARATORS:
            i += 1
            continue
        if tokens[i] == "yadm" and i + 1 < len(tokens) and tokens[i + 1] == "status":
            j = i + 2
            while j < len(tokens) and tokens[j] not in SHELL_SEPARATORS:
                tok = tokens[j]
                if tok == "-u" or tok.startswith("-u") and tok[2:].isalpha():
                    return True
                if tok == "--untracked-files" or tok.startswith("--untracked-files="):
                    return True
                j += 1
            i = j
            continue
        i += 1
    return False


def main():
    payload = json.load(sys.stdin)
    if payload.get("tool_name") != "Bash":
        return 0
    cmd = payload.get("tool_input", {}).get("command", "")
    if not cmd:
        return 0

    try:
        tokens = shlex.split(cmd, comments=False, posix=True)
    except ValueError:
        # Unparseable (unbalanced quotes, etc.) — let it through; bash
        # will reject it anyway. We only want to block well-formed
        # commands that we understand.
        return 0

    if is_blocked(tokens):
        sys.stderr.write(
            "BLOCKED: `yadm status -u` (or --untracked-files) is forbidden.\n"
            "\n"
            "It walks the entire home directory and holds yadm's index lock\n"
            "long enough to block other yadm commands. Use plain `yadm status`\n"
            "instead (it already shows tracked changes), or `yadm ls-files` /\n"
            "`yadm add -n` to check whether a specific path is tracked.\n"
            "\n"
            f"Command: {cmd}\n"
        )
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
