"""Every Manga Pop screen as a spec, built from the kit in mangapop.py.

Element names follow design/ui.json. Every dynamic label ships "<unbound>" with its
longest real strings as samples; repeated things are built by a *_template()
function, used once standalone (src/ui/Templates/<Thing>Template.model.json) and
again for the hidden Sample rows that fill the mockup.
"""

from __future__ import annotations

import json
from pathlib import Path

from mangapop import (INK, SENTINEL, WHITE, btn, card, chip, close_button, col, dyn, frame,  # noqa: F401
                      ibtn, ico, lbl, panel, ribbon, row, sample, track, viewport, window,
                      fill_frame)

ROOT = Path(__file__).resolve().parents[2]
CFG = json.loads((ROOT / "design" / "game.json").read_text(encoding="utf-8"))["config"]

RARITY = {k: "#" + v["Color"] for k, v in CFG["Rarities"].items()}
FLAVOR_HEX = {"Savory": "#FF9F43", "Sweet": "#FF7EC8", "Spicy": "#FF4D4D", "Seafood": "#2DD4BF"}
# one key colour per zone, in lane order (17 since economy v2); the client's zone banner uses the same
ZONE_HEX = ["#FF9A3C", "#5BD6B0", "#3FB6FF", "#5BE38A", "#3D7BFF", "#8BD94A", "#FFB03C", "#C084FF", "#C9B28A",
            "#FF6A3C", "#FFD23F", "#9B6BFF", "#FFE14A", "#FF8FC8", "#7A5CFF", "#6FA8FF", "#FFC83C"]
MUT_HEX = {"Galaxy": "#7C3AED", "Lightning": "#38BDF8", "Flame": "#FF6B2C", "Golden": "#F5B70A"}
LONG_NUM = "999.99Qi"
REF = [1280, 720]


def short(n):
    for v, s in ((1e15, "Qa"), (1e12, "T"), (1e9, "B"), (1e6, "M"), (1e3, "K")):
        if n >= v:
            x = n / v
            t = f"{x:.2f}".rstrip("0").rstrip(".")
            return t + s
    return str(int(n))


def page(name, children, kind="page", **kw):
    return {"name": name, "theme": "theme.json", "resolution": REF, "kind": kind,
            "ignoreGuiInset": True, "children": children, **kw}


# =================================================================== HUD

def hud_button(name, colour, icon_key, caption, opens, side=76, caption_samples=None):
    kids = [ico(icon_key, 50, pos=[0.5, 0, 0, 6], anchor=[0.5, 0])]
    if caption or caption_samples:
        c = (dyn("Caption", caption_samples, 108, 30, px=24, font="display") if caption_samples
             else lbl("Caption", caption, 108, 30, px=24, font="display"))
        c.update({"pos": [0.5, 0, 1, 12], "anchor": [0.5, 1], "overhang": True, "z": 3})
        kids.append(c)
        kids[0]["pos"] = [0.5, 0, 0, 4]
    else:
        kids[0] = ico(icon_key, 40, pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5])
    badge = chip("Badge", "BadgeText", None, 30, 30, "danger", px=22, static="!",
                 pos=[1, 10, 0, -10], anchor=[1, 0], overhang=True, z=4, corner=15,
                 visible=False)
    kids.append(badge)
    return btn(name, colour, side, side, kids, opens=opens)


def toast_template(name="ToastTemplate", text=None, icon_key="IconInfo", colour="panel"):
    return {"type": "panel", "name": name, "colour": colour, "paintable": True, "keyline": WHITE,
            "depth": 4, "size": [0, 400, 0, 40], "padding": 6, "layout": row(8, "start"),
            "children": [ico(icon_key, 28),
                         dyn("Text", text or ["Not enough yen for Festival Cake!"], 348, 26, px=16,
                             align="left", textStroke=2)]}


def hud():
    left = frame("LeftColumn", 76, 348, [
        hud_button("BtnShop", "buy", "IconShop", "SHOP", "FoodShop"),
        hud_button("BtnSquad", "info", "IconSquad", "SQUAD", "Squad"),
        hud_button("BtnIndex", "violet", "IconIndex", "INDEX", "HeroIndex"),
        hud_button("BtnSettings", "grey", "IconSettings", None, "Settings", side=60),
    ], layout=col(20, "start"), pos=[0, 24, 0, 96])

    gift = hud_button("BtnGift", "confirm", "IconGift", "GIFTS", "PlaytimeGifts", side=74)
    # on this button the "!" badge moves to the top-LEFT corner so the timer pill owns
    # the top-right corner, inside the button, clear of the Store button above
    badge = next(k for k in gift["children"] if k.get("name") == "Badge")
    badge["pos"], badge["anchor"] = [0, -8, 0, -6], [0, 0]
    timer = chip("GiftTimerBadge", "GiftTimer", ["12:59", "READY!"], 66, 24, "panelDeep", px=14,
                 pos=[1, -3, 0, 3], anchor=[1, 0], overhang=True, z=4, depth=2)
    gift["children"].append(timer)
    right = frame("RightColumn", 76, 262, [
        hud_button("BtnStore", "premium", "IconStore", "STORE", "Store", side=74),
        gift,
        hud_button("BtnRebirth", "buy", "IconRebirth", "REBIRTH", "Rebirth", side=74),
    ], layout=col(20, "start"), pos=[1, -24, 0, 224], anchor=[1, 0])

    # stat chips: one tight stack beside the left button column (x 112..302)
    yen = card("YenCounter", 190, 54, "panel", [
        ico("IconYen", 36, pos=[0, 8, 0.5, 0], anchor=[0, 0.5]),
        dyn("YenAmount", [LONG_NUM, "12.5M"], 132, 24, px=22, colour="yen", align="left",
            font="display", pos=[0, 52, 0, 2]),
        dyn("IncomePerSecond", ["+999.99Qi/s"], 132, 18, px=14, colour="soft", align="left",
            textStroke=1, pos=[0, 52, 0, 34]),
    ], comic=4, corner=12, pos=[0, 112, 0, 96])
    power = card("PowerCounter", 190, 54, "panel", [
        ico("IconPower", 34, pos=[0, 9, 0.5, 0], anchor=[0, 0.5]),
        dyn("PowerAmount", [LONG_NUM, "3.20K"], 132, 24, px=22, colour="power", align="left",
            font="display", pos=[0, 52, 0, 2]),
        dyn("RankName", ["CHAMPION", "ROOKIE"], 132, 18, px=14, colour="soft", align="left",
            textStroke=1, pos=[0, 52, 0, 34]),
    ], comic=4, corner=12, pos=[0, 112, 0, 158])
    luck = card("LuckChip", 110, 40, "panel", [
        ico("IconLuck", 28, pos=[0, 6, 0.5, 0], anchor=[0, 0.5]),
        dyn("LuckAmount", ["x999.9", "x1.25"], 62, 28, px=20, colour="luck", align="left",
            font="display", textStroke=2, pos=[0, 42, 0.5, 0], anchor=[0, 0.5]),
    ], comic=4, corner=12, pos=[0, 112, 0, 220])
    # 56 tall, not the suggested 48: it is a button and the project touch floor is 56 px
    food = btn("FoodChip", "panelHi", 190, 56, [
        ico("FoodIcon_onigiri", 36, pos=[0, 7, 0.5, 0], anchor=[0, 0.5]),
        dyn("FoodName", ["Festival Cake", "Onigiri"], 132, 22, px=18, align="left", textStroke=2,
            pos=[0, 52, 0, 4]),
        frame("FlavorRow", 132, 18, [
            ico("IconFlavorSweet", 16, name="FlavorIcon"),
            dyn("FoodFlavor", ["SEAFOOD", "SWEET"], 108, 18, px=14, colour="soft", align="left",
                font="display", textStroke=2),
        ], layout=row(8, "start"), pos=[0, 52, 0, 34]),
    ], keyline=WHITE, corner=12, depth=4, pos=[0, 112, 0, 268], opens="FoodShop")

    # top centre: slim pills only
    hint = card("TutorialHint", 460, 44, "panel", [
        ico("IconArrow", 26, name="Arrow", pos=[0, 10, 0.5, 0], anchor=[0, 0.5]),
        dyn("ObjectiveLine", ["Buy Festival Cake: open FOODS, or use the Food Cart behind your plot",
                              "Hold THROW (or T) and release near the top of the bar!"],
            406, 40, px=18, wrap=True, align="left", textStroke=2, pos=[0, 44, 0.5, 0], anchor=[0, 0.5]),
    ], comic=4, corner=22, pos=[0.5, 0, 0, 64], anchor=[0.5, 0])
    boost = ibtn("BoostButton", "premium", 104, 56, "IconRobux", "BOOST", icon_side=22, px=20)
    boost["overhang"] = True
    luckbar = card("ServerLuckBar", 360, 44, "panel", [
        ico("IconLuck", 28),
        dyn("Multiplier", ["SERVER x8", "FESTIVAL!"], 120, 30, px=20, colour="luck", font="display",
            textStroke=2),
        dyn("TimeLeft", ["14:59", "2:59"], 64, 28, px=18, textStroke=2),
        boost,
    ], comic=4, corner=22, padding=4, layout=row(10), pos=[0.5, 0, 0, 120], anchor=[0.5, 0])
    announce = card("Announcement", 460, 96, "panel", [
        ico("IconStar", 44, pos=[0, 10, 0, 10]),
        dyn("PlayerName", ["xX_SuperLongName_Xx", "Builderman"], 384, 20, px=16, align="left",
            colour="soft", textStroke=2, pos=[0, 64, 0, 4]),
        dyn("HeroName", ["Heavenly String King", "Copy Ninja"], 384, 30, px=24, align="left",
            font="display", pos=[0, 64, 0, 32]),
        dyn("RarityText", ["LEGENDARY", "SECRET"], 110, 20, px=16, colour="gold", align="left",
            font="display", textStroke=2, pos=[0, 64, 0, 70]),
        dyn("OneInN", ["1 in 48,400,000", "1 in 250"], 200, 20, px=16, colour="gold", align="left",
            textStroke=2, pos=[0, 186, 0, 70]),
    ], keyline="#FACC15", comic=4, pos=[0.5, 0, 0, 64], anchor=[0.5, 0], overhang=True, visible=False, z=6)
    flash = lbl("FlashText", SENTINEL, 400, 64, px=46, colour="buy", font="display",
                samples=["LUCKY THROW!", "PERFECT!"], stroke=4, pos=[0.5, 0, 0, 180], anchor=[0.5, 0],
                visible=False)
    toasts = frame("Toasts", 400, 88, [
        sample(toast_template(text=["Not enough yen for Festival Cake!"], icon_key="IconYen"), 1),
        sample(toast_template(text=["Gift 3 is ready to claim!"], icon_key="IconGift",
                              colour="#1F6E4A"), 2),
    ], layout=col(8, "end"), pos=[0.5, 0, 0, 256], anchor=[0.5, 0])
    return page("HUD", [left, right, yen, power, luck, food, hint, luckbar, announce, flash, toasts],
                kind="hud")


# =================================================================== ThrowMeter

def zone_mark_template(name="ZoneMarkTemplate", hexcol=ZONE_HEX[0], x=0.5):
    return fill_frame(name, hexcol, 12, 62, pos=[x, 0, 0.5, 0], anchor=[0.5, 0.5], corner=6,
                      overhang=True)


def throw_meter():
    marks = [sample(zone_mark_template(hexcol=ZONE_HEX[i], x=x), i + 1)
             for i, x in enumerate([0.14, 0.31, 0.48, 0.66, 0.82])]
    bar = track("ChargeBar", 560, 44, 0.62, "#34D17A", keyline=WHITE,
                pos=[0.5, 0, 1, -164], anchor=[0.5, 1])
    bar["children"].insert(0, {"type": "frame", "name": "PerfectWindow", "colour": ["#FFC93C", "#FFC93C"],
                               "alpha": 0.45, "outline": False, "size": [0.1, 0, 1, 0],
                               "pos": [1, 0, 0, 0], "anchor": [1, 0], "corner": 22, "overhang": True,
                               "children": []})
    bar["children"].append(frame("ZoneMarks", None, None, marks, overhang=True, z=3))
    throw = btn("ThrowButton", "coral", 136, 136, [
        ico("IconThrow", 60, pos=[0.5, 0, 0, 16], anchor=[0.5, 0]),
        lbl("Label", "THROW", 124, 38, px=32, font="display", pos=[0.5, 0, 1, -12], anchor=[0.5, 1]),
    ], pos=[0.5, 0, 1, -14], anchor=[0.5, 1], corner=34)

    def toggle(name, colour, icon_key, title, state_name, samples, pos, anchor):
        return btn(name, colour, 156, 80, [
            ico(icon_key, 44),
            frame("Text", 84, 66, [lbl("Title", title, 84, 28, px=22, font="display"),
                                   dyn(state_name, samples, 84, 30, px=26)], layout=col(8)),
        ], paint=True, layout=row(10), pos=pos, anchor=anchor)

    lucky = toggle("LuckyThrowToggle", "violet", "IconLuckyThrow", "LUCKY", "LuckyCount",
                   ["x999", "x3"], [0.5, -84, 1, -26], [1, 1])
    auto = toggle("AutoToggle", "grey", "IconAuto", "AUTO", "AutoState", ["OFF", "ON"],
                  [0.5, 84, 1, -26], [0, 1])
    zone = dyn("ZonePreviewLabel", ["Hold to charge, release near the top  (best: Realm of Legends)",
                                    "Lands in: Realm of Legends"], 740, 40, px=26, pos=[0.5, 0, 1, -218],
               anchor=[0.5, 1])
    return page("ThrowMeter", [zone, bar, throw, lucky, auto], kind="hud", enabled=False)


# =================================================================== Reveal

def reveal():
    c = card("RevealCard", 660, 270, "panel", [
        {**ribbon("RarityBanner", None, 330, 62, samples=["LEGENDARY", "UNCOMMON"],
                  colour=[RARITY["Legendary"], RARITY["Legendary"]]),
         "selfFace": True, "paintable": True, "pos": [0.5, 0, 0, -34], "anchor": [0.5, 0],
         "overhang": True, "z": 3},
        dyn("HeroName", ["Heavenly String King", "Sun God Captain"], 600, 58, px=42, font="display",
            pos=[0.5, 0, 0, 38], anchor=[0.5, 0]),
        frame("TagRow", 600, 40, [
            chip("SizeTag", "SizeText", ["TITAN", "HUGE"], 124, 40, "info", px=24),
            chip("MutationTag", "MutationText", ["LIGHTNING", "GALAXY"], 160, 40, MUT_HEX["Galaxy"], px=24),
            chip("CravingTag", "CravingText", None, 160, 40, "buy", px=24, static="CRAVING!"),
        ], layout=row(12), pos=[0.5, 0, 0, 104], anchor=[0.5, 0]),
        frame("StatsRow", 620, 52, [
            ico("IconYen", 44, name="YenIcon"),
            dyn("YenPerSecond", ["+999.99Qi/s", "+120/s"], 236, 48, px=34, colour="yen", font="display",
                align="left"),
            chip("OneInNChip", "OneInN", ["1 in 48,400,000", "1 in 40"], 268, 46, "panelDeep", px=26),
        ], layout=row(12), pos=[0.5, 0, 0, 154], anchor=[0.5, 0]),
        dyn("RevealAction", ["sold for 999.99Qi yen", "joins your plot", "sent to your bench"], 600, 32,
            px=24, colour="soft", pos=[0.5, 0, 0, 218], anchor=[0.5, 0]),
        chip("NewStamp", "NewText", None, 150, 58, "danger", px=36, static="NEW!", rotation=-14,
             pos=[0, -26, 0, -24], overhang=True, z=5, visible=False),
        chip("NewBestStamp", "NewBestText", None, 214, 58, "buy", px=32, static="NEW BEST!", rotation=10,
             pos=[1, 46, 0, -24], anchor=[1, 0], overhang=True, z=5, visible=False),
    ], comic=8, pos=[0.5, 0, 1, -66], anchor=[0.5, 1])
    c["children"][0]["children"][0]["name"] = "RarityText"
    for k in c["children"]:
        if k.get("name") in ("NewStamp", "NewBestStamp"):
            k["children"][0]["font"] = "display"
            from mangapop import DISPLAY_TEXTS
            DISPLAY_TEXTS.add(k["children"][0]["text"])
    skip = lbl("SkipHint", "TAP ANYWHERE TO SKIP", 420, 32, px=22, colour="soft",
               pos=[0.5, 0, 1, -16], anchor=[0.5, 1])
    return page("Reveal", [c, skip], kind="overlay")


# =================================================================== FoodShop

FOODS = CFG["Foods"]


def food_card_template(name="FoodCardTemplate", food=FOODS[10], state="price"):
    flav = food["Flavor"]
    colour, cap = {"price": ("buy", short(food["Cost"])), "equip": ("confirm", "EQUIP"),
                   "equipped": ("grey", "EQUIPPED")}[state]
    buy = ibtn("BuyButton", colour, 206, 72, "IconYen", samples=[cap, LONG_NUM, "EQUIPPED"],
               text_name="PriceText", px=26, icon_side=34, paint=True,
               pos=[0.5, 0, 1, -8], anchor=[0.5, 1])
    return {"type": "panel", "name": name, "colour": "cream", "size": [0, 228, 0, 352], "depth": 6,
            "children": [
                chip("TierTag", "TierText", [f"T{food['Tier']}", "T12"], 70, 32, "panel", px=21,
                     pos=[0, 10, 0, 10]),
                ico(f"IconFlavor{flav}", 42, name="FlavorIcon", pos=[1, -10, 0, 6], anchor=[1, 0]),
                viewport("Viewport", 206, 84, FLAVOR_HEX[flav], pos=[0.5, 0, 0, 56], anchor=[0.5, 0],
                         attrs={"FoodId": food["Id"]}),
                dyn("FoodName", [food["Name"], "Festival Cake"], 212, 36, px=28, colour="ink",
                    pos=[0.5, 0, 0, 148], anchor=[0.5, 0]),
                frame("StatRow", 212, 32, [
                    frame("PowerStat", 102, 32, [ico("IconPower", 28, name="PowerIcon"),
                                                 dyn("PowerText", [f"x{food['PowerMult']:.2f}", "x5.00"], 66, 30,
                                                     px=22, colour="powerInk", align="left")],
                          layout=row(8, "start")),
                    frame("LuckStat", 102, 32, [ico("IconLuck", 28, name="LuckIcon"),
                                                dyn("LuckText", [f"x{food['Luck']:.2f}", "x5.50"], 66, 30,
                                                    px=22, colour="luckInk", align="left")],
                          layout=row(8, "start")),
                ], layout=row(8), pos=[0.5, 0, 0, 192], anchor=[0.5, 0]),
                dyn("CraveHint", ["3 NEW HEROES", "ALL FOUND"], 212, 30, px=22, colour="premiumInk",
                    pos=[0.5, 0, 0, 232], anchor=[0.5, 0]),
                buy,
            ]}


def food_shop():
    filt = frame("FlavourFilter", 900, 60, [
        ibtn("FilterAll", "info", 140, 60, "IconShop", "ALL", paint=True, px=24, icon_side=32),
        ibtn("FilterSavory", "panelHi", 184, 60, "IconFlavorSavory", "SAVORY", paint=True, px=24,
             icon_side=32),
        ibtn("FilterSweet", "panelHi", 166, 60, "IconFlavorSweet", "SWEET", paint=True, px=24,
             icon_side=32),
        ibtn("FilterSpicy", "panelHi", 166, 60, "IconFlavorSpicy", "SPICY", paint=True, px=24,
             icon_side=32),
        ibtn("FilterSeafood", "panelHi", 196, 60, "IconFlavorSeafood", "SEAFOOD", paint=True, px=24,
             icon_side=32),
    ], layout=row(12), pos=[0.5, 0, 0, 0], anchor=[0.5, 0])
    cards = [sample(food_card_template(food=FOODS[0], state="equipped"), 1),
             sample(food_card_template(food=FOODS[1], state="equip"), 2),
             sample(food_card_template(food=FOODS[2], state="price"), 3),
             sample(food_card_template(food=FOODS[10], state="price"), 4)]
    scroller = frame("FoodScroller", 962, 384, cards, cls="ScrollingFrame", scroll="X",
                     layout=row(16, "start"), pos=[0.5, 0, 0, 76], anchor=[0.5, 0])
    return page("FoodShop", window("FOOD SHOP", 1010, 570, [filt, scroller]))


# =================================================================== Squad

def hero_row_template(name="HeroRowTemplate", hero="Heavenly String King", rarity="Epic", size="TITAN",
                      mut="Lightning", stars=3, income="+999.99Qi/s", where="ON PLOT 12", on_plot=True,
                      fuse=True):
    return {"type": "panel", "name": name, "colour": "panelHi", "depth": 4, "size": [0, 1084, 0, 96],
            "padding": 10, "layout": row(12, "start"), "children": [
                viewport("Thumb", 76, 76, RARITY[rarity]),
                frame("NameBlock", 376, 76, [
                    dyn("HeroName", [hero, "Heavenly String King"], 272, 36, px=26, align="left",
                        font="display", pos=[0, 0, 0, 0]),
                    frame("Stars", 94, 32, [ico("IconStar", 26, name=f"Star{i}",
                                                **({} if i <= stars else {"mockHide": True}))
                                            for i in (1, 2, 3)], layout=row(8, "start"), pos=[0, 282, 0, 2]),
                    frame("TagRow", 376, 32, [
                        chip("RarityTag", "RarityText", [rarity.upper(), "LEGENDARY"], 134, 32,
                             RARITY[rarity], px=22),
                        chip("SizeTag", "SizeText", [size or "BIG", "TITAN"], 86, 32, "info", px=22),
                        chip("MutationTag", "MutationText", [(mut or "Golden").upper(), "LIGHTNING"], 136,
                             32, MUT_HEX.get(mut or "Golden"), px=22),
                    ], layout=row(8, "start"), pos=[0, 0, 0, 44]),
                ]),
                frame("IncomeBlock", 180, 76, [
                    dyn("IncomeText", [income, "+999.99Qi/s"], 180, 36, px=28, colour="yen", align="left",
                        pos=[0, 0, 0, 2]),
                    dyn("LocationText", [where, "ON PLOT 24"], 180, 28, px=22, colour="soft", align="left",
                        pos=[0, 0, 0, 46]),
                ]),
                ibtn("PlaceButton", "info" if on_plot else "confirm", 136, 60,
                     "IconBench" if on_plot else "IconPlace",
                     samples=["BENCH" if on_plot else "PLACE", "PLACE"], text_name="PlaceText", px=24,
                     icon_side=30, paint=True),
                ibtn("FuseButton", "buy", 116, 60, "IconFuse", "FUSE", px=24, icon_side=28,
                     **({} if fuse else {"mockHide": True})),
                ibtn("SellButton", "danger", 112, 60, "IconSell", "SELL", px=24, icon_side=28),
            ]}


def squad():
    top = frame("TopBar", 1112, 64, [
        ibtn("TabPlot", "info", 196, 64, "IconPlace", samples=["PLOT 8/24", "PLOT 24/24"],
             text_name="SlotCount", paint=True, px=24, icon_side=32),
        ibtn("TabBench", "panelHi", 222, 64, "IconBench", samples=["BENCH 12/30", "BENCH 60/60"],
             text_name="BenchCount", paint=True, px=24, icon_side=32),
        ibtn("AutoSellCommon", "confirm", 196, 64, "IconSell", "AUTO-SELL COMMON", paint=True, px=22,
             icon_side=30, lines=2),
        ibtn("AutoSellUncommon", "grey", 196, 64, "IconSell", "AUTO-SELL UNCOMMON", paint=True, px=22,
             icon_side=30, lines=2),
        ibtn("EquipBest", "buy", 200, 64, "IconStar", "EQUIP BEST", px=24, icon_side=32),
    ], layout=row(12, "start"), pos=[0.5, 0, 0, 0], anchor=[0.5, 0])
    rows = [
        sample(hero_row_template(hero="Sun God Captain", rarity="Mythic", size="TITAN", mut="Galaxy", stars=3,
                                 income="+999.99Qi/s", where="ON PLOT 1"), 1),
        sample(hero_row_template(hero="Bald Cape Hero", rarity="Legendary", size="HUGE", mut="Golden", stars=2,
                                 income="+48.2T/s", where="ON PLOT 2", fuse=False), 2),
        sample(hero_row_template(hero="Heavenly String King", rarity="Epic", size=None, mut="Lightning",
                                 stars=1, income="+1.25B/s", where="ON PLOT 3"), 3),
        sample(hero_row_template(hero="Copy Ninja", rarity="Rare", size="BIG", mut=None, stars=0,
                                 income="+880K/s", where="ON BENCH", on_plot=False, fuse=False), 4),
    ]
    # tags a hero does not have are hidden at runtime; the mockup shows them hidden too
    for r, (has_size, has_mut) in zip(rows, [(1, 1), (1, 1), (0, 1), (1, 0)]):
        tagrow = r["children"][1]["children"][2]
        if not has_size:
            tagrow["children"][1]["mockHide"] = True
        if not has_mut:
            tagrow["children"][2]["mockHide"] = True
    lst = frame("HeroList", 1112, 418, rows, cls="ScrollingFrame", scroll="Y", layout=col(10, "start"),
                pos=[0.5, 0, 0, 76], anchor=[0.5, 0])
    return page("Squad", window("MY SQUAD", 1160, 600, [top, lst]))


# =================================================================== HeroIndex

ZONES = CFG["Zones"]
CHARS = CFG["Characters"]


def hero_tile_template(name="HeroTileTemplate", hero="Heavenly String King", rarity="Epic", craves="Seafood",
                       chance="0.0012%", known=True):
    return {"type": "panel", "name": name, "colour": RARITY[rarity], "paintable": True, "depth": 5,
            "size": [0, 166, 0, 206], "aspect": round(166 / 206, 4), "children": [
                viewport("Portrait", 150, 96, "#12153A" if known else "#05060F", pos=[0.5, 0, 0, 8],
                         anchor=[0.5, 0]),
                dyn("HeroName", [hero if known else "???", "Heavenly String King"], 154, 52, px=22,
                    wrap=True, pos=[0.5, 0, 0, 112], anchor=[0.5, 0]),
                frame("BottomRow", 154, 30, [
                    ico(f"IconFlavor{craves}", 28, name="CraveIcon"),
                    dyn("ChanceText", [chance, "0.0012%"], 108, 28, px=22),
                ], layout=row(8), pos=[0.5, 0, 0, 172], anchor=[0.5, 0]),
            ]}


def hero_index():
    tabs = []
    for i, z in enumerate(ZONES, start=1):
        have = [7, 7, 5, 3, 1, 5][i - 1]
        tot = sum(1 for c in CHARS if c["Zone"] == z["Id"])
        locked = i >= 6 and False
        tab = btn(f"ZoneTab{i}", "info" if i == 6 else "panelHi", 236, 74, [
            lbl("ZoneName", z["Name"], 214, 30, px=21, align="left", pos=[0, 11, 0, 6]),
            track("ZoneBar", 214, 26, min(1, have / tot), ZONE_HEX[i - 1], text_name="ZoneProgress",
                  samples=[f"{have}/{tot}", "8/8"], px=22, pos=[0, 11, 0, 44]),
            ico("IconLock", 30, name="LockIcon", pos=[1, 8, 0, -8], anchor=[1, 0], overhang=True, z=4,
                visible=False, **({} if locked else {"mockHide": True})),
        ], paint=True)
        tabs.append(tab)
    zone_tabs = frame("ZoneTabs", 236, 494, tabs, layout=col(10, "start"), pos=[0, 0, 0, 0])
    header = frame("ZoneHeader", 880, 60, [
        dyn("ZoneTitle", ["Realm of Legends", "Sakura Schoolyard"], 294, 44, px=32, font="display",
            align="left"),
        chip("TotalProgress", "TotalText", ["TOTAL 43/43", "TOTAL 28/43"], 200, 48, "panelDeep", px=22),
        dyn("LuckNote", ["Luck x999.9", "Luck x2.75"], 150, 40, px=22, colour="luck"),
        ibtn("ZoneRewardClaim", "confirm", 200, 60, "IconGift", samples=["5/8 FOUND", "CLAIM!", "CLAIMED"],
             text_name="ClaimText", px=22, icon_side=32, paint=True),
    ], layout=row(12, "start"), pos=[0, 252, 0, 0])
    realm = [c for c in CHARS if c["Zone"] == "realm_of_legends"]
    chances = ["41.20%", "28.80%", "14.10%", "6.200%", "6.200%", "1.420%", "1.420%", "0.0012%"]
    known = [True, True, True, True, False, True, False, False]
    tiles = [sample(hero_tile_template(hero=c["Name"], rarity=c["Rarity"], craves=c["Craves"], chance=ch,
                                       known=k), i + 1)
             for i, (c, ch, k) in enumerate(zip(realm, chances, known))]
    grid = frame("HeroGrid", 880, 424, tiles, cls="ScrollingFrame", scroll="Y",
                 layout={"type": "grid", "cell": [166, 206], "gap": 12, "cols": 5}, pos=[0, 252, 0, 76])
    return page("HeroIndex", window("HERO INDEX", 1180, 610, [zone_tabs, header, grid]))


# =================================================================== Store

PASS_NAMES = {"DoubleYen": ("2x Yen", "IconYen"), "DoubleTraining": ("2x Training", "IconTrain"),
              "Vip": ("VIP", "IconCrown"), "AutoThrow": ("Auto Throw", "IconAuto"),
              "LuckyAura": ("Lucky Aura", "IconLuck"), "BigBench": ("Big Bench", "IconBench")}
PRODUCT_NAMES = {"LuckyThrow1": ("1 Lucky Throw", "IconLuckyThrow"), "LuckyThrow5": ("5 Lucky Throws", "IconLuckyThrow"),
                 "LuckyThrow25": ("25 Lucky Throws", "IconLuckyThrow"), "ServerLuck": ("Server Luck", "IconLuck"),
                 "YenPack15m": ("15 min Yen", "IconYen"), "YenPack2h": ("2 hour Yen", "IconYen"),
                 "YenPack12h": ("12 hour Yen", "IconYen"), "Train5m": ("5 min Training", "IconTrain"),
                 "Train30m": ("30 min Training", "IconTrain"), "OfflineDouble": ("2x Offline", "IconTimer")}


def pass_card_template(name="PassCardTemplate", key="DoubleTraining", robux=149, owned=False):
    title, icon_key = PASS_NAMES[key]
    return {"type": "panel", "name": name, "colour": "panelHi", "depth": 4, "size": [0, 186, 0, 214],
            "attrs": {"PassKey": key}, "children": [
                ico(icon_key, 52, pos=[0.5, 0, 0, 10], anchor=[0.5, 0]),
                dyn("PassName", [title, "2x Training"], 170, 32, px=24, pos=[0.5, 0, 0, 70], anchor=[0.5, 0]),
                ibtn("PassBuyButton", "grey" if owned else "premium", 166, 86, "IconRobux",
                     samples=["OWNED" if owned else str(robux), "OWNED"], text_name="PassPrice", px=24,
                     icon_side=28, paint=True, pos=[0.5, 0, 1, -10], anchor=[0.5, 1]),
            ]}


def product_card_template(name="ProductCardTemplate", key="LuckyThrow25", robux=149):
    title, icon_key = PRODUCT_NAMES[key]
    return {"type": "panel", "name": name, "colour": "panelHi", "depth": 4, "size": [0, 186, 0, 170],
            "attrs": {"ProductKey": key}, "children": [
                ico(icon_key, 46, pos=[0, 10, 0, 10]),
                dyn("ProductName", [title, "30 min Training"], 116, 58, px=21, wrap=True, align="left",
                    pos=[0, 64, 0, 4]),
                ibtn("ProductBuyButton", "premium", 166, 86, "IconRobux", samples=[str(robux), "599"],
                     text_name="ProductPrice", px=24, icon_side=28, paint=True,
                     pos=[0.5, 0, 1, -10], anchor=[0.5, 1]),
            ]}


def store():
    mon = CFG["Monetization"]
    passes = {p["Key"]: p for p in mon["Passes"]}
    prods = {p["Key"]: p for p in mon["Products"]}
    summon = {p["Key"]: p for p in mon["Products"] if p["Kind"] == "summon"}

    def buy(n):
        p = summon[f"SummonScroll{n}"]
        return btn(f"SummonBuy{n}", "premium", 104, 86, [
            lbl("Count", f"x{n}", 92, 34, px=30, font="display"),
            frame("PriceRow", 96, 30, [ico("IconRobux", 24), lbl("Price", str(p["Robux"]), 58, 28, px=22,
                                                                   align="left")], layout=row(8)),
        ], layout=col(8))

    banner = card("SummonBanner", 360, 584, ["#8B5CF6", "#4C1D95"], [
        lbl("SummonTitle", "SUMMON SCROLL", 330, 46, px=34, font="display", colour="buy", pos=[0.5, 0, 0, 14],
            anchor=[0.5, 0]),
        lbl("SummonSub", "6 exclusive heroes!", 330, 30, px=24, pos=[0.5, 0, 0, 68], anchor=[0.5, 0]),
        viewport("SummonViewport", 330, 156, "#1E0B4B", pos=[0.5, 0, 0, 106], anchor=[0.5, 0]),
        ibtn("OddsButton", "info", 240, 86, "IconInfo", "SEE ODDS", px=26, icon_side=34, opens="SummonOdds",
             pos=[0.5, 0, 0, 272], anchor=[0.5, 0]),
        frame("BuyRow", 336, 86, [buy(1), buy(3), buy(10)], layout=row(12), pos=[0.5, 0, 0, 374],
              anchor=[0.5, 0]),
        lbl("SummonNote", "See the odds first!", 330, 30, px=22, colour="soft", pos=[0.5, 0, 0, 476],
            anchor=[0.5, 0]),
    ], pattern={"name": "sheen", "colour": "#FFFFFF", "opacity": 0.14}, pos=[0, 0, 0, 0])
    starter = card("StarterPackBanner", 786, 100, ["#FFC93C", "#FF5A5F"], [
        ico("IconGift", 66, pos=[0, 14, 0.5, 0], anchor=[0, 0.5]),
        lbl("StarterTitle", "STARTER PACK", 300, 40, px=32, font="display", align="left", pos=[0, 94, 0, 10]),
        lbl("StarterDesc", "Lucky Cat hero + 5 Lucky Throws + 2x Yen", 500, 32, px=22, align="left",
            pos=[0, 94, 0, 58]),
        ibtn("StarterBuyButton", "premium", 166, 64, "IconRobux", samples=[str(prods["StarterPack"]["Robux"]),
                                                                           "OWNED"],
             text_name="StarterPrice", px=26, icon_side=30, pos=[1, -16, 0.5, 0], anchor=[1, 0.5]),
    ], pattern={"name": "stripes", "colour": "#FFFFFF", "opacity": 0.16, "tile": 96}, pos=[0, 376, 0, 0])
    pass_cards = [sample(pass_card_template(key=k, robux=passes[k]["Robux"], owned=(k == "DoubleYen")), i + 1)
                  for i, k in enumerate(["DoubleYen", "DoubleTraining", "AutoThrow", "LuckyAura"])]
    prod_cards = [sample(product_card_template(key=k, robux=prods[k]["Robux"]), i + 1)
                  for i, k in enumerate(["LuckyThrow5", "ServerLuck", "YenPack2h", "Train30m"])]
    gift = ibtn("GiftTarget", "info", 252, 60, "IconGift", samples=["GIFT A FRIEND", "FOR: Builderman"],
                text_name="GiftTargetText", px=21, icon_side=30, pos=[1, -104, 0, -20], anchor=[1, 0],
                overhang=True, z=4)
    body = [
        banner, starter,
        lbl("PassesTitle", "PASSES", 300, 26, px=22, font="display", align="left", colour="buy",
            pos=[0, 376, 0, 108]),
        frame("PassScroller", 786, 218, pass_cards, cls="ScrollingFrame", scroll="X", layout=row(12, "start"),
              pos=[0, 376, 0, 142]),
        lbl("ItemsTitle", "ITEMS", 300, 26, px=22, font="display", align="left", colour="buy",
            pos=[0, 376, 0, 368]),
        frame("ProductScroller", 786, 174, prod_cards, cls="ScrollingFrame", scroll="X",
              layout=row(12, "start"), pos=[0, 376, 0, 402]),
    ]
    return page("Store", window("STORE", 1210, 690, body, ribbon_w=340, extra=[gift]))


# =================================================================== SummonOdds

PREMIUM = [p for p in CFG["PremiumCharacters"] if p["Source"] == "Summon"]
ODDS_HEX = ["#34D17A", "#38BDF8", "#A855F7", "#FF4FA3", "#FACC15", "#FB3B6B"]


def odds_row_template(name="OddsRowTemplate", hero=PREMIUM[5], hexcol=ODDS_HEX[5]):
    return {"type": "panel", "name": name, "colour": "panelHi", "depth": 4, "size": [0, 792, 0, 50],
            "padding": 5, "layout": row(14, "start"), "attrs": {"HeroId": hero["Id"]}, "children": [
                viewport("Portrait", 40, 40, hexcol),
                lbl("HeroName", hero["Name"], 300, 34, px=26, align="left"),
                lbl("OddsEarn", f"{hero['BestIncomeMult']:g}x your best", 260, 30, px=22,
                    colour="soft", align="left"),
                chip("OddsChip", "OddsPercent", None, 110, 40, hexcol, px=26, static=f"{hero['OddsPercent']:g}%"),
            ]}


def summon_odds():
    rows = []
    for i, (h, c) in enumerate(zip(PREMIUM, ODDS_HEX), start=1):
        rows.append(odds_row_template(name=f"OddsRow{i}", hero=h, hexcol=c))
    summon = {p["Key"]: p for p in CFG["Monetization"]["Products"] if p["Kind"] == "summon"}
    buys = [ibtn(f"OddsBuy{n}", "premium", 200, 60, "IconRobux", f"x{n}  {summon[f'SummonScroll{n}']['Robux']}",
                 px=24, icon_side=28) for n in (1, 3, 10)]
    body = [
        lbl("OddsNote", "Every Summon Scroll gives ONE of these heroes:", 792, 28, px=22, colour="soft",
            pos=[0.5, 0, 0, 0], anchor=[0.5, 0]),
        frame("OddsList", 792, 340, rows, layout=col(8, "start"), pos=[0.5, 0, 0, 36], anchor=[0.5, 0]),
        lbl("Total", f"TOTAL: {sum(p['OddsPercent'] for p in PREMIUM):g}%", 300, 32, px=24, colour="buy",
            font="display", pos=[0.5, 0, 0, 384], anchor=[0.5, 0]),
        frame("BuyButtons", 640, 60, buys, layout=row(16), pos=[0.5, 0, 0, 424], anchor=[0.5, 0]),
    ]
    return page("SummonOdds", window("SUMMON ODDS", 840, 590, body), displayOrder=12)


# =================================================================== OfflineEarnings

def offline():
    o = CFG["Offline"]
    body = [
        dyn("AwayTime", ["You were away 7h 59m", "You were away 2m"], 600, 40, px=28,
            pos=[0.5, 0, 0, 8], anchor=[0.5, 0]),
        panel("EarnedRow", 520, 96, "panelDeep", [
            ico("IconYen", 70),
            dyn("EarnedAmount", ["+999.99Qi", "+1.2K"], 380, 72, px=54, colour="yen", font="display"),
        ], layout=row(14), pos=[0.5, 0, 0, 64], anchor=[0.5, 0]),
        lbl("CapNote", f"Your heroes earned {int(o['Rate'] * 100)}% while you were away (max {o['CapHours']}h)",
            620, 30, px=22, colour="soft", pos=[0.5, 0, 0, 176], anchor=[0.5, 0]),
        frame("Buttons", 600, 80, [
            ibtn("ClaimButton", "confirm", 240, 80, "IconTick", "CLAIM", px=34, icon_side=40, font="display"),
            btn("DoubleButton", "premium", 280, 80, [
                lbl("Label", "2X", 70, 46, px=40, font="display"),
                ico("IconRobux", 30),
                dyn("DoublePrice", [str(next(p["Robux"] for p in CFG["Monetization"]["Products"]
                                             if p["Key"] == "OfflineDouble")), "999"], 70, 36, px=28,
                    align="left"),
            ], layout=row(10)),
        ], layout=row(24), pos=[0.5, 0, 0, 230], anchor=[0.5, 0]),
    ]
    return page("OfflineEarnings", window("WELCOME BACK!", 720, 470, body, ribbon_w=460))


# =================================================================== Rebirth

def rebirth():
    def keep_list(name, title, colour, icon_key, items, pos, anchor):
        return panel(name, 460, 196, "panelHi", [
            lbl("Title", title, 300, 30, px=24, font="display", colour=colour, align="left", pos=[0, 16, 0, 10]),
            frame("List", 428, 136, [frame(f"Item{i}", 428, 28, [ico(icon_key, 26),
                                                                   lbl("Text", t, 384, 28, px=22, align="left")],
                                           layout=row(10, "start")) for i, t in enumerate(items, 1)],
                  layout=col(8, "start"), pos=[0, 16, 0, 48]),
        ], depth=4, pos=pos, anchor=anchor)

    req = panel("Requirements", 560, 200, "panelHi", [
        lbl("ReqTitle", "NEXT REBIRTH", 260, 32, px=26, font="display", align="left", pos=[0, 16, 0, 10]),
        dyn("NextTier", ["REBIRTH 999", "REBIRTH 1"], 220, 32, px=24, colour="buy", align="right",
            pos=[1, -16, 0, 10], anchor=[1, 0]),
        ico("IconPower", 40, name="PowerIcon", pos=[0, 16, 0, 60]),
        track("PowerBar", 460, 40, 0.82, "#38BDF8", text_name="PowerReqText",
              samples=["999.99Qi / 999.99Qi", "98.4M / 120M"], px=24, pos=[0, 68, 0, 60]),
        ico("IconYen", 40, name="YenIcon", pos=[0, 16, 0, 126]),
        track("YenBar", 460, 40, 0.44, "#34D17A", text_name="YenReqText",
              samples=["999.99Qi / 999.99Qi", "220B / 500B"], px=24, pos=[0, 68, 0, 126]),
    ], depth=4)
    reward = card("Rewards", 360, 200, ["#FFE27A", "#FFB020"], [
        lbl("RewardTitle", "REWARD", 320, 34, px=28, font="display", pos=[0.5, 0, 0, 10], anchor=[0.5, 0]),
        dyn("RewardIncome", ["+50% INCOME", "+150% INCOME"], 330, 40, px=30, font="display", colour="confirm",
            pos=[0.5, 0, 0, 54], anchor=[0.5, 0]),
        dyn("RewardLuck", ["+10% LUCK", "+30% LUCK"], 330, 40, px=30, font="display", colour="info",
            pos=[0.5, 0, 0, 102], anchor=[0.5, 0]),
        lbl("RewardForever", "FOREVER!", 330, 30, px=24, pos=[0.5, 0, 0, 152], anchor=[0.5, 0]),
    ], pos=[1, 0, 0, 0], anchor=[1, 0])
    keeps = keep_list("Keeps", "YOU KEEP", "confirm", "IconTick",
                      ["Hero Index", "Game passes", "Premium heroes", "Lucky Throws"], [0, 0, 0, 214], [0, 0])
    resets = keep_list("Resets", "YOU LOSE", "danger", "IconClose",
                       ["Yen and power", "Foods and gear", "Plot slots", "Caught heroes"], [1, 0, 0, 214], [1, 0])
    body = [req, reward, keeps, resets,
            dyn("CurrentRebirth", ["You are at Rebirth 999", "You are at Rebirth 0"], 460, 40, px=26,
                colour="soft", align="left", pos=[0, 0, 0, 444]),
            ibtn("ConfirmButton", "buy", 320, 80, "IconRebirth", "REBIRTH!", px=34, icon_side=44,
                 font="display", paint=True, pos=[1, 0, 0, 424], anchor=[1, 0])]
    return page("Rebirth", window("REBIRTH", 980, 610, body))


# =================================================================== DailyRewards

def daily_cell_template(name="DailyCellTemplate", day=7, state="future"):
    r = CFG["Rewards"]
    mins = r["DailyYenMinutes"][day - 1]
    lucky = r["DailyLuckyThrowsOnDay"].get(str(day), 0)
    text = f"{mins} min yen" + (f" +{lucky} Lucky" if lucky else "")
    colour = {"claimed": "grey", "today": "buy", "future": "panelHi"}[state]
    return {"type": "panel", "name": name, "colour": colour, "paintable": True, "depth": 5,
            "size": [0, 132, 0, 186], "children": [
                lbl("DayLabel", f"DAY {day}", 116, 30, px=24, font="display", pos=[0.5, 0, 0, 8], anchor=[0.5, 0]),
                ico("IconLuckyThrow" if lucky else "IconYen", 60, pos=[0.5, 0, 0, 46], anchor=[0.5, 0]),
                dyn("RewardText", [text, "60 min yen +5 Lucky"], 124, 60, px=22, wrap=True, font="display",
                    pos=[0.5, 0, 0, 116], anchor=[0.5, 0]),
                ico("IconTick", 48, name="ClaimedTick", pos=[1, 10, 0, -10], anchor=[1, 0], overhang=True, z=4,
                    visible=False, **({} if state == "claimed" else {"mockHide": True})),
            ]}


def daily():
    cells = [daily_cell_template(name=f"DayCell{d}", day=d,
                                 state="claimed" if d < 5 else "today" if d == 5 else "future")
             for d in range(1, 8)]
    for c in cells:
        c["props"] = {}
    body = [
        dyn("StreakLabel", ["5 DAY STREAK!  +10% LUCK", "1 DAY STREAK!"], 640, 36, px=26, colour="buy",
            font="display", pos=[0.5, 0, 0, 0], anchor=[0.5, 0]),
        frame("DayStrip", 1012, 190, cells, layout=row(12), pos=[0.5, 0, 0, 46], anchor=[0.5, 0]),
        ibtn("ClaimButton", "confirm", 300, 76, "IconGift", samples=["CLAIM DAY 5", "TOMORROW"], text_name="ClaimText",
             px=28, icon_side=40, font="display", paint=True, pos=[0.5, 0, 0, 250], anchor=[0.5, 0]),
        dyn("NextIn", ["Next reward in 23:59:59", "Ready now!"], 420, 30, px=22, colour="soft",
            pos=[0.5, 0, 0, 338], anchor=[0.5, 0]),
    ]
    return page("DailyRewards", window("DAILY REWARDS", 1060, 480, body, ribbon_w=460))


# =================================================================== PlaytimeGifts

def gift_cell_template(name="GiftCellTemplate", i=6, state="wait"):
    mins = CFG["Rewards"]["PlaytimeMinutes"][i - 1]
    colour, icon_key, cap = {"claimed": ("grey", "IconTick", "CLAIMED"), "ready": ("confirm", "IconGift", "CLAIM!"),
                             "wait": ("panelDeep", "IconTimer", f"{mins - 12}:59")}[state]
    return {"type": "panel", "name": name, "colour": "panelHi", "depth": 5, "size": [0, 284, 0, 166],
            "aspect": round(284 / 166, 4), "children": [
                ico("IconGift", 72, pos=[0, 12, 0, 12]),
                lbl("GiftTitle", f"GIFT {i}", 170, 34, px=26, font="display", align="left", pos=[0, 98, 0, 14]),
                lbl("GiftWhen", f"after {mins} min", 170, 28, px=22, colour="soft", align="left",
                    pos=[0, 98, 0, 56]),
                ibtn("GiftButton", colour, 260, 60, icon_key, samples=[cap, "CLAIMED", "59:59"], text_name="GiftState",
                     px=24, icon_side=30, paint=True, pos=[0.5, 0, 1, -10], anchor=[0.5, 1]),
            ]}


def playtime():
    cells = [gift_cell_template(name=f"GiftCell{i}", i=i,
                                state="claimed" if i <= 2 else "ready" if i == 3 else "wait")
             for i in range(1, 7)]
    body = [
        dyn("Timer", ["Played today: 59:59", "Played today: 3:12"], 520, 34, px=24, colour="soft",
            pos=[0.5, 0, 0, 0], anchor=[0.5, 0]),
        frame("GiftGrid", 880, 346, cells, layout={"type": "grid", "cell": [284, 166], "gap": 14, "cols": 3},
              pos=[0.5, 0, 0, 46], anchor=[0.5, 0]),
    ]
    return page("PlaytimeGifts", window("FREE GIFTS", 940, 500, body))


# =================================================================== Codes

def codes():
    body = [
        lbl("CodesHint", "Join the group to find new codes!", 600, 34, px=24, colour="soft",
            pos=[0.5, 0, 0, 0], anchor=[0.5, 0]),
        frame("CodeRow", 620, 72, [
            card("CodeField", 430, 72, "panelDeep", [
                ico("IconCodes", 44, pos=[0, 12, 0.5, 0], anchor=[0, 0.5]),
                lbl("CodeBox", "TYPE A CODE", 350, 48, px=28, colour="soft", align="left", cls="TextBox",
                    pos=[0, 66, 0.5, 0], anchor=[0, 0.5]),
            ], comic=4),
            ibtn("RedeemButton", "confirm", 176, 72, "IconTick", "REDEEM", px=26, icon_side=34),
        ], layout=row(14), pos=[0.5, 0, 0, 48], anchor=[0.5, 0]),
        dyn("ResultLabel", ["Code redeemed! +3 Lucky Throws", "That code has expired"], 600, 34, px=24,
            colour="confirm", pos=[0.5, 0, 0, 140], anchor=[0.5, 0]),
    ]
    return page("Codes", window("CODES", 680, 340, body, ribbon_w=320), displayOrder=12)


# =================================================================== Settings

def settings():
    def setting_row(name, icon_key, text, controls):
        return panel(name, 732, 64, "panelHi", [
            ico(icon_key, 40, pos=[0, 14, 0.5, 0], anchor=[0, 0.5]),
            lbl("RowLabel", text, 280, 34, px=24, align="left", pos=[0, 66, 0.5, 0], anchor=[0, 0.5]),
            *controls,
        ], depth=4)

    def slider(prefix, value):
        t = track(f"{prefix}Slider", 260, 22, value, "#34D17A", pos=[1, -100, 0.5, 0], anchor=[1, 0.5])
        t["children"].append(btn(f"{prefix}Knob", "onDark", 56, 56, [ico("IconMusic" if prefix == "Music" else "IconSfx",
                                                                        30, pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5])],
                                 corner=28, depth=3, pos=[value, 0, 0.5, 0], anchor=[0.5, 0.5], overhang=True, z=3,
                                 centre=False))
        return [t, dyn(f"{prefix}Value", [f"{int(value * 100)}%", "100%"], 76, 30, px=22, align="right",
                       pos=[1, -12, 0.5, 0], anchor=[1, 0.5])]

    def toggle(name, on, text=None, w=150, x=-12):
        return ibtn(name, "confirm" if on else "grey", w, 56, "IconTick" if on else "IconClose",
                    text=text, samples=None if text else (["ON", "OFF"] if on else ["OFF", "ON"]),
                    text_name=f"{name}State" if not text else "Label", px=24, icon_side=28, paint=True,
                    pos=[1, x, 0.5, 0], anchor=[1, 0.5])

    rows = [
        setting_row("MusicRow", "IconMusic", "Music", slider("Music", 0.7)),
        setting_row("SfxRow", "IconSfx", "Sound effects", slider("Sfx", 1.0)),
        setting_row("FastRevealRow", "IconFast", "Fast reveal", [toggle("FastReveal", True)]),
        setting_row("LowDetailRow", "IconLowDetail", "Low detail", [toggle("LowDetail", False)]),
        setting_row("HideOthersRow", "IconHide", "Hide other plots", [toggle("HideOtherPlots", False)]),
        setting_row("AutoSellRow", "IconSell", "Auto-sell when full", [
            toggle("AutoSellCommon", True, text="COMMON", w=160, x=-210),
            toggle("AutoSellUncommon", False, text="UNCOMMON", w=188, x=-12)]),
        setting_row("CodesRow", "IconCodes", "Redeem a code", [
            ibtn("CodesButton", "info", 170, 56, "IconCodes", "CODES", px=24, icon_side=30, opens="Codes",
                 pos=[1, -12, 0.5, 0], anchor=[1, 0.5])]),
    ]
    # the slider knob value text is dynamic; the static "%" samples above are the longest
    body = [frame("Rows", 732, 496, rows, layout=col(8, "start"), pos=[0.5, 0, 0, 0], anchor=[0.5, 0])]
    return page("Settings", window("SETTINGS", 780, 610, body))


# =================================================================== TrainingBar

def training():
    p = card("TrainingPanel", 660, 172, "panel", [
        dyn("RankName", ["CHAMPION", "ROOKIE"], 250, 38, px=30, font="display", colour="power", align="left",
            pos=[0, 16, 0, 10]),
        dyn("GearName", ["on Gravity Dojo", "on Wooden Dummy"], 330, 34, px=24, colour="soft", align="right",
            pos=[1, -16, 0, 12], anchor=[1, 0]),
        track("ProgressBar", 628, 40, 0.58, "#38BDF8", text_name="ProgressText",
              samples=["999.99Qi / 999.99Qi  ->  LEGEND", "120 / 200  ->  TRAINEE"], px=24,
              pos=[0.5, 0, 0, 56], anchor=[0.5, 0]),
        ico("IconPower", 40, name="PowerIcon", pos=[0, 16, 0, 110]),
        dyn("PowerPerRep", ["+11.00K power per rep", "+1 power per rep"], 330, 36, px=26, colour="power",
            align="left", pos=[0, 64, 0, 112]),
        ibtn("StopButton", "danger", 170, 60, "IconClose", "STOP", px=28, icon_side=30, font="display",
             pos=[1, -16, 0, 104], anchor=[1, 0]),
    ], pos=[0.5, 0, 1, -16], anchor=[0.5, 1])
    up = ibtn("UpgradePrompt", "buy", 500, 60, "IconTrain", samples=["NEW GEAR: Dragon Shrine 999.99Qi",
                                                                     "NEW GEAR: Sandbag 600"],
              text_name="UpgradeText", px=22, icon_side=34, pos=[0.5, 0, 1, -204], anchor=[0.5, 1], visible=False)
    return page("TrainingBar", [up, p], kind="hud", enabled=False)


# =================================================================== world GUIs

def nameplate():
    kids = [
        dyn("HeroName", ["Heavenly String King", "Copy Ninja"], 312, 40, px=30, font="display",
            pos=[0.5, 0, 0, 4], anchor=[0.5, 0]),
        frame("TagRow", 312, 30, [
            chip("SizeTag", "SizeText", ["TITAN", "BIG"], 86, 30, "info", px=21),
            chip("MutationTag", "MutationText", ["LIGHTNING", "GOLDEN"], 120, 30, MUT_HEX["Lightning"], px=21),
        ], layout=row(8), pos=[0.5, 0, 0, 50], anchor=[0.5, 0]),
        frame("BottomRow", 312, 36, [
            ico("IconYen", 30, name="YenIcon"),
            dyn("YenPerSecond", ["+999.99Qi/s", "+12/s"], 150, 32, px=26, colour="yen", font="display"),
            frame("Stars", 94, 28, [ico("IconStar", 26, name=f"Star{i}") for i in (1, 2, 3)], layout=row(8)),
        ], layout=row(10), pos=[0.5, 0, 0, 90], anchor=[0.5, 0]),
    ]
    return {"name": "Nameplate", "theme": "theme.json", "resolution": [320, 132], "kind": "world",
            "rootClass": "BillboardGui", "children": kids,
            "rootProps": {"Size": {"UDim2": [[0, 320], [0, 132]]}, "StudsOffset": {"Vector3": [0, 4.5, 0]},
                          "MaxDistance": 60, "AlwaysOnTop": False, "LightInfluence": 0, "ClipsDescendants": False}}


def leaderboard_row_template(name="LeaderboardRowTemplate", rank=10, player="xX_SuperLongName_Xx", score=LONG_NUM):
    medal = {1: "#FACC15", 2: "#CBD5E1", 3: "#F59E0B"}.get(rank, "#2B3175")
    return {"type": "panel", "name": name, "colour": "panelHi", "paintable": True, "depth": 4,
            "size": [0, 730, 0, 64], "padding": 6, "layout": row(12, "start"), "children": [
                chip("RankBadge", "RankText", [str(rank), "10"], 52, 52, medal, px=30),
                {"type": "frame", "name": "AvatarWell", "colour": ["#12153A", "#12153A"], "size": [0, 52, 0, 52],
                 "corner": 26, "children": [ico("PlayerHeadshot", 36, name="Avatar", pos=[0.5, 0, 0.5, 0],
                                                anchor=[0.5, 0.5])]},
                dyn("PlayerName", [player, "xX_SuperLongName_Xx"], 350, 44, px=32, align="left"),
                dyn("Score", [score, "1 in 48,400,000"], 220, 44, px=30, colour="yen", align="right"),
            ]}


def leaderboard():
    people = [("Builderman", "999.99Qi"), ("SakuraNinja77", "512.4Qi"), ("xX_SuperLongName_Xx", "88.1Qi"),
              ("RamenLord", "3.2Qa"), ("TitanTosser", "940T"), ("LuckyCatFan", "201T"), ("OnigiriKid", "48T"),
              ("ZoneRunner", "9.9T"), ("PirateCook", "1.2T"), ("NewbieNoob", "800B")]
    rows = [leaderboard_row_template(name=f"Row{i}", rank=i, player=p, score=s)
            for i, (p, s) in enumerate(people, start=1)]
    board = card("Board", 770, 970, "panel", [
        ribbon("TitleRibbon", None, 520, 96, samples=["RAREST CATCH", "MOST YEN", "MOST CAUGHT"], px=54,
               pos=[0.5, 0, 0, 18], anchor=[0.5, 0]),
        frame("HeaderRow", 730, 40, [lbl("RankHead", "#", 64, 36, px=28, colour="soft"),
                                     lbl("PlayerHead", "PLAYER", 410, 36, px=28, colour="soft", align="left"),
                                     lbl("ScoreHead", "SCORE", 220, 36, px=28, colour="soft", align="right")],
              layout=row(12, "start"), pos=[0.5, 0, 0, 130], anchor=[0.5, 0]),
        frame("Rows", 730, 712, rows, layout=col(8, "start"), pos=[0.5, 0, 0, 178], anchor=[0.5, 0]),
        lbl("Footer", "Updates every minute", 600, 40, px=28, colour="soft", pos=[0.5, 0, 1, -16],
            anchor=[0.5, 1]),
    ], comic=10, corner=30, pos=[0.5, -5, 0.5, -5], anchor=[0.5, 0.5], centre=False)
    # the ribbon title is the board's dynamic title
    board["children"][0]["children"][0]["name"] = "BoardTitle"
    return {"name": "Leaderboard", "theme": "theme.json", "resolution": [800, 1000], "kind": "world",
            "rootClass": "SurfaceGui", "children": [board],
            "rootProps": {"SizingMode": "FixedSize", "CanvasSize": {"Vector2": [800, 1000]}, "Face": "Front",
                          "LightInfluence": 0, "AlwaysOnTop": False}}


def slot_sign():
    sign = card("Sign", 580, 280, "panel", [
        dyn("FromTo", ["SLOT 23 -> 24", "SLOT 8 -> 9"], 540, 60, px=46, font="display", pos=[0.5, 0, 0, 20],
            anchor=[0.5, 0]),
        frame("PriceRow", 540, 70, [ico("IconYen", 60), dyn("Price", [LONG_NUM, "1.5K"], 300, 64, px=52,
                                                             colour="yen", font="display")],
              layout=row(14), pos=[0.5, 0, 0, 96], anchor=[0.5, 0]),
        dyn("BuyPrompt", ["Walk in to buy this slot", "Not enough yen"], 540, 40, px=28, colour="soft",
            pos=[0.5, 0, 0, 192], anchor=[0.5, 0]),
    ], comic=8, pos=[0.5, -4, 0.5, -4], anchor=[0.5, 0.5], centre=False)
    return {"name": "SlotSign", "theme": "theme.json", "resolution": [600, 300], "kind": "world",
            "rootClass": "SurfaceGui", "children": [sign],
            "rootProps": {"SizingMode": "FixedSize", "CanvasSize": {"Vector2": [600, 300]}, "Face": "Front",
                          "LightInfluence": 0, "AlwaysOnTop": False}}


SCREENS = [hud, throw_meter, reveal, food_shop, squad, hero_index, store, summon_odds, offline, rebirth,
           daily, playtime, codes, settings, training, nameplate, leaderboard, slot_sign]

# (template builder, the screen it belongs to)
TEMPLATES = [
    (food_card_template, "FoodShop"), (hero_row_template, "Squad"), (hero_tile_template, "HeroIndex"),
    (pass_card_template, "Store"), (product_card_template, "Store"), (daily_cell_template, "DailyRewards"),
    (gift_cell_template, "PlaytimeGifts"), (leaderboard_row_template, "Leaderboard"), (toast_template, "HUD"),
    (zone_mark_template, "ThrowMeter"), (odds_row_template, "SummonOdds"),
]
