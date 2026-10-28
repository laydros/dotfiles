-- =====================================================================
--  Hammerspoon config -- replaces BetterTouchTool (Spaces chords)
--  and Easy Move+Resize (modifier-drag move/resize)
--
--  Install: save this file as ~/.hammerspoon/init.lua
--  Then: Hammerspoon menu bar icon -> Reload Config
--  Hammerspoon needs Accessibility permission (System Settings ->
--  Privacy & Security -> Accessibility) or none of this works.
-- =====================================================================

-- Keep event taps and timers reachable so Lua cannot garbage-collect them.
windowControls = {}
require("hs.ipc") -- enables the installed `hs` CLI for diagnostics
hs.window.animationDuration = 0

local function report(message)
  print("Window controls: " .. tostring(message))
  hs.alert.show(tostring(message))
end

-- ---------------------------------------------------------------------
-- Part 1: Move the focused window one Space left/right
--
--   Ctrl+Opt+Shift+Left / Right   (the chords BTT used to handle)
--
-- Hold the title bar and use Ctrl+Option+Arrow to switch Desktops.
-- This follows the window without opening Mission Control.
-- ---------------------------------------------------------------------

local spaceMovePending = false
local titlebarSpaces = require("titlebar_spaces")

function windowControls.moveFocusedWindowToSpace(direction) -- -1 = left, +1 = right
  if spaceMovePending then return end
  local win = hs.window.focusedWindow()
  if not win or not win:isStandard() or win:isFullScreen() then
    report("Choose a regular, non-fullscreen window first")
    return
  end

  local screen = win:screen()
  if not screen then return end

  -- Native switching acts on the immediately adjacent Space.
  local ordered = hs.spaces.spacesForScreen(screen)
  if not ordered then return end
  local spaces = ordered
  if #spaces < 2 then
    report("This display needs at least two Desktop Spaces")
    return
  end

  -- Which Space is the window on now?
  local winSpaces = hs.spaces.windowSpaces(win)
  if not winSpaces or #winSpaces ~= 1 then
    report("Window must belong to one Desktop (not All Desktops)")
    return
  end

  local index = nil
  for i, id in ipairs(spaces) do
    if id == winSpaces[1] then
      index = i
      break
    end
  end
  if not index then return end -- window is on a fullscreen Space etc.

  local target = spaces[index + direction]
  if not target then
    report("Already at the " .. (direction < 0 and "first" or "last") .. " Desktop")
    return
  end

  if hs.spaces.spaceType(target) ~= "user" then
    report("The adjacent Space is fullscreen; choose an adjacent regular Desktop")
    return
  end

  -- The hotkey release callback starts the move; modifiers may remain held.
  spaceMovePending = true
  local started, err = titlebarSpaces.move(win, target, direction, function(ok, moveError)
    spaceMovePending = false
    windowControls.lastSpaceMove = { success = ok, error = moveError, target = target }
    if not ok then report(moveError or "Could not move window to Desktop") end
  end)
  if not started then
    spaceMovePending = false
    report(err or "Could not start Desktop move")
  end
end

hs.hotkey.bind({ "ctrl", "alt", "shift" }, "left", nil,
  function() windowControls.moveFocusedWindowToSpace(-1) end)
hs.hotkey.bind({ "ctrl", "alt", "shift" }, "right", nil,
  function() windowControls.moveFocusedWindowToSpace(1) end)

-- ---------------------------------------------------------------------
-- Part 2: Easy Move+Resize replacement
--
--   Hold Cmd+Shift and drag anywhere inside a window:
--     left-drag  = move the window
--     right-drag = resize -- the edge/corner nearest where you grabbed
--                  is the one that moves (same 3x3-grid idea as EMR)
--
-- A center grab resizes from the bottom-right corner.
-- ---------------------------------------------------------------------

local DRAG_MODS = { "cmd", "shift" }
local DRAG_HZ = 120 -- shared update limit for moving and resizing
local MIN_W, MIN_H = 60, 60

local drag = nil -- state of the drag in progress, or nil

local function endDrag()
  if windowControls.dragTimer then
    windowControls.dragTimer:stop()
    windowControls.dragTimer = nil
  end
  drag = nil
end

local function windowUnderMouse(mouse)
  local _ = hs.application -- keeps hs.window.orderedWindows() happy
  local pos = hs.geometry.new(mouse)
  return hs.fnutils.find(hs.window.orderedWindows(), function(w)
    -- A window can straddle displays; test its frame, not its main screen.
    return w:isStandard() and not w:isFullScreen() and pos:inside(w:frame())
  end)
end

local function beginDrag(mode, mouse)
  local win = windowUnderMouse(mouse)
  if not win or not win:isStandard() then return false end
  if win:isFullScreen() then return false end
  if mode == "resize" then
    local ax = hs.axuielement.windowElement(win)
    if not ax or not ax:isAttributeSettable("AXSize") then return false end
  end

  local frame = win:frame()
  drag = { win = win, mode = mode, startMouse = mouse, startFrame = frame }

  if mode == "resize" then
    local relX = (mouse.x - frame.x) / frame.w
    local relY = (mouse.y - frame.y) / frame.h
    drag.fromLeft = relX < 1 / 3
    drag.fromRight = relX > 2 / 3
    drag.fromTop = relY < 1 / 3
    drag.fromBottom = relY > 2 / 3
    if not (drag.fromLeft or drag.fromRight or drag.fromTop or drag.fromBottom) then
      drag.fromRight, drag.fromBottom = true, true
    end
  end

  win:focus()
  return true -- swallow the click so the app doesn't also act on it
end

-- Use event coordinates: polling the global cursor during a drag can stay stale.
local function updateDrag(mouse)
  if not drag then return end
  if not drag.win:id() then endDrag(); return end
  local dx = mouse.x - drag.startMouse.x
  local dy = mouse.y - drag.startMouse.y
  local s = drag.startFrame
  local f = { x = s.x, y = s.y, w = s.w, h = s.h }

  if drag.mode == "move" then
    f.x = s.x + dx
    f.y = s.y + dy
  else
    if drag.fromRight then f.w = s.w + dx end
    if drag.fromLeft then
      f.w = s.w - dx
      f.x = s.x + dx
    end
    if drag.fromBottom then f.h = s.h + dy end
    if drag.fromTop then
      f.h = s.h - dy
      f.y = s.y + dy
    end
    if f.w < MIN_W then -- clamp, keeping the opposite edge put
      if drag.fromLeft then f.x = s.x + s.w - MIN_W end
      f.w = MIN_W
    end
    if f.h < MIN_H then
      if drag.fromTop then f.y = s.y + s.h - MIN_H end
      f.h = MIN_H
    end
  end

  if drag.mode == "move" then
    -- Moving must not also resize: Safari is particularly slow on size writes.
    drag.win:setTopLeft({ x = math.floor(f.x), y = math.floor(f.y) })
  else
    -- setFrame performs size/position/size. Most resize grabs only need size.
    drag.win:setSize({ w = math.floor(f.w), h = math.floor(f.h) })
    if drag.fromLeft or drag.fromTop then
      -- Applications may enforce a minimum larger than MIN_W/MIN_H.
      local actual = drag.win:size()
      if drag.fromLeft then f.x = s.x + s.w - actual.w end
      if drag.fromTop then f.y = s.y + s.h - actual.h end
      drag.win:setTopLeft({ x = math.floor(f.x), y = math.floor(f.y) })
    end
  end
end

local function queueDrag(mouse)
  drag.pendingMouse = mouse
  if windowControls.dragTimer then return end
  -- Keep the event tap quick and discard intermediate pointer positions.
  windowControls.dragTimer = hs.timer.doEvery(1 / DRAG_HZ, function()
    if not drag then endDrag(); return end
    local latest = drag.pendingMouse
    drag.pendingMouse = nil
    if latest then updateDrag(latest) end
  end)
end

local et = hs.eventtap.event.types
windowControls.dragTap = hs.eventtap.new(
  { et.leftMouseDown, et.leftMouseDragged, et.leftMouseUp,
    et.rightMouseDown, et.rightMouseDragged, et.rightMouseUp },
  function(event)
    local t = event:getType()
    if t == et.leftMouseDown or t == et.rightMouseDown then
      if not event:getFlags():containExactly(DRAG_MODS) then
        return false
      end
      return beginDrag(t == et.leftMouseDown and "move" or "resize", event:location())

    elseif t == et.leftMouseDragged or t == et.rightMouseDragged then
      if not drag then return false end
      queueDrag(event:location())
      return true

    elseif t == et.leftMouseUp or t == et.rightMouseUp then
      if not drag then endDrag(); return false end
      updateDrag(event:location()) -- apply the final position immediately
      endDrag()
      return true
    end

    return false
  end)
windowControls.dragTap:start()

-- ---------------------------------------------------------------------
-- Part 3: Show the Desktop number after every Desktop switch
--
-- macOS gives no sign of which Desktop you landed on, so this shows
-- "Desktop N" briefly on the main screen. Fullscreen Spaces show nothing.
-- ---------------------------------------------------------------------

local function showDesktopNumber()
  local screen = hs.screen.mainScreen()
  local spaces = screen and hs.spaces.spacesForScreen(screen)
  local current = hs.spaces.focusedSpace()
  if not spaces or not current then return end
  for i, id in ipairs(spaces) do
    if id == current then
      if windowControls.desktopAlert then hs.alert.closeSpecific(windowControls.desktopAlert) end
      windowControls.desktopAlert = hs.alert.show("Desktop " .. i, { textSize = 48 }, screen, 0.8)
      return
    end
  end
end
windowControls.showDesktopNumber = showDesktopNumber

-- The watcher can fire before macOS reports the new Space; a short delay
-- reads the Desktop we landed on, not the one we left.
windowControls.spaceWatcher = hs.spaces.watcher.new(function()
  hs.timer.doAfter(0.15, showDesktopNumber)
end)
windowControls.spaceWatcher:start()

if not hs.accessibilityState() then
  report("Enable Hammerspoon in System Settings > Privacy & Security > Accessibility")
elseif not windowControls.dragTap:isEnabled() then
  report("Mouse listener could not start; check Hammerspoon permissions")
else
  hs.alert.show("Window controls loaded: Cmd+Shift drag")
end
