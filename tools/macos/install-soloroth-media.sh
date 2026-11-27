#!/bin/bash
# Install art-only media for soloroth-ui (pfUI bar/glow textures).
#
#   tools/macos/install-soloroth-media.sh
#
# Copies into $BENILLA_HOME/AddOns/soloroth/img so the host resolves
# Interface\AddOns\soloroth\img\bar (no Lua UI).
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
src="$root/client/crates/soloroth-ui/media/img"
home="${BENILLA_HOME:-$root/benilla-config}"
dest="$home/AddOns/soloroth/img"

[ -d "$src" ] || {
    echo "install-soloroth-media: missing $src" >&2
    exit 1
}

mkdir -p "$dest"
updated=0
for f in bar.tga glow2.tga; do
    if [ -f "$src/$f" ]; then
        if [ ! -f "$dest/$f" ] || ! cmp -s "$src/$f" "$dest/$f"; then
            cp -f "$src/$f" "$dest/$f"
            updated=$((updated + 1))
        fi
    fi
done
# Minimal toc so the folder is a recognizable AddOn root (disabled / never loaded as Lua).
toc="$home/AddOns/soloroth/soloroth.toc"
if [ ! -f "$toc" ]; then
    cat >"$toc" <<'EOF'
## Interface: 11200
## Title: Soloroth Media
## Notes: Art only for Rust native UI (no Lua).
## LoadOnDemand: 1
EOF
fi
echo "install-soloroth-media: $dest ($updated updated)"
