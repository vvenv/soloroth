# Soloroth

WoW 1.12.1 classic for one player on an Apple Silicon Mac: a vmangos server, the benilla
client, and a Rust product UI (`soloroth-ui`) tuned for solo play.

Docs (Chinese unless noted):
- `README.md` — short human install / play guide. Keep its feature bullets and command
  table honest when player-visible behavior changes.
- `GUIDE.md` — full player-facing behavior (bots, grind, UI defaults, rates, …). This is
  the detailed source of truth for agents; update it with any player-visible change.
- `DEVELOP.md` — what each script does, directory table, upstream merging.

## Layout and who owns what

- `client/` — submodule soloroth-client (benilla, a Rust 1.12.1 client). It has its own
  `AGENTS.md` and `docs/METHOD.md`, binding inside it. Its rules that bite from here:
  benilla's own UI layer "does not grow" (a test fails on a new file), and GlueXML is read only
  from the MPQ patch chain, never loose files. Soloroth product UI is Rust
  (`client/crates/soloroth-ui`); hide-login is `WOW_NO_LOGIN_UI` in the client (no patch-S).
- `server/core` — submodule soloroth-server (vmangos plus bots and achievements).
- `tools/macos/` — build, install, run scripts. `tools/macos/launcher/` — Soloroth.app's
  launcher window (AppKit, built by `make-app.sh`): the art with no text over it but the
  logo, the slogan, the bottom bar and the promo slot. Account/password and optional
  character are one sheet (··· →「设置…」, or before first「开始游戏」), writing
  `benilla-config/login.env`. The window always shows on open
  (`SOLOROTH_SKIP_LAUNCHER=1` still bypasses it for automation). Product sets
  `WOW_NO_LOGIN_UI`.
  Heroes (picked at random, each placing the logo and slogan), logo, slogan, links and
  promo come from `launcher.json`, so new art or an ad changes there, not in Swift.
  `logo.png` is drawn by `render-logo.swift`. Check it with `--snapshot out.png`. The
  window stays open while the game runs (`start-client.sh`); ··· →「打开管理界面」starts
  `tools/macos/admin/server.py` on `127.0.0.1:8765`.
  `tools/lib/` — shared menu/log helpers for `do.sh`.
- `do.sh` — interactive entry (first install, play, build, visual, …); wraps `tools/macos/`.
- `Data/` (links to the client MPQs plus generated patches), `benilla-config/`, `server/run`,
  `server/logs`, `release/` — local state, gitignored.

## Build and run

- `./do.sh` (or `./do.sh first` / `play` / `build` / …) for the common paths.
- `tools/macos/build-classic.sh client|server|iter|all` → `release/build/macos/...`.
  Day-to-day Rust / UI: `./do.sh build iter` (`--profile play`, incremental). Shipping /
  App / first install: `client` (`--release`). `start-client.sh` picks the newer of
  `play/benilla` and `release/benilla` (`SOLOROTH_CLIENT_PROFILE=play|release` to pin).
  Optional `sccache` → scripts set `RUSTC_WRAPPER` when present.
- Product UI is Rust (`soloroth-ui`); changes need a client rebuild. `WOW_NATIVE_UI=0`
  falls back to stock FrameXML. `play.sh` / `start-client.sh` run
  `tools/macos/prune-legacy-ui.sh` each launch (deletes leftover `patch-S` / old AddOns).
- `tools/macos/start-server.sh` / `stop-server.sh`; `play.sh` = server + visual patches +
  legacy-UI prune + client.
- Start the server detached (`setsid`, or a double fork) when an agent shell launches it;
  it otherwise dies with the shell's process group.

## Testing in the client

- `benilla-config/login.env` is the player's own account (PLAYER). Never log in with it: a
  login kicks whoever holds the account. Scripted logins use the account in
  `client/.probe-identity` (SQUADTEST); `smoke-client.sh` defaults to PLAYER, so override
  `WOW_USER`/`WOW_PASS`/`WOW_CHAR` from that file.
- Use a scratch `BENILLA_HOME` (e.g. `/tmp/soloprobe`) so probes don't touch the player's
  settings, and a scratch data dir of symlinks when testing a new MPQ.
- Dev-build probes: `WOW_PROBE_LUA` (+`_AT`) runs Lua after world entry, `WOW_LIVE_SHOT`
  (+`_AT`), `WOW_PROBE_EXIT_AT`, `WOW_WIN=1600x960`; glue screens: `WOW_PROBE_GLUE_LUA`
  (+`_AT`), `WOW_PROBE_GLUE_SHOT` (+`_AFTER`). In-game `Screenshot()` writes to
  `$BENILLA_HOME/Screenshots`. Errors inside `pcall` reach chat, not the log; uncaught ones
  log as `runtime error`.
- Check UI changes by screenshot, not by reasoning about anchors. Product UI quality
  layers (unit + hit-map golden + `tools/macos/ui-smoke.sh`) are in `DEVELOP.md`.

## Code

- Product UI is Rust (`soloroth-ui` / `native_ui`). Stock GlueXML may still load for the glue
  manager when native UI is on; paint is suppressed in the client.
- Comments state a 1.12 fact or a constraint the code can't show, in a line or two; match the
  file around you. Shell and Python scripts open with a usage header.
