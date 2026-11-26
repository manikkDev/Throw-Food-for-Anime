#!/usr/bin/env python3
"""Install judged food models as the game's templates (plan 13 phase B).

    python tools/studio/foods/install_foods.py            # every food standing in Workspace.FoodLab
    python tools/studio/foods/install_foods.py onigiri legend_ramen     # only these

Order of work for a batch:
  1. Studio generate_mesh, one food each, the prompt starting "FOOD_<id>:" (ids from config.Foods).
  2. `studio_mcp.py luau --dm Edit --file tools/studio/foods/food_lab.luau`: the judging row.
     Look at every food at maximum graphics; remake what fails (a newer model replaces the older).
  3. This tool: sizes, turns and throw classes come from design/foods.json.
Studio must be in EDIT mode.
"""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HELPER = Path.home() / ".claude" / "skills" / "create-roblox-game" / "scripts" / "studio_mcp.py"
DESIGN = ROOT / "design" / "foods.json"
GAME = ROOT / "design" / "game.json"


def main() -> int:
    design = json.loads(DESIGN.read_text(encoding="utf-8"))["foods"]
    known = {f["Id"] for f in json.loads(GAME.read_text(encoding="utf-8"))["config"]["Foods"]}
    unknown = sorted(set(design) - known)
    if unknown:
        print(f"FAIL design/foods.json names foods that are not in config.Foods: {unknown}")
        return 1
    only = sys.argv[1:]
    rows = []
    for fid, spec in design.items():
        if spec["throw"] not in ("pitch", "heave", "spin"):
            print(f"FAIL {fid}: throw is {spec['throw']!r}")
            return 1
        turn = spec.get("turn", [0, 0, 0])
        rows.append(f'\t{fid} = {{ size = {spec["size"]}, throw = "{spec["throw"]}", '
                    f'turn = {{ {turn[0]}, {turn[1]}, {turn[2]} }} }},')
    source = Path(__file__).with_suffix(".luau").read_text(encoding="utf-8")
    source = source.replace("local SPEC = {} --[[SPEC]]", "local SPEC = {\n" + "\n".join(rows) + "\n}")
    source = source.replace("local ONLY = {} --[[ONLY]]",
                            "local ONLY = {" + ", ".join(f"{fid} = true" for fid in only) + "}")
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False, encoding="utf-8") as handle:
        handle.write(source)
        temp = handle.name
    done = subprocess.run([sys.executable, str(HELPER), "luau", "--dm", "Edit", "--file", temp],
                          capture_output=True, text=True, encoding="utf-8", errors="replace")
    Path(temp).unlink(missing_ok=True)
    text = (done.stdout + done.stderr).strip()
    lines = [line.strip().strip('"') for line in text.splitlines() if line.strip().strip('"').startswith("Food_")]
    if not lines:
        print("FAIL nothing installed:\n" + text[:800])
        return 1
    for line in lines:
        name, size, throw = line.split("|")
        print(f"ok {name:<24} {size:<18} {throw}")
    print(f"{len(lines)} food template(s) installed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
