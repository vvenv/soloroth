--[[--------------------------------------------------------------------------
Auto farming for Soloroth, driven by the server.

  Short Chinese names (avoid /cj = achievements, /farm = pfUI farm map):
  * /dg [yards] (/grind): fight and loot around here (default 40).
  * /dy [yards] (/fish): fish around here (default 25).
  * /cy [yards] (/gather): herb, mine and skin around here (default 40).
  * /gj [yards]: do whatever you can — fight, gather, fish schools
    (default 40). Bare /gj reports status; /gj stop ends it.

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

if SoloSkin and SoloSkin.Register then
  SoloSkin.Register("SoloFarm", function()
    SoloSkin.Backdrop(panel)
    SoloSkin.Controls(panel)
  end)
end

-- --------------------------------------------------------------- commands --

function SoloFarm_Stop()
  Server(".solo stop")
end

BINDING_HEADER_SOLOFARM = L("Solo auto farming", "单人挂机")
BINDING_NAME_SOLOFARM_STOP = L("Stop auto farming", "停止自动挂机")

local function Trim(msg)
  return string.lower(string.gsub(msg or "", "^%s*(.-)%s*$", "%1"))
end

local function Start(mode, msg)
  local yards = tonumber(Trim(msg))
  Server(".solo " .. mode .. (yards and (" " .. math.floor(yards)) or ""))
end

SLASH_SOLOGRIND1 = "/dg"
SLASH_SOLOGRIND2 = "/grind"
SlashCmdList["SOLOGRIND"] = function(msg) Start("grind", msg) end

SLASH_SOLOFISH1 = "/dy"
SLASH_SOLOFISH2 = "/fish"
SlashCmdList["SOLOFISH"] = function(msg) Start("fish", msg) end

SLASH_SOLOGATHER1 = "/cy"
SLASH_SOLOGATHER2 = "/gather"
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
    Say(L("/dg fights, /dy fishes, /cy gathers, /gj [yards] does all three, /gj stop ends it.",
      "/dg 打怪，/dy 钓鱼，/cy 采集，/gj [码数] 全能挂机，/gj stop 停止。"))
    return
  end
  Start("all", msg)
end

-- ----------------------------------------------------------------- events --

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("CHAT_MSG_SYSTEM")
ev:SetScript("OnEvent", function()
  if event == "PLAYER_ENTERING_WORLD" then
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
