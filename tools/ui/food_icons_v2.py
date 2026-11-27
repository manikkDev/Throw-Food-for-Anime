#!/usr/bin/env python3
"""Food icons from the real food models (plan 13 phase B).

    python tools/ui/food_icons_v2.py                 # render every food in design/foods.json
    python tools/ui/food_icons_v2.py onigiri ohagi   # only these
    python tools/ui/food_icons_v2.py --upload        # upload what changed, write the id map, gen_icons.py
    python tools/ui/food_icons_v2.py --sheet         # contact sheet -> assets/ui/food_icons_v2_sheet.png

HOW: Studio (EDIT mode, window in front) stands one food template on tools/studio/foods/icon_stage.luau
and this tool captures it twice through the Studio MCP, on a white wall and on a black one. The
difference of the two pictures is the food's exact outline, whatever its colours (a white rice ball
and a black lunch box both cut out clean; a colour key would eat one of them). The cut-out is
framed in 256 x 256 with the icon family's ink outline (icons v4: one thin ink line, no white keyline).

Output: assets/ui/food_icons_v2/Food_<id>.png, ids in assets/ui/ids_food_icons_v2.json (read LAST
by tools/gen_icons.py, so a food's own icon replaces any stand-in).
"""
from __future__ import annotations

import base64
import importlib.util
import io
import json
import subprocess
import sys
import time
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SKILLS = Path.home() / ".claude" / "skills"
HELPER = SKILLS / "create-roblox-game" / "scripts" / "studio_mcp.py"
UPLOAD = SKILLS / "roblox-ui" / "scripts" / "upload_icons.py"
STAGE = ROOT / "tools" / "studio" / "foods" / "icon_stage.luau"
DESIGN = ROOT / "design" / "foods.json"
OUT = ROOT / "assets" / "ui" / "food_icons_v2"
IDS = ROOT / "assets" / "ui" / "ids_food_icons_v2.json"
SHEET = ROOT / "assets" / "ui" / "food_icons_v2_sheet.png"

ORIGIN = (-2400, 900, 0)
CAMERA = [ORIGIN[0], ORIGIN[1] + 3.4, ORIGIN[2] - 7.4]
INK = (27, 31, 75)
SIZE, INSIDE, LINE = 256, 222, 5


def studio():
    spec = importlib.util.spec_from_file_location("studio_mcp", HELPER)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)  # type: ignore[union-attr]
    client = mod.Client()
    return client, mod.studio_id(client, None)


def stage(client, sid: str, ids: list[str], row: int, wall: str) -> str:
    code = STAGE.read_text(encoding="utf-8")
    code = code.replace("local IDS = {} --[[IDS]]", "local IDS = {" + ", ".join(f'"{i}"' for i in ids) + "}")
    code = code.replace("local ROW = 0 --[[ROW]]", f"local ROW = {row}")
    code = code.replace('local WALL = "black" --[[WALL]]', f'local WALL = "{wall}"')
    ok, text = client.tool("execute_luau", {"code": code, "datamodel_type": "Edit", "studio_id": sid})
    if not ok:
        raise SystemExit("stage failed: " + text[:400])
    return text


def capture(client, sid: str, name: str) -> Image.Image:
    reply = client.rpc("tools/call", {"name": "screen_capture", "arguments": {
        "capture_id": name, "studio_id": sid, "camera_position": CAMERA, "look_at_position": list(ORIGIN)}})
    for part in reply.get("result", {}).get("content", []):
        if part.get("type") == "image":
            return Image.open(io.BytesIO(base64.b64decode(part["data"]))).convert("RGB")
    raise SystemExit("no picture came back (is the Studio window in front?): " + json.dumps(reply)[:300])


def cut_out(white: Image.Image, black: Image.Image) -> Image.Image:
    """Difference matte: where the two pictures agree is food, where they differ is wall."""
    diff = ImageChops.difference(white, black).convert("L")
    span = diff.getpixel((4, 4))  # the wall's own white-minus-black, read in a corner
    if span < 128:
        raise ValueError("the wall did not change colour between the captures")
    alpha = diff.point(lambda v: max(0, min(255, int(255 - v * 255 / span))))
    alpha = alpha.point(lambda v: 0 if v < 24 else (255 if v > 232 else v))
    # the black-wall picture is the food already multiplied by its alpha
    r, g, b = black.split()
    return Image.merge("RGBA", (r, g, b, alpha))


def frame(cut: Image.Image) -> Image.Image:
    # Studio's own overlays (the editor grid, a selection box) are drawn in the 3D view and so are
    # in the captures as hairlines. Eroding the mask removes anything thin; the food is what is
    # left, and everything outside its box is cleared.
    mask = cut.getchannel("A").point(lambda v: 255 if v > 40 else 0)
    box = mask.filter(ImageFilter.MinFilter(9)).getbbox()
    if not box:
        raise ValueError("the cut-out is empty")
    pad = 6
    box = (max(0, box[0] - pad), max(0, box[1] - pad), min(cut.width, box[2] + pad), min(cut.height, box[3] + pad))
    if (box[2] - box[0]) < cut.width * 0.12 and (box[3] - box[1]) < cut.height * 0.2:
        raise ValueError("the food is far too small in the capture")
    cut = cut.crop(box)
    scale = INSIDE / max(cut.size)
    cut = cut.resize((max(1, round(cut.width * scale)), max(1, round(cut.height * scale))), Image.LANCZOS)
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    at = ((SIZE - cut.width) // 2, (SIZE - cut.height) // 2)
    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    layer.paste(cut, at)
    alpha = layer.getchannel("A")
    grown = alpha.filter(ImageFilter.MaxFilter(LINE * 2 + 1)).filter(ImageFilter.GaussianBlur(0.8))
    ink = Image.new("RGBA", (SIZE, SIZE), INK + (0,))
    ink.putalpha(grown)
    canvas = Image.alpha_composite(canvas, ink)
    # un-premultiply the food over the ink so soft edges do not go grey
    solid = Image.new("RGBA", (SIZE, SIZE), INK + (255,))
    solid.paste(layer.convert("RGB"), (0, 0), alpha)
    solid.putalpha(alpha.point(lambda v: 255 if v > 8 else 0))
    return Image.alpha_composite(canvas, solid)


def render(ids: list[str]) -> int:
    front = ROOT / "tools" / "studio" / "front.ps1"
    subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(front)],
                   capture_output=True)
    client, sid = studio()
    OUT.mkdir(parents=True, exist_ok=True)
    try:
        for fid in ids:
            icon = None
            for attempt in range(4):  # a capture now and then shows the wall before its new colour
                shots = {}
                for wall in ("white", "black"):
                    text = stage(client, sid, [fid], 1, wall)
                    if fid not in text:
                        raise SystemExit(f"{fid}: no template in ReplicatedStorage.Assets.Foods ({text.strip()})")
                    time.sleep(0.4 + 0.4 * attempt)
                    shots[wall] = capture(client, sid, f"icon_{fid}_{wall}")
                try:
                    icon = frame(cut_out(shots["white"], shots["black"]))
                    break
                except ValueError:
                    continue
            if icon is None:
                raise SystemExit(f"{fid}: the two captures never differed")
            icon.save(OUT / f"Food_{fid}.png")
            print(f"ok Food_{fid}")
    finally:
        try:
            stage(client, sid, [], 0, "black")
        finally:
            client.close()
    return 0


def sheet() -> int:
    files = sorted(OUT.glob("Food_*.png"))
    cols = 9
    rows = (len(files) + cols - 1) // cols
    cell = 150
    page = Image.new("RGB", (cols * cell, rows * cell), (245, 236, 214))
    for n, path in enumerate(files):
        icon = Image.open(path).resize((cell - 14, cell - 14), Image.LANCZOS)
        page.paste(icon, ((n % cols) * cell + 7, (n // cols) * cell + 7), icon)
    page.save(SHEET)
    print(f"{len(files)} icons -> {SHEET.relative_to(ROOT)}")
    return 0


def upload() -> int:
    done = subprocess.run([sys.executable, str(UPLOAD), "--icons", str(OUT), "--map", str(IDS)])
    if done.returncode:
        return done.returncode
    return subprocess.run([sys.executable, str(ROOT / "tools" / "gen_icons.py")]).returncode


def main() -> int:
    args = sys.argv[1:]
    if "--upload" in args:
        return upload()
    if "--sheet" in args:
        return sheet()
    design = json.loads(DESIGN.read_text(encoding="utf-8"))["foods"]
    ids = args or list(design)
    unknown = [i for i in ids if i not in design]
    if unknown:
        print(f"FAIL not in design/foods.json: {unknown}")
        return 1
    return render(ids)


if __name__ == "__main__":
    sys.exit(main())
