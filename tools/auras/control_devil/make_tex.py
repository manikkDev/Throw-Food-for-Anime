#!/usr/bin/env python3
"""ControlDevil (Makima, "Control Devil") aura textures, made from maths: nothing harvested.

    python tools/auras/control_devil/make_tex.py      -> assets/auras/control_devil/*.png (+ _sheet.jpg)

No flame tongues (the owner's brief). Makima's own language: her ringed golden eyes, and chains that are
leashes to her dogs.

  gaze_sigil.png   ground: her iris as a sigil, concentric gold and amber rings on a dark crimson disc
                   (the dark disc is what reads on her pink stand), a ring of chain links at the rim
  halo.png         the same ringed iris as an open halo behind her head (rings only, no filled disc)
  chain.png        beam strip (saved UPRIGHT: Roblox runs a beam texture's vertical axis along the beam),
                   tiles along the beam: dark iron links, face-on and edge-on in turn, gold glints
  dog_l.png        one of her dogs, sitting, in profile facing left: black, crimson rim, a ringed gold eye,
  dog_r.png        a gold collar ring where the leash hooks on (dog_r is the mirror, facing right)
  ring_pulse.png   a thin gold ring (laid flat, grows and fades: ripples of her gaze)
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets" / "auras" / "control_devil"

GOLD = np.array([255, 196, 52], float)
AMBER = np.array([214, 120, 18], float)
UMBER = np.array([92, 40, 8], float)
INK = np.array([12, 6, 10], float)
CRIM = np.array([170, 16, 32], float)
IRON = np.array([44, 40, 46], float)


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def to_img(rgba):
    return Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), "RGBA")


def polar(N):
    yy, xx = np.mgrid[-1:1:N * 1j, -1:1:N * 1j]
    return np.hypot(xx, yy), np.arctan2(yy, xx), xx, yy


def band(r, r0, w):
    """an antialiased ring of half-width w at radius r0"""
    return smooth(w + 0.004, w - 0.004, np.abs(r - r0))


IRIS = [  # (radius, half width, colour): her iris from the pupil out, thin rings, gold and amber in turn
    (0.19, 0.016, GOLD), (0.245, 0.012, AMBER), (0.30, 0.014, GOLD), (0.355, 0.011, AMBER),
    (0.41, 0.013, GOLD), (0.465, 0.010, AMBER), (0.52, 0.012, GOLD), (0.575, 0.009, AMBER),
    (0.63, 0.011, GOLD), (0.685, 0.016, UMBER),
]

def gaze_sigil(N=1024):
    r, th, xx, yy = polar(N)
    col = np.zeros((N, N, 3))
    col[:] = INK * 0.6 + CRIM * 0.15
    a = smooth(0.90, 0.86, r) * 0.88  # the dark disc
    # depth: a faint crimson glow rising toward the rim of the disc
    lift = smooth(0.2, 0.86, r)[..., None] * 0.35
    col = col * (1 - lift) + CRIM * 0.6 * lift
    # radial fibres between the rings, faint: they make it an iris, not a target
    fib = (0.5 + 0.5 * np.cos(th * 72 + 6 * np.sin(th * 7))) * smooth(0.16, 0.3, r) * smooth(0.72, 0.6, r)
    col = col * (1 - fib[..., None] * 0.22) + AMBER * fib[..., None] * 0.22
    for rr, w, c in IRIS:
        m = band(r, rr, w)[..., None] * 0.9
        col = col * (1 - m) + c * m
        a = np.maximum(a, band(r, rr, w))
    # the pupil: a dark core with a thin gold rim
    m = band(r, 0.13, 0.012)[..., None]
    col = col * (1 - m) + GOLD * m
    # a ring of chain links round the rim: ellipses along the circle, face-on and edge-on in turn
    k = 2
    M = N * k
    im = Image.new("L", (M, M), 0)
    d = ImageDraw.Draw(im)
    count = 36
    R = 0.79 * M / 2
    for i in range(count):
        a0 = (i + 0.5) / count * 2 * math.pi
        cx, cy = M / 2 + R * math.cos(a0), M / 2 + R * math.sin(a0)
        L, Wd = 0.072 * M / 2, (0.036 if i % 2 == 0 else 0.012) * M / 2
        pts = []
        for t in np.linspace(0, 2 * math.pi, 40):
            lx, ly = L * math.cos(t), Wd * math.sin(t)
            tx, ty = -math.sin(a0), math.cos(a0)  # along the circle
            pts.append((cx + lx * tx - ly * math.cos(a0), cy + lx * ty - ly * math.sin(a0)))
        d.line(pts + [pts[0]], fill=255, width=int(0.006 * M))
    link = np.asarray(im.resize((N, N), Image.LANCZOS), float) / 255.0
    m = link[..., None]
    col = col * (1 - m) + GOLD * 0.85 * m
    a = np.maximum(a, link)
    return to_img(np.dstack([col, a * 255]))


def halo(N=1024):
    r, th, xx, yy = polar(N)
    col = np.zeros((N, N, 3))
    col[:] = AMBER
    a = np.zeros((N, N))
    for rr, w, c in [row for row in IRIS[2:] if row[2] is GOLD]:
        rr2, w2 = rr * 1.25, w * 1.25
        m = band(r, rr2, w2)
        col = np.where((m > 0.01)[..., None], col * (1 - m[..., None]) + c * m[..., None], col)
        a = np.maximum(a, m)
    glow = np.clip(ndimage.gaussian_filter(a, 10) * 1.6, 0, 1) * 0.5
    col = np.where((a < 0.02)[..., None], GOLD, col)
    a = np.maximum(a, glow)
    return to_img(np.dstack([col, a * 255]))


def chain(W=512, H=128, k=3):
    """four link pairs per repeat; a link face-on (an oval ring with a hole) then one edge-on (a bar)"""
    S, T = W * k, H * k
    im = Image.new("L", (S, T), 0)
    d = ImageDraw.Draw(im)
    mid = T / 2
    pitch = S / 8  # one link every pitch, alternating
    for i in range(9):
        cx = i * pitch
        if i % 2 == 0:  # face-on oval with a hole
            rx, ry = pitch * 0.68, T * 0.36
            d.ellipse([cx - rx, mid - ry, cx + rx, mid + ry], fill=255)
            hx, hy = rx * 0.62, ry * 0.42
            d.ellipse([cx - hx, mid - hy, cx + hx, mid + hy], fill=0)
        else:  # edge-on: a rounded bar
            rx, ry = pitch * 0.72, T * 0.11
            d.rounded_rectangle([cx - rx, mid - ry, cx + rx, mid + ry], radius=int(ry), fill=255)
    m = np.asarray(im, float).reshape(T // k, k, S // k, k).mean(axis=(1, 3)) / 255.0
    yy, xx = np.mgrid[0:H, 0:W]
    v = (yy - H / 2) / (H / 2)
    solid = m > 0.5
    din = ndimage.distance_transform_edt(solid)
    lum = np.clip(0.55 + 0.45 * smooth(0, 4, din) - 0.35 * (v > 0), 0, 1)[..., None]
    col = IRON * (0.6 + 0.8 * lum)
    glint = np.exp(-((v + 0.28) / 0.08) ** 2)[..., None] * solid[..., None]
    col = col * (1 - glint * 0.8) + GOLD * glint * 0.8
    edge = (1 - smooth(0.6, 1.8, din))[..., None]
    col = col * (1 - edge) + INK * edge
    # Roblox lays a Beam texture's VERTICAL axis along the beam (measured in play, 2026-11-25: a horizontal
    # strip drew its links across the beam as parallel streaks), so the strip is saved upright.
    return to_img(np.dstack([col, np.clip(m, 0, 1) * 255])).rotate(90, expand=True)


def dog(N=512, k=3, mirror=False):
    """One of her dogs, sitting, in PROFILE facing left (a front view silhouette read as a cat in v1/v2):
    a Doberman-like guard dog, black with a crimson rim, a ringed gold eye, a gold collar ring."""
    S = N * k
    im = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(im)
    u = S / 512

    def P(x, y):  # x right, y up, origin at the bottom centre
        return (S / 2 + x * u, S - 24 * u - y * u)

    def poly(pts):
        d.polygon([P(x, y) for x, y in pts], fill=255)

    def ell(cx, cy, rx, ry):
        a, b = P(cx - rx, cy + ry), P(cx + rx, cy - ry)
        d.ellipse([a[0], a[1], b[0], b[1]], fill=255)

    ell(70, 92, 92, 88)  # haunch
    ell(34, 12, 56, 13)  # hind paw
    poly([(-78, 40), (-104, 200), (-92, 290), (-58, 330), (-10, 320), (52, 220), (150, 150), (130, 60), (20, 30)])  # body
    poly([(-100, 0), (-66, 0), (-70, 200), (-108, 196)])  # front leg
    ell(-90, 9, 32, 11)  # front paw
    ell(-78, 352, 52, 42)  # skull
    poly([(-112, 372), (-212, 342), (-218, 322), (-206, 310), (-112, 322)])  # long snout
    ell(-212, 330, 13, 11)  # nose
    poly([(-58, 380), (-30, 478), (-12, 372)])  # upright pointed ear
    poly([(150, 74), (232, 32), (240, 16), (142, 50)])  # tail along the ground
    m = np.asarray(im, float).reshape(N, k, N, k).mean(axis=(1, 3)) / 255.0
    solid = m > 0.5
    din = ndimage.distance_transform_edt(solid)
    dout = ndimage.distance_transform_edt(~solid)
    col = np.zeros((N, N, 3))
    col[:] = INK
    rim = (1 - smooth(0.8, 2.6, din))[..., None]
    col = col * (1 - rim) + CRIM * 1.2 * rim
    halo_ = (1 - smooth(0, 9, dout)) * 0.4 * (~solid)
    col = np.where(solid[..., None], col, CRIM[None, None, :])
    a = np.where(solid, m, halo_)
    yy, xx = np.mgrid[0:N, 0:N]

    def px(x, y):
        return N / 2 + x * N / 512, N - (24 + y) * N / 512

    # a ringed gold eye
    cx, cy = px(-102, 360)
    rr = np.hypot(xx - cx, (yy - cy) * 1.15)
    for r0, w, c in ((8.0, 2.4, GOLD), (4.4, 1.5, AMBER)):
        mm = smooth(w + 0.6, w - 0.6, np.abs(rr - r0))[..., None]
        col = col * (1 - mm) + c * mm
    glow = (1 - smooth(0, 18, rr)) ** 2 * 0.35
    col = col * (1 - glow[..., None]) + GOLD * glow[..., None]
    # a collar round the neck and its gold ring, where her leash hooks on
    x0, y0 = px(-96, 300)
    x1, y1 = px(-30, 322)
    t = np.clip(((xx - x0) * (x1 - x0) + (yy - y0) * (y1 - y0)) / ((x1 - x0) ** 2 + (y1 - y0) ** 2), 0, 1)
    dist = np.hypot(xx - (x0 + t * (x1 - x0)), yy - (y0 + t * (y1 - y0)))
    collar = (dist < 5) & solid
    col = np.where(collar[..., None], CRIM * 1.1, col)
    cx, cy = px(-80, 296)
    rr = np.hypot(xx - cx, yy - cy)
    ring = smooth(4.0, 2.4, np.abs(rr - 11))[..., None]
    col = col * (1 - ring) + GOLD * ring
    a = np.maximum(a, ring[..., 0])
    img = to_img(np.dstack([col, a * 255]))
    return img.transpose(Image.FLIP_LEFT_RIGHT) if mirror else img


def ring_pulse(N=512):
    r, _, _, _ = polar(N)
    ring = np.exp(-((r - 0.88) / 0.02) ** 2)
    glow = np.exp(-((r - 0.86) / 0.07) ** 2) * 0.45
    a = np.clip(ring + glow, 0, 1)
    col = np.zeros((N, N, 3))
    col[:] = GOLD
    return to_img(np.dstack([col, a * 255]))


def contact(imgs):
    tiles = []
    for name, im in imgs:
        t = im.copy()
        t.thumbnail((512, 512))
        tiles.append((name, t))
    rows = math.ceil(len(tiles) / 2)
    out = Image.new("RGB", (1080, rows * 560), (255, 95, 162))  # her pink stand
    dark = Image.new("RGB", (540, 560), (30, 40, 70))
    for i, (name, t) in enumerate(tiles):
        x, y = (i % 2) * 540, (i // 2) * 560
        if i % 2 == 1:
            out.paste(dark, (x, y))
        out.paste(t, (x + 14, y + 14), t)
        ImageDraw.Draw(out).text((x + 14, y + 534), name, fill=(255, 255, 255))
    return out


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    jobs = [("gaze_sigil", gaze_sigil), ("halo", halo), ("chain", chain), ("dog_l", dog), ("dog_r", lambda: dog(mirror=True)), ("ring_pulse", ring_pulse)]
    made = []
    for name, fn in jobs:
        im = fn()
        im.save(OUT / f"{name}.png", optimize=True)
        made.append((name, im))
        print(f"wrote {name}.png {im.size}")
    contact(made).save(OUT / "_sheet.jpg", quality=88)
    print("wrote _sheet.jpg")


if __name__ == "__main__":
    main()
