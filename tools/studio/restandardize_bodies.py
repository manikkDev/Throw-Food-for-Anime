#!/usr/bin/env python3
"""Rebuild every hero in R15_Final whose torso/arms/legs are not the game's standard R15 parts.

    python tools/studio/restandardize_bodies.py            # find and fix all
    python tools/studio/restandardize_bodies.py --list     # only list them
    python tools/studio/restandardize_bodies.py "Rimuru (R15)" ...   # fix these

Studio must be open in EDIT mode with the Studio MCP on. See restandardize_bodies.luau.
"""
from __future__ import annotations

import json
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BUILDER = ROOT / "tools" / "studio" / "restandardize_bodies.luau"
WORK = ROOT / "work" / "norm"
MCP = Path.home() / ".claude" / "skills" / "create-roblox-game" / "scripts" / "studio_mcp.py"

FIND = r'''
local std = {UpperTorso=Vector3.new(2,1.6,1),LowerTorso=Vector3.new(2,0.4,1),LeftUpperArm=Vector3.new(1,1.17,1),
 LeftLowerArm=Vector3.new(1,1.05,1),LeftHand=Vector3.new(1,0.3,1),LeftUpperLeg=Vector3.new(1,1.22,1),
 LeftLowerLeg=Vector3.new(1,1.19,1),LeftFoot=Vector3.new(1,0.3,1)}
local out = {}
for _, rig in game.ServerStorage.CharacterSources.R15_Final:GetChildren() do
	local worst = 0
	for n, s in std do
		local p = rig:FindFirstChild(n)
		worst = math.max(worst, p and (p.Size - s).Magnitude or 99)
	end
	if worst > 0.06 then out[#out+1] = rig.Name end
end
return table.concat(out, "\n")
'''


def luau(*args: str) -> str:
    out = subprocess.run([sys.executable, str(MCP), "luau", "--dm", "Edit", *args],
                         capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=300)
    if out.returncode != 0:
        raise SystemExit(f"studio call failed:\n{out.stdout}\n{out.stderr}")
    return out.stdout.strip()


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    names = args or [n for n in luau("--code", FIND).splitlines() if n.strip()]
    print(f"{len(names)} rigs")
    if "--list" in sys.argv:
        print("\n".join(names))
        return 0
    WORK.mkdir(parents=True, exist_ok=True)
    script = WORK / "run_fix.luau"
    script.write_text("_G.FIX = {" + ", ".join(json.dumps(n) for n in names) + "}\n" + BUILDER.read_text(encoding="utf-8"), encoding="utf-8")
    luau("--file", str(script))
    for _ in range(600):
        time.sleep(2)
        state = luau("--code", "return workspace:GetAttribute('TFAFix')")
        if not state.splitlines()[-1].startswith("running"):
            sys.stdout.buffer.write((state + "\n").encode("utf-8", "replace"))
            return 0 if "FAILED" not in state and "MISSING" not in state else 1
    print("timed out")
    return 1


if __name__ == "__main__":
    sys.exit(main())
