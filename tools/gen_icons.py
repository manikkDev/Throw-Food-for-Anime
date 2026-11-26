#!/usr/bin/env python3
"""Emit `src/shared/Config/Icons.luau` from the uploaded icon id maps.

    python tools/gen_icons.py            write the file
    python tools/gen_icons.py --check    exit 1 if it has drifted

Sources (written by the roblox-ui skill's upload_icons.py, one per folder):
    assets/ui/ids_icons.json        system glyphs   IconYen, IconShop, ...
    assets/ui/ids_food_icons.json   food renders    Food_onigiri, ...
    assets/ui/ids_patterns.json     panel patterns  pattern_dots, ...
    assets/ui/ids_icons_big.json    the v3 large glossy family, own keys (IconShopBig, ...).
                                    ids_icons_v2.json is the retired v2 map, not read.
    assets/ui/ids_icons_v4.json     icons v4 (tools/ui/icons_v4.py): ONE premium rendered family for every
                                    base key, every ...Big key, IconRobux/IconRobuxBig and the re-framed
                                    Food_* icons. Read LAST, so it overrides the older maps key by key; the
                                    older maps stay as fallbacks for any key v4 does not carry (FxStarburst,
                                    FxSunburst, pattern_*).
    assets/ui/ids_zone_bg.json      Hero Index zone card backdrops ZoneBg_<zoneId> (tools/ui/zone_backdrops.py).
    assets/ui/ids_food_icons_v2.json  plan 13 food icons, rendered from the real food models (tools/ui/food_icons_v2.py):
                                    Food_<id> for the 51 foods. Read last: a food's own icon replaces a stand-in.
    assets/ui/ids_cards.json        card-opening art (tools/ui/cards_art.py): CardBack, CardFrame_<Tier>, CardBanner_<Tier>,
                                    CardFoil, CardWindowShade, CardPortraitBg, CelebrateBackdrop, CelebrateBanner.

The UI trees carry no image ids: every icon slot is an ImageLabel with an `IconKey` attribute and
every patterned panel a `PatternName`. The client fills them from this table when it mounts a
screen. WHY: ids only exist after an upload, an image can be re-uploaded (new id) without the
screen files changing, and a key with no id leaves a blank slot instead of an error.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "src" / "shared" / "Config" / "Icons.luau"
# Order matters: a later map overrides an earlier one key by key. v4 is last on purpose.
MAPS = ["ids_icons.json", "ids_food_icons.json", "ids_patterns.json", "ids_icons_big.json", "ids_icons_v4.json", "ids_fx_v4.json",
        "ids_zone_bg.json", "ids_cards.json", "ids_food_icons_v2.json"]

BANNER = """--!strict
-- GENERATED FILE - DO NOT EDIT BY HAND.
-- Source: assets/ui/ids_*.json (uploaded image ids)
-- Regenerate: python tools/gen_icons.py
-- IconKey / PatternName -> image. A key that is missing here leaves its slot blank.
"""


def render() -> str:
    rows: dict[str, int] = {}
    for name in MAPS:
        path = ROOT / "assets" / "ui" / name
        if not path.exists():
            continue
        for key, value in json.loads(path.read_text(encoding="utf-8")).items():
            if isinstance(value, int) and not key.startswith("_"):
                rows[key] = value
    # the UI specs name a food slot FoodIcon_<id>; the uploads call it Food_<id>: both keys
    for key in list(rows):
        if key.startswith("Food_") and f"FoodIcon_{key[5:]}" not in rows:
            rows[f"FoodIcon_{key[5:]}"] = rows[key]
    lines = [BANNER, "local Icons: { [string]: string } = {"]
    for key in sorted(rows):
        lines.append(f'\t{key} = "rbxassetid://{rows[key]}",')
    # filled per player at run time (the leaderboard rows: WorldUiController sets an rbxthumb://
    # avatar headshot for each entry); listed so a key check knows it is a runtime image
    lines.append('\tPlayerHeadshot = "",')
    lines += ["}", "", "return Icons", ""]
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    text = render()
    if a.check:
        if not OUT.exists() or OUT.read_text(encoding="utf-8") != text:
            print(f"FAIL {OUT} has drifted from assets/ui/ids_*.json; run tools/gen_icons.py")
            return 1
        print(f"ok   Icons matches the uploaded ids ({text.count('rbxassetid')} images)")
        return 0
    OUT.write_text(text, encoding="utf-8", newline="\n")
    print(f"wrote {OUT} ({text.count('rbxassetid')} images)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
