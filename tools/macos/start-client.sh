#!/bin/bash
# Starts the game client only (server and glue patches must already be up).
# The launcher window uses this so it can stay open while the game runs.
#
#   tools/macos/start-client.sh
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
client="$root/release/build/macos/client-target/release/benilla"
[ -x "$client" ] || { echo "no client build: tools/macos/build-classic.sh client" >&2; exit 1; }
# shellcheck source=bundle.sh
source "$root/tools/macos/bundle.sh"
export_client_env
cd "$root"
exec "$(resolve_client "$client")" "$@"
