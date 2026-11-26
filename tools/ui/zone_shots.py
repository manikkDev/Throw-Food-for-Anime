"""Hero Index zone cards from pictures of the zones themselves (2026-11-26, economy v2: 17 zones).

    python tools/ui/zone_shots.py                 # work/zone_bg/shots/<zone id>.jpg -> assets/ui/zone_bg/ZoneBg_<zone id>.png
    python ~/.claude/skills/roblox-ui/scripts/upload_icons.py --icons assets/ui/zone_bg --map assets/ui/ids_zone_bg.json
    python tools/gen_icons.py                     # ZoneBg_<zone id> -> src/shared/Config/Icons.luau

WHY: the six painted backdrops of tools/ui/zone_backdrops.py showed the OLD zone themes (a sakura schoolyard, a
pirate harbor ...); the zones are the 17 anime zones now, each with its own built set pieces, so the card shows the
real place the player throws into.

HOW THE SHOTS ARE TAKEN (Studio, edit mode; the camera for zone i with z0 = 160 + 360 * (i - 1)):
    python tools/studio/zones/run_zone.py look 30 12 <z0+150> -150 -22 <z0+210> 5     # park first: the ground loads
    screen_capture with NO camera position                                            # then capture
A capture WITH a camera position is taken at once, while the terrain is still coarse: paving shows as flat green.
Save each as work/zone_bg/shots/<zone id>.jpg. Afterwards set the camera type back to Fixed.

The card is about 2.3 : 1: the shot is cropped to the terrace across the lane (clear of the gate pillar on the left
and of the lane floor at the bottom), then darkened a little toward the bottom-left where the zone name sits.
"""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SHOTS = ROOT / "work" / "zone_bg" / "shots"
OUT = ROOT / "assets" / "ui" / "zone_bg"
CARD = (480, 208)
# the crop inside a 1356 x 642 capture: x from just right of the near gate pillar, y from the wall's roof line
# to just above the lane's kerb
CROP = (300, 150, 1300, 583)


def card(path: Path) -> Image.Image:
    im = Image.open(path).convert("RGB")
    sx, sy = im.width / 1356, im.height / 642
    box = (round(CROP[0] * sx), round(CROP[1] * sy), round(CROP[2] * sx), round(CROP[3] * sy))
    im = im.crop(box).resize(CARD, Image.LANCZOS)
    im = ImageEnhance.Color(im).enhance(1.08)
    # darker toward the bottom-left, where the zone's name is written in white
    shade = Image.new("L", CARD, 0)
    d = ImageDraw.Draw(shade)
    d.ellipse([-CARD[0] * 0.55, CARD[1] * 0.25, CARD[0] * 0.75, CARD[1] * 1.9], fill=110)
    shade = shade.filter(ImageFilter.GaussianBlur(46))
    return Image.composite(Image.new("RGB", CARD, (10, 12, 40)), im, shade)


def main() -> int:
    zones = json.loads((ROOT / "design" / "game.json").read_text(encoding="utf-8"))["config"]["Zones"]
    OUT.mkdir(parents=True, exist_ok=True)
    missing = []
    for zone in zones:
        src = SHOTS / f"{zone['Id']}.jpg"
        if not src.exists():
            missing.append(zone["Id"])
            continue
        card(src).save(OUT / f"ZoneBg_{zone['Id']}.png")
    sheet = Image.new("RGB", (CARD[0] * 3 + 40, (CARD[1] + 10) * 6 + 10), (24, 26, 60))
    for i, zone in enumerate(zones):
        p = OUT / f"ZoneBg_{zone['Id']}.png"
        if p.exists():
            sheet.paste(Image.open(p), (10 + (i % 3) * (CARD[0] + 10), 10 + (i // 3) * (CARD[1] + 10)))
    sheet.save(ROOT / "work" / "zone_bg" / "_cards.png")
    print(f"wrote {len(zones) - len(missing)} cards" + (f"; no shot for {missing}" if missing else ""))
    return 1 if missing else 0


if __name__ == "__main__":
    raise SystemExit(main())
