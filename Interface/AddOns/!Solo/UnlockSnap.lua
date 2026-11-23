--[[--------------------------------------------------------------------------
UnlockSnap -- snap pfUI unlock drag to the unlock grid on release.

Stock pfUI only draws the grid (screen width / 128). Unlock now snaps in
DraggerOnDragStop as well (in grid cells); this wrap remains as a
belt-and-suspenders pass after the stock handler. Dock ±1 and typed coords
stay free (already in cells).

Always ConvertFrameAnchor into the seat's logical anchor before snapping:
StartMoving pins TOPLEFT against the screen root, and those GetPoint numbers
must not be stored as BOTTOM/CENTER offsets.
----------------------------------------------------------------------------]]

local unlockWrapped

-- Prefer pfUI.api once loaded; fall back matches DrawGrid's step.
function Solo_GridStep()
  if pfUI and pfUI.api and pfUI.api.GridStep then
    return pfUI.api.GridStep()
  end
  local w = GetScreenWidth()
  if not w or w <= 0 then return 10 end
  return w / 128
end

function Solo_SnapValue(v, step)
  v = tonumber(v)
  step = tonumber(step)
  if not v or not step or step <= 0 then return v end
  return math.floor(v / step + 0.5) * step
end

-- Snap pixel width/height to whole grid cells (returns pixels).
function Solo_SnapSize(w, h)
  local step = Solo_GridStep()
  return Solo_SnapValue(w, step), Solo_SnapValue(h, step)
end

local function PixelToGrid(px)
  if pfUI and pfUI.api and pfUI.api.PixelToGrid then
    return pfUI.api.PixelToGrid(px)
  end
  local step = Solo_GridStep()
  return (tonumber(px) or 0) / step
end

local function GridToPixel(n)
  if pfUI and pfUI.api and pfUI.api.GridToPixel then
    return pfUI.api.GridToPixel(n)
  end
  return (tonumber(n) or 0) * Solo_GridStep()
end

local function LogicalAnchor(frame)
  if frame.pfAnchor then
    if frame.pfAnchor == "CENTERBOTTOM" then return "BOTTOM" end
    return frame.pfAnchor
  end
  local name = frame.GetName and frame:GetName()
  local cfg = name and pfUI_config and pfUI_config.position and pfUI_config.position[name]
  local anchor = (cfg and cfg.anchor) or "TOPLEFT"
  if anchor == "CENTERBOTTOM" then return "BOTTOM" end
  -- Never fall back to GetPoint(): StartMoving pins TOPLEFT against the screen.
  return anchor
end

local function NativePoint(anchor)
  if pfUI and pfUI.api and pfUI.api.NativePoint then
    return pfUI.api.NativePoint(anchor)
  end
  if anchor == "CENTERBOTTOM" then return "BOTTOM" end
  return anchor or "TOPLEFT"
end

-- x/y in grid cells (float). Mid-line only within half a cell so ±1 sticks.
local function SnapSeat(anchor, x, y)
  if anchor == "TOP" or anchor == "BOTTOM" or anchor == "CENTER" then
    if math.abs(x) < 0.5 then x = 0 end
  end
  if anchor == "LEFT" or anchor == "RIGHT" or anchor == "CENTER" then
    if math.abs(y) < 0.5 then y = 0 end
  end
  return math.floor(x + 0.5), math.floor(y + 0.5)
end

local function CellsFromPixel(px)
  local step = Solo_GridStep()
  if not step or step <= 0 then return 0 end
  return (tonumber(px) or 0) / step
end

local function SnapFrame(frame)
  if not frame or not frame.GetPoint then return end
  local logical = LogicalAnchor(frame)
  if logical == "CENTERBOTTOM" then logical = "BOTTOM" end

  local convert = pfUI and pfUI.api and pfUI.api.ConvertFrameAnchor
  if not convert then return end
  local a, x, y = convert(frame, logical)
  if type(x) ~= "number" or type(y) ~= "number" then return end
  x, y = SnapSeat(a, CellsFromPixel(x), CellsFromPixel(y))

  local native = NativePoint(a)
  frame.pfAnchor = a
  frame:ClearAllPoints()
  frame:SetPoint(native, UIParent, native, GridToPixel(x), GridToPixel(y))
end

-- Write position the way SaveMovable does now: convert, then store (cells).
local function PersistSnapped(frame)
  local name = frame and frame.GetName and frame:GetName()
  if not name then return end
  if type(pfUI_config) ~= "table" then return end
  if pfUI and pfUI.api and pfUI.api.SaveMovable then
    pfUI.api.SaveMovable(frame)
    return
  end
  local convert = pfUI and pfUI.api and pfUI.api.ConvertFrameAnchor
  if not convert then return end
  local logical = LogicalAnchor(frame) or "TOPLEFT"
  local a, x, y = convert(frame, logical)
  if type(x) ~= "number" or type(y) ~= "number" then return end
  x, y = SnapSeat(a, CellsFromPixel(x), CellsFromPixel(y))
  pfUI_config.position = pfUI_config.position or {}
  local cfg = pfUI_config.position[name] or {}
  pfUI_config.position[name] = cfg
  cfg.xpos = x
  cfg.ypos = y
  cfg.anchor = a
  frame.pfAnchor = a
  local parent = frame.GetParent and frame:GetParent()
  cfg.parent = parent and parent.GetName and parent:GetName() or nil
end

local function RefreshDock(frame)
  local dock = pfUI and pfUI.unlock and pfUI.unlock.dock
  if not dock or not dock:IsShown() then return end
  if not (dock.parent and dock.parent.frame == frame) then return end
  local convert = pfUI and pfUI.api and pfUI.api.ConvertFrameAnchor
  if not convert then return end
  local logical = LogicalAnchor(frame) or "TOPLEFT"
  local a, x, y = convert(frame, logical)
  if type(x) ~= "number" or type(y) ~= "number" then return end
  -- Same integer-cell snap as drag-stop; do not tostring raw floats.
  x, y = SnapSeat(a, CellsFromPixel(x), CellsFromPixel(y))
  if dock.xcoord then dock.xcoord:SetText(tostring(x)) end
  if dock.ycoord then dock.ycoord:SetText(tostring(y)) end
end

local function SnapSelection()
  local sel = pfUI and pfUI.unlock and pfUI.unlock.selection
  if type(sel) ~= "table" then return end
  local A = pfUI.api
  for _, frame in pairs(sel) do
    if frame then
      SnapFrame(frame)
      PersistSnapped(frame)
      if A and A.UpdateMovable then A.UpdateMovable(frame) end
      if frame.OnMove then frame:OnMove() end
      RefreshDock(frame)
    end
  end
end

local function WrapDragger(drag)
  if not drag or drag.soloSnapWrapped then return end
  drag.soloSnapWrapped = true
  local prev = drag:GetScript("OnDragStop")
  drag:SetScript("OnDragStop", function()
    if prev then prev() end
    SnapSelection()
  end)
end

local function WrapUnlock()
  if unlockWrapped then return true end
  if not (pfUI and pfUI.unlock) then return false end
  unlockWrapped = true
  local prevShow = pfUI.unlock:GetScript("OnShow")
  pfUI.unlock:SetScript("OnShow", function()
    if prevShow then prevShow() end
    if type(pfUI.movables) ~= "table" then return end
    for name, frame in pairs(pfUI.movables) do
      frame = frame or getglobal(name)
      if frame and frame.drag then WrapDragger(frame.drag) end
    end
  end)
  return true
end

-- Keep for MessageLog / others that want a snapped SaveMovable pass.
function Solo_WithUnlockSnap(fn)
  if type(fn) == "function" then fn() end
  SnapSelection()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("VARIABLES_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" and arg1 ~= "pfUI" then return end
  if WrapUnlock() then return end
  -- Our ADDON_LOADED runs before pfUI creates unlock; poll briefly.
  this.tries = 0
  this:SetScript("OnUpdate", function()
    this.tries = this.tries + 1
    if WrapUnlock() or this.tries > 120 then
      this:SetScript("OnUpdate", nil)
    end
  end)
end)
