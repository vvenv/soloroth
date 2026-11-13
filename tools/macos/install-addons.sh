#!/bin/bash
# Installs the 1.12 addon set from this repository (Interface/AddOns) into
# the client's addon folder (benilla-config/AddOns): GMBox, !Solo and
# Achievements (the dungeon and bot panel, the single-player defaults, and
# the achievement window) and the vetted
# third-party addons (pfUI, pfQuest, Atlas, AtlasLoot, AtlasQuest, Bagshui,
# ShaguKill, ShaguNotify, SuperMacro, CleverMacro; see THIRD-PARTY-NOTICES.md).
# localize-addons.py then adds Chinese where an addon lacks it, on the
# installed copies.
#
# The first run also copies saved settings (Bagshui's excepted) from an old
# 1.12 zhCN client (../wow-data/client-zhCN/WTF/Account/ADMIN/SavedVariables,
# or OLD_SAVED=...) into benilla-config/saved, unless a settings file is
# already there; without one the addons start from !Solo's defaults.
#
#   tools/macos/install-addons.sh
#
# A new addon shows only after a full client restart, not after /reload.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
old_saved="${OLD_SAVED:-$root/../wow-data/client-zhCN/WTF/Account/ADMIN/SavedVariables}"
home="${BENILLA_HOME:-$root/benilla-config}"
dest="$home/AddOns"
mkdir -p "$dest" "$home/saved"

for dir in "$root"/Interface/AddOns/*/; do
    name="$(basename "$dir")"
    rsync -a --delete "$dir" "$dest/$name/"
    echo "addon $name"
done

# Chinese for the addons that lack it, and two AtlasLoot zhCN fixes, on the
# installed copies (see tools/macos/localize-addons.py).
python3 "$root/tools/macos/localize-addons.py" "$dest"

if [ -d "$old_saved" ]; then
    for f in "$old_saved"/*.lua; do
        name="$(basename "$f" .lua)"
        [ -d "$dest/$name" ] || continue
        # Bagshui stores its category and group names as text: the old
        # client's are English, so it starts fresh and names them in Chinese.
        [ "$name" = "Bagshui" ] && continue
        if [ ! -f "$home/saved/$name.lua" ]; then
            cp "$f" "$home/saved/$name.lua"
            echo "settings $name"
        fi
    done
fi
