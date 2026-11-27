#!/usr/bin/env bash
# Install Atlas floor-plan BLPs for native dungeon map tab (no Lua Atlas addon).
# Textures load as Interface\AddOns\Atlas\Images\Maps\<key> from benilla-config/AddOns.
#
#   tools/macos/install-atlas-maps.sh
#   (also run from prune-legacy-ui / install_product_ui)
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
home="${BENILLA_HOME:-$root/benilla-config}"
dest="$home/AddOns/Atlas/Images/Maps"

# Prefer a known backup of classic Atlas; fall back to any Atlas/Images/Maps nearby.
candidates=(
  "${WOW_DATA_ROOT:-$root/../wow-data}/vmangos-deploy/storage/mangosd/client-data/Interface/AddOns.bak-20260902-131804/Atlas/Images/Maps"
  "${WOW_DATA_ROOT:-$root/../wow-data}/addons/Atlas/Images/Maps"
  "$root/ui/world/Atlas/Images/Maps"
)

src=""
for c in "${candidates[@]}"; do
  if [ -d "$c" ] && ls "$c"/*.blp >/dev/null 2>&1; then
    src="$c"
    break
  fi
done

if [ -z "$src" ]; then
  echo "install-atlas-maps: no Atlas BLP source found — dungeon map tab will show legend only" >&2
  exit 0
fi

mkdir -p "$dest"
# Drop Lua/XML so prune + native UI never load Atlas as an AddOn.
rm -f "$home/AddOns/Atlas/"*.{lua,xml,toc} 2>/dev/null || true
# Copy maps (idempotent).
n=0
for f in "$src"/*.blp; do
  base="$(basename "$f")"
  if [ ! -f "$dest/$base" ] || ! cmp -s "$f" "$dest/$base"; then
    cp -f "$f" "$dest/$base"
    n=$((n + 1))
  fi
done
echo "install-atlas-maps: $dest ($n updated from $src)"
