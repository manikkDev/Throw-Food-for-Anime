#!/usr/bin/env python3
"""Emit `src/shared/Config/FoodFeel.luau` from design/foods.json (plan 13 phase C).

    python tools/gen_food_feel.py            write the file
    python tools/gen_food_feel.py --check    exit 1 if it has drifted

Per food: how it is thrown (pitch / heave / spin), the sound it lands with, and a Signature dish's
own landing accent. The client's Fx/FoodFx reads it; the food templates carry `Throw` too (set by
install_foods), this table is the same value without needing the template.
"""
from __future__ import annotations

import colorsys
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "src" / "shared" / "Config" / "FoodFeel.luau"
THROWS = {"pitch", "heave", "spin"}
PALE = 0.16  # coloured share below which a dish counts as colourless
LANDS = {"bowl", "plate", "soft", "sizzle", "glass", "splash"}


def dish_colour(key: str) -> str:
    """The dish's own colour, from its icon (assets/ui/food_icons_v2): the saturation-weighted
    mean hue of the food's pixels, at a fixed lively saturation and value so a tinted trail or
    aroma never comes out grey or dark. FFC93C when the icon is missing."""
    png = ROOT / "assets" / "ui" / "food_icons_v2" / f"Food_{key}.png"
    if not png.exists():
        return "FFC93C"
    im = Image.open(png).convert("RGBA").resize((64, 64), Image.LANCZOS)
    bins = [0.0] * 24
    sat_sum = weight = 0.0
    solid = 0
    for r, g, b, a in im.get_flattened_data():
        if a < 200:
            continue
        solid += 1
        h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        if v < 0.2 or s < 0.25:  # the ink outline, white rice, plates
            continue
        w = s * v
        bins[int(h * 24) % 24] += w
        sat_sum += s * w
        weight += w
    if weight <= 0 or weight / max(solid, 1) < PALE:
        return "FFE2A8"  # a dish with almost no colour of its own (rice, mochi): warm cream
    top = max(range(24), key=lambda i: bins[i - 1] + bins[i] + bins[(i + 1) % 24])
    r, g, b = colorsys.hsv_to_rgb((top + 0.5) / 24, min(0.85, max(0.6, sat_sum / weight)), 1.0)
    return "%02X%02X%02X" % (round(r * 255), round(g * 255), round(b * 255))


def render() -> str:
    foods = json.loads((ROOT / "design" / "foods.json").read_text(encoding="utf-8"))["foods"]
    lines = [
        "--!strict",
        "-- GENERATED FILE - DO NOT EDIT BY HAND.",
        "-- Source: design/foods.json (throw, land, accent)",
        "-- Regenerate: python tools/gen_food_feel.py",
        "-- How each food is thrown, the sound it lands with, its own colour (from its icon: tints its",
        "-- trail and aroma), a Signature dish's landing accent.",
        "",
        "export type Feel = { throw: string, land: string, color: string, accent: string? }",
        "",
        "local FoodFeel: { [string]: Feel } = {",
    ]
    for key in sorted(foods):
        row = foods[key]
        if row.get("throw") not in THROWS or row.get("land") not in LANDS:
            raise SystemExit(f"{key}: throw {row.get('throw')!r} / land {row.get('land')!r} is not a known class")
        accent = f', accent = "{row["accent"]}"' if row.get("accent") else ""
        lines.append(f'\t{key} = {{ throw = "{row["throw"]}", land = "{row["land"]}", color = "{dish_colour(key)}"{accent} }},')
    lines += ["}", "", "return FoodFeel", ""]
    return "\n".join(lines)


def missing() -> list[str]:
    """What a food's feel points at that does not exist: the landing sound of its class, a
    Signature dish's accent sound and its two effects (Fx/FoodFx builds these names)."""
    foods = json.loads((ROOT / "design" / "foods.json").read_text(encoding="utf-8"))["foods"]
    config = json.loads((ROOT / "design" / "game.json").read_text(encoding="utf-8"))["config"]["Foods"]
    roles = {row["role"] for row in json.loads((ROOT / "assets" / "sfx" / "manifest.json").read_text(encoding="utf-8"))["sounds"]}
    effects = {f.stem for f in (ROOT / "assets" / "vfx" / "effects").glob("*.json")}
    out = []
    for need in ("throw_whoosh", "throw_heave", "throw_spin", "food_ready", "sig_sting", "favourite_burst"):
        if need not in roles:
            out.append(f"sound role {need}")
    for need in ("ThrowTrail_Basic", "ThrowTrail_Meal", "Land_Impact", "Land_Meal", "Aroma_Meal", "Aroma_Signature", "Favourite_Burst"):
        if need not in effects:
            out.append(f"effect {need}")
    for food in config:
        key = food["Id"]
        row = foods.get(key)
        if not row:
            out.append(f"{key}: not in design/foods.json")
            continue
        if f"land_{row['land']}" not in roles:
            out.append(f"{key}: sound role land_{row['land']}")
        if food["Role"] == "Signature":
            if not row.get("accent"):
                out.append(f"{key}: a Signature dish needs an accent")
            elif f"sig_{row['accent']}" not in roles:
                out.append(f"{key}: sound role sig_{row['accent']}")
            for kind in ("Trail", "Land"):
                if f"Sig_{key}_{kind}" not in effects:
                    out.append(f"{key}: effect Sig_{key}_{kind}")
    return out


def main() -> int:
    text = render()
    if "--check" in sys.argv:
        if not OUT.exists() or OUT.read_text(encoding="utf-8") != text:
            print("FoodFeel.luau has drifted: run python tools/gen_food_feel.py")
            return 1
        gaps = missing()
        for gap in gaps:
            print("missing:", gap)
        return 1 if gaps else 0
    OUT.write_text(text, encoding="utf-8", newline="\n")
    print(f"wrote {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
