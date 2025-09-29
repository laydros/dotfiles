#!/bin/bash

# Configuration
SMB_PATH="smb://ral/m3db"  # Your exact share path
MOUNT_POINT="/Volumes/m3db"

# Check if mounted
if [[ -d "$MOUNT_POINT" ]]; then
    STATUS="🟢"
    ACTION="Unmount"
else
    STATUS="🔴"
    ACTION="Mount"
fi

# Menu bar display
echo "$STATUS m3db"
echo "---"

# Toggle action
if [ "$1" = "toggle" ]; then
    if [[ -d "$MOUNT_POINT" ]]; then
        # Unmount
        diskutil unmount "$MOUNT_POINT"
        osascript -e 'display notification "m3db Unmounted" with title "Network Drive"'
    else
        # Mount using AppleScript (same as your shortcut)
        osascript <<EOF
tell application "Finder"
    try
        mount volume "$SMB_PATH"
    end try
end tell
EOF
        # Wait a moment for mount to complete
        sleep 2
        osascript -e 'display notification "m3db Mounted" with title "Network Drive"'
    fi
    exit 0
fi

# Menu items
echo "$ACTION m3db | bash='$0' param1=toggle terminal=false"
echo "---"
if [[ -d "$MOUNT_POINT" ]]; then
    echo "Open in Finder | bash='open' param1='$MOUNT_POINT' terminal=false"
fi
echo "---"
echo "Refresh | refresh=true"