"""UI v4.6 (owner's review 7): the screens that changed, on top of screens_v44.

  Reveal   the final hero info card is compact (panel 410 x 130, was 640 x 186: 64% x 70%; 45% of the area): rarity ribbon on its top
           edge, the name, one row of tags, the income centred, the stamp on its corner, the sold line on its bottom
           edge. The card no longer carries the odds: the final beat shows them at the TOP centre instead
           (`FinalOdds`: a glow and a turning sunburst behind a big "1 IN 2,500" in the rarity colour, a CHANCE
           caption chip under it; RevealUi slams it in, shakes it, and sweeps a shine through the letters).
  HUD      the event bar is no longer a bar at the top centre: `ServerLuckBar` is a compact chip (icon, multiplier
           over the clock, the Robux boost button) just left of the right button column, level with its first button. The announcement
           tells the event once; the chip pops in after it.
"""

from __future__ import annotations

import mp4
import screens_v4 as v4
import screens_v43 as v43
import screens_v44 as v44
from mangapop import WHITE, frame, ico, row, col
from mp4 import T, auto_label, card, ribbon_tag, vbtn
from screens import MUT_HEX
from screens_v42 import NAVY, fx, gloss_band, twinkle

# =================================================================== Reveal: the compact hero card

CARD_W, CARD_H = 410, 130


def hero_card():
    ribbon = {**v4.rchip("RarityRibbon", "RarityText", ["LEGENDARY", "UNCOMMON", "SECRET"], "#A855F7", px=16,
                         h=28), "pos": [0.5, 0, 0, -14], "anchor": [0.5, 0], "z": 8, "overhang": True}
    stamp = {**ribbon_tag("Stamp", "NEW!", colour="danger", text_name="StampLabel",
                          samples=["NEW BEST!", "LUCKY!", "NEW!"], px=15, h=26, w=104),
             "pos": [1, -44, 0, -12], "anchor": [0.5, 0], "z": 9}
    stars = {**frame("Stars", 3 * 18 + 2 * 2, 20, [ico("IconStar", 18, name=f"Star{i}") for i in (1, 2, 3)],
                     layout=row(2, "center")), "autoW": 0}
    tags = frame("TagRow", CARD_W - 6, 26, [
        mp4.pill_auto("SizeTag", "SizeText", ["TITAN", "HUGE"], "info", px=14, h=24),
        mp4.pill_auto("MutationTag", "MutationText", ["LIGHTNING", "GALAXY"], MUT_HEX["Lightning"], px=14, h=24),
        v43.icon_chip("CraveTag", "CraveText", "IconFlavorSavory", ["CRAVING!", "CRAVES SEAFOOD"], "#B4235A",
                      px=14, h=24),
        stars,
    ], layout=row(6, "center"), pos=[0.5, 0, 0, 52], anchor=[0.5, 0])
    income = frame("IncomeRow", 240, 36, [ico("IconYenBig", 32, name="YenIcon"),
                                          auto_label("IncomeLabel", ["+999.99Qi/s", "+1.2K/s"], 28, colour="luck")],
                   layout=row(6, "center"), pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5])
    stats = frame("StatsRow", CARD_W - 40, 36, [income], pos=[0.5, 0, 0, 84], anchor=[0.5, 0])
    sold = {**v4.rchip("SoldTag", "SoldLabel", ["sold for 999.99Qi yen", "sent to your bench"], "#1B1F4B", px=14,
                       h=24), "pos": [0.5, 0, 1, -8], "anchor": [0.5, 0], "z": 8, "overhang": True}
    panel = {"type": "panel", "name": "CardPanel", "colour": NAVY, "keyline": WHITE, "depth": 0, "corner": 20,
             "size": [0, CARD_W, 0, CARD_H], "pos": [0.5, 0, 1, 0], "anchor": [0.5, 1], "z": 3,
             "pattern": {"name": "dots", "colour": "#FFFFFF", "opacity": 0.06, "tile": 22}, "children": [
                 gloss_band(20, 0.14),
                 ribbon, stamp,
                 {**T("CardName", None, CARD_W - 120, 26, font="display",
                      samples=["Heavenly String King", "Copy Ninja"], pos=[0.5, 0, 0, 14], anchor=[0.5, 0]), "z": 4},
                 tags, stats, sold,
             ]}
    return frame("HeroCard", CARD_W + 48, CARD_H + 30, [
        fx("FxGlow", 110, "Glow", tint="#FFFFFF", alpha=0.45, w=CARD_W + 48, pos=[0.5, 0, 0, 34],
           anchor=[0.5, 0.5], z=1, turn=0),
        panel,
        twinkle("Twinkle1", 22, [0, 30, 0, 30], z=6), twinkle("Twinkle2", 16, [1, -26, 1, -26], z=6),
    ], pos=[0.5, 0, 1, -30], anchor=[0.5, 1], overhang=True)


# the final beat's odds, at the top centre under the letterbox bar (79 px at 720)
ODDS_W, ODDS_Y = 620, 86
ODDS_PX = 58


def final_odds():
    big = {**auto_label("FinalOddsText", ["1 IN 999.99Qi", "1 IN 48,400,000", "1 IN 2,500"], ODDS_PX),
           "pos": [0.5, 0, 0, 0], "anchor": [0.5, 0], "z": 5}
    caption = {**mp4.chip("ChancePill", "ChanceText", None, "#1B1F4B", px=16, h=28, static="CHANCE"),
               "pos": [0.5, 0, 0, 82], "anchor": [0.5, 0], "z": 6}
    return frame("FinalOdds", ODDS_W, 112, [
        fx("FxGlow", 150, "Glow", tint="#FFFFFF", alpha=0.35, w=ODDS_W, pos=[0.5, 0, 0, 38],
           anchor=[0.5, 0.5], z=1, turn=0),
        fx("FxSunburst", 220, "Sunburst", tint="#FFFFFF", alpha=0.45, pos=[0.5, 0, 0, 38],
           anchor=[0.5, 0.5], z=2, turn=40),
        big, caption,
        twinkle("Twinkle1", 26, [0, 70, 0, 20], z=7), twinkle("Twinkle2", 20, [1, -70, 0, 64], z=7),
    ], pos=[0.5, 0, 0, ODDS_Y], anchor=[0.5, 0], overhang=True)


def reveal():
    spec = v43.reveal()
    kids = [k for k in spec["children"] if k.get("name") != "HeroCard"]
    spec["children"] = kids + [final_odds(), hero_card()]
    return spec


# =================================================================== HUD: the event chip

CHIP_W, CHIP_H = 224, 56
CHIP_Y = 236  # beside the right button column (x 1184..1260, y 224..468), clear of the player list zone


def event_chip():
    text = frame("EventText", 112, 46, [
        {**T("Multiplier", None, 112, 20, colour="luck", font="display", align="left",
             samples=["x1.75 LUCK", "FESTIVAL"]), "pos": [0, 0, 0, 0]},
        {**T("TimeLeft", None, 112, 15, align="left", samples=["14:59", "1:02:59"]), "pos": [0, 0, 1, 0],
         "anchor": [0, 1]},
    ])
    return card("ServerLuckBar", CHIP_W, CHIP_H, "panel", [
        ico("IconLuckBig", 34, name="Icon"),
        text,
        vbtn("BoostButton", "premium", "S", icon="IconRobux", w=44),
    ], layout=row(8, "center"), pos=[1, -108, 0, CHIP_Y], anchor=[1, 0], z=4)


def hud():
    spec = v44.hud()
    spec["children"] = [event_chip() if k.get("name") == "ServerLuckBar" else k for k in spec["children"]]
    return spec


_REPLACE = {"hud": hud, "reveal": reveal}
SCREENS = [_REPLACE.get(getattr(f, "__name__", ""), f) for f in v44.SCREENS]
TEMPLATES = v44.TEMPLATES
