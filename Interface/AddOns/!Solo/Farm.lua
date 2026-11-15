--[[--------------------------------------------------------------------------
Auto farming for Soloroth, driven by the server.

  Short Chinese names (avoid /farm = pfUI farm map):
  * /dg [yards] (/grind): fight and loot around here (default 40).
  * /dy [yards] (/fish): fish around here (default 25).
  * /cj [yards] (/cy, /gather): herb, mine and skin around here (default 40).
  * /gj [yards]: do whatever you can — fight, gather, fish schools
    (default 40). Bare /gj reports status; /gj stop ends it.
  * /bzd (/assist): fight only. You walk; it does not wander. A movement
    key does not stop it (it does stop the modes above).

  Also: a minimap button (menu), and character macros created on login so
  they can be dragged onto the action bar. Fake spellbook spells are not
  used — 1.12 has no clean way to inject those.

  The panel's Stop button or the "Stop" key binding ends it; so does a
  movement key pressed while the character stands still (while the server
  moves the body, 1.12 ignores the movement keys).

The server's `[solo] farm=grind|fish|gather|all|fight N` / `farm=off` lines
drive the panel; AutoLoot.lua keeps every `[solo]` line out of the chat.

  Each run is tallied here from the chat events (kills, money, experience,
  items by quality, profession and secondary-skill ranks): live on the
  panel, and as one chat line when it ends. The tally sits in
  Solo_State.farmRun so a /reload mid-run keeps it.
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
  fight = L("Assist", "半自动打怪"),
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

panel.skills = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
panel.skills:SetPoint("TOPLEFT", panel.stats, "BOTTOMLEFT", 0, -2)
panel.skills:SetPoint("RIGHT", panel, "RIGHT", -10, 0)
panel.skills:SetJustifyH("LEFT")
panel.skills:SetText("")

panel.stop = CreateFrame("Button", "SoloFarmPanelStop", panel, "UIPanelButtonTemplate")
panel.stop:SetWidth(64) panel.stop:SetHeight(22)
-- Top-aligned so a skill line can extend the panel downward without
-- dragging the button onto the stat lines. At height 60 this is the
-- same place as a vertical center.
panel.stop:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -19)
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

local run -- { mode, t0, money0, kills, xp, items, q, skills0, skills, skillOrder }

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
  return mode == "grind" or mode == "all" or mode == "fight"
end

-- 1.12 omits the children of a collapsed skill header from GetSkillLineInfo,
-- so a full read expands Professions / Secondary Skills and folds them back.
-- Expanding fires SKILL_LINES_CHANGED; scanning stops that from re-entering.
local scanning
local function IsProfessionHeader(name)
  return name and TRADE_SKILLS and SECONDARY_SKILLS
    and (name == TRADE_SKILLS or name == SECONDARY_SKILLS)
end

local function WalkProfessions(expand, fn)
  local collapsed
  if expand then
    collapsed = {}
    local i = 1
    while i <= GetNumSkillLines() do
      local name, header, expanded = GetSkillLineInfo(i)
      if header and not expanded and IsProfessionHeader(name) then
        ExpandSkillHeader(i)
        table.insert(collapsed, i)
      end
      i = i + 1
    end
  end
  local section
  for i = 1, GetNumSkillLines() do
    local name, header, _, rank, _, _, maxRank = GetSkillLineInfo(i)
    if header then
      section = IsProfessionHeader(name) and true or nil
    elseif section and name then
      fn(name, rank or 0, maxRank or 0)
    end
  end
  if collapsed then
    for i = table.getn(collapsed), 1, -1 do
      CollapseSkillHeader(collapsed[i])
    end
  end
end

local function ApplySkill(name, rank, maxRank)
  if not run.skills then run.skills = {} end
  if not run.skillOrder then run.skillOrder = {} end
  local cur = run.skills[name]
  if not cur then
    run.skills[name] = { rank = rank, max = maxRank }
    table.insert(run.skillOrder, name)
    return
  end
  if rank > cur.rank then cur.rank = rank end
  if maxRank > cur.max then cur.max = maxRank end
end

-- skills0 is the rank at the start of the run. Empty (no professions yet) is
-- still a baseline: the skill list was already loaded, so a later line is new.
local function TakeSkillBase()
  if not run or scanning or GetNumSkillLines() == 0 then return false end
  scanning = true
  local map, order, n = {}, {}, 0
  WalkProfessions(true, function(name, rank, maxRank)
    if not map[name] then
      n = n + 1
      order[n] = name
    end
    map[name] = { rank = rank, max = maxRank }
  end)
  run.skills0, run.skillOrder, run.skills = map, order, {}
  for i = 1, n do
    local name = order[i]
    run.skills[name] = { rank = map[name].rank, max = map[name].max }
  end
  scanning = false
  return true
end

local function SkillSync(expand)
  if not run or scanning then return end
  if not run.skills0 then
    TakeSkillBase()
    return
  end
  scanning = true
  WalkProfessions(expand and true or false, ApplySkill)
  scanning = false
end

local function SkillPhrase(name, base, cur)
  if not base then
    if cur.rank <= 0 then return nil, nil end
    return string.format(L("learned %s (%d/%d)", "学会%s（%d/%d）"), name, cur.rank, cur.max),
      string.format("%s %d", name, cur.rank)
  end
  local up = cur.rank - base.rank
  local rankUp, capUp = cur.rank > base.rank, cur.max > base.max
  if rankUp and capUp then
    return string.format(L("%s +%d (%d→%d), cap %d→%d", "%s +%d（%d→%d），上限 %d→%d"),
      name, up, base.rank, cur.rank, base.max, cur.max), string.format("%s +%d", name, up)
  end
  if rankUp then
    return string.format(L("%s +%d (%d→%d)", "%s +%d（%d→%d）"), name, up, base.rank, cur.rank),
      string.format("%s +%d", name, up)
  end
  if capUp then
    local phrase = string.format(L("%s cap %d→%d", "%s上限 %d→%d"), name, base.max, cur.max)
    return phrase, phrase
  end
  return nil, nil
end

local function SkillTexts()
  if not run or not run.skills0 or not run.skillOrder then return nil, nil end
  local full, short = {}, {}
  for i = 1, table.getn(run.skillOrder) do
    local name = run.skillOrder[i]
    local cur = run.skills and run.skills[name]
    if cur then
      local phrase, brief = SkillPhrase(name, run.skills0[name], cur)
      if phrase then
        table.insert(full, phrase)
        table.insert(short, brief)
      end
    end
  end
  if table.getn(full) == 0 then return nil, nil end
  return table.concat(full, L(", ", "、")), table.concat(short, " · ")
end

local function RunBegin(mode)
  run = { mode = mode, t0 = time(), money0 = GetMoney(), kills = 0, xp = 0, items = 0, q = {} }
  TakeSkillBase()
  if type(Solo_State) ~= "table" then Solo_State = {} end
  Solo_State.farmRun = run
end

local function RunSummary(ended)
  SkillSync(true)
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
  local skills = SkillTexts()
  if skills then table.insert(parts, skills) end
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
  if state.mode == "fight" then
    panel.info:SetText(string.format(L("Running %s", "运行 %s"), Clock(GetTime() - state.started)))
  else
    panel.info:SetText(string.format(L("%d yd · Running %s", "%d 码 · 运行 %s"), state.radius, Clock(GetTime() - state.started)))
  end
  if not run then panel.stats:SetText("") return end
  local parts = {}
  if Fights(run.mode) then table.insert(parts, string.format(L("Kills %d", "击杀 %d"), run.kills)) end
  table.insert(parts, string.format(L("Items %d", "物品 %d"), run.items))
  table.insert(parts, Coins(Earned()))
  panel.stats:SetText(table.concat(parts, " · "))
  local _, brief = SkillTexts()
  if brief then
    panel.skills:SetText(brief)
    panel.skills:Show()
    panel:SetHeight(76)
  else
    panel.skills:SetText("")
    panel.skills:Hide()
    panel:SetHeight(60)
  end
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
        if run.skills0 and not run.skillOrder then
          run.skillOrder = {}
          for name in pairs(run.skills0) do table.insert(run.skillOrder, name) end
        end
        if run.skills0 and not run.skills then
          run.skills = {}
          for i = 1, table.getn(run.skillOrder or {}) do
            local name = run.skillOrder[i]
            local v = run.skills0[name]
            if v then run.skills[name] = { rank = v.rank, max = v.max } end
          end
        end
        if not run.skills0 then TakeSkillBase() end
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

SLASH_SOLOFIGHT1 = "/bzd"
SLASH_SOLOFIGHT2 = "/assist"
SlashCmdList["SOLOFIGHT"] = function() Start("fight", "") end

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
    if state.mode == "fight" then
      Say(L("Assist is on.", "半自动打怪开着。"))
    else
      Say(state.mode and string.format(L("%s, %d yards.", "%s中，范围 %d 码。"), MODE_NAME[state.mode], state.radius)
        or L("Not farming.", "没有在挂机。"))
    end
    if run then Say(RunSummary()) end
    Say(L("/bzd assists, /dg fights, /dy fishes, /cj gathers, /gj [yards] does all three, /gj stop ends it.",
      "/bzd 半自动打怪，/dg 打怪，/dy 钓鱼，/cj 采集，/gj [码数] 全能挂机，/gj stop 停止。"))
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
  { L("Assist", "半自动"), function() SoloFarm_Start("fight") end },
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
  if state.mode == "fight" then
    GameTooltip:AddLine(MODE_NAME.fight, .8, .8, .8)
  elseif state.mode then
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
  { L("Solo assist", "半自动打怪"), "Ability_Warrior_Charge", "/bzd" },
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
local SKILL_UP = Pattern(ERR_SKILL_UP_SI)

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

-- The system line names the base rank. A collapsed profession header hides
-- the line from a cheap scan, so the chat line still moves a known skill.
local function OnSkillLine(msg)
  if not run or not run.skills or not SKILL_UP then return end
  local _, _, name, rank = strfind(msg, SKILL_UP)
  if not name then
    local plain = string.gsub(string.gsub(msg, "|c%x%x%x%x%x%x%x%x", ""), "|r", "")
    _, _, name, rank = strfind(plain, SKILL_UP)
  end
  rank = tonumber(rank)
  local cur = name and run.skills[name]
  if not cur or not rank or rank <= cur.rank then return end
  cur.rank = rank
  RefreshInfo()
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
ev:RegisterEvent("CHAT_MSG_SKILL")
ev:RegisterEvent("SKILL_LINES_CHANGED")
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
  elseif event == "CHAT_MSG_SKILL" and arg1 then
    OnSkillLine(arg1)
  elseif event == "SKILL_LINES_CHANGED" then
    -- No expand here: weapon skills fire this constantly while grinding.
    SkillSync(false)
    RefreshInfo()
  elseif event == "CHAT_MSG_SYSTEM" and arg1 then
    local _, _, mode, radius = strfind(arg1, "^%[solo%] farm=(%a+)%s*(%d*)")
    if mode == "off" then
      SetState(nil)
    elseif mode then
      SetState(mode, tonumber(radius))
    end
  end
end)
