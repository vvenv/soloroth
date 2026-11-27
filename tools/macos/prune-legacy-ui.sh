#!/bin/bash
# Prune leftover product Lua installs. UI is Rust (`soloroth-ui`); no patch-S / AddOns sync.
#
#   tools/macos/prune-legacy-ui.sh
#   tools/macos/prune-legacy-ui.sh --force   # same (kept for callers)
#   tools/macos/prune-legacy-ui.sh --world-only|--glue-only  # aliases; both prune
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
while [ $# -gt 0 ]; do
    case "$1" in
        --world-only|--glue-only|--force) ;;
        -*)
            echo "usage: tools/macos/prune-legacy-ui.sh [--world-only|--glue-only] [--force]" >&2
            exit 2
            ;;
        *)
            echo "usage: tools/macos/prune-legacy-ui.sh [--world-only|--glue-only] [--force]" >&2
            exit 2
            ;;
    esac
    shift
done

home="${BENILLA_HOME:-$root/benilla-config}"
dest="$home/AddOns"
patch="$root/Data/patch-S.MPQ"
stamp="$home/glue-patch.stamp"

echo "product UI is Rust (soloroth-ui) — no world AddOns / patch-S build"

if [ -f "$patch" ]; then
    rm -f "$patch"
    echo "removed leftover $patch"
fi
rm -f "$stamp"

if [ -d "$dest" ]; then
    for name in '!Solo' pfUI AtlasLoot Bots Companions Dungeon Farm GMBox Items Teleport Achievements; do
        if [ -d "$dest/$name" ]; then
            rm -rf "$dest/$name"
            echo "removed leftover AddOn $name"
        fi
    done
    # Strip Atlas Lua/XML/toc but keep Images/Maps for native dungeon atlas.
    if [ -d "$dest/Atlas" ]; then
        find "$dest/Atlas" -maxdepth 1 -type f \( -name '*.lua' -o -name '*.xml' -o -name '*.toc' \) -delete
        echo "stripped Atlas Lua (maps kept for native UI)"
    fi
fi

# Art-only media for Rust UI (pfUI bar textures); keep `soloroth` out of the prune list above.
bash "$root/tools/macos/install-soloroth-media.sh"
bash "$root/tools/macos/install-atlas-maps.sh"
