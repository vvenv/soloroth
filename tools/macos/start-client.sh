#!/bin/bash
# Starts the game client only (server must already be up). Installs product UI
# (world + glue) and the enchant-scroll Spell.dbc patch so edits are picked up
# without a full play.sh — Soloroth.app's「开始游戏」uses this path when the
# server is already ready.
#
#   tools/macos/start-client.sh
#
# Picks the newer of release/benilla and play/benilla under client-target
# (iter builds write play/). Override with SOLOROTH_CLIENT_PROFILE=release|play.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=bundle.sh
source "$root/tools/macos/bundle.sh"
client="$(resolve_benilla_bin)"
[ -n "$client" ] && [ -x "$client" ] || {
  echo "no client build — try: tools/macos/build-classic.sh iter   # or client" >&2
  exit 1
}
install_product_ui
rebuild_enchant_scrolls_patch
export_client_env
cd "$root"
exec "$(resolve_client "$client")" "$@"
