"""UI v5.2 (plan 13 phase D: the training games), on top of screens_v51.

  TrainingBar  the game area gets what the beat framework needs:
                 TimingRing.Fill   a disc inside the ring. The held game (Waterfall Focus) grows it out to the gold
                                   Target ring on every breath; the tapped game (Striking Post) keeps it hidden and
                                   closes the Shrink ring on the Target as before.
                 FocusBar          Focus (Fill, FocusText): fills with every Perfect and Good; at full the hero
                                   AWAKENS and the bar turns gold and runs down with the seconds left.
                 TapHint           one line over the ring: the ground's own instruction, then what to do right now.
               The Focus percentage no longer rides in the hint line.
"""

from __future__ import annotations

import mp4
import screens_v4 as v4
import screens_v42 as v42
import screens_v51 as v51

CX, CY, SIDE = 800, 340, 220  # the ring box of v4 (kept)


def training():
    spec = v42.training()
    root = {"children": spec["children"]}
    ring = v4.find(root, "TimingRing")
    # the breath disc: under the gold ring, over the dark back
    fill = {"type": "frame", "name": "Fill", "colour": ["#9BEBFF", "#38BDF8"], "alpha": 0.2, "outline": False,
            "corner": 1, "size": [0.3, 0, 0.3, 0], "pos": [0.5, 0, 0.5, 0], "anchor": [0.5, 0.5], "children": [],
            "overhang": True, "z": 1, "visible": False}
    ring["children"].insert(1, fill)
    focus = mp4.track("FocusBar", 264, 28, 0.6, "#FFC93C", text_name="FocusText",
                      samples=["FOCUS 100%", "AWAKENED! 8s"], px=18,
                      pos=[0, CX, 0, CY + SIDE // 2 + 12], anchor=[0.5, 0])
    tap = v4.find(root, "TapHint")
    # over the ring, where the station's name used to be (StationTitle is hidden in play): under the
    # Focus bar it ran into the UPGRADE READY chip
    tap.update({"pos": [0, CX, 0, CY - SIDE // 2 - 96]})
    spec["children"].append(focus)
    return spec


SCREENS = [training if fn is v42.training else fn for fn in v51.SCREENS]
TEMPLATES = list(v51.TEMPLATES)
