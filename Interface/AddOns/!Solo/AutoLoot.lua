--[[--------------------------------------------------------------------------
Loot on kill for Soloroth, and a loot effect that shows what was picked up.

  * "Auto loot on kill" (Options → Controls, or /autoloot): the server puts a
    kill's items and money straight into the bags, no corpse click. The
    choice is a RegisterCVar (solorothAutoLoot), sent to the server as
    `.solo autoloot on|off` at each login and on each change; the server's
    `[solo] autoloot=N` answer never reaches the chat window. What does not
    fit (bags full) stays on the corpse, which keeps its sparkle.
  * "Loot effect" (solorothLootFx): each looted item pops up over the
    character with its icon in its quality's colour, flies to the bags, and
    a line "+ [item] x2" floats up beside it; money gets a coin line.
    Driven by CHAT_MSG_LOOT / CHAT_MSG_MONEY, so a hand-looted corpse shows
    it too.
----------------------------------------------------------------------------]]

local CVAR_LOOT, CVAR_FX = "solorothAutoLoot", "solorothLootFx"
RegisterCVar(CVAR_LOOT, "1")
RegisterCVar(CVAR_FX, "1")

local ZH = (GetLocale and GetLocale() == "zhCN") and true or false
local function L(en, zh) if ZH and zh then return zh end return en end

local function On(cvar) return GetCVar(cvar) ~= "0" end

local function Say(text)
  DEFAULT_CHAT_FRAME:AddMessage("|cff44ddffSolo|r: " .. text)
end

-- ------------------------------------------------------------ server sync --

local function SyncServer(quiet)
  local cmd = ".solo autoloot " .. (On(CVAR_LOOT) and "on" or "off")
  if quiet then cmd = cmd .. " quiet" end
  SendChatMessage(cmd, "SAY")
end

local origChatEvent = ChatFrame_OnEvent
function ChatFrame_OnEvent(event)
  if event == "CHAT_MSG_SYSTEM" and arg1 and strfind(arg1, "^%[solo%]") then return end
  return origChatEvent(event)
end

-- ------------------------------------------------------------- loot effect --

local QUALITY = {
  [0] = { .62, .62, .62 }, [1] = { 1, 1, 1 }, [2] = { .12, 1, 0 },
  [3] = { 0, .44, .87 }, [4] = { .64, .21, .93 }, [5] = { 1, .5, 0 },
}

local GLOW = "Interface\\Buttons\\UI-ActionButton-Border"
local RING = "Interface\\AddOns\\!Solo\\Media\\LootRing"
local COIN = "Interface\\Icons\\INV_Misc_Coin_01"

-- Where the character stands on screen, and where the bags sit.
local ORIGIN_Y = -30
local function BagTarget()
  local w, h = UIParent:GetWidth(), UIParent:GetHeight()
  return w / 2 - 90, -h / 2 + 70
end

local function Ease(t) return 1 - (1 - t) * (1 - t) end

-- The burst: a ring of light over the character, once per loot.
local burst = CreateFrame("Frame", "SoloLootBurst", UIParent)
burst:SetFrameStrata("FULLSCREEN_DIALOG")
burst:SetWidth(64) burst:SetHeight(64)
burst:SetPoint("CENTER", UIParent, "CENTER", 0, ORIGIN_Y)
burst.tex = burst:CreateTexture(nil, "OVERLAY")
burst.tex:SetAllPoints(burst)
burst.tex:SetTexture(RING)
burst.tex:SetBlendMode("ADD")
burst:Hide()
burst:SetScript("OnUpdate", function()
  this.t = this.t + arg1
  local p = this.t / .55
  if p >= 1 then this:Hide() return end
  local s = 64 + 220 * Ease(p)
  this:SetWidth(s) this:SetHeight(s)
  this.tex:SetAlpha(1 - p)
end)

local function Burst(r, g, b)
  burst.t = 0
  burst.tex:SetVertexColor(r, g, b)
  burst:SetWidth(64) burst:SetHeight(64)
  burst:Show()
end

-- Flyers: an icon that pops up over the character, then flies to the bags.
local POP, HOLD, FLY = .25, .35, .55
local flyers = {}

local function NewFlyer()
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetWidth(44) f:SetHeight(44)
  f.glow = f:CreateTexture(nil, "BACKGROUND")
  f.glow:SetTexture(RING)
  f.glow:SetBlendMode("ADD")
  f.glow:SetPoint("CENTER", f, "CENTER", 0, 0)
  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetAllPoints(f)
  f.icon:SetTexCoord(.07, .93, .07, .93)
  f.border = f:CreateTexture(nil, "OVERLAY")
  f.border:SetTexture(GLOW)
  f.border:SetBlendMode("ADD")
  f.border:SetPoint("CENTER", f, "CENTER", 0, 0)
  f.border:SetWidth(78) f.border:SetHeight(78)
  f:Hide()
  f:SetScript("OnUpdate", function()
    this.t = this.t + arg1
    local t = this.t - this.delay
    if t < 0 then return end
    if not this.shown then this.shown = true this:SetAlpha(1) end
    local x, y, s, a = this.x0, this.y0, 1, 1
    if t < POP then
      -- Overshoot pop: 0.3 → 1.35 → 1.
      local p = t / POP
      s = p < .7 and (.3 + 1.05 * p / .7) or (1.35 - .35 * (p - .7) / .3)
      y = this.y0 + 30 * Ease(p)
    elseif t < POP + HOLD then
      y = this.y0 + 30
      s = 1 + .06 * math.sin((t - POP) * 20)
    elseif t < POP + HOLD + FLY then
      local p = (t - POP - HOLD) / FLY
      local e = p * p
      local tx, ty = BagTarget()
      x = this.x0 + (tx - this.x0) * e
      y = (this.y0 + 30) + (ty - this.y0 - 30) * e + 120 * math.sin(p * 3.14159)
      s = 1 - .6 * p
      a = 1 - .3 * p
    else
      this:Hide()
      this.busy = false
      return
    end
    this:ClearAllPoints()
    this:SetPoint("CENTER", UIParent, "CENTER", x, y)
    this:SetScale(s)
    this:SetAlpha(a)
    this.glow:SetAlpha(.6 + .4 * math.sin(this.t * 12))
  end)
  return f
end

local function Flyer()
  for i = 1, table.getn(flyers) do
    if not flyers[i].busy then return flyers[i] end
  end
  local f = NewFlyer()
  table.insert(flyers, f)
  return f
end

local lastLaunch, stagger = 0, 0

local function Launch(texture, r, g, b)
  local now = GetTime()
  if now - lastLaunch > .6 then stagger = 0 end
  lastLaunch = now
  local f = Flyer()
  f.busy, f.shown, f.t, f.delay = true, false, 0, stagger
  stagger = stagger + .18
  -- Several items fan out side by side over the character.
  local n = math.floor(f.delay / .18)
  f.x0 = (math.mod(n, 2) == 0 and 1 or -1) * math.floor((n + 1) / 2) * 52
  f.y0 = ORIGIN_Y + 20
  f.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
  f.glow:SetVertexColor(r, g, b)
  f.glow:SetWidth(100) f.glow:SetHeight(100)
  f.border:SetVertexColor(r, g, b)
  f:SetAlpha(0)
  f:ClearAllPoints()
  f:SetPoint("CENTER", UIParent, "CENTER", f.x0, f.y0)
  f:Show()
  if f.delay == 0 then Burst(r, g, b) end
end

-- The feed: "+ [item] x2" lines beside the character, floating up and out.
local FEED_SHOW, FEED_FADE, FEED_MAX = 3, 1, 6
local feed = {}

local function NewLine()
  local l = CreateFrame("Frame", nil, UIParent)
  l:SetFrameStrata("FULLSCREEN_DIALOG")
  l:SetWidth(300) l:SetHeight(26)
  l.icon = l:CreateTexture(nil, "ARTWORK")
  l.icon:SetWidth(24) l.icon:SetHeight(24)
  l.icon:SetPoint("LEFT", l, "LEFT", 0, 0)
  l.icon:SetTexCoord(.07, .93, .07, .93)
  l.text = l:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  l.text:SetPoint("LEFT", l.icon, "RIGHT", 6, 0)
  l.text:SetJustifyH("LEFT")
  l.text:SetShadowOffset(1, -1)
  l:Hide()
  l:SetScript("OnUpdate", function()
    this.t = this.t + arg1
    if this.t > FEED_SHOW + FEED_FADE then
      this:Hide()
      this.busy = false
      return
    end
    -- Slide in from the left, then drift up while fading.
    local slide = this.t < .2 and (1 - Ease(this.t / .2)) * -40 or 0
    local rise = this.t > FEED_SHOW and (this.t - FEED_SHOW) * 30 or 0
    this:ClearAllPoints()
    this:SetPoint("LEFT", UIParent, "CENTER", 90 + slide, this.y + rise)
    if this.t > FEED_SHOW then
      this:SetAlpha(1 - (this.t - FEED_SHOW) / FEED_FADE)
    end
  end)
  return l
end

local function FeedLine(texture, text)
  -- Push the lines already showing up one row.
  local line
  for i = 1, table.getn(feed) do
    local l = feed[i]
    if l.busy then
      l.y = l.y + 28
      if l.y > ORIGIN_Y + 28 * FEED_MAX then l.t = FEED_SHOW + FEED_FADE end
    elseif not line then
      line = l
    end
  end
  if not line then
    line = NewLine()
    table.insert(feed, line)
  end
  line.busy, line.t, line.y = true, 0, ORIGIN_Y
  line.icon:SetTexture(texture)
  line.text:SetText(text)
  line:SetAlpha(1)
  line:Show()
end

-- ------------------------------------------------------------- chat parse --

-- A GlobalStrings format ("You receive loot: %s.") as a Lua pattern.
local function Pattern(fmt)
  if not fmt then return nil end
  fmt = string.gsub(fmt, "([%(%)%.%[%]%*%+%-%?%^%$])", "%%%1")
  fmt = string.gsub(fmt, "%%%d?%$?s", "(.+)")
  fmt = string.gsub(fmt, "%%%d?%$?d", "(%%d+)")
  return "^" .. fmt .. "$"
end

local LOOT_MULTI = Pattern(LOOT_ITEM_SELF_MULTIPLE)
local LOOT_ONE = Pattern(LOOT_ITEM_SELF)
-- A hand-looted corpse prints YOU_LOOT_MONEY; the server's kill loot comes as
-- SMSG_LOOT_MONEY_NOTIFY, which 1.12 prints as LOOT_MONEY_SPLIT.
local MONEY = Pattern(YOU_LOOT_MONEY)
local MONEY_SPLIT = Pattern(LOOT_MONEY_SPLIT)

local pushedIcon

local function OnLoot(msg)
  local _, link, count
  if LOOT_MULTI then _, _, link, count = strfind(msg, LOOT_MULTI) end
  if not link and LOOT_ONE then _, _, link = strfind(msg, LOOT_ONE) end
  if not link then return end
  count = tonumber(count) or 1

  local id
  _, _, id = strfind(link, "item:(%d+)")
  local name, _, quality, texture
  if id then
    local n, _, q, _, _, _, _, _, tex = GetItemInfo(tonumber(id))
    name, quality, texture = n, q, tex
  end
  if not name then _, _, name = strfind(link, "%[(.-)%]") end
  texture = texture or pushedIcon
  pushedIcon = nil
  local c = QUALITY[quality or 1] or QUALITY[1]
  if not quality then
    local r, g, b
    _, _, r, g, b = strfind(link, "|c%x%x(%x%x)(%x%x)(%x%x)")
    if r then c = { tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255 } end
  end

  Launch(texture, c[1], c[2], c[3])
  local hex = string.format("|cff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255)
  local text = "+ " .. hex .. "[" .. (name or "?") .. "]|r"
  if count > 1 then text = text .. " |cffffffffx" .. count .. "|r" end
  FeedLine(texture or "Interface\\Icons\\INV_Misc_QuestionMark", text)
  if quality and quality >= 4 then PlaySoundFile("Sound\\Interface\\LevelUp.wav") end
end

-- The client already plays the coin when the money lands.
local function OnMoney(msg)
  local _, coins
  if MONEY then _, _, coins = strfind(msg, MONEY) end
  if not coins and MONEY_SPLIT then _, _, coins = strfind(msg, MONEY_SPLIT) end
  if not coins then return end
  Launch(COIN, 1, .82, 0)
  FeedLine(COIN, "+ |cffffd100" .. coins .. "|r")
end

-- ---------------------------------------------------------------- options --

local ROWS = {
  { key = "RowSoloAutoLoot", cvar = CVAR_LOOT, tip = "SOLOROTH_TOOLTIP_AUTOLOOT",
    label = L("Auto Loot on Kill", "击杀后自动拾取") },
  { key = "RowSoloLootFx", cvar = CVAR_FX, tip = "SOLOROTH_TOOLTIP_LOOTFX",
    label = L("Loot Effect", "拾取特效") },
}
SOLOROTH_TOOLTIP_AUTOLOOT = L(
  "Items and money from your kills go straight into your bags, no corpse click. What does not fit stays on the corpse.",
  "怪物死后，掉落的物品和金钱直接进背包，不用点尸体。背包放不下的留在尸体上，还可以手动拾取。")
SOLOROTH_TOOLTIP_LOOTFX = L(
  "Each looted item pops up over your character and flies into your bags, with its name beside it.",
  "拾取的每件物品在角色头上弹出、飞进背包，旁边列出物品名称和数量。")

local PAGE = "BenillaOptionsFrameContainerBodyControls"

local function Refresh()
  for i = 1, table.getn(ROWS) do
    local box = getglobal(PAGE .. ROWS[i].key .. "Check")
    if box then box:SetChecked(On(ROWS[i].cvar)) end
  end
end

-- Rows join the Controls page after the client's Auto Loot, so its layout,
-- scroll and search carry them.
local function Build()
  local page = getglobal(PAGE)
  local order = BENILLA_OPTIONS_PAGE_ROWS and BENILLA_OPTIONS_PAGE_ROWS.Controls
  if not page or not order or getglobal(PAGE .. ROWS[1].key) then return end
  local at = table.getn(order)
  for i = 1, at do
    if order[i] == "RowAutoLoot" then at = i break end
  end
  for i = 1, table.getn(ROWS) do
    local r = ROWS[i]
    local row = CreateFrame("Frame", PAGE .. r.key, page, "BenillaOptionsCheckboxRowTemplate")
    BenillaOptionsRow_OnLoad(row, r.cvar, r.label, r.tip)
    local cvar = r.cvar
    row.setValue = function(value)
      SetCVar(cvar, value)
      if cvar == CVAR_LOOT then SyncServer(false) end
    end
    table.insert(order, at + i, r.key)
  end
  BenillaOptionsPage_Layout("Controls")
  Refresh()
end

-- Built at load, before pfUI's Benilla skin walks the options window once.
Build()

-- ----------------------------------------------------------------- events --

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("CHAT_MSG_LOOT")
ev:RegisterEvent("CHAT_MSG_MONEY")
ev:RegisterEvent("ITEM_PUSH")
ev:SetScript("OnEvent", function()
  if event == "PLAYER_ENTERING_WORLD" then
    if not this.synced then
      this.synced = true
      SyncServer(true)
    end
  elseif event == "ITEM_PUSH" then
    pushedIcon = arg2
  elseif event == "CHAT_MSG_LOOT" then
    if On(CVAR_FX) and arg1 then OnLoot(arg1) end
  elseif event == "CHAT_MSG_MONEY" then
    if On(CVAR_FX) and arg1 then OnMoney(arg1) end
  end
end)

SLASH_SOLOAUTOLOOT1 = "/autoloot"
SLASH_SOLOAUTOLOOT2 = "/zdsq"
SlashCmdList["SOLOAUTOLOOT"] = function(msg)
  msg = string.lower(string.gsub(msg or "", "^%s*(.-)%s*$", "%1"))
  if msg == "on" or msg == "off" then
    SetCVar(CVAR_LOOT, msg == "on" and "1" or "0")
    Refresh()
    SyncServer(false)
  elseif msg == "fx on" or msg == "fx off" then
    SetCVar(CVAR_FX, msg == "fx on" and "1" or "0")
    Refresh()
    Say(L("loot effect ", "拾取特效：") .. (On(CVAR_FX) and L("on", "开") or L("off", "关")))
  elseif msg == "test" then
    -- An item outside the cache has no GetItemInfo, so the preview names its icons.
    pushedIcon = "Interface\\Icons\\INV_Fabric_Linen_01"
    OnLoot(string.format(LOOT_ITEM_SELF_MULTIPLE or "%s x%d",
      "|cffffffff|Hitem:2589:0:0:0|h[" .. L("Linen Cloth", "亚麻布") .. "]|h|r", 3))
    pushedIcon = "Interface\\Icons\\INV_Weapon_ShortBlade_05"
    OnLoot(string.format(LOOT_ITEM_SELF or "%s",
      "|cff0070dd|Hitem:2140:0:0:0|h[" .. L("Carving Knife", "雕刻刀") .. "]|h|r"))
    OnMoney(string.format(YOU_LOOT_MONEY or "%s", L("1 Silver, 20 Copper", "1 银币，20 铜币")))
  else
    Say(L("auto loot on kill: ", "击杀后自动拾取：") .. (On(CVAR_LOOT) and L("on", "开") or L("off", "关"))
      .. L(", loot effect: ", "，拾取特效：") .. (On(CVAR_FX) and L("on", "开") or L("off", "关")))
    Say(L("/autoloot on|off, /autoloot fx on|off, /autoloot test, or Options → Controls",
      "/autoloot on|off，/autoloot fx on|off，/autoloot test，或 选项 → 控制"))
  end
end
