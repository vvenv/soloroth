<p align="center">
  <img src=".github/images/launcher.jpg" alt="Soloroth 启动器" width="820">
</p>

<h1 align="center">Soloroth</h1>

<p align="center">
  一个在自己 Mac 上跑的魔兽世界 1.12.1 经典版：升级、探索、打怪。没有任务。<br>
  副本里自动补三人小队，五人与团本都按三人缩编，一个人也能打完整个经典旧世。
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
  <a href="GUIDE.md">完整说明</a> ·
  <a href="DEVELOP.md">开发者</a> ·
  <a href="https://github.com/vvenv/soloroth/issues">问题反馈</a>
</p>

<p align="center">
  <img src=".github/images/dungeon.jpg" alt="死亡矿井：机器人队友自动入队" width="400">
  <img src=".github/images/wailing-caverns.jpg" alt="哀嚎洞穴里打怪升级" width="400">
</p>
<p align="center">
  <img src=".github/images/world.jpg" alt="闪金镇：Soloroth 界面" width="400">
  <img src=".github/images/dungeon-hub.jpg" alt="副本中心 /gd：传送与重置" width="400">
</p>

---

## 特色

- **原版 1.12** + 简体中文，一个人也能打完旧世。
- **副本自动补三人小队**（五人与团本都按三人缩编）；进度记在角色上，不会自己重置。
- **没有任务**；靠打怪、探索、副本升级；装备不掉耐久；成就、挂机、传送 / 物品 / GM 工具都在。
- **Rust 原生界面**（pfUI Adapta，对照本页截图：中部单位框、青绿面板、右上 14 格方形小地图（朝向箭头 + 队友点；悬停滚轮缩放；悬停点显示名称）+ 坐标）+ 右下角双排图标命令条（各 7：背包/银行/角色/法术/天赋/地图/成就 + 传送/物品/宠物/GM/组队/挂机/副本；图标尺寸对齐右侧动作条）；底中主 + 主上 + 左右四条动作条（可从法术书 / 背包拖放）、细绿 XP 线，回车在主上条上方输入（中文输入法、⌘/Ctrl+C/V）；单位框带增益（剩余按 h/m/s）、动作条有冷却，功能面板可直接点选，黄标题栏可拖动。

目前只支持 **Apple Silicon 的 Mac**，从源码安装。细则见 [GUIDE.md](GUIDE.md)。

---

## 快速开始

### 需要准备

| 东西 | 说明 |
|---|---|
| Mac | Apple Silicon（M 系列）。目前在 macOS 26 上测试过 |
| 工具 | `xcode-select --install`；`brew install cmake mariadb openssl@3 pkg-config`；[rustup](https://rustup.rs) |
| 客户端 | 1.12.1 build 5875 的 `Data`（推荐 zhCN） |
| 地图数据 | vmangos 提取的 `maps` / `vmaps` / `mmaps` / `5875/dbc` |

默认数据放在仓库旁边的 `../wow-data/`（`client-zhCN/Data/` 与 `vmangos-deploy/storage/mangosd/extracted-data/`）。路径可变，见 [DEVELOP.md](DEVELOP.md)。

### 安装

```sh
git clone --recurse-submodules https://github.com/vvenv/soloroth.git
cd soloroth
./do.sh first          # 编译、配置、开服、建账号 → /Applications/Soloroth.app
```

双击 **Soloroth.app** → **开始游戏**。账号密码在启动器里输入（第一次，或 ··· →「设置…」），写进 `benilla-config/login.env` 后自动登录；游戏内不显示登录页。

启动器开着时服务器在后台跑；关掉窗口（或 ⌘Q）才离开 app。不想看启动器：··· →「设置…」勾选跳过；按住 Option 再打开可改回。

---

## 日常使用

| 做什么 | 命令 |
|---|---|
| 开始玩 | 双击 Soloroth.app，或 `./do.sh play` |
| 开 / 关服务器 | `./do.sh server` / `./do.sh stop` |
| 管理界面 | ··· →「打开管理界面」，或 `./do.sh admin`（`http://127.0.0.1:8765`） |
| 拉代码后更新 | `./do.sh build` → `./do.sh setup`；改 Rust UI 用 **`./do.sh build iter`**（快），装 App 再用 `build client`；改完完全重启客户端 |
| 改服务端设置 | 改 `config/mangosd.overrides.conf` → `./do.sh config`，重启服务器 |

日志在 `server/logs/`。脚本与目录细节见 [DEVELOP.md](DEVELOP.md)。

---

## 游戏里

| 功能 | 怎么开 |
|---|---|
| 组队（2 / 3 / 解散） | 命令条 · **O** · `/zd` · `.bots fill` |
| 副本中心 | 命令条 · **L** · `/gd` |
| 银行 | 命令条 · **U** · 背包窗「银行」 · `.bank` |
| 传送 / 物品 / 法术书 / 宠物 / GM | **J** · **I**（搜索） · **P** · **X** · **G** |
| 挂机 | **H** · `/dg` 打怪 · `/dy` 钓鱼 · `/cj` 采集 · `/gj` 全能 · `/bzd` 半自动 |
| 成就 | **Y** · `/ach` |

进副本（含团本）约 3 秒后自动补满三人小队；活着离开会解散 bot。经验、掉落、挂机规则等见 [GUIDE.md](GUIDE.md)。

---

## 常见问题

<details>
<summary><b>启动器一直「正在启动服务器…」或「服务器启动失败」。</b></summary>

第一次开服要加载地图，会慢一些。底栏有日志最后一行；完整输出在 `server/logs/launcher.log` 和 `mangosd.out`。修好后点「重试」。
</details>

<details>
<summary><b>更多功能说明 / 脚本细节？</b></summary>

玩家侧细则：[GUIDE.md](GUIDE.md)。开发与上游：[DEVELOP.md](DEVELOP.md)。
</details>

---

## 致谢

- [Hordes of Azeroth](https://github.com/jonhaldors/hordes-of-azeroth)：最初起步处。
- [VMaNGOS](https://github.com/vmangos/core)、[benilla](https://github.com/samwhosung/benilla)、pfUI / Atlas 等：见 [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)。

## 关于

非官方爱好者项目，与 Blizzard Entertainment 无关。仓库不含游戏资源文件；需自备 1.12.1 客户端。代码 [GPL-3.0](LICENSE)。

发现问题请开 [issue](https://github.com/vvenv/soloroth/issues)，附上 `server/logs/` 里的日志。
