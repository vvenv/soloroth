#!/usr/bin/env python3
"""Turn permanent enchant crafts into scroll CreateItem recipes.

  tools/enchant-scrolls/gen-enchant-scrolls.py [migration id, YYYYmmddHHMMSS]

Reads classic_world (skill 333, effect 53), then writes:
  server/core/sql/migrations/<id>_world.sql
  tools/enchant-scrolls/map.json   (craft → scroll/apply ids for the DBC patch)

Scroll items: 41000+i. Apply spells (no reagents): 35000+i.
Craft spells stay on their original ids; effect becomes CreateItem.
"""
from __future__ import annotations

import csv
import io
import json
import os
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HERE = os.path.dirname(os.path.abspath(__file__))
MARIADB = os.path.join(ROOT, "server/mariadb/bin/mariadb")
WORLD_DB = "classic_world"
ITEM_BASE = 41000
SPELL_BASE = 35000
# Scroll art: Scroll of Strength.
DISPLAY_ID = 3331


def query(sql: str):
    out = subprocess.run(
        [MARIADB, "--skip-ssl", "-h127.0.0.1", "-umangos", "-pmangos",
         "--batch", "--raw", WORLD_DB],
        input=sql, capture_output=True, text=True, check=True,
    ).stdout
    return list(csv.DictReader(io.StringIO(out), delimiter="\t", quoting=csv.QUOTE_NONE))


def esc(s: str) -> str:
    return (s or "").replace("\\", "\\\\").replace("'", "''")


def sql_str(s: str) -> str:
    return "'%s'" % esc(s)


def load_crafts():
    rows = query("""
SELECT sla.spell_id AS spell_id,
       st.name AS name,
       st.effectMiscValue1 AS enchant_id,
       st.equippedItemClass AS eq_class,
       st.equippedItemSubClassMask AS eq_sub,
       st.equippedItemInventoryTypeMask AS eq_inv,
       st.targets AS targets,
       st.spellIconId AS icon,
       st.castingTimeIndex AS cast_idx,
       st.attributes AS attributes,
       IFNULL(ls.name_loc4, '') AS name_zh
FROM skill_line_ability sla
JOIN spell_template st ON st.entry = sla.spell_id
LEFT JOIN locales_spell ls ON ls.entry = sla.spell_id
WHERE sla.skill_id = 333 AND sla.build = 5875 AND st.effect1 = 53
  AND st.build = (SELECT MAX(b.build) FROM spell_template b
                  WHERE b.entry = st.entry AND b.build <= 5875)
ORDER BY sla.spell_id
""")
    if not rows:
        sys.exit("no permanent enchant crafts found in classic_world")
    crafts = []
    for i, r in enumerate(rows):
        spell = int(r["spell_id"])
        en = r["name"] or ("Enchant %d" % spell)
        zh = r["name_zh"] if r["name_zh"] not in ("", "NULL", None) else en
        crafts.append({
            "index": i,
            "spell": spell,
            "scroll": ITEM_BASE + i,
            "apply": SPELL_BASE + i,
            "enchant": int(r["enchant_id"]),
            "name": en,
            "name_zh": zh,
            "eq_class": int(r["eq_class"]),
            "eq_sub": int(r["eq_sub"]),
            "eq_inv": int(r["eq_inv"]),
            "targets": int(r["targets"]),
            "icon": int(r["icon"]),
        })
    return crafts


def emit_migration(mid: str, crafts: list) -> str:
    last_item = ITEM_BASE + len(crafts) - 1
    last_spell = SPELL_BASE + len(crafts) - 1
    lines = [
        "DROP PROCEDURE IF EXISTS add_migration;",
        "DELIMITER ??",
        "CREATE PROCEDURE `add_migration`()",
        "BEGIN",
        "DECLARE v INT DEFAULT 1;",
        "SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='%s');" % mid,
        "IF v = 0 THEN",
        "INSERT INTO `migrations` VALUES ('%s');" % mid,
        "-- Add your query below.",
        "",
        "-- Soloroth: permanent enchant crafts produce scrolls; scrolls apply on use.",
        "DELETE FROM `item_template` WHERE `entry` BETWEEN %d AND %d;" % (ITEM_BASE, last_item),
        "DELETE FROM `locales_item` WHERE `entry` BETWEEN %d AND %d;" % (ITEM_BASE, last_item),
        "DELETE FROM `spell_template` WHERE `entry` BETWEEN %d AND %d;" % (SPELL_BASE, last_spell),
        "DELETE FROM `locales_spell` WHERE `entry` BETWEEN %d AND %d;" % (SPELL_BASE, last_spell),
        "",
        "CREATE TEMPORARY TABLE `_solo_enchant_apply` LIKE `spell_template`;",
    ]

    for c in crafts:
        lines.append("TRUNCATE TABLE `_solo_enchant_apply`;")
        lines.append(
            "INSERT INTO `_solo_enchant_apply` SELECT * FROM `spell_template` "
            "WHERE `entry`=%d AND `build`=("
            "SELECT MAX(b.build) FROM `spell_template` b WHERE b.entry=%d AND b.build<=5875);"
            % (c["spell"], c["spell"])
        )
        lines.append(
            "UPDATE `_solo_enchant_apply` SET "
            "`entry`=%d, `build`=5875, `attributes`=262144, `castingTimeIndex`=14, "
            "`manaCost`=0, `manCostPerLevel`=0, `manaPerSecond`=0, `manaPerSecondPerLevel`=0, "
            "`totem1`=0, `totem2`=0, "
            "`reagent1`=0, `reagent2`=0, `reagent3`=0, `reagent4`=0, "
            "`reagent5`=0, `reagent6`=0, `reagent7`=0, `reagent8`=0, "
            "`reagentCount1`=0, `reagentCount2`=0, `reagentCount3`=0, `reagentCount4`=0, "
            "`reagentCount5`=0, `reagentCount6`=0, `reagentCount7`=0, `reagentCount8`=0, "
            "`effectItemType1`=0, `effectItemType2`=0, `effectItemType3`=0, "
            "`name`=%s;"
            % (c["apply"], sql_str(c["name"]))
        )
        lines.append("INSERT INTO `spell_template` SELECT * FROM `_solo_enchant_apply`;")
        if c["name_zh"] and c["name_zh"] != c["name"]:
            lines.append(
                "INSERT INTO `locales_spell` (`entry`,`name_loc4`) VALUES (%d,%s);"
                % (c["apply"], sql_str(c["name_zh"]))
            )

    lines.append("DROP TEMPORARY TABLE `_solo_enchant_apply`;")
    lines.append("")
    lines.append("-- Scroll items (use apply spell; no reagents).")
    for c in crafts:
        en_name = "Scroll: " + c["name"]
        zh_name = "卷轴：" + c["name_zh"]
        lines.append(
            "INSERT INTO `item_template` ("
            "`entry`,`patch`,`class`,`subclass`,`name`,`description`,`display_id`,`quality`,`flags`,"
            "`buy_count`,`buy_price`,`sell_price`,`inventory_type`,`allowable_class`,`allowable_race`,"
            "`item_level`,`required_level`,`required_skill`,`required_skill_rank`,`required_spell`,"
            "`required_honor_rank`,`required_city_rank`,`required_reputation_faction`,"
            "`required_reputation_rank`,`max_count`,`stackable`,`container_slots`,"
            "`spellid_1`,`spelltrigger_1`,`spellcharges_1`,`spellppmrate_1`,`spellcooldown_1`,"
            "`spellcategory_1`,`spellcategorycooldown_1`,"
            "`bonding`,`material`,`sheath`,`bag_family`,`extra_flags`,`other_team_entry`"
            ") VALUES ("
            "%d,0,7,0,%s,'',%d,1,64,"
            "1,0,0,0,-1,-1,"
            "1,0,0,0,0,"
            "0,0,0,"
            "0,0,20,0,"
            "%d,0,-1,0,-1,"
            "0,-1,"
            "0,0,0,0,0,1);"
            % (c["scroll"], sql_str(en_name), DISPLAY_ID, c["apply"])
        )
        lines.append(
            "INSERT INTO `locales_item` (`entry`,`name_loc4`) VALUES (%d,%s);"
            % (c["scroll"], sql_str(zh_name))
        )

    lines.append("")
    lines.append("-- Craft spells: CreateItem the scroll (keep reagents / tradeskill attrs).")
    for c in crafts:
        lines.append(
            "UPDATE `spell_template` SET "
            "`effect1`=24, `effectItemType1`=%d, `effectMiscValue1`=0, "
            "`targets`=0, `equippedItemClass`=-1, "
            "`equippedItemSubClassMask`=0, `equippedItemInventoryTypeMask`=0 "
            "WHERE `entry`=%d;"
            % (c["scroll"], c["spell"])
        )

    lines += [
        "",
        "-- End of migration.",
        "END IF;",
        "END??",
        "DELIMITER ;",
        "CALL add_migration();",
        "DROP PROCEDURE IF EXISTS add_migration;",
        "",
    ]
    return "\n".join(lines)


def main():
    mid = sys.argv[1] if len(sys.argv) > 1 else time.strftime("%Y%m%d%H%M%S", time.gmtime())
    crafts = load_crafts()
    sql = emit_migration(mid, crafts)
    path = os.path.join(ROOT, "server/core/sql/migrations", mid + "_world.sql")
    with open(path, "w") as f:
        f.write(sql)
    mapping = {
        "item_base": ITEM_BASE,
        "spell_base": SPELL_BASE,
        "crafts": [
            {
                "spell": c["spell"],
                "scroll": c["scroll"],
                "apply": c["apply"],
                "enchant": c["enchant"],
                "name": c["name"],
                "name_zh": c["name_zh"],
            }
            for c in crafts
        ],
    }
    map_path = os.path.join(HERE, "map.json")
    with open(map_path, "w") as f:
        json.dump(mapping, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("wrote %s (%d crafts)" % (path, len(crafts)))
    print("wrote %s" % map_path)


if __name__ == "__main__":
    main()
