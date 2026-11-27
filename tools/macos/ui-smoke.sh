#!/usr/bin/env bash
# Short native-UI wiring probe: log in, take one live HUD shot, assert a non-empty frame.
#
# Needs a running local 1.12 server and a client built with default/dev features
# (`tools/macos/build-classic.sh client`). Uses `client/.probe-identity`, never the player's
# `benilla-config/login.env`. Not part of `client/scripts/gates.sh` (needs display + server).
#
#   tools/macos/ui-smoke.sh
#
# Env overrides: CLIENT_BIN, WOW_HOST, WOW_DATA, WOW_LIVE_SHOT_AT (default 12),
# WOW_PROBE_EXIT_AT (default 16), WOW_WIN (default 1280x800).
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
tag=ui-smoke
out="${TMPDIR:-/tmp}/soloroth-ui-smoke.$$"
shot="$out/hud.png"
win="${WOW_WIN:-1280x800}"
shot_at="${WOW_LIVE_SHOT_AT:-12}"
exit_at="${WOW_PROBE_EXIT_AT:-16}"
expect_w="${win%x*}"
expect_h="${win#*x}"

cleanup() { rm -rf "$out"; }
trap cleanup EXIT
mkdir -p "$out/home"

identity="$root/client/.probe-identity"
if [ ! -f "$identity" ]; then
  echo "$tag: REFUSING — missing $identity (WOW_USER / WOW_PASS / WOW_CHAR)"
  exit 1
fi
# shellcheck disable=SC1090
user="$(sed -n 's/^WOW_USER=//p' "$identity" | head -1)"
pass="$(sed -n 's/^WOW_PASS=//p' "$identity" | head -1)"
char="$(sed -n 's/^WOW_CHAR=//p' "$identity" | head -1)"
if [ -z "$user" ] || [ -z "$pass" ] || [ -z "$char" ]; then
  echo "$tag: REFUSING — $identity missing WOW_USER, WOW_PASS, or WOW_CHAR"
  exit 1
fi

host="${WOW_HOST:-127.0.0.1}"
auth_host="${host%%:*}"
auth_port="${host##*:}"
[ "$auth_port" != "$host" ] || auth_port=3724
for port in "$auth_port" 8085; do
  if ! (exec 3<>"/dev/tcp/$auth_host/$port") 2>/dev/null; then
    echo "$tag: REFUSING — nothing on $auth_host:$port (start the server first)"
    exit 1
  fi
done

client="${CLIENT_BIN:-$root/release/build/macos/client-target/release/benilla}"
if [ ! -x "$client" ]; then
  echo "$tag: REFUSING — no client at $client (build with tools/macos/build-classic.sh client)"
  exit 1
fi

echo "$tag: $user / $char → $shot (win=$win shot@${shot_at}s exit@${exit_at}s)"
export BENILLA_HOME="$out/home"
export WOW_DATA="${WOW_DATA:-$root/Data}"
export WOW_HOST="$host"
export WOW_USER="$user"
export WOW_PASS="$pass"
export WOW_CHAR="$char"
export WOW_RIG=
export WOW_WIN="$win"
export WOW_LIVE_SHOT="$shot"
export WOW_LIVE_SHOT_AT="$shot_at"
export WOW_PROBE_EXIT_AT="$exit_at"
export WOW_UNATTENDED=1
export WGPU_BACKEND="${WGPU_BACKEND:-metal}"

set +e
bash "$root/tools/macos/smoke-client.sh"
rc=$?
set -e

if [ ! -f "$shot" ]; then
  echo "$tag: FAIL — no screenshot at $shot (client rc=$rc)"
  exit 1
fi
bytes="$(wc -c <"$shot" | tr -d ' ')"
if [ "$bytes" -lt 30000 ]; then
  echo "$tag: FAIL — shot too small (${bytes} bytes); likely blank/failed capture"
  exit 1
fi

# macOS sips reports the PNG pixel size.
w="$(sips -g pixelWidth "$shot" 2>/dev/null | awk '/pixelWidth/ {print $2}')"
h="$(sips -g pixelHeight "$shot" 2>/dev/null | awk '/pixelHeight/ {print $2}')"
if [ -z "$w" ] || [ -z "$h" ]; then
  echo "$tag: FAIL — could not read PNG size via sips"
  exit 1
fi
# Retina often writes physical pixels (2× logical). Accept 1× or 2× of WOW_WIN.
ok_dims=0
for scale in 1 2; do
  if [ "$w" -eq "$((expect_w * scale))" ] && [ "$h" -eq "$((expect_h * scale))" ]; then
    ok_dims=1
    break
  fi
done
if [ "$ok_dims" -ne 1 ]; then
  echo "$tag: FAIL — shot ${w}x${h}, expected ${expect_w}x${expect_h} (or 2× retina)"
  exit 1
fi

# Mean luminance: reject near-black frames (native UI / world failed to paint).
mean="$(
  python3 - "$shot" <<'PY'
import struct, sys, zlib
path = sys.argv[1]
with open(path, "rb") as f:
    assert f.read(8) == b"\x89PNG\r\n\x1a\n"
    width = height = None
    idat = b""
    while True:
        hdr = f.read(8)
        if len(hdr) < 8:
            break
        ln, typ = struct.unpack(">I4s", hdr)
        data = f.read(ln)
        f.read(4)
        if typ == b"IHDR":
            width, height, bit_depth, color_type = struct.unpack(">IIBB", data[:10])
        elif typ == b"IDAT":
            idat += data
        elif typ == b"IEND":
            break
    if width is None:
        print("nan"); sys.exit(0)
    raw = zlib.decompress(idat)
    # Only 8-bit RGB/RGBA without interlace.
    if bit_depth != 8 or color_type not in (2, 6):
        print("nan"); sys.exit(0)
    bpp = 3 if color_type == 2 else 4
    stride = 1 + width * bpp
    total = 0
    n = 0
    # Sample every 8th pixel on every 8th row.
    for y in range(0, height, 8):
        row = raw[y * stride + 1 : (y + 1) * stride]
        for x in range(0, width, 8):
            i = x * bpp
            r, g, b = row[i], row[i + 1], row[i + 2]
            total += (r + g + b) / 3.0
            n += 1
    print(f"{total / max(n, 1):.2f}")
PY
)"
if [ "$mean" = "nan" ]; then
  echo "$tag: WARN — could not decode PNG luminance; size/dims OK (${bytes}B ${w}x${h})"
elif python3 -c "import sys; sys.exit(0 if float('$mean') >= 8.0 else 1)"; then
  :
else
  echo "$tag: FAIL — mean luminance $mean too dark (blank/black frame?)"
  exit 1
fi

keep="${SOLOROTH_UI_SMOKE_KEEP:-}"
if [ -n "$keep" ]; then
  dest="${keep%/}/hud.png"
  mkdir -p "$(dirname "$dest")"
  cp "$shot" "$dest"
  echo "$tag: OK — $dest (${bytes}B ${w}x${h} mean=$mean, client rc=$rc)"
else
  echo "$tag: OK — ${bytes}B ${w}x${h} mean=$mean (client rc=$rc); set SOLOROTH_UI_SMOKE_KEEP=dir to keep the PNG"
fi
