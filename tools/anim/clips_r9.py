"""Batch r9 (2026-11-27, plan 13 phase E): eight player clips for training grounds 3 and 4. All Action, full body,
the HRP and the root never move horizontally (ROOT z only). Built on clips_r8's machinery (per-frame keys, planted
feet solved every frame, arm key poses slerped joint by joint, hits solved with the fist's frontmost knuckle corner on
the plane).

Ground 3, BOULDER BREAKER (profile camera). Struck face = the plane y = 2.87 in front of the HRP (r8's post plane,
same planted feet as TrainPost: left front stance).
  TrainBoulder    4.000 s loop. Right palm-heel thrust, Hit 1.5000 (frame 45); left palm thrust, Hit 3.5000 (frame
                  105); each: a long slow coil from the hip (the player times a needle), a 3-frame snap, the palm ON
                  the rock for 3 frames while the body shudders, a slow recoil.
  BoulderBarrage  1.000 s loop, the awakening. 0.25 s does not fall on 30 fps frames: 4 blows at frames 4, 11, 19, 26
                  (0.1333, 0.3667, 0.6333, 0.8667: 7 and 8 frames apart, 0.25 s on average), right / left / right /
                  left, the chest whipping side to side, leaning in.
  BoulderFinish   1.300 s one-shot. Frame 0 = BoulderBarrage frame 0; both palms drawn back to the hips, a square
                  double palm thrust (lunging 40 deg into the rock) lands on the plane at Hit 0.6000 (frame 18), held,
                  settles to TrainBoulder frame 0 by frame 36.
Ground 4, THUNDER PEAK (front camera; the rods stand BEHIND the hero: left, middle, right).
  PeakReady   2.000 s loop: alert, coiled stance, arms half raised, head scanning, breathing bob.
  PeakLeft    0.800 s: the hero's RIGHT hand (the camera's left) thrown up and out at 45 deg; Catch 0.1333 (frame 4).
  PeakMid     0.800 s: the right hand straight up overhead, head back; Catch 0.1333.
  PeakRight   0.800 s: mirror of PeakLeft (the hero's LEFT hand); Catch 0.1333.
              Each: frame 0 = PeakReady frame 0, the pose by frame 4, a tremor to frame 15 (the bolt in the body: the
              shoulders shake, the other fist clenched), back to PeakReady frame 0 by frame 24.
  PeakStorm   2.000 s loop, the awakening: arms up and out in a V, chest out, head back, braced; a fast small shake
              over a slow sway.

  python tools/anim/clips_r9.py check [Name ...]
  python tools/anim/clips_r9.py catch           the catching hand's centre at Catch (HRP space) for the README
"""
import copy
import functools
import math

import numpy as np

import clips_r8 as M
import fkmodel as F
from animlib import clip
from clips_r3 import hand_centre, solve_feet
from clips_r4 import Curve
from clips_r7 import build, foot_at, full_pose
from clips_r8 import (AIM_SEED, HIKITE, L, P_FEET, R, ArmTrack, aim, head_level, hit, post_body, post_frames)
from clips_train import fr, slerp_pass

VIEW_ROCK = {"side": [1.0, 0.0, 0.08], "front34": [0.7, 1.0, 0.3], "left": [-1.0, 0.0, 0.08]}
VIEW_PEAK = {"front": [0.0, 1.0, -0.05], "front34": [0.7, 1.0, 0.1], "side": [1.0, 0.0, 0.08]}


def _rock_contact():
    return {"contact_distance": M.POST_FACE, "solved_plane": M.POST_D, "plane": "y = contact_distance (rig +Y = facing)",
            "what": "the striking palm's (hand block's) frontmost corner on the plane"}


def _rock_scene():
    return [{"pos": [0, M.POST_FACE + 1.3, -0.4], "size": [3.4, 2.6, 5.2], "colour": [0.46, 0.45, 0.47]}]


def _q(tracks):
    out = {}
    for s, t in tracks.items():
        for f, q in t.q.items():
            out[(s, f)] = q
    return [{"q": out}]


# ========================================================================================== TrainBoulder
TB_N = 120
RB_HIT = {R: 45, L: 105}
RB_SPOT = {R: (0.3, 0.5), L: (-0.3, 0.55)}


def _rb_yaw(a, lead):
    """total body turn (+ = left: right shoulder forward). Long slow coil, a held peak, a 3-frame snap (the hips
    lead by `lead`), held on the rock, slow recoil."""
    return Curve([(0, -26 * a, "smooth"), (38 - lead, -42 * a, "smooth"), (42 - lead, -44 * a, "in"),
                  (45 - lead, 46 * a, "linear"), (48, 45 * a, "out"), (70, 26 * a, "smooth"),
                  (98 - lead, 42 * a, "smooth"), (102 - lead, 44 * a, "in"), (105 - lead, -46 * a, "linear"),
                  (108, -45 * a, "out"), (120, -26 * a, "smooth")])


RB_HIPS, RB_CHEST = _rb_yaw(0.45, 1), _rb_yaw(1.0, 0)
RB_ROOT = Curve([(0, -0.33, "smooth"), (38, -0.31, "smooth"), (42, -0.30, "in"), (45, -0.46, "linear"),
                 (48, -0.47, "out"), (70, -0.34, "smooth"), (98, -0.31, "smooth"), (102, -0.30, "in"),
                 (105, -0.46, "linear"), (108, -0.47, "out"), (120, -0.33, "smooth")])
RB_LEAN = Curve([(0, -6.0, "smooth"), (38, 5.0, "smooth"), (42, 6.0, "in"), (45, -20.0, "linear"),
                 (48, -20.0, "out"), (70, -7.0, "smooth"), (98, 5.0, "smooth"), (102, 6.0, "in"),
                 (105, -20.0, "linear"), (108, -20.0, "out"), (120, -6.0, "smooth")])
SHUDDER = {46: 1.4, 47: -1.2, 48: 0.8, 49: -0.4, 106: -1.4, 107: 1.2, 108: -0.8, 109: 0.4}


class _Shake:
    def __init__(self, base, table):
        self.base, self.t = base, table

    def __call__(self, f):
        return float(self.base(f)) + self.t.get(f, 0.0)


def rb_body(f):
    return post_body(f, RB_HIPS, _Shake(RB_CHEST, SHUDDER), RB_ROOT, RB_LEAN, "rboulder")


@functools.lru_cache(None)
def rb_tracks():
    body = lambda f: rb_body(f)[:3]
    (rx, rz), (lx, lz) = RB_SPOT[R], RB_SPOT[L]
    s_r, s_l = aim(rx + 0.1, rz - 0.12, 0.9), aim(lx - 0.1, lz - 0.12, 0.9)
    p_r, p_l = aim(rx + 0.1, rz - 0.06, 0.7), aim(lx - 0.1, lz - 0.06, 0.7)
    tr = ArmTrack(R, [(0, HIKITE[R], "smooth"), (42, HIKITE[R], "in"), (45, hit(rx, rz), "linear"),
                      (46, hit(rx, rz), "linear"), (47, hit(rx, rz), "linear"), (48, hit(rx, rz - 0.02), "out"),
                      (70, s_r, "smooth"), (98, p_r, "smooth"), (102, p_r, "in"), (105, HIKITE[R], "smooth"),
                      (120, HIKITE[R], "smooth")], body,
                  seeds={70: AIM_SEED[R], 98: AIM_SEED[R], 102: AIM_SEED[R]})
    tl = ArmTrack(L, [(0, s_l, "smooth"), (38, p_l, "smooth"), (42, p_l, "in"), (45, HIKITE[L], "smooth"),
                      (102, HIKITE[L], "in"), (105, hit(lx, lz), "linear"), (106, hit(lx, lz), "linear"),
                      (107, hit(lx, lz), "linear"), (108, hit(lx, lz - 0.02), "out"), (120, s_l, "smooth")], body,
                  seeds={0: AIM_SEED[L], 38: AIM_SEED[L], 42: AIM_SEED[L], 120: AIM_SEED[L]})
    return {R: tr, L: tl}


def train_boulder():
    tr = rb_tracks()
    notes = {0: "left palm out as the sight, right palm chambered at the hip", 10: "slow coil: hips turn away, weight back",
             38: "coiled, held (the needle sweeps)", 42: "snap", 45: "HIT right palm-heel, on the rock",
             46: "held on the rock, the body shudders", 48: "slow recoil", 70: "the right palm is the sight now",
             80: "slow coil for the left", 98: "coiled, held", 102: "snap", 105: "HIT left palm thrust, on the rock",
             106: "held on the rock, the body shudders", 108: "slow recoil"}
    frames = post_frames(TB_N, rb_body, tr, notes)
    M.INFO["TrainBoulder"] = _q(tr)
    return slerp_pass(clip(
        "TrainBoulder", 4.0, True, "Action",
        "Boulder breaking from a left front stance, seen in profile: a long slow coil (hips and shoulders turned away, "
        "weight back, the striking palm chambered at the hip, the other arm out as a sight), a 3-frame snap with the "
        "hips leading and the weight driven forward, the palm heel ON the rock for 3 frames while the body shudders, "
        "a slow recoil; right palm-heel, then left palm thrust.",
        "shotei-uchi on a boulder; Hit at frames 45 and 105 (2.000 s apart)",
        build(frames, True), markers=[("Hit", fr(45)), ("Hit", fr(105))], views=VIEW_ROCK,
        extra={"_contact": _rock_contact(), "_scene": _rock_scene()}))


# ======================================================================================== BoulderBarrage
BB_N = 30
BB_HITS = {R: (4, 19), L: (11, 26)}
BB_SPOT = {4: (0.4, 0.62), 11: (-0.42, 0.52), 19: (0.5, 0.42), 26: (-0.48, 0.7)}
BB_YAW, BB_LEAN, BB_ROOT = 28.0, -18.0, -0.5
BB_CURVE = Curve([(-4, -BB_YAW, "smooth"), (4, BB_YAW, "smooth"), (11, -BB_YAW, "smooth"), (19, BB_YAW, "smooth"),
                  (26, -BB_YAW, "smooth"), (34, BB_YAW, "smooth")])


def bb_body(f):
    f = f % BB_N if f != BB_N else 0
    cy = float(BB_CURVE(f))
    hy = float(BB_CURVE(min(f + 1, 33))) * 0.35          # the hips lead the chest by a frame
    root = np.array([0.0, 0.0, BB_ROOT + 0.025 * math.cos(2 * math.pi * f / 7.5)])
    tor = [-2.0, hy, 0.0]
    up = [BB_LEAN, cy - hy, M.ROLL_K * cy]
    head = head_level(tor, up, (-10.0, 0, 0), 0.85)
    legs = solve_feet({s: foot_at(*v) for s, v in P_FEET.items()}, root, tor, "barrage")
    return root, tor, up, head, legs


@functools.lru_cache(None)
def bb_tracks():
    body = lambda f: bb_body(f % BB_N)[:3]
    tracks = {}
    for s, hits in BB_HITS.items():
        seq = [hits[-1] - BB_N] + list(hits) + [hits[0] + BB_N]
        k = []
        for h0, h1 in zip(seq, seq[1:]):
            k += [(h0, hit(*BB_SPOT[h0 % BB_N], straight=-12.0, zlim=60.0), "out"),
                  (h0 + 4, M.FL_CHAMBER[s], "smooth"), (h1 - 3, M.FL_CHAMBER[s], "in")]
        k.append((seq[-1], hit(*BB_SPOT[seq[-1] % BB_N], straight=-12.0, zlim=60.0), "linear"))
        tracks[s] = ArmTrack(s, k, body)
    return tracks


def boulder_barrage():
    tr = bb_tracks()
    notes = {h: f"HIT {'right' if s == R else 'left'} palm" for s, hs in BB_HITS.items() for h in hs}
    for h in (5, 12, 20, 27):
        notes[h] = "barrage"
    notes[0] = "barrage"
    frames = post_frames(BB_N, bb_body, tr, notes)
    M.INFO["BoulderBarrage"] = _q(tr)
    return slerp_pass(clip(
        "BoulderBarrage", 1.0, True, "Action",
        "Awakening barrage: low, leaning 18 deg into the rock, heavy alternating palm strikes, the chest whipping "
        "28 deg side to side with each, head locked on the rock; each palm lands on the face at its own spot.",
        "furious alternating palm strikes, 4 per 1.0 s loop at frames 4, 11, 19, 26",
        build(frames, True), markers=[("Hit", fr(h)) for h in (4, 11, 19, 26)], views=VIEW_ROCK,
        extra={"_contact": _rock_contact(), "_scene": _rock_scene()}))


# ========================================================================================= BoulderFinish
BF_N = 39
BF_HIT = 18
BF_SPOT = {R: (0.5, 0.45), L: (-0.5, 0.45)}


@functools.lru_cache(None)
def bf_curves():
    r0, t0, u0, _, _ = bb_body(0)
    th, tc = float(RB_HIPS(0)), float(RB_CHEST(0))
    hips = Curve([(0, t0[1], "out"), (10, 0.0, "smooth"), (36, th, "smooth"), (39, th, "smooth")])
    chest = Curve([(0, u0[1] + t0[1], "out"), (10, 0.0, "smooth"), (24, 0.0, "smooth"), (36, tc, "smooth"),
                   (39, tc, "smooth")])
    rootc = Curve([(0, float(r0[2]), "out"), (12, -0.3, "smooth"), (15, -0.29, "in"), (18, -0.42, "out"),
                   (24, -0.43, "smooth"), (36, float(RB_ROOT(0)), "smooth"), (39, float(RB_ROOT(0)), "smooth")])
    lean = Curve([(0, u0[0], "out"), (12, 10.0, "smooth"), (15, 11.0, "in"), (18, -40.0, "out"), (24, -41.0, "smooth"),
                  (36, float(RB_LEAN(0)), "smooth"), (39, float(RB_LEAN(0)), "smooth")])
    return hips, chest, rootc, lean


def bf_body(f):
    hips, chest, rootc, lean = bf_curves()
    out = post_body(f, hips, chest, rootc, lean, "bfin")
    if f <= 10:   # frame 0 is the barrage's exact body; blend into this clip's by frame 10
        w = M.C.EASE["smooth"](f / 10.0)
        r0, t0, u0, _, _ = bb_body(0)
        root, tor, up, _, _ = out
        tor = [t0[i] * (1 - w) + tor[i] * w for i in range(3)]
        up = [u0[i] * (1 - w) + up[i] * w for i in range(3)]
        root = r0 * (1 - w) + root * w
        head = head_level(tor, up, (-10.0 * (1 - w), 0, 0), 0.85 * (1 - w) + 0.55 * w)
        legs = solve_feet({s: foot_at(*v) for s, v in P_FEET.items()}, root, tor, "bfin")
        out = (root, tor, up, head, legs)
    root, tor, up, head, legs = out
    head = [head[0] + 0.5 * min(0.0, up[0]), head[1], head[2]]    # the head tucks with the lunge (clears the arms)
    return root, tor, up, head, legs


def boulder_finish():
    bb0 = boulder_barrage()["keyframes"][0]["bones"]
    rb0 = train_boulder()["keyframes"][0]["bones"]
    bbt, rbt = bb_tracks(), rb_tracks()
    body = lambda f: bf_body(f)[:3]
    a0 = {s: {j: bbt[s](0)[j + s.lower()] for j in ("ua", "la", "ha")} for s in (R, L)}
    end = {s: {j: rbt[s](0)[j + s.lower()] for j in ("ua", "la", "ha")} for s in (R, L)}
    tracks = {}
    for s in (R, L):
        x, z = BF_SPOT[s]
        tracks[s] = ArmTrack(s, [(0, a0[s], "out"), (12, HIKITE[s], "smooth"), (15, HIKITE[s], "in"),
                                 (18, hit(x, z, straight=-6.0), "out"), (23, hit(x, z, 0.02, straight=-6.0), "smooth"),
                                 (28, {"ua": [-38.0, 0.0, 28.0 * M.SG[s]], "la": [-70.0, 0.0, 0.0], "ha": [0.0, 0.0, 0.0]},
                                  "smooth"),
                                 (36, end[s], "smooth"), (39, end[s], "smooth")], body)
    notes = {0: "from BoulderBarrage frame 0", 6: "both palms drawn back to the hips, weight back",
             12: "coiled", 15: "snap", 18: "HIT double palm thrust, both palms on the rock",
             19: "held follow-through", 24: "settle", 36: "= TrainBoulder frame 0"}
    frames = post_frames(BF_N, bf_body, tracks, notes)
    frames[0] = (frames[0][0], copy.deepcopy(bb0))
    for i in range(36, BF_N + 1):
        frames[i] = ("= TrainBoulder frame 0", copy.deepcopy(rb0))
    M.INFO["BoulderFinish"] = _q(tracks)
    return slerp_pass(clip(
        "BoulderFinish", 1.3, False, "Action",
        "The awakening's finisher: from the barrage, both palms drawn back to the hips with the weight back and the "
        "chest squared, then a double palm thrust lunging 40 deg into the rock, both palms ON its face 0.3 either side "
        "of the centre line at the Hit (the boulder shatters), held, settle into TrainBoulder's first frame.",
        "morote shotei (double palm-heel) into a boulder; Hit at frame 18 (0.6000 s)",
        build(frames, False), markers=[("Hit", fr(BF_HIT))], views=VIEW_ROCK,
        extra={"_contact": _rock_contact(), "_scene": _rock_scene()}))


# ============================================================================================ THUNDER PEAK
PK_FEET = {R: (0.8, 0.0, -12.0, 0.0), L: (-0.8, 0.0, 12.0, 0.0)}
PK_N = 60
SG = {R: 1.0, L: -1.0}


def _legs(root, tor, tag):
    return solve_feet({s: foot_at(*v) for s, v in PK_FEET.items()}, root, tor, tag)


def _ready_arms(u):
    out = {}
    for s in (R, L):
        g = SG[s]
        sf = s.lower()
        out["ua" + sf] = [-24.0 - 2.0 * math.sin(2 * math.pi * u), 0.0, g * (36.0 + 2.0 * math.sin(2 * math.pi * u))]
        out["la" + sf] = [-72.0, 0.0, 0.0]
        out["ha" + sf] = [-12.0, 0.0, g * 6.0]
    return out


def ready_pose(f):
    u = (f % PK_N) / PK_N
    b = math.sin(2 * math.pi * u)
    root = np.array([0.0, 0.0, -0.3 + 0.025 * b])
    tor = [-3.0, 0.0, 0.0]
    up = [-3.0 + 2.0 * b, 3.0 * math.sin(2 * math.pi * u + 0.6), 0.0]
    head = [6.0 - 1.0 * b, -up[1] + 14.0 * math.sin(2 * math.pi * u), 0.0]      # scans left and right
    return root, tor, up, head, _ready_arms(u)


def peak_ready():
    frames = []
    for f in range(PK_N + 1):
        root, tor, up, head, arms = ready_pose(f)
        frames.append(("alert: coiled, scanning", full_pose(root, tor, up, head, _legs(root, tor, "pready"), arms)))
    return slerp_pass(clip(
        "PeakReady", 2.0, True, "Action",
        "On the peak waiting for the lightning, facing the camera: feet apart, knees soft, arms half raised and ready at "
        "the sides, hands open, head scanning slowly left and right, a slow breathing bob. Alert and coiled.",
        "ready stance, 2.0 s loop", build(frames, True), markers=[], views=VIEW_PEAK))


# the catching arm (rig FK) per clip, and which side catches
CATCH = {
    # a diagonal raise (flexion + abduction): 48 deg up and out with the shoulder cap clear of the head (a pure
    # sideways raise past ~115 drives the R15 upper arm's cap into the head: 0.4 on the meshes)
    "PeakLeft": (R, {"ua": [-110.0, 60.0, 20.0], "la": [-6.0, 0.0, 0.0], "ha": [10.0, 0.0, 0.0]}),
    "PeakMid": (R, {"ua": [-170.0, 0.0, 15.0], "la": [-4.0, 0.0, 0.0], "ha": [6.0, 0.0, 0.0]}),    # up by flexion
    "PeakRight": (L, {"ua": [-110.0, -60.0, -20.0], "la": [-6.0, 0.0, 0.0], "ha": [10.0, 0.0, 0.0]}),
}
FIST = {"ua": [-42.0, 0.0, 18.0], "la": [-118.0, 0.0, 0.0], "ha": [-10.0, 0.0, 0.0]}     # the clenched fist at the chest
# body at the catch: lean toward the rod (up Z: + tilts the chest to the character's LEFT, measured on the head)
CATCH_BODY = {"PeakLeft": ([-2.0, -6.0, 0.0], [14.0, -12.0, -6.0]), "PeakMid": ([4.0, 0.0, 0.0], [24.0, 0.0, 0.0]),
              "PeakRight": ([-2.0, 6.0, 0.0], [14.0, 12.0, 6.0])}
PC_N = 24
TREMOR = [1.0, -1.0, 0.85, -0.9, 0.75, -0.7, 0.6, -0.55, 0.45, -0.4, 0.3]   # frames 5..15


def peak_catch(name):
    side, arm = CATCH[name]
    other = L if side == R else R
    up_c, head_c = CATCH_BODY[name]
    g = SG[other]
    fist = {"ua": [FIST["ua"][0], 0.0, g * FIST["ua"][2]], "la": FIST["la"], "ha": FIST["ha"]}
    r0, t0, u0, h0, a0 = ready_pose(0)
    so, ss = other.lower(), side.lower()
    ready_arm = {s: {j: a0[j + s.lower()] for j in ("ua", "la", "ha")} for s in (R, L)}
    tracks = {side: ArmTrack(side, [(0, ready_arm[side], "out"), (4, arm, "linear"), (15, arm, "smooth"),
                                    (24, ready_arm[side], "smooth")], None),
              other: ArmTrack(other, [(0, ready_arm[other], "out"), (4, fist, "linear"), (15, fist, "smooth"),
                                      (24, ready_arm[other], "smooth")], None)}
    upc = Curve([(0, u0, "out"), (4, up_c, "linear"), (15, up_c, "smooth"), (24, u0, "smooth")])
    hc = Curve([(0, h0, "out"), (4, head_c, "linear"), (15, head_c, "smooth"), (24, h0, "smooth")])
    rc = Curve([(0, float(r0[2]), "out"), (4, -0.38, "linear"), (15, -0.36, "smooth"), (24, float(r0[2]), "smooth")])
    frames = []
    for f in range(PC_N + 1):
        k = TREMOR[f - 5] if 5 <= f <= 15 else 0.0
        root = np.array([0.0, 0.0, float(rc(f)) + 0.012 * k])
        tor = list(t0)
        up = [float(v) for v in upc(f)]
        up = [up[0] + 1.5 * k, up[1] + 2.0 * k, up[2] - 3.0 * k]        # the shoulders shake with the current
        head = [float(v) for v in hc(f)]
        head = [head[0] - 1.5 * k, head[1] - 1.5 * k, head[2] + 2.0 * k]
        arms = {**tracks[side](f), **tracks[other](f)}
        arms["ua" + ss] = [arms["ua" + ss][0], arms["ua" + ss][1], arms["ua" + ss][2] + 3.0 * k * SG[side]]
        arms["ua" + so] = [arms["ua" + so][0] - 2.0 * k, arms["ua" + so][1], arms["ua" + so][2]]
        frames.append(("", full_pose(root, tor, up, head, _legs(root, tor, "pc" + name), arms)))
    notes = {0: "= PeakReady frame 0", 1: "reflex thrust", 4: "CATCH: the hand open toward the rod",
             5: "the bolt runs through the body: tremor, the other fist clenched", 15: "release",
             24: "= PeakReady frame 0"}
    last = ""
    for i, (n_, b) in enumerate(frames):
        last = notes.get(i, last)
        frames[i] = (last, b)
    rd0 = peak_ready()["keyframes"][0]["bones"]
    frames[0] = (frames[0][0], copy.deepcopy(rd0))
    frames[-1] = (frames[-1][0], copy.deepcopy(rd0))
    where = {"PeakLeft": "up and out to the hero's RIGHT (the camera's left) at 45 deg",
             "PeakMid": "straight up overhead, head tilted back",
             "PeakRight": "up and out to the hero's LEFT (the camera's right) at 45 deg"}[name]
    return slerp_pass(clip(
        name, 0.8, False, "Action",
        f"Lightning catch, facing the camera: from PeakReady a reflex thrust of the open {'right' if side == R else 'left'} "
        f"hand {where}, reached by frame 4 (Catch), held while the bolt runs through the body (shoulders shaking, "
        "the other fist clenched at the chest), back to PeakReady's first frame by 0.8 s.",
        "reflex lightning catch; Catch at frame 4 (0.1333 s)",
        build(frames, False), markers=[("Catch", fr(4))], views=VIEW_PEAK,
        extra={"_catch": {"hand": "RightHand" if side == R else "LeftHand"}}))


def peak_storm():
    frames = []
    for f in range(PK_N + 1):
        u = (f % PK_N) / PK_N
        # a fast small shake (integer harmonics: periodic over the loop) over a slow sway
        sh = 0.6 * math.sin(2 * math.pi * 13 * u) + 0.4 * math.sin(2 * math.pi * 19 * u + 1.0)
        sw = math.sin(2 * math.pi * u)
        root = np.array([0.0, 0.0, -0.42 + 0.015 * sh + 0.03 * math.sin(2 * math.pi * 2 * u)])
        tor = [-2.0, 0.0, 2.5 * sw]
        up = [10.0 + 1.2 * sh, 2.0 * sh, -2.0 * sw + 1.5 * sh]
        head = [18.0 - 1.5 * sh, -1.5 * sh, 2.0 * sw]
        arms = {}
        for s in (R, L):
            g = SG[s]
            sf = s.lower()
            arms["ua" + sf] = [-110.0 + 2.0 * sh, g * 60.0, g * (20.0 + 3.0 * sh * g + 3.0 * sw)]   # the V
            arms["la" + sf] = [-8.0 - 3.0 * sh, 0.0, 0.0]
            arms["ha" + sf] = [8.0, 0.0, 0.0]
        frames.append(("storm: arms in a V, the current shaking the body", full_pose(root, tor, up, head,
                                                                                  _legs(root, tor, "storm"), arms)))
    return slerp_pass(clip(
        "PeakStorm", 2.0, True, "Action",
        "Awakening on the peak: both arms thrust up and out in a V, hands open, chest out, head back, legs braced, the "
        "whole body trembling with the current (a fast small shake over a slow sway).",
        "lightning awakening, 2.0 s loop", build(frames, True), markers=[], views=VIEW_PEAK))


CLIPS = {"TrainBoulder": train_boulder, "BoulderBarrage": boulder_barrage, "BoulderFinish": boulder_finish,
         "PeakReady": peak_ready, "PeakLeft": lambda: peak_catch("PeakLeft"), "PeakMid": lambda: peak_catch("PeakMid"),
         "PeakRight": lambda: peak_catch("PeakRight"), "PeakStorm": peak_storm}


def catch_points():
    import fkcheck as C
    for name in ("PeakLeft", "PeakMid", "PeakRight"):
        spec = CLIPS[name]()
        side = CATCH[name][0]
        b, root = C.sample(spec, fr(4))
        o = F.fk(b, root)
        c = hand_centre(o, side)
        print(f"{name}: {'Right' if side == R else 'Left'}Hand centre at Catch (x right, y forward, z up) "
              f"({c[0]:+.3f}, {c[1]:+.3f}, {c[2]:+.3f})")


if __name__ == "__main__":
    import sys
    names = sys.argv[2:] if len(sys.argv) > 2 else list(CLIPS)
    if sys.argv[1] == "check":
        for nm in names:
            M.check(nm, CLIPS[nm]())
    elif sys.argv[1] == "catch":
        catch_points()
