--[[--------------------------------------------------------------------------
Solo -- single-player defaults for this realm (WoW 1.12.1, Lua 5.0).

The realm is one player and their bots, so:

  * chat is a message log: system, loot, experience and what NPCs
    say stay; say, yell, whispers, party/guild talk and channels go. (The
    server refuses every channel join anyway: Channel.Disable.)
  * pfUI skips its first-run wizard and starts from a chosen style
    (default Adapta; Options → Graphics / /style) plus solo constraints
    (command strip, compact message log, HUD seats) every login.

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

-- Solo product constraints, written every login (and after a style switch).
-- Fonts, unit frames, bar textures, chat size and panel chrome follow the
-- chosen pfUI style (PfuiStyle.lua); these keys stay put.
local PFUI_INVARIANT = {
  -- World map: show zones not visited yet and the exploration points.
  { { "appearance", "worldmap", "mapreveal" }, "1" },
  { { "appearance", "worldmap", "mapexploration" }, "1" },
  -- Minimap: bigger, with the zone name and coordinates always on.
  -- Size 170 matches MicroBar's strip width under the minimap.
  { { "appearance", "minimap", "size" }, "170" },
  { { "appearance", "minimap", "zonetext" }, "on" },
  { { "appearance", "minimap", "coordstext" }, "on" },
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
  -- Seven solo buttons (travel → gear → pets → tools → party → farm → dungeon).
  -- MicroBar.lua redraws them as action-bar squares and packs the row.
  { { "abuttons", "rowsize" }, "7" },
  -- pfUI chat boxes stay off; MessageLog.lua draws the compact solo panel.
  { { "chat", "right", "enable" }, "0" },
  -- pfUI info bars unused (MessageLog owns bags / time / gold). All-none hides them.
  { { "panel", "left", "left" }, "none" },
  { { "panel", "left", "center" }, "none" },
  { { "panel", "left", "right" }, "none" },
  { { "panel", "right", "left" }, "none" },
  { { "panel", "right", "center" }, "none" },
  { { "panel", "right", "right" }, "none" },
  -- A travel journal: pfUI takes a screenshot on level up and on epic loot,
  -- without the interface and with the zone and time written on it.
  { { "screenshot", "levelup" }, "1" },
  { { "screenshot", "loot" }, "4" },
  { { "screenshot", "caption" }, "1" },
  { { "screenshot", "hideui" }, "1" },
  -- An item's tooltip (loot, vendors) always shows the
  -- equipped item beside it, without holding Shift.
  { { "tooltip", "compare", "showalways" }, "1" },
  -- No guild rank / note block on unit tooltips (home guild is always there).
  { { "tooltip", "extguild" }, "0" },
  -- Grey items sell themselves at a vendor.
  { { "global", "autosell" }, "1" },
  -- Vertical Actionbar (MultiBarLeft / bar4) off; main + bottom bars cover solo.
  { { "bars", "bar4", "enable" }, "0" },
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
  -- xpos/ypos/scale must be numbers: LoadMovable does SetPoint(anchor, x, y),
  -- and a string "610" is read as a region name. SavedVariables rewrite them
  -- as strings on logout; CoercePositions turns them back each login.
  { { "position", "pfPlayer", "anchor" }, "TOPLEFT" },
  { { "position", "pfPlayer", "xpos" }, 490 },
  { { "position", "pfPlayer", "ypos" }, -650 },
  { { "position", "pfPlayer", "parent" }, "UIParent" },
  { { "position", "pfTarget", "anchor" }, "TOPLEFT" },
  { { "position", "pfTarget", "xpos" }, 832 },
  { { "position", "pfTarget", "ypos" }, -650 },
  { { "position", "pfTarget", "parent" }, "UIParent" },
  { { "position", "pfPet", "anchor" }, "TOPLEFT" },
  { { "position", "pfPet", "xpos" }, 712 },
  { { "position", "pfPet", "ypos" }, -650 },
  { { "position", "pfPet", "parent" }, "UIParent" },
  { { "position", "pfTargetTarget", "anchor" }, "TOPLEFT" },
  { { "position", "pfTargetTarget", "xpos" }, 712 },
  { { "position", "pfTargetTarget", "ypos" }, -680 },
  { { "position", "pfTargetTarget", "parent" }, "UIParent" },
  { { "position", "pfChatInputBox", "anchor" }, "TOPLEFT" },
  { { "position", "pfChatInputBox", "xpos" }, 610 },
  { { "position", "pfChatInputBox", "ypos" }, -620 },
  { { "position", "pfChatInputBox", "parent" }, "UIParent" },
  { { "position", "pfTotems", "anchor" }, "TOPLEFT" },
  { { "position", "pfTotems", "xpos" }, 700 },
  { { "position", "pfTotems", "ypos" }, -700 },
  { { "position", "pfTotems", "parent" }, "UIParent" },
  { { "position", "pfActionBarVertical", "anchor" }, "TOPLEFT" },
  { { "position", "pfActionBarVertical", "xpos" }, 610 },
  { { "position", "pfActionBarVertical", "ypos" }, -740 },
  { { "position", "pfActionBarVertical", "parent" }, "UIParent" },
  { { "position", "pfActionBarPet", "anchor" }, "TOPLEFT" },
  { { "position", "pfActionBarPet", "xpos" }, 660 },
  { { "position", "pfActionBarPet", "ypos" }, -770 },
  { { "position", "pfActionBarPet", "parent" }, "UIParent" },
  { { "position", "pfDurability", "anchor" }, "TOPLEFT" },
  { { "position", "pfDurability", "xpos" }, 1260 },
  { { "position", "pfDurability", "ypos" }, -180 },
  { { "position", "pfDurability", "parent" }, "UIParent" },
  { { "position", "WorldMapFrame", "anchor" }, "TOPLEFT" },
  { { "position", "WorldMapFrame", "xpos" }, 310 },
  { { "position", "WorldMapFrame", "ypos" }, -70 },
  { { "position", "WorldMapFrame", "scale" }, 0.7 },
}

-- The steps of pfUI's first-run wizard. Style switching replaces the profile
-- step; the chat steps would set up channels this realm does not have.
local PFUI_WIZARD = { "init", "profile", "cvars", "chat_right", "chat_position", "chat_channels", "finalize" }

local DEFAULT_STYLE = "Adapta"

-- pfUI's SavedVariables dump every value as a string. LoadMovable then does
-- SetPoint(anchor, xpos, ypos); a string offset is treated as a region name.
local function CoercePositions()
  local pos = pfUI_config and pfUI_config.position
  if type(pos) ~= "table" then return end
  for _, cfg in pairs(pos) do
    if type(cfg) == "table" then
      if cfg.xpos ~= nil then cfg.xpos = tonumber(cfg.xpos) or cfg.xpos end
      if cfg.ypos ~= nil then cfg.ypos = tonumber(cfg.ypos) or cfg.ypos end
      if cfg.scale ~= nil then cfg.scale = tonumber(cfg.scale) or cfg.scale end
    end
  end
end

function Solo_PreferredPfuiStyle()
  if type(Solo_State) == "table" and type(Solo_State.uiStyle) == "string" and Solo_State.uiStyle ~= "" then
    return Solo_State.uiStyle
  end
  if type(GetCVar) == "function" then
    local c = GetCVar("solorothUiStyle")
    if c and c ~= "" then return c end
  end
  return DEFAULT_STYLE
end

-- Overlay solo constraints onto the current pfUI_config. Used every login and
-- after PfuiStyle copies a new profile.
function Solo_ApplyPfUIInvariant()
  if type(pfUI_config) ~= "table" then pfUI_config = {} end
  if type(pfUI_init) ~= "table" then pfUI_init = {} end
  for i = 1, table.getn(PFUI_WIZARD) do
    pfUI_init[PFUI_WIZARD[i]] = true
  end
  for i = 1, table.getn(PFUI_INVARIANT) do
    Set(pfUI_config, PFUI_INVARIANT[i][1], PFUI_INVARIANT[i][2])
  end
  CoercePositions()
end

local function PreparePfUI()
  if type(Solo_RegisterPfuiCommunityProfiles) == "function" then
    Solo_RegisterPfuiCommunityProfiles()
  end
  if type(pfUI_config) ~= "table" then pfUI_config = {} end
  if type(pfUI_init) ~= "table" then pfUI_init = {} end

  if IsEmpty(pfUI_config) and type(pfUI_profiles) == "table" then
    local style = Solo_PreferredPfuiStyle()
    local src = pfUI_profiles[style] or pfUI_profiles[DEFAULT_STYLE]
    if not src and style ~= DEFAULT_STYLE then
      style = DEFAULT_STYLE
      src = pfUI_profiles[DEFAULT_STYLE]
    end
    if src then
      pfUI_config = Copy(src)
      if type(Solo_State) ~= "table" then Solo_State = {} end
      Solo_State.uiStyle = style
      if type(SetCVar) == "function" then SetCVar("solorothUiStyle", style) end
    end
  end
  Solo_ApplyPfUIInvariant()
end

-- -------------------------------------------------------------------- chat --
-- Message groups only: layout lives in MessageLog.lua. System, loot, skills,
-- NPC speech, combat, money, experience and reputation share ChatFrame1.

local CHATTER = {
  "SAY", "YELL", "EMOTE", "WHISPER", "PARTY", "RAID", "RAID_LEADER", "RAID_WARNING",
  "GUILD", "OFFICER", "AFK", "DND", "IGNORED", "CHANNEL",
  "BATTLEGROUND", "BATTLEGROUND_LEADER",
}

local LOG_GROUPS = {
  "SYSTEM", "SKILL", "LOOT",
  "CREATURE", "MONSTER_SAY", "MONSTER_EMOTE", "MONSTER_YELL", "MONSTER_WHISPER",
  "MONSTER_BOSS_EMOTE", "MONSTER_BOSS_WHISPER",
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
  if not ChatFrame1 then return end
  if ChatFrame_RemoveAllMessageGroups then
    ChatFrame_RemoveAllMessageGroups(ChatFrame1)
  end
  for i = 1, table.getn(LOG_GROUPS) do
    ChatFrame_AddMessageGroup(ChatFrame1, LOG_GROUPS[i])
  end
  if ChatFrame_ActivateCombatMessages then
    ChatFrame_ActivateCombatMessages(ChatFrame1)
  end
  QuietFrame(ChatFrame1)
  for i = 2, NUM_CHAT_WINDOWS or 7 do
    local frame = getglobal("ChatFrame" .. i)
    if frame and ChatFrame_RemoveAllMessageGroups then
      ChatFrame_RemoveAllMessageGroups(frame)
      QuietFrame(frame)
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

-- Loading-screen tip-of-the-day (GameTips.dbc) only appears on glue→world.
-- setup-classic.sh writes showGameTips=0 into config.toml; this once-shot
-- covers installs that never re-ran setup. Options → 界面 → 显示游戏提示
-- stays the player's afterwards.
local function HideGameTips()
  if type(Solo_State) ~= "table" then Solo_State = {} end
  if Solo_State.nogametips then return end
  Solo_State.nogametips = true
  SetCVar("showGameTips", "0")
end

-- ---------------------------------------------------- Atlas / AtlasLoot MM --
-- Map and loot are embedded in the Dungeon hub (/gd). Hide their own minimap
-- buttons so the strip stays Teleport / Items / GMBox / party / farm / Dungeon.

local function HideDungeonRefButtons()
  if type(AtlasOptions) == "table" then
    AtlasOptions.AtlasButtonShown = false
    if type(AtlasButton_Init) == "function" then AtlasButton_Init() end
  end
  -- Create the table early so FirstTime is set before AtlasLoot's
  -- VARIABLES_LOADED shows ATLASLOOT_SETUP on a brand-new character.
  if type(AtlasLootCharDB) ~= "table" then AtlasLootCharDB = {} end
  AtlasLootCharDB.MinimapButton = false
  AtlasLootCharDB.FirstTime = false
  if type(AtlasLootMinimapButton_Init) == "function" then
    AtlasLootMinimapButton_Init()
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
    -- pfUI assigns Light on this event; re-publish community styles afterwards.
    if type(Solo_RegisterPfuiCommunityProfiles) == "function" then
      Solo_RegisterPfuiCommunityProfiles()
    end
    EnableCombatText()
    HideGuildUnderNames()
    HideGameTips()
    HideDungeonRefButtons()
  elseif event == "PLAYER_ENTERING_WORLD" then
    AssignChatGroups()
    if type(Solo_InstallMessageLog) == "function" then Solo_InstallMessageLog() end
    if type(Solo_PlaceMessageLog) == "function" then Solo_PlaceMessageLog() end
    HideDungeonRefButtons()
  end
end)
