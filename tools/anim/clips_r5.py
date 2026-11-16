"""Batch r5 (2026-11-15, the owner's new reveal flow): the silhouette stalks up to the thrown food (HeroStalk),
then PICKS IT UP before it is revealed.

  HeroPickUp  hero, 2.5 s (Action, held): chains from HeroStalk's RIGHT Step, stops (root coasts 0.5 Quad Out,
              the left foot takes one slow step back), bends with weight (knees, back, left arm hanging
              heavy), the right fist comes down onto the top-back of the food in front of the right foot
              (Grab), rises slowly lifting it to shoulder height out to his right, studies it (Lift), then a confident beat (Hold).

Same method as clips_r4.py: every frame is a key; planted feet are SOLVED with fkmodel.py; the right hand is
SOLVED per frame along an authored path (solve_hand) with its knuckle face pointing at the food's centre from
the Grab on, so the food can be welded with a pure offset along the hand's own -Y (Roblox) axis.
"""
import math

import numpy as np

import fkmodel as F
from animlib import clip, pose
from clips_r3 import contact_ankle, hand_centre, plant_ankle, solve_feet, solve_hand, to_roblox
from clips_r4 import (ARMS, FOOT_X, P0, RC_T, ROLL, STALK_STRIDE, STALK_T, STANCE, STOP, TOE, TRAV, Curve,
                      VIEWS, _smooth, men_d, men_dv, rl, stalk_frame, stalk_upper, stalk_root, stance_pitch)
from clips_train import fr, slerp_pass

R, L = "R", "L"

PU_N = 75                                   # 2.5 s
GRAB_F, LIFT_F, HOLD_F = 38, 61, 67
L_LAND = 20                                 # the trailing (left) foot plants behind: a split stance to bend in
LEFT_END = (-0.95, -0.28, 8.0)             # x, y (flat ankle), yaw
RIGHT_YAW_END = -9.0                       # toes turn out: the knee opens and clears the chest
FOOD_R = 0.9                                # the food's radius (studs) the clip is authored for
FOOD_C = np.array([1.05, 2.70, F.FLOOR + FOOD_R])     # food centre at rest on the floor, rig space at the END root
GRAB_N = np.array([0.0, -0.60, 1.0]) / np.linalg.norm([0.0, -0.60, 1.0])   # food centre -> hand: top-back
KNUCKLE = 0.15                              # hand centre -> knuckle face (half the 0.3 hand)
REACH0 = 8                                  # the right arm leaves the stalk swing and starts its solved path


def grab_hand():
    return FOOD_C + GRAB_N * (FOOD_R + KNUCKLE)


def hand_path():
    """(frame, hand centre (rig), knuckle-face direction or None, ease) for the right hand."""
    g = grab_hand()
    return [
        (24, [1.45, 1.30, -0.80], None, "smooth"),
        (33, [g[0] + 0.02, g[1] - 0.12, g[2] + 0.30], list(-GRAB_N), "out"),     # over the food, coming down
        (GRAB_F, list(g), list(-GRAB_N), "smooth"),                               # GRAB: knuckles on the food
        (43, list(g + [0, 0, 0.03]), list(-GRAB_N), "in"),                        # the squeeze; weight taken
        (53, [1.25, 1.45, -0.65], None, "smooth"),                                # food comes up with the body
        (57, [1.62, 1.20, -0.32], None, "smooth"),                                # swung out to his right
        (LIFT_F, [1.62, 0.80, 0.08], [0.18, 0.62, 0.76], "smooth"),              # LIFT: food up in front of the face
        (HOLD_F, [1.70, 0.66, 0.16], [0.24, 0.55, 0.80], "smooth"),              # HOLD: turned up a touch, steady
        (PU_N, [1.70, 0.66, 0.15], [0.24, 0.55, 0.80], "smooth"),
    ]


MISSES = []


def _solve_r(f, c, tor, up, root, tip, guess):
    """solve_hand for the right hand; a miss is recorded (and printed by the check) instead of raised"""
    try:
        return solve_hand(R, c, tor, up, root, palm_in=False, guess=guess, tip=tip, avoid=6.0)
    except ValueError:
        import clips_r3
        th = clips_r3.np.linalg.norm
        del th
        # re-run with the reach clamped toward the shoulder, record the miss
        sh = F.fk({"tor": tor, "up": up}, root)["shoulderR"]
        for k in np.linspace(0.01, 0.3, 30):
            try:
                out = solve_hand(R, np.asarray(c) + (sh - np.asarray(c)) * k, tor, up, root, palm_in=False,
                                 guess=guess, tip=tip, avoid=6.0)
                MISSES.append((f, round(float(k * np.linalg.norm(sh - np.asarray(c))), 3)))
                return out
            except ValueError:
                continue
        raise


def hero_pickup():
    t_to = (STANCE - 0.5) * STALK_T            # left toe-off (walk phase STANCE)
    t_land = fr(L_LAND)

    def right_foot(t):
        ph = min(t / STALK_T, ROLL)
        h = stance_pitch(ph)
        y, z = contact_ankle(P0 - men_d(t), h)
        yaw = -6.0 + (RIGHT_YAW_END + 6.0) * _smooth((t - 0.3) / 0.6)
        return np.array([FOOT_X, y, z]), h, yaw

    def left_heel(f):
        """the rear foot lands on its ball (heel 12 up), the heel peels higher as the weight goes forward into
        the bend, and settles flat as he rises"""
        if f > 60:
            return 0.0
        if f <= 31:
            return 12.0 + 18.0 * _smooth((f - L_LAND) / float(31 - L_LAND))
        if f <= 48:
            return 30.0
        return 30.0 * (1 - _smooth((f - 48) / 12.0))

    def left_foot(t, f):
        if t <= t_to:
            ph = 0.5 + t / STALK_T
            h = stance_pitch(ph)
            y, z = contact_ankle(P0 - STALK_STRIDE * 0.5 - men_d(t), h)
            return np.array([-FOOT_X, y, z]), h, 6.0
        x1, p1, yaw1 = LEFT_END
        if t >= t_land:
            h = left_heel(f)
            ax, ay = plant_ankle((x1, p1, yaw1, h))
            return np.array([ax, ay, contact_ankle(p1, h)[1]]), h, yaw1
        u = (t - t_to) / (t_land - t_to)
        y0, _ = contact_ankle(P0 - STALK_STRIDE * 0.5 - men_d(t_to), TOE)
        y1, _ = contact_ankle(p1, 12.0)
        m0 = -men_dv(t_to) * (t_land - t_to)
        h00, h10, h01 = 2 * u**3 - 3 * u**2 + 1, u**3 - 2 * u**2 + u, -2 * u**3 + 3 * u**2
        y = h00 * y0 + h10 * m0 + h01 * y1
        x = -FOOT_X + (x1 + FOOT_X) * _smooth(u)
        h = TOE + (12.0 - TOE) * _smooth(u / 0.85)
        a = math.radians(abs(h))
        z = F.FLOOR + 0.5 * math.sin(a) + 0.252 * math.cos(a) + 0.18 * math.sin(math.pi * u) ** 0.8
        return np.array([x, y, z]), h, 6.0 + (yaw1 - 6.0) * _smooth(u)

    tor0, up0, head0, arm0 = stalk_upper(RC_T)
    r0 = stalk_root(RC_T)
    # (frame, ease, root (right, fwd, up), tor, up, head)
    beats = [
        (0, "smooth", [0, 0, r0], tor0, up0, head0),
        (12, "smooth", [0, 0.03, -0.17], [-4, 3, 0], [-10, -3, 0], [-16, -2, 0]),       # stops; eyes on the food
        (24, "smooth", [0, 0.10, -0.34], [-10, 4, 0], [-12, -5, -2], [-6, -6, 0]),        # weight forward, going down
        (33, "out", [0, 0.26, -0.45], [-19, 5, 0], [-16, -7, -2], [6, -8, 0]),
        (GRAB_F, "smooth", [0, 0.27, -0.48], [-22, 5, 0], [-18, -8, -2], [10, -8, 0]),   # GRAB
        (43, "smooth", [0, 0.27, -0.50], [-23, 5, 0], [-18, -8, -2], [11, -8, 0]),      # weight taken
        (53, "smooth", [0, 0.10, -0.32], [-10, 3, 0], [-7, -7, -1], [-2, -12, 2]),      # rising, slow
        (LIFT_F, "smooth", [0, 0, -0.14], [-3, 1, 0], [3, -8, 0], [-12, -34, 4]),         # LIFT: food at the face
        (HOLD_F, "smooth", [0, 0, -0.09], [-1, 0, 0], [6, -7, 0], [-9, -40, 10]),         # HOLD: chest up, head cocked
        (PU_N, "smooth", [0, 0, -0.10], [-1, 0, 0], [5.5, -7, 0], [-9.5, -40, 10]),
    ]
    cv = {k: Curve([(b[0], b[i], b[1]) for b in beats]) for i, k in ((2, "root"), (3, "tor"), (4, "up"), (5, "head"))}
    hang = {"uar": arm0["uar"], "lar": arm0["lar"], "har": arm0["har"]}
    # the right arm before its path: from the stalk swing toward a heavy hang
    ra = {a: Curve([(0, hang[a], "smooth"), (REACH0, {"uar": [-8, 0, 9], "lar": [-18, 0, 0],
                                                       "har": [-8, 0, 0]}[a], "smooth")]) for a in hang}
    # the left arm when not braced: hangs loose, a slow fist at the hold
    hl = lambda x, z, l, h: {"ual": [x, 0, z], "lal": [l, 0, 0], "hal": [h, 0, 0]}  # noqa: E731
    lk = [(0, {a: arm0[a] for a in ("ual", "lal", "hal")}), (12, hl(2, -9, -16, -9)), (24, hl(8, -11, -20, -10)),
          (33, hl(16, -13, -24, -12)), (GRAB_F, hl(18, -13, -25, -12)), (43, hl(19, -13, -26, -13)),
          (53, hl(8, -10, -20, -12)), (LIFT_F, hl(3, -12, -22, -16)), (HOLD_F, hl(4, -15, -30, -26)),
          (PU_N, hl(4, -14.5, -30, -26))]
    la = {a: Curve([(k, v[a], "smooth") for k, v in lk]) for a in ("ual", "lal", "hal")}

    path = hand_path()
    guess = {}
    keys, info = [], {}
    h_start = None
    for f in range(PU_N + 1):
        t = fr(f)
        if f == 0:
            keys.append((0.0, "linear", f"HeroStalk pose at its RIGHT heel strike (t={RC_T})", stalk_frame(RC_T)))
            continue
        root = cv["root"](f)
        tor, up, head = rl(cv["tor"](f)), rl(cv["up"](f)), rl(cv["head"](f))
        feet = {R: right_foot(t), L: left_foot(t, f)}
        legs = solve_feet(feet, root, tor, "pickup")
        bones = {"tor": tor, "up": up}
        # ---- right arm
        if f <= REACH0:
            arm_r = {a: rl(ra[a](f)) for a in ra}
            if f == REACH0:
                o0 = F.fk({**bones, **arm_r}, root)
                h_start, tip_start = hand_centre(o0, R), o0["DhandR"] @ np.array([0, 0, -1.0])
        else:
            pk = [(REACH0, list(h_start), list(tip_start), "smooth")] + path
            c = Curve([(k[0], k[1], k[3]) for k in pk])(f)
            tips = [(k[0], k[2]) for k in pk if k[2] is not None]
            tip = Curve([(k, v, "smooth") for k, v in tips])(f)
            tip = tip / np.linalg.norm(tip)
            arm_r, guess[R] = _solve_r(f, c, tor, up, root, tip, guess.get(R))
        # ---- left arm: braced on the left thigh through the deep bend
        arm_l = {a: rl(la[a](f)) for a in la}
        b = pose(legs=legs, tor=tor, up=up, head=head, **arm_r, **arm_l)
        b["ROOT"] = {"loc": F.root_loc(root)}
        note = {L_LAND: "left foot plants behind", 24: "going down, heavy", GRAB_F: "GRAB: knuckles close on the food",
                43: "weight taken", LIFT_F: "LIFT: the food up at the face, studied", HOLD_F: "HOLD: chest up, head cocked",
                PU_N: "hold"}.get(f, "pickup")
        keys.append((t, "linear", note, b))
        if f in (GRAB_F, LIFT_F, HOLD_F):
            o = F.fk({**bones, "head": head, **arm_r}, root)
            info[f] = (hand_centre(o, R), o["DhandR"])

    def frame_info(f):
        c, D = info[f]
        M = np.array([[1.0, 0, 0], [0, 0, 1.0], [0, -1.0, 0]])     # rig (right, fwd, up) -> Roblox (X, Y, Z)
        Rr = M @ D @ M.T                                             # RightHand rotation in HumanoidRootPart space
        food = c + D @ np.array([0, 0, -(KNUCKLE + FOOD_R)])
        return {"hand_pos": to_roblox(c), "hand_rot_matrix": [[round(float(x), 4) + 0.0 for x in row] for row in Rr],
                "food_centre": to_roblox(food), "food_bottom_y": round(float(food[2] - FOOD_R), 3)}

    food_rest = info[GRAB_F][0] + info[GRAB_F][1] @ np.array([0, 0, -(KNUCKLE + FOOD_R)])
    grip = {"bone": "RightHand", "food_radius": FOOD_R,
            "weld_C0": f"CFrame.new(0, -(0.15 + radius), 0) on RightHand = CFrame.new(0, {-(KNUCKLE + FOOD_R)}, 0) "
                       "for the authored 0.9 food (the knuckle face points along the hand's -Y)",
            "food_rest_centre": to_roblox(food_rest),
            "grab": frame_info(GRAB_F), "lift": frame_info(LIFT_F), "hold": frame_info(HOLD_F)}
    g = grab_hand()
    D_g = info[GRAB_F][1]
    rest_hand = F.fk({}, 0.0)
    attach_pos = hand_centre(rest_hand, R) + D_g.T @ (food_rest - info[GRAB_F][0])
    food_col = [0.95, 0.55, 0.12]
    scene = [{"pos": [round(float(x), 4) for x in food_rest], "size": [2 * FOOD_R] * 3, "colour": food_col,
              "shape": "sphere", "show": [0, GRAB_F]}]
    attach = [{"bone": "RightHand", "pos": [round(float(x), 4) for x in attach_pos], "size": [2 * FOOD_R] * 3,
               "colour": food_col, "shape": "sphere", "show": [GRAB_F, PU_N + 1]}]
    del g
    return slerp_pass(clip(
        "HeroPickUp", fr(PU_N), False, "Action",
        "The villain arrives at the food and picks it up, unhurried and heavy: the lead (right) foot plants, the "
        "trailing foot steps back into a split stance, then he bends with weight (knees give, back leans, rear heel "
        "peels up, the left arm hangs heavy) while staring at the food; the right fist comes down onto the "
        "top of the food just in front of the right foot and closes on it (Grab); he rises slowly, bringing it up "
        "to shoulder height out to his right and turning his head to study it (Lift); then a confident beat: chest up, head cocked, food "
        "held steady (Hold), held.",
        "walk-to-stop, split-stance pick-up of a heavy object (hip and knee hinge, braced hand), slow rise, "
        "presenting / inspecting the object at face height; held last pose",
        keys, markers=[("Grab", fr(GRAB_F)), ("Lift", fr(LIFT_F)), ("Hold", fr(HOLD_F))], views=VIEWS,
        extra={"_arrive": {"start_from": f"HeroStalk at its RIGHT Step (TimePosition {RC_T})",
                           "root_travel": TRAV, "root_travel_time": STOP,
                           "root_easing": "Quad Out (initial speed = HeroStalk speed)"},
               "_grip": grip, "_scene": scene, "_attach": attach}))


CLIPS = {"HeroPickUp": hero_pickup}


def check(spec):
    """Numeric: food sphere clearance from every body part (boxes / limb capsules), per frame after the Grab,
    and the right hand's centre at the markers. Body parts approximated as in fkcheck."""
    import fkcheck as C
    out = []
    fps = spec["fps"]
    worst = (9.0, None)
    for f in range(PU_N + 1):
        b, root = C.sample(spec, f / fps)
        o = F.fk(b, root)
        if f < GRAB_F:
            food = FOOD_C + np.array([0, TRAV - men_d(f / fps), 0])   # the game coasts the root onto it
        else:
            food = hand_centre(o, R) + o["DhandR"] @ np.array([0, 0, -(KNUCKLE + FOOD_R)])
        gaps = {}
        for name, D, piv, ctr, half in C.body_boxes(o, b):
            q = D.T @ (food - piv) + piv - ctr
            gaps[name] = float(np.linalg.norm(np.maximum(np.abs(q) - half, 0))) - FOOD_R
        for s in (R, L):
            for a, c, nm in ((o["shoulder" + s], o["elbow" + s], "UpperArm"), (o["elbow" + s], o["wrist" + s], "LowerArm"),
                             (o["hip" + s], o["knee" + s], "UpperLeg"), (o["knee" + s], o["ankle" + s], "LowerLeg")):
                if s == R and nm == "LowerArm":
                    continue
                u = np.clip(np.dot(food - a, c - a) / np.dot(c - a, c - a), 0, 1)
                gaps[s + nm] = float(np.linalg.norm(food - (a + (c - a) * u))) - 0.5 - FOOD_R
        k = min(gaps, key=gaps.get)
        if gaps[k] < worst[0]:
            worst = (gaps[k], (f, k))
        out.append((f, k, gaps[k], food, hand_centre(o, R)))
    return out, worst


if __name__ == "__main__":
    import json
    import sys
    p = sys.argv[1] if len(sys.argv) > 1 else None
    s = json.load(open(p)) if p else hero_pickup()
    rows, worst = check(s)
    print("right-hand path misses (frame, studs short):", MISSES)
    for f, k, g, food, hc in rows:
        if f % 3 == 0 or f in (GRAB_F, LIFT_F, HOLD_F):
            print(f"f{f:02d} food {np.round(food, 2)} hand {np.round(hc, 2)} nearest {k} gap {g:+.2f}")
    print("worst food gap", worst)
