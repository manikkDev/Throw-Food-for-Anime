#!/usr/bin/env python3
"""Hero auras: design/auras.json -> src/shared/Config/Auras.luau (+ the Studio build script).

    python tools/gen_auras.py            write Auras.luau and work/auras/build.luau
    python tools/gen_auras.py --check    exit 1 if Auras.luau has drifted (a gate step)

Auras.luau maps every hero id (lane + premium, from design/game.json) to an aura key, either the
hand-matched line in "heroes" or a stable pick (crc32 of the id) from its rarity's pool, plus each
key's tier/cap, the "hot" marks (auras thinned at high graphics, see src/shared/Core/AuraDensity.luau)
and the runtime budget. work/auras/build.luau is tools/studio/build_auras.luau with
the template spec embedded: run it in Studio EDIT mode to (re)build ReplicatedStorage.Assets.Auras.
"""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SPEC = ROOT / "design" / "auras.json"
GAME = ROOT / "design" / "game.json"
OUT = ROOT / "src" / "shared" / "Config" / "Auras.luau"
BUILDER = ROOT / "tools" / "studio" / "build_auras.luau"
BUILD_OUT = ROOT / "work" / "auras" / "build.luau"


def lua(v) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return json.dumps(v)
    raise TypeError(v)


def assignments(spec: dict, game: dict) -> dict[str, str]:
    cfg = game["config"]
    pools = spec["by_rarity"]
    hand = {k: v for k, v in spec["heroes"].items() if not k.startswith("_")}
    out: dict[str, str] = {}
    rows = [(c["Id"], c.get("Rarity")) for c in cfg["Characters"]]
    rows += [(p["Id"], None) for p in cfg["PremiumCharacters"]]
    for hid, rarity in rows:
        if hid in hand:
            out[hid] = hand[hid]
            continue
        pool = pools.get(rarity or "", []) if rarity else []
        if pool:
            out[hid] = pool[zlib.crc32(hid.encode()) % len(pool)]
    for hid, key in out.items():
        if key not in spec["templates"]:
            raise SystemExit(f"FAIL hero {hid} -> unknown aura key {key}")
    return out


def hot_marks(spec: dict, worn: dict[str, str]) -> dict[str, float]:
    """design/auras.json "hot" (hero id -> the share of its rate the aura may be drawn at) by aura KEY.
    Heroes sharing a template share its mark: the lowest wins."""
    out: dict[str, float] = {}
    for hid, mark in spec.get("hot", {}).items():
        if hid.startswith("_"):
            continue
        if hid not in worn:
            raise SystemExit(f"FAIL hot: {hid} wears no aura")
        if not 0 < mark < 1:
            raise SystemExit(f"FAIL hot: {hid} = {mark}: a mark is a share between 0 and 1")
        key = worn[hid]
        out[key] = min(out.get(key, 1.0), mark)
    return out


def render(spec: dict, game: dict) -> str:
    tiers = spec["tiers"]
    lines = [
        "--!strict",
        "-- GENERATED FILE - DO NOT EDIT BY HAND.",
        "-- Source: design/auras.json (+ hero ids from design/game.json)",
        "-- Regenerate: python tools/gen_auras.py",
        "-- Hero id -> aura key (ReplicatedStorage.Assets.Auras.<Key>), key -> tier, and the runtime budget.",
        "",
        "export type Budget = { MaxLive: number, Range: number, ParticleBudget: number, RateScale: number }",
        "",
        "local Auras: {",
        "\tByHero: { [string]: string },",
        "\tTiers: { [string]: string },",
        "\t--- aura key -> the share of its rate it may be DRAWN at (Core/AuraDensity): the hot auras only",
        "\tHot: { [string]: number },",
        "\tBudget: Budget,",
        "\tLowDetail: Budget,",
        "} = {",
        "\tByHero = {",
    ]
    worn = assignments(spec, game)
    for hid, key in sorted(worn.items()):
        lines.append(f"\t\t{hid} = {lua(key)},")
    lines += ["\t},", "\tTiers = {"]
    for key, row in sorted(spec["templates"].items()):
        lines.append(f"\t\t{key} = {lua(row['tier'])},")
    lines += ["\t},", "\tHot = {"]
    for key, mark in sorted(hot_marks(spec, worn).items()):
        lines.append(f"\t\t{key} = {lua(mark)},")
    b = spec["budget"]
    lo = b["low_detail"]
    lines += [
        "\t},",
        f"\tBudget = {{ MaxLive = {b['max_live']}, Range = {b['range']}, ParticleBudget = {b['particle_budget']}, RateScale = 1 }},",
        f"\tLowDetail = {{ MaxLive = {lo['max_live']}, Range = {lo['range']}, ParticleBudget = {lo['particle_budget']}, RateScale = {lo['rate_scale']} }},",
        "}",
        "",
        "return Auras",
        "",
    ]
    del tiers
    return "\n".join(lines)


def build_script(spec: dict) -> str:
    rows = []
    for key, row in sorted(spec["templates"].items()):
        if "custom" in row:
            # hand-authored aura (own textures): built by its own Studio script, row["custom"]
            continue
        tier = spec["tiers"][row["tier"]]
        size = row.get("size", tier.get("size", 6))
        reach = row.get("reach", tier.get("reach", 6))
        rows.append(
            "\t{ key = %s, source = %s, rig = %d, cap = %d, tier = %s, size = %s, reach = %s },"
            % (json.dumps(key), json.dumps(row["source"]), row.get("rig", 1), tier["cap"],
               json.dumps(row["tier"]), size, reach)
        )
    head = "_G.AURA_SPEC = {\n" + "\n".join(rows) + "\n}\n"
    body = BUILDER.read_text(encoding="utf-8")
    tail = "\n"
    return head + body.replace("\nreturn table.concat(report, \"\\n\")", "\n_G.AURA_SPEC = nil\nreturn table.concat(report, \"\\n\")") + tail


def fmt(text: str) -> str:
    """The text as stylua (the code gate) would write it, so --check compares like with like."""
    exe = shutil.which("stylua")
    if not exe:
        return text
    r = subprocess.run([exe, "--stdin-filepath", str(OUT), "-"], input=text, capture_output=True,
                       text=True, encoding="utf-8", cwd=ROOT)
    return r.stdout if r.returncode == 0 and r.stdout else text


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    spec = json.loads(SPEC.read_text(encoding="utf-8"))
    game = json.loads(GAME.read_text(encoding="utf-8"))
    text = fmt(render(spec, game))
    if a.check:
        if not OUT.exists() or OUT.read_text(encoding="utf-8") != text:
            print(f"FAIL {OUT} has drifted from design/auras.json; run tools/gen_auras.py")
            return 1
        print(f"ok   Auras matches design/auras.json ({text.count(' = \"') } heroes/keys)")
        return 0
    OUT.write_text(text, encoding="utf-8", newline="\n")
    BUILD_OUT.parent.mkdir(parents=True, exist_ok=True)
    BUILD_OUT.write_text(build_script(spec), encoding="utf-8", newline="\n")
    n = len(assignments(spec, game))
    print(f"wrote {OUT} ({n} heroes with an aura) and {BUILD_OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
