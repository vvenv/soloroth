#!/bin/bash
# Starts the game client only (server must already be up). Rebuilds the glue
# skin patch and enchant-scroll Spell.dbc patch so edits are picked up without
# a full play.sh — Soloroth.app's「开始游戏」uses this path when the server is
# already ready.
#
#   tools/macos/start-client.sh
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
client="$root/release/build/macos/client-target/release/benilla"
[ -x "$client" ] || { echo "no client build: tools/macos/build-classic.sh client" >&2; exit 1; }
# shellcheck source=bundle.sh
source "$root/tools/macos/bundle.sh"
rebuild_glue_patch
rebuild_enchant_scrolls_patch
export_client_env
cd "$root"
exec "$(resolve_client "$client")" "$@"
