<p align="center">
  <img src=".github/images/launcher.jpg" alt="Soloroth 启动器" width="820">
</p>

<h1 align="center">Soloroth</h1>

<p align="center">
  一个在自己 Mac 上跑的魔兽世界 1.12.1 经典版：做任务、升级、探索。<br>
  五人副本里机器人队友自动补满，一个人也能打完整个经典旧世。
</p>

<p align="center">
  <img alt="Apple Silicon" src="https://img.shields.io/badge/Mac-Apple%20Silicon-111?style=for-the-badge&logo=apple">
  <img alt="WoW 1.12.1" src="https://img.shields.io/badge/WoW-1.12.1%20(5875)-c9a227?style=for-the-badge">
  <a href="LICENSE"><img alt="GPL-3.0" src="https://img.shields.io/badge/license-GPL--3.0-2b5797?style=for-the-badge"></a>
</p>

> [!WARNING]
> Soloroth 不包含、不提供、也不链接魔兽世界客户端，你需要自己的 1.12.1（build 5875）客户端。
> 这是非官方的爱好者项目，与暴雪娱乐无关。代码只在 [这个仓库](https://github.com/vvenv/soloroth) 发布，别处提供的“整合包”或客户端下载都不是我们做的。

<p align="center">
  <a href="#快速开始">快速开始</a> ·
  <a href="#特色">特色</a> ·
  <a href="#日常使用">日常使用</a> ·
  <a href="#游戏里">游戏里</a> ·
  <a href="#常见问题">常见问题</a> ·
  <a href="BUILDING.md">开发者</a> ·
  <a href="https://github.com/vvenv/soloroth/issues">问题反馈</a>
</p>

---

## 特色

- **原版内容**：服务端是原版 [vmangos](https://github.com/vmangos/core)，世界数据、任务、刷怪都是 1.12 原样。
- **机器人组队**：进入五人副本 3 秒后，队伍自动补满 5 人。缺坦克就补坦克，缺治疗就补治疗，其余补不同职业的输出。bot 和你同级、装备匹配等级，掷骰全部放弃。活着离开副本时 bot 自动解散。
- **中文**：用简体中文 1.12 客户端的数据，界面、任务、NPC、物品都是中文。
- **单人化**：没有聊天频道，聊天框只当消息记录用（系统、拾取、经验、任务和 NPC 说话）。
- **插件**：pfUI、pfQuest、Atlas 三件套、Bagshui 等一套 1.12 插件，已经按单人旅行做任务配好，不弹首次设置向导。另有 GMBox 2.0（副本与机器人面板、传送、物品、GM 工具），界面和 pfUI 风格一致。
- **自动挂机**：`/dg` 打怪、`/dy` 钓鱼、`/cj` 采集、`/gj` 全能；由服务器带着角色做。
- **成就**：3.x 成就里 1.12 世界有的部分（等级、任务、探索、地下城与团队副本，146 个）；默认按 `Y` 打开，达成时屏幕上方弹出提示。
- **低等级任务不白做**：等级高出任务太多、经验打折时，少拿的那部分经验按 60 级的规则折成金币。
- **经验 2 倍**，掉落和金钱保持 1 倍。在 `config/mangosd.overrides.conf` 里可以改。
- **专业不限**：9 个主专业都能学（炼金、锻造、附魔、工程、草药、制皮、采矿、剥皮、裁缝），急救、烹饪、钓鱼照旧不占名额。
- **新角色自带 1 金和 4 只 8 格包**（棕色小皮包）。
- **原版或高清怪物模型**：游戏里一键切换，见下文「客户端外观」。

目前只支持 **Apple Silicon 的 Mac**，从源码构建。

---

## 快速开始

### 需要准备

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

### 安装

1. 拉代码：

   ```sh
   git clone --recurse-submodules https://github.com/vvenv/soloroth.git
   cd soloroth
   ```

2. 运行 `./do.sh`，在菜单里选「第一次安装」（或直接 `./do.sh first`）。它会编译、配置、开服、建账号，最后生成 `/Applications/Soloroth.app`。第一次编译要一阵子。
3. 双击 **Soloroth.app**（或在启动台、Spotlight 里搜 Soloroth），在启动器里点 **开始游戏**。

每一步具体做了什么，见 [BUILDING.md](BUILDING.md)。

### 启动器

双击 Soloroth.app 先打开启动器窗口（就是本页顶部那张图）。窗口一打开就在后台启动服务器，底栏显示进度：

- **开始游戏**：服务器就绪后进入游戏，自动登录到角色选择。服务器还没好时点它，会等就绪后自动进入。启动失败时按钮变成「重试」，底栏显示日志最后一行。
- **底栏链接**：GitHub 和问题反馈。**···** 菜单里可以打开日志文件夹、插件文件夹、编辑启动器设置、关服务器。
- **关掉窗口**（或 ⌘Q）就什么都不启动；服务器如果已经开了，会继续运行。

想换背景图、底栏链接，或者不想看到启动器：点 ··· →「编辑启动器设置」，会打开 `benilla-config/launcher.json`（第一次打开时新建，里面只有 `"skip": false`）。把它改成 `true` 就跳过窗口，双击 app 直接进游戏；只想临时跳过一次，用 `open --env SOLOROTH_SKIP_LAUNCHER=1 -a Soloroth`。这个文件里还可以写仓库 `tools/macos/launcher/launcher.json` 里的任何一项（背景图 `hero`、链接、推广位），写了的整项替换掉仓库的。改完下次启动生效。

### 自动登录

启动器和 `./do.sh play` 用 `benilla-config/login.env` 里的账号自动登录（这个文件不进 git，只有你自己能读）：

```
WOW_USER=PLAYER
WOW_PASS=密码
# WOW_CHAR=角色名  (进游戏时跳过角色选择)
# WOW_SHOW_LOGIN_UI=1  (显示游戏内账号密码框；默认隐藏)
```

- 没有这个文件时，第一次启动会弹窗问一次账号密码，跟服务器核对无误后保存；服务器上还没有账号的话，直接建一个 `PLAYER`（带 GM 权限）。在弹窗里点取消，没有 `login.env`，游戏里会显示原生账号密码框以便手输。
- 有 `login.env` 时，默认隐藏游戏内的账号、密码输入框和登录按钮（自动登录不需要它们）。想重新显示：在文件里加上 `WOW_SHOW_LOGIN_UI=1`，或启动时 `WOW_SHOW_LOGIN_UI=1 ./do.sh play`。
- 去掉 `WOW_CHAR` 那行前面的 `#` 并填上角色名，启动后直接进入这个角色的游戏世界。
- 改了密码或想换账号，删掉 `login.env`，下次启动会重新问。

---

## 日常使用

根目录 `./do.sh` 是交互菜单（也可 `./do.sh play` 等子命令）。菜单会根据源码和二进制的新旧提示该不该编译；不确定时看 `./do.sh status`。Esc / ← 返回上一级。cargo / cmake 本身是增量的，提示说要编时再跑即可。

| 做什么 | 命令 |
|---|---|
| 开始玩 | 双击 Soloroth.app，或 `./do.sh play`（终端里启动不弹启动器，服务器没开会先开） |
| 开服务器 | `./do.sh server` |
| 关服务器 | `./do.sh stop`（可选连 MariaDB 一起关），或启动器的 ··· 菜单 |
| 该不该编译？ | `./do.sh status`（或菜单里的提示） |
| 拉代码后重新编译 | `./do.sh build`，再 `./do.sh setup`（补数据库迁移） |
| 改了服务端设置 | 改 `config/mangosd.overrides.conf`，然后 `./do.sh config`，重启服务器 |
| 更新插件 | 拉代码后 `./do.sh addons`，然后**完全重启**客户端（`/reload` 不会加载新插件） |
| 原版 / HD 模型 | 选项 → 图形 →「怪物模型」，或 `./do.sh visual`；重启生效；见下文「客户端外观」 |

关掉客户端后服务器会继续运行。服务器的输出在 `server/logs/mangosd.out`，Soloroth.app 和启动器的输出在 `server/logs/launcher.log`。

### 客户端外观（原版 / HD 怪物模型）

默认是 **原版** 1.12 模型。想用更精细的怪物，下载社区补丁（Project Reforged）后在游戏里切换，不用改服务端。

```sh
tools/macos/fetch-visual-patches.sh        # 下载 Reforged 生物包 Patch-C（约 2 GB，可中断，重跑续传）
tools/macos/fetch-visual-patches.sh --hd   # 再加环境 / 物品等整套（B、D、E、G、H）
```

- **游戏里切换**：选项 → 图形 → 最下面的「怪物模型」，或 `/visual` / `/waiguan`。还没下载的方案是灰色，标「未安装」。选好后**完全退出再开**才会换模型；没重启前这一行旁边会提示「重启后生效」。
- 方案：「原版」「高清怪物（Reforged）」只换生物；「高清合集（Reforged 全套）」在下载了 `--hd` 后多出环境和物品；「Improved Models」要自己把 MPQ 放进 `../wow-data/visual-patches/improved-models/`（见那里的 README.txt）。
- 选择写在 `config.toml` 的 `solorothVisual`，每次启动前按它把补丁链接进 `Data/`。命令行也能切：`tools/macos/apply-visual.sh hd` / `vanilla` / `--list`。
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
- **中文界面**：简体中文客户端下，pfUI / pfQuest / Atlas 三件套、Bagshui、成就、GMBox、benilla 选项本身带中文；SuperMacro、ShaguNotify、ShaguKill 的界面和提示由 `!Solo/AddOns_zhCN.lua` 在加载后换成中文（第三方源码不改）。

登录、角色选择和角色创建界面不归插件管，它们也是 pfUI 样式（见 [BUILDING.md](BUILDING.md)）。用 `WOW_STOCK_UI=1 ./do.sh play` 启动就会恢复原版界面。

进世界、切地图和坐船时，客户端不显示原版的地图插画，只有黑底、底部一条细进度条和小提示，等地图加载好就消失。

想改某一项，就改 `Solo.lua` 里对应的表，再运行 `tools/macos/install-addons.sh`。

### 自动挂机（打怪、采集、钓鱼）

1.12 的插件不能替玩家走路和施法，所以这些由服务器直接驱动你的角色（战斗用的是队伍 bot 那套职业逻辑），插件只负责命令和面板。

| 命令 | 作用 |
|---|---|
| `/dg [码数]` | 只打怪（默认 40，最大 150） |
| `/dy [码数]` | 只钓鱼（默认 25，最大 60） |
| `/cj [码数]` | 只采集：采药、挖矿、剥皮（默认 40） |
| `/gj [码数]` | 全能：能打就打、能采就采、有鱼群就钓（默认 40） |
| `/gj` | 查看当前状态 |
| `/gj stop` | 停止（面板「停止」、按键绑定也行） |

英文别名：`/grind`、`/fish`、`/gather`；`/cy` 仍可用（旧的采集缩写）。不用 `/farm`（pfUI 的农场小地图用了）。

**不用敲命令也可以**：小地图上有挂机按钮（和 GMBox 一样，可拖动）。左键打开菜单（全能 / 打怪 / 钓鱼 / 采集 / 停止），右键直接停止。另外登录时会在角色宏里自动建好「自动挂机」「自动打怪」「自动钓鱼」「自动采集」「停止挂机」，可从宏界面拖到动作条，用法接近法术书里的技能。没有往法术书里塞假技能（1.12 不好做，也不干净）。

- **打怪**：以当前位置为中心游荡，找怪、上去打、拾取（物品和金钱直接进背包）。用的是你自己学会的技能（战士会自己换姿态）。血低于 60%、或蓝低于 40% 时停下休息到 95%：会治疗的职业先给自己加血，背包里有食物、饮料就吃喝。战斗中血低于 30% 会喝背包里的治疗药水。不打精英、灰名怪、比你高 3 级或更多的怪，也不抢别人的怪。被怪贴身时，血量还在 40% 以上会站着打，不一直后撤（免得把怪遛回出生点、脱战）。
- **钓鱼**：要先学会钓鱼、背包里有鱼竿。范围里有鱼群就走到鱼群边上钓，没有就找一片能下钩的水面。鱼竿自动换上，停止时换回原来的武器。被怪打了会换回武器打完再继续钓。
- **采集**：有对应专业技能才做那一项，挖矿要有矿镐，剥皮要有剥皮刀，技能不够的草/矿/尸体自动跳过。拾取完可剥的尸体会先剥再走。
- **全能**：挨打先打完 → 剥皮/采药/挖矿 → 有鱼群就钓 → 否则按打怪规则找怪。没学过的专业会跳过。
- **面板**：屏幕上方显示当前模式、范围和已运行时间，可以拖动，「停止」按钮随时停下。
- **停止**：点面板的「停止」，或 `/gj stop`（服务端是 `.solo stop`），或在「按键设置 → 单人挂机」里绑键。角色站着不动（休息、钓鱼）时按移动键也会停；服务器正在带着角色走时客户端不响应移动键，请用按钮或快捷键。死亡、背包满、离中心太远、下线时也会自动停。
- **视角**：服务器带路时视角会跟着身体朝向（和坐飞行点类似）；按住左键可临时转开。战斗里不再每个技能都强行拧向目标，右键转视角不会马上被拽回。

服务端命令是 `.solo grind|fish|gather|all [码数]`、`.solo stop`、`.solo farm`（查看状态）。

### 成就

默认按 `Y` 打开成就窗口（和 `C` 打开角色面板一样；可在「按键设置 → 成就」里改），也可以输入 `/ach`。获得成就时屏幕上方弹出提示，聊天框也有一行。

- **综合**：10 到 60 级。
- **任务**：完成任务总数；各区域的任务（要求该区域本阵营能接的任务的六成）；两块大陆的博学者和博学者。
- **探索**：探索每个区域（世界地图上被遮住的每一块都算一项），探索东部王国、卡利姆多，世界探索者。
- **地下城与团队副本**：每个经典副本的最终首领，和机器人一起打也算；经典地下城大师、经典团队副本攻略者。

等级、任务和探索按角色当前的进度判定，首领击杀在打倒首领时记录。分阵营的成就（各区域任务、博学者）只显示本阵营的那一份。

| 命令 | 作用 |
|---|---|
| `.achievement` | 已获得的成就数和点数 |
| `.achievement add\|remove <id>` | GM：给选中的角色发放 / 收回一个成就（还满足条件的会马上回来） |
| `.achievement reset` | GM：清空选中角色的成就，按角色现状重新数（首领击杀会清掉） |

### GMBox 的其他页

- **传送**：服务器上的 997 个传送点，中文、英文、拼音都能搜。也可以用 `/gt 地名`。
- **物品**：按名字或 id 搜物品放进背包，可以勾选“我能用”。也可以用 `/gi 名字 数量`。
- **工具**：GM 模式、无敌、飞行、复活、修理、学技能、加速、加钱加等级，以及任意命令输入框。

---

## 常见问题

<details>
<summary><b>启动器一直显示「正在启动服务器…」，或者「服务器启动失败」。</b></summary>

第一次开服要加载地图数据，会慢一些。失败时底栏会显示日志最后一行，完整输出在 `server/logs/launcher.log` 和 `server/logs/mangosd.out`（··· →「打开日志文件夹」）。修好后点「重试」。
</details>

<details>
<summary><b>不想每次都看到启动器。</b></summary>

··· →「编辑启动器设置」，写上 `"skip": true`。以后双击 app 直接开服进游戏。
</details>

---

## 开发者

脚本具体做了什么、启动器怎么改、仓库目录和跟进 vmangos 上游的方法，见 [BUILDING.md](BUILDING.md)。发现问题请开 [issue](https://github.com/vvenv/soloroth/issues)，附上 `server/logs/` 里的日志。

## 致谢

- [Hordes of Azeroth](https://github.com/jonhaldors/hordes-of-azeroth)：Soloroth 最初从这里起步。
- [VMaNGOS](https://github.com/vmangos/core)：服务端。
- [benilla](https://github.com/samwhosung/benilla)：客户端。
- pfUI、pfQuest、Atlas 等插件的作者们，见 [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)。

## 关于

非官方的爱好者项目，与 Blizzard Entertainment 无关。仓库和构建产物里不含任何游戏本身的文件：模型、贴图、声音、地图和游戏数据都来自你自己的 1.12.1 客户端。启动器的背景插画（`tools/macos/launcher/hero.jpg`）是为本项目生成的原创图，图标也是本项目画的。

World of Warcraft 和 Blizzard Entertainment 是 Blizzard Entertainment, Inc. 的商标或注册商标。

本仓库代码使用 [GNU General Public License v3.0](LICENSE)。客户端基于 [benilla](https://github.com/samwhosung/benilla)（MIT 或 Apache-2.0）。服务端基于 [VMaNGOS](https://github.com/vmangos/core)（GPL-2.0）。`Interface/AddOns` 里的第三方插件原样收录，不属于本仓库的 GPL，各自的作者和许可见 THIRD-PARTY-NOTICES.md。其他依赖见 [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)。
