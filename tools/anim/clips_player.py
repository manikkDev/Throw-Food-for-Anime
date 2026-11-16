"""Player clips: Throw, TrainStrike, TrainPush, TrainLift, TrainMeditate, Celebrate.

Throw / TrainStrike / TrainPush / TrainLift (rev 2, 2026-11-15) are SOLVED: planted feet and every
contact point are found by least squares over the FK angles in fkmodel.py (a pure-Python copy of the
rig's FK, checked against Blender to 0.01 stud), then written here as plain FK rotations.
"""
from animlib import clip, euler, leg, lift, pose, pose_raw

R, L = "R", "L"


def throw():
    # Overhand throw, researched: wind-up, stride with the glove-side (LEFT) foot toward the
    # target, arm cocking to maximum layback (upper arm abducted ~90 deg, forearm vertical,
    # ball behind the head, glove arm pointing at the target, trunk coiled away), then a very
    # short acceleration (in a real pitch ~0.03-0.05 s), release just in front of and above the
    # head with the elbow nearly straight and the trunk tilted forward, and a follow-through
    # that sweeps the arm across the body to the opposite hip. A small round object is held in
    # the fingertips off the palm; the wrist is cocked back at layback and snaps through release.
    ready_legs = {R: leg(R, -3, -0.06, spread=4), L: leg(L, 6, -0.06, spread=4)}
    keys = [
        (0.00, "smooth", "ready: food held at the chest in the right hand", pose(
            root=-0.06, legs=ready_legs,
            uar=[-30, 0, -12], lar=[-78, 0, 0], ual=[-18, 0, 10], lal=[-55, 0, 0])),
        (0.15, "smooth", "wind-up: coil right, glove knee lifts, food drops back", pose(
            root=-0.12, legs={R: leg(R, 2, -0.12, spread=4), L: lift(L, 55, 75, tx=0, foot=10)},
            tor=[0, -24, 0], up=[4, -30, 0], head=[0, 32, 0],
            uar=[22, 0, 28], lar=[-35, 0, 0], ual=[-70, -15, 0], lal=[-25, 0, 0])),
        (0.35, "out", "stride lands toward the target, arm rising to cock", pose(
            root=-0.30, legs={R: leg(R, -22, -0.30, spread=6, heel=8), L: leg(L, 28, -0.30, shin_fwd=True)},
            tor=[0, -28, 0], up=[6, -38, 0], head=[0, 38, 0],
            uar=[25, 60, 75], lar=[-70, 0, 0], har=[20, 0, 0], ual=[-88, -28, 0], lal=[-6, 0, 0])),
        (0.45, "in", "COCKED: max layback, food behind the head, glove arm at the target", pose(
            root=-0.32, legs={R: leg(R, -24, -0.32, spread=6, heel=10), L: leg(L, 28, -0.32, shin_fwd=True)},
            tor=[0, -28, 0], up=[9, -42, 0], head=[0, 42, 0],
            uar=[15, 90, 92], lar=[-98, 0, 0], har=[28, 0, 0], ual=[-92, -32, 0], lal=[-4, 0, 0])),
        # The slerp midpoint rbx_axis_check.py reported for 0.45->0.55 (traps 37): Roblox slerps,
        # Blender lerps Euler, and they disagreed by 44 deg on the upper arm. Keyed, both agree.
        (0.50, "linear", "acceleration: elbow leads the arm over the top (slerp midpoint)", pose_raw(-0.34, {
            "HEAD": [7.2, 6.0, 2.3], "FK_Foot.L": [-41.9, 0, 0], "FK_Hand.L": [0, 0, 0],
            "FK_LowerArm.L": [-49.5, 0, 0], "FK_LowerLeg.L": [70.9, 0, 0], "FK_UpperArm.L": [-66.3, -14.0, 5.5],
            "FK_UpperLeg.L": [-29.0, 0, 0], "TORSO": [0, -5.0, 0], "FK_Foot.R": [-24.9, 0, -6.0],
            "FK_Hand.R": [0, 0, 0], "FK_LowerArm.R": [-55.0, 0, 0], "FK_LowerLeg.R": [15.4, 0, 0],
            "FK_UpperArm.R": [-123.1, 41.7, -8.9], "FK_UpperLeg.R": [27.0, 0, 6.0], "UpTorso": [-7.0, -6.0, 5.1]})),
        (0.55, "out", "RELEASE: arm high and forward, trunk tilted over the front leg", pose(
            root=-0.36, legs={R: leg(R, -30, -0.36, spread=6, heel=25), L: leg(L, 30, -0.36, shin_fwd=True)},
            tor=[0, 18, 0], up=[-22, 30, 0], head=[14, -30, 0],
            uar=[-150, 0, 18], lar=[-12, 0, 0], har=[-28, 0, 0], ual=[-40, 0, 18], lal=[-95, 0, 0])),
        (0.68, "smooth", "follow-through: arm swept across the body to the left hip", pose(
            root=-0.38, legs={R: leg(R, -24, -0.38, spread=6, heel=40), L: leg(L, 32, -0.38, shin_fwd=True)},
            tor=[0, 28, 0], up=[-30, 40, 0], head=[18, -40, 0],
            uar=[-48, -38, 0], lar=[-28, 0, 0], har=[-12, 0, 0], ual=[-15, 0, -12], lal=[-55, 0, 0])),
        (0.90, "smooth", "recover: neutral stand", pose()),
    ]
    return clip("Throw", 0.9, False, "Action",
                "Overhand throw: coil away with the glove arm aimed at the lane, food cocked behind "
                "the head, whip through to a release high in front at 0.55 s, arm finishes across "
                "the body; wind-up and release must read at a glance.",
                "baseball overhand throw phases (wind-up, stride, cocking, acceleration, release, "
                "follow-through); fingertip grip of a small round object; release beat 0.55 s",
                keys, markers=[("Release", 0.55)])


def train_push():
    def st(root, tx, a_r, a_l):
        return {R: leg(R, a_r, root, tx=tx, spread=5, heel=10), L: leg(L, a_l, root, tx=tx, spread=5, shin_fwd=True)}
    def arms(sx, ex, hx, y):
        return dict(uar=[sx, -y, 0], lar=[ex, 0, 0], har=[hx, 0, 0],
                    ual=[sx, y, 0], lal=[ex, 0, 0], hal=[hx, 0, 0])
    set_ = pose(root=-0.45, legs=st(-0.45, -12, -24, 34), tor=[-12, 0, 0], up=[-12, 0, 0],
                head=[16, 0, 0], **arms(-52, -62, -60, 18))
    keys = [
        (0.00, "smooth", "set: palms on the pillar, knees bent, leaning in", set_),
        (0.35, "in", "load: sink and draw the elbows back", pose(
            root=-0.55, legs=st(-0.55, -8, -22, 38), tor=[-8, 0, 0], up=[-8, 0, 0], head=[12, 0, 0],
            **arms(-34, -88, -62, 16))),
        (0.50, "out", "HIT: drive both palm-heels forward, rear leg extends", pose(
            root=-0.40, legs=st(-0.40, -18, -38, 30), tor=[-18, 0, 0], up=[-20, 0, 0], head=[24, 0, 0],
            **arms(-80, -10, -76, 24))),
        (0.65, "smooth", "hold the push", pose(
            root=-0.42, legs=st(-0.42, -18, -36, 31), tor=[-18, 0, 0], up=[-22, 0, 0], head=[24, 0, 0],
            **arms(-80, -16, -72, 23))),
        (1.00, "smooth", "set (loop)", set_),
    ]
    return clip("TrainPush", 1.0, True, "Action",
                "Both palm-heels driving into a heavy pillar in front of the chest from a deep "
                "staggered stance; the whole body leans in and the rear leg straightens on the beat.",
                "palm-heel push against a heavy pillar, knees bent, 1.0 s loop, hit at 0.5 s",
                keys, markers=[("Hit", 0.5)])


def train_meditate():
    SEAT = -1.65
    thigh_r = euler(("y", 80), ("x", -80), ("y", 56))
    thigh_l = euler(("y", -80), ("x", -80), ("y", -56))
    legs = {R: {"ul": thigh_r, "ll": [145, 0, 0], "f": [-30, 0, 0]},
            L: {"ul": thigh_l, "ll": [145, 0, 0], "f": [-30, 0, 0]}}
    def p(rz, ux, sx, ex, hx, head):
        return pose(root=SEAT + rz, legs=legs, up=[ux, 0, 0], head=[head, 0, 0],
                    uar=[sx, 0, -10], lar=[ex, 0, 0], har=[hx, 0, 0],
                    ual=[sx, 0, 10], lal=[ex, 0, 0], hal=[hx, 0, 0])
    rest = p(0.0, -2, -14, -8, 0, -8)
    keys = [
        (0.00, "smooth", "exhale: seated lotus, hands on the knees", rest),
        (0.35, "in", "inhale: chest rises", p(0.03, 2, -16, -18, -10, -4)),
        (0.50, "out", "PULSE: chest up, fists clench and lift", p(0.06, 5, -20, -45, -40, 0)),
        (0.70, "smooth", "release", p(0.03, 2, -16, -22, -14, -4)),
        (1.00, "smooth", "exhale (loop)", rest),
    ]
    return clip("TrainMeditate", 1.0, True, "Action",
                "Seated cross-legged on the ground, back straight, hands on the knees; on the beat "
                "the chest lifts and both fists clench and rise a little.",
                "seated lotus with a breathing pulse and a fist-clench on the beat, 1.0 s loop",
                keys, markers=[("Pulse", 0.5)])


def celebrate():
    keys = [
        (0.00, "smooth", "neutral stand", pose()),
        (0.18, "in", "anticipation: deep crouch, arms swing down and back", pose(
            root=-0.45, legs={R: leg(R, 28, -0.45, tx=-10, spread=4), L: leg(L, 28, -0.45, tx=-10, spread=4)},
            tor=[-10, 0, 0], up=[-12, 0, 0], head=[12, 0, 0],
            uar=[35, 0, 10], lar=[-20, 0, 0], ual=[35, 0, -10], lal=[-20, 0, 0])),
        (0.34, "out", "take-off: legs extend, arms swing up", pose(
            root=0.40, legs={R: lift(R, 0, 0, foot=25), L: lift(L, 0, 0, foot=25)},
            up=[4, 0, 0], uar=[-20, 0, 120], lar=[-20, 0, 0], ual=[-40, 0, -30], lal=[-60, 0, 0])),
        (0.50, "in", "PEAK: right fist punched to the sky, knees tucked", pose(
            root=1.00, legs={R: lift(R, 45, 75, foot=10), L: lift(L, 20, 95, foot=10)},
            up=[6, 12, 0], head=[12, -8, 0],
            uar=[8, 0, 168], lar=[-6, 0, 0], ual=[18, 0, -22], lal=[-112, 0, 0])),
        (0.68, "out", "land", pose(
            root=-0.10, legs={R: leg(R, 12, -0.10, spread=4), L: leg(L, 12, -0.10, spread=4)},
            up=[0, 6, 0], uar=[0, 0, 135], lar=[-30, 0, 0], ual=[10, 0, -20], lal=[-100, 0, 0])),
        (0.80, "smooth", "absorb, fist yanked down: YES", pose(
            root=-0.42, legs={R: leg(R, 28, -0.42, tx=-8, spread=4), L: leg(L, 28, -0.42, tx=-8, spread=4)},
            tor=[-8, 0, 0], up=[-14, 10, 0], head=[12, -6, 0],
            uar=[28, 0, 16], lar=[-118, 0, 0], ual=[18, 0, -18], lal=[-100, 0, 0])),
        (1.00, "smooth", "rise, hold the pump", pose(
            root=-0.08, legs={R: leg(R, 10, -0.08, spread=3), L: leg(L, 10, -0.08, spread=3)},
            up=[-4, 6, 0], uar=[22, 0, 14], lar=[-110, 0, 0], ual=[10, 0, -12], lal=[-60, 0, 0])),
        (1.20, "smooth", "neutral stand (hands back to idle)", pose()),
    ]
    return clip("Celebrate", 1.2, False, "Action",
                "Crouch, jump with the right fist punched straight up at the peak, land, yank the "
                "fist down in a 'yes!', finish in a neutral stand that blends into idle.",
                "fist pump jump, 1.2 s, lands back in idle", keys, markers=[("Peak", 0.5)])


CLIPS = {"Throw": throw, "TrainPush": train_push,
         "TrainMeditate": train_meditate, "Celebrate": celebrate}
CLIPS.update(__import__("clips_train").CLIPS)   # rev 2: solved contact clips override
