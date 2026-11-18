--[[--------------------------------------------------------------------------
Micro bar and addon-button strip, both drawn as pfUI action-bar squares.

Stock micro buttons are 33×44 with the glyph in the lower half; pfUI only
scales that art. Addon buttons wear the round minimap ring, which is drawn
larger than the button itself (pfUI sizes the cell from the button, so the
ring spills out). This file replaces both with the action-bar icon: cropped,
border from the action-bar setting, same size and gap as bar 1.

pfUI still collects the addon buttons. After it places them, they are packed
into a row under the micro buttons. Atlas / AtlasLoot open from /gd.
----------------------------------------------------------------------------]]

local MICRO = {
  { "CharacterMicroButton" },
  { "SpellbookMicroButton", "Interface\\Icons\\INV_Misc_Book_09" },
  { "TalentMicroButton", "Interface\\Icons\\Ability_Marksmanship" },
  { "SocialsMicroButton", "Interface\\Icons\\INV_Letter_15" },
  { "WorldMapMicroButton", "Interface\\Icons\\INV_Misc_Map_01" },
  { "MainMenuMicroButton", "Interface\\Icons\\INV_Misc_Gear_01" },
  { "HelpMicroButton", "Interface\\Icons\\INV_Misc_QuestionMark" },
}

local PAD = 4
local talentHooked

local function IsItemIcon(path)
  if type(path) ~= "string" then return end
  local low = string.lower(path)
  return strfind(low, "icons\\") or strfind(low, "icons/")
end

local function ButtonMetrics()
  local bar = pfUI_config and pfUI_config.bars and pfUI_config.bars.bar1
  local size = bar and tonumber(bar.icon_size)
  local gap = bar and tonumber(bar.spacing)
  if not size or size < 14 or size > 32 then size = 20 end
  if not gap or gap < 0 or gap > 12 then gap = 1 end
  return size, gap
end

local function HideChrome(btn, keep)
  if btn.SetHighlightTexture then btn:SetHighlightTexture("") end
  if btn.SetNormalTexture then btn:SetNormalTexture("") end
  if btn.SetPushedTexture then btn:SetPushedTexture("") end
  if btn.SetDisabledTexture then btn:SetDisabledTexture("") end
  local _, region
  for _, region in ipairs({ btn:GetRegions() }) do
    if region ~= keep and region.Hide and region.GetObjectType
        and region:GetObjectType() == "Texture" and not IsItemIcon(region:GetTexture()) then
      region:Hide()
      -- The menu button's OnUpdate shows the stock face again every frame.
      region.Show = function() end
    end
  end
end

-- `crop` is for item icons. The character portrait already has its own
-- coordinates from SetPortraitTexture; overwriting them shows the raw image.
local function Square(btn, icon, crop)
  local A = pfUI and pfUI.api
  if not A or not A.CreateBackdrop or not btn then return end
  local size = ButtonMetrics()
  btn:SetScale(1)
  btn:SetWidth(size)
  btn:SetHeight(size)
  if btn.frame then
    btn.frame:Hide()
    btn.frame.Show = function() end
  end
  HideChrome(btn, icon)
  -- The menu button's OnUpdate puts the stock face back every frame.
  if not btn.soloFaceLocked then
    btn.soloFaceLocked = true
    btn.SetNormalTexture = function() end
    btn.SetPushedTexture = function() end
    btn.SetDisabledTexture = function() end
    btn.SetHighlightTexture = function() end
  end
  if not btn.backdrop then
    local _, border = A.GetBorderSize("actionbars")
    A.CreateBackdrop(btn, border)
  end
  if icon then
    icon:ClearAllPoints()
    icon:SetAllPoints(btn)
    if crop then icon:SetTexCoord(.08, .92, .08, .92) end
    icon:SetDrawLayer("ARTWORK")
    icon:Show()
  end
  if not btn.soloSquare and A.SetHighlight then
    btn.soloSquare = true
    A.SetHighlight(btn)
  end
end

local function Pack(parent, buttons, size, gap, pad)
  local n = table.getn(buttons)
  if n < 1 then return end
  parent:SetWidth(pad * 2 + n * size + (n - 1) * gap)
  parent:SetHeight(size + pad * 2)
  local i = 1
  while buttons[i] do
    buttons[i]:ClearAllPoints()
    buttons[i]:SetPoint("LEFT", parent, "LEFT", pad + (i - 1) * (size + gap), 0)
    i = i + 1
  end
end

local function SkinMicro()
  local micro = pfUI and pfUI.panel and pfUI.panel.microbutton
  if not micro or not (pfUI.api and pfUI.api.CreateBackdrop) then return end
  if QuestLogMicroButton then
    QuestLogMicroButton:Hide()
    QuestLogMicroButton:ClearAllPoints()
  end
  local size, gap = ButtonMetrics()
  local shown, i = {}, 1
  while MICRO[i] do
    local name, path = MICRO[i][1], MICRO[i][2]
    local btn = getglobal(name)
    if btn and btn:IsShown() then
      local icon
      if name == "CharacterMicroButton" then
        icon = getglobal("MicroButtonPortrait")
        if icon and not btn.soloPortrait and SetPortraitTexture then
          SetPortraitTexture(icon, "player")
          btn.soloPortrait = true
        end
      elseif path then
        if not btn.soloIcon then
          btn.soloIcon = btn:CreateTexture(nil, "ARTWORK")
          btn.soloIcon:SetTexture(path)
        end
        icon = btn.soloIcon
      end
      Square(btn, icon, name ~= "CharacterMicroButton")
      if icon then
        if btn.IsEnabled and not btn:IsEnabled() then
          icon:SetVertexColor(.45, .45, .45)
        else
          icon:SetVertexColor(1, 1, 1)
        end
      end
      table.insert(shown, btn)
    end
    i = i + 1
  end
  Pack(micro, shown, size, gap, 0)
  if not talentHooked and UpdateTalentButton then
    talentHooked = true
    local old = UpdateTalentButton
    UpdateTalentButton = function()
      old()
      SkinMicro()
    end
  end
end

local function CenterMicroOnMinimap()
  local micro = pfUI and pfUI.panel and pfUI.panel.microbutton
  local map = pfUI and pfUI.minimap
  if not micro or not map then return end
  local zone = pfUI.panel and pfUI.panel.minimap
  micro:ClearAllPoints()
  if zone and zone:IsShown() then
    micro:SetPoint("TOP", zone, "BOTTOM", 0, -2)
  else
    micro:SetPoint("TOP", map, "BOTTOM", 0, -2)
  end
end

local function AddonIcon(btn)
  if btn.soloIcon then return btn.soloIcon end
  local _, region
  for _, region in ipairs({ btn:GetRegions() }) do
    if IsItemIcon(region.GetTexture and region:GetTexture()) then
      btn.soloIcon = region
      return region
    end
  end
end

local function SkinAddonButton(btn)
  local icon = AddonIcon(btn)
  Square(btn, icon, true)
  if icon then icon:SetVertexColor(1, 1, 1) end
end

-- A menu dropped from the addon-button strip: same width, sitting on its
-- bottom edge. `buttons` is the list of rows, widened to the strip.
function Solo_PlaceStripMenu(menu, buttons)
  local names = { "SoloFarmMenu", "BotsMenu" }
  local i = 1
  while names[i] do
    local other = getglobal(names[i])
    if other and other ~= menu and other:IsShown() then other:Hide() end
    i = i + 1
  end
  local bar = pfUI and pfUI.addonbuttons
  local map = (pfUI and pfUI.minimap) or Minimap
  local w = bar and bar:GetWidth() or 0
  if w < 40 then w = (map and map:GetWidth()) or 170 end
  menu:SetWidth(w)
  local bw = w - 16
  if bw < 40 then bw = 40 end
  i = 1
  while buttons and buttons[i] do
    buttons[i]:SetWidth(bw)
    i = i + 1
  end
  menu:ClearAllPoints()
  if bar and bar:IsShown() and (bar:GetWidth() or 0) >= 40 then
    menu:SetPoint("TOP", bar, "BOTTOM", 0, -2)
  elseif map then
    menu:SetPoint("TOP", map, "BOTTOM", 0, -2)
  end
end

local function DockAddonButtons()
  local micro = pfUI and pfUI.panel and pfUI.panel.microbutton
  local abs = pfUI and pfUI.addonbuttons
  local map = pfUI and pfUI.minimap
  if not micro or not abs or not map then return end

  CenterMicroOnMinimap()
  SkinMicro()
  local size, gap = ButtonMetrics()
  local shown, i = {}, 1
  while abs.buttons and abs.buttons[i] do
    local btn = getglobal(abs.buttons[i])
    if btn and btn:IsVisible() then
      SkinAddonButton(btn)
      table.insert(shown, btn)
    end
    i = i + 1
  end
  Pack(abs, shown, size, gap, PAD)
  abs:ClearAllPoints()
  abs:SetPoint("TOP", micro, "BOTTOM", 0, -4)
  if abs.minimapbutton then abs.minimapbutton:Hide() end
  if not abs:IsShown() then abs:Show() end
end

local function HookAddonButtons()
  local abs = pfUI and pfUI.addonbuttons
  if not abs or type(abs.ProcessButtons) ~= "function" then return end
  if not abs.soloDocked then
    abs.soloDocked = true
    local old = abs.ProcessButtons
    abs.ProcessButtons = function(self)
      old(self)
      DockAddonButtons()
    end
  end
  DockAddonButtons()
end

local ORPHAN_N = {
  [""] = true,
  ["VANILLABONK_INSPECT"] = true,
}

local function RestoreTalentKey()
  if type(GetBindingAction) ~= "function" or type(SetBinding) ~= "function" then return end
  local action = GetBindingAction("N") or ""
  if not ORPHAN_N[action] then return end
  SetBinding("N", "TOGGLETALENTS")
  if SaveBindings and GetCurrentBindingSet then
    SaveBindings(GetCurrentBindingSet())
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("UNIT_PORTRAIT_UPDATE")
ev:SetScript("OnEvent", function()
  if event == "UNIT_PORTRAIT_UPDATE" then
    if arg1 == "player" and SetPortraitTexture then
      local icon = getglobal("MicroButtonPortrait")
      if icon then SetPortraitTexture(icon, "player") end
    end
    return
  end
  if event == "ADDON_LOADED" and arg1 ~= "pfUI" then return end
  HookAddonButtons()
  SkinMicro()
  if event == "PLAYER_ENTERING_WORLD" then
    RestoreTalentKey()
    this.soloMicroWait = 0
    this:SetScript("OnUpdate", function()
      this.soloMicroWait = this.soloMicroWait + arg1
      HookAddonButtons()
      SkinMicro()
      if this.soloMicroWait < 4 then return end
      this:SetScript("OnUpdate", nil)
      if pfUI and pfUI.addonbuttons and pfUI.addonbuttons.ProcessButtons then
        pfUI.addonbuttons:ProcessButtons()
      end
    end)
  end
end)
