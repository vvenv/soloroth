#!/usr/bin/env python3
"""Write Interface/AddOns/Companions/Data_Companions.lua from classic_world.

Detects vanity-pet (SUMMON_CRITTER) and mount (SPELL_AURA_MOUNTED) spells
tied to on-use item_template rows — same rules as Player::CompanionUnlockSpell.

Bakes English + zhCN names so the 1.12 client can match spellbook entries
(no GetSpellInfo(spellId) in vanilla), and the item's inventory icon from
ItemDisplayInfo.dbc (spell textures are almost all Ability_Seal).

  tools/macos/gen-companions-data.py
"""
from __future__ import annotations

import os
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Interface" / "AddOns" / "Companions" / "Data_Companions.lua"
WOW_DATA = Path(os.environ.get("WOW_DATA_ROOT", ROOT.parent / "wow-data"))
DBC = Path(
    os.environ.get(
        "HOA_EXTRACTED",
        WOW_DATA / "vmangos-deploy" / "storage" / "mangosd" / "extracted-data",
    )
) / "5875" / "dbc"
ITEM_DISPLAY = DBC / "ItemDisplayInfo.dbc"

SQL = r"""
SELECT kind, sid, st.name, IFNULL(ls.name_loc4, '') AS zh, MIN(x.display_id) AS did
FROM (
  SELECT 'pet' AS kind, st.entry AS sid, it.display_id
  FROM item_template it
  JOIN spell_template st ON st.entry IN (it.spellid_1, it.spellid_2, it.spellid_3)
  WHERE (
    (it.spelltrigger_1 = 0 AND it.spellid_1 = st.entry) OR
    (it.spelltrigger_2 = 0 AND it.spellid_2 = st.entry) OR
    (it.spelltrigger_3 = 0 AND it.spellid_3 = st.entry)
  ) AND (st.Effect1 = 97 OR st.Effect2 = 97 OR st.Effect3 = 97)
  UNION ALL
  SELECT 'mount', st.entry, it.display_id
  FROM item_template it
  JOIN spell_template st ON st.entry = it.spellid_1
  WHERE it.spelltrigger_1 = 0
    AND (st.EffectApplyAuraName1 = 78 OR st.EffectApplyAuraName2 = 78
         OR st.EffectApplyAuraName3 = 78)
  UNION ALL
  SELECT 'mount', mount.entry, it.display_id
  FROM item_template it
  JOIN spell_template learn ON learn.entry = it.spellid_1
  JOIN spell_template mount ON mount.entry IN (
    learn.EffectTriggerSpell1, learn.EffectTriggerSpell2, learn.EffectTriggerSpell3)
  WHERE it.spelltrigger_1 = 0
    AND (learn.Effect1 = 36 OR learn.Effect2 = 36 OR learn.Effect3 = 36)
    AND (mount.EffectApplyAuraName1 = 78 OR mount.EffectApplyAuraName2 = 78
         OR mount.EffectApplyAuraName3 = 78)
) x
JOIN spell_template st ON st.entry = x.sid
LEFT JOIN locales_spell ls ON ls.entry = x.sid
GROUP BY kind, sid
ORDER BY kind, sid;
"""


def lua_str(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def load_item_icons() -> dict[int, str]:
    """display_id -> short icon name (no Interface\\Icons\\ prefix)."""
    if not ITEM_DISPLAY.is_file():
        print(f"gen-companions-data: missing {ITEM_DISPLAY}", file=sys.stderr)
        return {}
    data = ITEM_DISPLAY.read_bytes()
    if data[:4] != b"WDBC":
        print("gen-companions-data: ItemDisplayInfo.dbc is not WDBC", file=sys.stderr)
        return {}
    record_count, field_count, record_size, string_block_size = struct.unpack_from(
        "<IIII", data, 4
    )
    strings = data[20 + record_count * record_size :]
    icons: dict[int, str] = {}
    # Classic ItemDisplayInfo: field 0 = id, field 5 = inventoryIcon1 string ref.
    for i in range(record_count):
        vals = struct.unpack_from("<" + "i" * field_count, data, 20 + i * record_size)
        off = vals[5]
        if off <= 0 or off >= len(strings):
            continue
        end = strings.find(b"\0", off)
        name = strings[off:end].decode("latin-1", "replace")
        if not name:
            continue
        # DBC sometimes stores a full path; bake the leaf only.
        if "\\" in name:
            name = name.rsplit("\\", 1)[-1]
        icons[vals[0]] = name
    return icons


def mysql_rows() -> list[tuple[str, int, str, str, int]]:
    env = os.environ.copy()
    env.setdefault("MYSQL_PWD", "mangos")
    cmd = [
        "mysql", "--ssl=0", "-N", "-B",
        "-umangos", "-h127.0.0.1", "classic_world",
        "-e", SQL,
    ]
    out = subprocess.check_output(cmd, env=env, text=True)
    rows: list[tuple[str, int, str, str, int]] = []
    seen: set[tuple[str, int]] = set()
    for line in out.splitlines():
        line = line.strip()
        if not line:
            continue
        parts = line.split("\t")
        if len(parts) < 4:
            continue
        kind, sid_s, en = parts[0], parts[1], parts[2]
        zh = parts[3] if len(parts) > 3 else ""
        did = int(parts[4]) if len(parts) > 4 and parts[4].isdigit() else 0
        key = (kind, int(sid_s))
        if key in seen:
            continue
        seen.add(key)
        rows.append((kind, int(sid_s), en, zh, did))
    return rows


def main() -> int:
    try:
        rows = mysql_rows()
    except (OSError, subprocess.CalledProcessError) as e:
        print(f"gen-companions-data: mysql failed: {e}", file=sys.stderr)
        return 1

    icons = load_item_icons()
    pets = [r for r in rows if r[0] == "pet"]
    mounts = [r for r in rows if r[0] == "mount"]
    OUT.parent.mkdir(parents=True, exist_ok=True)

    lines = [
        "-- Auto-generated by tools/macos/gen-companions-data.py — do not edit by hand.",
        "-- Each row: { spellId, englishName, zhCNName, iconLeaf }.",
        "-- iconLeaf is the item inventory texture (no Interface\\\\Icons\\\\ prefix).",
        "Companions_Pets = {",
    ]
    missing = 0
    for _, sid, en, zh, did in pets:
        icon = icons.get(did, "")
        if not icon:
            missing += 1
        lines.append(f"  {{ {sid}, {lua_str(en)}, {lua_str(zh)}, {lua_str(icon)} }},")
    lines.append("}")
    lines.append("Companions_Mounts = {")
    for _, sid, en, zh, did in mounts:
        icon = icons.get(did, "")
        if not icon:
            missing += 1
        lines.append(f"  {{ {sid}, {lua_str(en)}, {lua_str(zh)}, {lua_str(icon)} }},")
    lines.append("}")
    lines.append("")
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(
        f"wrote {OUT} ({len(pets)} pets, {len(mounts)} mounts, "
        f"{len(icons)} display icons, {missing} missing)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
