#!/bin/bash
# Prune leftover product Lua installs and loose media under AddOns.
# UI is Rust (`soloroth-ui`); textures ship in Data/patch-M.MPQ.
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

echo "product UI is Rust (soloroth-ui) — media in patch-M; no world AddOns / patch-S"

if [ -f "$patch" ]; then
    rm -f "$patch"
    echo "removed leftover $patch"
fi
rm -f "$stamp"

if [ -d "$dest" ]; then
    for name in '!Solo' pfUI AtlasLoot Bots Companions Dungeon Farm GMBox Items Teleport Achievements \
        soloroth Atlas; do
        if [ -d "$dest/$name" ]; then
            rm -rf "$dest/$name"
            echo "removed leftover AddOn $name"
        fi
    done
    # Drop empty AddOns tree (and .DS_Store-only leftovers).
    if [ -d "$dest" ] && [ -z "$(find "$dest" -type f ! -name '.DS_Store' 2>/dev/null | head -1)" ]; then
        rm -rf "$dest"
        echo "removed empty $dest"
    fi
fi
