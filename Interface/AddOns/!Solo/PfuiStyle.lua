--[[--------------------------------------------------------------------------
pfUI interface style switcher for Soloroth.

A native row on Options → Graphics (next to Creature Models). Choosing a style
copies that pfUI_profiles table, re-applies Solo's invariant keys, and ReloadUI.
Official Modern / Nostalgia / Legacy / Slim / Adapta / Light plus community
tables from PfuiStylesData.lua ("Solo: …"). /style and /fengge do the same.
----------------------------------------------------------------------------]]

local CVAR = "solorothUiStyle"
local DEFAULT = "Modern"
local ROW_KEY = "RowSoloUiStyle"
local ROW_NAME = "BenillaOptionsFrameContainerBodyGraphics" .. ROW_KEY

-- Official builtins first; community ids match PfuiStylesData.lua.
local STYLES = {
  { id = "Modern",        en = "Modern",    zh = "现代" },
  { id = "Nostalgia",     en = "Nostalgia", zh = "怀旧" },
  { id = "Legacy",        en = "Legacy",    zh = "经典" },
  { id = "Slim",          en = "Slim",      zh = "纤细" },
  { id = "Adapta",        en = "Adapta",    zh = "Adapta" },
  { id = "Light",         en = "Light",     zh = "明亮" },
  { id = "Solo: Clean",   en = "Clean",     zh = "清爽" },
  { id = "Solo: Compact", en = "Compact",   zh = "紧凑" },
}

local ZH = (GetLocale and GetLocale() == "zhCN") and true or false
local function L(en, zh) if ZH and zh then return zh end return en end

RegisterCVar(CVAR, DEFAULT)

local function Copy(t)
  if type(t) ~= "table" then return t end
  if pfUI and pfUI.api and pfUI.api.CopyTable then return pfUI.api.CopyTable(t) end
  local out = {}
  for k, v in pairs(t) do out[k] = Copy(v) end
  return out
end

local function LabelOf(id)
  for i = 1, table.getn(STYLES) do
    if STYLES[i].id == id then return L(STYLES[i].en, STYLES[i].zh) end
  end
  return id
end

local function Known(id)
  for i = 1, table.getn(STYLES) do
    if STYLES[i].id == id then return true end
  end
  return false
end

local function Current()
  if type(Solo_PreferredPfuiStyle) == "function" then
    local s = Solo_PreferredPfuiStyle()
    if s and s ~= "" then return s end
  end
  local v = GetCVar(CVAR)
  if v and v ~= "" then return v end
  return DEFAULT
end

function Solo_RegisterPfuiCommunityProfiles()
  if type(pfUI_profiles) ~= "table" then return end
  if type(Solo_PfuiCommunityStyles) ~= "table" then return end
  for i = 1, table.getn(Solo_PfuiCommunityStyles) do
    local s = Solo_PfuiCommunityStyles[i]
    if type(s) == "table" and type(s.id) == "string" and type(s.config) == "table" then
      pfUI_profiles[s.id] = Copy(s.config)
    end
  end
end

-- Copy profile → remember choice → Solo invariant → fill gaps → ReloadUI.
function Solo_ApplyPfuiStyle(id, do_reload)
  if not id or id == "" then id = DEFAULT end
  if type(pfUI_profiles) ~= "table" then
    DEFAULT_CHAT_FRAME:AddMessage("|cff44ddffSolo|r: pfUI " .. L("not loaded", "尚未加载"))
    return
  end
  Solo_RegisterPfuiCommunityProfiles()
  local src = pfUI_profiles[id]
  if type(src) ~= "table" then
    DEFAULT_CHAT_FRAME:AddMessage("|cff44ddffSolo|r: " .. L("unknown style", "未知风格") .. " " .. id)
    return
  end

  pfUI_config = Copy(src)
  if type(Solo_State) ~= "table" then Solo_State = {} end
  Solo_State.uiStyle = id
  SetCVar(CVAR, id)
  if type(pfUI_config.global) ~= "table" then pfUI_config.global = {} end
  pfUI_config.global.profile = id

  if type(Solo_ApplyPfUIInvariant) == "function" then
    Solo_ApplyPfUIInvariant()
  end
  if pfUI and type(pfUI.LoadConfig) == "function" then
    pfUI:LoadConfig()
  end

  if do_reload == false then return end
  DEFAULT_CHAT_FRAME:AddMessage("|cff44ddffSolo|r: " .. L(
    "interface style → " .. LabelOf(id) .. ". Reloading…",
    "界面风格已选「" .. LabelOf(id) .. "」，正在重新加载…"
  ))
  ReloadUI()
end

SOLOROTH_TOOLTIP_UISTYLE = L(
  "Swaps pfUI fonts, unit frames, action bars and chrome.\n\n"
    .. "Takes effect after a UI reload. Command strip, dual chat and Solo HUD "
    .. "seats stay. Fine-tune further with ESC → Interface (/pfui).",
  "切换 pfUI 的字体、单位框、动作条和边框等外观。\n\n"
    .. "重新加载界面后生效。命令条、左右双聊天和 Solo 的座位不动。"
    .. "细节仍可在 ESC →「界面」(/pfui) 里调。"
)

local function Build()
  local graphics = BenillaOptionsFrameContainerBodyGraphics
  if getglobal(ROW_NAME) or not graphics or not BENILLA_OPTIONS_PAGE_ROWS then return end

  local row = CreateFrame("Frame", ROW_NAME, graphics, "BenillaOptionsDropdownRowTemplate")
  BenillaOptionsRow_OnLoad(row, CVAR, L("Interface Style", "界面风格"), "SOLOROTH_TOOLTIP_UISTYLE")
  local entries = {}
  for i = 1, table.getn(STYLES) do
    entries[i] = { text = L(STYLES[i].en, STYLES[i].zh), value = STYLES[i].id }
  end
  BenillaOptionsDropdownRow_Setup(row, entries)

  row.afterSet = function()
    local id = GetCVar(CVAR) or DEFAULT
    if not Known(id) then id = DEFAULT end
    -- Dropdown already wrote the CVar; Apply copies the profile and reloads.
    Solo_ApplyPfuiStyle(id, true)
  end

  table.insert(BENILLA_OPTIONS_PAGE_ROWS.Graphics, ROW_KEY)
  BenillaOptionsPage_Layout("Graphics")
  -- Show the remembered style even if CVar was never set this session.
  SetCVar(CVAR, Current())
  BenillaOptionsDropdown_ShowValue(row)
end

Build()

SLASH_SOLOUISTYLE1 = "/style"
SLASH_SOLOUISTYLE2 = "/fengge"
SlashCmdList["SOLOUISTYLE"] = function(msg)
  msg = string.gsub(msg or "", "^%s*(.-)%s*$", "%1")
  local cur = Current()
  if msg == "" or msg == "list" then
    DEFAULT_CHAT_FRAME:AddMessage("|cff44ddffSolo|r: " .. L("interface styles:", "界面风格："))
    for i = 1, table.getn(STYLES) do
      local p = STYLES[i]
      local mark = (p.id == cur) and " *" or ""
      DEFAULT_CHAT_FRAME:AddMessage("  " .. p.id .. " — " .. L(p.en, p.zh) .. mark)
    end
    DEFAULT_CHAT_FRAME:AddMessage(L(
      "Usage: /style <id>, or Options → Graphics",
      "用法：/style <id>，或 选项 → 图形"
    ))
    return
  end
  -- Allow short labels: clean, compact, modern, …
  local id = msg
  if not Known(id) then
    local lower = string.lower(msg)
    for i = 1, table.getn(STYLES) do
      local p = STYLES[i]
      if string.lower(p.id) == lower
          or string.lower(p.en) == lower
          or (p.zh and p.zh == msg)
          or string.lower(string.gsub(p.id, "^Solo: ", "")) == lower then
        id = p.id
        break
      end
    end
  end
  if not Known(id) and not (pfUI_profiles and pfUI_profiles[id]) then
    DEFAULT_CHAT_FRAME:AddMessage("|cff44ddffSolo|r: " .. L("unknown style", "未知风格") .. " " .. msg)
    return
  end
  Solo_ApplyPfuiStyle(id, true)
end
