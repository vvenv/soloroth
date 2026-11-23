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
  -- Size in whole grid cells (screen width / 128); 14 = 175px at 1600-wide.
  { { "appearance", "minimap", "size" }, "14" },
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
  -- No PvP flag on the player frame or minimap.
  { { "unitframes", "player", "showPVP" }, "0" },
  { { "unitframes", "player", "showPVPMinimap" }, "0" },
  -- Grey items sell themselves at a vendor.
  { { "global", "autosell" }, "1" },
  -- Vertical Actionbar (MultiBarLeft / bar4) off; main + bottom bars cover solo.
  { { "bars", "bar4", "enable" }, "0" },
  -- Re-enable if an older !Solo left bags off for Bagshui.
  { { "disabled", "bags" }, "0" },
  -- HUD seat *defaults* (grid cells). Applied only when that frame has no
  -- xpos yet — never overwrite a saved / loaded profile seat. xpos/ypos must
  -- be numbers: LoadMovable SetPoint + GridToPixel; SavedVariables stringify
  -- on logout; CoercePositions turns them back each login.
  { { "position", "pfPlayer", "anchor" }, "CENTER" },
  { { "position", "pfPlayer", "xpos" }, -16 },
  { { "position", "pfPlayer", "ypos" }, -15 },
  { { "position", "pfPlayer", "parent" }, "UIParent" },
  { { "position", "pfTarget", "anchor" }, "CENTER" },
  { { "position", "pfTarget", "xpos" }, 16 },
  { { "position", "pfTarget", "ypos" }, -15 },
  { { "position", "pfTarget", "parent" }, "UIParent" },
  { { "position", "pfPet", "anchor" }, "CENTER" },
  { { "position", "pfPet", "xpos" }, 0 },
  { { "position", "pfPet", "ypos" }, -14 },
  { { "position", "pfPet", "parent" }, "UIParent" },
  { { "position", "pfTargetTarget", "anchor" }, "CENTER" },
  { { "position", "pfTargetTarget", "xpos" }, 0 },
  { { "position", "pfTargetTarget", "ypos" }, -17 },
  { { "position", "pfTargetTarget", "parent" }, "UIParent" },
  -- pfChatInputBox is not a free seat. chat.lua docks its bottom edge to
  -- the top action bar; a saved CENTER/-12 xpos was winning over that dock.
  { { "position", "pfTotems", "anchor" }, "CENTER" },
  { { "position", "pfTotems", "xpos" }, 0 },
  { { "position", "pfTotems", "ypos" }, -19 },
  { { "position", "pfTotems", "parent" }, "UIParent" },
  { { "position", "pfActionBarVertical", "anchor" }, "CENTER" },
  { { "position", "pfActionBarVertical", "xpos" }, -16 },
  { { "position", "pfActionBarVertical", "ypos" }, -29 },
  { { "position", "pfActionBarVertical", "parent" }, "UIParent" },
  { { "position", "pfActionBarPet", "anchor" }, "CENTER" },
  { { "position", "pfActionBarPet", "xpos" }, 0 },
  { { "position", "pfActionBarPet", "ypos" }, -24 },
  { { "position", "pfActionBarPet", "parent" }, "UIParent" },
  -- ~101px from the left at 1600-wide → 8 cells.
  { { "position", "pfDurability", "anchor" }, "TOPLEFT" },
  { { "position", "pfDurability", "xpos" }, 8 },
  { { "position", "pfDurability", "ypos" }, -14 },
  { { "position", "pfDurability", "parent" }, "UIParent" },
  -- Compact message log: width/height come from MessageLog.lua (32×7 cells).
  { { "position", "pfSoloMessageLog", "anchor" }, "BOTTOMLEFT" },
  { { "position", "pfSoloMessageLog", "xpos" }, 0 },
  { { "position", "pfSoloMessageLog", "ypos" }, 0 },
  { { "position", "pfSoloMessageLog", "parent" }, "UIParent" },
  -- alpha is required: pfUI's map module SetAlphas it at PLAYER_ENTERING_WORLD
  -- and aborts the windowed skin (size, backdrop, BlackoutWorld:Hide) on nil.
  -- size ≈ 0.7 scale at typical map width (~1002px) / (1600/128); map-only zoom.
  { { "position", "WorldMapFrame", "anchor" }, "TOPLEFT" },
  { { "position", "WorldMapFrame", "xpos" }, 25 },
  { { "position", "WorldMapFrame", "ypos" }, -6 },
  { { "position", "WorldMapFrame", "size" }, 56 },
  { { "position", "WorldMapFrame", "alpha" }, 1 },
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
      if cfg.size ~= nil then cfg.size = tonumber(cfg.size) or cfg.size end
      if cfg.width ~= nil then cfg.width = tonumber(cfg.width) or cfg.width end
      if cfg.height ~= nil then cfg.height = tonumber(cfg.height) or cfg.height end
      if cfg.alpha ~= nil then cfg.alpha = tonumber(cfg.alpha) or cfg.alpha end
      -- Whole cells only for seats. Do not divide |n| > 64: the screen is
      -- 128 cells wide, so a corner anchor past the midline is a normal seat.
      -- Doing that divide on every reload (the step also changes when the
      -- window is resized) pulled those frames back to the default cluster.
      local x, y = tonumber(cfg.xpos), tonumber(cfg.ypos)
      if x then cfg.xpos = math.floor(x + 0.5) end
      if y then cfg.ypos = math.floor(y + 0.5) end
      local sz = tonumber(cfg.size)
      if sz then cfg.size = math.floor(sz + 0.5) end
    end
  end
  -- Unlock sizes with width/height cells + SetWidth; drop leftover scale/size
  -- (WorldMap keeps size for map zoom).
  for name, cfg in pairs(pos) do
    if type(cfg) == "table" and name ~= "WorldMapFrame" then
      cfg.size = nil
      cfg.scale = nil
    end
  end
end

-- One-shot: pixel layout → grid cells (screen width / 128). Authored profiles
-- and Solo seats are already in cells; this upgrades older SavedVariables.
local LAYOUT_LEAF = {
  width = true, height = true, pwidth = true, pheight = true,
  portraitwidth = true, portraitheight = true,
  combowidth = true, comboheight = true, druidmanaheight = true,
  xp_width = true, xp_height = true, rep_width = true, rep_height = true,
  input_width = true, heighthealth = true, heightcast = true,
}

local function GridStepNow()
  if pfUI and pfUI.api and pfUI.api.GridStep then return pfUI.api.GridStep() end
  local w = GetScreenWidth and GetScreenWidth()
  if not w or w <= 0 then return 12.5 end
  return w / 128
end

local function PxToCells(v)
  local n = tonumber(v)
  if not n or n == -1 or n == 0 then return v end
  local step = GridStepNow()
  if step <= 0 then return v end
  local cells = n / step
  -- keep two decimals
  cells = math.floor(cells * 100 + 0.5) / 100
  if type(v) == "string" then return tostring(cells) end
  return cells
end

-- Leave numbers that already fit on the 128-cell screen. Only convert a
-- value that is wider than the screen (pixels) or the old pixel*128 blow-up.
local function MaybePxToCells(v)
  local n = tonumber(v)
  if not n or n == -1 or math.abs(n) <= 128 then return v end
  if math.abs(n) > 256 then
    n = n / 128
    v = type(v) == "string" and tostring(n) or n
    if math.abs(n) <= 128 then return v end
  end
  return PxToCells(v)
end

local function MigrateLayoutNode(node, path_tail)
  if type(node) ~= "table" then return end
  for k, v in pairs(node) do
    if type(v) == "table" then
      MigrateLayoutNode(v, k)
    elseif LAYOUT_LEAF[k] then
      node[k] = MaybePxToCells(v)
    elseif k == "size" and path_tail == "minimap" then
      node[k] = MaybePxToCells(v)
    end
  end
end

-- A cell count cannot be wider than the screen (128). Larger numbers are
-- still pixels, or the old "pixel * 128" blow-up. A corner seat at cell 80
-- is not one of those.
local function LayoutLooksLikePixels()
  local uf = pfUI_config.unitframes and pfUI_config.unitframes.player
  local w = uf and tonumber(uf.width)
  if w and w > 128 then return true end
  local chat = pfUI_config.chat
  if chat then
    local left = chat.left and tonumber(chat.left.width)
    if left and left > 128 then return true end
    local right = chat.right and tonumber(chat.right.width)
    if right and right > 128 then return true end
  end
  local xp = pfUI_config.panel and pfUI_config.panel.xp
  if xp then
    local xw = tonumber(xp.xp_width)
    if xw and xw > 128 then return true end
    local rw = tonumber(xp.rep_width)
    if rw and rw > 128 then return true end
  end
  local pos = pfUI_config.position and pfUI_config.position.pfPlayer
  local x = pos and tonumber(pos.xpos)
  if x and math.abs(x) > 256 then return true end
  return false
end

-- pfUI modules already SetWidth(ConfigSize(...)) before ADDON_LOADED. A
-- leftover pixel width (e.g. 280) becomes ~2× screen wide. After migration
-- + invariants, resize and hide the dual-chat chrome MessageLog replaces.
function Solo_SuppressPfUIChatFrames()
  if not pfUI then return end
  local C = pfUI_config
  local ConfigSize = pfUI.api and pfUI.api.ConfigSize
  local function size(frame, w, h)
    if not frame or not ConfigSize then return end
    if w ~= nil then frame:SetWidth(ConfigSize(w)) end
    if h ~= nil then frame:SetHeight(ConfigSize(h)) end
  end
  if pfUI.chat then
    if pfUI.chat.left and C.chat and C.chat.left then
      size(pfUI.chat.left, C.chat.left.width, C.chat.left.height)
      pfUI.chat.left:Hide()
    end
    if pfUI.chat.right and C.chat and C.chat.right then
      size(pfUI.chat.right, C.chat.right.width, C.chat.right.height)
      pfUI.chat.right:Hide()
    end
  end
  if pfUI.panel then
    -- Panels match chat width (panel.lua uses width - 4 when chat exists).
    if pfUI.panel.left and C.chat and C.chat.left and ConfigSize then
      pfUI.panel.left:SetWidth(ConfigSize(C.chat.left.width) - 4)
      pfUI.panel.left:Hide()
    elseif pfUI.panel.left then
      pfUI.panel.left:Hide()
    end
    if pfUI.panel.right and C.chat and C.chat.right and ConfigSize then
      pfUI.panel.right:SetWidth(ConfigSize(C.chat.right.width) - 4)
      pfUI.panel.right:Hide()
    elseif pfUI.panel.right then
      pfUI.panel.right:Hide()
    end
  end
end

local function MigrateGridLayout()
  if type(pfUI_config) ~= "table" then return end
  if type(pfUI_config.global) ~= "table" then pfUI_config.global = {} end
  local ver = tonumber(pfUI_config.global.grid_layout) or 0
  -- Already on cells. Do not convert again: the divisor is the current
  -- window width, so a resize + reload would rewrite a good layout.
  if ver >= 2 and not LayoutLooksLikePixels() then return end
  if ver >= 2 then
    -- Only the absurd leftovers (wider than the screen). Leave real seats.
  elseif ver >= 1 and not LayoutLooksLikePixels() then
    pfUI_config.global.grid_layout = "2"
    return
  end

  MigrateLayoutNode(pfUI_config, nil)

  local pos = pfUI_config.position
  if type(pos) == "table" then
    for _, cfg in pairs(pos) do
      if type(cfg) == "table" then
        if cfg.xpos ~= nil then cfg.xpos = MaybePxToCells(cfg.xpos) end
        if cfg.ypos ~= nil then cfg.ypos = MaybePxToCells(cfg.ypos) end
        -- leave legacy scale; LoadMovable promotes to size when the frame has a width
      end
    end
  end

  pfUI_config.global.grid_layout = "2"
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

-- True when this frame already has a saved unlock seat (profile or drag).
local function HasSeat(name)
  local pos = pfUI_config.position and pfUI_config.position[name]
  return type(pos) == "table" and pos.xpos ~= nil
end

-- Overlay solo constraints onto the current pfUI_config. Used every login and
-- after PfuiStyle copies a new profile.
-- Product keys (disabled modules, micro bar, …) always apply. HUD seats are
-- defaults only: if the frame already has xpos (user drag or loaded profile),
-- leave it alone — otherwise Save/Load profile is pointless.
function Solo_ApplyPfUIInvariant()
  if type(pfUI_config) ~= "table" then pfUI_config = {} end
  if type(pfUI_init) ~= "table" then pfUI_init = {} end
  for i = 1, table.getn(PFUI_WIZARD) do
    pfUI_init[PFUI_WIZARD[i]] = true
  end
  for i = 1, table.getn(PFUI_INVARIANT) do
    local path = PFUI_INVARIANT[i][1]
    local value = PFUI_INVARIANT[i][2]
    if path[1] == "position" then
      local name = path[2]
      local leaf = path[3]
      if HasSeat(name) then
        -- Keep user/profile seat; map module still needs alpha if missing.
        if name == "WorldMapFrame" and leaf == "alpha" then
          local pos = pfUI_config.position[name]
          if pos.alpha == nil then Set(pfUI_config, path, value) end
        end
      else
        Set(pfUI_config, path, value)
      end
    else
      Set(pfUI_config, path, value)
    end
  end
  if type(pfUI_config.global) ~= "table" then pfUI_config.global = {} end
  pfUI_config.global.grid_layout = "2"
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
      -- Fresh copy from cell-based profiles; skip pixel migration.
      if type(pfUI_config.global) ~= "table" then pfUI_config.global = {} end
      pfUI_config.global.grid_layout = "2"
    end
  end
  -- Upgrade older pixel SavedVariables before overlaying Solo seats.
  MigrateGridLayout()
  Solo_ApplyPfUIInvariant()
  -- Modules already built chat/panel from pre-migration widths; fix live frames.
  Solo_SuppressPfUIChatFrames()
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
