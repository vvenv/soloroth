#!/usr/bin/env python3
"""Bake soloroth-ui achievement catalog from gen-achievements.build().

  tools/achievements/bake-client-data.py

Writes client/crates/soloroth-ui/src/product/achievements_data.rs
(titles, descriptions, points, criteria names). Needs Data/, mpqx, and
MariaDB (creature locales) — same inputs as gen-achievements.py.
"""
import importlib.util
import os
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "client/crates/soloroth-ui/src/product/achievements_data.rs")
GEN = os.path.join(os.path.dirname(os.path.abspath(__file__)), "gen-achievements.py")


def load_gen():
    spec = importlib.util.spec_from_file_location("gen_achievements", GEN)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def rust_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write_rs(path, cats, achs):
    lines = []
    w = lines.append
    w("//! Baked achievement catalog (from tools/achievements/bake-client-data.py).")
    w("//! Do not edit by hand — regenerate from gen-achievements.build().")
    w("")
    w("#[derive(Clone, Copy, Debug)]")
    w("pub struct AchCat { pub id: u32, pub zh: &'static str }")
    w("")
    w("/// Left-rail categories; id 0 is the overview pane.")
    w("pub const ACH_CATS: &[AchCat] = &[")
    for c in cats:
        w("    AchCat { id: %d, zh: %s }," % (c[0], rust_str(c[1])))
    w("];")
    w("")
    w("#[derive(Clone, Copy, Debug)]")
    w("pub struct AchCrit { pub id: u32, pub value: u32, pub zh: &'static str }")
    w("")
    w("#[derive(Clone, Copy, Debug)]")
    w("pub struct AchRow {")
    w("    pub id: u32,")
    w("    pub category: u32,")
    w("    pub points: u32,")
    w("    pub zh: &'static str,")
    w("    pub dzh: &'static str,")
    w("    pub icon: &'static str,")
    w("    pub criteria: &'static [AchCrit],")
    w("}")
    w("")
    # Emit criteria arrays first so AchRow can reference them.
    for a in achs:
        w("static CRIT_%d: &[AchCrit] = &[" % a.id)
        for cid, typ, assets, value, en, zh in a.criteria:
            label = zh or en or str(cid)
            if typ == 1 and not zh:
                label = "达到%d级" % value
            w("    AchCrit { id: %d, value: %d, zh: %s }," % (cid, value, rust_str(label)))
        w("];")
        w("")
    w("pub const ACH_ROWS: &[AchRow] = &[")
    for a in achs:
        w(
            "    AchRow { id: %d, category: %d, points: %d, zh: %s, dzh: %s, icon: %s, criteria: CRIT_%d },"
            % (a.id, a.cat, a.points, rust_str(a.zh), rust_str(a.dzh), rust_str(a.icon), a.id)
        )
    w("];")
    w("")
    w("/// Legacy level-only slice used by older paint paths.")
    w("pub const ACH_LEVEL: &[AchRow] = &[")
    for a in achs:
        if a.cat == 1:
            w("    AchRow { id: %d, category: %d, points: %d, zh: %s, dzh: %s, icon: %s, criteria: CRIT_%d },"
              % (a.id, a.cat, a.points, rust_str(a.zh), rust_str(a.dzh), rust_str(a.icon), a.id))
    w("];")
    w("")
    open(path, "w").write("\n".join(lines) + "\n")


def main():
    gen = load_gen()
    with tempfile.TemporaryDirectory() as tmp:
        achs = gen.build(tmp)
    cats = [
        (0, "总览"),
        (1, "综合"),
        (3, "探索"),
        (4, "地下城与副本"),
        (5, "轶事"),
        (6, "旅程"),
    ]
    write_rs(OUT, cats, achs)
    print("wrote %s (%d achievements, %d criteria)" % (
        OUT, len(achs), sum(len(a.criteria) for a in achs)))


if __name__ == "__main__":
    main()
