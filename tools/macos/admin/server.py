#!/usr/bin/env python3
"""Local Soloroth admin (127.0.0.1 only): accounts, characters, SQL browse.

  python3 tools/macos/admin/server.py [--port 8765]
  tools/macos/start-admin.sh

Bind loopback only. No auth — single-player machine use; do not expose.
"""
from __future__ import annotations

import html
import os
import re
import socket
import subprocess
import sys
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
MARIA = ROOT / "server" / "mariadb" / "bin" / "mariadb"
FIFO = ROOT / "server" / "logs" / "mangosd.stdin"
PORT = 8765
ALLOWED_DBS = (
    "classic_realmd",
    "classic_characters",
    "classic_world",
    "classic_logs",
)
IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
WRITE_HINT = re.compile(
    r"\b(INSERT|UPDATE|DELETE|DROP|ALTER|TRUNCATE|REPLACE|CREATE|GRANT|REVOKE|LOAD)\b",
    re.I,
)


def die(msg: str, code: int = 1) -> None:
    print(f"admin: {msg}", file=sys.stderr)
    raise SystemExit(code)


def mariadb(*args: str, database: str | None = None, sql: str | None = None) -> tuple[int, str, str]:
    if not MARIA.is_file():
        return 1, "", f"missing {MARIA} (run ./do.sh setup)"
    cmd = [str(MARIA), "-h", "127.0.0.1", "-P", "3306", "-u", "root", "--skip-ssl", "-N", "-B"]
    if database:
        cmd.append(database)
    cmd.extend(args)
    try:
        proc = subprocess.run(
            cmd,
            input=sql,
            capture_output=True,
            text=True,
            timeout=60,
            check=False,
        )
    except FileNotFoundError:
        return 1, "", f"cannot run {MARIA}"
    except subprocess.TimeoutExpired:
        return 1, "", "mariadb timed out"
    return proc.returncode, proc.stdout, proc.stderr


def sql_query(database: str, sql: str) -> tuple[list[str], list[list[str]], str | None]:
    """Run SQL; return (columns, rows, error). Uses --column-names for SELECT-like output."""
    if database not in ALLOWED_DBS:
        return [], [], "database not allowed"
    code, out, err = mariadb(
        "--column-names",
        database=database,
        sql=sql if sql.endswith(";") else sql + ";",
    )
    if code != 0:
        return [], [], (err or out or f"exit {code}").strip()
    lines = [ln for ln in out.splitlines() if ln != ""]
    if not lines:
        return [], [], None
    cols = lines[0].split("\t")
    rows = [ln.split("\t") for ln in lines[1:]]
    return cols, rows, None


def sql_scalar(database: str, sql: str) -> str:
    code, out, err = mariadb(database=database, sql=sql)
    if code != 0:
        return ""
    return out.strip().splitlines()[0] if out.strip() else ""


def port_open(port: int) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(0.3)
        return s.connect_ex(("127.0.0.1", port)) == 0


def process_running(name: str) -> bool:
    try:
        return (
            subprocess.run(
                ["pgrep", "-x", name],
                capture_output=True,
                check=False,
            ).returncode
            == 0
        )
    except OSError:
        return False


def page(title: str, body: str, flash: str = "") -> bytes:
    nav = """
    <nav>
      <a href="/">概览</a>
      <a href="/accounts">账号</a>
      <a href="/characters">角色</a>
      <a href="/db">数据库</a>
    </nav>
    """
    flash_html = f'<p class="flash">{html.escape(flash)}</p>' if flash else ""
    doc = f"""<!DOCTYPE html>
<html lang="zh-Hans">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)} · Soloroth</title>
<style>
  :root {{
    --bg: #0a0c12; --panel: #141822; --text: #ebe4d4; --muted: #8a8a92;
    --gold: #edc266; --line: #2a3140; --ok: #6bbf6b; --bad: #c45c5c;
  }}
  * {{ box-sizing: border-box; }}
  body {{
    margin: 0; font: 14px/1.45 -apple-system, BlinkMacSystemFont, "PingFang SC", sans-serif;
    background: radial-gradient(1200px 600px at 20% -10%, #1a2233, var(--bg));
    color: var(--text); min-height: 100vh;
  }}
  header {{
    padding: 20px 28px 8px; border-bottom: 1px solid var(--line);
    display: flex; align-items: baseline; gap: 16px; flex-wrap: wrap;
  }}
  header h1 {{ margin: 0; font-size: 20px; color: var(--gold); letter-spacing: 0.04em; }}
  header .sub {{ color: var(--muted); font-size: 12px; }}
  nav {{ display: flex; gap: 8px; padding: 12px 28px; border-bottom: 1px solid var(--line); }}
  nav a {{
    color: var(--text); text-decoration: none; padding: 6px 12px; border-radius: 6px;
    border: 1px solid transparent;
  }}
  nav a:hover {{ border-color: var(--line); background: var(--panel); }}
  main {{ padding: 20px 28px 48px; max-width: 1100px; }}
  .flash {{
    background: #243018; border: 1px solid #3d5a28; color: #cfe3b8;
    padding: 10px 14px; border-radius: 8px;
  }}
  .err {{
    background: #2a1515; border: 1px solid #5a2828; color: #e3b8b8;
    padding: 10px 14px; border-radius: 8px;
  }}
  .cards {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)); gap: 12px; }}
  .card {{
    background: var(--panel); border: 1px solid var(--line); border-radius: 10px; padding: 14px 16px;
  }}
  .card .k {{ color: var(--muted); font-size: 12px; }}
  .card .v {{ font-size: 18px; margin-top: 4px; }}
  .ok {{ color: #8dcf7a; }} .bad {{ color: #e08888; }}
  table {{
    width: 100%; border-collapse: collapse; background: var(--panel);
    border: 1px solid var(--line); border-radius: 10px; overflow: hidden;
  }}
  th, td {{ padding: 8px 10px; text-align: left; border-bottom: 1px solid var(--line); vertical-align: top; }}
  th {{ color: var(--muted); font-weight: 600; font-size: 12px; }}
  tr:last-child td {{ border-bottom: none; }}
  form.inline {{ display: inline; }}
  form.stack {{ display: grid; gap: 10px; max-width: 420px; margin: 16px 0; }}
  label {{ display: grid; gap: 4px; color: var(--muted); font-size: 12px; }}
  input, select, textarea, button {{
    font: inherit; color: var(--text); background: #0d1018; border: 1px solid var(--line);
    border-radius: 6px; padding: 8px 10px;
  }}
  textarea {{ width: 100%; min-height: 100px; font-family: ui-monospace, Menlo, monospace; }}
  button, .btn {{
    cursor: pointer; background: linear-gradient(#3a3020, #2a2216); border-color: #6a5428;
    color: var(--gold); font-weight: 600;
  }}
  button.danger {{ background: #3a1818; border-color: #6a2828; color: #e08888; }}
  .row {{ display: flex; gap: 10px; flex-wrap: wrap; align-items: end; }}
  .muted {{ color: var(--muted); }}
  pre.sql {{
    background: #0d1018; border: 1px solid var(--line); padding: 12px; border-radius: 8px;
    overflow: auto; font-size: 12px;
  }}
  a {{ color: var(--gold); }}
</style>
</head>
<body>
<header>
  <h1>Soloroth</h1>
  <span class="sub">本地管理 · 127.0.0.1 · 无鉴权</span>
</header>
{nav}
<main>
{flash_html}
{body}
</main>
</body>
</html>
"""
    # Fix accidental typo in CSS if any
    return doc.encode("utf-8")


def status_body() -> str:
    maria = port_open(3306)
    realm = port_open(3724)
    world = port_open(8085)
    mangosd = process_running("mangosd")
    realmd = process_running("realmd")
    realm_name = sql_scalar("classic_realmd", "SELECT name FROM realmlist WHERE id=1 LIMIT 1") or "—"
    accounts = sql_scalar("classic_realmd", "SELECT COUNT(*) FROM account") or "—"
    chars = sql_scalar("classic_characters", "SELECT COUNT(*) FROM characters") or "—"

    def pill(ok: bool, yes: str = "在线", no: str = "离线") -> str:
        cls = "ok" if ok else "bad"
        return f'<span class="{cls}">{yes if ok else no}</span>'

    return f"""
    <div class="cards">
      <div class="card"><div class="k">MariaDB :3306</div><div class="v">{pill(maria)}</div></div>
      <div class="card"><div class="k">realmd</div><div class="v">{pill(realmd and realm)}</div></div>
      <div class="card"><div class="k">mangosd</div><div class="v">{pill(mangosd and world)}</div></div>
      <div class="card"><div class="k">Realm</div><div class="v">{html.escape(realm_name)}</div></div>
      <div class="card"><div class="k">账号数</div><div class="v">{html.escape(accounts)}</div></div>
      <div class="card"><div class="k">角色数</div><div class="v">{html.escape(chars)}</div></div>
    </div>
    <p class="muted" style="margin-top:18px">建号 / 改 GM 需要 mangosd 在跑（写控制台）。浏览库只需 MariaDB。</p>
    """


def accounts_body(flash: str = "") -> tuple[str, str]:
    cols, rows, err = sql_query(
        "classic_realmd",
        """SELECT a.id, a.username, COALESCE(aa.gmlevel, a.gmlevel) AS gm,
                  a.email, a.joindate, a.last_login, a.online
           FROM account a
           LEFT JOIN account_access aa ON aa.id = a.id AND aa.RealmID IN (1, -1)
           ORDER BY a.id""",
    )
    if err:
        return f'<p class="err">{html.escape(err)}</p>', flash
    rows_html = []
    for r in rows:
        while len(r) < 7:
            r.append("")
        aid, user, gm, email, joined, last, online = r[:7]
        rows_html.append(
            f"""<tr>
            <td>{html.escape(aid)}</td>
            <td>{html.escape(user)}</td>
            <td>{html.escape(gm)}</td>
            <td>{html.escape(email)}</td>
            <td>{html.escape(joined)}</td>
            <td>{html.escape(last)}</td>
            <td>{html.escape(online)}</td>
            <td>
              <form class="inline" method="post" action="/accounts/gm">
                <input type="hidden" name="name" value="{html.escape(user, quote=True)}">
                <input name="level" value="{html.escape(gm, quote=True)}" size="2" style="width:3em">
                <button type="submit">设 GM</button>
              </form>
            </td>
            </tr>"""
        )
    table = f"""
    <h2>账号</h2>
    <table>
      <tr><th>ID</th><th>用户名</th><th>GM</th><th>邮箱</th><th>创建</th><th>上次登录</th><th>在线</th><th></th></tr>
      {''.join(rows_html) or '<tr><td colspan="8" class="muted">暂无账号</td></tr>'}
    </table>
    <h3 style="margin-top:24px">新建账号</h3>
    <form class="stack" method="post" action="/accounts/create">
      <label>用户名 <input name="name" required maxlength="32" autocomplete="off"></label>
      <label>密码 <input name="pass" type="password" required autocomplete="new-password"></label>
      <label><input type="checkbox" name="gm" value="1"> GM（level 6）</label>
      <button type="submit">创建</button>
    </form>
    """
    return table, flash


def characters_body() -> str:
    cols, rows, err = sql_query(
        "classic_characters",
        """SELECT c.guid, c.name, a.username, c.level, c.money, c.map, c.zone, c.online
           FROM characters c
           LEFT JOIN classic_realmd.account a ON a.id = c.account
           ORDER BY c.guid""",
    )
    if err:
        # Cross-db join may fail on some setups; fall back.
        cols, rows, err = sql_query(
            "classic_characters",
            """SELECT guid, name, account, level, money, map, zone, online
               FROM characters ORDER BY guid""",
        )
        if err:
            return f'<p class="err">{html.escape(err)}</p>'
    rows_html = []
    for r in rows:
        while len(r) < 8:
            r.append("")
        guid, name, acct, level, money, mmap, zone, online = r[:8]
        try:
            gold = int(money) // 10000
            silver = (int(money) % 10000) // 100
            copper = int(money) % 100
            money_s = f"{gold}g {silver}s {copper}c"
        except ValueError:
            money_s = money
        rows_html.append(
            f"""<tr>
            <td>{html.escape(guid)}</td>
            <td>{html.escape(name)}</td>
            <td>{html.escape(acct)}</td>
            <td>{html.escape(level)}</td>
            <td>{html.escape(money_s)}</td>
            <td>{html.escape(mmap)}</td>
            <td>{html.escape(zone)}</td>
            <td>{html.escape(online)}</td>
            <td>
              <form class="inline" method="post" action="/characters/delete"
                    onsubmit="return confirm('确认删除角色 {html.escape(name, quote=True)}？');">
                <input type="hidden" name="guid" value="{html.escape(guid, quote=True)}">
                <button type="submit" class="danger">删除</button>
              </form>
            </td>
            </tr>"""
        )
    return f"""
    <h2>角色</h2>
    <table>
      <tr><th>GUID</th><th>名</th><th>账号</th><th>等级</th><th>金钱</th><th>地图</th><th>区域</th><th>在线</th><th></th></tr>
      {''.join(rows_html) or '<tr><td colspan="9" class="muted">暂无角色</td></tr>'}
    </table>
    <p class="muted">删除只清 characters 主表行；角色在线时可能立刻被服写回。尽量在角色离线时删。</p>
    """


def db_body(qs: dict[str, list[str]]) -> str:
    db = (qs.get("db") or ["classic_realmd"])[0]
    if db not in ALLOWED_DBS:
        db = "classic_realmd"
    table = (qs.get("table") or [""])[0]
    page_n = 1
    try:
        page_n = max(1, int((qs.get("page") or ["1"])[0]))
    except ValueError:
        page_n = 1
    per = 50
    offset = (page_n - 1) * per

    opts = "".join(
        f'<option value="{d}"{" selected" if d == db else ""}>{d}</option>' for d in ALLOWED_DBS
    )
    tables_out = ""
    code, out, err = mariadb(
        database=db,
        sql="SHOW TABLES;",
    )
    table_names: list[str] = []
    if code == 0:
        table_names = [ln.strip() for ln in out.splitlines() if ln.strip()]
    else:
        tables_out = f'<p class="err">{html.escape(err or out)}</p>'

    links = " · ".join(
        f'<a href="/db?db={urllib.parse.quote(db)}&table={urllib.parse.quote(t)}">{html.escape(t)}</a>'
        for t in table_names
    )
    browse = ""
    if table and IDENT.match(table):
        cols, rows, qerr = sql_query(
            db,
            f"SELECT * FROM `{table}` LIMIT {per} OFFSET {offset}",
        )
        if qerr:
            browse = f'<p class="err">{html.escape(qerr)}</p>'
        else:
            head = "".join(f"<th>{html.escape(c)}</th>" for c in cols)
            body_rows = []
            for r in rows:
                cells = "".join(f"<td>{html.escape(c)}</td>" for c in r)
                body_rows.append(f"<tr>{cells}</tr>")
            prev = (
                f'<a href="/db?db={urllib.parse.quote(db)}&table={urllib.parse.quote(table)}&page={page_n - 1}">上一页</a>'
                if page_n > 1
                else ""
            )
            nxt = (
                f'<a href="/db?db={urllib.parse.quote(db)}&table={urllib.parse.quote(table)}&page={page_n + 1}">下一页</a>'
                if len(rows) == per
                else ""
            )
            browse = f"""
            <h3>{html.escape(table)} <span class="muted">第 {page_n} 页</span></h3>
            <p>{prev} {nxt}</p>
            <table><tr>{head}</tr>{''.join(body_rows) or '<tr><td class="muted">空</td></tr>'}</table>
            """
    elif table:
        browse = '<p class="err">非法表名</p>'

    return f"""
    <h2>数据库</h2>
    <form class="row" method="get" action="/db">
      <label>库
        <select name="db" onchange="this.form.submit()">{opts}</select>
      </label>
    </form>
    {tables_out}
    <p class="muted" style="margin:12px 0">{links or '（无表）'}</p>
    {browse}
    <h3 style="margin-top:28px">SQL</h3>
    <form class="stack" method="post" action="/db/sql" style="max-width:100%">
      <input type="hidden" name="db" value="{html.escape(db, quote=True)}">
      <label>在 {html.escape(db)} 执行
        <textarea name="sql" placeholder="SELECT …" required></textarea>
      </label>
      <label><input type="checkbox" name="confirm_write" value="1"> 确认执行写操作（INSERT/UPDATE/DELETE…）</label>
      <button type="submit">运行</button>
    </form>
    """


def create_account(name: str, password: str, gm: bool) -> str:
    name = name.strip()
    if not name or not password:
        return "账号和密码不能为空"
    if not process_running("mangosd") or not FIFO.is_fifo():
        return "服务器未运行（需要 mangosd 与 mangosd.stdin）"
    script = ROOT / "tools" / "macos" / "create-account.sh"
    args = [str(script), name, password]
    if gm:
        args.append("gm")
    proc = subprocess.run(args, capture_output=True, text=True, check=False)
    msg = (proc.stdout or proc.stderr or "").strip() or f"exit {proc.returncode}"
    return msg


def set_gm(name: str, level: str) -> str:
    name = name.strip()
    try:
        lvl = int(level)
    except ValueError:
        return "GM 等级必须是数字"
    if lvl < 0 or lvl > 6:
        return "GM 等级应在 0–6"
    if not process_running("mangosd") or not FIFO.is_fifo():
        return "服务器未运行"
    before = 0
    out_log = ROOT / "server" / "logs" / "mangosd.out"
    if out_log.is_file():
        before = sum(1 for _ in out_log.open("rb"))
    with FIFO.open("w") as f:
        f.write(f"account set gmlevel {name} {lvl}\n")
    return f"已发送: account set gmlevel {name} {lvl}（见 mangosd.out 约第 {before}+ 行）"


def delete_character(guid: str) -> str:
    if not guid.isdigit():
        return "无效 GUID"
    online = sql_scalar("classic_characters", f"SELECT online FROM characters WHERE guid={guid}")
    if online == "1":
        return "角色在线，请先下线再删"
    code, out, err = mariadb(
        database="classic_characters",
        sql=f"DELETE FROM characters WHERE guid={guid};",
    )
    if code != 0:
        return (err or out or "delete failed").strip()
    return f"已删除 guid={guid}"


def run_sql(db: str, sql: str, confirm_write: bool) -> str:
    sql = sql.strip()
    if not sql:
        return "空 SQL"
    if db not in ALLOWED_DBS:
        return "库不允许"
    if WRITE_HINT.search(sql) and not confirm_write:
        return "写操作需要勾选确认"
    cols, rows, err = sql_query(db, sql)
    if err:
        return f"错误: {err}"
    if not cols:
        return "完成（无结果集）"
    head = "\t".join(cols)
    body = "\n".join("\t".join(r) for r in rows[:500])
    more = f"\n…共 {len(rows)} 行" if len(rows) > 500 else ""
    return f"{head}\n{body}{more}" if body else head


class Handler(BaseHTTPRequestHandler):
    server_version = "SolorothAdmin/1.0"

    def log_message(self, fmt: str, *args) -> None:
        sys.stderr.write("admin: " + (fmt % args) + "\n")

    def _send(self, code: int, body: bytes, content_type: str = "text/html; charset=utf-8") -> None:
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _redirect(self, loc: str) -> None:
        self.send_response(303)
        self.send_header("Location", loc)
        self.end_headers()

    def _read_form(self) -> dict[str, str]:
        length = int(self.headers.get("Content-Length", "0") or 0)
        raw = self.rfile.read(length) if length else b""
        parsed = urllib.parse.parse_qs(raw.decode("utf-8", errors="replace"), keep_blank_values=True)
        return {k: (v[0] if v else "") for k, v in parsed.items()}

    def do_GET(self) -> None:
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        qs = urllib.parse.parse_qs(parsed.query)
        flash = (qs.get("flash") or [""])[0]

        if path == "/":
            self._send(200, page("概览", status_body(), flash))
        elif path == "/accounts":
            body, fl = accounts_body(flash)
            self._send(200, page("账号", body, fl))
        elif path == "/characters":
            self._send(200, page("角色", characters_body(), flash))
        elif path == "/db":
            self._send(200, page("数据库", db_body(qs), flash))
        elif path == "/health":
            self._send(200, b"ok\n", "text/plain; charset=utf-8")
        else:
            self._send(404, page("未找到", "<p class=\"err\">404</p>"))

    def do_POST(self) -> None:
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        form = self._read_form()

        if path == "/accounts/create":
            msg = create_account(form.get("name", ""), form.get("pass", ""), form.get("gm") == "1")
            self._redirect("/accounts?flash=" + urllib.parse.quote(msg))
        elif path == "/accounts/gm":
            msg = set_gm(form.get("name", ""), form.get("level", "0"))
            self._redirect("/accounts?flash=" + urllib.parse.quote(msg))
        elif path == "/characters/delete":
            msg = delete_character(form.get("guid", ""))
            self._redirect("/characters?flash=" + urllib.parse.quote(msg))
        elif path == "/db/sql":
            msg = run_sql(form.get("db", ""), form.get("sql", ""), form.get("confirm_write") == "1")
            body = f'<h2>SQL 结果</h2><pre class="sql">{html.escape(msg)}</pre><p><a href="/db?db={urllib.parse.quote(form.get("db", ""))}">返回</a></p>'
            self._send(200, page("SQL", body))
        else:
            self._send(404, page("未找到", "<p class=\"err\">404</p>"))


def main() -> None:
    port = PORT
    args = sys.argv[1:]
    if args and args[0] == "--port":
        port = int(args[1])
    elif args:
        die(f"usage: {sys.argv[0]} [--port {PORT}]")

    # Refuse non-loopback binding by construction.
    httpd = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    print(f"admin listening on http://127.0.0.1:{port}", flush=True)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nadmin stopped", flush=True)


if __name__ == "__main__":
    main()
