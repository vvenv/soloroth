--[[--------------------------------------------------------------------------
SoloUI — shared look tokens for glue (MPQ) and world (!Solo).

Edit this file only (ui/shared/Tokens.lua). ui/install.sh copies it into the
installed !Solo addon; ui/glue/build-patch.py ships it in patch-S ahead of
SoloGlueSkin.lua. Glue has no pfUI; world styles may still recolor borders —
these numbers are the product default (pfUI stock border / glue flats).
----------------------------------------------------------------------------]]

SoloUI = SoloUI or {}

SoloUI.WHITE = "Interface\\Buttons\\WHITE8X8"

-- 1px edge (r,g,b,a); matches pfUI default appearance.border.color.
SoloUI.BORDER = { .2, .2, .2, 1 }

-- Gold hover / selection accent (character-select pick, button hilight).
SoloUI.HOVER = { 1, .82, 0, 1 }

-- Flat panel fill alpha on black.
SoloUI.PANEL_ALPHA = .75

-- Same colors as pfUI appearance.border.* strings (GetStringColor).
SoloUI.BORDER_COLOR = "0.2,0.2,0.2,1"
SoloUI.BORDER_BACKGROUND = "0,0,0,0.75"
