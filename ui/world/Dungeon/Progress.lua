--[[--------------------------------------------------------------------------
Dungeon progress -- the bosses of the instance you are standing in.

The server (DungeonProgress) keeps the list. 1.12 has no encounter packets,
so this asks with ".dungeon progress" and reads addon messages, prefix
"SoloDun":

  S                 start
  H clears<tab>name this wing, and how many times its last boss has died
  P x<tab>y         player world XY (minimap pins)
  K 0|1<tab>name[<tab>x<tab>y]  one boss; optional spawn XY for pins
  D                 show
  X                 not in a tracked instance; clear

No left-of-minimap button. Snap feeds MinimapPins and the Dungeon strip
button tooltip. A new addon file needs a full client restart, not /reload.
----------------------------------------------------------------------------]]

local ZH = (GetLocale and GetLocale() == "zhCN") and true or false
local function L(en, zh) if ZH and zh then return zh end return en end

local PREFIX = "SoloDun"

local building
local snap          -- { name, clears, bosses = { { down, name, x?, y? }, ... }, player, sig }

local function Cmd(s)
  if UnitIsDeadOrGhost("player") then
    SendChatMessage(s, "WHISPER", nil, UnitName("player"))
  else
    SendChatMessage(s, "SAY")
  end
end

local function Request()
  Cmd(".dungeon progress")
end

function DungeonProgress_Request()
  Request()
end

function DungeonProgress_Snap()
  return snap
end

local function Counts()
  if not snap then return 0, 0 end
  local bosses = snap.bosses
  local total = table.getn(bosses)
  local killed = 0
  for i = 1, total do
    if bosses[i][1] then killed = killed + 1 end
  end
  return killed, total
end

local function ApplySnap()
  if snap then
    if type(DungeonPins_Update) == "function" then DungeonPins_Update(snap) end
  elseif type(DungeonPins_Clear) == "function" then
    DungeonPins_Clear()
  end
end

function DungeonProgress_Tooltip()
  if not snap then return end
  local bosses = snap.bosses
  local killed, total = Counts()
  local firstUp = 0
  for i = 1, total do
    if not bosses[i][1] and firstUp == 0 then firstUp = i end
  end
  GameTooltip:AddLine(snap.name, 1, .82, 0)
  GameTooltip:AddLine(string.format(L("Cleared %d. Bosses %d/%d.", "通过 %d 次，首领 %d/%d。"),
    snap.clears, killed, total), .8, .8, .8)
  for i = 1, total do
    local b = bosses[i]
    local num = i .. ". "
    if b[1] then
      GameTooltip:AddLine(num .. L("down", "已") .. "  " .. b[2], .24, .73, .42)
    elseif i == firstUp then
      GameTooltip:AddLine(num .. ">> " .. b[2], 1, .8, 0)
    else
      GameTooltip:AddLine(num .. L("up", "未") .. "  " .. b[2], .47, .47, .47)
    end
  end
end

-- ------------------------------------------------------------------ parse --

local function Apply()
  if not building or not building.name then
    building = nil
    return
  end
  local sig = building.name .. ":" .. building.clears .. ":" .. table.getn(building.bosses)
  for i = 1, table.getn(building.bosses) do
    if building.bosses[i][1] then sig = sig .. ":1"
    else sig = sig .. ":0" end
  end
  snap = {
    name = building.name,
    clears = building.clears,
    bosses = building.bosses,
    player = building.player,
    sig = sig,
  }
  building = nil
  ApplySnap()
end

local function OnAddon(msg)
  local tag = string.sub(msg, 1, 1)
  if tag == "S" then
    building = { clears = 0, name = nil, bosses = {}, player = nil }
  elseif tag == "X" then
    building = nil
    snap = nil
    ApplySnap()
  elseif tag == "H" and building then
    local _, _, clears, name = strfind(msg, "^H (%d+)\t(.+)$")
    if clears then
      building.clears = tonumber(clears) or 0
      building.name = name
    end
  elseif tag == "P" and building then
    local _, _, x, y = strfind(msg, "^P ([%-%d%.]+)\t([%-%d%.]+)$")
    if x and y then
      building.player = { tonumber(x), tonumber(y) }
    end
  elseif tag == "K" and building then
    local _, _, flag, rest = strfind(msg, "^K ([01])\t(.+)$")
    if flag and rest then
      local _, _, name, xs, ys = strfind(rest, "^(.-)\t([%-%d%.]+)\t([%-%d%.]+)$")
      if name and xs and ys then
        tinsert(building.bosses, { flag == "1", name, tonumber(xs), tonumber(ys) })
      else
        tinsert(building.bosses, { flag == "1", rest })
      end
    end
  elseif tag == "D" then
    Apply()
  end
end

-- ------------------------------------------------------------------ events --

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev:RegisterEvent("CHAT_MSG_ADDON")
ev:SetScript("OnEvent", function()
  if event == "CHAT_MSG_ADDON" then
    if arg1 == PREFIX then OnAddon(arg2 or "") end
  elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    Request()
  end
end)
