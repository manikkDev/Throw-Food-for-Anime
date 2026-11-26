#!/usr/bin/env python3
"""DemonKing (Muzan Kibutsuji, "Demon Progenitor") aura textures, made from maths: nothing harvested.

    python tools/auras/demon_king/make_tex.py      -> assets/auras/demon_king/*.png (+ _sheet.jpg)

The owner's brief: no flame tongues (Itachi's and Jinwoo's auras both use them). Muzan's own language:
his flesh whips (biokinesis), the blue spider lily he hunts, blood and a demon's heartbeat.

  blood_pool.png   ground: a dark glossy blood pool, satellite drops, crimson veins branching out over the
                   stand (dark-outlined: his stand is rose pink, crimson alone does not read on it)
  pulse_ring.png   the heartbeat: a crimson ring with a soft inner fade (laid flat, grows and fades)
  whip.png         beam strip (saved UPRIGHT: Roblox runs a beam texture's vertical axis along the beam):
                   a flesh whip, glowing veins, hooked thorns
  lily_4x4.png     16-frame ONE-SHOT blue spider lily: the head opens (curled petals, long arcing stamens),
                   holds, then wilts and fades
  droplet.png      a glossy blood drop with a highlight (rises off the pool)
  mist_4x4.png     16-frame ONE-SHOT soft blood mist puff (pre-coloured, non-additive)
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets" / "auras" / "demon_king"
F = 256

BLACKRED = np.array([22, 0, 4], float)
BLOOD = np.array([96, 2, 14], float)
CRIMSON = np.array([214, 16, 40], float)
HOT = np.array([255, 92, 110], float)


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def field(shape, scale, seed):
    rng = np.random.default_rng(seed)
    f = ndimage.gaussian_filter(rng.standard_normal(shape), scale, mode="wrap")
    return f / (np.abs(f).max() + 1e-9)


def fbm(shape, scales, weights, seed):
    out = np.zeros(shape)
    for i, (s, w) in enumerate(zip(scales, weights)):
        out += w * field(shape, s, seed + i)
    return out / sum(weights)


def to_img(rgba):
    return Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), "RGBA")


def sheet(frames):
    s = Image.new("RGBA", (F * 4, F * 4), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        s.paste(fr, ((i % 4) * F, (i // 4) * F))
    return s


def polar(N):
    yy, xx = np.mgrid[-1:1:N * 1j, -1:1:N * 1j]
    return np.hypot(xx, yy), np.arctan2(yy, xx), xx, yy


# ------------------------------------------------------------------ the blood pool + veins
def blood_pool(N=1024):
    k = 2
    M = N * k
    r, th, xx, yy = polar(M)
    n = fbm((M, M), [40, 16, 6], [1.0, 0.5, 0.25], 301)
    pool = (0.42 + 0.06 * n - r) > 0
    rng = np.random.default_rng(5)
    # satellite drops and splatter round the rim
    for _ in range(26):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0.44, 0.62)
        rr = rng.uniform(0.01, 0.04) * (1.2 - (d - 0.44) * 2)
        cx, cy = d * math.cos(a), d * math.sin(a)
        pool |= np.hypot(xx - cx, yy - cy) < rr
    # veins: branching random walks from the rim outward, thinner as they go
    vim = Image.new("L", (M, M), 0)
    vd = ImageDraw.Draw(vim)

    def grow(x, y, ang, w, depth):
        for _ in range(int(14 + rng.integers(0, 10))):
            step = 0.022
            ang += rng.normal(0, 0.16)
            nx, ny = x + math.cos(ang) * step, y + math.sin(ang) * step
            if math.hypot(nx, ny) > 0.97:
                return
            vd.line([((x + 1) * M / 2, (y + 1) * M / 2), ((nx + 1) * M / 2, (ny + 1) * M / 2)],
                    fill=255, width=max(1, int(w * M)))
            x, y = nx, ny
            w *= 0.95
            if depth < 2 and rng.random() < 0.11:
                grow(x, y, ang + rng.choice([-1, 1]) * rng.uniform(0.4, 0.9), w * 0.75, depth + 1)

    # few, bold veins (v1's 13 with deep branching made a tangled net)
    for i in range(8):
        a = i * 2 * math.pi / 8 + rng.uniform(-0.2, 0.2)
        grow(0.38 * math.cos(a), 0.38 * math.sin(a), a, 0.017, 0)
    vein = np.asarray(vim) > 127
    vein &= ~pool
    # colour: the pool is near-black red, lighter toward the rim, with glossy highlight arcs
    col = np.zeros((M, M, 3))
    depth = smooth(0.0, 0.42, r)[..., None]
    col[:] = BLACKRED * (1 - depth) + BLOOD * depth
    gloss = np.zeros_like(r)
    for (cx, cy, rr, w) in [(-0.08, -0.1, 0.24, 0.012), (-0.12, -0.14, 0.17, 0.008), (0.1, 0.12, 0.3, 0.006)]:
        ring = np.exp(-((np.hypot(xx - cx, yy - cy) - rr) / w) ** 2)
        arc = np.clip(np.cos(np.arctan2(yy - cy, xx - cx) + 2.3), 0, 1) ** 3
        gloss = np.maximum(gloss, ring * arc)
    col = col * (1 - gloss[..., None] * 0.7) + HOT * gloss[..., None] * 0.7
    # rim of the pool: a thin crimson edge where the blood thins out
    din = ndimage.distance_transform_edt(pool)
    rim = (1 - smooth(1.5 * k, 6 * k, din))[..., None]
    col = np.where(pool[..., None], col * (1 - rim * 0.8) + CRIMSON * rim * 0.8, col)
    # veins: crimson core, a dark outline to read on a pale or pink floor
    vglow = np.clip(ndimage.gaussian_filter(vein.astype(float), 1.5 * k) * 2.5, 0, 1)
    outline = ndimage.binary_dilation(vein, iterations=2 * k) & ~vein & ~pool
    col = np.where(outline[..., None], BLACKRED, col)
    col = np.where(vein[..., None], CRIMSON, col)
    a = np.where(pool, 1.0, 0.0)
    a = np.maximum(a, np.where(vein, 1.0, 0.0))
    a = np.maximum(a, np.where(outline, 0.85, 0.0))
    a = np.maximum(a, vglow * 0.25 * ~pool)
    # a faint dark stain under everything: the blood has soaked the floor
    stain = (1 - smooth(0.36, 0.7, r + 0.05 * n)) * 0.45
    a = np.maximum(a, stain)
    col = np.where(((a <= stain + 1e-6) & ~pool & ~vein & ~outline)[..., None], BLACKRED, col)
    return to_img(np.dstack([col, a * 255])).resize((N, N), Image.LANCZOS)


def pulse_ring(N=512):
    r, _, _, _ = polar(N)
    ring = np.exp(-((r - 0.86) / 0.035) ** 2)
    inner = smooth(0.55, 0.86, r) ** 2 * (r < 0.86) * 0.15
    dark = np.exp(-((r - 0.80) / 0.03) ** 2) * 0.8
    a = np.clip(ring + inner + dark * 0.6, 0, 1)
    col = np.zeros((N, N, 3))
    col[:] = CRIMSON
    col = col * (1 - dark[..., None]) + BLACKRED * dark[..., None]
    col = col * (1 - ring[..., None] * 0.4) + HOT * ring[..., None] * 0.4
    return to_img(np.dstack([col, a * 255]))


# ------------------------------------------------------------------ the whip (beam strip, tiles in U)
def whip(W=512, H=128, k=3):
    """Beam strip, tiles along U. A dark flesh whip: a clean organic tube (bulges), a crimson rim light
    along one edge, two thin glowing veins snaking along it, and only THREE hooked thorns per repeat at
    irregular spacing on alternating sides. (v2 had an even sawtooth of thorns on both edges and banded
    fibres: in Studio the whips read as feathered bird wings.)"""
    S, T = W * k, H * k
    im = Image.new("L", (S, T), 0)
    d = ImageDraw.Draw(im)
    mid = T / 2
    body = 0.30 * T
    xs = np.arange(S + 1)
    bulge = body * (1 + 0.13 * np.sin(2 * np.pi * xs / (S / 2)) + 0.05 * np.sin(2 * np.pi * xs / (S / 7)))
    d.polygon([(x, mid - b) for x, b in zip(xs[::4], bulge[::4])] +
              [(x, mid + b) for x, b in zip(xs[::-4], bulge[::-4])], fill=255)
    thorn_mask = Image.new("L", (S, T), 0)
    td = ImageDraw.Draw(thorn_mask)
    for fx, side, L in ((0.12, -1, 0.17), (0.46, 1, 0.15), (0.79, -1, 0.13)):
        x0 = fx * S
        b = body * (1 + 0.13 * math.sin(2 * math.pi * x0 / (S / 2)))
        base = 0.045 * S
        pts = []
        # a hooked thorn: wide base on the tube, curving back (toward U=0, the root) to a point
        for s in np.linspace(0, 1, 12):
            pts.append((x0 + base * (1 - s) - base * 1.3 * s * s, mid + side * (b * 0.85 + L * T * s)))
        for s in np.linspace(1, 0, 12):
            pts.append((x0 - base * 0.6 * (1 - s) - base * 1.3 * s * s - base * 0.25 * s, mid + side * (b * 0.85 + L * T * s * 0.82)))
        td.polygon(pts, fill=255)
        d.polygon(pts, fill=255)
    m = np.asarray(im, float).reshape(T // k, k, S // k, k).mean(axis=(1, 3)) / 255.0
    th = np.asarray(thorn_mask, float).reshape(T // k, k, S // k, k).mean(axis=(1, 3)) / 255.0 > 0.5
    yy, xx = np.mgrid[0:H, 0:W]
    v = (yy - H / 2) / (H / 2)
    roundness = np.clip(1 - np.abs(v / 0.62) ** 2, 0, 1)
    fib = 0.5 + 0.5 * np.sin(2 * math.pi * (xx / W * 5) + 6 * v)
    col = np.zeros((H, W, 3))
    lum = np.clip(0.35 + 0.45 * roundness + 0.06 * fib, 0, 1.1)[..., None]
    col[:] = BLACKRED + (BLOOD - BLACKRED) * lum
    # a crimson rim light along the upper edge (light from above), sharp
    rimv = np.exp(-((v + 0.5) / 0.07) ** 2)[..., None]
    col = col * (1 - rimv * 0.75) + CRIMSON * rimv * 0.75
    # two thin glowing veins snaking along the length (periodic in U: the strip still tiles)
    for ph, amp, off in ((0.0, 0.16, -0.05), (2.1, 0.12, 0.18)):
        vy = off + amp * np.sin(2 * math.pi * xx / W * 2 + ph)
        vein = np.exp(-((v - vy) / 0.035) ** 2)[..., None]
        col = col * (1 - vein * 0.8) + HOT * 0.85 * vein * 0.8
    solid = m > 0.5
    din = ndimage.distance_transform_edt(solid)
    edge = (1 - smooth(1.0, 2.6, din))[..., None]
    col = col * (1 - edge) + BLACKRED * 0.6 * edge
    col = np.where(th[..., None], BLACKRED * 1.4, col)
    a = np.clip(m, 0, 1)
    # Roblox lays a Beam texture's VERTICAL axis along the beam (measured in play, 2026-11-25: a horizontal
    # strip drew its links across the beam as parallel streaks), so the strip is saved upright.
    return to_img(np.dstack([col, a * 255])).rotate(90, expand=True)


# ------------------------------------------------------------------ the blue spider lily
LILY_DEEP = np.array([25, 60, 190], float)
LILY = np.array([70, 150, 255], float)
LILY_HI = np.array([175, 230, 255], float)
STEM = np.array([20, 70, 80], float)


def lily_frame(open_t, wilt_t, k=3):
    """open_t 0..1 (bud -> full), wilt_t 0..1 (fresh -> drooped). Returns (colour mask layers)."""
    S = F * k
    u = S / 256.0
    pet = Image.new("L", (S, S), 0)
    stam = Image.new("L", (S, S), 0)
    stem = Image.new("L", (S, S), 0)
    dp, ds, dt = ImageDraw.Draw(pet), ImageDraw.Draw(stam), ImageDraw.Draw(stem)
    hx, hy = 128 * u, (118 + 14 * wilt_t) * u  # head centre
    dt.line([(128 * u, 252 * u), (126 * u, 200 * u), (hx, hy + 6 * u)], fill=255, width=int(5 * u))
    dt.line([(127 * u, 232 * u), (112 * u, 218 * u)], fill=255, width=int(3.5 * u))  # a little bract
    u = u * 1.7  # the flower head is drawn 1.7x (v1's head was a speck on a long stem)
    rng = np.random.default_rng(42)
    florets = 7
    for i in range(florets):
        # florets fan upward and out, seen from the side: angles from -165 to -15 degrees
        base = math.radians(-165 + 150 * i / (florets - 1)) + rng.normal(0, 0.06)
        droop = wilt_t * 0.9 * math.copysign(1, math.cos(base))
        ang = base + droop * 0.6
        # six narrow petals per floret, strongly recurved: drawn as short curling ribbons
        for p in range(3):
            pa = ang + (p - 1) * 0.35
            L = (19 + 7 * (p % 2)) * open_t * u
            pts = []
            for s in np.linspace(0, 1, 10):
                curl = s * s * 2.2  # curling back
                a2 = pa + curl * math.copysign(1, (p - 1) or 1)
                pts.append((hx + math.cos(pa) * L * s * 1.2 + math.cos(a2) * L * 0.25 * s,
                            hy + math.sin(pa) * L * s * 1.2 + math.sin(a2) * L * 0.25 * s + wilt_t * 10 * s * u))
            dp.line(pts, fill=255, width=max(1, int((4.6 - 1.8 * wilt_t) * u)), joint="curve")
        # long stamens arcing out and up past the petals, a dot of pollen at the tip
        for sidx in range(3):
            sa = ang + (sidx - 1) * 0.18
            L = (40 + 8 * sidx) * open_t * (1 - 0.35 * wilt_t) * u
            pts = []
            for s in np.linspace(0, 1, 16):
                lift = -s * s * 0.9 * (1 - wilt_t) + s * s * 0.6 * wilt_t  # arcs upward, sags when wilting
                pts.append((hx + math.cos(sa) * L * s, hy + math.sin(sa) * L * s + lift * L * 0.5))
            ds.line(pts, fill=255, width=max(1, int(1.2 * u)), joint="curve")
            ex, ey = pts[-1]
            ds.ellipse([ex - 1.6 * u, ey - 1.6 * u, ex + 1.6 * u, ey + 1.6 * u], fill=255)

    def down(im):
        return np.asarray(im, float).reshape(F, k, F, k).mean(axis=(1, 3)) / 255.0

    return down(pet), down(stam), down(stem)


def lily():
    frames = []
    for f in range(16):
        t = f / 15
        open_t = smooth(0.0, 0.38, t) * 0.92 + 0.08
        wilt_t = smooth(0.66, 1.0, t)
        fade = 1 - smooth(0.78, 1.0, t)
        pet, stam, stem = lily_frame(open_t, wilt_t)
        col = np.zeros((F, F, 3))
        a = np.zeros((F, F))
        # stem, then stamens, then petals on top
        col = np.where((stem > 0.02)[..., None], STEM, col)
        a = np.maximum(a, stem)
        col = np.where((stam > 0.02)[..., None], LILY_HI, col)
        a = np.maximum(a, stam)
        pd = ndimage.distance_transform_edt(pet > 0.5)
        pcol = LILY_DEEP + (LILY - LILY_DEEP) * smooth(0, 2.5, pd)[..., None]
        col = np.where((pet > 0.02)[..., None], pcol, col)
        a = np.maximum(a, pet)
        # a soft blue glow round the head (the flower is half-mythical)
        glow = np.clip(ndimage.gaussian_filter(np.maximum(pet, stam), 7) * 2.2, 0, 1) * 0.42
        none = a < 0.02
        col = np.where(none[..., None], LILY, col)
        a = np.maximum(a, glow)
        # wilting: the colour drains toward a dark blue-grey
        col = col * (1 - 0.45 * wilt_t) + np.array([30, 40, 70]) * 0.45 * wilt_t
        frames.append(to_img(np.dstack([col, a * fade * 255])))
    return sheet(frames)


# ------------------------------------------------------------------ blood: drops and mist
def droplet(N=128):
    yy, xx = np.mgrid[-1:1:N * 1j, -1:1:N * 1j]
    r = np.hypot(xx, (yy + 0.1) * 1.08)
    a = 1 - smooth(0.62, 0.7, r)
    shade_ = smooth(0.7, -0.4, xx * 0.5 + yy * 0.7)
    col = BLACKRED[None, None, :] + (CRIMSON - BLACKRED)[None, None, :] * shade_[..., None]
    hl = np.exp(-(((xx + 0.22) / 0.13) ** 2 + ((yy + 0.28) / 0.09) ** 2))[..., None]
    col = col * (1 - hl) + np.array([255, 220, 225]) * hl
    rim = (smooth(0.5, 0.66, r) * (r < 0.7))[..., None]
    col = col * (1 - rim * 0.6) + BLACKRED * rim * 0.6
    return to_img(np.dstack([col, a * 255]))


def mist():
    yy, xx = np.mgrid[-1:1:F * 1j, -1:1:F * 1j]
    n = fbm((F, F), [16, 7], [1.0, 0.5], 401)
    frames = []
    for f in range(16):
        t = f / 15
        R = 0.3 + 0.55 * smooth(0, 0.6, t)
        r = np.hypot(xx * 0.8, yy * 1.3)
        dens = (1 - r / R) + 0.35 * np.roll(n, int(t * 20), axis=1)
        a = np.clip(dens * 1.2, 0, 1) ** 1.4 * (1 - smooth(0.4, 1.0, t)) * smooth(0, 0.15, t + 0.05)
        col = BLACKRED[None, None, :] + (BLOOD - BLACKRED)[None, None, :] * np.clip(dens, 0, 1)[..., None]
        frames.append(to_img(np.dstack([col, a * 0.85 * 255])))
    return sheet(frames)


def contact(imgs):
    tiles = []
    for name, im in imgs:
        t = im.copy()
        t.thumbnail((512, 512))
        tiles.append((name, t))
    rows = math.ceil(len(tiles) / 2)
    out = Image.new("RGB", (1080, rows * 560), (250, 60, 110))  # his rose-pink stand
    dark = Image.new("RGB", (540, 560), (25, 22, 55))
    for i, (name, t) in enumerate(tiles):
        x, y = (i % 2) * 540, (i // 2) * 560
        if (i // 2) % 2 == 1:
            out.paste(dark, (x, y))
        out.paste(t, (x + 14, y + 14), t)
        ImageDraw.Draw(out).text((x + 14, y + 534), name, fill=(255, 255, 255))
    return out


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    jobs = [("blood_pool", blood_pool), ("pulse_ring", pulse_ring), ("whip", whip), ("lily_4x4", lily),
            ("droplet", droplet), ("mist_4x4", mist)]
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
