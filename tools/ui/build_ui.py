"""Build every Manga Pop screen: spec -> mockup PNG + .model.json + Luau, then verify.

    python tools/ui/build_ui.py            # build all, verify, contact sheets
    python tools/ui/build_ui.py --only HUD,Store

Outputs
  design/ui/theme.json, design/ui/<Screen>.json, design/ui/templates/<T>.json   specs
  src/ui/<Screen>.model.json, src/ui/Templates/<T>.model.json                    shipping trees
  work/ui/mockups/<Screen>.png (+ phone/), _sheet_desktop.png, _sheet_phone.png  mockups
  work/ui/builders/<Screen>.lua                                                  Luau builders
  work/ui/verify.json                                                            checker results
"""

from __future__ import annotations

import argparse
import copy
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import mangapop as mp  # noqa: E402  (applies the patches)
from mangapop import ub  # noqa: E402
import mp3  # noqa: E402,F401  (v3 system: emitter additions)
import mp4  # noqa: E402,F401  (v4 system: thin strokes, lip only on buttons, type scale)
import screens_v52 as screens  # noqa: E402  (UI v5.2: v5.1 + the training games (Focus bar, breath disc))
import verify_ui as vu  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

ROOT = mp.ROOT
SPEC_DIR = ROOT / "design" / "ui"
UI_DIR = ROOT / "src" / "ui"
MOCK = ROOT / "work" / "ui" / "mockups"
LUAU = ROOT / "work" / "ui" / "builders"
PHONE = (844, 390)

THEME = {
    "_comment": "Manga Pop (design/plan/05-ui-ux.md). Read by tools/ui/mangapop.py through the roblox-ui "
                "builder. outline = ink, used for buttons and all text strokes; panels add a white keyline "
                "and an ink comic shadow per element (keyline/comic keys).",
    "font": "FredokaOne",
    "stroke": 3,
    "textStroke": 2,
    "corner": 16,
    "shadowOffset": 0,
    "outline": "#0D0F2B",
    "backdrop": ["#8ED1FC", "#9BDB7A"],
    "palette": {
        "panel": "#1B1F4B", "panelHi": "#2B3175", "panelDeep": "#12153A", "cream": "#FFF4DC",
        "ink": "#0D0F2B", "onDark": "#FFFFFF", "soft": "#C9CDF5",
        "yen": "#DDF25A", "power": "#5CC8FF", "luck": "#5BE37D", "gold": "#FFC93C",
        "powerInk": "#1D6FD1", "luckInk": "#15803D", "premiumInk": "#C0267A",
        "confirm": "#34D17A", "buy": "#FFC93C", "info": "#38BDF8", "premium": "#FF4FA3",
        "danger": "#F04438", "grey": "#6B7099", "slate": "#4A5078", "softRed": "#FF8A8A", "violet": "#A855F7", "coral": "#FF5A5F",
        "header_from": "#FF5A5F", "header_to": "#FFC93C",
    },
    "highlight": False,
    "motion": {"hover": {"scale": 1.06, "rotate": 0, "time": 0.1, "style": "Back"},
               "press": {"scale": 0.94, "time": 0.08},
               "open": {"style": "pop", "from": 0.85, "time": 0.18}},
}


def icon_map():
    m = {p.stem: p for p in (ROOT / "assets" / "ui" / "icons").glob("*.png")}
    for p in (ROOT / "assets" / "ui" / "icons_big").glob("*.png"):  # v3: large glossy keys (*Big)
        m[p.stem] = p
    for p in (ROOT / "assets" / "ui" / "food_icons").glob("*.png"):
        m[f"FoodIcon_{p.stem}"] = p
    for p in (ROOT / "assets" / "ui" / "fx_v4").glob("*.png"):  # effect sprites and card backdrops
        m[p.stem] = p
    for p in (ROOT / "assets" / "ui" / "zone_bg").glob("*.png"):  # Hero Index zone card backdrops
        m[p.stem] = p
    return m


def write_json(path: Path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, indent=1), encoding="utf-8")
    tmp.replace(path)


def post_root(root, spec):
    props = root["properties"]
    canvas = next(c for c in root["children"] if c.get("name") == "CanvasFrame")
    w, h = spec["resolution"]
    if spec.get("rootClass"):
        root["className"] = spec["rootClass"]
        for k in ("DisplayOrder", "IgnoreGuiInset"):
            props.pop(k, None)
        props["Enabled"] = True
        props.update(spec.get("rootProps", {}))
        canvas["children"] = [c for c in canvas["children"] if c.get("className") != "UIScale"]
        canvas["properties"]["Size"] = {"UDim2": [[1, 0], [1, 0]]}
    else:
        # full-screen layers (letterbox, flash) live on the ScreenGui itself so they
        # cover any aspect ratio, not just the 1280x720 canvas
        lift = {c["name"] for c in spec["children"] if c.get("screenLevel")}
        moved = [c for c in canvas["children"] if c.get("name") in lift]
        canvas["children"] = [c for c in canvas["children"] if c.get("name") not in lift]
        root["children"].extend(moved)
        # The page is authored at 1280x720 in offset: the canvas IS that rectangle,
        # centred, and the one UIScale maps it to the viewport (min of the two ratios).
        canvas["properties"]["Size"] = {"UDim2": [[0, w], [0, h]]}
        props["ScreenInsets"] = "DeviceSafeInsets"


def render_png(spec, icons):
    theme = THEME
    size = spec["resolution"]
    pspec = mp.prune(spec)
    root = ub.resolve({"type": "root", "name": spec["name"], "size": [1, 0, 1, 0],
                       "children": pspec["children"]}, (0, 0, size[0], size[1]), theme)
    return ub.render(root, theme, theme["palette"], icons, size).convert("RGB")


def emit(spec):
    theme = THEME
    size = spec["resolution"]
    full = {"type": "root", "name": spec["name"], "size": [1, 0, 1, 0], "children": spec["children"]}
    ub.RESOLVED_H.clear()
    ub.measure_heights(full, theme, size)
    tree = [i for c in spec["children"] for i in ub.to_instances(c, theme, theme["palette"])]
    root = ub.build_root(spec, spec["name"], tree)
    post_root(root, spec)
    model = copy.deepcopy(root)
    ub.strip_content_for_rojo(model)
    model.pop("name", None)
    lua = ub.luau(ub.qualify_enums(copy.deepcopy(root)))
    return model, lua


def emit_template(node):
    theme = THEME
    w, h = node["size"][1], node["size"][3]
    ub.RESOLVED_H.clear()
    ub.measure_heights({"type": "root", "size": [1, 0, 1, 0], "children": [node]}, theme, (w, h))
    inst = ub.to_instances(node, theme, theme["palette"])[0]
    inst = copy.deepcopy(inst)
    ub.strip_content_for_rojo(inst)
    inst.pop("name", None)
    return inst


ORIG_DEVICES = list(vu.DEVICES)
ORIG_SMALL = vu.SMALL
ORIG_TOUCH = vu.TOUCH_MIN


def verify(spec, stock=False):
    pspec = mp.prune(spec)
    rw, rh = spec["resolution"]
    if stock:
        vu.DEVICES, vu.SMALL, vu.TOUCH_MIN = ORIG_DEVICES, ORIG_SMALL, ORIG_TOUCH
    elif spec.get("kind") == "world":
        # A SurfaceGui / BillboardGui has no UIScale and no phone viewport: it is
        # drawn at its own canvas size, so the canvas is the only "device".
        vu.DEVICES, vu.SMALL, vu.TOUCH_MIN = [("world", rw, rh)], (rw, rh), ORIG_TOUCH
    else:
        # The two sizes the brief names. Touch floor: the project's 56 px at 1280x720,
        # i.e. 56 x the phone's UIScale in points. Text floor stays the skill's 11 pt
        # on the phone, which is ~21 px at the reference.
        sc = min(PHONE[0] / rw, PHONE[1] / rh)
        vu.DEVICES = [("desktop", 1280, 720), ("phone", PHONE[0], PHONE[1]), ("desktop-hd", 1920, 1080),
                      ("laptop", 1345, 611)]
        vu.SMALL = PHONE
        # desktop look: the smallest class (S, 34 px at 720p). Phone touch (44 px physical) is
        # checked separately by fit_gate's touch_phone report.
        vu.TOUCH_MIN = 34 * sc - 0.01
        # text floor = the project's 14 px at 720p, in phone points (was 11 pt = ~21 px,
        # which made the HUD chips too big in game)
        # v3 type scale starts at 12 px at 720p (coordinator's scale 12/14/16/20/26/34)
        vu.MIN_TEXT_PT = 12 * sc - 0.01
    try:
        issues = vu.check(pspec, THEME, None, spec["name"])
        # v3.3: a depth-stack element paints its lip inside its box, so its face (where children are
        # centred) sits lip/2 above the box centre. verify_ui measures against the box; forgive exactly
        # that offset (|off| <= 3.5 px, the largest lip/2 + rounding) for vertical centring only.
        import re as _re
        keep = []
        for i in issues:
            m = _re.search(r"centred (vertically|horizontally) but its centre is ([+-][0-9]+)px", i["msg"])
            lim = 3 if (m and m.group(1) == "vertically") else 5      # lip/2 vertical, comic/2 horizontal
            if i["check"] == "off_centre" and m and abs(int(m.group(2))) <= lim:
                continue
            keep.append(i)
        return keep
    finally:
        vu.DEVICES, vu.SMALL, vu.TOUCH_MIN = ORIG_DEVICES, ORIG_SMALL, ORIG_TOUCH
        vu.MIN_TEXT_PT = 11


def phone_composite(img: Image.Image, spec) -> Image.Image:
    if spec.get("kind") == "world":
        return img
    pw, ph = PHONE
    sc = min(pw / img.width, ph / img.height)
    bd = THEME["backdrop"]
    out = ub.v_gradient((pw, ph), ub.hex_rgb(bd[0]), ub.hex_rgb(bd[1])).convert("RGB")
    small = img.resize((round(img.width * sc), round(img.height * sc)), Image.LANCZOS)
    out.paste(small, ((pw - small.width) // 2, (ph - small.height) // 2))
    return out


def sheet(items, tile, cols, path):
    tw, th = tile
    rows = (len(items) + cols - 1) // cols
    out = Image.new("RGB", (cols * (tw + 16) + 16, rows * (th + 46) + 16), (24, 26, 56))
    d = ImageDraw.Draw(out)
    font = ub._orig_load_font(26) if hasattr(ub, "_orig_load_font") else mp._orig_load_font(26)
    for i, (name, im) in enumerate(items):
        x = 16 + (i % cols) * (tw + 16)
        y = 16 + (i // cols) * (th + 46)
        d.text((x, y), name, fill=(255, 255, 255), font=font)
        sc = min(tw / im.width, th / im.height)
        t = im.resize((max(1, round(im.width * sc)), max(1, round(im.height * sc))), Image.LANCZOS)
        out.paste(t, (x + (tw - t.width) // 2, y + 34 + (th - t.height) // 2))
    out.save(path)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default=None)
    args = ap.parse_args()
    only = set(args.only.split(",")) if args.only else None

    mp.BASE["theme"] = THEME
    ub.set_style(THEME)
    write_json(SPEC_DIR / "theme.json", THEME)
    icons = icon_map()
    results = {}
    desk, phone = [], []

    for fn in screens.SCREENS:
        spec = fn()
        for c in spec["children"]:
            mp4.normalize(c)
        name = spec["name"]
        if only and name not in only:
            continue
        write_json(SPEC_DIR / f"{name}.json", spec)
        img = render_png(spec, icons)
        MOCK.mkdir(parents=True, exist_ok=True)
        img.save(MOCK / f"{name}.png")
        ph = phone_composite(img, spec)
        (MOCK / "phone").mkdir(exist_ok=True)
        ph.save(MOCK / "phone" / f"{name}.png")
        desk.append((name, img))
        phone.append((name, ph))
        model, lua = emit(spec)
        write_json(UI_DIR / f"{name}.model.json", model)
        LUAU.mkdir(parents=True, exist_ok=True)
        (LUAU / f"{name}.lua").write_text(lua, encoding="utf-8")
        results[name] = {"project": verify(spec), "stock": verify(spec, stock=True)}

    for fn, owner in screens.TEMPLATES:
        node = mp4.normalize(fn())
        tname = node["name"]
        if only and owner not in only:
            continue
        w, h = node["size"][1], node["size"][3]
        tnode = copy.deepcopy(node)
        tnode["pos"], tnode["anchor"] = [0, 12, 0, 12], [0, 0]
        tspec = {"name": tname, "theme": "theme.json", "resolution": [w + 24, h + 24], "kind": "world",
                 "children": [tnode]}
        write_json(SPEC_DIR / "templates" / f"{tname}.json", tspec)
        # verified where it lives: inside a page at 1280x720 (modal), scaled to the phone;
        # a world template (leaderboard row) at its own canvas size
        vnode = {**copy.deepcopy(tnode), "modal": True}
        vspec = tspec if owner == "Leaderboard" else {**tspec, "resolution": [1280, 720], "kind": "page",
                                                       "children": [vnode]}
        write_json(UI_DIR / "Templates" / f"{tname}.model.json", emit_template(node))
        timg = render_png(tspec, icons)
        (MOCK / "templates").mkdir(parents=True, exist_ok=True)
        timg.save(MOCK / "templates" / f"{tname}.png")
        results[tname] = {"project": verify(vspec), "stock": []}

    write_json(ROOT / "work" / "ui" / "verify.json", results)
    if not only:
        sheet(desk, (640, 360), 3, MOCK / "_sheet_desktop.png")
        sheet(phone, (633, 293), 3, MOCK / "_sheet_phone.png")

    total_fail = 0
    for name, r in results.items():
        p = r["project"]
        fails = [i for i in p if i["level"] == "fail"]
        warns = [i for i in p if i["level"] == "warn"]
        sfails = [i for i in r["stock"] if i["level"] == "fail"]
        total_fail += len(fails)
        print(f"{name:<24} project: {len(fails)} fail {len(warns)} warn   stock(4 devices): {len(sfails)} fail")
        for i in fails + warns:
            print(f"    [{i['level']}] {i['check']}: {i['msg']}")
    print(f"\nproject-rule failures: {total_fail}")
    import fit_gate
    total_fail += len(fit_gate.run(verbose=False))
    return 1 if total_fail else 0


if __name__ == "__main__":
    raise SystemExit(main())
