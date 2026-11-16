"""RETIRED 2026-11-15 (icons v4). Do not use this to post-process icons.

The v3 version of this file gave every glossy icon an ink outline AND a white keyline outside it. The owner
called that out ("the icons have like 2 borders, a black and a white at the end. it looks so weird"), and its
fit step let subjects run to the canvas edge. Both are gone:

    python tools/ui/icons_v4.py          # the ONE post-process now: trim, centre, ONE thin ink outline, 256 px
    python tools/ui/icon_fit_check.py    # the framing gate

`family()` is kept only so an old import cannot bring the double border back: it delegates to
`icons_v4.frame`, which draws a single ink outline and never a keyline. Running this file exits 1.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))


def family(im, shadow=True):  # noqa: ARG001 - signature kept for old callers
    from icons_v4 import frame  # noqa: PLC0415

    return frame(im)


def main() -> int:
    print(__doc__.strip())
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
