#!/usr/bin/env python3
"""Simplified Chinese for the third-party addons, applied to the installed copies.

  tools/macos/localize-addons.py <AddOns folder>

install-addons.sh runs this after copying the addons, so a reinstall keeps
it. Every step is idempotent and prints what it changed. The addons' own
folder (../wow-data/addons) is never touched.

  Bagshui      no zhCN at all: adds Locale/zhCN.lua (tools/macos/addons-zhCN).
  ShaguKill    the "kills to next level" line.
  ShaguNotify  the popup titles it writes itself.
  AtlasLoot    two bugs of its zhCN files: a `true` value in locale.cn.lua,
               which AceLocale allows only in the base locale, and TBC loot
               table titles in loottables.cn.lua for tables this 1.12 build
               lacks; either one stops the file on a Chinese client.
"""
import os
import re
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OVERLAY = os.path.join(HERE, "addons-zhCN")
MARK = "-- zhCN (tools/macos/localize-addons.py)"


def read(path):
    with open(path, encoding="utf-8-sig", errors="surrogateescape") as f:
        return f.read()


def write(path, text, bom=False):
    with open(path, "w", encoding="utf-8", errors="surrogateescape") as f:
        f.write(("﻿" if bom else "") + text)


def had_bom(path):
    with open(path, "rb") as f:
        return f.read(3) == b"\xef\xbb\xbf"


def replace_all(path, pairs, what):
    """Replace each (old, new) once; skip pairs already applied."""
    if not os.path.isfile(path):
        return
    text = read(path)
    new = text
    for old, rep in pairs:
        if old in new:
            new = new.replace(old, rep)
    if new != text:
        write(path, new, had_bom(path))
        print("localized " + what)


def bagshui(addons):
    locale = os.path.join(addons, "Bagshui", "Locale")
    if not os.path.isdir(locale):
        return
    shutil.copyfile(os.path.join(OVERLAY, "Bagshui", "Locale", "zhCN.lua"), os.path.join(locale, "zhCN.lua"))
    xml = os.path.join(locale, "Locales.xml")
    text = read(xml)
    if "zhCN.lua" not in text:
        text = text.replace('<Include file="enUS.lua" />', '<Include file="enUS.lua" />\n\t<Include file="zhCN.lua" />')
        write(xml, text)
    print("localized Bagshui")


ZH = 'GetLocale() == "zhCN"'


def shagu(addons):
    replace_all(os.path.join(addons, "ShaguKill", "ShaguKill.lua"), [
        ('UIErrorsFrame:AddMessage("next level: |cffffffaa~" .. ShaguKill.RemainingKills .. "|r kills.")',
         'UIErrorsFrame:AddMessage((' + ZH + ') and ("距离升级：约 |cffffffaa" .. ShaguKill.RemainingKills .. "|r 只怪") or ("next level: |cffffffaa~" .. ShaguKill.RemainingKills .. "|r kills."))'),
        ('UIErrorsFrame:AddMessage("pet: |cffffffaa~" .. ShaguKill.petRemainingKills .. "|r kills.")',
         'UIErrorsFrame:AddMessage((' + ZH + ') and ("宠物升级：约 |cffffffaa" .. ShaguKill.petRemainingKills .. "|r 只怪") or ("pet: |cffffffaa~" .. ShaguKill.petRemainingKills .. "|r kills."))'),
    ], "ShaguKill")
    trig = os.path.join(addons, "ShaguNotify", "trigger")
    replace_all(os.path.join(trig, "combat_survive.lua"), [
        ('libnotify:ShowPopup("I will survive!"', 'libnotify:ShowPopup((' + ZH + ') and "死里逃生！" or "I will survive!"'),
    ], "ShaguNotify (survive)")
    replace_all(os.path.join(trig, "levelup.lua"), [
        ('libnotify:ShowPopup("Level: " .. arg1', 'libnotify:ShowPopup(((' + ZH + ') and "等级：" or "Level: ") .. arg1'),
    ], "ShaguNotify (level up)")
    replace_all(os.path.join(trig, "exploration.lua"), [
        ('nil, "Discovered")', 'nil, (' + ZH + ') and "发现新区域" or "Discovered")'),
    ], "ShaguNotify (exploration)")


def atlasloot(addons):
    replace_all(os.path.join(addons, "AtlasLoot", "Locale", "locale.cn.lua"), [
        ('["Left-click to open AtlasLoot.\\nMiddle-click for AtlasLoot options.\\nRight-click and drag to move this button."] = true,',
         '["Left-click to open AtlasLoot.\\nMiddle-click for AtlasLoot options.\\nRight-click and drag to move this button."] = "左键打开 AtlasLoot。\\n中键打开 AtlasLoot 设置。\\n右键拖动可移动此按钮。",'),
    ], "AtlasLoot strings")
    path = os.path.join(addons, "AtlasLoot", "TableRegister", "loottables.cn.lua")
    if os.path.isfile(path):
        text = read(path)
        pat = re.compile(r'^(\s*)AtlasLoot_TableNames\["([^"]+)"\]\[1\] = *(".*?");?\s*$', re.M)
        new = pat.sub(r'\1if AtlasLoot_TableNames["\2"] then AtlasLoot_TableNames["\2"][1] = \3 end', text)
        if new != text:
            write(path, new, had_bom(path))
            print("localized AtlasLoot loot table titles")


def main():
    if len(sys.argv) != 2 or not os.path.isdir(sys.argv[1]):
        print(__doc__)
        return 2
    addons = sys.argv[1]
    bagshui(addons)
    shagu(addons)
    atlasloot(addons)
    return 0


if __name__ == "__main__":
    sys.exit(main())
