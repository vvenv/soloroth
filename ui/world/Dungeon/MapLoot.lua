--[[--------------------------------------------------------------------------
Map pane inside the dungeon hub (/gd).

Uses Atlas map BLPs + AtlasMaps legend text, and AtlasLoot_ShowBossLoot for
drop tables over the map. Does not open AtlasFrame or AtlasLootDefaultFrame.
World bosses appear in the map dropdown only (no teleport); raids are on
the list tab with teleport like five-mans.
----------------------------------------------------------------------------]]

local ZH = (GetLocale and GetLocale() == "zhCN") and true or false
local function L(en, zh) if ZH and zh then return zh end return en end

local PAD = 16
local GAP = 8
local BTN_H = 22
local ROW_H = 16
local LEGEND_ROWS = 28
local MAP_SIZE = 512
local LEGEND_W = 260
-- Same width for list and map so the window does not jump sideways.
local HUB_W = PAD * 2 + MAP_SIZE + GAP + LEGEND_W
local LIST_H = 440
local MAP_H = 36 + BTN_H + GAP + 22 + MAP_SIZE + PAD

-- Atlas zone ids for each five-man teleport row (same order as DungeonList).
local FIVE_ATLAS = {
  "RagefireChasm",
  "WailingCaverns",
  "TheDeadmines",
  "ShadowfangKeep",
  "BlackfathomDeeps",
  "TheStockade",
  "SMGraveyard",
  "Gnomeregan",
  "RazorfenKraul",
  "SMLibrary",
  "SMArmory",
  "SMCathedral",
  "RazorfenDowns",
  "Uldaman",
  "ZulFarrak",
  "Maraudon",
  "Maraudon",
  "TheSunkenTemple",
  "BlackrockDepths",
  "BlackrockSpireLower",
  "DireMaulEast",
  "DireMaulWest",
  "DireMaulNorth",
  "Scholomance",
  "Stratholme",
  "Stratholme",
}

-- World-boss maps: browse only (raids are on the list tab now).
local EXTRA = {
  { "Azuregos",              "艾索雷葛斯", "Azuregos" },
  { "Lord Kazzak",           "卡扎克", "LordKazzak" },
  { "Dragons of Nightmare",  "梦魇之龙", "FourDragons" },
}

local mode = "list" -- list | map
local zoneId
local catalog = {} -- { { en, zh, atlas }, ... }
local catIndex = 1
local legend = { rows = {}, offset = 0, lines = {} }
local mapPane, lootHost, zoneLabel, dropBtn
local modeBtns = {}

local function Hub()
  return DungeonHub
end

local function Msg(s)
  local h = Hub()
  if h and h.msg then h.msg(s) else
    DEFAULT_CHAT_FRAME:AddMessage("|cff44ddff" .. L("Dungeon", "副本") .. "|r: " .. s)
  end
end

local function BuildCatalog()
  catalog = {}
  local list = (Hub() and Hub().dungeons) or {}
  local i
  for i = 1, table.getn(list) do
    local d = list[i]
    local atlas = d[10] or FIVE_ATLAS[i]
    if atlas then
      tinsert(catalog, { d[1], d[2], atlas })
    end
  end
  for i = 1, table.getn(EXTRA) do
    tinsert(catalog, EXTRA[i])
  end
end

local function CatalogIndexFor(atlas)
  local i
  for i = 1, table.getn(catalog) do
    if catalog[i][3] == atlas then return i end
  end
  return 1
end

local function ZoneTitle(atlas)
  if AtlasMaps and AtlasMaps[atlas] and AtlasMaps[atlas].ZoneName then
    return AtlasMaps[atlas].ZoneName[1]
  end
  local i = CatalogIndexFor(atlas)
  local e = catalog[i]
  if e then return ZH and e[2] or e[1] end
  return atlas
end

local function StripColor(s)
  if not s then return "" end
  return string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
end

local function DetectZone()
  local list = (Hub() and Hub().dungeons) or {}
  local z = GetRealZoneText and GetRealZoneText() or ""
  local i
  for i = 1, table.getn(list) do
    local d = list[i]
    if z == d[1] or z == d[2] or string.find(z, d[1], 1, true) or string.find(z, d[2], 1, true) then
      return d[10] or FIVE_ATLAS[i]
    end
  end
  for i = 1, table.getn(EXTRA) do
    local e = EXTRA[i]
    if z == e[1] or z == e[2] or string.find(z, e[1], 1, true) or string.find(z, e[2], 1, true) then
      return e[3]
    end
  end
  if AtlasMaps then
    local k, base
    for k, base in pairs(AtlasMaps) do
      if type(base) == "table" and base.ZoneName and base.ZoneName[1] then
        local name = StripColor(base.ZoneName[1])
        if name == z or string.find(z, name, 1, true) then
          return k
        end
      end
    end
  end
  return nil
end

-- Atlas zone id when the player is in a known instance, else nil.
function Dungeon_DetectZone()
  BuildCatalog()
  return DetectZone()
end

-- True when standing in any instance (even if the Atlas id is unknown).
function Dungeon_InInstance()
  if DetectZone() then return true end
  if type(IsInInstance) == "function" and IsInInstance() then return true end
  return false
end

local function ResolveZone(prefer)
  if prefer and AtlasMaps and AtlasMaps[prefer] then return prefer end
  if Hub() and Hub().selectedZone and AtlasMaps and AtlasMaps[Hub().selectedZone] then
    return Hub().selectedZone
  end
  local det = DetectZone()
  if det then return det end
  if zoneId and AtlasMaps and AtlasMaps[zoneId] then return zoneId end
  BuildCatalog()
  if catalog[1] then return catalog[1][3] end
  return "TheDeadmines"
end

local function LootId(atlas, line)
  if AtlasLootBossButtons and AtlasLootBossButtons[atlas]
      and AtlasLootBossButtons[atlas][line]
      and AtlasLootBossButtons[atlas][line] ~= "" then
    return AtlasLootBossButtons[atlas][line]
  end
  if AtlasLootWBBossButtons and AtlasLootWBBossButtons[atlas]
      and AtlasLootWBBossButtons[atlas][line]
      and AtlasLootWBBossButtons[atlas][line] ~= "" then
    return AtlasLootWBBossButtons[atlas][line]
  end
  return nil
end

local function BuildLegend(atlas)
  legend.lines = {}
  if not (AtlasMaps and AtlasMaps[atlas]) then return end
  local i = 1
  while AtlasMaps[atlas][i] do
    local row = AtlasMaps[atlas][i]
    tinsert(legend.lines, {
      text = row[1] or "",
      loot = LootId(atlas, i),
      index = i,
    })
    i = i + 1
  end
end

local function LegendRefresh()
  local n = table.getn(legend.lines)
  if legend.offset > n - LEGEND_ROWS then legend.offset = n - LEGEND_ROWS end
  if legend.offset < 0 then legend.offset = 0 end
  local i
  for i = 1, LEGEND_ROWS do
    local b = legend.rows[i]
    local line = legend.lines[legend.offset + i]
    if line then
      b.line = line
      b.text:SetText(line.text)
      if line.loot then
        b.text:SetTextColor(1, 0.82, 0)
      else
        b.text:SetTextColor(0.7, 0.7, 0.7)
      end
      b:Show()
    else
      b.line = nil
      b:Hide()
    end
  end
end

local function SetMapTexture(atlas)
  if not mapPane or not mapPane.map then return end
  mapPane.map:SetTexture("Interface\\AddOns\\Atlas\\Images\\Maps\\" .. atlas)
end

local function ShowLootForLine(atlas, line)
  local id = LootId(atlas, line)
  if not id then
    Msg(L("No loot table for that entry.", "该项没有掉落表。"))
    return false
  end
  if type(AtlasLoot_ShowBossLoot) ~= "function" then
    Msg(L("AtlasLoot is not loaded", "未加载 AtlasLoot"))
    return false
  end
  local title = AtlasMaps[atlas][line][1] or id
  local pFrame = { "TOPLEFT", lootHost, "TOPLEFT", 0, 0 }
  AtlasLoot_ShowBossLoot(id, StripColor(title), pFrame)
  if AtlasLootItemsFrame then
    AtlasLootItemsFrame:SetFrameLevel(lootHost:GetFrameLevel() + 5)
    AtlasLootItemsFrame:Show()
  end
  return true
end

local function HideLootFrame()
  if AtlasLootItemsFrame then AtlasLootItemsFrame:Hide() end
end

local function ResizeHub(h)
  local hframe = Hub() and Hub().frame
  if not hframe then return end
  hframe:SetWidth(HUB_W)
  hframe:SetHeight(h)
  local n = 0
  while modeBtns[n + 1] do n = n + 1 end
  if n < 1 then return end
  local bw = (HUB_W - PAD * 2 - GAP * (n - 1)) / n
  local i = 1
  while modeBtns[i] do
    modeBtns[i]:SetWidth(bw)
    modeBtns[i]:ClearAllPoints()
    modeBtns[i]:SetPoint("TOPLEFT", hframe, "TOPLEFT", PAD + (i - 1) * (bw + GAP), -36)
    i = i + 1
  end
end

local function HighlightModes(which)
  local i = 1
  while modeBtns[i] do
    local b = modeBtns[i]
    if b.mode == which then
      b:Disable()
    else
      b:Enable()
    end
    i = i + 1
  end
end

function Dungeon_SetMode(which, preferZone)
  local hub = Hub()
  if not hub or not hub.frame then return end
  if which ~= "list" and which ~= "map" then which = "list" end
  mode = which

  if which == "list" then
    HideLootFrame()
    if mapPane then mapPane:Hide() end
    if hub.listPane then hub.listPane:Show() end
    ResizeHub(LIST_H)
    HighlightModes("list")
    return
  end

  BuildCatalog()
  zoneId = ResolveZone(preferZone)
  if hub then hub.selectedZone = zoneId end
  catIndex = CatalogIndexFor(zoneId)

  if hub.listPane then hub.listPane:Hide() end
  ResizeHub(MAP_H)
  if mapPane then mapPane:Show() end
  SetMapTexture(zoneId)
  if zoneLabel then zoneLabel:SetText(ZoneTitle(zoneId)) end
  BuildLegend(zoneId)
  legend.offset = 0
  LegendRefresh()
  if dropBtn and UIDropDownMenu_SetText then
    UIDropDownMenu_SetText(ZH and catalog[catIndex][2] or catalog[catIndex][1], dropBtn)
  end
  HideLootFrame()
  HighlightModes("map")
end

function Dungeon_SelectZone(atlas)
  if not atlas then return end
  local hub = Hub()
  if hub then hub.selectedZone = atlas end
  zoneId = atlas
  if mode == "list" then return end
  Dungeon_SetMode("map", atlas)
end

function Dungeon_OpenMap(prefer)
  local hub = Hub()
  if hub and hub.frame then
    hub.frame:Show()
  end
  Dungeon_SetMode("map", prefer)
end

function Dungeon_CurrentMode()
  return mode
end

-- ----------------------------------------------------------------- UI ---

local function DropDownInit()
  if not catalog[1] then BuildCatalog() end
  local i
  for i = 1, table.getn(catalog) do
    local e = catalog[i]
    local info = {}
    info.text = ZH and e[2] or e[1]
    info.value = e[3]
    info.func = function()
      local v = this.value
      catIndex = CatalogIndexFor(v)
      Dungeon_SelectZone(v)
      Dungeon_SetMode("map", v)
    end
    UIDropDownMenu_AddButton(info)
  end
end

local function BuildMapPane(parent)
  mapPane = CreateFrame("Frame", "DungeonMapPane", parent)
  mapPane:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(36 + BTN_H + 4))
  mapPane:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
  mapPane:Hide()

  zoneLabel = mapPane:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  zoneLabel:SetPoint("TOPLEFT", mapPane, "TOPLEFT", PAD, -4)
  zoneLabel:SetText("")

  dropBtn = CreateFrame("Frame", "DungeonMapDropDown", mapPane, "UIDropDownMenuTemplate")
  dropBtn:SetPoint("TOPRIGHT", mapPane, "TOPRIGHT", -PAD + 16, 2)
  UIDropDownMenu_Initialize(dropBtn, DropDownInit)
  UIDropDownMenu_SetWidth(180, dropBtn)

  local map = mapPane:CreateTexture("DungeonMapTexture", "ARTWORK")
  map:SetWidth(MAP_SIZE)
  map:SetHeight(MAP_SIZE)
  map:SetPoint("TOPLEFT", mapPane, "TOPLEFT", PAD, -26)
  mapPane.map = map

  lootHost = CreateFrame("Frame", "DungeonLootHost", mapPane)
  lootHost:SetWidth(MAP_SIZE)
  lootHost:SetHeight(MAP_SIZE)
  lootHost:SetPoint("TOPLEFT", map, "TOPLEFT", 0, 0)
  lootHost:SetFrameLevel(mapPane:GetFrameLevel() + 2)

  local legendFrame = CreateFrame("Frame", "DungeonLegend", mapPane)
  legendFrame:SetPoint("TOPLEFT", map, "TOPRIGHT", GAP, 0)
  legendFrame:SetPoint("BOTTOMRIGHT", mapPane, "BOTTOMRIGHT", -PAD, PAD)
  legendFrame:EnableMouseWheel(true)
  legendFrame:SetScript("OnMouseWheel", function()
    legend.offset = legend.offset + ((arg1 > 0) and -3 or 3)
    LegendRefresh()
  end)

  local tip = legendFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  tip:SetPoint("TOPLEFT", legendFrame, "TOPLEFT", 0, 0)
  tip:SetText(L("Gold = has loot. Click a line.", "金色有掉落，点击查看。"))

  local i
  for i = 1, LEGEND_ROWS do
    local b = CreateFrame("Button", "DungeonLegendRow" .. i, legendFrame)
    b:SetHeight(ROW_H)
    b:SetPoint("TOPLEFT", legendFrame, "TOPLEFT", 0, -16 - (i - 1) * (ROW_H + 1))
    b:SetPoint("TOPRIGHT", legendFrame, "TOPRIGHT", 0, -16 - (i - 1) * (ROW_H + 1))
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    b.text = b:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    b.text:SetPoint("LEFT", b, "LEFT", 2, 0)
    b.text:SetPoint("RIGHT", b, "RIGHT", -2, 0)
    b.text:SetJustifyH("LEFT")
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnClick", function()
      local line = this.line
      if not line or not line.loot then return end
      ShowLootForLine(zoneId, line.index)
    end)
    b:SetScript("OnEnter", function()
      if not this.line then return end
      GameTooltip:SetOwner(this, "ANCHOR_LEFT")
      GameTooltip:AddLine(StripColor(this.line.text))
      if this.line.loot then
        GameTooltip:AddLine(L("Click for loot", "点击查看掉落"), 0.4, 0.8, 1)
      end
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    legend.rows[i] = b
  end
end

local function WireModeButtons(parent)
  local labels = {
    { "list", L("List", "列表"), L("Teleport and reset five-player dungeons.", "传送与重置五人副本。") },
    { "map", L("Map", "地图"), L("Instance layout; click a gold legend line for loot.", "副本地图；点金色图例看掉落。") },
  }
  local i
  for i = 1, 2 do
    local info = labels[i]
    local b = CreateFrame("Button", "DungeonMode" .. i, parent, "UIPanelButtonTemplate")
    b:SetHeight(BTN_H)
    b:SetText(info[2])
    b.mode = info[1]
    b:SetScript("OnClick", function()
      Dungeon_SetMode(this.mode)
    end)
    b:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
      GameTooltip:AddLine(info[3])
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    modeBtns[i] = b
  end
  if Hub() then Hub().modeButtons = modeBtns end
end

local function SkinModeButtons()
  if not SoloSkin then return end
  local i = 1
  while modeBtns[i] do
    SoloSkin.Button(modeBtns[i])
    i = i + 1
  end
  if mapPane and SoloSkin.Controls then
    SoloSkin.Controls(mapPane)
  end
end

local function Init()
  local hub = Hub()
  if not hub or not hub.frame then return end
  if mapPane then return end
  BuildCatalog()
  WireModeButtons(hub.frame)
  BuildMapPane(hub.frame)
  SkinModeButtons()
  Dungeon_SetMode("list")
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" and arg1 == "Dungeon" then
    Init()
  elseif event == "PLAYER_LOGIN" then
    Init()
  end
end)

-- Dungeon.lua loads before this file; hub may already exist.
if DungeonHub and DungeonHub.frame then
  Init()
end
