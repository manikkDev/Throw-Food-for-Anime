"""Throw family: ThrowTrail_Basic / _Hot / _Epic, Land_Impact, PerfectThrow_Flash, LuckyThrow_Charge.

BRIEFS (stylised_game, readable at a distance, no screen effects)
  ThrowTrail_*     the food is a comet. Trail (0.16-0.22 s of ribbon, ~35-45 studs at 200 studs/s) +
                   breadcrumb particles left hanging in the air. Basic = white cel streaks + sparkle
                   crumbs, TINTABLE to the food colour. Hot = flame ribbon + embers + puffs (orange).
                   Epic = sparkle-studded violet ribbon with a gold star wake + pulse rings.
                   Runs until stop (the food lands); attach = part (welded to the food).
  Land_Impact      food hits the floor: 1-frame bounce pop, cel dust puffs skidding out, flat ring
                   born at 45 %, three or four little stars hop up. 0.25 s main, dust residue.
  PerfectThrow     a gold four-point star flash at the hand, cross glint, ring pop, sparkle spray.
  LuckyThrow       armed: green clover sparkles drawn in to the hand, a turning green swirl halo,
                   a pulsing clover glow at the palm. Loops until stop; attach = part (the hand).
"""
from tfa_fx import (CS, FB4, FB4LOOP, FLAT, NR, NS, STREAK, TL, V2, V3, WHITE, E, att, carrier, hexc, light, mix, pe,
                    tex, trail, write)

GOLD = hexc("FFD23F")
CREAM = hexc("FFF4D6")


FLOORS = ["#F4EBD0", "#FFD6E5", "#CFF5E1"]  # the lane's pale floors: cream, light pink, mint


def flight(tl, T=0.9):
    """Sim staging only: fly the carrier straight down the lane (-Z) at ~167 studs/s with the game's
    chase camera (16 behind, 6 above, looking down the lane) riding along."""
    tl.at(0, do="path", target="Food", points=[[0, 5, 0], [0, 5, -75], [0, 5, -150]], time=T, style="Linear", sim=True)
    tl.at(0, do="camera", pos=[0, 11, 16], at=[0, 4, -10], sim=True)
    tl.at(0, do="camera", pos=[0, 11, -134], at=[0, 4, -160], time=T, style="Linear", sim=True)


def trail_fx(name, kind):
    """v2 (in-engine review: Basic was a faint streak from the chase camera over pale floors).
    Each trail = a saturated CORE ribbon 3 studs wide at the food tapering to 0, a darker EDGE copy
    (wider, LightEmission 0) so it reads on cream / pink / mint, a thin hot centre line, and dense
    crumbs left hanging in the air. Normal blending (low LightEmission) keeps colour on pale floors."""
    tl = TL()
    if kind == "Basic":
        core, edge, tip = hexc("38BDF8"), hexc("1E3A8A"), hexc("E0F2FE")
        tint = True
        core_tex, crumb_tex = "beams/energy_soft_03", "sprites/stars/star_cel_00"
        crumbs = [pe("Crumbs", attrs={"Tint": True}, Texture=tex(crumb_tex), Rate=70, Speed=NR(0.5, 2.5), SpreadAngle=V2(180, 180),
                     Lifetime=NR(0.35, 0.55), Rotation=NR(0, 360), RotSpeed=NR(-220, 220), Size=NS((0, 1.3), (0.6, 1.0), (1, 0)),
                     Color=CS((0, tip), (0.3, core), (1, edge)), LightEmission=0.15)]
    elif kind == "Hot":
        core, edge, tip = hexc("FF7A1A"), hexc("9A1B0E"), hexc("FFE36B")
        tint = False
        core_tex = "beams/fire_trail_hot_02"
        crumbs = [
            pe("Puffs", Texture=tex("flipbooks/fire/fire_burst_cel_01_4x4"), **FB4, FlipbookFramerate=NR(16 / 0.4), Rate=45,
               Speed=NR(0.5, 2), SpreadAngle=V2(180, 180), Lifetime=NR(0.35, 0.42), Rotation=NR(0, 360), Size=NS((0, 2.2), (1, 3.4)),
               Color=CS((0, tip), (0.4, core), (1, edge)), LightEmission=0.25, Acceleration=V3(0, 4, 0)),
            pe("Embers", Texture=tex("sprites/specks/ember_glow_00"), Rate=50, Speed=NR(2, 6), SpreadAngle=V2(180, 180), Drag=1.5,
               Acceleration=V3(0, 6, 0), Lifetime=NR(0.4, 0.7), Size=NS((0, 0.8), (1, 0)), Color=CS((0, tip), (1, hexc("E2481B"))), LightEmission=0.5),
        ]
    else:  # Epic
        core, edge, tip = hexc("A855F7"), hexc("3B0A7A"), hexc("F5D0FE")
        tint = True
        core_tex = "beams/energy_glow_04"
        crumbs = [
            pe("Stars", Texture=tex("sprites/stars/star_cel_01"), Rate=55, Speed=NR(1, 4), SpreadAngle=V2(180, 180), Drag=1,
               Lifetime=NR(0.4, 0.6), Rotation=NR(0, 360), RotSpeed=NR(-240, 240), Size=NS((0, 1.6), (0.2, 1.9), (1, 0)),
               Color=CS((0, hexc("FFF3B0")), (0.3, GOLD), (1, hexc("F97316"))), LightEmission=0.2),
            pe("Rings", attrs={"Tint": True}, Texture=tex("sprites/rings/ring_glow_02"), Rate=8, Speed=NR(0.01), EmissionDirection=E("NormalId.Front"),
               Orientation=E("ParticleOrientation.VelocityPerpendicular"), Lifetime=NR(0.3), Size=NS((0, 2.4), (1, 5.4)),
               Transparency=NS((0, 0.05), (1, 1)), Color=CS(core), LightEmission=0.4),
        ]
    ta = {"Tint": True} if tint else None
    W, WE = 3.0, 3.9
    ribbons = [
        trail("Edge", "Food.E0", "Food.E1", attrs=ta, Texture=tex("tfa/ribbon_solid"), TextureMode=E("TextureMode.Stretch"),
              Lifetime=0.22, MinLength=0.05, WidthScale=NS((0, 1), (0.5, 0.55), (1, 0)), Color=CS((0, mix(edge, core, 0.25)), (1, edge)),
              Transparency=NS((0, 0), (0.6, 0.1), (1, 1)), LightEmission=0),
        trail("Ribbon", "Food.T0", "Food.T1", attrs=ta, Texture=tex("tfa/ribbon_solid"), TextureMode=E("TextureMode.Stretch"),
              Lifetime=0.2, MinLength=0.05, WidthScale=NS((0, 1), (0.5, 0.5), (1, 0)), Color=CS((0, tip), (0.2, core), (1, mix(core, edge, 0.3))),
              Transparency=NS((0, 0), (0.6, 0.1), (1, 1)), LightEmission=0.1),
        trail("Glow", "Food.G0", "Food.G1", attrs=ta, Texture=tex(core_tex), TextureMode=E("TextureMode.Stretch"),
              Lifetime=0.24, MinLength=0.05, WidthScale=NS((0, 1), (1, 0)), Color=CS(WHITE) if kind == "Hot" else CS((0, tip), (1, core)),
              Transparency=NS((0, 0), (0.6, 0.2), (1, 1)), LightEmission=0.35),
        trail("Line", "Food.S0", "Food.S1", attrs=ta, Texture=tex("beams/laser_glow_04"), TextureMode=E("TextureMode.Stretch"),
              Lifetime=0.16, MinLength=0.05, WidthScale=NS((0, 1), (1, 0)), Color=CS(tip), Transparency=NS((0, 0), (1, 1)), LightEmission=0.5),
    ]
    if kind == "Epic":
        ribbons.append(trail("Sparkle", "Food.E0", "Food.E1", Texture=tex("beams/sparkle_trail_cel_02"), TextureMode=E("TextureMode.Stretch"),
                             Lifetime=0.3, MinLength=0.05, WidthScale=NS((0, 1), (1, 0.6)), Color=CS(hexc("FFE680")),
                             Transparency=NS((0, 0), (0.7, 0.15), (1, 1)), LightEmission=0.3))
    kids = [att("T0", (0, W / 2, 0)), att("T1", (0, -W / 2, 0)), att("E0", (0, WE / 2, 0)), att("E1", (0, -WE / 2, 0)),
            att("G0", (0, W * 0.4, 0)), att("G1", (0, -W * 0.4, 0)),
            att("S0", (0, 0.35, 0)), att("S1", (0, -0.35, 0)), att("A", children=crumbs)] + ribbons
    inst = [carrier("Food", (0, 5, 0, 0, 0, 0), kids, size=(2, 2, 2))]
    flight(tl)
    d = {"name": name, "note": f"Food trail ({kind}) v2: 3-stud core + dark edge copy + crumbs; runs until stop.", "duration": 1.1,
         "camera": {"pos": [0, 11, 16], "at": [0, 4, -10]}, "stage": {"ground": "light", "dummy": False}, "stripFloors": FLOORS,
         "game": {"loop": True, "attach": "part", "screen": False, "origin": [0, 5, 0]},
         "brief": {"category": "elemental", "tier": "basic", "style": "stylised_game", "shape": "comet ribbon with a dark edge",
                   "dominant": "#%02X%02X%02X" % tuple(int(c * 255) for c in core), "accent": "#%02X%02X%02X" % tuple(int(c * 255) for c in edge),
                   "signature_beats": ["dark copy under the bright stroke", "breadcrumb sparkles hang in the air"],
                   "phases": [{"name": "sustain", "t0": 0, "t1": 0.9}, {"name": "residue", "t0": 0.9, "t1": 1.1}]},
         "instances": inst, "timeline": tl}
    return write(d, [0.2, 0.4, 0.6, 0.8])


def land_impact():
    tl = TL()
    dust = hexc("F1E6C8")
    a = [
        pe("Pop", Texture=tex("sprites/impacts/starburst_cel_00"), Lifetime=NR(0.1), Speed=NR(0), Rotation=NR(0, 360),
           Size=NS((0, 3.2), (1, 4.2)), Color=CS((0, WHITE), (1, CREAM)), LightEmission=0.3, ZOffset=1),
        pe("Dust", Texture=tex("flipbooks/smoke/smoke_puff_fb_cel_03_4x4"), **FB4, FlipbookFramerate=NR(16 / 0.55), EmissionDirection=E("NormalId.Top"),
           SpreadAngle=V2(88, 88), Speed=NR(12, 18), Drag=5, Acceleration=V3(0, 1.5, 0), Lifetime=NR(0.45, 0.6), Rotation=NR(0, 360),
           Size=NS((0, 2.4), (0.3, 3.6), (1, 4.0)), Transparency=NS((0, 0), (0.7, 0.15), (1, 1)), Color=CS((0, WHITE), (1, dust)),
           LightEmission=0, LightInfluence=0, ZOffset=0.3),
        pe("Stars", Texture=tex("sprites/stars/star_cel_01"), EmissionDirection=E("NormalId.Top"), SpreadAngle=V2(40, 40), Speed=NR(14, 20),
           Acceleration=V3(0, -50, 0), Lifetime=NR(0.5, 0.6), Rotation=NR(0, 360), RotSpeed=NR(-300, 300),
           Size=NS((0, 0.6), (0.1, 1.4), (0.8, 1.2), (1, 0)), Color=CS((0, WHITE), (0.2, GOLD), (1, hexc("FF9A3D"))), LightEmission=0.25, ZOffset=0.5),
    ]
    g = [pe("Ring", Texture=tex("sprites/rings/ring_cel_08"), **FLAT, Lifetime=NR(0.35), Size=NS((0, 3.6), (0.2, 7.2), (1, 8.4)),
            Transparency=NS((0, 0), (0.5, 0.1), (1, 1)), Color=CS((0, WHITE), (1, dust)), LightEmission=0.2, ZOffset=0.2)]
    inst = [carrier("Hit", (0, 0.6, 0, 0, 0, 0), [att("A", children=a)]), carrier("Ground", (0, 0.12, 0, 0, 0, 0), [att("A", children=g)])]
    for tgt, n in (("Hit.A.Pop", 1), ("Hit.A.Dust", 8), ("Hit.A.Stars", 4), ("Ground.A.Ring", 1)):
        tl.at(0, do="emit", target=tgt, count=n)
    d = {"name": "Land_Impact", "note": "Food hits the floor.", "duration": 0.9, "camera": {"pos": [6, 5, 14], "at": [0, 1.2, 0]},
         "stage": {"ground": "light", "dummy": False}, "game": {"loop": False, "attach": "point", "screen": False},
         "brief": {"category": "impact", "tier": "basic", "style": "stylised_game", "shape": "bounce pop + skidding dust", "dominant": "#F1E6C8",
                   "accent": "#FFD23F", "signature_beats": ["shape born at full size"],
                   "phases": [{"name": "release", "t0": 0, "t1": 1 / 60}, {"name": "sustain", "t0": 1 / 60, "t1": 0.3}, {"name": "residue", "t0": 0.3, "t1": 0.9}]},
        "instances": inst, "timeline": tl}
    return write(d, [0.0, 0.03, 0.08, 0.16, 0.3, 0.45, 0.6, 0.8])


def perfect_flash():
    tl = TL()
    a = [
        pe("Star", attrs={"Tint": True}, Texture=tex("sprites/stars/star_glow_00"), Lifetime=NR(0.18), Speed=NR(0), Rotation=NR(-8, 8), RotSpeed=NR(90),
           Size=NS((0, 2.2), (0.15, 4.2), (1, 0.6)), Color=CS((0, WHITE), (0.4, GOLD), (1, GOLD)), LightEmission=0.6, Brightness=1.6, ZOffset=2),
        pe("Cross", Texture=tex("sprites/impacts/hit_cross_glow_00"), Lifetime=NR(0.12), Speed=NR(0), Rotation=NR(45),
           Size=NS((0, 3.5), (1, 5.5)), Transparency=NS((0, 0), (1, 1)), Color=CS(WHITE), LightEmission=0.7, ZOffset=2.5),
        pe("Ring", attrs={"Tint": True}, Texture=tex("sprites/rings/ring_glow_00"), Lifetime=NR(0.25), Speed=NR(0),
           Size=NS((0, 1.5), (0.3, 4), (1, 4.8)), Transparency=NS((0, 0), (1, 1)), Color=CS(GOLD), LightEmission=0.6, ZOffset=1),
        pe("Spray", attrs={"Tint": True}, Texture=tex("sprites/stars/star_cel_06"), SpreadAngle=V2(180, 180), Speed=NR(12, 20), Drag=4,
           Lifetime=NR(0.3, 0.45), Rotation=NR(0, 360), RotSpeed=NR(-300, 300), Size=NS((0, 0.9), (1, 0)),
           Color=CS((0, WHITE), (1, GOLD)), LightEmission=0.5, ZOffset=1.5),
    ]
    inst = [carrier("Hand", (1.6, 3.4, -0.6, 0, 0, 0), [att("A", children=a)]), light("Lamp", (1.6, 3.4, -0.6, 0, 0, 0), GOLD, 10)]
    for tgt, n in (("Hand.A.Star", 1), ("Hand.A.Cross", 1), ("Hand.A.Ring", 1), ("Hand.A.Spray", 10)):
        tl.at(0, do="emit", target=tgt, count=n)
    tl.at(0, do="set", target="Lamp.L", prop="Brightness", value=2.5)
    tl.at(0.02, do="tween", target="Lamp.L", prop="Brightness", to=0, time=0.25, style="Quad", dir="Out")
    d = {"name": "PerfectThrow_Flash", "note": "Perfect release at the hand.", "duration": 0.6, "camera": {"pos": [5, 5, 11], "at": [0.8, 3, 0]},
         "stage": {"ground": "light", "dummy": True}, "game": {"loop": False, "attach": "point", "screen": False, "origin": [1.6, 3.4, -0.6]},
         "brief": {"category": "ambient_pickup", "tier": "basic", "style": "stylised_game", "shape": "four-point star flash", "dominant": "#FFD23F",
                   "accent": "#FFFFFF", "signature_beats": ["pop to max in one frame"],
                   "phases": [{"name": "release", "t0": 0, "t1": 1 / 60}, {"name": "sustain", "t0": 1 / 60, "t1": 0.2}, {"name": "residue", "t0": 0.2, "t1": 0.45}]},
        "instances": inst, "timeline": tl}
    return write(d, [0.0, 0.03, 0.06, 0.1, 0.16, 0.24, 0.34, 0.45])


def lucky_charge():
    tl = TL()
    green, lime = hexc("3FD25A"), hexc("B6FF6B")
    shell = [
        pe("Clovers", attrs={"Tint": True}, Texture=tex("tfa/clover_cel"), Shape=E("ParticleEmitterShape.Sphere"), ShapeStyle=E("ParticleEmitterShapeStyle.Surface"),
           ShapeInOut=E("ParticleEmitterShapeInOut.Inward"), Rate=9, Speed=NR(3.5, 5), Lifetime=NR(0.55, 0.7), Rotation=NR(0, 360), RotSpeed=NR(-220, 220),
           Size=NS((0, 0), (0.2, 1.9), (0.8, 1.6), (1, 0)), Color=CS((0, lime), (1, green)), LightEmission=0.25, ZOffset=0.5),
        pe("Motes", attrs={"Tint": True}, Texture=tex("sprites/stars/star_glow_04"), Shape=E("ParticleEmitterShape.Sphere"), ShapeStyle=E("ParticleEmitterShapeStyle.Surface"),
           ShapeInOut=E("ParticleEmitterShapeInOut.Inward"), Rate=16, Speed=NR(4, 6), Lifetime=NR(0.4, 0.55), Rotation=NR(0, 90),
           Size=NS((0, 0), (0.3, 0.5), (1, 0)), Color=CS((0, WHITE), (1, lime)), LightEmission=0.7),
    ]
    core = [
        pe("Swirl", attrs={"Tint": True}, Texture=tex("sprites/swirls/swirl_glow_03"), Rate=3, Speed=NR(0), Lifetime=NR(0.6), Rotation=NR(0, 360), RotSpeed=NR(-320),
           Size=NS((0, 2.4), (0.3, 3.8), (1, 4.2)), Transparency=NS((0, 1), (0.25, 0.3), (0.7, 0.4), (1, 1)), Color=CS(green), LightEmission=0.6, ZOffset=-0.5,
           attrs_=None),
        pe("Glow", attrs={"Tint": True, "LowKeep": True}, Texture=tex("tfa/clover_glow"), Rate=2.5, Speed=NR(0), Lifetime=NR(0.5), Rotation=NR(-15, 15),
           Size=NS((0, 1.6), (0.4, 2.5), (1, 1.9)), Transparency=NS((0, 1), (0.3, 0.05), (0.7, 0.2), (1, 1)), Color=CS((0, lime), (1, green)),
           LightEmission=0.5, ZOffset=1),
    ]
    core[0]["props"].pop("attrs_")
    inst = [carrier("Shell", (1.6, 3.2, -0.6, 0, 0, 0), shell, size=(4.5, 4.5, 4.5)),
            carrier("Hand", (1.6, 3.2, -0.6, 0, 0, 0), [att("A", children=core)])]
    d = {"name": "LuckyThrow_Charge", "note": "Lucky throw armed (loop on the hand).", "duration": 2.0, "camera": {"pos": [5, 5, 11], "at": [0.8, 3, 0]},
         "stage": {"ground": "light", "dummy": True}, "game": {"loop": True, "attach": "part", "screen": False, "origin": [1.6, 3.2, -0.6]},
         "brief": {"category": "orb_charge", "tier": "basic", "style": "stylised_game", "shape": "clovers drawn into the palm", "dominant": "#3FD25A",
                   "accent": "#FFFFFF", "signature_beats": ["suck-in"], "phases": [{"name": "sustain", "t0": 0, "t1": 2.0}]},
        "instances": inst, "timeline": tl}
    return write(d, [0.25, 0.5, 0.8, 1.1, 1.4, 1.7])


if __name__ == "__main__":
    trail_fx("ThrowTrail_Basic", "Basic")
    # ThrowTrail_Hot and ThrowTrail_Epic are retired (plan 13 phase C): a Meal flies ThrowTrail_Meal and
    # every Signature dish its own effect (build_food.py)
    land_impact()
    perfect_flash()
    lucky_charge()
