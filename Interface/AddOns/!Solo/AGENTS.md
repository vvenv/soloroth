# !Solo

Loads first (`!` sorts before every other folder) and applies the single-player defaults
(`Solo.lua`) and every look change to other addons. Third-party addon sources are never
edited; anything they should do differently is done from here. Chinese for English-only
third-party UI (SuperMacro, ShaguNotify, ShaguKill) lives in `AddOns_zhCN.lua`; Bagshui's
`Locale/zhCN.lua` is the exception that ships inside Bagshui so its locale loader sees it.

## pfUI skins

- Each window set is one pfUI skin, so pfUI's "disable skin" setting covers it:
  `SoloSkin.Register(name, func)` in `SkinKit.lua`; the loader registers them when pfUI loads
  (pfUI loads last). `PfuiSkin.lua` registers benilla's own windows ("Benilla").
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

## Checking

Run `tools/macos/install-addons.sh` into a scratch `BENILLA_HOME`, open each window from
`WOW_PROBE_LUA` and screenshot it (see the root `AGENTS.md`). Note in README.md which
windows are skinned.
