# Third-party notices

This project is licensed under the GNU General Public License v3.0 (see `LICENSE`). It builds on or downloads the following projects, each under its own licence.

It is not affiliated with or endorsed by Blizzard Entertainment and ships no game files: the game client is a build of benilla, which reads the player's own World of Warcraft 1.12.1 data.

| Project | Used for | Licence | Source |
| --- | --- | --- | --- |
| benilla | The game client (submodule `client`, built as `benilla`) | MIT OR Apache-2.0 | https://github.com/samwhosung/benilla |
| Rust crates in the client | Bevy, wgpu, mlua's Lua and the other libraries benilla builds on | Each crate's own licence (MIT, Apache-2.0, MPL-2.0, zlib, BSD and similar) | https://crates.io |
| VMaNGOS | The game server (submodule `server/core`) | GPL-2.0 | https://github.com/vmangos/core |
| VMaNGOS world database | Downloaded by `tools/macos/setup-classic.sh` from the db_latest release | GPL-2.0 | https://github.com/vmangos/core/releases |
| MariaDB Server | The local database (Homebrew) | GPL-2.0 | https://mariadb.org |
| Hordes of Azeroth | Where Soloroth started (credits) | GPL-3.0 | https://github.com/jonhaldors/hordes-of-azeroth |

## Third-party addons

`Interface/AddOns` carries the 1.12 addons the game is set up with. pfUI, Atlas, and AtlasLoot are trimmed for this solo client (social, PvP, auction, mail, trade, battlegrounds, and other-client code are not shipped). SortBags' sorter lives in `Interface/AddOns/pfUI/modules/bagsort.lua`. The Chinese that `tools/macos/localize-addons.py` adds goes onto the installed copies only. They are not covered by this project's GPL: each keeps its own licence and belongs to its authors. Those marked "none shipped" come without a licence file; they are included as the vanilla community has long passed them around, and an author who wants one removed can open an issue.

| Addon | Version | Author | Licence | Source |
| --- | --- | --- | --- | --- |
| pfUI | 5.5.4 | Eric Mauser (Shagu) | MIT (`pfUI/LICENSE`) | https://github.com/shagu/pfUI |
| Atlas | 1.12.0 | Dan Gilbert | none shipped | http://www.atlasmod.com |
| AtlasLoot | 4.06.06 | Daviesh | none shipped | AtlasLoot Enhanced for 1.12 |
| SortBags (now `pfUI/modules/bagsort.lua`) | vanilla | shirsig | none shipped | https://github.com/shirsig/SortBags-vanilla |

Teleport, Items, GMBox, Dungeon, Bots, Achievements and !Solo in the same folder are this project's own, under its GPL-3.0.

Bundled pfUI style tables under `Interface/AddOns/!Solo/PfuiStylesData.lua` are decoded community `/share` exports (not the authors' full addons), kept for one-click switching in Soloroth:

| Style id | Author | Source |
| --- | --- | --- |
| Solo: Clean | megajjh | https://pastebin.com/aTz0rQAa (r/pfUI) |
| Solo: Compact | Khegful | https://pastebin.com/m2nLAtHA (r/pfUI) |

## benilla

benilla is dual-licensed under the MIT licence and the Apache License 2.0; the full Apache text is `LICENSE-APACHE` in the client source.

```
MIT License

Copyright (c) 2026 Sam

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
