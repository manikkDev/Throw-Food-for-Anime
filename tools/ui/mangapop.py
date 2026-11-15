"""Manga Pop: the roblox-ui skill's builder, extended for this game, plus the kit.

Every extension below is applied to BOTH halves of ui_build - the PNG renderer and
the instance emitter - in the same function, so the mockup and the .model.json are
still drawn from one resolved tree. Nothing here edits the skill on disk; the
patches live in this process only.

Extensions (spec keys):
  keyline: "#hex"      outer stroke colour of a panel/button/frame (default: theme ink)
  comic: px            the comic offset shadow: ink, offset down AND right by px
  font: "display"      Luckiest Guy (headers, big numbers) instead of Fredoka One
  cls: "ScrollingFrame" | "ViewportFrame" | "TextBox"   emitted class of a frame/label
  scroll: "X" | "Y"    ScrollingFrame direction
  paint: "#hex"        a FRAME whose colour the controller writes at runtime: neutral
                       gradient, BackgroundColor3 = the colour (panels use the skill's
                       own selfFace + paintable for the same thing)
  props / attrs        extra properties / attributes on the emitted top instance
  mockHide: true       not drawn in the mockup and not laid out by the checker; ships
                       Visible=false (a lock icon on an unlocked tab). Roblox's list
                       layouts skip invisible children too, so this is the faithful
                       preview, not a cheat.
  "<unbound>" text     the mockup draws samples[0]; the model ships the sentinel.
"""

from __future__ import annotations

import copy
import glob
import os
import shutil
import sys
from pathlib import Path

SKILL = Path.home() / ".claude" / "skills" / "roblox-ui" / "scripts"
sys.path.insert(0, str(SKILL))
import ui_build as ub  # noqa: E402
from PIL import ImageDraw  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SENTINEL = "<unbound>"
INK = "#0D0F2B"
WHITE = "#FFFFFF"

# ------------------------------------------------------------------ display font
# Luckiest Guy ships with Roblox Studio (Apache 2.0); the preview uses that file so
# the PNG measures the real glyphs. Copied into work/ so the path is stable.
_FONT_DST = ROOT / "work" / "ui" / "fonts" / "LuckiestGuy-Regular.ttf"
if not _FONT_DST.exists():
    found = sorted(glob.glob(os.path.expandvars(
        r"%LOCALAPPDATA%\Roblox\Versions\*\content\fonts\LuckiestGuy-Regular.ttf")))
    if not found:
        raise SystemExit("LuckiestGuy-Regular.ttf not found in the Roblox Studio install")
    _FONT_DST.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(found[-1], _FONT_DST)
ub.FONTS["LuckiestGuy"] = (str(_FONT_DST), "LuckiestGuy", "Regular")

STATE = {"font": None}
DISPLAY_TEXTS: set[str] = set()
BASE: dict = {"theme": None, "palette": None}

_orig_load_font = ub.load_font
_orig_fit = ub.fit_text_size
_orig_text = ub._text
_orig_draw = ub.draw_node
_orig_ti = ub.to_instances
_orig_lua_value = ub.lua_value


def load_font(size):
    f = STATE["font"]
    if not f:
        return _orig_load_font(size)
    saved = ub.STYLE["font"]
    ub.STYLE["font"] = f
    try:
        return _orig_load_font(size)
    finally:
        ub.STYLE["font"] = saved


def fit_text_size(draw, txt, font_size, box, stroke, floor=6, wrap=False):
    # verify_ui calls this with the text only, so display labels are known by text
    if STATE["font"] is None and txt in DISPLAY_TEXTS:
        STATE["font"] = "LuckiestGuy"
        try:
            return _orig_fit(draw, txt, font_size, box, stroke, floor, wrap)
        finally:
            STATE["font"] = None
    return _orig_fit(draw, txt, font_size, box, stroke, floor, wrap)


def _text(img, draw, s, box, theme, palette):
    if s.get("text") == SENTINEL and s.get("samples"):
        s = {**s, "text": s["samples"][0]}
    prev = STATE["font"]
    if s.get("font") == "display":
        STATE["font"] = "LuckiestGuy"
    try:
        _orig_text(img, draw, s, box, theme, palette)
    finally:
        STATE["font"] = prev


def _stops_gradient(stops):
    """v_gradient replacement for a node with "stops": [[t_from_top, hex], ...]."""
    from PIL import Image as _I
    pts = [(t, ub.hex_rgb(h)) for t, h in stops]

    def grad(size, top=None, bottom=None):
        w, h = max(1, int(size[0])), max(1, int(size[1]))
        g = _I.new("RGB", (1, h))
        px = g.load()
        for y in range(h):
            t = y / max(1, h - 1)
            for (t0, c0), (t1, c1) in zip(pts, pts[1:]):
                if t0 <= t <= t1:
                    u = (t - t0) / max(1e-6, t1 - t0)
                    px[0, y] = tuple(int(round(c0[i] + (c1[i] - c0[i]) * u)) for i in range(3))
                    break
        return g.resize((w, h))
    return grad


def draw_node(img, draw, node, theme, palette, icons):
    if node.spec.get("stops"):
        saved = ub.v_gradient
        ub.v_gradient = _stops_gradient(node.spec["stops"])
        try:
            return _draw_node_inner(img, draw, node, theme, palette, icons)
        finally:
            ub.v_gradient = saved
    return _draw_node_inner(img, draw, node, theme, palette, icons)


def _draw_node_inner(img, draw, node, theme, palette, icons):
    s = node.spec
    kind = s.get("type", "frame")
    kl = s.get("keyline")
    co = s.get("comic")
    if kind in ("panel", "button") and co:
        x, y, w, h = (v * ub.SS for v in node.rect)
        corner = s.get("corner", theme["corner"])
        r = corner * min(w, h) if corner <= 1 else corner * ub.SS
        off = co * ub.SS
        ub.rounded(draw, (x + off, y + off, w, h), r, fill=ub.hex_rgb(INK),
                   outline=ub.hex_rgb(INK), width=theme["stroke"] * ub.SS)
        node = ub.Node({**s, "depth": 0}, node.rect)
    if kl and kind in ("panel", "button", "frame"):
        theme = {**theme, "outline": kl}
    if s.get("stroke") and kind in ("panel", "button"):
        theme = {**theme, "stroke": s["stroke"]}
    _orig_draw(img, draw, node, theme, palette, icons)


def _find(node, name):
    for c in node.get("children") or []:
        if c.get("name") == name:
            return c
    return None


def to_instances(spec, theme, palette, counter=None):
    T = BASE["theme"]
    kl = spec.get("keyline")
    th = {**T, "outline": kl} if kl else T
    if spec.get("stroke") and spec.get("type") in ("panel", "button"):
        th = {**th, "stroke": spec["stroke"]}
    made = _orig_ti(spec, th, palette, counter)
    if made:
        _post(spec, made[0], palette)
    return made


def _post(spec, top, palette):
    kind = spec.get("type", "frame")
    props = top.setdefault("properties", {})
    co = spec.get("comic")
    if co and kind in ("panel", "button"):
        sh = _find(top, "Shadow")
        if sh:
            sh["properties"]["Position"] = {"UDim2": [[0, int(co)], [0, int(co)]]}
            sh["properties"]["BackgroundColor3"] = ub.col3(ub.hex_rgb(INK))
            st = _find(sh, "Stroke")
            if st:
                st["properties"]["Color"] = ub.col3(ub.hex_rgb(INK))
    if kind == "label" and spec.get("font") == "display":
        props["FontFace"] = {"Font": {"family": "rbxasset://fonts/families/LuckiestGuy.json",
                                      "weight": "Regular", "style": "Normal"}}
    if kind == "frame" and spec.get("paint"):
        base = ub.hex_rgb(spec["paint"])
        props["BackgroundColor3"] = ub.col3(base)
        g = int(round(255 * ub.PAINT_SHADE))
        top["children"] = [ub._gradient(((255, 255, 255), (g, g, g))) if c.get("name") == "Gradient"
                           else c for c in top.get("children", [])]
    if spec.get("stops"):
        for c in top.get("children", []):
            if c.get("name") == "Gradient":
                c["properties"]["Color"] = {"ColorSequence": {"keypoints": [
                    {"time": round(1 - t, 4), "color": ub.col3(ub.hex_rgb(h))["Color3"]}
                    for t, h in reversed(spec["stops"])]}}
    cls = spec.get("cls")
    if cls == "TextButton":
        # a transparent hit area (the throw tap target, the gear's 56 px touch box)
        top["className"] = "TextButton"
        props.update({"Text": "", "AutoButtonColor": False, "BackgroundTransparency": 1})
    if cls == "ViewportFrame":
        top["className"] = "ViewportFrame"
        col = ub.resolve_colour(spec.get("colour"), palette)
        if col:
            props["BackgroundColor3"] = ub.col3(col[1])
        top["children"] = [c for c in top.get("children", []) if c.get("name") != "Gradient"]
        props.setdefault("Ambient", ub.col3((210, 210, 225)))
        props.setdefault("LightDirection", {"Vector3": [-1, -1, -1]})
    elif cls == "ScrollingFrame":
        top["className"] = "ScrollingFrame"
        d = spec.get("scroll", "Y")
        props.update({"ScrollingDirection": d, "AutomaticCanvasSize": d,
                      "CanvasSize": {"UDim2": [[0, 0], [0, 0]]}, "ScrollBarThickness": 8,
                      "ScrollBarImageColor3": ub.col3((255, 255, 255)), "BorderSizePixel": 0,
                      "ClipsDescendants": True, "Active": True})
    elif cls == "TextBox":
        top["className"] = "TextBox"
        props["PlaceholderText"] = props.get("Text", "")
        props["PlaceholderColor3"] = props.get("TextColor3")
        props["Text"] = ""
        props["ClearTextOnFocus"] = False
    if kind == "icon":
        top.setdefault("attributes", {})["IconKey"] = spec["icon"]
    if spec.get("mockHide"):
        props["Visible"] = False
    if spec.get("props"):
        props.update(spec["props"])
    if spec.get("attrs"):
        top.setdefault("attributes", {}).update(spec["attrs"])


def _layout_instance(lay):
    """Direction-aware alignment, matching ub.resolve exactly: the main axis follows
    `align`, the cross axis is centred. Stock code mapped `align` to the HORIZONTAL
    alignment whatever the direction and always centred vertically, so a vertical
    list with align start rendered top-aligned in the PNG and centred in Roblox."""
    if lay.get("type") == "grid":
        return _orig_layout(lay)
    a = lay.get("align", "start")
    horiz = lay.get("dir") == "x"
    return ub.instance("Layout", "UIListLayout", {
        "FillDirection": "Horizontal" if horiz else "Vertical",
        "Padding": {"UDim": [0, int(lay.get("gap", 8))]},
        "SortOrder": "LayoutOrder",
        "HorizontalAlignment": {"start": "Left", "center": "Center", "end": "Right"}[a] if horiz else "Center",
        "VerticalAlignment": "Center" if horiz else {"start": "Top", "center": "Center", "end": "Bottom"}[a]})


_orig_layout = ub._layout_instance


def lua_value(v, prop=None, is_attribute=False):
    if isinstance(v, dict) and "Font" in v:
        f = v["Font"]
        return (f'Font.new("{f["family"]}", Enum.FontWeight.{f["weight"]}, '
                f'Enum.FontStyle.{f["style"]})')
    if isinstance(v, dict) and "Vector3" in v:
        x, y, z = v["Vector3"]
        return f"Vector3.new({x}, {y}, {z})"
    return _orig_lua_value(v, prop, is_attribute)


ub.load_font = load_font
ub.fit_text_size = fit_text_size
ub._text = _text
ub.draw_node = draw_node
ub.to_instances = to_instances
ub._layout_instance = _layout_instance
ub.lua_value = lua_value
ub.ENUM_PROPS |= {"ScrollingDirection", "AutomaticCanvasSize", "ScreenInsets", "SizingMode", "Face"}


def prune(spec):
    """The spec as the mockup and the checker see it: mockHide nodes removed."""
    s = copy.deepcopy(spec)

    def walk(n):
        n["children"] = [walk(c) for c in n.get("children") or [] if not c.get("mockHide")]
        return n
    s["children"] = [walk(c) for c in s["children"] if not c.get("mockHide")]
    return s


# ====================================================================== the kit

LIGHT_TEXT = {"onDark", "soft", "yen", "power", "luck", "gold", "confirm", "danger", "premium",
              "info", "buy", "coral"}


def lbl(name, text, w, h, px=None, colour="onDark", align="center", stroke=None,
        font=None, samples=None, wrap=False, **kw):
    px = px or round(h * 0.8)
    node = {"type": "label", "text": text, "size": [0, w, 0, h], "textColour": colour,
            "align": align, "textScale": round(px / h, 4),
            "textStroke": stroke if stroke is not None else (3 if colour in LIGHT_TEXT else 0)}
    if name:
        node["name"] = name
    if samples:
        node["samples"] = list(samples)
    if wrap:
        node["wrap"] = True
    if font == "display":
        node["font"] = "display"
        DISPLAY_TEXTS.add(text)
        DISPLAY_TEXTS.update(samples or [])
    node.update(kw)
    return node


def dyn(name, samples, w, h, **kw):
    """A label the controller writes: ships "<unbound>", measured against samples."""
    return lbl(name, SENTINEL, w, h, samples=samples, **kw)


def ico(key, side, name="Icon", **kw):
    return {"type": "icon", "icon": key, "name": name, "size": [0, side, 0, side], **kw}


def frame(name, w, h, children=(), layout=None, **kw):
    node = {"type": "frame", "name": name, "transparent": True,
            "size": [0, w, 0, h] if w is not None else [1, 0, 1, 0], "children": list(children)}
    if layout:
        node["layout"] = layout
    node.update(kw)
    return node


def row(gap=10, align="center"):
    return {"type": "list", "dir": "x", "gap": gap, "align": align}


def col(gap=10, align="center"):
    return {"type": "list", "dir": "y", "gap": gap, "align": align}


def shade_hex(hexcol, k=0.86):
    r, g, b = ub.hex_rgb(hexcol)
    return "#%02X%02X%02X" % (int(round(r * k)), int(round(g * k)), int(round(b * k)))


def fill_frame(name, hexcol, w=None, h=None, **kw):
    """A coloured frame the controller recolours (a bar fill, a zone mark)."""
    node = {"type": "frame", "name": name, "colour": [hexcol, shade_hex(hexcol)],
            "paint": hexcol, "children": [], **kw}
    if w is not None:
        node["size"] = [0, w, 0, h]
    return node


def viewport(name, w, h, colour="#12153A", **kw):
    return {"type": "frame", "name": name, "cls": "ViewportFrame", "colour": [colour, colour],
            "size": [0, w, 0, h], "children": [], **kw}


def panel(name, w, h, colour="panel", children=(), **kw):
    return {"type": "panel", "name": name, "colour": colour, "size": [0, w, 0, h],
            "children": list(children), **kw}


def card(name, w, h, colour="panel", children=(), **kw):
    """A HUD or window panel: white keyline and the comic shadow."""
    kw.setdefault("keyline", WHITE)
    kw.setdefault("comic", 6)
    return panel(name, w, h, colour, children, **kw)


def chip(name, text_name, samples, w, h, colour, px=None, static=None, font="display", **kw):
    """A coloured pill with one label (tags, stamps). Paintable: the controller
    writes <name>.BackgroundColor3."""
    px = px or round((h - 4) * 0.82)
    inner = (lbl(text_name, static, w - 8, h - 4, px=px, font=font)
             if static is not None else dyn(text_name, samples, w - 8, h - 4, px=px, font=font))
    inner.update({"pos": [0.5, 0, 0.5, 0], "anchor": [0.5, 0.5]})
    return {"type": "panel", "name": name, "colour": colour, "size": [0, w, 0, h],
            "selfFace": True, "paintable": True, "depth": 3, "children": [inner], **kw}


def btn(name, colour, w, h, children=(), paint=False, **kw):
    node = {"type": "button", "name": name, "colour": colour, "size": [0, w, 0, h],
            "children": list(children), **kw}
    if paint:
        node["selfFace"] = True
        node["paintable"] = True
    return node


def ibtn(name, colour, w, h, icon_key, text=None, samples=None, text_name="Label", px=None,
         icon_side=None, font="display", gap=8, paint=False, text_colour="onDark", lines=1, **kw):
    """The standard button: glyph + caption in a centred row. `samples` makes the
    caption dynamic (<unbound>)."""
    isz = icon_side or min(h - 22, 40)
    px = px or min(28, round((h - 20) * 0.62))
    tw = w - isz - gap - 20
    th = min(h - 6, round(px * 1.3 * lines))
    wrap = lines > 1
    cap = (dyn(text_name, samples, tw, th, px=px, font=font, colour=text_colour, wrap=wrap) if samples
           else lbl(text_name, text, tw, th, px=px, font=font, colour=text_colour, wrap=wrap)) if (samples or text) else None
    kids = [ico(icon_key, isz)] + ([cap] if cap else [])
    return btn(name, colour, w, h, kids, paint=paint, layout=row(gap), **kw)


def ribbon(name, title, w, h=68, samples=None, colour=None, px=None, **kw):
    """The tilted coral-to-yellow header with a halftone overlay."""
    px = px or round(h * 0.56)
    t = (dyn("Title", samples, w - 40, h - 14, px=px, font="display") if samples
         else lbl("Title", title, w - 40, h - 14, px=px, font="display"))
    t.update({"pos": [0.5, 0, 0.5, 0], "anchor": [0.5, 0.5]})
    node = {"type": "panel", "name": name, "colour": colour or ["#FFC93C", "#FF5A5F"],
            "size": [0, w, 0, h], "rotation": -2, "keyline": WHITE, "comic": 6,
            "pattern": {"name": "dots", "colour": "#FFFFFF", "opacity": 0.28, "tile": 34},
            "children": [t], **kw}
    return node


def close_button():
    return btn("CloseButton", "danger", 56, 56, [ico("IconClose", 30, pos=[0.5, 0, 0.5, 0],
                                                     anchor=[0.5, 0.5])],
               pos=[1, 14, 0, -18], anchor=[1, 0], z=4, overhang=True, closes=True, sizeClass="L")


def window(title, w, h, body_children, ribbon_w=420, extra=(), name="Window"):
    """A modal page: scrim + one Window panel holding Header, CloseButton and Body."""
    body = frame("Body", w - 48, h - 84 - 22, body_children, pos=[0.5, 0, 0, 84], anchor=[0.5, 0])
    win = card(name, w, h, "panel", [
        ribbon("Header", title, ribbon_w, 70, pos=[0.5, 0, 0, -36], anchor=[0.5, 0], z=3,
               overhang=True),
        {"type": "frame", "name": "BodyArt", "colour": ["#2E3488", "#161944"], "outline": False,
         "size": [1, -16, 1, -16], "pos": [0.5, 0, 0.5, 0], "anchor": [0.5, 0.5], "corner": 16,
         "pattern": {"name": "dots", "colour": "#FFFFFF", "opacity": 0.07, "tile": 28},
         # z -1, not child order: Rojo does not keep the order of siblings, and at the
         # same ZIndex Roblox draws the later one on top. MEASURED 2026-11-14: BodyArt
         # arrived AFTER Body and covered every page's content with a blank panel.
         "overhang": True, "z": -1, "children": []},
        close_button(),
        *extra,
        body,
    ], comic=10, modal=True, corner=22, pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5])
    # explicit z: Rojo does not keep sibling order, so the scrim must not rely on it
    scrim = {"type": "frame", "name": "Scrim", "colour": [INK, INK], "alpha": 0.55, "outline": False, "z": -2,
             "size": [1, 0, 1, 0], "children": []}
    return [scrim, win]


def track(name, w, h, value, fill_hex, text=None, text_name=None, samples=None, px=None, **kw):
    """A progress bar: dark track, painted Fill, optional value text on top."""
    kids = [fill_frame("Fill", fill_hex, size=[value, -6, 1, -6], pos=[0, 3, 0.5, 0],
                       anchor=[0, 0.5], outline=False, corner=max(4, (h - 6) // 2), overhang=True)]
    if samples or text:
        px = px or round(h * 0.62)
        t = (dyn(text_name, samples, w - 16, h, px=px) if samples else lbl(text_name, text, w - 16, h, px=px))
        t.update({"pos": [0.5, 0, 0.5, 0], "anchor": [0.5, 0.5], "overhang": True, "z": 2})
        kids.append(t)
    return {"type": "frame", "name": name, "colour": ["#0B0D29", "#12153A"], "size": [0, w, 0, h],
            "corner": h // 2, "children": kids, **kw}


def sample(node, i):
    """A list item that ships hidden and marked, so the mockup shows a filled list
    while the live list is filled from the matching Template."""
    node = dict(node)
    node["name"] = f"{node['name'].replace('Template', '')}Sample{i}"
    node["visible"] = False
    node["attrs"] = {**node.get("attrs", {}), "Sample": True}
    return node
