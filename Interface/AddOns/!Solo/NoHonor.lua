--[[--------------------------------------------------------------------------
No honor. Solo has no PvP ladder, so the stock Honor page and its character /
inspect tabs stay shut.
----------------------------------------------------------------------------]]

local hookedShowSub, hookedToggle, hookedInspect

local function Shut(frame)
  if not frame or frame.soloHonorShut then return end
  frame.soloHonorShut = true
  frame:Hide()
  frame.Show = function() end
end

local function ShutTab(tab)
  if not tab or tab.soloHonorShut then return end
  tab.soloHonorShut = true
  tab:Hide()
  tab.Show = function() end
end

-- CharacterFrame_ShowSubFrame hides every other page; if the last selected
-- tab was Honor, remap so PaperDoll still paints.
local function HookShowSubFrame()
  if hookedShowSub or type(CharacterFrame_ShowSubFrame) ~= "function" then return end
  hookedShowSub = true
  local orig = CharacterFrame_ShowSubFrame
  CharacterFrame_ShowSubFrame = function(frameName)
    if frameName == "HonorFrame" then frameName = "PaperDollFrame" end
    return orig(frameName)
  end
end

local function HookToggleCharacter()
  if hookedToggle or type(ToggleCharacter) ~= "function" then return end
  hookedToggle = true
  local orig = ToggleCharacter
  ToggleCharacter = function(tab)
    if tab == "HonorFrame" then tab = "PaperDollFrame" end
    return orig(tab)
  end
end

local function HookInspect()
  Shut(InspectHonorFrame)
  ShutTab(InspectFrameTab2)
  if hookedInspect or type(ToggleInspect) ~= "function" then return end
  hookedInspect = true
  local orig = ToggleInspect
  ToggleInspect = function(tab)
    if tab == "InspectHonorFrame" then tab = "InspectPaperDollFrame" end
    return orig(tab)
  end
end

local function Apply()
  Shut(HonorFrame)
  -- Fifth character tab is Honor (PaperDoll / Pet / Reputation / Skills / Honor).
  ShutTab(CharacterFrameTab5)
  HookShowSubFrame()
  HookToggleCharacter()
  if InspectHonorFrame or InspectFrameTab2 then HookInspect() end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" then
    if arg1 == "Blizzard_InspectUI" then
      HookInspect()
    end
    return
  end
  Apply()
end)
