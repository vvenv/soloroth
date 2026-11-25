# ui — Soloroth product UI

All player-facing game UI that Soloroth owns lives here. Not in `client/`
(benilla's UI layer does not grow; FrameXML/GlueXML stay on the MPQ chain).

| Path | What |
|---|---|
| `world/` | In-world UI (former `Interface/AddOns`): `!Solo`, pfUI, Atlas, AtlasLoot, Dungeon, Bots, GMBox, … |
| `glue/` | Login / realm / character select & create skin (`SoloGlueSkin.lua` + `build-patch.py`) |
| `install.sh` | One install: sync `world/` → `$BENILLA_HOME/AddOns`, rebuild `Data/patch-S.MPQ` |

## Install

```sh
./do.sh ui                 # or ./do.sh addons (alias)
ui/install.sh              # world + glue
ui/install.sh --world-only
ui/install.sh --glue-only
```

`play.sh` and `start-client.sh` run `ui/install.sh` each client launch. Glue must
ship as MPQ (`patch-S`): the glue VM has no addons and reads GlueXML only from
the patch chain. `WOW_STOCK_UI=1` removes the patch; `login.env` /
`WOW_SHOW_LOGIN_UI` pick show/hide for the AccountLogin page (baked into the
MPQ — glue Lua cannot read process env).

New files under `world/` need a **full client restart**, not `/reload`.

## Ownership

- Gut pfUI / Atlas / AtlasLoot in place (no social/PvP/AH/mail/trade/BG).
- Defaults, skins, and cross-addon seams stay in `world/!Solo` (see its `AGENTS.md`).
- Bag sorting is pfUI's, not a separate addon.
- Do not put product panels into `client/assets/ui`. Engine verbs only, when Lua cannot.

## Not this package

- `client/` — FrameXML host, script API, benilla's locked fix layer
- `tools/enchant-scrolls/` → `patch-T` (game data)
- HD / `patch-V` visual packs
- `tools/macos/launcher/` — desktop launcher, not in-game UI

## Probe

Scratch `BENILLA_HOME` (e.g. `/tmp/soloprobe`) filled by `ui/install.sh`. Glue:
symlink Data into a scratch dir, `ui/glue/build-patch.py` there, then
`WOW_DATA=…` with `WOW_PROBE_GLUE_LUA` / `WOW_PROBE_GLUE_SHOT`.
