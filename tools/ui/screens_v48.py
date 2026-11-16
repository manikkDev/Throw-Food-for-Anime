"""UI v4.8 (owner's request): the Robux purchase celebration, on top of screens_v47.

  Celebrate   ONE new ScreenGui (DisplayOrder 60: above every page, the Store, Confirm and the ToastLayer at 40),
              shipped Enabled=false. Two modes share one stage:
                single item  a hero model (ItemStage) or a pass / product icon (ItemIcon) on a glowing floor disc,
                             the item name big, a rarity / PASS chip, up to three perk rows;
                summon       SummonGrid: up to 10 face-down cards (5 x 2, centred: 1 and 3 cards sit centred too),
                             each flips from CardBack to a rarity-coloured CardFront.
              Both: a dim scrim, a turning burst (back rays, front sunburst, glow, halo, twinkles), a big striped
              gold-to-coral title ribbon, a sub line, the green AWESOME! button, a hint, and a top-most confetti
              layer the client fills from ConfettiTemplate / ConfettiStarTemplate.

The mockup draws the single-item mode; the summon grid ships hidden (mockHide). `celebrate(mode="summon")` builds the
summon variant for a preview / verify run (it is not a shipped screen).
"""

from __future__ import annotations

import mangapop as mp
import screens_v47 as v47
from mangapop import WHITE, col, frame, ico, row, ub
from mp4 import T, chip, ribbon_tag, vbtn
from screens import RARITY, page
from screens_v42 import fx, gloss_band, twinkle

# =================================================================== grid layouts that centre their cells

_prev_layout = ub._layout_instance


def _layout_instance(lay):
    """A grid with `hAlign` / `vAlign` / `maxCells`: UIGridLayout centred, so 1 or 3 visible cards sit centred
    (Roblox's grid skips invisible cells). Everything else as before."""
    inst = _prev_layout(lay)
    if lay.get("type") == "grid":
        props = inst.setdefault("properties", {})
        if lay.get("hAlign"):
            props["HorizontalAlignment"] = {"start": "Left", "center": "Center", "end": "Right"}[lay["hAlign"]]
        if lay.get("vAlign"):
            props["VerticalAlignment"] = {"start": "Top", "center": "Center", "end": "Bottom"}[lay["vAlign"]]
        if lay.get("maxCells"):
            props["FillDirectionMaxCells"] = int(lay["maxCells"])
    return inst


ub._layout_instance = _layout_instance

# =================================================================== Celebrate: geometry (1280 x 720 canvas)

STAGE_Y = 282                    # the burst / single item centre
RIB_W, RIB_H, RIB_Y = 700, 80, 16
SUB_Y = RIB_Y + RIB_H + 8        # 104
STAGE_SIDE, ICON_SIDE = 280, 210
NAME_Y = 420
CHIP_Y = 474
PERK_W, PERK_H, PERK_GAP = 560, 28, 8
PERK_Y = 512
BTN_Y = 624
HINT_Y = BTN_Y + 68 + 6
CARD_W, CARD_H, CARD_GAP = 148, 196, 14
GRID_W, GRID_H = 5 * CARD_W + 4 * CARD_GAP, 2 * CARD_H + CARD_GAP     # 796 x 406
GRID_Y = 344                     # centre: the grid spans 141..547, clear of the sub line and the button

GOLD_CORAL = ["#FFD84A", "#FF5A5F"]
PURPLE = ["#9B6BFF", "#3F178F"]


def _burst():
    c = [0.5, 0, 0.5, 0]
    a = [0.5, 0.5]
    side = 560          # the holder; the 780 back rays overhang it (decoration, never clipped)
    h = side / 2

    def tw(i, s, dx, dy):
        return twinkle(f"Twinkle{i}", s, [0, round(h + dx), 0, round(h + dy)], z=5)
    return frame("Burst", side, side, [
        fx("FxRays", 780, "RaysBack", tint="#FFD45C", alpha=0.3, pos=c, anchor=a, z=1, turn=8),
        fx("FxSunburst", 560, "RaysFront", tint="#FFFFFF", alpha=0.55, pos=c, anchor=a, z=2, turn=-12),
        fx("FxGlow", 520, "Glow", tint="#FFE38A", alpha=0.1, pos=c, anchor=a, z=3, turn=0),
        fx("FxRing", 330, "Halo", tint="#FFFFFF", alpha=0.35, pos=c, anchor=a, z=4, turn=0),
        tw(1, 44, -250, -60), tw(2, 30, 236, -96), tw(3, 36, 270, 70),
        tw(4, 26, -214, 112), tw(5, 22, -150, -150), tw(6, 28, 170, 150),
    ], pos=[0.5, 0, 0, STAGE_Y], anchor=[0.5, 0.5], z=1, overhang=True)


def _title_ribbon():
    tails = [{"type": "panel", "name": f"RibbonTail{s}", "colour": ["#E0306A", "#8E1546"], "keyline": WHITE,
              "depth": 0, "corner": 14, "size": [0, 96, 0, 58], "pos": [0.5, dx, 0, RIB_Y + 30], "anchor": [ax, 0],
              "z": 5, "overhang": True, "centre": False,
              "pattern": {"name": "stripes", "colour": "#FFFFFF", "opacity": 0.12, "tile": 48}, "children": []}
             for s, ax, dx in (("L", 0, -RIB_W // 2 - 54), ("R", 1, RIB_W // 2 + 54))]
    plate = {"type": "panel", "name": "TitleRibbon", "colour": GOLD_CORAL, "keyline": WHITE,
             "depth": 0, "corner": 26, "size": [0, RIB_W, 0, RIB_H], "pos": [0.5, 0, 0, RIB_Y], "anchor": [0.5, 0],
             "z": 6, "pattern": {"name": "stripes", "colour": "#FFFFFF", "opacity": 0.16, "tile": 64},
             "children": [
                 gloss_band(26, 0.32),
                 {**T("CelebrateTitle", None, RIB_W - 80, 44, font="display",
                      samples=["PURCHASE COMPLETE!", "PASS UNLOCKED!", "SUMMON!", "THANK YOU!"],
                      pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5]), "z": 8},
                 {**mp4_sparkle("RibbonStarL", 34, [0, 26, 0.5, 0]), "z": 8},
                 {**mp4_sparkle("RibbonStarR", 34, [1, -26, 0.5, 0]), "z": 8},
             ]}
    return [*tails, plate]


def mp4_sparkle(name, side, pos):
    n = ico("IconStar", side, name=name, pos=pos, anchor=[0.5, 0.5])
    n["overhang"] = True
    n["centre"] = False
    return n


def _perk(i, samples):
    return {"type": "panel", "name": f"Perk{i}", "colour": ["#353C9A", "#20256A"], "keyline": "#8D96F0",
            "depth": 0, "corner": PERK_H // 2, "size": [0, PERK_W, 0, PERK_H], "children": [
                {**ico("IconTick", 22, name="PerkIcon", pos=[0, 14, 0.5, 0], anchor=[0, 0.5]), "centre": False},
                T("PerkText", None, PERK_W - 64, 18, font="display", align="left", samples=samples,
                  pos=[0, 46, 0.5, 0], anchor=[0, 0.5])]}


def _single():
    stage = {"type": "frame", "name": "ItemStage", "transparent": True, "cls": "ViewportFrame",
             "size": [0, STAGE_SIDE, 0, STAGE_SIDE], "pos": [0.5, 0, 0, STAGE_Y], "anchor": [0.5, 0.5], "z": 5,
             "children": [], "overhang": True, "visible": False}
    icon = {**ico("IconLuckyThrowBig", ICON_SIDE, name="ItemIcon", pos=[0.5, 0, 0, STAGE_Y - 6],
                  anchor=[0.5, 0.5]), "z": 4, "overhang": True, "visible": False}
    disc = {**fx("FxGlow", 64, "StageDisc", tint="#FFE38A", alpha=0.15, w=340,
                 pos=[0.5, 0, 0, STAGE_Y + 112], anchor=[0.5, 0.5], z=3), "visible": False}
    name = {**T("ItemName", None, 820, 40, font="display",
                samples=["First Sun Swordsman", "25 Lucky Throws", "VIP"], pos=[0.5, 0, 0, NAME_Y],
                anchor=[0.5, 0]), "z": 6, "visible": False}
    rarity = {**chip("RarityChip", "RarityText", ["LEGENDARY", "MYTHIC", "PASS"], RARITY["Legendary"], px=20,
                     h=32, keyline=WHITE),
              "pos": [0.5, 0, 0, CHIP_Y], "anchor": [0.5, 0], "z": 6}  # a selfFace chip: Visible would land on
    # its RarityChipCell wrapper, which the client never toggles; the client hides RarityChip itself at reset
    perks = {**frame("PerkList", PERK_W, 3 * PERK_H + 2 * PERK_GAP, [
        _perk(1, ["x12 luck on 25 throws", "Every hero earns double yen, forever"]),
        _perk(2, ["Every hero earns double yen, forever", "+2 hero slots"]),
        _perk(3, ["+2 hero slots", "x12 luck on 25 throws"]),
    ], layout=col(PERK_GAP, "start"), pos=[0.5, 0, 0, PERK_Y], anchor=[0.5, 0]), "z": 6, "visible": False}
    return [disc, icon, stage, name, rarity, perks]


def _summon_card(i):
    rh = RARITY["Legendary"]
    back = {"type": "panel", "name": "CardBack", "colour": PURPLE, "keyline": WHITE, "keepKeyline": True,
            "depth": 0, "corner": 18, "size": [1, 0, 1, 0], "pos": [0.5, 0, 0.5, 0], "anchor": [0.5, 0.5], "z": 2,
            "pattern": {"name": "dots", "colour": "#FFFFFF", "opacity": 0.10, "tile": 22}, "children": [
                gloss_band(18, 0.22),
                fx("FxGlow", 140, "BackGlow", tint="#E9D5FF", alpha=0.35, pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5],
                   z=2),
                {**ico("IconScrollBig", 92, name="BackIcon", pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5]), "z": 3},
            ]}
    front = {"type": "panel", "name": "CardFront", "colour": rh, "paintable": True, "selfFace": True,
             "keyline": WHITE, "depth": 0, "corner": 18, "size": [1, 0, 1, 0], "pos": [0.5, 0, 0.5, 0],
             "anchor": [0.5, 0.5], "z": 3,  # no Visible=false: it would land on CardFrontCell (client hides CardFront)
             "pattern": {"name": "stripes", "colour": "#FFFFFF", "opacity": 0.10, "tile": 48}, "children": [
                 gloss_band(18, 0.24),
                 fx("FxGlow", 150, "CardGlow", tint="#FFFFFF", alpha=0.3, pos=[0.5, 0, 0, 58], anchor=[0.5, 0.5],
                    z=2),
                 {"type": "frame", "name": "CardViewport", "transparent": True, "cls": "ViewportFrame",
                  "size": [0, 128, 0, 96], "pos": [0.5, 0, 0, 10], "anchor": [0.5, 0], "z": 3, "children": [],
                  "overhang": True},
                 {**T("CardName", None, 134, 16, font="display", samples=["First Sun Swordsman", "Copy Ninja"],
                      lines=2, pos=[0.5, 0, 0, 110], anchor=[0.5, 0]), "z": 4},
                 {**chip("CardRarity", "CardRarityText", ["LEGENDARY", "MYTHIC", "SECRET"], "#1B1F4B", px=16, h=26,
                         keyline=WHITE), "pos": [0.5, 0, 1, -8], "anchor": [0.5, 1], "z": 4},
                 {**ribbon_tag("CardNew", "NEW!", colour="danger", text_name="CardNewText", px=16, h=26, w=72),
                  "pos": [1, -30, 0, -12], "anchor": [0.5, 0], "z": 6},
             ]}
    return frame(f"SummonCard{i}", CARD_W, CARD_H, [back, front], visible=False, attrs={"CardIndex": i})


def _summon_grid(show):
    grid = frame("SummonGrid", GRID_W, GRID_H, [_summon_card(i) for i in range(1, 11)],
                 layout={"type": "grid", "cell": [CARD_W, CARD_H], "gap": CARD_GAP, "cols": 5,
                         "hAlign": "center", "vAlign": "center", "maxCells": 5},
                 pos=[0.5, 0, 0, GRID_Y], anchor=[0.5, 0.5], z=6, visible=False)
    if not show:
        grid["mockHide"] = True
    return grid


def celebrate(mode="single"):
    scrim = {"type": "frame", "name": "Scrim", "colour": [mp.INK, mp.INK], "alpha": 0.4, "outline": False,
             "z": -2, "size": [1, 0, 1, 0], "children": [], "screenLevel": True, "overhang": True}
    sub = {**T("CelebrateSub", None, 820, 24, font="display", colour="gold",
               samples=["You unlocked 2x Yen forever", "10 heroes joined your squad"], pos=[0.5, 0, 0, SUB_Y],
               anchor=[0.5, 0]), "z": 6}
    single = _single()
    if mode == "summon":
        single = [{**n, "mockHide": True} for n in single]
    button = {**vbtn("CelebrateButton", "confirm", "L", icon="IconTick", text="AWESOME!", w=300,
                     pos=[0.5, 0, 0, BTN_Y], anchor=[0.5, 0]), "z": 7}
    hint = {**T("CelebrateHint", "tap to continue", 300, 16, colour="soft", pos=[0.5, 0, 0, HINT_Y],
                anchor=[0.5, 0]), "z": 7}
    confetti = {**frame("ConfettiLayer", None, None, [], z=40), "overhang": True}
    kids = [scrim, _burst(), *_title_ribbon(), sub, *single, _summon_grid(mode == "summon"), button, hint,
            confetti]
    return page("Celebrate", kids, kind="hud", enabled=False, displayOrder=60)


# =================================================================== templates

def confetti_template():
    return {"type": "frame", "name": "ConfettiTemplate", "colour": ["#FFFFFF", "#FFFFFF"], "outline": False,
            "corner": 2, "size": [0, 10, 0, 18], "children": []}


def confetti_star_template():
    n = fx("FxTwinkle", 22, "ConfettiStarTemplate", tint="#FFFFFF")
    n.pop("overhang", None)
    return n


# =================================================================== the set

SCREENS = [*v47.SCREENS, celebrate]
TEMPLATES = [*v47.TEMPLATES, (confetti_template, "Celebrate"), (confetti_star_template, "Celebrate")]
