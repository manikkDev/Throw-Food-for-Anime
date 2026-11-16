"""Batch r6 (2026-11-16): the SHOULDER carry, replacing the overhead CarryHold in the game.

  CarryShoulder  player, Action, 1.6 s loop, UPPER BODY ONLY (UpperTorso, Head, right arm): a caught hero sits on
                 the player's RIGHT shoulder; the right hand braces the hero's right foot, chest a touch forward
  CarriedRide    hero (scale 0.55 in game), Action, 1.6 s loop, full body: seated on the carrier's right
                 shoulder, left hand on the carrier's head, right arm waving, a small bounce in the hips
  PlaceHero      player, Action, 1.3 s (v2, replaces r3's): the hero hops off the shoulder into both hands,
                 is lowered onto the pedestal in front (Place), release, fist pump

WHY ONE SHOULDER (measured, duo.py on the rig's real part sizes): a standard R15 block head is a 1.2 stud cube
and the hero at 0.55 has its hip joints at +-0.275 and a whole leg under 1 stud long, so its thighs cannot
pass on either side of the head; every centred placement puts a leg 0.15+ studs into the head (the best one
has the hero sitting ON the head). The hero sits on the right shoulder strip beside the head instead, legs
hanging in front of the right side of the chest. Block arms are 1 stud thick and the hero's shins hang only
~0.3-0.6 in front of the chest, so the carrier cannot wrap its hands round them without the forearms going
through the hero or its own chest: the right hand braces the hero's right foot from below, the left arm is
left to the default walk / idle (unkeyed).

Placement: the hero's HumanoidRootPart is held at RIDE (hero rig origin in carrier rig space, unrotated).
Every check here is numeric (duo.py boxes); duo_blender.py renders the two real rigs together and measures the
same clashes on the real meshes.
"""
import math

import numpy as np

import duo
import fkmodel as F
from animlib import SHORT, clip, pose
from clips_r3 import FEET0, PEDESTAL_TOP, both_hands, hand_centre, solve_hand, to_roblox
from clips_train import fr, lock_feet, planted, slerp_pass

S = duo.HERO_S
R, L = "R", "L"
RIDE_F = 48                       # 1.6 s loop, both clips
RIDE_KEYS = [0, 12, 24, 36, 48]
SEAT_GAP = 0.02                   # thigh bottoms this far above the shoulder top at the lowest point

# ------------------------------------------------------------------------------------------ the hero
HERO_X = 1.25                     # hero LowerTorso centre x (rig): its left side clears the head (0.6) by ~0.1
HERO_Y = 0.34                     # forward: its shins hang in front of the chest
BOUNCE = [0.0, 0.07, 0.0, 0.07, 0.0]   # hero ROOT z per key (hero rig units, x0.55 in game)
HERO_LEGS = {"ulr": [-86, 0, 0], "ull": [-86, 0, 0], "llr": [52, 0, 0], "lll": [58, 0, 0],
             "fr": [28, 0, 0], "fl": [24, 0, 0]}
HERO_UP = [[-2, 4, 2], [-4, 2, 2.5], [-2, -2, 2], [-4, 0, 2.5], [-2, 4, 2]]   # Z + = lean to its left (the head)
HERO_HEAD = [[-4, -10, 3], [-2, -4, 2], [-4, 6, 3], [-2, -2, 2], [-4, -10, 3]]
# right arm cheering up and forward, waving out / in
WAVE_OUT = {"uar": [-140, 42, 0], "lar": [-35, 0, 0], "har": [-15, 0, 0]}   # raised arm: Y + swings it out
WAVE_IN = {"uar": [-152, 14, 0], "lar": [-18, 0, 0], "har": [12, 0, 0]}
HERO_WAVE = [WAVE_OUT, WAVE_IN, WAVE_OUT, WAVE_IN, WAVE_OUT]

# ---------------------------------------------------------------------------------------- the carrier
CAR_UP = [[-5, 0, 0], [-6.5, 0, 0], [-5, 0, 0], [-6.5, 0, 0], [-5, 0, 0]]     # forward lean, breathing settle
CAR_HEAD = [[-6, 2, 4], [-7, 0, 4], [-6, -2, 4], [-7, 0, 4], [-6, 2, 4]]   # Z + = tilt left, away from the hero
FOOT_HOLD = np.array([0.0, 0.05, -0.02])   # right hand centre offset from under the hero's right sole
CAR_FORE = [0.0, 0.75, 0.66]               # right forearm forward and up (elbow low and back)


def hero_bones(i):
    b = dict(HERO_LEGS)
    b.update(up=HERO_UP[i], head=HERO_HEAD[i], **HERO_WAVE[i])
    return b


def carrier_bones(i):
    return {"up": CAR_UP[i], "head": CAR_HEAD[i]}


def hero_boxes(bones, root_z, T, Rm=None):
    return duo.boxes(bones, root_z, T=T, R=Rm, s=S)


BODY = [p for p in duo.PARTS if "Arm" not in p and "Hand" not in p]


def seat_height():
    """lowest hero origin z (over every key) at which the hero's body clears the carrier's torso + head + right
    arm at rest, plus SEAT_GAP: the hero then sits ON the shoulder."""
    def clear(z):
        for i in range(len(RIDE_KEYS)):
            H = hero_boxes(hero_bones(i), BOUNCE[i], [HERO_X, HERO_Y, z])
            C = duo.boxes(carrier_bones(i))
            for hp in BODY:
                for cp in ("UpperTorso", "Head", "RightUpperArm"):
                    if duo.depth(H[hp], C[cp]) > 1e-4:
                        return False
        return True
    lo, hi = 0.5, 3.5
    for _ in range(40):
        mid = (lo + hi) / 2
        lo, hi = (lo, mid) if clear(mid) else (mid, hi)
    return hi + SEAT_GAP


def ride_T():
    return np.array([HERO_X, HERO_Y, round(seat_height(), 4)])


def clear_arm(side, bones, root, target, solids, guess, w_target=2.0, fore=None, w_fore=0.0, self_body=True,
              place=None, tag="", parts=None):
    """FK {ua, la, ha} for `side`, CLASH FIRST: every penetration of this arm's three parts into `solids` (a
    function bones -> {name: box} of the obstacles, the other rig included) and into its own body is driven to 0,
    then the hand centre is pulled toward `target` with a soft weight (it may stop short when the target is not
    reachable without a clash, and the report says how far). place(bones) -> {part: box} of this rig (default:
    carrier at scale 1). With a guess, only the guess seeds (no branch flips between keys)."""
    from scipy.optimize import least_squares
    sf = side.lower()
    nm = "Right" if side == R else "Left"
    mine = (nm + "UpperArm", nm + "LowerArm", nm + "Hand")
    hit = tuple(nm + p for p in parts) if parts else mine     # the parts kept OUT of the obstacles
    place = place or (lambda b: duo.boxes(b, root))

    def pose_of(v):
        return {**bones, "ua" + sf: list(v[0:3]), "la" + sf: [v[3], 0, 0], "ha" + sf: [v[4], 0, v[5]]}

    def res(v):
        b = pose_of(v)
        P = place(b)
        O = solids(b)
        r = [duo.depth(P[a], O[k]) * 40 for a in hit for k in O]
        if self_body:
            r += [duo.depth(P[a], P[t]) * 40 for a in mine[1:] for t in ("UpperTorso", "Head", "LowerTorso")]
            r += [duo.depth(P[nm + "Hand"], P[nm + "UpperArm"]) * 40]
        o = F.fk(b, root)
        r += list((hand_centre(o, side) - np.asarray(target)) * w_target)
        if fore is not None:
            r += list((o["Dfore" + side] @ np.array([0, 0, -1.0]) - np.asarray(fore) / np.linalg.norm(fore)) * w_fore)
        r += [v[1] * 0.005, v[4] * 0.005, v[5] * 0.005]
        if guess is not None:
            r += list((np.asarray(v) - np.asarray(guess)) * 0.02)
        return r

    lo, hi = F.ARM_LO + [-70, -70], F.ARM_HI + [70, 70]
    seeds = [guess] if guess is not None else [[-20, 0, 5, -90, -30, 0], [-10, 0, 10, -60, 0, 0], [0, 0, 15, -30, 0, 0],
                                               [-40, 0, 20, -70, 0, 0], [10, 0, 5, -100, 0, 0],
                                               [-150, 0, 0, -20, 0, 0], [-120, 40, 30, -60, 0, 0],
                                               [-160, -30, -20, -40, 0, 0], [-100, 60, 60, -90, 0, 0]]
    best = None
    for x0 in seeds:
        x0 = np.clip(np.asarray(x0, float), np.array(lo) + 1e-6, np.array(hi) - 1e-6)
        sol = least_squares(res, x0, bounds=(lo, hi), diff_step=1e-3)
        if best is None or sol.cost < best.cost - 1e-9:
            best = sol
    v = best.x
    b = pose_of(v)
    P, O = place(b), solids(b)
    worst = max([duo.depth(P[a], O[k]) for a in hit for k in O] + [0.0])
    miss = float(np.linalg.norm(hand_centre(F.fk(b, root), side) - np.asarray(target)))
    out = {"ua" + sf: [round(float(a), 2) for a in v[0:3]], "la" + sf: [round(float(v[3]), 2), 0, 0],
           "ha" + sf: [round(float(v[4]), 2), 0, round(float(v[5]), 2)]}
    return out, [float(a) for a in v], worst, miss


def hero_body(H):
    return {k: H[k] for k in BODY}


def head_drape_target(i, T):
    """hero LEFT hand palm-down on the top of the carrier's head, right of centre (a draped forearm does not fit:
    the hero's shoulder is only ~0.2 above the head top and its arm is 0.55 thick). Returns
    the target hand centre in HERO rig space and the carrier's head box."""
    c, A, h = duo.boxes(carrier_bones(i))["Head"]
    p = c + A @ np.array([0.2, 0.0, h[2] + 0.15 * S - 0.08])     # palm down on the top, right of centre
    return (p - T) / S - np.array([0, 0, BOUNCE[i]])


def hero_pose(i, T, guess=None):
    b = hero_bones(i)
    Ch = duo.boxes(carrier_bones(i))["Head"]
    root = BOUNCE[i]
    kl, g, worst, miss = clear_arm(L, b, root, head_drape_target(i, T), lambda bb: {"CarrierHead": Ch}, guess,
                                   w_target=8.0, fore=[-0.8, 0.0, -0.6], w_fore=0.5,
                                   place=lambda bb: hero_boxes(bb, root, T), tag=f"hero {i}",
                                   parts=("UpperArm", "LowerArm", "Hand"))
    b.update(kl)
    return b, g, worst, miss


def carrier_pose(i, T, hb, guess=None):
    """carrier upper body: right upper arm hanging, forearm level and forward under the hero's feet (a footrest:
    its top edge meets the hero's right sole). Solved clash-first against the hero's body."""
    cb = carrier_bones(i)
    H = hero_boxes(hb, BOUNCE[i], T)
    c = H["RightFoot"][0]
    sole = min(p[2] for p in duo.corners(H["RightFoot"]))
    tgt = np.array([c[0], c[1], sole - 0.5])          # hand centre half a hand below the sole: its edge on the sole
    kr, g, worst, miss = clear_arm(R, cb, 0.0, tgt, lambda bb: hero_body(H), guess, w_target=2.0,
                                   fore=[0, 1.0, 0.0], w_fore=0.5, tag=f"carrier {i}")
    cb.update(kr)
    return cb, g, worst, miss


def ride_poses(verbose=False):
    T = ride_T()
    hg = cg = None
    hero, car = [], []
    for i in range(len(RIDE_KEYS)):
        if i == len(RIDE_KEYS) - 1:          # loop seam: the last key IS the first one
            hero.append(dict(hero[0]))
            car.append(dict(car[0]))
            continue
        hb, hg, hw, hm = hero_pose(i, T, hg)
        cb, cg, cw, cm = carrier_pose(i, T, hb, cg)
        hero.append(hb)
        car.append(cb)
        if verbose:
            print(f"  key {i}: hero L arm clash {hw:.3f} miss {hm:.3f} | carrier R arm clash {cw:.3f} miss {cm:.3f}")
    return T, hero, car


CARRY_JOINTS = ["UpperTorso", "Head", "RightUpperArm", "RightLowerArm", "RightHand"]
CARRY_BONES = {"UpTorso", "HEAD", "FK_UpperArm.R", "FK_LowerArm.R", "FK_Hand.R"}
VIEWS = {"front": [0.25, 1.0, 0.18], "side": [1.0, 0.1, 0.12], "chase": [-0.3, -1.0, 0.6]}
_CACHE = {}


def _fingerprint():
    import hashlib
    import inspect
    src = inspect.getsource(__import__(__name__))
    return hashlib.sha1(src.split("_CACHE = {}")[0].encode()).hexdigest()[:12]


def ride():
    """solved ride poses, cached on disk (work/anim/upload6/ride_poses.json) keyed by this module's source above
    the cache: any change to the parameters or solvers re-solves (~75 s)."""
    import json
    import os
    if "ride" in _CACHE:
        return _CACHE["ride"]
    p = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
                     "work", "anim", "upload6", "ride_poses.json")
    fp = _fingerprint()
    if os.path.exists(p):
        d = json.load(open(p))
        if d.get("fp") == fp:
            _CACHE["ride"] = (np.array(d["T"]), d["hero"], d["car"])
            return _CACHE["ride"]
    T, hero, car = ride_poses()
    os.makedirs(os.path.dirname(p), exist_ok=True)
    json.dump({"fp": fp, "T": [float(x) for x in T], "hero": hero, "car": car}, open(p, "w"), indent=1)
    _CACHE["ride"] = (T, hero, car)
    return _CACHE["ride"]


def carried_ride():
    T, hero, car = ride()
    keys = []
    notes = ["seated on the right shoulder, waving out", "bounce up, wave in", "settle, wave out", "bounce up, wave in",
             "loop"]
    for i, f in enumerate(RIDE_KEYS):
        b = pose(root=BOUNCE[i], **hero[i])
        b["ROOT"] = {"loc": F.root_loc(BOUNCE[i])}
        keys.append((fr(f), "smooth", notes[i], b))
    return clip("CarriedRide", fr(RIDE_F), True, "Action",
                "A small hero riding on the carrier's RIGHT shoulder: seated, hips flexed ~86 deg, thighs forward over "
                "the shoulder beside the head, knees bent so the shins hang in front of the right side of the chest, "
                "the right foot resting on the carrier's forearm; torso upright with a slight lean in toward the "
                "carrier's head, left forearm draped over the top of the carrier's head, right arm raised forward-up "
                "and waving out and in; a small bounce in the hips twice a loop.",
                "child sitting on a parent's shoulder at a parade, arm over the parent's head, waving",
                keys, views={"front": [0.25, 1.0, 0.15], "side": [1.0, 0.1, 0.1]},
                extra={"_ride": {"hero_origin_rig": [round(float(x), 4) for x in T], "scale": S}})


def carry_shoulder():
    T, hero, car = ride()
    keys = []
    notes = ["hero on the right shoulder, forearm under its feet", "breath out: chest settles forward", "breath in",
             "settle", "loop"]
    for i, f in enumerate(RIDE_KEYS):
        b = pose(**car[i])
        keys.append((fr(f), "smooth", notes[i], {k: v for k, v in b.items() if k in CARRY_BONES}))
    return clip("CarryShoulder", fr(RIDE_F), True, "Action",
                "Carry a small hero sitting on the RIGHT shoulder: chest a touch forward under the weight, head forward "
                "and tilted a little away from the hero, right upper arm hanging with the elbow bent 90 deg and the "
                "forearm level and forward under the hero's feet (a footrest); a gentle breathing settle twice a loop. "
                "Upper body only (UpperTorso, Head, right arm): the default walk / idle keep the legs AND the left arm.",
                "parent walking with a child on one shoulder, a forearm held under the child's feet",
                keys, views=VIEWS, extra={"pose_only": CARRY_JOINTS})


# ------------------------------------------------------------------------------------------ PlaceHero v2
PLACE_N = 39                      # 1.3 s
HOP_F, GRAB_F, PLACE_F = 6, 13, 24
LT_REST = np.array([0.0, 0.0, -0.8])            # LowerTorso centre in rig space at rest (hero units)
HERO_FEET = 2.2 * S                             # standing hero: LowerTorso centre -> soles
CATCH_LT = np.array([0.0, 1.10, 0.95])          # hero LowerTorso centre when the hands catch it (rig)
PED_LT = np.array([0.0, 1.85, PEDESTAL_TOP + HERO_FEET])   # ... when its soles touch the pedestal top
GRIP_X = 1.1 + 0.58                             # hand centre off the hero's centre line: outside its arms
CHEST = 0.62                                    # ... at its chest: hands are this far above its LowerTorso centre
HANG_L = {"ual": [2, 0, -4], "lal": [-12, 0, 0], "hal": [0, 0, 0]}


def _ease(u):
    return u * u * (3 - 2 * u)


def place_hero():
    T, hero, car = ride()
    g = {}

    def P(root, tor, up, head, arms):
        return planted(FEET0, root, tor, "place6", up=up, head=head, **arms)

    def grip(lt, tor, up, root, fore):
        return both_hands([GRIP_X, lt[1], lt[2] + CHEST], tor, up, root, fore, g)

    c0 = car[0]
    r0 = {k: c0[k] for k in ("uar", "lar", "har")}
    k0 = P(-0.02, [0, 0, 0], c0["up"], c0["head"], {**r0, **HANG_L})
    k1 = P(-0.28, [-3, 0, 0], [-9, 0, 0], [-2, 0, 4],
           {"uar": [-22, 0, 4], "lar": [-112, 0, 0], "har": [-10, 0, 0],       # forearm boosts the feet up
            "ual": [-35, 0, -12], "lal": [-55, 0, 0], "hal": [0, 0, 0]})
    k1b = P(-0.12, [0, 0, 0], [0, 0, 0], [10, 0, 0],
            both_hands([1.8, 1.0, 1.15], [0, 0, 0], [0, 0, 0], -0.12, [0.25, 0.45, 0.86], g))   # wide, ready to catch
    U2 = [2, 0, 0]
    k2 = P(-0.08, [0, 0, 0], U2, [12, 0, 0], grip(CATCH_LT, [0, 0, 0], U2, -0.08, [0.1, 0.65, 0.75]))
    T3, U3 = [-6, 0, 0], [-12, 0, 0]
    k3 = P(-0.7, T3, U3, [4, 0, 0], grip(PED_LT, T3, U3, -0.7, [0.1, 0.95, -0.3]))
    U4 = [-11, 0, 0]
    k4 = P(-0.71, T3, U4, [3, 0, 0], grip(PED_LT, T3, U4, -0.71, [0.1, 0.95, -0.3]))
    T5, U5 = [-6, 0, 0], [-12, 0, 0]
    k5 = P(-0.4, T5, U5, [10, 0, 0], both_hands([1.6, 1.2, -0.3], T5, U5, -0.4, [0.3, 0.7, -0.5], g))
    k6 = P(-0.06, [0, 6, 0], [4, 8, -4], [-6, -10, 0],
           {"uar": [8, 0, 160], "lar": [-14, 0, 0], "har": [-25, 0, 0],
            "ual": [12, 0, -22], "lal": [-40, 0, 0], "hal": [-20, 0, 0]})
    k7 = P(-0.2, [-3, 10, 0], [-8, 12, 0], [8, -8, 0],
           {"uar": [26, 0, 18], "lar": [-118, 0, 0], "har": [-25, 0, 0],
            "ual": [16, 0, -16], "lal": [-90, 0, 0], "hal": [-20, 0, 0]})
    k8 = P(-0.04, [0, 3, 0], [-2, 3, 0], [3, -3, 0],
           {"uar": [6, 0, 8], "lar": [-40, 0, 0], "har": [-10, 0, 0],
            "ual": [2, 0, -8], "lal": [-25, 0, 0], "hal": [-5, 0, 0]})
    keys = [
        (0.0, "smooth", "CarryShoulder pose (its frame 0), left arm hanging; hero on the right shoulder", k0),
        (fr(HOP_F), "out", "HOP: knees give, the right forearm boosts the hero's feet, left hand comes up", k1),
        (fr(9), "smooth", "hands open wide and up, ready to catch", k1b),
        (fr(GRAB_F), "smooth", "GRAB: the hero has hopped forward off the shoulder; both palms on its hips in front of the face", k2),
        (fr(PLACE_F), "out", "PLACE: squat, the hero's soles touch the pedestal", k3),
        (fr(27), "smooth", "hold the touch", k4),
        (fr(30), "in", "release: hands open out and back", k5),
        (fr(34), "out", "fist punched to the sky", k6),
        (fr(37), "smooth", "YES: fist yanked down, knees dip", k7),
        (fr(PLACE_N), "smooth", "settle", k8),
    ]
    spec = slerp_pass(lock_feet(clip(
        "PlaceHero", fr(PLACE_N), False, "Action",
        "v2, from the SHOULDER carry: a little dip while the right forearm boosts the hero's feet, the hero hops "
        "forward off the shoulder and both hands catch it by the hips in front of the face, squat and set it "
        "standing on the pedestal in front (Place), hold, open the hands, right-fist pump to the sky and yank it "
        "down. Feet planted.",
        "lifting a child down off your shoulder onto a table in front, then a fist pump; 1.3 s",
        keys, markers=[("Hop", fr(HOP_F)), ("Grab", fr(GRAB_F)), ("Place", fr(PLACE_F))], views=VIEWS,
        extra={"_scene": [{"pos": [0.0, float(PED_LT[1]), (PEDESTAL_TOP + F.FLOOR) / 2],
                           "size": [1.6, 1.6, PEDESTAL_TOP - F.FLOOR], "colour": [0.6, 0.6, 0.62]}]})))
    return spec


def hands_mid(bones, root):
    o = F.fk(bones, root)
    return (hand_centre(o, R) + hand_centre(o, L)) / 2


def place_path(spec=None):
    """per clip frame 0..Place: the hero's placement. origin_rig = hero HumanoidRootPart (rest) centre in carrier rig
    space; lowertorso_rig its LowerTorso centre; pose = which hero pose the game should show."""
    import fkcheck as C
    import json
    import os
    if spec is None:
        spec = json.load(open(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
                                           "assets", "animations", "specs", "PlaceHero.json")))
    T, hero, car = ride()
    seat_lt = T + S * LT_REST                   # ride: LowerTorso centre (no bounce)
    hop_lt = seat_lt + np.array([-0.05, 0.62, 0.22])   # forward first: off the front of the shoulder, past the face
    bb, rt = C.sample(spec, fr(GRAB_F))
    grab_lt = hands_mid(bb, rt) - np.array([0, 0, CHEST])
    via = np.array([0.55, 1.45, 1.75])          # then across in front of the face, above the rising hands
    frames = []
    for f in range(PLACE_N + 1):
        t = fr(f)
        if f <= HOP_F:
            u = _ease(f / HOP_F)
            lt = seat_lt + (hop_lt - seat_lt) * u
            pose_name, rf = "CarriedRide", f
        elif f < GRAB_F:                        # in flight, still seated (legs forward): stops CarriedRide at Grab
            u = _ease((f - HOP_F) / (GRAB_F - HOP_F))
            lt = (1 - u) ** 2 * hop_lt + 2 * u * (1 - u) * via + u * u * grab_lt
            pose_name, rf = "CarriedRide", f
        elif f <= PLACE_F:
            bb, rt = C.sample(spec, t)
            lt = hands_mid(bb, rt) - np.array([0, 0, CHEST])
            pose_name, rf = "stand", 0
        else:                                   # released: it stays standing on the pedestal
            lt = np.array(frames[PLACE_F]["lowertorso_rig"])
            pose_name, rf = "stand", 0
        origin = lt - S * LT_REST
        frames.append({"frame": f, "t": t, "pose": pose_name, "ride_frame": rf, "yaw": 0.0, "pitch": 0.0,
                       "lowertorso_rig": [round(float(x), 4) for x in lt], "origin_rig": [round(float(x), 4) for x in origin]})
        if f == PLACE_F:
            frames[-1]["soles_rig_z"] = round(float(lt[2] - HERO_FEET), 4)
    return {"frames": frames}


def stand_spec_path():
    import json
    import os
    p = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
                     "work", "anim", "upload6", "duo", "HeroStand.json")
    if not os.path.exists(p):
        b = pose()
        json.dump(clip("HeroStand", fr(1), False, "Action", "rest pose (render helper)", "",
                       [(0.0, "smooth", "stand", b), (fr(1), "smooth", "stand", b)]), open(p, "w"))
    return p


def report():
    T, hero, car = ride_poses(True)
    H0 = hero_boxes(hero[0], 0.0, T)
    print("RIDE T (hero origin, rig)", np.round(T, 4), "seat (thigh bottoms)",
          round(min(min(p[2] for p in duo.corners(H0[k])) for k in ("RightUpperLeg", "LeftUpperLeg")), 3),
          "hero LT centre", np.round(H0["LowerTorso"][0], 3))
    for i, f in enumerate(RIDE_KEYS):
        H = hero_boxes(hero[i], BOUNCE[i], T)
        C = duo.boxes(car[i])
        cl = duo.clashes(H, C)
        hs = duo.clashes(H, H, self_=True)
        cs = duo.clashes(C, C, self_=True)
        print(f"key f{f}: hero x carrier {[(round(d, 3), b, 'hero ' + a) for d, a, b in cl[:5]]}")
        print(f"        hero self {[(round(d, 3), a, b) for d, a, b in hs[:3]]}  carrier self "
              f"{[(round(d, 3), a, b) for d, a, b in cs[:3]]}")
        print(f"        carrier R arm {car[i]['uar']} {car[i]['lar']} {car[i]['har']}; hero L arm {hero[i]['ual']} "
              f"{hero[i]['lal']} {hero[i]['hal']}")


CLIPS = {"CarryShoulder": carry_shoulder, "CarriedRide": carried_ride, "PlaceHero": place_hero}

P_RBX = np.array([[1.0, 0, 0], [0, 0, 1.0], [0, -1.0, 0]])     # rig (right, fwd, up) -> Roblox (X, Y, Z back)


def rbx(v):
    return [round(float(x), 4) + 0.0 for x in P_RBX @ np.asarray(v, float)]


def outputs():
    """work/anim/upload6/ride.json (the seat) + placehero_path.json (the hero path), Roblox HRP space."""
    import json
    import os
    out = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
                       "work", "anim", "upload6")
    T, hero, car = ride()
    lt = T + S * LT_REST
    # the same seat relative to the carrier's UpperTorso at CarryShoulder frame 0 (UpperTorso pose up = CAR_UP[0])
    Du = F.fk({"up": car[0]["up"]}, 0.0)["D_up"]
    ut_c = F.PIVOT + Du @ (np.array([0, 0, 0.2]) - F.PIVOT)
    lt_in_ut = Du.T @ (lt - ut_c)
    rot_ut = P_RBX @ Du.T @ P_RBX.T
    ride_d = {
        "hero_scale": S, "loop_seconds": fr(RIDE_F), "keys_seconds": [fr(f) for f in RIDE_KEYS],
        "seat_lowertorso_in_carrier_hrp": {"position": rbx(lt), "rotation": "identity (faces the carrier's facing)",
                                           "cframe": "CFrame.new(%.4f, %.4f, %.4f)" % tuple(rbx(lt))},
        "seat_hrp_in_carrier_hrp": {"position": rbx(T), "cframe": "CFrame.new(%.4f, %.4f, %.4f)" % tuple(rbx(T)),
                                    "note": "hero HumanoidRootPart centre = LowerTorso centre + (0, 0.8 * 0.55, 0)"},
        "seat_lowertorso_in_carrier_uppertorso": {
            "position": rbx(lt_in_ut), "rotation_matrix_rows": [[round(float(x), 5) for x in r] for r in rot_ut],
            "note": "the same seat relative to the carrier's UpperTorso at CarryShoulder frame 0 (UpperTorso pitched "
                    f"{car[0]['up'][0]} deg); weld here and the hero follows the walk's bob too"},
        "bounce": "CarriedRide moves the hero's LowerTorso up 0.07 (x0.55 = 0.0385 studs) at 0.4 s and 1.2 s",
    }
    json.dump(ride_d, open(os.path.join(out, "ride.json"), "w"), indent=1)
    path = place_path()
    marks = {HOP_F: "Hop", GRAB_F: "Grab", PLACE_F: "Place"}
    rows = []
    for smp in path["frames"]:
        f = smp["frame"]
        rows.append({"frame": f, "t": smp["t"], "marker": marks.get(f, ""),
                     "hero_pose": "CarriedRide" if smp["pose"] == "CarriedRide" else "standing (CarriedRide stopped)",
                     "lowertorso": rbx(smp["lowertorso_rig"]), "hrp": rbx(smp["origin_rig"]),
                     "yaw_deg": smp["yaw"], "pitch_deg": smp["pitch"], "after_place": f > PLACE_F})
    json.dump({"space": "carrier HumanoidRootPart (X right, Y up, -Z forward), standard R15 scale 1, hero scale 0.55",
               "fps": 30, "markers": {"Hop": fr(HOP_F), "Grab": fr(GRAB_F), "Place": fr(PLACE_F)},
               "length": fr(PLACE_N), "pedestal": {"top_y": PEDESTAL_TOP, "centre_ahead": float(PED_LT[1])},
               "frames": rows}, open(os.path.join(out, "placehero_path.json"), "w"), indent=1)
    print(json.dumps(ride_d, indent=1))
    print("Place frame:", rows[PLACE_F])


if __name__ == "__main__":
    import sys
    if sys.argv[1:] == ["outputs"]:
        outputs()
    else:
        report()
