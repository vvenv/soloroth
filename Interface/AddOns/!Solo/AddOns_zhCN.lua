--[[--------------------------------------------------------------------------
Chinese for third-party addons that ship English-only UI. Their sources stay
untouched; this file swaps the strings after each addon loads (zhCN clients
only). Bagshui has its own Locale/zhCN.lua. pfQuest's locales.lua has zhCN
but the minimap shortcut menu keys were never translated upstream, so those
are filled in here and the already-built menu labels are refreshed.
----------------------------------------------------------------------------]]

if GetLocale() ~= "zhCN" then return end

-- ------------------------------------------------------------------ pfQuest --

-- Menu titles are looked up once when menu.lua loads; missing keys fall back
-- to the English key string and get baked into the buttons.
local PFQUEST_MENU = {
  ["Shortcut Menu"] = "快捷菜单",
  ["Database"] = "数据库",
  ["Chests & Treasures"] = "宝箱与宝藏",
  ["Herbs & Flowers"] = "草药与花朵",
  ["Mines & Ores"] = "矿脉与矿石",
  ["Fishing Pools"] = "鱼点",
  ["Rare Mobs"] = "稀有怪物",
  ["Auctioneer"] = "拍卖师",
  ["Banker"] = "银行职员",
  ["Battlemaster"] = "战场军官",
  ["Flight Master"] = "飞行管理员",
  ["Innkeeper"] = "旅店老板",
  ["Mailbox"] = "邮箱",
  ["Meeting Stones"] = "集合石",
  ["Repair"] = "修理",
  ["Spirit Healer"] = "灵魂医者",
  ["Stable Master"] = "兽栏管理员",
  ["Vendor"] = "商人",
  ["Quest Journal"] = "任务日志",
  ["Welcome Screen"] = "欢迎界面",
  ["Settings"] = "设置",
}

-- Button names inside pfQuestMenu (see pfQuest/menu.lua).
local PFQUEST_MENU_BUTTONS = {
  {"database", "Database"},
  {"chests", "Chests & Treasures"},
  {"herbs", "Herbs & Flowers"},
  {"mines", "Mines & Ores"},
  {"fish", "Fishing Pools"},
  {"rares", "Rare Mobs"},
  {"auctioneer", "Auctioneer"},
  {"banker", "Banker"},
  {"battlemaster", "Battlemaster"},
  {"flight", "Flight Master"},
  {"innkeeper", "Innkeeper"},
  {"mailbox", "Mailbox"},
  {"meetingstone", "Meeting Stones"},
  {"repair", "Repair"},
  {"spirithealer", "Spirit Healer"},
  {"stablemaster", "Stable Master"},
  {"vendor", "Vendor"},
  {"journal", "Quest Journal"},
  {"welcome", "Welcome Screen"},
  {"settings", "Settings"},
}

local function LocalizePfQuest()
  if not pfQuest_Loc then return end
  local k, v, i, row, btn, width
  for k, v in pairs(PFQUEST_MENU) do
    pfQuest_Loc[k] = v
  end
  if not pfQuestMenu then return end
  width = 0
  for i = 1, table.getn(PFQUEST_MENU_BUTTONS) do
    row = PFQUEST_MENU_BUTTONS[i]
    btn = pfQuestMenu[row[1]]
    if btn and btn.title then
      btn.title:SetText(PFQUEST_MENU[row[2]])
      if btn.title.GetStringWidth then
        width = math.max(width, btn.title:GetStringWidth() + 60)
      end
    end
  end
  if width > 0 then pfQuestMenu:SetWidth(width) end
end

-- ---------------------------------------------------------------- SuperMacro --

local function LocalizeSuperMacro()
  SUPERMACROFRAME_EXTEND_CHAR_LIMIT = "扩展代码：%d/" .. EXTEND_MAX_LETTERS
  SUPERMACROFRAME_SUPER_CHAR_LIMIT = "超级宏：%d/" .. SUPER_MAX_LETTERS
  REGULAR = "普通"
  SUPER = "超级"
  SAVE_MACRO = "保存宏"
  ENTER_EXTEND_LABEL = "输入扩展 Lua 代码："
  SAVE_EXTEND = "保存扩展"
  DELETE_EXTEND = "删除扩展"
  SAVE_SUPERMACRO = "保存超级宏"
  NEW_SUPERMACRO = "新建超级宏"
  DELETE_SUPERMACRO = "删除超级宏"
  SUPERMACRO_TITLE = "超级宏"
  SUPERMACRO_BUTTON = "宏\n命\n令"
  SUPERMACRO_OPTIONS = "超级宏设置"
  SUPERMACRO_NEW_ACCOUNT = "新建账号宏"
  SUPERMACRO_NEW_CHARACTER = "新建角色宏"
  SUPERMACRO_OPTIONS_TITLE = "超级宏设置"
  SUPERMACRO_MINIMAP = "打开超级宏"

  SM_HIDE_ACTION = "隐藏动作条上的名称"
  SM_MACRO_TIP_1 = "显示法术或物品提示"
  SM_MACRO_TIP_2 = "显示宏脚本提示"
  SM_PRINT_COLOR = "SM_print() 与 /print 的输出颜色"
  SM_PRINT_COLOR_EXAMPLE_TEXT = "示例：现在能看见我吗？"
  SM_MINIMAP = "显示小地图按钮"
  SM_REPLACE_ICON = "自动替换动作图标"
  SM_CHECK_COOLDOWN = "自动检查动作冷却"
  SM_SHOW_MENU = "显示菜单按钮"
  SM_WORDWRAP = "长句自动换行"
  SM_MONO_FONT = "脚本编辑框使用等宽字体"
  SM_WINDOW_HEIGHT = "主窗口高度"
  SM_WINDOW_WIDTH = "主窗口宽度"
  SM_EDITBOX_FONT_SIZE = "脚本编辑框字号"

  SUPERMACRO_HELP_LINE1 = "输入 /supermacro 查看帮助"
  SUPERMACRO_HELP_LINE2 = "/macro <宏名称> 按名称运行宏"
  SUPERMACRO_HELP_LINE3 = "/supermacro hideaction 1 或 0 隐藏或显示动作按钮上的宏名称"
  SUPERMACRO_HELP_LINE4 = "/supermacro printcolor <红> <绿> <蓝>，每个 0 到 1，改变 /print 颜色"
  SUPERMACRO_HELP_LINE5 = "/supermacro macrotip 0-3，默认 1"
  SUPERMACRO_HELP_LINE6 = "0 普通，1 显示法术，2 显示宏代码，3 显示法术和/或代码"

  BINDING_HEADER_SUPERMACROHEADER = "超级宏"
  BINDING_NAME_TOGGLESUPERMACRO = "打开/关闭超级宏"
  BINDING_NAME_OPENCHATSCRIPT = "打开聊天 /script"
  BINDING_NAME_OPENCHATMACRO = "打开聊天 /macro"
  BINDING_NAME_SM_ATTACK = "攻击"
  BINDING_NAME_SM_PETATTACK = "宠物攻击"
  local i
  for i = 1, 36 do
    setglobal("BINDING_NAME_SM_MACRO" .. i, "宏 " .. i)
  end
  for i = 1, 10 do
    setglobal("BINDING_NAME_SM_SUPERMACRO" .. i, "超级宏 " .. i)
  end

  -- Options panel captured the English example string at load time.
  if SuperMacroOptionsFrameColorSwatches and SuperMacroOptionsFrameColorSwatches["SM_PRINT_COLOR"] then
    SuperMacroOptionsFrameColorSwatches["SM_PRINT_COLOR"].exampleText = SM_PRINT_COLOR_EXAMPLE_TEXT
  end

  local function Text(name, value)
    local w = getglobal(name)
    if w and w.SetText and value then w:SetText(value) end
  end

  Text("SuperMacroFrameTitle", SUPERMACRO_TITLE .. " " .. (SUPERMACRO_VERSION or ""))
  Text("SuperMacroFrameEnterExtendText", ENTER_EXTEND_LABEL)
  Text("SuperMacroSaveButton", SAVE_MACRO)
  Text("SuperMacroSaveExtendButton", SAVE_EXTEND)
  Text("SuperMacroDeleteExtendButton", DELETE_EXTEND)
  Text("SuperMacroNewAccountButton", SUPERMACRO_NEW_ACCOUNT)
  Text("SuperMacroNewCharacterButton", SUPERMACRO_NEW_CHARACTER)
  Text("SuperMacroNewSuperButton", NEW_SUPERMACRO)
  Text("SuperMacroSaveSuperButton", SAVE_SUPERMACRO)
  Text("SuperMacroDeleteSuperButton", DELETE_SUPERMACRO)
  Text("SuperMacroOptionsButton", SUPERMACRO_OPTIONS)
  Text("SuperMacroFrameTab1", REGULAR)
  Text("SuperMacroFrameTab2", SUPER)
  Text("SuperMacroOptionsTitleText", SUPERMACRO_OPTIONS_TITLE)
  Text("GameMenuButtonSuperMacro", SUPERMACRO_BUTTON)
end

-- --------------------------------------------------------------- ShaguNotify --

local function LocalizeShaguNotify()
  if not libnotify or not libnotify.ShowPopup then return end
  local orig = libnotify.ShowPopup
  function libnotify:ShowPopup(text, points, icon, elite, header)
    if header == "Discovered" then header = "已发现" end
    if text == "I will survive!" then text = "死里逃生！" end
    if type(text) == "string" then
      local _, _, lvl = string.find(text, "^Level: (%d+)$")
      if lvl then text = "等级：" .. lvl end
    end
    return orig(self, text, points, icon, elite, header)
  end
end

-- ----------------------------------------------------------------- ShaguKill --

-- ShaguKill's frame is local; rewrite the English kill-count lines as they
-- land on the error frame.
local function LocalizeShaguKill()
  if not UIErrorsFrame or not UIErrorsFrame.AddMessage then return end
  if UIErrorsFrame.soloZhKill then return end
  UIErrorsFrame.soloZhKill = true
  local orig = UIErrorsFrame.AddMessage
  function UIErrorsFrame:AddMessage(msg, r, g, b, a, hold)
    if type(msg) == "string" then
      local _, _, n = string.find(msg, "^next level: |cffffffaa~(%d+)|r kills%.$")
      if n then
        msg = "升级还需击杀：|cffffffaa~" .. n .. "|r 只"
      else
        _, _, n = string.find(msg, "^pet: |cffffffaa~(%d+)|r kills%.$")
        if n then
          msg = "宠物升级还需击杀：|cffffffaa~" .. n .. "|r 只"
        end
      end
    end
    return orig(self, msg, r, g, b, a, hold)
  end
end

-- --------------------------------------------------------------------- load --

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function()
  if arg1 == "pfQuest" then
    LocalizePfQuest()
  elseif arg1 == "SuperMacro" then
    LocalizeSuperMacro()
  elseif arg1 == "ShaguNotify" then
    LocalizeShaguNotify()
  elseif arg1 == "ShaguKill" then
    LocalizeShaguKill()
  end
end)

-- Already-loaded addons (load order can put them before this file runs).
if IsAddOnLoaded and IsAddOnLoaded("pfQuest") then LocalizePfQuest() end
if IsAddOnLoaded and IsAddOnLoaded("SuperMacro") then LocalizeSuperMacro() end
if IsAddOnLoaded and IsAddOnLoaded("ShaguNotify") then LocalizeShaguNotify() end
if IsAddOnLoaded and IsAddOnLoaded("ShaguKill") then LocalizeShaguKill() end
