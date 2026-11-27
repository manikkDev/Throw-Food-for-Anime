"""Batch r8 (2026-11-27, plan 13 phase D "training grounds"): five player clips, all Action, full body.

Ground 1, STRIKING POST (makiwara). Post front face = the plane y = POST_FACE (2.47 studs ahead of the
HumanoidRootPart, the TrainStrike convention), weak spot at chest height (z +0.5) on the centre line. Camera in
PROFILE. All three post clips share ONE pair of planted feet (left front stance), so cross-fades never slide a foot.
  TrainPost   2.000 s loop. Makiwara practice: RIGHT reverse punch (gyaku-zuki) lands at 0.5000, LEFT lead punch
              (kizami-zuki) lands at 1.5000. Each: the striking fist chambered at the hip (hikite), the other arm
              out as a sight; the hips coil away, then snap through (hips lead the shoulders by a frame), the
              striking fist drives straight to the post while the sight hand is pulled back to the hip; the fist is
              ON the post for 2 frames, recoils and becomes the next sight.
  PostFlurry  1.000 s loop, the awakening. Rapid alternating straight punches, low and leaning in, fists landing on
              a spread around the weak spot. 0.125 s does not land on 30 fps frames, so it is 6 punches 5 frames
              (0.1667 s) apart: Hit at frames 2, 7, 12, 17, 22, 27.
  PostFinish  1.200 s one-shot. From PostFlurry's first frame: big wind-up (weight back, right fist at the hip, left
              hand out as a sight), one right straight that drives 0.6 studs THROUGH the face (Hit 0.5000), held
              follow-through, settle into TrainPost's first frame exactly.

Ground 2, WATERFALL. Seated cross-legged (TrainMeditate's root drop -1.65, legs re-posed: knees up and out, shins
crossed one over the other, so they no longer sink into the floor), camera in FRONT.
  TrainBreath   3.000 s loop. Inhale 0..2.5 (spine lengthens, shoulders and chin rise, hands rise palms-up from the
                knees to chest height), Pulse at 2.5000, exhale 2.5..3.0 (hands turn over, press down to the knees).
  BreathAscend  2.000 s loop. Floats 1.6 studs above the seat (ROOT z only; the HRP does not move), still
                cross-legged, arms open wide and low palms up, head back a little, bob +-0.15, gentle sway.

Method (as clips_r7.py): EVERY frame is a key. Feet are solved onto their plants each frame (fkmodel.solve_leg),
hands are solved each frame (clips_r7.solve_h, warm-started: same branch frame to frame) from a hand path whose
key points live either in WORLD (contact on the post) or in the upper-torso frame (hikite, chamber: they ride with
the chest). The exported clip is plain FK.

  python tools/anim/clips_r8.py check [Name ...]   FK-model numbers: contact per Hit, part overlaps, floor, post
                                                   plane, foot slip, per-frame joint jumps (pops) and the loop seam.
"""
import copy
import functools
import math

import numpy as np

import fkcheck as C
import fkmodel as F
from animlib import clip
from clips_r3 import hand_centre, solve_feet, to_roblox
from clips_r4 import Curve
from clips_r7 import build, foot_at, full_pose, part_boxes, solve_h, torso_pt
from clips_train import fr, slerp_pass

R, L = "R", "L"
SG = {R: 1.0, L: -1.0}
HALF_T = 0.15                 # hand-part centre -> end face (the knuckle face of a block fist)
POST_D = 2.923                # plane the fists are SOLVED onto in the FK model (the tilted block fists read ~0.05 less on the meshes)
POST_FACE = 2.87              # where the post's face goes (second pass: moved back 0.4 for a long punch line)
WEAK = np.array([0.0, 0.5])   # weak spot (x, z), rig space, HRP-relative
VIEW_POST = {"side": [1.0, 0.0, 0.08], "front34": [0.7, 1.0, 0.3], "left": [-1.0, 0.0, 0.08]}
VIEW_FALL = {"front": [0.0, 1.0, 0.25], "side": [1.0, 0.0, 0.08], "front34": [0.7, 1.0, 0.3]}
INFO = {}


def unit(v):
    v = np.asarray(v, float)
    return v / np.linalg.norm(v)


def wave(u, k=1.0, ph=0.0):
    return math.sin(2 * math.pi * (k * u + ph))


def head_level(tor, up, extra=(0.0, 0.0, 0.0), turn=1.0):
    """Head that keeps looking down the facing (at the post / the camera): cancels the body's lean and roll and
    `turn` of its yaw (1 = locked on the target; less lets the chin stay behind the punching shoulder), + extra."""
    return [-(tor[0] + up[0]) + extra[0], -(tor[1] + up[1]) * turn + extra[1], -(tor[2] + up[2]) * 0.8 + extra[2]]


class Path:
    """Hand path. keys [(frame, point, ease)], point = (space, centre, tip): space "w" (rig/world) or "t" (rest
    upper-torso frame, carried by the posed chest); tip = the end-face normal. Both ends of a segment are
    evaluated with THIS frame's chest, then lerped (position) and nlerped (tip). Optional arc: (frame0, vector)."""

    def __init__(self, keys, arcs=None):
        self.k = keys
        self.arcs = arcs or {}

    @staticmethod
    def at(pt, tor, up, root):
        sp, c, tip = pt[:3]
        if sp in ("w", "h"):
            return np.asarray(c, float), unit(tip)
        o = F.fk({"tor": tor, "up": up}, root)
        return torso_pt(tor, up, root, c), unit(o["D_up"] @ np.asarray(tip, float))

    def __call__(self, f, tor, up, root):
        k = self.k
        for fk_, pt, _ in k:
            if fk_ == f and pt[0] == "h":
                c, tip = self.at(pt, tor, up, root)
                return c, tip, pt[3]
        if f <= k[0][0]:
            return self.at(k[0][1], tor, up, root) + (None,)
        for (f0, a, e), (f1, b, _) in zip(k, k[1:]):
            if f <= f1:
                u = C.EASE[e]((f - f0) / float(f1 - f0)) if e in C.EASE else EASE[e]((f - f0) / float(f1 - f0))
                ca, ta = self.at(a, tor, up, root)
                cb, tb = self.at(b, tor, up, root)
                c = ca + (cb - ca) * u
                if f0 in self.arcs:
                    c = c + np.asarray(self.arcs[f0], float) * math.sin(math.pi * u)
                return c, unit(ta + (tb - ta) * u), None
        return self.at(k[-1][1], tor, up, root) + (None,)


EASE = dict(C.EASE)
EASE["in3"] = lambda u: u ** 3
EASE["out3"] = lambda u: 1 - (1 - u) ** 3


def solve_arm8(side, centre, tor, up, root, tip=None, w_tip=3.0, fore=None, w_fore=2.0, w_wrist=0.02, guess=None,
               plane=None, avoid=6.0, la_pref=None, zlim=None):
    """FK {ua, la, ha} for one arm: hand-part CENTRE at `centre`; soft: end-face normal along `tip`, forearm along
    `fore`, a straight wrist (w_wrist per degree), no roll. plane=(D): instead of the centre's y, the hand box's
    FRONTMOST corner sits on y = D (what touches the post first); x and z still those of the face centre.
    Warm-started from `guess` (same branch frame to frame); a seed sweep only when there is no guess."""
    from scipy.optimize import least_squares
    sf = side.lower()
    centre = np.asarray(centre, float)

    def po(v):
        return {"tor": tor, "up": up, "ua" + sf: v[0:3], "la" + sf: [v[3], 0, 0], "ha" + sf: [v[4], 0, v[5]]}

    def res(v):
        o = F.fk(po(v), root)
        Dh = o["Dhand" + side]
        if plane is None:
            r = list((hand_centre(o, side) - centre) * 40.0)
        else:
            fc = o["fist" + side]
            r = [(fc[0] - centre[0]) * 40.0, (fc[2] - centre[2]) * 40.0, (F.front_y(o, side) - plane) * 300.0]
            # nothing of the arm but the fist's knuckles may reach the post: forearm corners stay 0.04 behind it
            nm = ("Right" if side == R else "Left") + "LowerArm"
            for bn, c, D, h in part_boxes(o):
                if bn == nm:
                    r.append(max(0.0, float(_corner_pts(c, D, h, 2)[:, 1].max()) - (plane - 0.04)) * 80.0)
        if tip is not None:
            r += list((Dh @ np.array([0, 0, -1.0]) - tip) * w_tip)
        if fore is not None:
            r += list((o["Dfore" + side] @ np.array([0, 0, -1.0]) - unit(fore)) * w_fore)
        if avoid:
            r += [x * avoid for x in F.arm_intrusion(o, side)]
        r += [v[1] * 0.01, v[4] * w_wrist, v[5] * w_wrist]
        if la_pref is not None:
            r.append((v[3] - la_pref) * 0.05)
        if guess is not None:          # stay near the seed: no drift into an equivalent, rolled Euler triple
            r += list((np.asarray(v[:4]) - np.asarray(guess[:4])) * 0.004)
        return r

    lo, hi = np.array(F.ARM_LO + [-70, -70]), np.array(F.ARM_HI + [70, 70])
    if zlim is not None:     # keep the upper arm unrolled (an equivalent rolled triple swings it into the head)
        lo[2], hi[2] = -zlim, zlim

    def run(x0):
        x0 = np.clip(np.asarray(x0, float), lo + 1e-6, hi - 1e-6)
        return least_squares(res, x0, bounds=(lo, hi), xtol=1e-9, ftol=1e-9)

    if guess is not None:
        best = run(guess)
    else:
        best = None
        sg = SG[side]
        for x0 in ([-60, 0, 0, -60, 0, 0], [-90, 0, 0, -10, 0, 0], [-30, 0, 0, -110, 0, 0], [-80, 0, 30 * sg, -40, 0, 0],
                   [30, 0, 0, -90, 0, 0], [-80, 0, -30 * sg, -40, 0, 0], [-120, 0, 0, -30, 0, 0], [0, 0, 20 * sg, -60, 0, 0]):
            sol = run(x0)
            if best is None or sol.cost < best.cost - 1e-9:
                best = sol
    v = best.x
    o = F.fk(po(v), root)
    e = float(np.linalg.norm(hand_centre(o, side) - centre)) if plane is None else abs(F.front_y(o, side) - plane)
    a = 0.0
    if tip is not None:
        a = math.degrees(math.acos(np.clip(o["Dhand" + side] @ np.array([0, 0, -1.0]) @ tip, -1, 1)))
    out = {"ua" + sf: [float(x) for x in v[0:3]], "la" + sf: [float(v[3]), 0.0, 0.0], "ha" + sf: [float(v[4]), 0.0, float(v[5])]}
    return out, list(map(float, v)), (e, a)


def arms_at(paths, f, tor, up, root, guess, tag, **kw):
    out, q = {}, {}
    for side, p in paths.items():
        c, tip, plane = p(f, tor, up, root)
        arm, guess[(tag, side)], q[side] = solve_arm8(side, c, tor, up, root, tip=tip, fore=tip, plane=plane,
                                                      guess=guess.get((tag, side)), **kw)
        out.update(arm)
    return out, q


def solve_hit(side, x, z, plane, tor, up, root, seed=None, straight=-8.0, zlim=50.0):
    """A punch landing the way a real one does: wrist straight, knuckles in line with the forearm, elbow as
    straight as the distance allows (`straight` deg preferred), the fist's frontmost knuckle corner ON `plane` and
    its end-face centre at (x, z). Seeded from a coarse grid over unrolled arms; the best of its 4 best seeds."""
    sf = side.lower()
    seeds = [seed] if seed is not None else []
    if seed is None:
        cand = []
        zr = int(zlim) if zlim else 70
        for ux in range(-130, -40, 4):
            for uz in range(-zr, zr + 1, 4):
                for la in (0, -10, -20, -32, -45, -60, -75):
                    o = F.fk({"tor": tor, "up": up, "ua" + sf: [ux, 0, uz], "la" + sf: [la, 0, 0]}, root)
                    if max(F.arm_intrusion(o, side)) > 0.02:
                        continue
                    fc = o["fist" + side]
                    e = abs(F.front_y(o, side) - plane) + abs(fc[0] - x) + abs(fc[2] - z) + abs(la - straight) * 0.002
                    cand.append((e, [ux, 0, uz, la, 0, 0]))
        cand.sort(key=lambda c: c[0])
        seeds = [c[1] for c in cand[:4]]
    best = None
    for sd in seeds:
        r = solve_arm8(side, (x, plane - HALF_T, z), tor, up, root, tip=None, w_wrist=0.4, plane=plane, guess=sd,
                       la_pref=straight, zlim=zlim)
        o = F.fk({"tor": tor, "up": up, **r[0]}, root)
        flat = float((o["Dhand" + side] @ np.array([0, 0, -1.0]))[1])
        score = r[2][0] * 10.0 + abs(r[1][3] - straight) * 0.004 + (1.0 - flat) * 1.0
        if best is None or score < best[0] - 1e-6:
            best = (score, r)
    return best[1]


def solve_aim(side, centre, tor, up, root, seed):
    """an arm reaching toward the post (a sight / a recoil): hand centre at `centre`, knuckles at the post"""
    return solve_arm8(side, centre, tor, up, root, tip=np.array([0, 1.0, 0]), w_tip=1.0, w_wrist=0.03, guess=seed)


class ArmTrack:
    """keys [(frame, spec, ease)]: spec = {"ua", "la", "ha"} FK angles, or ("hit", x, z, past) / ("aim", (x, y, z))
    solved with the body at that frame (`body(f)` -> root, tor, up). Between keys every joint is SLERPED (Roblox's
    own interpolation) with the segment's ease, so the arm moves as one piece and never changes branch."""

    def __init__(self, side, keys, body, seeds=None):
        from scipy.spatial.transform import Rotation as Rot
        self.side, sf = side, side.lower()
        self.keys, self.q = [], {}
        seeds = seeds or {}
        for f, spec, e in keys:
            if isinstance(spec, dict):
                ang = {k: np.asarray(v, float) for k, v in spec.items()}
            else:
                root, tor, up = body(f)
                if spec[0] == "hit":
                    arm, raw, q = solve_hit(side, spec[1], spec[2], POST_D + spec[3], tor, up, root, seed=seeds.get(f),
                                            straight=spec[4], zlim=spec[5])
                elif spec[0] == "hand":       # ("hand", Path point, w_tip): hand centre + palm direction
                    c, tip = Path.at(spec[1], tor, up, root)
                    arm, raw, q = solve_arm8(side, c, tor, up, root, tip=tip, w_tip=spec[2], w_wrist=0.02,
                                             guess=seeds.get(f))
                else:
                    arm, raw, q = solve_aim(side, spec[1], tor, up, root, seed=seeds.get(f))
                self.q[f] = q
                ang = {k[:2]: np.asarray(v, float) for k, v in arm.items()}
            self.keys.append((f, {j: Rot.from_euler("xyz", ang[j], degrees=True) for j in ("ua", "la", "ha")},
                              e, {j: ang[j] for j in ("ua", "la", "ha")}))

    def __call__(self, f):
        from scipy.spatial.transform import Slerp
        from scipy.spatial.transform import Rotation as Rot
        k = self.keys
        sf = self.side.lower()
        if f <= k[0][0]:
            return {j + sf: list(k[0][3][j]) for j in ("ua", "la", "ha")}
        for (f0, ra, e, aa), (f1, rb, _, ab) in zip(k, k[1:]):
            if f <= f1:
                u = EASE[e]((f - f0) / float(f1 - f0))
                out = {}
                for j in ("ua", "la", "ha"):
                    r = Slerp([0, 1], Rot.concatenate([ra[j], rb[j]]))([u])[0]
                    eul = r.as_euler("xyz", degrees=True)
                    ref = aa[j] + (ab[j] - aa[j]) * u
                    eul = np.array([ref[i] + ((eul[i] - ref[i] + 180) % 360 - 180) for i in range(3)])
                    out[j + sf] = [float(v) for v in eul]
                return out
        return {j + sf: list(k[-1][3][j]) for j in ("ua", "la", "ha")}

    def angles(self, f):
        return next(k[3] for k in self.keys if k[0] == f)


# =============================================================================================== POST
# Left front stance (zenkutsu-dachi): left foot forward, toes a touch in; right foot back, turned out. The left
# toes end ~1.2 short of the post's face. All three post clips stand on these plants.
P_FEET = {L: (-0.6, 0.72, 4.0, 0.0), R: (0.62, -0.78, -32.0, 0.0)}

# hikite: the fist pulled back to the ribs, elbow behind, knuckles forward-up (FK, relative to the chest)
HIKITE = {R: {"ua": [42.0, 0.0, 8.0], "la": [-110.0, 0.0, 0.0], "ha": [-5.0, 0.0, 0.0]},
          L: {"ua": [42.0, 0.0, -8.0], "la": [-110.0, 0.0, 0.0], "ha": [-5.0, 0.0, 0.0]}}
SIGHT_BACK = 0.8            # the sight / recoiled fist: knuckles this far off the post's face
AIM_SEED = {R: [-80.0, 0.0, -10.0, -35.0, 0.0, 0.0], L: [-80.0, 0.0, 10.0, -35.0, 0.0, 0.0]}


def hit(x, z, past=0.0, straight=-8.0, zlim=50.0):
    return ("hit", x, z, past, straight, zlim)


def aim(x, z, back):
    return ("aim", (x, POST_D - back - HALF_T, z))


def _post_contact():
    return {"contact_distance": POST_FACE, "solved_plane": POST_D, "plane": "y = contact_distance (rig +Y = facing)",
            "weak_spot_rig": [0.0, POST_FACE, 0.5],
            "what": "the striking fist's frontmost knuckle corner on the plane; its end face as flat as the arm allows"}


def _post_scene():
    # a makiwara: a post with a padded striking board, the board's face on the plane
    return [{"pos": [0, POST_FACE + 0.45, -0.9], "size": [0.7, 0.5, 4.2], "colour": [0.5, 0.33, 0.2]},
            {"pos": [0, POST_FACE + 0.1, 0.5], "size": [0.9, 0.2, 1.3], "colour": [0.78, 0.7, 0.52]}]


def post_body(f, hips, chest, root_c, lean, tag, heel=None, head_x=0.0, turn=0.55):
    """root, tor, up, head, legs at frame f from curves (yaw + = turned to the character's LEFT)."""
    root = np.array([0.0, 0.0, float(root_c(f))])
    hy, cy = float(hips(f)), float(chest(f))
    tor = [0.0, hy, 0.0]
    up = [float(lean(f)), cy - hy, ROLL_K * cy]        # the chest rolls a little with its turn (into the punch)
    head = head_level(tor, up, (head_x, 0.0, 0.0), turn)
    fs = {s: foot_at(x, y, yaw, heel[s](f) if heel and s in heel else h) for s, (x, y, yaw, h) in P_FEET.items()}
    legs = solve_feet(fs, root, tor, tag)
    return root, tor, up, head, legs


def post_frames(n, body_full, tracks, notes):
    frames, last = [], ""
    for f in range(n + 1):
        root, tor, up, head, legs = body_full(f)
        arms = {}
        for t in tracks.values():
            arms.update(t(f))
        last = notes.get(f, last)
        frames.append((last, full_pose(root, tor, up, head, legs, arms)))
    return frames


# ------------------------------------------------------------------------------------------- TrainPost
TP_N = 60
YAW_HIT, YAW_COIL, YAW_REC = 44.0, 34.0, 26.0     # total body turn at the hit, the coil, after the recoil
HIP_SHARE = 0.45
ROLL_K = 0.24               # chest roll per degree of chest turn: 8 deg at the hit keeps the upper arm off the jaw


def _tp_yaw(a, lead):
    """body yaw through TrainPost: + on the right punch, - on the left; the hips (lead 1) snap a frame early"""
    return Curve([(0, -YAW_REC * a, "smooth"), (10 - lead, -YAW_COIL * a, "smooth"),
                  (12 - lead, -(YAW_COIL + 3) * a, "in"), (15 - lead, YAW_HIT * a, "smooth"),
                  (17, (YAW_HIT - 1) * a, "out"), (23, YAW_REC * a, "smooth"),
                  (40 - lead, YAW_COIL * a, "smooth"), (42 - lead, (YAW_COIL + 3) * a, "in"),
                  (45 - lead, -YAW_HIT * a, "smooth"), (47, -(YAW_HIT - 1) * a, "out"), (53, -YAW_REC * a, "smooth"),
                  (60, -YAW_REC * a, "smooth")])


TP_HIPS, TP_CHEST = _tp_yaw(HIP_SHARE, 1), _tp_yaw(1.0, 0)
TP_ROOT = Curve([(0, -0.30, "smooth"), (10, -0.27, "smooth"), (12, -0.27, "in"), (15, -0.35, "smooth"),
                 (17, -0.35, "out"), (23, -0.31, "smooth"), (40, -0.27, "smooth"), (42, -0.27, "in"),
                 (45, -0.35, "smooth"), (47, -0.35, "out"), (53, -0.31, "smooth"), (60, -0.30, "smooth")])
TP_LEAN = Curve([(0, -6.0, "smooth"), (10, 2.0, "smooth"), (12, 3.0, "in"), (15, -18.0, "smooth"),
                 (17, -18.0, "out"), (23, -8.0, "smooth"), (40, 2.0, "smooth"), (42, 3.0, "in"),
                 (45, -18.0, "smooth"), (47, -18.0, "out"), (53, -8.0, "smooth"), (60, -6.0, "smooth")])
TP_SPOT = {R: (0.3, 0.5), L: (-0.3, 0.52)}


def tp_body(f):
    return post_body(f, TP_HIPS, TP_CHEST, TP_ROOT, TP_LEAN, "tpost")


@functools.lru_cache(None)
def tp_tracks():
    body = lambda f: tp_body(f)[:3]
    (rx, rz_), (lx, lz) = TP_SPOT[R], TP_SPOT[L]
    s_r, s_l = aim(rx + 0.1, rz_ - 0.12, SIGHT_BACK), aim(lx - 0.1, lz - 0.12, SIGHT_BACK)
    p_r, p_l = aim(rx + 0.1, rz_ - 0.06, SIGHT_BACK - 0.15), aim(lx - 0.1, lz - 0.06, SIGHT_BACK - 0.15)
    tr = ArmTrack(R, [(0, HIKITE[R], "smooth"), (12, HIKITE[R], "in"), (15, hit(rx, rz_), "linear"),
                      (16, hit(rx, rz_), "out"), (23, s_r, "smooth"), (40, p_r, "smooth"), (42, p_r, "in"),
                      (45, HIKITE[R], "smooth"), (60, HIKITE[R], "smooth")], body,
                  seeds={23: AIM_SEED[R], 40: AIM_SEED[R], 42: AIM_SEED[R]})
    tl = ArmTrack(L, [(0, s_l, "smooth"), (10, p_l, "smooth"), (12, p_l, "in"), (15, HIKITE[L], "smooth"),
                      (42, HIKITE[L], "in"), (45, hit(lx, lz), "linear"), (46, hit(lx, lz), "out"),
                      (53, s_l, "smooth"), (60, s_l, "smooth")], body,
                  seeds={0: AIM_SEED[L], 10: AIM_SEED[L], 12: AIM_SEED[L], 53: AIM_SEED[L], 60: AIM_SEED[L]})
    return {R: tr, L: tl}


def _q(tracks):
    out = {}
    for s, t in tracks.items():
        for f, q in t.q.items():
            out[(s, f)] = q
    return [{"q": out}]


def train_post():
    tr = tp_tracks()
    notes = {0: "right fist at the hip, left out as the sight", 10: "coil: hips turned away, weight back",
             12: "snap: the hips lead", 15: "HIT right reverse punch, on the post", 16: "held on the post",
             17: "recoil", 23: "the right fist is the sight now", 40: "coil for the left", 42: "snap",
             45: "HIT left lead punch, on the post", 46: "held on the post", 47: "recoil", 53: "the left fist is the sight"}
    frames = post_frames(TP_N, tp_body, tr, notes)
    INFO["TrainPost"] = _q(tr)
    return slerp_pass(clip(
        "TrainPost", 2.0, True, "Action",
        "Karate makiwara practice from a left front stance, seen in profile: the right fist chambered at the hip "
        "and the left arm out as a sight; the hips coil away, then snap through a frame ahead of the shoulders and "
        "the right reverse punch drives straight onto the post (2 frames held) while the left fist is pulled back "
        "to the hip; it recoils and becomes the sight; then the same for a left lead punch.",
        "makiwara training: gyaku-zuki and kizami-zuki with hikite; Hit at frames 15 and 45 (1.000 s apart)",
        build(frames, True), markers=[("Hit", fr(15)), ("Hit", fr(45))], views=VIEW_POST,
        extra={"_contact": _post_contact(), "_scene": _post_scene()}))


# ------------------------------------------------------------------------------------------ PostFlurry
FL_N = 30
FL_HITS = {R: (2, 12, 22), L: (7, 17, 27)}
FL_SPOT = {2: (0.4, 0.74), 7: (-0.42, 0.6), 12: (0.5, 0.56), 17: (-0.5, 0.8), 22: (0.32, 0.66), 27: (-0.34, 0.52)}
# between punches the fist is pulled back in front of its own shoulder, low, elbow down (FK on the chest)
FL_CHAMBER = {R: {"ua": [-30.0, 0.0, 22.0], "la": [-105.0, 0.0, 0.0], "ha": [5.0, 0.0, 0.0]},
              L: {"ua": [-30.0, 0.0, -22.0], "la": [-105.0, 0.0, 0.0], "ha": [5.0, 0.0, 0.0]}}
FL_YAW = 22.0
FL_ROOT = -0.5
FL_LEAN = -18.0
FL_TURN = 0.85              # the head stays on the post (85% of the chest's turn cancelled)


def fl_curve(f, amp, lag=0.0):
    """+ peaks ON each right Hit, - on each left Hit (period 10 frames); `lag` frames early (the hips lead)"""
    return amp * math.cos(2 * math.pi * (f + lag - 2) / 10.0)


def fl_body(f):
    root = np.array([0.0, 0.0, FL_ROOT + 0.02 * math.cos(2 * math.pi * (f - 2) / 5.0)])
    tor = [-2.0, fl_curve(f, FL_YAW * 0.35, 0.7), 0.0]
    cy = fl_curve(f, FL_YAW)
    up = [FL_LEAN - 1.2 * math.cos(2 * math.pi * (f - 2) / 5.0), cy - tor[1], ROLL_K * cy]
    head = head_level(tor, up, (-10.0, 0, 0), FL_TURN)
    legs = solve_feet({s: foot_at(*v) for s, v in P_FEET.items()}, root, tor, "flurry")
    return root, tor, up, head, legs


@functools.lru_cache(None)
def fl_tracks():
    body = lambda f: fl_body(f % FL_N)[:3]     # the body is periodic: keys outside 0..30 use the same phase
    tracks = {}
    for s, hits in FL_HITS.items():
        k = []
        seq = [hits[-1] - FL_N] + list(hits) + [hits[0] + FL_N]
        for h0, h1 in zip(seq, seq[1:]):
            k += [(h0, hit(*FL_SPOT[h0 % FL_N], straight=-12.0, zlim=60.0), "out"), (h0 + 3, FL_CHAMBER[s], "smooth"), (h1 - 3, FL_CHAMBER[s], "in")]
        k.append((seq[-1], hit(*FL_SPOT[seq[-1] % FL_N], straight=-12.0, zlim=60.0), "linear"))
        tracks[s] = ArmTrack(s, k, body)
    return tracks


def post_flurry():
    tr = fl_tracks()
    notes = {h: f"HIT {'right' if s == R else 'left'}" for s, hs in FL_HITS.items() for h in hs}
    notes.update({0: "flurry", 3: "flurry", 8: "flurry", 13: "flurry", 18: "flurry", 23: "flurry", 28: "flurry"})
    frames = post_frames(FL_N, fl_body, tr, notes)
    INFO["PostFlurry"] = _q(tr)
    return slerp_pass(clip(
        "PostFlurry", 1.0, True, "Action",
        "Awakening flurry: low and leaning into the post, knees bent, rapid alternating straight punches, the "
        "chest counter-rotating with every punch, head locked on the post; each fist lands on the face at a "
        "different spot around the weak spot.",
        "anime rapid-fire punch flurry (6 per 1.0 s loop at 30 fps), Hit at frames 2, 7, 12, 17, 22, 27",
        build(frames, True), markers=[("Hit", fr(h)) for h in (2, 7, 12, 17, 22, 27)], views=VIEW_POST,
        extra={"_contact": _post_contact(), "_scene": _post_scene()}))


# ------------------------------------------------------------------------------------------ PostFinish
PF_N = 36
PF_HIT = 15
PF_THROUGH = 0.6


def pf_curves():
    y0h, y0c = fl_curve(0, FL_YAW * 0.35, 0.7), fl_curve(0, FL_YAW)
    tph, tpc = float(TP_HIPS(0)), float(TP_CHEST(0))
    hips = Curve([(0, y0h, "out"), (9, -26.0, "smooth"), (12, -28.0, "in"), (14, 30.0, "out"), (20, 31.0, "smooth"),
                  (33, tph, "smooth"), (36, tph, "smooth")])
    chest = Curve([(0, y0c, "out"), (10, -52.0, "smooth"), (12, -55.0, "in"), (15, 58.0, "out"), (21, 60.0, "smooth"),
                   (33, tpc, "smooth"), (36, tpc, "smooth")])
    rootc = Curve([(0, float(fl_body(0)[0][2]), "out"), (10, -0.36, "smooth"), (12, -0.36, "in"), (15, -0.56, "out"),
                   (21, -0.58, "smooth"), (33, float(TP_ROOT(0)), "smooth"), (36, float(TP_ROOT(0)), "smooth")])
    lean = Curve([(0, float(fl_body(0)[2][0]), "out"), (10, 8.0, "smooth"), (12, 9.0, "in"), (15, -26.0, "out"),
                  (21, -27.0, "smooth"), (33, float(TP_LEAN(0)), "smooth"), (36, float(TP_LEAN(0)), "smooth")])
    heel = {R: Curve([(0, 0.0, "smooth"), (12, 0.0, "in"), (15, 34.0, "out"), (21, 36.0, "smooth"), (31, 0.0, "smooth"),
                      (36, 0.0, "smooth")])}
    return hips, chest, rootc, lean, heel


PF_CURVES = None


def pf_body(f):
    global PF_CURVES
    PF_CURVES = PF_CURVES or pf_curves()
    hips, chest, rootc, lean, heel = PF_CURVES
    root, tor, up, head, legs = post_body(f, hips, chest, rootc, lean, "pfin", heel=heel)
    if f <= 10:   # frame 0 is PostFlurry's exact body (its own lean/roll split): blend into this clip's by 10
        w = C.EASE["smooth"](f / 10.0)
        r0, t0, u0, _, _ = fl_body(0)
        tor = [t0[i] * (1 - w) + tor[i] * w for i in range(3)]
        up = [u0[i] * (1 - w) + up[i] * w for i in range(3)]
        root = r0 * (1 - w) + root * w
        head = head_level(tor, up, (-4.0 * (1 - w), 0, 0), FL_TURN * (1 - w) + 0.55 * w)
        legs = solve_feet({s: foot_at(*v) for s, v in P_FEET.items()}, root, tor, "pfin")
    return root, tor, up, head, legs


def post_finish():
    fl0 = post_flurry()["keyframes"][0]["bones"]
    tp0 = train_post()["keyframes"][0]["bones"]
    flt, tpt = fl_tracks(), tp_tracks()
    body = lambda f: pf_body(f)[:3]
    a0 = {s: {j: flt[s](0)[j + s.lower()] for j in ("ua", "la", "ha")} for s in (R, L)}
    end = {s: {j: tpt[s](0)[j + s.lower()] for j in ("ua", "la", "ha")} for s in (R, L)}
    sight = aim(-0.2, 0.42, 1.0)
    tr = ArmTrack(R, [(0, a0[R], "out"), (10, HIKITE[R], "smooth"), (12, HIKITE[R], "in"),
                      (15, hit(0.06, 0.5, PF_THROUGH), "out"), (21, hit(0.06, 0.47, PF_THROUGH + 0.05), "smooth"),
                      (33, end[R], "smooth"), (36, end[R], "smooth")], body)
    tl = ArmTrack(L, [(0, a0[L], "out"), (9, sight, "smooth"), (12, sight, "in"), (15, HIKITE[L], "out"),
                      (21, HIKITE[L], "smooth"), (33, end[L], "smooth"), (36, end[L], "smooth")], body,
                  seeds={9: AIM_SEED[L], 12: AIM_SEED[L]})
    notes = {0: "from PostFlurry frame 0", 10: "WIND-UP: weight back, right fist at the hip, left hand out as the sight",
             12: "coiled", 13: "snap", 15: "HIT: the right straight drives 0.6 through the face, rear heel up",
             16: "follow-through", 21: "held", 22: "settle", 33: "= TrainPost frame 0"}
    frames = post_frames(PF_N, pf_body, {R: tr, L: tl}, notes)
    frames[0] = (frames[0][0], copy.deepcopy(fl0))
    for i in range(33, PF_N + 1):
        frames[i] = ("= TrainPost frame 0", copy.deepcopy(tp0))
    INFO["PostFinish"] = _q({R: tr, L: tl})
    return slerp_pass(clip(
        "PostFinish", 1.2, False, "Action",
        "The awakening's finisher: from the flurry, a big wind-up (weight back, right fist chambered at the hip, "
        "left hand out as a sight), then one full-body right straight that drives 0.6 studs THROUGH the post's "
        "face (the post bursts on the Hit), rear heel up, held, then settle into TrainPost's first frame.",
        "karate/anime finishing straight punch through a target; Hit at frame 15 (0.5000 s)",
        build(frames, False), markers=[("Hit", fr(PF_HIT))], views=VIEW_POST,
        extra={"_contact": {**_post_contact(), "through": PF_THROUGH}, "_scene": _post_scene()}))


# ============================================================================================ WATERFALL
SEAT = -1.65                       # TrainMeditate's root drop: the game's seat height
# TrainMeditate's own fold (the seat the game already shows): thighs out and forward, shins crossed in front
from animlib import euler as _euler
MED_LEGS = {R: {"ul": _euler(("y", 80), ("x", -80), ("y", 56)), "ll": [145, 0, 0], "f": [-30, 0, 0]},
            L: {"ul": _euler(("y", -80), ("x", -80), ("y", -56)), "ll": [145, 0, 0], "f": [-30, 0, 0]}}
SEAT_KNEE = {R: np.array([1.18, 0.44, -2.79]), L: np.array([-1.18, 0.44, -2.79])}   # FK, at the seat


def seat_legs(root_z):
    """the legs keep TrainMeditate's fold; a raised root carries it up whole"""
    return {s: {k: list(v) for k, v in MED_LEGS[s].items()} for s in (R, L)}


TB_N = 90
TB_PULSE = 75
# hands: palms (end faces) up resting on the knees; gathered palms-up at chest height (rest upper-torso frame)
TB_KNEE = {s: ("w", tuple(SEAT_KNEE[s] + [SG[s] * 0.1, 0.3, 0.72]), (0, 0.35, 1.0)) for s in (R, L)}
TB_CHEST = {R: ("t", (0.72, 1.25, 0.05), (-0.25, 0.25, 1.0)), L: ("t", (-0.72, 1.25, 0.05), (0.25, 0.25, 1.0))}
TB_TURN = {R: ("t", (0.75, 1.35, -0.1), (0, 0.6, -0.8)), L: ("t", (-0.75, 1.35, -0.1), (0, 0.6, -0.8))}
TB_PRESS = {s: ("w", tuple(SEAT_KNEE[s] + [SG[s] * 0.05, 0.45, 0.95]), (0, 0.2, -1.0)) for s in (R, L)}

TB_RISE = Curve([(0, 0.0, "smooth"), (75, 1.0, "out"), (82, 0.25, "smooth"), (90, 0.0, "smooth")])


TB_LIFT = {R: ("t", (0.95, 1.35, -0.55), (-0.1, 0.3, 1.0)), L: ("t", (-0.95, 1.35, -0.55), (0.1, 0.3, 1.0))}


# key poses of the breath, right arm (the left mirrors: Z negated). FK on the chest.
TB_POSE = {   # from r8_breath_grid.py: elbows on the rib line, forearms in toward the centre line, fingertips facing
    "rest": {"ua": [-20.0, -45.0, 30.0], "la": [-90.0, 0.0, 0.0], "ha": [-20.0, 0.0, 0.0]},     # cupped in the lap
    "lift": {"ua": [-30.0, -45.0, 40.0], "la": [-90.0, 0.0, 0.0], "ha": [-30.0, 0.0, 0.0]},     # rising before the belly
    "gather": {"ua": [-60.0, -30.0, 40.0], "la": [-60.0, 0.0, 0.0], "ha": [-35.0, 0.0, 0.0]},   # chest height, palms up
    "turn": {"ua": [-60.0, -30.0, 40.0], "la": [-60.0, 0.0, 0.0], "ha": [40.0, 0.0, 0.0]},      # turned over
    "press": {"ua": [-50.0, -45.0, 40.0], "la": [-60.0, 0.0, 0.0], "ha": [35.0, 0.0, 0.0]}}     # pressing down


def _mir(p, s):
    return {k: [v[0], v[1] * SG[s], v[2] * SG[s]] for k, v in p.items()}


@functools.lru_cache(None)
def tb_tracks():
    body = lambda f: breath_body(f)[:3]
    out = {}
    for s in (R, L):
        P = {k: _mir(v, s) for k, v in TB_POSE.items()}
        out[s] = ArmTrack(s, [(0, P["rest"], "smooth"), (12, P["rest"], "smooth"), (42, P["lift"], "smooth"),
                              (70, P["gather"], "smooth"), (75, P["gather"], "in"), (79, P["turn"], "out"),
                              (86, P["press"], "smooth"), (90, P["rest"], "smooth")], body)
    return out


def breath_body(f):
    b = float(TB_RISE(f))                                # 0 = exhaled, 1 = full inhale
    root = np.array([0.0, 0.0, SEAT + 0.02 * b])
    tor = [-4.0 + 3.0 * b, 0.0, 0.0]
    up = [-6.0 + 9.0 * b, 0.0, 0.0]                      # the spine lengthens: the chest lifts and opens
    head = [-(tor[0] + up[0]) - 4.0 + 10.0 * b, 0.0, 0.0]   # chin lifts slightly on the inhale
    return root, tor, up, head


def train_breath():
    tr = tb_tracks()
    notes = {0: "exhaled: palms up on the knees", 12: "INHALE begins: hands lift off the knees",
             40: "rising in front of the belly", 70: "gathered: palms up at chest height, chest up, chin up",
             75: "PULSE (full breath)", 79: "hands turn over", 86: "EXHALE: palms press down to the knees",
             90: "settled (loop)"}
    frames, last = [], ""
    for f in range(TB_N + 1):
        root, tor, up, head = breath_body(f)
        arms = {**tr[R](f), **tr[L](f)}
        last = notes.get(f, last)
        frames.append((last, full_pose(root, tor, up, head, seat_legs(float(root[2])), arms)))
    INFO["TrainBreath"] = _q(tr)
    return slerp_pass(clip(
        "TrainBreath", 3.0, True, "Action",
        "Seated cross-legged under the falls, facing the camera: one slow breath. Inhale for 2.5 s: the spine "
        "lengthens, chest and shoulders rise, chin lifts, both hands rise palms-up from the knees to chest height "
        "gathering energy; Pulse at the top; exhale in 0.5 s: hands turn over and press down to the knees.",
        "qigong 'gathering and pressing' breath, seated; Pulse at frame 75 (2.5000 s)",
        build(frames, True), markers=[("Pulse", fr(TB_PULSE))], views=VIEW_FALL))


BA_N = 60
LIFT = 1.6


def breath_ascend():
    frames, guess, info = [], {}, []
    for _pass in range(2):
        frames, info = [], []
        for f in range(BA_N + 1):
            u = f / BA_N
            root = np.array([0.0, 0.0, SEAT + LIFT + 0.15 * wave(u)])
            sway = 2.5 * wave(u, 1, 0.2)
            tor = [-2.0 + 1.5 * wave(u, 1, 0.12), 0.0, sway]
            up = [4.0 + 2.0 * wave(u, 1, 0.08), 2.0 * wave(u, 1, 0.45), -sway * 0.6]
            head = [-(tor[0] + up[0]) + 14.0 + 2.0 * wave(u, 1, 0.02), -up[1] * 0.6, -(tor[2] + up[2]) * 0.4]
            legs = seat_legs(float(root[2]))
            arms = {}
            for s in (R, L):           # open wide and low, palms (end faces) turned up, a slow drift
                g = SG[s]
                arms["ua" + s.lower()] = [-14.0 + 3.0 * wave(u, 1, 0.3), 0.0, g * (52.0 + 4.0 * wave(u, 1, 0.25))]
                arms["la" + s.lower()] = [-28.0 - 4.0 * wave(u, 1, 0.35), 0.0, 0.0]
                arms["ha" + s.lower()] = [-55.0, 0.0, 0.0]
            frames.append(("floating", full_pose(root, tor, up, head, legs, arms)))
            info.append({"q": {s: (0, 0) for s in (R, L)}})
    INFO["BreathAscend"] = info
    return slerp_pass(clip(
        "BreathAscend", 2.0, True, "Action",
        f"Awakening: risen {LIFT} studs off the seat (ROOT z only), still cross-legged, arms open wide and low, "
        "palms up, head tilted back a little, a slow bob of +-0.15 and a gentle sway.",
        "levitating meditation, 2.0 s loop",
        build(frames, True), markers=[], views=VIEW_FALL))


CLIPS = {"TrainPost": train_post, "PostFlurry": post_flurry, "PostFinish": post_finish,
         "TrainBreath": train_breath, "BreathAscend": breath_ascend}


# =============================================================================================== CHECKS
ADJ = {("Head", "UpperTorso"), ("UpperTorso", "LowerTorso"), ("UpperTorso", "RightUpperArm"),
       ("UpperTorso", "LeftUpperArm"), ("RightUpperArm", "RightLowerArm"), ("RightLowerArm", "RightHand"),
       ("LeftUpperArm", "LeftLowerArm"), ("LeftLowerArm", "LeftHand"), ("LowerTorso", "RightUpperLeg"),
       ("LowerTorso", "LeftUpperLeg"), ("RightUpperLeg", "RightLowerLeg"), ("RightLowerLeg", "RightFoot"),
       ("LeftUpperLeg", "LeftLowerLeg"), ("LeftLowerLeg", "LeftFoot")}


def _corner_pts(c, D, h, n=3):
    g = np.linspace(-1, 1, n)
    return np.array([c + D @ (np.array([i, j, k]) * h) for i in g for j in g for k in g])


def overlaps(o):
    """deepest point of any non-adjacent part's box inside another's (FK model boxes)"""
    bx = part_boxes(o)
    pts = {b[0]: _corner_pts(b[1], b[2], b[3]) for b in bx}
    out = {}
    for a in bx:
        for b in bx:
            if a[0] >= b[0] or (a[0], b[0]) in ADJ or (b[0], a[0]) in ADJ:
                continue
            d = 0.0
            for P, (_, c, D, h) in ((pts[a[0]], b), (pts[b[0]], a)):
                q = h - np.abs((P - c) @ D)
                inside = np.all(q > 0, axis=1)
                if inside.any():
                    d = max(d, float(q[inside].min(axis=1).max()))
            if d > 0.02:
                out[(a[0], b[0])] = d
    return out


def joint_jump(spec):
    """largest frame-to-frame rotation of any joint (deg), including the loop seam"""
    from scipy.spatial.transform import Rotation as Rot
    keys = spec["keyframes"]
    worst = (0.0, None, None)
    pairs = list(zip(keys, keys[1:]))
    seam = 0.0
    for a, b in pairs:
        for n, v in a["bones"].items():
            if n == "ROOT":
                continue
            ra = Rot.from_euler("xyz", v["rot"], degrees=True)
            rb = Rot.from_euler("xyz", b["bones"][n]["rot"], degrees=True)
            d = float(np.degrees((ra.inv() * rb).magnitude()))
            if d > worst[0]:
                worst = (d, n, round(a["t"] * 30))
    if spec["loop"]:
        a, b = keys[-2], keys[0]   # the frame before the seam -> frame 0 of the next loop
        for n, v in a["bones"].items():
            if n != "ROOT":
                ra = Rot.from_euler("xyz", v["rot"], degrees=True)
                rb = Rot.from_euler("xyz", b["bones"][n]["rot"], degrees=True)
                seam = max(seam, float(np.degrees((ra.inv() * rb).magnitude())))
    return worst, seam


def check(name, spec=None):
    spec = spec or CLIPS[name]()
    fps = spec["fps"]
    n = int(round(spec["duration"] * fps)) + 1
    worst_ov = {}
    low, plane = (9, None), (-9, None)
    for f in range(n):
        b, root = C.sample(spec, f / fps)
        o = F.fk(b, root)
        for k, d in overlaps(o).items():
            if d > worst_ov.get(k, (0, 0))[0]:
                worst_ov[k] = (d, f)
        for nm, c, D, h in part_boxes(o):
            P = _corner_pts(c, D, h, 2)
            z = float(P[:, 2].min()) - F.FLOOR
            if z < low[0]:
                low = (z, (f, nm))
            if "Hand" not in nm:
                y = float(P[:, 1].max())
                if y > plane[0]:
                    plane = (y, (f, nm))
    print(f"=== {name}: {n} frames ({spec['duration']} s, loop {spec['loop']})")
    for line in C.check(name, quiet=True)[1:4] if False else []:
        print(line)
    print(f"  lowest part corner vs floor {low[0]:+.3f} at {low[1]}")
    if "_contact" in spec:
        print(f"  frontmost non-hand corner y {plane[0]:.3f} at {plane[1]} (post face at FK {POST_D})")
    for m in spec.get("markers", []):
        f = int(round(m["time"] * fps))
        b, root = C.sample(spec, m["time"])
        o = F.fk(b, root)
        cells = []
        for s in (R, L):
            fc = o["fist" + s]
            ny = (o["Dhand" + s] @ np.array([0, 0, -1.0]))[1]
            cells.append(f"{s} face ({fc[0]:+.3f},{fc[1]:.3f},{fc[2]:+.3f}) n.y {ny:.3f} front {F.front_y(o, s):.3f}")
        print(f"  {m['name']} t={m['time']:.4f} (frame {f}): " + " | ".join(cells))
    q = INFO.get(name, [])
    if q and any(r["q"] for r in q):
        e = max(max(v[0] for v in r["q"].values()) for r in q if r["q"])
        a = max(max(v[1] for v in r["q"].values()) for r in q if r["q"])
        print(f"  hand solve (solved keys): worst miss {e:.4f}, worst face/tip tilt {a:.2f} deg")
    (jj, jn, jf), seam = joint_jump(spec)
    print(f"  biggest frame-to-frame joint turn {jj:.1f} deg ({jn} at frame {jf}); loop seam {seam:.1f} deg")
    for k, (d, f) in sorted(worst_ov.items(), key=lambda kv: -kv[1][0])[:8]:
        print(f"  overlap {k[0]} / {k[1]}: {d:.3f} at f{f}")
    return spec


if __name__ == "__main__":
    import sys
    names = sys.argv[2:] if len(sys.argv) > 2 else list(CLIPS)
    if sys.argv[1] == "check":
        for nm in names:
            check(nm)
