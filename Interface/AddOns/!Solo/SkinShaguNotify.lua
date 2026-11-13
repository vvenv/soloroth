--[[--------------------------------------------------------------------------
ShaguNotify's popups (quest done, level up, a new zone, a close fight) in the
look of the achievement toast: pfUI's backdrop with a gold border, the icon
cropped on the left, the points on the right, instead of the 3.x
achievement-alert art.
----------------------------------------------------------------------------]]

SoloSkin.Register("ShaguNotify", function()
  HookAddonOrVariable("libnotify", function()
    for i = 1, libnotify.max_window do
      local w = libnotify.window[i]
      w:SetHeight(64)
      w.background:Hide()
      w.glow:Hide()
      w.shine:Hide()
      w.icon.bling:Hide()
      w.icon.overlay:Hide()
      w.shield.icon:Hide()

      CreateBackdrop(w, nil, nil, .85)
      CreateBackdropShadow(w)
      w.backdrop:SetBackdropBorderColor(1, .82, 0, 1)

      w.icon:ClearAllPoints()
      w.icon:SetPoint("LEFT", w, "LEFT", 10, 0)
      w.icon:SetWidth(44)
      w.icon:SetHeight(44)
      CreateBackdrop(w.icon, nil, true)
      w.icon.texture:ClearAllPoints()
      SetAllPointsOffset(w.icon.texture, w.icon, 1)
      w.icon.texture:SetTexCoord(.08, .92, .08, .92)

      w.unlocked:SetFontObject(GameFontHighlightSmall)
      w.unlocked:ClearAllPoints()
      w.unlocked:SetPoint("TOPLEFT", w.icon, "TOPRIGHT", 10, -4)
      w.unlocked:SetPoint("RIGHT", w, "RIGHT", -44, 0)
      w.unlocked:SetJustifyH("LEFT")

      w.name:SetFontObject(GameFontNormalLarge)
      w.name:ClearAllPoints()
      w.name:SetPoint("TOPLEFT", w.unlocked, "BOTTOMLEFT", 0, -4)
      w.name:SetPoint("RIGHT", w, "RIGHT", -44, 0)
      w.name:SetJustifyH("LEFT")

      w.shield:ClearAllPoints()
      w.shield:SetPoint("RIGHT", w, "RIGHT", -8, 0)
      w.shield:SetWidth(32)
      w.shield:SetHeight(32)
      w.shield.points:ClearAllPoints()
      w.shield.points:SetAllPoints(w.shield)
      w.shield.points:SetFontObject(GameFontNormalLarge)

      -- stacked under the achievement toast (SoloAchievementToast, TOP -150)
      w:ClearAllPoints()
      w:SetPoint("TOP", UIParent, "TOP", 0, -230 - 72 * (i - 1))
    end
  end)
end)
