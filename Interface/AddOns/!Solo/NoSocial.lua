--[[--------------------------------------------------------------------------
No social. Solo has no friends, guild or who list to manage, so the social
window and its micro-bar button stay shut.

pfUI's MICRO_BUTTONS still names SocialsMicroButton; drop it, then hide the
button once pfUI has placed the bar. MicroBar.lua lays out the ones that
remain.
----------------------------------------------------------------------------]]

local function DropMicro(name)
  if type(MICRO_BUTTONS) ~= "table" then return end
  local keep, i, n = {}, 1, table.getn(MICRO_BUTTONS)
  for i = 1, n do
    if MICRO_BUTTONS[i] ~= name then
      table.insert(keep, MICRO_BUTTONS[i])
    end
    MICRO_BUTTONS[i] = nil
  end
  for i = 1, table.getn(keep) do
    MICRO_BUTTONS[i] = keep[i]
  end
  if table.setn then table.setn(MICRO_BUTTONS, table.getn(keep)) end
end

DropMicro("SocialsMicroButton")

-- The keybind and the micro button call this global by name.
ToggleFriendsFrame = function() end

local function Shut(frame)
  if not frame or frame.soloSocialShut then return end
  frame.soloSocialShut = true
  frame:Hide()
  frame.Show = function() end
end

local function HideSocialButton()
  if SocialsMicroButton then
    SocialsMicroButton:Hide()
    SocialsMicroButton:ClearAllPoints()
  end
end

local function Apply()
  Shut(FriendsFrame)
  HideSocialButton()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" and arg1 ~= "pfUI" then return end
  Apply()
end)
