"""Textures for the training grounds of plan 13 phase D (the waterfall's water, the post's splinters).

    python assets/vfx/tools/make_train_tex.py

Writes assets/vfx/textures/<name>.png ("sim:tfa/<name>" in the effects). The water strips are drawn
HORIZONTAL (the sim runs a beam texture's width along the beam; the packer transposes them for
Roblox) and TILE along the flow, so a beam can scroll them for ever. The set pieces
(tools/studio/grounds/build_grounds.luau) use the same uploaded images on their own Beams and on the
pool's surface.
"""
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "textures"
RNG = np.random.default_rng(13)


def save(img, name):
    OUT.mkdir(parents=True, exist_ok=True)
    img.save(OUT / f"{name}.png")
    print("wrote", name, img.size)


def rgba(rgb, a):
    arr = np.dstack([np.clip(rgb, 0, 255).astype(np.uint8), (np.clip(a, 0, 1) * 255).astype(np.uint8)])
    return Image.fromarray(arr, "RGBA")


def streak_field(W, H, count, len_range, thick_range, soft):
    """Streaks running ALONG x, wrapped at the x seam. Returns a 0..1 field."""
    S = 2
    img = Image.new("L", (W * S, H * S), 0)
    d = ImageDraw.Draw(img)
    for _ in range(count):
        y = RNG.uniform(0.03, 0.97) * H * S
        x0 = RNG.uniform(0, W * S)
        ln = RNG.uniform(*len_range) * W * S
        th = RNG.uniform(*thick_range) * H * S
        v = int(RNG.uniform(150, 255))
        for shift in (-W * S, 0, W * S):  # drawn three times: whatever crosses the seam wraps
            # a tapered streak: thick head, thin tail (the water falls toward +x)
            pts = [(x0 + shift, y), (x0 + ln * 0.75 + shift, y - th / 2), (x0 + ln + shift, y),
                   (x0 + ln * 0.75 + shift, y + th / 2)]
            d.polygon(pts, fill=v)
    if soft:
        img = img.filter(ImageFilter.GaussianBlur(soft * S))
    return np.asarray(img.resize((W, H), Image.LANCZOS), np.float32) / 255


def water_sheet():
    """The body of the falls: pale blue water with long white streaks, soft at its two sides.
    Pre-coloured (the anime waterfall: flat blue, white streaks)."""
    W, H = 512, 256
    y = np.linspace(-1, 1, H, dtype=np.float32)[:, None]
    long = streak_field(W, H, 70, (0.25, 0.7), (0.012, 0.04), 0.6)
    fine = streak_field(W, H, 120, (0.08, 0.25), (0.006, 0.016), 0.3)
    white = np.clip(long * 0.9 + fine * 0.7, 0, 1)
    # slow darker bands so the body is not one flat colour
    bands = 0.5 + 0.5 * np.sin(y * 9.0 + 0.7) * np.ones((1, W), np.float32)
    body = np.array([150, 214, 250], np.float32)
    deep = np.array([96, 176, 236], np.float32)
    rgb = deep + (body - deep) * bands[..., None]
    rgb = rgb + (255 - rgb) * white[..., None]
    side = np.clip(1 - (np.abs(y) / 0.97) ** 10, 0, 1)
    alpha = (0.62 + 0.38 * white) * side
    save(rgba(rgb, alpha), "water_sheet")


def water_foam():
    """White foam streaks only (nothing between them): laid over the sheet and run faster."""
    W, H = 512, 256
    y = np.linspace(-1, 1, H, dtype=np.float32)[:, None]
    blobs = streak_field(W, H, 46, (0.1, 0.34), (0.02, 0.07), 0.2)
    a = np.clip((blobs - 0.35) / 0.3, 0, 1)  # hard cel edge
    side = np.clip(1 - (np.abs(y) / 0.95) ** 8, 0, 1)
    rgb = np.full((H, W, 3), 255, np.float32)
    save(rgba(rgb, a * side * 0.95), "water_foam")


def pool_ripple():
    """Ripple rings for the pool's surface and for a splash on it: white on clear, tintable."""
    N = 256
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    field = np.zeros((N, N), np.float32)
    for cx, cy, r0, n in ((128, 128, 26, 4), (52, 60, 10, 2), (204, 196, 12, 2), (196, 52, 8, 2), (60, 204, 9, 2)):
        r = np.hypot(xx - cx, yy - cy)
        for k in range(n):
            rad = r0 * (k + 1)
            field = np.maximum(field, np.clip(1 - np.abs(r - rad) / (2.2 + 0.5 * k), 0, 1) * (1 - 0.18 * k))
    edge = np.clip(1 - (np.hypot(xx - 128, yy - 128) / 126) ** 6, 0, 1)
    rgb = np.full((N, N, 3), 255, np.float32)
    save(rgba(rgb, field * edge * 0.9), "pool_ripple")


def wood_splinter():
    """One jagged splinter of wood, long axis up: pale heartwood, a darker rim and grain lines.
    Pre-coloured (Color still tints it)."""
    S, N = 4, 256
    img = Image.new("L", (N * S, N * S), 0)
    d = ImageDraw.Draw(img)
    c = N * S / 2
    pts = [(c - 14 * S, 232 * S), (c - 30 * S, 150 * S), (c - 18 * S, 96 * S), (c - 26 * S, 40 * S),
           (c - 6 * S, 64 * S), (c + 4 * S, 14 * S), (c + 12 * S, 70 * S), (c + 30 * S, 52 * S),
           (c + 22 * S, 120 * S), (c + 34 * S, 176 * S), (c + 12 * S, 242 * S)]
    d.polygon(pts, fill=255)
    mask = img.resize((N, N), Image.LANCZOS)
    a = np.asarray(mask, np.float32) / 255
    inner = np.asarray(mask.filter(ImageFilter.MinFilter(13)), np.float32) / 255
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    grain = 0.5 + 0.5 * np.sin((xx + 6 * np.sin(yy / 31.0)) * 0.55)
    light = np.array([238, 196, 132], np.float32)
    mid = np.array([196, 142, 84], np.float32)
    dark = np.array([112, 70, 38], np.float32)
    rgb = mid + (light - mid) * (grain > 0.55)[..., None]
    rgb = dark + (rgb - dark) * inner[..., None]
    save(rgba(rgb, a), "wood_splinter")


def bolt_strip():
    """A lightning bolt running ALONG x (a beam texture: the packer transposes it): a jagged white
    core with two short forks and a soft glow, tintable. It does not tile: a beam stretches it."""
    S, W, H = 3, 512, 128
    img = Image.new("L", (W * S, H * S), 0)
    d = ImageDraw.Draw(img)

    def jag(x0, y0, x1, y1, steps, wobble, width):
        pts = [(x0, y0)]
        for i in range(1, steps):
            u = i / steps
            pts.append((x0 + (x1 - x0) * u, y0 + (y1 - y0) * u + RNG.uniform(-wobble, wobble)))
        pts.append((x1, y1))
        d.line([(x * S, y * S) for x, y in pts], fill=255, width=int(width * S), joint="curve")
        return pts

    main = jag(0, H / 2, W, H / 2, 14, 30, 9)
    for k in (4, 9):
        x, y = main[k]
        jag(x, y, x + RNG.uniform(60, 100), y + RNG.choice((-1, 1)) * RNG.uniform(34, 50), 4, 9, 5)
    core = np.asarray(img.resize((W, H), Image.LANCZOS), np.float32) / 255
    glow = np.asarray(img.filter(ImageFilter.GaussianBlur(7 * S)).resize((W, H), Image.LANCZOS), np.float32) / 255
    a = np.clip(core + glow * 1.4, 0, 1)
    rgb = np.full((H, W, 3), 255, np.float32)
    save(rgba(rgb, a), "bolt_strip")


def speed_line():
    """One speed line, long axis UP (a particle drawn VelocityParallel runs its texture's up along its
    travel, and the library's streak is drawn lying at 20 degrees: falling straight down it showed as a
    row of sideways dashes). A hard white spindle, sharp at both ends, fatter toward the head (top);
    tintable."""
    # (square: a particle is drawn square whatever its image, so a narrow image came out a fat cone)
    S, W, H = 4, 256, 256
    img = Image.new("L", (W * S, H * S), 0)
    d = ImageDraw.Draw(img)
    cx = W * S / 2
    pts_l, pts_r = [], []
    for i in range(0, 101):
        u = i / 100  # 0 = top (head), 1 = bottom (tail)
        # widest at a quarter of the way down, a long tail
        w = (math.sin(min(u / 0.25, 1) * math.pi / 2) if u < 0.25 else (1 - (u - 0.25) / 0.75) ** 1.4) * 0.05 * W * S
        y = (0.03 + 0.94 * u) * H * S
        pts_l.append((cx - w, y))
        pts_r.append((cx + w, y))
    d.polygon(pts_l + pts_r[::-1], fill=255)
    a = np.asarray(img.resize((W, H), Image.LANCZOS), np.float32) / 255
    rgb = np.full((H, W, 3), 255, np.float32)
    save(rgba(rgb, a), "speed_line")


if __name__ == "__main__":
    water_sheet()
    water_foam()
    pool_ripple()
    wood_splinter()
    bolt_strip()
    speed_line()
