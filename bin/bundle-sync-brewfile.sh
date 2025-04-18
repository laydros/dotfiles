#!/bin/bash

# Brewfile Cross-Platform Installer
#
# Usage:
# 1. Install Homebrew packages based on OS:
#    - macOS: Uses Brewfile-core + Brewfile-mac
#    - Linux: Uses Brewfile-core + Brewfile-linux (excludes macOS-only entries)
#
# 2. Install all listed packages:
#    brew bundle install --cleanup --file=~/.config/brew/Brewfile
#
# 3. Remove unlisted Homebrew packages (except VS Code extensions):
#    brew bundle cleanup --file=~/.config/brew/Brewfile --force && ~/bin/sync-vscode-extensions.sh
#
# 4. Sync VS Code extensions separately:
#    ~/bin/sync-vscode-extensions.sh
#
# 5. Full install, cleanup, and VS Code sync:
#    ./install-brew-packages.sh
#
# Notes:
# - `brew` entries are cross-platform.
# - `cask` and `mas` entries are **macOS-only**.
# - `vscode` extensions are installed separately.
# - The script ensures `mas` and `cask` do not run on Linux.

BREWFILE_DIR=~/.config/brew
BREWFILE_TEMP=/tmp/Brewfile

# Start with the core Brewfile
cp "$BREWFILE_DIR/Brewfile-core" "$BREWFILE_TEMP"

# Append OS-specific packages
if [[ "$(uname)" == "Darwin" ]]; then
    cat "$BREWFILE_DIR/Brewfile-mac" >> "$BREWFILE_TEMP"
elif [[ "$(uname)" == "Linux" ]]; then
    cat "$BREWFILE_DIR/Brewfile-linux" >> "$BREWFILE_TEMP"
    # Ensure robustness by removing macOS-only entries, just in case
    sed -i '/^cask /d' "$BREWFILE_TEMP"
    sed -i '/^mas /d' "$BREWFILE_TEMP"
fi

# Install and clean up using the combined Brewfile
brew bundle install --no-upgrade --cleanup --file="$BREWFILE_TEMP"

# Sync VS Code extensions separately
~/bin/vscode-sync-extensions.sh

# Remove temporary file
rm "$BREWFILE_TEMP"

echo "Brewfile packages installed and VS Code extensions synced."
