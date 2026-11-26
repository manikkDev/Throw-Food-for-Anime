#!/usr/bin/env python3
"""EmperorThorns (Michael Kaiser, "Emperor Striker") aura textures, made from maths: nothing harvested.

    python tools/auras/emperor_thorns/make_tex.py      -> assets/auras/emperor_thorns/*.png (+ _sheet.jpg)

The look (Blue Lock, Kaiser's own imagery): the BLUE ROSE tattoo with its thorn stem crawling from his neck
down his left arm (the "impossible" flower he swore to become), the thorns that lead to a CROWN (Kaiser =
emperor), and the KAISER IMPACT: a shot so fast it is drawn as a blue lightning streak and a shock ring.
Anime cel style: every solid shape has a thin navy ink line, flat sapphire body, one lighter band, a cyan
rim and a white-hot lip (so it reads on the game's bright 13:12 daylight floor AND at night).

  rose_bloom_4x4.png  16-frame ONE-SHOT: a blue rose seen head-on opens from a bud (frames 0-9), its outer
                      petals loosen and drift off (10-15) while the whole flower fades
  petal_4x4.png       16-frame LOOP: one blue rose petal tumbling (flips over: the back is darker)
  bolt_4x4.png        16-frame LOOP: Kaiser Impact lightning, a new branched bolt each frame (white + alpha:
                      tinted by Color, drawn additive)
  sigil_core.png      ground sigil core: the full blue rose on a thorn wreath and a soft glow pool
  sigil_ring.png      ground sigil ring: gold rings, a thorn band, four crowns with keyholes, ticks
  crown_panel.png     one of eight gold panels standing in a ring above his head: a real 3D crown
  shock_ring.png      Kaiser Impact shock ring: a bright ring with speed streaks (white, tinted)
  glint.png           four-point star glint (white, tinted)
  glow.png            soft radial falloff

Grid4x4 flipbooks are row-major (frame 0 top-left), 256 px frames on a 1024 sheet.
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets" / "auras" / "emperor_thorns"
F = 256  # flipbook frame
SS = 2  # supersampling

INK = np.array([10, 16, 52], float)  # navy ink line
DEEP = np.array([20, 44, 150], float)  # petal base / shadow
BLUE = np.array([38, 96, 232], float)  # sapphire body
LIGHT = np.array([96, 168, 255], float)  # lighter band
CYAN = np.array([150, 222, 255], float)  # rim
HOT = np.array([236, 248, 255], float)  # white-hot lip
GOLD = np.array([246, 204, 96], float)
GOLD_D = np.array([150, 96, 26], float)


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def mix(c0, c1, t):
    c0 = np.asarray(c0, float)
    c1 = np.asarray(c1, float)
    if np.ndim(t) == 0:
        return c0 + (c1 - c0) * t
    return c0 + (c1 - c0) * np.asarray(t)[..., None]


def field(shape, scale, seed, wrap=True):
    n = np.random.default_rng(seed).standard_normal(shape)
    f = ndimage.gaussian_filter(n, scale, mode="wrap" if wrap else "reflect")
    return f / (np.abs(f).max() + 1e-9)


def over(dst, src):
    """Porter-Duff src over dst, float RGBA 0..255 arrays."""
    sa = src[..., 3:4] / 255.0
    da = dst[..., 3:4] / 255.0
    oa = sa + da * (1 - sa)
    oc = (src[..., :3] * sa + dst[..., :3] * da * (1 - sa)) / np.maximum(oa, 1e-6)
    return np.concatenate([oc, oa * 255], axis=-1)


def down(rgba, k):
    """Box-downsample premultiplied, back to straight alpha."""
    if k == 1:
        return rgba
    h, w, _ = rgba.shape
    a = rgba[..., 3:4] / 255.0
    pre = np.concatenate([rgba[..., :3] * a, a], -1)
    pre = pre.reshape(h // k, k, w // k, k, 4).mean(axis=(1, 3))
    col = pre[..., :3] / np.maximum(pre[..., 3:4], 1e-6)
    return np.concatenate([col, pre[..., 3:4] * 255], -1)


def to_img(rgba):
    return Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), "RGBA")


def grid(n):
    """Pixel-centre coords in -1..1 (x right, y UP)."""
    c = (np.arange(n) + 0.5) / n * 2 - 1
    x, y = np.meshgrid(c, -c)
    return x, y


def sheet(frames):
    s = Image.new("RGBA", (F * 4, F * 4), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        s.paste(fr, ((i % 4) * F, (i // 4) * F))
    return s


def glow_layer(x, y, r, colour, alpha, power=2.0):
    d = np.sqrt(x * x + y * y) / r
    a = np.clip(1 - d, 0, 1) ** power * alpha
    out = np.zeros(x.shape + (4,))
    out[..., :3] = colour
    out[..., 3] = a * 255
    return out


# ---------------------------------------------------------------- the rose
def petal(x, y, cx, cy, ang, a, b, px, back=False, lift=1.0, alpha=1.0):
    """One cel-shaded petal. (cx,cy) its centre, ang the outward direction, a radial / b tangential
    half-size (in -1..1 units), px = pixels per unit (for the ink line width). Returns RGBA."""
    ux, uy = math.cos(ang), math.sin(ang)
    dx, dy = x - cx, y - cy
    xr = dx * ux + dy * uy  # radial (out)
    yt = -dx * uy + dy * ux  # tangential
    s = np.clip((xr / a + 1) / 2, 0, 1)  # 0 base .. 1 tip
    beff = b * (0.62 + 0.5 * s)  # wider at the tip
    # notch + soft wave at the tip edge
    notch = 0.10 * np.exp(-((yt / (0.3 * b)) ** 2)) * smooth(0.6, 1.0, s)
    q = np.sqrt((xr / (a * (1 - notch))) ** 2 + (yt / beff) ** 2)
    inside = q < 1
    # approx px to the edge
    dist = (1 - q) * min(a, b) * px
    aa = smooth(-0.8, 0.8, dist)
    # body: base deep -> sapphire -> light band near the tip, cyan rim on the lip, white-hot thin lip
    col = mix(DEEP, BLUE, smooth(0.0, 0.7, s))
    col = mix(col, LIGHT, smooth(0.72, 0.97, s) * 0.6)
    # cupped shading: the side away from "light" (upper-left) is darker
    shade = smooth(-1, 1, -(yt / beff) * 0.6 + (xr / a) * 0.2)
    col = mix(col, DEEP, (1 - shade) * 0.35 * (1 - s))
    rim = (dist < 5 * SS) & (s > 0.45)
    col = np.where(rim[..., None], mix(col, CYAN, 0.85), col)
    lip = (dist < 2.6 * SS) & (s > 0.6)
    col = np.where(lip[..., None], mix(col, HOT, 0.8 * lift), col)
    ink = dist < 1.6 * SS
    col = np.where(ink[..., None], INK, col)
    if back:
        col = mix(col, DEEP * 0.7, 0.45)
    out = np.zeros(x.shape + (4,))
    out[..., :3] = col
    out[..., 3] = np.where(inside, aa, 0) * 255 * alpha
    return out


# (n petals, centre distance, radial half-size, tangential half-size, angle offset) outer -> inner
LAYERS = [
    (6, 0.47, 0.40, 0.36, 0.00),
    (5, 0.33, 0.33, 0.30, 0.31),
    (5, 0.21, 0.25, 0.23, 0.95),
    (4, 0.105, 0.17, 0.155, 0.40),
    (3, 0.04, 0.10, 0.10, 1.70),
]


def rose(n, openness=1.0, spin=0.0, drift=0.0, fade=1.0, scale=1.0, wreath=False):
    """A head-on blue rose on an n x n canvas (supersampled by the caller's n)."""
    x, y = grid(n)
    x, y = x / scale, y / scale
    px = n / 2 * scale
    out = glow_layer(x, y, 1.05, BLUE * 0.9, 0.42 * fade, 1.6)
    o = openness
    for li, (k, d, a, b, off) in enumerate(LAYERS):
        outer = li == 0
        grow = 0.42 + 0.58 * o ** (0.6 + 0.5 * (len(LAYERS) - li) / len(LAYERS))
        dd = d * (0.25 + 0.75 * o) + (drift * (1.6 - li * 0.35) if li < 2 else 0)
        la = 1.0 if li > 1 else max(0.0, 1 - drift * (2.6 if outer else 1.4))
        for j in range(k):
            ang = off + spin * (1 + li * 0.15) + j * 2 * math.pi / k
            cx, cy = dd * math.cos(ang), dd * math.sin(ang)
            out = over(out, petal(x, y, cx, cy, ang, a * grow, b * grow, px, alpha=la * fade))
    # the bud's spiral heart
    r = np.sqrt(x * x + y * y)
    th = np.arctan2(y, x) - spin * 1.8
    heart_r = 0.075 * (0.6 + 0.4 * o)
    spiral = np.mod(th / (2 * math.pi) - np.log(np.maximum(r, 1e-3) / heart_r) * 1.1, 1.0)
    line = (np.abs(spiral - 0.5) > 0.40) & (r < heart_r)
    disc = r < heart_r
    heart = np.zeros(x.shape + (4,))
    heart[..., :3] = np.where(line[..., None], INK, mix(DEEP, BLUE, smooth(heart_r, 0, r)))
    heart[..., 3] = disc * 255 * fade
    out = over(out, heart)
    return out


def rose_bloom():
    frames = []
    for f in range(16):
        if f <= 9:
            o = 0.12 + 0.88 * smooth(0, 9, f)
            drift, fade = 0.0, 1.0
        else:
            o = 1.0
            drift = (f - 9) / 6 * 0.3
            fade = 1 - smooth(11, 15.6, f)
        im = rose(F * SS, o, spin=0.05 * f, drift=drift, fade=fade, scale=0.92)
        frames.append(to_img(down(im, SS)))
    return sheet(frames)


def petal_flip():
    frames = []
    n = F * SS
    x, y = grid(n)
    for f in range(16):
        t = f / 16 * 2 * math.pi
        sx = math.cos(t)
        back = sx < 0
        k = max(abs(sx), 0.08)
        rot = t * 0.5
        c, s = math.cos(rot), math.sin(rot)
        xr = (x * c + y * s) / k
        yr = -x * s + y * c
        im = petal(xr, yr, -0.15, 0.0, 0.0, 0.62, 0.55, n / 2 * k, back=back)
        frames.append(to_img(down(im, SS)))
    return sheet(frames)


# ---------------------------------------------------------------- Kaiser Impact lightning
def bolt_path(rng, p0, p1, rough, depth):
    pts = [np.array(p0, float), np.array(p1, float)]
    for _ in range(depth):
        nxt = [pts[0]]
        for a, b in zip(pts[:-1], pts[1:]):
            m = (a + b) / 2
            d = b - a
            nrm = np.array([-d[1], d[0]])
            m = m + nrm * rng.uniform(-rough, rough)
            nxt += [m, b]
        pts = nxt
        rough *= 0.55
    return pts


def bolt():
    rng = np.random.default_rng(77)
    n = F * SS
    frames = []
    for f in range(16):
        img = Image.new("L", (n, n), 0)
        core = Image.new("L", (n, n), 0)
        dr, dc = ImageDraw.Draw(img), ImageDraw.Draw(core)
        a0 = rng.uniform(-0.35, 0.35)
        p0 = (0.5 + 0.42 * math.sin(a0), 0.06)
        p1 = (0.5 - 0.42 * math.sin(a0) + rng.uniform(-0.1, 0.1), 0.94)
        main = bolt_path(rng, p0, p1, 0.32, 6)
        paths = [(main, 1.0)]
        for _ in range(rng.integers(2, 4)):
            i = rng.integers(6, len(main) - 12)
            s = main[i]
            e = s + np.array([rng.uniform(-0.35, 0.35), rng.uniform(0.12, 0.3)])
            paths.append((bolt_path(rng, s, e, 0.35, 5), 0.55))
        for pts, wgt in paths:
            xy = [(float(p[0] * n), float(p[1] * n)) for p in pts]
            dr.line(xy, fill=int(255 * wgt), width=int(9 * SS * wgt + 2))
            dc.line(xy, fill=255, width=max(2, int(2.6 * SS * wgt)))
        g = np.asarray(img.filter(ImageFilter.GaussianBlur(7 * SS)), float) / 255
        c = np.asarray(core, float) / 255
        a = np.clip(c + g * 0.75, 0, 1)
        rgba = np.zeros((n, n, 4))
        rgba[..., :3] = 255
        rgba[..., 3] = a * 255
        frames.append(to_img(down(rgba, SS)))
    return sheet(frames)


# ---------------------------------------------------------------- the thorn vine
def vine_strip(w=512, h=128, glow=True, fat=1.0):
    """Horizontal tile: a gently waving stem, 4 thorns alternating up/down, one leaf. Pre-coloured."""
    W, H = w * SS, h * SS
    img = np.zeros((H, W, 4))
    xs = np.arange(W) + 0.5
    ys = np.arange(H) + 0.5
    X, Y = np.meshgrid(xs, ys)
    mid = H / 2 + np.sin(X / W * 2 * math.pi) * H * 0.07
    thick = H * 0.085 * fat
    d = np.abs(Y - mid)
    stem = d < thick
    sd = thick - d
    col = np.zeros((H, W, 3))
    col[:] = DEEP
    col = np.where((Y < mid - thick * 0.15)[..., None], BLUE, col)  # lit upper side
    col = np.where(((Y < mid - thick * 0.6) & stem)[..., None], LIGHT, col)
    col = np.where((sd < 1.7 * SS)[..., None], INK, col)
    layer = np.zeros((H, W, 4))
    layer[..., :3] = col
    layer[..., 3] = smooth(-0.8, 0.8, sd) * 255
    if glow:
        g = np.clip(1 - d / (H * 0.36), 0, 1) ** 2 * 0.2
        gl = np.zeros((H, W, 4))
        gl[..., :3] = LIGHT
        gl[..., 3] = g * 255
        img = over(img, gl)
    # thorns (curved triangles, hooked toward +x), and a leaf
    thorns = Image.new("L", (W, H), 0)
    td = ImageDraw.Draw(thorns)
    for i, tx in enumerate((0.1, 0.36, 0.6, 0.86)):
        up = i % 2 == 0
        bx = tx * W
        by = H / 2 + math.sin(tx * 2 * math.pi) * H * 0.07
        sgn = -1 if up else 1
        base_w = H * 0.13 * fat ** 0.5
        tip = (bx + H * 0.16, by + sgn * H * 0.40 * min(fat, 1.15))
        poly = [(bx - base_w, by), (bx + base_w * 0.6, by), tip]
        td.polygon(poly, fill=255)
    tm = np.asarray(thorns, float) / 255 > 0.5
    tdist = ndimage.distance_transform_edt(tm)
    tcol = np.zeros((H, W, 3))
    tcol[:] = DEEP
    tcol = np.where((tdist > 3 * SS)[..., None], BLUE, tcol)
    tcol = np.where((tdist < 1.6 * SS)[..., None], INK, tcol)
    tl = np.zeros((H, W, 4))
    tl[..., :3] = tcol
    tl[..., 3] = tm * 255
    img = over(img, tl)
    # leaf (a pointed ellipse on a short stalk) at x 0.48, below
    lx, ly = 0.48 * W, H / 2 + math.sin(0.48 * 2 * math.pi) * H * 0.07
    ang = math.radians(28)
    cx, cy = lx + math.cos(ang) * H * 0.2, ly + math.sin(ang) * H * 0.2
    dx, dy = X - cx, Y - cy
    xr = dx * math.cos(ang) + dy * math.sin(ang)
    yr = -dx * math.sin(ang) + dy * math.cos(ang)
    L, Wl = H * 0.2, H * 0.1
    q = (np.abs(xr) / L) ** 1.0 + (np.abs(yr) / (Wl * (1 - (xr / L) ** 2).clip(0) ** 0.5 + 1e-3)) ** 2
    leaf = (q < 1) & (np.abs(xr) < L)
    ld = ndimage.distance_transform_edt(leaf)
    lcol = np.zeros((H, W, 3))
    lcol[:] = DEEP
    lcol = np.where((yr < 0)[..., None], BLUE, lcol)
    lcol = np.where((np.abs(yr) < 1.0 * SS)[..., None], INK, lcol)  # midrib
    lcol = np.where((ld < 1.6 * SS)[..., None], INK, lcol)
    ll = np.zeros((H, W, 4))
    ll[..., :3] = lcol
    ll[..., 3] = leaf * 255
    img = over(img, ll)
    img = over(img, layer)
    return down(img, SS)


def polar_map(strip, size, r0, r1, repeats, ss=SS):
    """Wrap a horizontal strip (H x W x 4) round an annulus r0..r1 (fractions of the half-size)."""
    n = size * ss
    x, y = grid(n)
    r = np.sqrt(x * x + y * y)
    th = (np.arctan2(y, x) / (2 * math.pi)) % 1.0
    H, W, _ = strip.shape
    u = (th * repeats % 1.0) * (W - 1)
    v = (r - r0) / (r1 - r0) * (H - 1)
    inside = (v >= 0) & (v <= H - 1)
    vi = np.clip(v, 0, H - 1)
    out = np.zeros((n, n, 4))
    for ch in range(4):
        out[..., ch] = ndimage.map_coordinates(strip[..., ch], [vi, u], order=1, mode="nearest")
    out[..., 3] *= inside
    return down(out, ss)


def crown(cx, cy, s, n, x, y):
    """A small gold crown with a keyhole, upright at (cx,cy) (unit coords), height ~s. RGBA."""
    img = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(img)

    def P(u, v):
        return ((cx + u * s + 1) / 2 * n, (1 - (cy + v * s)) / 2 * n)

    body = [P(-0.5, -0.35), P(0.5, -0.35), P(0.55, 0.3), P(0.28, 0.02), P(0.0, 0.45), P(-0.28, 0.02), P(-0.55, 0.3)]
    d.polygon(body, fill=255)
    for u, v in ((-0.55, 0.36), (0.0, 0.52), (0.55, 0.36)):
        a, b = P(u - 0.07, v + 0.07), P(u + 0.07, v - 0.07)
        d.ellipse([a[0], a[1], b[0], b[1]], fill=255)
    m = np.asarray(img, float) / 255 > 0.5
    hole = Image.new("L", (n, n), 0)
    hd = ImageDraw.Draw(hole)
    a, b = P(-0.08, -0.02), P(0.08, -0.16)
    hd.ellipse([a[0], a[1], b[0], b[1]], fill=255)
    hd.polygon([P(-0.045, -0.12), P(0.045, -0.12), P(0.07, -0.3), P(-0.07, -0.3)], fill=255)
    hm = np.asarray(hole, float) / 255 > 0.5
    dist = ndimage.distance_transform_edt(m)
    col = np.zeros((n, n, 3))
    col[:] = GOLD
    col = np.where((y > cy + 0.05 * s)[..., None] & (dist > 4 * SS)[..., None], mix(GOLD, HOT, 0.45), col)
    col = np.where((dist < 2.2 * SS)[..., None], GOLD_D * 0.6, col)
    col = np.where(hm[..., None], INK, col)
    out = np.zeros((n, n, 4))
    out[..., :3] = col
    out[..., 3] = m * 255
    return out


def ring_line(x, y, r, w, colour, alpha=1.0):
    d = np.abs(np.sqrt(x * x + y * y) - r)
    out = np.zeros(x.shape + (4,))
    out[..., :3] = colour
    out[..., 3] = smooth(w, w * 0.5, d) * 255 * alpha
    return out


def sigil_core(size=1024):
    n = size * SS
    x, y = grid(n)
    out = glow_layer(x, y, 1.0, BLUE, 0.55, 1.3)
    strip = vine_strip(1024, 128, glow=False)
    wreath = polar_map(strip, size, 0.70, 0.93, 5, ss=1)
    big = np.zeros((n, n, 4))
    # upsample wreath to n for compositing (nearest is fine at SS 2, downsampled again below)
    wreath_up = np.kron(wreath, np.ones((SS, SS, 1)))
    big = over(big, wreath_up)
    out = over(out, big)
    out = over(out, rose(n, 1.0, spin=0.2, scale=0.66))
    return to_img(down(out, SS))


def sigil_ring(size=1024):
    n = size * SS
    x, y = grid(n)
    out = np.zeros((n, n, 4))
    out = over(out, ring_line(x, y, 0.80, 0.075, BLUE, 0.28))  # soft band
    strip = vine_strip(1024, 128, glow=False)
    band = np.kron(polar_map(strip, size, 0.74, 0.88, 7, ss=1), np.ones((SS, SS, 1)))
    out = over(out, band)
    for r, w in ((0.955, 0.012), (0.935, 0.005), (0.70, 0.010)):
        out = over(out, ring_line(x, y, r, w + 0.006, INK))
        out = over(out, ring_line(x, y, r, w, GOLD))
    # ticks between the outer gold rings
    th = np.arctan2(y, x)
    r = np.sqrt(x * x + y * y)
    tick = (np.abs(((th / (2 * math.pi) * 96) % 1.0) - 0.5) > 0.44) & (r > 0.94) & (r < 0.955)
    t = np.zeros((n, n, 4))
    t[..., :3] = GOLD
    t[..., 3] = tick * 255
    out = over(out, t)
    # four crowns, upright as seen from the front of the stand (the hero faces -Z; the sigil is
    # read from the camera, so draw them upright on the image and let the ring turn)
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        cx, cy = 0.81 * math.cos(a), 0.81 * math.sin(a)
        disc = glow_layer(x - cx, y - cy, 0.13, INK, 0.0)
        bg = np.zeros((n, n, 4))
        dd = np.sqrt((x - cx) ** 2 + (y - cy) ** 2)
        bg[..., :3] = DEEP
        bg[..., 3] = smooth(0.1, 0.095, dd) * 255
        out = over(out, bg)
        out = over(out, ring_line(x - cx, y - cy, 0.1, 0.008, GOLD))
        out = over(out, crown(cx, cy - 0.005, 0.14, n, x, y))
        del disc
    return to_img(down(out, SS))


def crown_panel(w=256, h=320):
    """One of eight panels standing in a circle above his head (a 3D crown): a gold band at the
    bottom set with a blue gem, a pointed prong rising from it with a ball tip, thorn-hook flourishes.
    Panels tile edge to edge (the band runs off both sides)."""
    W, H = w * SS, h * SS
    img = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(img)
    band_top, band_bot = H * 0.70, H * 0.97
    d.rectangle([0, band_top, W, band_bot], fill=255)
    # the prong: a tall pointed arch from the band
    cx = W / 2
    d.polygon([(cx - W * 0.30, band_top + 2), (cx, H * 0.16), (cx + W * 0.30, band_top + 2)], fill=255)
    # concave sides: cut two circles out
    cut = Image.new("L", (W, H), 0)
    cd = ImageDraw.Draw(cut)
    for sx in (-1, 1):
        ccx, ccy, r = cx + sx * W * 0.47, H * 0.38, W * 0.36
        cd.ellipse([ccx - r, ccy - r, ccx + r, ccy + r], fill=255)
    # ball tip
    r = W * 0.075
    d.ellipse([cx - r, H * 0.16 - r * 1.6, cx + r, H * 0.16 + r * 0.4], fill=255)
    # small half-prongs at the panel edges (they meet the neighbour's)
    for ex in (0, W):
        d.polygon([(ex - W * 0.14, band_top + 2), (ex, H * 0.47), (ex + W * 0.14, band_top + 2)], fill=255)
    m = (np.asarray(img, float) / 255 > 0.5) & ~(np.asarray(cut, float) / 255 > 0.5)
    m[int(H * 0.15 - r * 1.6) : int(H * 0.16 + r * 0.4) + 1, int(cx - r) : int(cx + r) + 1] |= (
        np.asarray(img, float)[int(H * 0.15 - r * 1.6) : int(H * 0.16 + r * 0.4) + 1, int(cx - r) : int(cx + r) + 1] > 127
    )
    dist = ndimage.distance_transform_edt(np.pad(m, ((0, 0), (0, 0)), mode="edge"))
    X, Y = np.meshgrid(np.arange(W) + 0.5, np.arange(H) + 0.5)
    col = np.zeros((H, W, 3))
    col[:] = GOLD
    col = np.where((X < cx)[..., None] & (Y < band_top)[..., None], mix(GOLD, HOT, 0.45), col)  # lit side
    col = np.where((Y > band_top + H * 0.035)[..., None] & (Y < band_bot - H * 0.035)[..., None],
                   mix(GOLD, GOLD_D, 0.35), col)  # band inset
    col = np.where((dist < 2.4 * SS)[..., None], GOLD_D * 0.55, col)
    # ink line along the band edges too
    edge_band = (np.abs(Y - band_top) < 1.6 * SS) | (np.abs(Y - band_bot) < 1.6 * SS)
    col = np.where(edge_band[..., None], GOLD_D * 0.55, col)
    out = np.zeros((H, W, 4))
    out[..., :3] = col
    out[..., 3] = m * 255
    # the gem on the band and a small one under the ball
    for gx, gy, gr in ((cx, (band_top + band_bot) / 2, H * 0.085), (cx, H * 0.40, H * 0.045)):
        dd = np.sqrt((X - gx) ** 2 + ((Y - gy) * 1.15) ** 2)
        g = np.zeros((H, W, 4))
        c = mix(DEEP, BLUE, smooth(gr, gr * 0.3, dd))
        c = np.where(((X - gx) < -gr * 0.15)[..., None] & ((Y - gy) < -gr * 0.15)[..., None] & (dd < gr * 0.55)[..., None], CYAN, c)
        c = np.where((dd > gr - 1.8 * SS)[..., None], INK, c)
        g[..., :3] = c
        g[..., 3] = smooth(gr, gr - 1.0, dd) * 255
        out = over(out, g)
    return to_img(down(out, SS))


# ---------------------------------------------------------------- white (tinted) helpers
def shock_ring(size=512):
    n = size * SS
    x, y = grid(n)
    r = np.sqrt(x * x + y * y)
    th = np.arctan2(y, x)
    ring = np.exp(-(((r - 0.82) / 0.035) ** 2))
    inner = np.clip((r - 0.35) / 0.47, 0, 1) ** 3 * (r < 0.82) * 0.55
    streak_n = field((1, 720), 2.0, 91)[0]
    idx = ((th / (2 * math.pi) % 1.0) * 719).astype(int)
    streak = np.clip(streak_n[idx] * 2.2, 0, 1) * np.clip((r - 0.45) / 0.37, 0, 1) * (r < 0.9) * 0.7
    a = np.clip(ring + inner * 0.6 + streak * 0.6, 0, 1)
    rgba = np.zeros((n, n, 4))
    rgba[..., :3] = 255
    rgba[..., 3] = a * 255
    return to_img(down(rgba, SS))


def glint(size=128):
    n = size * SS
    x, y = grid(n)
    ax, ay = np.abs(x), np.abs(y)
    star = np.clip(1 - (ax * 9 + ay * 1.0), 0, 1) ** 2 + np.clip(1 - (ay * 9 + ax * 1.0), 0, 1) ** 2
    d = np.sqrt(x * x + y * y)
    core = np.clip(1 - d / 0.22, 0, 1) ** 1.5
    halo = np.clip(1 - d, 0, 1) ** 3 * 0.35
    a = np.clip(star + core + halo, 0, 1)
    rgba = np.zeros((n, n, 4))
    rgba[..., :3] = 255
    rgba[..., 3] = a * 255
    return to_img(down(rgba, SS))


def glow(size=256):
    x, y = grid(size)
    d = np.sqrt(x * x + y * y)
    a = np.clip(1 - d, 0, 1) ** 2.2
    rgba = np.zeros((size, size, 4))
    rgba[..., :3] = 255
    rgba[..., 3] = a * 255
    return to_img(rgba)


def contact_sheet(files):
    tiles = []
    for name, im in files.items():
        t = im.copy()
        t.thumbnail((320, 320))
        for bg in ((18, 20, 34), (205, 210, 225)):
            b = Image.new("RGB", (330, 330), bg)
            b.paste(t, ((330 - t.width) // 2, (330 - t.height) // 2), t)
            ImageDraw.Draw(b).text((6, 4), name, fill=(255, 80, 80))
            tiles.append(b)
    cols = 6
    rows = (len(tiles) + cols - 1) // cols
    s = Image.new("RGB", (330 * cols, 330 * rows), (0, 0, 0))
    for i, t in enumerate(tiles):
        s.paste(t, ((i % cols) * 330, (i // cols) * 330))
    return s


def main():
    import sys

    OUT.mkdir(parents=True, exist_ok=True)
    only = set(sys.argv[1:])
    makers = {
        "rose_bloom_4x4": rose_bloom,
        "petal_4x4": petal_flip,
        "bolt_4x4": bolt,
        "sigil_core": sigil_core,
        "sigil_ring": sigil_ring,
        "crown_panel": crown_panel,
        "shock_ring": shock_ring,
        "glint": glint,
        "glow": glow,
    }
    files = {}
    for k, mk in makers.items():
        if only and k not in only:
            p = OUT / f"{k}.png"
            if p.exists():
                files[k] = Image.open(p).convert("RGBA")
            continue
        files[k] = mk()
    for k, im in files.items():
        if only and k not in only:
            continue
        im.save(OUT / f"{k}.png")
        print("wrote", k, im.size)
    contact_sheet(files).save(OUT / "_sheet.jpg", quality=88)
    print("wrote _sheet.jpg")


if __name__ == "__main__":
    main()
