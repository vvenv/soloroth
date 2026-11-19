--[[--------------------------------------------------------------------------
Category filter tabs above pfUI bags and bank: All / Gear / Consumable /
Recipe / Junk. Dim non-matching slots (same idea as pfUI's bag search).
Does not edit pfUI; hooks CreateBags / UpdateSlot after bags exist.
----------------------------------------------------------------------------]]

local ZH = (GetLocale and GetLocale() == "zhCN") and true or false
local function L(en, zh) if ZH and zh then return zh end return en end

-- Keys match GetAuctionItemClasses() indices (locale-safe).
local TABS = {
  { id = "all",         label = L("All", "全部") },
  { id = "gear",        label = L("Gear", "装备") },
  { id = "consumable",  label = L("Consumable", "消耗") },
  { id = "recipe",      label = L("Recipe", "配方") },
  { id = "junk",        label = L("Junk", "垃圾") },
}

local active = "all"
local bars = {}
local hookedUpdate
local hookedCreate
local classes

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
      if btn.label then btn.label:SetTextColor(.7, .7, .7, 1) end
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
  local border = bar.border
  local gap = border * 2
  local w = bar:GetWidth()
  if not w or w < 40 then
    local p = bar:GetParent()
    w = p and p:GetWidth() or 200
  end
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

local function MakeBar(parent, name)
  if not parent then return end
  if parent.soloBagFilter then
    LayoutTabs(parent.soloBagFilter)
    PaintTabs(parent.soloBagFilter)
    return parent.soloBagFilter
  end

  local A = pfUI.api
  local _, border = A.GetBorderSize("bags")
  if not border then border = 3 end

  -- Child of the bag frame: hides with it. Sits above so CreateBags topspace
  -- is left alone.
  local bar = CreateFrame("Frame", name, parent)
  bar.border = border
  bar.buttons = {}
  bar:SetHeight(18)
  bar:SetFrameStrata(parent:GetFrameStrata() or "HIGH")
  bar:SetFrameLevel((parent:GetFrameLevel() or 1) + 20)
  bar:EnableMouse(true)
  bar:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", 0, border * 3)
  bar:SetPoint("BOTTOMRIGHT", parent, "TOPRIGHT", 0, border * 3)
  A.CreateBackdrop(bar, border)
  A.CreateBackdropShadow(bar)

  local fontSize = 12
  if pfUI_config and pfUI_config.global and pfUI_config.global.font_size then
    fontSize = tonumber(pfUI_config.global.font_size) or 12
  end
  local font = pfUI.font_default or "Fonts\\FRIZQT__.TTF"

  local n = table.getn(TABS)
  for i = 1, n do
    local tab = TABS[i]
    local btn = CreateFrame("Button", name .. "Tab" .. i, bar)
    btn.filter = tab.id
    btn:SetHeight(14)
    btn:EnableMouse(true)
    A.CreateBackdrop(btn, border)
    btn.label = btn:CreateFontString(nil, "OVERLAY")
    btn.label:SetFont(font, fontSize, "OUTLINE")
    btn.label:SetAllPoints(btn)
    btn.label:SetJustifyH("CENTER")
    btn.label:SetText(tab.label)
    btn.label:SetTextColor(.7, .7, .7, 1)
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

  LayoutTabs(bar)
  parent.soloBagFilter = bar
  table.insert(bars, bar)
  PaintTabs(bar)
  return bar
end

local function HookBags()
  if not pfUI or not pfUI.bag then return end

  -- pfUI's hooksecurefunc lives in pfUI's env, not as a file-scope global here.
  if not hookedUpdate and pfUI.bag.UpdateSlot then
    hookedUpdate = true
    local prev = pfUI.bag.UpdateSlot
    function pfUI.bag.UpdateSlot(self, bag, slot)
      if type(self) == "number" then
        bag, slot, self = self, bag, pfUI.bag
      end
      prev(self, bag, slot)
      if active ~= "all" and bag and slot then ApplySlot(bag, slot) end
    end
  end

  if not hookedCreate and pfUI.bag.CreateBags then
    hookedCreate = true
    local prev = pfUI.bag.CreateBags
    function pfUI.bag.CreateBags(self, object)
      if type(self) == "string" or self == nil then
        object, self = self, pfUI.bag
      end
      prev(self, object)
      if pfUI.bag.right then MakeBar(pfUI.bag.right, "SoloBagFilter") end
      if pfUI.bag.left then MakeBar(pfUI.bag.left, "SoloBankFilter") end
      if active ~= "all" then ApplyAll() end
    end
  end

  if pfUI.bag.right then MakeBar(pfUI.bag.right, "SoloBagFilter") end
  if pfUI.bag.left then MakeBar(pfUI.bag.left, "SoloBankFilter") end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function()
  this:UnregisterAllEvents()
  HookBags()
  -- Bags may not exist until the module has run CreateBags once.
  if not (pfUI and pfUI.bag and pfUI.bag.right) then
    local wait = CreateFrame("Frame")
    local t = 0
    wait:SetScript("OnUpdate", function()
      t = t + arg1
      HookBags()
      if (pfUI and pfUI.bag and pfUI.bag.right) or t > 30 then
        this:SetScript("OnUpdate", nil)
      end
    end)
  end
end)
