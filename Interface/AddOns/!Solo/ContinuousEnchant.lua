--[[--------------------------------------------------------------------------
Continuous re-enchant on one item, like smelting's Create All: the first
BIND_ENCHANT / REPLACE_ENCHANT confirm still asks; after Accept, further
REPLACE_ENCHANT on that grind skip the popup and call ReplaceEnchant().

Cancel on REPLACE_ENCHANT, or closing the profession window, arms the
prompt again. BIND_ENCHANT itself always shows (a new unbound piece).
----------------------------------------------------------------------------]]

local skipReplace = false
local hooked = false

local function HookDialog(which, onAccept, onCancel)
  local d = StaticPopupDialogs and StaticPopupDialogs[which]
  if not d or d.soloContinuousEnchant then return end
  d.soloContinuousEnchant = true
  local prevAccept = d.OnAccept
  d.OnAccept = function()
    if onAccept then onAccept() end
    if prevAccept then return prevAccept() end
  end
  if onCancel then
    local prevCancel = d.OnCancel
    d.OnCancel = function()
      onCancel()
      if prevCancel then return prevCancel() end
    end
  end
end

local function Hook()
  if hooked or type(StaticPopupDialogs) ~= "table" then return end
  if not StaticPopupDialogs["REPLACE_ENCHANT"] then return end
  hooked = true

  HookDialog("REPLACE_ENCHANT", function()
    skipReplace = true
  end, function()
    skipReplace = false
  end)

  -- First cast on an unbound BoE: Accept here means the next replaces
  -- on that piece should not keep asking.
  HookDialog("BIND_ENCHANT", function()
    skipReplace = true
  end, nil)

  local origShow = StaticPopup_Show
  if type(origShow) ~= "function" then return end
  StaticPopup_Show = function(which, text1, text2, data)
    if which == "REPLACE_ENCHANT" and skipReplace and type(ReplaceEnchant) == "function" then
      ReplaceEnchant()
      return
    end
    return origShow(which, text1, text2, data)
  end
end

Hook()

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("TRADE_SKILL_CLOSE")
f:SetScript("OnEvent", function()
  if event == "PLAYER_LOGIN" then
    Hook()
  elseif event == "TRADE_SKILL_CLOSE" then
    skipReplace = false
  end
end)
