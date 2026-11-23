#!/usr/bin/env python3
"""Build Data/patch-T.MPQ with a Spell.dbc where enchant crafts CreateItem scrolls.

    tools/enchant-scrolls/build-patch.py [DATA_DIR] [--remove]

Reads tools/enchant-scrolls/map.json (from gen-enchant-scrolls.py). Extracts the
current Spell.dbc from the patch chain (never from patch-T itself), flips each
craft spell to effect 24 + scroll item, and appends oil-style apply spells.
"""
from __future__ import annotations

import json
import os
import struct
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
PATCH = "patch-T.MPQ"
SPELL_PATH = "DBFilesClient\\Spell.dbc"
MAP_PATH = os.path.join(HERE, "map.json")

# Spell.dbc column indices (benilla-formats spells/mod.rs).
COL_ID = 0
COL_ATTRIBUTES = 6
COL_TARGETS = 13
COL_CASTING_TIME = 18
COL_REAGENT_1 = 42
COL_REAGENT_COUNT_1 = 50
COL_EQUIPPED_CLASS = 58
COL_EQUIPPED_SUB = 59
COL_EQUIPPED_INV = 60
COL_EFFECT_1 = 61
COL_EFFECT_ITEM_1 = 103
COL_EFFECT_MISC_1 = 106
COL_MANA_COST = 32

SPELL_EFFECT_CREATE_ITEM = 24
SPELL_ATTR_ITEM_ENCHANT = 262144  # like Wizard Oil use
CAST_INSTANT = 14

FLAG_EXISTS = 0x80000000
FLAG_COMPRESS = 0x00000200
FLAG_ENCRYPTED = 0x00010000
FLAG_SINGLE_UNIT = 0x01000000


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


def read_file(path, name):
    with open(path, "rb") as f:
        data = f.read()
    base = data.find(b"MPQ\x1a")
    if base < 0:
        return None
    _, _, _, shift, hash_pos, block_pos, hash_count, block_count = struct.unpack_from(
        "<IIHHIIII", data, base + 4)
    hashes = _crypt(data[base + hash_pos:base + hash_pos + hash_count * 16],
                    hash_string("(hash table)", 3), False)
    blocks = _crypt(data[base + block_pos:base + block_pos + block_count * 16],
                    hash_string("(block table)", 3), False)
    a, b = hash_string(name, 1), hash_string(name, 2)
    i = hash_string(name, 0) % hash_count
    for _ in range(hash_count):
        ha, hb, _, _, index = struct.unpack_from("<IIHHI", hashes, i * 16)
        if index == 0xFFFFFFFF:
            return None
        if ha == a and hb == b and index < block_count:
            break
        i = (i + 1) % hash_count
    else:
        return None
    pos, packed, size, flags = struct.unpack_from("<IIII", blocks, index * 16)
    if not flags & FLAG_EXISTS:
        return None
    if flags & (FLAG_ENCRYPTED | FLAG_SINGLE_UNIT):
        sys.exit("%s: %s is stored in a way this builder does not read" % (path, name))
    start = base + pos
    if not flags & FLAG_COMPRESS:
        return data[start:start + size]
    sector = 512 << shift
    count = (size + sector - 1) // sector
    offsets = struct.unpack_from("<%dI" % (count + 1), data, start)
    out = b""
    for n in range(count):
        chunk = data[start + offsets[n]:start + offsets[n + 1]]
        want = min(sector, size - n * sector)
        if len(chunk) == want:
            out += chunk
        elif chunk[0] == 0x02:
            out += zlib.decompress(chunk[1:])
        else:
            sys.exit("%s: %s uses compression 0x%02x, which this builder does not read"
                     % (path, name, chunk[0]))
    return out


def _is_patch_glob(name: str) -> bool:
    """Same as benilla: patch-?.MPQ — exactly one character after the dash."""
    low = name.lower()
    return (
        low.startswith("patch-")
        and low.endswith(".mpq")
        and len(low) == len("patch-?.mpq")
        and low[6] != "."
    )


def chain_order(data_dir):
    """Highest-priority first, excluding our own patch-T (client: later mount wins)."""
    names = os.listdir(data_dir)
    patches = sorted(
        (n for n in names if _is_patch_glob(n) and n.lower() != PATCH.lower()),
        key=str.lower,
        reverse=True,
    )
    order = list(patches)
    for want in ("patch.MPQ", "dbc.MPQ"):
        order += [n for n in names if n.lower() == want.lower()]
    return [os.path.join(data_dir, n) for n in order]


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
    header = struct.pack("<4sIIHHIIII", b"MPQ\x1a", header_size, total, 0, 3,
                         hash_pos, block_pos, hash_count, len(blocks))
    tmp = path + ".tmp"
    with open(tmp, "wb") as f:
        f.write(header + body
                + _crypt(hash_table, hash_string("(hash table)", 3), True)
                + _crypt(block_table, hash_string("(block table)", 3), True))
    os.replace(tmp, path)


def u32_set(rec: bytearray, col: int, value: int):
    struct.pack_into("<I", rec, col * 4, value & 0xFFFFFFFF)


def i32_set(rec: bytearray, col: int, value: int):
    struct.pack_into("<i", rec, col * 4, value)


def patch_spell_dbc(raw: bytes, crafts: list) -> bytes:
    magic, n, f, rs, ss = struct.unpack_from("<4s4I", raw, 0)
    if magic != b"WDBC" or f != 173 or rs != 692:
        sys.exit("unexpected Spell.dbc header: %s %s %s %s" % (magic, n, f, rs))
    records = bytearray(raw[20:20 + n * rs])
    strings = raw[20 + n * rs:20 + n * rs + ss]

    by_id = {}
    for i in range(n):
        sid = struct.unpack_from("<I", records, i * rs)[0]
        by_id[sid] = i

    new_recs = []
    for c in crafts:
        spell = c["spell"]
        if spell not in by_id:
            sys.exit("Spell.dbc missing craft spell %d" % spell)
        idx = by_id[spell]
        off = idx * rs
        rec = bytearray(records[off:off + rs])

        # Craft → CreateItem scroll.
        craft = bytearray(rec)
        u32_set(craft, COL_EFFECT_1, SPELL_EFFECT_CREATE_ITEM)
        u32_set(craft, COL_EFFECT_ITEM_1, c["scroll"])
        u32_set(craft, COL_EFFECT_MISC_1, 0)
        u32_set(craft, COL_TARGETS, 0)
        i32_set(craft, COL_EQUIPPED_CLASS, -1)
        u32_set(craft, COL_EQUIPPED_SUB, 0)
        u32_set(craft, COL_EQUIPPED_INV, 0)
        records[off:off + rs] = craft

        # Apply spell: clone, clear reagents, oil-like cast.
        apply = bytearray(rec)
        u32_set(apply, COL_ID, c["apply"])
        u32_set(apply, COL_ATTRIBUTES, SPELL_ATTR_ITEM_ENCHANT)
        u32_set(apply, COL_CASTING_TIME, CAST_INSTANT)
        u32_set(apply, COL_MANA_COST, 0)
        for k in range(8):
            i32_set(apply, COL_REAGENT_1 + k, 0)
            u32_set(apply, COL_REAGENT_COUNT_1 + k, 0)
        u32_set(apply, COL_EFFECT_ITEM_1, 0)
        if c["apply"] in by_id:
            # Already present from a previous half-applied patch — overwrite later.
            pass
        new_recs.append(bytes(apply))

    # Drop any prior apply ids if regenerating from a DBC that already had them
    # (should not happen when chain_order skips patch-T).
    keep = []
    apply_ids = {c["apply"] for c in crafts}
    for i in range(n):
        sid = struct.unpack_from("<I", records, i * rs)[0]
        if sid in apply_ids:
            continue
        keep.append(records[i * rs:(i + 1) * rs])
    body = b"".join(keep) + b"".join(new_recs)
    new_n = len(keep) + len(new_recs)
    header = struct.pack("<4s4I", b"WDBC", new_n, f, rs, len(strings))
    return header + body + strings


def main():
    flags = [a for a in sys.argv[1:] if a.startswith("--")]
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    data_dir = args[0] if args else os.path.join(ROOT, "Data")
    out = os.path.join(data_dir, PATCH)
    if "--remove" in flags:
        if os.path.exists(out):
            os.remove(out)
            print("removed %s" % out)
        return
    if not os.path.isfile(MAP_PATH):
        sys.exit("missing %s — run gen-enchant-scrolls.py first" % MAP_PATH)
    with open(MAP_PATH) as f:
        mapping = json.load(f)
    crafts = mapping["crafts"]
    raw = None
    src = None
    for archive in chain_order(data_dir):
        raw = read_file(archive, SPELL_PATH)
        if raw is not None:
            src = archive
            break
    if raw is None:
        sys.exit("no %s in %s" % (SPELL_PATH, data_dir))
    patched = patch_spell_dbc(raw, crafts)
    listfile = "%s\r\n" % SPELL_PATH
    write_mpq(out, [(SPELL_PATH, patched), ("(listfile)", listfile.encode())])
    print("enchant scrolls: %s (%d crafts, from %s)" % (out, len(crafts), os.path.basename(src)))


if __name__ == "__main__":
    main()
