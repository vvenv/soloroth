--[[--------------------------------------------------------------------------
benilla's own ESC menu rungs and options window in pfUI's look, registered as
a pfUI skin (so pfUI's "disable skin" setting covers it too):

  * the ESC menu: no Edit Mode rung (benilla has nothing behind it), no
    SuperMacro side tab (its editor stays on /supermacro), Help in pfUI's
    button style;
  * the options window: no Game/AddOns tabs (AddOns has nothing behind it,
    Game alone is the whole window), and pfUI's backdrops, buttons,
    checkboxes, sliders, dropdowns, scroll bars and search box.
----------------------------------------------------------------------------]]

local function Texture(region)
  local path = region and region.GetTexture and region:GetTexture()
  return type(path) == "string" and path or ""
end

local function SkinGameMenu()
  local editMode = BenillaGameMenuButtonEditMode
  local support = BenillaGameMenuButtonSupport
  if editMode and support then
    local point, relativeTo, relativePoint, x, y = editMode:GetPoint()
    editMode:Hide()
    support:ClearAllPoints()
    support:SetPoint(point, relativeTo, relativePoint, x, y)
    GameMenuFrame:SetHeight(GameMenuFrame:GetHeight() - editMode:GetHeight())
    SkinButton(support)
  end
  -- SuperMacro loads after pfUI has run its skins: hide its tab at each open.
  local show = GameMenuFrame:GetScript("OnShow")
  GameMenuFrame:SetScript("OnShow", function()
    if show then show() end
    if GameMenuButtonSuperMacro then GameMenuButtonSuperMacro:Hide() end
  end)
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

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function()
  if arg1 ~= "pfUI" or not pfUI or not pfUI.RegisterSkin then return end
  this:UnregisterEvent("ADDON_LOADED")
  pfUI:RegisterSkin("Benilla", "vanilla", function()
    -- pfUI runs a skin in its own environment, where SkinButton and the rest
    -- live; the helpers above need it too.
    local env = getfenv(1)
    for _, f in ipairs({ Texture, SkinGameMenu, SkinCheck, SkinSliderRow, SkinDropdown, SkinControls, SkinOptions }) do
      setfenv(f, env)
    end
    SkinGameMenu()
    SkinOptions()
  end)
end)
