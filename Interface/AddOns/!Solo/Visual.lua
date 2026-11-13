--[[--------------------------------------------------------------------------
Model / visual profile switcher for Soloroth.

A native row on Options → Graphics (BenillaOptionsDropdownRowTemplate, listed in
BENILLA_OPTIONS_PAGE_ROWS.Graphics), so the page's own layout, search, Defaults
and PfuiSkin's dropdown skin all apply. The choice is the solorothVisual CVar
in benilla-config/config.toml; play.sh / apply-visual.sh mount the matching
patch-?.MPQ overlays on the next launch, since the MPQ chain is fixed at boot.

apply-visual.sh also writes solorothVisualReady (profiles with an MPQ on disk)
and solorothVisualActive (what this launch mounted).
----------------------------------------------------------------------------]]

local CVAR = "solorothVisual"
local DEFAULT = "vanilla"
local ROW_KEY = "RowSoloVisual"
local ROW_NAME = "BenillaOptionsFrameContainerBodyGraphics" .. ROW_KEY

-- id = folder under ../wow-data/visual-patches/ (or "vanilla")
local PROFILES = {
  { id = "vanilla",            en = "Vanilla",                  zh = "原版" },
  { id = "reforged-creatures", en = "HD creatures (Reforged)",  zh = "高清怪物（Reforged）" },
  { id = "improved-models",    en = "Improved Models",          zh = "Improved Models" },
  { id = "hd",                 en = "HD pack (Reforged, all)",  zh = "高清合集（Reforged 全套）" },
}

local ZH = (GetLocale and GetLocale() == "zhCN") and true or false
local function L(en, zh) if ZH and zh then return zh end return en end

RegisterCVar(CVAR, DEFAULT)
RegisterCVar("solorothVisualReady", "")
RegisterCVar("solorothVisualActive", "")

local function Current()
  local v = GetCVar(CVAR)
  if not v or v == "" then return DEFAULT end
  return v
end

local function LabelOf(id)
  for i = 1, table.getn(PROFILES) do
    if PROFILES[i].id == id then return L(PROFILES[i].en, PROFILES[i].zh) end
  end
  return id
end

-- Before apply-visual.sh has run once, nothing is known to be missing.
local function IsReady(id)
  if id == "vanilla" then return true end
  local ready = GetCVar("solorothVisualReady")
  if not ready or ready == "" then return true end
  return strfind(" " .. ready .. " ", " " .. id .. " ", 1, true) ~= nil
end

SOLOROTH_TOOLTIP_VISUAL = L(
  "Swaps creature and world models for a high-detail pack.\n\n"
    .. "Takes effect the next time Soloroth starts (quit fully, then launch again). "
    .. "Greyed entries are not downloaded yet: run tools/macos/fetch-visual-patches.sh.",
  "把怪物和世界模型换成高清包。\n\n"
    .. "下次启动 Soloroth 时生效（完全退出后重新打开）。"
    .. "灰色的选项还没下载，运行 tools/macos/fetch-visual-patches.sh 即可。"
)

local function Status(row)
  local hint = row.soloHint
  if not hint then return end
  local cur, active = Current(), GetCVar("solorothVisualActive")
  if active and active ~= "" and active ~= cur then
    hint:SetText(L("Restart to apply", "重启后生效"))
    hint:Show()
  else
    hint:Hide()
  end
end

-- The page's own InitMenu, plus disabled entries for packs not on disk.
local function InitMenu()
  local dd = getglobal(UIDROPDOWNMENU_INIT_MENU)
  local row = dd:GetParent()
  local cur = Current()
  for i = 1, table.getn(row.entries) do
    local e = row.entries[i]
    local info = {}
    info.text = e.text
    info.value = e.value
    info.checked = (e.value == cur) and 1 or nil
    if IsReady(e.value) then
      info.func = BenillaOptionsDropdownEntry_OnClick
    else
      info.text = e.text .. L(" (not installed)", "（未安装）")
      info.disabled = 1
    end
    UIDropDownMenu_AddButton(info)
  end
end

local function Build()
  local graphics = BenillaOptionsFrameContainerBodyGraphics
  if getglobal(ROW_NAME) or not graphics or not BENILLA_OPTIONS_PAGE_ROWS then return end

  local row = CreateFrame("Frame", ROW_NAME, graphics, "BenillaOptionsDropdownRowTemplate")
  BenillaOptionsRow_OnLoad(row, CVAR, L("Creature Models", "怪物模型"), "SOLOROTH_TOOLTIP_VISUAL")
  local entries = {}
  for i = 1, table.getn(PROFILES) do
    entries[i] = { text = L(PROFILES[i].en, PROFILES[i].zh), value = PROFILES[i].id }
  end
  BenillaOptionsDropdownRow_Setup(row, entries)
  UIDropDownMenu_Initialize(getglobal(ROW_NAME .. "Dropdown"), InitMenu)

  local hint = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("LEFT", getglobal(ROW_NAME .. "Dropdown"), "RIGHT", -6, 2)
  hint:Hide()
  row.soloHint = hint

  row.afterSet = function()
    Status(row)
    DEFAULT_CHAT_FRAME:AddMessage("|cff44ddffSolo|r: " .. L(
      "creature models → " .. LabelOf(Current()) .. ". Quit fully and start Soloroth again to apply.",
      "怪物模型已选「" .. LabelOf(Current()) .. "」，完全退出后重新打开 Soloroth 生效。"
    ))
  end

  table.insert(BENILLA_OPTIONS_PAGE_ROWS.Graphics, ROW_KEY)
  BenillaOptionsPage_Layout("Graphics")
  BenillaOptionsDropdown_ShowValue(row)
  Status(row)

  local prev = graphics:GetScript("OnShow")
  graphics:SetScript("OnShow", function()
    if prev then prev() end
    Status(row)
  end)
end

-- Built at load, before pfUI's Benilla skin walks the options window once.
Build()

SLASH_SOLOVISUAL1 = "/visual"
SLASH_SOLOVISUAL2 = "/waiguan"
SlashCmdList["SOLOVISUAL"] = function(msg)
  msg = string.gsub(msg or "", "^%s*(.-)%s*$", "%1")
  local cur = Current()
  if msg == "" or msg == "list" then
    DEFAULT_CHAT_FRAME:AddMessage("|cff44ddffSolo|r: " .. L("creature model packs:", "怪物模型方案："))
    for i = 1, table.getn(PROFILES) do
      local p = PROFILES[i]
      local mark = (p.id == cur) and " *" or ""
      if not IsReady(p.id) then mark = mark .. L(" (not installed)", "（未安装）") end
      DEFAULT_CHAT_FRAME:AddMessage("  " .. p.id .. " — " .. L(p.en, p.zh) .. mark)
    end
    DEFAULT_CHAT_FRAME:AddMessage(L("Usage: /visual <id>, or Options → Graphics",
      "用法：/visual <id>，或 选项 → 图形"))
    return
  end
  local known
  for i = 1, table.getn(PROFILES) do
    if PROFILES[i].id == msg then known = true break end
  end
  if not known then
    DEFAULT_CHAT_FRAME:AddMessage("|cff44ddffSolo|r: " .. L("unknown profile", "未知方案") .. " " .. msg)
    return
  end
  if not IsReady(msg) then
    DEFAULT_CHAT_FRAME:AddMessage("|cff44ddffSolo|r: " .. LabelOf(msg) .. L(" is not installed.", " 还没安装。"))
    return
  end
  SetCVar(CVAR, msg)
  local row = getglobal(ROW_NAME)
  if row then
    BenillaOptionsDropdown_ShowValue(row)
    row.afterSet()
  end
end
