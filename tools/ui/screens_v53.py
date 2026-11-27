"""UI v5.3 (plan 13 phase E: grounds 3 and 4), on top of screens_v52.

  TrainingBar  two more game pictures in the ring's place (the client shows the one the ground plays and
               hides the others):
                 SweepMeter  (Boulder Breaker) a bar the Needle sweeps along; Sweet is the gold zone (Good),
                             SweetCore the green line in it (Perfect). Tap as the needle crosses it.
                 Rods        (Thunder Peak) three round buttons, Rod1 / Rod2 / Rod3 = left / middle / right.
                             Lightning marks one (its Mark ring shows and pulses); tap that one before the
                             strike. Each carries its arrow (RodGlyph); the keys A / S / D (or the arrow keys) and
                             a tap on that third of the screen do the same.
"""

from __future__ import annotations

import mp4
import screens_v4 as v4
import screens_v52 as v52
from mp4 import T
from screens_v4 import GOLD

CX, CY = v52.CX, v52.CY
METER_W, METER_H = 320, 40
ROD, ROD_GAP = 72, 26


def rod(index, glyph):
    node = {"type": "button", "name": f"Rod{index}", "colour": "info", "size": [0, ROD, 0, ROD], "corner": ROD // 2,
            "depth": 3, "sizeClass": "HUD", "centre": False, "children": [
                {**mp4.ring("Mark", ROD + 14, GOLD, 7, pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5], z=4, overhang=True),
                 "visible": False},
                {**T("RodGlyph", glyph, 30, 34, font="display", pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5]), "z": 3},
            ]}
    mp4.mp3.gloss(node, "info")
    node["attrs"] = {"PressLip": 3, "Lane": index}
    return node


def training():
    spec = v52.training()
    # the sweep meter: a dark track, the gold sweet zone with its green core, the needle on top
    sweet_x, sweet_w = 0.74, 0.20
    meter = {"type": "frame", "name": "SweepMeter", "colour": ["#0B0D29", "#161A48"], "keyline": "#3A4196",
             "size": [0, METER_W, 0, METER_H], "corner": METER_H // 2, "pos": [0, CX, 0, CY], "anchor": [0.5, 0.5],
             "visible": False, "attrs": {"SweetAt": sweet_x, "SweetWidth": sweet_w}, "children": [
                 {"type": "frame", "name": "Sweet", "colour": ["#FFE066", "#FFA41B"], "outline": False, "corner": 8,
                  "size": [sweet_w, 0, 1, -8], "pos": [sweet_x, 0, 0.5, 0], "anchor": [0.5, 0.5], "children": [],
                  "overhang": True, "z": 2},
                 {"type": "frame", "name": "SweetCore", "colour": ["#7BF0A8", "#34D17A"], "outline": False, "corner": 6,
                  "size": [sweet_w * 0.36, 0, 1, -8], "pos": [sweet_x, 0, 0.5, 0], "anchor": [0.5, 0.5],
                  "children": [], "overhang": True, "z": 3},
                 {"type": "frame", "name": "Needle", "colour": ["#FFFFFF", "#FFFFFF"], "keyline": "#161A48", "corner": 4,
                  "size": [0, 10, 1, 18], "pos": [0.1, 0, 0.5, 0], "anchor": [0.5, 0.5], "children": [],
                  "overhang": True, "z": 5},
             ]}
    width = 3 * ROD + 2 * ROD_GAP
    rods = {**v4.frame("Rods", width, ROD + 20, [
        {**rod(1, "<"), "pos": [0, 0, 0.5, 0], "anchor": [0, 0.5]},
        {**rod(2, "^"), "pos": [0.5, 0, 0.5, 0], "anchor": [0.5, 0.5]},
        {**rod(3, ">"), "pos": [1, 0, 0.5, 0], "anchor": [1, 0.5]},
    ], pos=[0, CX, 0, CY], anchor=[0.5, 0.5]), "visible": False}
    spec["children"] += [meter, rods]
    return spec


SCREENS = [training if fn is v52.training else fn for fn in v52.SCREENS]
TEMPLATES = list(v52.TEMPLATES)
