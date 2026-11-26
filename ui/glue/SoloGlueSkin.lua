--[[--------------------------------------------------------------------------
The login, character select and character create screens in pfUI's look:
flat dark panels with a one-pixel border where the stock art drew its frames
and buttons. The glue has no pfUI, so this draws the same thing with the 1.12
glue API alone.

GlueXML runs off the patch chain, never loose files, so this file reaches the
client in a generated patch-S.MPQ beside SoloUITokens.lua (ui/shared/Tokens.lua)
and a copy of the stock GlueXML.toc (ui/glue/build-patch.py).

build-patch.py may prepend `SoloShowLoginUI = true|false`. Default false: the
AccountLogin page is removed for the run (model, overlay, the lot) while
Soloroth logs in from login.env — a black blank until character select.
play.sh passes --show-login-ui when there is no login.env, or when
WOW_SHOW_LOGIN_UI=1.

Colors come from SoloUI (loaded first as SoloUITokens.lua).
----------------------------------------------------------------------------]]

-- Prepended by build-patch.py; nil means hide (same as false).
if SoloShowLoginUI == nil then SoloShowLoginUI = false end

local WHITE = (SoloUI and SoloUI.WHITE) or "Interface\\Buttons\\WHITE8X8"
local BACKDROP = {
  bgFile = WHITE, edgeFile = WHITE, tile = false, edgeSize = 1,
  insets = { left = 1, right = 1, top = 1, bottom = 1 },
}
local BORDER = (SoloUI and SoloUI.BORDER) or { .2, .2, .2, 1 }
local HOVER = (SoloUI and SoloUI.HOVER) or { 1, .82, 0, 1 }
local PANEL_ALPHA = (SoloUI and SoloUI.PANEL_ALPHA) or .75

local function Texture(region)
  local path = region and region.GetTexture and region:GetTexture()
  return type(path) == "string" and path or ""
end

-- A backdrop behind `frame` in the rectangle its art drew, on a frame below
-- the owner's level so the owner's text stays on top.
local function Flat(frame, left, top, right, bottom, alpha)
  local bd = CreateFrame("Frame", nil, frame)
  local level = frame:GetFrameLevel()
  bd:SetFrameLevel(level > 0 and level - 1 or 0)
  bd:SetPoint("TOPLEFT", frame, "TOPLEFT", left or 0, -(top or 0))
  bd:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(right or 0), bottom or 0)
  bd:SetBackdrop(BACKDROP)
  bd:SetBackdropColor(0, 0, 0, alpha or PANEL_ALPHA)
  bd:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], BORDER[4])
  frame.soloBackdrop = bd
  return bd
end

-- A panel whose own backdrop was the stock art: the art goes, the flat one
-- takes the rectangle the art's background filled.
local function Panel(frame, left, top, right, bottom, alpha)
  if not frame or frame.soloSkinned then return end
  frame.soloSkinned = true
  frame:SetBackdrop(nil)
  return Flat(frame, left, top, right, bottom, alpha)
end

-- The flat backdrop on the frame itself, for one whose level leaves no room
-- below it: one level down from a child of a model frame is the model's scene.
local function Own(frame, alpha)
  if not frame or frame.soloSkinned then return end
  frame.soloSkinned = true
  frame:SetBackdrop(BACKDROP)
  frame:SetBackdropColor(0, 0, 0, alpha or PANEL_ALPHA)
  frame:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], BORDER[4])
end

local function HideTextures(frame)
  for _, r in ipairs({ frame:GetRegions() }) do
    if r:GetObjectType() == "Texture" then r:SetTexture(nil) end
  end
end

-- Stock Normal/Highlight/DisabledText sit CENTER -3,+3 for the tall red art;
-- pin every FontString to the flat face (GlueButtonTemplate has all three).
local function LabelOnFace(button, face)
  if not button or not face then return end
  for _, r in ipairs({ button:GetRegions() }) do
    if r:GetObjectType() == "FontString" then
      r:ClearAllPoints()
      r:SetPoint("CENTER", face, "CENTER", 0, 0)
    end
  end
end

-- The red Glue-Panel-Button art fills 86% of the button's width and about
-- half its height, centered a little above the middle, under the label.
local function Button(button)
  if button.soloSkinned then return end
  button.soloSkinned = true
  local w, h = button:GetWidth(), button:GetHeight()
  local bw, bh = math.floor(w * .86 + .5), math.floor(h * .55 + .5)

  button:SetNormalTexture("")
  button:SetDisabledTexture("")
  local bd = CreateFrame("Frame", nil, button)
  local level = button:GetFrameLevel()
  bd:SetFrameLevel(level > 0 and level - 1 or 0)
  bd:SetWidth(bw)
  bd:SetHeight(bh)
  bd:SetPoint("CENTER", button, "CENTER", -1, 3)
  bd:SetBackdrop(BACKDROP)
  bd:SetBackdropColor(0, 0, 0, PANEL_ALPHA)
  bd:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], BORDER[4])
  button.soloBackdrop = bd
  LabelOnFace(button, bd)

  button:SetHighlightTexture(WHITE)
  local hl = button:GetHighlightTexture()
  hl:ClearAllPoints()
  hl:SetPoint("TOPLEFT", bd, "TOPLEFT", 1, -1)
  hl:SetPoint("BOTTOMRIGHT", bd, "BOTTOMRIGHT", -1, 1)
  hl:SetVertexColor(1, 1, 1, .12)

  button:SetPushedTexture(WHITE)
  local pushed = button:GetPushedTexture()
  pushed:ClearAllPoints()
  pushed:SetPoint("TOPLEFT", bd, "TOPLEFT", 1, -1)
  pushed:SetPoint("BOTTOMRIGHT", bd, "BOTTOMRIGHT", -1, 1)
  pushed:SetVertexColor(HOVER[1], HOVER[2], HOVER[3], .2)
end

-- Every stock glue panel button under `frame`, found by its art.
local function Buttons(frame)
  for _, c in ipairs({ frame:GetChildren() }) do
    if c:GetObjectType() == "Button" and strfind(Texture(c:GetNormalTexture()), "Glue%-Panel%-Button") then
      Button(c)
    end
    Buttons(c)
  end
end

-- Flat square matching Enter's face: custom arc art (patch-S TGA), gold tint.
-- Stock Big / UI-Rotation textures stay low-res; Layout sizes these to the face.
local function RotateButton(button, side)
  if not button or button.soloSkinned then return end
  button.soloSkinned = true
  button:SetNormalTexture("")
  button:SetPushedTexture("")
  -- Default square; LayoutCharSelect retunes select to the shared row height.
  button:SetWidth(36)
  button:SetHeight(36)
  if button.SetHitRectInsets then
    button:SetHitRectInsets(0, 0, 0, 0)
  end

  local bd = CreateFrame("Frame", nil, button)
  local level = button:GetFrameLevel()
  bd:SetFrameLevel(level > 0 and level - 1 or 0)
  bd:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
  bd:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
  bd:SetBackdrop(BACKDROP)
  bd:SetBackdropColor(0, 0, 0, PANEL_ALPHA)
  bd:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], BORDER[4])
  button.soloBackdrop = bd

  local leaf = (side == "left") and "RotateLeft" or "RotateRight"
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetTexture("Interface\\Glues\\Solo\\" .. leaf)
  icon:SetPoint("TOPLEFT", button, "TOPLEFT", 5, -5)
  icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -5, 5)
  icon:SetVertexColor(HOVER[1], HOVER[2], HOVER[3], 1)
  button.soloIcon = icon

  button:SetHighlightTexture(WHITE)
  local hl = button:GetHighlightTexture()
  hl:ClearAllPoints()
  hl:SetPoint("TOPLEFT", bd, "TOPLEFT", 1, -1)
  hl:SetPoint("BOTTOMRIGHT", bd, "BOTTOMRIGHT", -1, 1)
  hl:SetVertexColor(1, 1, 1, .12)

  button:SetPushedTexture(WHITE)
  local pushed = button:GetPushedTexture()
  pushed:ClearAllPoints()
  pushed:SetPoint("TOPLEFT", bd, "TOPLEFT", 1, -1)
  pushed:SetPoint("BOTTOMRIGHT", bd, "BOTTOMRIGHT", -1, 1)
  pushed:SetVertexColor(HOVER[1], HOVER[2], HOVER[3], .2)
end

local function EditBox(box)
  -- The stock Glue-Tooltip-Border background sits 10/4/5/9 inside the box.
  local bd = Panel(box, 8, 3, 3, 7)
  if bd then box:SetTextInsets(14, 8, 0, 4) end
end

-- Kill the AccountLogin page: hide the ModelFFX (Dark Portal and all children)
-- and put a black blank over GlueParent so nothing of that screen remains.
-- After character select/create has stood once, "back" to login has nowhere to
-- go (page is gone), so QuitGame and let Soloroth.app return to the launcher.
local blank
local pastSelect = false

local function KillLoginPage()
  if AccountLogin then AccountLogin:Hide() end
  if not blank then
    blank = CreateFrame("Frame", "SoloLoginBlank", GlueParent)
    blank:SetAllPoints(GlueParent)
    blank:SetFrameStrata("FULLSCREEN")
    local fill = blank:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetTexture(WHITE)
    fill:SetVertexColor(0, 0, 0, 1)
    blank:EnableKeyboard(true)
    blank:SetScript("OnKeyDown", function()
      if arg1 == "ESCAPE" then QuitGame() end
    end)
  end
  blank:Show()
  blank:EnableKeyboard(true)
end

local function ReleaseLoginPage()
  pastSelect = true
  if blank then blank:Hide() end
end

-- Solo login keeps the account/password form and a Back (Quit) control.
-- Credits / cinematics / community / manage-account / TOS / realmlist / logo /
-- version / save-name / rating are solo-irrelevant chrome; stock OnShow may
-- re-Show some, so LayoutLogin runs after it too. Overlay dialogs (TOS,
-- keypad, survey, connection help) stay available when the stock path opens them.
local LOGIN_HIDE = {
  "AccountLoginLogo", "AccountLoginVersion", "WorldOfWarcraftRating",
  "AccountLoginTOSButton", "AccountLoginRealmName",
  "AccountLoginCreditsButton", "AccountLoginCinematicsButton",
  "AccountLoginCommunityButton", "AccountLoginManageAccountButton",
  "AccountLoginSaveAccountName",
  "BenillaRealmlistButton", "BenillaRealmlistText",
}

local function HideLoginChrome()
  for _, name in ipairs(LOGIN_HIDE) do
    local f = getglobal(name)
    if f then f:Hide() end
  end
  -- Stock Blizzard logo (unnamed Texture) and disclaimer (unnamed FontString)
  -- sit on AccountLoginUI; named chrome is in LOGIN_HIDE above.
  if AccountLoginUI then
    for _, r in ipairs({ AccountLoginUI:GetRegions() }) do
      local t = r:GetObjectType()
      if (t == "FontString" or t == "Texture") and not r:GetName() then
        r:Hide()
      end
    end
  end
end

-- Stock GlueButton face retune shared by login Back / Login and dialog OK.
-- Optional faceW: when set, the flat face uses that width (login column matches
-- the edit boxes' visible backdrop); otherwise ~86% of the button like stock art.
local function FaceCentered(btn, faceH, faceW)
  if not btn or not btn.soloBackdrop then return end
  local f = btn.soloBackdrop
  local w = faceW or math.floor(btn:GetWidth() * .86 + .5)
  local h = faceH or 36
  local bh = btn:GetHeight()
  if bh and bh > 0 and h > bh - 2 then h = bh - 2 end
  f:SetWidth(w)
  f:SetHeight(h)
  f:ClearAllPoints()
  f:SetPoint("CENTER", btn, "CENTER", 0, 0)
  LabelOnFace(btn, f)
end

local function LayoutLogin()
  HideLoginChrome()
  local ui = AccountLoginUI
  if not ui then return end
  local margin, baseline = 36, 44
  -- One column, one width: stock edits are 160 with Panel insets 8/3 (face
  -- off-center and narrower than Login's old GlueButton). Stretch each edit's
  -- face to the box, size Login to the same width, face fills the button —
  -- left/right edges share a line.
  local colW = 160
  for _, box in ipairs({ AccountLoginAccountEdit, AccountLoginPasswordEdit }) do
    if box then
      box:SetWidth(colW)
      if box.soloBackdrop then
        local bd = box.soloBackdrop
        bd:ClearAllPoints()
        bd:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
        bd:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
      end
    end
  end
  if AccountLoginAccountEdit then
    AccountLoginAccountEdit:ClearAllPoints()
    AccountLoginAccountEdit:SetPoint("BOTTOM", ui, "BOTTOM", 0, 345)
  end
  if AccountLoginPasswordEdit then
    AccountLoginPasswordEdit:ClearAllPoints()
    AccountLoginPasswordEdit:SetPoint("BOTTOM", ui, "BOTTOM", 0, 270)
  end
  if AccountLoginLoginButton then
    local login = AccountLoginLoginButton
    login:SetWidth(colW)
    login:ClearAllPoints()
    if AccountLoginPasswordEdit then
      login:SetPoint("TOP", AccountLoginPasswordEdit, "BOTTOM", 0, -16)
    else
      login:SetPoint("BOTTOM", ui, "BOTTOM", 0, 210)
    end
    FaceCentered(login, 36, colW)
  end
  -- Same bottom-left Back placement as character select; QuitGame via stock
  -- AccountLogin_Exit so Soloroth.app returns to the launcher.
  if AccountLoginExitButton then
    AccountLoginExitButton:SetText("后退")
    AccountLoginExitButton:ClearAllPoints()
    AccountLoginExitButton:SetPoint("BOTTOMLEFT", ui, "BOTTOMLEFT", margin, baseline)
    FaceCentered(AccountLoginExitButton)
  end
  -- A semi-transparent GlueDialog over the form makes the account box look like
  -- a mis-centered dialog control; hide the form while any dialog stands.
  local dialogUp = GlueDialog and GlueDialog:IsShown()
  for _, f in ipairs({ AccountLoginAccountEdit, AccountLoginPasswordEdit, AccountLoginLoginButton }) do
    if f then
      if dialogUp then f:Hide() else f:Show() end
    end
  end
end

local function SkinLogin()
  if SoloShowLoginUI then
    EditBox(AccountLoginAccountEdit)
    EditBox(AccountLoginPasswordEdit)
    Panel(ServerAlertFrame, 6, 6, 6, 6)
    Panel(VirtualKeypadFrame, 6, 6, 6, 6)
    local stockOnShow = AccountLogin_OnShow
    function AccountLogin_OnShow()
      stockOnShow()
      LayoutLogin()
    end
    LayoutLogin()
    return
  end

  KillLoginPage()
  -- Stock OnShow / ShowUserAgreements / survey will Show the page again; kill
  -- it every time. A later return from character select quits instead.
  local stockAgreements = AccountLogin_ShowUserAgreements
  function AccountLogin_ShowUserAgreements()
    stockAgreements()
    if pastSelect then QuitGame() return end
    KillLoginPage()
  end
  local stockOnShow = AccountLogin_OnShow
  function AccountLogin_OnShow()
    if pastSelect then
      QuitGame()
      return
    end
    stockOnShow()
    KillLoginPage()
    if AccountLoginAccountEdit then AccountLoginAccountEdit:ClearFocus() end
    if AccountLoginPasswordEdit then AccountLoginPasswordEdit:ClearFocus() end
  end
  local stockLogin = AccountLogin_Login
  function AccountLogin_Login()
    if not SoloShowLoginUI then return end
    return stockLogin()
  end
  local stockFocusPassword = AccountLogin_FocusPassword
  function AccountLogin_FocusPassword()
    if not SoloShowLoginUI then return end
    return stockFocusPassword()
  end
  local stockFocusAccount = AccountLogin_FocusAccountName
  function AccountLogin_FocusAccountName()
    if not SoloShowLoginUI then return end
    return stockFocusAccount()
  end
  local stockSurveyDone = AccountLogin_SurveyNotificationDone
  if stockSurveyDone then
    function AccountLogin_SurveyNotificationDone(accepted)
      stockSurveyDone(accepted)
      if pastSelect then QuitGame() return end
      KillLoginPage()
    end
  end
end

-- Solo has one local realm and a fixed addon set: no AddOns list, no realm
-- switch, no billing / remaining-time chrome, no stock WoW logo. Stock OnShow
-- and UpdateAddonButton re-Show some of these, so this runs after them too.
local CHAR_SELECT_HIDE = {
  "CharacterSelectAddonsButton", "CharacterSelectAddonsButtonGlow",
  "CharSelectChangeRealmButton", "CharSelectRealmName",
  "GameRoomBillingFrame", "BillingWarningFrame", "CharacterSelectLogo",
  "CharacterSelectRotateLeft", "CharacterSelectRotateRight",
}

local function HideCharSelectChrome()
  for _, name in ipairs(CHAR_SELECT_HIDE) do
    local f = getglobal(name)
    if f then f:Hide() end
  end
end

-- Stock select is top-heavy and right-crowded once the realm row is gone. Solo
-- layout: a right rail sized to the roster; bottom row is one baseline with
-- Back / Enter / Delete mirrored (same inset from left and right).
--
-- Stock character rows are left-anchored; their Glue-CharacterSelect-Highlight
-- hangs 20px left and its glow art is itself left-weighted — in a freestanding
-- rail that always reads off-center. Drop that texture, draw a pfUI-flat pick
-- frame we control, and center the row + text on the rail midline.
local ROW_W = 220

local function CenterCharSelectRow(btn)
  if not btn or btn.soloCentered then return end
  btn.soloCentered = true
  btn:SetWidth(ROW_W)
  local hl = btn:GetHighlightTexture()
  if hl then
    hl:SetTexture(nil)
    hl:SetWidth(1)
    hl:SetHeight(1)
  end
  if not btn.soloPick then
    local pick = CreateFrame("Frame", nil, btn)
    pick:SetFrameLevel(btn:GetFrameLevel())
    pick:SetPoint("TOPLEFT", btn, "TOPLEFT", -4, 6)
    pick:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 4, 10)
    pick:SetBackdrop(BACKDROP)
    pick:SetBackdropColor(1, .82, 0, .1)
    pick:SetBackdropBorderColor(HOVER[1], HOVER[2], HOVER[3], .95)
    pick:Hide()
    btn.soloPick = pick
  end
  local prefix = btn:GetName() .. "ButtonText"
  local text = getglobal(prefix)
  local name = getglobal(prefix .. "Name")
  local info = getglobal(prefix .. "Info")
  local loc = getglobal(prefix .. "Location")
  if name and text then
    name:SetJustifyH("CENTER")
    name:ClearAllPoints()
    name:SetPoint("TOP", text, "TOP", 0, -8)
  end
  if info and name then
    info:SetJustifyH("CENTER")
    info:SetWidth(ROW_W - 16)
    info:ClearAllPoints()
    info:SetPoint("TOP", name, "BOTTOM", 0, -1)
  end
  if loc and info then
    loc:SetJustifyH("CENTER")
    loc:SetWidth(ROW_W - 16)
    loc:ClearAllPoints()
    loc:SetPoint("TOP", info, "BOTTOM", 0, -1)
  end
end

local function SyncCharSelectPick()
  local maxDisp = MAX_CHARACTERS_DISPLAYED or 10
  local sel = CharacterSelect and CharacterSelect.selectedIndex or 0
  for i = 1, maxDisp do
    local btn = getglobal("CharSelectCharacterButton" .. i)
    if btn and btn.soloPick then
      if i == sel then btn.soloPick:Show() else btn.soloPick:Hide() end
    end
  end
end

local function LayoutCharSelect()
  HideCharSelectChrome()
  local ui = CharacterSelectUI
  local rail = CharacterSelectCharacterFrame
  if not ui or not rail then return end

  local margin, baseline = 36, 44
  local num = GetNumCharacters() or 0
  local maxPer = MAX_CHARACTERS_PER_REALM or 10
  local showCreate = (num < maxPer) and IsConnectedToServer()
  -- Row pitch matches stock: next button TOP = previous BOTTOM + 13 → 57px.
  local pitch, rowH, padTop = 57, 70, 28
  local padBot = showCreate and 58 or 24
  local listH = rowH
  if num > 1 then listH = rowH + (num - 1) * pitch end
  if num == 0 then listH = 0 end
  local h = padTop + listH + padBot
  if h < 160 then h = 160 end
  if h > 600 then h = 600 end

  rail:SetWidth(ROW_W + 36)
  rail:SetHeight(h)
  -- Same right inset as Delete; sit above the action row.
  rail:ClearAllPoints()
  rail:SetPoint("BOTTOMRIGHT", ui, "BOTTOMRIGHT", -margin, baseline + 56)

  if CharSelectCharacterButton1 then
    CharSelectCharacterButton1:ClearAllPoints()
    CharSelectCharacterButton1:SetPoint("TOP", rail, "TOP", 0, -padTop)
  end
  local maxDisp = MAX_CHARACTERS_DISPLAYED or 10
  for i = 1, maxDisp do
    CenterCharSelectRow(getglobal("CharSelectCharacterButton" .. i))
  end
  SyncCharSelectPick()
  if CharSelectCreateCharacterButton then
    local create = CharSelectCreateCharacterButton
    create:SetWidth(ROW_W)
    create:ClearAllPoints()
    create:SetPoint("BOTTOM", rail, "BOTTOM", 0, 14)
    -- Same fuller face as the bottom row: stock 55%/+3 left the label high.
    if create.soloBackdrop then
      local bw = math.floor(ROW_W * .86 + .5)
      local ch = create:GetHeight()
      local bh = 36
      if ch and ch > 0 and bh > ch - 2 then bh = ch - 2 end
      create.soloBackdrop:SetWidth(bw)
      create.soloBackdrop:SetHeight(bh)
      create.soloBackdrop:ClearAllPoints()
      create.soloBackdrop:SetPoint("CENTER", create, "CENTER", 0, 0)
      LabelOnFace(create, create.soloBackdrop)
    end
  end

  -- One bottom row: Back | Enter | Delete. Same baseline; outer edges share
  -- `margin` so left and right mirror. Enter is taller and grows up.
  if CharSelectEnterWorldButton then
    CharSelectEnterWorldButton:SetText("进入")
    -- Stock ENTER_WORLD is long; two glyphs need only a small face width.
    CharSelectEnterWorldButton:SetWidth(120)
    CharSelectEnterWorldButton:ClearAllPoints()
    CharSelectEnterWorldButton:SetPoint("BOTTOM", ui, "BOTTOM", 0, baseline)
  end
  if CharSelectCharacterName and CharSelectEnterWorldButton then
    CharSelectCharacterName:ClearAllPoints()
    CharSelectCharacterName:SetPoint("BOTTOM", CharSelectEnterWorldButton, "TOP", 0, 18)
  end
  -- Enter / Back / Delete share one face height, centered on each button
  -- (stock Button() face sits 3px high and only ~55% tall — on the
  -- SmallTemplate Back/Delete that left a ~21px face with the label sunk).
  local rowH = 36
  local function FaceOnRow(btn)
    if not btn or not btn.soloBackdrop then return end
    local f = btn.soloBackdrop
    local faceW = math.floor(btn:GetWidth() * .86 + .5)
    local faceH = rowH
    local bh = btn:GetHeight()
    if bh and bh > 0 and faceH > bh - 2 then faceH = bh - 2 end
    f:SetWidth(faceW)
    f:SetHeight(faceH)
    f:ClearAllPoints()
    f:SetPoint("CENTER", btn, "CENTER", 0, 0)
    LabelOnFace(btn, f)
  end
  FaceOnRow(CharSelectEnterWorldButton)
  if CharacterSelectBackButton then
    CharacterSelectBackButton:ClearAllPoints()
    CharacterSelectBackButton:SetPoint("BOTTOMLEFT", ui, "BOTTOMLEFT", margin, baseline)
    FaceOnRow(CharacterSelectBackButton)
  end
  if CharacterSelectDeleteButton then
    CharacterSelectDeleteButton:ClearAllPoints()
    CharacterSelectDeleteButton:SetPoint("BOTTOMRIGHT", ui, "BOTTOMRIGHT", -margin, baseline)
    FaceOnRow(CharacterSelectDeleteButton)
  end
end

local function SkinCharacterSelect()
  local stockCharShow = CharacterSelect_OnShow
  if stockCharShow then
    function CharacterSelect_OnShow()
      if not SoloShowLoginUI then ReleaseLoginPage() end
      local r = stockCharShow()
      LayoutCharSelect()
      return r
    end
  end
  local stockList = UpdateCharacterList
  if stockList then
    function UpdateCharacterList()
      stockList()
      LayoutCharSelect()
    end
  end
  local stockSel = UpdateCharacterSelection
  if stockSel then
    function UpdateCharacterSelection()
      stockSel()
      -- Stock LockHighlight would bring the left-weighted art back; keep ours.
      local maxDisp = MAX_CHARACTERS_DISPLAYED or 10
      for i = 1, maxDisp do
        local btn = getglobal("CharSelectCharacterButton" .. i)
        if btn then btn:UnlockHighlight() end
      end
      SyncCharSelectPick()
    end
  end
  function UpdateAddonButton()
    HideCharSelectChrome()
  end
  LayoutCharSelect()

  -- Own: a child one level down of a model-scene panel can slip under the 3D.
  Own(CharacterSelectCharacterFrame, .6)
  Panel(CharacterDeleteBackground, 6, 6, 6, 6, .85)
  Panel(CharacterRenameBackground, 6, 6, 6, 6, .85)
  -- Their name boxes wear the chat input's end caps.
  for _, box in ipairs({ CharacterDeleteEditBox, CharacterRenameEditBox }) do
    if box then
      HideTextures(box)
      Own(box)
      box:SetTextInsets(6, 6, 0, 0)
    end
  end
end

local function SkinCharacterCreate()
  if not SoloShowLoginUI then
    local stockCreateShow = CharacterCreate_OnShow
    if stockCreateShow then
      function CharacterCreate_OnShow()
        ReleaseLoginPage()
        return stockCreateShow()
      end
    end
  end
  -- The left column's stone frame and parchment; the faction banners stay.
  for _, name in ipairs({ "CharacterCreateOuterBorder1", "CharacterCreateOuterBorder2",
                          "CharacterCreateOuterBorder3", "CharacterCreateBackground" }) do
    local t = getglobal(name)
    if t then t:SetTexture(nil) end
  end
  if CharacterCreateOuterBorder1 and CharacterCreateOuterBorder3 then
    local column = CreateFrame("Frame", nil, CharacterCreateConfigurationFrame)
    local level = CharacterCreateConfigurationFrame:GetFrameLevel()
    column:SetFrameLevel(level > 0 and level - 1 or 0)
    column:SetPoint("TOPLEFT", CharacterCreateOuterBorder1, "TOPLEFT", 6, 0)
    column:SetPoint("BOTTOMRIGHT", CharacterCreateOuterBorder3, "BOTTOMRIGHT", -6, 6)
    column:SetBackdrop(BACKDROP)
    column:SetBackdropColor(0, 0, 0, PANEL_ALPHA)
    column:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], BORDER[4])
  end

  -- The three description panels and their scroll bars' end caps.
  for _, part in ipairs({ "Faction", "Race", "Class" }) do
    Panel(getglobal("CharacterCreateCharacter" .. part), 4, 4, 4, 4)
    for _, cap in ipairs({ "Top", "Bottom" }) do
      local t = getglobal("CharacterCreate" .. part .. "ScrollFrame" .. cap)
      if t then t:SetTexture(nil) end
    end
  end

  -- The customization rows' label plates.
  for i = 1, 5 do
    local row = getglobal("CharacterCustomizationButtonFrame" .. i)
    if row then
      for _, piece in ipairs({ "Left", "Middle", "Right" }) do
        local t = getglobal(row:GetName() .. piece)
        if t then t:SetTexture(nil) end
      end
      Flat(row, 26, 4, 26, 4, .6)
    end
  end

  EditBox(CharacterCreateNameEdit)
  RotateButton(CharacterCreateRotateLeft, "left")
  RotateButton(CharacterCreateRotateRight, "right")
end

-- Stock GlueDialog_Show places a lone OK on BOTTOM center; a prior two-button
-- dialog (or UPDATE_STATUS_DIALOG) can leave Button1 on BOTTOMRIGHT of center
-- so OK reads left. Re-assert after every show/update. Own the panel (Flat one
-- level down would slip under the dialog strata) at full opacity so the login
-- form cannot bleed through and look like a second, off-center control.
local function LayoutGlueDialog()
  if not GlueDialogBackground then return end
  GlueDialogBackground:ClearAllPoints()
  GlueDialogBackground:SetPoint("CENTER", GlueDialog, "CENTER", 0, 0)
  if GlueDialogButton2 and GlueDialogButton2:IsShown() then
    if GlueDialogButton1 then
      GlueDialogButton1:ClearAllPoints()
      GlueDialogButton1:SetPoint("BOTTOMRIGHT", GlueDialogBackground, "BOTTOM", -6, 16)
    end
    GlueDialogButton2:ClearAllPoints()
    GlueDialogButton2:SetPoint("LEFT", GlueDialogButton1, "RIGHT", 13, 0)
  elseif GlueDialogButton1 then
    GlueDialogButton1:ClearAllPoints()
    GlueDialogButton1:SetPoint("BOTTOM", GlueDialogBackground, "BOTTOM", 0, 16)
  end
  FaceCentered(GlueDialogButton1)
  FaceCentered(GlueDialogButton2)
  if SoloShowLoginUI then LayoutLogin() end
end

local function SkinDialogs()
  Own(GlueDialogBackground, .95)
  if GlueDialogEditBox then
    HideTextures(GlueDialogEditBox)
    Own(GlueDialogEditBox)
    GlueDialogEditBox:SetTextInsets(6, 6, 0, 0)
  end
  local stockShow = GlueDialog_Show
  if stockShow then
    function GlueDialog_Show(which, text, data)
      stockShow(which, text, data)
      LayoutGlueDialog()
    end
  end
  local stockDialogEvent = GlueDialog_OnEvent
  if stockDialogEvent then
    function GlueDialog_OnEvent()
      stockDialogEvent()
      if event == "UPDATE_STATUS_DIALOG" or event == "OPEN_STATUS_DIALOG" then
        LayoutGlueDialog()
      elseif event == "CLOSE_STATUS_DIALOG" and SoloShowLoginUI then
        LayoutLogin()
      end
    end
  end
  local stockDialogHide = GlueDialog_OnHide
  function GlueDialog_OnHide()
    if stockDialogHide then stockDialogHide() end
    if SoloShowLoginUI then LayoutLogin() end
  end
  -- benilla's realmlist dialog widens the box and adds a chat-input middle
  -- piece to it at each open.
  local take = BenillaRealmlist_TakeEditBox
  if take then
    BenillaRealmlist_TakeEditBox = function()
      take()
      if BenillaRealmlist_Middle then BenillaRealmlist_Middle:Hide() end
    end
  end
  if RealmListBackground then
    HideTextures(RealmListBackground)
    Flat(RealmListBackground, 6, 6, 6, 6, .85)
  end
end

local function Skin()
  SkinLogin()
  SkinCharacterSelect()
  SkinCharacterCreate()
  SkinDialogs()
  for _, root in ipairs({ AccountLoginUI, CharacterSelectUI, CharacterCreateFrame, GlueDialog,
                          CharacterDeleteDialog, CharacterRenameDialog, RealmList,
                          BillingWarningFrame }) do
    if root then Buttons(root) end
  end
  -- Buttons() builds Login's soloBackdrop after SkinLogin's first LayoutLogin;
  -- AccountLogin may already be shown so OnShow will not re-fire. Lay out again
  -- so the face fills the column width instead of Button()'s 86% stock fraction.
  if SoloShowLoginUI then LayoutLogin() end
  LayoutGlueDialog()
end

-- FRAMES_LOADED fires once the whole glue and benilla's own glue file have
-- loaded, so their buttons are all there.
--
-- DISCONNECTED_FROM_SERVER: stock shows AccountLogin and a dialog. With the
-- form hidden there is nothing to type into (env login already spent, creds
-- cleared), so QuitGame and let Soloroth.app's launch script bring the
-- launcher back instead of an empty password screen.
local stockOnEvent = GlueParent_OnEvent
function GlueParent_OnEvent(event)
  if event == "FRAMES_LOADED" and not SoloGlueSkinned then
    SoloGlueSkinned = true
    Skin()
  end
  if event == "DISCONNECTED_FROM_SERVER" and not SoloShowLoginUI then
    QuitGame()
    return
  end
  return stockOnEvent(event)
end
