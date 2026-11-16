--[[--------------------------------------------------------------------------
Solo -- single-player defaults for this realm (WoW 1.12.1, Lua 5.0).

The realm is one player and their bots, so:

  * chat is a message log: system, loot, experience and what NPCs
    say stay; say, yell, whispers, party/guild talk and channels go. (The
    server refuses every channel join anyway: Channel.Disable.)
  * pfUI skips its first-run wizard and starts from settings made for
    travelling alone, on every character, every login.

The folder starts with "!" so it loads before every other addon: its
ADDON_LOADED handler then runs before pfUI's own, at the moment pfUI's
per-character saved variables are loaded but not read yet.
----------------------------------------------------------------------------]]

-- ---------------------------------------------------------------- helpers --

local function Copy(t)
  if type(t) ~= "table" then return t end
  local out = {}
  for k, v in pairs(t) do out[k] = Copy(v) end
  return out
end

-- path = { "a", "b", "c" } sets t.a.b.c = value, creating tables on the way.
local function Set(t, path, value)
  local node = t
  for i = 1, table.getn(path) - 1 do
    local key = path[i]
    if type(node[key]) ~= "table" then node[key] = {} end
    node = node[key]
  end
  node[path[table.getn(path)]] = value
end

local function IsEmpty(t)
  return type(t) ~= "table" or next(t) == nil
end

-- -------------------------------------------------------------------- pfUI --

-- Set on every login, over whatever the character had.
local PFUI = {
  -- World map: show zones not visited yet and the exploration points.
  { { "appearance", "worldmap", "mapreveal" }, "1" },
  { { "appearance", "worldmap", "mapexploration" }, "1" },
  -- Minimap: bigger, with the zone name and coordinates always on.
  { { "appearance", "minimap", "size" }, "170" },
  { { "appearance", "minimap", "zonetext" }, "on" },
  { { "appearance", "minimap", "coordstext" }, "on" },
  { { "appearance", "border", "shadow" }, "1" },
  -- pfUI kills the stock MainMenuBar; without this the character / spellbook /
  -- talent / social micro buttons have nowhere to sit.
  { { "panel", "micro", "enable" }, "1" },
  -- Addon minimap buttons (GMBox, party, farm, Atlas, …) sit in one strip under that
  -- micro bar (MicroBar.lua docks the strip). Always shown, not combat-hidden.
  { { "abuttons", "enable" }, "1" },
  { { "abuttons", "position" }, "bottom" },
  { { "abuttons", "showdefault" }, "1" },
  { { "abuttons", "hideincombat" }, "0" },
  -- GMBox, party, farm, Atlas, AtlasLoot. MicroBar.lua then matches the
  -- column count to however many icons are actually showing.
  { { "abuttons", "rowsize" }, "5" },
  -- Info panels: no guild or friends to count.
  { { "panel", "left", "left" }, "exp" },
  { { "panel", "left", "right" }, "bagspace" },
  -- The right info bar is the length of the current or last fight, beside
  -- the time and gold. It sits in the bottom of the combat log (below).
  { { "panel", "right", "left" }, "combat" },
  -- Those bars take their width from the chat frames. Exp, armor, bags, the
  -- fight timer, the clock and gold are short; 380 leaves them mostly empty.
  -- The two chats are the same size: the message log on the left, the
  -- combat log on the right.
  { { "chat", "left", "width" }, "280" },
  { { "chat", "right", "width" }, "280" },
  { { "chat", "left", "height" }, "180" },
  { { "chat", "right", "height" }, "180" },
  -- The experience bar beside the chat stays visible, not only after a kill.
  { { "panel", "xp", "xp_always" }, "1" },
  -- Right chat on, so the combat log has the same frame as the message log.
  -- pfUI would put ChatFrame3 there; PlaceCombatLog swaps in ChatFrame2.
  { { "chat", "right", "enable" }, "1" },
  -- A travel journal: pfUI takes a screenshot on level up and on epic loot,
  -- without the interface and with the zone and time written on it.
  { { "screenshot", "levelup" }, "1" },
  { { "screenshot", "loot" }, "4" },
  { { "screenshot", "caption" }, "1" },
  { { "screenshot", "hideui" }, "1" },
  -- An item's tooltip (loot, vendors) always shows the
  -- equipped item beside it, without holding Shift.
  { { "tooltip", "compare", "showalways" }, "1" },
  -- Grey items sell themselves at a vendor.
  { { "global", "autosell" }, "1" },
  -- Modules with nothing to do alone, or that only serve other players.
  { { "disabled", "raid" }, "1" },                -- a five-player party at most
  { { "disabled", "targettargettarget" }, "1" },
  { { "disabled", "updatenotify" }, "1" },        -- asks other players' clients
  { { "disabled", "whisperproxy" }, "1" },        -- forwards whispers
  { { "disabled", "socialmod" }, "1" },           -- friends and guild list tweaks
  { { "disabled", "chatcopy" }, "1" },            -- copy chat lines
  -- Bagshui is the bag addon; pfUI's own bags would open a second bank
  -- window (Bagshui asks for this on every login otherwise).
  { { "disabled", "bags" }, "1" },
}

-- The steps of pfUI's first-run wizard. Its profile step would copy the
-- Modern profile, which is what a new character gets here; the chat steps
-- would set up channels this realm does not have.
local PFUI_WIZARD = { "init", "profile", "cvars", "chat_right", "chat_position", "chat_channels", "finalize" }

local function PreparePfUI()
  if type(pfUI_config) ~= "table" then pfUI_config = {} end
  if type(pfUI_init) ~= "table" then pfUI_init = {} end

  if IsEmpty(pfUI_config) and pfUI_profiles and pfUI_profiles["Modern"] then
    pfUI_config = Copy(pfUI_profiles["Modern"])
  end
  for i = 1, table.getn(PFUI_WIZARD) do
    pfUI_init[PFUI_WIZARD[i]] = true
  end
  for i = 1, table.getn(PFUI) do
    Set(pfUI_config, PFUI[i][1], PFUI[i][2])
  end
end

-- -------------------------------------------------------------------- chat --

-- Message groups the chat windows stop showing: other people talking.
-- What stays: system and error messages, loot, money, experience,
-- reputation, skills, NPC speech, combat log.
local CHATTER = {
  "SAY", "YELL", "EMOTE", "WHISPER", "PARTY", "RAID", "RAID_LEADER", "RAID_WARNING",
  "GUILD", "OFFICER", "AFK", "DND", "IGNORED", "CHANNEL",
}

local function QuietChat()
  for i = 1, NUM_CHAT_WINDOWS or 7 do
    local frame = getglobal("ChatFrame" .. i)
    if frame then
      for k = 1, table.getn(CHATTER) do
        ChatFrame_RemoveMessageGroup(frame, CHATTER[k])
      end
    end
  end
end

-- ------------------------------------------------------------- combat log --
-- ChatFrame2 is the combat log (战斗记录). Stock UI docks it as a tab of
-- ChatFrame1 (综合, bottom left). It belongs on the bottom right, in the
-- frame pfUI already mirrors there. pfUI's own refresh puts ChatFrame3 in
-- that frame and re-parents an undocked window to UIParent, so this runs
-- again after every refresh. `guard` stops the undock's own save from
-- re-entering while the points are still being set.

local combatGuard, combatSeparated = 0, nil

local function HideChatTextures(id)
  if not CHAT_FRAME_TEXTURES then return end
  for _, tex in pairs(CHAT_FRAME_TEXTURES) do
    local texture = getglobal("ChatFrame" .. id .. tex)
    if texture then
      texture:SetTexture()
      texture:Hide()
    end
  end
end

local function PlaceCombatLog()
  if combatGuard > 0 then return end
  if not (pfUI and pfUI.chat and pfUI.chat.right and ChatFrame1 and ChatFrame2) then return end
  combatGuard = 1

  local right = pfUI.chat.right
  local frame = ChatFrame2
  local tab = ChatFrame2Tab
  if frame.isDocked and FCF_UnDockFrame then
    FCF_UnDockFrame(frame)
  end
  if not combatSeparated then
    combatSeparated = true
    if FCF_SelectDockFrame then FCF_SelectDockFrame(ChatFrame1) end
    if SetChatWindowShown then SetChatWindowShown(frame:GetID(), 1) end
    if FCF_SetLocked then FCF_SetLocked(frame, 1) end
  end

  right:Show()
  if ChatFrame3 then
    ChatFrame3:Hide()
    if ChatFrame3Tab then ChatFrame3Tab:Hide() end
  end

  if tab and right.panelTop then
    tab:SetParent(right.panelTop)
    tab:ClearAllPoints()
    local src = ChatFrame1Tab
    local leftTop = pfUI.chat.left and pfUI.chat.left.panelTop
    local point, rel, relPoint, x, y
    if src and src:GetNumPoints() > 0 then
      point, rel, relPoint, x, y = src:GetPoint(1)
    end
    if point and (rel == leftTop or rel == pfUI.chat.left) then
      tab:SetPoint(point, rel == leftTop and right.panelTop or right, relPoint, x or 0, y or 0)
    else
      tab:SetPoint("LEFT", right.panelTop, "LEFT", 4, 0)
    end
    tab:Show()
  end

  frame:SetParent(right)
  frame:ClearAllPoints()
  -- Match 综合's insets inside its frame. GetPoint's relative frame is not
  -- the chat frame here, so the edges are copied instead: the combat log
  -- then clears the info bar by the same amount the message log does.
  local left = pfUI.chat.left
  local sl, sb = ChatFrame1:GetLeft(), ChatFrame1:GetBottom()
  local sr, st = ChatFrame1:GetRight(), ChatFrame1:GetTop()
  local ol = left and left:GetLeft()
  local ob = left and left:GetBottom()
  local ox = left and left:GetRight()
  local ot = left and left:GetTop()
  if sl and ol and sb and ob and sr and ox and st and ot then
    frame:SetPoint("TOPLEFT", right, "TOPLEFT", sl - ol, st - ot)
    frame:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", sr - ox, sb - ob)
  else
    frame:SetPoint("TOPLEFT", right, "TOPLEFT", 3, -24)
    frame:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", -3, 96)
  end
  HideChatTextures(frame:GetID())
  frame:Show()
  combatGuard = 0
end

local combatHooked
local function InstallCombatLog()
  if combatHooked or not (pfUI and pfUI.chat and pfUI.chat.RefreshChat) then return end
  combatHooked = true
  local refresh = pfUI.chat.RefreshChat
  pfUI.chat.RefreshChat = function()
    refresh()
    PlaceCombatLog()
  end
  if FCF_SaveDock then
    local save = FCF_SaveDock
    FCF_SaveDock = function()
      save()
      PlaceCombatLog()
    end
  end
  if FloatingChatFrame_Update then
    local update = FloatingChatFrame_Update
    FloatingChatFrame_Update = function(id, onUpdateEvent)
      update(id, onUpdateEvent)
      PlaceCombatLog()
    end
  end
end

-- ------------------------------------------------------------- combat text --

-- Floating combat text ships off. Turned on once per account, with dodges,
-- parries and misses; after that the options window's switch is the player's.
-- The saved interface variables have landed by VARIABLES_LOADED.
local function EnableCombatText()
  if type(Solo_State) ~= "table" then Solo_State = {} end
  if Solo_State.combattext then return end
  Solo_State.combattext = true
  SHOW_COMBAT_TEXT = "1"
  COMBAT_TEXT_SHOW_DODGE_PARRY_MISS = "1"
  if BenillaCombatText_UpdateOrLoad then
    BenillaCombatText_UpdateOrLoad()
  else
    UIParentLoadAddOn("Blizzard_CombatText")
    if CombatText_UpdateDisplayedMessages then CombatText_UpdateDisplayedMessages() end
  end
end

-- ----------------------------------------------------------- overhead names --

-- Every character gets a home guild ("<name>之家"), so the "<Guild>" line under
-- player names is noise. Off once per account; Options → 姓名板 → 玩家公会名称
-- stays the player's afterwards. (pfUI nameplates already default showguildname off.)
local function HideGuildUnderNames()
  if type(Solo_State) ~= "table" then Solo_State = {} end
  if Solo_State.noguildnames then return end
  Solo_State.noguildnames = true
  SetCVar("UnitNamePlayerGuild", "0")
end

-- ------------------------------------------------------------------ events --

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("VARIABLES_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" then
    if arg1 == "pfUI" then
      PreparePfUI()
    end
  elseif event == "VARIABLES_LOADED" then
    EnableCombatText()
    HideGuildUnderNames()
  elseif event == "PLAYER_ENTERING_WORLD" then
    QuietChat()
    InstallCombatLog()
    PlaceCombatLog()
  end
end)
