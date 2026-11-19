--[[--------------------------------------------------------------------------
Boss numbers on the live minimap while inside a tracked instance.

Placement matches engine blips / GetPingPosition (north-up: +X up, +Y left).
Only bosses inside 0.8 of the view radius are shown — the same cut the
client uses for party dots — so far bosses are not stacked on the rim.
(The live minimap only covers tens of yards; the full-dungeon layout is
the /gd map page / Atlas.)
----------------------------------------------------------------------------]]

-- Indoor radii (yards) by Minimap:GetZoom(), table 0x8116e8.
local INDOOR_RADII = { 150, 120, 90, 60, 40, 25 }
-- Engine party-dot cut (BLIP_EDGE_RATIO).
local EDGE = 0.8

local pins = {}
local MAX_PINS = 24
local poll = 0

local function RadiusYards()
  local z = 0
  if Minimap and Minimap.GetZoom then z = Minimap:GetZoom() or 0 end
  if z < 0 then z = 0 end
  if z > 5 then z = 5 end
  return INDOOR_RADII[z + 1]
end

local function EnsurePins()
  if pins[1] then return end
  local i
  for i = 1, MAX_PINS do
    local b = CreateFrame("Frame", "DungeonBossPin" .. i, Minimap)
    b:SetWidth(16)
    b:SetHeight(16)
    local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("CENTER", b, "CENTER", 0, 0)
    t:SetFont(GameFontNormal:GetFont(), 11, "OUTLINE")
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

-- World delta → Minimap CENTER offsets. Same basis as blips:
--   screen x = (playerY - bossY) * pxPerYd
--   screen y = (bossX - playerX) * pxPerYd   (UI y-up)
local function WorldToMinimap(dx, dy, radius)
  local w = Minimap:GetWidth() or 140
  local h = Minimap:GetHeight() or 140
  local side = w
  if h < side then side = h end
  local pxPerYd = (side * 0.5) / radius
  local ox = -dy * pxPerYd
  local oy = dx * pxPerYd
  return ox, oy
end

function DungeonPins_Update(snap)
  EnsurePins()
  if not snap or not snap.player or not snap.player[1] or not Minimap then
    HideAll()
    return
  end

  local px, py = snap.player[1], snap.player[2]
  local bosses = snap.bosses
  local n = table.getn(bosses)
  local radius = RadiusYards()
  if not radius or radius < 1 then radius = 90 end
  local maxDist = radius * EDGE
  local level = (Minimap.GetFrameLevel and Minimap:GetFrameLevel() or 0) + 8

  local firstUp = 0
  local i
  for i = 1, n do
    if not bosses[i][1] then firstUp = i break end
  end

  for i = 1, MAX_PINS do
    local pin = pins[i]
    local b = bosses[i]
    if i <= n and b and type(b[3]) == "number" and type(b[4]) == "number" then
      local dx = b[3] - px
      local dy = b[4] - py
      local dist = math.sqrt(dx * dx + dy * dy)
      if dist <= maxDist then
        local ox, oy = WorldToMinimap(dx, dy, radius)
        if pin:GetParent() ~= Minimap then pin:SetParent(Minimap) end
        pin:SetFrameLevel(level)
        pin:ClearAllPoints()
        pin:SetPoint("CENTER", Minimap, "CENTER", ox, oy)
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
    else
      if pin then pin:Hide() end
    end
  end
end

function DungeonPins_Clear()
  HideAll()
end

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
