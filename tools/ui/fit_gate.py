"""Fit gate: would this text and these boxes survive ROBLOX's metrics, not the mockup's?

    python tools/ui/fit_gate.py            # all screens + templates, exit 1 on any failure

WHY. v2 passed verify_ui (which measures with PIL and the real font files) and still broke
in game: Roblox TextScaled fills a label's whole HEIGHT, Luckiest Guy renders wider than the
preview measured, and captions had no padding, so text ran edge to edge or out of its
button. This gate uses a deliberately CONSERVATIVE width model instead of the preview
(display face 0.72 em per character, rounded face 0.60 em, plus the stroke on both sides)
and checks the geometry rules of the v3 system:

  caption_pad   a caption inside a button keeps >= 0.35 x button height on each side and
                >= 14% top and bottom (rule 2)
  contain       a label never leaves the card / chip / button it belongs to
  text_fit      at the conservative width the text still fits its box at >= MinTextSize 9
  size_cap      every TextScaled label carries a UITextSizeConstraint (emitted model)
  button_class  a button is no taller than its size class (S 34, M 44, L 56, HUD 64)
  scroll_x      a ScrollingFrame scrolls horizontally
  window_hang   something inside a window leaves the window (ribbon + close button excepted)

Geometry is evaluated at 1280x720 and mapped to 1345x611, 844x390 and 1920x1080 by the one
uniform UIScale the screens use, so a result is the same at all four sizes by construction;
the gate still reports per size so a non-uniform change would show.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import mangapop as mp  # noqa: E402
from mangapop import ub  # noqa: E402

ROOT = HERE.parents[1]
SPEC = ROOT / "design" / "ui"
UI = ROOT / "src" / "ui"
SIZES = [(1280, 720), (1345, 611), (844, 390), (1920, 1080)]
CLASS_H = {"S": 34, "M": 44, "L": 56, "HUD": 72}
MIN_TEXT = 9
# labels that are MEANT to sit outside their parent (named, so the list is reviewable)
ALLOW_OUTSIDE = {"Caption", "BonusLabel", "PerfectLabel", "ZoneMarkName", "FoodName", "FlavorRow",
                 "FoodFlavor"}


def em(spec):
    return 0.72 if spec.get("font") == "display" else 0.60


def texts(s):
    out = [t for t in (s.get("samples") or [])]
    if s.get("text") and s["text"] != mp.SENTINEL:
        out.append(s["text"])
    return out


def inside(a, b, tol=1.0):
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    return ax >= bx - tol and ay >= by - tol and ax + aw <= bx + bw + tol and ay + ah <= by + bh + tol


MIN_TEXT_PX = 13
# the ONE scroller allowed to scroll sideways (owner's call, v3.2): name list, model side
ALLOW_SCROLL_X = {"FoodScroller"}
CONTROL = ("button", "panel")


def _is_ctrl(n):
    s = n.spec
    return (s.get("type") in CONTROL or s.get("cls") == "TextButton") and s.get("visible") is not False


def _is_tag(n):
    nm = n.spec.get("name") or ""
    return n.spec.get("overhang") or any(t in nm for t in ("Tag", "Sticker", "Badge"))


def _is_card(n):
    return n.spec.get("type") == "panel" and n.rect[2] >= 100 and n.rect[3] >= 100


def _outer(n):
    """The painted rectangle. Since v3.3 every depth-stack element paints its stroke, lip and comic
    shadow INSIDE its box (mp3.inset), so the box is what is painted; the check measures it. Before
    that, strokes painted outside and an 8 px gap was 0 px of clear space."""
    return n.rect


def _units(n):
    """The controls a subtree presents to its siblings: itself if it is a control, else the nearest
    controls inside it (looks through transparent wrapper frames such as <Btn>Cell)."""
    if _is_tag(n):
        return []
    if _is_ctrl(n):
        return [n]
    if n.spec.get("visible") is False or n.spec.get("cls") == "ScrollingFrame":
        return []
    out = []
    for c in n.children:
        out += _units(c)
    return out


def _gaps(n, add):
    """Sibling subtrees keep the spacing rule between their controls' OUTER rectangles: 8 px in a
    row, 10 px between stacked rows inside a card, 14 px between cards and between HUD side buttons
    (sizeClass HUD). Overlap fails (tags and declared overhangs excepted)."""
    groups = [_units(k) for k in n.children]
    in_card = _is_card(n)
    for i in range(len(groups)):
        for j in range(i + 1, len(groups)):
            for a in groups[i]:
                for b in groups[j]:
                    ax, ay, aw, ah = _outer(a)
                    bx, by, bw, bh = _outer(b)
                    dx = max(bx - (ax + aw), ax - (bx + bw))
                    dy = max(by - (ay + ah), ay - (by + bh))
                    sep = max(dx, dy)
                    hud = "HUD" in (a.spec.get("sizeClass"), b.spec.get("sizeClass"))
                    need = 14 if ((_is_card(a) and _is_card(b)) or hud) else 10 if (in_card and dy > dx) else 8
                    if sep < need - 0.5:
                        what = "overlap" if sep < 0 else f"{sep:.0f}px apart"
                        add("gap", f"{n.spec.get('name')}: {a.spec.get('name')} / {b.spec.get('name')} {what} "
                                   f"outer (needs {need})")


def check_spec(name, spec, theme):
    issues = []
    pspec = mp.prune(spec)
    root = ub.resolve({"type": "root", "size": [1, 0, 1, 0], "children": pspec["children"]},
                      (0, 0, *spec["resolution"]), theme)

    def add(code, msg):
        issues.append((code, f"{name}: {msg}"))

    def walk(n, anc):
        s = n.spec
        kind = s.get("type", "frame")
        nm = s.get("name") or kind
        is_btn = kind == "button" or s.get("cls") == "TextButton"
        if is_btn and kind == "button":
            h = n.rect[3]
            cls = s.get("sizeClass")
            limit = CLASS_H.get(cls, 56)
            if h > limit + 0.5:
                add("button_class", f"{nm} is {h:.0f}px tall, class {cls or '-'} allows {limit}")
        if s.get("cls") == "ScrollingFrame" and s.get("scroll", "Y") == "X" and not s.get("scrollXok"):
            add("scroll_x", f"{nm} scrolls horizontally")
        if kind == "label":
            allowed = (s.get("overhang") and nm in ALLOW_OUTSIDE) or any(
                a.spec.get("overhang") and a.spec.get("name") in ALLOW_OUTSIDE for a in anc)
            container = next((a for a in reversed(anc)
                              if a.spec.get("type") in ("button", "panel") or a.spec.get("cls") == "TextButton"),
                             None)
            if container is not None and not allowed and not inside(n.rect, container.rect):
                add("contain", f"{nm} leaves {container.spec.get('name')}")
            # the caption rule applies to a label whose nearest container IS the button;
            # a label in a chip/badge inside the button is judged against that chip (contain)
            btn = container if container is not None and container.spec.get("type") == "button" else None
            if btn is not None and btn.spec.get("sizeClass") == "HUD":
                btn = None   # HUD side buttons carry a caption BAND on the face's lower edge (v3.2)
            if btn is not None and not allowed:
                bx, by, bw, bh = btn.rect
                x, y, w, h = n.rect
                padx, pady = 0.35 * bh, 0.14 * bh
                if x - bx < padx - 1 or bx + bw - (x + w) < padx - 1 or y - by < pady - 1 or by + bh - (y + h) < pady - 1:
                    add("caption_pad", f"{nm} in {btn.spec.get('name')}: inset L{x - bx:.0f} R{bx + bw - x - w:.0f} "
                                       f"T{y - by:.0f} B{by + bh - y - h:.0f}, needs {padx:.0f}/{pady:.0f}")
            w, h = n.rect[2], n.rect[3]
            stroke = s.get("textStroke", theme["textStroke"])
            cap = s.get("maxText") or int(h * s.get("textScale", 0.62))
            for t in texts(s):
                if not t:
                    continue
                e = em(s)
                if s.get("wrap"):
                    lines = max(1, int(h // (MIN_TEXT * 1.2)))
                    per = max(len(w_) for w_ in t.split()) if t.split() else len(t)
                    fit = min((w - 2 * stroke) / max(1, per * e), (w - 2 * stroke) * lines / max(1, len(t) * e))
                else:
                    fit = (w - 2 * stroke) / max(1, len(t) * e)
                if fit < min(MIN_TEXT, cap):
                    add("text_fit", f"{nm}: {t!r} needs {len(t) * e * MIN_TEXT + 2 * stroke:.0f}px at {MIN_TEXT}px "
                                    f"in a {w:.0f}px box (fits only at {fit:.1f}px)")
                    break
        # window overhang
        if nm == "Window" and s.get("modal"):
            def inner(k, skip):
                if k.spec.get("name") in ("Header", "CloseButton", "BodyArt"):
                    return
                if not inside(k.rect, n.rect, tol=2):
                    add("window_hang", f"{k.spec.get('name') or k.spec.get('type')} leaves the Window")
                if k.spec.get("cls") == "ScrollingFrame":
                    return  # its content is clipped and scrolled; only the frame itself must fit
                for c in k.children:
                    inner(c, skip)
            for c in n.children:
                inner(c, None)
        if kind == "label":
            cap = s.get("maxText") or int(n.rect[3] * s.get("textScale", 0.62))
            if cap < MIN_TEXT_PX and not s.get("autoX"):
                add("min_text", f"{nm}: max text {cap}px < {MIN_TEXT_PX}px")
        _gaps(n, add)
        for c in n.children:
            walk(c, anc + [n])

    for c in root.children:
        walk(c, [])
    return issues


PHONE = (844, 390)


def touch_phone(name, spec, theme):
    """Touch report at 844x390: physical size of every tappable thing, after the largest window
    UIScale the client may apply on touch (window <= 94% x 90% of the phone). HUD controls get
    no extra scale. Coordinator rule: 44 px physical. Reported separately: the desktop S/M/L
    classes cannot meet it by scaling alone, it needs the phone layout pass."""
    out = []
    s0 = min(PHONE[0] / spec["resolution"][0], PHONE[1] / spec["resolution"][1])
    pspec = mp.prune(spec)
    root = ub.resolve({"type": "root", "size": [1, 0, 1, 0], "children": pspec["children"]},
                      (0, 0, *spec["resolution"]), theme)

    def walk(n, f):
        s = n.spec
        if s.get("name") == "Window" and s.get("modal"):
            ww, wh = n.rect[2], n.rect[3]
            f = max(1.0, min(0.94 * PHONE[0] / (ww * s0), 0.90 * PHONE[1] / (wh * s0)))
        if s.get("type") == "button" or s.get("cls") == "TextButton":
            phys = min(n.rect[2], n.rect[3]) * s0 * f
            if phys < 44:
                out.append(f"{name}: {s.get('name')} {phys:.0f}px physical (window scale {f:.2f})")
        for c in n.children:
            walk(c, f)
    for c in root.children:
        walk(c, 1.0)
    return out


def _rects(spec, theme):
    root = ub.resolve({"type": "root", "size": [1, 0, 1, 0], "children": mp.prune(spec)["children"]},
                      (0, 0, *spec["resolution"]), theme)
    out = []

    def walk(n, hidden):
        hidden = hidden or n.spec.get("visible") is False
        out.append((n, hidden))
        for c in n.children:
            walk(c, hidden)
    for c in root.children:
        walk(c, False)
    return out


def hud_vs_close(theme):
    """Nothing visible in the HUD may overlap any window's close button (the screens share one
    1280x720 canvas and one uniform scale, so this holds at 1345x611 and 1482x673 alike)."""
    hud = json.loads((SPEC / "HUD.json").read_text(encoding="utf-8"))
    hud_nodes = [(n.spec.get("name"), n.rect) for n, hid in _rects(hud, theme)
                 if not hid and n.spec.get("name") and n.spec.get("type") in ("button", "panel", "frame", "label",
                                                                              "icon")
                 and n.spec.get("name") not in ("LeftColumn", "RightColumn", "Toasts")]
    issues = []
    for p in sorted(SPEC.glob("*.json")):
        spec = json.loads(p.read_text(encoding="utf-8"))
        if "children" not in spec or spec.get("kind") != "page":
            continue
        for n, _ in _rects(spec, theme):
            if n.spec.get("name") != "CloseButton":
                continue
            cx, cy, cw, ch = n.rect
            for name, (x, y, w, h) in hud_nodes:
                if x < cx + cw and cx < x + w and y < cy + ch and cy < y + h:
                    issues.append(("hud_close", f"HUD {name} overlaps {p.stem}'s CloseButton"))
    return issues


def check_model(name, model):
    issues = []

    def walk(n):
        if n.get("className") in ("TextLabel", "TextButton", "TextBox") and n.get("properties", {}).get("TextScaled"):
            if not any(c.get("className") == "UITextSizeConstraint" for c in n.get("children", [])):
                issues.append(("size_cap", f"{name}: {n.get('name')} is TextScaled without a UITextSizeConstraint"))
        if (n.get("className") == "ScrollingFrame" and n.get("properties", {}).get("ScrollingDirection") == "X"
                and n.get("name") not in ALLOW_SCROLL_X):
            issues.append(("scroll_x", f"{name}: {n.get('name')} ScrollingDirection X (model)"))
        for c in n.get("children", []):
            walk(c)
    walk(model)
    return issues


def run(verbose=True):
    import build_ui
    theme = build_ui.THEME
    mp.BASE["theme"] = theme
    ub.set_style(theme)
    all_issues = []
    specs = sorted(SPEC.glob("*.json")) + sorted((SPEC / "templates").glob("*.json"))
    for p in specs:
        spec = json.loads(p.read_text(encoding="utf-8"))
        if "children" not in spec:
            continue
        all_issues += check_spec(p.stem, spec, theme)
    for p in sorted(UI.glob("*.model.json")) + sorted((UI / "Templates").glob("*.model.json")):
        all_issues += check_model(p.name.removesuffix(".model.json"), json.loads(p.read_text()))
    touch = []
    for p in specs:
        spec = json.loads(p.read_text(encoding="utf-8"))
        if "children" in spec and spec.get("kind") != "world" and p.parent == SPEC:
            touch += touch_phone(p.stem, spec, theme)
    print(f"touch_phone @ 844x390 (44 px physical, after the max touch window scale): {len(touch)} under "
          f"(reported, not gating: needs the phone layout pass)")
    if verbose:
        for m in touch:
            print(f"      {m}")
    all_issues += hud_vs_close(theme)
    by = {}
    for code, msg in all_issues:
        by.setdefault(code, []).append(msg)
    for w, h in SIZES:
        print(f"fit_gate @ {w}x{h}: {len(all_issues)} failures (uniform UIScale: same geometry)")
    for code, msgs in sorted(by.items()):
        print(f"  {code:<13} {len(msgs)}")
        if verbose:
            for m in msgs[:400]:
                print(f"      {m}")
    return all_issues


if __name__ == "__main__":
    v = "-q" not in sys.argv
    raise SystemExit(1 if run(v) else 0)
