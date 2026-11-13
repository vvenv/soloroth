# glue-skin

The login, realm, character select and character create screens in pfUI's look.

- The glue VM has no pfUI and no addons, and reads GlueXML only from the MPQ patch chain.
  So `SoloGlueSkin.lua` uses the bare 1.12 glue API (`WHITE8X8` backdrops, 1px border
  `.2,.2,.2`, black `.75`), and `build-patch.py` ships it in `Data/patch-S.MPQ` next to a
  copy of the stock `GlueXML.toc` with the file appended. The toc is read from the player's
  chain at build time; nothing from the install is committed.
- `play.sh` rebuilds the patch each launch; `WOW_STOCK_UI=1` removes it.
- The AccountLogin page is removed by default (`SoloShowLoginUI = false` prepended by
  `build-patch.py --hide-login-ui`): the ModelFFX is hidden and a black blank covers
  GlueParent until character select. `play.sh` passes `--show-login-ui` when there is no
  `login.env`, or when `WOW_SHOW_LOGIN_UI=1`. Glue Lua cannot read the process env, so the
  choice is baked into the MPQ each launch. With the page gone, `DISCONNECTED_FROM_SERVER`
  calls `QuitGame` (Soloroth.app returns to its launcher).
- The skin runs once on `FRAMES_LOADED` (wrapping `GlueParent_OnEvent`), which fires after
  benilla's own glue file, so its Realmlist button is there too.
- Backdrops go on a child one level below the owner, inset to where the stock art drew.
  Exception: a frame whose parent is a model frame (character select) or a dialog panel —
  one level down lands under the 3D scene or the panel; put the backdrop on the frame
  itself (`Own`).
- benilla's realmlist dialog adds a chat-input middle piece to `GlueDialogEditBox` at each
  open (`BenillaRealmlist_TakeEditBox`); the skin wraps that function to hide it again.
- `build-patch.py` writes stored, unencrypted MPQ v0 files and reads stored or zlib ones;
  the letter must sort after the stock and visual patches (`A`, `C`, `H`).

Check: `build-patch.py /tmp/gluedata` (a dir of symlinks to `Data/*`), then run the client
with `WOW_DATA=/tmp/gluedata` and `WOW_PROBE_GLUE_LUA`/`WOW_PROBE_GLUE_SHOT`; reach
character select with `DefaultServerLogin` on the probe account only.
