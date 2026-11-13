#!/usr/bin/env python3
"""Build Data/patch-L.MPQ: 16:9 HD loading-screen BLPs that fill the window.

    tools/loading-screens/build-patch.py [DATA_DIR] [--force] [--remove]

Reads every FileName in LoadingScreens.dbc off the Data/ chain (skipping
patch-L itself), upscales each stock BLP to 1920×1080 with a centre crop via
blpx + ffmpeg, writes BLP2 Raw3, and packs them as patch-L.MPQ. Cached under
$WOW_DATA_ROOT/loading-screens/; rebuilds when the script or a source BLP is
newer, or with --force.

Needs: ffmpeg on PATH, and a built blpx (cargo build -p benilla-blp --bin blpx
in client/, or BLPX=/path/to/blpx).
"""
from __future__ import print_function

import os
import struct
import subprocess
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
PATCH = "patch-L.MPQ"
DBC = "DBFilesClient\\LoadingScreens.dbc"
OUT_W, OUT_H = 1920, 1080

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


def chain_order(data_dir):
    """Highest priority first, without patch-L."""
    names = os.listdir(data_dir)
    patches = sorted(
        (n for n in names
         if n.lower().startswith("patch-") and n.lower().endswith(".mpq")
         and len(n) == len("patch-?.mpq") and n.lower() != PATCH.lower()),
        key=str.lower, reverse=True)
    order = list(patches)
    for want in ("patch.MPQ", "interface.MPQ", "dbc.MPQ"):
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


def parse_loading_screens(dbc):
    magic, record_count, field_count, record_size, _ = struct.unpack_from("<4sIIII", dbc)
    if magic != b"WDBC" or field_count < 3 or record_size < 12:
        sys.exit("LoadingScreens.dbc: unexpected header")
    records = dbc[20:20 + record_count * record_size]
    strings = dbc[20 + record_count * record_size:]
    paths = []
    seen = set()
    for i in range(record_count):
        _id, _name_off, file_off = struct.unpack_from("<III", records, i * record_size)
        end = strings.find(b"\0", file_off)
        path = strings[file_off:end].decode("latin-1")
        if path and path not in seen:
            seen.add(path)
            paths.append(path)
    return paths


def find_blpx():
    env = os.environ.get("BLPX")
    if env and os.path.isfile(env) and os.access(env, os.X_OK):
        return env
    for rel in ("target/release/blpx", "target/debug/blpx"):
        p = os.path.join(ROOT, "client", rel)
        if os.path.isfile(p) and os.access(p, os.X_OK):
            return p
    sys.exit("no blpx: cargo build -p benilla-blp --bin blpx  (in client/)")


def encode_blp2_raw3(width, height, rgba):
    """BLP2 encoding 3 (uncompressed BGRA), mip 0 only. Header layout matches benilla-blp."""
    if len(rgba) != width * height * 4:
        sys.exit("rgba size mismatch: %d for %dx%d" % (len(rgba), width, height))
    bgra = bytearray(len(rgba))
    for i in range(0, len(rgba), 4):
        bgra[i] = rgba[i + 2]
        bgra[i + 1] = rgba[i + 1]
        bgra[i + 2] = rgba[i]
        bgra[i + 3] = rgba[i + 3]
    header = bytearray(148)
    header[0:4] = b"BLP2"
    struct.pack_into("<I", header, 4, 1)  # content type: Direct
    struct.pack_into("<BBBB", header, 8, 3, 8, 1, 0)  # enc Raw3, aBits, aType, hasMips
    struct.pack_into("<II", header, 12, width, height)
    struct.pack_into("<I", header, 20, 148)  # mipOffsets[0]
    struct.pack_into("<I", header, 84, len(bgra))  # mipSizes[0]
    return bytes(header) + bytes(bgra)


def blp_size(blp_bytes):
    """Width and height from a BLP2 header (type is u32 at offset 4)."""
    if blp_bytes[:4] != b"BLP2" or len(blp_bytes) < 20:
        sys.exit("not a BLP2")
    return struct.unpack_from("<II", blp_bytes, 12)


def upscale(blpx, blp_bytes, work_dir, stem):
    src = os.path.join(work_dir, stem + ".blp")
    rgba_in = os.path.join(work_dir, stem + ".rgba")
    rgba_out = os.path.join(work_dir, stem + "-out.rgba")
    with open(src, "wb") as f:
        f.write(blp_bytes)
    subprocess.check_call([blpx, src, rgba_in], stdout=subprocess.DEVNULL)
    w, h = blp_size(blp_bytes)
    want = OUT_W * OUT_H * 4
    vf = "scale=%d:%d:force_original_aspect_ratio=increase,crop=%d:%d" % (
        OUT_W, OUT_H, OUT_W, OUT_H)
    subprocess.check_call([
        "ffmpeg", "-y", "-loglevel", "error",
        "-f", "rawvideo", "-pix_fmt", "rgba", "-s", "%dx%d" % (w, h), "-i", rgba_in,
        "-vf", vf,
        "-f", "rawvideo", "-pix_fmt", "rgba", rgba_out,
    ])
    with open(rgba_out, "rb") as f:
        out = f.read()
    if len(out) != want:
        sys.exit("%s: ffmpeg wrote %d bytes, want %d" % (stem, len(out), want))
    return encode_blp2_raw3(OUT_W, OUT_H, out)


def cache_dir():
    wow_data = os.environ.get("WOW_DATA_ROOT", os.path.join(ROOT, "..", "wow-data"))
    return os.path.join(os.path.abspath(wow_data), "loading-screens")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    data_dir = args[0] if args else os.path.join(ROOT, "Data")
    out = os.path.join(data_dir, PATCH)
    if "--remove" in sys.argv:
        if os.path.exists(out):
            os.remove(out)
            print("removed %s" % out)
        return

    force = "--force" in sys.argv
    cache = cache_dir()
    os.makedirs(cache, exist_ok=True)
    cached_mpq = os.path.join(cache, PATCH)
    script_mtime = os.path.getmtime(__file__)

    if (not force and os.path.isfile(cached_mpq)
            and os.path.getmtime(cached_mpq) >= script_mtime):
        if (not os.path.isfile(out)
                or os.path.getmtime(out) < os.path.getmtime(cached_mpq)
                or os.path.getsize(out) != os.path.getsize(cached_mpq)):
            import shutil
            shutil.copy2(cached_mpq, out)
            print("loading screens: %s (cached)" % out)
        else:
            print("loading screens: %s (up to date)" % out)
        return

    dbc = None
    for archive in chain_order(data_dir):
        dbc = read_file(archive, DBC)
        if dbc is not None:
            break
    if dbc is None:
        sys.exit("no %s in %s" % (DBC, data_dir))
    paths = parse_loading_screens(dbc)
    if not paths:
        sys.exit("LoadingScreens.dbc has no FileName rows")

    blpx = find_blpx()
    work = os.path.join(cache, "work")
    os.makedirs(work, exist_ok=True)
    files = []
    for path in paths:
        raw = None
        for archive in chain_order(data_dir):
            raw = read_file(archive, path)
            if raw is not None:
                break
        if raw is None:
            sys.exit("missing %s in %s" % (path, data_dir))
        stem = os.path.splitext(os.path.basename(path.replace("\\", "/")))[0]
        print("  upscale %s" % stem)
        blp = upscale(blpx, raw, work, stem)
        files.append((path, blp))

    listfile = "\r\n".join(p for p, _ in files) + "\r\n(listfile)\r\n"
    files.append(("(listfile)", listfile.encode("latin-1")))
    write_mpq(cached_mpq, files)
    import shutil
    shutil.copy2(cached_mpq, out)
    print("loading screens: %s (%d BLPs, 1920x1080)" % (out, len(files) - 1))


if __name__ == "__main__":
    main()
