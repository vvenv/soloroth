--[[--------------------------------------------------------------------------
Soloroth command strip under the minimap: one chrome frame holding two rows of
pfUI action-bar squares — character / book / talent / map / menu above, then
travel → gear → pets → tools → party → farm → dungeon. Same size, same border;
the rows are layout only, not "system vs addon".

Stock micro buttons are 33×44; pfUI only scales that art. Feature buttons wear
the round minimap ring. Both become cropped action-bar icons. pfUI still
collects the feature buttons; after it places them they are packed here in a
fixed order. Icons are chosen so none match the faces above (especially not
the world-map tile). The strip matches the minimap width; squares shrink to
fit. Atlas / AtlasLoot open from /gd.
Social and Help are shut in NoSocial / NoHelp; Quest Log in NoQuest.
----------------------------------------------------------------------------]]

-- Top row: character / book / talent / map / menu. No letter, no "?".
local MICRO = {
  { "CharacterMicroButton" },
  { "SpellbookMicroButton", "Interface\\Icons\\INV_Misc_Book_09" },
  { "TalentMicroButton", "Interface\\Icons\\Ability_Marksmanship" },
  { "WorldMapMicroButton", "Interface\\Icons\\INV_Misc_Map_01" },
  { "MainMenuMicroButton", "Interface\\Icons\\INV_Misc_Gear_01" },
}

-- Feature row order. Discovery order from pfUI varies with load order.
local FEATURE_ORDER = {
  "TeleportMinimapButton",
  "ItemsMinimapButton",
  "CompanionsMinimapButton",
  "GMBoxMinimapButton",
  "BotsMinimapButton",
  "SoloFarmMinimapButton",
  "DungeonMinimapButton",
}

local talentHooked
local strip  -- SoloCommandStrip: one backdrop around both rows

local function MapWidth(frame)
  local map = pfUI and pfUI.minimap
  local w = map and map.GetWidth and map:GetWidth()
  if not w or w < 40 then w = 170 end
  if frame and map and frame.GetEffectiveScale and map.GetEffectiveScale then
    local fs, ms = frame:GetEffectiveScale(), map:GetEffectiveScale()
    if fs and fs > 0 and ms then w = w * ms / fs end
  end
  return w
end

local function Border()
  local border = 2
  if pfUI and pfUI.api and pfUI.api.GetBorderSize then
    local _, scaled = pfUI.api.GetBorderSize("actionbars")
    if scaled and scaled > 0 then border = scaled end
  end
  return border
end

-- `n` squares, each border drawn outside the button. The row stays inside
-- the minimap width: a border of inset on the ends, and a gap that clears
-- both borders plus a little air.
local function Fit(n, frame)
  local mapW = MapWidth(frame)
  local border = Border()
  local inset = math.ceil(border)
  local gap = math.ceil(border * 2 + 2)
  if n < 1 then return 16, gap, mapW, inset end
  local size = math.floor((mapW - inset * 2 - (n - 1) * gap) / n)
  if size < 14 then
    gap = math.ceil(border * 2)
    size = math.floor((mapW - inset * 2 - (n - 1) * gap) / n)
  end
  if size < 12 then size = 12 end
  return size, gap, mapW, inset
end

local function IsItemIcon(path)
  if type(path) ~= "string" then return end
  local low = string.lower(path)
  return strfind(low, "icons\\") or strfind(low, "icons/")
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
local function Square(btn, icon, crop, size)
  local A = pfUI and pfUI.api
  if not A or not A.CreateBackdrop or not btn then return end
  -- Hot-reload can keep an old SkinMicro that still calls Square without size.
  size = tonumber(size)
  if not size or size < 1 then size = 16 end
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

local function Pack(parent, buttons, size, gap, mapW, inset)
  local n = table.getn(buttons)
  if n < 1 then return end
  size = tonumber(size) or 16
  gap = tonumber(gap) or 4
  -- Hot-reload can keep an old SkinMicro that still calls Pack(..., pad).
  if inset == nil then
    local pad = tonumber(mapW) or 0
    parent:SetWidth(pad * 2 + n * size + (n - 1) * gap)
    parent:SetHeight(size + pad * 2)
    local i = 1
    while buttons[i] do
      buttons[i]:ClearAllPoints()
      buttons[i]:SetPoint("LEFT", parent, "LEFT", pad + (i - 1) * (size + gap), 0)
      i = i + 1
    end
    return
  end
  mapW = tonumber(mapW)
  inset = tonumber(inset) or 0
  if not mapW or mapW < 40 then
    mapW = inset * 2 + n * size + (n - 1) * gap
  end
  parent:SetWidth(mapW)
  parent:SetHeight(size + inset * 2)
  local row = n * size + (n - 1) * gap
  local spare = mapW - inset * 2 - row
  if spare < 0 then spare = 0 end
  local pad = inset + math.floor(spare / 2)
  local i = 1
  while buttons[i] do
    buttons[i]:ClearAllPoints()
    buttons[i]:SetPoint("LEFT", parent, "LEFT", pad + (i - 1) * (size + gap), 0)
    i = i + 1
  end
end

local function ShownFeatures()
  local abs = pfUI and pfUI.addonbuttons
  local shown, byName, i = {}, {}, 1
  if not abs then return shown end
  while abs.buttons and abs.buttons[i] do
    local name = abs.buttons[i]
    local btn = getglobal(name)
    if btn and btn:IsVisible() then byName[name] = btn end
    i = i + 1
  end
  i = 1
  while FEATURE_ORDER[i] do
    local name = FEATURE_ORDER[i]
    if byName[name] then
      table.insert(shown, byName[name])
      byName[name] = nil
    end
    i = i + 1
  end
  i = 1
  while abs.buttons and abs.buttons[i] do
    local name = abs.buttons[i]
    if byName[name] then table.insert(shown, byName[name]) end
    i = i + 1
  end
  return shown
end

local function DropStockMicro(name)
  local btn = getglobal(name)
  if btn then
    btn:Hide()
    btn:ClearAllPoints()
  end
end

local function EnsureStrip()
  if strip then return strip end
  local A = pfUI and pfUI.api
  if not A or not A.CreateBackdrop then return end
  strip = CreateFrame("Frame", "SoloCommandStrip", UIParent)
  strip:SetFrameStrata("MEDIUM")
  A.CreateBackdrop(strip, nil, nil, .75)
  if A.CreateBackdropShadow then A.CreateBackdropShadow(strip) end
  return strip
end

-- Drop the feature row's own panel chrome so only SoloCommandStrip shows.
local function ClearFeatureChrome(abs)
  if not abs then return end
  if abs.SetBackdrop then abs:SetBackdrop(nil) end
  if abs.backdrop then
    abs.backdrop:Hide()
    abs.backdrop.Show = function() end
  end
  if abs.backdrop_shadow then
    abs.backdrop_shadow:Hide()
    abs.backdrop_shadow.Show = function() end
  end
end

local function SkinMicro()
  local micro = pfUI and pfUI.panel and pfUI.panel.microbutton
  if not micro or not (pfUI.api and pfUI.api.CreateBackdrop) then return end
  DropStockMicro("QuestLogMicroButton")
  DropStockMicro("SocialsMicroButton")
  DropStockMicro("HelpMicroButton")
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
  local n = table.getn(shown)
  local feats = ShownFeatures()
  if table.getn(feats) > n then n = table.getn(feats) end
  local size, gap, mapW, inset = Fit(n, micro)
  i = 1
  while shown[i] do
    local name = shown[i]:GetName()
    local icon = (name == "CharacterMicroButton") and getglobal("MicroButtonPortrait") or shown[i].soloIcon
    Square(shown[i], icon, name ~= "CharacterMicroButton", size)
    i = i + 1
  end
  Pack(micro, shown, size, gap, mapW, inset)
  if not talentHooked and UpdateTalentButton then
    talentHooked = true
    local old = UpdateTalentButton
    UpdateTalentButton = function()
      old()
      SkinMicro()
    end
  end
end

local function FeatureIcon(btn)
  if btn.soloIcon then return btn.soloIcon end
  local _, region
  for _, region in ipairs({ btn:GetRegions() }) do
    if IsItemIcon(region.GetTexture and region:GetTexture()) then
      btn.soloIcon = region
      return region
    end
  end
end

local function SkinFeatureButton(btn, size)
  local icon = FeatureIcon(btn)
  Square(btn, icon, true, size)
  if icon then icon:SetVertexColor(1, 1, 1) end
end

-- A menu dropped from the command strip: same width, sitting on its bottom
-- edge. `buttons` is the list of rows, widened to the strip.
function Solo_PlaceStripMenu(menu, buttons)
  local names = { "SoloFarmMenu", "BotsMenu" }
  local i = 1
  while names[i] do
    local other = getglobal(names[i])
    if other and other ~= menu and other:IsShown() then other:Hide() end
    i = i + 1
  end
  local bar = strip or (pfUI and pfUI.addonbuttons)
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

local function DockCommandStrip()
  local micro = pfUI and pfUI.panel and pfUI.panel.microbutton
  local abs = pfUI and pfUI.addonbuttons
  local map = pfUI and pfUI.minimap
  if not micro or not abs or not map then return end

  local shell = EnsureStrip()
  if not shell then return end

  ClearFeatureChrome(abs)

  local zone = pfUI.panel and pfUI.panel.minimap
  shell:ClearAllPoints()
  if zone and zone:IsShown() then
    shell:SetPoint("TOP", zone, "BOTTOM", 0, -2)
  else
    shell:SetPoint("TOP", map, "BOTTOM", 0, -2)
  end

  SkinMicro()
  local shown = ShownFeatures()
  local n, nMicro, i = table.getn(shown), 0, 1
  while MICRO[i] do
    local btn = getglobal(MICRO[i][1])
    if btn and btn:IsShown() then nMicro = nMicro + 1 end
    i = i + 1
  end
  if nMicro > n then n = nMicro end
  local size, gap, mapW, inset = Fit(n, abs)
  i = 1
  while shown[i] do
    SkinFeatureButton(shown[i], size)
    i = i + 1
  end
  Pack(abs, shown, size, gap, mapW, inset)

  -- Chrome only: do not reparent micro or the feature row into the shell.
  -- pfUI's addonbuttons walker would then SetParent the shell back onto the
  -- feature row and hit a parenting loop.
  local rowGap = 4
  local h = micro:GetHeight() + rowGap + abs:GetHeight()
  shell:SetWidth(mapW)
  shell:SetHeight(h)
  local behind = math.max((micro:GetFrameLevel() or 2) - 1, 0)
  if (abs:GetFrameLevel() or 0) <= behind then
    behind = math.max((abs:GetFrameLevel() or 2) - 1, 0)
  end
  shell:SetFrameLevel(behind)

  micro:ClearAllPoints()
  micro:SetPoint("TOP", shell, "TOP", 0, 0)

  abs:ClearAllPoints()
  abs:SetPoint("TOP", micro, "BOTTOM", 0, -rowGap)
  if abs.minimapbutton then
    abs.minimapbutton:Hide()
    abs.minimapbutton.Show = function() end
  end
  if not abs:IsShown() then abs:Show() end
  if not shell:IsShown() then shell:Show() end
end

local function HookFeatureButtons()
  local abs = pfUI and pfUI.addonbuttons
  if not abs or type(abs.ProcessButtons) ~= "function" then return end
  if not abs.soloDocked then
    abs.soloDocked = true
    local old = abs.ProcessButtons
    abs.ProcessButtons = function(self)
      old(self)
      DockCommandStrip()
    end
  end
  DockCommandStrip()
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
  HookFeatureButtons()
  SkinMicro()
  if event == "PLAYER_ENTERING_WORLD" then
    RestoreTalentKey()
    this.soloMicroWait = 0
    this:SetScript("OnUpdate", function()
      this.soloMicroWait = this.soloMicroWait + arg1
      HookFeatureButtons()
      SkinMicro()
      if this.soloMicroWait < 4 then return end
      this:SetScript("OnUpdate", nil)
      if pfUI and pfUI.addonbuttons and pfUI.addonbuttons.ProcessButtons then
        pfUI.addonbuttons:ProcessButtons()
      end
    end)
  end
end)
