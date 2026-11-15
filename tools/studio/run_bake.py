#!/usr/bin/env python3
"""Bake every hero in design/characters/roster.json into the client templates.

    python tools/studio/run_bake.py

Fills the ROSTER line of tools/studio/bake_characters.luau from the roster file and runs it in
Studio's EDIT datamodel through the skill's direct MCP helper. Prints the bake report: one line
per hero with its part, motor and weld counts.

WHY: the bake script needs the roster pasted into it, and pasting by hand is how a hero added to
roster.json gets left out of the bake (it then shows in game as the neon placeholder block).
Studio must be open on the place and NOT in Play.
"""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
HELPER = Path.home() / ".claude" / "skills" / "create-roblox-game" / "scripts" / "studio_mcp.py"
MARK = "local ROSTER = {} -- <<< generated line goes here"


def main() -> int:
    roster = json.loads((ROOT / "design" / "characters" / "roster.json").read_text(encoding="utf-8"))
    line = "local ROSTER = {" + ", ".join(
        "{id=%s, source=%s}" % (json.dumps(row["Id"]), json.dumps(row["Source"])) for row in roster
    ) + "}"
    source = (ROOT / "tools" / "studio" / "bake_characters.luau").read_text(encoding="utf-8")
    if MARK not in source:
        print("FAIL the ROSTER marker line is missing from bake_characters.luau")
        return 1
    with tempfile.TemporaryDirectory() as tmp:
        script = Path(tmp) / "bake.luau"
        script.write_text(source.replace(MARK, line), encoding="utf-8")
        done = subprocess.run(
            [sys.executable, str(HELPER), "luau", "--file", str(script), "--dm", "Edit"],
            capture_output=True, text=True, encoding="utf-8", errors="replace",
        )
    out = (done.stdout + done.stderr).strip()
    print(out)
    bad = "MISSING" in out or "<<< MOTORS" in out or f"{len(roster)} templates" not in out
    if done.returncode != 0 or bad:
        print(f"FAIL expected {len(roster)} templates, every one with 15 motors")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
