--[[--------------------------------------------------------------------------
Companions — unlocked vanity pets and mounts.

The server learns the summon / mount spell when you loot or .additem the
token, and never puts the item in a bag. This panel matches Data_Companions
rows against the spellbook (1.12 has no GetSpellInfo(spellId)) and casts
with CastSpell(index, BOOKTYPE_SPELL). Icons come from the item inventory
texture baked into Data_Companions — spellbook textures are almost all
Ability_Seal for vanity pets.
----------------------------------------------------------------------------]]

local VERSION = "1.0.0"

local ZH = (GetLocale and GetLocale() == "zhCN") and true or false
local function L(en, zh) if ZH and zh then return zh end return en end

local COL = "|cff44ddff"
local function Say(s) DEFAULT_CHAT_FRAME:AddMessage(COL .. L("Pets", "宠物") .. "|r: " .. s) end

local COLS = 6
local ROWS = 4
local ICON = 36
local GAP = 6

CompanionsDB = nil
local db
local tab = "pet" -- "pet" | "mount"

local function InitDB()
  if type(CompanionsDB) ~= "table" then CompanionsDB = {} end
  db = CompanionsDB
  if type(db.mmAngle) ~= "number" then db.mmAngle = 100 end
end

-- name (any locale) -> { index, texture, name }
local function SpellbookIndex()
  local known = {}
  local i = 1
  while true do
    local name = GetSpellName(i, BOOKTYPE_SPELL)
    if not name then break end
    local tex = GetSpellTexture(i, BOOKTYPE_SPELL)
    known[name] = { index = i, texture = tex, name = name }
    i = i + 1
  end
  return known
end

local function RowLabel(row)
  -- row = { spellId, en, zh, iconLeaf }
  if ZH and row[3] and row[3] ~= "" then return row[3] end
  return row[2] or tostring(row[1])
end

-- Item inventory icon from Data_Companions; spellbook falls back when empty.
local function RowTexture(row, known)
  local leaf = row[4]
  if leaf and leaf ~= "" then
    return "Interface\\Icons\\" .. leaf
  end
  if known and known.texture then return known.texture end
  return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function FindKnown(row, book)
  if row[3] and row[3] ~= "" and book[row[3]] then return book[row[3]] end
  if row[2] and book[row[2]] then return book[row[2]] end
  return nil
end

local function Catalog(book)
  local src = (tab == "mount") and Companions_Mounts or Companions_Pets
  local out = {}
  if type(src) ~= "table" then return out end
  local i = 1
  while src[i] do
    local hit = FindKnown(src[i], book)
    if hit then
      table.insert(out, { row = src[i], known = hit })
    end
    i = i + 1
  end
  return out
end

-- --------------------------------------------------------------- frame ----

local f = CreateFrame("Frame", "CompanionsFrame", UIParent)
f:SetWidth(420)
f:SetHeight(340)
f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
f:SetBackdrop({
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true, tileSize = 32, edgeSize = 32,
  insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", function() this:StartMoving() end)
f:SetScript("OnDragStop", function()
  this:StopMovingOrSizing()
  local point, _, relPoint, x, y = this:GetPoint()
  db.point = { point, relPoint, x, y }
end)
if f.SetClampedToScreen then f:SetClampedToScreen(true) end
f:Hide()
tinsert(UISpecialFrames, "CompanionsFrame")

local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
title:SetPoint("TOP", f, "TOP", 0, -14)
title:SetText(L("Pets ", "宠物 ") .. VERSION)

local close = CreateFrame("Button", "CompanionsClose", f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)

local status = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
status:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20, 18)
status:SetWidth(380)
status:SetJustifyH("LEFT")

local tabPet = CreateFrame("Button", "CompanionsTabPet", f, "UIPanelButtonTemplate")
tabPet:SetWidth(100) tabPet:SetHeight(22)
tabPet:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -40)
tabPet:SetText(L("Companions", "小动物"))

local tabMount = CreateFrame("Button", "CompanionsTabMount", f, "UIPanelButtonTemplate")
tabMount:SetWidth(100) tabMount:SetHeight(22)
tabMount:SetPoint("LEFT", tabPet, "RIGHT", 8, 0)
tabMount:SetText(L("Mounts", "坐骑"))

local cells = {}
local list = {}
local Refresh

local function MarkTabs()
  if pfUI and pfUI.api then
    tabPet:Enable()
    tabMount:Enable()
    if tab == "pet" then tabPet:LockHighlight() else tabPet:UnlockHighlight() end
    if tab == "mount" then tabMount:LockHighlight() else tabMount:UnlockHighlight() end
  else
    if tab == "pet" then tabPet:Disable() else tabPet:Enable() end
    if tab == "mount" then tabMount:Disable() else tabMount:Enable() end
  end
end

local function CellClick()
  local e = this.entry
  if not e or not e.known then return end
  CastSpell(e.known.index, BOOKTYPE_SPELL)
end

local function CellEnter()
  local e = this.entry
  if not e then return end
  GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
  GameTooltip:AddLine(RowLabel(e.row))
  local other = ZH and e.row[2] or e.row[3]
  if other and other ~= "" and other ~= RowLabel(e.row) then
    GameTooltip:AddLine(other, 0.8, 0.8, 0.8)
  end
  GameTooltip:AddLine("id " .. e.row[1], 0.6, 0.6, 0.6)
  GameTooltip:AddLine(L("Click to summon or mount", "点击召唤或骑乘"), 0.4, 0.8, 1)
  GameTooltip:Show()
end

for row = 0, ROWS - 1 do
  for col = 0, COLS - 1 do
    local i = row * COLS + col + 1
    local b = CreateFrame("Button", "CompanionsCell" .. i, f)
    b:SetWidth(ICON) b:SetHeight(ICON)
    local x = 24 + col * (ICON + GAP)
    local y = -72 - row * (ICON + GAP)
    b:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnClick", CellClick)
    b:SetScript("OnEnter", CellEnter)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints(b)
    b.icon:SetTexCoord(.08, .92, .08, .92)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    cells[i] = b
  end
end

Refresh = function()
  MarkTabs()
  local book = SpellbookIndex()
  list = Catalog(book)
  local n = table.getn(list)
  local maxCells = table.getn(cells)
  for i = 1, maxCells do
    local e = list[i]
    local b = cells[i]
    if e then
      b.entry = e
      b.icon:SetTexture(RowTexture(e.row, e.known))
      b:Show()
    else
      b.entry = nil
      b.icon:SetTexture(nil)
      b:Hide()
    end
  end
  if tab == "mount" then
    status:SetText(L("Mounts known: ", "已学会坐骑：") .. n)
  else
    status:SetText(L("Companions known: ", "已学会小动物：") .. n)
  end
end

tabPet:SetScript("OnClick", function() tab = "pet" Refresh() end)
tabMount:SetScript("OnClick", function() tab = "mount" Refresh() end)

local function Toggle()
  if f:IsVisible() then
    f:Hide()
    return
  end
  f:Show()
  Refresh()
end

function Companions_Toggle() Toggle() end

-- ------------------------------------------------------- minimap button ---

local mm = CreateFrame("Button", "CompanionsMinimapButton", Minimap)
mm:SetWidth(31) mm:SetHeight(31)
mm:SetFrameStrata("MEDIUM")
mm:SetFrameLevel(8)
mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
mm:RegisterForClicks("LeftButtonUp")
mm:RegisterForDrag("LeftButton")
local mmIcon = mm:CreateTexture(nil, "ARTWORK")
-- Carrier icon; falls back if the tile is missing in a lean install.
mmIcon:SetTexture("Interface\\Icons\\Ability_Seal")
mmIcon:SetWidth(20) mmIcon:SetHeight(20)
mmIcon:SetPoint("TOPLEFT", mm, "TOPLEFT", 7, -5)
local mmBorder = mm:CreateTexture(nil, "OVERLAY")
mmBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
mmBorder:SetWidth(53) mmBorder:SetHeight(53)
mmBorder:SetPoint("TOPLEFT", mm, "TOPLEFT", 0, 0)

local function PlaceMinimapButton()
  local a = math.rad(db and db.mmAngle or 100)
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
  if Solo_StripButtonTip then
    Solo_StripButtonTip(L("Pets", "宠物"), "COMPANIONS_TOGGLE")
  else
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText(L("Pets", "宠物"), 1, 1, 1)
  end
  GameTooltip:Show()
end)
mm:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- ----------------------------------------------------------------- slash --

SLASH_COMPANIONS1 = "/cw"
SLASH_COMPANIONS2 = "/pets"
SLASH_COMPANIONS3 = "/companions"
SlashCmdList["COMPANIONS"] = function(msg)
  msg = string.gsub(msg or "", "^%s+", "")
  while string.sub(msg, -1) == " " do msg = string.sub(msg, 1, -2) end
  if msg == "mount" or msg == "m" or msg == "坐骑" then
    tab = "mount"
    if not f:IsVisible() then f:Show() end
    Refresh()
    return
  end
  if msg == "pet" or msg == "p" or msg == "小动物" then
    tab = "pet"
    if not f:IsVisible() then f:Show() end
    Refresh()
    return
  end
  if msg == "help" then
    Say(L("/cw opens the panel. /cw pet or /cw mount picks a tab.",
          "/cw 打开面板。/cw pet 或 /cw mount 切换页签。"))
    return
  end
  Toggle()
end

BINDING_HEADER_COMPANIONS = L("Pets", "宠物")
BINDING_NAME_COMPANIONS_TOGGLE = L("Toggle pets panel", "开关宠物面板")

-- ----------------------------------------------------------- pfUI skin ---

local function SkinCompanions()
  if not SoloSkin then return end
  SoloSkin.Backdrop(f)
  SoloSkin.Controls(f)
  SoloSkin.Button(tabPet)
  SoloSkin.Button(tabMount)
end

if SoloSkin and SoloSkin.Register then
  SoloSkin.Register("Companions", SkinCompanions)
end
if pfUI and pfUI.RegisterSkin and not (pfUI.skin and pfUI.skin["Companions"]) then
  pfUI:RegisterSkin("Companions", "vanilla", SkinCompanions)
end

-- ----------------------------------------------------------------- events --

local ev = CreateFrame("Frame")
ev:RegisterEvent("VARIABLES_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("SPELLS_CHANGED")
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
    if Solo_EnsureDefaultKey then Solo_EnsureDefaultKey("COMPANIONS_TOGGLE", "P", db) end
  elseif event == "SPELLS_CHANGED" then
    if f:IsVisible() then Refresh() end
  end
end)

InitDB()
