#!/bin/bash
# Install Soloroth product UI: world addons into $BENILLA_HOME/AddOns and the
# glue skin into Data/patch-S.MPQ. One entry for both; play / start-client / setup
# call this so developers do not track two install paths.
#
#   ui/install.sh              # world + glue (default)
#   ui/install.sh --world-only
#   ui/install.sh --glue-only
#
# World: sync ui/world → AddOns, localize Chinese on the installed copies, and
# on first run copy old SavedVariables when present. Glue: rebuild patch-S
# (WOW_STOCK_UI=1 removes it; login.env / WOW_SHOW_LOGIN_UI pick show/hide).
# New world files need a full client restart, not /reload.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
mode=all
case "${1:-}" in
    --world-only) mode=world; shift || true ;;
    --glue-only) mode=glue; shift || true ;;
    "" ) ;;
    -*)
        echo "usage: ui/install.sh [--world-only|--glue-only]" >&2
        exit 2
        ;;
esac

install_world() {
    local old_saved="${OLD_SAVED:-$root/../wow-data/client-zhCN/WTF/Account/ADMIN/SavedVariables}"
    local home="${BENILLA_HOME:-$root/benilla-config}"
    local dest="$home/AddOns"
    local dir name f
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
    local login="$root/benilla-config/login.env" key value show="" arg
    if [ "${WOW_STOCK_UI:-}" = 1 ]; then
        python3 "$root/ui/glue/build-patch.py" "$root/Data" --remove
        return
    fi
    if [ -f "$login" ]; then
        while IFS='=' read -r key value; do
            case "$key" in WOW_SHOW_LOGIN_UI) show="$value" ;; esac
        done < "$login"
    fi
    show="${WOW_SHOW_LOGIN_UI:-$show}"
    case "$show" in
        1|true|yes) arg=--show-login-ui ;;
        0|false|no) arg=--hide-login-ui ;;
        *)
            if [ ! -f "$login" ]; then arg=--show-login-ui
            else arg=--hide-login-ui
            fi
            ;;
    esac
    python3 "$root/ui/glue/build-patch.py" "$root/Data" "$arg"
}

case "$mode" in
    all) install_world; install_glue ;;
    world) install_world ;;
    glue) install_glue ;;
esac
