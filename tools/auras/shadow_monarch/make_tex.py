#!/usr/bin/env python3
"""ShadowArise (Sung Jinwoo, "Shadow Monarch") aura textures, made from maths: nothing harvested.

    python tools/auras/shadow_monarch/make_tex.py      -> assets/auras/shadow_monarch/*.png (+ _sheet.jpg)

The look (Solo Leveling): void black shapes rimmed in violet, the shadow army rising, eyes that glow
blue-violet. As with Itachi's aura, the dark textures are PRE-COLOURED (black core, indigo band, violet
rim, faint violet halo) and drawn with Color white, LightEmission 0, LightInfluence 0. Jinwoo wears black,
so every dark shape carries a wide violet band (black-on-black vanished on Itachi's robe in Studio).

  shadowflame_4x4.png  16-frame LOOP of violet-black flame tongues (taller and smokier than Amaterasu)
  shadowsmoke_4x4.png  16-frame ONE-SHOT shadow puff: billows, then erodes into violet-edged wisps
  soldier_knight.png   the shadow army, one silhouette each, bust to waist, dissolving into mist at the
  soldier_horned.png   bottom, two glowing eye slits: a knight with a long plume (his first knight), a
  soldier_ant.png      horned knight, an ant soldier (mandibles, antennae, spiked shoulders), a hooded mage
  soldier_mage.png
  void_pool.png        ground: a black void pool with a ragged violet edge and shadow spikes reaching out
  rune_ring.png        ground ring: violet glyphs of our own alphabet between thin rings (turns the other way)
  eye_flare.png        a horizontal streak flare with a hot core (the glowing eye), tinted by Color
  spark.png            a four-point glint with a soft halo (rising motes), tinted by Color
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets" / "auras" / "shadow_monarch"
F = 256

VOID = np.array([6, 4, 12], float)
INDIGO = np.array([34, 10, 70], float)
VIOLET = np.array([128, 64, 255], float)
LILAC = np.array([205, 180, 255], float)  # the hot keyline
HALO = np.array([120, 70, 255], float)


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


def shade(D, band_px=12.0, core_px=(9.0, 16.0), halo_px=7.0, halo_a=0.36, licks=True):
    """D: a smooth field whose 0.5 level is the edge. 3-band cel: lilac keyline, violet band fading to
    indigo, void core; a faint violet halo outside; optional inner lick contours. Float RGBA 0..255."""
    m = smooth(0.465, 0.535, D)
    solid = D > 0.5
    din = ndimage.distance_transform_edt(solid)
    dout = ndimage.distance_transform_edt(~solid)
    t = smooth(2.5, band_px, din)[..., None]
    col = VIOLET[None, None, :] * (1 - t) + INDIGO[None, None, :] * t
    ct = smooth(core_px[0], core_px[1], din)[..., None]
    col = col * (1 - ct) + VOID[None, None, :] * ct
    key = (1 - smooth(1.0, 2.4, din))[..., None]
    col = col * (1 - key) + LILAC[None, None, :] * key
    if licks:
        core = ndimage.binary_opening(D > 0.85, iterations=2)
        line = core & ~ndimage.binary_erosion(core, iterations=2)
        line &= ndimage.binary_erosion(solid, iterations=8)
        lf = np.clip(ndimage.gaussian_filter(line.astype(float), 0.6) * 1.6, 0, 1)[..., None]
        col = col * (1 - lf) + VIOLET[None, None, :] * lf
    halo = (1 - smooth(0, halo_px, dout)) * halo_a * (~solid)
    col = np.where(solid[..., None], col, HALO[None, None, :] * np.ones_like(col))
    a = np.where(solid, np.maximum(m, 0.0), np.maximum(halo, m))
    return np.dstack([col, a * 255])


# ------------------------------------------------------------------ shadow flames (loop)
def shadowflame():
    H, W = F * 2, F
    n1 = fbm((H, W), [(30, 8), (13, 4)], [1.0, 0.55], 101)
    n2 = fbm((H, W), [(10, 3), (4, 1.5)], [1.0, 0.5], 111)
    warp = field((H, W), 22, 121)
    y = np.linspace(0, 1, F)[:, None] * np.ones((1, F))
    x = np.linspace(-1, 1, F)[None, :] * np.ones((F, 1))
    frames = []
    for f in range(16):
        off = int(round(f / 16 * H))
        rows = (np.arange(F) + off) % H
        xs = x + 0.26 * warp[rows] * (1 - y) ** 1.2
        cols = np.clip(((xs + 1) / 2 * (W - 1)).astype(int), 0, W - 1)
        a = n1[rows[:, None], cols]
        b = n2[(rows * 2 % H)[:, None], cols]
        width = 0.10 + 0.74 * y ** 1.3  # wide enough for a violet band to read
        env = 1 - (np.abs(xs) / width) ** 1.6
        heat = (y ** 1.25) * 1.3
        dens = heat * env + 0.66 * a + 0.10 * b - 0.42  # little fine noise: fine holes read as confetti at range
        dens -= 1.5 * smooth(0.78, 0.96, y + 0.22 * (xs / width) ** 2)
        dens -= 0.9 * smooth(0.82, 0.98, np.abs(x))
        frames.append(to_img(shade(dens * 2.2 + 0.5, band_px=24, core_px=(20, 34), halo_a=0.45)))
    return sheet(frames)


# ------------------------------------------------------------------ shadow smoke (one shot)
def shadowsmoke():
    yy, xx = np.mgrid[-1:1:F * 1j, -1:1:F * 1j]
    big = fbm((F, F), [14, 7], [1.0, 0.5], 131)
    fine = fbm((F, F), [4, 2], [1.0, 0.5], 141)
    frames = []
    for f in range(16):
        t = f / 15
        R = 0.18 + 0.58 * smooth(0.0, 0.45, t)
        b = np.roll(big, -int(t * 22), axis=0)
        r = np.sqrt((xx * (1 + 0.2 * t)) ** 2 + ((yy + 0.12 * t) * 1.05) ** 2)
        dens = 1 - r / R + 0.45 * b + 0.2 * fine - 0.55 * smooth(0.3, 1.0, t)
        if t > 0.92:
            dens -= 1
        frames.append(to_img(shade(dens * 1.4 + 0.5, band_px=9, core_px=(7, 13), halo_px=5, halo_a=0.3, licks=False)))
    return sheet(frames)


# ------------------------------------------------------------------ the shadow army
def chaikin(pts, n=3, closed=True):
    p = np.asarray(pts, float)
    for _ in range(n):
        if closed:
            q = 0.75 * p + 0.25 * np.roll(p, -1, 0)
            r = 0.25 * p + 0.75 * np.roll(p, -1, 0)
        else:
            q = 0.75 * p[:-1] + 0.25 * p[1:]
            r = 0.25 * p[:-1] + 0.75 * p[1:]
        out = np.empty((len(q) * 2, 2))
        out[0::2], out[1::2] = q, r
        if not closed:
            out = np.vstack([p[:1], out, p[-1:]])
        p = out
    return p


def mirror(half):
    """half: points down the RIGHT side from top centre to bottom; returns the closed outline."""
    left = [(-x, y) for x, y in reversed(half)]
    return list(half) + left


def soldier(kind, N=512, k=3):
    """One of the shadow army, bust to waist, on a 512 canvas (x right, y up, origin at chest centre,
    300 px from the top). Organic outlines are chaikin-smoothed; the bottom dissolves into rising wisps."""
    S = N * k
    im = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(im)
    u = S / 512.0

    def P(x, y):
        return (S / 2 + x * u, 300 * u - y * u)

    def shape(pts, smooth_n=3, closed=True):
        p = chaikin(pts, smooth_n, closed) if smooth_n else np.asarray(pts, float)
        d.polygon([P(x, y) for x, y in p], fill=255)

    def ribbon(centre, w0, w1, smooth_n=3):
        """a tapered stroke along a smoothed centreline (plumes, antennae, horns)."""
        c = chaikin(centre, smooth_n, closed=False)
        n = len(c)
        L, R = [], []
        for i in range(n):
            a = c[min(i + 1, n - 1)] - c[max(i - 1, 0)]
            a = a / (np.hypot(*a) + 1e-9)
            nx, ny = -a[1], a[0]
            w = w0 + (w1 - w0) * (i / (n - 1))
            L.append((c[i][0] + nx * w, c[i][1] + ny * w))
            R.append((c[i][0] - nx * w, c[i][1] - ny * w))
        d.polygon([P(x, y) for x, y in L + R[::-1]], fill=255)

    eyes = []  # (x, y, half width, half height, tilt degrees)
    if kind in ("knight", "horned"):
        # torso: neck, sloped trapezius, broad chest, arms hanging at the sides, down out of frame
        shape(mirror([(0, 100), (30, 98), (62, 84), (104, 66), (130, 52), (148, 30), (156, 0), (160, -60),
                      (156, -130), (150, -240)]))
        # stepped plate pauldrons: three overlapping plates, each lower and wider than the last
        for s in (-1, 1):
            for i, (y0, x0, x1) in enumerate([(78, 70, 150), (52, 96, 172), (24, 118, 186)]):
                shape([(s * x0, y0 + 10), (s * (x0 + x1) / 2, y0 + 20 - i * 2), (s * x1, y0 - 4),
                       (s * (x1 + 4), y0 - 26), (s * (x0 + 20), y0 - 18)], smooth_n=2)
        if kind == "knight":
            # a cape flaring behind the shoulders
            shape(mirror([(0, 60), (150, 40), (178, -60), (204, -240)]), smooth_n=2)
            # helm: dome, cheek guards narrowing to a pointed chin guard, a crest fin
            # helm: kept angular (a smoothed helm read as a bald head in v1): flat crown, flared cheek
            # guards, a jaw that juts below the chin, and a crest ridge running front to back
            shape(mirror([(0, 234), (26, 232), (46, 220), (56, 198), (60, 168), (64, 138), (56, 116), (38, 96),
                          (18, 80), (0, 74)]), smooth_n=1)
            shape([(-8, 230), (-6, 256), (12, 268), (40, 262), (60, 244), (34, 236), (10, 230)], smooth_n=1)
            # the horsehair plume: thick at the crest, fanning into strands that stream back and down
            for dy, w0, mid, end in [(0, 26, (196, 214), (232, 70)), (-10, 18, (210, 196), (256, 110)),
                                     (8, 16, (180, 222), (204, 40)), (-4, 12, (222, 180), (270, 150))]:
                ribbon([(30, 258 + dy), (90, 284 + dy), (150, 272 + dy), mid, end], w0, 2.0)
            eyes = [(-20, 160, 13, 3.2, 8), (20, 160, 13, 3.2, -8)]
        else:
            shape(mirror([(0, 214), (36, 208), (54, 184), (56, 150), (50, 118), (30, 96), (0, 90)]))
            for s in (-1, 1):  # horns sweeping out and up
                ribbon([(s * 40, 190), (s * 80, 208), (s * 112, 236), (s * 128, 274), (s * 122, 310)], 13, 1.5)
            for s in (-1, 1):  # spikes on the pauldrons
                shape([(s * 120, 70), (s * 140, 128), (s * 150, 66)], smooth_n=0)
                shape([(s * 156, 40), (s * 196, 82), (s * 178, 30)], smooth_n=0)
            eyes = [(-19, 152, 12, 3.0, 6), (19, 152, 12, 3.0, -6)]
    elif kind == "ant":
        # the ant soldier: a long head narrowing to a jaw, big slanted compound eyes, curved mandibles,
        # antennae, a thorax with a carapace of backward spikes, thin arms with blade forearms
        shape(mirror([(0, 70), (26, 72), (54, 56), (84, 40), (110, 10), (118, -50), (110, -130), (104, -240)]))
        for s in (-1, 1):
            shape([(s * 60, 54), (s * 150, 96), (s * 214, 92), (s * 150, 66), (s * 104, 34)], smooth_n=1)
            shape([(s * 100, 14), (s * 190, 32), (s * 230, 8), (s * 176, 6), (s * 112, -14)], smooth_n=1)
            ribbon([(s * 112, -10), (s * 140, -70), (s * 150, -130)], 14, 10, smooth_n=2)
            ribbon([(s * 150, -130), (s * 186, -170), (s * 214, -230)], 12, 1.5, smooth_n=2)
        shape(mirror([(0, 236), (34, 230), (62, 206), (72, 170), (64, 132), (44, 102), (24, 84), (0, 78)]))
        for s in (-1, 1):
            ribbon([(s * 26, 92), (s * 52, 72), (s * 56, 46), (s * 38, 26), (s * 14, 22)], 9, 2, smooth_n=2)
            ribbon([(s * 22, 226), (s * 50, 262), (s * 96, 290), (s * 150, 296), (s * 196, 280)], 4.5, 1.2)
        eyes = [(-34, 176, 22, 7.5, 24), (34, 176, 22, 7.5, -24)]
    elif kind == "mage":
        # a deep pointed hood drooping forward, robe shoulders, a staff with a crooked head and a glowing orb
        shape(mirror([(0, 104), (40, 106), (100, 76), (140, 44), (156, -20), (160, -120), (158, -240)]))
        shape([(-70, 72), (-84, 150), (-70, 210), (-30, 258), (14, 300), (34, 316), (26, 272), (56, 224),
               (76, 160), (72, 72)])
        ribbon([(-186, -240), (-184, 60), (-180, 200), (-176, 236)], 6.5, 5.5, smooth_n=1)
        ribbon([(-176, 236), (-192, 262), (-176, 288), (-152, 286), (-148, 264)], 6, 4, smooth_n=2)
        eyes = [(-22, 172, 11, 3.2, 4), (22, 172, 11, 3.2, -4), (-166, 262, 12, 12, 0)]
    m = np.asarray(im, float) / 255.0
    m = m.reshape(N, k, N, k).mean(axis=(1, 3))
    # dissolve into mist: vertically stretched noise makes the fade rise in wisps, not a torn edge
    yy = np.linspace(0, 1, N)[:, None] * np.ones((1, N))
    wisp = fbm((N, N), [(22, 3), (8, 1.6)], [1.0, 0.5], 151 + len(kind))
    roll = fbm((N, N), [(40, 40)], [1.0], 161 + len(kind))
    fade = smooth(0.97, 0.52, yy + 0.24 * roll + 0.07 * wisp)
    D = (m - 0.5) * 2.2 + 0.5 - (1 - fade) * 1.3
    rgba = shade(D, band_px=11, core_px=(8, 15), halo_px=12, halo_a=0.45, licks=False)
    # glowing eyes (part of the texture: the silhouette must read as a soldier at a glance)
    X, Y = np.meshgrid(np.arange(N), np.arange(N))
    for ex, ey, ew, eh, tilt in eyes:
        cx, cy = N / 2 + ex * N / 512, 300 * N / 512 - ey * N / 512
        ca, sa = math.cos(math.radians(tilt)), math.sin(math.radians(tilt))
        dx, dy = X - cx, Y - cy
        lx, ly = dx * ca + dy * sa, -dx * sa + dy * ca
        # eyes drawn 1.6x and with a wide halo: at 4-5 studs the v1 eyes were a few pixels
        r = np.sqrt((lx / (1.6 * ew * N / 512)) ** 2 + (ly / (1.6 * eh * N / 512)) ** 2)
        core = 1 - smooth(0.7, 1.15, r)
        glow = (1 - smooth(0, 4.5, r)) ** 1.6 * 0.95
        for c, v in enumerate((225, 240, 255)):
            rgba[..., c] = rgba[..., c] * (1 - core) + v * core
        g2 = glow * (1 - core)
        for c, v in enumerate(HALO):
            rgba[..., c] = rgba[..., c] * (1 - g2) + v * g2
        rgba[..., 3] = np.maximum(rgba[..., 3], np.maximum(core, glow) * 255)
    return to_img(rgba)


# ------------------------------------------------------------------ ground
def polar(N):
    yy, xx = np.mgrid[-1:1:N * 1j, -1:1:N * 1j]
    return np.hypot(xx, yy), np.arctan2(yy, xx), xx, yy


def void_pool(N=1024):
    """A pool of liquid shadow, not a hole: a ragged disc whose edge is lit violet from inside, curling
    shadow tendrils (not straight spikes: on the gold Legendary stand straight spikes read as a black
    hedgehog), faint ripple rings in the void and slow indigo swirls."""
    r, th, xx, yy = polar(N)
    n = fbm((N, N), [26, 11, 4], [1.0, 0.45, 0.2], 161)
    R0 = 0.50
    D = (R0 + 0.035 * n - r) * 9 + 0.5  # the pool
    # curling tendrils: tapered ribbons spiralling out from the edge, uneven lengths, all one way
    im = Image.new("L", (N * 2, N * 2), 0)
    d = ImageDraw.Draw(im)
    rng = np.random.default_rng(7)
    for i in range(9):
        a0 = i * 2 * math.pi / 9 + rng.uniform(-0.25, 0.25)
        L = rng.uniform(0.14, 0.30)
        curl = rng.uniform(0.55, 1.0)
        w0 = rng.uniform(0.075, 0.1)
        pts_l, pts_r = [], []
        for s in np.linspace(0, 1, 40):
            rad = R0 - 0.10 + (L + 0.06) * s
            ang = a0 + curl * s ** 1.4
            cx, cy = rad * math.cos(ang), rad * math.sin(ang)
            ta = ang + math.atan2(1, curl * 1.4 * max(s, 0.05) ** 0.4 * rad / max(L, 1e-3))
            nx, ny = -math.sin(ta), math.cos(ta)
            w = w0 * (1 - s) ** 1.2 + 0.003
            pts_l.append(((cx + nx * w + 1) * N, (cy + ny * w + 1) * N))
            pts_r.append(((cx - nx * w + 1) * N, (cy - ny * w + 1) * N))
        d.polygon(pts_l + pts_r[::-1], fill=255)
    t = np.asarray(im.resize((N, N), Image.LANCZOS), float) / 255.0
    D = np.maximum(D, (t - 0.5) * 2.2 + 0.5)
    rgba = shade(D, band_px=26, core_px=(22, 60), halo_px=26, halo_a=0.55, licks=False)
    solid = D > 0.5
    inner = smooth(0.0, 0.42, r)  # violet light rising toward the rim, the middle is deep void
    lift = (smooth(0.18, 0.5, r) * 0.35)[..., None]
    rgba[..., :3] = np.where(solid[..., None], rgba[..., :3] * (1 - lift) + INDIGO * 1.6 * lift, rgba[..., :3])
    # ripple rings and swirls inside the void
    ripple = np.zeros_like(r)
    for rr in (0.22, 0.36):
        ripple = np.maximum(ripple, np.exp(-((r - rr - 0.04 * n) / 0.007) ** 2) * (0.5 + 0.5 * np.clip(n * 2, 0, 1)))
    sw = np.clip(fbm((N, N), [30, 12], [1.0, 0.5], 171) * 1.4, 0, 1)
    rip = (ripple * 0.4 * solid * (1 - smooth(0.42, 0.5, r)))[..., None]
    rgba[..., :3] = rgba[..., :3] * (1 - rip) + VIOLET * rip
    swi = (sw * 0.35 * solid * (1 - inner * 0.3))[..., None]
    rgba[..., :3] = rgba[..., :3] * (1 - swi) + INDIGO * 1.3 * swi
    return to_img(rgba)


def rune_ring(N=1024):
    """Violet glyphs of our own alphabet on a dark band between two bright rings: the dark band is what
    makes them read on any stand (lilac on the gold Legendary stand vanished in Studio, v1)."""
    k = 2
    M = N * k
    r, th, xx, yy = polar(M)
    lines = ((r > 0.95) & (r < 0.965)) | ((r > 0.785) & (r < 0.80))
    im = Image.new("L", (M, M), 0)
    d = ImageDraw.Draw(im)
    rng = np.random.default_rng(99)
    count = 30
    for i in range(count):
        a0 = i * 2 * math.pi / count
        cx, cy = 0.5 * M + 0.875 * M / 2 * math.cos(a0), 0.5 * M + 0.875 * M / 2 * math.sin(a0)
        g = []
        pts = [(gx, gy) for gx in (-1, 0, 1) for gy in (-1.5, -0.5, 0.5, 1.5)]
        for _ in range(rng.integers(3, 6)):
            p, q = rng.choice(len(pts), 2, replace=False)
            g.append((pts[p], pts[q]))
        s = 0.022 * M
        ux, uy = math.cos(a0), math.sin(a0)
        vx, vy = -uy, ux
        for (x0, y0), (x1, y1) in g:
            A = (cx + (x0 * vx + y0 * ux) * s, cy + (x0 * vy + y0 * uy) * s)
            B = (cx + (x1 * vx + y1 * ux) * s, cy + (x1 * vy + y1 * uy) * s)
            d.line([A, B], fill=255, width=int(0.0075 * M))
        d.ellipse([cx - 0.0045 * M, cy - 0.0045 * M, cx + 0.0045 * M, cy + 0.0045 * M], fill=255)
    glyph = np.asarray(im) > 127
    shape = glyph | lines
    glow = np.clip(ndimage.gaussian_filter(shape.astype(float), 5 * k) * 2.6, 0, 1)
    band = (r > 0.785) & (r < 0.965)
    col = np.zeros((M, M, 3))
    col[:] = VOID * 0.6 + INDIGO * 0.4
    col = np.where((glow > 0.02)[..., None] & ~shape[..., None],
                   (VOID * 0.6 + INDIGO * 0.4) * (1 - glow[..., None]) + VIOLET * glow[..., None], col)
    col = np.where(shape[..., None], LILAC[None, None, :], col)
    a = np.where(band, 0.82, glow * 0.6)
    a = np.where(shape, 1.0, a)
    # soft outer and inner edges of the band
    a = np.where(band, a * smooth(0.785, 0.80, r) * smooth(0.965, 0.95, r) + shape * 1.0, a)
    a = np.clip(a, 0, 1)
    return to_img(np.dstack([col, a * 255])).resize((N, N), Image.LANCZOS)


# ------------------------------------------------------------------ small glows
def eye_flare(N=256):
    yy, xx = np.mgrid[-1:1:N * 1j, -1:1:N * 1j]
    streak = np.exp(-(yy / 0.035) ** 2) * np.exp(-(np.abs(xx) / 0.55) ** 1.2)
    core = np.exp(-(np.hypot(xx, yy * 1.2) / 0.08) ** 2)
    halo = np.exp(-(np.hypot(xx, yy) / 0.3) ** 2) * 0.45
    a = np.clip(streak + core + halo, 0, 1)
    w = np.ones_like(a) * 255
    return to_img(np.dstack([w, w, w, a * 255]))


def streak(N=256):
    """a thin vertical energy line, tapered at both ends (drawn along the velocity: rising aura lines)"""
    yy, xx = np.mgrid[-1:1:N * 1j, -1:1:N * 1j]
    taper = np.clip(1 - np.abs(yy) / 0.92, 0, 1) ** 0.8
    w = 0.085 * taper + 1e-4  # 0.025 was under a pixel wide in Studio: invisible
    core = np.exp(-(xx / w) ** 2) * taper
    glow = np.exp(-(xx / (w * 3)) ** 2) * taper * 0.55
    a = np.clip(core + glow, 0, 1)
    c = np.ones_like(a) * 255
    return to_img(np.dstack([c, c, c, a * 255]))


def spark(N=128):
    yy, xx = np.mgrid[-1:1:N * 1j, -1:1:N * 1j]
    star = np.exp(-(np.abs(xx) / 0.05)) * np.exp(-(np.abs(yy) / 0.6)) + np.exp(-(np.abs(yy) / 0.05)) * np.exp(-(np.abs(xx) / 0.6))
    core = np.exp(-(np.hypot(xx, yy) / 0.12) ** 2)
    halo = np.exp(-(np.hypot(xx, yy) / 0.45) ** 2) * 0.4
    a = np.clip(star * 0.9 + core + halo, 0, 1)
    w = np.ones_like(a) * 255
    return to_img(np.dstack([w, w, w, a * 255]))


def contact(imgs):
    tiles = []
    for name, im in imgs:
        t = im.copy()
        t.thumbnail((512, 512))
        tiles.append((name, t))
    rows = math.ceil(len(tiles) / 2)
    out = Image.new("RGB", (1080, rows * 560), (150, 120, 200))
    dark = Image.new("RGB", (540, 560), (25, 22, 55))
    for i, (name, t) in enumerate(tiles):
        x, y = (i % 2) * 540, (i // 2) * 560
        if (i // 2) % 2 == 0:
            out.paste(dark, (x, y))
        out.paste(t, (x + 14, y + 14), t)
        ImageDraw.Draw(out).text((x + 14, y + 534), name, fill=(255, 255, 255))
    return out


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    jobs = [("shadowflame_4x4", shadowflame), ("shadowsmoke_4x4", shadowsmoke),
            ("soldier_knight", lambda: soldier("knight")), ("soldier_horned", lambda: soldier("horned")),
            ("soldier_ant", lambda: soldier("ant")), ("soldier_mage", lambda: soldier("mage")),
            ("void_pool", void_pool), ("rune_ring", rune_ring), ("eye_flare", eye_flare), ("spark", spark), ("streak", streak)]
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
