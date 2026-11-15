#!/usr/bin/env python3
"""Every gate this game has, in one command.

    python tools/gate.py

Runs, in order, and stops at the first failure:
  1. roblox-code check.py   rojo build, lune tests, selene, stylua
  2. gen_config.py --check  GameConfig.luau still matches design/game.json
     gen_server_config.py --check  the server-only config too, and no promo code is in `config`
  3. validate.py            the contract has no gaps
  4. balance_sim.py --check pacing still lands inside config.Pacing

WHY: the Luau hook only runs (1). A number edited in design/game.json without regenerating the
config, or a retune that moves a zone gate by an hour, passes (1) and is caught only by (2) to (4).
Run this before every Studio playtest and before closing a section.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKILLS = Path.home() / ".claude" / "skills"

STEPS = [
    ("code gates", [str(SKILLS / "roblox-code" / "scripts" / "check.py")]),
    ("config matches contract", [str(SKILLS / "create-roblox-game" / "scripts" / "gen_config.py"), "--dir", str(ROOT), "--check"]),
    ("server config matches contract", [str(ROOT / "tools" / "gen_server_config.py"), "--check"]),
    ("icon table matches uploads", [str(ROOT / "tools" / "gen_icons.py"), "--check"]),
    ("ui labels all bound", [str(SKILLS / "roblox-ui" / "scripts" / "verify_labels.py"), "--ui", str(ROOT / "src" / "ui"), "--client", str(ROOT / "src" / "client")]),
    ("contract valid", [str(SKILLS / "create-roblox-game" / "scripts" / "validate.py")]),
    ("pacing", [str(ROOT / "tools" / "balance_sim.py"), "--check", "--runs", "7", "--hours", "20"]),
]


def main() -> int:
    for name, cmd in STEPS:
        r = subprocess.run([sys.executable, *cmd], cwd=ROOT, capture_output=True, text=True,
                           encoding="utf-8", errors="replace")
        ok = r.returncode == 0
        print(f"  {'PASS' if ok else 'FAIL'}  {name}")
        if not ok:
            tail = (r.stdout + r.stderr).strip().splitlines()[-25:]
            print("\n".join("        " + line for line in tail))
            return 1
    print("all gates green.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
