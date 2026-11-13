--[[--------------------------------------------------------------------------
What the pfUI skins of the third-party addons share (SkinAtlas.lua,
SkinSuperMacro.lua, SkinShaguNotify.lua): their registration with pfUI, so
pfUI's "disable skin" setting covers each, and a walk that gives every stock
control under a frame pfUI's look, found by what it is:

  * panel buttons, check boxes, sliders, scroll bars, input boxes, drop-down
    menus, tabs, page arrows and close buttons, as pfUI's own skins do them;
  * a control is done once, so a walk may cover a frame already walked.

The helpers call pfUI.api by name; the skin bodies run in pfUI's environment,
where the same functions are globals.
----------------------------------------------------------------------------]]

SoloSkin = { skins = {} }

-- A skin body runs once pfUI has loaded, after every addon before it in
-- folder order (pfUI is last).
function SoloSkin.Register(name, func)
  table.insert(SoloSkin.skins, { name, func })
end

local function Texture(region)
  local path = region and region.GetTexture and region:GetTexture()
  return type(path) == "string" and path or ""
end

function SoloSkin.Backdrop(frame, alpha)
  local A = pfUI.api
  if frame.SetBackdrop then frame:SetBackdrop(nil) end
  A.CreateBackdrop(frame, nil, nil, alpha or .75)
  A.CreateBackdropShadow(frame)
end

-- An inner panel behind part of a window, without covering what the window
-- draws there: its frame sits below the window's own level.
function SoloSkin.Panel(parent, left, top, right, bottom, alpha)
  local panel = CreateFrame("Frame", nil, parent)
  panel:SetFrameLevel(math.max(parent:GetFrameLevel() - 1, 0))
  panel:SetPoint("TOPLEFT", parent, "TOPLEFT", left, top)
  panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", right, bottom)
  pfUI.api.CreateBackdrop(panel, nil, true, alpha or .5)
  return panel
end

-- Only the border, for a panel over art the window draws itself.
function SoloSkin.Frame(parent, region)
  local border = CreateFrame("Frame", nil, parent)
  border:SetAllPoints(region)
  pfUI.api.CreateBackdrop(border, nil, true)
  border:SetBackdropColor(0, 0, 0, 0)
  return border
end

function SoloSkin.Close(button, anchor)
  if not button then return end
  local A = pfUI.api
  local parent = anchor or button:GetParent()
  A.SkinCloseButton(button, parent.backdrop or parent, -6, -6)
  if button:GetText() then button:SetText("") end
end

function SoloSkin.EditBox(box, left, middle, right)
  local A = pfUI.api
  for _, t in ipairs({ left, middle, right }) do
    if t then t:Hide() end
  end
  if box:GetHeight() > 22 then box:SetHeight(20) end
  A.CreateBackdrop(box, nil, true)
  box:SetTextInsets(4, 4, 0, 0)
end

-- A square icon button whose icon is its normal texture (macro and quest
-- reward slots): the slot art goes, the icon is cropped inside a pfUI border.
function SoloSkin.IconButton(button, icon)
  local A = pfUI.api
  for _, r in ipairs({ button:GetRegions() }) do
    if r:GetObjectType() == "Texture" and r ~= icon and r:GetDrawLayer() == "BACKGROUND" then
      r:Hide()
    end
  end
  A.CreateBackdrop(button, nil, true)
  icon = icon or button:GetNormalTexture()
  if icon then
    icon:ClearAllPoints()
    A.SetAllPointsOffset(icon, button, 2)
    icon:SetTexCoord(.08, .92, .08, .92)
  end
  local _, class = UnitClass("player")
  local c = RAID_CLASS_COLORS[class]
  if button:GetHighlightTexture() then
    button:GetHighlightTexture():SetTexture(1, 1, 1, .15)
    A.SetAllPointsOffset(button:GetHighlightTexture(), button, 2)
  end
  if button.GetCheckedTexture and button:GetCheckedTexture() then
    button:GetCheckedTexture():SetTexture(c.r, c.g, c.b, .35)
    A.SetAllPointsOffset(button:GetCheckedTexture(), button, 2)
  end
  A.SetHighlight(button)
end

local function Normalize(button)
  if button:GetHeight() > 24 then button:SetHeight(20) end
end

-- UIPanelButtonTemplate2 draws its face with three region textures instead
-- of a normal texture, and swaps their files on press, enable and show.
local function PanelFace(button)
  local face = {}
  for _, r in ipairs({ button:GetRegions() }) do
    if r:GetObjectType() == "Texture" and strfind(Texture(r), "UI%-Panel%-Button%-") then
      table.insert(face, r)
    end
  end
  return face
end

-- Labels in black for parchment art; on pfUI's dark panels they vanish.
local function LightenLabels(frame)
  for _, r in ipairs({ frame:GetRegions() }) do
    if r:GetObjectType() == "FontString" then
      local cr, cg, cb = r:GetTextColor()
      if cr and cr < .25 and cg < .25 and cb < .25 then r:SetTextColor(1, 1, 1) end
    end
  end
end

-- Every stock control under `frame`.
function SoloSkin.Controls(frame)
  local A = pfUI.api
  LightenLabels(frame)
  for _, c in ipairs({ frame:GetChildren() }) do
    if not c.soloSkinned then
      c.soloSkinned = true
      local name = c:GetName() or ""
      local kind = c:GetObjectType()
      local normal = (kind == "Button" or kind == "CheckButton") and Texture(c:GetNormalTexture()) or ""
      local face = kind == "Button" and normal == "" and PanelFace(c) or {}

      if kind == "CheckButton" and strfind(normal, "UI%-CheckBox") then
        A.SkinCheckbox(c, 22)
      elseif kind == "Button" and table.getn(face) > 0 then
        for _, t in ipairs(face) do
          t:SetAlpha(0)
          t:Hide()
        end
        A.SkinButton(c)
        Normalize(c)
      elseif kind == "Button" and (strfind(normal, "UI%-Panel%-Button") or strfind(normal, "UI%-DialogBox%-Button")) then
        A.SkinButton(c)
        Normalize(c)
      elseif kind == "Button" and strfind(normal, "UI%-Panel%-MinimizeButton") then
        SoloSkin.Close(c)
      elseif kind == "Button" and strfind(normal, "NextPage") then
        A.SkinArrowButton(c, "right", 18)
      elseif kind == "Button" and strfind(normal, "PrevPage") then
        A.SkinArrowButton(c, "left", 18)
      elseif kind == "Slider" and getglobal(name .. "ScrollUpButton") then
        A.SkinScrollbar(c)
      elseif kind == "Slider" then
        A.SkinSlider(c)
      elseif kind == "EditBox" and getglobal(name .. "Left") then
        SoloSkin.EditBox(c, getglobal(name .. "Left"), getglobal(name .. "Middle"), getglobal(name .. "Right"))
      elseif kind == "ScrollFrame" then
        A.StripTextures(c)
      elseif name ~= "" and getglobal(name .. "LeftDisabled") and getglobal(name .. "MiddleDisabled") then
        A.SkinTab(c)
      elseif name ~= "" and getglobal(name .. "Button") and getglobal(name .. "Middle") and getglobal(name .. "Text") then
        A.SkinDropDown(c, nil, nil, nil, true)
      end

      SoloSkin.Controls(c)
    end
  end
end

-- pfUI-styled popup menus for the Dewdrop library (AtlasLoot's loot table
-- menus): each menu level is a frame named Dewdrop20Level<n> made on first
-- use, whose tooltip backdrop sits on its first child.
function SoloSkin.Dewdrop()
  local A = pfUI.api
  local br, bg, bb, ba = A.GetStringColor(pfUI_config.appearance.border.background)
  local er, eg, eb, ea = A.GetStringColor(pfUI_config.appearance.border.color)
  local watch = CreateFrame("Frame")
  watch:SetScript("OnUpdate", function()
    if (this.t or 0) > GetTime() then return end
    this.t = GetTime() + .1
    local i = 1
    while getglobal("Dewdrop20Level" .. i) do
      local level = getglobal("Dewdrop20Level" .. i)
      if not level.soloSkinned then
        level.soloSkinned = true
        local back = level:GetChildren()
        if back and back.SetBackdrop then
          back:SetBackdrop(pfUI.backdrop)
          back:SetBackdropColor(br, bg, bb, ba)
          back:SetBackdropBorderColor(er, eg, eb, ea)
          A.CreateBackdropShadow(back)
        end
      end
      i = i + 1
    end
  end)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function()
  if arg1 ~= "pfUI" or not pfUI or not pfUI.RegisterSkin then return end
  this:UnregisterEvent("ADDON_LOADED")
  for _, s in ipairs(SoloSkin.skins) do
    pfUI:RegisterSkin(s[1], "vanilla", s[2])
  end
end)
