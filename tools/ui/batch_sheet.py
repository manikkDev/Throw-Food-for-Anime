"""Contact sheet of a batch of screens at the in-game test size 1345x611 and the phone 844x390.

    python tools/ui/batch_sheet.py FoodShop,Store,Squad,HeroIndex work/ui/mockups/v3_batch1.png
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
MOCK = ROOT / "work" / "ui" / "mockups"
BACK = ((142, 209, 252), (155, 219, 122))


def at(img, vw, vh):
    sc = min(vw / img.width, vh / img.height)
    out = Image.new("RGB", (vw, vh))
    d = ImageDraw.Draw(out)
    for y in range(vh):
        t = y / vh
        d.line([(0, y), (vw, y)], fill=tuple(int(BACK[0][i] + (BACK[1][i] - BACK[0][i]) * t) for i in range(3)))
    s = img.resize((round(img.width * sc), round(img.height * sc)), Image.LANCZOS)
    out.paste(s, ((vw - s.width) // 2, (vh - s.height) // 2))
    return out


names, dest = sys.argv[1].split(","), sys.argv[2]
tiles = []
for n in names:
    im = Image.open(MOCK / f"{n}.png").convert("RGB")
    tiles.append((n, at(im, 1345, 611), at(im, 844, 390)))
W = 1345 + 844 + 30
H = sum(611 + 40 for _ in tiles) + 10
sheet = Image.new("RGB", (W, H), (24, 26, 56))
d = ImageDraw.Draw(sheet)
y = 10
for n, a, b in tiles:
    d.text((10, y), f"{n}   1345x611 | 844x390", fill=(255, 255, 255))
    sheet.paste(a, (10, y + 20))
    sheet.paste(b, (1365, y + 20))
    y += 651
sheet.save(dest)
print(dest)
