#!/bin/bash
# Mount the HD visual pack (Project Reforged) on top of stock Data/.
# Always HD — no profile switch. Missing pack → stock models + a warning.
#
#   tools/macos/apply-visual.sh          # mount HD (or warn if not downloaded)
#   tools/macos/apply-visual.sh --status # whether HD is on disk / mounted
#
# Download once: tools/macos/fetch-visual-patches.sh (or ./do.sh visual)
#
# Pack lives at:
#   $WOW_DATA_ROOT/visual-patches/hd/patch-?.MPQ
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
patches_root="$wow_data/visual-patches"
hd_dir="$patches_root/hd"
managed="$root/Data/.soloroth-visual-managed"
PROFILE=hd
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

# Keep visual.env in sync for older setups that still read it; not a switch.
write_env() {
    mkdir -p "$home"
    local example="$root/config/visual.env.example"
    if [ -f "$example" ]; then
        cp "$example" "$env_file"
    else
        printf 'VISUAL_PROFILE=%s\n' "$PROFILE" > "$env_file"
    fi
}

hd_ready() {
    local f
    [ -d "$hd_dir" ] || return 1
    for f in "$hd_dir"/*; do
        [ -e "$f" ] || continue
        is_patch_glob "$f" && return 0
    done
    return 1
}

status() {
    if hd_ready; then
        echo "HD pack: ready ($hd_dir)"
    else
        echo "HD pack: missing — run tools/macos/fetch-visual-patches.sh"
    fi
    if [ -f "$managed" ]; then
        echo "mounted: HD ($(tr '\n' ' ' < "$managed" | sed 's/ $//'))"
    else
        echo "mounted: stock (no HD overlays)"
    fi
}

mount_hd() {
    local f name target dest any
    ensure_base_data
    clear_managed
    write_env

    if ! hd_ready; then
        echo "warning: no HD pack in $hd_dir — stock models until you run:" >&2
        echo "  tools/macos/fetch-visual-patches.sh" >&2
        echo "visual: stock (HD missing)"
        return 0
    fi

    any=0
    : > "$managed.tmp"
    for f in "$hd_dir"/*; do
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
                "$patches_root"/*|"$hd_dir"/*) rm -f "$target" ;;
                *)
                    die "Data/$name already links to the stock client ($dest); use a free letter (C, G, I, …)"
                    ;;
            esac
        elif [ -e "$target" ]; then
            die "Data/$name already exists; use a free letter (C, G, I, …)"
        fi
        ln -s "$(cd "$(dirname "$f")" && pwd)/$(basename "$f")" "$target"
        echo "link Data/$name -> hd/$name"
        printf '%s\n' "$name" >> "$managed.tmp"
        any=1
    done
    if [ "$any" -ne 1 ]; then
        rm -f "$managed.tmp"
        echo "warning: no patch-?.MPQ in $hd_dir — stock models" >&2
        echo "visual: stock (HD empty)"
        return 0
    fi
    # Reforged/HD patch-C ships some CreatureModelData rows (AncientSeaTurtle for
    # Ghamoo-ra, …) with ModelScale 0; benilla then draws the black debug cube.
    # patch-V sits above C and sets those scales to 1; rebuilt on every mount.
    if [ -L "$root/Data/patch-C.MPQ" ] || [ -e "$root/Data/patch-C.MPQ" ]; then
        if python3 "$root/tools/macos/build-hd-overrides.py" --from-data "$root/Data" \
            "$root/Data/patch-V.MPQ"; then
            if [ -f "$root/Data/patch-V.MPQ" ]; then
                printf '%s\n' "patch-V.MPQ" >> "$managed.tmp"
            fi
        else
            echo "warning: build-hd-overrides.py failed; some HD creatures may stay black" >&2
        fi
    fi

    mv "$managed.tmp" "$managed"
    echo "visual: HD"
}

# --- args ---
arg="${1:-}"
case "$arg" in
    --status|-s|--list|-l)
        status
        exit 0
        ;;
    --help|-h)
        sed -n '2,16p' "$0" | sed 's/^# \?//'
        exit 0
        ;;
    ""|hd|apply)
        mount_hd
        ;;
    *)
        die "HD is always on; unknown arg '$arg' (try --status or fetch-visual-patches.sh)"
        ;;
esac
