#!/bin/bash
# Builds the classic game on an Apple Silicon Mac.
#
#   tools/macos/build-classic.sh [server|client|iter|all]     (default: all)
#
# server: CMake configure + build + install of server/core (mangosd, realmd)
#         into release/build/macos/server-classic. The configure step runs
#         every time, because mangosd embeds the list of sql/migrations and a
#         new migration file needs a fresh configure.
# client: cargo --release → release/build/macos/client-target/release/benilla
#         (shipping / Soloroth.app; no incremental — slow for one-line edits).
# iter:   cargo --profile play → …/client-target/play/benilla
#         (release opts + incremental; day-to-day Rust / UI loop).
# all:    server + client (release).
#
# Needs: Xcode command line tools, Homebrew cmake, mariadb, openssl@3,
# pkg-config, and Rust (rustup). Optional: sccache (RUSTC_WRAPPER).
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
part="${1:-all}"
jobs="$(sysctl -n hw.ncpu)"
client_target="$root/release/build/macos/client-target"

# Pick up sccache even when the invoking shell never exported RUSTC_WRAPPER
# (Cursor, launchd, a fresh Terminal before ~/.zshrc reload).
if [ -z "${RUSTC_WRAPPER:-}" ] && command -v sccache >/dev/null 2>&1; then
    export RUSTC_WRAPPER=sccache
fi

build_server() {
    local build="$root/release/build/macos/classic-build"
    local prefix="$root/release/build/macos/server-classic"
    mkdir -p "$(dirname "$build")"
    echo "== server: configure"
    cmake -S "$root/server/core" -B "$build" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$prefix" \
        -DBUILD_EXTRACTORS=0 -DUSE_SCRIPTS=1 -DUSE_PCH=1 \
        -DMYSQL_CONFIG="$(brew --prefix)/bin/mysql_config" \
        > "$build.configure.log" 2>&1 || { tail -30 "$build.configure.log"; exit 1; }
    echo "== server: build ($jobs jobs, log: ${build#$root/}.log)"
    cmake --build "$build" -j"$jobs" > "$build.log" 2>&1 || { grep -E "error|Error" "$build.log" | head -30; exit 1; }
    cmake --install "$build" > "$build.install.log" 2>&1
    echo "== server: installed into ${prefix#$root/}"
}

# build_client_cargo <cargo-profile> — profile name is also the target subdir.
build_client_cargo() {
    local profile="$1"
    local out="$client_target/$profile/benilla"
    echo "== client: cargo build --profile $profile -p benilla${RUSTC_WRAPPER:+ (wrapper=$RUSTC_WRAPPER)}"
    (
        cd "$root/client"
        WOW_DATA="$root/Data" CARGO_TARGET_DIR="$client_target" \
            cargo build --profile "$profile" -p benilla
    )
    echo "== client: ${out#$root/}"
}

build_client() {
    build_client_cargo release
}

# Incremental day-to-day client build (see client/Cargo.toml [profile.play]).
build_client_iter() {
    build_client_cargo play
}

case "$part" in
    server) build_server ;;
    client) build_client ;;
    iter|client-iter) build_client_iter ;;
    all) build_server; build_client ;;
    *) echo "usage: $0 [server|client|iter|all]" >&2; exit 2 ;;
esac
