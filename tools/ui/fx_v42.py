"""UI v4.2 effect sprites and store card backdrops, painted procedurally (no generator quota needed).

    python tools/ui/fx_v42.py            # -> assets/ui/fx_v4/<Key>.png (+ work/ui/fx_v42_sheet.png)
    python ~/.claude/skills/roblox-ui/scripts/upload_icons.py --icons assets/ui/fx_v4 --map assets/ui/ids_fx_v4.json
    python tools/gen_icons.py            # -> src/shared/Config/Icons.luau

Every sprite is WHITE with an alpha shape, so the client tints it with ImageColor3 (a rarity, a section colour) and
fades it with ImageTransparency. Particles do not render inside a ViewportFrame, so every glow the Reward popup, the
store's summon aura and the prompts show is one of these images on the UI layer.

  FxGlow      soft radial glow                     FxRays     soft light rays (16, feathered), loops when turned
  FxRing      soft halo ring                       FxTwinkle  four-point sparkle with a soft core
  FxPetal     sakura petal                         FxFlame    a rising flame tongue (aura sprite)
  FxTap       a tap ripple (touch key cap)         FxShine    a soft diagonal gloss streak
  BgClouds / BgSakura / BgStars / BgRays           card backdrops (2:1), blended in at low opacity
"""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "ui" / "fx_v4"
SS = 2


def white(alpha: Image.Image) -> Image.Image:
    im = Image.new("RGBA", alpha.size, (255, 255, 255, 0))
    im.putalpha(alpha)
    return im


def radial(side, inner=0.0, power=2.2):
    a = Image.new("L", (side, side))
    px = a.load()
    c = (side - 1) / 2
    for y in range(side):
        for x in range(side):
            d = math.hypot(x - c, y - c) / c
            v = 0.0 if d >= 1 else (1 - max(0.0, d - inner) / (1 - inner)) ** power
            px[x, y] = int(255 * max(0.0, min(1.0, v)))
    return a


def glow():
    return white(radial(256, 0.0, 2.4))


def ring():
    side = 256
    a = Image.new("L", (side, side))
    px = a.load()
    c = (side - 1) / 2
    for y in range(side):
        for x in range(side):
            d = math.hypot(x - c, y - c) / c
            v = math.exp(-((d - 0.78) / 0.09) ** 2)
            px[x, y] = int(255 * v)
    return white(a)


def rays(n=16):
    side = 512 * SS
    a = Image.new("L", (side, side), 0)
    d = ImageDraw.Draw(a)
    c = side / 2
    for i in range(n):
        ang = 2 * math.pi * i / n
        half = math.pi / n * (0.55 if i % 2 else 0.35)
        r = side * 0.5
        pts = [(c, c), (c + r * math.cos(ang - half), c + r * math.sin(ang - half)),
               (c + r * math.cos(ang + half), c + r * math.sin(ang + half))]
        d.polygon(pts, fill=255 if i % 2 == 0 else 170)
    a = a.filter(ImageFilter.GaussianBlur(6 * SS)).resize((512, 512), Image.LANCZOS)
    fall = radial(512, 0.05, 1.3)
    return white(ImageChops.multiply(a, fall))


def twinkle():
    side = 128 * SS
    a = Image.new("L", (side, side), 0)
    d = ImageDraw.Draw(a)
    c = side / 2
    for ang, long_ in ((0, 0.5), (math.pi / 2, 0.5), (math.pi / 4, 0.26), (3 * math.pi / 4, 0.26)):
        for sgn in (1, -1):
            tip = (c + sgn * long_ * side * math.cos(ang), c + sgn * long_ * side * math.sin(ang))
            w = side * (0.07 if long_ > 0.3 else 0.045)
            px_, py_ = -math.sin(ang) * w, math.cos(ang) * w
            d.polygon([tip, (c + px_, c + py_), (c - px_, c - py_)], fill=255)
    a = a.filter(ImageFilter.GaussianBlur(1.2 * SS)).resize((128, 128), Image.LANCZOS)
    core = radial(128, 0.0, 3.0)
    return white(ImageChops.lighter(a, core))


def petal():
    side = 128 * SS
    a = Image.new("L", (side, side), 0)
    d = ImageDraw.Draw(a)
    # a teardrop with a notch at the wide end
    d.ellipse([side * 0.22, side * 0.12, side * 0.78, side * 0.80], fill=255)
    d.polygon([(side * 0.5, side * 0.97), (side * 0.25, side * 0.55), (side * 0.75, side * 0.55)], fill=255)
    d.polygon([(side * 0.5, side * 0.30), (side * 0.40, side * 0.08), (side * 0.60, side * 0.08)], fill=0)
    a = a.filter(ImageFilter.GaussianBlur(1.5 * SS)).resize((128, 128), Image.LANCZOS)
    return white(a)


def flame():
    w, h = 128 * SS, 256 * SS
    a = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(a)
    pts = []
    for i in range(41):
        t = i / 40  # 0 bottom .. 1 tip
        half = (math.sin(math.pi * min(1, t * 1.15)) ** 0.8) * 0.42 * w * (1 - t) ** 0.35
        sway = math.sin(t * 5.0) * 0.06 * w * t
        pts.append((w / 2 + sway + half, h * (0.97 - 0.92 * t)))
    for i in range(40, -1, -1):
        t = i / 40
        half = (math.sin(math.pi * min(1, t * 1.15)) ** 0.8) * 0.42 * w * (1 - t) ** 0.35
        sway = math.sin(t * 5.0) * 0.06 * w * t
        pts.append((w / 2 + sway - half, h * (0.97 - 0.92 * t)))
    d.polygon(pts, fill=255)
    a = a.filter(ImageFilter.GaussianBlur(5 * SS)).resize((128, 256), Image.LANCZOS)
    # brighter core, fading tip
    grad = Image.linear_gradient("L").resize((128, 256))  # 0 top .. 255 bottom
    a = ImageChops.multiply(a, grad.point(lambda v: int(70 + 185 * (v / 255) ** 0.6)))
    return white(a)


def tap():
    side = 128 * SS
    a = Image.new("L", (side, side), 0)
    d = ImageDraw.Draw(a)
    c = side / 2
    d.ellipse([c - side * 0.13, c - side * 0.13, c + side * 0.13, c + side * 0.13], fill=255)
    for r, w_ in ((0.27, 0.045), (0.42, 0.035)):
        d.ellipse([c - side * r, c - side * r, c + side * r, c + side * r], outline=255 if r < 0.3 else 170,
                  width=int(side * w_))
    a = a.filter(ImageFilter.GaussianBlur(0.8 * SS)).resize((128, 128), Image.LANCZOS)
    return white(a)


def shine():
    w, h = 256, 128
    a = Image.new("L", (w, h), 0)
    px = a.load()
    for y in range(h):
        for x in range(w):
            u = (x - w / 2 + (y - h / 2) * 0.45) / (w * 0.16)
            px[x, y] = int(255 * math.exp(-u * u))
    return white(a)


# ------------------------------------------------------------------ card backdrops (2:1, monochrome white)

BW, BH = 512, 256


def bg_clouds():
    rnd = random.Random(7)
    a = Image.new("L", (BW, BH), 0)
    d = ImageDraw.Draw(a)
    for _ in range(9):
        cx, cy = rnd.uniform(0, BW), rnd.uniform(BH * 0.35, BH * 1.05)
        s = rnd.uniform(40, 90)
        for k in range(6):
            ox, oy = rnd.uniform(-1.6, 1.6) * s, rnd.uniform(-0.5, 0.2) * s
            r = s * rnd.uniform(0.55, 1.0)
            d.ellipse([cx + ox - r, cy + oy - r, cx + ox + r, cy + oy + r], fill=rnd.randint(90, 190))
    a = a.filter(ImageFilter.GaussianBlur(7))
    return white(a)


def bg_sakura():
    rnd = random.Random(11)
    a = Image.new("L", (BW, BH), 0)
    p = petal().getchannel("A")
    for _ in range(34):
        s = rnd.randint(18, 40)
        im = p.resize((s, s), Image.LANCZOS).rotate(rnd.uniform(0, 360), expand=True, resample=Image.BICUBIC)
        im = im.point(lambda v, k=rnd.uniform(0.45, 1.0): int(v * k))
        a.paste(Image.new("L", im.size, 255), (rnd.randint(-10, BW), rnd.randint(-10, BH)), im)
    return white(a.filter(ImageFilter.GaussianBlur(0.6)))


def bg_stars():
    rnd = random.Random(3)
    a = Image.new("L", (BW, BH), 0)
    d = ImageDraw.Draw(a)
    for _ in range(140):
        x, y, r = rnd.uniform(0, BW), rnd.uniform(0, BH), rnd.choice([0.8, 1.0, 1.3, 1.8])
        d.ellipse([x - r, y - r, x + r, y + r], fill=rnd.randint(120, 255))
    t = twinkle().getchannel("A")
    for _ in range(9):
        s = rnd.randint(16, 34)
        im = t.resize((s, s), Image.LANCZOS)
        a.paste(Image.new("L", im.size, 255), (rnd.randint(0, BW - s), rnd.randint(0, BH - s)), im)
    # a faint nebula band
    neb = Image.new("L", (BW, BH), 0)
    nd = ImageDraw.Draw(neb)
    for i in range(14):
        x = i * BW / 13
        y = BH * 0.55 + math.sin(i * 0.9) * 40
        nd.ellipse([x - 60, y - 30, x + 60, y + 30], fill=70)
    neb = neb.filter(ImageFilter.GaussianBlur(24))
    return white(ImageChops.lighter(a, neb))


def bg_rays():
    side = BW * 2
    a = Image.new("L", (side, side), 0)
    d = ImageDraw.Draw(a)
    c = (side / 2, side * 0.95)
    for i in range(22):
        ang = math.pi + math.pi * (i + 0.5) / 22
        half = math.pi / 22 * 0.42
        r = side
        d.polygon([c, (c[0] + r * math.cos(ang - half), c[1] + r * math.sin(ang - half)),
                   (c[0] + r * math.cos(ang + half), c[1] + r * math.sin(ang + half))], fill=200)
    a = a.filter(ImageFilter.GaussianBlur(8)).crop((side / 4, side / 2, side * 3 / 4, side * 0.75)).resize((BW, BH))
    fade = Image.linear_gradient("L").resize((BW, BH))  # brighter toward the bottom (the source)
    return white(ImageChops.multiply(a, fade.point(lambda v: int(60 + 195 * v / 255))))


SPRITES = {
    "FxGlow": glow, "FxRing": ring, "FxRays": rays, "FxTwinkle": twinkle, "FxPetal": petal, "FxFlame": flame,
    "FxTap": tap, "FxShine": shine, "BgClouds": bg_clouds, "BgSakura": bg_sakura, "BgStars": bg_stars,
    "BgRays": bg_rays,
}


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    made = []
    for key, fn in SPRITES.items():
        im = fn()
        im.save(OUT / f"{key}.png")
        made.append((key, im))
    # a contact sheet on a dark ground (the sprites are white)
    cell = 260
    sheet = Image.new("RGB", (cell * 4, cell * 3), (34, 38, 92))
    for i, (key, im) in enumerate(made):
        t = im.copy()
        t.thumbnail((cell - 20, cell - 20))
        sheet.paste(t, ((i % 4) * cell + (cell - t.width) // 2, (i // 4) * cell + (cell - t.height) // 2), t)
    (ROOT / "work" / "ui").mkdir(parents=True, exist_ok=True)
    sheet.save(ROOT / "work" / "ui" / "fx_v42_sheet.png")
    print(f"{len(made)} sprites -> {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
