--[[--------------------------------------------------------------------------
MessageLog -- compact bottom-left message panel for Soloroth (WoW 1.12.1).

ChatFrame1 still receives the solo message groups (Solo.lua) but is parked
off-screen: FloatingChatFrame keeps yanking it out of any parent we give it.
A private ScrollingMessageFrame inside the panel draws the lines (bottom-up)
above the bags / time / gold strip. ChatFrame1:AddMessage is forwarded.

Layout matches other pfUI seats: UpdateMovable so ESC →「界面」→ unlock can
drag and mouse-wheel scale (UnlockSnap snaps drag-stop). No separate grip.
----------------------------------------------------------------------------]]

local WIDTH = 400
local HEIGHT = 88
local STRIP = 20
local PAD = 4

local panel
local display
local bagsText, timeText, goldText
local chatGuard = 0
local installed
local hooked
local movable

local function GoldString(money)
  money = money or 0
  local g = math.floor(money / 10000)
  local s = math.floor(math.mod(money / 100, 100))
  local c = math.floor(math.mod(money, 100))
  return string.format("|cffffd700%dg|r |cffc7c7cf%ds|r |cffeda55f%dc|r", g, s, c)
end

local function BagCounts()
  local maxslots, usedslots = 0, 0
  for bag = 0, 4 do
    local bagsize = GetContainerNumSlots(bag) or 0
    maxslots = maxslots + bagsize
    for slot = 1, bagsize do
      if GetContainerItemLink(bag, slot) then
        usedslots = usedslots + 1
      end
    end
  end
  return maxslots - usedslots, usedslots, maxslots
end

local function RefreshBags()
  if not bagsText then return end
  local free, used, maxslots = BagCounts()
  bagsText:SetText(free .. " (" .. used .. "/" .. maxslots .. ")")
end

local function RefreshGold()
  if not goldText then return end
  goldText:SetText(GoldString(GetMoney()))
end

local function RefreshTime()
  if not timeText then return end
  timeText:SetText(date("%H:%M"))
end

local function HidePfUIChat()
  if not pfUI then return end
  if pfUI.chat then
    if pfUI.chat.left then pfUI.chat.left:Hide() end
    if pfUI.chat.right then pfUI.chat.right:Hide() end
  end
  if pfUI.panel then
    if pfUI.panel.left then pfUI.panel.left:Hide() end
    if pfUI.panel.right then pfUI.panel.right:Hide() end
  end
end

local function HideChatTextures(id)
  if not CHAT_FRAME_TEXTURES then return end
  for _, tex in pairs(CHAT_FRAME_TEXTURES) do
    local texture = getglobal("ChatFrame" .. id .. tex)
    if texture then
      texture:SetTexture()
      texture:Hide()
    end
  end
end

local function CloseExtraChats()
  for i = 2, NUM_CHAT_WINDOWS or 7 do
    local frame = getglobal("ChatFrame" .. i)
    if frame then
      if frame.isDocked and FCF_UnDockFrame then FCF_UnDockFrame(frame) end
      if SetChatWindowShown then SetChatWindowShown(i, 0) end
      if FCF_Close then FCF_Close(frame) end
      frame:Hide()
      local tab = getglobal("ChatFrame" .. i .. "Tab")
      if tab then tab:Hide() end
    end
  end
end

local function DisplayOnMouseWheel()
  if not display then return end
  if arg1 > 0 then
    if IsShiftKeyDown() then
      display:ScrollToTop()
    else
      display:ScrollUp()
      display:ScrollUp()
      display:ScrollUp()
    end
  elseif arg1 < 0 then
    if IsShiftKeyDown() then
      display:ScrollToBottom()
    else
      display:ScrollDown()
      display:ScrollDown()
      display:ScrollDown()
    end
  end
end

local function LayoutDisplay()
  if not (panel and display) then return end
  local w = panel:GetWidth() - PAD * 2
  local h = panel:GetHeight() - STRIP - PAD * 2 - 2
  if w < 40 then w = 40 end
  if h < 20 then h = 20 end
  display:SetWidth(w)
  display:SetHeight(h)
  display:ClearAllPoints()
  display:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", PAD, STRIP + PAD + 2)
  display:Show()
end

local function SkinPanel()
  if not panel then return end
  local A = pfUI and pfUI.api
  if not (A and A.CreateBackdrop) then return end
  if panel.soloSkinned then return end
  if panel.SetBackdrop then panel:SetBackdrop(nil) end
  A.CreateBackdrop(panel, nil, nil, .75)
  if A.CreateBackdropShadow then A.CreateBackdropShadow(panel) end
  panel.soloSkinned = true
end

local function RegisterMovable()
  if movable or not panel then return end
  local A = pfUI and pfUI.api
  if not (A and A.UpdateMovable) then return end
  panel.OnMove = function()
    LayoutDisplay()
  end
  A.UpdateMovable(panel, true)
  movable = true
end

local function EnsureDisplay()
  if display then return display end
  display = CreateFrame("ScrollingMessageFrame", "pfSoloMessageLogDisplay", panel)
  display:SetJustifyH("LEFT")
  display:SetFading(false)
  if display.SetMaxLines then display:SetMaxLines(128) end
  if ChatFontNormal then
    display:SetFontObject(ChatFontNormal)
  elseif display.SetFont then
    display:SetFont("Fonts\\FRIZQT__.TTF", 12)
  end
  display:EnableMouseWheel(true)
  display:SetScript("OnMouseWheel", DisplayOnMouseWheel)
  display:EnableMouse(true)
  LayoutDisplay()
  return display
end

local function ParkChatFrame1()
  if not ChatFrame1 then return end
  if ChatFrame1.isDocked and FCF_UnDockFrame then
    FCF_UnDockFrame(ChatFrame1)
  end
  if SetChatWindowShown then SetChatWindowShown(1, 1) end
  ChatFrame1:SetParent(UIParent)
  ChatFrame1:ClearAllPoints()
  ChatFrame1:SetWidth(8)
  ChatFrame1:SetHeight(8)
  ChatFrame1:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -4000, 4000)
  ChatFrame1:EnableMouse(false)
  ChatFrame1:EnableMouseWheel(false)
  HideChatTextures(1)
  if ChatFrame1Tab then ChatFrame1Tab:Hide() end
  local resize = getglobal("ChatFrame1ResizeBottom")
  if resize then resize:Hide() end
  if ChatFrameMenuButton then ChatFrameMenuButton:Hide() end
  if FCF_SetLocked then FCF_SetLocked(ChatFrame1, 1) end
end

local function HookChatFrame1()
  if hooked or not ChatFrame1 then return end
  hooked = true
  local orig = ChatFrame1.AddMessage
  ChatFrame1.AddMessage = function(frame, msg, r, g, b, id)
    if orig then orig(frame, msg, r, g, b, id) end
    if display and msg then
      display:AddMessage(msg, r or 1, g or 1, b or 1)
    end
  end
end

local function EnsurePanel()
  if panel then return panel end

  -- pf-prefix so unlock mode labels it "SoloMessageLog".
  panel = CreateFrame("Frame", "pfSoloMessageLog", UIParent)
  panel:SetFrameStrata("BACKGROUND")
  panel:SetWidth(WIDTH)
  panel:SetHeight(HEIGHT)
  panel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 4, 4)
  panel:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  panel:SetBackdropColor(0, 0, 0, .75)
  panel:EnableMouse(true)

  local strip = CreateFrame("Frame", "pfSoloMessageLogStrip", panel)
  strip:SetHeight(STRIP)
  strip:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", PAD, PAD)
  strip:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -PAD, PAD)

  local bags = CreateFrame("Button", "pfSoloMessageLogBags", strip)
  bags:SetPoint("TOPLEFT", strip, "TOPLEFT", 2, 0)
  bags:SetPoint("BOTTOMRIGHT", strip, "BOTTOM", -2, 0)
  bags:RegisterForClicks("LeftButtonUp")
  bags:SetScript("OnClick", function()
    if type(OpenAllBags) == "function" then OpenAllBags() end
  end)
  bagsText = bags:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  bagsText:SetAllPoints(bags)
  bagsText:SetJustifyH("CENTER")
  bagsText:SetJustifyV("CENTER")

  timeText = strip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  timeText:SetPoint("CENTER", strip, "CENTER", 0, 0)
  timeText:SetJustifyH("CENTER")
  timeText:SetJustifyV("CENTER")

  goldText = strip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  goldText:SetPoint("TOPLEFT", strip, "TOP", 2, 0)
  goldText:SetPoint("BOTTOMRIGHT", strip, "BOTTOMRIGHT", -2, 0)
  goldText:SetJustifyH("RIGHT")
  goldText:SetJustifyV("CENTER")

  local line = strip:CreateTexture(nil, "ARTWORK")
  line:SetTexture(1, 1, 1, .12)
  line:SetHeight(1)
  line:SetPoint("TOPLEFT", strip, "TOPLEFT", 0, 1)
  line:SetPoint("TOPRIGHT", strip, "TOPRIGHT", 0, 1)

  local ev = CreateFrame("Frame", nil, panel)
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  ev:RegisterEvent("BAG_UPDATE")
  ev:RegisterEvent("PLAYER_MONEY")
  ev:SetScript("OnEvent", function()
    if event == "PLAYER_MONEY" then
      RefreshGold()
    else
      RefreshBags()
      if event == "PLAYER_ENTERING_WORLD" then RefreshGold() end
    end
  end)
  ev:SetScript("OnUpdate", function()
    this.t = (this.t or 0) + arg1
    if this.t < 1 then return end
    this.t = 0
    RefreshTime()
  end)

  EnsureDisplay()
  return panel
end

function Solo_PlaceMessageLog()
  if chatGuard > 0 then return end
  chatGuard = 1

  EnsurePanel()
  EnsureDisplay()
  SkinPanel()
  RegisterMovable()
  if movable and pfUI and pfUI.api and pfUI.api.UpdateMovable then
    pfUI.api.UpdateMovable(panel)
  end
  LayoutDisplay()
  HidePfUIChat()
  CloseExtraChats()
  ParkChatFrame1()
  HookChatFrame1()

  if display.ScrollToBottom then display:ScrollToBottom() end

  CloseExtraChats()
  HidePfUIChat()
  panel:Show()
  RefreshBags()
  RefreshGold()
  RefreshTime()

  chatGuard = 0
end

function Solo_InstallMessageLog()
  if installed then
    Solo_PlaceMessageLog()
    return
  end
  installed = true
  EnsurePanel()
  SkinPanel()
  Solo_PlaceMessageLog()

  if pfUI and pfUI.chat and pfUI.chat.RefreshChat then
    local refresh = pfUI.chat.RefreshChat
    pfUI.chat.RefreshChat = function()
      refresh()
      Solo_PlaceMessageLog()
    end
  end
  if FCF_SaveDock then
    local save = FCF_SaveDock
    FCF_SaveDock = function()
      save()
      Solo_PlaceMessageLog()
    end
  end
  if FloatingChatFrame_Update then
    local update = FloatingChatFrame_Update
    FloatingChatFrame_Update = function(id, onUpdateEvent)
      update(id, onUpdateEvent)
      Solo_PlaceMessageLog()
    end
  end

  local watch = CreateFrame("Frame")
  watch:SetScript("OnUpdate", function()
    this.t = (this.t or 0) + arg1
    if this.t < 0.5 then return end
    this.t = 0
    if not (panel and display and ChatFrame1) then return end
    local left, top = ChatFrame1:GetLeft(), ChatFrame1:GetTop()
    local parentH = UIParent:GetHeight() or 0
    local chatVisible = left and top and left > -100 and top < parentH + 100
    local rightShown = pfUI and pfUI.chat and pfUI.chat.right and pfUI.chat.right:IsShown()
    local leftShown = pfUI and pfUI.chat and pfUI.chat.left and pfUI.chat.left:IsShown()
    local extra = ChatFrame2 and ChatFrame2:IsShown()
    local badDisplay = display:GetParent() ~= panel
    if chatVisible or rightShown or leftShown or extra or badDisplay then
      Solo_PlaceMessageLog()
    end
  end)
end
