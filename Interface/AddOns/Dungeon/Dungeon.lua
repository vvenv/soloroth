--[[--------------------------------------------------------------------------
Dungeon -- one hub for five-player instances on this solo realm.

  * list: click a name to `.go xyzo` just inside the entrance (GM)
  * reset: one row resets that map only (right-click the minimap button
    still clears every five-player instance)
  * map: Atlas layout + AtlasLoot overlay in this window (see MapLoot.lua)

Formerly the GMBox "Dungeons" tab plus the separate Atlas / AtlasLoot
minimap buttons. `/gd` lands here; inside an instance it opens on the map.
----------------------------------------------------------------------------]]

local VERSION = "1.3.2"

local ZH = (GetLocale and GetLocale() == "zhCN") and true or false
local function L(en, zh) if ZH and zh then return zh end return en end

local COL = "|cff44ddff"
-- Same width as the map page (512 map + legend); height grows for the map.
local FRAME_W, FRAME_H = 812, 440
local PAD = 16
local GAP = 8
local BTN_H = 22
local ROW_H, DROWS = 18, 18
local RESET_W = 52

local function msg(s) DEFAULT_CHAT_FRAME:AddMessage(COL .. L("Dungeon", "副本") .. "|r: " .. s) end

-- SAY is refused while dead; a whisper to yourself still reaches the parser.
local function Cmd(s)
  if not s or s == "" then return end
  if string.sub(s, 1, 1) ~= "." then s = "." .. s end
  if UnitIsDeadOrGhost("player") then
    SendChatMessage(s, "WHISPER", nil, UnitName("player"))
  else
    SendChatMessage(s, "SAY")
  end
  return s
end

local pendingReset
if StaticPopupDialogs then
  StaticPopupDialogs["DUNGEON_RESET_ONE"] = {
    text = "%s",
    button1 = ACCEPT,
    button2 = CANCEL,
    OnAccept = function()
      if pendingReset then
        Cmd(".instance reset " .. pendingReset)
        pendingReset = nil
      end
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
  }
end

local function AskReset(d)
  pendingReset = d[5]
  local name = ZH and d[2] or d[1]
  if StaticPopup_Show then
    StaticPopup_Show("DUNGEON_RESET_ONE", L("Reset ", "重置「") .. name .. L("?", "」？"))
  else
    Cmd(".instance reset " .. d[5])
  end
end

-- ------------------------------------------------------------- dungeon list --
-- Spot just inside each entrance (areatrigger_teleport targets). The server
-- still fills the party three seconds later; the Bots button sets the size.
-- [10] is the Atlas zone id used by MapLoot.lua.

local DUNGEONS = {
  -- { english, chinese, min, max, map, x, y, z, o, atlas }
  { "Ragefire Chasm",               "怒焰裂谷",           13, 18, 389,     0.8,    -8.2,  -15.5, 4.71, "RagefireChasm" },
  { "Wailing Caverns",              "哀嚎洞穴",           17, 24,  43,  -158.4,   131.6,  -74.3, 5.85, "WailingCaverns" },
  { "The Deadmines",                "死亡矿井",           17, 26,  36,   -14.6,  -385.5,   62.5, 1.57, "TheDeadmines" },
  { "Shadowfang Keep",              "影牙城堡",           22, 30,  33,  -228.2,  2111.4,   76.9, 1.22, "ShadowfangKeep" },
  { "Blackfathom Deeps",            "黑暗深渊",           24, 32,  48,  -150.2,   106.6,  -39.8, 4.45, "BlackfathomDeeps" },
  { "The Stockade",                 "暴风城监狱",         24, 32,  34,    49.0,     0.5,  -16.4, 6.28, "TheStockade" },
  { "Scarlet Monastery: Graveyard", "血色修道院：墓地",   26, 36, 189,  1687.3,  1050.1,   18.7, 1.57, "SMGraveyard" },
  { "Gnomeregan",                   "诺莫瑞根",           29, 38,  90,  -329.1,    -3.2, -152.9, 2.97, "Gnomeregan" },
  { "Razorfen Kraul",               "剃刀沼泽",           29, 38,  47,  1942.3,  1544.2,   83.3, 1.31, "RazorfenKraul" },
  { "Scarlet Monastery: Library",   "血色修道院：图书馆", 29, 39, 189,   253.7,  -206.6,   18.7, 4.71, "SMLibrary" },
  { "Scarlet Monastery: Armory",    "血色修道院：军械库", 32, 42, 189,  1608.1,  -318.9,   18.7, 4.71, "SMArmory" },
  { "Scarlet Monastery: Cathedral", "血色修道院：大教堂", 35, 45, 189,   853.2,  1319.2,   18.7, 1.57, "SMCathedral" },
  { "Razorfen Downs",               "剃刀高地",           37, 46, 129,  2593.7,  1111.2,   51.0, 4.71, "RazorfenDowns" },
  { "Uldaman",                      "奥达曼",             41, 51,  70,  -228.9,    46.1,  -46.0, 1.57, "Uldaman" },
  { "Zul'Farrak",                   "祖尔法拉克",         42, 54, 209,  1212.7,   842.0,    8.9, 6.28, "ZulFarrak" },
  { "Maraudon: Orange",             "玛拉顿：橙色入口",   46, 55, 349,  1016.8,  -458.5,  -43.5, 6.28, "Maraudon" },
  { "Maraudon: Purple",             "玛拉顿：紫色入口",   46, 55, 349,   755.1,  -617.7,  -32.9, 1.57, "Maraudon" },
  { "Sunken Temple",                "沉没的神庙",         50, 60, 109,  -315.9,   100.2, -131.8, 3.14, "TheSunkenTemple" },
  { "Blackrock Depths",             "黑石深渊",           52, 60, 230,   456.9,    34.1,  -68.1, 4.71, "BlackrockDepths" },
  { "Lower Blackrock Spire",        "黑石塔下层",         55, 60, 229,    78.4,  -226.8,   49.8, 4.71, "BlackrockSpireLower" },
  { "Dire Maul: East",              "厄运之槌：东",       55, 60, 429,  -203.2,  -323.0,   -2.7, 4.71, "DireMaulEast" },
  { "Dire Maul: West",              "厄运之槌：西",       57, 60, 429,   -65.7,   159.6,   -3.5, 2.36, "DireMaulWest" },
  { "Dire Maul: North",             "厄运之槌：北",       57, 60, 429,   254.9,   -19.5,   -2.6, 5.50, "DireMaulNorth" },
  { "Scholomance",                  "通灵学院",           58, 60, 289,   190.8,   126.3,  137.2, 6.28, "Scholomance" },
  { "Stratholme: Main Gate",        "斯坦索姆：正门",     58, 60, 329,  3392.9, -3395.0,  143.1, 1.57, "Stratholme" },
  { "Stratholme: Service Gate",     "斯坦索姆：后门",     58, 60, 329,  3590.9, -3643.2,  138.5, 5.50, "Stratholme" },
}

local function DungeonColor(d)
  local lvl = UnitLevel("player") or 1
  if lvl < d[3] - 2 then return 1, 0.1, 0.1 end
  if lvl < d[3] then return 1, 0.5, 0.25 end
  if lvl <= d[4] - 3 then return 1, 0.82, 0 end
  if lvl <= d[4] + 2 then return 0.25, 0.75, 0.25 end
  return 0.5, 0.5, 0.5
end

-- ------------------------------------------------------------- saved vars --

DungeonDB = nil
local db

local function InitDB()
  if type(DungeonDB) ~= "table" then DungeonDB = {} end
  db = DungeonDB
  if type(db.mmAngle) ~= "number" then db.mmAngle = 250 end
end

-- ------------------------------------------------------------------- UI ---

local f = CreateFrame("Frame", "DungeonFrame", UIParent)
f:SetWidth(FRAME_W)
f:SetHeight(FRAME_H)
f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
f:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 12,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
f:SetBackdropColor(0, 0, 0, .9)
f:EnableMouse(true)
f:SetMovable(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", function() this:StartMoving() end)
f:SetScript("OnDragStop", function()
  this:StopMovingOrSizing()
  local point, _, relPoint, x, y = this:GetPoint()
  if type(DungeonDB) ~= "table" then DungeonDB = {} end
  DungeonDB.point = { point, relPoint, x, y }
end)
if f.SetClampedToScreen then f:SetClampedToScreen(true) end
f:Hide()
tinsert(UISpecialFrames, "DungeonFrame")

local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
title:SetPoint("TOP", f, "TOP", 0, -12)
title:SetText(L("Dungeon", "副本") .. " " .. VERSION)

local close = CreateFrame("Button", "DungeonClose", f, "UIPanelButtonTemplate")
close:SetWidth(22) close:SetHeight(22)
close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
close:SetText("x")
close:SetScript("OnClick", function()
  if type(Dungeon_SetMode) == "function" then Dungeon_SetMode("list") end
  f:Hide()
end)

-- List pane: teleport rows (map lives in MapLoot.lua).
local listPane = CreateFrame("Frame", "DungeonListPane", f)
listPane:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(36 + BTN_H + 4))
listPane:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)

local listLabel = listPane:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
listLabel:SetPoint("TOPLEFT", listPane, "TOPLEFT", PAD, -4)
listLabel:SetText(L("Name: teleport inside (GM). Reset: that map only.", "点名字传送（需 GM）。「重置」只清这一张。"))

local lvlLabel = listPane:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
lvlLabel:SetPoint("TOPRIGHT", listPane, "TOPRIGHT", -(PAD + RESET_W + 8), -4)
lvlLabel:SetText(L("Level", "等级"))

local dui = { rows = {}, offset = 0, selected = nil }
local resetBtns = {}

local function DungeonRefresh()
  local n = table.getn(DUNGEONS)
  if dui.offset > n - DROWS then dui.offset = n - DROWS end
  if dui.offset < 0 then dui.offset = 0 end
  for i = 1, DROWS do
    local b, d = dui.rows[i], DUNGEONS[dui.offset + i]
    local r = resetBtns[i]
    if d then
      b.d = d
      r.d = d
      b.text:SetText(ZH and d[2] or d[1])
      b.text:SetTextColor(DungeonColor(d))
      b.info:SetText(d[3] .. "-" .. d[4])
      if dui.selected == d then
        b:LockHighlight()
      else
        b:UnlockHighlight()
      end
      b:Show()
      r:Show()
    else
      b.d = nil
      r.d = nil
      b:UnlockHighlight()
      b:Hide()
      r:Hide()
    end
  end
end

local function SelectDungeon(d)
  dui.selected = d
  if d and d[10] then
    if DungeonHub then DungeonHub.selectedZone = d[10] end
    if type(Dungeon_SelectZone) == "function" then Dungeon_SelectZone(d[10]) end
  end
  DungeonRefresh()
end

local function DungeonGo(d)
  SelectDungeon(d)
  Cmd(string.format(".go xyzo %.1f %.1f %.1f %.2f %d", d[6], d[7], d[8], d[9], d[5]))
  msg("-> " .. (ZH and d[2] or d[1]))
end

for i = 1, DROWS do
  local b = CreateFrame("Button", "DungeonRow" .. i, listPane)
  b:SetHeight(ROW_H)
  if i == 1 then
    b:SetPoint("TOPLEFT", listPane, "TOPLEFT", PAD, -22)
    b:SetPoint("TOPRIGHT", listPane, "TOPRIGHT", -(PAD + RESET_W + GAP), -22)
  else
    b:SetPoint("TOPLEFT", dui.rows[i - 1], "BOTTOMLEFT", 0, -1)
    b:SetPoint("TOPRIGHT", dui.rows[i - 1], "BOTTOMRIGHT", 0, -1)
  end
  b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
  b.text = b:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  b.text:SetPoint("LEFT", b, "LEFT", 4, 0)
  b.text:SetPoint("RIGHT", b, "RIGHT", -52, 0)
  b.text:SetJustifyH("LEFT")
  b.info = b:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  b.info:SetPoint("RIGHT", b, "RIGHT", -4, 0)
  b.info:SetJustifyH("RIGHT")
  b.info:SetWidth(44)
  b:RegisterForClicks("LeftButtonUp")
  b:SetScript("OnClick", function()
    if this.d then DungeonGo(this.d) end
  end)
  b:SetScript("OnEnter", function()
    local d = this.d
    if not d then return end
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:AddLine(ZH and d[2] or d[1])
    if ZH then GameTooltip:AddLine(d[1], 0.8, 0.8, 0.8) end
    GameTooltip:AddLine(L("Recommended level ", "推荐等级 ") .. d[3] .. "-" .. d[4], 0.8, 0.8, 0.8)
    GameTooltip:AddLine(L("Click the name to teleport inside. Reset clears only this map.",
                          "点名字传送进去。「重置」只清这一张地图（多个入口一起清）。"), 0.4, 0.8, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)

  local r = CreateFrame("Button", "DungeonReset" .. i, listPane, "UIPanelButtonTemplate")
  r:SetWidth(RESET_W)
  r:SetHeight(ROW_H)
  r:SetPoint("LEFT", b, "RIGHT", GAP, 0)
  r:SetText(L("Reset", "重置"))
  r:SetScript("OnClick", function()
    if this.d then AskReset(this.d) end
  end)
  r:SetScript("OnEnter", function()
    local d = this.d
    if not d then return end
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L("Reset ", "重置 ") .. (ZH and d[2] or d[1]))
    GameTooltip:AddLine(L("This map only. Leave it first if you are inside.",
                          "只清这一张。人在里面时要先出来。"), 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  resetBtns[i] = r
  dui.rows[i] = b
end

listPane:EnableMouseWheel(true)
listPane:SetScript("OnMouseWheel", function()
  dui.offset = dui.offset + ((arg1 > 0) and -3 or 3)
  DungeonRefresh()
end)

-- Hub table for MapLoot.lua (mode buttons, map pane).
DungeonHub = {
  frame = f,
  listPane = listPane,
  dungeons = DUNGEONS,
  selectedZone = nil,
  msg = msg,
  L = L,
  ZH = ZH,
  version = VERSION,
  modeButtons = nil,
}

f:SetScript("OnShow", function()
  DungeonRefresh()
end)
f:SetScript("OnHide", function()
  if AtlasLootItemsFrame and AtlasLootItemsFrame:IsVisible()
      and AtlasLootItemsFrame:GetParent()
      and AtlasLootItemsFrame:GetParent():GetName() == "DungeonLootHost" then
    AtlasLootItemsFrame:Hide()
  end
end)

-- Inside an instance → map page; otherwise list. Zone detect lives in MapLoot.
local function OpenPreferred()
  f:Show()
  DungeonRefresh()
  local inInst = type(Dungeon_InInstance) == "function" and Dungeon_InInstance()
  local zone = type(Dungeon_DetectZone) == "function" and Dungeon_DetectZone() or nil
  if inInst or zone then
    if type(Dungeon_OpenMap) == "function" then Dungeon_OpenMap(zone) end
  elseif type(Dungeon_SetMode) == "function" then
    Dungeon_SetMode("list")
  end
end

local function Toggle()
  if f:IsVisible() then
    f:Hide()
  else
    OpenPreferred()
  end
end

function Dungeon_Toggle() Toggle() end

-- ------------------------------------------------------- minimap button ---

local mm = CreateFrame("Button", "DungeonMinimapButton", Minimap)
mm:SetWidth(31) mm:SetHeight(31)
mm:SetFrameStrata("MEDIUM")
mm:SetFrameLevel(8)
mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
mm:RegisterForClicks("LeftButtonUp", "RightButtonUp")
mm:RegisterForDrag("LeftButton")
local mmIcon = mm:CreateTexture(nil, "ARTWORK")
-- Key, not INV_Misc_Map_01: that face is the world-map micro button above.
mmIcon:SetTexture("Interface\\Icons\\INV_Misc_Key_03")
mmIcon:SetWidth(20) mmIcon:SetHeight(20)
mmIcon:SetPoint("TOPLEFT", mm, "TOPLEFT", 7, -5)
local mmBorder = mm:CreateTexture(nil, "OVERLAY")
mmBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
mmBorder:SetWidth(53) mmBorder:SetHeight(53)
mmBorder:SetPoint("TOPLEFT", mm, "TOPLEFT", 0, 0)

local function PlaceMinimapButton()
  if type(DungeonDB) ~= "table" then DungeonDB = {} end
  local a = math.rad(DungeonDB.mmAngle or 250)
  mm:ClearAllPoints()
  mm:SetPoint("CENTER", Minimap, "CENTER", 80 * math.cos(a), 80 * math.sin(a))
end

mm:SetScript("OnDragStart", function()
  this:SetScript("OnUpdate", function()
    if type(DungeonDB) ~= "table" then DungeonDB = {} end
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    DungeonDB.mmAngle = math.deg(math.atan2(py / scale - my, px / scale - mx))
    PlaceMinimapButton()
  end)
end)
mm:SetScript("OnDragStop", function() this:SetScript("OnUpdate", nil) end)
mm:SetScript("OnClick", function()
  if arg1 == "RightButton" then
    if StaticPopup_Show then StaticPopup_Show("CONFIRM_RESET_INSTANCES") end
    return
  end
  Toggle()
end)
mm:SetScript("OnEnter", function()
  GameTooltip:SetOwner(this, "ANCHOR_LEFT")
  GameTooltip:AddLine(L("Dungeon", "副本"))
  GameTooltip:AddLine(L("Left: open the hub", "左键：打开副本中心"), 0.8, 0.8, 0.8)
  GameTooltip:AddLine(L("Right: reset instances", "右键：重置副本"), 0.8, 0.8, 0.8)
  if type(DungeonProgress_Tooltip) == "function" then DungeonProgress_Tooltip() end
  GameTooltip:Show()
end)
mm:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- ----------------------------------------------------------------- slash ---

SLASH_DUNGEON1 = "/gd"
SLASH_DUNGEON2 = "/fb"
SLASH_DUNGEON3 = "/dungeon"
SlashCmdList["DUNGEON"] = function(a)
  a = string.lower(string.gsub(a or "", "^%s+", ""))
  if a == "reset" or a == "cz" then
    if StaticPopup_Show then StaticPopup_Show("CONFIRM_RESET_INSTANCES") end
    return
  end
  if a == "map" or a == "atlas" or a == "loot" or a == "al" then
    if type(Dungeon_OpenMap) == "function" then Dungeon_OpenMap()
    else msg(L("Map pane is not ready", "地图页未就绪")) end
    return
  end
  if a == "help" or a == "?" then
    msg(L("/gd open  /gd reset  /gd map. Inside an instance, /gd opens on the map. Click a gold legend line for loot.",
          "/gd 打开  /gd reset 重置  /gd map 地图。在副本里 /gd 直接打开地图。点金色图例看掉落。"))
    return
  end
  Toggle()
end

BINDING_HEADER_DUNGEON = L("Dungeon", "副本")
BINDING_NAME_DUNGEON_TOGGLE = L("Toggle dungeon hub", "开关副本中心")

-- ------------------------------------------------------------- pfUI skin ---

local function SkinDungeon()
  if not SoloSkin then return end
  SoloSkin.Backdrop(f)
  SoloSkin.Controls(f)
  SoloSkin.Button(close)
  local i = 1
  if DungeonHub and DungeonHub.modeButtons then
    while DungeonHub.modeButtons[i] do
      SoloSkin.Button(DungeonHub.modeButtons[i])
      i = i + 1
    end
  end
  i = 1
  while resetBtns[i] do
    SoloSkin.Button(resetBtns[i])
    i = i + 1
  end
  local _, class = UnitClass("player")
  local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] or { r = 1, g = 1, b = 1 }
  i = 1
  while dui.rows[i] do
    local row = dui.rows[i]
    row:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
    local ht = row:GetHighlightTexture()
    if ht then ht:SetVertexColor(c.r, c.g, c.b, .2) end
    i = i + 1
  end
  if DungeonMapDropDown and SoloSkin.Controls then
    SoloSkin.Controls(DungeonMapPane)
  end
end

if SoloSkin and SoloSkin.Register then
  SoloSkin.Register("Dungeon", SkinDungeon)
end
if pfUI and pfUI.RegisterSkin and not (pfUI.skin and pfUI.skin["Dungeon"]) then
  pfUI:RegisterSkin("Dungeon", "vanilla", SkinDungeon)
end

-- ----------------------------------------------------------------- events --

local ev = CreateFrame("Frame")
ev:RegisterEvent("VARIABLES_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  if event == "VARIABLES_LOADED" then
    InitDB()
    if db.point then
      f:ClearAllPoints()
      f:SetPoint(db.point[1], UIParent, db.point[2], db.point[3], db.point[4])
    end
    PlaceMinimapButton()
    f:Hide()
  elseif event == "PLAYER_LOGIN" then
    -- L was the quest log; Solo shuts that window, so the key is free to take.
    if Solo_EnsureDefaultKey then Solo_EnsureDefaultKey("DUNGEON_TOGGLE", "L", db) end
  end
end)

InitDB()
