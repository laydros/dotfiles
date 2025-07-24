#!/bin/sh

if [ "$(uname)" = "Darwin" ]; then
    ksdiff --merge --output "$MERGED" "$LOCAL" "$BASE" "$REMOTE"
elif [ "$(uname)" = "Linux" ]; then
    meld "$LOCAL" "$BASE" "$REMOTE" --output="$MERGED"
else
    echo "Unsupported platform: $(uname)"
    exit 1
fi