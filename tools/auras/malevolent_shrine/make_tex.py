#!/usr/bin/env python3
"""MalevolentShrine (Ryomen Sukuna, "Curse King", Mythic) textures.

    python tools/auras/malevolent_shrine/make_tex.py [names...]   -> assets/auras/malevolent_shrine/*.png

His body keeps the KingOfCurses aura he wore (copied verbatim by the builder, as his red cursed energy). These add
his technique and his domain, drawn the way the anime shows them: Dismantle as volleys of razor-thin, perfectly
straight slash lines crossing at sharp angles with a flash; Cleave as a heavier cut that opens the air; its
domain's slashes shredding the ground. All PRE-COLOURED (a white-hot core,
a crimson fringe and a black hairline so a slash reads on the bright 13:12 sky as well as at night).

  dismantle_4x4.png  16-frame ONE-SHOT volley: five razor slashes cut in one after another (mostly parallel, one
                     crossing), each with a white flash where it lands, linger a beat, thin out and vanish
  cleave_4x4.png     16-frame ONE-SHOT heavy X cut: two long cuts, each opening a black void line in the air with
                     white edges and a red glow, the second a beat after the first; they close and fade
  seal.png           the domain on the floor (SurfaceGui): a dark blood pool with ripples, a ring of fangs (the
                     shrine's maw), carved slash scars, a band of kanji 伏魔御廚子 (Fukuma Mizushi) with skulls
(the shrine silhouette that stood behind him was removed at the owner's request, 2026-11-25)

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
OUT = ROOT / "assets" / "auras" / "malevolent_shrine"
_spec = importlib.util.spec_from_file_location("et", ROOT / "tools" / "auras" / "emperor_thorns" / "make_tex.py")
K = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(K)
smooth, over, down, grid, to_img, sheet = K.smooth, K.over, K.down, K.grid, K.to_img, K.sheet
SS, F = K.SS, K.F
FONT = Path("C:/Windows/Fonts/YuGothB.ttc")

WHITE = np.array([255, 252, 250], float)
CRIMSON = np.array([200, 16, 28], float)
BLOOD = np.array([110, 6, 12], float)
DEEP = np.array([40, 4, 6], float)
BLACK = np.array([8, 4, 6], float)
BONE = np.array([232, 224, 206], float)
EMBER = np.array([255, 90, 40], float)


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


def slash_layer(x, y, cx, cy, ang, length, width, draw=1.0, fade=1.0, from_end=-1):
    """One razor slash: a needle tapered at both ends. draw = how much of it has been cut (0..1, from one end),
    width = half-thickness of the core at its middle. Returns RGBA (core white, crimson fringe, black hairline)."""
    ux, uy = math.cos(ang), math.sin(ang)
    al = (x - cx) * ux + (y - cy) * uy
    ac = -(x - cx) * uy + (y - cy) * ux
    half = length / 2
    s = (al + half) / length  # 0..1 along it
    if from_end > 0:
        s = 1 - s
    vis = (s >= 0) & (s <= draw) & (np.abs(al) <= half)
    taper = np.clip(np.sin(np.clip((al + half) / length, 0, 1) * math.pi), 0, 1) ** 0.6
    w = width * taper
    d = np.abs(ac)
    core = (d < w) & vis
    fringe = (d < w + 0.006) & vis
    hair = (d < w + 0.0095) & vis
    glow = np.exp(-(d / (w * 4 + 0.004)) ** 2) * taper * vis * 0.5
    out = layer(hair * 0.85 * fade, BLACK)
    out = over(out, layer(fringe * fade, CRIMSON))
    out = over(out, layer(glow * fade, mix(CRIMSON, WHITE, 0.4)))
    out = over(out, layer(core * fade, WHITE))
    return out


# ---------------------------------------------------------------- Dismantle: a volley of razor slashes
def dismantle(frame=256):
    n = frame * SS
    x, y = grid(n)
    rng = np.random.default_rng(1234)
    base = math.radians(28)
    lines = []
    for i in range(5):
        crossing = i == 3
        ang = base + (math.radians(74) if crossing else rng.uniform(-0.13, 0.13))
        lines.append({
            "t0": [0, 1, 1, 2, 3][i],
            "ang": ang,
            "cx": rng.uniform(-0.18, 0.18),
            "cy": rng.uniform(-0.3, 0.3),
            "L": rng.uniform(1.25, 1.7) if not crossing else 1.1,
            "w": rng.uniform(0.009, 0.013),  # 0.006-0.009 went pink-thin on the sky
            "end": 1 if i % 2 else -1,
        })
    frames = []
    for f in range(16):
        out = np.zeros((n, n, 4))
        for ln in lines:
            age = f - ln["t0"]
            if age < 0:
                continue
            draw = 0.55 if age == 0 else 1.0  # cut in over a frame and a half: too fast to follow
            fade = 1.0 if age < 5 else max(0.0, 1 - (age - 5) / 6)
            thin = 1.0 if age < 4 else max(0.25, 1 - (age - 4) * 0.15)
            if fade <= 0:
                continue
            out = over(out, slash_layer(x, y, ln["cx"], ln["cy"], ln["ang"], ln["L"], ln["w"] * thin, draw, fade, ln["end"]))
            if age <= 1:  # the hit flash where it lands
                fx = ln["cx"] + math.cos(ln["ang"]) * ln["L"] * 0.1
                fy = ln["cy"] + math.sin(ln["ang"]) * ln["L"] * 0.1
                r = np.sqrt((x - fx) ** 2 + (y - fy) ** 2)
                fl = np.clip(1 - r / (0.12 if age == 0 else 0.07), 0, 1) ** 2
                out = over(out, layer(fl * (1.0 if age == 0 else 0.5), WHITE))
        frames.append(to_img(down(out, SS)))
    return sheet(frames)


# ---------------------------------------------------------------- Cleave: an X that opens the air
def void_cut(x, y, ang, L, open_w, fade):
    ux, uy = math.cos(ang), math.sin(ang)
    al = x * ux + y * uy
    ac = -x * uy + y * ux
    half = L / 2
    vis = np.abs(al) <= half
    taper = np.clip(np.sin(np.clip((al + half) / L, 0, 1) * math.pi), 0, 1) ** 0.7
    w = open_w * taper
    d = np.abs(ac)
    void = (d < w) & vis
    edge = (d >= w) & (d < w + 0.009) & vis
    glow = np.exp(-((d - w) / 0.05) ** 2) * taper * vis * 0.75
    out = layer(glow * fade, CRIMSON)
    out = over(out, layer(edge * fade, WHITE))
    out = over(out, layer(void * fade, BLACK))
    return out


def cleave(frame=256):
    n = frame * SS
    x, y = grid(n)
    frames = []
    cuts = [(math.radians(40), 0), (math.radians(-38), 2)]
    for f in range(16):
        out = np.zeros((n, n, 4))
        for ang, t0 in cuts:
            age = f - t0
            if age < 0:
                continue
            open_w = 0.004 + 0.028 * smooth(0, 2, age) * (1 - smooth(5, 12, age))
            fade = 1 - smooth(8, 14, age)
            if fade <= 0:
                continue
            L = 1.7 * smooth(-1, 1, age)
            out = over(out, void_cut(x, y, ang, max(L, 0.3), open_w, fade))
            if age == 0:
                r = np.sqrt(x * x + y * y)
                out = over(out, layer(np.clip(1 - r / 0.35, 0, 1) ** 2 * 0.8, WHITE))
        frames.append(to_img(down(out, SS)))
    return sheet(frames)


# ---------------------------------------------------------------- the domain on the floor
def skull_mask(n, cx, cy, s, up_angle):
    """A small skull (cranium, two eye sockets, a jaw), its top pointing along up_angle. Returns (bone, holes)."""
    img = Image.new("L", (n, n), 0)
    holes = Image.new("L", (n, n), 0)
    d, h = ImageDraw.Draw(img), ImageDraw.Draw(holes)
    c, s_ = math.cos(up_angle), math.sin(up_angle)

    def P(u, v):  # u across, v up (in skull units)
        return (cx + (u * s_ * -1 + v * c) * s, cy - (u * c + v * s_) * s) if False else (
            cx + (u * math.cos(up_angle - math.pi / 2) + v * c) * s,
            cy - (u * math.sin(up_angle - math.pi / 2) + v * s_) * s,
        )

    pts = [P(math.cos(t) * 0.5, 0.15 + math.sin(t) * 0.45) for t in np.linspace(0, math.pi * 2, 24)]
    d.polygon(pts, fill=255)
    d.polygon([P(-0.28, -0.1), P(0.28, -0.1), P(0.22, -0.48), P(-0.22, -0.48)], fill=255)
    for sx in (-0.18, 0.18):
        e = [P(sx + math.cos(t) * 0.12, 0.1 + math.sin(t) * 0.12) for t in np.linspace(0, math.pi * 2, 12)]
        h.polygon(e, fill=255)
    h.polygon([P(0, -0.05), P(0.06, -0.18), P(-0.06, -0.18)], fill=255)
    return np.asarray(img, float) / 255 > 0.5, np.asarray(holes, float) / 255 > 0.5


def seal(size=1024):
    n = size * SS
    x, y = grid(n)
    r = np.sqrt(x * x + y * y)
    th = np.arctan2(y, x)
    noise = fbm((n, n), [3 * SS, 10 * SS], 91)
    # the blood pool, ripples catching the light
    pool = r < 0.97
    col = mix(BLOOD, DEEP, smooth(0.0, 0.95, r))
    rip = (np.sin(r * 70 + noise * 2) > 0.92) & (r < 0.76)
    col = np.where(rip[..., None], mix(col, CRIMSON, 0.45), col)
    col = mix(col, DEEP, np.clip(noise * 0.5 + 0.2, 0, 1) * 0.3)
    out = layer(ndimage.gaussian_filter(pool.astype(float), 8 * SS) * 0.6, BLACK)
    pl = np.zeros((n, n, 4))
    pl[..., :3] = col
    pl[..., 3] = pool * 0.95 * 255
    out = over(out, pl)
    # carved slash scars across the pool (white cuts with a red fringe)
    rng = np.random.default_rng(5)
    for _ in range(7):
        a = rng.uniform(0, math.pi)
        out = over(out, slash_layer(x, y, rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), a, rng.uniform(0.8, 1.3),
                                    0.004, 1.0, 0.65))
    # the maw: a ring of fangs round the middle, pointing in
    fangs = np.zeros((n, n), bool)
    N = 22
    for k in range(N):
        a = k / N * 2 * math.pi
        ph = ((th - a + math.pi) % (2 * math.pi)) - math.pi
        base_r, tip_r = 0.74, 0.6 if k % 2 == 0 else 0.65
        t = (base_r - r) / (base_r - tip_r)
        fangs |= (t > 0) & (t < 1) & (np.abs(ph) < 0.11 * (1 - t))
    fd = ndimage.distance_transform_edt(fangs)
    fcol = mix(BONE * 0.8, BONE, smooth(0, 4 * SS, fd))
    fcol = np.where((fd < 1.5 * SS)[..., None], BLACK, fcol)
    fl = np.zeros((n, n, 4))
    fl[..., :3] = fcol
    fl[..., 3] = fangs * 255
    out = over(out, fl)
    # the kanji band
    band = (r > 0.78) & (r < 0.935)
    out = over(out, layer(band * 0.9, BLACK))
    for rr, w in ((0.94, 0.006), (0.775, 0.005)):
        out = over(out, layer((np.abs(r - rr) < w) * 1.0, CRIMSON))
    glyphs = Image.new("L", (n, n), 0)
    font = ImageFont.truetype(str(FONT), int(n * 0.058))
    text = "伏魔御廚子"
    slots = 2 * (len(text) + 1)
    skull_slots = []
    for k in range(slots):
        a = math.pi / 2 - k / slots * 2 * math.pi
        rr = 0.857 * n / 2
        cx, cy = n / 2 + rr * math.cos(a), n / 2 - rr * math.sin(a)
        i = k % (len(text) + 1)
        if i == len(text):
            skull_slots.append((cx, cy, a))
            continue
        tile = Image.new("L", (int(n * 0.09), int(n * 0.09)), 0)
        ImageDraw.Draw(tile).text((tile.width / 2, tile.height / 2), text[i], font=font, fill=255, anchor="mm")
        tile = tile.rotate(math.degrees(a) - 90, resample=Image.BICUBIC)
        glyphs.paste(tile, (int(cx - tile.width / 2), int(cy - tile.height / 2)), tile)
    gm = np.asarray(glyphs, float) / 255
    out = over(out, layer(ndimage.gaussian_filter(gm, 3 * SS) * 1.2, CRIMSON))
    out = over(out, layer(gm, BONE))
    # skulls between the words, and a ring of small skulls on the outer rim
    for cx, cy, a in skull_slots:
        b, hl = skull_mask(n, cx, cy, n * 0.045, a)
        out = over(out, layer(b * 1.0, BONE))
        out = over(out, layer(hl * 1.0, BLACK))
    for k in range(16):
        a = (k + 0.5) / 16 * 2 * math.pi
        rr = 0.965 * n / 2
        b, hl = skull_mask(n, n / 2 + rr * math.cos(a), n / 2 - rr * math.sin(a), n * 0.022, a)
        out = over(out, layer(b * 0.95, BONE))
        out = over(out, layer(hl * 1.0, BLACK))
    return to_img(down(out, SS))


# ---------------------------------------------------------------- the shrine behind him
def contact(files):
    tiles = []
    for name, im in files.items():
        t = im.copy()
        t.thumbnail((420, 420))
        for bg in ((70, 150, 220), (30, 30, 48)):
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
    makers = {"dismantle_4x4": dismantle, "cleave_4x4": cleave, "seal": seal}
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
