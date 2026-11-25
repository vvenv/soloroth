--[[--------------------------------------------------------------------------
Category filter tabs for pfUI bags and bank: All / Gear / Consumable /
Recipe / Junk. Dim non-matching slots (same idea as pfUI's bag search).

The bar is a child of pfBag / pfBank, one row below the default toolbar
(search / close / bags / …). CreateBags is wrapped so item slots and frame
height leave room for it — otherwise the first icon row would sit under the
tabs. Full client restart required after changing this file — /reload's hot
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
local createBagsHooked

local function Say(text)
  DEFAULT_CHAT_FRAME:AddMessage("|cff44ddffSolo|r: " .. text)
end

local function AuctionClasses()
  if classes then return classes end
  classes = { GetAuctionItemClasses() }
  return classes
end

-- benilla / 1.12 GetItemInfo is nine values:
--   name, link, quality, minLevel, type, subType, stack, equipLoc, texture
-- pfUI's TBC-shaped wrap (nil itemLevel at 4) lives only in pfUI's env, so
-- from !Solo we always see the native layout. Using the wrap's indices here
-- made "type" read as subType, and every class tab matched nothing.
local function SlotInfo(bag, slot)
  local texture, _, _, bagQuality = GetContainerItemInfo(bag, slot)
  if not texture then return end
  local link = GetContainerItemLink(bag, slot)
  local quality, itemType
  if link then
    local _
    _, _, quality, _, itemType = GetItemInfo(link)
    if not itemType then
      local _, _, id = string.find(link, "item:(%d+)")
      if id then
        _, _, quality, _, itemType = GetItemInfo(tonumber(id))
      end
    end
  end
  if quality == nil then quality = bagQuality end
  return quality, itemType
end

local function Matches(bag, slot, filter)
  if filter == "all" then return true end
  local quality, itemType = SlotInfo(bag, slot)
  if filter == "junk" then
    return quality == 0
  end
  if not itemType then return false end
  local c = AuctionClasses()
  if filter == "gear" then
    return itemType == c[1] or itemType == c[2]
  elseif filter == "consumable" then
    return itemType == c[4]
  elseif filter == "recipe" then
    return itemType == c[8]
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

-- inset 0: backdrop matches the button (no outer overhang), so a small
-- gap between tabs stays visible and widths can fill the bar edge-to-edge.
local function SkinTab(btn)
  local A = pfUI and pfUI.api
  if A and A.CreateBackdrop then
    A.CreateBackdrop(btn, 0)
  end
end

local function PaintTabs(bar)
  if not bar or not bar.buttons then return end
  for i = 1, table.getn(bar.buttons) do
    local btn = bar.buttons[i]
    local on = btn.filter == active
    SkinTab(btn)
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
  local bag = bar.bag
  local border = bar.border or 3
  -- Bar is inset by `border` from the bag; fill that content width.
  local w = bag and bag:GetWidth() or 0
  w = w - border * 2
  if w < 40 then w = 200 end
  bar:SetWidth(w)
  local gap = 3
  local used = 0
  for i = 1, n do
    local btn = bar.buttons[i]
    local tw
    if i < n then
      tw = math.floor((w - gap * (n - 1)) / n)
      used = used + tw + gap
    else
      tw = w - used
    end
    btn:ClearAllPoints()
    btn:SetWidth(tw)
    if i == 1 then
      btn:SetPoint("LEFT", bar, "LEFT", 0, 0)
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

-- Clear the toolbar button row and its CreateBackdrop overhang
-- (buttons hang `border` below their frames).
local function ToolbarOffset(bag, border)
  local closeH = 12
  if bag and bag.close then closeH = bag.close:GetHeight() or 12 end
  border = border or 3
  return closeH + border * 3
end

local function FilterExtra(bar)
  local border = bar.border or 3
  return (bar:GetHeight() or 20) + border
end

-- CreateBags lays slots from the toolbar; push them (and grow the frame)
-- so the filter row does not cover the first icons.
local function PushSlots(frame, iterate)
  local bar = frame and frame.soloBagFilter
  if not bar or not iterate or not pfUI or not pfUI.bags then return end
  local extra = FilterExtra(bar)
  for i = 1, table.getn(iterate) do
    local bag = iterate[i]
    local data = pfUI.bags[bag]
    if data and data.slots then
      for slot, entry in pairs(data.slots) do
        if type(entry) == "table" and entry.frame then
          local f = entry.frame
          local p, rel, rp, x, y = f:GetPoint(1)
          if p and y then
            f:ClearAllPoints()
            if rel then
              f:SetPoint(p, rel, rp, x, y - extra)
            else
              f:SetPoint(p, x, y - extra)
            end
          end
        end
      end
    end
  end
  frame:SetHeight(frame:GetHeight() + extra)
end

local function SyncBar(bar)
  local bag = bar.bag
  if not bag then return end
  if bag:IsVisible() then
    bar:Show()
    local border = bar.border or 3
    local top = ToolbarOffset(bag, border)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", bag, "TOPLEFT", border, -top)
    LayoutTabs(bar)
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

  -- Child of the bag so it moves / hides with it, under the toolbar row.
  local bar = CreateFrame("Frame", name, bag)
  bar.border = border
  bar.bag = bag
  bar.buttons = {}
  bar:SetHeight(20)
  bar:EnableMouse(true)
  bar:SetFrameLevel((bag:GetFrameLevel() or 0) + 5)
  -- No bar chrome — only the tab buttons carry a backdrop.

  -- A step under pfUI's UI font so five labels fit the tab row.
  local fontSize = 10
  if pfUI_config and pfUI_config.global and pfUI_config.global.font_size then
    fontSize = (tonumber(pfUI_config.global.font_size) or 12) - 2
    if fontSize < 9 then fontSize = 9 end
  end
  local font = pfUI.font_default or "Fonts\\FRIZQT__.TTF"

  for i = 1, table.getn(TABS) do
    local tab = TABS[i]
    local btn = CreateFrame("Button", name .. "Tab" .. i, bar)
    btn.filter = tab.id
    btn:SetHeight(16)
    btn:EnableMouse(true)
    SkinTab(btn)
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

local function AfterCreateBags(object)
  if object == "bank" then
    if pfUI.bag.left then
      MakeBar(pfUI.bag.left, "SoloBankFilter")
      PushSlots(pfUI.bag.left, pfUI.BANK)
    end
  else
    if pfUI.bag.right then
      MakeBar(pfUI.bag.right, "SoloBagFilter")
      PushSlots(pfUI.bag.right, pfUI.BACKPACK)
    end
  end
  if active ~= "all" then ApplyAll() end
end

local function EnsureCreateBagsHook()
  if createBagsHooked or not pfUI or not pfUI.bag or not pfUI.bag.CreateBags then
    return
  end
  createBagsHooked = true
  local orig = pfUI.bag.CreateBags
  function pfUI.bag.CreateBags(self, object)
    orig(self, object)
    AfterCreateBags(object)
  end
  -- Already laid out before the wrap existed: rebuild so PushSlots runs once.
  if pfUI.bag.right and pfUI.bag.right.init then
    pfUI.bag:CreateBags()
  end
  if pfUI.bag.left and pfUI.bag.left.init then
    pfUI.bag:CreateBags("bank")
  end
end

local function TryAttach()
  if not pfUI or not pfUI.bag then return false end
  EnsureCreateBagsHook()
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

-- Keep bars sized while bags move / show / hide. Slot push belongs on the
-- CreateBags wrap, not here.
local driver = CreateFrame("Frame")
local attachAt = 0
driver:SetScript("OnUpdate", function()
  if not pfUI or not pfUI.bag then return end
  EnsureCreateBagsHook()
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
  local c = AuctionClasses()
  local sample = "-"
  for bag = 0, 4 do
    for slot = 1, GetContainerNumSlots(bag) or 0 do
      local q, t = SlotInfo(bag, slot)
      if t then
        sample = tostring(t) .. "/q" .. tostring(q)
        break
      end
    end
    if sample ~= "-" then break end
  end
  Say(L("Bag filters below the bag toolbar.", "背包分类在工具条下方。")
    .. " class1=" .. tostring(c[1])
    .. " sample=" .. sample
    .. " filter=" .. active)
  SetFilter(active)
end
