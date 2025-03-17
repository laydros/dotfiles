#!/bin/bash

# Define the path to your Brewfile
BREWFILE="$HOME/.config/brew/Brewfile"

# Extract VS Code extensions listed in the Brewfile
brewfile_extensions=$(grep "^vscode " "$BREWFILE" | awk '{print $2}' | tr -d '"')

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
