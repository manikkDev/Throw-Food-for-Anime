"""Seamless tile textures for the map's plain parts -> assets/map/textures/*.png (brief D).

    python tools/map/make_textures.py

Every tile is drawn in WHITE / dark grey with alpha on a transparent background, so the part's own
Color shows through and Texture.Color3 tints the lines: one tile serves all six zones. Each tile is
drawn on a 3 x 3 canvas of its own period and the middle cut out, so it repeats without a seam, at
2x and downsampled for clean edges. StudsPerTile per use is in assets/map/textures/README.md and in
TEXTURES below (emit_chunks.py reads the same table through design/map.json).
"""
from __future__ import annotations

import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "map", "textures")
N = 512          # final tile size
S = 2            # supersample
T = N * S        # tile size while drawing
WHITE = (255, 255, 255)
INK = (40, 36, 48)

# name -> (what it is for, StudsPerTile)
TEXTURES = {
    "seigaiha": ("wave scales: Realm of Legends landing strip", 12),
    "asanoha": ("hemp-leaf star lattice: Sakura Schoolyard landing strip", 12),
    "kikko": ("tortoise-shell hexagons: Ninja Village landing strip", 12),
    "checker": ("two-tone check: Hero City landing strip and the plot training yard", 8),
    "planks": ("boards with staggered joints: Pirate Harbor landing strip and wall panels", 10),
    "setts": ("stone setts: Samurai Castle landing strip, walkways, lane mouths, margin paving", 8),
    "shoji": ("shoji lattice: Ninja Village and Hero City wall panels", 8),
    "brick": ("running-bond brick: Sakura Schoolyard and hub wall panels", 8),
    "panels": ("cladding panels with recessed seams: Samurai Castle and Realm of Legends wall panels", 8),
    "banner": ("ONE cloth face (not tiled): crest roundel + stripe borders; banners, shop signs, posters", "face"),
    "noren": ("ONE noren strip (not tiled): brush-stroke band + wave hem; each of the three noren strips", "face"),
}


def canvas():
    return Image.new("RGBA", (3 * T, 3 * T), (0, 0, 0, 0))


def finish(img, name):
    tile = img.crop((T, T, 2 * T, 2 * T)).resize((N, N), Image.LANCZOS)
    os.makedirs(OUT, exist_ok=True)
    tile.save(os.path.join(OUT, f"{name}.png"))


def seigaiha():
    img = canvas()
    d = ImageDraw.Draw(img)
    R = 64 * S
    rows = int(3 * T / (R / 2)) + 4
    for j in range(-2, rows):            # bottom rows drawn last overlap the ones above: the scale look
        y = j * R / 2
        off = (j % 2) * R
        for i in range(-2, int(3 * T / (2 * R)) + 3):
            x = i * 2 * R + off
            for k, (r, a) in enumerate(((R, 70), (R * 0.78, 0), (R * 0.56, 70), (R * 0.34, 0), (R * 0.14, 70))):
                fill = (*WHITE, a) if a else (0, 0, 0, 0)
                d.ellipse([x - r, y - r, x + r, y + r], fill=fill)
            for r in (R, R * 0.78, R * 0.56, R * 0.34):
                d.ellipse([x - r, y - r, x + r, y + r], outline=(*WHITE, 235), width=5 * S)
    finish(img, "seigaiha")


def tri_grid(period_x, period_y):
    """Vertices of a (squashed) triangle lattice covering the 3x canvas, keyed (i, j)."""
    V = {}
    for j in range(-1, int(3 * T / period_y) + 2):
        for i in range(-1, int(3 * T / period_x) + 2):
            V[(i, j)] = (i * period_x + (j % 2) * period_x / 2, j * period_y)
    return V


def asanoha():
    img = canvas()
    d = ImageDraw.Draw(img)
    px, py = 128 * S, 64 * S       # 4 x 8 triangles per tile (vertically squashed 15% to tile at 512)
    V = tri_grid(px, py)
    w = 3 * S
    for (i, j), (x, y) in V.items():
        for nb in ((i + 1, j), (i if j % 2 == 0 else i + 1, j + 1), (i - 1 if j % 2 == 0 else i, j + 1)):
            if nb in V:
                d.line([(x, y), V[nb]], fill=(*WHITE, 230), width=w)
        # two triangles below this vertex: centroid -> each corner (the hemp leaf)
        a = V.get((i, j))
        b = V.get((i + 1, j))
        c = V.get((i if j % 2 == 0 else i + 1, j + 1))
        e = V.get((i - 1 if j % 2 == 0 else i, j + 1))
        for tri in ((a, b, c), (a, c, e)):
            if all(tri):
                cx = sum(p[0] for p in tri) / 3
                cy = sum(p[1] for p in tri) / 3
                for p in tri:
                    d.line([(cx, cy), p], fill=(*WHITE, 170), width=w - S)
    finish(img, "asanoha")


def kikko():
    img = canvas()
    d = ImageDraw.Draw(img)
    P = 256 * S            # horizontal period: two hex columns
    a = P / 3              # flat-top hex "side" across x
    h = 128 * S            # vertical period (squashed to tile)
    for col in range(-1, int(3 * T / (P / 2)) + 2):
        for row in range(-1, int(3 * T / h) + 2):
            cx = col * P / 2
            cy = row * h + (col % 2) * h / 2
            for inset, width, alpha in ((0, 6 * S, 235), (14 * S, 2 * S, 150)):
                aa, hh = a - inset, h / 2 - inset * 0.9
                pts = [(cx - aa, cy), (cx - aa / 2, cy - hh), (cx + aa / 2, cy - hh), (cx + aa, cy),
                       (cx + aa / 2, cy + hh), (cx - aa / 2, cy + hh), (cx - aa, cy)]
                d.line(pts, fill=(*WHITE, alpha), width=width, joint="curve")
    finish(img, "kikko")


def checker():
    img = canvas()
    d = ImageDraw.Draw(img)
    c = 128 * S
    for j in range(0, 3 * T, c):
        for i in range(0, 3 * T, c):
            if (i // c + j // c) % 2 == 0:
                d.rectangle([i, j, i + c - 1, j + c - 1], fill=(*WHITE, 95))
            d.rectangle([i, j, i + c - 1, j + c - 1], outline=(*WHITE, 150), width=2 * S)
    finish(img, "checker")


def planks():
    img = canvas()
    d = ImageDraw.Draw(img)
    bh = 128 * S
    for r, y in enumerate(range(0, 3 * T, bh)):
        d.rectangle([0, y, 3 * T, y + 4 * S], fill=(*INK, 170))                  # board seam
        d.rectangle([0, y + 5 * S, 3 * T, y + 9 * S], fill=(*WHITE, 70))          # lit edge
        for g in range(3):                                                        # grain
            gy = y + bh * (0.3 + 0.2 * g)
            d.line([(0, gy), (3 * T, gy + 0)], fill=(*INK, 40), width=2 * S)
        off = (r % 4) * T // 4
        for x in range(off, 3 * T + T, T // 2):                                   # butt joints
            d.rectangle([x, y, x + 4 * S, y + bh], fill=(*INK, 160))
    finish(img, "planks")


def setts():
    img = canvas()
    d = ImageDraw.Draw(img)
    rh, sw, g = 128 * S, 256 * S, 7 * S
    for r, y in enumerate(range(0, 3 * T, rh)):
        off = (r % 2) * sw // 2
        for x in range(off - sw, 3 * T + sw, sw):
            d.rounded_rectangle([x + g, y + g, x + sw - g, y + rh - g], radius=18 * S, fill=(*WHITE, 45),
                                outline=(*WHITE, 120), width=3 * S)
        d.rectangle([0, y, 3 * T, y + g], fill=(*INK, 150))
    for r, y in enumerate(range(0, 3 * T, rh)):
        off = (r % 2) * sw // 2
        for x in range(off - sw, 3 * T + sw, sw):
            d.rectangle([x - g // 2, y, x + g // 2, y + rh], fill=(*INK, 150))
    finish(img, "setts")


def shoji():
    img = canvas()
    d = ImageDraw.Draw(img)
    c, w = 128 * S, 9 * S
    d.rectangle([0, 0, 3 * T, 3 * T], fill=(*WHITE, 60))                       # paper
    for x in range(0, 3 * T, c):
        d.rectangle([x - w // 2, 0, x + w // 2, 3 * T], fill=(*INK, 200))
    for y in range(0, 3 * T, c):
        d.rectangle([0, y - w // 2, 3 * T, y + w // 2], fill=(*INK, 200))
    for x in range(0, 3 * T, T // 2):                                         # heavier frame every 4
        d.rectangle([x - w, 0, x + w, 3 * T], fill=(*INK, 220))
    finish(img, "shoji")


def brick():
    img = canvas()
    d = ImageDraw.Draw(img)
    bh, bw, m = 64 * S, 128 * S, 6 * S
    for r, y in enumerate(range(0, 3 * T, bh)):
        d.rectangle([0, y, 3 * T, y + m], fill=(*WHITE, 200))
        d.rectangle([0, y + bh - 6 * S, 3 * T, y + bh], fill=(*INK, 50))       # shadow under each course
        off = (r % 2) * bw // 2
        for x in range(off - bw, 3 * T + bw, bw):
            d.rectangle([x, y, x + m, y + bh], fill=(*WHITE, 200))
    finish(img, "brick")


def panels():
    img = canvas()
    d = ImageDraw.Draw(img)
    c = 256 * S
    for j in range(0, 3 * T, c):
        for i in range(0, 3 * T, c):
            d.rectangle([i, j, i + c, j + 8 * S], fill=(*INK, 170))
            d.rectangle([i, j, i + 8 * S, j + c], fill=(*INK, 170))
            d.rectangle([i + 8 * S, j + 8 * S, i + c, j + 16 * S], fill=(*WHITE, 110))
            d.rectangle([i + 8 * S, j + 8 * S, i + 16 * S, j + c], fill=(*WHITE, 110))
            d.rectangle([i + 48 * S, j + 48 * S, i + c - 40 * S, j + c - 40 * S], outline=(*WHITE, 80), width=3 * S)
    finish(img, "panels")


def _cloth(draw_fn, name):
    """A whole-face cloth design (not a repeating tile): drawn once, stretched over the cloth part by
    StudsPerTileU/V = the part's face size (gen_lane_style sets su/sv)."""
    img = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(img))
    img.resize((N, N), Image.LANCZOS).save(os.path.join(OUT, f"{name}.png"))


def banner():
    def f(d):
        w = T
        for y0 in (int(0.04 * w), int(0.90 * w)):                       # stripe borders top and bottom
            d.rectangle([0, y0, w, y0 + int(0.025 * w)], fill=(*WHITE, 235))
            d.rectangle([0, y0 + int(0.04 * w), w, y0 + int(0.055 * w)], fill=(*WHITE, 235))
        cx, cy, r = w / 2, 0.36 * w, 0.30 * w                           # the crest (mon): ring + three-comma swirl
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(*WHITE, 245), width=int(0.035 * w))
        for k in range(3):
            a = math.radians(90 + k * 120)
            px, py = cx + 0.12 * w * math.cos(a), cy + 0.12 * w * math.sin(a)
            rr = 0.085 * w
            d.ellipse([px - rr, py - rr, px + rr, py + rr], fill=(*WHITE, 245))
            a2 = a + math.radians(70)
            d.line([(px, py), (cx + 0.22 * w * math.cos(a2), cy + 0.22 * w * math.sin(a2))], fill=(*WHITE, 245),
                   width=int(0.05 * w))
        for k in range(3):                                              # three brush marks below (no fake text)
            y = 0.72 * w + k * 0.05 * w
            d.line([(0.3 * w, y), (0.7 * w, y - 0.02 * w)], fill=(*WHITE, 200), width=int(0.022 * w))
    _cloth(f, "banner")


def noren():
    def f(d):
        w = T
        pts = [(0, 0.40 * w)]                                           # a brush-stroke band across the strip
        for k in range(1, 9):
            pts.append((k * w / 8, 0.40 * w + (0.03 * w if k % 2 else -0.02 * w)))
        d.line(pts, fill=(*WHITE, 230), width=int(0.13 * w), joint="curve")
        for k in range(-1, 9):                                          # wave hem
            x = k * w / 4
            d.arc([x, 0.84 * w, x + w / 4, 0.98 * w], 180, 360, fill=(*WHITE, 240), width=int(0.025 * w))
        d.rectangle([0, 0.95 * w, w, w], fill=(*WHITE, 240))
        d.ellipse([0.38 * w, 0.12 * w, 0.62 * w, 0.30 * w], outline=(*WHITE, 230), width=int(0.03 * w))
    _cloth(f, "noren")


def readme():
    lines = ["# Map tile textures (GENERATED by tools/map/make_textures.py)", "",
             "Seamless 512 x 512 PNG tiles, drawn white / dark grey with alpha on transparency: the PART's colour",
             "shows through and `Texture.Color3` tints the lines, so one tile serves every zone.",
             "",
             "Upload each as an **Image** (never Decal), then write `assets/map/ids_textures.json`:",
             "`{\"seigaiha\": 1234567890, ...}`. `tools/map/emit_chunks.py` adds a `Texture` to every part",
             "whose spec names a texture that has an id there (Top face for floors, the lane-facing faces for",
             "wall panels); a texture with no id leaves the part plain coloured.",
             "",
             "| File | For | StudsPerTile |", "|---|---|---|"]
    for n, (what, st) in TEXTURES.items():
        lines.append(f"| `{n}.png` | {what} | {st} |")
    with open(os.path.join(OUT, "README.md"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    for fn in (seigaiha, asanoha, kikko, checker, planks, setts, shoji, brick, panels, banner, noren):
        fn()
        print("wrote", fn.__name__)
    readme()
