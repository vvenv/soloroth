--[[--------------------------------------------------------------------------
Items -- the server's item_template list, on its own.

Formerly the GMBox "Items" tab and /gi. Teleports are the Teleport addon
(/gt). GM tools stay in GMBox (/gm). Five-player instances stay in Dungeon
(/gd).

Data_Items.lua (loaded first) still publishes GMBox_ItemID, GMBox_ItemName,
GMBox_ItemNameZH, GMBox_ItemNamePY and the packed filter columns. Those names
are what the generator writes. A zhCN client shows the Chinese name when
there is one; search matches English, Chinese, or pinyin (initials or full);
the id is what `.additem` sends.
----------------------------------------------------------------------------]]

local VERSION = "1.0.0"

local ZH = (GetLocale and GetLocale() == "zhCN") and true or false
local function L(en, zh) if ZH and zh then return zh end return en end

local ROWS      = 18
local ROW_H     = 15
local MAX_HITS  = 400
local MAX_RECENT = 12

local COL = "|cff44ddff"
local QCOLOR = {
  [0] = { 0.62, 0.62, 0.62 }, [1] = { 1.00, 1.00, 1.00 },
  [2] = { 0.12, 1.00, 0.00 }, [3] = { 0.00, 0.44, 0.87 },
  [4] = { 0.64, 0.21, 0.93 }, [5] = { 1.00, 0.50, 0.00 },
  [6] = { 0.90, 0.80, 0.50 }, [7] = { 0.90, 0.80, 0.50 },
}

local function msg(s) DEFAULT_CHAT_FRAME:AddMessage(COL .. L("Items", "物品") .. "|r: " .. s) end

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

ItemsDB = nil
local db

local function InitDB()
  if type(ItemsDB) ~= "table" then ItemsDB = {} end
  db = ItemsDB
  if type(db.fav) ~= "table" then db.fav = {} end
  if type(db.recent) ~= "table" then db.recent = {} end
  if type(db.count) ~= "number" or db.count < 1 then db.count = 1 end
  if type(db.mmAngle) ~= "number" then db.mmAngle = 70 end
end

local function TakeList(dst, src)
  if type(src) ~= "table" or table.getn(dst) > 0 then return end
  local i = 1
  while src[i] do
    table.insert(dst, src[i])
    i = i + 1
  end
end

-- GMBox used to own this list. Copy once, after saved variables exist.
local function MigrateFromGMBox()
  if db.took or type(GMBoxDB) ~= "table" then return end
  TakeList(db.fav, GMBoxDB.favItem)
  TakeList(db.recent, GMBoxDB.recentItem)
  if type(GMBoxDB.count) == "number" and GMBoxDB.count > 0 then db.count = GMBoxDB.count end
  if GMBoxDB.usable then db.usable = true end
  GMBoxDB.favItem = nil
  GMBoxDB.recentItem = nil
  GMBoxDB.count = nil
  GMBoxDB.usable = nil
  db.took = true
end

local function ListFind(t, v)
  for i = 1, table.getn(t) do if t[i] == v then return i end end
  return nil
end

local function Remember(v)
  local i = ListFind(db.recent, v)
  if i then table.remove(db.recent, i) end
  table.insert(db.recent, 1, v)
  while table.getn(db.recent) > MAX_RECENT do table.remove(db.recent) end
end

local function ToggleFav(v)
  local i = ListFind(db.fav, v)
  if i then table.remove(db.fav, i) return false end
  table.insert(db.fav, v)
  return true
end

-- ------------------------------------------------------------- search ------

local itemLower, itemById, itemAlts

local function BuildItems()
  if itemLower then return end
  itemLower, itemById = {}, {}
  -- Same shape as Teleport's TELE_ALTS: Chinese names + "initials fullpinyin".
  itemAlts = {}
  if GMBox_ItemNameZH then table.insert(itemAlts, GMBox_ItemNameZH) end
  if GMBox_ItemNamePY then table.insert(itemAlts, GMBox_ItemNamePY) end
  local names = GMBox_ItemName or {}
  for i = 1, table.getn(names) do
    itemLower[i] = string.lower(names[i])
    itemById[GMBox_ItemID[i]] = i
  end
end

local function ItemQuality(i)
  return tonumber(string.sub(GMBox_ItemQuality or "", i, i)) or 1
end

-- Packed columns: one char = 0..92, two chars = 0..8648. Alphabet is
-- ASCII 32..126 without " and \.
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
local ARMOR_RANK = { a = 1, b = 2, c = 3, d = 4 }

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

local function ItemShow(i)
  local cn = GMBox_ItemNameZH and GMBox_ItemNameZH[i] or ""
  if ZH and cn ~= "" then return cn end
  return GMBox_ItemName[i]
end

local sortKey = {}
local function ByRank(a, b) return sortKey[a] < sortKey[b] end

local function Search(q, limit)
  local res = {}
  local hits = 0
  local n = table.getn(itemLower)
  local nAlt = table.getn(itemAlts)
  for i = 1, n do
    local at = string.find(itemLower[i], q, 1, true)
    if not at then
      for k = 1, nAlt do
        local a = itemAlts[k][i]
        if a and a ~= "" then
          at = string.find(a, q, 1, true)
          if at then break end
        end
      end
    end
    if at then
      hits = hits + 1
      res[hits] = i
      sortKey[i] = (at - 1) * 1000 + string.len(itemLower[i])
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

local function Backdrop(frame)
  frame:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
end

local btnSeq = 0
local function Button(parent, w, h, text, point, rel, relPoint, x, y)
  btnSeq = btnSeq + 1
  local b = CreateFrame("Button", "ItemsButton" .. btnSeq, parent, "UIPanelButtonTemplate")
  b:SetWidth(w) b:SetHeight(h) b:SetText(text)
  b:SetPoint(point, rel, relPoint, x, y)
  return b
end

local function Label(parent, text, font, point, rel, relPoint, x, y)
  local fs = parent:CreateFontString(nil, "ARTWORK", font or "GameFontNormalSmall")
  fs:SetText(text)
  fs:SetPoint(point, rel, relPoint, x, y)
  return fs
end

local Refresh, RunSearch

local function RowData(i)
  local idx = view.results[view.offset + i]
  if not idx then return nil end
  local en = GMBox_ItemName[idx]
  local cn = GMBox_ItemNameZH and GMBox_ItemNameZH[idx] or ""
  if cn == "" then cn = nil end
  return { id = GMBox_ItemID[idx], en = en, zh = cn, name = ItemShow(idx), q = ItemQuality(idx) }
end

local function DoItem(d, count)
  count = count or db.count or 1
  Cmd(".additem " .. d.id .. " " .. count)
  Remember(d.id)
  msg("+" .. count .. " x " .. d.name .. " (" .. d.id .. ")")
  Refresh()
end

local function RowClick()
  local d = RowData(this.index)
  if not d then return end
  if arg1 == "RightButton" then
    if ToggleFav(d.id) then msg(L("favourite added: ", "已收藏: ") .. d.name)
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

local f = CreateFrame("Frame", "ItemsFrame", UIParent)
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
f:EnableMouseWheel(true)
f:SetScript("OnMouseWheel", function()
  view.offset = view.offset + ((arg1 > 0) and -3 or 3)
  Refresh()
end)
f:Hide()
tinsert(UISpecialFrames, "ItemsFrame")

Label(f, L("Items ", "物品 ") .. VERSION, "GameFontNormal", "TOP", f, "TOP", 0, -14)

local close = CreateFrame("Button", "ItemsClose", f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)

ui.search = CreateFrame("EditBox", "ItemsSearch", f, "InputBoxTemplate")
ui.search:SetWidth(280) ui.search:SetHeight(20)
ui.search:SetPoint("TOPLEFT", f, "TOPLEFT", 70, -36)
ui.search:SetAutoFocus(false)
ui.search:SetScript("OnTextChanged", function() RunSearch() end)
ui.search:SetScript("OnEscapePressed", function() this:ClearFocus() end)
ui.search:SetScript("OnEnterPressed", function()
  local d = RowData(1)
  if d then DoItem(d) end
end)
Label(f, L("Find:", "搜索:"), "GameFontNormalSmall", "RIGHT", ui.search, "LEFT", -8, 0)

ui.clear = Button(f, 52, 20, L("Clear", "清空"), "LEFT", ui.search, "RIGHT", 8, 0)
ui.clear:SetScript("OnClick", function()
  ui.search:SetText("")
  ui.search:ClearFocus()
end)

ui.favOnly = CreateFrame("CheckButton", "ItemsFavCheck", f, "UICheckButtonTemplate")
ui.favOnly:SetWidth(22) ui.favOnly:SetHeight(22)
ui.favOnly:SetPoint("LEFT", ui.clear, "RIGHT", 6, 0)
ui.favOnly:SetScript("OnClick", function()
  view.fav = this:GetChecked() and true or false
  RunSearch()
end)
Label(f, L("fav", "收藏"), "GameFontNormalSmall", "LEFT", ui.favOnly, "RIGHT", 0, 0)

ui.usable = CreateFrame("CheckButton", "ItemsUsableCheck", f, "UICheckButtonTemplate")
ui.usable:SetWidth(22) ui.usable:SetHeight(22)
ui.usable:SetPoint("LEFT", ui.favOnly, "RIGHT", 36, 0)
ui.usable:SetScript("OnClick", function()
  db.usable = this:GetChecked() and true or false
  RunSearch()
end)
Label(f, L("usable", "我能用"), "GameFontNormalSmall", "LEFT", ui.usable, "RIGHT", 0, 0)

for i = 1, ROWS do
  local b = CreateFrame("Button", "ItemsRow" .. i, f)
  b:SetWidth(558) b:SetHeight(ROW_H)
  if i == 1 then b:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -64)
  else b:SetPoint("TOPLEFT", rows[i - 1], "BOTTOMLEFT", 0, -1) end
  b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b.index = i
  b:SetScript("OnClick", RowClick)
  b:SetScript("OnEnter", RowEnter)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  b.text = b:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  b.text:SetPoint("LEFT", b, "LEFT", 4, 0)
  b.text:SetJustifyH("LEFT")
  b.text:SetWidth(440)
  b.info = b:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  b.info:SetPoint("RIGHT", b, "RIGHT", -4, 0)
  b.info:SetJustifyH("RIGHT")
  rows[i] = b
end

ui.status = Label(f, "", "GameFontDisableSmall", "BOTTOMLEFT", f, "BOTTOMLEFT", 20, 56)

ui.countLabel = Label(f, L("Count:", "数量:"), "GameFontNormalSmall", "BOTTOMLEFT", f, "BOTTOMLEFT", 20, 22)
ui.count = CreateFrame("EditBox", "ItemsCount", f, "InputBoxTemplate")
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
  local b = Button(f, 34, 20, tostring(QUICKN[i]), "LEFT",
                   (i == 1) and ui.count or ui.quick[i - 1], "RIGHT", 4, 0)
  b.n = QUICKN[i]
  b:SetScript("OnClick", function()
    db.count = this.n
    ui.count:SetText(this.n)
  end)
  ui.quick[i] = b
end

-- ------------------------------------------------------- minimap button ---

local mm = CreateFrame("Button", "ItemsMinimapButton", Minimap)
mm:SetWidth(31) mm:SetHeight(31)
mm:SetFrameStrata("MEDIUM")
mm:SetFrameLevel(8)
mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
mm:RegisterForClicks("LeftButtonUp")
mm:RegisterForDrag("LeftButton")
local mmIcon = mm:CreateTexture(nil, "ARTWORK")
mmIcon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
mmIcon:SetWidth(20) mmIcon:SetHeight(20)
mmIcon:SetPoint("TOPLEFT", mm, "TOPLEFT", 7, -5)
local mmBorder = mm:CreateTexture(nil, "OVERLAY")
mmBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
mmBorder:SetWidth(53) mmBorder:SetHeight(53)
mmBorder:SetPoint("TOPLEFT", mm, "TOPLEFT", 0, 0)

local function PlaceMinimapButton()
  local a = math.rad(db and db.mmAngle or 70)
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
    Solo_StripButtonTip(L("Items", "物品"), "ITEMS_TOGGLE")
  else
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText(L("Items", "物品"), 1, 1, 1)
  end
  GameTooltip:Show()
end)
mm:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- ------------------------------------------------------------ list logic ---

local function BaseList()
  local res, seen = {}, {}
  local function add(idx)
    if idx and not seen[idx] then seen[idx] = true table.insert(res, idx) end
  end
  if table.getn(db.fav) == 0 and table.getn(db.recent) == 0 then return res end
  BuildItems()
  for i = 1, table.getn(db.fav) do add(itemById[db.fav[i]]) end
  if not view.fav then
    for i = 1, table.getn(db.recent) do add(itemById[db.recent[i]]) end
  end
  return res
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
      local star = ListFind(db.fav, d.id) and "|cffffd100*|r " or ""
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
                        "没有匹配 -- 输入中文名、拼音首字母/全拼、英文名或物品 id"))
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
    view.results = Search(q, db.usable and 20000 or MAX_HITS)
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
      if ListFind(db.fav, GMBox_ItemID[idx]) then table.insert(keep, idx) end
    end
    view.results = keep
  end
  Refresh()
end

local function Toggle(query)
  if not f:IsVisible() then f:Show()
  elseif not query then f:Hide() return end
  ui.usable:SetChecked(db.usable and 1 or nil)
  ui.count:SetText(db.count)
  if query then
    ui.search:SetText(query)
    ui.search:SetFocus()
  end
  RunSearch()
end

function Items_Toggle() Toggle() end

mm:SetScript("OnClick", function() Toggle() end)

-- ----------------------------------------------------------------- slash ---

local function Help()
  if ZH then
    msg("/gi 开关窗口（命令条上也有）")
    msg("/gi <文字|id> [数量]  唯一匹配直接进包，多个就开列表")
    msg("左键放入背包，Shift+左键只放 1 个，右键收藏")
  else
    msg("/gi opens or closes the window (also on the command strip)")
    msg("/gi <text|id> [count]  one match goes straight into your bags")
    msg("left click adds it, shift+click adds 1, right click favourites")
  end
end

function Items_Query(a)
  a = string.gsub(a or "", "^%s+", "")
  if a == "" or a == "help" or a == "?" then
    if a == "" then Toggle() else Help() end
    return
  end
  BuildItems()
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
    DoItem({ id = GMBox_ItemID[i], name = ItemShow(i) }, count)
    return
  end
  local res = Search(string.lower(name), MAX_HITS)
  if table.getn(res) == 0 then msg(L("no item matches '", "没有物品匹配 '") .. name .. "'") return end
  local top = res[1]
  local exact = string.lower(GMBox_ItemName[top]) == string.lower(name)
             or (GMBox_ItemNameZH and GMBox_ItemNameZH[top] == name)
  if table.getn(res) == 1 or exact then
    DoItem({ id = GMBox_ItemID[top], name = ItemShow(top) }, count)
    return
  end
  if count then db.count = count end
  Toggle(name)
end

SLASH_ITEMS1 = "/gi"
SLASH_ITEMS2 = "/items"
SlashCmdList["ITEMS"] = Items_Query

BINDING_HEADER_ITEMS = L("Items", "物品")
BINDING_NAME_ITEMS_TOGGLE = L("Toggle items", "开关物品")

-- ------------------------------------------------------------- pfUI skin ---

local function SkinItems()
  if not SoloSkin then return end
  SoloSkin.Backdrop(f)
  SoloSkin.Controls(f)
  local _, class = UnitClass("player")
  local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] or { r = 1, g = 1, b = 1 }
  local i = 1
  while rows[i] do
    rows[i]:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
    local ht = rows[i]:GetHighlightTexture()
    if ht then ht:SetVertexColor(c.r, c.g, c.b, .2) end
    i = i + 1
  end
end

if SoloSkin and SoloSkin.Register then
  SoloSkin.Register("Items", SkinItems)
end
if pfUI and pfUI.RegisterSkin and not (pfUI.skin and pfUI.skin["Items"]) then
  pfUI:RegisterSkin("Items", "vanilla", SkinItems)
end

-- ----------------------------------------------------------------- events --

local ev = CreateFrame("Frame")
ev:RegisterEvent("VARIABLES_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  if event == "VARIABLES_LOADED" then
    InitDB()
    MigrateFromGMBox()
    ui.count:SetText(db.count)
    ui.usable:SetChecked(db.usable and 1 or nil)
    if db.point then
      f:ClearAllPoints()
      f:SetPoint(db.point[1], UIParent, db.point[2], db.point[3], db.point[4])
    end
    PlaceMinimapButton()
    f:Hide()
  elseif event == "PLAYER_LOGIN" then
    -- I is free in 1.12 defaults (/gi).
    if Solo_EnsureDefaultKey then Solo_EnsureDefaultKey("ITEMS_TOGGLE", "I", db) end
  end
end)

InitDB()
