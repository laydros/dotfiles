#!/bin/bash
# Apply my macOS settings (Dock, hot corners, Finder, trackpad, Spaces
# shortcuts, Caps Lock -> Control). Run by hand on a new Mac, and again
# after plugging in a new keyboard. Safe to re-run.
#
# The list came from diffing jaguar (years of history) against a fresh
# fender on 2026-09-25. Anything not set here was app state or a macOS
# default.
set -eu

if [ "$(uname -s)" != Darwin ]; then
    echo "macos-defaults: not macOS, nothing to do"
    exit 0
fi

# --- Dock and hot corners ----------------------------------------------
# Corner values: 1 none, 2 Mission Control, 4 Desktop, 14 Quick Note.
defaults write com.apple.dock wvous-tl-corner -int 2
defaults write com.apple.dock wvous-tl-modifier -int 0
defaults write com.apple.dock wvous-tr-corner -int 1
defaults write com.apple.dock wvous-tr-modifier -int 0
defaults write com.apple.dock wvous-bl-corner -int 4
defaults write com.apple.dock wvous-bl-modifier -int 0
defaults write com.apple.dock wvous-br-corner -int 14
defaults write com.apple.dock wvous-br-modifier -int 0

defaults write com.apple.dock tilesize -float 33
defaults write com.apple.dock magnification -bool true
defaults write com.apple.dock largesize -float 82
defaults write com.apple.dock minimize-to-application -bool true
defaults write com.apple.dock mru-spaces -bool false
defaults write com.apple.dock showAppExposeGestureEnabled -bool true

# --- Finder ------------------------------------------------------------
defaults write com.apple.finder FXPreferredViewStyle -string Nlsv
defaults write com.apple.finder FXDefaultSearchScope -string SCcf
defaults write com.apple.finder NewWindowTarget -string PfHm
defaults write com.apple.finder NewWindowTargetPath -string "file://$HOME/"
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true
defaults write com.apple.finder ShowMountedServersOnDesktop -bool true
defaults write com.apple.finder FinderSpawnTab -bool false

# --- Windows and global ------------------------------------------------
defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false
defaults write com.apple.WindowManager EnableTiledWindowMargins -bool false

defaults write -g AppleKeyboardUIMode -int 2
defaults write -g AppleInterfaceStyleSwitchesAutomatically -bool true
defaults write -g NSDocumentSaveNewDocumentsToCloud -bool false
defaults write -g NSNavPanelExpandedStateForSaveMode -bool true
defaults write -g NSNavPanelExpandedStateForSaveMode2 -bool true
defaults write -g PMPrintingExpandedStateForPrint -bool true
defaults write -g PMPrintingExpandedStateForPrint2 -bool true

# --- Trackpad ----------------------------------------------------------
# Tap to click. Look Up stays on Force Click; three-finger tap is off so it
# can't collide with BetterTouchTool's three-finger click = middle click.
for domain in com.apple.AppleMultitouchTrackpad com.apple.driver.AppleBluetoothMultitouch.trackpad; do
    defaults write "$domain" Clicking -bool true
    defaults write "$domain" TrackpadThreeFingerTapGesture -int 0
done
defaults -currentHost write -g com.apple.trackpad.threeFingerTapGesture -int 0
defaults write -g com.apple.trackpad.forceClick -bool true

# --- Spaces shortcuts --------------------------------------------------
# Ctrl+1..5 switch to Desktop 1..5. The desktops themselves must already
# exist (Mission Control); these only bind the keys.
# Args: symbolic hotkey ID, virtual key code.
set_space_hotkey() {
    defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "$1" \
        "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>65535</integer><integer>$2</integer><integer>262144</integer></array><key>type</key><string>standard</string></dict></dict>"
}
set_space_hotkey 118 18 # 1
set_space_hotkey 119 19 # 2
set_space_hotkey 120 20 # 3
set_space_hotkey 121 21 # 4
set_space_hotkey 122 23 # 5

# --- Keyboard remaps ---------------------------------------------------
# Stored per keyboard in -currentHost -g. System Settings names the key
# either <vendor>-<product>-0 or alt_handler_id-<n>, and not predictably,
# so write both. A key that matches no device is ignored.
# HID usages (0x7000000xx): 39 Caps Lock, e0 L-Ctrl, e2 L-Opt, e3 L-Cmd,
# e6 R-Opt, e7 R-Cmd.
CAPS_TO_CTRL='<dict><key>HIDKeyboardModifierMappingSrc</key><integer>30064771129</integer><key>HIDKeyboardModifierMappingDst</key><integer>30064771296</integer></dict>'
# PC layout: swap Option and Command so the key next to space is Command.
PC_SWAP='<dict><key>HIDKeyboardModifierMappingSrc</key><integer>30064771298</integer><key>HIDKeyboardModifierMappingDst</key><integer>30064771299</integer></dict>
<dict><key>HIDKeyboardModifierMappingSrc</key><integer>30064771299</integer><key>HIDKeyboardModifierMappingDst</key><integer>30064771298</integer></dict>
<dict><key>HIDKeyboardModifierMappingSrc</key><integer>30064771302</integer><key>HIDKeyboardModifierMappingDst</key><integer>30064771303</integer></dict>
<dict><key>HIDKeyboardModifierMappingSrc</key><integer>30064771303</integer><key>HIDKeyboardModifierMappingDst</key><integer>30064771302</integer></dict>'

# Keyboards that need the PC swap, as <vendor>-<product>.
PC_KEYBOARDS="12815-20548"

is_pc_keyboard() {
    case " $PC_KEYBOARDS " in *" $1 "*) return 0 ;; esac
    return 1
}

# Args: key suffix, <vendor>-<product>.
set_keymap() {
    if is_pc_keyboard "$2"; then
        # shellcheck disable=SC2086 # one array element per line
        (IFS='
'; defaults -currentHost write -g "com.apple.keyboard.modifiermapping.$1" -array "$CAPS_TO_CTRL" $PC_SWAP)
    else
        defaults -currentHost write -g "com.apple.keyboard.modifiermapping.$1" -array "$CAPS_TO_CTRL"
    fi
    echo "keyboard $1: Caps Lock -> Control$(is_pc_keyboard "$2" && echo ', Option/Command swapped')"
}

# Known keyboards get their entry even when unplugged.
for kb in $PC_KEYBOARDS; do
    set_keymap "$kb-0" "$kb"
done

# Attached keyboards: one "vendor product alt_handler_id" line each.
ioreg -r -c AppleHIDKeyboardEventDriverV2 -l | awk '
    /^\+-o/ { if (seen) print v, p, a; v = ""; p = ""; a = ""; seen = 1 }
    /"VendorID" = /       { v = $NF }
    /"ProductID" = /      { p = $NF }
    /"alt_handler_id" = / { a = $NF }
    END { if (seen) print v, p, a }
' | while read -r vendor product handler; do
    [ -n "$vendor" ] && [ -n "$product" ] || continue
    set_keymap "$vendor-$product-0" "$vendor-$product"
    [ -z "$handler" ] || set_keymap "alt_handler_id-$handler" "$vendor-$product"
done

# --- Apply -------------------------------------------------------------
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
killall Dock Finder 2>/dev/null || true

echo "Done. Keyboard remaps and trackpad changes may need a logout to take effect."
