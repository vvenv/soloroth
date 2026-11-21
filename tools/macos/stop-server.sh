#!/bin/bash
# Stops the local game server (mangosd, then realmd). MariaDB keeps running;
# add --all to stop it too.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
logs="$root/server/logs"

kill_holder() {
    local f="$logs/$1.holder.pid" pid
    [ -f "$f" ] || return 0
    pid="$(tr -d '[:space:]' < "$f")"
    [ -n "$pid" ] || return 0
    kill "$pid" 2>/dev/null || true
    rm -f "$f"
}

if pgrep -x mangosd >/dev/null; then
    echo "server shutdown 1" > "$logs/mangosd.stdin"
    for _ in $(seq 1 30); do pgrep -x mangosd >/dev/null || break; sleep 1; done
    pkill -x mangosd 2>/dev/null || true
fi
pkill -x realmd 2>/dev/null || true
# Wait for it: start-server.sh skips realmd while its port is still taken.
for _ in $(seq 1 30); do pgrep -x realmd >/dev/null || break; sleep 0.5; done
kill_holder mangosd
kill_holder realmd
if [ "${1:-}" = "--all" ] && [ -f "$logs/mariadb.pid" ]; then
    kill "$(cat "$logs/mariadb.pid")" 2>/dev/null || true
fi
echo "server stopped"
