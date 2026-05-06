#!/bin/bash
# PreToolUse guard for m3db customer data.
#
# Blocks tool calls that would read, list, or walk into numbered
# subdirectories under data/ on the m3db share (any of its mount points):
#   Linux:   /home/m3db/data/<digits>/...
#   macOS:   /Volumes/m3db/data/<digits>/...
#   Windows: H:\data\<digits>\...
#
# Rules:
#   1. Path references a numbered dir — block (exception: stat-only
#      commands like `du -sh`, `stat`, `ls -d` on the specific dir).
#   2. Shell glob expansion under data/ (e.g., /data/*) — block
#      (would fan out into customer dirs).
#   3. Recursive-walking tool (find, grep -r, ls -R, du, rsync, tar,
#      tree, cp -r) targeting /data — block.
#   4. Otherwise allow (incl. bare `ls /home/m3db/data` showing only
#      numbered dir names, which isn't customer data itself).
#
# See project CLAUDE.md section "Customer Data on m3db".

set -u

input="$(cat)"
tool="$(jq -r '.tool_name // empty' <<<"$input")"

case "$tool" in
  Bash)
    target="$(jq -r '.tool_input.command // empty' <<<"$input")"
    ;;
  Read)
    target="$(jq -r '.tool_input.file_path // empty' <<<"$input")"
    ;;
  Glob)
    target="$(jq -r '[.tool_input.pattern, .tool_input.path] | map(select(. != null and . != "")) | join(" ")' <<<"$input")"
    ;;
  Grep)
    target="$(jq -r '[.tool_input.path, .tool_input.pattern] | map(select(. != null and . != "")) | join(" ")' <<<"$input")"
    ;;
  *)
    exit 0
    ;;
esac

[ -z "$target" ] && exit 0

NUMBERED_RE='(/home/m3db|/Volumes/m3db)/data/[0-9]|[Hh]:[/\]+data[/\]+[0-9]'
DATA_ROOT_RE='(/home/m3db|/Volumes/m3db)/data($|[[:space:]]|/|["'"'"'])|[Hh]:[/\]+data($|[[:space:]]|[/\])'
GLOB_FANOUT_RE='[/\]+data[/\]+[^[:space:]|;&"'"'"']*\*|[/\]+data[/\]+\*'

has_glob_fanout() { echo "$1" | grep -qE "$GLOB_FANOUT_RE"; }

is_stat_only() {
  local t="$1"
  has_glob_fanout "$t" && return 1
  echo "$t" | grep -qE '\bdu[[:space:]]+(-[A-Za-rt-zA-RT-Z]*s[A-Za-rt-zA-RT-Z]*|--summarize)\b' && return 0
  echo "$t" | grep -qE '\bstat[[:space:]]' && return 0
  echo "$t" | grep -qE '\bls[[:space:]]+[^|;&]*-[A-Za-z]*d\b' && return 0
  return 1
}

is_recursive_walk() {
  local t="$1"
  echo "$t" | grep -qE '\b(find|tree|rsync|tar|cpio)\b' && return 0
  echo "$t" | grep -qE '\b(grep|rgrep)[[:space:]]+[^|;&]*-[A-Za-z]*[rR]' && return 0
  echo "$t" | grep -qE '\bls[[:space:]]+[^|;&]*-[A-Za-z]*R' && return 0
  echo "$t" | grep -qE '\b(cp|mv|rm|chown|chmod|chgrp)[[:space:]]+[^|;&]*-[A-Za-z]*[rR]' && return 0
  if echo "$t" | grep -qE '\bdu[[:space:]]+'; then
    echo "$t" | grep -qE '\bdu[[:space:]]+(-[A-Za-rt-zA-RT-Z]*s[A-Za-rt-zA-RT-Z]*|--summarize)\b' || return 0
  fi
  return 1
}

block() {
  cat >&2 <<EOF
BLOCKED by m3db customer-data guard: $1

Target: $target

Allowed: directory-level size/stat on a specific numbered dir (e.g.,
\`du -sh /home/m3db/data/12345\`, \`stat\`, \`ls -d\`). Not allowed:
listing or reading contents, /data/* glob fanout, or recursive walks
of /data root.

See project CLAUDE.md — "Customer Data on m3db".
EOF
  exit 2
}

if echo "$target" | grep -qE "$NUMBERED_RE"; then
  if [ "$tool" = "Bash" ] && is_stat_only "$target"; then
    exit 0
  fi
  block "path references numbered m3db customer-data subdirectory"
fi

if [ "$tool" = "Bash" ] && has_glob_fanout "$target"; then
  if echo "$target" | grep -qE "$DATA_ROOT_RE"; then
    block "glob fanout under m3db data/ would expand into customer subdirs"
  fi
fi

if [ "$tool" = "Bash" ] && echo "$target" | grep -qE "$DATA_ROOT_RE"; then
  if is_recursive_walk "$target"; then
    block "recursive walk at m3db data/ root would descend into customer subdirs"
  fi
fi

exit 0
