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

-- One-shot default key for an addon binding. Marks db[flag] so a player who
-- clears the bind is not given it again. Leaves the key alone when another
-- command holds it, except stock binds Solo has made no-ops (social, quest,
-- honor — H still opens the character frame, same as C after NoHonor).
local DISPLACEABLE = {
  TOGGLESOCIAL = true,
  TOGGLEQUESTLOG = true,
  TOGGLECHARACTER4 = true,
}

function Solo_EnsureDefaultKey(command, key, db, flag)
  if type(command) ~= "string" or type(key) ~= "string" then return end
  if type(db) ~= "table" then return end
  flag = flag or "defaultKey"
  if db[flag] then return end
  db[flag] = true
  if type(GetBindingKey) ~= "function" or type(SetBinding) ~= "function" then return end
  if GetBindingKey(command) then return end
  local taken = ""
  if type(GetBindingAction) == "function" then taken = GetBindingAction(key) or "" end
  if taken ~= "" and taken ~= command then
    if not DISPLACEABLE[taken] then return end
    SetBinding(key)
  end
  SetBinding(key, command)
  if type(SaveBindings) == "function" and type(GetCurrentBindingSet) == "function" then
    local which = GetCurrentBindingSet()
    if which == 1 or which == 2 then SaveBindings(which) end
  end
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
  -- talent / map / menu micro buttons have nowhere to sit. Social and Help
  -- are shut in NoSocial / NoHelp.
  { { "panel", "micro", "enable" }, "1" },
  -- Addon minimap buttons sit in one strip under that micro bar
  -- (MicroBar.lua docks them in order: Teleport, Items, GMBox, party, farm,
  -- Dungeon). Always shown, not combat-hidden. Atlas / AtlasLoot icons are
  -- hidden; open them from /gd.
  { { "abuttons", "enable" }, "1" },
  { { "abuttons", "position" }, "bottom" },
  { { "abuttons", "showdefault" }, "1" },
  { { "abuttons", "hideincombat" }, "0" },
  -- Six solo buttons. MicroBar.lua redraws them as action-bar squares and
  -- packs the row to however many are showing.
  { { "abuttons", "rowsize" }, "6" },
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
  -- Re-enable if an older !Solo left bags off for Bagshui.
  { { "disabled", "bags" }, "0" },
  -- HUD seats on a 10px grid (pfUI unlock grid ≈ screen/128), mutually
  -- aligned: player | pet | target on one row (20px gaps), ToT under pet,
  -- chat/vertical bar share a column, pet bar centred under the cluster.
  -- New / empty layouts pick these up via LoadMovable; a dragged frame
  -- keeps its layout-cache.txt row.
  { { "position", "pfPlayer", "anchor" }, "TOPLEFT" },
  { { "position", "pfPlayer", "xpos" }, "490" },
  { { "position", "pfPlayer", "ypos" }, "-650" },
  { { "position", "pfPlayer", "parent" }, "UIParent" },
  { { "position", "pfTarget", "anchor" }, "TOPLEFT" },
  { { "position", "pfTarget", "xpos" }, "832" },
  { { "position", "pfTarget", "ypos" }, "-650" },
  { { "position", "pfTarget", "parent" }, "UIParent" },
  { { "position", "pfPet", "anchor" }, "TOPLEFT" },
  { { "position", "pfPet", "xpos" }, "712" },
  { { "position", "pfPet", "ypos" }, "-650" },
  { { "position", "pfPet", "parent" }, "UIParent" },
  { { "position", "pfTargetTarget", "anchor" }, "TOPLEFT" },
  { { "position", "pfTargetTarget", "xpos" }, "712" },
  { { "position", "pfTargetTarget", "ypos" }, "-680" },
  { { "position", "pfTargetTarget", "parent" }, "UIParent" },
  { { "position", "pfChatInputBox", "anchor" }, "TOPLEFT" },
  { { "position", "pfChatInputBox", "xpos" }, "610" },
  { { "position", "pfChatInputBox", "ypos" }, "-620" },
  { { "position", "pfChatInputBox", "parent" }, "UIParent" },
  { { "position", "pfTotems", "anchor" }, "TOPLEFT" },
  { { "position", "pfTotems", "xpos" }, "700" },
  { { "position", "pfTotems", "ypos" }, "-700" },
  { { "position", "pfTotems", "parent" }, "UIParent" },
  { { "position", "pfActionBarVertical", "anchor" }, "TOPLEFT" },
  { { "position", "pfActionBarVertical", "xpos" }, "610" },
  { { "position", "pfActionBarVertical", "ypos" }, "-740" },
  { { "position", "pfActionBarVertical", "parent" }, "UIParent" },
  { { "position", "pfActionBarPet", "anchor" }, "TOPLEFT" },
  { { "position", "pfActionBarPet", "xpos" }, "660" },
  { { "position", "pfActionBarPet", "ypos" }, "-770" },
  { { "position", "pfActionBarPet", "parent" }, "UIParent" },
  { { "position", "pfDurability", "anchor" }, "TOPLEFT" },
  { { "position", "pfDurability", "xpos" }, "1260" },
  { { "position", "pfDurability", "ypos" }, "-180" },
  { { "position", "pfDurability", "parent" }, "UIParent" },
  { { "position", "WorldMapFrame", "anchor" }, "TOPLEFT" },
  { { "position", "WorldMapFrame", "xpos" }, "310" },
  { { "position", "WorldMapFrame", "ypos" }, "-70" },
  { { "position", "WorldMapFrame", "scale" }, "0.7" },
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
-- Two panels only: 综合 bottom left, 战斗记录 bottom right. pfUI's wizard
-- would open a third "拾取 & 聊天" window on the right; stock UI docks the
-- combat log as a tab of 综合. Characters that already have that third
-- window keep showing it until this rewrites the layout each login.

-- Message groups no window should show: other people talking.
local CHATTER = {
  "SAY", "YELL", "EMOTE", "WHISPER", "PARTY", "RAID", "RAID_LEADER", "RAID_WARNING",
  "GUILD", "OFFICER", "AFK", "DND", "IGNORED", "CHANNEL",
  "BATTLEGROUND", "BATTLEGROUND_LEADER",
}

-- 综合: system, loot, skills, NPC speech.
local LEFT_GROUPS = {
  "SYSTEM", "SKILL", "LOOT",
  "CREATURE", "MONSTER_SAY", "MONSTER_EMOTE", "MONSTER_YELL", "MONSTER_WHISPER",
  "MONSTER_BOSS_EMOTE", "MONSTER_BOSS_WHISPER",
}

-- 战斗记录: combat hits plus money, experience and reputation.
local RIGHT_EXTRA = {
  "MONEY", "COMBAT_XP_GAIN", "COMBAT_HONOR_GAIN", "COMBAT_FACTION_CHANGE",
}

local function QuietFrame(frame)
  if not frame then return end
  for k = 1, table.getn(CHATTER) do
    ChatFrame_RemoveMessageGroup(frame, CHATTER[k])
  end
  if ChatFrame_RemoveAllChannels then ChatFrame_RemoveAllChannels(frame) end
end

local function AssignChatGroups()
  if not (ChatFrame1 and ChatFrame2) then return end
  if ChatFrame_RemoveAllMessageGroups then
    ChatFrame_RemoveAllMessageGroups(ChatFrame1)
    ChatFrame_RemoveAllMessageGroups(ChatFrame2)
  end
  for i = 1, table.getn(LEFT_GROUPS) do
    ChatFrame_AddMessageGroup(ChatFrame1, LEFT_GROUPS[i])
  end
  if ChatFrame_ActivateCombatMessages then
    ChatFrame_ActivateCombatMessages(ChatFrame2)
  end
  for i = 1, table.getn(RIGHT_EXTRA) do
    ChatFrame_AddMessageGroup(ChatFrame2, RIGHT_EXTRA[i])
  end
  QuietFrame(ChatFrame1)
  QuietFrame(ChatFrame2)
  for i = 3, NUM_CHAT_WINDOWS or 7 do
    local frame = getglobal("ChatFrame" .. i)
    if frame and ChatFrame_RemoveAllMessageGroups then
      ChatFrame_RemoveAllMessageGroups(frame)
      QuietFrame(frame)
    end
  end
end

-- ------------------------------------------------------------- chat place --
-- ChatFrame1 stays in pfUI's left frame. ChatFrame2 fills the right frame.
-- ChatFrame3+ (拾取 & 聊天 and any extras) are closed. pfUI's own refresh
-- puts ChatFrame3 back on the right whenever right chat is on, and re-parents
-- an undocked window to UIParent, so this runs again after every refresh.
-- `guard` stops the undock's own save from re-entering while points move.

local chatGuard = 0

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

local function CloseExtraChats()
  for i = 3, NUM_CHAT_WINDOWS or 7 do
    local frame = getglobal("ChatFrame" .. i)
    if frame then
      if frame.isDocked and FCF_UnDockFrame then FCF_UnDockFrame(frame) end
      if SetChatWindowShown then SetChatWindowShown(i, 0) end
      if FCF_Close then FCF_Close(frame) end
      frame:Hide()
      local tab = getglobal("ChatFrame" .. i .. "Tab")
      if tab then tab:Hide() end
    end
  end
end

local function PlaceChatIn(frame, tab, box, panelTop)
  if not (frame and box) then return end
  frame:SetParent(box)
  frame:ClearAllPoints()
  -- Match the insets ChatFrame1 ends up with inside the left box, so both
  -- panels clear their bottom info bars by the same amount. Fall back to
  -- pfUI's own padding when 综合 is not measured yet.
  local left = pfUI.chat.left
  local sl, sb = ChatFrame1:GetLeft(), ChatFrame1:GetBottom()
  local sr, st = ChatFrame1:GetRight(), ChatFrame1:GetTop()
  local ol = left and left:GetLeft()
  local ob = left and left:GetBottom()
  local ox = left and left:GetRight()
  local ot = left and left:GetTop()
  if frame ~= ChatFrame1 and sl and ol and sb and ob and sr and ox and st and ot then
    frame:SetPoint("TOPLEFT", box, "TOPLEFT", sl - ol, st - ot)
    frame:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", sr - ox, sb - ob)
  else
    frame:SetPoint("TOPLEFT", box, "TOPLEFT", 5, -25)
    frame:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -5, 25)
  end
  HideChatTextures(frame:GetID())
  frame:Show()
  -- SetUserPlaced needs a movable frame; FCF_SetLocked may already have
  -- cleared that, and a script error here would leave chatGuard stuck and
  -- the third (拾取) window still open.
  frame:SetMovable(true)
  frame:SetResizable(true)
  frame:SetUserPlaced(false)
  frame:SetMovable(false)
  frame:SetResizable(false)
  if tab and panelTop then
    tab:SetParent(panelTop)
    tab:ClearAllPoints()
    tab:SetPoint("LEFT", panelTop, "LEFT", 4, 0)
    tab:Show()
  end
end

local function PlaceSoloChats()
  if chatGuard > 0 then return end
  if not (pfUI and pfUI.chat and pfUI.chat.left and pfUI.chat.right
      and ChatFrame1 and ChatFrame2) then
    return
  end
  chatGuard = 1

  local left, right = pfUI.chat.left, pfUI.chat.right
  right:Show()
  -- Drop 拾取 first so a later error cannot leave three windows up.
  CloseExtraChats()

  -- 综合 belongs in the left dock. Characters that ran pfUI's position step
  -- have it undocked; RefreshChat then leaves it on UIParent.
  if not ChatFrame1.isDocked and FCF_DockFrame then
    FCF_DockFrame(ChatFrame1)
  end
  if FCF_SelectDockFrame then FCF_SelectDockFrame(ChatFrame1) end
  if SetChatWindowShown then SetChatWindowShown(1, 1) end
  if FCF_SetWindowName and GENERAL then FCF_SetWindowName(ChatFrame1, GENERAL) end
  -- Leave a correctly docked 综合 alone so pfUI's own padding (above the
  -- info bar) stays; only pull it back when RefreshChat parked it elsewhere.
  if ChatFrame1:GetParent() ~= left then
    PlaceChatIn(ChatFrame1, ChatFrame1Tab, left, left.panelTop)
  else
    ChatFrame1:Show()
    if ChatFrame1Tab then
      ChatFrame1Tab:SetParent(left.panelTop or left)
      ChatFrame1Tab:Show()
    end
  end
  if FCF_SetLocked then FCF_SetLocked(ChatFrame1, 1) end

  -- 战斗记录 leaves the left dock and fills the right frame alone.
  if ChatFrame2.isDocked and FCF_UnDockFrame then
    FCF_UnDockFrame(ChatFrame2)
  end
  if SetChatWindowShown then SetChatWindowShown(2, 1) end
  if FCF_SetWindowName and COMBAT_LOG then FCF_SetWindowName(ChatFrame2, COMBAT_LOG) end
  PlaceChatIn(ChatFrame2, ChatFrame2Tab, right, right.panelTop)
  if FCF_SetLocked then FCF_SetLocked(ChatFrame2, 1) end

  CloseExtraChats()
  chatGuard = 0
end

local chatHooked
local function InstallSoloChats()
  if chatHooked or not (pfUI and pfUI.chat and pfUI.chat.RefreshChat) then return end
  chatHooked = true
  local refresh = pfUI.chat.RefreshChat
  pfUI.chat.RefreshChat = function()
    refresh()
    PlaceSoloChats()
  end
  if FCF_SaveDock then
    local save = FCF_SaveDock
    FCF_SaveDock = function()
      save()
      PlaceSoloChats()
    end
  end
  if FloatingChatFrame_Update then
    local update = FloatingChatFrame_Update
    FloatingChatFrame_Update = function(id, onUpdateEvent)
      update(id, onUpdateEvent)
      PlaceSoloChats()
    end
  end
  -- The opening resize can put a saved screen position back after the hooks
  -- above have run. Recheck until both windows sit in their pfUI frames.
  local watch = CreateFrame("Frame")
  watch:SetScript("OnUpdate", function()
    this.t = (this.t or 0) + arg1
    if this.t < 0.5 then return end
    this.t = 0
    if not (ChatFrame1 and ChatFrame2 and pfUI and pfUI.chat
        and pfUI.chat.left and pfUI.chat.right) then
      return
    end
    local left, right = pfUI.chat.left, pfUI.chat.right
    local badLeft = ChatFrame1:GetParent() ~= left
    local fl, rl = ChatFrame2:GetLeft(), right:GetLeft()
    local badRight = ChatFrame2:GetParent() ~= right
        or not fl or not rl or math.abs(fl - rl) > 24
    local extra = ChatFrame3 and ChatFrame3:IsShown()
    if badLeft or badRight or extra then PlaceSoloChats() end
  end)
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

-- ---------------------------------------------------- Atlas / AtlasLoot MM --
-- Map and loot are embedded in the Dungeon hub (/gd). Hide their own minimap
-- buttons so the strip stays Teleport / Items / GMBox / party / farm / Dungeon.

local function HideDungeonRefButtons()
  if type(AtlasOptions) == "table" then
    AtlasOptions.AtlasButtonShown = false
    if type(AtlasButton_Init) == "function" then AtlasButton_Init() end
  end
  if type(AtlasLootCharDB) == "table" then
    AtlasLootCharDB.MinimapButton = false
    if type(AtlasLootMinimapButton_Init) == "function" then
      AtlasLootMinimapButton_Init()
    end
  end
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
    elseif arg1 == "Atlas" or arg1 == "AtlasLoot" then
      HideDungeonRefButtons()
    end
  elseif event == "VARIABLES_LOADED" then
    EnableCombatText()
    HideGuildUnderNames()
    HideDungeonRefButtons()
  elseif event == "PLAYER_ENTERING_WORLD" then
    AssignChatGroups()
    InstallSoloChats()
    PlaceSoloChats()
    HideDungeonRefButtons()
  end
end)
