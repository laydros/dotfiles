#!/usr/bin/env bash

# VS Code Extension Sync Script
#
# Usage:
# - Installs missing VS Code extensions listed in the Brewfile.
# - Removes unlisted VS Code extensions.
#
# Notes:
# - Works cross-platform (macOS & Linux).
# - Extracts `vscode` entries from Brewfile-core and the OS-specific Brewfile.

PREVIEW=0
[[ "$1" == "--preview" ]] && PREVIEW=1

BREWFILE_DIR=~/.config/brew

# Determine the OS-specific Brewfile
if [[ "$(uname)" == "Darwin" ]]; then
    OS_BREWFILE="$BREWFILE_DIR/Brewfile-mac"
elif [[ "$(uname)" == "Linux" ]]; then
    OS_BREWFILE="$BREWFILE_DIR/Brewfile-linux"
else
    echo "Unsupported OS. Exiting."
    exit 1
fi

# Gather desired extensions from both core + OS-specific Brewfiles
brewfile_extensions=$(grep "^vscode " "$BREWFILE_DIR"/Brewfile-core "$OS_BREWFILE" 2>/dev/null | awk '{print $2}' | tr -d '"')

# Convert to array for safe looping
readarray -t desired_exts <<< "$brewfile_extensions"
readarray -t installed_exts <<< "$(code --list-extensions)"

echo "=== VS Code extensions to install ==="
for ext in "${desired_exts[@]}"; do
    if [[ ! " ${installed_exts[*]} " =~ " ${ext} " ]]; then
        echo "  + $ext"
        ((PREVIEW)) || code --install-extension "$ext"
    fi
done

echo "=== VS Code extensions to uninstall ==="
for ext in "${installed_exts[@]}"; do
    if [[ ! " ${desired_exts[*]} " =~ " ${ext} " ]]; then
        echo "  - $ext"
        ((PREVIEW)) || code --uninstall-extension "$ext"
    fi
done

((PREVIEW)) && echo "Preview mode: no changes made."

echo "VS Code extensions are now in sync with your Brewfile."
