#!/bin/bash
# PreToolUse guard: block `yadm status -u` (and variants).
#
# Reason: `yadm status -u` (or -uall, --untracked-files) walks the entire
# home directory looking for untracked files. On Jason's machine this
# takes long enough that it holds the yadm index lock and blocks
# subsequent yadm commands. The default `yadm status` (no -u) is fine.
#
# See ~/.claude/CLAUDE.md — "Yadm".

set -u

input="$(cat)"
tool="$(jq -r '.tool_name // empty' <<<"$input")"
[ "$tool" = "Bash" ] || exit 0

cmd="$(jq -r '.tool_input.command // empty' <<<"$input")"
[ -z "$cmd" ] && exit 0

# Match `yadm status` followed by any -u flag form:
#   -u, -uall, -uno, -unormal, --untracked-files[=...]
if echo "$cmd" | grep -qE '\byadm[[:space:]]+status\b[^|;&]*([[:space:]]-u([[:space:]]|$|[a-z])|[[:space:]]--untracked-files)'; then
  cat >&2 <<EOF
BLOCKED: \`yadm status -u\` (or --untracked-files) is forbidden.

It walks the entire home directory and holds yadm's index lock long
enough to block other yadm commands. Use plain \`yadm status\` instead
(it already shows tracked changes), or \`yadm ls-files\` / \`yadm add -n\`
if you specifically need to check whether a path is tracked.

Command: $cmd
EOF
  exit 2
fi

exit 0
