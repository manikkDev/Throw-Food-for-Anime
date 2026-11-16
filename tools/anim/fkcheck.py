"""Numeric checks of a generated spec, frame by frame, with the pure-Python FK (fkmodel.py).

  python tools/anim/fkcheck.py Throw TrainStrike ...

Samples every frame exactly as anim_render.py does (per-segment ease, Euler lerp) and prints:
  * feet: lowest foot-box corner vs the floor (z -3.0) and planted-foot slip
  * arms vs body: deepest arm-centreline intrusion into the torso / head boxes (arm half-width 0.45)
  * per marker: each hand's end-face centre and its FRONTMOST corner along the facing (+Y), i.e. the
    contact distance from the HumanoidRootPart to the target's front face.
"""
import json
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fkmodel as F  # noqa: E402

SPECS = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "animations", "specs")
LONG = {"TORSO": "tor", "UpTorso": "up", "HEAD": "head",
        "FK_UpperArm.R": "uar", "FK_LowerArm.R": "lar", "FK_Hand.R": "har",
        "FK_UpperArm.L": "ual", "FK_LowerArm.L": "lal", "FK_Hand.L": "hal",
        "FK_UpperLeg.R": "ulr", "FK_LowerLeg.R": "llr", "FK_Foot.R": "fr",
        "FK_UpperLeg.L": "ull", "FK_LowerLeg.L": "lll", "FK_Foot.L": "fl"}
EASE = {"smooth": lambda f: f * f * (3 - 2 * f), "linear": lambda f: f,
        "in": lambda f: f * f, "out": lambda f: 1 - (1 - f) * (1 - f)}
FOOT_OFF = [np.array([x, y, z]) for x in (-0.5, 0.5) for y in (-0.5, 0.5) for z in (-0.252, 0.048)]
HAND_OFF = [np.array([x, y, z]) for x in (-0.5, 0.5) for y in (-0.5, 0.5) for z in (-0.275, 0.025)]
FACE_OFF = [np.array([x, y, -0.275]) for x in (-0.5, 0.5) for y in (-0.5, 0.5)]


def sample(spec, t):
    keys = spec["keyframes"]
    out, root = {}, 0.0
    for bone in keys[0]["bones"]:
        field = "loc" if bone == "ROOT" else "rot"
        ks = [k for k in keys if bone in k["bones"]]
        if t <= ks[0]["t"]:
            v = ks[0]["bones"][bone][field]
        elif t >= ks[-1]["t"]:
            v = ks[-1]["bones"][bone][field]
        else:
            for a, b in zip(ks, ks[1:]):
                if a["t"] <= t <= b["t"]:
                    span = b["t"] - a["t"]
                    f = 0.0 if span == 0 else EASE[a.get("ease", "smooth")]((t - a["t"]) / span)
                    va, vb = a["bones"][bone][field], b["bones"][bone][field]
                    v = [va[i] + (vb[i] - va[i]) * f for i in range(3)]
                    break
        if bone == "ROOT":
            root = np.array([-v[0], -v[1], v[2]])   # ROOT loc -> world offset (fkmodel.root_loc inverse)
        elif bone in LONG:
            out[LONG[bone]] = v
    return out, root


def box_local(p, D, pivot, centre, half):
    """Penetration depth of point p into a box (half extents) posed by rotation D about pivot."""
    q = D.T @ (p - pivot) + pivot - centre
    d = half - np.abs(q)
    return float(min(d)) if np.all(d > 0) else 0.0


def body_boxes(o, b):
    Dt, Du = o["D_tor"], o["D_up"]
    Dh = Du @ F.local_delta(F.B_BODY, np.asarray(b.get("head", [0, 0, 0]), float))
    piv = o["neck"] - Du @ (F.NECK - F.PIVOT)
    return [("UpperTorso", Du, piv, np.array([0, 0, 0.2]), np.array([1.0, 0.5, 0.8])),
            ("LowerTorso", Dt, piv, np.array([0, 0, -0.8]), np.array([1.0, 0.5, 0.2])),
            ("Head", Dh, o["neck"], np.array([0, 0, 1.5]), np.array([0.6, 0.6, 0.6]))]


def arm_points(o, s):
    pts = []
    sh_ctr = o["shoulder" + s] + (o["elbow" + s] - o["shoulder" + s]) * 0.0
    # the arm's centre line: from the shoulder joint's outer half down through elbow, wrist, fist
    segs = [(o["elbow" + s] + (o["shoulder" + s] - o["elbow" + s]) * 0.35, o["elbow" + s]),
            (o["elbow" + s], o["wrist" + s]), (o["wrist" + s], o["fist" + s])]
    for a, c in segs:
        for k in range(5):
            pts.append(a + (c - a) * k / 4)
    del sh_ctr
    return pts


def check(name, quiet=False):
    spec = json.load(open(os.path.join(SPECS, name + ".json")))
    fps, dur, loop = spec["fps"], spec["duration"], spec.get("loop", False)
    n = int(round(dur * fps)) + (0 if loop else 1)
    lines = []
    worst_floor = {"R": (9, 0), "L": (9, 0)}
    slip = {"R": 0.0, "L": 0.0}
    prev = {}
    worst_pen = (0.0, None, None)
    reach = {"R": (-9, 0), "L": (-9, 0)}
    for i in range(n):
        t = i / fps
        b, root = sample(spec, t)
        o = F.fk(b, root)
        for s in ("R", "L"):
            low = min((o["ankle" + s] + o["Dfoot" + s] @ c)[2] for c in FOOT_OFF)
            gap = low - F.FLOOR
            if gap < worst_floor[s][0]:
                worst_floor[s] = (gap, t)
            a = o["ankle" + s]
            if s in prev and abs(gap) < 0.03 and abs(prev[s][1]) < 0.03:
                slip[s] = max(slip[s], float(np.linalg.norm((a - prev[s][0])[:2])))
            prev[s] = (a, gap)
        for s in ("R", "L"):
            fy = max((o["wrist" + s] + o["Dhand" + s] @ c)[1] for c in HAND_OFF)
            if fy > reach[s][0]:
                reach[s] = (fy, t)
            for p in arm_points(o, s):
                for nm, D, piv, ctr, half in body_boxes(o, b):
                    d = box_local(p, D, piv, ctr, half + 0.45)
                    if d > worst_pen[0]:
                        worst_pen = (d, f"{s} arm into {nm}", t)
    lines.append(f"=== {name}: {n} frames")
    for s in ("R", "L"):
        g, t = worst_floor[s]
        lines.append(f"  foot {s}: lowest corner {g:+.3f} vs floor (t={t:.3f}); planted slip max {slip[s]:.3f}/frame")
    cd = spec.get("_contact", {}).get("contact_distance")
    for s in ("R", "L"):
        over = f" -> {'THROUGH the target by ' + format(reach[s][0] - cd, '.3f') if reach[s][0] > cd + 0.02 else 'never past the target'}" if cd else ""
        lines.append(f"  hand {s}: furthest front-y over the take {reach[s][0]:.3f} (t={reach[s][1]:.3f}){over}")
    lines.append(f"  arm/body intrusion max {worst_pen[0]:.3f} ({worst_pen[1]} t={worst_pen[2]})")
    for m in spec.get("markers", []):
        b, root = sample(spec, m["time"])
        o = F.fk(b, root)
        cells = []
        for s in ("R", "L"):
            corners = [o["wrist" + s] + o["Dhand" + s] @ c for c in HAND_OFF]
            face = [o["wrist" + s] + o["Dhand" + s] @ c for c in FACE_OFF]
            fy = max(c[1] for c in corners)
            fc = o["fist" + s]
            cells.append(f"{s}: face-centre ({fc[0]:+.2f},{fc[1]:+.2f},{fc[2]:+.2f}) front-y {fy:.3f} "
                         f"face-y {min(c[1] for c in face):.2f}..{max(c[1] for c in face):.2f}")
        lines.append(f"  {m['name']} t={m['time']}: " + " | ".join(cells))
    if not quiet:
        print("\n".join(lines))
    return lines


if __name__ == "__main__":
    for nm in sys.argv[1:]:
        check(nm)
