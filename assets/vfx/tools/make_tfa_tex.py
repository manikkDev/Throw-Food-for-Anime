"""This game's own VFX textures (the library has no clover, coin, aurora or screen edge).

    python assets/vfx/tools/make_tfa_tex.py

Writes assets/vfx/textures/<name>.png, referenced in effects as "sim:tfa/<name>".
House rules from the skill (sim/tex/vfxtex.py): white + alpha so Color tints it (except the
pre-coloured coin), hard ~1 px edges with 2-3 cel grey levels and a darker rim, a separate soft
halo for the glow look, 4-11 % padding.
"""
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = Path(__file__).resolve().parent.parent / "textures"
SS = 4  # supersample


def save(img, name):
    OUT.mkdir(parents=True, exist_ok=True)
    img.save(OUT / f"{name}.png")
    print("wrote", name, img.size)


def heart_leaf(d, cx, cy, ang, L, fill):
    """One clover leaf: a heart whose tip sits at (cx, cy) and whose notch points outward along ang."""
    ux, uy = math.cos(ang), math.sin(ang)
    px, py = -uy, ux
    r = 0.31 * L
    for s in (-1, 1):
        ox = cx + ux * 0.64 * L + px * s * 0.27 * L
        oy = cy + uy * 0.64 * L + py * s * 0.27 * L
        d.ellipse([ox - r, oy - r, ox + r, oy + r], fill=fill)
    tip = (cx + ux * 0.02 * L, cy + uy * 0.02 * L)
    left = (cx + ux * 0.70 * L + px * 0.56 * L, cy + uy * 0.70 * L + py * 0.56 * L)
    right = (cx + ux * 0.70 * L - px * 0.56 * L, cy + uy * 0.70 * L - py * 0.56 * L)
    mid = (cx + ux * 0.7 * L, cy + uy * 0.7 * L)
    d.polygon([tip, left, mid, right], fill=fill)


def clover():
    N = 256 * SS
    c = N / 2
    base = Image.new("L", (N, N), 0)
    shade = Image.new("L", (N, N), 0)
    db, ds = ImageDraw.Draw(base), ImageDraw.Draw(shade)
    L = N * 0.33
    for k in range(4):
        a = math.radians(45 + 90 * k + (6 if k % 2 else -4))  # slightly asymmetric
        heart_leaf(db, c, c, a, L, 255)
        heart_leaf(ds, c + math.cos(a) * L * 0.16, c + math.sin(a) * L * 0.16, a, L * 0.72, 255)
    # stem (curved, short)
    for i in range(40):
        t = i / 39
        x = c + t * N * 0.10 + math.sin(t * 2.5) * N * 0.02
        y = c + t * N * 0.36
        r = N * (0.022 - 0.008 * t)
        db.ellipse([x - r, y - r, x + r, y + r], fill=255)
    a = np.asarray(base, np.float32) / 255
    inner = np.asarray(shade, np.float32) / 255
    # cel levels: rim 0.62, body 0.86, inner highlight 1.0, center vein dark
    lum = 0.62 + 0.24 * (a > 0.5) + 0.14 * (inner > 0.5)
    yy, xx = np.mgrid[0:N, 0:N]
    for k in range(4):
        ang = math.radians(45 + 90 * k)
        # vein: distance to the leaf's centre line
        dx, dy = xx - c, yy - c
        along = dx * math.cos(ang) + dy * math.sin(ang)
        across = np.abs(-dx * math.sin(ang) + dy * math.cos(ang))
        vein = (across < N * 0.006) & (along > N * 0.03) & (along < L * 0.6)
        lum = np.where(vein & (a > 0.5), 0.7, lum)
    rgb = np.clip(lum * 255, 0, 255).astype(np.uint8)
    img = Image.merge("RGBA", [Image.fromarray(rgb)] * 3 + [base])
    img = img.resize((256, 256), Image.LANCZOS)
    save(img, "clover_cel")
    # glow: white core + soft halo
    halo = base.filter(ImageFilter.GaussianBlur(N * 0.04))
    h = np.asarray(halo, np.float32) / 255
    alpha = np.clip(np.maximum(a, h * 0.75), 0, 1)
    col = np.clip(0.8 + 0.2 * inner, 0, 1)
    rgbg = (col * 255).astype(np.uint8)
    img = Image.merge("RGBA", [Image.fromarray(rgbg)] * 3 + [Image.fromarray((alpha * 255).astype(np.uint8))])
    save(img.resize((256, 256), Image.LANCZOS), "clover_glow")


def coin_spin():
    """4x4 flipbook of a gold yen coin turning half a revolution (faces are identical, so it loops)."""
    F = 128 * SS
    sheet = Image.new("RGBA", (F * 4, F * 4), (0, 0, 0, 0))
    font = ImageFont.truetype("C:/Windows/Fonts/ariblk.ttf", int(F * 0.46))
    R = F * 0.40
    T = F * 0.07  # thickness
    GOLD, DARK, RIM, HI, EDGE = (255, 205, 40), (196, 120, 10), (230, 160, 20), (255, 244, 170), (150, 82, 8)
    for k in range(16):
        th = k / 16 * math.pi
        cw = abs(math.cos(th))
        sw = math.sin(th)
        fr = Image.new("RGBA", (F, F), (0, 0, 0, 0))
        d = ImageDraw.Draw(fr)
        cx, cy = F / 2, F / 2
        w = max(R * cw, 1.5 * SS)
        off = T * sw * (1 if math.cos(th) >= 0 else -1)
        # edge (the coin's thickness), drawn as a stack of ellipses
        steps = int(abs(off)) + 1
        for s in range(steps):
            o = off * s / max(1, steps - 1)
            d.ellipse([cx - w + o - off / 2, cy - R, cx + w + o - off / 2, cy + R], fill=EDGE)
        fx = cx + off / 2
        d.ellipse([fx - w, cy - R, fx + w, cy + R], fill=DARK)                  # outer rim (dark)
        d.ellipse([fx - w * 0.9, cy - R * 0.9, fx + w * 0.9, cy + R * 0.9], fill=RIM)
        d.ellipse([fx - w * 0.82, cy - R * 0.82, fx + w * 0.82, cy + R * 0.82], fill=GOLD)
        # highlight crescent (top-left), cel hard edge
        if cw > 0.2:
            d.chord([fx - w * 0.74, cy - R * 0.74, fx + w * 0.74, cy + R * 0.74], 190, 280, fill=HI)
            d.ellipse([fx - w * 0.66, cy - R * 0.66, fx + w * 0.74, cy + R * 0.76], fill=GOLD)
        # the yen glyph, squashed with the face
        if cw > 0.22:
            g = Image.new("RGBA", (F, F), (0, 0, 0, 0))
            gd = ImageDraw.Draw(g)
            bb = gd.textbbox((0, 0), "¥", font=font)
            gw, gh = bb[2] - bb[0], bb[3] - bb[1]
            gd.text((F / 2 - gw / 2 - bb[0], F / 2 - gh / 2 - bb[1]), "¥", font=font, fill=DARK)
            g = g.resize((max(1, int(F * cw)), F), Image.LANCZOS)
            fr.alpha_composite(g, (int(fx - g.width / 2), 0))
        sheet.alpha_composite(fr, ((k % 4) * F, (k // 4) * F))
    save(sheet.resize((512, 512), Image.LANCZOS), "coin_spin_4x4")


def edge_glow():
    """Screen-edge flash: transparent middle, white rim (superellipse), soft inner falloff."""
    N = 256
    y, x = np.mgrid[0:N, 0:N] / (N - 1) * 2 - 1
    r = (np.abs(x) ** 4 + np.abs(y) ** 4) ** 0.25
    a = np.clip((r - 0.62) / 0.38, 0, 1) ** 1.6
    rgb = np.full((N, N), 255, np.uint8)
    img = Image.merge("RGBA", [Image.fromarray(rgb)] * 3 + [Image.fromarray((a * 255).astype(np.uint8))])
    save(img, "edge_glow")


def aurora():
    """Beam strip (runs along WIDTH like the sim's beams): vertical curtain striations, tileable in U,
    fading at both long edges with a brighter lower hem."""
    W, H = 512, 128
    rng = np.random.default_rng(7)
    u = np.arange(W) / W
    stri = np.zeros(W)
    for f, amp in [(3, 0.5), (7, 0.3), (13, 0.25), (29, 0.15), (53, 0.1)]:
        stri += amp * np.sin(2 * math.pi * (f * u + rng.random()))
    stri = (stri - stri.min()) / (stri.max() - stri.min())
    v = np.arange(H)[:, None] / (H - 1)
    env = np.clip(np.sin(math.pi * v) ** 0.8, 0, 1) * (0.55 + 0.45 * v)  # brighter hem at v=1
    a = env * (0.35 + 0.65 * stri[None, :])
    a = np.clip(a, 0, 1)
    rgb = np.full((H, W), 255, np.uint8)
    img = Image.merge("RGBA", [Image.fromarray(rgb)] * 3 + [Image.fromarray((a * 255).astype(np.uint8))])
    save(img, "aurora_band")


def ribbon_solid():
    """Trail/Beam strip (runs along WIDTH like the sim's beams): a SOLID cel band, alpha 1 over the
    middle 86 % of the height with ~1 px edges, and a slightly lighter centre so a flat Color still
    shows a little volume. Used for the throw trails' core and dark edge copy (they must read on
    pale floors, where soft additive glow textures vanish)."""
    W, H = 256, 64
    v = (np.arange(H) + 0.5) / H
    d = np.abs(v - 0.5) * 2  # 0 centre .. 1 edge
    a = np.clip((0.86 - d) / 0.03, 0, 1)
    lum = np.where(d < 0.35, 1.0, 0.86)
    A = np.repeat(a[:, None], W, 1)
    L = np.repeat(lum[:, None], W, 1)
    rgb = (L * 255).astype(np.uint8)
    img = Image.merge("RGBA", [Image.fromarray(rgb)] * 3 + [Image.fromarray((A * 255).astype(np.uint8))])
    save(img, "ribbon_solid")


if __name__ == "__main__":
    ribbon_solid()
    clover()
    coin_spin()
    edge_glow()
    aurora()
