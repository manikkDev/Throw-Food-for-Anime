#!/usr/bin/env python3
"""Upload every effect texture that has no asset id yet (Open Cloud, key from ROBLOX_API_KEY).

    python assets/vfx/tools/pack_all.py          # writes upload/ and upload_list.json
    python assets/vfx/tools/upload_tex.py        # uploads the new ones as Images -> ids.json
    python assets/vfx/tools/pack_all.py          # embeds the ids in work/vfx/build_templates.luau

`--force name.png ...` uploads those files again (after a texture was redrawn).
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

VFX = Path(__file__).resolve().parent.parent
IDS = VFX / "ids.json"
UPLOAD = Path.home() / ".claude" / "skills" / "roblox-3d-model" / "scripts" / "upload_asset.py"


def main() -> int:
    force = set(sys.argv[2:]) if len(sys.argv) > 1 and sys.argv[1] == "--force" else set()
    ids = json.loads(IDS.read_text(encoding="utf-8"))
    todo = [t for t in json.loads((VFX / "upload_list.json").read_text(encoding="utf-8"))["textures"]
            if t["file"] in force or t["file"] not in ids["textures"]]
    fails = []
    for i, t in enumerate(todo):
        key = t["file"]
        name = "TFA_Fx_" + re.sub(r"[^A-Za-z0-9_]", "_", key[:-4])[-40:]
        r = subprocess.run([sys.executable, str(UPLOAD), "--file", t["path"], "--name", name, "--asset-type", "Image",
                            "--description", "Throw Food for Anime: effect texture"], capture_output=True, text=True)
        m = re.search(r"assetId=(\d+)", r.stdout)
        if not m:
            fails.append(key)
            print(f"FAIL {key}: {(r.stdout + r.stderr)[-200:]}", flush=True)
            continue
        ids["textures"][key] = int(m.group(1))
        IDS.write_text(json.dumps(ids, indent=1) + "\n", encoding="utf-8")
        print(f"ok {i + 1}/{len(todo)} {key}", flush=True)
    print(f"done: {len(todo) - len(fails)} uploaded, {len(fails)} failed")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
