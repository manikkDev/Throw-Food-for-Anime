#!/usr/bin/env python3
"""Limitless (Satoru Gojo, "Limitless Teacher", Mythic) textures, v2: animated, layered, built for depth.

    python tools/auras/limitless/make_tex.py [names...]   -> assets/auras/limitless/*.png (+ _sheet.jpg)

His body keeps the aura the owner tuned for him (the builder rebuilds it exactly). v1's static orbs and flat floor
were rejected as low effort; v2 follows the anime (Lapse Blue pulls into a point, Reversal Red repels at twice the
output, Hollow Purple is the two colliding into imaginary mass; the Unlimited Void is endless space with a large
black hole, galaxies and streams of white information; the Six Eyes flash bright blue):

  blue_4x4.png        16-frame LOOP, Lapse Blue: a sphere with a dark gravity-well core, cyan swirl bands turning
                      INTO it (polar turbulence that flows inward), a bright fresnel rim, specks spiralling in
  red_4x4.png         16-frame LOOP, Reversal Red: a white-hot core in an orange-crimson sphere, flare tendrils
                      and sparks flowing OUT, turning the other way
  purple_4x4.png      16-frame ONE-SHOT, Hollow Purple: Blue and Red spiral in from either side (0-4), collide in
                      a white flash (5), a violet-black sphere of imaginary mass swirls with crackling arcs (6-11),
                      then implodes into a bright point and a shock ring (12-15)
  eye_flare.png       the Six Eyes' glint: a long anamorphic streak and a small star, white core, cyan falloff
  void_floor.png      Unlimited Void, the base layer (SurfaceGui): nebula, starfield, faint galaxies, a ring of
                      kanji 無量空処 with infinity signs, a dark centre for the black hole layer
  blackhole.png       the void's black hole (a second SurfaceGui, turning faster): a black disc, a white-hot
                      photon ring, a lopsided accretion glow, a faint swirling disc round it
  stream_4x4.png      16-frame LOOP, laid flat on the floor: streaks of white information rushing inward (seamless)
  streak.png          a thin vertical light streak (white; tinted) rising inside his dome

Reuses EmperorThorns's helpers (tools/auras/emperor_thorns/make_tex.py).
"""
from __future__ import annotations

import importlib.util
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets" / "auras" / "limitless"
_spec = importlib.util.spec_from_file_location("et", ROOT / "tools" / "auras" / "emperor_thorns" / "make_tex.py")
K = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(K)
smooth, over, down, grid, to_img, sheet = K.smooth, K.over, K.down, K.grid, K.to_img, K.sheet
SS = 2
FRAME = 256
FONT = Path("C:/Windows/Fonts/YuGothB.ttc")

SPACE = np.array([4, 4, 16], float)
NAVY = np.array([6, 12, 60], float)
INDIGO = np.array([34, 20, 96], float)
COBALT = np.array([30, 90, 255], float)
CYAN = np.array([130, 225, 255], float)
WHITE = np.array([255, 255, 255], float)
VIOLET = np.array([140, 40, 255], float)
MAGENTA = np.array([230, 60, 255], float)
PURPLE_DARK = np.array([30, 0, 50], float)
CRIMSON = np.array([220, 20, 36], float)
ORANGE = np.array([255, 130, 50], float)
GOLDW = np.array([255, 230, 200], float)


def mix(c0, c1, t):
    return K.mix(c0, c1, t)


def layer(alpha, colour):
    out = np.zeros(alpha.shape + (4,))
    out[..., :3] = colour
    out[..., 3] = np.clip(alpha, 0, 1) * 255
    return out


def fbm(shape, scales, seed, wrap=True):
    out = np.zeros(shape)
    for i, s in enumerate(scales):
        n = np.random.default_rng(seed + i).standard_normal(shape)
        f = ndimage.gaussian_filter(n, s, mode="wrap" if wrap else "reflect")
        out += f / (np.abs(f).max() + 1e-9) / (i + 1)
    return out / sum(1 / (i + 1) for i in range(len(scales)))


# a periodic noise sheet in (angle, log-radius) space: sampling it along spirals gives turbulence that turns and flows
POLAR = fbm((256, 512), [5, 12, 2], 777)  # rows = log radius, cols = angle (periodic)


def polar_sample(th, lr, twist, phase, flow):
    """th: angle (rad), lr: log radius. The spiral coordinate th + twist*lr, shifted by phase (turn) and flow
    (radial motion, + outward)."""
    cols = ((th + twist * lr + phase) / (2 * math.pi) % 1.0) * 512
    rows = ((lr - flow) * 40) % 256
    return ndimage.map_coordinates(POLAR, [rows, cols], order=1, mode="wrap")


# ---------------------------------------------------------------- the orbs
def orb_frame(x, y, cx, cy, R, t, kind, alpha_mul=1.0):
    """One orb at (cx, cy) radius R (frame units), phase t (0..1 of the loop). kind 'blue' or 'red'."""
    dx, dy = x - cx, y - cy
    r = np.sqrt(dx * dx + dy * dy) + 1e-6
    th = np.arctan2(dy, dx)
    lr = np.log(r / R)
    if kind == "blue":
        n = polar_sample(th, lr, 2.4, -t * 2 * math.pi, -t * 1.2)  # turning and flowing IN
        inside = r < R
        q = np.clip(r / R, 0, 1)
        fres = q ** 5  # bright limb
        # a bright ball of blue energy (v1's dark well read as a hollow ring): white-hot heart, cobalt body,
        # deep navy toward the edge, then a cyan rim; high-contrast swirl bands turning into it give it depth
        col = mix(WHITE, CYAN, smooth(0.0, 0.25, q))
        col = mix(col, COBALT, smooth(0.2, 0.6, q))
        col = mix(col, NAVY, smooth(0.6, 0.95, q) * 0.7)
        bright = smooth(0.2, 0.55, n) * smooth(0.1, 0.5, q)
        dark = smooth(-0.15, -0.5, n) * smooth(0.25, 0.7, q)
        col = mix(col, CYAN, bright * 0.8)
        col = mix(col, NAVY * 0.5, dark * 0.6)
        col = mix(col, mix(CYAN, WHITE, 0.5), fres * 0.85)
        a_in = inside * 1.0
        # arms of light spiralling in from outside, fading with distance
        arms = smooth(0.12, 0.5, n) * np.clip(1 - (r - R) / (R * 1.2), 0, 1) * (r >= R)
        halo = np.clip(1 - (r - R) / (R * 1.4), 0, 1) ** 2 * (r >= R) * 0.55
        out = layer(halo * alpha_mul, COBALT)
        out = over(out, layer(arms * 0.9 * alpha_mul, mix(COBALT, CYAN, 0.6)))
        body = np.zeros(x.shape + (4,))
        body[..., :3] = col
        body[..., 3] = a_in * 255 * alpha_mul
        out = over(out, body)
        # specks drawn spiralling in: thin dots along the arms near the rim
        sp = (n > 0.62) & (r > R * 0.95) & (r < R * 1.5)
        out = over(out, layer(sp * 0.9 * alpha_mul, WHITE))
        return out
    # red: a white-hot core, tendrils flowing OUT, turning the other way
    n = polar_sample(th, lr, -1.6, t * 2 * math.pi, t * 1.4)
    inside = r < R
    q = np.clip(r / R, 0, 1)
    col = mix(WHITE, GOLDW, smooth(0.0, 0.25, q))
    col = mix(col, ORANGE, smooth(0.2, 0.6, q))
    col = mix(col, CRIMSON, smooth(0.55, 1.0, q))
    col = mix(col, mix(CRIMSON, ORANGE, 0.5), smooth(0.2, 0.6, n) * smooth(0.3, 0.9, q) * 0.6)
    tend = smooth(0.1, 0.45, n) * np.clip(1 - (r - R) / (R * 1.5), 0, 1) * (r >= R)  # 0.25-0.65 read faint
    halo = np.clip(1 - (r - R) / (R * 1.5), 0, 1) ** 2 * (r >= R) * 0.6
    out = layer(halo * alpha_mul, CRIMSON)
    out = over(out, layer(tend * 0.95 * alpha_mul, mix(CRIMSON, ORANGE, 0.5)))
    body = np.zeros(x.shape + (4,))
    body[..., :3] = col
    body[..., 3] = inside * 255 * alpha_mul
    out = over(out, body)
    sp = (n > 0.66) & (r > R * 1.05) & (r < R * 1.7)
    out = over(out, layer(sp * alpha_mul, GOLDW))
    return out


def orb_sheet(kind):
    n = FRAME * SS
    x, y = grid(n)
    frames = []
    for f in range(16):
        frames.append(to_img(down(orb_frame(x, y, 0, 0, 0.42, f / 16, kind), SS)))
    return sheet(frames)


# ---------------------------------------------------------------- Hollow Purple
def bolt(rng, p0, p1, rough, depth):
    pts = [np.array(p0, float), np.array(p1, float)]
    for _ in range(depth):
        nxt = [pts[0]]
        for a, b in zip(pts[:-1], pts[1:]):
            d = b - a
            nxt += [(a + b) / 2 + np.array([-d[1], d[0]]) * rng.uniform(-rough, rough), b]
        pts = nxt
        rough *= 0.55
    return pts


def purple_sheet():
    n = FRAME * SS
    x, y = grid(n)
    r = np.sqrt(x * x + y * y) + 1e-6
    th = np.arctan2(y, x)
    lr = np.log(r / 0.45)
    rng = np.random.default_rng(23)
    frames = []
    for f in range(16):
        out = np.zeros((n, n, 4))
        if f <= 4:  # the approach: blue from the left, red from the right, spiralling in
            k = smooth(0, 5, f)
            ang = math.pi * 0.6 * k
            d = 0.6 * (1 - k) + 0.12
            bx, by = -d * math.cos(ang), -d * math.sin(ang)
            out = over(out, orb_frame(x, y, bx, by, 0.2, f / 8, "blue"))
            out = over(out, orb_frame(x, y, -bx, -by, 0.2, f / 8, "red"))
        elif f == 5:  # the collision
            fl = np.clip(1 - r / 0.7, 0, 1) ** 1.5
            out = over(out, layer(fl, mix(WHITE, MAGENTA, 0.2)))
            out = over(out, layer(np.clip(1 - r / 0.25, 0, 1), WHITE))
        else:
            if f <= 11:
                R = 0.3 + 0.18 * smooth(6, 9, f)
                bright = 1.0
            else:
                R = 0.48 * (1 - smooth(12, 15, f)) + 0.02
                bright = 1.0 + smooth(12, 14, f)
            t = (f - 6) / 10
            nn = polar_sample(th, np.log(r / max(R, 0.02)), 3.0, t * 2 * math.pi * 1.5, -t)
            q = np.clip(r / R, 0, 1)
            # imaginary mass: a white-hot heart, magenta into violet, a dark violet edge, a white rim; dark and
            # bright swirl bands turning into it (v1 was a hollow ring)
            col = mix(WHITE, MAGENTA, smooth(0.0, 0.3, q))
            col = mix(col, VIOLET, smooth(0.25, 0.65, q))
            col = mix(col, PURPLE_DARK, smooth(0.65, 0.95, q) * 0.75)
            col = mix(col, MAGENTA, smooth(0.2, 0.55, nn) * smooth(0.15, 0.8, q) * 0.8)
            col = mix(col, PURPLE_DARK * 0.6, smooth(-0.15, -0.5, nn) * smooth(0.3, 0.8, q) * 0.6)
            col = mix(col, WHITE, q ** 6 * 0.85)
            col = mix(col, WHITE, np.clip(1 - r / (R * 0.18), 0, 1) * (bright - 1))
            halo = np.clip(1 - (r - R) / 0.4, 0, 1) ** 2 * (r >= R) * 0.75
            swirl = smooth(0.3, 0.65, nn) * np.clip(1 - (r - R) / 0.35, 0, 1) * (r >= R)
            out = over(out, layer(halo, VIOLET))
            out = over(out, layer(swirl * 0.85, MAGENTA))
            body = np.zeros((n, n, 4))
            body[..., :3] = col
            body[..., 3] = (r < R) * 255
            out = over(out, body)
            if 6 <= f <= 11:  # crackling arcs round the sphere
                arcs = Image.new("L", (n, n), 0)
                ad = ImageDraw.Draw(arcs)
                for _ in range(3):
                    a0 = rng.uniform(0, 2 * math.pi)
                    a1 = a0 + rng.uniform(0.6, 1.4)
                    rr0, rr1 = R * rng.uniform(1.0, 1.15), R * rng.uniform(1.25, 1.7)
                    p0 = ((1 + rr0 * math.cos(a0)) / 2 * n, (1 - rr0 * math.sin(a0)) / 2 * n)
                    p1 = ((1 + rr1 * math.cos(a1)) / 2 * n, (1 - rr1 * math.sin(a1)) / 2 * n)
                    ad.line([tuple(p) for p in bolt(rng, p0, p1, 0.3, 5)], fill=255, width=int(1.6 * SS))
                am = np.asarray(arcs, float) / 255
                out = over(out, layer(ndimage.gaussian_filter(am, 3 * SS) * 1.4, MAGENTA))
                out = over(out, layer(am, WHITE))
            if f >= 12:  # the shock ring of the implosion, racing out
                rr = 0.3 + 0.6 * smooth(12, 15.5, f)
                ring = np.exp(-((r - rr) / 0.03) ** 2) * (1 - smooth(13, 15.8, f))
                out = over(out, layer(ring, mix(MAGENTA, WHITE, 0.4)))
        frames.append(to_img(down(out, SS)))
    return sheet(frames)


# ---------------------------------------------------------------- the Six Eyes
def eye_flare(size=256):
    n = size * SS
    x, y = grid(n)
    streak = np.exp(-(y / 0.018) ** 2) * np.clip(1 - np.abs(x), 0, 1) ** 1.5
    streak2 = np.exp(-(y / 0.05) ** 2) * np.clip(1 - np.abs(x) / 0.7, 0, 1) ** 2 * 0.5
    star = np.clip(1 - (np.abs(x) * 6 + np.abs(y) * 1.2), 0, 1) ** 2 + np.clip(1 - (np.abs(y) * 6 + np.abs(x) * 1.2), 0, 1) ** 2
    d = np.sqrt(x * x + y * y)
    core = np.clip(1 - d / 0.12, 0, 1)
    a = np.clip(streak + streak2 + star * 0.7 + core, 0, 1)
    col = mix(CYAN, WHITE, np.clip(core + star * 0.5 + np.exp(-(y / 0.008) ** 2) * 0.6, 0, 1))
    rgba = np.zeros((n, n, 4))
    rgba[..., :3] = col
    rgba[..., 3] = a * 255
    return to_img(down(rgba, SS))


# ---------------------------------------------------------------- Unlimited Void, in layers
def void_floor(size=1024):
    n = size * SS
    x, y = grid(n)
    r = np.sqrt(x * x + y * y)
    th = np.arctan2(y, x)
    neb = fbm((n, n), [8 * SS, 24 * SS, 60 * SS], 71)
    neb2 = fbm((n, n), [5 * SS, 16 * SS], 91)
    disc = r < 0.97
    col = mix(SPACE, INDIGO, np.clip(neb * 0.9 + 0.2, 0, 1) * 0.75)
    col = mix(col, VIOLET * 0.55, np.clip(neb2 - 0.15, 0, 1) * 0.7)
    col = mix(col, COBALT * 0.6, np.clip(-neb2 - 0.25, 0, 1) * 0.6)
    rng = np.random.default_rng(5)
    # faint distant galaxies
    for _ in range(7):
        a = rng.uniform(0, 2 * math.pi)
        rr = rng.uniform(0.35, 0.7)
        gx, gy = rr * math.cos(a), rr * math.sin(a)
        gr = np.sqrt((x - gx) ** 2 + ((y - gy) * 2.2) ** 2)
        col = mix(col, mix(CYAN, WHITE, 0.4), np.clip(1 - gr / 0.05, 0, 1) ** 2 * 0.8)
    # stars: a dense small field and a few bright ones with cross glints
    small = (rng.random((n, n)) > 0.9985).astype(float)
    col = mix(col, WHITE, np.clip(ndimage.gaussian_filter(small, 0.8 * SS) * 9, 0, 1))
    big = (rng.random((n, n)) > 0.99995).astype(float)
    bg = ndimage.gaussian_filter(big, 2.2 * SS) * 120
    col = mix(col, mix(CYAN, WHITE, 0.7), np.clip(bg, 0, 1))
    # the centre darkens toward the black hole layer that sits on top
    col = mix(col, SPACE, np.clip(1 - r / 0.42, 0, 1) ** 1.5 * 0.8)
    out = layer(ndimage.gaussian_filter(disc.astype(float), 10 * SS) * 0.5, SPACE)
    body = np.zeros((n, n, 4))
    body[..., :3] = col
    body[..., 3] = disc * 0.97 * 255
    out = over(out, body)
    band = (r > 0.8) & (r < 0.935)
    out = over(out, layer(band * 0.8, SPACE))
    for rr, w in ((0.945, 0.005), (0.79, 0.004), (0.962, 0.002)):
        m = np.abs(r - rr) < w
        out = over(out, layer(ndimage.gaussian_filter(m.astype(float), 3 * SS) * 1.4, COBALT))
        out = over(out, layer(m * 1.0, CYAN))
    glyphs = Image.new("L", (n, n), 0)
    font = ImageFont.truetype(str(FONT), int(n * 0.056))
    text = "無量空処"
    slots = 3 * (len(text) + 1)
    for k in range(slots):
        a = math.pi / 2 - k / slots * 2 * math.pi
        rr = 0.868 * n / 2
        cx, cy = n / 2 + rr * math.cos(a), n / 2 - rr * math.sin(a)
        i = k % (len(text) + 1)
        tile = Image.new("L", (int(n * 0.09), int(n * 0.09)), 0)
        td = ImageDraw.Draw(tile)
        if i < len(text):
            td.text((tile.width / 2, tile.height / 2), text[i], font=font, fill=255, anchor="mm")
        else:
            w_, h_ = tile.width, tile.height
            for sx in (-1, 1):
                td.ellipse([w_ / 2 + sx * w_ * 0.16 - w_ * 0.15, h_ / 2 - h_ * 0.1, w_ / 2 + sx * w_ * 0.16 + w_ * 0.15,
                            h_ / 2 + h_ * 0.1], outline=255, width=max(2, int(w_ * 0.04)))
        tile = tile.rotate(math.degrees(a) - 90, resample=Image.BICUBIC)
        glyphs.paste(tile, (int(cx - tile.width / 2), int(cy - tile.height / 2)), tile)
    gm = np.asarray(glyphs, float) / 255
    out = over(out, layer(ndimage.gaussian_filter(gm, 3 * SS) * 1.3, COBALT))
    out = over(out, layer(gm, mix(CYAN, WHITE, 0.65)))
    return to_img(down(out, SS))


def blackhole(size=1024):
    # Unlimited Void's centre, stood UPRIGHT behind him as a halo (on the floor his legs hid it): a black disc
    # his white hair reads against, a white-hot photon ring, a saturated cobalt/violet accretion disc swirling
    # round it (Doppler-bright on one side), and thin rays of light streaming out into the void. Saturated and
    # mostly opaque: a pale disc washed out against the owner's white dome.
    n = size * SS
    x, y = grid(n)
    r = np.sqrt(x * x + y * y) + 1e-6
    th = np.arctan2(y, x)
    lr = np.log(r / 0.5)
    nn = polar_sample(th, lr, 3.5, 0.0, 0.0)
    n2 = polar_sample(th * 2, lr, -2.0, 1.3, 0.0)
    R0 = 0.3
    side = 0.6 + 0.4 * np.cos(th - 0.8)
    disc = np.clip(1 - (r - R0) / 0.55, 0, 1) ** 1.3 * (r > R0)
    swirl = smooth(-0.2, 0.55, nn) * 0.75 + 0.25
    a_disc = np.clip(disc * swirl * (0.55 + 0.45 * side) * 1.25, 0, 1)
    col = mix(np.array([70, 40, 230], float), COBALT, smooth(0.15, 0.5, a_disc))
    col = mix(col, VIOLET, smooth(0.1, 0.6, n2) * disc * 0.45)
    col = mix(col, CYAN, smooth(0.55, 0.9, a_disc) * side)
    dl = np.zeros((n, n, 4))
    dl[..., :3] = col
    dl[..., 3] = a_disc * 255
    out = dl
    # rays streaming out of the ring into the void
    rays = smooth(0.35, 0.75, polar_sample(th * 6, lr * 0.05, 0.0, 0.0, 0.0))
    ray_a = rays * np.clip(1 - (r - R0) / 0.68, 0, 1) ** 1.5 * (r > R0) * 0.8
    out = over(out, layer(ray_a, mix(CYAN, WHITE, 0.3)))
    # the photon ring: a bright cyan bloom and a white-hot line at the edge of the dark
    ring = np.exp(-((r - R0) / 0.016) ** 2)
    out = over(out, layer(np.clip(ndimage.gaussian_filter(ring, 6 * SS) * 2.2, 0, 1), CYAN))
    out = over(out, layer(np.clip(ring * 1.2, 0, 1), WHITE))
    # the hole
    out = over(out, layer(smooth(R0 * 0.985, R0 * 0.93, r), SPACE * 0.25))
    return to_img(down(out, SS))


def stream_sheet():
    """Streaks of white information rushing inward, seamless over 16 frames."""
    n = FRAME * 2 * SS  # a 512 frame per cell would be 2048: keep 256 cells but supersample harder
    n = FRAME * SS
    x, y = grid(n)
    rng = np.random.default_rng(31)
    streaks = [(rng.uniform(0, 2 * math.pi), rng.uniform(0, 1), rng.uniform(0.06, 0.14), rng.uniform(0.6, 1.0))
               for _ in range(46)]
    frames = []
    for f in range(16):
        img = Image.new("L", (n, n), 0)
        d = ImageDraw.Draw(img)
        for a, ph, L, b in streaks:
            u = (ph - f / 16) % 1.0  # moves inward, wraps seamlessly
            r1 = 0.2 + 0.75 * u
            r0 = max(r1 - L, 0.12)
            p0 = ((1 + r0 * math.cos(a)) / 2 * n, (1 - r0 * math.sin(a)) / 2 * n)
            p1 = ((1 + r1 * math.cos(a)) / 2 * n, (1 - r1 * math.sin(a)) / 2 * n)
            fade = min(1.0, u * 4) * min(1.0, (1 - u) * 6)
            d.line([p0, p1], fill=int(255 * b * fade), width=max(1, int(1.6 * SS)))
        m = np.asarray(img, float) / 255
        a_ = np.clip(m + ndimage.gaussian_filter(m, 2 * SS) * 1.2, 0, 1)
        rgba = np.zeros((n, n, 4))
        rgba[..., :3] = mix(CYAN, WHITE, np.clip(m, 0, 1))
        rgba[..., 3] = a_ * 255
        frames.append(to_img(down(rgba, SS)))
    return sheet(frames)


def streak(w=32, h=256):
    W, H = w * SS, h * SS
    X, Y = np.meshgrid(np.arange(W) + 0.5, np.arange(H) + 0.5)
    u = (X / W - 0.5) * 2
    v = Y / H
    a = np.exp(-(u / 0.18) ** 2) * np.sin(np.clip(v, 0, 1) * math.pi) ** 1.5
    rgba = np.zeros((H, W, 4))
    rgba[..., :3] = 255
    rgba[..., 3] = a * 255
    sq = np.zeros((H, H, 4))
    off = (H - W) // 2
    sq[:, off : off + W] = rgba
    return to_img(down(sq, SS))


def contact(files):
    tiles = []
    for name, im in files.items():
        t = im.copy()
        t.thumbnail((420, 420))
        for bg in ((70, 150, 220), (14, 14, 30)):
            b = Image.new("RGB", (430, 430), bg)
            b.paste(t, ((430 - t.width) // 2, (430 - t.height) // 2), t)
            ImageDraw.Draw(b).text((6, 4), name, fill=(255, 80, 80))
            tiles.append(b)
    s = Image.new("RGB", (430 * 4, 430 * ((len(tiles) + 3) // 4)))
    for i, t in enumerate(tiles):
        s.paste(t, ((i % 4) * 430, (i // 4) * 430))
    return s


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    only = set(sys.argv[1:])
    makers = {
        "blue_4x4": lambda: orb_sheet("blue"),
        "red_4x4": lambda: orb_sheet("red"),
        "purple_4x4": purple_sheet,
        "eye_flare": eye_flare,
        "void_floor": void_floor,
        "blackhole": blackhole,
        "stream_4x4": stream_sheet,
        "streak": streak,
    }
    files = {}
    for k, mk in makers.items():
        p = OUT / f"{k}.png"
        if only and k not in only:
            if p.exists():
                files[k] = Image.open(p).convert("RGBA")
            continue
        files[k] = mk()
        files[k].save(p)
        print("wrote", k, files[k].size)
    contact(files).save(OUT / "_sheet.jpg", quality=90)
    print("wrote _sheet.jpg")


if __name__ == "__main__":
    main()
