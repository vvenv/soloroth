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
# A tools/macos/AppIcon.png (1024x1024), if there is one, becomes its icon.
# Launcher output goes to server/logs/launcher.log.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
dest="${1:-}"
if [ -z "$dest" ]; then
    dest=/Applications
    [ -w "$dest" ] || dest="$HOME/Applications"
fi
app="$dest/Soloroth.app"
mkdir -p "$dest"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"

cat > "$app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Soloroth</string>
    <key>CFBundleDisplayName</key><string>Soloroth</string>
    <key>CFBundleIdentifier</key><string>com.vvenv.soloroth</string>
    <key>CFBundleExecutable</key><string>Soloroth</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.role-playing-games</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

cat > "$app/Contents/MacOS/Soloroth" <<EOF
#!/bin/bash
root="$root"
EOF
cat >> "$app/Contents/MacOS/Soloroth" <<'EOF'
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
if pgrep -f "^$root/release/build/macos/client-target/release/benilla" >/dev/null; then
    exit 0
fi
if ! lsof -nP -iTCP:8085 -sTCP:LISTEN >/dev/null 2>&1; then
    osascript -e 'display notification "第一次启动服务器要一点时间" with title "Soloroth" subtitle "正在启动服务器…"'
fi
bash "$root/tools/macos/play.sh"
status=$?
if [ "$status" != 0 ]; then
    alert "启动失败（退出码 $status）。详情见 server/logs/launcher.log：
$(tail -n 8 "$logs/launcher.log")"
fi
exit "$status"
EOF
chmod +x "$app/Contents/MacOS/Soloroth"

icon="$root/tools/macos/AppIcon.png"
if [ -f "$icon" ]; then
    set_dir="$(mktemp -d)/AppIcon.iconset"
    mkdir -p "$set_dir"
    for s in 16 32 128 256 512; do
        sips -z "$s" "$s" "$icon" --out "$set_dir/icon_${s}x${s}.png" >/dev/null
        sips -z "$((s * 2))" "$((s * 2))" "$icon" --out "$set_dir/icon_${s}x${s}@2x.png" >/dev/null
    done
    iconutil -c icns "$set_dir" -o "$app/Contents/Resources/AppIcon.icns"
fi

# Tell Launchpad and Spotlight about it.
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$app" || true
echo "made $app"
