# Soloroth 开发者说明

玩家简版在 [README.md](README.md)，完整功能说明在 [GUIDE.md](GUIDE.md)。这里写安装细节、各个脚本、启动器、仓库目录，以及怎么跟进上游。

## 游戏数据路径

默认这些游戏数据都放在仓库**旁边**的 `../wow-data` 里：

```
../wow-data/
├── client-zhCN/Data/        中文客户端的 MPQ（CLIENT_LOCALE=enUS 时用 client/Data）
├── vmangos-deploy/storage/mangosd/extracted-data/
│   ├── maps/  vmaps/  mmaps/  5875/
```

放在别处时，运行安装脚本用环境变量指过去：

| 变量 | 作用 |
|---|---|
| `WOW_DATA_ROOT` | 整个数据根目录（替代 `../wow-data`） |
| `CLIENT_LOCALE` | `zhCN` 或 `enUS` |
| `HOA_EXTRACTED` | 提取好的地图数据目录 |

还没有提取好的地图数据时，用 vmangos 自带的提取工具从 1.12 客户端生成：构建时加 `-DBUILD_EXTRACTORS=1`，用法见 [vmangos](https://github.com/vmangos/core) 的文档。

经验倍率等服务端默认值在 `config/mangosd.overrides.conf`，改完跑 `./do.sh config` 并重启服务器。

## 安装的每一步

`./do.sh first`（或交互菜单里的「第一次安装」）依次运行下面几个脚本，也可以一步一步手动跑：

```sh
tools/macos/build-classic.sh                         # 编译服务端和客户端（第一次要编译一阵子）
tools/macos/setup-classic.sh                         # 数据库、配置、客户端数据、插件
tools/macos/play.sh --server-only                    # 先把服务器开起来
tools/macos/create-account.sh 账号 密码 gm           # 建账号；gm 表示给 GM 权限
tools/macos/make-app.sh                              # 生成 /Applications/Soloroth.app
```

1. **`build-classic.sh`**：编译服务端（`mangosd`、`realmd`），装到 `release/build/macos/server-classic`；再编译客户端，生成 `release/build/macos/client-target/release/benilla`。也可以只编一边：`build-classic.sh server` 或 `build-classic.sh client`。
2. **`setup-classic.sh`**：重复运行是安全的，已有的东西不会动。它会：
   - 把服务端程序和地图数据链接进 `server/run`、`server/data`；
   - 初始化并启动 MariaDB（数据在 `server/mariadb-data`）；
   - 第一次运行时，下载 vmangos 官方世界数据库快照（约 30 MB），建四个库：`classic_world`、`classic_characters`、`classic_realmd`、`classic_logs`；以后再运行只补新的数据库迁移；建库末尾会跑 `sql/custom/repack/AQ-SET_GATES_OPEN.sql`，安其拉之门默认已开；
   - 生成服务端配置，把 `Data/` 链接到客户端的 MPQ，以及登录界面要用的 `tos.html` / `eula.html` 等松散文件；
   - 设置客户端（服务器名 Azeroth，不限插件脚本内存），安装插件。

   加 `--reset-db` 会清空重建这四个库，**角色也会被清掉**。
3. **`create-account.sh`**：需要服务器在运行。加 `gm` 的账号才能用 GMBox 的传送、物品和工具按钮；机器人组队不需要 GM。建的第一个账号会存进 `benilla-config/login.env`，以后自动用它登录。
4. **`make-app.sh`**：生成 `Soloroth.app`，默认放进 `/Applications`，也可以指定目录：`make-app.sh ~/Desktop`。启动台、Spotlight、程序坞和「强制退出」里的名字都是 Soloroth，图标是 `tools/macos/AppIcon.png`。它直接运行这个仓库里的脚本，客户端重新编译之后，下次启动会自动换上新的。仓库换了位置、换了图标，或者改了启动器的代码（`Launcher.swift`），才要再运行一次。

主菜单只留日常项；开服务器、setup、建账号、App、HD、对照表在「更多…」。菜单会根据源码和二进制的新旧提示该不该编译；不确定时看 `./do.sh status`（或菜单「更多 → 对照表」）。cargo / cmake 本身是增量的，提示说要编时再跑即可。

## 启动器窗口

双击 Soloroth.app 先打开的那个窗口，源码在 `tools/macos/launcher/`：

- `Launcher.swift` 是单文件的 AppKit 程序，`make-app.sh` 用 Xcode 命令行工具里的 `swiftc` 把它编进 `Soloroth.app/Contents/MacOS/Launcher`。编译失败时 app 照样能用，只是不弹窗口，直接进游戏。
- 窗口一打开就在后台运行 `play.sh --no-client`（开服、外观补丁、登录界面补丁），底栏显示进度。点「开始游戏」时窗口**不退出**，自己跑 `start-client.sh`（把 benilla 拷进 `Contents/MacOS/Soloroth` 以保持 Dock 图标）；游戏退出后底栏回到「服务器已就绪」。`skip` / `SOLOROTH_SKIP_LAUNCHER=1` 时不弹窗，`launch` 脚本直接 `play.sh`。关掉启动器窗口或按 ⌘Q 是退出码 1，离开 app（并停掉本机 Web 管理台）；服务器和已在跑的客户端继续。
- ··· 菜单「打开管理界面」会跑 `start-admin.sh`：在 `127.0.0.1:8765` 起 `tools/macos/admin/server.py`（账号 / 角色 / 四个 `classic_*` 库浏览与 SQL；顶栏可切中英文与深色/浅色，Cookie 记住；列表可筛选，宽表 sticky 首列/表头）。文案在 `tools/macos/admin/i18n.py`。也可 `./do.sh admin`。仅本机回环、无鉴权，不要对局域网开放。
- 窗口上除了 Logo、标语和底栏不放文字。内容来自 `tools/macos/launcher/launcher.json`，路径都相对仓库根目录：
  - `heroes`：背景插画列表，每次打开窗口随机挑一张。每项的 `image` 按窗口铺满、保留右边缘（不填就画图标的剑和环）；`logo` 和 `slogan` 是这张图上 Logo 和标语的中心点 `{ "x", "y" }`，单位是窗口的点（960×600，从左上角算起）。不写 `logo` 用默认位置，不写 `slogan` 就放在 Logo 正下方。换图时按画面的空处调这两个点，让文字和画面主体错开。
  - `logo`：`image` 是 Logo 图片，`width` 是显示宽度（高度按比例）。默认的 `logo.png` 由 `swift tools/macos/launcher/render-logo.swift tools/macos/launcher/logo.png` 画出来：Hoefler Text Black 的 SOLOROTH，第一个 O 换成图标的环和剑，透明底、3 倍分辨率，四周留了阴影的边。改了脚本要重新运行它再提交 PNG。
  - `slogan`：`text` 是标语（空就不显示），`size` 是字号，`rule` 是两侧渐隐金线的长度（0 不画）。
  - `links`（底栏链接）、`promo`（左下角推广位，`title` 和 `text` 都为空时不显示；`url` 是点击后打开的网址，`image` 是图片路径）。

  `benilla-config/launcher.json` 里写的顶层键会整个替换掉仓库里的同名键。第一次打开「编辑启动器设置」时只会新建 `"skip": false`；写成 `true` 就跳过窗口。临时跳过一次：`open --env SOLOROTH_SKIP_LAUNCHER=1 -a Soloroth`。
- 出一张截图，不开窗口：

  ```sh
  swiftc -O -o /tmp/Launcher tools/macos/launcher/Launcher.swift
  /tmp/Launcher --root "$PWD" --snapshot /tmp/launcher.png                    # 仓库默认内容
  /tmp/Launcher --root "$PWD" --config promo.json --snapshot /tmp/promo.png   # 叠加一份测试配置
  /tmp/Launcher --root "$PWD" --hero 1 --snapshot /tmp/launcher-hero1.png     # 指定 heroes 里的第 2 张
  ```

  截图不随机，不加 `--hero` 时取第一张。README 顶部的 `.github/images/launcher.jpg` 就是这样生成的。

## 自动登录与登录界面

- `benilla-config/login.env` 是玩家自己的账号（不进 git）。有这个文件时，默认干掉整个登录页 `AccountLogin`（暗门、按钮、Logo 全不要），黑屏自动登录进角色选择；角色列表点「后退」、或服务器断开，都会退出客户端。
- 没有该文件、或设了 `WOW_SHOW_LOGIN_UI=1` 时保留原版登录页。也可 `WOW_SHOW_LOGIN_UI=1 ./do.sh play`。
- 用 `WOW_STOCK_UI=1 ./do.sh play` 启动会恢复原版 Glue 界面（不用 pfUI 皮肤的登录/角色页）。

登录、角色选择和角色创建界面不归插件管。它们的 pfUI 样式由 `tools/glue-skin/SoloGlueSkin.lua` 实现：`play.sh` 和 `start-client.sh` 每次开客户端时从 MPQ 读出原版 `GlueXML.toc`，加上这个文件，打包成 `Data/patch-S.MPQ`（`rebuild_glue_patch`）。客户端只从 MPQ 读 GlueXML，不读松散文件。同一路径还会打 `Data/patch-T.MPQ`（`rebuild_enchant_scrolls_patch`）：把永久附魔的 Spell.dbc 改成制造卷轴，并加上卷轴使用法术。服务器已在跑时启动器只走 `start-client.sh`，所以那条路径也必须重打补丁。有 `login.env` 时补丁默认加 `--hide-login-ui`；没有该文件或设了 `WOW_SHOW_LOGIN_UI=1` 时用 `--show-login-ui`。角色选择由 `LayoutCharSelect` 重排（右侧名单栏、居中进入世界、底栏返回/删除），并隐藏「插件」「切换服务器」、服务器名和剩余游戏时间等；插件由 `install-addons.sh` 管理。

附魔卷轴数据：改 `tools/enchant-scrolls/gen-enchant-scrolls.py` 后运行它写出迁移和 `map.json`，再 `build-classic.sh server`；客户端侧 `build-patch.py` / 启动时的 `rebuild_enchant_scrolls_patch` 会按 `map.json` 重打 Spell.dbc。

## 插件与单人设置

- `tools/macos/install-addons.sh`（或 `./do.sh addons`）把 `Interface/AddOns` 拷进 `$BENILLA_HOME/AddOns`（默认 `benilla-config/`）。新插件文件需要**完全重启**客户端，`/reload` 不够。
- pfUI、Atlas、AtlasLoot 是收进来的单人代码，可以直接改（去掉社交、PvP、拍卖、邮件、交易、战场，以及别的客户端或资料片用不到的部分）。默认值和外观仍写在 `Interface/AddOns/!Solo`（见其 `AGENTS.md`）。背包整理在 pfUI 里，没有单独的 SortBags。
- 想改某一项单人设置，改 `!Solo` 里对应的表，再跑 `install-addons.sh`。

## 客户端外观补丁

始终挂载 HD（Project Reforged 全套：生物 / 环境 / 物品），没有玩家切换入口，也不能切回原版。`setup-classic.sh` 在包缺失时会自动下载；`play.sh` 每次启动再挂载一次。

```sh
tools/macos/fetch-visual-patches.sh   # 下载 B/C/D/E/G/H → visual-patches/hd/（可中断续传）
tools/macos/apply-visual.sh           # 链接进 Data/
tools/macos/apply-visual.sh --status
./do.sh visual                        # 同上：下载并挂载
```

`apply-visual.sh` 挂上含 Reforged `patch-C` 时，还会用 `tools/macos/build-hd-overrides.py` 写出 `Data/patch-V.MPQ`：把 `CreatureModelData` 里 `ModelScale=0` 的行（含加摩拉用的 `AncientSeaTurtle`）补成 `1`，否则 benilla 会画黑块。原版 Windows 客户端要的 VanillaHelpers / DXVK，benilla 用不上。

## 目录

| 位置 | 内容 |
|---|---|
| `server/core` | 服务端（子模块 [soloroth-server](https://github.com/vvenv/soloroth-server)）：原版 vmangos 加上 macOS 修复、副本机器人 `src/game/PlayerBots/DungeonBotMgr.*`、成就 `src/game/AchievementMgr.*` 和副本进度 `src/game/DungeonProgress.*` |
| `client` | 客户端（子模块 [soloroth-client](https://github.com/vvenv/soloroth-client)）：[benilla](https://github.com/samwhosung/benilla)，用 Rust 从零写的 1.12 客户端，加上少量修复 |
| `Interface/AddOns` | 整套插件：GMBox、副本中心 `Dungeon`（列表传送 / 逐张重置；`MapLoot.lua` 内嵌 Atlas 图；`Progress.lua` + `MinimapPins.lua` 首领进度数据与小地图序号；副本内默认开地图）、组队 `Bots`、宠物与坐骑 `Companions`（`/cw`；数据由 `tools/macos/gen-companions-data.py` 生成）、成就窗口 `Achievements`、单人设置插件 `!Solo`（名字以 `!` 开头，保证比其他插件先加载），以及收进来的 pfUI（含背包整理）、Atlas、AtlasLoot |
| `config/` | 服务端配置改动（`*.overrides.conf`，含 `Instance.AutoReset = 0`：副本只认手动重置）和 MariaDB 配置 |
| `tools/macos/` | 构建、安装、启动脚本（含 `start-client.sh`、`start-admin.sh`） |
| `tools/macos/launcher/` | Soloroth.app 的启动器窗口和它的内容配置 |
| `tools/macos/admin/` | 本机 Web 管理台（`server.py`，`127.0.0.1:8765`） |
| `tools/achievements/` | 成就定义的生成脚本 |
| `tools/enchant-scrolls/` | 永久附魔改为制造卷轴：生成 world 迁移与 `Data/patch-T.MPQ`（Spell.dbc） |
| `tools/glue-skin/` | 登录和角色界面的 pfUI 样式，和把它打包成 `Data/patch-S.MPQ` 的脚本 |
| `tools/lib/` | `do.sh` 用的交互菜单和日志库 |
| `do.sh` | 根目录交互入口（主菜单日常项 +「更多」；子命令直达） |
| `benilla-config/` | 客户端设置、插件（`AddOns/`）、插件存档（`saved/`）和本地的启动器配置，不进 git |
| `Data/` | 指向客户端 MPQ 和登录条款 HTML 的链接，不进 git |
| `server/run`、`server/data`、`server/logs` | 服务端运行目录、地图数据、日志，不进 git |
| `release/` | 编译产物，不进 git |

成就的定义由 `tools/achievements/gen-achievements.py` 从世界数据库和客户端数据生成，一次写出服务端的迁移和插件的 `Data.lua`，要改就改这个脚本。

小动物 / 坐骑：服务端 `Player::CompanionUnlockSpell` / `AbsorbCompanionToken` 在 `StoreItem` 时把 on-use 含 `SUMMON_CRITTER` 或 `SPELL_AURA_MOUNTED` 的道具学会法术并销毁（登录加载同一路径，等于扫包迁移）。插件目录列表由 `tools/macos/gen-companions-data.py` 从 `item_template` + `spell_template` 写出。

## 跟进 vmangos 上游

服务端完全是 vmangos 原版加我们自己的少量提交，跟进上游很直接：

```sh
cd server/core
git remote add upstream https://github.com/vmangos/core.git   # 只需第一次
git fetch upstream
git merge upstream/development
cd ../.. && tools/macos/build-classic.sh server && tools/macos/setup-classic.sh
```

新增数据库迁移文件（`server/core/sql/migrations`）之后要重新编译服务端，因为 `mangosd` 会把迁移列表编进程序。数据库缺迁移时它会拒绝启动。

## 客户端探测（给代理 / 自动化）

- `benilla-config/login.env` 是玩家账号：脚本化登录不要用它（会踢掉正在玩的人）。探测账号在 `client/.probe-identity`（SQUADTEST）；`smoke-client.sh` 默认 PLAYER，需用该文件里的 `WOW_USER` / `WOW_PASS` / `WOW_CHAR` 覆盖。
- 用临时的 `BENILLA_HOME`（例如 `/tmp/soloprobe`，由 `install-addons.sh` 填好），避免动到玩家设置。
- 开发版探测：`WOW_PROBE_LUA`（+`_AT`）进世界后跑 Lua；`WOW_LIVE_SHOT`（+`_AT`）；`WOW_PROBE_EXIT_AT`；`WOW_WIN=1600x960`。Glue 界面：`WOW_PROBE_GLUE_LUA`（+`_AT`）、`WOW_PROBE_GLUE_SHOT`（+`_AFTER`）。游戏内 `Screenshot()` 写到 `$BENILLA_HOME/Screenshots`。
- 用截图核对 UI 改动，不要只靠推理锚点。Agent 约束见根目录 [AGENTS.md](AGENTS.md)。
