#!/usr/bin/env python3
"""AceEater (Don Lorenzo's aura) textures, made from maths: nothing harvested, nothing stock.

    python tools/auras/ace_eater/make_tex.py        -> assets/auras/ace_eater/*.png (+ _sheet.jpg)

The look (Blue Lock, Don Lorenzo, "the Ace Eater", the Zombie-step dribble, a player who prices everyone by their
transfer fee): acid lime and violet-black (undead), bone, and gold (his grill, his money).
  pitch_core / pitch_ink / pitch_glow   the ground: a football centre circle, halfway line and spot, a ring of gold
                                        coins etched with fee marks, an original Ace Eater crest (a fanged mouth with
                                        a gold grill biting a ball). White + alpha, tinted by the builder.
  coins_core / coins_ink / coins_glow   the coin ring alone (gold over ink, a layer of its own)
  hand_4x4.png    16 frames, pre-coloured: an undead hand claws up out of the ground, grabs, sinks back
  jaws_4x4.png    16 frames, pre-coloured: spectral jaws with a gold grill open wide and SNAP shut, then fade
  ball.png        a football (bone-white panels, black pentagons), pre-coloured, with a lime halo
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets" / "auras" / "ace_eater"
LIME = (182, 255, 64)
BONE = (226, 232, 206)
GOLD = (255, 208, 70)
VIOLET_BLACK = (22, 8, 30)


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


def jaw_shape(d: ImageDraw.ImageDraw, cx, cy, w, h, gap, fill_dark, teeth_fill, upper=True, n=7, grill=True, outline=0):
    """one jaw (upper or lower): a curved lip band with a row of sharp teeth pointing to the gap"""
    s = -1 if upper else 1
    # the lip: an arc band
    pts_outer, pts_inner = [], []
    for t in np.linspace(-1, 1, 40):
        x = cx + w * t
        y_inner = cy + s * (gap + h * 0.15 * (1 - t * t))
        y_outer = cy + s * (gap + h * (0.55 + 0.35 * (1 - t * t)))
        pts_inner.append((x, y_inner))
        pts_outer.append((x, y_outer))
    if outline:
        d.line(pts_inner + pts_outer[::-1] + [pts_inner[0]], fill=fill_dark, width=outline, joint="curve")
    else:
        d.polygon(pts_inner + pts_outer[::-1], fill=fill_dark)
    # teeth: triangles from the lip toward the gap, gold (the grill) in the middle, bone at the sides
    for i in range(n):
        t0 = -0.9 + 1.8 * i / n
        t1 = -0.9 + 1.8 * (i + 1) / n
        tm = (t0 + t1) / 2
        x0, x1, xm = cx + w * t0, cx + w * t1, cx + w * tm
        base = cy + s * (gap + h * 0.15 * (1 - tm * tm))
        tip = cy + s * (gap - h * (0.35 if abs(tm) < 0.5 else 0.25)) * 1.0
        col = teeth_fill(i, n) if grill else teeth_fill(0, 1)
        if outline:
            d.line([(x0, base), (xm, tip), (x1, base)], fill=col, width=outline, joint="curve")
        else:
            d.polygon([(x0, base), (x1, base), (xm, tip)], fill=col)


# ---------------------------------------------------------------- the ground
def pitch(size=1024):
    S = size * 2
    im = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(im)
    c = S / 2

    def R(f):
        return f * S / 2

    def W(f):
        return max(1, int(f * S / 2))

    # the centre circle, doubled, and the halfway line across it
    for rf, wf in ((0.70, 0.016), (0.655, 0.006)):
        d.ellipse([c - R(rf), c - R(rf), c + R(rf), c + R(rf)], outline=255, width=W(wf))
    d.line([(c - R(0.98), c), (c - R(0.70), c)], fill=255, width=W(0.016))
    d.line([(c + R(0.70), c), (c + R(0.98), c)], fill=255, width=W(0.016))
    # penalty-arc echoes either side, the outer boundary
    d.arc([c - R(0.98), c - R(0.98), c + R(0.98), c + R(0.98)], 0, 360, fill=255, width=W(0.010))
    for a0 in (60, 240):
        d.arc([c - R(0.86), c - R(0.86), c + R(0.86), c + R(0.86)], a0, a0 + 60, fill=255, width=W(0.008))
    # the crest: a fanged mouth biting a ball
    rr = R(0.22)
    d.ellipse([c - rr, c - rr, c + rr, c + rr], outline=255, width=W(0.012))
    for k in range(5):
        a = -math.pi / 2 + 2 * math.pi * k / 5
        px, py = c + rr * 0.55 * math.cos(a), c + rr * 0.55 * math.sin(a)
        q = rr * 0.2
        pts = [(px + q * math.cos(a + 2 * math.pi * j / 5), py + q * math.sin(a + 2 * math.pi * j / 5)) for j in range(5)]
        d.polygon(pts, fill=255)
    for up in (True, False):
        jaw_shape(d, c, c, R(0.34), R(0.2), R(0.20), 255, lambda i, n: 255, upper=up, n=6, grill=False, outline=W(0.012))
    return trio(im, size)


def coins(size=1024):
    S = size * 2
    im = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(im)
    c = S / 2
    n = 16
    for k in range(n):
        a = 2 * math.pi * (k + 0.5) / n
        x, y = c + S / 2 * 0.84 * math.cos(a), c + S / 2 * 0.84 * math.sin(a)
        r = S / 2 * 0.065
        d.ellipse([x - r, y - r, x + r, y + r], outline=255, width=max(2, int(S * 0.006)))
        r2 = r * 0.74
        d.ellipse([x - r2, y - r2, x + r2, y + r2], outline=255, width=max(1, int(S * 0.003)))
        # fee marks: a stroke and two bars (an original currency-like sign)
        d.line([(x, y - r2 * 0.75), (x, y + r2 * 0.75)], fill=255, width=max(2, int(S * 0.005)))
        for dy in (-0.22, 0.12):
            d.line([(x - r2 * 0.5, y + r2 * dy), (x + r2 * 0.5, y + r2 * dy)], fill=255, width=max(2, int(S * 0.004)))
    return trio(im, size)


# ---------------------------------------------------------------- the undead hand
def hand_frame(S, rise, curl, fade):
    """an undead hand and forearm clawing up out of cracked ground; rise 0..1, curl 0 (open) .. 1 (grabbing)"""
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    ground = S * 0.90
    cx = S * 0.48
    skin = (166, 182, 140, 255)
    shade = (112, 128, 96, 255)
    dark = (26, 22, 30, 255)
    rag = (48, 30, 58, 255)
    lw = max(3, int(S * 0.012))
    if rise > 0.03:
        top = ground - S * 0.74 * rise
        lean = S * 0.05
        # the forearm: tapered, leaning a little, wrist at `top + 0.22`
        wrist = (cx + lean, top + S * 0.24)
        fw0, fw1 = S * 0.085, S * 0.06
        arm = [(cx - fw0, ground), (cx + fw0, ground), (wrist[0] + fw1, wrist[1]), (wrist[0] - fw1, wrist[1])]
        d.polygon(arm, fill=skin, outline=dark)
        d.line(arm + [arm[0]], fill=dark, width=lw)
        # shading down one side, a torn sleeve near the ground
        d.polygon([(cx + fw0 * 0.25, ground), (cx + fw0, ground), (wrist[0] + fw1, wrist[1]), (wrist[0] + fw1 * 0.3, wrist[1])], fill=shade)
        sl = ground - S * 0.10
        rag_pts = [(cx - fw0 * 1.15, ground), (cx + fw0 * 1.15, ground), (cx + fw0 * 1.05, sl)]
        for k in range(6):
            t = 1 - k / 5
            rag_pts.append((cx - fw0 * 1.05 + 2 * fw0 * 1.05 * t, sl - (S * 0.035 if k % 2 else 0)))
        d.polygon(rag_pts, fill=rag)
        # the palm
        pw = S * 0.095
        palm_top = wrist[1] - S * 0.11
        palm = [(wrist[0] - fw1, wrist[1]), (wrist[0] + fw1, wrist[1]), (wrist[0] + pw, palm_top + S * 0.03),
                (wrist[0] + pw * 0.9, palm_top), (wrist[0] - pw * 0.9, palm_top), (wrist[0] - pw, palm_top + S * 0.03)]
        d.polygon(palm, fill=skin)
        d.line(palm + [palm[0]], fill=dark, width=lw)
        # four long fingers, two joints each, dark claws; they curl in as it grabs
        for i, off in enumerate((-0.78, -0.27, 0.25, 0.75)):
            base = (wrist[0] + pw * off, palm_top + S * 0.005)
            L = S * (0.17 if i in (1, 2) else 0.14)
            spread = off * 0.32
            bend = curl * (1.0 if off < 0 else -1.0)
            a1 = -math.pi / 2 + spread + bend * 0.45
            j1 = (base[0] + L * 0.55 * math.cos(a1), base[1] + L * 0.55 * math.sin(a1))
            a2 = a1 + bend * 1.0
            tip = (j1[0] + L * 0.45 * math.cos(a2), j1[1] + L * 0.45 * math.sin(a2))
            wd = max(3, int(S * 0.026))
            d.line([base, j1, tip], fill=dark, width=wd + lw, joint="curve")
            d.line([base, j1, tip], fill=skin, width=wd, joint="curve")
            d.ellipse([j1[0] - wd * 0.6, j1[1] - wd * 0.6, j1[0] + wd * 0.6, j1[1] + wd * 0.6], fill=shade)
            claw = (tip[0] + S * 0.035 * math.cos(a2), tip[1] + S * 0.035 * math.sin(a2))
            d.line([tip, claw], fill=dark, width=max(2, wd - 2))
        tb = (wrist[0] - pw, palm_top + S * 0.05)
        ta = math.pi * 1.15 - curl * 0.7
        tt = (tb[0] + S * 0.10 * math.cos(ta), tb[1] + S * 0.10 * math.sin(ta))
        d.line([tb, tt], fill=dark, width=int(S * 0.028) + lw)
        d.line([tb, tt], fill=skin, width=int(S * 0.028))
    # cracked ground: lime light leaking from jagged cracks round the arm (no hard black line)
    cr = Image.new("L", (S, S), 0)
    cd = ImageDraw.Draw(cr)
    spread = S * 0.30 * min(1.0, rise * 1.5 + 0.25)
    for k, (dx, dy) in enumerate(((-1, -0.10), (1, -0.05), (-0.6, 0.12), (0.7, 0.10))):
        pts = [(cx, ground)]
        for t in np.linspace(0.2, 1, 4):
            pts.append((cx + dx * spread * t, ground + dy * spread * t + (S * 0.012 if int(t * 10) % 2 else -S * 0.012)))
        cd.line(pts, fill=255, width=max(2, int(S * 0.012)))
    glow = cr.filter(ImageFilter.GaussianBlur(S * 0.02))
    g = np.clip(np.maximum(np.asarray(cr, float), np.asarray(glow, float) * 1.6) / 255, 0, 1)
    layer = np.zeros((S, S, 4))
    layer[..., 0], layer[..., 1], layer[..., 2] = LIME
    layer[..., 3] = g * 255
    out = Image.alpha_composite(Image.fromarray(layer.astype(np.uint8), "RGBA"), im)
    # a faint lime rim round the hand
    alpha = im.split()[3]
    rim = alpha.filter(ImageFilter.MaxFilter(7)).filter(ImageFilter.GaussianBlur(S * 0.01))
    rl = np.zeros((S, S, 4))
    rl[..., 0], rl[..., 1], rl[..., 2] = LIME
    rl[..., 3] = np.asarray(rim, float) * 0.6
    out = Image.alpha_composite(Image.fromarray(rl.astype(np.uint8), "RGBA"), out)
    a = np.asarray(out, float)
    a[..., 3] *= fade
    return Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA")


def hand_flipbook():
    F = 256
    S = F * 2
    sheet = Image.new("RGBA", (F * 4, F * 4), (0, 0, 0, 0))
    for f in range(16):
        t = f / 15
        rise = min(1.0, t / 0.35) if t < 0.7 else max(0.0, 1 - (t - 0.7) / 0.3)
        rise = 1 - (1 - rise) ** 2
        curl = 0.0 if t < 0.35 else min(1.0, (t - 0.35) / 0.25)
        fade = 1.0 if t < 0.85 else 1 - (t - 0.85) / 0.15
        im = hand_frame(S, rise, curl, fade)
        sheet.alpha_composite(im.resize((F, F), Image.LANCZOS), ((f % 4) * F, (f // 4) * F))
    return sheet


# ---------------------------------------------------------------- the jaws
def jaws_flipbook():
    F = 256
    S = F * 2
    sheet = Image.new("RGBA", (F * 4, F * 4), (0, 0, 0, 0))
    for f in range(16):
        t = f / 15
        # open wide (0-0.35), SNAP shut (0.35-0.45), hold, fade
        if t < 0.35:
            gap = 0.30 * (t / 0.35) ** 0.6
        elif t < 0.45:
            gap = 0.30 * (1 - (t - 0.35) / 0.10)
        else:
            gap = 0.0
        fade = 1.0 if t < 0.6 else max(0.0, 1 - (t - 0.6) / 0.4)
        grow = 0.7 + 0.3 * min(1.0, t / 0.2)
        im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        c = S / 2

        def teeth(i, n):
            mid = abs(i - (n - 1) / 2) <= 1.5
            return GOLD + (255,) if mid else BONE + (255,)

        for up in (True, False):
            jaw_shape(d, c, c, S * 0.40 * grow, S * 0.24 * grow, S * gap * 0.5 * grow, VIOLET_BLACK + (255,), teeth,
                      upper=up, n=9)
        # the snap flash
        if 0.4 <= t <= 0.55:
            k = 1 - abs(t - 0.45) / 0.1
            fl = Image.new("L", (S, S), 0)
            ImageDraw.Draw(fl).line([(c - S * 0.42, c), (c + S * 0.42, c)], fill=int(255 * k), width=int(S * 0.025))
            fl = fl.filter(ImageFilter.GaussianBlur(S * 0.01))
            fc = Image.new("RGBA", (S, S), LIME + (255,))
            im.paste(fc, (0, 0), fl)
        # a lime glow round the whole jaw
        alpha = im.split()[3]
        glow = alpha.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(S * 0.02))
        g = np.asarray(glow, float) * 0.55
        layer = np.zeros((S, S, 4))
        layer[..., 0], layer[..., 1], layer[..., 2] = LIME
        layer[..., 3] = g
        out = Image.alpha_composite(Image.fromarray(layer.astype(np.uint8), "RGBA"), im)
        a = np.asarray(out, float)
        a[..., 3] *= fade
        sheet.alpha_composite(Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA").resize((F, F), Image.LANCZOS),
                              ((f % 4) * F, (f // 4) * F))
    return sheet


def ball(size=256):
    S = size * 2
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = S / 2
    r = S * 0.34
    d.ellipse([c - r, c - r, c + r, c + r], fill=BONE + (255,), outline=(20, 20, 24, 255), width=int(S * 0.012))
    def pent(px, py, q, rot):
        return [(px + q * math.cos(rot + 2 * math.pi * j / 5), py + q * math.sin(rot + 2 * math.pi * j / 5)) for j in range(5)]
    d.polygon(pent(c, c, r * 0.30, -math.pi / 2), fill=(18, 18, 22, 255))
    for k in range(5):
        a = -math.pi / 2 + 2 * math.pi * k / 5
        px, py = c + r * 0.78 * math.cos(a), c + r * 0.78 * math.sin(a)
        d.polygon(pent(px, py, r * 0.22, a + math.pi / 2), fill=(18, 18, 22, 255))
        d.line([(c + r * 0.30 * math.cos(a), c + r * 0.30 * math.sin(a)), (px, py)], fill=(40, 40, 44, 255), width=int(S * 0.008))
    alpha = im.split()[3]
    glow = alpha.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(S * 0.05))
    layer = np.zeros((S, S, 4))
    layer[..., 0], layer[..., 1], layer[..., 2] = LIME
    layer[..., 3] = np.asarray(glow, float) * 0.9
    out = Image.alpha_composite(Image.fromarray(layer.astype(np.uint8), "RGBA"), im)
    return out.resize((size, size), Image.LANCZOS)


def contact_sheet(files):
    tiles = []
    for name, im in files.items():
        if name.endswith(("_ink.png", "_glow.png")):
            continue
        for bg in ((12, 10, 18), (255, 232, 40)):
            base = Image.new("RGBA", im.size, bg + (255,))
            if name == "pitch_core.png":
                for layer, col in (("pitch_glow.png", (120, 255, 60, 140)), ("pitch_ink.png", (22, 8, 30, 255))):
                    k = Image.new("RGBA", im.size, (0, 0, 0, 0))
                    k.paste(col, (0, 0), files[layer].split()[3])
                    base.alpha_composite(k)
                k = Image.new("RGBA", im.size, (0, 0, 0, 0))
                k.paste(LIME + (255,), (0, 0), im.split()[3])
                base.alpha_composite(k)
            elif name == "coins_core.png":
                k = Image.new("RGBA", im.size, (0, 0, 0, 0))
                k.paste(GOLD + (255,), (0, 0), im.split()[3])
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
    core, ink, glow = pitch()
    files.update({"pitch_core.png": core, "pitch_ink.png": ink, "pitch_glow.png": glow})
    core, ink, glow = coins()
    files.update({"coins_core.png": core, "coins_ink.png": ink, "coins_glow.png": glow})
    files["hand_4x4.png"] = hand_flipbook()
    files["jaws_4x4.png"] = jaws_flipbook()
    files["ball.png"] = ball()
    for name, im in files.items():
        im.save(OUT / name)
    contact_sheet(files).save(OUT / "_sheet.jpg", quality=88)
    print("wrote", len(files), "textures")


if __name__ == "__main__":
    main()
