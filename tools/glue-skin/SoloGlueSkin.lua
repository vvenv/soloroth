--[[--------------------------------------------------------------------------
The login, character select and character create screens in pfUI's look:
flat dark panels with a one-pixel border where the stock art drew its frames
and buttons. The glue has no pfUI, so this draws the same thing with the 1.12
glue API alone.

GlueXML runs off the patch chain, never loose files, so this file reaches the
client in a generated patch-S.MPQ beside a copy of the stock GlueXML.toc with
this file appended (tools/glue-skin/build-patch.py).

build-patch.py may prepend `SoloShowLoginUI = true|false`. Default false: the
AccountLogin page is removed for the run (model, overlay, the lot) while
Soloroth logs in from login.env — a black blank until character select.
play.sh passes --show-login-ui when there is no login.env, or when
WOW_SHOW_LOGIN_UI=1.
----------------------------------------------------------------------------]]

-- Prepended by build-patch.py; nil means hide (same as false).
if SoloShowLoginUI == nil then SoloShowLoginUI = false end

local WHITE = "Interface\\Buttons\\WHITE8X8"
local BACKDROP = {
  bgFile = WHITE, edgeFile = WHITE, tile = false, edgeSize = 1,
  insets = { left = 1, right = 1, top = 1, bottom = 1 },
}
-- pfUI's default appearance.border colors.
local BORDER = { .2, .2, .2, 1 }
local HOVER = { 1, .82, 0, 1 }

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
  bd:SetBackdropColor(0, 0, 0, alpha or .75)
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
  frame:SetBackdropColor(0, 0, 0, alpha or .75)
  frame:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], BORDER[4])
end

local function HideTextures(frame)
  for _, r in ipairs({ frame:GetRegions() }) do
    if r:GetObjectType() == "Texture" then r:SetTexture(nil) end
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
  bd:SetBackdropColor(0, 0, 0, .75)
  bd:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], BORDER[4])
  button.soloBackdrop = bd

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

local function EditBox(box)
  -- The stock Glue-Tooltip-Border background sits 10/4/5/9 inside the box.
  local bd = Panel(box, 8, 3, 3, 7)
  if bd then box:SetTextInsets(14, 8, 0, 4) end
end

-- Kill the AccountLogin page: hide the ModelFFX (Dark Portal and all children)
-- and put a black blank over GlueParent so nothing of that screen remains.
local blank

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
  if blank then blank:Hide() end
end

local function SkinLogin()
  if SoloShowLoginUI then
    EditBox(AccountLoginAccountEdit)
    EditBox(AccountLoginPasswordEdit)
    Panel(ServerAlertFrame, 6, 6, 6, 6)
    Panel(VirtualKeypadFrame, 6, 6, 6, 6)
    return
  end

  KillLoginPage()
  -- Stock OnShow / ShowUserAgreements / survey will Show the page again; kill
  -- it every time. Login/focus no-op so nothing fights the env fast path.
  local stockAgreements = AccountLogin_ShowUserAgreements
  function AccountLogin_ShowUserAgreements()
    stockAgreements()
    KillLoginPage()
  end
  local stockOnShow = AccountLogin_OnShow
  function AccountLogin_OnShow()
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
      KillLoginPage()
    end
  end
end

local function SkinCharacterSelect()
  -- Login blank stays up until character select actually stands.
  local stockCharShow = CharacterSelect_OnShow
  if stockCharShow and not SoloShowLoginUI then
    function CharacterSelect_OnShow()
      ReleaseLoginPage()
      return stockCharShow()
    end
  end
  Panel(CharacterSelectCharacterFrame, 8, 3, 3, 7, .6)
  Own(GameRoomBillingFrame)
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
    column:SetBackdropColor(0, 0, 0, .75)
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
end

local function SkinDialogs()
  Panel(GlueDialogBackground, 6, 6, 6, 6, .85)
  if GlueDialogEditBox then
    HideTextures(GlueDialogEditBox)
    Own(GlueDialogEditBox)
    GlueDialogEditBox:SetTextInsets(6, 6, 0, 0)
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
