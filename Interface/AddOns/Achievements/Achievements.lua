--[[--------------------------------------------------------------------------
Achievements -- the window, the toast and the server link.

The server (AchievementMgr) keeps the achievements; this addon shows them.
1.12 has no achievement packets, so the link is chat:

  * the addon asks with ".achievement sync" (a dot command, never broadcast);
  * the server answers with addon messages, prefix "SoloAch":
      S                       start: forget what you know
      E id:time,...           earned achievements (unix time)
      P criteria:counter,...  progress of the ones not earned yet
      D                       done
    and, as things happen, "P criteria:counter" and "N id:time" (new).

Data.lua (generated with the server's tables) holds the definitions, texts
and icons.
----------------------------------------------------------------------------]]

local ZH = (GetLocale and GetLocale() == "zhCN") and true or false
local function L(en, zh) if ZH and zh then return zh end return en end

local PREFIX = "SoloAch"
local DATA = SoloAchievementData
local ROWS, ROW_H = 7, 52
local COL = "|cffffd100"

-- Data.lua fields, by position.
local A_ID, A_CAT, A_FACTION, A_POINTS, A_ICON, A_EN, A_ZH, A_DEN, A_DZH, A_BAR, A_CRIT = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
local C_ID, C_TYPE, C_VALUE, C_ASSET, C_EN, C_ZH = 1, 2, 3, 4, 5, 6

local earned = {}      -- achievement id -> unix time
local progress = {}    -- criteria id -> counter
local synced, syncing = false, false
local byId, byCat, catById = {}, {}, {}
local db

local function msg(s) DEFAULT_CHAT_FRAME:AddMessage(COL .. L("Achievements", "成就") .. "|r: " .. s) end

-- ------------------------------------------------------------------ data ---

local playerFaction
local function Available(a)
  if a[A_FACTION] == 0 then return true end
  playerFaction = playerFaction or UnitFactionGroup("player")
  return (a[A_FACTION] == 1 and playerFaction == "Alliance") or (a[A_FACTION] == 2 and playerFaction == "Horde")
end

local function Name(a) return L(a[A_EN], a[A_ZH]) end
local function Desc(a) return L(a[A_DEN], a[A_DZH]) end
local function CritName(c) return L(c[C_EN], c[C_ZH]) end

local function CritDone(a, c)
  if earned[a[A_ID]] then return c[C_VALUE] end
  local n = progress[c[C_ID]] or 0
  if n > c[C_VALUE] then n = c[C_VALUE] end
  return n
end

local function CritCount(a)
  local done, total = 0, table.getn(a[A_CRIT])
  for i = 1, total do
    local c = a[A_CRIT][i]
    if CritDone(a, c) >= c[C_VALUE] then done = done + 1 end
  end
  return done, total
end

local function Index()
  for i = 1, table.getn(DATA.cats) do
    local c = DATA.cats[i]
    catById[c[1]] = c
    byCat[c[1]] = {}
  end
  for i = 1, table.getn(DATA.list) do
    local a = DATA.list[i]
    byId[a[A_ID]] = a
    table.insert(byCat[a[A_CAT]], a)
  end
end

-- Earned / available and points of a category and its children (0 = all).
local function Tally(cat)
  local done, total, points, allPoints = 0, 0, 0, 0
  for i = 1, table.getn(DATA.list) do
    local a = DATA.list[i]
    local c = catById[a[A_CAT]]
    if Available(a) and (cat == 0 or a[A_CAT] == cat or (c and c[2] == cat)) then
      total = total + 1
      allPoints = allPoints + a[A_POINTS]
      if earned[a[A_ID]] then
        done = done + 1
        points = points + a[A_POINTS]
      end
    end
  end
  return done, total, points, allPoints
end

local function DateText(t)
  return date(ZH and "%Y/%m/%d" or "%d/%m/%Y", t) or ""
end

-- --------------------------------------------------------------- window ---

local f = CreateFrame("Frame", "SoloAchievementFrame", UIParent)
f:SetWidth(700) f:SetHeight(460)
f:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
f:SetFrameStrata("HIGH")
f:SetBackdrop({
  bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true, tileSize = 32, edgeSize = 32,
  insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
f:SetMovable(true) f:EnableMouse(true) f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", function() this:StartMoving() end)
f:SetScript("OnDragStop", function()
  this:StopMovingOrSizing()
  local point, _, relPoint, x, y = this:GetPoint()
  if db then db.point = { point, relPoint, x, y } end
end)
if f.SetClampedToScreen then f:SetClampedToScreen(true) end
f:Hide()
tinsert(UISpecialFrames, "SoloAchievementFrame")

local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOP", f, "TOP", 0, -16)
title:SetText(L("Achievements", "成就"))

local close = CreateFrame("Button", "SoloAchievementFrameClose", f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)

local pointsText = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
pointsText:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -20)
local totalText = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
totalText:SetPoint("TOPRIGHT", f, "TOPRIGHT", -40, -22)

local view = { cat = 0, offset = 0, list = {} }
local Refresh

-- Categories on the left: Summary, then each category with its children.
local catButtons = {}
local function CatButton(i, cat, indent)
  local b = CreateFrame("Button", "SoloAchievementCat" .. i, f)
  b:SetWidth(170) b:SetHeight(20)
  b:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -48 - (i - 1) * 22)
  b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
  b.sel = b:CreateTexture(nil, "BACKGROUND")
  b.sel:SetAllPoints(b)
  b.sel:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
  b.sel:SetVertexColor(1, .82, 0, .6)
  b.label = b:CreateFontString(nil, "ARTWORK", indent and "GameFontHighlightSmall" or "GameFontNormal")
  b.label:SetPoint("LEFT", b, "LEFT", indent and 18 or 6, 0)
  b.count = b:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  b.count:SetPoint("RIGHT", b, "RIGHT", -4, 0)
  b.cat = cat
  b:SetScript("OnClick", function()
    view.cat = this.cat
    view.offset = 0
    Refresh()
  end)
  catButtons[i] = b
  return b
end

local listFrame = CreateFrame("Frame", nil, f)
listFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 200, -46)
listFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 38)
listFrame:EnableMouseWheel(true)
listFrame:SetScript("OnMouseWheel", function()
  local maxOffset = math.max(0, table.getn(view.list) - ROWS)
  view.offset = math.max(0, math.min(maxOffset, view.offset - arg1 * 2))
  Refresh()
end)

local emptyText = listFrame:CreateFontString(nil, "ARTWORK", "GameFontDisable")
emptyText:SetPoint("CENTER", listFrame, "CENTER", 0, 0)

local pageText = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
pageText:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -24, 20)
local hintText = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
hintText:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 24, 20)
hintText:SetText(L("Mouse wheel to scroll   /ach to open", "滚轮翻页   /ach 打开"))

local rows = {}

local function RowEnter()
  local a = this.a
  if not a then return end
  GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
  GameTooltip:AddLine(Name(a), 1, .82, 0)
  GameTooltip:AddLine(Desc(a), 1, 1, 1, 1)
  local crit = a[A_CRIT]
  if a[A_BAR] then
    local c = crit[1]
    GameTooltip:AddLine(L("Progress: ", "进度：") .. CritDone(a, c) .. " / " .. c[C_VALUE], .8, .8, .8)
  elseif table.getn(crit) > 1 or CritName(crit[1]) ~= "" then
    GameTooltip:AddLine(" ")
    for i = 1, table.getn(crit) do
      local c = crit[i]
      if CritDone(a, c) >= c[C_VALUE] then
        GameTooltip:AddLine("|cff20ff20+|r " .. CritName(c), .2, 1, .2)
      else
        GameTooltip:AddLine("- " .. CritName(c), .5, .5, .5)
      end
    end
  end
  if earned[a[A_ID]] then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L("Earned on ", "获得于 ") .. DateText(earned[a[A_ID]]), .4, .8, 1)
  end
  GameTooltip:Show()
end

for i = 1, ROWS do
  local r = CreateFrame("Button", "SoloAchievementRow" .. i, listFrame)
  r:SetHeight(ROW_H - 4)
  r:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 0, -(i - 1) * ROW_H)
  r:SetPoint("RIGHT", listFrame, "RIGHT", 0, 0)
  r.bg = r:CreateTexture(nil, "BACKGROUND")
  r.bg:SetAllPoints(r)
  r.bg:SetTexture(1, 1, 1, 1)
  r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetWidth(40) r.icon:SetHeight(40)
  r.icon:SetPoint("LEFT", r, "LEFT", 4, 0)
  r.icon:SetTexCoord(.07, .93, .07, .93)

  r.name = r:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  r.name:SetPoint("TOPLEFT", r, "TOPLEFT", 52, -5)
  r.desc = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  r.desc:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
  r.desc:SetPoint("RIGHT", r, "RIGHT", -90, 0)
  r.desc:SetJustifyH("LEFT")

  r.points = r:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  r.points:SetPoint("TOPRIGHT", r, "TOPRIGHT", -10, -6)
  r.date = r:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  r.date:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -8, 6)

  r.bar = CreateFrame("StatusBar", nil, r)
  r.bar:SetHeight(10)
  r.bar:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 52, 5)
  r.bar:SetPoint("RIGHT", r, "RIGHT", -110, 0)
  r.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  r.bar:SetStatusBarColor(.1, .6, .1)
  r.bar.bg = r.bar:CreateTexture(nil, "BACKGROUND")
  r.bar.bg:SetAllPoints(r.bar)
  r.bar.bg:SetTexture(0, 0, 0, .5)
  r.bar.text = r.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.bar.text:SetPoint("CENTER", r.bar, "CENTER", 0, 0)

  r:SetScript("OnEnter", RowEnter)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  r:EnableMouseWheel(true)
  r:SetScript("OnMouseWheel", function() listFrame:GetScript("OnMouseWheel")() end)
  rows[i] = r
end

local function FillRow(r, a)
  r.a = a
  if not a then r:Hide() return end
  r:Show()
  local done = earned[a[A_ID]]
  r.icon:SetTexture("Interface\\Icons\\" .. a[A_ICON])
  r.name:SetText(Name(a))
  r.desc:SetText(Desc(a))
  r.points:SetText(a[A_POINTS])
  if done then
    r.bg:SetVertexColor(.35, .28, .05, .55)
    r.icon:SetVertexColor(1, 1, 1)
    r.name:SetTextColor(1, .82, 0)
    r.points:SetTextColor(1, .82, 0)
    r.date:SetText(DateText(done))
    r.bar:Hide()
    return
  end
  r.bg:SetVertexColor(.15, .15, .15, .55)
  r.icon:SetVertexColor(.35, .35, .35)
  r.name:SetTextColor(.6, .6, .6)
  r.points:SetTextColor(.5, .5, .5)
  local value, max
  if a[A_BAR] then
    local c = a[A_CRIT][1]
    value, max = CritDone(a, c), c[C_VALUE]
  else
    value, max = CritCount(a)
  end
  if max > 1 then
    r.bar:SetMinMaxValues(0, max)
    r.bar:SetValue(value)
    r.bar.text:SetText(value .. " / " .. max)
    r.bar:Show()
    r.date:SetText("")
  else
    r.bar:Hide()
    r.date:SetText("")
  end
end

local function SortList(list)
  -- Earned first by date, newest first in the summary; else data order.
  if view.cat ~= 0 then return end
  table.sort(list, function(x, y) return earned[x[A_ID]] > earned[y[A_ID]] end)
end

function Refresh()
  if not f:IsVisible() then return end
  local done, total, points = Tally(0)
  pointsText:SetText(L("Points: ", "成就点数：") .. "|cffffffff" .. points .. "|r")
  totalText:SetText(L("Completed ", "已完成 ") .. done .. " / " .. total)

  for i = 1, table.getn(catButtons) do
    local b = catButtons[i]
    if b.cat == view.cat then b.sel:Show() else b.sel:Hide() end
    if b.cat ~= 0 then
      local d, t = Tally(b.cat)
      b.count:SetText(d .. "/" .. t)
    else
      b.count:SetText("")
    end
  end

  local list = {}
  if view.cat == 0 then
    for i = 1, table.getn(DATA.list) do
      local a = DATA.list[i]
      if earned[a[A_ID]] and Available(a) then table.insert(list, a) end
    end
  else
    local cats = { view.cat }
    for i = 1, table.getn(DATA.cats) do
      if DATA.cats[i][2] == view.cat then table.insert(cats, DATA.cats[i][1]) end
    end
    for _, cat in ipairs(cats) do
      for _, a in ipairs(byCat[cat] or {}) do
        if Available(a) then table.insert(list, a) end
      end
    end
  end
  SortList(list)
  view.list = list

  local n = table.getn(list)
  if view.offset > math.max(0, n - ROWS) then view.offset = math.max(0, n - ROWS) end
  for i = 1, ROWS do FillRow(rows[i], list[view.offset + i]) end

  if n == 0 then
    emptyText:SetText(view.cat == 0 and L("No achievement earned yet. Recently earned ones show here.", "还没有获得成就。最近获得的成就会显示在这里。") or "")
    emptyText:Show()
  else
    emptyText:Hide()
  end
  if not synced then
    emptyText:SetText(L("Asking the server...", "正在向服务器读取..."))
    emptyText:Show()
  end
  pageText:SetText(n > ROWS and ((view.offset + 1) .. "-" .. math.min(n, view.offset + ROWS) .. " / " .. n) or "")
end

do
  local i = 1
  CatButton(i, 0, false).label:SetText(L("Summary", "总览"))
  for c = 1, table.getn(DATA.cats) do
    local cat = DATA.cats[c]
    if cat[2] == 0 then
      i = i + 1
      CatButton(i, cat[1], false).label:SetText(L(cat[3], cat[4]))
      for s = 1, table.getn(DATA.cats) do
        local sub = DATA.cats[s]
        if sub[2] == cat[1] then
          i = i + 1
          CatButton(i, sub[1], true).label:SetText(L(sub[3], sub[4]))
        end
      end
    end
  end
end

f:SetScript("OnShow", function() Refresh() end)

local function RequestSync()
  if syncing then return end
  syncing = true
  SendChatMessage(".achievement sync", "SAY")
end

local function Toggle()
  if f:IsVisible() then f:Hide() return end
  if not synced then
    syncing = false
    RequestSync()
  end
  f:Show()
end
SoloAchievements_Toggle = Toggle
BINDING_HEADER_SOLOACHIEVEMENTS = L("Achievements", "成就")
BINDING_NAME_SOLOACHIEVEMENTS_TOGGLE = L("Open or close Achievements", "打开/关闭成就窗口")

-- ---------------------------------------------------------------- toast ---

local SHOW, FADE = 5, 1     -- seconds on screen, seconds fading out

local toast = CreateFrame("Frame", "SoloAchievementToast", UIParent)
toast:SetWidth(320) toast:SetHeight(72)
toast:SetPoint("TOP", UIParent, "TOP", 0, -150)
toast:SetFrameStrata("DIALOG")
toast:SetBackdrop({
  bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
toast:SetBackdropColor(0, 0, 0, .85)
toast:SetBackdropBorderColor(1, .82, 0, 1)
toast:Hide()
toast.icon = toast:CreateTexture(nil, "ARTWORK")
toast.icon:SetWidth(48) toast.icon:SetHeight(48)
toast.icon:SetPoint("LEFT", toast, "LEFT", 12, 0)
toast.icon:SetTexCoord(.07, .93, .07, .93)
toast.head = toast:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
toast.head:SetPoint("TOPLEFT", toast, "TOPLEFT", 70, -12)
toast.head:SetText(L("Achievement earned", "获得成就"))
toast.name = toast:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
toast.name:SetPoint("TOPLEFT", toast.head, "BOTTOMLEFT", 0, -4)
toast.name:SetPoint("RIGHT", toast, "RIGHT", -44, 0)
toast.name:SetJustifyH("LEFT")
toast.points = toast:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
toast.points:SetPoint("RIGHT", toast, "RIGHT", -14, 0)
toast:EnableMouse(true)
toast:SetScript("OnMouseUp", function()
  this.t = SHOW + FADE
  if not f:IsVisible() then Toggle() end
end)

local queue = {}

-- toast.active, not IsVisible(): a frame shown this tick may not read as
-- visible yet, and a second toast would replace the first.
local function NextToast()
  local a = table.remove(queue, 1)
  if not a then
    toast.active = false
    toast:Hide()
    return
  end
  toast.active = true
  toast.icon:SetTexture("Interface\\Icons\\" .. a[A_ICON])
  toast.name:SetText(Name(a))
  toast.points:SetText(a[A_POINTS])
  toast.t = 0
  toast:SetAlpha(1)
  toast:Show()
  PlaySoundFile("Sound\\Interface\\LevelUp.wav")
end

toast:SetScript("OnUpdate", function()
  this.t = (this.t or 0) + arg1
  if this.t > SHOW + FADE then
    NextToast()
  elseif this.t > SHOW then
    this:SetAlpha(1 - (this.t - SHOW) / FADE)
  end
end)
local function Toast(a)
  table.insert(queue, a)
  if not toast.active then NextToast() end
end

-- ------------------------------------------------------------ messages ---

local function EachPair(body, fn)
  for a, b in string.gfind(body or "", "(%d+):(%d+)") do fn(tonumber(a), tonumber(b)) end
end

local function OnAddonMessage(text)
  local tag, body = string.sub(text, 1, 1), string.sub(text, 3)
  if tag == "S" then
    earned, progress = {}, {}
  elseif tag == "E" then
    EachPair(body, function(id, t) earned[id] = t end)
  elseif tag == "P" then
    EachPair(body, function(id, n) progress[id] = n end)
    if synced then Refresh() end
  elseif tag == "D" then
    synced, syncing = true, false
    Refresh()
  elseif tag == "N" then
    EachPair(body, function(id, t)
      earned[id] = t
      local a = byId[id]
      if a then Toast(a) end
    end)
    Refresh()
  end
end

-- -------------------------------------------------------- minimap button ---

local mm = CreateFrame("Button", "SoloAchievementMinimapButton", Minimap)
mm:SetWidth(31) mm:SetHeight(31)
mm:SetFrameStrata("MEDIUM")
mm:SetFrameLevel(8)
mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
mm:RegisterForDrag("LeftButton")
local mmIcon = mm:CreateTexture(nil, "ARTWORK")
mmIcon:SetTexture("Interface\\Icons\\INV_Misc_Ribbon_01")
mmIcon:SetWidth(20) mmIcon:SetHeight(20)
mmIcon:SetPoint("TOPLEFT", mm, "TOPLEFT", 7, -5)
local mmBorder = mm:CreateTexture(nil, "OVERLAY")
mmBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
mmBorder:SetWidth(53) mmBorder:SetHeight(53)
mmBorder:SetPoint("TOPLEFT", mm, "TOPLEFT", 0, 0)

local function PlaceMinimapButton()
  local a = math.rad(db and db.mmAngle or 160)
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
mm:SetScript("OnClick", function() Toggle() end)
mm:SetScript("OnEnter", function()
  GameTooltip:SetOwner(this, "ANCHOR_LEFT")
  GameTooltip:AddLine(L("Achievements", "成就"))
  local done, total, points = Tally(0)
  GameTooltip:AddLine(done .. " / " .. total .. "   " .. L("points ", "点数 ") .. points, .8, .8, .8)
  GameTooltip:AddLine(L("Click: open or close   Drag: move", "点击：打开/关闭   拖动：移动"), .8, .8, .8)
  GameTooltip:Show()
end)
mm:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- ------------------------------------------------------------ pfUI skin ---

local function SkinWithPfUI()
  if not (pfUI and pfUI.api and pfUI.api.CreateBackdrop) then return end
  local api = pfUI.api
  f:SetBackdrop(nil)
  api.CreateBackdrop(f, nil, nil, .75)
  if api.CreateBackdropShadow then api.CreateBackdropShadow(f) end
  api.SkinCloseButton(close, f, -6, -6)
  toast:SetBackdrop(nil)
  api.CreateBackdrop(toast, nil, nil, .85)
  if api.CreateBackdropShadow then api.CreateBackdropShadow(toast) end
  if toast.backdrop then toast.backdrop:SetBackdropBorderColor(1, .82, 0, 1) end
end

-- ------------------------------------------------------------- events ---

SLASH_SOLOACHIEVEMENTS1 = "/ach"
SLASH_SOLOACHIEVEMENTS2 = "/achievements"
SLASH_SOLOACHIEVEMENTS3 = "/cj"
SlashCmdList["SOLOACHIEVEMENTS"] = function() Toggle() end

local ev = CreateFrame("Frame")
ev:RegisterEvent("VARIABLES_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("CHAT_MSG_ADDON")
ev:SetScript("OnEvent", function()
  if event == "CHAT_MSG_ADDON" then
    if arg1 == PREFIX then OnAddonMessage(arg2 or "") end
  elseif event == "VARIABLES_LOADED" then
    if type(SoloAchievementsDB) ~= "table" then SoloAchievementsDB = {} end
    db = SoloAchievementsDB
    if db.point then
      f:ClearAllPoints()
      f:SetPoint(db.point[1], UIParent, db.point[2], db.point[3], db.point[4])
    end
    PlaceMinimapButton()
  elseif event == "PLAYER_LOGIN" then
    SkinWithPfUI()
  elseif event == "PLAYER_ENTERING_WORLD" then
    if not synced then RequestSync() end
  end
end)

Index()
