--[[--------------------------------------------------------------------------
Atlas, AtlasLoot and AtlasQuest in pfUI's look. The three hang on one window:
Atlas draws the map and the list beside it, AtlasLoot lays its loot table
over the map and its button panel under the window, AtlasQuest opens a
quest column beside it and its quest text over the map.

  * Atlas: the parchment frame art goes for pfUI's backdrop, with a border
    round the map and a panel behind the zone text and list;
  * AtlasLoot: its panel docks under the window, its standalone window
    (/atlasloot) and options get the same backdrop, its menus pfUI's colours;
  * AtlasQuest: its column docks to the window's edge on the side it is set
    to, instead of tucking under the old art's margin.
----------------------------------------------------------------------------]]

local GAP = 4

local function FontStringWithText(frame, text)
  for _, r in ipairs({ frame:GetRegions() }) do
    if r:GetObjectType() == "FontString" and r:GetText() == text then return r end
  end
end

SoloSkin.Register("Atlas", function()
  HookAddonOrVariable("Atlas", function()
    local f = AtlasFrame
    StripTextures(f, nil, "ARTWORK")
    SoloSkin.Backdrop(f)

    local title = FontStringWithText(f, ATLAS_TITLE)
    if title then
      title:ClearAllPoints()
      title:SetPoint("TOP", f, "TOP", 0, -10)
    end
    local version = FontStringWithText(f, ATLAS_VERSION)
    if version then
      version:ClearAllPoints()
      version:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)
    end

    SoloSkin.Frame(f, AtlasMap)
    SoloSkin.Panel(f, 536, -84, -14, 50)

    SoloSkin.Close(AtlasFrameCloseButton, f)
    local lock = AtlasFrameLockButton
    SkinButton(lock)
    lock:SetWidth(15)
    lock:SetHeight(15)
    lock:ClearAllPoints()
    lock:SetPoint("RIGHT", AtlasFrameCloseButton, "LEFT", -6, 0)
    AtlasLockNorm:SetAlpha(0)
    AtlasLockPush:SetAlpha(0)
    lock.icon = lock:CreateTexture(nil, "OVERLAY")
    lock.icon:SetTexture(pfUI.media["img:key"])
    SetAllPointsOffset(lock.icon, lock, 2)
    local function UpdateLock()
      if AtlasOptions and AtlasOptions.AtlasLocked then
        lock.icon:SetVertexColor(1, .82, 0, 1)
      else
        lock.icon:SetVertexColor(.5, .5, .5, 1)
      end
    end
    hooksecurefunc("Atlas_UpdateLock", UpdateLock)
    UpdateLock()

    StripTextures(AtlasScrollBar)
    SoloSkin.Controls(f)

    StripTextures(AtlasOptionsFrame)
    SoloSkin.Backdrop(AtlasOptionsFrame)
    SoloSkin.Controls(AtlasOptionsFrame)
  end)
end)

SoloSkin.Register("AtlasLoot", function()
  HookAddonOrVariable("AtlasLoot", function()
    -- the panel under Atlas
    local panel = AtlasLootPanel
    SoloSkin.Backdrop(panel)
    AtlasLootPanel_Title:Hide()
    local caption = FontStringWithText(panel, "Atlasloot Enhanced")
    if caption then caption:Hide() end
    SoloSkin.Controls(panel)

    local function Dock()
      if AtlasFrame and panel:GetParent() == AtlasFrame then
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", AtlasFrame, "BOTTOMLEFT", 0, -GAP)
        panel:SetPoint("TOPRIGHT", AtlasFrame, "BOTTOMRIGHT", 0, -GAP)
      end
    end
    hooksecurefunc("AtlasLoot_SetupForAtlas", Dock)
    Dock()

    -- the loot table over the map
    local items = AtlasLootItemsFrame
    SoloSkin.Close(AtlasLootItemsFrame_CloseButton, items)
    for i = 1, 30 do
      local icon = getglobal("AtlasLootItem_" .. i .. "_Icon")
      if icon then icon:SetTexCoord(.08, .92, .08, .92) end
      icon = getglobal("AtlasLootMenuItem_" .. i .. "_Icon")
      if icon then icon:SetTexCoord(.08, .92, .08, .92) end
    end
    SoloSkin.Controls(items)
    SoloSkin.Controls(AtlasLootInfo)

    -- the standalone window
    local default = AtlasLootDefaultFrame
    SoloSkin.Backdrop(default)
    AtlasLootDefaultFrameHeader:SetAlpha(0)
    local title = FontStringWithText(default, ATLASLOOT_VERSION)
    if title then
      title:ClearAllPoints()
      title:SetPoint("TOP", default, "TOP", 0, -8)
    end
    SoloSkin.Close(AtlasLootDefaultFrame_CloseButton, default)
    AtlasLootDefaultFrame_LootBackground_Back:SetTexture(0, 0, 0, .5)
    SoloSkin.Frame(AtlasLootDefaultFrame_LootBackground, AtlasLootDefaultFrame_LootBackground)
    SoloSkin.Controls(default)

    SoloSkin.Backdrop(AtlasLootOptionsFrame)
    AtlasLootOptionsFrameHeader:SetAlpha(0)
    SoloSkin.Controls(AtlasLootOptionsFrame)

    SoloSkin.Dewdrop()
  end)
end)

SoloSkin.Register("AtlasQuest", function()
  HookAddonOrVariable("AtlasQuest", function()
    local column = AtlasQuestFrame
    SoloSkin.Backdrop(column)
    SoloSkin.Controls(column)

    local function Dock()
      if not AtlasFrame or column:GetParent() ~= AtlasFrame then return end
      column:ClearAllPoints()
      if AQ_ShownSide == "Right" then
        column:SetPoint("TOPLEFT", AtlasFrame, "TOPRIGHT", GAP, 0)
      else
        column:SetPoint("TOPRIGHT", AtlasFrame, "TOPLEFT", -GAP, 0)
      end
      column:SetHeight(AtlasFrame:GetHeight())
    end
    -- pfUI keeps a hooked function under its hook's identity: one closure each.
    hooksecurefunc("AQ_AtlasOrAlphamap", function() Dock() end)
    hooksecurefunc("AQRIGHTOption_OnClick", function() Dock() end)
    hooksecurefunc("AQLEFTOption_OnClick", function() Dock() end)
    Dock()

    SoloSkin.Frame(AtlasQuestInsideFrame, AtlasQuestInsideFrame)
    SoloSkin.Controls(AtlasQuestInsideFrame)
    SoloSkin.Controls(AtlasQuestButtonFrame)

    SoloSkin.Backdrop(AtlasQuestOptionFrame)
    SoloSkin.Controls(AtlasQuestOptionFrame)
  end)
end)
