"""Batch r10 (2026-11-27, plan 13 phase E, second pair): five player clips for training grounds 5 and 6. All
Action, full body; the HRP stays where the game anchors it (standing height): the body is moved through the ROOT
(LowerTorso) joint on Z only, and the plank of the push-up pivots on the toes (ankles flex), so nothing moves
horizontally at the root.

Ground 5, GRAVITY CHAMBER (profile camera).
  TrainPushup   2.000 s loop: two push-ups, Rep at 0.5000 (frame 15) and 1.5000 (frame 45), chest 0.25 above the
                floor at each Rep. Fast heavy descent, 2-frame trembling hold, slow strained push, lock-out settle.
                Hands (palms flat) and toes SOLVED planted every frame.
  GravityFloat  2.000 s loop, the awakening: weightless 2.2 studs above standing height, relaxed, arms drifting up and
                out, knees soft (one leg higher), head back, bob +-0.2, a gentle roll.
Ground 6, SPIRIT ORB (front camera).
  TrainOrb      4.000 s loop: feet wide, both hands overhead palms up under the orb; it grows 0..3.5 s (knees sink,
                elbows give, torso leans back, a growing tremor), Pulse 3.5000 (frame 105): a 3-frame push to full
                extension, chest up; recover to frame 0 by 4.0.
  OrbAwaken     2.000 s loop: arms at full stretch overhead and wider, legs deep, back arched, head thrown back,
                shaking under the load.
  OrbThrow      1.200 s one-shot: frame 0 = OrbAwaken frame 0; dip 0..0.35 s, full-body throw straight up and a little
                forward, Release 0.5000 (frame 15) arms at full extension, held reach, settle into TrainOrb frame 0.

  python tools/anim/clips_r10.py check [Name ...]
  python tools/anim/clips_r10.py numbers        hand centres / LowerTorso heights for the README (FK)
"""
import copy
import functools
import math

import numpy as np
from scipy.optimize import least_squares

import clips_r8 as M
import fkmodel as F
from animlib import clip
from clips_r3 import hand_centre, solve_feet
from clips_r4 import Curve
from clips_r7 import build, foot_at, full_pose, part_boxes
from clips_r8 import L, R, solve_arm8
from clips_train import fr, slerp_pass

SG = {R: 1.0, L: -1.0}
VIEW_PROF = {"side": [1.0, 0.0, 0.05], "front34": [0.7, 1.0, 0.3], "left": [-1.0, 0.0, 0.05]}
VIEW_FRONT = {"front": [0.0, 1.0, -0.05], "front34": [0.7, 1.0, 0.1], "side": [1.0, 0.0, 0.08]}
EASE = M.EASE


def unit(v):
    return M.unit(v)


# ============================================================================================ PUSH-UP
TOE = np.array([0.0, 0.5, -0.252])        # the toe edge's centre in the foot box (local): it stays on the floor
TOE_Y = -2.1                             # where the toes are planted (rig y)
LEG_Z = 4.0                               # legs a touch apart
HAND_X = 1.65                             # palm centres: a little wider than the shoulders' arm line (1.5)
HAND_Z = F.FLOOR + 0.15                   # the palm block lies flat on the floor


def _plank_bones(rz, tx, fx, ux=0.0, hx=0.0):
    return {"tor": [tx, 0, 0], "up": [ux, 0, 0], "ulr": [hx, 0, LEG_Z], "ull": [hx, 0, -LEG_Z], "llr": [0, 0, 0],
            "lll": [0, 0, 0], "fr": [fx, 0, 0], "fl": [fx, 0, 0]}


def chest_low(o):
    for name, c, D, h in part_boxes(o):
        if name == "UpperTorso":
            return float(M._corner_pts(c, D, h, 2)[:, 2].min())


@functools.lru_cache(None)
def plank(h, ux=0.0):
    """root drop, TORSO pitch and foot angle that put the toes on their mark and the chest's lowest point h above the
    floor, the body one straight line (legs in line with the pelvis)."""
    def res(v):
        o = F.fk(_plank_bones(v[0], v[1], v[2], ux, v[3]), v[0])
        t = o["ankleR"] + o["DfootR"] @ TOE
        return [(t[1] - TOE_Y) * 10, (t[2] - F.FLOOR) * 10, (chest_low(o) - (F.FLOOR + h)) * 10, v[3] * 0.004]
    sol = least_squares(res, np.array([-2.0, -70.0, 40.0, 0.0]), xtol=1e-12, ftol=1e-12)
    return tuple(float(x) for x in sol.x), float(np.abs(sol.fun[:3]).max() / 10)


def _shoulder(o, s):
    return o["shoulder" + s] + o["D_up"] @ np.array([0.5 * SG[s], 0, -0.15])


@functools.lru_cache(None)
def pushup_layout():
    """H_TOP (arms all but straight at the top) and the palm y (under the shoulders at the bottom, a little forward)"""
    (rz, tx, fx, hx), _ = plank(0.25)
    o = F.fk(_plank_bones(rz, tx, fx, 0.0, hx), rz)
    hy = float(_shoulder(o, R)[1]) + 0.12
    best = None
    for h in np.arange(0.7, 1.6, 0.01):
        (rz, tx, fx, hx), e = plank(round(float(h), 3))
        if e > 0.005:
            continue
        o = F.fk(_plank_bones(rz, tx, fx, 0.0, hx), rz)
        d = np.linalg.norm(_shoulder(o, R) - np.array([HAND_X, hy, HAND_Z]))
        if best is None or abs(d - 1.42) < best[0]:
            best = (abs(d - 1.42), round(float(h), 3))
    return best[1], hy


# depth of the push-up: 0 = top (arms locked), 1 = chest 0.25 above the floor
PU_N = 60
DEPTH = Curve([(0, 0.0, "in"), (13, 0.97, "out"), (15, 1.0, "linear"), (16, 1.0, "linear"), (17, 1.0, "smooth"),
               (27, 0.0, "out"), (28, -0.025, "smooth"), (30, 0.0, "in"),
               (43, 0.97, "out"), (45, 1.0, "linear"), (46, 1.0, "linear"), (47, 1.0, "smooth"),
               (57, 0.0, "out"), (58, -0.025, "smooth"), (60, 0.0, "linear")])
QUIVER = {15: 0.02, 16: -0.02, 17: 0.015, 18: -0.01, 45: 0.02, 46: -0.02, 47: 0.015, 48: -0.01,
          21: 0.008, 23: -0.008, 51: 0.008, 53: -0.008}           # the hold trembles, the push strains


def pushup_frame(f, guess):
    h_top, hy = pushup_layout()
    d = float(DEPTH(f))
    h = h_top + (0.25 - h_top) * d + QUIVER.get(f, 0.0)
    ux = 1.5 * math.sin(math.pi * f / 1.0) * (1 if f in QUIVER else 0)   # 0: tremor rides on h
    (rz, tx, fx, hx), err = plank(round(h, 4))
    if err > 0.005:
        raise ValueError(f"pushup f{f}: plank miss {err:.4f}")
    tor, up = [tx, 0, 0], [ux, 0, 0]
    arms = {}
    for s in (R, L):
        c = np.array([SG[s] * HAND_X, hy, HAND_Z])
        fore = unit([0, 0.12 + 0.45 * max(0.0, d), -1.0])          # elbows travel BACK along the ribs as they bend
        a, guess[s], q = solve_arm8(s, c, tor, up, np.array([0, 0, rz]), tip=np.array([0, 0, -1.0]), w_tip=4.0,
                                    fore=fore, w_fore=1.5, w_wrist=0.01, guess=guess.get(s))
        arms.update(a)
    head = [-tx * 0.6 - 20.0, 0.0, 0.0]          # in line with the spine, eyes a little ahead along the floor
    b = full_pose(np.array([0, 0, rz]), tor, up, head,
                  {R: {"ul": [hx, 0, LEG_Z], "ll": [0, 0, 0], "f": [fx, 0, 0]},
                   L: {"ul": [hx, 0, -LEG_Z], "ll": [0, 0, 0], "f": [fx, 0, 0]}}, arms)
    return b, (rz, tx, fx, h)


def train_pushup():
    frames, guess = [], {}
    for _ in range(2):            # second pass warm-started from the loop's end: frame 0 on the loop's own branch
        frames = []
        for f in range(PU_N + 1):
            b, _ = pushup_frame(f, guess)
            frames.append(("", b))
    notes = {0: "top: arms locked, a straight plank", 1: "DROP: gravity pulls the chest down fast",
             15: "REP: chest 0.25 above the floor, elbows back along the ribs", 16: "held, trembling",
             17: "PUSH: slow, strained", 27: "lock-out", 28: "settle", 30: "top",
             31: "DROP", 45: "REP", 46: "held, trembling", 47: "PUSH", 57: "lock-out", 58: "settle"}
    last = ""
    for i, (_, b) in enumerate(frames):
        last = notes.get(i, last)
        frames[i] = (last, b)
    return slerp_pass(clip(
        "TrainPushup", 2.0, True, "Action",
        "Push-ups under crushing gravity, seen in profile: a straight plank from head to heels on planted toes, palms "
        "flat a little wider than the shoulders; each rep drops fast and heavy until the chest is 0.25 above the "
        "floor, the elbows bending BACK along the ribs, a trembling 2-frame hold, a slow strained push to locked arms "
        "and a small settle.",
        "push-up, 2 reps per 2.0 s loop; Rep at frames 15 and 45",
        build(frames, True), markers=[("Rep", fr(15)), ("Rep", fr(45))], views=VIEW_PROF,
        extra={"_floor_hands": {"palm_centres_rig": [[HAND_X, pushup_layout()[1], HAND_Z],
                                                    [-HAND_X, pushup_layout()[1], HAND_Z]]}}))


def gravity_float():
    frames = []
    for f in range(PU_N + 1):
        u = f / PU_N
        w = 2 * math.pi * u
        root = np.array([0.0, 0.0, 2.6 + 0.2 * math.sin(w)])
        tor = [-3.0 + 2.0 * math.sin(w + 0.4), 0.0, 4.0 * math.sin(w + 1.1)]
        up = [6.0 + 2.0 * math.sin(w + 0.9), 3.0 * math.sin(w + 0.3), -2.5 * math.sin(w + 1.6)]
        head = [-(tor[0] + up[0]) + 18.0 + 3.0 * math.sin(w + 1.2), -up[1] * 0.5, -(tor[2] + up[2]) * 0.4]
        legs = {R: {"ul": [-20.0 - 6.0 * math.sin(w + 0.5), 0.0, 6.0], "ll": [34.0 + 6.0 * math.sin(w + 0.9), 0, 0],
                    "f": [22.0, 0, 0]},
                L: {"ul": [-6.0 - 4.0 * math.sin(w + 1.7), 0.0, -5.0], "ll": [16.0 + 5.0 * math.sin(w + 2.1), 0, 0],
                    "f": [28.0, 0, 0]}}
        arms = {}
        for s in (R, L):
            g = SG[s]
            ph = 0.0 if s == R else 0.9
            sf = s.lower()
            arms["ua" + sf] = [-12.0 + 6.0 * math.sin(w + ph), 0.0, g * (64.0 + 8.0 * math.sin(w + ph + 0.6))]
            arms["la" + sf] = [-26.0 - 6.0 * math.sin(w + ph + 1.2), 0.0, 0.0]
            arms["ha" + sf] = [-18.0, 0.0, 0.0]
        frames.append(("weightless: drifting, arms floating up and out", full_pose(root, tor, up, head, legs, arms)))
    return slerp_pass(clip(
        "GravityFloat", 2.0, True, "Action",
        "Gravity flipped: the hero floats weightless 2.2 studs above standing height (feet ~2.2 clear of the floor), "
        "upright but relaxed: arms drifting out and up, hands open, knees soft with the right leg higher, head back, "
        "a slow bob of +-0.2 and a gentle roll of the torso.",
        "zero-gravity float, 2.0 s loop", build(frames, True), markers=[], views=VIEW_PROF))


# ================================================================================================ ORB
OR_FEET = {R: (1.1, 0.0, -14.0, 0.0), L: (-1.1, 0.0, 14.0, 0.0)}
OR_N = 120


def _legs(root, tor, tag, heel=0.0):
    fs = {s: foot_at(x, y, yaw, heel) for s, (x, y, yaw, _) in OR_FEET.items()}
    return solve_feet(fs, root, tor, tag)


def orb_arms(lift, bend, wide=0.0, flick=0.0, fwd=0.0, shake=0.0, k=0):
    """both hands overhead, palms (end faces) up: lift = upper-arm flexion past horizontal, bend = elbow,
    wide = extra spread; the wrist keeps the palm up as the elbow bends; shake alternates per frame"""
    out = {}
    j = shake * (1 if k % 2 else -1)
    for s in (R, L):
        g = SG[s]
        sf = s.lower()
        out["ua" + sf] = [-(lift + fwd) + j, 0.0, g * (16.0 + wide + 0.6 * j)]
        out["la" + sf] = [-bend - 0.8 * j, 0.0, 0.0]
        out["ha" + sf] = [bend * 0.85 + flick, 0.0, 0.0]
    return out


def orb_body(root_z, lean, head_x, tor_z=0.0):
    root = np.array([0.0, 0.0, root_z])
    tor = [-2.0, 0.0, tor_z]
    up = [lean, 0.0, -tor_z * 0.6]
    head = [head_x, 0.0, -(tor_z * 0.4) * 0.5]
    return root, tor, up, head


TO_GROW = Curve([(0, 0.0, "smooth"), (105, 1.0, "linear"), (108, 1.0, "smooth"), (120, 0.0, "smooth")])


def orb_frame(f):
    """TrainOrb at frame f: growth g 0..1 to the Pulse, a 3-frame push, recovery"""
    if f <= 105:
        g = f / 105.0
        g = g * g * (3 - 2 * g) * 0.4 + g * 0.6            # slow, steady growth
        root_z, lean, head_x = -0.22 - 0.36 * g, 3.0 + 6.0 * g, 10.0 + 2.0 * g
        lift, bend = 166.0 - 6.0 * g, 10.0 + 34.0 * g
        shake = 2.2 * g * g
        p = (root_z, lean, head_x, lift, bend, shake, 0.0)
    elif f <= 108:     # PULSE: a sharp push to full extension, chest up
        u = EASE["out"]((f - 105) / 3.0)
        root_z, lean, head_x = -0.58 + 0.26 * u, 9.0 + 5.0 * u, 12.0 + 6.0 * u
        lift, bend = 160.0 + 12.0 * u, 44.0 - 42.0 * u
        p = (root_z, lean, head_x, lift, bend, 0.0, 10.0 * u)
    else:              # recover to frame 0
        u = EASE["smooth"]((f - 108) / 12.0)
        a = (-0.32, 14.0, 18.0, 172.0, 2.0, 0.0, 10.0)
        b = (-0.22, 3.0, 10.0, 166.0, 10.0, 0.0, 0.0)
        p = tuple(a[i] + (b[i] - a[i]) * u for i in range(7))
    root_z, lean, head_x, lift, bend, shake, flick = p
    root, tor, up, head = orb_body(root_z, lean, head_x)
    up = [up[0] + 0.6 * shake * (1 if f % 2 else -1), up[1], up[2]]
    arms = orb_arms(lift, bend, shake=shake, k=f, flick=flick)
    return root, tor, up, head, arms


def train_orb():
    frames = []
    for f in range(OR_N + 1):
        root, tor, up, head, arms = orb_frame(f % OR_N)
        frames.append(("", full_pose(root, tor, up, head, _legs(root, tor, "orb"), arms)))
    notes = {0: "orb overhead, palms up, feet wide", 20: "the orb grows: knees sink, elbows give",
             70: "heavier: leaning back, the arms tremble", 105: "PULSE: push up to full extension",
             108: "extended, chest up", 109: "recover"}
    last = ""
    for i, (_, b) in enumerate(frames):
        last = notes.get(i, last)
        frames[i] = (last, b)
    return slerp_pass(clip(
        "TrainOrb", 4.0, True, "Action",
        "Holding a growing ball of energy overhead, facing the camera: feet wide and braced, both palms up under the "
        "orb; it grows and gets heavier for 3.5 s (knees sink, elbows give, the torso leans back, a growing tremor), "
        "Pulse: a sharp 3-frame push to full extension with the chest lifting, then recovery.",
        "spirit-bomb charge, 4.0 s loop; Pulse at frame 105 (3.5000 s)",
        build(frames, True), markers=[("Pulse", fr(105))], views=VIEW_FRONT))


AW_N = 60


def awaken_frame(f):
    u = (f % AW_N) / AW_N
    sh = 0.6 * math.sin(2 * math.pi * 13 * u) + 0.4 * math.sin(2 * math.pi * 19 * u + 1.0)   # periodic over the loop
    sw = math.sin(2 * math.pi * u)
    root, tor, up, head = orb_body(-0.66 + 0.02 * sh + 0.03 * sw, 16.0 + 1.5 * sh, 30.0 - 2.0 * sh, tor_z=3.0 * sw)
    arms = orb_arms(170.0 + 1.5 * sh, 4.0 + 2.0 * abs(sh), wide=-14.0, shake=1.2 * sh, k=0)
    return root, tor, up, head, arms


def orb_awaken():
    frames = []
    for f in range(AW_N + 1):
        root, tor, up, head, arms = awaken_frame(f)
        frames.append(("under the enormous orb: shaking", full_pose(root, tor, up, head, _legs(root, tor, "awaken"),
                                                                     arms)))
    return slerp_pass(clip(
        "OrbAwaken", 2.0, True, "Action",
        "Awakening: the orb is enormous. Arms at full stretch overhead and wider, legs braced deep, back arched, head "
        "thrown back looking up at it, the whole body shaking under the load over a slow sway.",
        "straining under a giant energy ball, 2.0 s loop", build(frames, True), markers=[], views=VIEW_FRONT))


TH_N = 36


def orb_throw():
    aw0 = orb_awaken()["keyframes"][0]["bones"]
    tr0 = train_orb()["keyframes"][0]["bones"]
    r0, t0, u0, h0, a0 = awaken_frame(0)
    # (root z, lean, head x, lift, bend, wide, fwd, flick, heel)
    K = [(0, (float(r0[2]), u0[0], h0[0], 170.0, 4.0, -14.0, 0.0, 0.0, 0.0), "smooth"),
         (10, (-0.9, 4.0, 14.0, 150.0, 62.0, -6.0, 0.0, 0.0, 0.0), "in"),        # DIP: knees, arms bend
         (15, (-0.12, -6.0, 22.0, 176.0, 0.0, -4.0, -26.0, 30.0, 22.0), "out"),   # RELEASE: up and a little forward
         (22, (-0.14, -8.0, 24.0, 178.0, 2.0, -4.0, -28.0, 34.0, 18.0), "smooth"),  # held reach
         (33, (-0.22, 3.0, 10.0, 166.0, 10.0, 0.0, 0.0, 0.0, 0.0), "smooth"),
         (36, (-0.22, 3.0, 10.0, 166.0, 10.0, 0.0, 0.0, 0.0, 0.0), "smooth")]
    cur = Curve([(f, v, e) for f, v, e in K])
    frames = []
    for f in range(TH_N + 1):
        rz, lean, hx, lift, bend, wide, fwd, flick, heel = [float(x) for x in cur(f)]
        root, tor, up, head = orb_body(rz, lean, hx)
        arms = orb_arms(lift, bend, wide=wide, fwd=fwd, flick=flick)
        frames.append(("", full_pose(root, tor, up, head, _legs(root, tor, "throw", heel=heel), arms)))
    frames[0] = ("", copy.deepcopy(aw0))
    for i in (33, 34, 35, 36):
        frames[i] = ("", copy.deepcopy(tr0))
    notes = {0: "= OrbAwaken frame 0", 1: "DIP: knees bend, arms load", 10: "loaded", 11: "THROW: legs extend, arms whip",
             15: "RELEASE: arms at full extension up and forward, hands flick open", 16: "held reach",
             22: "settle", 33: "= TrainOrb frame 0"}
    last = ""
    for i, (_, b) in enumerate(frames):
        last = notes.get(i, last)
        frames[i] = (last, b)
    return slerp_pass(clip(
        "OrbThrow", 1.2, False, "Action",
        "Ending the awakening: from OrbAwaken a short dip (knees and arms load, 0-0.35 s), then a full-body throw of "
        "the orb straight up and a little forward: legs extend onto the toes, arms whip up and forward to full "
        "extension at Release, hands flick open; a held reach, then settle into TrainOrb's first frame.",
        "overhead full-body throw; Release at frame 15 (0.5000 s)",
        build(frames, False), markers=[("Release", fr(15))], views=VIEW_FRONT))


CLIPS = {"TrainPushup": train_pushup, "GravityFloat": gravity_float, "TrainOrb": train_orb,
         "OrbAwaken": orb_awaken, "OrbThrow": orb_throw}


def numbers():
    import fkcheck as C
    h_top, hy = pushup_layout()
    print(f"push-up: palm centres (x, y, z) (+{HAND_X:.2f}, {hy:+.3f}, {HAND_Z:+.3f}) and (-{HAND_X:.2f}, ...); "
          f"top chest height {h_top:.2f}; toes y {TOE_Y}")
    for name, frames in (("TrainPushup", (0, 15)), ("GravityFloat", (0, 15, 45)), ("TrainOrb", (0, 104, 108)),
                         ("OrbAwaken", (0,)), ("OrbThrow", (10, 15))):
        spec = CLIPS[name]()
        for f in frames:
            b, root = C.sample(spec, f / 30.0)
            o = F.fk(b, root)
            lt = float(np.asarray(root)[2]) - 0.8
            hr, hl = hand_centre(o, R), hand_centre(o, L)
            tip = o["DhandR"] @ np.array([0, 0, -1.0])
            print(f"  {name} f{f}: LowerTorso centre z {lt:+.3f} (standing -0.800); RightHand ({hr[0]:+.3f}, "
                  f"{hr[1]:+.3f}, {hr[2]:+.3f}) LeftHand ({hl[0]:+.3f}, {hl[1]:+.3f}, {hl[2]:+.3f}) palm-up "
                  f"{tip[2]:+.2f}")


if __name__ == "__main__":
    import sys
    names = sys.argv[2:] if len(sys.argv) > 2 else list(CLIPS)
    if sys.argv[1] == "check":
        for nm in names:
            M.check(nm, CLIPS[nm]())
    elif sys.argv[1] == "numbers":
        numbers()
