"""Shared helpers for authoring the game's R15 FK clips as roblox-animation specs.

Rig facts (MrXen0 R15, FK, measured 2026-11-15 by dry probes):
  rig space +X right, +Y forward, +Z up; rest root at 0, ankles at z -2.75, hips at z -1.0.
  FK limb bones: X negative swings forward, Z positive swings to the character's right.
  On a forward-swung limb, Y swings it horizontally (+ toward the character's right).
  Raised sideways arm [0, +90, 90] + elbow -90 = forearm vertical behind the head.
  Thigh rolled Y+90 (right) bends its knee inward (lotus).
  TORSO/UpTorso/HEAD: X positive leans BACK, Y positive turns to the character's LEFT.
  ROOT loc: only Z is used. Z is up 1:1. ROOT loc +Y moved the body BACKWARD in the render,
  the opposite of to_roblox.py's (x, z, -y) map, so no clip translates the root on X/Y.
"""
import json
import math
import os

from scipy.spatial.transform import Rotation as Rot

THIGH, SHIN = 0.822, 0.926          # hip->knee, knee->ankle (traps.md #13)
REST = THIGH + SHIN
PROPS = {"ARM_IK_FK.L": 0.0, "ARM_IK_FK.R": 0.0, "LEG_IK_FK.L": 0.0, "LEG_IK_FK.R": 0.0}
SHORT = {"tor": "TORSO", "up": "UpTorso", "head": "HEAD",
         "uar": "FK_UpperArm.R", "lar": "FK_LowerArm.R", "har": "FK_Hand.R",
         "ual": "FK_UpperArm.L", "lal": "FK_LowerArm.L", "hal": "FK_Hand.L",
         "ulr": "FK_UpperLeg.R", "llr": "FK_LowerLeg.R", "fr": "FK_Foot.R",
         "ull": "FK_UpperLeg.L", "lll": "FK_LowerLeg.L", "fl": "FK_Foot.L"}


def euler(*steps):
    """Compose rotations given as (axis, degrees), FIRST = innermost, into Blender XYZ Euler."""
    r = Rot.identity()
    for ax, d in steps:
        r = Rot.from_euler(ax, d, degrees=True) * r
    return [round(v, 2) for v in r.as_euler("xyz", degrees=True)]


def leg(side, a, root, tx=0.0, spread=0.0, shin_fwd=False, heel=0.0):
    """A PLANTED leg: absolute thigh swing `a` (deg, + forward), ankle on the floor.

    Solves the knee so the ankle sits at rest floor height given the root drop `root`
    and the TORSO lean `tx`. Returns {ul, ll, f} Euler lists. heel>0 lifts the heel.
    """
    s = 1 if side == "R" else -1
    need = (REST + root) / math.cos(math.radians(spread))
    c = (need - THIGH * math.cos(math.radians(a))) / SHIN
    if c > 1.0:
        raise ValueError(f"leg {side} a={a} root={root}: ankle cannot reach the floor")
    sh = math.degrees(math.acos(max(-1.0, c)))
    shin = sh if (shin_fwd and sh <= a) else -sh
    if shin > a:
        shin = -sh
    return {"ul": [round(tx - a, 2), 0, s * spread], "ll": [round(a - shin, 2), 0, 0],
            "f": [round(shin + heel, 2), 0, -s * spread]}


def lift(side, a, knee, tx=0.0, foot=0.0, spread=0.0):
    """A leg off the ground: thigh `a` forward (abs), knee bend `knee` (>=0), foot extra."""
    s = 1 if side == "R" else -1
    return {"ul": [tx - a, 0, s * spread], "ll": [knee, 0, 0], "f": [foot, 0, 0]}


def pose(root=0.0, legs=None, **kw):
    """Full pose: every bone keyed (first-beat and loop-seam rules), zeros by default."""
    b = {name: {"rot": [0, 0, 0]} for name in SHORT.values()}
    b["ROOT"] = {"loc": [0, 0, round(root, 3)]}
    for side, lg in (legs or {}).items():
        sfx = side.lower()
        b[SHORT["ul" + sfx]]["rot"] = list(lg["ul"])
        b[SHORT["ll" + sfx]]["rot"] = list(lg["ll"])
        b[SHORT["f" + sfx]]["rot"] = list(lg["f"])
    for k, v in kw.items():
        b[SHORT[k]]["rot"] = [round(x, 2) for x in v]
    return b


def clip(name, dur, loop, priority, intent, reference, keys, markers=(), views=None, extra=None):
    spec = {
        "name": name, "rbx_name": name, "priority": priority, "loop": loop,
        "fps": 30, "duration": dur, "_intent": intent, "_reference": reference,
        "markers": [{"name": m, "time": t} for m, t in markers],
        "w": 300, "h": 300, "margin": 1.08, "plain": True, "preview": False,
        "views": views or {"front": [0.18, 1.0, 0.12], "side": [1.0, 0.12, 0.08]},
        "properties": dict(PROPS),
        "keyframes": [{"t": t, "ease": e, "_note": n, "bones": p} for t, e, n, p in keys],
    }
    spec.update(extra or {})
    return spec


def write(spec, outdir):
    os.makedirs(outdir, exist_ok=True)
    p = os.path.join(outdir, spec["rbx_name"] + ".json")
    with open(p, "w", encoding="utf-8") as fh:
        json.dump(spec, fh, indent=1)
    return p


def pose_raw(root, bones):
    """Full pose from Blender bone names (e.g. a rbx_axis_check.py suggested beat)."""
    b = pose(root=root)
    for name, r in bones.items():
        b[name]["rot"] = list(r)
    return b
