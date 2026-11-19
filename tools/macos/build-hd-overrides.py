#!/usr/bin/env python3
"""Build a small MPQ that puts Ghamoo-ra (CreatureDisplayInfo 5027) back on the
ordinary SeaTurtle model when a Reforged/HD patch-C is mounted.

Project Reforged's patch-C remaps 5027 to AncientSeaTurtle, which benilla draws
as a black box. Display 5026 (Aku'mai Snapjaw) still uses SeaTurtleSkinRed and
is the donor for model id and texture string offsets.

    tools/macos/build-hd-overrides.py <source-CDI.dbc|source.MPQ> <out.MPQ>
    tools/macos/build-hd-overrides.py --from-data <Data/> <out.MPQ>

Exit 0 with no output file when 5027 is already on SeaTurtle (nothing to fix).
"""
from __future__ import print_function

import os
import struct
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CDI_NAME = "DBFilesClient\\CreatureDisplayInfo.dbc"
DISPLAY_ID = 5027
DONOR_ID = 5026  # same skin, model 173
SEA_TURTLE_MODEL = 173

# Minimal MPQ writer (stored, unencrypted), same layout as tools/glue-skin/build-patch.py.
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


def read_cdi_bytes(source):
    if source.lower().endswith(".dbc"):
        with open(source, "rb") as f:
            return f.read()
    mpqcat = find_mpqcat()
    if mpqcat is None:
        sys.exit("mpqcat not built (cargo build --release -p benilla-mpq --example mpqcat)")
    proc = subprocess.run(
        [mpqcat, source, CDI_NAME],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if proc.returncode != 0 or not proc.stdout:
        sys.exit("no %s in %s" % (CDI_NAME, source))
    return proc.stdout


def cdi_from_data_dir(data_dir):
    """Highest-priority patch-?.MPQ that holds CreatureDisplayInfo, then patch.MPQ / dbc.MPQ."""
    names = os.listdir(data_dir)
    patches = sorted(
        (
            n
            for n in names
            if n.lower().startswith("patch-")
            and n.lower().endswith(".mpq")
            and len(n) == len("patch-?.mpq")
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
            [mpqcat, path, CDI_NAME],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        if proc.returncode == 0 and proc.stdout[:4] == b"WDBC":
            return proc.stdout, path
    sys.exit("no %s under %s" % (CDI_NAME, data_dir))


def fix_cdi(data):
    """Return (fixed_bytes, changed). Vanilla CDI: 12×uint32 fields, scale is float at +16."""
    if data[:4] != b"WDBC":
        sys.exit("not a WDBC")
    records, fields, record_size, _ = struct.unpack_from("<IIII", data, 4)
    if fields < 8 or record_size < 32:
        sys.exit("unexpected CreatureDisplayInfo layout: fields=%d rs=%d" % (fields, record_size))
    header = 20
    donor = None
    target = None
    for i in range(records):
        off = header + i * record_size
        row_id = struct.unpack_from("<I", data, off)[0]
        if row_id == DONOR_ID:
            donor = off
        elif row_id == DISPLAY_ID:
            target = off
    if target is None:
        sys.exit("CreatureDisplayInfo has no row %d" % DISPLAY_ID)
    if donor is None:
        sys.exit("CreatureDisplayInfo has no donor row %d" % DONOR_ID)

    model = struct.unpack_from("<I", data, target + 4)[0]
    # textureVariation[3] live at +24,+28,+32 in the 1.12 / Reforged 12-field layout
    tex0 = struct.unpack_from("<I", data, target + 24)[0]
    donor_model = struct.unpack_from("<I", data, donor + 4)[0]
    donor_tex0 = struct.unpack_from("<I", data, donor + 24)[0]
    if donor_model != SEA_TURTLE_MODEL:
        sys.exit("donor %d is not SeaTurtle (model %d)" % (DONOR_ID, donor_model))

    if model == SEA_TURTLE_MODEL and tex0 == donor_tex0:
        return data, False

    out = bytearray(data)
    struct.pack_into("<I", out, target + 4, SEA_TURTLE_MODEL)
    # Keep 5027's own scale (1.5); only borrow model + skin name from 5026.
    struct.pack_into("<I", out, target + 24, donor_tex0)
    struct.pack_into("<I", out, target + 28, struct.unpack_from("<I", data, donor + 28)[0])
    struct.pack_into("<I", out, target + 32, struct.unpack_from("<I", data, donor + 32)[0])
    return bytes(out), True


def main():
    args = sys.argv[1:]
    if len(args) == 3 and args[0] == "--from-data":
        data_dir, out_path = args[1], args[2]
        raw, source = cdi_from_data_dir(data_dir)
        print("hd-overrides: CDI from %s" % source)
    elif len(args) == 2:
        raw = read_cdi_bytes(args[0])
        out_path = args[1]
    else:
        sys.exit(__doc__.strip())

    fixed, changed = fix_cdi(raw)
    if not changed:
        if os.path.exists(out_path):
            os.remove(out_path)
            print("hd-overrides: 5027 already SeaTurtle; removed %s" % out_path)
        else:
            print("hd-overrides: 5027 already SeaTurtle; nothing to write")
        return

    listfile = (CDI_NAME + "\r\n(listfile)\r\n").encode("latin-1")
    write_mpq(out_path, [(CDI_NAME, fixed), ("(listfile)", listfile)])
    print("hd-overrides: wrote %s (display %d → SeaTurtle model %d)" % (out_path, DISPLAY_ID, SEA_TURTLE_MODEL))


if __name__ == "__main__":
    main()
