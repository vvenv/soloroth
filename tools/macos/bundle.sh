# Shared by play.sh and Soloroth.app. Sourced, not executed.
#
# macOS names a running program from the .app that contains its executable.
# The built client lives outside the bundle (so a rebuild stays in place);
# copying it to Contents/MacOS/Soloroth makes the Dock, menu bar and Force
# Quit show Soloroth and the bundle icon. An APFS clone is cheap, and a
# newer build replaces the copy on the next launch.

# export_client_env: BENILLA_HOME, WOW_DATA, and the saved login.
# $root is the checkout. login.env must have WOW_USER and WOW_PASS before the
# client starts (launcher sheet or play.sh); AccountLogin is never shown.
export_client_env() {
    export BENILLA_HOME="$root/benilla-config"
    local login="$BENILLA_HOME/login.env"
    if [ -f "$login" ]; then
        local key value
        # `|| [ -n "$key" ]`: keep the last line when the file has no trailing
        # newline (bash `read` otherwise drops it). Strip a trailing CR too.
        while IFS='=' read -r key value || [ -n "$key" ]; do
            key="${key%$'\r'}"
            value="${value%$'\r'}"
            case "$key" in ''|'#'*) continue ;; esac
            case "$key" in WOW_USER|WOW_PASS|WOW_CHAR) export "$key=$value" ;; esac
        done < "$login"
        # The client only auto-logs in as the account .probe-identity declares
        # (the agents' test account) unless told the player chose this one.
        export WOW_ALLOW_ACCOUNT=1
        # Product: skip AccountLogin and quit on disconnect / char-select Back.
        export WOW_NO_LOGIN_UI=1
        # Rust native UI (FrameXML/Lua off). Set WOW_NATIVE_UI=0 to fall back.
        export WOW_NATIVE_UI="${WOW_NATIVE_UI:-1}"
    fi
    export WOW_DATA="$root/Data"
    export WGPU_BACKEND="${WGPU_BACKEND:-metal}"
}

# Data/patch-T.MPQ: Spell.dbc where enchant crafts CreateItem scrolls.
# Needs tools/enchant-scrolls/map.json (from gen-enchant-scrolls.py).
rebuild_enchant_scrolls_patch() {
    if [ "${WOW_STOCK_UI:-}" = 1 ]; then
        python3 "$root/tools/enchant-scrolls/build-patch.py" "$root/Data" --remove
        return
    fi
    if [ ! -f "$root/tools/enchant-scrolls/map.json" ]; then
        echo "enchant-scrolls: no map.json — skip patch-T" >&2
        return
    fi
    python3 "$root/tools/enchant-scrolls/build-patch.py" "$root/Data"
}

# Prune leftover product Lua / patch-S. start-client.sh runs this each launch.
install_product_ui() {
    bash "$root/tools/macos/prune-legacy-ui.sh" "$@"
}

# Alias kept for older callers.
rebuild_glue_patch() {
    install_product_ui
}

# stage_client <bundle.app> <benilla binary>
# Prints the executable to run: the copy inside the bundle, or the raw
# binary when the bundle is missing.
stage_client() {
    local bundle="$1" src="$2"
    if [ ! -d "$bundle/Contents/MacOS" ]; then
        printf '%s\n' "$src"
        return 0
    fi
    local dest="$bundle/Contents/MacOS/Soloroth"
    if [ -x "$dest" ] && [ ! "$src" -nt "$dest" ]; then
        printf '%s\n' "$dest"
        return 0
    fi
    local tmp="$dest.new.$$"
    rm -f "$tmp"
    if ! cp -c "$src" "$tmp" 2>/dev/null; then
        cp -f "$src" "$tmp"
    fi
    chmod +x "$tmp"
    mv -f "$tmp" "$dest"
    printf '%s\n' "$dest"
}

# resolve_benilla_bin — newer of release/ and play/ under client-target, or
# SOLOROTH_CLIENT_PROFILE=release|play to pin. Empty stdout if neither exists.
resolve_benilla_bin() {
    local target="$root/release/build/macos/client-target"
    local release_bin="$target/release/benilla"
    local play_bin="$target/play/benilla"
    case "${SOLOROTH_CLIENT_PROFILE:-}" in
        release)
            [ -x "$release_bin" ] && printf '%s\n' "$release_bin"
            return 0
            ;;
        play)
            [ -x "$play_bin" ] && printf '%s\n' "$play_bin"
            return 0
            ;;
        "")
            if [ -x "$play_bin" ] && { [ ! -x "$release_bin" ] || [ "$play_bin" -nt "$release_bin" ]; }; then
                printf '%s\n' "$play_bin"
            elif [ -x "$release_bin" ]; then
                printf '%s\n' "$release_bin"
            fi
            return 0
            ;;
        *)
            echo "SOLOROTH_CLIENT_PROFILE must be release or play (got: $SOLOROTH_CLIENT_PROFILE)" >&2
            return 2
            ;;
    esac
}

# resolve_client <benilla binary>
# The bundle path recorded by make-app.sh, when that .app is still there.
resolve_client() {
    local src="$1" bundle="" pathfile="$root/benilla-config/app.path" candidate
    if [ -f "$pathfile" ]; then
        IFS= read -r bundle < "$pathfile" || true
    fi
    if [ ! -d "$bundle/Contents/MacOS" ]; then
        for candidate in /Applications/Soloroth.app "$HOME/Applications/Soloroth.app"; do
            if [ -d "$candidate/Contents/MacOS" ]; then
                bundle="$candidate"
                break
            fi
        done
    fi
    stage_client "$bundle" "$src"
}
