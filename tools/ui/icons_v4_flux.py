"""Icons v4, the rendered half: FLUX.1-schnell on Cloudflare Workers AI.

    python tools/ui/icons_v4_flux.py --only Gift,Crown          # -> work/icons_v4/raw/<Key>__<n>.png
    python tools/ui/icons_v4_flux.py --only Gift --variant b    # an alternative prompt for one key

Every take is KEPT (`<Key>__<n>.png`, n counts up), because the endpoint has no seed: a reroll is a new
image and a good earlier take must never be overwritten by a worse later one. The pick per key is made by
eye on the contact sheet and recorded in `tools/ui/icons_v4.py` (PICKS).

The framing is our own, NOT the roblox-ui skill's ICON_HEAD/ICON_TAIL: those ask for "flat vector ... thick
dark outline, bold flat colours", which is exactly the plain emoji look the owner rejected. The head carries
what decides usability (one object, centred, whole, flat grey ground) because CLIP truncates at 77 tokens;
the shared style anchor follows the subject. Credentials are read inside Python (CF_ACCOUNT_ID,
CF_API_TOKEN) through the skill's `env()`; nothing is printed.
"""

from __future__ import annotations

import argparse
import sys
import time
import urllib.error
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "work" / "icons_v4" / "raw"
SKILL = Path.home() / ".claude" / "skills" / "roblox-ui" / "scripts"
sys.path.insert(0, str(SKILL))
from gen_icons_cf import env, estimate_neurons, generate  # noqa: E402

HEAD = "single glossy 3D game icon, one object, whole object fully in frame, centered, plain flat light grey background"
STYLE = ("premium mobile game UI icon render, vibrant saturated colours, glossy plastic, soft studio light from top left, "
         "bright specular highlight, soft rim light, no outline, no shadow, no text")

# key -> subject. Short and concrete: the subject decides the silhouette, the style anchor decides the look.
SUBJECTS = {
    "Yen": "a thick gold coin facing the viewer with an embossed yen sign, chunky raised rim",
    "Power": "a purple and silver dumbbell lying horizontal, chunky round weights",
    "Luck": "a green four leaf clover with a short stem, chunky rounded leaves",
    "LuckyThrow": "a golden four pointed sparkle star with a small sparkle beside it",
    "Squad": "two cute chibi anime heads side by side, blue team badge style",
    "Index": "a closed blue hardcover book with a gold star on the cover",
    "Shop": "an orange ramen bowl with noodles and chopsticks",
    "Store": "a large pink diamond gem cut with facets",
    "Rebirth": "a golden circular arrow loop, a chunky refresh arrow",
    "Gift": "a red gift box with a gold ribbon and a big bow",
    "Settings": "a chunky light blue cog gear",
    "Codes": "a purple ticket coupon with a gold star in the middle",
    "Crown": "a gold crown with red and blue jewels",
    "Lock": "a gold padlock with a silver shackle and a keyhole",
    "Timer": "a round stopwatch with a gold frame and a white face",
    "Sell": "a red price tag with a gold ring and string",
    "Fuse": "two glowing purple orbs merging into one with a plus sparkle",
    "Bench": "a red cushioned park bench, side view",
    "Place": "a golden pedestal platform with a green down arrow above it",
    "Scroll": "a rolled parchment scroll tied with a red ribbon",
    "Throw": "a rice ball flying fast to the right with motion speed lines",
    "Auto": "a green round play button with a white triangle and a circular arrow",
    "FlavorSavory": "a rice ball onigiri with a nori seaweed strip",
    "FlavorSweet": "a pink swirl lollipop on a stick",
    "FlavorSpicy": "a red chili pepper with a green stem and a small flame",
    "FlavorSeafood": "a cute blue fish, side view",
}
VARIANTS = {  # alternative subjects for keys whose first wording failed; --variant b
    "b": {},
}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", required=True, help="comma separated keys (without Icon prefix)")
    ap.add_argument("--variant", default=None)
    ap.add_argument("--subject", default=None, help="override the subject for a single key")
    ap.add_argument("--takes", type=int, default=1)
    args = ap.parse_args()
    if not (env("CF_ACCOUNT_ID") and env("CF_API_TOKEN")):
        raise SystemExit("CF_ACCOUNT_ID / CF_API_TOKEN not set")
    keys = [k.strip() for k in args.only.split(",") if k.strip()]
    RAW.mkdir(parents=True, exist_ok=True)
    per = estimate_neurons(1024, 4)
    print(f"{len(keys) * args.takes} images ~= {per * len(keys) * args.takes:.0f} neurons")
    log = RAW / "prompts.log"
    for key in keys:
        subject = args.subject or (VARIANTS.get(args.variant or "", {}).get(key)) or SUBJECTS[key]
        prompt = f"{HEAD}, {subject}, {STYLE}"
        for _ in range(args.takes):
            n = 1 + max([int(p.stem.split("__")[1]) for p in RAW.glob(f"{key}__*.png")] or [0])
            dest = RAW / f"{key}__{n}.png"
            t = time.time()
            try:
                dest.write_bytes(generate(prompt, 1024, 4, None))
            except urllib.error.HTTPError as exc:
                print(f"  {key}: HTTP {exc.code} {exc.read()[:200].decode(errors='ignore')}")
                if exc.code == 429:
                    return 1
                continue
            except Exception as exc:  # noqa: BLE001 - one bad icon must not kill a batch
                print(f"  {key}: FAILED {exc}")
                continue
            with log.open("a", encoding="utf-8") as fh:
                fh.write(f"{dest.name}\t{prompt}\n")
            print(f"  {dest.name}  {time.time() - t:.1f}s")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
