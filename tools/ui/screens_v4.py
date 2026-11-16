"""UI v4: the owner's review (thin strokes, readable type, centred text, no stretching, premium cards).

Every screen is authored here at 1280x720 with the mp4 system. Instance NAMES the client binds are kept
(design/ui/BINDINGS.md); what moved or is new is in design/ui/CHANGES-v4.md.
"""

from __future__ import annotations

import copy
import math

import mp4  # noqa: F401  (installs the v4 renderer/emitter additions)
import mangapop as mp
import screens as v1
import screens_v2 as v2
import screens_v3 as v3
from mangapop import WHITE, frame, ico, row, col, sample
from mp4 import (GOLD, PANEL_EDGE, RAINBOW, T, auto_label, card, chip, est, measure, pill_auto, ribbon_tag,
                 round_x, sheen, sparkle, state_pill, sunburst, track, vbtn, vbtn2, window)
from screens import CFG, LONG_NUM, MUT_HEX, RARITY, page
from screens_v2 import find

FLAVOR_TILE = v3.FLAVOR_TILE
CREAM_CHIP = "#F1E3C2"
FOODS = v1.FOODS
MON = CFG["Monetization"]
PASSES = {p["Key"]: p for p in MON["Passes"]}
PRODS = {p["Key"]: p for p in MON["Products"]}
SUMMON = {p["Key"]: p for p in MON["Products"] if p["Kind"] == "summon"}
ODDS_HEX = ["#4ADE80", "#38BDF8", "#A855F7", "#FF4FA3", "#FFB020", "#FB3B6B"]
STORE_CARD_H = 236
ODDS_TIER = ["COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY", "MYTHIC"]


def big(k):
    return k + "Big"


def chip_w(samples, px=18):
    return math.ceil(max(measure(s, px) for s in samples)) + 22


def rchip(name, text_name, samples, colour, px=18, h=28, **kw):
    """A chip sized by the REAL text width (the label still shrinks if a longer string arrives)."""
    return chip(name, text_name, samples, colour, px=px, h=h, w=chip_w(samples, px), **kw)


# =================================================================== FoodShop

def stat_pill(name, icon, text_name, samples, colour):
    """A food stat: [icon][POWER x1.5] as ONE tight group centred in a pill that grows with its text."""
    lab = auto_label(text_name, samples, 18, colour=colour)
    w = 22 + 6 + lab["size"][1] + 24
    return {"type": "frame", "name": name, "colour": [CREAM_CHIP, CREAM_CHIP], "paint": CREAM_CHIP, "corner": 15,
            "keyline": "#D8C69C", "keepKeyline": True, "size": [0, w, 0, 30], "autoW": 12,
            "layout": row(6, "center"), "children": [ico(icon, 22, name=icon.replace("Icon", "") + "Icon"), lab]}


FOOD_CARD_H = 380


def food_card_template(name="FoodCardTemplate", food=FOODS[2], state="afford", nxt=False, dim=False):
    """v4.1: the compact card. Art tile with the craving pill riding its bottom edge, name, two tight stat pills,
    and the price button with its yen icon + price centred as one group."""
    flav = food["Flavor"]
    cost = v1.short(food["Cost"])
    if state == "equipped":
        buy = state_pill("BuyButton", "PriceText", ["EQUIPPED"], "M", w=196)
    elif state == "equip":
        buy = vbtn("BuyButton", "info", "M", icon="IconTick", samples=["EQUIP", LONG_NUM], text_name="PriceText",
                   w=196)
    elif state == "afford":
        buy = vbtn("BuyButton", "confirm", "M", icon="IconYen", samples=[cost, LONG_NUM], text_name="PriceText",
                   w=196)
    else:
        buy = vbtn("BuyButton", "slate", "M", icon="IconYen", samples=[cost, LONG_NUM], text_name="PriceText",
                   text_colour="softRed", w=196)
    buy.update({"pos": [0.5, 0, 1, -12], "anchor": [0.5, 1]})
    kids = [
        rchip("TierTag", "TierText", [f"T{food['Tier']}", "T12"], "panel", pos=[0, 12, 0, 10]),
        ico(f"IconFlavor{flav}", 30, name="FlavorIcon", pos=[1, -12, 0, 9], anchor=[1, 0]),
        {"type": "frame", "name": "ArtTile", "colour": [FLAVOR_TILE[flav], FLAVOR_TILE[flav]],
         "paint": FLAVOR_TILE[flav], "size": [0, 196, 0, 128], "pos": [0.5, 0, 0, 46], "anchor": [0.5, 0],
         "corner": 14, "keyline": "#FFFFFF", "props": {"ClipsDescendants": True}, "children": [
             sunburst(200, pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5], z=1),
             sheen(corner=14, opacity=0.22, z=1),
             {"type": "frame", "name": "Viewport", "transparent": True, "cls": "ViewportFrame",
              "size": [0, 180, 0, 118], "pos": [0.5, 0, 0.5, 0], "anchor": [0.5, 0.5], "children": [],
              "attrs": {"FoodId": food["Id"]}, "z": 2}]},
        {**mp.panel("CravePill", 132, 28, "premium", [T("CraveHint", None, 122, 18, font="display",
                                                        samples=["+11 heroes", "+3 heroes"])],
                    corner=14, layout=row(0, "center"), pos=[0.5, 0, 0, 160], anchor=[0.5, 0]), "z": 4,
         "overhang": True},
        T("FoodName", None, 196, 24, colour="ink", font="display", samples=[food["Name"], "Festival Cake"],
          pos=[0.5, 0, 0, 194], anchor=[0.5, 0]),
        frame("StatRow", 196, 66, [
            stat_pill("PowerStat", "IconPower", "PowerText", [f"POWER x{food['PowerMult']:g}", "POWER x5.00"],
                      "powerInk"),
            stat_pill("LuckStat", "IconLuck", "LuckText", [f"LUCK x{food['Luck']:g}", "LUCK x5.50"], "luckInk"),
        ], layout=col(6, "center"), pos=[0.5, 0, 0, 232], anchor=[0.5, 0]),
        buy,
        {**ribbon_tag("NextTag", "NEXT", colour="buy"), **({} if nxt else {"visible": False, "mockHide": True})},
    ]
    c = {"type": "panel", "name": name, "colour": "#D9CFBA" if dim else "cream", "keyline": GOLD if nxt else WHITE,
         "size": [0, 220, 0, FOOD_CARD_H], "depth": 0, "corner": 18, "children": kids}
    return c


def food_shop():
    def tab(n, icon, text, on):
        return vbtn(n, "info" if on else "panelHi", "S", icon=icon, text=text)
    filt = frame("FlavourFilter", 1040, mp4.SIZE_H["S"], [
        tab("FilterAll", "IconShop", "ALL", True), tab("FilterSavory", "IconFlavorSavory", "SAVORY", False),
        tab("FilterSweet", "IconFlavorSweet", "SWEET", False), tab("FilterSpicy", "IconFlavorSpicy", "SPICY", False),
        tab("FilterSeafood", "IconFlavorSeafood", "SEAFOOD", False)], layout=row(10, "center"), pos=[0, 0, 0, 0])
    cards = [sample(food_card_template(food=FOODS[0], state="equipped"), 1),
             sample(food_card_template(food=FOODS[1], state="equip"), 2),
             sample(food_card_template(food=FOODS[2], state="afford", nxt=True), 3),
             sample(food_card_template(food=FOODS[3], state="locked", dim=True), 4)]
    scroller = {"type": "frame", "name": "FoodScroller", "transparent": True, "cls": "ScrollingFrame", "scroll": "X",
                "scrollXok": True, "size": [0, 1040, 0, FOOD_CARD_H + 40], "padding": 14, "layout": row(14, "start"),
                "props": {"ScrollBarThickness": 8, "HorizontalScrollBarInset": "ScrollBar"},
                "attrs": {"WheelScrollsX": True}, "pos": [0, 0, 0, 60], "children": cards}
    return page("FoodShop", window("FOOD SHOP", 1040, FOOD_CARD_H + 40 + 62, [filt, scroller], colour="orange", icon="IconShopBig"))


# =================================================================== Squad

def fuse_badge(stars=2, **kw):
    """The fused marker: a big gold star with a glow, the fuse count on it when > 1."""
    cnt = T("FuseCount", None, 30, 18, font="display", samples=[str(stars), "3"], pos=[0.5, 0, 0.5, 2],
            anchor=[0.5, 0.5], z=7)
    return frame("FuseBadge", 40, 40, [
        sunburst(62, colour=GOLD, name="Glow", pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5], z=5),
        {**ico("IconStar", 44, name="Star", pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5], z=6), "overhang": True},
        {**cnt, **({} if stars > 1 else {"mockHide": True})},
    ], z=5, overhang=True, **kw)


def hero_row_template(name="HeroRowTemplate", hero="Heavenly String King", rarity="Epic", size="TITAN",
                      mut="Lightning", stars=3, income="+999.99Qi/s", where="ON PLOT 12", on_plot=True, fuse=True):
    rh = RARITY[rarity]
    tile = {"type": "frame", "name": "PortraitTile", "colour": [rh, rh], "paint": rh, "corner": 16,
            "keyline": "#FFFFFF", "size": [0, 78, 0, 78], "pos": [0, 12, 0.5, 0], "anchor": [0, 0.5],
            "pattern": {"name": "dots", "colour": "#FFFFFF", "opacity": 0.14, "tile": 20}, "children": [
                sunburst(110, pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5], z=1),
                {"type": "frame", "name": "Thumb", "transparent": True, "cls": "ViewportFrame",
                 "size": [0, 74, 0, 74], "pos": [0.5, 0, 0.5, 0], "anchor": [0.5, 0.5], "children": [], "z": 2}],
            "props": {"ClipsDescendants": True}}
    badge = {**fuse_badge(stars, pos=[0, 54, 0, 1]), **({} if stars else {"visible": False, "mockHide": True})}
    chips = [rchip("RarityTag", "RarityText", [rarity.upper(), "LEGENDARY"], rh),
             rchip("SizeTag", "SizeText", [size or "BIG", "TITAN"], "info", **({} if size else {"mockHide": True})),
             rchip("MutationTag", "MutationText", [(mut or "Golden").upper(), "LIGHTNING"], MUT_HEX.get(mut or "Golden"),
                   **({} if mut else {"mockHide": True}))]
    tagw = sum(c["size"][1] for c in chips) + 16
    nbw = max(316, tagw)
    name_block = frame("NameBlock", nbw, 76, [
        T("HeroName", None, nbw, 26, font="display", align="left", samples=[hero, "Heavenly String King"],
          pos=[0, 0, 0, 2]),
        frame("TagRow", tagw, 28, chips, layout=row(8, "start"), pos=[0, 0, 0, 44]),
    ], pos=[0, 102, 0.5, 0], anchor=[0, 0.5])
    inc = frame("IncomeBlock", 144, 70, [
        T("IncomeText", None, 144, 24, colour="yen", font="display", align="right", samples=[income, "+999.99Qi/s"],
          pos=[0, 0, 0, 4]),
        T("LocationText", None, 144, 18, colour="soft", align="right", font="display", samples=[where, "ON PLOT 24"],
          pos=[0, 0, 0, 42]),
    ])
    acts = [inc,
            vbtn("PlaceButton", "info" if on_plot else "confirm", "S", icon="IconBench" if on_plot else "IconPlace",
                 samples=["BENCH" if on_plot else "PLACE", "PLACE"], text_name="PlaceText"),
            vbtn("FuseButton", "buy", "S", icon="IconFuse", text="FUSE", self_face=False,
                 **({} if fuse else {"mockHide": True})),
            vbtn("SellButton", "danger", "S", icon="IconSell", text="SELL", self_face=False)]
    aw = sum(a["size"][1] for a in acts if not a.get("mockHide")) + 10 * 3
    actions = frame("Actions", 1040 - 102 - nbw - 22, 76, acts, layout=row(10, "end"),
                    pos=[1, -12, 0.5, 0], anchor=[1, 0.5])
    assert aw <= actions["size"][1], (aw, actions["size"][1], tagw)
    return card(name, 1040, 98, "panelHi", [tile, name_block, actions, badge])


def squad():
    top = frame("TopBar", 1064, 44, [
        vbtn("TabPlot", "info", "S", icon="IconPlace", samples=["PLOT 9/9", "PLOT 24/24"], text_name="SlotCount"),
        vbtn("TabBench", "panelHi", "S", icon="IconBench", samples=["BENCH 5/30", "BENCH 60/60"],
             text_name="BenchCount"),
    ], layout=row(10, "start"), pos=[0, 0, 0, 0])
    rows = [sample(hero_row_template(hero="Sun God Captain", rarity="Mythic", size="TITAN", mut="Galaxy", stars=3,
                                     income="+999.99Qi/s", where="ON PLOT 1"), 1),
            sample(hero_row_template(hero="Bald Cape Hero", rarity="Legendary", size="HUGE", mut="Golden", stars=1,
                                     income="+48.2T/s", where="ON PLOT 2", fuse=False), 2),
            sample(hero_row_template(hero="Heavenly String King", rarity="Epic", size=None, mut="Lightning", stars=0,
                                     income="+1.25B/s", where="ON PLOT 3"), 3),
            sample(hero_row_template(hero="Copy Ninja", rarity="Rare", size="BIG", mut=None, stars=0,
                                     income="+880K/s", where="ON BENCH", on_plot=False, fuse=False), 4)]
    lst = mp3_vscroll("HeroList", 1064, 412, rows, col(10, "start"), pos=[0, 0, 0, 56])
    sell_lbl = T("AutoSellLabel", "AUTO-SELL:", 150, 22, font="display", colour="soft", align="left")
    bottom = frame("BottomBar", 1064, 44, [
        frame("AutoSellGroup", 600, 44, [
            sell_lbl,
            vbtn("AutoSellCommon", "confirm", "S", icon="IconSell", text="COMMON"),
            vbtn("AutoSellUncommon", "panelHi", "S", icon="IconSell", text="UNCOMMON"),
        ], layout=row(10, "start"), pos=[0, 0, 0, 0]),
        vbtn("EquipBest", "buy", "S", icon="IconStar", text="EQUIP BEST", self_face=False, pos=[1, 0, 0, 0],
             anchor=[1, 0]),
    ], pos=[0, 0, 0, 480])
    return page("Squad", window("MY SQUAD", 1064, 524, [top, lst, bottom], colour="blue", icon="IconSquadBig"))


def mp3_vscroll(name, w, h, children, layout, pad=8, **kw):
    return {"type": "frame", "name": name, "transparent": True, "cls": "ScrollingFrame", "scroll": "Y",
            "size": [0, w, 0, h], "padding": pad, "layout": layout, "children": list(children),
            "props": {"ScrollBarThickness": 6, "VerticalScrollBarInset": "ScrollBar"}, **kw}


# =================================================================== HeroIndex

TILE_W, TILE_H = 146, 214
ZONE_TAB_W, ZONE_TAB_H = 222, 96


def hero_tile_template(name="HeroTileTemplate", hero="Heavenly String King", rarity="Epic", craves="Seafood",
                       chance="0.0012%", known=True):
    """v4.1: an undiscovered hero is the hero's OWN black silhouette (the real model, ImageColor3 black) with a
    big "?" on it; its rarity is always shown (the coloured RarityTag chip riding the portrait's bottom edge)."""
    rh = RARITY[rarity]
    mark = {**T("UnknownMark", "?", 60, 48, font="display", pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5], z=4),
            "overhang": True,
            "props": {"TextColor3": {"Color3": [c / 255 for c in mp.ub.hex_rgb(rh)]}},
            **({} if not known else {"visible": False, "mockHide": True})}
    well = {"type": "frame", "name": "PortraitWell", "colour": ["#232866", "#12153A"], "corner": 12,
            "keyline": "#FFFFFF", "size": [0, 130, 0, 104], "pos": [0.5, 0, 0, 8], "anchor": [0.5, 0],
            "props": {"ClipsDescendants": True}, "children": [
                sunburst(150, colour=rh if known else "#3A3F6B", pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5], z=1),
                {"type": "frame", "name": "Portrait", "transparent": True, "cls": "ViewportFrame",
                 "size": [0, 126, 0, 100], "pos": [0.5, 0, 0.5, 0], "anchor": [0.5, 0.5], "z": 2, "children": []},
                mark]}
    tag = {**rchip("RarityTag", "RarityText", [rarity.upper(), "LEGENDARY"], rh, px=16, h=26),
           "pos": [0.5, 0, 0, 99], "anchor": [0.5, 0], "z": 5, "overhang": True}
    return {"type": "panel", "name": name, "colour": rh if known else "#23264F", "paintable": True, "depth": 0,
            "keyline": "#FFFFFF", "corner": 16, "size": [0, TILE_W, 0, TILE_H],
            "aspect": round(TILE_W / TILE_H, 4),
            "pattern": {"name": "dots", "colour": "#FFFFFF", "opacity": 0.12, "tile": 22}, "children": [
                well, tag,
                T("HeroName", None, 134, 17, lines=2, font="display", samples=[hero if known else "???",
                                                                             "Heavenly String King"],
                  pos=[0.5, 0, 0, 130], anchor=[0.5, 0]),
                {"type": "frame", "name": "BottomRow", "colour": ["#12153A", "#12153A"], "alpha": 0.25,
                 "outline": False, "corner": 13, "size": [0, 130, 0, 28], "pos": [0.5, 0, 1, -8],
                 "anchor": [0.5, 1], "layout": row(8, "center"),
                 "children": [ico(f"IconFlavor{craves}", 20, name="CraveIcon"),
                              auto_label("ChanceText", [chance, "0.0012%"], 18)]},
            ]}


def zone_tab(i, z, have, tot, selected=False, locked=False):
    """v4.1: a zone card with the zone's own painted landscape as its background (ZoneBg_<id>); the name and the
    progress bar are ONE centred column, the count centred in the bar; the lock on the top-right corner."""
    bar_w = 168
    return {"type": "button", "name": f"ZoneTab{i}", "colour": "info" if selected else "panelHi",
            "selfFace": True, "paintable": True, "sizeClass": "Z", "depth": 4, "corner": 16,
            "keyline": GOLD if selected else WHITE, "keepKeyline": selected,
            "size": [0, ZONE_TAB_W, 0, ZONE_TAB_H], "attrs": {"ZoneId": z["Id"]}, "children": [
                {**ico(f"ZoneBg_{z['Id']}", 100, name="ZoneBg", pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5]),
                 "size": [1, 0, 1, 0], "z": 0, "props": {"ScaleType": "Crop"}, "corner": 13, "overhang": True},
                {"type": "frame", "name": "NameWash", "colour": ["#0B0D29", "#0B0D29"], "alpha": 0.72,
                 "outline": False, "corner": 13, "size": [1, 0, 1, 0], "z": 1, "children": [],
                 "pos": [0, 0, 0, 0], "overhang": True},
                frame("ZoneColumn", ZONE_TAB_W - 24, 66, [
                    T("ZoneName", z["Name"], ZONE_TAB_W - 24, 22, font="display"),
                    track("ZoneBar", bar_w, 24, min(1, have / tot), v1.ZONE_HEX[i - 1], text_name="ZoneProgress",
                          samples=[f"{have}/{tot}", "8/8"], px=17),
                ], layout=col(8, "center"), pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5], z=2),
                {**ico("IconLock", 24, name="LockIcon", pos=[1, -8, 0, 6], anchor=[1, 0], z=3, overhang=True),
                 "visible": False, **({} if locked else {"mockHide": True})},
            ]}


def hero_index():
    tabs = []
    for i, z in enumerate(v1.ZONES, start=1):
        have = [7, 7, 5, 3, 1, 5][i - 1]
        tot = max(1, sum(1 for c in v1.CHARS if c["Zone"] == z["Id"]))
        tabs.append(zone_tab(i, z, have, tot, selected=i == 1, locked=i == 6))
    zone_tabs = mp3_vscroll("ZoneTabs", 236, 520, tabs, col(10, "start"), pad=6, pos=[0, 0, 0, 0])
    header = frame("ZoneHeader", 812, mp4.SIZE_H["S"], [
        T("ZoneTitle", None, 250, 28, font="display", align="left", samples=["Realm of Legends", "Sakura Schoolyard"]),
        rchip("TotalProgress", "TotalText", ["TOTAL 43/51", "TOTAL 8/51"], "panelDeep", px=20, h=34),
        T("LuckNote", None, 130, 20, colour="luck", font="display", samples=["Luck x999.9", "Luck x1.01"]),
        vbtn("ZoneRewardClaim", "confirm", "S", icon="IconGift", samples=["CLAIM!", "5/8 FOUND", "CLAIMED"],
             text_name="ClaimText"),
    ], layout=row(12, "start"), pos=[0, 252, 0, 0])
    realm = [c for c in v1.CHARS if c["Zone"] == "realm_of_legends"][:10]
    chances = ["41.20%", "28.80%", "14.10%", "6.200%", "6.200%", "1.420%", "1.420%", "0.0012%", "0.40%", "0.10%"]
    known = [True, True, True, True, False, True, False, False, True, False]
    tiles = [sample(hero_tile_template(hero=c["Name"], rarity=c["Rarity"], craves=c["Craves"], chance=ch, known=k),
                    n + 1) for n, (c, ch, k) in enumerate(zip(realm, chances, known))]
    grid = mp3_vscroll("HeroGrid", 812, 460, tiles, {"type": "grid", "cell": [TILE_W, TILE_H], "gap": 14, "cols": 5},
                       pad=6, pos=[0, 252, 0, 60])
    return page("HeroIndex", window("HERO INDEX", 1064, 520, [zone_tabs, header, grid], colour="violet",
                                    icon="IconIndexBig"))


# =================================================================== Store

def _icon_tile(icon_key, w, h, colour, name="IconTile", y=10):
    return {"type": "frame", "name": name, "colour": [mp4.light(colour, 0.25), colour], "corner": 14,
            "keyline": "#FFFFFF", "size": [0, w, 0, h], "pos": [0.5, 0, 0, y], "anchor": [0.5, 0],
            "pattern": {"name": "dots", "colour": "#FFFFFF", "opacity": 0.14, "tile": 20},
            "props": {"ClipsDescendants": True}, "children": [
                sunburst(min(w, h) + 40, pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5], z=1),
                sheen(corner=14, opacity=0.2, z=1)]}


def pass_card_template(name="PassCardTemplate", key="DoubleTraining", robux=149, owned=False):
    title, icon_key = v1.PASS_NAMES[key]
    btn_ = (state_pill("PassBuyButton", "PassPrice", ["OWNED"], "M", w=132) if owned else
            vbtn("PassBuyButton", "premium", "M", icon="IconRobux", samples=[str(robux), "999"], text_name="PassPrice",
                 w=132))
    btn_.update({"pos": [0.5, 0, 1, -10], "anchor": [0.5, 1]})
    return {"type": "panel", "name": name, "colour": ["#5B3FD6", "#33207F"], "keyline": "#9C8CFF", "depth": 0,
            "corner": 16, "size": [0, 148, 0, STORE_CARD_H], "attrs": {"PassKey": key}, "children": [
                _icon_tile(icon_key, 128, 88, "#7B5CFF"),
                {**ico(big(icon_key), 64, name="CardIcon", pos=[0.5, 0, 0, 22], anchor=[0.5, 0]), "z": 3, "overhang": True},
                T("PassName", None, 136, 20, lines=2, font="display", samples=[title, "2x Training"],
                  pos=[0.5, 0, 0, 104], anchor=[0.5, 0]),
                btn_]}


def product_card_template(name="ProductCardTemplate", key="LuckyThrow25", robux=149, stick=None):
    title, icon_key = v1.PRODUCT_NAMES[key]
    b = vbtn("ProductBuyButton", "premium", "M", icon="IconRobux", samples=[str(robux), "599"],
             text_name="ProductPrice", w=132, pos=[0.5, 0, 1, -10], anchor=[0.5, 1])
    st = ribbon_tag("Sticker", stick or "BEST VALUE", colour="danger", text_name="StickerText",
                    samples=["BEST VALUE", "LIMITED"])
    if not stick:
        st.update({"visible": False, "mockHide": True})
    return {"type": "panel", "name": name, "colour": ["#1F8F8A", "#125060"], "keyline": "#6FE3D6", "depth": 0,
            "corner": 16, "size": [0, 148, 0, STORE_CARD_H], "attrs": {"ProductKey": key}, "children": [
                _icon_tile(icon_key, 128, 88, "#2BB3A3", y=14),
                {**ico(big(icon_key), 64, name="CardIcon", pos=[0.5, 0, 0, 26], anchor=[0.5, 0]), "z": 3, "overhang": True},
                T("ProductName", None, 136, 20, lines=2, font="display", samples=[title, "30 min Training"],
                  pos=[0.5, 0, 0, 106], anchor=[0.5, 0]),
                b, st]}


def store():
    b1 = vbtn2("SummonBuy1", "premium", "L", "x1", "IconRobux", [str(SUMMON["SummonScroll1"]["Robux"]), "999"])
    b3 = vbtn2("SummonBuy3", "premium", "L", "x3", "IconRobux", [str(SUMMON["SummonScroll3"]["Robux"]), "999"])
    b10 = vbtn2("SummonBuy10", "confirm", "L", "x10", "IconRobux", [str(SUMMON["SummonScroll10"]["Robux"]), "999"])
    row_w = b1["size"][1] + b3["size"][1] + b10["size"][1] + 16
    bw = max(400, row_w + 24)
    banner = {"type": "panel", "name": "SummonBanner", "colour": ["#9B6BFF", "#3F178F"], "keyline": "#D6C2FF",
              "depth": 0, "corner": 20, "size": [0, bw, 0, 526], "pos": [0, 0, 0, 0],
              "pattern": {"name": "dots", "colour": "#FFFFFF", "opacity": 0.10, "tile": 26}, "children": [
                  sheen(corner=20, opacity=0.18, z=1),
                  T("SummonTitle", "SUMMON SCROLL", bw - 40, 34, colour="buy", font="display", pos=[0.5, 0, 0, 22],
                    anchor=[0.5, 0]),
                  T("SummonSub", "6 exclusive heroes", bw - 40, 20, pos=[0.5, 0, 0, 66], anchor=[0.5, 0]),
                  {"type": "frame", "name": "StageWell", "colour": ["#2A0F66", "#160638"], "corner": 16,
                   "keyline": "#B79CFF", "size": [0, bw - 48, 0, 220], "pos": [0.5, 0, 0, 100], "anchor": [0.5, 0],
                   "props": {"ClipsDescendants": True}, "children": [
                       sunburst(250, colour="#FFE38A", pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5], z=1),
                       {"type": "frame", "name": "SummonViewport", "transparent": True, "cls": "ViewportFrame",
                        "size": [1, -8, 1, -8], "pos": [0.5, 0, 0.5, 0], "anchor": [0.5, 0.5], "z": 2,
                        "children": []},
                       sparkle("Sparkle1", 26, [0, 22, 0, 26], z=3), sparkle("Sparkle2", 18, [1, -26, 0, 40], z=3),
                       sparkle("Sparkle3", 22, [1, -34, 1, -30], z=3)]},
                  vbtn("OddsButton", "info", "S", icon="IconInfo", text="SEE ODDS", opens="SummonOdds",
                       pos=[0.5, 0, 0, 334], anchor=[0.5, 0], self_face=False),
                  frame("BuyRow", row_w, 64, [b1, b3, b10], layout=row(8, "center"), pos=[0.5, 0, 0, 408],
                        anchor=[0.5, 0]),
                  {**ribbon_tag("BestValueSticker", "BEST VALUE", colour="buy", text_name="BestValueText"),
                   "pos": [0.5, (row_w - b10["size"][1]) / 2, 0, 393], "anchor": [0.5, 0]},
                  T("SummonNote", "Odds are shown before you buy", bw - 40, 18, colour="soft", pos=[0.5, 0, 0, 486],
                    anchor=[0.5, 0]),
                  {**ribbon_tag("NewSticker", "NEW!", colour="danger", text_name="NewStickerText"),
                   "pos": [1, -16, 0, 10], "anchor": [1, 0]},
              ]}
    # the x10 sticker sits on the x10 button's top border, centred on it
    bv = banner["children"][-3]
    bv["pos"] = [0, round(bw / 2 + row_w / 2 - b10["size"][1] / 2), 0, 380]
    sbtn = vbtn("StarterBuyButton", "premium", "M", icon="IconRobux",
                samples=[str(PRODS["StarterPack"]["Robux"]), "OWNED"], text_name="StarterPrice",
                pos=[1, -14, 0.5, 0], anchor=[1, 0.5])
    sw = 634
    starter = {"type": "panel", "name": "StarterPackBanner", "colour": ["#FFD45C", "#FF7A3D"], "keyline": "#FFF1B8",
               "depth": 0, "corner": 18, "size": [0, sw, 0, 116],
               "pattern": {"name": "stripes", "colour": "#FFFFFF", "opacity": 0.14, "tile": 96}, "children": [
                   sheen(corner=18, opacity=0.25, z=1),
                   sunburst(104, pos=[0, 54, 0.5, 0], anchor=[0.5, 0.5], z=1),
                   {**ico("IconGiftBig", 72, pos=[0, 54, 0.5, 0], anchor=[0.5, 0.5]), "z": 2},
                   T("StarterTitle", "STARTER PACK", 300, 30, font="display", align="left", pos=[0, 104, 0, 18], z=2),
                   T("StarterDesc", "Lucky Cat hero + 5 Lucky Throws + 2x Yen", 330, 20, lines=2, align="left",
                     pos=[0, 104, 0, 56], z=2),
                   sbtn,
                   {**ribbon_tag("LimitedSticker", "LIMITED", colour="danger", text_name="LimitedStickerText"),
                    "pos": [0, 70, 0, -15], "anchor": [0, 0]},
               ]}
    pass_cards = [sample(pass_card_template(key=k, robux=PASSES[k]["Robux"], owned=(k == "DoubleYen")), i + 1)
                  for i, k in enumerate(["DoubleYen", "DoubleTraining", "AutoThrow", "LuckyAura"])]
    prod_cards = [sample(product_card_template(key=k, robux=PRODS[k]["Robux"],
                                               stick="BEST VALUE" if k == "YenPack12h" else None), i + 1)
                  for i, k in enumerate(["LuckyThrow5", "ServerLuck", "YenPack12h", "Train30m"])]
    gridl = {"type": "grid", "cell": [148, STORE_CARD_H], "gap": 14, "cols": 4}
    scroll = mp3_vscroll("StoreScroll", 662, 526, [
        frame("StarterSpacer", 634, 4),
        starter,
        T("PassesTitle", "PASSES", 634, 26, colour="buy", font="display", align="left"),
        frame("PassScroller", 634, STORE_CARD_H, pass_cards, layout=gridl, props={"AutomaticSize": "Y"}),
        T("ItemsTitle", "ITEMS", 634, 26, colour="buy", font="display", align="left"),
        frame("ItemsSpacer", 634, 4),
        frame("ProductScroller", 634, STORE_CARD_H, prod_cards, layout=gridl, props={"AutomaticSize": "Y"}),
    ], col(12, "start"), pad=10, pos=[1, 0, 0, 0], anchor=[1, 0])
    gift = vbtn("GiftTarget", "info", "S", icon="IconGift", samples=["GIFT A FRIEND", "FOR: Builderman"],
                text_name="GiftTargetText", pos=[0, 18, 0, 18], z=4, overhang=True)
    body_w = bw + 14 + 662
    return page("Store", window("STORE", body_w, 526, [banner, scroll], colour="pink", icon="IconStoreBig",
                                extra=[gift]))


# =================================================================== SummonOdds

def odds_card(name, hero, idx):
    c = ODDS_HEX[idx]
    rarest = idx == 5
    kids = [
        sheen(corner=16, opacity=0.18, z=1),
        sunburst(156, pos=[0.5, 0, 0, 98], anchor=[0.5, 0.5], z=1),
        {"type": "frame", "name": "Portrait", "transparent": True, "cls": "ViewportFrame", "size": [0, 140, 0, 118],
         "pos": [0.5, 0, 0, 38], "anchor": [0.5, 0], "children": [], "z": 2},
        T("HeroName", hero["Name"], 150, 20, lines=2, font="display", pos=[0.5, 0, 0, 160], anchor=[0.5, 0]),
        rchip("RarityTag", "RarityText", [ODDS_TIER[idx], "LEGENDARY"], mp4.dark(c, 0.7), px=16, h=26,
              pos=[0.5, 0, 0, 212], anchor=[0.5, 0]),
        T("OddsEarn", f"{hero['BestIncomeMult']:g}x your best", 150, 18, colour="onDark", font="display",
          pos=[0.5, 0, 0, 246], anchor=[0.5, 0]),
        {**chip("OddsChip", "OddsPercent", None, "buy" if not rarest else "danger", px=26, h=40,
                static=f"{hero['OddsPercent']:g}%", w=104), "keyline": WHITE, "pos": [0.5, 0, 0, -16],
         "anchor": [0.5, 0], "z": 8, "overhang": True},
    ]
    if rarest:
        kids += [sparkle("Sparkle1", 26, [0, 14, 0, 40], z=4), sparkle("Sparkle2", 18, [1, -16, 0, 60], z=4),
                 sparkle("Sparkle3", 22, [1, -20, 0, 150], z=4)]
    node = {"type": "panel", "name": name, "colour": [mp4.light(c, 0.2), mp4.dark(c, 0.62)], "keyline": WHITE,
            "depth": 0, "corner": 16, "size": [0, 164, 0, 278], "attrs": {"HeroId": hero["Id"]},
            "pattern": {"name": "dots", "colour": "#FFFFFF", "opacity": 0.12, "tile": 22}, "children": kids}
    if rarest:
        node.update({"strokeGrad": RAINBOW, "strokeW": 4, "attrs": {"HeroId": hero["Id"], "Rarest": True}})
    return node


def summon_odds():
    prem = [p for p in CFG["PremiumCharacters"] if p["Source"] == "Summon"]
    cards = [odds_card(f"OddsRow{i}", h, i - 1) for i, h in enumerate(prem, start=1)]
    buys = []
    for n in (1, 3, 10):
        b = vbtn2(f"OddsBuy{n}", "confirm" if n == 10 else "premium", "L", f"BUY x{n}", "IconRobux",
                  [str(SUMMON[f"SummonScroll{n}"]["Robux"]), "999"], top_samples=[f"BUY x{n}", "BUY x10"])
        b["size"][1] = 176
        buys.append(b)
    bw = 3 * 176 + 2 * 20
    body = [T("OddsNote", "Every Summon Scroll gives ONE of these heroes:", 1064, 20, colour="soft",
              pos=[0.5, 0, 0, 0], anchor=[0.5, 0]),
            frame("OddsList", 1064, 280, cards, layout=row(14, "center"), pos=[0.5, 0, 0, 46], anchor=[0.5, 0]),
            T("Total", "TOTAL: 100%", 300, 24, colour="buy", font="display", pos=[0.5, 0, 0, 338], anchor=[0.5, 0]),
            frame("BuyButtons", bw, 64, buys, layout=row(20, "center"), pos=[0.5, 0, 0, 392], anchor=[0.5, 0]),
            {**ribbon_tag("OddsBestValue", "BEST VALUE", colour="buy", text_name="OddsBestValueText"),
             "pos": [0, 532 + 176 + 20, 0, 366], "anchor": [0.5, 0]}]
    return page("SummonOdds", window("SUMMON ODDS", 1064, 460, body, colour="purple", icon="IconScrollBig"),
                displayOrder=12)


# =================================================================== small windows

def offline():
    amt = auto_label("EarnedAmount", ["+999.99Qi", "+1.2K"], 44, colour="yen")
    body = [
        T("AwayTime", None, 520, 22, font="display", samples=["You were away 7h 59m", "You were away 2m"],
          pos=[0.5, 0, 0, 0], anchor=[0.5, 0]),
        {"type": "frame", "name": "EarnedWell", "colour": ["#12153A", "#0B0D29"], "keyline": "#3A4196", "corner": 20,
         "size": [0, 440, 0, 88], "pos": [0.5, 0, 0, 42], "anchor": [0.5, 0], "children": [
             sunburst(96, colour=GOLD, alpha=0.2, pos=[0, round(220 - (64 + 14 + amt["size"][1]) / 2 + 32), 0.5, 0],
                      anchor=[0.5, 0.5], z=1),
             frame("EarnedRow", 64 + 14 + amt["size"][1], 80, [ico("IconYenBig", 64), amt],
                   layout=row(14, "center"), pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5], z=2)]},
        T("CapNote", "Your heroes earned 50% while you were away (max 8h)", 520, 18, colour="soft",
          pos=[0.5, 0, 0, 142], anchor=[0.5, 0]),
    ]
    claim = vbtn("ClaimButton", "confirm", "L", icon="IconTick", text="CLAIM", self_face=False)
    h, lip = 64, 4
    ih = math.floor(0.72 * h - lip + 2)
    two = mp.lbl("Label", "2X", 44, ih, px=28, font="display", stroke=2)
    two["maxText"] = 28
    price = mp.dyn("DoublePrice", ["39", "999"], 66, ih, px=28, font="display", stroke=2)
    price["maxText"] = 28
    dbl = {"type": "button", "name": "DoubleButton", "size": [0, 44 + 38 + 66 + 16 + 46, 0, h], "sizeClass": "L",
           "depth": lip, "corner": 22, "layout": row(8, "center"),
           "children": [two, ico("IconRobux", 38), price]}
    mp4.mp3.gloss(dbl, "premium")
    dbl["attrs"] = {"PressLip": lip}
    body.append(frame("Buttons", 520, 64, [claim, dbl], layout=row(20, "center"), pos=[0.5, 0, 0, 180],
                      anchor=[0.5, 0]))
    return page("OfflineEarnings", window("WELCOME BACK!", 520, 248, body, colour="gold", icon="IconYenBig"))


def daily_cell(name, d, state):
    r = CFG["Rewards"]
    mins = r["DailyYenMinutes"][d - 1]
    lucky = r["DailyLuckyThrowsOnDay"].get(str(d), 0)
    text = f"{mins} min yen" + (f" +{lucky} Lucky" if lucky else "")
    colour = {"claimed": "#5C628F", "today": "buy", "future": "panelHi"}[state]
    return {"type": "panel", "name": name, "paintable": True, "depth": 0, "corner": 16, "colour": colour,
            "keyline": WHITE if state == "today" else PANEL_EDGE, "size": [0, 130, 0, 200],
            "pattern": {"name": "dots", "colour": "#FFFFFF", "opacity": 0.10, "tile": 22}, "children": [
                sheen(corner=16, opacity=0.18, z=1),
                T("DayLabel", f"DAY {d}", 116, 22, font="display", pos=[0.5, 0, 0, 10], anchor=[0.5, 0]),
                sunburst(116, colour="#FFFFFF" if state == "today" else GOLD, alpha=0 if state == "today" else 0.35, pos=[0.5, 0, 0, 82], anchor=[0.5, 0.5], z=1),
                {**ico("IconLuckyThrowBig" if lucky else "IconYenBig", 64, name="Icon", pos=[0.5, 0, 0, 50],
                       anchor=[0.5, 0]), "z": 2},
                T("RewardText", None, 118, 18, lines=2, font="display", samples=[text, "60 min yen +5 Lucky"],
                  pos=[0.5, 0, 0, 138], anchor=[0.5, 0]),
                ico("IconTick", 34, name="ClaimedTick", pos=[0, 85, 0, 92], anchor=[0.5, 0.5], z=4, overhang=True,
                    visible=False, **({} if state == "claimed" else {"mockHide": True})),
            ]}


def daily():
    cells = [daily_cell(f"DayCell{d}", d, "claimed" if d < 5 else "today" if d == 5 else "future") for d in range(1, 8)]
    body = [
        T("StreakLabel", None, 700, 26, colour="buy", font="display", samples=["5 DAY STREAK!  +10% LUCK",
                                                                            "CLAIM TO START A STREAK!"],
          pos=[0.5, 0, 0, 0], anchor=[0.5, 0]),
        frame("DayStrip", 1000, 200, cells, layout=row(14, "center"), pos=[0.5, 0, 0, 46], anchor=[0.5, 0]),
        vbtn("ClaimButton", "confirm", "L", icon="IconGift", samples=["CLAIM DAY 5", "TOMORROW"], text_name="ClaimText",
             pos=[0.5, 0, 0, 262], anchor=[0.5, 0]),
        T("NextIn", None, 500, 20, colour="soft", font="display", samples=["Next reward in 23:59:59", "Ready now!"],
          pos=[0.5, 0, 0, 340], anchor=[0.5, 0]),
    ]
    return page("DailyRewards", window("DAILY REWARDS", 1000, 366, body, colour="green", icon="IconGiftBig"))


def gift_cell(name, i, state):
    mins = CFG["Rewards"]["PlaytimeMinutes"][i - 1]
    if state == "claimed":
        gb = state_pill("GiftButton", "GiftState", ["CLAIMED"], "S", w=180)
    elif state == "ready":
        gb = vbtn("GiftButton", "confirm", "S", icon="IconGift", samples=["CLAIM!", "59:59"], text_name="GiftState",
                  w=180)
    else:
        gb = vbtn("GiftButton", "slate", "S", icon="IconTimer", samples=[f"{mins - 1}:59", "59:59"],
                  text_name="GiftState", text_colour="soft", w=180)
    gb.update({"pos": [0, 96, 1, -12], "anchor": [0, 1]})
    return {"type": "panel", "name": name, "colour": "panelHi", "keyline": PANEL_EDGE, "depth": 0, "corner": 16,
            "size": [0, 290, 0, 140], "aspect": round(290 / 140, 4), "children": [
                sunburst(100, colour=GOLD, alpha=0.35, pos=[0, 50, 0.5, 0], anchor=[0.5, 0.5], z=1),
                {**ico("IconGiftBig", 66, name="Icon", pos=[0, 50, 0.5, 0], anchor=[0.5, 0.5]), "z": 2},
                T("GiftTitle", f"GIFT {i}", 180, 24, font="display", align="left", pos=[0, 96, 0, 12]),
                T("GiftWhen", f"after {mins} min", 180, 20, colour="soft", align="left", pos=[0, 96, 0, 44]),
                gb]}


def playtime():
    cells = [gift_cell(f"GiftCell{i}", i, "claimed" if i <= 2 else "ready" if i == 3 else "wait") for i in range(1, 7)]
    body = [T("Timer", None, 500, 22, colour="soft", font="display", samples=["Played today: 59:59",
                                                                              "Played today: 3:12"],
              pos=[0.5, 0, 0, 0], anchor=[0.5, 0]),
            frame("GiftGrid", 898, 294, cells, layout={"type": "grid", "cell": [290, 140], "gap": 14, "cols": 3},
                  pos=[0.5, 0, 0, 42], anchor=[0.5, 0])]
    return page("PlaytimeGifts", window("FREE GIFTS", 898, 336, body, colour="green", icon="IconGiftBig"))


def codes():
    body = [
        T("CodesHint", "Join the group to find new codes!", 560, 20, colour="soft", pos=[0.5, 0, 0, 0],
          anchor=[0.5, 0]),
        frame("CodeRow", 560, 56, [
            {"type": "panel", "name": "CodeField", "colour": ["#12153A", "#0B0D29"], "keyline": PANEL_EDGE,
             "depth": 0, "corner": 16, "size": [0, 360, 0, 56], "children": [
                 ico("IconCodes", 28, pos=[0, 14, 0.5, 0], anchor=[0, 0.5]),
                 {**T("CodeBox", "TYPE A CODE", 296, 24, colour="soft", align="left", font="display",
                      pos=[0, 52, 0.5, 0], anchor=[0, 0.5]), "cls": "TextBox"}]},
            vbtn("RedeemButton", "confirm", "M", icon="IconTick", text="REDEEM", self_face=False),
        ], layout=row(14, "center"), pos=[0.5, 0, 0, 40], anchor=[0.5, 0]),
        T("ResultLabel", None, 560, 20, colour="confirm", font="display", samples=["Code redeemed! +3 Lucky Throws",
                                                                                   "That code has expired"],
          pos=[0.5, 0, 0, 112], anchor=[0.5, 0]),
    ]
    return page("Codes", window("CODES", 560, 140, body, colour="teal", icon="IconCodesBig"), displayOrder=12)


def settings():
    def srow(name, icon_key, text, controls):
        return card(name, 760, 58, "panelHi", [
            ico(icon_key, 30, pos=[0, 14, 0.5, 0], anchor=[0, 0.5]),
            T("RowLabel", text, 250, 22, align="left", font="display", pos=[0, 56, 0.5, 0], anchor=[0, 0.5]),
            *controls], corner=16)

    def slider(prefix, value):
        t = track(f"{prefix}Slider", 250, 18, value, "#34D17A", pos=[1, -96, 0.5, 0], anchor=[1, 0.5])
        knob = {"type": "button", "name": f"{prefix}Knob", "colour": "onDark", "size": [0, 40, 0, 40], "corner": 20,
                "depth": 3, "sizeClass": "X", "pos": [value, 0, 0.5, 0], "anchor": [0.5, 0.5], "overhang": True,
                "z": 3, "centre": False, "children": [
                    ico("IconMusic" if prefix == "Music" else "IconSfx", 22, pos=[0.5, 0, 0.5, -1],
                        anchor=[0.5, 0.5])]}
        mp4.mp3.gloss(knob, "onDark")
        knob["attrs"] = {"PressLip": 3}
        t["children"].append(knob)
        return [t, T(f"{prefix}Value", None, 66, 20, align="right", font="display",
                     samples=[f"{int(value * 100)}%", "100%"], pos=[1, -14, 0.5, 0], anchor=[1, 0.5])]

    def toggle(name, on, text=None, x=-12):
        return vbtn(name, "confirm" if on else "slate", "S", icon="IconTick" if on else "IconClose",
                    text=text, samples=None if text else (["ON", "OFF"] if on else ["OFF", "ON"]),
                    text_name=f"{name}State" if not text else "Label", pos=[1, x, 0.5, 0], anchor=[1, 0.5])
    unc = toggle("AutoSellUncommon", False, text="UNCOMMON")
    com = toggle("AutoSellCommon", True, text="COMMON", x=-12 - unc["size"][1] - 10)
    rows = [srow("MusicRow", "IconMusic", "Music", slider("Music", 0.7)),
            srow("SfxRow", "IconSfx", "Sound effects", slider("Sfx", 1.0)),
            srow("FastRevealRow", "IconFast", "Fast reveal", [toggle("FastReveal", True)]),
            srow("LowDetailRow", "IconLowDetail", "Low detail", [toggle("LowDetail", False)]),
            srow("HideOthersRow", "IconHide", "Hide other plots", [toggle("HideOtherPlots", False)]),
            srow("AutoSellRow", "IconSell", "Auto-sell when full", [com, unc]),
            srow("CodesRow", "IconCodes", "Redeem a code", [
                vbtn("CodesButton", "info", "S", icon="IconCodes", text="CODES", opens="Codes", pos=[1, -12, 0.5, 0],
                     anchor=[1, 0.5], self_face=False)])]
    body = [frame("Rows", 760, 7 * 58 + 6 * 10, rows, layout=col(10, "start"), pos=[0.5, 0, 0, 0], anchor=[0.5, 0])]
    return page("Settings", window("SETTINGS", 760, 7 * 58 + 6 * 10, body, colour="slate", icon="IconSettingsBig"))


def rebirth():
    def keep_list(name, title, colour, icon_key, items, x):
        return card(name, 442, 196, "panelHi", [
            T("Title", title, 400, 24, font="display", colour=colour, align="left", pos=[0, 18, 0, 12]),
            frame("List", 400, 4 * 28 + 3 * 8, [frame(f"Item{i}", 400, 28, [
                ico(icon_key, 24), T("Text", t, 360, 22, align="left", font="display")], layout=row(10, "start"))
                for i, t in enumerate(items, 1)], layout=col(8, "start"), pos=[0, 18, 0, 50]),
        ], pos=[x, 0, 0, 216], anchor=[x, 0])
    req = card("Requirements", 560, 200, "panelHi", [
        T("ReqTitle", "NEXT REBIRTH", 260, 26, font="display", align="left", pos=[0, 18, 0, 14]),
        T("NextTier", None, 220, 26, colour="buy", font="display", align="right", samples=["REBIRTH 999", "REBIRTH 1"],
          pos=[1, -18, 0, 14], anchor=[1, 0]),
        ico("IconPowerBig", 40, name="PowerIcon", pos=[0, 18, 0, 64]),
        track("PowerBar", 470, 40, 0.82, "#38BDF8", text_name="PowerReqText",
              samples=["999.99Qi / 999.99Qi", "6.8B / 600M"], px=24, pos=[0, 70, 0, 64]),
        ico("IconYenBig", 40, name="YenIcon", pos=[0, 18, 0, 128]),
        track("YenBar", 470, 40, 0.44, "#34D17A", text_name="YenReqText",
              samples=["999.99Qi / 999.99Qi", "220B / 500B"], px=24, pos=[0, 70, 0, 128]),
    ])
    reward = {"type": "panel", "name": "Rewards", "colour": ["#FFE27A", "#FF9F1A"], "keyline": "#FFF1B8",
              "depth": 0, "corner": 18, "size": [0, 326, 0, 200], "pos": [1, 0, 0, 0], "anchor": [1, 0],
              "pattern": {"name": "stripes", "colour": "#FFFFFF", "opacity": 0.14, "tile": 96}, "children": [
                  sheen(corner=18, opacity=0.25, z=1),
                  sunburst(196, pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5], z=1),
                  T("RewardTitle", "REWARD", 290, 28, font="display", pos=[0.5, 0, 0, 14], anchor=[0.5, 0], z=2),
                  T("RewardIncome", None, 290, 28, font="display", colour="confirm",
                    samples=["+50% INCOME", "+150% INCOME"], pos=[0.5, 0, 0, 58], anchor=[0.5, 0], z=2),
                  T("RewardLuck", None, 290, 28, font="display", colour="info", samples=["+10% LUCK", "+30% LUCK"],
                    pos=[0.5, 0, 0, 100], anchor=[0.5, 0], z=2),
                  T("RewardForever", "FOREVER!", 290, 22, font="display", pos=[0.5, 0, 0, 152], anchor=[0.5, 0], z=2),
              ]}
    body = [req, reward,
            keep_list("Keeps", "YOU KEEP", "confirm", "IconTick", ["Hero Index", "Game passes", "Premium heroes",
                                                                   "Lucky Throws"], 0),
            keep_list("Resets", "YOU LOSE", "danger", "IconClose", ["Yen and power", "Foods and gear", "Plot slots",
                                                                     "Caught heroes"], 1),
            T("CurrentRebirth", None, 420, 22, colour="soft", align="left", font="display",
              samples=["You are at Rebirth 999", "You are at Rebirth 0"], pos=[0, 0, 0, 440]),
            vbtn("ConfirmButton", "buy", "L", icon="IconRebirth", text="REBIRTH!", pos=[1, 0, 0, 428], anchor=[1, 0])]
    return page("Rebirth", window("REBIRTH", 900, 492, body, colour="gold", icon="IconRebirthBig"))


# =================================================================== TrainingBar (training mini-game HUD)

def training():
    # v4.1: one aligned panel. Rank (left) and gear (right) share one 32 px row so their centres line up; the
    # bar is centred with its text centred in it; the per-rep line is ONE centred icon + text group.
    pw = 600
    p = card("TrainingPanel", pw, 124, ["#262B6E", "#161A48"], [
        frame("HeadRow", pw - 32, 32, [
            T("RankName", None, 270, 26, colour="power", font="display", align="left",
              samples=["CHAMPION", "ROOKIE"], pos=[0, 0, 0.5, 0], anchor=[0, 0.5]),
            T("GearName", None, 280, 20, colour="soft", align="right", font="display",
              samples=["on Gravity Dojo", "on Wooden Dummy"], pos=[1, 0, 0.5, 0], anchor=[1, 0.5]),
        ], pos=[0.5, 0, 0, 10], anchor=[0.5, 0]),
        track("ProgressBar", pw - 32, 32, 0.58, "#38BDF8", text_name="ProgressText",
              samples=["999.99Qi / 999.99Qi -> LEGEND", "9.01K / 70K -> ELITE"], px=19, pos=[0.5, 0, 0, 48],
              anchor=[0.5, 0]),
        {**frame("RepRow", 300, 28, [
            ico("IconPower", 24, name="PowerIcon"),
            auto_label("PowerPerRep", ["+11.00K power per rep", "+560 power per rep"], 20, colour="power"),
        ], layout=row(8, "center"), pos=[0.5, 0, 0, 88], anchor=[0.5, 0]), "autoW": 0},
    ], pos=[0.5, 0, 1, -14], anchor=[0.5, 1])
    up = vbtn("UpgradePrompt", "confirm", "S", icon="IconTrain", px=20,
              samples=["NEW GEAR: Dragon Shrine 28B", "NEW GEAR: Sandbag 600"], text_name="UpgradeText",
              pos=[0.5, 0, 1, -150], anchor=[0.5, 1], visible=False, self_face=False)
    # the timing game: a fixed target ring and a ring that shrinks onto it each rep
    cx, cy, side = 800, 340, 220
    ring_box = frame("TimingRing", side, side, [
        {"type": "frame", "name": "RingBack", "colour": ["#12153A", "#12153A"], "alpha": 0.55, "outline": False,
         "corner": 1, "size": [0.62, 0, 0.62, 0], "pos": [0.5, 0, 0.5, 0], "anchor": [0.5, 0.5], "children": [],
         "overhang": True},
        mp4.ring("Target", round(side * 0.62), GOLD, 8, pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5], z=2, overhang=True),
        {**mp4.ring("Shrink", side, "#FFFFFF", 5, pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5], z=3, overhang=True),
         "size": [1, 0, 1, 0]},
        {**ico("IconPowerBig", 56, name="RingIcon", pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5]), "z": 4,
         "overhang": True},
    ], pos=[0, cx, 0, cy], anchor=[0.5, 0.5], attrs={"TargetScale": 0.62})
    title = T("StationTitle", None, 420, 36, font="display", samples=["STRIKE DUMMY", "GRAVITY DOJO"],
              pos=[0, cx, 0, cy - side // 2 - 100], anchor=[0.5, 0])
    tap = T("TapHint", "TAP IN THE RING!", 420, 28, font="display", pos=[0, cx, 0, cy + side // 2 + 10],
            anchor=[0.5, 0])
    perfect = {**T("PerfectLabel", "PERFECT!", 360, 48, colour="buy", font="display",
                   pos=[0, cx, 0, cy], anchor=[0.5, 0.5], z=6), "visible": False, "mockHide": True}
    rep = T("RepPower", None, 260, 32, colour="power", font="display", align="left",
            samples=["+120 POWER", "+11.00K POWER"], pos=[0, cx + side // 2 + 8, 0, cy - 70], z=5)
    combo = {**T("Combo", None, 200, 32, colour="buy", font="display", align="right",
                 samples=["x3 COMBO", "x12 COMBO"], pos=[0, cx - side // 2 - 8, 0, cy - 70], anchor=[1, 0], z=5),
             "visible": False}
    exit_ = round_x("ExitButton", pos=[0, cx + side // 2 + 6, 0, cy - side // 2 - 54], z=6)
    return page("TrainingBar", [up, p, ring_box, title, tap, perfect, rep, combo, exit_], kind="hud", enabled=False)


# =================================================================== ThrowMeter

def throw_meter():
    spec = v3.throw_meter()
    root = {"children": spec["children"]}
    face = vbtn("ThrowButtonFace", "coral", "L", icon="IconThrow", text="THROW", pos=[0.5, 0, 1, -16],
                anchor=[0.5, 1], z=3, self_face=False)

    def toggle(name, colour, icon_key, title, state_name, samples, pos, anchor):
        n = vbtn2(name, colour, "L", title, icon_key, samples, price_name=state_name, top_name="Title",
                  pos=pos, anchor=anchor, z=3)
        n["selfFace"] = True
        return n
    lucky = toggle("LuckyThrowToggle", "violet", "IconLuckyThrow", "LUCKY", "LuckyCount", ["x99", "x3"],
                   [0.5, -110, 1, -16], [1, 1])
    auto = toggle("AutoToggle", "grey", "IconAuto", "AUTO", "AutoState", ["OFF", "ON"], [0.5, 110, 1, -16], [0, 1])
    rep = {"ThrowButtonFace": face, "LuckyThrowToggle": lucky, "AutoToggle": auto}
    spec["children"] = [rep.get(k.get("name"), k) for k in spec["children"]]
    find(root, "TapLabel").update({"pos": [0.5, 0, 0, 552], "size": [0, 460, 0, 50], "textScale": round(40 / 50, 4),
                                   "maxText": 40, "textStroke": 2})
    zp = find(root, "ZonePreviewLabel")
    zp.update({"size": [0, 440, 0, 36], "pos": [0, 602, 0, 80], "textScale": round(28 / 36, 4), "maxText": 28,
               "font": "display", "textStroke": 2})
    mp.DISPLAY_TEXTS.update(zp["samples"])
    for mk in find(root, "ZoneBands")["children"]:
        lab = find(mk, "ZoneMarkName")
        lab.update({"size": [0, 220, 0, 26], "textScale": round(20 / 26, 4), "maxText": 20, "font": "display",
                    "textStroke": 1.5})
        mp.DISPLAY_TEXTS.add(lab["text"])
    pl = find(root, "PerfectLabel")
    pl.update({"size": [0, 130, 0, 26], "textScale": round(20 / 26, 4), "maxText": 20, "textStroke": 1.5})
    bl = find(root, "BonusLabel")
    bl.update({"size": [0, 220, 0, 40], "textScale": round(32 / 40, 4), "maxText": 32, "textStroke": 2,
               "samples": ["+12 POWER", "+1.2K POWER"]})
    mp.DISPLAY_TEXTS.update(bl["samples"])
    # leave the throw spot: the round red X at the top-right of the meter area
    spec["children"].append(round_x("ExitButton", pos=[0, 950, 0, 14], z=6))
    return spec


def zone_mark_template(name="ZoneMarkTemplate", **kw):
    m = v2.zone_mark_template(name=name, **kw)
    lab = find(m, "ZoneMarkName")
    lab.update({"size": [0, 220, 0, 26], "textScale": round(20 / 26, 4), "maxText": 20, "font": "display",
                "textStroke": 1.5})
    mp.DISPLAY_TEXTS.add(lab["text"])
    return m


# =================================================================== HUD (system + legibility)

def hud():
    spec = v3.hud()
    root = {"children": spec["children"]}
    for colname in ("LeftColumn", "RightColumn"):
        c = find(root, colname)
        for cell in c["children"]:
            b = cell["children"][0]
            b["depth"] = 4
            b["corner"] = 20
            cap = find(b, "Caption")
            cap.update({"size": [0, 70, 0, 22], "textScale": round(18 / 22, 4), "maxText": 18, "textStroke": 1.5,
                        "pos": [0.5, 0, 1, -2]})
            badge = find(b, "Badge")
            badge.update({"size": [0, 26, 0, 26], "corner": 13})
            badge["children"][0].update({"size": [0, 18, 0, 20], "textScale": 0.8, "maxText": 16})
            chipn = find(b, "GiftTimerBadge")
            if chipn is not None:
                chipn.update({"size": [0, 68, 0, 22]})
                chipn["children"][0].update({"size": [0, 62, 0, 20], "textScale": 0.8, "maxText": 16})
    hint = find(root, "TutorialHint")
    ol = find(hint, "ObjectiveLine")
    longest = max(ol["samples"], key=len)
    wtxt = int(est(longest, 20, display=False)) + 4
    hint.update({"size": [0, 44 + wtxt + 16, 0, 40], "keyline": PANEL_EDGE})
    ol.update({"size": [0, wtxt, 0, 28], "textScale": round(20 / 28, 4), "maxText": 20})
    # notice card: bigger type, system buttons
    nc = find(root, "NoticeCard")
    nb = vbtn("NoticeButton", "confirm", "S", icon="IconShop", samples=["SHOP", "BUY"], text_name="NoticeButtonText",
              pos=[1, -14, 1, -14], anchor=[1, 1])
    nc["children"] = [nb if k.get("name") in ("NoticeButton", "NoticeButtonCell") else k for k in nc["children"]]
    nc.update({"size": [0, 400, 0, 112], "keyline": PANEL_EDGE})
    find(nc, "NoticeTitle").update({"size": [0, 200, 0, 24], "textScale": 0.75, "maxText": 18, "pos": [0, 76, 0, 12]})
    find(nc, "NoticeBody").update({"size": [0, 168, 0, 46], "wrap": True, "textScale": round(18 / 46, 4),
                                   "maxText": 18, "pos": [0, 76, 0, 44]})
    lb = find(root, "ServerLuckBar")
    lb["children"] = [vbtn("BoostButton", "premium", "S", icon="IconRobux", w=44) if k.get("name") == "BoostButton"
                      else k for k in lb["children"]]
    lb.update({"size": [0, 300, 0, 56], "keyline": PANEL_EDGE})
    find(lb, "Multiplier").update({"size": [0, 110, 0, 30], "textScale": 0.75, "maxText": 22})
    find(lb, "TimeLeft").update({"size": [0, 70, 0, 28], "textScale": 0.72, "maxText": 20})
    # v4.1: the server announcement is a big top-centre banner (built by announcement()), and the toasts are a
    # stack on the left, clear of the centre (the reveal) and of the notice card
    spec["children"] = [announcement() if k.get("name") == "Announcement" else k for k in spec["children"]]
    toasts = find(root, "Toasts")
    toasts.update({"size": [0, TOAST_W, 0, 3 * TOAST_H + 2 * 8], "pos": [0, 112, 0, 252], "anchor": [0, 0],
                   "layout": col(8, "start"),
                   "children": [sample(toast_template(text=["Not enough yen for Festival Cake!"], kind="bad"), 1),
                                sample(toast_template(text=["Gift 3 is ready to claim!"], kind="good"), 2)]})
    find(root, "FlashText").update({"pos": [0.5, 0, 0, 300]})
    for name in ("PowerCounter", "YenCounter", "LuckChip"):
        r = find(root, name)
        for k in r["children"]:
            if k.get("type") == "label" and k.get("name") not in ("PowerAmount", "YenAmount", "LuckAmount"):
                k.update({"size": [0, 220, 0, 22], "textScale": round(18 / 22, 4), "maxText": 18, "pos": [0, 62, 0, 38]})
    fc = find(root, "FoodChip")
    find(fc, "FoodName").update({"size": [0, 184, 0, 26], "textScale": round(20 / 26, 4), "maxText": 20})
    frow = find(fc, "FlavorRow")
    frow.update({"pos": [0, 62, 0, 30], "size": [0, 184, 0, 22]})
    find(frow, "FoodFlavor").update({"size": [0, 160, 0, 22], "textScale": round(18 / 22, 4), "maxText": 18})
    find(frow, "FlavorIcon")["size"] = [0, 18, 0, 18]
    return spec


TOAST_W, TOAST_H = 430, 50
TOAST_KIND = {"info": ["#4FA8FF", "#2C5BD6"], "good": ["#4BE08A", "#14935A"], "bad": ["#FF6B6B", "#C42A3A"],
              "reward": ["#FFD45C", "#F08A1C"]}


def toast_template(name="ToastTemplate", text=None, kind="info", **kw):
    """v4.1 toast: a glossy game notification. Gradient face (repainted per kind at runtime), a round white icon
    well on the left, chunky display text, a sheen the client sweeps on entrance."""
    well = {"type": "frame", "name": "IconWell", "colour": ["#FFFFFF", "#E6ECFF"], "corner": 1,
            "keyline": "#FFFFFF", "size": [0, 38, 0, 38], "children": [
                ico("IconInfo", 28, pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5])]}
    lab = T("Text", None, TOAST_W - 38 - 10 - 34, 19, font="display", align="left",
            samples=text or ["Not enough yen for Festival Cake!"])
    return {"type": "panel", "name": name, "colour": TOAST_KIND[kind], "paintable": True, "keyline": WHITE,
            "depth": 0, "corner": 18, "size": [0, TOAST_W, 0, TOAST_H], "layout": row(10, "start"),
            "children": [
                {"type": "frame", "name": "Pad", "transparent": True, "size": [0, 2, 0, 10], "children": []},
                well, lab]}


def announcement():
    """v4.1 server announcement: a wide top-centre banner. A gradient plate (recoloured per kind: a rare catch,
    Festival Hour, server luck, rebirth), a big icon on a sunburst on the left, the headline over the big hero /
    event name, and a rarity chip + odds line. The client slides it in, pops it and sweeps a shine over it."""
    w_, h_ = 720, 100
    info = frame("InfoRow", 500, 26, [
        rchip("RarityChip", "RarityText", ["LEGENDARY", "SECRET"], "#1B1F4B", px=17, h=26),
        auto_label("OneInN", ["1 in 48,400,000", "1 in 250"], 18),
    ], layout=row(10, "start"))
    text = frame("TextColumn", 520, 88, [
        T("PlayerName", None, 520, 18, font="display", align="left",
          samples=["xX_SuperLongName_Xx caught", "FESTIVAL HOUR"]),
        T("HeroName", None, 520, 30, font="display", align="left", colour="buy",
          samples=["Heavenly String King", "x2 LUCK FOR 15 MIN"]),
        info,
    ], layout=col(2, "start"), pos=[0, 150, 0.5, 0], anchor=[0, 0.5], z=3)
    return {"type": "panel", "name": "Announcement", "colour": ["#FFC93C", "#FF5A5F"], "paintable": True,
            "keyline": WHITE, "depth": 0, "corner": 22, "size": [0, w_, 0, h_], "pos": [0.5, 0, 0, 118],
            "anchor": [0.5, 0], "visible": False, "z": 6,
            "pattern": {"name": "stripes", "colour": "#FFFFFF", "opacity": 0.12, "tile": 64}, "children": [
                {**sunburst(150, pos=[0, 74, 0.5, 0], anchor=[0.5, 0.5], z=1), "overhang": True},
                {**ico("IconCrownBig", 72, name="AnnounceIcon", pos=[0, 74, 0.5, 0], anchor=[0.5, 0.5]), "z": 3},
                text,
                sparkle("Sparkle1", 22, [1, -26, 0, 20], z=4), sparkle("Sparkle2", 16, [1, -54, 1, -18], z=4),
            ]}


# =================================================================== Reveal (system pass + legibility)

def reveal():
    spec = v3.reveal()
    root = {"children": spec["children"]}
    for nm, px, w in (("SkipHint", 18, 320), ("VariantLabel", 20, 280), ("SoldLabel", 20, 340), ("LuckLabel", 24, 320)):
        n = find(root, nm)
        h = round(px * 1.3)
        n.update({"size": [0, w, 0, h], "textScale": round(px / h, 4), "maxText": px})
    rr = find(root, "RarityRibbon")
    rr.update({"rotation": 0, "keyline": WHITE, "corner": 14})
    zb = find(root, "ZoneBanner")
    zb.update({"rotation": 0, "keyline": WHITE, "corner": 14, "size": [0, 300, 0, 40]})
    zb["children"][0].update({"size": [0, 270, 0, 30], "textScale": 0.67, "maxText": 20})
    return spec


# =================================================================== world GUIs

def nameplate():
    """Every line centred: the name; the tag pills as ONE centred group; the income + stars as one group.
    Pills, income and stars size to their content in game (AutomaticSize X), so a hidden pill or star leaves
    no gap and the group stays centred."""
    name = T("HeroName", None, 312, 34, font="display", samples=["Heavenly String King", "Copy Ninja"],
             pos=[0.5, 0, 0, 2], anchor=[0.5, 0])
    tags = frame("TagRow", 312, 32, [
        pill_auto("SizeTag", "SizeText", ["TITAN", "BIG"], "info", px=20, h=32),
        pill_auto("MutationTag", "MutationText", ["LIGHTNING", "GOLDEN"], MUT_HEX["Lightning"], px=20, h=32),
    ], layout=row(8, "center"), pos=[0.5, 0, 0, 48], anchor=[0.5, 0])
    yen = auto_label("YenPerSecond", ["+999.99Qi/s", "+1.26K/s"], 26, colour="yen")
    stars = frame("Stars", 3 * 24 + 2 * 4, 24, [ico("IconStar", 24, name=f"Star{i}") for i in (1, 2, 3)],
                  layout=row(4, "center"), autoW=0)
    bottom = frame("BottomRow", 312, 36, [ico("IconYen", 28, name="YenIcon"), yen, stars],
                   layout=row(8, "center"), pos=[0.5, 0, 0, 90], anchor=[0.5, 0])
    return {"name": "Nameplate", "theme": "theme.json", "resolution": [320, 132], "kind": "world",
            "rootClass": "BillboardGui", "children": [name, tags, bottom],
            "rootProps": {"Size": {"UDim2": [[0, 320], [0, 132]]}, "StudsOffset": {"Vector3": [0, 4.5, 0]},
                          "MaxDistance": 60, "AlwaysOnTop": False, "LightInfluence": 0, "ClipsDescendants": False}}


MEDAL = {1: "#FFC93C", 2: "#C9D3E3", 3: "#E8893A"}


def leaderboard_row_template(name="LeaderboardRowTemplate", rank=10, player="xX_SuperLongName_Xx", score=LONG_NUM):
    tint = ["#323A8C", "#21265E"][rank % 2]
    medal = MEDAL.get(rank, "#3A4196")
    badge = {"type": "panel", "name": "RankBadge", "colour": [mp4.light(medal, 0.3), medal], "selfFace": True,
             "paintable": True, "depth": 0, "corner": 26, "keyline": WHITE if rank <= 3 else PANEL_EDGE,
             "size": [0, 52, 0, 52], "children": [
                 mp.dyn("RankText", [str(rank), "10"], 44, 40, px=28, font="display", stroke=2,
                        pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5])]}
    badge["children"][0]["maxText"] = 28
    return {"type": "panel", "name": name, "colour": [mp4.light(tint, 0.06), tint], "paintable": True, "depth": 0,
            "keyline": MEDAL.get(rank, PANEL_EDGE), "corner": 16, "size": [0, 740, 0, 64],
            "children": [
                {**badge, "pos": [0, 10, 0.5, 0], "anchor": [0, 0.5]},
                {"type": "frame", "name": "AvatarWell", "colour": ["#12153A", "#12153A"], "keyline": PANEL_EDGE,
                 "size": [0, 52, 0, 52], "corner": 26, "pos": [0, 74, 0.5, 0], "anchor": [0, 0.5],
                 "children": [ico("PlayerHeadshot", 48, name="Avatar", pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5])]},
                T("PlayerName", None, 370, 28, align="left", samples=[player, "xX_SuperLongName_Xx"],
                  pos=[0, 140, 0.5, 0], anchor=[0, 0.5]),
                T("Score", None, 200, 28, colour="yen", align="right", font="display",
                  samples=[score, "1 in 48,400,000"], pos=[1, -16, 0.5, 0], anchor=[1, 0.5]),
            ]}


def leaderboard():
    people = [("Builderman", "999.99Qi"), ("SakuraNinja77", "512.4Qi"), ("xX_SuperLongName_Xx", "88.1Qi"),
              ("RamenLord", "3.2Qa"), ("TitanTosser", "940T"), ("LuckyCatFan", "201T"), ("OnigiriKid", "48T"),
              ("ZoneRunner", "9.9T"), ("PirateCook", "1.2T"), ("NewbieNoob", "800B")]
    rows = [leaderboard_row_template(name=f"Row{i}", rank=i, player=p, score=s) for i, (p, s) in enumerate(people, 1)]
    head = {"type": "frame", "name": "BoardHeader", "colour": ["#FFD45C", "#FF7A3D"], "paint": "#FFB13D",
            "corner": 22, "keyline": "#FFF1B8", "size": [0, 740, 0, 150], "pos": [0.5, 0, 0, 16], "anchor": [0.5, 0],
            "props": {"ClipsDescendants": True},
            "pattern": {"name": "stripes", "colour": "#FFFFFF", "opacity": 0.14, "tile": 96}, "children": [
                sheen(corner=22, opacity=0.25, z=1),
                sunburst(200, pos=[0, 90, 0.5, 0], anchor=[0.5, 0.5], z=1),
                {**ico("IconCrownBig", 96, name="BoardIcon", pos=[0, 90, 0.5, 0], anchor=[0.5, 0.5]), "z": 2},
                {**mp.dyn("BoardTitle", ["RAREST CATCH", "MOST CAUGHT", "MOST YEN"], 540, 64, px=54, font="display",
                          stroke=2.5, align="left", pos=[0, 170, 0, 22]), "maxText": 54, "z": 2},
                {**T("BoardSub", "TOP 10 PLAYERS", 540, 28, colour="#3A1A00", font="display", align="left",
                     pos=[0, 172, 0, 96]), "z": 2},
                sparkle("Sparkle1", 30, [1, -40, 0, 30], z=3), sparkle("Sparkle2", 20, [1, -80, 0, 110], z=3),
                sparkle("Sparkle3", 24, [0, 160, 0, 20], z=3)]}
    board = {"type": "panel", "name": "Board", "colour": ["#2C3280", "#161944"], "keyline": PANEL_EDGE, "depth": 0,
             "corner": 30, "size": [0, 780, 0, 980], "pos": [0.5, 0, 0.5, 0], "anchor": [0.5, 0.5],
             "pattern": {"name": "dots", "colour": "#FFFFFF", "opacity": 0.06, "tile": 28}, "children": [
                 head,
                 frame("Rows", 740, 10 * 64 + 9 * 8, rows, layout=col(8, "start"), pos=[0.5, 0, 0, 182],
                       anchor=[0.5, 0]),
                 T("Footer", "Updates every minute", 600, 26, colour="soft", font="display", pos=[0.5, 0, 1, -30],
                   anchor=[0.5, 1]),
             ]}
    return {"name": "Leaderboard", "theme": "theme.json", "resolution": [800, 1000], "kind": "world",
            "rootClass": "SurfaceGui", "children": [board],
            "rootProps": {"SizingMode": "FixedSize", "CanvasSize": {"Vector2": [800, 1000]}, "Face": "Front",
                          "LightInfluence": 0, "AlwaysOnTop": False}}


def slot_sign():
    sign = {"type": "panel", "name": "Sign", "colour": ["#2C3280", "#161944"], "keyline": PANEL_EDGE, "depth": 0,
            "corner": 26, "size": [0, 580, 0, 280], "pos": [0.5, 0, 0.5, 0], "anchor": [0.5, 0.5], "children": [
                {"type": "frame", "name": "SignHeader", "colour": ["#6EE68E", "#1FB46A"], "corner": 20,
                 "outline": False, "size": [0, 556, 0, 84], "pos": [0.5, 0, 0, 12], "anchor": [0.5, 0],
                 "pattern": {"name": "stripes", "colour": "#FFFFFF", "opacity": 0.14, "tile": 96}, "children": [
                     sheen(corner=20, opacity=0.25, z=1),
                     {**T("FromTo", None, 520, 48, font="display", samples=["SLOT 23 -> 24", "ALL 24 SLOTS OPEN"],
                          pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5]), "z": 2}]},
                frame("PriceRow", 540, 76, [ico("IconYenBig", 64),
                                            auto_label("Price", [LONG_NUM, "1.5K"], 52, colour="yen")],
                      layout=row(14, "center"), pos=[0.5, 0, 0, 112], anchor=[0.5, 0]),
                T("BuyPrompt", None, 540, 30, colour="soft", font="display",
                  samples=["Buy this slot here!", "Not enough yen"], pos=[0.5, 0, 0, 206], anchor=[0.5, 0]),
            ]}
    return {"name": "SlotSign", "theme": "theme.json", "resolution": [600, 300], "kind": "world",
            "rootClass": "SurfaceGui", "children": [sign],
            "rootProps": {"SizingMode": "FixedSize", "CanvasSize": {"Vector2": [600, 300]}, "Face": "Front",
                          "LightInfluence": 0, "AlwaysOnTop": False}}


# =================================================================== HudFx (moments over everything, v4.1)

def hud_fx():
    """Moments that must show over the throw cinematic and the reveal (DisplayOrder 15, above Reveal's 5): the
    zone label a thrown food shows when it crosses into a new region (left of centre, under the reveal's luck
    line and inside the letterbox; clear of the ThrowMeter on the right and of the toasts below), and the LEVEL UP
    banner (rank up, new gear, rebirth). Both start hidden; HudController:ZoneCross / :LevelUp drive them."""
    plate = {"type": "panel", "name": "ZonePlate", "colour": ["#FF7AB6", "#E8358F"], "paintable": True,
             "keyline": WHITE, "depth": 0, "corner": 20, "size": [0, 440, 0, 80], "pos": [0.5, 0, 0, 24],
             "anchor": [0.5, 0], "z": 2,
             "pattern": {"name": "stripes", "colour": "#FFFFFF", "opacity": 0.14, "tile": 64}, "children": [
                 {**T("ZoneTitle", None, 400, 40, font="display", samples=["Sakura Schoolyard", "Realm of Legends"],
                      pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5]), "z": 3},
             ]}
    zone_chip = {**rchip("ZoneNumber", "ZoneNumberText", ["ZONE 3", "ZONE 6"], "#1B1F4B", px=18, h=30),
                 "pos": [0.5, 0, 0, 8], "anchor": [0.5, 0], "z": 4, "overhang": True}
    zone = frame("ZoneCross", 460, 112, [
        {**sunburst(230, colour="#FFFFFF", alpha=0.35, name="Burst", pos=[0.5, 0, 0, 64], anchor=[0.5, 0.5],
                    z=1), "overhang": True},
        plate, zone_chip,
    ], pos=[0, 400, 0, 132], anchor=[0.5, 0], visible=False)
    ribbon = {"type": "panel", "name": "LevelPlate", "colour": ["#FFE066", "#FF9F1A"], "paintable": True,
              "keyline": WHITE, "depth": 0, "corner": 24, "size": [0, 540, 0, 92], "pos": [0.5, 0, 0, 30],
              "anchor": [0.5, 0], "z": 2,
              "pattern": {"name": "stripes", "colour": "#FFFFFF", "opacity": 0.16, "tile": 64}, "children": [
                  {**T("LevelTitle", None, 500, 44, font="display", samples=["RANK UP!", "NEW GEAR!"],
                       pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5]), "z": 3},
              ]}
    sub = {"type": "panel", "name": "LevelSubPlate", "colour": ["#262B6E", "#161A48"], "keyline": WHITE,
           "depth": 0, "corner": 18, "size": [0, 360, 0, 40], "pos": [0.5, 0, 0, 132], "anchor": [0.5, 0], "z": 3,
           "children": [T("LevelSub", None, 340, 22, font="display", colour="buy",
                          samples=["CHAMPION", "Gravity Dojo"], pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5])]}
    level = frame("LevelUp", 600, 180, [
        {**sunburst(320, colour="#FFE38A", name="Burst", pos=[0.5, 0, 0, 76], anchor=[0.5, 0.5], z=1),
         "overhang": True},
        ribbon, sub,
        sparkle("Sparkle1", 30, [0, 40, 0, 26], z=5), sparkle("Sparkle2", 22, [1, -40, 0, 20], z=5),
        sparkle("Sparkle3", 26, [1, -70, 0, 150], z=5), sparkle("Sparkle4", 18, [0, 76, 0, 150], z=5),
    ], pos=[0.5, 0, 0, 150], anchor=[0.5, 0], visible=False)
    return page("HudFx", [zone, level], kind="hud", displayOrder=15)


SCREENS = [hud, throw_meter, reveal, food_shop, squad, hero_index, store, summon_odds, offline, rebirth,
           daily, playtime, codes, settings, training, hud_fx, nameplate, leaderboard, slot_sign]


def _daily_t(name="DailyCellTemplate"):
    return daily_cell(name, 7, "future")


def _gift_t(name="GiftCellTemplate"):
    return gift_cell(name, 6, "wait")


def _odds_t(name="OddsRowTemplate"):
    prem = [p for p in CFG["PremiumCharacters"] if p["Source"] == "Summon"]
    return odds_card(name, prem[5], 5)


TEMPLATES = [
    (food_card_template, "FoodShop"), (hero_row_template, "Squad"), (hero_tile_template, "HeroIndex"),
    (pass_card_template, "Store"), (product_card_template, "Store"), (toast_template, "HUD"),
    (zone_mark_template, "ThrowMeter"), (leaderboard_row_template, "Leaderboard"),
    (_daily_t, "DailyRewards"), (_gift_t, "PlaytimeGifts"), (_odds_t, "SummonOdds"),
]
