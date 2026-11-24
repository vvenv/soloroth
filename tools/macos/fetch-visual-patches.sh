#!/bin/bash
# Download the Project Reforged HD pack into ../wow-data/visual-patches/hd/.
# Does not touch the git repo. Rerun to resume. Always the full set (creatures,
# environment, items); Soloroth mounts this pack on every launch.
#
#   tools/macos/fetch-visual-patches.sh
#   ./do.sh visual
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
wow_data="${WOW_DATA_ROOT:-$root/../wow-data}"
base="$wow_data/visual-patches"
cache="$base/_cache"
mkdir -p "$cache" "$base/hd"

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

# fetch_link <url> <letter>
fetch_link() {
    local url="$1" letter="$2"
    local raw="$cache/patch-$letter.MPQ"
    fetch "$url" "$raw"
    ln -sfn "$raw" "$base/hd/patch-$letter.MPQ"
}

# Creatures (~2 GB) plus environment / items. Reforged patch-A would collide
# with zhCN locale patch-A.MPQ, so it mounts as patch-H.
fetch_link "$R2/patch-C.mpq" C
fetch_link "$R2/patch-B.mpq" B
fetch_link "$R2/patch-D.mpq" D
fetch_link "$R2/patch-E.mpq" E
fetch_link "$R2/patch-G.mpq" G
fetch_link "$R2/kronos/patch-A.mpq" H

echo
echo "HD pack ready under $base/hd"
echo "  tools/macos/apply-visual.sh   # mount on next launch (play.sh does this)"
