"""Compose the per-model q34.png renders into one labelled batch sheet with measured size vs target.
python sheet.py out.png Name [Name ...]"""
import json, sys, pathlib
from PIL import Image, ImageDraw, ImageFont
HERE = pathlib.Path(__file__).resolve().parent
GAME = HERE.parents[3]; WORK = GAME / "work/models/zones_a"
_k = json.load(open(GAME / "design/kit.json", encoding="utf-8"))
kit = {**_k["zone_props"], **_k.get("zone_props_v2", {})}
out, names = sys.argv[1], sys.argv[2:]
T = 640; cols = min(3, len(names)); rows = (len(names) + cols - 1) // cols
sheet = Image.new("RGB", (cols * T, rows * (T + 60)), (30, 32, 40))
d = ImageDraw.Draw(sheet)
try: f = ImageFont.truetype("arial.ttf", 18)
except OSError: f = ImageFont.load_default()
for i, n in enumerate(names):
    x, y = (i % cols) * T, (i // cols) * (T + 60)
    sheet.paste(Image.open(WORK / n / "q34.png").convert("RGB").resize((T, T)), (x, y))
    m = json.load(open(WORK / n / "measure.json"))[n]
    tgt = kit[n]["size"]
    pct = [round(100 * (a - b) / b) for a, b in zip(m["bounds_studs"], tgt)]
    d.text((x + 6, y + T + 4), n.replace("Prop_", ""), fill="white", font=f)
    d.text((x + 6, y + T + 28), f"tris {m['tris']}  size {m['bounds_studs']} vs {tgt} ({pct}%)", fill=(255, 220, 120), font=f)
sheet.save(out); print("sheet", out)
