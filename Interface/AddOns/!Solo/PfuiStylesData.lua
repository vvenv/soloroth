--[[--------------------------------------------------------------------------
Bundled pfUI style tables for Soloroth (community /share imports, decoded).

Loaded by PfuiStyle.lua into pfUI_profiles as "Solo: …" entries. position is
omitted: Solo's invariant HUD seats always win. Disabled-module flags in these
tables are sparse diffs; Solo_ApplyPfUIInvariant re-applies solo disables.
----------------------------------------------------------------------------]]

Solo_PfuiCommunityStyles = {
  -- Community profile by megajjh (r/pfUI, https://pastebin.com/aTz0rQAa).
  {
    id = "Solo: Clean",
    en = "Clean",
    zh = "清爽",
    config = {
      ["unitframes"] = {
        ["grouptarget"] = {
          ["visible"] = "0",
        },
        ["ptarget"] = {
          ["width"] = "125",
          ["pspace"] = "-1",
          ["portrait"] = "off",
          ["height"] = "8",
        },
        ["target"] = {
          ["indicator_pos"] = "RIGHT",
          ["panchor"] = "TOPLEFT",
          ["custom_indicator"] = "#Moonfire#Insect Swarm",
          ["indicator_spacing"] = "3",
          ["pspace"] = "-1",
          ["show_buffs"] = "0",
          ["indicator_size"] = "28",
          ["pheight"] = "6",
          ["portrait"] = "off",
          ["show_hots"] = "1",
          ["height"] = "35",
          ["buffs"] = "off",
          ["txthpright"] = "healthperc",
          ["buff_indicator"] = "1",
          ["debuffs"] = "off",
          ["txthprightoffx"] = "40",
          ["width"] = "225",
        },
        ["ttarget"] = {
          ["width"] = "125",
          ["pspace"] = "-1",
          ["pheight"] = "6",
          ["portrait"] = "off",
          ["height"] = "16",
        },
        ["player"] = {
          ["txthpleft"] = "powerdyn",
          ["pheight"] = "25",
          ["pspace"] = "-1",
          ["showPVP"] = "0",
          ["height"] = "35",
          ["buffs"] = "off",
          ["debuffs"] = "off",
          ["portrait"] = "off",
          ["width"] = "225",
          ["panchor"] = "TOPRIGHT",
        },
        ["focus"] = {
          ["pheight"] = "6",
          ["portrait"] = "off",
        },
        ["raid"] = {
          ["indicator_pos"] = "TOP",
          ["custom_indicator"] = "#Mark of the Wild",
          ["txthpleftoffy"] = "-10",
          ["show_buffs"] = "0",
          ["indicator_size"] = "19",
          ["show_hots"] = "1",
          ["height"] = "40",
          ["width"] = "80",
          ["indicator_spacing"] = "3",
        },
        ["pet"] = {
          ["width"] = "125",
          ["pspace"] = "-1",
          ["portrait"] = "off",
          ["pheight"] = "6",
        },
        ["group"] = {
          ["custom_indicator"] = "#Wildgrowth",
          ["txthpleftoffy"] = "-10",
          ["show_buffs"] = "0",
          ["hide_in_raid"] = "1",
          ["indicator_size"] = "16",
          ["showtooltip"] = "0",
          ["debuffs"] = "off",
          ["show_hots"] = "1",
          ["buffs"] = "off",
          ["txthpright"] = "healthperc",
        },
        ["tttarget"] = {
          ["width"] = "125",
          ["pspace"] = "-1",
          ["pheight"] = "6",
          ["portrait"] = "off",
          ["height"] = "16",
        },
        ["customcolor"] = "0.1,0.2,0.2,1",
      },
      ["global"] = {
        ["autorepair"] = "1",
        ["profile"] = "Arakenek",
        ["autosell"] = "1",
        ["font_size"] = "14",
        ["font_default"] = "Interface\\AddOns\\pfUI\\fonts\\PT-Sans-Narrow-Bold.ttf",
      },
      ["panel"] = {
        ["xp"] = {
          ["rep_display"] = "FLEX",
        },
      },
      ["bars"] = {
        ["bar3"] = {
          ["formfactor"] = "4 x 3",
          ["icon_size"] = "24",
        },
        ["bar8"] = {
          ["icon_size"] = "17",
        },
        ["bar9"] = {
          ["icon_size"] = "17",
        },
        ["bar1"] = {
          ["icon_size"] = "24",
        },
        ["bar7"] = {
          ["icon_size"] = "17",
        },
        ["bar6"] = {
          ["icon_size"] = "24",
        },
        ["bar10"] = {
          ["icon_size"] = "17",
        },
        ["bar2"] = {
          ["icon_size"] = "17",
        },
        ["bar5"] = {
          ["formfactor"] = "4 x 3",
          ["icon_size"] = "24",
        },
        ["bar12"] = {
          ["icon_size"] = "17",
        },
        ["bar11"] = {
          ["icon_size"] = "17",
        },
        ["bar4"] = {
          ["icon_size"] = "17",
        },
      },
      ["appearance"] = {
        ["infight"] = {
          ["health"] = "0",
          ["common"] = "0",
        },
        ["bags"] = {
          ["movable"] = "1",
        },
        ["border"] = {
          ["color"] = "0,0,0,1",
          ["actionbars"] = "4",
          ["background"] = "0.05,0.15,0.15,0.75",
          ["unitframes"] = "1",
        },
        ["worldmap"] = {
          ["mapreveal"] = "1",
        },
      },
      ["chat"] = {
        ["global"] = {
          ["tabmouse"] = "1",
          ["border"] = "0,0,0,1",
          ["custombg"] = "1",
          ["background"] = "0.15,0.25,0.25,0.3",
        },
        ["text"] = {
          ["outline"] = "0",
        },
        ["left"] = {
          ["height"] = "161",
          ["width"] = "400",
        },
        ["right"] = {
          ["height"] = "161",
          ["enable"] = "1",
          ["width"] = "400",
        },
      },
      ["version"] = "5.5.4",
      ["nameplates"] = {
        ["barcombatstate"] = "0",
        ["debuffs"] = {
          ["filter"] = "whitelist",
          ["whitelist"] = "#Moonfire#Insect Swarm",
        },
        ["debuffsize"] = "20",
      },
      ["bettertotems"] = {
        ["asked"] = "0",
        ["recallRange"] = "45",
        ["recall"] = "1",
      },
    },
  },
  -- Community profile by Khegful (r/pfUI, https://pastebin.com/m2nLAtHA).
  {
    id = "Solo: Compact",
    en = "Compact",
    zh = "紧凑",
    config = {
      ["questlog"] = {
        ["showQuestLevels"] = "1",
      },
      ["unitframes"] = {
        ["grouptarget"] = {
          ["visible"] = "0",
        },
        ["ttarget"] = {
          ["visible"] = "0",
          ["glowcombat"] = "0",
          ["glowaggro"] = "0",
        },
        ["target"] = {
          ["txthpleft"] = "healthdyn",
          ["healthcolor"] = "0",
          ["defcolor"] = "0",
          ["pheight"] = "6",
          ["width"] = "367",
          ["glowcombat"] = "0",
          ["height"] = "17",
          ["buffs"] = "TOPRIGHT",
          ["manacolor"] = "0.1,0.1,0.5,1",
          ["txthpright"] = "unit",
          ["pbartexture"] = "Interface\\AddOns\\pfUI\\img\\bar_gradient",
        },
        ["player"] = {
          ["defcolor"] = "0",
          ["pbartexture"] = "Interface\\AddOns\\pfUI\\img\\bar_gradient",
          ["customfont_name"] = "Interface\\AddOns\\pfUI\\fonts\\Myriad-Pro.ttf",
          ["pheight"] = "6",
          ["customfont_style"] = "THICKOUTLINE",
          ["cooldown_text"] = "0",
          ["glowcombat"] = "0",
          ["customfont_size"] = "10",
          ["hitindicator"] = "1",
          ["height"] = "17",
          ["custompbgcolor"] = "0.5,0.2,0.2,0",
          ["txthpright"] = "none",
          ["showRest"] = "1",
          ["custombgcolor"] = "0.5,0.2,0.2,0",
          ["showtooltip"] = "0",
          ["manacolor"] = "0.1,0.1,0.4,1",
          ["manatick"] = "1",
          ["width"] = "367",
          ["customcolor"] = "0.2,0.4,0,1",
        },
        ["manacolor"] = "0,0.1,1,1",
        ["group"] = {
          ["defcolor"] = "0",
        },
        ["custombgcolor"] = "0.1,0,0,0",
        ["custompbgcolor"] = "0.5,0.2,0.2,0",
        ["custom"] = "1",
        ["disable"] = "1",
      },
      ["buffs"] = {
        ["textinside"] = "1",
        ["fontsize"] = "1",
        ["size"] = "20",
      },
      ["bars"] = {
        ["count_color"] = "1,1,0.6,1",
        ["font"] = "Interface\\AddOns\\pfUI\\fonts\\Expressway.ttf",
        ["bar6"] = {
          ["icon_size"] = "25",
          ["spacing"] = "2",
          ["background"] = "0",
        },
        ["bind_color"] = "1,0.9,0.9,1",
        ["bar4"] = {
          ["enable"] = "0",
        },
        ["macro_size"] = "7",
        ["bar3"] = {
          ["icon_size"] = "25",
          ["spacing"] = "2",
          ["background"] = "0",
          ["formfactor"] = "12 x 1",
        },
        ["pagemaster"] = "0",
        ["bar5"] = {
          ["icon_size"] = "25",
          ["spacing"] = "2",
          ["background"] = "0",
          ["formfactor"] = "12 x 1",
        },
        ["bar1"] = {
          ["icon_size"] = "25",
          ["spacing"] = "2",
          ["background"] = "0",
        },
        ["bind_size"] = "9",
      },
      ["global"] = {
        ["pixelperfect"] = "7",
        ["font_combat"] = "Interface\\AddOns\\pfUI\\fonts\\Expressway.ttf",
        ["font_unit"] = "Interface\\AddOns\\pfUI\\fonts\\Myriad-Pro.ttf",
        ["autorepair"] = "1",
        ["font_size"] = "14",
        ["autosell"] = "1",
        ["profile"] = "KRAVINOFF MAIN",
      },
      ["castbar"] = {
        ["player"] = {
          ["width"] = "160",
          ["showicon"] = "1",
        },
        ["target"] = {
          ["width"] = "100",
        },
      },
      ["chat"] = {
        ["global"] = {
          ["tabmouse"] = "1",
          ["tabdock"] = "1",
          ["fadeout"] = "1",
          ["background"] = "0.3,0.3,0.3,0",
        },
      },
      ["tooltip"] = {
        ["position"] = "free",
      },
      ["abuttons"] = {
        ["position"] = "top",
      },
      ["panel"] = {
        ["other"] = {
          ["minimap"] = "none",
        },
        ["hide_microbar"] = "1",
        ["micro"] = {
          ["enable"] = "1",
        },
        ["left"] = {
          ["right"] = "exp",
          ["left"] = "zone",
        },
        ["xp"] = {
          ["xp_always"] = "1",
          ["dont_overlap"] = "1",
          ["xp_anchor"] = "__NONONIL__",
          ["xp_color"] = "0.4,0.9,0.2,1",
          ["xp_timeout"] = "3",
          ["xp_width"] = "230",
          ["xp_mode"] = "HORIZONTAL",
          ["xp_height"] = "7",
          ["rest_color"] = "0.5,0.7,1,0.4",
        },
      },
      ["version"] = "5.4.17",
      ["CustomMedia"] = {
        ["color"] = "1,1,1,0.5",
        ["selectimg"] = "Default",
      },
      ["appearance"] = {
        ["castbar"] = {
          ["castbarcolor"] = "0.9,0.8,0.3,0.8",
        },
        ["minimap"] = {
          ["mouseoverzone"] = "0",
        },
        ["border"] = {
          ["force_blizz"] = "1",
          ["background"] = "0,0,0,0.3",
        },
        ["worldmap"] = {
          ["mapreveal"] = "1",
        },
      },
    },
  },
}
