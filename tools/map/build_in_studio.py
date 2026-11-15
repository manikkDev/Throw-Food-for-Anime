#!/usr/bin/env python3
"""Build the map in Studio (EDIT mode) from the emitted chunks, in order, waiting for each one.

    python tools/map/build_in_studio.py                 every chunk in work/map/chunks
    python tools/map/build_in_studio.py --from 02       start at the first chunk whose name starts with 02
    python tools/map/build_in_studio.py --only 04_hub 05_lanes

Each chunk yields while it builds, so the MCP call returns before the work is finished and drops
its printed output. The chunks therefore write `Workspace.Map` attributes `LastChunk` and
`Chunk_<id>` when they end; this runner clears `LastChunk`, runs the file and polls until the
chunk says it is done, then prints its summary (which counts any MissingMesh stand-ins).

Studio must be open on the place and NOT in Play. `00_setup` wipes `Workspace.Map`.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
CHUNKS = ROOT / "work" / "map" / "chunks"
HELPER = Path.home() / ".claude" / "skills" / "create-roblox-game" / "scripts" / "studio_mcp.py"


def studio(*args: str) -> str:
    done = subprocess.run([sys.executable, str(HELPER), "luau", "--dm", "Edit", *args],
                          capture_output=True, text=True, encoding="utf-8", errors="replace")
    return (done.stdout + done.stderr).strip()


READ = ("local m = workspace:FindFirstChild('Map') if not m then return 'NOMAP' end "
        "return tostring(m:GetAttribute('LastChunk')) .. '|' .. tostring(m:GetAttribute('Chunk_%s'))")
CLEAR = "local m = workspace:FindFirstChild('Map') if m then m:SetAttribute('LastChunk', nil) end return 'ok'"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--from", dest="start", default=None)
    ap.add_argument("--only", nargs="*", default=None)
    ap.add_argument("--timeout", type=int, default=420, help="seconds to wait per chunk")
    a = ap.parse_args()

    files = sorted(CHUNKS.glob("*.lua"))
    if a.only is not None:
        files = [f for f in files if any(f.stem.startswith(o) for o in a.only)]
    elif a.start:
        files = [f for f in files if f.stem >= a.start]
    if not files:
        print("no chunks to run")
        return 1
    for f in files:
        chunk = f.stem
        studio("--code", CLEAR)
        t0 = time.time()
        first = studio("--file", str(f))
        if "setup" in chunk or "lighting" in chunk:  # these do not yield and set no attribute
            print(f"{chunk}: {first[:200]}")
            continue
        state = ""
        while time.time() - t0 < a.timeout:
            state = studio("--code", READ % chunk)
            if state.startswith(chunk + "|"):
                break
            time.sleep(3)
        else:
            print(f"FAIL {chunk}: no completion after {a.timeout}s (last: {state[:160]} / {first[:160]})")
            return 1
        print(f"{chunk} ({time.time() - t0:.0f}s): {state.split('|', 1)[1][:400]}")
    # dressing passes that are not in the generator (wall surfaces, glow, stand-ins)
    print(studio("--file", str(Path(__file__).resolve().parent / "post_build.luau"))[:300])
    return 0


if __name__ == "__main__":
    sys.exit(main())
