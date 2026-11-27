"""Home + big-moment effects (stylised_game, kid-friendly, saturated, no screen effects except Rebirth).

BRIEFS
  DashHome_Trail  hero runs home: speed-streak ribbon the height of the body + dust puffs kicked at
                  the feet + white speed streaks. Loop until stop; attach = root.
  Train_Hit       punchy comic star at the dummy: 1-frame cel burst, cross glint, star spray, ring.
  PowerUp_Burst   new power rank: upward chevrons rise round the player (the arrow carries the
                  meaning), ring at the feet, upward spark streaks, a short pop of light.
  Coin_Pop        four yen coins (a spinning-coin flipbook rendered from a real coin) pop up and fall,
                  one glint. Frequent and tiny: 5 particles.
  Slot_Unlock     a pedestal unlocks: flat gold rings rise off it like a stack, sparkles, star pop.
  Rebirth_Nova    the rarest personal moment: white star flash, huge cel shock flipbook + spiked ring
                  racing out, rays, rising rainbow sparkles, screen-edge flash + light shake (local only).
  Summon_Portal   magic circle (spinning sigil flipbook + counter-turning rune ring) scales in on the
                  ground, a light column rises from it, motes climb, a star pop opens it at the end.
  ServerLuck_Sky  high over the hub: two waving aurora ribbons (green -> cyan -> violet) + slow
                  drifting clover sparkles. Loop, one instance, cheap for 15 minutes.
  Zone_Unlock     a sparkle sweep left to right across a zone gate: seven staggered star columns and
                  a ribbon flash across the gate top (tint = the zone colour).
"""
from tfa_fx import (CS, FB4, FB4LOOP, FLAT, NR, NS, STREAK, TL, V2, V3, WHITE, E, att, beam, carrier, hexc, hsv, light,
                    mix, pe, tex, trail, write)

GOLD = hexc("FFD23F")
ORANGE = hexc("FF9A3D")
RAINBOW3 = [(round(i / 18, 4), hsv(i / 6, 0.65, 1.0)) for i in range(19)]


def brief(cat, tier, shape, dom, acc, beats, phases):
    return {"category": cat, "tier": tier, "style": "stylised_game", "shape": shape, "dominant": dom, "accent": acc,
            "signature_beats": beats, "phases": phases}


def ph(rel, sus, res):
    return [{"name": "release", "t0": rel, "t1": rel + 1 / 60}, {"name": "sustain", "t0": rel + 1 / 60, "t1": sus}, {"name": "residue", "t0": sus, "t1": res}]


def dash_home():
    tl = TL()
    kids = [att("Hi", (0, 2.2, 0)), att("Lo", (0, -1.6, 0)),
            trail("Streak", "Root.Hi", "Root.Lo", attrs={"Tint": True}, Texture=tex("beams/speed_streaks_cel_02"), TextureMode=E("TextureMode.Stretch"),
                  Lifetime=0.28, MinLength=0.05, WidthScale=NS((0, 1), (1, 0.7)), Color=CS(WHITE), Transparency=NS((0, 0.25), (1, 1)), LightEmission=0.3),
            att("A", children=[
                pe("Lines", attrs={"Tint": True}, Texture=tex("sprites/specks/streak_soft_00"), **STREAK, EmissionDirection=E("NormalId.Back"),
                   SpreadAngle=V2(12, 12), Rate=22, Speed=NR(10, 16), Lifetime=NR(0.18, 0.26), Size=NS((0, 1.2), (1, 0.4)),
                   Transparency=NS((0, 0.2), (1, 1)), Color=CS(WHITE), LightEmission=0.4)])]
    feet = [pe("Dust", Texture=tex("flipbooks/smoke/smoke_puff_fb_cel_03_4x4"), **FB4, FlipbookFramerate=NR(16 / 0.45), EmissionDirection=E("NormalId.Top"),
               SpreadAngle=V2(50, 50), Rate=14, Speed=NR(2, 4), Drag=3, Lifetime=NR(0.38, 0.48), Rotation=NR(0, 360), Size=NS((0, 1.4), (1, 2.6)),
               Transparency=NS((0, 0.1), (0.7, 0.2), (1, 1)), Color=CS((0, WHITE), (1, hexc("EADFC2"))), LightEmission=0)]
    inst = [carrier("Root", (0, 3, -24, 0, 0, 0), kids), carrier("Feet", (0, 0.4, -24, 0, 0, 0), [att("A", children=feet)])]
    for c in ("Root", "Feet"):
        y = 3 if c == "Root" else 0.4
        tl.at(0, do="path", target=c, points=[[0, y, -24], [0, y, 0], [0, y, 24]], time=1.0, style="Linear", sim=True)
    d = {"name": "DashHome_Trail", "note": "Hero dashes home (loop until stop).", "duration": 1.3, "camera": {"pos": [16, 6, 4], "at": [0, 2.5, 2]},
         "stage": {"ground": "light", "dummy": False}, "game": {"loop": True, "attach": "root", "screen": False, "origin": [0, 3, -24]},
         "brief": brief("dash_teleport", "basic", "speed streak ribbon + dust", "#FFFFFF", "#EADFC2", ["speed streaks"],
                        [{"name": "sustain", "t0": 0, "t1": 1.0}, {"name": "residue", "t0": 1.0, "t1": 1.3}]),
         "instances": inst, "timeline": tl}
    return write(d, [0.3, 0.42, 0.5, 0.58, 0.7, 1.05])


def train_hit():
    tl = TL()
    a = [pe("Burst", Texture=tex("sprites/impacts/comic_burst_cel_02"), Lifetime=NR(0.16), Speed=NR(0), Rotation=NR(0, 360),
            Size=NS((0, 4.2), (1, 5.2)), Transparency=NS((0, 0), (0.6, 0), (1, 1)), Color=CS((0, WHITE), (0.5, hexc("FFF07A")), (1, GOLD)), LightEmission=0.25, ZOffset=2),
         pe("Cross", Texture=tex("sprites/impacts/hit_cross_cel_00"), Lifetime=NR(0.1), Speed=NR(0), Rotation=NR(0, 90), Size=NS((0, 3), (1, 4.5)),
            Color=CS(WHITE), LightEmission=0.4, ZOffset=2.5),
         pe("Ring", Texture=tex("sprites/rings/ring_cel_04"), Lifetime=NR(0.22), Speed=NR(0), Size=NS((0, 2), (0.3, 4.4), (1, 5)),
            Transparency=NS((0, 0), (1, 1)), Color=CS((0, WHITE), (1, ORANGE)), LightEmission=0.3, ZOffset=1),
         pe("Stars", Texture=tex("sprites/stars/star_cel_01"), SpreadAngle=V2(180, 180), Speed=NR(12, 18), Drag=3, Acceleration=V3(0, -20, 0),
            Lifetime=NR(0.3, 0.45), Rotation=NR(0, 360), RotSpeed=NR(-300, 300), Size=NS((0, 1.1), (1, 0)), Color=CS((0, WHITE), (1, GOLD)), LightEmission=0.2, ZOffset=1.5)]
    inst = [carrier("Hit", (0, 3.2, 0, 0, 0, 0), [att("A", children=a)])]
    for t, n in (("Burst", 1), ("Cross", 1), ("Ring", 1), ("Stars", 6)):
        tl.at(0, do="emit", target=f"Hit.A.{t}", count=n)
    d = {"name": "Train_Hit", "note": "Training rep impact at the dummy.", "duration": 0.6, "camera": {"pos": [6, 4.5, 11], "at": [0, 3, 0]},
         "stage": {"ground": "light", "dummy": True}, "game": {"loop": False, "attach": "point", "screen": False, "origin": [0, 3.2, 0]},
         "brief": brief("impact", "basic", "comic star", "#FFD23F", "#FFFFFF", ["shape born at full size"], ph(0, 0.2, 0.5)),
         "instances": inst, "timeline": tl}
    return write(d, [0.0, 0.03, 0.07, 0.12, 0.2, 0.3, 0.45])


def powerup():
    tl = TL()
    inst = [
        carrier("Ground", (0, 0.15, 0, 0, 0, 0), [att("A", children=[
            pe("Ring", attrs={"Tint": True}, Texture=tex("sprites/rings/ring_glow_08"), **FLAT, Lifetime=NR(0.5), Size=NS((0, 4), (0.2, 9), (1, 10.5)),
               Transparency=NS((0, 0), (1, 1)), Color=CS((0, WHITE), (0.3, ORANGE)), LightEmission=0.55, ZOffset=0.2)])]),
        carrier("Column", (0, 0.4, 0, 0, 0, 0), size=(5, 0.2, 5), children=[
            pe("Chevrons", attrs={"Tint": True}, Texture=tex("sprites/shapes/chevron_glow_01"), Shape=E("ParticleEmitterShape.Disc"),
               ShapeStyle=E("ParticleEmitterShapeStyle.Surface"), EmissionDirection=E("NormalId.Top"), Rate=0, Speed=NR(9, 13), Drag=1.2,
               Lifetime=NR(0.6, 0.8), Rotation=NR(-90), Size=NS((0, 0.6), (0.15, 1.7), (0.7, 1.5), (1, 0)), Color=CS((0, WHITE), (0.3, GOLD), (1, ORANGE)), LightEmission=0.5),
            pe("Sparks", attrs={"Tint": True}, Texture=tex("sprites/specks/streak_glow_00"), **STREAK, Shape=E("ParticleEmitterShape.Disc"),
               EmissionDirection=E("NormalId.Top"), Speed=NR(18, 28), Drag=2, Lifetime=NR(0.35, 0.5), Size=NS((0, 0.7), (1, 0)), Color=CS((0, WHITE), (1, GOLD)), LightEmission=0.7)]),
        carrier("Core", (0, 2.6, 0, 0, 0, 0), [att("A", children=[
            pe("Pop", Texture=tex("sprites/stars/star_glow_00"), Lifetime=NR(0.14), Speed=NR(0), Size=NS((0, 4), (1, 6)), Transparency=NS((0, 0.1), (1, 1)),
               Color=CS((0, WHITE), (1, GOLD)), LightEmission=0.5, ZOffset=2)])]),
        light("Lamp", (0, 3, 0, 0, 0, 0), mix(GOLD, WHITE, 0.4), 14),
    ]
    tl.at(0, do="emit", target="Ground.A.Ring", count=1)
    tl.at(0, do="emit", target="Core.A.Pop", count=1)
    tl.at(0, do="emit", target="Column.Sparks", count=14)
    for i in range(4):
        tl.at(0.04 + i * 0.12, do="emit", target="Column.Chevrons", count=4)
    tl.at(0, do="set", target="Lamp.L", prop="Brightness", value=3)
    tl.at(0.03, do="tween", target="Lamp.L", prop="Brightness", to=0, time=0.5, style="Quad", dir="Out")
    d = {"name": "PowerUp_Burst", "note": "New power rank: chevrons rise.", "duration": 1.4, "camera": {"pos": [9, 6, 16], "at": [0, 4, 0]},
         "stage": {"ground": "light", "dummy": True}, "game": {"loop": False, "attach": "point", "screen": False},
         "brief": brief("ambient_pickup", "skill", "rising chevrons", "#FF9A3D", "#FFFFFF", ["arrows carry the meaning"], ph(0, 0.75, 1.4)),
         "instances": inst, "timeline": tl}
    return write(d, [0.0, 0.05, 0.15, 0.3, 0.5, 0.75, 1.0, 1.25])


def coin_pop():
    tl = TL()
    a = [pe("Coins", Texture=tex("tfa/coin_spin_4x4"), **FB4LOOP, FlipbookFramerate=NR(26, 34), FlipbookStartRandom=True, EmissionDirection=E("NormalId.Top"),
            SpreadAngle=V2(28, 28), Speed=NR(11, 15), Acceleration=V3(0, -38, 0), Lifetime=NR(0.6, 0.7), Size=NS((0, 0.6), (0.12, 1.25), (0.8, 1.2), (1, 0)),
            Color=CS(WHITE), LightEmission=0, LightInfluence=0, ZOffset=1),
         pe("Glint", Texture=tex("sprites/stars/star_glow_04"), Lifetime=NR(0.18), Speed=NR(0), Rotation=NR(0, 45), Size=NS((0, 0.5), (0.3, 1.8), (1, 0)),
            Color=CS((0, WHITE), (1, GOLD)), LightEmission=0.6, ZOffset=2)]
    inst = [carrier("Pop", (0, 1, 0, 0, 0, 0), [att("A", children=a)])]
    tl.at(0, do="emit", target="Pop.A.Coins", count=4)
    tl.at(0, do="emit", target="Pop.A.Glint", count=1)
    d = {"name": "Coin_Pop", "note": "Yen coins pop (frequent, tiny).", "duration": 0.8, "camera": {"pos": [5, 4, 10], "at": [0, 2.5, 0]},
         "stage": {"ground": "light", "dummy": False}, "game": {"loop": False, "attach": "point", "screen": False, "origin": [0, 1, 0]},
         "brief": brief("ambient_pickup", "basic", "spinning coins", "#FFCD28", "#FFFFFF", ["pop to max in one frame"], ph(0, 0.15, 0.7)),
         "instances": inst, "timeline": tl}
    return write(d, [0.0, 0.06, 0.15, 0.25, 0.35, 0.5, 0.65])


def slot_unlock():
    tl = TL()
    inst = [
        carrier("Base", (0, 0.2, 0, 0, 0, 0), [att("A", children=[
            pe("Rings", attrs={"Tint": True}, Texture=tex("sprites/rings/ring_cel_08"), Orientation=E("ParticleOrientation.VelocityPerpendicular"),
               EmissionDirection=E("NormalId.Top"), Speed=NR(7), Drag=1.5, Lifetime=NR(0.9), Size=NS((0, 3), (0.15, 5.2), (1, 3.6)),
               Transparency=NS((0, 0), (0.6, 0.1), (1, 1)), Color=CS((0, WHITE), (0.25, GOLD), (1, ORANGE)), LightEmission=0.45, ZOffset=0.5),
            pe("Flat", attrs={"Tint": True}, Texture=tex("sprites/rings/ring_glow_08"), **FLAT, Lifetime=NR(0.5), Size=NS((0, 4), (0.2, 8), (1, 9)),
               Transparency=NS((0, 0), (1, 1)), Color=CS(GOLD), LightEmission=0.55, ZOffset=0.2),
            pe("Pop", Texture=tex("sprites/stars/star_glow_00"), Lifetime=NR(0.14), Speed=NR(0), Size=NS((0, 3.5), (1, 5)), Transparency=NS((0, 0.1), (1, 1)),
               Color=CS((0, WHITE), (1, GOLD)), LightEmission=0.5, ZOffset=2)])]),
        carrier("Disc", (0, 0.3, 0, 0, 0, 0), size=(4.5, 0.2, 4.5), children=[
            pe("Sparkles", attrs={"Tint": True}, Texture=tex("sprites/stars/star_cel_06"), Shape=E("ParticleEmitterShape.Disc"),
               ShapeStyle=E("ParticleEmitterShapeStyle.Volume"), EmissionDirection=E("NormalId.Top"), Rate=30, Enabled=False, Speed=NR(6, 10), Drag=1,
               Lifetime=NR(0.5, 0.75), Rotation=NR(0, 360), RotSpeed=NR(-200, 200), Size=NS((0, 0), (0.2, 1.0), (1, 0)), Color=CS((0, WHITE), (1, GOLD)), LightEmission=0.4)]),
    ]
    tl.at(0, do="emit", target="Base.A.Pop", count=1)
    tl.at(0, do="emit", target="Base.A.Flat", count=1)
    for i in range(4):
        tl.at(i * 0.12, do="emit", target="Base.A.Rings", count=1)
    tl.at(0, do="enable", target="Disc.Sparkles", duration=0.6)
    d = {"name": "Slot_Unlock", "note": "Pedestal slot bought: rings rise off it.", "duration": 1.5, "camera": {"pos": [8, 6, 14], "at": [0, 3, 0]},
         "stage": {"ground": "light", "dummy": False}, "game": {"loop": False, "attach": "point", "screen": False},
         "brief": brief("ambient_pickup", "skill", "stacked rising rings", "#FFD23F", "#FFFFFF", ["stacked staggered circles"], ph(0, 0.85, 1.5)),
         "instances": inst, "timeline": tl}
    return write(d, [0.0, 0.08, 0.2, 0.35, 0.5, 0.7, 0.95, 1.2])


def rebirth_nova():
    tl = TL()
    mag = hexc("FF4FD8")
    g = [pe("Shock", attrs={"Tint": True}, Texture=tex("flipbooks/shockwaves/shockwave_cel_01_4x4"), **FB4, **FLAT, FlipbookFramerate=NR(16 / 0.6), Lifetime=NR(0.6),
            Size=NS((0, 14), (1, 34)), Color=CS((0, WHITE), (0.3, mix(mag, WHITE, 0.3)), (1, mag)), LightEmission=0.45, ZOffset=0.1),
         pe("Spiked", attrs={"Tint": True}, Texture=tex("sprites/rings/ring_spiked_cel_05"), **FLAT, Lifetime=NR(0.7), Rotation=NR(0, 360), RotSpeed=NR(80),
            Size=NS((0, 9), (0.15, 24), (1, 30)), Transparency=NS((0, 0), (0.6, 0.1), (1, 1)), Color=CS((0, WHITE), (0.2, GOLD), (1, ORANGE)), LightEmission=0.5, ZOffset=0.2)]
    core = [pe("Flash", Texture=tex("sprites/stars/star_glow_00"), Lifetime=NR(0.12), Speed=NR(0), Size=NS((0, 10), (1, 14)), Transparency=NS((0, 0), (1, 1)),
               Color=CS(WHITE), LightEmission=0.6, ZOffset=3),
            pe("Wall", attrs={"Tint": True}, Texture=tex("sprites/rings/ring_glow_08"), Lifetime=NR(0.5), Speed=NR(0), Size=NS((0, 6), (0.2, 22), (1, 28)),
               Transparency=NS((0, 0), (1, 1)), Color=CS(mag), LightEmission=0.55, ZOffset=1),
            pe("Rays", attrs={"Tint": True}, Texture=tex("sprites/elements/rays_glow_01"), Lifetime=NR(1.3), Speed=NR(0), Rotation=NR(0, 360), RotSpeed=NR(30),
               Size=NS((0, 8), (0.12, 20), (1, 24)), Transparency=NS((0, 0.2), (0.6, 0.4), (1, 1)), Color=CS(mix(GOLD, WHITE, 0.3)), LightEmission=0.45, ZOffset=-1)]
    inst = [carrier("Ground", (0, 0.15, 0, 0, 0, 0), [att("A", children=g)]),
            carrier("Core", (0, 3, 0, 0, 0, 0), [att("A", children=core)]),
            carrier("Disc", (0, 0.4, 0, 0, 0, 0), size=(14, 0.2, 14), children=[
                pe("Rise", Texture=tex("sprites/stars/star_glow_04"), Shape=E("ParticleEmitterShape.Disc"), EmissionDirection=E("NormalId.Top"), Rate=60, Enabled=False,
                   Speed=NR(8, 16), Drag=0.8, Lifetime=NR(0.7, 1.0), Rotation=NR(0, 90), Size=NS((0, 0), (0.2, 1.4), (1, 0)), Color=CS(*RAINBOW3), LightEmission=0.6)]),
            light("Lamp", (0, 4, 0, 0, 0, 0), mix(mag, WHITE, 0.5), 30)]
    for t in ("Ground.A.Shock", "Ground.A.Spiked", "Core.A.Flash", "Core.A.Wall", "Core.A.Rays"):
        tl.at(0.05, do="emit", target=t, count=1)
    tl.at(0.05, do="enable", target="Disc.Rise", duration=1.0)
    tl.at(0.05, do="set", target="Lamp.L", prop="Brightness", value=4)
    tl.at(0.07, do="tween", target="Lamp.L", prop="Brightness", to=0, time=0.8, style="Quad", dir="Out")
    tl.at(0.05, do="overlay", kind="lines", image=tex("tfa/edge_glow"), spin=False, scale=0.87, time=0.4, fin=0.03, fout=0.3, color=list(mix(mag, WHITE, 0.3)), transparency=0.3)
    tl.at(0.05, do="shake", amp=0.3, time=0.3, freq=24)
    d = {"name": "Rebirth_Nova", "note": "Rebirth: radial nova round the player.", "duration": 2.2, "camera": {"pos": [16, 12, 34], "at": [0, 4, 0]},
         "stage": {"ground": "light", "dummy": True}, "game": {"loop": False, "attach": "point", "screen": True},
         "brief": brief("explosion", "big skill", "radial nova", "#FF4FD8", "#FFD23F", ["shape born at full size", "screen-edge flash"], ph(0.05, 1.1, 2.2)),
         "instances": inst, "timeline": tl}
    return write(d, [0.0, 0.07, 0.12, 0.25, 0.45, 0.8, 1.2, 1.7])


def summon_portal():
    tl = TL()
    vio, cyan = hexc("A855F7"), hexc("67E8F9")
    g = [pe("Sigil", attrs={"Tint": True}, Texture=tex("flipbooks/magic/sigil_spin_glow_02_4x4"), **FB4LOOP, **FLAT, FlipbookFramerate=NR(10), Lifetime=NR(2.5),
            Rotation=NR(0), RotSpeed=NR(45), Size=NS((0, 4), (0.12, 14), (0.85, 14), (1, 15)), Transparency=NS((0, 0.1), (0.85, 0.1), (1, 1)),
            Color=CS((0, cyan), (0.5, mix(vio, WHITE, 0.3)), (1, vio)), LightEmission=0.5, ZOffset=0.2),
         pe("Runes", attrs={"Tint": True}, Texture=tex("sprites/sigils/rune_glow_02"), **FLAT, Lifetime=NR(2.45), Rotation=NR(0), RotSpeed=NR(-70),
            Size=NS((0, 6), (0.15, 18), (0.85, 18), (1, 19)), Transparency=NS((0, 0.2), (0.85, 0.25), (1, 1)), Color=CS(vio), LightEmission=0.45, ZOffset=0.15)]
    col = [att("Bot", (0, 0, 0, 0, 0, 90)), att("Top", (0, 16, 0, 0, 0, 90)),
           beam("Column", "Portal.Bot", "Portal.Top", attrs={"Tint": True}, Texture=tex("beams/laser_soft_04"), TextureMode=E("TextureMode.Stretch"),
                Width0=9, Width1=6, Color=CS((0, mix(cyan, WHITE, 0.4)), (1, vio)), LightEmission=0.5, Transparency=NS((0, 0.35), (0.6, 0.6), (1, 1)), Enabled=False),
           beam("Inner", "Portal.Bot", "Portal.Top", Texture=tex("beams/energy_glow_02"), TextureMode=E("TextureMode.Wrap"), TextureLength=6, TextureSpeed=-1.5,
                Width0=4, Width1=2.5, Color=CS(WHITE), LightEmission=0.6, Transparency=NS((0, 0.2), (0.7, 0.5), (1, 1)), Enabled=False)]
    inst = [carrier("Ground", (0, 0.15, 0, 0, 0, 0), [att("A", children=g)]),
            carrier("Portal", (0, 0.2, 0, 0, 0, 0), col),
            carrier("Disc", (0, 0.4, 0, 0, 0, 0), size=(10, 0.2, 10), children=[
                pe("Motes", attrs={"Tint": True}, Texture=tex("sprites/specks/dot_glow_00"), Shape=E("ParticleEmitterShape.Disc"), EmissionDirection=E("NormalId.Top"),
                   Rate=40, Enabled=False, Speed=NR(5, 10), Lifetime=NR(0.7, 1.0), Size=NS((0, 0), (0.2, 0.55), (1, 0)), Color=CS((0, WHITE), (1, cyan)), LightEmission=0.7)]),
            carrier("Open", (0, 3, 0, 0, 0, 0), [att("A", children=[
                pe("Pop", Texture=tex("sprites/stars/star_glow_00"), Lifetime=NR(0.14), Speed=NR(0), Size=NS((0, 6), (1, 9)), Transparency=NS((0, 0), (1, 1)),
                   Color=CS((0, WHITE), (1, cyan)), LightEmission=0.6, ZOffset=2),
                pe("Stars", attrs={"Tint": True}, Texture=tex("sprites/stars/star_cel_01"), SpreadAngle=V2(180, 180), Speed=NR(14, 22), Drag=2.5, Acceleration=V3(0, -12, 0),
                   Lifetime=NR(0.5, 0.75), Rotation=NR(0, 360), RotSpeed=NR(-250, 250), Size=NS((0, 1.6), (1, 0)), Color=CS((0, WHITE), (0.3, cyan), (1, vio)), LightEmission=0.4)])]),
            light("Lamp", (0, 3, 0, 0, 0, 0), mix(vio, WHITE, 0.4), 22)]
    tl.at(0, do="emit", target="Ground.A.Sigil", count=1)
    tl.at(0.1, do="emit", target="Ground.A.Runes", count=1)
    for b, w in (("Column", 9), ("Inner", 4)):
        tl.at(0.35, do="set", target=f"Portal.{b}", prop="Enabled", value=True)
        tl.at(0.35, do="tween", target=f"Portal.{b}", prop="Width0", **{"from": 0}, to=w, time=0.35, style="Quart", dir="Out")
        tl.at(2.05, do="tween", target=f"Portal.{b}", prop="Width0", to=0, time=0.35, style="Quad", dir="In")
        tl.at(2.05, do="tween", target=f"Portal.{b}", prop="Width1", to=0, time=0.3, style="Quad", dir="In")
        tl.at(2.42, do="set", target=f"Portal.{b}", prop="Enabled", value=False)
    tl.at(0.35, do="enable", target="Disc.Motes", duration=1.6)
    tl.at(0.35, do="tween", target="Lamp.L", prop="Brightness", to=2.2, time=0.4, style="Quad", dir="Out")
    tl.at(1.9, do="emit", target="Open.A.Pop", count=1)
    tl.at(1.9, do="emit", target="Open.A.Stars", count=18)
    tl.at(1.9, do="set", target="Lamp.L", prop="Brightness", value=3.5)
    tl.at(1.92, do="tween", target="Lamp.L", prop="Brightness", to=0, time=0.6, style="Quad", dir="Out")
    d = {"name": "Summon_Portal", "note": "Summon scroll: magic circle, light column, star pop at 1.9 s.", "duration": 2.8,
         "camera": {"pos": [14, 11, 26], "at": [0, 4, 0]}, "stage": {"ground": "light", "dummy": False},
         "game": {"loop": False, "attach": "point", "screen": False},
         "brief": brief("orb_charge", "big skill", "magic circle + light column", "#A855F7", "#67E8F9", ["stacked staggered circles", "star pop"],
                        [{"name": "anticipation", "t0": 0, "t1": 1.9}, {"name": "release", "t0": 1.9, "t1": 1.92}, {"name": "sustain", "t0": 1.92, "t1": 2.3}, {"name": "residue", "t0": 2.3, "t1": 2.8}]),
         "instances": inst, "timeline": tl}
    return write(d, [0.05, 0.2, 0.45, 0.9, 1.5, 1.92, 2.1, 2.5])


def server_luck():
    """v2 (review: read as a cyan halo ring): two soft green-and-gold aurora ARCS (not a loop) with
    low LightEmission so a blue sky cannot shift them to cyan, gold-rimmed clovers and gold twinkles."""
    green, lime, gold, deep = hexc("22C55E"), hexc("86EFAC"), hexc("FACC15"), hexc("15803D")
    band = [att("L1", (-60, 0, 0, 0, 0, 90)), att("R1", (60, 3, -6, 0, 0, 90)), att("L2", (-50, -8, 10, 0, 0, 90)), att("R2", (55, -6, 4, 0, 0, 90)),
            beam("Aurora1", "Sky.L1", "Sky.R1", attrs={"Tint": True, "LowKeep": True}, Texture=tex("tfa/aurora_band"), TextureMode=E("TextureMode.Wrap"),
                 TextureLength=40, TextureSpeed=0.12, Width0=20, Width1=24, CurveSize0=14, CurveSize1=14, Segments=40,
                 Color=CS((0, green), (0.35, lime), (0.55, gold), (0.8, green), (1, deep)), LightEmission=0.15,
                 Transparency=NS((0, 1), (0.15, 0.3), (0.85, 0.3), (1, 1))),
            beam("Aurora2", "Sky.L2", "Sky.R2", attrs={"Tint": True}, Texture=tex("tfa/aurora_band"), TextureMode=E("TextureMode.Wrap"),
                 TextureLength=32, TextureSpeed=-0.08, Width0=12, Width1=16, CurveSize0=-10, CurveSize1=-10, Segments=40,
                 Color=CS((0, gold), (0.4, green), (1, lime)), LightEmission=0.15, Transparency=NS((0, 1), (0.2, 0.45), (0.8, 0.45), (1, 1)))]
    inst = [carrier("Sky", (0, 60, 0, 0, 0, 0), band),
            carrier("Field", (0, 52, 0, 0, 0, 0), size=(110, 14, 50), children=[
                pe("Clovers", attrs={"Tint": True}, Texture=tex("tfa/clover_glow"), Shape=E("ParticleEmitterShape.Box"), Rate=8, Speed=NR(1, 2.5),
                   EmissionDirection=E("NormalId.Bottom"), Lifetime=NR(2.6, 3.4), Rotation=NR(0, 360), RotSpeed=NR(-40, 40),
                   Size=NS((0, 0), (0.15, 5.0), (0.85, 4.6), (1, 0)), Color=CS((0, lime), (1, green)), LightEmission=0.2),
                pe("Twinkle", Texture=tex("sprites/stars/star_glow_04"), Shape=E("ParticleEmitterShape.Box"), Rate=10, Speed=NR(0.5),
                   Lifetime=NR(0.6, 1.0), Rotation=NR(0, 90), Size=NS((0, 0), (0.3, 2.6), (1, 0)), Color=CS((0, hexc("FFF7C2")), (1, gold)), LightEmission=0.5)])]
    d = {"name": "ServerLuck_Sky", "note": "Server luck active: soft green-and-gold aurora arcs + drifting clovers over the hub (loop).", "duration": 4.0,
         "camera": {"pos": [0, 4, 70], "at": [0, 48, 0]}, "stage": {"ground": "light", "dummy": False},
         "game": {"loop": True, "attach": "point", "screen": False, "origin": [0, 60, 0]},
         "brief": brief("aura_transform", "skill", "aurora arcs + drifting clovers", "#22C55E", "#FACC15", ["aurora"], [{"name": "sustain", "t0": 0, "t1": 4}]),
         "instances": inst, "timeline": TL()}
    return write(d, [0.5, 1.5, 2.5, 3.5])


def zone_unlock():
    tl = TL()
    inst = [carrier("Gate", (0, 14, 0, 0, 0, 0), [att("L", (-26, 0, 0, 0, 0, 0)), att("R", (26, 0, 0, 0, 0, 0)),
                    beam("Ribbon", "Gate.L", "Gate.R", attrs={"Tint": True}, Texture=tex("beams/sparkle_trail_glow_02"), TextureMode=E("TextureMode.Wrap"),
                         TextureLength=14, TextureSpeed=2, Width0=3, Width1=3, Color=CS(WHITE), LightEmission=0.6, Transparency=NS((0, 0.1), (1, 0.1)), Enabled=False)])]
    for i in range(7):
        x = -24 + 8 * i
        inst.append(carrier(f"C{i}", (x, 0.3, 0, 0, 0, 0), size=(3, 0.2, 3), children=[
            pe("Column", attrs={"Tint": True}, Texture=tex("sprites/stars/star_cel_06"), Shape=E("ParticleEmitterShape.Disc"), EmissionDirection=E("NormalId.Top"),
               Speed=NR(16, 28), Drag=1.2, Lifetime=NR(0.55, 0.8), Rotation=NR(0, 360), RotSpeed=NR(-200, 200), Size=NS((0, 0), (0.15, 2.4), (1, 0)),
               Color=CS((0, WHITE), (0.4, mix(GOLD, WHITE, 0.3)), (1, GOLD)), LightEmission=0.4),
            pe("Pop", Texture=tex("sprites/stars/star_glow_00"), Lifetime=NR(0.14), Speed=NR(0), Size=NS((0, 3), (1, 5)), Transparency=NS((0, 0.1), (1, 1)),
               Color=CS(WHITE), LightEmission=0.5, ZOffset=1)]))
        tl.at(0.06 * i, do="emit", target=f"C{i}.Column", count=10)
        tl.at(0.06 * i, do="emit", target=f"C{i}.Pop", count=1)
    tl.at(0.0, do="set", target="Gate.Ribbon", prop="Enabled", value=True)
    tl.at(0.0, do="tween", target="Gate.Ribbon", prop="Width0", **{"from": 0}, to=3, time=0.36, style="Quad", dir="Out")
    tl.at(0.8, do="tween", target="Gate.Ribbon", prop="Width0", to=0, time=0.4, style="Quad", dir="In")
    tl.at(0.8, do="tween", target="Gate.Ribbon", prop="Width1", to=0, time=0.4, style="Quad", dir="In")
    tl.at(1.25, do="set", target="Gate.Ribbon", prop="Enabled", value=False)
    d = {"name": "Zone_Unlock", "note": "New zone: sparkle sweep across the gate (tint = zone colour).", "duration": 1.6,
         "camera": {"pos": [0, 10, 52], "at": [0, 7, 0]}, "stage": {"ground": "light", "dummy": False},
         "game": {"loop": False, "attach": "point", "screen": False},
         "brief": brief("ambient_pickup", "skill", "sweep of star columns", "#FFD23F", "#FFFFFF", ["sweep left to right"], ph(0, 1.0, 1.6)),
         "instances": inst, "timeline": tl}
    return write(d, [0.02, 0.12, 0.24, 0.4, 0.6, 0.9, 1.3])


if __name__ == "__main__":
    # (Train_Hit is built by build_train.py since plan 13 phase D; train_hit() above is the section 4 version, kept for reference)
    dash_home(); powerup(); coin_pop(); slot_unlock()
    rebirth_nova(); summon_portal(); server_luck(); zone_unlock()
