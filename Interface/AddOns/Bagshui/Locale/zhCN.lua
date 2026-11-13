Bagshui:LoadComponent(function()

BsLocalization:AddLocale("zhCN", {

-- ### Game Stuff ###

-- Player classes.
["Druid"] = "德鲁伊",
["Hunter"] = "猎人",
["Mage"] = "法师",
["Paladin"] = "圣骑士",
["Priest"] = "牧师",
["Rogue"] = "盗贼",
["Shaman"] = "萨满祭司",
["Warlock"] = "术士",
["Warrior"] = "战士",

-- Item classes and subclasses that can't be automatically localized because they're not
-- returned from GetAuctionItemClasses() / GetAuctionItemSubClasses().
["Devices"] = "装置",
["Explosives"] = "爆炸物",
["Junk"] = "垃圾",
["Key"] = "钥匙",
["Miscellaneous"] = "杂项",
["Parts"] = "零件",
["Quest"] = "任务",
["Trade Goods"] = "商品",

-- Skill types.
-- Must cover all keys in LOCALIZED_TO_EN_SKILL_ID and IGNORE_SKILL_CATEGORY.
["Class Skills"] = "职业技能",
["Professions"] = "专业",
["Secondary Skills"] = "辅助技能",
["Weapon Skills"] = "武器技能",
["Armor Proficiencies"] = "护甲精通",
["Languages"] = "语言",

-- Skills.
-- Must cover any skill that the game can return from GetSkillLineInfo().
["Axes"] = "斧",
["Dual Wield"] = "双武器",
["Fishing"] = "钓鱼",
["Maces"] = "锤",
["Swords"] = "剑",
["Plate Mail"] = "板甲",
["Shield"] = "盾牌",

-- Professions that have their own bag types.
-- Referenced in GameInfo.lua to build the professionsToBags table.
["Enchanting"] = "附魔",
["Herbalism"] = "草药学",




-- ### General ###

["AbandonChanges"] = "放弃更改",
["About"] = "关于",
["Actions"] = "操作",
["Add"] = "添加",
["AddSlashRemove"] = "添加/移除",
["Aliases"] = "别名",
["AltClick"] = "Alt+点击",
["AltRightClick"] = "Alt+右键点击",
["Ascending"] = "升序",
["Available"] = "可用",
["Background"] = "背景",
["Bag"] = "背包",
["Border"] = "边框",
["Bottom"] = "底部",
["Cancel"] = "取消",
["Catalog"] = "目录",
["Categories"] = "分类",
["Category"] = "分类",
["CharacterData"] = "角色数据",
["CategorySlashItem"] = "分类/物品",
["ClassCategory"] = "职业分类",
["Clear"] = "清除",
["Click"] = "点击",
["Close"] = "关闭",
["Color"] = "颜色",
["Column"] = "列",
["Copy"] = "复制",
["Create"] = "创建",
["Creation"] = "创建",
["Custom"] = "自定义",
["Default"] = "默认",
["Delete"] = "删除",
["Deletion"] = "删除",
["Descending"] = "降序",
["Details"] = "详情",
["Dialog"] = "对话框",
["Disable"] = "禁用",
["Duplicate"] = "复制副本",
["Edit"] = "编辑",
["Editing"] = "编辑",
["EmptyBagSlot"] = "空背包栏位",
["Export"] = "导出",
["Full"] = "已满",
["Group"] = "分组",
["Help"] = "帮助",
["Hidden"] = "已隐藏",
["Hide"] = "隐藏",  -- Verb, opposite of show
["HoldAlt"] = "按住Alt",
["HoldControlAlt"] = "按住Ctrl+Alt",
["Horizontal"] = "水平",
["Ignore"] = "忽略",
["Import"] = "导入",
["ImportSlashExport"] = "导入/导出",
["Info"] = "信息",
["Information"] = "信息",
["Inventory"] = "物品栏",
["Item"] = "物品",
["ItemProperties"] = "物品属性",
["KeepEditing"] = "继续编辑",
["Label"] = "标签",
["Left"] = "左",
["Location"] = "位置",
["Lock"] = "锁定",
["LogWindow"] = "日志窗口",
["Manage"] = "管理",
["Menu"] = "菜单",
["MoreInformation"] = "更多信息",
["Move"] = "移动",
["MoveDown"] = "下移",
["MoveUp"] = "上移",
["Name"] = "名称",
["New"] = "新建",
["No"] = "否",
["NotNow"] = "暂不",
["NoItemsAvailable"] = "(无可用物品)",
["NoneAssigned"] = "(未分配)",
["NoneParenthesis"] = "(无)",
["NoRuleFunction"] = "(无规则函数)",
["NoValue"] = "(无值)",
["Open"] = "打开",
["PleaseWait"] = "请稍候...",
["Profile"] = "方案",
["Prefix_Add"] = "添加%s",
["Prefix_Bag"] = "背包%s",
["Prefix_Class"] = "职业%s",
["Prefix_ClickFor"] = "点击%s",
["Prefix_Default"] = "默认%s",
["Prefix_Edit"] = "编辑%s",
["Prefix_Manage"] = "管理%s",
["Prefix_Move"] = "移动%s",
["Prefix_New"] = "新建%s",
["Prefix_OpenMenuFor"] = "打开%s菜单",
["Prefix_Remove"] = "移除%s",
["Prefix_Search"] = "搜索%s",
["Prefix_Sort"] = "排序%s",
["Prefix_Target"] = "目标%s",
["Prefix_Toggle"] = "切换%s",
["Prefix_Unnamed"] = "(未命名%s)",
["Profiles"] = "方案",
["Quality"] = "品质",
["ReleaseAlt"] = "松开Alt",
["Reload"] = "重新加载",
["Remove"] = "移除",
["Rename"] = "重命名",
["Replace"] = "替换",
["Report"] = "报告",
["Right"] = "右",
["RightClick"] = "右键点击",
["Row"] = "行",
["Save"] = "保存",
["Search"] = "搜索",
["Settings"] = "设置",
["Share"] = "分享",
["Show"] = "显示",
["SortOrder"] = "排序方式",
["SortOrders"] = "排序方式",
["Sorting"] = "排序",
["Stack"] = "堆叠",  -- Verb
["Suffix_Default"] = "%s " .. LIGHTYELLOW_FONT_COLOR_CODE .. " [默认]" .. FONT_COLOR_CODE_CLOSE,
["Suffix_EmptySlot"] = "%s空栏位",
["Suffix_Menu"] = "%s菜单",
["Suffix_ReadOnly"] = "%s " .. LIGHTYELLOW_FONT_COLOR_CODE .. "[只读]" .. FONT_COLOR_CODE_CLOSE,
["Suffix_Reversed"] = "%s [反向]",  -- Used in explanations of sort orders when a field is reversed (i.e. Name [reversed])
["Suffix_Sets"] = "%d 套",
["Symbol_Brackets"] = "[%s]",
["Symbol_Colon"] = "%s：",
["Symbol_Ellipsis"] = "%s…",  -- Used in menus to indicate that clicking it will open another dialog or menu
["Templates"] = "模板",
["Text"] = "文本",
["Toggle"] = "切换",  -- Verb
["Top"] = "顶部",
["Total"] = "总计",
["Undo"] = "撤销",
["Unknown"] = "未知",
["Unlock"] = "解锁",
["Unnamed"] = "(未命名)",
["Unstack"] = "取消堆叠",  -- Verb
["Used"] = "已使用",
["UseDefault"] = "使用默认值",
["Validate"] = "验证",
["Vertical"] = "垂直",
["VersionNumber"] = "版本 %s",
["Yes"] = "是",

-- Inventory types.
["Bags"] = "背包",
["Bank"] = "银行",
["Equipped"] = "已装备",
["Keyring"] = "钥匙链",

-- Abbreviations for tooltip use.
["Abbrev_Bags"] = "背包",
["Abbrev_Bank"] = "银行",
["Abbrev_Keyring"] = "钥匙",
["Abbrev_Equipped"] = "装备",

-- Slash command help message.
["Slash_Help"] = "%s 命令：",
["Slash_Help_Postscript"] = "要查看子命令列表，请在命令后加上 Help。",

-- Key bindings (other than Inventory class names; those are handled in Inventory:New()).
["Binding_Resort"] = "整理全部",
["Binding_Restack"] = "重新堆叠全部",

-- Item properties to friendly names as `ItemPropFriendly_<propertyName>`.
-- Anything non-private in BS_ITEM_SKELETON or BS_REALTIME_ITEM_INFO_PROPERTIES must be present.
["ItemPropFriendly_activeQuest"] = "进行中的任务物品",
["ItemPropFriendly_baseName"] = "基础名称",
["ItemPropFriendly_bagNum"] = "背包编号",
["ItemPropFriendly_bagType"] = "背包类型",
["ItemPropFriendly_bindsOnEquip"] = "装备后绑定",
["ItemPropFriendly_charges"] = "次数",
["ItemPropFriendly_count"] = "数量",
["ItemPropFriendly_equipLocation"] = "装备位置",
["ItemPropFriendly_equipLocationLocalized"] = "装备位置(本地化)",
["ItemPropFriendly_emptySlot"] = "空栏位",
["ItemPropFriendly_id"] = "物品ID",
["ItemPropFriendly_itemLink"] = "物品链接",
["ItemPropFriendly_itemString"] = "物品字符串",
["ItemPropFriendly_locked"] = "已锁定",
["ItemPropFriendly_maxStackCount"] = "最大堆叠数量",
["ItemPropFriendly_minLevel"] = "最低等级",
["ItemPropFriendly_name"] = "!!Name!!",
["ItemPropFriendly_periodicTable"] = "元素周期表",
["ItemPropFriendly_quality"] = "!!Quality!!",
["ItemPropFriendly_qualityLocalized"] = "品质(本地化)",
["ItemPropFriendly_readable"] = "可阅读",
["ItemPropFriendly_slotNum"] = "栏位编号",
["ItemPropFriendly_soulbound"] = "已绑定",
["ItemPropFriendly_stacks"] = "可堆叠",
["ItemPropFriendly_subtype"] = "子类型",
["ItemPropFriendly_SuffixName"] = "后缀名称",
["ItemPropFriendly_tooltip"] = "提示信息",
["ItemPropFriendly_type"] = "类型",
["ItemPropFriendly_uncategorized"] = "未分类",




-- ### Inventory UI ###

["Inventory_NoData"] = "没有可用的离线物品栏数据。",

-- Toolbar.
["Toolbar_Menu_TooltipTitle"] = "菜单",
["Toolbar_ExitEditMode"] = "退出编辑模式",
["Toolbar_Catalog_TooltipTitle"] = "目录(账号通用物品栏)",
["Toolbar_Catalog_TooltipText"] = "查看并搜索此账号下所有角色的物品合集。",
["Toolbar_Character_TooltipTitle"] = "角色",
["Toolbar_Character_TooltipText"] = "查看你其他角色的%s。",  -- %s = Inventory type.
["Toolbar_Hide_TooltipTitle"] = "不显示已隐藏项",
["Toolbar_Show_TooltipTitle"] = "显示已隐藏项",
["Toolbar_Show_TooltipText"] = "切换是否显示已隐藏的物品。",
["Toolbar_Search_TooltipTitle"] = "搜索",
["Toolbar_Search_TooltipText"] = "筛选你的%s内容。" .. BS_NEWLINE .. "搜索时按 Shift+回车键 可打开目录。",  -- %s = Inventory type.
["Toolbar_Resort_TooltipTitle"] = "整理",
["Toolbar_Resort_TooltipText"] = "重新排序并分类。",
["Toolbar_Restack_TooltipTitle"] = "重新堆叠",
["Toolbar_Restack_TooltipText"] = "合并可堆叠的物品。",
["Toolbar_HighlightChanges_TooltipTitle"] = "高亮变化",
["Toolbar_HighlightChanges_TooltipText"] = "切换是否高亮显示最近变化的物品。" .. BS_NEWLINE .. GRAY_FONT_COLOR_CODE .. "Alt+点击可将所有物品标记为未变化。",
["Toolbar_UnHighlightChanges_TooltipTitle"] = "不高亮变化",

-- Action Tooltips.
["Tooltip_Inventory_ToggleBagSlotHighlightLockHint"] = "%s可%s栏位高亮。",  -- "Alt-Click to lock/unlock slot highlighting"
["Tooltip_Inventory_ToggleEmptySlotStacking"] = "%s可%s空栏位。",  -- "Click to stack/unstack empty slots"
["Tooltip_Inventory_TradeShortcut"] = "%s可与%s交易。",  -- "Alt-Click to trade with <Player Name>"

-- Edit Mode.
["EditMode"] = "编辑模式",
["EditMode_CategoryInGroup"] = "在当前结构中已分配到分组“%s”。",  -- %s = group name or (Unnamed Group)
["EditMode_CategoryNotInGroup"] = "在当前结构中未分配到任何分组。",
["EditMode_Prompt_NewGroupName"] = "新分组的标签(可选，但建议填写)：",
["EditMode_Prompt_RenameGroup"] = "%s的新标签：",
["EditMode_Prompt_DeleteGroup"] = "要删除所选分组吗？!!Warning_NoUndo!!",
["EditMode_Tooltip_SelectNew"] = "选择新的%s。",  -- %s = L.Location or L.Group

-- Main Menu.
["Menu_Main_EditMode_TooltipText"] = "修改当前结构(重新排列分组、分配分类等)。",
["Menu_Main_Settings_TooltipText"] = "打开设置菜单。",
["Menu_Main_ManageCategories_TooltipText"] = "打开分类管理器。",
["Menu_Main_ManageProfiles_TooltipText"] = "打开方案管理器。",
["Menu_Main_ManageSortOrders_TooltipText"] = "打开排序方式管理器。",
["Menu_Main_Toggle_TooltipText"] = "切换%s窗口。",

-- Settings Menu (localizations for settings themselves are configured in `settingsStrings`).
["Menu_Settings"] = "%s设置",  -- "Bags Settings"
["Menu_Settings_About"] = "关于 Bagshui",
["Menu_Settings_Accessibility"] = "辅助功能",
["Menu_Settings_Advanced"] = "高级",
["Menu_Settings_Anchoring"] = "锚点",
["Menu_Settings_Behaviors"] = "行为",
["Menu_Settings_Badges"] = "物品标记",
["Menu_Settings_ChangeTiming"] = "库存变化计时",
["Menu_Settings_Colors"] = "颜色",
["Menu_Settings_ColorHistory_TooltipTitle"] = "取色器历史记录",
["Menu_Settings_Commands"] = "命令",
["Menu_Settings_DefaultProfiles"] = "默认方案",
["Menu_Settings_Defaults"] = "默认值",
["Menu_Settings_Etcetera"] = "其他",
["Menu_Settings_General"] = "常规",
["Menu_Settings_GroupDefaults"] = "分组默认值",
["Menu_Settings_Groups"] = "分组",
["Menu_Settings_Hooks_Suffix"] = "%s接管",  -- %s = Inventory type.
["Menu_Settings_Integration"] = "整合",
["Menu_Settings_Interface"] = "界面",
["Menu_Settings_ItemSlots"] = "物品栏位",
["Menu_Settings_More"] = "更多",
["Menu_Settings_More_TooltipTitle"] = "附加设置",
["Menu_Settings_Overrides"] = "覆盖",
["Menu_Settings_Open"] = "!!Open!!",
["Menu_Settings_Options"] = "选项",
["Menu_Settings_Profile"] = "方案",
["Menu_Settings_Size"] = "尺寸",
["Menu_Settings_Tinting"] = "物品着色",
["Menu_Settings_Toolbar"] = "工具栏",
["Menu_Settings_Tooltips"] = "提示信息",
["Menu_Settings_ToggleBagsWith"] = "联动开关背包",
["Menu_Settings_StockBadgeColors"] = "库存颜色",
["Menu_Settings_View"] = "视图",
["Menu_Settings_Window"] = "窗口",

-- Category Menu.
["Menu_Category_Move_TooltipText"] = "拾起此分类，以便将其移动到新的分组。",
["Menu_Category_Edit_TooltipText"] = "在编辑器中打开此分类。",
["Menu_Category_Remove_TooltipText"] = "将此分类从当前分组中移除。!!Info_NoDelete!!",

-- Group Menu.
["Menu_Group_Rename_TooltipTitle"] = "重命名分组",
["Menu_Group_Rename_TooltipText"] = "更改此分组的标签。",
["Menu_Group_Move_TooltipTitle"] = "移动分组",
["Menu_Group_Move_TooltipText"] = "拾起此分组，以便将其移动到新的位置。",
["Menu_Group_Delete_TooltipTitle"] = "删除分组",
["Menu_Group_Delete_TooltipText"] = "彻底删除此分组，并取消所有分类的分配。!!Warning_NoUndo!!",

["Menu_Group_Add_Category_TooltipText"] = "将一个已有分类分配到此分组。",
["Menu_Group_Configure_Category_TooltipText"] = "显示此分类的右键菜单。",
["Menu_Group_New_Category_TooltipTitle"] = "新建分类",
["Menu_Group_New_Category_TooltipText"] = "创建一个新分类并将其分配到此分组。",
["Menu_Group_Move_Category_TooltipText"] = "拾起当前分配到此分组的某个分类，以便将其移动到另一个分组。",
["Menu_Group_Remove_Category_TooltipText"] = "移除当前分配到此分组的某个分类。!!Info_NoDelete!!",
["Menu_Group_Edit_Category_TooltipText"] = "编辑当前分配到此分组的某个分类。",
["Menu_Group_DefaultColor_TooltipTitle"] = "使用默认分组%s颜色",  -- %s = Background/Border
["Menu_Group_DefaultColor_TooltipText"] = "应用设置中定义的分组%s颜色。",  -- %s = Background/Border
["Menu_Group_DefaultSortOrder_TooltipTitle"] = "使用默认排序方式",
["Menu_Group_DefaultSortOrder_TooltipText"] = "应用当前结构的默认排序方式：" .. BS_NEWLINE .. "%s",  -- %s = <Name of default sort order>
["Menu_Group_HideGroup"] = "隐藏分组",
["Menu_Group_HideGroup_TooltipText"] = "除非开启“显示已隐藏项”，否则不显示此分组。",
["Menu_Group_HideStockBadge"] = "隐藏库存标记",
["Menu_Group_HideStockBadge_TooltipText"] = "不为此分组显示库存变化标记(新增/增加/减少)。",
["Menu_Group_Settings_TooltipTitle"] = "分组设置",
["Menu_Group_Settings_TooltipText"] = "管理分组专属选项，包括背景和边框颜色。",
["Menu_Group_Color_TooltipTitle"] = "分组%s颜色",  -- %s = Background/Border
["Menu_Group_Color_TooltipText"] = "设置此分组的%s。",  -- %s = background/border
["Menu_Group_SortOrder_TooltipTitle"] = "分组排序方式",
["Menu_Group_SortOrder_TooltipText"] = "更改此分组内物品的排序方式。",

-- Item Menu.
["Menu_Item_AssignToCategory"] = "直接分配",
["Menu_Item_AssignToCategory_TooltipTitle"] = "直接分配到分类",
["Menu_Item_AssignToCategory_TooltipText"] = "将此物品的ID分配到一个或多个自定义分类(而不是使用规则函数)。",
["Menu_Item_Information_TooltipTitle"] = "物品信息",
["Menu_Item_Information_TooltipText"] = "查看此物品的属性详情，并打开物品信息窗口。",
["Menu_Item_Information_Submenu_TooltipText"] = "点击打开物品信息窗口。",
["Menu_Item_Manage_TooltipTitle"] = "管理物品",
["Menu_Item_Manage_TooltipText"] = "Bagshui 专属的物品操作。",
["Menu_Item_MatchedCategories"] = "已匹配",
["Menu_Item_MatchedCategories_TooltipTitle"] = "已匹配的分类",
["Menu_Item_MatchedCategories_TooltipText"] = "匹配此物品的所有分类列表，按顺序排列。",
["Menu_Item_MatchedCategory_TooltipText"] = "点击编辑。",
["Menu_Item_Move_TooltipText"] = "拾起此物品，以便将其直接分配到新的分类。",
["Menu_Item_RemoveFromEquippedGear"] = "从已装备中移除",
["Menu_Item_RemoveFromEquippedGear_TooltipText"] = "将此物品从你已装备过的装备列表中移除(即 Equipped() 规则将不再匹配它)。",
["Menu_Item_ResetStockState"] = "重置库存状态",
["Menu_Item_ResetStockState_TooltipText"] = "清除此物品的新增/增加/减少状态。",

-- Item Stock State.
["StockState"] = "库存状态",
["StockLastChange"] = "上次变化",
-- BS_ITEM_STOCK_STATE localizations as `Stock_<BS_ITEM_STOCK_STATE value>`.
["Stock_New"] = "!!New!!",
["Stock_Up"] = "增加",
["Stock_Down"] = "减少",
["Stock_"] = "无",

-- Item Information window title.
["BagshuiItemInformation"] = "Bagshui 物品信息",



-- ### Categories and Groups ###

-- Templates.
["Suffix_Items"] = "%s物品",
["Suffix_Potions"] = "%s药水",
["Suffix_Reagents"] = "%s材料",

-- Special categories.
["TurtleWoWGlyphs"] = "雕文(Turtle WoW)",
["SoulboundGear"] = "已绑定装备",

-- Name/Tooltip identifiers sed to categorize items using strings that appear
-- in their names or tooltips.
-- Using [[bracket quoting]] to avoid the need for any Lua pattern escapes (like \.).
-- Any Lua patterns must be wrapped in slashes per the normal Bagshui string
-- handling rules (see TooltipIdentifier_PotionHealth for an example).
["NameIdentifier_AntiVenom"] = [[抗毒药剂]],
["NameIdentifier_Bandage"] = [[绷带]],
["NameIdentifier_Elixir"] = [[药剂]],
["NameIdentifier_Firestone"] = [[火焰石]],
["NameIdentifier_FrostOil"] = [[冰霜之油]],
["NameIdentifier_HallowedWand"] = [[圣洁魔杖]],
["NameIdentifier_Idol"] = [[神像]],
["NameIdentifier_Juju"] = [[魂能]],
["NameIdentifier_ManaOil"] = [[法力之油]],
["NameIdentifier_Poison"] = [[毒药]],
["NameIdentifier_Potion"] = [[药水]],
-- zhCN scroll names are like "力量卷轴 IX", not a "卷轴：" prefix.
["NameIdentifier_Scroll"] = [[卷轴]],
["NameIdentifier_ShadowOil"] = [[暗影之油]],
["NameIdentifier_SharpeningStone"] = [[磨刀石]],
["NameIdentifier_Soulstone"] = [[灵魂石]],
["NameIdentifier_Spellstone"] = [[法术石]],
["NameIdentifier_TurtleWoWGlyph"] = [[雕文]],  -- Used along with type('Key') to identify Turtle WoW glyphs.
["NameIdentifier_Weightstone"] = [[平衡石]],
["NameIdentifier_WizardOil"] = [[巫师之油]],

["TooltipIdentifier_Buff_AlsoIncreases"] = [[同时提高你的]],
["TooltipIdentifier_Buff_WellFed"] = [[进食充分]],
["TooltipIdentifier_Companion"] = [[点击右键召唤或解散]],
["TooltipIdentifier_Drink"] = [[喝水时必须保持坐姿]],
["TooltipIdentifier_Food"] = [[进食时必须保持坐姿]],
["TooltipIdentifier_Mount"] = [[使用：召唤或解散可骑乘的]],
["TooltipIdentifier_MountAQ40"] = [[使用：发出高频声波]],
["TooltipIdentifier_PotionHealth"] = [[/恢复[%d.]+[^%d]+[%d.]+点生命/]],  -- Wrap in slashes to activate pattern matching.
["TooltipIdentifier_PotionMana"] = [[/恢复[%d.]+[^%d]+[%d.]+点法力/]],  -- Wrap in slashes to activate pattern matching.
["TooltipIdentifier_QuestItem"] = [[任务物品]],

-- Tooltip parsing -- extracting data from tooltips.
["TooltipParse_Charges"] = [[^(%d+)次$]],  -- MUST contain the (%d) capture group.
-- ItemInfo:IsUsable() Tooltip parsing
["TooltipParse_AlreadyKnown"] = _G.ITEM_SPELL_KNOWN,
["TooltipParse_RequiresLevel"] = [[需要([%A%s]-)%（(%d+)%）]],  -- Aiming to match "需要钓鱼（10）" and pull out "钓鱼", "10". (Could probably use _G.ITEM_MIN_SKILL and replace its placeholders with the capture groups.)


-- Shared Category/Group Names.
["ActiveQuest"] = "进行中的任务",
["Bandages"] = "绷带",
["BindOnEquip"] = "装备后绑定",
["Books"] = "书籍",
["Buffs"] = "增益",
["Companions"] = "伙伴",
["Consumables"] = "消耗品",
["Disguises"] = "伪装",
["Drink"] = "饮料",
["Elixirs"] = "药剂",
["Empty"] = "空",
["EmptySlots"] = "空栏位",
["Equipment"] = "装备",
["EquippedGear"] = "已装备的装备",
["FirstAid"] = "急救",
["Food"] = "食物",
["FoodBuffs"] = "食物增益",
["Gear"] = "装备",
["Glyphs"] = "雕文",
["Gray"] = "灰色",  -- Used in "Gray Items"
["Health"] = "生命",
["Items"] = "物品",
["Juju"] = "魂能",
["Keys"] = "钥匙",
["Mana"] = "法力",
["Misc"] = "杂项",
["Mounts"] = "坐骑",
["MyGear"] = "我的装备",
["Other"] = "其他",
["Potions"] = "药水",
["PotionsSlashRunes"] = "药水/符文",
["ProfessionBags"] = "专业背包",
["ProfessionCrafts"] = "专业制作物",
["ProfessionReagents"] = "专业材料",
["Reagents"] = "材料",
["Recipes"] = "配方",
["Runes"] = "符文",
["Scrolls"] = "卷轴",
["Teleports"] = "传送",
["Tools"] = "工具",
["TradeTools"] = "专业工具",
["Uncategorized"] = "未分类",
["WeaponBuffs"] = "武器增强",
["Weapons"] = "武器",

-- Category names that are different from group names.
["Category_ProfessionBags"] = "专业背包(已学习)",
["Category_ProfessionBagsAll"] = "专业背包(全部)",
["Category_ProfessionCrafts"] = "专业制作物(已学配方)",
["Category_ProfessionReagents"] = "专业材料(已学配方)",




-- ### Sort Orders ###

["SortOrder_Default_MinLevel"] = "标准(含最低等级)",
["SortOrder_Default_MinLevelNameRev"] = "标准(含最低等级) - 物品名称反向",
["SortOrder_Default_NameRev"] = "标准 - 物品名称反向",
["SortOrder_Default"] = "标准",
["SortOrder_Manual"] = "手动(仅按背包/栏位编号)",




-- ### Profiles ###
["ManageProfile"] = "管理方案",
-- Profile types.
["Profile_Design"] = "外观",
["Profile_Structure"] = "结构",
["Profile_Abbrev_Design"] = "外观",
["Profile_Abbrev_Structure"] = "结构",

["Object_UsedInProfiles"] = "用于方案：",
["Object_UsedByCharacters"] = "使用此项的角色：",
["Object_ProfileUses"] = "方案使用：",


-- ### Object List/Manager/Editor ###

-- General.
["ObjectList_ActionNotAllowed"] = "%s功能对%s不可用。",  -- "<Creation/Editing/Deletion> is not allowed for <objectNamePlural>"
["ObjectList_ShowObjectUses"] = "显示%s用途",
["ObjectList_ShowProfileUses"] = "显示方案用途",
["ObjectList_ImportSuccessful"] = "已导入%s“%s”。",  -- "Imported <objectType> '<objectName>'"
["ObjectList_ImportReusingExisting"] = "已跳过导入%s“%s”，因为它与“%s”完全相同。",  -- "Skipping import of <objectType> '<objectName>' since it's identical to '<existingObjectName'."

-- Default column names.
["ObjectManager_Column_Name"] = "!!Name!!",
["ObjectManager_Column_InUse"] = "已使用",
["ObjectManager_Column_Realm"] = "服务器",
["ObjectManager_Column_Sequence"] = "顺序",
["ObjectManager_Column_Source"] = "来源",
["ObjectManager_Column_LastInventoryUpdate"] = "物品栏更新时间",

-- The third %s after the ? is used to insert additional text if the ObjectManager's deletePromptExtraInfo property is set.
["ObjectManager_DeletePrompt"] = "要删除以下%s吗？%s%s!!Warning_NoUndo!!",  -- "Delete category '<category name>'?"
["ObjectManager_DeleteForPrompt"] = "要删除%s：“%s”吗？%s!!Warning_NoUndo!!",  -- "Delete character data for '<character name>'?"

["ObjectEditor_UnsavedPrompt"] = "关闭前是否保存对%s“%s”的更改？",   -- "Save changes to <objectType> '<objectName>' before closing?"
["ObjectEditor_RequiredField"] = "%s为必填项",

-- Object editor prompt when adding a new item to an item list.
["ItemList_NewPrompt"] = "要添加的物品标识：" .. BS_NEWLINE .. GRAY_FONT_COLOR_CODE .. "可以是物品ID、物品链接/物品字符串，或数据库网址。" .. BS_NEWLINE .. "多个标识可用空格、制表符、逗号、分号或换行任意组合分隔。" .. FONT_COLOR_CODE_CLOSE,
["ItemList_CopyPrompt"] = "物品ID：",



-- ### Managers and Windows ###

-- Category Manager/Editor.
["CategoryManager"] = "Bagshui 分类管理器",  -- Window title.
["CategoryEditor"] = "编辑分类",  -- Window title.
["CategoryEditor_Field_name"] = "!!Name!!",
["CategoryEditor_Field_nameSort"] = "名称(排序用)",
["CategoryEditor_Field_nameSort_TooltipText"] = "覆盖排序方式中使用的分类名称，而不改变其显示名称。",
["CategoryEditor_Field_sequence"] = "顺序",
["CategoryEditor_Field_sequence_TooltipText"] = "控制分类的判定顺序。" .. BS_NEWLINE .. "0 = 最先，100 = 最后",
["CategoryEditor_Field_class"] = "职业",
["CategoryEditor_Field_rule"] = "规则",
["CategoryEditor_Field_rule_TooltipText"] = "一个或多个 Bagshui 规则函数，可用 and/or/not 关键字组合，也可用括号分组。详见文档。",
["CategoryEditor_Field_list"] = "直接分配",
["CategoryEditor_Field_list_TooltipText"] = "直接分配到此分类的物品列表(而不是使用规则函数)。",
-- Button tooltips.
["CategoryEditor_AddRuleFunction"] = "添加规则函数",
["CategoryEditor_RuleFunctionWiki"] = "规则帮助",
["CategoryEditor_RuleValidation_Validate"] = "验证规则",
["CategoryEditor_RuleValidation_Valid"] = "规则有效",
["CategoryEditor_RuleValidation_Invalid"] = "规则验证错误：",



-- Character Data Manager.
["CharacterDataManager"] = "Bagshui 角色数据管理器",
["CharacterDataManager_DeleteInfo"] = "这只会移除物品栏数据；不会影响方案。",


-- Sort Order Editor.
["SortOrderManager"] = "Bagshui 排序方式管理器",  -- Window title.
["SortOrderEditor"] = "编辑排序方式",  -- Window title.
["SortOrderEditor_Field_name"] = "!!Name!!",
["SortOrderEditor_Field_fields"] = "字段",
-- Button tooltips.
["SortOrderEditor_NormalWordOrder"] = "正常词序",
["SortOrderEditor_ReverseWordOrder"] = "反向词序",



-- Profile Manager/Editor.
["ProfileManager"] = "Bagshui 方案管理器",  -- Window title.
["ProfileManager_ReplaceTooltipTitle"] = "替换%s",  -- "Replace Design"
["ProfileManager_ReplaceTooltipText"] = "将%s配置从“%s”方案复制到“%s”方案。" ,  -- "Copy the Design configuration from the 'Source' profile to 'Target'."
["ProfileManager_ReplacePrompt"] = "要替换%s配置吗？目标方案：“%s”，来源方案：“%s”。!!Warning_NoUndo!!",  -- "Replace the Design configuration of the 'Target' profile with that of 'Source'?"

["ProfileEditor"] = "编辑方案",  -- Window title.
["ProfileEditor_Field_name"] = "!!Name!!",
["ProfileEditor_FooterText"] = "方案通过设置菜单和编辑模式进行编辑。",


-- Share (Import/Export).
["ShareManager"] = "Bagshui 导入/导出",
["ShareManager_ExportPrompt"] = "按 Ctrl+C 复制。",
["ShareManager_ExportEncodeCheckbox"] = "优化以便分享",
["ShareManager_ExportEncodeExplanation"] = "请分享优化后(压缩/编码)的版本，这样几乎可以保证它能在各种网络传输中完好无损。如需查看分享的内容，请将未优化的版本复制到文本编辑器中。",
["ShareManager_ImportPrompt"] = "请使用 Ctrl+V 粘贴要导入的 Bagshui 数据。",


-- Catalog (Account-wide search).
["CatalogManager"] = "Bagshui 目录",
["CatalogManager_SearchBoxPlaceholder"] = "搜索账号通用物品栏",
["CatalogManager_KnownCharacters"] = "正在显示以下角色的物品栏：",


-- Game Report
["GameReport"] = "Bagshui 游戏环境报告",
["GameReport_Instructions"] = "请将下方文本复制并粘贴到错误报告的“环境”部分。",


-- ### Rule Function Templates ###
-- See `Rules:AddRuleExamplesFromLocalization() for details.

-- Shared values for rule function !!placeholders!! that will be replaced when the localization is loaded.
["RuleFunction_LuaStringPatternsSupported"] = BS_NEWLINE .. GRAY_FONT_COLOR_CODE .. '支持 Lua 字符串模式，用斜杠包裹即可，如 "/模式/"。' .. FONT_COLOR_CODE_CLOSE,
["RuleFunction_PT_CaseSensitiveParameters"] = BS_NEWLINE .. GRAY_FONT_COLOR_CODE .. "集合名称区分大小写。" .. FONT_COLOR_CODE_CLOSE,

-- DO NOT Localize rule function names (ActiveQuest(), BindsOnEquip(), etc. as they are NOT localized in the rule environment).

["RuleFunction_ActiveQuest_Example1"] = 'ActiveQuest()',
["RuleFunction_ActiveQuest_ExampleDescription1"] = "检查物品是否为当前角色任务日志中的任务目标。",

["RuleFunction_Bag_GenericDescription"] = "检查物品是否位于指定编号的背包中",
["RuleFunction_Bag_ExampleDescription"] = "检查物品是否位于指定编号的背包中(编号 %d 对应第 %d 个容器，位于%s)",  -- "(0 is container #1 in Bags)"
["RuleFunction_Bag_ExampleExtra1"] = 'Bag(num1, num2, numN)',
["RuleFunction_Bag_ExampleDescriptionExtra1"] = "检查物品是否位于任意一个指定编号的背包中。",

["RuleFunction_BagType_GenericDescription"] = "检查物品是否位于指定类型的背包中。",
["RuleFunction_BagType_ExampleDescription"] = "检查物品是否位于类型为“%s”的背包中。",
["RuleFunction_BagType_ExampleExtra1"] = 'BagType(ProfessionBag)',
["RuleFunction_BagType_ExampleDescriptionExtra1"] = "检查物品是否位于当前角色某项专业所对应的专用背包中" .. GRAY_FONT_COLOR_CODE .. BS_NEWLINE .. "ProfessionBag 是此功能的特殊触发词，不能加引号。" .. FONT_COLOR_CODE_CLOSE,
["RuleFunction_BagType_ExampleExtra2"] = 'BagType(AllProfessionBags)',
["RuleFunction_BagType_ExampleDescriptionExtra2"] = "检查物品是否位于任意专业专用容器中。" .. GRAY_FONT_COLOR_CODE .. BS_NEWLINE .. "AllProfessionBags 是此功能的特殊触发词，不能加引号。" .. FONT_COLOR_CODE_CLOSE,
["RuleFunction_BagType_ExampleExtra3"] = 'BagType("type1", "type2", "typeN")',
["RuleFunction_BagType_ExampleDescriptionExtra3"] = '检查物品是否位于任意一个指定类型的背包中。',

["RuleFunction_BindsOnEquip_Example1"] = 'BindsOnEquip()',
["RuleFunction_BindsOnEquip_ExampleDescription1"] = string.format("检查物品是否%s", string.lower(_G.ITEM_BIND_ON_EQUIP)),

["RuleFunction_CharacterLevelRange_GenericDescription"] = "根据当前角色的等级检查物品是否可用。",
["RuleFunction_CharacterLevelRange_Example1"] = 'CharacterLevelRange()',
["RuleFunction_CharacterLevelRange_ExampleDescription1"] = "检查物品是否恰好在当前角色等级可用。",
["RuleFunction_CharacterLevelRange_Example2"] = 'CharacterLevelRange(levelsBelowOrAbove)',
["RuleFunction_CharacterLevelRange_ExampleDescription2"] = "检查物品是否在当前角色等级上下 <levelsBelowOrAbove> 级范围内可用。",
["RuleFunction_CharacterLevelRange_Example3"] = 'CharacterLevelRange(levelsBelow, levelsAbove)',
["RuleFunction_CharacterLevelRange_ExampleDescription3"] = "检查物品是否在当前角色等级以下 <below> 级到以上 <above> 级的范围内可用。",

["RuleFunction_Count_GenericDescription"] = "检查堆叠中的物品是否达到指定数量。",
["RuleFunction_Count_Example1"] = 'Count(number)',
["RuleFunction_Count_ExampleDescription1"] = "检查堆叠中的该物品是否至少有 <number> 个。",
["RuleFunction_Count_Example2"] = 'Count(min, max)',
["RuleFunction_Count_ExampleDescription2"] = "检查堆叠中的该物品是否有 <min> 到 <max> 个。",

["RuleFunction_EmptySlot_Example1"] = 'EmptySlot()',
["RuleFunction_EmptySlot_ExampleDescription1"] = "检查背包栏位中是否没有物品。",

["RuleFunction_EquipLocation_GenericDescription"] = "检查物品是否可以装备在指定栏位。",
["RuleFunction_EquipLocation_ExampleDescription"] = "检查物品是否可以装备在%s栏位。",
["RuleFunction_EquipLocation_ExampleExtra1"] = 'EquipLocation("Slot1", "Slot2", "SlotN")',
["RuleFunction_EquipLocation_ExampleDescriptionExtra1"] = "检查物品是否可以装备在任意一个指定栏位。",

["RuleFunction_Equipped_Example1"] = 'Equipped()',
["RuleFunction_Equipped_ExampleDescription1"] = "检查物品是否曾被装备过(可用于匹配未绑定的装备)。" .. GRAY_FONT_COLOR_CODE .. BS_NEWLINE .. "也可以传入与 EquipLocation() 相同的参数，只匹配特定的装备栏位。" .. FONT_COLOR_CODE_CLOSE,

["RuleFunction_Id_GenericDescription"] = '检查物品ID是否完全匹配。',
["RuleFunction_Id_Example1"] = 'Id(number)',
["RuleFunction_Id_ExampleDescription1"] = "检查物品ID是否完全匹配。",
["RuleFunction_Id_ExampleExtra1"] = 'Id(id1, id2, idN)',
["RuleFunction_Id_ExampleDescriptionExtra1"] = "检查物品ID是否匹配任意一个指定参数。",

["RuleFunction_ItemString_GenericDescription"] = "检查物品字符串是否匹配(用于匹配特定的附魔或后缀ID)。",
["RuleFunction_ItemString_Example1"] = 'ItemString(number)',
["RuleFunction_ItemString_ExampleDescription1"] = RED_FONT_COLOR_CODE .. "请改用 Id(itemId)。" .. FONT_COLOR_CODE_CLOSE .. BS_NEWLINE .. "检查物品字符串是否以 'item:<itemId>:' 开头",
["RuleFunction_ItemString_Example2"] = 'ItemString("item:number")',
["RuleFunction_ItemString_ExampleDescription2"] = RED_FONT_COLOR_CODE .. "请改用 Id(itemId)。" .. FONT_COLOR_CODE_CLOSE .. BS_NEWLINE .. "检查物品字符串是否以 'item:<itemId>:' 开头(item: 前缀可省略)。",
["RuleFunction_ItemString_Example3"] = 'ItemString("item:number:number")',
["RuleFunction_ItemString_ExampleDescription3"] = "检查物品字符串是否以 'item:<itemId>:<enchantId>:' 开头(item: 前缀可省略)。",
["RuleFunction_ItemString_Example4"] = 'ItemString("item:number:number:number")',
["RuleFunction_ItemString_ExampleDescription4"] = "检查物品字符串是否以 'item:<itemId>:<enchantId>:<suffixId>:' 开头(item: 前缀可省略)。",
["RuleFunction_ItemString_ExampleExtra1"] = 'ItemString(param1, param2, paramN)',
["RuleFunction_ItemString_ExampleDescriptionExtra1"] = '检查物品字符串是否匹配任意一个指定参数。',

["RuleFunction_Location_GenericDescription"] = "检查物品是否存放在特定位置(背包、银行等)",
["RuleFunction_Location_ExampleDescription"] = "检查物品是否在你的%s中",
["RuleFunction_Location_ExampleExtra1"] = 'Location("loc1", "loc2", "locN")',
["RuleFunction_Location_ExampleDescriptionExtra1"] = "检查物品是否存放在任意一个指定位置。",

["RuleFunction_MinLevel_GenericDescription"] = "根据指定等级检查物品是否可用。",
["RuleFunction_MinLevel_Example1"] = 'MinLevel(level)',
["RuleFunction_MinLevel_ExampleDescription1"] = "检查物品是否在 <level> 级或更高等级可用。",
["RuleFunction_MinLevel_Example2"] = 'MinLevel(min, max)',
["RuleFunction_MinLevel_ExampleDescription2"] = "检查物品是否在 <min> 到 <max> 级可用。",

["RuleFunction_Name_GenericDescription"] = "检查物品名称是否包含指定字符串。!!RuleFunction_LuaStringPatternsSupported!!",
["RuleFunction_Name_Example1"] = 'Name("string")',
["RuleFunction_Name_ExampleDescription1"] = "检查物品名称是否包含指定字符串。!!RuleFunction_LuaStringPatternsSupported!!",
["RuleFunction_Name_ExampleExtra1"] = 'Name("string1", "string2", "stringN")',
["RuleFunction_Name_ExampleDescriptionExtra1"] = "检查物品名称是否包含任意一个指定字符串。!!RuleFunction_LuaStringPatternsSupported!!",

["RuleFunction_NameExact_GenericDescription"] = "检查物品名称是否与指定字符串完全一致。",
["RuleFunction_NameExact_Example1"] = 'NameExact("string")',
["RuleFunction_NameExact_ExampleDescription1"] = "检查物品名称是否与指定字符串完全一致。",
["RuleFunction_NameExact_ExampleExtra1"] = 'NameExact("string1", "string2", "stringN")',
["RuleFunction_NameExact_ExampleDescriptionExtra1"] = "检查物品名称是否与任意一个指定字符串完全一致。",

["RuleFunction_Outfit_GenericDescription"] = "检查物品是否属于 Outfitter 或 ItemRack 的套装。",
["RuleFunction_Outfit_Example1"] = 'Outfit()',
["RuleFunction_Outfit_ExampleDescription1"] = "检查物品是否属于任意 Outfitter 或 ItemRack 套装。",
["RuleFunction_Outfit_Example2"] = 'Outfit("Outfit Name")',
["RuleFunction_Outfit_ExampleDescription2"] = "检查物品是否属于指定的 Outfitter 或 ItemRack 套装。",
["RuleFunction_Outfit_ExampleExtra1"] = 'Outfit("outfit1", "outfit2", "outfitN")',
["RuleFunction_Outfit_ExampleDescriptionExtra1"] = "检查物品是否属于任意一个指定的 Outfitter 或 ItemRack 套装。",

["RuleFunction_PeriodicTable_GenericDescription"] = "检查物品是否属于某个 PeriodicTable 集合。!!RuleFunction_PT_CaseSensitiveParameters!!",
["RuleFunction_PeriodicTable_ExampleDescription"] = "检查物品是否属于 PeriodicTable 集合“%s”。!!RuleFunction_PT_CaseSensitiveParameters!!",
["RuleFunction_PeriodicTable_ExampleExtra1"] = 'PeriodicTable("set1", "set2", "setN")',
["RuleFunction_PeriodicTable_ExampleDescriptionExtra1"] = "检查物品是否属于任意一个指定的 PeriodicTable 集合。!!RuleFunction_PT_CaseSensitiveParameters!!",

["RuleFunction_ProfessionCraft_GenericDescription"] = "检查物品是否可由当前角色的专业制作(仅限已学配方)。",
["RuleFunction_ProfessionCraft_Example1"] = 'ProfessionCraft()',
["RuleFunction_ProfessionCraft_ExampleDescription1"] = "检查物品是否可由当前角色的任意专业制作(仅限已学配方)。",
["RuleFunction_ProfessionCraft_Example2"] = 'ProfessionCraft("Profession Name")',
["RuleFunction_ProfessionCraft_ExampleDescription2"] = "检查物品是否可由当前角色的指定专业制作(仅限已学配方)。",
["RuleFunction_ProfessionCraft_ExampleExtra1"] = 'ProfessionCraft("Profession1", "Profession2", "ProfessionN")',
["RuleFunction_ProfessionCraft_ExampleDescriptionExtra1"] = "检查物品是否可由当前角色的任意一个指定专业制作(仅限已学配方)。",

["RuleFunction_ProfessionReagent_GenericDescription"] = "检查物品是否为当前角色专业制作所需的材料(仅限已学配方)。",
["RuleFunction_ProfessionReagent_Example1"] = 'ProfessionReagent()',
["RuleFunction_ProfessionReagent_ExampleDescription1"] = "检查物品是否为当前角色任意专业制作所需的材料(仅限已学配方)。",
["RuleFunction_ProfessionReagent_Example2"] = 'ProfessionReagent("Profession Name")',
["RuleFunction_ProfessionReagent_ExampleDescription2"] = "检查物品是否为当前角色指定专业制作所需的材料(仅限已学配方)。",
["RuleFunction_ProfessionReagent_ExampleExtra1"] = 'ProfessionReagent("Profession1", "Profession2", "ProfessionN")',
["RuleFunction_ProfessionReagent_ExampleDescriptionExtra1"] = "检查物品是否为当前角色任意一个指定专业制作所需的材料(仅限已学配方)。",

["RuleFunction_Quality_GenericDescription"] = "检查物品是否为指定品质。",
["RuleFunction_Quality_ExampleDescription"] = "检查物品是否为%s品质。",
["RuleFunction_Quality_ExampleExtra1"] = 'Quality(qual1, qual2, qualN)',
["RuleFunction_Quality_ExampleDescriptionExtra1"] = "检查物品是否为任意一个指定品质。",

["RuleFunction_RequiresClass_GenericDescription"] = "检查物品是否可被指定职业使用。",
["RuleFunction_RequiresClass_ExampleDescription"] = "检查物品是否可被%s职业使用。",
["RuleFunction_RequiresClass_ExampleExtra1"] = 'RequiresClass("class1", "class2", "classN")',
["RuleFunction_RequiresClass_ExampleDescriptionExtra1"] = "检查物品是否可被任意一个指定职业使用。",

["RuleFunction_Soulbound_Example1"] = 'Soulbound()',
["RuleFunction_Soulbound_ExampleDescription1"] = "检查物品是否已绑定。",

["RuleFunction_Stacks_Example1"] = 'Stacks()',
["RuleFunction_Stacks_ExampleDescription1"] = "检查物品是否可以堆叠。",

["RuleFunction_Subtype_GenericDescription"] = "检查物品是否为指定子类型",
["RuleFunction_Subtype_ExampleDescription"] = "检查物品的子类型是否为“%s”。",
["RuleFunction_Subtype_ExampleExtra1"] = 'Subtype("type1", "type2", "typeN")',
["RuleFunction_Subtype_ExampleDescriptionExtra1"] = "检查物品是否为任意一个指定子类型。",

["RuleFunction_Tooltip_GenericDescription"] = "检查提示信息是否包含指定字符串。!!RuleFunction_LuaStringPatternsSupported!!",
["RuleFunction_Tooltip_Example1"] = 'Tooltip("string")',
["RuleFunction_Tooltip_ExampleDescription1"] = "检查物品提示信息是否包含指定字符串。!!RuleFunction_LuaStringPatternsSupported!!",
["RuleFunction_Tooltip_ExampleExtra1"] = 'Tooltip("string1", "string2", "stringN")',
["RuleFunction_Tooltip_ExampleDescriptionExtra1"] = "检查提示信息是否包含任意一个指定字符串。!!RuleFunction_LuaStringPatternsSupported!!",

["RuleFunction_Type_GenericDescription"] = "检查物品是否为指定类型。",
["RuleFunction_Type_ExampleDescription"] = "检查物品的类型是否为“%s”。",
["RuleFunction_Type_ExampleExtra1"] = 'Type("type1", "type2", "typeN")',
["RuleFunction_Type_ExampleDescriptionExtra1"] = "检查物品是否为任意一个指定类型。",

["RuleFunction_Usable_Example1"] = 'Usable()',
["RuleFunction_Usable_ExampleDescription1"] = "根据等级、技能和专业，检查物品是否可被当前角色使用。",

["RuleFunction_Wishlist_Example1"] = 'Wishlist()',
["RuleFunction_Wishlist_ExampleDescription1"] = "检查物品是否在 AtlasLoot 愿望清单中。",


-- ### Tips/Help ###
["BagshuiTooltipIntro"] = "显示 Bagshui 信息提示",


-- ### Errors/Warnings ###

["Error"] = "错误",
["Error_AddonDependency"] = "%s 未安装或未启用。",
["Error_CategoryEvaluation"] = "%s：%s",  -- "<Category Name>: <Error Message>"
["Error_DuplicateName"] = "已存在%s“%s”。",  -- "There is already a <Object Type> named <Name>."
["Error_GroupNotFound"] = "找不到分组ID %s。",
["Error_HearthstoneNotFound"] = "找不到炉石。",
["Error_ImportInvalidFormat"] = "导入失败：数据格式不符合预期。",
["Error_ImportVersionTooNew"] = "导入失败：请升级到最新版本的 Bagshui。",
["Error_ItemCategoryUnknown"] = "!未知!(这不应该发生)。",  -- Placed in the tooltip if the item doesn't have a category.
["Error_RestackFailed"] = "重新堆叠失败：%s",
["Error_SaveFailed"] = "%s 无法保存：%s",
["Error_Suffix_Retrying"] = "%s；正在重试…",  -- Appended to the end of an error message when an action has failed but is being attempted again.

["Info_NoDelete"] = BS_NEWLINE .. GRAY_FONT_COLOR_CODE .. "不会删除该分类。" .. FONT_COLOR_CODE_CLOSE,

["Warning_NoUndo"] = BS_NEWLINE .. RED_FONT_COLOR_CODE .. "此操作无法撤销！" .. FONT_COLOR_CODE_CLOSE,
["Warning_RuleFunctionOverwrite"] = "正在覆盖已有的规则环境函数 %s()",
["Warning_BuiltinRuleFunctionCollision"] = "第三方规则函数/别名 %s() 未被加载，因为它与 Bagshui 内置规则函数的名称/别名冲突",

["Compat_ReloadUIPrompt"] = "需要重新加载界面。",
["Compat_pfUIBags"] = "强烈建议禁用 pfUI 的背包模块，以免出现多个银行窗口。",
["Compat_pfUIBagsInfo"] = "如果你改变主意，可以在 pfUI 配置 > 组件 > 模块 中管理 pfUI 背包模块。",
["Compat_tDFAllInOneBags"] = "如果你想使用 Bagshui 作为默认背包，建议禁用 tDF 的一体化背包模块。",
["Compat_tDFAllInOneBagsInfo"] = "如果你改变主意，可以在 tDF 选项中管理 tDF 一体化背包模块。",

-- Rule function errors.
["Error_RuleFunctionInvalid"] = '“%s”不是有效的规则函数 -- 如果它是用作参数，请像 Function("parameter") 这样为其加上引号',
["Error_RuleVariablePropertyInvalid"] = "“%s”不是有效的 %s 属性",
["Error_RuleExecution"] = "规则函数 %s 出错：%s",
["Error_RuleNoArguments"] = "至少需要一个参数，但未提供任何参数",
["Error_RuleNilArgument"] = "无效的参数 %s：不允许为 nil",
["Error_RuleInvalidArgument"] = "无效的参数 %s：“%s”是 %s，应为 %s",
["Error_RuleInvalidArgumentType"] = "%s 不是有效的参数类型；允许的参数类型有：%s",
["Error_RuleTooManyArguments"] = "规则函数最多支持 50 个参数。若要使用更多参数，请再添加一次对 %s 的调用，并用 'or' 连接，如：or %s(param1, param2, etc)",

["Error_Rule_ItemLevelStat"] = "原版魔兽世界没有物品等级(ilvl)，因此无法使用 ItemLevelStat()。",
["Error_Rule_ItemStat"] = "目前不支持 ItemStat() 和 ItemStatActive()。请尝试使用 Tooltip() 来检查属性。",

-- ### Logging ###

["LogWindowTitle"] = "Bagshui 日志",
["ClearLog"] = "清除日志",
-- Log types.
["Log_Info"] = "信息",
["Log_Warn"] = "警告",
["Log_Error"] = "错误",

-- Settings reset messages.
["SettingReset_LogStart"] = "%s 已重置",
["SettingReset_InvalidValue"] = "值无效",
["SettingReset_Outdated"] = "已过时",




-- ### Help/Misc ###

["BagshuiDataReset"] = "由于版本变更，配置已被重置(旧版本：%s / 新版本：%s)。",
["HowToUrl"] = "魔兽世界无法直接打开网址，请复制此网址(Ctrl+C)并在浏览器中访问。",


-- ### Settings: Tooltips, Scopes, Special ###

-- Automatically generated settings.
["Setting_HookBagTooltipTitle"] = "接管%s",
["Setting_HookBagTooltipText"] = "接管“切换%s”的按键绑定。",
-- Special settings stuff.
["SettingScope_Account"] = "适用于此账号下的所有角色。",
["SettingScope_Character"] = "适用于此角色的所有物品栏窗口。",
["Setting_DisabledBy_HideGroupLabels"] = "× 已禁用，因为当前结构启用了“隐藏分组标签”。",
["Setting_EnabledBy_ColorblindMode"] = "√ 已启用，因为色盲模式已开启。",
["Setting_Profile_SetAllHint"] = "Shift+点击可用于所有方案类型。",
["Setting_Reset_TooltipText"] = "重置为默认值：Ctrl+Alt+Shift+点击。",
["Setting_Profile_Use"] = "将其设为当前使用的%s%s方案。",  -- Make this the active Bags Design profile.


-- ### Settings ###
-- Keys are settingName, settingName_TooltipTitle, or settingName_TooltipText.
-- See localization notes in the declaration of `Settings:InitSettingsInfo()` for more information.

["aboutBagshui_TooltipTitle"] = "关于 Bagshui",

["colorblindMode"] = "色盲模式",
["colorblindMode_TooltipText"] = "无论外观设置如何，始终显示物品品质和不可用标记。",

["createNewProfileDesign"] = "复制",
["createNewProfileDesign_TooltipTitle"] = "创建外观方案副本",
["createNewProfileDesign_TooltipText"] = "复制新角色使用的默认方案。",

["createNewProfileStructure"] = "复制",
["createNewProfileStructure_TooltipTitle"] = "创建结构方案副本",
["createNewProfileStructure_TooltipText"] = "复制新角色使用的默认方案。",

["defaultSortOrder"] = "排序方式",
["defaultSortOrder_TooltipTitle"] = "默认排序方式",
["defaultSortOrder_TooltipText"] = "未指定专属排序方式的分组所使用的排序方式。",

["defaultProfileDesign"] = "外观",
["defaultProfileDesign_TooltipTitle"] = "默认外观方案",
["defaultProfileDesign_TooltipText"] = "新角色使用的方案。",

["defaultProfileStructure"] = "结构",
["defaultProfileStructure_TooltipTitle"] = "默认结构方案",
["defaultProfileStructure_TooltipText"] = "新角色使用的方案。",

["windowDoubleClickActions"] = "双击切换",
["windowDoubleClickActions_TooltipText"] = "双击物品栏窗口的空白处可显示/隐藏所有工具栏。" .. BS_NEWLINE .. "Alt+双击可切换位置锁定。",

["globalInfoTooltips"] = "物品信息",
["globalInfoTooltips_TooltipTitle"] = "接管所有物品提示 ",
["globalInfoTooltips_TooltipText"] = "在任何位置(角色窗口、聊天链接等)按住 Alt 时显示 Bagshui 信息提示。",

["groupBackgroundDefault"] = "背景",
["groupBackgroundDefault_TooltipTitle"] = "默认分组背景颜色",
["groupBackgroundDefault_TooltipText"] = "未设置分组专属颜色时使用的背景颜色。",

["groupBorderDefault"] = "边框",
["groupBorderDefault_TooltipTitle"] = "默认分组边框颜色",
["groupBorderDefault_TooltipText"] = "未设置分组专属颜色时使用的边框颜色。",

["groupLabelDefault"] = "标签",
["groupLabelDefault_TooltipTitle"] = "默认分组标签颜色",
["groupLabelDefault_TooltipText"] = "未设置分组专属颜色时使用的标签颜色。",

["groupMargin"] = "外边距",
["groupMargin_TooltipTitle"] = "分组外边距",
["groupMargin_TooltipText"] = "分组之间的间距。",

["groupPadding"] = "内边距",
["groupPadding_TooltipTitle"] = "分组内边距",
["groupPadding_TooltipText"] = "分组边框与其内部物品之间的间距。",

["groupUseSkinColors"] = "使用%s颜色",
["groupUseSkinColors_TooltipTitle"] = "分组使用%s颜色",
["groupUseSkinColors_TooltipText"] = "使用%s的颜色，而不是 Bagshui 的设置。",

["hideGroupLabelsOverride"] = "隐藏分组标签",
["hideGroupLabelsOverride_TooltipText"] = "即使外观中的“分组标签”设置已启用，也不显示分组标签。",

["itemMargin"] = "外边距",
["itemMargin_TooltipTitle"] = "物品外边距",
["itemMargin_TooltipText"] = "物品之间的间距。",

["itemActiveQuestBadges"] = "进行中的任务",
["itemActiveQuestBadges_TooltipTitle"] = "物品栏位进行中任务标记",
["itemActiveQuestBadges_TooltipText"] = "当物品是进行中任务的目标时，在顶部显示一个 ?。",

["itemQualityBadges"] = "!!Quality!!",
["itemQualityBadges_TooltipTitle"] = "物品品质标记",
["itemQualityBadges_TooltipText"] = "在左下角显示表示物品稀有度的图标。",

["itemUsableBadges"] = "不可用",
["itemUsableBadges_TooltipTitle"] = "物品不可用标记",
["itemUsableBadges_TooltipText"] = "在左上角为不可用/已学会的物品显示图标。",

["itemUsableColors"] = "不可用",
["itemUsableColors_TooltipTitle"] = "物品不可用着色",
["itemUsableColors_TooltipText"] = "为不可用/已学会的物品叠加红色/绿色。",

["itemSize"] = "尺寸",
["itemSize_TooltipTitle"] = "物品尺寸",
["itemSize_TooltipText"] = "物品的高度和宽度。",

["itemStockBadges"] = "库存",
["itemStockBadges_TooltipTitle"] = "物品库存标记",
["itemStockBadges_TooltipText"] = "标示物品是新获得的，或数量增加/减少。",

["itemStockChangeExpiration"] = "过期时间",
["itemStockChangeExpiration_TooltipTitle"] = "物品库存标记变化过期时间",
["itemStockChangeExpiration_TooltipText"] = "经过这段时间后，物品将不再被视为已变化(新增/增加/减少)。",

["itemStockBadgeFadeDuration"] = "淡出",
["itemStockBadgeFadeDuration_TooltipTitle"] = "物品库存标记淡出时长",
["itemStockBadgeFadeDuration_TooltipText"] = "库存变化标记(新增/增加/减少)将在过期时间到来前的这段时间开始淡出。",

["profileDesign"] = "方案",
["profileDesign_TooltipTitle"] = "外观方案",
["profileDesign_TooltipText"] = "用于外观(物品栏的显示样式)的方案。",

["profileStructure"] = "方案",
["profileStructure_TooltipTitle"] = "结构方案",
["profileStructure_TooltipText"] = "用于结构(物品栏的组织方式)的方案。",

["replaceBank"] = "替换银行",
["replaceBank_TooltipText"] = "使用 Bagshui 银行代替暴雪银行界面。",

["resetStockState"] = "标记物品为未变化",
["resetStockState_TooltipText"] = "将此物品栏中的所有物品设为不再是新增、增加或减少状态。",

["showBagBar"] = "背包栏",
["showBagBar_TooltipText"] = "在左下角显示背包栏。",

["showFooter"] = "底部工具栏",
["showFooter_TooltipTitle"] = "底部工具栏",
["showFooter_TooltipText"] = "显示底部工具栏。" .. BS_NEWLINE .. LIGHTYELLOW_FONT_COLOR_CODE .. "隐藏后，物品下方的所有内容都将被隐藏，包括背包栏和金钱显示。" .. FONT_COLOR_CODE_CLOSE,

["showGroupLabels"] = "标签",
["showGroupLabels_TooltipTitle"] = "分组标签",
["showGroupLabels_TooltipText"] = "在分组上方显示标签。",

["showHeader"] = "顶部工具栏",
["showHeader_TooltipTitle"] = "顶部工具栏",
["showHeader_TooltipText"] = "显示顶部工具栏。" .. BS_NEWLINE .. LIGHTYELLOW_FONT_COLOR_CODE .. "隐藏后，物品上方的所有内容都将被隐藏，包括关闭按钮，因此你需要通过按键绑定、动作条按钮或宏来关闭窗口。" .. FONT_COLOR_CODE_CLOSE,

["showHearthstone"] = "炉石按钮",
["showHearthstone_TooltipText"] = "显示炉石按钮。" .. BS_NEWLINE .. LIGHTYELLOW_FONT_COLOR_CODE .. "仅适用于背包。" .. FONT_COLOR_CODE_CLOSE,

["showLogWindow_TooltipText"] = "打开 Bagshui 日志窗口。",

["showMoney"] = "金钱",
["showMoney_TooltipText"] = "在右下角显示金钱。",

["stackEmptySlots"] = "堆叠空栏位",
["stackEmptySlots_TooltipTitle"] = "堆叠空栏位",
["stackEmptySlots_TooltipText"] = "将空栏位合并为单个堆叠，点击即可展开(专业背包将单独堆叠)。",

["toolbarButtonColor"] = "图标",
["toolbarButtonColor_TooltipTitle"] = "工具栏图标颜色",
["toolbarButtonColor_TooltipText"] = "此物品栏工具栏图标使用的颜色。",

["toggleBagsWithAuctionHouse"] = "拍卖行",
["toggleBagsWithAuctionHouse_TooltipTitle"] = "随拍卖行开关背包",
["toggleBagsWithAuctionHouse_TooltipText"] = "访问拍卖行时自动打开和关闭背包。",

["toggleBagsWithBankFrame"] = "银行",
["toggleBagsWithBankFrame_TooltipTitle"] = "随银行开关背包",
["toggleBagsWithBankFrame_TooltipText"] = "访问银行时自动打开和关闭背包。",

["toggleBagsWithMailFrame"] = "邮件",
["toggleBagsWithMailFrame_TooltipTitle"] = "随邮件开关背包",
["toggleBagsWithMailFrame_TooltipText"] = "使用邮箱时自动打开和关闭背包。",

["toggleBagsWithTradeFrame"] = "交易",
["toggleBagsWithTradeFrame_TooltipTitle"] = "随交易开关背包",
["toggleBagsWithTradeFrame_TooltipText"] = "与其他玩家交易时自动打开和关闭背包。",

["windowAnchorXPoint"] = "水平",
["windowAnchorXPoint_TooltipTitle"] = "水平锚点",
["windowAnchorXPoint_TooltipText"] = "窗口将从屏幕的此侧边缘向水平方向扩展。",

["windowAnchorYPoint"] = "垂直",
["windowAnchorYPoint_TooltipTitle"] = "垂直锚点",
["windowAnchorYPoint_TooltipText"] = "窗口将从屏幕的此侧边缘向垂直方向扩展。",

["windowBackground"] = "背景",
["windowBackground_TooltipTitle"] = "窗口背景颜色",
["windowBackground_TooltipText"] = "此物品栏窗口背景使用的颜色。",

["windowBorder"] = "边框",
["windowBorder_TooltipTitle"] = "窗口边框颜色",
["windowBorder_TooltipText"] = "此物品栏窗口边框使用的颜色。",

["windowLocked"] = "锁定位置",
["windowLocked_TooltipText"] = "不允许移动此窗口。",

["windowMaxColumns"] = "最大列数",
["windowMaxColumns_TooltipText"] = "窗口宽度上限，以每行物品数量计。",

["windowScale"] = "缩放",
["windowScale_TooltipTitle"] = "窗口缩放",
["windowScale_TooltipText"] = "整个窗口的相对大小。",

["windowUseSkinColors"] = "使用%s颜色",
["windowUseSkinColors_TooltipTitle"] = "窗口使用%s颜色",
["windowUseSkinColors_TooltipText"] = "使用%s的颜色，而不是 Bagshui 的设置。",


})


end)
