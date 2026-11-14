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
  <a href="DEVELOP.md">开发者</a> ·
  <a href="https://github.com/vvenv/soloroth/issues">问题反馈</a>
</p>

---

## 特色

- **原版内容**：服务端是原版 [vmangos](https://github.com/vmangos/core)，世界数据、任务、刷怪都是 1.12 原样。
- **机器人组队**：进入五人副本 3 秒后，队伍自动补满 5 人。缺坦克就补坦克，缺治疗就补治疗，其余补不同职业的输出，来的总是同一批有名有姓的固定队友。bot 和你同级、装备匹配等级，掷骰全部放弃。活着离开副本时 bot 自动解散。
- **中文**：用简体中文 1.12 客户端的数据，界面、任务、NPC、物品都是中文。
- **单人化**：没有聊天频道，聊天框只当消息记录用（系统、拾取、经验、任务和 NPC 说话）。
- **插件**：pfUI、pfQuest、Atlas 三件套、Bagshui 等一套 1.12 插件，已经按单人旅行做任务配好，不弹首次设置向导。另有 GMBox 2.0（副本与机器人面板、传送、物品、GM 工具），界面和 pfUI 风格一致。
- **自动挂机**：`/dg` 打怪、`/dy` 钓鱼、`/cj` 采集、`/gj` 全能；由服务器带着角色做。
- **成就**：3.x 成就里 1.12 世界有的部分，加上轶事（世界首领、稀有、经典任务链，共 168 个）；默认按 `Y` 打开，达成时屏幕上方弹出提示。
- **低等级任务不白做**：等级高出任务太多、经验打折时，少拿的那部分经验按 60 级的规则折成金币。
- **经验 2 倍**，掉落和金钱保持 1 倍。想慢一点可以在 GMBox 工具页或用 `.xprate` 调到一半或停掉；少拿的任务经验同样折成金币。
- **默认移速 2 倍**（跑步）。GMBox 工具页的 1x / 2x / 4x / 7x 会改这个倍率。
- **专业不限**：9 个主专业都能学；急救、烹饪、钓鱼照旧不占名额。
- **新角色自带 1 金和 4 只 8 格包**（棕色小皮包）。
- **原版或高清怪物模型**：游戏里一键切换，见下文「客户端外观」。

目前只支持 **Apple Silicon 的 Mac**，从源码安装。

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

默认把游戏数据放在仓库**旁边**的 `../wow-data` 里：

```
../wow-data/
├── client-zhCN/Data/        中文客户端的 MPQ
├── vmangos-deploy/storage/mangosd/extracted-data/
│   ├── maps/  vmaps/  mmaps/  5875/
```

数据放在别处、换英文客户端、或自己从客户端提取地图，见 [DEVELOP.md](DEVELOP.md)。

### 安装

1. 拉代码：

   ```sh
   git clone --recurse-submodules https://github.com/vvenv/soloroth.git
   cd soloroth
   ```

2. 运行 `./do.sh`，在菜单里选「第一次安装」（或直接 `./do.sh first`）。它会编译、配置、开服、建账号，最后生成 `/Applications/Soloroth.app`。第一次编译要一阵子。
3. 双击 **Soloroth.app**（或在启动台、Spotlight 里搜 Soloroth），在启动器里点 **开始游戏**。

### 启动器

双击 Soloroth.app 先打开启动器窗口（就是本页顶部那张图）。窗口一打开就在后台启动服务器，底栏显示进度：

- **开始游戏**：服务器就绪后进入游戏，自动登录（有账号文件时不显示账号密码框）。服务器还没好时点它，会等就绪后自动进入。启动失败时按钮变成「重试」，底栏显示日志最后一行。
- **退出游戏**（游戏里的退出 / 关掉客户端窗口）会回到这个启动器，可以再点「开始游戏」；服务器继续跑着。
- **底栏链接**：GitHub 和问题反馈。**···** 菜单里可以打开日志文件夹、插件文件夹、编辑启动器设置、关服务器。
- **关掉启动器窗口**（或 ⌘Q）才真正离开 app；服务器如果已经开了，会继续运行。

不想每次都看到启动器：点 ··· →「编辑启动器设置」，把 `"skip"` 改成 `true`。改背景图、标语等见 [DEVELOP.md](DEVELOP.md)。

### 自动登录

第一次启动会弹窗问一次账号密码，核对无误后保存到 `benilla-config/login.env`（不进 git）。之后启动器和 `./do.sh play` 会用它自动登录：

- 有账号文件时，默认黑屏自动进角色选择（不显示登录页）。
- 想跳过角色选择：在文件里加上 `WOW_CHAR=角色名`。
- 想恢复原版登录页：加上 `WOW_SHOW_LOGIN_UI=1`。
- 改了密码或想换账号，删掉 `login.env`，下次启动会重新问。
- 在弹窗里点取消且没有该文件时，游戏里会显示原生账号密码框以便手输。

---

## 日常使用

根目录 `./do.sh` 是交互菜单（也可 `./do.sh play` 等子命令）。Esc / ← 返回上一级。

| 做什么 | 命令 |
|---|---|
| 开始玩 | 双击 Soloroth.app，或 `./do.sh play` |
| 开 / 关服务器 | `./do.sh server` / `./do.sh stop`，或启动器的 ··· 菜单 |
| 拉代码后更新 | `./do.sh build`，再 `./do.sh setup`；插件用 `./do.sh addons` 后**完全重启**客户端 |
| 改了服务端设置 | 改 `config/mangosd.overrides.conf`，然后 `./do.sh config`，重启服务器 |
| 原版 / HD 模型 | 选项 → 图形 →「怪物模型」，或 `./do.sh visual`；重启生效 |

从 Soloroth.app 进游戏再退出，会回到启动器；服务器继续运行。服务器日志在 `server/logs/mangosd.out`，启动器日志在 `server/logs/launcher.log`。

### 客户端外观（原版 / HD 怪物模型）

默认是 **原版** 1.12 模型。想用更精细的怪物，下载社区补丁后在游戏里切换：

```sh
tools/macos/fetch-visual-patches.sh        # 下载 Reforged 生物包（约 2 GB，可中断续传）
tools/macos/fetch-visual-patches.sh --hd   # 再加环境 / 物品等整套
```

- **游戏里切换**：选项 → 图形 →「怪物模型」，或 `/visual` / `/waiguan`。选好后**完全退出再开**才会换模型。
- 方案：「原版」「高清怪物」「高清合集」（需 `--hd`）、「Improved Models」（需自己放 MPQ，见 `../wow-data/visual-patches/improved-models/` 的说明）。
- 文件不完整时，怪物会隐形或变成方块；下载器会按校验值核对。

---

## 游戏里

### 机器人队友

- 进五人副本 3 秒后自动补满队伍。登录时就在副本里也算进入。
- 活着离开副本，副本里补的 bot 会解散；死了跑尸的路上不会解散。
- 团队副本不会自动补。在野外想带 bot 做精英任务，用「补满队伍」或 `.bots fill`。
- bot 是一批固定的队友：每个阵营每个职业的每个天赋各一人，名字、种族、性别、长相每次都一样。补位时按缺的职责从他们里挑（坦克优先战士，治疗优先牧师，输出尽量不同职业），聊天框会报出谁来了，例如「Tahomak（防护战士）、Elspeth（神圣牧师）」。
  - 联盟：战士 Aldric（武器）、Brannoc（狂怒）、Durgan（防护）；圣骑士 Elenya（神圣）、Hamrik（防护）、Cedric（惩戒）；猎人 Sylvaine（野兽控制）、Gundrik（射击）、Faelan（生存）；盗贼 Vesper（刺杀）、Fizzwick（战斗）、Nyssa（敏锐）；牧师 Brenna（戒律）、Lucienne（神圣）、Mordecai（暗影）；法师 Tinkara（奥术）、Corvin（火焰）、Isolde（冰霜）；术士 Malachar（痛苦）、Nixwick（恶魔学识）、Seraphine（毁灭）；德鲁伊 Aerwynn（平衡）、Thalor（野性）、Nerwen（恢复）。
  - 部落：战士 Grukash（武器）、Rakzan（狂怒）、Tahomak（防护）；萨满 Shakara（元素）、Durgash（增强）、Halona（恢复）；猎人 Grashnak（野兽控制）、Zanjira（射击）、Kotori（生存）；盗贼 Morwenna（刺杀）、Skarn（战斗）、Vexjin（敏锐）；牧师 Zalaya（戒律）、Elspeth（神圣）、Vorlath（暗影）；法师 Ashveld（奥术）、Yenjala（火焰）、Halvrik（冰霜）；术士 Morthis（痛苦）、Grishna（恶魔学识）、Cindrel（毁灭）；德鲁伊 Aponi（平衡）、Hoketah（野性）、Mahala（恢复）。

**GMBox 的「副本」页**：输入 `/gd`，或者右键小地图上的 GMBox 按钮打开。

- **我的职责**：自动、坦克、治疗、输出四选一，bot 会补齐你之外的职责。
- **进副本自动补机器人**开关，**补满队伍**，**解散机器人**。
- **副本列表**：按推荐等级排序。点一下直接传送进副本（需要 GM 账号）。
- **副本任务**：旁边的「任务」栏显示本阵营、本职业这个副本的任务进度；**右键**在聊天框列出没做完的任务。
- **指挥**：到我身边、集火目标、停手、坦克拉怪、原地待命、继续。

| 命令 | 作用 |
|---|---|
| `.bots` | 查看职责和自动补位设置 |
| `.bots role tank\|healer\|dps\|auto` | 设定自己的职责 |
| `.bots auto on\|off` | 进副本是否自动补 bot |
| `.bots fill` / `.bots dismiss` | 立刻补满 / 解散 bot |
| `.partybot cometome` | 所有 bot 到你身边 |
| `.partybot attackstart` / `attackstop` | 集火你的目标 / 停手 |
| `.partybot pull` | 坦克 bot 去拉你选中的怪 |
| `.partybot pause` / `unpause` | 原地待命 / 继续 |

### 单人设置

每次登录都会生效：

- **聊天**：只保留系统、拾取、金钱、经验、声望、技能、任务和 NPC 说话。
- **pfUI / pfQuest**：跳过首次向导；地图显示未探索区域和刷怪点；小地图放大并显示坐标；自动卖灰色物品；升级和史诗装备自动截图等。
- **击杀后自动拾取**（默认开）：掉落直接进背包。在「选项 → 控制」开关，或 `/autoloot on|off`。
- **拾取特效**（默认开）：物品飞进背包的动画。`/autoloot fx off` 关掉；`/autoloot test` 预览。
- **浮动战斗信息**：第一次登录时打开，以后可在「选项 → 战斗」里关掉。
- **中文界面**：第三方插件的界面文字也会换成中文。

进世界、切地图和坐船时，只显示黑底和底部进度条，没有原版地图插画。

### 自动挂机（打怪、采集、钓鱼）

| 命令 | 作用 |
|---|---|
| `/dg [码数]` | 只打怪（默认 40） |
| `/dy [码数]` | 只钓鱼（默认 25） |
| `/cj [码数]` | 只采集：采药、挖矿、剥皮，以及任务道具（默认 40） |
| `/gj [码数]` | 全能（默认 40） |
| `/gj stop` | 停止 |

英文别名：`/grind`、`/fish`、`/gather`。小地图上有挂机按钮：左键开菜单，右键停止。登录时也会自动建好对应宏，可拖到动作条。

- **打怪**：以当前位置为中心游荡、打怪、拾取；血蓝低时休息；不打精英、灰名、高 3 级以上的怪。
- **钓鱼**：要先学会钓鱼、背包里有鱼竿；有鱼群就去鱼群边上钓。
- **采集**：有对应专业技能才做；也会点任务道具和发光箱子。
- **停止**：面板「停止」、`/gj stop`、按键绑定，或站着不动时按移动键。死亡、背包满、离中心太远、下线时也会自动停。

### 成就

默认按 `Y` 打开（或 `/ach`）。获得成就时屏幕上方弹出提示。

- **综合 / 任务 / 探索 / 地下城与团队副本**：覆盖 1.12 旧世界能做到的部分。
- **旅程**：旧世界四章，见下面「推荐旅程」。
- **轶事**：霍格等稀有、世界首领、荆棘谷青山等经典任务链（共 168 个）。

### 推荐旅程

按故事线和等级排，每张图做完再往下走；副本在任务接齐之后再进（GMBox 副本页的「任务」栏会告诉你接齐没有）。

1. **家园**（1–40 级）：先做自己种族的新手区和周边，再去另一族盟友的地盘。
   - 联盟：艾尔文森林 → 西部荒野（死亡矿井）→ 赤脊山 → 暮色森林 → 丹莫罗 → 洛克莫丹 → 湿地 → 泰达希尔 → 黑海岸 → 灰谷。
   - 部落：杜隆塔尔（怒焰裂谷）→ 莫高雷 → 贫瘠之地（哀嚎洞穴）→ 石爪山脉 → 提瑞斯法林地 → 银松森林（影牙城堡）→ 灰谷（黑暗深渊）。
2. **七大王国的残影**（30–45 级）：希尔斯布莱德 → 奥特兰克 → 阿拉希 → 尘泥沼泽 → 血色修道院。
3. **神与半神**（35–55 级）：千针石林 → 荆棘谷 → 荒芜之地（奥达曼）→ 凄凉之地（玛拉顿）→ 塔纳利斯 → 悲伤沼泽 → 辛特兰 → 祖尔法拉克 → 菲拉斯 → 沉没的神庙。
4. **旧世界的余烬**（50–60 级）：灼热峡谷 → 燃烧平原（黑石系列）→ 西/东瘟疫之地 → 诅咒之地 → 艾萨拉 → 安戈洛 → 费伍德 → 月光林地 → 冬泉谷 → 厄运之槌 → 希利苏斯。

经验 2 倍时等级会比这条路线快。想把每章做完整，就在 GMBox 工具页把经验调到一半或停掉。团队副本机器人不补位，不在这条路线里。

### GMBox 的其他页

- **传送**：约 997 个传送点，中文、英文、拼音都能搜。也可用 `/gt 地名`。
- **物品**：按名字或 id 搜物品。也可用 `/gi 名字 数量`。
- **工具**：经验倍率、GM 模式、无敌、飞行、复活、修理、学技能、移速、加钱加等级等。

| 命令 | 作用 |
|---|---|
| `.xprate` | 查看当前经验倍率 |
| `.xprate off` / `.xprate on` | 停止 / 恢复全部经验 |
| `.xprate 0.5` | 只拿一半（乘在服务器的 2 倍上） |

经验减少时，任务少给的那部分经验折成金币。设置按角色保存。

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

<details>
<summary><b>更新代码 / 改配置 / 换外观数据要怎么做？</b></summary>

见上面「日常使用」表格。更细的脚本说明和目录结构见 [DEVELOP.md](DEVELOP.md)。
</details>

---

## 致谢

- [Hordes of Azeroth](https://github.com/jonhaldors/hordes-of-azeroth)：Soloroth 最初从这里起步。
- [VMaNGOS](https://github.com/vmangos/core)：服务端。
- [benilla](https://github.com/samwhosung/benilla)：客户端。
- pfUI、pfQuest、Atlas 等插件的作者们，见 [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)。

## 关于

非官方的爱好者项目，与 Blizzard Entertainment 无关。仓库和构建产物里不含任何游戏本身的文件：模型、贴图、声音、地图和游戏数据都来自你自己的 1.12.1 客户端。启动器的背景插画是为本项目生成的原创图，图标和 Logo 也是本项目画的。

World of Warcraft 和 Blizzard Entertainment 是 Blizzard Entertainment, Inc. 的商标或注册商标。

本仓库代码使用 [GNU General Public License v3.0](LICENSE)。客户端基于 [benilla](https://github.com/samwhosung/benilla)（MIT 或 Apache-2.0）。服务端基于 [VMaNGOS](https://github.com/vmangos/core)（GPL-2.0）。`Interface/AddOns` 里的第三方插件原样收录，不属于本仓库的 GPL，各自的作者和许可见 THIRD-PARTY-NOTICES.md。其他依赖见 [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)。

想改脚本、启动器、跟进上游，见 [DEVELOP.md](DEVELOP.md)。发现问题请开 [issue](https://github.com/vvenv/soloroth/issues)，附上 `server/logs/` 里的日志。
