"""Painted anime-style landscape backdrops for the Hero Index zone cards (PIL, no network).

Used by `zone_backdrops.py paint` when no image generator is available (Cloudflare's daily FLUX quota and the
HuggingFace provider credits were both spent on 2026-11-15). Each zone is a layered cel-shaded scene: gradient
sky, sun glow, puffy anime clouds, hazy far ridges, then the zone's own landmark and foreground. Painted at 2x
and downsampled, so every edge is anti-aliased. Deterministic (fixed seed per zone).
"""

from __future__ import annotations

import math
import random

from PIL import Image, ImageDraw, ImageFilter

W, H = 960, 416


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def vgrad(size, stops):
    w, h = size
    img = Image.new("RGB", (1, h))
    px = img.load()
    for y in range(h):
        t = y / max(1, h - 1)
        for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
            if t0 <= t <= t1:
                px[0, y] = mix(rgb(c0), rgb(c1), (t - t0) / max(1e-6, t1 - t0))
                break
    return img.resize((w, h))


def layer():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def paste(base, lay, blur=0):
    if blur:
        lay = lay.filter(ImageFilter.GaussianBlur(blur))
    base.alpha_composite(lay)


def glow(base, cx, cy, r, colour, strength=200):
    lay = layer()
    d = ImageDraw.Draw(lay)
    for i in range(24, 0, -1):
        rr = r * i / 24
        a = int(strength * (1 - i / 24) ** 1.6)
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=rgb(colour) + (a,))
    paste(base, lay, blur=6)


def cloud(d, cx, cy, s, top="#FFFFFF", under="#D9E6FF"):
    """An anime cumulus: a flat-bottomed heap of circles, lit top, cooler underside."""
    rnd = random.Random(int(cx * 7 + cy * 13))
    puffs = [(cx + rnd.uniform(-1.6, 1.6) * s, cy - rnd.uniform(0, 0.9) * s, rnd.uniform(0.55, 1.0) * s)
             for _ in range(9)]
    for x, y, r in puffs:
        d.ellipse([x - r, y - r + 6, x + r, y + r + 6], fill=rgb(under) + (255,))
    for x, y, r in puffs:
        d.ellipse([x - r * 0.92, y - r, x + r * 0.92, y + r * 0.8], fill=rgb(top) + (255,))
    d.rectangle([cx - 2.6 * s, cy + 0.55 * s, cx + 2.6 * s, cy + 3 * s], fill=(0, 0, 0, 0))


def clouds(base, specs, top="#FFFFFF", under="#D9E6FF"):
    lay = layer()
    d = ImageDraw.Draw(lay)
    for cx, cy, s in specs:
        cloud(d, cx, cy, s, top, under)
    paste(base, lay, blur=1.2)


def ridge(base, y0, amp, colour, seed, step=40, blur=0, jag=1.0):
    rnd = random.Random(seed)
    pts = [(0, H)]
    x = -step
    while x <= W + step:
        y = y0 - amp * (0.5 + 0.5 * math.sin(x / (170 + seed % 50) + seed)) - rnd.uniform(0, amp * 0.35 * jag)
        pts.append((x, y))
        x += step
    pts.append((W, H))
    lay = layer()
    ImageDraw.Draw(lay).polygon(pts, fill=rgb(colour) + (255,))
    paste(base, lay, blur)


def blob_tree(d, x, y, r, canopy, shade, trunk="#6B3E26", rnd=None):
    rnd = rnd or random.Random(int(x * 3 + y))
    d.polygon([(x - r * 0.12, y + r * 1.9), (x + r * 0.12, y + r * 1.9), (x + r * 0.06, y), (x - r * 0.06, y)],
              fill=rgb(trunk) + (255,))
    for _ in range(9):
        a = rnd.uniform(0, math.tau)
        rr = r * rnd.uniform(0.45, 0.7)
        px, py = x + math.cos(a) * r * 0.55, y + math.sin(a) * r * 0.4
        d.ellipse([px - rr, py - rr + 4, px + rr, py + rr + 4], fill=rgb(shade) + (255,))
    for _ in range(9):
        a = rnd.uniform(0, math.tau)
        rr = r * rnd.uniform(0.4, 0.62)
        px, py = x + math.cos(a) * r * 0.5, y - r * 0.08 + math.sin(a) * r * 0.35
        d.ellipse([px - rr, py - rr, px + rr, py + rr], fill=rgb(canopy) + (255,))


def roof(d, x, y, w, h, colour, curl=0.18):
    """A Japanese roof: a wide trapezoid with upturned eaves."""
    c = rgb(colour) + (255,)
    d.polygon([(x - w * (0.5 + curl), y + h), (x - w * 0.5, y + h * 0.75), (x - w * 0.28, y), (x + w * 0.28, y),
               (x + w * 0.5, y + h * 0.75), (x + w * (0.5 + curl), y + h)], fill=c)


def sky(stops):
    return vgrad((W, H), stops).convert("RGBA")


# ------------------------------------------------------------------ zones

def sakura_schoolyard():
    img = sky([(0, "#6FC3FF"), (0.55, "#BFE6FF"), (1, "#FFE9F3")])
    glow(img, 820, 70, 160, "#FFFFFF", 170)
    clouds(img, [(160, 90, 34), (430, 60, 26), (700, 120, 30)])
    ridge(img, 250, 40, "#A8C8F0", 3, blur=2)
    lay = layer()
    d = ImageDraw.Draw(lay)
    # the school: a long white block, a tower with a clock
    d.rectangle([250, 170, 760, 300], fill=rgb("#F7F3EA") + (255,))
    d.rectangle([250, 160, 760, 176], fill=rgb("#C9B8A6") + (255,))
    d.rectangle([460, 110, 550, 300], fill=rgb("#FFFFFF") + (255,))
    d.polygon([(450, 112), (505, 80), (560, 112)], fill=rgb("#D9534F") + (255,))
    d.ellipse([482, 124, 528, 170], fill=rgb("#F4C542") + (255,))
    d.ellipse([489, 131, 521, 163], fill=rgb("#FFFFFF") + (255,))
    d.line([505, 147, 505, 135], fill=(40, 40, 60, 255), width=3)
    d.line([505, 147, 514, 151], fill=(40, 40, 60, 255), width=3)
    for row in range(3):
        for col in range(14):
            x = 266 + col * 35
            if 452 < x < 552:
                continue
            d.rectangle([x, 190 + row * 34, x + 22, 210 + row * 34], fill=rgb("#7EC8F2") + (255,))
    paste(img, lay)
    ridge(img, 330, 10, "#7FD36B", 8, step=60)
    lay = layer()
    d = ImageDraw.Draw(lay)
    rnd = random.Random(1)
    for x, y, r in [(90, 200, 90), (190, 250, 70), (860, 210, 95), (770, 270, 60), (40, 290, 60), (930, 300, 60)]:
        blob_tree(d, x, y, r, "#FFB7D5", "#F48FB8", rnd=rnd)
    paste(img, lay)
    ridge(img, 395, 6, "#5BBE55", 11, step=80)
    lay = layer()
    d = ImageDraw.Draw(lay)
    for _ in range(120):
        x, y, s = rnd.uniform(0, W), rnd.uniform(0, H), rnd.uniform(3, 7)
        d.ellipse([x, y, x + s * 1.6, y + s], fill=rgb(rnd.choice(["#FFC4DD", "#FFE0EE", "#FF9EC7"])) + (230,))
    paste(img, lay, blur=0.6)
    return img


def pirate_harbor():
    img = sky([(0, "#2FA8FF"), (0.5, "#9FDBFF"), (0.62, "#E6F7FF"), (1, "#E6F7FF")])
    glow(img, 140, 60, 170, "#FFFFFF", 180)
    clouds(img, [(300, 80, 32), (620, 50, 24), (860, 100, 30)])
    ridge(img, 238, 50, "#7FB7A0", 5, blur=2)
    lay = layer()
    d = ImageDraw.Draw(lay)
    d.rectangle([0, 236, W, H], fill=rgb("#1FB5C9") + (255,))
    for y in range(240, H, 6):
        t = (y - 240) / (H - 240)
        d.rectangle([0, y, W, y + 6], fill=mix(rgb("#4FD8E6"), rgb("#0E7FA8"), t) + (255,))
    rnd = random.Random(2)
    for _ in range(90):
        x, y = rnd.uniform(0, W), rnd.uniform(244, H)
        d.line([x, y, x + rnd.uniform(10, 40), y], fill=(255, 255, 255, 170), width=2)
    paste(img, lay)
    lay = layer()
    d = ImageDraw.Draw(lay)
    # the ship
    d.polygon([(420, 250), (700, 250), (670, 300), (450, 300)], fill=rgb("#7A4524") + (255,))
    d.polygon([(420, 250), (700, 250), (695, 262), (425, 262)], fill=rgb("#B5703A") + (255,))
    for mx, top in ((500, 70), (580, 50), (650, 100)):
        d.rectangle([mx - 4, top, mx + 4, 252], fill=rgb("#5A3418") + (255,))
        for k, (sy, sw) in enumerate(((top + 20, 46), (top + 80, 56))):
            d.polygon([(mx - sw, sy), (mx + sw, sy), (mx + sw - 6, sy + 52), (mx - sw + 6, sy + 52)],
                      fill=rgb("#FFF8EA") + (255,))
            d.line([mx - sw + 6, sy + 52, mx + sw - 6, sy + 52], fill=rgb("#E3D3B5") + (255,), width=4)
        d.polygon([(mx + 4, top), (mx + 40, top + 8), (mx + 4, top + 18)], fill=rgb("#20202A") + (255,))
    paste(img, lay)
    lay = layer()
    d = ImageDraw.Draw(lay)
    # dock planks and posts, a palm tree
    d.polygon([(0, 330), (380, 312), (380, 336), (0, 360)], fill=rgb("#A36A3C") + (255,))
    for x in range(0, 380, 26):
        y = 330 - x * 18 / 380
        d.line([x, y, x, y + 28], fill=rgb("#7A4A26") + (255,), width=3)
    for x in (40, 160, 290):
        d.rectangle([x, 330 - x * 18 / 380, x + 12, H], fill=rgb("#6A3E1E") + (255,))
    d.line([860, H, 840, 200], fill=rgb("#8A5A2E") + (255,), width=14)
    for a in range(0, 360, 45):
        ang = math.radians(a)
        d.polygon([(840, 200), (840 + math.cos(ang) * 110, 200 + math.sin(ang) * 50 + 30),
                   (840 + math.cos(ang + 0.25) * 90, 200 + math.sin(ang + 0.25) * 40 + 20)],
                  fill=rgb("#2FA84F") + (255,))
    paste(img, lay)
    return img


def ninja_village():
    img = sky([(0, "#58B7FF"), (0.6, "#CDEBFF"), (1, "#E9F7E0")])
    glow(img, 760, 80, 150, "#FFF6D6", 160)
    clouds(img, [(200, 70, 28), (520, 100, 22), (820, 60, 26)])
    ridge(img, 190, 70, "#9CC3B8", 6, blur=2, step=50, jag=1.6)
    ridge(img, 245, 60, "#5E9E7A", 9, step=40, jag=1.4)
    lay = layer()
    d = ImageDraw.Draw(lay)
    rnd = random.Random(3)
    houses = [(160, 270, 120), (330, 250, 140), (520, 268, 120), (690, 245, 150), (860, 275, 110)]
    for x, y, w in houses:
        d.rectangle([x - w * 0.42, y, x + w * 0.42, y + 70], fill=rgb("#F2E3C2") + (255,))
        d.rectangle([x - w * 0.42, y + 34, x + w * 0.42, y + 40], fill=rgb("#8B5A3C") + (255,))
        d.rectangle([x - 12, y + 40, x + 12, y + 70], fill=rgb("#6B3E26") + (255,))
        roof(d, x, y - 40, w, 44, "#3D3F63")
        roof(d, x, y - 40, w * 0.92, 10, "#5A5D8A", curl=0.05)
    paste(img, lay)
    lay = layer()
    d = ImageDraw.Draw(lay)
    for x, y, r in [(40, 300, 70), (250, 330, 50), (610, 330, 55), (930, 300, 70)]:
        blob_tree(d, x, y, r, "#3FAE5A", "#2C8A47", rnd=rnd)
    paste(img, lay)
    ridge(img, 395, 8, "#4C9A4E", 13, step=70)
    lay = layer()
    d = ImageDraw.Draw(lay)
    for x, y in [(110, 360), (420, 350), (760, 355)]:
        d.line([x, y - 30, x, y + 40], fill=(60, 40, 30, 255), width=4)
        d.ellipse([x - 16, y - 20, x + 16, y + 16], fill=rgb("#FF5A3C") + (255,))
        d.ellipse([x - 8, y - 12, x + 8, y + 8], fill=rgb("#FFC14D") + (255,))
    paste(img, lay)
    glow(img, 110, 358, 40, "#FFB04D", 120)
    glow(img, 420, 348, 40, "#FFB04D", 120)
    glow(img, 760, 353, 40, "#FFB04D", 120)
    return img


def samurai_castle():
    img = sky([(0, "#FF8A5B"), (0.45, "#FFC46B"), (0.75, "#FFE6A8"), (1, "#FFE6A8")])
    glow(img, 230, 170, 200, "#FFF4C2", 220)
    clouds(img, [(600, 70, 30), (860, 110, 26), (130, 60, 22)], top="#FFE9D0", under="#F4A88A")
    ridge(img, 210, 90, "#B07AA6", 4, blur=2, step=60, jag=1.5)
    ridge(img, 270, 40, "#8E5E8F", 7, step=50)
    lay = layer()
    d = ImageDraw.Draw(lay)
    cx = 560
    d.polygon([(cx - 170, 330), (cx + 170, 330), (cx + 130, 250), (cx - 130, 250)], fill=rgb("#8A8578") + (255,))
    for k in range(5):
        d.line([cx - 160 + k * 6, 330 - k * 16, cx + 160 - k * 6, 330 - k * 16], fill=(110, 105, 96, 255), width=2)
    tiers = [(250, 230, 52), (198, 180, 46), (152, 130, 42), (110, 86, 38)]
    for y, w, h in tiers:
        d.rectangle([cx - w * 0.42, y - h, cx + w * 0.42, y], fill=rgb("#FBF7EE") + (255,))
        for wx in range(int(cx - w * 0.36), int(cx + w * 0.36), 22):
            d.rectangle([wx, y - h + 14, wx + 9, y - h + 26], fill=rgb("#3A2E3A") + (255,))
        roof(d, cx, y - h - 16, w * 1.05, 22, "#3C3A5C", curl=0.22)
    d.polygon([(cx - 14, 48), (cx, 30), (cx + 14, 48)], fill=rgb("#E8B83A") + (255,))
    paste(img, lay)
    lay = layer()
    d = ImageDraw.Draw(lay)
    rnd = random.Random(4)
    for x, y, r in [(60, 280, 80), (180, 320, 60), (860, 270, 85), (950, 330, 60), (300, 350, 50)]:
        blob_tree(d, x, y, r, "#FF5A3C", "#D63A2A", trunk="#5A2E22", rnd=rnd)
    paste(img, lay)
    ridge(img, 400, 6, "#6E8E3E", 15, step=80)
    return img


def hero_city():
    img = sky([(0, "#2E8BFF"), (0.6, "#9FD3FF"), (1, "#DDF1FF")])
    glow(img, 860, 60, 170, "#FFFFFF", 190)
    clouds(img, [(150, 70, 30), (420, 110, 24), (680, 60, 26)])
    rnd = random.Random(5)
    for depth, (base, col_a, col_b, hmin, hmax) in enumerate(
            [(300, "#9DC4EA", "#B8D8F4", 120, 220), (340, "#4F8FD6", "#7FB6EE", 150, 280)]):
        lay = layer()
        d = ImageDraw.Draw(lay)
        x = -20
        while x < W:
            w = rnd.uniform(50, 90)
            h = rnd.uniform(hmin, hmax)
            if depth == 1 and 430 < x < 560:
                x += w + 6
                continue
            d.rectangle([x, base - h, x + w, H], fill=rgb(col_a) + (255,))
            d.rectangle([x + w * 0.62, base - h, x + w, H], fill=rgb(col_b) + (255,))
            if depth == 1:
                for wy in range(int(base - h + 12), H, 18):
                    for wx in range(int(x + 8), int(x + w - 8), 14):
                        d.rectangle([wx, wy, wx + 6, wy + 9], fill=(225, 245, 255, 200))
            x += w + 6
        paste(img, lay, blur=1.5 if depth == 0 else 0)
    lay = layer()
    d = ImageDraw.Draw(lay)
    # the hero tower: a tall spire with a gold star emblem
    d.polygon([(470, H), (470, 120), (500, 70), (530, 120), (530, H)], fill=rgb("#F2F6FF") + (255,))
    d.polygon([(500, 70), (530, 120), (530, H), (505, H)], fill=rgb("#C9D7F2") + (255,))
    d.line([500, 70, 500, 20], fill=(230, 235, 250, 255), width=4)
    cx, cy, r = 500, 160, 30
    pts = [(cx + math.cos(math.radians(-90 + i * 36)) * (r if i % 2 == 0 else r * 0.45),
            cy + math.sin(math.radians(-90 + i * 36)) * (r if i % 2 == 0 else r * 0.45)) for i in range(10)]
    d.ellipse([cx - 40, cy - 40, cx + 40, cy + 40], fill=rgb("#E8443A") + (255,))
    d.polygon(pts, fill=rgb("#FFD23F") + (255,))
    paste(img, lay)
    glow(img, 500, 160, 80, "#FFE27A", 120)
    lay = layer()
    d = ImageDraw.Draw(lay)
    for x0 in (300, 700):
        d.polygon([(x0, H), (x0 + 20, H), (x0 + 160, 0), (x0 + 100, 0)], fill=(255, 255, 255, 40))
    paste(img, lay, blur=4)
    return img


def realm_of_legends():
    img = sky([(0, "#2A1A6E"), (0.45, "#7B3FD6"), (0.8, "#FF8FD0"), (1, "#FFD3E8")])
    lay = layer()
    d = ImageDraw.Draw(lay)
    for k, col in enumerate(["#4DFFD2", "#7BE8FF", "#C38BFF"]):
        pts = [(x, 90 + k * 26 + 30 * math.sin(x / 120 + k)) for x in range(0, W + 20, 20)]
        for i in range(len(pts) - 1):
            (x0, y0), (x1, y1) = pts[i], pts[i + 1]
            d.polygon([(x0, y0), (x1, y1), (x1, y1 + 60), (x0, y0 + 60)], fill=rgb(col) + (70,))
    paste(img, lay, blur=10)
    rnd = random.Random(6)
    lay = layer()
    d = ImageDraw.Draw(lay)
    for _ in range(70):
        x, y, s = rnd.uniform(0, W), rnd.uniform(0, 200), rnd.uniform(1, 3)
        d.ellipse([x - s, y - s, x + s, y + s], fill=(255, 255, 255, 220))
    paste(img, lay)
    glow(img, 480, 150, 140, "#FFE9A8", 160)

    def island(cx, cy, w, h, grass="#5FD38A"):
        lay_ = layer()
        dd = ImageDraw.Draw(lay_)
        dd.polygon([(cx - w / 2, cy), (cx + w / 2, cy), (cx + w * 0.1, cy + h), (cx - w * 0.15, cy + h * 0.8)],
                   fill=rgb("#7A5A8E") + (255,))
        dd.polygon([(cx, cy), (cx + w / 2, cy), (cx + w * 0.1, cy + h)], fill=rgb("#5E4474") + (255,))
        dd.ellipse([cx - w / 2 - 4, cy - 14, cx + w / 2 + 4, cy + 12], fill=rgb(grass) + (255,))
        dd.rectangle([cx + w * 0.18, cy + 4, cx + w * 0.24, cy + h + 120], fill=(235, 248, 255, 200))
        paste(img, lay_)

    island(160, 230, 220, 120)
    island(820, 200, 240, 130)
    island(480, 290, 360, 140)
    lay = layer()
    d = ImageDraw.Draw(lay)
    # the golden temple on the middle island
    for x in range(380, 600, 34):
        d.rectangle([x, 200, x + 14, 284], fill=rgb("#F2C14E") + (255,))
    d.polygon([(360, 200), (480, 150), (600, 200)], fill=rgb("#FFD86B") + (255,))
    d.rectangle([360, 196, 600, 206], fill=rgb("#E0A93A") + (255,))
    for cx, cy, s in [(130, 214, 26), (210, 200, 36), (790, 182, 40), (870, 192, 28), (650, 270, 30)]:
        d.polygon([(cx, cy - s * 1.6), (cx + s * 0.45, cy), (cx, cy + s * 0.2), (cx - s * 0.45, cy)],
                  fill=rgb("#C77DFF") + (255,))
        d.polygon([(cx, cy - s * 1.6), (cx + s * 0.45, cy), (cx, cy + s * 0.2)], fill=rgb("#8E4FE0") + (255,))
    paste(img, lay)
    for cx, cy in [(210, 170), (790, 140), (650, 240)]:
        glow(img, cx, cy, 60, "#E7B8FF", 140)
    clouds(img, [(80, 380, 40), (330, 395, 46), (620, 390, 44), (900, 380, 40)], top="#FFE8F6", under="#E3B6E8")
    return img


PAINTERS = {
    "sakura_schoolyard": sakura_schoolyard, "pirate_harbor": pirate_harbor, "ninja_village": ninja_village,
    "samurai_castle": samurai_castle, "hero_city": hero_city, "realm_of_legends": realm_of_legends,
}


def paint(zone: str) -> Image.Image:
    """The zone's scene as a square-ish 1024 wide RGB image (same shape the strip() crop expects)."""
    img = PAINTERS[zone]().convert("RGB")
    # cel look: a light posterise-free sharpen, then pad to the generator's square so strip() crops the middle
    img = img.filter(ImageFilter.UnsharpMask(radius=2, percent=60, threshold=2))
    out = Image.new("RGB", (W, W), img.getpixel((W // 2, 2)))
    out.paste(img, (0, (W - H) // 2))
    return out
