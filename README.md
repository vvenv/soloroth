# Soloroth（经典单机版）

一个在自己电脑上跑的魔兽世界 1.12.1 经典版：做任务、升级、探索，五人副本里自动有机器人队友补满队伍。

- **原版内容**：服务端是原版 [vmangos](https://github.com/vmangos/core)，世界数据、任务、刷怪都是 1.12 原样。
- **机器人组队**：进入五人副本 3 秒后，队伍自动补满 5 人。缺坦克就补坦克，缺治疗就补治疗，其余补不同职业的输出。bot 和你同级、装备匹配等级，掷骰全部放弃。活着离开副本时 bot 自动解散。
- **中文**：用简体中文 1.12 客户端的数据，界面、任务、NPC、物品都是中文。
- **单人化**：没有聊天频道，聊天框只当消息记录用（系统、拾取、经验、任务和 NPC 说话）。
- **插件**：pfUI、pfQuest、Atlas 三件套、Bagshui 等一套 1.12 插件，已经按单人旅行做任务配好，不弹首次设置向导。另有 GMBox 2.0（副本与机器人面板、传送、物品、GM 工具），界面和 pfUI 风格一致。
- **成就**：3.x 成就里 1.12 世界有的部分（等级、任务、探索、地下城与团队副本，146 个），已有角色登录时按做过的内容补发。
- **低等级任务不白做**：等级高出任务太多、经验打折时，少拿的那部分经验按 60 级的规则折成金币。
- **经验 2 倍**，掉落和金钱保持 1 倍。在 `config/mangosd.overrides.conf` 里可以改。
- **专业不限**：9 个主专业都能学（炼金、锻造、附魔、工程、草药、制皮、采矿、剥皮、裁缝），急救、烹饪、钓鱼照旧不占名额。
- **新角色自带 1 金和 4 只 8 格包**（棕色小皮包）；已有角色不补发。

目前只支持 **Apple Silicon 的 Mac**，从源码构建。

---

## 需要准备

| 东西 | 说明 |
|---|---|
| Mac | Apple Silicon（M 系列芯片）。目前在 macOS 26 上测试过 |
| 开发工具 | Xcode 命令行工具：`xcode-select --install` |
| Homebrew 包 | `brew install cmake mariadb openssl@3 pkg-config` |
| Rust | 用 [rustup](https://rustup.rs) 安装 |
| 1.12.1 客户端 | build 5875 的 `Data` 文件夹。推荐简体中文版（zhCN），英文版（enUS）也可以 |
| 服务端地图数据 | vmangos 提取工具从 1.12 客户端提取的 `maps`、`vmaps`、`mmaps` 和 `5875/dbc` |

默认这些游戏数据都放在仓库**旁边**的 `../wow-data` 里：

```
../wow-data/
├── client-zhCN/Data/        中文客户端的 MPQ（CLIENT_LOCALE=enUS 时用 client/Data）
├── vmangos-deploy/storage/mangosd/extracted-data/
│   ├── maps/  vmaps/  mmaps/  5875/
```

放在别处的话，运行安装脚本时用环境变量指过去：`WOW_DATA_ROOT`（整个文件夹）、`CLIENT_LOCALE`（`zhCN` 或 `enUS`）、`HOA_EXTRACTED`（提取好的地图数据）。

还没有提取好的地图数据的话，用 vmangos 自带的提取工具从 1.12 客户端生成：构建时加 `-DBUILD_EXTRACTORS=1`，用法见 [vmangos](https://github.com/vmangos/core) 的文档。

---

## 第一次安装

```sh
git clone --recurse-submodules https://github.com/vvenv/soloroth.git
cd soloroth

./do.sh                                              # 交互菜单；选「第一次安装」走完下面几步
# 或直接：
./do.sh first                                        # 编译 → 配置 → 开服 → 建账号 → 生成 App
```

也可以逐步跑（菜单和 `./do.sh <子命令>` 都是转发到这些脚本）：

```sh
tools/macos/build-classic.sh                         # 编译服务端和客户端（第一次要编译一阵子）
tools/macos/setup-classic.sh                         # 数据库、配置、客户端数据、插件
tools/macos/play.sh --server-only                    # 先把服务器开起来
tools/macos/create-account.sh 账号 密码 gm           # 建账号；gm 表示给 GM 权限
tools/macos/make-app.sh                              # 生成 /Applications/Soloroth.app
```

以后双击 **Soloroth.app**（或者在启动台、Spotlight 里搜 Soloroth）就能玩：服务器没开会先开，然后自动登录，直接到角色选择。日常也可用 `./do.sh`（开始玩、关服务器、编译、更新插件、外观补丁等）。

各步骤做了什么：

1. **`build-classic.sh`**：编译服务端（`mangosd`、`realmd`），装到 `release/build/macos/server-classic`；再编译客户端，生成 `release/build/macos/client-target/release/benilla`。也可以只编一边：`build-classic.sh server` 或 `build-classic.sh client`。
2. **`setup-classic.sh`**：重复运行是安全的，已有的东西不会动。它会：
   - 把服务端程序和地图数据链接进 `server/run`、`server/data`；
   - 初始化并启动 MariaDB（数据在 `server/mariadb-data`）；
   - 第一次运行时，下载 vmangos 官方世界数据库快照（约 30 MB），建四个库：`classic_world`、`classic_characters`、`classic_realmd`、`classic_logs`；以后再运行只补新的数据库迁移；
   - 生成服务端配置，把 `Data/` 链接到客户端的 MPQ，以及登录界面要用的 `tos.html` / `eula.html` 等松散文件；
   - 设置客户端（服务器名 Azeroth，不限插件脚本内存），安装插件。

   加 `--reset-db` 会清空重建这四个库，**角色也会被清掉**。
3. **`create-account.sh`**：需要服务器在运行。加 `gm` 的账号才能用 GMBox 的传送、物品和工具按钮；机器人组队不需要 GM。建的第一个账号会存进 `benilla-config/login.env`，以后自动用它登录。
4. **`make-app.sh`**：生成启动器 `Soloroth.app`，默认放进 `/Applications`，也可以指定目录：`make-app.sh ~/Desktop`。启动台、Spotlight、程序坞和「强制退出」里的名字都是 Soloroth，图标是仓库里的 `tools/macos/AppIcon.png`。窗口标题在重新编译客户端之后也是 Soloroth。它直接运行这个仓库里的脚本；客户端重新编译之后，下次启动会自动换上新的。只有仓库换了位置，或换了图标，才要再运行一次。想换成自己的图标，放一张 1024×1024 的 `AppIcon.png` 再运行即可。

### 自动登录

`play.sh` 和 Soloroth.app 用 `benilla-config/login.env` 里的账号自动登录（这个文件不进 git，只有你自己能读）：

```
WOW_USER=PLAYER
WOW_PASS=密码
# WOW_CHAR=角色名  (进游戏时跳过角色选择)
```

- 没有这个文件时，第一次启动会弹窗问一次账号密码，跟服务器核对无误后保存；服务器上还没有账号的话，直接建一个 `PLAYER`（带 GM 权限）。在弹窗里点取消，就照常显示登录界面。
- 去掉 `WOW_CHAR` 那行前面的 `#` 并填上角色名，启动后直接进入这个角色的游戏世界。
- 改了密码或想换账号，删掉 `login.env`，下次启动会重新问。

## 日常使用

根目录 `./do.sh` 是交互菜单（也可 `./do.sh play` 等子命令），对应下面这些脚本。菜单会根据源码和二进制的新旧提示该不该编译；不确定时看 `./do.sh status`。Esc / ← 返回上一级。cargo / cmake 本身是增量的，提示说要编时再跑即可。

| 做什么 | 命令 |
|---|---|
| 开始玩 | 双击 Soloroth.app，或 `./do.sh play`（服务器没开会先开） |
| 只开服务器 | `./do.sh server` |
| 关服务器 | `./do.sh stop`（可选连 MariaDB 一起关） |
| 该不该编译？ | `./do.sh status`（或菜单里的提示） |
| 拉代码后重新编译 | `./do.sh build`，再 `./do.sh setup`（补数据库迁移） |
| 改了服务端设置 | 改 `config/mangosd.overrides.conf`，然后 `./do.sh config`，重启服务器 |
| 更新插件 | 拉代码后 `./do.sh addons`，然后**完全重启**客户端（`/reload` 不会加载新插件） |
| 原版 / HD 模型 | 选项 → 图形 →「怪物模型」，或 `./do.sh visual`；重启生效；见下文「客户端外观」 |

关掉客户端后服务器会继续运行。服务器的输出在 `server/logs/mangosd.out`，Soloroth.app 的输出在 `server/logs/launcher.log`。

---

## 客户端外观（原版 / HD 怪物模型）

默认是 **原版** 1.12 模型。想用更精细的怪物，下载社区补丁（Project Reforged）后在游戏里切换，不用改服务端。

```sh
tools/macos/fetch-visual-patches.sh        # 下载 Reforged 生物包 Patch-C（约 2 GB，可中断，重跑续传）
tools/macos/fetch-visual-patches.sh --hd   # 再加环境 / 物品等整套（B、D、E、G、H）
```

- **游戏里切换**：选项 → 图形 → 最下面的「怪物模型」，或 `/visual` / `/waiguan`。还没下载的方案是灰色，标「未安装」。选好后**完全退出再开**才会换模型；没重启前这一行旁边会提示「重启后生效」。
- 方案：「原版」「高清怪物（Reforged）」只换生物；「高清合集（Reforged 全套）」在下载了 `--hd` 后多出环境和物品；「Improved Models」要自己把 MPQ 放进 `../wow-data/visual-patches/improved-models/`（见那里的 README.txt）。
- 选择写在 `config.toml` 的 `solorothVisual`，`play.sh` 启动前按它把补丁链接进 `Data/`。命令行也能切：`tools/macos/apply-visual.sh hd` / `vanilla` / `--list`。
- 下载器按 10 MB 分块并行下载，并用服务器的校验值核对整个文件；文件不完整时，怪物会隐形或变成方块。
- 原版 Windows 客户端要的 VanillaHelpers / DXVK，benilla **用不上**。

---

## 游戏里

### 机器人队友

- 进五人副本 3 秒后自动补满队伍。登录时就在副本里也算进入。
- 活着离开副本，副本里补的 bot 会解散；死了跑尸的路上不会解散。
- 团队副本不会自动补。在野外想带 bot 做精英任务，用「补满队伍」或 `.bots fill`。

**GMBox 的「副本」页**：输入 `/gd`，或者右键小地图上的 GMBox 按钮打开。

- **我的职责**：自动、坦克、治疗、输出四选一，bot 会补齐你之外的职责。选“自动”时，按职业、天赋和是否带盾来判断。
- **进副本自动补机器人**开关，**补满队伍**，**解散机器人**。
- **副本列表**：按推荐等级排序，颜色和任务日志一样。点一下直接传送进副本，这个功能需要 GM 账号。
- **指挥**：到我身边、集火目标、停手、坦克拉怪（输出 bot 等 10 秒再动手）、原地待命、继续。

不用插件也可以直接输命令：

| 命令 | 作用 |
|---|---|
| `.bots` | 查看自己的职责和自动补位设置 |
| `.bots role tank\|healer\|dps\|auto` | 设定自己的职责 |
| `.bots auto on\|off` | 进副本是否自动补 bot |
| `.bots fill` / `.bots dismiss` | 立刻补满 / 解散 bot |
| `.partybot cometome` | 所有 bot 到你身边 |
| `.partybot attackstart` / `attackstop` | 集火你的目标 / 停手 |
| `.partybot pull` | 坦克 bot 去拉你选中的怪 |
| `.partybot pause` / `unpause` | 原地待命 / 继续（选中某个 bot 时只对它生效） |

### 单人设置（Solo 插件）

`Interface/AddOns/!Solo` 每次登录都会对每个角色生效：

- **聊天**：不显示说话、喊话、表情、密语、队伍、公会和频道消息，只保留系统、拾取、金钱、经验、声望、技能、任务和 NPC 说话。服务器也拒绝加入任何频道（`Channel.Disable = 1`）。
- **pfUI**：跳过首次设置向导，新角色用 Modern 布局。另外：
  - 世界地图显示未探索区域；小地图放大，常显区域名和坐标；任务日志显示等级；
  - 左下信息栏不显示公会和好友，改为经验、耐久、背包空格；右下是战斗计时（这一场或上一场打了多久）、时间、金币；
  - 聊天框旁的经验条一直显示，不只在拿到经验后亮一下；
  - 升级和拿到史诗装备时自动截图，自动卖灰色物品；
  - 鼠标指向装备（任务奖励、拾取、商人）时，总是在旁边显示身上对应的装备做对比，不用按 Shift；
  - 关掉团队框体、更新检查、密语转发、社交增强、复制聊天和 pfUI 自带背包（背包用 Bagshui）。
- **击杀后自动拾取**（默认开）：怪物死后，掉落的物品和金钱直接进背包，不用点尸体；背包放不下的留在尸体上，可以照常手动拾取。在「选项 → 控制」里「自动拾取」下面的「击杀后自动拾取」开关，或输入 `/autoloot on|off`（服务端命令是 `.solo autoloot on|off`）。
- **拾取特效**（默认开）：拾到的时候角色身上扩散出一圈光环，每件物品在角色头上弹出（光晕是品质颜色），再飞进右下角的背包，角色右边浮出「+ [物品] x数量」和金钱。史诗以上还有音效。在「选项 → 控制」的「拾取特效」关掉，或 `/autoloot fx off`；`/autoloot test` 可以预览。
- **浮动战斗信息**：第一次登录时打开（伤害、治疗、躲闪/招架/未命中、进出战斗），以后在「选项 → 战斗」里关掉就不会再被打开。
- **pfQuest**：新角色跳过欢迎向导，世界地图显示刷怪点和任务图标，小地图显示刷怪点，打开导航箭头。
- **ESC 菜单和「选项」窗口**：换成 pfUI 的样式；去掉客户端里还没有功能的「编辑模式」按钮和「插件」页，以及 SuperMacro 挂在菜单边上的「宏命令」按钮（它的编辑器用 `/supermacro` 打开）。界面文字是中文。
- **其他窗口也换成 pfUI 的样式**（作为 pfUI 皮肤注册，在 pfUI 设置里可以单独关掉，插件源码不改）：Atlas 地图（AtlasLoot 面板贴在下方，AtlasQuest 贴在旁边）、AtlasLoot、SuperMacro 编辑器和图标选择、ShaguNotify 的提示条、脚本错误日志（`/errors`），以及这些插件的设置窗口。原版窗口由 pfUI 自己的皮肤负责；Bagshui 自带 pfUI 皮肤。

登录、角色选择和角色创建界面不归插件管，它们的 pfUI 样式由 `tools/glue-skin/SoloGlueSkin.lua` 实现：`play.sh` 每次启动时从客户端 MPQ 里读出原版 `GlueXML.toc`，加上这个文件，打包成 `Data/patch-S.MPQ`。用 `WOW_STOCK_UI=1` 启动就会去掉它，恢复原版界面。

进世界、切地图和坐船时，客户端不显示原版的地图插画，只有黑底、底部一条细进度条和小提示，等地图加载好就消失。

想改某一项，就改 `Solo.lua` 里对应的表，再运行 `tools/macos/install-addons.sh`。

### 自动打怪和自动钓鱼

1.12 的插件不能替玩家走路和施法，所以这两项由服务器直接驱动你的角色（和队伍 bot 用的是同一套职业战斗逻辑），插件只负责命令和面板。

- **自动打怪**：`/dg [码数]`（或 `/grind`）。以当前位置为中心，默认 40 码，最大 150。角色在范围里游荡，找怪、上去打、拾取（物品和金钱直接进背包）。用的是你自己学会的技能（战士会自己换姿态）。血低于 60%、或蓝低于 40% 时停下休息到 95%：会治疗的职业先给自己加血，背包里有食物、饮料就吃喝。战斗中血低于 30% 会喝背包里的治疗药水。不打精英、灰名怪、比你高 3 级或更多的怪，也不抢别人的怪。
- **自动钓鱼**：`/dy [码数]`（或 `/fish`）。默认 25 码，最大 60。要先学会钓鱼、背包里有鱼竿。范围里有鱼群就走到鱼群边上钓，没有就找一片能下钩的水面。鱼竿自动换上，停止时换回原来的武器。被怪打了会换回武器打完再继续钓。
- **面板**：屏幕上方显示正在打怪还是钓鱼、范围和已运行时间，可以拖动，「停止」按钮随时停下。`/farm` 查看状态。
- **停止**：点面板的「停止」，或输入 `/farm stop`（服务端命令是 `.solo stop`），或在「按键设置」的「单人挂机」里给「停止自动打怪/钓鱼」绑一个键。角色站着不动（休息、钓鱼）时按移动键也会停止；服务器正在带着角色走的时候，客户端不响应移动键，这时请用按钮或快捷键。角色死亡、背包满了、离中心太远（比如炉石、坐飞行点）、下线时也会自动停止。

服务端命令是 `.solo grind [码数]`、`.solo fish [码数]`、`.solo stop`、`.solo farm`（查看状态）。

### 成就

输入 `/ach`（或 `/cj`），或者点小地图上的缎带按钮打开成就窗口。获得成就时屏幕上方弹出提示，聊天框也有一行。

- **综合**：10 到 60 级。
- **任务**：完成任务总数；各区域的任务（要求该区域本阵营能接的任务的六成）；两块大陆的博学者和博学者。
- **探索**：探索每个区域（世界地图上被遮住的每一块都算一项），探索东部王国、卡利姆多，世界探索者。
- **地下城与团队副本**：每个经典副本的最终首领，和机器人一起打也算；经典地下城大师、经典团队副本攻略者。

等级、任务和探索是登录时从角色身上重新数的，所以老角色一登录就能拿到已经做到的；首领击杀从开始有成就系统时算起。分阵营的成就（各区域任务、博学者）只显示本阵营的那一份。

| 命令 | 作用 |
|---|---|
| `.achievement` | 已获得的成就数和点数 |
| `.achievement add\|remove <id>` | GM：给选中的角色发放 / 收回一个成就（还满足条件的会马上回来） |
| `.achievement reset` | GM：清空选中角色的成就，按角色现状重新数（首领击杀会清掉） |

成就的定义由 `tools/achievements/gen-achievements.py` 从世界数据库和客户端数据生成，一次写出服务端的迁移和插件的 `Data.lua`，要改就改这个脚本。

### GMBox 的其他页

- **传送**：服务器上的 997 个传送点，中文、英文、拼音都能搜。也可以用 `/gt 地名`。
- **物品**：按名字或 id 搜物品放进背包，可以勾选“我能用”。也可以用 `/gi 名字 数量`。
- **工具**：GM 模式、无敌、飞行、复活、修理、学技能、加速、加钱加等级，以及任意命令输入框。

---

## 目录

| 位置 | 内容 |
|---|---|
| `server/core` | 服务端（子模块 [soloroth-server](https://github.com/vvenv/soloroth-server)）：原版 vmangos 加上 macOS 修复、副本机器人 `src/game/PlayerBots/DungeonBotMgr.*` 和成就 `src/game/AchievementMgr.*` |
| `client` | 客户端（子模块 [soloroth-client](https://github.com/vvenv/soloroth-client)）：[benilla](https://github.com/samwhosung/benilla)，用 Rust 从零写的 1.12 客户端，加上少量修复 |
| `Interface/AddOns` | 整套插件：GMBox、成就窗口 `Achievements`、单人设置插件 `!Solo`（名字以 `!` 开头，保证比其他插件先加载），和第三方的 pfUI、pfQuest、Atlas 三件套、Bagshui 等（原样收录，各自的作者和许可见 THIRD-PARTY-NOTICES.md） |
| `config/` | 服务端配置改动（`*.overrides.conf`）和 MariaDB 配置 |
| `tools/macos/` | 构建、安装、启动脚本 |
| `tools/achievements/` | 成就定义的生成脚本 |
| `tools/glue-skin/` | 登录和角色界面的 pfUI 样式，和把它打包成 `Data/patch-S.MPQ` 的脚本 |
| `tools/lib/` | `do.sh` 用的交互菜单和日志库 |
| `do.sh` | 根目录交互入口（第一次安装、开玩、编译、外观等） |
| `benilla-config/` | 客户端设置、插件（`AddOns/`）和插件存档（`saved/`），不进 git |
| `Data/` | 指向客户端 MPQ 和登录条款 HTML 的链接，不进 git |
| `server/run`、`server/data`、`server/logs` | 服务端运行目录、地图数据、日志，不进 git |

服务端完全是 vmangos 原版加我们自己的少量提交，跟进上游很直接：

```sh
cd server/core
git remote add upstream https://github.com/vmangos/core.git   # 只需第一次
git fetch upstream
git merge upstream/development
cd ../.. && tools/macos/build-classic.sh server && tools/macos/setup-classic.sh
```

新增数据库迁移文件（`server/core/sql/migrations`）之后要重新编译服务端，因为 `mangosd` 会把迁移列表编进程序。数据库缺迁移时它会拒绝启动。

---

## 常见问题

**客户端进游戏后十几秒自己退出了。**
插件超过了 1.12 默认的 48 MB 脚本内存上限。`setup-classic.sh` 会在 `benilla-config/config.toml` 里设置 `scriptMemory = "0"`（不限），重新运行一遍即可。

**服务器重启后，原来在副本里下线的角色出现在副本门口外面。**
这是原版机制：重启后副本实例没了，角色会被放到门口。走进传送门就会照常补 bot。

**GM 命令没反应，提示“您无法使用此命令”。**
GM 权限读的是 `classic_realmd.account_access` 表，不是 `account.gmlevel`。用 `tools/macos/create-account.sh 账号 密码 gm` 建账号，或者在服务器控制台执行 `account set gmlevel 账号 6`。

**bot 太弱或者太强。**
副本难度还没调，这是下一步要做的。

---

## 致谢

- [Hordes of Azeroth](https://github.com/jonhaldors/hordes-of-azeroth)：Soloroth 最初从这里起步。
- [VMaNGOS](https://github.com/vmangos/core)：服务端。
- [benilla](https://github.com/samwhosung/benilla)：客户端。
- pfUI、pfQuest、Atlas 等插件的作者们，见 [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)。

## 关于

非官方的爱好者项目，与 Blizzard Entertainment 无关。仓库和构建产物里不含任何游戏本身的文件：模型、贴图、声音、地图和游戏数据都来自你自己的 1.12.1 客户端。

World of Warcraft 和 Blizzard Entertainment 是 Blizzard Entertainment, Inc. 的商标或注册商标。

本仓库代码使用 [GNU General Public License v3.0](LICENSE)。客户端基于 [benilla](https://github.com/samwhosung/benilla)（MIT 或 Apache-2.0）。服务端基于 [VMaNGOS](https://github.com/vmangos/core)（GPL-2.0）。`Interface/AddOns` 里的第三方插件原样收录，不属于本仓库的 GPL，各自的作者和许可见 THIRD-PARTY-NOTICES.md。其他依赖见 [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)。
