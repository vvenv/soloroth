#!/bin/bash
# Starts the local server (MariaDB, realmd, mangosd) when it is not running,
# then the game client. The server keeps running after the client closes;
# tools/macos/stop-server.sh stops it.
#
#   tools/macos/play.sh                 server + client
#   tools/macos/play.sh --server-only   just the server
#   tools/macos/play.sh --no-client     server + visual/UI install, no client
#
# The client logs in by itself with the account in benilla-config/login.env
# (WOW_USER, WOW_PASS, and optionally WOW_CHAR to go straight into the world
# as that character). AccountLogin is never shown: without a usable login.env
# this script asks once (TTY, or an osascript dialog when there is no
# terminal), checks against the server and saves it; with no account on the
# server yet it creates one (PLAYER, with GM rights). Cancelling or a failed
# ask refuses to start the client. Soloroth.app collects the same fields in
# its launcher window instead.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
bash "$root/tools/macos/start-server.sh"
[ "${1:-}" = "--server-only" ] && exit 0

# shellcheck source=bundle.sh
source "$root/tools/macos/bundle.sh"
client="$(resolve_benilla_bin)"
[ -n "$client" ] && [ -x "$client" ] || {
  echo "no client build — try: ./do.sh build iter   # or build client" >&2
  exit 1
}
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
    local char=""
    if [ -f "$login" ]; then
        char="$(sed -n 's/^WOW_CHAR=//p' "$login" | head -n1)"
    fi
    ( umask 077; printf '%s\n' \
        "WOW_USER=$1" \
        "WOW_PASS=$2" \
        "WOW_CHAR=${char}" \
        "# WOW_CHAR=角色名  (进游戏时跳过角色选择)" \
        > "$login" )
    echo "saved the login to $login"
}

login_ready() {
    local key value user="" pass=""
    [ -f "$login" ] || return 1
    while IFS='=' read -r key value || [ -n "$key" ]; do
        key="${key%$'\r'}"
        value="${value%$'\r'}"
        case "$key" in ''|'#'*) continue ;; esac
        case "$key" in
            WOW_USER) user="$value" ;;
            WOW_PASS) pass="$value" ;;
        esac
    done < "$login"
    [ -n "$user" ] && [ -n "$pass" ]
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
    [ -z "$user" ] && [ -f "$login" ] && user="$(sed -n 's/^WOW_USER=//p' "$login" | head -n1)"
    local prompt="输入游戏账号，以后自动登录"
    for _ in 1 2 3; do
        user="$(ask "$prompt" "${user:-PLAYER}")" || return 1
        pass="$(ask "账号 $user 的密码" "" hidden)" || return 1
        if printf '%s\n%s\n' "$user" "$pass" | python3 "$root/tools/macos/check-login.py"; then
            save_login "$(printf '%s' "$user" | tr '[:lower:]' '[:upper:]')" "$pass"
            return 0
        fi
        prompt="账号或密码不对，请重新输入账号"
        [ -t 0 ] && echo "$prompt" >&2
    done
    return 1
}

# HD creature / world overlays (always on when the pack is downloaded).
bash "$root/tools/macos/apply-visual.sh"
# Prune leftover product Lua / patch-S, then enchant-scroll Spell.dbc
# (Data/patch-T.MPQ); same install as start-client.sh.
install_product_ui
rebuild_enchant_scrolls_patch
# Soloroth.app's launcher window starts the server itself, then runs the
# client via start-client.sh. Account is collected in the launcher sheet.
[ "${1:-}" = "--no-client" ] && exit 0

if ! login_ready; then
    first_login || {
        echo "no account saved — not starting the client (AccountLogin is never shown)" >&2
        exit 1
    }
fi
export_client_env
cd "$root"
exec "$(resolve_client "$client")" "$@"
