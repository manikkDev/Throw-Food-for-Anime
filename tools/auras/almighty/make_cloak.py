#!/usr/bin/env python3
"""TheAlmighty's shadow CLOAK (Yhwach): mesh, texture and anchor points, made from maths.

    python tools/auras/almighty/make_cloak.py
        -> assets/auras/almighty/cloak.obj         the mesh, in Yhwach's ROOT space, Roblox axes (x right, y up,
                                                    front -Z), feet at y -3; two layers (outer + inner, reversed)
           assets/auras/almighty/cloak.png         its texture (u round him, v collar -> hem)
           assets/auras/almighty/cloak_points.json eye anchors ON the outer surface (+ normals) and hem anchors,
                                                    and the mesh's bounding-box centre (Roblox recentres a mesh)
    then:  <blender 4.5> -b --python tools/auras/almighty/obj_to_fbx_one.py -- <obj> <fbx>

The shape (The Almighty as a cloak): a high collar ring round his neck, a mantle over his shoulders that clears
his arms (x +-2), his long hair (to ~0.9 behind his back) and his own cape (to ~1.5 behind his heels; its bounding
box, x -3.24..2.98 z 2.45, is far bigger than the mesh), falling in deepening folds to a
hem torn into long points that reach the floor. Open at the front so he stays visible; the opening narrows to a
clasp at the collar.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets" / "auras" / "almighty"

N_PHI = 84   # segments round him
N_V = 36     # rows collar -> hem

# (v, y, half-width a, front half-depth, back half-depth, centre z): the cross-sections, collar to hem
KEYS = [
    # a HIGH collar that hides his own cape's collar (it rises to y ~1.67 round his neck)
    (0.00, 1.90, 0.95, 0.80, 1.05, 0.05),
    (0.07, 1.50, 1.62, 1.00, 1.15, 0.05),
    (0.13, 1.10, 2.32, 1.08, 1.20, 0.06),
    (0.22, 0.50, 2.42, 1.10, 1.28, 0.10),
    # wider low down: his cape spreads to x -3.2 .. 3.0 near the floor
    (0.55, -1.20, 3.05, 1.25, 1.75, 0.20),
    (1.00, -2.95, 3.45, 1.45, 2.20, 0.30),
]


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def key_at(v: float):
    """C1-smooth (PCHIP) through the keys: a smoothstep per segment flattened the slope at every key and drew a
    horizontal crease across the cloth"""
    from scipy.interpolate import PchipInterpolator
    ks = np.array(KEYS)
    return [float(PchipInterpolator(ks[:, 0], ks[:, i])(v)) for i in range(1, ks.shape[1])]


def opening(v: float) -> float:
    """half-angle (deg) of the cloak's sweep from the BACK: 150 at the collar (a clasp), 128 at the hem"""
    return 150 - 22 * min(max((v - 0.08) / 0.6, 0), 1)


def hem_y(phi_deg: np.ndarray) -> np.ndarray:
    """the torn hem: sixteen long points reaching the floor, the cloth between them torn up to ~0.7 higher"""
    period = 360 / 16
    f = ((phi_deg + 7.0) / period) % 1.0
    tri = 1 - np.abs(f * 2 - 1)                    # 1 at a point, 0 between
    jag = 0.10 * np.sin(np.radians(phi_deg) * 23 + 0.7)
    rng = np.random.default_rng(3)
    length = np.interp(phi_deg, np.linspace(-180, 180, 17), rng.uniform(0.8, 1.0, 17))
    return -2.95 + 0.72 * (1 - tri ** 1.7 * length) + jag * (1 - tri)


def surface():
    vs = np.linspace(0, 1, N_V + 1)
    rows = []
    for v in vs:
        y, a, bf, bb, cz = key_at(float(v))
        half = opening(float(v))
        # wavy opening edges, slightly torn low down
        phis = np.linspace(-half, half, N_PHI + 1)
        ph = np.radians(phis)
        # folds: deepen down the cloth and lean a little (the cloth hangs from the shoulders, not straight down)
        lean = 0.9 * v
        fold = smooth(0.12, 0.7, v) * (0.07 * np.sin(9 * ph + 0.4 + lean) + 0.04 * np.sin(15 * ph + 1.3 - lean)
                                        + 0.022 * np.sin(27 * ph + 2.0 + 2 * lean) + 0.012 * np.sin(41 * ph))
        b = np.where(np.cos(ph) >= 0, bb, bf)
        x = a * np.sin(ph) * (1 + fold)
        z = cz + b * np.cos(ph) * (1 + fold)
        # the collar dips toward the front; low rows run down to the torn hem
        yy = np.full_like(ph, y)
        yy = yy - (0.42 * (1 - np.cos(ph)) / 2) * (1 - smooth(0.0, 0.13, v))
        if v > 0.55:
            t = (v - 0.55) / 0.45
            yy = y + (hem_y(phis) - (-2.95)) * t ** 1.4 + (KEYS[-1][1] - y) * 0  # y already moves to -2.95
            # the points flare out a little
            flare = 1 + 0.06 * t * (1 - smooth(-2.9, -2.4, yy))
            x = x * flare
            z = cz + (z - cz) * flare
        rows.append(np.stack([x, yy, z], 1))
    return np.stack(rows, 0), vs  # (N_V+1, N_PHI+1, 3)


def normals(P):
    du = np.gradient(P, axis=1)
    dv = np.gradient(P, axis=0)
    n = np.cross(dv, du)
    n /= np.linalg.norm(n, axis=2, keepdims=True) + 1e-9
    # outward = away from the vertical axis through his body
    out = P.copy()
    out[..., 1] = 0
    out[..., 2] -= 0.25
    sign = np.sign(np.sum(n * out, axis=2, keepdims=True))
    return n * np.where(sign == 0, 1, sign)


def write_obj(P, path: Path):
    R, C = P.shape[0], P.shape[1]
    lines = ["# TheAlmighty cloak (tools/auras/almighty/make_cloak.py): Roblox axes, Yhwach root space"]
    N = normals(P)
    for layer in (0, 1):
        for r in range(R):
            for c in range(C):
                x, y, z = P[r, c]
                lines.append(f"v {x:.5f} {y:.5f} {z:.5f}")
    for layer in (0, 1):
        for r in range(R):
            for c in range(C):
                lines.append(f"vt {c / (C - 1):.5f} {1 - r / (R - 1):.5f}")
    for layer in (0, 1):
        s = 1 if layer == 0 else -1
        for r in range(R):
            for c in range(C):
                nx, ny, nz = N[r, c] * s
                lines.append(f"vn {nx:.5f} {ny:.5f} {nz:.5f}")
    off = R * C
    for layer in (0, 1):
        base = layer * off
        for r in range(R - 1):
            for c in range(C - 1):
                i00 = base + r * C + c + 1
                i01 = base + r * C + c + 2
                i10 = base + (r + 1) * C + c + 1
                i11 = base + (r + 1) * C + c + 2
                quad = [(i00, i10, i11), (i00, i11, i01)]
                for tri in quad:
                    if layer == 1:
                        tri = tri[::-1]
                    lines.append("f " + " ".join(f"{i}/{i}/{i}" for i in tri))
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return 2 * 2 * (R - 1) * (C - 1)


def anchors(P, vs):
    """eye anchors ON the outer surface (densest on the shoulders and back) and hem anchors on the torn edge"""
    N = normals(P)
    rng = np.random.default_rng(17)
    eyes = []
    plan = [(0.09, 6), (0.16, 8), (0.24, 8), (0.33, 8), (0.43, 7), (0.53, 6), (0.64, 5), (0.75, 4)]
    for v, count in plan:
        r = int(round(v * (len(vs) - 1)))
        cols = np.linspace(0.08, 0.92, count) + rng.uniform(-0.03, 0.03, count)
        if r % 2:
            cols = cols + 0.5 / count * 0.84
        for u in np.clip(cols, 0.06, 0.94):
            c = int(round(u * (P.shape[1] - 1)))
            p = P[r, c] + N[r, c] * 0.045
            eyes.append({"p": [round(float(x), 4) for x in p], "n": [round(float(x), 4) for x in N[r, c]],
                         "size": round(float(0.17 + 0.09 * rng.random() + (0.05 if v < 0.3 else 0)), 3)})
    hem = []
    phis = np.linspace(-opening(1.0), opening(1.0), P.shape[1])
    last = P[-1]
    for c in range(2, P.shape[1] - 2, 3):
        # on the hem edge, a little up the cloth so the strands hang from the edge itself
        r = P.shape[0] - 3
        p = P[r, c] + N[r, c] * 0.03
        hem.append({"p": [round(float(x), 4) for x in p], "phi": round(float(phis[c]), 2)})
    del last
    return eyes, hem


def texture(size=1024) -> Image.Image:
    """black cloak cloth: long liquid flow streaks, faint sleeping eyes, a glossy dark-blue rim on its edges"""
    rng = np.random.default_rng(5)
    yy, xx = np.mgrid[0:size, 0:size].astype(float)
    u = xx / (size - 1)
    v = yy / (size - 1)
    # streaks: noise stretched along v (the cloth's fall), wrapping in u
    base = rng.standard_normal((16, 128))
    streak = ndimage.gaussian_filter(base, (1.2, 2.0), mode="wrap")
    streak = (streak - streak.min()) / np.ptp(streak)
    streak = np.asarray(Image.fromarray((streak * 255).astype(np.uint8)).resize((size, size), Image.BICUBIC), float) / 255
    col = np.array([8, 8, 13.0]) + (np.array([22, 26, 44.0]) - np.array([8, 8, 13.0])) * (streak ** 2.2)[..., None]
    # glossy rim on the opening edges (u ~ 0, 1) and the hem (v ~ 1)
    rim = np.maximum(1 - smooth(0.0, 0.025, np.minimum(u, 1 - u)), smooth(0.94, 1.0, v))
    col = col + (np.array([58, 78, 128.0]) - col) * (rim * 0.85)[..., None]
    # resting eyes, half-lidded and dim, all over the cloth (the bright animated ones open among them). The UV map is
    # stretched: ~10.5 studs round the cloak against ~4.7 tall, so an eye W studs wide is W/10.5 in u, H/4.7 in v.
    U_STUDS, V_STUDS = 10.5, 4.7
    for k in range(46):
        cy = rng.uniform(0.06, 0.82) ** 1.25            # more of them high up, on the shoulders
        cx = rng.uniform(0.05, 0.95)
        w_st = rng.uniform(0.22, 0.42)
        ap = rng.uniform(0.25, 0.55)                     # how open the lid is
        hw, hh = w_st / 2 / U_STUDS, w_st * 0.42 / V_STUDS
        ex = (u - cx) / hw
        ey = (v - cy) / hh
        inside_x = np.abs(ex) < 1
        lid = (1 - np.clip(np.abs(ex), 0, 1) ** 2) ** 0.6
        upper = lid * ap
        lower = -lid * 0.55
        sclera = inside_x & (ey < upper * 0.98) & (ey > lower)
        # the eye's ink socket round it, its heavy upper lid, a dim blue sclera, a pupil looking somewhere
        socket = inside_x & (ey < upper + 0.45) & (ey > lower - 0.35)
        col = np.where(socket[..., None], col * 0.55, col)
        sc = np.array([62, 76, 112.0]) + 30 * (1 - np.clip(np.abs(ey) / (ap + 0.01), 0, 1))[..., None]
        col = np.where(sclera[..., None], sc, col)
        lx = rng.uniform(-0.35, 0.35)
        pupil = sclera & (np.hypot(ex - lx, (ey - upper * 0.3) * 1.6) < 0.22)
        col = np.where(pupil[..., None], np.array([6, 6, 10.0]), col)
        lidline = inside_x & (np.abs(ey - upper) < 0.16)
        col = np.where(lidline[..., None], np.array([4, 4, 8.0]), col)
    return Image.fromarray(np.clip(col, 0, 255).astype(np.uint8), "RGB")


BUILDER = ROOT / "tools" / "studio" / "auras" / "build_almighty.luau"


def write_builder_data(centre, size, eyes, hem) -> None:
    """the cloak's centre, size and anchors into build_almighty.luau's generated block (it runs as one file)"""
    v3 = lambda p: f"Vector3.new({p[0]:.4f}, {p[1]:.4f}, {p[2]:.4f})"  # noqa: E731
    lines = ["-- BEGIN CLOAK DATA (generated by tools/auras/almighty/make_cloak.py: do not edit by hand)",
             "local CLOAK = {",
             f"	centre = {v3(centre)},",
             f"	size = {v3(size)},",
             "	eyes = {"]
    lines += [f"		{{ p = {v3(e['p'])}, size = {e['size']} }}," for e in eyes]
    lines += ["	},", "	hem = {"]
    lines += [f"		{{ p = {v3(h['p'])} }}," for h in hem]
    lines += ["	},", "}", "-- END CLOAK DATA"]
    text = BUILDER.read_text(encoding="utf-8")
    i = text.index("-- BEGIN CLOAK DATA")
    j = text.index("-- END CLOAK DATA") + len("-- END CLOAK DATA")
    BUILDER.write_text(text[:i] + "\n".join(lines) + text[j:], encoding="utf-8")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    P, vs = surface()
    tris = write_obj(P, OUT / "cloak.obj")
    lo = P.reshape(-1, 3).min(0)
    hi = P.reshape(-1, 3).max(0)
    centre = (lo + hi) / 2
    eyes, hem = anchors(P, vs)
    (OUT / "cloak_points.json").write_text(json.dumps({
        "_what": "TheAlmighty cloak anchors in Yhwach's ROOT space (Roblox axes); Roblox recentres an imported mesh "
                 "on its bounding box, so the MeshPart sits at 'centre' and attachments are p - centre",
        "centre": [round(float(x), 4) for x in centre], "size": [round(float(x), 4) for x in hi - lo],
        "eyes": eyes, "hem": hem}, indent=1) + "\n", encoding="utf-8")
    texture().save(OUT / "cloak.png")
    write_builder_data(centre, hi - lo, eyes, hem)
    print(f"cloak.obj: {tris} tris, bbox {lo.round(2)} .. {hi.round(2)}, centre {centre.round(3)}")
    print(f"anchors: {len(eyes)} eyes, {len(hem)} hem")


if __name__ == "__main__":
    main()
