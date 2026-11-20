#!/bin/bash
# Starts the local Soloroth web admin (tools/macos/admin/server.py) on
# 127.0.0.1:8765 if it is not already listening, then opens it in the browser.
#
#   tools/macos/start-admin.sh
#   tools/macos/start-admin.sh --no-open   # only ensure it is up
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
port=8765
url="http://127.0.0.1:$port"
logs="$root/server/logs"
pidfile="$logs/admin.pid"
open_browser=1
[ "${1:-}" = "--no-open" ] && open_browser=0

mkdir -p "$logs"

listening() {
    lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1
}

if ! listening; then
    # Drop a stale pid file.
    if [ -f "$pidfile" ]; then
        old="$(cat "$pidfile" 2>/dev/null || true)"
        if [ -n "${old:-}" ] && kill -0 "$old" 2>/dev/null; then
            : # still alive but not listening yet
        else
            rm -f "$pidfile"
        fi
    fi
    if [ ! -f "$pidfile" ] || ! kill -0 "$(cat "$pidfile")" 2>/dev/null; then
        echo "starting admin on $url"
        # Same detach style as start-server.sh (nohup; macOS has no setsid(1)).
        nohup python3 "$root/tools/macos/admin/server.py" --port "$port" \
            >"$logs/admin.out" 2>&1 &
        echo $! >"$pidfile"
        for _ in $(seq 1 40); do
            listening && break
            sleep 0.1
        done
    fi
fi

if ! listening; then
    echo "admin did not start (see $logs/admin.out)" >&2
    exit 1
fi

if [ "$open_browser" -eq 1 ]; then
    open "$url"
fi
echo "$url"
