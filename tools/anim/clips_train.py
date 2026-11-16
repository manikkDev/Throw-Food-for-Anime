"""Rev 2 player clips (2026-11-15, owner review): TrainStrike, TrainPush, TrainLift.

Every contact here is SOLVED, not eyeballed: fkmodel.py (a pure-Python copy of the rig's FK, checked
against Blender to 0.01 stud) finds the FK angles that put the fists / palms ON the target plane and the
feet flat on the floor, and the result is written as plain FK rotations. The main thread snaps the
player to a stand point so the target's front face is exactly `contact_distance` studs in front of the
HumanoidRootPart along its facing (rig +Y = Roblox LookVector).
"""
import numpy as np

import fkcheck as C
import fkmodel as F
from animlib import SHORT, clip, pose

R, L = "R", "L"
_LEG_GUESS = {}


def fr(n):
    """Time of frame n at 30 fps. Keys and markers sit ON frames, so the render, the numeric checks
    and the in-game marker all describe the same instant."""
    return round(n / 30.0, 4)


def feet(spec, root, tor, tag=""):
    """spec: {"R": (x, y, yaw, heel), ...} -> legs dict for pose(); ankles planted on the floor."""
    out = {}
    for side, (x, y, yaw, heel) in spec.items():
        key = (tag, side)
        lg, err, raw = F.solve_leg(side, (x, y), root, tor, yaw=yaw, heel=heel, guess=_LEG_GUESS.get(key))
        if err > 0.01:
            raise ValueError(f"{tag} leg {side}: ankle misses its plant by {err:.3f}")
        _LEG_GUESS[key] = raw
        out[side] = lg
    return out


def planted(legs_spec, root, tor, tag, **kw):
    """pose() with planted legs; remembers the plant so lock_feet() can hold it between keys."""
    b = pose(legs=feet(legs_spec, root, tor, tag=tag), tor=tor, **kw)
    b["ROOT"] = {"loc": F.root_loc(root)}
    b["__feet"] = {s: list(v) for s, v in legs_spec.items()}
    return b


def lock_feet(spec, tol=0.02, hands=None):
    """FOOT LOCK. FK keys put each planted ankle exactly on its mark, but the Euler lerp between two keys
    lets it drift (a knee that straightens while the hips rise slides the foot / dips it through the
    floor). For every segment where a foot keeps the same plant at both ends and drifts more than `tol`,
    bake one key per frame across that segment: every bone sampled exactly as the renderer would, then
    that leg re-solved onto its plant. Linear between frame keys, so the eased timing is unchanged.
    hands(bones, root) -> {short arm name: euler}: when given (palms pinned to a surface), EVERY segment is
    baked per frame and the arms are re-solved onto their contact too."""
    keys = spec["keyframes"]
    plants = [k["bones"].pop("__feet", None) for k in keys]
    fps = spec["fps"]
    out = []
    for i, (a, b) in enumerate(zip(keys, keys[1:])):
        out.append(a)
        pa, pb = plants[i] or {}, plants[i + 1] or {}
        # a foot that stays on the same spot (it may pivot: yaw / heel change) is held there
        sides = [s for s in pa if s in pb and np.allclose(pa[s][:2], pb[s][:2], atol=0.011)]
        ease = C.EASE[a.get("ease", "smooth")]

        def plant_at(s, f):
            u = ease((f - f0) / float(f1 - f0))
            return [pa[s][0], pa[s][1], pa[s][2] + (pb[s][2] - pa[s][2]) * u, pa[s][3] + (pb[s][3] - pa[s][3]) * u]
        f0, f1 = int(round(a["t"] * fps)), int(round(b["t"] * fps))
        if (not sides and hands is None) or f1 - f0 < 2:
            continue
        worst = 0.0
        for f in range(f0 + 1, f1):
            bb, root = C.sample({"keyframes": keys}, f / fps)
            o = F.fk(bb, root)
            for s in sides:
                x, y, yaw, heel = plant_at(s, f)
                h = np.radians(heel)
                want = np.array([x, y, F.FLOOR + 0.5 * np.sin(abs(h)) + 0.252 * np.cos(h)])
                worst = max(worst, float(np.linalg.norm(o["ankle" + s] - want)))
        if worst <= tol and hands is None:
            continue
        a["ease"] = "linear"
        for f in range(f0 + 1, f1):
            t = f / fps
            bb, root = C.sample({"keyframes": keys}, t)
            legs = feet({s: plant_at(s, f) for s in sides}, root, bb["tor"], tag=f"lock{s}")
            bones = {SHORT[k]: {"rot": [round(float(x), 2) for x in v]} for k, v in bb.items()}
            for s, lg in legs.items():
                sf = s.lower()
                bones[SHORT["ul" + sf]]["rot"], bones[SHORT["ll" + sf]]["rot"], bones[SHORT["f" + sf]]["rot"] =                     lg["ul"], lg["ll"], lg["f"]
            if hands is not None:
                for k, v in hands(bb, root).items():
                    bones[SHORT[k]]["rot"] = [round(float(x), 2) for x in v]
            bones["ROOT"] = {"loc": F.root_loc(root)}
            out.append({"t": round(t, 4), "ease": "linear", "_note": f"foot lock ({worst:.2f} drift)", "bones": bones})
    out.append(keys[-1])
    spec["keyframes"] = out
    return spec


def _euler_near(rot, ref):
    """Euler XYZ (deg) of `rot`, picking the equivalent triple (and 360 wraps) closest to `ref`."""
    e = rot.as_euler("xyz", degrees=True)
    cands = [e, np.array([e[0] + 180, 180 - e[1], e[2] + 180])]
    best = None
    for c in cands:
        c = np.array([ref[i] + ((c[i] - ref[i] + 180) % 360 - 180) for i in range(3)])
        if best is None or np.abs(c - ref).sum() < np.abs(best - ref).sum():
            best = c
    return best


def slerp_pass(spec, tol=6.0):
    """MATCH THE GAME'S PATH. Roblox slerps each joint between keyframes; Blender lerps the Euler angles
    (traps.md #37), so a big swing (release -> follow-through) can take a different route in game than
    on the sheet. For every segment whose midpoint differs by more than `tol` degrees on any joint, key
    every frame of it on the SLERP path (Euler chosen continuous with the lerp), linear between frames:
    the render then shows the in-game motion and both agree to a frame."""
    from scipy.spatial.transform import Rotation as Rot
    from scipy.spatial.transform import Slerp
    keys, fps = spec["keyframes"], spec["fps"]
    # same rotation, nearest Euler triple to the previous key: the solver can return an equivalent
    # triple far away in angle space (X -167 for X +13...), which is harmless at the key but makes
    # Blender's Euler lerp spin the long way round between keys
    # (a looped clip keeps its last key byte-identical to the first: the seam is asserted)
    out = []
    for i, (a, b) in enumerate(zip(keys, keys[1:])):
        out.append(a)
        if not (spec.get("loop") and i == len(keys) - 2):
            for n, v in b["bones"].items():
                if n != "ROOT" and "rot" in v:
                    v["rot"] = [round(float(x), 2) for x in
                                _euler_near(Rot.from_euler("xyz", v["rot"], degrees=True), np.array(a["bones"][n]["rot"]))]
        f0, f1 = int(round(a["t"] * fps)), int(round(b["t"] * fps))
        if f1 - f0 < 2:
            continue
        ease = C.EASE[a.get("ease", "smooth")]
        rots = [n for n in a["bones"] if n != "ROOT" and "rot" in a["bones"][n]]
        sl = {n: Slerp([0, 1], Rot.from_euler("xyz", [a["bones"][n]["rot"], b["bones"][n]["rot"]], degrees=True))
              for n in rots}
        worst = 0.0
        for n in rots:
            lerp = Rot.from_euler("xyz", (np.array(a["bones"][n]["rot"]) + np.array(b["bones"][n]["rot"])) / 2,
                                  degrees=True)
            worst = max(worst, float(np.degrees((sl[n]([0.5])[0] * lerp.inv()).magnitude())))
        if worst <= tol:
            continue
        a["ease"] = "linear"
        prev = {n: np.array(a["bones"][n]["rot"], float) for n in rots}
        for f in range(f0 + 1, f1):
            u = ease((f - f0) / float(f1 - f0))
            bones = {}
            for n in rots:
                e = _euler_near(sl[n]([u])[0], prev[n])       # continuous with the previous FRAME
                prev[n] = e
                bones[n] = {"rot": [round(float(x), 2) for x in e]}
            la, lb = np.array(a["bones"]["ROOT"]["loc"]), np.array(b["bones"]["ROOT"]["loc"])
            bones["ROOT"] = {"loc": [round(float(x), 3) for x in la + (lb - la) * u]}
            out.append({"t": round(f / fps, 4), "ease": "linear", "_note": f"slerp path ({worst:.0f} deg)", "bones": bones})
        if spec.get("loop") and i == len(keys) - 2:
            continue
        for n in rots:                                        # and the key after it continuous too
            b["bones"][n]["rot"] = [round(float(x), 2) for x in
                                    _euler_near(Rot.from_euler("xyz", b["bones"][n]["rot"], degrees=True), prev[n])]
    out.append(keys[-1])
    spec["keyframes"] = out
    return spec


def arm_kw(side, sol):
    s = side.lower()
    kw = {"ua" + s: sol["ua"], "la" + s: sol["la"]}
    if "ha" in sol:
        kw["ha" + s] = sol["ha"]
    return kw


def shoulder_centre(o, side):
    """Centre of the shoulder ball: the upper-arm bone head sits on the arm's INNER edge."""
    s = 1 if side == R else -1
    return o["shoulder" + side] + o["D_up"] @ np.array([0.5 * s, 0, -0.15])


def torso_point(tor, up, root, p):
    """A point given in the rest upper-torso frame, carried by the posed torso (guards follow the chest)."""
    o = F.fk({"tor": tor, "up": up}, root)
    piv = F.PIVOT + F.root_vec(root)
    return piv + o["D_up"] @ (np.asarray(p, float) - F.PIVOT), o["D_up"]


def held(side, p, fd, tor, up, root, hand=(0, 0, 0), avoid=12.0):
    """Arm whose fist sits at torso-relative point p with the forearm along torso-relative fd."""
    tgt, Du = torso_point(tor, up, root, p)
    return arm_kw(side, F.solve_arm(side, tgt, tor, up, fore_dir=Du @ np.array(fd, float), root=root,
                                    w_dir=3, hand=hand, avoid=avoid)[0])


# chase camera (behind, above), the character's right side, and a left-front three-quarter
VIEWS3 = {"back": [-0.3, -1.0, 0.4], "side": [1.0, 0.08, 0.1], "left34": [-1.0, 0.45, 0.25]}


# --------------------------------------------------------------------------------------------- strike
STRIKE_D = 2.5     # the plane the fists are SOLVED onto (FK model)
STRIKE_FACE = 2.47  # where to put the bag face: Blender measures the fists at 2.45-2.48 on the real meshes


def train_strike():
    # Heavy-bag combo, orthodox (left lead): JAB - CROSS - LEFT HOOK - RIGHT UPPERCUT, 2.0 s loop.
    # Mechanics: punches leave the guard and return to it; the jab is mostly arm with a small shoulder
    # turn, the cross drives the rear hip and pivots the rear foot (heel up), the hook is the torso
    # turning back the other way with the elbow at shoulder height and the arm bent ~90, the uppercut
    # dips and drives up through the legs with the forearm near vertical. Every fist lands with its
    # frontmost corner ON the plane y = STRIKE_D (solved), at head/chin height of a bag.
    D = STRIKE_D
    FEET = {L: (-0.6, 0.55, -18, 0), R: (0.62, -0.6, -38, 0)}

    def straight(side, x, z, tor, up, root):
        o = F.fk({"tor": tor, "up": up}, root)
        d = np.array([x, D, z]) - shoulder_centre(o, side)
        return F.solve_fist(side, D, x, z, tor, up, fore_dir=d / np.linalg.norm(d), root=root, w_dir=4,
                            face=(0, 1, 0), w_face=2.5, avoid=6.0)

    def recoil(side, hit, tor, up, root, back=0.45, face=(0, 1, 0)):
        """3 frames after contact: the fist snaps back along its own forearm, frontmost corner `back`
        studs off the bag face (it never sinks into the bag)."""
        sol, o, _ = hit
        d = o["Dfore" + side] @ np.array([0, 0, -1.0])
        c = o["fist" + side] - d * back
        return arm_kw(side, F.solve_fist(side, D - back, c[0], c[2], tor, up, fore_dir=d, root=root, w_dir=3,
                                         face=face, w_face=2.0, avoid=6.0)[0])

    GUARD = {L: ((-0.45, 1.3, 1.3), (0.25, 0.3, 0.92)), R: ((0.45, 1.25, 1.22), (-0.25, 0.25, 0.94))}

    def guard_arms(tor, up, root, which="LR"):
        kw = {}
        for side in which:
            kw.update(held(side, GUARD[side][0], GUARD[side][1], tor, up, root))
        return kw

    def P(root, tor, up, head, arms, ft=None):
        return planted(ft or FEET, root, tor, "strike", up=up, head=head, **arms)

    T0, U0 = [0, -14, 0], [-5, -8, 0]
    guard = P(-0.18, T0, U0, [0, 20, 0], guard_arms(T0, U0, -0.18))
    # JAB (left): small right turn, lead arm straight to the bag
    Tj, Uj = [0, -12, 0], [-8, -14, 0]
    hj = straight(L, -0.5, 0.85, Tj, Uj, -0.22)
    jab = P(-0.22, Tj, Uj, [4, 24, 0], {**arm_kw(L, hj[0]), **guard_arms(Tj, Uj, -0.22, "R")})
    jab_r = P(-0.21, Tj, Uj, [3, 24, 0], {**recoil(L, hj, Tj, Uj, -0.21), **guard_arms(Tj, Uj, -0.21, "R")})
    # load the cross: hips coil right, lead fist back to the chin
    Tl, Ul = [0, -22, 0], [-4, -14, 0]
    load_x = P(-0.2, Tl, Ul, [2, 32, 0], guard_arms(Tl, Ul, -0.2))
    # CROSS (right): rear hip drives through, rear heel up, body turns left
    Tc, Uc = [0, 8, 0], [-10, 25, 0]
    FEET_C = {L: FEET[L], R: (0.62, -0.6, -14, 26)}
    hc = straight(R, 0.45, 0.85, Tc, Uc, -0.22)
    cross = P(-0.22, Tc, Uc, [6, -14, 0], {**arm_kw(R, hc[0]), **guard_arms(Tc, Uc, -0.22, "L")}, ft=FEET_C)
    cross_r = P(-0.22, Tc, Uc, [5, -14, 0], {**recoil(R, hc, Tc, Uc, -0.22), **guard_arms(Tc, Uc, -0.22, "L")}, ft=FEET_C)
    # hook chamber: right fist home, torso still turned left, left elbow lifts out to the side
    Th, Uh = [0, 6, 0], [-6, 20, 0]
    ch_hook = P(-0.24, Th, Uh, [4, -10, 0], {**guard_arms(Th, Uh, -0.24, "R"),
                                             **held(L, (-1.55, 0.75, 0.95), (0.6, 0.75, 0.25), Th, Uh, -0.24)}, ft=FEET_C)
    # LEFT HOOK: torso whips right, elbow at shoulder height, forearm level across the front
    Tk, Uk = [0, -26, 0], [-10, -30, -6]
    FEET_K = {L: (-0.6, 0.55, -40, 16), R: FEET[R]}
    hk = F.solve_fist(L, D, 0.1, 0.85, Tk, Uk, fore_dir=(0.75, 0.65, 0), w_dir=3, root=-0.24,
                      face=(0.45, 0.9, 0), w_face=2, avoid=6.0)
    hook = P(-0.24, Tk, Uk, [6, 44, 0], {**guard_arms(Tk, Uk, -0.24, "R"), **arm_kw(L, hk[0])}, ft=FEET_K)
    hook_r = P(-0.26, Tk, Uk, [6, 44, 0], {**guard_arms(Tk, Uk, -0.26, "R"), **recoil(L, hk, Tk, Uk, -0.26, 0.5, face=(0.45, 0.9, 0))}, ft=FEET_K)
    # uppercut load: dip, right fist drops to the ribs, torso turned right
    Tu0, Uu0 = [0, -16, 0], [-8, -4, 4]
    dip = P(-0.42, Tu0, Uu0, [8, 26, 0], {**guard_arms(Tu0, Uu0, -0.42, "L"),
                                          **held(R, (0.75, 0.95, -0.25), (0, 0.55, 0.83), Tu0, Uu0, -0.42)})
    # RIGHT UPPERCUT: legs drive up, hips turn left, forearm near vertical into the chin of the bag
    Tu, Uu = [0, 12, 0], [-14, 22, -4]
    hu = F.solve_fist(R, D, 0.05, 1.0, Tu, Uu, fore_dir=(-0.1, 0.4, 0.9), w_dir=3, root=-0.12, avoid=6.0)
    upper = P(-0.12, Tu, Uu, [-4, -18, 0], {**guard_arms(Tu, Uu, -0.12, "L"), **arm_kw(R, hu[0])}, ft=FEET_C)
    upper_r = P(-0.13, Tu, Uu, [-2, -18, 0], {**guard_arms(Tu, Uu, -0.13, "L"), **recoil(R, hu, Tu, Uu, -0.13, 0.4, face=None)},
                ft=FEET_C)
    back = P(-0.2, T0, U0, [0, 20, 0], guard_arms(T0, U0, -0.2))
    Ub = [-7, -8, 0]
    bounce = P(-0.27, T0, Ub, [3, 20, 0], guard_arms(T0, Ub, -0.27))
    keys = [
        (0.00, "in", "guard, orthodox stance, weight centred", guard),
        (fr(6), "out", "HIT jab: lead arm straight, fist on the bag face", jab),
        (fr(9), "smooth", "jab snaps back off the bag", jab_r),
        (fr(12), "in", "lead fist home, hips coil right to load the cross", load_x),
        (fr(18), "out", "HIT cross: rear hip and heel drive, right arm straight", cross),
        (fr(21), "smooth", "cross snaps back", cross_r),
        (fr(24), "in", "cross home, left elbow lifts for the hook", ch_hook),
        (fr(30), "out", "HIT left hook: torso whips right, forearm level", hook),
        (fr(33), "smooth", "hook comes off the bag", hook_r),
        (fr(36), "in", "dip: knees bend, right fist drops to the ribs", dip),
        (fr(42), "out", "HIT right uppercut: legs drive up, forearm vertical", upper),
        (fr(45), "smooth", "uppercut comes off", upper_r),
        (fr(50), "smooth", "back to guard", back),
        (fr(55), "smooth", "bounce on the balls of the feet", bounce),
        (2.00, "smooth", "guard (loop)", guard),
    ]
    return slerp_pass(lock_feet(clip("TrainStrike", 2.0, True, "Action",
                "Heavy-bag combo jab-cross-hook-uppercut from an orthodox guard; every punch lands its "
                f"fist ON the bag's front face {D} studs in front of the HumanoidRootPart, the other "
                "hand guards the chin, hips and the pivoting foot drive each punch, a little bounce.",
                "boxing heavy-bag combination 1-2-3-uppercut, 2.0 s loop, hits at frames 6/18/30/42",
                keys, markers=[("Hit", fr(6)), ("Hit", fr(18)), ("Hit", fr(30)), ("Hit", fr(42))],
                views=VIEWS3,
                extra={"_contact": {"contact_distance": STRIKE_FACE, "solved_plane": D, "measured_blender": [2.481, 2.472, 2.475, 2.45], "plane": "y = contact_distance (rig +Y = facing)",
                                    "what": "frontmost corner of the striking hand box at each Hit"},
                       "_scene": [{"pos": [0, STRIKE_FACE + 0.75, 0.2], "size": [1.7, 1.5, 4.2],
                                   "colour": [0.55, 0.32, 0.2]}]})))


# ----------------------------------------------------------------------------------------------- push
PUSH_D = 2.45      # the plane the palms are SOLVED onto (FK model)
PUSH_FACE = 2.44   # where to put the boulder face: Blender measures both palms at 2.44 every frame
PUSH_X, PUSH_Z = 1.4, -0.05  # palm-face centres at x = +-PUSH_X, z = PUSH_Z (rig space, HRP-relative)


def train_push():
    # Pushing an immovable boulder: long lunge (left foot forward, right leg extended back on the ball of
    # the foot), body leaning in, both palms FLAT on the face at shoulder width and they never leave it.
    # Each surge: SINK (hips drop, chest closer to the rock, elbows bend) then DRIVE (rear leg straightens,
    # hips rise, arms lock out against the rock - with the rock not moving, the push extends the arms),
    # a strained hold with a small tremor, then settle. The palms are solved ON the plane y = PUSH_D.
    D = PUSH_D
    FEET = {L: (-0.55, 0.85, -4, 0), R: (0.55, -1.32, -8, 40)}

    last = {}

    def palms(tor, up, root):
        kw = {}
        for side, x in ((R, PUSH_X), (L, -PUSH_X)):
            o0 = F.fk({"tor": tor, "up": up}, root)
            d = np.array([x, D, PUSH_Z]) - shoulder_centre(o0, side)
            sol, _, raw = F.solve_fist(side, D, x, PUSH_Z, tor, up, fore_dir=d / np.linalg.norm(d), w_dir=1.0,
                                       root=root, face=(0, 1, 0), w_face=6, avoid=6, guess=last.get(side))
            last[side] = raw
            kw.update(arm_kw(side, sol))
            if "ha" not in sol:
                kw["ha" + side.lower()] = [0, 0, 0]
        return kw

    def P(root, tor, up, head):
        return planted(FEET, root, tor, "push", up=up, head=head, **palms(tor, up, root))

    set_ = P(-0.48, [-8, 0, 0], [-34, 0, 0], [24, 0, 0])
    sink = P(-0.68, [-10, 0, 0], [-42, 0, 0], [30, 0, 0])
    drive = P(-0.32, [-5, 0, 0], [-24, 0, 0], [16, 0, 0])
    strain_a = P(-0.35, [-5, 0, 0], [-26, 2, 3], [18, -3, 0])
    strain_b = P(-0.35, [-5, 0, 0], [-26, -2, -3], [18, 3, 0])
    keys = [
        (0.00, "smooth", "set: lunge, palms flat on the boulder", set_),
        (fr(10), "in", "SINK: hips drop, chest in, elbows bend", sink),
        (fr(16), "out", "HIT drive: rear leg straightens, arms lock out", drive),
        (fr(21), "smooth", "strain, tremor left", strain_a),
        (fr(26), "smooth", "strain, tremor right", strain_b),
        (fr(36), "smooth", "settle (loop)", set_),
    ]
    return slerp_pass(lock_feet(clip("TrainPush", fr(36), True, "Action",
                          "Pushing a heavy boulder from a long lunge: both palms flat on its face "
                          f"{D} studs in front of the HumanoidRootPart and never leaving it; each surge sinks, "
                          "then the rear leg drives and the arms lock out, then a strained tremor.",
                          "heavy push / prowler-sled drive against an immovable rock, 1.2 s loop, surge peak frame 16",
                          keys, markers=[("Hit", fr(16))],
                          views={"back": [-0.3, -1.0, 0.4], "side": [1.0, 0.08, 0.1], "rear34": [0.9, -0.75, 0.35]},
                          extra={"_contact": {"contact_distance": PUSH_FACE, "solved_plane": D, "measured_blender": [2.442, 2.441], "plane": "y = contact_distance",
                                              "palm_centres": [[PUSH_X, D, PUSH_Z], [-PUSH_X, D, PUSH_Z]],
                                              "what": "the hands' flat end faces lie on the plane all loop"},
                                 "_scene": [{"pos": [0, PUSH_FACE + 1.4, -0.6], "size": [4.4, 2.8, 4.8],
                                             "colour": [0.45, 0.44, 0.42]}]}),
                     hands=lambda bb, root: palms(bb["tor"], bb["up"], root)))


# ----------------------------------------------------------------------------------------------- lift
# Dumbbell in EACH hand, hammer (neutral) grip: the handle runs through the centre of the hand part,
# front-to-back (the hand part's own Z axis at rest), plates in front of and behind the fist.
# Weld for the main thread: Part0 = RightHand / LeftHand, C0 = CFrame.new(0, 0, 0) with the dumbbell's
# long axis on the hand part's Z axis (if the dumbbell model is built along its own X axis:
# C0 = CFrame.Angles(0, math.rad(90), 0)). Hand part centre = rig (+-1.5, 0, -0.85) at rest.
HAND_CENTRE = {R: [1.5, 0.0, -0.85], L: [-1.5, 0.0, -0.85]}
DB_PLATE = [0.78, 0.3, 0.78]     # rig x, y (along the bar), z
DB_PLATE_OFF = 0.68              # plate centre from the hand centre along the bar
DB_BAR = [0.2, 1.7, 0.2]


def dumbbell(side):
    cx, cy, cz = HAND_CENTRE[side]
    bone = "RightHand" if side == R else "LeftHand"
    grey = [0.18, 0.18, 0.2]
    return [{"bone": bone, "pos": [cx, cy, cz], "size": DB_BAR, "colour": [0.5, 0.5, 0.52]},
            {"bone": bone, "pos": [cx, cy + DB_PLATE_OFF, cz], "size": DB_PLATE, "colour": grey},
            {"bone": bone, "pos": [cx, cy - DB_PLATE_OFF, cz], "size": DB_PLATE, "colour": grey}]


def train_lift():
    # Alternating standing hammer curls, 2.0 s loop: the elbow stays pinned at the side and only the
    # forearm travels (shoulder drifts forward ~15 deg at the top, as real curls do), squeeze at the top,
    # slower lowering; the torso counter-leans a touch away from the working arm, a breath per rep.
    FEET = {R: (0.55, 0.0, -6, 0), L: (-0.55, 0.0, 6, 0)}
    down = {"ua": [-6, 0, 5], "la": [-10, 0, 0]}
    top = {"ua": [-22, 0, 5], "la": [-128, 0, 0]}
    rest_r = {"uar": down["ua"], "lar": down["la"]}
    rest_l = {"ual": [-6, 0, -5], "lal": down["la"]}
    top_r = {"uar": top["ua"], "lar": top["la"]}
    top_l = {"ual": [-22, 0, -5], "lal": top["la"]}
    sq_r = {"uar": [-24, 0, 5], "lar": [-132, 0, 0], "har": [-8, 0, 0]}
    sq_l = {"ual": [-24, 0, -5], "lal": [-132, 0, 0], "hal": [-8, 0, 0]}

    def P(root, tor, up, head, **arms):
        return planted(FEET, root, tor, "lift", up=up, head=head, **arms)

    T = [0, 0, 0]
    base = P(-0.06, T, [0, 0, 0], [-6, 0, 0], **rest_r, **rest_l)
    keys = [
        (0.00, "smooth", "both dumbbells down, elbows at the sides", base),
        (fr(14), "smooth", "REP right: forearm up, dumbbell at the shoulder", P(-0.04, T, [3, 4, 2], [-10, 6, 0], **top_r, **rest_l)),
        (fr(18), "smooth", "squeeze at the top", P(-0.04, T, [4, 4, 2], [-10, 6, 0], **sq_r, **rest_l)),
        (fr(30), "smooth", "lowered under control", base),
        (fr(44), "smooth", "REP left", P(-0.04, T, [3, -4, -2], [-10, -6, 0], **rest_r, **top_l)),
        (fr(48), "smooth", "squeeze at the top", P(-0.04, T, [4, -4, -2], [-10, -6, 0], **rest_r, **sq_l)),
        (2.00, "smooth", "lowered (loop)", base),
    ]
    return slerp_pass(lock_feet(clip("TrainLift", 2.0, True, "Action",
                          "Alternating standing hammer curls with a dumbbell in each hand: elbows pinned at the "
                          "sides, right then left, squeeze at the top, slower lowering.",
                          "alternating dumbbell hammer curl, 2.0 s loop, rep tops at frames 14 and 44",
                          keys, markers=[("Rep", fr(14)), ("Rep", fr(44))],
                          views={"front": [0.25, 1.0, 0.2], "back": [-0.3, -1.0, 0.4], "side": [1.0, 0.08, 0.1]},
                          extra={"_attach": dumbbell(R) + dumbbell(L),
                                 "_grip": {"hands": ["RightHand", "LeftHand"], "grip": "hammer (neutral)",
                                           "weld_C0_hand_space": [0, 0, 0],
                                           "long_axis_hand_space": "Z (front-back of the hand part at rest)",
                                           "dumbbell_size_studs": {"bar": DB_BAR, "plate": DB_PLATE,
                                                                   "plate_offset": DB_PLATE_OFF}}})))


# ---------------------------------------------------------------------------------------------- throw
THROW_RELEASE_FRAME = 23


def throw():
    # Full-power overhand throw, right hand, 1.5 s, one-shot. Mechanics from pitching / javelin
    # breakdowns: SET (food at the chest) -> pivot step, body turns side-on (glove shoulder at the
    # target) -> BALANCE (lead knee up, weight over the back leg, hips back) -> STRIDE (lead leg reaches
    # for the target, hands break: throwing arm swings down and back, glove arm points at the target)
    # -> FOOT PLANT (stride ~1.6 studs, hips already opening while the shoulders stay closed: ~40 deg of
    # hip-shoulder separation, throwing arm cocked: upper arm at shoulder height, elbow 90, forearm up)
    # -> LAYBACK (hips square, chest turning, forearm laid back behind the head, glove arm tucks)
    # -> RELEASE (trunk tilted forward ~30 and over to the glove side ~20, arm long and high in front of
    # the head, back heel up and turning) -> FOLLOW-THROUGH (arm sweeps across the body to outside the
    # lead knee, chest over the lead thigh, back leg swings forward) -> recovery steps back to a stand.
    # The hips TRAVEL (root offset -0.25 back at balance to +0.55 forward after release), so the body
    # visibly moves into the throw; see progress.md for the ROOT loc export correction this needs.
    def head_to_target(tor, up, extra=(0, 0, 0)):
        yaw = -(tor[1] + up[1])
        return [extra[0] - up[0] * 0.6, max(-80, min(80, yaw)) + extra[1], -up[2] * 0.6 + extra[2]]

    def P(root, tor, up, plants, arms, air=None, head=None):
        legs = feet(plants, root, tor, tag="throw")
        b = pose(legs=legs, tor=tor, up=up, head=head or head_to_target(tor, up), **arms)
        for side, lg in (air or {}).items():
            sf = side.lower()
            b[SHORT["ul" + sf]]["rot"] = list(lg["ul"])
            b[SHORT["ll" + sf]]["rot"] = list(lg["ll"])
            b[SHORT["f" + sf]]["rot"] = list(lg["f"])
        b["ROOT"] = {"loc": F.root_loc(root)}
        b["__feet"] = {s: list(v) for s, v in plants.items()}
        return b

    def air_leg(side, ankle, root, tor, yaw=0.0, toe=0.0):
        return F.solve_leg(side, ankle, root, tor, yaw=yaw, heel=toe)[0]

    def chest_hands(tor, up, root):
        return {**held(R, (0.3, 1.05, 0.25), (-0.55, 0.25, 0.8), tor, up, root),
                **held(L, (-0.15, 1.1, 0.35), (0.6, 0.2, 0.77), tor, up, root)}

    SQ = {L: (-0.55, 0.0, 0, 0), R: (0.55, 0.0, 0, 0)}
    PIV = (0.4, -0.3, -75, 0)
    LEAD = (-0.32, 1.3, -28, 0)
    # 0 SET
    r0, t0, u0 = (0, 0, -0.04), [0, 0, 0], [0, -6, 0]
    k_set = P(r0, t0, u0, SQ, chest_hands(t0, u0, r0))
    # 4 pivot step: the back foot turns and steps behind, body half turned
    r1, t1, u1 = (0, -0.1, -0.08), [0, -40, 0], [0, -10, 0]
    k_piv = P(r1, t1, u1, {L: (-0.55, 0.0, -35, 12), R: PIV}, chest_hands(t1, u1, r1))
    # 2 the back foot is OFF the floor mid-step (a step, not a slide)
    rh, th, uh = (0, -0.05, -0.07), [0, -22, 0], [0, -8, 0]
    k_hop = P(rh, th, uh, {L: (-0.55, 0.0, -18, 6)}, chest_hands(th, uh, rh),
              air={R: air_leg(R, (0.47, -0.16, -2.6), rh, th, yaw=-40, toe=0)})
    # 9 BALANCE: side-on, lead knee up, weight back over the pivot leg
    r2, t2, u2 = (0, -0.25, -0.12), [0, -72, 0], [3, -14, 0]
    k_bal = P(r2, t2, u2, {R: PIV}, chest_hands(t2, u2, r2),
              air={L: {"ul": [-82, 0, 0], "ll": [96, 0, 0], "f": [-12, 0, 0]}})
    # 14 STRIDE: lead leg reaches for the target, hands break
    r3, t3, u3 = (0, -0.05, -0.34), [0, -62, 0], [2, -24, 4]
    k_str = P(r3, t3, u3, {R: PIV},
              {"uar": [14, 0, 62], "lar": [-14, 0, 0], "ual": [-12, 0, -84], "lal": [-12, 0, 0]},
              air={L: air_leg(L, (-0.36, 1.05, -2.42), r3, t3, yaw=-35, toe=-12)})
    # 18 FOOT PLANT: hips opening, shoulders closed, arm cocked (inverted L), glove arm at the target
    r4, t4, u4 = (0, 0.28, -0.48), [0, -38, 0], [0, -38, -8]
    k_pl = P(r4, t4, u4, {L: LEAD, R: (0.4, -0.3, -68, 22)},
             {"uar": [0, 85, 88], "lar": [-95, 0, 0], "har": [10, 0, 0], "ual": [-22, 0, -78], "lal": [-14, 0, 0]})
    # 21 LAYBACK: hips square, chest turning, forearm laid back, glove arm tucks to the chest
    r5, t5, u5 = (0, 0.42, -0.46), [0, -8, 0], [-12, 2, 10]
    lay = F.solve_arm(R, (1.45, -0.35, 1.05), t5, u5, fore_dir=(0.05, -0.72, 0.69), root=r5, w_dir=3, avoid=6)[0]
    k_lay = P(r5, t5, u5, {L: LEAD, R: (0.4, -0.3, -50, 36)},
              {**arm_kw(R, lay), "har": [30, 0, 0], **held(L, (-1.1, 0.7, 0.2), (0.4, 0.5, 0.75), t5, u5, r5)})
    # 23 RELEASE: trunk forward and over to the glove side, arm long and high in front of the head
    r6, t6, u6 = (0, 0.52, -0.42), [0, 16, 0], [-26, 20, 12]
    o6 = F.fk({"tor": t6, "up": u6}, r6)
    sh = shoulder_centre(o6, R)
    rel = F.solve_arm(R, sh + np.array([0.05, 1.25, 1.05]), t6, u6, fore_dir=(-0.05, 0.72, 0.69), root=r6,
                      w_dir=3, avoid=6)[0]
    k_rel = P(r6, t6, u6, {L: LEAD, R: (0.4, -0.3, -30, 52)},
              {**arm_kw(R, rel), "har": [-25, 0, 0], **held(L, (-1.3, 0.35, -0.2), (0.3, 0.4, 0.86), t6, u6, r6)})
    # 29 FOLLOW-THROUGH: arm across the body outside the lead knee, chest over the lead thigh,
    # back leg swinging forward off the ground
    r7, t7, u7 = (0, 0.58, -0.56), [0, 24, 0], [-42, 22, 2]
    fol = F.solve_arm(R, (-0.75, 1.15, -1.15), t7, u7, fore_dir=(-0.45, 0.25, -0.86), root=r7, w_dir=3, avoid=8)[0]
    k_fol = P(r7, t7, u7, {L: LEAD},
              {**arm_kw(R, fol), "har": [-10, 0, 0], **held(L, (-1.35, 0.1, -0.55), (0.1, 0.3, 0.95), t7, u7, r7)},
              air={R: air_leg(R, (0.42, 0.05, -2.35), r7, t7, yaw=-25, toe=55)})
    # 35 back foot lands beside, rising out of the follow-through
    r8, t8, u8 = (0, 0.45, -0.44), [0, 16, 0], [-22, 10, 0]
    k_land = P(r8, t8, u8, {L: (-0.32, 1.3, -22, 0), R: (0.55, 0.0, -8, 0)},
               {"uar": [-20, 0, -18], "lar": [-35, 0, 0], "ual": [-10, 0, -12], "lal": [-30, 0, 0]})
    # 40 lead foot steps back under the hips
    r9, t9, u9 = (0, 0.18, -0.16), [0, 8, 0], [-8, 4, 0]
    k_back = P(r9, t9, u9, {R: (0.55, 0.0, -4, 0)},
               {"uar": [-8, 0, 6], "lar": [-18, 0, 0], "ual": [-6, 0, -6], "lal": [-18, 0, 0]},
               air={L: air_leg(L, (-0.5, 0.7, -2.45), r9, t9, yaw=-8, toe=-6)})
    k_end = P((0, 0, 0), [0, 0, 0], [0, 0, 0], SQ, {}, head=[0, 0, 0])
    keys = [
        (0.00, "smooth", "SET: square stance, food held at the chest", k_set),
        (fr(2), "smooth", "pivot step: back foot off the floor", k_hop),
        (fr(4), "smooth", "pivot step lands: back foot turned and behind, body half turned", k_piv),
        (fr(9), "in", "BALANCE: side-on, lead knee up, weight back", k_bal),
        (fr(14), "smooth", "STRIDE: lead leg reaches, throwing arm swings down and back, glove arm at target", k_str),
        (fr(18), "in", "FOOT PLANT: hips open, shoulders closed, arm cocked", k_pl),
        (fr(21), "in", "LAYBACK: chest turning, forearm laid back behind the head", k_lay),
        (fr(THROW_RELEASE_FRAME), "out", "RELEASE: trunk over the lead leg, arm long and high", k_rel),
        (fr(29), "smooth", "FOLLOW-THROUGH: arm across outside the lead knee, back leg swings", k_fol),
        (fr(35), "smooth", "back foot lands, rising", k_land),
        (fr(39), "smooth", "lead foot steps back under the hips", k_back),
        (fr(43), "smooth", "stand", k_end),
        (1.50, "smooth", "stand (idle)", k_end),
    ]
    rt = fr(THROW_RELEASE_FRAME)
    return slerp_pass(lock_feet(clip("Throw", 1.5, False, "Action",
                          "Full-power overhand throw of a food item held in the right hand: turn side-on, lead "
                          "knee up, long stride at the target, hips open before the shoulders, arm cocked and "
                          "whipped over the top to a high release in front of the head, long follow-through "
                          "across the body with the back leg swinging through, recover to a stand.",
                          "baseball pitch / javelin release phases (balance, stride, foot plant, max external "
                          "rotation, release, deceleration, follow-through); release at frame 23",
                          keys, markers=[("Release", rt)], views=VIEWS3,
                          extra={"prop": {"name": "Food", "attach": "RightHand",
                                          "parts": [{"name": "Food", "size": [0.75, 0.75, 0.75], "pos": [0, 0, 0],
                                                     "colour": [0.95, 0.55, 0.15]}],
                                          "grip_bone": {"pos": [0, 0.5, 0], "rot": [0, 0, 0]},
                                          "release": {"t": rt}}})))


CLIPS = {"Throw": throw, "TrainStrike": train_strike, "TrainPush": train_push, "TrainLift": train_lift}
