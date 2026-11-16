"""UI v4.3 (owner's review 4): the screens that changed, on top of screens_v42.

  HudFx           the Reward popup is a CARD now: the model on a stage with rays behind it, a title ribbon on the card's
                  top edge, the item name large, up to three detail chips (icon + text), a "tap to continue" hint.
  Confirm         the purchase dialog, redesigned: title bar, item name + tier tag, a model panel with a proper
                  backdrop, stat rows as aligned cards (icon well / label / from -> to columns), a cost panel, two
                  buttons of the same size.
  Rebirth         smaller and premium: a requirements card (icon wells, captioned bars, ticks when met), a gold reward
                  panel on a ribbon, keep / lose cards with coloured header strips, the REBIRTH button big.
  Reveal          the final beat is ONE hero info card at the bottom centre (rarity ribbon on its top edge, the name
                  big, size / mutation / craving tags and stars, the income big with the yen icon, the odds, a NEW
                  stamp, the sold / bench line riding its bottom edge).
  OfflineEarnings the sunburst sits INSIDE the icon's holder, so it is centred on the yen coin whatever the amount.

The store is the STORE worker's (screens_store_v5.py when it exists); this module only passes it through.
"""

from __future__ import annotations

import mp4
import mangapop as mp
import screens_v4 as v4
import screens_v42 as v42
from mangapop import WHITE, frame, ico, row, col
from mp4 import T, _hex, auto_label, chip, ribbon_tag, round_x, sheen, track, vbtn, card
from screens import MUT_HEX, page
from screens_v42 import NAVY, fx, gloss_band, twinkle

try:  # the store worker's module, when it lands
    import screens_store_v5 as _store_v5  # type: ignore
except Exception:  # noqa: BLE001
    _store_v5 = None


def icon_chip(name, text_name, icon, samples, colour, px=18, h=34, keyline=None):
    """A pill that grows with its text in game: [icon][text] centred, in a transparent `<name>Cell`."""
    lab = auto_label(text_name, samples, px)
    isz = h - 12
    ic = ico(icon, isz, name=f"{name}Icon")
    w = isz + 8 + lab["size"][1] + 28
    pill = {"type": "frame", "name": name, "colour": [_hex(colour), _hex(colour)], "paint": _hex(colour),
            "corner": h // 2, "size": [0, w, 0, h], "autoW": 14, "layout": row(8, "center"),
            "children": [ic, lab]}
    if keyline:
        pill["keyline"] = keyline
    return {"type": "frame", "name": f"{name}Cell", "transparent": True, "size": [0, w, 0, h], "autoW": 0,
            "children": [pill]}


def icon_well(name, icon, side, icon_side, colour=("#3B4396", "#262C70"), keyline="#5A63C8", icon_name=None, **kw):
    """A round well behind a small icon (stat rows, list headers)."""
    return {"type": "frame", "name": name, "colour": list(colour), "corner": 1, "keyline": keyline,
            "size": [0, side, 0, side], "children": [
                ico(icon, icon_side, name=icon_name or f"{name}Icon", pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5])],
            **kw}


# =================================================================== HudFx: the reward card

RW_W, RW_H = 620, 452
RW_STAGE_Y = 128
RW_CARD_W, RW_CARD_H, RW_CARD_Y = 580, 196, 240


def reward_popup():
    """The unboxing reward: rays, glow and a halo in the item colour turning behind a 3D stage (RewardStage) or
    the icon (RewardIcon); under it ONE card: the title ribbon on its top edge (RewardTitlePlate.RewardTitle),
    the item name large (RewardName), up to three detail chips (RewardChips.RewardChip1..3, icon + text), or the
    plain RewardSub line when the caller sent no chips, and the hint. Fades in and out; tap or 4 s dismisses."""
    c = RW_STAGE_Y
    title = {"type": "panel", "name": "RewardTitlePlate", "colour": ["#5BE38A", "#1FA862"], "paintable": True,
             "keyline": WHITE, "depth": 0, "corner": 24, "size": [0, 300, 0, 52], "pos": [0.5, 0, 0, -26],
             "anchor": [0.5, 0], "z": 9, "overhang": True,
             "pattern": {"name": "stripes", "colour": "#FFFFFF", "opacity": 0.12, "tile": 64}, "children": [
                 gloss_band(24),
                 {**T("RewardTitle", None, 270, 30, font="display", samples=["NEW GEAR!", "NEW FOOD!", "NEW SLOT!"],
                      pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5]), "z": 10}]}
    chips = [icon_chip(f"RewardChip{i}", f"RewardChipText{i}", ico_key, samples, colour)
             for i, (ico_key, samples, colour) in enumerate([
                 ("IconPower", ["+2.4K Power per rep", "Luck x5.50"], "#2F6BFF"),
                 ("IconPlace", ["Slot 11 of 28", "Power x5.00"], "#1FA862"),
                 ("IconFlavorSweet", ["SWEET", "SEAFOOD"], "#E8358F")], 1)]
    chip_w = sum(ch["size"][1] for ch in chips) + 2 * 10
    body = {"type": "panel", "name": "RewardCard", "colour": NAVY, "keyline": WHITE, "depth": 0, "corner": 26,
            "size": [0, RW_CARD_W, 0, RW_CARD_H], "pos": [0.5, 0, 0, RW_CARD_Y], "anchor": [0.5, 0], "z": 7,
            "pattern": {"name": "dots", "colour": "#FFFFFF", "opacity": 0.06, "tile": 26}, "children": [
                gloss_band(26, 0.16),
                title,
                {**T("RewardName", None, RW_CARD_W - 40, 40, font="display",
                     samples=["Dragon Shrine", "Festival Cake", "Slot 11"], pos=[0.5, 0, 0, 38], anchor=[0.5, 0]),
                 "z": 8},
                {**frame("RewardChips", max(chip_w, RW_CARD_W - 40), 34, chips, layout=row(10, "center"),
                         pos=[0.5, 0, 0, 100], anchor=[0.5, 0]), "z": 8},
                {**T("RewardSub", None, RW_CARD_W - 40, 22, font="display", colour="yen",
                     samples=["One more hero on your plot", "+2.4K Power per rep"], pos=[0.5, 0, 0, 104],
                     anchor=[0.5, 0]), "z": 8, "overhang": True, "visible": False, "mockHide": True},
                {**T("RewardHint", "tap to continue", 260, 16, colour="soft", pos=[0.5, 0, 1, -14],
                     anchor=[0.5, 1]), "z": 8},
            ]}
    return frame("Reward", RW_W, RW_H, [
        fx("FxRays", 520, "Rays", tint="#7CF0A8", alpha=0.15, pos=[0.5, 0, 0, c], anchor=[0.5, 0.5], z=1, turn=14),
        fx("FxSunburst", 400, "Rays2", tint="#FFFFFF", alpha=0.55, pos=[0.5, 0, 0, c], anchor=[0.5, 0.5], z=2,
           turn=-9),
        fx("FxGlow", 380, "Glow", tint="#7CF0A8", alpha=0.1, pos=[0.5, 0, 0, c], anchor=[0.5, 0.5], z=3, turn=0),
        fx("FxRing", 270, "Halo", tint="#FFFFFF", alpha=0.45, pos=[0.5, 0, 0, c], anchor=[0.5, 0.5], z=4, turn=0),
        {**ico("IconStar", 170, name="RewardIcon", pos=[0.5, 0, 0, c], anchor=[0.5, 0.5]), "z": 5,
         "overhang": True},
        {"type": "frame", "name": "RewardStage", "transparent": True, "cls": "ViewportFrame",
         "size": [0, 240, 0, 240], "pos": [0.5, 0, 0, c], "anchor": [0.5, 0.5], "z": 6, "children": [],
         "overhang": True},
        body,
        twinkle("Twinkle1", 40, [0, 110, 0, 40], z=7), twinkle("Twinkle2", 28, [1, -100, 0, 60], z=7),
        twinkle("Twinkle3", 30, [1, -120, 0, 200], z=7), twinkle("Twinkle4", 24, [0, 130, 0, 210], z=7),
        twinkle("Twinkle5", 20, [0.5, 140, 0, 20], z=7), twinkle("Twinkle6", 22, [0.5, -150, 0, 230], z=7),
    ], pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5], visible=False, overhang=True)


def hud_fx():
    scrim = {"type": "frame", "name": "Scrim", "colour": [mp.INK, mp.INK], "alpha": 0.5, "outline": False,
             "z": -2, "size": [1, 0, 1, 0], "children": [], "visible": False, "overhang": True}
    return page("HudFx", [scrim, v42.level_banner(), v42.zone_banner(), reward_popup(), v42.stat_panel()],
                kind="hud", displayOrder=15)


# =================================================================== Confirm (purchase dialog)

CONF_W, CONF_H = 680, 506
STAGE_X, STAGE_Y, STAGE_W, STAGE_H = 24, 86, 224, 240
COL_X = STAGE_X + STAGE_W + 24
COL_W = CONF_W - COL_X - 24
ROW_W, ROW_H = COL_W, 46


def confirm_row(i):
    """One stat as an aligned card: icon well | label | from | arrow | to (the columns line up across rows)."""
    return {"type": "panel", "name": f"ConfirmRow{i}", "colour": ["#2F367F", "#1E2360"], "keyline": "#4C55B8",
            "depth": 0, "corner": 14, "size": [0, ROW_W, 0, ROW_H], "children": [
                icon_well("RowIconWell", "IconPower", 34, 24, icon_name="RowIcon", pos=[0, 8, 0.5, 0],
                          anchor=[0, 0.5]),
                T("RowLabel", None, 134, 17, colour="soft", font="display", align="left",
                  samples=["Power per rep", "Hero slots", "Unlocks"], pos=[0, 52, 0.5, 0], anchor=[0, 0.5]),
                T("RowFrom", None, 64, 19, colour="soft", font="display", align="right", samples=["+560", "999.9K"],
                  pos=[1, -128, 0.5, 0], anchor=[1, 0.5]),
                {**ico("IconArrow", 18, name="RowArrow", pos=[1, -112, 0.5, 0], anchor=[0.5, 0.5]),
                 "tint": "#5BE37D", "rotation": 90},
                T("RowTo", None, 88, 22, colour="luck", font="display", align="right",
                  samples=["+2.4K", "Meditate"], pos=[1, -12, 0.5, 0], anchor=[1, 0.5]),
            ]}


def confirm():
    bw = 296
    yes = vbtn("ConfirmYes", "confirm", "L", icon="IconTick", samples=["CONFIRM", "UPGRADE", "NEED MORE YEN"],
               text_name="YesText", w=bw)
    no = vbtn("ConfirmNo", "slate", "L", icon="IconClose", text="CANCEL", self_face=False, w=bw)
    header = {"type": "frame", "name": "ConfirmHeader", "colour": ["#FFE066", "#FFA41B"], "paint": "#FFC83D",
              "corner": 18, "outline": False, "size": [1, -12, 0, 64], "pos": [0.5, 0, 0, 6], "anchor": [0.5, 0],
              "z": 2, "pattern": {"name": "stripes", "colour": "#FFFFFF", "opacity": 0.12, "tile": 64},
              "children": [sheen(corner=18, opacity=0.26),
                           {**T("ConfirmTitle", None, 460, 32, font="display",
                                samples=["UPGRADE GEAR", "NEW HERO SLOT"], pos=[0.5, 0, 0.5, 0],
                                anchor=[0.5, 0.5]), "z": 3}]}
    well = {"type": "frame", "name": "StageWell", "colour": ["#2A3088", "#12153A"], "corner": 20,
            "keyline": "#6F79D8", "size": [0, STAGE_W, 0, STAGE_H], "pos": [0, STAGE_X, 0, STAGE_Y],
            "props": {"ClipsDescendants": True}, "children": [
                {**v42.card_bg("BgRays", 0.82, name="StageBg"), "z": 1},
                fx("FxGlow", 210, "Glow", tint="#FFC83D", alpha=0.3, pos=[0.5, 0, 0.5, -10], anchor=[0.5, 0.5],
                   z=2, turn=0),
                {"type": "frame", "name": "StageFloor", "colour": ["#0B0D29", "#0B0D29"], "alpha": 0.55,
                 "outline": False, "corner": 1, "size": [0, 170, 0, 34], "pos": [0.5, 0, 1, -30],
                 "anchor": [0.5, 0.5], "z": 2, "children": [], "overhang": True},
                {**ico("IconTrainBig", 130, name="ConfirmIcon", pos=[0.5, 0, 0.5, -8], anchor=[0.5, 0.5]), "z": 3,
                 "centre": False},
                {"type": "frame", "name": "ConfirmViewport", "transparent": True, "cls": "ViewportFrame",
                 "size": [1, -8, 1, -8], "pos": [0.5, 0, 0.5, 0], "anchor": [0.5, 0.5], "z": 4, "children": [],
                 "overhang": True},
            ]}
    tag = {**chip("ConfirmTag", "ConfirmTagText", ["TIER 12", "LEGENDARY", "SLOT 28"], "#7B3FF2", px=16, h=28),
           "pos": [0, 0, 0, 44]}
    details = frame("Details", COL_W, STAGE_H, [
        T("ConfirmName", None, COL_W, 30, font="display", align="left", samples=["Dragon Shrine", "Slot 24"],
          pos=[0, 0, 0, 0]),
        tag,
        frame("ConfirmRows", COL_W, 3 * ROW_H + 2 * 8, [confirm_row(i) for i in (1, 2, 3)],
              layout=col(8, "start"), pos=[0, 0, 1, 0], anchor=[0, 1]),
    ], pos=[0, COL_X, 0, STAGE_Y])
    cost_y = STAGE_Y + STAGE_H + 16
    cost = {"type": "frame", "name": "CostWell", "colour": ["#12153A", "#0B0D29"], "keyline": "#3A4196",
            "corner": 18, "size": [0, CONF_W - 48, 0, 58], "pos": [0.5, 0, 0, cost_y], "anchor": [0.5, 0],
            "children": [
                icon_well("CostBadge", "IconYen", 38, 26, colour=("#FFE066", "#FFA41B"), keyline="#FFF1B8",
                          icon_name="CostBadgeIcon", pos=[0, 12, 0.5, 0], anchor=[0, 0.5]),
                T("CostLabel", "PRICE", 120, 20, colour="soft", font="display", align="left", pos=[0, 62, 0.5, 0],
                  anchor=[0, 0.5]),
                frame("CostRow", 300, 46, [ico("IconYen", 34, name="CostIcon"),
                                           auto_label("CostText", ["999.99Qi", "28B"], 32, colour="yen")],
                      layout=row(8, "end"), pos=[1, -18, 0.5, 0], anchor=[1, 0.5])]}
    buttons = frame("ConfirmButtons", 2 * bw + 20, 68, [no, yes], layout=row(20, "center"),
                    pos=[0.5, 0, 1, -18], anchor=[0.5, 1])
    win = {"type": "panel", "name": "ConfirmWindow", "colour": NAVY, "keyline": "#8D96F0", "depth": 0,
           "stroke": mp4.WINDOW_STROKE, "corner": 24, "size": [0, CONF_W, 0, CONF_H], "pos": [0.5, 0, 0.5, 0],
           "anchor": [0.5, 0.5], "modal": True,
           "pattern": {"name": "dots", "colour": "#FFFFFF", "opacity": 0.05, "tile": 28},
           "children": [header,
                        round_x("ConfirmClose", pos=[1, -14, 0, 10], anchor=[1, 0], z=4, overhang=True),
                        well, details, cost, buttons]}
    scrim = {"type": "frame", "name": "Scrim", "colour": [mp.INK, mp.INK], "alpha": 0.5, "outline": False,
             "z": -2, "size": [1, 0, 1, 0], "children": []}
    return page("Confirm", [scrim, win], kind="hud", enabled=False, displayOrder=14)


# =================================================================== Rebirth

RB_W, RB_H = 760, 440


def rebirth():
    def prog(name, icon, caption, fill, samples, y):
        return frame(f"{name}Row", 408, 62, [
            icon_well(f"{name}Well", icon, 52, 38, icon_name=f"{name}Icon", pos=[0, 0, 0.5, 0], anchor=[0, 0.5]),
            T(f"{name}Caption", caption, 220, 15, colour="soft", font="display", align="left", pos=[0, 66, 0, 0]),
            {**ico("IconTick", 22, name=f"{name}Done", pos=[1, 0, 0, 0], anchor=[1, 0]), "visible": False,
             "mockHide": True},
            track(f"{name}Bar", 342, 34, 0.62, fill, text_name=f"{name}ReqText", samples=samples, px=19,
                  pos=[0, 66, 1, 0], anchor=[0, 1]),
        ], pos=[0, 16, 0, y])
    req = card("Requirements", 440, 204, "panelHi", [
        T("ReqTitle", "REQUIREMENTS", 220, 20, font="display", colour="soft", align="left", pos=[0, 18, 0, 16]),
        {**v4.rchip("NextTierChip", "NextTier", ["REBIRTH 999", "MAX REBIRTH"], "#7B3FF2", px=17, h=30),
         "pos": [1, -16, 0, 12], "anchor": [1, 0]},
        prog("Power", "IconPowerBig", "TOTAL POWER", "#38BDF8", ["999.99Qi / 999.99Qi", "6.8B / 600M"], 56),
        prog("Yen", "IconYenBig", "YEN (SPENT ON REBIRTH)", "#34D17A", ["999.99Qi / 999.99Qi", "220B / 500B"], 130),
    ])

    def reward_line(name, icon, text_name, samples, y):
        return frame(name, 268, 46, [ico(icon, 40, name=f"{name}Icon"),
                                     auto_label(text_name, samples, 26)],
                     layout=row(10, "center"), pos=[0.5, 0, 0, y], anchor=[0.5, 0])
    reward = {"type": "panel", "name": "Rewards", "colour": ["#FFD24A", "#FF8A1A"], "keyline": "#FFF1B8",
              "depth": 0, "corner": 20, "size": [0, 304, 0, 204], "pos": [1, 0, 0, 0], "anchor": [1, 0],
              "pattern": {"name": "stripes", "colour": "#FFFFFF", "opacity": 0.14, "tile": 96}, "children": [
                  gloss_band(20, 0.24),
                  fx("FxGlow", 190, "Glow", tint="#FFF6C8", alpha=0.35, w=290, pos=[0.5, 0, 0.5, 6],
                     anchor=[0.5, 0.5], z=1, turn=0),
                  {**ribbon_tag("RewardRibbon", "REWARD", colour="#B4235A", text_name="RewardTitle", px=20, h=34,
                                w=150), "pos": [0.5, 0, 0, -17]},
                  {**reward_line("IncomeLine", "IconYenBig", "RewardIncome",
                                 ["+150% INCOME", "MAX REBIRTH"], 34), "z": 3},
                  {**reward_line("LuckLine", "IconLuckBig", "RewardLuck", ["+30% LUCK", "+10% LUCK"], 90), "z": 3},
                  {**chip("ForeverChip", "ForeverText", None, "#B4235A", px=18, h=30, static="FOREVER!"),
                   "pos": [0.5, 0, 1, -16], "anchor": [0.5, 1], "z": 3},
                  twinkle("Twinkle1", 26, [0, 22, 0, 40], z=4), twinkle("Twinkle2", 20, [1, -24, 0, 120], z=4),
              ]}

    def keep_card(name, title, head, icon_key, items, x):
        cell = [frame(f"Item{i}", 172, 30, [ico(icon_key, 22, name="ItemIcon"),
                                            T("Text", t, 142, 17, align="left", font="display")],
                      layout=row(8, "start")) for i, t in enumerate(items, 1)]
        strip = {"type": "frame", "name": f"{name}Head", "colour": head, "corner": 12, "outline": False,
                 "size": [1, -16, 0, 36], "pos": [0.5, 0, 0, 8], "anchor": [0.5, 0], "children": [
                     sheen(corner=12, opacity=0.22),
                     frame(f"{name}TitleRow", 200, 30, [ico(icon_key, 24, name="HeadIcon"),
                                                        T("Title", title, 160, 20, font="display", align="left")],
                           layout=row(8, "center"), pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5], z=3)]}
        return card(name, 372, 136, "panelHi", [
            strip,
            frame("List", 352, 2 * 30 + 10, cell, layout={"type": "grid", "cell": [172, 30], "gap": 8, "cols": 2},
                  pos=[0.5, 0, 0, 56], anchor=[0.5, 0]),
        ], pos=[x, 0, 0, 220], anchor=[x, 0])
    body = [req, reward,
            keep_card("Keeps", "YOU KEEP", ["#4BE08A", "#14935A"], "IconTick",
                      ["Hero Index", "Game passes", "Premium heroes", "Lucky Throws"], 0),
            keep_card("Resets", "YOU LOSE", ["#FF6B6B", "#C42A3A"], "IconClose",
                      ["Yen and power", "Foods and gear", "Plot slots", "Caught heroes"], 1),
            {**v4.rchip("CurrentChip", "CurrentRebirth", ["You are at Rebirth 999", "You are at Rebirth 0"],
                        "#1B1F4B", px=18, h=34), "pos": [0, 0, 1, -17], "anchor": [0, 0.5]},
            fx("FxGlow", 90, "ButtonGlow", tint="#FFE38A", alpha=0.35, w=280, pos=[1, -150, 1, -34],
               anchor=[0.5, 0.5], z=0, turn=0),
            vbtn("ConfirmButton", "buy", "L", icon="IconRebirth", text="REBIRTH!", w=300, pos=[1, 0, 1, 0],
                 anchor=[1, 1])]
    return page("Rebirth", v4.window("REBIRTH", RB_W, RB_H, body, colour="gold", icon="IconRebirthBig"))


# =================================================================== Reveal: the hero info card

CARD_W, CARD_H = 640, 186
FINAL_NODES = {"StampLabel", "RarityRibbon", "RarityRibbonCell", "VariantLabel", "IncomeRow", "SoldLabel"}


def hero_card():
    ribbon = {**v4.rchip("RarityRibbon", "RarityText", ["LEGENDARY", "UNCOMMON", "SECRET"], "#A855F7", px=20,
                         h=36), "pos": [0.5, 0, 0, -18], "anchor": [0.5, 0], "z": 8, "overhang": True}
    stamp = {**ribbon_tag("Stamp", "NEW!", colour="danger", text_name="StampLabel",
                          samples=["NEW BEST!", "LUCKY!", "NEW!"], px=18, h=32, w=130),
             "pos": [1, -72, 0, -14], "anchor": [0.5, 0], "z": 9}
    stars = {**frame("Stars", 3 * 24 + 2 * 2, 26, [ico("IconStar", 24, name=f"Star{i}") for i in (1, 2, 3)],
                     layout=row(2, "center")), "autoW": 0}
    tags = frame("TagRow", CARD_W - 40, 32, [
        mp4.pill_auto("SizeTag", "SizeText", ["TITAN", "HUGE"], "info", px=18, h=30),
        mp4.pill_auto("MutationTag", "MutationText", ["LIGHTNING", "GALAXY"], MUT_HEX["Lightning"], px=18, h=30),
        icon_chip("CraveTag", "CraveText", "IconFlavorSavory", ["CRAVING!", "CRAVES SEAFOOD"], "#B4235A", px=17,
                  h=30),
        stars,
    ], layout=row(8, "center"), pos=[0.5, 0, 0, 84], anchor=[0.5, 0])
    income = frame("IncomeRow", 290, 48, [ico("IconYenBig", 42, name="YenIcon"),
                                          auto_label("IncomeLabel", ["+999.99Qi/s", "+1.2K/s"], 36, colour="luck")],
                   layout=row(8, "center"), pos=[0, 0, 0.5, 0], anchor=[0, 0.5])
    odds = frame("CardOddsRow", 290, 48, [ico("IconLuckBig", 34, name="OddsIcon"),
                                          auto_label("CardOdds", ["1 in 999.99Qi", "1 in 250"], 28, colour="yen")],
                 layout=row(8, "center"), pos=[1, 0, 0.5, 0], anchor=[1, 0.5])
    divider = {"type": "frame", "name": "Divider", "colour": ["#8D96F0", "#8D96F0"], "alpha": 0.4,
               "outline": False, "corner": 2, "size": [0, 3, 0, 36], "pos": [0.5, 0, 0.5, 0], "anchor": [0.5, 0.5],
               "children": []}
    stats = frame("StatsRow", CARD_W - 40, 48, [income, divider, odds], pos=[0.5, 0, 0, 126], anchor=[0.5, 0])
    sold = {**v4.rchip("SoldTag", "SoldLabel", ["sold for 999.99Qi yen", "sent to your bench"], "#1B1F4B", px=16,
                       h=28), "pos": [0.5, 0, 1, -14], "anchor": [0.5, 0], "z": 8, "overhang": True}
    panel = {"type": "panel", "name": "CardPanel", "colour": NAVY, "keyline": WHITE, "depth": 0, "corner": 26,
             "size": [0, CARD_W, 0, CARD_H], "pos": [0.5, 0, 1, 0], "anchor": [0.5, 1], "z": 3,
             "pattern": {"name": "dots", "colour": "#FFFFFF", "opacity": 0.06, "tile": 26}, "children": [
                 gloss_band(26, 0.14),
                 ribbon, stamp,
                 {**T("CardName", None, CARD_W - 60, 40, font="display",
                      samples=["Heavenly String King", "Copy Ninja"], pos=[0.5, 0, 0, 26], anchor=[0.5, 0]), "z": 4},
                 tags, stats, sold,
             ]}
    return frame("HeroCard", CARD_W + 80, CARD_H + 40, [
        fx("FxGlow", 160, "Glow", tint="#FFFFFF", alpha=0.45, w=CARD_W + 80, pos=[0.5, 0, 0, 44],
           anchor=[0.5, 0.5], z=1, turn=0),
        panel,
        twinkle("Twinkle1", 30, [0, 46, 0, 40], z=6), twinkle("Twinkle2", 22, [1, -40, 1, -40], z=6),
    ], pos=[0.5, 0, 1, -34], anchor=[0.5, 1], overhang=True)


def reveal():
    spec = v4.reveal()
    spec["children"] = [k for k in spec["children"] if k.get("name") not in FINAL_NODES]
    root = {"children": spec["children"]}
    skip = v4.find(root, "SkipHint")
    skip["pos"] = [0.5, 0, 1, -24]
    name = v4.find(root, "NameLabel")
    name["overhang"] = True  # the spelled-out name; the card replaces it at the final beat
    spec["children"].append(hero_card())
    return spec


# =================================================================== OfflineEarnings

def offline():
    spec = v4.offline()
    well = v4.find({"children": spec["children"]}, "EarnedWell")
    erow = next(k for k in well["children"] if k.get("name") == "EarnedRow")
    amt = next(k for k in erow["children"] if k.get("name") == "EarnedAmount")
    holder = frame("CoinHolder", 64, 64, [
        {**mp4.sunburst(104, colour=mp4.GOLD, alpha=0.2, pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5]), "z": 1},
        {**ico("IconYenBig", 64, name="Icon", pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5]), "z": 2},
    ])
    erow["children"] = [holder, amt]
    well["children"] = [erow]
    return spec


# =================================================================== the set

_REPLACE = {"hud_fx": hud_fx, "confirm": confirm, "rebirth": rebirth, "reveal": reveal, "offline": offline}
if _store_v5 is not None and hasattr(_store_v5, "store"):
    _REPLACE["store"] = _store_v5.store
SCREENS = [_REPLACE.get(f.__name__, f) for f in v42.SCREENS]
TEMPLATES = list(getattr(_store_v5, "TEMPLATES_OVERRIDE", None) or v42.TEMPLATES)
