#!/bin/bash
# Starts MariaDB (if needed), realmd, and mangosd. Daemons are double-forked into
# their own session so a parent Process (Soloroth.app's Launcher, an agent shell)
# exiting cannot take them down. A holder keeps each CLI FIFO's write end open:
# mangosd treats stdin EOF as "server shutdown 0".
#
#   tools/macos/start-server.sh
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
run="$root/server/run"
logs="$root/server/logs"
maria="$(cd "$root/server/mariadb" && pwd -P)"
data="$root/server/mariadb-data"
cfg="$root/config/mariadb.ini"
mkdir -p "$logs"

if ! "$maria/bin/mariadb" -h127.0.0.1 -P3306 -uroot --skip-ssl -e 'SELECT 1' >/dev/null 2>&1; then
    echo "starting mariadbd"
    nohup "$maria/bin/mariadbd" --defaults-file="$cfg" --basedir="$maria" --datadir="$data" --port=3306 \
        --socket="$logs/mysql.sock" \
        --pid-file="$logs/mariadb.pid" --log-error="$logs/mariadb.err" >/dev/null 2>&1 &
    for i in $(seq 1 60); do
        "$maria/bin/mariadb" -h127.0.0.1 -P3306 -uroot --skip-ssl -e 'SELECT 1' >/dev/null 2>&1 && break
        sleep 1
    done
fi

new_fifo() {
    rm -f "$1"
    mkfifo "$1"
}

# spawn_daemon <name> <fifo> <logfile> <cwd> <argv...>
# Detaches into a new session, holds the fifo write end, execs the daemon with
# stdin on the fifo. Writes <name>.pid under $logs.
spawn_daemon() {
    local name="$1" fifo="$2" out="$3" cwd="$4"
    shift 4
    new_fifo "$fifo"
    python3 - "$name" "$fifo" "$out" "$logs" "$cwd" "$@" <<'PY'
import os, sys, time, pathlib

name, fifo, out, logs, cwd = sys.argv[1:6]
cmd = sys.argv[6:]

if os.fork() > 0:
    sys.exit(0)
os.setsid()
if os.fork() > 0:
    sys.exit(0)

# Writer held for the daemon's life so fgets never sees EOF from a closed partner.
hold = os.open(fifo, os.O_RDWR)
pid = os.fork()
if pid == 0:
    rd = os.open(fifo, os.O_RDONLY)
    os.dup2(rd, 0)
    if rd > 2:
        os.close(rd)
    fdout = os.open(out, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o644)
    os.dup2(fdout, 1)
    os.dup2(fdout, 2)
    if fdout > 2:
        os.close(fdout)
    # Drop the inherited writer in the daemon; the holder keeps it.
    try:
        os.close(hold)
    except OSError:
        pass
    os.chdir(cwd)
    os.execv(cmd[0], cmd)

pathlib.Path(logs, f"{name}.pid").write_text(str(pid) + "\n")
pathlib.Path(logs, f"{name}.holder.pid").write_text(str(os.getpid()) + "\n")
while True:
    try:
        os.kill(pid, 0)
    except OSError:
        break
    time.sleep(1)
try:
    os.close(hold)
except OSError:
    pass
try:
    pathlib.Path(logs, f"{name}.holder.pid").unlink(missing_ok=True)
except OSError:
    pass
PY
}

if ! lsof -nP -iTCP:3724 -sTCP:LISTEN >/dev/null 2>&1; then
    echo "starting realmd"
    spawn_daemon realmd "$logs/realmd.stdin" "$logs/realmd.out" "$run" \
        "$run/realmd" -c realmd.conf
fi

if ! lsof -nP -iTCP:8085 -sTCP:LISTEN >/dev/null 2>&1; then
    echo "starting mangosd"
    spawn_daemon mangosd "$logs/mangosd.stdin" "$logs/mangosd.out" "$run" \
        "$run/mangosd" -c mangosd.conf
fi

for i in $(seq 1 120); do
    r=0; w=0
    lsof -nP -iTCP:3724 -sTCP:LISTEN >/dev/null 2>&1 && r=1
    lsof -nP -iTCP:8085 -sTCP:LISTEN >/dev/null 2>&1 && w=1
    if [ "$r$w" = 11 ]; then
        echo "server ready on 127.0.0.1 (auth 3724, world 8085)"
        exit 0
    fi
    sleep 1
done
echo "server failed to become ready" >&2
tail -50 "$logs/mangosd.out" >&2 || true
exit 1
