"""UI v3: every button from the mp3 system, native 720p page layouts (no shrink), names kept.

Paths that had to change are listed in design/ui/CHANGES-v3.md.
"""

from __future__ import annotations

import copy

import mp3  # noqa: F401  (installs the emitter additions)
import screens as v1
import screens_v2 as v2
from mangapop import (WHITE, card, chip, dyn, fill_frame, frame, ico, lbl, panel, ribbon, row, col, sample,
                      viewport, window, close_button)
from mp3 import T, est_w, state_pill, tag, vbtn, vbtn2, vscroll
from screens import CFG, LONG_NUM, MUT_HEX, RARITY, page
from screens_v2 import find

FLAVOR_TILE = {"Savory": "#F2A541", "Sweet": "#FF8CC6", "Spicy": "#FF6A3D", "Seafood": "#2EC4B6"}
CREAM_CHIP = "#F1E3C2"
INKSOFT = "#3A3F6B"


def win(title, body_w, body_h, body, ribbon_w=360, extra=(), top=84):
    w, h = body_w + 48, body_h + top + 22
    kids = window(title, w, h, body, ribbon_w=ribbon_w, extra=list(extra))
    b = find({"children": kids}, "Body")
    b["pos"] = [0.5, 0, 0, top]
    return kids


def big(key):
    return key + "Big"


# =================================================================== HUD (system fixes only)

def hud():
    spec = v2.hud()
    root = {"children": spec["children"]}
    for nm, colour in (("BtnShop", "buy"), ("BtnSquad", "info"), ("BtnIndex", "violet"), ("BtnStore", "premium"),
                       ("BtnGift", "confirm"), ("BtnRebirth", "buy")):
        b = find(root, nm)
        b["sizeClass"] = "HUD"
        icon = next(k for k in b["children"] if k.get("type") == "icon")
        icon["icon"] = big(icon["icon"])
        capn = find(b, "Caption")
        capn.update({"size": [0, 92, 0, 18], "textScale": round(14 / 18, 4), "maxText": 14, "textStroke": 2,
                     "pos": [0.5, 0, 1, 8], "anchor": [0.5, 0]})
        badge = find(b, "Badge")
        badge.update({"size": [0, 24, 0, 24], "pos": [1, 6, 0, -6], "anchor": [1, 0], "corner": 12})
        badge["children"][0].update({"size": [0, 16, 0, 20], "textScale": round(14 / 20, 4), "maxText": 14})
    gift = find(root, "BtnGift")
    gt = find(gift, "GiftTimerBadge")
    gt.update({"size": [0, 64, 0, 20], "pos": [0.5, 0, 1, 0], "anchor": [0.5, 0.5], "z": 5})
    gt["children"][0].update({"size": [0, 56, 0, 16], "textScale": round(12 / 16, 4), "maxText": 12,
                              "textStroke": 1})
    find(gift, "Caption")["pos"] = [0.5, 0, 1, 12]
    find(root, "LeftColumn").update({"pos": [0, 20, 0, 104]})
    find(root, "RightColumn").update({"pos": [1, -20, 0, 228]})
    # settings: a 44 px gear in the top-right corner, clear of the player list and the hint
    find(root, "BtnSettings")["pos"] = [0, 950, 0, 12]
    gb = find(find(root, "BtnSettings"), "Badge")
    gb.update({"size": [0, 24, 0, 24], "pos": [1, 6, 0, -6], "anchor": [1, 0], "corner": 12})
    gb["children"][0].update({"size": [0, 16, 0, 20], "textScale": round(14 / 20, 4), "maxText": 14})
    fc = find(root, "FoodChip")
    fc["sizeClass"] = "HUD"
    # hint: a pill that grows with its text (AutomaticSize X, TextSize 16), capped at 60% of 1280
    hint = find(root, "TutorialHint")
    ol = find(hint, "ObjectiveLine")
    longest = max(ol["samples"], key=len)
    wtxt = int(est_w(longest, 16, display=False)) + 4
    hint.update({"size": [0, 40 + wtxt + 16, 0, 36], "autoX": 768, "selfFace": True})
    ol.update({"size": [0, wtxt, 0, 24], "textScale": round(16 / 24, 4), "maxText": 16, "autoX": True,
               "pos": [0, 40, 0.5, 0], "anchor": [0, 0.5], "textStroke": 2})
    # notice card: S/M system buttons
    nc = find(root, "NoticeCard")
    nb = vbtn("NoticeButton", "confirm", "S", icon="IconShop", samples=["SHOP", "BUY"], text_name="NoticeButtonText",
              pos=[1, -12, 1, -12], anchor=[1, 1])
    nc["children"] = [nb if k.get("name") == "NoticeButton" else k for k in nc["children"]]
    nc["size"] = [0, 340, 0, 84]
    find(nc, "NoticeTitle").update({"size": [0, 160, 0, 20], "textScale": 0.7, "maxText": 14, "pos": [0, 70, 0, 10]})
    find(nc, "NoticeBody").update({"size": [0, 160, 0, 38], "wrap": True, "textScale": round(14 / 38, 4),
                                   "maxText": 14, "pos": [0, 70, 0, 34]})
    lb = find(root, "ServerLuckBar")
    lb["children"] = [vbtn("BoostButton", "premium", "S", icon="IconRobux", w=34) if k.get("name") == "BoostButton"
                      else k for k in lb["children"]]
    for t in find(root, "Toasts")["children"]:
        tx = find(t, "Text")
        tx.update({"textScale": round(14 / 22, 4), "maxText": 14})
    return spec


# =================================================================== ThrowMeter / TrainingBar

def throw_meter():
    spec = v2.throw_meter()
    root = {"children": spec["children"]}
    face = vbtn("ThrowButtonFace", "coral", "L", icon="IconThrow", text="THROW", pos=[0.5, 0, 1, -18],
                anchor=[0.5, 1], z=3, self_face=False)
    face["sizeClass"] = "L"

    def toggle(name, colour, icon_key, title, state_name, samples, pos, anchor):
        n = vbtn2(name, colour, "L", title, icon_key, samples, price_name=state_name, top_name="Title", w=124,
                  pos=pos, anchor=anchor, z=3)
        n["selfFace"] = True
        return n
    lucky = toggle("LuckyThrowToggle", "violet", "IconLuckyThrow", "LUCKY", "LuckyCount", ["x999", "x3"],
                   [0.5, -92, 1, -24], [1, 1])
    auto = toggle("AutoToggle", "grey", "IconAuto", "AUTO", "AutoState", ["OFF", "ON"], [0.5, 92, 1, -24], [0, 1])
    spec["children"] = [face if k.get("name") == "ThrowButtonFace" else lucky if k.get("name") == "LuckyThrowToggle"
                        else auto if k.get("name") == "AutoToggle" else k for k in spec["children"]]
    tap = find(root, "TapLabel")
    tap.update({"pos": [0.5, 0, 0, 572], "size": [0, 420, 0, 44], "textScale": round(34 / 44, 4), "maxText": 34,
                "textStroke": 3})
    return spec


def training():
    spec = v1.training()
    root = {"children": spec["children"]}
    p = find(root, "TrainingPanel")
    p["children"] = [vbtn("StopButton", "danger", "M", icon="IconClose", text="STOP", pos=[1, -16, 0, 110],
                          anchor=[1, 0]) if k.get("name") == "StopButton" else k for k in p["children"]]
    up = vbtn("UpgradePrompt", "confirm", "M", icon="IconTrain",
              samples=["NEW GEAR: Dragon Shrine 999.99Qi", "NEW GEAR: Sandbag 600"], text_name="UpgradeText",
              pos=[0.5, 0, 1, -204], anchor=[0.5, 1], visible=False, self_face=False)
    spec["children"] = [up if k.get("name") == "UpgradePrompt" else k for k in spec["children"]]
    for k in p["children"]:
        if k.get("type") == "label":
            k["textStroke"] = min(3, k.get("textStroke", 3))
    return spec


# =================================================================== FoodShop

FOODS = v1.FOODS


def food_card_template(name="FoodCardTemplate", food=FOODS[2], state="afford", nxt=False, dim=False):
    flav = food["Flavor"]
    cost = v1.short(food["Cost"])
    if state == "equipped":
        buy = state_pill("BuyButton", "PriceText", ["EQUIPPED"], "M")
    elif state == "equip":
        buy = vbtn("BuyButton", "info", "M", icon="IconTick", samples=["EQUIP", LONG_NUM], text_name="PriceText",
                   maxw=144)
    elif state == "afford":
        buy = vbtn("BuyButton", "confirm", "M", icon="IconYen", samples=[cost, LONG_NUM], text_name="PriceText",
                   maxw=144)
    else:
        buy = vbtn("BuyButton", "slate", "M", icon="IconYen", samples=[cost, LONG_NUM], text_name="PriceText",
                   text_colour="softRed", maxw=144)
    buy.update({"pos": [0.5, 0, 1, -10], "anchor": [0.5, 1]})
    kids = [
        chip("TierTag", "TierText", [f"T{food['Tier']}", "T12"], 40, 22, "panel", px=12,
             pos=[0, 10, 0, 10]),
        ico(f"IconFlavor{flav}", 22, name="FlavorIcon", pos=[1, -10, 0, 10], anchor=[1, 0]),
        {"type": "frame", "name": "ArtTile", "colour": [FLAVOR_TILE[flav], v1.shade_hex(FLAVOR_TILE[flav])]
         if hasattr(v1, "shade_hex") else [FLAVOR_TILE[flav], FLAVOR_TILE[flav]], "paint": FLAVOR_TILE[flav],
         "size": [0, 148, 0, 100], "pos": [0.5, 0, 0, 40], "anchor": [0.5, 0], "corner": 12, "children": [
             {**ico("FxSunburst", 120, name="Sunburst", pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5]), "z": 1,
              "overhang": True},
             {"type": "frame", "name": "Viewport", "transparent": True, "cls": "ViewportFrame",
              "size": [0, 136, 0, 78], "pos": [0.5, 0, 0.5, 0], "anchor": [0.5, 0.5], "children": [],
              "attrs": {"FoodId": food["Id"]}, "z": 2},
         ]},
        T("FoodName", None, 148, 16, colour="ink", font="display", samples=[food["Name"], "Festival Cake"],
          pos=[0.5, 0, 0, 148], anchor=[0.5, 0]),
        frame("StatRow", 148, 20, [
            panel("PowerStat", 70, 20, CREAM_CHIP, [ico("IconPower", 14, name="PowerIcon"),
                                                    T("PowerText", None, 44, 12, colour="powerInk", font="display",
                                                      samples=[f"x{food['PowerMult']:g}", "x5.00"])],
                  layout=row(3), depth=0, corner=10),
            panel("LuckStat", 70, 20, CREAM_CHIP, [ico("IconLuck", 14, name="LuckIcon"),
                                                   T("LuckText", None, 44, 12, colour="luckInk", font="display",
                                                     samples=[f"x{food['Luck']:g}", "x5.50"])],
                  layout=row(3), depth=0, corner=10),
        ], layout=row(8), pos=[0.5, 0, 0, 176], anchor=[0.5, 0]),
        panel("CravePill", 104, 18, "premium", [T("CraveHint", None, 96, 12, samples=["+11 heroes", "+3 heroes"],
                                                    font="display")],
              depth=0, corner=9, pos=[0.5, 0, 0, 202], anchor=[0.5, 0]),
        buy,
    ]
    if nxt:
        kids.append(tag("NextTag", "NEXT", colour="buy", corner="tl"))
    else:
        kids.append({**tag("NextTag", "NEXT", colour="buy", corner="tl"), "visible": False, "mockHide": True})
    c = {"type": "panel", "name": name, "colour": "cream", "size": [0, 168, 0, 274], "depth": 5, "corner": 16,
         "aspect": round(168 / 274, 4), "children": kids}
    if nxt:
        c["keyline"] = "#FFC93C"
    if dim:
        c["colour"] = "#D9CFBA"
    return c


def food_shop():
    def tab(n, icon, text, on):
        return vbtn(n, "info" if on else "panelHi", "S", icon=icon, text=text)
    filt = frame("FlavourFilter", 740, 34, [
        tab("FilterAll", "IconShop", "ALL", True), tab("FilterSavory", "IconFlavorSavory", "SAVORY", False),
        tab("FilterSweet", "IconFlavorSweet", "SWEET", False), tab("FilterSpicy", "IconFlavorSpicy", "SPICY", False),
        tab("FilterSeafood", "IconFlavorSeafood", "SEAFOOD", False)], layout=row(8, "start"), pos=[0, 0, 0, 0])
    cards = [sample(food_card_template(food=FOODS[0], state="equipped"), 1),
             sample(food_card_template(food=FOODS[1], state="equip"), 2),
             sample(food_card_template(food=FOODS[2], state="afford", nxt=True), 3),
             sample(food_card_template(food=FOODS[3], state="locked", dim=True), 4)]
    grid = vscroll("FoodScroller", 740, 300, cards, {"type": "grid", "cell": [168, 274], "gap": 12, "cols": 4},
                   pos=[0, 0, 0, 42])
    return page("FoodShop", win("FOOD SHOP", 740, 342, [filt, grid]))


# =================================================================== Squad

def hero_row_template(name="HeroRowTemplate", hero="Heavenly String King", rarity="Epic", size="TITAN",
                      mut="Lightning", stars=3, income="+999.99Qi/s", where="ON PLOT 12", on_plot=True, fuse=True):
    chips = [chip("RarityTag", "RarityText", [rarity.upper(), "LEGENDARY"], 96, 20, RARITY[rarity], px=12),
             chip("SizeTag", "SizeText", [size or "BIG", "TITAN"], 62, 20, "info", px=12,
                  **({} if size else {"mockHide": True})),
             chip("MutationTag", "MutationText", [(mut or "Golden").upper(), "LIGHTNING"], 96, 20,
                  MUT_HEX.get(mut or "Golden"), px=12, **({} if mut else {"mockHide": True}))]
    return {"type": "panel", "name": name, "colour": "panelHi", "depth": 3, "corner": 14, "size": [0, 870, 0, 64],
            "padding": 6, "layout": row(10, "start"), "children": [
                fill_frame("RarityStripe", RARITY[rarity], 6, 48, corner=3),
                viewport("Thumb", 52, 52, RARITY[rarity]),
                frame("NameBlock", 300, 52, [
                    T("HeroName", None, 210, 16, font="display", align="left", samples=[hero, "Heavenly String King"],
                      pos=[0, 0, 0, 2]),
                    frame("Stars", 54, 14, [ico("IconStar", 14, name=f"Star{i}",
                                                **({} if i <= stars else {"mockHide": True})) for i in (1, 2, 3)],
                          layout=row(6, "start"), pos=[0, 218, 0, 4]),
                    frame("TagRow", 300, 20, chips, layout=row(6, "start"), pos=[0, 0, 0, 30]),
                ]),
                frame("IncomeBlock", 140, 52, [
                    T("IncomeText", None, 140, 20, colour="yen", font="display", align="left",
                      samples=[income, "+999.99Qi/s"], pos=[0, 0, 0, 2]),
                    T("LocationText", None, 140, 12, colour="soft", align="left", samples=[where, "ON PLOT 24"],
                      font="display", pos=[0, 0, 0, 32]),
                ]),
                vbtn("PlaceButton", "info" if on_plot else "confirm", "S",
                     icon="IconBench" if on_plot else "IconPlace",
                     samples=["BENCH" if on_plot else "PLACE", "PLACE"], text_name="PlaceText"),
                vbtn("FuseButton", "buy", "S", icon="IconFuse", text="FUSE", self_face=False,
                     **({} if fuse else {"mockHide": True})),
                vbtn("SellButton", "danger", "S", icon="IconSell", text="SELL", self_face=False),
            ]}


def squad():
    top = frame("TopBar", 900, 34, [
        vbtn("TabPlot", "info", "S", icon="IconPlace", samples=["PLOT 9/9", "PLOT 24/24"], text_name="SlotCount"),
        vbtn("TabBench", "panelHi", "S", icon="IconBench", samples=["BENCH 5/30", "BENCH 60/60"],
             text_name="BenchCount"),
        vbtn("AutoSellCommon", "confirm", "S", icon="IconSell", text="SELL COMMON"),
        vbtn("AutoSellUncommon", "panelHi", "S", icon="IconSell", text="SELL UNCOMMON"),
        vbtn("EquipBest", "buy", "S", icon="IconStar", text="EQUIP BEST", self_face=False),
    ], layout=row(8, "start"), pos=[0, 0, 0, 0])
    rows = [sample(hero_row_template(hero="Sun God Captain", rarity="Mythic", size="TITAN", mut="Galaxy", stars=3,
                                     income="+999.99Qi/s", where="ON PLOT 1"), 1),
            sample(hero_row_template(hero="Bald Cape Hero", rarity="Legendary", size="HUGE", mut="Golden", stars=2,
                                     income="+48.2T/s", where="ON PLOT 2", fuse=False), 2),
            sample(hero_row_template(hero="Heavenly String King", rarity="Epic", size=None, mut="Lightning", stars=1,
                                     income="+1.25B/s", where="ON PLOT 3"), 3),
            sample(hero_row_template(hero="Copy Ninja", rarity="Rare", size="BIG", mut=None, stars=0,
                                     income="+880K/s", where="ON BENCH", on_plot=False, fuse=False), 4)]
    lst = vscroll("HeroList", 900, 300, rows, col(8, "start"), pos=[0, 0, 0, 42])
    return page("Squad", win("MY SQUAD", 900, 342, [top, lst]))


# =================================================================== HeroIndex

def hero_tile_template(name="HeroTileTemplate", hero="Heavenly String King", rarity="Epic", craves="Seafood",
                       chance="0.0012%", known=True):
    port = viewport("Portrait", 124, 80, "#12153A" if known else "#0B0D24", pos=[0.5, 0, 0, 6], anchor=[0.5, 0])
    port["children"] = [{**T("UnknownMark", "?", 60, 34, font="display", colour="onDark",
                             pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5]),
                         "props": {"TextColor3": {"Color3": [c / 255 for c in v1_rgb(RARITY[rarity])]}},
                         **({} if not known else {"visible": False, "mockHide": True})}]
    return {"type": "panel", "name": name, "colour": RARITY[rarity] if known else "#23264F", "paintable": True,
            "depth": 4, "corner": 14, "size": [0, 136, 0, 158], "aspect": round(136 / 158, 4), "children": [
                port,
                fill_frame("RarityStripe", RARITY[rarity], 124, 5, corner=2, pos=[0.5, 0, 0, 90], anchor=[0.5, 0],
                           z=2),
                T("HeroName", None, 124, 14, wrap=True, samples=[hero if known else "???", "Heavenly String King"],
                  pos=[0.5, 0, 0, 98], anchor=[0.5, 0]),
                frame("BottomRow", 124, 16, [ico(f"IconFlavor{craves}", 16, name="CraveIcon"),
                                             T("ChanceText", None, 80, 12, font="display", samples=[chance, "0.0012%"])],
                      layout=row(6), pos=[0.5, 0, 0, 136], anchor=[0.5, 0]),
            ]}


def v1_rgb(h):
    from mangapop import ub
    return ub.hex_rgb(h)


def hero_index():
    tabs = []
    for i, z in enumerate(v1.ZONES, start=1):
        have = [7, 7, 5, 3, 1, 5][i - 1]
        tot = max(1, sum(1 for c in v1.CHARS if c["Zone"] == z["Id"]))
        locked = i == 6
        tabs.append({"type": "button", "name": f"ZoneTab{i}", "colour": "info" if i == 1 else "panelHi",
                     "selfFace": True, "paintable": True, "sizeClass": "L", "depth": 3, "corner": 14,
                     "size": [0, 196, 0, 56], "children": [
                         T("ZoneName", z["Name"], 156, 14, align="left", font="display", pos=[0, 20, 0, 8]),
                         v1.track("ZoneBar", 156, 18, min(1, have / tot), v1.ZONE_HEX[i - 1], text_name="ZoneProgress",
                                  samples=[f"{have}/{tot}", "8/8"], px=12, pos=[0, 20, 0, 30]),
                         ico("IconLock", 18, name="LockIcon", pos=[1, -2, 0, 4], anchor=[1, 0],
                             visible=False, **({} if locked else {"mockHide": True})),
                     ]})
    zone_tabs = vscroll("ZoneTabs", 210, 392, tabs, col(8, "start"), pad=4, pos=[0, 0, 0, 0])
    header = frame("ZoneHeader", 610, 34, [
        T("ZoneTitle", None, 200, 20, font="display", align="left", samples=["Realm of Legends", "Sakura Schoolyard"]),
        chip("TotalProgress", "TotalText", ["TOTAL 43/51", "TOTAL 8/51"], 110, 24, "panelDeep", px=14),
        T("LuckNote", None, 110, 14, colour="luck", samples=["Luck x999.9", "Luck x1.01"]),
        vbtn("ZoneRewardClaim", "confirm", "S", icon="IconGift", samples=["CLAIM!", "5/8 FOUND", "CLAIMED"],
             text_name="ClaimText"),
    ], layout=row(10, "start"), pos=[0, 222, 0, 0])
    realm = [c for c in v1.CHARS if c["Zone"] == "realm_of_legends"][:8]
    chances = ["41.20%", "28.80%", "14.10%", "6.200%", "6.200%", "1.420%", "1.420%", "0.0012%"]
    known = [True, True, True, True, False, True, False, False]
    tiles = [sample(hero_tile_template(hero=c["Name"], rarity=c["Rarity"], craves=c["Craves"], chance=ch, known=k),
                    n + 1) for n, (c, ch, k) in enumerate(zip(realm, chances, known))]
    grid = vscroll("HeroGrid", 610, 340, tiles, {"type": "grid", "cell": [136, 158], "gap": 10, "cols": 4},
                   pos=[0, 222, 0, 42])
    return page("HeroIndex", win("HERO INDEX", 832, 392, [zone_tabs, header, grid]))


# =================================================================== Store

def pass_card_template(name="PassCardTemplate", key="DoubleTraining", robux=149, owned=False):
    title, icon_key = v1.PASS_NAMES[key]
    btn_ = (state_pill("PassBuyButton", "PassPrice", ["OWNED"], "M") if owned else
            vbtn("PassBuyButton", "premium", "M", icon="IconRobux", samples=[str(robux), "999"], text_name="PassPrice"))
    btn_.update({"pos": [0.5, 0, 1, -8], "anchor": [0.5, 1]})
    return {"type": "panel", "name": name, "colour": "panelHi", "depth": 4, "corner": 14, "size": [0, 136, 0, 150],
            "attrs": {"PassKey": key}, "children": [
                ico(big(icon_key), 48, pos=[0.5, 0, 0, 8], anchor=[0.5, 0]),
                T("PassName", None, 120, 14, wrap=True, font="display", samples=[title, "2x Training"],
                  pos=[0.5, 0, 0, 60], anchor=[0.5, 0]),
                btn_]}


def product_card_template(name="ProductCardTemplate", key="LuckyThrow25", robux=149, stick=None):
    title, icon_key = v1.PRODUCT_NAMES[key]
    b = vbtn("ProductBuyButton", "premium", "M", icon="IconRobux", samples=[str(robux), "599"],
             text_name="ProductPrice", pos=[0.5, 0, 1, -8], anchor=[0.5, 1])
    st = tag("Sticker", stick or "BEST VALUE", colour="danger", text_name="StickerText")
    st["children"][0].update({"text": "<unbound>", "samples": [stick or "BEST VALUE", "BEST VALUE", "LIMITED"]})
    if not stick:
        st.update({"visible": False, "mockHide": True})
    return {"type": "panel", "name": name, "colour": "panelHi", "depth": 4, "corner": 14, "size": [0, 136, 0, 150],
            "attrs": {"ProductKey": key}, "children": [
                ico(big(icon_key), 48, pos=[0.5, 0, 0, 8], anchor=[0.5, 0]),
                T("ProductName", None, 120, 14, wrap=True, font="display", samples=[title, "30 min Training"],
                  pos=[0.5, 0, 0, 60], anchor=[0.5, 0]),
                b, st]}


def store():
    mon = CFG["Monetization"]
    passes = {p["Key"]: p for p in mon["Passes"]}
    prods = {p["Key"]: p for p in mon["Products"]}
    summon = {p["Key"]: p for p in mon["Products"] if p["Kind"] == "summon"}
    b1 = vbtn2("SummonBuy1", "premium", "L", "x1", "IconRobux", [str(summon["SummonScroll1"]["Robux"]), "999"])
    b3 = vbtn2("SummonBuy3", "premium", "L", "x3", "IconRobux", [str(summon["SummonScroll3"]["Robux"]), "999"])
    b10 = vbtn2("SummonBuy10", "confirm", "L", "x10", "IconRobux", [str(summon["SummonScroll10"]["Robux"]), "999"])
    b10["keyline"] = "#FFC93C"
    row_w = b1["size"][1] + b3["size"][1] + b10["size"][1] + 16
    banner = card("SummonBanner", row_w + 20, 454, ["#8B5CF6", "#4C1D95"], [
        T("SummonTitle", "SUMMON SCROLL", 270, 26, colour="buy", font="display", pos=[0.5, 0, 0, 10],
          anchor=[0.5, 0]),
        T("SummonSub", "6 exclusive heroes", 270, 14, pos=[0.5, 0, 0, 48], anchor=[0.5, 0]),
        viewport("SummonViewport", 268, 216, "#1E0B4B", pos=[0.5, 0, 0, 72], anchor=[0.5, 0]),
        vbtn("OddsButton", "info", "S", icon="IconInfo", text="SEE ODDS", opens="SummonOdds", pos=[0.5, 0, 0, 296],
             anchor=[0.5, 0], self_face=False),
        frame("BuyRow", row_w, 56, [b1, b3, b10], layout=row(8, "center"), pos=[0.5, 0, 0, 356], anchor=[0.5, 0]),
        tag("BestValueSticker", "BEST VALUE", colour="buy", text_name="BestValueText",
            pos=[1, -6, 0, 338], anchor=[1, 0]),
        T("SummonNote", "Odds are shown before you buy", 270, 12, colour="soft", pos=[0.5, 0, 0, 424],
          anchor=[0.5, 0]),
        tag("NewSticker", "NEW!", colour="danger", text_name="NewStickerText"),
    ], comic=6, pattern={"name": "sheen", "colour": "#FFFFFF", "opacity": 0.12}, pos=[0, 0, 0, 0])
    sbtn = vbtn("StarterBuyButton", "premium", "M", icon="IconRobux",
                samples=[str(prods["StarterPack"]["Robux"]), "OWNED"], text_name="StarterPrice",
                pos=[1, -12, 0.5, 0], anchor=[1, 0.5])
    starter = card("StarterPackBanner", 580, 76, ["#FFC93C", "#FF5A5F"], [
        ico("IconGiftBig", 52, pos=[0, 12, 0.5, 0], anchor=[0, 0.5]),
        T("StarterTitle", "STARTER PACK", 300, 20, font="display", align="left", pos=[0, 74, 0, 10]),
        T("StarterDesc", "Lucky Cat hero + 5 Lucky Throws + 2x Yen", 330, 14, align="left", pos=[0, 74, 0, 42]),
        sbtn,
        tag("LimitedSticker", "LIMITED", colour="danger", text_name="LimitedStickerText", corner="tl"),
    ], comic=4, pattern={"name": "stripes", "colour": "#FFFFFF", "opacity": 0.14, "tile": 96})
    pass_cards = [sample(pass_card_template(key=k, robux=passes[k]["Robux"], owned=(k == "DoubleYen")), i + 1)
                  for i, k in enumerate(["DoubleYen", "DoubleTraining", "AutoThrow", "LuckyAura"])]
    prod_cards = [sample(product_card_template(key=k, robux=prods[k]["Robux"],
                                               stick="BEST VALUE" if k == "YenPack12h" else None), i + 1)
                  for i, k in enumerate(["LuckyThrow5", "ServerLuck", "YenPack12h", "Train30m"])]
    gridl = {"type": "grid", "cell": [136, 150], "gap": 12, "cols": 4}
    scroll = vscroll("StoreScroll", 600, 454, [
        starter,
        T("PassesTitle", "PASSES", 580, 20, colour="buy", font="display", align="left"),
        frame("PassScroller", 580, 150, pass_cards, layout=gridl, props={"AutomaticSize": "Y"}),
        T("ItemsTitle", "ITEMS", 580, 20, colour="buy", font="display", align="left"),
        frame("ProductScroller", 580, 150, prod_cards, layout=gridl, props={"AutomaticSize": "Y"}),
    ], col(8, "start"), pos=[1, 0, 0, 0], anchor=[1, 0])
    gift = vbtn("GiftTarget", "info", "S", icon="IconGift", samples=["GIFT A FRIEND", "FOR: Builderman"],
                text_name="GiftTargetText", pos=[1, -92, 0, 40], anchor=[1, 0], z=3)
    kids = win("STORE", banner["size"][1] + 12 + 600, 454, [banner, scroll], ribbon_w=300, extra=[gift])
    return page("Store", kids)


# =================================================================== small windows

def offline():
    body = [
        T("AwayTime", None, 420, 16, samples=["You were away 7h 59m", "You were away 2m"], pos=[0.5, 0, 0, 0],
          anchor=[0.5, 0]),
        panel("EarnedRow", 360, 64, "panelDeep", [
            ico("IconYenBig", 48), T("EarnedAmount", None, 270, 34, colour="yen", font="display",
                                     samples=["+999.99Qi", "+1.2K"], align="left")],
              layout=row(12, "center"), depth=0, pos=[0.5, 0, 0, 30], anchor=[0.5, 0]),
        T("CapNote", "Your heroes earned 50% while you were away (max 8h)", 440, 14, colour="soft",
          pos=[0.5, 0, 0, 104], anchor=[0.5, 0]),
        frame("Buttons", 440, 56, [
            vbtn("ClaimButton", "confirm", "L", icon="IconTick", text="CLAIM", self_face=False),
            {**vbtn("DoubleButton", "premium", "M", icon="IconRobux", samples=["2X  39", "2X  999"],
                    text_name="DoublePrice", self_face=False)},
        ], layout=row(14, "center"), pos=[0.5, 0, 0, 134], anchor=[0.5, 0]),
    ]
    return page("OfflineEarnings", win("WELCOME BACK!", 452, 190, body, ribbon_w=320))


def daily():
    r = CFG["Rewards"]
    cells = []
    for d in range(1, 8):
        state = "claimed" if d < 5 else "today" if d == 5 else "future"
        mins = r["DailyYenMinutes"][d - 1]
        lucky = r["DailyLuckyThrowsOnDay"].get(str(d), 0)
        text = f"{mins} min yen" + (f" +{lucky} Lucky" if lucky else "")
        cells.append({"type": "panel", "name": f"DayCell{d}", "paintable": True, "depth": 4, "corner": 14,
                      "colour": {"claimed": "#5C628F", "today": "buy", "future": "panelHi"}[state],
                      "keyline": "#FFFFFF" if state == "today" else None, "size": [0, 96, 0, 132], "children": [
                          T("DayLabel", f"DAY {d}", 84, 14, font="display", pos=[0.5, 0, 0, 6], anchor=[0.5, 0]),
                          ico("IconLuckyThrowBig" if lucky else "IconYenBig", 48, name="Icon", pos=[0.5, 0, 0, 30],
                              anchor=[0.5, 0]),
                          T("RewardText", None, 84, 12, wrap=True, font="display",
                            samples=[text, "60 min yen +5 Lucky"], pos=[0.5, 0, 0, 88], anchor=[0.5, 0]),
                          ico("IconTick", 22, name="ClaimedTick", pos=[1, 8, 0, -8], anchor=[1, 0], z=4, overhang=True,
                              visible=False, **({} if state == "claimed" else {"mockHide": True})),
                      ]})
        if cells[-1]["keyline"] is None:
            del cells[-1]["keyline"]
    body = [
        T("StreakLabel", None, 500, 16, colour="buy", font="display", samples=["5 DAY STREAK!  +10% LUCK",
                                                                            "1 DAY STREAK!"],
          pos=[0.5, 0, 0, 0], anchor=[0.5, 0]),
        frame("DayStrip", 720, 132, cells, layout=row(8, "center"), pos=[0.5, 0, 0, 30], anchor=[0.5, 0]),
        vbtn("ClaimButton", "confirm", "L", icon="IconGift", samples=["CLAIM DAY 5", "TOMORROW"], text_name="ClaimText",
             pos=[0.5, 0, 0, 176], anchor=[0.5, 0]),
        T("NextIn", None, 400, 12, colour="soft", samples=["Next reward in 23:59:59", "Ready now!"],
          pos=[0.5, 0, 0, 240], anchor=[0.5, 0]),
    ]
    return page("DailyRewards", win("DAILY REWARDS", 720, 256, body, ribbon_w=380))


def playtime():
    cells = []
    for i in range(1, 7):
        mins = CFG["Rewards"]["PlaytimeMinutes"][i - 1]
        state = "claimed" if i <= 2 else "ready" if i == 3 else "wait"
        if state == "claimed":
            gb = state_pill("GiftButton", "GiftState", ["CLAIMED"], "S")
        elif state == "ready":
            gb = vbtn("GiftButton", "confirm", "S", icon="IconGift", samples=["CLAIM!", "59:59"], text_name="GiftState")
        else:
            gb = vbtn("GiftButton", "slate", "S", icon="IconTimer", samples=[f"{mins - 1}:59", "59:59"],
                      text_name="GiftState", text_colour="soft")
        gb.update({"pos": [0, 72, 1, -10], "anchor": [0, 1]})
        cells.append({"type": "panel", "name": f"GiftCell{i}", "colour": "panelHi", "depth": 4, "corner": 14,
                      "size": [0, 220, 0, 100], "aspect": 2.2, "children": [
                          ico("IconGiftBig", 52, name="Icon", pos=[0, 10, 0.5, 0], anchor=[0, 0.5]),
                          T("GiftTitle", f"GIFT {i}", 136, 16, font="display", align="left", pos=[0, 72, 0, 8]),
                          T("GiftWhen", f"after {mins} min", 136, 12, colour="soft", align="left",
                            pos=[0, 72, 0, 32]),
                          gb]})
    body = [T("Timer", None, 400, 14, colour="soft", samples=["Played today: 59:59", "Played today: 3:12"],
              pos=[0.5, 0, 0, 0], anchor=[0.5, 0]),
            frame("GiftGrid", 688, 214, cells, layout={"type": "grid", "cell": [220, 100], "gap": 14, "cols": 3},
                  pos=[0.5, 0, 0, 28], anchor=[0.5, 0])]
    return page("PlaytimeGifts", win("FREE GIFTS", 688, 242, body))


def codes():
    body = [
        T("CodesHint", "Join the group to find new codes!", 420, 14, colour="soft", pos=[0.5, 0, 0, 0],
          anchor=[0.5, 0]),
        frame("CodeRow", 440, 44, [
            panel("CodeField", 300, 44, "panelDeep", [
                ico("IconCodes", 22, pos=[0, 12, 0.5, 0], anchor=[0, 0.5]),
                {**T("CodeBox", "TYPE A CODE", 248, 20, colour="soft", align="left", font="display",
                     pos=[0, 44, 0.5, 0], anchor=[0, 0.5]), "cls": "TextBox"},
            ], keyline=WHITE, depth=0, corner=14),
            vbtn("RedeemButton", "confirm", "M", icon="IconTick", text="REDEEM", self_face=False),
        ], layout=row(12, "center"), pos=[0.5, 0, 0, 28], anchor=[0.5, 0]),
        T("ResultLabel", None, 420, 14, colour="confirm", samples=["Code redeemed! +3 Lucky Throws",
                                                                  "That code has expired"],
          pos=[0.5, 0, 0, 84], anchor=[0.5, 0]),
    ]
    return page("Codes", win("CODES", 452, 104, body, ribbon_w=260), displayOrder=12)


def settings():
    def srow(name, icon_key, text, controls):
        return panel(name, 600, 44, "panelHi", [
            ico(icon_key, 22, pos=[0, 12, 0.5, 0], anchor=[0, 0.5]),
            T("RowLabel", text, 230, 16, align="left", pos=[0, 44, 0.5, 0], anchor=[0, 0.5]),
            *controls], depth=3, corner=14)

    def slider(prefix, value):
        t = v1.track(f"{prefix}Slider", 200, 14, value, "#34D17A", pos=[1, -76, 0.5, 0], anchor=[1, 0.5])
        knob = vbtn(f"{prefix}Knob", "onDark", "S", icon="IconMusic" if prefix == "Music" else "IconSfx", w=34,
                    pos=[value, 0, 0.5, 0], anchor=[0.5, 0.5], overhang=True, z=3, centre=False, self_face=False)
        t["children"].append(knob)
        return [t, T(f"{prefix}Value", None, 52, 12, align="right", font="display",
                     samples=[f"{int(value * 100)}%", "100%"], pos=[1, -12, 0.5, 0], anchor=[1, 0.5])]

    def toggle(name, on, text=None, x=-12):
        return vbtn(name, "confirm" if on else "slate", "S", icon="IconTick" if on else "IconClose",
                    text=text, samples=None if text else (["ON", "OFF"] if on else ["OFF", "ON"]),
                    text_name=f"{name}State" if not text else "Label", pos=[1, x, 0.5, 0], anchor=[1, 0.5])
    unc = toggle("AutoSellUncommon", False, text="UNCOMMON")
    com = toggle("AutoSellCommon", True, text="COMMON", x=-12 - unc["size"][1] - 8)
    rows = [srow("MusicRow", "IconMusic", "Music", slider("Music", 0.7)),
            srow("SfxRow", "IconSfx", "Sound effects", slider("Sfx", 1.0)),
            srow("FastRevealRow", "IconFast", "Fast reveal", [toggle("FastReveal", True)]),
            srow("LowDetailRow", "IconLowDetail", "Low detail", [toggle("LowDetail", False)]),
            srow("HideOthersRow", "IconHide", "Hide other plots", [toggle("HideOtherPlots", False)]),
            srow("AutoSellRow", "IconSell", "Auto-sell when full", [com, unc]),
            srow("CodesRow", "IconCodes", "Redeem a code", [
                vbtn("CodesButton", "info", "S", icon="IconCodes", text="CODES", opens="Codes", pos=[1, -12, 0.5, 0],
                     anchor=[1, 0.5], self_face=False)])]
    body = [frame("Rows", 600, 356, rows, layout=col(8, "start"), pos=[0.5, 0, 0, 0], anchor=[0.5, 0])]
    return page("Settings", win("SETTINGS", 600, 356, body, ribbon_w=300))


def summon_odds():
    prem = [p for p in CFG["PremiumCharacters"] if p["Source"] == "Summon"]
    rows = []
    for i, (h, c) in enumerate(zip(prem, v1.ODDS_HEX), start=1):
        rows.append({"type": "panel", "name": f"OddsRow{i}", "colour": "panelHi", "depth": 3, "corner": 12,
                     "size": [0, 600, 0, 40], "padding": 4, "layout": row(12, "start"),
                     "attrs": {"HeroId": h["Id"]}, "children": [
                         viewport("Portrait", 32, 32, c),
                         T("HeroName", h["Name"], 230, 16, font="display", align="left"),
                         T("OddsEarn", f"{h['BestIncomeMult']:g}x your best", 180, 12, colour="soft", align="left"),
                         chip("OddsChip", "OddsPercent", None, 70, 26, c, px=14, static=f"{h['OddsPercent']:g}%")]})
    summon = {p["Key"]: p for p in CFG["Monetization"]["Products"] if p["Kind"] == "summon"}
    buys = [vbtn(f"OddsBuy{n}", "premium" if n < 10 else "confirm", "M" if n < 10 else "L", icon="IconRobux",
                 text=f"x{n}  {summon[f'SummonScroll{n}']['Robux']}", self_face=False) for n in (1, 3, 10)]
    body = [T("OddsNote", "Every Summon Scroll gives ONE of these heroes:", 600, 14, colour="soft",
              pos=[0.5, 0, 0, 0], anchor=[0.5, 0]),
            frame("OddsList", 600, 280, rows, layout=col(8, "start"), pos=[0.5, 0, 0, 26], anchor=[0.5, 0]),
            T("Total", "TOTAL: 100%", 300, 16, colour="buy", font="display", pos=[0.5, 0, 0, 314], anchor=[0.5, 0]),
            frame("BuyButtons", 600, 56, buys, layout=row(12, "center"), pos=[0.5, 0, 0, 344], anchor=[0.5, 0])]
    return page("SummonOdds", win("SUMMON ODDS", 600, 400, body, ribbon_w=320), displayOrder=12)


def rebirth():
    def keep_list(name, title, colour, icon_key, items, x):
        return panel(name, 354, 128, "panelHi", [
            T("Title", title, 300, 16, font="display", colour=colour, align="left", pos=[0, 12, 0, 8]),
            frame("List", 330, 88, [frame(f"Item{i}", 330, 16, [ico(icon_key, 16), T("Text", t, 300, 14, align="left")],
                                          layout=row(8, "start")) for i, t in enumerate(items, 1)],
                  layout=col(6, "start"), pos=[0, 12, 0, 34]),
        ], depth=3, corner=14, pos=[x, 0, 0, 164], anchor=[x, 0])
    req = panel("Requirements", 440, 150, "panelHi", [
        T("ReqTitle", "NEXT REBIRTH", 220, 16, font="display", align="left", pos=[0, 14, 0, 10]),
        T("NextTier", None, 180, 16, colour="buy", font="display", align="right", samples=["REBIRTH 999", "REBIRTH 1"],
          pos=[1, -14, 0, 10], anchor=[1, 0]),
        ico("IconPower", 26, name="PowerIcon", pos=[0, 14, 0, 50]),
        v1.track("PowerBar", 370, 28, 0.82, "#38BDF8", text_name="PowerReqText",
                 samples=["999.99Qi / 999.99Qi", "98.4M / 120M"], px=16, pos=[0, 52, 0, 49]),
        ico("IconYen", 26, name="YenIcon", pos=[0, 14, 0, 98]),
        v1.track("YenBar", 370, 28, 0.44, "#34D17A", text_name="YenReqText",
                 samples=["999.99Qi / 999.99Qi", "220B / 500B"], px=16, pos=[0, 52, 0, 97]),
    ], depth=3, corner=14)
    reward = card("Rewards", 268, 150, ["#FFE27A", "#FFB020"], [
        T("RewardTitle", "REWARD", 240, 20, font="display", pos=[0.5, 0, 0, 10], anchor=[0.5, 0]),
        T("RewardIncome", None, 240, 20, font="display", colour="confirm", samples=["+50% INCOME", "+150% INCOME"],
          pos=[0.5, 0, 0, 46], anchor=[0.5, 0]),
        T("RewardLuck", None, 240, 20, font="display", colour="info", samples=["+10% LUCK", "+30% LUCK"],
          pos=[0.5, 0, 0, 80], anchor=[0.5, 0]),
        T("RewardForever", "FOREVER!", 240, 14, font="display", pos=[0.5, 0, 0, 116], anchor=[0.5, 0]),
    ], comic=4, pos=[1, 0, 0, 0], anchor=[1, 0])
    body = [req, reward,
            keep_list("Keeps", "YOU KEEP", "confirm", "IconTick", ["Hero Index", "Game passes", "Premium heroes",
                                                                   "Lucky Throws"], 0),
            keep_list("Resets", "YOU LOSE", "danger", "IconClose", ["Yen and power", "Foods and gear", "Plot slots",
                                                                     "Caught heroes"], 1),
            T("CurrentRebirth", None, 340, 16, colour="soft", align="left",
              samples=["You are at Rebirth 999", "You are at Rebirth 0"], pos=[0, 0, 0, 326]),
            vbtn("ConfirmButton", "buy", "L", icon="IconRebirth", text="REBIRTH!", pos=[1, 0, 0, 306], anchor=[1, 0])]
    return page("Rebirth", win("REBIRTH", 722, 362, body))


SCREENS = [hud, throw_meter, v2.reveal, food_shop, squad, hero_index, store, summon_odds, offline, rebirth,
           daily, playtime, codes, settings, training, v1.nameplate, v1.leaderboard, v1.slot_sign]

TEMPLATES = [
    (food_card_template, "FoodShop"), (hero_row_template, "Squad"), (hero_tile_template, "HeroIndex"),
    (pass_card_template, "Store"), (product_card_template, "Store"), (v2.toast_template, "HUD"),
    (v2.zone_mark_template, "ThrowMeter"), (v1.leaderboard_row_template, "Leaderboard"),
    (lambda name="DailyCellTemplate": daily_cell(name), "DailyRewards"),
    (lambda name="GiftCellTemplate": gift_cell(name), "PlaytimeGifts"),
    (lambda name="OddsRowTemplate": odds_row(name), "SummonOdds"),
]


def daily_cell(name):
    d = copy.deepcopy(find({"children": daily()["children"]}, "DayCell7"))
    d["name"] = name
    return d


def gift_cell(name):
    d = copy.deepcopy(find({"children": playtime()["children"]}, "GiftCell6"))
    d["name"] = name
    return d


def odds_row(name):
    d = copy.deepcopy(find({"children": summon_odds()["children"]}, "OddsRow6"))
    d["name"] = name
    return d



# =================================================================== v3.1 fix round (play test s3-v3-01)
# Wrappers rebind the builder names, so food_shop() / store() / squad() pick them up at call time.

def _cell(b, caption=None, extra=()):
    """Button + caption row inside one column pitch: button 0..64, caption 66..84."""
    cap = find(b, "Caption")
    if cap is not None:
        b["children"].remove(cap)
        cap.update({"size": [0, 76, 0, 18], "textScale": round(12 / 18, 4), "maxText": 12, "textStroke": 1,
                    "pos": [0.5, 0, 0, 66], "anchor": [0.5, 0]})
        cap.pop("overhang", None)
    b.update({"pos": [0.5, 0, 0, 0], "anchor": [0.5, 0]})
    return frame(b["name"] + "Cell", 76, 84, [b] + ([cap] if cap is not None else []) + list(extra))


_hud30 = hud


def hud():
    spec = _hud30()
    root = {"children": spec["children"]}
    # 1. hint pill hugs its text: a plain frame (no depth-stack cell) with AutomaticSize X
    old = find(root, "TutorialHintCell") or find(root, "TutorialHint")
    ol = find(old, "ObjectiveLine")
    arrow = find(old, "Arrow")
    w = ol["size"][1] + 40 + 16
    hint = {"type": "frame", "name": "TutorialHint", "colour": ["#262B66", "#1B1F4B"], "keyline": WHITE,
            "alpha": 0.2, "corner": 18, "size": [0, w, 0, 36], "pos": [0.5, 0, 0, 14], "anchor": [0.5, 0],
            "autoX": 768, "children": [arrow, ol]}
    spec["children"] = [hint if k is old else k for k in spec["children"]]
    # 2. settings pinned to the true top-right corner by the column's edge rule (x = right - 20)
    st = find(root, "BtnSettings")
    st.update({"pos": [1, -20, 0, 12], "anchor": [1, 0]})
    # 3. columns: button + caption row in one pitch (84 + 7); the gift timer REPLACES the caption row
    for colname, names in (("LeftColumn", ("BtnShop", "BtnSquad", "BtnIndex")),
                           ("RightColumn", ("BtnStore", "BtnGift", "BtnRebirth"))):
        c = find(root, colname)
        cells = []
        for n in names:
            b = find(c, n)
            extra = []
            if n == "BtnGift":
                chipn = find(b, "GiftTimerBadgeCell") or find(b, "GiftTimerBadge")
                b["children"].remove(chipn)
                chipn.update({"size": [0, 66, 0, 18], "pos": [0.5, 0, 0, 66], "anchor": [0.5, 0], "z": 5,
                              "overhang": True, "visible": False})
                chipn["children"][0].update({"size": [0, 58, 0, 16], "textScale": 0.75, "maxText": 12,
                                             "textStroke": 1})
                chipn["depth"] = 0
                extra = [chipn]
            cells.append(_cell(b, extra=extra))
        c["children"] = cells
        c["size"] = [0, 76, 0, 3 * 84 + 2 * 7]
        c["layout"] = col(7, "start")
    find(root, "LeftColumn")["pos"] = [0, 20, 0, 104]
    find(root, "RightColumn").update({"pos": [1, -20, 0, 224], "anchor": [1, 0]})
    # the server-luck pill sat on five windows' close buttons (fit_gate hud_close): top centre under the hint
    find(root, "ServerLuckBar").update({"pos": [0.5, 0, 0, 58], "anchor": [0.5, 0]})
    find(root, "NoticeCard").update({"pos": [0.5, 0, 0, 106]})
    return spec


_food30 = food_card_template


def food_card_template(name="FoodCardTemplate", food=FOODS[2], state="afford", nxt=False, dim=False):
    """5. every element on its own row, 6 px apart, top-down (the button no longer rides up from the
    bottom edge when the cell renders shorter); NEXT tag on the top border's centre."""
    c = _food30(name=name, food=food, state=state, nxt=nxt, dim=dim)
    rows = {"ArtTile": (38, 92), "FoodName": (136, None), "StatRow": (163, None), "CravePill": (189, None)}
    for k in c["children"]:
        n = k.get("name")
        if n in rows:
            y, h = rows[n]
            k["pos"] = [0.5, 0, 0, y]
            if h:
                k["size"][3] = h
        if n in ("BuyButton", "BuyButtonCell"):
            k.update({"pos": [0.5, 0, 0, 213], "anchor": [0.5, 0]})
        if n in ("NextTag", "NextTagCell"):
            k.update({"pos": [0.5, 0, 0, -7], "anchor": [0.5, 0]})
    c["size"] = [0, 168, 0, 266]
    c["aspect"] = round(168 / 266, 4)
    return c


_foodshop30 = food_shop


def food_shop():
    spec = _foodshop30()
    g = find({"children": spec["children"]}, "FoodScroller")
    g["layout"]["cell"] = [168, 266]
    g["padding"] = 9
    return spec


_row30 = hero_row_template


def hero_row_template(**kw):
    """7. actions right-aligned to the row's inner edge: income, PLACE/BENCH, FUSE, SELL (SELL last)."""
    r = _row30(**kw)
    keep, acts = [], []
    for k in r["children"]:
        (acts if k.get("name") in ("IncomeBlock", "PlaceButton", "PlaceButtonCell", "FuseButton", "SellButton")
         else keep).append(k)
    inc = next(a for a in acts if a.get("name") == "IncomeBlock")
    for lab in inc["children"]:
        lab["align"] = "right"
    order = {"IncomeBlock": 0, "PlaceButton": 1, "PlaceButtonCell": 1, "FuseButton": 2, "SellButton": 3}
    acts.sort(key=lambda a: order[a["name"]])
    x = 6
    for k in keep:
        k["pos"] = [0, x, 0.5, 0]
        k["anchor"] = [0, 0.5]
        x += k["size"][1] + 10
    actions = frame("Actions", 858 - x, 52, acts, layout=row(10, "end"), pos=[1, -6, 0.5, 0], anchor=[1, 0.5])
    r["children"] = keep + [actions]
    r.pop("layout", None)
    r.pop("padding", None)
    return r


_prod30 = product_card_template


def product_card_template(name="ProductCardTemplate", key="LuckyThrow25", robux=149, stick=None):
    """6. a card sticker sits entirely above the card face: bottom edge on the top border."""
    c = _prod30(name=name, key=key, robux=robux, stick=stick)
    for k in c["children"]:
        if k.get("name") in ("Sticker", "StickerCell"):
            k.update({"pos": [1, 4, 0, -18], "anchor": [1, 0]})
    return c


_store30 = store


def store():
    spec = _store30()
    root = {"children": spec["children"]}
    bv = find(root, "BestValueStickerCell") or find(root, "BestValueSticker")
    bv["pos"] = [1, -6, 0, 334]   # bottom edge (334 + 22) on the x10 button's top border (356)
    return spec


_offline30 = offline


def offline():
    """4. "2X" + robux + price as ONE centred row in one text size; coin + amount as one centred group."""
    spec = _offline30()
    root = {"children": spec["children"]}
    btns = find(root, "Buttons")
    db = find(btns, "DoubleButton")
    i = db["children"].index(next(k for k in db["children"] if k.get("type") == "icon"))
    two = lbl("Label", "2X", 30, db["children"][-1]["size"][3], px=19, font="display", stroke=2)
    two["maxText"] = 19
    db["children"].insert(i, two)
    price = find(db, "DoublePrice")
    price["samples"] = ["39", "999"]
    price["size"][1] = 44
    db["size"][1] = 2 * 16 + 30 + 8 + 26 + 8 + 44
    amt = find(root, "EarnedAmount")
    amt.update({"autoX": True, "align": "center"})
    amt["size"][1] = int(est_w("+999.99Qi", 34)) + 4
    return spec


_playtime30 = playtime


def playtime():
    """9. same top padding as the other windows (the body started 84 px under the window top)."""
    spec = _playtime30()
    root = {"children": spec["children"]}
    find(root, "Body")["pos"] = [0.5, 0, 0, 70]
    find(root, "Window")["size"][3] -= 14
    return spec


def reveal():
    """8. the odds block fully below the 11% letterbox bar (79 px at 720) with a margin, still above
    the 24% line; the flight beat (LUCK, zone ribbon) shares that band and is marked as overhang."""
    spec = v2.reveal()
    root = {"children": spec["children"]}
    find(root, "LuckLabel").update({"pos": [0.5, 0, 0, 86], "overhang": True})
    find(root, "ZoneBanner").update({"pos": [0.5, 0, 0, 118], "overhang": True})
    find(root, "OddsBurst").update({"size": [0, 116, 0, 116], "pos": [0.5, 0, 0, 114]})
    find(root, "OddsLabel").update({"pos": [0.5, 0, 0, 86]})
    find(root, "StampLabel").update({"pos": [0.5, 0, 0, 144]})
    return spec


SCREENS = [hud, throw_meter, reveal, food_shop, squad, hero_index, store, summon_odds, offline, rebirth,
           daily, playtime, codes, settings, training, v1.nameplate, v1.leaderboard, v1.slot_sign]
TEMPLATES = [(food_card_template if t[0] is _food30 else hero_row_template if t[0] is _row30
              else product_card_template if t[0] is _prod30 else t[0], t[1]) for t in TEMPLATES]



# =================================================================== v3.2 (owner: spacing, horizontal food row, legible HUD)
from mp3 import CARD_GAP, GAP, PAD, ROW_GAP  # noqa: E402


def food_card_template(name="FoodCardTemplate", food=FOODS[2], state="afford", nxt=False, dim=False):
    """208 x 368: every element on its own row, 10 px between rows, 12 px card padding."""
    flav = food["Flavor"]
    cost = v1.short(food["Cost"])
    if state == "equipped":
        buy = state_pill("BuyButton", "PriceText", ["EQUIPPED"], "M", w=184)
    elif state == "equip":
        buy = vbtn("BuyButton", "info", "M", icon="IconTick", samples=["EQUIP", LONG_NUM], text_name="PriceText",
                   maxw=184)
    elif state == "afford":
        buy = vbtn("BuyButton", "confirm", "M", icon="IconYen", samples=[cost, LONG_NUM], text_name="PriceText",
                   maxw=184)
    else:
        buy = vbtn("BuyButton", "slate", "M", icon="IconYen", samples=[cost, LONG_NUM], text_name="PriceText",
                   text_colour="softRed", maxw=184)
    buy.update({"pos": [0.5, 0, 0, 312], "anchor": [0.5, 0]})

    def stat(n, icon, tname, samples, colour):
        return panel(n, 184, 22, CREAM_CHIP, [ico(icon, 14, name=icon.replace("Icon", "") + "Icon"),
                                             T(tname, None, 150, 13, colour=colour, font="display", samples=samples)],
                     layout=row(6, "center"), depth=0, corner=11)
    kids = [
        chip("TierTag", "TierText", [f"T{food['Tier']}", "T12"], 46, 22, "panel", px=13, pos=[0, PAD, 0, PAD]),
        ico(f"IconFlavor{flav}", 22, name="FlavorIcon", pos=[1, -PAD, 0, PAD], anchor=[1, 0]),
        {"type": "frame", "name": "ArtTile", "colour": [FLAVOR_TILE[flav], FLAVOR_TILE[flav]],
         "paint": FLAVOR_TILE[flav], "size": [0, 184, 0, 130], "pos": [0.5, 0, 0, 44], "anchor": [0.5, 0],
         "corner": 12, "children": [
             {**ico("FxSunburst", 150, name="Sunburst", pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5]), "z": 1,
              "overhang": True},
             {"type": "frame", "name": "Viewport", "transparent": True, "cls": "ViewportFrame",
              "size": [0, 170, 0, 116], "pos": [0.5, 0, 0.5, 0], "anchor": [0.5, 0.5], "children": [],
              "attrs": {"FoodId": food["Id"]}, "z": 2}]},
        T("FoodName", None, 184, 18, colour="ink", font="display", samples=[food["Name"], "Festival Cake"],
          pos=[0.5, 0, 0, 184], anchor=[0.5, 0]),
        frame("StatRow", 184, 54, [
            stat("PowerStat", "IconPower", "PowerText", [f"POWER x{food['PowerMult']:g}", "POWER x5.00"], "powerInk"),
            stat("LuckStat", "IconLuck", "LuckText", [f"LUCK x{food['Luck']:g}", "LUCK x5.50"], "luckInk"),
        ], layout=col(ROW_GAP, "start"), pos=[0.5, 0, 0, 218], anchor=[0.5, 0]),
        panel("CravePill", 132, 20, "premium", [T("CraveHint", None, 120, 13, samples=["+11 heroes", "+3 heroes"],
                                                    font="display")],
              depth=0, corner=10, pos=[0.5, 0, 0, 282], anchor=[0.5, 0]),
        buy,
        {**tag("NextTag", "NEXT", colour="buy"), "pos": [0.5, 0, 0, -7], "anchor": [0.5, 0],
         **({} if nxt else {"visible": False, "mockHide": True})},
    ]
    c = {"type": "panel", "name": name, "colour": "#D9CFBA" if dim else "cream", "size": [0, 208, 0, 368],
         "depth": 5, "corner": 16, "children": kids}
    if nxt:
        c["keyline"] = "#FFC93C"
    return c


def food_shop():
    def tab(n, icon, text, on):
        return vbtn(n, "info" if on else "panelHi", "S", icon=icon, text=text)
    filt = frame("FlavourFilter", 960, 34, [
        tab("FilterAll", "IconShop", "ALL", True), tab("FilterSavory", "IconFlavorSavory", "SAVORY", False),
        tab("FilterSweet", "IconFlavorSweet", "SWEET", False), tab("FilterSpicy", "IconFlavorSpicy", "SPICY", False),
        tab("FilterSeafood", "IconFlavorSeafood", "SEAFOOD", False)], layout=row(GAP, "start"), pos=[0, 0, 0, 0])
    cards = [sample(food_card_template(food=FOODS[0], state="equipped"), 1),
             sample(food_card_template(food=FOODS[1], state="equip"), 2),
             sample(food_card_template(food=FOODS[2], state="afford", nxt=True), 3),
             sample(food_card_template(food=FOODS[3], state="locked", dim=True), 4)]
    # 4 samples: the mockup renderer cannot clip a scroller, a 5th would be drawn outside the window
    # ONE row, scrolled sideways (owner's call); bar 8 px in its own gutter under the row,
    # 12 px canvas padding so the first and last card are never cut
    scroller = {"type": "frame", "name": "FoodScroller", "transparent": True, "cls": "ScrollingFrame", "scroll": "X",
                "scrollXok": True, "size": [0, 960, 0, 400], "padding": PAD, "layout": row(CARD_GAP, "start"),
                "props": {"ScrollBarThickness": 8, "HorizontalScrollBarInset": "ScrollBar"},
                "attrs": {"WheelScrollsX": True}, "pos": [0, 0, 0, 34 + CARD_GAP], "children": cards}
    return page("FoodShop", win("FOOD SHOP", 960, 34 + CARD_GAP + 400, [filt, scroller]))


def _stat_pill(name, icon, value_name, samples, colour, sub=None, y=0):
    kids = [{**ico(icon, 40, pos=[0, -8, 0.5, 0], anchor=[0, 0.5]), "overhang": True, "z": 3},
            dyn(value_name, samples, 128, 26, px=20, font="display", colour=colour, align="left", stroke=3,
                pos=[0, 40, 0.5, 0], anchor=[0, 0.5])]
    kids[1]["maxText"] = 20
    if sub:
        kids.append(sub)
    return panel(name, 280, 36, "panel", kids, corner=18, depth=3, pos=[0, 28, 0, y])


_hud31 = hud


def hud():
    spec = _hud31()
    root = {"children": spec["children"]}
    # side buttons: 72 px, caption INSIDE on a band at the lower edge (15 px max), pitch 84
    for colname in ("LeftColumn", "RightColumn"):
        c = find(root, colname)
        for cell in c["children"]:
            b = cell["children"][0]
            capn = next((k for k in cell["children"] if k.get("name") == "Caption"), None)
            chipn = next((k for k in cell["children"] if k.get("name") in ("GiftTimerBadgeCell", "GiftTimerBadge")),
                         None)
            b["size"] = [0, 72, 0, 72]
            icon = next(k for k in b["children"] if k.get("type") == "icon")
            icon.update({"size": [0, 44, 0, 44], "pos": [0.5, 0, 0, 5], "anchor": [0.5, 0]})
            band = lbl("Caption", capn["text"], 68, 20, px=15, font="display", stroke=3, pos=[0.5, 0, 1, -3],
                       anchor=[0.5, 1], z=4)
            band["maxText"] = 15
            b["children"].append(band)
            if chipn is not None:
                chipn.update({"size": [0, 66, 0, 20], "pos": [0.5, 0, 1, -3], "anchor": [0.5, 1], "z": 6})
                chipn["children"][0].update({"size": [0, 60, 0, 18], "textScale": round(15 / 18, 4), "maxText": 15,
                                             "textStroke": 2})
                b["children"].append(chipn)
            badge = find(b, "Badge")
            badge.update({"size": [0, 22, 0, 22], "pos": [1, 6, 0, -6], "anchor": [1, 0], "corner": 11})
            badge["children"][0].update({"size": [0, 16, 0, 18], "textScale": round(13 / 18, 4), "maxText": 13})
            cell["children"] = [b]
            cell["size"] = [0, 72, 0, 72]
        c["size"] = [0, 76, 0, 3 * 72 + 2 * 12]
        c["layout"] = col(12, "start")
    find(root, "LeftColumn")["pos"] = [0, 20, 0, 104]
    find(root, "RightColumn").update({"pos": [1, -20, 0, 224], "anchor": [1, 0]})
    sb = find(find(root, "BtnSettings"), "Badge")
    sb.update({"size": [0, 22, 0, 22], "pos": [1, 6, 0, -6], "anchor": [1, 0], "corner": 11})
    sb["children"][0].update({"size": [0, 16, 0, 18], "textScale": round(13 / 18, 4), "maxText": 13})
    # food chip: ONE pill, picture 44, name 15 px, flavour glyph + name 13 px
    fc = find(root, "FoodChip")
    pic = next(k for k in fc["children"] if k.get("type") == "icon")
    pic.update({"size": [0, 44, 0, 44], "pos": [0, -4, 0.5, 0], "anchor": [0, 0.5]})
    fname = find(fc, "FoodName")
    fname.update({"size": [0, 140, 0, 20], "textScale": 0.75, "maxText": 15, "pos": [0, 48, 0, 3], "textStroke": 2})
    fname.pop("overhang", None)
    frow = find(fc, "FlavorRow")
    frow.update({"size": [0, 140, 0, 18], "pos": [0, 48, 0, 23]})
    frow.pop("overhang", None)
    find(frow, "FlavorIcon")["size"] = [0, 14, 0, 14]
    find(frow, "FoodFlavor").update({"size": [0, 118, 0, 18], "textScale": round(13 / 18, 4), "maxText": 13})
    fc["children"] = [pic, fname, frow]
    fc.update({"size": [0, 200, 0, 44], "corner": 22, "pos": [0, 24, 0, 400]})
    # stats: three equal pills stacked 8 px apart, icons in one column, values at one x
    rank = chip("RankChip", "RankName", ["CHAMPION", "FIGHTER"], 92, 22, "panelHi", px=13,
                pos=[1, -8, 0.5, 0], anchor=[1, 0.5])
    inc = T("IncomePerSecond", None, 88, 13, colour="soft", align="right", samples=["+999.99Qi/s", "+4.55M/s"],
            pos=[1, -12, 0.5, 0], anchor=[1, 0.5])
    new = {"PowerCounter": _stat_pill("PowerCounter", "IconPower", "PowerAmount", [LONG_NUM, "3.97K"], "power",
                                      rank, 452),
           "YenCounter": _stat_pill("YenCounter", "IconYen", "YenAmount", [LONG_NUM, "26.1B"], "yen", inc, 496),
           "LuckChip": _stat_pill("LuckChip", "IconLuck", "LuckAmount", ["x999.9", "x1.01"], "luck", None, 540)}
    spec["children"] = [new.get(k.get("name"), k) for k in spec["children"]]
    return spec


SCREENS = [hud, throw_meter, reveal, food_shop, squad, hero_index, store, summon_odds, offline, rebirth,
           daily, playtime, codes, settings, training, v1.nameplate, v1.leaderboard, v1.slot_sign]
TEMPLATES = [(food_card_template, "FoodShop") if t[1] == "FoodShop" else t for t in TEMPLATES]


# =================================================================== v3.3 (owner: buttons apart, simple stats, compact training)
_hud32 = hud


def _stat_row(name, icon, value_name, samples, colour, sub=None, y=0):
    """One stat: a 44 px icon box, the value at box + 10 in the display face 28 px, an optional
    14 px line directly under it. No panel: legibility comes from the ink stroke alone."""
    kids = [ico(icon, 44, pos=[0, 0, 0.5, 0], anchor=[0, 0.5]),
            dyn(value_name, samples, 230, 32, px=28, font="display", colour=colour, align="left", stroke=3,
                pos=[0, 54, 0, 0 if sub else 10])]
    kids[1]["maxText"] = 28
    if sub:
        sub.update({"pos": [0, 54, 0, 33]})
        kids.append(sub)
    return frame(name, 290, 52, kids, pos=[0, 20, 0, y])


def hud():
    spec = _hud32()
    root = {"children": spec["children"]}
    # side buttons: 72 px painted box (stroke + lip inside it), 14 px clear between neighbours
    for colname in ("LeftColumn", "RightColumn"):
        c = find(root, colname)
        for cell in c["children"]:
            b = cell["children"][0]
            b["depth"] = 3
            find(b, "Caption")["overhang"] = True     # the band overlaps the icon's foot by design
            icon = next(k for k in b["children"] if k.get("type") == "icon")
            icon.update({"size": [0, 40, 0, 40], "pos": [0.5, 0, 0, 1]})
        c["size"] = [0, 76, 0, 3 * 72 + 2 * 14]
        c["layout"] = col(14, "start")
    find(root, "LeftColumn")["pos"] = [0, 20, 0, 96]
    # equipped food: round 48 px picture with the ink ring, name and flavour to its right, no pill
    old = find(root, "FoodChip")
    pic = next(k for k in old["children"] if k.get("type") == "icon")
    fname = find(old, "FoodName")
    frow = find(old, "FlavorRow")
    ring = {"type": "frame", "name": "FoodRing", "colour": ["#2B3175", "#1B1F4B"], "corner": 24,
            "size": [0, 48, 0, 48], "pos": [0, 0, 0.5, 0], "anchor": [0, 0.5],
            "children": [{**pic, "size": [0, 34, 0, 34], "pos": [0.5, 0, 0.5, 0], "anchor": [0.5, 0.5]}]}
    fname.update({"size": [0, 170, 0, 22], "textScale": round(16 / 22, 4), "maxText": 16, "pos": [0, 58, 0, 2],
                  "textStroke": 3})
    frow.update({"pos": [0, 58, 0, 27], "size": [0, 170, 0, 18]})
    food = {"type": "frame", "name": "FoodChip", "transparent": True, "cls": "TextButton", "size": [0, 230, 0, 48],
            "pos": [0, 20, 0, 390], "attrs": {"OpensPage": "FoodShop"}, "children": [ring, fname, frow]}
    # stats: three rows of 52, 10 apart, under the food with a 14 px gap
    rank = dyn("RankName", ["CHAMPION", "FIGHTER"], 200, 18, px=14, colour="soft", align="left", font="display",
               stroke=2)
    rank["maxText"] = 14
    inc = dyn("IncomePerSecond", ["+999.99Qi/s", "+4.55M/s"], 200, 18, px=14, colour="soft", align="left", stroke=2)
    inc["maxText"] = 14
    new = {"FoodChip": food,
           "PowerCounter": _stat_row("PowerCounter", "IconPower", "PowerAmount", [LONG_NUM, "3.97K"], "power", rank,
                                     452),
           "YenCounter": _stat_row("YenCounter", "IconYen", "YenAmount", [LONG_NUM, "26.1B"], "yen", inc, 514),
           "LuckChip": _stat_row("LuckChip", "IconLuck", "LuckAmount", ["x999.9", "x1.01"], "luck", None, 576)}
    spec["children"] = [new.get(k.get("name"), k) for k in spec["children"]]
    return spec


def training():
    """Compact and low: one panel 440 x 86, bottom centre 16 px up; NEW GEAR is a small chip on its top edge."""
    p = card("TrainingPanel", 440, 86, "panel", [
        T("RankName", None, 200, 16, colour="power", font="display", align="left", samples=["CHAMPION", "ROOKIE"],
          pos=[0, 8, 0, 0]),
        T("GearName", None, 200, 13, colour="soft", align="right", samples=["on Gravity Dojo", "on Wooden Dummy"],
          pos=[1, -8, 0, 2], anchor=[1, 0]),
        v1.track("ProgressBar", 404, 22, 0.58, "#38BDF8", text_name="ProgressText",
                 samples=["999.99Qi / 999.99Qi -> LEGEND", "9.01K / 70K -> ELITE"], px=13, pos=[0.5, 0, 0, 22],
                 anchor=[0.5, 0]),
        ico("IconPower", 16, name="PowerIcon", pos=[0, 8, 0, 51]),
        T("PowerPerRep", None, 220, 13, colour="power", align="left",
          samples=["+11.00K power per rep", "+560 power per rep"], pos=[0, 28, 0, 49]),
        vbtn("StopButton", "danger", "S", icon="IconClose", text="STOP", pos=[1, -8, 1, 0], anchor=[1, 1]),
    ], comic=3, pos=[0.5, 0, 1, -16], anchor=[0.5, 1])
    up = vbtn("UpgradePrompt", "confirm", "S", icon="IconTrain", px=13,
              samples=["NEW GEAR: Dragon Shrine 28B", "NEW GEAR: Sandbag 600"], text_name="UpgradeText", maxw=300,
              pos=[0.5, 0, 1, -102], anchor=[0.5, 1], visible=False, self_face=False, overhang=True)
    return page("TrainingBar", [up, p], kind="hud", enabled=False)


_index32 = hero_index


def hero_index():
    spec = _index32()
    for i in range(1, 7):
        t = find({"children": spec["children"]}, f"ZoneTab{i}")
        find(t, "ZoneName").update({"pos": [0, 16, 0, 4]})
        find(t, "ZoneBar").update({"pos": [0, 16, 0, 25], "size": [0, 150, 0, 17]})
    return spec


SCREENS = [hud, throw_meter, reveal, food_shop, squad, hero_index, store, summon_odds, offline, rebirth,
           daily, playtime, codes, settings, training, v1.nameplate, v1.leaderboard, v1.slot_sign]


# ---- v3.3: content re-fitted to the inset faces (stroke + lip now paint inside the box)
_pass32, _prod33, _tile32, _play33, _store33, _lb33 = (pass_card_template, product_card_template,
                                                       hero_tile_template, playtime, store, v1.leaderboard)


def _taller(c, h):
    c["size"][3] = h
    return c


def pass_card_template(**kw):
    return _taller(_pass32(**kw), 172)


def product_card_template(**kw):
    return _taller(_prod33(**kw), 172)


def hero_tile_template(**kw):
    t = _tile32(**kw)
    for k in t["children"]:
        y = {"Portrait": 2, "RarityStripe": 81, "HeroName": 88, "BottomRow": 126}.get(k.get("name"))
        if y is not None:
            k["pos"] = [k["pos"][0], k["pos"][1], 0, y]
        if k.get("name") == "Portrait":
            k["size"][3] = 78
        if k.get("name") == "HeroName":
            k["size"][3] = 36
    return t


def store():
    spec = _store33()
    root = {"children": spec["children"]}
    for n in ("PassScroller", "ProductScroller"):
        g = find(root, n)
        g["layout"]["cell"] = [136, 172]
        g["size"][3] = 172
        for c in g["children"]:
            c["size"][3] = 172
    return spec


def playtime():
    spec = _play33()
    root = {"children": spec["children"]}
    g = find(root, "GiftGrid")
    g["layout"]["cell"] = [220, 112]
    g["size"][3] = 2 * 112 + 14
    for c in g["children"]:
        c["size"][3] = 112
        c["aspect"] = round(220 / 112, 4)
    find(root, "Window")["size"][3] += 24
    return spec


def _leaderboard33():
    spec = _lb33()
    b = find({"children": spec["children"]}, "Board")
    b["comic"] = 6
    find(b, "Footer")["pos"] = [0.5, 0, 1, -4]
    return spec


_hud33 = hud


def hud():
    spec = _hud33()
    nc = find({"children": spec["children"]}, "NoticeCard")
    nc["size"][3] = 104
    for n in ("NoticeTitle", "NoticeBody"):
        find(nc, n)["size"][1] = 138
    return spec


_index33 = hero_index


def hero_index():
    spec = _index33()
    for i in range(1, 7):
        find(find({"children": spec["children"]}, f"ZoneTab{i}"), "ZoneName")["size"][1] = 150
    return spec


_training33 = training


def training():
    spec = _training33()
    p = find({"children": spec["children"]}, "TrainingPanel")
    p.update({"comic": 0, "depth": 0})
    find(p, "GearName")["size"][3] = 19
    return spec


SCREENS = [hud, throw_meter, reveal, food_shop, squad, hero_index, store, summon_odds, offline, rebirth,
           daily, playtime, codes, settings, training, v1.nameplate, _leaderboard33, v1.slot_sign]
TEMPLATES = [(pass_card_template, t[1]) if t[0].__name__ == "pass_card_template" else
             (product_card_template, t[1]) if t[0].__name__ == "product_card_template" else
             (hero_tile_template, t[1]) if t[0].__name__ == "hero_tile_template" else t for t in TEMPLATES]


# =================================================================== v3.4: stats one notch toward the reference
_hud34 = hud


def hud():
    spec = _hud34()
    root = {"children": spec["children"]}
    for name, y in (("PowerCounter", 456), ("YenCounter", 526), ("LuckChip", 596)):
        r = find(root, name)
        r.update({"size": [0, 320, 0, 60], "pos": [0, 20, 0, y]})
        for k in r["children"]:
            if k.get("type") == "icon":
                k["size"] = [0, 52, 0, 52]
            elif k.get("name") in ("PowerAmount", "YenAmount", "LuckAmount"):
                sub = len(r["children"]) > 2
                k.update({"size": [0, 250, 0, 38], "textScale": round(34 / 38, 4), "maxText": 34,
                          "pos": [0, 62, 0, 0 if sub else 11]})
            else:
                k.update({"size": [0, 220, 0, 20], "textScale": 0.75, "maxText": 15, "pos": [0, 62, 0, 39]})
    fc = find(root, "FoodChip")
    fc.update({"size": [0, 250, 0, 52], "pos": [0, 20, 0, 390]})
    ring = find(fc, "FoodRing")
    ring.update({"size": [0, 52, 0, 52], "corner": 26})
    ring["children"][0]["size"] = [0, 38, 0, 38]
    find(fc, "FoodName").update({"size": [0, 180, 0, 23], "textScale": round(17 / 23, 4), "maxText": 17,
                                 "pos": [0, 62, 0, 2]})
    find(fc, "FlavorRow").update({"pos": [0, 62, 0, 30]})
    return spec


SCREENS = [hud] + SCREENS[1:]
