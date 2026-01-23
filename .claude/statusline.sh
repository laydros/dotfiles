#!/bin/bash

# Enhanced Claude Code status line with git information
input=$(cat)

# Extract data from JSON input
model_name=$(echo "$input" | jq -r '.model.display_name')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir')
version=$(echo "$input" | jq -r '.version')
output_style=$(echo "$input" | jq -r '.output_style.name')

# Context window usage - use pre-calculated percentage for accuracy
percent_used=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | awk '{printf "%.0f", $1}')
context_info=""
if [ "$percent_used" != "0" ]; then
    # Color based on usage: green < 65%, yellow 65-85%, red >= 85%
    if [ "$percent_used" -lt 65 ]; then
        context_info=$(printf " \033[32m%d%%\033[0m" "$percent_used")
    elif [ "$percent_used" -lt 85 ]; then
        context_info=$(printf " \033[33m%d%%\033[0m" "$percent_used")
    else
        context_info=$(printf " \033[31m%d%%\033[0m" "$percent_used")
    fi
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
printf "\033[1m%s\033[0m%s \033[32m@%s\033[0m \033[36m%s\033[0m%s%s%s\n" "$model_name" "$context_info" "$hostname" "$display_dir" "$git_info" "$version_info" "$style_info"