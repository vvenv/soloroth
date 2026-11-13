# Shared by play.sh and Soloroth.app. Sourced, not executed.
#
# macOS names a running program from the .app that contains its executable.
# The built client lives outside the bundle (so a rebuild stays in place);
# copying it to Contents/MacOS/Soloroth makes the Dock, menu bar and Force
# Quit show Soloroth and the bundle icon. An APFS clone is cheap, and a
# newer build replaces the copy on the next launch.

# export_client_env: BENILLA_HOME, WOW_DATA, and the saved login.
# $root is the checkout. login.env is optional; cancelling the first-launch
# dialog leaves it absent and the client shows the login screen.
export_client_env() {
    export BENILLA_HOME="$root/benilla-config"
    local login="$BENILLA_HOME/login.env"
    if [ -f "$login" ]; then
        local key value
        while IFS='=' read -r key value; do
            case "$key" in WOW_USER|WOW_PASS|WOW_CHAR) export "$key=$value" ;; esac
        done < "$login"
        # The client only auto-logs in as the account .probe-identity declares
        # (the agents' test account) unless told the player chose this one.
        export WOW_ALLOW_ACCOUNT=1
    fi
    export WOW_DATA="$root/Data"
    export WGPU_BACKEND="${WGPU_BACKEND:-metal}"
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
