--[[--------------------------------------------------------------------------
TradeSkill and Craft are one workbench each; pfUI EnableMovable lets both float
at once. Close the other on SHOW so only one profession window is open.
----------------------------------------------------------------------------]]

local f = CreateFrame("Frame")
f:RegisterEvent("TRADE_SKILL_SHOW")
f:RegisterEvent("CRAFT_SHOW")
f:SetScript("OnEvent", function()
  if event == "TRADE_SKILL_SHOW" then
    if type(CloseCraft) == "function" then CloseCraft() end
  elseif event == "CRAFT_SHOW" then
    if type(CloseTradeSkill) == "function" then CloseTradeSkill() end
  end
end)
