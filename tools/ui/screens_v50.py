"""UI v5.0 (owner's review of v4.9: "the text info below it is ass ... not arranged and placed properly"), on top of
screens_v49.

  Celebrate   one change: the single-item details. v4.9 hung three thin pills under the card, squeezed between the
              card and the AWESOME button. Now, once a single card is open, the card slides LEFT (the client moves it by
              PerkList's CardShift attribute) and a details PANEL stands beside it, vertically centred on the card:

                PerkList (the panel, 440 x 322, dark glass with a gold keyline)
                  ItemName        the item, big
                  RarityChip      its type / tier pill (tinted by the client)
                  PerkDivider     a thin rule
                  PerkHeader      "WHAT YOU GET"
                  PerkRows        Perk1..3: a row each, a green tick badge + PerkText (two lines allowed)

              Every name the client binds is kept (ItemName, RarityChip/RarityText, PerkList, Perk<i>, PerkText).
              The tree ships the card centred (the reveal happens there); the mockup draws the panel at its final place.
"""

from __future__ import annotations

import mangapop as mp
import screens_v49 as v49
from mangapop import WHITE, col, frame, ico
from mp4 import T, chip
from screens import RARITY

PANEL_W, PANEL_H = 440, 322
CARD_SHIFT = -220                       # the card's x offset once the panel is in (canvas px)
PANEL_X = -70                           # the panel's left edge, from the canvas centre
ROW_W, ROW_H, ROW_GAP = 400, 50, 8
ROWS_Y = 140


def _perk(i, samples):
    badge = {"type": "panel", "name": "PerkBadge", "colour": "confirm", "keyline": WHITE, "depth": 0,
             "corner": 15, "size": [0, 30, 0, 30], "pos": [0, 12, 0.5, 0], "anchor": [0, 0.5], "z": 1,
             "children": [{**ico("IconTick", 18, name="PerkIcon", pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5]),
                           "centre": False}]}
    text = {**T("PerkText", None, ROW_W - 66, 17, font="display", align="left", lines=2, samples=samples,
                pos=[0, 54, 0.5, 0], anchor=[0, 0.5]), "z": 1}
    return {"type": "panel", "name": f"Perk{i}", "colour": ["#2C3496", "#1E2470"], "keyline": "#6872E0",
            "depth": 0, "corner": 12, "size": [0, ROW_W, 0, ROW_H], "children": [badge, text]}


def _single(show):
    stage = {"type": "frame", "name": "ItemStage", "transparent": True, "cls": "ViewportFrame",
             "size": [0, 280, 0, 280], "pos": [0.5, 0, 0, v49.CARD_Y], "anchor": [0.5, 0.5], "z": 4,
             "children": [], "overhang": True, "visible": False, "mockHide": True}
    icon = {**ico("IconLuckyThrowBig", 210, name="ItemIcon", pos=[0.5, 0, 0, v49.CARD_Y], anchor=[0.5, 0.5]),
            "z": 4, "overhang": True, "visible": False, "mockHide": True}
    disc = {**v49.fx("FxGlow", 64, "StageDisc", tint="#FFE38A", alpha=0.15, w=340,
                     pos=[0.5, 0, 0, v49.CARD_BOT - 10], anchor=[0.5, 0.5], z=3), "visible": False, "mockHide": True}

    name = {**T("ItemName", None, PANEL_W - 40, 28, font="display",
                samples=["First Sun Swordsman", "25 Lucky Throws", "VIP"], pos=[0.5, 0, 0, 16], anchor=[0.5, 0]),
            "z": 2}
    rarity = {**chip("RarityChip", "RarityText", ["LEGENDARY", "GAME PASS", "BOOST", "PREMIUM"], RARITY["Legendary"],
                     px=17, h=28, keyline=WHITE), "pos": [0.5, 0, 0, 60], "anchor": [0.5, 0], "z": 2}
    divider = {"type": "frame", "name": "PerkDivider", "colour": ["#8D96F0", "#8D96F0"], "alpha": 0.55,
               "outline": False, "size": [0, PANEL_W - 60, 0, 2], "pos": [0.5, 0, 0, 98], "anchor": [0.5, 0],
               "children": [], "z": 2}
    header = {**T("PerkHeader", "WHAT YOU GET", 300, 16, font="display", colour="gold",
                  pos=[0.5, 0, 0, 110], anchor=[0.5, 0]), "z": 2}
    rows = frame("PerkRows", ROW_W, 3 * ROW_H + 2 * ROW_GAP, [
        _perk(1, ["x12 luck on one throw", "+15% luck on every throw and +2 hero slots"]),
        _perk(2, ["You have 6 Lucky Throws", "Active right now"]),
        _perk(3, ["Switch Lucky on at your throw pad", "Yours on every server, forever"]),
    ], layout=col(ROW_GAP, "start"), pos=[0.5, 0, 0, ROWS_Y], anchor=[0.5, 0], z=2)
    panel = {"type": "panel", "name": "PerkList", "colour": ["#1C2163", "#0E1142"], "keyline": "#E9C46A",
             "depth": 0, "corner": 20, "size": [0, PANEL_W, 0, PANEL_H],
             "pos": [0.5, PANEL_X, 0, v49.CARD_Y], "anchor": [0, 0.5], "z": 6, "visible": False,
             "attrs": {"CardShift": CARD_SHIFT}, "children": [name, rarity, divider, header, rows]}
    if not show:
        panel["mockHide"] = True
    return [disc, icon, stage, panel]


v49._single = _single

SCREENS = v49.SCREENS
TEMPLATES = v49.TEMPLATES
