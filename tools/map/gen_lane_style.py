"""Lane floor and wall faces for gen_map.py (map v3, brief B + C, research 06 sections 1.5 and 3).

Imported by gen_map.py with its namespace injected (`install(ns)`), so it uses the same add(),
mesh(), BANDS, SIZES ... and stays readable apart from the 1,300-line generator.
"""
from __future__ import annotations

import math

KERB_W, KERB_TOP = 1.0, 1.3      # brief B: a raised 1-stud trim along both strip edges
PAVE_TOP, POCKET_TOP = 0.36, 0.5  # margin paving and its planting pockets
FACADE_D = 1.2                    # how far the wall facade (plinth, pilasters) stands proud of the wall
LINE_D = 6.0                      # the painted zone band at each zone line (carries the zone name)
MARK_EVERY = 60                   # a distance marker every 60 studs (brief B)
TONE_EVERY = 45                   # two tones of the zone hue along the lane (45-stud tiles: part budget)
PARAPET_H = 1.6                   # research 1.5 rule 4: the parapet is the wall cap raised 1.6 (a coping band)
WHITE = [255, 255, 255]
BLACK = [0, 0, 0]
WALL_MAT = {"sakura_schoolyard": "Brick", "pirate_harbor": "WoodPlanks", "ninja_village": "Wood",
            "samurai_castle": "Cobblestone", "hero_city": "Concrete", "realm_of_legends": "Marble", "hub": "Brick"}
SIGNS = {}                        # (lane index, side) -> [z] of distance signs; the foot props keep clear

G_ = {}


def install(ns):
    G_.update(ns)


def build_lanes(G):
    g = G_
    add, mesh, mix, hexrgb, SIZES = g["add"], g["mesh"], g["mix"], g["hexrgb"], g["SIZES"]
    LANES, LANE_W, STRIP_W, LANE0 = g["LANES"], g["LANE_W"], g["STRIP_W"], g["LANE0"]
    gx, gy, gz = SIZES["Lane_ZoneGate"]
    for b in g["BANDS"]:
        key = hexrgb(b["colour"])
        # deep enough not to bloom: the first tones (0.22 / 0.42 toward white) made the pale pink
        # Sakura strip render pure white in play under the map bloom (threshold 0.92)
        tones = (mix(key, WHITE, 0.06), mix(key, WHITE, 0.20))
        accent = hexrgb(b["cap"])
        pave_rgb = mix(hexrgb(b["wall"]), WHITE, 0.35)
        F = f"Lanes/Zone_{b['id']}"
        za = b["z0"] + LINE_D
        L = b["z1"] - za
        for i, x in enumerate(LANES, 1):
            add({"id": f"Line_{b['id']}_{i}", "size": [LANE_W, 4, LINE_D], "pos": [x, g["LINE_TOP"] - 2, b["z0"] + LINE_D / 2],
                 "roles": ["main_route", "zone_line"], "color": key, "material": "SmoothPlastic",
                 "build": {"kind": "part", "folder": F, "name": f"Line_{b['id']}_{i}", "attrs": {"Zone": b["id"]},
                           "toplabel": b["name"].upper()}})
            # the landing strip in 24-stud tiles of two tones (one Part per tile, each with the zone pattern)
            n = max(1, round(L / TONE_EVERY))
            for t in range(n):
                z0, z1 = za + t * L / n, za + (t + 1) * L / n
                add({"id": f"Strip_{b['id']}_{i}_{t + 1}", "size": [STRIP_W, 4, round(z1 - z0, 3)],
                     "pos": [x, g["STRIP_TOP"] - 2, round((z0 + z1) / 2, 3)], "roles": ["main_route", "landing_strip"],
                     "color": tones[t % 2], "material": "SmoothPlastic",
                     "texture": {"name": b.get("floor_texture", "checker"), "faces": ["Top"]},
                     "build": {"kind": "part", "folder": F, "name": f"Strip_{b['id']}_{i}",
                               "attrs": {"Zone": b["id"], "Plot": i}}})
            for sd in (-1, 1):
                tag = "R" if sd > 0 else "L"
                add({"id": f"Kerb_{b['id']}_{i}{tag}", "size": [KERB_W, 2.6, L],
                     "pos": [x + sd * (STRIP_W / 2 + KERB_W / 2), KERB_TOP - 1.3, za + L / 2], "roles": ["prop"],
                     "decor": True, "color": accent, "material": "SmoothPlastic",
                     "build": {"kind": "part", "folder": F, "name": "Kerb", "noshadow": True}})
                x0, x1 = x + sd * (STRIP_W / 2 + KERB_W), x + sd * LANE_W / 2
                add({"id": f"Pave_{b['id']}_{i}{tag}", "size": [abs(x1 - x0), 2, L],
                     "pos": [(x0 + x1) / 2, PAVE_TOP - 1, za + L / 2], "roles": ["prop"], "decor": True,
                     "color": pave_rgb, "material": b.get("pave", "Cobblestone"),
                     "texture": {"name": "setts", "faces": ["Top"]},
                     "build": {"kind": "part", "folder": F, "name": "Paving", "noshadow": True}})
            # distance markers: a painted band across the strip + a plaque at the wall foot (the number
            # goes on the plaque, never the floor: research 3.1, unreadable from the chase camera)
            dist = MARK_EVERY * math.ceil((za + 3 - LANE0) / MARK_EVERY)
            while LANE0 + dist < b["z1"] - 3:
                z = LANE0 + dist
                add({"id": f"Mark_{i}_{dist}", "size": [STRIP_W, 0.2, 1.2], "pos": [x, g["STRIP_TOP"] - 0.02, z],
                     "roles": ["prop"], "decor": True, "solid": False, "color": mix(key, WHITE, 0.8),
                     "material": "SmoothPlastic", "build": {"kind": "part", "folder": F, "name": "DistanceBand",
                                                            "noshadow": True}})
                sd = 1 if (dist // MARK_EVERY + i) % 2 else -1
                sx = x + sd * (LANE_W / 2 - 0.55)        # mounted on the wall plinth: no post
                add({"id": f"MarkSign_{i}_{dist}", "size": [0.3, 1.8, 3.6], "pos": [sx, PAVE_TOP + 3.6, z],
                     "roles": ["prop"], "decor": True, "solid": False, "color": [255, 244, 220],
                     "material": "SmoothPlastic",
                     "build": {"kind": "part", "folder": F, "name": "DistanceSign", "noshadow": True,
                               "facetext": {"text": f"{dist}", "face": "Left" if sd > 0 else "Right"}}})
                SIGNS.setdefault((i, sd), []).append(z)
                dist += MARK_EVERY
            label = (f"{b['name'].upper()}\nSTART HERE" if b["power"] == 0
                     else f"{b['name'].upper()}\nNEEDS {g['fmt_power'](b['power'])} POWER")
            base = G.surf(x + LANE_W / 2 - 3, b["z0"]) - 0.6
            mesh(f"Gate_{b['id']}_{i}", "Lane_ZoneGate", x, base, b["z0"] + LINE_D + gz / 2 + 0.2,
                 solid=False, folder=F, biome="lanes",
                 extra={"name": f"Gate_{b['id']}_{i}", "accent": key, "persistent": True,
                        "banner": {"text": label, "size": [22, 4.5], "dy": gy - 7.0}})


def zone_style(z, folder):
    g = G_
    if folder.startswith("Hub") or z < g["LANE0"] - 12:
        h = g["ZD"]["hub"]
        return {"id": "hub", "wall": h["wall"], "cap": h["cap"], "colour": "#E0453C",
                "hung": h.get("hung", ["banner"]), "wall_texture": h.get("wall_texture", "brick")}
    return g["band_at"](z)


def face_name(along, side):
    if along == "z":
        return "Right" if side > 0 else "Left"
    return "Back" if side > 0 else "Front"


def wall_faces():
    """Research 3.2, on a part budget (v3.1: the first pass put 21,560 BaseParts in the place):
      - ONE plinth per wall face per zone (merged across segments; the plinth has a fixed height)
      - the parapet is the wall cap itself raised PARAPET_H (gen_map.wall_run): no extra parts
      - a pilaster at every other segment joint (36-60 studs), one part, no cap
      - a hung group on every other bay, lean: noren = rod + 3 strips with slits between them,
        banner = one cloth with a crest/border texture, lanterns = cord + 3, window = dark frame +
        shoji panel, sign = frame + board, poster = 1
    Only faces a player can see get any of this (seg["faces"]: lane-, plot- or hub-facing)."""
    g = G_
    add, mix, hexrgb = g["add"], g["mix"], g["hexrgb"]
    n = 0
    segs_by = {}
    for sg in g["WALL_SEGS"]:
        segs_by.setdefault(sg["key"], []).append(sg)

    def fbox(sg, side, u0, u1, n0, n1, y0, y1, rgb, name, mat="SmoothPlastic", shape=None, tex=None):
        nonlocal n
        n += 1
        fc = sg["x"] + side * sg["width"] / 2
        na, nb = fc + side * n0, fc + side * n1
        if sg["along"] == "z":
            size, pos = [abs(nb - na), y1 - y0, u1 - u0], [(na + nb) / 2, (y0 + y1) / 2, (u0 + u1) / 2]
        else:
            size, pos = [u1 - u0, y1 - y0, abs(nb - na)], [(u0 + u1) / 2, (y0 + y1) / 2, (na + nb) / 2]
        folder = sg["folder"].replace("Walls_", "Facade_").replace("Hub/Walls", "Hub/Facade")
        p = {"id": f"Fac{n}", "size": [round(v, 3) for v in size], "pos": [round(v, 3) for v in pos],
             "roles": ["prop"], "decor": True, "solid": False, "color": rgb, "material": mat,
             "build": {"kind": "part", "folder": folder, "name": name, "noshadow": True}}
        if shape:
            p["shape"] = shape
        if tex:
            # one tile across the whole cloth/panel face, white design tinted over the part colour
            p["texture"] = {"name": tex, "faces": [face_name(sg["along"], side)],
                            "su": round(u1 - u0, 3), "sv": round(y1 - y0, 3)}
        add(p)

    k_hung = 0
    for key, segs in segs_by.items():
        # merged plinths: one run per (face, folder) of contiguous segments
        for side in segs[0]["faces"]:
            run = None
            for sg in segs + [None]:
                if run and (sg is None or sg["folder"] != run[0]["folder"] or abs(sg["a"] - run[-1]["b"]) > 1e-6):
                    st = zone_style(run[0]["mid"], run[0]["folder"])
                    fbox(run[0], side, run[0]["a"], run[-1]["b"], 0, 0.5, -1.5, 2.2,
                         mix(hexrgb(st["wall"]), BLACK, 0.38), "Plinth", "Slate")
                    run = None
                if sg is not None:
                    run = (run or []) + [sg]
        for idx, sg in enumerate(segs):
            st = zone_style(sg["mid"], sg["folder"])
            body = hexrgb(st["wall"])
            dark = mix(body, BLACK, 0.38)
            pil = mix(body, BLACK, 0.2)
            keyc = hexrgb(st["colour"])
            mat = WALL_MAT.get(st["id"], "Brick")
            a, b, h = sg["a"], sg["b"], sg["h"]
            prev_h = segs[idx - 1]["h"] if idx > 0 and abs(segs[idx - 1]["b"] - a) < 1e-6 else 0
            for side in sg["faces"]:
                if idx % 2 == 0:
                    fbox(sg, side, a - 1.0, a + 1.0, 0, 0.9, -1.5, max(h, prev_h), pil, "Pilaster", mat)
                if h < 12 or b - a < 10 or (idx + (side > 0)) % 2:
                    continue
                kind = st["hung"][k_hung % len(st["hung"])]
                k_hung += 1
                c, yt = (a + b) / 2, h - 2.4
                drop = (5.5, 7.0, 8.5)[k_hung % 3]          # varied lengths
                if kind == "noren":
                    fbox(sg, side, c - 4.8, c + 4.8, 0.2, 0.6, yt - 0.4, yt, dark, "NorenRod", "Wood")
                    for j in (-1, 0, 1):                         # three strips, slits between them
                        fbox(sg, side, c + j * 3.1 - 1.4, c + j * 3.1 + 1.4, 0.1, 0.3, yt - drop * 0.7, yt - 0.4,
                             keyc, "Noren", "Fabric", tex="noren")
                elif kind == "banner":
                    fbox(sg, side, c - 1.5, c + 1.5, 0.1, 0.35, yt - drop - 1.5, yt, keyc, "Banner", "Fabric",
                         tex="banner")
                elif kind == "lanterns":
                    span = min(b - a - 4, 12)
                    fbox(sg, side, c - span / 2, c + span / 2, 0.5, 0.7, yt - 0.1, yt + 0.1, dark, "LanternCord")
                    for j in range(3):
                        u = c - span / 2 + (j + 0.5) * span / 3
                        fbox(sg, side, u - 0.9, u + 0.9, 0.4, 2.2, yt - 2.2, yt - 0.4,
                             [224, 69, 60] if j != 1 else [255, 244, 220], "Lantern", "SmoothPlastic", shape="ball")
                elif kind == "sign":
                    fbox(sg, side, c - 3.8, c + 3.8, 0, 0.3, yt - 3.3, yt + 0.3, dark, "SignFrame", "Wood")
                    fbox(sg, side, c - 3.5, c + 3.5, 0.3, 0.5, yt - 3.0, yt, keyc, "ShopSign", "SmoothPlastic",
                         tex="banner")
                elif kind == "window":
                    fbox(sg, side, c - 2.6, c + 2.6, 0, 0.3, yt - 6.2, yt - 0.8, dark, "WindowFrame", "Wood")
                    fbox(sg, side, c - 2.2, c + 2.2, 0.3, 0.4, yt - 5.8, yt - 1.2, [255, 244, 220], "Shoji",
                         "SmoothPlastic", tex="shoji")
                else:    # poster
                    pal = [[255, 201, 60], [79, 139, 255], [255, 143, 177], [91, 212, 58], [166, 107, 255]]
                    fbox(sg, side, c - 1.6, c + 1.6, 0.05, 0.2, yt - 6.0, yt - 1.5, pal[k_hung % len(pal)],
                         "Poster", tex="banner")
    return n
