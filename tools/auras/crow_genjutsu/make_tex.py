#!/usr/bin/env python3
"""CrowGenjutsu (Itachi Uchiha, "Crow Illusionist") aura textures, made from maths: nothing harvested.

    python tools/auras/crow_genjutsu/make_tex.py      -> assets/auras/crow_genjutsu/*.png (+ _sheet.jpg)

The look (from the owner's two key-art references): ink-black shapes with a crimson rim, never a glow
over the black (a dark aura drawn additive reads as red candy floss). Every dark texture is PRE-COLOURED
RGBA (black core, dark-red band, crimson rim, a faint crimson halo) and is drawn with Color white,
LightEmission 0, LightInfluence 0, so what is painted here is what shows.

  amaterasu_4x4.png  16-frame LOOP of black flame tongues (Amaterasu): three tongues that lick and sway,
                     seamless (the noise scrolls through one vertical period)
  inksmoke_4x4.png   16-frame ONE-SHOT ink puff: born small, billows (peak ~0.3), erodes into wisps, gone
  crow_4x4.png       16-frame flap LOOP of a crow seen from the front: fingered primaries, fan tail,
                     beak, two sharingan-red eyes; wings fold on the upstroke
  feather_4x4.png    16-frame LOOP of a black feather turning about its shaft (crimson vane edge)
  mangekyo.png       ground sigil core: Itachi's three-bladed pinwheel on a red iris, black limbal ring
  tomoe_ring.png     ground sigil ring: three tomoe in a band, fine ticks, thin rings (turns the other way)
  ember.png          hot crimson spark, white core + soft halo (tinted by Color, additive, tiny)
  glow.png           soft radial falloff (never a solid core)

Grid4x4 flipbooks are row-major (frame 0 top-left), 256 px frames on a 1024 sheet.
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets" / "auras" / "crow_genjutsu"
RNG = np.random.default_rng(4919)
F = 256  # frame size

INK = np.array([9, 5, 9], float)  # the black: a hair of red in it
DEEP = np.array([70, 6, 14], float)  # dark-red band inside the rim
CRIMSON = np.array([214, 18, 34], float)  # the rim
HOT = np.array([255, 70, 70], float)  # the thinnest outer edge of the rim


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def field(shape, scale, wrap=True, seed=None):
    """Smooth random field in -1..1 (a gaussian-filtered white noise), periodic if wrap."""
    rng = np.random.default_rng(seed) if seed is not None else RNG
    n = rng.standard_normal(shape)
    f = ndimage.gaussian_filter(n, scale, mode="wrap" if wrap else "reflect")
    return f / (np.abs(f).max() + 1e-9)


def fbm(shape, scales, weights, seed):
    out = np.zeros(shape)
    for i, (s, w) in enumerate(zip(scales, weights)):
        out += w * field(shape, s, seed=seed + i)
    return out / sum(weights)


def ink_colour(mask, rim_px=2.2, band_px=7.0, halo_px=5.0, halo_a=0.32, hot=True):
    """Pre-colour a 0..1 coverage mask: crimson rim, dark-red band, ink core, faint crimson halo outside.
    Returns float RGBA 0..255."""
    m = np.clip(mask, 0, 1)
    solid = m > 0.5
    din = ndimage.distance_transform_edt(solid)  # px inside the edge
    dout = ndimage.distance_transform_edt(~solid)  # px outside the edge
    rim = 1 - smooth(rim_px * 0.5, rim_px, din)
    band = 1 - smooth(rim_px, band_px, din)
    col = INK[None, None, :] * np.ones(m.shape + (3,))
    col = col + (DEEP - INK)[None, None, :] * band[..., None]
    col = col + (CRIMSON - col) * rim[..., None]
    if hot:
        edge = 1 - smooth(0.0, rim_px * 0.45, din)
        col = col + (HOT - col) * (edge * 0.6)[..., None]
    halo = (1 - smooth(0, halo_px, dout)) * halo_a * (~solid)
    a = np.where(solid, np.clip(m * 1.0, 0, 1), 0) * 255
    # antialiased edge: keep the mask's soft alpha at the boundary
    a = np.maximum(a, np.clip(m, 0, 1) * 255 * (m < 0.5) * 0)  # (hard cel edge, mask already AA'd below)
    a = np.maximum(a, halo * 255)
    col = np.where(solid[..., None], col, CRIMSON[None, None, :] * np.ones_like(col))
    return np.dstack([col, a])


def aa_mask(hi, k):
    """Downsample a supersampled boolean/float mask by k with a box filter (antialias)."""
    h, w = hi.shape
    return hi.reshape(h // k, k, w // k, k).mean(axis=(1, 3))


def to_img(rgba):
    return Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), "RGBA")


def sheet(frames):
    s = Image.new("RGBA", (F * 4, F * 4), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        s.paste(fr, ((i % 4) * F, (i // 4) * F))
    return s


def cel(mask_float, lo=0.5):
    """Hard cel edge from a smooth field, antialiased over ~1 px."""
    return smooth(lo - 0.035, lo + 0.035, mask_float)


def colour_from_float(mask_float, **kw):
    """ink_colour expects a boolean-ish mask; feed the cel'd mask and blend alpha at the AA edge."""
    m = cel(mask_float)
    rgba = ink_colour(m, **kw)
    # restore the antialiased boundary inside the hard edge
    edge = (m > 0.02) & (m < 0.98)
    rgba[..., 3] = np.where(edge & (m >= 0.5), m * 255, rgba[..., 3])
    rgba[..., 3] = np.where(edge & (m < 0.5), np.maximum(rgba[..., 3], m * 255), rgba[..., 3])
    return rgba


# ------------------------------------------------------------------ amaterasu: black flame tongues, loop
def amaterasu():
    """Classic cel fire: a heat gradient (hot at the foot) shaped by a narrowing envelope, plus turbulence
    that scrolls UP through one seamless period over the loop. The threshold cuts licks and detached
    tongues near the top, the way anime fire breaks up."""
    H = F * 2  # vertical noise period; scrolled through once over 16 frames -> seamless loop
    W = F
    # noise stretched VERTICALLY (sigma y > x): it breaks the body into upright tongues, not round lumps
    n1 = fbm((H, W), [(26, 9), (12, 4.5)], [1.0, 0.55], seed=11)
    n2 = fbm((H, W), [(9, 3), (4, 1.6)], [1.0, 0.5], seed=21)
    warp = field((H, W), 20, seed=31)
    y = np.linspace(0, 1, F)[:, None] * np.ones((1, F))  # 0 top .. 1 bottom
    x = np.linspace(-1, 1, F)[None, :] * np.ones((F, 1))
    frames = []
    for f in range(16):
        ph = f / 16
        off = int(round(ph * H))
        rows = (np.arange(F) + off) % H
        # domain warp: sideways sway that grows toward the top
        w = warp[rows][:, :]
        xs = x + 0.22 * w * (1 - y) ** 1.3
        cols = np.clip(((xs + 1) / 2 * (W - 1)).astype(int), 0, W - 1)
        a = n1[rows[:, None], cols]
        b = n2[(rows * 2 % H)[:, None], cols]  # finer noise scrolls twice as fast
        width = 0.08 + 0.60 * y ** 1.25
        env = 1 - (np.abs(xs) / width) ** 1.6
        heat = (y ** 1.15) * 1.25
        dens = heat * env + 0.62 * a + 0.24 * b - 0.40
        # round the foot (a hard flat bottom shows the moment a flame lifts off the ground) and the sides
        dens -= 1.5 * smooth(0.78, 0.96, y + 0.22 * (xs / width) ** 2)  # elliptic foot: corners go first
        dens -= 0.9 * smooth(0.82, 0.98, np.abs(x))
        D = dens * 2.2 + 0.5
        rgba = colour_from_float(D, rim_px=2.6, band_px=9, halo_px=6, halo_a=0.34)
        # 3-band cel fire, measured in px from the outer edge: hot keyline, a CRIMSON band fading to dark
        # red, then the black core. Black-on-black vanished against his robe in Studio; the crimson band
        # is what reads, the black core is what makes it Amaterasu.
        solid = D > 0.5
        din = ndimage.distance_transform_edt(solid)
        t = smooth(3.0, 13.0, din)[..., None]  # 0 at the rim .. 1 deep inside
        band = np.array([205, 18, 32])[None, None, :] * (1 - t) + np.array([80, 5, 14])[None, None, :] * t
        core_t = smooth(10.0, 17.0, din)[..., None]
        col = band * (1 - core_t) + INK[None, None, :] * core_t
        keyline = (1 - smooth(1.2, 2.6, din))[..., None]
        col = col * (1 - keyline) + HOT[None, None, :] * keyline
        rgba[..., :3] = np.where(solid[..., None], col, rgba[..., :3])
        # inner licks: the contour of the denser core drawn as a crimson line inside the black,
        # the second cel layer that gives anime fire its depth
        core = (D - 0.85) > 0
        core = ndimage.binary_opening(core, iterations=2)
        line = core & ~ndimage.binary_erosion(core, iterations=2)
        line &= ndimage.binary_erosion(solid, iterations=8)  # never on the outer rim
        lf = ndimage.gaussian_filter(line.astype(float), 0.6)
        lf = np.clip(lf * 1.6, 0, 1)[..., None]
        rgba[..., :3] = rgba[..., :3] * (1 - lf) + np.array([215, 24, 40])[None, None, :] * lf
        frames.append(to_img(rgba))
    return sheet(frames)


# ------------------------------------------------------------------ inksmoke: one-shot billow and erode
def inksmoke():
    N = F
    yy, xx = np.mgrid[-1:1:N * 1j, -1:1:N * 1j]
    big = fbm((N, N), [14, 7], [1.0, 0.5], seed=31)
    fine = fbm((N, N), [4, 2], [1.0, 0.5], seed=41)
    frames = []
    for f in range(16):
        t = f / 15
        R = 0.18 + 0.58 * smooth(0.0, 0.45, t)
        # warp: billows drift up and curl out as it ages
        sh = int(t * 18)
        b = np.roll(big, -sh, axis=0)
        r = np.sqrt((xx * (1 + 0.15 * t)) ** 2 + ((yy + 0.10 * t) * 1.05) ** 2)
        base = 1 - r / R
        dens = base + 0.42 * b + 0.18 * fine
        th = 0.0 + 0.55 * smooth(0.32, 1.0, t)  # erode from ~0.32, gone by 1
        dens = dens - th
        if t > 0.92:
            dens -= 1
        frames.append(to_img(colour_from_float(dens * 1.4 + 0.5, rim_px=2.2, band_px=8, halo_px=5, halo_a=0.26)))
    return sheet(frames)


# ------------------------------------------------------------------ crow: front-view flap loop
def crow_mask(flap, fold, k=4):
    """flap: wing angle in degrees (+ up), fold: 0 open .. 1 folded (upstroke). Supersampled k."""
    S = F * k
    im = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(im)
    cx, cy = S / 2, S * 0.53
    u = S / 256.0

    def P(x, y):
        return (cx + x * u, cy - y * u)

    # tail fan (below the body), 7 feathers with rounded tips
    for i in range(7):
        a = math.radians(-90 + (i - 3) * 9)
        L = 40 + (3 - abs(i - 3)) * 3
        tx, ty = 0 + math.cos(a) * L, -8 + math.sin(a) * L
        nx, ny = -math.sin(a) * 4.2, math.cos(a) * 4.2
        d.polygon([P(-3 + nx * 0.4, -10), P(3, -10), P(tx + nx, ty + ny), P(tx, ty - 2), P(tx - nx, ty - ny)], fill=255)
        d.ellipse([P(tx - 4, ty + 4)[0], P(tx - 4, ty + 4)[1], P(tx + 4, ty - 4)[0], P(tx + 4, ty - 4)[1]], fill=255)
    # body
    d.ellipse([P(-15, 26)[0], P(-15, 26)[1], P(15, -22)[0], P(15, -22)[1]], fill=255)
    # head + beak (pointing down-forward, seen nearly head-on)
    d.ellipse([P(-11, 44)[0], P(-11, 44)[1], P(11, 22)[0], P(11, 22)[1]], fill=255)
    d.polygon([P(-5, 28), P(5, 28), P(0, 13)], fill=255)

    # one wing in its own frame (x outward), then mirror
    def wing(sign):
        span = 1 - 0.38 * fold
        ang = math.radians(flap)
        ca, sa = math.cos(ang), math.sin(ang)

        def W(x, y):  # wing-local -> body: rotate about the shoulder, mirror by sign
            x *= span
            rx, ry = x * ca - y * sa, x * sa + y * ca
            return P(sign * (9 + rx), 14 + ry)

        # arm / coverts: leading edge from shoulder to wrist, scalloped trailing edge of secondaries
        lead = [(0, 6), (22, 12), (46, 14), (62, 12)]
        trail = []
        for i in range(8):
            xx = 62 - i * 8
            trail.append((xx, -16 - 6 * math.sin(i * 0.9) * 0.4 - (8 if i in (1, 3, 5) else 4)))
        trail.append((0, -12))
        d.polygon([W(x, y) for x, y in lead + trail], fill=255)
        # secondaries: rounded feather tips along the trailing edge
        for i in range(7):
            xx = 58 - i * 8
            y0 = -18 - (3 if i % 2 else 0)
            q = [W(xx - 4, y0 + 2), W(xx + 3, y0 + 2), W(xx + 2.5, y0 - 8), W(xx - 1, y0 - 10), W(xx - 4, y0 - 7)]
            d.polygon(q, fill=255)
        # primaries: the crow's "fingers", separated, fanning from the wrist
        for i in range(6):
            fa = math.radians(8 - i * 13 - fold * 18)
            L = (54 - i * 3.5) * (1 - 0.25 * fold)
            bx, by = 58 - i * 2.5, 6 - i * 4
            ex, ey = bx + math.cos(fa) * L, by + math.sin(fa) * L
            nx, ny = -math.sin(fa), math.cos(fa)
            wdt = 5.5 - i * 0.25
            pts = [(bx - nx * wdt, by - ny * wdt), (bx + nx * wdt, by + ny * wdt),
                   (ex + nx * wdt * 0.55 - math.cos(fa) * 4, ey + ny * wdt * 0.55 - math.sin(fa) * 4),
                   (ex, ey), (ex - nx * wdt * 0.6, ey - ny * wdt * 0.6)]
            d.polygon([W(x, y) for x, y in pts], fill=255)

    wing(1)
    wing(-1)
    return aa_mask(np.asarray(im, float) / 255.0, k)


def crow():
    frames = []
    for f in range(16):
        ph = f / 16 * 2 * math.pi
        flap = 34 * math.cos(ph) - 4  # +30 (up) .. -38 (down)
        # flap falls over ph 0..pi (downstroke, wings spread) and rises over pi..2pi (upstroke, folded)
        fold = smooth(0.0, 1.0, np.array(0.5 - 0.5 * math.sin(ph)))
        fold = float(fold) * 0.85
        m = crow_mask(flap, fold)
        rgba = ink_colour(m > 0.5, rim_px=1.8, band_px=4.5, halo_px=5, halo_a=0.38)
        a = rgba[..., 3]
        edge = (m > 0.02) & (m < 0.98)
        a[:] = np.where(edge, np.maximum(a * (m >= 0.5), np.maximum(a, m * 255)), a)
        # feather separation: faint darker-red lines along primaries come from the gaps; eyes: two red dots
        yy, xx = np.mgrid[0:F, 0:F]
        cx, cy = F / 2, F * 0.53
        for ex in (-4.6, 4.6):
            r = np.hypot(xx - (cx + ex), yy - (cy - 34))
            e = 1 - smooth(1.4, 2.6, r)
            rgba[..., 0] = rgba[..., 0] * (1 - e) + 255 * e
            rgba[..., 1] = rgba[..., 1] * (1 - e) + 30 * e
            rgba[..., 2] = rgba[..., 2] * (1 - e) + 40 * e
        frames.append(to_img(rgba))
    return sheet(frames)


# ------------------------------------------------------------------ feather: turning about its shaft
def feather():
    k = 4
    S = F * k
    frames = []
    for f in range(16):
        ph = f / 16 * 2 * math.pi
        wscale = math.cos(ph)  # vane width as it turns (negative = the other face)
        im = Image.new("L", (S, S), 0)
        d = ImageDraw.Draw(im)
        u = S / 256
        cx, cy = S / 2, S / 2
        L = 112
        pts_l, pts_r = [], []
        for i in range(61):
            s = i / 60  # 0 tip .. 1 base of the vane
            y = -L + s * 1.62 * L
            bend = 12 * math.sin(s * math.pi) - 5  # curved shaft
            w = 34 * math.sin(min(1, s * 1.08) * math.pi) ** 0.6 * (1 - 0.3 * s)
            w *= abs(wscale) * 0.92 + 0.08
            # ragged barbs: split the vane in two places on each side
            nl = 0.55 if (abs(s - 0.42) < 0.025 or abs(s - 0.7) < 0.02) else 1.0
            nr = 0.6 if abs(s - 0.56) < 0.025 else 1.0
            pts_l.append((cx + (bend - w * 0.8 * nl) * u, cy + y * u))
            pts_r.append((cx + (bend + w * 1.0 * nr) * u, cy + y * u))
        d.polygon(pts_l + pts_r[::-1], fill=255)
        # shaft through the vane and the bare quill below it (one piece with the vane)
        sh = [(cx + (12 * math.sin(s * math.pi) - 5) * u, cy + (-L + s * 1.62 * L) * u) for s in np.linspace(0, 1, 30)]
        sh += [(cx + (-5 - 3 * s) * u, cy + (0.62 * L + s * 0.34 * L) * u) for s in np.linspace(0, 1, 10)]
        d.line(sh, fill=255, width=int(5 * u), joint="curve")
        m = aa_mask(np.asarray(im, float) / 255.0, k)
        rgba = ink_colour(m > 0.5, rim_px=1.6, band_px=3.5, halo_px=3, halo_a=0.25, hot=False)
        edge = (m > 0.02) & (m < 0.98)
        rgba[..., 3] = np.where(edge, np.maximum(rgba[..., 3] * (m >= 0.5), np.maximum(rgba[..., 3], m * 255)), rgba[..., 3])
        if wscale < 0:  # the underside is a touch lighter (sheen)
            sol = m > 0.5
            rgba[..., :3] = np.where(sol[..., None], rgba[..., :3] + 14, rgba[..., :3])
        frames.append(to_img(rgba))
    return sheet(frames)


# ------------------------------------------------------------------ sigils
def polar(N):
    yy, xx = np.mgrid[-1:1:N * 1j, -1:1:N * 1j]
    return np.hypot(xx, yy), np.arctan2(yy, xx)


def mangekyo(N=1024):
    k = 2
    M = N * k
    r, th = polar(M)
    # iris: deep red rim -> bright crimson -> hot near the pupil
    iris_c = np.zeros((M, M, 3))
    g = smooth(0.95, 0.15, r)
    for c in range(3):
        iris_c[..., c] = (CRIMSON[c] * 0.55) * (1 - g) + np.array([235, 28, 40])[c] * g
    iris = r < 0.95
    # limbal ring
    limbal = (r > 0.86) & (r < 0.95)
    # the pinwheel: three curved blades + centre circle
    blade = np.zeros_like(r, bool)
    for kb in range(3):
        base = kb * 2 * math.pi / 3
        curl = 1.25  # radians of sweep from centre to tip
        centre_ang = base + curl * (r / 0.88) ** 1.2
        dang = np.angle(np.exp(1j * (th - centre_ang)))
        prof = np.clip(r / 0.88, 0, 1)
        width = 0.62 * np.sin(np.pi * np.clip(prof, 0, 1) ** 0.75) ** 0.9 * (1 - prof ** 3) + 0.02
        # a crescent: the leading side bulges, the trailing side is cut back
        blade |= (dang > -width * 0.35) & (dang < width) & (r < 0.88) & (r > 0.12)
    centre = r < 0.2
    black = blade | centre | limbal
    inner_hole = r < 0.075  # a fine red pupil glint keeps it from being a flat dot
    black &= ~inner_hole
    col = np.where(black[..., None], INK[None, None, :], iris_c)
    # thin crimson keyline round the black shapes
    bb = ndimage.binary_dilation(black, iterations=5) & ~black & iris
    col = np.where(bb[..., None], np.array([255, 60, 60])[None, None, :] * 0.85 + col * 0.15, col)
    a = iris.astype(float)
    # outer halo (soft crimson glow outside the iris)
    halo = (1 - smooth(0.95, 1.0, r)) * (r >= 0.95) * 0.5
    col = np.where((r >= 0.95)[..., None], CRIMSON[None, None, :], col)
    a = np.maximum(a, halo)
    rgba = np.dstack([col, a * 255])
    img = to_img(rgba).resize((N, N), Image.LANCZOS)
    return img


def tomoe_ring(N=1024):
    k = 2
    M = N * k
    r, th = polar(M)
    yy, xx = np.mgrid[-1:1:M * 1j, -1:1:M * 1j]
    black = np.zeros_like(r, bool)
    red = np.zeros_like(r, bool)
    # band rings
    black |= (r > 0.955) & (r < 0.975)
    black |= (r > 0.60) & (r < 0.615)
    red |= (r > 0.93) & (r < 0.95)
    # tick marks between the rings
    ticks = (np.abs(np.angle(np.exp(1j * th * 48))) < 0.12) & (r > 0.905) & (r < 0.93)
    black |= ticks
    # three tomoe orbiting in the band: head circle + tapering comma tail
    for kb in range(3):
        a0 = kb * 2 * math.pi / 3 + math.pi / 2
        R0 = 0.77
        hx, hy = R0 * math.cos(a0), R0 * math.sin(a0)
        head = np.hypot(xx - hx, yy - hy) < 0.085
        # tail sweeps backwards along the circle and narrows
        tail = np.zeros_like(r, bool)
        for s in np.linspace(0, 1, 60):
            ang = a0 - s * 0.55
            px, py = (R0 + 0.06 * s) * math.cos(ang), (R0 + 0.06 * s) * math.sin(ang)
            tail |= np.hypot(xx - px, yy - py) < 0.075 * (1 - s) ** 0.8
        black |= head | tail
    # gliding crows between the tomoe: the crow drawing itself, head outward, flying round the ring
    glide = Image.fromarray((crow_mask(-6, 0.0, k=2) * 255).astype(np.uint8), "L")
    size = int(0.30 * M / 2)
    glide = glide.resize((size, size), Image.LANCZOS)
    layer = Image.new("L", (M, M), 0)
    for kb in range(3):
        a0 = kb * 2 * math.pi / 3 + math.pi / 2 + math.pi / 3
        cx, cy = (0.5 + 0.385 * math.cos(a0)) * M, (0.5 + 0.385 * math.sin(a0)) * M
        # image y points down: rotate so the crow's head points radially outward
        rot = glide.rotate(-math.degrees(a0) - 90, resample=Image.BICUBIC, expand=True)
        layer.paste(255, (int(cx - rot.width / 2), int(cy - rot.height / 2)), rot)
    black |= np.asarray(layer) > 127
    col = np.zeros((M, M, 3))
    col[:] = INK
    col = np.where(red[..., None], CRIMSON[None, None, :], col)
    shape = black | red
    keyline = ndimage.binary_dilation(shape, iterations=4) & ~shape
    col = np.where(keyline[..., None], CRIMSON[None, None, :], col)
    a = (shape | keyline).astype(float)
    # faint red wash inside the band so the ring reads as one disc
    band = (r > 0.615) & (r < 0.955)
    wash = band & ~(shape | keyline)
    # a strong dark-crimson wash: on the pale pink pedestals a faint one vanished (Studio, v1)
    col = np.where(wash[..., None], np.array([120, 6, 18])[None, None, :] * (0.85 + 0.15 * np.cos((r - 0.78) * 9))[..., None], col)
    a = np.where(wash, 0.62 + 0.12 * np.cos((r - 0.78) * 9), a)
    rgba = np.dstack([col, a * 255])
    return to_img(rgba).resize((N, N), Image.LANCZOS)


def moon(N=512):
    """Tsukuyomi's blood moon: crimson disc, darker maria and craters, a brighter limb, a soft red halo."""
    r, th = polar(N)
    yy, xx = np.mgrid[-1:1:N * 1j, -1:1:N * 1j]
    R = 0.86
    disc = r < R
    maria = fbm((N, N), [22, 9], [1.0, 0.5], seed=77)
    shade = 0.74 + 0.26 * np.clip(maria * 1.8, -1, 1)
    craters = np.zeros((N, N))
    rng = np.random.default_rng(123)
    for _ in range(26):
        cx, cy = rng.uniform(-0.68, 0.68, 2)
        cr = rng.uniform(0.02, 0.08)
        d = np.hypot(xx - cx, yy - cy)
        craters -= 0.22 * (1 - smooth(cr * 0.6, cr, d))  # dark floor
        craters += 0.12 * ((d > cr * 0.85) & (d < cr * 1.15))  # lit rim
    lum = np.clip(shade + craters, 0.35, 1.2)
    limb = smooth(R * 0.70, R, r) * 0.25  # brighter toward the edge (back-lit)
    base = np.array([196, 22, 30], float)
    col = base[None, None, :] * (lum + limb)[..., None]
    col = np.clip(col, 0, 255)
    edge = 1 - smooth(0, 1.5 / N * 2, np.abs(r - R))
    a = np.where(disc, 1.0, 0.0)
    # a tight halo: a wide one turned the disc into a red cloud at viewing distance (Studio, v2)
    halo = (1 - smooth(R, R + 0.12, r)) ** 1.6 * 0.42 * (~disc)
    col = np.where(disc[..., None], col, np.array([220, 30, 40])[None, None, :])
    a = np.maximum(a, halo)
    # antialias the disc edge
    aa = smooth(R + 1.2 / N * 2, R - 1.2 / N * 2, r)
    a = np.where(np.abs(r - R) < 3 / N * 2, np.maximum(aa, halo), a)
    del edge, th
    return to_img(np.dstack([col, a * 255]))


def ember(N=128):
    r, _ = polar(N)
    core = 1 - smooth(0.0, 0.16, r)
    halo = (1 - smooth(0.0, 0.95, r)) ** 2.2
    a = np.clip(core + halo * 0.75, 0, 1)
    w = 255 * np.ones((N, N))
    rgba = np.dstack([w, w * (0.75 + 0.25 * core), w * (0.75 + 0.25 * core), a * 255])
    return to_img(rgba)


def glow(N=256):
    r, _ = polar(N)
    a = (1 - smooth(0.0, 1.0, r)) ** 2.4
    w = 255 * np.ones((N, N))
    return to_img(np.dstack([w, w, w, a * 255]))


def contact(imgs):
    tiles = []
    for name, im in imgs:
        t = im.copy()
        t.thumbnail((512, 512))
        tiles.append((name, t))
    W = 2 * 540
    rows = math.ceil(len(tiles) / 2)
    out = Image.new("RGB", (W, rows * 560), (150, 120, 200))  # a pale lilac like the pedestals
    half = Image.new("RGB", (540, 560), (25, 22, 55))  # and the dark stage floor
    for i, (name, t) in enumerate(tiles):
        x, y = (i % 2) * 540, (i // 2) * 560
        if (i // 2) % 2 == 0:
            out.paste(half, (x, y))
        out.paste(t, (x + 14, y + 14), t)
        ImageDraw.Draw(out).text((x + 14, y + 534), name, fill=(255, 255, 255))
    return out


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    jobs = [("amaterasu_4x4", amaterasu), ("inksmoke_4x4", inksmoke), ("crow_4x4", crow),
            ("feather_4x4", feather), ("mangekyo", mangekyo), ("tomoe_ring", tomoe_ring),
            ("moon", moon), ("ember", ember), ("glow", glow)]
    made = []
    for name, fn in jobs:
        im = fn()
        im.save(OUT / f"{name}.png", optimize=True)
        made.append((name, im))
        print(f"wrote {name}.png {im.size}")
    # the lightning arcs come from the roblox-vfx skill's own generated library (not harvested)
    lib = Path.home() / ".claude" / "skills" / "roblox-vfx" / "sim" / "textures" / "lib" / "flipbooks" / "lightning"
    lt = Image.open(lib / "lightning_fb_glow_12_4x4.png").convert("RGBA")
    lt.save(OUT / "lightning_4x4.png", optimize=True)
    made.append(("lightning_4x4", lt))
    contact(made).save(OUT / "_sheet.jpg", quality=88)
    print("wrote _sheet.jpg")


if __name__ == "__main__":
    main()
