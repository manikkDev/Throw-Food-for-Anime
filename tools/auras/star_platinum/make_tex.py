#!/usr/bin/env python3
"""StarPlatinum (Jotaro Kujo, "Star Delinquent") aura textures, made from maths and system fonts: nothing harvested.

    python tools/auras/star_platinum/make_tex.py      -> assets/auras/star_platinum/*.png (+ _sheet.jpg)

Reference (Stardust Crusaders, the anime; the owner wants no stand, so no stand aura): the "menacing" katakana ゴゴゴ hang beside them in thick magenta letters
with a black outline and a 3D extrusion, trembling; the barrage lands as white impact flashes ("ORA ORA");
the Joestar star is the family mark; Star Platinum: The World stops time with an inverting sphere wave.
Every texture is PRE-COLOURED (drawn with Color white, unless the builder says otherwise).

  go_2x2.png          the menacing ゴ, 4 trembling frames (Grid2x2, Loop): magenta face, white bevel, black
                      outline, deep violet extrusion, slanted like the manga's lettering
  ora.png             "オラ" shout lettering: white-gold face, violet outline and extrusion
  impact_4x4.png      16-frame ONE-SHOT punch impact: a white star flash, a cyan ring and speed lines bursting out
  star.png            the Joestar star: bevelled gold five-point star with a white-hot middle and a halo
  comet_v.png         STARDUST ORBITS beam tile, UPRIGHT (1:6, head at the top; a Beam lays a texture's vertical
                      axis along itself): a gold Joestar star trailing a white-gold > pink > violet tail
  emblem.png          JOESTAR EMBLEM crest: gold star outline in a gold ring, violet-pink rays, tip sparkles
  twinkle.png         four-point stardust sparkle (white, tinted by Color)
  pulse.png           time-stop sphere wave: a bright rim with inverted green/magenta fringes, faint inside
  sigil.png           ground plate: Star Platinum's stand-stat hexagon (A A C A A A) round the star
  clockring.png       ground ring: clock ticks, a star at every hour, "STAR PLATINUM * THE WORLD" round it
  glow.png            soft radial falloff
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets" / "auras" / "star_platinum"
FONTS = Path("C:/Windows/Fonts")
JP_FONT = FONTS / "YuGothB.ttc"
LATIN_FONT = FONTS / "ariblk.ttf"

# palette (Stardust Crusaders' Star Platinum: violet skin, cyan rim light, gold; the menacing magenta)
VIOLET = np.array([122, 76, 255], float)
DEEP_VIOLET = np.array([58, 26, 150], float)
CYAN_WHITE = np.array([226, 250, 255], float)
CYAN = np.array([110, 220, 255], float)
MAGENTA_TOP = np.array([255, 112, 226], float)
MAGENTA_BOT = np.array([156, 40, 230], float)
EXTRUDE = np.array([52, 10, 92], float)
INK = np.array([14, 6, 24], float)
GOLD = np.array([255, 205, 60], float)
GOLD_DARK = np.array([214, 128, 18], float)


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def disk(r):
    y, x = np.ogrid[-r : r + 1, -r : r + 1]
    return x * x + y * y <= r * r


def field(shape, scale, seed, wrap=True):
    rng = np.random.default_rng(seed)
    f = ndimage.gaussian_filter(rng.standard_normal(shape), scale, mode="wrap" if wrap else "reflect")
    return f / (np.abs(f).max() + 1e-9)


def down(rgba, k):
    """Box-downsample a float RGBA by k with premultiplied alpha (clean edges)."""
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
    """Alpha-composite float RGBA src over dst (both 0..255)."""
    sa = src[..., 3:4] / 255.0
    da = dst[..., 3:4] / 255.0
    oa = sa + da * (1 - sa)
    col = np.where(oa > 1e-5, (src[..., :3] * sa + dst[..., :3] * da * (1 - sa)) / np.maximum(oa, 1e-5), 0)
    return np.concatenate([col, oa * 255], axis=2)


def layer(mask, colour):
    """A solid-colour RGBA layer from a 0..1 mask; colour is RGB or an HxWx3 array."""
    c = np.broadcast_to(np.asarray(colour, float), mask.shape + (3,))
    return np.concatenate([c, (np.clip(mask, 0, 1) * 255)[..., None]], axis=2)


def grid(frames, n):
    f = frames[0].size[0]
    s = Image.new("RGBA", (f * n, f * n), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        s.paste(fr, ((i % n) * f, (i // n) * f))
    return s


# ------------------------------------------------------------------ shout lettering (ゴ, オラ)
def glyph_mask(text, size, canvas, font=JP_FONT, spacing=0.0):
    """White-on-black text mask (float 0..1) centred on a canvas."""
    img = Image.new("L", (canvas, canvas), 0)
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(str(font), size)
    if spacing == 0.0:
        bb = d.textbbox((0, 0), text, font=f)
        d.text(((canvas - (bb[2] - bb[0])) / 2 - bb[0], (canvas - (bb[3] - bb[1])) / 2 - bb[1]), text, font=f, fill=255)
    else:
        widths = [d.textbbox((0, 0), ch, font=f) for ch in text]
        total = sum(b[2] - b[0] for b in widths) + spacing * (len(text) - 1)
        x = (canvas - total) / 2
        hb = d.textbbox((0, 0), text, font=f)
        y = (canvas - (hb[3] - hb[1])) / 2 - hb[1]
        for ch, b in zip(text, widths):
            d.text((x - b[0], y), ch, font=f, fill=255)
            x += (b[2] - b[0]) + spacing
    return np.asarray(img, float) / 255.0


def affine(mask, shear=0.0, rot_deg=0.0, scale=1.0, dx=0.0, dy=0.0):
    """Shear (italic slant), rotate and scale a mask about its centre."""
    h, w = mask.shape
    c = np.array([h / 2, w / 2])
    a = math.radians(rot_deg)
    # output (y, x) -> input: inverse of R * S * Shear
    rot = np.array([[math.cos(a), -math.sin(a)], [math.sin(a), math.cos(a)]])
    sh = np.array([[1, 0], [-shear, 1]])  # x' = x + shear * (h/2 - y): top leans right
    m = np.linalg.inv(rot @ sh * scale)
    off = c - m @ (c + np.array([dy, dx]))
    return ndimage.affine_transform(mask, m, offset=off, order=1, mode="constant")


def shout(mask, k, face_top, face_bot, bevel, extrude_col, outline_col, ext_px, outline_px, thick_px):
    """Manga SFX lettering from a raw glyph mask at supersample k: thickened face, vertical gradient,
    a bevel highlight on the upper-left edges, a 3D extrusion down-right, a heavy outline round it all."""
    face = ndimage.binary_dilation(mask > 0.5, structure=disk(thick_px))
    h, w = face.shape
    # extrusion: the face pushed down-right step by step
    ext = np.zeros_like(face)
    for s in range(1, ext_px + 1, 2):
        ext |= np.roll(np.roll(face, s, axis=0), int(s * 0.75), axis=1)
    ext &= ~face
    body = face | ext
    outline = ndimage.binary_dilation(body, structure=disk(outline_px)) & ~body
    ys = np.linspace(0, 1, h)[:, None]
    rows = np.where(face.any(axis=1))[0]
    y0, y1 = (rows.min() / h, rows.max() / h) if len(rows) else (0, 1)
    t = np.clip((ys - y0) / max(y1 - y0, 1e-3), 0, 1)
    grad = face_top[None, None, :] * (1 - t[..., None]) + face_bot[None, None, :] * t[..., None]
    grad = np.broadcast_to(grad, (h, w, 3))
    # bevel: face pixels whose up-left neighbour (a few px away) is outside
    off = max(2, int(thick_px * 0.55))
    lit = face & ~np.roll(np.roll(face, off, axis=0), off, axis=1)
    shade = face & ~np.roll(np.roll(face, -off, axis=0), -off, axis=1)
    # extrusion shading: darker the further from the face
    dist = ndimage.distance_transform_edt(~face)
    et = np.clip(dist / (ext_px * 1.1), 0, 1)[..., None]
    ext_rgb = extrude_col[None, None, :] * (1.15 - 0.55 * et)
    out = np.zeros((h, w, 4))
    out = over(out, layer(outline.astype(float), outline_col))
    out = over(out, layer(ext.astype(float), ext_rgb))
    out = over(out, layer(face.astype(float), grad))
    out = over(out, layer(shade.astype(float) * 0.55, face_bot * 0.55))
    out = over(out, layer(lit.astype(float) * 0.95, bevel))
    return out


def go_flipbook():
    """The menacing ゴ: 4 trembling frames (Grid2x2, 512 px frames)."""
    k = 2
    S = 512 * k
    raw = glyph_mask("ゴ", int(S * 0.66), S)
    frames = []
    jit = [(0, 0, 0.0, 1.0), (7, -5, 2.2, 1.03), (-6, 4, -1.6, 0.985), (4, 7, 1.0, 1.015)]
    for dx, dy, rot, sc in jit:
        m = affine(raw, shear=0.2, rot_deg=-6 + rot, scale=0.92 * sc, dx=dx * k - 18 * k, dy=dy * k - 14 * k)
        rgba = shout(m, k, MAGENTA_TOP, MAGENTA_BOT, np.array([255, 225, 250.0]), EXTRUDE, INK,
                     ext_px=26 * k, outline_px=9 * k, thick_px=9 * k)
        frames.append(to_img(down(rgba, k)))
    return grid(frames, 2)


def ora():
    k = 2
    S = 512 * k
    raw = glyph_mask("オラ", int(S * 0.42), S, spacing=-S * 0.02)
    m = affine(raw, shear=0.22, rot_deg=-8, scale=0.98, dx=-10 * k, dy=-10 * k)
    rgba = shout(m, k, np.array([255, 255, 255.0]), np.array([255, 214, 70.0]), np.array([255, 255, 255.0]),
                 DEEP_VIOLET, INK, ext_px=20 * k, outline_px=8 * k, thick_px=7 * k)
    return to_img(down(rgba, k))


# ------------------------------------------------------------------ stand aura flames
# ------------------------------------------------------------------ punch impact (ORA barrage)
def impact():
    F = 256
    c = F / 2
    yy, xx = np.mgrid[0:F, 0:F].astype(float)
    r = np.hypot(xx - c, yy - c) / c
    th = np.arctan2(yy - c, xx - c)
    rng = np.random.default_rng(77)
    angles = rng.uniform(0, 2 * math.pi, 28)
    lens = rng.uniform(0.55, 1.0, 28)
    frames = []
    for i in range(16):
        t = i / 15
        e = 1 - (1 - t) ** 2.2  # ease out
        fade = 1 - smooth(0.45, 1.0, t)
        out = np.zeros((F, F, 4))
        # speed lines: thin wedges flying outward
        lines = np.zeros((F, F))
        for a0, ln in zip(angles, lens):
            d = np.abs(np.angle(np.exp(1j * (th - a0))))
            inner_r = 0.1 + 0.6 * e
            outer_r = inner_r + (0.25 + 0.4 * ln) * (1 - 0.6 * t)
            seg = smooth(inner_r - 0.02, inner_r + 0.04, r) * (1 - smooth(outer_r - 0.06, outer_r, r))
            wid = 0.06 * (1 - r * 0.45)
            lines = np.maximum(lines, seg * (1 - smooth(wid * 0.3, wid, d)))
        out = over(out, layer(lines * fade, CYAN_WHITE))
        # shock ring
        rr = 0.2 + 0.7 * e
        ring = np.exp(-(((r - rr) / (0.035 + 0.03 * t)) ** 2)) * (1 - smooth(0.35, 0.9, t))
        out = over(out, layer(ring * 0.9, CYAN))
        # star flash: 8 spikes, biggest at the first frames
        s = (1.0 - 0.75 * t) * (0.55 + 0.45 * smooth(0, 0.15, t))
        spikes = (np.abs(np.cos(4 * th)) ** 18) * 0.9 + (np.abs(np.cos(4 * th + math.pi / 4)) ** 30) * 0.45
        flash = smooth(0.0, 1.0, 1 - r / np.maximum(s * (0.18 + 0.55 * spikes), 1e-3))
        flash *= 1 - smooth(0.2, 0.55, t)
        core = np.exp(-((r / (0.16 * (1 - 0.6 * t))) ** 2)) * (1 - smooth(0.1, 0.5, t))
        out = over(out, layer(np.clip(flash, 0, 1), np.array([200, 235, 255.0])))
        out = over(out, layer(np.clip(core, 0, 1), np.array([255, 255, 255.0])))
        frames.append(to_img(out))
    return grid(frames, 4)


# ------------------------------------------------------------------ stars and sparkles
def star_poly(cx, cy, R, rr, rot=-math.pi / 2):
    pts = []
    for i in range(10):
        a = rot + i * math.pi / 5
        rad = R if i % 2 == 0 else rr
        pts.append((cx + rad * math.cos(a), cy + rad * math.sin(a)))
    return pts


def star(N=256):
    """Bevelled gold Joestar star: each arm split into a lit and a shaded half, white-hot middle, a halo."""
    k = 4
    S = N * k
    c = S / 2
    R, rr = S * 0.40, S * 0.40 * 0.42
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pts = star_poly(c, c, R, rr)
    # outline
    d.polygon(star_poly(c, c, R + 7 * k, rr + 5 * k), fill=(120, 50, 8, 255))
    for i in range(10):
        p0 = pts[i]
        p1 = pts[(i + 1) % 10]
        lit = (i % 2 == 0)
        a = math.atan2((p0[1] + p1[1]) / 2 - c, (p0[0] + p1[0]) / 2 - c)
        light = 0.5 + 0.5 * math.cos(a - math.radians(-135))  # light from the upper left
        base = GOLD if lit else GOLD_DARK
        col = base * (0.72 + 0.4 * light)
        d.polygon([(c, c), p0, p1], fill=tuple(int(min(255, v)) for v in col) + (255,))
    arr = np.asarray(img, float)
    yy, xx = np.mgrid[0:S, 0:S].astype(float)
    r = np.hypot(xx - c, yy - c) / (S / 2)
    hot = np.exp(-((r / 0.22) ** 2))
    arr[..., :3] = arr[..., :3] + (255 - arr[..., :3]) * (hot * 0.85 * (arr[..., 3] > 0))[..., None]
    out = down(arr, k)
    # halo
    n = N
    yy, xx = np.mgrid[0:n, 0:n].astype(float)
    rn = np.hypot(xx - n / 2, yy - n / 2) / (n / 2)
    halo = layer(np.exp(-((rn / 0.62) ** 2)) * 0.55, np.array([255, 222, 120.0]))
    return to_img(over(halo, out))


def comet(W=384, H=64):
    """One beam tile of the STARDUST ORBITS: a gold Joestar star (head, at +U) with a tapering tail of white-gold
    into hot pink into violet, sparkle dots along it, and an empty gap before the next tile's comet.
    U runs along x (the beam's length), V along y (its width); the tile matches the beam's aspect (6:1)."""
    k = 4
    Wk, Hk = W * k, H * k
    xs = np.linspace(0, 1, Wk)[None, :]
    ys = np.linspace(-1, 1, Hk)[:, None]
    head_x = 0.86
    tail0 = 0.3  # the tail starts fading in here (the first 30% is the gap between comets)
    t = np.clip((xs - tail0) / (head_x - tail0), 0, 1)  # 0 at the tail's end .. 1 at the head
    behind = xs <= head_x
    width = 0.08 + 0.5 * t ** 1.6
    core = np.exp(-((ys / np.maximum(width * 0.35, 1e-3)) ** 2)) * (t ** 1.3) * behind
    soft = np.exp(-((ys / np.maximum(width, 1e-3)) ** 2)) * (t ** 1.8) * 0.65 * behind
    a = np.clip(core + soft, 0, 1)
    # colour along the tail: violet (end) -> hot pink -> white-gold (near the head)
    c_end = np.array([120, 70, 255.0])
    c_mid = np.array([255, 90, 210.0])
    c_head = np.array([255, 236, 170.0])
    tt = np.broadcast_to(t, a.shape)[..., None]
    col = np.where(tt < 0.55, c_end + (c_mid - c_end) * (tt / 0.55), c_mid + (c_head - c_mid) * ((tt - 0.55) / 0.45))
    col = col + (255 - col) * (core[..., None] * 0.6)
    out = np.concatenate([col, (a * 255)[..., None]], axis=2)
    # sparkle dots shed along the tail
    rng = np.random.default_rng(2024)
    yy, xx = np.mgrid[0:Hk, 0:Wk].astype(float)
    for _ in range(26):
        u = rng.uniform(0.32, head_x - 0.06)
        v = rng.normal(0, 0.35) * (0.3 + (u - 0.32))
        cx, cy = u * Wk, (v * 0.5 + 0.5) * Hk
        rr = rng.uniform(1.2, 2.6) * k
        d = np.hypot(xx - cx, yy - cy)
        dot = np.exp(-((d / rr) ** 2)) * rng.uniform(0.6, 1.0)
        out = over(out, layer(dot, np.array([255, 245, 220.0])))
    out = down(out, k)
    # the head: the Joestar star, pasted over the tail's front
    st = star(160).resize((H + 8, H + 8), Image.LANCZOS)
    img = to_img(out)
    img.alpha_composite(st, (int(head_x * W - (H + 8) / 2), -4))
    return img


def emblem(N=1024):
    """JOESTAR EMBLEM, the crest behind his shoulders: a gold star outline (white-hot inner edge, faint violet
    fill) inside a gold ring, violet-pink light rays fanning out past it, sparkles at the star's tips."""
    k = 2
    S = N * k
    c = S / 2
    yy, xx = np.mgrid[0:N, 0:N].astype(float)
    r = np.hypot(xx - N / 2, yy - N / 2) / (N / 2)
    th = np.arctan2(yy - N / 2, xx - N / 2)
    out = np.zeros((N, N, 4))
    # rays: 20, long and short alternating, a soft glow under them
    glow = np.exp(-((r / 0.62) ** 2)) * 0.42 * (r < 1)
    out = over(out, layer(glow, np.array([110, 60, 230.0])))
    rays = np.zeros((N, N))
    for i in range(20):
        a0 = -math.pi / 2 + i * 2 * math.pi / 20
        d = np.abs(np.angle(np.exp(1j * (th - a0))))
        long = i % 2 == 0
        r1 = 0.98 if long else 0.8
        wid = (0.05 if long else 0.032) * (1 - 0.6 * smooth(0.45, r1, r))
        seg = smooth(0.4, 0.5, r) * (1 - smooth(r1 - 0.25, r1, r))
        rays = np.maximum(rays, seg * (1 - smooth(wid * 0.35, wid, d)))
    rcol = np.array([255, 120, 220.0])[None, None, :] * (1 - r[..., None]) + np.array([130, 80, 255.0])[None, None, :] * r[..., None]
    out = over(out, layer(rays * 0.85, rcol))
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # ring
    for rad, w, col in ((0.665, 22, (120, 50, 8, 255)), (0.665, 14, (255, 205, 60, 255)), (0.665, 4, (255, 250, 220, 255))):
        rr = S / 2 * rad
        d.ellipse([c - rr, c - rr, c + rr, c + rr], outline=col, width=w * k)
    # the star: faint violet fill, a dark-gold outline, gold stroke, white-hot inner line
    R = S / 2 * 0.6
    pts = star_poly(c, c, R, R * 0.42)
    d.polygon(pts, fill=(150, 90, 255, 70))
    for w, col in ((30, (120, 50, 8, 255)), (20, (255, 205, 60, 255)), (6, (255, 250, 225, 255))):
        d.line(pts + [pts[0], pts[1]], fill=col, width=w * k, joint="curve")
    arr = down(np.asarray(img, float), k)
    bloom = layer(ndimage.gaussian_filter(arr[..., 3], 9) / 255 * 0.6, np.array([255, 200, 110.0]))
    out = over(over(out, bloom), arr)
    # sparkles on the five tips
    tw = np.asarray(twinkle(160), float)
    img = to_img(out)
    for i in range(5):
        a = -math.pi / 2 + i * 2 * math.pi / 5
        x, y = N / 2 + (N / 2) * 0.6 * math.cos(a), N / 2 + (N / 2) * 0.6 * math.sin(a)
        img.alpha_composite(to_img(tw), (int(x - 80), int(y - 80)))
    return img


def twinkle(N=128):
    c = N / 2
    yy, xx = np.mgrid[0:N, 0:N].astype(float)
    x, y = (xx - c) / c, (yy - c) / c
    r = np.hypot(x, y)
    cross = np.exp(-np.abs(x) / 0.035) * np.exp(-np.abs(y) / 0.55) + np.exp(-np.abs(y) / 0.035) * np.exp(-np.abs(x) / 0.55)
    diag = (np.exp(-np.abs(x - y) / 0.05) + np.exp(-np.abs(x + y) / 0.05)) * np.exp(-r / 0.22) * 0.5
    core = np.exp(-((r / 0.13) ** 2))
    halo = np.exp(-((r / 0.45) ** 2)) * 0.3
    a = np.clip(cross + diag + core + halo, 0, 1)
    return to_img(layer(a, np.array([255, 255, 255.0])))


def pulse(N=512):
    """Time-stop sphere wave: a bright rim, a green fringe outside and a magenta one inside (the inverted
    colours of Star Platinum: The World), a faint lilac inside."""
    c = N / 2
    yy, xx = np.mgrid[0:N, 0:N].astype(float)
    r = np.hypot(xx - c, yy - c) / c
    rim = np.exp(-(((r - 0.9) / 0.022) ** 2))
    green = np.exp(-(((r - 0.94) / 0.03) ** 2))
    mag = np.exp(-(((r - 0.85) / 0.04) ** 2))
    fill = smooth(0.0, 0.9, r) * (r < 0.9) * 0.22
    out = np.zeros((N, N, 4))
    out = over(out, layer(fill, np.array([200, 170, 255.0])))
    out = over(out, layer(mag * 0.8, np.array([255, 70, 210.0])))
    out = over(out, layer(green * 0.75, np.array([120, 255, 170.0])))
    out = over(out, layer(rim, np.array([255, 255, 255.0])))
    return to_img(out)


def glow(N=256):
    c = N / 2
    yy, xx = np.mgrid[0:N, 0:N].astype(float)
    r = np.hypot(xx - c, yy - c) / c
    a = np.clip(1 - r, 0, 1) ** 2.2
    return to_img(layer(a, np.array([255, 255, 255.0])))


# ------------------------------------------------------------------ ground: stat hexagon + clock ring
def text_on(d, xy, s, font, fill, stroke, sw, anchor="mm"):
    d.text(xy, s, font=font, fill=fill, stroke_width=sw, stroke_fill=stroke, anchor=anchor)


def sigil(N=1024):
    """Star Platinum's stand-stat chart (Power A, Speed A, Range C, Durability A, Precision A, Potential A)
    as a glowing hexagon round the Joestar star."""
    k = 2
    S = N * k
    c = S / 2
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    R = S * 0.36
    grades = ["A", "A", "C", "A", "A", "A"]  # clockwise from the top: power, speed, range, durability, precision, potential
    val = {"A": 1.0, "B": 0.8, "C": 0.6}
    ang = [-math.pi / 2 + i * math.pi / 3 for i in range(6)]
    hexpts = [(c + R * math.cos(a), c + R * math.sin(a)) for a in ang]
    # filled stat polygon
    stat = [(c + R * val[g] * math.cos(a), c + R * val[g] * math.sin(a)) for g, a in zip(grades, ang)]
    d.polygon(stat, fill=(168, 70, 255, 120))
    # guide rings (the chart's grade lines)
    for f in (0.2, 0.4, 0.6, 0.8):
        p = [(c + R * f * math.cos(a), c + R * f * math.sin(a)) for a in ang]
        d.line(p + [p[0]], fill=(150, 200, 255, 110), width=3 * k)
    for (x, y) in hexpts:
        d.line([(c, c), (x, y)], fill=(150, 200, 255, 130), width=3 * k)
    d.line(hexpts + [hexpts[0]], fill=(226, 250, 255, 255), width=9 * k, joint="curve")
    d.line(stat + [stat[0]], fill=(255, 150, 240, 255), width=7 * k, joint="curve")
    # outer ring
    for rad, w, col in ((0.465, 10, (226, 250, 255, 255)), (0.488, 4, (150, 200, 255, 200))):
        rr = S * rad
        d.ellipse([c - rr, c - rr, c + rr, c + rr], outline=col, width=w * k)
    # grade letters in circles at the vertices
    f = ImageFont.truetype(str(LATIN_FONT), int(S * 0.062))
    for g, a in zip(grades, ang):
        x, y = c + R * 1.115 * math.cos(a), c + R * 1.115 * math.sin(a)
        rr = S * 0.046
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=(40, 16, 96, 255), outline=(226, 250, 255, 255), width=5 * k)
        text_on(d, (x, y + S * 0.002), g, f, (255, 214, 70, 255), (40, 16, 96, 255), 2 * k)
    # the star in the middle
    d.polygon(star_poly(c, c, S * 0.135 + 8 * k, S * 0.135 * 0.42 + 6 * k), fill=(40, 16, 96, 255))
    pts = star_poly(c, c, S * 0.135, S * 0.135 * 0.42)
    for i in range(10):
        p0, p1 = pts[i], pts[(i + 1) % 10]
        a = math.atan2((p0[1] + p1[1]) / 2 - c, (p0[0] + p1[0]) / 2 - c)
        light = 0.5 + 0.5 * math.cos(a - math.radians(-135))
        base = GOLD if i % 2 == 0 else GOLD_DARK
        col = base * (0.72 + 0.4 * light)
        d.polygon([(c, c), p0, p1], fill=tuple(int(min(255, v)) for v in col) + (255,))
    arr = down(np.asarray(img, float), k)
    # soft violet pool under it all, and a bloom of the bright lines
    yy, xx = np.mgrid[0:N, 0:N].astype(float)
    r = np.hypot(xx - N / 2, yy - N / 2) / (N / 2)
    pool = layer(np.exp(-((r / 0.75) ** 2)) * 0.5 * (r < 1), np.array([70, 30, 170.0]))
    bloom_a = ndimage.gaussian_filter(arr[..., 3], 7) * 0.5
    bloom = layer(bloom_a / 255, np.array([170, 140, 255.0]))
    return to_img(over(over(pool, bloom), arr))


def clockring(N=1024):
    k = 2
    S = N * k
    c = S / 2
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r_out, r_in = S * 0.485, S * 0.385
    d.ellipse([c - r_out, c - r_out, c + r_out, c + r_out], outline=(226, 250, 255, 255), width=8 * k)
    d.ellipse([c - r_in, c - r_in, c + r_in, c + r_in], outline=(226, 250, 255, 230), width=6 * k)
    # minute ticks on the inner edge, hour stars between the rings' text gaps
    for m in range(60):
        a = m * math.pi / 30
        l = 0.03 if m % 5 else 0.0
        if l:
            p0 = (c + (r_in + 6 * k) * math.cos(a), c + (r_in + 6 * k) * math.sin(a))
            p1 = (c + (r_in + S * l) * math.cos(a), c + (r_in + S * l) * math.sin(a))
            d.line([p0, p1], fill=(170, 210, 255, 220), width=3 * k)
    # lettering round the band, a star at each hour mark between the words
    words = "STAR PLATINUM \u2605 THE WORLD \u2605 STAR PLATINUM \u2605 THE WORLD \u2605 "
    f = ImageFont.truetype(str(LATIN_FONT), int(S * 0.046))
    rt = (r_out + r_in) / 2 + S * 0.004
    n = len(words)
    for i, ch in enumerate(words):
        a = -math.pi / 2 + i * 2 * math.pi / n
        if ch == "\u2605":
            pts = star_poly(c + rt * math.cos(a), c + rt * math.sin(a), S * 0.02, S * 0.0085, rot=a)
            d.polygon(pts, fill=(255, 214, 70, 255))
            continue
        if ch == " ":
            continue
        glyph = Image.new("RGBA", (int(S * 0.08), int(S * 0.08)), (0, 0, 0, 0))
        gd = ImageDraw.Draw(glyph)
        text_on(gd, (glyph.size[0] / 2, glyph.size[1] / 2), ch, f, (226, 250, 255, 255), (40, 16, 96, 255), 2 * k)
        rot = glyph.rotate(-math.degrees(a) - 90, resample=Image.BICUBIC)
        x, y = c + rt * math.cos(a), c + rt * math.sin(a)
        img.alpha_composite(rot, (int(x - rot.size[0] / 2), int(y - rot.size[1] / 2)))
    arr = down(np.asarray(img, float), k)
    bloom = layer(ndimage.gaussian_filter(arr[..., 3], 6) / 255 * 0.45, np.array([150, 120, 255.0]))
    return to_img(over(bloom, arr))


# ------------------------------------------------------------------ contact sheet
def contact(imgs):
    cell = 300
    names = list(imgs)
    cols = 5
    rows = math.ceil(len(names) / cols)
    sheet = Image.new("RGB", (cell * cols, cell * rows * 2), (0, 0, 0))
    d = ImageDraw.Draw(sheet)
    for half, bg in enumerate(((14, 10, 26), (196, 210, 225))):
        for i, n in enumerate(names):
            x, y = (i % cols) * cell, (i // cols) * cell + half * cell * rows
            tile = Image.new("RGBA", (cell, cell), bg + (255,))
            im = imgs[n].copy()
            im.thumbnail((cell - 20, cell - 30))
            tile.alpha_composite(im, ((cell - im.size[0]) // 2, 22))
            sheet.paste(tile.convert("RGB"), (x, y))
            d.text((x + 6, y + 4), n, fill=(255, 255, 255) if half == 0 else (0, 0, 0))
    return sheet


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    made = {
        "go_2x2": go_flipbook(),
        "ora": ora(),
        "impact_4x4": impact(),
        "star": star(),
        "twinkle": twinkle(),
        "comet_v": comet().transpose(Image.ROTATE_90),  # upright: Roblox lays a beam texture's VERTICAL axis along the beam
        "emblem": emblem(),
        "pulse": pulse(),
        "sigil": sigil(),
        "clockring": clockring(),
        "glow": glow(),
    }
    for n, im in made.items():
        im.save(OUT / f"{n}.png", optimize=True)
        print("wrote", n, im.size)
    contact(made).save(OUT / "_sheet.jpg", quality=90)
    print("sheet", OUT / "_sheet.jpg")


if __name__ == "__main__":
    main()
