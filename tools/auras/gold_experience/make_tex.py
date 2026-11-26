#!/usr/bin/env python3
"""GoldExperience (Giorno's aura) textures, made from maths: nothing harvested, nothing stock.

    python tools/auras/gold_experience/make_tex.py        -> assets/auras/gold_experience/*.png (+ _sheet.jpg)

The look (JoJo Part 5, "Golden Wind"): Gold Experience gives LIFE (flowers, vines, creatures), its emblem is the
ladybug (Giorno's brooches), and the part is the golden wind. Gold, his suit's magenta, leaf green, petal pink.
  crest_core / crest_ink / crest_glow   the ground: a gold ring wreathed in a vine with leaves, three ladybug
                                        emblems, golden-wind swirl arcs at its heart (white + alpha, tinted)
  flower_4x4.png   16 frames, pre-coloured: a stem grows out of the ground, leaves unfurl, a bud opens into a pink
                   and white blossom with a gold centre, holds, its petals fall
  ladybug_4x4.png  16 frames (a loop), pre-coloured: a golden ladybug in flight, shell halves up, wings buzzing
  petal.png        one pink petal, pre-coloured
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets" / "auras" / "gold_experience"
GOLD = (255, 206, 70, 255)
GOLD_DARK = (170, 110, 20, 255)
LEAF = (86, 178, 74, 255)
LEAF_DARK = (36, 96, 40, 255)
PINK = (255, 126, 190, 255)
PINK_LIGHT = (255, 214, 236, 255)
INK = (34, 8, 30, 255)


def rgba_white(lum: Image.Image) -> Image.Image:
    a = np.asarray(lum, np.uint8)
    return Image.fromarray(np.dstack([np.full(a.shape + (3,), 255, np.uint8), a]), "RGBA")


def trio(im: Image.Image, size: int):
    S = im.width
    core = im.resize((size, size), Image.LANCZOS)
    ink = im.filter(ImageFilter.MaxFilter(11)).filter(ImageFilter.GaussianBlur(S * 0.0035)).resize((size, size), Image.LANCZOS)
    glow = im.filter(ImageFilter.MaxFilter(7)).filter(ImageFilter.GaussianBlur(S * 0.014)).resize((size, size), Image.LANCZOS)
    g = np.asarray(glow, float)
    g = np.clip(g / max(g.max(), 1) * 1.7, 0, 1) * 255
    return rgba_white(core), rgba_white(ink), rgba_white(Image.fromarray(g.astype(np.uint8)))


def leaf(d, x, y, ang, L, W, fill, outline=None, ow=1):
    ca, sa = math.cos(ang), math.sin(ang)
    pts = []
    for t in np.linspace(0, 1, 14):
        w = W * math.sin(math.pi * t) ** 0.8
        pts.append((x + ca * L * t - sa * w, y + sa * L * t + ca * w))
    for t in np.linspace(1, 0, 14):
        w = W * math.sin(math.pi * t) ** 0.8
        pts.append((x + ca * L * t + sa * w, y + sa * L * t - ca * w))
    d.polygon(pts, fill=fill)
    if outline is not None:
        d.line(pts + [pts[0]], fill=outline, width=ow)
        d.line([(x, y), (x + ca * L * 0.85, y + sa * L * 0.85)], fill=outline, width=max(1, ow - 1))


def ladybug_top(d, cx, cy, r, shell, spot, head, open_amt=0.0, outline=None, ow=2):
    """a ladybug seen from above; open_amt lifts the shell halves apart"""
    hr = r * 0.42
    d.ellipse([cx - hr, cy - r - hr * 0.9, cx + hr, cy - r + hr * 0.9], fill=head)
    gap = r * 0.35 * open_amt
    for s in (-1, 1):
        box = [cx - r + (gap if s > 0 else -gap), cy - r, cx + r + (gap if s > 0 else -gap), cy + r]
        start, end = (270, 450) if s > 0 else (90, 270)
        d.pieslice(box, start, end, fill=shell, outline=outline, width=ow if outline else 0)
        for (sx, sy, sr) in ((0.45, -0.35, 0.16), (0.55, 0.25, 0.2), (0.22, 0.62, 0.13)):
            px = cx + s * (sx * r + gap)
            py = cy + sy * r
            d.ellipse([px - sr * r, py - sr * r, px + sr * r, py + sr * r], fill=spot)
    if open_amt < 0.1:
        d.line([(cx, cy - r), (cx, cy + r)], fill=spot, width=max(2, int(r * 0.08)))


# ---------------------------------------------------------------- the ground crest
def crest(size=1024):
    S = size * 2
    im = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(im)
    c = S / 2

    def R(f):
        return f * S / 2

    def W(f):
        return max(1, int(f * S / 2))

    for rf, wf in ((0.975, 0.012), (0.70, 0.010), (0.66, 0.005)):
        d.ellipse([c - R(rf), c - R(rf), c + R(rf), c + R(rf)], outline=255, width=W(wf))
    # the vine: a sinuous stem between the rings with leaves on alternating sides
    pts = []
    for t in np.linspace(0, 2 * math.pi, 361):
        r = R(0.835 + 0.05 * math.sin(t * 9))
        pts.append((c + r * math.cos(t), c + r * math.sin(t)))
    d.line(pts, fill=255, width=W(0.010), joint="curve")
    for k in range(36):
        t = 2 * math.pi * (k + 0.25) / 36
        r = R(0.835 + 0.05 * math.sin(t * 9))
        x, y = c + r * math.cos(t), c + r * math.sin(t)
        side = 1 if k % 2 else -1
        ang = t + math.pi / 2 + side * 0.9
        leaf(d, x, y, ang, R(0.075), R(0.022), 255)
    # three ladybug emblems on the vine ring (solid shapes, spots cut out)
    for k in range(3):
        a = -math.pi / 2 + 2 * math.pi * k / 3
        x, y = c + R(0.835) * math.cos(a), c + R(0.835) * math.sin(a)
        r = R(0.085)
        d.ellipse([x - r * 1.25, y - r * 1.25, x + r * 1.25, y + r * 1.25], fill=0)
        ladybug_top(d, x, y, r, 255, 0, 255)
    # golden wind: three spiral arms sweeping out from the heart, each tapering
    for k in range(3):
        a0 = 2 * math.pi * k / 3
        prev = None
        for i, t in enumerate(np.linspace(0, 1, 60)):
            r = R(0.10 + 0.50 * t)
            a = a0 + 2.6 * t
            p_ = (c + r * math.cos(a), c + r * math.sin(a))
            if prev is not None:
                d.line([prev, p_], fill=255, width=max(1, int(W(0.022) * (1 - 0.8 * t))))
            prev = p_
        # a fine echo arm beside each
        prev = None
        for t in np.linspace(0, 1, 50):
            r = R(0.16 + 0.42 * t)
            a = a0 + 0.35 + 2.3 * t
            p_ = (c + r * math.cos(a), c + r * math.sin(a))
            if prev is not None:
                d.line([prev, p_], fill=255, width=W(0.006))
            prev = p_
    rr = R(0.09)
    d.ellipse([c - rr, c - rr, c + rr, c + rr], outline=255, width=W(0.012))
    return trio(im, size)


# ---------------------------------------------------------------- the flower
def flower_frame(S, grow, bloom, drop, fade):
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    ground = S * 0.92
    cx = S * 0.5
    H = S * 0.62 * grow
    lw = max(2, int(S * 0.008))
    if grow > 0.02:
        # a gently curved stem
        stem = [(cx + S * 0.03 * math.sin(t * 2.2) * t, ground - H * t) for t in np.linspace(0, 1, 12)]
        d.line(stem, fill=LEAF_DARK, width=int(S * 0.028), joint="curve")
        d.line(stem, fill=LEAF, width=int(S * 0.018), joint="curve")
        # two leaves unfurl as it grows
        for k, (t, side) in enumerate(((0.3, -1), (0.55, 1))):
            if grow > t:
                u = min(1.0, (grow - t) / 0.3)
                x, y = stem[int(t * 11)]
                leaf(d, x, y, -math.pi / 2 + side * 1.0, S * 0.16 * u, S * 0.05 * u, LEAF, LEAF_DARK, lw)
        top = stem[-1]
        if bloom <= 0.05:
            # a closed bud
            br = S * 0.04 * min(1.0, grow * 1.5)
            d.ellipse([top[0] - br, top[1] - br * 1.4, top[0] + br, top[1] + br * 0.6], fill=PINK, outline=LEAF_DARK, width=lw)
        else:
            # five petals open out, pink with a pale edge; they drop away at the end
            pr = S * 0.11 * bloom
            for k in range(5):
                a = -math.pi / 2 + 2 * math.pi * k / 5
                dx, dy = math.cos(a), math.sin(a)
                fall = drop * S * 0.25 * (0.6 + 0.4 * ((k * 37) % 5) / 5)
                px, py = top[0] + dx * pr * 0.9 + dx * drop * S * 0.05, top[1] + dy * pr * 0.9 + fall
                if drop > 0 and k % 2 == 0 and drop > 0.5:
                    continue
                d.ellipse([px - pr * 0.62, py - pr * 0.62, px + pr * 0.62, py + pr * 0.62], fill=PINK_LIGHT, outline=PINK, width=lw * 2)
                d.ellipse([px - pr * 0.4, py - pr * 0.4, px + pr * 0.4, py + pr * 0.4], fill=PINK)
            cr = S * 0.035 * max(bloom, 0.3)
            d.ellipse([top[0] - cr, top[1] - cr, top[0] + cr, top[1] + cr], fill=GOLD, outline=GOLD_DARK, width=lw)
    # a little gold life-light where it sprouts
    gl = Image.new("L", (S, S), 0)
    ImageDraw.Draw(gl).ellipse([cx - S * 0.14, ground - S * 0.03, cx + S * 0.14, ground + S * 0.03], fill=int(200 * min(1, grow * 2)))
    gl = gl.filter(ImageFilter.GaussianBlur(S * 0.02))
    layer = Image.new("RGBA", (S, S), GOLD)
    base = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    base.paste(layer, (0, 0), gl)
    out = Image.alpha_composite(base, im)
    a = np.asarray(out, float)
    a[..., 3] *= fade
    return Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA")


def flower_flipbook():
    F = 256
    S = F * 2
    sheet = Image.new("RGBA", (F * 4, F * 4), (0, 0, 0, 0))
    for f in range(16):
        t = f / 15
        grow = min(1.0, t / 0.35)
        grow = 1 - (1 - grow) ** 2
        bloom = 0.0 if t < 0.32 else min(1.0, (t - 0.32) / 0.2)
        drop = 0.0 if t < 0.75 else (t - 0.75) / 0.25
        fade = 1.0 if t < 0.85 else 1 - (t - 0.85) / 0.15
        sheet.alpha_composite(flower_frame(S, grow, bloom, drop, fade).resize((F, F), Image.LANCZOS), ((f % 4) * F, (f // 4) * F))
    return sheet


# ---------------------------------------------------------------- the golden ladybug
def ladybug_flipbook():
    F = 256
    S = F * 2
    sheet = Image.new("RGBA", (F * 4, F * 4), (0, 0, 0, 0))
    for f in range(16):
        ph = 2 * math.pi * f / 16
        im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        c = S / 2
        r = S * 0.22
        # buzzing wings: translucent, swinging
        for s in (-1, 1):
            ang = math.radians(25 + 35 * (0.5 + 0.5 * math.sin(ph * 2)))
            wl = S * 0.44
            wx = c + s * math.sin(ang) * wl
            wy = c - math.cos(ang) * wl * 0.6
            wing = Image.new("RGBA", (S, S), (0, 0, 0, 0))
            wd = ImageDraw.Draw(wing)
            wd.polygon([(c + s * r * 0.2, c - r * 0.3), (wx, wy), (wx + s * S * 0.06, wy + S * 0.14), (c + s * r * 0.3, c + r * 0.1)],
                       fill=(255, 246, 210, 165), outline=(255, 255, 255, 220))
            im = Image.alpha_composite(im, wing)
        d = ImageDraw.Draw(im)
        ladybug_top(d, c, c + r * 0.15, r, GOLD, INK, INK, open_amt=0.55, outline=GOLD_DARK, ow=max(2, int(S * 0.008)))
        # a highlight on each shell half
        for s in (-1, 1):
            hx = c + s * (r * 0.42 + r * 0.35 * 0.55)
            d.ellipse([hx - r * 0.12, c - r * 0.45, hx + r * 0.05, c - r * 0.25], fill=(255, 245, 200, 220))
        alpha = im.split()[3]
        glow = alpha.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(S * 0.03))
        layer = np.zeros((S, S, 4))
        layer[..., 0], layer[..., 1], layer[..., 2] = GOLD[:3]
        layer[..., 3] = np.asarray(glow, float) * 0.5
        out = Image.alpha_composite(Image.fromarray(layer.astype(np.uint8), "RGBA"), im)
        sheet.alpha_composite(out.resize((F, F), Image.LANCZOS), ((f % 4) * F, (f // 4) * F))
    return sheet


def petal(size=128):
    S = size * 4
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = S / 2
    # a teardrop petal: narrow at its base (bottom), broad and notched at its tip (top)
    pts = []
    for t in np.linspace(0, 1, 40):
        y = c + S * 0.36 - S * 0.72 * t
        w = S * 0.26 * math.sin(math.pi * min(1.0, t * 1.15)) ** 0.7
        pts.append((c - w, y))
    pts.append((c - S * 0.05, c - S * 0.36))
    pts.append((c, c - S * 0.30))
    pts.append((c + S * 0.05, c - S * 0.36))
    for t in np.linspace(1, 0, 40):
        y = c + S * 0.36 - S * 0.72 * t
        w = S * 0.26 * math.sin(math.pi * min(1.0, t * 1.15)) ** 0.7
        pts.append((c + w, y))
    d.polygon(pts, fill=PINK_LIGHT, outline=PINK, width=int(S * 0.03))
    d.line([(c, c - S * 0.2), (c, c + S * 0.2)], fill=PINK, width=int(S * 0.012))
    return im.resize((size, size), Image.LANCZOS)


def contact_sheet(files):
    tiles = []
    for name, im in files.items():
        if name.endswith(("_ink.png", "_glow.png")):
            continue
        for bg in ((16, 10, 20), (255, 232, 40)):
            base = Image.new("RGBA", im.size, bg + (255,))
            if name == "crest_core.png":
                for layer, col in (("crest_glow.png", (255, 170, 40, 150)), ("crest_ink.png", INK)):
                    k = Image.new("RGBA", im.size, (0, 0, 0, 0))
                    k.paste(col, (0, 0), files[layer].split()[3])
                    base.alpha_composite(k)
                k = Image.new("RGBA", im.size, (0, 0, 0, 0))
                k.paste(GOLD, (0, 0), im.split()[3])
                base.alpha_composite(k)
            else:
                base.alpha_composite(im)
            t = base.convert("RGB")
            t.thumbnail((512, 512), Image.LANCZOS)
            pad = Image.new("RGB", (512, 512), bg)
            pad.paste(t, ((512 - t.width) // 2, (512 - t.height) // 2))
            tiles.append(pad)
    cols = 4
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * 512, rows * 512))
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % cols) * 512, (i // cols) * 512))
    return sheet


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    files = {}
    core, ink, glow = crest()
    files.update({"crest_core.png": core, "crest_ink.png": ink, "crest_glow.png": glow})
    files["flower_4x4.png"] = flower_flipbook()
    files["ladybug_4x4.png"] = ladybug_flipbook()
    files["petal.png"] = petal()
    for name, im in files.items():
        im.save(OUT / name)
    contact_sheet(files).save(OUT / "_sheet.jpg", quality=88)
    print("wrote", len(files), "textures")


if __name__ == "__main__":
    main()
