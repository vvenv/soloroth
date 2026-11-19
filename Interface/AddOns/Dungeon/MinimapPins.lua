--[[--------------------------------------------------------------------------
Atlas-style boss numbers on the minimap while inside a tracked instance.

Positions come from SoloDun (P = player XY, K = boss XY). Indoor zoom radii
match the 1.12 table. Numbers match the progress panel order (1..N).
----------------------------------------------------------------------------]]

local ZH = (GetLocale and GetLocale() == "zhCN") and true or false
local function L(en, zh) if ZH and zh then return zh end return en end

-- Indoor radii (yards) by Minimap:GetZoom(), table 0x8116e8.
local INDOOR_RADII = { 150, 120, 90, 60, 40, 25 }
-- Outdoor: chunk count * 0.5 * 33.333332.
local OUTDOOR_RADII = { 233.3333, 200, 166.6667, 133.3333, 100, 66.6667 }

local pins = {}
local MAX_PINS = 24
local poll = 0

local function MapFrame()
  return (pfUI and pfUI.minimap) or Minimap
end

local function PlayerFacing()
  if type(GetPlayerFacing) == "function" then
    local f = GetPlayerFacing()
    if f then return f end
  end
  local kids = { Minimap:GetChildren() }
  local arrow = kids[9]
  if arrow and arrow.GetFacing then
    return arrow:GetFacing() or 0
  end
  return 0
end

local function RadiusYards()
  local z = 0
  if Minimap and Minimap.GetZoom then z = Minimap:GetZoom() or 0 end
  if z < 0 then z = 0 end
  if z > 5 then z = 5 end
  local indoors = true
  if type(IsInInstance) == "function" then
    indoors = IsInInstance() and true or false
  end
  if indoors then
    return INDOOR_RADII[z + 1]
  end
  return OUTDOOR_RADII[z + 1]
end

local function EnsurePins()
  if pins[1] then return end
  local parent = MapFrame()
  local i
  for i = 1, MAX_PINS do
    local b = CreateFrame("Frame", "DungeonBossPin" .. i, parent)
    b:SetWidth(18)
    b:SetHeight(18)
    b:SetFrameLevel((parent.GetFrameLevel and parent:GetFrameLevel() or 0) + 8)
    local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("CENTER", b, "CENTER", 0, 0)
    t:SetFont(GameFontNormal:GetFont(), 12, "OUTLINE")
    b.text = t
    b:Hide()
    pins[i] = b
  end
end

local function HideAll()
  local i
  for i = 1, MAX_PINS do
    if pins[i] then pins[i]:Hide() end
  end
end

-- snap from Progress.lua: { player = {x,y}, bosses = { {down, name, x, y}, ... } }
function DungeonPins_Update(snap)
  EnsurePins()
  if not snap or not snap.player or not snap.player[1] then
    HideAll()
    return
  end
  local px, py = snap.player[1], snap.player[2]
  local bosses = snap.bosses
  local n = table.getn(bosses)
  local radius = RadiusYards()
  if not radius or radius < 1 then radius = 90 end
  local map = MapFrame()
  local half = (map:GetWidth() or 140) * 0.5 - 6
  local facing = PlayerFacing()
  local cos = math.cos(facing)
  local sin = math.sin(facing)

  local firstUp = 0
  local i
  for i = 1, n do
    if not bosses[i][1] then firstUp = i break end
  end

  for i = 1, MAX_PINS do
    local pin = pins[i]
    local b = bosses[i]
    if i <= n and b and b[3] and b[4] then
      local dx = b[3] - px
      local dy = b[4] - py
      -- Rotating minimap: player facing is "up".
      local mx = dx * sin - dy * cos
      local my = dx * cos + dy * sin
      local dist = math.sqrt(mx * mx + my * my)
      local ox, oy
      if dist > radius and dist > 0.001 then
        local f = half / dist
        ox, oy = mx * f, my * f
      else
        local scale = half / radius
        ox, oy = mx * scale, my * scale
      end
      pin:ClearAllPoints()
      pin:SetPoint("CENTER", map, "CENTER", ox, oy)
      pin.text:SetText(tostring(i))
      if b[1] then
        pin.text:SetTextColor(0.45, 0.45, 0.45)
      elseif i == firstUp then
        pin.text:SetTextColor(1, 0.82, 0)
      else
        pin.text:SetTextColor(1, 1, 1)
      end
      pin:Show()
    else
      pin:Hide()
    end
  end
end

function DungeonPins_Clear()
  HideAll()
end

-- Keep facing/zoom fresh; Progress.lua refreshes player XY via SoloDun.
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function()
  if type(DungeonProgress_Snap) ~= "function" then return end
  local snap = DungeonProgress_Snap()
  if not snap then
    HideAll()
    return
  end
  poll = poll + arg1
  if poll >= 1.0 then
    poll = 0
    if type(DungeonProgress_Request) == "function" then
      DungeonProgress_Request()
    end
  end
  DungeonPins_Update(snap)
end)
