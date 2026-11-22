--[[--------------------------------------------------------------------------
Teleport -- the server's game_tele list, on its own.

Formerly the GMBox "Teleport" tab and /gt. Items are the Items addon (/gi).
GM tools stay in GMBox (/gm). Five-player instances stay in Dungeon (/gd).

Data_Tele.lua (loaded first) still publishes GMBox_Tele, GMBox_TeleZH and
GMBox_TelePY. Those names are what the generator writes. The Chinese and
pinyin columns are why a zhCN client can search by hanzi or pinyin; the
English name is what `.tele` expects and is what gets sent.

Data_MapBounds.lua is WorldMapArea.dbc for outdoor maps 0/1. A map click
turns the cursor percent into world XY and picks the nearest game_tele.
----------------------------------------------------------------------------]]

local VERSION = "1.1.0"

local ZH = (GetLocale and GetLocale() == "zhCN") and true or false
local function L(en, zh) if ZH and zh then return zh end return en end

local ROWS      = 18
local ROW_H     = 15
local MAX_HITS  = 400
local MAX_RECENT = 12

local TELE = GMBox_Tele or {}
local TELE_ZH = GMBox_TeleZH or {}
local TELE_PY = GMBox_TelePY or {}
local TELE_ALTS = { TELE_ZH, TELE_PY }
local MAP_BOUNDS = Teleport_MapBounds or {}

local COL = "|cff44ddff"

local MAPNAME = {
  [0] = "Eastern Kingdoms", [1] = "Kalimdor", [13] = "Test",
  [33] = "Shadowfang Keep", [34] = "Stockade", [36] = "Deadmines", [37] = "Azshara Crater",
  [43] = "Wailing Caverns", [47] = "Razorfen Kraul", [48] = "Blackfathom Deeps",
  [70] = "Uldaman", [90] = "Gnomeregan", [109] = "Sunken Temple", [129] = "Razorfen Downs",
  [189] = "Scarlet Monastery", [229] = "Blackrock Spire", [230] = "Blackrock Depths",
  [249] = "Onyxia's Lair", [289] = "Scholomance", [309] = "Zul'Gurub", [329] = "Stratholme",
  [349] = "Maraudon", [369] = "Deeprun Tram", [389] = "Ragefire Chasm", [409] = "Molten Core",
  [429] = "Dire Maul", [451] = "GM Island", [469] = "Blackwing Lair",
  [509] = "Ruins of Ahn'Qiraj",
  [531] = "Temple of Ahn'Qiraj", [533] = "Naxxramas",
}

local MAPNAME_ZH = {
  [0] = "东部王国", [1] = "卡利姆多", [13] = "测试",
  [33] = "影牙城堡", [34] = "监狱", [36] = "死亡矿井", [37] = "艾萨拉火山口",
  [43] = "哀嚎洞穴", [47] = "剃刀沼泽", [48] = "黑暗深渊", [70] = "奥达曼",
  [90] = "诺莫瑞根", [109] = "沉没的神庙", [129] = "剃刀高地", [189] = "血色修道院",
  [229] = "黑石塔", [230] = "黑石深渊", [249] = "奥妮克希亚的巢穴", [289] = "通灵学院",
  [309] = "祖尔格拉布", [329] = "斯坦索姆", [349] = "玛拉顿", [369] = "地下铁",
  [389] = "怒焰裂谷", [409] = "熔火之心", [429] = "厄运之槌",
  [451] = "GM 岛", [469] = "黑翼之巢", [509] = "安其拉废墟",
  [531] = "安其拉神庙", [533] = "纳克萨玛斯",
}

local function MapLabel(id)
  if ZH then return MAPNAME_ZH[id] or MAPNAME[id] or ("map " .. id) end
  return MAPNAME[id] or ("map " .. id)
end

local function msg(s) DEFAULT_CHAT_FRAME:AddMessage(COL .. L("Teleport", "传送") .. "|r: " .. s) end

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

TeleportDB = nil
local db

local function InitDB()
  if type(TeleportDB) ~= "table" then TeleportDB = {} end
  db = TeleportDB
  if type(db.fav) ~= "table" then db.fav = {} end
  if type(db.recent) ~= "table" then db.recent = {} end
  if type(db.mmAngle) ~= "number" then db.mmAngle = 110 end
end

-- GMBox used to own this list. Copy once, after saved variables exist.
local function TakeList(dst, src)
  if type(src) ~= "table" or table.getn(dst) > 0 then return end
  local i = 1
  while src[i] do
    table.insert(dst, src[i])
    i = i + 1
  end
end

local function MigrateFromGMBox()
  if db.took or type(GMBoxDB) ~= "table" then return end
  TakeList(db.fav, GMBoxDB.favTele)
  TakeList(db.recent, GMBoxDB.recentTele)
  GMBoxDB.favTele = nil
  GMBoxDB.recentTele = nil
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

local teleLower, teleByName

local function BuildTele()
  if teleLower then return end
  teleLower, teleByName = {}, {}
  for i = 1, table.getn(TELE) do
    local nm = TELE[i][1]
    teleLower[i] = string.lower(nm)
    teleByName[string.lower(nm)] = i
  end
end

local function TeleDisplay(i)
  if ZH then
    local zh = TELE_ZH[i]
    if zh and zh ~= "" then return zh end
  end
  return TELE[i][1]
end

local sortKey = {}
local function ByRank(a, b) return sortKey[a] < sortKey[b] end

local function Search(q, limit)
  local res = {}
  local hits = 0
  for i = 1, table.getn(teleLower) do
    local at = string.find(teleLower[i], q, 1, true)
    if not at then
      for k = 1, table.getn(TELE_ALTS) do
        local a = TELE_ALTS[k][i]
        if a and a ~= "" then
          at = string.find(a, q, 1, true)
          if at then break end
        end
      end
    end
    if at then
      hits = hits + 1
      res[hits] = i
      sortKey[i] = (at - 1) * 1000 + string.len(teleLower[i])
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

local btnSeq = 0
local function Button(parent, w, h, text, point, rel, relPoint, x, y)
  btnSeq = btnSeq + 1
  local b = CreateFrame("Button", "TeleportButton" .. btnSeq, parent, "UIPanelButtonTemplate")
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
  local e = TELE[idx]
  return { name = e[1], show = TeleDisplay(idx), map = e[2], x = e[3], y = e[4], z = e[5] }
end

local function DoTele(d, useXYZ)
  if useXYZ then
    Cmd(".go xyz " .. d.x .. " " .. d.y .. " " .. d.z .. " " .. d.map)
  else
    Cmd(".tele " .. d.name)
  end
  Remember(d.name)
  msg("-> " .. (d.show or d.name) .. " (" .. MapLabel(d.map) .. ")")
  Refresh()
end

local function RowClick()
  local d = RowData(this.index)
  if not d then return end
  if arg1 == "RightButton" then
    if ToggleFav(d.name) then msg(L("favourite added: ", "已收藏: ") .. (d.show or d.name))
    else msg(L("favourite removed: ", "已取消收藏: ") .. (d.show or d.name)) end
    Refresh()
    return
  end
  DoTele(d, IsShiftKeyDown())
end

local function RowEnter()
  local d = RowData(this.index)
  if not d then return end
  GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
  GameTooltip:AddLine(d.show or d.name)
  if ZH and d.show ~= d.name then
    GameTooltip:AddLine(d.name, 0.8, 0.8, 0.8)
  end
  GameTooltip:AddLine(MapLabel(d.map) .. "  " .. d.x .. " " .. d.y .. " " .. d.z, 0.8, 0.8, 0.8)
  GameTooltip:AddLine(L("Left click: .tele   Shift+click: .go xyz",
                        "左键 .tele 传送   Shift+左键按坐标 .go xyz"), 0.4, 0.8, 1)
  GameTooltip:AddLine(L("Right click: toggle favourite", "右键收藏/取消收藏"), 0.4, 0.8, 1)
  GameTooltip:Show()
end

local f = CreateFrame("Frame", "TeleportFrame", UIParent)
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
tinsert(UISpecialFrames, "TeleportFrame")

Label(f, L("Teleport ", "传送 ") .. VERSION, "GameFontNormal", "TOP", f, "TOP", 0, -14)

local close = CreateFrame("Button", "TeleportClose", f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)

ui.search = CreateFrame("EditBox", "TeleportSearch", f, "InputBoxTemplate")
ui.search:SetWidth(360) ui.search:SetHeight(20)
ui.search:SetPoint("TOPLEFT", f, "TOPLEFT", 70, -36)
ui.search:SetAutoFocus(false)
ui.search:SetScript("OnTextChanged", function() RunSearch() end)
ui.search:SetScript("OnEscapePressed", function() this:ClearFocus() end)
ui.search:SetScript("OnEnterPressed", function()
  local d = RowData(1)
  if d then DoTele(d) end
end)
Label(f, L("Find:", "搜索:"), "GameFontNormalSmall", "RIGHT", ui.search, "LEFT", -8, 0)

ui.clear = Button(f, 52, 20, L("Clear", "清空"), "LEFT", ui.search, "RIGHT", 8, 0)
ui.clear:SetScript("OnClick", function()
  ui.search:SetText("")
  ui.search:ClearFocus()
end)

ui.favOnly = CreateFrame("CheckButton", "TeleportFavCheck", f, "UICheckButtonTemplate")
ui.favOnly:SetWidth(22) ui.favOnly:SetHeight(22)
ui.favOnly:SetPoint("LEFT", ui.clear, "RIGHT", 6, 0)
ui.favOnly:SetScript("OnClick", function()
  view.fav = this:GetChecked() and true or false
  RunSearch()
end)
Label(f, L("fav", "收藏"), "GameFontNormalSmall", "LEFT", ui.favOnly, "RIGHT", 0, 0)

for i = 1, ROWS do
  local b = CreateFrame("Button", "TeleportRow" .. i, f)
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

ui.gox = CreateFrame("EditBox", "TeleportGoXYZ", f, "InputBoxTemplate")
ui.gox:SetWidth(190) ui.gox:SetHeight(20)
ui.gox:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 76, 18)
ui.gox:SetAutoFocus(false)
ui.gox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
ui.gox:SetScript("OnEnterPressed", function()
  local t = this:GetText()
  if t and t ~= "" then Cmd(".go xyz " .. t) msg(".go xyz " .. t) end
  this:ClearFocus()
end)
Label(f, L("go xyz:", "坐标:"), "GameFontNormalSmall", "RIGHT", ui.gox, "LEFT", -8, 0)

ui.recall = Button(f, 70, 20, L("Recall", "回上个点"), "LEFT", ui.gox, "RIGHT", 8, 0)
ui.recall:SetScript("OnClick", function()
  Cmd(".recall")
  msg(L("recall (back to the spot before your last teleport)", "回到上次传送前的位置"))
end)
ui.gps = Button(f, 60, 20, L("Where", "我在哪"), "LEFT", ui.recall, "RIGHT", 4, 0)
ui.gps:SetScript("OnClick", function() Cmd(".gps") end)

-- ------------------------------------------------------- world map pin ---
-- Right-click or Ctrl+left-click places a "go here" button on the map.
-- Left-click on a zone map (already zoomed in) does the same; continent
-- left-click still zooms. The button sends .tele to the nearest outdoor
-- game_tele — Z from the list, so you land on the ground.

local mapPin = {
  frame = nil, go = nil, mark = nil, key = nil, data = nil,
}

local function MapCursorPercent()
  if not WorldMapButton or not MouseIsOver(WorldMapButton) then return end
  local width = WorldMapButton:GetWidth()
  local height = WorldMapButton:GetHeight()
  local mx, my = WorldMapButton:GetCenter()
  local scale = WorldMapButton:GetEffectiveScale()
  local x, y = GetCursorPosition()
  if not mx or not my or width == 0 or height == 0 then return end
  mx = ((x / scale) - (mx - width / 2)) / width * 100
  my = ((my + height / 2) - (y / scale)) / height * 100
  if mx < 0 or mx > 100 or my < 0 or my > 100 then return end
  return mx, my, width, height
end

local function MapSelectionKey()
  local file = GetMapInfo and GetMapInfo() or ""
  return tostring(GetCurrentMapContinent and GetCurrentMapContinent() or 0) .. ":"
    .. tostring(GetCurrentMapZone and GetCurrentMapZone() or 0) .. ":" .. tostring(file)
end

local function HideMapPin()
  mapPin.data = nil
  mapPin.key = nil
  if mapPin.frame then mapPin.frame:Hide() end
end

local function NearestTele(mapId, wx, wy)
  local best, bestD
  for i = 1, table.getn(TELE) do
    local e = TELE[i]
    if e[2] == mapId then
      local dx, dy = e[3] - wx, e[4] - wy
      local d = dx * dx + dy * dy
      if not bestD or d < bestD then
        bestD = d
        best = i
      end
    end
  end
  if not best then return end
  return {
    name = TELE[best][1], show = TeleDisplay(best),
    map = TELE[best][2], x = TELE[best][3], y = TELE[best][4], z = TELE[best][5],
  }
end

local function EnsureMapPin()
  if mapPin.frame then return end
  local p = CreateFrame("Frame", "TeleportMapPin", WorldMapButton)
  p:SetWidth(1) p:SetHeight(1)
  p:SetFrameLevel((WorldMapButton:GetFrameLevel() or 1) + 20)
  p:Hide()
  local mark = p:CreateTexture(nil, "OVERLAY")
  mark:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
  mark:SetWidth(16) mark:SetHeight(16)
  mark:SetPoint("CENTER", p, "CENTER", 0, 0)
  local go = CreateFrame("Button", "TeleportMapGo", p, "UIPanelButtonTemplate")
  go:SetWidth(170) go:SetHeight(22)
  go:SetPoint("TOP", p, "BOTTOM", 0, -4)
  go:SetScript("OnClick", function()
    if not mapPin.data then return end
    DoTele(mapPin.data)
    HideMapPin()
  end)
  go:SetScript("OnEnter", function()
    if not mapPin.data then return end
    local d = mapPin.data
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:AddLine(d.show or d.name)
    if ZH and d.show ~= d.name then
      GameTooltip:AddLine(d.name, 0.8, 0.8, 0.8)
    end
    GameTooltip:AddLine(MapLabel(d.map) .. "  " .. d.x .. " " .. d.y .. " " .. d.z, 0.8, 0.8, 0.8)
    GameTooltip:AddLine(L("Click to teleport (nearest named spot).",
                          "点此传送到最近的命名地点。"), 0.4, 0.8, 1)
    GameTooltip:Show()
  end)
  go:SetScript("OnLeave", function() GameTooltip:Hide() end)
  mapPin.frame, mapPin.go, mapPin.mark = p, go, mark
  if SoloSkin and SoloSkin.Button then SoloSkin.Button(go) end
end

local function PlaceMapPin(mx, my)
  local file = GetMapInfo and GetMapInfo()
  local bounds = file and MAP_BOUNDS[file]
  if not bounds then
    msg(L("this map has no outdoor bounds for click-teleport",
          "这张地图没有可点的户外范围"))
    return
  end
  BuildTele()
  local mapId, left, right, top, bottom = bounds[1], bounds[2], bounds[3], bounds[4], bounds[5]
  local wy = left - (left - right) * (mx / 100)
  local wx = top - (top - bottom) * (my / 100)
  local d = NearestTele(mapId, wx, wy)
  if not d then
    msg(L("no teleport point on this continent", "这块大陆上没有传送点"))
    return
  end
  EnsureMapPin()
  local w, h = WorldMapButton:GetWidth(), WorldMapButton:GetHeight()
  mapPin.frame:ClearAllPoints()
  mapPin.frame:SetPoint("CENTER", WorldMapButton, "TOPLEFT", w * mx / 100, -h * my / 100)
  mapPin.go:SetText(L("Go: ", "传送：") .. (d.show or d.name))
  local fs = mapPin.go:GetFontString()
  local tw = (fs and fs:GetStringWidth()) or 140
  if tw + 24 > 170 then mapPin.go:SetWidth(tw + 24) else mapPin.go:SetWidth(170) end
  mapPin.data = d
  mapPin.key = MapSelectionKey()
  mapPin.frame:Show()
end

local function TryMapPinClick()
  local mx, my = MapCursorPercent()
  if not mx then return false end
  PlaceMapPin(mx, my)
  return true
end

local function HookWorldMapTeleport()
  if not WorldMapButton or WorldMapButton.teleportHooked then return end
  WorldMapButton.teleportHooked = true
  WorldMapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local prev = WorldMapButton:GetScript("OnClick")
  WorldMapButton:SetScript("OnClick", function()
    local zone = GetCurrentMapZone and GetCurrentMapZone() or 0
    local pinClick = (arg1 == "RightButton")
      or (arg1 == "LeftButton" and IsControlKeyDown())
      or (arg1 == "LeftButton" and zone > 0)
    if pinClick then TryMapPinClick() end
    -- Right / Ctrl+left: pin only, keep the current zoom.
    if arg1 == "RightButton" or (arg1 == "LeftButton" and IsControlKeyDown()) then
      return
    end
    if prev then prev() end
  end)
  if not WorldMapFrame then return end
  local prevHide = WorldMapFrame:GetScript("OnHide")
  WorldMapFrame:SetScript("OnHide", function()
    HideMapPin()
    if prevHide then prevHide() end
  end)
end

-- ------------------------------------------------------- minimap button ---

local mm = CreateFrame("Button", "TeleportMinimapButton", Minimap)
mm:SetWidth(31) mm:SetHeight(31)
mm:SetFrameStrata("MEDIUM")
mm:SetFrameLevel(8)
mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
mm:RegisterForClicks("LeftButtonUp")
mm:RegisterForDrag("LeftButton")
local mmIcon = mm:CreateTexture(nil, "ARTWORK")
mmIcon:SetTexture("Interface\\Icons\\Spell_Arcane_TeleportStormWind")
mmIcon:SetWidth(20) mmIcon:SetHeight(20)
mmIcon:SetPoint("TOPLEFT", mm, "TOPLEFT", 7, -5)
local mmBorder = mm:CreateTexture(nil, "OVERLAY")
mmBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
mmBorder:SetWidth(53) mmBorder:SetHeight(53)
mmBorder:SetPoint("TOPLEFT", mm, "TOPLEFT", 0, 0)

local function PlaceMinimapButton()
  local a = math.rad(db and db.mmAngle or 110)
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
  GameTooltip:AddLine(L("Teleport", "传送"))
  GameTooltip:AddLine(L("Left click: open or close", "左键：打开/关闭"), 0.8, 0.8, 0.8)
  GameTooltip:Show()
end)
mm:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- ------------------------------------------------------------ list logic ---

local function BaseList()
  local res, seen = {}, {}
  local function add(idx)
    if idx and not seen[idx] then seen[idx] = true table.insert(res, idx) end
  end
  BuildTele()
  for i = 1, table.getn(db.fav) do add(teleByName[string.lower(db.fav[i])]) end
  if not view.fav then
    for i = 1, table.getn(db.recent) do add(teleByName[string.lower(db.recent[i])]) end
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
      local star = ListFind(db.fav, d.name) and "|cffffd100*|r " or ""
      b.text:SetText(star .. (d.show or d.name))
      b.text:SetTextColor(1, 1, 1)
      b.info:SetText(MapLabel(d.map))
      b:Show()
    else
      b:Hide()
    end
  end

  local shown = n - view.offset
  if shown > ROWS then shown = ROWS end
  if n == 0 then
    ui.status:SetText(L("no match -- type part of a place name, e.g. iron, orgri, gurub",
                        "没有匹配 -- 输入地名片段，如 iron、orgri、gurub"))
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
  BuildTele()
  view.results = Search(q, MAX_HITS)
  if view.fav then
    local keep = {}
    for i = 1, table.getn(view.results) do
      local idx = view.results[i]
      if ListFind(db.fav, TELE[idx][1]) then table.insert(keep, idx) end
    end
    view.results = keep
  end
  Refresh()
end

local function Toggle(query)
  if not f:IsVisible() then f:Show()
  elseif not query then f:Hide() return end
  if query then
    ui.search:SetText(query)
    ui.search:SetFocus()
  end
  RunSearch()
end

function Teleport_Toggle() Toggle() end

mm:SetScript("OnClick", function() Toggle() end)

-- ----------------------------------------------------------------- slash ---

local function Help()
  if ZH then
    msg("/gt 开关窗口（命令条上也有）")
    msg("/gt <文字>  唯一匹配直接过去，多个就开列表")
    msg("左键传送，Shift+左键按坐标，右键收藏")
    msg("世界地图：区域图左键、或右键 / Ctrl+左键，点出「传送」按钮")
  else
    msg("/gt opens or closes the window (also on the command strip)")
    msg("/gt <text>  one match goes instantly, otherwise the list opens")
    msg("left click teleports, shift+click uses .go xyz, right click favourites")
    msg("world map: left-click a zone, or right / Ctrl+left, for a Go button")
  end
end

local function GoQuery(a)
  a = string.gsub(a or "", "^%s+", "")
  if a == "" or a == "help" or a == "?" then
    if a == "" then Toggle() else Help() end
    return
  end
  BuildTele()
  local q = string.lower(a)
  if teleByName[q] then
    local i = teleByName[q]
    local e = TELE[i]
    DoTele({ name = e[1], show = TeleDisplay(i), map = e[2], x = e[3], y = e[4], z = e[5] })
    return
  end
  local res = Search(q, MAX_HITS)
  if table.getn(res) == 1 then
    local i = res[1]
    local e = TELE[i]
    DoTele({ name = e[1], show = TeleDisplay(i), map = e[2], x = e[3], y = e[4], z = e[5] })
    return
  end
  if table.getn(res) == 0 then msg(L("no place matches '", "没有地点匹配 '") .. a .. "'") return end
  Toggle(a)
end

SLASH_TELEPORT1 = "/gt"
SLASH_TELEPORT2 = "/teleport"
SlashCmdList["TELEPORT"] = GoQuery

BINDING_HEADER_TELEPORT = L("Teleport", "传送")
BINDING_NAME_TELEPORT_TOGGLE = L("Toggle teleport", "开关传送")

-- ------------------------------------------------------------- pfUI skin ---
-- This addon loads after pfUI (AtlasLoot pulls pfUI in first, and the folder
-- sorts after it), so SoloSkin.Register alone never runs. Register here too.

local function SkinTeleport()
  if not SoloSkin then return end
  SoloSkin.Backdrop(f)
  SoloSkin.Controls(f)
  if mapPin.go and SoloSkin.Button then SoloSkin.Button(mapPin.go) end
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
  SoloSkin.Register("Teleport", SkinTeleport)
end
if pfUI and pfUI.RegisterSkin and not (pfUI.skin and pfUI.skin["Teleport"]) then
  pfUI:RegisterSkin("Teleport", "vanilla", SkinTeleport)
end

-- ----------------------------------------------------------------- events --

local ev = CreateFrame("Frame")
ev:RegisterEvent("VARIABLES_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("WORLD_MAP_UPDATE")
ev:SetScript("OnEvent", function()
  if event == "VARIABLES_LOADED" then
    InitDB()
    MigrateFromGMBox()
    if db.point then
      f:ClearAllPoints()
      f:SetPoint(db.point[1], UIParent, db.point[2], db.point[3], db.point[4])
    end
    PlaceMinimapButton()
    HookWorldMapTeleport()
    f:Hide()
  elseif event == "PLAYER_LOGIN" then
    -- J is free in 1.12 defaults.
    if Solo_EnsureDefaultKey then Solo_EnsureDefaultKey("TELEPORT_TOGGLE", "J", db) end
    HookWorldMapTeleport()
  elseif event == "WORLD_MAP_UPDATE" then
    if mapPin.key and mapPin.key ~= MapSelectionKey() then HideMapPin() end
  end
end)

InitDB()
HookWorldMapTeleport()
