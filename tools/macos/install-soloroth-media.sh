#!/bin/bash
# Deprecated alias: product bar/glow textures ship in Data/patch-M.MPQ.
#
#   tools/macos/install-soloroth-media.sh
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
exec python3 "$root/tools/macos/build-product-media.py" "$root/Data"
