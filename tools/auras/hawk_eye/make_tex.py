#!/usr/bin/env python3
"""HawkEye (Mihawk's aura) textures, made from maths: nothing harvested, nothing stock.

    python tools/auras/hawk_eye/make_tex.py        -> assets/auras/hawk_eye/*.png (+ _sheet.jpg)

  slash_4x4.png   16-frame crescent slash (Yoru's flying slash): sweeps on from one tip, then thins and frays.
                  Pre-coloured: white-mint edge, emerald body, green-black belly (the dark copy in the same quad).
  bolt_4x4.png    16-frame Haki crack: a jagged bolt with branches strikes, re-strikes once, then thins out.
                  Pre-coloured: near-black core, crimson halo.
  sigil.png       ground sigil: rings scored by radial sword cuts, Yoru's cross and a hawk eye at the centre.
  feather.png     a hawk feather: barred dark vane, thin emerald rim, pale shaft (pre-coloured, square canvas).

Reused from tools/auras/butterfly_dance (same art family): wisp_4x4, glint, glow.
Grid4x4 flipbooks are row-major, 256 px frames on a 1024 sheet.
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets" / "auras" / "hawk_eye"
FRAME = 256


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def rgba_white(a: np.ndarray) -> Image.Image:
    h, w = a.shape
    return Image.fromarray(np.dstack([np.full((h, w, 3), 255, np.uint8), (np.clip(a, 0, 1) * 255).astype(np.uint8)]), "RGBA")


def grid(xs: int):
    yy, xx = np.mgrid[0:xs, 0:xs].astype(float)
    x = (xx - (xs - 1) / 2) / (xs / 2)
    y = -(yy - (xs - 1) / 2) / (xs / 2)
    return x, y


# ---------------------------------------------------------------- the slash
def slash_flipbook() -> Image.Image:
    S = FRAME * 2
    x, y = grid(S)
    r = np.hypot(x, y)
    ang = np.degrees(np.arctan2(y, x))  # 0 = +X (the crescent's belly), +-180 behind
    rng = np.random.default_rng(7)
    noise = ndimage.gaussian_filter(rng.standard_normal((S // 6, S // 6)), 1.6)
    noise = np.asarray(Image.fromarray(((noise - noise.min()) / np.ptp(noise) * 255).astype(np.uint8)).resize((S, S), Image.BICUBIC), float) / 255
    sheet = Image.new("RGBA", (FRAME * 4, FRAME * 4), (0, 0, 0, 0))
    R_OUT = 0.84
    for f in range(16):
        t = f / 15
        d = 0.24 * (1 - 0.7 * smooth(0.15, 1.0, t))  # crescent belly thickness shrinks as it fades
        inner = np.hypot(x + d, y)  # inner circle, offset back
        body = smooth(-0.012, 0.012, R_OUT - r) * smooth(-0.01, 0.012, inner - (R_OUT - 0.02))
        # the sweep: the head runs tip to tip in ~5 frames, the tail follows
        head = -105 + 210 * smooth(0.0, 0.32, t)
        tail = -105 + 210 * smooth(0.18, 0.95, t)
        sweep = smooth(tail - 6, tail + 14, ang) * (1 - smooth(head - 12, head + 2, ang))
        edge = np.exp(-((r - (R_OUT - 0.014)) / 0.013) ** 2) * smooth(-100, -60, ang) * (1 - smooth(60, 100, ang))
        depth = np.clip((R_OUT - r) / np.maximum(R_OUT - (inner - (R_OUT - 0.02)) * 0 - (R_OUT - d - 0.02), 0.02), 0, 1)
        a = body * (0.55 + 0.45 * (1 - smooth(0.0, 1.0, depth))) * (0.7 + 0.3 * smooth(-0.2, 0.6, np.cos(np.radians(ang)))) + edge
        a *= sweep
        fray = smooth(0.45, 1.0, t)
        a *= 1 - fray * smooth(0.25, 0.75, noise + 0.25 * (1 - smooth(-60, 60, ang)))
        a *= 1 - 0.5 * smooth(0.7, 1.0, t)
        # a faint speed smear inside the arc, right after the head passes
        smear = np.exp(-((r - (R_OUT - 0.09)) / 0.05) ** 2) * sweep * 0.18 * (1 - smooth(0.2, 0.6, t))
        # pre-coloured (the dark copy under the bright stroke has to be in the SAME particle): white-mint edge,
        # emerald body, deep green-black toward the belly
        dep = np.clip(depth, 0, 1)
        col = np.array([226, 255, 238.0]) + (np.array([34, 214, 124.0]) - np.array([226, 255, 238.0])) * smooth(0.0, 0.25, dep)[..., None]
        col = col + (np.array([4, 40, 24.0]) - col) * smooth(0.35, 0.95, dep)[..., None]
        col = col + (np.array([235, 255, 245.0]) - col) * np.clip(edge * sweep, 0, 1)[..., None]
        aa = np.clip(a + smear, 0, 1)
        im = Image.fromarray(np.dstack([col.clip(0, 255), aa * 255]).astype(np.uint8), "RGBA").resize((FRAME, FRAME), Image.LANCZOS)
        sheet.alpha_composite(im, ((f % 4) * FRAME, (f // 4) * FRAME))
    return sheet


# ---------------------------------------------------------------- the haki crack
def bolt_path(rng, start, end, depth=0):
    pts = [np.array(start, float), np.array(end, float)]
    for _ in range(5):
        new = [pts[0]]
        for a, b in zip(pts[:-1], pts[1:]):
            m = (a + b) / 2
            n = np.array([-(b - a)[1], (b - a)[0]])
            m = m + n * rng.uniform(-0.28, 0.28)
            new += [m, b]
        pts = new
    return pts


def bolt_frame(rng, S, width):
    im = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(im)

    def px(p):
        return ((p[0] + 1) / 2 * S, (1 - (p[1] + 1) / 2) * S)

    main = bolt_path(rng, (rng.uniform(-0.5, -0.2), -0.85), (rng.uniform(0.2, 0.5), 0.85))
    d.line([px(p) for p in main], fill=255, width=width, joint="curve")
    for _ in range(5):
        i = rng.integers(len(main) // 5, len(main) * 4 // 5)
        s = main[i]
        e = s + np.array([rng.uniform(-0.55, 0.55), rng.uniform(-0.2, 0.45)])
        br = bolt_path(rng, s, e)
        d.line([px(p) for p in br], fill=200, width=max(1, width // 2), joint="curve")
    return im


def bolt_flipbook() -> Image.Image:
    S = FRAME * 2
    rng = np.random.default_rng(31)
    sheet = Image.new("RGBA", (FRAME * 4, FRAME * 4), (0, 0, 0, 0))
    strike_a = bolt_frame(np.random.default_rng(11), S, 10)
    strike_b = bolt_frame(np.random.default_rng(12), S, 9)
    for f in range(16):
        if f <= 2:
            core, k = strike_a, 1.0
        elif f <= 4:
            core, k = strike_b, 1.0 if f == 3 else 0.8
        elif f <= 9:
            core, k = strike_b, 0.75 * (1 - (f - 5) / 6)
        else:
            core, k = None, 0
        if core is None:
            im = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
        else:
            thin = core.filter(ImageFilter.MinFilter(3)) if f >= 6 else core
            glow = thin.filter(ImageFilter.GaussianBlur(S * 0.016))
            c = np.asarray(thin, float) / 255
            g = np.asarray(glow, float) / 255
            # pre-coloured: a near-black core in a crimson halo (Conqueror's Haki)
            col = np.array([255, 36, 58.0]) * (1 - c)[..., None] + np.array([14, 4, 8.0]) * c[..., None]
            a = np.clip(np.maximum(c, g * 0.85), 0, 1) * k
            im = Image.fromarray(np.dstack([col.clip(0, 255), a * 255]).astype(np.uint8), "RGBA").resize((FRAME, FRAME), Image.LANCZOS)
        sheet.alpha_composite(im, ((f % 4) * FRAME, (f // 4) * FRAME))
    del rng
    return sheet


# ---------------------------------------------------------------- the ground sigil
def sigil(size=1024) -> Image.Image:
    S = size * 2
    x, y = grid(S)
    r = np.hypot(x, y)
    th = np.arctan2(y, x)
    a = np.zeros((S, S))

    def ring(r0, w, k=1.0):
        return k * (1 - smooth(w * 0.5, w, np.abs(r - r0)))

    a = np.maximum(a, ring(0.93, 0.012))
    a = np.maximum(a, ring(0.885, 0.030, 0.85))
    a = np.maximum(a, ring(0.60, 0.010, 0.9))
    a = np.maximum(a, ring(0.56, 0.005, 0.6))
    # sixteen sword cuts scored across the outer band, each a tapered tangent-leaning stroke
    img = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "L")
    cut = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(cut)
    for k in range(16):
        base = 2 * math.pi * k / 16
        long = k % 2 == 0
        r0, r1 = (0.64, 0.99) if long else (0.70, 0.95)
        lean = 0.22
        pts = []
        for s in np.linspace(0, 1, 24):
            rr = r0 + (r1 - r0) * s
            aa = base + lean * s
            w = (0.022 if long else 0.015) * math.sin(math.pi * s) ** 0.7
            pts.append((rr, aa, w))
        left = [((S / 2) + (rr * math.cos(aa) - w * math.sin(aa)) * S / 2, (S / 2) - (rr * math.sin(aa) + w * math.cos(aa)) * S / 2) for rr, aa, w in pts]
        right = [((S / 2) + (rr * math.cos(aa) + w * math.sin(aa)) * S / 2, (S / 2) - (rr * math.sin(aa) - w * math.cos(aa)) * S / 2) for rr, aa, w in pts]
        d.polygon(left + right[::-1], fill=255)
    # Yoru's cross: a long vertical blade, a shorter guard whose ends curl up
    def bar(x0, y0, x1, y1, w):
        d.line([((x0 + 1) / 2 * S, (1 - (y0 + 1) / 2) * S), ((x1 + 1) / 2 * S, (1 - (y1 + 1) / 2) * S)], fill=255, width=int(w * S / 2))
    bar(0, -0.30, 0, 0.50, 0.05)
    bar(-0.30, 0.16, 0.30, 0.16, 0.045)
    for sgn in (-1, 1):
        pts = [((sgn * (0.30 + 0.08 * math.sin(u * math.pi / 2)) + 1) / 2 * S, (1 - (0.16 + 0.10 * (1 - math.cos(u * math.pi / 2))) + 1) / 2 * S) for u in np.linspace(0, 1, 12)]
        pts = [(p[0], (1 - ((0.16 + 0.10 * (1 - math.cos(u * math.pi / 2)) + 1) / 2)) * S) for p, u in zip(pts, np.linspace(0, 1, 12))]
        d.line(pts, fill=255, width=int(0.04 * S / 2), joint="curve")
    # a pointed blade tip at the bottom
    d.polygon([((1 - 0.026) / 2 * S, (1 - (-0.50 + 1) / 2) * S), ((1 + 0.026) / 2 * S, (1 - (-0.50 + 1) / 2) * S), (S / 2, (1 - (-0.56 + 1) / 2) * S)], fill=0)
    d.polygon([((1 - 0.025) / 2 * S, (1 - (-0.30 + 1) / 2) * S), ((1 + 0.025) / 2 * S, (1 - (-0.30 + 1) / 2) * S), (S / 2, (1 - (-0.54 + 1) / 2) * S)], fill=255)
    img = Image.fromarray(np.maximum(np.asarray(img), np.asarray(cut)).astype(np.uint8), "L")
    # the hawk eye over the cross: an almond outline and a slit pupil (cut out of the cross)
    a = np.asarray(img, float) / 255
    ex, ey = x / 0.30, (y - 0.16) / 0.13
    almond = np.abs(ey) - (1 - ex ** 2) * (np.abs(ex) <= 1) + (np.abs(ex) > 1) * 2
    inside = almond < 0
    outline = np.exp(-(almond / 0.08) ** 2) * (np.abs(ex) <= 1.02)
    a = np.where(inside, 0.0, a)
    a = np.maximum(a, outline)
    iris = 1 - smooth(0.085, 0.10, np.hypot(x, y - 0.16))
    slit = 1 - smooth(0.012, 0.022, np.abs(x)) * 1.0
    a = np.maximum(a, iris * (1 - slit * (np.abs(y - 0.16) < 0.09)) * 0.95)
    a = np.maximum(a, 0.08 * (1 - smooth(0.0, 0.6, r)))
    img = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "L").resize((size, size), Image.LANCZOS)
    a = np.asarray(img, float) / 255
    glow = np.asarray(img.filter(ImageFilter.GaussianBlur(size * 0.010)), float) / 255
    return rgba_white(np.clip(np.maximum(a, glow * 0.5), 0, 1))
    del th


# ---------------------------------------------------------------- the feather
def feather(w=128, h=256) -> Image.Image:
    SS = 4
    W, H = w * SS, h * SS
    yy, xx = np.mgrid[0:H, 0:W].astype(float)
    u = 1 - yy / (H - 1)            # 0 at the quill, 1 at the tip
    cx = W / 2 + np.sin(u * 1.6) * W * 0.06  # the shaft bends a little
    dx = (xx - cx) / (W / 2)
    # an asymmetric vane: narrower on the leading side, widest at ~45 % of the length, rounded tip
    prof = np.sin(np.clip((u - 0.10) / 0.92, 0, 1) * math.pi) ** 0.6
    wl = 0.42 * prof
    wr = 0.66 * prof
    inside = ((dx < 0) & (-dx < wl)) | ((dx >= 0) & (dx < wr))
    edge_d = np.where(dx < 0, wl + dx, wr - dx)
    # barbs: fine lines angled toward the tip, with a couple of splits in the vane
    barbs = 0.5 + 0.5 * np.cos((u * 70 - np.abs(dx) * 9) * 2 * math.pi / 2)
    split = (np.abs(((u * 7 + np.abs(dx) * 1.2) % 1) - 0.5) < 0.025) & (np.abs(dx) > 0.15)
    vane = inside & ~split
    col = np.zeros((H, W, 3))
    base = np.array([16, 18, 20.0])
    sheen = np.array([40, 220, 140.0])
    tip = 1 - smooth(0.0, 0.10, edge_d)  # a thin rim at the vane's edge
    col[:] = base + (sheen - base) * (tip * 0.75)[..., None]
    bars = 0.5 + 0.5 * np.sin(u * 2 * math.pi * 5.5 + np.abs(dx) * 2.5)
    col += (np.array([58, 52, 46.0]) * smooth(0.55, 0.9, bars)[..., None]) * (1 - tip)[..., None]
    col *= (0.75 + 0.25 * barbs)[..., None]
    shaft = np.abs(xx - cx) < W * 0.018
    col[shaft & (u < 0.98)] = [200, 214, 205]
    a = (vane * (0.92 - 0.12 * smooth(0.7, 1.0, u))).astype(float)
    a = np.maximum(a, (shaft & (u < 0.98)).astype(float))
    quill = (np.abs(xx - cx) < W * 0.03) & (u < 0.12)
    col[quill] = [225, 230, 225]
    a = np.maximum(a, quill.astype(float))
    im = Image.fromarray(np.dstack([col.clip(0, 255), a * 255]).astype(np.uint8), "RGBA").resize((w, h), Image.LANCZOS)
    # particles are square: centre the feather on a square canvas so it is not squashed fat
    sq = Image.new("RGBA", (h, h), (0, 0, 0, 0))
    sq.alpha_composite(im, ((h - w) // 2, 0))
    return sq


def contact_sheet(files: dict[str, Image.Image]) -> Image.Image:
    tiles = []
    for name, im in files.items():
        for bg in ((14, 16, 20), (200, 205, 200)):
            base = Image.new("RGBA", im.size, bg + (255,))
            base.alpha_composite(im)
            t = base.convert("RGB")
            t.thumbnail((512, 512), Image.LANCZOS)
            pad = Image.new("RGB", (512, 512), bg)
            pad.paste(t, ((512 - t.width) // 2, (512 - t.height) // 2))
            tiles.append(pad)
    cols = 4
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * 512, rows * 512), (0, 0, 0))
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % cols) * 512, (i // cols) * 512))
    return sheet


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    files = {
        "slash_4x4.png": slash_flipbook(),
        "bolt_4x4.png": bolt_flipbook(),
        "sigil.png": sigil(),
        "feather.png": feather(),
    }
    for name, im in files.items():
        im.save(OUT / name)
        print("wrote", (OUT / name).relative_to(ROOT), im.size)
    contact_sheet(files).save(OUT / "_sheet.jpg", quality=88)
    print("wrote", (OUT / "_sheet.jpg").relative_to(ROOT))


if __name__ == "__main__":
    main()
