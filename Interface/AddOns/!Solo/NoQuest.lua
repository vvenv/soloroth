--[[--------------------------------------------------------------------------
No quests. The server never offers one, so the stock quest log, its tracker
and the quest-accept window stay shut. The micro-bar button goes too.

pfUI lays that bar out from its own MICRO_BUTTONS while it loads (a copy,
not the global). This file loads first, so the button is taken out of the
global list, then the bar is chained again once pfUI has placed it.
----------------------------------------------------------------------------]]

local function DropMicro(name)
  if type(MICRO_BUTTONS) ~= "table" then return end
  local keep, i, n = {}, 1, table.getn(MICRO_BUTTONS)
  for i = 1, n do
    if MICRO_BUTTONS[i] ~= name then
      table.insert(keep, MICRO_BUTTONS[i])
      MICRO_BUTTONS[i] = nil
    else
      MICRO_BUTTONS[i] = nil
    end
  end
  for i = 1, table.getn(keep) do
    MICRO_BUTTONS[i] = keep[i]
  end
  if table.setn then table.setn(MICRO_BUTTONS, table.getn(keep)) end
end

DropMicro("QuestLogMicroButton")

-- The keybind calls this global by name.
ToggleQuestLog = function() end

local function Shut(frame)
  if not frame or frame.soloQuestShut then return end
  frame.soloQuestShut = true
  frame:Hide()
  frame.Show = function() end
end

local MICRO = {
  "CharacterMicroButton", "SpellbookMicroButton", "TalentMicroButton",
  "SocialsMicroButton", "WorldMapMicroButton", "MainMenuMicroButton", "HelpMicroButton",
}

local function RelayoutMicro()
  if QuestLogMicroButton then
    QuestLogMicroButton:Hide()
    QuestLogMicroButton:ClearAllPoints()
  end
  local parent = pfUI and pfUI.panel and pfUI.panel.microbutton
  if not parent then return end
  local prev, i, button
  for i = 1, table.getn(MICRO) do
    button = getglobal(MICRO[i])
    if button then
      button:ClearAllPoints()
      if not prev then
        button:SetPoint("LEFT", parent, "LEFT", 1, 10)
      else
        button:SetPoint("TOPLEFT", prev, "TOPRIGHT", 1, 0)
      end
      prev = button
    end
  end
  -- pfUI sizes the bar for eight buttons. One less, a little shorter.
  parent:SetWidth(127)
end

local function Apply()
  Shut(QuestWatchFrame)
  Shut(QuestTimerFrame)
  Shut(QuestLogFrame)
  Shut(QuestFrame)
  RelayoutMicro()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" and arg1 ~= "pfUI" then return end
  Apply()
end)
