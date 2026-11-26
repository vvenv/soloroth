#!/bin/bash
# Install Soloroth product UI: world addons into $BENILLA_HOME/AddOns and the
# glue skin into Data/patch-S.MPQ. Skips a side when sources are unchanged
# (stamp + mtimes); use --force to always rebuild both.
#
#   ui/install.sh              # world + glue (default; incremental)
#   ui/install.sh --world-only
#   ui/install.sh --glue-only
#   ui/install.sh --force      # with any mode
#
# World: sync ui/world → AddOns, inject ui/shared/Tokens.lua into !Solo,
# localize Chinese on the installed copies, and on first run copy old
# SavedVariables when present. Glue: rebuild patch-S (WOW_STOCK_UI=1 removes
# it; login.env / WOW_SHOW_LOGIN_UI pick show/hide). New world files need a
# full client restart, not /reload.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
mode=all
force=0
while [ $# -gt 0 ]; do
    case "$1" in
        --world-only) mode=world ;;
        --glue-only) mode=glue ;;
        --force) force=1 ;;
        -*)
            echo "usage: ui/install.sh [--world-only|--glue-only] [--force]" >&2
            exit 2
            ;;
        *)
            echo "usage: ui/install.sh [--world-only|--glue-only] [--force]" >&2
            exit 2
            ;;
    esac
    shift
done

home="${BENILLA_HOME:-$root/benilla-config}"
dest="$home/AddOns"
shared="$root/ui/shared/Tokens.lua"
tokens_name=Tokens.lua

# True when any file under $1 is newer than $2, or $2 is missing.
# Extra args are directory names to prune (e.g. __pycache__).
_tree_newer_than() {
    local src="$1" ref="$2"
    shift 2
    [ -e "$ref" ] || return 0
    local find_args=( "$src" ) d
    for d in "$@"; do
        find_args+=( -name "$d" -prune -o )
    done
    find_args+=( -type f ! -name '.DS_Store' -newer "$ref" -print -quit )
    [ -n "$(find "${find_args[@]}" 2>/dev/null)" ]
}

world_stale() {
    [ "$force" -eq 1 ] && return 0
    [ -d "$dest" ] || return 0
    [ -f "$dest/!Solo/$tokens_name" ] || return 0
    if [ -f "$shared" ] && [ "$shared" -nt "$dest/!Solo/$tokens_name" ]; then
        return 0
    fi
    local dir name f rel
    for dir in "$root"/ui/world/*/; do
        name="$(basename "$dir")"
        [ -d "$dest/$name" ] || return 0
        while IFS= read -r -d '' f; do
            rel="${f#"$root/ui/world/$name"/}"
            if [ ! -e "$dest/$name/$rel" ] || [ "$f" -nt "$dest/$name/$rel" ]; then
                return 0
            fi
        done < <(find "$dir" -type f ! -name '.DS_Store' -print0 2>/dev/null)
    done
    for dir in "$dest"/*/; do
        name="$(basename "$dir")"
        [ -d "$root/ui/world/$name" ] || return 0
    done
    return 1
}

glue_login_arg() {
    # Show the in-game form when asked, when there is no login.env, or when
    # the file has no account (empty WOW_USER): hide+empty would black-screen
    # forever (KillLoginPage, nothing to auto-submit). `|| [ -n "$key" ]`
    # keeps the last line when the file has no trailing newline — bash `read`
    # otherwise drops it (so a lone WOW_SHOW_LOGIN_UI=1 never took effect).
    local login="$home/login.env" key value show="" user=""
    if [ -f "$login" ]; then
        while IFS='=' read -r key value || [ -n "$key" ]; do
            key="${key%$'\r'}"
            value="${value%$'\r'}"
            case "$key" in ''|'#'*) continue ;; esac
            case "$key" in
                WOW_SHOW_LOGIN_UI) show="$value" ;;
                WOW_USER) user="$value" ;;
            esac
        done < "$login"
    fi
    show="${WOW_SHOW_LOGIN_UI:-$show}"
    case "$show" in
        1|true|yes) echo --show-login-ui ;;
        0|false|no) echo --hide-login-ui ;;
        *)
            if [ ! -f "$login" ] || [ -z "$user" ]; then echo --show-login-ui
            else echo --hide-login-ui
            fi
            ;;
    esac
}

glue_stale() {
    local patch="$root/Data/patch-S.MPQ"
    local stamp="$home/glue-patch.stamp"
    local want
    [ "$force" -eq 1 ] && return 0
    if [ "${WOW_STOCK_UI:-}" = 1 ]; then
        [ -f "$patch" ] && return 0
        [ -f "$stamp" ] || return 1
        [ "$(cat "$stamp" 2>/dev/null || true)" = "removed" ] && return 1
        return 0
    fi
    want="$(glue_login_arg)"
    [ -f "$patch" ] || return 0
    [ -f "$stamp" ] || return 0
    [ "$(cat "$stamp" 2>/dev/null || true)" = "$want" ] || return 0
    _tree_newer_than "$root/ui/glue" "$patch" __pycache__ && return 0
    _tree_newer_than "$root/ui/shared" "$patch" && return 0
    return 1
}

install_world() {
    local old_saved="${OLD_SAVED:-$root/../wow-data/client-zhCN/WTF/Account/ADMIN/SavedVariables}"
    local dir name f
    if ! world_stale; then
        echo "world ui up to date"
        return 0
    fi
    mkdir -p "$dest" "$home/saved"

    for dir in "$root"/ui/world/*/; do
        name="$(basename "$dir")"
        rsync -a --delete "$dir" "$dest/$name/"
        echo "addon $name"
    done

    for dir in "$dest"/*/; do
        name="$(basename "$dir")"
        if [ ! -d "$root/ui/world/$name" ]; then
            rm -rf "$dir"
            echo "removed $name"
        fi
    done

    if [ -f "$shared" ]; then
        mkdir -p "$dest/!Solo"
        cp -f "$shared" "$dest/!Solo/$tokens_name"
        echo "tokens !Solo/$tokens_name"
    fi

    python3 "$root/tools/macos/localize-addons.py" "$dest"

    if [ -d "$old_saved" ]; then
        for f in "$old_saved"/*.lua; do
            name="$(basename "$f" .lua)"
            [ -d "$dest/$name" ] || continue
            if [ ! -f "$home/saved/$name.lua" ]; then
                cp "$f" "$home/saved/$name.lua"
                echo "settings $name"
            fi
        done
    fi
}

install_glue() {
    local patch="$root/Data/patch-S.MPQ"
    local stamp="$home/glue-patch.stamp"
    local arg
    mkdir -p "$home"
    if ! glue_stale; then
        echo "glue ui up to date"
        return 0
    fi
    if [ "${WOW_STOCK_UI:-}" = 1 ]; then
        python3 "$root/ui/glue/build-patch.py" "$root/Data" --remove
        printf '%s\n' "removed" > "$stamp"
        return
    fi
    arg="$(glue_login_arg)"
    python3 "$root/ui/glue/build-patch.py" "$root/Data" "$arg"
    printf '%s\n' "$arg" > "$stamp"
}

case "$mode" in
    all) install_world; install_glue ;;
    world) install_world ;;
    glue) install_glue ;;
esac
