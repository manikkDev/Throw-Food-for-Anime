#!/usr/bin/env python3
"""Upload every model in assets/meshes/manifest_*.json to Roblox, once, and record the ids.

    python tools/publish_meshes.py            upload what is new or changed
    python tools/publish_meshes.py --dry      list what would be uploaded
    python tools/publish_meshes.py --only Plot_Pedestal Coin_Yen

Writes assets/meshes/ids.json: { "<Name>": { "assetId": 123, "sha1": "...", "file": "..." } }.
A model whose GLB has not changed since its last upload is skipped, so the script is safe to
re-run after a worker fixes three models: only those three go up again.

WHY ONE SCRIPT ON ONE THREAD: several workers build models in parallel, and an upload is an
outward action under the owner's account. If each worker uploaded its own, a retry would leave
duplicate assets nobody references, and the key would be handled in six places. Workers write
files; this publishes them.

The key is read from the environment by the skill's uploader (ROBLOX_API_KEY, ROBLOX_USER_ID).
It is never printed, passed on a command line or written anywhere.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MESHES = ROOT / "assets" / "meshes"
IDS = MESHES / "ids.json"
UPLOADER = Path.home() / ".claude" / "skills" / "roblox-3d-model" / "scripts" / "upload_asset.py"


def entries() -> list[dict]:
    rows: list[dict] = []
    for manifest in sorted(MESHES.glob("manifest_*.json")):
        data = json.loads(manifest.read_text(encoding="utf-8"))
        if isinstance(data, dict):
            data = data.get("assets") or data.get("models") or data.get("entries") or list(data.values())
        for row in data:
            if isinstance(row, dict) and row.get("name") and row.get("path"):
                rows.append(row)
    return rows


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--dry", action="store_true")
    ap.add_argument("--only", nargs="*", default=None)
    a = ap.parse_args()

    ids = json.loads(IDS.read_text(encoding="utf-8")) if IDS.exists() else {}
    failed, done, skipped = [], 0, 0
    for row in entries():
        name = row["name"]
        if a.only is not None and name not in a.only:
            continue
        path = Path(row["path"])
        if not path.is_absolute():
            path = ROOT / path
        if not path.exists():
            failed.append(f"{name}: file missing ({row['path']})")
            continue
        sha1 = hashlib.sha1(path.read_bytes()).hexdigest()
        known = ids.get(name)
        if known and known.get("sha1") == sha1 and known.get("assetId"):
            skipped += 1
            continue
        if a.dry:
            print(f"would upload {name}  ({path.stat().st_size / 1024:.0f} KB)")
            continue
        run = subprocess.run(
            [sys.executable, str(UPLOADER), "--file", str(path), "--name", name, "--asset-type", "Model",
             "--description", "Throw Food for Anime world model"],
            capture_output=True, text=True, encoding="utf-8", errors="replace",
        )
        found = re.search(r"assetId=(\d+)", run.stdout)
        if run.returncode != 0 or not found:
            tail = (run.stdout + run.stderr).strip().splitlines()[-3:]
            failed.append(f"{name}: " + " | ".join(tail))
            continue
        ids[name] = {"assetId": int(found.group(1)), "sha1": sha1,
                     "file": str(path.relative_to(ROOT)).replace("\\", "/")}
        IDS.write_text(json.dumps(ids, indent=1, sort_keys=True), encoding="utf-8", newline="\n")
        done += 1
        print(f"uploaded {name} -> {found.group(1)}")
        time.sleep(1.0)  # stay well under the Assets API rate limit

    print(f"{done} uploaded, {skipped} unchanged, {len(failed)} failed, {len(ids)} ids on record")
    for line in failed:
        print("  FAIL " + line)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
