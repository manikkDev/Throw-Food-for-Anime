"""Framing gate for UI icons: nothing cut off, nothing off centre.

    python tools/ui/icon_fit_check.py                                  # assets/ui/icons_v4
    python tools/ui/icon_fit_check.py --dir assets/ui/icons_v4 --sources work/icons_v4/render

Per icon (owner brief 2026-11-15: "some icons are exceeding 1:1 ratio so their ends are being cut"):
  size     256 x 256, RGBA
  margin   the alpha bounding box lies inside the central 88 % (>= 6 % transparent margin on every side)
  edge     no pixel with any alpha within 4 px of an edge
  centre   the visual centre (alpha-weighted centroid) is within 3 % of the square's centre
  empty    the icon has a subject at all
--sources also checks the raw renders the icons were cut from: a subject touching the render's border was
cropped BEFORE framing, and no amount of re-centring brings the missing part back.
Exit 1 and a list of offenders on any failure.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SIDE = 256
MARGIN = 0.06
EDGE_PX = 4
CENTRE_TOL = 0.03
ALPHA_MIN = 3  # alpha at or below this is resampling dust, not subject


def check_icon(path: Path) -> list[str]:
    im = Image.open(path)
    errs = []
    if im.size != (SIDE, SIDE):
        errs.append(f"size {im.size[0]}x{im.size[1]} (want {SIDE}x{SIDE})")
    if im.mode != "RGBA":
        errs.append(f"mode {im.mode} (want RGBA)")
        im = im.convert("RGBA")
    a = np.asarray(im)[..., 3].astype(np.float64)
    h, w = a.shape
    mask = a > ALPHA_MIN
    if not mask.any():
        return errs + ["empty (no subject)"]
    ys, xs = np.where(mask)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    sides = {"left": x0 / w, "right": (w - x1) / w, "top": y0 / h, "bottom": (h - y1) / h}
    tight = {k: v for k, v in sides.items() if v < MARGIN}
    if tight:
        errs.append("margin " + ", ".join(f"{k} {v:.1%}" for k, v in tight.items()) + f" (< {MARGIN:.0%})")
    band = np.zeros_like(mask)
    band[:EDGE_PX], band[-EDGE_PX:], band[:, :EDGE_PX], band[:, -EDGE_PX:] = True, True, True, True
    if (a[band] > 0).any():
        errs.append(f"pixels within {EDGE_PX} px of the edge")
    yy, xx = np.mgrid[0:h, 0:w]
    cx, cy = (a * xx).sum() / a.sum() + 0.5, (a * yy).sum() / a.sum() + 0.5
    off = max(abs(cx - w / 2) / w, abs(cy - h / 2) / h)
    if off > CENTRE_TOL:
        errs.append(f"visual centre off by {off:.1%} (dx {cx - w / 2:+.1f}, dy {cy - h / 2:+.1f} px; tol {CENTRE_TOL:.0%})")
    return errs


def check_source(path: Path) -> list[str]:
    a = np.asarray(Image.open(path).convert("RGBA"))[..., 3]
    border = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    return [f"source render touches its border ({int((border > ALPHA_MIN).sum())} px): subject cropped upstream"] \
        if (border > ALPHA_MIN).any() else []


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", action="append", default=None, help="icon folder (repeatable)")
    ap.add_argument("--sources", default=None, help="folder of raw renders to check for upstream cropping")
    args = ap.parse_args()
    dirs = [Path(d) for d in (args.dir or [ROOT / "assets" / "ui" / "icons_v4"])]
    bad: dict[str, list[str]] = {}
    n = 0
    for d in dirs:
        files = sorted(d.glob("*.png"))
        if not files:
            print(f"FAIL no PNGs in {d}")
            return 1
        for f in files:
            n += 1
            e = check_icon(f)
            if e:
                bad[str(f.relative_to(ROOT) if f.is_relative_to(ROOT) else f)] = e
    if args.sources:
        for f in sorted(Path(args.sources).glob("*.png")):
            n += 1
            e = check_source(f)
            if e:
                bad[str(f)] = e
    if bad:
        print(f"FAIL {len(bad)} of {n} images break the framing rules:")
        for k, v in bad.items():
            print(f"  {k}: " + "; ".join(v))
        return 1
    print(f"ok   {n} images: 256x256 RGBA, >= {MARGIN:.0%} margin on every side, nothing within {EDGE_PX} px of "
          f"an edge, visual centre within {CENTRE_TOL:.0%}" + ("; no source render cropped" if args.sources else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
