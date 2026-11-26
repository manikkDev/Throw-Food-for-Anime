#!/usr/bin/env python3
"""Upload the ControlDevil textures as Roblox Images (Open Cloud, key from ROBLOX_API_KEY).

    python tools/auras/control_devil/upload.py           upload any texture with no id yet
    python tools/auras/control_devil/upload.py --force   re-upload every texture (after a redesign)

Ids land in assets/auras/control_devil/ids.json, which tools/studio/auras/build_control_devil.luau
reads (pasted in by tools/auras/control_devil/emit_builder.py).
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
DIR = ROOT / "assets" / "auras" / "control_devil"
MAP = DIR / "ids.json"
UPLOAD = Path.home() / ".claude" / "skills" / "roblox-3d-model" / "scripts" / "upload_asset.py"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    ap.add_argument("only", nargs="*", help="texture names to upload (default: all)")
    a = ap.parse_args()
    ids = json.loads(MAP.read_text(encoding="utf-8")) if MAP.exists() else {}
    fails = []
    for png in sorted(DIR.glob("*.png")):
        key = png.stem
        if a.only and key not in a.only:
            continue
        if key in ids and not a.force and not a.only:
            continue
        r = subprocess.run([sys.executable, str(UPLOAD), "--file", str(png), "--name", f"TFA_ControlDevil_{key}",
                            "--asset-type", "Image", "--description", "Throw Food for Anime: hero aura texture"],
                           capture_output=True, text=True)
        m = re.search(r"assetId=(\d+)", r.stdout)
        if not m:
            fails.append(key)
            print(f"FAIL {key}: {(r.stdout + r.stderr)[-300:]}")
            continue
        ids[key] = int(m.group(1))
        MAP.write_text(json.dumps(ids, indent=2) + "\n", encoding="utf-8")
        print(f"ok   {key} {ids[key]}")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
