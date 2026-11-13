# Soloroth

WoW 1.12.1 classic for one player on an Apple Silicon Mac: a vmangos server, the benilla
client, and a vetted 1.12 addon set tuned for solo play. README.md (Chinese) is the user
guide; keep it in step with any player-visible change. BUILDING.md (Chinese) holds what
each script does, the directory table and upstream merging.

## Layout and who owns what

- `client/` — submodule soloroth-client (benilla, a Rust 1.12.1 client). It has its own
  `AGENTS.md` and `docs/METHOD.md`, binding inside it. Its rules that bite from here:
  benilla's own UI layer "does not grow" (a test fails on a new file), and GlueXML is read only
  from the MPQ patch chain, never loose files. Soloroth-only UI goes in addons or in a patch
  MPQ under `Data/` (see `tools/glue-skin/`), not in the client.
- `server/core` — submodule soloroth-server (vmangos plus bots and achievements).
- `Interface/AddOns/` — the addon set. Third-party addons (pfUI, pfQuest, Atlas*, Bagshui,
  Shagu*, SuperMacro, CleverMacro) are kept as shipped: never edit their sources. Change
  their defaults or looks from `!Solo` (see its `AGENTS.md`).
- `tools/macos/` — build, install, run scripts. `tools/macos/launcher/` — Soloroth.app's
 launcher window (AppKit, built by `make-app.sh`): the art with no text over it but the
 bottom bar and the promo slot. Art, links and promo come from `launcher.json`, so an ad
 changes there, not in Swift. Check it with
 `--snapshot out.png`. `tools/glue-skin/` — login/character screens.
  `tools/lib/` — shared menu/log helpers for `do.sh`.
- `do.sh` — interactive entry (first install, play, build, visual, …); wraps `tools/macos/`.
- `Data/` (links to the client MPQs plus generated patches), `benilla-config/`, `server/run`,
  `server/logs`, `release/` — local state, gitignored.

## Build and run

- `./do.sh` (or `./do.sh first` / `play` / `build` / …) for the common paths.
- `tools/macos/build-classic.sh client|server|all` → `release/build/macos/...`
- `tools/macos/install-addons.sh` copies `Interface/AddOns` into `$BENILLA_HOME/AddOns`
  (default `benilla-config/`). A new addon file needs a full client restart, not `/reload`.
- `tools/macos/start-server.sh` / `stop-server.sh`; `play.sh` = server + visual patches +
  glue patch + client.
- Start the server detached (`setsid`, or a double fork) when an agent shell launches it;
  it otherwise dies with the shell's process group.

## Testing in the client

- `benilla-config/login.env` is the player's own account (PLAYER). Never log in with it: a
  login kicks whoever holds the account. Scripted logins use the account in
  `client/.probe-identity` (SQUADTEST); `smoke-client.sh` defaults to PLAYER, so override
  `WOW_USER`/`WOW_PASS`/`WOW_CHAR` from that file.
- Use a scratch `BENILLA_HOME` (e.g. `/tmp/soloprobe`, filled by `install-addons.sh`) so
  probes don't touch the player's settings, and a scratch data dir of symlinks when testing
  a new MPQ.
- Dev-build probes: `WOW_PROBE_LUA` (+`_AT`) runs Lua after world entry, `WOW_LIVE_SHOT`
  (+`_AT`), `WOW_PROBE_EXIT_AT`, `WOW_WIN=1600x960`; glue screens: `WOW_PROBE_GLUE_LUA`
  (+`_AT`), `WOW_PROBE_GLUE_SHOT` (+`_AFTER`). In-game `Screenshot()` writes to
  `$BENILLA_HOME/Screenshots`. Errors inside `pcall` reach chat, not the log; uncaught ones
  log as `runtime error`.
- Check UI changes by screenshot, not by reasoning about anchors.

## Code

- Addon Lua is Lua 5.0 / the 1.12 API: `table.getn`, `getglobal`, `strfind`, `this`/`arg1`
  globals, no `#`, no `HookScript`.
- Comments state a 1.12 fact or a constraint the code can't show, in a line or two; match the
  file around you. Shell and Python scripts open with a usage header.
