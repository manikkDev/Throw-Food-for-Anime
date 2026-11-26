#!/usr/bin/env python3
"""DarkSlash (Yami Sukehiro, "Dark Slash Captain") aura textures, made from maths: nothing harvested.

    python tools/auras/dark_slash/make_tex.py      -> assets/auras/dark_slash/*.png (+ _sheet.jpg)

No flame tongues (the owner's brief). Yami's Dark Magic: slashes that cut space itself, a black crescent
moon, ink-black darkness with a thin white edge (Black Clover's inked look).

  rift_4x4.png     16-frame ONE-SHOT dimension slash, anime-timed: a white-hot stroke swipes across,
                   flashes, tears open into void (ragged lips, white rim, violet light inside), closes,
                   and leaves a fading scar with ink specks drifting off
  black_moon.png   a black crescent moon with a thin white rim and a faint violet halo
  ink_pool.png     ground: a black ink splash pool with a straight dimension-slash scar cut across it
                   (white-rimmed), ink droplets round it
  brush_4x4.png    16-frame ONE-SHOT ink brush stroke: a curving stroke drawn with a dry-brush edge,
                   held, then dissolving into specks
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets" / "auras" / "dark_slash"
F = 256

INK = np.array([8, 8, 13], float)
VOID = np.array([22, 10, 40], float)
VIOLET = np.array([110, 70, 190], float)
WHITE = np.array([240, 240, 255], float)


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def field(shape, scale, seed):
    rng = np.random.default_rng(seed)
    f = ndimage.gaussian_filter(rng.standard_normal(shape), scale, mode="wrap")
    return f / (np.abs(f).max() + 1e-9)


def to_img(rgba):
    return Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), "RGBA")


def sheet(frames):
    s = Image.new("RGBA", (F * 4, F * 4), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        s.paste(fr, ((i % 4) * F, (i // 4) * F))
    return s


def rift():
    """16-frame ONE-SHOT dimension slash, anime-timed (v2: v1 faded in as a clean dark lens and read odd):
      0-2   SWIPE  a white-hot tapered crescent stroke sweeps left to right, a motion-blur tail behind it
      2-3   FLASH  the whole cut line glows
      3-10  TEAR   it splits open: slightly ragged lips, a white rim, violet light just inside, specks
                   deep in the void
      10-13 CLOSE  eased shut, the rim brightening as the lips meet
      13-15 SCAR   a white scar line fading, a few ink specks drifting off
    Drawn at 2x and downsampled for smooth edges."""
    k = 2
    N = F * k
    yy, xx = np.mgrid[-1:1:N * 1j, -1:1:N * 1j]
    L, bend = 0.86, 0.2
    u = np.clip(xx / L, -1.2, 1.2)
    yc = bend * (1 - u ** 2) - bend / 2
    dy = yy - yc  # signed distance across the slash (y down is +)
    taper = np.clip(1 - u ** 2, 0, 1)
    rng = np.random.default_rng(8)

    def noise1d(scale, seed):
        g = np.random.default_rng(seed).standard_normal(512)
        g = ndimage.gaussian_filter1d(g, scale, mode="wrap")
        g /= np.abs(g).max() + 1e-9
        idx = np.clip(((u + 1.2) / 2.4 * 511).astype(int), 0, 511)
        return g[idx]

    rag_top = noise1d(14, 1) * 0.5 + noise1d(3, 2) * 0.5
    rag_bot = noise1d(14, 3) * 0.5 + noise1d(3, 4) * 0.5
    teeth_t = noise1d(1.2, 5)
    teeth_b = noise1d(1.2, 6)
    specks = (field((N, N), 1.4, 41) > 0.8)
    px = 2.0 / N
    # tendril roots along the lips: (u, which lip, curl direction)
    roots = [(rng.uniform(-0.65, 0.65), rng.choice([-1, 1]), rng.choice([-1, 1])) for _ in range(7)]
    frames = []
    for f in range(16):
        t = f / 15
        sweep = smooth(0.0, 0.14, t)
        u_head = -1.05 + 2.1 * sweep
        open_t = smooth(0.15, 0.34, t) * (1 - smooth(0.64, 0.86, t))
        scar = smooth(0.12, 0.2, t) * (1 - smooth(0.86, 1.0, t))
        col = np.zeros((N, N, 3))
        a = np.zeros((N, N))
        # SWIPE: the stroke exists behind the head, brightest at the head
        if t <= 0.2:
            head = smooth(u_head + 0.02, u_head - 0.32, u)  # 0 at the tip .. 1 behind it: a pointed head
            ws = (0.045 * taper ** 0.7 + 0.002) * (1.15 - 0.6 * smooth(0.12, 0.2, t)) * (0.15 + 0.85 * head ** 0.6)
            along = smooth(u_head - 1.1, u_head - 0.05, u) * smooth(u_head + 0.04, u_head - 0.06, u)
            core = (1 - smooth(ws * 0.35, ws, np.abs(dy))) * along
            glow = (1 - smooth(ws, ws * 3.5, np.abs(dy))) * along * 0.55
            col = np.where((core > 0.01)[..., None], WHITE, VIOLET)
            a = np.maximum(core, glow)
        # TEAR: the void between ragged lips
        ht = open_t * 0.15 * taper ** 0.75 * (1 + 0.16 * rag_top) + open_t * 0.0025 * teeth_t
        hb = open_t * 0.11 * taper ** 0.75 * (1 + 0.16 * rag_bot) + open_t * 0.0025 * teeth_b
        inside = (dy > -ht) & (dy < hb) & (taper > 0.01) & (open_t > 0.02)
        din = np.minimum(dy + ht, hb - dy)  # depth inside the void
        if open_t > 0.02:
            depth = smooth(0.0, 0.05, din)[..., None]
            voidc = VIOLET * 0.55 * (1 - depth) + INK * depth
            col = np.where(inside[..., None], voidc, col)
            a = np.where(inside, 1.0, a)
            sp = inside & specks & (din > 0.03)
            col = np.where(sp[..., None], VIOLET * 1.7, col)
        # the lips: a white rim on both edges (merges into the scar line when closed)
        lip_d = np.minimum(np.abs(dy + ht), np.abs(dy - hb))
        rim_w = px * (2.2 + 2.0 * (1 - open_t))
        rim = (1 - smooth(rim_w * 0.6, rim_w * 1.6, lip_d)) * (taper > 0.01) * scar
        col = col * (1 - rim[..., None]) + WHITE * rim[..., None]
        a = np.maximum(a, rim)
        halo = (1 - smooth(rim_w, rim_w * 7, lip_d)) * (taper > 0.01) * scar * 0.4 * (~inside)
        col = np.where(((halo > 0.01) & (rim < 0.05) & ~inside)[..., None], VIOLET, col)
        a = np.maximum(a, halo)
        img = to_img(np.dstack([col, a * 255]))
        # (no ink wisps: at slash scale they crossed the slit like stitches; the void carries the look)
        # SCAR: a few ink specks drifting off the closing cut
        if t > 0.8:
            sp = Image.new("RGBA", (N, N), (0, 0, 0, 0))
            d = ImageDraw.Draw(sp)
            fade = 1 - smooth(0.85, 1.0, t)
            for i in range(9):
                ur = -0.7 + 1.4 * i / 8
                y0 = bend * (1 - ur ** 2) - bend / 2 - (t - 0.8) * (0.4 + 0.3 * math.sin(i * 2.1))
                x0 = ur * L + 0.05 * math.sin(i * 1.7)
                r = (2.5 + (i % 3)) * k
                cx, cy = (x0 + 1) * N / 2, (y0 + 1) * N / 2
                d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(8, 8, 13, int(230 * fade)))
            img.alpha_composite(sp)
        frames.append(img.resize((F, F), Image.LANCZOS))
    return sheet(frames)


def black_moon(N=512):
    yy, xx = np.mgrid[-1:1:N * 1j, -1:1:N * 1j]
    r1 = np.hypot(xx, yy)
    r2 = np.hypot(xx - 0.3, yy + 0.18)
    R = 0.72
    moon = (r1 < R) & (r2 > R * 0.88)
    px = 2 / N
    rim1 = (np.abs(r1 - R) < px * 2.5) & (r2 > R * 0.88)
    rim2 = (np.abs(r2 - R * 0.88) < px * 2.0) & (r1 < R)
    rim = rim1 | rim2
    col = np.zeros((N, N, 3))
    col[:] = INK
    shade = smooth(0.2, R, r1)[..., None] * 0.6
    col = col * (1 - shade) + VOID * shade
    col = np.where(rim[..., None], WHITE, col)
    a = (moon | rim).astype(float)
    a = ndimage.gaussian_filter(a, 0.7)
    halo = (1 - smooth(R, R + 0.2, r1)) * 0.45 * (r1 >= R) * (r2 > R * 0.85)
    col = np.where((halo > 0.01)[..., None] & ~(moon | rim)[..., None], VIOLET, col)
    a = np.maximum(a, halo)
    return to_img(np.dstack([col, a * 255]))


def ink_pool(N=1024):
    yy, xx = np.mgrid[-1:1:N * 1j, -1:1:N * 1j]
    r = np.hypot(xx, yy)
    n = field((N, N), 18, 51) * 0.6 + field((N, N), 6, 52) * 0.4
    pool = (0.45 + 0.07 * n - r) > 0
    rng = np.random.default_rng(9)
    drops = np.zeros_like(pool)
    for _ in range(30):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0.5, 0.82)
        rr = rng.uniform(0.008, 0.035) * (1.3 - d)
        drops |= np.hypot(xx - d * math.cos(a), yy - d * math.sin(a)) < rr
    # two crossing dimension cuts, kept INSIDE the pool (one long scar running past the pool read as
    # Saturn's ring in the first sheet)
    scar = np.zeros_like(pool)
    scar_rim = np.zeros_like(pool)
    for ang_d, L, w in ((28, 0.5, 0.026), (-52, 0.34, 0.018)):
        ang = math.radians(ang_d)
        u = xx * math.cos(ang) + yy * math.sin(ang)
        v = -xx * math.sin(ang) + yy * math.cos(ang)
        half = w * np.clip(1 - (u / L) ** 2, 0, 1) ** 0.6
        scar |= (np.abs(v) < half) & (np.abs(u) < L)
        scar_rim |= (np.abs(np.abs(v) - half) < 0.006) & (np.abs(u) < L) & (half > 0.002)
    col = np.zeros((N, N, 3))
    col[:] = INK
    sheen = smooth(0.45, 0.1, r)[..., None] * 0.35
    col = col * (1 - sheen) + VOID * sheen
    col = np.where(scar[..., None], VOID * 0.6, col)
    col = np.where(scar_rim[..., None], WHITE, col)
    ink = pool | drops
    # a white edge round the ink (the inked look) and a faint violet glow along the scar
    edge = ndimage.binary_dilation(ink, iterations=3) & ~ink
    col = np.where(edge[..., None], WHITE * 0.85, col)
    a = (ink | scar | scar_rim | edge).astype(float)
    glow = np.clip(ndimage.gaussian_filter((scar | scar_rim).astype(float), 8) * 3, 0, 1) * 0.5
    col = np.where(((glow > 0.02) & ~(ink | scar | scar_rim | edge))[..., None], VIOLET, col)
    a = np.maximum(a, glow)
    return to_img(np.dstack([col, a * 255]))


def brush():
    k = 3
    S = F * k
    frames = []
    rng = np.random.default_rng(77)
    bristles = rng.uniform(0, 1, 28)
    for f in range(16):
        t = f / 15
        drawn = smooth(0.0, 0.35, t)
        fade = smooth(0.6, 1.0, t)
        im = Image.new("L", (S, S), 0)
        d = ImageDraw.Draw(im)
        # a rising S-curve stroke; width swells then tapers
        pts = []
        for s in np.linspace(0, drawn, 60):
            x = 0.5 + 0.22 * math.sin(s * math.pi * 1.3 + 0.4)
            y = 0.92 - 0.82 * s
            w = 0.11 * math.sin(min(s / 0.9, 1) * math.pi) ** 0.6 + 0.008
            pts.append((x * S, y * S, w * S))
        for i in range(len(pts) - 1):
            x0, y0, w0 = pts[i]
            x1, y1, _ = pts[i + 1]
            for b in bristles:  # dry brush: bristles drop out near the edges
                off = (b - 0.5) * 2 * w0
                if abs(off) > w0 * (0.55 + 0.45 * (1 - i / len(pts))) and rng.random() < 0.5:
                    continue
                d.line([(x0 + off, y0), (x1 + off, y1)], fill=255, width=max(1, int(w0 / 6)))
        m = np.asarray(im, float).reshape(F, k, F, k).mean(axis=(1, 3)) / 255.0
        m = np.clip(m * 1.4, 0, 1)
        if fade > 0:
            dis = field((F, F), 2.5, 61 + f) * 0.5 + 0.5
            m = m * (dis > fade * 1.1)
        solid = m > 0.4
        edge = ndimage.binary_dilation(solid, iterations=2) & ~solid
        col = np.zeros((F, F, 3))
        col[:] = INK
        col = np.where(edge[..., None], WHITE * 0.8, col)
        a = np.maximum(m, edge * 0.8)
        frames.append(to_img(np.dstack([col, a * 255])))
    return sheet(frames)


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
    jobs = [("rift_4x4", rift), ("black_moon", black_moon), ("ink_pool", ink_pool), ("brush_4x4", brush)]
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
