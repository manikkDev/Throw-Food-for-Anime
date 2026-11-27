"""Textures for the food effects of plan 13 phase C (Signature dishes, aroma, favourite).

    python assets/vfx/tools/make_food_tex.py

Writes assets/vfx/textures/<name>.png ("sim:tfa/<name>" in the effects). House rules as in
make_tfa_tex.py: white + alpha so Color tints it (the fish cake and the gold "1" are pre-coloured),
hard edges, 2-3 cel grey levels with a darker rim, padding.
"""
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = Path(__file__).resolve().parent.parent / "textures"
SS = 4
FONTS = Path("C:/Windows/Fonts")


def save(img, name):
    OUT.mkdir(parents=True, exist_ok=True)
    img.save(OUT / f"{name}.png")
    print("wrote", name, img.size)


def down(img, size):
    return img.resize(size, Image.LANCZOS)


def rim_levels(mask, rim_px, body=1.0, rim=0.55):
    """L mask -> luminance: `rim` in a band of rim_px inside the edge, `body` further in."""
    a = np.asarray(mask, np.float32) / 255
    inner = np.asarray(mask.filter(ImageFilter.MinFilter(rim_px * 2 + 1)), np.float32) / 255
    return rim + (body - rim) * inner, a


def narutomaki():
    """The fish-cake slice: a white disc with a scalloped edge and a pink spiral. Pre-coloured."""
    N = 256 * SS
    c = N / 2
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    dx, dy = xx - c, yy - c
    r = np.hypot(dx, dy)
    th = np.arctan2(dy, dx)
    R = N * 0.40 * (1 + 0.055 * np.cos(14 * th))
    disc = r < R
    edge = (r > R - N * 0.022) & disc
    # an Archimedean spiral, 2.2 turns, wide stroke with a round start
    turns = 2.2
    best = np.full((N, N), 1e9, np.float32)
    for k in range(700):
        t = k / 699
        ang = t * turns * 2 * math.pi + 0.6
        rad = N * (0.035 + 0.25 * t)
        px, py = c + rad * math.cos(ang), c + rad * math.sin(ang)
        best = np.minimum(best, np.hypot(xx - px, yy - py))
    spiral = best < N * 0.034
    rgb = np.zeros((N, N, 3), np.float32)
    rgb[:] = (255, 250, 244)
    rgb[edge] = (236, 222, 214)
    rgb[spiral & disc] = (255, 96, 152)
    core = best < N * 0.016
    rgb[core & disc] = (255, 142, 184)
    alpha = (disc * 255).astype(np.uint8)
    img = Image.merge("RGBA", [Image.fromarray(rgb[..., i].astype(np.uint8)) for i in range(3)] + [Image.fromarray(alpha)])
    save(down(img, (256, 256)), "narutomaki")


def numeral_one():
    """A fat gold "1" with a dark rim and a cel highlight. Pre-coloured."""
    N = 256 * SS
    font = ImageFont.truetype(str(FONTS / "impact.ttf"), int(N * 0.86))
    m = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(m)
    box = d.textbbox((0, 0), "1", font=font)
    d.text(((N - (box[2] - box[0])) / 2 - box[0], (N - (box[3] - box[1])) / 2 - box[1]), "1", font=font, fill=255)
    m = m.transform((N, N), Image.AFFINE, (1, 0.16, -N * 0.08, 0, 1, 0), Image.BICUBIC)  # a forward lean
    outer = m.filter(ImageFilter.MaxFilter(SS * 10 + 1))
    a_in = np.asarray(m, np.float32) / 255
    a_out = np.asarray(outer, np.float32) / 255
    yy = np.mgrid[0:N, 0:N][0].astype(np.float32) / N
    rgb = np.zeros((N, N, 3), np.float32)
    rgb[:] = (92, 46, 8)  # the rim
    top, bot = np.array((255, 236, 120), np.float32), np.array((255, 168, 30), np.float32)
    body = top[None, None, :] * (1 - yy[..., None]) + bot[None, None, :] * yy[..., None]
    rgb = rgb * (1 - a_in[..., None]) + body * a_in[..., None]
    # cel highlight: the left third of the stroke
    hi = np.asarray(m.transform((N, N), Image.AFFINE, (1, 0, N * 0.035, 0, 1, N * 0.02)), np.float32) / 255
    band = (a_in > 0.5) & (hi < 0.5)
    rgb[band] = (255, 250, 205)
    img = Image.merge("RGBA", [Image.fromarray(rgb[..., i].astype(np.uint8)) for i in range(3)]
                      + [Image.fromarray((a_out * 255).astype(np.uint8))])
    save(down(img, (256, 256)), "numeral_one")


def chain_ring():
    """A ring of twelve chain links seen from above, alternately flat and on edge. Tintable."""
    N = 512 * SS
    c = N / 2
    m = Image.new("L", (N, N), 0)
    shade = Image.new("L", (N, N), 0)
    R = N * 0.37
    links = 14
    for k in range(links):
        a = 2 * math.pi * k / links
        cx, cy = c + R * math.cos(a), c + R * math.sin(a)
        L, Wd = N * 0.115, (N * 0.062 if k % 2 == 0 else N * 0.026)
        tile = Image.new("L", (int(L * 2.4), int(L * 2.4)), 0)
        td = ImageDraw.Draw(tile)
        tc = tile.size[0] / 2
        stroke = int(N * 0.02)
        if k % 2 == 0:
            td.rounded_rectangle([tc - L, tc - Wd, tc + L, tc + Wd], radius=Wd, outline=255, width=stroke)
        else:
            td.rounded_rectangle([tc - L * 0.9, tc - Wd, tc + L * 0.9, tc + Wd], radius=Wd, fill=255)
        tile = tile.rotate(-math.degrees(a) + 90, resample=Image.BICUBIC)
        box = (int(cx - tc), int(cy - tc))
        m.paste(255, box, tile)
        if k % 2 == 1:
            shade.paste(255, box, tile)
    lum, a = rim_levels(m, SS * 2, 1.0, 0.6)
    lum = np.where(np.asarray(shade) > 128, lum * 0.78, lum)
    g = (np.clip(lum, 0, 1) * 255).astype(np.uint8)
    img = Image.merge("RGBA", [Image.fromarray(g)] * 3 + [m])
    save(down(img, (512, 512)), "chain_ring")


def menace_go():
    """The drifting sound-effect glyph (katakana GO), heavy, leaning, with a dark rim. Tintable."""
    N = 256 * SS
    font = None
    for name, idx in (("YuGothB.ttc", 0), ("meiryob.ttc", 0), ("msgothic.ttc", 0)):
        p = FONTS / name
        if p.exists():
            font = ImageFont.truetype(str(p), int(N * 0.74), index=idx)
            break
    m = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(m)
    box = d.textbbox((0, 0), "ゴ", font=font, stroke_width=int(N * 0.006))
    d.text(((N - (box[2] - box[0])) / 2 - box[0], (N - (box[3] - box[1])) / 2 - box[1]), "ゴ", font=font, fill=255,
           stroke_width=int(N * 0.006), stroke_fill=255)
    m = m.transform((N, N), Image.AFFINE, (1, 0.22, -N * 0.11, 0, 1, 0), Image.BICUBIC).rotate(8, resample=Image.BICUBIC)
    outer = m.filter(ImageFilter.MaxFilter(SS * 6 + 1))
    a_in = np.asarray(m, np.float32) / 255
    lum = 0.22 + 0.78 * a_in  # dark rim outside the stroke
    yy = np.mgrid[0:N, 0:N][0].astype(np.float32) / N
    lum = np.where(a_in > 0.5, 1.0 - 0.22 * yy, lum)  # a little darker toward the foot
    g = (np.clip(lum, 0, 1) * 255).astype(np.uint8)
    img = Image.merge("RGBA", [Image.fromarray(g)] * 3 + [outer])
    save(down(img, (256, 256)), "menace_go")


def sugar_cube():
    """An isometric sugar cube: three cel faces, a rim, sparkle grains on top. Tintable."""
    N = 256 * SS
    c = N / 2
    s = N * 0.30
    top_c = (c, c - s * 0.55)
    def iso(x, y, z):
        return (c + (x - y) * s * 0.866, c - s * 0.1 + (x + y) * s * 0.5 - z * s)
    P = {k: iso(*k) for k in [(0, 0, 0), (1, 0, 0), (0, 1, 0), (1, 1, 0), (0, 0, 1), (1, 0, 1), (0, 1, 1), (1, 1, 1)]}
    faces = [((0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1), 255),      # top
             ((0, 1, 0), (1, 1, 0), (1, 1, 1), (0, 1, 1), 206),      # left
             ((1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1), 166)]      # right
    lum = Image.new("L", (N, N), 0)
    mask = Image.new("L", (N, N), 0)
    dl, dm = ImageDraw.Draw(lum), ImageDraw.Draw(mask)
    for a, b, cc, e, v in faces:
        poly = [P[a], P[b], P[cc], P[e]]
        dl.polygon(poly, fill=v)
        dm.polygon(poly, fill=255)
    rng = np.random.default_rng(3)
    for _ in range(26):  # grains on the top face
        u, v = rng.random(), rng.random()
        x, y = iso(u, v, 1)
        r = N * 0.006
        dl.ellipse([x - r, y - r, x + r, y + r], fill=214)
    for a, b in [((0, 0, 1), (1, 0, 1)), ((0, 0, 1), (0, 1, 1)), ((1, 1, 1), (1, 0, 1)), ((1, 1, 1), (0, 1, 1)), ((1, 1, 1), (1, 1, 0))]:
        dl.line([P[a], P[b]], fill=255, width=int(N * 0.012))
    outer = mask.filter(ImageFilter.MaxFilter(SS * 3 + 1))
    L = np.asarray(lum, np.float32)
    L = np.where(np.asarray(mask) > 128, L, 120)  # the rim
    img = Image.merge("RGBA", [Image.fromarray(L.astype(np.uint8))] * 3 + [outer])
    img = img.rotate(-10, resample=Image.BICUBIC)
    _ = top_c
    save(down(img, (256, 256)), "sugar_cube")


def aroma_wave():
    """One anime aroma line: an upright S-curve that tapers to nothing at both ends. Tintable."""
    W, H = 128 * SS, 256 * SS
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    n = 400
    for i in range(n):
        t = i / (n - 1)
        y = H * (0.94 - 0.88 * t)
        x = W * (0.5 + 0.2 * math.sin(t * 2 * math.pi * 1.15 + 0.4) * (0.55 + 0.45 * t))
        r = W * 0.06 * math.sin(math.pi * t) ** 0.7 * (1 - 0.35 * t) + 1
        d.ellipse([x - r, y - r, x + r, y + r], fill=255)
    soft = m.filter(ImageFilter.GaussianBlur(SS * 1.2))
    lum, _ = rim_levels(m, SS * 2, 1.0, 0.8)
    g = (np.clip(lum, 0, 1) * 255).astype(np.uint8)
    img = Image.merge("RGBA", [Image.fromarray(g)] * 3 + [soft])
    save(down(img, (128, 256)), "aroma_wave")


def pillar_soft():
    """A column of light for a landing pillar: bright centre line, soft sides, fading to the top.
    Drawn as a HORIZONTAL strip (the sim runs a beam texture's width along the beam; the packer
    transposes it for Roblox). Tintable."""
    W, H = 512, 128
    x = np.linspace(0, 1, W, dtype=np.float32)[None, :]
    y = np.linspace(-1, 1, H, dtype=np.float32)[:, None]
    across = np.exp(-(y / 0.6) ** 2) * 0.85 + np.exp(-(y / 0.16) ** 2) * 0.5
    streaks = 0.82 + 0.18 * np.sin(y * 21 + 1.3) * np.sin(x * 9)
    along = np.clip(1.15 - x, 0, 1) ** 1.4 * np.clip(x / 0.04, 0, 1)
    a = np.clip(across * streaks * along, 0, 1)
    edge = np.clip(1 - (np.abs(y) / 0.96) ** 8, 0, 1)
    g = np.full((H, W), 255, np.uint8)
    img = Image.merge("RGBA", [Image.fromarray(g)] * 3 + [Image.fromarray((a * edge * 255).astype(np.uint8))])
    save(img, "pillar_soft")


if __name__ == "__main__":
    narutomaki()
    numeral_one()
    chain_ring()
    menace_go()
    sugar_cube()
    aroma_wave()
    pillar_soft()
