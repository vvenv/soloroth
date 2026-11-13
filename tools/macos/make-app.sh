#!/bin/bash
# Builds Soloroth.app, a double-click launcher for tools/macos/play.sh: it
# starts the server when it is not running (with a notification, since the
# first start takes a while), then the client, which logs in by itself (see
# play.sh). The app runs this checkout in place, so it stays current with
# builds and pulls; rerun this only when the checkout moves.
#
#   tools/macos/make-app.sh              into /Applications (~/Applications if not writable)
#   tools/macos/make-app.sh <folder>     into <folder>
#
# The icon is tools/macos/AppIcon.png (1024x1024; render-icon.swift draws it).
# Launcher output goes to server/logs/launcher.log.
#
# The bundle's executable is a shell script named "launch". It starts the
# server, then replaces itself with a copy of the client at
# Contents/MacOS/Soloroth. macOS takes the Dock name, menu bar and icon from
# the bundle that contains the running executable, so the game shows up as
# Soloroth rather than as the raw benilla binary.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
dest="${1:-}"
if [ -z "$dest" ]; then
    dest=/Applications
    [ -w "$dest" ] || dest="$HOME/Applications"
fi
mkdir -p "$dest"
dest="$(cd "$dest" && pwd)"
app="$dest/Soloroth.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"

cat > "$app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>zh-Hans</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>Soloroth</string>
    <key>CFBundleDisplayName</key><string>Soloroth</string>
    <key>CFBundleSpokenName</key><string>Soloroth</string>
    <key>CFBundleIdentifier</key><string>com.vvenv.soloroth</string>
    <key>CFBundleExecutable</key><string>launch</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.role-playing-games</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSMultipleInstancesProhibited</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSHumanReadableCopyright</key><string>非官方爱好者项目，与暴雪娱乐无关。</string>
</dict>
</plist>
EOF

# "launch" is the bundle executable. The game binary is copied to
# Contents/MacOS/Soloroth at startup and exec'd in this process, so macOS
# keeps this bundle's name and icon on the running game.
cat > "$app/Contents/MacOS/launch" <<EOF
#!/bin/bash
root="$root"
EOF
cat >> "$app/Contents/MacOS/launch" <<'EOF'
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
logs="$root/server/logs"
mkdir -p "$logs"
exec >"$logs/launcher.log" 2>&1

alert() {
    osascript - "$1" <<'APPLESCRIPT'
on run argv
    display alert "Soloroth" message (item 1 of argv) as critical
end run
APPLESCRIPT
}

[ -d "$root/tools/macos" ] || { alert "找不到游戏目录：$root。重新运行 tools/macos/make-app.sh。"; exit 1; }
bundle="$(cd "$(dirname "$0")/../.." && pwd)"
client="$root/release/build/macos/client-target/release/benilla"
if pgrep -f "^$bundle/Contents/MacOS/Soloroth" >/dev/null \
    || pgrep -f "^$client" >/dev/null; then
    exit 0
fi
if ! lsof -nP -iTCP:8085 -sTCP:LISTEN >/dev/null 2>&1; then
    osascript -e 'display notification "第一次启动服务器要一点时间" with title "Soloroth" subtitle "正在启动服务器…"'
fi
bash "$root/tools/macos/play.sh" --no-client
status=$?
if [ "$status" != 0 ]; then
    alert "启动失败（退出码 $status）。详情见 server/logs/launcher.log：
$(tail -n 8 "$logs/launcher.log")"
    exit "$status"
fi
# shellcheck source=bundle.sh
source "$root/tools/macos/bundle.sh"
export_client_env
cd "$root"
target="$(stage_client "$bundle" "$client")"
[ -x "$target" ] || { alert "找不到客户端。先运行 tools/macos/build-classic.sh client。"; exit 1; }
exec "$target"
EOF
chmod +x "$app/Contents/MacOS/launch"

icon="$root/tools/macos/AppIcon.png"
if [ ! -f "$icon" ]; then
    swift "$root/tools/macos/render-icon.swift" "$icon"
fi
if [ -f "$icon" ]; then
    tmp="$(mktemp -d)"
    set_dir="$tmp/AppIcon.iconset"
    mkdir -p "$set_dir"
    for s in 16 32 128 256 512; do
        sips -z "$s" "$s" "$icon" --out "$set_dir/icon_${s}x${s}.png" >/dev/null
        sips -z "$((s * 2))" "$((s * 2))" "$icon" --out "$set_dir/icon_${s}x${s}@2x.png" >/dev/null
    done
    iconutil -c icns "$set_dir" -o "$app/Contents/Resources/AppIcon.icns"
    rm -rf "$tmp"
fi

printf 'APPL????' > "$app/Contents/PkgInfo"
# InfoPlist.strings is UTF-16. A Chinese Mac reads the display name from here.
for lang in zh-Hans en; do
    dir="$app/Contents/Resources/$lang.lproj"
    mkdir -p "$dir"
    printf 'CFBundleDisplayName = "Soloroth";\nCFBundleName = "Soloroth";\nNSHumanReadableCopyright = "非官方爱好者项目，与暴雪娱乐无关。";\n' \
        | iconv -f UTF-8 -t UTF-16 > "$dir/InfoPlist.strings"
done
mkdir -p "$root/benilla-config"
printf '%s\n' "$app" > "$root/benilla-config/app.path"

# Tell Launchpad and Spotlight about it.
touch "$app"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$app" || true
echo "made $app"
