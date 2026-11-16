"""UI v5.2 store: the Blood Fiend card's blood sprites, drawn (not generated), so they are deterministic.

    python tools/ui/store_blood.py            -> assets/ui/store_v5/blood/{BloodSplat,BloodDrip,BloodDrop}.png

The owner's VFX packs hold no blood texture (fire, smoke, spikes, hearts...), so these three are drawn here:
  BloodSplat  a glossy splatter: a lumpy core, tapered spray arms ending in beads, satellite droplets
  BloodDrip   a run of blood hanging from an edge, thinning to a heavy bead (top edge is flat: it hangs)
  BloodDrop   one falling drop (teardrop, point up) with a specular highlight
Deep crimson with darker rims and a wet highlight, drawn at 4x and downsampled (smooth edges, no halo:
RGB is the blood colour everywhere, alpha carries the shape). Uploaded as Image (Open Cloud), ids in
assets/ui/ids_store_v5.json.
"""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "ui" / "store_v5" / "blood"
SS = 4
DARK, MID, BRIGHT = (52, 0, 6), (122, 2, 16), (176, 14, 30)


def _shade(mask: Image.Image, light_dir=(-0.5, -0.7), gloss=0.9) -> Image.Image:
    """Colour a shape mask like wet blood: dark rims, a bright body, a soft specular highlight."""
    w, h = mask.size
    blur = mask.filter(ImageFilter.GaussianBlur(max(2, w // 60)))
    # depth: distance-ish from the edge (blurred mask), used to darken the rim
    inner = mask.filter(ImageFilter.GaussianBlur(max(3, w // 30)))
    base = Image.new("RGB", (w, h), DARK)
    body = Image.new("RGB", (w, h), MID)
    base = Image.composite(body, base, inner.point(lambda v: min(255, int(v * 1.6))))
    bright = Image.new("RGB", (w, h), BRIGHT)
    core = inner.point(lambda v: max(0, int((v - 200) * 1.6)))
    base = Image.composite(bright, base, core)
    # highlight: the mask shifted against the light, subtracted -> a lit crescent on the light side
    dx, dy = int(light_dir[0] * w / 70), int(light_dir[1] * h / 70)
    shifted = ImageChops.offset(blur, -dx, -dy)
    rim = ImageChops.subtract(blur, shifted).point(lambda v: min(255, int(v * 3.2 * gloss)))
    rim = ImageChops.multiply(rim, mask)
    spec = Image.new("RGB", (w, h), (255, 190, 190))
    base = Image.composite(spec, base, rim.filter(ImageFilter.GaussianBlur(max(1, w // 300))))
    out = base.convert("RGBA")
    out.putalpha(mask)
    return out


def _blob(draw, cx, cy, r, rnd, lumps=14, jitter=0.22):
    pts = []
    phase = rnd.random() * 6
    for i in range(lumps * 4):
        a = i / (lumps * 4) * math.tau
        k = 1 + jitter * math.sin(a * lumps / 2 + phase) * rnd.uniform(0.6, 1.0) + rnd.uniform(-0.05, 0.05)
        pts.append((cx + r * k * math.cos(a), cy + r * k * math.sin(a)))
    draw.polygon(pts, fill=255)


def _arm(draw, cx, cy, a, r0, length, width, rnd):
    """A tapered spray arm from the core, ending in a bead."""
    steps = 24
    left, right = [], []
    for i in range(steps + 1):
        t = i / steps
        d = r0 + length * t
        wv = width * (1 - 0.82 * t) * (1 + 0.15 * math.sin(t * 9 + a))
        bend = 0.06 * math.sin(t * 3 + a * 2)
        x, y = cx + d * math.cos(a + bend), cy + d * math.sin(a + bend)
        nx, ny = -math.sin(a + bend), math.cos(a + bend)
        left.append((x + nx * wv, y + ny * wv))
        right.append((x - nx * wv, y - ny * wv))
    draw.polygon(left + right[::-1], fill=255)
    ex, ey = left[-1][0] / 2 + right[-1][0] / 2, left[-1][1] / 2 + right[-1][1] / 2
    br = width * rnd.uniform(0.55, 0.8)
    draw.ellipse((ex - br, ey - br, ex + br, ey + br), fill=255)


def splat(size=512, seed=7) -> Image.Image:
    rnd = random.Random(seed)
    S = size * SS
    m = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(m)
    c = S / 2
    _blob(d, c, c, S * 0.2, rnd, 11, 0.3)
    for _ in range(5):
        a = rnd.random() * math.tau
        _blob(d, c + math.cos(a) * S * 0.12, c + math.sin(a) * S * 0.12, S * rnd.uniform(0.07, 0.11), rnd, 9, 0.3)
    for i in range(15):
        a = i / 15 * math.tau + rnd.uniform(-0.15, 0.15)
        _arm(d, c, c, a, S * 0.16, S * rnd.uniform(0.1, 0.28), S * rnd.uniform(0.018, 0.04), rnd)
    for _ in range(46):
        a = rnd.random() * math.tau
        r = S * rnd.uniform(0.27, 0.46)
        br = S * rnd.uniform(0.004, 0.017)
        x, y = c + r * math.cos(a), c + r * math.sin(a)
        d.ellipse((x - br, y - br, x + br, y + br), fill=255)
    m = m.filter(ImageFilter.GaussianBlur(SS * 0.8)).point(lambda v: 255 if v > 120 else int(v * 2.1))
    return _shade(m).resize((size, size), Image.LANCZOS)


def drip(w=96, h=512, seed=3) -> Image.Image:
    rnd = random.Random(seed)
    W, H = w * SS, h * SS
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    cx = W / 2
    # the band it hangs from (flat top), then the run narrowing, then the bead
    d.rounded_rectangle((0, -W * 0.2, W, W * 0.14), radius=W * 0.12, fill=255)
    bead_y, bead_r = H * 0.88, W * 0.27
    left, right = [], []
    for i in range(41):
        t = i / 40
        y = W * 0.08 + (bead_y - W * 0.08) * t
        wv = W * (0.3 * (1 - t) ** 1.4 + 0.16 + 0.05 * t * t) * (1 + 0.05 * math.sin(t * 13 + seed))
        x = cx + W * 0.03 * math.sin(t * 5)
        left.append((x - wv, y))
        right.append((x + wv, y))
    d.polygon(left + right[::-1], fill=255)
    d.ellipse((cx - bead_r, bead_y - bead_r * 1.15, cx + bead_r, bead_y + bead_r), fill=255)
    m = m.filter(ImageFilter.GaussianBlur(SS)).point(lambda v: 255 if v > 120 else int(v * 2.1))
    return _shade(m, light_dir=(-0.9, -0.2)).resize((w, h), Image.LANCZOS)


def drop(size=128) -> Image.Image:
    S = size * SS
    m = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(m)
    cx, cy, r = S / 2, S * 0.64, S * 0.27
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    d.polygon([(cx, S * 0.08), (cx - r * 0.93, cy - r * 0.35), (cx + r * 0.93, cy - r * 0.35)], fill=255)
    m = m.filter(ImageFilter.GaussianBlur(SS * 1.5)).point(lambda v: 255 if v > 120 else int(v * 2.1))
    img = _shade(m, light_dir=(-0.6, -0.6))
    hl = Image.new("L", (S, S), 0)
    ImageDraw.Draw(hl).ellipse((cx - r * 0.55, cy - r * 0.6, cx - r * 0.15, cy - r * 0.05), fill=200)
    hl = hl.filter(ImageFilter.GaussianBlur(SS * 3))
    img = Image.composite(Image.new("RGBA", (S, S), (255, 210, 210, 255)), img, hl)
    img.putalpha(m)
    return img.resize((size, size), Image.LANCZOS)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    splat().save(OUT / "BloodSplat.png")
    drip().save(OUT / "BloodDrip.png")
    drop().save(OUT / "BloodDrop.png")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
