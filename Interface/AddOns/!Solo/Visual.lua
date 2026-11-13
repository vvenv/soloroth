--[[--------------------------------------------------------------------------
Model / visual profile switcher for Soloroth.

Lives on the Options → Graphics page. Choice is a RegisterCVar
(solorothVisual) so it lands in benilla-config/config.toml; play.sh /
apply-visual.sh remount the matching patch-?.MPQ overlays on the next
launch. Mid-session swaps are impossible: the MPQ chain is fixed at boot.

Buttons are skinned through SoloSkin (pfUI) once pfUI has loaded.
----------------------------------------------------------------------------]]

local CVAR = "solorothVisual"
local DEFAULT = "vanilla"

-- id = folder under ../wow-data/visual-patches/ (or "vanilla")
-- Reforged full packs ship DBC overrides that break benilla (ErrorCube /
-- "pillar" mobs). Use reforged-creatures only after strip-mpq-dbc, or vanilla.
local PROFILES = {
  { id = "vanilla",             en = "Vanilla (original)",           zh = "原版（默认）" },
  { id = "reforged-creatures",  en = "HD creatures (models only)",   zh = "高清怪物（仅模型）" },
  { id = "improved-models",     en = "Improved Models",              zh = "Improved Models" },
  { id = "hd",                  en = "HD pack (multi-patch)",        zh = "高清合集" },
}

local ZH = (GetLocale and GetLocale() == "zhCN") and true or false
local function L(en, zh) if ZH and zh then return zh end return en end

local function LabelOf(id)
  for i = 1, table.getn(PROFILES) do
    if PROFILES[i].id == id then return L(PROFILES[i].en, PROFILES[i].zh) end
  end
  return id
end

RegisterCVar(CVAR, DEFAULT)

local function Current()
  local v = GetCVar(CVAR)
  if not v or v == "" then return DEFAULT end
  return v
end

local ui = { buttons = {} }

local function RefreshMarks()
  local cur = Current()
  for i = 1, table.getn(ui.buttons) do
    local b = ui.buttons[i]
    if b.id == cur then
      b:SetText("|cff44ddff> " .. b.label .. "|r")
    else
      b:SetText(b.label)
    end
  end
  if ui.hint then
    ui.hint:SetText(L(
      "Applies on next full launch. Current: " .. LabelOf(cur),
      "下次完全启动后生效。当前：" .. LabelOf(cur)
    ))
  end
end

local function Choose(id)
  if id == Current() then
    DEFAULT_CHAT_FRAME:AddMessage("|cff44ddffSolo|r: " .. L(
      "already using " .. LabelOf(id),
      "已经是「" .. LabelOf(id) .. "」"
    ))
    return
  end
  SetCVar(CVAR, id)
  RefreshMarks()
  DEFAULT_CHAT_FRAME:AddMessage("|cff44ddffSolo|r: " .. L(
    "visual profile → " .. LabelOf(id) .. ". Quit fully, then start Soloroth again.",
    "外观已选「" .. LabelOf(id) .. "」。请完全退出，再打开 Soloroth。"
  ))
end

local function SkinButtons()
  if not (pfUI and pfUI.api and pfUI.api.SkinButton) then return end
  for i = 1, table.getn(ui.buttons) do
    local b = ui.buttons[i]
    if b and not b.soloSkinned then
      b.soloSkinned = true
      pfUI.api.SkinButton(b)
    end
  end
end

local function Build()
  if ui.root then
    SkinButtons()
    RefreshMarks()
    return
  end
  local graphics = BenillaOptionsFrameContainerBodyGraphics
  local anchor = BenillaOptionsFrameContainerBodyGraphicsRowRenderScale
  if not graphics or not anchor then return end

  local root = CreateFrame("Frame", "SoloVisualOptions", graphics)
  root:SetHeight(120)
  root:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -16)
  root:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -16)
  ui.root = root

  local title = root:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  title:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
  title:SetText(L("Creature / world models", "怪物 / 世界模型"))
  ui.title = title

  local hint = root:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  hint:SetPoint("RIGHT", root, "RIGHT", 0, 0)
  hint:SetJustifyH("LEFT")
  ui.hint = hint

  local y = -36
  for i = 1, table.getn(PROFILES) do
    local p = PROFILES[i]
    local b = CreateFrame("Button", "SoloVisualBtn" .. i, root, "UIPanelButtonTemplate")
    b:SetWidth(200)
    b:SetHeight(22)
    local col = (i - 1) - math.floor((i - 1) / 2) * 2
    local row = math.floor((i - 1) / 2)
    b:SetPoint("TOPLEFT", root, "TOPLEFT", col * 210, y - row * 26)
    b.id = p.id
    b.label = L(p.en, p.zh)
    b:SetText(b.label)
    b:SetScript("OnClick", function() Choose(this.id) end)
    b:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:AddLine(this.label)
      GameTooltip:AddLine(L(
        "Needs wow-data/visual-patches/<id>/patch-?.MPQ. Vanilla needs nothing. Raw Reforged DBCs break models in benilla.",
        "需要 wow-data/visual-patches/<id>/ 下的 patch。原版不用文件。未处理的 Reforged DBC 会在 benilla 里把怪变成方块。"
      ), 1, 1, 1, 1)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ui.buttons[i] = b
  end

  SkinButtons()
  RefreshMarks()
end

-- pfUI skins run after earlier addons; register so we re-skin when it lands.
if SoloSkin and SoloSkin.Register then
  SoloSkin.Register("SoloVisual", function()
    Build()
    SkinButtons()
  end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  Build()
  local graphics = BenillaOptionsFrameContainerBodyGraphics
  if graphics then
    local prev = graphics:GetScript("OnShow")
    graphics:SetScript("OnShow", function()
      if prev then prev() end
      SkinButtons()
      RefreshMarks()
    end)
  end
end)

SLASH_SOLOVISUAL1 = "/visual"
SLASH_SOLOVISUAL2 = "/waiguan"
SlashCmdList["SOLOVISUAL"] = function(msg)
  msg = string.gsub(msg or "", "^%s*(.-)%s*$", "%1")
  if msg == "" or msg == "list" then
    local cur = Current()
    DEFAULT_CHAT_FRAME:AddMessage("|cff44ddffSolo|r: " .. L("visual profiles:", "外观方案："))
    for i = 1, table.getn(PROFILES) do
      local p = PROFILES[i]
      local mark = (p.id == cur) and " *" or ""
      DEFAULT_CHAT_FRAME:AddMessage("  " .. p.id .. " — " .. L(p.en, p.zh) .. mark)
    end
    DEFAULT_CHAT_FRAME:AddMessage(L("Usage: /visual <id>   or Options → Graphics",
      "用法：/visual <id>，或 选项 → 图形"))
    return
  end
  local ok
  for i = 1, table.getn(PROFILES) do
    if PROFILES[i].id == msg then ok = true break end
  end
  if not ok then
    DEFAULT_CHAT_FRAME:AddMessage("|cff44ddffSolo|r: " .. L("unknown profile", "未知方案") .. " " .. msg)
    return
  end
  Choose(msg)
end
