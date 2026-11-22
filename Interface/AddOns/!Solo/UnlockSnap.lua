--[[--------------------------------------------------------------------------
UnlockSnap -- snap pfUI unlock drag to the unlock grid on release.

Stock pfUI only draws the grid (screen width / 128). Unlock's SaveMovable
lives in pfUI.env (copied at module load), so patching pfUI.api alone never
runs. We wrap each dragger's OnDragStop and snap after the stock handler.
Dock ±1 and typed coords stay free.
----------------------------------------------------------------------------]]

local unlockWrapped

-- Same step DrawGrid uses in pfUI/modules/unlock.lua.
function Solo_GridStep()
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

function Solo_SnapSize(w, h)
  local step = Solo_GridStep()
  return Solo_SnapValue(w, step), Solo_SnapValue(h, step)
end

local function SnapFrame(frame)
  if not frame or not frame.GetPoint then return end
  local anchor, relativeTo, relativePoint, xpos, ypos = frame:GetPoint()
  if type(xpos) ~= "number" or type(ypos) ~= "number" then return end
  local step = Solo_GridStep()
  local sx, sy = Solo_SnapValue(xpos, step), Solo_SnapValue(ypos, step)
  if sx == xpos and sy == ypos then return end
  frame:ClearAllPoints()
  frame:SetPoint(anchor, relativeTo or UIParent, relativePoint or anchor, sx, sy)
end

-- Write position the way SaveMovable does, without its integer round (grid
-- steps can be .5px on some resolutions).
local function PersistSnapped(frame)
  local name = frame and frame.GetName and frame:GetName()
  if not name then return end
  local anchor, _, _, xpos, ypos = frame:GetPoint()
  if type(xpos) ~= "number" or type(ypos) ~= "number" then return end
  if type(pfUI_config) ~= "table" then return end
  pfUI_config.position = pfUI_config.position or {}
  local cfg = pfUI_config.position[name] or {}
  pfUI_config.position[name] = cfg
  cfg.xpos = xpos
  cfg.ypos = ypos
  cfg.anchor = anchor
  local parent = frame.GetParent and frame:GetParent()
  cfg.parent = parent and parent.GetName and parent:GetName() or nil
end

local function RefreshDock(frame)
  local dock = pfUI and pfUI.unlock and pfUI.unlock.dock
  if not dock or not dock:IsShown() then return end
  if not (dock.parent and dock.parent.frame == frame) then return end
  local _, _, _, xpos, ypos = frame:GetPoint()
  if dock.xcoord and type(xpos) == "number" then
    dock.xcoord:SetText(tostring(xpos))
  end
  if dock.ycoord and type(ypos) == "number" then
    dock.ycoord:SetText(tostring(ypos))
  end
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
