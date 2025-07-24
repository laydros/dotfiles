#!/bin/sh

# Git diff wrapper to choose ksdiff on macOS, meld on Linux
if [ "$(uname)" = "Darwin" ]; then
    # macOS - use Kaleidoscope
    ksdiff --partial-changeset --relative-path \"$MERGED\" -- \"$LOCAL\" \"$REMOTE\"
elif [ "$(uname)" = "Linux" ]; then
    # Linux - use Meld
    meld "$LOCAL" "$REMOTE"
else
    echo "Unsupported platform: $(uname)"
    exit 1
fi
