-- Move windows using a native title-bar hold and the configured Desktop shortcut.
local M = {}
local event = hs.eventtap.event
local types, props = event.types, event.properties
local eventNumber = 40000

function M.move(win, target, direction, callback)
  if M.active then return false, "A Desktop move is already in progress" end
  local buttons = hs.eventtap.checkMouseButtons()
  if buttons.left or buttons.right or buttons.middle then
    return false, "Release the mouse buttons before moving a window between Desktops"
  end
  local frame, screen = win:frame(), win:screen()
  if not screen then return false, "Window has no display" end
  -- Grab the title-bar strip just above the green traffic light, not browser tabs.
  local zoom = win:zoomButtonRect()
  local point
  if zoom then
    point = { x = zoom.x + zoom.w / 2, y = math.max(frame.y + 4, zoom.y - 3) }
  else
    point = { x = frame.x + math.min(80, frame.w / 2), y = frame.y + 5 }
  end
  eventNumber = eventNumber + 1
  local state = {
    cursor = hs.mouse.absolutePosition(), point = point,
    number = eventNumber, held = false, started = hs.timer.secondsSinceEpoch(),
  }
  M.active = state
  M.lastAttempt = state
  state.target = target
  state.source = hs.spaces.activeSpaceOnScreen(screen)

  local function post(kind, dx)
    event.newMouseEvent(kind, state.point):rawFlags(0)
      :setProperty(props.mouseEventNumber, state.number)
      :setProperty(props.mouseEventClickState, 1)
      :setProperty(props.mouseEventDeltaX, dx or 0)
      :setProperty(props.mouseEventDeltaY, 0):post()
  end
  local function release()
    if state.held then
      state.held = false
      post(types.leftMouseUp)
    end
    hs.mouse.absolutePosition(state.cursor)
  end
  local function finish(ok, err)
    if M.active ~= state then return end
    if state.timer then state.timer:stop() end
    if state.watchdog then state.watchdog:stop() end
    pcall(release)
    M.active = nil
    callback(ok, err)
  end
  local function later(delay, fn)
    state.timer = hs.timer.doAfter(delay, function()
      if M.active ~= state then return end
      local ok, err = pcall(fn)
      if not ok then finish(false, tostring(err)) end
    end)
  end
  state.watchdog = hs.timer.doAfter(3, function()
    finish(false, "Desktop switch timed out; mouse released")
  end)

  local function waitForDesktop()
    state.observed = hs.spaces.activeSpaceOnScreen(screen)
    if state.observed == target then
      later(0.15, function()
        release()
        later(0.15, function()
          for _, id in ipairs(hs.spaces.windowSpaces(win) or {}) do
            if id == target then finish(true); return end
          end
          finish(false, "Desktop switched, but the window did not follow the title-bar hold")
        end)
      end)
    elseif hs.timer.secondsSinceEpoch() - state.started > 2 then
      finish(false, "Ctrl+Option+Arrow did not reach the destination Desktop")
    else
      later(0.05, waitForDesktop)
    end
  end

  local ok, err = pcall(function()
    win:focus()
    hs.mouse.absolutePosition(point)
    state.held = true
    post(types.leftMouseDown)
    later(0.08, function()
      later(0.08, function()
        state.task = hs.task.new(hs.configdir .. "/native/space-key", function(code, _, stderr)
          if M.active ~= state then return end
          if code ~= 0 then
            finish(false, "Desktop key sender failed: " .. tostring(stderr))
          else
            later(0.05, waitForDesktop)
          end
        end, { direction < 0 and "left" or "right" })
        if not state.task or not state.task:start() then
          finish(false, "Could not start the native Desktop key sender")
        end
      end)
    end)
  end)
  if not ok then finish(false, tostring(err)) end
  return true
end

return M
