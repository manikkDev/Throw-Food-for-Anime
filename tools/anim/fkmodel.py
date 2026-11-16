"""Pure-Python forward kinematics of the MrXen0 R15 rig, so contact points can be SOLVED at authoring time.

Rest geometry was read off the rig's bones (rig space: +X right, +Y forward, +Z up, origin = rest
HumanoidRootPart; the floor is z = -3.0). Every pose bone rotates about its own head; a pose Euler is
in the bone's LOCAL frame (Blender XYZ: R = Rz @ Ry @ Rx), and a bone's world delta from rest is
    D_child = D_parent @ B_child @ E_child @ B_child^T
with B the bone's rest axes. Limb bones rest pointing DOWN (local X = -X, Y = -Z, Z = -Y); the body
bones (TORSO, UpTorso, HEAD) point UP (local X = X, Y = Z, Z = -Y). Checked against Blender dry runs
(see progress.md): agreement to about 0.01 stud.

The point: training contact distances and planted feet are numbers solved here (scipy least squares
over the FK angles), then written into the spec as plain FK rotations. The exported clip is still pure
FK - no IK anywhere near Roblox.
"""
import numpy as np
from scipy.optimize import least_squares
from scipy.spatial.transform import Rotation as Rot

B_LIMB = np.array([[-1.0, 0, 0], [0, 0, -1.0], [0, -1.0, 0]]).T   # columns = local X, Y, Z in rig space
B_BODY = np.array([[1.0, 0, 0], [0, 0, 1.0], [0, -1.0, 0]]).T

PIVOT = np.array([0.0, 0.0, -0.6])                 # TORSO and UpTorso heads (waist)
NECK = np.array([0.0, 0.0, 1.0])
HIP = {"R": np.array([0.5, 0.0, -1.0]), "L": np.array([-0.5, 0.0, -1.0])}
THIGH = np.array([0.0, 0.010, -0.822])              # hip -> knee (rest)
SHIN = np.array([0.0, -0.015, -0.926])              # knee -> ankle
SHOULDER = {"R": np.array([1.0, 0.0, 0.763]), "L": np.array([-1.0, 0.0, 0.763])}
UPPER = {"R": np.array([0.5, -0.009, -0.728]), "L": np.array([-0.5, -0.009, -0.728])}   # shoulder bone head -> elbow
FORE = np.array([0.0, 0.006, -0.760])               # elbow -> wrist
HAND_LEN = 0.275                                    # wrist -> end face of the 1 x 1 x 0.3 hand box
FLOOR = -3.0
ANKLE_REST_Z = -2.748                               # ankle height when the foot is flat on the floor


def E(xyz):
    return Rot.from_euler("xyz", xyz, degrees=True).as_matrix()


def local_delta(B, xyz):
    return B @ E(xyz) @ B.T


def _g(bones, k):
    return np.asarray(bones.get(k, [0, 0, 0]), float)


def root_vec(root):
    """Root offset in RIG/WORLD space: a scalar is a drop on Z, a 3-vector is (right, forward, up)."""
    return np.array([0.0, 0.0, float(root)]) if np.ndim(root) == 0 else np.asarray(root, float)


def root_loc(root):
    """The ROOT bone's pose `loc` for a world offset: its rest axes are X = -X, Y = -Y, Z = Z (probed),
    so loc +Y moves the body BACKWARD (traps.md #45). Spec loc = (-dx, -dy, dz)."""
    r = root_vec(root)
    return [round(-r[0], 3) + 0.0, round(-r[1], 3) + 0.0, round(r[2], 3)]


def fk(bones, root=0.0):
    """bones: {short name: euler deg} (short names as in animlib: tor, up, head, uar, lar, har, ...).

    Returns dict of world points (rig space) and world deltas."""
    off = root_vec(root)
    Dt = local_delta(B_BODY, _g(bones, "tor"))
    Du = Dt @ local_delta(B_BODY, _g(bones, "up"))
    out = {"D_tor": Dt, "D_up": Du}
    piv = PIVOT + off
    out["neck"] = piv + Du @ (NECK - PIVOT)
    out["D_head"] = Du @ local_delta(B_BODY, _g(bones, "head"))
    for s in ("R", "L"):
        sf = s.lower()
        hip = piv + Dt @ (HIP[s] - PIVOT)
        Dul = Dt @ local_delta(B_LIMB, _g(bones, "ul" + sf))
        knee = hip + Dul @ THIGH
        Dll = Dul @ local_delta(B_LIMB, _g(bones, "ll" + sf))
        ankle = knee + Dll @ SHIN
        Df = Dll @ local_delta(B_LIMB, _g(bones, "f" + sf))
        out.update({f"hip{s}": hip, f"knee{s}": knee, f"ankle{s}": ankle, f"Dfoot{s}": Df,
                    f"Dthigh{s}": Dul, f"Dshin{s}": Dll})
        sh = piv + Du @ (SHOULDER[s] - PIVOT)
        Dua = Du @ local_delta(B_LIMB, _g(bones, "ua" + sf))
        elbow = sh + Dua @ UPPER[s]
        Dla = Dua @ local_delta(B_LIMB, _g(bones, "la" + sf))
        wrist = elbow + Dla @ FORE
        Dh = Dla @ local_delta(B_LIMB, _g(bones, "ha" + sf))
        fist = wrist + Dh @ np.array([0, 0, -HAND_LEN])
        out.update({f"shoulder{s}": sh, f"elbow{s}": elbow, f"wrist{s}": wrist, f"fist{s}": fist,
                    f"Dhand{s}": Dh, f"Dfore{s}": Dla, f"Dupper{s}": Dua})
    return out


def _wrap(a):
    return (a + 180.0) % 360.0 - 180.0


def solve_leg(side, ankle, root, tor, yaw=0.0, heel=0.0, guess=None, knee_out=0.0):
    """FK angles {ul, ll, f} that put `side`'s ankle at `ankle` (rig space) with the foot flat
    (`heel` deg > 0 lifts the heel, standing on the toe edge; give ankle as (x, y) to put the foot on the floor), toes turned `yaw` deg (+ = toward the character's
    LEFT, like the torso), the knee bending over the toes (+knee_out pushes it outward)."""
    sf = side.lower()
    want_foot = Rot.from_euler("z", yaw, degrees=True).as_matrix() @ Rot.from_euler("x", -heel, degrees=True).as_matrix()
    if len(ankle) == 2:   # (x, y): put the foot's lowest corner on the floor
        h = np.radians(heel)
        ankle = [ankle[0], ankle[1], FLOOR + 0.5 * np.sin(abs(h)) + 0.252 * np.cos(h)]
    x0 = np.array(guess if guess is not None else [-20, 0, 0, 30, -10, 0, 0], float)

    def res(x):
        b = {"tor": tor, "ul" + sf: x[0:3], "ll" + sf: [x[3], 0, 0], "f" + sf: x[4:7]}
        o = fk(b, root)
        r = list((o["ankle" + side] - np.asarray(ankle)) * 40.0)
        r += list((o["Dfoot" + side] - want_foot).ravel() * 3.0)
        # knee over the toes: the knee's sideways offset from the hip->ankle line, in the foot's frame
        hip, knee, ank = o["hip" + side], o["knee" + side], o["ankle" + side]
        mid = (hip + ank) / 2
        side_axis = want_foot @ np.array([1.0, 0, 0])
        s = 1 if side == "R" else -1
        r.append((np.dot(knee - mid, side_axis) - s * knee_out) * 4.0)
        r.append(x[1] * 0.002)
        r.append(min(0.0, x[3]) * 1.0)   # the knee only bends forward (positive)
        return r

    sol = least_squares(res, x0, xtol=1e-10, ftol=1e-10)
    x = sol.x
    b = {"tor": tor, "ul" + sf: x[0:3], "ll" + sf: [x[3], 0, 0], "f" + sf: x[4:7]}
    o = fk(b, root)
    err = float(np.linalg.norm(o["ankle" + side] - np.asarray(ankle)))
    return ({"ul": [round(v, 2) for v in x[0:3]], "ll": [round(x[3], 2), 0, 0],
             "f": [round(v, 2) for v in x[4:7]]}, err, list(x))


def arm_intrusion(o, side, pad=0.4):
    """Penetration depths of the arm's centre line into the (padded) chest, belly and head boxes: a
    smooth-ish residual that keeps a solved arm OUTSIDE the body. Arms are 1 stud thick, so pad 0.4 lets
    the arm's surface touch the chest without the arm sinking into it."""
    Du = o["D_up"]
    piv = o["neck"] - Du @ (NECK - PIVOT)
    boxes = [(Du, np.array([0, 0, 0.2]), np.array([1.0, 0.5, 0.8])),
             (o["D_tor"], np.array([0, 0, -0.8]), np.array([1.0, 0.5, 0.2])),
             (Du, np.array([0, 0, 1.5]), np.array([0.6, 0.6, 0.6]))]
    e, w, f = o["elbow" + side], o["wrist" + side], o["fist" + side]
    sh = e + (o["shoulder" + side] - e) * 0.35
    pts = [sh + (e - sh) * k / 3 for k in range(4)] + [e + (w - e) * k / 3 for k in range(1, 4)] + [f]
    out = []
    for p in pts:
        best = 0.0
        for D, c, h in boxes:
            q = D.T @ (p - piv) + PIVOT - c
            d = h + pad - np.abs(q)
            if np.all(d > 0):
                best = max(best, float(d.min()))
        out.append(best)
    return out


ARM_LO = [-200, -100, -100, -150]
ARM_HI = [100, 100, 170, 0]


def solve_arm(side, target, tor, up, fore_dir=None, guess=None, roll=0.0, hand=(0, 0, 0), root=0.0, w_dir=6.0,
              avoid=0.0):
    """FK {ua, la} putting the fist END-FACE CENTRE at `target`; `fore_dir` (unit, rig space)
    optionally asks the forearm to point that way. Bounded multi-start, best residual wins."""
    sf = side.lower()

    def pose_of(v):
        return {"tor": tor, "up": up, "ua" + sf: v[0:3], "la" + sf: [v[3], 0, 0], "ha" + sf: hand}

    def res(v):
        o = fk(pose_of(v), root)
        r = list((o["fist" + side] - np.asarray(target)) * 40.0)
        if fore_dir is not None:
            d = o["Dfore" + side] @ np.array([0, 0, -1.0])
            r += list((d - np.asarray(fore_dir) / np.linalg.norm(fore_dir)) * w_dir)
        if avoid:
            r += [x * avoid for x in arm_intrusion(o, side)]
        r.append((v[1] - roll) * 0.01)
        return r

    seeds = ([guess] if guess is not None else []) + [
        [-90, 0, 0, -10], [-60, 0, 0, -60], [-30, 0, 0, -110], [-80, 0, 40, -40],
        [-80, 0, -40, -40], [0, 60, 80, -90], [-120, 0, 0, -30], [20, 0, 0, -20]]
    best = None
    for x0 in seeds:
        x0 = np.clip(np.asarray(x0, float), np.array(ARM_LO) + 1e-6, np.array(ARM_HI) - 1e-6)
        sol = least_squares(res, x0, bounds=(ARM_LO, ARM_HI), xtol=1e-10, ftol=1e-10)
        if best is None or sol.cost < best.cost - 1e-9:
            best = sol
    x = best.x
    o = fk(pose_of(x), root)
    return ({"ua": [round(float(v), 2) for v in x[0:3]], "la": [round(float(x[3]), 2), 0, 0]},
            float(np.linalg.norm(o["fist" + side] - np.asarray(target))), [float(v) for v in x], o)

HAND_CORNERS = [np.array([x, y, z]) for x in (-0.5, 0.5) for y in (-0.5, 0.5) for z in (-0.275, 0.025)]


def front_y(o, side):
    """Frontmost (+Y) corner of the 1 x 1 x 0.3 hand box: what touches a target face first."""
    return max((o["wrist" + side] + o["Dhand" + side] @ c)[1] for c in HAND_CORNERS)


def _smax(v, k=40.0):
    v = np.asarray(v)
    m = v.max()
    return m + np.log(np.exp((v - m) * k).sum()) / k




def solve_fist(side, D, x, z, tor, up, fore_dir=None, guess=None, hand=(0, 0, 0), w_dir=6.0, roll=0.0,
               root=0.0, starts=None, face=None, w_face=4.0, avoid=0.0):
    """FK {ua, la} so the hand box's frontmost corner sits ON the plane y = D (the target's front face)
    with the end-face centre at (x, ?, z). fore_dir (unit) shapes the punch. Multi-start, bounded,
    best residual wins (deterministic)."""
    sf = side.lower()
    nv = 4 if face is None else 6

    def pose_of(v):
        h = hand if face is None else [v[4], 0, v[5]]
        return {"tor": tor, "up": up, "ua" + sf: v[0:3], "la" + sf: [v[3], 0, 0], "ha" + sf: h}

    def res(v):
        o = fk(pose_of(v), root)
        fc = o["fist" + side]
        if face is not None:   # the end face's outward normal should point along `face` (flat on the target)
            nrm = o["Dhand" + side] @ np.array([0, 0, -1.0])
            r0 = list((nrm - np.asarray(face) / np.linalg.norm(face)) * w_face)
        else:
            r0 = []
        ys = [(o["wrist" + side] + o["Dhand" + side] @ c)[1] for c in HAND_CORNERS]
        r = r0 + [(fc[0] - x) * 80.0, (fc[2] - z) * 80.0, (_smax(ys) - D) * 120.0]
        if fore_dir is not None:
            d = o["Dfore" + side] @ np.array([0, 0, -1.0])
            r += list((d - np.asarray(fore_dir) / np.linalg.norm(fore_dir)) * w_dir)
        if avoid:
            r += [x * avoid for x in arm_intrusion(o, side)]
        r.append((v[1] - roll) * 0.01)
        return r

    # a warm start from the previous key keeps the SAME solution branch (no limb flip between keys)
    seeds = [guess] if guess is not None else []
    if guess is None:
        seeds += starts or [[-90, 0, 0, -10], [-60, 0, 0, -60], [-30, 0, 0, -110], [-80, 0, 40, -40],
                            [-80, 0, -40, -40], [0, 60, 80, -90], [-120, 0, 0, -30]]
    lo, hi = list(ARM_LO), list(ARM_HI)
    if face is not None:
        lo, hi = lo + [-50, -50], hi + [50, 50]
    best = None
    for x0 in seeds:
        x0 = list(x0) if len(x0) == nv else list(x0)[:4] + ([0, 0] if face is not None else [])
        x0 = np.clip(np.asarray(x0, float), np.array(lo) + 1e-6, np.array(hi) - 1e-6)
        sol = least_squares(res, x0, bounds=(lo, hi), xtol=1e-10, ftol=1e-10)
        if best is None or sol.cost < best.cost - 1e-9:
            best = sol
    v = best.x
    o = fk(pose_of(v), root)
    out = {"ua": [round(float(a), 2) for a in v[0:3]], "la": [round(float(v[3]), 2), 0, 0]}
    if face is not None:
        out["ha"] = [round(float(v[4]), 2), 0, round(float(v[5]), 2)]
    return (out, o, [float(a) for a in v])
