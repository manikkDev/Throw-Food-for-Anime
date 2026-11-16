"""Hero clips. Idles loop at Core priority so the default walk/run still drives the legs when a hero
moves (roblox-animation SKILL.md, 'An authored clip breaks the ones you did not author')."""
from animlib import clip, leg, lift, pose

R, L = "R", "L"


def stand(root, aR=0, aL=0, sR=5, sL=5, tx=0, fR=False, fL=False):
    return {R: leg(R, aR, root, tx=tx, spread=sR, shin_fwd=fR), L: leg(L, aL, root, tx=tx, spread=sL, shin_fwd=fL)}


def idle_cool():
    # Arms crossed (grid-searched: forearms ~1.0 stud forward of the chest, left over right), weight
    # on the right leg with the left knee relaxed, slow look to the side and back.
    arms = dict(uar=[-30, -60, 0], lar=[-50, 0, 0], ual=[-45, 60, 0], lal=[-50, 0, 0])
    legs = stand(-0.04, aR=-1, aL=9, sR=5, sL=8)
    def p(head, up, root=-0.04):
        return pose(root=root, legs=stand(root, aR=-1, aL=9, sR=5, sL=8), head=head, up=up, **arms)
    k0 = p([4, 0, 0], [0, 0, 2])
    keys = [
        (0.0, "smooth", "arms crossed, weight on the right leg", k0),
        (0.9, "smooth", "breathe in, slow look left", p([4, 24, 0], [2, 4, 2], -0.03)),
        (1.6, "smooth", "hold the look", p([5, 24, -2], [1, 4, 2], -0.05)),
        (2.3, "smooth", "glance back past centre", p([3, -8, 0], [0, -2, 2], -0.05)),
        (3.0, "smooth", "loop", k0),
    ]
    del legs
    return clip("IdleCool", 3.0, True, "Core", "Arms crossed high on the chest, weight on one leg, "
                "chin up, slow head turn to the side and back; aloof.",
                "arms crossed, weight on one leg, slow head turn, 3 s loop", keys)


def idle_cheer():
    # Idol wave: right upper arm raised out to the side and rolled so the elbow hinges in the frontal
    # plane, forearm waving side to side above the shoulder; left fist at the chest; small bounce.
    def p(i):
        up_beat = i % 2 == 0
        root = -0.03 if up_beat else -0.13
        return pose(root=root, legs=stand(root, aR=4, aL=4, sR=5, sL=5),
                    up=[0, 0, 3 if up_beat else -3], head=[4, 0, 8 if up_beat else -8],
                    uar=[-20, 60, 112], lar=[-62 if up_beat else -12, 0, 0], har=[0, 0, 0],
                    ual=[-30, 60, 0], lal=[-72, 0, 0])
    keys = [(round(i * 0.25, 2), "smooth", "wave in, up" if i % 2 == 0 else "wave out, dip", p(i)) for i in range(9)]
    return clip("IdleCheer", 2.0, True, "Core", "Bright idol wave: right hand waving above the "
                "shoulder, left fist at the chest, a little bounce and head tilt on each wave.",
                "idol wave with a small bounce, 2 s loop", keys)


def idle_blade():
    # Sword carry, researched: a katana is worn on the LEFT hip, edge up; at rest the left hand rests on
    # the scabbard by the guard (thumb on the tsuba) and the right hand hangs free to draw. Without a
    # sword the same pose reads as a hand-on-hip confident stance. Hips turned a little so the left
    # (sword) hip leads, chest up, chin level.
    def p(head, up, root, rh):
        return pose(root=root, legs=stand(root, aR=-3, aL=7, sR=9, sL=9), tor=[0, -8, 0], up=up, head=head,
                    ual=[15, 80, -15], lal=[-62, 0, 0], hal=[0, 0, 0],
                    uar=[-4, 0, 9], lar=[-14 + rh, 0, 0], har=[rh, 0, 0])
    k0 = p([3, 12, 0], [3, -4, 0], -0.07, 0)
    keys = [
        (0.0, "smooth", "hand on the hilt at the left hip, confident stance", k0),
        (1.0, "smooth", "breathe in, chest up, fingers flex", p([4, 18, 0], [5, -5, 0], -0.05, -8)),
        (2.0, "smooth", "eyes forward, breathe out", p([3, 6, 0], [2, -3, 0], -0.08, -3)),
        (3.0, "smooth", "loop", k0),
    ]
    return clip("IdleBlade", 3.0, True, "Core", "Left hand resting at the left hip where a katana "
                "hilt is worn, right arm loose and ready to draw, hips turned so the sword hip leads, "
                "chest up; reads as a confident hand-on-hip stance when no sword is worn.",
                "hand on the hilt at the hip; katana worn edge up on the left hip; 3 s loop", keys)


def idle_ninja():
    def p(root, head, up):
        return pose(root=root, legs=stand(root, aR=-10, aL=14, sR=16, sL=16, fL=True), tor=[0, -20, 0],
                    up=up, head=head, uar=[-30, -80, 0], lar=[-95, 0, 0], har=[0, 0, 0],
                    ual=[28, 0, -22], lal=[-30, 0, 0])
    k0 = p(-0.55, [6, 26, 0], [-10, -10, 0])
    keys = [
        (0.0, "smooth", "low ready crouch, two-finger sign at the chest", k0),
        (1.0, "smooth", "sink, scan right", p(-0.6, [6, 8, 0], [-12, -10, 0])),
        (2.0, "smooth", "scan left", p(-0.57, [6, 38, 0], [-10, -12, 0])),
        (3.0, "smooth", "loop", k0),
    ]
    return clip("IdleNinja", 3.0, True, "Core", "Low wide crouch side-on, right hand upright in a "
                "two-finger seal in front of the chest, left arm swept back, eyes scanning.",
                "low ready stance, one hand in a two-finger sign at the chest, 3 s loop", keys)


def idle_power():
    # Feet wide, fists clenched slightly out from the hips, chest heaving: shoulders rise on the
    # in-breath (arms lift a little with the chest). Small motion: read at 30-60 studs on a pedestal.
    def p(root, ux, az, head):
        return pose(root=root, legs=stand(root, aR=0, aL=0, sR=14, sL=14), up=[ux, 0, 0], head=[head, 0, 0],
                    uar=[-6, 0, az], lar=[-32, 0, 0], har=[-20, 0, 0],
                    ual=[-6, 0, -az], lal=[-32, 0, 0], hal=[-20, 0, 0])
    k0 = p(-0.14, 0, 13, 2)
    keys = [(0.0, "smooth", "wide stance, fists clenched at the sides, breathe out", k0),
            (0.9, "smooth", "breathe in: chest and shoulders rise", p(-0.08, 5, 17, -2)),
            (1.3, "smooth", "hold the breath", p(-0.08, 5, 17, -2)),
            (2.0, "smooth", "loop", k0)]
    return clip("IdlePower", 2.0, True, "Core", "Feet wide, fists clenched just out from the hips, "
                "chest and shoulders rising and falling like gathering power.",
                "feet wide, fists clenched at the sides, shoulders rise and fall, 2 s loop", keys)


def idle_shy():
    # Hands clasped behind the back (grid-searched), head tipped down and to one side, weight swaying
    # from side to side, the left toe tapping behind once per loop.
    def p(root, sway, tap):
        lg = stand(root, aR=0, aL=0, sR=4, sL=4)
        if tap:
            lg["L"] = lift("L", -14, 32, foot=34, spread=4)
        return pose(root=root, legs=lg, up=[-3, 0, sway], head=[-10, 6, -sway * 2],
                    uar=[30, 60, -25], lar=[-30, 0, 0], ual=[30, -60, 25], lal=[-30, 0, 0])
    k0 = p(-0.05, 3, False)
    keys = [(0.0, "smooth", "hands behind the back, head down, sway right", k0),
            (0.8, "smooth", "left toe taps behind", p(-0.05, 1, True)),
            (1.1, "smooth", "toe down", p(-0.05, 0, False)),
            (2.0, "smooth", "sway left", p(-0.06, -3, False)),
            (3.0, "smooth", "loop", k0)]
    return clip("IdleShy", 3.0, True, "Core", "Hands clasped behind the back, head tipped down, "
                "a small side-to-side sway and a toe tap; bashful.",
                "hands behind the back, toe tap and sway, 3 s loop", keys)


def idle_float():
    # Hover: the whole body drifts on the ROOT (Z only), legs hang relaxed with toes pointed, arms a
    # little out. The feet never touch the floor, so this clip owns the legs while it plays.
    def p(root, arm, sway):
        return pose(root=root, legs={"R": lift("R", 12, 28, foot=35), "L": lift("L", -4, 40, foot=40)},
                    up=[sway, 0, 0], head=[2, 0, 0],
                    uar=[-8, 0, arm], lar=[-22, 0, 0], ual=[-8, 0, -arm], lal=[-22, 0, 0])
    k0 = p(0.55, 22, 0)
    keys = [(0.0, "smooth", "low point of the drift", k0),
            (1.0, "smooth", "rising, arms float up", p(0.70, 27, 2)),
            (2.0, "smooth", "high point", p(0.85, 30, 3)),
            (3.0, "smooth", "sinking, arms settle", p(0.70, 25, 1)),
            (4.0, "smooth", "loop", k0)]
    return clip("IdleFloat", 4.0, True, "Core", "Hovering half a stud off the ground with legs hanging "
                "relaxed and toes pointed, arms slightly out, slow vertical drift authored on the root.",
                "legs relaxed off the ground, arms slightly out, slow vertical drift on the root, 4 s loop", keys)


def eat():
    MOUTH = dict(uar=[-60, -80, 0], lar=[-110, 0, 0])   # grid-searched: food at the mouth
    NEAR = dict(uar=[-45, -70, 0], lar=[-95, 0, 0])
    OFF = dict(ual=[-10, 0, -6], lal=[-30, 0, 0])
    st0 = stand(-0.04, aR=0, aL=4)
    st1 = stand(-0.08, aR=0, aL=4)
    keys = [
        (0.0, "smooth", "stand", pose(root=-0.04, legs=st0)),
        (0.30, "out", "crouch and reach down for the food", pose(
            root=-1.0, legs=stand(-1.0, aR=45, aL=55, sR=8, sL=8, tx=-25), tor=[-25, 0, 0], up=[-30, 0, 0],
            head=[26, 0, 0], uar=[-45, 0, -6], lar=[-8, 0, 0], ual=[-20, 0, -10], lal=[-40, 0, 0])),
        (0.50, "smooth", "stand up, food comes to the mouth", pose(root=-0.06, legs=st0, up=[2, 0, 0], **OFF, **NEAR)),
        (0.70, "out", "BITE one", pose(root=-0.08, legs=st1, up=[-6, 0, 0], head=[-8, 0, 0], **OFF, **MOUTH)),
        (0.82, "smooth", "pull away, chew", pose(root=-0.05, legs=st0, up=[2, 0, 0], head=[6, 0, 4], **OFF, **NEAR)),
        (0.95, "out", "BITE two", pose(root=-0.08, legs=st1, up=[-6, 0, 0], head=[-8, 0, 0], **OFF, **MOUTH)),
        (1.12, "smooth", "chew, happy", pose(root=-0.05, legs=st0, up=[3, 0, 0], head=[8, 0, -5], **OFF, **NEAR)),
        (1.35, "out", "thumbs up with the left hand", pose(root=-0.03, legs=st0, up=[4, -8, 0], head=[6, 10, 0],
            uar=[-10, 0, 8], lar=[-40, 0, 0], ual=[-32, 45, 0], lal=[-92, 0, 0])),
        (1.60, "smooth", "hold the thumbs up", pose(root=-0.03, legs=st0, up=[4, -8, 0], head=[6, 10, 0],
            uar=[-10, 0, 8], lar=[-40, 0, 0], ual=[-34, 45, 0], lal=[-94, 0, 0])),
    ]
    return clip("Eat", 1.6, False, "Action", "Crouch to pick the food up, stand, two clear bites with "
                "the food at the mouth, then a thumbs up to the thrower.",
                "crouch, pick up, two bites, thumbs up, 1.6 s", keys,
                markers=[("Bite", 0.7), ("Bite", 0.95)])


def reveal_land():
    tx = -22
    def land(root, kneel):
        return {"R": lift("R", 0, kneel, tx=tx, foot=40, spread=6),
                "L": leg("L", 72, root, tx=tx, spread=10, shin_fwd=True)}
    keys = [
        (0.0, "in", "falling in from above: tucked, arms up", pose(
            root=2.4, legs={"R": lift("R", 50, 90, foot=20), "L": lift("L", 70, 110, foot=20)},
            up=[6, 0, 0], head=[-10, 0, 0], uar=[-20, 0, 140], lar=[-20, 0, 0], ual=[-20, 0, -140], lal=[-20, 0, 0])),
        (0.20, "in", "legs reach for the ground", pose(
            root=0.5, legs={"R": lift("R", 10, 40, foot=10), "L": lift("L", 40, 50, foot=10)},
            head=[-10, 0, 0], uar=[-30, 0, 70], lar=[-20, 0, 0], ual=[-30, 0, -70], lal=[-20, 0, 0])),
        (0.27, "out", "LAND: three-point landing, knee and fist on the ground", pose(
            root=-1.15, legs=land(-1.15, 92), tor=[tx, 0, 0], up=[-22, 0, 0], head=[28, 0, 0],
            uar=[-25, -12, -8], lar=[0, 0, 0], har=[-10, 0, 0], ual=[20, 0, -55], lal=[-20, 0, 0])),
        (0.50, "in", "hold the landing", pose(
            root=-1.18, legs=land(-1.18, 94), tor=[tx, 0, 0], up=[-24, 0, 0], head=[30, 0, 0],
            uar=[-25, -12, -8], lar=[0, 0, 0], har=[-10, 0, 0], ual=[20, 0, -50], lal=[-20, 0, 0])),
        (0.75, "out", "rise", pose(
            root=-0.30, legs=stand(-0.30, aR=-6, aL=32, sR=10, sL=10, fL=True), up=[2, 0, 0], head=[4, 0, 0],
            uar=[-30, -60, 0], lar=[-70, 0, 0], ual=[10, 0, -20], lal=[-20, 0, 0])),
        (1.00, "smooth", "hero pose: chest out, fist at the chest", pose(
            root=-0.12, legs=stand(-0.12, aR=-6, aL=16, sR=10, sL=10, fL=True), up=[4, 0, 0], head=[4, -8, 0],
            uar=[-40, -70, 0], lar=[-95, 0, 0], ual=[8, 0, -22], lal=[-30, 0, 0])),
    ]
    return clip("RevealLand", 1.0, False, "Action", "Hero drops in from above (first frames read as "
                "falling), slams into a three-point landing (one knee, one foot, one fist down) at "
                "0.27 s, holds, then rises into a proud pose.",
                "three-point superhero landing rising into a pose, 1.0 s", keys,
                markers=[("Land", 0.27)])


CLIPS = {"IdleCool": idle_cool, "IdleCheer": idle_cheer, "IdleBlade": idle_blade, "IdleNinja": idle_ninja,
         "IdlePower": idle_power, "IdleShy": idle_shy, "IdleFloat": idle_float, "Eat": eat,
         "RevealLand": reveal_land}
