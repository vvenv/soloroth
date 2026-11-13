#!/bin/bash
# Starts the local server (MariaDB, realmd, mangosd) when it is not running,
# then the game client. The server keeps running after the client closes;
# tools/macos/stop-server.sh stops it.
#
#   tools/macos/play.sh                 server + client
#   tools/macos/play.sh --server-only   just the server
#
# The client logs in by itself with the account in benilla-config/login.env
# (WOW_USER, WOW_PASS, and optionally WOW_CHAR to go straight into the world
# as that character). Without the file, the first launch asks for the account
# once (a dialog when there is no terminal, as from Soloroth.app), checks it
# against the server and saves it; with no account on the server yet it
# creates one (PLAYER, with GM rights). Cancelling shows the login screen.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
bash "$root/tools/macos/start-server.sh"
[ "${1:-}" = "--server-only" ] && exit 0

client="$root/release/build/macos/client-target/release/benilla"
[ -x "$client" ] || { echo "no client build: tools/macos/build-classic.sh client" >&2; exit 1; }
export BENILLA_HOME="$root/benilla-config"
login="$BENILLA_HOME/login.env"

ask() { # ask <prompt> <default> [hidden]
    if [ -t 0 ]; then
        local answer
        if [ -n "${3:-}" ]; then read -r -s -p "$1: " answer; echo >&2; else read -r -p "$1 [$2]: " answer; fi
        printf '%s' "${answer:-$2}"
    else
        osascript - "$1" "$2" "${3:-}" <<'EOF'
on run argv
    if item 3 of argv is "" then
        set r to display dialog (item 1 of argv) default answer (item 2 of argv) with title "Soloroth"
    else
        set r to display dialog (item 1 of argv) default answer "" with title "Soloroth" with hidden answer
    end if
    return text returned of r
end run
EOF
    fi
}

save_login() {
    mkdir -p "$BENILLA_HOME"
    ( umask 077; printf 'WOW_USER=%s\nWOW_PASS=%s\n# WOW_CHAR=角色名  (进游戏时跳过角色选择)\n' "$1" "$2" > "$login" )
    echo "saved the login to $login"
}

first_login() {
    local maria="$root/server/mariadb/bin/mariadb" probe user pass n
    probe="$(sed -n 's/^WOW_USER=//p' "$root/.probe-identity" 2>/dev/null || true)"
    n="$("$maria" -h127.0.0.1 -uroot --skip-ssl -N -B classic_realmd \
        -e "SELECT COUNT(*) FROM account WHERE username <> UPPER('$probe')")"
    if [ "$n" = 0 ]; then
        pass="$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 12)"
        bash "$root/tools/macos/create-account.sh" PLAYER "$pass" gm >/dev/null
        save_login PLAYER "$pass"
        return
    fi
    user="$(sed -n 's/^accountName = "\(.*\)"$/\1/p' "$BENILLA_HOME/config.toml" 2>/dev/null || true)"
    local prompt="第一次启动：输入游戏账号，以后自动登录"
    for _ in 1 2 3; do
        user="$(ask "$prompt" "${user:-PLAYER}")" || return 0
        pass="$(ask "账号 $user 的密码" "" hidden)" || return 0
        if printf '%s\n%s\n' "$user" "$pass" | python3 "$root/tools/macos/check-login.py"; then
            save_login "$(printf '%s' "$user" | tr '[:lower:]' '[:upper:]')" "$pass"
            return
        fi
        prompt="账号或密码不对，请重新输入账号"
        [ -t 0 ] && echo "$prompt" >&2
    done
}

[ -f "$login" ] || first_login
# Optional HD / model overlays from benilla-config/visual.env
bash "$root/tools/macos/apply-visual.sh"
# pfUI-style login / character screens: Data/patch-S.MPQ, rebuilt off the
# stock GlueXML.toc each launch; WOW_STOCK_UI=1 drops it with benilla's layer.
if [ "${WOW_STOCK_UI:-}" = 1 ]; then
    python3 "$root/tools/glue-skin/build-patch.py" "$root/Data" --remove
else
    python3 "$root/tools/glue-skin/build-patch.py" "$root/Data"
fi
# 16:9 HD loading screens (blue bar): Data/patch-L.MPQ. Built once into
# ../wow-data/loading-screens/ and copied here; WOW_STOCK_LOADING=1 drops it.
if [ "${WOW_STOCK_LOADING:-}" = 1 ]; then
    python3 "$root/tools/loading-screens/build-patch.py" "$root/Data" --remove
else
    python3 "$root/tools/loading-screens/build-patch.py" "$root/Data"
fi
# shellcheck source=bundle.sh
source "$root/tools/macos/bundle.sh"
export_client_env
# Soloroth.app starts the server and the account itself, then execs the
# client in this process so the Dock keeps a single Soloroth icon.
[ "${1:-}" = "--no-client" ] && exit 0
cd "$root"
exec "$(resolve_client "$client")" "$@"
