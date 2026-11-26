#!/usr/bin/env python3
"""ButterflyDance (Shinobu's aura) textures, made from maths: nothing harvested, nothing stock.

    python tools/auras/butterfly_dance/make_tex.py        -> assets/auras/butterfly_dance/*.png (+ _sheet.png)

Textures (all RGBA, white-or-own-colour + alpha):
  bf_spirit_4x4.png   16-frame flap cycle of a glowing spirit butterfly: stained-glass lattice wings,
                      pale lilac root -> violet -> indigo tip, cyan hindwing edge, white rim, baked halo
  bf_haori_4x4.png    same wings in her haori's pattern: white, black lattice and border, teal tips
  sigil.png           ground sigil: rings, a lattice band like the haori, eight butterflies, wisteria dots
  glow.png            soft radial glow (falloff, never a solid core)
  wisp_4x4.png        16-frame rising ribbon of energy: born thin, swells, curls, frays away
  glint.png           four-point star glint with a soft halo (wing-scale sparkles)
  shard.png           thin diamond flake with a bright edge (the glass petals of the key art)
  ribbon.png          trail strip, UPRIGHT (Roblox runs a trail texture's vertical axis along the trail): white-hot
                      core, halo, a second filament, soft gaps

Grid4x4 flipbooks are row-major (frame 0 top-left), 256 px frames on a 1024 sheet.
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets" / "auras" / "butterfly_dance"
RNG = np.random.default_rng(1717)

FRAME = 256
SS = 4  # supersampling for the wing art


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def lerp3(c0, c1, t):
    c0 = np.asarray(c0, float)
    c1 = np.asarray(c1, float)
    return c0 + (c1 - c0) * t[..., None]


def chaikin(pts, n=4):
    p = np.asarray(pts, float)
    for _ in range(n):
        q = 0.75 * p + 0.25 * np.roll(p, -1, 0)
        r = 0.25 * p + 0.75 * np.roll(p, -1, 0)
        p = np.empty((len(q) * 2, 2))
        p[0::2] = q
        p[1::2] = r
    return p


# ---------------------------------------------------------------- the wing (right side, fully open)
# local wing space: x 0 (body axis) .. 1, y -1 .. 1 (up); the canvas is W x H
WING_W, WING_H = 118 * SS, 236 * SS

FORE = [(0.02, 0.10), (0.10, 0.30), (0.30, 0.56), (0.52, 0.76), (0.74, 0.86), (0.90, 0.84),
        (0.97, 0.74), (0.93, 0.52), (0.80, 0.30), (0.62, 0.10), (0.40, -0.02), (0.14, -0.04)]
HIND = [(0.03, -0.02), (0.30, -0.02), (0.58, -0.08), (0.74, -0.22), (0.76, -0.42), (0.64, -0.60),
        (0.50, -0.70), (0.40, -0.86), (0.30, -0.80), (0.24, -0.62), (0.10, -0.42), (0.03, -0.20)]


def to_px(pts):
    p = np.asarray(pts, float)
    x = p[:, 0] * (WING_W - 1)
    y = (1 - (p[:, 1] + 1) / 2) * (WING_H - 1)
    return list(map(tuple, np.stack([x, y], 1)))


def mask_of(pts):
    im = Image.new("L", (WING_W, WING_H), 0)
    ImageDraw.Draw(im).polygon(to_px(chaikin(pts)), fill=255)
    return np.asarray(im, float) / 255.0


def voronoi_edges(mask, n, seed, root):
    """Stained-glass cells: distance between nearest and second-nearest seed, small = an edge.
    Seeds are denser toward the wing's outer edge, like the haori's lattice."""
    rng = np.random.default_rng(seed)
    ys, xs = np.nonzero(mask > 0.5)
    pick = rng.choice(len(xs), size=n * 6, replace=False)
    px, py = xs[pick].astype(float), ys[pick].astype(float)
    dr = np.hypot(px - root[0], py - root[1])
    keep = np.argsort(-(dr + rng.uniform(0, WING_W * 0.6, len(dr))))[:n]
    sx, sy = px[keep], py[keep]
    yy, xx = np.mgrid[0:WING_H, 0:WING_W].astype(float)
    d = np.stack([np.hypot(xx - x0, yy - y0) for x0, y0 in zip(sx, sy)], 0)
    d.sort(0)
    return d[1] - d[0]


def wing_art(scheme: str) -> np.ndarray:
    fore = mask_of(FORE)
    hind = mask_of(HIND)
    m = np.clip(fore + hind, 0, 1)
    yy, xx = np.mgrid[0:WING_H, 0:WING_W].astype(float)
    root = (0.02 * WING_W, WING_H * 0.5)
    rho = np.hypot((xx - root[0]) / WING_W, (yy - root[1]) / (WING_H * 0.5))
    rho = np.clip(rho / 1.05, 0, 1)

    inside = ndimage.distance_transform_edt(m > 0.5)
    outside = ndimage.distance_transform_edt(m <= 0.5)
    # the seam between fore- and hindwing: a dark line where the forewing overlaps
    fore_in = ndimage.distance_transform_edt(fore > 0.5)
    seam = (hind > 0.5) & (fore_in > 0) & (fore_in < 2.2 * SS)
    seam = seam | ((fore > 0.5) & (ndimage.distance_transform_edt(fore > 0.5) < 2.0 * SS) & (hind > 0.5))

    cells = np.minimum(voronoi_edges(fore, 22, 3, root), voronoi_edges(hind, 16, 5, root))
    vein = 1.0 - smooth(1.2 * SS, 2.6 * SS, cells)
    # radial main veins from the root
    ang = np.arctan2(-(yy - root[1]), xx - root[0])
    radial = np.zeros_like(ang)
    for a0 in (-1.25, -0.8, -0.35, 0.25, 0.62, 0.95, 1.2):
        dist = np.abs(np.sin(ang - a0)) * np.hypot(xx - root[0], yy - root[1])
        radial = np.maximum(radial, (1 - smooth(0.8 * SS, 2.0 * SS, dist)) * smooth(0.06, 0.25, rho))
    vein = np.maximum(vein * smooth(0.12, 0.3, rho), radial * 0.85)
    vein = np.maximum(vein, seam.astype(float))
    rim = 1.0 - smooth(1.6 * SS, 3.2 * SS, inside)

    rgb = np.zeros((WING_H, WING_W, 3))
    a = np.zeros((WING_H, WING_W))
    if scheme == "spirit":
        t = smooth(0.0, 1.0, rho ** 0.9)
        col = lerp3((236, 222, 255), (166, 96, 255), smooth(0.0, 0.45, t))
        col = lerp3(col, (92, 40, 222), smooth(0.5, 1.0, t))
        # cyan on the hindwing's lower edge and the forewing tip's underside, as in the key art
        cyan = np.clip((hind > 0.5) * smooth(0.45, 0.95, rho) + (fore > 0.5) * smooth(0.82, 1.0, rho) * 0.6, 0, 1)
        col = lerp3(col, (96, 226, 255), cyan * 0.85)
        col = lerp3(col, (58, 18, 120), vein * 0.75)
        col = lerp3(col, (226, 248, 255), rim)
        body_a = m * (0.86 - 0.32 * vein * smooth(0.2, 0.6, rho) + 0.14 * rim)
        halo = np.exp(-outside / (7.0 * SS)) * (m <= 0.5) * 0.42
        hcol = lerp3(np.full_like(rho[..., None].repeat(3, -1), 0) + np.array([150, 92, 255.0]),
                     np.array([110, 210, 255.0]), cyan * 0.0 + smooth(0.6, 1.0, rho) * 0.4)
        rgb = col * m[..., None] + hcol * (1 - m[..., None])
        a = np.clip(body_a + halo, 0, 1)
    else:  # haori
        t = smooth(0.25, 1.0, rho)
        col = lerp3((255, 255, 255), (232, 222, 255), smooth(0.0, 0.6, t))
        col = lerp3(col, (70, 196, 182), smooth(0.62, 1.0, t) * 0.9)
        col = lerp3(col, (16, 10, 24), np.clip(vein * 1.1, 0, 1))
        col = lerp3(col, (10, 6, 16), rim)
        halo = np.exp(-outside / (4.0 * SS)) * (m <= 0.5) * 0.22
        rgb = col * m[..., None] + np.array([236, 226, 255.0]) * (1 - m[..., None])
        a = np.clip(m * 0.97 + halo, 0, 1)
    out = np.dstack([np.clip(rgb, 0, 255), a * 255]).astype(np.uint8)
    return out


def body_layer(scheme: str, size: int) -> Image.Image:
    """Body, head and antennae on a full frame canvas (supersampled)."""
    S = size * SS
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx = S / 2
    def Y(v):
        return S / 2 - v * S / 2
    dark = (34, 14, 58, 255) if scheme == "spirit" else (14, 10, 20, 255)
    lite = (200, 170, 255, 255) if scheme == "spirit" else (120, 100, 150, 255)
    w = 0.028 * S
    d.ellipse([cx - w, Y(0.26), cx + w, Y(-0.40)], fill=dark)
    d.ellipse([cx - w * 0.45, Y(0.20), cx + w * 0.45, Y(-0.30)], fill=lite)
    d.ellipse([cx - w * 1.2, Y(0.36), cx + w * 1.2, Y(0.24)], fill=dark)
    for sgn in (-1, 1):
        pts = [(cx + sgn * (0.02 + 0.12 * t * t) * S / 2, Y(0.34 + 0.34 * t)) for t in np.linspace(0, 1, 12)]
        d.line(pts, fill=dark, width=max(2, int(0.006 * S)))
        ex, ey = pts[-1]
        r = 0.012 * S
        d.ellipse([ex - r, ey - r, ex + r, ey + r], fill=lite if scheme == "spirit" else dark)
    return im


def butterfly_flipbook(scheme: str) -> Image.Image:
    wing = Image.fromarray(wing_art(scheme), "RGBA")
    body = body_layer(scheme, FRAME)
    sheet = Image.new("RGBA", (FRAME * 4, FRAME * 4), (0, 0, 0, 0))
    S = FRAME * SS
    half = int(S * 0.46)  # wing reach from the body axis at full open (keeps ~8 % padding)
    wing_full = wing.resize((half, int(half * WING_H / WING_W)), Image.LANCZOS)
    for f in range(16):
        t = f / 16
        # fast downstroke, slower upstroke; angle 0 = flat open, 78 deg = wings up
        tt = t + 0.10 * math.sin(2 * math.pi * t)
        ang = math.radians(78) * (0.5 + 0.5 * math.cos(2 * math.pi * tt))
        s = max(0.10, math.cos(ang))
        lift = 0.035 * math.sin(2 * math.pi * tt)  # the body bobs against the stroke
        frame = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        w = max(2, int(wing_full.width * s))
        right = wing_full.resize((w, wing_full.height), Image.LANCZOS)
        # wings tilted up read darker on their undersides
        shade = 0.80 + 0.20 * s
        r = np.asarray(right, float)
        r[..., :3] *= shade
        right = Image.fromarray(r.clip(0, 255).astype(np.uint8), "RGBA")
        left = right.transpose(Image.FLIP_LEFT_RIGHT)
        top = int(S / 2 - wing_full.height / 2 - lift * S / 2) + int(0.04 * S)
        cx = S // 2
        frame.alpha_composite(right, (cx, top))
        frame.alpha_composite(left, (cx - w, top))
        frame.alpha_composite(body, (0, int(-lift * S / 2)))
        frame = frame.resize((FRAME, FRAME), Image.LANCZOS)
        sheet.alpha_composite(frame, ((f % 4) * FRAME, (f // 4) * FRAME))
    return sheet


# ---------------------------------------------------------------- the ground sigil
def sigil(size=1024) -> Image.Image:
    S = size * 2
    yy, xx = np.mgrid[0:S, 0:S].astype(float)
    cx = cy = (S - 1) / 2
    r = np.hypot(xx - cx, yy - cy) / (S / 2)
    th = np.arctan2(yy - cy, xx - cx)
    a = np.zeros((S, S))

    def ring(r0, w, k=1.0):
        return k * (1 - smooth(w * 0.5, w, np.abs(r - r0)))

    a = np.maximum(a, ring(0.90, 0.010))
    a = np.maximum(a, ring(0.84, 0.006, 0.8))
    a = np.maximum(a, ring(0.60, 0.008, 0.9))
    a = np.maximum(a, ring(0.30, 0.006, 0.7))
    # lattice band between 0.62 and 0.82: the haori's stained-glass cells, wrapped round
    band = (r > 0.62) & (r < 0.82)
    # irregular cells (Voronoi in the band's own polar coordinates, wrapped), like the haori's lattice
    rng = np.random.default_rng(41)
    cols, rows = 30, 3  # jittered grid: even cells, no clumps
    gu, gv = np.meshgrid((np.arange(cols) + 0.5) / cols, (np.arange(rows) + 0.5) / rows)
    su = (gu.ravel() + (gv.ravel() * 2 % 2) * 0.5 / cols + rng.uniform(-0.3, 0.3, cols * rows) / cols) % 1
    sv = gv.ravel() + rng.uniform(-0.25, 0.25, cols * rows) / rows
    n = cols * rows
    u = (th / (2 * np.pi) + 0.5)
    v = np.clip((r - 0.62) / 0.20, 0, 1)
    sub = (slice(None, None, 2), slice(None, None, 2))
    uu, vv = u[sub], v[sub]
    d = []
    for k in range(n):
        du = np.abs(uu - su[k])
        du = np.minimum(du, 1 - du) * 2 * np.pi * 0.72 / 0.20  # same scale as v across the band
        d.append(np.hypot(du, vv - sv[k]))
    d = np.sort(np.stack(d, 0), 0)
    e = d[1] - d[0]
    e = np.asarray(Image.fromarray((np.clip(e, 0, 1) * 255).astype(np.uint8)).resize((S, S), Image.BILINEAR), float) / 255
    lat = 1 - smooth(0.012, 0.03, e)
    a = np.maximum(a, lat * band * 0.8)
    # a faint wash inside each cell, brighter toward the outer ring (stained glass catching light)
    a = np.maximum(a, band * 0.16 * smooth(0.62, 0.82, r))
    # inner wisteria dots on the 0.45 circle
    for k in range(24):
        ang = 2 * np.pi * k / 24
        px, py = cx + np.cos(ang) * 0.45 * S / 2, cy + np.sin(ang) * 0.45 * S / 2
        rr = 0.016 if k % 2 == 0 else 0.010
        a = np.maximum(a, 1 - smooth(rr * 0.6, rr, np.hypot(xx - px, yy - py) / (S / 2)))
    # soft fill inside
    a = np.maximum(a, 0.10 * (1 - smooth(0.0, 0.62, r)))
    img = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "L")
    # eight butterflies (silhouettes) round the 0.72.. no, on the 0.97 rim, heads outward
    bf = Image.fromarray(wing_art("haori")[..., 3], "L")
    wing = bf.resize((int(S * 0.045), int(S * 0.09)), Image.LANCZOS)
    for k in range(8):
        ang = 2 * math.pi * k / 8 + math.pi / 8
        b = Image.new("L", (int(S * 0.1), int(S * 0.1)), 0)
        bx = b.width // 2
        b.paste(wing, (bx, (b.height - wing.height) // 2), wing)
        lw = wing.transpose(Image.FLIP_LEFT_RIGHT)
        b.paste(lw, (bx - wing.width, (b.height - wing.height) // 2), lw)
        b = b.rotate(-math.degrees(ang) - 90, resample=Image.BICUBIC)
        px = int(cx + math.cos(ang) * 0.72 * S / 2 - b.width / 2)
        py = int(cy + math.sin(ang) * 0.72 * S / 2 - b.height / 2)
        img.paste(255, (px, py), b)
    img = img.resize((size, size), Image.LANCZOS)
    a = np.asarray(img, float) / 255
    glow = np.asarray(img.filter(ImageFilter.GaussianBlur(size * 0.012)), float) / 255
    a = np.clip(np.maximum(a, glow * 0.55), 0, 1)
    rgb = np.full((size, size, 3), 255, np.uint8)
    return Image.fromarray(np.dstack([rgb, (a * 255).astype(np.uint8)]), "RGBA")


def glow(size=256) -> Image.Image:
    yy, xx = np.mgrid[0:size, 0:size].astype(float)
    r = np.hypot(xx - (size - 1) / 2, yy - (size - 1) / 2) / (size / 2)
    a = np.clip(np.exp(-(r / 0.42) ** 2) * (1 - smooth(0.82, 0.98, r)), 0, 1)
    rgb = np.full((size, size, 3), 255, np.uint8)
    return Image.fromarray(np.dstack([rgb, (a * 255).astype(np.uint8)]), "RGBA")


def glint(size=128) -> Image.Image:
    yy, xx = np.mgrid[0:size, 0:size].astype(float)
    x = (xx - (size - 1) / 2) / (size / 2)
    y = (yy - (size - 1) / 2) / (size / 2)
    r = np.hypot(x, y)
    spike = np.exp(-np.abs(x) / 0.035) * np.exp(-np.abs(y) / 0.55) + np.exp(-np.abs(y) / 0.035) * np.exp(-np.abs(x) / 0.55)
    diag = (np.exp(-np.abs(x - y) / 0.05) + np.exp(-np.abs(x + y) / 0.05)) * np.exp(-r / 0.22) * 0.35
    core = np.exp(-(r / 0.09) ** 2)
    halo = np.exp(-(r / 0.30) ** 2) * 0.35
    a = np.clip(spike + diag + core + halo, 0, 1) * (1 - smooth(0.85, 0.99, r))
    rgb = np.full((size, size, 3), 255, np.uint8)
    return Image.fromarray(np.dstack([rgb, (a * 255).astype(np.uint8)]), "RGBA")


def shard(size=128) -> Image.Image:
    yy, xx = np.mgrid[0:size, 0:size].astype(float)
    x = (xx - (size - 1) / 2) / (size / 2)
    y = (yy - (size - 1) / 2) / (size / 2)
    # an asymmetric diamond: long upper point, short lower one
    yy2 = np.where(y < 0, y / 0.86, y / 0.42)
    d = np.abs(x) / 0.24 + np.abs(yy2)
    body = 1 - smooth(0.92, 1.0, d)
    edge = (1 - smooth(0.0, 0.10, np.abs(d - 0.93))) * 0.9
    facet = (x > 0) * 0.25
    a = np.clip(body * (0.55 - facet) + edge, 0, 1)
    halo = np.exp(-np.maximum(d - 1, 0) / 0.08) * (d > 1) * 0.3
    a = np.clip(a + halo, 0, 1)
    rgb = np.full((size, size, 3), 255, np.uint8)
    return Image.fromarray(np.dstack([rgb, (a * 255).astype(np.uint8)]), "RGBA")


def ribbon(w=512, h=64) -> Image.Image:
    """Trail strip: U (x) runs ALONG the trail, V (y) across it. A thin white-hot core, a soft halo and a
    faint second filament, broken by a few soft gaps so the ribbon reads as flowing light, not a pipe."""
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    v = (yy - (h - 1) / 2) / (h / 2)
    u = xx / (w - 1)
    core = np.exp(-(v / 0.10) ** 2)
    halo = np.exp(-(v / 0.42) ** 2) * 0.45
    fil = np.exp(-((v - 0.32 - 0.08 * np.sin(u * 2 * np.pi * 3)) / 0.06) ** 2) * 0.5
    gaps = 1 - 0.45 * np.clip(np.sin(u * 2 * np.pi * 5 + 0.7) ** 8, 0, 1)
    a = np.clip((core + halo + fil) * gaps, 0, 1) * (1 - smooth(0.85, 1.0, np.abs(v)))
    rgb = np.full((h, w, 3), 255, np.uint8)
    return Image.fromarray(np.dstack([rgb, (a * 255).astype(np.uint8)]), "RGBA")


def wisp_flipbook() -> Image.Image:
    """A ribbon of energy that rises from the bottom of the frame, swells, curls and frays.
    Coverage follows the skill's template: small at frame 0, peak near frame 4, eroded from ~7."""
    sheet = Image.new("RGBA", (FRAME * 4, FRAME * 4), (0, 0, 0, 0))
    S = FRAME * 2
    yy, xx = np.mgrid[0:S, 0:S].astype(float)
    x = (xx - (S - 1) / 2) / (S / 2)
    y = 1 - yy / (S / 2)  # 0 at the bottom edge? no: y in (-1, 1), up positive
    y = -(yy - (S - 1) / 2) / (S / 2)
    noise = ndimage.gaussian_filter(RNG.standard_normal((S // 8, S // 8)), 2.0)
    noise = np.asarray(Image.fromarray(((noise - noise.min()) / (np.ptp(noise)) * 255).astype(np.uint8)).resize((S, S), Image.BICUBIC), float) / 255
    for f in range(16):
        t = f / 15
        # a flame TONGUE: a broad base that tapers to a curled tip, rising through the frame
        base = -0.92 + 0.55 * smooth(0.25, 1.0, t)           # its bottom lifts off as it burns out
        tip = -0.70 + 1.55 * smooth(0.0, 0.5, t) + 0.12 * t  # its tip shoots up fast, then drifts
        ln = np.maximum(tip - base, 0.05)
        s = np.clip((y - base) / ln, 0, 1)                     # 0 at the base, 1 at the tip
        inside = (y > base) & (y < tip)
        curl = 0.16 * np.sin(np.pi * s * 1.4 - 0.6 - 1.6 * t) * s
        cx = curl + 0.03 * np.sin(9 * y + t * 5) * s
        width = 0.20 * (1 - s) ** 0.8 * (0.35 + 0.65 * smooth(0.0, 0.12, s)) * (1 - 0.35 * t)
        width = np.maximum(width, 0.012)
        dx = np.abs(x - cx)
        core = np.exp(-(dx / (width * 0.42)) ** 2)
        soft = np.exp(-(dx / (width * 1.15)) ** 2) * 0.55
        ends = smooth(0.0, 0.10, s) * (1 - smooth(0.9, 1.0, s))
        fray = smooth(0.45, 1.0, t)
        erode = smooth(0.15 + 0.6 * (1 - fray), 0.35 + 0.6 * (1 - fray), noise * 0.8 + 0.35 * s)
        a = np.clip((core + soft) * ends * inside * (1 - erode * fray), 0, 1)
        a *= 1 - 0.45 * smooth(0.6, 1.0, t)
        a *= (1 - smooth(0.88, 1.0, np.abs(x))) * (1 - smooth(0.9, 1.0, np.abs(y)))
        im = Image.fromarray(np.dstack([np.full((S, S, 3), 255, np.uint8), (a * 255).astype(np.uint8)]), "RGBA")
        im = im.resize((FRAME, FRAME), Image.LANCZOS)
        sheet.alpha_composite(im, ((f % 4) * FRAME, (f // 4) * FRAME))
    return sheet


def contact_sheet(files: dict[str, Image.Image]) -> Image.Image:
    tiles = []
    for name, im in files.items():
        for bg in ((18, 12, 30), (200, 200, 205)):
            base = Image.new("RGBA", im.size, bg + (255,))
            base.alpha_composite(im)
            tiles.append(base.convert("RGB").resize((512, 512), Image.LANCZOS))
    cols = 4
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * 512, rows * 512), (0, 0, 0))
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % cols) * 512, (i // cols) * 512))
    return sheet


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    files = {
        "bf_spirit_4x4.png": butterfly_flipbook("spirit"),
        "bf_haori_4x4.png": butterfly_flipbook("haori"),
        "sigil.png": sigil(),
        "glow.png": glow(),
        "wisp_4x4.png": wisp_flipbook(),
        "glint.png": glint(),
        "shard.png": shard(),
        # Roblox lays a Beam/Trail texture's VERTICAL axis along it: the strip must be drawn upright
        "ribbon.png": ribbon().transpose(Image.Transpose.ROTATE_90),
    }
    for name, im in files.items():
        im.save(OUT / name)
        print("wrote", (OUT / name).relative_to(ROOT), im.size)
    contact_sheet(files).save(OUT / "_sheet.jpg", quality=88)
    print("wrote", (OUT / "_sheet.jpg").relative_to(ROOT))


if __name__ == "__main__":
    main()
