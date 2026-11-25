--[[--------------------------------------------------------------------------
GMBox -- a small GM console for WoW 1.12.1 / Lua 5.0, aimed at VMaNGOS.

What it does: a page of common GM commands. One click sends the matching
line. Teleport points live in the Teleport addon (/gt). Items live in the
Items addon (/gi). Instances (including raids) live in the Dungeon addon (/gd).

How the commands get to the server: every button ends up in SendChatMessage()
with a leading dot (SAY when alive, WHISPER-to-self when dead/ghost — the
client refuses SAY then). VMaNGOS's WorldSession::HandleMessagechatOpcode
hands any dot-prefixed chat line to the command parser and never broadcasts
it -- an unknown command answers "There is no such command" rather than
leaking into /say. Nothing here needs a protected/secure context; it is all
plain chat.

Requires a GM account (this realm: gmlevel 6). Without it the server simply
refuses each command.
----------------------------------------------------------------------------]]

local VERSION = "5.0.0"

local ZH = (GetLocale and GetLocale() == "zhCN") and true or false
local function L(en, zh) if ZH and zh then return zh end return en end

local COL = "|cff44ddff"

local function msg(s) DEFAULT_CHAT_FRAME:AddMessage(COL .. "GMBox|r: " .. s) end

-- SAY is refused while dead; a whisper to yourself still reaches the parser.
local function Cmd(s)
  if not s or s == "" then return end
  if string.sub(s, 1, 1) ~= "." then s = "." .. s end
  if string.len(s) > 250 then s = string.sub(s, 1, 250) end
  if UnitIsDeadOrGhost("player") then
    SendChatMessage(s, "WHISPER", nil, UnitName("player"))
  else
    SendChatMessage(s, "SAY")
  end
  return s
end

-- ------------------------------------------------------------- saved vars --

GMBoxDB = nil
local db

local function InitDB()
  if type(GMBoxDB) ~= "table" then GMBoxDB = {} end
  db = GMBoxDB
  if type(db.mmAngle) ~= "number" then db.mmAngle = 200 end
end

-- ------------------------------------------------------------- the frame ---

local function Backdrop(frame)
  frame:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
end

local skin = { buttons = {}, edits = {}, on = false }

local btnSeq = 0
local function Button(parent, w, h, text, point, rel, relPoint, x, y)
  btnSeq = btnSeq + 1
  local b = CreateFrame("Button", "GMBoxButton" .. btnSeq, parent, "UIPanelButtonTemplate")
  b:SetWidth(w) b:SetHeight(h) b:SetText(text)
  b:SetPoint(point, rel, relPoint, x, y)
  table.insert(skin.buttons, b)
  return b
end

local function Label(parent, text, font, point, rel, relPoint, x, y)
  local fs = parent:CreateFontString(nil, "ARTWORK", font or "GameFontNormalSmall")
  fs:SetText(text)
  fs:SetPoint(point, rel, relPoint, x, y)
  return fs
end

local function MarkCurrent(b, current)
  if skin.on then
    b:Enable()
    if current then b:LockHighlight() else b:UnlockHighlight() end
  else
    if current then b:Disable() else b:Enable() end
  end
end

local f = CreateFrame("Frame", "GMBoxFrame", UIParent)
f:SetWidth(600) f:SetHeight(440)
f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
Backdrop(f)
f:SetMovable(true) f:EnableMouse(true) f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", function() this:StartMoving() end)
f:SetScript("OnDragStop", function()
  this:StopMovingOrSizing()
  local point, _, relPoint, x, y = this:GetPoint()
  db.point = { point, relPoint, x, y }
end)
if f.SetClampedToScreen then f:SetClampedToScreen(true) end
f:Hide()
tinsert(UISpecialFrames, "GMBoxFrame")

Label(f, L("GM Tools ", "GM 工具 ") .. VERSION, "GameFontNormal", "TOP", f, "TOP", 0, -14)

local close = CreateFrame("Button", "GMBoxClose", f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)

local tools = CreateFrame("Frame", nil, f)
tools:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -40)
tools:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 16)

-- Each entry is { label, command, chinese label }. "%s" is replaced by the
-- player-name box below the grid.
local TOOLROWS = {
  { L("GM mode", "GM 模式"), {
    { "GM on", ".gm on", "开 GM" }, { "GM off", ".gm off", "关 GM" },
    { "Invis on", ".gm visible off", "隐身" }, { "Invis off", ".gm visible on", "现身" },
  } },
  { L("Cheats", "作弊"), {
    { "God on", ".cheat god on", "无敌开" }, { "God off", ".cheat god off", "无敌关" },
    { "Fly on", ".cheat fly on", "飞行开" }, { "Fly off", ".cheat fly off", "飞行关" },
  } },
  { L("More cheats", "更多"), {
    { "Waterwalk", ".cheat waterwalk on", "水上行走" },
    { "No waterwalk", ".cheat waterwalk off", "取消水行" },
    { "All taxis", ".taxicheat on", "全飞行点" },
    { "Explore map", ".explorecheat on", "全地图" },
  } },
  { L("Self", "自身"), {
    { "Revive", ".revive", "复活" }, { "Unstuck", ".unstuck", "脱卡" },
    { "Repair", ".repairitems", "修理" }, { "Max skills", ".maxskill", "满技能" },
  } },
  { L("Learn", "学习"), {
    { "My spells", ".learn all_myspells", "本职法术" },
    { "My talents", ".learn all_mytalents", "本职天赋" },
    { "Recipes", ".learn all_recipes", "配方" },
    { "Languages", ".learn all_lang", "语言" },
  } },
  { L("Speed", "移速"), {
    { "1x", ".modify speed 1" }, { "2x", ".modify speed 2" },
    { "4x", ".modify speed 4" }, { "7x", ".modify speed 7" },
  } },
  { L("Money / level", "金钱 / 等级"), {
    { "+10g", ".modify money 100000" }, { "+100g", ".modify money 1000000" },
    { "+1 level", ".levelup 1", "+1 级" }, { "+5 levels", ".levelup 5", "+5 级" },
  } },
  -- Party bots are real player units; go-to / summon use their character names.
  { L("Player", "玩家"), {
    { "Go to", ".goname %s", "去他那" }, { "Summon", ".namego %s", "召来" },
    { "Kill target", ".die", "杀死目标" }, { "Player info", ".pinfo %s", "玩家信息" },
  } },
}

local toolY = -4

local xp = { known = false, personal = 1, server = 2, buttons = {} }
local XPSTEPS = { { 1, "All", "全部" }, { 0.5, "Half", "一半" }, { 0, "Off", "停止" } }
Label(tools, L("Experience", "经验"), "GameFontNormalSmall", "TOPLEFT", tools, "TOPLEFT", 2, toolY)
for c = 1, table.getn(XPSTEPS) do
  local s = XPSTEPS[c]
  local b = Button(tools, 104, 20, L(s[2], s[3]), "TOPLEFT", tools, "TOPLEFT", 96 + (c - 1) * 108, toolY + 3)
  b.rate = s[1]
  b:SetScript("OnClick", function() Cmd(".xprate " .. this.rate) end)
  b:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
    if this.rate == 0 then
      GameTooltip:AddLine(L("Gain no experience; quests pay it in gold", "不再获得经验，任务经验折成金币"))
    else
      GameTooltip:AddLine(L("Experience rate ", "经验倍率 ") .. (xp.server * this.rate) .. L("x", " 倍"))
      if this.rate < 1 then
        GameTooltip:AddLine(L("The quest experience not taken is paid in gold", "少拿的任务经验折成金币"), 0.8, 0.8, 0.8)
      end
    end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  xp.buttons[c] = b
end
xp.status = Label(tools, "", "GameFontHighlightSmall", "TOPLEFT", tools, "TOPLEFT", 96 + 3 * 108 + 4, toolY)
toolY = toolY - 32

local function XpRefresh()
  for c = 1, table.getn(XPSTEPS) do
    MarkCurrent(xp.buttons[c], xp.known and math.abs(XPSTEPS[c][1] - xp.personal) < 0.01)
  end
  if not xp.known then
    xp.status:SetText("")
  elseif xp.personal <= 0 then
    xp.status:SetText(L("now: off", "当前：停止"))
  else
    xp.status:SetText(L("now: ", "当前：") .. (xp.server * xp.personal) .. L("x", " 倍"))
  end
end

local function ParseXpLine(text)
  local _, _, personal, server = string.find(text, "^%[xp%] personal=([%d%.]+) server=([%d%.]+)")
  if not personal then return false end
  xp.personal, xp.server, xp.known = tonumber(personal), tonumber(server), true
  XpRefresh()
  return true
end

for r = 1, table.getn(TOOLROWS) do
  local sect = TOOLROWS[r]
  Label(tools, sect[1], "GameFontNormalSmall", "TOPLEFT", tools, "TOPLEFT", 2, toolY)
  local defs = sect[2]
  for c = 1, table.getn(defs) do
    local b = Button(tools, 104, 20, L(defs[c][1], defs[c][3]), "TOPLEFT", tools, "TOPLEFT",
                     96 + (c - 1) * 108, toolY + 3)
    b.cmd = defs[c][2]
    b:SetScript("OnClick", function()
      local cmd = this.cmd
      if string.find(cmd, "%%s") then
        local who = GMBoxName:GetText()
        if not who or who == "" then
          if UnitExists("target") and UnitIsPlayer("target") then who = UnitName("target") end
        end
        if not who or who == "" then msg(L("type a player name in the box first", "先在下面的框里填玩家名")) return end
        cmd = string.gsub(cmd, "%%s", who)
      end
      msg(Cmd(cmd))
    end)
  end
  toolY = toolY - 32
end

local nameBox = CreateFrame("EditBox", "GMBoxName", tools, "InputBoxTemplate")
table.insert(skin.edits, nameBox)
nameBox:SetWidth(150) nameBox:SetHeight(20)
nameBox:SetPoint("TOPLEFT", tools, "TOPLEFT", 96, toolY - 4)
nameBox:SetAutoFocus(false)
nameBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
nameBox:SetScript("OnEnterPressed", function() this:ClearFocus() end)
Label(tools, L("Player name", "玩家名"), "GameFontNormalSmall", "RIGHT", nameBox, "LEFT", -8, 0)
local grabTarget = Button(tools, 80, 20, L("Use target", "取当前目标"), "LEFT", nameBox, "RIGHT", 8, 0)
grabTarget:SetScript("OnClick", function()
  if UnitExists("target") then nameBox:SetText(UnitName("target"))
  else msg(L("no target", "没有目标")) end
end)

toolY = toolY - 34
local rawBox = CreateFrame("EditBox", "GMBoxRaw", tools, "InputBoxTemplate")
table.insert(skin.edits, rawBox)
rawBox:SetWidth(360) rawBox:SetHeight(20)
rawBox:SetPoint("TOPLEFT", tools, "TOPLEFT", 96, toolY)
rawBox:SetAutoFocus(false)
rawBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
rawBox:SetScript("OnEnterPressed", function()
  local t = this:GetText()
  if t and t ~= "" then msg(Cmd(t)) this:SetText("") end
end)
Label(tools, L("Any command", "任意命令"), "GameFontNormalSmall", "RIGHT", rawBox, "LEFT", -8, 0)
Label(tools, L("(leading dot optional, Enter sends)", "(开头的点可省，回车发送)"), "GameFontDisableSmall",
      "TOPLEFT", rawBox, "BOTTOMLEFT", 0, -2)

-- `[xp]` is this window talking to itself. `[bots]` is hidden by the Bots addon.
local origChatEvent = ChatFrame_OnEvent
function ChatFrame_OnEvent(event)
  if event == "CHAT_MSG_SYSTEM" and arg1 and string.find(arg1, "^%[xp%]") then
    return
  end
  return origChatEvent(event)
end

-- ------------------------------------------------------- minimap button ---

local mm = CreateFrame("Button", "GMBoxMinimapButton", Minimap)
mm:SetWidth(31) mm:SetHeight(31)
mm:SetFrameStrata("MEDIUM")
mm:SetFrameLevel(8)
mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
mm:RegisterForClicks("LeftButtonUp")
mm:RegisterForDrag("LeftButton")
local mmIcon = mm:CreateTexture(nil, "ARTWORK")
-- Wrench for tools; not a gear face (MainMenuMicroButton uses INV_Misc_Gear_01).
mmIcon:SetTexture("Interface\\Icons\\INV_Misc_Wrench_01")
mmIcon:SetWidth(20) mmIcon:SetHeight(20)
mmIcon:SetPoint("TOPLEFT", mm, "TOPLEFT", 7, -5)
local mmBorder = mm:CreateTexture(nil, "OVERLAY")
mmBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
mmBorder:SetWidth(53) mmBorder:SetHeight(53)
mmBorder:SetPoint("TOPLEFT", mm, "TOPLEFT", 0, 0)

local function PlaceMinimapButton()
  local a = math.rad(db and db.mmAngle or 200)
  mm:ClearAllPoints()
  mm:SetPoint("CENTER", Minimap, "CENTER", 80 * math.cos(a), 80 * math.sin(a))
end

mm:SetScript("OnDragStart", function()
  this:SetScript("OnUpdate", function()
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    db.mmAngle = math.deg(math.atan2(py / scale - my, px / scale - mx))
    PlaceMinimapButton()
  end)
end)
mm:SetScript("OnDragStop", function() this:SetScript("OnUpdate", nil) end)
mm:SetScript("OnEnter", function()
  if Solo_StripButtonTip then
    Solo_StripButtonTip(L("GM Tools", "GM 工具"), "GMBOX_TOGGLE")
  else
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText(L("GM Tools", "GM 工具"), 1, 1, 1)
  end
  GameTooltip:Show()
end)
mm:SetScript("OnLeave", function() GameTooltip:Hide() end)

local function Toggle()
  if f:IsVisible() then f:Hide() return end
  f:Show()
  XpRefresh()
  Cmd(".xprate quiet")
end

-- ------------------------------------------------------------- pfUI skin ---
-- pfUI loads before this addon (AtlasLoot pulls it in). !Solo only hands
-- its skin list over on ADDON_LOADED "pfUI", which has already fired, so
-- Register here too or the gold panel buttons stay.

local function SkinGMBox()
  if skin.on or not SoloSkin then return end
  skin.on = true
  SoloSkin.Backdrop(f)
  SoloSkin.Close(close)
  SoloSkin.Controls(f)
  local i = 1
  while skin.buttons[i] do
    SoloSkin.Button(skin.buttons[i])
    i = i + 1
  end
  i = 1
  while skin.edits[i] do
    local e = skin.edits[i]
    e:DisableDrawLayer("BACKGROUND")
    if pfUI and pfUI.api and pfUI.api.CreateBackdrop then
      pfUI.api.CreateBackdrop(e, nil, true)
    end
    e:SetTextInsets(5, 5, 3, 3)
    i = i + 1
  end
  if f:IsVisible() then XpRefresh() end
end

if SoloSkin and SoloSkin.Register then
  SoloSkin.Register("GMBox", SkinGMBox)
end
if pfUI and pfUI.RegisterSkin and not (pfUI.skin and pfUI.skin["GMBox"]) then
  pfUI:RegisterSkin("GMBox", "vanilla", SkinGMBox)
end

mm:SetScript("OnClick", function() Toggle() end)

BINDING_HEADER_GMBOX = L("GM Tools", "GM 工具")
BINDING_NAME_GMBOX_TOGGLE = L("Toggle GM Tools", "开关 GM 工具")
function GMBox_Toggle() Toggle() end

-- ----------------------------------------------------------------- slash ---

local function Help()
  if ZH then
    msg("/gm 开关工具窗口（命令条上也有）")
    msg("物品在 /gi，传送在 /gt，副本中心在 /gd")
  else
    msg("/gm opens or closes the tools window (also on the command strip)")
    msg("items are /gi, teleport is /gt, dungeon hub is /gd")
  end
end

SLASH_GMBOX1 = "/gm"
SLASH_GMBOX2 = "/gmbox"
SlashCmdList["GMBOX"] = function(a)
  a = string.gsub(a or "", "^%s+", "")
  if a == "" then Toggle() return end
  if a == "help" or a == "?" then Help() return end
  if a == "dungeon" or a == "dungeons" or a == "fb" then
    if type(Dungeon_Toggle) == "function" then Dungeon_Toggle()
    else msg(L("dungeon hub is /gd", "副本中心在 /gd")) end
    return
  end
  if a == "tele" or a == "tp" or a == "cs" then
    if type(Teleport_Toggle) == "function" then Teleport_Toggle()
    else msg(L("teleport is /gt", "传送在 /gt")) end
    return
  end
  if a == "item" or a == "items" or a == "wp" then
    if type(Items_Toggle) == "function" then Items_Toggle()
    else msg(L("items are /gi", "物品在 /gi")) end
    return
  end
  if type(Items_Query) == "function" then Items_Query(a)
  else msg(L("items are /gi", "物品在 /gi")) end
end

-- ----------------------------------------------------------------- events --

local ev = CreateFrame("Frame")
ev:RegisterEvent("VARIABLES_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("CHAT_MSG_SYSTEM")
ev:SetScript("OnEvent", function()
  if event == "VARIABLES_LOADED" then
    InitDB()
    if db.point then
      f:ClearAllPoints()
      f:SetPoint(db.point[1], UIParent, db.point[2], db.point[3], db.point[4])
    end
    PlaceMinimapButton()
    f:Hide()
  elseif event == "CHAT_MSG_SYSTEM" then
    ParseXpLine(arg1 or "")
  elseif event == "PLAYER_LOGIN" then
    -- G is free in 1.12 defaults (/gm).
    if Solo_EnsureDefaultKey then Solo_EnsureDefaultKey("GMBOX_TOGGLE", "G", db) end
    if not skin.on then SkinGMBox() end
  end
end)

InitDB()
