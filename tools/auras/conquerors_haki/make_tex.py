#!/usr/bin/env python3
"""ConquerorsHaki (Shanks, "Red-Haired Emperor") aura textures, made from maths: nothing harvested.

    python tools/auras/conquerors_haki/make_tex.py      -> assets/auras/conquerors_haki/*.png (+ _sheet.jpg)

No flame tongues (the owner's brief). Shanks's own language is Conqueror's Haki: black lightning edged in
crimson, an Emperor's pressure pushing everything back, stone cracking under it.

  haki_bolt_4x4.png  16 different black-lightning bolts (flipbook, shown a few frames each): a black core,
                     a crimson rim, a red glow, forked branches (pre-coloured; reads on sky and on gold)
  pressure_ring.png  a dark-red shockwave ring with a black inner edge (laid flat, grows and fades)
  crater.png         ground: stone cracked in a radial web, crimson seams glowing in the cracks, a dark
                     pressure stain in the middle (dark-backed: reads on his gold stand)
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets" / "auras" / "conquerors_haki"
F = 256
RNG = np.random.default_rng(2024)

BLACK = (8, 0, 4)
CRIMSON = (225, 22, 44)
RED = (150, 0, 20)
HOT = (255, 150, 160)


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def bolt_path(p0, p1, rough, depth):
    """midpoint displacement: a jagged path from p0 to p1"""
    pts = [np.array(p0, float), np.array(p1, float)]
    for _ in range(depth):
        new = [pts[0]]
        for a, b in zip(pts[:-1], pts[1:]):
            m = (a + b) / 2
            d = b - a
            n = np.array([-d[1], d[0]]) / (np.hypot(*d) + 1e-9)
            m = m + n * RNG.normal(0, rough * np.hypot(*d))
            new += [m, b]
        pts = new
    return pts


def bolt_frame(k=3):
    S = F * k
    paths = []
    # the trunk crosses the frame at a random angle; 2-3 forks leave it
    a = RNG.uniform(0, math.pi)
    r = 0.36 * S
    c = np.array([S / 2, S / 2]) + RNG.normal(0, 0.05 * S, 2)
    p0 = c - r * np.array([math.cos(a), math.sin(a)])
    p1 = c + r * np.array([math.cos(a), math.sin(a)])
    trunk = bolt_path(p0, p1, 0.22, 6)
    paths.append((trunk, 1.0))
    for _ in range(RNG.integers(2, 4)):
        i = RNG.integers(len(trunk) // 5, 4 * len(trunk) // 5)
        start = trunk[i]
        ang = a + RNG.choice([-1, 1]) * RNG.uniform(0.5, 1.1)
        L = RNG.uniform(0.14, 0.26) * S
        end = start + L * np.array([math.cos(ang), math.sin(ang)])
        end = np.clip(end, 0.14 * S, 0.86 * S)
        paths.append((bolt_path(start, end, 0.25, 5), 0.6))
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for pts, w in paths:
        gd.line([tuple(p) for p in pts], fill=RED + (170,), width=int(30 * w * k), joint="curve")
    glow = glow.filter(ImageFilter.GaussianBlur(7 * k))
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    img.alpha_composite(glow)
    d = ImageDraw.Draw(img)
    for pts, w in paths:
        d.line([tuple(p) for p in pts], fill=CRIMSON + (255,), width=int(16 * w * k), joint="curve")
    for pts, w in paths:
        d.line([tuple(p) for p in pts], fill=HOT + (255,), width=max(1, int(11 * w * k)), joint="curve")
    for pts, w in paths:
        d.line([tuple(p) for p in pts], fill=BLACK + (255,), width=max(1, int(7.5 * w * k)), joint="curve")
    img = img.resize((F, F), Image.LANCZOS)
    arr = np.asarray(img, float)
    yy, xx = np.mgrid[0:F, 0:F]
    edge = np.minimum(np.minimum(xx, F - 1 - xx), np.minimum(yy, F - 1 - yy))
    arr[..., 3] *= smooth(0, 14, edge)
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def haki_bolt():
    s = Image.new("RGBA", (F * 4, F * 4), (0, 0, 0, 0))
    for i in range(16):
        s.paste(bolt_frame(), ((i % 4) * F, (i // 4) * F))
    return s


def pressure_ring(N=512):
    yy, xx = np.mgrid[-1:1:N * 1j, -1:1:N * 1j]
    r = np.hypot(xx, yy)
    band = np.exp(-((r - 0.84) / 0.06) ** 2)
    edge = np.exp(-((r - 0.78) / 0.018) ** 2)
    a = np.clip(band * 0.85 + edge, 0, 1)
    col = np.zeros((N, N, 3))
    col[:] = np.array(RED, float)
    col = col * (1 - edge[..., None]) + np.array(BLACK, float) * edge[..., None]
    hi = np.exp(-((r - 0.88) / 0.012) ** 2)[..., None]
    col = col * (1 - hi * 0.6) + np.array(CRIMSON, float) * hi * 0.6
    return Image.fromarray(np.clip(np.dstack([col, a * 255]), 0, 255).astype(np.uint8), "RGBA")


def crater(N=1024, k=2):
    M = N * k
    yy, xx = np.mgrid[-1:1:M * 1j, -1:1:M * 1j]
    r = np.hypot(xx, yy)
    im = Image.new("L", (M, M), 0)
    d = ImageDraw.Draw(im)
    rng = np.random.default_rng(11)

    def crack(x, y, ang, w, depth, length):
        pts = [(x, y)]
        for _ in range(int(length)):
            ang += rng.normal(0, 0.04) + (rng.choice([-1, 1]) * rng.uniform(0.35, 0.7) if rng.random() < 0.16 else 0)
            x, y = x + math.cos(ang) * 0.03, y + math.sin(ang) * 0.03
            if math.hypot(x, y) > 0.9:
                break
            pts.append((x, y))
            if depth < 1 and rng.random() < 0.06:
                crack(x, y, ang + rng.choice([-1, 1]) * rng.uniform(0.5, 1.0), w * 0.6, depth + 1, length * 0.5)
        d.line([((px + 1) * M / 2, (py + 1) * M / 2) for px, py in pts], fill=255, width=max(1, int(w * M)), joint="curve")

    for i in range(11):
        a = i * 2 * math.pi / 11 + rng.uniform(-0.2, 0.2)
        crack(0.12 * math.cos(a), 0.12 * math.sin(a), a, 0.0065, 0, rng.integers(16, 26))
    # two broken rings round the impact
    for rr in (0.3, 0.55):
        for _ in range(7):
            a0 = rng.uniform(0, 2 * math.pi)
            span = rng.uniform(0.3, 0.7)
            pts = [((rr + rng.normal(0, 0.006)) * math.cos(t), (rr + rng.normal(0, 0.006)) * math.sin(t))
                   for t in np.linspace(a0, a0 + span, 12)]
            d.line([((px + 1) * M / 2, (py + 1) * M / 2) for px, py in pts], fill=255, width=int(0.008 * M))
    cracks = np.asarray(im) > 127
    seam = np.clip(ndimage.gaussian_filter(cracks.astype(float), 2.5 * k) * 2.5, 0, 1)
    edge = ndimage.binary_dilation(cracks, iterations=2 * k) & ~cracks
    col = np.zeros((M, M, 3))
    stain = (1 - smooth(0.0, 0.75, r))  # the dark pressure stain in the middle
    col[:] = np.array([30, 10, 14], float)
    col = np.where(edge[..., None], np.array(RED, float) * 0.8, col)
    col = np.where(cracks[..., None], np.array(BLACK, float), col)
    a = np.maximum(stain * 0.7, np.where(cracks | edge, 1.0, 0.0))
    a = np.maximum(a, seam * 0.6)
    col = np.where(((seam > 0.05) & ~cracks & ~edge)[..., None],
                   col * (1 - seam[..., None]) + np.array(RED, float) * seam[..., None], col)
    img = Image.fromarray(np.clip(np.dstack([col, a * 255]), 0, 255).astype(np.uint8), "RGBA")
    return img.resize((N, N), Image.LANCZOS)


def contact(imgs):
    tiles = []
    for name, im in imgs:
        t = im.copy()
        t.thumbnail((512, 512))
        tiles.append((name, t))
    rows = math.ceil(len(tiles) / 2)
    out = Image.new("RGB", (1080, rows * 560), (250, 204, 21))  # his gold stand
    sky = Image.new("RGB", (540, 560), (120, 200, 240))
    for i, (name, t) in enumerate(tiles):
        x, y = (i % 2) * 540, (i // 2) * 560
        if i % 2 == 1:
            out.paste(sky, (x, y))
        out.paste(t, (x + 14, y + 14), t)
        ImageDraw.Draw(out).text((x + 14, y + 534), name, fill=(0, 0, 0))
    return out


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    jobs = [("haki_bolt_4x4", haki_bolt), ("crater", crater), ("pressure_ring", pressure_ring)]
    made = []
    for name, fn in jobs:
        im = fn()
        im.save(OUT / f"{name}.png", optimize=True)
        made.append((name, im))
        print(f"wrote {name}.png {im.size}")
    contact(made).save(OUT / "_sheet.jpg", quality=88)
    print("wrote _sheet.jpg")


if __name__ == "__main__":
    main()
