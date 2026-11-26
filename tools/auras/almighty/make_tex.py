#!/usr/bin/env python3
"""TheAlmighty (Yhwach's aura) textures, made from maths: nothing harvested, nothing stock.

    python tools/auras/almighty/make_tex.py        -> assets/auras/almighty/*.png (+ _sheet.jpg)

The look (Bleach TYBW, The Almighty): his shadow is flat matte BLACK ink with liquid, ragged edges; eyes OPEN
inside it, white sclera shading to pale blue at the rim, a heavy black outline that is the ink itself, small
irregular black pupils that look different ways. Every texture is pre-coloured (the eye and its ink must be ONE
particle) except the motes.

  eye_a_4x4.png    16 frames (no drips: drips under an eye read as fangs): an ink blob swells, an almond eye opens in it, looks, blinks, looks elsewhere,
                   closes, the ink recedes
  eye_b_4x4.png    the same life for a rounder, wider eye with a bigger pupil and a different rhythm
  ink_4x4.png      16 frames: an ink splotch crawls out (tendrils, a drip), wobbles, recedes
  tongue_4x4.png   16 frames: a black shadow flame with crisp ragged ink edges rising and tearing apart
  strand_4x4.png   16-frame loop: three ink strands hanging from the cloak's torn hem, swaying
  pool.png         his shadow on the ground: a black pool with splash tendrils and droplets, a dark-blue sheen rim
Grid4x4 flipbooks are row-major, 256 px frames on a 1024 sheet.
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets" / "auras" / "almighty"
FRAME = 256
INK = np.array([7, 7, 11.0])
SHEEN = np.array([58, 78, 128.0])


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def grid(n: int):
    yy, xx = np.mgrid[0:n, 0:n].astype(float)
    return (xx - (n - 1) / 2) / (n / 2), -(yy - (n - 1) / 2) / (n / 2)


def noise(n: int, cells: int, seed: int, sigma: float = 1.2) -> np.ndarray:
    rng = np.random.default_rng(seed)
    a = ndimage.gaussian_filter(rng.standard_normal((cells, cells)), sigma, mode="wrap")
    a = (a - a.min()) / np.ptp(a)
    return np.asarray(Image.fromarray((a * 255).astype(np.uint8)).resize((n, n), Image.BICUBIC), float) / 255


def polar_wobble(th: np.ndarray, seed: int, amp: float, k=(2, 3, 5, 7)) -> np.ndarray:
    rng = np.random.default_rng(seed)
    w = np.zeros_like(th)
    for kk in k:
        w += rng.uniform(0.3, 1.0) / kk * np.sin(kk * th + rng.uniform(0, 2 * np.pi))
    return 1 + amp * w


def crisp(field: np.ndarray, px: float) -> np.ndarray:
    """field > 0 inside: an anti-aliased hard edge about px pixels wide"""
    return np.clip(field / px + 0.5, 0, 1)


def compose(col: np.ndarray, a: np.ndarray) -> Image.Image:
    return Image.fromarray(np.dstack([col.clip(0, 255), np.clip(a, 0, 1) * 255]).astype(np.uint8), "RGBA")


def sheet_of(frames: list[Image.Image]) -> Image.Image:
    s = Image.new("RGBA", (FRAME * 4, FRAME * 4), (0, 0, 0, 0))
    for f, im in enumerate(frames):
        s.alpha_composite(im.resize((FRAME, FRAME), Image.LANCZOS), ((f % 4) * FRAME, (f // 4) * FRAME))
    return s


# ---------------------------------------------------------------- an eye in its ink
def eye_frame(S, x, y, *, blob: float, aperture: float, look: tuple[float, float], fade: float, shape: dict,
              seed: int) -> Image.Image:
    r = np.hypot(x, y)
    th = np.arctan2(y, x)
    px = 2.0 / S  # one pixel in these units
    # the ink blob: an irregular ellipse with two drips hanging off its lower edge
    rx, ry = shape["blob"]
    rr = np.hypot(x / rx, y / ry) / max(blob, 1e-3)
    ink_field = polar_wobble(th, seed, 0.16) - rr
    if blob > 0.6:
        for dx, dl in shape["drips"]:
            # a drip hangs DOWN from the blob's lower edge and tapers to a point
            top = -ry * blob * 0.75
            bottom = -ry * blob - dl * blob
            along = np.clip((y - bottom) / (top - bottom), 0, 1)
            width = 0.065 * along ** 0.6
            band = (y > bottom) & (y < top + 0.05)
            drip = np.where(band, width - np.abs(x - dx), -1.0)
            ink_field = np.maximum(ink_field, drip * 4)
    ink = crisp(ink_field, 3 * px * 2)
    # the eye: an almond (or round) opening, its lids, never perfectly regular
    ax, ay = shape["eye"]
    ex, ey = x / ax, y / ay
    lid_wobble = 1 + 0.10 * np.sin(5.0 * ex + seed) + 0.06 * np.sin(11.0 * ex + 2 * seed)
    lid = (1 - np.clip(np.abs(ex), 0, 1) ** shape["round"]) ** 0.55 * aperture * lid_wobble
    sclera_field = np.minimum(lid - np.abs(ey + shape["tilt"] * ex), 1 - np.abs(ex)) * ay
    sclera = crisp(sclera_field, 2.5 * px) * (aperture > 0.02)
    # inside the sclera: white-blue centre to blue rim, a lid shadow on top
    depth = np.clip(sclera_field / (ay * max(aperture, 0.05) * 0.9), 0, 1)
    col_s = np.array([150, 182, 236.0]) + (np.array([246, 250, 255.0]) - np.array([150, 182, 236.0])) * smooth(0.0, 0.7, depth)[..., None]
    lidshade = smooth(0.0, 0.35, ey * ay - (-0.0)) * smooth(0.3, 1.0, ey + 0.2) * 0.35
    col_s = col_s * (1 - lidshade[..., None] * 0.6)
    # the pupil: small, irregular, off-centre (where it looks)
    lx, ly = look
    pr = shape["pupil"] * (0.9 + 0.1 * aperture)
    pth = np.arctan2(y - ly * ay, x - lx * ax)
    pupil_field = pr * polar_wobble(pth, seed + 9, 0.35, (3, 4, 6)) - np.hypot(x - lx * ax, y - ly * ay)
    pupil = crisp(pupil_field, 2 * px) * sclera
    # a tiny catch-light by the pupil
    catch = crisp(0.018 - np.hypot(x - lx * ax - pr * 0.5, y - ly * ay - pr * 0.55), 1.5 * px) * sclera
    col = INK * np.ones((S, S, 1))
    # the ink's glossy sheen along its upper edge
    edge = np.clip(1 - np.abs(ink_field) / (5 * px * 2), 0, 1) * smooth(-0.2, 0.5, y) * 0.8
    col = col + (SHEEN - INK) * edge[..., None]
    col = col * (1 - sclera[..., None]) + col_s * sclera[..., None]
    col = col * (1 - pupil[..., None]) + INK * pupil[..., None]
    col = col * (1 - catch[..., None]) + np.array([255, 255, 255.0]) * catch[..., None]
    a = np.maximum(ink, sclera) * fade
    return compose(col, a)


def eye_flipbook(shape: dict, timeline: list[tuple], seed: int) -> Image.Image:
    S = FRAME * 2
    x, y = grid(S)
    return sheet_of([eye_frame(S, x, y, blob=b, aperture=ap, look=lk, fade=fd, shape=shape, seed=seed)
                     for b, ap, lk, fd in timeline])


EYE_A = {"blob": (0.80, 0.60), "eye": (0.56, 0.34), "round": 2.0, "tilt": 0.08, "pupil": 0.085,
         "drips": []}
EYE_B = {"blob": (0.78, 0.74), "eye": (0.50, 0.44), "round": 2.6, "tilt": -0.05, "pupil": 0.12,
         "drips": []}
# (blob size, eye aperture, pupil look (x, y) in eye units, alpha)
TIME_A = [(0.40, 0, (0, 0), 1), (0.75, 0, (0, 0), 1), (1.0, 0.12, (0, 0), 1), (1.0, 0.55, (0.05, 0), 1),
          (1.0, 0.92, (0.1, 0.05), 1), (1.0, 1.0, (0.15, 0.05), 1), (1.0, 1.0, (0.2, 0.05), 1),
          (1.0, 1.0, (0.2, 0.05), 1), (1.0, 1.0, (0.2, 0.05), 1), (1.0, 0.15, (0.2, 0.05), 1),
          (1.0, 1.0, (-0.25, -0.1), 1), (1.0, 1.0, (-0.25, -0.1), 1), (1.0, 1.0, (-0.25, -0.1), 1),
          (1.0, 0.5, (-0.2, -0.05), 1), (0.85, 0.0, (0, 0), 0.95), (0.5, 0, (0, 0), 0.6)]
TIME_B = [(0.35, 0, (0, 0), 1), (0.7, 0, (0, 0), 1), (0.95, 0.05, (0, 0), 1), (1.0, 0.35, (0, 0), 1),
          (1.0, 0.8, (-0.1, 0.1), 1), (1.0, 1.0, (-0.15, 0.1), 1), (1.0, 1.0, (-0.15, 0.1), 1),
          (1.0, 1.0, (0.2, -0.05), 1), (1.0, 1.0, (0.2, -0.05), 1), (1.0, 1.0, (0.2, -0.05), 1),
          (1.0, 1.0, (0.2, -0.05), 1), (1.0, 0.1, (0.2, -0.05), 1), (1.0, 1.0, (0.0, 0.15), 1),
          (1.0, 0.6, (0.0, 0.15), 1), (0.8, 0.05, (0, 0), 0.95), (0.45, 0, (0, 0), 0.55)]


# ---------------------------------------------------------------- the crawling ink
def ink_flipbook() -> Image.Image:
    S = FRAME * 2
    x, y = grid(S)
    r = np.hypot(x, y)
    th = np.arctan2(y, x)
    n1 = noise(S, 18, 4, 1.4)
    n2 = noise(S, 48, 5, 1.0)
    px = 2.0 / S
    frames = []
    for f in range(16):
        t = f / 15
        grow = smooth(0.0, 0.35, t) * (1 - 0.55 * smooth(0.6, 1.0, t))
        # tendrils: radial spikes that reach out as it grows
        spikes = 0.22 * np.clip(np.sin(7 * th + 1.3) * np.sin(3 * th - 0.4), 0, 1) ** 2 * smooth(0.1, 0.5, t)
        reach = (0.55 + spikes) * polar_wobble(th, 21, 0.18) * grow
        drip = 0.25 * smooth(0.25, 0.7, t) * np.exp(-((x - 0.12) / 0.06) ** 2) * (y < 0)
        field = reach + drip - r + 0.12 * (n1 - 0.5) + 0.04 * (n2 - 0.5)
        a = crisp(field, 3 * px)
        # droplets flung off as it lands
        for k, (dx, dy) in enumerate([(0.68, 0.30), (-0.62, -0.42), (0.20, -0.78), (-0.35, 0.66)]):
            rad = 0.045 * smooth(0.15 + 0.05 * k, 0.35, t) * (1 - smooth(0.55, 0.85, t))
            a = np.maximum(a, crisp(rad - np.hypot(x - dx, y - dy), 2 * px))
        edge = np.clip(1 - np.abs(field) / (8 * px), 0, 1) * smooth(-0.3, 0.6, y - x * 0.3) * 0.9
        col = INK + (SHEEN - INK) * edge[..., None]
        frames.append(compose(col * np.ones((S, S, 1)), a * (1 - 0.4 * smooth(0.85, 1.0, t))))
    return sheet_of(frames)


# ---------------------------------------------------------------- the shadow tongue
def tongue_flipbook() -> Image.Image:
    S = FRAME * 2
    x, y = grid(S)
    n1 = noise(S, 20, 8, 1.3)
    n2 = noise(S, 56, 9, 1.0)
    px = 2.0 / S
    frames = []
    for f in range(16):
        t = f / 15
        base = -0.92 + 0.55 * smooth(0.3, 1.0, t)
        tip = -0.65 + 1.55 * smooth(0.0, 0.5, t) + 0.1 * t
        ln = np.maximum(tip - base, 0.05)
        s = np.clip((y - base) / ln, 0, 1)
        inside = (y > base) & (y < tip)
        curl = 0.14 * np.sin(np.pi * s * 1.5 - 0.4 - 1.8 * t) * s
        w = 0.24 * (1 - s) ** 0.75 * (0.4 + 0.6 * smooth(0.0, 0.1, s)) * (1 - 0.3 * t)
        field = (w - np.abs(x - curl)) + 0.10 * (n1 - 0.5) + 0.04 * (n2 - 0.5)
        tear = smooth(0.45, 1.0, t) * smooth(0.3, 0.8, n1 * 0.7 + s * 0.5)
        field = field - tear * 0.25
        a = crisp(field, 3 * px) * inside
        edge = np.clip(1 - np.abs(field) / (7 * px), 0, 1) * 0.7 * inside
        col = INK + (SHEEN - INK) * edge[..., None]
        frames.append(compose(col * np.ones((S, S, 1)), a))
    return sheet_of(frames)


# ---------------------------------------------------------------- strands hanging off the cloak's torn hem
def strand_flipbook() -> Image.Image:
    """three thin ink strands hanging from the top edge, swaying as one loop of 16 frames (FlipbookMode Loop),
    tapering to points; the middle one longest"""
    S = FRAME * 2
    x, y = grid(S)
    px = 2.0 / S
    frames = []
    strands = [(-0.28, 1.25, 0.050, 0.0), (0.02, 1.75, 0.065, 1.7), (0.30, 1.05, 0.045, 3.1)]
    for f in range(16):
        ph = 2 * math.pi * f / 16
        field = np.full((S, S), -1.0)
        for x0, length, w, off in strands:
            d = np.clip((0.98 - y) / length, 0, 1)            # 0 at the top edge, 1 at the tip
            sway = 0.16 * np.sin(ph + off) * d ** 1.6 + 0.04 * np.sin(2 * ph + off + 3 * d) * d
            cx = x0 + sway
            width = w * (1 - d) ** 0.8 + 0.004
            inside = (y <= 0.98) & (y >= 0.98 - length)
            field = np.maximum(field, np.where(inside, width - np.abs(x - cx), -1.0))
        a = crisp(field, 2.5 * px) * (1 - smooth(0.9, 1.0, y))  # soft top so it melts into the hem
        edge = np.clip(1 - np.abs(field) / (4 * px), 0, 1) * 0.6
        col = INK + (SHEEN - INK) * edge[..., None]
        frames.append(compose(col * np.ones((S, S, 1)), a))
    return sheet_of(frames)


# ---------------------------------------------------------------- his shadow on the ground
def pool(size=1024) -> Image.Image:
    S = size * 2
    x, y = grid(S)
    r = np.hypot(x, y)
    th = np.arctan2(y, x)
    px = 2.0 / S
    n1 = noise(S, 22, 13, 1.4)
    body = 0.60 * polar_wobble(th, 31, 0.12) - r + 0.06 * (n1 - 0.5)
    field = body
    rng = np.random.default_rng(77)
    for k in range(15):
        a0 = 2 * math.pi * k / 15 + rng.uniform(-0.15, 0.15)
        length = rng.uniform(0.78, 0.97)
        wid = rng.uniform(0.035, 0.06)
        # a tendril: along its direction u, across v, tapered, wavy
        u = x * math.cos(a0) + y * math.sin(a0)
        v = -x * math.sin(a0) + y * math.cos(a0)
        v = v - 0.04 * np.sin(u * 18 + k)
        taper = wid * (1 - smooth(0.5, length, u)) + 0.006
        tend = np.where((u > 0.3) & (u < length), taper - np.abs(v), -1.0)  # -1 = outside (0 would be half ink)
        field = np.maximum(field, tend)
        # a droplet past its end
        dx, dy = (length + 0.03) * math.cos(a0 + 0.05), (length + 0.03) * math.sin(a0 + 0.05)
        field = np.maximum(field, 0.018 - np.hypot(x - dx, y - dy))
    a = crisp(field, 3 * px)
    edge = np.clip(1 - np.abs(field) / (6 * px), 0, 1)
    sheen = 0.25 * smooth(0.2, 0.6, r) * (1 - smooth(0.6, 0.66, r))
    col = INK + (SHEEN - INK) * np.clip(edge * 0.9 + sheen, 0, 1)[..., None]
    col = col + (np.array([14, 18, 34.0]) - INK) * (1 - smooth(0.0, 0.55, r))[..., None] * (field > 0)[..., None]
    im = compose(col * np.ones((S, S, 1)), a)
    return im.resize((size, size), Image.LANCZOS)


def contact_sheet(files: dict[str, Image.Image]) -> Image.Image:
    tiles = []
    for name, im in files.items():
        for bg in ((30, 34, 60), (210, 214, 210)):
            base = Image.new("RGBA", im.size, bg + (255,))
            base.alpha_composite(im)
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
    files = {
        "eye_a_4x4.png": eye_flipbook(EYE_A, TIME_A, 3),
        "eye_b_4x4.png": eye_flipbook(EYE_B, TIME_B, 6),
        "ink_4x4.png": ink_flipbook(),
        "tongue_4x4.png": tongue_flipbook(),
        "pool.png": pool(),
        "strand_4x4.png": strand_flipbook(),
    }
    for name, im in files.items():
        im.save(OUT / name)
        print("wrote", (OUT / name).relative_to(ROOT), im.size)
    contact_sheet(files).save(OUT / "_sheet.jpg", quality=88)
    print("wrote", (OUT / "_sheet.jpg").relative_to(ROOT))


if __name__ == "__main__":
    main()
