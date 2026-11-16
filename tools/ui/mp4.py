"""UI v4 system on top of mp3 / mangapop: thin clean strokes, no offset shadows, a bigger type scale.

Owner's review (design/ui/CHANGES-v4.md) turned into properties of the helpers, so a screen cannot get it
wrong by hand:

  strokes     one 2 px stroke on every frame, panel and button face (ApplyStrokeMode Border). No comic
              offset shadow anywhere (normalize() strips it from any spec). Text strokes 1.5 px under 24 px,
              2 px from 24 px up (ApplyStrokeMode Contextual).
  lip         only BUTTONS keep a lip: a darker slab of the face colour under it, NO stroke of its own, so it
              reads as the press lip, not as a second border. Panels and cards are flat (depth 0).
  type        reference 1280x720: chips/meta >= 18, body >= 20, row titles >= 24, buttons S 22 / M 24 / L 28,
              window titles 40. Nothing on screen under 16.
  buttons     S 44, M 52, L 64. Icon 0.6 x height in a square slot (ScaleType Fit), caption box centred in the
              rest of the face, 0.35 x height clear on each side. Width is derived from the text, never stretched.
  new nodes   "sheen": a diagonal white band (UIGradient transparency), "ring": a circle outline (UICorner 1 +
              UIStroke), "strokeGrad": a rainbow / gradient stroke (UIGradient under the UIStroke),
              "autoW": a frame that grows with its content (AutomaticSize X + UIPadding).
"""

from __future__ import annotations

import math

import mangapop as mp
import mp3
from mangapop import WHITE, ub
from PIL import Image, ImageChops, ImageDraw, ImageFont

# v4.1 (owner review 2): the WHITE border is back, clearly visible: 3 px on buttons and cards, 4 px on windows,
# 2 px on chips, ribbons and small tracks (an integer: the face is inset by it). Never an angled black offset shadow.
STROKE = 3
WINDOW_STROKE = 4
CHIP_STROKE = 2
KEYLINE = "#FFFFFF"
# keylines that MEAN something keep their colour (the NEXT food's gold, the leaderboard medals)
KEEP_KEYLINE = {"#FFC93C", "#C9D3E3", "#E8893A"}
# Luckiest Guy sits high in its line box (ascent 1440 / descent 608 of 2048: caps centre 0.145 em above the box
# centre), so every centred display label is nudged down by a top padding of 2 x DISPLAY_NUDGE em. One constant
# to tune after looking in game.
DISPLAY_NUDGE = 0.12
SIZE_H = {"S": 48, "M": 56, "L": 68}
SIZE_T = {"S": 24, "M": 26, "L": 30}
LIP = {"S": 4, "M": 4, "L": 5}
MIN_TEXT = 16
mp3.SIZE_H.update(SIZE_H)
mp3.SIZE_T.update(SIZE_T)
mp3.LIP.update(LIP)
mp3.MIN_TEXT = MIN_TEXT
# glossier candy face: bright top half with a hard gloss step, deeper bottom (a multiply gradient, so a client
# repaint of BackgroundColor3 keeps it)
mp3.GLOSS[:] = [(0.0, 0.74), (0.5, 0.86), (0.51, 1.0), (1.0, 1.0)]

PANEL_EDGE = "#5B64C9"     # window / card keyline: a lighter navy, reads as a clean edge on the navy page
GOLD = "#FFC93C"
RAINBOW = ["#FF4D6D", "#FFB020", "#FFE14D", "#4ADE80", "#38BDF8", "#A855F7", "#FF4D6D"]


# ------------------------------------------------------------------ measuring

_FONTS = {}


def measure(text, px, display=True):
    """Real advance width of `text` at `px` (Luckiest Guy for display, Fredoka One otherwise)."""
    key = (display, px)
    if key not in _FONTS:
        path = mp._FONT_DST if display else (ub.FONT_DIR / "FredokaOne-Regular.ttf")
        _FONTS[key] = ImageFont.truetype(str(path), px)
    return _FONTS[key].getlength(text)


def est(text, px, display=True, stroke=2):
    return mp3.est_w(text, px, display, stroke)


def _hex(c):
    pal = (mp.BASE.get("theme") or {}).get("palette", {})
    c = pal.get(c, c)
    return c if c.startswith("#") else "#" + c


def light(h, k):
    return mp3._light(_hex(h), k)


def dark(h, k):
    return mp3._mul(_hex(h), k)


# ------------------------------------------------------------------ text

def tstroke(px, colour):
    if colour in ("ink", "powerInk", "luckInk", "premiumInk", "inkSoft") or str(colour).startswith("#0") \
            or str(colour).startswith("#1") or str(colour).startswith("#2") or str(colour).startswith("#3"):
        return 0
    return 2 if px >= 24 else 1.5


def T(name, text, w, px, colour="onDark", font=None, samples=None, align="center", lines=1, **kw):
    """A label: box = px x 1.25 per line, capped at px, thin stroke."""
    px = max(px, MIN_TEXT)
    h = math.ceil(px * (1.25 if lines == 1 else 1.12 * lines + 0.1))
    mk = mp.dyn if samples else mp.lbl
    args = dict(px=px, colour=colour, font=font, align=align, wrap=lines > 1, stroke=tstroke(px, colour))
    n = mk(name, samples, w, h, **args, **kw) if samples else mk(name, text, w, h, **args, **kw)
    n["maxText"] = px
    return n


def auto_label(name, samples_or_text, px, colour="onDark", font="display", dyn_=True, **kw):
    """A label that grows with its text (AutomaticSize X, TextSize fixed). The spec box is the real
    width of the longest sample, so the mockup shows what Roblox will size it to."""
    samples = samples_or_text if isinstance(samples_or_text, list) else [samples_or_text]
    w = math.ceil(max(measure(s, px, font == "display") for s in samples)) + 6
    h = math.ceil(px * 1.25)
    n = (mp.dyn(name, samples, w, h, px=px, colour=colour, font=font, stroke=tstroke(px, colour), **kw) if dyn_
         else mp.lbl(name, samples[0], w, h, px=px, colour=colour, font=font, stroke=tstroke(px, colour), **kw))
    n["maxText"] = px
    n["autoX"] = True
    return n


# ------------------------------------------------------------------ buttons

def caption(name, samples, text, cap_w, h, px, font="display", colour="onDark"):
    """A button caption: as wide as its text in game (AutomaticSize X, fixed TextSize, capped at `cap_w` by a
    UISizeConstraint; Screens shrinks the TextSize if a longer string arrives), so the parent's centred row
    layout centres icon + text as ONE group. The spec box is the real width of the longest sample."""
    strings = list(samples or []) + ([text] if text else [])
    tw = min(cap_w, math.ceil(max(measure(s, px, font == "display") for s in strings)) + 4)
    stroke = tstroke(px, colour)
    n = (mp.dyn(name, samples, tw, h, px=px, font=font, colour=colour, stroke=stroke) if samples
         else mp.lbl(name, text, tw, h, px=px, font=font, colour=colour, stroke=stroke))
    n.update({"maxText": px, "autoX": True, "capW": int(cap_w)})
    return n


def vbtn(name, colour, size, icon=None, text=None, samples=None, text_name="Label", font="display",
         w=None, minw=None, self_face=True, text_colour="onDark", icon_name="Icon", px=None, **kw):
    """THE button. Height from the class, width from the text; icon 0.6 h square, caption centred WITH it."""
    h = SIZE_H[size]
    px = px or SIZE_T[size]
    lip = LIP[size]
    padx = math.ceil(0.32 * h)
    ih = math.floor(h - 2 * STROKE - lip - 2 * math.ceil(0.06 * h))
    strings = list(samples or []) + ([text] if text else [])
    isz = round(0.58 * h) if icon else 0
    gap = round(0.14 * h) if icon and strings else 0
    tw = math.ceil(max((measure(s, px, font == "display") + 4 for s in strings), default=0))
    content = isz + gap + tw
    W = w or content + 2 * padx
    if minw:
        W = max(W, minw)
    cap_w = max(16, W - 2 * STROKE - 2 * 8 - isz - gap)
    kids = []
    if icon:
        kids.append(mp.ico(icon, isz, name=icon_name))
    if strings:
        kids.append(caption(text_name, samples, text, cap_w, ih, px, font, text_colour))
    node = {"type": "button", "name": name, "size": [0, round(W), 0, h], "children": kids,
            "layout": mp.row(gap, "center"), "sizeClass": size, "depth": lip, "corner": round(h * 0.34),
            **kw}
    if self_face:
        node["selfFace"] = True
    mp3.gloss(node, colour)
    node["attrs"] = {**node.get("attrs", {}), "PressLip": lip}
    if colour in ("confirm", "buy", "premium", "coral", "gold"):
        node["attrs"]["AutoShine"] = True
    return node


def vbtn2(name, colour, size, top_text, icon, price_samples, price_name="Price", top_name="Count", w=None,
          top_samples=None, **kw):
    """Two-line price button: quantity over [currency][price], both centred inside the face (the price row
    grows with its text, so icon + price stay one centred group)."""
    h = SIZE_H[size]
    lip = LIP[size]
    padx = math.ceil(0.32 * h)
    ih = math.floor(h - 2 * STROKE - lip - 6)
    top_px = 18 if size == "L" else 16
    top_h = top_px + 2
    pr_h = ih - top_h
    pr_px = 26 if size == "L" else 22
    isz = pr_h - 2
    tw = math.ceil(max(measure(s, pr_px) for s in price_samples)) + 4
    tops = (top_samples or []) + [top_text]
    W = w or math.ceil(max(isz + 4 + tw, max(measure(t, top_px) for t in tops))) + 2 * padx
    t = (mp.dyn(top_name, top_samples, W - 2 * padx, top_h, px=top_px, font="display", stroke=1.5)
         if top_samples else mp.lbl(top_name, top_text, W - 2 * padx, top_h, px=top_px, font="display", stroke=1.5))
    t["maxText"] = top_px
    p = caption(price_name, price_samples, None, W - 2 * padx - isz - 4, pr_h, pr_px)
    row_ = mp.frame("PriceRow", min(W - 2 * padx, isz + 4 + p["size"][1]), pr_h, [mp.ico(icon, isz), p],
                    layout=mp.row(4, "center"))
    row_["autoW"] = 0
    node = {"type": "button", "name": name, "size": [0, round(W), 0, h], "sizeClass": size, "depth": lip,
            "corner": round(h * 0.34), "layout": mp.col(0, "center"), "children": [t, row_], **kw}
    mp3.gloss(node, colour)
    node["attrs"] = {**node.get("attrs", {}), "PressLip": lip}
    if colour in ("confirm", "buy", "premium", "coral", "gold"):
        node["attrs"]["AutoShine"] = True
    return node


def state_pill(name, text_name, samples, size="M", icon="IconTick", w=None, **kw):
    """A STATE, not a button: flat slate pill with a tick (EQUIPPED, CLAIMED, OWNED); tick + text centred."""
    h = SIZE_H[size]
    px = SIZE_T[size]
    padx = math.ceil(0.25 * h)
    tw = math.ceil(max(measure(s, px) for s in samples)) + 4
    isz = round(0.5 * h)
    W = w or isz + 6 + tw + 2 * padx
    t = caption(text_name, samples, None, W - 2 * padx - isz - 6, round(0.62 * h), px)
    return {"type": "panel", "name": name, "colour": ["#5C628F", "#5C628F"], "size": [0, round(W), 0, h],
            "corner": round(h * 0.34), "depth": 0, "layout": mp.row(6, "center"),
            "children": [mp.ico(icon, isz), t], **kw}


def round_x(name="CloseButton", side=56, icon_side=30, **kw):
    """The round red X (close a window, leave a throw spot / station): 56 px hit, lip 3."""
    node = {"type": "button", "name": name, "colour": "danger", "size": [0, side, 0, side], "corner": side // 2,
            "depth": 3, "sizeClass": "X", "children": [
                mp.ico("IconClose", icon_side, pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5])], **kw}
    mp3.gloss(node, "danger")
    node["attrs"] = {**node.get("attrs", {}), "PressLip": 3}
    return node


# ------------------------------------------------------------------ decoration

def sheen(name="Sheen", angle=-24, opacity=0.32, bands=((0.30, 0.05), (0.40, 0.10)), corner=12, **kw):
    """A diagonal white sheen: UIGradient transparency bands on a white frame, rotated."""
    return {"type": "sheen", "name": name, "size": kw.pop("size", [1, 0, 1, 0]), "angle": angle,
            "opacity": opacity, "bands": [list(b) for b in bands], "corner": corner, "overhang": True,
            "children": [], **kw}


def ring(name, side, colour, thick, **kw):
    return {"type": "ring", "name": name, "size": [0, side, 0, side], "ringColour": colour, "thick": thick,
            "children": [], **kw}


def sunburst(side, colour="#FFFFFF", alpha=0.0, name="Sunburst", **kw):
    n = mp.ico("FxSunburst", side, name=name, **kw)
    n["tint"] = colour
    n["alphaImg"] = alpha
    n.setdefault("overhang", True)
    return n


def sparkle(name, side, pos, rot=0, **kw):
    n = mp.ico("IconStar", side, name=name, pos=pos, anchor=[0.5, 0.5], **kw)
    n["overhang"] = True
    if rot:
        n["rotation"] = rot
    return n


def ribbon_tag(name, text, colour="danger", text_name=None, samples=None, w=None, h=30, px=18, **kw):
    """BEST VALUE / LIMITED / NEW: a pill centred on a card's top edge (half above it), above everything."""
    strings = (samples or []) + [text]
    tw = math.ceil(max(est(s, px) for s in strings))
    W = w or tw + 22
    t = mp.lbl(text_name or f"{name}Text", text, W - 12, h - 6, px=px, font="display", stroke=1.5,
               pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5])
    if samples:
        t.update({"text": mp.SENTINEL, "samples": strings})
        mp.DISPLAY_TEXTS.update(strings)
    t["maxText"] = px
    node = {"type": "panel", "name": name, "colour": colour, "size": [0, W, 0, h], "corner": h // 2, "depth": 0,
            "keyline": WHITE, "selfFace": True, "paintable": True, "pos": [0.5, 0, 0, -h // 2],
            "anchor": [0.5, 0], "z": 8, "overhang": True, "children": [t, sheen(corner=h // 2, opacity=0.25)]}
    node.update(kw)
    return node


def chip(name, text_name, samples, colour, px=18, h=28, static=None, w=None, **kw):
    """A coloured pill with one label (rarity, size, mutation): paintable, width from the text."""
    strings = list(samples or []) + ([static] if static else [])
    tw = math.ceil(max(est(s, px) for s in strings))
    W = w or tw + 20
    inner = (mp.lbl(text_name, static, W - 10, h - 6, px=px, font="display", stroke=1.5) if static is not None
             else mp.dyn(text_name, samples, W - 10, h - 6, px=px, font="display", stroke=1.5))
    inner.update({"pos": [0.5, 0, 0.5, 0], "anchor": [0.5, 0.5], "maxText": px})
    return {"type": "panel", "name": name, "colour": colour, "size": [0, W, 0, h], "selfFace": True,
            "paintable": True, "depth": 0, "corner": h // 2, "children": [inner], **kw}


def pill_auto(name, text_name, samples, colour, px=20, h=32, cell=True, **kw):
    """A pill that grows with its text in game (AutomaticSize X on cell, pill and label)."""
    lab = auto_label(text_name, samples, px)
    lab["pos"], lab["anchor"] = [0, 0, 0.5, 0], [0, 0.5]
    w = lab["size"][1] + 24
    pill = {"type": "frame", "name": name, "colour": [_hex(colour), _hex(colour)], "paint": _hex(colour),
            "corner": h // 2, "size": [0, w, 0, h], "autoW": 12, "layout": mp.row(0, "center"),
            "children": [lab]}
    if not cell:
        pill.update(kw)
        return pill
    return {"type": "frame", "name": f"{name}Cell", "transparent": True, "size": [0, w, 0, h], "autoW": 0,
            "children": [pill], **kw}


# ------------------------------------------------------------------ window

HEADERS = {
    "orange": ["#FFB13D", "#FF6B3D"], "blue": ["#4FC3FF", "#2F6BFF"], "violet": ["#C27BFF", "#7B3FF2"],
    "pink": ["#FF7AC3", "#E8358F"], "gold": ["#FFE066", "#FFA41B"], "green": ["#6EE68E", "#1FB46A"],
    "teal": ["#4FE3D2", "#1597A8"], "slate": ["#8C95D9", "#4C55A8"], "purple": ["#B07CFF", "#6A2FD6"],
}


def header(title, colour="orange", icon=None, px=40):
    tw = math.ceil(measure(title, px)) + 10
    kids = [T("Title", title, tw, px, font="display")]
    if icon:
        kids.insert(0, mp.ico(icon, 52, name="TitleIcon"))
    row_w = tw + (52 + 12 if icon else 0)
    return {"type": "frame", "name": "Header", "colour": HEADERS[colour], "corner": 16, "outline": False,
            "size": [1, -12, 0, 68], "pos": [0.5, 0, 0, 6], "anchor": [0.5, 0], "z": 2,
            "pattern": {"name": "stripes", "colour": "#FFFFFF", "opacity": 0.12, "tile": 64},
            "children": [sheen(corner=16, opacity=0.28),
                         mp.frame("TitleRow", row_w, 56, kids, layout=mp.row(12, "center"),
                                  pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5], z=3)]}


def window(title, body_w, body_h, body, colour="orange", icon=None, extra=(), top=86, name="Window"):
    """A modal page: scrim + one Window (flat navy, one thin keyline) with a gradient Header bar inside its
    top edge, the round red CloseButton on the header's right end, and the Body under it."""
    w, h = body_w + 40, body_h + top + 20
    body_node = mp.frame("Body", body_w, body_h, body, pos=[0.5, 0, 0, top], anchor=[0.5, 0])
    win = {"type": "panel", "name": name, "colour": ["#2C3280", "#181B4C"], "keyline": KEYLINE, "depth": 0,
           "stroke": WINDOW_STROKE,
           "corner": 22, "size": [0, w, 0, h], "pos": [0.5, 0, 0.5, 0], "anchor": [0.5, 0.5], "modal": True,
           "pattern": {"name": "dots", "colour": "#FFFFFF", "opacity": 0.05, "tile": 28},
           "children": [header(title, colour, icon),
                        round_x("CloseButton", pos=[1, -14, 0, 12], anchor=[1, 0], z=4, closes=True, overhang=True),
                        *extra, body_node]}
    scrim = {"type": "frame", "name": "Scrim", "colour": [mp.INK, mp.INK], "alpha": 0.55, "outline": False,
             "z": -2, "size": [1, 0, 1, 0], "children": []}
    return [scrim, win]


def card(name, w, h, colour="panelHi", children=(), keyline=PANEL_EDGE, **kw):
    """A flat card: gradient face, one thin keyline, no lip, no shadow."""
    return {"type": "panel", "name": name, "colour": colour, "keyline": keyline, "depth": 0, "corner": 16,
            "size": [0, w, 0, h], "children": list(children), **kw}


def track(name, w, h, value, fill_hex, text_name=None, samples=None, px=None, **kw):
    """A progress bar: dark track, painted Fill with a sheen, value text centred on top."""
    kids = [mp.fill_frame("Fill", fill_hex, size=[value, -6, 1, -6], pos=[0, 3, 0.5, 0], anchor=[0, 0.5],
                          outline=False, corner=max(4, (h - 6) // 2), overhang=True)]
    kids[0]["children"] = [sheen(corner=max(4, (h - 6) // 2), opacity=0.30, angle=-90,
                                 bands=((0.62, 0.10), (0.72, 0.06)))]
    if samples:
        px = px or round(h * 0.7)
        t = mp.dyn(text_name, samples, w - 16, h, px=px, font="display", stroke=tstroke(px, "x"))
        t.update({"pos": [0.5, 0, 0.5, 0], "anchor": [0.5, 0.5], "overhang": True, "z": 3, "maxText": px,
                  "textScale": round(px / h, 4)})
        kids.append(t)
    return {"type": "frame", "name": name, "colour": ["#0B0D29", "#161A48"], "size": [0, w, 0, h],
            "corner": h // 2, "keyline": "#3A4196", "children": kids, **kw}


# ------------------------------------------------------------------ normalisation pass

def _keyline(node):
    kl = node.get("keyline")
    if node.get("keepKeyline") or (isinstance(kl, str) and kl.upper() in KEEP_KEYLINE):
        return kl
    return KEYLINE


RIM_TINT = 0.5
NAVY_RIM = "#6F79D8"


def _face_hex(node):
    c = node.get("colour")
    if isinstance(c, list):
        c = c[0]
    if not isinstance(c, str):
        return None
    try:
        return _hex(c)
    except Exception:  # noqa: BLE001
        return None


def _is_navy(node):
    c = node.get("colour")
    if isinstance(c, str) and c in ("panel", "panelHi", "panelDeep"):
        return True
    hx = _face_hex(node)
    if not hx:
        return False
    r, g, b = ub.hex_rgb(hx)
    return b > r + 20 and b > g + 10 and max(r, g, b) < 140


def normalize(node):
    """The v4 rules as one pass over a whole spec (also catches anything inherited from v1-v3 builders).
    v4.1: every panel, button and keylined frame gets the WHITE border at its class thickness."""
    node.pop("comic", None)
    kind = node.get("type")
    h = node.get("size", [0, 0, 0, 0])[3] if node.get("size", [0, 0, 0, 0])[2] == 0 else 999
    if kind == "panel":
        if node.get("depth", 0) and not node.get("keepLip"):
            node["depth"] = 0
        if node.get("stroke") != WINDOW_STROKE:
            node["stroke"] = CHIP_STROKE if h <= 34 else STROKE
        if node.get("outline", True) is not False:
            kl = node.get("keyline")
            if isinstance(kl, str) and kl.upper() not in ("#FFFFFF", WHITE.upper()) and h > 34                     and node.get("stroke") != WINDOW_STROKE:
                # v4.2: a card that names its own accent rim keeps it (store sections, stat rows, prompt card)
                pass
            elif _is_navy(node) and h > 34 and node.get("stroke") != WINDOW_STROKE and not node.get("keepKeyline"):
                # a plain navy card inside a window: a soft periwinkle accent, white reads cheap there
                node["keyline"] = NAVY_RIM
            else:
                # windows, chips, ribbons, stickers, toasts and banners over the world, rarity tiles: white
                node["keyline"] = _keyline(node)
    if kind == "button":
        node["stroke"] = CHIP_STROKE if h <= 34 else STROKE
        node["depth"] = min(node.get("depth", 3), 5)
        node["keyline"] = _keyline(node)
        # v4.2 (owner's review 3: "not white everywhere"): a button's rim is a PALE TINT OF ITS OWN COLOUR, so it reads
        # as the glossy edge of the candy, not a white outline drawn round it. Attribute Rim = the tint amount, so
        # Screens.tint keeps the rim matching when the client repaints the face (afford / cannot / robux ...).
        base = _face_hex(node)
        if base and not node.get("keepKeyline"):
            node["keyline"] = light(base, RIM_TINT)
            node["attrs"] = {**node.get("attrs", {}), "Rim": RIM_TINT}
    if kind == "frame" and node.get("keyline") and node.get("outline", True) is not False:
        node["keyline"] = _keyline(node)
        node["strokePx"] = 2 if h <= 30 else STROKE
    if kind == "label":
        cap = node.get("maxText") or int(node["size"][3] * node.get("textScale", 0.62))
        if node["size"][2] == 0 and not node.get("autoX") and cap < MIN_TEXT:
            h = node["size"][3]
            node["maxText"] = MIN_TEXT
            if MIN_TEXT / h > 0.85:
                node["size"][3] = h = math.ceil(MIN_TEXT / 0.8)
            node["textScale"] = round(max(node.get("textScale", 0.62), (MIN_TEXT + 0.05) / h), 4)
            cap = MIN_TEXT
        ts = node.get("textStroke", 2)
        if ts:
            node["textStroke"] = min(ts, 2 if cap >= 24 else 1.5)
    for c in node.get("children") or []:
        normalize(c)
    return node


# ------------------------------------------------------------------ renderer + emitter additions

def _inset(spec, theme):
    st = spec.get("stroke", theme["stroke"])
    lip = spec.get("_lip", spec.get("depth", theme["shadowOffset"])) or 0
    return st, st, st, st + lip


mp3.inset = _inset


def _rgb(c):
    return ub.hex_rgb(_hex(c))


def _grad_img(size, stops, angle_deg):
    """An RGB image of a multi-stop linear gradient at Roblox's UIGradient Rotation (clockwise from +X)."""
    w, h = max(1, int(size[0])), max(1, int(size[1]))
    a = math.radians(angle_deg)
    ca, sa = math.cos(a), math.sin(a)
    span = abs(w * ca) + abs(h * sa)
    img = Image.new("RGB", (w, h))
    px = img.load()
    pts = [(t, c) for t, c in stops]
    for y in range(h):
        for x in range(w):
            t = 0.5 + ((x - w / 2) * ca + (y - h / 2) * sa) / max(1, span)
            for (t0, c0), (t1, c1) in zip(pts, pts[1:]):
                if t0 <= t <= t1:
                    u = (t - t0) / max(1e-6, t1 - t0)
                    px[x, y] = tuple(int(c0[i] + (c1[i] - c0[i]) * u) for i in range(3))
                    break
            else:
                px[x, y] = pts[0][1] if t < pts[0][0] else pts[-1][1]
    return img


def _sheen_alpha(spec):
    """Transparency keypoints of a sheen: (time, opacity)."""
    pts = [(0.0, 0.0)]
    for c, hw in sorted(spec["bands"]):
        pts += [(max(0.001, c - hw), 0.0), (c, spec["opacity"]), (min(0.999, c + hw), 0.0)]
    pts.append((1.0, 0.0))
    pts = sorted(set(pts))
    out, last = [], -1
    for t, o in pts:
        if t > last + 1e-4:
            out.append((round(t, 4), o))
            last = t
    return out


_draw_prev = ub.draw_node


def _draw4(img, draw, node, theme, palette, icons):
    s = node.spec
    kind = s.get("type", "frame")
    SS = ub.SS
    x, y, w, h = (v * SS for v in node.rect)
    if w <= 0 or h <= 0:
        return
    if kind == "sheen":
        W, H = int(w), int(h)
        pts = _sheen_alpha(s)
        g = _grad_img((W // 4 + 1, H // 4 + 1), [(t, (int(o * 255),) * 3) for t, o in pts], s.get("angle", 0))
        alpha = g.convert("L").resize((W, H))
        mask = Image.new("L", (W, H), 0)
        cr = s.get("corner", 0)
        r = cr * min(w, h) if cr <= 1 else cr * SS
        ub.rounded(ImageDraw.Draw(mask), (0, 0, W - 1, H - 1), r, fill=255)
        alpha = Image.composite(alpha, Image.new("L", (W, H), 0), mask)
        white = Image.new("RGBA", (W, H), (255, 255, 255, 255))
        white.putalpha(alpha)
        img.alpha_composite(white, (int(x), int(y)))
        return
    if kind == "ring":
        t = s.get("thick", 4) * SS
        draw.ellipse([x + t / 2, y + t / 2, x + w - t / 2, y + h - t / 2], outline=_rgb(s["ringColour"]),
                     width=int(t))
        return
    if kind == "icon" and (s.get("props") or {}).get("ScaleType") == "Crop":
        p = icons.get(s["icon"])
        if p:
            im = Image.open(p).convert("RGBA")
            W_, H_ = int(w), int(h)
            k = max(W_ / im.width, H_ / im.height)
            im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
            l_, t_ = (im.width - W_) // 2, (im.height - H_) // 2
            im = im.crop((l_, t_, l_ + W_, t_ + H_))
            mask = Image.new("L", (W_, H_), 0)
            cr = s.get("corner", 0)
            ub.rounded(ImageDraw.Draw(mask), (0, 0, W_ - 1, H_ - 1), cr * SS if cr > 1 else cr * min(w, h), fill=255)
            if s.get("tint"):  # v4.2: white sprites / backdrops tinted by ImageColor3
                r_, g_, b_ = _rgb(s["tint"])
                lum = im.convert("L")
                col = Image.merge("RGB", [lum.point(lambda v, k=k: int(v * k / 255)) for k in (r_, g_, b_)])
                col.putalpha(im.getchannel("A"))
                im = col
            keep = 1 - float(s.get("alphaImg", 0) or 0)
            a_ = ImageChops.multiply(im.getchannel("A"), mask).point(lambda v: int(v * keep))
            im.putalpha(a_)
            img.alpha_composite(im, (int(x), int(y)))
        return
    if kind == "icon" and (s.get("tint") or s.get("alphaImg")):
        p = icons.get(s["icon"])
        if p:
            side = int(min(w, h))
            im = Image.open(p).convert("RGBA").resize((side, side), Image.LANCZOS)
            if s.get("tint"):
                r_, g_, b_ = _rgb(s["tint"])
                lum = im.convert("L")
                col = Image.merge("RGB", [lum.point(lambda v, k=k: int(v * k / 255)) for k in (r_, g_, b_)])
                col.putalpha(im.getchannel("A"))
                im = col
            a = 1 - float(s.get("alphaImg", 0))
            im.putalpha(im.getchannel("A").point(lambda v: int(v * a)))
            rot = float(s.get("rotation", 0) or 0)
            img.alpha_composite(im, (int(x + (w - side) / 2), int(y + (h - side) / 2)))
        return
    if kind in ("panel", "button") and s.get("depth", theme["shadowOffset"]):
        lip = s.get("depth", theme["shadowOffset"])
        l, t, r, b = _inset({**s, "_lip": lip}, theme)
        cr = s.get("corner", theme["corner"])
        fx, fy, fw, fh = x + l * SS, y + t * SS, w - (l + r) * SS, h - (t + b) * SS
        rad = cr * min(fw, fh) if cr <= 1 else cr * SS
        col = ub.resolve_colour(s.get("colour", "panel"), palette)[1]
        if s.get("paintable"):
            col = ub.face_colours(s, palette)[0]
        ub.rounded(draw, (fx, fy + lip * SS, fw, fh), rad, fill=ub.shade(col))
        node = ub.Node({**s, "depth": 0, "_lip": lip}, node.rect)
    _draw_prev(img, draw, node, theme, palette, icons)
    if s.get("strokeGrad") and kind in ("panel", "button", "frame"):
        st = s.get("strokeW", 4) * SS
        l, t, r, b = _inset(s, theme) if kind != "frame" else (0, 0, 0, 0)
        fx, fy, fw, fh = x + l * SS, y + t * SS, w - (l + r) * SS, h - (t + b) * SS
        cr = s.get("corner", theme["corner"])
        rad = cr * min(fw, fh) if cr <= 1 else cr * SS
        mask = Image.new("L", (int(fw), int(fh)), 0)
        ub.rounded(ImageDraw.Draw(mask), (0, 0, fw - 1, fh - 1), rad, outline=255, width=st)
        n = len(s["strokeGrad"]) - 1
        g = _grad_img((int(fw) // 4 + 1, int(fh) // 4 + 1),
                      [(i / n, _rgb(c)) for i, c in enumerate(s["strokeGrad"])], 45).resize((int(fw), int(fh)))
        g = g.convert("RGBA")
        g.putalpha(mask)
        img.alpha_composite(g, (int(fx), int(fy)))


ub.draw_node = _draw4

_ti_prev = ub.to_instances


def _base_props(spec):
    size, pos = spec.get("size", [1, 0, 1, 0]), spec.get("pos", [0, 0, 0, 0])
    p = {"Size": ub.udim2_tag(size), "Position": ub.udim2_tag(pos), "AnchorPoint": {"Vector2": spec.get("anchor", [0, 0])},
         "ZIndex": spec.get("z", 0)}
    if spec.get("visible") is False:
        p["Visible"] = False
    if float(spec.get("rotation", 0) or 0):
        p["Rotation"] = float(spec["rotation"])
    return p


def _corner(c):
    return ub.instance("Corner", "UICorner", {"CornerRadius": {"UDim": [c if c <= 1 else 0, 0 if c <= 1 else int(c)]}})


def _to_instances4(spec, theme, palette, counter=None):
    kind = spec.get("type")
    if kind == "sheen":
        pts = _sheen_alpha(spec)
        grad = ub.instance("Gradient", "UIGradient", {
            "Rotation": spec.get("angle", 0),
            "Transparency": {"NumberSequence": {"keypoints": [
                {"time": t, "value": round(1 - o, 3), "envelope": 0} for t, o in pts]}}})
        props = {**_base_props(spec), "BackgroundColor3": ub.col3((255, 255, 255)), "BorderSizePixel": 0}
        return [ub.instance(spec.get("name", "Sheen"), "Frame", props, [_corner(spec.get("corner", 0)), grad])]
    if kind == "ring":
        props = {**_base_props(spec), "BackgroundTransparency": 1}
        st = ub.instance("Stroke", "UIStroke", {"Thickness": spec.get("thick", 4), "ApplyStrokeMode": "Border",
                                                "Color": ub.col3(_rgb(spec["ringColour"]))})
        return [ub.instance(spec["name"], "Frame", props, [_corner(1), st])]
    made = _ti_prev(spec, theme, palette, counter)
    if made:
        _post4(spec, made[0], palette)
    return made


def _find_all(node, name):
    out = []
    for c in node.get("children", []):
        if c.get("name") == name:
            out.append(c)
        out += _find_all(c, name)
    return out


def _post4(spec, top, palette):
    kind = spec.get("type", "frame")
    # the lip has no border of its own: it is the darker slab under the face, nothing more
    for sh in [c for c in top.get("children", []) if c.get("name") == "Shadow"]:
        sh["children"] = [c for c in sh.get("children", []) if c.get("className") != "UIStroke"]
        sh.setdefault("properties", {})["BorderSizePixel"] = 0
    if kind == "icon":
        p = top.setdefault("properties", {})
        if spec.get("corner"):
            top.setdefault("children", []).append(_corner(spec["corner"]))
        if spec.get("tint"):
            p["ImageColor3"] = ub.col3(_rgb(spec["tint"]))
        if spec.get("alphaImg"):
            p["ImageTransparency"] = float(spec["alphaImg"])
    if spec.get("strokeGrad"):
        face = top
        if kind in ("panel", "button"):
            nm = spec.get("name") if spec.get("selfFace") else "Face"
            face = next((c for c in top.get("children", []) if c.get("name") == nm), top)
        st = next((c for c in face.get("children", []) if c.get("className") == "UIStroke"), None)
        if st is not None:
            n = len(spec["strokeGrad"]) - 1
            st["properties"]["Thickness"] = spec.get("strokeW", 4)
            st["properties"]["Color"] = ub.col3((255, 255, 255))
            st.setdefault("children", []).append(ub.instance("Rainbow", "UIGradient", {
                "Rotation": 45, "Color": {"ColorSequence": {"keypoints": [
                    {"time": round(i / n, 4), "color": ub.col3(_rgb(c))["Color3"]}
                    for i, c in enumerate(spec["strokeGrad"])]}}}))
    if spec.get("autoW") is not None and kind != "label":
        p = top.setdefault("properties", {})
        p["AutomaticSize"] = "X"
        sz = spec["size"]
        p["Size"] = {"UDim2": [[0, 0], [sz[2], int(sz[3])]]}
        pad = int(spec["autoW"])
        if pad:
            target = next((c for c in top.get("children", []) if c.get("name") == "Content"), top)
            target.setdefault("children", []).insert(0, ub.instance("AutoPad", "UIPadding", {
                "PaddingLeft": {"UDim": [0, pad]}, "PaddingRight": {"UDim": [0, pad]}}))
    if kind == "label":
        # thin text strokes as floats (1.5 / 2)
        for c in top.get("children", []):
            if c.get("className") == "UIStroke":
                c["properties"]["Thickness"] = spec.get("textStroke", 2)
        if spec.get("capW"):
            top.setdefault("children", []).append(ub.instance("CapWidth", "UISizeConstraint", {
                "MaxSize": {"Vector2": [int(spec["capW"]), 1000]}}))
            top.setdefault("attributes", {})["FitText"] = int(spec.get("maxText") or 16)
        px = spec.get("maxText") or 0
        valign = (spec.get("props") or {}).get("TextYAlignment")
        if spec.get("font") == "display" and px and valign in (None, "Center") and not spec.get("noNudge"):
            # Luckiest Guy sits high in its line box: push the text down so caps are optically centred
            top.setdefault("children", []).append(ub.instance("Nudge", "UIPadding", {
                "PaddingTop": {"UDim": [0, int(round(2 * DISPLAY_NUDGE * px))]}}))
    # the white border: colour and thickness of the face's Border stroke
    if kind in ("panel", "button", "frame") and not spec.get("strokeGrad"):
        face = top
        if kind in ("panel", "button"):
            nm = spec.get("name") if spec.get("selfFace") else "Face"
            face = next((c for c in top.get("children", []) if c.get("name") == nm), top)
        for c in face.get("children", []):
            if c.get("className") == "UIStroke" and c["properties"].get("ApplyStrokeMode") == "Border":
                if spec.get("keyline"):
                    c["properties"]["Color"] = ub.col3(_rgb(spec["keyline"]))
                thick = spec.get("strokePx") if kind == "frame" else spec.get("stroke")
                if thick:
                    c["properties"]["Thickness"] = thick


ub.to_instances = _to_instances4
ub.ENUM_PROPS |= {"AutomaticSize"}


# ------------------------------------------------------------------ renderer: clip scrollers and clipping frames
# The stock renderer cannot clip, so a scroller's 5th card was drawn outside its window. A ScrollingFrame, or any
# frame shipped with ClipsDescendants, now paints its subtree on its own layer cropped to its rectangle, which is
# what Roblox does.

def _clips(spec):
    return spec.get("cls") == "ScrollingFrame" or (spec.get("props") or {}).get("ClipsDescendants") is True


def render(root, theme, palette, icons, size):
    SS = ub.SS
    w, h = int(size[0] * SS), int(size[1] * SS)
    bd = theme.get("backdrop", "#7FB2E5")
    if isinstance(bd, list):
        img = ub.v_gradient((w, h), ub.hex_rgb(bd[0]), ub.hex_rgb(bd[1])).convert("RGBA")
    else:
        img = Image.new("RGBA", (w, h), ub.hex_rgb(bd) + (255,))

    def paint(n, target, tdraw):
        if n.spec.get("type") != "root":
            ub.draw_node(target, tdraw, n, theme, palette, icons)
        for c in sorted(n.children, key=lambda k: k.spec.get("z", 0)):
            rot = float(c.spec.get("rotation", 0) or 0)
            clip = _clips(c.spec)
            if not rot and not clip:
                paint(c, target, tdraw)
                continue
            layer = Image.new("RGBA", target.size, (0, 0, 0, 0))
            if clip:
                ub.draw_node(layer, ImageDraw.Draw(layer), c, theme, palette, icons)
                sub = Image.new("RGBA", target.size, (0, 0, 0, 0))
                for k in sorted(c.children, key=lambda k: k.spec.get("z", 0)):
                    paint(k, sub, ImageDraw.Draw(sub))
                mask = Image.new("L", target.size, 0)
                x, y, ww, hh = (v * SS for v in c.rect)
                cr = c.spec.get("corner", 0) if c.spec.get("type") == "frame" and not c.spec.get("transparent") else 0
                r = cr * min(ww, hh) if cr <= 1 else cr * SS
                ub.rounded(ImageDraw.Draw(mask), (x, y, ww, hh), r, fill=255)
                sub.putalpha(Image.composite(sub.getchannel("A"), Image.new("L", target.size, 0), mask))
                layer.alpha_composite(sub)
            else:
                paint(c, layer, ImageDraw.Draw(layer))
            if rot:
                cx = (c.rect[0] + c.rect[2] / 2) * SS
                cy = (c.rect[1] + c.rect[3] / 2) * SS
                layer = layer.rotate(-rot, resample=Image.BICUBIC, center=(cx, cy))
            target.alpha_composite(layer)

    paint(root, img, ImageDraw.Draw(img))
    return img.resize((int(size[0]), int(size[1])), Image.LANCZOS)


ub.render = render
