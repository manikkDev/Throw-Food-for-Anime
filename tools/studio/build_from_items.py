#!/usr/bin/env python3
"""Build heroes in Studio from marketplace item links or ids (no username, no plugin).

    python tools/studio/build_from_items.py "Yuno" 80640898032476 https://www.roblox.com/catalog/135595125281380/Yuno ...
    python tools/studio/build_from_items.py --file design/characters/item_avatars.json

The json file maps a hero name to its list of ids or links, e.g. {"Yuno": ["806...", "https://..."]}.
Every built hero is recorded in design/characters/item_avatars.json (its source of truth, since
there is no original avatar to archive). Results land in Workspace.Characters_R15_New as
"<Name> (R15)"; then apply the head rule, move them to R15_Final, add roster rows and bake
(design/characters/README.md). Studio must be open in EDIT mode with the Studio MCP on.
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BUILDER = ROOT / "tools" / "studio" / "build_from_items.luau"
RECORD = ROOT / "design" / "characters" / "item_avatars.json"
WORK = ROOT / "work" / "items"
MCP = Path.home() / ".claude" / "skills" / "create-roblox-game" / "scripts" / "studio_mcp.py"


def asset_id(text: str) -> int:
    """A bare id or any roblox.com catalog/bundle link -> the number in it."""
    m = re.search(r"(\d{5,})", str(text))
    if not m:
        raise SystemExit(f"no item id in {text!r}")
    return int(m.group(1))


def luau(*args: str) -> str:
    out = subprocess.run([sys.executable, str(MCP), "luau", "--dm", "Edit", *args],
                         capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=300)
    if out.returncode != 0:
        raise SystemExit(f"studio call failed:\n{out.stdout}\n{out.stderr}")
    return out.stdout.strip()


def main() -> int:
    if len(sys.argv) >= 3 and sys.argv[1] == "--file":
        rows = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
    elif len(sys.argv) >= 3:
        rows = {sys.argv[1]: sys.argv[2:]}
    else:
        print(__doc__)
        return 1
    rows = {name: [asset_id(x) for x in items] for name, items in rows.items()}

    record = json.loads(RECORD.read_text(encoding="utf-8")) if RECORD.exists() else {}
    record.update(rows)
    RECORD.write_text(json.dumps(record, indent=1) + "\n", encoding="utf-8", newline="\n")

    spec = "_G.ITEMS = {" + ", ".join(
        "{name = %s, ids = {%s}}" % (json.dumps(n), ", ".join(map(str, ids))) for n, ids in rows.items()
    ) + "}\n"
    WORK.mkdir(parents=True, exist_ok=True)
    script = WORK / "build_from_items.luau"
    script.write_text(spec + BUILDER.read_text(encoding="utf-8"), encoding="utf-8")
    luau("--file", str(script))
    for _ in range(120):
        time.sleep(1)
        state = luau("--code", "return workspace:GetAttribute('TFAItems')")
        if "running" not in state.splitlines()[-1]:
            print(state)
            return 0 if "FAILED" not in state and "NOT FOUND" not in state else 1
    print("timed out waiting for the build")
    return 1


if __name__ == "__main__":
    sys.exit(main())
