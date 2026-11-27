"""One-off search (batch r8, TrainBreath v2): FK key poses for the right arm (left mirrors) so the hands travel up
the centre line with the elbows by the ribs. Scores hand-centre position, forearm direction and real part overlaps.
Prints the poses to paste into clips_r8.TB_POSE."""
import itertools
import sys

import numpy as np

import clips_r8 as M
import fkmodel as F
from clips_r3 import hand_centre

# key: (frame, hand centre in REST upper-torso coordinates (x right, y fwd, z up; z +root at use), forearm dir)
KEYS = {
    "lap":    (0, (0.62, 1.0, 0.0), (-0.75, 0.55, 0.0)),
    "belly":  (40, (0.62, 1.1, 0.3), (-0.7, 0.6, 0.25)),
    "gather": (70, (0.62, 1.2, 0.6), (-0.65, 0.6, 0.45)),
    "turn":   (79, (0.62, 1.25, 0.5), (-0.7, 0.7, 0.0)),
    "press":  (86, (0.62, 1.1, 0.12), (-0.7, 0.6, -0.3)),
}


def search(name):
    f, c_rest, fd = KEYS[name]
    root, tor, up, head = M.breath_body(f)
    c = M.torso_pt(tor, up, root, c_rest)
    o0 = F.fk({"tor": tor, "up": up}, root)
    fd = M.unit(o0["D_up"] @ np.array(fd))
    legs = M.seat_legs(0)
    base = {"tor": tor, "up": up, "head": head}
    for s in "RL":
        base["ul" + s.lower()], base["ll" + s.lower()], base["f" + s.lower()] = legs[s]["ul"], legs[s]["ll"], legs[s]["f"]
    cand = []
    for ux, uy, uz, la in itertools.product(range(-90, 31, 10), range(-120, 121, 15), range(-30, 41, 10),
                                            range(-140, -19, 10)):
        o = F.fk({"tor": tor, "up": up, "uar": [ux, uy, uz], "lar": [la, 0, 0]}, root)
        e = np.linalg.norm(hand_centre(o, "R") - c)
        d = 1 - float(o["DforeR"] @ np.array([0, 0, -1.0]) @ fd)
        el = abs(o["elbowR"][0] - 1.5)          # elbow by the ribs (arm's rest line)
        cand.append((e + 0.6 * d + 0.3 * el, ux, uy, uz, la))
    cand.sort()
    best = None
    for sc, ux, uy, uz, la in cand[:150]:
        o = F.fk({**base, "uar": [ux, uy, uz], "lar": [la, 0, 0]}, root)
        ov = sum(v for k, v in M.overlaps(o).items() if "Right" in k[0] + k[1] and ("Arm" in k[0] + k[1] or "Hand" in k[0] + k[1]))
        tot = sc + 3 * ov
        if best is None or tot < best[0]:
            best = (tot, sc, ov, [ux, uy, uz], la, np.round(hand_centre(o, "R"), 2), np.round(o["elbowR"], 2))
    print(name, f"score {best[0]:.3f} pos+dir {best[1]:.3f} overlap {best[2]:.3f} ua {best[3]} la {best[4]} hand {best[5]} elbow {best[6]}")


if __name__ == "__main__":
    for n in sys.argv[1:] or KEYS:
        search(n)
