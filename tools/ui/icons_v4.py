"""Icons v4: renders -> the final 256 px PNGs, the contact sheet, and the key map.

    python tools/ui/icons_v4.py            # work/icons_v4/render/*.png -> assets/ui/icons_v4/*.png + sheet
    python tools/ui/icons_v4.py --sheet    # only redraw assets/ui/icons_v4_sheet.png

Pipeline (owner brief 2026-11-15, see work/icons_v4/progress.md):
  1. tools/ui/icons_v4_shapes.py   2D silhouettes (drawn geometry, never generated)
  2. tools/ui/icons_v4_blender.py  every icon is a small 3D model rendered in Blender 4.5 Cycles
  3. THIS FILE                     trim, size, centre, ONE thin ink outline, 256 x 256 RGBA
  4. tools/ui/icon_fit_check.py    the framing gate (fails loudly)

ONE outline only: ink #0D0F2B (the UI's text-stroke colour), about 2.3 % of the side, drawn by distance
from the silhouette and anti-aliased. There is NO white keyline (the v3 icon_post.py drew ink + white,
the "two borders" the owner rejected). Framing: the alpha-weighted centre goes to the square's centre and
the whole subject, outline included, fits inside the central 86 % (gate: 88 %), sized to an even optical
weight (alpha coverage) so a coin does not dwarf a tick.

Resampling is done on PREMULTIPLIED alpha (PIL mode "RGBa"): straight-alpha resizing drags the colour of
transparent pixels into the edge and leaves a dark or grey fringe on coloured panels.
"""

from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFont
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
RENDER = ROOT / "work" / "icons_v4" / "render"
SHAPES = ROOT / "work" / "icons_v4" / "shapes.json"
OUT = ROOT / "assets" / "ui" / "icons_v4"
SHEET = ROOT / "assets" / "ui" / "icons_v4_sheet.png"
STAGE = ROOT / "work" / "icons_v4" / "upload"          # one file per DISTINCT image (no duplicate uploads)
IDS = ROOT / "assets" / "ui" / "ids_icons_v4.json"
SIDE = 256
SS = 4                      # work at 1024, downsample once at the end
INK = (13, 15, 43)
OUTLINE_FRAC = 0.023        # of the side: ~6 px at 256, ~1.1 px at 48, ~0.55 px at 24
FIT = 0.86                  # subject + outline inside this central fraction (the gate allows 0.88)
COVERAGE = 0.44             # target alpha coverage (optical weight); the fit always wins

# key -> render name. A base key and its ...Big key share one image when the render reads at 16-24 px
# (judged on the sheet). Keys listed in SMALL use their own simpler render at < 30 px.
KEYS = {
    "IconArrow": "Arrow", "IconAuto": "Auto", "IconBench": "Bench", "IconClose": "Close", "IconCodes": "Codes",
    "IconCrown": "Crown", "IconFast": "Fast", "IconFlavorSavory": "FlavorSavory",
    "IconFlavorSeafood": "FlavorSeafood", "IconFlavorSpicy": "FlavorSpicy", "IconFlavorSweet": "FlavorSweet",
    "IconFuse": "Fuse", "IconGift": "Gift", "IconHide": "Hide", "IconIndex": "Index", "IconInfo": "Info",
    "IconLock": "Lock", "IconLowDetail": "LowDetail", "IconLuck": "Luck", "IconLuckyThrow": "LuckyThrow",
    "IconMusic": "Music", "IconPlace": "Place", "IconPlus": "Plus", "IconPower": "Power", "IconRebirth": "Rebirth",
    "IconScroll": "Scroll", "IconSell": "Sell", "IconSettings": "Settings", "IconSfx": "Sfx", "IconShop": "Shop",
    "IconSquad": "Squad", "IconStar": "Star", "IconStore": "Store", "IconThrow": "Throw", "IconTick": "Tick",
    "IconTimer": "Timer", "IconTrain": "Power", "IconYen": "Yen",
    "IconRobux": "@robux_white", "IconRobuxBig": "RobuxBig",
}
BIG = ["Auto", "Bench", "Codes", "Crown", "FlavorSavory", "FlavorSeafood", "FlavorSpicy", "FlavorSweet", "Fuse",
       "Gift", "Index", "Lock", "Luck", "LuckyThrow", "Place", "Power", "Rebirth", "Scroll", "Sell", "Settings",
       "Shop", "Squad", "Store", "Throw", "Timer", "Train", "Yen"]
for _k in BIG:
    KEYS[f"Icon{_k}Big"] = KEYS[f"Icon{_k}"]
SMALL: dict[str, str] = {}   # base key -> simpler render; the sheet review found none needed (all read at 16-24 px)
FOODS = ROOT / "assets" / "ui" / "food_icons"   # renders of the game's own food meshes (section 3)
FOOD_SATURATION = 1.18   # the food renders are softer than the family; a mild lift, hue untouched


# ----------------------------------------------------------------------------------------------- pipeline

def _premul_resize(im: Image.Image, size) -> Image.Image:
    return im.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")


def frame(src: Image.Image) -> Image.Image:
    """Trim, size, centre (alpha centroid), add ONE ink outline, return SIDE x SIDE RGBA."""
    big = SIDE * SS
    w_out = OUTLINE_FRAC * big
    src = src.convert("RGBA")
    src = src.crop(src.getbbox())
    a = np.asarray(src)[..., 3].astype(np.float64) / 255
    ys, xs = np.mgrid[0:a.shape[0], 0:a.shape[1]]
    cy, cx = (a * ys).sum() / a.sum(), (a * xs).sum() / a.sum()
    # largest scale that keeps every side (plus the outline) inside the FIT box around the centre
    half = FIT * big / 2 - w_out - 2
    reach = max(cx, src.width - cx, cy, src.height - cy)
    s_fit = half / reach
    s_cov = np.sqrt(COVERAGE * big * big / a.sum())
    s = min(s_fit, s_cov)
    im = _premul_resize(src, (max(1, round(src.width * s)), max(1, round(src.height * s))))
    canvas = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    canvas.alpha_composite(im, (round(big / 2 - cx * s), round(big / 2 - cy * s)))
    alpha = np.asarray(canvas)[..., 3].astype(np.float64) / 255
    dist = ndimage.distance_transform_edt(alpha < 0.5)
    ring = np.clip(w_out + 0.5 - dist, 0, 1)
    base = np.zeros((big, big, 4), np.uint8)
    base[..., :3] = INK
    base[..., 3] = (ring * 255).astype(np.uint8)
    out = Image.fromarray(base, "RGBA")
    out.alpha_composite(canvas)
    return _premul_resize(out, (SIDE, SIDE))


def robux_white() -> Image.Image:
    """The white Robux mark, drawn as vector (crispest at 16-34 px): a pointy-top hexagon ring and a
    solid rounded square, with a faint cool bottom tone so it is not dead flat."""
    shapes = json.loads(SHAPES.read_text(encoding="utf-8"))
    n = 1024
    acc = np.zeros((n, n), bool)
    for name in ("robux_ring", "robux_square"):
        for loop in shapes[name]:
            t = Image.new("L", (n, n), 0)
            ImageDraw.Draw(t).polygon([(x * n, (1 - y) * n) for x, y in loop], fill=255)
            acc ^= np.asarray(t) > 127
    tone = np.linspace(0, 1, n)[:, None]
    top, bottom = np.array([255, 255, 255]), np.array([222, 228, 250])
    rgb = np.broadcast_to((top * (1 - tone) + bottom * tone)[:, None, :], (n, n, 3))
    img = np.dstack([rgb.astype(np.uint8), (acc * 255).astype(np.uint8)])
    return Image.fromarray(img, "RGBA")


def build() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    made: dict[str, Image.Image] = {}
    for key, render in {**KEYS, **SMALL}.items():
        if render not in made:
            src = robux_white() if render == "@robux_white" else Image.open(RENDER / f"{render}.png")
            made[render] = frame(src)
    for old in OUT.glob("*.png"):
        old.unlink()
    for key, render in KEYS.items():
        made[SMALL.get(key, render)].save(OUT / f"{key}.png")
    # Food_*: NOT regenerated (they are renders of the real food meshes, so the icon matches the food in the
    # world); re-framed with the same outline, centre and optical size so they sit in the family.
    foods = sorted(FOODS.glob("Food_*.png"))
    for f in foods:
        im = Image.open(f).convert("RGBA")
        rgb = ImageEnhance.Color(im.convert("RGB")).enhance(FOOD_SATURATION)
        rgb.putalpha(im.getchannel("A"))
        frame(rgb).save(OUT / f.name)
    print(f"{len(KEYS)} keys ({len(made)} distinct images) + {len(foods)} foods -> {OUT}")
    # Upload staging: Roblox cannot delete an asset, so an image shared by several keys (IconGift and
    # IconGiftBig, IconPower and IconTrain...) is uploaded ONCE, under its primary key, and --ids maps the rest.
    STAGE.mkdir(parents=True, exist_ok=True)
    for old in STAGE.glob("*.png"):
        old.unlink()
    for key in primaries().values():
        shutil.copyfile(OUT / f"{key}.png", STAGE / f"{key}.png")
    for f in foods:
        shutil.copyfile(OUT / f.name, STAGE / f.name)


def primaries() -> dict[str, str]:
    """render -> the first key (in KEYS order) that uses it: the name its image is uploaded under."""
    first: dict[str, str] = {}
    for key, render in KEYS.items():
        first.setdefault(SMALL.get(key, render), key)
    return first


def write_ids() -> int:
    """Expand the uploaded primary ids (upload_icons.py output) to every key that shares the image."""
    data = json.loads(IDS.read_text(encoding="utf-8"))
    first = primaries()
    missing = []
    for key, render in KEYS.items():
        primary = first[SMALL.get(key, render)]
        if primary in data and isinstance(data[primary], int):
            data[key] = data[primary]
        else:
            missing.append(key)
    ordered = {k: data[k] for k in sorted(k for k in data if not k.startswith("_"))}
    ordered["_hashes"] = data.get("_hashes", {})
    ordered["_aliases"] = {k: first[SMALL.get(k, r)] for k, r in KEYS.items() if first[SMALL.get(k, r)] != k}
    IDS.write_text(json.dumps(ordered, indent=2) + "\n", encoding="utf-8")
    print(f"{len([k for k in ordered if not k.startswith('_')])} keys -> {IDS}" + (f"; MISSING {missing}" if missing else ""))
    return 1 if missing else 0


# ----------------------------------------------------------------------------------------------- sheet

PANELS = [("navy", (42, 47, 107)), ("pink", (255, 97, 172)), ("green", (72, 214, 135)), ("blue", (76, 196, 249))]


def sheet(dest: Path = SHEET, keys: list[str] | None = None) -> None:
    """Every key at 256 (on the navy window), 64 and 24 px (on navy, pink, green, blue buttons)."""
    files = sorted(OUT.glob("*.png"))
    if keys:
        files = [f for f in files if f.stem in keys]
    try:
        font = ImageFont.truetype(str(Path.home() / ".claude/skills/roblox-ui/references/fonts/FredokaOne-Regular.ttf"), 18)
    except OSError:
        font = ImageFont.load_default()
    cw, ch, cols = 560, 300, 4
    rows = (len(files) + cols - 1) // cols
    sh = Image.new("RGB", (cols * cw, rows * ch), (20, 22, 52))
    d = ImageDraw.Draw(sh)
    for i, f in enumerate(files):
        x, y = (i % cols) * cw + 8, (i // cols) * ch + 8
        im = Image.open(f).convert("RGBA")
        d.rectangle([x, y, x + 255, y + 255], fill=PANELS[0][1])
        sh.paste(im, (x, y), im)
        for j, (_, col) in enumerate(PANELS):
            bx, by = x + 268 + (j % 2) * 140, y + (j // 2) * 92
            d.rounded_rectangle([bx, by, bx + 84, by + 84], 12, fill=col)
            m = _premul_resize(im, (64, 64))
            sh.paste(m, (bx + 10, by + 10), m)
            sx, sy = bx + 92, by + 26
            d.rounded_rectangle([sx, sy, sx + 34, sy + 34], 6, fill=col)
            t = _premul_resize(im, (24, 24))
            sh.paste(t, (sx + 5, sy + 5), t)
        d.text((x + 268, y + 196), f.stem, fill=(255, 255, 255), font=font)
    sh.save(dest)
    print(f"sheet -> {dest}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--sheet", action="store_true", help="only redraw the contact sheet")
    ap.add_argument("--ids", action="store_true", help="after upload_icons.py: map every key to its image id")
    a = ap.parse_args()
    if a.ids:
        return write_ids()
    if not a.sheet:
        build()
    sheet()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
