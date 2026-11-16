"""Reveal_<Rarity>: the catch reveal at the landing spot (one builder, seven parameter sets).

BRIEF
  Fantasy:      a pillar of festival light bursts out of the lane where the food landed, flicks up
                through the rarity colours like a slot machine and locks on the result; the hero
                appears inside it in a pop of chunky stars
  Tier:         skill (Common 1.0 s) .. big skill (Secret 2.4 s)
  Style:        stylised_game with anime_cel accents (hard cel stars and rings + soft glow halos)
  Category:     orb_charge -> impact (born big, settle fast; pop to max in 1 frame)
  Dominant:     the rarity colour     Accent: white core + a cool/warm complement
  Signature:    COLOUR CLIMB (the pillar steps through every lower rarity, 0.1 s a step, then locks:
                the moment kids film) + shape born at full size (ring at ~45 % radius, full by 0.15 s)
  Escalation:   Common pop -> Rare second ring -> Epic shock flipbook -> Legendary rays + tall beam
                -> Mythic edge flash + short shake -> Secret: black core pillar with gold rims and a
                rainbow ring/star storm, the only dark pillar in the game
  Timeline:     t0 ground ring + pillar pops | climb 0.1 s/step | LOCK = burst (flash, stars, ring 2)
                | sustain sparkles rise | pillar thins out | residue sparkles
"""
from tfa_fx import (CS, FB4, FLAT, NR, NS, ORDER, RARITY, STREAK, TL, V2, V3, WHITE, E, att, beam, carrier, hexc,
                    hsv, light, mix, pe, tex, write)

GOLD = hexc("FFD23F")
RAINBOW = [(i / 6, hsv(i / 6 * 0.83, 0.75, 1.0)) for i in range(7)]
RAINBOW3 = [(round(i / 18, 4), hsv(i / 6, 0.7, 1.0)) for i in range(19)]  # three hue cycles per life: ages differ, so hues differ

P = {  # H pillar height, W pillar width, R ring radius, stars, sparkle rate, extras
    "Common":    dict(dur=1.0, H=14, W=4.4, R=5,  stars=10, rate=14, ring2=False, shock=False, rays=False, edge=False, shake=0),
    "Uncommon":  dict(dur=1.2, H=18, W=5.0, R=6,  stars=14, rate=20, ring2=False, shock=False, rays=False, edge=False, shake=0),
    "Rare":      dict(dur=1.4, H=24, W=5.6, R=7,  stars=18, rate=26, ring2=True,  shock=False, rays=False, edge=False, shake=0),
    "Epic":      dict(dur=1.6, H=30, W=6.4, R=8,  stars=24, rate=32, ring2=True,  shock=True,  rays=False, edge=False, shake=0),
    "Legendary": dict(dur=1.9, H=40, W=7.4, R=9,  stars=30, rate=40, ring2=True,  shock=True,  rays=True,  edge=False, shake=0),
    "Mythic":    dict(dur=2.1, H=48, W=8.2, R=10, stars=34, rate=46, ring2=True,  shock=True,  rays=True,  edge=True,  shake=0.35),
    "Secret":    dict(dur=2.4, H=60, W=9.2, R=11, stars=40, rate=50, ring2=True,  shock=True,  rays=True,  edge=True,  shake=0.5),
}


def build(rar):
    p = P[rar]
    r = ORDER.index(rar)
    secret = rar == "Secret"
    col = GOLD if secret else hexc(RARITY[rar])
    light_col = mix(col, WHITE, 0.55)
    H, W, R = p["H"], p["W"], p["R"]
    LOCK = 0.06 + 0.1 * r  # the climb: one step per lower rarity
    T = p["dur"]
    tl = TL()

    # ---------------------------------------------------------- pillar (3 beams, one carrier)
    beams = [
        att("Bot", (0, 0, 0, 0, 0, 90)), att("Top", (0, H, 0, 0, 0, 90)),
        beam("Halo", "Pillar.Bot", "Pillar.Top", attrs={"Tint": True}, Texture=tex("beams/laser_soft_04"), TextureMode=E("TextureMode.Stretch"),
             Width0=W * 2.2, Width1=W * 1.6, Color=CS(col), LightEmission=0.5, Brightness=1,
             Transparency=NS((0, 0.3), (0.6, 0.5), (1, 1)), Enabled=False, ZOffset=-0.1),
        beam("Body", "Pillar.Bot", "Pillar.Top", attrs={"Tint": True}, Texture=tex("beams/energy_glow_02"), TextureMode=E("TextureMode.Wrap"),
             TextureLength=8, TextureSpeed=-2.2, Width0=W, Width1=W * 0.8, Color=CS(col), LightEmission=0.6, Brightness=1.4,
             Transparency=NS((0, 0.05), (0.7, 0.25), (1, 1)), Enabled=False, ZOffset=-0.05),
        beam("Core", "Pillar.Bot", "Pillar.Top", Texture=tex("beams/laser_soft_04" if secret else "beams/laser_glow_04"), TextureMode=E("TextureMode.Stretch"),
             Width0=W * (0.62 if secret else 0.42), Width1=W * (0.45 if secret else 0.3), Color=CS((0.06, 0.05, 0.04)) if secret else CS(WHITE),
             LightEmission=0 if secret else 0.8, Brightness=1 if secret else 2, Transparency=NS((0, 0), (0.75, 0.1), (1, 1)), Enabled=False, ZOffset=1 if secret else 0.1),
    ]
    if secret:  # gold rims either side of the black core
        beams.append(beam("Rim", "Pillar.Bot", "Pillar.Top", Texture=tex("beams/laser_glow_01"), TextureMode=E("TextureMode.Stretch"),
                          Width0=W * 0.7, Width1=W * 0.55, Color=CS(GOLD), LightEmission=0.7, Brightness=2,
                          Transparency=NS((0, 0), (0.8, 0.2), (1, 1)), Enabled=False, ZOffset=0.05))
    inst = [carrier("Pillar", (0, 0, 0, 0, 0, 0), beams)]
    pillar = [b["name"] for b in beams if b["class"] == "Beam"]

    # ---------------------------------------------------------- ground rings
    ground = [
        pe("Ring", attrs={"Tint": True}, Texture=tex("sprites/rings/ring_cel_02"), **FLAT, Lifetime=NR(0.55 + 0.05 * r),
           Size=NS((0, R * 0.9), (0.12, R * 1.9), (1, R * 2.1)), Transparency=NS((0, 0), (0.55, 0.05), (1, 1)),
           Color=CS((0, WHITE), (0.15, mix(col, WHITE, 0.3)), (1, col)), LightEmission=0.45, ZOffset=0.2),
        pe("Glow", attrs={"Tint": True}, Texture=tex("sprites/rings/ring_glow_08"), **FLAT, Lifetime=NR(0.4),
           Size=NS((0, R * 0.8), (0.2, R * 1.7), (1, R * 1.9)), Transparency=NS((0, 0.2), (1, 1)),
           Color=CS(col), LightEmission=0.7, ZOffset=0.1),
        pe("Ring2", attrs={"Tint": True}, Texture=tex("sprites/rings/ring_dashed_cel_02"), **FLAT, Lifetime=NR(0.7),
           Rotation=NR(0, 360), RotSpeed=NR(90),
           Size=NS((0, R * 1.2), (0.15, R * 2.6), (1, R * 3.0)), Transparency=NS((0, 0), (0.5, 0.1), (1, 1)),
           Color=CS((0, WHITE), (0.3, col)), LightEmission=0.5, ZOffset=0.15),
        pe("Shock", attrs={"Tint": True}, Texture=tex("flipbooks/shockwaves/shockwave_cel_01_4x4"), **FB4, **FLAT,
           FlipbookFramerate=NR(16 / 0.5), Lifetime=NR(0.5), Size=NS((0, R * 2.4), (1, R * 3.6)),
           Color=CS((0, WHITE), (1, col)), LightEmission=0.4, ZOffset=0.05),
    ]
    if secret:
        for g in ground:
            if g["name"] in ("Ring", "Ring2"):
                g["props"]["Color"] = CS(*RAINBOW)
    inst.append(carrier("Ground", (0, 0.15, 0, 0, 0, 0), [att("A", children=ground)]))

    # ---------------------------------------------------------- the shot up + lock burst
    burst = [
        pe("Shot", attrs={"Tint": True}, Texture=tex("sprites/specks/streak_glow_02"), **STREAK, EmissionDirection=E("NormalId.Top"),
           Speed=NR(H * 3.2), Lifetime=NR(0.3), Size=NS((0, W * 0.9), (1, W * 0.5)),
           Transparency=NS((0, 0), (0.7, 0), (1, 1)), Color=CS((0, WHITE), (1, col)), LightEmission=0.8, ZOffset=1),
        pe("Flash", Texture=tex("sprites/stars/star_glow_00"), Lifetime=NR(0.1), Speed=NR(0), Rotation=NR(-10, 10),
           Size=NS((0, R * 1.3), (1, R * 1.8)), Transparency=NS((0, 0), (0.5, 0.1), (1, 1)),
           Color=CS(WHITE), LightEmission=0.6, Brightness=2, ZOffset=3),
        pe("Pop", attrs={"Tint": True}, Texture=tex("sprites/impacts/starburst_cel_02"), Lifetime=NR(0.28), Speed=NR(0), Rotation=NR(0, 360),
           Size=NS((0, R * 1.1), (0.25, R * 1.5), (1, R * 1.6)), Transparency=NS((0, 0), (0.45, 0), (1, 1)),
           Color=CS((0, WHITE), (0.25, mix(col, WHITE, 0.35)), (1, col)), LightEmission=0.35, ZOffset=2),
        pe("Stars", attrs={"Tint": True}, Texture=tex("sprites/stars/star_cel_01"), EmissionDirection=E("NormalId.Top"), SpreadAngle=V2(70, 70),
           Speed=NR(R * 2.6, R * 4.6), Drag=1.8, Acceleration=V3(0, -R * 3.2, 0), Lifetime=NR(0.7, 1.0),
           Rotation=NR(0, 360), RotSpeed=NR(-260, 260), Size=NS((0, 0.8), (0.08, 2.6), (0.7, 2.1), (1, 0)),
           Color=CS(*RAINBOW3) if secret else CS((0, WHITE), (0.15, mix(col, WHITE, 0.2)), (1, col)), LightEmission=0.4, ZOffset=1.5),
    ]
    inst.append(carrier("Burst", (0, 2.6, 0, 0, 0, 0), [att("A", children=burst)]))

    # ---------------------------------------------------------- sparkles rising through the pillar
    inst.append(carrier("Sparkle", (0, 0.4, 0, 0, 0, 0), size=(R * 1.1, 0.2, R * 1.1), children=[
        pe("Twinkle", attrs={"Tint": True}, Texture=tex("sprites/stars/star_glow_04"), Shape=E("ParticleEmitterShape.Disc"),
           ShapeStyle=E("ParticleEmitterShapeStyle.Volume"), EmissionDirection=E("NormalId.Top"), Rate=p["rate"], Enabled=False,
           Speed=NR(H * 0.35, H * 0.7), Drag=0.6, Lifetime=NR(0.6, 0.9), Rotation=NR(0, 90), RotSpeed=NR(-120, 120),
           Size=NS((0, 0), (0.15, 1.3), (0.6, 1.0), (1, 0)), Transparency=NS((0, 0), (0.7, 0.1), (1, 1)),
           Color=CS(*RAINBOW3) if secret else CS((0, WHITE), (0.4, mix(col, WHITE, 0.4)), (1, col)), LightEmission=0.6, ZOffset=1),
    ]))
    if p["rays"]:
        inst.append(carrier("Rays", (0, H * 0.32, 0, 0, 0, 0), [att("A", children=[
            pe("Rays", attrs={"Tint": True}, Texture=tex("sprites/elements/rays_glow_01"), Lifetime=NR(T - LOCK), Speed=NR(0), Rotation=NR(0, 360),
               RotSpeed=NR(25), Size=NS((0, H * 0.25), (0.12, H * 0.62), (1, H * 0.7)), Transparency=NS((0, 0.15), (0.6, 0.35), (1, 1)),
               Color=CS(mix(col, WHITE, 0.25)), LightEmission=0.5, ZOffset=-1),
        ])]))
    inst.append(light("Lamp", (0, 4, 0, 0, 0, 0), light_col, rng=18 + R))

    # ---------------------------------------------------------- timeline
    tl.at(0, do="emit", target="Ground.A.Ring", count=1)
    tl.at(0, do="emit", target="Ground.A.Glow", count=1)
    tl.at(0, do="emit", target="Burst.A.Shot", count=1)
    for b in pillar:
        w0 = next(x for x in beams if x.get("name") == b)["props"]["Width0"]
        tl.at(0, do="set", target=f"Pillar.{b}", prop="Enabled", value=True)
        tl.at(0, do="tween", target=f"Pillar.{b}", prop="Width0", **{"from": w0 * 0.45}, to=w0, time=0.12, style="Quint", dir="Out")
    # the climb: Body and Halo flick through each lower rarity's colour, 0.1 s a step, hard cuts
    for i in range(r):
        c = hexc(RARITY[ORDER[i]])
        for b in ("Body", "Halo"):
            tl.at(0.06 + 0.1 * i - 0.06, do="set", target=f"Pillar.{b}", prop="Color", value=CS(c))
    for b in ("Body", "Halo"):
        tl.at(LOCK, do="set", target=f"Pillar.{b}", prop="Color", value=CS(col))
    # LOCK: burst
    tl.at(LOCK, do="emit", target="Burst.A.Flash", count=1)
    tl.at(LOCK, do="emit", target="Burst.A.Pop", count=1)
    tl.at(LOCK, do="emit", target="Burst.A.Stars", count=p["stars"])
    if r > 0:
        tl.at(LOCK, do="emit", target="Ground.A.Ring", count=1)
    if p["ring2"]:
        tl.at(LOCK + 0.03, do="emit", target="Ground.A.Ring2", count=1)
    if p["shock"]:
        tl.at(LOCK, do="emit", target="Ground.A.Shock", count=1)
    if p["rays"]:
        tl.at(LOCK, do="emit", target="Rays.A.Rays", count=1)
    tl.at(LOCK, do="tween", target="Pillar.Body", prop="Width0", **{"from": W * 1.45}, to=W, time=0.2, style="Quint", dir="Out")
    tl.at(LOCK, do="enable", target="Sparkle.Twinkle", duration=round(T - LOCK - 0.45, 3))
    tl.at(LOCK, do="set", target="Lamp.L", prop="Brightness", value=3.5)
    tl.at(LOCK + 0.02, do="tween", target="Lamp.L", prop="Brightness", to=0, time=0.6, style="Quad", dir="Out")
    if p["edge"]:
        tl.at(LOCK, do="overlay", kind="lines", image=tex("tfa/edge_glow"), spin=False, scale=0.87, time=0.35, fin=0.03, fout=0.28,
              color=list(GOLD if secret else mix(col, WHITE, 0.2)), transparency=0.3)
        tl.at(LOCK, do="shake", amp=p["shake"], time=0.3 if not secret else 0.45, freq=24)
    # pillar thins out (both widths) and fades
    fade_t = T - 0.45
    for b in pillar:
        w0 = next(x for x in beams if x.get("name") == b)["props"]["Width0"]
        w1 = next(x for x in beams if x.get("name") == b)["props"]["Width1"]
        tl.at(fade_t, do="tween", target=f"Pillar.{b}", prop="Width0", to=0, time=0.4, style="Quad", dir="In")
        tl.at(fade_t, do="tween", target=f"Pillar.{b}", prop="Width1", to=0, time=0.3, style="Quad", dir="In")
        tl.at(T - 0.02, do="set", target=f"Pillar.{b}", prop="Enabled", value=False)

    phases = [{"name": "anticipation", "t0": 0, "t1": LOCK}, {"name": "release", "t0": LOCK, "t1": LOCK + 1 / 60},
              {"name": "sustain", "t0": LOCK + 1 / 60, "t1": T - 0.45}, {"name": "residue", "t0": T - 0.45, "t1": T + 0.6}]
    tier = "skill" if T <= 2.0 else "big skill"
    d = {
        "name": f"Reveal_{rar}",
        "note": f"Catch reveal, {rar}: pillar climbs {r} rarity colours then locks; hero appears inside at t={LOCK:.2f}s.",
        "duration": round(T + 0.6, 3),
        "camera": {"pos": [9, 6, 26], "at": [0, 8, 0]},
        "game": {"loop": False, "attach": "point", "screen": p["edge"], "lock": LOCK},
        "brief": {"name": f"Reveal {rar}", "category": "orb_charge", "tier": tier, "style": "stylised_game",
                  "shape": "pillar of light + ground ring + star pop", "dominant": "#" + ("FFD23F" if secret else RARITY[rar]),
                  "accent": "#FFFFFF" if not secret else "#111111", "darks": "#0D0F2B",
                  "signature_beats": ["colour climb through the rarities", "shape born at full size"] + (["screen-edge flash"] if p["edge"] else []),
                  "phases": phases},
        "instances": inst,
        "timeline": tl,
    }
    strip = [0.02, max(0.05, LOCK - 0.05), LOCK + 0.02, LOCK + 0.1, LOCK + 0.3, (LOCK + T) / 2 + 0.2, T - 0.25, T + 0.3]
    return write(d, strip)


if __name__ == "__main__":
    import sys
    for rr in (sys.argv[1:] or ORDER):
        build(rr)
