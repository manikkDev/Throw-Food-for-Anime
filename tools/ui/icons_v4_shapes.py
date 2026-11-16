"""Icons v4: the 2D silhouettes the Blender renderer extrudes.

    python tools/ui/icons_v4_shapes.py      # -> work/icons_v4/shapes.json

Each shape is drawn as a mask at 1024 px (PIL), softened (a blur + threshold rounds every corner and
fillets every inside corner, which is what makes an extrusion read as moulded plastic instead of
cut card), then traced to closed loops (cv2, with holes). Coordinates are unit square, y UP.
Blender (tools/ui/icons_v4_blender.py) extrudes each shape into a bevelled slab; a nested loop is a hole.
Geometry is drawn, never generated: a diffusion model is worst at exactly these (roblox-ui skill).
"""

from __future__ import annotations

import json
import math
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "work" / "icons_v4" / "shapes.json"
S = 1024
FONT_BLACK = "C:/Windows/Fonts/ariblk.ttf"


def P(pts):
    return [(S * x, S * y) for x, y in pts]


def bar(d, p0, p1, w, fill=255):
    """A stadium (round capped bar) from p0 to p1, width w (unit coords)."""
    d.line(P([p0, p1]), fill=fill, width=int(S * w))
    for x, y in (p0, p1):
        r = S * w / 2
        d.ellipse([S * x - r, S * y - r, S * x + r, S * y + r], fill=fill)


def poly_stroke(d, pts, w, fill=255):
    for a, b in zip(pts, pts[1:]):
        bar(d, a, b, w, fill)


def ell(d, x0, y0, x1, y1, fill=255):
    d.ellipse([S * x0, S * y0, S * x1, S * y1], fill=fill)


def rrect(d, x0, y0, x1, y1, r, fill=255):
    d.rounded_rectangle([S * x0, S * y0, S * x1, S * y1], radius=S * r, fill=fill)


def star_pts(cx, cy, outer, inner, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        r = outer if i % 2 == 0 else inner
        a = math.radians(rot + i * 180 / n)
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


# ---------------------------------------------------------------- shapes (draw on a 0..1 square, y DOWN)

def tick(d):
    poly_stroke(d, [(0.16, 0.52), (0.40, 0.76), (0.86, 0.24)], 0.20)


def close(d):
    bar(d, (0.20, 0.20), (0.80, 0.80), 0.21)
    bar(d, (0.80, 0.20), (0.20, 0.80), 0.21)


def plus(d):
    bar(d, (0.5, 0.14), (0.5, 0.86), 0.24)
    bar(d, (0.14, 0.5), (0.86, 0.5), 0.24)


def arrow_up(d):
    bar(d, (0.5, 0.42), (0.5, 0.86), 0.22)
    d.polygon(P([(0.5, 0.08), (0.88, 0.50), (0.12, 0.50)]), fill=255)


def star5(d):
    d.polygon(P(star_pts(0.5, 0.53, 0.48, 0.22)), fill=255)


def sparkle4(d):
    """Four point sparkle with concave (curved) sides."""
    cx, cy, r = 0.5, 0.5, 0.49
    pts = []
    for i in range(4):
        a0 = math.radians(-90 + i * 90)
        for t in np.linspace(0, 1, 60, endpoint=False):
            a = a0 + t * math.pi / 2
            k = 1 - math.sin(t * math.pi)  # 1 at the tips, 0 midway between them
            rr = r * (0.30 + 0.70 * k ** 1.7)
            pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    d.polygon(P(pts), fill=255)


def heart(d):
    pts = []
    for t in np.linspace(0, 2 * math.pi, 240, endpoint=False):
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((0.5 + x / 36, 0.47 - y / 36))
    d.polygon(P(pts), fill=255)


def gear(d):
    cx = cy = 0.5
    for i in range(8):
        a = math.radians(i * 45)
        pts = []
        for da, rr in ((-0.22, 0.34), (-0.15, 0.48), (0.15, 0.48), (0.22, 0.34)):
            pts.append((cx + math.cos(a + da) * rr, cy + math.sin(a + da) * rr))
        d.polygon(P(pts), fill=255)
    ell(d, 0.15, 0.15, 0.85, 0.85)
    ell(d, 0.35, 0.35, 0.65, 0.65, fill=0)


def tag(d):
    d.polygon(P([(0.04, 0.50), (0.32, 0.18), (0.96, 0.18), (0.96, 0.82), (0.32, 0.82)]), fill=255)
    ell(d, 0.20, 0.42, 0.36, 0.58, fill=0)


def ticket(d):
    rrect(d, 0.04, 0.22, 0.96, 0.78, 0.07)
    ell(d, -0.06, 0.39, 0.16, 0.61, fill=0)
    ell(d, 0.84, 0.39, 1.06, 0.61, fill=0)


def merge(d):
    """Fuse: two branches joining into one arrow pointing up."""
    poly_stroke(d, [(0.18, 0.92), (0.18, 0.74), (0.5, 0.48)], 0.17)
    poly_stroke(d, [(0.82, 0.92), (0.82, 0.74), (0.5, 0.48)], 0.17)
    bar(d, (0.5, 0.50), (0.5, 0.30), 0.17)
    d.polygon(P([(0.5, 0.04), (0.80, 0.36), (0.20, 0.36)]), fill=255)


def note(d):
    ell(d, 0.08, 0.62, 0.42, 0.90)
    ell(d, 0.56, 0.52, 0.90, 0.80)
    rrect(d, 0.33, 0.14, 0.42, 0.78, 0.0)
    rrect(d, 0.81, 0.06, 0.90, 0.68, 0.0)
    d.polygon(P([(0.33, 0.14), (0.90, 0.04), (0.90, 0.24), (0.33, 0.34)]), fill=255)


def speaker(d):
    rrect(d, 0.04, 0.34, 0.30, 0.66, 0.04)
    d.polygon(P([(0.22, 0.36), (0.56, 0.08), (0.56, 0.92), (0.22, 0.64)]), fill=255)


def wave1(d):
    d.arc([S * 0.34, S * 0.30, S * 0.78, S * 0.70], -52, 52, fill=255, width=int(S * 0.085))


def wave2(d):
    d.arc([S * 0.30, S * 0.12, S * 0.98, S * 0.88], -52, 52, fill=255, width=int(S * 0.085))


def eye(d):
    """A lens: the intersection of two circles."""
    pts = []
    for t in np.linspace(0, 1, 80):
        x = 0.02 + 0.96 * t
        pts.append((x, 0.5 - 0.40 * math.sin(math.pi * t) ** 0.8))
    for t in np.linspace(1, 0, 80):
        x = 0.02 + 0.96 * t
        pts.append((x, 0.5 + 0.40 * math.sin(math.pi * t) ** 0.8))
    d.polygon(P(pts), fill=255)


def slash(d):
    bar(d, (0.16, 0.86), (0.84, 0.14), 0.13)


def fastfwd(d):
    for x in (0.06, 0.48):
        d.polygon(P([(x, 0.16), (x + 0.48, 0.50), (x, 0.84)]), fill=255)


def play(d):
    d.polygon(P([(0.18, 0.08), (0.92, 0.50), (0.18, 0.92)]), fill=255)


def rebirth(d):
    d.arc([S * 0.12, S * 0.12, S * 0.88, S * 0.88], 40, 310, fill=255, width=int(S * 0.16))
    # arrow head at the 310 degree end (upper right), pointing clockwise
    a = math.radians(310)
    cx, cy, r = 0.5, 0.5, 0.30
    hx, hy = cx + math.cos(a) * r, cy + math.sin(a) * r
    t = (-math.sin(a), math.cos(a))          # clockwise tangent in y-down coords
    n = (math.cos(a), math.sin(a))
    tip = (hx + t[0] * 0.22, hy + t[1] * 0.22)
    l = (hx + n[0] * 0.21 - t[0] * 0.02, hy + n[1] * 0.21 - t[1] * 0.02)
    rr = (hx - n[0] * 0.21 - t[0] * 0.02, hy - n[1] * 0.21 - t[1] * 0.02)
    d.polygon(P([tip, l, rr]), fill=255)


def circle_arrow(d):
    """Auto: a ring arrow (thinner) that goes round a play button."""
    d.arc([S * 0.04, S * 0.04, S * 0.96, S * 0.96], 120, 400, fill=255, width=int(S * 0.10))
    a = math.radians(400 - 360)
    cx, cy, r = 0.5, 0.5, 0.41
    hx, hy = cx + math.cos(a) * r, cy + math.sin(a) * r
    t = (-math.sin(a), math.cos(a))
    n = (math.cos(a), math.sin(a))
    tip = (hx + t[0] * 0.17, hy + t[1] * 0.17)
    d.polygon(P([tip, (hx + n[0] * 0.15, hy + n[1] * 0.15), (hx - n[0] * 0.15, hy - n[1] * 0.15)]), fill=255)


def robux_ring(d):
    """The Robux mark: a pointy-top hexagon RING with a solid rounded square in the middle."""
    hexo = [(0.5 + 0.48 * math.cos(math.radians(a)), 0.5 + 0.48 * math.sin(math.radians(a))) for a in range(-90, 270, 60)]
    hexi = [(0.5 + 0.31 * math.cos(math.radians(a)), 0.5 + 0.31 * math.sin(math.radians(a))) for a in range(-90, 270, 60)]
    d.polygon(P(hexo), fill=255)
    d.polygon(P(hexi), fill=0)


def robux_square(d):
    rrect(d, 0.36, 0.36, 0.64, 0.64, 0.04)


def onigiri(d):
    d.polygon(P([(0.5, 0.06), (0.95, 0.86), (0.05, 0.86)]), fill=255)


def nori(d):
    rrect(d, 0.34, 0.58, 0.66, 0.96, 0.03)


def crown(d):
    d.polygon(P([(0.04, 0.26), (0.28, 0.50), (0.5, 0.14), (0.72, 0.50), (0.96, 0.26),
                 (0.86, 0.82), (0.14, 0.82)]), fill=255)


def keyhole(d):
    ell(d, 0.36, 0.20, 0.64, 0.48)
    d.polygon(P([(0.43, 0.40), (0.57, 0.40), (0.62, 0.80), (0.38, 0.80)]), fill=255)


def shackle(d):
    d.arc([S * 0.18, S * 0.02, S * 0.82, S * 0.66], 180, 360, fill=255, width=int(S * 0.13))
    d.rectangle([S * 0.18, S * 0.33, S * 0.31, S * 0.70], fill=255)
    d.rectangle([S * 0.69, S * 0.33, S * 0.82, S * 0.70], fill=255)


def glyph(ch, size=0.95):
    def draw(d):
        f = ImageFont.truetype(FONT_BLACK, int(S * size))
        bb = d.textbbox((0, 0), ch, font=f)
        w, h = bb[2] - bb[0], bb[3] - bb[1]
        d.text(((S - w) / 2 - bb[0], (S - h) / 2 - bb[1]), ch, font=f, fill=255)
    return draw


def info_i(d):
    ell(d, 0.40, 0.08, 0.60, 0.28)
    rrect(d, 0.40, 0.36, 0.60, 0.92, 0.04)


def fish(d):
    ell(d, 0.04, 0.22, 0.72, 0.78)
    d.polygon(P([(0.60, 0.50), (0.97, 0.18), (0.88, 0.50), (0.97, 0.82)]), fill=255)


def fin(d):
    d.polygon(P([(0.28, 0.26), (0.46, 0.04), (0.60, 0.28)]), fill=255)


def bolt(d):
    d.polygon(P([(0.62, 0.02), (0.18, 0.56), (0.46, 0.56), (0.36, 0.98),
                 (0.84, 0.40), (0.55, 0.40), (0.70, 0.02)]), fill=255)


def speed_line(d):
    bar(d, (0.06, 0.5), (0.94, 0.5), 0.34)


def swirl(d):
    """Lollipop swirl stripe (a spiral band)."""
    pts_o, pts_i = [], []
    for t in np.linspace(0, 3.2 * math.pi, 300):
        r = 0.04 + 0.42 * t / (3.2 * math.pi)
        w = 0.035 + 0.03 * t / (3.2 * math.pi)
        pts_o.append((0.5 + math.cos(t) * (r + w), 0.5 + math.sin(t) * (r + w)))
        pts_i.append((0.5 + math.cos(t) * max(r - w, 0), 0.5 + math.sin(t) * max(r - w, 0)))
    d.polygon(P(pts_o + pts_i[::-1]), fill=255)


def chili(d):
    """A curved chili pod: fat at the stem (top left), curling down to a point (bottom right)."""
    p0, p1, p2 = np.array([0.26, 0.16]), np.array([0.22, 0.80]), np.array([0.92, 0.90])
    side_a, side_b = [], []
    n = 90
    for i in range(n + 1):
        t = i / n
        c = (1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t ** 2 * p2
        dv = 2 * (1 - t) * (p1 - p0) + 2 * t * (p2 - p1)
        nv = np.array([-dv[1], dv[0]]) / np.linalg.norm(dv)
        w = 0.15 * (1 - t ** 1.6) + 0.006
        side_a.append(tuple(c + nv * w))
        side_b.append(tuple(c - nv * w))
    d.polygon(P(side_a + side_b[::-1]), fill=255)
    ell(d, 0.11, 0.08, 0.41, 0.26)


def cal_page(d):
    """Daily: a tear-off calendar page, the bottom right corner folded (dog-ear cut)."""
    rrect(d, 0.08, 0.06, 0.92, 0.94, 0.09)
    d.polygon(P([(0.70, 0.96), (0.96, 0.96), (0.96, 0.70)]), fill=0)


def cal_fold(d):
    """Daily: the folded-over corner flap that sits on the cut of cal_page."""
    d.polygon(P([(0.70, 0.94), (0.70, 0.74), (0.90, 0.74)]), fill=255)


def speaker_full(d):
    speaker(d)
    wave1(d)
    wave2(d)


SHAPES = {
    "tick": (tick, 22), "close": (close, 22), "plus": (plus, 22), "arrow_up": (arrow_up, 26),
    "star5": (star5, 30), "sparkle4": (sparkle4, 10), "heart": (heart, 10), "gear": (gear, 14),
    "tag": (tag, 34), "ticket": (ticket, 14), "merge": (merge, 22), "note": (note, 14),
    "speaker": (speaker_full, 10), "eye": (eye, 20),
    "slash": (slash, 8), "fastfwd": (fastfwd, 30), "play": (play, 34), "rebirth": (rebirth, 16),
    "circle_arrow": (circle_arrow, 10), "robux_ring": (robux_ring, 26), "robux_square": (robux_square, 4),
    "onigiri": (onigiri, 110), "nori": (nori, 8), "crown": (crown, 24), "keyhole": (keyhole, 10),
    "shackle": (shackle, 6), "yen": (glyph("\u00a5"), 6), "info_i": (info_i, 6), "fish": (fish, 30),
    "fin": (fin, 16), "bolt": (bolt, 18), "speed_line": (speed_line, 4), "swirl": (swirl, 4),
    "chili": (chili, 10), "star5_small": (star5, 40),
    "cal_page": (cal_page, 10), "cal_fold": (cal_fold, 6), "one": (glyph("1"), 6),
}


def trace(fn, soften):
    im = Image.new("L", (S, S), 0)
    fn(ImageDraw.Draw(im))
    m = np.asarray(im).astype(np.float32)
    if soften:
        m = cv2.GaussianBlur(m, (0, 0), soften)
    m = (m > 127).astype(np.uint8) * 255
    contours, _ = cv2.findContours(m, cv2.RETR_CCOMP, cv2.CHAIN_APPROX_NONE)
    loops = []
    for c in contours:
        if cv2.contourArea(c) < 40:
            continue
        c = cv2.approxPolyDP(c, 0.6, True)[:, 0, :]
        loops.append([[round(float(x) / S, 5), round(1 - float(y) / S, 5)] for x, y in c])
    return loops


def main() -> int:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    data = {name: trace(fn, soft) for name, (fn, soft) in SHAPES.items()}
    OUT.write_text(json.dumps(data), encoding="utf-8")
    print(f"{len(data)} shapes -> {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
