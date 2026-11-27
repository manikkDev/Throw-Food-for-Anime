#!/usr/bin/env python3
"""Build the training grounds' set pieces in Studio (edit mode). Plan 13 phase D.

    python tools/studio/grounds/run_build.py            # gather new generated pieces, then build
    python tools/studio/grounds/run_build.py --no-lab   # build only

Runs ground_lab.luau (takes freshly generated GROUND_<key> models into the judging row) and then
build_grounds.luau with the effect texture ids (assets/vfx/ids.json) set in _G.GROUND_TEX: the
water of the falls, the pool's ripple, the fires and the mist use the game's own uploaded images.
"""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
MCP = Path.home() / ".claude" / "skills" / "create-roblox-game" / "scripts" / "studio_mcp.py"

# the name build_grounds.luau uses -> the uploaded file (assets/vfx/ids.json "textures")
TEXTURES = {
    "water_sheet": "tfa__water_sheet__vt.png",
    "water_foam": "tfa__water_foam__vt.png",
    "pool_ripple": "tfa__pool_ripple.png",
    "mist": "lib__sprites__smoke__smoke_puff_soft_02.png",
    "dot": "lib__sprites__specks__dot_cel_00.png",
    "splash": "lib__flipbooks__water__water_splash_cel_00_4x4.png",
    "flame": "lib__sprites__elements__flame_cel_02.png",
    "ember": "lib__sprites__specks__ember_cel_01.png",
    "glint": "lib__sprites__stars__star_glow_04.png",
    "streak": "lib__sprites__specks__streak_cel_00.png",
    "crack": "lib__sprites__cracks__crack_cel_02.png",
    "bolt": "tfa__bolt_strip__vt.png",
    "boltsprite": "lib__sprites__elements__bolt_cel_04.png",
}


def run(path: Path) -> int:
    out = subprocess.run([sys.executable, str(MCP), "luau", "--dm", "Edit", "--file", str(path)], capture_output=True,
                         text=True, encoding="utf8", errors="replace")
    print((out.stdout + out.stderr).strip())
    return out.returncode


def main() -> int:
    ids = json.loads((ROOT / "assets" / "vfx" / "ids.json").read_text(encoding="utf-8"))["textures"]
    missing = [name for name, file in TEXTURES.items() if file not in ids]
    if missing:
        print("no uploaded id for:", ", ".join(missing), "(python assets/vfx/tools/upload_tex.py)")
        return 1
    if "--no-lab" not in sys.argv:
        run(HERE / "ground_lab.luau")
    table = ", ".join(f"{name} = {ids[file]}" for name, file in TEXTURES.items())
    code = f"_G.GROUND_TEX = {{ {table} }}\n" + (HERE / "build_grounds.luau").read_text(encoding="utf-8")
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False, encoding="utf-8") as tmp:
        tmp.write(code)
    return run(Path(tmp.name))


if __name__ == "__main__":
    raise SystemExit(main())
