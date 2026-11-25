--[[--------------------------------------------------------------------------
Enchanting uses CraftFrame (no Create All / count), unlike smelting's
TradeSkill. Permanent enchants now CreateItem scrolls, so batching is just
repeated DoCraft — no item retarget / REPLACE skip.

CraftCreateButton's stock label is getglobal(GetCraftButtonToken()) → ENSCRIBE
("Enchant" / 「附魔」). Scroll crafting reads as Create, so remap to CREATE.

Cancel on craft close, cast fail, or count exhausted.
----------------------------------------------------------------------------]]

local ZH = (GetLocale and GetLocale() == "zhCN") and true or false
local function L(en, zh) if ZH and zh then return zh end return en end

local CREATE_LABEL = CREATE or L("Create", "制造")

local remaining = 0
local pendingNext = false
local expectStop = false
local uiReady = false

local input, createAll, minus, plus
local skinReady = false

local function RelabelCreate()
  -- FrameXML looks up ENSCRIBE on show / selection; keep the global and the
  -- button in sync so a late CraftFrame_SetSelection cannot restore 「附魔」.
  ENSCRIBE = CREATE_LABEL
  if CraftCreateButton then CraftCreateButton:SetText(CREATE_LABEL) end
end

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
  pendingNext = false
  expectStop = false
end

local function QueueCraft()
  local idx = GetCraftSelectionIndex and GetCraftSelectionIndex()
  if not idx or idx == 0 then
    ClearBatch()
    return
  end
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
  pendingNext = false
  expectStop = false
  DoCraft(idx)
end

local function LayoutActions()
  local detail = CraftDetailScrollFrame
  local bd = detail and detail.backdrop
  if not (SoloSkin and SoloSkin.ProfessionActions and bd) then return end
  SoloSkin.ProfessionActions(bd, createAll, minus, input, plus, CraftCreateButton, CraftCancelButton)
  if CraftFramePointsText and createAll then
    CraftFramePointsText:ClearAllPoints()
    CraftFramePointsText:SetPoint("LEFT", createAll, "RIGHT", 8, 0)
  end
end

local function SkinCountUi()
  if skinReady or not createAll then return end
  if not (pfUI and pfUI.api and SoloSkin) then return end
  local A = pfUI.api
  SoloSkin.Button(createAll)
  if minus then A.SkinArrowButton(minus, "left", 22) end
  if plus then A.SkinArrowButton(plus, "right", 22) end
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
  LayoutActions()
end

local function InstallCraftUi()
  if uiReady or not CraftFrame or not CraftCreateButton then return end
  uiReady = true

  RelabelCreate()

  -- Widgets only; SoloSkin.ProfessionActions matches TradeSkill justify/height.
  local create = CraftCreateButton
  local level = (create:GetFrameLevel() or 1) + 2

  plus = CreateFrame("Button", "SoloCraftIncrementButton", CraftFrame)
  plus:SetFrameLevel(level)
  plus:SetScript("OnClick", function()
    local avail = Available()
    input:SetNumber(ClampCount(input:GetNumber() + 1, avail > 0 and avail or nil))
  end)

  input = CreateFrame("EditBox", "SoloCraftInputBox", CraftFrame, "InputBoxTemplate")
  input:SetNumeric(true)
  input:SetMaxLetters(3)
  input:SetAutoFocus(false)
  input:SetNumber(1)
  input:SetScript("OnEnterPressed", function()
    this:ClearFocus()
    SyncInput()
  end)
  input:SetScript("OnEditFocusLost", SyncInput)

  minus = CreateFrame("Button", "SoloCraftDecrementButton", CraftFrame)
  minus:SetFrameLevel(level)
  minus:SetScript("OnClick", function()
    input:SetNumber(ClampCount(input:GetNumber() - 1, Available()))
  end)

  createAll = CreateFrame("Button", "SoloCraftCreateAllButton", CraftFrame, "UIPanelButtonTemplate")
  createAll:SetWidth(80)
  createAll:SetFrameLevel(level)
  createAll:SetText(CREATE_ALL or L("Create All", "全部制造"))
  createAll:SetScript("OnClick", function()
    local n = Available()
    if n < 1 then n = ClampCount(input and input:GetNumber() or 1, nil) end
    StartBatch(n)
  end)

  create:SetScript("OnClick", function()
    SyncInput()
    StartBatch(input:GetNumber())
  end)

  if type(CraftFrame_SetSelection) == "function" then
    local orig = CraftFrame_SetSelection
    CraftFrame_SetSelection = function(id)
      orig(id)
      RelabelCreate()
      SyncInput()
    end
  end

  SkinCountUi()
  LayoutActions()
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
  if not pendingNext then return end
  pendingNext = false
  if remaining < 1 then return end
  QueueCraft()
end)
f:SetScript("OnEvent", function()
  if event == "PLAYER_LOGIN" then
    if IsAddOnLoaded and IsAddOnLoaded("Blizzard_CraftUI") then
      InstallCraftUi()
    end
  elseif event == "ADDON_LOADED" and arg1 == "Blizzard_CraftUI" then
    InstallCraftUi()
  elseif event == "CRAFT_SHOW" then
    InstallCraftUi()
    RelabelCreate()
    SkinCountUi()
    LayoutActions()
    SyncInput()
  elseif event == "CRAFT_CLOSE" then
    ClearBatch()
  elseif event == "CRAFT_UPDATE" then
    RelabelCreate()
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
