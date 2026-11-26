#!/usr/bin/env python3
"""The owner's approved preview auras -> the real game (plan 12, phase E).

    python tools/aura_to_game.py              # export every stand, update design/auras.json, run gen_auras.py
    python tools/aura_to_game.py --only=wheel_guardian,limitless_teacher     # re-export some heroes
    python tools/aura_to_game.py --dry        # export nothing: show what would be assigned

WHAT IT DOES
  1. Reads design/aura_assignments.json (written by `python tools/aura_assign.py plan`: who wears what on the
     preview yard, the owner's rules) and the CUSTOM table of tools/aura_assign.py.
  2. A hero with a hand-built aura (CUSTOM) keeps its own template: its line in design/auras.json "heroes" is
     that template's key.
  3. Every other aura hero: tools/studio/export_preview_auras.luau captures its stand in Studio as
     ReplicatedStorage.Assets.Auras.H_<heroId>; the template is registered in design/auras.json "templates" as
     a "custom" one (so tools/studio/build_auras.luau never rebuilds or removes it) with a tier by its live
     particles, and the hero's line is "H_<heroId>".
  4. The by_rarity pools are emptied: since the owner's assignment every aura is a hero's own line, and
     Common and Uncommon heroes wear none.
  5. python tools/gen_auras.py (Auras.luau).

Studio must be in EDIT mode with the preview yard built. The place then has to be SAVED for the templates to
ship (only on the owner's word).
"""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import aura_assign  # noqa: E402

SPEC = ROOT / "design" / "auras.json"
PLAN = ROOT / "design" / "aura_assignments.json"
EXPORTER = ROOT / "tools" / "studio" / "export_preview_auras.luau"
MCP = Path.home() / ".claude" / "skills" / "create-roblox-game" / "scripts" / "studio_mcp.py"
EXPORT_TAG = "tools/studio/export_preview_auras.luau"
# live-particle ceiling of an EXPORTED aura by the hero's rarity (rates are scaled down to it). Only the Rare
# aura needs one: it runs about 500 on the yard, and a base holds many Rares under one shared runtime budget.
CAP_BY_RARITY = {"Rare": 200}


def tier_for(spec: dict, live: int) -> str:
    """The smallest tier whose cap holds the aura as approved (rates are NOT scaled: the owner judged this look)."""
    for name in "ABCDE":
        if live <= spec["tiers"][name]["cap"]:
            return name
    return "E"


def run_export(skip: list[str], only: list[str], caps: dict[str, int]) -> dict[str, tuple[str, int, int]]:
    def table(ids: list[str]) -> str:
        return "{" + ", ".join(f"[{json.dumps(i)}] = true" for i in ids) + "}"
    cap = "{" + ", ".join(f"[{json.dumps(i)}] = {n}" for i, n in sorted(caps.items())) + "}"
    head = "_G.EXPORT_AURAS = { skip = %s, cap = %s%s }\n" % (table(skip), cap,
                                                              (", only = " + table(only)) if only else "")
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False, encoding="utf8", newline="\n") as f:
        f.write(head + EXPORTER.read_text(encoding="utf-8"))
        path = f.name
    r = subprocess.run([sys.executable, str(MCP), "luau", "--dm", "Edit", "--file", path], capture_output=True,
                       text=True, encoding="utf8", errors="replace")
    Path(path).unlink(missing_ok=True)
    out: dict[str, tuple[str, int, int]] = {}
    problems = []
    for line in (r.stdout + r.stderr).splitlines():
        parts = line.split()
        if len(parts) == 4 and parts[1].startswith("H_") and parts[2].isdigit():
            out[parts[0]] = (parts[1], int(parts[2]), int(parts[3]))
        elif "FAIL" in line or "NONE" in line:
            problems.append(line.strip())
    for p in problems:
        print("  ! " + p)
    if not out and not problems:
        raise SystemExit("export returned nothing:\n" + (r.stdout + r.stderr)[-800:])
    return out


def main() -> int:
    dry = "--dry" in sys.argv
    only = [a.split("=", 1)[1] for a in sys.argv if a.startswith("--only=")]
    only = only[0].split(",") if only else []
    spec = json.loads(SPEC.read_text(encoding="utf-8"))
    plan = json.loads(PLAN.read_text(encoding="utf-8"))["heroes"]
    custom = {hid: key for hid, (key, _why) in aura_assign.CUSTOM.items()}
    for hid, key in custom.items():
        if key not in spec["templates"] or "custom" not in spec["templates"][key]:
            raise SystemExit(f"CUSTOM hero {hid}: {key} is not a hand-built template in design/auras.json")
    wanted = [h["id"] for h in plan if h["id"] not in custom]
    print(f"{len(plan)} heroes wear an aura on the yard: {len(custom)} hand-built, {len(wanted)} to export")
    if dry:
        return 0

    caps = {h["id"]: CAP_BY_RARITY[h["rarity"]] for h in plan if h["rarity"] in CAP_BY_RARITY}
    exported = run_export(sorted(custom), only, caps)
    print(f"exported {len(exported)} stands")
    templates = spec["templates"]
    heroes = {k: v for k, v in spec["heroes"].items() if k.startswith("_")}
    old_lines = {k: v for k, v in spec["heroes"].items() if not k.startswith("_")}
    if only:
        heroes.update(old_lines)  # a partial run keeps every other line
    else:
        for key in [k for k, v in templates.items() if v.get("custom") == EXPORT_TAG]:
            del templates[key]  # templates of heroes that no longer wear an exported aura
    missing = []
    for h in plan:
        hid = h["id"]
        if hid in custom:
            heroes[hid] = custom[hid]
        elif hid in exported:
            key, live, _pieces = exported[hid]
            templates[key] = {"custom": EXPORT_TAG, "tier": tier_for(spec, live), "live": live}
            heroes[hid] = key
        elif not only:
            missing.append(hid)
    if missing:
        print(f"  ! {len(missing)} aura heroes have no exported stand: {missing}")
    heroes["_note"] = ("Since 2026-11-26 (plan 12 phase E) every line is the owner's approved assignment: a hand-built "
                       "aura's key, or H_<heroId> = that hero's preview stand captured by tools/aura_to_game.py. "
                       "Do not hand-edit H_ lines: re-run the tool.")
    spec["heroes"] = dict(sorted(heroes.items(), key=lambda kv: (not kv[0].startswith("_"), kv[0])))
    for rarity, pool in spec["by_rarity"].items():
        if isinstance(pool, list):
            spec["by_rarity"][rarity] = []
    spec["by_rarity"]["_note"] = ("EMPTY on purpose since 2026-11-26: the owner assigned every aura hero by name "
                                  "(tools/aura_assign.py); Common and Uncommon heroes wear no aura. A hero with no "
                                  "line in 'heroes' has no aura.")
    SPEC.write_text(json.dumps(spec, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    by_tier: dict[str, int] = {}
    for key, live, _ in exported.values():
        t = tier_for(spec, live)
        by_tier[t] = by_tier.get(t, 0) + 1
    lives = sorted(live for _k, live, _p in exported.values())
    print(f"design/auras.json: {len([k for k in spec['heroes'] if not k.startswith('_')])} hero lines; "
          f"exported by tier {dict(sorted(by_tier.items()))}; live particles median {lives[len(lives) // 2]}, "
          f"max {lives[-1]}")
    r = subprocess.run([sys.executable, str(ROOT / "tools" / "gen_auras.py")], capture_output=True, text=True,
                       encoding="utf8", errors="replace", cwd=ROOT)
    print((r.stdout + r.stderr).strip().splitlines()[-1])
    return r.returncode


if __name__ == "__main__":
    sys.exit(main())
