#!/bin/bash
# Download Project Reforged creature (and optional HD) MPQs into
# ../wow-data/visual-patches/. Does not touch the git repo. Rerun to resume.
#
#   tools/macos/fetch-visual-patches.sh           # Patch-C → reforged-creatures, hd
#   tools/macos/fetch-visual-patches.sh --hd      # also B+D+E+G (+A as patch-H) → hd
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
wow_data="${WOW_DATA_ROOT:-$root/../wow-data}"
base="$wow_data/visual-patches"
cache="$base/_cache"
mkdir -p "$cache" "$base/reforged-creatures" "$base/improved-models" "$base/hd"

R2="https://pub-0f05631d243e4046993fc02ca7be9542.r2.dev/patches"

# Parallel 10 MiB ranges, checked against R2's multipart ETag; a rerun repairs
# only the parts still missing. A preallocating resume (aria2, then curl -C)
# once left zero-filled holes: benilla logged "sector 0 is empty", creatures
# went invisible, and a holed CreatureModelData.dbc turned every mob into a cube.
fetch() {
    local url="$1" out="$2"
    [ -f "$out.ok" ] && [ "$out.ok" -nt "$out" ] && { echo "have $(basename "$out")"; return 0; }
    echo "download $(basename "$out")"
    python3 "$root/tools/macos/mpq-fetch.py" "$url" "$out" || {
        echo "$(basename "$out"): incomplete; rerun this script to resume" >&2
        exit 1
    }
    touch "$out.ok"
}

# fetch_link <url> <letter> <profile...>
fetch_link() {
    local url="$1" letter="$2"
    shift 2
    local raw="$cache/patch-$letter.MPQ" p
    fetch "$url" "$raw"
    for p in "$@"; do
        ln -sfn "$raw" "$base/$p/patch-$letter.MPQ"
    done
}

# Creatures only (~2 GB).
fetch_link "$R2/patch-C.mpq" C reforged-creatures hd

if [ "${1:-}" = "--hd" ]; then
    # Environment set B+D+E must stay together. Reforged patch-A would collide
    # with zhCN locale patch-A.MPQ, so it mounts as patch-H.
    fetch_link "$R2/patch-B.mpq" B hd
    fetch_link "$R2/patch-D.mpq" D hd
    fetch_link "$R2/patch-E.mpq" E hd
    fetch_link "$R2/patch-G.mpq" G hd
    fetch_link "$R2/kronos/patch-A.mpq" H hd
fi

# Improved Models: upstream releases use adf.ly; drop the Standard MPQ here yourself
# as patch-C.MPQ (or any free letter) when you have it.
if [ ! -e "$base/improved-models/patch-C.MPQ" ] && [ ! -e "$base/improved-models/patch-I.MPQ" ]; then
    printf '%s\n' \
        "Put Koward Improved Models (Standard 1.12.1) here as patch-C.MPQ or patch-I.MPQ." \
        "https://github.com/Koward/Improved_Models/releases" \
        > "$base/improved-models/README.txt"
    echo "improved-models: waiting for manual MPQ (see README.txt there)"
fi

echo
echo "Profiles ready under $base"
echo "  tools/macos/apply-visual.sh reforged-creatures"
echo "  tools/macos/apply-visual.sh hd"
echo "  tools/macos/apply-visual.sh vanilla"
