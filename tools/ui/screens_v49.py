"""UI v4.9 (owner: the purchase celebration is "lame"; reveal bought items like a Clash Royale card opening), on top
of screens_v48.

  Celebrate   same ScreenGui (DisplayOrder 60, Enabled=false), every v4.8 name kept, redesigned round ONE big card:
                Backdrop     the CelebrateBackdrop burst art, full screen (on the ScreenGui next to Scrim, so it covers
                             any aspect ratio), under everything
                TitleRibbon  the CelebrateBanner art (an ImageLabel) with CelebrateTitle on its band
                RevealCard   the tap-to-reveal card (240 x 336, centred at canvas y 300): RevealBack (CardBack) face
                             down; tap -> RevealFront with the CardFrame_<Tier> art over a tinted CardPortraitBg + the
                             hero viewport / item icon; each tap climbs a tier until the real one. TapHint, RevealCounter
                             and SkipButton (10-packs) sit outside the card.
                under it     ItemName, RarityChip, PerkList, CelebrateButton, CelebrateHint (as v4.8, re-spaced)
                SummonGrid   10 small cards using the same art (CardBack / CardFrameArt / CardBannerArt)
              Art keys (Icons): CardBack, CardFrame_<Tier>, CardBanner_<Tier>, CardFoil, CardWindowShade,
              CardPortraitBg, CelebrateBackdrop, CelebrateBanner (tools/ui/cards_art.py, assets/ui/ids_cards.json).

`celebrate(mode)`: "reveal" (the shipped tree; the mockup shows the card face up, Legendary, with name and perks),
"tap" (preview only: card face down, TAP!, counter, SKIP), "summon" (preview only: the 10-card grid).
`reveal_card_preview(tier)` composes a RevealCard preview PNG per tier for work/ui/mockups/cards/.
"""

from __future__ import annotations

import copy
from pathlib import Path

import mangapop as mp
import screens_v48 as v48
from mangapop import WHITE, col, frame, ico, ub
from mp4 import T, chip, ribbon_tag, vbtn
from screens import RARITY, page
from screens_v42 import fx, twinkle

ROOT = Path(__file__).resolve().parents[2]
CARDS_DIR = ROOT / "assets" / "ui" / "cards"
TIERS = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Premium"]
# CardPortraitBg tint per tier (ImageColor3); the same table is in tools/ui/cards_art.py (TINT)
PORTRAIT_TINT = {"Common": "#B9C3D3", "Uncommon": "#7EE8AE", "Rare": "#7DBBFF", "Epic": "#C69BFF",
                 "Legendary": "#FFCB6B", "Mythic": "#FFB0F2", "Secret": "#B0306A", "Premium": "#FF9CC8"}

# =================================================================== the mockup sees the card art; stretched images

_prev_render = ub.render


def _render(root, theme, palette, icons, size):
    icons = dict(icons)
    for p in CARDS_DIR.glob("*.png"):
        icons.setdefault(p.stem, p)
    return _prev_render(root, theme, palette, icons, size)


ub.render = _render
_prev_icon = ub._icon


def _hex3(c):
    if isinstance(c, dict):
        return tuple(int(round(v * 255)) for v in c["Color3"])
    c = c.lstrip("#")
    return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4))


def _icon(img, s, box, icons):
    """A Stretch image (card art) is drawn at its box, not as a square; ImageColor3 / ImageTransparency from props."""
    props = s.get("props") or {}
    if props.get("ScaleType") != "Stretch":
        return _prev_icon(img, s, box, icons)
    from PIL import Image
    p = icons.get(s["icon"])
    x, y, w, h = box
    if not p or w < 1 or h < 1:
        return
    im = Image.open(p).convert("RGBA").resize((max(1, int(w)), max(1, int(h))), Image.LANCZOS)
    if props.get("ImageColor3"):
        r_, g_, b_ = _hex3(props["ImageColor3"])
        ch = im.split()
        im = Image.merge("RGBA", [ch[0].point(lambda v: v * r_ // 255), ch[1].point(lambda v: v * g_ // 255),
                                  ch[2].point(lambda v: v * b_ // 255), ch[3]])
    keep = 1 - float(props.get("ImageTransparency", 0) or 0)
    if keep < 1:
        im.putalpha(im.getchannel("A").point(lambda v: int(v * keep)))
    img.alpha_composite(im, (int(x), int(y)))


ub._icon = _icon


def art(key, name, w, h, z=0, tint=None, transparency=None, **kw):
    """A card-art ImageLabel: IconKey = the art key, ScaleType Stretch (the box has the art's aspect)."""
    n = {**ico(key, 1, name=name), "size": [0, w, 0, h] if w is not None else [1, 0, 1, 0], "z": z,
         "shadow": False, "centre": False, "props": {"ScaleType": "Stretch"}, **kw}
    if tint:
        n["props"]["ImageColor3"] = {"Color3": [round(v / 255, 4) for v in _hex3(tint)]}
    if transparency is not None:
        n["props"]["ImageTransparency"] = transparency
    return n


# `ship`: properties forced onto the instance that carries the spec's NAME (not its ...Cell wrapper), applied after
# mockHide. WHY: a selfFace button/chip emits <Name>Cell > <Name>; `visible` / mockHide land on the Cell, which the
# client never toggles, so SkipButton would never show. Also lets the mockup draw the card face up while the tree
# ships face down (RevealBack shown, RevealFront hidden).
_prev_ti = ub.to_instances


def _to_instances(spec, theme, palette, counter=None):
    made = _prev_ti(spec, theme, palette, counter)
    ship = spec.get("ship") if isinstance(spec, dict) else None
    if made and ship:
        top = made[0]
        stack = [top]
        while stack:
            n = stack.pop()
            if n.get("name") == spec.get("name"):
                n.setdefault("properties", {}).update(ship)
                break
            stack.extend(n.get("children", []))
        if top.get("name") != spec.get("name") and "Visible" in ship:
            top.setdefault("properties", {}).pop("Visible", None)     # the wrapper stays visible
    return made


ub.to_instances = _to_instances


# =================================================================== geometry (1280 x 720 canvas)

CARD_X, CARD_Y = 0, 300            # RevealCard centre (canvas x centre + offset, y)
CARD_W, CARD_H = 240, 336          # art 512 x 716 at k = 240 / 512
K = CARD_W / 512
CARD_TOP, CARD_BOT = CARD_Y - CARD_H // 2, CARD_Y + CARD_H // 2      # 132, 468

BAN_W, BAN_H = 500, 99             # CelebrateBanner art 760 x 150
SUB_Y = 104
NAME_Y = 474
CHIP_Y = 510
PERK_W, PERK_H, PERK_GAP = 540, 24, 8
PERK_Y = 546
BTN_Y = 642
HINT_Y = 700

SC_W, SC_H, SC_GAP = 156, 218, 12  # summon cards (the art's aspect)
GRID_W, GRID_H = 5 * SC_W + 4 * SC_GAP, 2 * SC_H + SC_GAP
GRID_Y = 350


def _win(k):
    """The portrait window in a card of scale k: art px (30, 30)..(482, 440) -> (x, y, w, h)."""
    return round(30 * k), round(30 * k), round(452 * k), round(410 * k)


# =================================================================== pieces

def _backdrop():
    n = art("CelebrateBackdrop", "Backdrop", None, None, z=-1)
    n["props"]["ScaleType"] = "Crop"
    n.update({"screenLevel": True, "overhang": True})
    return n


def _title():
    band_cy = round(BAN_H * 0.54)
    title = {**T("CelebrateTitle", None, round(BAN_W * 0.66), 26, font="display",
                 samples=["PURCHASE COMPLETE!", "PASS UNLOCKED!", "SUMMON!", "THANK YOU!"],
                 pos=[0.5, 0, 0, band_cy], anchor=[0.5, 0.5]), "z": 8}
    rib = art("CelebrateBanner", "TitleRibbon", BAN_W, BAN_H, z=6, pos=[0.5, 0, 0, 0], anchor=[0.5, 0],
              children=[title])
    rib["centre"] = True
    return rib


def _burst():
    b = v48._burst()
    b["pos"] = [0.5, 0, 0, CARD_Y]
    return b


def _reveal_card(tier="Legendary", face_up=True, name_samples=None):
    wx, wy, ww, wh = _win(K)
    cx_win, cy_win = wx + ww // 2, wy + wh // 2
    ban_w, ban_h = round(420 * K), round(96 * K)
    tier_text = {**T("RevealTierText", None, round(ban_w * 0.7), 18, font="display",
                     samples=["LEGENDARY", "UNCOMMON", "PREMIUM"], pos=[0.5, 0, 0, round(ban_h * 0.44)],
                     anchor=[0.5, 0.5]), "z": 10}
    front_kids = [
        art("CardPortraitBg", "RevealPortraitBg", ww, wh, z=4, pos=[0, wx, 0, wy], tint=PORTRAIT_TINT[tier]),
        {"type": "frame", "name": "RevealViewport", "transparent": True, "cls": "ViewportFrame",
         "size": [0, ww, 0, wh], "pos": [0, wx, 0, wy], "z": 5, "children": [], "overhang": True},
        {**ico("IconLuckyThrowBig", 150, name="RevealIcon", pos=[0, cx_win, 0, cy_win], anchor=[0.5, 0.5]),
         "z": 6, "overhang": True, "centre": False, "visible": False, "mockHide": True},
        art("CardWindowShade", "RevealShade", None, None, z=7, overhang=True),
        art(f"CardFrame_{tier}", "RevealFrameArt", None, None, z=8, overhang=True),
        art(f"CardBanner_{tier}", "RevealBannerArt", ban_w, ban_h, z=9, pos=[0.5, 0, 0, round(650 * K)],
            anchor=[0.5, 0.5], overhang=True, children=[tier_text]),
        {**T("RevealName", None, round(410 * K), 18, font="display", lines=2,
             samples=name_samples or ["First Sun Swordsman", "25 Lucky Throws", "Copy Ninja"],
             pos=[0.5, 0, 0, round(535 * K)], anchor=[0.5, 0.5]), "z": 9},
        art("CardFoil", "RevealFoil", None, None, z=11, transparency=1, overhang=True),
        {**ribbon_tag("RevealNew", "NEW!", colour="danger", text_name="RevealNewText", px=16, h=26, w=72),
         "pos": [1, -26, 0, -8], "anchor": [0.5, 0], "z": 12},
    ]
    front = {**frame("RevealFront", None, None, front_kids, z=3), "overhang": True}
    back = art("CardBack", "RevealBack", None, None, z=3, overhang=True)
    # ships face DOWN (back shown, front hidden) whatever the mockup draws
    if face_up:
        back.update({"mockHide": True, "ship": {"Visible": True}})
        front["ship"] = {"Visible": False}
    else:
        front.update({"mockHide": True, "ship": {"Visible": False}})
    # a soft drop shadow: the white FxGlow sprite stretched past the card, tinted ink
    shadow = art("FxGlow", "RevealShadow", CARD_W + 90, CARD_H + 110, z=2, pos=[0.5, 6, 0.5, 16], anchor=[0.5, 0.5],
            tint="#05061A", transparency=0.15, overhang=True)
    kids = [
        fx("FxRays", 700, "RevealRays", tint=TIER_GLOW[tier], alpha=0.35, pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5],
           z=0, turn=10),
        fx("FxGlow", 560, "RevealGlow", tint=TIER_GLOW[tier], alpha=0.15, pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5],
           z=1),
        shadow, back, front,
    ]
    return {**frame("RevealCard", CARD_W, CARD_H, kids, pos=[0.5, CARD_X, 0, CARD_Y], anchor=[0.5, 0.5], z=5,
                    visible=False, attrs={"CardArtScale": round(K, 5)}), "overhang": True}


TIER_GLOW = {"Common": "#DDE3EE", "Uncommon": "#7CF0B0", "Rare": "#7FC4FF", "Epic": "#D6A8FF",
             "Legendary": "#FFD86A", "Mythic": "#FFB6F5", "Secret": "#FF4D7A", "Premium": "#FF9CC8"}


def _tap_bits(show):
    tap = {**T("TapHint", "TAP!", 160, 48, font="display", colour="gold", pos=[0.5, 0, 0, CARD_BOT + 10],
               anchor=[0.5, 0]), "z": 9, "visible": False, "attrs": {"Pulse": True}}
    # a TextLabel (the client writes "3 / 10" into it), beside the card's top-right corner: the band above the card
    # holds the sub line
    counter = {**T("RevealCounter", None, 90, 24, font="display", colour="onDark", samples=["1 / 10", "10 / 10"],
                   align="left", pos=[0.5, CARD_W // 2 + 20, 0, CARD_TOP + 6], anchor=[0, 0]), "z": 9,
               "centre": False}
    skip = {**vbtn("SkipButton", "slate", "S", text="SKIP", icon=None, minw=120,
                   pos=[0.5, CARD_W // 2 + 20, 0, CARD_BOT], anchor=[0, 1]), "z": 9}
    out = [tap, counter, skip]
    for n in out:
        n["visible"] = False
        n["ship"] = {"Visible": False}
        if not show:
            n["mockHide"] = True
    return out


def _perk(i, samples):
    return {"type": "panel", "name": f"Perk{i}", "colour": ["#353C9A", "#20256A"], "keyline": "#8D96F0",
            "depth": 0, "corner": PERK_H // 2, "size": [0, PERK_W, 0, PERK_H], "children": [
                {**ico("IconTick", 20, name="PerkIcon", pos=[0, 14, 0.5, 0], anchor=[0, 0.5]), "centre": False},
                T("PerkText", None, PERK_W - 64, 16, font="display", align="left", samples=samples,
                  pos=[0, 44, 0.5, 0], anchor=[0, 0.5])]}


def _single(show):
    """The v4.8 single-item pieces: the stage / icon / disc stay (hidden: the card carries the item now); name, chip
    and perks sit under the card."""
    stage = {"type": "frame", "name": "ItemStage", "transparent": True, "cls": "ViewportFrame",
             "size": [0, 280, 0, 280], "pos": [0.5, 0, 0, CARD_Y], "anchor": [0.5, 0.5], "z": 4,
             "children": [], "overhang": True, "visible": False, "mockHide": True}
    icon = {**ico("IconLuckyThrowBig", 210, name="ItemIcon", pos=[0.5, 0, 0, CARD_Y], anchor=[0.5, 0.5]), "z": 4,
            "overhang": True, "visible": False, "mockHide": True}
    disc = {**fx("FxGlow", 64, "StageDisc", tint="#FFE38A", alpha=0.15, w=340,
                 pos=[0.5, 0, 0, CARD_BOT - 10], anchor=[0.5, 0.5], z=3), "visible": False, "mockHide": True}
    name = {**T("ItemName", None, 700, 26, font="display",
                samples=["First Sun Swordsman", "25 Lucky Throws", "VIP"], pos=[0.5, 0, 0, NAME_Y],
                anchor=[0.5, 0]), "z": 6, "visible": False}
    rarity = {**chip("RarityChip", "RarityText", ["LEGENDARY", "MYTHIC", "PASS"], RARITY["Legendary"], px=18,
                     h=28, keyline=WHITE), "pos": [0.5, 0, 0, CHIP_Y], "anchor": [0.5, 0], "z": 6}
    perks = {**frame("PerkList", PERK_W, 3 * PERK_H + 2 * PERK_GAP, [
        _perk(1, ["x12 luck on 25 throws", "Every hero earns double yen, forever"]),
        _perk(2, ["Every hero earns double yen, forever", "+2 hero slots"]),
        _perk(3, ["+2 hero slots", "x12 luck on 25 throws"]),
    ], layout=col(PERK_GAP, "start"), pos=[0.5, 0, 0, PERK_Y], anchor=[0.5, 0]), "z": 6, "visible": False}
    out = [disc, icon, stage, name, rarity, perks]
    if not show:
        for n in out[3:]:
            n["mockHide"] = True
    return out


def _summon_card(i, tier="Legendary"):
    k = SC_W / 512
    wx, wy, ww, wh = _win(k)
    ban_w, ban_h = round(420 * k), round(96 * k)
    back = art("CardBack", "CardBack", None, None, z=2, overhang=True)
    rarity = {**frame("CardRarity", round(ban_w * 0.74), round(ban_h * 0.68), [
        {**T("CardRarityText", None, round(ban_w * 0.74), 16, font="display",
             samples=["LEGENDARY", "UNCOMMON", "SECRET"], pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5]), "z": 11}],
        pos=[0.5, 0, 0, round(ban_h * 0.44)], anchor=[0.5, 0.5], z=10), "overhang": True}
    front_kids = [
        fx("FxGlow", 200, "CardGlow", tint="#FFFFFF", alpha=0.4, pos=[0.5, 0, 0, wy + wh // 2], anchor=[0.5, 0.5],
           z=1),
        art("CardPortraitBg", "CardPortraitBg", ww, wh, z=3, pos=[0, wx, 0, wy], tint=PORTRAIT_TINT[tier]),
        {"type": "frame", "name": "CardViewport", "transparent": True, "cls": "ViewportFrame",
         "size": [0, ww, 0, wh], "pos": [0, wx, 0, wy], "z": 4, "children": [], "overhang": True},
        art("CardWindowShade", "CardShade", None, None, z=5, overhang=True),
        art(f"CardFrame_{tier}", "CardFrameArt", None, None, z=6, overhang=True),
        {**T("CardName", None, round(420 * k), 16, font="display", lines=2,
             samples=["First Sun Swordsman", "Copy Ninja"], pos=[0.5, 0, 0, round(535 * k)], anchor=[0.5, 0.5]),
         "z": 8},
        art(f"CardBanner_{tier}", "CardBannerArt", ban_w, ban_h, z=9, pos=[0.5, 0, 0, round(650 * k)],
            anchor=[0.5, 0.5], overhang=True, children=[rarity]),
        {**ribbon_tag("CardNew", "NEW!", colour="danger", text_name="CardNewText", px=16, h=26, w=72),
         "pos": [1, -24, 0, -10], "anchor": [0.5, 0], "z": 12},
    ]
    front = {**frame("CardFront", None, None, front_kids, z=3), "overhang": True}
    return frame(f"SummonCard{i}", SC_W, SC_H, [back, front], visible=False, attrs={"CardIndex": i})


def _summon_grid(show):
    grid = frame("SummonGrid", GRID_W, GRID_H, [_summon_card(i, TIERS[(i * 3) % 7]) for i in range(1, 11)],
                 layout={"type": "grid", "cell": [SC_W, SC_H], "gap": SC_GAP, "cols": 5,
                         "hAlign": "center", "vAlign": "center", "maxCells": 5},
                 pos=[0.5, 0, 0, GRID_Y], anchor=[0.5, 0.5], z=6, visible=False)
    if not show:
        grid["mockHide"] = True
    return grid


def celebrate(mode="reveal"):
    scrim = {"type": "frame", "name": "Scrim", "colour": [mp.INK, mp.INK], "alpha": 0.4, "outline": False,
             "z": -2, "size": [1, 0, 1, 0], "children": [], "screenLevel": True, "overhang": True}
    sub = {**T("CelebrateSub", None, 640, 16, font="display", colour="gold",
               samples=["You unlocked 2x Yen forever", "10 heroes joined your squad"], pos=[0.5, 0, 0, SUB_Y],
               anchor=[0.5, 0]), "z": 6}
    card = _reveal_card("Legendary", face_up=(mode != "tap"))
    if mode == "summon":
        card["mockHide"] = True
    button = {**vbtn("CelebrateButton", "confirm", "M", icon="IconTick", text="AWESOME!", w=280,
                     pos=[0.5, 0, 0, BTN_Y], anchor=[0.5, 0]), "z": 7}
    hint = {**T("CelebrateHint", "tap to continue", 300, 16, colour="soft", pos=[0.5, 0, 0, HINT_Y],
                anchor=[0.5, 0]), "z": 7}
    if mode == "tap":
        button["mockHide"] = True
    confetti = {**frame("ConfettiLayer", None, None, [], z=40), "overhang": True}
    kids = [scrim, _backdrop(), _burst(), _title(), sub, *_single(mode == "reveal"), card,
            *_tap_bits(mode == "tap"), _summon_grid(mode == "summon"), button, hint, confetti]
    return page("Celebrate", kids, kind="hud", enabled=False, displayOrder=60)


# =================================================================== previews (not shipped)

def reveal_card_preview(tier):
    """A 1280 x 720-free spec holding only the RevealCard (face up, the given tier), for a per-tier preview PNG."""
    card = _reveal_card(tier, face_up=True)
    tt = _find(card, "RevealTierText")
    tt["samples"] = [tier.upper()]
    for c in card["children"]:
        if c["name"] in ("RevealRays", "RevealGlow"):
            c["alphaImg"] = 0.25
    card["pos"], card["anchor"] = [0.5, 0, 0.5, 0], [0.5, 0.5]
    bg = art("CelebrateBackdrop", "Backdrop", None, None, z=-1)
    bg["props"]["ScaleType"] = "Crop"
    return {"name": f"RevealCard_{tier}", "theme": "theme.json", "resolution": [520, 520], "kind": "world",
            "children": [bg, copy.deepcopy(card)]}


def _find(node, name):
    for c in node.get("children") or []:
        if c.get("name") == name:
            return c
        f = _find(c, name)
        if f:
            return f
    return None


# =================================================================== the set

SCREENS = [celebrate if fn is v48.celebrate else fn for fn in v48.SCREENS]
TEMPLATES = list(v48.TEMPLATES)
