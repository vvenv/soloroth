#!/usr/bin/env python3
"""Build Data/patch-S.MPQ: the stock GlueXML.toc with SoloGlueSkin.lua appended,
and that file, so the glue loads the skin after its own files.

    tools/glue-skin/build-patch.py [DATA_DIR] [--remove]
    tools/glue-skin/build-patch.py [DATA_DIR] [--show-login-ui|--hide-login-ui]

The toc is read from the highest archive in DATA_DIR that holds it, as the client
resolves it (patch-?.MPQ by letter, then patch.MPQ, then interface.MPQ), never
from patch-S.MPQ itself. Nothing from the install is kept in the repo: the toc
is copied at build time.

--hide-login-ui (default) prepends SoloShowLoginUI = false so the skin removes the
AccountLogin page; --show-login-ui keeps it.
"""
import os
import struct
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
SKIN = "SoloGlueSkin.lua"
PATCH = "patch-S.MPQ"
TOC = "Interface\\GlueXML\\GlueXML.toc"

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
    """`name` out of the MPQ at `path`, or None when it is not there."""
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
    """Archives in the client's mount order, highest priority first, without ours."""
    names = os.listdir(data_dir)
    patches = sorted((n for n in names
                      if n.lower().startswith("patch-") and n.lower().endswith(".mpq")
                      and len(n) == len("patch-?.mpq") and n.lower() != PATCH.lower()),
                     key=str.lower, reverse=True)
    order = patches
    for want in ("patch.MPQ", "interface.MPQ"):
        order += [n for n in names if n.lower() == want.lower()]
    return [os.path.join(data_dir, n) for n in order]


def write_mpq(path, files):
    """A version-0 MPQ of stored files: no compression, no encryption."""
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


def _clamp01(x):
    if x < 0:
        return 0.0
    if x > 1:
        return 1.0
    return float(x)


def _cover(dist, half):
    """1 inside a stroke of half-width `half`, with a ~1px AA ramp."""
    return _clamp01(half + 0.75 - dist)


def rotate_arrow_tga(clockwise, size=128):
    """White arc + arrowhead on transparent TGA (32-bit). Drawn CCW, mirrored for CW."""
    import math
    cx = (size - 1) * 0.5
    # Gap sits at the bottom, so a centered circle reads high in the button;
    # nudge the whole glyph down so the ink mass sits on the face midline.
    cy = (size - 1) * 0.5 - size * 0.08
    radius = size * 0.31
    # ~2.5px stroke at the ~26px on-screen icon size.
    half = size * 0.048
    # Math y-up: stroke ends at ~8 o'clock; tip follows the CCW tangent
    # (down, slightly inward). Long sharp head so it reads at 26px.
    a0 = math.radians(-40)
    a1 = math.radians(200)
    tang = a1 + math.pi * 0.5
    head_len = size * 0.28
    head_half = size * 0.09
    end_x = cx + math.cos(a1) * radius
    end_y = cy + math.sin(a1) * radius
    tip_x = end_x + math.cos(tang) * (head_len * 0.72)
    tip_y = end_y + math.sin(tang) * (head_len * 0.72)
    back_x = tip_x - math.cos(tang) * head_len
    back_y = tip_y - math.sin(tang) * head_len
    left_x = back_x + math.cos(tang + math.pi * 0.5) * head_half
    left_y = back_y + math.sin(tang + math.pi * 0.5) * head_half
    right_x = back_x + math.cos(tang - math.pi * 0.5) * head_half
    right_y = back_y + math.sin(tang - math.pi * 0.5) * head_half

    def in_arc(ang):
        while ang < a0:
            ang += 2 * math.pi
        while ang > a1 + 1e-6:
            ang -= 2 * math.pi
        return a0 - 0.02 <= ang <= a1 + 0.02

    def edge(ax, ay, bx, by, x, y):
        return (x - ax) * (by - ay) - (y - ay) * (bx - ax)

    area = edge(tip_x, tip_y, left_x, left_y, right_x, right_y)

    def tri_cover(px, py):
        if area == 0:
            return 0.0
        e0 = edge(tip_x, tip_y, left_x, left_y, px, py)
        e1 = edge(left_x, left_y, right_x, right_y, px, py)
        e2 = edge(right_x, right_y, tip_x, tip_y, px, py)
        if area < 0:
            e0, e1, e2 = -e0, -e1, -e2
        if e0 < -1.5 or e1 < -1.5 or e2 < -1.5:
            return 0.0
        return _clamp01(min(e0, e1, e2) / 1.5 + 0.25)

    rows = []
    for y in range(size):
        row = []
        for x in range(size):
            mx = x + 0.5
            my = size - (y + 0.5)
            dx, dy = mx - cx, my - cy
            dist = math.hypot(dx, dy)
            ang = math.atan2(dy, dx)
            a = _cover(abs(dist - radius), half) if in_arc(ang) else 0.0
            a = max(a, tri_cover(mx, my))
            row.append((255, 255, 255, int(255 * _clamp01(a) + 0.5)))
        rows.append(row)

    if clockwise:
        rows = [list(reversed(r)) for r in rows]

    # Descriptor: bit 5 = top-left origin; low nibble = 8 alpha bits (32-bpp
    # with 0 alpha bits refuses decode and draws opaque white).
    header = struct.pack(
        "<BBBHHBHHHHBB",
        0, 0, 2, 0, 0, 0, 0, 0, size, size, 32, 0x28,
    )
    body = bytearray()
    for row in rows:
        for r, g, b, a in row:
            body.extend((b, g, r, a))
    return bytes(header) + bytes(body)


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
    if "--show-login-ui" in flags and "--hide-login-ui" in flags:
        sys.exit("use only one of --show-login-ui / --hide-login-ui")
    show_login_ui = "--show-login-ui" in flags
    toc = None
    for archive in chain_order(data_dir):
        toc = read_file(archive, TOC)
        if toc is not None:
            break
    if toc is None:
        sys.exit("no %s in %s" % (TOC, data_dir))
    lines = toc.replace(b"\r", b"").split(b"\n")
    if SKIN.encode() not in lines:
        toc = toc.rstrip(b"\r\n") + b"\r\n" + SKIN.encode() + b"\r\n"
    with open(os.path.join(HERE, SKIN), "rb") as f:
        skin = f.read()
    # Glue Lua cannot read the process env; bake the choice in at patch time.
    skin = ("SoloShowLoginUI = %s\r\n" % ("true" if show_login_ui else "false")).encode() + skin
    left = rotate_arrow_tga(False)
    right = rotate_arrow_tga(True)
    listfile = (
        "%s\r\nInterface\\GlueXML\\%s\r\n"
        "Interface\\Glues\\Solo\\RotateLeft.tga\r\n"
        "Interface\\Glues\\Solo\\RotateRight.tga\r\n"
    ) % (TOC, SKIN)
    files = [
        (TOC, toc),
        ("Interface\\GlueXML\\" + SKIN, skin),
        ("Interface\\Glues\\Solo\\RotateLeft.tga", left),
        ("Interface\\Glues\\Solo\\RotateRight.tga", right),
        ("(listfile)", listfile.encode()),
    ]
    write_mpq(out, files)
    print("glue skin: %s (login ui %s)" % (out, "shown" if show_login_ui else "hidden"))


if __name__ == "__main__":
    main()
