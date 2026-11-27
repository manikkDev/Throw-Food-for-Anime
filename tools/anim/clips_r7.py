"""Batch r7 (2026-11-27, plan 13 phase C "throw feel"): the hold and throw clips for the three food classes.

  HoldPitch   player, Action, 2.0 s loop: pitcher's ready stance, the food sitting on the right hand by the
              right shoulder, left arm loose in front; breathing, weight shift, two small toss-ready pumps.
              Feet = Throw's frame 0, so it crossfades into the existing Throw (0.1 s).
  HoldHeave   player, Action, 2.0 s loop: square, knees soft, a big bowl carried LEVEL in both hands in front
              of the chest; breathing bob. Hands rigid in the bowl's frame (constant distance, same height).
  ThrowHeave  player, Action, 1.5 s: sink and draw the bowl down to the right hip (held), drive up through the
              legs with a step of the left foot and launch it forward and up, arms locked out (Release 0.7667),
              arms fly up and open, settle back to a stand.
  HoldSpin    player, Action, 2.0 s loop: side-on (right shoulder to the lane), the flat food held level at
              the left hip in the right hand, gripped at its edge, left arm out behind, weight on the back foot.
  ThrowSpin   player, Action, 1.5 s: coil further (held), step at the lane, hips then shoulders open, the arm
              whips flat across the body, wrist snap, Release 0.7 at chest height forward-right, the arm wraps
              round and up, weight on the front foot, back to a stand.

Method (same as clips_r5.py): EVERY frame is a key. Planted feet are solved with fkmodel.solve_leg; every hand
that holds food is SOLVED per frame from where the food is (pitch: hand under the ball, palm (end face) up;
heave: both hands from the bowl's level frame; spin: hand at the disc's edge with the hand's X axis kept
vertical so the disc stays flat). The clip is still pure FK. `python tools/anim/clips_r7.py check` prints the
food's clearance from every body part, the hands' spacing and level, and the release numbers (FK model).

Hand part conventions (rig space = +X right, +Y forward (the lane), +Z up, origin the rest HumanoidRootPart):
the R15 block hand is a 1 x 1 tile 0.3 thick ALONG the arm, so the face that touches the food is its 1 x 1 END
face (Roblox hand -Y, "tip" here); its X axis is Roblox hand X.
"""
import math

import numpy as np

import fkmodel as F
from animlib import clip, pose
from clips_r3 import hand_centre, solve_feet, to_roblox
from clips_r4 import Curve, rl
from clips_train import fr, slerp_pass

R, L = "R", "L"
SG = {R: 1.0, L: -1.0}
M_RBX = np.array([[1.0, 0, 0], [0, 0, 1.0], [0, -1.0, 0]])     # rig vector -> Roblox vector
VIEWS = {"side": [1.0, 0.08, 0.1], "front": [0.18, 1.0, 0.12], "front34": [0.7, 1.0, 0.3]}
PROPS_DIR = r"D:\Roblox Studio Games\Throw food for Anime\work\anim\r7\props"
HALF_T = 0.15                       # hand centre -> end face

# Blender rest of the deform hand BONE (probed): columns = bone axes in rig space, last column = head (wrist)
# in WORLD (origin = HRP at world z 3.0). Used to turn a food offset in hand-PART space into anim_render's
# bone-space `grip_bone`; anim_render then re-derives the Roblox grip from the render and asserts it.
BONE_REST = {R: np.array([[-0.99999, 0.004, -1e-05, 1.4995], [0.0, -0.00258, -1.0, -0.00292],
                          [-0.004, -0.99999, 0.00258, 2.27509], [0, 0, 0, 1.0]])}
HAND_REST_C = {R: np.array([1.5, 0.0, 2.14995])}       # hand part rest centre, world


def rz(deg):
    a = math.radians(deg)
    return np.array([[math.cos(a), -math.sin(a), 0], [math.sin(a), math.cos(a), 0], [0, 0, 1.0]])


def unit(v):
    v = np.asarray(v, float)
    return v / np.linalg.norm(v)


def wave(u, k=1.0, ph=0.0):
    return math.sin(2 * math.pi * (k * u + ph))


# ----------------------------------------------------------------------------------------- feet
def foot_at(x, y, yaw, heel=0.0, lift=0.0):
    """(ankle xyz, heel, yaw) for solve_feet. heel > 0: heel up, the foot pivots on its TOE edge; < 0 toe up
    on the heel edge; the contact edge stays where the flat foot had it (no slide while it rolls)."""
    a = math.radians(abs(heel))
    d = np.array([-math.sin(math.radians(yaw)), math.cos(math.radians(yaw))])
    s = 0.5 * (1 - math.cos(a)) + 0.252 * math.sin(a)
    xy = np.array([x, y]) + d * (s if heel >= 0 else -s)
    return (np.array([xy[0], xy[1], F.FLOOR + 0.5 * math.sin(a) + 0.252 * math.cos(a) + lift]), heel, yaw)


class FootTrack:
    """keys [(frame, (x, y, yaw, heel))]: a segment whose (x, y) changes is a STEP (lifted on an arc, CLEAR
    at mid-swing, heel/yaw eased), otherwise the foot is planted and only pivots (yaw / heel)."""

    def __init__(self, keys, clear=0.22):
        # a planted foot that turns pivots on the BALL of the foot: keep its toe point still, so the authored
        # (x, y) of a pivot's end key is replaced by where the ankle goes when the toe stays put
        k = [(keys[0][0], tuple(keys[0][1]))]
        for (f1, b) in keys[1:]:
            a = k[-1][1]
            if abs(a[0] - b[0]) + abs(a[1] - b[1]) < 1e-6:
                da = np.array([-math.sin(math.radians(a[2])), math.cos(math.radians(a[2]))])
                db = np.array([-math.sin(math.radians(b[2])), math.cos(math.radians(b[2]))])
                toe = np.array(a[:2]) + da * 0.5
                xy = toe - db * 0.5
                b = (float(xy[0]), float(xy[1]), b[2], b[3])
            k.append((f1, tuple(b)))
        self.k = k
        self.clear = clear

    def __call__(self, f):
        k = self.k
        if f <= k[0][0]:
            return foot_at(*k[0][1])
        for (f0, a), (f1, b) in zip(k, k[1:]):
            if f <= f1:
                u = (f - f0) / float(f1 - f0)
                s = u * u * (3 - 2 * u)
                yaw, heel = a[2] + (b[2] - a[2]) * s, a[3] + (b[3] - a[3]) * s
                da = np.array([-math.sin(math.radians(a[2])), math.cos(math.radians(a[2]))])
                db = np.array([-math.sin(math.radians(b[2])), math.cos(math.radians(b[2]))])
                ta, tb = np.array(a[:2]) + da * 0.5, np.array(b[:2]) + db * 0.5
                step = float(np.linalg.norm(ta - tb)) > 1e-4
                if step:
                    x, y = a[0] + (b[0] - a[0]) * s, a[1] + (b[1] - a[1]) * s
                else:                                     # pivot on the still toe
                    dy = np.array([-math.sin(math.radians(yaw)), math.cos(math.radians(yaw))])
                    x, y = ta - dy * 0.5
                lift = self.clear * math.sin(math.pi * u) ** 0.8 if step else 0.0
                return foot_at(x, y, yaw, heel, lift)
        return foot_at(*k[-1][1])

    def planted(self, f):
        for (f0, a), (f1, b) in zip(self.k, self.k[1:]):
            if f0 <= f <= f1 and abs(a[0] - b[0]) + abs(a[1] - b[1]) > 1e-6:
                return f in (f0, f1)
        return True


# ----------------------------------------------------------------------------------------- hands
def solve_h(side, centre, tor, up, root, tip=None, xax=None, fore=None, elbow=None, guess=None, avoid=6.0,
            lim=80.0, w_tip=8.0, w_x=6.0, w_fore=1.5, w_elb=1.0, food=None, w_food=30.0, margin=0.03, w_c=40.0,
            touch=None, tip_ok=3.0, yax=None):
    """FK {ua, la, ha} putting the hand part's CENTRE at `centre` with its end-face normal along `tip` and/or
    its X axis along `xax`; `fore` (forearm direction) and `elbow` (point) are soft preferences. `food` (a Food)
    is an obstacle: the upper and lower arm keep `margin` outside it and the hand may touch it but not enter
    (`touch` = the hand's wanted clearance from it, two-sided: the palm stays ON the food).
    Warm-started from `guess` (same branch frame to frame); falls back to a seed sweep only if that misses."""
    from scipy.optimize import least_squares
    sf = side.lower()
    nm = "Right" if side == R else "Left"
    food = food.coarse() if food is not None else None

    def po(v):
        return {"tor": tor, "up": up, "ua" + sf: v[0:3], "la" + sf: [v[3], 0, 0], "ha" + sf: [v[4], 0, v[5]]}

    def res(v):
        o = F.fk(po(v), root)
        Dh = o["Dhand" + side]
        r = list((hand_centre(o, side) - centre) * w_c)
        if food is not None:
            bx = [b for b in part_boxes(o) if b[0] in (nm + "UpperArm", nm + "LowerArm", nm + "Hand")]
            cl = food.clearance(bx)
            r += [max(0.0, margin - cl[nm + "UpperArm"]) * w_food, max(0.0, margin - cl[nm + "LowerArm"]) * w_food,
                  max(0.0, -cl[nm + "Hand"]) * w_food]
            if touch is not None:
                r.append((cl[nm + "Hand"] - touch) * w_food * 0.5)
        if tip is not None:
            r += list((Dh @ np.array([0, 0, -1.0]) - tip) * w_tip)
        if xax is not None:
            r += list((Dh @ np.array([1.0, 0, 0]) - xax) * w_x)
        if yax is not None:
            r += list((Dh @ np.array([0, 1.0, 0]) - yax) * w_x)
        if fore is not None:
            r += list((o["Dfore" + side] @ np.array([0, 0, -1.0]) - fore) * w_fore)
        if elbow is not None:
            r += list((o["elbow" + side] - elbow) * w_elb)
        if avoid:
            r += [x * avoid for x in F.arm_intrusion(o, side)]
        r += [v[1] * 0.004, v[4] * 0.003, v[5] * 0.003]
        return r

    lo, hi = np.array(F.ARM_LO + [-lim, -lim]), np.array(F.ARM_HI + [lim, lim])

    def run(x0):
        x0 = np.clip(np.asarray(x0, float), lo + 1e-6, hi - 1e-6)
        return least_squares(res, x0, bounds=(lo, hi), xtol=1e-10, ftol=1e-10)

    def quality(sol):
        o = F.fk(po(sol.x), root)
        e = float(np.linalg.norm(hand_centre(o, side) - centre))
        a = 0.0
        if tip is not None:
            a = max(a, math.degrees(math.acos(np.clip(o["Dhand" + side] @ np.array([0, 0, -1.0]) @ tip, -1, 1))))
        if xax is not None:
            a = max(a, math.degrees(math.acos(np.clip(o["Dhand" + side] @ np.array([1.0, 0, 0]) @ xax, -1, 1))))
        if yax is not None:
            a = max(a, math.degrees(math.acos(np.clip(o["Dhand" + side] @ np.array([0, 1.0, 0]) @ yax, -1, 1))))
        return e, a

    best = run(guess) if guess is not None else None
    if best is None or quality(best)[0] > 0.01 or quality(best)[1] > tip_ok:
        sg = SG[side]
        for x0 in ([-60, 0, 0, -60, 0, 0], [-80, 0, 40 * sg, -40, 0, 0], [-40, 30, 60 * sg, -80, 0, 0],
                   [-90, 0, 0, -10, 0, 0], [-30, 0, 0, -110, 0, 0], [-120, 0, 0, -30, 0, 0], [0, 60, 80 * sg, -90, 0, 0],
                   [-20, -30, -40 * sg, -90, 0, 0], [-60, -40, -30 * sg, -60, 0, 0],
                   [-60, 60 * sg, -60 * sg, -60, 0, 0], [-70, -60 * sg, -50 * sg, -50, 0, 0], [-45, 90 * sg, -40 * sg, -70, 0, 0],
                   [-80, 0, -60 * sg, -30, 0, 0], [-50, 30 * sg, -80 * sg, -40, 30, 0], [-30, 80 * sg, -70 * sg, -90, 0, 0]):
            s = run(x0)
            if best is None or s.cost < best.cost - 1e-9:
                best = s
    v = best.x
    o = F.fk(po(v), root)
    e, a = quality(best)
    out = {"ua" + sf: [float(x) for x in v[0:3]], "la" + sf: [float(v[3]), 0.0, 0.0],
           "ha" + sf: [float(v[4]), 0.0, float(v[5])]}
    return out, list(map(float, v)), (e, a)


# ------------------------------------------------------------------------------------- body boxes
REST = {"UpperArm": ([1.5, 0, 0.369], [0.5, 0.5, 0.584]), "LowerArm": ([1.5, 0, -0.224], [0.5, 0.5, 0.526]),
        "Hand": ([1.5, 0, -0.85], [0.5, 0.5, 0.15]), "UpperLeg": ([0.5, 0, -1.421], [0.5, 0.5, 0.608]),
        "LowerLeg": ([0.5, 0, -2.201], [0.5, 0.5, 0.597]), "Foot": ([0.5, 0, -2.85], [0.5, 0.5, 0.15])}


def part_boxes(o):
    """Every R15 part as an oriented box (name, centre, rotation, half extents), sizes measured on the rig."""
    piv = o["neck"] - o["D_up"] @ (F.NECK - F.PIVOT)
    out = [("UpperTorso", piv + o["D_up"] @ (np.array([0, 0, 0.2]) - F.PIVOT), o["D_up"], np.array([1.0, 0.5, 0.8])),
           ("LowerTorso", piv + o["D_tor"] @ (np.array([0, 0, -0.8]) - F.PIVOT), o["D_tor"], np.array([1.0, 0.5, 0.2])),
           ("Head", o["neck"] + o["D_head"] @ (np.array([0, 0, 1.5]) - F.NECK), o["D_head"], np.array([0.6, 0.6, 0.6]))]
    for s in (R, L):
        g = SG[s]
        sh0 = F.SHOULDER[s]
        el0 = sh0 + F.UPPER[s]
        wr0 = el0 + F.FORE
        hip0 = F.HIP[s]
        kn0 = hip0 + F.THIGH
        an0 = kn0 + F.SHIN
        nm = "Right" if s == R else "Left"
        for part, j, j0, D in (("UpperArm", o["shoulder" + s], sh0, o["Dupper" + s]),
                               ("LowerArm", o["elbow" + s], el0, o["Dfore" + s]),
                               ("Hand", o["wrist" + s], wr0, o["Dhand" + s]),
                               ("UpperLeg", o["hip" + s], hip0, o["Dthigh" + s]),
                               ("LowerLeg", o["knee" + s], kn0, o["Dshin" + s]),
                               ("Foot", o["ankle" + s], an0, o["Dfoot" + s])):
            c0, h = REST[part]
            c0 = np.array([c0[0] * g, c0[1], c0[2]])
            out.append((nm + part, j + D @ (c0 - j0), D, np.array(h)))
    return out


def box_sd(p, c, D, h):
    q = np.abs(D.T @ (p - c)) - h
    return float(np.linalg.norm(np.maximum(q, 0))) if np.any(q > 0) else float(q.max())


def box_points(c, D, h):
    pts = []
    for i in (-1, 0, 1):
        for j in (-1, 0, 1):
            for k in (-1, 0, 1):
                if i or j or k:
                    pts.append(c + D @ (np.array([i, j, k]) * h))
    return pts


class Food:
    """sphere (r) or disc (radius R, half thickness h, flat axis = column 2 of `rot`) for clearance checks"""

    def __init__(self, kind, centre, rot=np.eye(3), r=0.9, R_=1.2, h=0.15):
        self.kind, self.c, self.rot, self.r, self.R, self.h = kind, np.asarray(centre, float), rot, r, R_, h

    def coarse(self):
        """the same food with a light sample set, for use inside a solver"""
        f = Food(self.kind, self.c, self.rot, self.r, self.R, self.h)
        f._S = np.array(self.samples(light=True))
        return f

    def samples(self, light=False):
        out = []
        if self.kind == "sphere":
            n = 90 if light else 400
            for i in range(n):
                z = 1 - 2 * (i + 0.5) / n
                t = math.pi * (1 + 5 ** 0.5) * i
                rr = math.sqrt(1 - z * z)
                out.append(self.c + self.r * np.array([rr * math.cos(t), rr * math.sin(t), z]))
            return out
        for a in np.linspace(0, 2 * math.pi, 28 if light else 72, endpoint=False):
            for z in np.linspace(-self.h, self.h, 3 if light else 5):
                out.append(self.c + self.rot @ np.array([self.R * math.cos(a), self.R * math.sin(a), z]))
            for rr in ((0.6,) if light else (0.25, 0.5, 0.75)):
                for z in (-self.h, self.h):
                    out.append(self.c + self.rot @ np.array([rr * self.R * math.cos(a), rr * self.R * math.sin(a), z]))
        out += [self.c + self.rot @ np.array([0, 0, z]) for z in (-self.h, self.h)]
        return out

    def sd(self, p):
        if self.kind == "sphere":
            return float(np.linalg.norm(p - self.c)) - self.r
        q = self.rot.T @ (p - self.c)
        dr, dz = math.hypot(q[0], q[1]) - self.R, abs(q[2]) - self.h
        return math.hypot(max(dr, 0), max(dz, 0)) if (dr > 0 or dz > 0) else max(dr, dz)

    def clearance(self, boxes):
        if not hasattr(self, "_S"):
            self._S = np.array(self.samples())
        S = self._S
        out = {}
        for name, c, D, h in boxes:
            q = np.abs((S - c) @ D) - h                       # rows: sample in the box's frame
            outside = np.linalg.norm(np.maximum(q, 0), axis=1)
            sd = np.where(np.any(q > 0, axis=1), outside, q.max(axis=1))
            b = min(self.sd(p) for p in box_points(c, D, h))
            out[name] = min(float(sd.min()), b)
        return out


# ------------------------------------------------------------------------------------- assembly
def full_pose(root, tor, up, head, legs, arms):
    b = pose(legs=legs, tor=rl(tor), up=rl(up), head=rl(head), **{k: rl(v) for k, v in arms.items()})
    b["ROOT"] = {"loc": F.root_loc(root)}
    return b


def torso_pt(tor, up, root, p):
    """point given in the REST upper-torso frame, carried by the posed upper torso"""
    o = F.fk({"tor": tor, "up": up}, root)
    return F.PIVOT + F.root_vec(root) + o["D_up"] @ (np.asarray(p, float) - F.PIVOT)


def grip_bone(side, food_in_hand_rbx, rot_rbx=np.eye(3)):
    """food offset in Roblox hand-PART space (CFrame position + rotation) -> anim_render grip_bone (pos, XYZ deg)"""
    from scipy.spatial.transform import Rotation as Rot
    B = M_RBX.T                                    # Roblox vec -> rig vec
    H = np.eye(4)
    H[:3, :3] = B
    H[:3, 3] = HAND_REST_C[side]
    G = np.eye(4)
    G[:3, :3] = rot_rbx
    G[:3, 3] = food_in_hand_rbx
    Bm = BONE_REST[side].copy()
    # orthonormalise the probed rest rotation (it is 4-5 decimals)
    u, _, vt = np.linalg.svd(Bm[:3, :3])
    Bm[:3, :3] = u @ vt
    # anim_render: prop_world = bone_mat @ GRIP_OFFSET, and its hand frame H_rest relative to the bone is
    # BONE_REST^-1 @ H_rest; we want prop_world = hand_world @ G
    X = np.linalg.inv(Bm) @ H @ G
    # Blender's prop empty is in Blender axes; G's rotation is in Roblox axes for the prop's own frame too:
    # prop_blender = B @ prop_roblox, so the empty's matrix = X @ diag(B^T) (prop meshes are authored Z-up).
    Y = X.copy()
    Y[:3, :3] = X[:3, :3] @ M_RBX
    return {"pos": [round(float(v), 5) for v in Y[:3, 3]],
            "rot": [round(float(v), 4) for v in Rot.from_matrix(Y[:3, :3]).as_euler("xyz", degrees=True)]}


def build(frames, loop):
    """frames: list of (note, bones) for frames 0..N; a loop's last frame is a byte copy of frame 0"""
    import copy
    keys = []
    n = len(frames)
    for f, (note, b) in enumerate(frames):
        keys.append((fr(f), "linear", note, b))
    if loop:
        keys[-1] = (keys[-1][0], "linear", keys[0][2] + " (loop)", copy.deepcopy(keys[0][3]))
    del n
    return keys


INFO = {}       # per clip: per-frame FK records for the checks and the report


# ============================================================================================ PITCH
PITCH_R = 0.9
PITCH_N = 60
P_FEET = {L: (-0.55, 0.0, 0.0, 0.0), R: (0.55, 0.0, 0.0, 0.0)}     # = Throw frame 0 (no slide in the crossfade)
P_HAND = np.array([1.40, 1.00, 0.76])      # right hand centre, rest upper-torso frame: in front of the shoulder
P_TIP = unit([0.0, 0.45, 1.0])             # end face up and a little forward: the ball sits on it
P_FORE = unit([0.0, 0.72, 0.80])           # forearm up and forward (a block forearm must point UP or the ball
                                           # sinks into it: the hand cap is only 0.3 thick)
PUMP = Curve([(0, 0.0, "smooth"), (9, 0.0, "in"), (13, -0.06, "out"), (16, 0.08, "smooth"), (23, 0.0, "smooth"),
              (39, 0.0, "in"), (43, -0.06, "out"), (46, 0.08, "smooth"), (53, 0.0, "smooth"), (60, 0.0, "smooth")])
PUMP_TILT = Curve([(0, 0.0, "smooth"), (9, 0.0, "in"), (13, -6.0, "out"), (16, 7.0, "smooth"), (23, 0.0, "smooth"),
                   (39, 0.0, "in"), (43, -6.0, "out"), (46, 7.0, "smooth"), (53, 0.0, "smooth"), (60, 0.0, "smooth")])


def pitch_upper(f):
    u = f / PITCH_N
    root = np.array([0.035 * wave(u), 0.0, -0.075 + 0.012 * wave(u, 2, 0.25)])
    tor = [0.0, -10.0 + 1.5 * wave(u), 1.0 * wave(u)]
    up = [-3.0 + 1.3 * wave(u, 2, 0.25), -12.0 + 1.5 * wave(u, 1, 0.1), -1.0 * wave(u)]
    head = [-2.0 - 0.8 * wave(u, 2, 0.25), 21.0 - 2.5 * wave(u, 1, 0.1), 0.0]
    return root, tor, up, head


def hold_pitch():
    frames, guess, info = [], None, []
    for f in range(PITCH_N + 1):
        u = f / PITCH_N
        root, tor, up, head = pitch_upper(f)
        legs = solve_feet({s: foot_at(*v) for s, v in P_FEET.items()}, root, tor, "hpitch")
        o0 = F.fk({"tor": tor, "up": up}, root)
        Du = o0["D_up"]
        c = torso_pt(tor, up, root, P_HAND + np.array([0, 0, PUMP(f)]))
        tip = Du @ (F.E([PUMP_TILT(f), 0, 0]) @ P_TIP)     # the pump cocks the wrist back, then flicks it up
        tip = unit(tip)
        arm, guess, q = solve_h(R, c, tor, up, root, tip=tip, fore=Du @ P_FORE, guess=guess, w_fore=2.0)
        larm = {"ual": [-24.0 + 2.0 * wave(u, 1, 0.1), 0.0, -9.0], "lal": [-38.0 + 2.0 * wave(u, 1, 0.1), 0, 0],
                "hal": [-8.0, 0, 0]}
        b = full_pose(root, tor, up, head, legs, {**arm, **larm})
        frames.append(("ready: food on the right hand by the shoulder" if f % 10 else "ready (pump)" if PUMP(f) else "ready", b))
        info.append({"q": q})
    INFO["HoldPitch"] = info
    keys = build(frames, True)
    food = {"pos": [0.0, -(HALF_T + PITCH_R), 0.0]}
    return slerp_pass(clip(
        "HoldPitch", 2.0, True, "Action",
        "Pitcher's ready stance before the wind-up, feet planted square to the lane exactly as the Throw starts, "
        "shoulders turned a little side-on (left shoulder to the lane), head on the target; the food (r 0.9) "
        "sits ON the right hand's end face (palm up) by the right shoulder, elbow bent and down; the left arm "
        "hangs loose in front. Breathing, a slow weight shift and two small toss-ready pumps of the hand (the "
        "food never leaves the hand).",
        "baseball / cricket ready stance before the wind-up; 2.0 s loop, pumps at frames 16 and 46",
        keys, markers=[], views=VIEWS,
        extra={"prop": {"name": "Food", "attach": "RightHand", "glb": PROPS_DIR + r"\ball.glb",
                        "colour": [0.95, 0.55, 0.15], "grip_bone": grip_bone(R, food["pos"])},
               "_food": {"kind": "sphere", "radius": PITCH_R, "hand": "RightHand",
                         "cframe_in_hand": f"CFrame.new(0, {food['pos'][1]}, 0)"}}))


# ============================================================================================ HEAVE
BOWL_R, BOWL_H = 1.3, 0.55        # radius, half height of the 2.6 x 1.1 disc
BETA = 32.0                       # palms on the rim this many degrees BEHIND the widest line (reach: see the doc)
PALM_OUT = 0.1                    # palm-face centre this far outside the rim: a flat 1-stud face on a 1.3 radius
                                  # touches with its edges, its centre stands 0.1 off
GRIP_Z = -0.2                     # palm-face centres this far below the bowl's centre: the hands cup it from the sides
HEAVE_N = 60
H_FEET = {L: (-0.62, 0.0, 7.0, 0.0), R: (0.62, 0.0, -7.0, 0.0)}
H_BOWL = np.array([0.0, 1.88, 0.30])     # bowl centre, rest upper-torso frame (in front of the chest)


def heave_targets(c, yaw):
    """palm (end face) centres and end-face normals of both hands for a LEVEL bowl at c turned `yaw`"""
    Rz = rz(yaw)
    b = math.radians(BETA)
    out = {}
    for s in (R, L):
        g = SG[s]
        face = c + Rz @ np.array([g * (BOWL_R + PALM_OUT) * math.cos(b), -(BOWL_R + PALM_OUT) * math.sin(b), GRIP_Z])
        tip = Rz @ np.array([-g * math.cos(b), math.sin(b), 0.0])
        out[s] = (face - tip * HALF_T, tip, Rz)
    return out


def heave_hands(c, yaw, tor, up, root, guess):
    """both hands on the level bowl: palm (end face) centres pinned on the rim, palms kept touching it, the
    arms kept outside it; palm direction soft (a flat palm cannot lie flush on a curved rim)"""
    tg = heave_targets(c, yaw)
    food = Food("disc", c, rz(yaw), R_=BOWL_R, h=BOWL_H)
    arms, q = {}, {}
    for s in (R, L):
        hc, tip, Rz = tg[s]
        a, guess[s], q[s] = solve_h(s, hc, tor, up, root, tip=tip, w_tip=3.0, food=food, w_c=200.0, touch=0.01,
                                    tip_ok=25.0, guess=guess.get(s))
        arms.update(a)
    return arms, q


def heave_upper(f):
    u = f / HEAVE_N
    root = np.array([0.0, 0.0, -0.2 + 0.018 * wave(u, 2, 0.25)])
    tor = [-4.0, 0.6 * wave(u), 0.0]
    up = [-3.0 + 1.2 * wave(u, 2, 0.25), 0.8 * wave(u, 1, 0.1), 0.5 * wave(u)]
    head = [-9.0 - 0.8 * wave(u, 2, 0.25), -1.2 * wave(u, 1, 0.1), 0.0]
    return root, tor, up, head


def _heave_record(name, f, arms, tor, up, head, root, c, yaw, legs=None):
    o = F.fk({"tor": tor, "up": up, "head": head, **arms, **(legs or {})}, root)
    INFO.setdefault(name, []).append({"f": f, "c": c.copy(), "yaw": yaw, "hR": hand_centre(o, R), "hL": hand_centre(o, L),
                                      "DR": o["DhandR"], "DL": o["DhandL"]})


def _legs_kw(legs):
    out = {}
    for s, lg in legs.items():
        sf = s.lower()
        out.update({"ul" + sf: lg["ul"], "ll" + sf: lg["ll"], "f" + sf: lg["f"]})
    return out


def hold_heave():
    INFO.pop("HoldHeave", None)
    frames, guess = [], {}
    for f in range(HEAVE_N + 1):
        root, tor, up, head = heave_upper(f)
        legs = solve_feet({s: foot_at(*v) for s, v in H_FEET.items()}, root, tor, "hheave")
        c = torso_pt(tor, up, root, H_BOWL)
        yaw = tor[1] + up[1]
        arms, q = heave_hands(c, yaw, tor, up, root, guess)
        _heave_record("HoldHeave", f, arms, tor, up, head, root, c, yaw)
        INFO["HoldHeave"][-1]["q"] = q
        frames.append(("carry: bowl level in both hands" + (" (breath in)" if f in (15, 45) else ""),
                       full_pose(root, tor, up, head, legs, arms)))
    keys = build(frames, True)
    return slerp_pass(clip(
        "HoldHeave", 2.0, True, "Action",
        "Carrying a big bowl (2.6 across, 1.1 tall) LEVEL in both hands in front of the chest: square to the "
        "lane, knees soft, elbows out, each hand's flat end face pressed on the bowl's side a little below its "
        "middle, the two hands at the same height and the same distance apart all loop; a slow breathing bob.",
        "carrying a full bowl / hot pot so the soup does not spill; 2.0 s loop, breaths at frames 15 and 45",
        keys, markers=[], views=VIEWS, extra=_heave_extra(keys, "HoldHeave")))


def _heave_extra(keys, name):
    rec = INFO[name][0]
    D = rec["DR"]
    food_rot_rig = rz(rec["yaw"])
    rel = D.T @ (rec["c"] - rec["hR"])
    rot = M_RBX @ D.T @ food_rot_rig @ M_RBX.T            # bowl axes in Roblox hand-part space
    pos = M_RBX @ rel
    # the bowl is placed from BOTH hands (level, its centre fixed off their midpoint) and keyed per frame. A
    # RightHand weld is NOT used: the right hand rolls against the bowl in the throw, so a weld tilts it ~25 deg
    del pos, rot
    trk = [[round(float(x), 5) for x in list(rz(r["yaw"]).ravel()) + list(r["c"])] for r in INFO[name]]
    return {"_track": [{"glb": PROPS_DIR + r"\bowl.glb", "colour": [0.86, 0.32, 0.2], "frames": trk}],
            "_food": {"kind": "disc", "diameter": 2 * BOWL_R, "height": 2 * BOWL_H, "grip_beta_deg": BETA,
                      "grip_z": GRIP_Z}}


# ThrowHeave timeline (frames at 30 fps)
THROW_HEAVE_N = 45
THROW_HEAVE_REL = 23
TH_DEEP, TH_HOLD = 11, 14


def throw_heave():
    INFO.pop("ThrowHeave", None)
    root0, tor0, up0, head0 = heave_upper(0)
    # body beats: (frame, ease, root, tor, up, head)
    beats = [
        (0, "smooth", root0, tor0, up0, head0),
        (3, "in", [0.03, -0.03, -0.26], [-6, -6, 0], [-5, -6, 0], [-10, 8, 0]),
        (TH_DEEP, "out", [0.12, -0.16, -0.62], [-6, -18, 3], [-4, -24, -6], [4, 38, 4]),      # deepest coil
        (TH_HOLD, "in", [0.13, -0.17, -0.65], [-6, -19, 3], [-5, -25, -6], [5, 39, 4]),      # held
        (18, "smooth", [0.04, 0.22, -0.46], [-6, -4, 0], [-6, -6, -2], [2, 8, 0]),             # drive
        (THROW_HEAVE_REL, "out", [-0.04, 0.42, -0.26], [-6, 8, 0], [6, 6, 2], [14, -12, 0]),     # RELEASE
        (27, "smooth", [-0.05, 0.48, -0.30], [-9, 10, 0], [-2, 6, 1], [10, -14, 0]),            # follow-through
        (32, "smooth", [-0.04, 0.46, -0.31], [-8, 8, 0], [-4, 5, 0], [6, -12, 0]),              # held, settling
        (38, "smooth", [-0.01, 0.20, -0.12], [-3, 2, 0], [-2, 2, 0], [0, -3, 0]),
        (42, "smooth", [0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0]),
        (THROW_HEAVE_N, "smooth", [0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0]),
    ]
    cv = {k: Curve([(b[0], b[i], b[1]) for b in beats]) for i, k in ((2, "root"), (3, "tor"), (4, "up"), (5, "head"))}
    # bowl centre in the REST upper-torso frame, and its yaw relative to the chest
    bowl = Curve([(0, H_BOWL, "smooth"), (3, [0.02, 1.88, 0.26], "in"), (TH_DEEP, [0.05, 1.9, 0.34], "out"),
                  (TH_HOLD, [0.05, 1.9, 0.33], "in"), (18, [0.05, 1.92, 0.32], "smooth"),
                  (THROW_HEAVE_REL, [0.0, 2.18, 1.02], "smooth")])
    byaw = Curve([(0, 0.0, "smooth"), (TH_DEEP, 0.0, "out"), (TH_HOLD, 0.0, "in"), (18, 2.0, "smooth"),
                  (THROW_HEAVE_REL, 0.0, "smooth")])
    feet = {L: FootTrack([(0, H_FEET[L]), (TH_HOLD, (-0.62, 0.0, 10.0, 0.0)), (15, (-0.62, 0.0, 10.0, 0.0)),
                          (20, (-0.48, 1.0, -2.0, 0.0)), (35, (-0.48, 1.0, -2.0, 0.0)), (41, (-0.55, 0.0, 0.0, 0.0)),
                          (THROW_HEAVE_N, (-0.55, 0.0, 0.0, 0.0))], clear=0.15),
            R: FootTrack([(0, H_FEET[R]), (TH_DEEP, (0.62, 0.0, -22.0, 0.0)), (TH_HOLD, (0.62, 0.0, -22.0, 0.0)),
                          (18, (0.62, 0.0, -14.0, 14.0)), (THROW_HEAVE_REL, (0.62, 0.0, -8.0, 38.0)),
                          (27, (0.62, 0.0, -6.0, 44.0)), (32, (0.62, 0.0, -6.0, 40.0)), (36, (0.62, 0.0, -4.0, 0.0)),
                          (40, (0.62, 0.0, -4.0, 0.0)), (43, (0.55, 0.0, 0.0, 0.0)), (THROW_HEAVE_N, (0.55, 0.0, 0.0, 0.0))],
                         clear=0.12)}
    # after the release the arms are free: (frame, {bone: euler}) keys, the first is the solved release pose
    free_keys = [
        (27, {"uar": [-8, 0, 100], "lar": [-6, 0, 0], "har": [40, 0, 0], "ual": [-8, 0, -100], "lal": [-6, 0, 0], "hal": [40, 0, 0]}),
        (32, {"uar": [-4, 0, 94], "lar": [-12, 0, 0], "har": [30, 0, 0], "ual": [-4, 0, -94], "lal": [-12, 0, 0], "hal": [30, 0, 0]}),
        (38, {"uar": [-20, 0, 40], "lar": [-30, 0, 0], "har": [0, 0, 0], "ual": [-20, 0, -40], "lal": [-30, 0, 0], "hal": [0, 0, 0]}),
        (42, {k: [0, 0, 0] for k in ("uar", "lar", "har", "ual", "lal", "hal")}),
        (THROW_HEAVE_N, {k: [0, 0, 0] for k in ("uar", "lar", "har", "ual", "lal", "hal")}),
    ]
    frames, guess, free = [], {}, None
    notes = {0: "HoldHeave pose", TH_DEEP: "DEEPEST: sunk, coiled right, bowl low at the right hip", TH_HOLD: "held",
             15: "left foot lifts", 18: "drive up through the legs", 20: "left foot plants",
             THROW_HEAVE_REL: "RELEASE: arms locked out forward and up", 27: "follow-through: arms fly up and open",
             32: "held", 41: "left foot back", 42: "stand"}
    for f in range(THROW_HEAVE_N + 1):
        root, tor, up, head = rl(cv["root"](f)), rl(cv["tor"](f)), rl(cv["up"](f)), rl(cv["head"](f))
        if f == 0:
            root, tor, up, head = heave_upper(0)
        legs = solve_feet({R: feet[R](f), L: feet[L](f)}, root, tor, "theave")
        if f <= THROW_HEAVE_REL:
            c = torso_pt(tor, up, root, bowl(f))
            yaw = float(tor[1] + up[1] + byaw(f))
            arms, q = heave_hands(c, yaw, tor, up, root, guess)
            _heave_record("ThrowHeave", f, arms, tor, up, head, root, c, yaw)
            INFO["ThrowHeave"][-1]["q"] = q
            if f == THROW_HEAVE_REL:
                free = Curve([(THROW_HEAVE_REL, np.concatenate([arms[k] for k in ("uar", "lar", "har", "ual", "lal", "hal")]), "out")]
                             + [(k, np.concatenate([v[b] for b in ("uar", "lar", "har", "ual", "lal", "hal")]),
                                 "smooth") for k, v in free_keys])
        else:
            vv = free(f)
            arms = {k: list(vv[3 * i:3 * i + 3]) for i, k in enumerate(("uar", "lar", "har", "ual", "lal", "hal"))}
            arms["lar"][1:] = [0.0, 0.0]
            arms["lal"][1:] = [0.0, 0.0]
            arms["har"][1] = 0.0
            arms["hal"][1] = 0.0
        frames.append((notes.get(f, "heave"), full_pose(root, tor, up, head, legs, arms)))
    keys = build(frames, False)
    return slerp_pass(clip(
        "ThrowHeave", fr(THROW_HEAVE_N), False, "Action",
        "Anime two-hand heave of a big bowl kept LEVEL until it leaves the hands: from the carry, sink at the "
        "knees and draw the bowl down to the right hip with the chest coiled right (held), then drive up through "
        "the legs and hips with a step of the left foot and launch it forward and up, both arms locking out in "
        "front of and above the chest at the release, the rear heel driving up; the arms fly up and open "
        "(hands bent back), held, then the left foot steps back and he settles to a stand.",
        "chest pass / underhand shot-put launch of a heavy two-handed object; release at frame 23 like Throw",
        keys, markers=[("Release", fr(THROW_HEAVE_REL))], views=VIEWS, extra=_heave_extra(keys, "ThrowHeave")))


# ============================================================================================= SPIN
DISC_R, DISC_H = 1.2, 0.15
SPIN_N = 60
S_FEET = {R: (0.32, 0.62, 58.0, 0.0), L: (-0.30, -0.62, 76.0, 0.0)}
S_HAND = np.array([0.30, 1.25, 0.10])      # right hand centre, rest upper-torso frame: in front of the belly (a block
                                           # right arm cannot reach the left hip: 1.95 needed, 1.69 there)
S_TIPYAW = 40.0                            # disc direction (deg from the chest's forward, + to the left): it reaches to the left hip


def spin_tip(yaw_world):
    a = math.radians(yaw_world)
    return np.array([-math.sin(a), math.cos(a), 0.0])


def spin_upper(f):
    u = f / SPIN_N
    root = np.array([0.0, -0.16 + 0.035 * wave(u), -0.22 + 0.012 * wave(u, 2, 0.25)])
    tor = [0.0, 58.0 + 2.5 * wave(u), 0.0]
    up = [-6.0 + 1.0 * wave(u, 2, 0.25), 16.0 + 2.5 * wave(u, 1, 0.05), 2.0]
    head = [-4.0, -68.0 - 4.0 * wave(u, 1, 0.05), -6.0]
    return root, tor, up, head


def spin_hand(c, tipyaw, tor, up, root, guess, fore=None, elbow=None):
    tip = spin_tip(tipyaw)
    # the disc lies on the hand's Roblox Z axis (rig Y): with no forearm twist in R15, a forearm across the
    # belly keeps that axis vertical naturally; holding the X axis vertical instead raises the elbow to the face
    return solve_h(R, c, tor, up, root, tip=tip, yax=np.array([0, 0, 1.0]), fore=fore, elbow=elbow, guess=guess,
                   w_tip=5.0, w_x=20.0)


def _spin_record(name, f, arms, tor, up, head, root):
    o = F.fk({"tor": tor, "up": up, "head": head, **arms}, root)
    D = o["DhandR"]
    hc = hand_centre(o, R)
    c = hc + D @ np.array([0, 0, -(HALF_T + DISC_R)])
    INFO.setdefault(name, []).append({"hR": hc, "DR": D, "c": c, "rot": D @ np.array([[0, 0, 1.0], [0, 1.0, 0], [-1.0, 0, 0]]).T})


S_LARM = {"ual": [-8.0, 0, -86.0], "lal": [-16.0, 0, 0], "hal": [-6.0, 0, 0]}


def hold_spin():
    INFO.pop("HoldSpin", None)
    frames, guess = [], None
    for f in range(SPIN_N + 1):
        u = f / SPIN_N
        root, tor, up, head = spin_upper(f)
        legs = solve_feet({s: foot_at(*v) for s, v in S_FEET.items()}, root, tor, "hspin")
        c = torso_pt(tor, up, root, S_HAND + np.array([0, 0, 0.02 * wave(u, 2, 0.25)]))
        tyaw = tor[1] + up[1] + S_TIPYAW
        arm, guess, q = spin_hand(c, tyaw, tor, up, root, guess)
        larm = {"ual": [S_LARM["ual"][0] + 3 * wave(u, 1, 0.05), 0, S_LARM["ual"][2] - 3 * wave(u, 1, 0.05)],
                "lal": S_LARM["lal"], "hal": S_LARM["hal"]}
        _spin_record("HoldSpin", f, {**arm, **larm}, tor, up, head, root)
        INFO["HoldSpin"][-1]["q"] = q
        frames.append(("side-on, disc level at the left hip", full_pose(root, tor, up, head, legs, {**arm, **larm})))
    keys = build(frames, True)
    return slerp_pass(clip(
        "HoldSpin", 2.0, True, "Action",
        "Frisbee backhand set: side-on with the right shoulder to the lane, feet along the lane, weight on the "
        "back (left) foot; the right arm across the body holds the flat food LEVEL at the left hip, gripped at "
        "its near edge (hand palm down, the disc reaching out past the hip); the left arm out behind for "
        "balance; head turned to the target; a slow sway.",
        "disc-golf / frisbee backhand reach-back; 2.0 s loop",
        keys, markers=[], views=VIEWS, extra=_spin_extra("HoldSpin")))


def _spin_extra(name):
    pos = [0.0, -(HALF_T + DISC_R), 0.0]
    rot = np.array([[1.0, 0, 0], [0, 0, -1.0], [0, 1.0, 0]])      # CFrame.Angles(pi/2, 0, 0): disc axis -> hand Z
    ex = {"prop": {"name": "Disc", "attach": "RightHand", "glb": PROPS_DIR + r"\disc.glb", "colour": [0.95, 0.75, 0.25],
                   "grip_bone": grip_bone(R, pos, rot)},
          "_food": {"kind": "disc", "diameter": 2 * DISC_R, "thickness": 2 * DISC_H, "hand": "RightHand",
                    "cframe_in_hand": f"CFrame.new(0, {pos[1]}, 0) * CFrame.Angles(math.pi / 2, 0, 0)"}}
    if name == "ThrowSpin":
        ex["prop"]["release"] = {"t": fr(THROW_SPIN_REL)}
    return ex


THROW_SPIN_N = 45
THROW_SPIN_REL = 21
SPIN_NRM = np.array([0, 1.0, 0])
TS_COIL, TS_HOLD = 10, 13


def throw_spin():
    INFO.pop("ThrowSpin", None)
    root0, tor0, up0, head0 = spin_upper(0)
    beats = [
        (0, "smooth", root0, tor0, up0, head0),
        (TS_COIL, "out", [0.02, -0.34, -0.40], [0, 74, 0], [-10, 34, 4], [-4, -80, -8]),          # COIL
        (TS_HOLD, "in", [0.02, -0.36, -0.42], [0, 76, 0], [-11, 36, 4], [-4, -80, -8]),          # held
        (17, "smooth", [0.0, 0.10, -0.42], [0, 46, 0], [-8, 22, 2], [-2, -66, -4]),               # stride: hips open
        (19, "in", [-0.02, 0.36, -0.36], [0, 14, 0], [-6, 6, -2], [0, -20, 0]),                   # shoulders open
        (THROW_SPIN_REL, "out", [-0.02, 0.44, -0.36], [0, -6, 0], [-8, -14, -6], [2, 16, 0]),     # RELEASE
        (26, "smooth", [-0.02, 0.50, -0.38], [0, -22, 0], [-10, -26, -8], [4, 40, 0]),            # wrap
        (31, "smooth", [-0.01, 0.48, -0.34], [0, -20, 0], [-6, -22, -4], [2, 36, 0]),             # held
        (37, "smooth", [0.0, 0.26, -0.30], [0, -6, 0], [-2, -6, 0], [0, 8, 0]),
        (42, "smooth", [0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0]),
        (THROW_SPIN_N, "smooth", [0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0]),
    ]
    cv = {k: Curve([(b[0], b[i], b[1]) for b in beats]) for i, k in ((2, "root"), (3, "tor"), (4, "up"), (5, "head"))}
    feet = {R: FootTrack([(0, S_FEET[R]), (TS_COIL, (0.32, 0.62, 62.0, 0.0)), (TS_HOLD, (0.32, 0.62, 62.0, 0.0)),
                          (14, (0.32, 0.62, 62.0, 0.0)), (18, (0.42, 1.20, 22.0, 0.0)), (36, (0.42, 1.20, 22.0, 0.0)),
                          (41, (0.55, 0.0, 0.0, 0.0)), (THROW_SPIN_N, (0.55, 0.0, 0.0, 0.0))], clear=0.18),
            L: FootTrack([(0, S_FEET[L]), (TS_HOLD, S_FEET[L]), (17, (-0.30, -0.62, 66.0, 10.0)),
                          (THROW_SPIN_REL, (-0.30, -0.62, 40.0, 40.0)), (25, (-0.30, -0.62, 30.0, 46.0)),
                          (28, (-0.30, -0.62, 30.0, 40.0)), (34, (-0.55, 0.10, 0.0, 0.0)), (THROW_SPIN_N, (-0.55, 0.0, 0.0, 0.0))],
                         clear=0.2)}
    # the hand's path: before the whip in the chest's frame; the whip itself a flat arc round the body's axis
    hand_local = Curve([(0, S_HAND, "smooth"), (TS_COIL, [0.12, 1.2, 0.04], "out"),
                        (TS_HOLD, [0.1, 1.19, 0.03], "in"), (16, [0.4, 1.32, 0.1], "smooth")])
    tipyaw_rel = Curve([(0, S_TIPYAW, "smooth"), (TS_COIL, 40.0, "out"), (TS_HOLD, 40.0, "in"), (16, 36.0, "smooth")])
    # whip (world): polar (angle from +Y, + to the left; radius from the body's axis; height) of the hand centre
    WHIP0 = 16
    frames, guess, arm_free = [], None, None
    notes = {0: "HoldSpin pose", TS_COIL: "COIL: chest wound further, disc drawn back past the hip", TS_HOLD: "held",
             14: "right foot lifts", 17: "stride lands, hips open", 19: "shoulders open, the arm whips",
             THROW_SPIN_REL: "RELEASE: arm out forward-right at chest height, wrist snapped", 26: "wrap round and up",
             31: "held", 34: "back foot steps up", 41: "front foot back", 42: "stand"}
    free_keys = [(26, {"uar": [-118, 0, 88], "lar": [-22, 0, 0], "har": [-10, 0, 0]}),
                 (31, {"uar": [-108, 0, 84], "lar": [-30, 0, 0], "har": [-6, 0, 0]}),
                 (37, {"uar": [-30, 0, 18], "lar": [-30, 0, 0], "har": [0, 0, 0]}),
                 (42, {"uar": [0, 0, 0], "lar": [0, 0, 0], "har": [0, 0, 0]}),
                 (THROW_SPIN_N, {"uar": [0, 0, 0], "lar": [0, 0, 0], "har": [0, 0, 0]})]
    larm = Curve([(0, [S_LARM["ual"][0], 0, S_LARM["ual"][2], S_LARM["lal"][0], S_LARM["hal"][0]], "smooth"),
                  (TS_COIL, [30, 0, -70, -20, -6], "out"), (TS_HOLD, [31, 0, -71, -20, -6], "in"),
                  (19, [34, 0, -62, -30, -4], "smooth"), (THROW_SPIN_REL, [30, 0, -60, -36, 0], "smooth"),
                  (26, [16, 0, -48, -60, 0], "smooth"), (31, [12, 0, -44, -56, 0], "smooth"),
                  (37, [0, 0, -14, -30, 0], "smooth"), (42, [0, 0, 0, 0, 0], "smooth")])
    whip = None
    for f in range(THROW_SPIN_N + 1):
        root, tor, up, head = rl(cv["root"](f)), rl(cv["tor"](f)), rl(cv["up"](f)), rl(cv["head"](f))
        if f == 0:
            root, tor, up, head = spin_upper(0)
        legs = solve_feet({R: feet[R](f), L: feet[L](f)}, root, tor, "tspin")
        lv = larm(f)
        la = {"ual": [lv[0], 0, lv[2]], "lal": [lv[3], 0, 0], "hal": [lv[4], 0, 0]}
        if f == 0:
            u = 0.0
            la = {"ual": [S_LARM["ual"][0] + 3 * wave(u, 1, 0.05), 0, S_LARM["ual"][2] - 3 * wave(u, 1, 0.05)],
                  "lal": S_LARM["lal"], "hal": S_LARM["hal"]}
        if f <= WHIP0:
            c = torso_pt(tor, up, root, hand_local(f))
            tyaw = tor[1] + up[1] + tipyaw_rel(f)
            if f == WHIP0:
                # build the whip arc from where the hand is now to the release point
                ang0 = math.degrees(math.atan2(-c[0], c[1]))
                rad0 = math.hypot(c[0], c[1])
                rel_c = np.array([1.15, 1.80, 0.35])                     # RELEASE hand centre (world, rig)
                ang1 = math.degrees(math.atan2(-rel_c[0], rel_c[1]))
                rad1 = math.hypot(rel_c[0], rel_c[1])
                end_c = np.array([2.05, 0.10, 1.20])
                whip = {"ang": Curve([(WHIP0, ang0, "in"), (THROW_SPIN_REL, ang1, "out")]),
                        "rad": Curve([(WHIP0, rad0, "in"), (THROW_SPIN_REL, rad1, "out")]),
                        "z": Curve([(WHIP0, c[2], "smooth"), (THROW_SPIN_REL, rel_c[2], "out")]),
                        "tip": Curve([(WHIP0, tyaw, "in"), (19, tyaw - 70.0, "in"), (THROW_SPIN_REL, -8.0, "out")])}
                del end_c
        else:
            if f <= THROW_SPIN_REL:
                a, rr = math.radians(whip["ang"](f)), whip["rad"](f)
                c = np.array([-rr * math.sin(a), rr * math.cos(a), whip["z"](f)])
                tyaw = whip["tip"](f)
        if f <= THROW_SPIN_REL:
            arm, guess, q = spin_hand(c, tyaw, tor, up, root, guess)
            _spin_record("ThrowSpin", f, {**arm, **la}, tor, up, head, root)
            INFO["ThrowSpin"][-1]["q"] = q
            if f == THROW_SPIN_REL:
                arm_free = Curve([(THROW_SPIN_REL, np.concatenate([arm["uar"], arm["lar"], arm["har"]]), "out")]
                                 + [(k, np.concatenate([v["uar"], v["lar"], v["har"]]), "smooth") for k, v in free_keys])
        else:
            vv = arm_free(f)
            arm = {"uar": list(vv[0:3]), "lar": [vv[3], 0.0, 0.0], "har": [vv[6], 0.0, vv[8]]}
        frames.append((notes.get(f, "spin"), full_pose(root, tor, up, head, legs, {**arm, **la})))
    keys = build(frames, False)
    return slerp_pass(clip(
        "ThrowSpin", fr(THROW_SPIN_N), False, "Action",
        "Side-arm backhand frisbee flick of a flat food from the right hand: from the set, coil further (chest "
        "wound, disc drawn back past the left hip, weight sunk on the back foot, held), then stride at the lane "
        "with the right foot, hips open before the shoulders, the right arm whips out flat across the body "
        "keeping the disc level and the wrist snaps it out at chest height forward-right (Release); the arm "
        "wraps round and up, weight on the front foot and the back heel up, held; then back to a stand.",
        "disc-golf / frisbee backhand: reach-back, pull-through, hit, follow-through; release frame 21",
        keys, markers=[("Release", fr(THROW_SPIN_REL))], views=VIEWS, extra=_spin_extra("ThrowSpin")))


CLIPS = {"HoldPitch": hold_pitch, "HoldHeave": hold_heave, "ThrowHeave": throw_heave, "HoldSpin": hold_spin,
         "ThrowSpin": throw_spin}


# ================================================================================ V2 (behind camera)
# Coordinator, 2026-11-27, after an in-game look: the aiming camera sits ~8 studs behind and above the right
# shoulder, so a bowl at the belly or a disc at the left hip is hidden by the body. v2 below REPLACES the heave
# and spin definitions above (same clip names): the bowl is carried OVERHEAD, the disc out to the RIGHT.
# HoldPitch is unchanged (its food sits beside the head at the right shoulder, outside the silhouette).
SPIN_NRM = np.array([1.0, 0, 0])   # v2 disc lies on the hand X axis (vertical when the arm is out to the side)

# ---- heave v2: overhead. The palms cup the bowl's two BOTTOM edges from outside-below (end faces turned up
# and in by CUP deg). Reach limit (measured): a straight block arm puts the hand centre at most ~2.37 above the
# HRP centre, so with the palms at the bowl's bottom edge its centre sits ~0.8 above the head top, not 1.2.
CUP = 35.0
EDGE_X = 1.25                      # palm-face centres at x +-EDGE_X on the bowl's bottom plane


def heave_targets(c, yaw):
    Rz = rz(yaw)
    a = math.radians(CUP)
    out = {}
    for s in (R, L):
        g = SG[s]
        face = c + Rz @ np.array([g * EDGE_X, 0.0, -BOWL_H])
        tip = Rz @ np.array([-g * math.sin(a), 0.0, math.cos(a)])
        out[s] = (face - tip * HALF_T, tip, Rz)
    return out


H_FEET = {L: (-0.6, 0.0, 7.0, 0.0), R: (0.6, 0.0, -7.0, 0.0)}
H_BOWL = np.array([0.0, 0.15, 3.02])       # bowl centre, rest upper-torso frame: over the head


def heave_upper(f):
    u = f / HEAVE_N
    root = np.array([0.0, 0.0, -0.16 + 0.02 * wave(u, 2, 0.25)])
    tor = [-1.0, 0.6 * wave(u), 0.0]
    up = [1.0 + 1.0 * wave(u, 2, 0.25), 0.8 * wave(u, 1, 0.1), 0.5 * wave(u)]
    head = [6.0 + 1.0 * wave(u, 2, 0.25), -1.0 * wave(u, 1, 0.1), 0.0]
    return root, tor, up, head


def hold_heave():
    INFO.pop("HoldHeave", None)
    frames, guess = [], {}
    for f in range(HEAVE_N + 1):
        root, tor, up, head = heave_upper(f)
        legs = solve_feet({s: foot_at(*v) for s, v in H_FEET.items()}, root, tor, "hheave2")
        c = torso_pt(tor, up, root, H_BOWL)
        yaw = tor[1] + up[1]
        arms, q = heave_hands(c, yaw, tor, up, root, guess)
        _heave_record("HoldHeave", f, arms, tor, up, head, root, c, yaw)
        INFO["HoldHeave"][-1]["q"] = q
        frames.append(("overhead carry: bowl level in both hands" + (" (breath in)" if f in (15, 45) else ""),
                       full_pose(root, tor, up, head, legs, arms)))
    keys = build(frames, True)
    return slerp_pass(clip(
        "HoldHeave", 2.0, True, "Action",
        "Carrying a big bowl (2.6 across, 1.1 tall) LEVEL OVERHEAD in both hands (seen from the chase camera behind "
        "the player): arms up, elbows slightly bent, each palm cupping the bowl's bottom edge from outside-below, the "
        "two hands at the same height and the same distance apart all loop; knees soft, a slow breathing bob.",
        "carrying a full tray / pot overhead; 2.0 s loop, breaths at frames 15 and 45",
        keys, markers=[], views=VIEWS, extra=_heave_extra(keys, "HoldHeave")))


def throw_heave():
    INFO.pop("ThrowHeave", None)
    root0, tor0, up0, head0 = heave_upper(0)
    beats = [
        (0, "smooth", root0, tor0, up0, head0),
        (3, "in", [0.0, -0.02, -0.2], [0, 0, 0], [4, 0, 0], [7, 0, 0]),
        (TH_DEEP, "out", [0.0, -0.14, -0.46], [4, 0, 0], [13, 0, 0], [8, 0, 0]),       # arched back, sunk
        (TH_HOLD, "in", [0.0, -0.15, -0.49], [4, 0, 0], [14, 0, 0], [8, 0, 0]),        # held
        (18, "smooth", [0.0, 0.20, -0.38], [-3, 0, 0], [-2, 0, 0], [6, 0, 0]),           # drive
        (THROW_HEAVE_REL, "out", [0.0, 0.42, -0.30], [-6, 0, 0], [-8, 0, 0], [10, 0, 0]),  # RELEASE
        (27, "smooth", [0.0, 0.48, -0.36], [-14, 0, 0], [-22, 0, 0], [12, 0, 0]),       # follow-through, bent over
        (32, "smooth", [0.0, 0.46, -0.34], [-12, 0, 0], [-18, 0, 0], [10, 0, 0]),       # held
        (38, "smooth", [0.0, 0.26, -0.30], [-4, 0, 0], [-4, 0, 0], [2, 0, 0]),
        (42, "smooth", [0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0]),
        (THROW_HEAVE_N, "smooth", [0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0]),
    ]
    cv = {k: Curve([(b[0], b[i], b[1]) for b in beats]) for i, k in ((2, "root"), (3, "tor"), (4, "up"), (5, "head"))}
    bowl = Curve([(0, H_BOWL, "smooth"), (3, [0.0, 0.05, 3.0], "in"), (TH_DEEP, [0.0, -0.18, 2.98], "out"),
                  (TH_HOLD, [0.0, -0.2, 2.97], "in"), (18, [0.0, 0.12, 2.98], "smooth"),
                  (THROW_HEAVE_REL, [0.0, 0.60, 2.88], "smooth")])
    feet = {L: FootTrack([(0, H_FEET[L]), (15, H_FEET[L]), (20, (-0.48, 1.0, -2.0, 0.0)), (35, (-0.48, 1.0, -2.0, 0.0)),
                          (41, (-0.55, 0.0, 0.0, 0.0)), (THROW_HEAVE_N, (-0.55, 0.0, 0.0, 0.0))], clear=0.15),
            R: FootTrack([(0, H_FEET[R]), (16, H_FEET[R]), (THROW_HEAVE_REL, (0.6, 0.0, -7.0, 32.0)),
                          (27, (0.6, 0.0, -7.0, 38.0)), (32, (0.6, 0.0, -7.0, 34.0)), (36, (0.6, 0.0, -7.0, 0.0)),
                          (40, (0.6, 0.0, -7.0, 0.0)), (43, (0.55, 0.0, 0.0, 0.0)), (THROW_HEAVE_N, (0.55, 0.0, 0.0, 0.0))],
                         clear=0.12)}
    A = ("uar", "lar", "har", "ual", "lal", "hal")
    free_keys = [
        (27, {"uar": [-95, 0, 12], "lar": [-8, 0, 0], "har": [30, 0, 0], "ual": [-95, 0, -12], "lal": [-8, 0, 0], "hal": [30, 0, 0]}),
        (32, {"uar": [-50, 0, 12], "lar": [-14, 0, 0], "har": [16, 0, 0], "ual": [-50, 0, -12], "lal": [-14, 0, 0], "hal": [16, 0, 0]}),
        (38, {"uar": [-12, 0, 8], "lar": [-20, 0, 0], "har": [0, 0, 0], "ual": [-12, 0, -8], "lal": [-20, 0, 0], "hal": [0, 0, 0]}),
        (42, {k: [0, 0, 0] for k in A}), (THROW_HEAVE_N, {k: [0, 0, 0] for k in A})]
    notes = {0: "HoldHeave pose (overhead)", TH_DEEP: "DEEPEST: arched back, sunk, bowl back behind the head", TH_HOLD: "held",
             15: "left foot lifts", 18: "drive forward through the hips", 20: "left foot plants",
             THROW_HEAVE_REL: "RELEASE: arms extended forward and up", 27: "follow-through: arms swing down",
             32: "held", 41: "left foot back", 42: "stand"}
    frames, guess, free = [], {}, None
    for f in range(THROW_HEAVE_N + 1):
        root, tor, up, head = rl(cv["root"](f)), rl(cv["tor"](f)), rl(cv["up"](f)), rl(cv["head"](f))
        if f == 0:
            root, tor, up, head = heave_upper(0)
        legs = solve_feet({R: feet[R](f), L: feet[L](f)}, root, tor, "theave2")
        if f <= THROW_HEAVE_REL:
            c = torso_pt(tor, up, root, bowl(f))
            yaw = float(tor[1] + up[1])
            arms, q = heave_hands(c, yaw, tor, up, root, guess)
            _heave_record("ThrowHeave", f, arms, tor, up, head, root, c, yaw)
            INFO["ThrowHeave"][-1]["q"] = q
            if f == THROW_HEAVE_REL:
                free = Curve([(THROW_HEAVE_REL, np.concatenate([arms[k] for k in A]), "out")]
                             + [(k, np.concatenate([v[b] for b in A]), "smooth") for k, v in free_keys])
        else:
            vv = free(f)
            arms = {k: list(vv[3 * i:3 * i + 3]) for i, k in enumerate(A)}
            for k in ("lar", "lal"):
                arms[k][1:] = [0.0, 0.0]
            for k in ("har", "hal"):
                arms[k][1] = 0.0
        frames.append((notes.get(f, "heave"), full_pose(root, tor, up, head, legs, arms)))
    keys = build(frames, False)
    return slerp_pass(clip(
        "ThrowHeave", fr(THROW_HEAVE_N), False, "Action",
        "Anime overhead two-hand hurl of a big bowl kept LEVEL until it leaves the hands (a football throw-in with "
        "power): from the overhead carry, arch back and sink with the bowl drawn back behind the head (held), then "
        "drive forward through the hips with a step of the left foot and hurl it, both arms extended forward and up "
        "at the release, rear heel driving up; the arms swing down through, held bent over, then the left foot "
        "steps back and he settles to a stand.",
        "football throw-in / overhead two-hand pass; release at frame 23 like Throw",
        keys, markers=[("Release", fr(THROW_HEAVE_REL))], views=VIEWS, extra=_heave_extra(keys, "ThrowHeave")))


# ---- spin v2: forehand / discus. The disc is out to the RIGHT at shoulder height, gripped at its edge, lying
# on the hand X axis (an arm held out to the side keeps that axis vertical).
S_FEET = {L: (-0.5, 0.45, 8.0, 0.0), R: (0.62, -0.4, -22.0, 0.0)}
S_HAND = np.array([2.25, -0.35, 0.72])      # right hand centre, rest upper-torso frame: out to the side, cocked back
S_TIPYAW = -125.0                           # disc direction rel. the chest (+ left): out and back
S_LARM = {"ual": [-72.0, 0, -8.0], "lal": [-18.0, 0, 0], "hal": [-4.0, 0, 0]}


def spin_upper(f):
    u = f / SPIN_N
    root = np.array([0.0, -0.14 + 0.03 * wave(u), -0.2 + 0.012 * wave(u, 2, 0.25)])
    tor = [0.0, -12.0 + 2.0 * wave(u), 0.0]
    up = [-2.0 + 1.0 * wave(u, 2, 0.25), -16.0 + 2.0 * wave(u, 1, 0.05), 0.0]
    head = [-2.0, 26.0 - 3.0 * wave(u, 1, 0.05), 0.0]
    return root, tor, up, head


def spin_hand(c, tipyaw, tor, up, root, guess, fore=None, elbow=None):
    tip = spin_tip(tipyaw)
    return solve_h(R, c, tor, up, root, tip=tip, xax=np.array([0, 0, 1.0]), fore=fore, elbow=elbow, guess=guess,
                   w_tip=5.0, w_x=20.0)


def _spin_record(name, f, arms, tor, up, head, root):
    o = F.fk({"tor": tor, "up": up, "head": head, **arms}, root)
    D = o["DhandR"]
    hc = hand_centre(o, R)
    INFO.setdefault(name, []).append({"hR": hc, "DR": D, "c": hc + D @ np.array([0, 0, -(HALF_T + DISC_R)])})


def _spin_extra(name):
    pos = [0.0, -(HALF_T + DISC_R), 0.0]
    rot = np.array([[0, 1.0, 0], [-1.0, 0, 0], [0, 0, 1.0]])      # CFrame.Angles(0, 0, -pi/2): disc axis -> hand X
    ex = {"prop": {"name": "Disc", "attach": "RightHand", "glb": PROPS_DIR + r"\disc.glb", "colour": [0.95, 0.75, 0.25],
                   "grip_bone": grip_bone(R, pos, rot)},
          "_food": {"kind": "disc", "diameter": 2 * DISC_R, "thickness": 2 * DISC_H, "hand": "RightHand",
                    "cframe_in_hand": f"CFrame.new(0, {pos[1]}, 0) * CFrame.Angles(0, 0, -math.pi / 2)"}}
    if name == "ThrowSpin":
        ex["prop"]["release"] = {"t": fr(THROW_SPIN_REL)}
    return ex


def hold_spin():
    INFO.pop("HoldSpin", None)
    frames, guess = [], None
    for f in range(SPIN_N + 1):
        u = f / SPIN_N
        root, tor, up, head = spin_upper(f)
        legs = solve_feet({s: foot_at(*v) for s, v in S_FEET.items()}, root, tor, "hspin2")
        c = torso_pt(tor, up, root, S_HAND + np.array([0, 0, 0.03 * wave(u, 2, 0.25)]))
        arm, guess, q = spin_hand(c, tor[1] + up[1] + S_TIPYAW, tor, up, root, guess)
        larm = {"ual": [S_LARM["ual"][0] + 3 * wave(u, 1, 0.05), 0, S_LARM["ual"][2]], "lal": S_LARM["lal"], "hal": S_LARM["hal"]}
        _spin_record("HoldSpin", f, {**arm, **larm}, tor, up, head, root)
        INFO["HoldSpin"][-1]["q"] = q
        frames.append(("forehand set: disc flat out to the right", full_pose(root, tor, up, head, legs, {**arm, **larm})))
    keys = build(frames, True)
    return slerp_pass(clip(
        "HoldSpin", 2.0, True, "Action",
        "Forehand / discus ready pose (seen from the chase camera behind): the flat food held LEVEL out to the RIGHT "
        "at shoulder height in the right hand, gripped at its edge, arm out and cocked back so the disc sits clear "
        "of the body silhouette; chest coiled a little right, left arm forward for balance, weight on the back "
        "(right) foot, a slow sway.",
        "frisbee forehand / discus wind-up; 2.0 s loop",
        keys, markers=[], views=VIEWS, extra=_spin_extra("HoldSpin")))


def throw_spin():
    INFO.pop("ThrowSpin", None)
    root0, tor0, up0, head0 = spin_upper(0)
    beats = [
        (0, "smooth", root0, tor0, up0, head0),
        (TS_COIL, "out", [0.0, -0.26, -0.32], [0, -24, 0], [-2, -30, -4], [-2, 50, 0]),       # COIL
        (TS_HOLD, "in", [0.0, -0.27, -0.34], [0, -25, 0], [-2, -31, -4], [-2, 52, 0]),       # held
        (17, "smooth", [0.0, 0.10, -0.38], [0, 0, 0], [-4, -14, 0], [0, 14, 0]),             # stride lands, hips open
        (19, "in", [0.0, 0.30, -0.34], [0, 18, 0], [-6, 8, 0], [0, -26, 0]),
        (THROW_SPIN_REL, "out", [0.0, 0.40, -0.32], [0, 26, 0], [-8, 22, 4], [0, -48, 0]),  # RELEASE
        (26, "smooth", [0.0, 0.46, -0.34], [0, 36, 0], [-10, 30, 4], [0, -62, 0]),         # across the body
        (31, "smooth", [0.0, 0.44, -0.32], [0, 34, 0], [-8, 28, 2], [0, -60, 0]),          # held
        (37, "smooth", [0.0, 0.22, -0.24], [0, 10, 0], [-2, 8, 0], [0, -16, 0]),
        (42, "smooth", [0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0]),
        (THROW_SPIN_N, "smooth", [0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0]),
    ]
    cv = {k: Curve([(b[0], b[i], b[1]) for b in beats]) for i, k in ((2, "root"), (3, "tor"), (4, "up"), (5, "head"))}
    feet = {L: FootTrack([(0, S_FEET[L]), (13, S_FEET[L]), (17, (-0.42, 1.1, 0.0, 0.0)), (33, (-0.42, 1.1, 0.0, 0.0)),
                          (39, (-0.55, 0.0, 0.0, 0.0)), (THROW_SPIN_N, (-0.55, 0.0, 0.0, 0.0))], clear=0.18),
            R: FootTrack([(0, S_FEET[R]), (TS_HOLD, S_FEET[R]), (17, (0.62, -0.4, -16.0, 10.0)),
                          (THROW_SPIN_REL, (0.62, -0.4, -2.0, 34.0)), (26, (0.62, -0.4, 6.0, 40.0)),
                          (31, (0.62, -0.4, 6.0, 36.0)), (35, (0.62, -0.4, 0.0, 0.0)), (38, (0.62, -0.4, 0.0, 0.0)),
                          (43, (0.55, 0.0, 0.0, 0.0)), (THROW_SPIN_N, (0.55, 0.0, 0.0, 0.0))], clear=0.15)}
    hand_local = Curve([(0, S_HAND, "smooth"), (TS_COIL, [2.15, -0.62, 0.68], "out"),
                        (TS_HOLD, [2.14, -0.64, 0.67], "in"), (16, [2.2, -0.45, 0.62], "smooth")])
    tipyaw_rel = Curve([(0, S_TIPYAW, "smooth"), (TS_COIL, -135.0, "out"), (TS_HOLD, -137.0, "in"), (16, -128.0, "smooth")])
    larm = Curve([(0, [S_LARM["ual"][0], 0, S_LARM["ual"][2], S_LARM["lal"][0], S_LARM["hal"][0]], "smooth"),
                  (TS_COIL, [-80, 0, -14, -14, -4], "out"), (TS_HOLD, [-80, 0, -14, -14, -4], "in"),
                  (19, [-20, 0, -40, -40, 0], "smooth"), (THROW_SPIN_REL, [10, 0, -45, -50, 0], "smooth"),
                  (26, [14, 0, -42, -56, 0], "smooth"), (31, [10, 0, -38, -50, 0], "smooth"),
                  (37, [0, 0, -12, -26, 0], "smooth"), (42, [0, 0, 0, 0, 0], "smooth")])
    free_keys = [(26, {"uar": [-88, 0, -52], "lar": [-24, 0, 0], "har": [-6, 0, 0]}),
                 (31, {"uar": [-76, 0, -46], "lar": [-30, 0, 0], "har": [-4, 0, 0]}),
                 (37, {"uar": [-24, 0, -8], "lar": [-24, 0, 0], "har": [0, 0, 0]}),
                 (42, {"uar": [0, 0, 0], "lar": [0, 0, 0], "har": [0, 0, 0]}),
                 (THROW_SPIN_N, {"uar": [0, 0, 0], "lar": [0, 0, 0], "har": [0, 0, 0]})]
    notes = {0: "HoldSpin pose", TS_COIL: "COIL: chest wound right, disc drawn further back", TS_HOLD: "held",
             13: "left foot lifts", 17: "stride lands, hips open", 19: "the arm slings forward flat",
             THROW_SPIN_REL: "RELEASE: arm out forward at chest-shoulder height, wrist snapped",
             26: "follow-through across the body", 31: "held", 39: "left foot back", 42: "stand"}
    WHIP0 = 16
    frames, guess, arm_free, whip = [], None, None, None
    for f in range(THROW_SPIN_N + 1):
        root, tor, up, head = rl(cv["root"](f)), rl(cv["tor"](f)), rl(cv["up"](f)), rl(cv["head"](f))
        if f == 0:
            root, tor, up, head = spin_upper(0)
        legs = solve_feet({R: feet[R](f), L: feet[L](f)}, root, tor, "tspin2")
        lv = larm(f)
        la = {"ual": [lv[0], 0, lv[2]], "lal": [lv[3], 0, 0], "hal": [lv[4], 0, 0]}
        if f == 0:
            la = {"ual": [S_LARM["ual"][0] + 3 * wave(0.0, 1, 0.05), 0, S_LARM["ual"][2]], "lal": S_LARM["lal"], "hal": S_LARM["hal"]}
        if f <= WHIP0:
            c = torso_pt(tor, up, root, hand_local(f))
            tyaw = tor[1] + up[1] + tipyaw_rel(f)
            if f == WHIP0:
                ang0, rad0 = math.degrees(math.atan2(-c[0], c[1])), math.hypot(c[0], c[1])
                rel_c = np.array([0.95, 1.9, 0.55])
                ang1, rad1 = math.degrees(math.atan2(-rel_c[0], rel_c[1])), math.hypot(rel_c[0], rel_c[1])
                whip = {"ang": Curve([(WHIP0, ang0, "in"), (THROW_SPIN_REL, ang1, "out")]),
                        "rad": Curve([(WHIP0, rad0, "smooth"), (THROW_SPIN_REL, rad1, "out")]),
                        "z": Curve([(WHIP0, c[2], "smooth"), (THROW_SPIN_REL, rel_c[2], "out")]),
                        "tip": Curve([(WHIP0, tyaw, "in"), (19, tyaw + 40.0, "in"), (THROW_SPIN_REL, -20.0, "out")])}
        elif f <= THROW_SPIN_REL:
            a, rr = math.radians(whip["ang"](f)), whip["rad"](f)
            c = np.array([-rr * math.sin(a), rr * math.cos(a), whip["z"](f)])
            tyaw = whip["tip"](f)
        if f <= THROW_SPIN_REL:
            arm, guess, q = spin_hand(c, tyaw, tor, up, root, guess)
            _spin_record("ThrowSpin", f, {**arm, **la}, tor, up, head, root)
            INFO["ThrowSpin"][-1]["q"] = q
            if f == THROW_SPIN_REL:
                arm_free = Curve([(THROW_SPIN_REL, np.concatenate([arm["uar"], arm["lar"], arm["har"]]), "out")]
                                 + [(k, np.concatenate([v["uar"], v["lar"], v["har"]]), "smooth") for k, v in free_keys])
        else:
            vv = arm_free(f)
            arm = {"uar": list(vv[0:3]), "lar": [vv[3], 0.0, 0.0], "har": [vv[6], 0.0, vv[8]]}
        frames.append((notes.get(f, "spin"), full_pose(root, tor, up, head, legs, {**arm, **la})))
    keys = build(frames, False)
    return slerp_pass(clip(
        "ThrowSpin", fr(THROW_SPIN_N), False, "Action",
        "Forehand side-arm sling of a flat food from the right hand: from the set (disc out to the right), coil a "
        "little further back (held), stride at the lane with the left foot, hips then shoulders open, the arm slings "
        "forward flat across the body keeping the disc level and the wrist snaps it out with the arm extended "
        "forward at chest-to-shoulder height (Release); the arm follows through across the body, rear heel up, "
        "held; then back to a stand.",
        "frisbee forehand / discus sling; release frame 21",
        keys, markers=[("Release", fr(THROW_SPIN_REL))], views=VIEWS, extra=_spin_extra("ThrowSpin")))


CLIPS = {"HoldPitch": hold_pitch, "HoldHeave": hold_heave, "ThrowHeave": throw_heave, "HoldSpin": hold_spin,
         "ThrowSpin": throw_spin}


# ============================================================================================ CHECKS
def check(name, spec=None):
    """FK-model numbers per frame: food clearance from every part (the holding hand(s) listed apart),
    solver residuals, heave hand spacing / level / bowl-to-midpoint constancy, spin disc tilt."""
    import fkcheck as C
    spec = spec or CLIPS[name]()
    fps = spec["fps"]
    n = int(round(spec["duration"] * fps)) + (0 if spec["loop"] else 1)
    rel = next((int(round(m["time"] * fps)) for m in spec.get("markers", []) if m["name"] == "Release"), n - 1)
    held = range(0, rel + 1)
    worst_body, worst_hand, worst_q = (9, None), (9, None), (0, 0, None)
    lines = []
    for f in held:
        b, root = C.sample(spec, f / fps)
        o = F.fk(b, root)
        boxes = part_boxes(o)
        if name in ("HoldPitch",):
            food = Food("sphere", hand_centre(o, R) + o["DhandR"] @ np.array([0, 0, -(HALF_T + PITCH_R)]), r=PITCH_R)
            grip = {"RightHand"}
        elif name in ("HoldHeave", "ThrowHeave"):
            rec = INFO[name][f]
            food = Food("disc", rec["c"], rz(rec["yaw"]), R_=BOWL_R, h=BOWL_H)
            grip = {"RightHand", "LeftHand"}
        else:
            D = o["DhandR"]
            c = hand_centre(o, R) + D @ np.array([0, 0, -(HALF_T + DISC_R)])
            rot = np.column_stack([D @ np.array([0, 0, -1.0]), np.cross(D @ SPIN_NRM, D @ np.array([0, 0, -1.0])), D @ SPIN_NRM])
            food = Food("disc", c, rot, R_=DISC_R, h=DISC_H)
            grip = {"RightHand"}
        cl = food.clearance(boxes)
        for k, v in cl.items():
            if k in grip:
                if v < worst_hand[0]:
                    worst_hand = (v, (f, k))
            elif v < worst_body[0]:
                worst_body = (v, (f, k))
        q = INFO.get(name, [{}] * (f + 1))[f].get("q") if f < len(INFO.get(name, [])) else None
        if q:
            qq = q.values() if isinstance(q, dict) else [q]
            for e, a in qq:
                if e > worst_q[0] or a > worst_q[1]:
                    worst_q = (max(e, worst_q[0]), max(a, worst_q[1]), f)
        if name in ("HoldHeave", "ThrowHeave") and (f % 3 == 0 or f == rel):
            rec = INFO[name][f]
            hR, hL = hand_centre(o, R), hand_centre(o, L)
            mid = (hR + hL) / 2
            xa = unit(hR - hL)
            yb = np.array([0, 0, 1.0])
            zb = np.cross(xa, yb)
            fr_ = np.column_stack([xa, yb, -zb]) if False else None
            del fr_
            lines.append(f"  f{f:02d} hands {np.linalg.norm(hR - hL):.4f} apart, dz {hR[2] - hL[2]:+.4f}, "
                         f"bowl - mid {np.round(rz(rec['yaw']).T @ (rec['c'] - mid), 4)} (bowl frame)")
        if name in ("HoldSpin", "ThrowSpin") and (f % 3 == 0 or f == rel):
            D = o["DhandR"]
            tilt = math.degrees(math.acos(np.clip(abs(D @ SPIN_NRM @ np.array([0, 0, 1.0])), -1, 1)))
            lines.append(f"  f{f:02d} disc centre {np.round(food.c, 3)} tilt {tilt:.2f} deg")
    print(f"=== {name}: {n} frames, food checked on frames 0..{rel}")
    print(f"  food vs body (not the holding hands): worst clearance {worst_body[0]:+.3f} at {worst_body[1]}")
    print(f"  food vs holding hand(s): worst {worst_hand[0]:+.3f} at {worst_hand[1]} (0 = touching, < 0 = inside)")
    print(f"  hand solve: worst centre miss {worst_q[0]:.4f}, worst orientation miss {worst_q[1]:.2f} deg (frame {worst_q[2]})")
    print("\n".join(lines))
    print("\n".join(C.check(name, quiet=True)[1:4]) if False else "", end="")
    return spec


def release_report(name, spec=None):
    import fkcheck as C
    spec = spec or CLIPS[name]()
    fps = spec["fps"]
    rel = next(int(round(m["time"] * fps)) for m in spec["markers"] if m["name"] == "Release")
    pts = {}
    for f in (rel - 1, rel, rel + 1):
        b, root = C.sample(spec, f / fps)
        o = F.fk(b, root)
        pts[f] = (hand_centre(o, R), hand_centre(o, L))
    for i, s in enumerate(("RightHand", "LeftHand")):
        p = pts[rel][i]
        v = (pts[rel + 1][i] - pts[rel - 1][i]) * fps / 2
        print(f"  {name} {s} at Release t={rel / fps:.4f}: HRP space (right, up, forward) "
              f"({p[0]:+.3f}, {p[2]:+.3f}, {p[1]:+.3f}); velocity {np.linalg.norm(v):.2f} studs/s along "
              f"({unit(v)[0]:+.2f}, {unit(v)[2]:+.2f}, {unit(v)[1]:+.2f}) [roblox CFrame pos {to_roblox(p)}]")


if __name__ == "__main__":
    import sys
    names = sys.argv[2:] if len(sys.argv) > 2 else list(CLIPS)
    if sys.argv[1] == "check":
        for nm in names:
            s = check(nm)
            if any(m["name"] == "Release" for m in s.get("markers", [])):
                release_report(nm, s)
