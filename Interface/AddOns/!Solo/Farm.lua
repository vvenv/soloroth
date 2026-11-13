--[[--------------------------------------------------------------------------
Auto farming for Soloroth, driven by the server.

  Short Chinese names (avoid /farm = pfUI farm map):
  * /dg [yards] (/grind): fight and loot around here (default 40).
  * /dy [yards] (/fish): fish around here (default 25).
  * /cj [yards] (/cy, /gather): herb, mine and skin around here (default 40).
  * /gj [yards]: do whatever you can — fight, gather, fish schools
    (default 40). Bare /gj reports status; /gj stop ends it.

  Also: a minimap button (menu), and character macros created on login so
  they can be dragged onto the action bar. Fake spellbook spells are not
  used — 1.12 has no clean way to inject those.

  The panel's Stop button or the "Stop" key binding ends it; so does a
  movement key pressed while the character stands still (while the server
  moves the body, 1.12 ignores the movement keys).

The server's `[solo] farm=grind|fish|gather|all N` / `farm=off` lines drive
the panel; AutoLoot.lua keeps every `[solo]` line out of the chat.
----------------------------------------------------------------------------]]

local ZH = (GetLocale and GetLocale() == "zhCN") and true or false
local function L(en, zh) if ZH and zh then return zh end return en end

local function Say(text)
  DEFAULT_CHAT_FRAME:AddMessage("|cff44ddffSolo|r: " .. text)
end

local function Server(cmd)
  SendChatMessage(cmd, "SAY")
end

local MODE_NAME = {
  grind = L("Auto grinding", "自动打怪"),
  fish = L("Auto fishing", "自动钓鱼"),
  gather = L("Auto gathering", "自动采集"),
  all = L("Auto farming", "自动挂机"),
}

-- ------------------------------------------------------------------ panel --

local panel = CreateFrame("Frame", "SoloFarmPanel", UIParent)
panel:SetFrameStrata("MEDIUM")
panel:SetWidth(220) panel:SetHeight(46)
panel:SetPoint("TOP", UIParent, "TOP", 0, -110)
panel:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 12,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
panel:SetBackdropColor(0, 0, 0, .75)
panel:EnableMouse(true)
panel:SetMovable(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", function() this:StartMoving() end)
panel:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
panel:Hide()

panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
panel.title:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -8)
panel.title:SetJustifyH("LEFT")

panel.info = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
panel.info:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -4)
panel.info:SetJustifyH("LEFT")

panel.stop = CreateFrame("Button", "SoloFarmPanelStop", panel, "UIPanelButtonTemplate")
panel.stop:SetWidth(64) panel.stop:SetHeight(22)
panel.stop:SetPoint("RIGHT", panel, "RIGHT", -10, 0)
panel.stop:SetText(L("Stop", "停止"))
panel.stop:SetScript("OnClick", function() SoloFarm_Stop() end)

local state = { mode = nil, radius = 0, started = 0 }

local function Clock(seconds)
  seconds = math.floor(seconds)
  local h = math.floor(seconds / 3600)
  local m = math.floor(math.mod(seconds, 3600) / 60)
  local s = math.mod(seconds, 60)
  if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
  return string.format("%d:%02d", m, s)
end

local function RefreshInfo()
  if not state.mode then return end
  panel.info:SetText(string.format(L("%d yd · %s", "%d 码 · 已运行 %s"), state.radius, Clock(GetTime() - state.started)))
end

panel:SetScript("OnUpdate", function()
  this.elapsed = (this.elapsed or 0) + arg1
  if this.elapsed < 1 then return end
  this.elapsed = 0
  RefreshInfo()
end)

local function SetState(mode, radius)
  if mode ~= state.mode then state.started = GetTime() end
  state.mode, state.radius = mode, radius or 0
  if not mode then panel:Hide() return end
  panel.title:SetText("|cff44ddff" .. (MODE_NAME[mode] or mode) .. "|r")
  RefreshInfo()
  panel:Show()
end

-- --------------------------------------------------------------- commands --

function SoloFarm_Stop()
  Server(".solo stop")
end

local function Start(mode, msg)
  -- Extra parens: gsub's 2nd return (sub count) must not become tonumber's base.
  local yards = tonumber((string.gsub(msg or "", "^%s*(.-)%s*$", "%1")))
  Server(".solo " .. mode .. (yards and (" " .. math.floor(yards)) or ""))
end

function SoloFarm_Start(mode)
  Start(mode, "")
end

BINDING_HEADER_SOLOFARM = L("Solo auto farming", "单人挂机")
BINDING_NAME_SOLOFARM_STOP = L("Stop auto farming", "停止自动挂机")

local function Trim(msg)
  return string.lower(string.gsub(msg or "", "^%s*(.-)%s*$", "%1"))
end

SLASH_SOLOGRIND1 = "/dg"
SLASH_SOLOGRIND2 = "/grind"
SlashCmdList["SOLOGRIND"] = function(msg) Start("grind", msg) end

SLASH_SOLOFISH1 = "/dy"
SLASH_SOLOFISH2 = "/fish"
SlashCmdList["SOLOFISH"] = function(msg) Start("fish", msg) end

SLASH_SOLOGATHER1 = "/cj"
SLASH_SOLOGATHER2 = "/cy"
SLASH_SOLOGATHER3 = "/gather"
SlashCmdList["SOLOGATHER"] = function(msg) Start("gather", msg) end

-- /gj = 挂机. Not /farm: pfUI already takes /farm for its farm map.
SLASH_SOLOGJ1 = "/gj"
SlashCmdList["SOLOGJ"] = function(msg)
  local t = Trim(msg)
  if t == "stop" then
    SoloFarm_Stop()
    return
  end
  if t == "" then
    Say(state.mode and string.format(L("%s, %d yards.", "%s中，范围 %d 码。"), MODE_NAME[state.mode], state.radius)
      or L("Not farming.", "没有在挂机。"))
    Say(L("/dg fights, /dy fishes, /cj gathers, /gj [yards] does all three, /gj stop ends it.",
      "/dg 打怪，/dy 钓鱼，/cj 采集，/gj [码数] 全能挂机，/gj stop 停止。"))
    return
  end
  Start("all", msg)
end

-- ---------------------------------------------------------- minimap menu --

local menu = CreateFrame("Frame", "SoloFarmMenu", UIParent)
menu:SetFrameStrata("DIALOG")
menu:SetWidth(140)
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
  { L("Auto farm", "全能挂机"), function() SoloFarm_Start("all") end },
  { L("Grind", "自动打怪"), function() SoloFarm_Start("grind") end },
  { L("Fish", "自动钓鱼"), function() SoloFarm_Start("fish") end },
  { L("Gather", "自动采集"), function() SoloFarm_Start("gather") end },
  { L("Stop", "停止"), function() SoloFarm_Stop() end },
}

menu:SetHeight(10 + table.getn(menuRows) * 24)
local prev
for i = 1, table.getn(menuRows) do
  local row = menuRows[i]
  local b = CreateFrame("Button", "SoloFarmMenuBtn" .. i, menu, "UIPanelButtonTemplate")
  b:SetWidth(124) b:SetHeight(22)
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
  prev = b
end

local function ToggleMenu()
  if menu:IsVisible() then
    menu:Hide()
    return
  end
  menu:ClearAllPoints()
  menu:SetPoint("TOPRIGHT", Minimap, "BOTTOMLEFT", 8, 8)
  menu:Show()
end

local mm = CreateFrame("Button", "SoloFarmMinimapButton", Minimap)
mm:SetWidth(31) mm:SetHeight(31)
mm:SetFrameStrata("MEDIUM")
mm:SetFrameLevel(8)
mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
mm:RegisterForClicks("LeftButtonUp", "RightButtonUp")
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
  if type(Solo_State) ~= "table" then Solo_State = {} end
  local a = math.rad(Solo_State.farmMmAngle or 200)
  mm:ClearAllPoints()
  mm:SetPoint("CENTER", Minimap, "CENTER", 80 * math.cos(a), 80 * math.sin(a))
end

mm:SetScript("OnDragStart", function()
  this:SetScript("OnUpdate", function()
    if type(Solo_State) ~= "table" then Solo_State = {} end
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    Solo_State.farmMmAngle = math.deg(math.atan2(py / scale - my, px / scale - mx))
    PlaceMinimapButton()
  end)
end)
mm:SetScript("OnDragStop", function() this:SetScript("OnUpdate", nil) end)
mm:SetScript("OnClick", function()
  if arg1 == "RightButton" then
    menu:Hide()
    if state.mode then SoloFarm_Stop() end
    return
  end
  ToggleMenu()
end)
mm:SetScript("OnEnter", function()
  GameTooltip:SetOwner(this, "ANCHOR_LEFT")
  GameTooltip:AddLine(L("Solo farming", "单人挂机"))
  if state.mode then
    GameTooltip:AddLine(string.format("%s · %d", MODE_NAME[state.mode] or state.mode, state.radius), .8, .8, .8)
  else
    GameTooltip:AddLine(L("Not farming.", "没有在挂机。"), .8, .8, .8)
  end
  GameTooltip:AddLine(L("Left: menu   Right: stop   Drag: move", "左键：菜单   右键：停止   拖动：移动"), .7, .7, .7)
  GameTooltip:Show()
end)
mm:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Hide the menu when the player clicks away (any other mouse-down).
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

-- --------------------------------------------------------------- macros --
-- Character macros the player can drag onto the action bar. Closest thing
-- to "put it in the spellbook" without inventing fake spells.

local MACRO_DEFS = {
  { L("Solo farm", "自动挂机"), "INV_Misc_Bag_10", "/gj" },
  { L("Solo grind", "自动打怪"), "Ability_DualWield", "/dg" },
  { L("Solo fish", "自动钓鱼"), "INV_Misc_Fish_02", "/dy" },
  { L("Solo gather", "自动采集"), "INV_Misc_Herb_07", "/cj" },
  { L("Solo stop", "停止挂机"), "Spell_Holy_SealOfSacrifice", "/gj stop" },
}

local function MacroIconIndex(want)
  local n = GetNumMacroIcons and GetNumMacroIcons() or 0
  want = string.lower(want)
  for i = 1, n do
    local tex = GetMacroIconInfo(i)
    if tex and strfind(string.lower(tex), want) then
      return i
    end
  end
  return 1
end

local function EnsureMacros()
  if not CreateMacro or not GetMacroIndexByName then return end
  for i = 1, table.getn(MACRO_DEFS) do
    local def = MACRO_DEFS[i]
    if GetMacroIndexByName(def[1]) == 0 then
      -- CreateMacro(name, iconIndex, body, local, perCharacter): character book.
      CreateMacro(def[1], MacroIconIndex(def[2]), def[3], nil, 1)
    end
  end
end

-- ----------------------------------------------------------------- skin --

if SoloSkin and SoloSkin.Register then
  SoloSkin.Register("SoloFarm", function()
    SoloSkin.Backdrop(panel)
    SoloSkin.Controls(panel)
    SoloSkin.Backdrop(menu)
    SoloSkin.Controls(menu)
  end)
end

-- ----------------------------------------------------------------- events --

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("VARIABLES_LOADED")
ev:RegisterEvent("CHAT_MSG_SYSTEM")
ev:SetScript("OnEvent", function()
  if event == "VARIABLES_LOADED" then
    if type(Solo_State) ~= "table" then Solo_State = {} end
    PlaceMinimapButton()
  elseif event == "PLAYER_LOGIN" then
    EnsureMacros()
  elseif event == "PLAYER_ENTERING_WORLD" then
    -- A /reload keeps the server's farming going: ask what it is doing.
    Server(".solo farm")
  elseif event == "CHAT_MSG_SYSTEM" and arg1 then
    local _, _, mode, radius = strfind(arg1, "^%[solo%] farm=(%a+)%s*(%d*)")
    if mode == "off" then
      SetState(nil)
    elseif mode then
      SetState(mode, tonumber(radius))
    end
  end
end)
