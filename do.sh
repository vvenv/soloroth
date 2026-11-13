#!/bin/bash
# Soloroth 开发 / 日常入口。无参数进入交互菜单；具体做法仍在 tools/macos/ 里，这里只做转发。
#
# 用法:
#   ./do.sh                         # 交互主菜单
#   ./do.sh play                    # 开服务器（如未开）+ 客户端
#   ./do.sh server                  # 只开服务器
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
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

MACOS="$ROOT/tools/macos"
LOG_TAG=soloroth
# shellcheck source=tools/lib/log.sh
source "$ROOT/tools/lib/log.sh"
# shellcheck source=tools/lib/prompt-menu.sh
source "$ROOT/tools/lib/prompt-menu.sh"

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

# ---------- 子命令 ----------

cmd_play() {
  log_info "开始玩（服务器没开会先开）"
  run_macos play.sh "$@"
}

cmd_server() {
  log_info "只开服务器"
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
    part="$(prompt_menu "编译哪边" --default=1 \
      "all:服务端 + 客户端" \
      "server:只服务端" \
      "client:只客户端")"
  fi
  part="${part:-all}"

  log_info "编译 ${part}（第一次要一阵子）"
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
    case "$where" in
      desktop) dest="$HOME/Desktop" ;;
      ask)
        read -r -p "目录: " dest </dev/tty || true
        [ -n "$dest" ] || log_die "目录不能为空"
        ;;
    esac
  fi

  if [ -n "$dest" ]; then
    log_info "生成 Soloroth.app → $dest"
    run_macos make-app.sh "$dest"
  else
    log_info "生成 Soloroth.app"
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
      "full:高清合集" \
      "quit:取消")"
  fi
  action="${action:-list}"

  case "$action" in
    quit)
      log_info "已取消"
      return 0
      ;;
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
      # 透传给 apply-visual.sh（自定义 profile 名）
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
    local choice
    choice="$(prompt_menu "Soloroth" --default=1 \
      "play:开始玩" \
      "server:只开服务器" \
      "stop:关服务器" \
      "first:第一次安装" \
      "build:编译" \
      "setup:配置（库 / 数据 / 插件）" \
      "account:建账号" \
      "app:生成 Soloroth.app" \
      "addons:更新插件" \
      "visual:外观补丁" \
      "config:应用服务端配置" \
      "quit:退出")"
    case "$choice" in
      quit)
        exit 0
        ;;
      play|server|stop|first|build|setup|account|app|addons|visual|config)
        "cmd_$choice" || log_error "执行失败（${choice}）"
        pause_menu
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
    play|server|stop|first|build|setup|account|app|addons|visual|config)
      CMD="$1"
      shift
      ;;
    -*)
      log_die "请先给出子命令（play / first / build …），或直接运行 ./do.sh"
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
