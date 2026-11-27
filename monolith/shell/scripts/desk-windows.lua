-- Desktop mode on Hyprland: windows behave like KDE Plasma's (KWin's defaults, from its kwin.kcfg).
--   · snapping to the screen's edges and to other windows within 10 px
--   · dragging a window to the screen's left or right edge tiles it to that half, to a corner (the
--     outer quarter of an edge) to that quarter, to the top edge maximises it; an outline shows
--     where it will go once the pointer has been there 75 ms, and letting go puts it there
--   · dragging a tiled window away gives it back the size it had, under the pointer where you hold it
--   · a right click on a title bar opens the window's menu (the shell's status/WindowMenu.qml)
-- Loaded by core/Desk.qml (hyprctl eval, dofile) with MonolithDesk.kdeCfg set: { ipc, bars, noBar }.
-- Hyprland tells Lua nothing while a window is dragged: two binds on the left button that pass every
-- click on (non_consuming) say when it goes down and up, and a timer runs only between the two.

local D = MonolithDesk
local cfg = D.kdeCfg or {}

local function log(...) if D.log then D.log(string.format(...)) end end
local function addr(w) local a = tostring(w.address); if a:sub(1, 2) ~= "0x" then a = "0x" .. a end; return a end
local function xy(v) if type(v) == "table" then return (v.x or v[1] or 0), (v.y or v[2] or 0) end; return 0, 0 end
local function num(v, d) local n = tonumber(v); if n then return n end; if type(v) == "table" then return tonumber(v.top or v[1]) or d end; return d end

hl.config({ general = { snap = { enabled = true, window_gap = 10, monitor_gap = 10, border_overlap = false } } })

-- a screen's working area, logical pixels: what the bar and docks leave
local function area(m)
  local s = m.scale or 1
  local lw, lh = (m.width or 0) / s, (m.height or 0) / s
  if type(m.mode) == "table" and (m.mode.width or 0) > 0 then lw, lh = m.mode.width, m.mode.height end
  if (m.transform or 0) % 2 == 1 and lw > lh then lw, lh = lh, lw end
  local mx, my = m.x, m.y
  if mx == nil and type(m.position) == "table" then mx, my = m.position.x, m.position.y end
  local r = m.reserved or {}
  return (mx or 0) + (r.left or 0), (my or 0) + (r.top or 0), lw - (r.left or 0) - (r.right or 0), lh - (r.top or 0) - (r.bottom or 0), mx or 0, my or 0, lw, lh
end

-- what a window wears around itself: its border, and a title bar above it (the hyprbars plugin)
local function hasBar(w)
  if not cfg.bars then return false end
  local c = string.lower(tostring(w.class or ""))
  for _, n in ipairs(cfg.noBar or {}) do if n == c then return false end end
  return true
end
local function frame(w)
  local b = num(hl.get_config("general.border_size"), 0)
  local bh = hasBar(w) and (num(hl.get_config("plugin:hyprbars:bar_height"), 34)) or 0
  return b, bh
end

-- the zone under the pointer at a screen's edge: left, right, top, tl, tr, bl, br, or nil
local function zoneAt(cx, cy, m)
  local _, _, _, _, mx, my, mw, mh = area(m)
  local e = 2
  local L, R, T, B = cx <= mx + e, cx >= mx + mw - 1 - e, cy <= my + e, cy >= my + mh - 1 - e
  local qx, qy = mw * 0.25, mh * 0.25
  if L then if cy < my + qy then return "tl" elseif cy > my + mh - qy then return "bl" end; return "left" end
  if R then if cy < my + qy then return "tr" elseif cy > my + mh - qy then return "br" end; return "right" end
  if T then if cx < mx + qx then return "tl" elseif cx > mx + mw - qx then return "tr" end; return "top" end
  if B then if cx < mx + qx then return "bl" elseif cx > mx + mw - qx then return "br" end end
  return nil
end

-- where a zone puts a window (its outer box, title bar and border included)
local GAP = 6
local function zoneBox(z, m)
  local x, y, w, h = area(m)
  x, y, w, h = x + GAP, y + GAP, w - 2 * GAP, h - 2 * GAP
  local hw, hh = math.floor((w - GAP) / 2), math.floor((h - GAP) / 2)
  if z == "top" then return x, y, w, h end
  if z == "left" then return x, y, hw, h end
  if z == "right" then return x + w - hw, y, hw, h end
  if z == "tl" then return x, y, hw, hh end
  if z == "tr" then return x + w - hw, y, hw, hh end
  if z == "bl" then return x, y + h - hh, hw, hh end
  if z == "br" then return x + w - hw, y + h - hh, hw, hh end
end

local function ipc(...)
  if not cfg.ipc or cfg.ipc == "" then return end
  local a = { "quickshell", "ipc", "-p", string.format("%q", cfg.ipc), "call", "desk" }
  for _, v in ipairs({ ... }) do a[#a + 1] = string.format("%q", tostring(v)) end
  hl.exec_cmd(table.concat(a, " "))
end

-- (loaded again, a new version: the timer made by the one before still ran its code)
if D.dragTimer then D.dragTimer:set_enabled(false); D.dragTimer = nil end

D.tiled = D.tiled or {}      -- address -> { w, h, zone }: the size it had before it was tiled

-- put a window in a zone (also the window menu's "Tile left / right")
function D.tileWin(s, z)
  local w = hl.get_window(s); if not w then return end
  local a = addr(w)
  local cx, cy = xy(w.at); local zw, zh = xy(w.size)
  local ok, m = pcall(hl.get_monitor_at, { x = cx + zw / 2, y = cy + zh / 2 })
  if not ok or type(m) ~= "table" then m = hl.get_monitor_at_cursor and hl.get_monitor_at_cursor() or hl.get_active_monitor() end
  if not D.tiled[a] and (w.fullscreen or 0) == 0 then D.tiled[a] = { w = zw, h = zh } end
  if z == "top" then
    D.tiled[a] = nil
    hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "set", window = s }))
    return
  end
  if (w.fullscreen or 0) ~= 0 then hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "unset", window = s })) end
  local x, y, bw, bh2 = zoneBox(z, m)
  if not x then return end
  local b, bar = frame(w)
  hl.dispatch(hl.dsp.window.resize({ x = math.floor(bw - 2 * b), y = math.floor(bh2 - 2 * b - bar), window = s }))
  hl.dispatch(hl.dsp.window.move({ x = math.floor(x + b), y = math.floor(y + b + bar), window = s }))
  D.tiled[a].zone = z
end

-- ── a drag: from the button going down to it coming up ──
local function stopTimer() if D.dragTimer then D.dragTimer:set_enabled(false) end end
local function tick()
  local d = D.drag
  if not d or not D.on then stopTimer(); return end
  local c = hl.get_cursor_pos(); if not c then return end
  local cx, cy = c.x or c[1], c.y or c[2]
  local w = hl.get_active_window()
  if not w or not w.floating then return end
  local a = addr(w)
  local ax, ay = xy(w.at); local sw, sh = xy(w.size)
  if d.a ~= a then d.a, d.ax, d.ay, d.sw, d.sh, d.cx, d.cy, d.moving = a, ax, ay, sw, sh, cx, cy, false; return end
  if not d.moving then
    -- moving with the pointer, the same size: being dragged (a border being dragged changes its size)
    local dx, dy = ax - d.ax, ay - d.ay
    if math.abs(dx) + math.abs(dy) < 4 or math.abs(sw - d.sw) > 1 or math.abs(sh - d.sh) > 1 then return end
    if math.abs(dx - (cx - d.cx)) > 3 or math.abs(dy - (cy - d.cy)) > 3 then return end
    d.moving = true
    log("drag %s at %s,%s size %sx%s pointer %s,%s tiled %s", a, ax, ay, sw, sh, cx, cy, tostring(D.tiled[a] and D.tiled[a].zone))
    -- a tiled window taken away: the size it had. Hyprland keeps it where you took hold of it
    -- (the pointer, less that spot) for the whole drag and can't be told another spot, so while
    -- it's dragged it stays wide enough to stay under the pointer; let go, it gets its size exactly,
    -- the pointer as far along it as where you held it
    local t = D.tiled[a]
    if t and t.zone then
      D.tiled[a] = nil
      local hx, hy = d.cx - d.ax, d.cy - d.ay
      local nw, nh = math.max(t.w, hx + 24), math.max(t.h, hy + 24)
      hl.dispatch(hl.dsp.window.resize({ x = math.floor(nw), y = math.floor(nh), window = "address:" .. a }))
      if nw ~= t.w or nh ~= t.h then d.fix = { w = t.w, h = t.h, fx = sw > 0 and hx / sw or 0.5, fy = sh > 0 and hy / sh or 0 } end
    end
  end
  local m = hl.get_monitor_at_cursor and hl.get_monitor_at_cursor() or hl.get_active_monitor()
  local z = m and zoneAt(cx, cy, m) or nil
  if z ~= d.cand then d.cand, d.since = z, 0 else d.since = d.since + 1 end
  -- (75 ms there, KWin's ElectricBorderDelay: going past an edge to the next screen shows nothing)
  local shown = (d.cand and d.since >= 4) and d.cand or nil
  if shown ~= d.zone then
    d.zone = shown
    if shown then
      local x, y, bw, bh2 = zoneBox(shown, m)
      ipc("preview", math.floor(x), math.floor(y), math.floor(bw), math.floor(bh2))
    else
      ipc("previewOff")
    end
  end
end

D.tick = tick
-- (nothing here may ever get in the way of a click: every call caught, its error noted)
function D.safe(f) local ok, e = pcall(f); if not ok then log("error: %s", tostring(e)) end end

function D.pDown()
  if not D.on then return end
  D.drag = { since = 0 }
  if not D.dragTimer then D.dragTimer = hl.timer(function() D.safe(D.tick) end, { timeout = 16, type = "repeat" }) else D.dragTimer:set_enabled(true) end
end
function D.pUp()
  local d = D.drag
  D.drag = nil
  stopTimer()
  if d then log("up moving %s zone %s fix %s", tostring(d.moving), tostring(d.zone), tostring(d.fix and d.fix.w)) end
  if not d or not d.moving or not D.on then return end
  local s = "address:" .. d.a
  if d.zone then
    ipc("previewOff")
    if d.fix then D.tiled[d.a] = { w = d.fix.w, h = d.fix.h } end
    D.tileWin(s, d.zone)
  elseif d.fix then
    local w = hl.get_window(s); local c = hl.get_cursor_pos()
    if w and c then
      local _, ay = xy(w.at); local cx, cy = c.x or c[1], c.y or c[2]
      hl.dispatch(hl.dsp.window.resize({ x = math.floor(d.fix.w), y = math.floor(d.fix.h), window = s }))
      hl.dispatch(hl.dsp.window.move({ x = math.floor(cx - d.fix.fx * d.fix.w), y = math.floor(math.min(ay, cy - 8)), window = s }))
    end
  end
end

-- a right click on a window's title bar: its menu, where you clicked
function D.rDown()
  if not D.on or not cfg.bars then return end
  local c = hl.get_cursor_pos(); if not c then return end
  local cx, cy = c.x or c[1], c.y or c[2]
  local bh = num(hl.get_config("plugin:hyprbars:bar_height"), 34)
  local best
  for _, w in ipairs(hl.get_windows() or {}) do
    local special = w.workspace and tostring(w.workspace.name or ""):find("^special")
    if w.mapped ~= false and w.visible ~= false and not special and hasBar(w) then
      local ax, ay = xy(w.at); local zw = select(1, xy(w.size))
      if cx >= ax and cx <= ax + zw and cy >= ay - bh - 2 and cy < ay then
        local mon = w.monitor; local ws = mon and mon.active_workspace
        if not ws or not w.workspace or ws.id == w.workspace.id then
          if not best or (w.focus_history_id or 99) < (best.focus_history_id or 99) then best = w end
        end
      end
    end
  end
  if not best then return end
  ipc("windowMenu", addr(best), math.floor(cx), math.floor(cy), (best.fullscreen or 0) ~= 0, best.pinned == true, tostring(best.title or ""))
end

-- the binds, once per config (a reload clears them)
if not D.kdeReload then D.kdeReload = hl.on("config.reloaded", function() D.kdeBinds = nil end) end
if not D.kdeBinds then
  D.kdeBinds = true
  hl.bind("mouse:272", function() D.safe(D.pDown) end, { non_consuming = true, ignore_mods = true })
  hl.bind("mouse:272", function() D.safe(D.pUp) end, { release = true, non_consuming = true, ignore_mods = true })
  hl.bind("mouse:273", function() D.safe(D.rDown) end, { non_consuming = true, ignore_mods = true })
end
