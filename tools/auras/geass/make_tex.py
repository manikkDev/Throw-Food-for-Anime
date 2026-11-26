#!/usr/bin/env python3
"""Geass (Lelouch, "Rebel Emperor", Epic) textures.

    python tools/auras/geass/make_tex.py [names...]   -> assets/auras/geass/*.png (+ _sheet.jpg)

His body keeps the pack aura the owner gave him (Heaven, copied verbatim by the builder). Round it, his own power and
his own symbol, never fire:
  - the Geass: a bird-shaped sigil that glows red in his LEFT eye; one look, one absolute order
  - the chess motif: he reads the war as a board and casts himself as the BLACK KING (Zero's costume)

  board.png       the floor (SurfaceGui): a round chessboard, black and royal-purple lacquer squares with a gloss
                  sweep and fine gold inlay, darkening to the rim, the bird sigil ENGRAVED in dark crimson at the
                  centre, a lacquer border between two gold lines set with small gold diamonds
  sigil_4x4.png   16-frame LOOP laid flat over the engraving: the sigil lit from inside, a pulse of red light
                  running from the bird's body out along its wings and tail, the glow breathing
  eye_sigil.png   the sigil small and white-hot in a crimson halo: his left eye
  wave.png        the Geass cast: three concentric thin crimson rings (white cores), the outer one brightest,
                  flown out of his eye and grown, so they read as a train of rings travelling outward
  mote.png        a tiny crimson diamond glint rising off the board
  soft.png        a soft round glow (white; tinted) under the black king piece

The sigil is drawn here from tapered bezier strokes (a bird: a drop-shaped body, two swept wings with an inner
feather each, two tail hooks); it is our own drawing of the idea, not a copy of the show's emblem.
Reuses EmperorThorns's helpers (tools/auras/emperor_thorns/make_tex.py).
"""
from __future__ import annotations

import importlib.util
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets" / "auras" / "geass"
_spec = importlib.util.spec_from_file_location("et", ROOT / "tools" / "auras" / "emperor_thorns" / "make_tex.py")
K = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(K)
smooth, over, down, grid, to_img, mix = K.smooth, K.over, K.down, K.grid, K.to_img, K.mix
SS = 2
FRAME = 256

BLACK = np.array([9, 7, 16], float)
PURPLE = np.array([52, 22, 104], float)
PURPLE_HI = np.array([96, 52, 170], float)
GOLD = np.array([232, 186, 86], float)
GOLD_D = np.array([130, 86, 26], float)
CRIMSON = np.array([230, 16, 44], float)
CRIMSON_D = np.array([86, 4, 18], float)
PINK = np.array([255, 120, 150], float)
WHITE = np.array([255, 255, 255], float)


def layer(alpha, colour):
    out = np.zeros(alpha.shape + (4,))
    out[..., :3] = colour
    out[..., 3] = np.clip(alpha, 0, 1) * 255
    return out


def coloured(alpha, col):
    """col: an HxWx3 colour field."""
    out = np.zeros(alpha.shape + (4,))
    out[..., :3] = col
    out[..., 3] = np.clip(alpha, 0, 1) * 255
    return out


# ---------------------------------------------------------------- the sigil
def bez(p0, p1, p2, p3, t):
    t = t[:, None]
    return ((1 - t) ** 3) * p0 + 3 * ((1 - t) ** 2) * t * p1 + 3 * (1 - t) * t * t * p2 + (t ** 3) * p3


def stroke(p, w0, w1, n=96, taper=0.9):
    """Outline polygon of a tapered cubic bezier stroke (points in -1..1, y up)."""
    p = [np.array(q, float) for q in p]
    t = np.linspace(0, 1, n)
    c = bez(*p, t)
    d = np.gradient(c, axis=0)
    d /= np.linalg.norm(d, axis=1, keepdims=True) + 1e-9
    nrm = np.stack([-d[:, 1], d[:, 0]], 1)
    w = w0 * (1 - t) ** taper + w1 * t
    left = c + nrm * w[:, None] * 0.5
    right = c - nrm * w[:, None] * 0.5
    return np.concatenate([left, right[::-1]])


def mirror(poly):
    q = poly.copy()
    q[:, 0] *= -1
    return q


def sigil_polys():
    polys = []
    # body: a drop, point down, a small notch-free head at the top
    # a long drop: round shoulders at the top (y 0.30), widest just above the wings' roots, a sharp point at
    # the bottom (y -0.50) between the tail hooks
    v = np.linspace(0, 1, 120)
    yy = 0.30 - v * 0.80
    ww = 0.12 * np.sqrt(np.clip(v / 0.22, 0, 1)) * np.where(v < 0.22, 1.0, (1 - (v - 0.22) / 0.78) ** 1.35)
    polys.append(np.concatenate([np.stack([ww, yy], 1), np.stack([-ww, yy], 1)[::-1]]))
    # the head: a small diamond above the body
    polys.append(np.array([(0.0, 0.44), (0.055, 0.365), (0.0, 0.33), (-0.055, 0.365)]))
    for side in (1, -1):
        f = (lambda q: q) if side == 1 else mirror
        # the great wing, swept up and out
        polys.append(f(stroke([(0.05, 0.10), (0.34, 0.04), (0.62, 0.24), (0.88, 0.66)], 0.13, 0.0, taper=0.85)))
        # its inner feather
        polys.append(f(stroke([(0.06, 0.02), (0.30, -0.06), (0.52, 0.06), (0.70, 0.30)], 0.085, 0.0, taper=0.8)))
        # a third, short covert feather
        polys.append(f(stroke([(0.06, -0.06), (0.24, -0.14), (0.40, -0.08), (0.52, 0.06)], 0.06, 0.0, taper=0.8)))
        # the tail hook, swept down and curled back up
        polys.append(f(stroke([(0.03, -0.30), (0.20, -0.50), (0.42, -0.52), (0.50, -0.34)], 0.07, 0.0, taper=0.9)))
    return polys


def sigil_mask(n, scale=1.0, cx=0.0, cy=0.0, ss=4):
    """Antialiased 0..1 mask of the sigil on an n x n canvas spanning -1..1 (the sigil spans about -0.9..0.9 * scale)."""
    m = n * ss
    img = Image.new("L", (m, m), 0)
    dr = ImageDraw.Draw(img)
    for poly in sigil_polys():
        px = ((poly[:, 0] * scale + cx) + 1) / 2 * m
        py = (1 - ((poly[:, 1] * scale + cy) + 1) / 2) * m
        dr.polygon(list(zip(px.tolist(), py.tolist())), fill=255)
    return np.asarray(img.resize((n, n), Image.LANCZOS), float) / 255.0


# ---------------------------------------------------------------- the textures
def board(size=1024):
    n = size * SS
    x, y = grid(n)
    r = np.sqrt(x * x + y * y)
    R = 0.84
    half = R
    cell = 2 * half / 8
    gx = (x + half) / cell
    gy = (y + half) / cell
    ix, iy = np.floor(gx), np.floor(gy)
    fx, fy = gx - ix, gy - iy
    light = ((ix + iy) % 2) == 1
    col = np.where(light[..., None], PURPLE, BLACK)
    # each square: a soft top-left to bottom-right lacquer gradient
    shade = 0.82 + 0.28 * (1 - (fx * 0.5 + (1 - fy) * 0.5))
    col = col * shade[..., None]
    # a bevel: each square's top and left edges catch the light, bottom and right fall into shadow
    bev = smooth(0.06, 0.0, fy - 0.0) * 0 + smooth(0.07, 0.0, 1 - fy) + smooth(0.07, 0.0, fx)
    dark = smooth(0.07, 0.0, fy) + smooth(0.07, 0.0, 1 - fx)
    col = mix(col, np.where(light[..., None], PURPLE_HI * 1.3, PURPLE * 0.9), np.clip(bev, 0, 1) * 0.55)
    col = col * (1 - 0.35 * np.clip(dark, 0, 1))[..., None]
    # one gloss sweep across the whole board
    sweep = np.exp(-(((x + y) * 0.7071 - 0.18) / 0.16) ** 2) * 0.55 + np.exp(-(((x + y) * 0.7071 + 0.42) / 0.05) ** 2) * 0.35
    col = mix(col, np.where(light[..., None], PURPLE_HI, PURPLE * 0.7), sweep * 0.9)
    # fine gold inlay between the squares
    dl = np.minimum(np.minimum(fx, 1 - fx), np.minimum(fy, 1 - fy)) * cell
    inlay = smooth(0.0065, 0.0025, dl) * (r < R)
    col = mix(col, GOLD * 0.85, inlay * 0.8)
    # darker toward the rim
    col = col * (1 - 0.55 * smooth(0.35, R, r))[..., None]
    # the sigil engraved at the centre: dark crimson with a lit inner edge
    sm = sigil_mask(n, scale=0.78, cy=0.02, ss=2)
    edge = np.clip(sm - ndimage.gaussian_filter(sm, 3 * SS), 0, 1) * 3
    col = mix(col, CRIMSON_D * 1.3, sm * 0.95)
    col = mix(col, CRIMSON, np.clip(edge, 0, 1) * 0.8)
    out = coloured((r < R).astype(float), col)
    # border: lacquer band between two gold lines, set with gold diamonds
    band = (r >= R) & (r < 0.975)
    bcol = np.broadcast_to(BLACK * 1.4, x.shape + (3,)).copy()
    th = np.arctan2(y, x)
    k = 24
    a = (th / (2 * math.pi) * k) % 1.0
    dia = (np.abs(a - 0.5) * 2 * math.pi * 0.905 / k / 0.012 + np.abs(r - 0.905) / 0.026) < 1
    bcol = mix(bcol, GOLD, dia.astype(float))
    line_in = np.exp(-((r - (R + 0.006)) / 0.0045) ** 2)
    line_out = np.exp(-((r - 0.968) / 0.0045) ** 2)
    line_mid = np.exp(-((r - 0.935) / 0.0018) ** 2) * 0.6
    bcol = mix(bcol, GOLD, np.clip(line_in + line_out, 0, 1))
    bcol = mix(bcol, CRIMSON, line_mid)
    out = over(out, coloured(band.astype(float) + line_out * (r >= 0.975), bcol))
    out[..., 3] *= smooth(0.982, 0.975, r)
    return to_img(down(out, SS))


def sigil_sheet():
    frames = []
    n = FRAME * SS
    x, y = grid(n)
    sm = sigil_mask(n, scale=0.86, cy=0.02, ss=2)
    d = np.sqrt(x * x + (y - 0.02) ** 2)
    halo = ndimage.gaussian_filter(sm, 7 * SS)
    halo2 = ndimage.gaussian_filter(sm, 18 * SS)
    for f in range(16):
        ph = f / 16
        breath = 0.82 + 0.18 * math.sin(2 * math.pi * ph)
        c = -0.15 + ph * 1.3
        pulse = np.exp(-((d - c) / 0.11) ** 2) + np.exp(-((d - (c - 1.3)) / 0.11) ** 2)
        pulse = np.clip(pulse, 0, 1)
        out = layer(np.clip(halo2 * 2.2 * breath, 0, 1) * 0.55, CRIMSON)
        out = over(out, layer(np.clip(halo * 2.5 * breath, 0, 1) * 0.7, CRIMSON))
        core = sm * (0.6 + 0.4 * breath)
        col = mix(np.broadcast_to(CRIMSON, sm.shape + (3,)), PINK, pulse * 0.85)
        col = mix(col, WHITE, np.clip(pulse - 0.55, 0, 1) * 1.6)
        out = over(out, coloured(np.clip(core + pulse * sm * 0.3, 0, 1), col))
        frames.append(to_img(down(out, SS)))
    s = Image.new("RGBA", (FRAME * 4, FRAME * 4), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        s.paste(fr, ((i % 4) * FRAME, (i // 4) * FRAME))
    return s


def eye_sigil(size=256):
    n = size * SS
    x, y = grid(n)
    r = np.sqrt(x * x + y * y)
    sm = sigil_mask(n, scale=0.62, ss=2)
    out = layer(np.clip(1 - r / 0.95, 0, 1) ** 2.2 * 0.85, CRIMSON)
    out = over(out, layer(np.clip(ndimage.gaussian_filter(sm, 5 * SS) * 2.4, 0, 1), np.array([255, 40, 70], float)))
    col = mix(np.broadcast_to(PINK, sm.shape + (3,)), WHITE, smooth(0.5, 0.0, r))
    out = over(out, coloured(sm, col))
    return to_img(down(out, SS))


def wave(size=512):
    n = size * SS
    x, y = grid(n)
    r = np.sqrt(x * x + y * y)
    out = np.zeros((n, n, 4))
    for rr, a in ((0.42, 0.35), (0.66, 0.65), (0.9, 1.0)):
        glow = np.exp(-((r - rr) / 0.05) ** 2)
        core = np.exp(-((r - rr) / 0.011) ** 2)
        out = over(out, layer(glow * a * 0.8, CRIMSON))
        out = over(out, layer(core * a, mix(PINK, WHITE, 0.5)))
    return to_img(down(out, SS))


def mote(size=128):
    n = size * SS
    x, y = grid(n)
    dia = np.abs(x) / 0.22 + np.abs(y) / 0.62
    star = np.clip(1 - dia, 0, 1)
    r = np.sqrt(x * x + y * y)
    out = layer(np.clip(1 - r / 0.9, 0, 1) ** 2.5 * 0.7, CRIMSON)
    out = over(out, layer(smooth(0.0, 0.25, star), mix(PINK, WHITE, 0.4)))
    return to_img(down(out, SS))


def soft(size=256):
    n = size * SS
    x, y = grid(n)
    r = np.sqrt(x * x + y * y)
    return to_img(down(layer(np.clip(1 - r, 0, 1) ** 2.0, WHITE), SS))


def sigil_lit(size=1024):
    """The engraving lit from inside, on the SAME canvas as board.png (scale 0.78, cy 0.02), so a second
    SurfaceGui the board's size lays it exactly on the engraving (a flat particle's in-plane turn is not stable)."""
    n = size * SS
    x, y = grid(n)
    sm = sigil_mask(n, scale=0.78, cy=0.02, ss=2)
    out = layer(np.clip(ndimage.gaussian_filter(sm, 22 * SS) * 2.0, 0, 1) * 0.5, CRIMSON)
    out = over(out, layer(np.clip(ndimage.gaussian_filter(sm, 7 * SS) * 2.4, 0, 1) * 0.75, CRIMSON))
    # the stroke itself: crimson, a hot pink-white spine (the mask eroded) down its middle
    dt = ndimage.distance_transform_edt(sm > 0.5)
    spine = smooth(5 * SS, 16 * SS, dt) * 0.8  # a hot core only where the stroke is thick (body, wing roots)
    col = mix(np.broadcast_to(CRIMSON, sm.shape + (3,)), PINK, spine * 0.8)
    col = mix(col, WHITE, np.clip(spine - 0.5, 0, 1) * 1.2)
    out = over(out, coloured(sm, col))
    return to_img(down(out, SS))


def contact(files):
    tiles = []
    for name, im in files.items():
        b = Image.new("RGBA", (430, 430), (60, 60, 70, 255))
        t = im.copy()
        t.thumbnail((420, 420))
        b.alpha_composite(t, ((430 - t.width) // 2, (430 - t.height) // 2))
        ImageDraw.Draw(b).text((6, 4), name, fill=(255, 220, 120))
        tiles.append(b)
    s = Image.new("RGB", (430 * 3, 430 * ((len(tiles) + 2) // 3)))
    for i, t in enumerate(tiles):
        s.paste(t.convert("RGB"), ((i % 3) * 430, (i // 3) * 430))
    return s


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    only = set(sys.argv[1:])
    makers = {
        "board": board,
        "sigil_4x4": sigil_sheet,
        "sigil_lit": sigil_lit,
        "eye_sigil": eye_sigil,
        "wave": wave,
        "mote": mote,
        "soft": soft,
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
