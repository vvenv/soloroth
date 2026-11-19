--[[--------------------------------------------------------------------------
No help. Solo has no ticket system behind the help window, so that window,
its micro-bar button and the ESC "Support" rung stay shut.

pfUI's MICRO_BUTTONS still names HelpMicroButton; drop it, then hide the
button once pfUI has placed the bar. MicroBar.lua lays out the ones that
remain. PfuiSkin.lua re-anchors the ESC menu after Support is gone.
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

DropMicro("HelpMicroButton")

-- The keybind, the micro button and the ESC Support rung call this.
ToggleHelpFrame = function() end

local function Shut(frame)
  if not frame or frame.soloHelpShut then return end
  frame.soloHelpShut = true
  frame:Hide()
  frame.Show = function() end
end

local function HideHelpButton()
  if HelpMicroButton then
    HelpMicroButton:Hide()
    HelpMicroButton:ClearAllPoints()
  end
  local support = BenillaGameMenuButtonSupport
  if support and not support.soloHelpShut then
    support.soloHelpShut = true
    support:Hide()
    support.Show = function() end
  end
end

local function Apply()
  Shut(HelpFrame)
  HideHelpButton()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" and arg1 ~= "pfUI" then return end
  Apply()
end)
