#!/usr/bin/env python3
"""HeavenlyRestriction (Toji Fushiguro, "Sorcerer Hunter", Legendary) textures.

    python tools/auras/heavenly_restriction/make_tex.py [names...]   -> assets/auras/heavenly_restriction/*.png

His body keeps the pack aura he wears (Pack3 "Dummy", copied verbatim by the builder; it already spends his whole
Legendary particle budget). Toji has NO cursed energy (Heavenly Restriction), so nothing here glows: what is
added is raw physical power, pre-coloured and drawn with LightEmission 0.

  crater.png        the floor caved in under him: a shallow crater of cracked grey stone, radial fractures
                    running out of it, a sunken shaded centre, chipped rubble on the rim (SurfaceGui; no particles)
  cut_4x4.png       16-frame ONE-SHOT sorcerer-killer cut: a razor-thin straight cut flashes across the air
                    (frames 0-3), the air SPLITS along it into two thin white edges drifting apart (4-10), gone
  pebble.png        a chip of grey stone kicked up off the crater
  lib_dust_ground_soft_02_4x4.png   the roblox-vfx skill's generated dust puff (ours too), tinted grey

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
OUT = ROOT / "assets" / "auras" / "heavenly_restriction"
_spec = importlib.util.spec_from_file_location("et", ROOT / "tools" / "auras" / "emperor_thorns" / "make_tex.py")
K = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(K)
smooth, over, down, grid, to_img, sheet = K.smooth, K.over, K.down, K.grid, K.to_img, K.sheet
SS, F = K.SS, K.F
LIB = Path.home() / ".claude" / "skills" / "roblox-vfx" / "sim" / "textures" / "lib"

STONE_D = np.array([58, 56, 60], float)
STONE = np.array([118, 114, 112], float)
STONE_L = np.array([170, 166, 160], float)
CRACK = np.array([16, 14, 16], float)
WHITE = np.array([248, 248, 250], float)
INK = np.array([12, 12, 16], float)


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


def crater(size=1024):
    n = size * SS
    x, y = grid(n)
    r = np.sqrt(x * x + y * y)
    th = np.arctan2(y, x)
    noise = fbm((n, n), [2 * SS, 7 * SS], 41)
    # an irregular rim radius
    rim_r = 0.62 + 0.05 * np.sin(th * 5 + 1.3) + 0.03 * np.sin(th * 11) + 0.02 * noise
    inside = r < rim_r
    # depth shading: the bowl darker toward the middle, lit from the upper left
    depth = np.clip(1 - r / rim_r, 0, 1)
    light = np.clip(0.5 + 0.5 * (-x * 0.6 + y * 0.8) / np.maximum(r, 1e-3) * (r / rim_r), 0, 1)
    col = mix(STONE, STONE_D, depth ** 0.8 * 0.8)
    col = mix(col, STONE_L, (1 - light) * inside * 0.35 * (r / rim_r))
    col = mix(col, STONE_D, light * inside * 0.3 * (r / rim_r))
    col = mix(col, STONE_L, np.clip(noise * 0.5 + 0.3, 0, 1) * 0.25)
    a = inside * 0.95
    # the raised, chipped rim
    rim = np.abs(r - rim_r) < 0.035 + 0.02 * noise
    col = np.where(rim[..., None], mix(STONE_L, STONE, np.clip(noise + 0.5, 0, 1)), col)
    a = np.maximum(a, rim * 1.0)
    # rubble chunks scattered just outside the rim
    rng = np.random.default_rng(7)
    rub = Image.new("L", (n, n), 0)
    rd = ImageDraw.Draw(rub)
    for _ in range(60):
        ang = rng.uniform(0, 2 * math.pi)
        rr = rng.uniform(0.66, 0.9)
        cx, cy = (1 + rr * math.cos(ang)) / 2 * n, (1 - rr * math.sin(ang)) / 2 * n
        s_ = n * rng.uniform(0.006, 0.02)
        pts = [(cx + s_ * math.cos(t) * rng.uniform(0.6, 1.2), cy + s_ * math.sin(t) * rng.uniform(0.6, 1.2))
               for t in np.linspace(0, 2 * math.pi, 6, endpoint=False)]
        rd.polygon(pts, fill=255)
    rm = np.asarray(rub, float) / 255 > 0.5
    col = np.where(rm[..., None], mix(STONE, STONE_L, 0.4), col)
    a = np.maximum(a, rm * 1.0)
    # fractures: from the centre out past the rim, branching
    cr = Image.new("L", (n, n), 0)
    cd = ImageDraw.Draw(cr)
    for k in range(13):
        ang = k / 13 * 2 * math.pi + rng.uniform(-0.15, 0.15)
        p = np.array([n / 2, n / 2], float) + np.array([math.cos(ang), -math.sin(ang)]) * n * 0.05
        pts = [tuple(p)]
        reach = rng.uniform(0.38, 0.49)
        steps = 10
        for i in range(steps):
            ang += rng.uniform(-0.3, 0.3)
            p = p + np.array([math.cos(ang), -math.sin(ang)]) * n * reach / steps
            pts.append(tuple(p))
            if rng.random() < 0.22:
                b = np.array(p)
                ba = ang + rng.choice([-1, 1]) * rng.uniform(0.5, 1.0)
                bpts = [tuple(b)]
                for _ in range(rng.integers(2, 5)):
                    b = b + np.array([math.cos(ba), -math.sin(ba)]) * n * 0.03
                    ba += rng.uniform(-0.3, 0.3)
                    bpts.append(tuple(b))
                cd.line(bpts, fill=255, width=int(1.6 * SS))
        for i in range(len(pts) - 1):
            w = int(max(1.4, 5.5 * (1 - i / len(pts))) * SS)
            cd.line([pts[i], pts[i + 1]], fill=255, width=w)
    cm = np.asarray(cr, float) / 255 > 0.5
    # cracks outside the crater still need the floor under them to show: give them their own alpha
    col = np.where(cm[..., None], CRACK, col)
    edge_hi = ndimage.binary_dilation(cm, iterations=int(1.5 * SS)) & ~cm
    col = np.where((edge_hi & inside)[..., None], mix(col, STONE_L, 0.5), col)
    a = np.maximum(a, cm * 0.95)
    a = np.maximum(a, edge_hi * 0.35)
    # a soft dark contact shadow round the whole thing
    sh = ndimage.gaussian_filter((a > 0.5).astype(float), 8 * SS) * 0.35
    rgba = np.zeros((n, n, 4))
    rgba[..., :3] = col
    rgba[..., 3] = np.clip(a, 0, 1) * 255
    return to_img(down(over(layer(sh, INK), rgba), SS))


def cut(frame=256):
    """A straight razor cut across the frame: flash, then the air splits into two edges that drift apart."""
    n = frame * SS
    x, y = grid(n)
    frames = []
    for f in range(16):
        t = f / 15
        # the cut is drawn along x, centred; it shoots out fast from the middle
        grow = smooth(0, 3, f)
        L = 0.92 * grow
        along = np.clip(1 - np.abs(x) / max(L, 1e-3), 0, 1)
        taper = along ** 0.6
        if f <= 3:
            w = 0.012 + 0.02 * (1 - abs(f - 2) / 2)
            core = (np.abs(y) < w * taper) & (np.abs(x) < L)
            glow = np.exp(-(y / (w * 3.5)) ** 2) * taper * 0.55
            rgba = over(layer(glow, WHITE), layer(core * 1.0, WHITE))
        else:
            sep = 0.012 + 0.07 * smooth(3, 11, f)
            fade = 1 - smooth(7, 15, f)
            shrink = 1 - 0.35 * smooth(4, 15, f)
            along2 = np.clip(1 - np.abs(x) / (0.92 * shrink), 0, 1) ** 0.6
            out = np.zeros((n, n, 4))
            for sgn in (1, -1):
                w = 0.006
                edge = (np.abs(y - sgn * sep) < w * along2) & (np.abs(x) < 0.92 * shrink)
                out = over(out, layer(edge * fade, WHITE))
                # a dark sliver of the cut between the edges: the split air
            gap = (np.abs(y) < sep * 0.6) & (np.abs(x) < 0.92 * shrink * 0.85)
            out = over(layer(gap * 0.5 * fade * along2, INK), out)
            rgba = out
        frames.append(to_img(down(rgba, SS)))
    return sheet(frames)


def pebble(size=64):
    n = size * SS
    img = Image.new("L", (n, n), 0)
    rng = np.random.default_rng(3)
    pts = [(n / 2 + n * 0.38 * math.cos(t) * rng.uniform(0.7, 1.0), n / 2 + n * 0.38 * math.sin(t) * rng.uniform(0.7, 1.0))
           for t in np.linspace(0, 2 * math.pi, 7, endpoint=False)]
    ImageDraw.Draw(img).polygon(pts, fill=255)
    m = np.asarray(img, float) / 255 > 0.5
    x, y = grid(n)
    col = mix(STONE_D, STONE_L, np.clip(0.5 + (-x + y) * 0.6, 0, 1))
    din = ndimage.distance_transform_edt(m)
    col = np.where((din < 1.4 * SS)[..., None], STONE_D * 0.7, col)
    rgba = np.zeros((n, n, 4))
    rgba[..., :3] = col
    rgba[..., 3] = m * 255
    return to_img(down(rgba, SS))


def contact(files):
    tiles = []
    for name, im in files.items():
        t = im.copy()
        t.thumbnail((420, 420))
        for bg in ((60, 64, 110), (235, 210, 60)):
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
        "crater": crater,
        "cut_4x4": cut,
        "pebble": pebble,
        "lib_dust_ground_soft_02_4x4": lambda: Image.open(LIB / "flipbooks/smoke/dust_ground_soft_02_4x4.png").convert("RGBA"),
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
