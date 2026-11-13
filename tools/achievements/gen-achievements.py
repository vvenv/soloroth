#!/usr/bin/env python3
"""Achievement definitions: one source for the server table and the addon.

  tools/achievements/gen-achievements.py <migration id, YYYYmmddHHMMSS>

Writes
  server/core/sql/migrations/<id>_world.sql     achievement_template and
                                                achievement_criteria, replaced
  Interface/AddOns/Achievements/Data.lua         the same, plus the texts and
                                                icons the window shows

The achievements are the WoW 3.x ones that the 1.12 world holds: levels, quest
counts, the Loremaster line, exploring every zone, and the classic dungeons
and raids. Two inputs make them fit this world rather than 3.x's:

  * Exploration criteria are the client's WorldMapOverlay rows, as in 3.x: an
    overlay counts once any of its areas is explored. Read from the zhCN
    client's DBCs (and the enUS DBCs vmangos extracted, for English names).
  * Zone quest counts come from the world DB: quests with a spawned starter
    that the faction can take (no class, profession or repeatable quests, at
    most one per exclusive group). A zone asks for 60% of them.

Needs: the world DB (classic_world, read through server/mariadb), the client
MPQs in Data/ and mpqx (built from the client: `cargo build --release -p
benilla-formats --bin mpqx`), the enUS DBC folder below.
"""
import collections
import csv
import io
import os
import struct
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MARIADB = os.path.join(ROOT, "server/mariadb/bin/mariadb")
MPQX = os.path.join(ROOT, "release/build/macos/client-target/release/mpqx")
DATA = os.path.join(ROOT, "Data")
ENUS_DBC = os.path.join(ROOT, "../wow-data/vmangos-deploy/storage/mangosd/extracted-data/5875/dbc")
WORLD_DB = "classic_world"
PATCH = 10  # WowPatch: 1.12

# Criteria types (AchievementMgr.h keeps the same numbers).
REACH_LEVEL, QUEST_COUNT, QUESTS_IN_ZONE, EXPLORE_AREA, KILL_CREATURE, EARN_ACHIEVEMENT, COMPLETE_QUEST = 1, 2, 3, 4, 5, 6, 7
BOTH, ALLIANCE, HORDE = 0, 1, 2
ZONE_SHARE = 0.6
ZONE_MIN = 10      # a zone that would ask for fewer quests gets no achievement

# Categories: id, parent, english, chinese.
CATEGORIES = [
    (1, 0, "General", "综合"),
    (2, 0, "Quests", "任务"),
    (21, 2, "Eastern Kingdoms", "东部王国"),
    (22, 2, "Kalimdor", "卡利姆多"),
    (3, 0, "Exploration", "探索"),
    (31, 3, "Eastern Kingdoms", "东部王国"),
    (32, 3, "Kalimdor", "卡利姆多"),
    (4, 0, "Dungeons & Raids", "地下城与团队副本"),
    (41, 4, "Classic Dungeons", "经典地下城"),
    (42, 4, "Classic Raids", "经典团队副本"),
]

CITIES = {1519, 1537, 1657, 1637, 1638, 1497}

# 3.x Classic dungeons: (id, map name en/zh, icon, [boss entries]).
DUNGEONS = [
    (1301, "Ragefire Chasm", "怒焰裂谷", "Spell_Fire_LavaSpawn", [11520]),
    (1302, "Wailing Caverns", "哀嚎洞穴", "Spell_Nature_NullifyDisease", [3654]),
    (1303, "The Deadmines", "死亡矿井", "INV_Pick_02", [639]),
    (1304, "Shadowfang Keep", "影牙城堡", "Spell_Shadow_RaiseDead", [4275]),
    (1305, "Blackfathom Deeps", "黑暗深渊", "INV_Misc_Fish_14", [4829]),
    (1306, "The Stockade", "监狱", "INV_Misc_Key_03", [1716]),
    (1307, "Gnomeregan", "诺莫瑞根", "INV_Misc_Gear_01", [7800]),
    (1308, "Razorfen Kraul", "剃刀沼泽", "INV_Misc_Root_02", [4421]),
    (1309, "Scarlet Monastery", "血色修道院", "Spell_Holy_Resurrection", [4543, 6487, 3975, 3977]),
    (1310, "Razorfen Downs", "剃刀高地", "Spell_Frost_FrostShock", [7358]),
    (1311, "Uldaman", "奥达曼", "Spell_Nature_Earthquake", [2748]),
    (1312, "Zul'Farrak", "祖尔法拉克", "INV_Misc_Head_Troll_01", [7267]),
    (1313, "Maraudon", "玛拉顿", "INV_Misc_Idol_03", [12201]),
    (1314, "Sunken Temple", "沉没的神庙", "INV_Misc_Head_Dragon_Bronze", [5709]),
    (1315, "Blackrock Depths", "黑石深渊", "INV_Hammer_Unique_Sulfuras", [9019]),
    (1316, "Lower Blackrock Spire", "黑石塔下层", "INV_Misc_Head_Dragon_Black", [9568]),
    (1317, "Upper Blackrock Spire", "黑石塔上层", "INV_Misc_Head_Dragon_01", [10363]),
    (1318, "Dire Maul", "厄运之槌", "INV_Misc_Head_Gnoll_01", [11492, 11486, 11501]),
    (1319, "Scholomance", "通灵学院", "Spell_Shadow_Charm", [1853]),
    (1320, "Stratholme", "斯坦索姆", "INV_Misc_Head_Undead_01", [10440]),
]
RAIDS = [
    (1401, "Onyxia's Lair", "奥妮克希亚的巢穴", "INV_Misc_Head_Dragon_Black", [10184]),
    (1402, "Molten Core", "熔火之心", "Spell_Fire_Incinerate", [11502]),
    (1403, "Zul'Gurub", "祖尔格拉布", "INV_Misc_Monsterclaw_04", [14834]),
    (1404, "Blackwing Lair", "黑翼之巢", "INV_Misc_Shadowegg", [11583]),
    (1405, "Ruins of Ahn'Qiraj", "安其拉废墟", "INV_Qiraj_JewelBlessed", [15339]),
    (1406, "Temple of Ahn'Qiraj", "安其拉神殿", "INV_Misc_Ahnqirajtrinket_05", [15727]),
    (1407, "Naxxramas", "纳克萨玛斯", "INV_Trinket_Naxxramas06", [15990]),
]
LEVEL_ICONS = {10: "INV_Sword_04", 20: "INV_Shield_06", 30: "INV_Helmet_25",
               40: "Ability_Mount_RidingHorse", 50: "INV_Chest_Plate06", 60: "Spell_Holy_SealOfWisdom"}
QUEST_COUNTS = [(1101, 50, "INV_Misc_Note_01"), (1102, 100, "INV_Scroll_03"), (1103, 250, "INV_Misc_Book_07"),
                (1104, 500, "INV_Misc_Book_09"), (1105, 1000, "INV_Misc_Book_11")]


# ------------------------------------------------------------------ inputs --

def dbc(path):
    d = open(path, "rb").read()
    _, n, f, rs, _ = struct.unpack("<4s4I", d[:20])
    recs = [struct.unpack("<%di" % f, d[20 + i * rs:20 + (i + 1) * rs]) for i in range(n)]
    strings = d[20 + n * rs:]

    def s(o):
        return strings[o:strings.index(b"\0", o)].decode("utf-8")
    return recs, s


def client_dbc(name, tmp):
    out = os.path.join(tmp, name + ".dbc")
    subprocess.run([MPQX, DATA, "DBFilesClient\\%s.dbc" % name, out], check=True, stdout=subprocess.DEVNULL)
    return dbc(out)


def area_names(recs, s):
    names = {}
    for r in recs:
        names[r[0]] = next((s(r[11 + k]) for k in range(8) if r[11 + k]), "")
    return names


def query(sql):
    out = subprocess.run([MARIADB, "--skip-ssl", "-h127.0.0.1", "-umangos", "-pmangos", "--batch", WORLD_DB],
                         input=sql, capture_output=True, text=True, check=True).stdout
    return list(csv.DictReader(io.StringIO(out), delimiter="\t", quoting=csv.QUOTE_NONE))


def icon_exists(icon):
    return subprocess.run([MPQX, DATA, "Interface\\Icons\\%s.blp" % icon, os.devnull],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0


# Team masks of FactionTemplate (FACTION_MASK_ALLIANCE / _HORDE) and the
# factions the players' templates belong to.
TEAM_MASK = {ALLIANCE: 2, HORDE: 4}
TEAM_FACTION = {ALLIANCE: 469, HORDE: 67}
RACES = {ALLIANCE: 1 | 4 | 8 | 64, HORDE: 2 | 16 | 32 | 128}


def zone_quest_counts():
    """{team: {zone: n}} of the quests a team can take, by the quest's zone."""
    templates = {int(r["id"]): r for r in query("SELECT * FROM faction_template")}

    def hostile(ft, team):
        t = templates.get(ft)
        if not t:
            return False
        if int(t["hostile_mask"]) & TEAM_MASK[team]:
            return True
        return str(TEAM_FACTION[team]) in (t["enemy_faction1"], t["enemy_faction2"], t["enemy_faction3"], t["enemy_faction4"])

    rows = query("""
SELECT q.entry, COALESCE(NULLIF(a.zone_id, 0), a.entry) zone, a.map_id, q.RequiredRaces, q.RequiredClasses,
       q.RequiredSkill, q.SpecialFlags, q.Method, q.ExclusiveGroup,
       (SELECT GROUP_CONCAT(DISTINCT ct.faction) FROM creature_questrelation r
          JOIN creature c ON c.id = r.id AND c.patch_min <= %(p)d AND c.patch_max >= %(p)d
          JOIN creature_template ct ON ct.entry = r.id
               AND ct.patch = (SELECT MAX(patch) FROM creature_template x WHERE x.entry = r.id AND x.patch <= %(p)d)
         WHERE r.quest = q.entry AND r.patch_min <= %(p)d AND r.patch_max >= %(p)d) npc_factions,
       (EXISTS(SELECT 1 FROM gameobject_questrelation r
          JOIN gameobject g ON g.id = r.id AND g.patch_min <= %(p)d AND g.patch_max >= %(p)d
         WHERE r.quest = q.entry AND r.patch_min <= %(p)d AND r.patch_max >= %(p)d)
        OR EXISTS(SELECT 1 FROM item_template i WHERE i.start_quest = q.entry)) other_starter
FROM quest_template q
JOIN (SELECT entry, MAX(patch) p FROM quest_template WHERE patch <= %(p)d GROUP BY entry) m
  ON m.entry = q.entry AND m.p = q.patch
JOIN area_template a ON a.entry = q.ZoneOrSort
WHERE q.ZoneOrSort > 0
""" % {"p": PATCH})
    counts = {ALLIANCE: collections.Counter(), HORDE: collections.Counter()}
    for team in (ALLIANCE, HORDE):
        groups = set()
        for r in rows:
            if r["map_id"] not in ("0", "1") or r["Method"] == "1":
                continue
            if int(r["SpecialFlags"]) & 1 or r["RequiredClasses"] != "0" or r["RequiredSkill"] != "0":
                continue
            races = int(r["RequiredRaces"])
            if races and not races & RACES[team]:
                continue
            factions = [int(x) for x in r["npc_factions"].split(",")] if r["npc_factions"] not in ("", "NULL") else []
            takeable = r["other_starter"] == "1" or any(not hostile(f, team) for f in factions)
            if not takeable:
                continue
            group = int(r["ExclusiveGroup"])
            if group > 0:
                if group in groups:
                    continue
                groups.add(group)
            counts[team][int(r["zone"])] += 1
    return counts


def creature_names(entries):
    rows = query("SELECT t.entry, t.name, l.name_loc4 FROM creature_template t LEFT JOIN locales_creature l "
                 "ON l.entry = t.entry WHERE t.entry IN (%s) GROUP BY t.entry" % ",".join(map(str, entries)))
    return {int(r["entry"]): (r["name"], r["name_loc4"] if r["name_loc4"] not in ("", "NULL") else r["name"]) for r in rows}


# ------------------------------------------------------------------- build --

class Ach:
    def __init__(self, id, cat, en, zh, den, dzh, icon, points=10, faction=BOTH, required=0, bar=False):
        self.id, self.cat, self.en, self.zh, self.den, self.dzh = id, cat, en, zh, den, dzh
        self.icon, self.points, self.faction, self.required, self.bar = icon, points, faction, required, bar
        self.criteria = []

    def add(self, type, value=1, assets=(), en="", zh=""):
        cid = self.id * 100 + len(self.criteria) + 1
        assets = list(assets) + [0] * (4 - len(assets))
        self.criteria.append((cid, type, assets, value, en, zh))


def build(tmp):
    areas_zh = area_names(*client_dbc("AreaTable", tmp))
    areas_en = area_names(*dbc(os.path.join(ENUS_DBC, "AreaTable.dbc")))
    maps, _ = client_dbc("WorldMapArea", tmp)
    overlays, _ = client_dbc("WorldMapOverlay", tmp)
    quests = zone_quest_counts()
    out = []

    # General: levels.
    for i, lvl in enumerate(range(10, 70, 10)):
        a = Ach(1001 + i, 1, "Level %d" % lvl, "%d级" % lvl, "Reach level %d." % lvl, "达到%d级。" % lvl,
                LEVEL_ICONS[lvl], bar=True)
        a.add(REACH_LEVEL, lvl)
        out.append(a)

    # Quests: counts.
    for id, n, icon in QUEST_COUNTS:
        a = Ach(id, 2, "%d Quests Completed" % n, "完成%d个任务" % n,
                "Complete %d quests." % n, "完成%d个任务。" % n, icon, bar=True)
        a.add(QUEST_COUNT, n)
        out.append(a)

    # Zones, in the order of the world map: continent, then name.
    zones = []
    for m in maps:
        _, mapid, zone = m[0], m[1], m[2]
        if mapid not in (0, 1) or not zone or zone in CITIES:
            continue
        zones.append((mapid, zone, [o for o in overlays if o[1] == m[0]]))
    zones.sort(key=lambda z: (z[0], areas_en[z[1]]))

    lore = {(0, ALLIANCE): [], (0, HORDE): [], (1, ALLIANCE): [], (1, HORDE): []}
    for mapid, zone, ovs in zones:
        cat = 21 if mapid == 0 else 22
        for team in (ALLIANCE, HORDE):
            n = int(quests[team][zone] * ZONE_SHARE)
            if n < ZONE_MIN:
                continue
            a = Ach(20000 + zone * 2 + (team - 1), cat, "%s Quests" % areas_en[zone], "%s的任务" % areas_zh[zone],
                    "Complete %d quests in %s." % (n, areas_en[zone]), "完成%d个%s的任务。" % (n, areas_zh[zone]),
                    "INV_Letter_08", faction=team, bar=True)
            a.add(QUESTS_IN_ZONE, n, [zone])
            out.append(a)
            lore[(mapid, team)].append(a)

    explore = {0: [], 1: []}
    for mapid, zone, ovs in zones:
        if not ovs:
            continue
        cat = 31 if mapid == 0 else 32
        a = Ach(30000 + zone, cat, "Explore %s" % areas_en[zone], "探索%s" % areas_zh[zone],
                "Explore %s, revealing the covered areas of the world map." % areas_en[zone],
                "探索%s，揭示世界地图上被覆盖的区域。" % areas_zh[zone], "INV_Misc_Map_01")
        for o in sorted(ovs, key=lambda o: areas_en.get(o[2], "")):
            ids = [x for x in o[2:6] if x]
            a.add(EXPLORE_AREA, 1, ids, areas_en.get(ids[0], str(ids[0])), areas_zh.get(ids[0], str(ids[0])))
        out.append(a)
        explore[mapid].append(a)

    # Metas.
    def meta(id, cat, en, zh, den, dzh, icon, parts, points=10, faction=BOTH):
        a = Ach(id, cat, en, zh, den, dzh, icon, points=points, faction=faction)
        for p in parts:
            a.add(EARN_ACHIEVEMENT, 1, [p.id], p.en, p.zh)
        out.append(a)
        return a

    cont = {0: ("Eastern Kingdoms", "东部王国"), 1: ("Kalimdor", "卡利姆多")}
    loremasters = {ALLIANCE: [], HORDE: []}
    for i, (mapid, team) in enumerate(sorted(lore)):
        en, zh = cont[mapid]
        loremasters[team].append(meta(1151 + i, 2, "Loremaster of %s" % en, "%s博学者" % zh,
                                      "Complete the quest achievements of %s." % en, "完成%s的所有任务成就。" % zh,
                                      "INV_Misc_Book_08", lore[(mapid, team)], faction=team))
    for i, team in enumerate((ALLIANCE, HORDE)):
        meta(1155 + i, 2, "Loremaster", "博学者", "Complete the Loremaster achievements of both continents.",
             "完成两块大陆的博学者成就。", "INV_Misc_Book_04", loremasters[team], points=25, faction=team)

    ek = meta(1201, 3, "Explore Eastern Kingdoms", "探索东部王国", "Explore the regions of Eastern Kingdoms.",
              "探索东部王国的所有地区。", "INV_Misc_Spyglass_02", explore[0], points=25)
    kal = meta(1202, 3, "Explore Kalimdor", "探索卡利姆多", "Explore the regions of Kalimdor.",
               "探索卡利姆多的所有地区。", "INV_Misc_Spyglass_02", explore[1], points=25)
    meta(1203, 3, "World Explorer", "世界探索者", "Explore Eastern Kingdoms and Kalimdor.",
         "探索东部王国和卡利姆多。", "INV_Misc_Spyglass_03", [ek, kal], points=50)

    # Dungeons and raids.
    bosses = creature_names([e for d in DUNGEONS + RAIDS for e in d[4]])

    def instance(id, cat, en, zh, icon, entries):
        names_en = [bosses[e][0] for e in entries]
        names_zh = [bosses[e][1] for e in entries]
        a = Ach(id, cat, en, zh, "Defeat %s." % ", ".join(names_en), "击败%s。" % "、".join(names_zh), icon)
        for e in entries:
            a.add(KILL_CREATURE, 1, [e], bosses[e][0], bosses[e][1])
        out.append(a)
        return a

    dungeons = [instance(d[0], 41, d[1], d[2], d[3], d[4]) for d in DUNGEONS]
    raids = [instance(d[0], 42, d[1], d[2], d[3], d[4]) for d in RAIDS]
    meta(1399, 41, "Classic Dungeonmaster", "经典地下城大师", "Complete the classic dungeon achievements.",
         "完成所有经典地下城成就。", "INV_Misc_Bone_HumanSkull_01", dungeons, points=25)
    meta(1499, 42, "Classic Raider", "经典团队副本攻略者", "Complete the classic raid achievements.",
         "完成所有经典团队副本成就。", "INV_Misc_Bone_ElfSkull_01", raids, points=25)

    for a in out:
        if not icon_exists(a.icon):
            sys.exit("missing icon %s (achievement %d)" % (a.icon, a.id))
    return out, quests


# ------------------------------------------------------------------ output --

def sql_str(s):
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'") + "'"


def write_sql(path, mig, achs):
    lines = []
    w = lines.append
    w("DROP PROCEDURE IF EXISTS add_migration;")
    w("DELIMITER ??")
    w("CREATE PROCEDURE `add_migration`()")
    w("BEGIN")
    w("DECLARE v INT DEFAULT 1;")
    w("SET v = (SELECT COUNT(*) FROM `migrations` WHERE `id`='%s');" % mig)
    w("IF v = 0 THEN")
    w("INSERT INTO `migrations` VALUES ('%s');" % mig)
    w("-- Add your query below.")
    w("")
    w("-- Generated by tools/achievements/gen-achievements.py; edit that, not this.")
    w("-- Achievements (AchievementMgr). faction: 0 both, 1 Alliance, 2 Horde.")
    w("-- required_count: criteria needed, 0 = all of them.")
    w("CREATE TABLE IF NOT EXISTS `achievement_template` (")
    w("  `id` int(11) unsigned NOT NULL,")
    w("  `category` smallint(5) unsigned NOT NULL DEFAULT '0',")
    w("  `faction` tinyint(3) unsigned NOT NULL DEFAULT '0',")
    w("  `points` tinyint(3) unsigned NOT NULL DEFAULT '10',")
    w("  `required_count` tinyint(3) unsigned NOT NULL DEFAULT '0',")
    w("  `name` varchar(100) NOT NULL DEFAULT '',")
    w("  `name_loc4` varchar(100) NOT NULL DEFAULT '',")
    w("  PRIMARY KEY (`id`)")
    w(") ENGINE=MyISAM DEFAULT CHARSET=utf8;")
    w("")
    w("-- type: 1 reach level, 2 quests completed, 3 quests completed in zone asset1,")
    w("-- 4 explore any of the areas asset1..4, 5 kill creature asset1, 6 earn")
    w("-- achievement asset1, 7 complete quest asset1. value: the amount needed.")
    w("CREATE TABLE IF NOT EXISTS `achievement_criteria` (")
    w("  `id` int(11) unsigned NOT NULL,")
    w("  `achievement` int(11) unsigned NOT NULL,")
    w("  `type` tinyint(3) unsigned NOT NULL,")
    w("  `asset1` int(11) unsigned NOT NULL DEFAULT '0',")
    w("  `asset2` int(11) unsigned NOT NULL DEFAULT '0',")
    w("  `asset3` int(11) unsigned NOT NULL DEFAULT '0',")
    w("  `asset4` int(11) unsigned NOT NULL DEFAULT '0',")
    w("  `value` int(11) unsigned NOT NULL DEFAULT '1',")
    w("  PRIMARY KEY (`id`),")
    w("  KEY `achievement` (`achievement`)")
    w(") ENGINE=MyISAM DEFAULT CHARSET=utf8;")
    w("")
    w("DELETE FROM `achievement_template`;")
    w("DELETE FROM `achievement_criteria`;")
    for i in range(0, len(achs), 50):
        w("INSERT INTO `achievement_template` (`id`, `category`, `faction`, `points`, `required_count`, `name`, `name_loc4`) VALUES")
        w(",\n".join("(%d, %d, %d, %d, %d, %s, %s)" % (a.id, a.cat, a.faction, a.points, a.required,
                                                        sql_str(a.en), sql_str(a.zh)) for a in achs[i:i + 50]) + ";")
    crit = [(a, c) for a in achs for c in a.criteria]
    for i in range(0, len(crit), 100):
        w("INSERT INTO `achievement_criteria` (`id`, `achievement`, `type`, `asset1`, `asset2`, `asset3`, `asset4`, `value`) VALUES")
        w(",\n".join("(%d, %d, %d, %d, %d, %d, %d, %d)" % (c[0], a.id, c[1], c[2][0], c[2][1], c[2][2], c[2][3], c[3])
                     for a, c in crit[i:i + 100]) + ";")
    w("")
    w("-- End of migration.")
    w("END IF;")
    w("END??")
    w("DELIMITER ;")
    w("CALL add_migration();")
    w("DROP PROCEDURE IF EXISTS add_migration;")
    open(path, "w").write("\n".join(lines) + "\n")


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write_lua(path, achs):
    lines = []
    w = lines.append
    w("-- Generated by tools/achievements/gen-achievements.py; edit that, not this.")
    w("-- The server's achievement_template / achievement_criteria, with the texts.")
    w("--   cats[i]    = { id, parent, en, zh }")
    w("--   list[i]    = { id, category, faction (0 both, 1 Alliance, 2 Horde), points,")
    w("--                  icon, en, zh, description en, description zh, bar,")
    w("--                  criteria = { { id, type, value, asset, en, zh }, ... } }")
    w("SoloAchievementData = {")
    w("  cats = {")
    for c in CATEGORIES:
        w("    { %d, %d, %s, %s }," % (c[0], c[1], lua_str(c[2]), lua_str(c[3])))
    w("  },")
    w("  list = {")
    for a in achs:
        crit = ", ".join("{ %d, %d, %d, %d, %s, %s }" % (c[0], c[1], c[3], c[2][0], lua_str(c[4]), lua_str(c[5]))
                         for c in a.criteria)
        w("    { %d, %d, %d, %d, %s, %s, %s, %s, %s, %s, { %s } }," % (
            a.id, a.cat, a.faction, a.points, lua_str(a.icon), lua_str(a.en), lua_str(a.zh),
            lua_str(a.den), lua_str(a.dzh), "true" if a.bar else "false", crit))
    w("  },")
    w("}")
    open(path, "w").write("\n".join(lines) + "\n")


def main():
    if len(sys.argv) != 2 or len(sys.argv[1]) != 14 or not sys.argv[1].isdigit():
        sys.exit(__doc__)
    mig = sys.argv[1]
    with tempfile.TemporaryDirectory() as tmp:
        achs, quests = build(tmp)
    write_sql(os.path.join(ROOT, "server/core/sql/migrations/%s_world.sql" % mig), mig, achs)
    os.makedirs(os.path.join(ROOT, "Interface/AddOns/Achievements"), exist_ok=True)
    write_lua(os.path.join(ROOT, "Interface/AddOns/Achievements/Data.lua"), achs)
    by_cat = collections.Counter(a.cat for a in achs)
    print("%d achievements, %d criteria; by category %s" % (
        len(achs), sum(len(a.criteria) for a in achs), dict(sorted(by_cat.items()))))


if __name__ == "__main__":
    main()
