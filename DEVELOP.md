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

1. **`build-classic.sh`**：编译服务端（`mangosd`、`realmd`），装到 `release/build/macos/server-classic`；再编译客户端，生成 `release/build/macos/client-target/release/benilla`。也可以只编一边：`build-classic.sh server` 或 `build-classic.sh client`。日常改 Rust / UI 用 **`build-classic.sh iter`**（或 `./do.sh build iter`）：`--profile play`（release 级优化 + incremental），产物在 `…/client-target/play/benilla`；`start-client.sh` / Soloroth.app 会自动选较新的那份。装 App、发版、`./do.sh first` 仍走 `client`（`--release`）。有 `sccache` 时脚本会自动设 `RUSTC_WRAPPER`。
2. **`setup-classic.sh`**：重复运行是安全的，已有的东西不会动。它会：
   - 把服务端程序和地图数据链接进 `server/run`、`server/data`；
   - 初始化并启动 MariaDB（数据在 `server/mariadb-data`）；
   - 第一次运行时，下载 vmangos 官方世界数据库快照（约 30 MB），建四个库：`classic_world`、`classic_characters`、`classic_realmd`、`classic_logs`；以后再运行只补新的数据库迁移；建库末尾会跑 `sql/custom/repack/AQ-SET_GATES_OPEN.sql`，安其拉之门默认已开；
   - 生成服务端配置，把 `Data/` 链接到客户端的 MPQ，以及登录界面要用的 `tos.html` / `eula.html` 等松散文件；
   - 设置客户端（服务器名 Azeroth，不限插件脚本内存），安装插件。

   加 `--reset-db` 会清空重建这四个库，**角色也会被清掉**。
3. **`create-account.sh`**：需要服务器在运行。加 `gm` 的账号才能用 GMBox 的传送、物品和工具按钮；机器人组队不需要 GM。建的第一个账号会存进 `benilla-config/login.env`，以后自动用它登录。
4. **`make-app.sh`**：生成 `Soloroth.app`，默认放进 `/Applications`，也可以指定目录：`make-app.sh ~/Desktop`。启动台、Spotlight、程序坞和「强制退出」里的名字都是 Soloroth，图标是 `tools/macos/AppIcon.png`。它直接运行这个仓库里的脚本，客户端重新编译之后，下次启动会自动换上新的。仓库换了位置、换了图标，或者改了启动器的代码（`Launcher.swift`），才要再运行一次。

主菜单只留日常项；开服务器、setup、建账号、App、HD、对照表在「更多…」。菜单会根据源码和二进制的新旧提示该不该编译；不确定时看 `./do.sh status`（或菜单「更多 → 对照表」）。cargo / cmake 本身是增量的，提示说要编时再跑即可。客户端日常用 **`./do.sh build iter`**，不要每次 `build client`（后者无 incremental，改一行也会很慢）。

## 启动器窗口

双击 Soloroth.app 先打开的那个窗口，源码在 `tools/macos/launcher/`：

- `Launcher.swift` 是单文件的 AppKit 程序，`make-app.sh` 用 Xcode 命令行工具里的 `swiftc` 把它编进 `Soloroth.app/Contents/MacOS/Launcher`。编译失败时 app 照样能用，只是不弹窗口，直接进游戏。
- 窗口一打开就在后台运行 `play.sh --no-client`（开服、外观补丁、登录界面补丁），底栏显示进度。点「开始游戏」时窗口**不退出**，自己跑 `start-client.sh`（把 benilla 拷进 `Contents/MacOS/Soloroth` 以保持 Dock 图标）；还没有 `login.env` 账号密码时先弹 sheet 校验并写入。游戏退出后底栏回到「服务器已就绪」。启动器窗口总是弹出；`SOLOROTH_SKIP_LAUNCHER=1` 时不弹窗，`launch` 脚本直接 `play.sh`（CLI 路径自己问账号）。关掉启动器窗口或按 ⌘Q 是退出码 1，离开 app（并停掉本机 Web 管理台）；服务器和已在跑的客户端继续。
- ··· 菜单「设置…」是一个 sheet：改 `benilla-config/login.env`（账号 / 密码 / 可选角色）；密码留空表示不改已保存的。「打开管理界面」会跑 `start-admin.sh`：在 `127.0.0.1:8765` 起 `tools/macos/admin/server.py`（账号 / 角色 / 四个 `classic_*` 库浏览与 SQL；顶栏可切中英文与深色/浅色，Cookie 记住；列表可筛选，宽表 sticky 首列/表头）。文案在 `tools/macos/admin/i18n.py`。也可 `./do.sh admin`。仅本机回环、无鉴权，不要对局域网开放。
- 窗口上除了 Logo、标语和底栏不放文字（设置表单是 sheet，不画在英雄图上）。内容来自 `tools/macos/launcher/launcher.json`，路径都相对仓库根目录：
  - `heroes`：背景插画列表，每次打开窗口随机挑一张。每项的 `image` 按窗口铺满、保留右边缘（不填就画图标的剑和环）；`logo` 和 `slogan` 是这张图上 Logo 和标语的中心点 `{ "x", "y" }`，单位是窗口的点（960×600，从左上角算起）。不写 `logo` 用默认位置，不写 `slogan` 就放在 Logo 正下方。换图时按画面的空处调这两个点，让文字和画面主体错开。
  - `logo`：`image` 是 Logo 图片，`width` 是显示宽度（高度按比例）。默认的 `logo.png` 由 `swift tools/macos/launcher/render-logo.swift tools/macos/launcher/logo.png` 画出来：Hoefler Text Black 的 SOLOROTH，第一个 O 换成图标的环和剑，透明底、3 倍分辨率，四周留了阴影的边。改了脚本要重新运行它再提交 PNG。
  - `slogan`：`text` 是标语（空就不显示），`size` 是字号，`rule` 是两侧渐隐金线的长度（0 不画）。
  - `links`（底栏链接）、`promo`（左下角推广位，`title` 和 `text` 都为空时不显示；`url` 是点击后打开的网址，`image` 是图片路径）。

  `benilla-config/launcher.json` 里写的顶层键会整个替换掉仓库里的同名键。临时跳过窗口一次：`open --env SOLOROTH_SKIP_LAUNCHER=1 -a Soloroth`。
- 出一张截图，不开窗口：

  ```sh
  swiftc -O -o /tmp/Launcher tools/macos/launcher/Launcher.swift
  /tmp/Launcher --root "$PWD" --snapshot /tmp/launcher.png                    # 仓库默认内容
  /tmp/Launcher --root "$PWD" --config promo.json --snapshot /tmp/promo.png   # 叠加一份测试配置
  /tmp/Launcher --root "$PWD" --hero 1 --snapshot /tmp/launcher-hero1.png     # 指定 heroes 里的第 2 张
  ```

  截图不随机，不加 `--hero` 时取第一张。README 顶部的 `.github/images/launcher.jpg` 就是这样生成的。

## 自动登录与登录界面

- `benilla-config/login.env` 是玩家自己的账号（不进 git）。账号密码只在启动器 sheet（或 `play.sh` 的 TTY/osascript）里输入。`bundle.sh` 在有该文件时导出 `WOW_NO_LOGIN_UI=1`：客户端不坐 `SET_GLUE_SCREEN("login")`，断线 / 返回登录改为退出进程。有账号密码时自动进角色选择；角色列表点「返回」、或服务器断开，都会退出客户端回到启动器。缺有效凭证时不启动客户端。

产品界面是客户端 Rust 原生 UI（`client/crates/soloroth-ui`，`WOW_NATIVE_UI` 默认开）：进世界不加载 FrameXML/AddOns；选角由 native UI 绘制，stock GlueXML 画在客户端关掉。世界 / glue Lua 与 `patch-S` 已退役。`play.sh` / `start-client.sh` 每次跑 `tools/macos/prune-legacy-ui.sh`（只清残留）。同一路径打 `Data/patch-T.MPQ`。`WOW_NATIVE_UI=0` 回退 stock FrameXML（无产品 Lua 皮）。

附魔卷轴数据：改 `tools/enchant-scrolls/gen-enchant-scrolls.py` 后运行它写出迁移和 `map.json`，再 `build-classic.sh server`；客户端侧 `tools/enchant-scrolls` 的 `build-patch.py` / 启动时的 `rebuild_enchant_scrolls_patch` 会按 `map.json` 重打 Spell.dbc。

## 产品界面与单人设置

- `tools/macos/prune-legacy-ui.sh`（或 `./do.sh ui`）：清掉旧 `patch-S` / 产品 AddOns。改 `soloroth-ui` 需重编客户端。
- 新产品界面写在 `client/crates/soloroth-ui`（及 `benilla-app` `native_ui`）。面板内容列用 `chrome::{PAD, after_title, content_band, body_band, footer_band}`：header（标题）→ tabs/toolbar → body → footer 左右对齐，别再各写一套 `r.x + 12` / 浮动顶栏钮。外壳宽度用 `chrome::width::{S,M,L,XL}`（360/420/480/560）按内容就近取档；`width::fit(content)` 给格子类（背包/银行/天赋）；地图单独 `MAP`。

### UI 验收清单

视觉北极星：README 四张游戏截图（[`.github/images/world.jpg`](.github/images/world.jpg)、[`dungeon.jpg`](.github/images/dungeon.jpg)、[`dungeon-hub.jpg`](.github/images/dungeon-hub.jpg)、[`wailing-caverns.jpg`](.github/images/wailing-caverns.jpg)）。未出镜面板按同族 Adapta 语汇（青绿半透明底、1px 黑边、黄标题）脑补。改完一类用 `WOW_LIVE_SHOT` 对照。

| 面 | README 图 | 要点 |
|---|---|---|
| HUD 单位框 | world / dungeon | 中部扁平血/蓝条 |
| HUD 动作条 + 左右 4×3 侧栏 | world / dungeon / dungeon-hub | 底中 12 格 + MultiBarBottomLeft/Right；顶细 XP 绿线 |
| HUD 消息板 | world / dungeon | 左下约 320 宽（高与右下命令条同）；内边距 + 行高 15；悬停 ▲▼ / 滚轮翻页 |
| HUD 小地图 + 命令条 | world / dungeon | 右上方形；区名 / 坐标；右下角双排图标（同侧栏尺寸） |
| 副本面板 | dungeon-hub | 「列表/地图」、红名、黄等级、重置 |
| 系统面板 | （脑补） | 背包 / 法术书 / 角色 / 天赋 / 地图 / 选项 / 按键 / Esc / 观察 |
| NPC 窗 | （脑补） | 商人 / 训练师 / 对话 / 拾取 / 银行 / 制造 |
| 产品窗 | （脑补；副本有图） | 组队 / 挂机 / 传送 / 物品 / 宠物 / 成就 / GM |
| 模态 | （脑补） | 绑定 / 组队邀请 / 死亡套件 |
| Glue | （中间 3D booth；无 README 图） | 选角 / 创角；ModelFFX 预览 + 右侧原生边栏 |

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
| `client` | 客户端（子模块 [soloroth-client](https://github.com/vvenv/soloroth-client)）：[benilla](https://github.com/samwhosung/benilla)，用 Rust 从零写的 1.12 客户端，加上少量修复；产品 UI 在 `crates/soloroth-ui` |
| `config/` | 服务端配置改动（`*.overrides.conf`，含 `Instance.AutoReset = 0`：副本只认手动重置）和 MariaDB 配置 |
| `tools/macos/` | 构建、安装、启动脚本（含 `start-client.sh`、`start-admin.sh`、`prune-legacy-ui.sh`） |
| `tools/macos/launcher/` | Soloroth.app 的启动器窗口和它的内容配置 |
| `tools/macos/admin/` | 本机 Web 管理台（`server.py`，`127.0.0.1:8765`） |
| `tools/achievements/` | 成就定义的生成脚本 |
| `tools/tele/` | 传送目录 `tele.bin` 烘焙（`bake-tele-bin.py`） |
| `tools/items/` | 物品搜索目录：`lua_to_bin.py`（SIT1）+ `bake-item-icons.py`（SIT2 图标） |
| `tools/enchant-scrolls/` | 永久附魔改为制造卷轴：生成 world 迁移与 `Data/patch-T.MPQ`（Spell.dbc） |
| `tools/lib/` | `do.sh` 用的交互菜单和日志库 |
| `do.sh` | 根目录交互入口（主菜单日常项 +「更多」；子命令直达） |
| `benilla-config/` | 客户端设置、存档（`saved/`）和本地的启动器配置，不进 git |
| `Data/` | 指向客户端 MPQ 和登录条款 HTML 的链接，不进 git |
| `server/run`、`server/data`、`server/logs` | 服务端运行目录、地图数据、日志，不进 git |
| `release/` | 编译产物，不进 git |

成就的定义由 `tools/achievements/gen-achievements.py` 从世界数据库和客户端数据生成，写出服务端迁移，要改就改这个脚本。客户端目录（标题、说明、点数、条件名）用同目录的 `bake-client-data.py` 烤进 `client/crates/soloroth-ui/src/product/achievements_data.rs`（需 Data/、mpqx、MariaDB）。

传送搜索目录 `client/crates/soloroth-ui/data/tele.bin` 由 `tools/tele/bake-tele-bin.py` 从 `game_tele` + `locales_area` 烘焙；主城分区等 AreaTable 没有的名字在脚本的 `TELE_ZH_OVERRIDES` 里补。改完需重编客户端才进游戏。

物品搜索目录 `client/crates/soloroth-ui/data/items.bin`：名字/拼音来自旧 Items 插件数据（`tools/items/lua_to_bin.py` → SIT1），图标由 `tools/items/bake-item-icons.py` 从 `item_template.display_id` × `ItemDisplayInfo.dbc` 写进 SIT2。改完需重编客户端。

小动物 / 坐骑：服务端 `Player::CompanionUnlockSpell` / `AbsorbCompanionToken` 在 `StoreItem` 时把 on-use 含 `SUMMON_CRITTER` 或 `SPELL_AURA_MOUNTED` 的道具学会法术并销毁（登录加载同一路径，等于扫包迁移）。

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
- 用临时的 `BENILLA_HOME`（例如 `/tmp/soloprobe`），避免动到玩家设置。
- 开发版探测：`WOW_PROBE_LUA`（+`_AT`）进世界后跑 Lua；`WOW_LIVE_SHOT`（+`_AT`）；`WOW_PROBE_EXIT_AT`；`WOW_WIN=1600x960`。Glue 界面：`WOW_PROBE_GLUE_LUA`（+`_AT`）、`WOW_PROBE_GLUE_SHOT`（+`_AFTER`）。游戏内 `Screenshot()` 写到 `$BENILLA_HOME/Screenshots`。
- 用截图核对 UI 改动，不要只靠推理锚点。Agent 约束见根目录 [AGENTS.md](AGENTS.md)。

### 产品 UI 质量门禁（`soloroth-ui`）

分层抓不同失败；日常改布局靠 A+B，改 `native_ui` 接线再跑 C，观感仍靠人工截图（D）。

| 层 | 抓什么 | 怎么跑 |
|---|---|---|
| A 逻辑 / 几何 | 缺 hit、点错 Action、控件飞出屏幕 | `cargo test -p soloroth-ui`（在 `client/`） |
| B hit-map golden | 布局漂移（位置 / 尺寸 / z） | 同上；golden 在 `client/crates/soloroth-ui/tests/goldens/` |
| C 真机接线 | 单测绿但进世界空白 | `tools/macos/ui-smoke.sh`（要本机服务器 + 窗口） |
| D 人工 | 观感 / 文案 / 色 | 截图核对（见 AGENTS.md） |

有意改可点布局后重写 golden：

```sh
cd client
SOLOROTH_UI_UPDATE_GOLDEN=1 cargo test -p soloroth-ui --test hitmap_golden
```

真机接线探针（不进 `gates.sh`）：

```sh
# 服务器已起；账号来自 client/.probe-identity
tools/macos/ui-smoke.sh
SOLOROTH_UI_SMOKE_KEEP=/tmp/ui-smoke tools/macos/ui-smoke.sh   # 保留 hud.png
```

不要把产品 HUD 塞进 `client/scripts/visual.sh` 世界像素 CI：那套 `ui-*` 场景是 FrameXML fixture，不是 Soloroth 原生皮。
