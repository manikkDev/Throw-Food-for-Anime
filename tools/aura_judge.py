#!/usr/bin/env python3
"""Judge the game's hero auras where they are worn: on a real base, in daylight (plan 12, phase E).

    python tools/aura_judge.py show limitless_teacher time_wizard_king     # these heroes on Plot5's pedestals
    python tools/aura_judge.py spread <heroId> ...     # the same, on every other pedestal (up to 21)
    python tools/aura_judge.py row 1           # THE AUDIT: 7 heroes on the front row, rarest first (19 rows)
    python tools/aura_judge.py page 1          # page n of every aura hero, 21 a page, rarest first
    python tools/aura_judge.py pages           # how many pages, and who is on each
    python tools/aura_judge.py clear           # take the judge's heroes away again
  show / spread / row take --raw (no thinning: how the hot ones are FOUND) and, for show and spread,
  "heroId=0.3" (try a hot mark on that hero before writing it to design/auras.json "hot").

Studio in EDIT mode. See tools/studio/aura_judge.luau for the why (the preview yard is dark, a base is not).
A page fills every OTHER pedestal (heroes 16 studs apart), so a neighbour's aura is not mistaken for the hero's
own; `show` fills pedestals in order, 8 apart, as a full base stands.
Look at the front row head-on (rows stand at z 52.5, 42.9, 33.3, 23.7, 14.1, 4.5):
    python tools/studio/zones/run_zone.py look 184 9 76 184 5 52.5 6       (then a capture with NO position)
and set the camera type back to Fixed afterwards.

JUDGE AT MAXIMUM GRAPHICS. Studio's edit view runs at its automatic quality, which draws well under half the
particles and little bloom: an aura that reads well there can be a white ball in the game (Gojo's was). Before
looking: settings().Rendering.EditQualityLevel = Enum.QualityLevel.Level21, and back to Automatic afterwards.
"""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools" / "studio" / "aura_judge.luau"
MCP = Path.home() / ".claude" / "skills" / "create-roblox-game" / "scripts" / "studio_mcp.py"
ORDER = ["Secret", "Mythic", "Legendary", "Epic", "Rare", "Uncommon", "Common"]
PAGE = 21


def aura_heroes() -> list[str]:
    spec = json.loads((ROOT / "design" / "auras.json").read_text(encoding="utf-8"))
    cfg = json.loads((ROOT / "design" / "game.json").read_text(encoding="utf-8"))["config"]
    rarity = {c["Id"]: c.get("Rarity", "Secret") for c in cfg["Characters"]}
    rarity.update({c["Id"]: "Secret" for c in cfg.get("PremiumCharacters", [])})
    ids = [k for k in spec["heroes"] if not k.startswith("_")]
    return sorted(ids, key=lambda i: (ORDER.index(rarity.get(i, "Secret")), i))


def run(head: str) -> str:
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False, encoding="utf8", newline="\n") as f:
        f.write(head + SCRIPT.read_text(encoding="utf-8"))
        path = f.name
    r = subprocess.run([sys.executable, str(MCP), "luau", "--dm", "Edit", "--file", path], capture_output=True,
                       text=True, encoding="utf8", errors="replace")
    Path(path).unlink(missing_ok=True)
    return (r.stdout + r.stderr).strip()


def show(ids: list[str], spread: bool) -> str:
    # "hero=0.3" tries a hot mark on that hero; --raw puts every aura on unthinned
    raw = "--raw" in sys.argv
    ids = [i for i in ids if i != "--raw"]
    marks = {i.split("=")[0]: float(i.split("=")[1]) for i in ids if "=" in i}
    ids = [i.split("=")[0] for i in ids]
    extra = ", raw = %s, marks = {%s}" % ("true" if raw else "false",
                                          ", ".join(f"[{json.dumps(k)}] = {v}" for k, v in marks.items()))
    if spread:
        # every other pedestal of a 7-wide row: 1, 3, 5, 7, then the next row's 2, 4, 6 ...
        slots = [i for i in range(1, 43) if i % 2 == 1][:len(ids)]
        table = "{" + ", ".join(f"[{s}] = {json.dumps(i)}" for s, i in zip(slots, ids)) + "}"
    else:
        table = "{" + ", ".join(json.dumps(i) for i in ids) + "}"
    return run("_G.AURA_JUDGE = { ids = %s%s }\n" % (table, extra))


def main() -> int:
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    heroes = aura_heroes()
    pages = [heroes[i:i + PAGE] for i in range(0, len(heroes), PAGE)]
    if cmd == "clear":
        print(run("_G.AURA_JUDGE = { clear = true }\n"))
    elif cmd == "show" and len(sys.argv) > 2:
        print(show(sys.argv[2:], spread=False))
    elif cmd == "spread" and len(sys.argv) > 2:
        print(show(sys.argv[2:], spread=True))
    elif cmd == "row" and len(sys.argv) > 2:
        n = int(sys.argv[2])
        ids = heroes[(n - 1) * 7:n * 7]
        show(ids, spread=False)
        print(f"row {n} of {(len(heroes) + 6) // 7}, left to right: " + " | ".join(ids))
    elif cmd == "page" and len(sys.argv) > 2:
        print(show(pages[int(sys.argv[2]) - 1], spread=True))
    elif cmd == "pages":
        for n, p in enumerate(pages, 1):
            print(n, " ".join(p))
    else:
        print(__doc__)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
