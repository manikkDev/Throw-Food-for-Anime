#!/usr/bin/env python3
"""Turn the Creator Store sources in the place into kit templates and write their manifest.

    python tools/studio/install_store_assets.py

Runs tools/studio/install_store_assets.luau in Studio (EDIT mode): every Model in
ServerStorage.StoreAssets becomes ReplicatedStorage.Assets.Kit.Prop_store_<Name> (upright, pivot
at the base centre, front at -Z). The sizes it measures go to assets/meshes/manifest-store.json,
which tools/map/gen_map.py reads like any other manifest (name starts with "manifest"); the
upload tools do not (they glob manifest_*.json), because these models are not ours to upload.

Triangle counts are not measurable from Luau: a MeshPart is entered as 600 triangles and a plain
Part as 12, which is on the heavy side for these packs.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
HELPER = Path.home() / ".claude" / "skills" / "create-roblox-game" / "scripts" / "studio_mcp.py"
OUT = ROOT / "assets" / "meshes" / "manifest-store.json"


def main() -> int:
    script = Path(__file__).with_suffix(".luau")
    done = subprocess.run([sys.executable, str(HELPER), "luau", "--dm", "Edit", "--file", str(script)],
                          capture_output=True, text=True, encoding="utf-8", errors="replace")
    text = (done.stdout + done.stderr).strip()
    rows = []
    for line in text.splitlines():
        bits = line.strip().strip('"').split("|")
        if len(bits) == 3 and bits[0].startswith("Prop_store_"):
            parts = int(bits[1])
            size = [float(v) for v in bits[2].split(",")]
            heavy = parts > 20            # part-built models: mostly plain Parts
            rows.append({"name": bits[0], "bounds_studs": size, "parts": parts,
                         "tris": parts * (12 if heavy else 600), "tris_estimated": True,
                         "colour_parts": [f"p{i}" for i in range(parts)]})
    if not rows:
        print("FAIL nothing installed:\n" + text[:600])
        return 1
    OUT.write_text(json.dumps({"_what": "Creator Store models installed as kit templates (see "
                                        "tools/studio/install_store_assets.py). Sources: "
                                        "ServerStorage.StoreAssets in the place.",
                               "assets": rows}, indent=1), encoding="utf-8")
    for r in rows:
        print(f"ok {r['name']} parts={r['parts']} size={r['bounds_studs']}")
    print(f"{len(rows)} store template(s) installed -> {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
