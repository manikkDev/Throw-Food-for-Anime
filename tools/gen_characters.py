#!/usr/bin/env python3
"""config.Characters and config.PremiumCharacters from the lineup (plan 12).

    python tools/gen_characters.py            # rewrites the two tables in design/game.json
    python tools/gen_characters.py --check    # exit 1 if game.json differs from the lineup
    python tools/gen_characters.py --seed-lineup   # ONE-OFF: build lineup.json from HERO_LIST_BY_RARITY.md

SOURCES
  design/characters/lineup.json   THE TRUTH for gameplay: every hero's zone (1..17) and rarity, and
                                  the premium heroes with how they are sold. Edit this, then run me.
  design/characters/roster.json   id -> in-game name (the alias) and the real character (Source).
  design/game.json                kept per hero if already there: Craves, Idle, Line.

A new hero gets a craved flavour and an idle clip by a stable hash of its id, so re-running never
reshuffles them. Then: python ~/.claude/skills/create-roblox-game/scripts/gen_config.py --dir .
"""
from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "design" / "game.json"
LINEUP = ROOT / "design" / "characters" / "lineup.json"
ROSTER = ROOT / "design" / "characters" / "roster.json"
HERO_LIST = ROOT / "design" / "characters" / "HERO_LIST_BY_RARITY.md"

RARITY_ORDER = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret"]
IDLES = ["IdleCool", "IdlePower", "IdleBlade", "IdleNinja", "IdleCheer", "IdleShy"]
# owner, 2026-11-26: Goku is the Starter Pack hero, Power joins the Chainsaw Man zone (a Legendary)
MOVES = {
    "instinct_warrior": {"premium": {"Source": "StarterPack", "BestIncomeMult": 1.5, "OddsPercent": 0}},
    "lucky_cat_mascot": {"lane": {"Zone": 10, "Rarity": "Legendary"}},
}


def pick(seq: list[str], key: str) -> str:
    return seq[int(hashlib.sha1(key.encode()).hexdigest(), 16) % len(seq)]


def seed_lineup() -> int:
    """Read the owner-approved list once and write lineup.json (then the json is the truth)."""
    game = json.loads(GAME.read_text(encoding="utf-8"))["config"]
    premium_now = {p["Id"]: p for p in game["PremiumCharacters"]}
    rarity, lane, premium = None, [], []
    for line in HERO_LIST.read_text(encoding="utf-8").splitlines():
        m = re.match(r"## (\w+) \((\d+)\)", line)
        if m:
            rarity = m.group(1)
            continue
        m = re.match(r"\| \d+ \| (.+?) \| (.+?) \| (\d+) \| (\w+) \|", line)
        if not m or rarity is None:
            continue
        name, source, zone, hid = m.group(1), m.group(2), int(m.group(3)), m.group(4)
        move = MOVES.get(hid, {})
        if (rarity == "Premium" and "lane" not in move) or "premium" in move:
            row = dict(premium_now.get(hid, {}))
            row.update(move.get("premium", {}))
            premium.append({"Id": hid, "Zone": zone, "Source": row["Source"],
                            "BestIncomeMult": row["BestIncomeMult"], "OddsPercent": row["OddsPercent"]})
        else:
            spot = move.get("lane", {"Zone": zone, "Rarity": rarity})
            lane.append({"Id": hid, "Zone": spot["Zone"], "Rarity": spot["Rarity"]})
    lane.sort(key=lambda r: (r["Zone"], RARITY_ORDER.index(r["Rarity"]), r["Id"]))
    order = ["Summon", "StarterPack", "Limited"]
    premium.sort(key=lambda r: (order.index(r["Source"]), -r["OddsPercent"], r["Id"]))
    LINEUP.write_text(json.dumps({
        "_what": "Gameplay lineup (plan 12): each thrown hero's zone (1..17) and rarity, and the premium heroes. "
                 "Edit here, then run tools/gen_characters.py. Seeded from HERO_LIST_BY_RARITY.md on 2026-11-26 "
                 "with the owner's two moves (Goku -> Starter Pack, Power -> zone 10 Legendary).",
        "lane": lane, "premium": premium}, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"wrote {LINEUP.relative_to(ROOT)}: {len(lane)} lane, {len(premium)} premium")
    return 0


def build(doc: dict) -> tuple[list[dict], list[dict]]:
    cfg = doc["config"]
    lineup = json.loads(LINEUP.read_text(encoding="utf-8"))
    roster = {r["Id"]: r for r in json.loads(ROSTER.read_text(encoding="utf-8"))}
    zones = cfg["Zones"]
    old = {c["Id"]: c for c in cfg["Characters"]}
    old.update({c["Id"]: c for c in cfg["PremiumCharacters"]})
    flavors = cfg["Flavors"]
    seen: set[str] = set()

    def base(hid: str) -> dict:
        if hid in seen:
            raise SystemExit(f"lineup: {hid} is listed twice")
        seen.add(hid)
        if hid not in roster:
            raise SystemExit(f"lineup: {hid} is not in roster.json")
        return roster[hid]

    lane = []
    for row in lineup["lane"]:
        r, prev = base(row["Id"]), old.get(row["Id"], {})
        if not 1 <= row["Zone"] <= len(zones):
            raise SystemExit(f"lineup: {row['Id']} zone {row['Zone']} does not exist")
        if row["Rarity"] not in cfg["Rarities"]:
            raise SystemExit(f"lineup: {row['Id']} rarity {row['Rarity']}")
        out = {"Id": row["Id"], "Name": r["Name"], "Zone": zones[row["Zone"] - 1]["Id"], "Rarity": row["Rarity"],
               "Craves": prev.get("Craves") or pick(flavors, row["Id"] + ":craves"),
               "Idle": prev.get("Idle") or pick(IDLES, row["Id"] + ":idle")}
        if prev.get("Line"):
            out["Line"] = prev["Line"]
        lane.append(out)

    premium = []
    for row in lineup["premium"]:
        r, prev = base(row["Id"]), old.get(row["Id"], {})
        out = {"Id": row["Id"], "Name": r["Name"], "Source": row["Source"],
               "Idle": prev.get("Idle") or pick(IDLES, row["Id"] + ":idle"),
               "Look": "imported avatar: " + r["Source"], "BestIncomeMult": row["BestIncomeMult"],
               "OddsPercent": row["OddsPercent"]}
        if prev.get("Line"):
            out["Line"] = prev["Line"]
        premium.append(out)
    odds = sum(p["OddsPercent"] for p in premium if p["Source"] == "Summon")
    if odds != 100:
        raise SystemExit(f"lineup: summon odds sum to {odds}, not 100")
    return lane, premium


def main() -> int:
    if "--seed-lineup" in sys.argv:
        return seed_lineup()
    doc = json.loads(GAME.read_text(encoding="utf-8"))
    lane, premium = build(doc)
    cfg = doc["config"]
    if "--check" in sys.argv:
        if cfg["Characters"] != lane or cfg["PremiumCharacters"] != premium:
            print("FAIL config.Characters / PremiumCharacters differ from design/characters/lineup.json; "
                  "run tools/gen_characters.py")
            return 1
        print(f"ok: {len(lane)} lane heroes, {len(premium)} premium")
        return 0
    cfg["Characters"], cfg["PremiumCharacters"] = lane, premium
    for product in cfg["Monetization"]["Products"]:
        if product.get("Kind") == "starter":
            product["Hero"] = next(p["Id"] for p in premium if p["Source"] == "StarterPack")
    GAME.write_text(json.dumps(doc, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    by_zone: dict[str, int] = {}
    for c in lane:
        by_zone[c["Zone"]] = by_zone.get(c["Zone"], 0) + 1
    print(f"wrote {len(lane)} lane heroes, {len(premium)} premium")
    print("  per zone: " + ", ".join(f"{z}={n}" for z, n in by_zone.items()))
    return 0


if __name__ == "__main__":
    sys.exit(main())
