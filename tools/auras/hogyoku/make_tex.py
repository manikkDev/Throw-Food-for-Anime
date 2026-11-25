#!/usr/bin/env python3
"""Hogyoku (Sosuke Aizen, "Illusion Overlord", Premium) aura textures, made from maths and system fonts.

    python tools/auras/hogyoku/make_tex.py      -> assets/auras/hogyoku/*.png (+ _sheet.jpg)

Reference (Bleach, the Fake Karakura Town arc): the Hogyoku fused into his sternum (a violet orb in a cross-shaped
seal, cracks running out of it), his reiatsu as a column of violet light streaks, his god complex ("from now on I
will stand in heaven") as a halo built from his own powers, Hado #90 Kurohitsugi (a coffin of black walls with violet seams), and Kyoka Suigetsu's "Shatter" (reality
breaking like mirror glass; the name means "mirror flower, water moon").
Every texture is PRE-COLOURED (drawn with Color white unless the builder says otherwise).

  hogyoku.png         the orb: deep violet sphere, a nebula swirling inside, a magenta-white heart, rim light, gloss
  seal.png            the chest seal it sits in: four tapered black prongs (a cross) with violet seams, glowing cracks
  crown.png           HEAVEN'S THRONE back plane: twenty black Kurohitsugi blades radiating like a sunburst, violet
                      seams and pale edges, a violet glow behind them (the middle is empty: he stands in it)
  mirror.png          HEAVEN'S THRONE front plane: Kyoka Suigetsu as a round mirror reflecting Las Noches' night and
                      its crescent moon, cracked into glowing shards, the outer ones blown apart mid-"Shatter", ringed
                      by 破道の九十 黒棺
  streak.png          a reiatsu streak along X (VelocityParallel lays X along the motion): white core, violet glow
  glass.png           a Kyoka Suigetsu mirror shard: sky-to-violet reflection, a white bevel edge, a glint
  glass_b.png         a second shard shape
  suigetsu.png        ground sigil: still water mirroring a broken moon, ripples, the ring 鏡花水月 with flower marks
  ripple.png          a water ripple ring (live, expanding on the ground) and the Hogyoku heartbeat
  mote.png            a soft violet-white mote (wing dust, sparks)
  glow.png            soft radial falloff
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets" / "auras" / "hogyoku"
FONTS = Path("C:/Windows/Fonts")
JP_FONT = FONTS / "YuGothB.ttc"

# palette: the Hogyoku's violet, Aizen's reiatsu, Kurohitsugi black
ABYSS = np.array([22, 6, 40], float)
DEEP = np.array([52, 14, 104], float)
VIOLET = np.array([128, 64, 236], float)
ORCHID = np.array([214, 96, 255], float)
LAVENDER = np.array([236, 220, 255], float)
WHITE = np.array([255, 255, 255], float)
COFFIN = np.array([8, 4, 14], float)


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def field(shape, scale, seed, wrap=True):
    rng = np.random.default_rng(seed)
    f = ndimage.gaussian_filter(rng.standard_normal(shape), scale, mode="wrap" if wrap else "reflect")
    return f / (np.abs(f).max() + 1e-9)


def down(rgba, k):
    h, w, _ = rgba.shape
    a = rgba[..., 3:4] / 255.0
    pre = np.concatenate([rgba[..., :3] * a, a], axis=2)
    pre = pre.reshape(h // k, k, w // k, k, 4).mean(axis=(1, 3))
    al = pre[..., 3:4]
    col = np.where(al > 1e-4, pre[..., :3] / np.maximum(al, 1e-4), 0)
    return np.concatenate([col, al * 255], axis=2)


def to_img(rgba):
    return Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), "RGBA")


def over(dst, src):
    sa = src[..., 3:4] / 255.0
    da = dst[..., 3:4] / 255.0
    oa = sa + da * (1 - sa)
    col = np.where(oa > 1e-5, (src[..., :3] * sa + dst[..., :3] * da * (1 - sa)) / np.maximum(oa, 1e-5), 0)
    return np.concatenate([col, oa * 255], axis=2)


def layer(mask, colour):
    c = np.broadcast_to(np.asarray(colour, float), np.shape(mask) + (3,))
    return np.concatenate([c, (np.clip(mask, 0, 1) * 255)[..., None]], axis=2)


def lerp(c0, c1, t):
    t = np.asarray(t, float)[..., None]
    return c0 * (1 - t) + c1 * t


def grid(frames, n):
    f = frames[0].size[0]
    s = Image.new("RGBA", (f * n, f * n), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        s.paste(fr, ((i % n) * f, (i // n) * f))
    return s


def coords(n):
    yy, xx = np.mgrid[0:n, 0:n].astype(float)
    x = (xx + 0.5) / n * 2 - 1
    y = (yy + 0.5) / n * 2 - 1
    return x, y


# ------------------------------------------------------------------ the Hogyoku
def hogyoku(N=512):
    """A sphere lit from the upper left: a deep violet body with a nebula swirling in it, a magenta-white heart
    below the middle (light inside the glass), a lavender rim (fresnel), a sharp gloss and a thin dark outline,
    and a soft orchid halo outside."""
    k = 2
    S = N * k
    x, y = coords(S)
    R = 0.66
    r = np.hypot(x, y) / R
    inside = r < 1
    z = np.sqrt(np.clip(1 - r ** 2, 0, 1))  # sphere height
    nx, ny = x / R, y / R
    # nebula: noise in a swirled frame, denser toward the heart
    th = np.arctan2(ny, nx) + 2.4 * (1 - r)
    sx, sy = r * np.cos(th), r * np.sin(th)
    base = field((S, S), 22 * k, seed=3) * 0.6 + field((S, S), 7 * k, seed=4) * 0.4
    neb = ndimage.map_coordinates(base, [(sy * 0.5 + 0.5) * (S - 1), (sx * 0.5 + 0.5) * (S - 1)], order=1, mode="wrap")
    neb = smooth(-0.1, 0.6, neb)
    heart = np.exp(-(((nx - 0.05) / 0.42) ** 2 + ((ny - 0.12) / 0.38) ** 2))
    col = lerp(ABYSS, DEEP, z ** 0.7)
    col = lerp(col, VIOLET, np.clip(neb * 0.75 * z, 0, 1))
    col = lerp(col, ORCHID, np.clip(heart * 0.9, 0, 1))
    col = lerp(col, LAVENDER, np.clip(heart ** 3 * 0.9, 0, 1))
    # light: diffuse from the upper left, a fresnel rim, a gloss
    L = np.array([-0.5, -0.6, 0.62])
    L = L / np.linalg.norm(L)
    nd = np.clip(nx * L[0] + ny * L[1] + z * L[2], 0, 1)
    col = col * (0.55 + 0.6 * nd[..., None])
    fres = (1 - z) ** 2.2
    col = lerp(col, np.array([196, 150, 255.0]), np.clip(fres * 0.85, 0, 1))
    gloss = np.exp(-(((nx + 0.36) / 0.2) ** 2 + ((ny + 0.42) / 0.12) ** 2))
    col = lerp(col, WHITE, np.clip(gloss * 0.95, 0, 1))
    glint = np.exp(-(((nx - 0.4) / 0.05) ** 2 + ((ny - 0.45) / 0.05) ** 2)) * 0.8
    col = lerp(col, LAVENDER, glint)
    a = inside.astype(float)
    orb = np.concatenate([col, (a * 255)[..., None]], axis=2)
    # thin dark outline and the halo
    ring = (np.abs(r - 1) < 0.025).astype(float)
    halo = np.exp(-(((r - 1) / 0.28) ** 2)) * (r >= 1) * 0.75
    out = np.zeros((S, S, 4))
    out = over(out, layer(halo, ORCHID))
    out = over(out, orb)
    out = over(out, layer(ring * 0.85, ABYSS))
    return to_img(down(out, k))


def seal(N=512):
    """The cross-shaped seal in his chest: four tapered black prongs (long up/down, shorter sideways) around a
    round socket, a violet seam inside each prong, and glowing cracks branching out between them."""
    k = 2
    S = N * k
    c = S / 2
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rng = np.random.default_rng(90)
    # cracks first (under the prongs)
    for i in range(8):
        a = math.pi / 4 + i * math.pi / 4 + rng.uniform(-0.18, 0.18)
        if i % 2 == 0:
            a = math.pi / 4 + (i // 2) * math.pi / 2 + rng.uniform(-0.12, 0.12)
        x, y = c, c
        length = S * rng.uniform(0.3, 0.44)
        steps = 9
        for s in range(steps):
            a += rng.uniform(-0.35, 0.35)
            seg = length / steps
            nx_, ny_ = x + seg * math.cos(a), y + seg * math.sin(a)
            w = int((7 - 0.6 * s) * k)
            d.line([(x, y), (nx_, ny_)], fill=(214, 96, 255, 255), width=max(w, 2 * k))
            if rng.random() < 0.35:
                b = a + rng.choice([-1, 1]) * rng.uniform(0.5, 0.9)
                bx, by = nx_ + seg * 0.8 * math.cos(b), ny_ + seg * 0.8 * math.sin(b)
                d.line([(nx_, ny_), (bx, by)], fill=(214, 96, 255, 230), width=max(w // 2, 2 * k))
            x, y = nx_, ny_
    cracks = np.asarray(img, float)
    glowa = ndimage.gaussian_filter(cracks[..., 3], 6 * k) / 255
    img2 = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d2 = ImageDraw.Draw(img2)
    # prongs: kite shapes from the socket out
    for ang, L, W in ((-90, 0.47, 0.085), (90, 0.47, 0.085), (0, 0.33, 0.075), (180, 0.33, 0.075)):
        a = math.radians(ang)
        ux, uy = math.cos(a), math.sin(a)
        px, py = -uy, ux
        r0 = S * 0.13
        tip = (c + ux * S * L, c + uy * S * L)
        bl = (c + ux * r0 + px * S * W, c + uy * r0 + py * S * W)
        br = (c + ux * r0 - px * S * W, c + uy * r0 - py * S * W)
        mid = (c + ux * S * L * 0.55, c + uy * S * L * 0.55)
        d2.polygon([bl, tip, br, (c + ux * r0 * 0.6, c + uy * r0 * 0.6)], fill=(10, 4, 18, 255))
        # seam
        d2.line([(c + ux * r0, c + uy * r0), tip], fill=(160, 80, 255, 255), width=4 * k)
        d2.line([(c + ux * r0, c + uy * r0), mid], fill=(236, 210, 255, 255), width=2 * k)
    # socket ring
    rr = S * 0.15
    d2.ellipse([c - rr, c - rr, c + rr, c + rr], outline=(10, 4, 18, 255), width=12 * k)
    d2.ellipse([c - rr, c - rr, c + rr, c + rr], outline=(160, 80, 255, 255), width=3 * k)
    prongs = np.asarray(img2, float)
    out = np.zeros((S, S, 4))
    out = over(out, layer(glowa * 0.8, VIOLET))
    out = over(out, cracks)
    out = over(out, prongs)
    return to_img(down(out, k))


# ------------------------------------------------------------------ HEAVEN'S THRONE halo
def crown(N=1024):
    """Twenty black blades radiating from r 0.44: long and short alternating, each a slender kite (widest a third of
    the way out), black with a bright violet seam down its middle and a pale lavender edge; a violet glow behind."""
    k = 2
    S = N * k
    c = S / 2
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    seams = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ds = ImageDraw.Draw(seams)
    n = 20
    for i in range(n):
        a = -math.pi / 2 + i * 2 * math.pi / n
        long = i % 2 == 0
        r0, r1 = 0.44 * c, (0.985 if long else 0.8) * c
        wid = (0.05 if long else 0.038) * c
        ux, uy = math.cos(a), math.sin(a)
        px, py = -uy, ux
        rm = r0 + (r1 - r0) * 0.3
        pts = [(c + ux * r0, c + uy * r0), (c + ux * rm + px * wid, c + uy * rm + py * wid), (c + ux * r1, c + uy * r1),
               (c + ux * rm - px * wid, c + uy * rm - py * wid)]
        d.polygon(pts, fill=(226, 206, 255, 255))  # the edge colour; the black is drawn inset over it
        inset = 0.5  # (0.72: the pale edge was a hairline; black on a dark floor vanished)
        pts_in = [(c + ux * (r0 + 6 * k), c + uy * (r0 + 6 * k)),
                  (c + ux * rm + px * wid * inset, c + uy * rm + py * wid * inset),
                  (c + ux * (r1 - 10 * k), c + uy * (r1 - 10 * k)),
                  (c + ux * rm - px * wid * inset, c + uy * rm - py * wid * inset)]
        d.polygon(pts_in, fill=(9, 4, 16, 255))
        ds.line([(c + ux * (r0 + 14 * k), c + uy * (r0 + 14 * k)), (c + ux * (r1 - 24 * k), c + uy * (r1 - 24 * k))],
                fill=(214, 150, 255, 255), width=7 * k)
    blades = np.asarray(img, float)
    seam = np.asarray(seams, float)
    x, y = coords(S)
    r = np.hypot(x, y)
    glow = layer(np.clip(ndimage.gaussian_filter(blades[..., 3] / 255, 16 * k) * 1.6, 0, 1) * (r > 0.38), np.array([150, 80, 255.0]))
    ring = layer(np.exp(-(((r - 0.44) / 0.006) ** 2)) * 0.9, LAVENDER)
    out = over(over(over(glow, blades), seam), ring)
    seam_bloom = layer(np.clip(ndimage.gaussian_filter(seam[..., 3] / 255, 5 * k) * 1.4, 0, 1), ORCHID)
    return to_img(down(over(out, seam_bloom), k))


def mirror(N=1024):
    """Kyoka Suigetsu as a round mirror (r 0.7) reflecting Las Noches: a night sky from black-indigo to violet, a pale
    crescent moon up and to the left (it shows above his shoulder), faint stars, a diagonal sheen. Cracked into
    voronoi shards with glowing cracks and white bevels, each shard a slightly different reflection; the shards
    beyond r 0.42 are blown outward (more the further out). A ring of the spell's name runs round it."""
    k = 2
    S = N * k
    x, y = coords(S)
    r = np.hypot(x, y)
    R = 0.7
    sky = lerp(np.broadcast_to(np.array([46, 22, 104.0]), (S, S, 3)), np.array([170, 110, 250.0]), smooth(-0.8, 0.9, y))
    mx, my, mr = -0.3, -0.36, 0.17
    md = np.hypot(x - mx, y - my)
    bite = np.hypot(x - mx - 0.075, y - my + 0.05)
    moon = (md < mr) & (bite > mr * 0.92)
    mglow = np.exp(-((md / 0.42) ** 2)) * 0.75
    sky = lerp(sky, np.array([150, 110, 230.0]), mglow)
    sky = lerp(sky, np.array([246, 242, 255.0]), ndimage.gaussian_filter(moon.astype(float), 1.5 * k))
    rng = np.random.default_rng(12)
    for _ in range(70):
        sx, sy = rng.uniform(-R, R), rng.uniform(-R, R)
        sd = np.hypot(x - sx, y - sy)
        sky = lerp(sky, LAVENDER, np.exp(-((sd / rng.uniform(0.002, 0.005)) ** 2)) * rng.uniform(0.4, 1))
    diag = x * 0.7 - y * 0.7
    sheen = np.exp(-(((diag + 0.2) / 0.06) ** 2)) * 0.35 + np.exp(-(((diag - 0.25) / 0.025) ** 2)) * 0.25
    sky = lerp(sky, WHITE, sheen)
    disc = r < R
    ns = 34
    ang = rng.uniform(0, 2 * math.pi, ns)
    rad = np.sqrt(rng.uniform(0, 1, ns)) * R * 1.05
    seeds = np.stack([rad * np.cos(ang), rad * np.sin(ang)], 1)
    dist = np.stack([np.hypot(x - sx, y - sy) for sx, sy in seeds], 0)
    order = np.argsort(dist, 0)
    cell = order[0]
    d1 = np.take_along_axis(dist, order[0:1], 0)[0]
    d2 = np.take_along_axis(dist, order[1:2], 0)[0]
    del dist, order
    edge = d2 - d1
    out = np.zeros((S, S, 4))
    for i, (sx, sy) in enumerate(seeds):
        m = disc & (cell == i)
        if not m.any():
            continue
        sr = math.hypot(sx, sy)
        push = max(0.0, sr - 0.5) * 0.2  # (0.42 from r 0.42: gaps so wide it read as a turtle shell)
        dx, dy = (sx / max(sr, 1e-3)) * push, (sy / max(sr, 1e-3)) * push
        tone = 0.86 + 0.28 * rng.random()
        bev = 1 - smooth(0.004, 0.016, edge)
        col = lerp(sky * tone, WHITE, bev * 0.85)
        shard = np.concatenate([col, (np.where(m, 0.93, 0.0) * 255)[..., None]], axis=2)
        shard = np.where(m[..., None], shard, 0)
        ox, oy = int(round(dx * S / 2)), int(round(dy * S / 2))
        shard = np.roll(np.roll(shard, oy, axis=0), ox, axis=1)
        out = over(out, shard)
    crack = np.exp(-((edge / 0.006) ** 2)) * disc * (r < 0.52)
    out = over(out, layer(np.clip(ndimage.gaussian_filter(crack, 3 * k) * 2.0, 0, 1), np.array([240, 190, 255.0])))
    for rr, w, colr, aa in ((0.78, 0.004, LAVENDER, 1.0), (0.865, 0.003, ORCHID, 0.9)):
        out = over(out, layer(np.exp(-(((r - rr) / w) ** 2)) * aa, colr))
    img = to_img(out)
    f = ImageFont.truetype(str(JP_FONT), int(S * 0.04))
    seq = list("破道の九十・黒棺・") * 3
    rt = S / 2 * 0.822
    c = S / 2
    for i, ch in enumerate(seq):
        a = -math.pi / 2 + i * 2 * math.pi / len(seq)
        g = Image.new("RGBA", (int(S * 0.07), int(S * 0.07)), (0, 0, 0, 0))
        ImageDraw.Draw(g).text((g.size[0] / 2, g.size[1] / 2), ch, font=f, fill=(240, 228, 255, 255), anchor="mm",
                               stroke_width=2 * k, stroke_fill=(40, 10, 80, 255))
        g = g.rotate(-math.degrees(a) - 90, resample=Image.BICUBIC)
        X, Y = c + rt * math.cos(a), c + rt * math.sin(a)
        img.alpha_composite(g, (int(X - g.size[0] / 2), int(Y - g.size[1] / 2)))
    return to_img(down(np.asarray(img, float), k))


# ------------------------------------------------------------------ reiatsu streak
def streak(W=256, H=64):
    x = np.linspace(-1, 1, W)[None, :]
    y = np.linspace(-1, 1, H)[:, None]
    taper = (1 - np.abs(x) ** 2.2) * smooth(-1.0, -0.4, x)  # thicker at the head (+x)
    core = np.exp(-((y / (0.09 + 0.08 * taper)) ** 2)) * taper
    glow = np.exp(-((y / (0.35 + 0.2 * taper)) ** 2)) * taper * 0.6
    a = np.clip(core + glow, 0, 1)
    col = lerp(np.broadcast_to(VIOLET, a.shape + (3,)), WHITE, np.clip(core * 1.2, 0, 1))
    return to_img(np.concatenate([col, (a * 255)[..., None]], axis=2))


# ------------------------------------------------------------------ Kurohitsugi wall
# ------------------------------------------------------------------ Kyoka Suigetsu glass
def glass(points, seed, N=256):
    """A mirror shard: polygon in -1..1 units; a reflection of sky into violet, a white bevel, a corner glint."""
    k = 3
    S = N * k
    img = Image.new("L", (S, S), 0)
    pts = [((px * 0.5 + 0.5) * S, (py * 0.5 + 0.5) * S) for px, py in points]
    ImageDraw.Draw(img).polygon(pts, fill=255)
    m = np.asarray(img, float) / 255 > 0.5
    x, y = coords(S)
    # reflection: a tilted gradient sky -> lavender -> violet with a bright band (a mirror's sheen)
    u = (x * 0.6 + y * 0.8)
    col = lerp(np.broadcast_to(np.array([160, 210, 255.0]), (S, S, 3)), np.array([200, 170, 255.0]), smooth(-0.8, 0.2, u))
    col = lerp(col, np.array([110, 60, 220.0]), smooth(0.1, 0.9, u))
    band = np.exp(-(((u + 0.15) / 0.09) ** 2))
    col = lerp(col, WHITE, band * 0.75)
    din = ndimage.distance_transform_edt(m)
    bevel = 1 - smooth(1.5 * k, 5 * k, din)
    col = lerp(col, WHITE, bevel * 0.9)
    a = np.where(m, 0.62 + 0.35 * bevel + 0.2 * band, 0)
    out = np.concatenate([col, (np.clip(a, 0, 1) * 255)[..., None]], axis=2)
    out = down(out, k)
    # glint on the sharpest corner
    gx, gy = points[0]
    yy, xx = np.mgrid[0:N, 0:N].astype(float)
    cx, cy = (gx * 0.5 + 0.5) * N, (gy * 0.5 + 0.5) * N
    dx, dy = (xx - cx) / N, (yy - cy) / N
    cross = np.exp(-np.abs(dx) / 0.006) * np.exp(-np.abs(dy) / 0.12) + np.exp(-np.abs(dy) / 0.006) * np.exp(-np.abs(dx) / 0.12)
    cross += np.exp(-((np.hypot(dx, dy) / 0.03) ** 2))
    return to_img(over(out, layer(np.clip(cross, 0, 1), WHITE)))


# ------------------------------------------------------------------ ground: 鏡花水月
def suigetsu(N=1024):
    k = 2
    S = N * k
    x, y = coords(S)
    r = np.hypot(x, y)
    out = np.zeros((S, S, 4))
    # water disc: deep indigo, lighter toward the rim, faint noise
    water_r = 0.78
    w = (r < water_r).astype(float)
    wcol = lerp(np.broadcast_to(np.array([14, 8, 40.0]), (S, S, 3)), np.array([60, 30, 120.0]), smooth(0.0, water_r, r))
    wcol = wcol * (0.92 + 0.1 * field((S, S), 10 * k, seed=8)[..., None])
    out = over(out, np.concatenate([wcol, (w * 0.86 * 255)[..., None]], axis=2))
    # concentric ripples
    rip = sum(np.exp(-(((r - rr) / 0.006) ** 2)) * a for rr, a in ((0.2, 0.25), (0.36, 0.35), (0.52, 0.4), (0.66, 0.45)))
    out = over(out, layer(rip * w, np.array([170, 140, 255.0])))
    # the moon's reflection: a pale disc broken into horizontal slivers that shift sideways
    mx, my, mr = 0.0, 0.08, 0.2
    rows = np.floor((y - my + mr) / 0.034)
    shift = 0.03 * np.sin(rows * 2.1) + 0.015 * np.sin(rows * 5.3)
    md = np.hypot((x - mx - shift) / 1.0, (y - my))
    sliver = (np.abs(((y - my + mr) / 0.034) % 1 - 0.5) < 0.36)
    moon = (md < mr) & sliver
    mglow = ndimage.gaussian_filter(moon.astype(float), 14 * k)
    out = over(out, layer(mglow * 0.8, np.array([200, 180, 255.0])))
    out = over(out, layer(moon.astype(float) * 0.92, np.array([246, 240, 255.0])))
    # rings
    for rr, wdt, col, aa in ((0.8, 0.008, LAVENDER, 1.0), (0.83, 0.003, ORCHID, 0.9), (0.965, 0.006, LAVENDER, 1.0), (0.985, 0.003, ORCHID, 0.8)):
        out = over(out, layer(np.exp(-(((r - rr) / wdt) ** 2)) * aa, col))
    band = ((r > 0.83) & (r < 0.965)).astype(float)
    out = over(out, layer(band * 0.55, np.array([20, 8, 44.0])))
    img = to_img(out)
    d = ImageDraw.Draw(img)
    c = S / 2
    # kanji round the band: 鏡花水月 twice, a five-petal flower between the words
    f = ImageFont.truetype(str(JP_FONT), int(S * 0.055))
    seq = ["鏡", "花", "水", "月", "*", "鏡", "花", "水", "月", "*"]
    rt = S / 2 * 0.897
    for i, ch in enumerate(seq):
        a = -math.pi / 2 + i * 2 * math.pi / len(seq)
        X, Y = c + rt * math.cos(a), c + rt * math.sin(a)
        if ch == "*":
            for p in range(5):
                pa = a + p * 2 * math.pi / 5
                px, py = X + S * 0.016 * math.cos(pa), Y + S * 0.016 * math.sin(pa)
                rr = S * 0.012
                d.ellipse([px - rr, py - rr, px + rr, py + rr], fill=(214, 96, 255, 255))
            rr = S * 0.007
            d.ellipse([X - rr, Y - rr, X + rr, Y + rr], fill=(255, 240, 200, 255))
            continue
        g = Image.new("RGBA", (int(S * 0.1), int(S * 0.1)), (0, 0, 0, 0))
        gd = ImageDraw.Draw(g)
        gd.text((g.size[0] / 2, g.size[1] / 2), ch, font=f, fill=(242, 232, 255, 255), anchor="mm",
                stroke_width=2 * k, stroke_fill=(60, 20, 120, 255))
        g = g.rotate(-math.degrees(a) - 90, resample=Image.BICUBIC)
        img.alpha_composite(g, (int(X - g.size[0] / 2), int(Y - g.size[1] / 2)))
    arr = down(np.asarray(img, float), k)
    bloom = layer(ndimage.gaussian_filter(arr[..., 3] * (arr[..., :3].mean(2) > 150), 6) / 255 * 0.5, ORCHID)
    return to_img(over(bloom, arr))


def ripple(N=512):
    x, y = coords(N)
    r = np.hypot(x, y)
    a = np.exp(-(((r - 0.9) / 0.03) ** 2)) + 0.5 * np.exp(-(((r - 0.82) / 0.02) ** 2))
    col = lerp(np.broadcast_to(LAVENDER, (N, N, 3)), np.array([200, 160, 255.0]), smooth(0.8, 0.95, r))
    return to_img(np.concatenate([col, (np.clip(a, 0, 1) * 255)[..., None]], axis=2))


def mote(N=128):
    x, y = coords(N)
    r = np.hypot(x, y)
    a = np.clip(np.exp(-((r / 0.18) ** 2)) + 0.45 * np.exp(-((r / 0.5) ** 2)), 0, 1)
    col = lerp(np.broadcast_to(WHITE, (N, N, 3)), ORCHID, smooth(0.1, 0.6, r))
    return to_img(np.concatenate([col, (a * 255)[..., None]], axis=2))


def glow(N=256):
    x, y = coords(N)
    r = np.hypot(x, y)
    a = np.clip(1 - r, 0, 1) ** 2.2
    return to_img(layer(a, WHITE))


# ------------------------------------------------------------------ contact sheet
def contact(imgs):
    cell = 300
    names = list(imgs)
    cols = 6
    rows = math.ceil(len(names) / cols)
    sheet = Image.new("RGB", (cell * cols, cell * rows * 2), (0, 0, 0))
    d = ImageDraw.Draw(sheet)
    for half, bg in enumerate(((12, 8, 24), (196, 210, 225))):
        for i, n in enumerate(names):
            X, Y = (i % cols) * cell, (i // cols) * cell + half * cell * rows
            tile = Image.new("RGBA", (cell, cell), bg + (255,))
            im = imgs[n].copy()
            im.thumbnail((cell - 20, cell - 30))
            tile.alpha_composite(im, ((cell - im.size[0]) // 2, 22))
            sheet.paste(tile.convert("RGB"), (X, Y))
            d.text((X + 6, Y + 4), n, fill=(255, 255, 255) if half == 0 else (0, 0, 0))
    return sheet


def main():
    import sys

    OUT.mkdir(parents=True, exist_ok=True)
    makers = {
        "hogyoku": hogyoku,
        "seal": seal,
        "crown": crown,
        "mirror": mirror,
        "streak": streak,
        "glass": lambda: glass([(0.05, -0.92), (0.62, 0.55), (-0.5, 0.78)], 1),
        "glass_b": lambda: glass([(-0.7, -0.75), (0.8, -0.35), (0.35, 0.85), (-0.55, 0.4)], 2),
        "suigetsu": suigetsu,
        "ripple": ripple,
        "mote": mote,
        "glow": glow,
    }
    only = sys.argv[1:]
    made = {}
    for n, fn in makers.items():
        if only and n not in only:
            p = OUT / f"{n}.png"
            if p.exists():
                made[n] = Image.open(p).convert("RGBA")
            continue
        im = fn()
        im.save(OUT / f"{n}.png", optimize=True)
        made[n] = im
        print("wrote", n, im.size)
    contact(made).save(OUT / "_sheet.jpg", quality=90)
    print("sheet", OUT / "_sheet.jpg")


if __name__ == "__main__":
    main()
