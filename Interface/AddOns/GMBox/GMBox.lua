--[[--------------------------------------------------------------------------
GMBox -- a small GM console for WoW 1.12.1 / Lua 5.0, aimed at VMaNGOS.

What it does: search the server's 20034 items by name and fire the matching
GM command with one click, plus a page of common commands. The item database
is baked into Data_Items.lua (dumped straight from the world DB), so searching
needs no server round trip and works while you are loading.

Teleport points live in the Teleport addon (/gt). Five-player instances live
in the Dungeon addon (/gd).

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

local VERSION = "4.0.0"

-- The realm's world DB carries Simplified Chinese for ~89% of items, so on a
-- zhCN client the addon searches and shows Chinese names and labels. The 1.12
-- Chinese client reads UTF-8, which is what Data_Items.lua is written in.
local ZH = (GetLocale and GetLocale() == "zhCN") and true or false
local function L(en, zh) if ZH and zh then return zh end return en end

local ROWS      = 16     -- visible result rows
local ROW_H     = 15
local MAX_HITS  = 400    -- cap on search results, keeps sorting cheap
local MAX_RECENT = 12

local COL = "|cff44ddff"                    -- addon colour, used in chat output
local QCOLOR = {                            -- item quality -> rgb
  [0] = { 0.62, 0.62, 0.62 }, [1] = { 1.00, 1.00, 1.00 },
  [2] = { 0.12, 1.00, 0.00 }, [3] = { 0.00, 0.44, 0.87 },
  [4] = { 0.64, 0.21, 0.93 }, [5] = { 1.00, 0.50, 0.00 },
  [6] = { 0.90, 0.80, 0.50 }, [7] = { 0.90, 0.80, 0.50 },
}

local function msg(s) DEFAULT_CHAT_FRAME:AddMessage(COL .. "GMBox|r: " .. s) end

-- ---------------------------------------------------------------- sending --

-- Benilla (and the 1.12 client) refuse SAY/YELL/EMOTE while dead or ghost
-- (ERR_CHAT_WHILE_DEAD). Whisper is allowed; the server still parses a leading
-- dot before any channel broadcast, so self-whisper works for .revive etc.
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
  if type(db.favItem)    ~= "table"  then db.favItem = {} end
  if type(db.recentItem) ~= "table"  then db.recentItem = {} end
  if type(db.count)      ~= "number" then db.count = 1 end
  if type(db.tab)        ~= "number" then db.tab = 1 end
  if type(db.mmAngle)    ~= "number" then db.mmAngle = 200 end
  if not db.version or db.version < 4 then
    -- Tabs were Teleport / Items / [Dungeons] / Tools. Teleport is its own
    -- addon now, so Items is 1 and Tools is 2. Old favourites stay on
    -- GMBoxDB until the Teleport addon copies them.
    if db.tab == 2 then db.tab = 1
    elseif db.tab and db.tab >= 3 then db.tab = 2
    else db.tab = 1 end
    db.version = 4
  end
end

local function ListFind(t, v)
  for i = 1, table.getn(t) do if t[i] == v then return i end end
  return nil
end

local function Remember(t, v)
  local i = ListFind(t, v)
  if i then table.remove(t, i) end
  table.insert(t, 1, v)
  while table.getn(t) > MAX_RECENT do table.remove(t) end
end

local function ToggleFav(t, v)
  local i = ListFind(t, v)
  if i then table.remove(t, i) return false end
  table.insert(t, v)
  return true
end

-- ------------------------------------------------------------- search ------
-- Lowercase copies are built once, on first use: 20k string.lower() calls are
-- cheap enough as a one-off but not per keystroke.

local itemLower, itemById, itemZH

local function BuildItems()
  if itemLower then return end
  itemLower, itemById = {}, {}
  itemZH = GMBox_ItemNameZH and { GMBox_ItemNameZH } or nil   -- alternate names for Search()
  local names = GMBox_ItemName
  for i = 1, table.getn(names) do
    itemLower[i] = string.lower(names[i])
    itemById[GMBox_ItemID[i]] = i
  end
end

local function ItemQuality(i)
  return tonumber(string.sub(GMBox_ItemQuality, i, i)) or 1
end

-- The packed per-item columns (see Data_Items.lua): one char = 0..92, two
-- chars = 0..8648, from an alphabet of ASCII 32..126 without " and \.
local function Dec1(str, i)
  local b = string.byte(str, i)
  if not b then return 0 end
  if b > 92 then b = b - 1 end
  if b > 34 then b = b - 1 end
  return b - 32
end
local function Dec2(str, i) return Dec1(str, 2 * i - 1) * 93 + Dec1(str, 2 * i) end
local function HasBit(mask, bit) return math.mod(math.floor(mask / bit), 2) == 1 end

local CLASS_ID = { WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5,
                   SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11 }
local RACE_ID = { Human = 1, Orc = 2, Dwarf = 3, NightElf = 4, Scourge = 5,
                  Tauren = 6, Gnome = 7, Troll = 8 }
local ARMOR_RANK = { a = 1, b = 2, c = 3, d = 4 }   -- cloth, leather, mail, plate

-- "Can my character use this": class and race masks, required level, the
-- heaviest armour the class wears at this level, and shields.
local me = {}
local function RefreshMe()
  local _, cls = UnitClass("player")
  local _, race = UnitRace("player")
  me.level = UnitLevel("player") or 1
  me.classBit = math.pow(2, (CLASS_ID[cls or ""] or 1) - 1)
  me.raceBit = math.pow(2, (RACE_ID[race or ""] or 1) - 1)
  local heavy = me.level >= 40
  if cls == "WARRIOR" or cls == "PALADIN" then me.armor = heavy and 4 or 3
  elseif cls == "HUNTER" or cls == "SHAMAN" then me.armor = heavy and 3 or 2
  elseif cls == "ROGUE" or cls == "DRUID" then me.armor = 2
  else me.armor = 1 end
  me.shield = (cls == "WARRIOR" or cls == "PALADIN" or cls == "SHAMAN")
end

local function ItemUsable(i)
  if not GMBox_ItemReqLvl then return true end
  if Dec1(GMBox_ItemReqLvl, i) > me.level then return false end
  if not HasBit(Dec2(GMBox_ItemClass, i), me.classBit) then return false end
  if not HasBit(Dec2(GMBox_ItemRace, i), me.raceBit) then return false end
  local kind = string.sub(GMBox_ItemKind, i, i)
  if kind == "s" then return me.shield end
  local rank = ARMOR_RANK[kind]
  if rank and rank > me.armor then return false end
  return true
end

-- Rank: earlier match wins, then shorter name -- so "iron" finds "Ironforge"
-- before "Fields of Iron", and "Ironforge" before "IronforgeBank".
local sortKey = {}
local function ByRank(a, b) return sortKey[a] < sortKey[b] end

-- `alts` is an optional list of alternate-name tables per index (Chinese name,
-- pinyin), so one pass matches either language. UTF-8 substring search is
-- plain byte search here, which is safe: a multi-byte sequence can never match
-- inside another one.
local function Search(lowered, alts, q, limit)
  local res = {}
  local n = table.getn(lowered)
  local hits = 0
  for i = 1, n do
    local at = string.find(lowered[i], q, 1, true)
    if not at and alts then
      for k = 1, table.getn(alts) do
        local a = alts[k][i]
        if a and a ~= "" then
          at = string.find(a, q, 1, true)
          if at then break end
        end
      end
    end
    if at then
      hits = hits + 1
      res[hits] = i
      sortKey[i] = (at - 1) * 1000 + string.len(lowered[i])
      if hits >= limit then break end
    end
  end
  table.sort(res, ByRank)
  return res
end

-- ------------------------------------------------------------- the frame ---

local rows = {}
local ui = {}
local view = { results = {}, offset = 0, fav = false }

local function Backdrop(f)
  f:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
end

-- Every widget the pfUI skin restyles (see SkinWithPfUI).
local skin = { buttons = {}, checks = {}, edits = {}, rows = {}, on = false }

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

local Refresh, SetTab, RunSearch

local function MarkCurrent(b, current)
  if skin.on then
    b:Enable()
    if current then b:LockHighlight() else b:UnlockHighlight() end
  else
    if current then b:Disable() else b:Enable() end
  end
end

-- current entry under a row, as a small record the click handlers understand
local function RowData(i)
  local idx = view.results[view.offset + i]
  if not idx then return nil end
  local en = GMBox_ItemName[idx]
  local cn = GMBox_ItemNameZH and GMBox_ItemNameZH[idx] or ""
  if cn == "" then cn = nil end
  return { id = GMBox_ItemID[idx], en = en, zh = cn,
           name = (ZH and cn) or en, q = ItemQuality(idx) }
end

local function DoItem(d, count)
  count = count or db.count or 1
  Cmd(".additem " .. d.id .. " " .. count)
  Remember(db.recentItem, d.id)
  msg("+" .. count .. " x " .. d.name .. " (" .. d.id .. ")")
  Refresh()
end

local function RowClick()
  local d = RowData(this.index)
  if not d then return end
  if arg1 == "RightButton" then
    if ToggleFav(db.favItem, d.id) then msg(L("favourite added: ", "已收藏: ") .. d.name)
    else msg(L("favourite removed: ", "已取消收藏: ") .. d.name) end
    Refresh()
    return
  end
  DoItem(d, IsShiftKeyDown() and 1 or nil)
end

local function RowEnter()
  local d = RowData(this.index)
  if not d then return end
  GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
  GameTooltip:SetHyperlink("item:" .. d.id .. ":0:0:0")
  GameTooltip:AddLine(" ")
  local other = ZH and d.en or d.zh
  if other then GameTooltip:AddLine(other, 0.8, 0.8, 0.8) end
  GameTooltip:AddLine("id " .. d.id, 0.6, 0.6, 0.6)
  GameTooltip:AddLine(L("Left click: add   Shift+click: add 1",
                        "左键放入背包   Shift+左键只放 1 个"), 0.4, 0.8, 1)
  GameTooltip:AddLine(L("Right click: toggle favourite", "右键收藏/取消收藏"), 0.4, 0.8, 1)
  GameTooltip:Show()
end

local function RowLeave() GameTooltip:Hide() end

-- ------------------------------------------------------------------ build --

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
tinsert(UISpecialFrames, "GMBoxFrame")   -- Escape closes it

Label(f, L("GM Box ", "GM 工具箱 ") .. VERSION, "GameFontNormal", "TOP", f, "TOP", 0, -14)

local close = CreateFrame("Button", "GMBoxClose", f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)

ui.tabs = {}
local TABS = { L("Items", "物品"), L("Tools", "工具") }
local NTABS = 2
for i = 1, NTABS do
  local b = Button(f, 96, 22, TABS[i], "TOPLEFT", f, "TOPLEFT", 16 + (i - 1) * 100, -34)
  b.index = i
  b:SetScript("OnClick", function() SetTab(this.index) end)
  ui.tabs[i] = b
end

-- search + result list (the Items tab)
local panel = CreateFrame("Frame", nil, f)
panel:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -62)
panel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 16)
panel:EnableMouse(true)
panel:EnableMouseWheel(true)
panel:SetScript("OnMouseWheel", function()
  local step = (arg1 > 0) and -3 or 3
  view.offset = view.offset + step
  Refresh()
end)

ui.search = CreateFrame("EditBox", "GMBoxSearch", panel, "InputBoxTemplate")
table.insert(skin.edits, ui.search)
ui.search:SetWidth(360) ui.search:SetHeight(20)
ui.search:SetPoint("TOPLEFT", panel, "TOPLEFT", 46, 0)
ui.search:SetAutoFocus(false)
ui.search:SetScript("OnTextChanged", function() RunSearch() end)
ui.search:SetScript("OnEscapePressed", function() this:ClearFocus() end)
ui.search:SetScript("OnEnterPressed", function()
  local d = RowData(1)
  if d then DoItem(d) end
end)
Label(panel, L("Find:", "搜索:"), "GameFontNormalSmall", "RIGHT", ui.search, "LEFT", -8, 0)

ui.clear = Button(panel, 52, 20, L("Clear", "清空"), "LEFT", ui.search, "RIGHT", 8, 0)
ui.clear:SetScript("OnClick", function()
  ui.search:SetText("")
  ui.search:ClearFocus()
end)

ui.favOnly = CreateFrame("CheckButton", "GMBoxFavCheck", panel, "UICheckButtonTemplate")
table.insert(skin.checks, ui.favOnly)
ui.favOnly:SetWidth(20) ui.favOnly:SetHeight(20)
ui.favOnly:SetPoint("LEFT", ui.clear, "RIGHT", 6, 0)
ui.favOnly:SetScript("OnClick", function() view.fav = this:GetChecked() and true or false RunSearch() end)
Label(panel, L("fav", "收藏"), "GameFontNormalSmall", "LEFT", ui.favOnly, "RIGHT", 0, 0)

ui.usable = CreateFrame("CheckButton", "GMBoxUsableCheck", panel, "UICheckButtonTemplate")
table.insert(skin.checks, ui.usable)
ui.usable:SetWidth(20) ui.usable:SetHeight(20)
ui.usable:SetPoint("LEFT", ui.favOnly, "RIGHT", 34, 0)
ui.usable:SetScript("OnClick", function() db.usable = this:GetChecked() and true or false RunSearch() end)
ui.usableLabel = Label(panel, L("usable", "我能用"), "GameFontNormalSmall", "LEFT", ui.usable, "RIGHT", 0, 0)

for i = 1, ROWS do
  local b = CreateFrame("Button", "GMBoxRow" .. i, panel)
  b:SetWidth(558) b:SetHeight(ROW_H)
  if i == 1 then b:SetPoint("TOPLEFT", panel, "TOPLEFT", 2, -26)
  else b:SetPoint("TOPLEFT", rows[i - 1], "BOTTOMLEFT", 0, -1) end
  b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
  table.insert(skin.rows, b)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b.index = i
  b:SetScript("OnClick", RowClick)
  b:SetScript("OnEnter", RowEnter)
  b:SetScript("OnLeave", RowLeave)
  b.text = b:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  b.text:SetPoint("LEFT", b, "LEFT", 4, 0)
  b.text:SetJustifyH("LEFT")
  b.text:SetWidth(440)
  b.info = b:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  b.info:SetPoint("RIGHT", b, "RIGHT", -4, 0)
  b.info:SetJustifyH("RIGHT")
  rows[i] = b
end

ui.status = Label(panel, "", "GameFontDisableSmall", "BOTTOMLEFT", panel, "BOTTOMLEFT", 4, 30)

-- footer: how many of the clicked item to add
ui.countLabel = Label(panel, L("Count:", "数量:"), "GameFontNormalSmall", "BOTTOMLEFT", panel, "BOTTOMLEFT", 4, 6)
ui.count = CreateFrame("EditBox", "GMBoxCount", panel, "InputBoxTemplate")
table.insert(skin.edits, ui.count)
ui.count:SetWidth(50) ui.count:SetHeight(20)
ui.count:SetPoint("LEFT", ui.countLabel, "RIGHT", 10, 0)
ui.count:SetAutoFocus(false)
ui.count:SetNumeric(true)
ui.count:SetScript("OnTextChanged", function()
  local v = tonumber(this:GetText())
  if v and v > 0 then db.count = v end
end)
ui.count:SetScript("OnEscapePressed", function() this:ClearFocus() end)
ui.count:SetScript("OnEnterPressed", function() this:ClearFocus() end)

ui.quick = {}
local QUICKN = { 1, 5, 20, 100 }
for i = 1, 4 do
  local b = Button(panel, 34, 20, tostring(QUICKN[i]), "LEFT",
                   (i == 1) and ui.count or ui.quick[i - 1], "RIGHT", 4, 0)
  b.n = QUICKN[i]
  b:SetScript("OnClick", function()
    db.count = this.n
    ui.count:SetText(this.n)
  end)
  ui.quick[i] = b
end

-- ------------------------------------------------------------- tools tab ---

local tools = CreateFrame("Frame", nil, f)
tools:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -62)
tools:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 16)
tools:Hide()

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
  { L("Player", "玩家"), {
    { "Go to", ".goname %s", "去他那" }, { "Summon", ".namego %s", "召来" },
    { "Kill target", ".die", "杀死目标" }, { "Player info", ".pinfo %s", "玩家信息" },
  } },
}

local toolY = -4

-- Experience: `.xprate` scales the server's rate for this character and the
-- server keeps it. Quest experience turned down is paid in gold.
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

-- `.xprate` answers with a machine line first: "[xp] personal=1 server=2 max=1".
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

-- `[xp]` is the tools page talking to itself. `[bots]` is hidden by the Bots addon.
-- Teleports live in the Teleport addon (/gt). Dungeons live in Dungeon (/gd).
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
mm:RegisterForClicks("LeftButtonUp", "RightButtonUp")
mm:RegisterForDrag("LeftButton")
local mmIcon = mm:CreateTexture(nil, "ARTWORK")
mmIcon:SetTexture("Interface\\Icons\\Ability_Warrior_BattleShout")
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
  GameTooltip:SetOwner(this, "ANCHOR_LEFT")
  GameTooltip:AddLine("GM Box")
  GameTooltip:AddLine(L("Left click: open or close", "左键：打开/关闭"), 0.8, 0.8, 0.8)
  GameTooltip:AddLine(L("Drag: move around the minimap", "拖动：沿小地图移动"), 0.8, 0.8, 0.8)
  GameTooltip:AddLine(L("Teleport is /gt", "传送在 /gt"), 0.7, 0.7, 0.7)
  GameTooltip:AddLine(L("Dungeon hub is /gd", "副本中心在 /gd"), 0.7, 0.7, 0.7)
  GameTooltip:Show()
end)
mm:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- ------------------------------------------------------------ list logic ---

local function BaseList()
  -- With an empty search box, show favourites first, then recent picks.
  local res, seen = {}, {}
  local function add(idx)
    if idx and not seen[idx] then seen[idx] = true table.insert(res, idx) end
  end
  if table.getn(db.favItem) == 0 and table.getn(db.recentItem) == 0 then return res end
  BuildItems()   -- 17k lowercase copies, so only pay for it when there is something to show
  for i = 1, table.getn(db.favItem) do add(itemById[db.favItem[i]]) end
  if not view.fav then
    for i = 1, table.getn(db.recentItem) do add(itemById[db.recentItem[i]]) end
  end
  return res
end

local function IsFav(d)
  return ListFind(db.favItem, d.id) ~= nil
end

function Refresh()
  local n = table.getn(view.results)
  local maxOff = n - ROWS
  if maxOff < 0 then maxOff = 0 end
  if view.offset > maxOff then view.offset = maxOff end
  if view.offset < 0 then view.offset = 0 end

  for i = 1, ROWS do
    local b, d = rows[i], RowData(i)
    if d then
      local star = IsFav(d) and "|cffffd100*|r " or ""
      local c = QCOLOR[d.q] or QCOLOR[1]
      b.text:SetText(star .. d.name)
      b.text:SetTextColor(c[1], c[2], c[3])
      b.info:SetText(d.id)
      b:Show()
    else
      b:Hide()
    end
  end

  local shown = n - view.offset
  if shown > ROWS then shown = ROWS end
  if n == 0 then
    ui.status:SetText(L("no match -- type part of an item name, or an item id",
                        "没有匹配 -- 输入物品名（中英文都行）或物品 id"))
  else
    ui.status:SetText(n .. L(" match(es), showing ", " 个匹配，显示第 ") .. (view.offset + 1) .. "-" ..
      (view.offset + shown) .. L("   (mouse wheel scrolls)", " 个   (滚轮翻页)"))
  end
end

function RunSearch()
  local q = string.lower(ui.search:GetText() or "")
  view.offset = 0
  if q == "" then
    view.results = BaseList()
    Refresh()
    return
  end
  BuildItems()
  local id = tonumber(q)
  if id and itemById[id] then
    view.results = { itemById[id] }
  else
    view.results = Search(itemLower, itemZH, q, db.usable and 20000 or MAX_HITS)
  end
  if db.usable then
    RefreshMe()
    local keep = {}
    for i = 1, table.getn(view.results) do
      local idx = view.results[i]
      if ItemUsable(idx) then
        table.insert(keep, idx)
        if table.getn(keep) >= MAX_HITS then break end
      end
    end
    view.results = keep
  end
  if view.fav then
    local keep = {}
    for i = 1, table.getn(view.results) do
      local idx = view.results[i]
      if ListFind(db.favItem, GMBox_ItemID[idx]) then table.insert(keep, idx) end
    end
    view.results = keep
  end
  Refresh()
end

function SetTab(i)
  if i < 1 or i > NTABS then i = 1 end
  db.tab = i
  for t = 1, NTABS do
    MarkCurrent(ui.tabs[t], t == i)
  end
  panel:Hide() tools:Hide()
  if i == 2 then
    tools:Show()
    XpRefresh()
    Cmd(".xprate quiet")
    return
  end
  panel:Show()
  ui.usable:SetChecked(db.usable and 1 or nil)
  ui.count:SetText(db.count)
  RunSearch()
end

local function Toggle(tab, query)
  if tab then db.tab = tab end
  if not f:IsVisible() then f:Show() elseif not query and not tab then f:Hide() return end
  SetTab(db.tab)
  if db.tab > 1 then return end
  if query then
    ui.search:SetText(query)
    ui.search:SetFocus()
  end
  RunSearch()
end

-- --------------------------------------------------------------- bindings --

-- ------------------------------------------------------------- pfUI skin ---
-- With pfUI loaded, the window looks like pfUI's own: its flat backdrop and
-- shadow, its buttons, checkboxes, edit boxes and close button, and the
-- class colour for the current tab and role. GMBox loads before pfUI
-- (folders load by name), so this runs at PLAYER_LOGIN.

local function SkinWithPfUI()
  if skin.on or not (pfUI and pfUI.api and pfUI.api.CreateBackdrop) then return end
  local api = pfUI.api
  skin.on = true

  f:SetBackdrop(nil)
  api.CreateBackdrop(f, nil, nil, .75)
  if api.CreateBackdropShadow then api.CreateBackdropShadow(f) end
  api.SkinCloseButton(close, f, -6, -6)

  for i = 1, table.getn(skin.buttons) do api.SkinButton(skin.buttons[i]) end
  for i = 1, table.getn(skin.checks) do api.SkinCheckbox(skin.checks[i], 14) end
  for i = 1, table.getn(skin.edits) do
    local e = skin.edits[i]
    e:DisableDrawLayer("BACKGROUND")
    api.CreateBackdrop(e, nil, true)
    e:SetTextInsets(5, 5, 3, 3)
  end

  local _, class = UnitClass("player")
  local c = RAID_CLASS_COLORS[class] or { r = 1, g = 1, b = 1 }
  for i = 1, table.getn(skin.rows) do
    skin.rows[i]:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
    skin.rows[i]:GetHighlightTexture():SetVertexColor(c.r, c.g, c.b, .2)
  end

  -- The minimap button keeps its round look: pfUI collects it into the
  -- button row under the minimap next to the other addons' round buttons.

  if f:IsVisible() then SetTab(db.tab) end
end

mm:SetScript("OnClick", function()
  Toggle()
end)

BINDING_HEADER_GMBOX = "GM Box"
BINDING_NAME_GMBOX_TOGGLE = "Toggle GM Box"
function GMBox_Toggle() Toggle() end

-- ----------------------------------------------------------------- slash ---

local function Help()
  if ZH then
    msg("命令:")
    msg("  /gm            开关窗口（小地图上也有按钮）")
    msg("  /gi <文字|id> [数量]   物品: 唯一匹配直接进包（中英文名都能搜）")
    msg("  传送在 /gt（Teleport 插件），副本中心在 /gd")
    msg("列表里: 左键放入背包，Shift+左键只放 1 个，右键收藏")
  else
    msg("commands:")
    msg("  /gm            open or close the window (or the minimap button)")
    msg("  /gi <text|id> [count]   item: one match goes straight into your bags")
    msg("  teleport is /gt (Teleport addon), dungeon hub is /gd")
    msg("in the list: left click adds it, shift+click adds 1, right click favourites")
  end
end

SLASH_GMBOX1 = "/gm"
SLASH_GMBOX2 = "/gmbox"
SlashCmdList["GMBOX"] = function(a)
  a = a or ""
  if a == "help" or a == "?" then Help() return end
  if a == "dungeon" or a == "dungeons" or a == "fb" then
    if type(Dungeon_Toggle) == "function" then Dungeon_Toggle()
    else msg(L("install the Dungeon addon for /gd", "副本列表在 Dungeon 插件（/gd）")) end
    return
  end
  if a == "tele" or a == "tp" or a == "cs" then
    if type(Teleport_Toggle) == "function" then Teleport_Toggle()
    else msg(L("teleport is the Teleport addon (/gt)", "传送在 Teleport 插件（/gt）")) end
    return
  end
  if a ~= "" then Toggle(nil, a) else Toggle() end
end

SLASH_GMBOXITEM1 = "/gi"
SlashCmdList["GMBOXITEM"] = function(a)
  a = string.gsub(a or "", "^%s+", "")
  if a == "" then Toggle(1) return end
  BuildItems()
  -- trailing number is a count, unless the whole argument is a number (= item id)
  local count, name = nil, a
  if not tonumber(a) then
    local at, _, digits = string.find(a, "%s+(%d+)$")
    if at then
      count = tonumber(digits)
      name = string.sub(a, 1, at - 1)
    end
  end
  local id = tonumber(name)
  if id then
    local i = itemById[id]
    if not i then msg(L("no item with id ", "没有这个 id 的物品: ") .. id) return end
    DoItem({ kind = "item", id = GMBox_ItemID[i], name = GMBox_ItemName[i] }, count)
    return
  end
  local res = Search(itemLower, itemZH, string.lower(name), MAX_HITS)
  if table.getn(res) == 0 then msg(L("no item matches '", "没有物品匹配 '") .. name .. "'") return end
  local top = res[1]
  local exact = string.lower(GMBox_ItemName[top]) == string.lower(name)
             or (GMBox_ItemNameZH and GMBox_ItemNameZH[top] == name)
  if table.getn(res) == 1 or exact then
    local i = res[1]
    DoItem({ kind = "item", id = GMBox_ItemID[i], name = GMBox_ItemName[i] }, count)
    return
  end
  if count then db.count = count end
  Toggle(1, name)
end

-- ----------------------------------------------------------------- events --

local ev = CreateFrame("Frame")
ev:RegisterEvent("VARIABLES_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("CHAT_MSG_SYSTEM")
ev:SetScript("OnEvent", function()
  if event == "VARIABLES_LOADED" then
    InitDB()
    ui.count:SetText(db.count)
    if db.point then
      f:ClearAllPoints()
      f:SetPoint(db.point[1], UIParent, db.point[2], db.point[3], db.point[4])
    end
    PlaceMinimapButton()
    f:Hide()
  elseif event == "CHAT_MSG_SYSTEM" then
    ParseXpLine(arg1 or "")
  elseif event == "PLAYER_LOGIN" then
    SkinWithPfUI()
    if ZH then
      msg("就绪 -- " .. table.getn(GMBox_ItemID) .. " 件物品。/gm 打开，/gm help 看用法。传送在 /gt。")
    else
      msg("ready -- " .. table.getn(GMBox_ItemID) .. " items. /gm to open, /gm help for the rest. Teleport is /gt.")
    end
  end
end)

InitDB()   -- so the UI is usable even before VARIABLES_LOADED fires
