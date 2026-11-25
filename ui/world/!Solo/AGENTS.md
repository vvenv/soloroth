# !Solo

Loads first (`!` sorts before every other folder) and applies the single-player defaults
(`Solo.lua`, including HUD frame seats under `position`) and every look change to other
addons. `Tokens.lua` is injected from `ui/shared/Tokens.lua` by `ui/install.sh` (not
edited here). pfUI, Atlas, and AtlasLoot are solo code: gutting (delete modules, BG maps,
PvP loot, etc.) happens in those trees — new product features go in first-party modules,
not inside pfUI. Bag sorting is pfUI's, not a separate addon. `!Solo` still owns defaults,
skins, and shutting stock Blizzard frames the client might still raise.

Player-facing copy treats Soloroth windows as one product (command strip under the
minimap, ESC「界面」for settings). Interface style lives in Options → Graphics
(`/style`, `PfuiStyle.lua` + `PfuiStylesData.lua`); Solo invariant keys stay in
`Solo.lua` (product constraints every login; HUD `position.*` only when that
frame has no `xpos` yet, so Save/Load profile and unlock drags stick). Keep
that in README; this file stays in addon terms.

## Command strip

`MicroBar.lua` wraps the micro row and the feature row in `SoloCommandStrip` (one
pfUI backdrop). Menus use `Solo_PlaceStripMenu`. Do not present the two rows as
"system vs addon" in player docs. Feature-button hover tips go through
`Solo_StripButtonTip` (same `MicroButtonTooltipText` title+(key) and the same
`GameTooltip_AddNewbieTip` anchor path as the micro row, on the pfUI-skinned
`GameTooltip`).

## pfUI skins

- Each window set is one pfUI skin, so pfUI's "disable skin" setting covers it:
  `SoloSkin.Register(name, func)` in `SkinKit.lua`. The loader hands that list to pfUI on
  `ADDON_LOADED "pfUI"`. pfUI is not last: AtlasLoot loads it first, before Bots,
  GMBox, Items and Teleport. An addon that loads after that event must also call `pfUI:RegisterSkin` itself when
  `pfUI` is already there, or the skin never runs and stock buttons stay gold.
  `PfuiSkin.lua` registers benilla's own windows ("Benilla"), relabels
  `GameMenuButtonPFUI` to Interface / 「界面」, and re-stacks the ESC menu
  after Edit Mode / Support are hidden (settings → leave → resume).
- A skin body runs in pfUI's environment, so `CreateBackdrop`, `SkinButton`, … are globals
  there. A file-scope local function is not: call `pfUI.api.X` in helpers, or `setfenv` them
  as `PfuiSkin.lua` does.
- Wait for the addon: `HookAddonOrVariable("Atlas", function() ... end)`.
- Prefer `SoloSkin.Controls(frame)`, which finds stock controls by their art (panel buttons
  including `UIPanelButtonTemplate2`'s three-region face, checkboxes, sliders, scroll bars,
  edit boxes, tabs, drop-downs, close and page buttons) and marks each `soloSkinned`. Add a
  case there rather than per-window special cases. It also turns parchment-black labels white.
- Other helpers: `Backdrop`, `Panel`, `Frame` (border only), `Close`, `EditBox`,
  `IconButton`, `Dewdrop`.
- pfUI's vanilla `hooksecurefunc` keys hooks by the hook function: hooking several functions
  needs a distinct closure each (`function() Dock() end`), not one shared function.
- `SkinCheckbox` insets its backdrop 4px: pass a size around 22, not 14.
- Windows drawn on spellbook/trainer art (384×512) keep that size; re-point the backdrop to
  the page (`TOPLEFT 10/12,-10/12`, `BOTTOMRIGHT -32,72..76`) as pfUI's trainer skin does,
  and move title, close and bottom buttons onto it.

## Unlock grid units

Layout uses **grid cells**: 1 cell = `GetScreenWidth() / 128` (same step for X
and Y). Stored `position.*.xpos/ypos` are whole cells. Unlock size uses
`position.*.width/height` (cells) with `SetWidth`/`SetHeight` via
`LoadMovable` / `SaveUnlockSize` — never `SetScale` (that broke seat math).
Drop leftover `position.*.size/scale` except `WorldMapFrame.size` (map
Ctrl+wheel zoom). Unitframe/chat/castbar/etc. layout `width`/`height` in
config are cells; `ConfigSize` → pixels at apply time. Unlock four-corner drag
and dock W/H sync those module keys (action bars save `position.*.width/height`
as the outer box; `BarFitToSize` / `BarSquarePads` keep square icons and put
leftover space into axis padding so the button grid reaches both edges — dock
W/H stick to what you set). Unitframes scale `width`/`height`/`pheight`
together to the unlock box via `SyncUnitframeUnlockSize` (power bar no
longer floors how small the frame can go; portrait chrome comes from
config, not `GetWidth`, so corner-drag cannot freeze bars at the old
width). `LoadMovable` re-runs that fill when `position.*.width/height`
exist. Action-bar `GetWidth`/`GetHeight` include the panel border (backdrop
flush on the frame, not outside), so unlock grid snap matches the visible
outer edge. Icon/font/spacing sizes stay pixels.

`UnlockSnap.lua` wraps drag-stop as a second snap pass. Dock ±1 and typed
coords are already in cells. MessageLog uses unlock drag/resize; default
32×7 cells, overridable via `position.pfSoloMessageLog.width/height`.

pfUI unlock (Soloroth-tuned): drag keeps the current anchor; within half a
cell of a green mid-line that axis snaps to 0 (±1 is kept); seats snap to
integer cells; the dock labels centre-relative axes as 中X/中Y and shows W/H
in cells. BOTTOM means bottom edge with X from the vertical mid-line. Helpers
live in `pfUI/api/api.lua`
(`GridStep`, `GridToPixel`, `PixelToGrid`, `ConfigSize`, `SaveUnlockSize`;
`ApplyFrameSize` is map-only). Older pixel SavedVariables migrate via
`Solo.lua` (`global.grid_layout = "2"`; re-runs if widths/offsets still look
like pixels).

## Checking

Run `ui/install.sh` into a scratch `BENILLA_HOME`, open each window from
`WOW_PROBE_LUA` and screenshot it (see the root `AGENTS.md`). Note in GUIDE.md which
windows are skinned. A window that is still the stock art after `/reload` is a fact to
read out of `server/logs/launcher.log` (which file ran, in which order, and any script
error), not a cause to guess.
