"""Mutation auras: Aura_Golden, Aura_Flame, Aura_Lightning, Aura_Galaxy, Aura_Titan.

BRIEF (v2, after the in-engine review: v1 read as a thin ring + a few particles at 30 studs)
  A hero on a pedestal wears its mutation and must read at 60 studs as "this hero is special"
  (the genre's strong glow round a mutated pet) without hiding the face.
  Every aura = three parts, sized for a 5-stud hero (pass opts.scale for others):
    GROUND  a bright filled glow disc (radius ~3.7, LightEmission 1) + a hard ring on it
            (radius ~3.9, LightEmission 1, near-opaque) that pulses: the LowKeep layer is the ring
    SHELL   the element rising round the body on a cylinder of radius 2.6 from the feet to the
            waist, lifted by Acceleration so it thins out by the chest and fades before head height
            (most density feet -> chest); lifetimes 0.6-1.0 s
    ACCENT  one extra element layer (wisps / embers / sparks / swirl motes)
  Budget: <= 60 particles alive each (measured in the sim, see manifest).
  Golden    gold stars + white-gold light motes + gold flame wisps, gold disc
  Flame     big cel flame tongues + embers + a hot inner glow, orange disc
  Lightning crackling bolts redrawn every 0.1 s on the shell + spark spits + cyan motes
  Galaxy    colour-cycling twinkles + swirl motes turning + violet vortex disc with a pink rim
  Titan     a wide ground ripple (radius 6-8 at scale 1) that clearly pulses twice a second,
            a hard ring pulse, a warm base disc, drifting gold dust
"""
from tfa_fx import CS, FB4LOOP, FLAT, NR, NS, TL, V3, WHITE, E, att, carrier, hexc, mix, pe, tex, write

FEET = -2.9
SHELL_R, SHELL_Y0, SHELL_Y1 = 2.6, FEET, -0.4
LIFT = V3(0, 3.2, 0)


def shell(kids, r=SHELL_R):
    h = SHELL_Y1 - SHELL_Y0
    return carrier("Shell", (0, (SHELL_Y0 + SHELL_Y1) / 2, 0, 0, 0, 0), kids, size=(r * 2, h, r * 2))


def spe(name, attrs=None, **p):
    """An emitter on the shell: cylinder surface, slow start, lifted by Acceleration."""
    base = dict(Shape=E("ParticleEmitterShape.Cylinder"), ShapeStyle=E("ParticleEmitterShapeStyle.Surface"),
                EmissionDirection=E("NormalId.Top"), Speed=NR(0.4, 1.4), Acceleration=LIFT)
    base.update(p)
    return pe(name, attrs=attrs, **base)


def ground(col, ring_tex, ring_col=None, disc_tr=0.35, ring_size=7.8, spin=50, extra=()):
    ring_col = ring_col or mix(col, WHITE, 0.25)
    kids = [
        pe("Disc", attrs={"Tint": True}, Texture=tex("sprites/shapes/orb_soft_00"), **FLAT, Rate=2.4, Lifetime=NR(0.9),
           Size=NS((0, 6.6), (0.4, 7.4), (1, 7.6)), Transparency=NS((0, 1), (0.25, disc_tr), (0.65, disc_tr + 0.1), (1, 1)),
           Color=CS(col), LightEmission=1, ZOffset=0.1),
        pe("Ring", attrs={"Tint": True, "LowKeep": True}, Texture=tex(ring_tex), **FLAT, Rate=2.2, Lifetime=NR(0.9),
           Rotation=NR(0, 360), RotSpeed=NR(spin), Size=NS((0, ring_size * 0.8), (0.25, ring_size), (1, ring_size * 1.08)),
           Transparency=NS((0, 1), (0.15, 0.02), (0.6, 0.08), (1, 1)), Color=CS((0, WHITE), (0.2, ring_col), (1, col)),
           LightEmission=1, ZOffset=0.2),
    ] + list(extra)
    return carrier("Ground", (0, FEET + 0.1, 0, 0, 0, 0), [att("A", children=kids)])


def halo(col, tr=0.4, size=9.0):
    """The genre's 'special pet' glow: a soft billboard behind the body (ZOffset pushes it 3 studs
    away from the camera, so the hero and its face stay in front of it)."""
    return carrier("Halo", (0, -0.4, 0, 0, 0, 0), [att("A", children=[
        pe("Glow", attrs={"Tint": True}, Texture=tex("sprites/shapes/orb_soft_00"), Rate=3, Speed=NR(0), Lifetime=NR(0.8),
           Size=NS((0, size * 0.85), (0.5, size), (1, size * 0.9)), Transparency=NS((0, 1), (0.3, tr), (0.7, tr + 0.05), (1, 1)),
           Color=CS(col), LightEmission=1, ZOffset=-3)])])


def aura(name, note, inst, dominant, beats, accent="#FFFFFF"):
    for it in inst:  # sim: the dummy's root is at y=3; carriers are authored relative to the root
        it["CFrame"][1] = round(it["CFrame"][1] + 3, 3)
    d = {"name": name, "note": note, "duration": 2.4,
         "camera": {"pos": [16, 9, 25], "at": [0, 2.5, 0]},       # ~30 studs, the player's view of the base
         "camera2": {"pos": [32, 16, 50], "at": [0, 2.5, 0]},     # ~60 studs
         "stage": {"ground": "light", "dummy": True}, "game": {"loop": True, "attach": "root", "screen": False, "origin": [0, 3, 0]},
         "brief": {"category": "aura_transform", "tier": "skill", "style": "stylised_game", "shape": "glow disc + rising element shell",
                   "dominant": dominant, "accent": accent, "signature_beats": beats,
                   "phases": [{"name": "sustain", "t0": 0, "t1": 2.4}]},
         "instances": inst, "timeline": TL()}
    return write(d, [0.6, 1.2, 1.8, 2.35])


def golden():
    gold, deep, pale = hexc("FFD23F"), hexc("F59E0B"), hexc("FFF3B0")
    inst = [
        ground(gold, "sprites/rings/ring_dashed_glow_04", disc_tr=0.3), halo(gold),
        shell([
            spe("Stars", attrs={"Tint": True}, Texture=tex("sprites/stars/star_cel_06"), Rate=26, Lifetime=NR(0.7, 0.95),
                Rotation=NR(0, 360), RotSpeed=NR(-160, 160), Size=NS((0, 0), (0.15, 2.0), (0.7, 1.6), (1, 0)),
                Transparency=NS((0, 0), (0.7, 0), (1, 1)), Color=CS((0, WHITE), (0.25, gold), (1, deep)), LightEmission=0.6),
            spe("Motes", attrs={"Tint": True}, Texture=tex("sprites/specks/dot_glow_00"), Rate=18, Lifetime=NR(0.6, 0.85),
                Size=NS((0, 0), (0.2, 0.8), (1, 0)), Color=CS((0, WHITE), (1, pale)), LightEmission=1),
            spe("Wisps", attrs={"Tint": True}, Texture=tex("sprites/elements/flame_glow_02"), Rate=10, Lifetime=NR(0.6, 0.8),
                Rotation=NR(-10, 10), Size=NS((0, 1.4), (0.3, 2.6), (1, 0.8)), Transparency=NS((0, 1), (0.2, 0.3), (1, 1)),
                Color=CS((0, pale), (1, deep)), LightEmission=0.8),
        ]),
    ]
    return aura("Aura_Golden", "Golden mutation: gold glow disc + ring, gold stars and light motes rising round the body.", inst, "#FFD23F", ["glow disc", "rising sparkle stars"])


def flame():
    hot, mid, dark = hexc("FFE36B"), hexc("FF7A1A"), hexc("D9341C")
    inst = [
        ground(mid, "sprites/rings/ring_spiked_cel_05", ring_col=hexc("FFB347"), disc_tr=0.3, spin=-40), halo(mid),
        shell([
            spe("Tongues", attrs={"Tint": True}, Texture=tex("flipbooks/fire/fire_loop_cel_01_4x4"), **FB4LOOP, FlipbookFramerate=NR(18),
                Rate=28, Lifetime=NR(0.55, 0.75), Rotation=NR(-8, 8), Size=NS((0, 1.8), (0.3, 3.0), (1, 1.0)),
                Transparency=NS((0, 0.4), (0.12, 0), (0.7, 0.1), (1, 1)), Color=CS((0, hot), (0.35, mid), (1, dark)), LightEmission=0.6),
            spe("Embers", Texture=tex("sprites/specks/ember_glow_00"), Rate=22, Speed=NR(1, 3), Lifetime=NR(0.7, 1.0),
                Size=NS((0, 0.6), (1, 0)), Color=CS((0, hot), (1, mid)), LightEmission=1),
        ]),
        carrier("Core", (0, FEET + 1.0, 0, 0, 0, 0), [att("A", children=[
            pe("Glow", attrs={"Tint": True}, Texture=tex("sprites/elements/flame_glow_02"), Rate=5, Speed=NR(0.5), EmissionDirection=E("NormalId.Top"),
               Lifetime=NR(0.7), Size=NS((0, 4), (0.4, 5.5), (1, 4.5)), Transparency=NS((0, 1), (0.3, 0.45), (1, 1)),
               Color=CS((0, hot), (1, mid)), LightEmission=0.8, ZOffset=-1)])]),
    ]
    return aura("Aura_Flame", "Flame mutation: orange glow disc + spiked ring, big cel flame tongues and embers round the legs.", inst, "#FF7A1A", ["flames lick up from the ring"], "#FFE36B")


def lightning():
    cyan, ice, deep = hexc("38D6FF"), hexc("E6FBFF"), hexc("1E90FF")
    inst = [
        ground(cyan, "sprites/rings/ring_spiked_glow_02", ring_col=ice, disc_tr=0.35, spin=0), halo(cyan),
        shell([
            spe("Bolts", attrs={"Tint": True}, Texture=tex("sprites/elements/bolt_glow_03"), Rate=40, Speed=NR(0.01), Acceleration=V3(0, 0, 0),
                Lifetime=NR(0.08, 0.13), Rotation=NR(-50, 50), Size=NS((0, 2.6), (1, 3.0)), Color=CS((0, ice), (1, cyan)),
                LightEmission=1, Brightness=1.5, ZOffset=0.5),
            spe("Sparks", attrs={"Tint": True}, Texture=tex("sprites/specks/streak_glow_00"), Orientation=E("ParticleOrientation.VelocityParallel"),
                SpreadAngle={"Vector2": [180, 180]}, Rate=34, Speed=NR(8, 14), Drag=4, Acceleration=V3(0, 0, 0), Lifetime=NR(0.15, 0.25),
                Size=NS((0, 0.7), (1, 0)), Color=CS((0, WHITE), (1, cyan)), LightEmission=1),
            spe("Motes", attrs={"Tint": True}, Texture=tex("sprites/specks/dot_glow_00"), Rate=24, Lifetime=NR(0.6, 0.85),
                Size=NS((0, 0), (0.2, 0.7), (1, 0)), Color=CS((0, ice), (1, deep)), LightEmission=1),
        ]),
    ]
    return aura("Aura_Lightning", "Lightning mutation: cyan glow disc + crackle ring, bolts redrawn round the body, sparks, motes.", inst, "#38D6FF", ["bolts redrawn every 0.1 s"])


def galaxy():
    vio, pink, cyan = hexc("7C3AED"), hexc("F472B6"), hexc("67E8F9")
    cyc = [(round(i / 12, 4), [pink, cyan, mix(vio, WHITE, 0.45)][i % 3]) for i in range(13)]
    inst = [
        ground(vio, "sprites/rings/ring_glow_05", ring_col=pink, disc_tr=0.25, spin=0, extra=[
            pe("Vortex", attrs={"Tint": True}, Texture=tex("sprites/swirls/vortex_glow_01"), **FLAT, Rate=1.6, Lifetime=NR(1.0), Rotation=NR(0, 360),
               RotSpeed=NR(-120), Size=NS((0, 6.4), (1, 7.2)), Transparency=NS((0, 1), (0.2, 0.15), (0.8, 0.2), (1, 1)),
               Color=CS(mix(vio, pink, 0.3)), LightEmission=1, ZOffset=0.15)]), halo(mix(vio, pink, 0.35), tr=0.38),
        shell([
            spe("Twinkles", Texture=tex("sprites/stars/star_glow_04"), Rate=26, Lifetime=NR(0.75, 1.0), Rotation=NR(0, 90), RotSpeed=NR(-120, 120),
                Size=NS((0, 0), (0.2, 1.7), (0.7, 1.3), (1, 0)), Color=CS(*cyc), LightEmission=1),
            spe("Swirls", attrs={"Tint": True}, Texture=tex("sprites/swirls/swirl_glow_03"), Rate=9, Lifetime=NR(0.7, 0.9), Rotation=NR(0, 360),
                RotSpeed=NR(-300), Size=NS((0, 0.8), (0.3, 1.8), (1, 1.2)), Transparency=NS((0, 1), (0.25, 0.2), (1, 1)),
                Color=CS((0, pink), (1, vio)), LightEmission=1),
            spe("Dust", Texture=tex("sprites/specks/dot_glow_00"), Rate=16, Lifetime=NR(0.6, 0.9), Size=NS((0, 0.4), (1, 0)),
                Color=CS((0, WHITE), (1, cyan)), LightEmission=1),
        ]),
    ]
    return aura("Aura_Galaxy", "Galaxy mutation: violet vortex disc + pink ring, colour-cycling twinkles and swirl motes rising.", inst, "#7C3AED", ["vortex disc", "colour-cycling twinkles"], "#F472B6")


def titan():
    sand, warm, gold = hexc("FDE68A"), hexc("F59E0B"), hexc("FFD23F")
    g = [
        pe("Ripple", attrs={"Tint": True, "LowKeep": True}, Texture=tex("sprites/rings/ripple_glow_03"), **FLAT, Rate=2, Lifetime=NR(1.0),
           Size=NS((0, 7), (0.5, 13), (1, 16)), Transparency=NS((0, 1), (0.1, 0.05), (0.6, 0.25), (1, 1)), Color=CS((0, WHITE), (0.3, sand), (1, warm)),
           LightEmission=1, ZOffset=0.2),
        pe("Pulse", attrs={"Tint": True}, Texture=tex("sprites/rings/ring_cel_08"), **FLAT, Rate=1, Lifetime=NR(0.7),
           Size=NS((0, 6), (0.3, 12), (1, 14)), Transparency=NS((0, 0), (0.6, 0.15), (1, 1)), Color=CS((0, WHITE), (1, gold)),
           LightEmission=1, ZOffset=0.25),
        pe("Base", attrs={"Tint": True}, Texture=tex("sprites/shapes/orb_soft_00"), **FLAT, Rate=1.4, Lifetime=NR(1.0), Size=NS((0, 11), (1, 12)),
           Transparency=NS((0, 1), (0.3, 0.45), (0.7, 0.5), (1, 1)), Color=CS(warm), LightEmission=1, ZOffset=0.1),
    ]
    inst = [
        carrier("Ground", (0, FEET + 0.1, 0, 0, 0, 0), [att("A", children=g)]),
        shell([
            spe("Dust", attrs={"Tint": True}, Texture=tex("sprites/specks/dot_glow_00"), Rate=20, Lifetime=NR(0.7, 1.0),
                Size=NS((0, 0), (0.3, 0.8), (1, 0)), Color=CS((0, WHITE), (1, gold)), LightEmission=1),
        ], r=5.0),
    ]
    return aura("Aura_Titan", "Titan: wide gold ground ripple (radius 6-8 at scale 1) pulsing twice a second, ring pulse, dust.", inst, "#FDE68A", ["ground ripple pulse"])


if __name__ == "__main__":
    golden()
    flame()
    lightning()
    galaxy()
    titan()
