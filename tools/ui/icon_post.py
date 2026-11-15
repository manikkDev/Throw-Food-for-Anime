"""Large (40 px and up) icon family: the same post-process on every glossy icon.

    python tools/ui/icon_post.py      # -> assets/ui/icons_big/<Key>Big.png (256 x 256)

Size decides style: under 30 px the flat ink glyphs in assets/ui/icons are used, never these.
Every glossy icon gets the SAME treatment so the set reads as one family:
  1. remove a baked ground shadow (low-saturation grey pixels in the lower part) - only on the
     v2 sources, which were generated with shadows; v3 was prompted "no ground shadow" and the
     filter would eat grey faces (it hollowed the stopwatch),
  2. trim, fit inside the square with room for the outline,
  3. ink outline of 5% of the side (#0D0F2B) by dilation, then a thin white keyline outside it.
Icons whose generation failed twice keep the flat glyph at large size (copied, not outlined
again): listed in GLYPH_BIG.
"""

from __future__ import annotations

import colorsys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "ui" / "icons_big"
V2 = ROOT / "assets" / "ui" / "icons_v2"
V3A = ROOT / "work" / "ui" / "icons_v3_cut"
V3B = ROOT / "work" / "ui" / "icons_v3_cut2"
GLYPH = ROOT / "assets" / "ui" / "icons"
SIDE = 256
INK = (13, 15, 43)

GLOSSY = {  # key -> source file
    **{k: V2 / f"Icon{k}.png" for k in ("Shop", "Store", "Index", "Gift", "Settings", "Yen", "Crown", "Luck",
                                        "LuckyThrow", "Scroll")},
    **{k: V3A / f"Icon{k}Big.png" for k in ("Bench", "Codes", "FlavorSeafood", "FlavorSpicy", "FlavorSweet", "Fuse",
                                            "Lock", "Place", "Power", "Squad", "Timer")},
    **{k: V3B / f"Icon{k}Big.png" for k in ("Rebirth", "Sell")},
}
ALIAS = {"Train": "Power"}                       # the dumbbell is power AND training, everywhere
GLYPH_BIG = ("Auto", "FlavorSavory", "Throw")    # failed twice: flat glyph at large size too


def deshadow(im):
    a = np.asarray(im.convert("RGBA")).astype(np.float32)
    rgb, al = a[..., :3] / 255, a[..., 3]
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    h = a.shape[0]
    low = np.zeros_like(sat, bool)
    low[int(h * 0.55):] = True
    shadow = low & (sat < 0.12) & (mx > 0.2) & (mx < 0.94)
    a[..., 3] = np.where(shadow, 0, al)
    # keep only the largest connected object (drops shadow islands left behind)
    mask = a[..., 3] > 40
    lab, n = ndimage.label(mask)
    if n > 1:
        sizes = ndimage.sum(mask, lab, range(1, n + 1))
        keep = 1 + int(np.argmax(sizes))
        a[..., 3] = np.where(lab == keep, a[..., 3], 0)
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def family(im, shadow=True):
    im = deshadow(im) if shadow else im
    bb = im.getbbox()
    im = im.crop(bb)
    ink = round(SIDE * 0.05)
    key = 3
    room = SIDE - 2 * (ink + key + 4)
    s = room / max(im.size)
    im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
    canvas = Image.new("RGBA", (SIDE, SIDE), (0, 0, 0, 0))
    canvas.alpha_composite(im, ((SIDE - im.width) // 2, (SIDE - im.height) // 2))
    a = np.asarray(canvas)
    m = a[..., 3] > 100
    st = ndimage.generate_binary_structure(2, 2)
    m_ink = ndimage.binary_dilation(m, st, iterations=ink)
    m_key = ndimage.binary_dilation(m_ink, st, iterations=key)
    base = np.zeros((SIDE, SIDE, 4), np.uint8)
    base[m_key] = (255, 255, 255, 255)
    base[m_ink] = (*INK, 255)
    out = Image.fromarray(base, "RGBA")
    out.alpha_composite(canvas)
    return out


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    made = []
    for k, src in GLOSSY.items():
        family(Image.open(src), shadow=(src.parent == V2)).save(OUT / f"Icon{k}Big.png")
        made.append(k)
    for k, src in ALIAS.items():
        (OUT / f"Icon{k}Big.png").write_bytes((OUT / f"Icon{src}Big.png").read_bytes())
    for k in GLYPH_BIG:
        Image.open(GLYPH / f"Icon{k}.png").convert("RGBA").resize((SIDE, SIDE), Image.LANCZOS).save(OUT / f"Icon{k}Big.png")
    print(f"{len(made)} glossy + {len(ALIAS)} alias + {len(GLYPH_BIG)} glyph-at-large -> {OUT}")


if __name__ == "__main__":
    main()
