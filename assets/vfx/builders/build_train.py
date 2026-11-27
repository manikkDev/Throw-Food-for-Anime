"""Training effects (plan 13 phase D): the reps, the awakening and the two grounds' finishes.

    python assets/vfx/builders/build_train.py [name ...]

WHERE THEY ARE SEEN. The training camera stands 7 to 10 studs from the trainee: the Striking Post
in profile (a fist lands on the post's face, the effect is seen from the side), the Waterfall from
the front (the trainee sits on a stone in a pool, the falls behind). Effects are small next to the
landing effects of the lane (a hit is 3 to 5 studs across) and must leave the trainee readable:
cel shapes with dark rims, LightEmission <= 0.4 on bodies, nothing that hangs over the face.

  Train_Hit      a rep on the post: comic burst, cross glint, wood chips, a ring
  Train_Crit     the PERFECT rep on top of it: big starburst, speed lines, spiked ring, sparks
  Train_Flurry   (loop) the awakening's flurry at the post's face: hit marks all over it
  Train_Pulse    (tint) a breath let out: ripple rings on the water round the seat, drops rising
  Train_Awaken   (tint) the hero awakens: shock ring, pillar, burst, sparks. Played at the root
  Train_Aura     (loop, tint) the awakened hero's aura: cel flames up round the body, embers
  Post_Burst     the post bursts: splinters, dust, a spiked shock ring
  Post_Rise      the new post comes up out of the floor: a dust ring and chips at its foot
  Falls_Ascend   (loop) the column of light and rising water where the trainee floats
  Falls_Crash    the falls come back down: a wall of splash, rings on the pool, mist
"""
import sys

from build_food import FADE, TOP, fb, hx, pillar, pillar_events, pop, ring, rise, toss
from tfa_fx import (CS, FB4, FLAT, NR, NS, STREAK, TL, V2, V3, WHITE, E, att, beam, carrier, hexc, light, mix, pe, tex,
                    write)

GOLD = hexc("FFD23F")
ORANGE = hexc("FF8A2A")
CREAM = hexc("FFF4D6")
WOOD = hexc("C98F55")
WATER = hexc("5FD8FF")
DEEP = hexc("2F8FE0")
BOX = E("ParticleEmitterShape.Box")
FB8 = {"FlipbookLayout": E("ParticleFlipbookLayout.Grid8x8"), "FlipbookMode": E("ParticleFlipbookMode.OneShot"),
       "FlipbookBlendFrames": False}
TINT = {"Tint": True}


def effect(name, note, dur, inst, tl, strip, col, shape, loop=False, attach="point", origin=None, shake=0.0, dummy=True,
           cam=((7, 4.5, 12), (0, 3, 0)), beats=()):
    if shake:
        tl.at(0, do="shake", amp=shake, time=0.3, freq=24)
    game = {"loop": loop, "attach": attach, "screen": bool(shake)}
    if origin:
        game["origin"] = list(origin)
    phases = ([{"name": "sustain", "t0": 0, "t1": dur}] if loop else
              [{"name": "release", "t0": 0, "t1": 1 / 60}, {"name": "sustain", "t0": 1 / 60, "t1": dur * 0.4},
               {"name": "residue", "t0": dur * 0.4, "t1": dur}])
    d = {"name": name, "note": note, "duration": dur, "camera": {"pos": list(cam[0]), "at": list(cam[1])},
         "stage": {"ground": "light", "dummy": dummy}, "stripFloors": ["#E9D2A2"], "game": game,
         "brief": {"category": "impact" if not loop else "aura_buff", "tier": "basic", "style": "stylised_game", "shape": shape,
                   "dominant": hx(col), "accent": "#FFFFFF", "signature_beats": list(beats) or ["shape born at full size"],
                   "phases": phases},
         "instances": inst, "timeline": tl}
    return write(d, strip)


# ------------------------------------------------------------------------------------ the reps
def train_hit():
    """A rep on the post. Origin = the contact point (3.2 up in the strips)."""
    tl = TL()
    a = [
        pe("Burst", Texture=tex("sprites/impacts/comic_burst_cel_02"), Lifetime=NR(0.14), Speed=NR(0), Rotation=NR(0, 360),
           Size=NS((0, 3.0), (1, 3.8)), Transparency=NS((0, 0), (0.6, 0), (1, 1)), Color=CS((0, WHITE), (0.5, hexc("FFF07A")), (1, GOLD)),
           LightEmission=0.25, ZOffset=2),
        pe("Cross", Texture=tex("sprites/impacts/hit_cross_cel_00"), Lifetime=NR(0.09), Speed=NR(0), Rotation=NR(0, 90),
           Size=NS((0, 2.2), (1, 3.4)), Color=CS(WHITE), LightEmission=0.4, ZOffset=2.5),
        pe("Ring", Texture=tex("sprites/rings/ring_cel_04"), Lifetime=NR(0.2), Speed=NR(0), Size=NS((0, 1.4), (0.3, 3.2), (1, 3.8)),
           Transparency=NS((0, 0), (1, 1)), Color=CS((0, WHITE), (1, ORANGE)), LightEmission=0.3, ZOffset=1),
        # chips of wood knocked off the post: out and down
        pe("Chips", Texture=tex("tfa/wood_splinter"), SpreadAngle=V2(180, 180), Speed=NR(8, 14), Drag=2, Acceleration=V3(0, -34, 0),
           Lifetime=NR(0.3, 0.5), Rotation=NR(0, 360), RotSpeed=NR(-500, 500), Size=NS((0, 0.55), (0.7, 0.5), (1, 0)), Color=CS(WHITE),
           LightEmission=0, ZOffset=1.5),
        pe("Dust", Texture=tex("flipbooks/smoke/smoke_puff_fb_cel_03_4x4"), **fb(0.4), SpreadAngle=V2(180, 180), Speed=NR(2, 4), Drag=4,
           Lifetime=NR(0.32, 0.42), Rotation=NR(0, 360), Size=NS((0, 1.2), (1, 2.2)), Transparency=NS((0, 0.25), (0.6, 0.45), (1, 1)),
           Color=CS((0, WHITE), (1, hexc("EADBB8"))), LightEmission=0, ZOffset=0.5),
    ]
    inst = [carrier("Hit", (0, 3.2, 0, 0, 0, 0), [att("A", children=a)])]
    for t, n in (("Burst", 1), ("Cross", 1), ("Ring", 1), ("Chips", 4), ("Dust", 2)):
        tl.at(0, do="emit", target=f"Hit.A.{t}", count=n)
    effect("Train_Hit", "A training rep lands on the post.", 0.6, inst, tl, [0.0, 0.03, 0.07, 0.12, 0.2, 0.35], GOLD,
           "comic star + wood chips", origin=(0, 3.2, 0))


def train_crit():
    """The PERFECT rep, played over Train_Hit: the anime critical."""
    tl = TL()
    a = [
        pe("Star", Texture=tex("sprites/impacts/starburst_cel_00"), Lifetime=NR(0.16), Speed=NR(0), Rotation=NR(0, 360),
           # gold from its first frame (seen in the game: a white start bloomed to a plain white flash)
           Size=NS((0, 5.0), (0.4, 6.6), (1, 7.2)), Transparency=NS((0, 0), (0.55, 0), (1, 1)), Color=CS((0, hexc("FFE35A")), (1, ORANGE)),
           LightEmission=0.15, ZOffset=3),
        pe("Core", Texture=tex("sprites/impacts/hit_cross_cel_00"), Lifetime=NR(0.1), Speed=NR(0), Rotation=NR(0, 90), Size=NS((0, 2.6), (1, 4.2)),
           Color=CS(WHITE), LightEmission=0.4, ZOffset=3.5),
        pe("Lines", Texture=tex("sprites/impacts/speed_lines_cel_02"), Lifetime=NR(0.2), Speed=NR(0), Rotation=NR(0, 360),
           Size=NS((0, 6), (1, 9.5)), Transparency=NS((0, 0.1), (0.5, 0.3), (1, 1)), Color=CS(WHITE), LightEmission=0.3, ZOffset=2),
        pe("Spiked", Texture=tex("sprites/rings/ring_spiked_cel_02"), Lifetime=NR(0.26), Speed=NR(0), Rotation=NR(0, 360),
           Size=NS((0, 2.5), (0.3, 6.5), (1, 8)), Transparency=NS((0, 0), (0.5, 0.1), (1, 1)), Color=CS((0, WHITE), (1, ORANGE)), LightEmission=0.3,
           ZOffset=1),
        pe("Sparks", Texture=tex("sprites/stars/star_cel_01"), SpreadAngle=V2(180, 180), Speed=NR(16, 26), Drag=3.5, Acceleration=V3(0, -18, 0),
           Lifetime=NR(0.35, 0.55), Rotation=NR(0, 360), RotSpeed=NR(-400, 400), Size=NS((0, 1.3), (0.6, 1.0), (1, 0)),
           Color=CS((0, WHITE), (0.3, hexc("FFF07A")), (1, ORANGE)), LightEmission=0.35, ZOffset=2.5),
        pe("Streaks", Texture=tex("sprites/specks/streak_cel_00"), SpreadAngle=V2(180, 180), Speed=NR(26, 38), Drag=5, Lifetime=NR(0.16, 0.24),
           Size=NS((0, 1.6), (1, 0.4)), Color=CS((0, WHITE), (1, GOLD)), LightEmission=0.4, ZOffset=2, **STREAK),
    ]
    inst = [carrier("Hit", (0, 3.2, 0, 0, 0, 0), [att("A", children=a)]), light("Lamp", (0, 3.2, 0, 0, 0, 0), GOLD, 12)]
    for t, n in (("Star", 1), ("Core", 1), ("Lines", 1), ("Spiked", 1), ("Sparks", 9), ("Streaks", 10)):
        tl.at(0, do="emit", target=f"Hit.A.{t}", count=n)
    tl.at(0, do="set", target="Lamp.L", prop="Brightness", value=2.0)
    tl.at(0.02, do="tween", target="Lamp.L", prop="Brightness", to=0, time=0.3, style="Quad", dir="Out")
    effect("Train_Crit", "A PERFECT rep: the critical flash over the hit.", 0.7, inst, tl, [0.0, 0.03, 0.07, 0.12, 0.2, 0.35], GOLD,
           "starburst + speed lines", origin=(0, 3.2, 0), beats=["critical starburst"])


def train_flurry():
    """(loop) The awakening's flurry: hit marks all over the post's face, as fast as the fists."""
    face = [
        pe("Marks", Texture=tex("sprites/impacts/hit_cross_cel_00"), Shape=BOX, Rate=22, Speed=NR(0), Lifetime=NR(0.09, 0.12),
           Rotation=NR(0, 90), Size=NS((0, 1.6), (1, 2.6)), Color=CS((0, WHITE), (1, hexc("FFF07A"))), LightEmission=0.4, ZOffset=2.5),
        pe("Bursts", Texture=tex("sprites/impacts/comic_burst_cel_02"), Shape=BOX, Rate=11, Speed=NR(0), Lifetime=NR(0.12, 0.15),
           Rotation=NR(0, 360), Size=NS((0, 2.2), (1, 3.2)), Transparency=NS((0, 0), (0.6, 0), (1, 1)),
           Color=CS((0, WHITE), (0.5, hexc("FFF07A")), (1, ORANGE)), LightEmission=0.25, ZOffset=2),
        pe("Chips", Texture=tex("tfa/wood_splinter"), Shape=BOX, Rate=16, SpreadAngle=V2(180, 180), Speed=NR(9, 16), Drag=2,
           Acceleration=V3(0, -34, 0), Lifetime=NR(0.3, 0.5), Rotation=NR(0, 360), RotSpeed=NR(-500, 500),
           Size=NS((0, 0.6), (0.7, 0.5), (1, 0)), Color=CS(WHITE), LightEmission=0, ZOffset=1.5),
        pe("Sparks", Texture=tex("sprites/stars/star_cel_01"), Shape=BOX, Rate=14, SpreadAngle=V2(180, 180), Speed=NR(12, 20), Drag=3,
           Lifetime=NR(0.25, 0.4), Rotation=NR(0, 360), RotSpeed=NR(-300, 300), Size=NS((0, 0.9), (1, 0)), Color=CS((0, WHITE), (1, GOLD)),
           LightEmission=0.3, ZOffset=2),
    ]
    inst = [carrier("Face", (0, 3.2, 0, 0, 0, 0), face, size=(1.8, 2.6, 0.3))]
    effect("Train_Flurry", "The awakening's flurry on the post (loop).", 1.2, inst, TL(), [0.2, 0.4, 0.6, 0.8, 1.0], GOLD,
           "hit marks all over the post", loop=True, attach="part", origin=(0, 3.2, 0), beats=["a storm of hit marks"])


def train_pulse():
    """(tint) A breath let out under the falls: rings spread on the water, drops lift. Origin = the seat."""
    tl = TL()
    g = [
        ring("Ring", "sprites/rings/ring_cel_08", 3, 10, CS(WHITE), life=0.6, le=0.3, attrs=TINT),
        ring("Ripple", "tfa/pool_ripple", 4, 13, CS(WHITE), life=0.8, le=0.4, attrs=TINT, Transparency=NS((0, 0.1), (0.6, 0.3), (1, 1))),
        ring("Soft", "sprites/rings/ring_glow_02", 2, 8, CS(WHITE), life=0.5, le=0.5, attrs=TINT),
    ]
    a = [
        pe("Drops", attrs=TINT, Texture=tex("sprites/specks/dot_cel_00"), Shape=BOX, EmissionDirection=TOP, SpreadAngle=V2(14, 14),
           Speed=NR(5, 9), Drag=1.5, Acceleration=V3(0, -8, 0), Lifetime=NR(0.5, 0.8), Size=NS((0, 0), (0.15, 0.5), (0.7, 0.4), (1, 0)),
           Color=CS(WHITE), LightEmission=0.4, ZOffset=1),
        pe("Glints", Texture=tex("sprites/stars/star_glow_04"), Shape=BOX, EmissionDirection=TOP, SpreadAngle=V2(30, 30), Speed=NR(2, 5),
           Lifetime=NR(0.4, 0.7), Rotation=NR(0, 90), Size=NS((0, 0), (0.3, 0.9), (1, 0)), Color=CS(WHITE), LightEmission=0.7, ZOffset=1.2),
    ]
    inst = [carrier("Floor", (0, 0.15, 0, 0, 0, 0), [att("A", children=g)]), carrier("Rim", (0, 0.4, 0, 0, 0, 0), a, size=(5.5, 0.4, 5.5))]
    for t, n, when in (("Floor.A.Ring", 1, 0), ("Floor.A.Soft", 1, 0), ("Floor.A.Ripple", 1, 0.08), ("Rim.Drops", 12, 0), ("Rim.Glints", 5, 0.05)):
        tl.at(when, do="emit", target=t, count=n)
    effect("Train_Pulse", "A breath let out: rings on the water, drops rising.", 1.0, inst, tl, [0.0, 0.05, 0.12, 0.25, 0.45, 0.7], WATER,
           "ripple rings", origin=(0, 0, 0), beats=["rings spread on the water"])


# ------------------------------------------------------------------------------------ awakening
def train_awaken():
    """(tint) The hero awakens. Played at the root (3 above the floor)."""
    tl = TL()
    col = hexc("FFC24A")
    hit = [
        pop("sprites/impacts/starburst_cel_00", size=8, color=CS(WHITE), life=0.14, attrs=TINT),
        pe("Lines", attrs=TINT, Texture=tex("sprites/impacts/speed_lines_cel_02"), Lifetime=NR(0.25), Speed=NR(0), Rotation=NR(0, 360),
           Size=NS((0, 8), (1, 14)), Transparency=NS((0, 0.15), (0.5, 0.35), (1, 1)), Color=CS(WHITE), LightEmission=0.3, ZOffset=1.5),
        pe("Sparks", attrs=TINT, Texture=tex("flipbooks/specks/sparks_glow_00_8x8"), **dict(FB8, FlipbookFramerate=NR(64 / 0.5)),
           SpreadAngle=V2(180, 180), Speed=NR(10, 18), Drag=3, Lifetime=NR(0.45, 0.6), Rotation=NR(0, 360), Size=NS((0, 2.4), (1, 3.6)),
           Color=CS(WHITE), LightEmission=0.5, ZOffset=1),
        toss("Embers", "sprites/specks/ember_cel_01", NS((0, 0.9), (0.6, 0.7), (1, 0)), CS(WHITE), speed=(14, 24), spread=(70, 70), grav=-14,
             life=(0.6, 0.9), LightEmission=0.4),
    ]
    hit[3]["attrs"] = TINT
    ground = [
        ring("Shock", "sprites/rings/ring_spiked_cel_02", 4, 17, CS(WHITE), life=0.4, le=0.3, attrs=TINT),
        ring("Ring", "sprites/rings/ring_cel_08", 3, 12, CS(WHITE), life=0.5, le=0.3, attrs=TINT),
        ring("Crack", "sprites/cracks/crack_glow_01", 9, 10, CS(WHITE), life=0.9, le=0.5, attrs=TINT, Rotation=NR(0, 360),
             Transparency=NS((0, 0), (0.6, 0.2), (1, 1))),
    ]
    pil = pillar(col, core=WHITE, H=13, W=4.6)
    for child in pil[0]["children"]:
        if child.get("class") == "Beam":
            child["attrs"] = TINT
    pil[0]["CFrame"] = [0, 0.1, 0, 0, 0, 0]
    inst = [carrier("Hit", (0, 3, 0, 0, 0, 0), [att("A", children=hit)]), carrier("Ground", (0, 0.12, 0, 0, 0, 0), [att("A", children=ground)]),
            pil[0], light("Lamp", (0, 3, 0, 0, 0, 0), col, 18)]
    pillar_events(tl, pil[1], pil[2], hold=0.35)
    for t, n, when in (("Hit.A.Pop", 1, 0), ("Hit.A.Lines", 1, 0), ("Hit.A.Sparks", 10, 0), ("Hit.A.Embers", 14, 0), ("Ground.A.Shock", 1, 0),
                       ("Ground.A.Crack", 1, 0), ("Ground.A.Ring", 1, 0.07), ("Hit.A.Embers", 8, 0.15)):
        tl.at(when, do="emit", target=t, count=n)
    tl.at(0, do="set", target="Lamp.L", prop="Brightness", value=1.0)
    tl.at(0.02, do="tween", target="Lamp.L", prop="Brightness", to=0, time=0.5, style="Quad", dir="Out")
    effect("Train_Awaken", "The hero awakens: shock ring, pillar, burst.", 1.3, inst, tl, [0.0, 0.04, 0.1, 0.2, 0.35, 0.55, 0.8, 1.1], col,
           "burst + pillar", origin=(0, 3, 0), shake=0.4, cam=((8, 5, 16), (0, 5, 0)), beats=["pillar of ki", "shock ring"])


def train_aura():
    """(loop, tint) The awakened hero's aura: cel flames up round the body, embers, a breathing ring.
    Rides on the root (3 above the floor). All white: the tint is the ground's energy colour."""
    flames = [
        # (upright, facing the camera: with VelocityParallel a flame sprite is drawn lying on its side,
        # seen in the game as blobs streaming off the trainee's back)
        pe("Flames", attrs=TINT, Texture=tex("sprites/elements/flame_cel_02"), Shape=BOX, EmissionDirection=TOP, Rate=18, Speed=NR(7, 11),
           Lifetime=NR(0.45, 0.65), Rotation=NR(-10, 10), Size=NS((0, 2.2), (0.35, 3.8), (1, 1.0)),
           Transparency=NS((0, 0.2), (0.6, 0.3), (1, 1)), Color=CS(WHITE), LightEmission=0.2, LockedToPart=True, ZOffset=-1.6),
        pe("Tongues", attrs=TINT, Texture=tex("sprites/elements/flame_cel_05"), Shape=BOX, EmissionDirection=TOP, Rate=12, Speed=NR(10, 15),
           Lifetime=NR(0.35, 0.5), Rotation=NR(-14, 14), Size=NS((0, 1.5), (0.4, 3.0), (1, 0.5)),
           Transparency=NS((0, 0.15), (0.7, 0.25), (1, 1)), Color=CS(WHITE), LightEmission=0.3, LockedToPart=True, ZOffset=-1.4),
        pe("Lines", attrs=TINT, Texture=tex("sprites/specks/streak_cel_00"), Shape=BOX, EmissionDirection=TOP, Rate=16, Speed=NR(18, 26),
           Lifetime=NR(0.25, 0.35), Size=NS((0, 1.5), (1, 0.5)), Color=CS(WHITE), LightEmission=0.45, LockedToPart=True, ZOffset=0.8, **STREAK),
        pe("Embers", attrs=TINT, Texture=tex("sprites/specks/ember_cel_01"), Shape=BOX, EmissionDirection=TOP, SpreadAngle=V2(18, 18), Rate=12,
           Speed=NR(6, 11), Drag=0.6, Lifetime=NR(0.7, 1.1), Size=NS((0, 0), (0.2, 0.7), (1, 0)), Color=CS(WHITE), LightEmission=0.5, ZOffset=1),
    ]
    floor = [pe("Glow", attrs=TINT, Texture=tex("sprites/rings/ring_glow_02"), **FLAT, Rate=2.4, Lifetime=NR(0.7), Size=NS((0, 4), (1, 9)),
                Transparency=NS((0, 1), (0.2, 0.3), (1, 1)), Color=CS(WHITE), LightEmission=0.5, ZOffset=0.2),
             pe("Spiked", attrs=TINT, Texture=tex("sprites/rings/ring_spiked_cel_02"), **FLAT, Rate=1.6, Lifetime=NR(0.5), Rotation=NR(0, 360),
                Size=NS((0, 5), (1, 8)), Transparency=NS((0, 0.4), (1, 1)), Color=CS(WHITE), LightEmission=0.3, ZOffset=0.25)]
    inst = [carrier("Feet", (0, 0.5, 0, 0, 0, 0), flames, size=(3.4, 0.5, 3.4)), carrier("Floor", (0, 0.15, 0, 0, 0, 0), [att("A", children=floor)]),
            light("Lamp", (0, 3, 0, 0, 0, 0), hexc("FFC24A"), 14)]
    tl = TL()
    tl.at(0, do="set", target="Lamp.L", prop="Brightness", value=0.4)
    effect("Train_Aura", "The awakened hero's aura (loop).", 2.0, inst, tl, [0.4, 0.8, 1.2, 1.6], hexc("FFC24A"), "cel flames round the body",
           loop=True, attach="root", origin=(0, 3, 0), cam=((7, 5, 14), (0, 4.5, 0)), beats=["flames lick up the body"])


# ------------------------------------------------------------------------------------ the post's finish
def post_burst():
    """The post bursts into splinters. Origin = the contact point (3.2 up)."""
    tl = TL()
    dust = hexc("E6D2A8")
    a = [
        pop("sprites/impacts/starburst_cel_00", size=10, color=CS((0, WHITE), (1, hexc("FFF07A"))), life=0.14),
        pe("Lines", Texture=tex("sprites/impacts/speed_lines_cel_02"), Lifetime=NR(0.22), Speed=NR(0), Rotation=NR(0, 360),
           Size=NS((0, 9), (1, 15)), Transparency=NS((0, 0.1), (0.5, 0.3), (1, 1)), Color=CS(WHITE), LightEmission=0.3, ZOffset=1.5),
        pe("Shock", Texture=tex("sprites/rings/ring_spiked_cel_02"), Lifetime=NR(0.3), Speed=NR(0), Rotation=NR(0, 360),
           Size=NS((0, 3), (0.3, 10), (1, 13)), Transparency=NS((0, 0), (0.5, 0.1), (1, 1)), Color=CS((0, WHITE), (1, ORANGE)), LightEmission=0.3,
           ZOffset=1),
        # the post itself, in pieces: big splinters thrown out and up, tumbling, then falling
        pe("Splinters", Texture=tex("tfa/wood_splinter"), SpreadAngle=V2(180, 180), Speed=NR(16, 30), Drag=1.2, Acceleration=V3(0, -46, 0),
           Lifetime=NR(0.7, 1.1), Rotation=NR(0, 360), RotSpeed=NR(-700, 700), Size=NS((0, 2.4), (0.8, 2.0), (1, 0)), Color=CS(WHITE),
           LightEmission=0, ZOffset=2),
        pe("Chips", Texture=tex("tfa/wood_splinter"), SpreadAngle=V2(180, 180), Speed=NR(20, 40), Drag=2.5, Acceleration=V3(0, -40, 0),
           Lifetime=NR(0.45, 0.8), Rotation=NR(0, 360), RotSpeed=NR(-900, 900), Size=NS((0, 0.9), (0.7, 0.7), (1, 0)), Color=CS(WHITE),
           LightEmission=0, ZOffset=1.5),
        pe("Dust", Texture=tex("flipbooks/smoke/smoke_puff_fb_cel_03_4x4"), **fb(0.6), SpreadAngle=V2(180, 180), Speed=NR(8, 15), Drag=4,
           Acceleration=V3(0, 2, 0), Lifetime=NR(0.5, 0.7), Rotation=NR(0, 360), Size=NS((0, 3.0), (0.3, 5.0), (1, 6.0)), Transparency=FADE,
           Color=CS((0, WHITE), (1, dust)), LightEmission=0, ZOffset=0.3),
        pe("Sparks", Texture=tex("sprites/stars/star_cel_01"), SpreadAngle=V2(180, 180), Speed=NR(18, 30), Drag=3, Lifetime=NR(0.4, 0.6),
           Rotation=NR(0, 360), RotSpeed=NR(-300, 300), Size=NS((0, 1.4), (0.6, 1.0), (1, 0)), Color=CS((0, WHITE), (1, GOLD)), LightEmission=0.35,
           ZOffset=2.5),
    ]
    inst = [carrier("Hit", (0, 3.2, 0, 0, 0, 0), [att("A", children=a)]), light("Lamp", (0, 3.2, 0, 0, 0, 0), GOLD, 16)]
    for t, n, when in (("Pop", 1, 0), ("Lines", 1, 0), ("Shock", 1, 0), ("Splinters", 16, 0), ("Chips", 22, 0), ("Dust", 9, 0), ("Sparks", 12, 0),
                       ("Dust", 4, 0.1)):
        tl.at(when, do="emit", target=f"Hit.A.{t}", count=n)
    tl.at(0, do="set", target="Lamp.L", prop="Brightness", value=2.4)
    tl.at(0.02, do="tween", target="Lamp.L", prop="Brightness", to=0, time=0.4, style="Quad", dir="Out")
    effect("Post_Burst", "The post bursts into splinters at the end of the awakening.", 1.4, inst, tl,
           [0.0, 0.04, 0.1, 0.2, 0.35, 0.55, 0.8, 1.1], WOOD, "splinters + shock ring", origin=(0, 3.2, 0), shake=0.5,
           cam=((8, 5, 15), (0, 4, 0)), beats=["the post flies apart"])


def post_rise():
    """A new post comes up out of the floor: dust and chips kicked out round its foot. Origin = the floor."""
    tl = TL()
    dust = hexc("E6D2A8")
    rim = [
        pe("Dust", Texture=tex("flipbooks/smoke/smoke_puff_fb_cel_03_4x4"), **fb(0.55), Shape=E("ParticleEmitterShape.Cylinder"),
           ShapeStyle=E("ParticleEmitterShapeStyle.Surface"), EmissionDirection=TOP, SpreadAngle=V2(70, 70), Speed=NR(5, 9), Drag=4,
           Lifetime=NR(0.45, 0.6), Rotation=NR(0, 360), Size=NS((0, 1.8), (0.3, 3.0), (1, 3.6)), Transparency=FADE,
           Color=CS((0, WHITE), (1, dust)), LightEmission=0, ZOffset=0.3),
        pe("Chips", Texture=tex("sprites/elements/rock_chunk_cel_02"), Shape=E("ParticleEmitterShape.Cylinder"), EmissionDirection=TOP,
           SpreadAngle=V2(40, 40), Speed=NR(12, 20), Acceleration=V3(0, -50, 0), Lifetime=NR(0.4, 0.6), Rotation=NR(0, 360),
           RotSpeed=NR(-400, 400), Size=NS((0, 0.8), (0.8, 0.7), (1, 0)), Color=CS((0, WHITE), (1, hexc("C9B58A"))), LightEmission=0, ZOffset=0.6),
    ]
    g = [ring("Ring", "sprites/rings/ring_cel_08", 3, 11, CS((0, WHITE), (1, dust)), life=0.45, le=0.1),
         ring("Spiked", "sprites/rings/ring_spiked_cel_02", 3, 9, CS((0, WHITE), (1, GOLD)), life=0.35, le=0.3)]
    inst = [carrier("Rim", (0, 0.3, 0, 0, 0, 0), rim, size=(4.2, 0.4, 4.2)), carrier("Ground", (0, 0.12, 0, 0, 0, 0), [att("A", children=g)])]
    for t, n, when in (("Rim.Dust", 10, 0), ("Rim.Chips", 10, 0), ("Ground.A.Ring", 1, 0), ("Ground.A.Spiked", 1, 0.3), ("Rim.Dust", 6, 0.3)):
        tl.at(when, do="emit", target=t, count=n)
    effect("Post_Rise", "A new post rises out of the floor.", 1.0, inst, tl, [0.0, 0.05, 0.12, 0.25, 0.4, 0.6], WOOD, "dust ring at the foot",
           origin=(0, 0, 0), dummy=False, beats=["dust kicked out at the foot"])


# ------------------------------------------------------------------------------------ the falls
def falls_ascend():
    """(loop) Where the trainee floats: a column of light, water running UP it, drops rising. Origin =
    the seat (the top of the stone)."""
    H = 14.0
    col_beams = [
        att("Bot", (0, 0, 0, 0, 0, 90)), att("Top", (0, H, 0, 0, 0, 90)),
        # (seen in the game at max graphics: a wide soft halo, additive water and two lamps on the pale
        # rock blew the whole court out to white. Narrow, see-through, barely emissive, a weak lamp.)
        beam("Halo", "Column.Bot", "Column.Top", Texture=tex("tfa/pillar_soft"), TextureMode=E("TextureMode.Stretch"), Width0=4.6, Width1=3.2,
             Color=CS(DEEP), LightEmission=0.1, Transparency=NS((0, 0.72), (0.6, 0.85), (1, 1)), ZOffset=-1.5),
        # the falls' own water, running the other way: up
        beam("Water", "Column.Bot", "Column.Top", Texture=tex("tfa/water_sheet"), TextureMode=E("TextureMode.Wrap"), TextureLength=9,
             TextureSpeed=3.2, Width0=3.6, Width1=2.6, Color=CS(WHITE), LightEmission=0.05, Transparency=NS((0, 0.45), (0.7, 0.6), (1, 1)),
             ZOffset=-1.2),
        beam("Foam", "Column.Bot", "Column.Top", Texture=tex("tfa/water_foam"), TextureMode=E("TextureMode.Wrap"), TextureLength=7,
             TextureSpeed=5.0, Width0=3.2, Width1=2.2, Color=CS(WHITE), LightEmission=0.15, Transparency=NS((0, 0.35), (0.7, 0.55), (1, 1)),
             ZOffset=-1.0),
    ]
    rim = [
        pe("Drops", Texture=tex("sprites/specks/dot_cel_00"), Shape=BOX, EmissionDirection=TOP, SpreadAngle=V2(6, 6), Rate=26, Speed=NR(9, 16),
           Lifetime=NR(0.7, 1.1), Size=NS((0, 0), (0.15, 0.55), (0.8, 0.4), (1, 0)), Color=CS((0, WHITE), (1, WATER)), LightEmission=0.45, ZOffset=1),
        pe("Streaks", Texture=tex("sprites/specks/streak_cel_00"), Shape=BOX, EmissionDirection=TOP, Rate=14, Speed=NR(20, 30),
           Lifetime=NR(0.3, 0.45), Size=NS((0, 1.6), (1, 0.5)), Color=CS((0, WHITE), (1, WATER)), LightEmission=0.4, ZOffset=0.8, **STREAK),
        pe("Glints", Texture=tex("sprites/stars/star_glow_04"), Shape=BOX, EmissionDirection=TOP, SpreadAngle=V2(25, 25), Rate=8, Speed=NR(3, 7),
           Lifetime=NR(0.6, 0.9), Rotation=NR(0, 90), Size=NS((0, 0), (0.3, 1.0), (1, 0)), Color=CS(WHITE), LightEmission=0.7, ZOffset=1.2),
    ]
    g = [pe("Ripple", Texture=tex("tfa/pool_ripple"), **FLAT, Rate=2.2, Lifetime=NR(0.9), Size=NS((0, 4), (1, 13)),
            Transparency=NS((0, 0.15), (0.6, 0.35), (1, 1)), Color=CS((0, WHITE), (1, WATER)), LightEmission=0.4, ZOffset=0.2),
         pe("Glow", Texture=tex("sprites/rings/ring_cel_08"), **FLAT, Rate=1.6, Lifetime=NR(0.8), Size=NS((0, 5), (1, 10)),
            Transparency=NS((0, 1), (0.2, 0.45), (1, 1)), Color=CS(WATER), LightEmission=0.2, ZOffset=0.15)]
    inst = [carrier("Column", (0, -0.6, -1.4, 0, 0, 0), col_beams), carrier("Rim", (0, -0.9, 0, 0, 0, 0), rim, size=(5.0, 0.4, 5.0)),
            carrier("Floor", (0, -1.0, 0, 0, 0, 0), [att("A", children=g)]), light("Lamp", (0, 2.5, 0, 0, 0, 0), WATER, 16)]
    tl = TL()
    tl.at(0, do="set", target="Lamp.L", prop="Brightness", value=0.35)
    effect("Falls_Ascend", "The column of light and rising water of the Waterfall's awakening (loop).", 2.0, inst, tl, [0.4, 0.8, 1.2, 1.6], WATER,
           "column of rising water", loop=True, attach="part", origin=(0, 0, 0), cam=((6, 5, 16), (0, 5, 0)),
           beats=["water runs up the column"])


def falls_crash():
    """The falls come back down on the pool. Origin = the pool's surface, at the foot of the falls."""
    tl = TL()
    a = [
        pe("Splash", Texture=tex("flipbooks/water/water_splash_cel_00_4x4"), **fb(0.5), Shape=BOX, EmissionDirection=TOP, Speed=NR(2, 4),
           Lifetime=NR(0.45, 0.55), Rotation=NR(-8, 8), Size=NS((0, 4.5), (0.3, 7.5), (1, 8.5)), Transparency=NS((0, 0), (0.7, 0.1), (1, 1)),
           Color=CS((0, WHITE), (1, hexc("CDEFFF"))), LightEmission=0.25, ZOffset=1),
        toss("Drops", "sprites/specks/dot_cel_00", NS((0, 0.8), (0.7, 0.6), (1, 0)), CS((0, WHITE), (1, WATER)), speed=(18, 32), spread=(55, 55),
             grav=-60, life=(0.6, 1.0), LightEmission=0.35),
        pe("Mist", Texture=tex("sprites/smoke/smoke_puff_soft_02"), Shape=BOX, EmissionDirection=TOP, SpreadAngle=V2(70, 70), Speed=NR(5, 10),
           Drag=3, Lifetime=NR(0.8, 1.2), Rotation=NR(0, 360), RotSpeed=NR(-30, 30), Size=NS((0, 3), (1, 7)),
           Transparency=NS((0, 0.55), (0.5, 0.7), (1, 1)), Color=CS(WHITE), LightEmission=0.1, ZOffset=0.4),
        pe("Streaks", Texture=tex("sprites/specks/streak_cel_00"), Shape=BOX, EmissionDirection=TOP, SpreadAngle=V2(35, 35), Speed=NR(28, 42),
           Acceleration=V3(0, -70, 0), Lifetime=NR(0.3, 0.5), Size=NS((0, 1.8), (1, 0.5)), Color=CS((0, WHITE), (1, WATER)), LightEmission=0.4,
           ZOffset=1.2, **STREAK),
    ]
    g = [ring("Ring", "sprites/rings/ring_cel_08", 5, 17, CS((0, WHITE), (1, WATER)), life=0.55, le=0.3),
         ring("Ripple", "tfa/pool_ripple", 6, 18, CS(WHITE), life=0.9, le=0.4, Transparency=NS((0, 0.1), (0.6, 0.3), (1, 1))),
         ring("Ring2", "sprites/rings/ring_glow_02", 4, 12, CS(WATER), life=0.6, le=0.5)]
    inst = [carrier("Foot", (0, 0.5, 0, 0, 0, 0), a, size=(6.0, 0.5, 1.6)), carrier("Ground", (0, 0.15, 0, 0, 0, 0), [att("A", children=g)])]
    for t, n, when in (("Foot.Splash", 5, 0), ("Foot.Drops", 26, 0), ("Foot.Streaks", 14, 0), ("Foot.Mist", 6, 0.03), ("Ground.A.Ring", 1, 0),
                       ("Ground.A.Ring2", 1, 0.05), ("Ground.A.Ripple", 1, 0.1), ("Foot.Splash", 3, 0.12), ("Foot.Mist", 4, 0.25)):
        tl.at(when, do="emit", target=t, count=n)
    effect("Falls_Crash", "The falls crash back onto the pool at the end of the awakening.", 1.5, inst, tl,
           [0.0, 0.04, 0.1, 0.2, 0.35, 0.55, 0.8, 1.1], WATER, "wall of splash", origin=(0, 0, 0), shake=0.4, dummy=False,
           cam=((7, 5, 15), (0, 3.5, 0)), beats=["a wall of water goes up"])


# ------------------------------------------------------------------------------------ Boulder Breaker (phase E)
STONE = hexc("9A9CA4")
ROCK = "sprites/elements/rock_chunk_cel_02"


def boulder_hit():
    """A heavy blow on the boulder. Origin = the contact point (3.2 up in the strips)."""
    tl = TL()
    dust = hexc("D9D6CC")
    a = [
        pe("Burst", Texture=tex("sprites/impacts/comic_burst_cel_02"), Lifetime=NR(0.16), Speed=NR(0), Rotation=NR(0, 360),
           Size=NS((0, 3.8), (1, 4.8)), Transparency=NS((0, 0), (0.6, 0), (1, 1)), Color=CS((0, WHITE), (0.5, hexc("FFE9A8")), (1, ORANGE)),
           LightEmission=0.2, ZOffset=2),
        pe("Crack", Texture=tex("sprites/cracks/crack_cel_02"), Lifetime=NR(0.3), Speed=NR(0), Rotation=NR(0, 360),
           Size=NS((0, 3.2), (0.2, 4.6), (1, 4.8)), Transparency=NS((0, 0), (0.6, 0.1), (1, 1)), Color=CS((0, WHITE), (1, hexc("3A3A44"))),
           LightEmission=0, ZOffset=1.5),
        pe("Ring", Texture=tex("sprites/rings/ring_cel_04"), Lifetime=NR(0.22), Speed=NR(0), Size=NS((0, 1.8), (0.3, 4.2), (1, 5.0)),
           Transparency=NS((0, 0), (1, 1)), Color=CS((0, WHITE), (1, STONE)), LightEmission=0.2, ZOffset=1),
        pe("Chips", Texture=tex(ROCK), SpreadAngle=V2(180, 180), Speed=NR(10, 18), Drag=2, Acceleration=V3(0, -42, 0),
           Lifetime=NR(0.35, 0.6), Rotation=NR(0, 360), RotSpeed=NR(-500, 500), Size=NS((0, 0.75), (0.7, 0.65), (1, 0)),
           Color=CS((0, WHITE), (1, hexc("C8C8D0"))), LightEmission=0, ZOffset=1.5),
        pe("Dust", Texture=tex("flipbooks/smoke/smoke_puff_fb_cel_03_4x4"), **fb(0.5), SpreadAngle=V2(180, 180), Speed=NR(3, 6), Drag=4,
           Lifetime=NR(0.4, 0.5), Rotation=NR(0, 360), Size=NS((0, 1.6), (1, 3.0)), Transparency=NS((0, 0.25), (0.6, 0.45), (1, 1)),
           Color=CS((0, WHITE), (1, dust)), LightEmission=0, ZOffset=0.5),
    ]
    inst = [carrier("Hit", (0, 3.2, 0, 0, 0, 0), [att("A", children=a)])]
    for t, n in (("Burst", 1), ("Crack", 1), ("Ring", 1), ("Chips", 6), ("Dust", 3)):
        tl.at(0, do="emit", target=f"Hit.A.{t}", count=n)
    effect("Boulder_Hit", "A heavy blow lands on the boulder: crack flash, rock chips, dust.", 0.7, inst, tl, [0.0, 0.03, 0.07, 0.12, 0.2, 0.35], STONE,
           "crack + rock chips", origin=(0, 3.2, 0), beats=["a crack flashes on the rock"])


def boulder_barrage():
    """(loop) The awakening's barrage on the boulder's face: bursts, chips and dust all over it."""
    face = [
        pe("Bursts", Texture=tex("sprites/impacts/comic_burst_cel_02"), Shape=BOX, Rate=10, Speed=NR(0), Lifetime=NR(0.12, 0.16),
           Rotation=NR(0, 360), Size=NS((0, 2.8), (1, 4.0)), Transparency=NS((0, 0), (0.6, 0), (1, 1)),
           Color=CS((0, WHITE), (0.5, hexc("FFE9A8")), (1, ORANGE)), LightEmission=0.2, ZOffset=2),
        pe("Cracks", Texture=tex("sprites/cracks/crack_cel_02"), Shape=BOX, Rate=7, Speed=NR(0), Lifetime=NR(0.25, 0.3), Rotation=NR(0, 360),
           Size=NS((0, 2.6), (1, 4.2)), Transparency=NS((0, 0), (0.6, 0.1), (1, 1)), Color=CS((0, WHITE), (1, hexc("3A3A44"))), LightEmission=0,
           ZOffset=1.5),
        pe("Chips", Texture=tex(ROCK), Shape=BOX, Rate=22, SpreadAngle=V2(180, 180), Speed=NR(10, 20), Drag=2, Acceleration=V3(0, -42, 0),
           Lifetime=NR(0.35, 0.6), Rotation=NR(0, 360), RotSpeed=NR(-500, 500), Size=NS((0, 0.8), (0.7, 0.7), (1, 0)),
           Color=CS((0, WHITE), (1, hexc("C8C8D0"))), LightEmission=0, ZOffset=1.5),
        pe("Dust", Texture=tex("flipbooks/smoke/smoke_puff_fb_cel_03_4x4"), **fb(0.5), Shape=BOX, Rate=8, SpreadAngle=V2(180, 180),
           Speed=NR(3, 6), Drag=4, Lifetime=NR(0.4, 0.5), Rotation=NR(0, 360), Size=NS((0, 1.8), (1, 3.2)),
           Transparency=NS((0, 0.35), (0.6, 0.5), (1, 1)), Color=CS((0, WHITE), (1, hexc("D9D6CC"))), LightEmission=0, ZOffset=0.5),
    ]
    inst = [carrier("Face", (0, 3.2, 0, 0, 0, 0), face, size=(3.0, 3.2, 0.3))]
    effect("Boulder_Barrage", "The awakening's barrage on the boulder (loop).", 1.2, inst, TL(), [0.2, 0.4, 0.6, 0.8, 1.0], STONE,
           "bursts and chips all over the rock", loop=True, attach="part", origin=(0, 3.2, 0), beats=["the rock is being taken apart"])


def boulder_shatter():
    """The boulder shatters. Origin = the middle of the boulder (3.2 up)."""
    tl = TL()
    dust = hexc("D9D6CC")
    a = [
        pop("sprites/impacts/starburst_cel_00", size=12, color=CS((0, hexc("FFE35A")), (1, ORANGE)), life=0.14, LightEmission=0.15),
        pe("Lines", Texture=tex("sprites/impacts/speed_lines_cel_02"), Lifetime=NR(0.22), Speed=NR(0), Rotation=NR(0, 360),
           Size=NS((0, 10), (1, 17)), Transparency=NS((0, 0.1), (0.5, 0.3), (1, 1)), Color=CS(WHITE), LightEmission=0.3, ZOffset=1.5),
        pe("Shock", Texture=tex("sprites/rings/ring_spiked_cel_02"), Lifetime=NR(0.32), Speed=NR(0), Rotation=NR(0, 360),
           Size=NS((0, 4), (0.3, 12), (1, 15)), Transparency=NS((0, 0), (0.5, 0.1), (1, 1)), Color=CS((0, WHITE), (1, STONE)), LightEmission=0.2,
           ZOffset=1),
        # the boulder itself, in pieces: big chunks thrown out and up, tumbling, then falling
        pe("Chunks", Texture=tex(ROCK), Shape=E("ParticleEmitterShape.Sphere"), SpreadAngle=V2(180, 180), Speed=NR(16, 32), Drag=1.0,
           Acceleration=V3(0, -52, 0), Lifetime=NR(0.8, 1.2), Rotation=NR(0, 360), RotSpeed=NR(-500, 500),
           Size=NS((0, 2.8), (0.8, 2.4), (1, 0)), Color=CS((0, WHITE), (1, hexc("C8C8D0"))), LightEmission=0, ZOffset=2),
        pe("Chips", Texture=tex(ROCK), Shape=E("ParticleEmitterShape.Sphere"), SpreadAngle=V2(180, 180), Speed=NR(22, 44), Drag=2.2,
           Acceleration=V3(0, -46, 0), Lifetime=NR(0.5, 0.9), Rotation=NR(0, 360), RotSpeed=NR(-800, 800),
           Size=NS((0, 1.1), (0.7, 0.9), (1, 0)), Color=CS((0, WHITE), (1, hexc("B8B8C2"))), LightEmission=0, ZOffset=1.5),
        pe("Dust", Texture=tex("flipbooks/smoke/smoke_puff_fb_cel_03_4x4"), **fb(0.7), Shape=E("ParticleEmitterShape.Sphere"),
           SpreadAngle=V2(180, 180), Speed=NR(8, 16), Drag=4, Acceleration=V3(0, 2, 0), Lifetime=NR(0.6, 0.8), Rotation=NR(0, 360),
           Size=NS((0, 3.6), (0.3, 6.0), (1, 7.2)), Transparency=FADE, Color=CS((0, WHITE), (1, dust)), LightEmission=0, ZOffset=0.3),
    ]
    inst = [carrier("Hit", (0, 3.2, 0, 0, 0, 0), a, size=(3.6, 4.4, 3.6)), light("Lamp", (0, 3.2, 0, 0, 0, 0), GOLD, 16)]
    for t, n, when in (("Pop", 1, 0), ("Lines", 1, 0), ("Shock", 1, 0), ("Chunks", 18, 0), ("Chips", 26, 0), ("Dust", 10, 0), ("Dust", 5, 0.1)):
        tl.at(when, do="emit", target=f"Hit.{t}", count=n)
    tl.at(0, do="set", target="Lamp.L", prop="Brightness", value=1.4)
    tl.at(0.02, do="tween", target="Lamp.L", prop="Brightness", to=0, time=0.4, style="Quad", dir="Out")
    effect("Boulder_Shatter", "The boulder shatters at the end of the awakening.", 1.5, inst, tl, [0.0, 0.04, 0.1, 0.2, 0.35, 0.55, 0.8, 1.1], STONE,
           "rock chunks + shock ring", origin=(0, 3.2, 0), shake=0.6, cam=((9, 5, 16), (0, 4, 0)), beats=["the boulder flies apart"])


def boulder_land():
    """A new, bigger boulder lands on the floor. Origin = the floor under it."""
    tl = TL()
    dust = hexc("D9D6CC")
    rim = [
        pe("Dust", Texture=tex("flipbooks/smoke/smoke_puff_fb_cel_03_4x4"), **fb(0.65), Shape=E("ParticleEmitterShape.Cylinder"),
           ShapeStyle=E("ParticleEmitterShapeStyle.Surface"), EmissionDirection=TOP, SpreadAngle=V2(80, 80), Speed=NR(8, 14), Drag=4,
           Lifetime=NR(0.55, 0.7), Rotation=NR(0, 360), Size=NS((0, 2.6), (0.3, 4.4), (1, 5.2)), Transparency=FADE,
           Color=CS((0, WHITE), (1, dust)), LightEmission=0, ZOffset=0.3),
        pe("Chips", Texture=tex(ROCK), Shape=E("ParticleEmitterShape.Cylinder"), EmissionDirection=TOP, SpreadAngle=V2(45, 45),
           Speed=NR(16, 26), Acceleration=V3(0, -56, 0), Lifetime=NR(0.5, 0.75), Rotation=NR(0, 360), RotSpeed=NR(-400, 400),
           Size=NS((0, 1.0), (0.8, 0.9), (1, 0)), Color=CS((0, WHITE), (1, hexc("C8C8D0"))), LightEmission=0, ZOffset=0.6),
    ]
    g = [ring("Ring", "sprites/rings/ring_cel_08", 5, 16, CS((0, WHITE), (1, dust)), life=0.5, le=0.1),
         ring("Spiked", "sprites/rings/ring_spiked_cel_02", 5, 14, CS((0, WHITE), (1, GOLD)), life=0.4, le=0.25),
         ring("Crack", "sprites/cracks/crack_cel_02", 11, 12, CS((0, hexc("3A3A44")), (1, hexc("3A3A44"))), life=1.2, le=0, Rotation=NR(0, 360),
              Transparency=NS((0, 0), (0.7, 0.1), (1, 1)))]
    inst = [carrier("Rim", (0, 0.3, 0, 0, 0, 0), rim, size=(6.0, 0.4, 6.0)), carrier("Ground", (0, 0.12, 0, 0, 0, 0), [att("A", children=g)])]
    for t, n, when in (("Rim.Dust", 14, 0), ("Rim.Chips", 14, 0), ("Ground.A.Ring", 1, 0), ("Ground.A.Spiked", 1, 0), ("Ground.A.Crack", 1, 0),
                       ("Rim.Dust", 6, 0.12)):
        tl.at(when, do="emit", target=t, count=n)
    effect("Boulder_Land", "A new boulder lands: dust, chips, a cracked floor.", 1.3, inst, tl, [0.0, 0.05, 0.12, 0.25, 0.4, 0.6], STONE,
           "dust ring + cracked floor", origin=(0, 0, 0), shake=0.5, dummy=False, beats=["the floor cracks under it"])


# ------------------------------------------------------------------------------------ Thunder Peak (phase E)
VOLT = hexc("FFE85A")
ARC = hexc("7FD8FF")
BOLT = "sprites/elements/bolt_cel_04"


def bolt_beams(name, H, width):
    """A lightning bolt as two beams on one carrier, from the origin straight up H studs."""
    return carrier(name, (0, 0, 0, 0, 0, 0), [
        att("Bot", (0, 0, 0, 0, 0, 90)), att("Top", (0, H, 0, 0, 0, 90)),
        beam("Glow", f"{name}.Bot", f"{name}.Top", Texture=tex("tfa/pillar_soft"), TextureMode=E("TextureMode.Stretch"), Width0=width * 1.7,
             Width1=width * 1.2, Color=CS(ARC), LightEmission=0.15, Transparency=NS((0, 0.6), (0.7, 0.75), (1, 1)), Enabled=False, ZOffset=-0.2),
        beam("Core", f"{name}.Bot", f"{name}.Top", Texture=tex("tfa/bolt_strip"), TextureMode=E("TextureMode.Stretch"), Width0=width,
             Width1=width, Color=CS((0, WHITE), (1, VOLT)), LightEmission=0.4, Brightness=1.6, Transparency=NS((0, 0), (1, 0)), Enabled=False,
             ZOffset=0.1),
    ])


def bolt_flicker(tl, name, t0=0.0):
    """On for two frames, off for one, on again, gone: lightning."""
    for b in ("Glow", "Core"):
        for t, on in ((t0, True), (t0 + 0.07, False), (t0 + 0.1, True), (t0 + 0.2, False)):
            tl.at(t, do="set", target=f"{name}.{b}", prop="Enabled", value=on)


def peak_strike():
    """Lightning strikes a rod. Origin = the rod's tip."""
    tl = TL()
    a = [
        pop("sprites/impacts/starburst_cel_00", size=6.5, color=CS((0, WHITE), (1, VOLT)), life=0.12, LightEmission=0.3),
        pe("Forks", Texture=tex(BOLT), SpreadAngle=V2(180, 180), Speed=NR(0.5, 2), Lifetime=NR(0.12, 0.2), Rotation=NR(0, 360),
           Size=NS((0, 2.6), (1, 4.2)), Transparency=NS((0, 0), (0.6, 0), (1, 1)), Color=CS((0, WHITE), (1, VOLT)), LightEmission=0.4, ZOffset=1),
        pe("Sparks", Texture=tex("sprites/specks/streak_cel_00"), SpreadAngle=V2(180, 180), Speed=NR(22, 36), Drag=4, Acceleration=V3(0, -30, 0),
           Lifetime=NR(0.2, 0.35), Size=NS((0, 1.4), (1, 0.4)), Color=CS((0, WHITE), (1, VOLT)), LightEmission=0.45, ZOffset=1, **STREAK),
        pe("Ring", Texture=tex("sprites/rings/ring_cel_04"), Lifetime=NR(0.22), Speed=NR(0), Size=NS((0, 1.5), (0.3, 4.5), (1, 5.5)),
           Transparency=NS((0, 0), (1, 1)), Color=CS((0, WHITE), (1, ARC)), LightEmission=0.3, ZOffset=0.5),
    ]
    inst = [bolt_beams("Bolt", 46, 4.2), carrier("Tip", (0, 0, 0, 0, 0, 0), [att("A", children=a)]), light("Lamp", (0, 1, 0, 0, 0, 0), VOLT, 18)]
    bolt_flicker(tl, "Bolt")
    for t, n, when in (("Pop", 1, 0), ("Forks", 4, 0), ("Sparks", 12, 0), ("Ring", 1, 0), ("Forks", 3, 0.1), ("Sparks", 6, 0.1)):
        tl.at(when, do="emit", target=f"Tip.A.{t}", count=n)
    tl.at(0, do="set", target="Lamp.L", prop="Brightness", value=0.5)
    tl.at(0.02, do="tween", target="Lamp.L", prop="Brightness", to=0, time=0.3, style="Quad", dir="Out")
    effect("Peak_Strike", "Lightning strikes a rod: a bolt from the sky, forks and sparks at the tip.", 0.8, inst, tl, [0.0, 0.03, 0.08, 0.12, 0.2, 0.35],
           VOLT, "bolt from the sky", origin=(0, 0, 0), dummy=False, cam=((10, 8, 30), (0, 14, 0)), beats=["the bolt flickers twice"])


def peak_catch():
    """(tint) The hero catches the bolt. Origin = the catching hand."""
    tl = TL()
    a = [
        pop("sprites/impacts/starburst_cel_00", size=5.5, color=CS(WHITE), life=0.12, attrs=TINT, LightEmission=0.3),
        pe("Forks", attrs=TINT, Texture=tex(BOLT), SpreadAngle=V2(180, 180), Speed=NR(1, 3), Lifetime=NR(0.14, 0.24), Rotation=NR(0, 360),
           Size=NS((0, 2.2), (1, 3.8)), Transparency=NS((0, 0), (0.6, 0), (1, 1)), Color=CS(WHITE), LightEmission=0.4, ZOffset=1),
        pe("Sparks", attrs=TINT, Texture=tex("sprites/specks/streak_cel_00"), SpreadAngle=V2(180, 180), Speed=NR(18, 30), Drag=4,
           Lifetime=NR(0.2, 0.3), Size=NS((0, 1.3), (1, 0.4)), Color=CS(WHITE), LightEmission=0.45, ZOffset=1, **STREAK),
        pe("Ring", attrs=TINT, Texture=tex("sprites/rings/ring_spiked_cel_02"), Lifetime=NR(0.24), Speed=NR(0), Rotation=NR(0, 360),
           Size=NS((0, 2), (0.3, 5.5), (1, 6.5)), Transparency=NS((0, 0), (1, 1)), Color=CS(WHITE), LightEmission=0.3, ZOffset=0.5),
    ]
    inst = [carrier("Hand", (0, 5, 0, 0, 0, 0), [att("A", children=a)])]
    for t, n, when in (("Pop", 1, 0), ("Forks", 5, 0), ("Sparks", 10, 0), ("Ring", 1, 0), ("Forks", 3, 0.12), ("Forks", 3, 0.24)):
        tl.at(when, do="emit", target=f"Hand.A.{t}", count=n)
    effect("Peak_Catch", "The hero catches the bolt: forks and sparks at the hand.", 0.8, inst, tl, [0.0, 0.03, 0.08, 0.14, 0.25, 0.4], VOLT,
           "electric burst at the hand", origin=(0, 5, 0), beats=["the hand crackles"])


def peak_storm():
    """(loop) The awakened hero is wrapped in lightning. Rides on the root (3 above the floor)."""
    body = [
        pe("Forks", Texture=tex(BOLT), Shape=BOX, Rate=16, Speed=NR(0), Lifetime=NR(0.08, 0.14), Rotation=NR(0, 360),
           Size=NS((0, 2.4), (1, 3.6)), Color=CS((0, WHITE), (1, VOLT)), LightEmission=0.4, LockedToPart=True, ZOffset=0.6),
        pe("Arcs", Texture=tex(BOLT), Shape=BOX, Rate=9, Speed=NR(0), Lifetime=NR(0.1, 0.16), Rotation=NR(0, 360), Size=NS((0, 4.0), (1, 5.5)),
           Color=CS((0, WHITE), (1, ARC)), LightEmission=0.3, LockedToPart=True, ZOffset=-1.2),
        pe("Sparks", Texture=tex("sprites/specks/streak_cel_00"), Shape=BOX, Rate=18, SpreadAngle=V2(180, 180), Speed=NR(14, 24), Drag=4,
           Lifetime=NR(0.18, 0.3), Size=NS((0, 1.2), (1, 0.4)), Color=CS((0, WHITE), (1, VOLT)), LightEmission=0.45, ZOffset=1, **STREAK),
    ]
    floor = [pe("Spiked", Texture=tex("sprites/rings/ring_spiked_cel_02"), **FLAT, Rate=2.2, Lifetime=NR(0.45), Rotation=NR(0, 360),
                Size=NS((0, 5), (1, 9)), Transparency=NS((0, 0.3), (1, 1)), Color=CS((0, WHITE), (1, VOLT)), LightEmission=0.3, ZOffset=0.25)]
    inst = [carrier("Body", (0, 3.2, 0, 0, 0, 0), body, size=(3.2, 5.0, 2.4)), carrier("Floor", (0, 0.15, 0, 0, 0, 0), [att("A", children=floor)]),
            light("Lamp", (0, 3, 0, 0, 0, 0), VOLT, 14)]
    tl = TL()
    tl.at(0, do="set", target="Lamp.L", prop="Brightness", value=0.3)
    effect("Peak_Storm", "The awakened hero is wrapped in lightning (loop).", 2.0, inst, tl, [0.4, 0.8, 1.2, 1.6], VOLT, "lightning round the body",
           loop=True, attach="root", origin=(0, 3, 0), cam=((7, 5, 14), (0, 4.5, 0)), beats=["forks crawl over the body"])


def peak_finale():
    """The awakening ends: one enormous bolt on the hero. Origin = the hero's feet."""
    tl = TL()
    a = [
        pop("sprites/impacts/starburst_cel_00", size=13, color=CS((0, WHITE), (1, VOLT)), life=0.16, LightEmission=0.3),
        pe("Lines", Texture=tex("sprites/impacts/speed_lines_cel_02"), Lifetime=NR(0.24), Speed=NR(0), Rotation=NR(0, 360),
           Size=NS((0, 10), (1, 18)), Transparency=NS((0, 0.1), (0.5, 0.3), (1, 1)), Color=CS(WHITE), LightEmission=0.3, ZOffset=1.5),
        pe("Forks", Texture=tex(BOLT), SpreadAngle=V2(180, 180), Speed=NR(4, 10), Lifetime=NR(0.16, 0.28), Rotation=NR(0, 360),
           Size=NS((0, 4.0), (1, 7.0)), Transparency=NS((0, 0), (0.6, 0), (1, 1)), Color=CS((0, WHITE), (1, VOLT)), LightEmission=0.4, ZOffset=1),
        pe("Sparks", Texture=tex("sprites/specks/streak_cel_00"), SpreadAngle=V2(180, 180), Speed=NR(28, 48), Drag=4, Acceleration=V3(0, -30, 0),
           Lifetime=NR(0.25, 0.45), Size=NS((0, 1.8), (1, 0.5)), Color=CS((0, WHITE), (1, VOLT)), LightEmission=0.45, ZOffset=1, **STREAK),
    ]
    g = [ring("Shock", "sprites/rings/ring_spiked_cel_02", 5, 19, CS((0, WHITE), (1, VOLT)), life=0.4, le=0.3),
         ring("Ring", "sprites/rings/ring_cel_08", 4, 14, CS((0, WHITE), (1, ARC)), life=0.5, le=0.3),
         ring("Scorch", "sprites/cracks/crack_cel_02", 10, 11, CS(hexc("2A2A34")), life=1.2, le=0, Rotation=NR(0, 360),
              Transparency=NS((0, 0), (0.7, 0.1), (1, 1)))]
    inst = [bolt_beams("Bolt", 50, 7.5), carrier("Hit", (0, 3, 0, 0, 0, 0), [att("A", children=a)]),
            carrier("Ground", (0, 0.12, 0, 0, 0, 0), [att("A", children=g)]), light("Lamp", (0, 3, 0, 0, 0, 0), VOLT, 20)]
    bolt_flicker(tl, "Bolt")
    for t, n, when in (("Hit.A.Pop", 1, 0), ("Hit.A.Lines", 1, 0), ("Hit.A.Forks", 8, 0), ("Hit.A.Sparks", 20, 0), ("Ground.A.Shock", 1, 0),
                       ("Ground.A.Scorch", 1, 0), ("Ground.A.Ring", 1, 0.06), ("Hit.A.Forks", 5, 0.1), ("Hit.A.Sparks", 10, 0.1)):
        tl.at(when, do="emit", target=t, count=n)
    tl.at(0, do="set", target="Lamp.L", prop="Brightness", value=1.4)
    tl.at(0.02, do="tween", target="Lamp.L", prop="Brightness", to=0, time=0.45, style="Quad", dir="Out")
    effect("Peak_Finale", "The Thunder Peak's awakening ends: one enormous bolt on the hero.", 1.5, inst, tl,
           [0.0, 0.04, 0.1, 0.2, 0.35, 0.55, 0.8, 1.1], VOLT, "giant bolt + shock ring", origin=(0, 0, 0), shake=0.6, cam=((10, 8, 30), (0, 12, 0)),
           beats=["the sky comes down on the hero"])


# ------------------------------------------------------------------------------------ Gravity Chamber (phase E, pair 2)
# Seen side-on and LOW (the push-up camera stands 9 studs off, 1.5 up): what lies flat on the floor is a
# thin ellipse there, so every effect also has something that stands up off the floor.
GRAV = hexc("B58CFF")
BOTTOM = E("NormalId.Bottom")
HEXES = "sprites/sigils/hex_grid_cel_02"


def gravity_pulse():
    """(tint) A push-up lands under heavy gravity: the floor rings under the chest. Origin = the floor."""
    tl = TL()
    g = [
        ring("Ring", "sprites/rings/ring_cel_08", 2.5, 9, CS(WHITE), life=0.4, le=0.3, attrs=TINT),
        ring("Dashed", "sprites/rings/ring_dashed_cel_02", 2, 6.5, CS(WHITE), life=0.5, le=0.35, attrs=TINT, Rotation=NR(0, 360)),
        ring("Plates", HEXES, 5.5, 6.5, CS(WHITE), life=0.35, le=0.3, attrs=TINT, Transparency=NS((0, 0.25), (0.5, 0.45), (1, 1))),
    ]
    press = [
        # the weight coming down: short streaks falling onto the floor round the body
        pe("Press", attrs=TINT, Texture=tex("tfa/speed_line"), Shape=BOX, EmissionDirection=BOTTOM, SpreadAngle=V2(0, 0),
           Speed=NR(22, 30), Lifetime=NR(0.09, 0.12), Size=NS((0, 1.5), (1, 0.6)), Color=CS(WHITE), LightEmission=0.4, ZOffset=1, **STREAK),
    ]
    rim = [
        pe("Dust", Texture=tex("flipbooks/smoke/smoke_puff_fb_cel_03_4x4"), **fb(0.4), Shape=E("ParticleEmitterShape.Cylinder"),
           ShapeStyle=E("ParticleEmitterShapeStyle.Surface"), EmissionDirection=TOP, SpreadAngle=V2(80, 80), Speed=NR(2, 4), Drag=4,
           Lifetime=NR(0.3, 0.4), Rotation=NR(0, 360), Size=NS((0, 0.9), (1, 1.8)), Transparency=NS((0, 0.35), (0.6, 0.5), (1, 1)),
           Color=CS((0, WHITE), (1, hexc("CFC8E6"))), LightEmission=0, ZOffset=0.4),
        pe("Motes", attrs=TINT, Texture=tex("sprites/specks/dot_cel_00"), Shape=E("ParticleEmitterShape.Cylinder"), EmissionDirection=TOP,
           SpreadAngle=V2(25, 25), Speed=NR(4, 8), Drag=3, Lifetime=NR(0.3, 0.45), Size=NS((0, 0.4), (1, 0)), Color=CS(WHITE),
           LightEmission=0.45, ZOffset=0.8),
    ]
    inst = [carrier("Floor", (0, 0.12, 0, 0, 0, 0), [att("A", children=g)]), carrier("Press", (0, 2.6, 0, 0, 0, 0), press, size=(4.5, 0.2, 2.2)),
            carrier("Rim", (0, 0.25, 0, 0, 0, 0), rim, size=(3.6, 0.3, 3.6))]
    for t, n, when in (("Floor.A.Ring", 1, 0), ("Floor.A.Plates", 1, 0), ("Floor.A.Dashed", 1, 0.05), ("Press.Press", 9, 0), ("Rim.Dust", 5, 0),
                       ("Rim.Motes", 8, 0)):
        tl.at(when, do="emit", target=t, count=n)
    effect("Gravity_Pulse", "A push-up lands under heavy gravity: the floor rings.", 0.7, inst, tl, [0.0, 0.03, 0.07, 0.12, 0.2, 0.35], GRAV,
           "floor ring + falling pressure lines", origin=(0, 0, 0), dummy=False, cam=((9, 1.8, 3), (0, 1.2, 0)),
           beats=["the weight lands on the floor"])


def gravity_flip():
    """(tint) Gravity turns over: everything on the floor is flung UP. Origin = the floor."""
    tl = TL()
    g = [
        ring("Shock", "sprites/rings/ring_spiked_cel_02", 5, 20, CS(WHITE), life=0.45, le=0.3, attrs=TINT),
        ring("Ring", "sprites/rings/ring_cel_08", 4, 15, CS(WHITE), life=0.55, le=0.3, attrs=TINT),
        ring("Plates", HEXES, 12, 14, CS(WHITE), life=0.6, le=0.3, attrs=TINT, Transparency=NS((0, 0.2), (0.5, 0.4), (1, 1))),
    ]
    up = [
        pe("Lift", attrs=TINT, Texture=tex("tfa/speed_line"), Shape=BOX, EmissionDirection=TOP, SpreadAngle=V2(3, 3),
           Speed=NR(26, 44), Drag=1.5, Lifetime=NR(0.3, 0.5), Size=NS((0, 2.2), (1, 0.6)), Color=CS(WHITE), LightEmission=0.4, ZOffset=1,
           **STREAK),
        pe("Chips", Texture=tex(ROCK), Shape=BOX, EmissionDirection=TOP, SpreadAngle=V2(12, 12), Speed=NR(9, 16), Drag=2.2,
           Lifetime=NR(0.9, 1.3), Rotation=NR(0, 360), RotSpeed=NR(-200, 200), Size=NS((0, 0.7), (0.8, 0.6), (1, 0)),
           Color=CS((0, WHITE), (1, hexc("B8B4CC"))), LightEmission=0, ZOffset=0.6),
        pe("Dust", Texture=tex("flipbooks/smoke/smoke_puff_fb_cel_03_4x4"), **fb(0.7), Shape=BOX, EmissionDirection=TOP, SpreadAngle=V2(20, 20),
           Speed=NR(6, 11), Drag=2.5, Lifetime=NR(0.6, 0.8), Rotation=NR(0, 360), Size=NS((0, 1.8), (1, 3.4)),
           Transparency=NS((0, 0.4), (0.6, 0.55), (1, 1)), Color=CS((0, WHITE), (1, hexc("CFC8E6"))), LightEmission=0, ZOffset=0.3),
    ]
    hit = [
        pe("Lines", attrs=TINT, Texture=tex("sprites/impacts/speed_lines_cel_02"), Lifetime=NR(0.25), Speed=NR(0), Rotation=NR(0, 360),
           Size=NS((0, 9), (1, 15)), Transparency=NS((0, 0.15), (0.5, 0.35), (1, 1)), Color=CS(WHITE), LightEmission=0.3, ZOffset=1.5),
    ]
    inst = [carrier("Ground", (0, 0.12, 0, 0, 0, 0), [att("A", children=g)]), carrier("Up", (0, 0.3, 0, 0, 0, 0), up, size=(10, 0.3, 10)),
            carrier("Hit", (0, 3, 0, 0, 0, 0), [att("A", children=hit)]), light("Lamp", (0, 3, 0, 0, 0, 0), GRAV, 18)]
    for t, n, when in (("Ground.A.Shock", 1, 0), ("Ground.A.Plates", 1, 0), ("Ground.A.Ring", 1, 0.06), ("Up.Lift", 26, 0), ("Up.Chips", 14, 0),
                       ("Up.Dust", 8, 0), ("Hit.A.Lines", 1, 0), ("Up.Lift", 14, 0.12)):
        tl.at(when, do="emit", target=t, count=n)
    tl.at(0, do="set", target="Lamp.L", prop="Brightness", value=0.5)
    tl.at(0.02, do="tween", target="Lamp.L", prop="Brightness", to=0, time=0.5, style="Quad", dir="Out")
    effect("Gravity_Flip", "Gravity turns over: everything on the floor is flung up.", 1.3, inst, tl, [0.0, 0.04, 0.1, 0.2, 0.35, 0.55, 0.8],
           GRAV, "everything flung upward", origin=(0, 0, 0), shake=0.4, cam=((11, 2.6, 6), (0, 3.6, 0)), beats=["the floor lets go"])


def gravity_float():
    """(loop, tint) While gravity is turned over: dust, grit and light drift UP off the whole deck. Rides
    on the floor spot."""
    deck = [
        pe("Motes", attrs=TINT, Texture=tex("sprites/specks/dot_cel_00"), Shape=BOX, EmissionDirection=TOP, SpreadAngle=V2(6, 6), Rate=16,
           Speed=NR(2, 4.5), Lifetime=NR(1.6, 2.4), Size=NS((0, 0), (0.15, 0.45), (0.8, 0.35), (1, 0)), Color=CS(WHITE), LightEmission=0.45,
           ZOffset=0.8),
        pe("Grit", Texture=tex(ROCK), Shape=BOX, EmissionDirection=TOP, SpreadAngle=V2(8, 8), Rate=5, Speed=NR(1.2, 2.6), Lifetime=NR(2.0, 2.8),
           Rotation=NR(0, 360), RotSpeed=NR(-60, 60), Size=NS((0, 0), (0.12, 0.6), (0.85, 0.5), (1, 0)),
           Color=CS((0, WHITE), (1, hexc("B8B4CC"))), LightEmission=0, ZOffset=0.5),
        pe("Lift", attrs=TINT, Texture=tex("tfa/speed_line"), Shape=BOX, EmissionDirection=TOP, SpreadAngle=V2(0, 0), Rate=7,
           Speed=NR(10, 16), Lifetime=NR(0.5, 0.8), Size=NS((0, 0), (0.2, 1.3), (1, 0.3)), Transparency=NS((0, 0.35), (1, 0.7)),
           Color=CS(WHITE), LightEmission=0.4, ZOffset=0.6, **STREAK),
    ]
    floor = [pe("Dashed", attrs=TINT, Texture=tex("sprites/rings/ring_dashed_cel_02"), **FLAT, Rate=0.9, Lifetime=NR(1.3), Rotation=NR(0, 360),
                RotSpeed=NR(25, 25), Size=NS((0, 5), (1, 13)), Transparency=NS((0, 0.45), (0.6, 0.6), (1, 1)), Color=CS(WHITE), LightEmission=0.3,
                ZOffset=0.25)]
    inst = [carrier("Deck", (0, 0.3, 0, 0, 0, 0), deck, size=(11, 0.3, 11)), carrier("Floor", (0, 0.14, 0, 0, 0, 0), [att("A", children=floor)])]
    effect("Gravity_Float", "Gravity is turned over: dust and light drift up off the deck (loop).", 2.4, inst, TL(), [0.5, 1.0, 1.5, 2.0], GRAV,
           "everything drifts upward", loop=True, attach="part", origin=(0, 0, 0), cam=((11, 2.6, 6), (0, 3.6, 0)),
           beats=["motes and grit rise and never fall"])


def gravity_slam():
    """(tint) Gravity comes back: everything slams into the floor. Origin = the floor."""
    tl = TL()
    dust = hexc("CFC8E6")
    g = [
        ring("Shock", "sprites/rings/ring_spiked_cel_02", 6, 22, CS(WHITE), life=0.4, le=0.3, attrs=TINT),
        ring("Ring", "sprites/rings/ring_cel_08", 5, 17, CS((0, WHITE), (1, dust)), life=0.5, le=0.15),
        ring("Plates", HEXES, 13, 15, CS(WHITE), life=0.5, le=0.3, attrs=TINT, Transparency=NS((0, 0.15), (0.5, 0.4), (1, 1))),
        ring("Crack", "sprites/cracks/crack_cel_02", 12, 13, CS(hexc("2C2838")), life=1.2, le=0, Rotation=NR(0, 360),
             Transparency=NS((0, 0), (0.7, 0.1), (1, 1))),
    ]
    down = [
        pe("Press", attrs=TINT, Texture=tex("tfa/speed_line"), Shape=BOX, EmissionDirection=BOTTOM, SpreadAngle=V2(0, 0),
           Speed=NR(46, 60), Lifetime=NR(0.1, 0.13), Size=NS((0, 2.6), (1, 0.8)), Color=CS(WHITE), LightEmission=0.4, ZOffset=1, **STREAK),
    ]
    rim = [
        pe("Dust", Texture=tex("flipbooks/smoke/smoke_puff_fb_cel_03_4x4"), **fb(0.65), Shape=E("ParticleEmitterShape.Cylinder"),
           ShapeStyle=E("ParticleEmitterShapeStyle.Surface"), EmissionDirection=TOP, SpreadAngle=V2(80, 80), Speed=NR(9, 15), Drag=4,
           Lifetime=NR(0.55, 0.7), Rotation=NR(0, 360), Size=NS((0, 2.4), (0.3, 4.2), (1, 5.0)), Transparency=FADE,
           Color=CS((0, WHITE), (1, dust)), LightEmission=0, ZOffset=0.3),
        pe("Chips", Texture=tex(ROCK), Shape=E("ParticleEmitterShape.Cylinder"), EmissionDirection=TOP, SpreadAngle=V2(45, 45),
           Speed=NR(16, 28), Acceleration=V3(0, -70, 0), Lifetime=NR(0.45, 0.7), Rotation=NR(0, 360), RotSpeed=NR(-400, 400),
           Size=NS((0, 0.9), (0.8, 0.8), (1, 0)), Color=CS((0, WHITE), (1, hexc("B8B4CC"))), LightEmission=0, ZOffset=0.6),
    ]
    inst = [carrier("Ground", (0, 0.12, 0, 0, 0, 0), [att("A", children=g)]), carrier("Down", (0, 7, 0, 0, 0, 0), down, size=(10, 0.3, 10)),
            carrier("Rim", (0, 0.3, 0, 0, 0, 0), rim, size=(7, 0.4, 7)), light("Lamp", (0, 2, 0, 0, 0, 0), GRAV, 18)]
    for t, n, when in (("Down.Press", 26, 0), ("Ground.A.Shock", 1, 0.02), ("Ground.A.Plates", 1, 0.02), ("Ground.A.Crack", 1, 0.02),
                       ("Rim.Dust", 16, 0.02), ("Rim.Chips", 16, 0.02), ("Ground.A.Ring", 1, 0.08), ("Rim.Dust", 6, 0.14)):
        tl.at(when, do="emit", target=t, count=n)
    tl.at(0, do="set", target="Lamp.L", prop="Brightness", value=0.5)
    tl.at(0.02, do="tween", target="Lamp.L", prop="Brightness", to=0, time=0.45, style="Quad", dir="Out")
    effect("Gravity_Slam", "Gravity comes back: everything slams into the floor.", 1.4, inst, tl, [0.0, 0.04, 0.1, 0.2, 0.35, 0.55, 0.8], GRAV,
           "slam: shock ring + dust wall", origin=(0, 0, 0), shake=0.6, dummy=False, cam=((11, 2.6, 6), (0, 2.4, 0)),
           beats=["the whole deck is driven into the floor"])


# ------------------------------------------------------------------------------------ Spirit Orb (phase E, pair 2)
# Seen from the front, the orb over the hero's raised hands. Camera-facing shapes round the orb.
SPIRIT = hexc("6CF5B0")


def orb_release():
    """(tint) The charge is let go: a pulse leaves the orb. Origin = the orb's centre."""
    tl = TL()
    a = [
        pop("sprites/impacts/starburst_cel_00", size=4.2, color=CS(WHITE), life=0.1, attrs=TINT, LightEmission=0.3),
        pe("Ring", attrs=TINT, Texture=tex("sprites/rings/ring_cel_04"), Lifetime=NR(0.36), Speed=NR(0), Size=NS((0, 2), (0.3, 7.5), (1, 9.5)),
           Transparency=NS((0, 0), (0.5, 0.15), (1, 1)), Color=CS(WHITE), LightEmission=0.3, ZOffset=0.5),
        pe("Soft", attrs=TINT, Texture=tex("sprites/rings/ring_glow_02"), Lifetime=NR(0.3), Speed=NR(0), Size=NS((0, 1.5), (1, 7)),
           Transparency=NS((0, 0.3), (1, 1)), Color=CS(WHITE), LightEmission=0.5, ZOffset=0.3),
        pe("Sparks", attrs=TINT, Texture=tex("sprites/stars/star_cel_01"), SpreadAngle=V2(180, 180), Speed=NR(10, 18), Drag=3.5,
           Lifetime=NR(0.35, 0.55), Rotation=NR(0, 360), RotSpeed=NR(-300, 300), Size=NS((0, 0.9), (0.6, 0.7), (1, 0)), Color=CS(WHITE),
           LightEmission=0.4, ZOffset=1),
        pe("Rays", attrs=TINT, Texture=tex("sprites/specks/streak_cel_00"), SpreadAngle=V2(180, 180), Speed=NR(20, 30), Drag=5,
           Lifetime=NR(0.16, 0.26), Size=NS((0, 1.4), (1, 0.4)), Color=CS(WHITE), LightEmission=0.45, ZOffset=1, **STREAK),
    ]
    inst = [carrier("Orb", (0, 8, 0, 0, 0, 0), [att("A", children=a)])]
    for t, n, when in (("Pop", 1, 0), ("Ring", 1, 0), ("Soft", 1, 0), ("Sparks", 8, 0), ("Rays", 10, 0)):
        tl.at(when, do="emit", target=f"Orb.A.{t}", count=n)
    effect("Orb_Release", "The charge is let go: a pulse leaves the orb.", 0.7, inst, tl, [0.0, 0.03, 0.07, 0.12, 0.2, 0.35], SPIRIT,
           "pulse ring from the orb", origin=(0, 8, 0), cam=((1.5, 2.4, 13), (0, 5.2, 0)), beats=["a ring of light leaves the orb"])


def orb_burst():
    """(tint) The thrown orb bursts high over the court. Origin = the burst, seen from 50 studs below."""
    tl = TL()
    a = [
        pop("sprites/impacts/starburst_cel_00", size=30, color=CS((0, hexc("FFF1A8")), (1, WHITE)), life=0.16, attrs=TINT, LightEmission=0.2),
        pe("Lines", attrs=TINT, Texture=tex("sprites/impacts/speed_lines_cel_02"), Lifetime=NR(0.3), Speed=NR(0), Rotation=NR(0, 360),
           Size=NS((0, 26), (1, 46)), Transparency=NS((0, 0.1), (0.5, 0.3), (1, 1)), Color=CS(WHITE), LightEmission=0.3, ZOffset=1.5),
        pe("Ring", attrs=TINT, Texture=tex("sprites/rings/ring_cel_08"), Lifetime=NR(0.55), Speed=NR(0), Size=NS((0, 8), (0.3, 36), (1, 46)),
           Transparency=NS((0, 0), (0.5, 0.15), (1, 1)), Color=CS(WHITE), LightEmission=0.3, ZOffset=0.5),
        pe("Spiked", attrs=TINT, Texture=tex("sprites/rings/ring_spiked_cel_02"), Lifetime=NR(0.4), Speed=NR(0), Rotation=NR(0, 360),
           Size=NS((0, 8), (0.3, 30), (1, 38)), Transparency=NS((0, 0), (0.5, 0.1), (1, 1)), Color=CS(WHITE), LightEmission=0.3, ZOffset=0.8),
        # the orb's light comes down as glitter
        pe("Glitter", attrs=TINT, Texture=tex("sprites/stars/star_cel_01"), SpreadAngle=V2(180, 180), Speed=NR(30, 62), Drag=2.6,
           Acceleration=V3(0, -14, 0), Lifetime=NR(1.1, 1.8), Rotation=NR(0, 360), RotSpeed=NR(-250, 250),
           Size=NS((0, 3.2), (0.6, 2.4), (1, 0)), Color=CS(WHITE), LightEmission=0.4, ZOffset=1),
        pe("Rays", attrs=TINT, Texture=tex("sprites/specks/streak_cel_00"), SpreadAngle=V2(180, 180), Speed=NR(70, 110), Drag=3.5,
           Lifetime=NR(0.3, 0.5), Size=NS((0, 5), (1, 1.4)), Color=CS(WHITE), LightEmission=0.45, ZOffset=1, **STREAK),
        pe("Motes", attrs=TINT, Texture=tex("sprites/specks/dot_cel_00"), SpreadAngle=V2(180, 180), Speed=NR(14, 34), Drag=2,
           Acceleration=V3(0, -8, 0), Lifetime=NR(1.4, 2.2), Size=NS((0, 1.4), (0.7, 1.0), (1, 0)), Color=CS(WHITE), LightEmission=0.45,
           ZOffset=0.6),
    ]
    inst = [carrier("Sky", (0, 50, 0, 0, 0, 0), [att("A", children=a)])]
    for t, n, when in (("Pop", 1, 0), ("Lines", 1, 0), ("Ring", 1, 0), ("Spiked", 1, 0), ("Glitter", 34, 0), ("Rays", 30, 0), ("Motes", 30, 0),
                       ("Ring", 1, 0.14), ("Glitter", 14, 0.14)):
        tl.at(when, do="emit", target=f"Sky.A.{t}", count=n)
    effect("Orb_Burst", "The thrown orb bursts high over the court: rings, rays and falling glitter.", 2.2, inst, tl,
           [0.0, 0.04, 0.1, 0.2, 0.4, 0.7, 1.1, 1.6], SPIRIT, "sky burst", origin=(0, 50, 0), shake=0.5, dummy=True,
           cam=((2, 1.5, 24), (0, 20, 0)), beats=["the sky lights up over the court"])


EFFECTS = {"hit": train_hit, "crit": train_crit, "flurry": train_flurry, "pulse": train_pulse, "awaken": train_awaken, "aura": train_aura,
           "post_burst": post_burst, "post_rise": post_rise, "falls_ascend": falls_ascend, "falls_crash": falls_crash,
           "boulder_hit": boulder_hit, "boulder_barrage": boulder_barrage, "boulder_shatter": boulder_shatter, "boulder_land": boulder_land,
           "peak_strike": peak_strike, "peak_catch": peak_catch, "peak_storm": peak_storm, "peak_finale": peak_finale,
           "gravity_pulse": gravity_pulse, "gravity_flip": gravity_flip, "gravity_float": gravity_float, "gravity_slam": gravity_slam,
           "orb_release": orb_release, "orb_burst": orb_burst}

if __name__ == "__main__":
    _ = (FB4, mix, rise)
    for key in sys.argv[1:] or list(EFFECTS):
        EFFECTS[key]()
