"""Two rigs at once: the carrier (scale 1) and a carried hero (scale HERO_S) as oriented part boxes, from the
pure-Python FK (fkmodel.py), with exact box-box penetration depths (separating-axis test).

Rest boxes are the MrXen0 rig's real part-mesh bounds (read in Blender 2026-11-16: every part is a rigid
box-like mesh parented to its bone). Rig space: +X right, +Y forward, +Z up, origin = rest HumanoidRootPart.

A hero placement is (T, R): hero rig point p -> carrier rig point T + R @ (HERO_S * p).
"""
import numpy as np

import fkmodel as F

HERO_S = 0.55

# part: (rest box lo, rest box hi, pivot key, delta key)  (pivot key names a point in fk() output)
_L, _R = "L", "R"
REST_BOX = {
    "Head": ((-0.6, -0.6, 0.9), (0.6, 0.6, 2.1)),
    "UpperTorso": ((-1.0, -0.5, -0.6), (1.0, 0.5, 1.0)),
    "LowerTorso": ((-1.0, -0.5, -1.0), (1.0, 0.5, -0.6)),
    "RightUpperArm": ((1.0, -0.5, -0.216), (2.0, 0.5, 0.953)),
    "RightLowerArm": ((1.0, -0.5, -0.75), (2.0, 0.5, 0.302)),
    "RightHand": ((1.0, -0.5, -1.0), (2.0, 0.5, -0.7)),
    "RightUpperLeg": ((0.0, -0.5, -2.029), (1.0, 0.5, -0.812)),
    "RightLowerLeg": ((0.0, -0.5, -2.797), (1.0, 0.5, -1.604)),
    "RightFoot": ((0.0, -0.5, -3.0), (1.0, 0.5, -2.7)),
}
for _k in list(REST_BOX):
    if _k.startswith("Right"):
        lo, hi = REST_BOX[_k]
        REST_BOX["Left" + _k[5:]] = ((-hi[0], lo[1], lo[2]), (-lo[0], hi[1], hi[2]))

_REST = F.fk({}, 0.0)
# part -> (fk point key of its pivot, fk delta key)
LINK = {"Head": ("neck", "D_head"), "UpperTorso": ("_piv", "D_up"), "LowerTorso": ("_piv", "D_tor")}
for _s, _n in ((_R, "Right"), (_L, "Left")):
    LINK.update({f"{_n}UpperArm": ("shoulder" + _s, "Dupper" + _s), f"{_n}LowerArm": ("elbow" + _s, "Dfore" + _s),
                 f"{_n}Hand": ("wrist" + _s, "Dhand" + _s), f"{_n}UpperLeg": ("hip" + _s, "Dthigh" + _s),
                 f"{_n}LowerLeg": ("knee" + _s, "Dshin" + _s), f"{_n}Foot": ("ankle" + _s, "Dfoot" + _s)})
PARTS = list(LINK)
ADJ = {frozenset(p) for p in [("Head", "UpperTorso"), ("UpperTorso", "LowerTorso"), ("UpperTorso", "RightUpperArm"),
                              ("UpperTorso", "LeftUpperArm"), ("RightUpperArm", "RightLowerArm"),
                              ("RightLowerArm", "RightHand"), ("LeftUpperArm", "LeftLowerArm"),
                              ("LeftLowerArm", "LeftHand"), ("LowerTorso", "RightUpperLeg"),
                              ("LowerTorso", "LeftUpperLeg"), ("RightUpperLeg", "RightLowerLeg"),
                              ("RightLowerLeg", "RightFoot"), ("LeftUpperLeg", "LeftLowerLeg"),
                              ("LeftLowerLeg", "LeftFoot")]}


def _pt(o, key, off):
    if key == "_piv":
        return F.PIVOT + off
    return o[key]


def boxes(bones, root=0.0, T=None, R=None, s=1.0):
    """{part: (centre, axes 3x3 (columns), half extents)} in carrier rig space."""
    o = F.fk(bones, root)
    r0 = F.root_vec(root)
    T = np.zeros(3) if T is None else np.asarray(T, float)
    R = np.eye(3) if R is None else np.asarray(R, float)
    out = {}
    for p, (pk, dk) in LINK.items():
        lo, hi = (np.asarray(v, float) for v in REST_BOX[p])
        c0, h = (lo + hi) / 2, (hi - lo) / 2
        piv0 = _pt(_REST, pk, np.zeros(3))
        D = o[dk]
        c = _pt(o, pk, r0) + D @ (c0 - piv0)
        out[p] = (T + R @ (s * c), R @ D, s * h)
    return out


def corners(b):
    c, A, h = b
    return [c + A @ (h * np.array([x, y, z])) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]


def depth(a, b):
    """Penetration depth of two oriented boxes (0 if separated): the smallest overlap over the 15 SAT axes."""
    ca, A, ha = a
    cb, B, hb = b
    d = cb - ca
    axes = [A[:, i] for i in range(3)] + [B[:, i] for i in range(3)]
    for i in range(3):
        for j in range(3):
            v = np.cross(A[:, i], B[:, j])
            n = np.linalg.norm(v)
            if n > 1e-6:
                axes.append(v / n)
    best = 1e9
    for ax in axes:
        ra = sum(ha[i] * abs(ax @ A[:, i]) for i in range(3))
        rb = sum(hb[i] * abs(ax @ B[:, i]) for i in range(3))
        ov = ra + rb - abs(ax @ d)
        if ov <= 0:
            return 0.0
        best = min(best, ov)
    return best


def clashes(A, B, skip=(), self_=False, tol=0.0):
    """Worst-first list of (depth, partA, partB) between two box sets (or within one, non-adjacent)."""
    out = []
    ka, kb = list(A), list(B)
    for i, pa in enumerate(ka):
        for j, pb in enumerate(kb):
            if self_ and (j <= i or frozenset((pa, pb)) in ADJ):
                continue
            if (pa, pb) in skip:
                continue
            dd = depth(A[pa], B[pb])
            if dd > tol:
                out.append((dd, pa, pb))
    return sorted(out, reverse=True)


def gap(a, b, n=6):
    """Rough clearance between two boxes (0 if touching / overlapping): min distance over sampled surface points."""
    if depth(a, b) > 0:
        return 0.0
    ca, A, ha = a
    pts = [ca + A @ (ha * np.array([x, y, z])) for x in np.linspace(-1, 1, n) for y in np.linspace(-1, 1, n)
           for z in np.linspace(-1, 1, n)]
    cb, B, hb = b
    best = 1e9
    for p in pts:
        q = B.T @ (p - cb)
        e = np.maximum(np.abs(q) - hb, 0)
        best = min(best, float(np.linalg.norm(e)))
    return best
