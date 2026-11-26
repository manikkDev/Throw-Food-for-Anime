#!/usr/bin/env python3
"""CompassNeedle (Akaza's aura) textures, made from maths: nothing harvested, nothing stock.

    python tools/auras/compass_needle/make_tex.py        -> assets/auras/compass_needle/*.png (+ _sheet.jpg)

The look (Demon Slayer, Upper Rank Three, Blood Demon Art "Destructive Death"): the Compass Needle, a snowflake
compass (from Koyuki's hairpin) that opens on the ground under him as he senses a fighter's spirit; his blows land
as ice-blue shockwaves with snowflake-shaped flashes. Ice-white, cyan, electric blue; deep navy ink for contrast.

Ground plates come as three white+alpha layers, tinted by the builder (glow under, ink, core on top):
  rose_core / rose_ink / rose_glow     the compass rose: tick ring, cardinal marks, twelve needles
  flake_core / flake_ink / flake_glow  the snowflake at its heart: six branching arms, a hexagon, a ring
Particles (white + alpha):
  snow.png         one crisp six-armed snowflake with a soft halo (fighting spirit)
  impact_4x4.png   16 frames: a snowflake flash bursts out of a hot core inside an expanding shock ring, then frays
  streak.png       a thin vertical needle of light (VelocityParallel)
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets" / "auras" / "compass_needle"


def rgba(lum: Image.Image) -> Image.Image:
    a = np.asarray(lum, np.uint8)
    return Image.fromarray(np.dstack([np.full(a.shape + (3,), 255, np.uint8), a]), "RGBA")


def trio(im: Image.Image, size: int):
    """core (crisp), ink (dilated + soft), glow (wide blur) from one supersampled line drawing"""
    S = im.width
    core = im.resize((size, size), Image.LANCZOS)
    ink = im.filter(ImageFilter.MaxFilter(11)).filter(ImageFilter.GaussianBlur(S * 0.0035)).resize((size, size), Image.LANCZOS)
    glow = im.filter(ImageFilter.MaxFilter(7)).filter(ImageFilter.GaussianBlur(S * 0.014)).resize((size, size), Image.LANCZOS)
    g = np.asarray(glow, float)
    g = np.clip(g / max(g.max(), 1) * 1.7, 0, 1) * 255
    return rgba(core), rgba(ink), rgba(Image.fromarray(g.astype(np.uint8)))


def snowflake(d: ImageDraw.ImageDraw, cx, cy, R, w, rot=0.0, branches=3):
    """six arms, each with `branches` pairs of side twigs angled outward, a small hexagon at the heart"""
    for k in range(6):
        a = rot + k * math.pi / 3
        ca, sa = math.cos(a), math.sin(a)
        d.line([(cx, cy), (cx + R * ca, cy + R * sa)], fill=255, width=w)
        for b in range(branches):
            t = 0.35 + 0.2 * b
            px, py = cx + R * t * ca, cy + R * t * sa
            L = R * (0.32 - 0.07 * b)
            for s in (-1, 1):
                ab = a + s * math.radians(55)
                d.line([(px, py), (px + L * math.cos(ab), py + L * math.sin(ab))], fill=255, width=max(1, int(w * 0.8)))
        # a small diamond at the arm's tip
        tx, ty = cx + R * ca, cy + R * sa
        q = R * 0.07
        d.polygon([(tx + q * ca, ty + q * sa), (tx - q * sa, ty + q * ca), (tx - q * ca, ty - q * sa),
                   (tx + q * sa, ty - q * ca)], fill=255)
    hexr = R * 0.16
    pts = [(cx + hexr * math.cos(rot + k * math.pi / 3 + math.pi / 6), cy + hexr * math.sin(rot + k * math.pi / 3 + math.pi / 6))
           for k in range(7)]
    d.line(pts, fill=255, width=w)


def rose(size=1024):
    S = size * 2
    im = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(im)
    c = S / 2

    def R(f):
        return f * S / 2

    def W(f):
        return max(1, int(f * S / 2))

    for rf, wf in ((0.985, 0.012), (0.95, 0.006), (0.80, 0.008), (0.56, 0.006)):
        d.ellipse([c - R(rf), c - R(rf), c + R(rf), c + R(rf)], outline=255, width=W(wf))
    # 72 ticks between the two outer rings, every 6th long, every 18th a cardinal triangle
    for i in range(72):
        a = 2 * math.pi * i / 72
        r0 = 0.88 if i % 6 else 0.82
        d.line([(c + R(r0) * math.cos(a), c + R(r0) * math.sin(a)), (c + R(0.95) * math.cos(a), c + R(0.95) * math.sin(a))],
               fill=255, width=W(0.005 if i % 6 else 0.008))
    for k in range(4):
        a = k * math.pi / 2 - math.pi / 2
        tip = (c + R(1.0) * math.cos(a), c + R(1.0) * math.sin(a))
        l = (c + R(0.9) * math.cos(a - 0.05), c + R(0.9) * math.sin(a - 0.05))
        r = (c + R(0.9) * math.cos(a + 0.05), c + R(0.9) * math.sin(a + 0.05))
        d.polygon([tip, l, r], fill=255)
    # twelve needles: long thin diamonds from the inner ring out past the middle ring (alternating lengths)
    for k in range(12):
        a = 2 * math.pi * k / 12 - math.pi / 2
        L = 0.97 if k % 2 == 0 else 0.76
        half = 0.035 if k % 2 == 0 else 0.026
        ca, sa = math.cos(a), math.sin(a)
        base = 0.30
        mid = 0.52
        p_tip = (c + R(L) * ca, c + R(L) * sa)
        p_in = (c + R(base) * ca, c + R(base) * sa)
        p_l = (c + R(mid) * ca - R(half) * sa, c + R(mid) * sa + R(half) * ca)
        p_r = (c + R(mid) * ca + R(half) * sa, c + R(mid) * sa - R(half) * ca)
        d.line([p_in, p_l, p_tip, p_r, p_in], fill=255, width=W(0.006), joint="curve")
        d.line([p_in, p_tip], fill=255, width=W(0.003))
    return trio(im, size)


def flake(size=1024):
    S = size * 2
    im = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(im)
    c = S / 2
    snowflake(d, c, c, S * 0.44, max(2, int(S * 0.008)), rot=-math.pi / 2, branches=3)
    r = S * 0.485
    d.ellipse([c - r, c - r, c + r, c + r], outline=255, width=max(2, int(S * 0.007)))
    hexr = S * 0.30
    pts = [(c + hexr * math.cos(k * math.pi / 3), c + hexr * math.sin(k * math.pi / 3)) for k in range(7)]
    d.line(pts, fill=255, width=max(2, int(S * 0.005)))
    return trio(im, size)


def snow(size=128):
    S = size * 4
    im = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(im)
    snowflake(d, S / 2, S / 2, S * 0.40, max(2, int(S * 0.03)), branches=2)
    glow = im.filter(ImageFilter.GaussianBlur(S * 0.04))
    a = np.maximum(np.asarray(im, float), np.asarray(glow, float) * 1.2).clip(0, 255).astype(np.uint8)
    return rgba(Image.fromarray(a).resize((size, size), Image.LANCZOS))


def impact():
    F = 256
    S = F * 2
    sheet = Image.new("L", (F * 4, F * 4), 0)
    for f in range(16):
        t = f / 15
        im = Image.new("L", (S, S), 0)
        d = ImageDraw.Draw(im)
        c = S / 2
        grow = 1 - (1 - min(t / 0.3, 1)) ** 3
        fade = 1 - max(0.0, (t - 0.35) / 0.65)
        if fade <= 0:
            sheet.paste(im.resize((F, F), Image.LANCZOS), ((f % 4) * F, (f // 4) * F))
            continue
        # shock ring: expands fast, thins
        rr = S * (0.12 + 0.34 * (1 - (1 - t) ** 2))
        wr = max(1, int(S * 0.03 * (1 - t) + 2))
        d.ellipse([c - rr, c - rr, c + rr, c + rr], outline=int(255 * fade), width=wr)
        # the snowflake flash: big at the peak, arms thin as it fades
        R = S * 0.42 * grow
        snowflake(d, c, c, R, max(1, int(S * 0.02 * fade + 1)), rot=0.3 + t * 0.6, branches=2)
        # hot core
        cr = S * 0.10 * (1 - t) ** 1.5
        d.ellipse([c - cr, c - cr, c + cr, c + cr], fill=255)
        glow = im.filter(ImageFilter.GaussianBlur(S * 0.03))
        a = np.maximum(np.asarray(im, float) * fade, np.asarray(glow, float) * 1.1 * fade).clip(0, 255)
        sheet.paste(Image.fromarray(a.astype(np.uint8)).resize((F, F), Image.LANCZOS), ((f % 4) * F, (f // 4) * F))
    return rgba(sheet)


def streak(size=128):
    yy, xx = np.mgrid[0:size, 0:size].astype(float)
    x = (xx - (size - 1) / 2) / (size / 2)
    y = (yy - (size - 1) / 2) / (size / 2)
    along = np.clip(1 - np.abs(y) ** 1.6, 0, 1)
    head = np.exp(-((y + 0.75) / 0.12) ** 2) * 0.6   # a brighter head at the top end
    a = (np.exp(-(x / 0.035) ** 2) + np.exp(-(x / 0.12) ** 2) * 0.35) * (along + head)
    return rgba(Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)))


def contact_sheet(files) -> Image.Image:
    tiles = []
    for name, im in files.items():
        if not (name.endswith("_core.png") or name in ("snow.png", "impact_4x4.png", "streak.png")):
            continue
        for bg in ((10, 14, 30), (255, 232, 40)):
            base = Image.new("RGBA", im.size, bg + (255,))
            ink = files.get(name.replace("_core", "_ink")) if name.endswith("_core.png") else None
            glow = files.get(name.replace("_core", "_glow")) if name.endswith("_core.png") else None
            if glow is not None:
                g = Image.new("RGBA", im.size, (0, 0, 0, 0))
                g.paste((40, 140, 255, 150), (0, 0), glow.split()[3])
                base.alpha_composite(g)
            if ink is not None:
                k = Image.new("RGBA", im.size, (0, 0, 0, 0))
                k.paste((6, 16, 40, 255), (0, 0), ink.split()[3])
                base.alpha_composite(k)
            col = Image.new("RGBA", im.size, (0, 0, 0, 0))
            col.paste((200, 248, 255, 255), (0, 0), im.split()[3])
            base.alpha_composite(col)
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
    for name, fn in (("rose", rose), ("flake", flake)):
        core, ink, glow = fn()
        files[f"{name}_core.png"], files[f"{name}_ink.png"], files[f"{name}_glow.png"] = core, ink, glow
    files["snow.png"] = snow()
    files["impact_4x4.png"] = impact()
    files["streak.png"] = streak()
    for name, im in files.items():
        im.save(OUT / name)
    contact_sheet(files).save(OUT / "_sheet.jpg", quality=88)
    print("wrote", len(files), "textures")


if __name__ == "__main__":
    main()
