--[[--------------------------------------------------------------------------
Micro bar dock. pfUI kills the stock MainMenuBar and can put the micro
buttons under the minimap. Addon minimap buttons (GMBox, farm, Atlas,
AtlasLoot, …) are collected by pfUI's abuttons panel; keep that panel under
the micro bar so the column reads as one dock, always open.
----------------------------------------------------------------------------]]

-- pfUI lays addon buttons on a full-minimap grid (rowsize 6), so four icons
-- sit in the left four cells. Shrink the strip to the icons and hang it from
-- the micro bar's center (TOP→BOTTOM is center-to-center).
local function DockAddonButtons()
  local micro = pfUI and pfUI.panel and pfUI.panel.microbutton
  local abs = pfUI and pfUI.addonbuttons
  if not micro or not abs or type(abs.buttons) ~= "table" then return end

  local list, i, name, btn, dock = {}
  for i = 1, table.getn(abs.buttons) do
    name = abs.buttons[i]
    btn = getglobal(name)
    if btn and btn:IsVisible() then
      dock = btn
      while dock:GetParent() and dock:GetParent() ~= abs
        and dock:GetParent() ~= UIParent
        and dock:GetParent() ~= Minimap
        and dock:GetParent() ~= MinimapBackdrop do
        dock = dock:GetParent()
      end
      if dock:GetParent() ~= abs then dock = btn end
      table.insert(list, { btn = btn, dock = dock })
    end
  end
  local n = table.getn(list)
  if n == 0 then
    abs:ClearAllPoints()
    abs:SetPoint("TOP", micro, "BOTTOM", 0, -4)
    if abs.minimapbutton then abs.minimapbutton:Hide() end
    return
  end

  local spacing = 4
  local size = list[1].dock:GetWidth()
  if not size or size < 1 then size = 28 end
  local width = n * size + (n + 1) * spacing
  local height = size + spacing * 2
  abs:SetWidth(width)
  abs:SetHeight(height)
  abs:ClearAllPoints()
  abs:SetPoint("TOP", micro, "BOTTOM", 0, -4)
  if abs.minimapbutton then abs.minimapbutton:Hide() end

  for i = 1, n do
    local x = spacing + (i - 1) * (size + spacing) + size / 2
    local y = -(spacing + size / 2)
    local entry = list[i]
    entry.btn:ClearAllPoints()
    entry.btn:SetPoint("CENTER", abs, "TOPLEFT", x, y)
    if entry.dock ~= entry.btn then
      entry.dock:ClearAllPoints()
      entry.dock:SetPoint("CENTER", abs, "TOPLEFT", x, y)
    end
  end
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
