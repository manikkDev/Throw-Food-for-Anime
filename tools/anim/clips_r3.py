"""Batch r3 (2026-11-15): catch-reveal and rebirth clips.

  HeroWalkIn     hero, 1.2 s loop: weighty hero-entrance stride, root motion handled by the game
  HeroArrive     hero, 0.9 s: last step into a stomp and a power stance (blends into IdlePower)
  CarryHold      player, 1.2 s loop, UPPER BODY ONLY: a caught hero held up overhead in both hands
  PlaceHero      player, 1.2 s: lower the hero forward onto a pedestal, release, fist pump
  RebirthEvolve  player, 3.0 s: gather and tremble, explode up with arms spread, hold the pose

Same method as clips_train.py: every planted foot and every hand that must be at a known place is
SOLVED with fkmodel.py (pure-Python FK of the rig, checked against Blender to 0.01 stud) and written into
the spec as plain FK rotations. The walk is solved per frame: each foot follows a ground track whose
heel / toe contact point moves backward at exactly the root speed, so moving the HumanoidRootPart at
WALK_SPEED studs/s gives zero foot slide.
"""
import math

import numpy as np

import fkmodel as F
from animlib import SHORT, clip, pose
from clips_train import fr, held, lock_feet, planted, slerp_pass

R, L = "R", "L"

# ------------------------------------------------------------------------------------------- walk
WALK_N = 34             # frames per cycle (even: both contacts on the 30 fps grid)
WALK_T = round(WALK_N / 30.0, 4)  # 1.1333 s, two steps
STANCE = 0.62           # fraction of the cycle each foot is on the ground
P0 = 0.74               # flat-foot-equivalent ankle position (studs ahead of the root) at heel strike
WALK_STRIDE = 2 * P0 / STANCE          # root travel per cycle = 3.1667 studs
WALK_SPEED = WALK_STRIDE / WALK_T      # 2.639 studs/s
FOOT_X = 0.55
HEEL_STRIKE = -10.0     # toe up at contact (deg, solve_leg heel < 0)
TOE_OFF = 32.0          # heel up at toe-off
R_CONTACT = fr(8)       # right heel strike at frame 8, left at frame 25 (never on the loop seam)
CLEAR = 0.12            # sole clearance at mid-swing (studs)


def _mj(u):
    """minimum-jerk 0..1"""
    u = min(1.0, max(0.0, u))
    return u * u * u * (10 - 15 * u + 6 * u * u)


def _smooth(u):
    u = min(1.0, max(0.0, u))
    return u * u * (3 - 2 * u)


def contact_ankle(p, h):
    """Ankle (y, z) for a foot whose flat-equivalent position is p with pitch h (deg; <0 toe up on the
    heel, >0 heel up on the toe). The heel (h<0) or toe (h>0) edge stays where it would be if the foot
    were flat, so the contact point travels exactly with p: no slide while the foot rolls."""
    a = math.radians(abs(h))
    z = F.FLOOR + 0.5 * math.sin(a) + 0.252 * math.cos(a)
    if h < 0:
        return (p - 0.5) + 0.5 * math.cos(a) - 0.252 * math.sin(a), z
    if h > 0:
        return (p + 0.5) - 0.5 * math.cos(a) + 0.252 * math.sin(a), z
    return p, z


def stance_pitch(ph):
    """foot pitch over the stance (ph 0..STANCE): heel strike, roll to flat, flat, heel rises."""
    if ph < 0.08:
        return HEEL_STRIKE * (1 - _smooth(ph / 0.08))
    if ph < 0.42:
        return 0.0
    return TOE_OFF * (_smooth((ph - 0.42) / (STANCE - 0.42)) ** 1.3)


def foot_track(ph, x):
    """(ankle xyz, pitch, planted?) of a foot at cycle phase ph (0 = heel strike)."""
    ph %= 1.0
    if ph <= STANCE:
        p = P0 - WALK_STRIDE * ph
        h = stance_pitch(ph)
        y, z = contact_ankle(p, h)
        return np.array([x, y, z]), h, True
    u = (ph - STANCE) / (1 - STANCE)
    y0, z0 = contact_ankle(P0 - WALK_STRIDE * STANCE, TOE_OFF)
    y1, z1 = contact_ankle(P0, HEEL_STRIKE)
    # Hermite in y with the end slopes of a planted foot (world speed 0 at toe-off and at heel strike):
    # the foot leaves and meets the ground moving backward at the root speed, so it never skids
    m = -WALK_SPEED * (1 - STANCE) * WALK_T
    h00, h10, h01, h11 = 2 * u**3 - 3 * u**2 + 1, u**3 - 2 * u**2 + u, -2 * u**3 + 3 * u**2, u**3 - u**2
    y = h00 * y0 + h10 * m + h01 * y1 + h11 * m
    # toes come up early in the swing, reach heel-strike pitch before contact; the ankle height is set
    # from the SOLE: lowest foot edge CLEAR studs off the floor at mid-swing, exactly on it at both ends
    h = TOE_OFF + (HEEL_STRIKE - TOE_OFF) * _smooth(u / 0.75)
    a = math.radians(abs(h))
    z = F.FLOOR + 0.5 * math.sin(a) + 0.252 * math.cos(a) + CLEAR * math.sin(math.pi * u) ** 0.8
    del z0, z1
    return np.array([x, y, z]), h, False


_GUESS = {}


def solve_feet(feet, root, tor, tag):
    out = {}
    for side, (ank, h, yaw) in feet.items():
        lg, err, raw = F.solve_leg(side, ank, root, tor, yaw=yaw, heel=h, guess=_GUESS.get((tag, side)))
        if err > 0.01:
            raise ValueError(f"{tag} {side}: ankle misses by {err:.3f} (root {root}, ankle {ank})")
        _GUESS[(tag, side)] = raw
        out[side] = lg
    return out


def walk_upper(t):
    """Upper body of the walk at time t (s): pelvis turn, counter-turning shoulders, arm swing."""
    w = 2 * math.pi * (t - R_CONTACT) / WALK_T
    tor = [-2.0, 6.0 * math.cos(w), 0.0]                     # right hip leads at R contact
    sh = -7.0 * math.cos(w - 0.25)                           # shoulders counter-turn (net, world)
    up = [-1.0, sh - tor[1], 2.5 * math.sin(w)]              # chest carried a touch forward, shoulders roll
    head = [5.0, -sh * 0.8, -up[2] * 0.6]                    # eyes stay on the path
    fr_ = -math.cos(w - 0.3)                                  # right arm forward amount (back at R contact)
    fl_ = -fr_
    arm = {}
    for s, f, sg in ((R, fr_, 1), (L, fl_, -1)):
        sf = s.lower()
        arm["ua" + sf] = [-6.0 - 30.0 * f, 0.0, sg * 9.0]
        arm["la" + sf] = [-20.0 - 22.0 * max(0.0, f), 0.0, 0.0]
        arm["ha" + sf] = [-12.0, 0.0, 0.0]
    return tor, up, head, arm


def walk_root(t):
    # lowest just after each contact (weight accepted), highest at mid-stance
    return -0.05 - 0.04 * math.cos(4 * math.pi * (t - R_CONTACT - 0.06) / WALK_T)


def walk_frame(t):
    tor, up, head, arm = walk_upper(t)
    root = walk_root(t)
    ph_r = (t - R_CONTACT) / WALK_T
    feet = {}
    for side, ph, x, yaw in ((R, ph_r, FOOT_X, -5.0), (L, ph_r + 0.5, -FOOT_X, 5.0)):
        ank, h, _ = foot_track(ph, x)
        feet[side] = (ank, h, yaw)
    b = pose(legs=solve_feet(feet, root, tor, "walk"), tor=tor, up=up, head=head, **arm)
    b["ROOT"] = {"loc": F.root_loc(root)}
    return b


def hero_walk_in():
    keys = []
    for f in range(WALK_N):
        t = fr(f)
        note = ("RIGHT heel strike" if f == 8 else "LEFT heel strike" if f == 25 else "stride")
        keys.append((t, "linear", note, walk_frame(t)))
    keys.append((WALK_T, "linear", "loop", keys[0][3]))
    return slerp_pass(clip(
        "HeroWalkIn", WALK_T, True, "Movement",
        "Confident, weighty hero entrance stride: chest up, slight forward lean from the hips, shoulders "
        "counter-turning and rolling a little, arms swinging with intent (fists loosely closed, elbow bends "
        "on the forward swing), heel strike and toe-off on every step, only the natural stride bob.",
        "human walk cycle (heel strike, loading, mid-stance, heel rise, toe-off, swing); 2 steps per "
        f"{WALK_T} s, root travel {WALK_STRIDE:.4f} studs per cycle ({WALK_SPEED:.4f} studs/s)",
        keys, markers=[("Step", fr(8)), ("Step", fr(25))],
        views={"side": [1.0, 0.08, 0.1], "front34": [0.7, 1.0, 0.3]},
        extra={"_walk": {"stride_per_cycle": round(WALK_STRIDE, 4), "speed_studs_per_s": round(WALK_SPEED, 4),
                         "right_contact": fr(8), "left_contact": fr(25),
                         "how": "move the HumanoidRootPart forward at speed_studs_per_s while this loops"}}))


# ---------------------------------------------------------------------------------------- arrive
ARRIVE_TRAVEL = round(P0 - 0.10, 4)          # root travel during HeroArrive: the right foot ends 0.1 ahead
ARRIVE_STOP = round(2 * ARRIVE_TRAVEL / WALK_SPEED, 4)  # Quad Out over this long: starts at WALK_SPEED, ends at 0
STOMP_F = 12


def arrive_d(t):
    u = min(1.0, t / ARRIVE_STOP)
    return ARRIVE_TRAVEL * (1 - (1 - u) ** 2)


def hero_arrive():
    """Starts on the walk's RIGHT heel strike (walk t = 0.3): right foot planted ahead, left foot
    behind with its heel rising. The body coasts forward over the right foot (the game moves the root
    ARRIVE_TRAVEL studs, Quad Out, over ARRIVE_STOP s), the left knee lifts and the foot STOMPS down flat
    beside it at frame 12, the body absorbs, then rises chest-out into a fists-clenched power stance."""
    end_y = P0 - ARRIVE_TRAVEL                 # where the right foot ends, root-relative (0.10)
    LX_END = -0.78
    stomp_t = fr(STOMP_F)
    toe_off_t = (STANCE - 0.5) * WALK_T        # left toe-off 0.12 s in (walk phase 0.6)

    def right_foot(t):
        ph = min(t / WALK_T, STANCE * 0.5)     # heel rolls to flat exactly as in the walk, then stays flat
        p = P0 - arrive_d(t)
        h = stance_pitch(ph)
        y, z = contact_ankle(p, h)
        return np.array([FOOT_X, y, z]), h, -5.0

    def left_foot(t):
        if t <= toe_off_t:
            ph = 0.5 + t / WALK_T
            p = (P0 - WALK_STRIDE * 0.5) - arrive_d(t)            # world-planted while the root coasts
            h = stance_pitch(ph)
            y, z = contact_ankle(p, h)
            return np.array([-FOOT_X, y, z]), h, 5.0
        # swing: high knee, slam down flat at the stomp
        y0, z0 = contact_ankle((P0 - WALK_STRIDE * 0.5) - arrive_d(toe_off_t), TOE_OFF)
        if t >= stomp_t:
            y, z = contact_ankle(end_y + ARRIVE_TRAVEL - arrive_d(t), 0.0)
            return np.array([LX_END, y, z]), 0.0, 9.0
        u = (t - toe_off_t) / (stomp_t - toe_off_t)
        ys = end_y + ARRIVE_TRAVEL - arrive_d(stomp_t)
        z1 = F.FLOOR + 0.252
        y = y0 + (ys - y0) * _smooth(min(1.0, u / 0.8))
        x = -FOOT_X + (LX_END + FOOT_X) * _smooth(u)
        # knee comes up (peak ~0.62 at u 0.6) then the foot is driven down: accelerating into contact
        lift = 0.62 * (math.sin(math.pi * min(1.0, u / 1.0)) ** 0.8) if u < 0.6 else 0.62 * (1 - ((u - 0.6) / 0.4) ** 2)
        z = z0 + (z1 - z0) * _smooth(u) + lift
        h = TOE_OFF * (1 - _smooth(u / 0.5)) + 6.0 * _smooth(u / 0.5) * (1 - _smooth((u - 0.7) / 0.3))
        return np.array([x, y, z]), h, 9.0 * _smooth(u)

    tor_w, up_w, head_w, arm_w = walk_upper(R_CONTACT)
    root_w = walk_root(R_CONTACT)
    # upper-body beats (t, root, tor, up, head, arms)
    fist = {"har": [-22, 0, 0], "hal": [-22, 0, 0]}
    beats = [
        (0.0, root_w, tor_w, up_w, head_w, arm_w),
        (fr(8), -0.06, [-3, 3, 0], [2, -6, 0], [0, 4, 0],
         {"uar": [-18, 0, 22], "lar": [-70, 0, 0], "ual": [-18, 0, -22], "lal": [-70, 0, 0], **fist}),
        (fr(STOMP_F), -0.26, [-6, 0, 0], [6, 0, 0], [-4, 0, 0],
         {"uar": [8, 0, 24], "lar": [-26, 0, 0], "ual": [8, 0, -24], "lal": [-26, 0, 0], **fist}),
        (fr(15), -0.40, [-8, 0, 0], [8, 0, 0], [-6, 0, 0],
         {"uar": [12, 0, 22], "lar": [-34, 0, 0], "ual": [12, 0, -22], "lal": [-34, 0, 0], **fist}),
        (fr(21), -0.18, [-2, 0, 0], [6, 0, 0], [3, 0, 0],
         {"uar": [-4, 0, 15], "lar": [-34, 0, 0], "ual": [-4, 0, -15], "lal": [-34, 0, 0], **fist}),
        (fr(27), -0.15, [0, 0, 0], [3, 0, 0], [2, 0, 0],
         {"uar": [-6, 0, 13], "lar": [-32, 0, 0], "ual": [-6, 0, -13], "lal": [-32, 0, 0],
          "har": [-20, 0, 0], "hal": [-20, 0, 0]}),
    ]
    eases = ["smooth", "in", "out", "smooth", "smooth"]

    def beat_at(t):
        for i, (a, b) in enumerate(zip(beats, beats[1:])):
            if a[0] - 1e-9 <= t <= b[0] + 1e-9:
                from fkcheck import EASE
                u = EASE[eases[i]]((t - a[0]) / (b[0] - a[0]))
                lerp = lambda va, vb: [x + (y - x) * u for x, y in zip(va, vb)]
                arms = {k: lerp(a[5].get(k, [0, 0, 0]), b[5].get(k, [0, 0, 0])) for k in set(a[5]) | set(b[5])}
                return a[1] + (b[1] - a[1]) * u, lerp(a[2], b[2]), lerp(a[3], b[3]), lerp(a[4], b[4]), arms
        raise ValueError(t)

    keys = []
    n = int(round(0.9 * 30))
    for f in range(n + 1):
        t = fr(f)
        if f == 0:
            keys.append((0.0, "linear", f"walk pose at the RIGHT heel strike (HeroWalkIn t={R_CONTACT})", walk_frame(R_CONTACT)))
            continue
        root, tor, up, head, arms = beat_at(t)
        feet = {R: right_foot(t), L: left_foot(t)}
        b = pose(legs=solve_feet(feet, root, tor, "arrive"), tor=tor, up=up, head=head, **arms)
        b["ROOT"] = {"loc": F.root_loc(root)}
        note = "PLANT: left foot stomps down flat" if f == STOMP_F else ("power stance" if f == n else "arrive")
        keys.append((t, "linear", note, b))
    return slerp_pass(clip(
        "HeroArrive", 0.9, False, "Action",
        "From the stride into a power stance: the body coasts forward over the planted right foot, the left "
        "knee lifts and the foot stomps down flat beside it (dust), the body absorbs with the chest out and "
        "fists clenched, then rises into a wide fists-at-the-sides stance that blends into an idle.",
        "walk-to-stop with a stomp plant; ends near IdlePower's first pose",
        keys, markers=[("Plant", fr(STOMP_F))],
        views={"side": [1.0, 0.08, 0.1], "front34": [0.7, 1.0, 0.3]},
        extra={"_arrive": {"start_from": f"HeroWalkIn at its RIGHT Step (TimePosition {R_CONTACT})",
                           "root_travel": ARRIVE_TRAVEL, "root_travel_time": ARRIVE_STOP,
                           "root_easing": "Quad Out (initial speed = HeroWalkIn speed)"}}))


# ------------------------------------------------------------------------------ toe-pivot plants
def plant_ankle(pl):
    """plant (x, y_flat, yaw, heel) -> ankle (x, y) for solve_leg: with the heel up the foot pivots on its
    TOE edge (and toe-up on its heel edge), so the contact edge stays where the flat foot had it."""
    x, y, yaw, heel = pl
    return (x, contact_ankle(y, heel)[0])


def feet_p(spec, root, tor, tag):
    return solve_feet({s: (plant_ankle(v), v[3], v[2]) for s, v in spec.items()}, root, tor, tag)


def planted_p(legs_spec, root, tor, tag, **kw):
    b = pose(legs=feet_p(legs_spec, root, tor, tag), tor=tor, **kw)
    b["ROOT"] = {"loc": F.root_loc(root)}
    b["__feet"] = {s: list(v) for s, v in legs_spec.items()}
    return b


def lock_feet_p(spec, tol=0.02, pivot=True):
    """clips_train.lock_feet with toe-pivot plants: every segment where a foot keeps its plant (it may
    change yaw / heel) is baked per frame with that leg re-solved, heel and yaw eased like the segment."""
    import fkcheck as C
    keys = spec["keyframes"]
    plants = [k["bones"].pop("__feet", None) for k in keys]
    fps = spec["fps"]
    out = []
    for i, (a, b) in enumerate(zip(keys, keys[1:])):
        out.append(a)
        pa, pb = plants[i] or {}, plants[i + 1] or {}
        sides = [s for s in pa if s in pb and np.allclose(pa[s][:2], pb[s][:2], atol=0.011)]
        f0, f1 = int(round(a["t"] * fps)), int(round(b["t"] * fps))
        if not sides or f1 - f0 < 2:
            continue
        ease = C.EASE[a.get("ease", "smooth")]

        def plant_at(s, f):
            u = ease((f - f0) / float(f1 - f0))
            return [pa[s][0], pa[s][1], pa[s][2] + (pb[s][2] - pa[s][2]) * u, pa[s][3] + (pb[s][3] - pa[s][3]) * u]
        worst = 0.0
        for f in range(f0 + 1, f1):
            bb, root = C.sample({"keyframes": keys}, f / fps)
            o = F.fk(bb, root)
            for s in sides:
                pl = plant_at(s, f)
                ax, ay = plant_ankle(pl)
                want = np.array([ax, ay, contact_ankle(pl[1], pl[3])[1]])
                worst = max(worst, float(np.linalg.norm(o["ankle" + s] - want)))
        if worst <= tol:
            continue
        a["ease"] = "linear"
        for f in range(f0 + 1, f1):
            t = f / fps
            bb, root = C.sample({"keyframes": keys}, t)
            legs = feet_p({s: plant_at(s, f) for s in sides}, root, bb["tor"], "lockp")
            bones = {SHORT[k]: {"rot": [round(float(x), 2) for x in v]} for k, v in bb.items()}
            for s, lg in legs.items():
                sf = s.lower()
                bones[SHORT["ul" + sf]]["rot"] = lg["ul"]
                bones[SHORT["ll" + sf]]["rot"] = lg["ll"]
                bones[SHORT["f" + sf]]["rot"] = lg["f"]
            bones["ROOT"] = {"loc": F.root_loc(root)}
            out.append({"t": round(t, 4), "ease": "linear", "_note": f"foot lock ({worst:.2f} drift)", "bones": bones})
    out.append(keys[-1])
    spec["keyframes"] = out
    return spec


# ----------------------------------------------------------------------------------- hand solving
HAND_C = np.array([0, 0, -0.125])      # wrist -> centre of the hand part (rig space at rest)


def hand_centre(o, side):
    return o["wrist" + side] + o["Dhand" + side] @ HAND_C


def solve_hand(side, centre, tor, up, root, fore_dir=None, palm_in=True, guess=None, w_dir=2.0, avoid=6.0, tip=None):
    """FK {ua, la, ha} putting the CENTRE of the hand part at `centre` (rig space), the forearm along
    fore_dir and (palm_in) the hand's inner face pointing at the character's midline, level: two hands
    solved this way face each other, so a carried object can be welded between them."""
    from scipy.optimize import least_squares
    sf = side.lower()
    sg = 1 if side == R else -1

    def pose_of(v):
        return {"tor": tor, "up": up, "ua" + sf: v[0:3], "la" + sf: [v[3], 0, 0], "ha" + sf: [v[4], 0, v[5]]}

    def res(v):
        o = F.fk(pose_of(v), root)
        r = list((hand_centre(o, side) - np.asarray(centre)) * 40.0)
        if fore_dir is not None:
            d = o["Dfore" + side] @ np.array([0, 0, -1.0])
            r += list((d - np.asarray(fore_dir) / np.linalg.norm(fore_dir)) * w_dir)
        if palm_in:
            inner = o["Dhand" + side] @ np.array([-sg, 0, 0])      # the face toward the body at rest
            r += list((inner - np.array([-sg, 0, 0])) * 3.0)
        if tip is not None:   # the hand's end-face normal (what a welded object follows) held on `tip`
            r += list((o["Dhand" + side] @ np.array([0, 0, -1.0]) - np.asarray(tip)) * 6.0)
        if avoid:
            r += [x * avoid for x in F.arm_intrusion(o, side)]
        r += [v[1] * 0.01, v[4] * 0.02, v[5] * 0.02]
        return r

    lo, hi = F.ARM_LO + [-60, -60], F.ARM_HI + [60, 60]
    seeds = ([guess] if guess is not None else []) + [[-150, 0, 0, -20, 0, 0], [-90, 0, 0, -40, 0, 0],
                                                       [-170, 0, -20, -10, 0, 0], [-60, 0, 0, -70, 0, 0]]
    best = None
    for x0 in seeds:
        x0 = np.clip(np.asarray(x0, float), np.array(lo) + 1e-6, np.array(hi) - 1e-6)
        sol = least_squares(res, x0, bounds=(lo, hi), xtol=1e-10, ftol=1e-10)
        if best is None or sol.cost < best.cost - 1e-9:
            best = sol
    v = best.x
    o = F.fk(pose_of(v), root)
    err = float(np.linalg.norm(hand_centre(o, side) - np.asarray(centre)))
    if err > 0.02:
        raise ValueError(f"hand {side} misses {centre} by {err:.3f}")
    return {"ua" + sf: [round(float(a), 2) for a in v[0:3]], "la" + sf: [round(float(v[3]), 2), 0, 0],
            "ha" + sf: [round(float(v[4]), 2), 0, round(float(v[5]), 2)]}, [float(a) for a in v]


def both_hands(c_r, tor, up, root, fore_r, guess, tip=None):
    """hands mirrored across the midline: c_r = right hand centre, fore_r = right forearm direction."""
    c_l = [-c_r[0], c_r[1], c_r[2]]
    fore_l = [-fore_r[0], fore_r[1], fore_r[2]]
    kr, gr = solve_hand(R, c_r, tor, up, root, fore_r, guess=guess.get(R), tip=tip)
    kl, gl = solve_hand(L, c_l, tor, up, root, fore_l, guess=guess.get(L), tip=tip)
    guess[R], guess[L] = gr, gl
    return {**kr, **kl}


def to_roblox(v):
    """rig (right, forward, up) -> Roblox HumanoidRootPart object space (X right, Y up, Z back)."""
    return [round(float(v[0]), 3) + 0.0, round(float(v[2]), 3) + 0.0, round(-float(v[1]), 3) + 0.0]


# ------------------------------------------------------------------------------------------ carry
# Hero held UP like a trophy (the Simba lift): upright, the player's hands gripping its waist from the
# sides, palms facing each other, arms up and a little forward so the hero's dangling legs clear the
# player's face. A 0.55-scale R15 hero: LowerTorso 1.1 wide, its centre ~1.2 above its feet.
CARRY_C = [1.05, 0.42, 2.35]        # right hand centre (rig space); left is mirrored
CARRY_FORE = [-0.03, 0.2, 0.98]
GRIP_BELOW_LT = 0.95                # the hands grip the hero's ankles: its LowerTorso centre is this far above them
UPPER_ONLY = {"UpTorso", "HEAD", "FK_UpperArm.R", "FK_LowerArm.R", "FK_Hand.R",
              "FK_UpperArm.L", "FK_LowerArm.L", "FK_Hand.L"}
UPPER_JOINTS = ["UpperTorso", "Head", "RightUpperArm", "RightLowerArm", "RightHand",
                "LeftUpperArm", "LeftLowerArm", "LeftHand"]


def upper(b):
    return {k: v for k, v in b.items() if k in UPPER_ONLY}


def carry_pose(dz, up, head, guess, dy=0.0):
    c = [CARRY_C[0], CARRY_C[1] + dy, CARRY_C[2] + dz]
    arms = both_hands(c, [0, 0, 0], up, 0.0, CARRY_FORE, guess, tip=[0, 0, 1.0])   # hands level: the hero stays upright
    return pose(up=up, head=head, **arms)


HERO_S = 0.55
# 0.55-scale R15 hero as boxes, relative to ITS LowerTorso centre (rig axes); arms left off (its own pose)
HERO_PARTS = [((2, 1, 0.4), (0, 0, 0)), ((2, 1, 1.6), (0, 0, 1.0)), ((1.2, 1.2, 1.2), (0, 0, 2.3)),
              ((1, 1, 2), (0.5, 0, -1.2)), ((1, 1, 2), (-0.5, 0, -1.2))]
HERO_FEET = 2.2 * HERO_S            # LowerTorso centre -> soles
ORANGE = [0.9, 0.5, 0.15]


def hero_world(centre):
    return [{"pos": [float(centre[i] + HERO_S * off[i]) for i in range(3)],
             "size": [HERO_S * x for x in size], "colour": ORANGE} for size, off in HERO_PARTS]


def _short(bones):
    from fkcheck import LONG
    return {LONG[k]: v["rot"] for k, v in bones.items() if k in LONG}


def hero_on_hand(bones, side=R):
    """Hero proxy boxes bone-parented to a hand so they appear upright between the hands at the given
    pose: each box's rest placement is its posed world placement carried back through the hand's turn."""
    from scipy.spatial.transform import Rotation as Rot
    o, o0 = F.fk(_short(bones), 0.0), F.fk({}, 0.0)
    centre = (hand_centre(o, R) + hand_centre(o, L)) / 2 + np.array([0, 0, GRIP_BELOW_LT])
    Dh = o["Dhand" + side]
    rot = [round(float(a), 3) for a in Rot.from_matrix(Dh.T).as_euler("xyz", degrees=True)]
    out = []
    for it in hero_world(centre):
        rest = o0["wrist" + side] + Dh.T @ (np.asarray(it["pos"]) - o["wrist" + side])
        out.append({**it, "bone": "RightHand" if side == R else "LeftHand",
                    "pos": [round(float(x), 4) for x in rest], "rot": rot})
    return out, centre


def carry_hold():
    g = {}
    k0 = carry_pose(0.0, [5, 0, 0], [10, 0, 0], g)
    keys = [
        (0.0, "smooth", "held high, chest leaning back a touch under the weight", upper(k0)),
        (fr(9), "smooth", "the weight settles: elbows give, chest sinks",
         upper(carry_pose(-0.1, [3, 0, -2], [8, 0, 2], g, 0.03))),
        (fr(18), "smooth", "pressed back up", upper(carry_pose(0.0, [5, 0, 0], [10, 0, 0], g))),
        (fr(27), "smooth", "settles again, other side", upper(carry_pose(-0.1, [3, 0, 2], [8, 0, -2], g, 0.03))),
        (fr(36), "smooth", "loop", upper(k0)),
    ]
    attach, centre = hero_on_hand(k0)
    return clip("CarryHold", fr(36), True, "Action",
                "A caught hero held up overhead like a trophy: both arms up and slightly forward, hands gripping "
                "the hero's ankles from the sides (palms facing), chest leaning back a little under the weight, "
                "head up to look at it; a small settle twice a loop. Upper body only: the default walk keeps the legs.",
                "overhead trophy lift of a small figure held upright by the ankles (a trophy by its base)",
                keys, views={"front34": [0.7, 1.0, 0.3], "side": [1.0, 0.08, 0.1]},
                extra={"pose_only": UPPER_JOINTS, "_attach": attach,
                       "_carry": {"hero_lowertorso_centre_rig": [round(float(x), 3) for x in centre]}})


# ------------------------------------------------------------------------------------------ place
PLACE_F = 16
PEDESTAL_TOP = F.FLOOR + 1.0        # the game's pedestal tops are 1 stud above the ground
PLACE_C = [1.05, 1.85, PEDESTAL_TOP + HERO_FEET - GRIP_BELOW_LT]   # right hand centre at the touch-down
FEET0 = {R: (0.55, 0.0, -4, 0), L: (-0.55, 0.0, 4, 0)}


def place_hero():
    g, gc = {}, {}
    k0u = carry_pose(0.0, [5, 0, 0], [10, 0, 0], gc)

    def P(root, tor, up, head, arms):
        return planted(FEET0, root, tor, "place", up=up, head=head, **arms)

    def arms_at(c, fore, tor, up, root):
        return both_hands(c, tor, up, root, fore, g)

    a0 = _short(upper(k0u))
    up0, head0 = a0.pop("up"), a0.pop("head")
    k0 = P(-0.02, [0, 0, 0], up0, head0, a0)
    T1, U1 = [-4, 0, 0], [-6, 0, 0]
    k1 = P(-0.25, T1, U1, [6, 0, 0], arms_at([1.05, 1.45, 1.1], [0, 0.6, 0.8], T1, U1, -0.25))
    T2, U2 = [-18, 0, 0], [-30, 0, 0]
    k2 = P(-1.0, T2, U2, [30, 0, 0], arms_at(PLACE_C, [0, 0.7, -0.7], T2, U2, -1.0))
    U3 = [-29, 0, 0]
    k3 = P(-1.02, T2, U3, [28, 0, 0], arms_at(PLACE_C, [0, 0.7, -0.7], T2, U3, -1.02))
    T4, U4 = [-6, 0, 0], [-12, 0, 0]
    k4 = P(-0.45, T4, U4, [10, 0, 0], arms_at([1.5, 1.3, -0.6], [0.3, 0.7, -0.5], T4, U4, -0.45))
    k5 = P(-0.06, [0, 6, 0], [4, 8, -4], [-6, -10, 0],
           {"uar": [8, 0, 160], "lar": [-14, 0, 0], "har": [-25, 0, 0],
            "ual": [12, 0, -22], "lal": [-40, 0, 0], "hal": [-20, 0, 0]})
    k6 = P(-0.22, [-3, 10, 0], [-8, 12, 0], [8, -8, 0],
           {"uar": [26, 0, 18], "lar": [-118, 0, 0], "har": [-25, 0, 0],
            "ual": [16, 0, -16], "lal": [-90, 0, 0], "hal": [-20, 0, 0]})
    k7 = P(-0.06, [0, 4, 0], [-2, 4, 0], [3, -4, 0],
           {"uar": [10, 0, 12], "lar": [-80, 0, 0], "har": [-20, 0, 0],
            "ual": [2, 0, -10], "lal": [-40, 0, 0], "hal": [-10, 0, 0]})
    keys = [
        (0.0, "smooth", "carry pose (CarryHold frame 0), standing", k0),
        (fr(7), "smooth", "hero comes forward and down past the face", k1),
        (fr(PLACE_F), "out", "PLACE: hero's feet touch the pedestal", k2),
        (fr(19), "smooth", "hold the touch", k3),
        (fr(23), "in", "release: hands open out and back", k4),
        (fr(28), "out", "fist punched to the sky", k5),
        (fr(32), "smooth", "YES: fist yanked down, knees dip", k6),
        (fr(36), "smooth", "settle", k7),
    ]
    o = F.fk(_short(k2), F.root_vec(-1.0))
    cz = (hand_centre(o, R) + hand_centre(o, L)) / 2 + np.array([0, 0, GRIP_BELOW_LT])
    top = float(cz[2] - HERO_FEET)
    scene = hero_world(cz) + [{"pos": [0.0, float(cz[1]), (top + F.FLOOR) / 2],
                               "size": [1.6, 1.6, top - F.FLOOR], "colour": [0.6, 0.6, 0.62]}]
    return slerp_pass(lock_feet(clip(
        "PlaceHero", fr(36), False, "Action",
        "Lower the hero held overhead forward and down onto a pedestal in front (a deep squat, chest over it: "
        "the hands hold its ankles), hold the touch, open the hands off it, then rise into a right-fist pump to the sky and "
        "yank it down: YES. Feet stay planted.",
        "set a heavy object down on a table in front, release, fist pump; 1.2 s, touch-down at frame 16",
        keys, markers=[("Place", fr(PLACE_F))], views={"front34": [0.7, 1.0, 0.3], "side": [1.0, 0.08, 0.1]},
        extra={"_scene": scene,
               "_place": {"hero_lowertorso_centre_rig": [round(float(x), 3) for x in cz],
                          "pedestal_top_rig_z": round(top, 3), "grip_below_hero_lowertorso": GRIP_BELOW_LT}})))


# ---------------------------------------------------------------------------------------- rebirth
def rebirth_evolve():
    FEET = {R: (0.62, 0.02, -8, 0), L: (-0.62, 0.02, 8, 0)}
    FEET_UP = {R: (0.62, 0.02, -8, 22), L: (-0.62, 0.02, 8, 22)}   # heels up, toes where they were

    def P(root, tor, up, head, arms, feet=None):
        return planted_p(feet or FEET, root, tor, "rebirth", up=up, head=head, **arms)

    def drawn(tor, up, root, sq=0.0):
        """both fists drawn in at the sides of the waist, elbows back (chambered)"""
        return {**held(R, (1.35, 0.3 - sq, -0.35 + sq), (0.05, 0.98, 0.15), tor, up, root, hand=(-20, 0, 0)),
                **held(L, (-1.35, 0.3 - sq, -0.35 + sq), (-0.05, 0.98, 0.15), tor, up, root, hand=(-20, 0, 0))}

    keys = [(0.0, "smooth", "stand", P(-0.03, [0, 0, 0], [0, 0, 0], [0, 0, 0],
                                       {"uar": [-4, 0, 5], "lar": [-10, 0, 0], "ual": [-4, 0, -5], "lal": [-10, 0, 0]}))]
    T1, U1 = [-6, 0, 0], [-10, 0, 0]
    keys.append((fr(10), "smooth", "gather: knees bend, fists pull in to the waist",
                 P(-0.45, T1, U1, [6, 0, 0], drawn(T1, U1, -0.45))))
    T2, U2 = [-10, 0, 0], [-22, 0, 0]
    for i, f in enumerate(range(12, 37, 2)):
        u = (f - 12) / 24.0
        sh = (1 if i % 2 == 0 else -1) * (0.6 + 1.0 * u)           # the shake grows as the power builds
        root = -0.55 - 0.25 * u + 0.012 * sh
        up = [U2[0] - 6 * u, sh * 1.2, sh * 1.5]
        head = [-4 - 10 * u, -sh * 1.5, -sh]
        keys.append((fr(f), "in" if f == 36 else "linear", "coil and tremble" + (" (deepest)" if f == 36 else ""),
                     P(root, T2, up, head, drawn(T2, up, root, sq=0.08 * u))))
    burst = {"uar": [-10, 0, 128], "lar": [-12, 0, 0], "har": [0, 0, 0],
             "ual": [-10, 0, -128], "lal": [-12, 0, 0], "hal": [0, 0, 0]}
    over = {"uar": [-14, 0, 138], "lar": [-6, 0, 0], "har": [10, 0, 0],
            "ual": [-14, 0, -138], "lal": [-6, 0, 0], "hal": [10, 0, 0]}
    glory = {"uar": [-12, 0, 122], "lar": [-16, 0, 0], "har": [-10, 0, 0],
             "ual": [-12, 0, -122], "lal": [-16, 0, 0], "hal": [-10, 0, 0]}
    glory2 = {"uar": [-12, 0, 125], "lar": [-14, 0, 0], "har": [-10, 0, 0],
              "ual": [-12, 0, -125], "lal": [-14, 0, 0], "hal": [-10, 0, 0]}
    keys += [
        (fr(41), "out", "BURST: legs drive, up on the balls of the feet, arms flung wide and up, head back",
         P(0.12, [6, 0, 0], [16, 0, 0], [28, 0, 0], burst, feet=FEET_UP)),
        (fr(46), "smooth", "overshoot: arms wider, head further back",
         P(0.14, [7, 0, 0], [20, 0, 0], [34, 0, 0], over, feet=FEET_UP)),
        (fr(56), "smooth", "heels down: glorious V pose, chest up", P(-0.05, [3, 0, 0], [12, 0, 0], [18, 0, 0], glory)),
        (fr(73), "smooth", "hold: breathe in, chest rises", P(-0.03, [3, 0, 0], [14, 0, 0], [20, 0, 0], glory2)),
        (3.0, "smooth", "hold the pose", P(-0.05, [3, 0, 0], [12, 0, 0], [18, 0, 0], glory)),
    ]
    return slerp_pass(lock_feet_p(clip(
        "RebirthEvolve", 3.0, False, "Action",
        "Power-up: sink into a wide crouch with both fists drawn in at the waist, the whole body trembling "
        "harder as the power builds (0-1.2 s), then explode upward onto the balls of the feet with the arms "
        "flung wide and up, chest open and head thrown back (Burst at 1.3667 s), and hold a glorious V pose "
        "with a slow breath to the end.",
        "anime power-up / transformation: gather and shake, release, triumphant pose; 3.0 s",
        keys, markers=[("Burst", fr(41))], views={"front34": [0.7, 1.0, 0.3], "side": [1.0, 0.08, 0.1]}), pivot=True))


CLIPS = {"HeroWalkIn": hero_walk_in, "HeroArrive": hero_arrive, "CarryHold": carry_hold,
         "PlaceHero": place_hero, "RebirthEvolve": rebirth_evolve}
