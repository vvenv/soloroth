#!/usr/bin/env python3
"""Local Soloroth admin (127.0.0.1 only): accounts, characters, SQL browse/edit.

  python3 tools/macos/admin/server.py [--port 8765]
  tools/macos/start-admin.sh

Bind loopback only. No auth — single-player machine use; do not expose.
Language and theme are stored in cookies (sa_lang, sa_theme).
"""
from __future__ import annotations

import hashlib
import html
import os
import re
import socket
import subprocess
import sys
import urllib.parse
from dataclasses import dataclass
from datetime import datetime
from http.cookies import SimpleCookie
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from catalog import db_meta, table_meta
from i18n import (
    CLASS_IDS,
    DB_KEYS,
    GENDER_IDS,
    GM_IDS,
    LOCALE_IDS,
    RACE_IDS,
    map_opts,
    t,
)

ROOT = Path(__file__).resolve().parents[3]
MARIA = ROOT / "server" / "mariadb" / "bin" / "mariadb"
FIFO = ROOT / "server" / "logs" / "mangosd.stdin"
PORT = 8765
ALLOWED_DBS = tuple(DB_KEYS.keys())
IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
WRITE_HINT = re.compile(
    r"\b(INSERT|UPDATE|DELETE|DROP|ALTER|TRUNCATE|REPLACE|CREATE|GRANT|REVOKE|LOAD)\b",
    re.I,
)
SRP_N = int("894B645E89E1535BBDAD5B8B290650530801B18EBFBF5E8FAB3C82872A3E9BB7", 16)
SRP_G = 7
ACCOUNT_SKIP = {"sessionkey", "v", "s"}
ACCOUNT_FIELDS = [
    "username", "email", "locked", "lock_country", "expansion", "mutetime",
    "locale", "flags", "email_verif", "geolock_pin", "last_ip", "os", "platform",
    "current_realm", "security", "token_key",
]
CHAR_FIELDS = [
    "account", "name", "race", "class", "gender", "skin", "face", "hair_style",
    "hair_color", "facial_hair", "level", "xp", "money", "character_flags",
    "zone", "map", "instance", "position_x", "position_y", "position_z",
    "orientation", "online", "played_time_total", "played_time_level",
    "rest_bonus", "stable_slots", "bank_bag_slots", "extra_flags",
    "honor_rank_points", "honor_highest_rank", "honor_standing",
    "honor_last_week_hk", "honor_last_week_cp", "honor_stored_hk",
    "honor_stored_dk", "watched_faction", "drunk", "health",
    "power1", "power2", "power3", "power4", "power5", "ammo_id", "action_bars",
    "world_phase_mask", "known_taxi_mask", "current_taxi_path", "explored_zones",
    "equipment_cache",
]
COOKIE_MAX_AGE = 365 * 24 * 3600


@dataclass
class Ctx:
    lang: str = "zh"
    theme: str = "dark"

    def t(self, key: str, **kwargs: object) -> str:
        return t(self.lang, key, **kwargs)

    def db_label(self, db: str) -> str:
        title, _blurb = db_meta(db, self.lang)
        return title or self.t(DB_KEYS.get(db, db))

    def db_blurb(self, db: str) -> str:
        _title, blurb = db_meta(db, self.lang)
        return blurb

    def table_label(self, name: str) -> str:
        title, _blurb = table_meta(name, self.lang)
        return title

    def table_blurb(self, name: str) -> str:
        _title, blurb = table_meta(name, self.lang)
        return blurb

    def races(self) -> dict[str, str]:
        return map_opts(self.lang, "race", RACE_IDS)

    def classes(self) -> dict[str, str]:
        return map_opts(self.lang, "class", CLASS_IDS)

    def genders(self) -> dict[str, str]:
        return map_opts(self.lang, "gender", GENDER_IDS)

    def gm_levels(self) -> dict[str, str]:
        return map_opts(self.lang, "gm", GM_IDS)

    def locales(self) -> dict[str, str]:
        return map_opts(self.lang, "locale", LOCALE_IDS)


def die(msg: str, code: int = 1) -> None:
    print(f"admin: {msg}", file=sys.stderr)
    raise SystemExit(code)


def sql_escape(value: str) -> str:
    return value.replace("\\", "\\\\").replace("'", "''")


def srp_sv(username: str, password: str) -> tuple[str, str]:
    name = username.strip().upper()
    password = password.upper()
    salt = os.urandom(32)
    inner = hashlib.sha1(f"{name}:{password}".encode()).digest()
    x = int.from_bytes(hashlib.sha1(salt + inner).digest(), "little")
    v = pow(SRP_G, x, SRP_N)
    return f"{int.from_bytes(salt, 'little'):064X}", f"{v:064X}"


def process_running(name: str) -> bool:
    try:
        return subprocess.run(["pgrep", "-x", name], capture_output=True, check=False).returncode == 0
    except OSError:
        return False


def mangosd_up() -> bool:
    return process_running("mangosd") and FIFO.is_fifo()


def fifo_cmd(ctx: Ctx, line: str) -> str:
    if not mangosd_up():
        return ctx.t("msg_no_mangosd")
    with FIFO.open("w") as f:
        f.write(line if line.endswith("\n") else line + "\n")
    return ctx.t("msg_sent", cmd=line.strip())


def mariadb(*args: str, database: str | None = None, sql: str | None = None) -> tuple[int, str, str]:
    if not MARIA.is_file():
        return 1, "", f"missing {MARIA} (run ./do.sh setup)"
    cmd = [str(MARIA), "-h", "127.0.0.1", "-P", "3306", "-u", "root", "--skip-ssl", "-N", "-B"]
    if database:
        cmd.append(database)
    cmd.extend(args)
    try:
        proc = subprocess.run(cmd, input=sql, capture_output=True, text=True, timeout=60, check=False)
    except FileNotFoundError:
        return 1, "", f"cannot run {MARIA}"
    except subprocess.TimeoutExpired:
        return 1, "", "mariadb timed out"
    return proc.returncode, proc.stdout, proc.stderr


def sql_exec(database: str, sql: str) -> str | None:
    if database not in ALLOWED_DBS:
        return "database not allowed"
    code, out, err = mariadb(database=database, sql=sql if sql.endswith(";") else sql + ";")
    return None if code == 0 else (err or out or f"exit {code}").strip()


def sql_query(database: str, sql: str) -> tuple[list[str], list[list[str]], str | None]:
    if database not in ALLOWED_DBS:
        return [], [], "database not allowed"
    code, out, err = mariadb(
        "--column-names", database=database, sql=sql if sql.endswith(";") else sql + ";",
    )
    if code != 0:
        return [], [], (err or out or f"exit {code}").strip()
    lines = [ln for ln in out.splitlines() if ln != ""]
    if not lines:
        return [], [], None
    cols = lines[0].split("\t")
    return cols, [ln.split("\t") for ln in lines[1:]], None


def sql_scalar(database: str, sql: str) -> str:
    code, out, _ = mariadb(database=database, sql=sql)
    if code != 0:
        return ""
    return out.strip().splitlines()[0] if out.strip() else ""


def sql_row(database: str, sql: str) -> dict[str, str] | None:
    cols, rows, err = sql_query(database, sql)
    if err or not rows:
        return None
    row = rows[0]
    while len(row) < len(cols):
        row.append("")
    return {c: row[i] if i < len(row) else "" for i, c in enumerate(cols)}


def port_open(port: int) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(0.3)
        return s.connect_ex(("127.0.0.1", port)) == 0


def table_primary_key(database: str, table: str) -> str | None:
    _c, rows, err = sql_query(
        database,
        f"""SELECT COLUMN_NAME FROM information_schema.KEY_COLUMN_USAGE
            WHERE TABLE_SCHEMA='{sql_escape(database)}' AND TABLE_NAME='{sql_escape(table)}'
              AND CONSTRAINT_NAME='PRIMARY' ORDER BY ORDINAL_POSITION""",
    )
    if err or not rows or len(rows) != 1:
        return None
    return rows[0][0]


def clean(value: str) -> str:
    return "" if value in ("NULL", "\\N", None) else value  # type: ignore[comparison-overlap]


def money_parts(copper: str) -> tuple[int, int, int]:
    try:
        n = max(0, int(copper or "0"))
    except ValueError:
        return 0, 0, 0
    return n // 10000, (n % 10000) // 100, n % 100


def money_str(ctx: Ctx, copper: str) -> str:
    g, s, c = money_parts(copper)
    return ctx.t("money_fmt", g=g, s=s, c=c)


def lookup(opts: dict[str, str], key: str) -> str:
    return opts.get(str(key), key or "—")


def fmt_when(ctx: Ctx, raw: str) -> str:
    raw = clean(raw)
    if not raw or raw.startswith("0000"):
        return ctx.t("never_login")
    # MariaDB timestamps are local wall time on this Mac.
    try:
        dt_local = datetime.strptime(raw[:19], "%Y-%m-%d %H:%M:%S")
    except ValueError:
        return raw
    sec = max(0, int((datetime.now() - dt_local).total_seconds()))
    if sec < 60:
        return ctx.t("ago_just")
    if sec < 3600:
        return ctx.t("ago_min", n=sec // 60)
    if sec < 86400:
        return ctx.t("ago_hour", n=sec // 3600)
    if sec < 86400 * 14:
        return ctx.t("ago_day", n=sec // 86400)
    return raw[:16]


def badge(ctx: Ctx, ok: bool, yes_key: str = "online", no_key: str = "offline") -> str:
    cls = "badge ok" if ok else "badge"
    return f'<span class="{cls}">{html.escape(ctx.t(yes_key) if ok else ctx.t(no_key))}</span>'


def select_html(ctx: Ctx, name: str, options: dict[str, str], current: str) -> str:
    cur = str(current)
    opts = []
    for k, lab in options.items():
        sel = " selected" if k == cur else ""
        opts.append(f'<option value="{html.escape(k)}"{sel}>{html.escape(lab)}</option>')
    if cur and cur not in options:
        opts.append(
            f'<option value="{html.escape(cur)}" selected>'
            f'{html.escape(ctx.t("custom_opt", v=cur))}</option>'
        )
    return f'<select name="{html.escape(name)}">{"".join(opts)}</select>'


def input_text(ctx: Ctx, name: str, value: str, *, hint: str = "", typ: str = "text") -> str:
    col = name.removeprefix("f_")
    lab = ctx.t(f"lbl_{col}") if ctx.t(f"lbl_{col}") != f"lbl_{col}" else col
    hint_html = f'<span class="hint">{html.escape(hint)}</span>' if hint else ""
    return (
        f'<label>{html.escape(lab)}{hint_html}'
        f'<input type="{typ}" name="{html.escape(name)}" '
        f'value="{html.escape(clean(value), quote=True)}"></label>'
    )


def input_check(name: str, value: str, label: str) -> str:
    checked = " checked" if clean(value) not in ("", "0") else ""
    return (
        f'<label class="check"><input type="checkbox" name="{html.escape(name)}" value="1"{checked}>'
        f' {html.escape(label)}</label>'
    )


def input_area(ctx: Ctx, name: str, value: str, label: str | None = None) -> str:
    col = name.removeprefix("f_")
    lab = label or (ctx.t(f"lbl_{col}") if ctx.t(f"lbl_{col}") != f"lbl_{col}" else col)
    return (
        f'<label class="span2">{html.escape(lab)}'
        f'<textarea name="{html.escape(name)}" rows="3">{html.escape(clean(value))}</textarea></label>'
    )


def section(title: str, body: str, *, open_: bool = True) -> str:
    op = " open" if open_ else ""
    return (
        f'<details class="section"{op}><summary>{html.escape(title)}</summary>'
        f'<div class="grid">{body}</div></details>'
    )


def toolbar(*parts: str) -> str:
    return f'<div class="toolbar">{"".join(parts)}</div>'


def btn(href: str, text: str, *, danger: bool = False) -> str:
    cls = "btn danger" if danger else "btn"
    return f'<a class="{cls}" href="{html.escape(href)}">{html.escape(text)}</a>'


def table_wrap(inner: str, *, sticky_end: bool = True) -> str:
    cls = "table-scroll sticky-end" if sticky_end else "table-scroll"
    return f'<div class="{cls}">{inner}</div>'


def filter_box(ctx: Ctx) -> str:
    return (
        f'<input class="filter" type="search" data-filter-table '
        f'placeholder="{html.escape(ctx.t("filter_placeholder"))}" '
        f'aria-label="{html.escape(ctx.t("filter_placeholder"))}">'
    )


def prefs_links(ctx: Ctx, path: str) -> str:
    next_url = urllib.parse.quote(path or "/", safe="")
    zh_on = " on" if ctx.lang == "zh" else ""
    en_on = " on" if ctx.lang == "en" else ""
    dark_on = " on" if ctx.theme == "dark" else ""
    light_on = " on" if ctx.theme == "light" else ""
    return f"""
    <div class="prefs">
      <span class="muted">{html.escape(ctx.t("lang"))}</span>
      <a class="chip{zh_on}" href="/prefs?lang=zh&next={next_url}">中文</a>
      <a class="chip{en_on}" href="/prefs?lang=en&next={next_url}">English</a>
      <span class="muted sep">·</span>
      <span class="muted">{html.escape(ctx.t("theme"))}</span>
      <a class="chip{dark_on}" href="/prefs?theme=dark&next={next_url}">{html.escape(ctx.t("theme_dark"))}</a>
      <a class="chip{light_on}" href="/prefs?theme=light&next={next_url}">{html.escape(ctx.t("theme_light"))}</a>
    </div>
    """


def page(ctx: Ctx, title: str, body: str, flash: str = "", path: str = "/") -> bytes:
    flash_html = f'<p class="flash">{html.escape(flash)}</p>' if flash else ""
    doc = f"""<!DOCTYPE html>
<html lang="{html.escape(ctx.lang)}" data-theme="{html.escape(ctx.theme)}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)} · Soloroth</title>
<style>
  :root, [data-theme="dark"] {{
    --bg: #0a0c12; --panel: #141822; --text: #ebe4d4; --muted: #8a8a92;
    --gold: #edc266; --line: #2a3140; --ok: #6bbf6b; --bad: #c45c5c;
    --head: #1a1f2a; --hover: #1a2030; --input: #0d1018;
    --flash-bg: #243018; --flash-bd: #3d5a28; --flash-fg: #cfe3b8;
    --err-bg: #2a1515; --err-bd: #5a2828; --err-fg: #e3b8b8;
    --btn: linear-gradient(#3a3020, #2a2216); --btn-bd: #6a5428;
    --danger-bg: #3a1818; --danger-bd: #6a2828; --danger-fg: #e08888;
  }}
  [data-theme="light"] {{
    --bg: #f4f1ea; --panel: #fffcf7; --text: #1c1915; --muted: #6b6560;
    --gold: #8a5a12; --line: #ddd4c6; --ok: #2f7a3e; --bad: #b33a3a;
    --head: #efe8dc; --hover: #f7f1e7; --input: #ffffff;
    --flash-bg: #e8f0df; --flash-bd: #b7cda0; --flash-fg: #2f4a22;
    --err-bg: #f8e8e8; --err-bd: #e0b0b0; --err-fg: #7a2a2a;
    --btn: linear-gradient(#f0e0c0, #e4d0a8); --btn-bd: #c4a46a;
    --danger-bg: #f5e0e0; --danger-bd: #d09090; --danger-fg: #8a3030;
  }}
  * {{ box-sizing: border-box; }}
  body {{
    margin: 0; font: 14px/1.5 -apple-system, BlinkMacSystemFont, "PingFang SC", "Helvetica Neue", sans-serif;
    background: var(--bg); color: var(--text); min-height: 100vh;
  }}
  [data-theme="dark"] body {{
    background: radial-gradient(1200px 600px at 18% -8%, #1a2233, var(--bg));
  }}
  [data-theme="light"] body {{
    background: radial-gradient(1000px 500px at 80% -10%, #fff8ea, var(--bg));
  }}
  header {{
    padding: 16px 28px 10px; border-bottom: 1px solid var(--line);
    display: flex; align-items: center; justify-content: space-between; gap: 16px; flex-wrap: wrap;
  }}
  .brand {{ display: flex; align-items: baseline; gap: 12px; flex-wrap: wrap; }}
  header h1 {{ margin: 0; font-size: 20px; color: var(--gold); letter-spacing: 0.04em; }}
  header .sub {{ color: var(--muted); font-size: 12px; }}
  .prefs {{ display: flex; align-items: center; gap: 6px; flex-wrap: wrap; font-size: 12px; }}
  .prefs .sep {{ margin: 0 2px; }}
  nav {{ display: flex; gap: 6px; padding: 10px 28px; border-bottom: 1px solid var(--line); flex-wrap: wrap; }}
  nav a {{
    color: var(--text); text-decoration: none; padding: 7px 14px; border-radius: 8px;
    border: 1px solid transparent;
  }}
  nav a:hover {{ border-color: var(--line); background: var(--panel); }}
  main {{ padding: 22px 28px 56px; max-width: min(1280px, 100%); }}
  h2 {{ margin: 0 0 8px; font-size: 22px; }}
  h3 {{ margin: 0 0 10px; font-size: 15px; color: var(--gold); }}
  .flash {{ background: var(--flash-bg); border: 1px solid var(--flash-bd); color: var(--flash-fg);
    padding: 10px 14px; border-radius: 8px; margin: 0 0 16px; }}
  .err {{ background: var(--err-bg); border: 1px solid var(--err-bd); color: var(--err-fg);
    padding: 10px 14px; border-radius: 8px; margin: 0 0 16px; }}
  .muted {{ color: var(--muted); }}
  .meta {{ color: var(--muted); font-size: 13px; margin: 0 0 16px; }}
  .cards {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 12px; }}
  .card {{ background: var(--panel); border: 1px solid var(--line); border-radius: 12px; padding: 14px 16px; }}
  .card .k {{ color: var(--muted); font-size: 12px; }}
  .card .v {{ font-size: 18px; margin-top: 6px; font-weight: 600; }}
  .badge {{
    display: inline-block; padding: 2px 8px; border-radius: 999px; font-size: 12px;
    background: var(--input); color: var(--muted); border: 1px solid var(--line);
  }}
  .badge.ok {{ color: var(--ok); border-color: var(--ok); }}
  .table-scroll {{
    overflow: auto; max-width: 100%; max-height: min(70vh, 760px);
    border: 1px solid var(--line); border-radius: 12px; background: var(--panel);
    -webkit-overflow-scrolling: touch;
  }}
  .table-scroll table {{
    width: max-content; min-width: 100%; border-collapse: separate; border-spacing: 0;
    background: transparent; border: none;
  }}
  .table-scroll th, .table-scroll td {{
    padding: 10px 12px; text-align: left; vertical-align: middle;
    border-bottom: 1px solid var(--line); white-space: nowrap; background: var(--panel);
  }}
  .table-scroll th {{ color: var(--muted); font-weight: 600; font-size: 12px; background: var(--head); }}
  .table-scroll tbody tr:last-child td {{ border-bottom: none; }}
  .table-scroll tbody tr:hover td {{ background: var(--hover); }}
  .table-scroll thead th {{ position: sticky; top: 0; z-index: 2; box-shadow: 0 1px 0 var(--line); }}
  .table-scroll th:first-child, .table-scroll td:first-child {{
    position: sticky; left: 0; z-index: 1; box-shadow: 6px 0 8px -6px rgba(0,0,0,0.35);
  }}
  .table-scroll thead th:first-child {{ z-index: 3; background: var(--head); }}
  .table-scroll tbody td:first-child {{ background: var(--panel); }}
  .table-scroll tbody tr:hover td:first-child {{ background: var(--hover); }}
  .table-scroll.sticky-end th:last-child, .table-scroll.sticky-end td:last-child {{
    position: sticky; right: 0; z-index: 1; box-shadow: -6px 0 8px -6px rgba(0,0,0,0.35);
  }}
  .table-scroll.sticky-end thead th:last-child {{ z-index: 3; background: var(--head); }}
  .table-scroll.sticky-end tbody td:last-child {{ background: var(--panel); }}
  .table-scroll.sticky-end tbody tr:hover td:last-child {{ background: var(--hover); }}
  form.inline {{ display: inline; }}
  form.stack {{ display: grid; gap: 12px; max-width: 420px; margin: 12px 0; }}
  .grid {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 12px 14px; }}
  .span2 {{ grid-column: 1 / -1; }}
  .money {{ display: flex; gap: 8px; align-items: end; }}
  .money label {{ flex: 1; }}
  label {{ display: grid; gap: 5px; color: var(--muted); font-size: 12px; }}
  label.check {{ display: flex; align-items: center; gap: 8px; color: var(--text); font-size: 14px; padding-top: 18px; }}
  label .hint {{ color: var(--muted); font-weight: 400; margin-left: 6px; }}
  input, select, textarea, button, .btn, .filter {{
    font: inherit; color: var(--text); background: var(--input); border: 1px solid var(--line);
    border-radius: 8px; padding: 8px 10px;
  }}
  .filter {{ width: min(280px, 100%); margin: 0 0 12px; }}
  select {{ appearance: none; padding-right: 28px; }}
  textarea {{ width: 100%; min-height: 72px; font-family: ui-monospace, Menlo, monospace; font-size: 12px; }}
  button, .btn {{
    cursor: pointer; background: var(--btn); border-color: var(--btn-bd);
    color: var(--gold); font-weight: 600; text-decoration: none; display: inline-block;
  }}
  button:hover, .btn:hover {{ filter: brightness(1.05); }}
  button.danger, .btn.danger {{ background: var(--danger-bg); border-color: var(--danger-bd); color: var(--danger-fg); }}
  .toolbar {{ display: flex; gap: 8px; flex-wrap: wrap; align-items: center; margin: 0 0 16px; }}
  .actions {{ display: flex; gap: 8px; flex-wrap: wrap; margin-top: 16px; }}
  .section {{
    background: var(--panel); border: 1px solid var(--line); border-radius: 12px;
    padding: 4px 14px 14px; margin: 0 0 12px;
  }}
  .section summary {{
    cursor: pointer; list-style: none; padding: 12px 0 8px; font-weight: 600; color: var(--gold);
  }}
  .section summary::-webkit-details-marker {{ display: none; }}
  .section summary::before {{ content: "▸ "; color: var(--muted); }}
  .section[open] summary::before {{ content: "▾ "; }}
  .panel {{
    background: var(--panel); border: 1px solid var(--line); border-radius: 12px;
    padding: 16px 18px; margin: 0 0 16px;
  }}
  .chip-row {{ display: flex; gap: 8px; flex-wrap: wrap; margin: 10px 0 0; }}
  .chip {{
    display: inline-flex; flex-direction: column; align-items: flex-start; gap: 2px;
    padding: 8px 12px; border-radius: 12px; border: 1px solid var(--line);
    color: var(--text); text-decoration: none; background: var(--input); font-size: 13px;
    max-width: 280px;
  }}
  .chip .chip-title {{ font-weight: 600; color: var(--text); }}
  .chip .chip-tech {{ font-size: 11px; color: var(--muted); font-family: ui-monospace, Menlo, monospace; }}
  .chip .chip-blurb {{ font-size: 11px; color: var(--muted); white-space: normal; line-height: 1.35; }}
  .chip:hover, .chip.on {{ border-color: var(--btn-bd); }}
  .chip.on .chip-title {{ color: var(--gold); }}
  .chip-row.compact .chip {{ max-width: 220px; padding: 6px 10px; }}
  pre.sql {{
    background: var(--input); border: 1px solid var(--line); padding: 12px; border-radius: 8px;
    overflow: auto; font-size: 12px; white-space: pre-wrap;
  }}
  a {{ color: var(--gold); }}
  .danger-zone {{ margin-top: 28px; padding-top: 18px; border-top: 1px dashed var(--danger-bd); }}
  tr.is-hidden, a.chip.is-hidden {{ display: none; }}
</style>
</head>
<body>
<header>
  <div class="brand">
    <h1>Soloroth</h1>
    <span class="sub">{html.escape(ctx.t("app_sub"))}</span>
  </div>
  {prefs_links(ctx, path)}
</header>
<nav>
  <a href="/">{html.escape(ctx.t("nav_overview"))}</a>
  <a href="/accounts">{html.escape(ctx.t("nav_accounts"))}</a>
  <a href="/characters">{html.escape(ctx.t("nav_characters"))}</a>
  <a href="/db">{html.escape(ctx.t("nav_db"))}</a>
</nav>
<main>
{flash_html}
{body}
</main>
<script>
(function () {{
  document.querySelectorAll("[data-filter-table]").forEach(function (input) {{
    var root = input.parentElement;
    var table = root && root.querySelector(".table-scroll tbody");
    if (!table) return;
    input.addEventListener("input", function () {{
      var q = (input.value || "").trim().toLowerCase();
      table.querySelectorAll("tr").forEach(function (tr) {{
        var text = (tr.textContent || "").toLowerCase();
        tr.classList.toggle("is-hidden", q && text.indexOf(q) < 0);
      }});
    }});
  }});
  document.querySelectorAll("[data-filter-chips]").forEach(function (input) {{
    var row = input.nextElementSibling;
    if (!row || !row.classList.contains("chip-row")) return;
    input.addEventListener("input", function () {{
      var q = (input.value || "").trim().toLowerCase();
      row.querySelectorAll("a.chip").forEach(function (chip) {{
        var text = (chip.textContent || "").toLowerCase();
        chip.classList.toggle("is-hidden", q && text.indexOf(q) < 0);
      }});
    }});
  }});
}})();
</script>
</body>
</html>
"""
    return doc.encode("utf-8")


def status_body(ctx: Ctx) -> str:
    maria = port_open(3306)
    realm = port_open(3724)
    world = port_open(8085)
    mangosd = process_running("mangosd")
    realmd = process_running("realmd")
    realm_name = sql_scalar("classic_realmd", "SELECT name FROM realmlist WHERE id=1 LIMIT 1") or ctx.t("dash")
    accounts = sql_scalar("classic_realmd", "SELECT COUNT(*) FROM account") or "0"
    chars = sql_scalar("classic_characters", "SELECT COUNT(*) FROM characters") or "0"
    online_chars = sql_scalar("classic_characters", "SELECT COUNT(*) FROM characters WHERE online=1") or "0"

    def pill(ok: bool) -> str:
        return badge(ctx, ok, "ok", "down")

    return f"""
    <h2>{html.escape(ctx.t("title_overview"))}</h2>
    <p class="meta">{html.escape(ctx.t("overview_lead"))}</p>
    <div class="cards">
      <div class="card"><div class="k">{html.escape(ctx.t("overview_db"))}</div><div class="v">{pill(maria)}</div></div>
      <div class="card"><div class="k">{html.escape(ctx.t("overview_login"))}</div><div class="v">{pill(realmd and realm)}</div></div>
      <div class="card"><div class="k">{html.escape(ctx.t("overview_world"))}</div><div class="v">{pill(mangosd and world)}</div></div>
      <div class="card"><div class="k">{html.escape(ctx.t("overview_realm"))}</div><div class="v">{html.escape(realm_name)}</div></div>
      <div class="card"><div class="k">{html.escape(ctx.t("overview_accounts"))}</div><div class="v">{html.escape(accounts)}</div></div>
      <div class="card"><div class="k">{html.escape(ctx.t("overview_chars"))}</div><div class="v">{html.escape(chars)} / {html.escape(online_chars)}</div></div>
    </div>
    <div class="toolbar" style="margin-top:18px">
      {btn("/accounts", ctx.t("overview_manage_accounts"))}
      {btn("/characters", ctx.t("overview_manage_chars"))}
      {btn("/db", ctx.t("overview_browse_db"))}
    </div>
    <p class="muted" style="margin-top:18px">{html.escape(ctx.t("overview_tip"))}</p>
    """


def accounts_body(ctx: Ctx) -> str:
    _c, rows, err = sql_query(
        "classic_realmd",
        """SELECT a.id, a.username, COALESCE(aa.gmlevel, a.gmlevel) AS gm,
                  a.email, a.locked, a.last_login, a.online
           FROM account a
           LEFT JOIN account_access aa ON aa.id = a.id AND aa.RealmID IN (1, -1)
           ORDER BY a.id""",
    )
    if err:
        return f'<p class="err">{html.escape(err)}</p>'
    gm_opts = ctx.gm_levels()
    rows_html = []
    for r in rows:
        while len(r) < 7:
            r.append("")
        aid, user, gm, email, locked, last, online = r[:7]
        email_s = clean(email) or ctx.t("dash")
        rows_html.append(
            f"""<tr>
            <td><a href="/accounts/edit?id={urllib.parse.quote(aid)}">{html.escape(user)}</a>
              <div class="muted" style="font-size:12px">#{html.escape(aid)}</div></td>
            <td>{html.escape(lookup(gm_opts, gm))}</td>
            <td>{html.escape(email_s)}</td>
            <td>{html.escape(ctx.t("locked") if locked not in ("", "0") else ctx.t("dash"))}</td>
            <td>{html.escape(fmt_when(ctx, last))}</td>
            <td>{badge(ctx, online == "1")}</td>
            <td>{btn(f"/accounts/edit?id={urllib.parse.quote(aid)}", ctx.t("edit"))}</td>
            </tr>"""
        )
    body_rows = "".join(rows_html) or f'<tr><td colspan="7" class="muted">{html.escape(ctx.t("no_accounts"))}</td></tr>'
    return f"""
    <h2>{html.escape(ctx.t("title_accounts"))}</h2>
    <p class="meta">{html.escape(ctx.t("accounts_lead"))}</p>
    {filter_box(ctx)}
    {table_wrap(f'''
    <table>
      <thead><tr>
        <th>{html.escape(ctx.t("col_account"))}</th>
        <th>{html.escape(ctx.t("col_priv"))}</th>
        <th>{html.escape(ctx.t("col_email"))}</th>
        <th>{html.escape(ctx.t("col_lock"))}</th>
        <th>{html.escape(ctx.t("col_last_login"))}</th>
        <th>{html.escape(ctx.t("col_status"))}</th>
        <th></th>
      </tr></thead>
      <tbody>{body_rows}</tbody>
    </table>
    ''')}
    <div class="panel" style="margin-top:20px">
      <h3>{html.escape(ctx.t("new_account"))}</h3>
      <form class="stack" method="post" action="/accounts/create">
        <label>{html.escape(ctx.t("username"))}
          <input name="name" required maxlength="32" autocomplete="off"
                 placeholder="{html.escape(ctx.t("ph_username"))}"></label>
        <label>{html.escape(ctx.t("password"))}
          <input name="pass" type="password" required autocomplete="new-password"></label>
        <label class="check"><input type="checkbox" name="gm" value="1"> {html.escape(ctx.t("give_gm"))}</label>
        <button type="submit">{html.escape(ctx.t("create_account"))}</button>
      </form>
    </div>
    """


def account_edit_body(ctx: Ctx, aid: str) -> str:
    if not aid.isdigit():
        return f'<p class="err">{html.escape(ctx.t("invalid_account_id"))}</p>'
    row = sql_row("classic_realmd", f"SELECT * FROM account WHERE id={aid}")
    if not row:
        return f'<p class="err">{html.escape(ctx.t("account_missing"))}</p>'
    gm = sql_scalar(
        "classic_realmd",
        f"SELECT COALESCE(MAX(gmlevel),0) FROM account_access WHERE id={aid} AND RealmID IN (1,-1)",
    ) or "0"
    online = row.get("online", "0") == "1"
    char_online = sql_scalar(
        "classic_characters",
        f"SELECT 1 FROM characters WHERE account={aid} AND online=1 LIMIT 1",
    ) == "1"
    actions = [btn("/accounts", ctx.t("back_list"))]
    if online or char_online:
        actions.append(
            '<form method="post" action="/accounts/kick" class="inline">'
            f'<input type="hidden" name="id" value="{html.escape(aid, quote=True)}">'
            f'<button type="submit">{html.escape(ctx.t("kick"))}</button></form>'
        )
    return f"""
    {toolbar(*actions)}
    <h2>{html.escape(row.get("username", ""))}</h2>
    <p class="meta">
      #{html.escape(aid)} · {badge(ctx, online or char_online)} ·
      {html.escape(ctx.t("created_at"))} {html.escape(clean(row.get("joindate", "")) or ctx.t("dash"))} ·
      {html.escape(ctx.t("last_at"))} {html.escape(fmt_when(ctx, row.get("last_login", "")))}
    </p>
    <form method="post" action="/accounts/save">
      <input type="hidden" name="id" value="{html.escape(aid, quote=True)}">
      {section(ctx.t("section_basic"), f'''
        {input_text(ctx, "f_username", row.get("username", ""))}
        <label>{html.escape(ctx.t("gm_priv"))}{select_html(ctx, "gmlevel", ctx.gm_levels(), gm)}</label>
        {input_text(ctx, "f_email", row.get("email", ""), hint=ctx.t("email_hint"))}
        <label>{html.escape(ctx.t("language_field"))}{select_html(ctx, "f_locale", ctx.locales(), row.get("locale", "4"))}</label>
        {input_check("f_locked", row.get("locked", "0"), ctx.t("lock_account"))}
        <label class="span2">{html.escape(ctx.t("new_password"))}
          <span class="hint">{html.escape(ctx.t("new_password_hint"))}</span>
          <input type="password" name="pass" autocomplete="new-password"
                 placeholder="{html.escape(ctx.t("new_password_ph"))}">
        </label>
      ''')}
      {section(ctx.t("section_other"), f'''
        {input_text(ctx, "f_expansion", row.get("expansion", "0"), hint=ctx.t("expansion_hint"))}
        {input_text(ctx, "f_last_ip", row.get("last_ip", ""))}
        {input_text(ctx, "f_os", row.get("os", ""))}
        {input_text(ctx, "f_platform", row.get("platform", ""))}
        {input_text(ctx, "f_lock_country", row.get("lock_country", ""))}
        {input_text(ctx, "f_mutetime", row.get("mutetime", "0"))}
        {input_text(ctx, "f_flags", row.get("flags", "0"))}
        {input_check("f_email_verif", row.get("email_verif", "0"), ctx.t("email_verified"))}
        {input_text(ctx, "f_geolock_pin", row.get("geolock_pin", "0"))}
        {input_text(ctx, "f_current_realm", row.get("current_realm", "0"))}
        {input_text(ctx, "f_security", row.get("security", ""))}
        {input_area(ctx, "f_token_key", row.get("token_key", ""), ctx.t("token"))}
      ''', open_=False)}
      <div class="actions"><button type="submit">{html.escape(ctx.t("save"))}</button></div>
    </form>
    <div class="danger-zone">
      <h3>{html.escape(ctx.t("danger"))}</h3>
      <p class="muted">{html.escape(ctx.t("delete_account_warn"))}</p>
      <form method="post" action="/accounts/delete"
            onsubmit="return confirm('{html.escape(ctx.t("delete_account_confirm", name=row.get("username", "")), quote=True)}');">
        <input type="hidden" name="id" value="{html.escape(aid, quote=True)}">
        <button type="submit" class="danger">{html.escape(ctx.t("delete_account"))}</button>
      </form>
    </div>
    """


def characters_body(ctx: Ctx) -> str:
    _c, rows, err = sql_query(
        "classic_characters",
        """SELECT c.guid, c.name, a.username, c.race, c.class, c.level, c.money, c.map, c.zone, c.online
           FROM characters c
           LEFT JOIN classic_realmd.account a ON a.id = c.account
           ORDER BY c.guid""",
    )
    if err:
        _c, rows, err = sql_query(
            "classic_characters",
            "SELECT guid, name, account, race, class, level, money, map, zone, online FROM characters ORDER BY guid",
        )
        if err:
            return f'<p class="err">{html.escape(err)}</p>'
    races, classes = ctx.races(), ctx.classes()
    rows_html = []
    for r in rows:
        while len(r) < 10:
            r.append("")
        guid, name, acct, race, klass, level, money, mmap, zone, online = r[:10]
        rows_html.append(
            f"""<tr>
            <td><a href="/characters/edit?guid={urllib.parse.quote(guid)}">{html.escape(name)}</a>
              <div class="muted" style="font-size:12px">#{html.escape(guid)}</div></td>
            <td>{html.escape(acct or ctx.t("dash"))}</td>
            <td>{html.escape(lookup(races, race))} · {html.escape(lookup(classes, klass))}</td>
            <td>{html.escape(level)}</td>
            <td>{html.escape(money_str(ctx, money))}</td>
            <td class="muted">{html.escape(ctx.t("map_zone", map=mmap, zone=zone))}</td>
            <td>{badge(ctx, online == "1")}</td>
            <td>{btn(f"/characters/edit?guid={urllib.parse.quote(guid)}", ctx.t("edit"))}</td>
            </tr>"""
        )
    body_rows = "".join(rows_html) or f'<tr><td colspan="8" class="muted">{html.escape(ctx.t("no_characters"))}</td></tr>'
    return f"""
    <h2>{html.escape(ctx.t("title_characters"))}</h2>
    <p class="meta">{html.escape(ctx.t("chars_lead"))}</p>
    {filter_box(ctx)}
    {table_wrap(f'''
    <table>
      <thead><tr>
        <th>{html.escape(ctx.t("col_character"))}</th>
        <th>{html.escape(ctx.t("col_account"))}</th>
        <th>{html.escape(ctx.t("col_race_class"))}</th>
        <th>{html.escape(ctx.t("col_level"))}</th>
        <th>{html.escape(ctx.t("col_money"))}</th>
        <th>{html.escape(ctx.t("col_pos"))}</th>
        <th>{html.escape(ctx.t("col_status"))}</th>
        <th></th>
      </tr></thead>
      <tbody>{body_rows}</tbody>
    </table>
    ''')}
    """


def character_edit_body(ctx: Ctx, guid: str) -> str:
    if not guid.isdigit():
        return f'<p class="err">{html.escape(ctx.t("invalid_guid"))}</p>'
    row = sql_row("classic_characters", f"SELECT * FROM characters WHERE guid={guid}")
    if not row:
        return f'<p class="err">{html.escape(ctx.t("char_missing"))}</p>'
    g, s, c = money_parts(row.get("money", "0"))
    online = row.get("online") == "1"
    acct = row.get("account", "")
    acct_name = sql_scalar("classic_realmd", f"SELECT username FROM account WHERE id={acct}") if acct.isdigit() else ""
    warn = f'<p class="err">{html.escape(ctx.t("char_online_warn"))}</p>' if online else ""
    actions = [btn("/characters", ctx.t("back_list"))]
    if acct.isdigit():
        actions.append(btn(f"/accounts/edit?id={urllib.parse.quote(acct)}", ctx.t("view_account")))
    if online:
        actions.append(
            '<form method="post" action="/characters/kick" class="inline">'
            f'<input type="hidden" name="guid" value="{html.escape(guid, quote=True)}">'
            f'<button type="submit">{html.escape(ctx.t("kick"))}</button></form>'
        )
    race_s = lookup(ctx.races(), row.get("race", ""))
    class_s = lookup(ctx.classes(), row.get("class", ""))
    return f"""
    {toolbar(*actions)}
    <h2>{html.escape(row.get("name", ""))}</h2>
    <p class="meta">
      #{html.escape(guid)} · {html.escape(race_s)} {html.escape(class_s)} ·
      {badge(ctx, online)} · {html.escape(ctx.t("col_account"))} {html.escape(acct_name or acct or ctx.t("dash"))}
    </p>
    {warn}
    <form method="post" action="/characters/save">
      <input type="hidden" name="guid" value="{html.escape(guid, quote=True)}">
      {section(ctx.t("section_basic_char"), f'''
        {input_text(ctx, "f_name", row.get("name", ""))}
        {input_text(ctx, "f_account", row.get("account", ""), hint=ctx.t("account_id_hint"))}
        <label>{html.escape(ctx.t("lbl_race"))}{select_html(ctx, "f_race", ctx.races(), row.get("race", "1"))}</label>
        <label>{html.escape(ctx.t("lbl_class"))}{select_html(ctx, "f_class", ctx.classes(), row.get("class", "1"))}</label>
        <label>{html.escape(ctx.t("lbl_gender"))}{select_html(ctx, "f_gender", ctx.genders(), row.get("gender", "0"))}</label>
        {input_text(ctx, "f_level", row.get("level", "1"))}
        {input_text(ctx, "f_xp", row.get("xp", "0"))}
        <div class="span2"><div class="muted" style="margin-bottom:4px">{html.escape(ctx.t("money"))}</div>
          <div class="money">
            <label>{html.escape(ctx.t("gold"))} <input name="money_gold" value="{g}"></label>
            <label>{html.escape(ctx.t("silver"))} <input name="money_silver" value="{s}"></label>
            <label>{html.escape(ctx.t("copper"))} <input name="money_copper" value="{c}"></label>
          </div>
        </div>
      ''')}
      {section(ctx.t("section_appearance"), f'''
        {input_text(ctx, "f_skin", row.get("skin", "0"))}
        {input_text(ctx, "f_face", row.get("face", "0"))}
        {input_text(ctx, "f_hair_style", row.get("hair_style", "0"))}
        {input_text(ctx, "f_hair_color", row.get("hair_color", "0"))}
        {input_text(ctx, "f_facial_hair", row.get("facial_hair", "0"))}
      ''', open_=False)}
      {section(ctx.t("section_location"), f'''
        {input_text(ctx, "f_map", row.get("map", "0"), hint=ctx.t("map_hint"))}
        {input_text(ctx, "f_zone", row.get("zone", "0"))}
        {input_text(ctx, "f_instance", row.get("instance", "0"))}
        {input_text(ctx, "f_position_x", row.get("position_x", "0"))}
        {input_text(ctx, "f_position_y", row.get("position_y", "0"))}
        {input_text(ctx, "f_position_z", row.get("position_z", "0"))}
        {input_text(ctx, "f_orientation", row.get("orientation", "0"))}
      ''')}
      {section(ctx.t("section_combat"), f'''
        {input_check("f_online", row.get("online", "0"), ctx.t("mark_online"))}
        {input_text(ctx, "f_health", row.get("health", "0"))}
        {input_text(ctx, "f_power1", row.get("power1", "0"))}
        {input_text(ctx, "f_power2", row.get("power2", "0"))}
        {input_text(ctx, "f_power3", row.get("power3", "0"))}
        {input_text(ctx, "f_power4", row.get("power4", "0"))}
        {input_text(ctx, "f_power5", row.get("power5", "0"))}
        {input_text(ctx, "f_rest_bonus", row.get("rest_bonus", "0"))}
        {input_text(ctx, "f_played_time_total", row.get("played_time_total", "0"), hint=ctx.t("seconds"))}
        {input_text(ctx, "f_played_time_level", row.get("played_time_level", "0"), hint=ctx.t("seconds"))}
        {input_text(ctx, "f_drunk", row.get("drunk", "0"))}
      ''', open_=False)}
      {section(ctx.t("section_honor"), f'''
        {input_text(ctx, "f_honor_rank_points", row.get("honor_rank_points", "0"))}
        {input_text(ctx, "f_honor_highest_rank", row.get("honor_highest_rank", "0"))}
        {input_text(ctx, "f_honor_standing", row.get("honor_standing", "0"))}
        {input_text(ctx, "f_honor_last_week_hk", row.get("honor_last_week_hk", "0"))}
        {input_text(ctx, "f_honor_last_week_cp", row.get("honor_last_week_cp", "0"))}
        {input_text(ctx, "f_honor_stored_hk", row.get("honor_stored_hk", "0"))}
        {input_text(ctx, "f_honor_stored_dk", row.get("honor_stored_dk", "0"))}
        {input_text(ctx, "f_watched_faction", row.get("watched_faction", "-1"))}
        {input_text(ctx, "f_stable_slots", row.get("stable_slots", "0"))}
        {input_text(ctx, "f_bank_bag_slots", row.get("bank_bag_slots", "0"))}
        {input_text(ctx, "f_ammo_id", row.get("ammo_id", "0"))}
        {input_text(ctx, "f_action_bars", row.get("action_bars", "0"))}
        {input_text(ctx, "f_character_flags", row.get("character_flags", "0"))}
        {input_text(ctx, "f_extra_flags", row.get("extra_flags", "0"))}
      ''', open_=False)}
      {section(ctx.t("section_advanced"), f'''
        {input_area(ctx, "f_world_phase_mask", row.get("world_phase_mask", ""))}
        {input_area(ctx, "f_known_taxi_mask", row.get("known_taxi_mask", ""))}
        {input_area(ctx, "f_current_taxi_path", row.get("current_taxi_path", ""))}
        {input_area(ctx, "f_explored_zones", row.get("explored_zones", ""))}
        {input_area(ctx, "f_equipment_cache", row.get("equipment_cache", ""))}
      ''', open_=False)}
      <div class="actions"><button type="submit">{html.escape(ctx.t("save"))}</button></div>
    </form>
    <div class="danger-zone">
      <h3>{html.escape(ctx.t("danger"))}</h3>
      <p class="muted">{html.escape(ctx.t("delete_char_warn"))}</p>
      <form method="post" action="/characters/delete"
            onsubmit="return confirm('{html.escape(ctx.t("delete_char_confirm", name=row.get("name", "")), quote=True)}');">
        <input type="hidden" name="guid" value="{html.escape(guid, quote=True)}">
        <button type="submit" class="danger">{html.escape(ctx.t("delete_char"))}</button>
      </form>
    </div>
    """


def db_body(ctx: Ctx, qs: dict[str, list[str]]) -> str:
    db = (qs.get("db") or ["classic_realmd"])[0]
    if db not in ALLOWED_DBS:
        db = "classic_realmd"
    table = (qs.get("table") or [""])[0]
    page_n = 1
    try:
        page_n = max(1, int((qs.get("page") or ["1"])[0]))
    except ValueError:
        page_n = 1
    per, offset = 40, (page_n - 1) * 40

    chips = []
    for d in ALLOWED_DBS:
        on = " on" if d == db else ""
        blurb = ctx.db_blurb(d)
        chips.append(
            f'<a class="chip{on}" href="/db?db={urllib.parse.quote(d)}" '
            f'title="{html.escape(blurb, quote=True)}">'
            f'<span class="chip-title">{html.escape(ctx.db_label(d))}</span>'
            f'<span class="chip-tech">{html.escape(d)}</span>'
            f'<span class="chip-blurb">{html.escape(blurb)}</span></a>'
        )
    code, out, err = mariadb(database=db, sql="SHOW TABLES;")
    table_names = [ln.strip() for ln in out.splitlines() if ln.strip()] if code == 0 else []
    tables_out = f'<p class="err">{html.escape(err or out)}</p>' if code != 0 else ""
    table_chip_parts = []
    for tname in table_names:
        on = " on" if tname == table else ""
        title = ctx.table_label(tname)
        blurb = ctx.table_blurb(tname)
        table_chip_parts.append(
            f'<a class="chip{on}" href="/db?db={urllib.parse.quote(db)}&table={urllib.parse.quote(tname)}" '
            f'title="{html.escape(blurb, quote=True)}">'
            f'<span class="chip-title">{html.escape(title)}</span>'
            f'<span class="chip-tech">{html.escape(tname)}</span></a>'
        )
    table_chips = " ".join(table_chip_parts) or f'<span class="muted">{html.escape(ctx.t("no_tables"))}</span>'

    browse = ""
    if table and IDENT.match(table):
        pk = table_primary_key(db, table)
        cols, rows, qerr = sql_query(db, f"SELECT * FROM `{table}` LIMIT {per} OFFSET {offset}")
        if qerr:
            browse = f'<p class="err">{html.escape(qerr)}</p>'
        else:
            head = "".join(f"<th>{html.escape(c)}</th>" for c in cols[:12])
            if len(cols) > 12:
                head += "<th>…</th>"
            if pk:
                head += "<th></th>"
            body_rows = []
            pk_i = cols.index(pk) if pk and pk in cols else -1
            for r in rows:
                while len(r) < len(cols):
                    r.append("")
                cells = "".join(
                    f"<td>{html.escape(c if len(c) < 48 else c[:45] + '…')}</td>" for c in r[:12]
                )
                if len(cols) > 12:
                    cells += '<td class="muted">…</td>'
                if pk and pk_i >= 0:
                    edit_url = (
                        "/db/edit?db=" + urllib.parse.quote(db)
                        + "&table=" + urllib.parse.quote(table)
                        + "&pk=" + urllib.parse.quote(pk)
                        + "&id=" + urllib.parse.quote(r[pk_i])
                    )
                    cells += f"<td>{btn(edit_url, ctx.t('edit'))}</td>"
                body_rows.append(f"<tr>{cells}</tr>")
            prev = (
                f'<a class="btn" href="/db?db={urllib.parse.quote(db)}&table={urllib.parse.quote(table)}&page={page_n - 1}">{html.escape(ctx.t("prev"))}</a>'
                if page_n > 1 else ""
            )
            nxt = (
                f'<a class="btn" href="/db?db={urllib.parse.quote(db)}&table={urllib.parse.quote(table)}&page={page_n + 1}">{html.escape(ctx.t("next"))}</a>'
                if len(rows) == per else ""
            )
            note = (
                f'<p class="muted">{html.escape(ctx.t("pk_note", pk=pk))}</p>'
                if pk else f'<p class="muted">{html.escape(ctx.t("no_pk_note"))}</p>'
            )
            rows_inner = "".join(body_rows) or f'<tr><td class="muted">{html.escape(ctx.t("empty_table"))}</td></tr>'
            t_title = ctx.table_label(table)
            t_blurb = ctx.table_blurb(table)
            browse = f"""
            <div class="panel">
              <h3>{html.escape(t_title)}
                <span class="muted"> · <code>{html.escape(table)}</code> · {html.escape(ctx.t("page_n", n=page_n))}</span>
              </h3>
              <p class="meta" style="margin-top:0">{html.escape(t_blurb)}</p>
              {note}
              <div class="toolbar">{prev}{nxt}</div>
              {filter_box(ctx)}
              {table_wrap(f'<table><thead><tr>{head}</tr></thead><tbody>{rows_inner}</tbody></table>', sticky_end=bool(pk))}
            </div>
            """
    elif table:
        browse = f'<p class="err">{html.escape(ctx.t("bad_table"))}</p>'

    return f"""
    <h2>{html.escape(ctx.t("title_db"))}</h2>
    <p class="meta">{html.escape(ctx.t("db_lead"))}</p>
    <div class="chip-row">{''.join(chips)}</div>
    <p class="muted" style="margin:14px 0 6px">{html.escape(ctx.t("db_current", label=ctx.db_label(db), name=db))}
      — {html.escape(ctx.db_blurb(db))}</p>
    {tables_out}
    <input class="filter" type="search" data-filter-chips
           placeholder="{html.escape(ctx.t("filter_tables"))}"
           aria-label="{html.escape(ctx.t("filter_tables"))}">
    <div class="chip-row compact">{table_chips}</div>
    {browse}
    <div class="panel">
      <h3>{html.escape(ctx.t("run_sql"))}</h3>
      <form class="stack" method="post" action="/db/sql" style="max-width:100%">
        <input type="hidden" name="db" value="{html.escape(db, quote=True)}">
        <label>{html.escape(ctx.t("run_sql_in", label=ctx.db_label(db)))}
          <textarea name="sql" placeholder="{html.escape(ctx.t("sql_ph"))}" required></textarea>
        </label>
        <label class="check"><input type="checkbox" name="confirm_write" value="1">
          {html.escape(ctx.t("confirm_write"))}</label>
        <button type="submit">{html.escape(ctx.t("run"))}</button>
      </form>
    </div>
    """


def db_edit_body(ctx: Ctx, qs: dict[str, list[str]]) -> str:
    db = (qs.get("db") or [""])[0]
    table = (qs.get("table") or [""])[0]
    pk = (qs.get("pk") or [""])[0]
    pk_id = (qs.get("id") or [""])[0]
    if db not in ALLOWED_DBS or not IDENT.match(table or "") or not IDENT.match(pk or ""):
        return f'<p class="err">{html.escape(ctx.t("bad_params"))}</p>'
    if pk_id.isdigit() or (pk_id.startswith("-") and pk_id[1:].isdigit()):
        where = f"`{pk}`={pk_id}"
    else:
        where = f"`{pk}`='{sql_escape(pk_id)}'"
    row = sql_row(db, f"SELECT * FROM `{table}` WHERE {where} LIMIT 1")
    if not row:
        return f'<p class="err">{html.escape(ctx.t("row_missing"))}</p>'
    fields = []
    for name, value in row.items():
        if name == pk:
            lab = ctx.t(f"lbl_{name}") if ctx.t(f"lbl_{name}") != f"lbl_{name}" else name
            fields.append(
                f'<label>{html.escape(lab)} {html.escape(ctx.t("pk_readonly"))}'
                f'<input value="{html.escape(clean(value), quote=True)}" disabled>'
                f'<input type="hidden" name="f_{html.escape(name, quote=True)}" '
                f'value="{html.escape(clean(value), quote=True)}"></label>'
            )
            continue
        if db == "classic_realmd" and table == "account" and name in ACCOUNT_SKIP:
            continue
        long = len(clean(value)) > 80 or name.endswith(("_mask", "_path", "_zones", "_cache", "_key"))
        fields.append(
            input_area(ctx, f"f_{name}", value) if long else input_text(ctx, f"f_{name}", value)
        )
    back = f"/db?db={urllib.parse.quote(db)}&table={urllib.parse.quote(table)}"
    return f"""
    {toolbar(btn(back, ctx.t("back_table")))}
    <h2>{html.escape(ctx.t("edit_row"))}</h2>
    <p class="meta">{html.escape(ctx.t("edit_row_meta", db=ctx.db_label(db), table=f"{ctx.table_label(table)} ({table})", pk=pk, id=pk_id))}
      · {html.escape(ctx.table_blurb(table))}</p>
    <form method="post" action="/db/save">
      <input type="hidden" name="db" value="{html.escape(db, quote=True)}">
      <input type="hidden" name="table" value="{html.escape(table, quote=True)}">
      <input type="hidden" name="pk" value="{html.escape(pk, quote=True)}">
      <input type="hidden" name="id" value="{html.escape(pk_id, quote=True)}">
      <div class="panel"><div class="grid">{''.join(fields)}</div></div>
      <div class="actions"><button type="submit">{html.escape(ctx.t("save"))}</button></div>
    </form>
    """


# --- mutations (messages use ctx.lang) ---

def create_account(ctx: Ctx, name: str, password: str, gm: bool) -> str:
    name = name.strip()
    if not name or not password:
        return ctx.t("msg_need_user_pass")
    if mangosd_up():
        script = ROOT / "tools" / "macos" / "create-account.sh"
        args = [str(script), name, password] + (["gm"] if gm else [])
        proc = subprocess.run(args, capture_output=True, text=True, check=False)
        return (proc.stdout or proc.stderr or "").strip() or f"exit {proc.returncode}"
    if sql_scalar("classic_realmd", f"SELECT 1 FROM account WHERE username=UPPER('{sql_escape(name)}')"):
        return ctx.t("msg_exists")
    s_hex, v_hex = srp_sv(name, password)
    err = sql_exec(
        "classic_realmd",
        f"INSERT INTO account(username,v,s,joindate) VALUES(UPPER('{sql_escape(name)}'),'{s_hex}','{v_hex}',NOW())",
    )
    if err:
        return err
    if gm:
        aid = sql_scalar("classic_realmd", f"SELECT id FROM account WHERE username=UPPER('{sql_escape(name)}')")
        if aid:
            sql_exec("classic_realmd", f"REPLACE INTO account_access(id,gmlevel,RealmID) VALUES({aid},6,1)")
    return ctx.t("msg_created_offline", name=name.upper())


def save_account(ctx: Ctx, form: dict[str, str]) -> str:
    aid = form.get("id", "")
    if not aid.isdigit():
        return ctx.t("msg_invalid_id")
    row = sql_row("classic_realmd", f"SELECT username FROM account WHERE id={aid}")
    if not row:
        return ctx.t("msg_account_missing")
    old_user = row["username"]
    form = dict(form)
    form["f_locked"] = "1" if form.get("f_locked") == "1" else "0"
    form["f_email_verif"] = "1" if form.get("f_email_verif") == "1" else "0"
    new_user = form.get("f_username", old_user).strip() or old_user
    sets: list[str] = []
    for key, val in form.items():
        if not key.startswith("f_"):
            continue
        col = key[2:]
        if col not in ACCOUNT_FIELDS or not IDENT.match(col):
            continue
        if col == "username":
            sets.append(f"`username`=UPPER('{sql_escape(val.strip())}')")
        else:
            sets.append(f"`{col}`='{sql_escape(val)}'")
    password = form.get("pass", "")
    if password:
        s_hex, v_hex = srp_sv(new_user, password)
        sets.append(f"`s`='{s_hex}'")
        sets.append(f"`v`='{v_hex}'")
        if mangosd_up():
            fifo_cmd(ctx, f"account set password {old_user} {password} {password}")
    if sets:
        err = sql_exec("classic_realmd", f"UPDATE account SET {', '.join(sets)} WHERE id={aid}")
        if err:
            return err
    gm = form.get("gmlevel", "").strip()
    if gm != "":
        try:
            lvl = int(gm)
        except ValueError:
            return ctx.t("msg_gm_num")
        if lvl < 0 or lvl > 6:
            return ctx.t("msg_gm_range")
        if mangosd_up():
            fifo_cmd(ctx, f"account set gmlevel {new_user.upper()} {lvl}")
        err = sql_exec(
            "classic_realmd",
            f"REPLACE INTO account_access(id,gmlevel,RealmID) VALUES({aid},{lvl},1)",
        )
        if err:
            return err
    return ctx.t("msg_saved")


def kick_character(ctx: Ctx, guid: str) -> str:
    if not guid.isdigit():
        return ctx.t("msg_invalid_guid")
    name = sql_scalar("classic_characters", f"SELECT name FROM characters WHERE guid={guid}")
    if not name:
        return ctx.t("msg_char_missing")
    if sql_scalar("classic_characters", f"SELECT online FROM characters WHERE guid={guid}") != "1":
        return ctx.t("msg_char_offline")
    if not mangosd_up():
        return ctx.t("msg_no_mangosd_kick")
    return fifo_cmd(ctx, f'kick "{name}"')


def kick_account(ctx: Ctx, aid: str) -> str:
    if not aid.isdigit():
        return ctx.t("msg_invalid_id")
    if not sql_scalar("classic_realmd", f"SELECT 1 FROM account WHERE id={aid}"):
        return ctx.t("msg_account_missing")
    if not mangosd_up():
        return ctx.t("msg_no_mangosd_kick")
    _c, rows, err = sql_query(
        "classic_characters", f"SELECT name FROM characters WHERE account={aid} AND online=1",
    )
    if err:
        return err
    if not rows:
        user = sql_scalar("classic_realmd", f"SELECT username FROM account WHERE id={aid}")
        if sql_scalar("classic_realmd", f"SELECT online FROM account WHERE id={aid}") == "1" and user:
            return ctx.t("msg_kick_charselect", user=user)
        return ctx.t("msg_no_online_chars")
    return "；".join(fifo_cmd(ctx, f'kick "{r[0]}"') for r in rows if r and r[0])


def delete_account(ctx: Ctx, aid: str) -> str:
    if not aid.isdigit():
        return ctx.t("msg_invalid_id")
    name = sql_scalar("classic_realmd", f"SELECT username FROM account WHERE id={aid}")
    if not name:
        return ctx.t("msg_account_missing")
    if sql_scalar("classic_realmd", f"SELECT online FROM account WHERE id={aid}") == "1":
        return ctx.t("msg_acct_online_kick")
    chars_online = sql_scalar(
        "classic_characters", f"SELECT COUNT(*) FROM characters WHERE account={aid} AND online=1",
    )
    if chars_online and chars_online != "0":
        return ctx.t("msg_chars_online_kick")
    if mangosd_up():
        return fifo_cmd(ctx, f"account delete {name}")
    sql_exec("classic_characters", f"DELETE FROM characters WHERE account={aid}")
    sql_exec("classic_realmd", f"DELETE FROM account_access WHERE id={aid}")
    sql_exec("classic_realmd", f"DELETE FROM realmcharacters WHERE acctid={aid}")
    err = sql_exec("classic_realmd", f"DELETE FROM account WHERE id={aid}")
    return err or ctx.t("msg_deleted_acct", name=name)


def save_character(ctx: Ctx, form: dict[str, str]) -> str:
    guid = form.get("guid", "")
    if not guid.isdigit():
        return ctx.t("msg_invalid_guid")
    if sql_scalar("classic_characters", f"SELECT 1 FROM characters WHERE guid={guid}") != "1":
        return ctx.t("msg_char_missing")
    form = dict(form)
    form["f_online"] = "1" if form.get("f_online") == "1" else "0"
    if any(k in form for k in ("money_gold", "money_silver", "money_copper")):
        try:
            g = max(0, int(form.get("money_gold") or "0"))
            s = max(0, int(form.get("money_silver") or "0"))
            c = max(0, int(form.get("money_copper") or "0"))
            form["f_money"] = str(g * 10000 + s * 100 + c)
        except ValueError:
            return ctx.t("msg_money_int")
    sets: list[str] = []
    for key, val in form.items():
        if not key.startswith("f_"):
            continue
        col = key[2:]
        if col not in CHAR_FIELDS or not IDENT.match(col):
            continue
        sets.append(
            f"`name`='{sql_escape(val.strip())}'" if col == "name" else f"`{col}`='{sql_escape(val)}'"
        )
    if not sets:
        return ctx.t("msg_no_fields")
    err = sql_exec("classic_characters", f"UPDATE characters SET {', '.join(sets)} WHERE guid={guid}")
    return err or ctx.t("msg_saved")


def delete_character(ctx: Ctx, guid: str) -> str:
    if not guid.isdigit():
        return ctx.t("msg_invalid_guid")
    if sql_scalar("classic_characters", f"SELECT online FROM characters WHERE guid={guid}") == "1":
        return ctx.t("msg_char_online_del")
    err = sql_exec("classic_characters", f"DELETE FROM characters WHERE guid={guid}")
    return err or ctx.t("msg_deleted_char", guid=guid)


def save_db_row(ctx: Ctx, form: dict[str, str]) -> str:
    db, table, pk, pk_id = form.get("db", ""), form.get("table", ""), form.get("pk", ""), form.get("id", "")
    if db not in ALLOWED_DBS or not IDENT.match(table) or not IDENT.match(pk):
        return ctx.t("bad_params")
    sets: list[str] = []
    for key, val in form.items():
        if not key.startswith("f_"):
            continue
        col = key[2:]
        if not IDENT.match(col) or col == pk:
            continue
        if db == "classic_realmd" and table == "account" and col in ACCOUNT_SKIP:
            continue
        sets.append(f"`{col}`='{sql_escape(val)}'")
    if not sets:
        return ctx.t("msg_no_fields")
    if pk_id.isdigit() or (pk_id.startswith("-") and pk_id[1:].isdigit()):
        where = f"`{pk}`={pk_id}"
    else:
        where = f"`{pk}`='{sql_escape(pk_id)}'"
    err = sql_exec(db, f"UPDATE `{table}` SET {', '.join(sets)} WHERE {where}")
    return err or ctx.t("msg_saved")


def run_sql(ctx: Ctx, db: str, sql: str, confirm_write: bool) -> str:
    sql = sql.strip()
    if not sql:
        return ctx.t("msg_empty_sql")
    if db not in ALLOWED_DBS:
        return ctx.t("msg_bad_db")
    if WRITE_HINT.search(sql) and not confirm_write:
        return ctx.t("msg_confirm_write")
    cols, rows, err = sql_query(db, sql)
    if err:
        return ctx.t("msg_sql_err", err=err)
    if not cols:
        return ctx.t("msg_sql_ok_empty")
    head = "\t".join(cols)
    body = "\n".join("\t".join(r) for r in rows[:500])
    more = f"\n… {len(rows)}" if len(rows) > 500 else ""
    return f"{head}\n{body}{more}" if body else head


def parse_cookies(header: str | None) -> dict[str, str]:
    c = SimpleCookie()
    if header:
        try:
            c.load(header)
        except Exception:
            return {}
    return {k: m.value for k, m in c.items()}


def make_ctx(cookies: dict[str, str], qs: dict[str, list[str]] | None = None) -> Ctx:
    qs = qs or {}
    lang = (qs.get("lang") or [cookies.get("sa_lang", "zh")])[0]
    theme = (qs.get("theme") or [cookies.get("sa_theme", "dark")])[0]
    if lang not in ("zh", "en"):
        lang = "zh"
    if theme not in ("dark", "light"):
        theme = "dark"
    return Ctx(lang=lang, theme=theme)


class Handler(BaseHTTPRequestHandler):
    server_version = "SolorothAdmin/1.0"

    def log_message(self, fmt: str, *args) -> None:
        sys.stderr.write("admin: " + (fmt % args) + "\n")

    def _cookies(self) -> dict[str, str]:
        return parse_cookies(self.headers.get("Cookie"))

    def _ctx(self, qs: dict[str, list[str]] | None = None) -> Ctx:
        return make_ctx(self._cookies(), qs)

    def _send(
        self, code: int, body: bytes, content_type: str = "text/html; charset=utf-8",
        set_cookies: list[tuple[str, str]] | None = None,
    ) -> None:
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        for name, value in set_cookies or []:
            self.send_header(
                "Set-Cookie",
                f"{name}={value}; Path=/; Max-Age={COOKIE_MAX_AGE}; SameSite=Lax",
            )
        self.end_headers()
        self.wfile.write(body)

    def _redirect(self, loc: str, set_cookies: list[tuple[str, str]] | None = None) -> None:
        self.send_response(303)
        self.send_header("Location", loc)
        for name, value in set_cookies or []:
            self.send_header(
                "Set-Cookie",
                f"{name}={value}; Path=/; Max-Age={COOKIE_MAX_AGE}; SameSite=Lax",
            )
        self.end_headers()

    def _read_form(self) -> dict[str, str]:
        length = int(self.headers.get("Content-Length", "0") or 0)
        raw = self.rfile.read(length) if length else b""
        parsed = urllib.parse.parse_qs(raw.decode("utf-8", errors="replace"), keep_blank_values=True)
        return {k: (v[0] if v else "") for k, v in parsed.items()}

    def do_GET(self) -> None:
        parsed = urllib.parse.urlparse(self.path)
        path, qs = parsed.path, urllib.parse.parse_qs(parsed.query)
        flash = (qs.get("flash") or [""])[0]
        ctx = self._ctx()

        if path == "/prefs":
            cookies: list[tuple[str, str]] = []
            if (qs.get("lang") or [""])[0] in ("zh", "en"):
                cookies.append(("sa_lang", qs["lang"][0]))
            if (qs.get("theme") or [""])[0] in ("dark", "light"):
                cookies.append(("sa_theme", qs["theme"][0]))
            nxt = (qs.get("next") or ["/"])[0]
            if not nxt.startswith("/"):
                nxt = "/"
            self._redirect(nxt, set_cookies=cookies)
            return

        if path == "/health":
            self._send(200, b"ok\n", "text/plain; charset=utf-8")
            return

        pages = {
            "/": ("title_overview", lambda: status_body(ctx)),
            "/accounts": ("title_accounts", lambda: accounts_body(ctx)),
            "/characters": ("title_characters", lambda: characters_body(ctx)),
            "/db": ("title_db", lambda: db_body(ctx, qs)),
        }
        if path in pages:
            title_key, body_fn = pages[path]
            self._send(200, page(ctx, ctx.t(title_key), body_fn(), flash, path))
        elif path == "/accounts/edit":
            body = account_edit_body(ctx, (qs.get("id") or [""])[0])
            self._send(200, page(ctx, ctx.t("title_account_edit"), body, flash, path))
        elif path == "/characters/edit":
            body = character_edit_body(ctx, (qs.get("guid") or [""])[0])
            self._send(200, page(ctx, ctx.t("title_character_edit"), body, flash, path))
        elif path == "/db/edit":
            self._send(200, page(ctx, ctx.t("title_db_edit"), db_edit_body(ctx, qs), flash, path))
        else:
            self._send(404, page(ctx, ctx.t("title_404"), f'<p class="err">{html.escape(ctx.t("not_found"))}</p>', "", path))

    def do_POST(self) -> None:
        path = urllib.parse.urlparse(self.path).path
        form = self._read_form()
        ctx = self._ctx()

        if path == "/accounts/create":
            msg = create_account(ctx, form.get("name", ""), form.get("pass", ""), form.get("gm") == "1")
            self._redirect("/accounts?flash=" + urllib.parse.quote(msg))
        elif path == "/accounts/save":
            msg = save_account(ctx, form)
            self._redirect(
                f"/accounts/edit?id={urllib.parse.quote(form.get('id', ''))}&flash="
                + urllib.parse.quote(msg)
            )
        elif path == "/accounts/kick":
            msg = kick_account(ctx, form.get("id", ""))
            self._redirect(
                f"/accounts/edit?id={urllib.parse.quote(form.get('id', ''))}&flash="
                + urllib.parse.quote(msg)
            )
        elif path == "/accounts/delete":
            msg = delete_account(ctx, form.get("id", ""))
            self._redirect("/accounts?flash=" + urllib.parse.quote(msg))
        elif path == "/characters/save":
            msg = save_character(ctx, form)
            self._redirect(
                f"/characters/edit?guid={urllib.parse.quote(form.get('guid', ''))}&flash="
                + urllib.parse.quote(msg)
            )
        elif path == "/characters/kick":
            msg = kick_character(ctx, form.get("guid", ""))
            self._redirect(
                f"/characters/edit?guid={urllib.parse.quote(form.get('guid', ''))}&flash="
                + urllib.parse.quote(msg)
            )
        elif path == "/characters/delete":
            msg = delete_character(ctx, form.get("guid", ""))
            self._redirect("/characters?flash=" + urllib.parse.quote(msg))
        elif path == "/db/save":
            msg = save_db_row(ctx, form)
            loc = (
                f"/db/edit?db={urllib.parse.quote(form.get('db', ''))}"
                f"&table={urllib.parse.quote(form.get('table', ''))}"
                f"&pk={urllib.parse.quote(form.get('pk', ''))}"
                f"&id={urllib.parse.quote(form.get('id', ''))}"
                f"&flash={urllib.parse.quote(msg)}"
            )
            self._redirect(loc)
        elif path == "/db/sql":
            msg = run_sql(ctx, form.get("db", ""), form.get("sql", ""), form.get("confirm_write") == "1")
            body = (
                f'<h2>{html.escape(ctx.t("sql_result"))}</h2>'
                f'<pre class="sql">{html.escape(msg)}</pre>'
                f'<p>{btn(f"/db?db={urllib.parse.quote(form.get("db", ""))}", ctx.t("back_db"))}</p>'
            )
            self._send(200, page(ctx, ctx.t("title_sql"), body, "", "/db"))
        else:
            self._send(404, page(ctx, ctx.t("title_404"), f'<p class="err">{html.escape(ctx.t("not_found"))}</p>'))


def main() -> None:
    port = PORT
    args = sys.argv[1:]
    if args and args[0] == "--port":
        port = int(args[1])
    elif args:
        die(f"usage: {sys.argv[0]} [--port {PORT}]")
    # Ensure i18n import works when started from any cwd.
    os.chdir(Path(__file__).resolve().parent)
    httpd = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    print(f"admin listening on http://127.0.0.1:{port}", flush=True)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nadmin stopped", flush=True)


if __name__ == "__main__":
    main()
