#!/usr/bin/env python3
"""Build Data/patch-M.MPQ: product UI textures (soloroth bars + Atlas floor plans).

    tools/macos/build-product-media.py [DATA_DIR] [--remove] [--force]

Sources (not copied into benilla-config/AddOns):
  - soloroth bar/glow TGA from client/crates/soloroth-ui/media/img
  - Atlas BLPs from wow-data / leftover AddOns / ui/world (same search as the
    old install-atlas-maps.sh)

Native UI keeps classic paths (Interface\\AddOns\\…) so the MPQ chain serves them
without a loose AddOns install. Skips rebuild when sources match the stamp.
"""
from __future__ import annotations

import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
PATCH = "patch-M.MPQ"
STAMP = "patch-M.stamp"

FLAG_EXISTS = 0x80000000

SOLOROTH_FILES = (
    ("bar.tga", "Interface\\AddOns\\soloroth\\img\\bar.tga"),
    ("glow2.tga", "Interface\\AddOns\\soloroth\\img\\glow2.tga"),
)


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


def soloroth_src():
    return os.path.join(ROOT, "client", "crates", "soloroth-ui", "media", "img")


def atlas_candidates(home: str):
    wow_data = os.environ.get("WOW_DATA_ROOT", os.path.join(ROOT, "..", "wow-data"))
    return [
        os.path.join(
            wow_data,
            "vmangos-deploy/storage/mangosd/client-data/Interface/"
            "AddOns.bak-20260902-131804/Atlas/Images/Maps",
        ),
        os.path.join(wow_data, "addons/Atlas/Images/Maps"),
        os.path.join(ROOT, "ui/world/Atlas/Images/Maps"),
        # Migration fallback: previous loose install under BENILLA_HOME.
        os.path.join(home, "AddOns/Atlas/Images/Maps"),
    ]


def find_atlas_src(home: str):
    for c in atlas_candidates(home):
        if os.path.isdir(c) and any(n.endswith(".blp") for n in os.listdir(c)):
            return c
    return None


def file_sig(path: str) -> str:
    st = os.stat(path)
    return "%s\t%d\t%d" % (path, st.st_size, int(st.st_mtime))


def collect_entries(home: str):
    """Return (mpq_files, stamp_lines, notes). mpq_files: [(archive_name, bytes)]."""
    files = []
    stamp = []
    notes = []

    img = soloroth_src()
    if not os.path.isdir(img):
        sys.exit("product-media: missing %s" % img)
    for leaf, archive in SOLOROTH_FILES:
        path = os.path.join(img, leaf)
        if not os.path.isfile(path):
            sys.exit("product-media: missing %s" % path)
        with open(path, "rb") as f:
            files.append((archive, f.read()))
        stamp.append(file_sig(path))
    notes.append("soloroth=%s" % img)

    atlas = find_atlas_src(home)
    if atlas is None:
        notes.append("atlas=missing")
    else:
        blps = sorted(n for n in os.listdir(atlas) if n.lower().endswith(".blp"))
        for name in blps:
            path = os.path.join(atlas, name)
            with open(path, "rb") as f:
                data = f.read()
            archive = "Interface\\AddOns\\Atlas\\Images\\Maps\\%s" % name
            files.append((archive, data))
            stamp.append(file_sig(path))
        notes.append("atlas=%s (%d)" % (atlas, len(blps)))

    return files, stamp, notes


def stamp_path(data_dir: str) -> str:
    return os.path.join(data_dir, STAMP)


def stamp_matches(data_dir: str, lines: list[str]) -> bool:
    path = stamp_path(data_dir)
    if not os.path.isfile(path):
        return False
    with open(path) as f:
        got = [ln.rstrip("\n") for ln in f if ln.strip()]
    return got == lines


def write_stamp(data_dir: str, lines: list[str]):
    path = stamp_path(data_dir)
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        f.write("\n".join(lines) + "\n")
    os.replace(tmp, path)


def main():
    flags = [a for a in sys.argv[1:] if a.startswith("--")]
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    data_dir = args[0] if args else os.path.join(ROOT, "Data")
    out = os.path.join(data_dir, PATCH)
    home = os.environ.get("BENILLA_HOME", os.path.join(ROOT, "benilla-config"))

    if "--remove" in flags:
        for p in (out, stamp_path(data_dir)):
            if os.path.exists(p):
                os.remove(p)
                print("removed %s" % p)
        return

    files, stamp, notes = collect_entries(home)
    if not files:
        sys.exit("product-media: nothing to pack")

    force = "--force" in flags
    if (
        not force
        and os.path.isfile(out)
        and stamp_matches(data_dir, stamp)
    ):
        print("product-media: %s up to date (%s)" % (out, "; ".join(notes)))
        return

    names = [n for n, _ in files]
    listfile = "\r\n".join(names + ["(listfile)"]) + "\r\n"
    write_mpq(out, files + [("(listfile)", listfile.encode())])
    write_stamp(data_dir, stamp)
    print(
        "product-media: %s (%d files; %s)"
        % (out, len(files), "; ".join(notes))
    )


if __name__ == "__main__":
    main()
