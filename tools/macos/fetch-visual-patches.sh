#!/bin/bash
# Download Project Reforged creature (and optional HD) MPQs into
# ../wow-data/visual-patches/. Does not touch the git repo.
#
#   tools/macos/fetch-visual-patches.sh           # Patch-C → reforged-creatures
#   tools/macos/fetch-visual-patches.sh --hd      # also B+D+E+G (+A as patch-H)
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
wow_data="${WOW_DATA_ROOT:-$root/../wow-data}"
base="$wow_data/visual-patches"
cache="$base/_cache"
mkdir -p "$cache" "$base/reforged-creatures" "$base/improved-models" "$base/hd"

R2="https://pub-0f05631d243e4046993fc02ca7be9542.r2.dev/patches"
have_aria2=0
command -v aria2c >/dev/null && have_aria2=1

fetch() {
    local url="$1" out="$2"
    if [ -f "$out" ] && [ -s "$out" ]; then
        echo "have $(basename "$out") ($(du -h "$out" | awk '{print $1}'))"
        return 0
    fi
    echo "download $(basename "$out")"
    if [ "$have_aria2" -eq 1 ]; then
        aria2c -c -x 16 -s 16 -k 1M --file-allocation=none \
            --console-log-level=notice -o "$(basename "$out")" -d "$(dirname "$out")" "$url"
    else
        curl -fL --progress-bar -o "$out.part" "$url"
        mv "$out.part" "$out"
    fi
}

# Creatures only (~2 GB).
fetch "$R2/patch-C.mpq" "$cache/patch-C.MPQ"
ln -sfn "$cache/patch-C.MPQ" "$base/reforged-creatures/patch-C.MPQ"
ln -sfn "$cache/patch-C.MPQ" "$base/hd/patch-C.MPQ"

if [ "${1:-}" = "--hd" ]; then
    # Environment set B+D+E must stay together. Reforged patch-A would collide
    # with zhCN locale patch-A.MPQ, so it mounts as patch-H.
    fetch "$R2/patch-B.mpq" "$cache/patch-B.MPQ"
    fetch "$R2/patch-D.mpq" "$cache/patch-D.MPQ"
    fetch "$R2/patch-E.mpq" "$cache/patch-E.MPQ"
    fetch "$R2/patch-G.mpq" "$cache/patch-G.MPQ"
    fetch "$R2/kronos/patch-A.mpq" "$cache/patch-H.MPQ"
    ln -sfn "$cache/patch-B.MPQ" "$base/hd/patch-B.MPQ"
    ln -sfn "$cache/patch-D.MPQ" "$base/hd/patch-D.MPQ"
    ln -sfn "$cache/patch-E.MPQ" "$base/hd/patch-E.MPQ"
    ln -sfn "$cache/patch-G.MPQ" "$base/hd/patch-G.MPQ"
    ln -sfn "$cache/patch-H.MPQ" "$base/hd/patch-H.MPQ"
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
