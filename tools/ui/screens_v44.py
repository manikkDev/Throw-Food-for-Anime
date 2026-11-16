"""UI v4.4 (owner's review 5): the screens that changed, on top of screens_v43.

  window headings  ONE title style for every window (mp4.header is replaced here, so the Store gets it too): the
                   icon sized to the caps of the title (44 px for 36 px type), icon + title centred as ONE group by
                   real font metrics (the title grows with its text, AutomaticSize X), a white -> pale-gold text
                   gradient over a 2 px ink stroke, a soft darker band along the bar's lower edge; the close button
                   sits on the bar's vertical centre.
  HUD              the server announcement is a slim cinematic bar at the TOP centre (rarity accent edges, a round
                   portrait well, the hero name as the hero of the layout, a small "caught by" line, rarity chip and
                   odds on one baseline at the right). The toasts are compact pills stacked at the top centre under
                   whatever top-centre piece is showing (HudController moves the stack), never over the banner.
  Rebirth          a strict grid: two cards of equal height on row 1 (requirements: icon / caption + bar columns
                   shared by both rows; reward: title, two centred lines and the FOREVER chip on a 10 px rhythm),
                   two mirrored keep / lose cards of equal size on row 2 (titles centred by real metrics, a 2 x 2
                   list on shared columns, 18 px text), and the footer (status pill, REBIRTH button) on one centre
                   line, flush with the cards' outer edges.
"""

from __future__ import annotations

import math

import mp4
import mangapop as mp
import screens_v4 as v4
import screens_v42 as v42
import screens_v43 as v43
from mangapop import WHITE, frame, ico, row, col, sample
from mp4 import T, auto_label, card, chip, measure, sheen, track, vbtn
from screens import page
from screens_v42 import fx

# =================================================================== window headings (shared)

TITLE_PX = 36
TITLE_ICON = 44
TITLE_GRAD = ["#FFFFFF", "#FFE9A8"]


def header(title, colour="orange", icon=None, px=TITLE_PX):
    """The window title bar. Same geometry as before (68 px bar, 6 px inside the window's top edge) so every page
    keeps its body position; only the title group changed."""
    lab = auto_label("Title", title, px, dyn_=False)
    lab["textGrad"] = TITLE_GRAD
    kids = [lab]
    if icon:
        kids.insert(0, ico(icon, TITLE_ICON, name="TitleIcon"))
    row_w = lab["size"][1] + (TITLE_ICON + 10 if icon else 0)
    shade = {"type": "frame", "name": "HeaderShade", "colour": ["#000000", "#000000"], "alpha": 0.9,
             "outline": False, "corner": 16, "size": [1, 0, 0, 18], "pos": [0, 0, 1, 0], "anchor": [0, 1],
             "z": 2, "children": [], "overhang": True}
    return {"type": "frame", "name": "Header", "colour": mp4.HEADERS[colour], "corner": 16, "outline": False,
            "size": [1, -12, 0, 68], "pos": [0.5, 0, 0, 6], "anchor": [0.5, 0], "z": 2,
            "pattern": {"name": "stripes", "colour": "#FFFFFF", "opacity": 0.10, "tile": 64},
            "children": [sheen(corner=16, opacity=0.24), shade,
                         {**frame("TitleRow", row_w, 56, kids, layout=row(10, "center"),
                                  pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5], z=3), "autoW": 0}]}


mp4.header = header  # mp4.window looks it up at call time: every window, the Store's included

_post_prev = mp4._post4


def _post44(spec, top, palette):
    _post_prev(spec, top, palette)
    grad = spec.get("textGrad")
    if grad and spec.get("type") == "label":
        n = len(grad) - 1
        top.setdefault("children", []).append(mp.ub.instance("TextGradient", "UIGradient", {
            "Rotation": 90, "Color": {"ColorSequence": {"keypoints": [
                {"time": round(i / n, 4), "color": mp.ub.col3(mp4._rgb(c))["Color3"]} for i, c in enumerate(grad)]}}}))


mp4._post4 = _post44

# =================================================================== HUD: announcement bar + toasts

AN_W, AN_H, AN_Y = 760, 74, 62  # under the TutorialHint pill (y 14..54), in the luck bar's row
PORTRAIT = 56
META_W = 230


def announcement():
    """The server announcement: a slim dark bar at the top centre. Runtime (HudMoments.dressAnnouncement) tints
    AccentLeft / AccentRight / RarityWash / the bar's rim / the portrait rim in the rarity (or event) colour."""
    text_x = 22 + PORTRAIT + 16
    text_w = AN_W - text_x - META_W - 24 - 12
    accent = lambda name, x, ax: {"type": "frame", "name": name, "colour": [WHITE, "#E8E8E8"], "outline": False,
                                  "corner": 3, "size": [0, 5, 1, -26], "pos": [x, -8 if x else 8, 0.5, 0],
                                  "anchor": [ax, 0.5], "z": 3, "children": [], "overhang": True}
    wash = {**sheen("RarityWash", angle=0, opacity=0.30, bands=((0.03, 0.36), (0.97, 0.36)), corner=16), "z": 1}
    well = {"type": "frame", "name": "PortraitWell", "colour": ["#2A3088", "#12153A"], "corner": 1,
            "keyline": WHITE, "keepKeyline": True, "size": [0, PORTRAIT, 0, PORTRAIT], "pos": [0, 22, 0.5, 0],
            "anchor": [0, 0.5], "z": 3, "children": [
                {**ico("IconCrownBig", 36, name="AnnounceIcon", pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5]), "z": 4},
                {"type": "frame", "name": "AnnouncePortrait", "transparent": True, "cls": "ViewportFrame",
                 "size": [1, 0, 1, 0], "pos": [0.5, 0, 0.5, 0], "anchor": [0.5, 0.5], "z": 5, "children": [],
                 "overhang": True}]}
    text = frame("TextColumn", text_w, 62, [
        T("PlayerName", None, text_w, 16, font="display", align="left", colour="soft",
          samples=["CAUGHT BY XX_SUPERLONGNAME_XX", "SERVER LUCK"]),
        T("HeroName", None, text_w, 30, font="display", align="left",
          samples=["Heavenly String King", "x2 LUCK FOR 15 MIN"]),
    ], layout=col(4, "start"), pos=[0, text_x, 0.5, 0], anchor=[0, 0.5], z=3)
    meta = frame("MetaRow", META_W, 30, [
        v4.rchip("RarityChip", "RarityText", ["LEGENDARY", "SECRET"], "#A855F7", px=16, h=28),
        auto_label("OneInN", ["1 in 48.4M", "1 in 710"], 20, colour="yen"),
    ], layout=row(10, "end"), pos=[1, -24, 0.5, 0], anchor=[1, 0.5], z=3)
    return {"type": "frame", "name": "Announcement", "colour": ["#232866", "#0E1030"], "alpha": 0.06,
            "corner": 16, "keyline": WHITE, "keepKeyline": True, "size": [0, AN_W, 0, AN_H],
            "pos": [0.5, 0, 0, AN_Y], "anchor": [0.5, 0], "visible": False, "z": 6,
            "children": [wash, accent("AccentLeft", 0, 0), accent("AccentRight", 1, 1), well, text, meta]}


TOAST_H = 40
TOAST_GAP = 8
TOAST_KIND = {"info": "#3B82F6", "good": "#2FBF71", "bad": "#F0524D", "reward": "#F5A524"}
TOAST_ICON = {"info": "IconInfo", "good": "IconTick", "bad": "IconClose", "reward": "IconGift"}


def toast_template(name="ToastTemplate", text=None, kind="info"):
    """A compact notification pill: a coloured round icon well (repainted per kind), one line of 18 px text. The
    wrapper grows with the text (AutomaticSize X); the client slides and fades the `Face` inside it."""
    lab = auto_label("Text", text or ["Not enough yen for Festival Cake!"], 18)
    well = {"type": "frame", "name": "IconWell", "colour": [WHITE, "#DADDF0"], "corner": 1, "outline": False,
            "size": [0, 28, 0, 28], "children": [
                ico(TOAST_ICON[kind], 18, pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5])],
            "paint": TOAST_KIND[kind]}
    well["colour"] = [mp4.light(TOAST_KIND[kind], 0.12), TOAST_KIND[kind]]
    tail = {"type": "frame", "name": "Tail", "transparent": True, "size": [0, 4, 0, 10], "children": []}
    w = 6 + 28 + 10 + lab["size"][1] + 10 + 4 + 6
    face = {"type": "frame", "name": "Face", "colour": ["#262B6E", "#161A48"], "alpha": 0.04, "corner": TOAST_H // 2,
            "keyline": mp4.PANEL_EDGE, "keepKeyline": True, "size": [0, w, 0, TOAST_H],
            "pos": [0, 0, 0.5, 0], "anchor": [0, 0.5], "autoW": 6, "layout": row(10, "start"),
            "children": [well, lab, tail]}
    return {"type": "frame", "name": name, "transparent": True, "size": [0, w, 0, TOAST_H + 4], "autoW": 0,
            "children": [face]}


TOASTS_Y = 146  # under the server luck bar; HudController moves the stack under whatever top-centre piece shows


def hud():
    spec = v42.hud()
    root = {"children": spec["children"]}
    spec["children"] = [announcement() if k.get("name") == "Announcement" else k for k in spec["children"]]
    toasts = v4.find(root, "Toasts")
    toasts.update({"size": [0, 640, 0, 3 * (TOAST_H + 4) + 2 * TOAST_GAP], "pos": [0.5, 0, 0, TOASTS_Y],
                   "anchor": [0.5, 0], "layout": col(TOAST_GAP, "center"),
                   "children": [sample(toast_template(text=["Not enough yen for Festival Cake!"], kind="bad"), 1),
                                sample(toast_template(text=["Daily reward claimed!"], kind="reward"), 2)]})
    return spec


# =================================================================== Rebirth: a strict grid

RB_W = 820
GAP = 14
R1_H = 196                      # row 1: requirements | reward, equal heights
REQ_W = 496
REW_W = RB_W - REQ_W - GAP      # 310
R2_Y = R1_H + GAP
R2_H = 140                      # row 2: keep | lose, equal and mirrored
KEEP_W = (RB_W - GAP) // 2      # 373
FOOT_Y = R2_Y + R2_H + GAP
FOOT_H = 68
RB_H = FOOT_Y + FOOT_H          # 432
PAD = 16
TITLE_Y, TITLE_H = 14, 30       # every card title sits on this line
ITEM_PX = 18


def card_title(name, text, **kw):
    return T(name, text, 260, 18, font="display", colour="soft", align="left", pos=[0, PAD, 0, TITLE_Y + 4], **kw)


def rebirth():
    # ---- requirements: icon well | caption over bar, both rows on the same two columns
    well, bar_x = 50, PAD + 50 + 14
    bar_w = REQ_W - bar_x - PAD

    def req_row(name, icon, caption, fill, samples, y):
        return frame(f"{name}Row", REQ_W - 2 * PAD, 60, [
            v43.icon_well(f"{name}Well", icon, well, 34, icon_name=f"{name}Icon", pos=[0, 0, 0.5, 0],
                          anchor=[0, 0.5]),
            T(f"{name}Caption", caption, bar_w - 30, 16, colour="soft", font="display", align="left",
              pos=[0, bar_x - PAD, 0, 0]),
            {**ico("IconTick", 20, name=f"{name}Done", pos=[1, 0, 0, 0], anchor=[1, 0]), "visible": False,
             "mockHide": True},
            track(f"{name}Bar", bar_w, 32, 0.62, fill, text_name=f"{name}ReqText", samples=samples, px=18,
                  pos=[0, bar_x - PAD, 1, 0], anchor=[0, 1]),
        ], pos=[0, PAD, 0, y])
    req = card("Requirements", REQ_W, R1_H, "panelHi", [
        card_title("ReqTitle", "REQUIREMENTS"),
        {**v4.rchip("NextTierChip", "NextTier", ["REBIRTH 999", "MAX REBIRTH"], "#7B3FF2", px=16, h=TITLE_H),
         "pos": [1, -PAD, 0, TITLE_Y], "anchor": [1, 0]},
        req_row("Power", "IconPowerBig", "TOTAL POWER", "#38BDF8", ["999.99Qi / 999.99Qi", "6.8B / 600M"], 52),
        req_row("Yen", "IconYenBig", "YEN COST", "#34D17A", ["999.99Qi / 999.99Qi", "220B / 500B"], 122),
    ], pos=[0, 0, 0, 0])

    # ---- reward: title, two centred lines, FOREVER, on a 10 px rhythm (14 | 30 | 10 | 40 | 10 | 40 | 10 | 28 | 14)
    def reward_line(name, icon, text_name, samples, y):
        return {**frame(name, REW_W - 2 * PAD, 40, [ico(icon, 34, name=f"{name}Icon"),
                                                     auto_label(text_name, samples, 24)],
                        layout=row(10, "center"), pos=[0.5, 0, 0, y], anchor=[0.5, 0]), "z": 3}
    reward = {"type": "panel", "name": "Rewards", "colour": ["#FFD24A", "#FF8A1A"], "keyline": "#FFF1B8",
              "depth": 0, "corner": 16, "size": [0, REW_W, 0, R1_H], "pos": [1, 0, 0, 0], "anchor": [1, 0],
              "pattern": {"name": "stripes", "colour": "#FFFFFF", "opacity": 0.12, "tile": 96}, "children": [
                  v42.gloss_band(16, 0.22),
                  fx("FxGlow", 170, "Glow", tint="#FFF6C8", alpha=0.4, w=280, pos=[0.5, 0, 0.5, 6],
                     anchor=[0.5, 0.5], z=1, turn=0),
                  {**T("RewardTitle", "REWARD", REW_W - 2 * PAD, 18, font="display", pos=[0.5, 0, 0, TITLE_Y + 4],
                       anchor=[0.5, 0]), "z": 3},
                  reward_line("IncomeLine", "IconYenBig", "RewardIncome", ["+150% INCOME", "MAX REBIRTH"], 54),
                  reward_line("LuckLine", "IconLuckBig", "RewardLuck", ["+30% LUCK", "+10% LUCK"], 104),
                  {**chip("ForeverChip", "ForeverText", None, "#B4235A", px=16, h=28, static="FOREVER"),
                   "pos": [0.5, 0, 0, 154], "anchor": [0.5, 0], "z": 3},
              ]}

    # ---- keep / lose: mirrored cards, a centred title strip, a 2 x 2 list on shared columns
    col_w = (KEEP_W - 2 * 12 - 10) // 2
    longest = max(measure(t, ITEM_PX) for t in ["Hero Index", "Game passes", "Premium heroes", "Lucky Throws",
                                                "Yen and power", "Foods and gear", "Plot slots", "Caught heroes"])
    assert 22 + 8 + longest + 4 <= col_w, (longest, col_w)

    def keep_card(name, title, head, icon_key, items, x):
        cells = [frame(f"Item{i}", col_w, 30, [ico(icon_key, 22, name="ItemIcon"),
                                               T("Text", t, col_w - 30, ITEM_PX, align="left", font="display")],
                       layout=row(8, "start")) for i, t in enumerate(items, 1)]
        title_lab = auto_label("Title", title, 20, dyn_=False)
        strip = {"type": "frame", "name": f"{name}Head", "colour": head, "corner": 12, "outline": False,
                 "size": [1, -2 * 8, 0, 38], "pos": [0.5, 0, 0, 8], "anchor": [0.5, 0], "children": [
                     sheen(corner=12, opacity=0.22),
                     {**frame(f"{name}TitleRow", 24 + 8 + title_lab["size"][1], 30,
                              [ico(icon_key, 24, name="HeadIcon"), title_lab], layout=row(8, "center"),
                              pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5], z=3), "autoW": 0}]}
        return card(name, KEEP_W, R2_H, "panelHi", [
            strip,
            frame("List", 2 * col_w + 10, 2 * 30 + 10, cells,
                  layout={"type": "grid", "cell": [col_w, 30], "gap": 10, "cols": 2},
                  pos=[0.5, 0, 0, 58], anchor=[0.5, 0]),
        ], pos=[x, 0, 0, R2_Y], anchor=[x, 0])

    # ---- footer: status pill and REBIRTH on one centre line, flush with the cards' outer edges
    status = {**v43.icon_chip("CurrentChip", "CurrentRebirth", "IconRebirth",
                              ["You are at Rebirth 999", "You are at Rebirth 0"], "#1B1F4B", px=18, h=40,
                              keyline=mp4.PANEL_EDGE),
              "pos": [0, 0, 0.5, 0], "anchor": [0, 0.5]}
    button = vbtn("ConfirmButton", "buy", "L", icon="IconRebirth", text="REBIRTH!", w=300, pos=[1, 0, 0.5, 0],
                  anchor=[1, 0.5])
    footer = frame("Footer", RB_W, FOOT_H, [
        status,
        fx("FxGlow", 84, "ButtonGlow", tint="#FFE38A", alpha=0.4, w=300, pos=[1, -150, 0.5, 0], anchor=[0.5, 0.5],
           z=0, turn=0),
        button,
    ], pos=[0, 0, 0, FOOT_Y])

    body = [req, reward,
            keep_card("Keeps", "YOU KEEP", ["#4BE08A", "#14935A"], "IconTick",
                      ["Hero Index", "Game passes", "Premium heroes", "Lucky Throws"], 0),
            keep_card("Resets", "YOU LOSE", ["#FF6B6B", "#C42A3A"], "IconClose",
                      ["Yen and power", "Foods and gear", "Plot slots", "Caught heroes"], 1),
            footer]
    return page("Rebirth", v4.window("REBIRTH", RB_W, RB_H, body, colour="gold", icon="IconRebirthBig"))


# =================================================================== the set

_REPLACE = {"hud": hud, "rebirth": rebirth}
SCREENS = [_REPLACE.get(getattr(f, "__name__", ""), f) for f in v43.SCREENS]
TEMPLATES = [((toast_template if getattr(f, "__name__", "") == "toast_template" else f), o) for f, o in v43.TEMPLATES]
