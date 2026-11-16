--[[--------------------------------------------------------------------------
Micro bar dock. pfUI kills the stock MainMenuBar and puts micro buttons under
the minimap. Addon minimap buttons (GMBox, party, farm, Atlas, AtlasLoot, …) go into
pfUI's abuttons strip under that.

pfUI packs icons on a rowsize-wide grid. Solo sets rowsize to the live button
count so the icons fill the strip evenly (centered as a group). This file only
keeps the strip parked under the micro bar.
----------------------------------------------------------------------------]]

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

local function CountVisible(abs)
  local n, i, btn = 0, 1
  while abs.buttons and abs.buttons[i] do
    btn = getglobal(abs.buttons[i])
    if btn and btn:IsVisible() then n = n + 1 end
    i = i + 1
  end
  return n
end

local function DockAddonButtons()
  local micro = pfUI and pfUI.panel and pfUI.panel.microbutton
  local abs = pfUI and pfUI.addonbuttons
  local map = pfUI and pfUI.minimap
  if not micro or not abs or not map then return end

  CenterMicroOnMinimap()
  abs:ClearAllPoints()
  abs:SetWidth(map:GetWidth() or 170)
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
      -- Match columns to icons so pfUI's own grid fills evenly (no left gap).
      if pfUI_config and pfUI_config.abuttons then
        local n = CountVisible(self)
        if n < 1 then n = table.getn(self.buttons or {}) end
        if n < 1 then n = 4 end
        pfUI_config.abuttons.rowsize = tostring(n)
      end
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
ev:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" and arg1 ~= "pfUI" then return end
  HookAddonButtons()
  if event == "PLAYER_ENTERING_WORLD" then
    RestoreTalentKey()
    this.soloMicroWait = 0
    this:SetScript("OnUpdate", function()
      this.soloMicroWait = this.soloMicroWait + arg1
      HookAddonButtons()
      if this.soloMicroWait < 4 then return end
      this:SetScript("OnUpdate", nil)
      if pfUI and pfUI.addonbuttons and pfUI.addonbuttons.ProcessButtons then
        pfUI.addonbuttons:ProcessButtons()
      end
    end)
  end
end)
