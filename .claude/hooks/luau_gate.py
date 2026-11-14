#!/usr/bin/env python3
"""PostToolUse hook: after Claude edits a Luau file, run the four roblox-code gates.

Reads the hook payload (JSON) on stdin. Only reacts to Edit/Write/MultiEdit on *.luau/*.lua
files inside this project. Exit 0 = gates green (silent). Exit 2 = a gate failed: the failure
text goes to stderr, which Claude Code feeds back to the model so it fixes the code before
anything reaches Studio. Never blocks on its own errors (exits 0 if the checker is missing).
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHECK = Path.home() / ".claude" / "skills" / "roblox-code" / "scripts" / "check.py"


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception:  # noqa: BLE001
        return 0
    path = (payload.get("tool_input") or {}).get("file_path") or ""
    if not path.lower().endswith((".luau", ".lua")):
        return 0
    try:
        Path(path).resolve().relative_to(ROOT)
    except ValueError:
        return 0  # a Luau file outside this game (e.g. a skill's script): not ours to gate
    if not CHECK.exists():
        return 0
    env = dict(os.environ, NO_COLOR="1", PYTHONIOENCODING="utf-8")
    r = subprocess.run([sys.executable, str(CHECK)], cwd=ROOT, capture_output=True, text=True,
                       encoding="utf-8", errors="replace", timeout=300, env=env)
    if r.returncode == 0:
        return 0
    import re

    def clean(proc) -> str:
        return re.sub(r"\x1b\[[0-9;]*m", "", proc.stdout + proc.stderr).strip()

    out = clean(r)
    # FORMAT-ONLY failure: let stylua rewrite the file and re-run. Measured on this project
    # (2026-11-14): most failures were a signature one column too long, each costing a full
    # round trip and ~900 tokens of diff for something the formatter fixes by itself. A real
    # failure (build, test, lint) still stops the edit below.
    failed = re.findall(r"^\s*FAIL\s+(\S+)", out, flags=re.M)
    if failed and all(name == "stylua" for name in failed):
        subprocess.run([sys.executable, str(CHECK), "--fix"], cwd=ROOT, capture_output=True,
                       text=True, encoding="utf-8", errors="replace", timeout=300, env=env)
        r = subprocess.run([sys.executable, str(CHECK)], cwd=ROOT, capture_output=True, text=True,
                           encoding="utf-8", errors="replace", timeout=300, env=env)
        if r.returncode == 0:
            return 0
        out = clean(r)
    # Report what FAILED, not the hundred tests that passed.
    lines = [ln for ln in out.splitlines() if not re.match(r"^\s*PASS\s+\S+\.spec\.luau ::", ln)]
    sys.stderr.write(
        "roblox-code gates FAILED after editing " + os.path.basename(path)
        + ". Fix this before continuing (do not hand broken code to Rojo/Studio):\n"
        + "\n".join(lines)[-3500:] + "\n")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
