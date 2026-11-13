#!/usr/bin/env python3
# Checks an account name and password against the local realmd database the
# way realmd does (SRP6, salt s and verifier v in classic_realmd.account),
# without logging in. Reads the name and password from stdin, one per line.
#
#   printf '%s\n%s\n' NAME PASS | tools/macos/check-login.py
#
# Exit 0: they match; 1: wrong password; 2: no such account.
import hashlib
import os
import subprocess
import sys

N = int("894B645E89E1535BBDAD5B8B290650530801B18EBFBF5E8FAB3C82872A3E9BB7", 16)
G = 7

root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
lines = sys.stdin.read().split("\n")
name, password = lines[0].strip().upper(), (lines[1] if len(lines) > 1 else "").upper()
if not name or "'" in name or "\\" in name:
    sys.exit(2)

row = subprocess.run(
    [os.path.join(root, "server/mariadb/bin/mariadb"), "-h127.0.0.1", "-uroot", "--skip-ssl",
     "-N", "-B", "classic_realmd", "-e", f"SELECT s, v FROM account WHERE username = '{name}'"],
    capture_output=True, text=True, check=True,
).stdout.split()
if len(row) != 2:
    sys.exit(2)
salt, verifier = (int(h, 16) for h in row)

inner = hashlib.sha1(f"{name}:{password}".encode()).digest()
x = int.from_bytes(hashlib.sha1(salt.to_bytes(32, "little") + inner).digest(), "little")
sys.exit(0 if pow(G, x, N) == verifier else 1)
