"""Food effects (plan 13 phase C): the Meal trail and landing, the aroma loops, the favourite burst,
and the 17 Signature dishes (one flight effect and one landing each, built from the dish).

    python assets/vfx/builders/build_food.py [name ...]      (names: meal aroma favourite <food id> ...)

HOW A FLIGHT EFFECT MUST BE BUILT (measured in the game). The food flies 125 to 2,100 studs a
second and the chase camera rides 15 studs behind and 7 above it. Anything left hanging in the
world is behind the camera within one frame, and only the first 15 studs of a Trail are in view, so
a texture on a Trail never reads. So:
  - RIBBONS (Trails) give colour only: a solid core over a darker, wider edge copy.
  - Everything that says what the dish IS rides WITH the food: LockedToPart emitters on the
    carrier, streaming out of its back (carrier -Z is the travel direction, so NormalId.Back).
    They look the same at every speed.
  - Stay off the food: the wake sits behind and below it from the chase camera, sizes modest.
A landing is a one-shot at the floor point, seen first from 30 studs up the lane, then from a low
camera 9.5 studs away: readable silhouette, 10 to 14 studs tall at most, gone in about a second
(the rarity pillar of the reveal comes later and must stay the bigger moment).

Colours come from the dish itself. Pale floors and the 13:12 sun wash additive pale colour to white:
bodies are saturated with LightEmission <= 0.4 and a dark copy underneath; only glints go higher.
"""
import sys

from tfa_fx import (CS, FB4, FB4LOOP, FLAT, NR, NS, STREAK, TL, V2, V3, WHITE, C3, E, att, beam, carrier, hexc, light,
                    mix, pe, tex, trail, write)

GOLD = hexc("FFD23F")
CREAM = hexc("FFF4D6")
BLACK = (0.04, 0.04, 0.05)
FLOORS = ["#F4EBD0", "#FFD6E5", "#CFF5E1"]
BACK = E("NormalId.Back")
TOP = E("NormalId.Top")
FB8 = {"FlipbookLayout": E("ParticleFlipbookLayout.Grid8x8"), "FlipbookMode": E("ParticleFlipbookMode.OneShot"), "FlipbookBlendFrames": False}
FB8LOOP = {"FlipbookLayout": E("ParticleFlipbookLayout.Grid8x8"), "FlipbookMode": E("ParticleFlipbookMode.Loop"), "FlipbookBlendFrames": False}
# the wake is judged from 15 studs behind the food, where the food itself is small: these make every
# wake layer big and dense enough to be the thing the eye follows
WAKE_SIZE, WAKE_RATE, WAKE_SPEED = 1.25, 1.6, 1.35
PERP = {"Orientation": E("ParticleOrientation.VelocityPerpendicular")}
FADE = NS((0, 0), (0.7, 0.15), (1, 1))


def hx(c):
    return "#%02X%02X%02X" % tuple(int(round(x * 255)) for x in c)


def fb(frames_life):
    """Flipbook kwargs for a 4x4 one-shot that plays once over `frames_life` seconds."""
    return dict(FB4, FlipbookFramerate=NR(16 / frames_life))


# ------------------------------------------------------------------------------------ flight
def sim_food(col, y=5.0):
    """A stand-in for the thrown food in the sim strips only (the packer drops it)."""
    return {"class": "Part", "name": "SimFood", "CFrame": [0, y, 0, 0, 0, 0], "Size": [3.6, 2.6, 3.6], "Shape": "Ball",
            "Transparency": 0, "Color": C3(col), "props": {"Color": C3(col)}, "children": [], "sim": True}


def flight(tl, T=0.9):
    for target in ("Food", "SimFood"):
        tl.at(0, do="path", target=target, points=[[0, 5, 0], [0, 5, -75], [0, 5, -150]], time=T, style="Linear", sim=True)
    tl.at(0, do="camera", pos=[0, 12, 15], at=[0, 4, -12], sim=True)
    tl.at(0, do="camera", pos=[0, 12, -135], at=[0, 4, -162], time=T, style="Linear", sim=True)


def ribbons(core, edge, tip, W=3.4, glow="beams/energy_glow_04", tint=False, life=0.2, a0=0.0):
    """Core + darker edge copy + glow + hot line. Returns (attachments, trails)."""
    ta = {"Tint": True} if tint else None
    WE = W * 1.3
    tr = [
        trail("Edge", "Food.E0", "Food.E1", attrs=ta, Texture=tex("tfa/ribbon_solid"), TextureMode=E("TextureMode.Stretch"),
              Lifetime=life + 0.02, MinLength=0.05, WidthScale=NS((0, 1), (0.5, 0.55), (1, 0)), Color=CS((0, mix(edge, core, 0.25)), (1, edge)),
              Transparency=NS((0, a0), (0.6, a0 + 0.1), (1, 1)), LightEmission=0),
        trail("Ribbon", "Food.T0", "Food.T1", attrs=ta, Texture=tex("tfa/ribbon_solid"), TextureMode=E("TextureMode.Stretch"),
              Lifetime=life, MinLength=0.05, WidthScale=NS((0, 1), (0.5, 0.5), (1, 0)), Color=CS((0, tip), (0.2, core), (1, mix(core, edge, 0.3))),
              Transparency=NS((0, a0), (0.6, a0 + 0.1), (1, 1)), LightEmission=0.1),
        trail("Glow", "Food.G0", "Food.G1", attrs=ta, Texture=tex(glow), TextureMode=E("TextureMode.Stretch"),
              Lifetime=life + 0.04, MinLength=0.05, WidthScale=NS((0, 1), (1, 0)), Color=CS((0, tip), (1, core)),
              Transparency=NS((0, 0), (0.6, 0.2), (1, 1)), LightEmission=0.35),
        trail("Line", "Food.S0", "Food.S1", attrs=ta, Texture=tex("beams/laser_glow_04"), TextureMode=E("TextureMode.Stretch"),
              Lifetime=life - 0.04, MinLength=0.05, WidthScale=NS((0, 1), (1, 0)), Color=CS(tip), Transparency=NS((0, 0), (1, 1)), LightEmission=0.5),
    ]
    at = [att("T0", (0, W / 2, 0)), att("T1", (0, -W / 2, 0)), att("E0", (0, WE / 2, 0)), att("E1", (0, -WE / 2, 0)),
          att("G0", (0, W * 0.4, 0)), att("G1", (0, -W * 0.4, 0)), att("S0", (0, 0.35, 0)), att("S1", (0, -0.35, 0))]
    return at, tr


def wake(name, texture, rate, size, color, life=(0.3, 0.45), speed=(10, 16), spread=(14, 14), attrs=None, **kw):
    """A layer that streams out of the food's back and rides with it."""
    size = {"NumberSequence": [[k[0], k[1] * WAKE_SIZE] + list(k[2:]) for k in size["NumberSequence"]]}
    p = dict(Texture=tex(texture), Rate=round(rate * WAKE_RATE, 2), LockedToPart=True, EmissionDirection=BACK,
             Speed=NR(speed[0] * WAKE_SPEED, speed[1] * WAKE_SPEED), SpreadAngle=V2(*spread), Lifetime=NR(*life), Size=size, Color=color, ZOffset=1.5)
    p.update(kw)
    return pe(name, attrs=attrs, **p)


def halo(name, texture, rate, size, color, life=0.35, attrs=None, **kw):
    """A sprite that sits ON the food, behind it for the camera (negative ZOffset), riding with it."""
    p = dict(Texture=tex(texture), Rate=rate, LockedToPart=True, Speed=NR(0), Lifetime=NR(life), Size=size, Color=color, ZOffset=-1.5)
    p.update(kw)
    return pe(name, attrs=attrs, **p)


def trail_effect(name, note, pal, layers, W=2.4, glow="beams/energy_glow_04", tint=False, extra=(), beats=(), a0=0.2, back=()):
    """pal = (core, edge, tip). layers = emitters under Food.A, 2.2 studs BEHIND the food's centre
    (seen in the game: a wake born at the centre covers the food from the chase camera; born behind
    it, it sits below the food on screen); back = emitters 3.6 studs behind (heavy layers); extra = attachments (children of
    Food) and box carriers (Parts: top-level, the runtime keeps every carrier in formation)."""
    tl = TL()
    core, edge, tip = pal
    ats, trs = ribbons(core, edge, tip, W=W, glow=glow, tint=tint, a0=a0)
    boxes = [x for x in extra if x["class"] == "Part"]
    kids = ats + [att("A", (0, -0.3, 2.2), children=list(layers)), att("B", (0, -0.4, 3.6), children=list(back))] + [x for x in extra if x["class"] != "Part"] + trs
    inst = [carrier("Food", (0, 5, 0, 0, 0, 0), kids, size=(2, 2, 2))] + boxes + [sim_food(mix(core, WHITE, 0.25))]
    flight(tl)
    for b in boxes:
        x, y, z = b["CFrame"][:3]
        tl.at(0, do="path", target=b["name"], points=[[x, y, z], [x, y, z - 75], [x, y, z - 150]], time=0.9, style="Linear", sim=True)
    d = {"name": name, "note": note, "duration": 1.1, "camera": {"pos": [0, 12, 15], "at": [0, 4, -12]},
         "stage": {"ground": "light", "dummy": False}, "stripFloors": ["#F4EBD0"], "stripGrounds": ["light"],
         "game": {"loop": True, "attach": "part", "screen": False, "origin": [0, 5, 0]},
         "brief": {"category": "projectile", "tier": "basic", "style": "stylised_game", "shape": "comet with a wake that rides along",
                   "dominant": hx(core), "accent": hx(edge), "signature_beats": list(beats) or ["dark copy under the bright stroke"],
                   "phases": [{"name": "sustain", "t0": 0, "t1": 0.9}, {"name": "residue", "t0": 0.9, "t1": 1.1}]},
         "instances": inst, "timeline": tl}
    return write(d, [0.25, 0.45, 0.65, 0.85])


# ------------------------------------------------------------------------------------ landing
def pillar(col, core=WHITE, H=12.0, W=5.0, dark=False):
    """Three beams on one carrier (named Pillar). Returns (carrier, beam names, widths)."""
    b = [
        att("Bot", (0, 0, 0, 0, 0, 90)), att("Top", (0, H, 0, 0, 0, 90)),
        beam("Halo", "Pillar.Bot", "Pillar.Top", Texture=tex("tfa/pillar_soft"), TextureMode=E("TextureMode.Stretch"),
             Width0=W * 1.9, Width1=W * 1.2, Color=CS(col), LightEmission=0.3, Transparency=NS((0, 0.2), (0.6, 0.5), (1, 1)),
             Enabled=False, ZOffset=-0.1),
        beam("Body", "Pillar.Bot", "Pillar.Top", Texture=tex("beams/energy_glow_02"), TextureMode=E("TextureMode.Wrap"),
             TextureLength=7, TextureSpeed=-2.4, Width0=W, Width1=W * 0.6, Color=CS(col), LightEmission=0.35, Brightness=1.2,
             Transparency=NS((0, 0), (0.7, 0.3), (1, 1)), Enabled=False, ZOffset=-0.05),
        beam("Core", "Pillar.Bot", "Pillar.Top", Texture=tex("beams/laser_soft_04" if dark else "beams/laser_glow_04"),
             TextureMode=E("TextureMode.Stretch"), Width0=W * (0.5 if dark else 0.32), Width1=W * 0.18, Color=CS(core),
             LightEmission=0 if dark else 0.7, Brightness=1 if dark else 1.8, Transparency=NS((0, 0), (0.75, 0.15), (1, 1)),
             Enabled=False, ZOffset=0.1),
    ]
    return carrier("Pillar", (0, 0, 0, 0, 0, 0), b), ["Halo", "Body", "Core"], {"Halo": (W * 1.9, W * 1.2), "Body": (W, W * 0.6), "Core": (W * (0.5 if dark else 0.32), W * 0.18)}


def pillar_events(tl, names, widths, t0=0.0, hold=0.3):
    for b in names:
        w0, w1 = widths[b]
        tl.at(t0, do="set", target=f"Pillar.{b}", prop="Enabled", value=True)
        tl.at(t0, do="tween", target=f"Pillar.{b}", prop="Width0", **{"from": w0 * 1.5}, to=w0, time=0.12, style="Quint", dir="Out")
        tl.at(t0 + hold, do="tween", target=f"Pillar.{b}", prop="Width0", to=0, time=0.3, style="Quad", dir="In")
        tl.at(t0 + hold, do="tween", target=f"Pillar.{b}", prop="Width1", to=0, time=0.24, style="Quad", dir="In")
        tl.at(t0 + hold + 0.32, do="set", target=f"Pillar.{b}", prop="Enabled", value=False)
        tl.at(t0 + hold + 0.34, do="set", target=f"Pillar.{b}", prop="Width0", value=w0)
        tl.at(t0 + hold + 0.34, do="set", target=f"Pillar.{b}", prop="Width1", value=w1)


def ring(name, texture, size0, size1, color, life=0.4, le=0.25, attrs=None, **kw):
    p = dict(Texture=tex(texture), **FLAT, Lifetime=NR(life), Size=NS((0, size0), (0.25, size0 + (size1 - size0) * 0.8), (1, size1)),
             Transparency=NS((0, 0), (0.5, 0.1), (1, 1)), Color=color, LightEmission=le, ZOffset=0.2)
    p.update(kw)
    return pe(name, attrs=attrs, **p)


def pop(texture="sprites/impacts/starburst_cel_00", size=4.5, color=None, life=0.1, **kw):
    p = dict(Texture=tex(texture), Lifetime=NR(life), Speed=NR(0), Rotation=NR(0, 360), Size=NS((0, size * 0.75), (1, size)),
             Color=color or CS((0, WHITE), (1, CREAM)), LightEmission=0.4, ZOffset=1)
    p.update(kw)
    return pe("Pop", **p)


def toss(name, texture, size, color, speed=(14, 22), spread=(40, 40), grav=-50, life=(0.55, 0.8), **kw):
    """Things thrown up out of the landing that fall back."""
    p = dict(Texture=tex(texture), EmissionDirection=TOP, SpreadAngle=V2(*spread), Speed=NR(*speed), Acceleration=V3(0, grav, 0),
             Lifetime=NR(*life), Rotation=NR(0, 360), RotSpeed=NR(-300, 300), Size=size, Color=color, ZOffset=0.5)
    p.update(kw)
    return pe(name, **p)


def rise(name, texture, size, color, speed=(3, 6), life=(0.7, 1.1), spread=(18, 18), **kw):
    """Residue that drifts up out of the dish."""
    p = dict(Texture=tex(texture), EmissionDirection=TOP, SpreadAngle=V2(*spread), Speed=NR(*speed), Drag=1.2, Lifetime=NR(*life),
             Size=size, Color=color, Transparency=NS((0, 1), (0.15, 0.2), (0.7, 0.35), (1, 1)))
    p.update(kw)
    return pe(name, **p)


def land_effect(name, note, col, hit, ground, emits, pil=None, lamp=None, shake=0.0, extra=(), after=None, dur=1.5, beats=(),
                food_col=None, tint=False):
    """hit = emitters at the dish (0.9 up); ground = flat emitters on the floor; emits = [(path, count, t)].
    pil = pillar(...) result or None; after(tl) adds more events."""
    tl = TL()
    inst = [carrier("Hit", (0, 0.9, 0, 0, 0, 0), [att("A", children=list(hit))]),
            carrier("Ground", (0, 0.12, 0, 0, 0, 0), [att("A", children=list(ground))])]
    inst += list(extra)
    if pil:
        inst.append(pil[0])
        pillar_events(tl, pil[1], pil[2])
    if lamp:
        inst.append(light("Lamp", (0, 3, 0, 0, 0, 0), lamp, 16))
        tl.at(0, do="set", target="Lamp.L", prop="Brightness", value=2.2)
        tl.at(0.02, do="tween", target="Lamp.L", prop="Brightness", to=0, time=0.45, style="Quad", dir="Out")
    for path, n, t in emits:
        tl.at(t, do="emit", target=path, count=n)
    if shake:
        tl.at(0, do="shake", amp=shake, time=0.3, freq=24)
    if after:
        after(tl)
    inst.append({"class": "Part", "name": "SimFood", "CFrame": [0, 1.3, 0, 0, 0, 0], "Size": [3.6, 2.4, 3.6], "Shape": "Ball",
                 "Transparency": 0, "props": {"Color": C3(food_col or mix(col, WHITE, 0.3))}, "children": [], "sim": True})
    d = {"name": name, "note": note, "duration": dur, "camera": {"pos": [5, 4.5, 17], "at": [0, 4.5, 0]},
         "stage": {"ground": "light", "dummy": False}, "stripFloors": ["#F4EBD0"],
         "game": {"loop": False, "attach": "point", "screen": bool(shake)},
         "brief": {"category": "impact", "tier": "skill", "style": "stylised_game", "shape": "burst + pillar in the dish's colour",
                   "dominant": hx(col), "accent": "#FFFFFF", "signature_beats": list(beats) or ["shape born at full size"],
                   "phases": [{"name": "release", "t0": 0, "t1": 1 / 60}, {"name": "sustain", "t0": 1 / 60, "t1": 0.45},
                              {"name": "residue", "t0": 0.45, "t1": dur}]},
         "instances": inst, "timeline": tl}
    _ = tint
    return write(d, [0.0, 0.04, 0.1, 0.2, 0.35, 0.55, 0.8, 1.1])


# ------------------------------------------------------------------------------------ meal, aroma, favourite
def meal():
    """Meal: a streak in the food's colour and sparks that ride with it; landing = ring + aroma wisps."""
    core, edge, tip = hexc("FF9A3D"), hexc("8A2C0A"), hexc("FFF1B8")
    layers = [
        wake("Sparks", "flipbooks/specks/sparks_glow_00_8x8", 26, NS((0, 2.2), (1, 3.4)), CS((0, WHITE), (0.3, tip), (1, core)), attrs={"Tint": True},
             life=(0.28, 0.4), speed=(9, 15), spread=(20, 20), Rotation=NR(0, 360), LightEmission=0.5, **dict(FB8, FlipbookFramerate=NR(64 / 0.35))),
        wake("Glints", "sprites/stars/star_glow_04", 18, NS((0, 0), (0.25, 1.1), (1, 0)), CS((0, WHITE), (1, tip)), attrs={"Tint": True},
             life=(0.25, 0.4), speed=(6, 18), spread=(26, 26), Rotation=NR(0, 90), RotSpeed=NR(-200, 200), LightEmission=0.6),
    ]
    trail_effect("ThrowTrail_Meal", "Meal flight: tintable streak + sparks that ride with the food.", (core, edge, tip), layers, W=3.2,
                 tint=True, beats=["sparks stream off the dish"])
    dust = hexc("F1E6C8")
    hit = [
        pop(size=4.6),
        pe("Dust", Texture=tex("flipbooks/smoke/smoke_puff_fb_cel_03_4x4"), **fb(0.55), EmissionDirection=TOP, SpreadAngle=V2(88, 88),
           Speed=NR(12, 18), Drag=5, Acceleration=V3(0, 1.5, 0), Lifetime=NR(0.45, 0.6), Rotation=NR(0, 360), Size=NS((0, 2.4), (0.3, 3.6), (1, 4.0)),
           Transparency=FADE, Color=CS((0, WHITE), (1, dust)), LightEmission=0, ZOffset=0.3),
        toss("Sparks", "sprites/stars/star_cel_01", NS((0, 0.6), (0.1, 1.3), (0.8, 1.1), (1, 0)), CS((0, WHITE), (0.2, tip), (1, core)), LightEmission=0.3,
             attrs_=None),
        rise("Aroma", "tfa/aroma_wave", NS((0, 1.6), (1, 3.4)), CS((0, WHITE), (1, tip)), speed=(4, 6.5), life=(0.8, 1.1), spread=(24, 24),
             Rotation=NR(-12, 12), LightEmission=0.3, ZOffset=0.6),
    ]
    hit[2]["props"].pop("attrs_")
    for i in (2, 3):
        hit[i]["attrs"] = {"Tint": True}
    ground = [ring("Ring", "sprites/rings/ring_cel_08", 4, 10, CS((0, WHITE), (1, core)), life=0.4, attrs={"Tint": True}),
              ring("Ring2", "sprites/rings/ring_glow_02", 2, 7, CS(tip), life=0.5, le=0.5, attrs={"Tint": True})]
    land_effect("Land_Meal", "A Meal lands: pop, dust, a ring in the food's colour and aroma wisps.", core, hit, ground,
                [("Hit.A.Pop", 1, 0), ("Hit.A.Dust", 8, 0), ("Hit.A.Sparks", 6, 0), ("Ground.A.Ring", 1, 0), ("Ground.A.Ring2", 1, 0.06),
                 ("Hit.A.Aroma", 2, 0.12), ("Hit.A.Aroma", 2, 0.3), ("Hit.A.Aroma", 1, 0.5)], dur=1.5, beats=["aroma lines rise out of the dish"])


def aroma():
    """Loops on the resting dish until the hero picks it up. Meal: a few aroma lines. Signature: more
    lines, glints and a breathing glow on the floor. Both take the food's colour."""
    for name, lines, extra in (("Aroma_Meal", 2.2, False), ("Aroma_Signature", 3.4, True)):
        # all-white lines: the tint (the dish's own colour) then colours them fully. White lines over
        # the lane's pale floors washed out in the game.
        col, tip = hexc("FFD27A"), hexc("FFF6D8")
        a = [pe("Lines", attrs={"Tint": True}, Texture=tex("tfa/aroma_wave"), Rate=lines, EmissionDirection=TOP, SpreadAngle=V2(16, 16), Speed=NR(2.4, 3.6),
                Lifetime=NR(1.1, 1.5), Rotation=NR(-10, 10), RotSpeed=NR(-8, 8), Size=NS((0, 1.8), (0.5, 3.6), (1, 4.6)),
                Transparency=NS((0, 1), (0.18, 0.05), (0.65, 0.2), (1, 1)), Color=CS(WHITE), LightEmission=0.15, ZOffset=0.6)]
        g = []
        if extra:
            a.append(pe("Glints", attrs={"Tint": True}, Texture=tex("sprites/stars/star_glow_04"), Rate=7, EmissionDirection=TOP, SpreadAngle=V2(50, 50),
                        Speed=NR(2, 5), Lifetime=NR(0.6, 0.9), Rotation=NR(0, 90), Size=NS((0, 0), (0.3, 0.9), (1, 0)),
                        Color=CS((0, WHITE), (1, col)), LightEmission=0.7, ZOffset=0.8))
            g.append(pe("Glow", attrs={"Tint": True}, Texture=tex("sprites/rings/ring_glow_02"), **FLAT, Rate=1.4, Lifetime=NR(1.2),
                        Size=NS((0, 3.5), (1, 8.5)), Transparency=NS((0, 1), (0.2, 0.35), (1, 1)), Color=CS(col), LightEmission=0.5, ZOffset=0.2))
        inst = [carrier("Dish", (0, 1.6, 0, 0, 0, 0), [att("A", children=a)]), carrier("Floor", (0, 0.12, 0, 0, 0, 0), [att("A", children=g)]),
                {"class": "Part", "name": "SimFood", "CFrame": [0, 1.3, 0, 0, 0, 0], "Size": [3.6, 2.4, 3.6], "Shape": "Ball", "Transparency": 0,
                 "props": {"Color": C3(hexc("E8A04A"))}, "children": [], "sim": True}]
        d = {"name": name, "note": "Aroma over the resting dish (loop until picked up).", "duration": 2.4,
             "camera": {"pos": [4, 3.5, 12], "at": [0, 3, 0]}, "stage": {"ground": "light", "dummy": False}, "stripFloors": ["#F4EBD0"],
             "game": {"loop": True, "attach": "point", "screen": False},
             "brief": {"category": "ambient_pickup", "tier": "basic", "style": "stylised_game", "shape": "aroma lines", "dominant": hx(col),
                       "accent": "#FFFFFF", "signature_beats": ["wavy aroma lines"], "phases": [{"name": "sustain", "t0": 0, "t1": 2.4}]},
             "instances": inst, "timeline": TL()}
        write(d, [0.6, 1.0, 1.4, 1.8, 2.2])


def favourite():
    """The hero's favourite dish: hearts and sparkles burst round the hero at the reveal."""
    pink, hot = hexc("FF5FA2"), hexc("FF2D78")
    a = [
        pe("Hearts", Texture=tex("sprites/shapes/heart_cel_03"), EmissionDirection=TOP, SpreadAngle=V2(55, 55), Speed=NR(9, 15), Drag=3,
           Acceleration=V3(0, 5, 0), Lifetime=NR(0.9, 1.3), Rotation=NR(-25, 25), RotSpeed=NR(-40, 40),
           Size=NS((0, 0), (0.12, 2.2), (0.8, 1.8), (1, 0)), Color=CS((0, hexc("FFD3E4")), (0.3, pink), (1, hot)), LightEmission=0.2, ZOffset=1),
        pe("BigHeart", Texture=tex("sprites/shapes/heart_glow_03"), Speed=NR(0), Lifetime=NR(0.5), Rotation=NR(-6, 6),
           Size=NS((0, 2), (0.15, 6.5), (0.6, 6), (1, 7.5)), Transparency=NS((0, 0), (0.6, 0.15), (1, 1)), Color=CS((0, WHITE), (0.3, pink), (1, hot)),
           LightEmission=0.45, ZOffset=2),
        pe("Twinkle", Texture=tex("sprites/stars/star_glow_00"), SpreadAngle=V2(180, 180), Speed=NR(8, 16), Drag=4, Lifetime=NR(0.4, 0.7),
           Rotation=NR(0, 90), Size=NS((0, 0), (0.2, 1.3), (1, 0)), Color=CS((0, WHITE), (1, hexc("FFE680"))), LightEmission=0.7, ZOffset=1.5),
    ]
    g = [ring("Ring", "sprites/rings/ring_cel_02", 3, 11, CS((0, WHITE), (1, pink)), life=0.45)]
    inst = [carrier("Hit", (0, 3.2, 0, 0, 0, 0), [att("A", children=a)]), carrier("Ground", (0, 0.12, 0, 0, 0, 0), [att("A", children=g)])]
    tl = TL()
    for tgt, n, t in (("Hit.A.BigHeart", 1, 0), ("Hit.A.Hearts", 9, 0), ("Hit.A.Twinkle", 12, 0), ("Ground.A.Ring", 1, 0), ("Hit.A.Hearts", 4, 0.25)):
        tl.at(t, do="emit", target=tgt, count=n)
    d = {"name": "Favourite_Burst", "note": "The caught hero's favourite dish: hearts round the hero.", "duration": 1.6,
         "camera": {"pos": [5, 5, 15], "at": [0, 3.5, 0]}, "stage": {"ground": "light", "dummy": True},
         "game": {"loop": False, "attach": "point", "screen": False},
         "brief": {"category": "ambient_pickup", "tier": "basic", "style": "stylised_game", "shape": "heart pop", "dominant": hx(pink),
                   "accent": "#FFFFFF", "signature_beats": ["pop to max in one frame"],
                   "phases": [{"name": "release", "t0": 0, "t1": 1 / 60}, {"name": "sustain", "t0": 1 / 60, "t1": 0.5}, {"name": "residue", "t0": 0.5, "t1": 1.6}]},
         "instances": inst, "timeline": tl}
    write(d, [0.0, 0.05, 0.12, 0.25, 0.4, 0.6, 0.9, 1.2])


# ------------------------------------------------------------------------------------ the 17 Signature dishes
def steam(name, rate, size=(2.6, 5.0), col=WHITE, life=(0.35, 0.5), alpha=0.35, **kw):
    return wake(name, "sprites/smoke/smoke_puff_soft_02", rate, NS((0, size[0]), (1, size[1])), CS((0, col), (1, mix(col, WHITE, 0.5))),
                life=life, speed=(7, 12), spread=(22, 22), Rotation=NR(0, 360), RotSpeed=NR(-60, 60),
                Transparency=NS((0, alpha), (0.6, alpha + 0.2), (1, 1)), LightEmission=0.05, ZOffset=1.0, **kw)


def sig_legend_ramen():
    red, dark, cream, pink = hexc("E23A2E"), hexc("7A1410"), hexc("FFF3DA"), hexc("FF6098")
    layers = [
        steam("Steam", 22),
        wake("Swirls", "tfa/narutomaki", 7, NS((0, 0.8), (0.25, 2.0), (1, 2.3)), CS(WHITE), life=(0.5, 0.6), speed=(9, 12), spread=(24, 24),
             Rotation=NR(0, 360), RotSpeed=NR(380, 520), Transparency=NS((0, 0), (0.75, 0), (1, 1)), ZOffset=0.5),
        halo("Ring", "sprites/swirls/swirl_glow_03", 2.4, NS((0, 4.5), (1, 6.5)), CS((0, WHITE), (1, pink)), life=0.45, Rotation=NR(0, 360),
             RotSpeed=NR(-420), Transparency=NS((0, 1), (0.3, 0.35), (1, 1)), LightEmission=0.4),
    ]
    trail_effect("Sig_legend_ramen_Trail", "Legendary Ramen: steam spiral and spinning fish-cake swirls.", (red, dark, cream), layers,
                 beats=["fish-cake slices spin in the wake"])
    hit = [
        pop(size=5),
        pe("Steam", Texture=tex("flipbooks/smoke/smoke_puff_fb_soft_02_4x4"), **fb(0.8), EmissionDirection=TOP, SpreadAngle=V2(70, 70), Speed=NR(9, 15),
           Drag=3.5, Acceleration=V3(0, 5, 0), Lifetime=NR(0.7, 0.95), Rotation=NR(0, 360), Size=NS((0, 3), (0.3, 5.5), (1, 7)),
           Transparency=NS((0, 0.2), (0.6, 0.45), (1, 1)), Color=CS((0, WHITE), (1, cream)), LightEmission=0.05, ZOffset=0.3),
        toss("Swirls", "tfa/narutomaki", NS((0, 0.8), (0.12, 2.4), (0.8, 2.2), (1, 0)), CS(WHITE), speed=(15, 22), spread=(38, 38), grav=-46,
             life=(0.75, 0.95), RotSpeed=NR(-500, 500)),
        pe("Spiral", Texture=tex("sprites/swirls/swirl_cel_03"), Speed=NR(0), Lifetime=NR(0.5), Rotation=NR(0, 360), RotSpeed=NR(-540),
           Size=NS((0, 3), (0.2, 8), (1, 10)), Transparency=NS((0, 0), (0.6, 0.2), (1, 1)), Color=CS((0, WHITE), (0.4, pink), (1, red)),
           LightEmission=0.3, ZOffset=0.8),
        rise("Aroma", "tfa/aroma_wave", NS((0, 1.6), (1, 3.6)), CS((0, WHITE), (1, cream)), speed=(4, 6.5), spread=(24, 24), Rotation=NR(-12, 12),
             LightEmission=0.3, ZOffset=0.6),
    ]
    ground = [ring("Ring", "sprites/rings/ring_cel_08", 4, 12, CS((0, WHITE), (1, pink))), ring("Ring2", "sprites/rings/ring_glow_02", 3, 9, CS(red), life=0.5, le=0.4)]
    land_effect("Sig_legend_ramen_Land", "Legendary Ramen lands: steam burst, fish-cake slices, a pink swirl.", red, hit, ground,
                [("Hit.A.Pop", 1, 0), ("Hit.A.Steam", 9, 0), ("Hit.A.Swirls", 6, 0), ("Hit.A.Spiral", 1, 0), ("Ground.A.Ring", 1, 0), ("Ground.A.Ring2", 1, 0.06),
                 ("Hit.A.Aroma", 2, 0.15), ("Hit.A.Aroma", 2, 0.35), ("Hit.A.Aroma", 2, 0.6)],
                pil=pillar(mix(red, pink, 0.4), H=12), lamp=hexc("FFB199"), food_col=red)


def sig_flame_bento():
    org, dark, tip = hexc("FF6A14"), hexc("8E1508"), hexc("FFE36B")
    layers = [
        wake("Flames", "flipbooks/fire/fire_burst_hot_01_4x4", 30, NS((0, 3.4), (1, 6.0)), CS(WHITE), life=(0.32, 0.42), speed=(9, 14), spread=(14, 14),
             Rotation=NR(0, 360), LightEmission=0.45, **fb(0.4)),
        wake("Tongues", "sprites/elements/flame_hot_04", 18, NS((0, 3.8), (1, 1.0)), CS(WHITE), life=(0.25, 0.35), speed=(14, 20), spread=(8, 8),
             LightEmission=0.5, **STREAK),
        wake("Embers", "sprites/specks/ember_glow_00", 26, NS((0, 0.9), (1, 0)), CS((0, tip), (1, hexc("E2481B"))), life=(0.35, 0.6), speed=(8, 20),
             spread=(34, 34), LightEmission=0.6),
    ]
    trail_effect("Sig_flame_bento_Trail", "Flame Bento: a tail of flame and embers.", (org, dark, tip), layers, glow="beams/fire_trail_hot_02",
                 beats=["a tail of fire"])
    hit = [
        pop("sprites/impacts/starburst_glow_00", size=6, color=CS((0, WHITE), (1, tip)), LightEmission=0.6),
        # hard-edged cel flames (the soft "hot" flipbook came out as a pale yellow cloud in the game)
        pe("Fire", Texture=tex("sprites/elements/flame_cel_05"), EmissionDirection=TOP, SpreadAngle=V2(42, 42), Speed=NR(15, 26), Drag=2.2, Lifetime=NR(0.4, 0.6),
           Size=NS((0, 2.8), (0.3, 5.6), (1, 1.6)), Color=CS((0, tip), (0.25, org), (1, hexc("C4260B"))), Transparency=NS((0, 0), (0.7, 0.1), (1, 1)),
           LightEmission=0.2, ZOffset=0.5, **STREAK),
        pe("Glow", Texture=tex("sprites/elements/flame_glow_05"), Speed=NR(0), Lifetime=NR(0.5), Size=NS((0, 5), (0.25, 12), (1, 9)),
           Transparency=NS((0, 0.5), (0.6, 0.65), (1, 1)), Color=CS((0, org), (1, hexc("C4260B"))), LightEmission=0.3, ZOffset=-3),
        toss("Embers", "sprites/specks/ember_glow_00", NS((0, 1.0), (0.7, 0.8), (1, 0)), CS((0, tip), (0.5, org), (1, hexc("C4260B"))), speed=(16, 28),
             spread=(50, 50), grav=-40, life=(0.7, 1.1), LightEmission=0.6),
        pe("Smoke", Texture=tex("flipbooks/smoke/smoke_puff_fb_cel_03_4x4"), **fb(0.9), EmissionDirection=TOP, SpreadAngle=V2(30, 30), Speed=NR(5, 8), Drag=1.5,
           Lifetime=NR(0.8, 1.0), Rotation=NR(0, 360), Size=NS((0, 2.5), (1, 5.5)), Transparency=NS((0, 0.35), (0.6, 0.55), (1, 1)),
           Color=CS((0, hexc("5B4A42")), (1, hexc("8C7B72"))), LightEmission=0, ZOffset=-0.2),
    ]
    ground = [ring("Ring", "sprites/rings/ring_spiked_cel_02", 4, 12, CS((0, tip), (1, org)), le=0.4), ring("Scorch", "sprites/impacts/splat_cel_02", 5, 7,
              CS(hexc("3A1A10")), life=1.2, le=0, Transparency=NS((0, 0.25), (0.6, 0.4), (1, 1)), Rotation=NR(0, 360))]
    land_effect("Sig_flame_bento_Land", "Flame Bento lands: fire burst, ember fountain, a scorch mark.", org, hit, ground,
                [("Hit.A.Pop", 1, 0), ("Hit.A.Glow", 1, 0), ("Hit.A.Fire", 9, 0), ("Hit.A.Embers", 22, 0), ("Ground.A.Ring", 1, 0), ("Ground.A.Scorch", 1, 0.03),
                 ("Hit.A.Fire", 6, 0.15), ("Hit.A.Fire", 4, 0.3), ("Hit.A.Smoke", 4, 0.3)],
                pil=pillar(org, core=tip, H=12), lamp=org, food_col=hexc("C4260B"))


def sig_swirl_fruit():
    vio, dark, tip = hexc("9A4DFF"), hexc("2A0A52"), hexc("E7CCFF")
    layers = [
        wake("Spirals", "sprites/swirls/swirl_cel_05", 9, NS((0, 2.2), (1, 6.4)), CS((0, tip), (0.3, vio), (1, dark)), life=(0.4, 0.5), speed=(12, 14),
             spread=(0, 0), Rotation=NR(0, 360), RotSpeed=NR(520, 640), Transparency=NS((0, 0), (0.6, 0.2), (1, 1)), LightEmission=0.2, **PERP),
        wake("Vortex", "sprites/swirls/vortex_glow_02", 4, NS((0, 3), (1, 7.5)), CS((0, vio), (1, dark)), life=(0.45, 0.5), speed=(9, 10), spread=(0, 0),
             Rotation=NR(0, 360), RotSpeed=NR(-360), Transparency=NS((0, 0.3), (1, 1)), LightEmission=0.35, **PERP),
        wake("Motes", "sprites/specks/dot_glow_00", 20, NS((0, 0.9), (1, 0)), CS((0, WHITE), (1, vio)), life=(0.3, 0.5), speed=(8, 18), spread=(30, 30),
             LightEmission=0.6),
    ]
    trail_effect("Sig_swirl_fruit_Trail", "Swirl Fruit: purple spirals turning in the wake.", (vio, dark, tip), layers, beats=["a tunnel of turning spirals"])
    # seen in the game: a dark pulse on a dark floor, hidden behind the fruit, read as nothing. The
    # landing is the fruit's own spiral: one big turning spiral BEHIND the fruit (it frames it), a
    # spiral spinning flat on the floor, motes pulled in, then the dark ring and violet wisps.
    hit = [
        pe("Spiral", Texture=tex("sprites/swirls/swirl_cel_05"), Speed=NR(0), Lifetime=NR(0.7), Rotation=NR(0, 360), RotSpeed=NR(-520),
           Size=NS((0, 4), (0.15, 13), (0.8, 14), (1, 16)), Transparency=NS((0, 0), (0.7, 0.1), (1, 1)), Color=CS((0, tip), (0.25, vio), (1, dark)),
           LightEmission=0.2, ZOffset=-2.5),
        pe("Spiral2", Texture=tex("sprites/swirls/vortex_glow_02"), Speed=NR(0), Lifetime=NR(0.6), Rotation=NR(0, 360), RotSpeed=NR(380),
           Size=NS((0, 3), (0.2, 9), (1, 11)), Transparency=NS((0, 0.2), (0.7, 0.35), (1, 1)), Color=CS((0, WHITE), (0.3, tip), (1, vio)),
           LightEmission=0.4, ZOffset=-2),
        pe("Motes", Texture=tex("sprites/specks/dot_glow_00"), Shape=E("ParticleEmitterShape.Sphere"), ShapeInOut=E("ParticleEmitterShapeInOut.Inward"),
           Speed=NR(12, 18), Lifetime=NR(0.35, 0.5), Size=NS((0, 1.4), (1, 0)), Color=CS((0, tip), (1, vio)), LightEmission=0.6),
        toss("Wisps", "sprites/elements/tendril_cel_03", NS((0, 1.5), (0.3, 3.6), (1, 0)), CS((0, tip), (0.3, vio), (1, dark)), speed=(9, 15), spread=(60, 60), grav=-8,
             life=(0.6, 0.9), LightEmission=0.15),
        pop("sprites/impacts/starburst_cel_00", size=6, color=CS((0, WHITE), (1, tip)), LightEmission=0.4),
    ]
    ground = [pe("Floor", Texture=tex("sprites/swirls/swirl_cel_03"), **FLAT, Lifetime=NR(0.75), Rotation=NR(0, 360), RotSpeed=NR(460),
                 Size=NS((0, 4), (0.2, 13), (1, 14.5)), Transparency=NS((0, 0), (0.7, 0.1), (1, 1)), Color=CS((0, tip), (0.3, vio), (1, dark)),
                 LightEmission=0.25, ZOffset=0.25),
              ring("Dark", "sprites/rings/ring_cel_02", 3, 13, CS((0, dark), (1, BLACK)), le=0, life=0.5),
              ring("Ring", "sprites/rings/ring_cel_08", 2, 12, CS((0, tip), (1, vio)), le=0.3, life=0.4)]
    extra = [carrier("Shell", (0, 1.2, 0, 0, 0, 0), [hit.pop(2)], size=(13, 13, 13))]
    land_effect("Sig_swirl_fruit_Land", "Swirl Fruit lands: its spiral turns behind it and on the floor, motes pulled in, a dark ring.", vio, hit, ground,
                [("Shell.Motes", 26, 0), ("Hit.A.Pop", 1, 0), ("Hit.A.Spiral", 1, 0), ("Hit.A.Spiral2", 1, 0.04), ("Ground.A.Floor", 1, 0), ("Ground.A.Dark", 1, 0.1),
                 ("Ground.A.Ring", 1, 0.14), ("Hit.A.Wisps", 8, 0.12)],
                pil=pillar(vio, core=tip, H=12), lamp=vio, extra=extra, food_col=vio, beats=["the fruit's spiral turns behind it"])


def sig_mapo_tofu():
    red, dark, tip = hexc("F0431F"), hexc("7A1206"), hexc("FFD36B")
    pops = pe("Pops", Texture=tex("flipbooks/impacts/comic_pop_cel_01_4x4"), **fb(0.26), Rate=16, LockedToPart=True, Speed=NR(6, 10), EmissionDirection=BACK,
              Shape=E("ParticleEmitterShape.Box"), Lifetime=NR(0.24, 0.28), Rotation=NR(0, 360), Size=NS((0, 3.4), (1, 5.6)),
              Color=CS((0, tip), (0.4, hexc("FF8A1F")), (1, red)), LightEmission=0.35, ZOffset=1.5)
    layers = [
        wake("Chili", "sprites/specks/ember_cel_01", 24, NS((0, 1.6), (1, 0)), CS((0, tip), (1, red)), life=(0.3, 0.5), speed=(8, 18), spread=(32, 32),
             LightEmission=0.4),
        wake("Puffs", "flipbooks/smoke/smoke_puff_fb_cel_03_4x4", 12, NS((0, 1.8), (1, 3.4)), CS((0, hexc("FFB36B")), (1, red)), life=(0.3, 0.4), speed=(8, 12),
             Rotation=NR(0, 360), Transparency=NS((0, 0.2), (1, 1)), LightEmission=0.15, **fb(0.38)),
    ]
    extra = [carrier("PopBox", (0, 5, 3.2, 0, 0, 0), [pops], size=(5, 3.4, 4))]
    trail_effect("Sig_mapo_tofu_Trail", "Explosion Mapo Tofu: little orange blasts popping along the path.", (red, dark, tip), layers,
                 glow="beams/fire_trail_hot_02", extra=extra, beats=["comic pops burst behind the dish"])
    hit = [
        pop("sprites/impacts/comic_burst_cel_02", size=9, color=CS((0, WHITE), (0.5, tip), (1, hexc("FF8A1F"))), life=0.16, LightEmission=0.4),
        pe("Blast", Texture=tex("flipbooks/impacts/comic_pop_cel_01_4x4"), **fb(0.34), Speed=NR(0), Lifetime=NR(0.34),
           Rotation=NR(-20, 20), Size=NS((0, 8), (0.3, 13), (1, 14)), Color=CS((0, tip), (0.35, hexc("FF8A1F")), (1, red)), LightEmission=0.3, ZOffset=1.2),
        pe("Pops", Texture=tex("flipbooks/impacts/comic_pop_cel_01_4x4"), **fb(0.3), EmissionDirection=TOP, SpreadAngle=V2(70, 70), Speed=NR(10, 18), Drag=4,
           Lifetime=NR(0.28, 0.32), Rotation=NR(0, 360), Size=NS((0, 3.5), (1, 6.5)), Color=CS((0, tip), (0.35, hexc("FF8A1F")), (1, red)), LightEmission=0.3,
           ZOffset=1.5),
        toss("Chili", "sprites/specks/ember_cel_01", NS((0, 1.2), (0.8, 1.0), (1, 0)), CS((0, tip), (1, red)), speed=(18, 30), spread=(65, 65), grav=-45,
             life=(0.6, 0.95), LightEmission=0.4),
        pe("Smoke", Texture=tex("flipbooks/smoke/smoke_puff_fb_cel_03_4x4"), **fb(0.8), EmissionDirection=TOP, SpreadAngle=V2(80, 80), Speed=NR(10, 16), Drag=4,
           Lifetime=NR(0.7, 0.9), Rotation=NR(0, 360), Size=NS((0, 3), (1, 5.5)), Transparency=NS((0, 0.3), (0.6, 0.5), (1, 1)),
           Color=CS((0, hexc("6B4A3E")), (1, hexc("9A8076"))), LightEmission=0, ZOffset=-0.2),
    ]
    ground = [ring("Shock", "sprites/rings/ring_spiked_cel_02", 5, 15, CS((0, tip), (0.4, hexc("FF8A1F")), (1, red)), life=0.4, le=0.3),
              ring("Ring", "sprites/rings/ring_cel_08", 4, 12, CS((0, WHITE), (1, hexc("FF8A1F"))), life=0.35)]
    land_effect("Sig_mapo_tofu_Land", "Explosion Mapo Tofu lands: a small comic blast.", red, hit, ground,
                [("Hit.A.Pop", 1, 0), ("Hit.A.Blast", 1, 0), ("Hit.A.Chili", 18, 0), ("Ground.A.Shock", 1, 0), ("Ground.A.Ring", 1, 0.04), ("Hit.A.Pops", 4, 0.08),
                 ("Hit.A.Smoke", 7, 0.1), ("Hit.A.Pops", 3, 0.2)],
                pil=pillar(hexc("FF6A1F"), core=tip, H=11), lamp=hexc("FF8A1F"), shake=0.25, food_col=hexc("B32A12"), beats=["one clean blast"])


def sig_rank_one_steak():
    blue, dark, tip = hexc("1F8BFF"), hexc("0A2A7A"), hexc("CFEAFF")
    layers = [
        wake("Lines", "sprites/specks/streak_cel_00", 46, NS((0, 6.0), (1, 2.4)), CS((0, WHITE), (0.2, tip), (0.6, blue), (1, dark)), life=(0.16, 0.24), speed=(34, 52),
             spread=(9, 9), LightEmission=0.45, **STREAK),
        wake("Darts", "sprites/shapes/chevron_cel_00", 9, NS((0, 2.4), (1, 4.2)), CS((0, tip), (1, blue)), life=(0.28, 0.34), speed=(16, 20), spread=(0, 0),
             Transparency=NS((0, 0), (0.6, 0.2), (1, 1)), LightEmission=0.3, **PERP),
        wake("Stars", "sprites/stars/star_cel_01", 8, NS((0, 0.4), (0.3, 1.3), (1, 0)), CS((0, hexc("FFF3B0")), (1, GOLD)), life=(0.35, 0.5), speed=(8, 16),
             spread=(28, 28), Rotation=NR(0, 360), RotSpeed=NR(-240, 240), LightEmission=0.3),
    ]
    box = pe("Wind", Texture=tex("sprites/specks/streak_cel_02"), Rate=30, LockedToPart=True, EmissionDirection=BACK, Shape=E("ParticleEmitterShape.Box"),
             Speed=NR(40, 60), Lifetime=NR(0.14, 0.2), Size=NS((0, 8), (1, 3)), Color=CS((0, WHITE), (0.4, blue), (1, dark)), Transparency=NS((0, 0.05), (1, 1)),
             LightEmission=0.3, ZOffset=1.5, **STREAK)
    extra = [carrier("WindBox", (0, 5, 0, 0, 0, 0), [box], size=(8, 5.5, 2))]
    trail_effect("Sig_rank_one_steak_Trail", "Rank One Steak: blue speed lines racing past.", (blue, dark, tip), layers, extra=extra,
                 beats=["speed lines race past the dish"])
    hit = [
        pop("sprites/impacts/speed_lines_cel_02", size=13, color=CS((0, WHITE), (1, tip)), life=0.2, LightEmission=0.45),
        pe("One", Texture=tex("tfa/numeral_one"), EmissionDirection=TOP, Speed=NR(5.5), Drag=2.2, Lifetime=NR(0.95), Rotation=NR(0), SpreadAngle=V2(0, 0),
           Size=NS((0, 1.5), (0.1, 7.6), (0.2, 6.2), (0.8, 6.2), (1, 7.5)), Transparency=NS((0, 0), (0.8, 0), (1, 1)), Color=CS(WHITE), ZOffset=3),
        pe("Shine", Texture=tex("sprites/flares/flare_glow_01"), Speed=NR(0), Lifetime=NR(0.3), Rotation=NR(0, 45), Size=NS((0, 4), (0.3, 12), (1, 9)),
           Transparency=NS((0, 0.1), (1, 1)), Color=CS((0, WHITE), (1, GOLD)), LightEmission=0.7, ZOffset=2),
        toss("Stars", "sprites/stars/star_cel_01", NS((0, 0.6), (0.1, 1.5), (0.8, 1.2), (1, 0)), CS((0, WHITE), (0.2, GOLD), (1, hexc("FF9A3D"))), speed=(16, 24),
             spread=(48, 48), LightEmission=0.3),
        pe("Lines", Texture=tex("sprites/specks/streak_cel_00"), EmissionDirection=TOP, SpreadAngle=V2(85, 85), Speed=NR(30, 46), Drag=3, Lifetime=NR(0.25, 0.35),
           Size=NS((0, 3.2), (1, 0.8)), Color=CS((0, WHITE), (1, blue)), LightEmission=0.4, **STREAK),
    ]
    extra2 = [carrier("OneAt", (0, 3.4, 0, 0, 0, 0), [att("A", children=[hit.pop(1), hit.pop(1)])])]
    ground = [ring("Ring", "sprites/rings/ring_cel_08", 4, 13, CS((0, WHITE), (1, blue))), ring("Ring2", "sprites/rings/ring_dashed_cel_00", 3, 10, CS(GOLD), life=0.5, le=0.4)]
    land_effect("Sig_rank_one_steak_Land", "Rank One Steak lands: speed-line burst and a gold number one.", blue, hit, ground,
                [("Hit.A.Pop", 1, 0), ("Hit.A.Lines", 20, 0), ("Hit.A.Stars", 8, 0), ("Ground.A.Ring", 1, 0), ("Ground.A.Ring2", 1, 0.05),
                 ("OneAt.A.One", 1, 0.08), ("OneAt.A.Shine", 1, 0.08)],
                pil=pillar(blue, H=12), lamp=blue, extra=extra2, food_col=hexc("8A4A2A"), beats=["a gold 1 slams up and holds"])


def sig_sheep_feast():
    grn, dark, tip = hexc("7ED957"), hexc("2E6B2A"), hexc("FFFDF2")
    layers = [
        wake("Wool", "sprites/smoke/cloud_cel_01", 15, NS((0, 1.6), (0.4, 3.4), (1, 3.9)), CS((0, WHITE), (1, hexc("F3EDE0"))), life=(0.4, 0.55), speed=(7, 11),
             spread=(20, 20), Rotation=NR(-30, 30), RotSpeed=NR(-60, 60), Transparency=NS((0, 0), (0.7, 0.05), (1, 1)), LightEmission=0.05),
        wake("Clovers", "tfa/clover_cel", 12, NS((0, 0.5), (0.25, 1.9), (0.8, 1.7), (1, 0)), CS((0, hexc("C8F59A")), (1, grn)), life=(0.45, 0.6), speed=(8, 15),
             spread=(28, 28), Rotation=NR(0, 360), RotSpeed=NR(-300, 300), LightEmission=0.2, ZOffset=0.4),
    ]
    trail_effect("Sig_sheep_feast_Trail", "Cotton Sheep Feast: soft wool puffs and clover leaves.", (grn, dark, tip), layers, glow="beams/energy_soft_03",
                 beats=["wool puffs and clovers tumble in the wake"])
    hit = [
        pe("Poof", Texture=tex("flipbooks/magic/magic_poof_cel_01_4x4"), **fb(0.45), Speed=NR(0), Lifetime=NR(0.45), Rotation=NR(0, 360),
           Size=NS((0, 7), (0.3, 13), (1, 14)), Color=CS((0, WHITE), (1, hexc("DCEFD0"))), LightEmission=0.05, ZOffset=0.8),
        pe("Wool", Texture=tex("sprites/smoke/cloud_cel_01"), EmissionDirection=TOP, SpreadAngle=V2(80, 80), Speed=NR(12, 20), Drag=4.5, Acceleration=V3(0, 3, 0),
           Lifetime=NR(0.9, 1.2), Rotation=NR(-30, 30), RotSpeed=NR(-50, 50), Size=NS((0, 2), (0.2, 4.8), (0.8, 4.2), (1, 0)), Color=CS((0, WHITE), (1, hexc("E4DCCB"))),
           LightEmission=0.05, ZOffset=0.3),
        toss("Clovers", "tfa/clover_cel", NS((0, 0.5), (0.15, 2.0), (0.8, 1.8), (1, 0)), CS((0, hexc("C8F59A")), (1, grn)), speed=(14, 21), spread=(45, 45),
             grav=-24, life=(1.0, 1.35), LightEmission=0.2, Drag=1.5),
    ]
    ground = [ring("Ring", "sprites/rings/ring_cel_08", 4, 13, CS((0, hexc("C8F59A")), (1, dark)), le=0.1), ring("Ring2", "sprites/rings/ripple_soft_00", 3, 10, CS(grn), life=0.6, le=0.2)]
    land_effect("Sig_sheep_feast_Land", "Cotton Sheep Feast lands: a wool poof and clovers fluttering down.", grn, hit, ground,
                [("Hit.A.Poof", 1, 0), ("Hit.A.Wool", 12, 0), ("Hit.A.Clovers", 14, 0), ("Ground.A.Ring", 1, 0), ("Ground.A.Ring2", 1, 0.08), ("Hit.A.Clovers", 6, 0.2)],
                pil=pillar(hexc("A8E888"), H=11), lamp=hexc("C8F59A"), food_col=hexc("F3EDE0"), beats=["clovers flutter down slowly"])


def sig_boar_roast():
    amb, dark, tip = hexc("D9792B"), hexc("4A2410"), hexc("FFD9A0")
    smoke_c = CS((0, hexc("5A4336")), (1, hexc("8C7566")))
    back = [
        wake("Smoke", "flipbooks/smoke/smoke_puff_fb_cel_03_4x4", 22, NS((0, 2.2), (1, 5.6)), smoke_c, life=(0.45, 0.6), speed=(7, 11), spread=(22, 22),
             Rotation=NR(0, 360), Transparency=NS((0, 0.15), (0.6, 0.35), (1, 1)), LightEmission=0, **fb(0.55))]
    layers = [
        wake("Embers", "sprites/specks/ember_glow_00", 14, NS((0, 0.9), (1, 0)), CS((0, tip), (1, amb)), life=(0.35, 0.55), speed=(8, 18), spread=(30, 30),
             LightEmission=0.6),
        wake("Grit", "sprites/elements/rock_chunk_cel_02", 6, NS((0, 0.9), (1, 0.5)), CS((0, hexc("8A6A52")), (1, hexc("4A3628"))), life=(0.35, 0.5),
             speed=(10, 18), spread=(26, 26), Rotation=NR(0, 360), RotSpeed=NR(-300, 300)),
    ]
    trail_effect("Sig_boar_roast_Trail", "Giant Boar Roast: a heavy smoke trail.", (amb, dark, tip), layers, W=2.8, back=back, glow="beams/smoke_trail_soft_02",
                 beats=["thick roast smoke rolls off the dish"])
    hit = [
        pop(size=6.5),
        pe("Dust", Texture=tex("flipbooks/smoke/dust_ground_cel_01_4x4"), **fb(0.7), EmissionDirection=TOP, SpreadAngle=V2(89, 89), Speed=NR(16, 24), Drag=4,
           Lifetime=NR(0.65, 0.8), Rotation=NR(0, 360), Size=NS((0, 4), (0.3, 7.5), (1, 9)), Transparency=NS((0, 0), (0.6, 0.2), (1, 1)),
           Color=CS((0, hexc("E9D9B8")), (1, hexc("B79E7C"))), LightEmission=0, ZOffset=0.3),
        toss("Rocks", "sprites/elements/rock_chunk_cel_02", NS((0, 1.6), (0.8, 1.4), (1, 0.6)), CS((0, hexc("9A7C62")), (1, hexc("5A4232"))), speed=(18, 30),
             spread=(42, 42), grav=-70, life=(0.7, 1.0)),
        pe("Smoke", Texture=tex("flipbooks/smoke/smoke_puff_fb_cel_03_4x4"), **fb(1.0), EmissionDirection=TOP, SpreadAngle=V2(25, 25), Speed=NR(5, 9), Drag=1.2,
           Lifetime=NR(0.9, 1.1), Rotation=NR(0, 360), Size=NS((0, 3), (1, 6.5)), Transparency=NS((0, 0.2), (0.6, 0.45), (1, 1)), Color=smoke_c,
           LightEmission=0, ZOffset=-0.2),
    ]
    ground = [ring("CrackGlow", "sprites/cracks/crack_glow_02", 12, 13, CS((0, tip), (1, amb)), life=1.2, le=0.5, Transparency=NS((0, 0.1), (0.6, 0.3), (1, 1)),
                   Rotation=NR(35)),
              ring("Crack", "sprites/cracks/crack_cel_02", 12, 13, CS(hexc("2E1C12")), life=1.3, le=0, Transparency=NS((0, 0), (0.7, 0.1), (1, 1)), Rotation=NR(35),
                   ZOffset=0.3),
              ring("Ring", "sprites/rings/ring_cel_08", 5, 14, CS((0, WHITE), (1, hexc("E9D9B8"))), life=0.4),
              ring("Ring2", "sprites/rings/ring_cel_02", 3, 11, CS(amb), life=0.5, le=0.3)]
    land_effect("Sig_boar_roast_Land", "Giant Boar Roast lands heavy: cracked ground, rocks, a shake.", amb, hit, ground,
                [("Hit.A.Pop", 1, 0), ("Hit.A.Dust", 18, 0), ("Hit.A.Rocks", 9, 0), ("Ground.A.CrackGlow", 1, 0), ("Ground.A.Crack", 1, 0), ("Ground.A.Ring", 1, 0), ("Ground.A.Ring2", 1, 0.07),
                 ("Hit.A.Smoke", 5, 0.2)],
                pil=pillar(amb, core=tip, H=10, W=3.8), lamp=amb, shake=0.55, food_col=hexc("9A4A22"), beats=["the ground cracks and shakes"])


def sig_floor_boss_stew():
    cyn, dark, tip = hexc("22C7FF"), hexc("0B2B6B"), hexc("D6F6FF")
    layers = [
        wake("Shards", "sprites/shards/glass_cel_02", 16, NS((0, 2.0), (0.3, 3.8), (1, 0)), CS((0, tip), (0.3, cyn), (1, dark)), life=(0.35, 0.5), speed=(9, 18),
             spread=(30, 30), Rotation=NR(0, 360), RotSpeed=NR(-420, 420), LightEmission=0.35),
        wake("Grid", "sprites/sigils/hex_grid_glow_00", 5, NS((0, 2.5), (1, 6)), CS((0, tip), (1, cyn)), life=(0.35, 0.4), speed=(12, 13), spread=(0, 0),
             Rotation=NR(0, 60), Transparency=NS((0, 0.15), (0.6, 0.4), (1, 1)), LightEmission=0.5, **PERP),
        wake("Bits", "sprites/specks/dot_cel_00", 16, NS((0, 0.7), (1, 0.3)), CS((0, WHITE), (1, cyn)), life=(0.25, 0.4), speed=(10, 22), spread=(34, 34),
             LightEmission=0.5),
    ]
    trail_effect("Sig_floor_boss_stew_Trail", "Floor Boss Stew: the world breaks into blue polygons behind it.", (cyn, dark, tip), layers,
                 beats=["polygon shards and a hex grid peel off the dish"])
    hit = [
        pop("sprites/impacts/starburst_glow_00", size=6, color=CS((0, WHITE), (1, tip)), LightEmission=0.6),
        pe("Shatter", Texture=tex("flipbooks/shards/shatter_glow_01_4x4"), **fb(0.5), Speed=NR(0), Lifetime=NR(0.5), Rotation=NR(0, 360),
           Size=NS((0, 7), (0.3, 13), (1, 14.5)), Color=CS((0, tip), (0.3, cyn), (1, dark)), LightEmission=0.2, ZOffset=0.8),
        toss("Shards", "sprites/shards/glass_cel_02", NS((0, 1.2), (0.15, 3.2), (0.8, 2.6), (1, 0)), CS((0, tip), (0.3, cyn), (1, dark)), speed=(16, 28),
             spread=(60, 60), grav=-34, life=(0.7, 1.05), LightEmission=0.35, RotSpeed=NR(-500, 500)),
        rise("Bits", "sprites/specks/dot_cel_00", NS((0, 0.8), (1, 0)), CS((0, WHITE), (1, cyn)), speed=(5, 10), life=(0.6, 1.0), spread=(40, 40), LightEmission=0.5),
    ]
    ground = [ring("Grid", "sprites/sigils/hex_grid_cel_00", 6, 16, CS((0, cyn), (1, dark)), life=0.8, le=0.15, Transparency=NS((0, 0), (0.6, 0.15), (1, 1))),
              ring("Ring", "sprites/rings/ring_dashed_cel_00", 4, 12, CS((0, WHITE), (1, cyn)), life=0.4, le=0.4)]
    land_effect("Sig_floor_boss_stew_Land", "Floor Boss Stew lands: the floor shatters into blue polygons.", cyn, hit, ground,
                [("Hit.A.Pop", 1, 0), ("Hit.A.Shatter", 1, 0), ("Hit.A.Shards", 18, 0), ("Ground.A.Grid", 1, 0), ("Ground.A.Ring", 1, 0.04), ("Hit.A.Bits", 10, 0.15)],
                pil=pillar(cyn, H=12), lamp=cyn, food_col=hexc("2A4FA8"), beats=["glass-shatter burst"])


def sig_officers_ham():
    grn, dark, tip = hexc("2F8F5B"), hexc("123A26"), hexc("EAF7E4")
    fea = CS((0, hexc("A6F2C4")), (0.3, hexc("3FCB7E")), (1, grn))
    layers = [
        steam("Steam", 16, alpha=0.4),
        wake("Feathers", "sprites/shapes/feather_cel_02", 15, NS((0, 0.8), (0.2, 2.6), (0.8, 2.3), (1, 0)), fea, life=(0.45, 0.6), speed=(8, 15), spread=(30, 30),
             Rotation=NR(0, 360), RotSpeed=NR(-260, 260), LightEmission=0.25, ZOffset=0.4),
    ]
    wing = dict(Texture=tex("sprites/shapes/feather_cel_05"), Rate=9, LockedToPart=True, Speed=NR(9, 12), Lifetime=NR(0.32, 0.4),
                Size=NS((0, 2.2), (0.4, 4.2), (1, 3.2)), Color=fea, Transparency=NS((0, 0), (0.6, 0.1), (1, 1)), LightEmission=0.1, SpreadAngle=V2(10, 10),
                EmissionDirection=BACK, **STREAK)
    extra = [att("WingL", (-1.2, 0.3, 0, 0, 38, 0), [pe("L", **wing)]), att("WingR", (1.2, 0.3, 0, 0, -38, 0), [pe("R", **wing)])]
    trail_effect("Sig_officers_ham_Trail", "Officer's Ham: steam and green wing feathers swept back like a cape.", (grn, dark, tip), layers,
                 glow="beams/energy_soft_03", extra=extra, beats=["two wings of feathers sweep back"])
    hit = [
        pop(size=5.5),
        pe("Steam", Texture=tex("flipbooks/smoke/smoke_puff_fb_soft_02_4x4"), **fb(0.8), EmissionDirection=TOP, SpreadAngle=V2(60, 60), Speed=NR(8, 13), Drag=3.5,
           Acceleration=V3(0, 5, 0), Lifetime=NR(0.7, 0.9), Rotation=NR(0, 360), Size=NS((0, 3), (1, 6.5)), Transparency=NS((0, 0.25), (0.6, 0.5), (1, 1)),
           Color=CS(WHITE), LightEmission=0.05, ZOffset=0.3),
        toss("Feathers", "sprites/shapes/feather_cel_02", NS((0, 0.8), (0.12, 2.8), (0.85, 2.5), (1, 0)), fea, speed=(15, 24), spread=(50, 50), grav=-22,
             life=(1.1, 1.5), Drag=1.8, RotSpeed=NR(-200, 200), LightEmission=0.1),
    ]
    wingb = dict(Texture=tex("sprites/shapes/feather_cel_05"), Speed=NR(16, 24), Drag=4, Lifetime=NR(0.5, 0.65), Size=NS((0, 2.5), (0.25, 6.2), (1, 4.5)), Color=fea,
                 Transparency=NS((0, 0), (0.6, 0.1), (1, 1)), LightEmission=0.15, SpreadAngle=V2(22, 10), EmissionDirection=TOP, **STREAK)
    extra2 = [carrier("Wings", (0, 1.4, 0, 0, 0, 0), [att("L", (-0.6, 0, 0, 0, 0, 52), [pe("F", **wingb)]), att("R", (0.6, 0, 0, 0, 0, -52), [pe("F", **wingb)])])]
    ground = [ring("Ring", "sprites/rings/ring_cel_08", 4, 12, CS((0, WHITE), (1, grn))), ring("Ring2", "sprites/rings/ring_glow_02", 3, 9, CS(hexc("7AD39A")), life=0.5, le=0.4)]
    land_effect("Sig_officers_ham_Land", "Officer's Ham lands: two wings of green feathers open, steam, feathers drift down.", grn, hit, ground,
                [("Hit.A.Pop", 1, 0), ("Hit.A.Steam", 7, 0), ("Wings.L.F", 7, 0), ("Wings.R.F", 7, 0), ("Hit.A.Feathers", 9, 0.05), ("Ground.A.Ring", 1, 0),
                 ("Ground.A.Ring2", 1, 0.06)],
                pil=pillar(grn, H=12), lamp=hexc("7AD39A"), extra=extra2, food_col=hexc("A0522D"), beats=["wings of feathers open"])


def sig_devil_ice_cream():
    red, dark, tip, ice = hexc("E8232F"), hexc("5A0A12"), hexc("FFE1E4"), hexc("CFEFFF")
    layers = [
        wake("Mist", "sprites/smoke/smoke_puff_soft_02", 20, NS((0, 2.6), (1, 5.4)), CS((0, WHITE), (1, ice)), life=(0.4, 0.55), speed=(7, 11),
             spread=(22, 22), Rotation=NR(0, 360), RotSpeed=NR(-60, 60), Transparency=NS((0, 0.25), (0.6, 0.45), (1, 1)), LightEmission=0.15, ZOffset=1.0),
        wake("Chains", "tfa/chain_ring", 5, NS((0, 2.4), (1, 6.4)), CS((0, hexc("FF6B6B")), (1, red)), life=(0.42, 0.46), speed=(12, 13), spread=(0, 0),
             Rotation=NR(0, 360), RotSpeed=NR(240, 300), Transparency=NS((0, 0), (0.7, 0.1), (1, 1)), LightEmission=0.3, **PERP),
        wake("Flakes", "sprites/elements/snowflake_glow_02", 12, NS((0, 0.4), (0.3, 1.5), (1, 0)), CS((0, WHITE), (1, ice)), life=(0.4, 0.55), speed=(8, 16),
             spread=(30, 30), Rotation=NR(0, 360), RotSpeed=NR(-200, 200), LightEmission=0.5),
        wake("Sparks", "sprites/specks/ember_glow_00", 10, NS((0, 0.8), (1, 0)), CS((0, tip), (1, red)), life=(0.25, 0.4), speed=(10, 20), spread=(32, 32),
             LightEmission=0.6),
    ]
    trail_effect("Sig_devil_ice_cream_Trail", "Devil Ice Cream: cold mist and red chain rings.", (red, dark, tip), layers,
                 beats=["red chain rings slide back through the mist"])
    hit = [
        pop("sprites/impacts/starburst_glow_00", size=5.5, color=CS((0, WHITE), (1, ice)), LightEmission=0.5),
        pe("Mist", Texture=tex("flipbooks/smoke/smoke_puff_fb_soft_02_4x4"), **fb(0.9), EmissionDirection=TOP, SpreadAngle=V2(88, 88), Speed=NR(12, 18), Drag=4.5,
           Lifetime=NR(0.8, 1.0), Rotation=NR(0, 360), Size=NS((0, 3), (1, 7)), Transparency=NS((0, 0.3), (0.6, 0.5), (1, 1)), Color=CS((0, WHITE), (1, ice)),
           LightEmission=0.15, ZOffset=0.3),
        toss("Flakes", "sprites/elements/snowflake_glow_02", NS((0, 0.4), (0.15, 1.7), (0.8, 1.4), (1, 0)), CS((0, WHITE), (1, ice)), speed=(12, 20), spread=(55, 55),
             grav=-18, life=(0.9, 1.3), Drag=1.5, LightEmission=0.5),
        pe("Sparks", Texture=tex("flipbooks/specks/sparks_glow_00_8x8"), **dict(FB8, FlipbookFramerate=NR(64 / 0.4)), SpreadAngle=V2(180, 180), Speed=NR(2, 6),
           Lifetime=NR(0.4), Rotation=NR(0, 360), Size=NS((0, 7), (1, 11)), Color=CS((0, tip), (1, red)), LightEmission=0.45, ZOffset=0.6),
    ]
    ground = [ring("Chain", "tfa/chain_ring", 4, 16, CS((0, red), (1, dark)), life=0.9, le=0.05, RotSpeed=NR(90), Transparency=NS((0, 0), (0.8, 0), (1, 1)),
                   Size=NS((0, 4), (0.15, 15), (1, 16))),
              ring("Chain2", "tfa/chain_ring", 3, 9, CS((0, hexc("FF6B6B")), (1, red)), life=0.8, le=0.1, RotSpeed=NR(-140), Transparency=NS((0, 0), (0.8, 0), (1, 1)),
                   Size=NS((0, 3), (0.15, 8.5), (1, 9))),
              ring("Frost", "sprites/rings/ripple_soft_00", 4, 12, CS(ice), life=0.6, le=0.35)]
    land_effect("Sig_devil_ice_cream_Land", "Devil Ice Cream lands: a red chain ring snaps out on the floor in cold mist.", red, hit, ground,
                [("Hit.A.Pop", 1, 0), ("Hit.A.Mist", 9, 0), ("Hit.A.Flakes", 10, 0), ("Hit.A.Sparks", 3, 0.04), ("Ground.A.Chain", 1, 0), ("Ground.A.Chain2", 1, 0.06), ("Ground.A.Frost", 1, 0.05)],
                pil=pillar(red, core=ice, H=12), lamp=hexc("FF6B6B"), food_col=hexc("7A1A22"), beats=["a ring of chain links snaps out"])


def sig_healing_pasta():
    gold, dark, tip, pur = hexc("FFC21F"), hexc("6A3D00"), hexc("FFF6C8"), hexc("8A3FD9")
    go = CS((0, hexc("C79BFF")), (0.5, pur), (1, hexc("3D1470")))
    layers = [
        wake("Twinkle", "flipbooks/specks/twinkle_glow_00_8x8", 12, NS((0, 1.6), (1, 2.4)), CS((0, tip), (1, gold)), life=(0.35, 0.5), speed=(8, 16),
             spread=(28, 28), LightEmission=0.4, **dict(FB8, FlipbookFramerate=NR(64 / 0.45))),
        wake("Glyphs", "tfa/menace_go", 3.0, NS((0, 1.2), (0.3, 3.0), (1, 3.6)), go, life=(0.6, 0.7), speed=(5, 14), spread=(60, 60), Rotation=NR(-10, 6),
             Transparency=NS((0, 0), (0.7, 0), (1, 1)), LightEmission=0, ZOffset=0.8),
        wake("Stars", "sprites/stars/star_cel_01", 10, NS((0, 0), (0.25, 1.1), (1, 0)), CS((0, tip), (1, gold)), life=(0.3, 0.5), speed=(8, 20), spread=(30, 30),
             Rotation=NR(0, 90), LightEmission=0.3),
    ]
    trail_effect("Sig_healing_pasta_Trail", "Healing Squid Ink Pasta: golden sparkle and drifting sound-effect glyphs.", (gold, dark, tip), layers,
                 beats=["heavy purple glyphs drift off the dish"])
    hit = [
        pop("sprites/impacts/starburst_glow_00", size=6, color=CS((0, WHITE), (1, tip)), LightEmission=0.6),
        pe("Heal", Texture=tex("flipbooks/magic/heal_rise_glow_00_4x4"), **fb(0.7), EmissionDirection=TOP, Speed=NR(3), Lifetime=NR(0.7), SpreadAngle=V2(0, 0),
           Size=NS((0, 7), (1, 10)), Color=CS((0, WHITE), (1, gold)), LightEmission=0.55, ZOffset=0.8),
        toss("Stars", "sprites/stars/star_glow_00", NS((0, 0), (0.15, 1.6), (1, 0)), CS((0, WHITE), (1, gold)), speed=(14, 24), spread=(60, 60), grav=-24,
             life=(0.6, 0.95), LightEmission=0.7),
        pe("Glyphs", Texture=tex("tfa/menace_go"), EmissionDirection=TOP, SpreadAngle=V2(55, 55), Speed=NR(11, 17), Drag=2.6, Lifetime=NR(1.0, 1.25),
           Rotation=NR(-10, 6), Size=NS((0, 1.0), (0.15, 4.2), (0.85, 4.6), (1, 5.0)), Transparency=NS((0, 0), (0.8, 0), (1, 1)), Color=go, LightEmission=0,
           ZOffset=1.5),
    ]
    ground = [ring("Ring", "sprites/rings/ring_cel_08", 4, 12, CS((0, WHITE), (1, gold))), ring("Ring2", "sprites/rings/ring_glow_02", 3, 9, CS(pur), life=0.55, le=0.4)]
    land_effect("Sig_healing_pasta_Land", "Healing Squid Ink Pasta lands: a golden healing rise and menacing glyphs floating up.", gold, hit, ground,
                [("Hit.A.Pop", 1, 0), ("Hit.A.Heal", 1, 0.02), ("Hit.A.Stars", 14, 0), ("Ground.A.Ring", 1, 0), ("Ground.A.Ring2", 1, 0.06), ("Hit.A.Glyphs", 3, 0.06),
                 ("Hit.A.Glyphs", 2, 0.26), ("Hit.A.Glyphs", 2, 0.46)],
                pil=pillar(gold, H=12), lamp=gold, food_col=hexc("2A2230"), dur=1.8, beats=["glyphs float up one after another"])


def sig_detective_cake():
    pink, dark, tip = hexc("FF7FB0"), hexc("1A1A20"), hexc("FFF0F6")
    blk = CS((0, hexc("3A3A44")), (1, hexc("0E0E12")))
    layers = [
        wake("Cubes", "tfa/sugar_cube", 14, NS((0, 0.6), (0.25, 1.7), (0.8, 1.5), (1, 0)), CS((0, WHITE), (1, tip)), life=(0.4, 0.55), speed=(8, 16), spread=(30, 30),
             Rotation=NR(0, 360), RotSpeed=NR(-360, 360), LightEmission=0.1, ZOffset=0.4),
        wake("Feathers", "sprites/shapes/feather_ink_03", 12, NS((0, 0.8), (0.2, 2.6), (0.8, 2.3), (1, 0)), blk, life=(0.45, 0.6), speed=(8, 14), spread=(30, 30),
             Rotation=NR(0, 360), RotSpeed=NR(-240, 240), LightEmission=0),
        wake("Sugar", "sprites/specks/dot_glow_00", 18, NS((0, 0.6), (1, 0)), CS((0, WHITE), (1, pink)), life=(0.25, 0.45), speed=(8, 20), spread=(34, 34),
             LightEmission=0.55),
    ]
    trail_effect("Sig_detective_cake_Trail", "Detective's Cake Tower: sugar cubes and black feathers.", (pink, dark, tip), layers,
                 beats=["sugar cubes and black feathers tumble in the wake"])
    hit = [
        pop(size=5.5, color=CS((0, WHITE), (1, tip))),
        toss("Cubes", "tfa/sugar_cube", NS((0, 0.7), (0.12, 2.0), (0.85, 1.8), (1, 0)), CS((0, WHITE), (1, tip)), speed=(20, 32), spread=(70, 70), grav=-56,
             life=(0.75, 1.0), LightEmission=0.1),
        toss("Feathers", "sprites/shapes/feather_ink_03", NS((0, 0.8), (0.12, 2.9), (0.85, 2.5), (1, 0)), blk, speed=(14, 22), spread=(52, 52), grav=-20,
             life=(1.1, 1.5), Drag=1.8, RotSpeed=NR(-180, 180), LightEmission=0),
        pe("Cream", Texture=tex("flipbooks/magic/magic_poof_soft_01_4x4"), **fb(0.45), Speed=NR(0), Lifetime=NR(0.45), Rotation=NR(0, 360),
           Size=NS((0, 6), (0.3, 12), (1, 13)), Color=CS((0, hexc("FFD0E2")), (1, pink)), LightEmission=0.1, ZOffset=-2.5),
        rise("Sugar", "sprites/specks/dot_glow_00", NS((0, 0.7), (1, 0)), CS((0, WHITE), (1, pink)), speed=(5, 10), life=(0.6, 1.0), spread=(42, 42), LightEmission=0.55),
    ]
    ground = [ring("Ring", "sprites/rings/ring_cel_08", 4, 12, CS((0, WHITE), (1, pink))), ring("Ring2", "sprites/rings/ring_dashed_cel_00", 3, 9.5, CS(hexc("2A2A32")), life=0.5, le=0)]
    land_effect("Sig_detective_cake_Land", "Detective's Cake Tower lands: sugar cubes bounce out, black feathers drift down.", pink, hit, ground,
                [("Hit.A.Pop", 1, 0), ("Hit.A.Cream", 1, 0), ("Hit.A.Cubes", 10, 0), ("Hit.A.Feathers", 12, 0.04), ("Ground.A.Ring", 1, 0), ("Ground.A.Ring2", 1, 0.06),
                 ("Hit.A.Sugar", 10, 0.15)],
                pil=pillar(pink, H=12), lamp=pink, food_col=hexc("FFD9E6"), beats=["black feathers against pink"])


def sig_crab_hot_pot():
    cor, dark, tip = hexc("FF5A3C"), hexc("7A1C0E"), hexc("FFF1E0")
    layers = [
        steam("Steam", 26, size=(2.8, 5.6), alpha=0.3),
        wake("Bubbles", "sprites/elements/bubbles_glow_02", 12, NS((0, 1.0), (1, 2.6)), CS((0, WHITE), (1, hexc("FFD0C0"))), life=(0.35, 0.5), speed=(8, 16),
             spread=(28, 28), Rotation=NR(0, 360), Transparency=NS((0, 0), (0.7, 0.2), (1, 1)), LightEmission=0.4),
        wake("Wave", "sprites/rings/ring_cel_02", 2.6, NS((0, 3), (1, 9)), CS((0, WHITE), (1, cor)), life=(0.4, 0.42), speed=(13, 14), spread=(0, 0),
             Transparency=NS((0, 0.1), (0.6, 0.35), (1, 1)), LightEmission=0.3, **PERP),
    ]
    trail_effect("Sig_crab_hot_pot_Trail", "Crab Hot Pot: rolling steam, bubbles and clean pressure rings.", (cor, dark, tip), layers,
                 glow="beams/energy_soft_03", beats=["clean rings pulse back through the steam"])
    hit = [
        pop(size=6),
        pe("Splash", Texture=tex("flipbooks/water/water_splash_cel_00_4x4"), **fb(0.5), Speed=NR(0), Lifetime=NR(0.5), Rotation=NR(-6, 6),
           Size=NS((0, 6), (0.3, 10), (1, 11)), Color=CS((0, WHITE), (1, hexc("FFD0C0"))), LightEmission=0.2, ZOffset=0.8),
        pe("Steam", Texture=tex("flipbooks/smoke/plume_loop_soft_00_4x4"), **dict(FB4LOOP, FlipbookFramerate=NR(14)), EmissionDirection=TOP, SpreadAngle=V2(18, 18),
           Speed=NR(11, 18), Drag=1.6, Lifetime=NR(0.9, 1.15), Rotation=NR(-15, 15), Size=NS((0, 4), (1, 10)), Transparency=NS((0, 0.1), (0.6, 0.35), (1, 1)),
           Color=CS((0, WHITE), (1, hexc("F2E6DE"))), LightEmission=0.05, ZOffset=0.3),
        toss("Bubbles", "sprites/elements/bubbles_glow_02", NS((0, 0.8), (0.2, 2.2), (1, 2.8)), CS((0, WHITE), (1, hexc("FFD0C0"))), speed=(10, 18), spread=(55, 55),
             grav=6, life=(0.6, 0.9), Drag=2, RotSpeed=NR(-40, 40), Transparency=NS((0, 0), (0.7, 0.2), (1, 1)), LightEmission=0.4),
    ]
    ground = [ring("Shock", "sprites/rings/ring_cel_02", 4, 15, CS((0, hexc("FFB09A")), (0.4, cor), (1, dark)), life=0.5, le=0.1),
              ring("Ring", "sprites/rings/ring_cel_08", 3, 11, CS((0, WHITE), (1, tip)), life=0.42, le=0.3)]
    land_effect("Sig_crab_hot_pot_Land", "Crab Hot Pot lands: one clean shockwave and a column of steam.", cor, hit, ground,
                [("Hit.A.Pop", 1, 0), ("Hit.A.Splash", 1, 0), ("Ground.A.Shock", 1, 0), ("Ground.A.Ring", 1, 0.02), ("Hit.A.Steam", 9, 0.04), ("Hit.A.Bubbles", 12, 0.04),
                 ("Hit.A.Steam", 6, 0.25), ("Hit.A.Steam", 4, 0.5)],
                pil=pillar(cor, H=11), lamp=hexc("FF9A80"), shake=0.3, food_col=hexc("D94A30"), beats=["one clean shockwave"])


def sig_captains_curry():
    wht, dark, tip = hexc("F4F6FA"), hexc("0C0C10"), WHITE
    k = CS(BLACK)
    back = [
        wake("Black", "sprites/slashes/slash_ink_02", 12, NS((0, 4.4), (1, 2.6)), k, life=(0.2, 0.3), speed=(26, 40), spread=(12, 12), LightEmission=0,
             Transparency=NS((0, 0), (0.7, 0.1), (1, 1)), **STREAK),
        wake("White", "sprites/slashes/slash_cel_01", 12, NS((0, 4.0), (1, 2.4)), CS(WHITE), life=(0.2, 0.3), speed=(26, 40), spread=(12, 12), LightEmission=0.4,
             Transparency=NS((0, 0), (0.7, 0.1), (1, 1)), ZOffset=1.7, **STREAK)]
    layers = [
        wake("Pressure", "sprites/rings/ring_ink_02", 3, NS((0, 3), (1, 9)), k, life=(0.36, 0.4), speed=(14, 15), spread=(0, 0), Rotation=NR(0, 360),
             Transparency=NS((0, 0.1), (0.6, 0.35), (1, 1)), LightEmission=0, **PERP),
    ]
    core, edge = hexc("EDEFF5"), dark
    trail_effect("Sig_captains_curry_Trail", "Captain's Curry: black and white spirit pressure streaks.", (core, edge, tip), layers, W=2.6,
                 glow="beams/energy_soft_03", back=back, beats=["black and white strokes tear past"])
    hit = [
        pop("sprites/slashes/slash_cross_ink_01", size=11, color=k, life=0.22, LightEmission=0),
        pe("WhiteX", Texture=tex("sprites/slashes/slash_cross_cel_01"), Speed=NR(0), Lifetime=NR(0.2), Rotation=NR(40, 50), Size=NS((0, 7), (1, 10)),
           Transparency=NS((0, 0), (0.6, 0.1), (1, 1)), Color=CS(WHITE), LightEmission=0.6, ZOffset=1.6),
        pe("Ink", Texture=tex("flipbooks/ink/ink_splash_ink_00_4x4"), **fb(0.55), Speed=NR(0), Lifetime=NR(0.55), Rotation=NR(0, 360), Size=NS((0, 6), (0.3, 11), (1, 12)),
           Color=k, LightEmission=0, ZOffset=0.6),
        pe("Strokes", Texture=tex("sprites/slashes/slash_ink_02"), EmissionDirection=TOP, SpreadAngle=V2(80, 80), Speed=NR(26, 40), Drag=3.5, Lifetime=NR(0.3, 0.42),
           Size=NS((0, 4.5), (1, 1.5)), Color=k, LightEmission=0, **STREAK),
        pe("Light", Texture=tex("sprites/slashes/slash_cel_01"), EmissionDirection=TOP, SpreadAngle=V2(80, 80), Speed=NR(26, 40), Drag=3.5, Lifetime=NR(0.3, 0.42),
           Size=NS((0, 4), (1, 1.2)), Color=CS(WHITE), LightEmission=0.5, ZOffset=0.2, **STREAK),
        rise("Wisps", "sprites/specks/wisp_ink_01", NS((0, 1.5), (1, 3.5)), k, speed=(4, 8), life=(0.7, 1.0), spread=(30, 30), LightEmission=0, Rotation=NR(-20, 20)),
    ]
    ground = [ring("Dark", "sprites/rings/ring_ink_02", 4, 15, k, life=0.5, le=0), ring("Ring", "sprites/rings/ring_cel_02", 3, 12, CS(WHITE), life=0.42, le=0.5)]
    land_effect("Sig_captains_curry_Land", "Captain's Curry lands: a black and white pressure cross and ink strokes.", wht, hit, ground,
                [("Hit.A.Pop", 1, 0), ("Hit.A.WhiteX", 1, 0.03), ("Hit.A.Ink", 1, 0.02), ("Hit.A.Strokes", 12, 0), ("Hit.A.Light", 10, 0), ("Ground.A.Dark", 1, 0),
                 ("Ground.A.Ring", 1, 0.05), ("Hit.A.Wisps", 6, 0.2)],
                pil=pillar(hexc("E6E8F0"), core=BLACK, H=12, dark=True), lamp=WHITE, shake=0.3, food_col=hexc("C8862A"), beats=["black cross, white cross"])


def sig_elixir():
    vio, dark, tip, blue = hexc("8B5CF6"), hexc("2A1466"), hexc("E4DBFF"), hexc("38BDF8")
    layers = [
        wake("Sigils", "sprites/sigils/sigil_glow_02", 4.5, NS((0, 2.6), (1, 7.2)), CS((0, tip), (1, vio)), life=(0.44, 0.48), speed=(12, 13), spread=(0, 0),
             Rotation=NR(0, 360), RotSpeed=NR(160, 220), Transparency=NS((0, 0), (0.65, 0.2), (1, 1)), LightEmission=0.45, **PERP),
        wake("Runes", "sprites/sigils/rune_glow_03", 12, NS((0, 0.5), (0.25, 1.7), (0.8, 1.5), (1, 0)), CS((0, WHITE), (1, blue)), life=(0.4, 0.55), speed=(8, 16),
             spread=(30, 30), Rotation=NR(-20, 20), LightEmission=0.55, ZOffset=0.4),
        halo("Glow", "sprites/shapes/orb_soft_00", 3, NS((0, 5.5), (1, 7)), CS(blue), life=0.4, Transparency=NS((0, 1), (0.3, 0.45), (1, 1)), LightEmission=0.5),
        wake("Motes", "sprites/specks/dot_glow_00", 16, NS((0, 0.8), (1, 0)), CS((0, WHITE), (1, vio)), life=(0.3, 0.5), speed=(8, 20), spread=(32, 32),
             LightEmission=0.6),
    ]
    trail_effect("Sig_elixir_Trail", "Elixir of Life: violet rune circles and a blue glow.", (vio, dark, tip), layers, beats=["rune circles slide back, runes scatter"])
    hit = [
        pop("sprites/impacts/starburst_glow_00", size=6, color=CS((0, WHITE), (1, tip)), LightEmission=0.6),
        pe("Glow", Texture=tex("sprites/shapes/orb_soft_00"), Speed=NR(0), Lifetime=NR(0.9), Size=NS((0, 4), (0.2, 10), (1, 12)),
           Transparency=NS((0, 0.3), (0.5, 0.5), (1, 1)), Color=CS(blue), LightEmission=0.5, ZOffset=-0.5),
        pe("Runes", Texture=tex("sprites/sigils/rune_glow_03"), EmissionDirection=TOP, SpreadAngle=V2(40, 40), Speed=NR(6, 11), Drag=2.2, Lifetime=NR(0.9, 1.2),
           Rotation=NR(-15, 15), Size=NS((0, 0.8), (0.15, 3.0), (0.85, 2.6), (1, 0)), Color=CS((0, tip), (0.3, blue), (1, vio)), LightEmission=0.4, ZOffset=0.8),
        toss("Motes", "sprites/specks/dot_glow_00", NS((0, 1.0), (1, 0)), CS((0, WHITE), (1, vio)), speed=(12, 22), spread=(60, 60), grav=-10, life=(0.6, 1.0),
             LightEmission=0.6),
    ]
    ground = [pe("Circle", Texture=tex("sprites/sigils/sigil_glow_02"), **FLAT, Lifetime=NR(1.25), Rotation=NR(0, 360), RotSpeed=NR(120),
                 Size=NS((0, 3), (0.12, 15), (0.85, 15.5), (1, 17)), Transparency=NS((0, 0), (0.8, 0), (1, 1)), Color=CS((0, vio), (1, dark)),
                 LightEmission=0.15, ZOffset=0.25),
              pe("Under", Texture=tex("sprites/sigils/sigil_cel_02"), **FLAT, Lifetime=NR(1.25), Rotation=NR(0, 360), RotSpeed=NR(120),
                 Size=NS((0, 3), (0.12, 15), (0.85, 15.5), (1, 17)), Transparency=NS((0, 0.2), (0.8, 0.3), (1, 1)), Color=CS(dark), LightEmission=0, ZOffset=0.2),
              pe("Circle2", Texture=tex("sprites/rings/ring_dashed_glow_00"), **FLAT, Lifetime=NR(1.1), Rotation=NR(0, 360), RotSpeed=NR(-200),
                 Size=NS((0, 2), (0.15, 9), (1, 10)), Transparency=NS((0, 0), (0.8, 0.1), (1, 1)), Color=CS((0, blue), (1, hexc("1557B0"))), LightEmission=0.3, ZOffset=0.3)]
    land_effect("Sig_elixir_Land", "Elixir of Life lands: a violet rune circle turns on the floor in a blue glow.", vio, hit, ground,
                [("Hit.A.Pop", 1, 0), ("Hit.A.Glow", 1, 0), ("Ground.A.Under", 1, 0), ("Ground.A.Circle", 1, 0), ("Ground.A.Circle2", 1, 0.05), ("Hit.A.Motes", 14, 0), ("Hit.A.Runes", 4, 0.1),
                 ("Hit.A.Runes", 3, 0.3), ("Hit.A.Runes", 3, 0.5)],
                pil=pillar(vio, core=hexc("DFF6FF"), H=13), lamp=blue, food_col=hexc("B9A3FF"), dur=1.8, beats=["the rune circle keeps turning"])


def sig_cream_mochi():
    vio, dark, tip, blu, red = hexc("9B5CFF"), hexc("2A0F6B"), hexc("EADFFF"), hexc("2F7BFF"), hexc("FF3B4E")
    def orb(name, col, side):
        return att(name, (2.5 * side, 0, 0, 0, -28 * side, 0), [
            pe("Orb", Texture=tex("sprites/shapes/orb_glow_00"), Rate=13, LockedToPart=True, EmissionDirection=BACK, Speed=NR(11, 12), SpreadAngle=V2(0, 0),
               Lifetime=NR(0.36, 0.4), Size=NS((0, 2.9), (0.7, 2.3), (1, 0.9)), Color=CS((0, col), (0.6, col), (1, vio)), LightEmission=0.2, ZOffset=2),
            pe("Tail", Texture=tex("sprites/specks/dot_glow_00"), Rate=26, LockedToPart=True, EmissionDirection=BACK, Speed=NR(8, 12), SpreadAngle=V2(8, 8),
               Lifetime=NR(0.25, 0.4), Size=NS((0, 0.8), (1, 0)), Color=CS((0, WHITE), (1, col)), LightEmission=0.6)])
    layers = [
        halo("Merge", "sprites/shapes/orb_glow_02", 6, NS((0, 1.2), (0.5, 3.0), (1, 4.2)), CS((0, hexc("C9A6FF")), (0.3, vio), (1, dark)), life=0.3,
             Transparency=NS((0, 0.15), (0.6, 0.35), (1, 1)), LightEmission=0.25, ZOffset=0.2),
        wake("Violet", "sprites/rings/ring_glow_02", 3.2, NS((0, 2.5), (1, 7.5)), CS((0, tip), (1, vio)), life=(0.34, 0.38), speed=(10, 11), spread=(0, 0),
             Transparency=NS((0, 0.1), (0.6, 0.4), (1, 1)), LightEmission=0.45, **PERP),
    ]
    extra = [orb("Blue", blu, -1), orb("Red", red, 1), att("MergeAt", (0, 0, 4.6, 0, 0, 0), [layers.pop(0)])]
    trail_effect("Sig_cream_mochi_Trail", "Infinity Cream Mochi: a blue orb stream and a red one meet behind the dish and turn violet.", (vio, dark, tip), layers,
                 extra=extra, beats=["blue and red converge into violet"])
    def inward(name, col, side):
        return carrier(name, (4.6 * side, 1.4, 0, 0, 0, 0), [att("A", (0, 0, 0, 0, 0, 90 * side), [
            pe("Orb", Texture=tex("sprites/shapes/orb_glow_00"), EmissionDirection=TOP, Speed=NR(26), SpreadAngle=V2(0, 0), Lifetime=NR(0.17),
               Size=NS((0, 4.2), (1, 3.0)), Color=CS(col), LightEmission=0.25, ZOffset=1.2),
            pe("Tail", Texture=tex("sprites/specks/dot_glow_00"), EmissionDirection=TOP, Speed=NR(14, 26), SpreadAngle=V2(14, 14), Lifetime=NR(0.14, 0.2),
               Size=NS((0, 1.2), (1, 0)), Color=CS((0, WHITE), (1, col)), LightEmission=0.6)])])
    hit = [
        pe("Violet", Texture=tex("sprites/shapes/orb_cel_02"), Speed=NR(0), Lifetime=NR(0.6), Size=NS((0, 2), (0.15, 12), (0.7, 11), (1, 13.5)),
           Transparency=NS((0, 0), (0.7, 0.05), (1, 1)), Color=CS((0, hexc("C9A6FF")), (0.2, vio), (1, dark)), LightEmission=0.15, ZOffset=1),
        pe("Heart", Texture=tex("sprites/shapes/orb_soft_00"), Speed=NR(0), Lifetime=NR(0.5), Size=NS((0, 1), (0.2, 6), (1, 4)),
           Transparency=NS((0, 0), (0.7, 0.1), (1, 1)), Color=CS(dark), LightEmission=0, ZOffset=1.4),
        pe("Charge", Texture=tex("flipbooks/magic/charge_in_glow_00_4x4"), **fb(0.2), Speed=NR(0), Lifetime=NR(0.2), Size=NS((0, 10), (1, 8)),
           Color=CS((0, blu), (1, red)), LightEmission=0.5, ZOffset=0.6),
        toss("Motes", "sprites/specks/dot_glow_00", NS((0, 1.1), (1, 0)), CS((0, WHITE), (0.4, vio), (1, dark)), speed=(14, 26), spread=(70, 70), grav=-10,
             life=(0.6, 1.0), LightEmission=0.6),
        pe("Flare", Texture=tex("sprites/flares/flare_glow_01"), Speed=NR(0), Lifetime=NR(0.28), Rotation=NR(0, 45), Size=NS((0, 5), (0.3, 14), (1, 9)),
           Transparency=NS((0, 0.1), (1, 1)), Color=CS((0, WHITE), (1, vio)), LightEmission=0.7, ZOffset=1.5),
    ]
    extra2 = [inward("BlueIn", blu, -1), inward("RedIn", red, 1)]
    ground = [ring("Ring", "sprites/rings/ring_cel_08", 3, 17, CS((0, hexc("C9A6FF")), (1, vio)), life=0.45, le=0.2), ring("Dark", "sprites/rings/ring_cel_02", 3, 13, CS(dark), life=0.55, le=0)]
    T0 = 0.17
    land_effect("Sig_cream_mochi_Land", "Infinity Cream Mochi lands: a blue orb and a red orb fly in from the sides and burst violet.", vio, hit, ground,
                [("BlueIn.A.Orb", 1, 0), ("RedIn.A.Orb", 1, 0), ("BlueIn.A.Tail", 8, 0), ("RedIn.A.Tail", 8, 0), ("Hit.A.Charge", 1, 0), ("Hit.A.Violet", 1, T0), ("Hit.A.Heart", 1, T0 + 0.03),
                 ("Hit.A.Flare", 1, T0), ("Hit.A.Motes", 18, T0), ("Ground.A.Ring", 1, T0), ("Ground.A.Dark", 1, T0 + 0.05)],
                pil=None, lamp=vio, food_col=hexc("BFE8C8"), dur=1.6, beats=["blue + red = violet"],
                extra=extra2 + [pillar(vio, H=12)[0]], after=lambda tl: pillar_events(tl, *pillar(vio, H=12)[1:], t0=T0))


def sig_saiyan_feast():
    gold, dark, tip = hexc("FFC400"), hexc("7A4A00"), hexc("FFF7C2")
    aura = pe("Aura", Texture=tex("sprites/elements/flame_glow_05"), Rate=30, LockedToPart=True, EmissionDirection=TOP, Shape=E("ParticleEmitterShape.Box"),
              Speed=NR(10, 16), Lifetime=NR(0.28, 0.4), Size=NS((0, 3.8), (0.4, 6.0), (1, 1.8)), Color=CS((0, tip), (0.3, gold), (1, hexc("FF8A00"))),
              Transparency=NS((0, 0.1), (0.6, 0.25), (1, 1)), LightEmission=0.5, ZOffset=-1, **STREAK)
    bolts = pe("Bolts", Texture=tex("sprites/elements/bolt_glow_04"), Rate=16, LockedToPart=True, Shape=E("ParticleEmitterShape.Box"), Speed=NR(0, 2),
               Lifetime=NR(0.07, 0.11), Rotation=NR(0, 360), Size=NS((0, 5.0), (1, 6.4)), Color=CS((0, WHITE), (1, hexc("9FD8FF"))), LightEmission=0.7, ZOffset=2)
    layers = [
        wake("Flare", "sprites/elements/flame_glow_02", 26, NS((0, 3.2), (1, 1.4)), CS((0, WHITE), (0.3, tip), (1, gold)), life=(0.22, 0.32), speed=(16, 24),
             spread=(12, 12), Transparency=NS((0, 0.1), (1, 1)), LightEmission=0.5, **STREAK),
        wake("Sparks", "sprites/specks/ember_glow_00", 22, NS((0, 0.9), (1, 0)), CS((0, WHITE), (1, gold)), life=(0.3, 0.5), speed=(10, 22), spread=(34, 34),
             LightEmission=0.65),
        halo("Halo", "sprites/elements/rays_glow_03", 3, NS((0, 6), (1, 8.5)), CS((0, tip), (1, gold)), life=0.36, Rotation=NR(0, 360), RotSpeed=NR(60),
             Transparency=NS((0, 1), (0.3, 0.45), (1, 1)), LightEmission=0.5),
    ]
    extra = [carrier("AuraBox", (0, 4.2, 0, 0, 0, 0), [aura], size=(4.2, 1.2, 4.2)), carrier("BoltBox", (0, 5, 0.6, 0, 0, 0), [bolts], size=(6, 5, 4))]
    trail_effect("Sig_saiyan_feast_Trail", "Warrior's Feast: a golden aura flaring off the dish, lightning crackling round it.", (gold, dark, tip), layers,
                 W=2.8, glow="beams/energy_glow_02", extra=extra, beats=["a golden aura with crackling lightning"])
    # seen in the game: soft glow flames at this size fuse into one yellow blob. The aura is built from
    # hard-edged cel flames (gold with an orange rim) that keep their shape, one soft envelope behind
    # the dish, and lightning drawn in front of everything.
    org = hexc("FF7A00")
    flame = CS((0, tip), (0.25, gold), (1, org))
    hit = [
        pop("sprites/impacts/starburst_cel_00", size=9, color=CS((0, WHITE), (1, tip)), life=0.1, LightEmission=0.4),
        pe("Envelope", Texture=tex("sprites/elements/flame_glow_05"), Speed=NR(0), Lifetime=NR(0.55), Rotation=NR(0), Size=NS((0, 6), (0.25, 14), (1, 11)),
           Transparency=NS((0, 0.45), (0.6, 0.6), (1, 1)), Color=CS((0, gold), (1, org)), LightEmission=0.3, ZOffset=-3),
        pe("Aura", Texture=tex("sprites/elements/flame_cel_05"), EmissionDirection=TOP, SpreadAngle=V2(34, 34), Speed=NR(16, 28), Drag=2.2, Lifetime=NR(0.4, 0.6),
           Size=NS((0, 2.6), (0.3, 5.2), (1, 1.6)), Color=flame, Transparency=NS((0, 0), (0.7, 0.1), (1, 1)), LightEmission=0.15, **STREAK),
        pe("Lightning", Texture=tex("sprites/elements/bolt_cel_04"), EmissionDirection=TOP, SpreadAngle=V2(70, 70), Speed=NR(4, 10), Lifetime=NR(0.1, 0.16),
           Rotation=NR(0, 360), Size=NS((0, 7), (1, 9.5)), Color=CS((0, WHITE), (1, hexc("9FD8FF"))), LightEmission=0.8, ZOffset=3),
        toss("Sparks", "sprites/specks/ember_cel_01", NS((0, 0.7), (1, 0)), CS((0, tip), (1, gold)), speed=(18, 32), spread=(60, 60), grav=-30, life=(0.6, 1.0),
             LightEmission=0.5),
    ]
    ring_fl = pe("Flames", Texture=tex("sprites/elements/flame_cel_02"), EmissionDirection=TOP, Shape=E("ParticleEmitterShape.Box"),
                 Speed=NR(10, 17), Lifetime=NR(0.4, 0.6), Size=NS((0, 2.2), (0.4, 4.0), (1, 1.0)), Color=flame,
                 Transparency=NS((0, 0), (0.7, 0.1), (1, 1)), LightEmission=0.15, **STREAK)
    extra2 = [carrier("AuraRing", (0, 0.6, 0, 0, 0, 0), [ring_fl], size=(7.5, 0.6, 7.5))]
    ground = [ring("Crack", "sprites/cracks/crack_glow_01", 12, 13, CS((0, tip), (1, gold)), life=1.0, le=0.5, Transparency=NS((0, 0), (0.6, 0.2), (1, 1)), Rotation=NR(0, 360)),
              ring("Ring", "sprites/rings/ring_spiked_cel_02", 5, 18, CS((0, tip), (1, org)), life=0.42, le=0.3),
              ring("Ring2", "sprites/rings/ring_cel_08", 4, 13, CS((0, WHITE), (1, gold)), life=0.5)]
    land_effect("Sig_saiyan_feast_Land", "Warrior's Feast lands: a golden aura erupts with lightning, the ground cracks.", gold, hit, ground,
                [("Hit.A.Pop", 1, 0), ("Hit.A.Envelope", 1, 0), ("Hit.A.Aura", 7, 0), ("AuraRing.Flames", 9, 0), ("Hit.A.Lightning", 3, 0.02), ("Hit.A.Sparks", 16, 0),
                 ("Ground.A.Crack", 1, 0), ("Ground.A.Ring", 1, 0), ("Ground.A.Ring2", 1, 0.06), ("Hit.A.Lightning", 3, 0.14), ("AuraRing.Flames", 7, 0.18),
                 ("Hit.A.Aura", 4, 0.2), ("Hit.A.Lightning", 2, 0.3), ("AuraRing.Flames", 6, 0.36), ("Hit.A.Lightning", 2, 0.46)],
                pil=pillar(gold, core=tip, H=14, W=5.5), lamp=gold, shake=0.5, extra=extra2, food_col=hexc("D9A05A"), dur=1.7,
                beats=["golden aura flare", "lightning crackle"])


SIGNATURES = {
    "legend_ramen": sig_legend_ramen, "flame_bento": sig_flame_bento, "swirl_fruit": sig_swirl_fruit, "mapo_tofu": sig_mapo_tofu,
    "rank_one_steak": sig_rank_one_steak, "sheep_feast": sig_sheep_feast, "boar_roast": sig_boar_roast, "floor_boss_stew": sig_floor_boss_stew,
    "officers_ham": sig_officers_ham, "devil_ice_cream": sig_devil_ice_cream, "healing_pasta": sig_healing_pasta, "detective_cake": sig_detective_cake,
    "crab_hot_pot": sig_crab_hot_pot, "captains_curry": sig_captains_curry, "elixir": sig_elixir, "cream_mochi": sig_cream_mochi,
    "saiyan_feast": sig_saiyan_feast,
}
OTHERS = {"meal": meal, "aroma": aroma, "favourite": favourite}

if __name__ == "__main__":
    want = sys.argv[1:] or (list(OTHERS) + list(SIGNATURES))
    for key in want:
        (OTHERS.get(key) or SIGNATURES[key])()
