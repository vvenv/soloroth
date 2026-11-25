#!/usr/bin/env python3
"""Achievement definitions: one source for the server table and the addon.

  tools/achievements/gen-achievements.py <migration id, YYYYmmddHHMMSS>

Writes
  server/core/sql/migrations/<id>_world.sql     achievement_template and
                                                achievement_criteria, replaced
  ui/world/Achievements/Data.lua                 the same, plus the texts and
                                                icons the window shows

The achievements are the WoW 3.x ones that the 1.12 world holds without a
quest log: levels, exploring every zone, the classic dungeons and raids, a
Feats set (world bosses, famous rares, outdoor bosses Classic only summoned
for quests), and Journeys (explore the chapter's zones and clear its
dungeons). Soloroth has no quest UI, so there is no Quests category, no
Loremaster, and no "complete quest X" criteria.

Exploration criteria are the client's WorldMapOverlay rows, as in 3.x: an
overlay counts once any of its areas is explored. Read from the zhCN
client's DBCs (and the enUS DBCs vmangos extracted, for English names).

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

# Criteria types (AchievementMgr.h keeps the same numbers; 2/3/7 quest types unused).
REACH_LEVEL, EXPLORE_AREA, KILL_CREATURE, EARN_ACHIEVEMENT = 1, 4, 5, 6
BOTH, ALLIANCE, HORDE = 0, 1, 2

# Categories: id, parent, english, chinese.
CATEGORIES = [
    (1, 0, "General", "综合"),
    (3, 0, "Exploration", "探索"),
    (31, 3, "Eastern Kingdoms", "东部王国"),
    (32, 3, "Kalimdor", "卡利姆多"),
    (4, 0, "Dungeons & Raids", "地下城与团队副本"),
    (41, 4, "Classic Dungeons", "经典地下城"),
    (42, 4, "Classic Raids", "经典团队副本"),
    (5, 0, "Feats", "轶事"),
    (6, 0, "Journeys", "旅程"),
]

# The old world as four chapters of one journey, in the order the stories run
# and the levels rise: (id, en, zh, description en, zh, icon, zones, dungeons
# by faction). A chapter asks for the explore achievements of those zones and
# the dungeon achievements on the way.
CHAPTERS = [
    (1601, "Chapter I: Homelands", "第一章：家园",
     "Explore the homelands and clear the dungeons on the way.",
     "探索家园各区域，并打通沿途的副本。",
     "Ability_Townwatch",
     [12, 40, 44, 10, 1, 38, 11, 141, 148, 331, 14, 215, 17, 406, 85, 130],
     {1: [1303, 1302, 1304, 1305, 1306, 1307, 1308, 1310], 2: [1301, 1302, 1304, 1305, 1308, 1310]}),
    (1603, "Chapter II: Shadows of the Seven Kingdoms", "第二章：七大王国的残影",
     "Explore the old human kingdoms' lands and clear the Scarlet Monastery.",
     "探索旧人类王国的土地，并打通血色修道院。",
     "INV_BannerPVP_01",
     [267, 36, 45, 15],
     {1: [1309], 2: [1309]}),
    (1605, "Chapter III: Gods and Demigods", "第三章：神与半神",
     "Explore the lands around the titans' vaults and the trolls' temples, and clear their dungeons.",
     "探索泰坦宝库和巨魔神庙周边，并打通奥达曼、玛拉顿、祖尔法拉克和沉没的神庙。",
     "INV_Misc_Idol_02",
     [400, 33, 3, 405, 440, 8, 47, 357],
     {1: [1311, 1313, 1312, 1314], 2: [1311, 1313, 1312, 1314]}),
    (1607, "Chapter IV: Embers of the Old World", "第四章：旧世界的余烬",
     "Explore Blackrock, the Plaguelands and the far corners of both continents, and clear their dungeons.",
     "探索黑石山、瘟疫之地和两块大陆边陲，并打通沿途的副本。",
     "INV_Misc_Head_Dragon_Black",
     [51, 46, 139, 28, 4, 16, 490, 361, 618, 1377],
     {1: [1315, 1316, 1317, 1318, 1319, 1320], 2: [1315, 1316, 1317, 1318, 1319, 1320]}),
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
    out = []

    # General: levels.
    for i, lvl in enumerate(range(10, 70, 10)):
        a = Ach(1001 + i, 1, "Level %d" % lvl, "%d级" % lvl, "Reach level %d." % lvl, "达到%d级。" % lvl,
                LEVEL_ICONS[lvl], bar=True)
        a.add(REACH_LEVEL, lvl)
        out.append(a)

    # Zones, in the order of the world map: continent, then name.
    zones = []
    for m in maps:
        _, mapid, zone = m[0], m[1], m[2]
        if mapid not in (0, 1) or not zone or zone in CITIES:
            continue
        zones.append((mapid, zone, [o for o in overlays if o[1] == m[0]]))
    zones.sort(key=lambda z: (z[0], areas_en[z[1]]))

    explore = {0: [], 1: []}
    explore_by_zone = {}
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
        explore_by_zone[zone] = a

    # Metas.
    def meta(id, cat, en, zh, den, dzh, icon, parts, points=10, faction=BOTH):
        a = Ach(id, cat, en, zh, den, dzh, icon, points=points, faction=faction)
        for p in parts:
            a.add(EARN_ACHIEVEMENT, 1, [p.id], p.en, p.zh)
        out.append(a)
        return a

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

    # Feats: world bosses, famous rares, and outdoor bosses Classic only
    # summoned for quests (Soloroth gives them world spawns). Kill progress
    # is kept; no "complete quest" criteria — there is no quest log.
    feats_bosses = creature_names([
        314, 448, 645, 731, 1494, 2707, 2755, 2757, 2759, 2763, 2937, 4490, 5402,
        5828, 6239, 7664, 8075, 8391, 9453, 9456, 9684, 10373, 10581, 10737,
        10882, 12339, 14435, 14467, 15623, 6109, 7846, 12397, 14507, 14509,
        14510, 14515, 14517, 14887, 14888, 14889, 14890,
    ])

    def kill(id, en, zh, den, dzh, icon, entry, points=10, n=1, bar=False):
        name_en, name_zh = feats_bosses[entry]
        a = Ach(id, 5, en, zh, den, dzh, icon, points=points, bar=bar)
        a.add(KILL_CREATURE, n, [entry], name_en, name_zh)
        out.append(a)
        return a

    kill(1501, "Hogger", "霍格", "Defeat Hogger.", "击败霍格。",
         "Ability_Hunter_Pet_Wolf", 448)
    kill(1502, "Again?", "又是你？", "Defeat Hogger 10 times.", "击败霍格10次。",
         "INV_Misc_MonsterClaw_03", 448, n=10, bar=True)
    kill(1504, "Cookie's Specialty", "厨子的拿手菜", "Defeat Cookie in the Deadmines.",
         "在死亡矿井击败曲奇。", "INV_Misc_Food_16", 645)
    kill(1505, "Humar the Pridelord", "狮王修玛", "Defeat Humar the Pridelord in the Barrens.",
         "在贫瘠之地击败狮王修玛。", "Ability_Mount_JungleTiger", 5828)
    kill(1506, "Teremus the Devourer", "吞噬者特雷姆斯",
         "Defeat Teremus the Devourer in the Blasted Lands.",
         "在诅咒之地击败吞噬者特雷姆斯。", "INV_Misc_Head_Dragon_01", 7846)
    kazzak = kill(1507, "Lord Kazzak", "卡扎克", "Defeat Lord Kazzak.", "击败卡扎克。",
                  "Spell_Shadow_SummonVoidWalker", 12397, points=25)
    azuregos = kill(1508, "Azuregos", "艾索雷葛斯", "Defeat Azuregos.", "击败艾索雷葛斯。",
                    "INV_Misc_Head_Dragon_Blue", 6109, points=25)
    emeriss = kill(1509, "Emeriss", "艾莫莉丝", "Defeat Emeriss.", "击败艾莫莉丝。",
                   "INV_Misc_Head_Dragon_Green", 14889, points=25)
    lethon = kill(1510, "Lethon", "莱索恩", "Defeat Lethon.", "击败莱索恩。",
                  "INV_Misc_Head_Dragon_Green", 14888, points=25)
    ysondre = kill(1511, "Ysondre", "伊索德雷", "Defeat Ysondre.", "击败伊索德雷。",
                   "INV_Misc_Head_Dragon_Green", 14887, points=25)
    taerar = kill(1512, "Taerar", "泰拉尔", "Defeat Taerar.", "击败泰拉尔。",
                  "INV_Misc_Head_Dragon_Green", 14890, points=25)
    nightmare = meta(1513, 5, "Dragons of Nightmare", "梦魇巨龙",
                     "Defeat the four Dragons of Nightmare.", "击败四条梦魇巨龙。",
                     "Spell_Nature_ForceOfNature", [emeriss, lethon, ysondre, taerar], points=25)
    meta(1514, 5, "World Bosses", "世界首领",
         "Defeat Lord Kazzak, Azuregos, and the Dragons of Nightmare.",
         "击败卡扎克、艾索雷葛斯和梦魇巨龙。",
         "INV_Misc_Head_Dragon_Black", [kazzak, azuregos, nightmare], points=50)

    # ZG high priests before Hakkar (Hakkar itself is the raid achievement).
    zg = Ach(1515, 5, "High Priests of Zul'Gurub", "祖尔格拉布的高阶祭司",
             "Defeat the five High Priests of Zul'Gurub.",
             "击败祖尔格拉布的五位高阶祭司。", "INV_Misc_Head_Troll_01", points=25)
    for e in (14517, 14507, 14510, 14515, 14509):
        zg.add(KILL_CREATURE, 1, [e], feats_bosses[e][0], feats_bosses[e][1])
    out.append(zg)

    # Outdoor quest-summoned bosses (Soloroth gives them world spawns).
    # Prefer a kill feat when the fight is the point; quest-item loot still
    # counts for NoQuest turn-ins on its own.
    qs = []
    qs.append(kill(1523, "Eliza", "伊莉莎", "Defeat Eliza in Duskwood.",
                   "在暮色森林击败伊莉莎。", "Spell_Shadow_RaiseDead", 314))
    qs.append(kill(1524, "Negolash", "奈古拉什", "Defeat Negolash on the Savage Coast.",
                   "在野人海岸击败奈古拉什。", "INV_Misc_Head_Dragon_01", 1494))
    qs.append(kill(1525, "Blacklash", "布莱克拉什", "Defeat Blacklash in the Badlands.",
                   "在荒芜之地击败布莱克拉什。", "INV_Misc_Head_Dragon_Bronze", 2757))
    qs.append(kill(1526, "Hematus", "赫玛图斯", "Defeat Hematus in the Badlands.",
                   "在荒芜之地击败赫玛图斯。", "INV_Misc_Head_Dragon_Bronze", 2759))
    qs.append(kill(1527, "Thenan", "瑟恩纳", "Defeat Thenan in Arathi Highlands.",
                   "在阿拉希高地击败瑟恩纳。", "INV_Stone_15", 2763))
    qs.append(kill(1528, "Myzrael", "密斯莱尔", "Defeat Myzrael in Arathi Highlands.",
                   "在阿拉希高地击败密斯莱尔。", "Spell_Nature_Earthquake", 2755))
    qs.append(kill(1529, "Dagun the Ravenous", "贪婪的达古恩",
                   "Defeat Dagun the Ravenous in the Wetlands.",
                   "在湿地击败贪婪的达古恩。", "Spell_Frost_SummonWaterElemental", 2937))
    qs.append(kill(1530, "Shadra", "沙德拉", "Defeat Shadra in the Hinterlands.",
                   "在辛特兰击败沙德拉。", "Ability_PoisonSting", 2707))
    qs.append(kill(1531, "Cyclonian", "塞克隆尼亚", "Defeat Cyclonian in the Alterac Mountains.",
                   "在奥特兰克山脉击败塞克隆尼亚。", "Spell_Nature_EarthBind", 6239))
    qs.append(kill(1532, "Lathoric the Black", "黑衣拉索里克",
                   "Defeat Lathoric the Black in Searing Gorge.",
                   "在灼热峡谷击败黑衣拉索里克。", "Spell_Shadow_SummonVoidWalker", 8391))
    qs.append(kill(1533, "Razelikh the Defiler", "污染者拉瑟莱克",
                   "Defeat Razelikh the Defiler in the Blasted Lands.",
                   "在诅咒之地击败污染者拉瑟莱克。", "Spell_Shadow_Metamorphosis", 7664))
    qs.append(kill(1534, "Demetria", "德米提雅", "Defeat Demetria in the Eastern Plaguelands.",
                   "在东瘟疫之地击败德米提雅。", "Spell_Holy_PrayerOfHealing", 12339))
    qs.append(kill(1535, "Arikara", "阿利卡拉", "Defeat Arikara in Thousand Needles.",
                   "在千针石林击败阿利卡拉。", "Ability_Hunter_Pet_WindSerpent", 10882))
    qs.append(kill(1536, "Young Arikara", "幼年阿利卡拉",
                   "Defeat Young Arikara in Thousand Needles.",
                   "在千针石林击败幼年阿利卡拉。", "Ability_Hunter_Pet_WindSerpent", 10581))
    qs.append(kill(1537, "Lar'korwi", "拉克维", "Defeat Lar'korwi in Un'Goro Crater.",
                   "在安戈洛环形山击败拉克维。", "Ability_Hunter_Pet_Raptor", 9684))
    qs.append(kill(1538, "Edana Hatetalon", "艾丹娜·邪爪", "Defeat Edana Hatetalon in Feralas.",
                   "在菲拉斯击败艾丹娜·邪爪。", "Ability_Hunter_Pet_Owl", 8075))
    qs.append(kill(1539, "Khan Hratha", "赫鲁萨可汗", "Defeat Khan Hratha in Desolace.",
                   "在凄凉之地击败赫鲁萨可汗。", "INV_Misc_Head_Centaur_01", 5402))
    qs.append(kill(1540, "Xabraxxis", "萨巴克希斯", "Defeat Xabraxxis in Ashenvale.",
                   "在灰谷击败萨巴克希斯。", "Spell_Shadow_SummonSuccubus", 10373))
    qs.append(kill(1541, "Warlord Krom'zar", "督军克罗姆扎",
                   "Defeat Warlord Krom'zar in the Barrens.",
                   "在贫瘠之地击败督军克罗姆扎。", "INV_Misc_Head_Centaur_01", 9456))
    qs.append(kill(1542, "Aquementas", "亚奎门塔斯", "Defeat Aquementas in Tanaris.",
                   "在塔纳利斯击败亚奎门塔斯。", "Spell_Frost_SummonWaterElemental", 9453))
    qs.append(kill(1543, "Shy-Rotam", "希洛塔姆", "Defeat Shy-Rotam in Winterspring.",
                   "在冬泉谷击败希洛塔姆。", "Ability_Hunter_Pet_Cat", 10737))
    qs.append(kill(1544, "Xandivious", "沙迪维尔斯", "Defeat Xandivious in Winterspring.",
                   "在冬泉谷击败沙迪维尔斯。", "Spell_Shadow_SummonFelHunter", 15623))
    qs.append(kill(1545, "Prince Thunderaan", "桑德兰王子",
                   "Defeat Prince Thunderaan in Silithus.",
                   "在希利苏斯击败桑德兰王子。", "Spell_Nature_EarthBind", 14435, points=25))
    qs.append(kill(1546, "Kroshius", "克罗苏斯", "Defeat Kroshius in Felwood.",
                   "在费伍德森林击败克罗苏斯。", "Spell_Fire_Incinerate", 14467))
    qs.append(kill(1547, "Grenka Bloodscreech", "格林卡·血啸",
                   "Defeat Grenka Bloodscreech in Thousand Needles.",
                   "在千针石林击败格林卡·血啸。", "Ability_Townwatch", 4490))
    qs.append(kill(1548, "King Bangalash", "虎王邦加拉什",
                   "Defeat King Bangalash in Stranglethorn Vale.",
                   "在荆棘谷击败虎王邦加拉什。", "Ability_Hunter_Pet_Cat", 731))
    meta(1549, 5, "Called Out", "现身受死",
         "Defeat the outdoor bosses that Classic only summoned for quests.",
         "击败那些原版只靠任务召唤的野外首领。",
         "INV_Misc_Horn_01", qs, points=25)

    # Journeys: the chapters, then the whole journey, per faction.
    by_id = {a.id: a for a in dungeons}
    for team in (ALLIANCE, HORDE):
        chapters = []
        for id, en, zh, den, dzh, icon, zone_ids, dungeon_ids in CHAPTERS:
            parts = [explore_by_zone[z] for z in zone_ids if z in explore_by_zone]
            parts += [by_id[d] for d in dungeon_ids[team]]
            chapters.append(meta(id + team - 1, 6, en, zh,
                                 den, dzh,
                                 icon, parts, points=25, faction=team))
        meta(1609 + team - 1, 6, "Journey Through the Old World", "旧世界的旅程",
             "Complete the four chapters of the journey.", "完成旅程的四个章节。",
             "INV_Misc_Book_10", chapters, points=50, faction=team)

    for a in out:
        if not icon_exists(a.icon):
            sys.exit("missing icon %s (achievement %d)" % (a.icon, a.id))
    return out


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
    w("-- type: 1 reach level, 4 explore any of the areas asset1..4, 5 kill creature")
    w("-- asset1, 6 earn achievement asset1. (2/3/7 quest types unused: no quest log.)")
    w("-- value: the amount needed.")
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
        achs = build(tmp)
    write_sql(os.path.join(ROOT, "server/core/sql/migrations/%s_world.sql" % mig), mig, achs)
    os.makedirs(os.path.join(ROOT, "ui/world/Achievements"), exist_ok=True)
    write_lua(os.path.join(ROOT, "ui/world/Achievements/Data.lua"), achs)
    by_cat = collections.Counter(a.cat for a in achs)
    print("%d achievements, %d criteria; by category %s" % (
        len(achs), sum(len(a.criteria) for a in achs), dict(sorted(by_cat.items()))))


if __name__ == "__main__":
    main()
