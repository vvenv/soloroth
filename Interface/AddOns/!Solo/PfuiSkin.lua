--[[--------------------------------------------------------------------------
benilla's own ESC menu rungs and options window in pfUI's look, registered as
a pfUI skin (so pfUI's "disable skin" setting covers it too):

  * the ESC menu: no Edit Mode rung (benilla has nothing behind it) and no
    Support / Help rung (NoHelp.lua shuts that window); pfUI's own config
    rung is relabelled "Interface" / 「界面」 so players open settings as a
    product feature, not a third-party addon panel. Visible rungs are
    re-stacked (settings / leave / resume) with even rung spacing and larger
    gaps between groups, so hiding Edit Mode / Support leaves no holes;
  * the options window: no Game/AddOns tabs (AddOns has nothing behind it,
    Game alone is the whole window), and pfUI's backdrops, buttons,
    checkboxes, sliders, dropdowns, scroll bars and search box;
  * the script error log (/errors): pfUI's backdrop over the class trainer
    art it borrows, its list and detail panes bordered.
----------------------------------------------------------------------------]]

local ZH = (GetLocale and GetLocale() == "zhCN") and true or false

local function Texture(region)
  local path = region and region.GetTexture and region:GetTexture()
  return type(path) == "string" and path or ""
end

local function SkinGameMenu()
  local editMode = BenillaGameMenuButtonEditMode
  local support = BenillaGameMenuButtonSupport
  if editMode then editMode:Hide() end
  if support then support:Hide() end

  -- pfUI parks the title above the frame (TOP +16), so the era's 32/28
  -- insets leave a hollow band; tighten to match the skinned look. ITEM
  -- between rungs in a group; GAP between settings / leave / resume.
  local TOP, BOTTOM, ITEM, GAP = -12, 16, 6, 20

  local function LabelUI()
    local ui = GameMenuButtonPFUI
    if ui and ui.SetText then
      ui:SetText(ZH and "界面" or "Interface")
    end
  end

  local function Layout()
    local ui = GameMenuButtonPFUI
    local addons = GameMenuButtonPFUIAddOns
    local options = GameMenuButtonOptions
    local macros = GameMenuButtonMacros
    local logout = GameMenuButtonLogout
    local quit = GameMenuButtonQuit
    local cont = GameMenuButtonContinue
    if not (ui and options and macros and logout and quit and cont) then return end

    local function place(btn, above, dy)
      btn:ClearAllPoints()
      if above then
        btn:SetPoint("TOP", above, "BOTTOM", 0, dy or 0)
      else
        btn:SetPoint("TOP", GameMenuFrame, "TOP", 0, TOP)
      end
    end

    -- Settings: Interface, AddOns, Options, Macros
    place(ui)
    local prev = ui
    local items = 0
    if addons then
      place(addons, prev, -ITEM)
      prev = addons
      items = items + 1
    end
    place(options, prev, -ITEM)
    place(macros, options, -ITEM)
    items = items + 3
    -- Leave
    place(logout, macros, -GAP)
    place(quit, logout, -ITEM)
    items = items + 1
    -- Resume
    place(cont, quit, -GAP)

    local bh = options:GetHeight() or 21
    local n = addons and 7 or 6
    GameMenuFrame:SetHeight((-TOP) + n * bh + items * ITEM + 2 * GAP + BOTTOM)
  end

  LabelUI()
  Layout()
  if GameMenuFrame and not GameMenuFrame.soloUILabel then
    GameMenuFrame.soloUILabel = true
    local prev = GameMenuFrame:GetScript("OnShow")
    GameMenuFrame:SetScript("OnShow", function()
      if prev then prev() end
      LabelUI()
      Layout()
    end)
  end
end

-- The page body is a scroll child, where benilla draws a child frame over its
-- parent's text whatever their levels; pfUI's widget skins hang their
-- backdrop on a child frame, so the controls there carry it themselves.
local function SkinCheck(check)
  check:SetNormalTexture("")
  check:SetPushedTexture("")
  check:SetHighlightTexture("")
  check:SetWidth(14)
  check:SetHeight(14)
  CreateBackdrop(check, nil, true)
end

local function SkinSliderRow(slider)
  local groove = getglobal(slider:GetParent():GetName() .. "Groove")
  if groove then
    CreateBackdrop(groove, nil, true)
    groove:SetHeight(6)
  end
  local thumb = slider:GetThumbTexture()
  thumb:SetTexture(1, .82, 0)
  thumb:SetWidth(8)
  thumb:SetHeight(14)
end

local function SkinDropdown(dd)
  local name = dd:GetName()
  StripTextures(dd)
  CreateBackdrop(dd, nil, true)
  local button = getglobal(name .. "Button")
  button:SetNormalTexture("")
  button:SetPushedTexture("")
  button:SetHighlightTexture("")
  button:SetDisabledTexture("")
  if not button.icon then
    button.icon = button:CreateTexture(nil, "OVERLAY")
    button.icon:SetTexture(pfUI.media["img:down"])
    button.icon:SetVertexColor(1, .9, .1)
    button.icon:SetWidth(10)
    button.icon:SetHeight(10)
    button.icon:SetPoint("CENTER", button, "CENTER", 0, 0)
  end
end

-- Every control under the options window, found by what it is.
local function SkinControls(frame)
  for _, child in ipairs({ frame:GetChildren() }) do
    local name = child:GetName() or ""
    local kind = child:GetObjectType()

    if kind == "CheckButton" and strfind(Texture(child:GetNormalTexture()), "UI%-CheckBox") then
      SkinCheck(child)
    elseif kind == "Button" and strfind(Texture(child:GetNormalTexture()), "UI%-Panel%-Button") then
      SkinButton(child)
    elseif kind == "Slider" and getglobal(name .. "ScrollUpButton") then
      SkinScrollbar(child)
    elseif kind == "Slider" then
      SkinSliderRow(child)
    elseif kind == "EditBox" then
      StripTextures(child)
      CreateBackdrop(child, nil, true)
    elseif strfind(name, "Dropdown$") and getglobal(name .. "Button") then
      SkinDropdown(child)
    elseif strfind(name, "Trough$") then
      StripTextures(child, true)
    end

    SkinControls(child)
  end
end

local function SkinOptions()
  local frame = BenillaOptionsFrame
  if not frame then return end

  StripTextures(frame)
  CreateBackdrop(frame, nil, true, .75)
  CreateBackdropShadow(frame)

  local title = BenillaOptionsFrameTitleText
  title:ClearAllPoints()
  title:SetPoint("TOP", frame, "TOP", 0, 16)
  title:SetTextColor(1, 1, 1, 1)
  title:SetFont(pfUI.font_default, C.global.font_size + 2, "OUTLINE")

  BenillaOptionsFrameGameTab:Hide()
  BenillaOptionsFrameAddOnsTab:Hide()

  for _, box in ipairs({ BenillaOptionsFrameCategoryBox, BenillaOptionsFramePageBox }) do
    box:SetBackdrop(nil)
    CreateBackdrop(box, nil, true, .5)
  end

  SkinControls(frame)
end

-- On the class trainer's art, so cut as pfUI cuts the class trainer.
local function SkinScriptLog()
  local frame = BenillaScriptLogFrame
  if not frame then return end

  StripTextures(frame)
  CreateBackdrop(frame, nil, nil, .75)
  CreateBackdropShadow(frame)
  frame.backdrop:SetPoint("TOPLEFT", 10, -10)
  frame.backdrop:SetPoint("BOTTOMRIGHT", -32, 72)
  frame:SetHitRectInsets(10, 32, 10, 72)

  BenillaScriptLogTitle:ClearAllPoints()
  BenillaScriptLogTitle:SetPoint("TOP", frame.backdrop, "TOP", 0, -10)
  SoloSkin.Close(BenillaScriptLogCloseButton)

  for _, pane in ipairs({ BenillaScriptLogListScrollFrame, BenillaScriptLogDetailScroll }) do
    local border = SoloSkin.Frame(frame, pane)
    border:SetFrameLevel(frame:GetFrameLevel())
    border:SetBackdropColor(0, 0, 0, .35)
  end
  SoloSkin.Controls(frame)

  BenillaScriptLogCloseBottomButton:ClearAllPoints()
  BenillaScriptLogCloseBottomButton:SetPoint("BOTTOMRIGHT", frame.backdrop, "BOTTOMRIGHT", -8, 8)
  BenillaScriptLogClearButton:ClearAllPoints()
  BenillaScriptLogClearButton:SetPoint("RIGHT", BenillaScriptLogCloseBottomButton, "LEFT", -4, 0)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function()
  if arg1 ~= "pfUI" or not pfUI or not pfUI.RegisterSkin then return end
  this:UnregisterEvent("ADDON_LOADED")
  pfUI:RegisterSkin("Benilla", "vanilla", function()
    -- pfUI runs a skin in its own environment, where SkinButton and the rest
    -- live; the helpers above need it too.
    local env = getfenv(1)
    for _, f in ipairs({ Texture, SkinGameMenu, SkinCheck, SkinSliderRow, SkinDropdown, SkinControls, SkinOptions, SkinScriptLog }) do
      setfenv(f, env)
    end
    SkinGameMenu()
    SkinOptions()
    SkinScriptLog()
  end)
end)
