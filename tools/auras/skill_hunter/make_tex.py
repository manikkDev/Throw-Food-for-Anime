#!/usr/bin/env python3
"""SkillHunter (Chrollo Lucilfer, "Spider Thief Boss", Legendary) aura textures, made from maths and system fonts.

    python tools/auras/skill_hunter/make_tex.py [names...]   -> assets/auras/skill_hunter/*.png (+ _sheet.jpg)

Reference (Hunter x Hunter): his Nen ability Skill Hunter, the book "Bandit's Secret" (盗賊の極意) that he holds
open in his right hand, a handprint on it, its pages the abilities he stole (Sun and Moon, Black Voice, the order
stamp...); the Phantom Troupe (幻影旅団), the Spiders, twelve members, their tattoo a twelve-legged spider; the
inverted cross on his coat; Nen seen with Gyo as a thin outline of aura.
Every texture is PRE-COLOURED (drawn with Color white unless the builder says otherwise).

  book.png            the open grimoire seen from the front: dark leather, gold edges and corner fittings, a crimson
                      handprint on the left page, glyph text and a seal on the right, a cold glow off the pages
  page_sun.png        a torn page: parchment, the crimson handprint, the Sun of "Sun and Moon"
  page_moon.png       ... the Moon
  page_antenna.png    ... Black Voice's antenna
  page_stamp.png      ... the order stamp's seal
  web.png             the Troupe web: 12 spokes (one per member), a spiral, dew drops glinting, silver with a glow
  sigil.png           ground seal: the twelve-legged spider, four inverted crosses, 幻影旅団 and 盗賊の極意
  nen_4x4.png         16-frame LOOP of thin Gyo aura lines wavering upward (cold white-blue)
  pulse_v.png         the web's spoke-beam tile, upright: one soft dash of cold light and a long gap
  mist.png            a soft charcoal mist puff
  mote.png            a cold white-blue mote
  glow.png            soft radial falloff
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets" / "auras" / "skill_hunter"
FONTS = Path("C:/Windows/Fonts")
JP_FONT = FONTS / "YuGothB.ttc"

OBSIDIAN = np.array([12, 11, 16], float)
LEATHER = np.array([34, 22, 26], float)
BONE = np.array([238, 232, 220], float)
PARCH = np.array([226, 214, 188], float)
SILVER = np.array([200, 210, 226], float)
CRIMSON = np.array([176, 22, 38], float)
GOLD = np.array([212, 168, 80], float)
NEN = np.array([196, 226, 255], float)
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


def coords(n):
    yy, xx = np.mgrid[0:n, 0:n].astype(float)
    return (xx + 0.5) / n * 2 - 1, (yy + 0.5) / n * 2 - 1


def grid(frames, n):
    f = frames[0].size[0]
    s = Image.new("RGBA", (f * n, f * n), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        s.paste(fr, ((i % n) * f, (i // n) * f))
    return s


def rgba_t(c, a=255):
    return tuple(int(v) for v in c) + (a,)


# ------------------------------------------------------------------ drawing helpers
def hand(d, cx, cy, s, fill):
    """A right handprint (palm up), centre (cx, cy), scale s (palm width)."""
    pw, ph = s, s * 1.05
    d.rounded_rectangle([cx - pw / 2, cy - ph / 2, cx + pw / 2, cy + ph / 2], radius=s * 0.32, fill=fill)
    fingers = [(-0.36, 0.95, 0.2), (-0.12, 1.12, 0.21), (0.12, 1.08, 0.21), (0.35, 0.88, 0.19)]
    for fx, fl, fw in fingers:
        x0 = cx + fx * pw - fw * s / 2
        d.rounded_rectangle([x0, cy - ph / 2 - fl * s * 0.62, x0 + fw * s, cy - ph / 2 + s * 0.12], radius=fw * s / 2, fill=fill)
    # thumb, angled out to the left
    th = Image.new("L", d.im.size, 0)
    tw = int(s * 0.24)
    poly = [(cx - pw / 2 + s * 0.05, cy + ph * 0.1), (cx - pw / 2 - s * 0.38, cy - ph * 0.28),
            (cx - pw / 2 - s * 0.24, cy - ph * 0.42), (cx - pw / 2 + s * 0.12, cy - ph * 0.12)]
    d.polygon(poly, fill=fill)
    d.ellipse([poly[1][0] - tw / 2, poly[1][1] - tw / 2 - s * 0.05, poly[1][0] + tw / 2 + s * 0.08, poly[1][1] + tw / 2 - s * 0.05], fill=fill)


def spider(d, cx, cy, s, body, outline, ow):
    """The Troupe's twelve-legged spider seen from above, head UP (toward -y). s = abdomen radius.
    (v1 swept every foot downward: it looked lopsided and as if it faced away.) Each side has six legs fanned from
    forward to backward like a real spider's: the front pairs reach ahead and bend out, the back pairs trail."""
    hx, hy = cx, cy - s * 0.55  # the cephalothorax centre: the legs root here
    for side in (-1, 1):
        for i in range(6):
            th = math.radians(24 + i * 26.4)  # from the head direction: 24 .. 156 degrees
            dx, dy = side * math.sin(th), -math.cos(th)
            root = (hx + side * s * 0.28, hy + (i - 2.5) * s * 0.1)
            knee = (root[0] + dx * s * 0.95 + side * s * 0.25, root[1] + dy * s * 0.95 - s * 0.3)
            # the lower leg turns further from the body axis and toward the ground of the drawing's "outside"
            bend = math.radians(18 if i < 3 else -18)
            fx = dx * math.cos(bend) - dy * math.sin(bend) * side
            fy = dx * math.sin(bend) * side + dy * math.cos(bend)
            foot = (knee[0] + fx * s * 1.0, knee[1] + fy * s * 1.0 + s * 0.15)
            d.line([root, knee, foot], fill=outline, width=int(ow * 4.4), joint="curve")
            d.line([root, knee, foot], fill=body, width=int(ow * 2.8), joint="curve")
    d.ellipse([cx - s * 0.62 - ow, cy - s * 0.25 - ow, cx + s * 0.62 + ow, cy + s * 1.05 + ow], fill=outline)
    d.ellipse([cx - s * 0.62, cy - s * 0.25, cx + s * 0.62, cy + s * 1.05], fill=body)
    d.ellipse([hx - s * 0.36 - ow, hy - s * 0.4 - ow, hx + s * 0.36 + ow, hy + s * 0.35 + ow], fill=outline)
    d.ellipse([hx - s * 0.36, hy - s * 0.4, hx + s * 0.36, hy + s * 0.35], fill=body)
    # two small fangs at the front
    for side in (-1, 1):
        d.line([(hx + side * s * 0.12, hy - s * 0.36), (hx + side * s * 0.18, hy - s * 0.58)], fill=outline, width=int(ow * 2.2))


def inv_cross(d, cx, cy, s, fill):
    """An inverted cross: long arm up, the crossbar low."""
    w = s * 0.2
    d.rectangle([cx - w / 2, cy - s, cx + w / 2, cy + s], fill=fill)
    d.rectangle([cx - s * 0.45, cy + s * 0.25 - w / 2, cx + s * 0.45, cy + s * 0.25 + w / 2], fill=fill)


def glyph_lines(d, x0, y0, x1, y1, rng, colour, k, rows=11):
    """Lines of an unknown script: short strokes, dots and hooks."""
    lh = (y1 - y0) / rows
    for r in range(rows):
        y = y0 + r * lh + lh * 0.5
        x = x0
        while x < x1 - 6 * k:
            w = rng.uniform(3, 9) * k
            kind = rng.integers(0, 4)
            if kind == 0:
                d.line([(x, y), (x + w, y)], fill=colour, width=2 * k)
            elif kind == 1:
                d.line([(x, y - lh * 0.25), (x + w * 0.5, y + lh * 0.2), (x + w, y - lh * 0.2)], fill=colour, width=2 * k)
            elif kind == 2:
                d.ellipse([x, y - 2 * k, x + 4 * k, y + 2 * k], fill=colour)
            else:
                d.line([(x, y + lh * 0.2), (x, y - lh * 0.25), (x + w * 0.7, y - lh * 0.25)], fill=colour, width=2 * k)
            x += w + rng.uniform(2, 6) * k


# ------------------------------------------------------------------ the grimoire
def book(N=512):
    k = 3
    S = N * k
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = S / 2, S * 0.54
    bw, bh = S * 0.86, S * 0.56  # the open cover
    # cover (leather) with a slight V at the spine
    cov = [(cx - bw / 2, cy - bh / 2 + 10 * k), (cx, cy - bh / 2 + 22 * k), (cx + bw / 2, cy - bh / 2 + 10 * k),
           (cx + bw / 2, cy + bh / 2), (cx, cy + bh / 2 + 14 * k), (cx - bw / 2, cy + bh / 2)]
    d.polygon(cov, fill=rgba_t(LEATHER))
    # gold corner fittings
    for sx in (-1, 1):
        for sy in (-1, 1):
            x = cx + sx * bw / 2
            y = cy + sy * bh / 2 + (10 * k if sy < 0 else 0)
            d.polygon([(x, y), (x - sx * 46 * k, y), (x, y - sy * 46 * k)], fill=rgba_t(GOLD))
    # pages: two blocks, page-edge stripes below
    pw, ph = bw * 0.46, bh * 0.86
    for side in (-1, 1):
        x0 = cx if side > 0 else cx - pw
        x1 = cx + pw if side > 0 else cx
        top = cy - ph / 2 + 18 * k
        for e in range(5):
            d.line([(x0 + 6 * k, top + ph + e * 3 * k), (x1 - 6 * k, top + ph + e * 3 * k)], fill=rgba_t(PARCH * (0.8 - 0.05 * e)), width=k)
        d.polygon([(x0, top), (x1, top), (x1, top + ph), (x0, top + ph)], fill=rgba_t(PARCH))
    arr = np.asarray(img, float).copy()
    # page shading: darker toward the spine (the pages curve into it)
    x, y = coords(S)
    spine = np.exp(-((x / 0.09) ** 2))
    pagemask = (np.abs(arr[..., :3] - PARCH).sum(2) < 30) & (arr[..., 3] > 0)
    arr[..., :3] = np.where(pagemask[..., None], arr[..., :3] * (1 - 0.35 * spine[..., None]), arr[..., :3])
    img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")
    d = ImageDraw.Draw(img)
    # the handprint (left page) in crimson, a thin ring round it
    lx = cx - pw / 2
    hand(d, lx, cy + 6 * k, pw * 0.34, rgba_t(CRIMSON))
    d.ellipse([lx - pw * 0.42, cy - pw * 0.42 + 6 * k, lx + pw * 0.42, cy + pw * 0.42 + 6 * k], outline=rgba_t(CRIMSON, 200), width=3 * k)
    # the right page: glyph text and a small seal
    rng = np.random.default_rng(4)
    rx0, rx1 = cx + 18 * k, cx + pw - 16 * k
    glyph_lines(d, rx0, cy - ph / 2 + 36 * k, rx1, cy + ph * 0.18, rng, (60, 40, 40, 255), k, rows=9)
    sx_, sy_ = (rx0 + rx1) / 2, cy + ph * 0.3
    d.ellipse([sx_ - 28 * k, sy_ - 28 * k, sx_ + 28 * k, sy_ + 28 * k], outline=(60, 40, 40, 255), width=3 * k)
    inv_cross(d, sx_, sy_, 18 * k, (60, 40, 40, 255))
    arr = down(np.asarray(img, float), k)
    # a cold glow lifting off the pages
    x, y = coords(N)
    pages = np.clip(arr[..., 3] / 255 * (arr[..., :3].mean(2) > 150), 0, 1)
    glow = ndimage.gaussian_filter(pages, 14) * 1.3
    up = smooth(0.4, -0.6, y)  # stronger above the book
    halo = layer(np.clip(glow * (0.6 + 0.8 * up), 0, 0.85), NEN)
    return to_img(over(halo, arr))


def page(icon, seed, N=256):
    """A torn page: parchment with a ragged edge and foxing, the crimson handprint, an ability's mark in ink."""
    k = 3
    S = N * k
    x, y = coords(S)
    rng = np.random.default_rng(seed)
    # a slightly skewed rectangle with a torn top edge
    w, h = 0.56, 0.74
    torn = 0.05 * field((1, S), 6 * k, seed=seed)[0][None, :] + 0.03 * np.sin(x * 40 + seed)
    m = (np.abs(x + y * 0.06) < w) & (y < h) & (y > -h + torn)
    col = lerp(np.broadcast_to(PARCH, (S, S, 3)), np.array([170, 140, 100.0]), np.clip(field((S, S), 18 * k, seed=seed + 1) * 0.5 + 0.1, 0, 1))
    edge = ndimage.distance_transform_edt(m) / S
    col = lerp(col, np.array([120, 90, 60.0]), 1 - smooth(0.0, 0.035, edge))
    arr = np.concatenate([col, (m * 255.0)[..., None]], axis=2)
    img = to_img(arr)
    d = ImageDraw.Draw(img)
    c = S / 2
    hand(d, c - S * 0.12, c + S * 0.18, S * 0.16, rgba_t(CRIMSON, 235))
    ink = (40, 28, 30, 255)
    ix, iy, r = c + S * 0.12, c - S * 0.16, S * 0.12
    if icon == "sun":
        d.ellipse([ix - r * 0.55, iy - r * 0.55, ix + r * 0.55, iy + r * 0.55], outline=ink, width=4 * k)
        for a in range(12):
            aa = a * math.pi / 6
            d.line([(ix + math.cos(aa) * r * 0.75, iy + math.sin(aa) * r * 0.75), (ix + math.cos(aa) * r * 1.05, iy + math.sin(aa) * r * 1.05)], fill=ink, width=4 * k)
    elif icon == "moon":
        d.ellipse([ix - r, iy - r, ix + r, iy + r], fill=ink)
        d.ellipse([ix - r * 0.55, iy - r * 1.05, ix + r * 1.25, iy + r * 0.75], fill=(0, 0, 0, 0))
        img2 = Image.new("RGBA", img.size, (0, 0, 0, 0))
        d2 = ImageDraw.Draw(img2)
        d2.ellipse([ix - r, iy - r, ix + r, iy + r], fill=ink)
        d2.ellipse([ix - r * 0.55, iy - r * 1.05, ix + r * 1.25, iy + r * 0.75], fill=(0, 0, 0, 0))
        # (crescent: draw the dark disc, then repaint the bite with parchment)
        d.ellipse([ix - r * 0.55, iy - r * 1.05, ix + r * 1.25, iy + r * 0.75], fill=rgba_t(PARCH))
    elif icon == "antenna":
        d.line([(ix, iy + r), (ix, iy - r)], fill=ink, width=5 * k)
        d.ellipse([ix - r * 0.22, iy - r * 1.25, ix + r * 0.22, iy - r * 0.8], fill=ink)
        for rr in (0.5, 0.8):
            d.arc([ix - r * rr * 1.6, iy - r * rr * 1.6 - r, ix + r * rr * 1.6, iy + r * rr * 1.6 - r], 200, 340, fill=ink, width=3 * k)
    else:  # stamp
        d.rectangle([ix - r * 0.7, iy - r * 0.7, ix + r * 0.7, iy + r * 0.7], outline=ink, width=5 * k)
        inv_cross(d, ix, iy, r * 0.5, ink)
    # (v1 wrote these below the page, floating in the air)
    glyph_lines(d, c - S * 0.24, c - S * 0.27, c - S * 0.02, c - S * 0.02, rng, (70, 50, 50, 230), k, rows=5)
    arr = down(np.asarray(img, float), k)
    arr[..., 3] = np.where(arr[..., 3] > 0, arr[..., 3] * 0.96, 0)
    # a faint cold rim (it glows, it is Nen)
    a = arr[..., 3] / 255
    rim = np.clip(ndimage.gaussian_filter(a, 4) - a * 0.9, 0, 1) * 1.6
    return to_img(over(layer(rim, NEN), arr))


# ------------------------------------------------------------------ the web
def web(N=1024):
    """Twelve spokes (one per Troupe member) and a spiral, silver threads with a glow, dew drops that glint."""
    k = 2
    S = N * k
    c = S / 2
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    R = S * 0.48
    r0 = S * 0.14  # the hub is empty (his body hides it)
    spokes = [-math.pi / 2 + i * 2 * math.pi / 12 + 0.04 * math.sin(i * 2.3) for i in range(12)]
    for a in spokes:
        d.line([(c + r0 * math.cos(a), c + r0 * math.sin(a)), (c + R * math.cos(a), c + R * math.sin(a))],
               fill=(232, 238, 250, 255), width=5 * k)
    # spiral: straight segments between spokes, sagging a little toward the hub
    turns = 9
    pts_all = []
    for t in range(turns * 12 + 1):
        i = t % 12
        frac = t / (turns * 12)
        rr = r0 * 1.2 + (R * 0.97 - r0 * 1.2) * frac
        pts_all.append((rr, spokes[i] + (2 * math.pi if i < (t // 12) * 0 else 0)))
    prev = None
    for t, (rr, a) in enumerate(pts_all):
        p = (c + rr * math.cos(a), c + rr * math.sin(a))
        if prev is not None:
            mid = ((prev[0] + p[0]) / 2, (prev[1] + p[1]) / 2)
            sag = 0.06
            mid = (c + (mid[0] - c) * (1 - sag), c + (mid[1] - c) * (1 - sag))
            d.line([prev, mid, p], fill=(220, 228, 242, 235), width=3 * k, joint="curve")
        prev = p
    arr = np.asarray(img, float)
    x, y = coords(S)
    r = np.hypot(x, y)
    threads = arr[..., 3] / 255
    glow = np.clip(ndimage.gaussian_filter(threads, 6 * k) * 2.2, 0, 1)
    out = layer(glow * 0.75 * smooth(0.98, 0.9, r), np.array([150, 170, 230.0]))
    out = over(out, arr)
    # dew: small bright drops on the threads, some with a cross glint
    rng = np.random.default_rng(31)
    ys, xs = np.where(threads > 0.8)
    pick = rng.choice(len(xs), size=60, replace=False)
    dew = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dd = ImageDraw.Draw(dew)
    for j, i in enumerate(pick):
        rr = rng.uniform(4, 8) * k
        dd.ellipse([xs[i] - rr, ys[i] - rr, xs[i] + rr, ys[i] + rr], fill=(255, 255, 255, 255))
        if j % 4 == 0:
            L = rr * 5
            dd.line([(xs[i] - L, ys[i]), (xs[i] + L, ys[i])], fill=(230, 240, 255, 200), width=k)
            dd.line([(xs[i], ys[i] - L), (xs[i], ys[i] + L)], fill=(230, 240, 255, 200), width=k)
    dew_a = np.asarray(dew, float)
    out = over(out, layer(np.clip(ndimage.gaussian_filter(dew_a[..., 3] / 255, 3 * k) * 2, 0, 1) * 0.8, NEN))
    out = over(out, dew_a)
    return to_img(down(out, k))


# ------------------------------------------------------------------ ground seal
def sigil(N=1024):
    k = 2
    S = N * k
    c = S / 2
    x, y = coords(S)
    r = np.hypot(x, y)
    out = layer((r < 0.86) * 0.88, OBSIDIAN)
    out = over(out, layer(np.exp(-((r / 0.55) ** 2)) * 0.5 * (r < 0.86), np.array([60, 20, 30.0])))
    for rr, w, colr in ((0.86, 0.006, SILVER), (0.71, 0.004, SILVER), (0.68, 0.003, CRIMSON), (0.97, 0.004, SILVER)):
        out = over(out, layer(np.exp(-(((r - rr) / w) ** 2)), colr))
    band = (r > 0.86) & (r < 0.97)
    out = over(out, layer(band * 0.85, OBSIDIAN))
    img = to_img(out)
    d = ImageDraw.Draw(img)
    # the spider
    spider(d, c, c - S * 0.04, S * 0.12, (20, 16, 22, 255), (226, 230, 240, 255), 4 * k)
    # four inverted crosses at the compass points, inside the inner ring
    for i in range(4):
        a = -math.pi / 2 + i * math.pi / 2 + math.pi / 4
        inv_cross(d, c + S * 0.29 * math.cos(a), c + S * 0.29 * math.sin(a), S * 0.04, rgba_t(CRIMSON))
    # lettering round the band
    f = ImageFont.truetype(str(JP_FONT), int(S * 0.04))
    seq = list("幻影旅団・盗賊の極意・") * 2
    rt = S / 2 * 0.915
    for i, ch in enumerate(seq):
        a = -math.pi / 2 + i * 2 * math.pi / len(seq)
        g = Image.new("RGBA", (int(S * 0.07), int(S * 0.07)), (0, 0, 0, 0))
        col = (236, 232, 224, 255) if ch != "・" else (190, 30, 45, 255)
        ImageDraw.Draw(g).text((g.size[0] / 2, g.size[1] / 2), ch, font=f, fill=col, anchor="mm")
        g = g.rotate(-math.degrees(a) - 90, resample=Image.BICUBIC)
        X, Y = c + rt * math.cos(a), c + rt * math.sin(a)
        img.alpha_composite(g, (int(X - g.size[0] / 2), int(Y - g.size[1] / 2)))
    # twelve thin spokes between the rings (the web again)
    for i in range(12):
        a = -math.pi / 2 + i * math.pi / 6
        d.line([(c + S * 0.355 * math.cos(a), c + S * 0.355 * math.sin(a)), (c + S * 0.425 * math.cos(a), c + S * 0.425 * math.sin(a))], fill=(200, 210, 226, 200), width=2 * k)
    return to_img(down(np.asarray(img, float), k))


# ------------------------------------------------------------------ Gyo aura lines, mist, motes
def nen():
    F = 256
    k = 2
    N = F * k
    x, y = coords(N)
    frames = []
    base = field((N * 2, N), (10 * k, 3 * k), seed=61)
    for i in range(16):
        off = int(i * N / 16)
        n = base[off: off + N]
        lines = np.zeros((N, N))
        for j, x0 in enumerate((-0.45, -0.15, 0.12, 0.4)):
            wav = x0 + 0.06 * np.sin(y * 7 + i * 0.39 * 2 + j) + 0.05 * n
            env = smooth(1.0, 0.6, y) * smooth(-1.0, -0.2, y) * (0.6 + 0.4 * math.sin(j * 1.7 + i * 0.39))
            lines = np.maximum(lines, np.exp(-(((x - wav) / 0.018) ** 2)) * env)
        glow = np.clip(ndimage.gaussian_filter(lines, 4 * k) * 2.5, 0, 1)
        out = over(layer(glow * 0.6, np.array([120, 160, 230.0])), layer(lines, NEN))
        frames.append(to_img(down(out, k)))
    return grid(frames, 4)


def pulse_v(W=64, H=256):
    """A tile for the web's spoke beams, UPRIGHT (a Beam lays the texture's vertical axis along itself): one soft
    dash of cold Nen light (white core, blue edge) and a long dark gap, so pulses run out along the threads."""
    y = np.linspace(-1, 1, H)[:, None]
    x = np.linspace(-1, 1, W)[None, :]
    along = np.exp(-((y + 0.35) / 0.16) ** 2)  # the dash sits in the upper part of the tile
    core = np.exp(-(x / 0.18) ** 2) * along
    glow = np.exp(-(x / 0.55) ** 2) * along * 0.6
    a = np.clip(core + glow, 0, 1)
    col = lerp(np.broadcast_to(NEN, a.shape + (3,)), WHITE, np.clip(core * 1.3, 0, 1))
    return to_img(np.concatenate([col, (a * 255)[..., None]], axis=2))


def mist(N=256):
    x, y = coords(N)
    r = np.hypot(x, y)
    n = field((N, N), 10, seed=71) * 0.5 + field((N, N), 4, seed=72) * 0.5
    a = np.clip((1 - r) * 1.4 + n * 0.5 - 0.3, 0, 1) ** 1.5
    col = lerp(np.broadcast_to(np.array([40, 38, 46.0]), (N, N, 3)), np.array([90, 88, 100.0]), np.clip(n + 0.5, 0, 1))
    return to_img(np.concatenate([col, (a * 220)[..., None]], axis=2))


def mote(N=128):
    x, y = coords(N)
    r = np.hypot(x, y)
    a = np.clip(np.exp(-((r / 0.16) ** 2)) + 0.4 * np.exp(-((r / 0.5) ** 2)), 0, 1)
    return to_img(np.concatenate([lerp(np.broadcast_to(WHITE, (N, N, 3)), NEN, smooth(0.1, 0.5, r)), (a * 255)[..., None]], axis=2))


def glow(N=256):
    x, y = coords(N)
    r = np.hypot(x, y)
    return to_img(layer(np.clip(1 - r, 0, 1) ** 2.2, WHITE))


def contact(imgs):
    cell = 300
    names = list(imgs)
    cols = 6
    rows = math.ceil(len(names) / cols)
    sheet = Image.new("RGB", (cell * cols, cell * rows * 2), (0, 0, 0))
    d = ImageDraw.Draw(sheet)
    for half, bg in enumerate(((14, 12, 20), (196, 210, 225))):
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
        "book": book,
        "page_sun": lambda: page("sun", 1),
        "page_moon": lambda: page("moon", 2),
        "page_antenna": lambda: page("antenna", 3),
        "page_stamp": lambda: page("stamp", 4),
        "web": web,
        "sigil": sigil,
        "nen_4x4": nen,
        "pulse_v": pulse_v,
        "mist": mist,
        "mote": mote,
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
