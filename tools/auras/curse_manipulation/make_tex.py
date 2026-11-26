#!/usr/bin/env python3
"""CurseManipulation (Geto, "Curse Manipulator") aura textures, made from maths: nothing harvested.

    python tools/auras/curse_manipulation/make_tex.py   -> assets/auras/curse_manipulation/*.png (+ _sheet.jpg)

No flame tongues (the owner's brief). Geto's Curse Manipulation: he absorbs cursed spirits and condenses
them into black spheres; Uzumaki compresses them into a spiral.

  orb_4x4.png      16-frame LOOP: a black cursed-spirit sphere, violet rim light, curse energy swirling
                   inside, one yellow eye that looks about and blinks
  spirit_eye.png   cursed spirits drifting in to be absorbed: a lumpy blob with one great eye,
  spirit_grin.png  one with a wide toothy grin and two small red eyes,
  spirit_many.png  and an amorphous one covered in small eyes (all with a violet keyline)
  uzumaki.png      ground: a spiral vortex of compressed curses, dark violet arms with eyes along them,
                   on a dark disc (reads on his gold stand)
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets" / "auras" / "curse_manipulation"
F = 256

INK = np.array([10, 6, 16], float)
DEEP = np.array([46, 14, 70], float)
VIOLET = np.array([150, 80, 220], float)
LILAC = np.array([210, 180, 255], float)
YELLOW = np.array([255, 214, 60], float)
RED = np.array([230, 30, 40], float)
WHITE = np.array([245, 240, 250], float)


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def field(shape, scale, seed):
    rng = np.random.default_rng(seed)
    f = ndimage.gaussian_filter(rng.standard_normal(shape), scale, mode="wrap")
    return f / (np.abs(f).max() + 1e-9)


def to_img(rgba):
    return Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), "RGBA")


def eye(col, a, xx, yy, cx, cy, rx, ry, open_=1.0, look=0.0, iris=YELLOW, slit=True):
    """an almond eye: sclera, iris, pupil (a slit for curses), a dark lid line. In place on col/a."""
    ry = ry * max(open_, 0.02)
    ex = (xx - cx) / rx
    ey = (yy - cy) / max(ry, 1e-4)
    almond = (np.abs(ex) ** 1.5 + np.abs(ey) ** 2) < 1
    lid = ((np.abs(ex) ** 1.5 + np.abs(ey) ** 2) < 1.25) & ~almond
    col[lid] = INK
    a[lid] = 1
    col[almond] = WHITE
    a[almond] = 1
    if open_ > 0.15:
        ir = np.hypot((xx - cx - look * rx * 0.35) / (rx * 0.5), (yy - cy) / (rx * 0.5))
        m = almond & (ir < 1)
        col[m] = iris
        if slit:
            pm = almond & (np.abs(xx - cx - look * rx * 0.35) < rx * 0.08) & (ir < 0.9)
        else:
            pm = almond & (ir < 0.45)
        col[pm] = INK


def orb():
    yy, xx = np.mgrid[-1:1:F * 1j, -1:1:F * 1j]
    r = np.hypot(xx, yy)
    th = np.arctan2(yy, xx)
    R = 0.62
    swirl_base = field((F, F), 6, 3)
    frames = []
    for f in range(16):
        t = f / 16
        col = np.zeros((F, F, 3))
        a = np.zeros((F, F))
        # swirl: a spiral pattern turning with time, dark violet streaks in the black
        sw = np.sin(th * 3 + r * 9 - t * 2 * math.pi) * 0.5 + 0.5
        n = ndimage.shift(swirl_base, (0, f * 2), mode="wrap")
        body = r < R
        shade = smooth(R, R * 0.2, r)  # darker toward the middle
        inner = (sw * 0.6 + 0.4 * (n * 0.5 + 0.5)) * (1 - shade * 0.5)
        col[:] = INK + (DEEP - INK) * np.clip(inner, 0, 1)[..., None]
        a = np.where(body, 1.0, 0.0)
        # rim light (violet, top-left brighter) and a soft outer halo
        rim = smooth(R * 0.8, R, r) * body
        rim_dir = 0.6 + 0.4 * np.clip(-(xx * 0.6 + yy * 0.8) / (r + 1e-6), 0, 1)
        col = col * (1 - (rim * rim_dir)[..., None]) + VIOLET * (rim * rim_dir)[..., None]
        halo = (1 - smooth(R, R + 0.22, r)) * (~body) * 0.5
        col = np.where((~body)[..., None], VIOLET, col)
        a = np.maximum(a, halo)
        # the eye: looks about, blinks at frames 10-11
        open_ = 0.05 if f in (10,) else (0.45 if f in (9, 11) else 1.0)
        look = math.sin(t * 2 * math.pi) * 0.8
        eye(col, a, xx, yy, 0.0, 0.0, 0.3, 0.16, open_=open_, look=look)
        frames.append(to_img(np.dstack([col, a * 255])))
    s = Image.new("RGBA", (F * 4, F * 4), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        s.paste(fr, ((i % 4) * F, (i // 4) * F))
    return s


def blob(xx, yy, seed, scale=1.0):
    th = np.arctan2(yy, xx)
    r = np.hypot(xx, yy)
    rng = np.random.default_rng(seed)
    wob = sum(rng.uniform(0.03, 0.08) * np.sin(k * th + rng.uniform(0, 6.3)) for k in (2, 3, 5, 7))
    return r < (0.62 * scale + wob)


def spirit(kind, N=512):
    yy, xx = np.mgrid[-1:1:N * 1j, -1:1:N * 1j]
    body = blob(xx, yy + 0.05, {"eye": 1, "grin": 2, "many": 3}[kind])
    # little tendrils trailing below (they drift inward, tails dragging)
    for i, x0 in enumerate((-0.3, 0.0, 0.28)):
        tail = (np.abs(xx - x0 - 0.06 * np.sin((yy - 0.5) * 9 + i)) < 0.06 * (1 - (yy - 0.45) / 0.45)) & (yy > 0.45) & (yy < 0.9)
        body |= tail
    col = np.zeros((N, N, 3))
    col[:] = INK
    din = ndimage.distance_transform_edt(body)
    shade = smooth(0, 40, din)[..., None]
    col = DEEP * (1 - shade) + INK * shade
    a = body.astype(float)
    if kind == "eye":
        eye(col, a, xx, yy, 0.0, -0.08, 0.36, 0.22, look=0.2)
    elif kind == "grin":
        for sx in (-0.2, 0.2):
            eye(col, a, xx, yy, sx, -0.25, 0.1, 0.07, iris=RED, slit=False)
        mouth = (np.abs(yy - 0.1 - 0.12 * (xx / 0.42) ** 2) < 0.1) & (np.abs(xx) < 0.42)
        col[mouth] = INK * 0.4
        teeth = mouth & (((xx * 14) % 1.0) < 0.55) & (np.abs(yy - 0.1 - 0.12 * (xx / 0.42) ** 2) > 0.035)
        col[teeth] = WHITE
    else:
        rng = np.random.default_rng(5)
        for _ in range(7):
            cx, cy = rng.uniform(-0.38, 0.38), rng.uniform(-0.38, 0.25)
            s = rng.uniform(0.06, 0.12)
            eye(col, a, xx, yy, cx, cy, s, s * 0.6, look=rng.uniform(-1, 1))
    # violet keyline and a faint halo
    solid = a > 0.5
    key = ndimage.binary_dilation(solid, iterations=5) & ~solid
    col = np.where(key[..., None], VIOLET, col)
    a = np.maximum(a, key * 1.0)
    dout = ndimage.distance_transform_edt(~(solid | key))
    halo = (1 - smooth(0, 22, dout)) * 0.4 * ~(solid | key)
    col = np.where((halo > 0.01)[..., None] & ~(solid | key)[..., None], VIOLET, col)
    a = np.maximum(a, halo)
    return to_img(np.dstack([col, a * 255]))


def uzumaki(N=1024):
    yy, xx = np.mgrid[-1:1:N * 1j, -1:1:N * 1j]
    r = np.hypot(xx, yy) + 1e-6
    th = np.arctan2(yy, xx)
    arms = 4
    phase = th * arms + 3.2 * np.log(r / 0.05) * arms / 2
    band = np.cos(phase) * 0.5 + 0.5
    n = field((N, N), 10, 7) * 0.5 + 0.5
    arm = smooth(0.55, 0.75, band + 0.15 * (n - 0.5))
    fade = smooth(0.95, 0.82, r)
    col = np.zeros((N, N, 3))
    col[:] = INK
    edge = smooth(0.5, 0.62, band) * (1 - smooth(0.75, 0.9, band))
    col = INK * (1 - arm[..., None]) + DEEP * arm[..., None]
    col = col * (1 - edge[..., None] * 0.8) + VIOLET * edge[..., None] * 0.8
    # a nearly opaque dark disc under the arms: half-transparent black over the gold stand went olive
    a = np.clip(0.86 + 0.14 * arm, 0, 1) * fade
    # the vortex's heart: a dark core with a violet ring
    core = smooth(0.2, 0.08, r)
    col = col * (1 - core[..., None]) + INK * core[..., None]
    a = np.maximum(a, core)  # a fully dark heart (a gold dot showed through before)
    # eyes along the arms (curses compressed into it)
    col = col.copy()
    rng = np.random.default_rng(12)
    for i in range(22):
        rr = rng.uniform(0.25, 0.8)
        # place on an arm: solve phase = 0 (mod 2pi)
        k = rng.integers(0, arms)
        t0 = (2 * math.pi * k - 3.2 * math.log(rr / 0.05) * arms / 2) / arms
        cx, cy = rr * math.cos(t0), rr * math.sin(t0)
        s = 0.018 + 0.03 * rr
        eye(col, a, xx, yy, cx, cy, s, s * 0.55, look=rng.uniform(-1, 1))
    return to_img(np.dstack([col, a * 255]))


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
    jobs = [("uzumaki", uzumaki), ("orb_4x4", orb), ("spirit_eye", lambda: spirit("eye")),
            ("spirit_grin", lambda: spirit("grin")), ("spirit_many", lambda: spirit("many"))]
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
