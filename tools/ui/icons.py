"""Procedural system icons for Throw Food for Anime.

    python tools/ui/icons.py            # -> assets/ui/icons/<IconName>.png (256 px)

Every shape is GEOMETRY drawn with the roblox-ui skill's glyph renderer
(`glyphs.render`: silhouette mask, uniform dilation outline, top-lit shading), so
the set is consistent by construction. Nothing is generated or downloaded.
A cut-out narrower than twice the outline fills with the ink outline colour, which
is how the yen sign, the clock hands and the book spine read as dark detail.
Patterns (halftone dots, sheen, stripes) are written next to them for upload.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

SKILL = Path.home() / ".claude" / "skills" / "roblox-ui" / "scripts"
sys.path.insert(0, str(SKILL))
import glyphs  # noqa: E402
import patterns  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "ui" / "icons"
PAT_OUT = ROOT / "assets" / "ui" / "patterns"

glyphs.OUTLINE = (13, 15, 43)  # Manga Pop ink #0D0F2B
glyphs.PALETTE.update({
    "pink": (255, 79, 163), "orange": (255, 146, 60), "teal": (45, 205, 190),
    "sky": (56, 189, 248), "lime": (52, 209, 122), "violet": (168, 85, 247),
    "yellow": (255, 201, 60), "white": (250, 250, 255), "coral": (255, 90, 95),
})


def P(S, pts):
    return [(S * x, S * y) for x, y in pts]


def E(d, S, x0, y0, x1, y1, fill=255):
    d.ellipse([S * x0, S * y0, S * x1, S * y1], fill=fill)


def R(d, S, x0, y0, x1, y1, fill=255, r=0.0):
    if r:
        d.rounded_rectangle([S * x0, S * y0, S * x1, S * y1], radius=S * r, fill=fill)
    else:
        d.rectangle([S * x0, S * y0, S * x1, S * y1], fill=fill)


def L(d, S, pts, w, fill=255):
    d.line(P(S, pts), fill=fill, width=int(S * w), joint="curve")


def yen(d, S):
    E(d, S, 0.10, 0.10, 0.90, 0.90)
    L(d, S, [(0.34, 0.27), (0.50, 0.50), (0.66, 0.27)], 0.075, 0)
    L(d, S, [(0.50, 0.48), (0.50, 0.75)], 0.075, 0)
    L(d, S, [(0.35, 0.55), (0.65, 0.55)], 0.06, 0)
    L(d, S, [(0.35, 0.65), (0.65, 0.65)], 0.06, 0)


def power(d, S):
    d.polygon(P(S, [(0.60, 0.06), (0.22, 0.56), (0.46, 0.56), (0.38, 0.94),
                    (0.78, 0.40), (0.54, 0.40), (0.66, 0.06)]), fill=255)


def luck(d, S):
    for dx, dy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        cx, cy = 0.5 + dx * 0.15, 0.44 + dy * 0.15
        E(d, S, cx - 0.17, cy - 0.17, cx + 0.17, cy + 0.17)
    L(d, S, [(0.50, 0.50), (0.58, 0.72), (0.70, 0.90)], 0.08)
    L(d, S, [(0.50, 0.12), (0.50, 0.76)], 0.035, 0)
    L(d, S, [(0.18, 0.44), (0.82, 0.44)], 0.035, 0)


def squad(d, S):
    E(d, S, 0.52, 0.16, 0.80, 0.44)
    d.pieslice([S * 0.42, S * 0.46, S * 0.92, S * 0.98], 180, 360, fill=255)
    E(d, S, 0.20, 0.22, 0.52, 0.54)
    d.pieslice([S * 0.08, S * 0.56, S * 0.64, S * 1.12], 180, 360, fill=255)
    R(d, S, 0.08, 0.83, 0.92, 0.86, fill=0)


def index_book(d, S):
    d.polygon(P(S, [(0.08, 0.24), (0.48, 0.30), (0.48, 0.86), (0.08, 0.78)]), fill=255)
    d.polygon(P(S, [(0.52, 0.30), (0.92, 0.24), (0.92, 0.78), (0.52, 0.86)]), fill=255)
    L(d, S, [(0.16, 0.40), (0.40, 0.44)], 0.04, 0)
    L(d, S, [(0.16, 0.54), (0.40, 0.58)], 0.04, 0)
    L(d, S, [(0.60, 0.44), (0.84, 0.40)], 0.04, 0)


def shop_bowl(d, S):
    L(d, S, [(0.30, 0.10), (0.62, 0.46)], 0.06)
    L(d, S, [(0.46, 0.08), (0.70, 0.46)], 0.06)
    d.pieslice([S * 0.10, S * 0.20, S * 0.90, S * 0.92], 0, 180, fill=255)
    R(d, S, 0.08, 0.50, 0.92, 0.60, r=0.04)
    R(d, S, 0.34, 0.86, 0.66, 0.94, r=0.03)
    L(d, S, [(0.10, 0.62), (0.90, 0.62)], 0.035, 0)


def gem(d, S):
    d.polygon(P(S, [(0.28, 0.18), (0.72, 0.18), (0.90, 0.40), (0.50, 0.90), (0.10, 0.40)]), fill=255)
    L(d, S, [(0.12, 0.40), (0.88, 0.40)], 0.04, 0)
    L(d, S, [(0.38, 0.40), (0.50, 0.84)], 0.035, 0)
    L(d, S, [(0.62, 0.40), (0.50, 0.84)], 0.035, 0)


def rebirth(d, S):
    d.arc([S * 0.16, S * 0.16, S * 0.84, S * 0.84], 30, 300, fill=255, width=int(S * 0.13))
    d.polygon(P(S, [(0.60, 0.02), (0.88, 0.22), (0.56, 0.38)]), fill=255)


def gift(d, S):
    R(d, S, 0.16, 0.44, 0.84, 0.90, r=0.04)
    R(d, S, 0.10, 0.30, 0.90, 0.46, r=0.04)
    E(d, S, 0.22, 0.10, 0.50, 0.34)
    E(d, S, 0.50, 0.10, 0.78, 0.34)
    R(d, S, 0.465, 0.30, 0.535, 0.90, fill=0)
    R(d, S, 0.16, 0.455, 0.84, 0.485, fill=0)


def gear(d, S):
    cx = cy = S * 0.5
    for i in range(8):
        a = math.radians(i * 45)
        pts = []
        for da, rr in ((-0.20, 0.30), (-0.13, 0.45), (0.13, 0.45), (0.20, 0.30)):
            pts.append((cx + math.cos(a + da) * S * rr, cy + math.sin(a + da) * S * rr))
        d.polygon(pts, fill=255)
    E(d, S, 0.18, 0.18, 0.82, 0.82)
    E(d, S, 0.38, 0.38, 0.62, 0.62, fill=0)


def ticket(d, S):
    R(d, S, 0.08, 0.26, 0.92, 0.74, r=0.06)
    E(d, S, 0.01, 0.41, 0.17, 0.59, fill=0)
    E(d, S, 0.83, 0.41, 0.99, 0.59, fill=0)
    for y in (0.32, 0.44, 0.56):
        L(d, S, [(0.64, y), (0.64, y + 0.06)], 0.04, 0)
    L(d, S, [(0.24, 0.44), (0.52, 0.44)], 0.045, 0)
    L(d, S, [(0.24, 0.56), (0.46, 0.56)], 0.045, 0)


def sparkle(d, S):
    d.polygon(glyphs._star_points(S * 0.46, S * 0.52, S * 0.42, S * 0.12, points=4), fill=255)
    d.polygon(glyphs._star_points(S * 0.80, S * 0.20, S * 0.15, S * 0.05, points=4), fill=255)


def onigiri(d, S):
    d.polygon(P(S, [(0.50, 0.14), (0.86, 0.78), (0.14, 0.78)]), fill=255)
    for cx, cy in ((0.50, 0.24), (0.76, 0.76), (0.24, 0.76)):
        E(d, S, cx - 0.12, cy - 0.12, cx + 0.12, cy + 0.12)
    R(d, S, 0.20, 0.62, 0.80, 0.88)
    R(d, S, 0.445, 0.60, 0.555, 0.88, fill=0)


def lollipop(d, S):
    R(d, S, 0.46, 0.50, 0.54, 0.94, r=0.03)
    E(d, S, 0.18, 0.06, 0.82, 0.70)
    d.arc([S * 0.30, S * 0.18, S * 0.70, S * 0.58], 200, 470, fill=0, width=int(S * 0.045))


def flame(d, S):
    E(d, S, 0.18, 0.40, 0.82, 0.94)
    d.polygon(P(S, [(0.20, 0.62), (0.34, 0.30), (0.46, 0.44), (0.54, 0.06),
                    (0.72, 0.36), (0.80, 0.26), (0.84, 0.64)]), fill=255)
    E(d, S, 0.38, 0.62, 0.62, 0.86, fill=0)


def fish(d, S):
    E(d, S, 0.08, 0.28, 0.70, 0.72)
    d.polygon(P(S, [(0.62, 0.50), (0.94, 0.24), (0.88, 0.50), (0.94, 0.76)]), fill=255)
    E(d, S, 0.20, 0.40, 0.29, 0.49, fill=0)
    d.arc([S * 0.30, S * 0.32, S * 0.50, S * 0.68], 300, 60, fill=0, width=int(S * 0.04))


def auto(d, S):
    d.arc([S * 0.08, S * 0.08, S * 0.92, S * 0.92], 0, 360, fill=255, width=int(S * 0.10))
    d.polygon(P(S, [(0.38, 0.28), (0.74, 0.50), (0.38, 0.72)]), fill=255)


def timer(d, S):
    R(d, S, 0.42, 0.04, 0.58, 0.16, r=0.02)
    E(d, S, 0.12, 0.14, 0.88, 0.90)
    L(d, S, [(0.50, 0.30), (0.50, 0.53), (0.66, 0.62)], 0.065, 0)


def dumbbell(d, S):
    R(d, S, 0.20, 0.45, 0.80, 0.55)
    R(d, S, 0.10, 0.24, 0.26, 0.76, r=0.04)
    R(d, S, 0.74, 0.24, 0.90, 0.76, r=0.04)
    R(d, S, 0.03, 0.34, 0.12, 0.66, r=0.02)
    R(d, S, 0.88, 0.34, 0.97, 0.66, r=0.02)


def robux(d, S):
    pts = [(0.5 + 0.42 * math.cos(math.radians(a)), 0.5 + 0.42 * math.sin(math.radians(a)))
           for a in range(30, 390, 60)]
    d.polygon(P(S, pts), fill=255)
    R(d, S, 0.40, 0.40, 0.60, 0.60, fill=0)


def tag(d, S):
    d.polygon(P(S, [(0.10, 0.50), (0.36, 0.20), (0.90, 0.20), (0.90, 0.80), (0.36, 0.80)]), fill=255)
    E(d, S, 0.28, 0.44, 0.38, 0.56, fill=0)
    L(d, S, [(0.52, 0.42), (0.78, 0.42)], 0.05, 0)
    L(d, S, [(0.52, 0.58), (0.72, 0.58)], 0.05, 0)


def music(d, S):
    E(d, S, 0.12, 0.62, 0.42, 0.88)
    R(d, S, 0.34, 0.14, 0.42, 0.76)
    d.polygon(P(S, [(0.34, 0.12), (0.82, 0.24), (0.82, 0.42), (0.42, 0.32)]), fill=255)
    E(d, S, 0.56, 0.52, 0.86, 0.78)
    R(d, S, 0.78, 0.24, 0.86, 0.66)


def speaker(d, S):
    R(d, S, 0.08, 0.36, 0.28, 0.64)
    d.polygon(P(S, [(0.24, 0.36), (0.52, 0.14), (0.52, 0.86), (0.24, 0.64)]), fill=255)
    d.arc([S * 0.40, S * 0.30, S * 0.72, S * 0.70], -50, 50, fill=255, width=int(S * 0.07))
    d.arc([S * 0.42, S * 0.14, S * 0.92, S * 0.86], -50, 50, fill=255, width=int(S * 0.07))


def crown(d, S):
    d.polygon(P(S, [(0.10, 0.30), (0.30, 0.52), (0.50, 0.20), (0.70, 0.52), (0.90, 0.30),
                    (0.84, 0.76), (0.16, 0.76)]), fill=255)
    R(d, S, 0.16, 0.78, 0.84, 0.88, r=0.03)
    for x in (0.10, 0.50, 0.90):
        E(d, S, x - 0.07, 0.14 if x == 0.5 else 0.24, x + 0.07, (0.14 if x == 0.5 else 0.24) + 0.14)


def info(d, S):
    E(d, S, 0.08, 0.08, 0.92, 0.92)
    E(d, S, 0.44, 0.22, 0.56, 0.34, fill=0)
    R(d, S, 0.455, 0.42, 0.545, 0.76, fill=0)


def eye(d, S):
    d.chord([S * 0.06, S * 0.18, S * 0.94, S * 0.98], 200, 340, fill=255)
    d.chord([S * 0.06, S * 0.02, S * 0.94, S * 0.82], 20, 160, fill=255)
    E(d, S, 0.38, 0.38, 0.62, 0.62, fill=0)
    L(d, S, [(0.16, 0.86), (0.84, 0.14)], 0.07, 0)


def fast(d, S):
    for x in (0.12, 0.46):
        d.polygon(P(S, [(x, 0.18), (x + 0.42, 0.50), (x, 0.82), (x + 0.10, 0.50)]), fill=255)


def lowdetail(d, S):
    for x0, y0 in ((0.12, 0.12), (0.54, 0.12), (0.12, 0.54), (0.54, 0.54)):
        R(d, S, x0, y0, x0 + 0.34, y0 + 0.34, r=0.05)


def bench(d, S):
    R(d, S, 0.08, 0.30, 0.92, 0.46, r=0.04)
    R(d, S, 0.08, 0.52, 0.92, 0.62, r=0.03)
    R(d, S, 0.16, 0.60, 0.26, 0.90)
    R(d, S, 0.74, 0.60, 0.84, 0.90)


def place(d, S):
    glyphs._bar(d, S / 2, S * 0.36, S * 0.36, S * 0.16, 90)
    d.polygon(P(S, [(0.5, 0.80), (0.74, 0.52), (0.26, 0.52)]), fill=255)
    R(d, S, 0.14, 0.84, 0.86, 0.94, r=0.03)


def scroll(d, S):
    R(d, S, 0.20, 0.18, 0.80, 0.82, r=0.02)
    E(d, S, 0.06, 0.12, 0.30, 0.36)
    E(d, S, 0.70, 0.64, 0.94, 0.88)
    L(d, S, [(0.34, 0.40), (0.66, 0.40)], 0.045, 0)
    L(d, S, [(0.34, 0.54), (0.66, 0.54)], 0.045, 0)


def throw(d, S):
    E(d, S, 0.40, 0.22, 0.92, 0.74)
    for y, x0 in ((0.32, 0.16), (0.48, 0.06), (0.64, 0.16)):
        L(d, S, [(x0, y), (0.36, y)], 0.07)


def starburst(d, S):
    d.polygon(glyphs._star_points(S / 2, S / 2, S * 0.47, S * 0.30, points=14), fill=255)


GAME_GLYPHS = {
    "FxStarburst": (starburst, "white"),
    "IconYen": (yen, "yellow"), "IconPower": (dumbbell, "violet"), "IconLuck": (luck, "lime"),
    "IconSquad": (squad, "sky"), "IconIndex": (index_book, "violet"),
    "IconShop": (shop_bowl, "orange"), "IconStore": (gem, "pink"),
    "IconRebirth": (rebirth, "yellow"), "IconGift": (gift, "coral"),
    "IconSettings": (gear, "grey"), "IconCodes": (ticket, "violet"),
    "IconLuckyThrow": (sparkle, "yellow"), "IconFlavorSavory": (onigiri, "cream"),
    "IconFlavorSweet": (lollipop, "pink"), "IconFlavorSpicy": (flame, "coral"),
    "IconFlavorSeafood": (fish, "teal"), "IconStar": (glyphs.star, "gold"),
    "IconLock": (glyphs.lock, "gold"), "IconClose": (glyphs.close, "white"),
    "IconTick": (glyphs.tick, "white"), "IconArrow": (glyphs.arrow, "yellow"),
    "IconPlus": (glyphs.plus, "white"), "IconAuto": (auto, "white"),
    "IconTimer": (timer, "white"), "IconTrain": (dumbbell, "grey"),
    "IconRobux": (robux, "white"), "IconSell": (tag, "coral"), "IconFuse": (glyphs.plus, "lime"),
    "IconMusic": (music, "white"), "IconSfx": (speaker, "white"), "IconCrown": (crown, "gold"),
    "IconInfo": (info, "white"), "IconHide": (eye, "white"), "IconFast": (fast, "white"),
    "IconLowDetail": (lowdetail, "white"), "IconBench": (bench, "white"),
    "IconPlace": (place, "white"), "IconScroll": (scroll, "cream"), "IconThrow": (throw, "white"),
}


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (fn, colour) in GAME_GLYPHS.items():
        img = glyphs.render(fn, colour, 256, white=False)
        img.save(OUT / f"{name}.png")
    # a faint sunburst for behind food art: white, alpha baked at 30% (the client can tint it)
    sb = glyphs.render(starburst, "white", 256, white=True)
    sb.putalpha(sb.getchannel("A").point(lambda v: int(v * 0.30)))
    sb.save(OUT / "FxSunburst.png")
    PAT_OUT.mkdir(parents=True, exist_ok=True)
    for n in ("dots", "sheen", "stripes"):
        patterns.tile(n).save(PAT_OUT / f"pattern_{n}.png")
    print(f"{len(GAME_GLYPHS)} icons -> {OUT}; patterns -> {PAT_OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
