"""UI v4.2 (owner's review 3): the screens that changed, on top of screens_v4.

  HudFx       ONE top banner (LevelUp: title and item name inside one glossy plate), the zone banner back at the
              top centre (under the letterbox, below the flight's luck line), the Reward unboxing popup, the
              StatTicks panel. DisplayOrder 15: above the Reveal screen and the cinematic fade.
  Confirm     the modal confirmation dialog (HudController:Confirm), DisplayOrder 14.
  PromptCard  the custom ProximityPrompt card (PromptController), a BillboardGui.
  Nameplate   the pedestal hero plate: rarity word, name, tags, stars, the income big and green.
  TrainingBar no station name in the bar; the UPGRADE READY chip instead of the buy prompt.
  Store       a premium store in sections (Featured, Gamepasses, Luck & Boosts, Yen Packs), each with its own colour,
              a pill header with lines either side, illustrated card backdrops, stickers on the cards' top edges.
  Toast       taller glossy plate with a glowing icon well.

What moved, and the exact paths the client binds, is in design/ui/CHANGES-v4.md ("UI v4.2").
"""

from __future__ import annotations

import math

import mp4
import mangapop as mp
import screens_v4 as v4
from mangapop import WHITE, frame, ico, row, col, sample
from mp4 import (GOLD, PANEL_EDGE, T, auto_label, chip, measure, pill_auto, ribbon_tag, round_x, sheen,
                 sparkle, sunburst, vbtn, vbtn2)
from screens import CFG, MUT_HEX, RARITY, page

PASSES, PRODS, SUMMON = v4.PASSES, v4.PRODS, v4.SUMMON
NAVY = ["#2C3280", "#181B4C"]


def fx(key, side, name, tint="#FFFFFF", alpha=0.0, w=None, turn=None, **kw):
    """A white effect sprite (assets/ui/fx_v4) tinted by ImageColor3. `turn` = FxTurn (deg/s) for UiFx."""
    n = ico(key, side, name=name, **kw)
    if w:
        n["size"] = [0, w, 0, side]
    n["tint"] = tint
    if alpha:
        n["alphaImg"] = alpha
    n.setdefault("overhang", True)
    n["centre"] = False  # decoration placed by offset, not a centred element
    if turn is not None:
        n["attrs"] = {**n.get("attrs", {}), "FxTurn": turn}
    return n


def twinkle(name, side, pos, alpha=0.0, **kw):
    return fx("FxTwinkle", side, name, pos=pos, anchor=[0.5, 0.5], alpha=alpha, **kw)


def gloss_band(corner, opacity=0.30):
    """The plate's soft inner highlight: a white band across the top third (a sheen at -90 degrees)."""
    return sheen("Highlight", angle=90, opacity=opacity, bands=((0.08, 0.22),), corner=corner, z=1)


# =================================================================== HudFx

LEVEL_W, LEVEL_H = 500, 86


def level_banner():
    """The single celebratory banner at the TOP centre, in the band under Roblox's top bar: one glossy plate with
    the small title over the big item name, an icon medallion on its left end, rays + glow behind, sparkles."""
    plate = {"type": "panel", "name": "LevelPlate", "colour": ["#FFE066", "#FF9F1A"], "paintable": True,
             "keyline": WHITE, "depth": 0, "corner": 28, "size": [0, LEVEL_W, 0, LEVEL_H], "pos": [0.5, 0, 0, 14],
             "anchor": [0.5, 0], "z": 3,
             "pattern": {"name": "stripes", "colour": "#FFFFFF", "opacity": 0.12, "tile": 64}, "children": [
                 gloss_band(28),
                 {**T("LevelTitle", None, 340, 20, font="display", samples=["NEW GEAR!", "RANK UP!", "REBIRTH 12"],
                      pos=[0.5, 18, 0, 8], anchor=[0.5, 0]), "z": 4, "centre": False},
                 {**T("LevelSub", None, 380, 34, font="display", samples=["Dragon Shrine", "CHAMPION",
                                                                          "You evolved!"],
                      pos=[0.5, 18, 0, 34], anchor=[0.5, 0]), "z": 4, "centre": False},
             ]}
    medal = {"type": "frame", "name": "LevelMedal", "colour": ["#FFFFFF", "#FFE7A8"], "corner": 1,
             "keyline": WHITE, "size": [0, 76, 0, 76], "pos": [0.5, -LEVEL_W // 2 + 30, 0, 14 + LEVEL_H // 2],
             "anchor": [0.5, 0.5], "z": 5, "overhang": True, "centre": False, "children": [
                 {**ico("IconStar", 52, name="LevelIcon", pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5]), "z": 6}]}
    return frame("LevelUp", 640, 120, [
        fx("FxRays", 240, "Rays", tint="#FFE38A", alpha=0.25, w=640, pos=[0.5, 0, 0, 57], anchor=[0.5, 0.5],
           z=1, turn=0),
        fx("FxGlow", 200, "Glow", tint="#FFE38A", alpha=0.2, w=620, pos=[0.5, 0, 0, 57], anchor=[0.5, 0.5], z=2,
           turn=0),
        plate, medal,
        twinkle("Twinkle1", 30, [0.5, -LEVEL_W // 2 + 70, 0, 14]),
        twinkle("Twinkle2", 24, [0.5, LEVEL_W // 2 - 26, 0, 12]),
        twinkle("Twinkle3", 20, [0.5, LEVEL_W // 2 + 4, 0, 96]),
        twinkle("Twinkle4", 18, [0.5, -LEVEL_W // 2 + 120, 0, 104]),
    ], pos=[0.5, 0, 0, 52], anchor=[0.5, 0], visible=False, overhang=True)


def zone_banner():
    """The region banner a thrown food shows as it crosses a gate: TOP centre, under the letterbox bar and below
    the flight's luck line (y 86..117). A small ZONE n tag, the name slamming in (ZoneTitle) with an echo
    (ZoneGhost), a glow and rays in the zone colour, a sheen."""
    pw, ph = 420, 64
    plate = {"type": "panel", "name": "ZonePlate", "colour": ["#FF7AB6", "#E8358F"], "paintable": True,
             "keyline": WHITE, "depth": 0, "corner": 22, "size": [0, pw, 0, ph], "pos": [0.5, 0, 0, 20],
             "anchor": [0.5, 0], "z": 3,
             "pattern": {"name": "stripes", "colour": "#FFFFFF", "opacity": 0.14, "tile": 64}, "children": [
                 gloss_band(22, 0.26),
                 {**T("ZoneGhost", None, 400, 36, font="display", samples=["Sakura Schoolyard", "Realm of Legends"],
                      pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5]), "z": 4, "overhang": True},
                 {**T("ZoneTitle", None, 400, 36, font="display", samples=["Sakura Schoolyard", "Realm of Legends"],
                      pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5]), "z": 5, "overhang": True},
             ]}
    tag = {**v4.rchip("ZoneNumber", "ZoneNumberText", ["ZONE 3", "ZONE 6"], "#1B1F4B", px=17, h=28),
           "pos": [0.5, 0, 0, 6], "anchor": [0.5, 0], "z": 6, "overhang": True}
    return frame("ZoneCross", 560, 104, [
        fx("FxRays", 220, "Rays", tint="#FFFFFF", alpha=0.3, w=560, pos=[0.5, 0, 0, 52], anchor=[0.5, 0.5], z=1,
           turn=0),
        fx("FxGlow", 170, "Glow", tint="#FFFFFF", alpha=0.25, w=540, pos=[0.5, 0, 0, 52], anchor=[0.5, 0.5], z=2,
           turn=0),
        plate, tag,
        twinkle("Twinkle1", 24, [0.5, -pw // 2 + 16, 0, 22]),
        twinkle("Twinkle2", 20, [0.5, pw // 2 - 14, 0, 82]),
    ], pos=[0.5, 0, 0, 122], anchor=[0.5, 0], visible=False, overhang=True)


def reward_popup():
    """The unboxing reward at screen centre: rays and glow in the item colour turning behind a 3D stage
    (RewardStage, a ViewportFrame the client fills with the model), the title on a plate above, the name and the
    sub line under it, sparkles. A tap / click (or 2.8 s) dismisses it."""
    title = {"type": "panel", "name": "RewardTitlePlate", "colour": ["#5BE38A", "#1FA862"], "paintable": True,
             "keyline": WHITE, "depth": 0, "corner": 26, "size": [0, 360, 0, 62], "pos": [0.5, 0, 0, 30],
             "anchor": [0.5, 0], "z": 8,
             "pattern": {"name": "stripes", "colour": "#FFFFFF", "opacity": 0.12, "tile": 64}, "children": [
                 gloss_band(26),
                 {**T("RewardTitle", None, 330, 36, font="display", samples=["NEW GEAR!", "NEW FOOD!", "NEW SLOT!"],
                      pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5]), "z": 9}]}
    stage = {"type": "frame", "name": "RewardStage", "transparent": True, "cls": "ViewportFrame",
             "size": [0, 300, 0, 300], "pos": [0.5, 0, 0, 250], "anchor": [0.5, 0.5], "z": 6, "children": [],
             "overhang": True}
    return frame("Reward", 600, 560, [
        fx("FxRays", 560, "Rays", tint="#7CF0A8", alpha=0.15, pos=[0.5, 0, 0, 250], anchor=[0.5, 0.5], z=1, turn=14),
        fx("FxSunburst", 430, "Rays2", tint="#FFFFFF", alpha=0.55, pos=[0.5, 0, 0, 250], anchor=[0.5, 0.5], z=2,
           turn=-9),
        fx("FxGlow", 420, "Glow", tint="#7CF0A8", alpha=0.1, pos=[0.5, 0, 0, 250], anchor=[0.5, 0.5], z=3, turn=0),
        fx("FxRing", 300, "Halo", tint="#FFFFFF", alpha=0.45, pos=[0.5, 0, 0, 250], anchor=[0.5, 0.5], z=4, turn=0),
        {**ico("IconStar", 180, name="RewardIcon", pos=[0.5, 0, 0, 250], anchor=[0.5, 0.5]), "z": 5,
         "overhang": True},
        stage, title,
        {**T("RewardName", None, 560, 40, font="display", samples=["Dragon Shrine", "Festival Cake", "Slot 9"],
             pos=[0.5, 0, 0, 420], anchor=[0.5, 0]), "z": 8},
        {**T("RewardSub", None, 560, 24, font="display", colour="yen",
             samples=["+2.4K Power per rep", "Luck x5.50  Power x5.00"], pos=[0.5, 0, 0, 472], anchor=[0.5, 0]),
         "z": 8},
        {**T("RewardHint", "tap to continue", 300, 18, colour="soft", pos=[0.5, 0, 0, 516], anchor=[0.5, 0]),
         "z": 8},
        twinkle("Twinkle1", 40, [0, 120, 0, 130], z=7), twinkle("Twinkle2", 28, [1, -110, 0, 150], z=7),
        twinkle("Twinkle3", 34, [1, -130, 0, 360], z=7), twinkle("Twinkle4", 24, [0, 140, 0, 380], z=7),
        twinkle("Twinkle5", 20, [0.5, 150, 0, 110], z=7), twinkle("Twinkle6", 22, [0.5, -160, 0, 330], z=7),
    ], pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5], visible=False, overhang=True)


STAT_ROWS = 6
STAT_W, STAT_ROW_H = 430, 50


def stat_row(i):
    return {"type": "panel", "name": f"StatRow{i}", "colour": ["#2F367F", "#1E2360"], "keyline": "#4C55B8",
            "depth": 0, "corner": 16, "size": [0, STAT_W - 28, 0, STAT_ROW_H], "children": [
                {**ico("IconPower", 30, name="StatIcon", pos=[0, 12, 0.5, 0], anchor=[0, 0.5])},
                T("StatLabel", None, 148, 18, colour="soft", font="display", align="left",
                  samples=["Income", "Index & passes"], pos=[0, 52, 0.5, 0], anchor=[0, 0.5]),
                T("StatFrom", None, 64, 20, colour="soft", font="display", align="right", samples=["x1.50", "1.2M"],
                  pos=[1, -130, 0.5, 0], anchor=[1, 0.5]),
                {**ico("IconArrow", 22, name="StatArrow", pos=[1, -124, 0.5, 0], anchor=[0, 0.5]),
                 "tint": "#5BE37D", "rotation": 90},
                T("StatTo", None, 84, 24, colour="luck", font="display", align="right", samples=["x2.00", "KEPT"],
                  pos=[1, -12, 0.5, 0], anchor=[1, 0.5]),
            ]}


def stat_panel():
    """The rebirth's stats panel, filled one row at a time (HudController:StatTicks)."""
    h = 74 + STAT_ROWS * (STAT_ROW_H + 8) + 10
    head = {"type": "panel", "name": "StatHeader", "colour": ["#C27BFF", "#7B3FF2"], "paintable": True,
            "keyline": WHITE, "depth": 0, "corner": 18, "size": [0, STAT_W - 20, 0, 56], "pos": [0.5, 0, 0, 10],
            "anchor": [0.5, 0], "z": 3,
            "pattern": {"name": "stripes", "colour": "#FFFFFF", "opacity": 0.12, "tile": 64}, "children": [
                gloss_band(18),
                {**T("StatTitle", None, STAT_W - 60, 30, font="display", samples=["REBIRTH 12", "REBIRTH 1"],
                     pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5]), "z": 4}]}
    rows = frame("StatRows", STAT_W - 28, STAT_ROWS * (STAT_ROW_H + 8), [stat_row(i) for i in range(1, STAT_ROWS + 1)],
                 layout=col(8, "start"), pos=[0.5, 0, 0, 76], anchor=[0.5, 0])
    return {"type": "panel", "name": "StatPanel", "colour": NAVY, "keyline": "#8D96F0", "depth": 0, "corner": 22,
            "size": [0, STAT_W, 0, h], "pos": [0, 1030, 0.5, 0], "anchor": [0.5, 0.5], "visible": False,
            "overhang": True, "pattern": {"name": "dots", "colour": "#FFFFFF", "opacity": 0.05, "tile": 28},
            "children": [fx("FxGlow", 300, "Glow", tint="#C27BFF", alpha=0.6, w=STAT_W, pos=[0.5, 0, 0, 38],
                            anchor=[0.5, 0.5], z=1, turn=0), head, rows]}


def hud_fx():
    scrim = {"type": "frame", "name": "Scrim", "colour": [mp.INK, mp.INK], "alpha": 0.5, "outline": False,
             "z": -2, "size": [1, 0, 1, 0], "children": [], "visible": False, "overhang": True}
    return page("HudFx", [scrim, level_banner(), zone_banner(), reward_popup(), stat_panel()], kind="hud",
                displayOrder=15)


# =================================================================== Confirm

CONF_W, CONF_H = 680, 420


def confirm_row(i):
    return frame(f"ConfirmRow{i}", 380, 40, [
        ico("IconPower", 28, name="RowIcon", pos=[0, 0, 0.5, 0], anchor=[0, 0.5]),
        T("RowLabel", None, 132, 18, colour="soft", font="display", align="left",
          samples=["Power per rep", "Hero slots"], pos=[0, 36, 0.5, 0], anchor=[0, 0.5]),
        T("RowFrom", None, 80, 22, colour="soft", font="display", align="right", samples=["+560", "999.9K"],
          pos=[1, -122, 0.5, 0], anchor=[1, 0.5]),
        {**ico("IconArrow", 22, name="RowArrow", pos=[1, -116, 0.5, 0], anchor=[0, 0.5]), "tint": "#5BE37D",
         "rotation": 90},
        T("RowTo", None, 90, 24, colour="luck", font="display", align="right", samples=["+2.4K", "Meditate"],
          pos=[1, 0, 0.5, 0], anchor=[1, 0.5]),
    ])


def confirm():
    yes = vbtn("ConfirmYes", "confirm", "L", icon="IconTick", samples=["CONFIRM", "UPGRADE", "NEED MORE YEN"],
               text_name="YesText")
    no = vbtn("ConfirmNo", "slate", "L", icon="IconClose", text="CANCEL", self_face=False)
    header = {"type": "frame", "name": "ConfirmHeader", "colour": ["#FFE066", "#FFA41B"], "paint": "#FFC83D",
              "corner": 18, "outline": False, "size": [1, -12, 0, 64], "pos": [0.5, 0, 0, 6], "anchor": [0.5, 0],
              "z": 2, "pattern": {"name": "stripes", "colour": "#FFFFFF", "opacity": 0.12, "tile": 64},
              "children": [sheen(corner=18, opacity=0.26),
                           {**T("ConfirmTitle", None, 480, 32, font="display",
                                samples=["UPGRADE GEAR", "NEW HERO SLOT"], pos=[0.5, 0, 0.5, 0],
                                anchor=[0.5, 0.5]), "z": 3}]}
    well = {"type": "frame", "name": "StageWell", "colour": ["#232866", "#12153A"], "corner": 20,
            "keyline": "#4C55B8", "size": [0, 230, 0, 230], "pos": [0, 30, 0, 90],
            "props": {"ClipsDescendants": True}, "children": [
                fx("FxRays", 300, "Rays", tint="#FFC83D", alpha=0.35, pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5], z=1,
                   turn=12),
                fx("FxGlow", 230, "Glow", tint="#FFC83D", alpha=0.3, pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5], z=2,
                   turn=0),
                {**ico("IconTrainBig", 130, name="ConfirmIcon", pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5]), "z": 3},
                {"type": "frame", "name": "ConfirmViewport", "transparent": True, "cls": "ViewportFrame",
                 "size": [1, -8, 1, -8], "pos": [0.5, 0, 0.5, 0], "anchor": [0.5, 0.5], "z": 4, "children": [],
                 "overhang": True},
            ]}
    right = frame("Details", 380, 238, [
        T("ConfirmName", None, 380, 30, font="display", align="left", samples=["Dragon Shrine", "Slot 24"],
          pos=[0, 0, 0, 0]),
        frame("ConfirmRows", 380, 3 * 40 + 2 * 4, [confirm_row(i) for i in (1, 2, 3)], layout=col(4, "start"),
              pos=[0, 0, 0, 48]),
        {"type": "frame", "name": "CostWell", "colour": ["#12153A", "#0B0D29"], "keyline": "#3A4196",
         "corner": 18, "size": [0, 380, 0, 52], "pos": [0, 0, 1, 0], "anchor": [0, 1], "children": [
             T("CostLabel", "COST", 90, 18, colour="soft", font="display", align="left", pos=[0, 16, 0.5, 0],
               anchor=[0, 0.5]),
             frame("CostRow", 236, 44, [ico("IconYen", 34, name="CostIcon"),
                                        auto_label("CostText", ["999.99Qi", "28B"], 30, colour="yen")],
                   layout=row(8, "end"), pos=[1, -16, 0.5, 0], anchor=[1, 0.5])]},
    ], pos=[0, 280, 0, 86])
    buttons = frame("ConfirmButtons", 620, 68, [no, yes], layout=row(20, "center"), pos=[0.5, 0, 1, -18],
                    anchor=[0.5, 1])
    win = {"type": "panel", "name": "ConfirmWindow", "colour": NAVY, "keyline": "#8D96F0", "depth": 0,
           "stroke": mp4.WINDOW_STROKE, "corner": 24, "size": [0, CONF_W, 0, CONF_H], "pos": [0.5, 0, 0.5, 0],
           "anchor": [0.5, 0.5], "modal": True, "pattern": {"name": "dots", "colour": "#FFFFFF", "opacity": 0.05, "tile": 28},
           "children": [header,
                        round_x("ConfirmClose", pos=[1, -14, 0, 10], anchor=[1, 0], z=4, overhang=True),
                        well, right, buttons]}
    scrim = {"type": "frame", "name": "Scrim", "colour": [mp.INK, mp.INK], "alpha": 0.5, "outline": False,
             "z": -2, "size": [1, 0, 1, 0], "children": []}
    return page("Confirm", [scrim, win], kind="hud", enabled=False, displayOrder=14)


# =================================================================== PromptCard (custom ProximityPrompt)

def prompt_card():
    """A glossy rounded card: the key cap on the left (the key letter on PC, the pad button on a gamepad, a tap
    ripple on touch) with a ring of 16 hold pips around it, ActionText bold and ObjectText small. The whole card
    is a TextButton (CardButton) so a touch on it holds the prompt."""
    cap = 62
    pips = []
    R = cap / 2 + 10
    for i in range(16):
        a = -math.pi / 2 + 2 * math.pi * i / 16
        pips.append({"type": "frame", "name": f"Pip{i + 1}", "colour": ["#FFFFFF", "#FFFFFF"], "outline": False,
                     "corner": 1, "size": [0, 7, 0, 7], "alpha": 0.75,
                     "pos": [0, round((cap + 28) / 2 + R * math.cos(a)), 0, round((cap + 28) / 2 + R * math.sin(a))],
                     "anchor": [0.5, 0.5],
                     "children": [], "overhang": True})
    ring = frame("HoldRing", cap + 28, cap + 28, pips, pos=[0, 52, 0.5, 0], anchor=[0.5, 0.5], z=3, overhang=True)
    keycap = {"type": "panel", "name": "KeyCap", "colour": ["#FFFFFF", "#D9DEF5"], "paintable": True,
              "keyline": "#AEB6E8", "depth": 0, "corner": 16, "size": [0, cap, 0, cap], "pos": [0, 52, 0.5, 0],
              "anchor": [0.5, 0.5], "z": 4, "children": [
                  {**T("KeyText", None, cap - 10, 34, colour="ink", font="display", samples=["E", "F", "B"],
                       pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5]), "z": 5},
                  {**ico("FxTap", 40, name="KeyIcon", pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5], visible=False,
                         mockHide=True), "tint": "#1B1F4B", "z": 5}]}
    card = {"type": "panel", "name": "Card", "colour": ["#353C93", "#1A1E52"], "keyline": "#8D96F0", "depth": 0,
            "corner": 24, "size": [0, 330, 0, 92], "pos": [0.5, 0, 0.5, 0], "anchor": [0.5, 0.5],
            "children": [
                gloss_band(24, 0.22),
                fx("FxGlow", 110, "Glow", tint="#FFFFFF", alpha=0.65, pos=[0, 52, 0.5, 0], anchor=[0.5, 0.5], z=2,
                   turn=0),
                ring, keycap,
                {**T("ActionText", None, 220, 28, font="display", align="left",
                     samples=["Upgrade gear", "Place hero", "Train"], pos=[0, 100, 0, 12]), "z": 4},
                {**T("ObjectText", None, 220, 18, colour="soft", align="left",
                     samples=["Dragon Shrine 28B", "Strike Dummy"], pos=[0, 100, 0, 56]), "z": 4},
            ]}
    return {"name": "PromptCard", "theme": "theme.json", "resolution": [350, 112], "kind": "world",
            "rootClass": "BillboardGui", "children": [card],
            "rootProps": {"Size": {"UDim2": [[0, 350], [0, 112]]}, "AlwaysOnTop": True, "LightInfluence": 0,
                          "ClipsDescendants": False, "MaxDistance": 80, "ResetOnSpawn": False}}


# =================================================================== Nameplate

def nameplate():
    """Readable at a distance, compact, centred: the rarity word in its colour (Mythic / Secret get a moving
    gradient at runtime), the name bold white with a dark outline, the tags (size, mutation, stars) as one centred
    group, and the income BIG in green with the yen icon."""
    rarity = T("RarityText", None, 330, 22, font="display", samples=["LEGENDARY", "COMMON"], pos=[0.5, 0, 0, 0],
               anchor=[0.5, 0])
    name = T("HeroName", None, 340, 32, font="display", samples=["Heavenly String King", "Copy Ninja"],
             pos=[0.5, 0, 0, 26], anchor=[0.5, 0])
    stars = {**frame("Stars", 3 * 22 + 2 * 2, 24, [ico("IconStar", 22, name=f"Star{i}") for i in (1, 2, 3)],
                     layout=row(2, "center")), "autoW": 0}
    tags = frame("TagRow", 340, 30, [
        pill_auto("SizeTag", "SizeText", ["TITAN", "BIG"], "info", px=18, h=28),
        pill_auto("MutationTag", "MutationText", ["LIGHTNING", "GOLDEN"], MUT_HEX["Lightning"], px=18, h=28),
        stars,
    ], layout=row(6, "center"), pos=[0.5, 0, 0, 66], anchor=[0.5, 0])
    yen = auto_label("YenPerSecond", ["+999.99Qi/s", "+1.2K/s"], 36, colour="luck")
    income = frame("BottomRow", 340, 46, [ico("IconYenBig", 40, name="YenIcon"), yen], layout=row(6, "center"),
                   pos=[0.5, 0, 0, 102], anchor=[0.5, 0])
    return {"name": "Nameplate", "theme": "theme.json", "resolution": [350, 150], "kind": "world",
            "rootClass": "BillboardGui", "children": [rarity, name, tags, income],
            "rootProps": {"Size": {"UDim2": [[0, 350], [0, 150]]}, "StudsOffset": {"Vector3": [0, 4.5, 0]},
                          "MaxDistance": 60, "AlwaysOnTop": False, "LightInfluence": 0, "ClipsDescendants": False}}


# =================================================================== Toast

TOAST_W, TOAST_H = 440, 58


def toast_template(name="ToastTemplate", text=None, kind="info", **kw):
    """A glossy notification: gradient plate (repainted per kind), a soft inner highlight, a round white icon well
    with a glow, chunky text. The client lays a gloss and a shine over it; nothing about it is ever rotated."""
    well = {"type": "frame", "name": "IconWell", "colour": ["#FFFFFF", "#E6ECFF"], "corner": 1,
            "keyline": "#FFFFFF", "size": [0, 42, 0, 42], "children": [
                ico("IconInfo", 30, pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5])]}
    lab = T("Text", None, TOAST_W - 42 - 10 - 40, 20, font="display", align="left",
            samples=text or ["Not enough yen for Festival Cake!"])
    return {"type": "panel", "name": name, "colour": v4.TOAST_KIND[kind], "paintable": True, "keyline": WHITE,
            "depth": 0, "corner": 20, "size": [0, TOAST_W, 0, TOAST_H], "layout": row(10, "start"),
            "children": [
                {"type": "frame", "name": "Pad", "transparent": True, "size": [0, 4, 0, 10], "children": []},
                well, lab]}


def hud():
    spec = v4.hud()
    root = {"children": spec["children"]}
    toasts = v4.find(root, "Toasts")
    toasts.update({"size": [0, TOAST_W, 0, 3 * TOAST_H + 2 * 8],
                   "children": [sample(toast_template(text=["Not enough yen for Festival Cake!"], kind="bad"), 1),
                                sample(toast_template(text=["Gift 3 is ready to claim!"], kind="good"), 2)]})
    return spec


# =================================================================== TrainingBar

def training():
    spec = v4.training()
    kids = spec["children"]
    # the station's name is in the world; the bar says rank, progress and power only
    panel = next(k for k in kids if k.get("name") == "TrainingPanel")
    head = v4.find({"children": [panel]}, "HeadRow")
    head["children"] = [T("RankName", None, 400, 26, colour="power", font="display",
                          samples=["CHAMPION", "ROOKIE"], pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5])]
    # UPGRADE READY: a pulsing gold chip, not a buy button (the gear is bought at the gear stand, with a confirm)
    ready = {"type": "panel", "name": "UpgradeReady", "colour": ["#FFE066", "#FFA41B"], "paintable": True,
             "keyline": WHITE, "depth": 0, "corner": 22, "size": [0, 470, 0, 62], "pos": [0.5, 0, 1, -150],
             "anchor": [0.5, 1], "visible": False,
             "pattern": {"name": "stripes", "colour": "#FFFFFF", "opacity": 0.14, "tile": 64}, "children": [
                 gloss_band(22),
                 fx("FxGlow", 70, "Glow", tint="#FFFFFF", alpha=0.4, pos=[0, 38, 0.5, 0], anchor=[0.5, 0.5], z=2,
                    turn=0),
                 {**ico("IconTrainBig", 44, name="ReadyIcon", pos=[0, 38, 0.5, 0], anchor=[0.5, 0.5]), "z": 3},
                 {**T("ReadyTitle", "UPGRADE READY!", 380, 22, font="display", align="left", pos=[0, 72, 0, 7]),
                  "z": 3},
                 {**T("UpgradeText", None, 380, 18, colour="#3A1A00", align="left",
                      samples=["Leave training, press F at the gear stand", "Leave training, tap the gear stand"],
                      pos=[0, 72, 0, 36]), "z": 3},
             ]}
    spec["children"] = [ready if k.get("name") == "UpgradePrompt" else k for k in kids]
    return spec


# =================================================================== Store

SECTION = {
    "featured": {"hex": "#FF5FA2", "card": ["#FF8CC6", "#C2307A"], "keyline": "#FFD1E8", "bg": "BgRays"},
    "passes": {"hex": "#A06BFF", "card": ["#8B5CF6", "#3F1F99"], "keyline": "#D3C2FF", "bg": "BgStars"},
    "boosts": {"hex": "#2FD08A", "card": ["#34D399", "#0F7A5C"], "keyline": "#B9F5DD", "bg": "BgSakura"},
    "yen": {"hex": "#FFB020", "card": ["#FFCB47", "#E07A12"], "keyline": "#FFEFB8", "bg": "BgClouds"},
}
CARD_W, CARD_H = 148, 238
STORE_W = 662


def section_header(name, text, hexc, w=634):
    """A pill tab with a line either side, in the section's colour."""
    tw = math.ceil(measure(text, 22)) + 44
    line_w = (w - tw - 24) // 2
    pill = {"type": "panel", "name": f"{name}Pill", "colour": [mp4.light(hexc, 0.25), hexc], "keyline": WHITE,
            "depth": 0, "corner": 18, "size": [0, tw, 0, 36], "pos": [0.5, 0, 0.5, 0], "anchor": [0.5, 0.5],
            "children": [gloss_band(18, 0.26),
                         {**T(f"{name}Text", text, tw - 20, 22, font="display", pos=[0.5, 0, 0.5, 0],
                              anchor=[0.5, 0.5]), "z": 3}]}
    line = {"type": "frame", "colour": [hexc, hexc], "outline": False, "corner": 2, "size": [0, line_w, 0, 4],
            "children": []}
    return frame(name, w, 40, [
        {**line, "name": "LineLeft", "pos": [0, 0, 0.5, 0], "anchor": [0, 0.5],
         "colour": [mp4.dark(hexc, 0.9), hexc]},
        pill,
        {**line, "name": "LineRight", "pos": [1, 0, 0.5, 0], "anchor": [1, 0.5]},
    ])


def card_bg(key, alpha=0.78, name="CardBg"):
    return {**ico(key, 100, name=name, pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5]), "size": [1, 0, 1, 0], "z": 0,
            "props": {"ScaleType": "Crop"}, "corner": 14, "overhang": True, "tint": "#FFFFFF", "alphaImg": alpha}


def _icon_tile(w, h, name="IconTile", y=12):
    return {"type": "frame", "name": name, "colour": ["#FFFFFF", "#FFFFFF"], "alpha": 0.82, "corner": 14,
            "keyline": "#FFFFFF", "size": [0, w, 0, h], "pos": [0.5, 0, 0, y], "anchor": [0.5, 0],
            "props": {"ClipsDescendants": True}, "children": [
                fx("FxRays", h + 70, "Rays", tint="#FFFFFF", alpha=0.25, pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5],
                   z=1),
                fx("FxGlow", h + 20, "Glow", tint="#FFFFFF", alpha=0.3, pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5], z=1,
                   turn=0)]}


def store_card(name, title_name, price_name, button_name, key, robux, section, owned=False, sticker=None,
               attrs=None, icon="IconStar"):
    s = SECTION[section]
    if owned:
        btn_ = v4.state_pill(button_name, price_name, ["OWNED"], "M", w=132)
    else:
        btn_ = vbtn(button_name, "confirm", "M", icon="IconRobux", samples=[str(robux), "999"],
                    text_name=price_name, w=132)
    btn_.update({"pos": [0.5, 0, 1, -10], "anchor": [0.5, 1]})
    kids = [
        card_bg(s["bg"]),
        sheen(corner=16, opacity=0.16, z=1),
        _icon_tile(128, 92),
        {**ico(icon, 70, name="CardIcon", pos=[0.5, 0, 0, 23], anchor=[0.5, 0]), "z": 3,
         "overhang": True},
        T(title_name, None, 136, 20, lines=2, font="display", samples=[key, "30 min Training"],
          pos=[0.5, 0, 0, 112], anchor=[0.5, 0]),
        btn_,
    ]
    st = ribbon_tag("Sticker", sticker or "BEST VALUE", colour="danger", text_name="StickerText",
                    samples=["BEST VALUE", "MOST VALUE", "GOOD VALUE", "LIMITED", "NEW!"], px=16, h=28, w=126)
    st["pos"] = [0.5, 0, 0, -12]
    if not sticker:
        st.update({"visible": False, "mockHide": True})
    kids.append(st)
    return {"type": "panel", "name": name, "colour": s["card"], "keyline": s["keyline"], "paintable": True,
            "depth": 0, "corner": 16, "size": [0, CARD_W, 0, CARD_H], "attrs": attrs or {}, "children": kids}


def pass_card_template(name="PassCardTemplate", key="DoubleTraining", robux=149, owned=False):
    return store_card(name, "PassName", "PassPrice", "PassBuyButton", v4.v1.PASS_NAMES[key][0], robux, "passes",
                      owned=owned, attrs={"PassKey": key}, icon=v4.v1.PASS_NAMES[key][1] + "Big")


def product_card_template(name="ProductCardTemplate", key="LuckyThrow25", robux=149, stick=None, section="boosts"):
    return store_card(name, "ProductName", "ProductPrice", "ProductBuyButton", v4.v1.PRODUCT_NAMES[key][0], robux,
                      section, sticker=stick, attrs={"ProductKey": key},
                      icon=v4.v1.PRODUCT_NAMES[key][1] + "Big")


def summon_banner():
    """The featured Summon Scroll: the rarest scroll hero ANIMATED in a WorldModel, with a UI-layer aura behind it
    (glow, two turning ray layers, a halo ring, rising flame sprites in the hero's rarity colour), sparkles and
    petals around the banner, and three price buttons; BEST VALUE sits centred on the x10 button's top edge."""
    widths = (124, 124, 152)
    b1 = vbtn2("SummonBuy1", "confirm", "L", "x1", "IconRobux", [str(SUMMON["SummonScroll1"]["Robux"]), "999"],
               w=widths[0])
    b3 = vbtn2("SummonBuy3", "confirm", "L", "x3", "IconRobux", [str(SUMMON["SummonScroll3"]["Robux"]), "999"],
               w=widths[1])
    b10 = vbtn2("SummonBuy10", "confirm", "L", "x10", "IconRobux", [str(SUMMON["SummonScroll10"]["Robux"]), "999"],
                w=widths[2])
    gap = 10
    row_w = sum(widths) + 2 * gap
    bw = 410
    buy_y = 442
    x10_centre = bw / 2 + row_w / 2 - widths[2] / 2
    flames = [fx("FxFlame", 70, f"Flame{i}", tint="#FFD45C", alpha=0.25, w=36,
                 pos=[0.5, -110 + i * 37, 1, -6], anchor=[0.5, 1], z=2) for i in range(7)]
    stage = {"type": "frame", "name": "StageWell", "colour": ["#2A0F66", "#12052E"], "corner": 18,
             "keyline": "#B79CFF", "size": [0, bw - 40, 0, 262], "pos": [0.5, 0, 0, 98], "anchor": [0.5, 0],
             "props": {"ClipsDescendants": True}, "children": [
                 fx("FxGlow", 280, "AuraGlow", tint="#FFB020", alpha=0.15, pos=[0.5, 0, 0.5, 10], anchor=[0.5, 0.5],
                    z=1, turn=0),
                 fx("FxRays", 380, "Rays", tint="#FFD45C", alpha=0.35, pos=[0.5, 0, 0.5, 10], anchor=[0.5, 0.5],
                    z=1, turn=10),
                 fx("FxSunburst", 300, "Rays2", tint="#FFE38A", alpha=0.7, pos=[0.5, 0, 0.5, 10], anchor=[0.5, 0.5],
                    z=1, turn=-6),
                 fx("FxRing", 230, "Halo", tint="#FFE38A", alpha=0.5, pos=[0.5, 0, 0.5, 10], anchor=[0.5, 0.5],
                    z=1, turn=0),
                 *flames,
                 {"type": "frame", "name": "SummonViewport", "transparent": True, "cls": "ViewportFrame",
                  "size": [1, -8, 1, -8], "pos": [0.5, 0, 0.5, 0], "anchor": [0.5, 0.5], "z": 3, "children": []},
                 twinkle("Sparkle1", 26, [0, 26, 0, 30], z=4), twinkle("Sparkle2", 20, [1, -28, 0, 44], z=4),
                 twinkle("Sparkle3", 24, [1, -36, 1, -34], z=4),
             ]}
    kids = [
        card_bg("BgStars", 0.6),
        sheen(corner=20, opacity=0.18, z=1),
        T("SummonTitle", "SUMMON SCROLL", bw - 40, 34, colour="buy", font="display", pos=[0.5, 0, 0, 20],
          anchor=[0.5, 0]),
        T("SummonSub", "6 exclusive heroes", bw - 40, 20, pos=[0.5, 0, 0, 64], anchor=[0.5, 0]),
        stage,
        {**v4.rchip("SummonHeroTag", "SummonHeroName", ["Illusion Overlord", "Elf Archmage"], "#1B1F4B", px=18,
                    h=30), "pos": [0.5, 0, 0, 338], "anchor": [0.5, 0], "z": 5, "overhang": True},
        vbtn("OddsButton", "info", "S", icon="IconInfo", text="SEE ODDS", opens="SummonOdds",
             pos=[0.5, 0, 0, 380], anchor=[0.5, 0], self_face=False),
        frame("BuyRow", row_w, 68, [b1, b3, b10], layout=row(gap, "center"), pos=[0.5, 0, 0, buy_y],
              anchor=[0.5, 0]),
        {**ribbon_tag("BestValueSticker", "BEST VALUE", colour="danger", text_name="BestValueText", px=16, h=28,
                      w=widths[2] - 12), "pos": [0, round(x10_centre), 0, buy_y - 20], "anchor": [0.5, 0]},
        T("SummonNote", "Odds are shown before you buy", bw - 40, 16, colour="soft", pos=[0.5, 0, 0, 516],
          anchor=[0.5, 0]),
        {**ribbon_tag("NewSticker", "NEW!", colour="danger", text_name="NewStickerText"),
         "pos": [1, -16, 0, 10], "anchor": [1, 0]},
        twinkle("Twinkle1", 34, [0, 16, 0, 26], z=6), twinkle("Twinkle2", 22, [1, -18, 0, 90], z=6),
        fx("FxPetal", 20, "Petal1", tint="#FFC2E0", pos=[0, 30, 0, 330], anchor=[0.5, 0.5], z=6),
        fx("FxPetal", 16, "Petal2", tint="#FFC2E0", pos=[1, -30, 0, 300], anchor=[0.5, 0.5], z=6),
    ]
    return {"type": "panel", "name": "SummonBanner", "colour": ["#9B6BFF", "#3F178F"], "keyline": "#D6C2FF",
            "depth": 0, "corner": 20, "size": [0, bw, 0, 540], "pos": [0, 0, 0, 0],
            "pattern": {"name": "dots", "colour": "#FFFFFF", "opacity": 0.08, "tile": 26}, "children": kids}


def featured_banner(name, title_name, title, desc_name, desc, button, button_name, price_name, price, colours,
                    keyline, bg, icon=None, viewport=None, sticker=None):
    btn_ = vbtn(button_name, "confirm", "M", icon="IconRobux", samples=[str(price), "OWNED"], text_name=price_name,
                pos=[1, -16, 0.5, 0], anchor=[1, 0.5])
    left = []
    if viewport:
        left = [fx("FxRays", 150, "Rays", tint="#FFFFFF", alpha=0.35, pos=[0, 64, 0.5, 0], anchor=[0.5, 0.5], z=1,
                   turn=10),
                {"type": "frame", "name": viewport, "transparent": True, "cls": "ViewportFrame",
                 "size": [0, 112, 0, 112], "pos": [0, 64, 0.5, 0], "anchor": [0.5, 0.5], "z": 2, "children": []}]
    else:
        left = [fx("FxRays", 150, "Rays", tint="#FFFFFF", alpha=0.3, pos=[0, 64, 0.5, 0], anchor=[0.5, 0.5], z=1,
                   turn=10),
                {**ico(icon, 80, name="BannerIcon", pos=[0, 64, 0.5, 0], anchor=[0.5, 0.5]), "z": 2}]
    kids = [card_bg(bg, 0.72), sheen(corner=18, opacity=0.25, z=1), *left,
            T(title_name, title, 300, 28, font="display", align="left", pos=[0, 128, 0, 18], z=2),
            T(desc_name, desc, 300, 18, lines=2, align="left", pos=[0, 128, 0, 54], z=2),
            btn_,
            twinkle("Twinkle1", 26, [0, 22, 0, 20], z=4), twinkle("Twinkle2", 18, [0, 110, 1, -18], z=4)]
    if sticker:
        kids.append({**ribbon_tag(f"{name}Sticker", sticker, colour="danger", text_name=f"{name}StickerText",
                                  px=16, h=28), "pos": [0, 64, 0, -12], "anchor": [0.5, 0]})
    return {"type": "panel", "name": name, "colour": colours, "keyline": keyline, "depth": 0, "corner": 18,
            "size": [0, 634, 0, 124], "pattern": {"name": "stripes", "colour": "#FFFFFF", "opacity": 0.12,
                                                  "tile": 96},
            "children": kids}


def grid_of(name, cards, rows_):
    gridl = {"type": "grid", "cell": [CARD_W, CARD_H], "gap": 14, "cols": 4}
    h = rows_ * CARD_H + (rows_ - 1) * 22
    return frame(name, 634, h, cards, layout=gridl, props={"AutomaticSize": "Y"})


def store():
    lim_hero = next(p for p in CFG["PremiumCharacters"] if p["Source"] == "Limited")
    starter = featured_banner("StarterPackBanner", "StarterTitle", "STARTER PACK", "StarterDesc",
                              "Blood Fiend hero + 5 Lucky Throws + 2x Yen", "starter", "StarterBuyButton",
                              "StarterPrice", PRODS["StarterPack"]["Robux"], ["#FFD45C", "#FF7A3D"], "#FFF1B8",
                              "BgRays", icon="IconGiftBig", sticker="LIMITED")
    starter["children"][-1]["name"] = "LimitedSticker"
    starter["children"][-1]["children"][0]["name"] = "LimitedStickerText"
    limited = featured_banner("LimitedHeroBanner", "LimitedHeroName", lim_hero["Name"].upper(), "LimitedHeroDesc",
                              "Limited hero. Earns 3x your best.", "hero", "LimitedHeroBuy", "LimitedHeroPrice",
                              PRODS["SakuraShogun"]["Robux"], ["#FF7AA8", "#B8215F"], "#FFD1E8", "BgSakura",
                              viewport="LimitedHeroViewport", sticker="NEW!")
    pass_keys = [p["Key"] for p in CFG["Monetization"]["Passes"]]
    pass_cards = [sample(pass_card_template(key=k, robux=PASSES[k]["Robux"], owned=(k == "DoubleYen")), i + 1)
                  for i, k in enumerate(pass_keys)]
    boost_keys = ["LuckyThrow1", "LuckyThrow5", "LuckyThrow25", "ServerLuck", "Train5m", "Train30m"]
    boost_stick = {"LuckyThrow25": "BEST VALUE", "LuckyThrow5": "GOOD VALUE"}
    boosts = [sample(product_card_template(key=k, robux=PRODS[k]["Robux"], stick=boost_stick.get(k)), i + 1)
              for i, k in enumerate(boost_keys)]
    yen_keys = ["YenPack15m", "YenPack2h", "YenPack12h"]
    yens = [sample(product_card_template(key=k, robux=PRODS[k]["Robux"], section="yen",
                                         stick="MOST VALUE" if k == "YenPack12h" else None), i + 1)
            for i, k in enumerate(yen_keys)]
    scroll = v4.mp3_vscroll("StoreScroll", STORE_W, 540, [
        section_header("FeaturedHeader", "FEATURED", SECTION["featured"]["hex"]),
        frame("FeaturedSpacer", 634, 6),
        starter,
        frame("FeaturedGap", 634, 6),
        limited,
        section_header("PassesHeader", "GAMEPASSES", SECTION["passes"]["hex"]),
        frame("PassesSpacer", 634, 6),
        grid_of("PassScroller", pass_cards, 2),
        section_header("BoostsHeader", "LUCK & BOOSTS", SECTION["boosts"]["hex"]),
        frame("BoostsSpacer", 634, 6),
        grid_of("ProductScroller", boosts, 2),
        section_header("YenHeader", "YEN PACKS", SECTION["yen"]["hex"]),
        frame("YenSpacer", 634, 6),
        grid_of("YenScroller", yens, 1),
    ], col(12, "start"), pad=10, pos=[1, 0, 0, 0], anchor=[1, 0])
    banner = summon_banner()
    gift = vbtn("GiftTarget", "info", "S", icon="IconGift", samples=["GIFT A FRIEND", "FOR: Builderman"],
                text_name="GiftTargetText", pos=[0, 18, 0, 16], z=4, overhang=True)
    body_w = banner["size"][1] + 14 + STORE_W
    return page("Store", v4.window("STORE", body_w, 540, [banner, scroll], colour="pink", icon="IconStoreBig",
                                   extra=[gift]))


# =================================================================== the set

SCREENS = [hud, v4.throw_meter, v4.reveal, v4.food_shop, v4.squad, v4.hero_index, store, v4.summon_odds, v4.offline,
           v4.rebirth, v4.daily, v4.playtime, v4.codes, v4.settings, training, hud_fx, confirm, nameplate,
           prompt_card, v4.leaderboard, v4.slot_sign]

TEMPLATES = [(f, o) for f, o in v4.TEMPLATES if o not in ("Store", "HUD")] + [
    (pass_card_template, "Store"), (product_card_template, "Store"), (toast_template, "HUD")]
