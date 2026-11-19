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
  X                 not in a tracked instance; hide

A new addon file needs a full client restart, not /reload.
----------------------------------------------------------------------------]]

local ZH = (GetLocale and GetLocale() == "zhCN") and true or false
local function L(en, zh) if ZH and zh then return zh end return en end

local PREFIX = "SoloDun"
local VISIBLE = 12
local ROW_H = 16

local building
local snap          -- { name, clears, bosses = { { down, name, x?, y? }, ... }, player, sig }
local dismissed = false
local offset = 0

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

-- ------------------------------------------------------------------- frame --

local GAP = 4
local WIDTH = 180
local f

-- Lowest visible party frame on the left (pfUI pfGroupN, else stock).
-- Alone: the player frame. No frames yet: top-left fallback.
local function PartyAnchor()
  local best, bestBottom
  local function consider(frame)
    if not frame or not frame.IsVisible or not frame:IsVisible() then return end
    if not frame.GetBottom then return end
    local bottom = frame:GetBottom()
    if not bottom then return end
    -- Same parent scale family; prefer the lowest bottom edge.
    if not bestBottom or bottom < bestBottom then
      best, bestBottom = frame, bottom
    end
  end

  if pfUI and pfUI.uf and pfUI.uf.group then
    local i = 0
    while i <= 4 do
      consider(pfUI.uf.group[i])
      i = i + 1
    end
  end
  local i = 1
  while i <= 4 do
    consider(getglobal("pfGroup" .. i))
    consider(getglobal("PartyMemberFrame" .. i))
    i = i + 1
  end
  if not best then
    consider(getglobal("pfPlayer"))
    consider(PlayerFrame)
  end
  return best
end

local function PlaceProgress()
  if not f then return end
  local anchor = PartyAnchor()
  local width = WIDTH
  if anchor and anchor.GetWidth then
    local w = anchor:GetWidth()
    if w and w > 40 then
      width = w * (anchor:GetEffectiveScale() or 1) / (f:GetEffectiveScale() or 1)
    end
  end
  if width < 140 then width = 140 end
  if math.abs(f:GetWidth() - width) >= 0.5 then f:SetWidth(width) end

  local point, rel, relPoint, x, y = f:GetPoint()
  if anchor then
    if point == "TOPLEFT" and rel == anchor and relPoint == "BOTTOMLEFT"
        and x == 0 and y == -GAP then
      return
    end
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -GAP)
  else
    if point == "TOPLEFT" and rel == UIParent and relPoint == "TOPLEFT"
        and x == 12 and y == -180 then
      return
    end
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 12, -180)
  end
end

f = CreateFrame("Frame", "DungeonProgressFrame", UIParent)
f:SetWidth(WIDTH)
f:SetHeight(80)
f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 12, -180)
f:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 12,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
f:SetBackdropColor(0, 0, 0, .85)
f:EnableMouse(true)
f:EnableMouseWheel(true)
if f.SetClampedToScreen then f:SetClampedToScreen(true) end
f:SetScript("OnUpdate", function()
  if this:IsShown() then PlaceProgress() end
end)
f:SetFrameStrata("MEDIUM")
f:Hide()

local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
title:SetPoint("TOPRIGHT", f, "TOPRIGHT", -26, -8)
title:SetJustifyH("LEFT")

local sub = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
sub:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -26)
sub:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -26)
sub:SetJustifyH("LEFT")

local close = CreateFrame("Button", "DungeonProgressClose", f, "UIPanelButtonTemplate")
close:SetWidth(18)
close:SetHeight(18)
close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
close:SetText("x")
close:SetScript("OnClick", function()
  dismissed = true
  f:Hide()
end)

local rows = {}
for i = 1, VISIBLE do
  local t = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  t:SetHeight(ROW_H)
  t:SetJustifyH("LEFT")
  if i == 1 then
    t:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -44)
    t:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -44)
  else
    t:SetPoint("TOPLEFT", rows[i - 1], "BOTTOMLEFT", 0, 0)
    t:SetPoint("TOPRIGHT", rows[i - 1], "BOTTOMRIGHT", 0, 0)
  end
  rows[i] = t
end

local function ShownCount(total)
  local n = total - offset
  if n > VISIBLE then n = VISIBLE end
  if n < 0 then n = 0 end
  return n
end

local function Layout()
  if not snap then
    f:Hide()
    return
  end
  local bosses = snap.bosses
  local total = table.getn(bosses)
  local maxOff = total - VISIBLE
  if maxOff < 0 then maxOff = 0 end
  if offset < 0 then offset = 0 end
  if offset > maxOff then offset = maxOff end

  local killed = 0
  local firstUp = 0
  for i = 1, total do
    if bosses[i][1] then killed = killed + 1
    elseif firstUp == 0 then firstUp = i end
  end

  title:SetText(snap.name)
  if total > 0 and killed == total then
    sub:SetText(string.format(L("Cleared %d. All bosses down.", "通过 %d 次，首领已全部击败。"), snap.clears))
  else
    sub:SetText(string.format(L("Cleared %d. Bosses %d/%d.", "通过 %d 次，首领 %d/%d。"), snap.clears, killed, total))
  end

  local n = ShownCount(total)
  for i = 1, VISIBLE do
    local idx = offset + i
    local b = bosses[idx]
    if i <= n and b then
      local num = "|cffcccccc" .. idx .. ".|r "
      if b[1] then
        rows[i]:SetText(num .. "|cff3dba6a" .. L("down", "已") .. "|r  " .. b[2])
      elseif idx == firstUp then
        rows[i]:SetText(num .. "|cffffcc00>>|r " .. b[2])
      else
        rows[i]:SetText(num .. "|cff777777" .. L("up", "未") .. "|r  " .. b[2])
      end
      rows[i]:Show()
    else
      rows[i]:Hide()
    end
  end

  local h = 52 + n * ROW_H
  if h < 52 then h = 52 end
  f:SetHeight(h)
  PlaceProgress()
  if not dismissed then f:Show() else f:Hide() end
  if type(DungeonPins_Update) == "function" then DungeonPins_Update(snap) end
end

f:SetScript("OnMouseWheel", function()
  if not snap then return end
  offset = offset + ((arg1 > 0) and -1 or 1)
  Layout()
end)

function DungeonProgress_Tooltip()
  if not snap then return end
  local killed, total = 0, table.getn(snap.bosses)
  for i = 1, total do
    if snap.bosses[i][1] then killed = killed + 1 end
  end
  GameTooltip:AddLine(snap.name, 1, .82, 0)
  GameTooltip:AddLine(string.format(L("Cleared %d. Bosses %d/%d.", "通过 %d 次，首领 %d/%d。"),
    snap.clears, killed, total), .8, .8, .8)
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
  if not snap or snap.sig ~= sig then
    if not snap or snap.name ~= building.name then offset = 0 end
    dismissed = false
  end
  snap = {
    name = building.name,
    clears = building.clears,
    bosses = building.bosses,
    player = building.player,
    sig = sig,
  }
  building = nil
  Layout()
end

local function OnAddon(msg)
  local tag = string.sub(msg, 1, 1)
  if tag == "S" then
    building = { clears = 0, name = nil, bosses = {}, player = nil }
  elseif tag == "X" then
    building = nil
    snap = nil
    dismissed = false
    f:Hide()
    if type(DungeonPins_Clear) == "function" then DungeonPins_Clear() end
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

-- ------------------------------------------------------------- pfUI skin ---

local function SkinProgress()
  if not SoloSkin then return end
  SoloSkin.Backdrop(f)
  SoloSkin.Button(close)
end

if SoloSkin and SoloSkin.Register then
  SoloSkin.Register("DungeonProgress", SkinProgress)
end
if pfUI and pfUI.RegisterSkin and not (pfUI.skin and pfUI.skin["DungeonProgress"]) then
  pfUI:RegisterSkin("DungeonProgress", "vanilla", SkinProgress)
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
    dismissed = false
    Request()
  end
end)
