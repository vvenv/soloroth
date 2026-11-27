#!/bin/bash
# Deprecated alias: Atlas floor plans ship in Data/patch-M.MPQ.
#
#   tools/macos/install-atlas-maps.sh
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
exec python3 "$root/tools/macos/build-product-media.py" "$root/Data"
