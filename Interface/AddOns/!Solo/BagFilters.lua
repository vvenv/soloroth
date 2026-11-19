--[[--------------------------------------------------------------------------
Category filter tabs for pfUI bags and bank: All / Gear / Consumable /
Recipe / Junk. Dim non-matching slots (same idea as pfUI's bag search).

The bar lives on UIParent, glued to the top of pfBag / pfBank, so it is not
clipped by the bag frame. No hooksecurefunc (that global is only in pfUI's
env). Full client restart required after changing this file — /reload's hot
swap keeps old OnUpdate / hooks.
----------------------------------------------------------------------------]]

local ZH = (GetLocale and GetLocale() == "zhCN") and true or false
local function L(en, zh) if ZH and zh then return zh end return en end

local TABS = {
  { id = "all",         label = L("All", "全部") },
  { id = "gear",        label = L("Gear", "装备") },
  { id = "consumable",  label = L("Consumable", "消耗") },
  { id = "recipe",      label = L("Recipe", "配方") },
  { id = "junk",        label = L("Junk", "垃圾") },
}

local active = "all"
local bars = {}
local classes

local function Say(text)
  DEFAULT_CHAT_FRAME:AddMessage("|cff44ddffSolo|r: " .. text)
end

local function AuctionClasses()
  if classes then return classes end
  classes = { GetAuctionItemClasses() }
  return classes
end

-- pfUI wraps GetItemInfo as name, link, quality, nil, minLevel, type, subType, stack.
local function SlotInfo(bag, slot)
  local link = GetContainerItemLink(bag, slot)
  if not link then return end
  local _, _, quality, _, _, itemType = GetItemInfo(link)
  return quality, itemType
end

local function Matches(bag, slot, filter)
  if filter == "all" then return true end
  local quality, itemType = SlotInfo(bag, slot)
  if not itemType then return false end
  local c = AuctionClasses()
  if filter == "gear" then
    return itemType == c[1] or itemType == c[2]
  elseif filter == "consumable" then
    return itemType == c[4]
  elseif filter == "recipe" then
    return itemType == c[8]
  elseif filter == "junk" then
    return quality == 0
  end
  return true
end

local function ApplySlot(bag, slot)
  if not pfUI or not pfUI.bags or not pfUI.bags[bag] then return end
  local entry = pfUI.bags[bag].slots and pfUI.bags[bag].slots[slot]
  local frame = entry and entry.frame
  if not frame then return end
  if active == "all" or Matches(bag, slot, active) then
    frame:SetAlpha(1)
  else
    frame:SetAlpha(.25)
  end
end

local function ApplyAll()
  if not pfUI or not pfUI.bags then return end
  for bag, data in pairs(pfUI.bags) do
    if type(data) == "table" and data.slots then
      for slot, entry in pairs(data.slots) do
        if type(entry) == "table" and entry.frame then
          ApplySlot(bag, slot)
        end
      end
    end
  end
end

local function PaintTabs(bar)
  if not bar or not bar.buttons then return end
  local A = pfUI and pfUI.api
  for i = 1, table.getn(bar.buttons) do
    local btn = bar.buttons[i]
    local on = btn.filter == active
    if A and A.CreateBackdrop then
      A.CreateBackdrop(btn, bar.border)
    end
    if on and btn.backdrop then
      btn.backdrop:SetBackdropBorderColor(1, 1, .25, 1)
      if btn.label then btn.label:SetTextColor(1, 1, .25, 1) end
    else
      if btn.label then btn.label:SetTextColor(.85, .85, .85, 1) end
    end
  end
end

local function PaintAllBars()
  for i = 1, table.getn(bars) do
    PaintTabs(bars[i])
  end
end

local function LayoutTabs(bar)
  local n = table.getn(bar.buttons)
  local border = bar.border or 3
  local gap = border * 2
  local bag = bar.bag
  local w = bag and bag:GetWidth() or bar:GetWidth()
  if not w or w < 40 then w = 200 end
  bar:SetWidth(w)
  local inner = w - border * 2 - gap * (n - 1)
  local tw = inner / n
  for i = 1, n do
    local btn = bar.buttons[i]
    btn:ClearAllPoints()
    btn:SetWidth(tw)
    if i == 1 then
      btn:SetPoint("LEFT", bar, "LEFT", border, 0)
    else
      btn:SetPoint("LEFT", bar.buttons[i - 1], "RIGHT", gap, 0)
    end
  end
end

local function SetFilter(id)
  active = id
  PaintAllBars()
  ApplyAll()
end

local function SyncBar(bar)
  local bag = bar.bag
  if not bag then return end
  if bag:IsVisible() then
    bar:Show()
    LayoutTabs(bar)
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOMLEFT", bag, "TOPLEFT", 0, 4)
    bar:SetPoint("BOTTOMRIGHT", bag, "TOPRIGHT", 0, 4)
  else
    bar:Hide()
  end
end

local function MakeBar(bag, name)
  if not bag or not pfUI or not pfUI.api then return end
  if bag.soloBagFilter then
    SyncBar(bag.soloBagFilter)
    PaintTabs(bag.soloBagFilter)
    return bag.soloBagFilter
  end

  local A = pfUI.api
  local _, border = A.GetBorderSize("bags")
  if not border then border = 3 end

  -- On UIParent so the bag frame cannot clip it; glued to the bag's top edge.
  local bar = CreateFrame("Frame", name, UIParent)
  bar.border = border
  bar.bag = bag
  bar.buttons = {}
  bar:SetHeight(20)
  bar:EnableMouse(true)
  bar:SetFrameStrata("HIGH")
  bar:SetFrameLevel(100)
  A.CreateBackdrop(bar, border)
  if A.CreateBackdropShadow then A.CreateBackdropShadow(bar) end

  local fontSize = 12
  if pfUI_config and pfUI_config.global and pfUI_config.global.font_size then
    fontSize = tonumber(pfUI_config.global.font_size) or 12
  end
  local font = pfUI.font_default or "Fonts\\FRIZQT__.TTF"

  for i = 1, table.getn(TABS) do
    local tab = TABS[i]
    local btn = CreateFrame("Button", name .. "Tab" .. i, bar)
    btn.filter = tab.id
    btn:SetHeight(16)
    btn:EnableMouse(true)
    A.CreateBackdrop(btn, border)
    btn.label = btn:CreateFontString(nil, "OVERLAY")
    btn.label:SetFont(font, fontSize, "OUTLINE")
    btn.label:SetAllPoints(btn)
    btn.label:SetJustifyH("CENTER")
    btn.label:SetText(tab.label)
    btn.label:SetTextColor(.85, .85, .85, 1)
    btn:SetScript("OnClick", function()
      SetFilter(this.filter)
    end)
    btn:SetScript("OnEnter", function()
      if this.backdrop then
        this.backdrop:SetBackdropBorderColor(1, 1, .25, 1)
      end
    end)
    btn:SetScript("OnLeave", function()
      PaintTabs(bar)
    end)
    bar.buttons[i] = btn
  end

  bag.soloBagFilter = bar
  table.insert(bars, bar)
  PaintTabs(bar)
  SyncBar(bar)
  return bar
end

local function TryAttach()
  if not pfUI or not pfUI.bag then return false end
  local ok = false
  if pfUI.bag.right then
    MakeBar(pfUI.bag.right, "SoloBagFilter")
    ok = true
  end
  if pfUI.bag.left then
    MakeBar(pfUI.bag.left, "SoloBankFilter")
  end
  return ok
end

-- Keep bars glued while bags move / show / hide. Do not ApplyAll here —
-- that belongs on bag events and tab clicks.
local driver = CreateFrame("Frame")
local attachAt = 0
driver:SetScript("OnUpdate", function()
  if not pfUI or not pfUI.bag then return end
  attachAt = attachAt + arg1
  if attachAt > 0.25 then
    attachAt = 0
    if pfUI.bag.right and not pfUI.bag.right.soloBagFilter then
      MakeBar(pfUI.bag.right, "SoloBagFilter")
    end
    if pfUI.bag.left and not pfUI.bag.left.soloBagFilter then
      MakeBar(pfUI.bag.left, "SoloBankFilter")
    end
  end
  for i = 1, table.getn(bars) do
    SyncBar(bars[i])
  end
end)

local bagEv = CreateFrame("Frame")
bagEv:RegisterEvent("BAG_UPDATE")
bagEv:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
bagEv:RegisterEvent("BANKFRAME_OPENED")
bagEv:RegisterEvent("PLAYER_ENTERING_WORLD")
bagEv:SetScript("OnEvent", function()
  TryAttach()
  if active ~= "all" then ApplyAll() end
end)

-- /bagfilter — force attach + status (full restart still needed for code edits).
SLASH_SOLOBAGFILTER1 = "/bagfilter"
SLASH_SOLOBAGFILTER2 = "/bbfl"
SlashCmdList["SOLOBAGFILTER"] = function()
  local ok = TryAttach()
  local right = pfUI and pfUI.bag and pfUI.bag.right
  local bar = right and right.soloBagFilter
  if not ok or not bar then
    Say(L("Bag filters: pfUI bags not ready.", "背包分类：pfUI 背包还没好。"))
    return
  end
  Say(L("Bag filters on top of the bag.", "背包分类在背包上方。")
    .. " w=" .. math.floor(bar:GetWidth() or 0)
    .. " shown=" .. tostring(bar:IsShown())
    .. " bag=" .. tostring(right:IsShown()))
  SetFilter(active)
end
