#!/bin/bash

# VS Code Extension Sync Script
#
# Usage:
# - Installs missing VS Code extensions listed in the Brewfile.
# - Removes unlisted VS Code extensions.
#
# Notes:
# - Works cross-platform (macOS & Linux).
# - Extracts `vscode` entries from Brewfile-core and the OS-specific Brewfile.

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

# Extract VS Code extensions from the Brewfiles
brewfile_extensions=$(grep "^vscode " "$BREWFILE_DIR/Brewfile-core" "$OS_BREWFILE" 2>/dev/null | awk '{print $2}' | tr -d '"')

# Get currently installed VS Code extensions
installed_extensions=$(code --list-extensions)

# Install missing extensions
for extension in $brewfile_extensions; do
    if ! echo "$installed_extensions" | grep -q "^$extension$"; then
        echo "Installing VS Code extension: $extension"
        code --install-extension "$extension"
    fi
done

# Uninstall extensions that are not in the Brewfile
for extension in $installed_extensions; do
    if ! echo "$brewfile_extensions" | grep -q "^$extension$"; then
        echo "Uninstalling VS Code extension: $extension"
        code --uninstall-extension "$extension"
    fi
done

echo "VS Code extensions are now in sync with your Brewfile."
