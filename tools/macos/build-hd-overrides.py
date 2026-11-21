#!/usr/bin/env python3
"""Build Data/patch-V.MPQ: fix Reforged/HD CreatureModelData rows whose
ModelScale is 0 so benilla will draw them.

benilla only builds a creature display when
`CreatureModelData.modelScale * CreatureDisplayInfo.creatureModelScale > 0`
(see new_creature_display). Project Reforged's patch-C ships several models —
including AncientSeaTurtle used by Ghamoo-ra (display 5027) — with ModelScale
0, which becomes the black debug cube in-world.

    tools/macos/build-hd-overrides.py <source.MPQ|CMD.dbc> <out.MPQ>
    tools/macos/build-hd-overrides.py --from-data <Data/> <out.MPQ>

Exit 0 with no output file when every ModelScale is already > 0.
"""
from __future__ import print_function

import os
import struct
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CMD_NAME = "DBFilesClient\\CreatureModelData.dbc"
# ModelScale is field 4 (byte offset 16) in the 1.12 / Reforged 16-field layout.
MODEL_SCALE_OFF = 16
DEFAULT_SCALE = 1.0

FLAG_EXISTS = 0x80000000


def _crypt_table():
    table = [0] * 0x500
    seed = 0x00100001
    for i in range(0x100):
        idx = i
        for _ in range(5):
            seed = (seed * 125 + 3) % 0x2AAAAB
            hi = (seed & 0xFFFF) << 16
            seed = (seed * 125 + 3) % 0x2AAAAB
            table[idx] = hi | (seed & 0xFFFF)
            idx += 0x100
    return table


CRYPT = _crypt_table()


def hash_string(name, kind):
    s1, s2 = 0x7FED7FED, 0xEEEEEEEE
    for ch in name.upper().replace("/", "\\").encode("latin-1"):
        s1 = (CRYPT[kind * 0x100 + ch] ^ (s1 + s2)) & 0xFFFFFFFF
        s2 = (ch + s1 + s2 + (s2 << 5) + 3) & 0xFFFFFFFF
    return s1


def _crypt(data, key, encrypt):
    words = struct.unpack("<%dI" % (len(data) // 4), data)
    out = []
    s2 = 0xEEEEEEEE
    for word in words:
        s2 = (s2 + CRYPT[0x400 + (key & 0xFF)]) & 0xFFFFFFFF
        result = word ^ ((key + s2) & 0xFFFFFFFF)
        plain = word if encrypt else result
        out.append(result)
        key = (((~key << 0x15) & 0xFFFFFFFF) + 0x11111111 | (key >> 0x0B)) & 0xFFFFFFFF
        s2 = (plain + s2 + (s2 << 5) + 3) & 0xFFFFFFFF
    return struct.pack("<%dI" % len(out), *out)


def write_mpq(path, files):
    hash_count = 16
    while hash_count < len(files) * 2:
        hash_count *= 2
    header_size = 32
    body = b""
    blocks = []
    for name, content in files:
        blocks.append((header_size + len(body), len(content), len(content), FLAG_EXISTS))
        body += content
    hashes = [(0xFFFFFFFF, 0xFFFFFFFF, 0xFFFF, 0xFFFF, 0xFFFFFFFF)] * hash_count
    for index, (name, _) in enumerate(files):
        i = hash_string(name, 0) % hash_count
        while hashes[i][4] != 0xFFFFFFFF:
            i = (i + 1) % hash_count
        hashes[i] = (hash_string(name, 1), hash_string(name, 2), 0, 0, index)
    hash_table = b"".join(struct.pack("<IIHHI", *h) for h in hashes)
    block_table = b"".join(struct.pack("<IIII", *b) for b in blocks)
    hash_pos = header_size + len(body)
    block_pos = hash_pos + len(hash_table)
    total = block_pos + len(block_table)
    header = struct.pack(
        "<4sIIHHIIII",
        b"MPQ\x1a",
        header_size,
        total,
        0,
        3,
        hash_pos,
        block_pos,
        hash_count,
        len(blocks),
    )
    tmp = path + ".tmp"
    with open(tmp, "wb") as f:
        f.write(
            header
            + body
            + _crypt(hash_table, hash_string("(hash table)", 3), True)
            + _crypt(block_table, hash_string("(block table)", 3), True)
        )
    os.replace(tmp, path)


def find_mpqcat():
    candidates = [
        os.path.join(ROOT, "release/build/macos/client-target/release/examples/mpqcat"),
        os.path.join(ROOT, "client/target/release/examples/mpqcat"),
    ]
    for c in candidates:
        if os.path.isfile(c) and os.access(c, os.X_OK):
            return c
    return None


def read_cmd_bytes(source):
    if source.lower().endswith(".dbc"):
        with open(source, "rb") as f:
            return f.read()
    mpqcat = find_mpqcat()
    if mpqcat is None:
        sys.exit("mpqcat not built (cargo build --release -p benilla-mpq --example mpqcat)")
    proc = subprocess.run(
        [mpqcat, source, CMD_NAME],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if proc.returncode != 0 or not proc.stdout:
        sys.exit("no %s in %s" % (CMD_NAME, source))
    return proc.stdout


def cmd_from_data_dir(data_dir):
    """Highest-priority patch that holds CreatureModelData, then patch.MPQ / dbc.MPQ.

    Skip our own patch-V so a remount always re-reads the Reforged/HD source.
    """
    names = os.listdir(data_dir)
    patches = sorted(
        (
            n
            for n in names
            if n.lower().startswith("patch-")
            and n.lower().endswith(".mpq")
            and len(n) == len("patch-?.mpq")
            and n.lower() != "patch-v.mpq"
        ),
        key=str.lower,
        reverse=True,
    )
    order = patches + [n for n in names if n.lower() in ("patch.mpq", "dbc.mpq")]
    mpqcat = find_mpqcat()
    if mpqcat is None:
        sys.exit("mpqcat not built")
    for name in order:
        path = os.path.join(data_dir, name)
        proc = subprocess.run(
            [mpqcat, path, CMD_NAME],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        if proc.returncode == 0 and proc.stdout[:4] == b"WDBC":
            return proc.stdout, path
    sys.exit("no %s under %s" % (CMD_NAME, data_dir))


def fix_cmd(data):
    """Return (fixed_bytes, list of (id, path) repaired)."""
    if data[:4] != b"WDBC":
        sys.exit("not a WDBC")
    records, fields, record_size, _ = struct.unpack_from("<IIII", data, 4)
    if fields < 5 or record_size < 20:
        sys.exit("unexpected CreatureModelData layout: fields=%d rs=%d" % (fields, record_size))
    strings = data[20 + records * record_size :]

    def sget(off):
        if not off:
            return ""
        end = strings.find(b"\0", off)
        return strings[off:end].decode("latin-1", "replace")

    out = bytearray(data)
    fixed = []
    for i in range(records):
        off = 20 + i * record_size
        mid = struct.unpack_from("<I", data, off)[0]
        scale = struct.unpack_from("<f", data, off + MODEL_SCALE_OFF)[0]
        if scale > 0.0:
            continue
        path_off = struct.unpack_from("<I", data, off + 8)[0]
        struct.pack_into("<f", out, off + MODEL_SCALE_OFF, DEFAULT_SCALE)
        fixed.append((mid, sget(path_off)))
    return bytes(out), fixed


def main():
    args = sys.argv[1:]
    if len(args) == 3 and args[0] == "--from-data":
        data_dir, out_path = args[1], args[2]
        raw, source = cmd_from_data_dir(data_dir)
        print("hd-overrides: CMD from %s" % source)
    elif len(args) == 2:
        raw = read_cmd_bytes(args[0])
        out_path = args[1]
    else:
        sys.exit(__doc__.strip())

    fixed, repaired = fix_cmd(raw)
    if not repaired:
        if os.path.exists(out_path):
            os.remove(out_path)
            print("hd-overrides: no zero ModelScale rows; removed %s" % out_path)
        else:
            print("hd-overrides: no zero ModelScale rows; nothing to write")
        return

    listfile = (CMD_NAME + "\r\n(listfile)\r\n").encode("latin-1")
    write_mpq(out_path, [(CMD_NAME, fixed), ("(listfile)", listfile)])
    print(
        "hd-overrides: wrote %s (%d ModelScale 0→%.1f)"
        % (out_path, len(repaired), DEFAULT_SCALE)
    )
    for mid, path in repaired:
        print("  model %d %s" % (mid, path or "?"))


if __name__ == "__main__":
    main()
