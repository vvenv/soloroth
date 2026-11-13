--[[--------------------------------------------------------------------------
SuperMacro's editor (/supermacro) in pfUI's look, laid out as pfUI lays out
the stock macro window: its tooltip-bordered body becomes pfUI's backdrop,
the macro slots pfUI's icon buttons, the text areas pfUI's input panels; the
icon picker and the options window follow.
----------------------------------------------------------------------------]]

local function MacroSlots(prefix, count)
  for i = 0, count do
    local name = i == 0 and prefix or prefix .. i
    local b = getglobal(name)
    if b then SoloSkin.IconButton(b, getglobal(name .. "Icon")) end
  end
end

local function TextPanel(frame)
  frame:SetBackdrop(nil)
  pfUI.api.CreateBackdrop(frame, nil, true, .5)
end

SoloSkin.Register("SuperMacro", function()
  HookAddonOrVariable("SuperMacro", function()
    local f = SuperMacroFrame
    local body = SuperMacroFrameMainBackground
    body:SetBackdrop(nil)
    CreateBackdrop(f, nil, nil, .75)
    CreateBackdropShadow(f)
    f.backdrop:ClearAllPoints()
    f.backdrop:SetAllPoints(body)
    SuperMacroFramePortrait:Hide()
    SuperMacroFrameSelectedMacroBackground:Hide()
    SuperMacroFrameTitle:ClearAllPoints()
    SuperMacroFrameTitle:SetPoint("TOP", body, "TOP", 0, -8)
    SoloSkin.Close(SuperMacroFrameCloseButton, f)

    MacroSlots("SuperMacroButton", 36)
    MacroSlots("SuperMacroSuperButton", 36)
    MacroSlots("SuperMacroFrameSelectedMacroButton", 0)
    MacroSlots("SuperMacroFrameSelectedMacroSuperButton", 0)

    TextPanel(SuperMacroFrameTextBackground)
    TextPanel(SuperMacroFrameExtendTextBackground)
    TextPanel(SuperMacroFrameSuperTextBackground)

    SoloSkin.Controls(f)
    SuperMacroFrameTab1:ClearAllPoints()
    SuperMacroFrameTab1:SetPoint("TOPLEFT", body, "BOTTOMLEFT", 0, -4)
    SuperMacroFrameTab2:ClearAllPoints()
    SuperMacroFrameTab2:SetPoint("LEFT", SuperMacroFrameTab1, "RIGHT", 4, 0)

    -- the icon picker beside the editor
    local popup = SuperMacroPopupFrame
    StripTextures(popup)
    SoloSkin.Backdrop(popup)
    popup:ClearAllPoints()
    popup:SetPoint("TOPLEFT", f.backdrop, "TOPRIGHT", 4, 0)
    SoloSkin.EditBox(SuperMacroPopupEditBox, SuperMacroPopupNameLeft, SuperMacroPopupNameMiddle, SuperMacroPopupNameRight)
    StripTextures(SuperMacroPopupScrollFrame)
    MacroSlots("SuperMacroPopupButton", 20)
    SoloSkin.Controls(popup)

    local options = SuperMacroOptionsFrame
    StripTextures(options)
    SoloSkin.Backdrop(options)
    -- The window keeps the size of its spellbook art; the controls sit
    -- inside the page.
    options.backdrop:ClearAllPoints()
    options.backdrop:SetPoint("TOPLEFT", options, "TOPLEFT", 12, -12)
    options.backdrop:SetPoint("BOTTOMRIGHT", options, "BOTTOMRIGHT", -32, 76)
    SuperMacroOptionsTitleText:ClearAllPoints()
    SuperMacroOptionsTitleText:SetPoint("TOP", options.backdrop, "TOP", 0, -10)
    SoloSkin.Close(SuperMacroOptionsCloseButton)
    SuperMacroOptionsExitButton:ClearAllPoints()
    SuperMacroOptionsExitButton:SetPoint("BOTTOMRIGHT", options.backdrop, "BOTTOMRIGHT", -8, 8)
    for i = 1, 3 do
      local name = "SuperMacroOptionsFrameEditBox" .. i
      SoloSkin.EditBox(getglobal(name), getglobal(name .. "NameLeft"), getglobal(name .. "NameMiddle"), getglobal(name .. "NameRight"))
    end
    SoloSkin.Controls(options)
  end)
end)
