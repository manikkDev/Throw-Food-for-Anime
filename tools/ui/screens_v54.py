"""UI v5.4 (plan 13 phase E: grounds 5 and 6), on top of screens_v53.

  TrainingBar  two more game pictures in the ring's place (the client shows the one the ground plays and
               hides the others):
                 BeatTrack    (Gravity Chamber) a track the beats ride along, right to left, as round notes
                              Note1..Note6; tap as a note sits in the gold Hit ring. A REST is a gap in the
                              line (drawn as a small dim note): do not tap it.
                 ChargeMeter  (Spirit Orb) an upright gauge. Hold: Fill climbs; let go while it is in the gold
                              Sweet band (SweetCore = Perfect). Marker is the level the charge WOULD have, shown
                              while nothing is held.
"""

from __future__ import annotations

import mp4
import screens_v53 as v53
from screens_v4 import GOLD

CX, CY = v53.CX, v53.CY
TRACK_W, TRACK_H = 340, 60
NOTE = 36
GAUGE_W, GAUGE_H = 58, 210


def note(index):
    return {"type": "frame", "name": f"Note{index}", "colour": ["#FFFFFF", "#D9D4FF"], "keyline": "#161A48",
            "corner": NOTE // 2, "size": [0, NOTE, 0, NOTE], "pos": [0.5 + 0.1 * index, 0, 0.5, 0],
            "anchor": [0.5, 0.5], "children": [], "overhang": True, "z": 3}


def training():
    spec = v53.training()
    hit_x = 0.16
    track = {"type": "frame", "name": "BeatTrack", "colour": ["#0B0D29", "#161A48"], "keyline": "#3A4196",
             "size": [0, TRACK_W, 0, TRACK_H], "corner": TRACK_H // 2, "pos": [0, CX, 0, CY], "anchor": [0.5, 0.5],
             "visible": False, "attrs": {"HitAt": hit_x, "PerSecond": 0.27}, "children": [
                 {"type": "frame", "name": "Line", "colour": ["#3A4196", "#3A4196"], "outline": False, "corner": 2,
                  "size": [1, -40, 0, 4], "pos": [0.5, 0, 0.5, 0], "anchor": [0.5, 0.5], "children": [], "z": 1},
                 mp4.ring("Hit", NOTE + 14, GOLD, 6, pos=[hit_x, 0, 0.5, 0], anchor=[0.5, 0.5], z=4, overhang=True),
                 *[note(i) for i in range(1, 7)],
             ]}
    sweet_y, sweet_h = 0.16, 0.18  # from the top: the band's middle and its height
    gauge = {"type": "frame", "name": "ChargeMeter", "colour": ["#0B0D29", "#161A48"], "keyline": "#3A4196",
             "size": [0, GAUGE_W, 0, GAUGE_H], "corner": GAUGE_W // 2, "pos": [0, CX, 0, CY], "anchor": [0.5, 0.5],
             "visible": False, "attrs": {"SweetAt": 1 - sweet_y}, "children": [
                 {"type": "frame", "name": "Fill", "colour": ["#B8FFE6", "#3FE0A0"], "outline": False,
                  "corner": 10, "size": [1, -12, 0.3, 0], "pos": [0.5, 0, 1, -6], "anchor": [0.5, 1], "children": [],
                  "overhang": True, "z": 1},
                 {"type": "frame", "name": "Sweet", "colour": ["#FFE066", "#FFA41B"], "alpha": 0.25, "outline": False,
                  "corner": 8, "size": [1, -8, sweet_h, 0], "pos": [0.5, 0, sweet_y, 0], "anchor": [0.5, 0.5],
                  "children": [], "overhang": True, "z": 2},
                 {"type": "frame", "name": "SweetCore", "colour": ["#7BF0A8", "#34D17A"], "alpha": 0.15,
                  "outline": False, "corner": 4, "size": [1, -8, sweet_h * 0.36, 0], "pos": [0.5, 0, sweet_y, 0],
                  "anchor": [0.5, 0.5], "children": [], "overhang": True, "z": 3},
                 {"type": "frame", "name": "Marker", "colour": ["#FFFFFF", "#FFFFFF"], "keyline": "#161A48",
                  "corner": 3, "size": [1, 6, 0, 8], "pos": [0.5, 0, 0.9, 0], "anchor": [0.5, 0.5], "children": [],
                  "overhang": True, "z": 5},
             ]}
    spec["children"] += [track, gauge]
    return spec


SCREENS = [training if fn is v53.training else fn for fn in v53.SCREENS]
TEMPLATES = list(v53.TEMPLATES)
