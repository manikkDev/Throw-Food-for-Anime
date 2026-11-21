#!/usr/bin/env python3
"""Build Workspace.ZoneLab in Studio from the zone plan (design/zones/anime_zones.json).

    python tools/studio/zone_lab.py

One column per planned anime zone, heroes sorted by rarity front to back, grey pads for the
characters to import next and empty pads for spare room. Studio must be open in EDIT mode with
the Studio MCP on. Dev only: the server deletes Workspace.ZoneLab on start.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PLAN = ROOT / "design" / "zones" / "anime_zones.json"
ROSTER = ROOT / "design" / "characters" / "roster.json"
GAME = ROOT / "design" / "game.json"
BUILDER = ROOT / "tools" / "studio" / "build_zone_lab.luau"
SLOTS = ROOT / "design" / "zones" / "lab_slots.json"  # zone anime -> names in pad order (row = index)
WORK = ROOT / "work" / "zones"
MCP = Path.home() / ".claude" / "skills" / "create-roblox-game" / "scripts" / "studio_mcp.py"
ORIGIN = (-1320, 320, -40)  # west of the aura showcase (its floor ends at x -896)
SPARE = 3  # empty pads behind the longest column
PREMIUM = "#FF5FA2"
ZONE_COLOURS = ["#FFB020", "#FF5A5A", "#3FB6FF", "#4FD18B", "#3F7BFF", "#9AE05A", "#FFD23F", "#C38BFF",
                "#B0B6C8", "#FF7A3D", "#E85AFF", "#7A6BFF", "#FFE27A", "#9AE6FF", "#8C7BFF", "#5A8CFF", "#FF9A3D"]


def lua_value(v) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return json.dumps(v)
    if isinstance(v, list):
        return "{" + ", ".join(lua_value(x) for x in v) + "}"
    if isinstance(v, dict):
        return "{" + ", ".join(f"{k} = {lua_value(x)}" for k, x in v.items()) + "}"
    raise TypeError(v)


def main() -> int:
    plan = json.loads(PLAN.read_text(encoding="utf-8"))
    roster = {r["Source"]: r for r in json.loads(ROSTER.read_text(encoding="utf-8"))}
    cfg = json.loads(GAME.read_text(encoding="utf-8"))["config"]
    colour = {name: "#" + row["Color"].lstrip("#") for name, row in cfg["Rarities"].items()}
    colour["Premium"] = PREMIUM
    order = plan["rarities"] + ["Premium"]

    seen: set[str] = set()
    slots = json.loads(SLOTS.read_text(encoding="utf-8")) if SLOTS.exists() else {}
    zones, rows = [], 0
    for i, z in enumerate(plan["zones"]):
        heroes = []
        for c in z["characters"]:
            src = c["source"]
            assert src in roster, f"{src} is not in roster.json"
            assert src not in seen, f"{src} is in two zones"
            assert c["rarity"] in order, f"{src}: unknown rarity {c['rarity']}"
            seen.add(src)
            heroes.append({"source": src, "id": roster[src]["Id"], "alias": roster[src]["Name"],
                           "rarity": c["rarity"], "color": colour[c["rarity"]]})
        heroes.sort(key=lambda h: order.index(h["rarity"]))  # first build only; after that the pad order is frozen
        # Pads never move once built: the owner drops avatars onto them. A new hero takes the pad of the
        # same name (a suggestion becoming a hero); anything else goes on the next free pad.
        by_name = {h["source"]: h for h in heroes}
        names = list(slots.get(z["anime"]) or [h["source"] for h in heroes] + z.get("suggest", []))
        for n in [h["source"] for h in heroes] + z.get("suggest", []):
            if n not in names:
                names.append(n)
        slots[z["anime"]] = names
        rowsList = []
        for n in names:
            if n in by_name:
                rowsList.append({"hero": by_name[n]})
            elif n in z.get("suggest", []):
                rowsList.append({"suggest": n})
            else:
                rowsList.append({})
        zones.append({"n": z["n"], "anime": z["anime"], "title": z["title"], "mixed": bool(z.get("mixed")),
                      "color": ZONE_COLOURS[i % len(ZONE_COLOURS)], "rows": rowsList,
                      "heroCount": len(heroes), "suggestCount": len(z.get("suggest", []))})
        rows = max(rows, len(names))
    left = set(roster) - seen
    assert not left, f"heroes in roster.json but in no zone: {sorted(left)}"

    SLOTS.write_text(json.dumps(slots, indent=1, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    spec = {"origin": list(ORIGIN), "rows": rows + SPARE, "rarityOrder": order, "zones": zones}
    WORK.mkdir(parents=True, exist_ok=True)
    out = WORK / "zone_lab.luau"
    out.write_text("_G.ZONELAB = " + lua_value(spec) + "\n" + BUILDER.read_text(encoding="utf-8"), encoding="utf-8")
    done = subprocess.run([sys.executable, str(MCP), "luau", "--dm", "Edit", "--file", str(out)],
                          capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=600)
    print((done.stdout + done.stderr).strip())
    return 0 if done.returncode == 0 and "MISSING" not in done.stdout else 1


if __name__ == "__main__":
    sys.exit(main())
