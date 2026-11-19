#!/usr/bin/env python3
"""Simplified Chinese for the third-party addons, applied to the installed copies.

  tools/macos/localize-addons.py <AddOns folder>

install-addons.sh runs this after copying the addons, so a reinstall keeps
it. Every step is idempotent and prints what it changed. The addons' own
folder (../wow-data/addons) is never touched.

  AtlasLoot    two bugs of its zhCN files: a `true` value in locale.cn.lua,
               which AceLocale allows only in the base locale, and TBC loot
               table titles in loottables.cn.lua for tables this 1.12 build
               lacks; either one stops the file on a Chinese client.
"""
import os
import re
import sys


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
    atlasloot(sys.argv[1])
    return 0


if __name__ == "__main__":
    sys.exit(main())
