"""Batch r4 (2026-11-15, owner review of the reveal walk: "childish, too fast, hyper"): a VILLAIN set.

  HeroStalk      hero, 1.6667 s loop (Movement): slow, heavy, menacing stride, two heel-to-toe steps
  HeroMenace     hero, 2.2 s (Action, held): plant the lead foot, head comes up, shoulders roll back,
                 fists clench and flex out with a chest lift (Look / Power)
  RebirthAwaken  player, 6.0 s (Action, held): one knee down, fist on the ground -> slow trembling rise ->
                 burst (head back, arms flung wide and up) -> confident power stance (Rise / Burst / Stance)

Same method as clips_r3.py: every frame is a key, every planted foot is SOLVED with fkmodel.py (pure-Python FK
of the rig, checked against Blender to 0.01 stud) and written as plain FK rotations. The stride is solved per
frame on a ground track whose contact point moves backward at exactly STALK_SPEED, so moving the
HumanoidRootPart at that speed gives zero foot slide. Truth is measured afterwards on the real meshes with
mesh_probe.py (`run.py probe`), and judged on the rendered sheets.
"""
import math

import numpy as np

import fkcheck as C
import fkmodel as F
from animlib import clip, pose
from clips_r3 import contact_ankle, plant_ankle, solve_feet, solve_hand
from clips_train import fr, slerp_pass

R, L = "R", "L"
EASE = dict(C.EASE)
EASE["in3"] = lambda u: u ** 3
EASE["out3"] = lambda u: 1 - (1 - u) ** 3
VIEWS = {"side": [1.0, 0.08, 0.1], "front34": [0.7, 1.0, 0.3]}
ARMS = ("uar", "lar", "har", "ual", "lal", "hal")


def _smooth(u):
    u = min(1.0, max(0.0, u))
    return u * u * (3 - 2 * u)


class Curve:
    """Keys [(frame, value, ease of the segment that starts here)]; value: float or list. Held outside."""

    def __init__(self, keys):
        self.k = [(f, np.asarray(v, float), e) for f, v, e in keys]

    def __call__(self, f):
        k = self.k
        if f <= k[0][0]:
            return k[0][1].copy()
        for (f0, v0, e), (f1, v1, _) in zip(k, k[1:]):
            if f <= f1:
                u = EASE[e]((f - f0) / float(f1 - f0))
                return v0 + (v1 - v0) * u
        return k[-1][1].copy()


def rl(v):
    return [round(float(x), 2) + 0.0 for x in v]


# ============================================================================================ STALK
STALK_N = 50                          # frames per cycle (two steps)
STALK_T = fr(STALK_N)                 # 1.6667 s
STANCE = 0.66                         # a slow walk: each foot is down two thirds of the cycle
STALK_STRIDE = 2.5                    # root travel per cycle (studs)
STALK_SPEED = STALK_STRIDE / STALK_T  # 1.5 studs/s
P0 = STALK_STRIDE * STANCE / 2        # flat-foot ankle position ahead of the root at heel strike (0.825)
FOOT_X = 0.56
HEEL = -14.0                          # toe up at the heel strike: a clear heel-to-toe roll
TOE = 30.0                            # heel up at toe-off
ROLL = 0.10                           # heel strike -> foot flat (a heavy, slow foot-fall over 5 frames)
RISE = 0.40                           # heel starts to rise
CLEAR = 0.16                          # a deliberate, planted swing: lifts clear, never high-steps
RC = 8                                # right heel strike frame; left at RC + 25
RC_T = fr(RC)


def stance_pitch(ph):
    if ph < ROLL:
        return HEEL * (1 - _smooth(ph / ROLL))
    if ph < RISE:
        return 0.0
    return TOE * (_smooth((ph - RISE) / (STANCE - RISE)) ** 1.3)


def foot_track(ph, x):
    """(ankle xyz, pitch) at cycle phase ph (0 = this foot's heel strike)."""
    ph %= 1.0
    if ph <= STANCE:
        p = P0 - STALK_STRIDE * ph
        h = stance_pitch(ph)
        y, z = contact_ankle(p, h)
        return np.array([x, y, z]), h
    u = (ph - STANCE) / (1 - STANCE)
    y0, _ = contact_ankle(P0 - STALK_STRIDE * STANCE, TOE)
    y1, _ = contact_ankle(P0, HEEL)
    m = -STALK_SPEED * (1 - STANCE) * STALK_T          # leave and meet the ground at root speed: no skid
    h00, h10, h01, h11 = 2 * u**3 - 3 * u**2 + 1, u**3 - 2 * u**2 + u, -2 * u**3 + 3 * u**2, u**3 - u**2
    y = h00 * y0 + h10 * m + h01 * y1 + h11 * m
    h = TOE + (HEEL - TOE) * _smooth(u / 0.8)
    a = math.radians(abs(h))
    z = F.FLOOR + 0.5 * math.sin(a) + 0.252 * math.cos(a) + CLEAR * math.sin(math.pi * u) ** 0.8
    return np.array([x, y, z]), h


def stalk_upper(t):
    """Chest carried forward, shoulders rolling with each step, head steady and low, arms hanging loose."""
    w = 2 * math.pi * (t - RC_T) / STALK_T
    tor = [-3.0, 5.0 * math.cos(w), 0.0]                     # right hip leads at the right heel strike
    sh = -9.0 * math.cos(w - 0.35)                           # shoulders counter-turn (world), a slow roll
    up = [-7.0 + 1.0 * math.cos(2 * w - 0.9), sh - tor[1], 3.0 * math.sin(w - 0.35)]
    head = [-5.0 - (up[0] + 7.0), -sh * 0.9, -up[2] * 0.9]  # eyes level on the target, chin down
    f = -math.cos(w - 0.6)                                   # right arm forward amount; loose arms lag
    arm = {}
    for s, ff, sg in ((R, f, 1), (L, -f, -1)):
        sf = s.lower()
        arm["ua" + sf] = [-1.0 - 11.0 * ff, 0.0, sg * 8.0]
        arm["la" + sf] = [-14.0 - 8.0 * max(0.0, ff), 0.0, 0.0]
        arm["ha" + sf] = [-9.0, 0.0, 0.0]
    return tor, up, head, arm


def stalk_root(t):
    # almost no bob: 0.012 studs, lowest just after each heel strike (the weight lands)
    return -0.12 - 0.012 * math.cos(4 * math.pi * (t - RC_T - 0.1) / STALK_T)


def stalk_frame(t):
    tor, up, head, arm = stalk_upper(t)
    root = stalk_root(t)
    ph = (t - RC_T) / STALK_T
    feet = {}
    for side, p, x, yaw in ((R, ph, FOOT_X, -6.0), (L, ph + 0.5, -FOOT_X, 6.0)):
        ank, h = foot_track(p, x)
        feet[side] = (ank, h, yaw)
    b = pose(legs=solve_feet(feet, root, tor, "stalk"), tor=tor, up=up, head=head, **arm)
    b["ROOT"] = {"loc": F.root_loc(root)}
    return b


def hero_stalk():
    keys = []
    lc = RC + STALK_N // 2
    for f in range(STALK_N):
        note = "RIGHT heel strike" if f == RC else "LEFT heel strike" if f == lc else "stalk"
        keys.append((fr(f), "linear", note, stalk_frame(fr(f))))
    keys.append((STALK_T, "linear", "loop", keys[0][3]))
    return slerp_pass(clip(
        "HeroStalk", STALK_T, True, "Movement",
        "A villain's slow, menacing stalk: heavy deliberate heel-to-toe steps with almost no bob, chest carried "
        "slightly forward, shoulders rolling with each step, head steady and low (chin down, eyes forward), "
        "arms hanging loose with a small slow swing, hands relaxed. Weight, menace, confidence; never bouncy.",
        f"slow heavy walk: 2 steps per {STALK_T} s, stance {STANCE:.0%} of the cycle, root travel "
        f"{STALK_STRIDE:.4f} studs per cycle ({STALK_SPEED:.4f} studs/s)",
        keys, markers=[("Step", fr(RC)), ("Step", fr(lc))], views=VIEWS,
        extra={"_walk": {"stride_per_cycle": round(STALK_STRIDE, 4), "speed_studs_per_s": round(STALK_SPEED, 4),
                         "right_contact": fr(RC), "left_contact": fr(lc),
                         "how": "move the HumanoidRootPart forward at speed_studs_per_s while this loops"}}))


# =========================================================================================== MENACE
MEN_N = 66
TRAV = 0.5                                  # root travel during HeroMenace (game-driven, Quad Out)
STOP = round(2 * TRAV / STALK_SPEED, 4)     # 0.6667 s: starts at the stalk speed, ends at 0
LOOK_F, POWER_F = 36, 50
L_LAND = 22                                 # the trailing (left) foot lands beside / behind
LEFT_END = (-0.78, -0.08, 14.0)             # x, y (flat ankle), yaw
RIGHT_YAW_END = -9.0


def men_d(t):
    u = min(1.0, t / STOP)
    return TRAV * (1 - (1 - u) ** 2)


def men_dv(t):
    u = min(1.0, t / STOP)
    return 2 * TRAV * (1 - u) / STOP


def hero_menace():
    """Starts on the stalk's RIGHT heel strike (HeroStalk TimePosition RC_T). The game coasts the root
    TRAV studs forward (Quad Out over STOP s) while the right heel rolls flat; the left foot finishes its
    stance, then takes one slow step to plant behind and outside. Then the menace beats."""
    t_to = (STANCE - 0.5) * STALK_T           # left toe-off (walk phase STANCE)
    t_land = fr(L_LAND)

    def right_foot(t):
        ph = min(t / STALK_T, ROLL)
        h = stance_pitch(ph)
        y, z = contact_ankle(P0 - men_d(t), h)
        yaw = -6.0 + (RIGHT_YAW_END + 6.0) * _smooth((t - 0.3) / 0.6)
        return np.array([FOOT_X, y, z]), h, yaw

    def left_foot(t):
        if t <= t_to:
            ph = 0.5 + t / STALK_T
            h = stance_pitch(ph)
            y, z = contact_ankle(P0 - STALK_STRIDE * 0.5 - men_d(t), h)
            return np.array([-FOOT_X, y, z]), h, 6.0
        x1, p1, yaw1 = LEFT_END
        if t >= t_land:
            h = -6.0 * (1 - _smooth((t - t_land) / fr(4)))
            y, z = contact_ankle(p1, h)
            return np.array([x1, y, z]), h, yaw1
        u = (t - t_to) / (t_land - t_to)
        y0, _ = contact_ankle(P0 - STALK_STRIDE * 0.5 - men_d(t_to), TOE)
        y1, _ = contact_ankle(p1, -6.0)
        m0 = -men_dv(t_to) * (t_land - t_to)
        h00, h10, h01 = 2 * u**3 - 3 * u**2 + 1, u**3 - 2 * u**2 + u, -2 * u**3 + 3 * u**2
        y = h00 * y0 + h10 * m0 + h01 * y1
        x = -FOOT_X + (x1 + FOOT_X) * _smooth(u)
        h = TOE + (-6.0 - TOE) * _smooth(u / 0.85)
        a = math.radians(abs(h))
        z = F.FLOOR + 0.5 * math.sin(a) + 0.252 * math.cos(a) + 0.2 * math.sin(math.pi * u) ** 0.8
        return np.array([x, y, z]), h, 6.0 + (yaw1 - 6.0) * _smooth(u)

    tor0, up0, head0, arm0 = stalk_upper(RC_T)
    hang = lambda z, la, ha, x=0.0: {"uar": [x, 0, z], "lar": [la, 0, 0], "har": [ha, 0, 0],  # noqa: E731
                                     "ual": [x, 0, -z], "lal": [la, 0, 0], "hal": [ha, 0, 0]}
    beats = [  # (frame, ease, root, tor, up, head, arms)
        (0, "smooth", stalk_root(RC_T), tor0, up0, head0, arm0),
        (14, "smooth", -0.15, [-3, 3, 0], [-7, -3, 0], [-5, 1, 0], hang(8, -15, -9, 1.0)),
        (24, "smooth", -0.19, [-4, 5, 0], [-8, -5, 0], [-11, 0, 0], hang(9, -16, -10)),
        (27, "smooth", -0.18, [-4, 5, 0], [-8, -5, 0], [-12, 0, 0], hang(9, -16, -10)),
        (LOOK_F, "smooth", -0.16, [-4, 5, 0], [-8, -5, 0], [9, 0, 0], hang(9, -16, -10)),       # LOOK
        (46, "in", -0.14, [-3, 5, 0], [1, -5, 0], [1, 0, 0], hang(11, -18, -12, 7.0)),          # shoulders back
        (POWER_F, "out", -0.07, [-2, 5, 0], [6, -5, 0], [-2, 0, 0],                             # POWER
         {"uar": [6, 0, 21], "lar": [-38, 0, 0], "har": [-32, 0, 0],
          "ual": [6, 0, -21], "lal": [-38, 0, 0], "hal": [-32, 0, 0]}),
        (54, "smooth", -0.06, [-2, 5, 0], [7, -5, 0], [-3, 0, 0],
         {"uar": [6, 0, 23], "lar": [-41, 0, 0], "har": [-34, 0, 0],
          "ual": [6, 0, -23], "lal": [-41, 0, 0], "hal": [-34, 0, 0]}),
        (61, "smooth", -0.08, [-2, 5, 0], [5, -5, 0], [-1, 0, 0],
         {"uar": [5, 0, 20], "lar": [-36, 0, 0], "har": [-32, 0, 0],
          "ual": [5, 0, -20], "lal": [-36, 0, 0], "hal": [-32, 0, 0]}),
        (MEN_N, "smooth", -0.08, [-2, 5, 0], [5.5, -5, 0], [-1.5, 0, 0],
         {"uar": [5, 0, 20.5], "lar": [-36, 0, 0], "har": [-32, 0, 0],
          "ual": [5, 0, -20.5], "lal": [-36, 0, 0], "hal": [-32, 0, 0]}),
    ]
    cv = {"root": Curve([(b[0], b[2], b[1]) for b in beats]),
          "tor": Curve([(b[0], b[3], b[1]) for b in beats]),
          "up": Curve([(b[0], b[4], b[1]) for b in beats]),
          "head": Curve([(b[0], b[5], b[1]) for b in beats])}
    for a in ARMS:
        cv[a] = Curve([(b[0], b[6][a], b[1]) for b in beats])
    keys = []
    for f in range(MEN_N + 1):
        t = fr(f)
        if f == 0:
            keys.append((0.0, "linear", f"HeroStalk pose at its RIGHT heel strike (t={RC_T})", stalk_frame(RC_T)))
            continue
        root, tor = float(cv["root"](f)), rl(cv["tor"](f))
        feet = {R: right_foot(t), L: left_foot(t)}
        b = pose(legs=solve_feet(feet, root, tor, "menace"), tor=tor, up=rl(cv["up"](f)), head=rl(cv["head"](f)),
                 **{a: rl(cv[a](f)) for a in ARMS})
        b["ROOT"] = {"loc": F.root_loc(root)}
        note = {L_LAND: "left foot plants", LOOK_F: "LOOK: head up, eyes on the camera", 46: "shoulders rolled back",
                POWER_F: "POWER: fists clench, arms flex out, chest lifts"}.get(f, "menace")
        keys.append((t, "linear", note, b))
    return slerp_pass(clip(
        "HeroMenace", fr(MEN_N), False, "Action",
        "The villain stops in front of the food: the lead (right) foot plants, the trailing foot takes one slow "
        "step, then the head slowly comes up from chin-down to staring straight at the camera, the shoulders "
        "roll back, and both fists clench at the sides as the arms flex slightly outward with a small chest "
        "lift: a power-up pose, held.",
        "walk-to-stop, slow look-up, shoulder roll, fist clench (bodybuilder-lite flex); held last pose",
        keys, markers=[("Look", fr(LOOK_F)), ("Power", fr(POWER_F))], views=VIEWS,
        extra={"_arrive": {"start_from": f"HeroStalk at its RIGHT Step (TimePosition {RC_T})",
                           "root_travel": TRAV, "root_travel_time": STOP,
                           "root_easing": "Quad Out (initial speed = HeroStalk speed)"}}))


# ========================================================================================== AWAKEN
AW_N = 180
RISE_F, BURST_F, STANCE_F = 36, 105, 132
LF = (-0.96, 0.42, 24.0)               # front (left) foot: x, y (flat ankle), yaw - planted the whole clip
RF_END = (0.72, -0.25, -14.0)          # rear (right) foot after its step
KNEEL_ROOT = -0.58
KNEEL_TOR, KNEEL_UP = [-10, 0, -8], [-42, 2, -28]   # body Z<0 leans to the RIGHT: down toward the fist
RF_KNEEL_H = 62.0                      # rear toes tucked under: heel this far up
RF_KNEEL_Y = -1.5                      # rear toe plant: the shin then lies on the floor (knee down)
STEP0, STEP1 = 56, 76                  # rear foot swing frames


def _shin_low(bones, root, side):
    """lowest corner of the lower-leg box (mesh at rest: 1 x 1 x 1.193, z -2.797..-1.604, knee at -1.822)."""
    o = F.fk(bones, root)
    sf = side.lower()
    Dt = F.local_delta(F.B_BODY, bones.get("tor", [0, 0, 0]))
    Dll = Dt @ F.local_delta(F.B_LIMB, bones["ul" + sf]) @ F.local_delta(F.B_LIMB, bones["ll" + sf])
    c = o["knee" + side] + Dll @ np.array([0.0, 0.0, -0.3785])
    return min((c + Dll @ np.array([x, y, z]))[2] for x in (-0.5, 0.5) for y in (-0.5, 0.5) for z in (-0.597, 0.597))


def kneel_rear_y(root, tor, heel, x=0.62, yaw=-4.0):
    """y of the rear toe plant that puts the rear KNEE (shin box) on the floor (bisection)."""
    lo, hi = -1.6, -0.5
    for _ in range(40):
        y = (lo + hi) / 2
        ax, ay = plant_ankle((x, y, yaw, heel))
        lg, err, _ = F.solve_leg(R, (ax, ay), root, tor, yaw=yaw, heel=heel)
        z = _shin_low({"tor": tor, "ulr": lg["ul"], "llr": lg["ll"], "fr": lg["f"]}, root, R)
        # foot further back -> knee lower
        if z < F.FLOOR + 0.01:
            hi = y
        else:
            lo = y
    return round((lo + hi) / 2, 3)


def rebirth_awaken():
    rk = (0.62, RF_KNEEL_Y, -4.0)

    def right_plant(f):
        """(ankle, heel, yaw) of the rear foot."""
        if f <= RISE_F:
            return plant_ankle((rk[0], rk[1], rk[2], RF_KNEEL_H)), RF_KNEEL_H, rk[2]
        if f <= STEP0:   # the knee comes off the ground: pivot on the tucked toes, heel lowers a little
            h = RF_KNEEL_H + (55.0 - RF_KNEEL_H) * _smooth((f - RISE_F) / (STEP0 - RISE_F))
            return plant_ankle((rk[0], rk[1], rk[2], h)), h, rk[2]
        x1, y1, yaw1 = RF_END
        if f >= STEP1:
            h = heel_burst(f)
            return plant_ankle((x1, y1, yaw1, h)), h, yaw1
        u = (f - STEP0) / float(STEP1 - STEP0)
        a0 = np.array(list(plant_ankle((rk[0], rk[1], rk[2], 55.0))) + [contact_ankle(rk[1], 55.0)[1]])
        a1 = np.array([x1, y1, F.ANKLE_REST_Z + 0.0])
        e = _smooth(u)
        p = a0 + (a1 - a0) * e
        p[2] += 0.2 * math.sin(math.pi * u) ** 0.9
        h = 55.0 * (1 - _smooth(u / 0.8))
        return p, h, rk[2] + (yaw1 - rk[2]) * e

    def heel_burst(f):
        """both heels come up onto the balls of the feet for the burst, and back down."""
        if f < 101 or f > 122:
            return 0.0
        if f <= BURST_F:
            return 20.0 * _smooth((f - 101) / (BURST_F - 101.0))
        if f <= 110:
            return 20.0
        return 20.0 * (1 - _smooth((f - 110) / 12.0))

    def left_plant(f):
        h = heel_burst(f)
        return plant_ankle((LF[0], LF[1], LF[2], h)), h, LF[2]

    fistR = lambda la, ha, z=14, x=-12: {"uar": [x, 0, z], "lar": [la, 0, 0], "har": [ha, 0, 0]}  # noqa: E731
    fistL = lambda la, ha, z=14, x=-12: {"ual": [x, 0, -z], "lal": [la, 0, 0], "hal": [ha, 0, 0]}  # noqa: E731
    burst = {"uar": [-10, 0, 108], "lar": [-12, 0, 0], "har": [0, 0, 0],
             "ual": [-10, 0, -108], "lal": [-12, 0, 0], "hal": [0, 0, 0]}
    over = {"uar": [-14, 0, 114], "lar": [-6, 0, 0], "har": [10, 0, 0],
            "ual": [-14, 0, -114], "lal": [-6, 0, 0], "hal": [10, 0, 0]}
    stance = {**fistR(-34, -30, 24, -6), **fistL(-34, -30, 24, -6)}
    # (frame, ease, root, tor, up, head, arms or None = solved contact)
    beats = [
        (0, "smooth", KNEEL_ROOT, KNEEL_TOR, KNEEL_UP, [-24, 0, 14], None),
        (18, "smooth", KNEEL_ROOT - 0.01, KNEEL_TOR, [KNEEL_UP[0], KNEEL_UP[1] + 2, KNEEL_UP[2]], [-20, -1, 14], None),
        (RISE_F, "smooth", KNEEL_ROOT, KNEEL_TOR, KNEEL_UP, [-24, 0, 14], None),                       # RISE
        (STEP0, "smooth", -0.4, [-8, -3, 1], [-24, 2, 2], [-26, 0, 0],
         {**fistR(-48, -20, 18, -16), **fistL(-40, -20, 30, -22)}),
        (STEP1, "smooth", -0.24, [-7, -6, 0], [-20, 5, 0], [-26, 0, 0],
         {**fistR(-52, -30, 17, -10), **fistL(-52, -30, 17, -10)}),
        (100, "in", -0.17, [-3, -6, 0], [-12, 6, 0], [-22, 0, 0],
         {**fistR(-68, -34, 15, -10), **fistL(-68, -34, 15, -10)}),
        (BURST_F, "out", -0.11, [4, -3, 0], [16, 3, 0], [28, 0, 0], burst),                            # BURST
        (110, "smooth", -0.09, [5, -3, 0], [20, 3, 0], [34, 0, 0], over),
        (121, "smooth", -0.13, [1, -5, 0], [8, 5, 0], [10, 0, 0],
         {**fistR(-24, -18, 50, -10), **fistL(-24, -18, 50, -10)}),
        (STANCE_F, "smooth", -0.13, [0, -6, 0], [5, 6, 0], [6, 0, 0], stance),                       # STANCE
        (150, "smooth", -0.11, [0, -6, 0], [6.5, 6, 0], [5, 0, 0],
         {**fistR(-35, -30, 25, -6), **fistL(-35, -30, 25, -6)}),
        (165, "smooth", -0.13, [0, -6, 0], [5, 6, 0], [6, 0, 0], stance),
        (AW_N, "smooth", -0.12, [0, -6, 0], [5.5, 6, 0], [5.5, 0, 0], stance),
    ]

    # contact arms in the kneel: the right fist's knuckles on the floor, the left forearm across the left knee
    def kneel_arms(root, tor, up, guess):
        bones = {"tor": tor, "up": up}
        kr, gr = fist_on_floor(FIST_GROUND, tor, up, root, guess.get(R))
        lg = F.solve_leg(L, plant_ankle((LF[0], LF[1], LF[2], 0.0)), root, tor, yaw=LF[2])[0]
        o = F.fk({**bones, "ull": lg["ul"], "lll": lg["ll"], "fl": lg["f"]}, root)
        kn = o["kneeL"]
        for dz in (0.15, 0.19, 0.23, 0.27, 0.31):   # forearm across the knee; nearest reachable spot
            try:
                kl, gl = solve_hand(L, [kn[0] - 0.05, kn[1] + 0.55, kn[2] + 0.45 + dz], tor, up, root,
                                    fore_dir=[0.15, 0.8, -0.55], palm_in=False, guess=guess.get(L))
                break
            except ValueError:
                continue
        guess[R], guess[L] = gr, gl
        return {**kr, **kl}

    cv = {"root": Curve([(b[0], b[2], b[1]) for b in beats]),
          "tor": Curve([(b[0], b[3], b[1]) for b in beats]),
          "up": Curve([(b[0], b[4], b[1]) for b in beats]),
          "head": Curve([(b[0], b[5], b[1]) for b in beats])}
    guess = {}
    arm_keys = []
    for b in beats:
        arms = b[6]
        if arms is None:
            arms = kneel_arms(b[2], list(b[3]), list(b[4]), guess)
        arm_keys.append((b[0], arms, b[1]))
    for a in ARMS:
        cv[a] = Curve([(f, arms[a], e) for f, arms, e in arm_keys])

    def tremble(f):
        """power building: a small, fast shake (2 frames each way) in the torso and arms, 1.4 -> 3.4 s"""
        if f < 42 or f > 102:
            return 0.0
        amp = _smooth((f - 42) / 30.0) * (0.7 + 0.8 * _smooth((f - 80) / 20.0))
        amp *= 1 - _smooth((f - 100) / 2.0)
        return amp * math.sqrt(2) * math.sin(math.pi / 2 * f + math.pi / 4)

    keys = []
    for f in range(AW_N + 1):
        t = fr(f)
        s = tremble(f)
        root = float(cv["root"](f)) + 0.006 * s
        tor = rl(cv["tor"](f))
        up = cv["up"](f) + np.array([0.0, 1.2 * s, 1.5 * s])
        head = cv["head"](f) + np.array([0.0, -1.0 * s, -0.8 * s])
        if f <= RISE_F:
            arms = kneel_arms(root, tor, rl(up), guess)
        else:
            arms = {a: cv[a](f) for a in ARMS}
            arms["uar"] = arms["uar"] + np.array([0.0, 0.0, 1.8 * s])
            arms["ual"] = arms["ual"] + np.array([0.0, 0.0, 1.8 * s])
            arms["lar"] = arms["lar"] + np.array([-2.0 * s, 0.0, 0.0])
            arms["lal"] = arms["lal"] + np.array([2.0 * s, 0.0, 0.0])
        ra, rh, ryaw = right_plant(f)
        la, lh, lyaw = left_plant(f)
        feet = {R: (ra, rh, ryaw), L: (la, lh, lyaw)}
        b = pose(legs=solve_feet(feet, root, tor, "awaken"), tor=tor, up=rl(up), head=rl(head),
                 **{a: rl(v) for a, v in arms.items()})
        b["ROOT"] = {"loc": F.root_loc(root)}
        note = {0: "one knee down, head bowed, right fist on the ground", RISE_F: "RISE: the push begins",
                STEP0: "rear knee off, the foot steps through", STEP1: "rear foot plants: trembling with power",
                BURST_F: "BURST: head thrown back, arms flung wide and up", STANCE_F: "STANCE: power stance",
                AW_N: "hold"}.get(f, "awaken")
        keys.append((t, "linear", note, b))
    return slerp_pass(clip(
        "RebirthAwaken", fr(AW_N), False, "Action",
        "A villain levels up: down on one knee with the head bowed and the right fist's knuckles on the ground, "
        "the left forearm across the front knee (0-1.2 s); slowly rises as the fists clench, the rear foot "
        "steps through, the body trembling harder with power, head still down (1.2-3.4 s); explodes upward "
        "onto the balls of the feet, head thrown back, arms flung wide and up, chest out (Burst 3.5 s); settles "
        "into a confident power stance, feet apart, fists at hip level slightly out, chin raised, held.",
        "superhero landing kneel -> trembling rise -> power-up burst -> power stance; 6.0 s",
        keys, markers=[("Rise", fr(RISE_F)), ("Burst", fr(BURST_F)), ("Stance", fr(STANCE_F))], views=VIEWS))


FIST_GROUND = [1.55, 0.8]             # right hand-part centre (x, y) in the kneel; z is solved onto the floor
FIST_TIP = [0.0, 0.2, -0.98]           # the knuckle face points down, a little forward


def fist_on_floor(xy, tor, up, root, guess):
    """right arm whose hand box rests its lowest corner ON the floor at hand-centre (x, y)."""
    z = -2.75
    for _ in range(4):
        kr, g = solve_hand(R, [xy[0], xy[1], z], tor, up, root, fore_dir=[0.05, 0.3, -0.95], palm_in=False,
                           guess=guess, tip=FIST_TIP)
        o = F.fk({"tor": tor, "up": up, **kr}, root)
        low = min((o["wristR"] + o["DhandR"] @ c)[2] for c in F.HAND_CORNERS)
        z += F.FLOOR - low
        guess = g
    return kr, g


CLIPS = {"HeroStalk": hero_stalk, "HeroMenace": hero_menace, "RebirthAwaken": rebirth_awaken}
