#!/usr/bin/env python3
"""DragonMonarch (Antares, "Dragon Monarch", Legendary; Solo Leveling's King of Dragons, Monarch of
Destruction) textures. His body keeps the pack aura he wears (Pack1 "Cinder", copied verbatim by the
builder); these add DRAGON imagery round it, never more fire (the owner: flames on every hero are repetitive).

    python tools/auras/dragon_monarch/make_tex.py [names...]   -> assets/auras/dragon_monarch/*.png (+ _sheet.jpg)

All PRE-COLOURED (drawn with Color white, low LightEmission), so they keep their colours on any floor or sky.

  wing_r_4x4.png   16-frame LOOP: his RIGHT dragon wing beating slowly (one cycle): black finger bones with a
                   red rim, a crimson membrane darkening toward the bones, scalloped edges glowing red-orange;
                   the wing's root sits at the frame's LEFT-MIDDLE edge (the builder offsets it from the shoulder)
  wing_l_4x4.png   the same wing mirrored (particles cannot flip a texture)
  seal.png         the Monarch of Destruction's mark (SurfaceGui, turning slowly): a dark stone disc in a ring of
                   scale-pattern, torn by three huge dragon-claw marks glowing molten red inside, cracks of red
                   light spreading from them
  scale.png        one crimson dragon scale (a shield with a ridge, bright edge), drifting up off him

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
OUT = ROOT / "assets" / "auras" / "dragon_monarch"
_spec = importlib.util.spec_from_file_location("et", ROOT / "tools" / "auras" / "emperor_thorns" / "make_tex.py")
K = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(K)
smooth, over, down, grid, to_img, sheet = K.smooth, K.over, K.down, K.grid, K.to_img, K.sheet
SS, F = K.SS, K.F

BONE = np.array([20, 8, 8], float)
MEMB_DARK = np.array([58, 8, 12], float)
MEMB = np.array([128, 18, 24], float)
EDGE = np.array([255, 70, 30], float)
HOT = np.array([255, 170, 80], float)
STONE = np.array([34, 28, 28], float)
STONE_L = np.array([62, 52, 50], float)
CRIMSON = np.array([170, 20, 22], float)
GOLD = np.array([230, 170, 80], float)


def mix(c0, c1, t):
    return K.mix(c0, c1, t)


def layer(alpha, colour):
    out = np.zeros(alpha.shape + (4,))
    out[..., :3] = colour
    out[..., 3] = np.clip(alpha, 0, 1) * 255
    return out


def fbm(shape, scales, seed):
    out = np.zeros(shape)
    for i, s in enumerate(scales):
        n = np.random.default_rng(seed + i).standard_normal(shape)
        f = ndimage.gaussian_filter(n, s, mode="wrap")
        out += f / (np.abs(f).max() + 1e-9) / (i + 1)
    return out / sum(1 / (i + 1) for i in range(len(scales)))


def stroke(draw, pts, w0, w1, fill=255):
    n = len(pts)
    for i in range(n - 1):
        t0, t1 = i / (n - 1), (i + 1) / (n - 1)
        a, b = pts[i], pts[i + 1]
        wa, wb = w0 + (w1 - w0) * t0, w0 + (w1 - w0) * t1
        d = (b[0] - a[0], b[1] - a[1])
        L = math.hypot(*d) + 1e-9
        nx, ny = -d[1] / L, d[0] / L
        draw.polygon([(a[0] + nx * wa, a[1] + ny * wa), (b[0] + nx * wb, b[1] + ny * wb),
                      (b[0] - nx * wb, b[1] - ny * wb), (a[0] - nx * wa, a[1] - ny * wa)], fill=fill)
        draw.ellipse([b[0] - wb, b[1] - wb, b[0] + wb, b[1] + wb], fill=fill)


# ---------------------------------------------------------------- the wing
# wing space: root at (0, 0), +x outward, +y up; units = frame width
WRIST = (0.36, 0.16)
TIPS = [(0.96, 0.36), (0.97, 0.04), (0.84, -0.26), (0.6, -0.46)]
TAIL = (0.06, -0.3)  # where the membrane meets his back


def wing_frame(t, n):
    """One frame of the right wing at phase t (0..1). Root at the frame's left-middle edge."""
    # the beat: up-stroke and down-stroke, eased; the wing folds a little at the bottom of the stroke
    phase = math.sin(t * 2 * math.pi)
    ang = math.radians(14 * phase + 4)  # rotate the whole wing about its root
    fold = 0.9 + 0.1 * (0.5 + 0.5 * phase)  # spread most at the top of the stroke
    fore = 0.92 + 0.08 * math.cos(t * 2 * math.pi)  # foreshortening

    def P(p):
        x, y = p[0] * fore * fold, p[1] * fold
        c, s = math.cos(ang), math.sin(ang)
        xr, yr = x * c - y * s, x * s + y * c
        return (xr * n * 0.86 + n * 0.01, n * 0.5 - yr * n * 0.86)  # 0.98 clipped the tips at the top of the beat

    root, wrist = P((0, 0)), P(WRIST)
    tips = [P(tp) for tp in TIPS]
    tail = P(TAIL)
    # membrane: root -> wrist -> tip0 -> scallops between tips -> last tip -> tail -> root
    poly = [root, wrist, tips[0]]
    for a, b in zip(tips[:-1], tips[1:]):
        # a scallop curving in toward the wrist between two finger tips
        mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        cx = mx + (wrist[0] - mx) * 0.22
        cy = my + (wrist[1] - my) * 0.22
        for k in range(1, 8):
            u = k / 8
            # quadratic bezier a -> c -> b
            x = (1 - u) ** 2 * a[0] + 2 * (1 - u) * u * cx + u ** 2 * b[0]
            y = (1 - u) ** 2 * a[1] + 2 * (1 - u) * u * cy + u ** 2 * b[1]
            poly.append((x, y))
        poly.append(b)
    # last scallop down to the tail
    a, b = tips[-1], tail
    mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
    cx, cy = mx + (root[0] - mx) * 0.3, my + (root[1] - my) * 0.3 - n * 0.02
    for k in range(1, 10):
        u = k / 10
        poly.append(((1 - u) ** 2 * a[0] + 2 * (1 - u) * u * cx + u ** 2 * b[0],
                     (1 - u) ** 2 * a[1] + 2 * (1 - u) * u * cy + u ** 2 * b[1]))
    poly.append(tail)
    mem = Image.new("L", (n, n), 0)
    ImageDraw.Draw(mem).polygon(poly, fill=255)
    mm = np.asarray(mem, float) / 255 > 0.5
    # bones
    bones = Image.new("L", (n, n), 0)
    bd = ImageDraw.Draw(bones)
    stroke(bd, [root, wrist], n * 0.03, n * 0.022)
    for tp in tips:
        stroke(bd, [wrist, tp], n * 0.017, n * 0.004)
    # thumb claw up from the wrist
    claw = P((WRIST[0] + 0.05, WRIST[1] + 0.13))
    stroke(bd, [wrist, claw], n * 0.014, n * 0.002)
    bm = np.asarray(bones, float) / 255 > 0.5
    # colour the membrane: dark at the bones, crimson in the panels, a glowing scalloped edge
    dbone = ndimage.distance_transform_edt(~bm)
    dedge = ndimage.distance_transform_edt(mm)
    col = mix(MEMB_DARK, MEMB, smooth(n * 0.01, n * 0.12, dbone))
    veins = fbm((n, n), [n * 0.004, n * 0.012], 5) if False else None
    col = mix(col, EDGE, (1 - smooth(1.5 * SS, n * 0.03, dedge)) * 0.9)
    col = mix(col, HOT, (1 - smooth(0.5 * SS, 2.2 * SS, dedge)) * 0.8)
    out = layer(ndimage.gaussian_filter(mm.astype(float), n * 0.012) * 0.55, EDGE)  # a red glow round it
    memb = np.zeros((n, n, 4))
    memb[..., :3] = col
    memb[..., 3] = mm * 0.9 * 255
    out = over(out, memb)
    din = ndimage.distance_transform_edt(bm)
    bcol = np.where((din < 1.6 * SS)[..., None], mix(BONE, EDGE, 0.7), BONE)
    bl = np.zeros((n, n, 4))
    bl[..., :3] = bcol
    bl[..., 3] = bm * 255
    out = over(out, bl)
    return out


def wing(mirror=False, frame=256):
    n = frame * SS
    frames = []
    for f in range(16):
        img = to_img(down(wing_frame(f / 16, n), SS))
        if mirror:
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
        frames.append(img)
    return sheet(frames)


# ---------------------------------------------------------------- the Monarch of Destruction's mark
def seal(size=1024):
    n = size * SS
    x, y = grid(n)
    r = np.sqrt(x * x + y * y)
    th = np.arctan2(y, x)
    noise = fbm((n, n), [3 * SS, 9 * SS], 21)
    out = np.zeros((n, n, 4))
    out = over(out, layer(np.clip(1 - (r - 0.9) / 0.1, 0, 1) * (r > 0.9) * 0.5, np.array([10, 5, 5], float)))
    # stone disc
    disc = r < 0.95
    scol = mix(STONE, STONE_L, np.clip(noise * 0.8 + 0.4, 0, 1))
    sl = np.zeros((n, n, 4))
    sl[..., :3] = scol
    sl[..., 3] = disc * 0.95 * 255
    out = over(out, sl)
    # a ring of dragon scales between r 0.8 and 0.93
    rows = 2
    band = (r > 0.8) & (r < 0.93)
    k = 48
    u = (th / (2 * math.pi) * k) % 1.0
    v = (r - 0.8) / 0.13 * rows
    vi = np.floor(v)
    u2 = (u + 0.5 * (vi % 2)) % 1.0
    vf = v - vi
    sc = ((u2 - 0.5) ** 2 / 0.25 + (vf - 0.15) ** 2 / 0.7) < 1
    edge_sc = sc & ~(((u2 - 0.5) ** 2 / 0.2 + (vf - 0.15) ** 2 / 0.55) < 1)
    sccol = mix(CRIMSON * 0.45, CRIMSON, np.clip(vf, 0, 1))
    scl = np.zeros((n, n, 4))
    scl[..., :3] = np.where(edge_sc[..., None], EDGE * 0.8, sccol)
    scl[..., 3] = (band & sc) * 255
    out = over(out, scl)
    for rr, w in ((0.95, 0.006), (0.935, 0.003), (0.8, 0.005)):
        out = over(out, layer((np.abs(r - rr) < w) * 1.0, GOLD))
    # three dragon-claw gouges across the middle
    claws = Image.new("L", (n, n), 0)
    cd = ImageDraw.Draw(claws)
    for k2, off in enumerate((-0.2, 0.0, 0.2)):
        pts = []
        for i in range(30):
            s_ = i / 29
            px_ = -0.55 + 1.1 * s_
            py_ = off + 0.18 * math.sin(s_ * math.pi) - 0.1 * s_
            pts.append(((1 + px_ * 0.95 + py_ * 0.3) / 2 * n, (1 - (py_ - px_ * 0.3)) / 2 * n))
        w_mid = n * 0.035
        for i in range(len(pts) - 1):
            s_ = i / (len(pts) - 1)
            w = w_mid * math.sin(math.pi * min(max(s_, 0.02), 0.98)) ** 0.7
            stroke(cd, [pts[i], pts[i + 1]], w, w)
    cm = np.asarray(claws, float) / 255 > 0.5
    # cracks spreading from the gouges
    rng = np.random.default_rng(9)
    cracks = Image.new("L", (n, n), 0)
    kd = ImageDraw.Draw(cracks)
    ys, xs = np.nonzero(cm)
    for _ in range(34):
        i = rng.integers(0, len(xs))
        p = np.array([xs[i], ys[i]], float)
        ang = rng.uniform(0, 2 * math.pi)
        pts = [tuple(p)]
        for _ in range(rng.integers(4, 9)):
            ang += rng.uniform(-0.6, 0.6)
            p = p + np.array([math.cos(ang), math.sin(ang)]) * n * rng.uniform(0.02, 0.045)
            pts.append(tuple(p))
        kd.line(pts, fill=255, width=int(rng.uniform(1.4, 3.0) * SS))
    km = (np.asarray(cracks, float) / 255 > 0.5) & (r < 0.78) & ~cm
    out = over(out, layer(ndimage.gaussian_filter(km.astype(float), 4 * SS) * 1.6, EDGE))
    out = over(out, layer(km * 1.0, HOT))
    # the gouges: black rims, molten red-orange deep inside
    din = ndimage.distance_transform_edt(cm)
    gcol = np.zeros((n, n, 3))
    gcol[:] = BONE
    gcol = mix(gcol, CRIMSON, smooth(2 * SS, 7 * SS, din))
    gcol = mix(gcol, EDGE, smooth(6 * SS, 14 * SS, din))
    gcol = mix(gcol, HOT, smooth(12 * SS, 22 * SS, din))
    out = over(out, layer(ndimage.gaussian_filter(cm.astype(float), 7 * SS) * 1.3, EDGE))
    gl = np.zeros((n, n, 4))
    gl[..., :3] = gcol
    gl[..., 3] = cm * 255
    out = over(out, gl)
    return to_img(down(out, SS))


def scale_tex(size=128):
    n = size * SS
    x, y = grid(n)
    # a shield: round top, pointed bottom
    # a scale: round shoulders, a long pointed tip at the bottom
    m = (x ** 2 / 0.5 ** 2 + (y - 0.3) ** 2 / 0.5 ** 2 < 1) | ((y < 0.3) & (y > -0.9) & (np.abs(x) < 0.5 * ((y + 0.9) / 1.2) ** 1.4))
    din = ndimage.distance_transform_edt(m)
    col = mix(CRIMSON * 0.5, CRIMSON, smooth(-0.6, 0.6, y))
    ridge = (np.abs(x) < 0.04) & m
    col = np.where(ridge[..., None], mix(CRIMSON, EDGE, 0.6), col)
    col = np.where((din < 2.2 * SS)[..., None], EDGE, col)
    rgba = np.zeros((n, n, 4))
    rgba[..., :3] = col
    rgba[..., 3] = m * 255
    return to_img(down(rgba, SS))


def contact(files):
    tiles = []
    for name, im in files.items():
        t = im.copy()
        t.thumbnail((420, 420))
        for bg in ((60, 70, 120), (235, 210, 60)):
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
        "wing_r_4x4": lambda: wing(False),
        "wing_l_4x4": lambda: wing(True),
        "seal": seal,
        "scale": scale_tex,
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
