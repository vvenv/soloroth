--[[--------------------------------------------------------------------------
Enchanting uses CraftFrame (no Create All / count), unlike smelting's
TradeSkill. Add a count box + Create All next to Craft Create, and run that
many enchants on the same item: first BIND/REPLACE still asks; the rest
re-target the remembered bag/paperdoll slot and skip the popup.

Needs the Soloroth client deviation that lets ReplaceEnchant commit outside
a click (craft batch re-target runs from OnUpdate).

Cancel on REPLACE cancel, craft close, cast fail, or count exhausted.
----------------------------------------------------------------------------]]

local ZH = (GetLocale and GetLocale() == "zhCN") and true or false
local function L(en, zh) if ZH and zh then return zh end return en end

local skipReplace = false
local remaining = 0
local needRetarget = false
local pendingNext = false
local expectStop = false
local lastBag, lastSlot, lastInv
local dialogsHooked = false
local popupShowHooked = false
local pickupsHooked = false
local uiReady = false

local input, createAll, minus, plus
local skinReady = false

local function ClampCount(n, avail)
  n = tonumber(n) or 1
  if n < 1 then n = 1 end
  if avail and avail > 0 and n > avail then n = avail end
  return n
end

local function Available()
  local idx = GetCraftSelectionIndex and GetCraftSelectionIndex()
  if not idx or idx == 0 then return 0 end
  local _, _, craftType, num = GetCraftInfo(idx)
  if craftType == "header" then return 0 end
  return tonumber(num) or 0
end

local function CreateEnabled()
  return CraftCreateButton and CraftCreateButton:IsEnabled() == 1
end

local function SyncInput()
  if not input then return end
  local avail = Available()
  input:SetNumber(ClampCount(input:GetNumber(), avail > 0 and avail or nil))
  if createAll then
    if CreateEnabled() or avail > 0 then
      createAll:Enable()
    else
      createAll:Disable()
    end
  end
end

local function ClearBatch()
  remaining = 0
  needRetarget = false
  pendingNext = false
  expectStop = false
end

local function ClearSession()
  ClearBatch()
  skipReplace = false
end

local function RememberTarget(bag, slot, inv)
  lastBag, lastSlot, lastInv = bag, slot, inv
end

local function Retarget()
  if lastBag ~= nil and lastSlot ~= nil and type(PickupContainerItem) == "function" then
    PickupContainerItem(lastBag, lastSlot)
  elseif lastInv ~= nil and type(PickupInventoryItem) == "function" then
    PickupInventoryItem(lastInv)
  end
end

local function QueueCraft()
  local idx = GetCraftSelectionIndex and GetCraftSelectionIndex()
  if not idx or idx == 0 then
    ClearBatch()
    return
  end
  needRetarget = true
  DoCraft(idx)
end

local function StartBatch(count)
  local idx = GetCraftSelectionIndex and GetCraftSelectionIndex()
  if not idx or idx == 0 then return end
  local avail = Available()
  if avail > 0 then
    remaining = ClampCount(count, avail)
  else
    remaining = ClampCount(count, nil)
  end
  needRetarget = false
  pendingNext = false
  expectStop = false
  DoCraft(idx)
end

local function HookDialog(which, onAccept, onCancel)
  local d = StaticPopupDialogs and StaticPopupDialogs[which]
  if not d or d.soloContinuousEnchant then return end
  d.soloContinuousEnchant = true
  local prevAccept = d.OnAccept
  d.OnAccept = function()
    if onAccept then onAccept() end
    if prevAccept then return prevAccept() end
  end
  if onCancel then
    local prevCancel = d.OnCancel
    d.OnCancel = function()
      onCancel()
      if prevCancel then return prevCancel() end
    end
  end
end

local function HookDialogs()
  if type(StaticPopupDialogs) ~= "table" then return end
  if not StaticPopupDialogs["REPLACE_ENCHANT"] then return end

  if not dialogsHooked then
    dialogsHooked = true
    HookDialog("REPLACE_ENCHANT", function()
      skipReplace = true
    end, ClearSession)

    HookDialog("BIND_ENCHANT", function()
      skipReplace = true
    end, nil)
  end

  if popupShowHooked then return end
  local origShow = StaticPopup_Show
  if type(origShow) ~= "function" then return end
  popupShowHooked = true
  StaticPopup_Show = function(which, text1, text2, data)
    if which == "REPLACE_ENCHANT" and skipReplace
        and type(ReplaceEnchant) == "function" then
      ReplaceEnchant()
      return
    end
    return origShow(which, text1, text2, data)
  end
end

local function HookPickups()
  if pickupsHooked then return end
  pickupsHooked = true
  if type(PickupContainerItem) == "function" then
    local orig = PickupContainerItem
    PickupContainerItem = function(bag, slot)
      if SpellIsTargeting and SpellIsTargeting() then
        RememberTarget(bag, slot, nil)
      end
      return orig(bag, slot)
    end
  end
  if type(PickupInventoryItem) == "function" then
    local orig = PickupInventoryItem
    PickupInventoryItem = function(slot)
      if SpellIsTargeting and SpellIsTargeting() then
        RememberTarget(nil, nil, slot)
      end
      return orig(slot)
    end
  end
end

local function SkinCountUi()
  if skinReady or not createAll then return end
  if not (pfUI and pfUI.api and SoloSkin) then return end
  local A = pfUI.api
  SoloSkin.Button(createAll)
  if minus then A.SkinArrowButton(minus, "left", 18) end
  if plus then A.SkinArrowButton(plus, "right", 18) end
  if input and not input.soloSkinned then
    input.soloSkinned = true
    input:DisableDrawLayer("BACKGROUND")
    A.CreateBackdrop(input)
    if input.backdrop and A.SetAllPointsOffset then
      A.SetAllPointsOffset(input.backdrop, input, .2)
    end
    input:SetJustifyH("CENTER")
  end
  skinReady = true
end

local function InstallCraftUi()
  if uiReady or not CraftFrame or not CraftCreateButton then return end
  uiReady = true

  local create = CraftCreateButton
  createAll = CreateFrame("Button", "SoloCraftCreateAllButton", CraftFrame, "UIPanelButtonTemplate")
  createAll:SetWidth(80)
  createAll:SetHeight(22)
  createAll:SetFrameLevel((create:GetFrameLevel() or 1) + 2)
  createAll:SetText(CREATE_ALL or L("Create All", "全部制造"))
  createAll:SetPoint("RIGHT", create, "LEFT", -5, 0)
  createAll:SetScript("OnClick", function()
    local n = Available()
    if n < 1 then n = ClampCount(input and input:GetNumber() or 1, nil) end
    StartBatch(n)
  end)

  plus = CreateFrame("Button", "SoloCraftIncrementButton", CraftFrame)
  plus:SetWidth(18)
  plus:SetHeight(18)
  plus:SetFrameLevel((create:GetFrameLevel() or 1) + 2)
  plus:SetPoint("RIGHT", createAll, "LEFT", -5, 0)
  plus:SetScript("OnClick", function()
    local avail = Available()
    input:SetNumber(ClampCount(input:GetNumber() + 1, avail > 0 and avail or nil))
  end)

  input = CreateFrame("EditBox", "SoloCraftInputBox", CraftFrame, "InputBoxTemplate")
  input:SetWidth(36)
  input:SetHeight(20)
  input:SetNumeric(true)
  input:SetMaxLetters(3)
  input:SetAutoFocus(false)
  input:SetNumber(1)
  input:SetPoint("RIGHT", plus, "LEFT", -2, 0)
  input:SetScript("OnEnterPressed", function()
    this:ClearFocus()
    SyncInput()
  end)
  input:SetScript("OnEditFocusLost", SyncInput)

  minus = CreateFrame("Button", "SoloCraftDecrementButton", CraftFrame)
  minus:SetWidth(18)
  minus:SetHeight(18)
  minus:SetFrameLevel((create:GetFrameLevel() or 1) + 2)
  minus:SetPoint("RIGHT", input, "LEFT", -2, 0)
  minus:SetScript("OnClick", function()
    input:SetNumber(ClampCount(input:GetNumber() - 1, Available()))
  end)

  create:SetScript("OnClick", function()
    SyncInput()
    StartBatch(input:GetNumber())
  end)

  if type(CraftFrame_SetSelection) == "function" then
    local orig = CraftFrame_SetSelection
    CraftFrame_SetSelection = function(id)
      orig(id)
      SyncInput()
    end
  end

  SkinCountUi()
  SyncInput()
end

if SoloSkin and SoloSkin.Register then
  SoloSkin.Register("SoloCraftCount", function()
    HookAddonOrVariable("Blizzard_CraftUI", function()
      InstallCraftUi()
      SkinCountUi()
    end)
  end)
end

HookDialogs()
HookPickups()

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("CRAFT_SHOW")
f:RegisterEvent("CRAFT_CLOSE")
f:RegisterEvent("CRAFT_UPDATE")
f:RegisterEvent("SPELLCAST_START")
f:RegisterEvent("SPELLCAST_STOP")
f:RegisterEvent("SPELLCAST_FAILED")
f:RegisterEvent("SPELLCAST_INTERRUPTED")
f:SetScript("OnUpdate", function()
  if pendingNext then
    pendingNext = false
    if remaining < 1 then return end
    QueueCraft()
    return
  end
  if not needRetarget then return end
  if SpellIsTargeting and SpellIsTargeting() then
    needRetarget = false
    Retarget()
  end
end)
f:SetScript("OnEvent", function()
  if event == "PLAYER_LOGIN" then
    HookDialogs()
    HookPickups()
    if IsAddOnLoaded and IsAddOnLoaded("Blizzard_CraftUI") then
      InstallCraftUi()
    end
  elseif event == "ADDON_LOADED" and arg1 == "Blizzard_CraftUI" then
    InstallCraftUi()
  elseif event == "CRAFT_SHOW" then
    InstallCraftUi()
    SkinCountUi()
    SyncInput()
    HookDialogs()
  elseif event == "CRAFT_CLOSE" then
    ClearSession()
  elseif event == "CRAFT_UPDATE" then
    SyncInput()
  elseif event == "SPELLCAST_START" then
    if remaining > 0 then expectStop = true end
  elseif event == "SPELLCAST_FAILED" or event == "SPELLCAST_INTERRUPTED" then
    if remaining > 0 and expectStop then ClearBatch() end
  elseif event == "SPELLCAST_STOP" then
    if remaining < 1 or not expectStop then return end
    expectStop = false
    remaining = remaining - 1
    if remaining < 1 then
      ClearBatch()
      SyncInput()
      return
    end
    pendingNext = true
  end
end)
