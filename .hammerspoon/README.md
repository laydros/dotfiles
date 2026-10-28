# Hammerspoon window controls

- Cmd+Shift + left-drag inside a regular window: move it.
- Cmd+Shift + right-drag: resize from the nearest edge/corner.
  A center grab resizes from the bottom-right corner.
- Ctrl+Option+Shift + Left/Right: on arrow release, move the focused window
  to the adjacent Desktop and follow it. The modifiers can stay held.
- Every Desktop switch shows a small "Desktop N" at the top of the main
  screen. Ctrl+1..5 and Ctrl+Option+Left/Right show it as the key is
  pressed; trackpad swipes and app switches show it about a second later,
  when macOS reports the change. Fullscreen Spaces show nothing.

Moving and resizing use mouse-event coordinates and combine rapid pointer
updates at a shared limit of 120 updates per second. Change DRAG_HZ in init.lua
if desired. Releasing the mouse applies the final position immediately.

## Setup on another Mac

1. Install Hammerspoon and allow it in System Settings > Privacy & Security >
   Accessibility.
2. Enable Ctrl+Option+Left/Right as macOS's Move left/right a space shortcuts.
3. With Apple's command-line developer tools installed, build the key sender:

   ```sh
   sh ~/.hammerspoon/native/build.sh
   ```

4. Reload Hammerspoon's config.

The helper executable is built locally and ignored by Git; its C source and
build script are tracked by yadm. Rebuild after changing the C source.

## Moving between Desktops

The helper briefly holds the title-bar strip above the green window button,
sends Ctrl+Option+Arrow, then releases and restores the pointer. It does not
open Mission Control or intentionally nudge the window. The small native key
sender posts through the HID event route, which works on this Mac where
Hammerspoon's built-in keyStroke did not switch Desktops.

Use regular windows on adjacent regular Desktops. Fullscreen windows,
fullscreen destination Spaces, and windows assigned to All Desktops are
excluded. There is no wraparound at the first/last Desktop. Avoid moving the
mouse during the brief title-bar hold. A timeout releases the held button.
Errors appear in the Hammerspoon Console and as alerts.

Keep BTT's matching shortcuts disabled or quit BTT so it does not also handle
the same shortcut. The hs.ipc module enables local diagnostics with the hs CLI.
