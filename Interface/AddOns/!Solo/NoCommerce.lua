--[[--------------------------------------------------------------------------
No auction house, mail, trade or battlegrounds. Solo has no other players to
trade or mail with, and no AH / BG queue. Shut the stock frames and hide the
minimap mail / battlefield icons.
----------------------------------------------------------------------------]]

local function Shut(frame)
  if not frame or frame.soloCommerceShut then return end
  frame.soloCommerceShut = true
  frame:Hide()
  frame.Show = function() end
end

local function HideIcon(frame)
  if not frame then return end
  frame:Hide()
  frame.Show = function() end
end

-- Keybinds / NPC gossip call these by global name when present.
if type(AuctionFrame_LoadUI) == "function" then
  -- Keep the lazy-load hook; shut the frame once it exists.
end

local function Apply()
  Shut(AuctionFrame)
  Shut(MailFrame)
  Shut(TradeFrame)
  Shut(BattlefieldFrame)
  Shut(WorldStateScoreFrame)
  Shut(BattlefieldMinimap)
  HideIcon(MiniMapMailFrame)
  HideIcon(MiniMapBattlefieldFrame)
end

-- Open-mail / AH / trade events still fire; re-shut if a frame appears.
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("MAIL_SHOW")
ev:RegisterEvent("TRADE_SHOW")
ev:RegisterEvent("AUCTION_HOUSE_SHOW")
ev:RegisterEvent("BATTLEFIELDS_SHOW")
ev:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" then
    if arg1 == "Blizzard_AuctionUI" or arg1 == "pfUI" then
      Apply()
    end
    return
  end
  Apply()
  if event == "MAIL_SHOW" then Shut(MailFrame) end
  if event == "TRADE_SHOW" then Shut(TradeFrame) end
  if event == "AUCTION_HOUSE_SHOW" then Shut(AuctionFrame) end
  if event == "BATTLEFIELDS_SHOW" then Shut(BattlefieldFrame) end
end)

Apply()
