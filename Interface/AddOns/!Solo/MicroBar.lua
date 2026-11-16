--[[--------------------------------------------------------------------------
Micro bar dock. pfUI kills the stock MainMenuBar and can put the micro
buttons under the minimap. Addon minimap buttons (GMBox, farm, Atlas,
AtlasLoot, …) are collected by pfUI's abuttons panel; keep that panel under
the micro bar so the column reads as one dock, always open.
----------------------------------------------------------------------------]]

local function DockAddonButtons()
  local micro = pfUI and pfUI.panel and pfUI.panel.microbutton
  local abs = pfUI and pfUI.addonbuttons
  if not micro or not abs then return end
  abs:ClearAllPoints()
  abs:SetPoint("TOP", micro, "BOTTOM", 0, -4)
  -- The arrow on the minimap is for collapsing; with showdefault on, hide it.
  if abs.minimapbutton then abs.minimapbutton:Hide() end
end

local function HookAddonButtons()
  local abs = pfUI and pfUI.addonbuttons
  if not abs or abs.soloDocked then return end
  abs.soloDocked = true
  local old = abs.ProcessButtons
  if type(old) == "function" then
    abs.ProcessButtons = function(self)
      old(self)
      DockAddonButtons()
    end
  end
  if abs:IsShown() then
    DockAddonButtons()
  else
    abs:Show()
    DockAddonButtons()
  end
end

-- Orphan binds from a removed addon stole N (talents). Put the stock key back
-- when the current action is empty or that dead name.
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
    -- Late-created minimap buttons (farm, GMBox) land after the first scan.
    if this.soloMicroArmed then return end
    this.soloMicroArmed = true
    this.soloMicroWait = 0
    this:SetScript("OnUpdate", function()
      this.soloMicroWait = this.soloMicroWait + arg1
      if this.soloMicroWait < 2 then return end
      this:SetScript("OnUpdate", nil)
      HookAddonButtons()
      if pfUI and pfUI.addonbuttons and pfUI.addonbuttons.ProcessButtons then
        pfUI.addonbuttons:ProcessButtons()
      end
    end)
  end
end)
