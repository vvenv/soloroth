--[[--------------------------------------------------------------------------
Chinese for third-party addons that ship English-only UI. Their sources stay
untouched; this file swaps the strings after each addon loads (zhCN clients
only). Bagshui has its own Locale/zhCN.lua.
----------------------------------------------------------------------------]]

if GetLocale() ~= "zhCN" then return end

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
  if arg1 == "ShaguNotify" then
    LocalizeShaguNotify()
  elseif arg1 == "ShaguKill" then
    LocalizeShaguKill()
  end
end)

-- Already-loaded addons (load order can put them before this file runs).
if IsAddOnLoaded and IsAddOnLoaded("ShaguNotify") then LocalizeShaguNotify() end
if IsAddOnLoaded and IsAddOnLoaded("ShaguKill") then LocalizeShaguKill() end
