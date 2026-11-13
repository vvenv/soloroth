#!/bin/bash
# Soloroth 开发 / 日常入口。无参数进入交互菜单；具体做法仍在 tools/macos/ 里，这里只做转发。
#
# 用法:
#   ./do.sh                         # 交互主菜单（会提示该不该编译）
#   ./do.sh status                  # 只看改动提示（该编译 / 装插件 / 应用配置？）
#   ./do.sh play                    # 开服务器（如未开）+ 客户端
#   ./do.sh server                  # 开服务器
#   ./do.sh stop                    # 关服务器（交互可选连 MariaDB 一起关）
#   ./do.sh stop --all              # 关服务器并关 MariaDB
#   ./do.sh first                   # 第一次安装向导：编译 → 配置 → 开服 → 建账号 → 生成 App
#   ./do.sh build [all|server|client]
#   ./do.sh setup [--reset-db]
#   ./do.sh account [账号 密码 [gm]]
#   ./do.sh app [目标目录]          # 生成 Soloroth.app（默认 /Applications）
#   ./do.sh addons                  # 安装 / 更新插件
#   ./do.sh visual                  # 外观：下载补丁或切换方案
#   ./do.sh visual fetch|--hd|list|vanilla|hd|reforged-creatures|...
#   ./do.sh config                  # 应用 config/mangosd.overrides.conf
#
# 菜单里 Esc / ← 返回上一级；主菜单 Esc 退出。
# cargo / cmake 本身是增量的：提示说该编时再跑 build 即可，不必每次全编。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

MACOS="$ROOT/tools/macos"
CLIENT_BIN="$ROOT/release/build/macos/client-target/release/benilla"
SERVER_BIN="$ROOT/release/build/macos/server-classic/bin/mangosd"
LOG_TAG=soloroth
# shellcheck source=tools/lib/log.sh
source "$ROOT/tools/lib/log.sh"
# shellcheck source=tools/lib/prompt-menu.sh
source "$ROOT/tools/lib/prompt-menu.sh"

# 主菜单默认项 / build 子菜单默认边（由 refresh_hints 填写）
HINT_MENU_DEFAULT=1
HINT_BUILD_PART=all
HINT_LINES=()

usage() {
  sed -n '2,/^set -euo pipefail$/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

prompt_confirm() {
  local message="$1"
  local default="${2:-y}"

  if [ ! -t 0 ]; then
    [ "$default" = "y" ]
    return
  fi

  local hint="Y/n"
  if [ "$default" = "n" ]; then
    hint="y/N"
  fi

  local answer=""
  read -r -p "$message [$hint]: " answer </dev/tty || true
  if [ -z "$answer" ]; then
    answer="$default"
  fi
  case "$answer" in
    [Yy]|[Yy][Ee][Ss]) return 0 ;;
    *) return 1 ;;
  esac
}

pause_menu() {
  [ -t 0 ] || return 0
  echo ""
  read -r -p "按回车返回菜单…" _ </dev/tty || true
}

run_macos() {
  local script="$1"
  shift
  bash "$MACOS/$script" "$@"
}

# prompt_menu 取消（Esc/←）时输出 __back__
is_back() { [ "${1:-}" = "__back__" ]; }

# ---------- 改动提示（什么时候该编译） ----------

# 源树里是否有比 ref 更新的普通文件。$2… 是相对 $1 的 prune 名（目录名）。
_tree_newer_than() {
  local root="$1" ref="$2"
  shift 2
  if [ ! -e "$ref" ]; then
    return 0
  fi
  local args=() d
  for d in "$@"; do
    args+=( -name "$d" -prune -o )
  done
  # 有任一命中就 stale
  [ -n "$(find "$root" "${args[@]}" -type f ! -name '.DS_Store' -newer "$ref" -print -quit 2>/dev/null)" ]
}

_addons_stale() {
  local src="$ROOT/Interface/AddOns"
  local dst="${BENILLA_HOME:-$ROOT/benilla-config}/AddOns"
  [ -d "$src" ] || return 1
  if [ ! -d "$dst" ]; then
    return 0
  fi
  local f rel
  while IFS= read -r -d '' f; do
    rel="${f#"$src"/}"
    if [ ! -e "$dst/$rel" ] || [ "$f" -nt "$dst/$rel" ]; then
      return 0
    fi
  done < <(find "$src" -type f ! -name '.DS_Store' -print0 2>/dev/null)
  return 1
}

_config_stale() {
  local o conf
  for o in mangosd realmd; do
    conf="$ROOT/server/run/$o.conf"
    if [ -f "$ROOT/config/$o.overrides.conf" ]; then
      if [ ! -f "$conf" ] || [ "$ROOT/config/$o.overrides.conf" -nt "$conf" ]; then
        return 0
      fi
    fi
  done
  return 1
}

_glue_stale() {
  local patch="$ROOT/Data/patch-S.MPQ"
  [ -f "$patch" ] || return 1
  _tree_newer_than "$ROOT/tools/glue-skin" "$patch" __pycache__
}

# 刷新 HINT_*。stdout 给人看的提示行；菜单默认项写进全局。
refresh_hints() {
  HINT_LINES=()
  HINT_MENU_DEFAULT=1
  HINT_BUILD_PART=all
  local need_client=0 need_server=0 need_addons=0 need_config=0 need_glue=0
  local need_first=0

  if [ ! -x "$CLIENT_BIN" ] && [ ! -x "$SERVER_BIN" ]; then
    need_first=1
  else
    if [ ! -x "$CLIENT_BIN" ] || _tree_newer_than "$ROOT/client" "$CLIENT_BIN" .git target; then
      need_client=1
    fi
    if [ ! -x "$SERVER_BIN" ] || _tree_newer_than "$ROOT/server/core" "$SERVER_BIN" .git build 'cmake-build-*'; then
      need_server=1
    fi
  fi
  _addons_stale && need_addons=1
  _config_stale && need_config=1
  _glue_stale && need_glue=1

  if [ "$need_first" -eq 1 ]; then
    HINT_LINES+=("还没有编过 → 选「第一次安装」，或 ./do.sh first")
    HINT_MENU_DEFAULT=4  # first
    return
  fi

  if [ "$need_client" -eq 1 ] && [ "$need_server" -eq 1 ]; then
    HINT_LINES+=("服务端和客户端源码都比二进制新 → ./do.sh build（cargo/cmake 增量）")
    HINT_BUILD_PART=all
    HINT_MENU_DEFAULT=5  # build
  elif [ "$need_client" -eq 1 ]; then
    HINT_LINES+=("客户端（client/）有改动 → ./do.sh build client（cargo 增量）")
    HINT_BUILD_PART=client
    HINT_MENU_DEFAULT=5
  elif [ "$need_server" -eq 1 ]; then
    HINT_LINES+=("服务端（server/core）有改动 → ./do.sh build server，再重启服务器")
    HINT_BUILD_PART=server
    HINT_MENU_DEFAULT=5
  fi

  if [ "$need_addons" -eq 1 ]; then
    HINT_LINES+=("插件有改动 → ./do.sh addons，然后完全重启客户端（/reload 不够）")
    [ "$HINT_MENU_DEFAULT" -eq 1 ] && HINT_MENU_DEFAULT=9  # addons
  fi
  if [ "$need_config" -eq 1 ]; then
    HINT_LINES+=("服务端 overrides 有改动 → ./do.sh config，再重启服务器")
    [ "$HINT_MENU_DEFAULT" -eq 1 ] && HINT_MENU_DEFAULT=11  # config
  fi
  if [ "$need_glue" -eq 1 ]; then
    HINT_LINES+=("登录界面 glue-skin 有改动 → 再开一次客户端即可（play 会重打 patch-S）")
  fi

  if [ "${#HINT_LINES[@]}" -eq 0 ]; then
    HINT_LINES+=("源码和当前二进制一致，开玩就行（改插件 / 配置 / 客户端 / 服务端才会提示）")
  fi
}

print_hints() {
  refresh_hints
  local line
  # 全部走 stderr，避免和后面的说明（或菜单）在重定向时乱序
  echo "" >&2
  for line in "${HINT_LINES[@]}"; do
    case "$line" in
      源码和当前二进制一致*) log_success "$line" >&2 ;;
      *) log_warn "$line" ;;
    esac
  done
}

cmd_status() {
  print_hints
  echo "" >&2
  echo "对照：" >&2
  echo "  改 Interface/AddOns 或 !Solo     → addons + 重启客户端（不用编译）" >&2
  echo "  改 client/（Rust）               → build client（增量）" >&2
  echo "  改 server/core（C++）            → build server（增量）+ 重启服务器" >&2
  echo "  改 config/*.overrides.conf       → config + 重启服务器" >&2
  echo "  改 tools/glue-skin               → 直接再开客户端" >&2
}

# ---------- 子命令 ----------

cmd_play() {
  log_info "开始玩（服务器没开会先开）"
  run_macos play.sh "$@"
}

cmd_server() {
  log_info "开服务器"
  run_macos play.sh --server-only
  log_success "服务器已开（日志 server/logs/mangosd.out）"
}

cmd_stop() {
  local all=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --all) all=1 ;;
      -h|--help) usage 0 ;;
      *) log_die "stop 未知参数: $1" ;;
    esac
    shift
  done

  if [ -t 0 ] && [ "$all" -eq 0 ]; then
    local a
    a="$(prompt_menu "关服务器" --default=1 \
      "server:只关 mangosd / realmd" \
      "all:连 MariaDB 一起关")"
    if is_back "$a"; then
      return 0
    fi
    [ "$a" = "all" ] && all=1
  fi

  if [ "$all" -eq 1 ]; then
    run_macos stop-server.sh --all
  else
    run_macos stop-server.sh
  fi
  log_success "已停止"
}

cmd_build() {
  local part=""
  while [ $# -gt 0 ]; do
    case "$1" in
      all|server|client) part="$1" ;;
      -h|--help) usage 0 ;;
      *) log_die "build 未知参数: $1（用 all / server / client）" ;;
    esac
    shift
  done

  if [ -z "$part" ] && [ -t 0 ]; then
    refresh_hints
    local def=1
    case "$HINT_BUILD_PART" in
      all) def=1 ;;
      server) def=2 ;;
      client) def=3 ;;
    esac
    part="$(prompt_menu "编译哪边（已编过的会增量）" --default="$def" \
      "all:服务端 + 客户端" \
      "server:只服务端" \
      "client:只客户端")"
    if is_back "$part"; then
      return 0
    fi
  fi
  part="${part:-$HINT_BUILD_PART}"
  part="${part:-all}"

  log_info "编译 ${part}（cargo/cmake 增量；第一次要一阵子）"
  run_macos build-classic.sh "$part"
  log_success "编译完成（${part}）"
}

cmd_setup() {
  local reset=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --reset-db) reset=1 ;;
      -h|--help) usage 0 ;;
      *) log_die "setup 未知参数: $1" ;;
    esac
    shift
  done

  if [ -t 0 ] && [ "$reset" -eq 0 ]; then
    local r
    r="$(prompt_menu "数据库" --default=1 \
      "keep:保留已有库（安全重跑）" \
      "reset:清空重建（角色也会没）")"
    if is_back "$r"; then
      return 0
    fi
    [ "$r" = "reset" ] && reset=1
  fi

  if [ "$reset" -eq 1 ]; then
    if [ -t 0 ] && ! prompt_confirm "确认清空 classic_* 库（含角色）？" n; then
      log_info "已取消"
      return 0
    fi
    log_info "配置（--reset-db）"
    run_macos setup-classic.sh --reset-db
  else
    log_info "配置（保留已有）"
    run_macos setup-classic.sh
  fi
  log_success "配置完成"
}

cmd_account() {
  local name="${1:-}" pass="${2:-}" gm="${3:-}"

  if [ -z "$name" ] || [ -z "$pass" ]; then
    if [ ! -t 0 ]; then
      log_die "用法: ./do.sh account <账号> <密码> [gm]"
    fi
    read -r -p "账号: " name </dev/tty || true
    read -r -s -p "密码: " pass </dev/tty || true
    echo "" >&2
    [ -n "$name" ] && [ -n "$pass" ] || log_die "账号和密码不能为空"
    if [ -z "$gm" ]; then
      local g
      g="$(prompt_menu "GM 权限" --default=1 \
        "gm:给 GM（传送 / 物品 / GMBox 工具）" \
        "no:普通账号")"
      if is_back "$g"; then
        return 0
      fi
      [ "$g" = "gm" ] && gm=gm
    fi
  fi

  if ! pgrep -x mangosd >/dev/null; then
    log_warn "服务器没开，先开起来"
    run_macos play.sh --server-only
  fi

  if [ "$gm" = "gm" ]; then
    run_macos create-account.sh "$name" "$pass" gm
  else
    run_macos create-account.sh "$name" "$pass"
  fi
  log_success "账号已处理"
}

cmd_app() {
  local dest="${1:-}"
  if [ -z "$dest" ] && [ -t 0 ]; then
    local where
    where="$(prompt_menu "Soloroth.app 放哪" --default=1 \
      "default:默认（/Applications 或 ~/Applications）" \
      "desktop:桌面" \
      "ask:指定目录")"
    if is_back "$where"; then
      return 0
    fi
    case "$where" in
      desktop) dest="$HOME/Desktop" ;;
      ask)
        read -r -p "目录: " dest </dev/tty || true
        [ -n "$dest" ] || log_die "目录不能为空"
        ;;
    esac
  fi

  if [ -n "$dest" ]; then
    log_info "生成 App → $dest"
    run_macos make-app.sh "$dest"
  else
    log_info "生成 App"
    run_macos make-app.sh
  fi
  log_success "App 已生成"
}

cmd_addons() {
  log_info "安装插件到 benilla-config"
  run_macos install-addons.sh
  log_success "插件已装；新插件文件需要完全重启客户端（/reload 不够）"
}

cmd_visual() {
  local action="${1:-}"
  if [ -n "$action" ]; then
    shift
  fi

  if [ -z "$action" ] && [ -t 0 ]; then
    action="$(prompt_menu "外观" --default=1 \
      "fetch:下载高清怪物（Patch-C，约 2 GB）" \
      "hd:再加环境 / 物品整套（--hd）" \
      "list:看已装方案" \
      "vanilla:切回原版模型" \
      "reforged:高清怪物" \
      "full:高清合集")"
    if is_back "$action"; then
      return 0
    fi
  fi
  action="${action:-list}"

  case "$action" in
    fetch)
      log_info "下载 Reforged 生物包"
      run_macos fetch-visual-patches.sh
      ;;
    hd|--hd)
      log_info "下载 Reforged 全套（含环境 / 物品）"
      run_macos fetch-visual-patches.sh --hd
      ;;
    list|--list)
      run_macos apply-visual.sh --list
      ;;
    vanilla)
      run_macos apply-visual.sh vanilla
      log_success "已切原版；完全退出客户端再开才生效"
      ;;
    reforged|reforged-creatures)
      run_macos apply-visual.sh reforged-creatures
      log_success "已切高清怪物；完全退出客户端再开才生效"
      ;;
    full|hd-pack)
      run_macos apply-visual.sh hd
      log_success "已切高清合集；完全退出客户端再开才生效"
      ;;
    *)
      run_macos apply-visual.sh "$action" "$@"
      ;;
  esac
}

cmd_config() {
  log_info "应用 mangosd.overrides.conf"
  run_macos apply-config.sh
  log_success "配置已写；改过的话请重启服务器"
}

cmd_first() {
  echo ""
  log_info "第一次安装会依次：编译 → 配置 → 开服务器 → 建账号 → 生成 App"
  echo "  需要已备好 ../wow-data（客户端 Data + 提取的 maps/vmaps/mmaps/dbc）"
  echo "  以及 brew 依赖、Rust（见 README「需要准备」）"
  echo ""
  if [ -t 0 ] && ! prompt_confirm "开始？" y; then
    log_info "已取消"
    return 0
  fi

  cmd_build all
  cmd_setup
  cmd_server
  cmd_account
  cmd_app
  echo ""
  log_success "装好了。以后双击 Soloroth.app，或 ./do.sh play"
}

# ---------- 菜单 / 入口 ----------

run_main_menu() {
  while true; do
    print_hints
    local choice
    choice="$(prompt_menu "Soloroth" --default="$HINT_MENU_DEFAULT" \
      "play:开始玩" \
      "server:开服务器" \
      "stop:关服务器" \
      "first:第一次安装" \
      "build:编译（增量）" \
      "setup:配置（库 / 数据 / 插件）" \
      "account:建账号" \
      "app:生成 Soloroth.app" \
      "addons:更新插件" \
      "visual:外观补丁" \
      "config:应用服务端配置" \
      "status:为什么要编译？（对照表）" \
      "quit:退出")"
    case "$choice" in
      __back__|quit)
        exit 0
        ;;
      play|server|stop|first|build|setup|account|app|addons|visual|config|status)
        "cmd_$choice" || log_error "执行失败（${choice}）"
        # status 只是看一眼，不必再按回车
        if [ "$choice" != "status" ]; then
          pause_menu
        fi
        ;;
      *)
        log_die "未知命令: $choice"
        ;;
    esac
  done
}

CMD=""
if [ $# -gt 0 ]; then
  case "$1" in
    -h|--help|help) usage 0 ;;
    play|server|stop|first|build|setup|account|app|addons|visual|config|status|hint|doctor)
      CMD="$1"
      [ "$CMD" = "hint" ] || [ "$CMD" = "doctor" ] && CMD=status
      shift
      ;;
    -*)
      log_die "请先给出子命令（play / status / first / build …），或直接运行 ./do.sh"
      ;;
    *)
      echo "未知命令: $1" >&2
      usage 2
      ;;
  esac
fi

if [ -z "$CMD" ]; then
  if [ -t 0 ]; then
    run_main_menu
  else
    usage 2
  fi
else
  "cmd_$CMD" "$@"
fi
