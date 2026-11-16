--[[--------------------------------------------------------------------------
Party bots. Calling them needs no GM rights, so this is not part of GMBox
(that addon keeps the dungeon list, which teleports). The round button sits
with the others under the minimap. Left click opens the size menu; right
click sends the bots home.

`.bots fill` takes 2, 3 or 5. Entering a five-player dungeon still fills to
five on its own. Raids are 20 (Zul'Gurub, Ruins of Ahn'Qiraj) or 40 (Molten
Core, Blackwing Lair, Temple of Ahn'Qiraj, Naxxramas); the server does not
fill a raid, so the menu has no raid row.
----------------------------------------------------------------------------]]

local ZH = (GetLocale and GetLocale() == "zhCN") and true or false
local function L(en, zh) if ZH and zh then return zh end return en end

local function Say(text)
  DEFAULT_CHAT_FRAME:AddMessage("|cff44ddff" .. L("Party", "组队") .. "|r: " .. text)
end

-- SAY is refused while dead; a whisper to yourself still reaches the parser.
local function Cmd(s)
  if not s or s == "" then return end
  if string.sub(s, 1, 1) ~= "." then s = "." .. s end
  if UnitIsDeadOrGhost("player") then
    SendChatMessage(s, "WHISPER", nil, UnitName("player"))
  else
    SendChatMessage(s, "SAY")
  end
end

local db
local function InitDB()
  if type(BotsDB) ~= "table" then BotsDB = {} end
  db = BotsDB
end

-- What `.bots status` last reported. `role` is the choice, `playing` the guess.
local bots = { role = "auto", playing = nil, auto = true, known = false }

local ROLES = {
  { key = "auto",   en = "Auto",   zh = "自动" },
  { key = "tank",   en = "Tank",   zh = "坦克" },
  { key = "healer", en = "Healer", zh = "治疗" },
  { key = "dps",    en = "Damage", zh = "输出" },
}
local ROLE_ZH = { tank = "坦克", healer = "治疗", ["melee dps"] = "近战输出",
                  ["ranged dps"] = "远程输出", auto = "自动" }

local function RoleText(r)
  if not r then return "?" end
  if ZH then return ROLE_ZH[r] or r end
  return r
end

local function MarkCurrent(b, current)
  if pfUI and pfUI.api then
    b:Enable()
    if current then b:LockHighlight() else b:UnlockHighlight() end
  else
    if current then b:Disable() else b:Enable() end
  end
end

-- ----------------------------------------------------------------- panel --

local panel = CreateFrame("Frame", "BotsPanel", UIParent)
panel:SetFrameStrata("DIALOG")
panel:SetWidth(336)
panel:SetHeight(168)
panel:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
panel:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 12,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
panel:SetBackdropColor(0, 0, 0, .9)
panel:EnableMouse(true)
panel:SetMovable(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", function() this:StartMoving() end)
panel:SetScript("OnDragStop", function()
  this:StopMovingOrSizing()
  local point, _, relPoint, x, y = this:GetPoint()
  if type(BotsDB) ~= "table" then BotsDB = {} end
  BotsDB.point = { point, relPoint, x, y }
end)
if panel.SetClampedToScreen then panel:SetClampedToScreen(true) end
panel:Hide()
tinsert(UISpecialFrames, "BotsPanel")

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
title:SetPoint("TOP", panel, "TOP", 0, -10)
title:SetText(L("Party", "组队"))

-- A panel button, like the farming menu's rows. The stock close button
-- (UIPanelCloseButton) is skinned by a routine that names its icon
-- globally; a second one aborts the skin, and the menu rows stay vanilla.
local close = CreateFrame("Button", "BotsPanelClose", panel, "UIPanelButtonTemplate")
close:SetWidth(22) close:SetHeight(22)
close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -8)
close:SetText("x")
close:SetScript("OnClick", function() panel:Hide() end)

local status = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
status:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -30)
status:SetWidth(312)
status:SetJustifyH("LEFT")
status:SetText(L("Asking the server...", "正在向服务器查询..."))

local roleButtons = {}
for i = 1, table.getn(ROLES) do
  local r = ROLES[i]
  local b = CreateFrame("Button", "BotsRole" .. i, panel, "UIPanelButtonTemplate")
  b:SetWidth(76) b:SetHeight(20)
  b:SetText(L(r.en, r.zh))
  b:SetPoint("TOPLEFT", panel, "TOPLEFT", 12 + (i - 1) * 80, -48)
  b.role = r.key
  b:SetScript("OnClick", function() Cmd(".bots role " .. this.role) end)
  b:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
    if this.role == "auto" then
      GameTooltip:AddLine(L("Guess from class, talents and shield", "按职业、天赋和是否带盾判断"))
    else
      GameTooltip:AddLine(L("Bots fill the other roles around you", "机器人补齐你之外的职责"))
    end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  roleButtons[i] = b
end

local auto = CreateFrame("CheckButton", "BotsAutoFill", panel, "UICheckButtonTemplate")
auto:SetWidth(22) auto:SetHeight(22)
auto:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -72)
auto:SetScript("OnClick", function()
  Cmd(".bots auto " .. (this:GetChecked() and "on" or "off"))
end)
local autoLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
autoLabel:SetPoint("LEFT", auto, "RIGHT", 0, 0)
autoLabel:SetText(L("Fill to five in dungeons", "进五人副本时补满五人"))

local ORDERS = {
  { L("Come", "过来"), ".partybot cometome", L("Every bot runs to you", "所有机器人跑到你身边") },
  { L("Attack", "集火"), ".partybot attackstart", L("Every bot attacks your target", "所有机器人攻击你的目标") },
  { L("Stop", "停手"), ".partybot attackstop", L("Every bot stops attacking", "所有机器人停止攻击") },
  { L("Pull", "拉怪"), ".partybot pull", L("The tank pulls your target; damage waits 10 s", "坦克去拉你的目标，输出等 10 秒") },
  { L("Hold", "待命"), ".partybot pause", L("Wait here (target one bot to hold only it)", "原地待命（选中某个机器人则只对它）") },
  { L("Resume", "继续"), ".partybot unpause", L("Bots act again", "机器人恢复行动") },
}
for i = 1, table.getn(ORDERS) do
  local c = ORDERS[i]
  local col = math.mod(i - 1, 3)
  local row = math.floor((i - 1) / 3)
  local b = CreateFrame("Button", "BotsOrder" .. i, panel, "UIPanelButtonTemplate")
  b:SetWidth(100) b:SetHeight(20)
  b:SetText(c[1])
  b:SetPoint("TOPLEFT", panel, "TOPLEFT", 12 + col * 106, -104 - row * 24)
  b.cmd, b.tip = c[2], c[3]
  b:SetScript("OnClick", function() Cmd(this.cmd) end)
  b:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_TOP")
    GameTooltip:AddLine(this.tip)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function RefreshPanel()
  for i = 1, table.getn(ROLES) do
    MarkCurrent(roleButtons[i], ROLES[i].key == bots.role)
  end
  auto:SetChecked(bots.auto and 1 or nil)
  if bots.known then
    local guessed = (bots.role == "auto") and L(" (guessed)", "（自动判断）") or ""
    status:SetText(L("You play ", "你是") .. RoleText(bots.playing) .. guessed)
  else
    status:SetText(L("Asking the server...", "正在向服务器查询..."))
  end
end

local function ShowPanel()
  if panel:IsVisible() then
    panel:Hide()
    return
  end
  panel:Show()
  RefreshPanel()
  Cmd(".bots status quiet")
end

-- ------------------------------------------------------------------ menu --

local menu = CreateFrame("Frame", "BotsMenu", UIParent)
menu:SetFrameStrata("DIALOG")
menu:SetWidth(156)
menu:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 12,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
menu:SetBackdropColor(0, 0, 0, .9)
menu:EnableMouse(true)
menu:Hide()

local menuRows = {
  { L("Duo", "两人"), function() Cmd(".bots fill 2") end },
  { L("Trio", "三人"), function() Cmd(".bots fill 3") end },
  { L("Party of five", "五人"), function() Cmd(".bots fill 5") end },
  { L("Dismiss", "解散"), function() Cmd(".bots dismiss") end },
  { L("Role and orders", "职责和指挥"), ShowPanel },
}

menu:SetHeight(10 + table.getn(menuRows) * 24)
local menuBtns = {}
local prev
for i = 1, table.getn(menuRows) do
  local row = menuRows[i]
  local b = CreateFrame("Button", "BotsMenuBtn" .. i, menu, "UIPanelButtonTemplate")
  b:SetWidth(140) b:SetHeight(22)
  if prev then
    b:SetPoint("TOP", prev, "BOTTOM", 0, -2)
  else
    b:SetPoint("TOP", menu, "TOP", 0, -6)
  end
  b:SetText(row[1])
  b:SetScript("OnClick", function()
    menu:Hide()
    row[2]()
  end)
  menuBtns[i] = b
  prev = b
end

local function ToggleMenu()
  if menu:IsVisible() then
    menu:Hide()
    return
  end
  panel:Hide()
  -- Same drop-down as the farming menu: under the addon-button strip.
  if Solo_PlaceStripMenu then Solo_PlaceStripMenu(menu, menuBtns) end
  menu:Show()
end

local sink = CreateFrame("Frame", nil, UIParent)
sink:SetFrameStrata("BACKGROUND")
sink:SetAllPoints(UIParent)
sink:EnableMouse(true)
sink:SetScript("OnMouseDown", function()
  if menu:IsVisible() then menu:Hide() end
end)
sink:Hide()
menu:SetScript("OnShow", function() sink:Show() end)
menu:SetScript("OnHide", function() sink:Hide() end)

-- ------------------------------------------------------- minimap button --

local mm = CreateFrame("Button", "BotsMinimapButton", Minimap)
mm:SetWidth(31) mm:SetHeight(31)
mm:SetFrameStrata("MEDIUM")
mm:SetFrameLevel(8)
mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
mm:RegisterForClicks("LeftButtonUp", "RightButtonUp")
mm:RegisterForDrag("LeftButton")
local mmIcon = mm:CreateTexture(nil, "ARTWORK")
mmIcon:SetTexture("Interface\\Icons\\Spell_Holy_PrayerOfHealing")
mmIcon:SetWidth(20) mmIcon:SetHeight(20)
mmIcon:SetPoint("TOPLEFT", mm, "TOPLEFT", 7, -5)
local mmBorder = mm:CreateTexture(nil, "OVERLAY")
mmBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
mmBorder:SetWidth(53) mmBorder:SetHeight(53)
mmBorder:SetPoint("TOPLEFT", mm, "TOPLEFT", 0, 0)

local function PlaceMinimapButton()
  if type(BotsDB) ~= "table" then BotsDB = {} end
  local a = math.rad(BotsDB.mmAngle or 150)
  mm:ClearAllPoints()
  mm:SetPoint("CENTER", Minimap, "CENTER", 80 * math.cos(a), 80 * math.sin(a))
end

mm:SetScript("OnDragStart", function()
  this:SetScript("OnUpdate", function()
    if type(BotsDB) ~= "table" then BotsDB = {} end
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    BotsDB.mmAngle = math.deg(math.atan2(py / scale - my, px / scale - mx))
    PlaceMinimapButton()
  end)
end)
mm:SetScript("OnDragStop", function() this:SetScript("OnUpdate", nil) end)
mm:SetScript("OnClick", function()
  if arg1 == "RightButton" then
    menu:Hide()
    Cmd(".bots dismiss")
    return
  end
  ToggleMenu()
end)
mm:SetScript("OnEnter", function()
  GameTooltip:SetOwner(this, "ANCHOR_LEFT")
  GameTooltip:AddLine(L("Party", "组队"))
  GameTooltip:AddLine(L("Left: duo, trio or five", "左键：两人、三人或五人"), .8, .8, .8)
  GameTooltip:AddLine(L("Right: dismiss", "右键：解散"), .8, .8, .8)
  GameTooltip:AddLine(L("Drag: move", "拖动：移动"), .7, .7, .7)
  GameTooltip:Show()
end)
mm:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- ----------------------------------------------------------------- slash --

local function Help()
  Say(L("/zd opens the menu. /zd 2, /zd 3, /zd 5 call that many. /zd x sends them home.",
        "/zd 打开菜单。/zd 2、/zd 3、/zd 5 按人数叫人。/zd x 解散。"))
end

SLASH_BOTS1 = "/zd"
SLASH_BOTS2 = "/bots"
SlashCmdList["BOTS"] = function(msg)
  msg = string.gsub(msg or "", "^%s+", "")
  while string.sub(msg, -1) == " " do msg = string.sub(msg, 1, -2) end
  if msg == "2" or msg == "3" or msg == "5" then Cmd(".bots fill " .. msg) return end
  if msg == "x" or msg == "stop" or msg == "dismiss" then Cmd(".bots dismiss") return end
  if msg == "role" or msg == "panel" then ShowPanel() return end
  if msg == "" then ToggleMenu() return end
  Help()
end

-- ----------------------------------------------------------- server line --
-- `.bots status` starts with "[bots] role=tank playing=tank auto=1".
-- Kept out of the chat window; the human lines after it still show.

local function ParseBotsLine(text)
  local _, _, role, playing, autoOn = string.find(text, "^%[bots%] role=(.-) playing=(.-) auto=(%d)")
  if not role then return false end
  if role == "melee dps" or role == "ranged dps" then role = "dps" end
  bots.role, bots.playing, bots.auto, bots.known = role, playing, autoOn == "1", true
  if panel:IsVisible() then RefreshPanel() end
  return true
end

local origChatEvent = ChatFrame_OnEvent
function ChatFrame_OnEvent(event)
  if event == "CHAT_MSG_SYSTEM" and arg1 and string.find(arg1, "^%[bots%]") then
    return
  end
  return origChatEvent(event)
end

-- pfUI loads before this addon (AtlasLoot pulls it in). !Solo only hands
-- its skin list over on ADDON_LOADED "pfUI", which has already fired, so a
-- Register here never reaches pfUI and the menu keeps the gold button art.
local function SkinBots()
  SoloSkin.Backdrop(menu)
  SoloSkin.Controls(menu)
  local i = 1
  while menuBtns[i] do
    SoloSkin.Button(menuBtns[i])
    i = i + 1
  end
  SoloSkin.Backdrop(panel)
  SoloSkin.Controls(panel)
  SoloSkin.Button(close)
  i = 1
  while roleButtons[i] do
    SoloSkin.Button(roleButtons[i])
    i = i + 1
  end
  i = 1
  while i <= table.getn(ORDERS) do
    SoloSkin.Button(getglobal("BotsOrder" .. i))
    i = i + 1
  end
end

if SoloSkin and SoloSkin.Register then
  SoloSkin.Register("Bots", SkinBots)
end
if pfUI and pfUI.RegisterSkin and not (pfUI.skin and pfUI.skin["Bots"]) then
  pfUI:RegisterSkin("Bots", "vanilla", SkinBots)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("VARIABLES_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("CHAT_MSG_SYSTEM")
ev:SetScript("OnEvent", function()
  if event == "VARIABLES_LOADED" then
    InitDB()
    if db.point then
      panel:ClearAllPoints()
      panel:SetPoint(db.point[1], UIParent, db.point[2], db.point[3], db.point[4])
    end
    PlaceMinimapButton()
  elseif event == "PLAYER_ENTERING_WORLD" then
    if not bots.known then Cmd(".bots status quiet") end
  elseif event == "CHAT_MSG_SYSTEM" and arg1 then
    ParseBotsLine(arg1)
  end
end)

InitDB()
