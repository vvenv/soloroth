--[[--------------------------------------------------------------------------
Auto farming for Soloroth, driven by the server.

  Short Chinese names (avoid /farm = pfUI farm map):
  * /dg [yards] (/grind): fight and loot around here (default 40).
  * /dy [yards] (/fish): fish around here (default 25).
  * /cj [yards] (/cy, /gather): herb, mine, skin, and quest objects /
    glowing chests around here (default 40).
  * /gj [yards]: do whatever you can — fight, gather, fish schools,
    quest objects (default 40). Bare /gj reports status; /gj stop ends it.

  Also: a minimap button (menu), and character macros created on login so
  they can be dragged onto the action bar. Fake spellbook spells are not
  used — 1.12 has no clean way to inject those.

  The panel's Stop button or the "Stop" key binding ends it; so does a
  movement key pressed while the character stands still (while the server
  moves the body, 1.12 ignores the movement keys).

The server's `[solo] farm=grind|fish|gather|all N` / `farm=off` lines drive
the panel; AutoLoot.lua keeps every `[solo]` line out of the chat.

  Each run is tallied here from the chat events (kills, money, experience,
  items by quality): live on the panel, and as one chat line when it ends.
  The tally sits in Solo_State.farmRun so a /reload mid-run keeps it.
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
panel:SetWidth(270) panel:SetHeight(60)
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

panel.stats = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
panel.stats:SetPoint("TOPLEFT", panel.info, "BOTTOMLEFT", 0, -3)
panel.stats:SetJustifyH("LEFT")

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

-- ------------------------------------------------------------------ tally --

local run -- { mode, t0 = time(), money0, kills, xp, items, q = { [quality] = n } }

local QUALITY_NAME = {
  [2] = { "1eff00", L("green", "绿色") },
  [3] = { "0070dd", L("blue", "蓝色") },
  [4] = { "a335ee", L("epic", "紫色") },
  [5] = { "ff8000", L("legendary", "橙色") },
}
local COLOR_QUALITY = { ["9d9d9d"] = 0, ffffff = 1, ["1eff00"] = 2, ["0070dd"] = 3, a335ee = 4, ff8000 = 5 }

local function Coins(copper)
  local g, s, c = math.floor(copper / 10000), math.floor(math.mod(copper, 10000) / 100), math.mod(copper, 100)
  local out = ""
  if g > 0 then out = out .. "|cffffd700" .. g .. L("g", "金") .. "|r " end
  if s > 0 then out = out .. "|cffc7c7cf" .. s .. L("s", "银") .. "|r " end
  if c > 0 or out == "" then out = out .. "|cffeda55f" .. c .. L("c", "铜") .. "|r " end
  return (string.gsub(out, " $", ""))
end

local function Earned()
  return run and math.max(0, GetMoney() - run.money0) or 0
end

local function Fights(mode)
  return mode == "grind" or mode == "all"
end

local function RunBegin(mode)
  run = { mode = mode, t0 = time(), money0 = GetMoney(), kills = 0, xp = 0, items = 0, q = {} }
  if type(Solo_State) ~= "table" then Solo_State = {} end
  Solo_State.farmRun = run
end

local function RunSummary(ended)
  local parts = {}
  if Fights(run.mode) or run.kills > 0 then
    table.insert(parts, string.format(L("%d kills", "击杀 %d 只"), run.kills))
  end
  local money = Earned()
  if money > 0 then table.insert(parts, L("earned ", "获得 ") .. Coins(money)) end
  if run.xp > 0 then table.insert(parts, string.format(L("%d experience", "经验 %d"), run.xp)) end
  if run.items > 0 then
    local item = string.format(L("looted %d items", "拾取物品 %d 件"), run.items)
    local good = {}
    for q = 2, 5 do
      local n, label = run.q[q], QUALITY_NAME[q][2]
      if n then
        table.insert(good, "|cff" .. QUALITY_NAME[q][1] .. (ZH and (label .. " " .. n .. " 件") or (n .. " " .. label)) .. "|r")
      end
    end
    if table.getn(good) > 0 then item = item .. L(" (", "（") .. table.concat(good, L(", ", "，")) .. L(")", "）") end
    table.insert(parts, item)
  end
  local head = string.format(ended and L("%s ended (%s): ", "%s结束（%s）：") or L("%s so far (%s): ", "%s本次（%s）："),
    MODE_NAME[run.mode] or run.mode, Clock(time() - run.t0))
  if table.getn(parts) == 0 then return head .. L("nothing this time.", "这次没有收获。") end
  return head .. table.concat(parts, L(", ", "，")) .. L(".", "。")
end

-- The server's own "stopped" line follows farm=off; the summary goes after it.
local pending, pendingAt
local after = CreateFrame("Frame")
after:Hide()
after:SetScript("OnUpdate", function()
  if GetTime() < pendingAt then return end
  this:Hide()
  Say(pending)
end)

local function RunEnd(report)
  if run and report then
    pending, pendingAt = RunSummary(true), GetTime() + .3
    after:Show()
  end
  run = nil
  if type(Solo_State) == "table" then Solo_State.farmRun = nil end
end

-- 1.12 has no unit GUIDs and its kill lines name the victim only, so a kill is
-- "You have slain X!" (yours) or "X dies, you gain N experience." (yours or
-- your pet's). One of yours prints both; they pair up by name.
local recentKills = {}
local function Killed(name, source)
  if not run or not name then return end
  local now = GetTime()
  for i = table.getn(recentKills), 1, -1 do
    local k = recentKills[i]
    if now - k.t > 3 then
      table.remove(recentKills, i)
    elseif k.name == name and k.source ~= source then
      table.remove(recentKills, i)
      return
    end
  end
  table.insert(recentKills, { name = name, source = source, t = now })
  run.kills = run.kills + 1
end

local xpSeen, xpMaxSeen
local function XpBaseline()
  xpSeen, xpMaxSeen = UnitXP("player"), UnitXPMax("player")
end

local function XpUpdate()
  local xp, max = UnitXP("player"), UnitXPMax("player")
  if run and xpSeen then
    -- A level-up wraps the bar: the rest of the old bar, then the new.
    run.xp = run.xp + (xp >= xpSeen and xp - xpSeen or xpMaxSeen - xpSeen + xp)
  end
  xpSeen, xpMaxSeen = xp, max
end

local function Looted(link, count)
  if not run then return end
  local quality
  local _, _, id = strfind(link, "item:(%d+)")
  if id then _, _, quality = GetItemInfo(tonumber(id)) end
  if not quality then
    local _, _, hex = strfind(link, "|c%x%x(%x%x%x%x%x%x)")
    quality = hex and COLOR_QUALITY[string.lower(hex)]
  end
  run.items = run.items + count
  if quality and quality >= 2 then run.q[quality] = (run.q[quality] or 0) + count end
end

local function RefreshInfo()
  if not state.mode then return end
  panel.info:SetText(string.format(L("%d yd · %s", "%d 码 · 已运行 %s"), state.radius, Clock(GetTime() - state.started)))
  if not run then panel.stats:SetText("") return end
  local parts = {}
  if Fights(run.mode) then table.insert(parts, string.format(L("Kills %d", "击杀 %d"), run.kills)) end
  table.insert(parts, string.format(L("Items %d", "物品 %d"), run.items))
  table.insert(parts, Coins(Earned()))
  panel.stats:SetText(table.concat(parts, " · "))
end

panel:SetScript("OnUpdate", function()
  this.elapsed = (this.elapsed or 0) + arg1
  if this.elapsed < 1 then return end
  this.elapsed = 0
  RefreshInfo()
end)

local function SetState(mode, radius)
  -- Off at login: a tally saved by a session that ended mid-run is stale.
  if not mode and not state.mode then RunEnd(false) end
  if mode ~= state.mode then
    if state.mode then RunEnd(true) end
    if mode then
      -- After a /reload the server is still farming: carry on with the saved tally.
      local saved = type(Solo_State) == "table" and Solo_State.farmRun
      if not state.mode and saved and saved.mode == mode then
        run = saved
      else
        RunBegin(mode)
      end
      XpBaseline()
    end
    state.started = run and GetTime() - (time() - run.t0) or GetTime()
  end
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
    if run then Say(RunSummary()) end
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

-- ------------------------------------------------------------- chat parse --

-- A GlobalStrings format ("You have slain %s!") as a Lua pattern.
local function Pattern(fmt)
  if not fmt then return nil end
  fmt = string.gsub(fmt, "([%(%)%.%[%]%*%+%-%?%^%$])", "%%%1")
  fmt = string.gsub(fmt, "%%%d?%$?s", "(.+)")
  fmt = string.gsub(fmt, "%%%d?%$?d", "(%%d+)")
  return "^" .. fmt .. "$"
end

local SLAIN = Pattern(SELFKILLOTHER)
-- Rested and group kills print their own variants of the experience line.
local XP_KILL = {}
for _, key in ipairs({ "COMBATLOG_XPGAIN_FIRSTPERSON", "COMBATLOG_XPGAIN_FIRSTPERSON_GROUP",
    "COMBATLOG_XPGAIN_FIRSTPERSON_RAID", "COMBATLOG_XPGAIN_EXHAUSTION1", "COMBATLOG_XPGAIN_EXHAUSTION2",
    "COMBATLOG_XPGAIN_EXHAUSTION4", "COMBATLOG_XPGAIN_EXHAUSTION5", "COMBATLOG_XPGAIN_EXHAUSTION1_GROUP",
    "COMBATLOG_XPGAIN_EXHAUSTION2_GROUP", "COMBATLOG_XPGAIN_EXHAUSTION4_GROUP",
    "COMBATLOG_XPGAIN_EXHAUSTION5_GROUP" }) do
  local p = Pattern(getglobal(key))
  if p then table.insert(XP_KILL, p) end
end
local LOOT_MULTI = Pattern(LOOT_ITEM_SELF_MULTIPLE)
local LOOT_ONE = Pattern(LOOT_ITEM_SELF)

local function OnKillLine(msg, patterns, source)
  for i = 1, table.getn(patterns) do
    local _, _, name = strfind(msg, patterns[i])
    if name then Killed(name, source) return end
  end
end

local function OnLootLine(msg)
  local _, link, count
  if LOOT_MULTI then _, _, link, count = strfind(msg, LOOT_MULTI) end
  if not link and LOOT_ONE then _, _, link = strfind(msg, LOOT_ONE) end
  if link then Looted(link, tonumber(count) or 1) end
end

-- ----------------------------------------------------------------- events --

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("VARIABLES_LOADED")
ev:RegisterEvent("CHAT_MSG_SYSTEM")
ev:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
ev:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN")
ev:RegisterEvent("CHAT_MSG_LOOT")
ev:RegisterEvent("PLAYER_XP_UPDATE")
ev:SetScript("OnEvent", function()
  if event == "VARIABLES_LOADED" then
    if type(Solo_State) ~= "table" then Solo_State = {} end
    PlaceMinimapButton()
  elseif event == "PLAYER_LOGIN" then
    EnsureMacros()
  elseif event == "PLAYER_ENTERING_WORLD" then
    XpBaseline()
    -- A /reload keeps the server's farming going: ask what it is doing.
    Server(".solo farm")
  elseif event == "PLAYER_XP_UPDATE" then
    XpUpdate()
  elseif event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" and arg1 and SLAIN then
    OnKillLine(arg1, { SLAIN }, "slain")
  elseif event == "CHAT_MSG_COMBAT_XP_GAIN" and arg1 then
    OnKillLine(arg1, XP_KILL, "xp")
  elseif event == "CHAT_MSG_LOOT" and arg1 then
    OnLootLine(arg1)
  elseif event == "CHAT_MSG_SYSTEM" and arg1 then
    local _, _, mode, radius = strfind(arg1, "^%[solo%] farm=(%a+)%s*(%d*)")
    if mode == "off" then
      SetState(nil)
    elseif mode then
      SetState(mode, tonumber(radius))
    end
  end
end)
