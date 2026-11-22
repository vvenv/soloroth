# !Solo

Loads first (`!` sorts before every other folder) and applies the single-player defaults
(`Solo.lua`, including HUD frame seats under `position`) and every look change to other
addons. Third-party addon sources are never edited; anything they should do differently
is done from here.

Player-facing copy treats Soloroth windows as one product (command strip under the
minimap, ESC「界面」for settings). Interface style lives in Options → Graphics
(`/style`, `PfuiStyle.lua` + `PfuiStylesData.lua`); Solo invariant keys stay in
`Solo.lua`. Keep that in README; this file stays in addon terms.

## Command strip

`MicroBar.lua` wraps the micro row and the feature row in `SoloCommandStrip` (one
pfUI backdrop). Menus use `Solo_PlaceStripMenu`. Do not present the two rows as
"system vs addon" in player docs.

## pfUI skins

- Each window set is one pfUI skin, so pfUI's "disable skin" setting covers it:
  `SoloSkin.Register(name, func)` in `SkinKit.lua`. The loader hands that list to pfUI on
  `ADDON_LOADED "pfUI"`. pfUI is not last: AtlasLoot loads it first, before Bots,
  GMBox, Items and Teleport. An addon that loads after that event must also call `pfUI:RegisterSkin` itself when
  `pfUI` is already there, or the skin never runs and stock buttons stay gold.
  `PfuiSkin.lua` registers benilla's own windows ("Benilla") and relabels
  `GameMenuButtonPFUI` to Interface / 「界面」.
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

## Unlock grid snap

`UnlockSnap.lua` wraps pfUI unlock drag-stop so seats land on the drawn grid
(screen width / 128). Do not edit `pfUI/modules/unlock.lua`. Dock ±1 and typed
coords stay free. MessageLog uses the same unlock drag / scroll-scale path.

## Checking

Run `tools/macos/install-addons.sh` into a scratch `BENILLA_HOME`, open each window from
`WOW_PROBE_LUA` and screenshot it (see the root `AGENTS.md`). Note in GUIDE.md which
windows are skinned. A window that is still the stock art after `/reload` is a fact to
read out of `server/logs/launcher.log` (which file ran, in which order, and any script
error), not a cause to guess.
