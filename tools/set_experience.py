"""Experience settings over Open Cloud (section 6): the server size matches the plots and the store
description. Visibility is NOT touched here (making the game public is the owner's call).

    python tools/set_experience.py          # show what would change
    python tools/set_experience.py --apply  # write it

The key is read from ROBLOX_API_KEY and never printed.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
API = "https://apis.roblox.com/cloud/v2"

DESCRIPTION = """Train your power, throw food down a lane of anime worlds and catch the hero it lures. The further you throw, the rarer the hero!

- Charge and throw: a perfect throw flies further
- 51 heroes across 6 worlds, Common to Secret, with mutations and giant sizes
- Heroes on your plot earn Yen every second, even while you are away
- Train at the dojo for Power, upgrade your gear and plot slots
- Better foods for more luck; each hero craves a flavour
- Fuse duplicates, complete the Hero Index, Rebirth for permanent income and luck
- Daily rewards, playtime gifts and codes (Settings)"""


def call(method: str, url: str, key: str, body: dict | None = None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method,
                                 headers={"x-api-key": key, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:400]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    a = ap.parse_args()
    key = os.environ.get("ROBLOX_API_KEY")
    if not key:
        raise SystemExit("ROBLOX_API_KEY is not set")
    game = json.loads((ROOT / "design" / "game.json").read_text(encoding="utf-8"))
    universe, place = game["publish"]["universe_id"], game["publish"]["place_id"]
    players = game["config"]["Server"]["MaxPlayers"]
    u_url = f"{API}/universes/{universe}"
    p_url = f"{u_url}/places/{place}"
    _, u = call("GET", u_url, key)
    _, p = call("GET", p_url, key)
    print(f"universe: visibility {u.get('visibility')}, description {len(u.get('description') or '')} chars")
    print(f"place: serverSize {p.get('serverSize')} -> {players}, description {len(p.get('description') or '')} chars")
    if not a.apply:
        return 0
    s, r = call("PATCH", f"{u_url}?updateMask=description", key, {"description": DESCRIPTION})
    print("universe description:", s, "" if s == 200 else r)
    s, r = call("PATCH", f"{p_url}?updateMask=description,serverSize", key,
                {"description": DESCRIPTION, "serverSize": players})
    print("place description + serverSize:", s, "" if s == 200 else r)
    _, p = call("GET", p_url, key)
    print("read back: serverSize", p.get("serverSize"), "description", len(p.get("description") or ""), "chars")
    return 0


if __name__ == "__main__":
    sys.exit(main())
