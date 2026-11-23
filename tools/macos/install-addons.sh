#!/bin/bash
# Installs the 1.12 addon set from this repository (Interface/AddOns) into
# the client's addon folder (benilla-config/AddOns): Teleport, Items, Companions,
# GMBox, Dungeon, Bots, !Solo and Achievements (teleport, items, pets/mounts, GM tools,
# the dungeon hub, the party button, single-player defaults, achievements)
# and the absorbed UI addons (pfUI, Atlas, AtlasLoot; bag sorting is inside
# pfUI; see THIRD-PARTY-NOTICES.md). localize-addons.py then adds Chinese
# where an addon lacks it, on the installed copies.
#
# The first run also copies saved settings from an old 1.12 zhCN client
# (../wow-data/client-zhCN/WTF/Account/ADMIN/SavedVariables, or OLD_SAVED=...)
# into benilla-config/saved, unless a settings file is already there;
# without one the addons start from !Solo's defaults.
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

# A removed addon stays loaded until its folder is gone.
for dir in "$dest"/*/; do
    name="$(basename "$dir")"
    if [ ! -d "$root/Interface/AddOns/$name" ]; then
        rm -rf "$dir"
        echo "removed $name"
    fi
done

# Chinese for the addons that lack it, and two AtlasLoot zhCN fixes, on the
# installed copies (see tools/macos/localize-addons.py).
python3 "$root/tools/macos/localize-addons.py" "$dest"

if [ -d "$old_saved" ]; then
    for f in "$old_saved"/*.lua; do
        name="$(basename "$f" .lua)"
        [ -d "$dest/$name" ] || continue
        if [ ! -f "$home/saved/$name.lua" ]; then
            cp "$f" "$home/saved/$name.lua"
            echo "settings $name"
        fi
    done
fi
