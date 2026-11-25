#!/bin/bash
# Forwards to ui/install.sh (world + glue). Prefer ./do.sh ui or ui/install.sh.
#
#   tools/macos/install-addons.sh
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
exec bash "$root/ui/install.sh" "$@"
