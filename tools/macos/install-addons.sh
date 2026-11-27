#!/bin/bash
# Alias for tools/macos/prune-legacy-ui.sh (legacy product Lua / patch-S cleanup).
#
#   tools/macos/install-addons.sh
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
exec bash "$root/tools/macos/prune-legacy-ui.sh" "$@"
