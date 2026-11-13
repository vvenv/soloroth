# Soloroth 开发者说明

玩家用的说明在 [README.md](README.md)。这里是各个脚本具体做了什么、仓库的目录，以及怎么跟进上游。

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
   - 第一次运行时，下载 vmangos 官方世界数据库快照（约 30 MB），建四个库：`classic_world`、`classic_characters`、`classic_realmd`、`classic_logs`；以后再运行只补新的数据库迁移；
   - 生成服务端配置，把 `Data/` 链接到客户端的 MPQ，以及登录界面要用的 `tos.html` / `eula.html` 等松散文件；
   - 设置客户端（服务器名 Azeroth，不限插件脚本内存），安装插件。

   加 `--reset-db` 会清空重建这四个库，**角色也会被清掉**。
3. **`create-account.sh`**：需要服务器在运行。加 `gm` 的账号才能用 GMBox 的传送、物品和工具按钮；机器人组队不需要 GM。建的第一个账号会存进 `benilla-config/login.env`，以后自动用它登录。
4. **`make-app.sh`**：生成 `Soloroth.app`，默认放进 `/Applications`，也可以指定目录：`make-app.sh ~/Desktop`。启动台、Spotlight、程序坞和「强制退出」里的名字都是 Soloroth，图标是 `tools/macos/AppIcon.png`。它直接运行这个仓库里的脚本，客户端重新编译之后，下次启动会自动换上新的。仓库换了位置、换了图标，或者改了启动器的代码（`Launcher.swift`），才要再运行一次。

## 启动器窗口

双击 Soloroth.app 先打开的那个窗口，源码在 `tools/macos/launcher/`：

- `Launcher.swift` 是单文件的 AppKit 程序，`make-app.sh` 用 Xcode 命令行工具里的 `swiftc` 把它编进 `Soloroth.app/Contents/MacOS/Launcher`。编译失败时 app 照样能用，只是不弹窗口，直接进游戏。
- 窗口一打开就在后台运行 `play.sh --no-client`（开服、外观补丁、登录界面补丁），底栏显示进度。点「开始游戏」时窗口以退出码 0 结束，app 的启动脚本接着启动客户端；客户端退出后再打开启动器（`skip` / `SOLOROTH_SKIP_LAUNCHER=1` 时不弹窗，跟客户端一起结束）。关掉启动器窗口或按 ⌘Q 是退出码 1，离开 app。
- 窗口上除了底栏不放文字。内容来自 `tools/macos/launcher/launcher.json`：`hero`（背景插画，按窗口铺满、保留右边缘，默认是同目录的 `hero.jpg`；不填就画图标的剑和环）、`links`（底栏链接）、`promo`（左下角推广位，`title` 和 `text` 都为空时不显示；`url` 是点击后打开的网址，`image` 是图片路径，相对仓库根目录）。`benilla-config/launcher.json` 里写的顶层键会整个替换掉仓库里的同名键。
- 出一张截图，不开窗口：

  ```sh
  swiftc -O -o /tmp/Launcher tools/macos/launcher/Launcher.swift
  /tmp/Launcher --root "$PWD" --snapshot /tmp/launcher.png                    # 仓库默认内容
  /tmp/Launcher --root "$PWD" --config promo.json --snapshot /tmp/promo.png   # 叠加一份测试配置
  ```

  README 顶部的 `.github/images/launcher.jpg` 就是这样生成的。

## 目录

| 位置 | 内容 |
|---|---|
| `server/core` | 服务端（子模块 [soloroth-server](https://github.com/vvenv/soloroth-server)）：原版 vmangos 加上 macOS 修复、副本机器人 `src/game/PlayerBots/DungeonBotMgr.*` 和成就 `src/game/AchievementMgr.*` |
| `client` | 客户端（子模块 [soloroth-client](https://github.com/vvenv/soloroth-client)）：[benilla](https://github.com/samwhosung/benilla)，用 Rust 从零写的 1.12 客户端，加上少量修复 |
| `Interface/AddOns` | 整套插件：GMBox、成就窗口 `Achievements`、单人设置插件 `!Solo`（名字以 `!` 开头，保证比其他插件先加载），和第三方的 pfUI、pfQuest、Atlas 三件套、Bagshui 等（原样收录，各自的作者和许可见 THIRD-PARTY-NOTICES.md） |
| `config/` | 服务端配置改动（`*.overrides.conf`）和 MariaDB 配置 |
| `tools/macos/` | 构建、安装、启动脚本 |
| `tools/macos/launcher/` | Soloroth.app 的启动器窗口和它的内容配置 |
| `tools/achievements/` | 成就定义的生成脚本 |
| `tools/glue-skin/` | 登录和角色界面的 pfUI 样式，和把它打包成 `Data/patch-S.MPQ` 的脚本 |
| `tools/lib/` | `do.sh` 用的交互菜单和日志库 |
| `do.sh` | 根目录交互入口（第一次安装、开玩、编译、外观等） |
| `benilla-config/` | 客户端设置、插件（`AddOns/`）、插件存档（`saved/`）和本地的启动器配置，不进 git |
| `Data/` | 指向客户端 MPQ 和登录条款 HTML 的链接，不进 git |
| `server/run`、`server/data`、`server/logs` | 服务端运行目录、地图数据、日志，不进 git |

登录、角色选择和角色创建界面的 pfUI 样式由 `tools/glue-skin/SoloGlueSkin.lua` 实现：`play.sh` 每次启动时从客户端 MPQ 里读出原版 `GlueXML.toc`，加上这个文件，打包成 `Data/patch-S.MPQ`。客户端只从 MPQ 读 GlueXML，不读松散文件。有 `login.env` 时补丁默认干掉整个登录页 `AccountLogin`（`--hide-login-ui`），黑屏等到角色选择；没有该文件、或设了 `WOW_SHOW_LOGIN_UI=1` 时用 `--show-login-ui` 保留。

成就的定义由 `tools/achievements/gen-achievements.py` 从世界数据库和客户端数据生成，一次写出服务端的迁移和插件的 `Data.lua`，要改就改这个脚本。

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
