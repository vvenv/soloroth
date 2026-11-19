--[[--------------------------------------------------------------------------
Atlas-style boss numbers on the minimap while inside a tracked instance.

Positions come from SoloDun (P = player XY, K = boss XY). Placement matches
Minimap:GetPingPosition: (-dy/D, dx/D) with D = 2 * view-radius, then times
the Minimap frame size — same as the stock ping. Pins parent to Minimap
(under pfUI's wrapper), not the wrapper itself.
----------------------------------------------------------------------------]]

-- Indoor radii (yards) by Minimap:GetZoom(), table 0x8116e8.
local INDOOR_RADII = { 150, 120, 90, 60, 40, 25 }

local pins = {}
local MAX_PINS = 24
local poll = 0

local function RadiusYards()
  local z = 0
  if Minimap and Minimap.GetZoom then z = Minimap:GetZoom() or 0 end
  if z < 0 then z = 0 end
  if z > 5 then z = 5 end
  -- Snap only exists inside a tracked instance: always the indoor table.
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

-- World delta → Minimap CENTER offsets (pixels), same basis as GetPingPosition.
local function WorldToMinimap(dx, dy)
  local radius = RadiusYards()
  if not radius or radius < 1 then radius = 90 end
  local D = 2 * radius
  local w = Minimap:GetWidth() or 140
  local h = Minimap:GetHeight() or 140
  local nx = -dy / D
  local ny = dx / D
  local ox = nx * w
  local oy = ny * h
  local dist = math.sqrt(ox * ox + oy * oy)
  local maxr = math.min(w, h) * 0.5 - 4
  if dist > maxr and dist > 0.001 then
    ox = ox * maxr / dist
    oy = oy * maxr / dist
  end
  return ox, oy
end

-- snap from Progress.lua: { player = {x,y}, bosses = { {down, name, x, y}, ... } }
function DungeonPins_Update(snap)
  EnsurePins()
  if not snap or not snap.player or not snap.player[1] then
    HideAll()
    return
  end
  if not Minimap then
    HideAll()
    return
  end

  local px, py = snap.player[1], snap.player[2]
  local bosses = snap.bosses
  local n = table.getn(bosses)
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
      local ox, oy = WorldToMinimap(b[3] - px, b[4] - py)
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
