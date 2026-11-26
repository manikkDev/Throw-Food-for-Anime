#!/usr/bin/env python3
"""AntiMagic (Liebe, "Devil Knight", Legendary) textures: the base and accents round his wing.

    python tools/auras/anti_magic/make_tex.py [names...]   -> assets/auras/anti_magic/*.png (+ _sheet.jpg)

His body keeps the pack aura he wears (Pack9 "one winged angel": a black wing with black mist and feathers,
copied verbatim by the builder): the single black wing is how anti-magic first shows in Black Clover. These
textures add his own imagery round it. A DARK aura must not glow: everything here is PRE-COLOURED (black
core, ash-white rim, a hair of blood red) and drawn with Color white, LightEmission 0, LightInfluence 0.

  seal.png          the grimoire seal (SurfaceGui, turning): a black five-leaf clover (his grimoire) with silver
                    edges and blood-red veins, a red devil's eye at its heart, inside a black band where white
                    anti-magic crackle runs round between silver rings
  clover.png        one black five-leaf clover (his grimoire's emblem): silver edges, blood-red veins, a soft dark
                    shadow; five of them glide round him, turning smoothly (Rotation, not a flipbook)
  leaf.png          one heart-shaped leaf of it, for the leaves that come away and float off
  slash_4x4.png     16-frame ONE-SHOT black anti-magic sword cut: a black crescent with an ash-white edge and a
                    red inner line sweeps out (0-6), then crumbles away (7-15)
(v1's flame-shaped miasma and v2's grimoire pages are gone: the owner asked for no flames, then for the
five-leaf clover moving smoothly instead of pages, 2026-11-25)
  crackle_4x4.png   16-frame LOOP of black anti-magic lightning: a new jagged branched bolt each frame, black core,
                    thin dark-red then ash rim
  shard.png         a black anti-magic flake: a sharp sliver with an ash edge

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
OUT = ROOT / "assets" / "auras" / "anti_magic"
_spec = importlib.util.spec_from_file_location("et", ROOT / "tools" / "auras" / "emperor_thorns" / "make_tex.py")
K = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(K)
smooth, over, down, grid, to_img, sheet = K.smooth, K.over, K.down, K.grid, K.to_img, K.sheet
SS, F = K.SS, K.F

BLACK = np.array([8, 7, 10], float)
CHAR = np.array([28, 24, 30], float)  # a lifted black, for depth inside shapes
ASH = np.array([226, 222, 214], float)  # anti-magic's white edge
SILVER = np.array([196, 200, 210], float)
BLOOD = np.array([150, 14, 24], float)
RED = np.array([220, 30, 40], float)


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


def bolt_path(rng, p0, p1, rough, depth):
    pts = [np.array(p0, float), np.array(p1, float)]
    for _ in range(depth):
        nxt = [pts[0]]
        for a, b in zip(pts[:-1], pts[1:]):
            d = b - a
            m = (a + b) / 2 + np.array([-d[1], d[0]]) * rng.uniform(-rough, rough)
            nxt += [m, b]
        pts = nxt
        rough *= 0.55
    return pts


# ---------------------------------------------------------------- the grimoire seal
def clover_mask(n, scale=1.0):
    """Five heart-shaped leaves round the centre (his five-leaf grimoire), as a boolean mask."""
    x, y = grid(n)
    m = np.zeros((n, n), bool)
    for i in range(5):
        a = math.pi / 2 + i * 2 * math.pi / 5
        ux, uy = math.cos(a), math.sin(a)
        px, py = -uy, ux
        # leaf frame: along (axis), across (side)
        al = x * ux + y * uy
        ac = x * px + y * py
        r0, lobe, lr = 0.36 * scale, 0.095 * scale, 0.135 * scale
        lobes = ((al - r0) ** 2 + (ac - lobe) ** 2 < lr ** 2) | ((al - r0) ** 2 + (ac + lobe) ** 2 < lr ** 2)
        # the point toward the centre: a triangle from the lobes' base to near the middle
        t = (al - 0.06 * scale) / (r0 - 0.06 * scale)
        wedge = (t > 0) & (t < 1.05) & (np.abs(ac) < (0.205 * scale) * np.clip(t, 0, 1) ** 0.9)
        # the heart's notch at the outer end
        notch = ((al - (r0 + lr * 0.95)) ** 2 + ac ** 2) < (0.045 * scale) ** 2
        m |= (lobes | wedge) & ~notch
    return m


def seal(size=1024):
    n = size * SS
    x, y = grid(n)
    r = np.sqrt(x * x + y * y)
    th = np.arctan2(y, x)
    out = np.zeros((n, n, 4))
    # a dark soft shadow under it all, so it reads on a pale or bright floor
    out = over(out, layer(smooth(1.0, 0.86, r) * 0.55, BLACK))
    # the outer band: black, silver rings either side, ash crackle running round inside it
    band = (r > 0.80) & (r < 0.955)
    out = over(out, layer(band * 0.92, BLACK))
    rng = np.random.default_rng(31)
    crack = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(crack)
    segs = 10
    for k in range(segs):
        a0 = k / segs * 2 * math.pi
        a1 = (k + 1) / segs * 2 * math.pi
        rr0, rr1 = rng.uniform(0.84, 0.92), rng.uniform(0.84, 0.92)
        p0 = ((1 + rr0 * math.cos(a0)) / 2 * n, (1 - rr0 * math.sin(a0)) / 2 * n)
        p1 = ((1 + rr1 * math.cos(a1)) / 2 * n, (1 - rr1 * math.sin(a1)) / 2 * n)
        pts = bolt_path(rng, p0, p1, 0.22, 5)
        d.line([tuple(p) for p in pts], fill=255, width=int(3.4 * SS))
        if rng.random() < 0.6:  # a small fork
            j = rng.integers(4, len(pts) - 4)
            q = pts[j] + rng.uniform(-1, 1, 2) * n * 0.02
            d.line([tuple(p) for p in bolt_path(rng, pts[j], q, 0.3, 3)], fill=255, width=int(1.4 * SS))
    cm = np.asarray(crack, float) / 255 * band
    out = over(out, layer(ndimage.gaussian_filter(cm, 4 * SS) * 1.8, mix(BLOOD, RED, 0.4)))
    out = over(out, layer(cm, ASH))
    for rr, w in ((0.97, 0.007), (0.955, 0.004), (0.80, 0.006), (0.785, 0.003)):
        m = np.abs(r - rr) < w
        out = over(out, layer(m * 1.0, SILVER))
    # inner field: a faint blood-red glow pool
    # inner field: a solid dark disc (see-through, it went muddy on a yellow stand), a blood-red glow at its heart
    out = over(out, layer((r < 0.785) * 0.9, mix(BLACK, CHAR, 0.5)))
    out = over(out, layer(np.clip(1 - r / 0.78, 0, 1) ** 1.6 * 0.55 * (r < 0.78), BLOOD))
    # five short silver spikes in the gaps between the leaves (pointing out)
    spikes = np.zeros((n, n), bool)
    for i in range(5):
        a = math.pi / 2 + (i + 0.5) * 2 * math.pi / 5
        ux, uy = math.cos(a), math.sin(a)
        al = x * ux + y * uy
        ac = np.abs(-x * uy + y * ux)
        t = (al - 0.46) / 0.28
        spikes |= (t > 0) & (t < 1) & (ac < 0.028 * (1 - t))
    out = over(out, layer(spikes * 1.0, SILVER))
    # the clover: black leaves, silver outline, blood-red veins
    cl = clover_mask(n)
    din = ndimage.distance_transform_edt(cl)
    leaf = np.zeros((n, n, 4))
    col = np.zeros((n, n, 3))
    col[:] = BLACK
    col = mix(col, CHAR, smooth(4 * SS, 30 * SS, din))
    leaf[..., :3] = col
    leaf[..., 3] = cl * 255
    out = over(out, layer(ndimage.gaussian_filter(cl.astype(float), 6 * SS) * 0.9, BLACK))  # drop shadow
    out = over(out, leaf)
    # veins: a midrib down each leaf and the heart lines
    veins = Image.new("L", (n, n), 0)
    vd = ImageDraw.Draw(veins)
    for i in range(5):
        a = math.pi / 2 + i * 2 * math.pi / 5
        c, s = math.cos(a), math.sin(a)

        def P(al, ac):
            return ((1 + al * c - ac * s) / 2 * n, (1 - (al * s + ac * c)) / 2 * n)

        vd.line([P(0.08, 0), P(0.42, 0)], fill=255, width=int(2.4 * SS))
        for sgn in (1, -1):
            vd.line([P(0.2, 0), P(0.34, sgn * 0.09)], fill=255, width=int(1.6 * SS))
            vd.line([P(0.3, 0), P(0.42, sgn * 0.1)], fill=255, width=int(1.4 * SS))
    vm = np.asarray(veins, float) / 255 * cl
    out = over(out, layer(ndimage.gaussian_filter(vm, 2 * SS) * 1.4, RED))
    out = over(out, layer(vm * 0.9, BLOOD))
    edge = cl & (din < 2.6 * SS)
    out = over(out, layer(edge * 1.0, SILVER))
    # the devil's eye at the heart: a red slit in a black almond with a silver rim
    ax, ay = x / 0.11, y / 0.055
    almond = ax ** 2 + ay ** 2 < 1
    out = over(out, layer(almond * 1.0, BLACK))
    rim = almond & (ndimage.distance_transform_edt(almond) < 2.0 * SS)
    out = over(out, layer(rim * 1.0, SILVER))
    slit = (np.abs(x) < 0.016 * np.sqrt(np.clip(1 - (y / 0.05) ** 2, 0, 1))) & almond
    out = over(out, layer(ndimage.gaussian_filter(slit.astype(float), 3 * SS) * 1.5, RED))
    out = over(out, layer(slit * 1.0, mix(RED, ASH, 0.25)))
    return to_img(down(out, SS))


# ---------------------------------------------------------------- the clover emblem and its leaf
def _emblem(mask, n, veins_fn):
    """Pre-colour a leaf/clover mask: black body lifted inside, red veins, silver edge, soft dark shadow."""
    din = ndimage.distance_transform_edt(mask)
    col = np.zeros((n, n, 3))
    col[:] = BLACK
    col = mix(col, CHAR, smooth(3 * SS, 24 * SS, din))
    body = np.zeros((n, n, 4))
    body[..., :3] = col
    body[..., 3] = mask * 255
    out = layer(ndimage.gaussian_filter(mask.astype(float), 5 * SS) * 0.7, BLACK)
    out = over(out, body)
    vm = veins_fn() * mask
    out = over(out, layer(ndimage.gaussian_filter(vm, 2 * SS) * 1.5, RED))
    out = over(out, layer(vm * 0.9, BLOOD))
    out = over(out, layer((mask & (din < 2.4 * SS)) * 1.0, SILVER))
    return out


def clover(size=256):
    n = size * SS
    x0, y0 = grid(n)
    # 1.7x the seal's clover (2x clipped the canvas edge), the gaps at its heart filled so it is one emblem
    m = clover_mask(n, scale=1.7) | (x0 * x0 + y0 * y0 < 0.3 ** 2)

    def veins():
        v = Image.new("L", (n, n), 0)
        d = ImageDraw.Draw(v)
        for i in range(5):
            a = math.pi / 2 + i * 2 * math.pi / 5
            c, s_ = math.cos(a), math.sin(a)

            def P(al, ac):
                return ((1 + al * c - ac * s_) / 2 * n, (1 - (al * s_ + ac * c)) / 2 * n)

            d.line([P(0.2, 0), P(0.72, 0)], fill=255, width=int(3 * SS))
            for sgn in (1, -1):
                d.line([P(0.38, 0), P(0.6, sgn * 0.15)], fill=255, width=int(2 * SS))
        return np.asarray(v, float) / 255

    out = _emblem(m, n, veins)
    # the devil's eye at the heart, small
    x, y = grid(n)
    almond = (x / 0.13) ** 2 + (y / 0.065) ** 2 < 1
    out = over(out, layer(almond * 1.0, BLACK))
    out = over(out, layer((almond & (ndimage.distance_transform_edt(almond) < 1.8 * SS)) * 1.0, SILVER))
    slit = (np.abs(x) < 0.02 * np.sqrt(np.clip(1 - (y / 0.06) ** 2, 0, 1))) & almond
    out = over(out, layer(slit * 1.0, RED))
    return to_img(down(out, SS))


def leaf(size=128):
    n = size * SS
    x, y = grid(n)
    # one heart-shaped leaf pointing down (the clover's centre end), lobes up
    lobes = ((x - 0.28) ** 2 + (y - 0.28) ** 2 < 0.36 ** 2) | ((x + 0.28) ** 2 + (y - 0.28) ** 2 < 0.36 ** 2)
    t = (y + 0.9) / 1.2
    wedge = (t > 0) & (t < 1.0) & (np.abs(x) < 0.62 * np.clip(t, 0, 1) ** 0.9)
    notch = (x ** 2 + (y - 0.62) ** 2) < 0.1 ** 2
    m = (lobes | wedge) & ~notch & (y > -0.9)

    def veins():
        v = Image.new("L", (n, n), 0)
        d = ImageDraw.Draw(v)
        d.line([(n * 0.5, n * 0.93), (n * 0.5, n * 0.3)], fill=255, width=int(2.4 * SS))
        for sgn in (1, -1):
            d.line([(n * 0.5, n * 0.62), (n * (0.5 + sgn * 0.22), n * 0.36)], fill=255, width=int(1.6 * SS))
        return np.asarray(v, float) / 255

    return to_img(down(_emblem(m, n, veins), SS))


# ---------------------------------------------------------------- black anti-magic sword cut (one-shot)
def slash(frame=256):
    n = frame * SS
    x, y = grid(n)
    r = np.sqrt(x * x + y * y)
    th = (np.arctan2(y, x) + 2 * math.pi) % (2 * math.pi)
    noise = fbm((n, n), [5 * SS, 2 * SS], 801, wrap=False)
    frames = []
    total = math.radians(230)
    start = math.radians(205)
    for f in range(16):
        head = total * smooth(0, 6.5, f) if f <= 7 else total
        tail = 0.0 if f <= 6 else total * smooth(6, 15.5, f) * 1.02
        a = (start - th) % (2 * math.pi)
        arc = (a >= tail) & (a <= head)
        u = np.clip((a - tail) / max(head - tail, 1e-3), 0, 1)
        thick = 0.04 + 0.3 * np.sin(u * math.pi) ** 0.8
        mid = 0.66
        m = arc & (r > mid - thick * 0.45) & (r < mid + thick * 0.55 + 0.03 * noise)
        if f >= 9:  # crumbling away into flakes
            m &= noise + (u - 0.2) * 2.4 > (f - 9) / 6 * 1.4 - 0.4
        din = ndimage.distance_transform_edt(m)
        col = np.zeros((n, n, 3))
        col[:] = BLACK
        col = mix(col, CHAR, smooth(4 * SS, 14 * SS, din) * 0.6)
        # a thin red line inside the cut, the ash-white edge outside
        redline = m & (np.abs(r - (mid + thick * 0.1)) < 0.006) & (din > 3 * SS)
        col = np.where(redline[..., None], RED, col)
        col = np.where((m & (din < 2.6 * SS))[..., None], ASH, col)
        rgba = np.zeros((n, n, 4))
        rgba[..., :3] = col
        rgba[..., 3] = m * 255
        sh = ndimage.gaussian_filter(m.astype(float), 4 * SS) * 0.45
        frames.append(to_img(down(over(layer(sh, BLACK), rgba), SS)))
    return sheet(frames)


# ---------------------------------------------------------------- black lightning (loop)
def crackle(frame=256):
    rng = np.random.default_rng(707)
    n = frame * SS
    frames = []
    for f in range(16):
        core = Image.new("L", (n, n), 0)
        d = ImageDraw.Draw(core)
        a0 = rng.uniform(0, math.pi)
        p0 = np.array([0.5 + 0.44 * math.cos(a0), 0.5 + 0.44 * math.sin(a0)]) * n
        p1 = np.array([0.5 - 0.44 * math.cos(a0), 0.5 - 0.44 * math.sin(a0)]) * n
        main = bolt_path(rng, p0, p1, 0.34, 6)
        d.line([tuple(p) for p in main], fill=255, width=int(3.2 * SS))
        for _ in range(rng.integers(2, 5)):
            i = rng.integers(5, len(main) - 6)
            e = main[i] + rng.uniform(-1, 1, 2) * n * 0.22
            d.line([tuple(p) for p in bolt_path(rng, main[i], e, 0.4, 4)], fill=255, width=int(1.8 * SS))
        m = np.asarray(core, float) / 255
        red = ndimage.gaussian_filter(m, 2.2 * SS) * 2.2
        ash = ndimage.gaussian_filter(m, 5 * SS) * 1.4
        rgba = np.zeros((n, n, 4))
        out = layer(np.clip(ash, 0, 1) * 0.8, ASH)
        out = over(out, layer(np.clip(red, 0, 1), BLOOD))
        out = over(out, layer(m, BLACK))
        rgba = out
        frames.append(to_img(down(rgba, SS)))
    return sheet(frames)


def shard(size=128):
    n = size * SS
    img = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(img)
    d.polygon([(n * 0.5, n * 0.06), (n * 0.62, n * 0.5), (n * 0.5, n * 0.94), (n * 0.41, n * 0.48)], fill=255)
    m = np.asarray(img, float) / 255 > 0.5
    din = ndimage.distance_transform_edt(m)
    col = np.zeros((n, n, 3))
    col[:] = BLACK
    col = np.where((din < 2.2 * SS)[..., None], ASH, col)
    rgba = np.zeros((n, n, 4))
    rgba[..., :3] = col
    rgba[..., 3] = m * 255
    return to_img(down(rgba, SS))


def contact(files):
    tiles = []
    for name, im in files.items():
        t = im.copy()
        t.thumbnail((420, 420))
        for bg in ((40, 44, 70), (235, 210, 60)):
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
    makers = {"seal": seal, "clover": clover, "leaf": leaf, "slash_4x4": slash, "crackle_4x4": crackle, "shard": shard}
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
