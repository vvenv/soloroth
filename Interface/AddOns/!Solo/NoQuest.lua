--[[--------------------------------------------------------------------------
No quests. The server never offers one, so the stock quest log, its tracker
and the quest-accept window stay shut. The micro-bar button goes too.

pfUI builds that bar from its own MICRO_BUTTONS list, which still names the
quest button. Hide the button once pfUI has placed it; MicroBar.lua lays out
the ones that remain.
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

local function HideQuestButton()
  if QuestLogMicroButton then
    QuestLogMicroButton:Hide()
    QuestLogMicroButton:ClearAllPoints()
  end
  -- Stock UpdateTalentButton still gates the talent button on level 10.
  if UpdateTalentButton then UpdateTalentButton() end
end

local function Apply()
  Shut(QuestWatchFrame)
  Shut(QuestTimerFrame)
  Shut(QuestLogFrame)
  Shut(QuestFrame)
  HideQuestButton()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" and arg1 ~= "pfUI" then return end
  Apply()
end)
