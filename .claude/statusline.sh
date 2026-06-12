#!/bin/bash

# Enhanced Claude Code status line with git information
input=$(cat)

# Format a raw token count for display: 84000 -> 84k, 1000000 -> 1.0M
fmt_tokens() {
    awk -v n="$1" 'BEGIN { if (n >= 1000000) printf "%.1fM", n/1000000; else printf "%.0fk", n/1000 }'
}

# Separator drawn between status groups
sep=$(printf " \033[90m|\033[0m ")

# Extract data from JSON input
# Strip any trailing "(... context)" suffix; the window size is shown in the token section
model_name=$(echo "$input" | jq -r '.model.display_name' | sed -E 's/ *\([^)]*context[^)]*\)$//')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir')
version=$(echo "$input" | jq -r '.version')
output_style=$(echo "$input" | jq -r '.output_style.name')

# Context window usage as used/total tokens
percent_raw=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
percent_used=$(awk -v p="$percent_raw" 'BEGIN { printf "%.0f", p }')
context_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
context_info=""
if [ "$context_size" -gt 0 ]; then
    used_tokens=$(awk -v p="$percent_raw" -v s="$context_size" 'BEGIN { printf "%d", (p/100)*s }')
    used_fmt=$(fmt_tokens "$used_tokens")
    size_fmt=$(fmt_tokens "$context_size")
    # Color based on usage: green < 65%, yellow 65-85%, red >= 85%
    if [ "$percent_used" -lt 65 ]; then
        ctx_color=32
    elif [ "$percent_used" -lt 85 ]; then
        ctx_color=33
    else
        ctx_color=31
    fi
    context_info="${sep}$(printf "\033[%sm%s/%s\033[0m" "$ctx_color" "$used_fmt" "$size_fmt")"
fi

# 5-hour usage window (Pro/Max only; present after the first API response)
window_info=""
five_used=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
if [ -n "$five_used" ] && [ -n "$five_reset" ]; then
    # Percentage of the 5-hour quota still available
    remaining=$(awk -v u="$five_used" 'BEGIN { r = 100 - u; if (r < 0) r = 0; printf "%.0f", r }')

    # Time until the window resets
    secs=$((five_reset - $(date +%s)))
    if [ "$secs" -lt 0 ]; then secs=0; fi
    hrs=$((secs / 3600))
    mins=$(((secs % 3600) / 60))
    if [ "$hrs" -gt 0 ]; then
        reset_str="${hrs}h${mins}m"
    else
        reset_str="${mins}m"
    fi

    # Color based on remaining quota: green > 35%, yellow 15-35%, red < 15%
    if [ "$remaining" -ge 35 ]; then
        window_color=32
    elif [ "$remaining" -ge 15 ]; then
        window_color=33
    else
        window_color=31
    fi
    window_info="${sep}$(printf "\033[%sm5h:%d%% left (%s)\033[0m" "$window_color" "$remaining" "$reset_str")"
fi

# Get hostname
hostname=$(hostname -s)

# Format directory display (show last two path components)
display_dir=$(echo "$current_dir" | sed 's|.*/\([^/]*/[^/]*\)$|\1|')

# Git information (if in a git repository)
git_info=""
if [ -d "$current_dir/.git" ] || git -C "$current_dir" rev-parse --git-dir >/dev/null 2>&1; then
    # Get current branch
    branch=$(git -C "$current_dir" branch --show-current 2>/dev/null || git -C "$current_dir" rev-parse --short HEAD 2>/dev/null)

    if [ -n "$branch" ]; then
        # Get git status indicators
        git_status=""

        # Check for uncommitted changes
        if ! git -C "$current_dir" diff-index --quiet HEAD 2>/dev/null; then
            git_status="${git_status}*"
        fi

        # Check for staged changes
        if ! git -C "$current_dir" diff-index --quiet --cached HEAD 2>/dev/null; then
            git_status="${git_status}+"
        fi

        # Check for untracked files
        if [ -n "$(git -C "$current_dir" ls-files --others --exclude-standard 2>/dev/null)" ]; then
            git_status="${git_status}?"
        fi

        # Format git info with yellow color using printf with -e flag
        git_info=$(printf " \033[33m%s%s\033[0m" "$branch" "$git_status")
    fi
fi

# Build version info if available
version_info=""
if [ "$version" != "null" ] && [ -n "$version" ]; then
    version_info=$(printf " \033[90mv%s\033[0m" "$version")
fi

# Build output style info if available
style_info=""
if [ "$output_style" != "null" ] && [ -n "$output_style" ] && [ "$output_style" != "default" ]; then
    style_info=$(printf " \033[35m[%s]\033[0m" "$output_style")
fi

# Output formatted status line using printf with -e flag to interpret escape sequences
printf "\033[1m%s\033[0m%s%s%s\033[34m@%s\033[0m \033[36m%s\033[0m%s%s%s\n" "$model_name" "$context_info" "$window_info" "$sep" "$hostname" "$display_dir" "$git_info" "$version_info" "$style_info"