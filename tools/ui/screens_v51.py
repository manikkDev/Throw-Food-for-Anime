"""UI v5.1 (economy v2, design/plan/12 sections 3.5, 9 and 10), on top of screens_v50.

  ThrowMeter   AIM: two round arrow buttons either side of the "Lands in" line (AimBack, AimFurther) step the zone
               the player throws into; the client hides the one that cannot move. ODDS (OddsButton), a small pill left
               of the meter's foot, opens the live odds. (v5.0 had no aim control: the meter's zone marks picked the
               zone by timing; the client's first pass used invisible tap areas over the label.)

  ThrowOdds    NEW page: the live odds of the next throw. Roblox requires the odds of anything a paid luck boost can
               change to be shown as percentages and to update while the boost is on, so this page is the truth the
               Lucky Throw and Server Luck products point at.
                 OddsZone    "Hidden Leaf Village"        OddsLuck   "Your luck x4.20"
                 OddsLines   a scrolling list of ThrowOddsRowTemplate rows written by the client:
                               a rarity / mutation / size row:  Swatch (tinted)  Name  Percent  OneIn
                               a section header row:            Name only, in gold (HEROES, MUTATIONS, SIZES, YOUR LUCK)
                               a luck line:                     Name  Percent (the "x1.5" or "+30%")
                 OddsNote    one line: what a Lucky Throw changes

  ThrowOddsRowTemplate   one row of that list.
"""

from __future__ import annotations

import mangapop as mp
import screens_v4 as v4
import screens_v50 as v50
from mangapop import WHITE, col, frame, sample
from mp3 import vscroll
from mp4 import T, vbtn, window
from screens import RARITY, page
from screens_v2 import find

ROW_W, ROW_H = 660, 40


# =================================================================== ThrowMeter

def throw_meter():
    spec = v4.throw_meter()
    root = {"children": spec["children"]}
    zp = find(root, "ZonePreviewLabel")
    # the line is narrowed about its own centre so both arrows stay clear of Roblox's player list
    centre = zp["pos"][1] + zp["size"][1] // 2
    w, h = 340, zp["size"][3]
    x0, y0 = centre - w // 2, zp["pos"][3]
    zp["pos"][1], zp["size"][1] = x0, w
    cy = y0 + h // 2
    back = vbtn("AimBack", "violet", "S", text="<", w=48, px=30, pos=[0, x0 - 8, 0, cy], anchor=[1, 0.5], z=6)
    further = vbtn("AimFurther", "violet", "S", text=">", w=48, px=30, pos=[0, x0 + w + 8, 0, cy], anchor=[0, 0.5], z=6)
    # left of the meter's foot, clear of the lane view's middle and of the bonus label on the right
    odds = vbtn("OddsButton", "violet", "S", icon="IconLuck", text="ODDS", pos=[0, 760, 0, 470], anchor=[1, 0.5], z=6)
    zp["samples"] = ["Lands in: Planet of the Gods", "Lands in: Grand Line"]
    mp.DISPLAY_TEXTS.update(zp["samples"])
    # the marker is worth LUCK now (how deep the food lands), not Power
    bl = find(root, "BonusLabel")
    bl["samples"] = ["+25% LUCK", "+0% LUCK"]
    mp.DISPLAY_TEXTS.update(bl["samples"])
    spec["children"] += [back, further, odds]
    # the game turns Roblox's player list off (client init, as the HUD declares since v4.7)
    spec["coreGui"] = {"playerList": False}
    return spec


# =================================================================== ThrowOdds

def throw_odds_row_template(name="ThrowOddsRowTemplate", label="Legendary", percent="0.75%", one_in="1 in 133",
                            hexcol=None, header=False):
    hexcol = hexcol or RARITY["Legendary"]
    swatch = {"type": "panel", "name": "Swatch", "colour": [hexcol, hexcol], "paintable": True, "depth": 0,
              "keyline": WHITE, "corner": 11, "size": [0, 22, 0, 22], "pos": [0, 12, 0.5, 0], "anchor": [0, 0.5],
              "children": [], **({"visible": False, "mockHide": True} if header else {})}
    kids = [
        swatch,
        T("Name", None, 250, 20, font="display", align="left", colour="gold" if header else "onDark",
          samples=[label, "INSANE LUCK"], pos=[0, 14 if header else 46, 0.5, 0], anchor=[0, 0.5]),
        T("Percent", None, 150, 20, font="display", align="right", samples=[percent, "100.00%"],
          pos=[1, -196, 0.5, 0], anchor=[1, 0.5]),
        T("OneIn", None, 176, 18, colour="soft", align="right", samples=[one_in, "1 in 1,000,000"],
          pos=[1, -12, 0.5, 0], anchor=[1, 0.5]),
    ]
    tint = ["#161A4E", "#161A4E"] if header else ["#2A3088", "#232870"]
    return {"type": "panel", "name": name, "colour": tint, "paintable": True, "depth": 0,
            "keyline": "#3A4196", "corner": 12, "size": [0, ROW_W, 0, ROW_H], "children": kids}


def throw_odds():
    rows_data = [
        ("HEROES IN THIS ZONE", "", "", None, True),
        ("Common", "49.20%", "1 in 2.0", RARITY["Common"], False),
        ("Uncommon", "26.49%", "1 in 3.8", RARITY["Uncommon"], False),
        ("Rare", "18.36%", "1 in 5.4", RARITY["Rare"], False),
        ("Epic", "5.00%", "1 in 20", RARITY["Epic"], False),
        ("Legendary", "0.63%", "1 in 160", RARITY["Legendary"], False),
        ("Mythic", "0.03%", "1 in 4,000", RARITY["Mythic"], False),
        ("MUTATIONS", "", "", None, True),
    ]
    rows = [sample(throw_odds_row_template(label=a, percent=b, one_in=c, hexcol=d, header=e), i + 1)
            for i, (a, b, c, d, e) in enumerate(rows_data)]
    head = frame("OddsHead", ROW_W, 34, [
        T("OddsZone", None, 400, 26, font="display", align="left",
          samples=["Planet of the Gods", "Hidden Leaf Village"], pos=[0, 4, 0.5, 0], anchor=[0, 0.5]),
        T("OddsLuck", None, 240, 22, colour="luck", font="display", align="right",
          samples=["Your luck x999.9", "Your luck x1.00"], pos=[1, -4, 0.5, 0], anchor=[1, 0.5]),
    ], pos=[0.5, 0, 0, 0], anchor=[0.5, 0])
    lines = vscroll("OddsLines", ROW_W + 20, 360, rows, col(8, "start"), pad=6, pos=[0.5, 0, 0, 44], anchor=[0.5, 0])
    note = T("OddsNote", None, ROW_W, 18, colour="soft", align="center",
             samples=["A Lucky Throw: x12 luck, never below Epic", "Luck divides every 1 in N"],
             pos=[0.5, 0, 0, 416], anchor=[0.5, 0])
    return page("ThrowOdds", window("THROW ODDS", ROW_W + 40, 440, [head, lines, note], colour="violet",
                                    icon="IconLuckBig"), displayOrder=12)


SCREENS = [throw_meter if fn is v4.throw_meter else fn for fn in v50.SCREENS] + [throw_odds]
TEMPLATES = list(v50.TEMPLATES) + [(throw_odds_row_template, "ThrowOdds")]
