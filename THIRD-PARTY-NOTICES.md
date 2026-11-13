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

`Interface/AddOns` carries the 1.12 addons the game is set up with, unmodified (the Chinese that `tools/macos/localize-addons.py` adds goes onto the installed copies only). They are not covered by this project's GPL: each keeps its own licence and belongs to its authors. Those marked "none shipped" come without a licence file; they are included as the vanilla community has long passed them around, and an author who wants one removed can open an issue.

| Addon | Version | Author | Licence | Source |
| --- | --- | --- | --- | --- |
| pfUI | 5.5.4 | Eric Mauser (Shagu) | MIT (`pfUI/LICENSE`) | https://github.com/shagu/pfUI |
| pfQuest | 7.0.1 | Eric Mauser (Shagu) | MIT (`pfQuest/LICENSE`) | https://github.com/shagu/pfQuest |
| pfQuest-icons | git | Eric Mauser (Shagu) | MIT (`pfQuest-icons/LICENSE`) | https://github.com/shagu/pfQuest-icons |
| Bagshui | 1.0.5 | veechs | MIT (`Bagshui/LICENSE`) | Bagshui for 1.12 |
| ShaguKill | 1.0 | Shagu | none shipped | https://github.com/shagu/ShaguKill |
| ShaguNotify | 0.1 | Shagu | none shipped | https://github.com/shagu/ShaguNotify |
| Atlas | 1.12.0 | Dan Gilbert | none shipped | http://www.atlasmod.com |
| AtlasLoot | 4.06.06 | Daviesh | none shipped | AtlasLoot Enhanced for 1.12 |
| AtlasQuest | 4.2 | Thandrenn | none shipped | http://www.atlasmod.com |
| SuperMacro | 3.18.1 | unnamed | none shipped | SuperMacro for 1.12 |
| CleverMacro | 1.2 | _brain | none shipped | https://github.com/DanielAdolfsson/CleverMacro |

GMBox and !Solo in the same folder are this project's own, under its GPL-3.0.

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
