# Hammerspoon window controls

- Hold Cmd+Shift and left-drag anywhere inside a regular window to move it.
- Hold Cmd+Shift and right-drag to resize from the nearest edge/corner.
  A grab in the center resizes from the bottom-right corner.
- Ctrl+Option+Shift+Left/Right moves the focused window to the previous/next
  regular Desktop on its display and follows it. No wrapping at the ends.
- Change FOLLOW in init.lua to false to move without following.

Hammerspoon needs Accessibility permission. Reload Config after editing.
Space movement briefly opens Mission Control and waits for shortcut modifiers
 to be released. Fullscreen windows and windows assigned to All Desktops
are excluded. Avoid using the mouse while a Space move is in progress.
Failures appear as alerts and in the Hammerspoon Console.

## macOS 27 compatibility

The built-in hs.spaces.moveWindowToSpace can return success without moving a
window, and hs.spaces.gotoSpace uses an outdated Mission Control tree.
mission_control.lua is the standalone helper from PaperWM.spoon; this config
loads only that helper and does not enable PaperWM's tiling window manager.

Upstream: https://github.com/mogenson/PaperWM.spoon
Fix: https://github.com/mogenson/PaperWM.spoon/pull/174
Downloaded 2026-10-23 from the release branch, mission_control.lua.
The helper is unmodified. License: LICENSE.PaperWM (MIT).
SHA-256: 6241a6579baf1d997cd26524337e89e61960ff34b8532b76db4342b18d2e0c8a

The hs.ipc module is enabled for local diagnostics using the installed hs CLI.
