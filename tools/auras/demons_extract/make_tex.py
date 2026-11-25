#!/usr/bin/env python3
"""DemonsExtract (Esdeath, "Ice General", Epic) aura textures, made from maths: nothing harvested.

    python tools/auras/demons_extract/make_tex.py [names...]   -> assets/auras/demons_extract/*.png (+ _sheet.jpg)

Reference (Akame ga Kill!): her Teigu Demon's Extract makes and shapes ice out of thin air: giant ice spikes
raised from the ground, ice masses dropped from the sky (Hagelsprung), volleys of ice shards (Weissschnabel),
blizzards and ice constructs; her ultimate (Mahapadma) freezes time. Palette: ice white, glacier cyan, deep ice
blue, navy shadow. Ice is bright, so it reads against the yard's dark floor without help.
Every texture is PRE-COLOURED (drawn with Color white unless the builder says otherwise).

  spike_4x4.png       16-frame ONE-SHOT: an ice cluster bursts up out of the ground (eased, a little overshoot),
                      a glint runs up it, it cracks and shatters, the pieces fall away and fade
  frost.png           ground seal: hoarfrost ferns in six-fold symmetry over a pale ice disc, an ice crest in the
                      middle, a ring of tiny snowflakes
  icering.png         the frost shockwave: a ring of outward ice crystals with a white rim
  flake_a/b/c.png     three six-armed snowflakes (white, a cyan glow)
  shard.png           a small ice chunk (hail)
  glint.png           a four-point diamond-dust sparkle
  mist.png            a pale blue cold-mist puff
  glow.png            soft radial falloff
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets" / "auras" / "demons_extract"

ICE = np.array([240, 250, 255], float)
CYAN = np.array([150, 222, 255], float)
BLUE = np.array([56, 132, 218], float)
DEEP = np.array([26, 66, 140], float)
NAVY = np.array([16, 34, 80], float)
WHITE = np.array([255, 255, 255], float)


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def field(shape, scale, seed, wrap=True):
    rng = np.random.default_rng(seed)
    f = ndimage.gaussian_filter(rng.standard_normal(shape), scale, mode="wrap" if wrap else "reflect")
    return f / (np.abs(f).max() + 1e-9)


def down(rgba, k):
    h, w, _ = rgba.shape
    a = rgba[..., 3:4] / 255.0
    pre = np.concatenate([rgba[..., :3] * a, a], axis=2)
    pre = pre.reshape(h // k, k, w // k, k, 4).mean(axis=(1, 3))
    al = pre[..., 3:4]
    col = np.where(al > 1e-4, pre[..., :3] / np.maximum(al, 1e-4), 0)
    return np.concatenate([col, al * 255], axis=2)


def to_img(rgba):
    return Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), "RGBA")


def over(dst, src):
    sa = src[..., 3:4] / 255.0
    da = dst[..., 3:4] / 255.0
    oa = sa + da * (1 - sa)
    col = np.where(oa > 1e-5, (src[..., :3] * sa + dst[..., :3] * da * (1 - sa)) / np.maximum(oa, 1e-5), 0)
    return np.concatenate([col, oa * 255], axis=2)


def layer(mask, colour):
    c = np.broadcast_to(np.asarray(colour, float), np.shape(mask) + (3,))
    return np.concatenate([c, (np.clip(mask, 0, 1) * 255)[..., None]], axis=2)


def lerp(c0, c1, t):
    t = np.asarray(t, float)[..., None]
    return c0 * (1 - t) + c1 * t


def coords(n, m=None):
    m = m or n
    yy, xx = np.mgrid[0:m, 0:n].astype(float)
    return (xx + 0.5) / n * 2 - 1, (yy + 0.5) / m * 2 - 1


def grid(frames, n):
    f = frames[0].size[0]
    s = Image.new("RGBA", (f * n, f * n), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        s.paste(fr, ((i % n) * f, (i // n) * f))
    return s


def rgba_t(c, a=255):
    return tuple(int(max(0, min(255, v))) for v in c) + (int(a),)


# ------------------------------------------------------------------ crystals
def crystal(d, bx, by, w, h, lean, lit, shade, edge, ew, alpha=235):
    """A faceted ice crystal standing on (bx, by) (image coords, y down): width w at its base, height h, its tip
    leaning by `lean` (fraction of h). Two faces (lit left, shaded right), a central ridge, white edges."""
    tip = (bx + lean * h, by - h)
    shoulder = 0.78  # where the sides turn in to the point
    ls = (bx - w / 2 + lean * h * shoulder, by - h * shoulder)
    rs = (bx + w / 2 + lean * h * shoulder, by - h * shoulder)
    mid_b = (bx + w * 0.08, by)
    mid_s = (bx + w * 0.08 + lean * h * shoulder, by - h * shoulder * 1.02)
    left = [(bx - w / 2, by), ls, tip, mid_s, mid_b]
    right = [mid_b, mid_s, tip, rs, (bx + w / 2, by)]
    d.polygon(left, fill=rgba_t(lit, alpha))
    d.polygon(right, fill=rgba_t(shade, alpha))
    d.line([(bx - w / 2, by), ls, tip, rs, (bx + w / 2, by)], fill=rgba_t(edge), width=ew, joint="curve")
    d.line([mid_b, mid_s, tip], fill=rgba_t(edge, 200), width=max(1, ew // 2))
    return tip


def spike():
    """16 frames (256 px): an ice cluster bursts up out of the ground, glints, cracks and shatters."""
    F = 256
    k = 2
    N = F * k
    base = N * 0.94
    cluster = [  # (x frac, width, height, lean)
        (0.5, 0.26, 0.86, 0.0), (0.33, 0.16, 0.52, -0.22), (0.68, 0.17, 0.6, 0.2), (0.42, 0.1, 0.34, -0.35),
        (0.6, 0.1, 0.3, 0.32),
    ]
    rng = np.random.default_rng(5)
    frames = []
    for i in range(16):
        t = i / 15
        g = smooth(0.0, 0.32, t)
        grow = g + 0.12 * math.sin(math.pi * min(t / 0.42, 1.0)) * (t < 0.42)  # a little overshoot
        brk = smooth(0.66, 1.0, t)
        fade = 1 - smooth(0.8, 1.0, t)
        img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        for j, (fx, fw, fh, lean) in enumerate(cluster):
            h = fh * N * max(grow, 0.001)
            w = fw * N * (0.55 + 0.45 * min(grow, 1.0))
            dx = (fx - 0.5) * N * 0.9 * brk + rng.uniform(-4, 4) * k * brk
            dy = N * 0.5 * brk * brk
            crystal(d, fx * N + dx, base + dy, w, h, lean * (1 + brk), CYAN, BLUE * 1.1, ICE, 4 * k,
                    alpha=230 * fade)
        arr = np.asarray(img, float).copy()
        x, y = coords(N)
        m = arr[..., 3] > 0
        arr[..., :3] = np.where(m[..., None], lerp(arr[..., :3], DEEP, smooth(0.4, 0.95, y) * 0.5), arr[..., :3])
        # the glint runs up the cluster while it holds
        if 0.32 < t < 0.7:
            gy = 0.9 - (t - 0.32) / 0.38 * 1.7
            band = np.exp(-(((y - gy) / 0.05) ** 2)) * m
            arr = over(arr, layer(band * 0.9, WHITE))
        # cracks flare before it breaks
        if 0.55 < t < 0.75:
            cr = smooth(0.55, 0.68, t) * (1 - smooth(0.68, 0.75, t))
            crack = (np.abs(field((N, N), 3 * k, seed=11)) < 0.03) * m
            arr = over(arr, layer(crack * cr, WHITE))
        # frost puff at the root as it bursts out, and ice dust as it breaks
        burst = np.exp(-((x / 0.5) ** 2 + ((y - 0.88) / 0.12) ** 2)) * (smooth(0.0, 0.08, t) - smooth(0.12, 0.35, t))
        arr = over(arr, layer(np.clip(burst, 0, 1) * 0.8, ICE))
        if brk > 0:
            dust = np.zeros((N, N))
            drs = np.random.default_rng(40 + i)
            for _ in range(60):
                px, py = drs.uniform(-0.8, 0.8), drs.uniform(-0.4, 0.9) + 0.3 * brk
                dust = np.maximum(dust, np.exp(-((np.hypot(x - px, y - py) / drs.uniform(0.006, 0.014)) ** 2)))
            arr = over(arr, layer(dust * fade * smooth(0.66, 0.75, t), ICE))
        frames.append(to_img(down(arr, k)))
    return grid(frames, 4)


# ------------------------------------------------------------------ snowflakes, frost
def flake_arms(d, cx, cy, R, colour, w, style, k):
    for a6 in range(6):
        a = -math.pi / 2 + a6 * math.pi / 3
        ux, uy = math.cos(a), math.sin(a)
        d.line([(cx, cy), (cx + ux * R, cy + uy * R)], fill=colour, width=w)
        branches = {0: (0.45, 0.72), 1: (0.3, 0.55, 0.8), 2: (0.6,)}[style]
        for f in branches:
            bx, by = cx + ux * R * f, cy + uy * R * f
            L = R * (0.42 - 0.25 * f) if style != 2 else R * 0.32
            for s in (-1, 1):
                ba = a + s * math.radians(60 if style != 1 else 45)
                d.line([(bx, by), (bx + math.cos(ba) * L, by + math.sin(ba) * L)], fill=colour, width=max(1, w - k))
        if style == 2:
            d.regular_polygon((cx + ux * R * 0.95, cy + uy * R * 0.95, R * 0.1), 6, fill=colour)
    d.regular_polygon((cx, cy, R * 0.16), 6, rotation=30, fill=colour)


def flake(style, N=256):
    k = 3
    S = N * k
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    flake_arms(d, S / 2, S / 2, S * 0.42, (255, 255, 255, 255), 9 * k, style, k)
    arr = down(np.asarray(img, float), k)
    a = arr[..., 3] / 255
    glow = layer(np.clip(ndimage.gaussian_filter(a, 6) * 1.6, 0, 1) * 0.7, CYAN)
    return to_img(over(glow, arr))


def frost(N=1024):
    k = 2
    S = N * k
    c = S / 2
    x, y = coords(S)
    r = np.hypot(x, y)
    # a pale ice disc, clearer toward the rim, with a faint cracked texture
    disc = (r < 0.9).astype(float)
    base = lerp(np.broadcast_to(np.array([200, 232, 255.0]), (S, S, 3)), BLUE, smooth(0.0, 0.9, r) * 0.6)
    out = np.concatenate([base, (disc * (0.55 - 0.25 * smooth(0.5, 0.9, r)) * 255)[..., None]], axis=2)
    cracks = (np.abs(field((S, S), 5 * k, seed=21)) < 0.02) * disc * 0.5
    out = over(out, layer(cracks, WHITE))
    img = to_img(out)
    d = ImageDraw.Draw(img)
    rng = np.random.default_rng(3)

    def fern(x0, y0, a, L, w, depth):
        """A hoarfrost fern: a stem with side barbs at 60 degrees, the barbs ferning in turn."""
        x1, y1 = x0 + L * math.cos(a), y0 + L * math.sin(a)
        d.line([(x0, y0), (x1, y1)], fill=(255, 255, 255, 255), width=max(1, int(w)))
        if depth == 0:
            return
        n = 7 if depth == 2 else 5
        for j in range(1, n):
            f = j / n
            bx, by = x0 + (x1 - x0) * f, y0 + (y1 - y0) * f
            bl = L * 0.36 * (1 - f * 0.7)
            for s in (-1, 1):
                fern(bx, by, a + s * math.radians(58), bl, w * 0.6, depth - 1)

    for i in range(6):
        a = -math.pi / 2 + i * math.pi / 3
        fern(c + math.cos(a) * S * 0.08, c + math.sin(a) * S * 0.08, a, S * 0.36, 7 * k, 2)
        a2 = a + math.pi / 6
        fern(c + math.cos(a2) * S * 0.12, c + math.sin(a2) * S * 0.12, a2, S * 0.2, 4 * k, 1)
    # the ice crest in the middle: a six-pointed star of crystals inside a hexagon
    d.regular_polygon((c, c, S * 0.085), 6, rotation=30, outline=(255, 255, 255, 255), width=5 * k)
    for i in range(6):
        a = -math.pi / 2 + i * math.pi / 3
        crystal(d, c + math.cos(a) * S * 0.02, c + math.sin(a) * S * 0.02, S * 0.03, S * 0.075, 0, ICE, CYAN, WHITE, 2 * k)
    flake_arms(d, c, c, S * 0.04, (255, 255, 255, 255), 3 * k, 0, k)
    # rings and a ring of tiny snowflakes
    for rr, w in ((0.9, 4), (0.94, 2)):
        R = S / 2 * rr
        d.ellipse([c - R, c - R, c + R, c + R], outline=(235, 248, 255, 255), width=w * k)
    for i in range(24):
        a = -math.pi / 2 + i * math.pi / 12
        flake_arms(d, c + math.cos(a) * S / 2 * 0.92, c + math.sin(a) * S / 2 * 0.92, S * 0.012, (255, 255, 255, 230), 2 * k, i % 3, k)
    arr = down(np.asarray(img, float), k)
    lines = np.clip((arr[..., :3].mean(2) > 245) * arr[..., 3] / 255, 0, 1)
    bloom = layer(np.clip(ndimage.gaussian_filter(lines, 4) * 1.8, 0, 1) * 0.7, CYAN)
    return to_img(over(bloom, arr))


def icering(N=512):
    k = 2
    S = N * k
    c = S / 2
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rng = np.random.default_rng(2)
    R = S * 0.36
    for i in range(36):
        a = i * 2 * math.pi / 36 + rng.uniform(-0.04, 0.04)
        h = S * rng.uniform(0.06, 0.12)
        w = S * rng.uniform(0.025, 0.04)
        # a crystal standing on the ring, pointing outward: draw it upright on a scratch canvas and rotate
        g = Image.new("RGBA", (int(w * 3), int(h * 1.3)), (0, 0, 0, 0))
        crystal(ImageDraw.Draw(g), g.size[0] / 2, g.size[1] - 2, w, h, 0, ICE, CYAN, WHITE, 2 * k)
        g = g.rotate(-math.degrees(a) - 90, expand=True, resample=Image.BICUBIC)
        X, Y = c + math.cos(a) * (R + h * 0.45), c + math.sin(a) * (R + h * 0.45)
        img.alpha_composite(g, (int(X - g.size[0] / 2), int(Y - g.size[1] / 2)))
    d.ellipse([c - R, c - R, c + R, c + R], outline=(255, 255, 255, 255), width=6 * k)
    arr = down(np.asarray(img, float), k)
    x, y = coords(N)
    r = np.hypot(x, y)
    glow = layer(np.exp(-(((r - 0.72) / 0.08) ** 2)) * 0.5, CYAN)
    return to_img(over(glow, arr))


def shard(N=128):
    k = 3
    S = N * k
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    crystal(ImageDraw.Draw(img), S * 0.5, S * 0.92, S * 0.34, S * 0.84, 0.05, ICE, CYAN, WHITE, 3 * k)
    return to_img(down(np.asarray(img, float), k))


def glint(N=128):
    x, y = coords(N)
    r = np.hypot(x, y)
    cross = np.exp(-np.abs(x) / 0.03) * np.exp(-np.abs(y) / 0.6) + np.exp(-np.abs(y) / 0.03) * np.exp(-np.abs(x) / 0.6)
    diag = (np.exp(-np.abs(x - y) / 0.04) + np.exp(-np.abs(x + y) / 0.04)) * np.exp(-r / 0.2) * 0.5
    a = np.clip(cross + diag + np.exp(-((r / 0.12) ** 2)) + 0.3 * np.exp(-((r / 0.4) ** 2)), 0, 1)
    return to_img(np.concatenate([lerp(np.broadcast_to(WHITE, (N, N, 3)), CYAN, smooth(0.1, 0.6, r)), (a * 255)[..., None]], axis=2))


def mist(N=256):
    x, y = coords(N)
    r = np.hypot(x, y)
    n = field((N, N), 10, seed=71) * 0.5 + field((N, N), 4, seed=72) * 0.5
    a = np.clip((1 - r) * 1.4 + n * 0.5 - 0.3, 0, 1) ** 1.5
    col = lerp(np.broadcast_to(np.array([200, 230, 255.0]), (N, N, 3)), np.array([140, 190, 240.0]), np.clip(n + 0.5, 0, 1))
    return to_img(np.concatenate([col, (a * 200)[..., None]], axis=2))


def glow(N=256):
    x, y = coords(N)
    return to_img(layer(np.clip(1 - np.hypot(x, y), 0, 1) ** 2.2, WHITE))


def contact(imgs):
    cell = 300
    names = list(imgs)
    cols = 6
    rows = math.ceil(len(names) / cols)
    sheet = Image.new("RGB", (cell * cols, cell * rows * 2), (0, 0, 0))
    d = ImageDraw.Draw(sheet)
    for half, bg in enumerate(((14, 16, 30), (196, 210, 225))):
        for i, n in enumerate(names):
            X, Y = (i % cols) * cell, (i // cols) * cell + half * cell * rows
            tile = Image.new("RGBA", (cell, cell), bg + (255,))
            im = imgs[n].copy()
            im.thumbnail((cell - 20, cell - 30))
            tile.alpha_composite(im, ((cell - im.size[0]) // 2, 22))
            sheet.paste(tile.convert("RGB"), (X, Y))
            d.text((X + 6, Y + 4), n, fill=(255, 255, 255) if half == 0 else (0, 0, 0))
    return sheet


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    makers = {
        "spike_4x4": spike,
        "frost": frost,
        "icering": icering,
        "flake_a": lambda: flake(0),
        "flake_b": lambda: flake(1),
        "flake_c": lambda: flake(2),
        "shard": shard,
        "glint": glint,
        "mist": mist,
        "glow": glow,
    }
    only = sys.argv[1:]
    made = {}
    for n, fn in makers.items():
        p = OUT / f"{n}.png"
        if only and n not in only:
            if p.exists():
                made[n] = Image.open(p).convert("RGBA")
            continue
        im = fn()
        im.save(p, optimize=True)
        made[n] = im
        print("wrote", n, im.size)
    contact(made).save(OUT / "_sheet.jpg", quality=90)
    print("sheet", OUT / "_sheet.jpg")


if __name__ == "__main__":
    main()
