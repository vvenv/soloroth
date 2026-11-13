#!/bin/bash
# Apply (or clear) optional client visual patch MPQs on top of stock Data/.
#
#   tools/macos/apply-visual.sh                 # config.toml solorothVisual, else visual.env
#   tools/macos/apply-visual.sh vanilla         # stock models; saves the choice
#   tools/macos/apply-visual.sh reforged-creatures
#   tools/macos/apply-visual.sh --list          # profiles on disk
#
# In-game: Options → Graphics (or /visual). That writes the solorothVisual CVar;
# quit fully and relaunch so this script remounts the MPQs.
#
# Put patch MPQs in:
#   $WOW_DATA_ROOT/visual-patches/<profile>/patch-C.MPQ
# (any single-character patch-?.MPQ; do not reuse letters already used by the
# stock client, e.g. patch.MPQ / patch-2.MPQ / zhCN patch-A.MPQ).
#
# Env (same as setup-classic.sh):
#   WOW_DATA_ROOT  default ../wow-data
#   CLIENT_LOCALE  zhCN (default) or enUS
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
wow_data="${WOW_DATA_ROOT:-$root/../wow-data}"
locale="${CLIENT_LOCALE:-zhCN}"
home="${BENILLA_HOME:-$root/benilla-config}"
env_file="$home/visual.env"
toml="$home/config.toml"
patches_root="$wow_data/visual-patches"
managed="$root/Data/.soloroth-visual-managed"
die() { echo "error: $*" >&2; exit 1; }

case "$locale" in
    zhCN) client_data="$wow_data/client-zhCN/Data" ;;
    enUS) client_data="$wow_data/client/Data" ;;
    *) die "CLIENT_LOCALE is zhCN or enUS" ;;
esac

is_patch_glob() {
    local base lower mid
    base="$(basename "$1")"
    lower="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')"
    mid="${lower#patch-}"
    mid="${mid%.mpq}"
    [ "$lower" != "$mid" ] || return 1
    [ "${#mid}" -eq 1 ]
}

ensure_base_data() {
    mkdir -p "$root/Data"
    [ -d "$client_data" ] || die "missing $client_data (set WOW_DATA_ROOT)"
    local f name
    for f in "$client_data"/*.MPQ; do
        [ -e "$f" ] || continue
        name="$(basename "$f")"
        if [ -L "$root/Data/$name" ] || [ -e "$root/Data/$name" ]; then
            continue
        fi
        ln -s "$f" "$root/Data/$name"
        echo "link Data/$name (stock)"
    done
}

clear_managed() {
    [ -f "$managed" ] || return 0
    local name
    while IFS= read -r name || [ -n "$name" ]; do
        [ -n "$name" ] || continue
        if [ -L "$root/Data/$name" ]; then
            rm -f "$root/Data/$name"
            echo "unlink Data/$name"
        fi
    done < "$managed"
    rm -f "$managed"
}

read_cvar_profile() {
    [ -f "$toml" ] || return 0
    python3 - "$toml" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r'^solorothVisual\s*=\s*"([^"]*)"', text, re.M)
if m and m.group(1).strip():
    print(m.group(1).strip())
PY
}

read_env_profile() {
    local p=""
    if [ -f "$env_file" ]; then
        p="$(sed -n 's/^[[:space:]]*VISUAL_PROFILE=//p' "$env_file" | head -1 | tr -d '\r' | tr -d '"' | tr -d "'")"
    fi
    printf '%s' "$p"
}

read_profile() {
    local p
    p="$(read_cvar_profile)"
    [ -n "$p" ] || p="$(read_env_profile)"
    [ -n "$p" ] || p="vanilla"
    printf '%s' "$p"
}

save_profile() {
    local profile="$1"
    mkdir -p "$home"
    local example="$root/config/visual.env.example"
    if [ -f "$example" ]; then
        sed "s/^VISUAL_PROFILE=.*/VISUAL_PROFILE=$profile/" "$example" > "$env_file"
    else
        printf 'VISUAL_PROFILE=%s\n' "$profile" > "$env_file"
    fi
    set_cvar solorothVisual "$profile"
}

# set_cvar <name> <value>: writes into config.toml's [cvars], which the client
# reads at launch (the !Solo addon registers these CVars).
set_cvar() {
    mkdir -p "$home"
    python3 - "$toml" "$1" "$2" <<'PY'
import os, re, sys
path, name, value = sys.argv[1:4]
text = open(path, encoding="utf-8").read() if os.path.exists(path) else ""
line = '%s = "%s"' % (name, value)
pat = r'^%s\s*=.*$' % re.escape(name)
if re.search(pat, text, re.M):
    text = re.sub(pat, line, text, count=1, flags=re.M)
elif "[cvars]\n" in text:
    text = text.replace("[cvars]\n", "[cvars]\n" + line + "\n", 1)
else:
    text = "[cvars]\n" + line + "\n" + text
open(path, "w", encoding="utf-8").write(text)
PY
}

# Profiles with at least one patch-?.MPQ on disk, space-separated, vanilla first.
ready_profiles() {
    local out="vanilla" d f
    [ -d "$patches_root" ] || { printf '%s' "$out"; return; }
    for d in "$patches_root"/*/; do
        [ -d "$d" ] || continue
        [ "$(basename "$d")" = "_cache" ] && continue
        for f in "$d"*; do
            [ -e "$f" ] || continue
            if is_patch_glob "$f"; then
                out="$out $(basename "$d")"
                break
            fi
        done
    done
    printf '%s' "$out"
}

# What the options page shows: which profiles can be picked, and which one is
# actually mounted this launch (a missing pick falls back to vanilla).
publish_state() {
    set_cvar solorothVisualReady "$(ready_profiles)"
    set_cvar solorothVisualActive "$1"
}

list_profiles() {
    echo "VISUAL_PROFILE choices:"
    echo "  vanilla"
    if [ -d "$patches_root" ]; then
        local d
        for d in "$patches_root"/*/; do
            [ -d "$d" ] || continue
            case "$(basename "$d")" in
                _cache) continue ;;
            esac
            echo "  $(basename "$d")"
        done
    else
        echo "(no folders yet under $patches_root)"
    fi
    echo "current: $(read_profile)"
}

apply_profile() {
    local mounted
    mounted="$(mount_profile "$1" | tee /dev/stderr | sed -n 's/^visual profile: \([^ ]*\).*/\1/p')"
    publish_state "${mounted:-vanilla}"
}

mount_profile() {
    local profile="$1" dir f name target dest any
    ensure_base_data
    clear_managed

    if [ "$profile" = "vanilla" ]; then
        echo "visual profile: vanilla (stock models)"
        return 0
    fi

    dir="$patches_root/$profile"
    if [ ! -d "$dir" ]; then
        echo "warning: no profile folder $dir — staying on stock models" >&2
        echo "visual profile: vanilla (missing $profile)"
        return 0
    fi

    any=0
    : > "$managed.tmp"
    for f in "$dir"/*; do
        [ -e "$f" ] || continue
        name="$(basename "$f")"
        case "$name" in
            *.MPQ|*.mpq) ;;
            *) continue ;;
        esac
        is_patch_glob "$name" || die "$name: client only mounts patch-?.MPQ (one character after patch-)"
        target="$root/Data/$name"
        if [ -L "$target" ]; then
            dest="$(readlink "$target")"
            case "$dest" in
                "$patches_root"/*|"$dir"/*) rm -f "$target" ;;
                *)
                    die "Data/$name already links to the stock client ($dest); use a free letter (C, G, I, …)"
                    ;;
            esac
        elif [ -e "$target" ]; then
            die "Data/$name already exists; use a free letter (C, G, I, …)"
        fi
        ln -s "$(cd "$(dirname "$f")" && pwd)/$(basename "$f")" "$target"
        echo "link Data/$name -> $profile/$name"
        printf '%s\n' "$name" >> "$managed.tmp"
        any=1
    done
    if [ "$any" -ne 1 ]; then
        rm -f "$managed.tmp"
        echo "warning: no patch-?.MPQ in $dir — staying on stock models" >&2
        echo "visual profile: vanilla (empty $profile)"
        return 0
    fi
    mv "$managed.tmp" "$managed"
    echo "visual profile: $profile"
}

# --- args ---
arg="${1:-}"
case "$arg" in
    --list|-l)
        list_profiles
        exit 0
        ;;
    --help|-h)
        sed -n '2,18p' "$0" | sed 's/^# \?//'
        exit 0
        ;;
    "")
        apply_profile "$(read_profile)"
        ;;
    *)
        save_profile "$arg"
        apply_profile "$arg"
        ;;
esac
