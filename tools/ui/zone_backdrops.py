"""Hero Index zone cards: one anime landscape backdrop per zone (FLUX.1-schnell on Cloudflare Workers AI).

    python tools/ui/zone_backdrops.py gen --takes 2          # -> work/zone_bg/raw/<zone>__<n>.png (every take kept)
    python tools/ui/zone_backdrops.py paint                  # no generator quota: painted scenes (zone_paint.py)
    python tools/ui/zone_backdrops.py build                  # picks (PICKS) -> assets/ui/zone_bg/ZoneBg_<zone>.png
    python tools/ui/zone_backdrops.py sheet                  # work/zone_bg/_sheet.png (every take, to pick by eye)
    python ~/.claude/skills/roblox-ui/scripts/upload_icons.py --icons assets/ui/zone_bg --map assets/ui/ids_zone_bg.json
    python tools/gen_icons.py                                # ZoneBg_<zone> keys -> src/shared/Config/Icons.luau

The card is about 2.3 : 1, so the square render is cropped to a horizontal strip around its middle (the horizon),
then darkened a little toward the bottom-left where the zone name sits, so white text reads on any picture.
Credentials (CF_ACCOUNT_ID, CF_API_TOKEN) are read inside the skill's `env()`; nothing is printed.
"""

from __future__ import annotations

import argparse
import sys
import time
import urllib.error
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "work" / "zone_bg" / "raw"
OUT = ROOT / "assets" / "ui" / "zone_bg"
SKILL = Path.home() / ".claude" / "skills" / "roblox-ui" / "scripts"
sys.path.insert(0, str(SKILL))

HEAD = "anime background art, wide establishing landscape shot, no people, no characters, no text"
STYLE = ("vibrant saturated colours, cel shaded anime movie background painting, bright clear sky with soft clouds, "
         "crisp detail, cheerful mobile game key art")
SUBJECTS = {
    "sakura_schoolyard": "a japanese high school courtyard with pink cherry blossom trees in full bloom, petals in the "
                         "air, the school building behind",
    "pirate_harbor": "a sunny pirate harbor with wooden docks, a big pirate ship with sails, turquoise sea and palm trees",
    "ninja_village": "a hidden ninja village of wooden houses with tiled roofs in a green forest valley, stone cliffs "
                     "and paper lanterns",
    "samurai_castle": "a white japanese samurai castle on a stone base, red maple trees, mountains behind, golden hour",
    "hero_city": "a bright modern superhero city skyline with tall glass skyscrapers, a hero tower, blue sky",
    "realm_of_legends": "a mythical floating island realm with glowing purple crystals, waterfalls into clouds, golden "
                        "temple ruins, magical aurora sky",
}
# zone -> chosen take number (set after looking at the sheet)
PICKS = {z: "paint" for z in SUBJECTS}  # "paint" = zone_paint.py; a number = a FLUX take
CARD = (480, 208)


HF_URL = "https://router.huggingface.co/hf-inference/models/black-forest-labs/FLUX.1-schnell"


def generate_hf(prompt: str) -> bytes:
    """FLUX.1-schnell on HuggingFace inference (HF_TOKEN), at a wide size. Used when Cloudflare's daily quota
    is spent (HTTP 429). The token is read here and never printed."""
    import json  # noqa: PLC0415
    import urllib.request  # noqa: PLC0415

    from gen_icons_cf import env  # noqa: PLC0415

    body = {"inputs": prompt, "parameters": {"width": 1024, "height": 448, "num_inference_steps": 4}}
    req = urllib.request.Request(HF_URL, data=json.dumps(body).encode(), method="POST",
                                 headers={"Authorization": f"Bearer {env('HF_TOKEN')}",
                                          "Content-Type": "application/json", "Accept": "image/png"})
    with urllib.request.urlopen(req, timeout=240) as resp:
        return resp.read()


def gen(takes: int, only: list[str] | None, backend: str = "cf") -> int:
    from gen_icons_cf import env, generate  # noqa: PLC0415

    if backend == "hf":
        generate = lambda prompt, *_: generate_hf(prompt)  # noqa: E731
    elif not (env("CF_ACCOUNT_ID") and env("CF_API_TOKEN")):
        raise SystemExit("CF_ACCOUNT_ID / CF_API_TOKEN not set")
    RAW.mkdir(parents=True, exist_ok=True)
    for zone, subject in SUBJECTS.items():
        if only and zone not in only:
            continue
        prompt = f"{HEAD}, {subject}, {STYLE}"
        for _ in range(takes):
            n = 1 + max([int(p.stem.split("__")[1]) for p in RAW.glob(f"{zone}__*.png")] or [0])
            dest = RAW / f"{zone}__{n}.png"
            t = time.time()
            try:
                dest.write_bytes(generate(prompt, 1024, 4, None))
            except urllib.error.HTTPError as exc:
                print(f"  {zone}: HTTP {exc.code}")
                if exc.code == 429:
                    return 1
                continue
            except Exception as exc:  # noqa: BLE001 - one failed take must not kill the batch
                print(f"  {zone}: FAILED {exc}")
                continue
            print(f"  {dest.name}  {time.time() - t:.1f}s")
    return 0


def strip(src: Image.Image) -> Image.Image:
    """Centre strip at the card's aspect, resized, with a soft dark wash low-left for the name."""
    w, h = src.size
    ch = round(w * CARD[1] / CARD[0])
    top = max(0, min(h - ch, round(h * 0.5 - ch * 0.5)))
    im = src.convert("RGB").crop((0, top, w, top + ch)).resize(CARD, Image.LANCZOS)
    wash = Image.new("L", CARD, 0)
    d = ImageDraw.Draw(wash)
    for y in range(CARD[1]):
        a = int(150 * max(0.0, (y / CARD[1] - 0.25) / 0.75) ** 1.4)
        d.line([(0, y), (CARD[0], y)], fill=a)
    wash = wash.filter(ImageFilter.GaussianBlur(6))
    dark = Image.new("RGB", CARD, (10, 12, 40))
    return Image.composite(dark, im, wash)


def paint_all() -> int:
    import zone_paint  # noqa: PLC0415

    RAW.mkdir(parents=True, exist_ok=True)
    for zone in SUBJECTS:
        zone_paint.paint(zone).save(RAW / f"{zone}__paint.png")
        print(f"  {zone}__paint.png")
    return 0


def build() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    for zone, n in PICKS.items():
        src = RAW / f"{zone}__{n}.png"
        if not src.exists():
            print(f"  missing {src.name}")
            continue
        strip(Image.open(src)).save(OUT / f"ZoneBg_{zone}.png")
        print(f"  ZoneBg_{zone}.png <- {src.name}")
    return 0


def sheet() -> int:
    files = sorted(RAW.glob("*.png"))
    cols = 4
    tw, th = 480, 208
    rows = (len(files) + cols - 1) // cols
    out = Image.new("RGB", (cols * (tw + 10) + 10, rows * (th + 30) + 10), (24, 26, 56))
    d = ImageDraw.Draw(out)
    for i, f in enumerate(files):
        x, y = 10 + (i % cols) * (tw + 10), 10 + (i // cols) * (th + 30)
        out.paste(strip(Image.open(f)), (x, y + 20))
        d.text((x, y + 2), f.stem, fill=(255, 255, 255))
    out.save(RAW.parent / "_sheet.png")
    print(RAW.parent / "_sheet.png")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("step", choices=["gen", "paint", "build", "sheet"])
    ap.add_argument("--takes", type=int, default=1)
    ap.add_argument("--only", default=None)
    ap.add_argument("--backend", choices=["cf", "hf"], default="cf")
    a = ap.parse_args()
    if a.step == "gen":
        return gen(a.takes, a.only.split(",") if a.only else None, a.backend)
    if a.step == "paint":
        return paint_all()
    if a.step == "build":
        return build()
    return sheet()


if __name__ == "__main__":
    raise SystemExit(main())
