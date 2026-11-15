"""UI version 2: minimal HUD, vertical ThrowMeter, edge-only Reveal, smaller juicier pages.

Proportions and beats from design/research/05-reference-recording.md; look, wording and
layouts stay Manga Pop. Names given by the coordinator's v2 message are a contract; every
other name keeps its v1 path (design/ui/BINDINGS.md).
"""

from __future__ import annotations

import copy
import math

import screens as v1
from mangapop import (INK, SENTINEL, WHITE, btn, card, chip, dyn, fill_frame, frame, ibtn, ico, lbl,  # noqa: F401
                      panel, ribbon, row, col, sample, viewport)
from screens import LONG_NUM, MUT_HEX, RARITY, ZONE_HEX, page

GOLD = "#FFC93C"


def find(n, name):
    if n.get("name") == name:
        return n
    for c in n.get("children") or []:
        r = find(c, name)
        if r:
            return r
    return None


def hit(name, w, h, children=(), **kw):
    """A transparent TextButton hit area (no depth stack)."""
    return {"type": "frame", "name": name, "transparent": True, "cls": "TextButton", "size": [0, w, 0, h],
            "children": list(children), **kw}


# =================================================================== HUD

def hud_button(name, colour, icon_key, caption, opens, side=64):
    kids = [ico(icon_key, 44, pos=[0.5, 0, 0, 3], anchor=[0.5, 0])]
    c = lbl("Caption", caption, 92, 22, px=16, font="display")
    c.update({"pos": [0.5, 0, 1, 12], "anchor": [0.5, 1], "overhang": True, "z": 3})
    kids.append(c)
    kids.append(chip("Badge", "BadgeText", None, 28, 28, "danger", px=16, static="!",
                     pos=[1, 8, 0, -8], anchor=[1, 0], overhang=True, z=4, corner=14, visible=False))
    return btn(name, colour, side, side, kids, opens=opens, corner=18)


def toast_template(name="ToastTemplate", text=None, icon_key="IconInfo", colour="panel"):
    return {"type": "panel", "name": name, "colour": colour, "paintable": True, "keyline": WHITE,
            "depth": 3, "corner": 16, "size": [0, 380, 0, 32], "padding": 4, "layout": row(8, "start"),
            "children": [ico(icon_key, 22),
                         dyn("Text", text or ["Not enough yen for Festival Cake!"], 330, 22, px=15,
                             align="left", textStroke=2)]}


def notice_card():
    return card("NoticeCard", 340, 84, "panel", [
        ico("FoodIcon_dango", 52, name="NoticeIcon", pos=[0, 10, 0.5, 0], anchor=[0, 0.5]),
        dyn("NoticeTitle", ["NEW FOOD UNLOCKED!", "NEW GEAR!"], 150, 22, px=16, colour="gold",
            font="display", align="left", textStroke=2, pos=[0, 70, 0, 10]),
        dyn("NoticeBody", ["Dango, 250 yen", "Iron Dummy, 20K yen"], 150, 36, px=15, align="left", wrap=True,
            textStroke=2, pos=[0, 70, 0, 40]),
        ibtn("NoticeButton", "confirm", 100, 56, "IconShop", samples=["SHOP", "BUY"], text_name="NoticeButtonText",
             px=16, icon_side=22, pos=[1, -12, 0.5, 0], anchor=[1, 0.5]),
        hit("NoticeClose", 56, 56, [panel("CloseFace", 30, 30, "danger", [
            ico("IconClose", 14, pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5])], corner=14, depth=2,
            pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5])], pos=[1, 22, 0, -22], anchor=[1, 0], overhang=True, z=5),
    ], comic=4, pos=[0.5, 0, 0, 58], anchor=[0.5, 0], visible=False, z=5)


def hud():
    left = frame("LeftColumn", 72, 252, [
        hud_button("BtnShop", "buy", "IconShop", "SHOP", "FoodShop"),
        hud_button("BtnSquad", "info", "IconSquad", "SQUAD", "Squad"),
        hud_button("BtnIndex", "violet", "IconIndex", "INDEX", "HeroIndex"),
    ], layout=col(30, "start"), pos=[0, 20, 0, 112])
    gift = hud_button("BtnGift", "confirm", "IconGift", "GIFTS", "PlaytimeGifts")
    badge = find(gift, "Badge")
    badge["pos"], badge["anchor"] = [0, -12, 0.5, 0], [0, 0.5]
    gift["children"].append(chip("GiftTimerBadge", "GiftTimer", ["12:59", "READY!"], 68, 24, "panelDeep", px=14,
                                 pos=[1, 2, 0, -8], anchor=[1, 0], overhang=True, z=4, depth=2))
    right = frame("RightColumn", 72, 252, [
        hud_button("BtnStore", "premium", "IconStore", "STORE", "Store"),
        gift,
        hud_button("BtnRebirth", "buy", "IconRebirth", "REBIRTH", "Rebirth"),
    ], layout=col(30, "start"), pos=[1, -20, 0, 230], anchor=[1, 0])
    settings = hit("BtnSettings", 56, 56, [
        panel("GearFace", 44, 44, "grey", [ico("IconSettings", 28, pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5])],
              corner=22, depth=3, pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5]),
        chip("Badge", "BadgeText", None, 26, 26, "danger", px=15, static="!", pos=[1, 0, 0, 0], anchor=[1, 0],
             overhang=True, z=4, corner=13, visible=False),
    ], pos=[0, 20, 0, 46], attrs={"OpensPage": "Settings"})

    # food chip: a round icon button above the stats; name and flavour as plain outlined text
    # FoodName / FlavorRow stay CHILDREN of FoodChip (v1 paths), drawn beside the round chip
    food_name = dyn("FoodName", ["Festival Cake", "Onigiri"], 150, 22, px=16, align="left", stroke=3,
                    pos=[1, 8, 0, 4], overhang=True)
    flavor = frame("FlavorRow", 150, 20, [ico("IconFlavorSweet", 18, name="FlavorIcon"),
                                         dyn("FoodFlavor", ["SEAFOOD", "SWEET"], 124, 20, px=14, colour="soft",
                                             align="left", font="display", textStroke=2)],
                   layout=row(8, "start"), pos=[1, 8, 0, 32], overhang=True)
    food = btn("FoodChip", "panelHi", 56, 56, [ico("FoodIcon_onigiri", 40, pos=[0.5, 0, 0.5, 0],
                                                    anchor=[0.5, 0.5]), food_name, flavor],
               keyline=WHITE, corner=28, depth=4, pos=[0, 20, 0, 388], opens="FoodShop")

    # stats: outlined TEXT with an icon, bottom-left, no panel
    # one tight left-aligned block: number on top, small caps under it, icons in one column
    power = frame("PowerCounter", 240, 62, [
        ico("IconPower", 38, pos=[0, 0, 0, 0]),
        dyn("PowerAmount", [LONG_NUM, "3.20K"], 190, 36, px=30, colour="power", align="left", font="display",
            stroke=4, pos=[0, 46, 0, 0]),
        dyn("RankName", ["CHAMPION", "ROOKIE"], 150, 18, px=14, colour="soft", align="left", font="display",
            stroke=2, pos=[0, 46, 0, 44]),
    ], pos=[0, 20, 0, 538])
    yen = frame("YenCounter", 240, 62, [
        ico("IconYen", 38, pos=[0, 0, 0, 0]),
        dyn("YenAmount", [LONG_NUM, "12.5M"], 190, 36, px=30, colour="yen", align="left", font="display",
            stroke=4, pos=[0, 46, 0, 0]),
        dyn("IncomePerSecond", ["+999.99Qi/s"], 190, 18, px=15, colour="soft", align="left", stroke=2,
            pos=[0, 46, 0, 44]),
    ], pos=[0, 20, 0, 608])
    luck = frame("LuckChip", 140, 30, [
        ico("IconLuck", 28, pos=[0, 5, 0.5, 0], anchor=[0, 0.5]),
        dyn("LuckAmount", ["x999.9", "x1.25"], 90, 28, px=20, colour="luck", align="left", font="display",
            stroke=3, pos=[0, 46, 0.5, 0], anchor=[0, 0.5]),
    ], pos=[0, 20, 0, 678])

    hint = card("TutorialHint", 480, 36, "panel", [
        ico("IconArrow", 22, name="Arrow", pos=[0, 10, 0.5, 0], anchor=[0, 0.5]),
        dyn("ObjectiveLine", ["Reach Realm of Legends: train to 40M power",
                              "Hold THROW and release near the top!"], 430, 28, px=17, align="left", textStroke=2,
            pos=[0, 42, 0.5, 0], anchor=[0, 0.5]),
    ], comic=3, corner=18, alpha=0.2, pos=[0.5, 0, 0, 14], anchor=[0.5, 0])
    boost = ibtn("BoostButton", "premium", 56, 56, "IconRobux", icon_side=28)
    boost["overhang"] = True
    luckbar = card("ServerLuckBar", 250, 40, "panel", [
        ico("IconLuck", 24),
        dyn("Multiplier", ["x8 LUCK", "x2 FEST"], 80, 28, px=18, colour="luck", font="display", textStroke=2),
        dyn("TimeLeft", ["14:59", "2:59"], 56, 26, px=16, textStroke=2),
        boost,
    ], comic=3, corner=20, padding=4, layout=row(8), pos=[0, 754, 0, 150])
    announce = card("Announcement", 672, 44, ["#FFC93C", "#FF5A5F"], [
        ico("IconStar", 26),
        dyn("PlayerName", ["xX_SuperLongName_Xx", "Builderman"], 212, 22, px=14, align="left", textStroke=2),
        dyn("HeroName", ["Heavenly String King", "Copy Ninja"], 176, 28, px=19, font="display"),
        dyn("RarityText", ["LEGENDARY", "SECRET"], 88, 22, px=14, colour="onDark", font="display", textStroke=2),
        dyn("OneInN", ["1 in 48,400,000", "1 in 250"], 126, 22, px=14, textStroke=2),
    ], keyline=WHITE, comic=3, corner=10, rotation=-1, padding=4, layout=row(8),
        pattern={"name": "dots", "colour": "#FFFFFF", "opacity": 0.22, "tile": 26},
        pos=[0.5, 0, 0, 206], anchor=[0.5, 0], visible=False, z=6)
    flash = lbl("FlashText", SENTINEL, 400, 56, px=44, colour="buy", font="display",
                samples=["LUCKY THROW!", "PERFECT!"], stroke=4, pos=[0.5, 0, 0, 260], anchor=[0.5, 0],
                visible=False)
    toasts = frame("Toasts", 380, 72, [
        sample(toast_template(text=["Not enough yen for Festival Cake!"], icon_key="IconYen"), 1),
        sample(toast_template(text=["Gift 3 is ready to claim!"], icon_key="IconGift", colour="#1F6E4A"), 2),
    ], layout=col(8, "end"), pos=[0.5, 0, 0, 452], anchor=[0.5, 0])
    return page("HUD", [settings, left, right, food, power, yen, luck, hint, notice_card(),
                        luckbar, announce, flash, toasts], kind="hud")


# =================================================================== ThrowMeter

def zone_mark_template(name="ZoneMarkTemplate", hexcol=ZONE_HEX[1], f=0.5, zone="Pirate Harbor"):
    return {**fill_frame(name, hexcol, 84, 6, pos=[0.5, 0, 1 - f, 0], anchor=[0.5, 0.5], corner=3, overhang=True),
            "children": [lbl("ZoneMarkName", zone, 176, 22, px=16, align="right", stroke=3,
                             pos=[0, -8, 0.5, 0], anchor=[1, 0.5], overhang=True)]}


def throw_meter():
    names = [z["Name"] for z in v1.ZONES]
    marks = [sample(zone_mark_template(hexcol=ZONE_HEX[i], f=f, zone=names[i]), i + 1)
             for i, f in enumerate([0.16, 0.34, 0.52, 0.70])]
    segs = [{"type": "frame", "name": f"Segment{i}", "colour": [INK, INK], "alpha": 0.6, "outline": False,
             "size": [1, -10, 0, 3], "pos": [0.5, 0, i / 10, 0], "anchor": [0.5, 0.5], "corner": 1,
             "overhang": True, "z": 1, "children": []} for i in range(1, 10)]
    marker = {"type": "panel", "name": "MeterMarker", "colour": "onDark", "size": [0, 96, 0, 28], "corner": 14,
              "depth": 4, "pos": [0.5, 0, 0.38, 0], "anchor": [0.5, 0.5], "overhang": True, "z": 6, "children": [
                  lbl("BonusLabel", SENTINEL, 96, 50, px=42, colour="buy", font="display", stroke=4,
                      samples=["+12", "+20"], align="left", pos=[1, 10, 0.5, 0], anchor=[0, 0.5], overhang=True)]}
    bar = {"type": "frame", "name": "MeterBar", "colour": ["#34D17A", "#F04438"],
           "stops": [[0, "#34D17A"], [0.45, "#FFC93C"], [1, "#F04438"]], "size": [0, 64, 0, 380], "corner": 30,
           "pos": [0, 790, 0, 128], "children": [
               *segs,
               {"type": "frame", "name": "Sheen", "colour": ["#FFFFFF", "#FFFFFF"], "alpha": 0.55, "outline": False,
                "size": [0, 12, 1, -40], "pos": [0, 10, 0.5, 0], "anchor": [0, 0.5], "corner": 6,
                "overhang": True, "z": 2, "children": []},
               {"type": "frame", "name": "PerfectBand", "colour": ["#FFFFFF", "#FFF3B0"], "alpha": 0.25,
                "outline": False, "size": [1, 0, 0.08, 0], "corner": 30, "overhang": True, "z": 4, "children": [
                    lbl("PerfectLabel", "PERFECT", 104, 24, px=18, colour="buy", font="display", stroke=3,
                        align="right", pos=[0, -8, 0.5, 0], anchor=[1, 0.5], overhang=True)]},
               frame("ZoneBands", None, None, marks, overhang=True, z=3),
               marker,
           ]}
    face = btn("ThrowButtonFace", "coral", 180, 80, [
        ico("IconThrow", 44), lbl("Label", "THROW", 100, 40, px=32, font="display")],
        layout=row(8), corner=26, pos=[0.5, 0, 1, -16], anchor=[0.5, 1], z=3)

    def toggle(name, colour, icon_key, title, state_name, samples, pos, anchor):
        return btn(name, colour, 140, 72, [
            ico(icon_key, 40),
            frame("Text", 76, 60, [lbl("Title", title, 76, 24, px=18, font="display"),
                                   dyn(state_name, samples, 76, 26, px=20)], layout=col(8)),
        ], paint=True, layout=row(8), pos=pos, anchor=anchor, z=3)

    kids = [
        hit("ThrowButton", 1280, 480, pos=[0, 0, 0, 240], overhang=True, z=-1),
        dyn("ZonePreviewLabel", ["Lands in: Realm of Legends", "Lands in: Pirate Harbor"], 380, 36, px=24,
            pos=[0, 632, 0, 82]),
        bar,
        ico("FoodIcon_onigiri", 56, name="FoodIcon", pos=[0, 866, 0, 452]),
        lbl("TapLabel", "TAP TO THROW!", 480, 56, px=44, colour="onDark", font="display", stroke=4,
            pos=[0.5, 0, 0, 540], anchor=[0.5, 0]),
        face,
        toggle("LuckyThrowToggle", "violet", "IconLuckyThrow", "LUCKY", "LuckyCount", ["x999", "x3"],
               [0.5, -102, 1, -20], [1, 1]),
        toggle("AutoToggle", "grey", "IconAuto", "AUTO", "AutoState", ["OFF", "ON"], [0.5, 102, 1, -20], [0, 1]),
    ]
    return page("ThrowMeter", kids, kind="hud", enabled=False)


# =================================================================== Reveal

def reveal():
    zr = ribbon("ZoneBanner", None, 260, 36, samples=["Realm of Legends", "Pirate Harbor"], px=17,
                pos=[0.5, 0, 0, 36], anchor=[0.5, 0])
    zr["children"][0]["name"] = "ZoneBannerText"
    zr["z"] = 2  # explicit: above OddsBurst (z 1), never relies on sibling order
    rr = ribbon("RarityRibbon", None, 190, 36, samples=["LEGENDARY", "UNCOMMON"], px=17,
                colour=[RARITY["Legendary"], RARITY["Legendary"]], pos=[0.5, -8, 0, 550], anchor=[1, 0],
                centre=False)
    rr.update({"selfFace": True, "paintable": True})
    rr["children"][0]["name"] = "RarityText"
    kids = [
        {"type": "frame", "name": "LetterboxTop", "colour": ["#000000", "#000000"], "outline": False,
         "size": [1, 0, 0, 0], "screenLevel": True, "z": -1, "children": []},
        {"type": "frame", "name": "LetterboxBottom", "colour": ["#000000", "#000000"], "outline": False,
         "size": [1, 0, 0, 0], "pos": [0, 0, 1, 0], "anchor": [0, 1], "screenLevel": True, "z": -1, "children": []},
        dyn("LuckLabel", ["999.9x LUCK", "2.36x LUCK"], 300, 26, px=22, colour="luck", font="display", stroke=3,
            pos=[0.5, 0, 0, 6], anchor=[0.5, 0], z=3),
        zr,
        {**ico("FxStarburst", 130, name="OddsBurst", pos=[0.5, 0, 0, 106], anchor=[0.5, 0.5]),
         "overhang": True, "visible": False, "z": 1, "props": {"ImageColor3": {"Color3": [1, 0.231, 0.42]}}},
        dyn("OddsLabel", ["1 in 48,400,000", "1 in 31"], 560, 56, px=52, font="display", stroke=4,
            pos=[0.5, 0, 0, 80], anchor=[0.5, 0], z=3),
        dyn("StampLabel", ["NEW BEST!", "LUCKY!", "NEW!"], 260, 28, px=24, colour="buy", font="display", stroke=3,
            rotation=-4, pos=[0.5, 0, 0, 144], anchor=[0.5, 0], z=4),
        rr,
        dyn("VariantLabel", ["LIGHTNING  TITAN", "GOLDEN  HUGE"], 240, 30, px=17, colour="soft", font="display",
            stroke=3, align="left", pos=[0.5, 8, 0, 553], centre=False),
        dyn("NameLabel", ["HEAVENLY STRING KING", "H_A_E_L_ S_R_N_ K_N_"], 820, 52, px=48, font="display",
            stroke=4, pos=[0.5, 0, 0, 594], anchor=[0.5, 0]),
        frame("IncomeRow", 230, 30, [ico("IconYen", 26, name="YenIcon"),
                                     dyn("IncomeLabel", ["+999.99Qi/s", "+24/s"], 190, 28, px=24, colour="yen",
                                         font="display", stroke=3, align="left")], layout=row(8, "start"),
              pos=[0.5, -8, 0, 654], anchor=[1, 0], centre=False),
        dyn("SoldLabel", ["sold for 999.99Qi yen", "sent to your bench"], 300, 30, px=17, colour="soft", stroke=2,
            align="left", pos=[0.5, 8, 0, 654], centre=False),
        lbl("SkipHint", "tap to continue", 260, 20, px=14, colour="soft", stroke=2, pos=[0.5, 0, 0, 692],
            anchor=[0.5, 0]),
        {"type": "frame", "name": "FlashFrame", "colour": ["#FFFFFF", "#FFFFFF"], "alpha": 1, "outline": False,
         "size": [1, 0, 1, 0], "screenLevel": True, "overhang": True, "z": 20, "children": []},
    ]
    return page("Reveal", kids, kind="overlay")


# =================================================================== pages: smaller + juice

def shrink(node, k):
    n = copy.deepcopy(node)

    def rec(n):
        t = n.get("type", "frame")
        for key in ("size", "pos"):
            v = n.get(key)
            if v:
                n[key] = [v[0], round(v[1] * k), v[2], round(v[3] * k)]
        if n.get("padding"):
            n["padding"] = max(3, round(n["padding"] * k))
        if n.get("layout"):
            lay = dict(n["layout"])
            if "gap" in lay:
                lay["gap"] = max(8, round(lay["gap"] * k)) if lay["gap"] >= 8 else round(lay["gap"] * k)
            if "cell" in lay:
                lay["cell"] = [round(lay["cell"][0] * k), round(lay["cell"][1] * k)]
            n["layout"] = lay
        if isinstance(n.get("corner"), (int, float)) and n["corner"] > 1:
            n["corner"] = max(4, round(n["corner"] * k))
        if t == "label" and n["size"][2] == 0:
            ts = n["textScale"]
            if n["size"][3] * ts < 14:
                n["size"][3] = math.ceil(14 / ts)
            if n.get("textStroke", 3) >= 3 and k < 0.8:
                n["textStroke"] = 2
        if t == "button" and n["size"][0] == 0 and n["size"][2] == 0:
            n["size"][1] = max(56, n["size"][1])
            n["size"][3] = max(56, n["size"][3])
        if n.get("aspect") and n["size"][0] == 0 and n["size"][2] == 0:
            n["aspect"] = round(n["size"][1] / n["size"][3], 4)
        for c in n.get("children") or []:
            rec(c)
        return n
    return rec(n)


def page_k(spec):
    w = find({"children": spec["children"]}, "Window")
    W, H = w["size"][1], w["size"][3]
    return min(0.85, 800 / W, 500 / H)


def shrunk(fn, extra=None):
    def build():
        spec = fn()
        if extra:
            extra(spec)
        k = page_k(spec)
        spec["children"] = [c if c.get("name") == "Scrim" else shrink(c, k) for c in spec["children"]]
        spec["pageScale"] = round(k, 4)
        return spec
    build.__name__ = fn.__name__
    return build


def sticker(name, text_name, samples, w, colour, rot, pos, anchor=(0, 0), static=None, **kw):
    return chip(name, text_name, samples, w, 34, colour, px=20, static=static, rotation=rot, pos=pos,
                anchor=list(anchor), overhang=True, z=6, keyline=WHITE, **kw)


def hero_row_template(**kw):
    r = v1.hero_row_template(**kw)
    r["children"].insert(0, fill_frame("RarityStripe", RARITY[kw.get("rarity", "Epic")], 10, 76, corner=5))
    r["size"][1] += 22
    return r


def hero_tile_template(**kw):
    t = v1.hero_tile_template(**kw)
    t["children"].append(fill_frame("RarityStripe", "#FFFFFF", 150, 8, corner=4, pos=[0.5, 0, 0, 100],
                                    anchor=[0.5, 0], overhang=True, z=2, alpha=0.55))
    return t


def product_card_template(name="ProductCardTemplate", key="LuckyThrow25", robux=149, stick=None):
    c = v1.product_card_template(name=name, key=key, robux=robux)
    s = sticker("Sticker", "StickerText", [stick or "BEST VALUE", "BEST VALUE", "LIMITED"], 130, "danger", 8,
                [1, 12, 0, -14], anchor=(1, 0))
    if not stick:
        s["mockHide"] = True
    c["children"].append(s)
    return c


def squad_v2():
    spec = v1.squad()
    lst = find({"children": spec["children"]}, "HeroList")
    rarities = ["Mythic", "Legendary", "Epic", "Rare"]
    for r, rar in zip(lst["children"], rarities):
        r["children"].insert(0, fill_frame("RarityStripe", RARITY[rar], 10, 76, corner=5))
        r["size"][1] += 22
    find({"children": spec["children"]}, "Window")["size"][1] += 22
    find({"children": spec["children"]}, "Body")["size"][1] += 22
    for nm in ("TopBar", "HeroList"):
        find({"children": spec["children"]}, nm)["size"][1] += 22
    return spec


def index_v2():
    spec = v1.hero_index()
    for t in find({"children": spec["children"]}, "HeroGrid")["children"]:
        t["children"].append(fill_frame("RarityStripe", "#FFFFFF", 150, 8, corner=4, pos=[0.5, 0, 0, 100],
                                        anchor=[0.5, 0], overhang=True, z=2, alpha=0.55))
    return spec


def store_juice(spec):
    root = {"children": spec["children"]}
    find(root, "SummonBanner")["children"].append(
        sticker("NewSticker", "NewStickerText", None, 90, "danger", 10, [1, 14, 0, -16], anchor=(1, 0), static="NEW!"))
    find(root, "StarterPackBanner")["children"].append(
        sticker("LimitedSticker", "LimitedStickerText", None, 130, "danger", -8, [0, -14, 0, -18], static="LIMITED"))
    b10 = find(root, "SummonBuy10")
    b10["children"].append(sticker("BestValueSticker", "BestValueText", None, 156, "buy", 8, [0.5, 0, 0, -30],
                                   anchor=(0.5, 0), static="BEST VALUE"))
    scr = find(root, "ProductScroller")
    keys = ["LuckyThrow5", "ServerLuck", "YenPack2h", "Train30m"]
    prods = {p["Key"]: p for p in v1.CFG["Monetization"]["Products"]}
    scr["children"] = [sample(product_card_template(key=k, robux=prods[k]["Robux"],
                                                    stick="BEST VALUE" if k == "YenPack2h" else None), i + 1)
                       for i, k in enumerate(keys)]


SCREENS = [hud, throw_meter, reveal,
           shrunk(v1.food_shop), shrunk(squad_v2), shrunk(index_v2), shrunk(v1.store, store_juice),
           shrunk(v1.summon_odds), shrunk(v1.offline), shrunk(v1.rebirth), shrunk(v1.daily),
           shrunk(v1.playtime), shrunk(v1.codes), shrunk(v1.settings),
           v1.training, v1.nameplate, v1.leaderboard, v1.slot_sign]

_K = {}


def _k(screen_fn):
    if screen_fn not in _K:
        _K[screen_fn] = page_k(screen_fn())
    return _K[screen_fn]


def _t(fn, screen_fn):
    def build():
        return shrink(fn(), _k(screen_fn))
    build.__name__ = fn.__name__
    return build


TEMPLATES = [
    (_t(v1.food_card_template, v1.food_shop), "FoodShop"),
    (_t(hero_row_template, squad_v2), "Squad"),
    (_t(hero_tile_template, index_v2), "HeroIndex"),
    (_t(v1.pass_card_template, v1.store), "Store"),
    (_t(product_card_template, v1.store), "Store"),
    (_t(v1.daily_cell_template, v1.daily), "DailyRewards"),
    (_t(v1.gift_cell_template, v1.playtime), "PlaytimeGifts"),
    (v1.leaderboard_row_template, "Leaderboard"),
    (toast_template, "HUD"),
    (zone_mark_template, "ThrowMeter"),
    (_t(v1.odds_row_template, v1.summon_odds), "SummonOdds"),
]
