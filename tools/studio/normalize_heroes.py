#!/usr/bin/env python3
"""Run tools/studio/normalize_heroes.luau on a list of rigs.

    python tools/studio/normalize_heroes.py work/norm/batch1.json

The json is a list of {"src": "<Workspace child>", "name": "<Hero>", "mode": "rebuild"|"inplace",
"parent": "<path, optional>"}. Studio must be open in EDIT mode with the Studio MCP on.
"""
from __future__ import annotations

import json
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BUILDER = ROOT / "tools" / "studio" / "normalize_heroes.luau"
WORK = ROOT / "work" / "norm"
MCP = Path.home() / ".claude" / "skills" / "create-roblox-game" / "scripts" / "studio_mcp.py"


def luau(*args: str) -> str:
    out = subprocess.run([sys.executable, str(MCP), "luau", "--dm", "Edit", *args],
                         capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=300)
    if out.returncode != 0:
        raise SystemExit(f"studio call failed:\n{out.stdout}\n{out.stderr}")
    return out.stdout.strip()


def lua(v) -> str:
    if isinstance(v, str):
        return json.dumps(v)
    if isinstance(v, dict):
        return "{" + ", ".join(f"{k} = {lua(x)}" for k, x in v.items()) + "}"
    if isinstance(v, list):
        return "{" + ", ".join(lua(x) for x in v) + "}"
    return str(v)


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    rows = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    for r in rows:
        r.setdefault("mode", "rebuild")
    WORK.mkdir(parents=True, exist_ok=True)
    script = WORK / "run.luau"
    script.write_text("_G.NORM = " + lua(rows) + "\n" + BUILDER.read_text(encoding="utf-8"), encoding="utf-8")
    luau("--file", str(script))
    for _ in range(300):
        time.sleep(2)
        state = luau("--code", "return workspace:GetAttribute('TFANorm')")
        if not state.splitlines()[-1].startswith("running"):
            sys.stdout.buffer.write((state + "\n").encode("utf-8", "replace"))
            return 0 if "FAILED" not in state and "MISSING" not in state else 1
    print("timed out")
    return 1


if __name__ == "__main__":
    sys.exit(main())
