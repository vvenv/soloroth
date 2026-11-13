# Loading screens (patch-L)

Soloroth fills the blue-bar loading cover edge-to-edge with 16:9 art. Stock 1.12
BLPs are 512×512 and the reference pillarboxes them to 4:3; benilla on the
soloroth branch always uses the whole window (`fit_rect` in
`client/.../loading_screen.rs`), and this tool ships the matching textures.

`build-patch.py` reads `LoadingScreens.dbc` from `Data/`, upscales every
`FileName` BLP to 1920×1080 (centre crop), and writes `Data/patch-L.MPQ`. The
heavy result is cached under `$WOW_DATA_ROOT/loading-screens/`. `play.sh` runs
it each launch; `WOW_STOCK_LOADING=1` removes the patch.
