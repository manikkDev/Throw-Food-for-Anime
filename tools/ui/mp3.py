"""UI v3 system on top of mangapop: one button system, caption boxes, gloss, type scale.

Every rule below is a property of a helper, so a screen cannot get it wrong by hand:

  vbtn()      three size classes at the 1280x720 reference: S 34, M 44, L 56. Width comes
              from the CONSERVATIVE caption width (display 0.72 em, rounded 0.60 em, plus
              stroke) plus 0.35 x height padding each side, clamped by minw/maxw. The caption
              is its own box (vertical inset 14%), TextScaled with MaxTextSize S15/M19/L24 and
              MinTextSize 9, so it can only shrink. Icon + caption are ONE centred row, icon
              0.6 x height, gap 0.18 x height.
  gloss       every button face: same-hue gradient, top ~10% lighter, a hard step at 40%
              (the gloss band), bottom ~18% darker; drawn as a NEUTRAL multiply gradient so a
              client that repaints BackgroundColor3 keeps the gloss. Ink stroke 4 everywhere,
              lip under it (depth), PressLip attribute = the lip, for the press-down.
  colours     confirm = free/affordable, info = neutral action, premium = Robux only,
              danger = destructive (smallest in its row), slate = cannot afford (caption in
              softRed), state = flat grey pill with a tick (EQUIPPED, CLAIMED, OWNED).
  type        12 / 14 / 16 / 20 / 26 / 34 at 720p, strokes <= 3.
  corner_tag  BEST VALUE / LIMITED / NEW / NEXT on a card corner, above everything (z 8).
  autoX       a pill that grows with its text (AutomaticSize X, fixed TextSize), capped.
"""

from __future__ import annotations

import math

import mangapop as mp
from mangapop import (BASE, SENTINEL, WHITE, chip, dyn, frame, ico, lbl, panel, row, col, ub)  # noqa: F401

SIZE_H = {"S": 34, "M": 44, "L": 56}
SIZE_T = {"S": 15, "M": 19, "L": 24}
LIP = {"S": 3, "M": 4, "L": 5}
TYPE = (13, 14, 16, 18, 20, 26, 34)   # v3.2: 13 px floor (12 maps to 13); 18 for card names
EM_D, EM_R = 0.72, 0.60
GLOSS = [(0.0, 0.82), (0.59, 0.90), (0.60, 1.0), (1.0, 1.0)]   # time from the BOTTOM, grey factor


def est_w(text, px, display=True, stroke=2):
    return len(text) * (EM_D if display else EM_R) * px + 2 * stroke


def _hex(c):
    pal = (BASE.get("theme") or {}).get("palette", {})
    c = pal.get(c, c)
    return c if c.startswith("#") else "#" + c


def _mul(h, k):
    r, g, b = ub.hex_rgb(h)
    return "#%02X%02X%02X" % tuple(min(255, int(round(v * k))) for v in (r, g, b))


def _light(h, k):
    r, g, b = ub.hex_rgb(h)
    return "#%02X%02X%02X" % tuple(int(round(v + (255 - v) * k)) for v in (r, g, b))


def gloss(node, colour):
    """Candy face: same hue, lighter top band with a hard step at 40%, darker bottom."""
    base = _light(_hex(colour), 0.10)
    node["colour"] = base
    node["paintable"] = True
    node["gloss"] = True
    node["stops"] = [[1 - t, _mul(base, f)] for t, f in reversed(GLOSS)]
    return node


def vbtn(name, colour, size, icon=None, text=None, samples=None, text_name="Label", font="display",
         w=None, minw=None, maxw=None, self_face=True, text_colour="onDark", icon_name="Icon", px=None, **kw):
    h = SIZE_H[size]
    px = px or SIZE_T[size]
    padx, pady = math.ceil(0.35 * h), math.ceil(0.14 * h)
    face = h - 4 - (4 + LIP[size])        # v3.3: stroke + lip paint inside the box
    ih = face - 2 * max(0, pady - 4)       # caption box inside the face, >= 14% of the box from its edges
    strings = list(samples or []) + ([text] if text else [])
    isz = round(0.6 * h) if icon else 0
    gap = round(0.18 * h) if icon and strings else 0
    tw = math.ceil(max((est_w(s, px, font == "display") for s in strings), default=0))
    content = isz + gap + tw
    W = w or content + 2 * padx
    if minw:
        W = max(W, minw)
    if maxw:
        W = min(W, maxw)
    if strings and W - 2 * padx < content:
        tw = max(16, W - 2 * padx - isz - gap)
    kids = []
    if icon:
        kids.append(ico(icon, isz, name=icon_name))
    if strings:
        mk = dyn if samples else lbl
        cap = (mk(text_name, samples, tw, ih, px=px, font=font, colour=text_colour, stroke=2) if samples
               else mk(text_name, text, tw, ih, px=px, font=font, colour=text_colour, stroke=2))
        cap["maxText"] = px
        kids.append(cap)
    node = {"type": "button", "name": name, "size": [0, round(W), 0, h], "children": kids,
            "layout": row(gap, "center"), "sizeClass": size, "depth": LIP[size], "corner": round(h * 0.42),
            **kw}
    if self_face:
        node["selfFace"] = True
    gloss(node, colour)
    node["attrs"] = {**node.get("attrs", {}), "PressLip": LIP[size]}
    return node


def vbtn2(name, colour, size, top_text, icon, price_samples, price_name="Price", top_name="Count", w=None, **kw):
    """Two-line price button: small quantity over [currency][price], both inside the box."""
    h = SIZE_H[size]
    padx, pady = math.ceil(0.35 * h), math.ceil(0.14 * h)
    face = h - 4 - (4 + LIP[size])        # v3.3: stroke + lip paint inside the box
    ih = face - 2 * max(0, pady - 4)       # caption box inside the face, >= 14% of the box from its edges
    top_h = 14 if size == "M" else 16
    pr_h = ih - top_h - 1
    pr_px = 14 if size == "M" else 19
    isz = pr_h - 2
    tw = math.ceil(max(est_w(s, pr_px) for s in price_samples))
    W = w or max(isz + 4 + tw, est_w(top_text, 12)) + 2 * padx
    t = lbl(top_name, top_text, W - 2 * padx, top_h, px=12 if size == "M" else 14, font="display", stroke=1)
    t["maxText"] = 12 if size == "M" else 14
    p = dyn(price_name, price_samples, tw, pr_h, px=pr_px, font="display", stroke=1)
    p["maxText"] = pr_px
    node = {"type": "button", "name": name, "size": [0, round(W), 0, h], "sizeClass": size, "depth": LIP[size],
            "corner": round(h * 0.42), "layout": col(1, "center"), "children": [
                t, frame("PriceRow", min(W - 2 * padx, isz + 4 + tw), pr_h, [ico(icon, isz), p], layout=row(4, "center"))],
            **kw}
    gloss(node, colour)
    node["attrs"] = {**node.get("attrs", {}), "PressLip": LIP[size]}
    return node


def state_pill(name, text_name, samples, size="M", icon="IconTick", w=None, **kw):
    """A STATE, not a button: flat grey pill with a tick (EQUIPPED, CLAIMED, OWNED)."""
    h = SIZE_H[size]
    px = SIZE_T[size]
    padx, pady = math.ceil(0.35 * h), math.ceil(0.14 * h)
    tw = math.ceil(max(est_w(s, px) for s in samples))
    isz = round(0.5 * h)
    W = w or isz + 6 + tw + 2 * padx
    t = dyn(text_name, samples, min(tw, W - 2 * padx - isz - 6), h - 2 * pady, px=px, font="display", stroke=2)
    t["maxText"] = px
    return {"type": "panel", "name": name, "colour": ["#5C628F", "#5C628F"], "size": [0, round(W), 0, h],
            "corner": round(h * 0.42), "depth": 0, "layout": row(6, "center"),
            "children": [ico(icon, isz), t], **kw}


def tag(name, text, colour="danger", text_name=None, corner="tr", w=None, h=22, **kw):
    """A corner tag on a card: overlaps only the card border, above everything in the card."""
    tw = math.ceil(est_w(text, 12))
    W = w or tw + 16
    t = lbl(text_name or f"{name}Text", text, W - 10, h - 6, px=12, font="display", stroke=2,
            pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5])
    t["maxText"] = 12
    pos = {"tr": [1, 4, 0, -7], "tl": [0, -4, 0, -7]}[corner]
    anchor = {"tr": [1, 0], "tl": [0, 0]}[corner]
    return {"type": "panel", "name": name, "colour": colour, "size": [0, W, 0, h], "corner": h // 2, "depth": 2,
            "keyline": WHITE, "selfFace": True, "paintable": True, "pos": pos, "anchor": anchor, "z": 8,
            "overhang": True, "children": [t], **kw}


def T(name, text, w, size, colour="onDark", font=None, samples=None, align="center", wrap=False, **kw):
    """A label on the type scale; the box is the text size x 1.3 (x lines when wrapped)."""
    size = max(size, 13)
    assert size in TYPE, size
    lines = 2 if wrap else 1
    dark = colour in ("ink", "powerInk", "luckInk", "premiumInk", "inkSoft")
    h = math.ceil(size * 1.3 * lines)
    mk = dyn if samples else lbl
    n = (mk(name, samples, w, h, px=size, colour=colour, font=font, align=align, wrap=wrap,
            stroke=0 if dark else 1 if size <= 12 else 2 if size <= 16 else 3, **kw) if samples
         else mk(name, text, w, h, px=size, colour=colour, font=font, align=align, wrap=wrap,
                 stroke=0 if dark else 1 if size <= 12 else 2 if size <= 16 else 3, **kw))
    n["maxText"] = size
    return n


def vscroll(name, w, h, children, layout, pad=6, **kw):
    """Vertical-only scroll: 6 px bar in its own gutter, padding so the last row is never cut."""
    return {"type": "frame", "name": name, "transparent": True, "cls": "ScrollingFrame", "scroll": "Y",
            "size": [0, w, 0, h], "padding": pad, "layout": layout, "children": list(children),
            "props": {"ScrollBarThickness": 6, "VerticalScrollBarInset": "ScrollBar"}, **kw}


# ------------------------------------------------------------------ emitter additions

_prev_post = mp._post


def _post3(spec, top, palette):
    _prev_post(spec, top, palette)
    kind = spec.get("type", "frame")
    if kind == "label":
        cap = next((c for c in top.get("children", []) if c.get("className") == "UITextSizeConstraint"), None)
        if cap is not None:
            if spec.get("maxText"):
                cap["properties"]["MaxTextSize"] = int(spec["maxText"])
            cap["properties"]["MinTextSize"] = 9
        if spec.get("autoX"):
            p = top["properties"]
            p["TextScaled"] = False
            p["TextSize"] = int(spec.get("maxText") or 16)
            p["AutomaticSize"] = "X"
            top["children"] = [c for c in top.get("children", []) if c.get("className") != "UITextSizeConstraint"]
            sz = spec["size"]
            p["Size"] = {"UDim2": [[0, 0], [sz[2], int(sz[3])]]}
    if spec.get("gloss"):
        face = top if spec.get("selfFace") is not True else None
        if spec.get("selfFace"):
            face = next((c for c in top.get("children", []) if c.get("name") == spec.get("name")), None)
        else:
            face = next((c for c in top.get("children", []) if c.get("name") == "Face"), None)
        if face is not None:
            for c in face.get("children", []):
                if c.get("name") == "Gradient":
                    c["properties"]["Color"] = {"ColorSequence": {"keypoints": [
                        {"time": t, "color": [f, f, f]} for t, f in GLOSS]}}
    if spec.get("autoX") and kind != "label":
        p = top.setdefault("properties", {})
        p["AutomaticSize"] = "X"
        sz = spec["size"]
        p["Size"] = {"UDim2": [[0, 0], [sz[2], int(sz[3])]]}
        top.setdefault("children", []).append(ub.instance("MaxWidth", "UISizeConstraint", {
            "MaxSize": {"Vector2": [int(spec["autoX"]), 1000]}}))
        top["children"].append(ub.instance("AutoPad", "UIPadding", {
            "PaddingRight": {"UDim": [0, 16]}}))


mp._post = _post3
ub.ENUM_PROPS |= {"VerticalScrollBarInset", "HorizontalScrollBarInset", "AutomaticSize"}



# ------------------------------------------------------------------ v3.2: spacing + legibility system
GAP = 8          # between sibling controls in a row
ROW_GAP = 10     # between stacked rows inside a card
CARD_GAP = 14    # between cards, and card grid to window edge
PAD = 12         # inner padding of every card and panel
MIN_TEXT = 13    # no on-screen text under 13 px at 720p


def clamp_text(node):
    """The legibility floor as a pass over a whole spec: a label whose max text size is under 13 px
    gets 13, and its box grows if 13 px would not fit it. Text never shrinks to make room."""
    import math as _m
    if node.get("type") == "label" and node["size"][2] == 0 and not node.get("autoX"):
        h = node["size"][3]
        ts = node.get("textScale", 0.62)
        cap = node.get("maxText") or int(h * ts)
        if cap < MIN_TEXT:
            if node.get("maxText"):
                node["maxText"] = MIN_TEXT
            if MIN_TEXT / h > 0.85:
                node["size"][3] = h = _m.ceil(MIN_TEXT / 0.8)
            node["textScale"] = round(max(ts, (MIN_TEXT + 0.05) / h), 4)
            node["textStroke"] = min(node.get("textStroke", 1), 2)
    if node.get("type") == "panel" and node["size"][2] == 0 and 0 < node["size"][3] <= 30:
        # chips / pills / tags: a 2 px stroke and no lip, so a 13 px label keeps an 18 px face
        node.setdefault("stroke", 2)
        node["depth"] = 0
    for c in node.get("children") or []:
        clamp_text(c)
    return node


# ------------------------------------------------------------------ v3.3: the painted rectangle IS the layout box
# A Border UIStroke paints OUTSIDE its element and the lip / comic shadow hang below it, so an 8 px layout
# gap was 0 px of clear space and neighbouring buttons touched in game (owner, s3-v3-03). Every depth-stack
# element (panel, button) now insets its face by the stroke on each side, plus the lip (or comic offset)
# at the bottom and the comic offset at the right: what you see ends exactly at the box. Applied to the
# resolver (children sit in the face), the renderer and the emitter alike, so PNG and model still agree.

def inset(spec, theme):
    st = spec.get("stroke", theme["stroke"])
    lip = spec.get("depth", theme["shadowOffset"]) or 0
    comic = spec.get("comic") or 0
    # true painted extents: stroke all round, plus the lip / comic shadow below and the comic offset right
    return st, st, st + comic, st + max(lip, comic)


_resolve0 = ub.resolve


def _resolve_inset(spec, parent_rect, theme):
    if spec.get("type") not in ("panel", "button"):
        return _resolve0(spec, parent_rect, theme)
    node = _resolve0({**spec, "children": []}, parent_rect, theme)
    node.spec = spec
    l, t, r, b = inset(spec, theme)
    x, y, w, h = node.rect
    fake = {"type": "frame", "size": [0, w - l - r, 0, h - t - b], "padding": spec.get("padding", 0),
            "layout": spec.get("layout"), "children": spec.get("children") or []}
    node.children = _resolve0(fake, (x + l, y + t, w - l - r, h - t - b), theme).children
    return node


_draw_prev = ub.draw_node


def _draw_inset(img, draw, node, theme, palette, icons):
    s = node.spec
    if s.get("type") in ("panel", "button"):
        l, t, r, b = inset(s, theme)
        x, y, w, h = node.rect
        node = ub.Node(s, (x + l, y + t, w - l - r, h - t - b))
    return _draw_prev(img, draw, node, theme, palette, icons)


ub.resolve = _resolve_inset
ub.draw_node = _draw_inset

_post_v32 = mp._post


def _post33(spec, top, palette):
    _post_v32(spec, top, palette)
    if spec.get("type") not in ("panel", "button"):
        return
    theme = BASE["theme"]
    l, t, r, b = inset(spec, theme)
    comic = spec.get("comic") or 0
    lip = spec.get("depth", theme["shadowOffset"]) or 0
    face_name = spec.get("name") if spec.get("selfFace") else "Face"
    size = {"UDim2": [[1, -(l + r)], [1, -(t + b)]]}
    for c in top.get("children", []):
        if c.get("name") == face_name and c.get("className") in ("Frame", "TextButton", "ImageButton"):
            c["properties"]["Size"] = size
            c["properties"]["Position"] = {"UDim2": [[0, l], [0, t]]}
        elif c.get("name") == "Shadow":
            c["properties"]["Size"] = size
            c["properties"]["Position"] = {"UDim2": [[0, l + comic], [0, t + (comic or lip)]]}


mp._post = _post33
