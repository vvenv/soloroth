--[[--------------------------------------------------------------------------
NoQuest -- when `.noquest on` is set for this character, hide every quest UI
the client still paints: pfQuest nodes and tracker, the stock quest watch,
and the quest-log hotkey's window is left alone (empty after the server
clears the log). Third-party sources are not edited; pfQuest_config is
rewritten from here and nodes are redrawn.

`allquestgivers` is the yellow "!" on the minimap and world map. Turning off
spawn points does not hide it: those pins carry their own texture, and the
minimap only drops untextured spawn dots when `showspawnmini` is "0".
----------------------------------------------------------------------------]]

local KEYS = {
  "showspawn", "showspawnmini", "showcluster", "showclustermini",
  "allquestgivers", "currentquestgivers", "trackingicons", "showtracker",
  "questlogbuttons", "arrow", "routestarter", "routeender",
}

local saved = nil   -- values before no-quest, so turning off restores them
local on = false

local function ApplyPfQuest(hide)
  if type(pfQuest_config) ~= "table" then return end
  if hide then
    if not saved then
      saved = {}
      for i = 1, table.getn(KEYS) do
        local k = KEYS[i]
        saved[k] = pfQuest_config[k]
      end
    end
    for i = 1, table.getn(KEYS) do
      pfQuest_config[KEYS[i]] = "0"
    end
  elseif saved then
    for i = 1, table.getn(KEYS) do
      local k = KEYS[i]
      if saved[k] ~= nil then pfQuest_config[k] = saved[k] end
    end
    saved = nil
  end
  if pfQuest and pfQuest.ResetAll then
    pfQuest:ResetAll()
  elseif pfMap and pfMap.UpdateNodes then
    pfMap:UpdateNodes()
  end
end

local function ApplyWatch(hide)
  if not QuestWatchFrame then return end
  if hide then
    QuestWatchFrame:Hide()
    -- Stop the stock frame from showing itself again on QUEST_LOG_UPDATE.
    if not QuestWatchFrame.soloNoQuestHooked then
      QuestWatchFrame.soloNoQuestHooked = true
      local orig = QuestWatchFrame.Show
      QuestWatchFrame.Show = function(self)
        if on then return end
        return orig(self)
      end
    end
  end
end

local function SetNoQuest(want)
  if on == want then return end
  on = want
  ApplyPfQuest(want)
  ApplyWatch(want)
end

-- The server answers `.noquest` / `.noquest quiet` with "[noquest] on=1 kill=2".
local function ParseLine(text)
  local _, _, flag = string.find(text, "^%[noquest%] on=(%d)")
  if not flag then return false end
  SetNoQuest(flag == "1")
  return true
end

local asked = false
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("CHAT_MSG_SYSTEM")
ev:SetScript("OnEvent", function()
  if event == "PLAYER_ENTERING_WORLD" then
    if asked then return end
    asked = true
    -- Ask once per login; GMBox may also ask when its tools tab opens.
    SendChatMessage(".noquest quiet", "SAY")
  elseif event == "CHAT_MSG_SYSTEM" then
    ParseLine(arg1 or "")
  end
end)

-- Other addons (GMBox) may want to know without parsing chat themselves.
Solo_NoQuest = Solo_NoQuest or {}
Solo_NoQuest.IsOn = function() return on end
Solo_NoQuest.ParseLine = ParseLine
