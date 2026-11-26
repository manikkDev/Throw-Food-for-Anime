#!/usr/bin/env python3
"""DemonCircle (Anos Voldigoad's aura) textures, made from maths: nothing harvested, nothing stock.

    python tools/auras/demon_circle/make_tex.py        -> assets/auras/demon_circle/*.png (+ _sheet.jpg)

The look (The Misfit of Demon King Academy): his power is MAGIC CIRCLES, layered rings of demon script and geometric
lattices that stack and counter-rotate, crimson-hot lines over black, and the Demon Eyes of Destruction (crimson
ring pupils). The script here is our own alphabet (24 glyphs from strokes on a 3x3 node grid), not the show's.

Every circle comes as two textures, white + alpha, tinted by its layer:
  *_core.png   the crisp lines (tinted crimson-hot)
  *_ink.png    the same lines dilated and softened (tinted black: the dark copy under the bright strokes)
  outer        a double ring with a band of runes and tick marks
  mid          a heptagram and a hexagram over each other, circles at the points, inner arcs
  inner        a crest: rings, twelve spokes, a demon-eye at the centre
  halo         the vertical array behind him: two rune bands, an octagram, a ring of small circles
  cast         the small casting arrays at his hands
plus
  glyphs_4x4.png   16 single runes (a particle per rune, a random frame each)
  eye.png          a Demon Eye: crimson ring pupil with a hot core and spokes (white + alpha, tinted crimson)
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets" / "auras" / "demon_circle"
RNG = np.random.default_rng(2024)

# ---------------------------------------------------------------- the alphabet
NODES = [(x, y) for y in (0, 1, 2) for x in (0, 1, 2)]


def make_alphabet(n=24):
    glyphs = []
    seen = set()
    while len(glyphs) < n:
        k = int(RNG.integers(2, 5))
        strokes = []
        for _ in range(k):
            a, b = RNG.choice(9, 2, replace=False)
            strokes.append(tuple(sorted((int(a), int(b)))))
        strokes = tuple(sorted(set(strokes)))
        if strokes in seen or len(strokes) < 2:
            continue
        seen.add(strokes)
        extra = int(RNG.integers(0, 3))  # 0 none, 1 a dot, 2 a small arc
        glyphs.append((strokes, extra, int(RNG.integers(0, 9))))
    return glyphs


ALPHABET = make_alphabet()


def draw_glyph(d: ImageDraw.ImageDraw, cx, cy, size, angle, glyph, width):
    strokes, extra, node = glyph
    ca, sa = math.cos(angle), math.sin(angle)

    def P(i):
        x, y = NODES[i]
        lx, ly = (x - 1) * size / 2, (y - 1) * size / 2
        return (cx + lx * ca - ly * sa, cy + lx * sa + ly * ca)

    for a, b in strokes:
        d.line([P(a), P(b)], fill=255, width=width)
    px, py = P(node)
    r = size * 0.11
    if extra == 1:
        d.ellipse([px - r, py - r, px + r, py + r], fill=255)
    elif extra == 2:
        d.arc([px - r * 2, py - r * 2, px + r * 2, py + r * 2], 0, 180, fill=255, width=width)


# ---------------------------------------------------------------- drawing helpers (supersampled canvas)
class Canvas:
    def __init__(self, size=1024, ss=2):
        self.size, self.ss = size, ss
        self.S = size * ss
        self.im = Image.new("L", (self.S, self.S), 0)
        self.d = ImageDraw.Draw(self.im)
        self.c = self.S / 2

    def r(self, frac):
        return frac * self.S / 2

    def w(self, studs_frac):
        return max(1, int(studs_frac * self.S / 2))

    def ring(self, rf, wf):
        c, r = self.c, self.r(rf)
        self.d.ellipse([c - r, c - r, c + r, c + r], outline=255, width=self.w(wf))

    def polygon_star(self, rf, n, step, wf, rot=0.0):
        pts = [(self.c + self.r(rf) * math.cos(rot + 2 * math.pi * i * step / n - math.pi / 2),
                self.c + self.r(rf) * math.sin(rot + 2 * math.pi * i * step / n - math.pi / 2)) for i in range(n + 1)]
        self.d.line(pts, fill=255, width=self.w(wf), joint="curve")

    def ticks(self, r0, r1, n, wf, every=1, long_r=None):
        for i in range(n):
            a = 2 * math.pi * i / n
            rr1 = long_r if (long_r and i % every == 0) else r1
            p0 = (self.c + self.r(r0) * math.cos(a), self.c + self.r(r0) * math.sin(a))
            p1 = (self.c + self.r(rr1) * math.cos(a), self.c + self.r(rr1) * math.sin(a))
            self.d.line([p0, p1], fill=255, width=self.w(wf))

    def rune_band(self, rf, count, gf, wf, seed):
        rng = np.random.default_rng(seed)
        for i in range(count):
            a = 2 * math.pi * i / count
            g = ALPHABET[int(rng.integers(0, len(ALPHABET)))]
            draw_glyph(self.d, self.c + self.r(rf) * math.cos(a), self.c + self.r(rf) * math.sin(a), self.r(gf),
                       a + math.pi / 2, g, self.w(wf))

    def small_circle(self, rf, af, sf, wf, fill=False):
        x = self.c + self.r(rf) * math.cos(af)
        y = self.c + self.r(rf) * math.sin(af)
        s = self.r(sf)
        if fill:
            self.d.ellipse([x - s, y - s, x + s, y + s], fill=255)
        else:
            self.d.ellipse([x - s, y - s, x + s, y + s], outline=255, width=self.w(wf))

    def arc(self, rf, a0, a1, wf):
        c, r = self.c, self.r(rf)
        self.d.arc([c - r, c - r, c + r, c + r], a0, a1, fill=255, width=self.w(wf))

    def finish(self):
        core = self.im.resize((self.size, self.size), Image.LANCZOS)
        ink = self.im.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(self.S * 0.003))
        ink = ink.resize((self.size, self.size), Image.LANCZOS)
        glow = self.im.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(self.S * 0.012))
        glow = glow.resize((self.size, self.size), Image.LANCZOS)
        g = np.asarray(glow, float)
        g = np.clip(g / max(g.max(), 1) * 1.6, 0, 1) * 255
        return rgba(core), rgba(ink), rgba(Image.fromarray(g.astype(np.uint8)))


def rgba(lum: Image.Image) -> Image.Image:
    a = np.asarray(lum, np.uint8)
    return Image.fromarray(np.dstack([np.full(a.shape + (3,), 255, np.uint8), a]), "RGBA")


# ---------------------------------------------------------------- the circles
def outer():
    c = Canvas()
    c.ring(0.985, 0.012)
    c.ring(0.955, 0.006)
    c.rune_band(0.885, 40, 0.07, 0.007, 11)
    c.ring(0.815, 0.010)
    c.ticks(0.79, 0.815, 120, 0.004, every=10, long_r=0.76)
    c.ring(0.74, 0.005)
    for i in range(8):
        c.small_circle(0.955, 2 * math.pi * i / 8, 0.028, 0.006)
        c.small_circle(0.955, 2 * math.pi * i / 8, 0.012, 0.006, fill=True)
    return c.finish()


def mid():
    c = Canvas()
    c.ring(0.98, 0.010)
    c.polygon_star(0.96, 7, 3, 0.008)
    c.polygon_star(0.96, 6, 1, 0.006, rot=math.pi / 6)
    c.polygon_star(0.80, 6, 2, 0.006)
    for i in range(7):
        a = 2 * math.pi * i / 7 - math.pi / 2
        c.small_circle(0.96, a, 0.05, 0.007)
        c.small_circle(0.96, a, 0.022, 0.006, fill=True)
    c.ring(0.62, 0.008)
    for k in range(6):
        c.arc(0.52, k * 60 + 8, k * 60 + 52, 0.006)
    c.rune_band(0.42, 16, 0.07, 0.006, 23)
    return c.finish()


def inner():
    c = Canvas()
    c.ring(0.97, 0.014)
    c.ring(0.90, 0.006)
    c.ticks(0.66, 0.90, 12, 0.008)
    c.ring(0.66, 0.010)
    c.polygon_star(0.64, 5, 2, 0.008)
    c.ring(0.36, 0.010)
    # the demon eye at the centre: an almond with a slit ring pupil
    d, S, cc = c.d, c.S, c.c
    w, h = c.r(0.30), c.r(0.16)
    pts = [(cc + w * t, cc - h * (1 - t * t)) for t in np.linspace(-1, 1, 30)]
    pts += [(cc + w * t, cc + h * (1 - t * t)) for t in np.linspace(1, -1, 30)]
    d.line(pts + [pts[0]], fill=255, width=c.w(0.012), joint="curve")
    rr = c.r(0.11)
    d.ellipse([cc - rr, cc - rr, cc + rr, cc + rr], outline=255, width=c.w(0.012))
    rr = c.r(0.04)
    d.ellipse([cc - rr, cc - rr, cc + rr, cc + rr], fill=255)
    del S
    return c.finish()


def halo():
    c = Canvas()
    c.ring(0.985, 0.012)
    c.rune_band(0.92, 36, 0.06, 0.006, 41)
    c.ring(0.855, 0.008)
    c.polygon_star(0.84, 8, 3, 0.007)
    c.ring(0.62, 0.006)
    for i in range(12):
        c.small_circle(0.73, 2 * math.pi * i / 12, 0.04, 0.006)
    c.rune_band(0.52, 18, 0.06, 0.006, 43)
    c.ring(0.44, 0.008)
    c.polygon_star(0.42, 6, 2, 0.006)
    c.ring(0.18, 0.010)
    return c.finish()


def cast():
    c = Canvas(512)
    c.ring(0.97, 0.02)
    c.rune_band(0.84, 14, 0.12, 0.012, 61)
    c.ring(0.70, 0.014)
    c.polygon_star(0.68, 5, 2, 0.014)
    c.ring(0.30, 0.016)
    c.small_circle(0.0, 0, 0.08, 0.01, fill=True)
    return c.finish()


def glyph_sheet() -> Image.Image:
    S = 256
    sheet = Image.new("L", (S * 4, S * 4), 0)
    for f in range(16):
        im = Image.new("L", (S * 2, S * 2), 0)
        d = ImageDraw.Draw(im)
        draw_glyph(d, S, S, S * 1.1, 0, ALPHABET[f], 14)
        d.ellipse([S - S * 0.82, S - S * 0.82, S + S * 0.82, S + S * 0.82], outline=255, width=6)
        glow = im.filter(ImageFilter.GaussianBlur(10))
        a = np.maximum(np.asarray(im, float), np.asarray(glow, float) * 1.4).clip(0, 255).astype(np.uint8)
        sheet.paste(Image.fromarray(a).resize((S, S), Image.LANCZOS), ((f % 4) * S, (f // 4) * S))
    return rgba(sheet)


def eye(size=256) -> Image.Image:
    yy, xx = np.mgrid[0:size, 0:size].astype(float)
    x = (xx - (size - 1) / 2) / (size / 2)
    y = (yy - (size - 1) / 2) / (size / 2)
    r = np.hypot(x, y)
    th = np.arctan2(y, x)
    ring = np.exp(-((r - 0.55) / 0.05) ** 2) + np.exp(-((r - 0.30) / 0.035) ** 2) * 0.9
    spokes = (np.abs(np.sin(th * 4)) < 0.12) * (r > 0.32) * (r < 0.53) * 0.8
    core = np.exp(-(r / 0.12) ** 2)
    halo = np.exp(-(r / 0.55) ** 2) * 0.35
    a = np.clip(ring + spokes + core + halo, 0, 1) * (1 - np.clip((r - 0.85) / 0.15, 0, 1))
    return rgba(Image.fromarray((a * 255).astype(np.uint8)))


def contact_sheet(files: dict[str, Image.Image]) -> Image.Image:
    tiles = []
    for name, im in files.items():
        if not name.endswith(("_core.png", "glyphs_4x4.png", "eye.png")):
            continue
        for bg, tint in (((14, 10, 12), (255, 70, 60)), ((230, 120, 200), (255, 70, 60))):
            base = Image.new("RGBA", im.size, bg + (255,))
            ink = files.get(name.replace("_core", "_ink"))
            if ink is not None and ink is not im:
                inkc = Image.new("RGBA", im.size, (0, 0, 0, 0))
                inkc.paste((10, 4, 6, 255), (0, 0), ink.split()[3])
                base.alpha_composite(inkc)
            col = Image.new("RGBA", im.size, (0, 0, 0, 0))
            col.paste(tint + (255,), (0, 0), im.split()[3])
            base.alpha_composite(col)
            t = base.convert("RGB")
            t.thumbnail((512, 512), Image.LANCZOS)
            tiles.append(t)
    cols = 4
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * 512, rows * 512), (0, 0, 0))
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % cols) * 512, (i // cols) * 512))
    return sheet


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    files: dict[str, Image.Image] = {}
    for name, fn in (("outer", outer), ("mid", mid), ("inner", inner), ("halo", halo), ("cast", cast)):
        core, ink, glow = fn()
        files[f"{name}_core.png"] = core
        files[f"{name}_ink.png"] = ink
        files[f"{name}_glow.png"] = glow
    files["glyphs_4x4.png"] = glyph_sheet()
    files["eye.png"] = eye()
    for name, im in files.items():
        im.save(OUT / name)
    print("wrote", len(files), "textures to", OUT.relative_to(ROOT))
    contact_sheet(files).save(OUT / "_sheet.jpg", quality=88)


if __name__ == "__main__":
    main()
