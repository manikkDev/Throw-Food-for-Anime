#!/usr/bin/env python3
"""Card-opening artwork for the Celebrate screen (owner: "reveal it like a Clash Royale card opening").

    python tools/ui/cards_art.py              draw every texture into assets/ui/cards/ + sheet.png
    python tools/ui/cards_art.py --only CardBack,CardFrame_Legendary
    python tools/ui/cards_art.py --preview    also composite tier strip / banner previews (work/ui/mockups/cards/)
    python tools/ui/cards_art.py --upload-only   upload textures with no id yet (Open Cloud, Image) -> ids_cards.json
                                                 (--force re-uploads all); then `python tools/gen_icons.py`

Everything is drawn procedurally (numpy + PIL, no generated or stock imagery), at 2x and box-reduced, so it is
crisp and reproducible (fixed seeds). The toolkit:
  masks      exact rounded-rect SDFs; polygons / ellipses / text through PIL at 4x then reduced (anti-aliased)
  bevel      a distance-field height map per mask -> normals -> lambert + specular; one light from the top left
  materials  metal ramps (steel, jade, sapphire, amethyst, gold, holo chrome, void, rose gold), faceted gems
  patterns   seigaiha, asanoha, halftone, radial speed lines, brushed noise, nebula, star fields, sakura

Textures (keys = Icons keys, see assets/ui/ids_cards.json):
  CardBack                 512x716  the face-down back, opaque
  CardFrame_<Tier>         512x716  the front frame; the portrait WINDOW (WIN below) is transparent
  CardBanner_<Tier>        420x96   the rarity ribbon (the tier word is UI text, not baked)
  CardFoil                 512x716  a holographic sheen, mostly transparent (the client sweeps it)
  CardWindowShade          512x716  a vignette for the portrait window only
  CardPortraitBg           512x420  white speed-line burst behind the hero (tinted per tier by ImageColor3)
  CelebrateBackdrop        1280x720 radial burst backdrop
  CelebrateBanner          760x150  the title ribbon
Card layout every frame shares (card px, 512 x 716): WIN = (30, 30)..(482, 440) is safe inside every window;
the divider bar 440..458; the name zone 470..600; the banner centre y 650.
"""

from __future__ import annotations

import argparse
import json
import math
import re
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage as ndi

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "ui" / "cards"
PREVIEW = ROOT / "work" / "ui" / "mockups" / "cards"
S = 2                    # supersample of the working canvas
CW, CH = 512, 716        # card
CARD_R = 34              # card corner radius
WIN_B = 440              # window bottom (all tiers)
DIV_B = 458              # divider bar bottom
NAME_Y = (470, 600)
BANNER_CY = 650

TIER_ORDER = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Premium"]

_FONT_CANDIDATES = [r"C:\Windows\Fonts\NotoSansJP-Black.otf", r"C:\Windows\Fonts\YuGothB.ttc",
                    r"C:\Windows\Fonts\meiryob.ttc", r"C:\Windows\Fonts\msgothic.ttc"]
KANJI_FONT = next((p for p in _FONT_CANDIDATES if Path(p).exists()), None)
LABEL_FONT = Path.home() / ".claude" / "skills" / "roblox-ui" / "references" / "fonts" / "FredokaOne-Regular.ttf"

LIGHT = np.array([-0.45, -0.65, 0.62], np.float32)
LIGHT /= np.linalg.norm(LIGHT)
HALF = LIGHT + np.array([0, 0, 1], np.float32)
HALF /= np.linalg.norm(HALF)


# ============================================================================ colour helpers

def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)], np.float32)


def ramp(stops, t):
    """stops: [(t, '#hex'), ...]; t: array -> (..., 3)."""
    ts = [s[0] for s in stops]
    cs = np.stack([hexc(s[1]) for s in stops])
    t = np.clip(t, 0, 1)
    return np.stack([np.interp(t, ts, cs[:, i]) for i in range(3)], -1).astype(np.float32)


def hsv_arr(h, s, v):
    h = (h % 1.0) * 6
    i = np.floor(h).astype(int) % 6
    f = h - np.floor(h)
    p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
    r = np.choose(i, [v, q, p, p, t, v])
    g = np.choose(i, [t, v, v, q, p, p])
    b = np.choose(i, [p, p, t, v, v, q])
    return np.stack([r, g, b], -1).astype(np.float32)


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


# ============================================================================ canvas

class Cv:
    def __init__(self, w, h, ox=0, oy=0):
        self.w, self.h, self.ox, self.oy = int(w), int(h), int(ox), int(oy)
        self.a = np.zeros((self.h * S, self.w * S, 4), np.float32)
        yy, xx = np.mgrid[0:self.h * S, 0:self.w * S].astype(np.float32)
        self.x = (xx + 0.5) / S + self.ox
        self.y = (yy + 0.5) / S + self.oy

    def patch(self, cx, cy, half):
        """A small local canvas around (cx, cy): draw into it, then blit() it back (fast ornaments)."""
        x0, y0 = int(math.floor(cx - half)), int(math.floor(cy - half))
        return Cv(2 * half + 2, 2 * half + 2, x0, y0)

    def blit(self, p):
        X0, Y0 = (p.ox - self.ox) * S, (p.oy - self.oy) * S
        H, W = p.a.shape[:2]
        sx0, sy0 = max(0, -X0), max(0, -Y0)
        dx0, dy0 = max(0, X0), max(0, Y0)
        w = min(W - sx0, self.a.shape[1] - dx0)
        h = min(H - sy0, self.a.shape[0] - dy0)
        if w <= 0 or h <= 0:
            return
        src = p.a[sy0:sy0 + h, sx0:sx0 + w]
        dst = self.a[dy0:dy0 + h, dx0:dx0 + w]
        a = src[..., 3:4]
        da = dst[..., 3:4]
        oa = a + da * (1 - a)
        dst[..., :3] = (src[..., :3] * a + dst[..., :3] * da * (1 - a)) / np.maximum(oa, 1e-6)
        dst[..., 3:4] = oa

    # ---------------------------------------------------------------- compositing
    def over(self, rgb, alpha):
        a = np.clip(alpha, 0, 1)[..., None].astype(np.float32)
        rgb = np.broadcast_to(np.asarray(rgb, np.float32), self.a[..., :3].shape)
        da = self.a[..., 3:4]
        oa = a + da * (1 - a)
        self.a[..., :3] = (rgb * a + self.a[..., :3] * da * (1 - a)) / np.maximum(oa, 1e-6)
        self.a[..., 3:4] = oa

    def screen(self, rgb, amount):
        """Lighten the existing pixels (alpha unchanged)."""
        m = np.clip(amount, 0, 1)[..., None]
        rgb = np.broadcast_to(np.asarray(rgb, np.float32), self.a[..., :3].shape)
        self.a[..., :3] = 1 - (1 - self.a[..., :3]) * (1 - rgb * m)

    def multiply(self, rgb, amount):
        m = np.clip(amount, 0, 1)[..., None]
        rgb = np.broadcast_to(np.asarray(rgb, np.float32), self.a[..., :3].shape)
        self.a[..., :3] = self.a[..., :3] * (1 - m + rgb * m)

    def cut(self, mask):
        self.a[..., 3] *= 1 - np.clip(mask, 0, 1)

    def clip_to(self, mask):
        self.a[..., 3] *= np.clip(mask, 0, 1)

    def image(self):
        arr = (np.clip(self.a, 0, 1) * 255 + 0.5).astype(np.uint8)
        im = Image.fromarray(arr, "RGBA")
        return im.convert("RGBa").resize((self.w, self.h), Image.LANCZOS).convert("RGBA")

    # ---------------------------------------------------------------- masks
    def rrect(self, x0, y0, x1, y1, r):
        return np.clip(0.5 - self.rrect_sdf(x0, y0, x1, y1, r) * S, 0, 1)

    def rrect_sdf(self, x0, y0, x1, y1, r):
        cx, cy, hw, hh = (x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0) / 2, (y1 - y0) / 2
        qx = np.abs(self.x - cx) - (hw - r)
        qy = np.abs(self.y - cy) - (hh - r)
        out = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0))
        return out + np.minimum(np.maximum(qx, qy), 0) - r

    def circle(self, cx, cy, r):
        return np.clip(0.5 - (np.hypot(self.x - cx, self.y - cy) - r) * S, 0, 1)

    def ring(self, cx, cy, r, w):
        d = np.abs(np.hypot(self.x - cx, self.y - cy) - r) - w / 2
        return np.clip(0.5 - d * S, 0, 1)

    def pil(self, fn):
        """fn(draw, P, k) draws in canvas units: P(x, y) maps a point, k scales a length; anti-aliased mask."""
        k = S * 2
        ox, oy = self.ox, self.oy
        im = Image.new("L", (self.w * k, self.h * k), 0)
        fn(ImageDraw.Draw(im), lambda x, y: ((x - ox) * k, (y - oy) * k), k)
        im = im.resize((self.w * S, self.h * S), Image.BOX)
        return np.asarray(im, np.float32) / 255

    def poly(self, pts):
        return self.pil(lambda d, P, k: d.polygon([P(x, y) for x, y in pts], fill=255))

    def polys(self, list_of_pts):
        def f(d, P, k):
            for pts in list_of_pts:
                d.polygon([P(x, y) for x, y in pts], fill=255)
        return self.pil(f)

    def text(self, s, cx, cy, size, font=None, vertical=False, spacing=0.0):
        font_path = font or KANJI_FONT
        if not font_path:
            return np.zeros(self.x.shape, np.float32)

        def f(d, P, k):
            fnt = ImageFont.truetype(str(font_path), int(size * k))
            if vertical:
                n = len(s)
                step = size * (1 + spacing)
                for i, ch in enumerate(s):
                    d.text(P(cx, cy + (i - (n - 1) / 2) * step), ch, font=fnt, fill=255, anchor="mm")
            else:
                d.text(P(cx, cy), s, font=fnt, fill=255, anchor="mm")
        return self.pil(f)


def blur(mask, sigma):
    return ndi.gaussian_filter(mask, sigma * S)


def grow(mask, px):
    """Dilate (px > 0) a soft mask by px (1x units)."""
    d = ndi.distance_transform_edt(mask < 0.5) / S
    return np.clip(px - d + 0.5, 0, 1) if px > 0 else mask


# ============================================================================ lighting / materials

def bevel(mask, width, soften=0.8):
    inside = mask > 0.5
    d = ndi.distance_transform_edt(inside) / S
    t = np.clip(d / max(width, 1e-3), 0, 1)
    hgt = width * np.sin(t * np.pi / 2)
    if soften:
        hgt = ndi.gaussian_filter(hgt, soften * S)
    gy, gx = np.gradient(hgt)
    gx, gy = gx * S, gy * S
    n = np.stack([-gx, -gy, np.ones_like(gx)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    diff = n @ LIGHT
    spec = np.clip(n @ HALF, 0, 1)
    return diff, spec, n, d


STEEL = [(0, "#1E222A"), (0.3, "#4B525E"), (0.55, "#8D96A3"), (0.78, "#D3D9E1"), (1, "#FFFFFF")]
JADE = [(0, "#062417"), (0.3, "#11633C"), (0.55, "#2FA56A"), (0.78, "#8EF0BE"), (1, "#F1FFF7")]
SAPPHIRE = [(0, "#081538"), (0.3, "#1B4296"), (0.55, "#4C8BE8"), (0.78, "#AFD3FF"), (1, "#FFFFFF")]
AMETHYST = [(0, "#1C0636"), (0.3, "#4E1A94"), (0.55, "#8F4FE6"), (0.78, "#D9B5FF"), (1, "#FFFFFF")]
GOLD = [(0, "#3D2004"), (0.28, "#8A4E0A"), (0.5, "#D8961E"), (0.7, "#F7CF5A"), (0.86, "#FFF1B0"), (1, "#FFFFFF")]
VOID = [(0, "#030205"), (0.35, "#120B1A"), (0.6, "#2C1C3C"), (0.82, "#6B4C8C"), (1, "#E8D6FF")]
ROSE = [(0, "#4A1820"), (0.3, "#9C4B53"), (0.55, "#DE8C86"), (0.78, "#FFD0C2"), (1, "#FFFFFF")]
SILVER = [(0, "#2A2E3A"), (0.35, "#6F7688"), (0.6, "#B9C0CF"), (0.82, "#EEF1F7"), (1, "#FFFFFF")]


def metal(cv, mask, stops, width=6, env=0.16, spec_amt=0.85, power=36, holo=False, noise=None, contrast=1.0,
          shadow=0.0, shadow_off=(0, 3)):
    """A beveled metal shape. `holo` = prismatic chrome (hue follows position and normal)."""
    if shadow:
        sh = np.roll(blur(mask, 2.5), (int(shadow_off[1] * S), int(shadow_off[0] * S)), (0, 1))
        cv.over(hexc("#000000"), sh * shadow)
    diff, spec, n, d = bevel(mask, width)
    rel = (diff - LIGHT[2]) * contrast
    wave = np.sin((cv.y * 0.85 + cv.x * 0.4) / 95 * 2 * np.pi + n[..., 0] * 2.2 - n[..., 1] * 1.6)
    t = 0.56 + 0.85 * rel + env * wave
    if noise is not None:
        t = t + noise
    if holo:
        hue = (cv.x + cv.y * 0.7) / 520 + n[..., 0] * 0.35 + n[..., 1] * 0.25 + wave * 0.06
        v = np.clip(0.62 + 0.75 * rel + 0.12 * wave, 0.15, 1)
        col = hsv_arr(hue, 0.42 + 0.15 * wave, v)
        col = col * 0.85 + ramp(SILVER, t) * 0.15
    else:
        col = ramp(stops, t)
    col = 1 - (1 - col) * (1 - (spec ** power * spec_amt)[..., None])
    cv.over(col, mask)
    return n


def flat_fill(cv, mask, top, bottom, y0=0, y1=None):
    y1 = y1 if y1 is not None else cv.h
    t = np.clip((cv.y - y0) / max(1, y1 - y0), 0, 1)[..., None]
    cv.over(hexc(top) * (1 - t) + hexc(bottom) * t, mask)


def glow(cv, mask, colour, sigma, strength=1.0):
    g = blur(mask, sigma)
    g = np.clip(g / max(g.max(), 1e-6), 0, 1) * strength
    cv.over(hexc(colour), g)


def ell(cv, x0, y0, x1, y1):
    return cv.pil(lambda d, P, k: d.ellipse([*P(x0, y0), *P(x1, y1)], fill=255))


def gem(cv, cx, cy, r, colour, shape="round", facets=8, bezel=None, rot=0.0):
    """A faceted gem with an optional metal bezel, drawn on a local patch."""
    p = cv.patch(cx, cy, int(r * 1.9 + 10))
    _gem(p, cx, cy, r, colour, shape, facets, bezel, rot)
    cv.blit(p)


def _gem(cv, cx, cy, r, colour, shape, facets, bezel, rot):
    if shape == "round":
        m = cv.circle(cx, cy, r)
    elif shape == "diamond":
        m = cv.poly([(cx, cy - r * 1.25), (cx + r, cy), (cx, cy + r * 1.25), (cx - r, cy)])
    elif shape == "oval":
        m = ell(cv, cx - r * 0.78, cy - r * 1.1, cx + r * 0.78, cy + r * 1.1)
    else:  # hex
        m = cv.poly([(cx + r * math.cos(rot + i * math.pi / 3), cy + r * math.sin(rot + i * math.pi / 3))
                     for i in range(6)])
    if bezel:
        metal(cv, grow(m, max(2.5, r * 0.28)), bezel, width=max(1.5, r * 0.2), shadow=0.5, shadow_off=(0, 2))
    base = hexc(colour)
    ang = np.arctan2(cv.y - cy, cv.x - cx) - rot
    sector = np.floor((ang + np.pi) / (2 * np.pi) * facets) % facets
    rng = np.random.default_rng(int(cx * 7 + cy * 13 + r))
    tone = rng.uniform(0.55, 1.2, facets)[sector.astype(int)]
    rad = np.hypot(cv.x - cx, cv.y - cy) / max(r, 1)
    tone = np.where(rad < 0.45, 1.08, tone * (1.1 - 0.35 * rad))
    lit = 1 + 0.35 * (-(cv.x - cx) * 0.6 - (cv.y - cy) * 0.8) / max(r, 1)
    col = np.clip(base[None, None, :] * (tone * lit)[..., None], 0, 1)
    cv.over(col, m)
    hl = ell(cv, cx - r * 0.55, cy - r * 0.62, cx - r * 0.05, cy - r * 0.22)
    cv.over(hexc("#FFFFFF"), blur(hl, max(0.6, r * 0.06)) * m * 0.75)
    cv.over(hexc("#FFFFFF"), np.clip(star4(cv, cx - r * 0.3, cy - r * 0.42, r * 0.6), 0, 1) * 0.95)


def star4(cv, cx, cy, r, thin=0.5):
    """A four-point sparkle (an astroid) with a soft core."""
    u = np.abs(cv.x - cx) / max(r, 1e-3)
    v = np.abs(cv.y - cy) / max(r, 1e-3)
    f = u ** thin + v ** thin
    core = np.exp(-(u * u + v * v) * 9)
    return np.clip((1 - f) * 6, 0, 1) + core * 0.6


# ============================================================================ patterns

def seigaiha(cv, R, x0=0, y0=0, rings=4, line=1.6):
    """Wave scales: rows of concentric half circles, later rows over earlier ones."""
    def f(d, P, k):
        rows = int(cv.h / (R / 2)) + 4
        cols = int(cv.w / (2 * R)) + 3
        for j in range(-2, rows):
            cy = y0 + j * R / 2
            off = (j % 2) * R
            for i in range(-2, cols):
                cx = x0 + i * 2 * R + off
                d.ellipse([*P(cx - R, cy - R), *P(cx + R, cy + R)], fill=0)
                for q in range(rings):
                    rr = R * (1 - q / rings) - line * 0.5
                    if rr > line:
                        d.ellipse([*P(cx - rr, cy - rr), *P(cx + rr, cy + rr)], outline=255,
                                  width=max(1, int(line * k)))
    return cv.pil(f)


def asanoha(cv, a, line=1.2):
    """Hemp-leaf lattice: triangle grid + every triangle's centroid joined to its corners."""
    h = a * math.sqrt(3) / 2

    def f(d, P, k):
        w = max(1, int(line * k))
        rows = int(cv.h / h) + 3
        cols = int(cv.w / a) + 3
        for j in range(-1, rows):
            for i in range(-1, cols):
                ox = i * a + (j % 2) * a / 2
                oy = j * h
                up = [(ox, oy + h), (ox + a, oy + h), (ox + a / 2, oy)]
                dn = [(ox + a / 2, oy), (ox + a * 1.5, oy), (ox + a, oy + h)]
                for tri in (up, dn):
                    cx = sum(p[0] for p in tri) / 3
                    cy = sum(p[1] for p in tri) / 3
                    pts = [P(*q) for q in tri]
                    d.line(pts + [pts[0]], fill=255, width=w)
                    for q in pts:
                        d.line([P(cx, cy), q], fill=255, width=w)
    return cv.pil(f)


def halftone(cv, spacing, radius_field, angle=45):
    th = math.radians(angle)
    u = cv.x * math.cos(th) + cv.y * math.sin(th)
    v = -cv.x * math.sin(th) + cv.y * math.cos(th)
    fu = (u / spacing) % 1 - 0.5
    fv = (v / spacing) % 1 - 0.5
    d = np.hypot(fu, fv) * spacing
    return np.clip((radius_field - d) * S + 0.5, 0, 1)


def speed_lines(cv, cx, cy, n=160, r0=60, r1=None, seed=1, width=(0.15, 0.7)):
    rng = np.random.default_rng(seed)
    ang = (np.arctan2(cv.y - cy, cv.x - cx) + np.pi) / (2 * np.pi)
    rad = np.hypot(cv.x - cx, cv.y - cy)
    bins = 4096
    prof = np.zeros(bins, np.float32)
    for _ in range(n):
        c = rng.uniform(0, 1)
        w = rng.uniform(*width) / 360
        idx = np.arange(int((c - w) * bins), int((c + w) * bins) + 1)
        t = 1 - np.abs((idx / bins - c) / max(w, 1e-6))
        prof[idx % bins] = np.maximum(prof[idx % bins], np.clip(t * 1.6, 0, 1) * rng.uniform(0.5, 1))
    a = np.interp(ang * bins, np.arange(bins), prof)
    start = rng.uniform(0, 1, bins)[(ang * bins).astype(int) % bins] * 60
    fade = smooth(r0 + start, r0 + start + 40, rad)
    if r1:
        fade *= smooth(r1, r1 * 0.7, rad)
    return a * fade


def brushed(cv, seed=3, strength=1.0):
    rng = np.random.default_rng(seed)
    nz = rng.normal(0, 1, cv.x.shape).astype(np.float32)
    nz = ndi.gaussian_filter(nz, (0.4 * S, 24 * S))
    return nz / (nz.std() + 1e-6) * strength


def fbm(cv, seed=5, scales=(120, 60, 30, 14), weights=(1, 0.6, 0.35, 0.2)):
    rng = np.random.default_rng(seed)
    out = np.zeros(cv.x.shape, np.float32)
    for sc, w in zip(scales, weights):
        nz = rng.normal(0, 1, cv.x.shape).astype(np.float32)
        nz = ndi.gaussian_filter(nz, sc * S / 4)
        out += nz / (nz.std() + 1e-6) * w
    out -= out.min()
    return out / max(out.max(), 1e-6)


def star_field(cv, n, seed=9, rmin=0.6, rmax=1.8, region=None):
    rng = np.random.default_rng(seed)
    m = np.zeros(cv.x.shape, np.float32)
    x0, y0, x1, y1 = region or (0, 0, cv.w, cv.h)
    for _ in range(n):
        cx, cy = rng.uniform(x0, x1), rng.uniform(y0, y1)
        r = rng.uniform(rmin, rmax)
        sl = _win(cv, cx, cy, r * 6)
        if sl is None:
            continue
        ys, xs = sl
        m[ys, xs] = np.maximum(m[ys, xs], np.exp(-((cv.x[ys, xs] - cx) ** 2 + (cv.y[ys, xs] - cy) ** 2) / (r * r)))
    return m


def _win(cv, cx, cy, rad):
    x0, x1 = int(max(0, (cx - rad) * S)), int(min(cv.w * S, (cx + rad) * S + 1))
    y0, y1 = int(max(0, (cy - rad) * S)), int(min(cv.h * S, (cy + rad) * S + 1))
    if x1 <= x0 or y1 <= y0:
        return None
    return slice(y0, y1), slice(x0, x1)


def sparkles(cv, pts):
    m = np.zeros(cv.x.shape, np.float32)
    for cx, cy, r in pts:
        sl = _win(cv, cx, cy, r * 1.2)
        if sl is None:
            continue
        ys, xs = sl
        u = np.abs(cv.x[ys, xs] - cx) / r
        v = np.abs(cv.y[ys, xs] - cy) / r
        f = u ** 0.5 + v ** 0.5
        core = np.exp(-(u * u + v * v) * 9)
        m[ys, xs] = np.maximum(m[ys, xs], np.clip((1 - f) * 6, 0, 1) + core * 0.6)
    return np.clip(m, 0, 1)


# ============================================================================ shapes

def rot_pts(pts, ang, cx, cy):
    c, s = math.cos(ang), math.sin(ang)
    return [(cx + x * c - y * s, cy + x * s + y * c) for x, y in pts]


def leaf_pts(length, width, n=24):
    top = [(t * length, -width * math.sin(math.pi * t) ** 0.8) for t in np.linspace(0, 1, n)]
    bot = [(t * length, width * math.sin(math.pi * t) ** 0.8) for t in np.linspace(1, 0, n)]
    return top + bot


def bolt_pts(x, y, h, w, flip=False):
    s = -1 if flip else 1
    p = [(0, 0), (0.55, 0), (0.25, 0.38), (0.62, 0.38), (-0.05, 1.0), (0.18, 0.52), (-0.2, 0.52)]
    return [(x + s * px * w, y + py * h) for px, py in p]


def shard_pts(cx, cy, length, width, ang):
    p = [(0, -width * 0.5), (length * 0.78, -width * 0.42), (length, 0), (length * 0.78, width * 0.42),
         (0, width * 0.5)]
    return rot_pts(p, ang, cx, cy)


def sakura_pts(cx, cy, R, rot=0.0, n=120):
    """Five notched petals."""
    pts = []
    for i in range(n):
        th = 2 * math.pi * i / n
        local = (th * 5 / (2 * math.pi)) % 1          # 0..1 across one petal
        petal = math.sin(math.pi * local) ** 0.55
        notch = 1 - 0.22 * math.exp(-((local - 0.5) / 0.07) ** 2)
        r = R * (0.32 + 0.68 * petal) * notch
        pts.append((cx + r * math.cos(th + rot), cy + r * math.sin(th + rot)))
    return pts


def star_pts(cx, cy, R, r, n=5, rot=-math.pi / 2):
    pts = []
    for i in range(n * 2):
        rr = R if i % 2 == 0 else r
        th = rot + i * math.pi / n
        pts.append((cx + rr * math.cos(th), cy + rr * math.sin(th)))
    return pts


def corner_list(inset):
    """(cx, cy, sx, sy) for the four card corners: sx/sy point INTO the card."""
    return [(inset, inset, 1, 1), (CW - inset, inset, -1, 1), (inset, CH - inset, 1, -1),
            (CW - inset, CH - inset, -1, -1)]


def filigree(cv, cx, cy, sx, sy, size, thick):
    """An L bracket with scroll curls at both arm ends and a leaf on the diagonal (one card corner)."""
    def f(d, P, k):
        w = int(thick * k)
        L = size
        d.line([P(cx, cy), P(cx + sx * L, cy)], fill=255, width=w)
        d.line([P(cx, cy), P(cx, cy + sy * L)], fill=255, width=w)
        for ex, ey, ox, oy in ((cx + sx * L, cy, 0, sy), (cx, cy + sy * L, sx, 0)):
            rr = size * 0.2
            ccx, ccy = ex + ox * rr, ey + oy * rr
            d.ellipse([*P(ccx - rr, ccy - rr), *P(ccx + rr, ccy + rr)], outline=255, width=w)
            r2 = rr * 0.38
            d.ellipse([*P(ccx - r2, ccy - r2), *P(ccx + r2, ccy + r2)], fill=255)
        # a second, shorter inner arm pair (double rule)
        L2, o = size * 0.55, thick * 1.9
        d.line([P(cx + sx * o, cy + sy * o), P(cx + sx * L2, cy + sy * o)], fill=255, width=max(1, int(thick * 0.5 * k)))
        d.line([P(cx + sx * o, cy + sy * o), P(cx + sx * o, cy + sy * L2)], fill=255, width=max(1, int(thick * 0.5 * k)))
        tip = (cx + sx * size * 0.66, cy + sy * size * 0.66)
        d.polygon([P(cx, cy), P(cx + sx * size * 0.44, cy + sy * size * 0.2), P(*tip),
                   P(cx + sx * size * 0.2, cy + sy * size * 0.44)], fill=255)
    return cv.pil(f)


def corner_piece(cv, cx, cy, half, fn):
    """Run fn(patch) on a local patch around a corner and blit it back."""
    p = cv.patch(cx, cy, half)
    fn(p)
    cv.blit(p)


# ============================================================================ card front frames

TIERS = {
    "Common": dict(bw=16, metal=STEEL, plate=("#454C59", "#1C2028"), glow="#B8C2D2", kanji="普通", rank=0,
                   banner=("#7A8496", "#3A404C"), pattern="brushed"),
    "Uncommon": dict(bw=20, metal=JADE, plate=("#17744A", "#06291A"), glow="#5BE39A", kanji="良品", rank=1,
                     banner=("#2FCB78", "#0C6B3A"), pattern="asanoha"),
    "Rare": dict(bw=24, metal=SAPPHIRE, plate=("#1D56C4", "#0A1A4E"), glow="#4FC3FF", kanji="希少", rank=2,
                 banner=("#3C8DFF", "#123F9E"), gemc="#38A8FF", pattern="seigaiha"),
    "Epic": dict(bw=28, metal=AMETHYST, plate=("#6A22C8", "#1E0748"), glow="#C084FC", kanji="超絶", rank=3,
                 banner=("#A855F7", "#4C1499"), gemc="#C95BFF", pattern="lightning"),
    "Legendary": dict(bw=34, metal=GOLD, plate=("#B3231A", "#420806"), glow="#FFD45C", kanji="伝説", rank=4,
                      banner=("#FF5A3C", "#9E1410"), gemc="#FF2A3C", pattern="sun"),
    "Mythic": dict(bw=34, metal=SILVER, holo=True, plate=("#33207A", "#0B0628"), glow="#FF8CF0", kanji="神話",
                   rank=5, banner=None, gemc="#9AF6FF", pattern="prism"),
    "Secret": dict(bw=34, metal=VOID, plate=("#1A0828", "#020103"), glow="#FF2D6F", kanji="秘密", rank=6,
                   banner=("#3A0A1E", "#0A0206"), gemc="#FF1F4B", pattern="cosmic"),
    "Premium": dict(bw=32, metal=ROSE, plate=("#C43478", "#55102F"), glow="#FF9AC8", kanji="特別", rank=6,
                    banner=("#FF6FB0", "#B51D66"), gemc="#FF5FA2", pattern="sakura"),
}
DIV_Y = (WIN_B + DIV_B) / 2


def _plate_pattern(cv, t, cfg, plate_mask):
    kind = cfg["pattern"]
    pm = plate_mask
    if kind == "brushed":
        nz = brushed(cv, 11)
        cv.screen(hexc("#FFFFFF"), np.clip(nz * 0.05, 0, 1) * pm)
        cv.multiply(hexc("#000000"), np.clip(-nz * 0.06, 0, 1) * pm)
        cv.over(hexc("#FFFFFF"), halftone(cv, 9, 1.2 * smooth(470, 700, cv.y)) * pm * 0.07)
    elif kind == "asanoha":
        cv.over(hexc("#9BF5C6"), asanoha(cv, 46, 1.1) * pm * 0.16)
    elif kind == "seigaiha":
        cv.over(hexc("#9CCBFF"), seigaiha(cv, 26, 0, 452, rings=4, line=1.5) * pm * 0.2)
    elif kind == "lightning":
        cv.over(hexc("#E3C2FF"), speed_lines(cv, CW / 2, 760, n=90, r0=40, seed=4, width=(0.2, 0.9)) * pm * 0.22)
        cv.over(hexc("#FFFFFF"), halftone(cv, 8, 1.5 * smooth(560, 700, cv.y)) * pm * 0.1)
    elif kind == "sun":
        ang = np.arctan2(cv.y - 760, cv.x - CW / 2)
        rays = (np.sin(ang * 24) > 0.15).astype(np.float32)
        cv.over(hexc("#FFB347"), ndi.gaussian_filter(rays, 0.6 * S) * pm * 0.16)
        cv.over(hexc("#FFE08A"), seigaiha(cv, 22, 0, 452, rings=3, line=1.2) * pm * 0.08)
    elif kind == "prism":
        hue = (cv.x * 0.8 + cv.y) / 420
        cv.over(hsv_arr(hue, 0.55, 1.0), pm * 0.26)
        cv.over(hexc("#FFFFFF"), star_field(cv, 50, 21, 0.5, 1.4, (0, 450, CW, CH)) * pm * 0.9)
    elif kind == "cosmic":
        nb = fbm(cv, 33)
        cv.over(hexc("#7A1FA8"), smooth(0.45, 0.9, nb) * pm * 0.55)
        cv.over(hexc("#E0144C"), smooth(0.62, 0.95, fbm(cv, 34)) * pm * 0.45)
        cv.over(hexc("#FFFFFF"), star_field(cv, 90, 22, 0.4, 1.3, (0, 450, CW, CH)) * pm)
    elif kind == "sakura":
        cv.over(hexc("#FFD1E6"), seigaiha(cv, 24, 0, 452, rings=3, line=1.2) * pm * 0.1)
        rng = np.random.default_rng(77)
        pet = []
        for _ in range(14):
            pet.append(sakura_pts(rng.uniform(30, CW - 30), rng.uniform(470, CH - 30), rng.uniform(7, 15),
                                  rng.uniform(0, 6.28)))
        cv.over(hexc("#FFE3EF"), cv.polys(pet) * pm * 0.22)


def card_frame(tier):
    cfg = TIERS[tier]
    rank = cfg["rank"]
    bw = cfg["bw"]
    cv = Cv(CW, CH)
    outer = cv.rrect(0, 0, CW, CH, CARD_R)
    win = cv.rrect(bw, bw, CW - bw, WIN_B, max(8, CARD_R - bw + 4))
    inner = cv.rrect(bw, bw, CW - bw, CH - bw, max(8, CARD_R - bw + 4))
    plate_mask = cv.rrect(bw, DIV_B - 4, CW - bw, CH - bw, max(8, CARD_R - bw + 4))

    # 1. the plate (whole card; the window is punched out after)
    flat_fill(cv, outer, cfg["plate"][0], cfg["plate"][1], 440, CH)
    _plate_pattern(cv, tier, cfg, plate_mask)
    # a soft light behind the name, big kanji watermark
    lightpool = np.exp(-(((cv.x - CW / 2) / 190) ** 2 + ((cv.y - 535) / 60) ** 2))
    cv.screen(hexc(cfg["glow"]), lightpool * plate_mask * 0.22)
    if KANJI_FONT and rank >= 1:
        wm = cv.text(cfg["kanji"], CW / 2, 545, 118)
        cv.over(hexc("#FFFFFF"), wm * plate_mask * (0.04 + 0.006 * rank))
    # inner shadow of the plate under the border
    edge = blur(1 - plate_mask, 5) * plate_mask
    cv.multiply(hexc("#000000"), edge * 0.7)

    # 2. punch the window, then the window rim shading (partial alpha inside the window)
    cv.cut(win)
    sdf = cv.rrect_sdf(bw, bw, CW - bw, WIN_B, max(8, CARD_R - bw + 4))
    rim = np.exp(np.minimum(sdf, 0) / 10.0) * win
    cv.over(hexc("#05060F"), rim * 0.55)
    tierglow = np.exp(np.minimum(sdf, 0) / (5.0 + rank)) * win
    cv.over(hexc(cfg["glow"]), tierglow * (0.28 + 0.06 * rank))

    # 3. the border + divider bar, metal
    border = np.clip(outer - inner, 0, 1)
    div = cv.rrect(bw - 4, WIN_B - 2, CW - bw + 4, DIV_B, 4)
    frame_m = np.clip(np.maximum(border, div), 0, 1)
    noise = brushed(cv, 5, 0.05) if tier == "Common" else None
    glow(cv, frame_m, cfg["glow"], 4 + rank, 0.25 + 0.06 * rank) if rank >= 3 else None
    metal(cv, frame_m, cfg["metal"], width=min(9, bw * 0.4), env=0.14 + 0.02 * rank, holo=cfg.get("holo", False),
          noise=noise, contrast=1.1)
    # engraved groove along the border (rank >= 2), a fine inner trim line (all)
    if rank >= 2:
        g = bw / 2
        groove = np.clip(cv.rrect(g - 1.2, g - 1.2, CW - g + 1.2, CH - g + 1.2, CARD_R - g + 1)
                         - cv.rrect(g + 1.2, g + 1.2, CW - g - 1.2, CH - g - 1.2, CARD_R - g - 1), 0, 1)
        cv.multiply(hexc("#000000"), groove * 0.55)
        hl = np.roll(groove, S * 1, axis=0) * (1 - groove)
        cv.screen(hexc("#FFFFFF"), hl * 0.35)
    trim = np.clip(cv.rrect(bw - 3, bw - 3, CW - bw + 3, WIN_B + 1, CARD_R - bw + 6) - grow(win, 0.0), 0, 1)
    trim = np.clip(trim - (1 - cv.rrect(bw - 3, bw - 3, CW - bw + 3, WIN_B + 3, CARD_R - bw + 6)), 0, 1)
    trim *= 1 - win
    cv.over(hexc("#FFFFFF") * 0.3 + hexc(cfg["glow"]) * 0.7, trim * 0.85)

    # 4. tier ornaments
    _ornaments(cv, tier, cfg)

    # 5. ink outline at the very edge + clip to the card
    edge = np.clip(outer - cv.rrect(2.5, 2.5, CW - 2.5, CH - 2.5, CARD_R - 2.5), 0, 1)
    cv.over(hexc("#0D0F2B"), edge * 0.9)
    cv.clip_to(outer)
    return cv.image()


def _top_plaque(cv, cfg, w, h, stops, holo=False):
    cx, cy = CW / 2, cfg["bw"] / 2 + h * 0.18
    pts = [(cx - w / 2, cy - h / 2 + 8), (cx - w / 2 + 16, cy - h / 2), (cx + w / 2 - 16, cy - h / 2),
           (cx + w / 2, cy - h / 2 + 8), (cx + w / 2, cy + h / 2 - 12), (cx + w / 2 - 26, cy + h / 2),
           (cx - w / 2 + 26, cy + h / 2), (cx - w / 2, cy + h / 2 - 12)]
    m = cv.poly(pts)
    metal(cv, m, stops, width=5, holo=holo, shadow=0.7, shadow_off=(0, 4))
    inner = cv.poly([(x * 0.88 + cx * 0.12, y * 0.74 + cy * 0.26) for x, y in pts])
    flat_fill(cv, inner, cfg["plate"][0], cfg["plate"][1], cy - h / 2, cy + h / 2)
    cv.multiply(hexc("#000000"), blur(1 - inner, 2) * inner * 0.6)
    if KANJI_FONT:
        k = cv.text(cfg["kanji"], cx, cy - 1, h * 0.5)
        glow(cv, k, cfg["glow"], 3, 0.9)
        metal(cv, k, GOLD if not holo else SILVER, width=1.3, holo=holo, env=0.1)
    return cx, cy


def wings(cv, cx, cy, reach, stops, holo=False, droop=0.12, n=4):
    """Feathered wings either side of (cx, cy)."""
    feathers = []
    for side in (-1, 1):
        for i in range(n):
            ln = reach * (1 - i * 0.17)
            ang = droop + i * 0.2
            a = ang if side > 0 else math.pi - ang
            feathers.append(rot_pts(leaf_pts(ln, 7 + 1.5 * (n - i)), a, cx + side * 6, cy + i * 2))
    m = cv.polys(feathers)
    metal(cv, m, stops, width=3.5, holo=holo, shadow=0.6, shadow_off=(0, 3), env=0.22)
    return m


def sun_crest(cv, cx, cy, R, stops, holo=False, n=16):
    m = cv.poly(star_pts(cx, cy, R, R * 0.58, n=n, rot=-math.pi / 2))
    glow(cv, m, "#FFE08A" if not holo else "#FFFFFF", 6, 0.6)
    metal(cv, m, stops, width=5, holo=holo, shadow=0.6, shadow_off=(0, 3), contrast=1.2)


def _ornaments(cv, tier, cfg):
    bw = cfg["bw"]
    holo = cfg.get("holo", False)
    corners = corner_list(bw / 2 + 1)
    if tier == "Common":
        for cx, cy, sx, sy in corners:
            def f(pc, cx=cx, cy=cy, sx=sx, sy=sy):
                br = pc.poly([(cx, cy), (cx + sx * 40, cy), (cx + sx * 40, cy + sy * 5), (cx + sx * 5, cy + sy * 5),
                              (cx + sx * 5, cy + sy * 40), (cx, cy + sy * 40)])
                metal(pc, br, STEEL, width=2.5, shadow=0.45, shadow_off=(0, 1.5))
                metal(pc, pc.circle(cx + sx * 3, cy + sy * 3, 6), STEEL, width=3.5, shadow=0.5, shadow_off=(0, 1.5))
            corner_piece(cv, cx, cy, 56, f)
        for x in (CW * 0.25, CW * 0.5, CW * 0.75):
            metal(cv, cv.circle(x, DIV_Y, 3.6), STEEL, width=2)
    elif tier == "Uncommon":
        for cx, cy, sx, sy in corners:
            def f(pc, cx=cx, cy=cy, sx=sx, sy=sy):
                base = math.atan2(sy, sx)
                leaves = [rot_pts(leaf_pts(ln, wd), base + da, cx, cy)
                          for da, ln, wd in ((-0.6, 58, 11), (0.0, 76, 13), (0.6, 58, 11))]
                m = pc.polys(leaves)
                metal(pc, m, JADE, width=5, shadow=0.55, shadow_off=(1, 2), env=0.2)
                ribs = pc.pil(lambda d, P, k: [d.line([P(*q[0]), P(*q[len(q) // 2 - 1])], fill=255,
                                                      width=int(1.4 * k)) for q in leaves])
                pc.multiply(hexc("#0A3A22"), ribs * m * 0.6)
                _gem(pc, cx, cy, 8, "#3BE58A", "round", 8, GOLD, 0)
            corner_piece(cv, cx, cy, 92, f)
        gem(cv, CW / 2, DIV_Y, 9, "#3BE58A", shape="diamond", bezel=JADE)
        _top_plaque(cv, cfg, 120, 36, JADE)
    elif tier == "Rare":
        for cx, cy, sx, sy in corners:
            def f(pc, cx=cx, cy=cy, sx=sx, sy=sy):
                L = 96
                br = pc.poly([(cx, cy), (cx + sx * L, cy), (cx + sx * (L - 10), cy + sy * 10),
                              (cx + sx * 12, cy + sy * 10), (cx + sx * 10, cy + sy * (L - 10)), (cx, cy + sy * L)])
                metal(pc, br, SILVER, width=3.5, shadow=0.55)
                _gem(pc, cx + sx * 4, cy + sy * 4, 15, cfg["gemc"], "diamond", 8, SILVER, 0)
            corner_piece(cv, cx, cy, 110, f)
        for y in (150, 300):
            for x in (bw / 2, CW - bw / 2):
                gem(cv, x, y, 6, cfg["gemc"], bezel=SILVER)
        for x in (CW / 2 - 76, CW / 2 + 76):
            gem(cv, x, DIV_Y, 6, cfg["gemc"], bezel=SILVER)
        _top_plaque(cv, cfg, 150, 44, SILVER)
        gem(cv, CW / 2, DIV_Y, 12, cfg["gemc"], shape="diamond", bezel=SILVER)
    elif tier == "Epic":
        bolts = []
        for y in (110, 280):
            bolts.append(bolt_pts(bw / 2 - 9, y, 100, 30))
            bolts.append(bolt_pts(CW - bw / 2 + 9, y, 100, 30, flip=True))
        bm = cv.polys(bolts)
        glow(cv, bm, "#E879F9", 8, 1.0)
        metal(cv, bm, [(0, "#7C2DD6"), (0.5, "#E9C6FF"), (1, "#FFFFFF")], width=3, env=0.1)
        for cx, cy, sx, sy in corners:
            def f(pc, cx=cx, cy=cy, sx=sx, sy=sy):
                base = math.atan2(sy, sx)
                shards = [shard_pts(cx - sx * 6, cy - sy * 6, ln, wd, base + da)
                          for da, ln, wd in ((-0.95, 50, 13), (-0.48, 86, 20), (0.0, 122, 28), (0.48, 86, 20),
                                             (0.95, 50, 13))]
                sm = pc.polys(shards)
                glow(pc, sm, "#C084FC", 8, 0.9)
                metal(pc, sm, [(0, "#2A0752"), (0.35, "#7B2CE0"), (0.65, "#C79BFF"), (0.9, "#F4E6FF"),
                               (1, "#FFFFFF")], width=7, env=0.25, contrast=1.5)
            corner_piece(cv, cx, cy, 140, f)
        sh = cv.polys([shard_pts(CW / 2 - 70, 26, 46, 16, math.pi + 0.25), shard_pts(CW / 2 + 70, 26, 46, 16, -0.25)])
        glow(cv, sh, "#C084FC", 6, 0.8)
        metal(cv, sh, AMETHYST, width=5, contrast=1.4)
        _top_plaque(cv, cfg, 160, 48, AMETHYST)
        for x in (CW / 2 - 80, CW / 2 + 80):
            gem(cv, x, DIV_Y, 7, cfg["gemc"], bezel=AMETHYST)
        gem(cv, CW / 2, DIV_Y, 14, cfg["gemc"], shape="hex", bezel=AMETHYST, rot=math.pi / 6)
    elif tier in ("Legendary", "Mythic"):
        st = GOLD if tier == "Legendary" else SILVER
        if tier == "Legendary":
            ang = np.arctan2(cv.y - 30, cv.x - CW / 2)
            rad = np.hypot(cv.x - CW / 2, cv.y - 30)
            rays = (np.cos(ang * 22) * 0.5 + 0.5) ** 6 * np.exp(-rad / 70) * (cv.y > 30)
            cv.over(hexc("#FFE9A0"), np.clip(rays * 1.3, 0, 1) * 0.6)
        for cx, cy, sx, sy in corners:
            def f(pc, cx=cx, cy=cy, sx=sx, sy=sy):
                fm = filigree(pc, cx, cy, sx, sy, 112, 9)
                metal(pc, fm, st, width=3.8, holo=holo, shadow=0.65, shadow_off=(1, 3), env=0.22)
                if tier == "Mythic":
                    sm = pc.poly(star_pts(cx + sx * 4, cy + sy * 4, 36, 10, n=4, rot=0))
                    glow(pc, sm, "#FFFFFF", 6, 1.0)
                    metal(pc, sm, SILVER, width=5, holo=True, contrast=1.3)
                    _gem(pc, cx + sx * 4, cy + sy * 4, 9, "#C6F8FF", "round", 8, None, 0)
                else:
                    _gem(pc, cx + sx * 4, cy + sy * 4, 16, cfg["gemc"], "round", 10, GOLD, 0)
            corner_piece(cv, cx, cy, 150, f)
        for y in (180, 300, 560):
            for x in (bw / 2, CW - bw / 2):
                gem(cv, x, y, 6, cfg["gemc"] if tier == "Legendary" else "#FFA6F4", bezel=st)
        sun_crest(cv, CW / 2, 30, 56, st, holo=holo)
        wings(cv, CW / 2, 34, 130, st, holo=holo)
        if tier == "Mythic":
            sp = sparkles(cv, [(92, 150, 18), (430, 120, 13), (440, 360, 20), (70, 380, 12), (330, 92, 10),
                               (150, 640, 10), (390, 520, 9)])
            glow(cv, sp, "#B6F3FF", 4, 0.8)
            cv.over(hexc("#FFFFFF"), sp)
        _top_plaque(cv, cfg, 170, 52, st, holo=holo)
        wings(cv, CW / 2, DIV_Y + 2, 74, st, holo=holo, droop=-0.05, n=3)
        if tier == "Legendary":
            gem(cv, CW / 2, DIV_Y, 16, cfg["gemc"], shape="oval", bezel=GOLD)
        else:
            gem(cv, CW / 2, DIV_Y, 15, "#C6F8FF", shape="diamond", bezel=SILVER)
    elif tier == "Secret":
        runes = "封印魔闇血呪鬼影冥滅"
        rm = np.zeros(cv.x.shape, np.float32)
        if KANJI_FONT:
            for i in range(5):
                rm = np.maximum(rm, cv.text(runes[i], bw / 2, 130 + i * 100, 22))
                rm = np.maximum(rm, cv.text(runes[5 + i], CW - bw / 2, 130 + i * 100, 22))
        glow(cv, rm, "#FF1F4B", 5, 1.0)
        glow(cv, rm, "#B026FF", 12, 0.7)
        cv.over(hexc("#FFD0DA"), rm)
        for cx, cy, sx, sy in corners:
            def f(pc, cx=cx, cy=cy, sx=sx, sy=sy):
                base = math.atan2(sy, sx)
                spikes = [shard_pts(cx - sx * 2, cy - sy * 2, ln, wd, base + da)
                          for da, ln, wd in ((-0.9, 44, 12), (-0.45, 70, 16), (0.0, 112, 20), (0.45, 70, 16),
                                             (0.9, 44, 12))]
                sm = pc.polys(spikes)
                glow(pc, sm, "#FF1F4B", 9, 1.0)
                metal(pc, sm, VOID, width=5, env=0.3, contrast=1.5)
                _gem(pc, cx + sx * 3, cy + sy * 3, 11, cfg["gemc"], "round", 8, VOID, 0)
            corner_piece(cv, cx, cy, 135, f)
        horns = cv.polys([shard_pts(CW / 2 - 80, 28, 70, 18, math.pi - 0.35),
                          shard_pts(CW / 2 + 80, 28, 70, 18, 0.35)])
        glow(cv, horns, "#FF1F4B", 7, 0.9)
        metal(cv, horns, VOID, width=5, contrast=1.5)
        _top_plaque(cv, cfg, 170, 52, VOID)
        eye = ell(cv, CW / 2 - 30, DIV_Y - 15, CW / 2 + 30, DIV_Y + 15)
        glow(cv, eye, "#FF1F4B", 8, 1.0)
        metal(cv, eye, VOID, width=4)
        gem(cv, CW / 2, DIV_Y, 9, "#FF1F4B")
        pup = cv.rrect(CW / 2 - 1.6, DIV_Y - 8, CW / 2 + 1.6, DIV_Y + 8, 1.6)
        cv.over(hexc("#14020A"), pup)
    elif tier == "Premium":
        for cx, cy, sx, sy in corners:
            def f(pc, cx=cx, cy=cy, sx=sx, sy=sy):
                base = math.atan2(sy, sx)
                lv = pc.polys([rot_pts(leaf_pts(46, 9), base + da, cx, cy) for da in (-0.75, 0.75)])
                metal(pc, lv, ROSE, width=3, shadow=0.4)
                fl = [sakura_pts(cx + sx * 8, cy + sy * 8, 36, 0.3), sakura_pts(cx + sx * 58, cy + sy * 12, 18, 1.1),
                      sakura_pts(cx + sx * 12, cy + sy * 58, 18, 2.0), sakura_pts(cx + sx * 86, cy + sy * 6, 10, 0.6),
                      sakura_pts(cx + sx * 6, cy + sy * 86, 10, 1.6)]
                fm = pc.polys(fl)
                glow(pc, fm, "#FFB3D6", 7, 0.85)
                metal(pc, fm, [(0, "#B0346F"), (0.45, "#FF8FC2"), (0.75, "#FFD6EA"), (1, "#FFFFFF")], width=7,
                      env=0.12, shadow=0.55, shadow_off=(1, 2))
                _gem(pc, cx + sx * 8, cy + sy * 8, 8, "#FFE36B", "round", 8, ROSE, 0)
            corner_piece(cv, cx, cy, 125, f)
        sm = cv.polys([sakura_pts(CW / 2 - 98, 26, 16, 0.4), sakura_pts(CW / 2 + 98, 26, 16, 1.0)])
        glow(cv, sm, "#FFB3D6", 5, 0.8)
        metal(cv, sm, ROSE, width=5)
        _top_plaque(cv, cfg, 170, 52, ROSE)
        wings(cv, CW / 2, DIV_Y + 2, 64, ROSE, droop=-0.05, n=3)
        gem(cv, CW / 2, DIV_Y, 14, cfg["gemc"], shape="oval", bezel=ROSE)


# ============================================================================ card back

def card_back():
    cv = Cv(CW, CH)
    bw = 30
    outer = cv.rrect(0, 0, CW, CH, CARD_R)
    cx, cy = CW / 2, CH / 2
    rad = np.hypot(cv.x - cx, cv.y - cy)
    t = np.clip(rad / 430, 0, 1)
    col = ramp([(0, "#3B36B8"), (0.35, "#22207A"), (0.75, "#121347"), (1, "#080A26")], t)
    cv.over(col, outer)
    inner = cv.rrect(bw, bw, CW - bw, CH - bw, CARD_R - bw + 8)
    cv.over(hexc("#7F8CFF"), seigaiha(cv, 30, 0, 0, rings=4, line=1.4) * inner * 0.1)
    cv.over(hexc("#FFFFFF"), speed_lines(cv, cx, cy, n=200, r0=150, seed=7) * inner * 0.16)
    cv.over(hexc("#8E8CFF"), halftone(cv, 11, 3.4 * smooth(180, 420, rad)) * inner * 0.3)
    # inner gold rule + inner glow under the border
    rule = np.clip(cv.rrect(bw + 10, bw + 10, CW - bw - 10, CH - bw - 10, 18)
                   - cv.rrect(bw + 12.5, bw + 12.5, CW - bw - 12.5, CH - bw - 12.5, 16), 0, 1)
    metal(cv, rule, GOLD, width=1)
    edge = np.exp(np.minimum(cv.rrect_sdf(bw, bw, CW - bw, CH - bw, CARD_R - bw + 8), 0) / 14) * inner
    cv.over(hexc("#6E7BFF"), edge * 0.45)
    # emblem: glow, 8-point star, ring, onigiri
    glow(cv, cv.circle(cx, cy, 120), "#8C7DFF", 24, 0.85)
    s8 = np.maximum(cv.poly(star_pts(cx, cy, 160, 70, n=8, rot=-math.pi / 2)),
                    cv.poly(star_pts(cx, cy, 118, 60, n=8, rot=-math.pi / 2 + math.pi / 8)))
    metal(cv, s8, GOLD, width=10, shadow=0.7, shadow_off=(0, 5), env=0.2, contrast=1.15)
    metal(cv, cv.circle(cx, cy, 98), GOLD, width=8, shadow=0.5, shadow_off=(0, 3))
    disc = cv.circle(cx, cy, 86)
    cv.over(ramp([(0, "#2D2A9A"), (1, "#0D0C3A")], np.clip(np.hypot(cv.x - cx, cv.y - cy + 30) / 110, 0, 1)), disc)
    cv.multiply(hexc("#000000"), blur(1 - disc, 4) * disc * 0.8)
    cv.over(hexc("#FFFFFF"), speed_lines(cv, cx, cy, n=60, r0=30, r1=84, seed=8) * disc * 0.18)
    # onigiri: a rounded triangle, rice white with a soft blue shade, nori band at the base
    oy = cy + 8
    tri = [(cx, oy - 70), (cx + 66, oy + 46), (cx - 66, oy + 46)]
    oni = grow(cv.poly(tri), 0)
    oni = np.clip(blur(oni, 7) * 2.2 - 0.6, 0, 1)  # rounded corners
    diff, spec, n, d = bevel(oni, 14, soften=1.2)
    rice = ramp([(0, "#9FA8E8"), (0.55, "#E8ECFF"), (1, "#FFFFFF")], 0.6 + (diff - LIGHT[2]) * 1.2)
    cv.over(hexc("#000000"), np.roll(blur(oni, 4), 6 * S, 0) * 0.5)
    cv.over(rice, oni)
    grains = halftone(cv, 7, 1.0) * oni * 0.12
    cv.multiply(hexc("#7C86C8"), grains)
    nori = cv.rrect(cx - 36, oy + 4, cx + 36, oy + 60, 6) * oni
    cv.over(ramp([(0, "#0B1A12"), (0.6, "#1D3A2A"), (1, "#3A5E48")], 0.4 + (diff - LIGHT[2]) * 1.5), nori)
    cv.over(hexc("#FFFFFF"), cv.rrect(cx - 30, oy + 8, cx - 22, oy + 52, 3) * nori * 0.22)
    hl = ell(cv, cx - 40, oy - 50, cx - 8, oy - 14)
    cv.over(hexc("#FFFFFF"), blur(hl, 3) * oni * 0.8)
    # sparkles round the crest
    sp = sparkles(cv, [(cx - 128, cy - 132, 18), (cx + 136, cy - 110, 13), (cx + 120, cy + 140, 16),
                       (cx - 140, cy + 118, 11), (cx, cy - 196, 12), (cx, cy + 196, 12)])
    glow(cv, sp, "#AFC3FF", 4, 0.8)
    cv.over(hexc("#FFFFFF"), sp)
    # bottom cartouche with the mystery kanji, small top one with a star
    for (py, txt, w) in ((CH - bw - 46, "謎", 96), (bw + 46, None, 70)):
        pm = cv.rrect(cx - w / 2, py - 20, cx + w / 2, py + 20, 20)
        metal(cv, pm, GOLD, width=5, shadow=0.6)
        inn = cv.rrect(cx - w / 2 + 5, py - 15, cx + w / 2 - 5, py + 15, 15)
        flat_fill(cv, inn, "#2A2790", "#121246", py - 15, py + 15)
        if txt and KANJI_FONT:
            km = cv.text(txt, cx, py - 1, 24)
            glow(cv, km, "#9EA8FF", 3, 0.8)
            metal(cv, km, GOLD, width=1.2)
        else:
            sm = cv.poly(star_pts(cx, py, 13, 5.5))
            metal(cv, sm, GOLD, width=2)
    # border, corners
    border = np.clip(outer - inner, 0, 1)
    glow(cv, border, "#FFD45C", 4, 0.3)
    metal(cv, border, GOLD, width=11, env=0.2, contrast=1.1)
    g = bw / 2
    groove = np.clip(cv.rrect(g - 1.2, g - 1.2, CW - g + 1.2, CH - g + 1.2, CARD_R - g + 1)
                     - cv.rrect(g + 1.2, g + 1.2, CW - g - 1.2, CH - g - 1.2, CARD_R - g - 1), 0, 1)
    cv.multiply(hexc("#000000"), groove * 0.5)
    for ccx, ccy, sx, sy in corner_list(bw / 2 + 2):
        def f(pc, ccx=ccx, ccy=ccy, sx=sx, sy=sy):
            fm = filigree(pc, ccx, ccy, sx, sy, 100, 8)
            metal(pc, fm, GOLD, width=3.5, shadow=0.6, shadow_off=(1, 2.5), env=0.2)
            _gem(pc, ccx + sx * 4, ccy + sy * 4, 14, "#4F7BFF", "round", 10, GOLD, 0)
        corner_piece(cv, ccx, ccy, 135, f)
    for y in (CH * 0.3, CH * 0.5, CH * 0.7):
        for x in (bw / 2, CW - bw / 2):
            gem(cv, x, y, 5, "#4F7BFF", bezel=GOLD)
    edge = np.clip(outer - cv.rrect(2.5, 2.5, CW - 2.5, CH - 2.5, CARD_R - 2.5), 0, 1)
    cv.over(hexc("#0D0F2B"), edge * 0.9)
    cv.clip_to(outer)
    return cv.image()


# ============================================================================ banners

def ribbon(w, h, fill, trim_stops, holo=False, gems=None, stars=False, tail=0.17, glowc=None, crest=False):
    cv = Cv(w, h)
    band_y0, band_y1 = (h * 0.24, h * 0.84) if crest else (h * 0.1, h * 0.78)
    tw = w * tail
    # tails (behind, lower, darker), with a swallowtail notch
    ty0, ty1 = (band_y0 + h * 0.18, min(h * 0.99, band_y1 + h * 0.16))
    tails = [[(0, ty0), (tw + 8, ty0), (tw + 8, ty1), (0, ty1), (tw * 0.38, (ty0 + ty1) / 2)],
             [(w, ty0), (w - tw - 8, ty0), (w - tw - 8, ty1), (w, ty1), (w - tw * 0.38, (ty0 + ty1) / 2)]]
    tm = cv.polys(tails)
    cv.over(hexc("#000000"), np.roll(blur(tm, 2), 2 * S, 0) * 0.45)
    if holo:
        dark = hsv_arr(cv.x / w + 0.55, 0.55, 0.55)
        cv.over(dark, tm)
    else:
        flat_fill(cv, tm, _shade(fill[1], 0.8), _shade(fill[1], 0.5), ty0, ty1)
    tedge = np.clip(tm - _erode(tm, 2.5), 0, 1)
    metal(cv, tedge, trim_stops, width=1.2, holo=holo)
    # folds
    folds = cv.polys([[(tw, band_y1 - 2), (tw + 8, band_y1 - 2), (tw + 8, ty1)],
                      [(w - tw, band_y1 - 2), (w - tw - 8, band_y1 - 2), (w - tw - 8, ty1)]])
    cv.over(hexc("#000000"), folds * 0.85)
    # the band
    bx0, bx1 = tw - 2, w - tw + 2
    band = cv.rrect(bx0, band_y0, bx1, band_y1, 6)
    cv.over(hexc("#000000"), np.roll(blur(band, 3), 3 * S, 0) * 0.5)
    if holo:
        hue = cv.x / w * 1.1 + cv.y / h * 0.15
        col = hsv_arr(hue, 0.5, 1.0)
        v = 1 - 0.35 * np.clip((cv.y - band_y0) / (band_y1 - band_y0), 0, 1)
        cv.over(col * v[..., None], band)
    else:
        flat_fill(cv, band, fill[0], fill[1], band_y0, band_y1)
    # subtle texture + gloss + trim
    cv.over(hexc("#FFFFFF"), halftone(cv, 6, 1.0 * smooth(band_y0 + 10, band_y1, cv.y)) * band * 0.08)
    stripes = (np.sin((cv.x + cv.y) / 9.0) > 0.55).astype(np.float32)
    cv.over(hexc("#FFFFFF"), ndi.gaussian_filter(stripes, 0.5 * S) * band * 0.06)
    gl = cv.rrect(bx0 + 6, band_y0 + 4, bx1 - 6, band_y0 + (band_y1 - band_y0) * 0.42, 5)
    cv.over(hexc("#FFFFFF"), gl * smooth(band_y0 + (band_y1 - band_y0) * 0.45, band_y0, cv.y) * 0.32)
    trim_h = max(3.5, h * 0.06)
    trim = np.maximum(cv.rrect(bx0, band_y0, bx1, band_y0 + trim_h, 2), cv.rrect(bx0, band_y1 - trim_h, bx1,
                                                                                band_y1, 2))
    metal(cv, trim, trim_stops, width=1.6, holo=holo, env=0.2)
    endcap = np.maximum(cv.rrect(bx0 - 2, band_y0 - 2, bx0 + trim_h + 2, band_y1 + 2, 3),
                        cv.rrect(bx1 - trim_h - 2, band_y0 - 2, bx1 + 2, band_y1 + 2, 3))
    metal(cv, endcap, trim_stops, width=2, holo=holo, env=0.2, shadow=0.4)
    if glowc:
        rim = np.exp(np.minimum(cv.rrect_sdf(bx0, band_y0, bx1, band_y1, 6), 0) / 4) * band
        cv.over(hexc(glowc), rim * 0.6)
    my = (band_y0 + band_y1) / 2
    if gems:
        for gx in (bx0 + trim_h + h * 0.2, bx1 - trim_h - h * 0.2):
            gem(cv, gx, my, h * 0.09, gems, bezel=trim_stops)
    if crest:
        ccx, ccy = w / 2, band_y0 + 2
        burst = cv.poly(star_pts(ccx, ccy, h * 0.3, h * 0.17, n=12, rot=-math.pi / 2))
        glow(cv, burst, "#FFE08A", 6, 0.8)
        metal(cv, burst, GOLD, width=4, shadow=0.6, shadow_off=(0, 3), contrast=1.2)
        disc = cv.circle(ccx, ccy, h * 0.15)
        flat_fill(cv, disc, fill[0], fill[1], ccy - h * 0.15, ccy + h * 0.15)
        st = cv.poly(star_pts(ccx, ccy, h * 0.12, h * 0.05))
        metal(cv, st, GOLD, width=2.5)
        sp = sparkles(cv, [(ccx - h * 0.42, ccy - h * 0.08, h * 0.08), (ccx + h * 0.4, ccy - h * 0.12, h * 0.06)])
        cv.over(hexc("#FFFFFF"), sp)
    if stars:  # sparkles only: the band stays clear for the title text
        sp = sparkles(cv, [(bx0 + 30, band_y0 + 4, 9), (bx1 - 60, band_y1 - 2, 7), (w * 0.62, band_y0, 6),
                           (w * 0.3, band_y1, 5)])
        cv.over(hexc("#FFFFFF"), sp)
    return cv


def _shade(hx, k):
    c = hexc(hx) * k
    return "#%02X%02X%02X" % tuple(int(round(v * 255)) for v in c)


def _erode(mask, px):
    d = ndi.distance_transform_edt(mask > 0.5) / S
    return np.clip(d - px + 0.5, 0, 1)


def card_banner(tier):
    cfg = TIERS[tier]
    trim = {"Common": STEEL, "Uncommon": GOLD, "Rare": SILVER, "Epic": GOLD, "Legendary": GOLD,
            "Mythic": SILVER, "Secret": VOID, "Premium": ROSE}[tier]
    fill = cfg["banner"] or ("#FFFFFF", "#FFFFFF")
    gems = cfg.get("gemc") if cfg["rank"] >= 2 else None
    cv = ribbon(420, 96, fill, trim, holo=cfg.get("holo", False), gems=gems, tail=0.13,
                glowc={"Secret": "#FF1F4B", "Mythic": "#FFFFFF", "Legendary": "#FFD45C"}.get(tier))
    return cv.image()


def celebrate_banner():
    cv = ribbon(760, 150, ("#FF6A4A", "#C8183E"), GOLD, gems="#FF2A3C", stars=True, tail=0.13, glowc="#FFD45C",
                crest=True)
    return cv.image()


# ============================================================================ overlays / backdrops

def card_foil():
    cv = Cv(CW, CH)
    outer = cv.rrect(0, 0, CW, CH, CARD_R)
    u = (cv.x + cv.y * 0.62)
    band = np.zeros(cv.x.shape, np.float32)
    for c, wd, a in ((360, 70, 0.55), (470, 22, 0.75), (250, 30, 0.35), (560, 50, 0.3)):
        band += np.exp(-((u - c) / wd) ** 2) * a
    hue = u / 260 + cv.y / 1400
    col = hsv_arr(hue, 0.55, 1.0)
    fine = 0.75 + 0.25 * np.sin(u * 0.55)
    cv.over(col, np.clip(band * fine, 0, 0.6) * outer)
    sp = sparkles(cv, [(140, 330, 16), (300, 220, 10), (220, 520, 13), (380, 160, 8), (90, 520, 7),
                       (420, 300, 11), (330, 420, 7)])
    cv.over(hexc("#FFFFFF"), sp * outer * 0.95)
    cv.over(hexc("#FFFFFF"), star_field(cv, 70, 5, 0.5, 1.2) * np.clip(band, 0, 1) * outer)
    return cv.image()


def window_shade():
    cv = Cv(CW, CH)
    sdf = cv.rrect_sdf(20, 20, CW - 20, WIN_B, 18)
    inside = cv.rrect(20, 20, CW - 20, WIN_B, 18)
    # a rim vignette: dark at the window's edge, fading to nothing a few dozen px in, so the hero in the middle
    # keeps its full colour (owner's review: the portraits read dark; the first version had the falloff inverted,
    # 60% ink over the face and less at the edge)
    v = np.exp(np.minimum(sdf, 0) / 26)
    lower = smooth(380, WIN_B, cv.y)
    cv.over(hexc("#06071A"), np.clip(v * 0.5 + lower * 0.22, 0, 0.6) * inside)
    return cv.image()


def portrait_bg():
    w, h = 512, 420
    cv = Cv(w, h)
    cx, cy = w / 2, h * 0.46
    rad = np.hypot(cv.x - cx, cv.y - cy)
    base = ramp([(0, "#FFFFFF"), (0.45, "#C9C9D6"), (1, "#5A5A6E")], rad / 330)
    cv.over(base, np.ones(cv.x.shape, np.float32))
    cv.over(hexc("#FFFFFF"), speed_lines(cv, cx, cy, n=150, r0=70, seed=12) * 0.55)
    cv.over(hexc("#2A2A3A"), halftone(cv, 9, 2.6 * smooth(170, 330, rad)) * 0.35)
    cv.over(hexc("#FFFFFF"), np.exp(-(rad / 120) ** 2) * 0.8)
    return cv.image()


def celebrate_backdrop():
    w, h = 1280, 720
    cv = Cv(w, h)
    cx, cy = w / 2, h * 0.42
    rad = np.hypot(cv.x - cx, cv.y - cy)
    base = ramp([(0, "#4B2FA8"), (0.25, "#2A1B6E"), (0.6, "#120E3C"), (1, "#05061A")], rad / 760)
    cv.over(base, np.ones(cv.x.shape, np.float32))
    ang = np.arctan2(cv.y - cy, cv.x - cx)
    rays = (np.sin(ang * 14) * 0.5 + 0.5) ** 3
    cv.over(hexc("#8F7BFF"), rays * smooth(40, 200, rad) * np.exp(-rad / 520) * 0.35)
    cv.over(hexc("#FFFFFF"), speed_lines(cv, cx, cy, n=260, r0=220, seed=31, width=(0.05, 0.3)) * 0.14)
    cv.over(hexc("#9A8CFF"), halftone(cv, 14, 4.2 * smooth(380, 760, rad)) * 0.18)
    cv.over(hexc("#FFE6A8"), np.exp(-(rad / 210) ** 2) * 0.45)
    rng = np.random.default_rng(41)
    for _ in range(46):
        bx, by = rng.uniform(0, w), rng.uniform(0, h)
        br = rng.uniform(6, 26)
        colr = ["#FFD45C", "#FF7AB6", "#7FD4FF", "#C9A8FF", "#FFFFFF"][rng.integers(0, 5)]
        m = cv.circle(bx, by, br)
        cv.over(hexc(colr), blur(m, br * 0.25) * rng.uniform(0.08, 0.3))
        cv.over(hexc(colr), cv.ring(bx, by, br, 1.2) * rng.uniform(0.05, 0.15))
    cv.over(hexc("#FFFFFF"), star_field(cv, 160, 42, 0.5, 1.4) * 0.8)
    vig = smooth(380, 820, np.hypot((cv.x - cx) * 0.9, (cv.y - cy) * 1.4))
    cv.over(hexc("#020310"), vig * 0.8)
    return cv.image()


# ============================================================================ upload

MAP = ROOT / "assets" / "ui" / "ids_cards.json"
UPLOAD = Path.home() / ".claude" / "skills" / "roblox-3d-model" / "scripts" / "upload_asset.py"


def upload(force=False) -> int:
    ids = json.loads(MAP.read_text(encoding="utf-8")) if MAP.exists() else {}
    fails = []
    for png in sorted(OUT.glob("*.png")):
        key = png.stem
        if key == "sheet" or (key in ids and not force):
            continue
        r = subprocess.run([sys.executable, str(UPLOAD), "--file", str(png), "--name", f"TFA_{key}",
                            "--asset-type", "Image"], capture_output=True, text=True)
        m = re.search(r"assetId=(\d+)", r.stdout)
        if not m:
            fails.append(key)
            print(f"FAIL {key}: {(r.stdout + r.stderr)[-300:]}")
            continue
        ids[key] = int(m.group(1))
        MAP.write_text(json.dumps(ids, indent=2) + "\n", encoding="utf-8")
        print(f"ok   {key} {ids[key]}")
    return 1 if fails else 0



# ============================================================================ driver

def build_all():
    jobs = {"CardBack": card_back, "CardFoil": card_foil, "CardWindowShade": window_shade,
            "CardPortraitBg": portrait_bg, "CelebrateBackdrop": celebrate_backdrop,
            "CelebrateBanner": celebrate_banner}
    for t in TIER_ORDER:
        jobs[f"CardFrame_{t}"] = (lambda t=t: card_frame(t))
        jobs[f"CardBanner_{t}"] = (lambda t=t: card_banner(t))
    return jobs


def compose_card(tier, name="First Sun Swordsman", show_foil=False, hero=None):
    """A preview composite of the reveal card at full art size: portrait bg (tinted), window shade, frame, banner
    with the tier word, the name. Hero = an optional RGBA image dropped in the window."""
    card = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    bg = Image.open(OUT / "CardPortraitBg.png").convert("RGBA").resize((CW - 60, WIN_B - 30))
    tint = TINT[tier]
    r, g, b = (int(tint[i:i + 2], 16) for i in (1, 3, 5))
    lum = bg.convert("L")
    bg = Image.merge("RGBA", [lum.point(lambda v, c=c: int(v * c / 255)) for c in (r, g, b)]
                     + [Image.new("L", bg.size, 255)])
    card.alpha_composite(bg, (30, 30))
    if hero is not None:
        card.alpha_composite(hero, ((CW - hero.width) // 2, WIN_B - hero.height))
    card.alpha_composite(Image.open(OUT / "CardWindowShade.png").convert("RGBA"))
    card.alpha_composite(Image.open(OUT / f"CardFrame_{tier}.png").convert("RGBA"))
    ban = Image.open(OUT / f"CardBanner_{tier}.png").convert("RGBA")
    card.alpha_composite(ban, ((CW - ban.width) // 2, BANNER_CY - ban.height // 2))
    d = ImageDraw.Draw(card)
    f1 = ImageFont.truetype(str(LABEL_FONT), 34)
    f2 = ImageFont.truetype(str(LABEL_FONT), 38)
    d.text((CW / 2, 640), tier.upper(), font=f1, fill="white", anchor="mm", stroke_width=4,
           stroke_fill="#0D0F2B")
    d.text((CW / 2, 530), name, font=f2, fill="white", anchor="mm", stroke_width=5, stroke_fill="#0D0F2B")
    if show_foil:
        card.alpha_composite(Image.open(OUT / "CardFoil.png").convert("RGBA"))
    return card


# tints for CardPortraitBg per tier (the client uses the same; listed in the report)
TINT = {"Common": "#B9C3D3", "Uncommon": "#7EE8AE", "Rare": "#7DBBFF", "Epic": "#C69BFF", "Legendary": "#FFCB6B",
        "Mythic": "#FFB0F2", "Secret": "#B0306A", "Premium": "#FF9CC8"}


def contact_sheet(names):
    tiles = []
    for n in names:
        p = OUT / f"{n}.png"
        if p.exists():
            tiles.append((n, Image.open(p).convert("RGBA")))
    tw, th = 300, 420
    cols = 5
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * (tw + 20) + 20, rows * (th + 50) + 20), (30, 34, 60, 255))
    chk = Image.new("RGBA", (tw, th), (58, 62, 92, 255))
    cd = ImageDraw.Draw(chk)
    for yy in range(0, th, 20):
        for xx in range(0, tw, 20):
            if (xx // 20 + yy // 20) % 2:
                cd.rectangle([xx, yy, xx + 19, yy + 19], fill=(74, 78, 110, 255))
    d = ImageDraw.Draw(sheet)
    font = ImageFont.truetype(str(LABEL_FONT), 20)
    for i, (n, im) in enumerate(tiles):
        x = 20 + (i % cols) * (tw + 20)
        y = 20 + (i // cols) * (th + 50)
        sheet.alpha_composite(chk, (x, y + 30))
        sc = min(tw / im.width, th / im.height)
        t = im.resize((max(1, round(im.width * sc)), max(1, round(im.height * sc))), Image.LANCZOS)
        sheet.alpha_composite(t, (x + (tw - t.width) // 2, y + 30 + (th - t.height) // 2))
        d.text((x, y), n, font=font, fill="white")
    sheet.convert("RGB").save(OUT / "sheet.png")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default=None)
    ap.add_argument("--preview", action="store_true")
    ap.add_argument("--upload", action="store_true", help="upload textures with no id yet -> assets/ui/ids_cards.json")
    ap.add_argument("--upload-only", action="store_true")
    ap.add_argument("--force", action="store_true", help="with --upload: re-upload everything (new ids)")
    a = ap.parse_args()
    if a.upload_only:
        return upload(a.force)
    OUT.mkdir(parents=True, exist_ok=True)
    jobs = build_all()
    only = set(a.only.split(",")) if a.only else None
    for name, fn in jobs.items():
        if only and name not in only:
            continue
        im = fn()
        im.save(OUT / f"{name}.png")
        print("wrote", name, im.size)
    order = ["CardBack"] + [f"CardFrame_{t}" for t in TIER_ORDER] + ["CardFoil", "CardWindowShade",
                                                                     "CardPortraitBg"]
    contact_sheet(order)
    if a.preview:
        PREVIEW.mkdir(parents=True, exist_ok=True)
        cards = [compose_card(t) for t in TIER_ORDER]
        w = 8 * 260 + 20
        strip = Image.new("RGBA", (w, 400), (20, 22, 48, 255))
        for i, c in enumerate(cards):
            strip.alpha_composite(c.resize((250, 350), Image.LANCZOS), (15 + i * 260, 25))
        strip.convert("RGB").save(PREVIEW / "tiers_strip.png")
        bans = Image.new("RGBA", (2 * 440 + 20, 4 * 110 + 200), (30, 34, 60, 255))
        for i, t in enumerate(TIER_ORDER):
            b = Image.open(OUT / f"CardBanner_{t}.png")
            bans.alpha_composite(b, (10 + (i % 2) * 440, 10 + (i // 2) * 110))
        cb = Image.open(OUT / "CelebrateBanner.png")
        bans.alpha_composite(cb.resize((570, 112)), (10, 4 * 110 + 30))
        bans.convert("RGB").save(PREVIEW / "banners.png")
        print("previews in", PREVIEW)
    if a.upload:
        return upload(a.force)
    return 0


if __name__ == "__main__":
    sys.exit(main())
