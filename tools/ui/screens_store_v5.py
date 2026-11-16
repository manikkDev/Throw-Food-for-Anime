"""UI v5 store (owner's review 4; v5.1 = review 5; v5.2 = review 6; v5.3 = review 7, see CHANGES-v4.md): the Store screen and its two card templates, rebuilt as a premium shop.

build_ui.py builds every screen from screens_v42; `install(screens)` swaps in this file's Store and its
templates, so the other screens are never touched here.

  left       SUMMON SCROLL: the rarest scroll hero full length on a stage (cosmic backdrop, turning sigil and
             rune ring, radial speed lines, an SSJ-style aura silhouette and violet flames from the owner's own VFX
             packs, smoke at the feet, lightning crackles, rising speed lines and embers), an animated rarity chip,
             the drop chance, SEE ODDS, "Earns Nx your best", 6 exclusive heroes, and three buy TILES with the
             count ABOVE each button (the buttons hold only the Robux price) and BEST VALUE on the x10 tile's edge.
  FEATURED   two showcase cards: the starter pack (its hero animated, spinning coins, what is inside with icons)
             and the limited hero (sun burst, crest, flames, slash arc, his perks); stickers, light-chase borders.
  GAMEPASSES wide cards: icon tile, name, a short exact description of what the pass does, price.
  LUCK & BOOSTS / YEN PACKS  cards with a one-line description each.

Effects: every owner texture carries `VfxImage` (its asset id); a flipbook is a clipping square holding a `Sheet`
image (grid x grid of the square) with `VfxGrid` / `VfxFps`; motion attributes `VfxTurn` (deg/s), `VfxPulse`
(v5.2: never used, nothing in the store changes size), `VfxBreath` (transparency breathing), `VfxRise` (px per
loop), `VfxDrift`, `VfxPeriod`, `VfxOnce` (crackle: one cycle then a pause), `VfxThrust` (px out along the
rotation), `VfxFall` (a drip's drop), `VfxDrip` (a blood run, see drip()).
Ui/StoreFx.luau plays all of them in one loop while the store is open. Texture ids: assets/ui/ids_store_v5.json.
"""

from __future__ import annotations

import json
import math

import mangapop as mp
import mp3
import mp4
import screens_v4 as v4
import screens_v42 as v42
from mangapop import WHITE, frame, ico, row, col, sample
from mp4 import T, ribbon_tag, sheen, vbtn
from screens import CFG, page

ROOT = mp.ROOT
TEX = json.loads((ROOT / "assets" / "ui" / "ids_store_v5.json").read_text(encoding="utf-8"))["textures"]
PASSES, PRODS = v4.PASSES, v4.PRODS
SECTION = v42.SECTION
STORE_W = 662
INNER_W = 634
BANNER_W, BODY_H = 436, 540


# =================================================================== effect sprites

def vfx(name, key, side, pos, anchor=(0.5, 0.5), tint="#FFFFFF", alpha=0.0, z=2, w=None, h=None, rot=0, **motion):
    """One effect layer. `key` = an owner texture (ids_store_v5.json) or an Icons key (FxGlow ...).
    A flipbook texture becomes a clipping square with a `Sheet` child that StoreFx steps over the grid."""
    attrs = {}
    for k, v in motion.items():
        attrs["Vfx" + k[0].upper() + k[1:]] = v
    tex = TEX.get(key)
    W, H = w or side, h or side
    if tex and tex.get("grid", 1) > 1:
        g = tex["grid"]
        img = f"rbxassetid://{tex['id']}"
        # the Sheet ships at the holder's size showing frame 0 in the mockup (Vfx_<id>_f0.png); StoreFx sizes it to
        # grid x grid of the holder and steps it (so nothing hangs outside the window in the tree as authored)
        sheet = {**ico(f"Vfx_{tex['id']}_f0", side, name="Sheet", pos=[0, 0, 0, 0]), "size": [1, 0, 1, 0],
                 "tint": tint, "overhang": True, "centre": False,
                 "props": {"Image": img, "ScaleType": "Stretch"}, "attrs": {"VfxImage": img}}
        if alpha:
            sheet["alphaImg"] = alpha
        attrs.update({"VfxGrid": g, "VfxFps": tex.get("fps", 20)})
        return {"type": "frame", "name": name, "transparent": True, "size": [0, side, 0, side], "pos": list(pos),
                "anchor": list(anchor), "z": z, "overhang": True, "centre": False,
                "props": {"ClipsDescendants": True}, "attrs": attrs, "children": [sheet]}
    if tex:
        img = f"rbxassetid://{tex['id']}"
        n = {**ico(f"Vfx_{tex['id']}", side, name=name), "props": {"Image": img, "ScaleType": "Stretch"}}
        attrs["VfxImage"] = img
    else:
        n = ico(key, side, name=name)
    n.update({"size": [0, W, 0, H], "pos": list(pos), "anchor": list(anchor), "z": z, "tint": tint,
              "overhang": True, "centre": False, "attrs": attrs})
    if alpha:
        n["alphaImg"] = alpha
    if rot:
        n["rotation"] = rot
    return n


def embers(prefix, n, area_w, bottom, tint, z=7, size=14, rise=150, seed=0):
    out = []
    for i in range(n):
        x = round(-area_w / 2 + (i + 0.5) * area_w / n + ((i * 37 + seed) % 17) - 8)
        out.append(vfx(f"{prefix}{i + 1}", "Flare", size - (i % 3) * 3, [0.5, x, 1, bottom - (i * 23 % 60)],
                       tint=tint, alpha=0.1, z=z, rise=rise, drift=6 + i % 4, period=2.2 + (i % 5) * 0.35))
    return out


def streaks(prefix, n, area_w, tint, z=3, h=96, alpha=0.45):
    out = []
    for i in range(n):
        x = round(-area_w / 2 + (i + 0.5) * area_w / n)
        out.append(vfx(f"{prefix}{i + 1}", "Streak", 12, [0.5, x, 1, -(i * 41 % 70)], anchor=(0.5, 1), w=12,
                       h=h - (i % 3) * 18, tint=tint, alpha=alpha, z=z, rise=210, period=0.9 + (i % 4) * 0.22))
    return out


def scrim(name, w=None, h=None, hexc="#000000", start=0.0, stop=0.85, rot=90, corner=0, **kw):
    """v5.1: a darkening (or fading) gradient: opacity `start` at the gradient's start -> `stop` at its end, along
    `rot` (90 = top to bottom, 0 = left to right). One Frame + one UIGradient (Transparency), no image."""
    return {"type": "frame", "name": name, "colour": [hexc, hexc], "outline": False, "corner": corner,
            "size": [0, w, 0, h] if w is not None else [1, 0, 1, 0], "children": [], "overhang": True,
            "centre": False, "scrim": {"from": start, "to": stop, "rot": rot}, **kw}


def centred_ribbon(name, text, text_name, w, samples=None):
    """A ribbon sitting CENTRED on its card's top edge (half above, half below), pivoting on its centre."""
    r = ribbon_tag(name, text, colour="danger", text_name=text_name, samples=samples, px=15, h=24, w=w)
    r["pos"], r["anchor"] = [0.5, 0, 0, 0], [0.5, 0.5]
    return r


def icon_slot(side, icon_key, icon_side, **kw):
    """The ONE framed icon slot of every pass / product card: dark well, white rim, soft glow, icon centred."""
    return {"type": "frame", "name": "IconSlot", "colour": ["#2E1870", "#12082E"], "corner": 14,
            "keyline": "#FFFFFF", "keepKeyline": True, "size": [0, side, 0, side], "children": [
                vfx("SlotGlow", "FxGlow", side - 4, [0.5, 0, 0.5, 0], tint="#FFFFFF", alpha=0.55, z=1),
                {**ico(icon_key, icon_side, name="CardIcon", pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5]), "z": 3},
            ], **kw}


def header_band(w, h, hexc, kids, **kw):
    """The coloured title band at the top of a pass / product card."""
    return {"type": "frame", "name": "HeaderBand", "colour": [mp4.light(hexc, 0.3), mp4.dark(hexc, 0.82)],
            "corner": 12, "keyline": "#FFFFFF", "keepKeyline": True, "size": [0, w, 0, h],
            "children": [sheen(corner=12, opacity=0.18, z=1), *kids], **kw}


# =================================================================== v5.2: the framed hero panel

def hero_frame(name, w, h, pos, theme, inner, viewport, z=4, rim=()):
    """v5.2 (owner's review 6): every store hero stands INSIDE a framed glass panel, never on the painting.
    A rounded frame (themed rim, a light chase from StoreFx.border), a dark frosted glass fill that lets the art
    and the flames behind it show through faintly, a themed pattern, an inner glow at the top and bottom edges, a
    breathing core light behind the hero, `inner` effects (behind the hero), the hero's ViewportFrame (rounded by
    Store.luau), and a gloss highlight over the glass (StoreFx.shine sweeps a glint across it). Every layer
    inside fits the frame: rotated sprites are not clipped by ClipsDescendants, so they stay smaller than it.
    v5.3 (owner's review 7): `rim` = the themed effects that hug the panel's edges (flames licking up its sides,
    blood bursting at its corners and running down from its rim). They live INSIDE the frame, above the glass
    fill, pattern and inner glows (so nothing mutes them) and below the hero's viewport (so he stays readable),
    clipped by the frame itself; frame-local coordinates, never rotated."""
    g0, g1 = theme["glass"]
    kids = [
        {**ico(theme["pattern"], 100, name="GlassPattern", pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5]),
         "size": [1, 0, 1, 0], "z": 1, "props": {"ScaleType": "Crop"}, "corner": 16, "overhang": True,
         "tint": theme["patternTint"], "alphaImg": theme.get("patternAlpha", 0.82)},
        scrim("InnerGlowTop", None, None, hexc=theme["glow"], start=0.42, stop=0.0, z=1, size=[1, 0, 0, 44],
              corner=16),
        scrim("InnerGlowBottom", None, None, hexc=theme["glow"], start=0.0, stop=0.55, z=1, size=[1, 0, 0, 64],
              pos=[0, 0, 1, 0], anchor=[0, 1], corner=16),
        vfx("CoreGlow", "EnergyCloud", min(w, h) - 16, [0.5, 0, 0.55, 0], tint=theme["glow"], alpha=0.35, z=2,
            breath=0.3, period=3.4),
        *inner,
        *rim,
        {"type": "frame", "name": viewport, "transparent": True, "cls": "ViewportFrame",
         "size": [1, -8, 1, -8], "pos": [0.5, 0, 0.5, 0], "anchor": [0.5, 0.5], "z": 6, "children": [],
         "overhang": True},
        sheen("Gloss", corner=16, opacity=0.2, bands=((0.16, 0.06), (0.26, 0.12)), z=8),
    ]
    return {"type": "frame", "name": name, "colour": [g0, g1], "alpha": theme.get("alpha", 0.42), "corner": 18,
            "keyline": theme["rim"], "keepKeyline": True, "size": [0, w, 0, h], "pos": list(pos),
            "anchor": [0.5, 0], "z": z, "overhang": True, "props": {"ClipsDescendants": True}, "children": kids}


def drip(name, x, y, run_w, show_h, fall, period, phase, z=6):
    """v5.2: a blood run hanging from an edge at (x, y): a clipping holder shows the top of a `Run` image
    (BloodDrip) that StoreFx slides down until its bead reaches the holder's foot, then the bead falls off as
    `<name>Drop` (BloodDrop) and the run draws back up. Position only: nothing changes size."""
    tex = TEX["BloodDrip"]
    run_h = round(run_w * 512 / 96)
    y0, y1 = -(run_h - 8), show_h - run_h
    img = f"rbxassetid://{tex['id']}"
    run = {**ico(f"Vfx_{tex['id']}", run_w, name="Run"), "size": [0, run_w, 0, run_h],
           "pos": [0.5, 0, 0, round(y1 - (y1 - y0) * 0.3)], "anchor": [0.5, 0], "overhang": True, "centre": False,
           "props": {"Image": img, "ScaleType": "Stretch"}, "attrs": {"VfxImage": img}, "tint": "#FFFFFF"}
    holder = {"type": "frame", "name": name, "transparent": True, "size": [0, run_w + 4, 0, show_h],
              "pos": [0, x, 0, y], "anchor": [0.5, 0], "z": z, "overhang": True, "centre": False,
              "props": {"ClipsDescendants": True}, "children": [run],
              "attrs": {"VfxDrip": period, "VfxPhase": phase, "VfxRunFrom": y0, "VfxRunTo": y1}}
    drop_ = vfx(f"{name}Drop", "BloodDrop", round(run_w * 0.8), [0, x, 0, y + show_h + 4], z=z, alpha=0.0,
                fall=fall)
    return [holder, drop_]


# =================================================================== SUMMON SCROLL

STAGE_W, STAGE_H = BANNER_W - 36, 286
TILE_W, TILE_H, TILE_GAP, TILE_PAD = 124, 140, 14, 8
PLATE_H = 72
SF_W, SF_H, SF_Y = 168, 184, 12              # the summon hero's spot in the stage (v5.3: no frame drawn)
SF_CY = SF_Y + SF_H // 2
SIDE_W = (STAGE_W - SF_W) // 2 - 18          # the columns either side of the frame (chance badge, SEE ODDS)


def scroll_tile(amount, best=False):
    """Count on top, savings note, price button at the bottom: one column, equal paddings."""
    price = PRODS[f"SummonScroll{amount}"]["Robux"]
    btn = vbtn(f"SummonBuy{amount}", "confirm", "S", icon="IconRobux", samples=[str(price), "999"],
               text_name="Price", w=TILE_W - 2 * TILE_PAD, px=20, pos=[0.5, 0, 1, -TILE_PAD], anchor=[0.5, 1])
    kids = [
        sheen(corner=16, opacity=0.14, z=1),
        {**T("ScrollCount", None, TILE_W - 2 * TILE_PAD, 26, colour="buy" if best else "onDark", font="display",
             samples=[f"x{amount}", "x10"], pos=[0.5, 0, 0, 12], anchor=[0.5, 0]), "z": 3},
        {**T("ScrollNote", None, TILE_W - 2 * TILE_PAD, 16, colour="luck" if amount > 1 else "soft",
             font="display", samples=["79 EACH", "SAVE 24%"], pos=[0.5, 0, 0, 50], anchor=[0.5, 0]), "z": 3},
        btn,
    ]
    if best:
        kids.append(centred_ribbon("BestValueSticker", "BEST VALUE", "BestValueText", TILE_W - 16))
    return {"type": "panel", "name": f"ScrollTile{amount}",
            "colour": ["#5A2BC0", "#24105E"] if best else ["#3A1F86", "#1C0D4A"],
            "keyline": "#FFC93C" if best else "#9C7BFF", "depth": 0, "corner": 16,
            "size": [0, TILE_W, 0, TILE_H], "children": kids}


def name_plate():
    """The summon hero's banner: the name large (white, rarity gradient + outline at runtime), the earn line as a
    gold chip under it. Sits on the stage's floor, below the hero's frame."""
    perk_samples = ["EARNS 12x YOUR BEST", "EARNS 1.75x YOUR BEST"]
    cw = v4.chip_w(perk_samples, 16) + 38
    chip_ = {"type": "frame", "name": "SummonPerkChip", "colour": ["#FFE58A", "#F2A31B"], "corner": 13,
             "keyline": "#FFF6D0", "keepKeyline": True, "size": [0, cw, 0, 28], "pos": [0.5, 0, 1, -7],
             "anchor": [0.5, 1], "z": 10, "children": [
                 {**ico("IconYen", 20, name="PerkIcon", pos=[0, 8, 0.5, 0], anchor=[0, 0.5]), "z": 11},
                 {**T("SummonHeroPerk", None, cw - 44, 16, colour="ink", font="display", samples=perk_samples,
                      pos=[0, 36, 0.5, 0], anchor=[0, 0.5]), "z": 11}]}
    return {"type": "frame", "name": "SummonHeroTag", "colour": ["#24104F", "#0A0420"], "alpha": 0.18,
            "corner": 16, "keyline": "#C084FC", "keepKeyline": True, "size": [0, STAGE_W - 24, 0, PLATE_H],
            "pos": [0.5, 0, 1, -10], "anchor": [0.5, 1], "z": 9, "children": [
                {**T("SummonHeroName", None, STAGE_W - 48, 24, font="display",
                     samples=["Illusion Overlord", "Sweet-Tooth Detective"], pos=[0.5, 0, 0, 5], anchor=[0.5, 0]),
                 "z": 10},
                chip_]}


def chance_badge():
    """v5.2: the drop chance as a small badge left of the frame: the percentage large, CHANCE under it."""
    return {"type": "frame", "name": "SummonChance", "colour": ["#2A1B66", "#0E0828"], "alpha": 0.15,
            "corner": 14, "keyline": "#B79CFF", "keepKeyline": True, "size": [0, SIDE_W, 0, 60],
            "pos": [0, 10, 0, 12], "z": 9, "children": [
                {**T("SummonChanceText", None, SIDE_W - 12, 24, colour="buy", font="display",
                     samples=["1%", "0.25%"], pos=[0.5, 0, 0, 5], anchor=[0.5, 0]), "z": 10},
                {**T("SummonChanceCaption", "CHANCE", SIDE_W - 12, 15, colour="soft", font="display",
                     pos=[0.5, 0, 1, -4], anchor=[0.5, 1]), "z": 10}]}


def summon_banner():
    rar_s = ["MYTHIC", "LEGENDARY"]
    rar = v4.rchip("SummonRarity", "SummonRarityText", rar_s, "#7B2CF2", px=17, h=28, z=11)
    rar.update({"pos": [0.5, 0, 0, SF_Y], "anchor": [0.5, 0.5], "overhang": True})   # the frame's crest
    fc, cy = [0.5, 0, 0, SF_CY], (0.5, 0.5)
    feet = SF_Y + SF_H - 6
    # v5.3 (owner's review 7): no panel round this hero ("it looks weird for him"): he stands straight on the
    # throne painting inside the magic circle, his aura and a breathing core light behind him, smoke at his feet
    hero = [
        vfx("VfxCoreGlow", "EnergyCloud", SF_W - 8, [0.5, 0, 0, SF_CY + 8], tint="#8E4DFF", alpha=0.35, z=3,
            breath=0.3, period=3.4),
        vfx("VfxAura", "AuraShape", 150, [0.5, 0, 0, feet + 10], (0.5, 1), tint="#9B5CFF", alpha=0.15, z=3),
        {"type": "frame", "name": "SummonViewport", "transparent": True, "cls": "ViewportFrame",
         "size": [0, SF_W, 0, SF_H], "pos": [0.5, 0, 0, SF_Y], "anchor": [0.5, 0], "z": 5, "children": [],
         "overhang": True, "centre": False},
        vfx("VfxSmoke", "Smoke", 150, [0.5, 0, 0, feet + 22], (0.5, 1), tint="#4A2496", alpha=0.25, z=7),
    ]
    odds = mp3.vbtn("OddsButton", "info", "S", text="SEE ODDS", px=14, opens="SummonOdds",
                    pos=[1, -10, 0, 12], anchor=[1, 0], self_face=False, z=9, maxw=SIDE_W)
    stage_kids = [
        {**vfx("VfxBackdrop", "BgThrone", 100, [0.5, 0, 0.5, 0], w=STAGE_W, h=STAGE_H, z=1),
         "size": [1, 0, 1, 0], "corner": 16},
        scrim("StageShade", None, None, hexc="#05020F", start=0.0, stop=0.7, z=1, size=[1, 0, 0, 120],
              pos=[0, 0, 1, 0], anchor=[0, 1], corner=16),
        vfx("VfxSigil", "Sigil", 214, fc, cy, tint="#A77BFF", alpha=0.4, z=2, turn=7),
        vfx("VfxRunes", "Runes", 196, fc, cy, tint="#FF8AF0", alpha=0.35, z=2, turn=-13, breath=0.25),
        vfx("VfxSpeedRays", "SpeedRays", 230, fc, cy, tint="#D7C2FF", alpha=0.45, z=2, turn=4, breath=0.25),
        *streaks("VfxLine", 6, STAGE_W - 30, "#E6D8FF", alpha=0.55),
        vfx("VfxFlameL", "AuraFlame", 128, [0.5, -SF_W // 2, 0, feet], (0.5, 1), tint="#B47BFF", z=3),
        vfx("VfxFlameR", "AuraFlame", 128, [0.5, SF_W // 2, 0, feet], (0.5, 1), tint="#B47BFF", z=3),
        *hero,
        rar,
        vfx("VfxZap", "Zaps", 104, [0.5, -SF_W // 2 - 6, 0, SF_Y + 40], z=8, tint="#E2C8FF", once=True),
        vfx("VfxBolt", "Lightning", 96, [0.5, SF_W // 2 + 6, 0, SF_Y + 70], z=8, tint="#CDB2FF", once=True),
        vfx("VfxGlint", "StarFlip", 56, [1, -46, 0, 120], z=8, tint="#FFFFFF"),
        *embers("VfxSpark", 8, STAGE_W - 40, -PLATE_H - 20, "#FFB05C"),
        chance_badge(), odds,
        name_plate(),
    ]
    stage = {"type": "frame", "name": "StageWell", "colour": ["#1B0B48", "#05020F"], "corner": 16,
             "keyline": "#B79CFF", "size": [0, STAGE_W, 0, STAGE_H], "pos": [0.5, 0, 0, 78], "anchor": [0.5, 0],
             "props": {"ClipsDescendants": True}, "children": stage_kids}
    pool_samples = ["6 EXCLUSIVE HEROES", "12 EXCLUSIVE HEROES"]
    pw = math.ceil(max(mp4.measure(x, 16) for x in pool_samples)) + 8
    pool = frame("PoolChip", pw + 30, 24, [
        {**ico("IconScroll", 22, name="PoolIcon", pos=[0, 0, 0.5, 0], anchor=[0, 0.5]), "z": 3},
        {**T("SummonPoolText", None, pw, 16, colour="soft", font="display", align="left", samples=pool_samples,
             pos=[0, 30, 0.5, 0], anchor=[0, 0.5]), "z": 3}], pos=[0.5, 0, 0, 46], anchor=[0.5, 0])
    tiles = frame("BuyRow", 3 * TILE_W + 2 * TILE_GAP, TILE_H,
                  [scroll_tile(1), scroll_tile(3), scroll_tile(10, best=True)],
                  layout=row(TILE_GAP, "center"), pos=[0.5, 0, 1, -16], anchor=[0.5, 1])
    kids = [
        vfx("VfxCardBg", "Galaxy", 100, [0.5, 0, 0.5, 0], w=BANNER_W, h=BODY_H, tint="#FFFFFF", alpha=0.55, z=0),
        sheen(corner=20, opacity=0.14, z=1),
        {**T("SummonTitle", "SUMMON SCROLL", BANNER_W - 40, 28, colour="buy", font="display", pos=[0.5, 0, 0, 4],
             anchor=[0.5, 0]), "z": 3},
        pool, stage, tiles,
    ]
    return {"type": "panel", "name": "SummonBanner", "colour": ["#3A1786", "#12062E"], "keyline": "#D6C2FF",
            "depth": 0, "corner": 20, "size": [0, BANNER_W, 0, BODY_H], "pos": [0, 0, 0, 0],
            "children": kids}


# =================================================================== FEATURED

FEAT_W, FEAT_H = 310, 420
FF_W, FF_H, FF_Y = 226, 176, 22             # the hero's frame on a featured card
FF_X0, FF_X1 = (FEAT_W - FF_W) // 2, (FEAT_W + FF_W) // 2
FF_CY = FF_Y + FF_H // 2
TITLE_Y = FF_Y + FF_H + 6
PERK_Y, PERK_H, PERK_GAP = TITLE_Y + 36, 26, 6
PERK_W = FEAT_W - 40
PERK_END = PERK_Y + 3 * PERK_H + 2 * PERK_GAP
# v5.3 (owner's review 7): the price button is 60% of the card, centred, with a clear gap above it
BUY_W, BUY_H, BUY_PAD = round(0.6 * FEAT_W), mp4.SIZE_H["M"], 14
BUY_Y = FEAT_H - BUY_PAD - BUY_H
BUY_GAP = BUY_Y - PERK_END
assert BUY_GAP >= 18, BUY_GAP


def perk_rows(prefix, samples_per_row, icons, theme):
    """v5.2: each perk is a themed glass chip: a round icon well in the card's colour, the line beside it."""
    rows_ = []
    for i, (samples, icon) in enumerate(zip(samples_per_row, icons), start=1):
        rows_.append({"type": "frame", "name": f"{prefix}Perk{i}", "colour": theme["chip"], "alpha": 0.2,
                      "corner": PERK_H // 2, "keyline": theme["chipRim"], "keepKeyline": True,
                      "size": [0, PERK_W, 0, PERK_H], "children": [
                          {"type": "frame", "name": "PerkWell", "colour": theme["well"], "corner": 0.5,
                           "keyline": "#FFFFFF", "keepKeyline": True, "size": [0, PERK_H - 4, 0, PERK_H - 4],
                           "pos": [0, 2, 0.5, 0], "anchor": [0, 0.5], "z": 3, "children": [
                               {**ico(icon, 16, name="PerkIcon", pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5]),
                                "z": 4}]},
                          {**T("PerkText", None, PERK_W - 44, 16, font="display", align="left", samples=samples,
                               pos=[0, PERK_H + 8, 0.5, 0], anchor=[0, 0.5]), "z": 3}]})
    return frame(f"{prefix}Perks", PERK_W, 3 * PERK_H + 2 * PERK_GAP, rows_, layout=col(PERK_GAP, "start"),
                 pos=[0.5, 0, 0, PERK_Y], anchor=[0.5, 0], z=3)


def feature_card(prefix, name, colours, keyline, art, theme, behind, front, title_name, title_samples, perks,
                 sticker, button_name, price_name, price, viewport, inner, rim=()):
    """v5.2: the owner's painting is the card's background; the hero stands in a framed glass panel on it;
    `behind` effects sit under the frame (flames / blood licking out round its edges), `front` ones over its
    rim and corners, never over the text. Title in the theme's gradient (StoreFx.shimmer) over a soft glow,
    perks as themed chips, the price button on a breathing light."""
    btn = vbtn(button_name, "confirm", "M", icon="IconRobux", samples=[str(price), "OWNED", "9999"],
               text_name=price_name, w=BUY_W, pos=[0.5, 0, 1, -BUY_PAD], anchor=[0.5, 1], z=5)
    st_name, st_text = sticker
    art_node = vfx("CardArt", art, 100, [0.5, 0, 0.5, 0], w=FEAT_W, h=FEAT_H, z=0)
    art_node.update({"size": [1, 0, 1, 0], "corner": 16, "props": {**art_node["props"], "ScaleType": "Crop"}})
    art_node.pop("tint", None)   # the owner's painting in its own colours
    kids = [
        art_node,
        scrim("ArtShadeTop", None, None, hexc="#000000", start=0.35, stop=0.0, z=0, size=[1, 0, 0, 60],
              pos=[0, 0, 0, 0], corner=16),
        scrim("TextScrim", None, None, hexc=theme["scrim"], start=0.0, stop=0.92, z=1,
              size=[1, 0, 0, FEAT_H - TITLE_Y + 30], pos=[0, 0, 1, 0], anchor=[0, 1], corner=16),
        sheen(corner=18, opacity=0.1, z=1),
        *behind,
        hero_frame(f"{prefix}Frame", FF_W, FF_H, [0.5, 0, 0, FF_Y], theme, inner, viewport, rim=rim),
        *front,
        vfx("TitleGlow", "EnergyCloud", 60, [0.5, 0, 0, TITLE_Y + 15], w=250, h=52, tint=theme["glow"], alpha=0.5,
            z=2, breath=0.25, period=3.0),
        {**T(title_name, None, FEAT_W - 24, 24, font="display", samples=title_samples, pos=[0.5, 0, 0, TITLE_Y],
             anchor=[0.5, 0]), "z": 4},
        perks,
        vfx("BuyGlow", "EnergyCloud", 60, [0.5, 0, 1, -BUY_PAD - BUY_H // 2], w=BUY_W + 50, h=BUY_H + 12, tint=theme["buyGlow"], alpha=0.55, z=2,
            breath=0.3, period=2.4),
        btn,
        centred_ribbon(st_name, st_text, f"{st_name}Text", None,
                       samples=[st_text] + [x for x in ("LIMITED HERO", "ONE-TIME OFFER", "NEW HERO") if x != st_text]),
    ]
    return {"type": "panel", "name": name, "colour": colours, "keyline": keyline, "depth": 0, "corner": 18,
            "size": [0, FEAT_W, 0, FEAT_H], "children": kids}


BLOOD = {"glass": ["#2A040C", "#0A0103"], "rim": "#FF5A6A", "glow": "#C8102E", "pattern": "BgStars",
         "patternTint": "#FF3B4E", "patternAlpha": 0.88, "alpha": 0.5, "scrim": "#120206",
         "chip": ["#5A0A18", "#1E0308"], "chipRim": "#FF6B7A", "well": ["#FF4D5E", "#8A0016"],
         "buyGlow": "#FF3048"}
SUN = {"glass": ["#3A1404", "#0E0402"], "rim": "#FFC36B", "glow": "#FF7A1A", "pattern": "BgRays",
       "patternTint": "#FFB347", "patternAlpha": 0.86, "alpha": 0.5, "scrim": "#140602",
       "chip": ["#5C2408", "#1E0A02"], "chipRim": "#FFB25C", "well": ["#FFD27A", "#D9480F"],
       "buyGlow": "#FF9A2E"}


def spear(name, cx, cy, rot, w, h, tint, period):
    """A blood spear (SPIKES) pointing out of a frame corner at `rot` degrees (0 = up): its centre sits along
    that direction so its base tucks behind the corner (Rotation turns about the centre). StoreFx thrusts it
    out and draws it back along the same line (VfxThrust px)."""
    a = math.radians(rot)
    d = h / 2 - 16
    return vfx(name, "BloodSpear", w, [0, round(cx + math.sin(a) * d), 0, round(cy - math.cos(a) * d)], w=w, h=h,
               tint=tint, z=3, rot=rot, thrust=12, period=period)


def starter_card():
    """The Blood Fiend: her power is blood. Spears thrust out of the frame's corners, splashes burst behind
    them, crimson wisps flow up one edge and a slash spray the other, a crimson ring turns behind the frame and
    inside it, splatters stain two corners, and blood runs down from the rim and drips off."""
    L, R, T_, B = FF_X0, FF_X1, FF_Y, FF_Y + FF_H
    behind = [
        vfx("VfxBloodGlow", "Eclipse", 300, [0.5, 0, 0, FF_CY], tint="#B0001E", alpha=0.35, z=2, breath=0.3,
            period=3.6),
        vfx("VfxBloodRing", "BloodRing", 236, [0.5, 0, 0, FF_CY], tint="#8A0014", alpha=0.25, z=2, turn=-6),
        spear("VfxSpearTL", L + 6, T_ + 8, -42, 34, 74, "#C8102E", 2.8),
        spear("VfxSpearTR", R - 6, T_ + 8, 42, 34, 74, "#C8102E", 3.1),
        spear("VfxSpearBL", L + 4, B - 30, -118, 30, 62, "#A80C24", 3.4),
        spear("VfxSpearBR", R - 4, B - 30, 118, 30, 62, "#A80C24", 2.6),
    ]
    # v5.3: in the frame, over the glass, under the hero (frame-local): splashes bursting in two corners, wisps
    # flowing up the left side, a slash spray down the right, blood running down from the top rim and the sides
    W, H = FF_W, FF_H
    rim = [
        vfx("VfxBurstL", "BloodBlobs", 96, [0, 16, 0, 28], tint="#D3142C", alpha=0.05, z=4),
        vfx("VfxBurstR", "BloodBlobs", 88, [0, W - 16, 0, H - 26], tint="#D3142C", alpha=0.05, z=4),
        vfx("VfxWisp", "BloodWisp", 104, [0, 18, 1, 8], (0.5, 1), tint="#E01E38", alpha=0.1, z=4),
        vfx("VfxSlashSpray", "BloodCrescent", 96, [0, W - 18, 0, 74], tint="#D01530", alpha=0.05, z=4),
        *drip("VfxDrip3", 52, 0, 9, 34, 0, 5.0, 2.9, z=5),
        *drip("VfxDrip4", W - 48, 0, 10, 40, 0, 4.2, 0.8, z=5),
        *drip("VfxDrip5", 9, 14, 8, 52, 0, 4.8, 1.9, z=5),
        *drip("VfxDrip6", W - 9, 18, 8, 46, 0, 5.4, 3.6, z=5),
    ]
    front = [
        vfx("VfxSplatTL", "BloodSplat", 70, [0, L + 10, 0, T_ + 10], z=7, alpha=0.08, rot=20),
        vfx("VfxSplatBR", "BloodSplat", 58, [0, R - 8, 0, B - 8], z=7, alpha=0.08, rot=-35),
        *drip("VfxDrip1", L + 22, B - 2, 12, 34, 22, 3.6, 0.0),
        *drip("VfxDrip2", R - 26, B - 2, 10, 28, 20, 4.4, 1.7),
        *embers("VfxSpark", 6, FF_W, -(FEAT_H - FF_Y - FF_H) - 4, "#FF3B4E", size=10, rise=120),
    ]
    inner = [vfx("VfxInnerRing", "BloodRing", 150, [0.5, 0, 0.5, 0], tint="#FF2A40", alpha=0.55, z=2, turn=9)]
    perks = perk_rows("Starter", [["Blood Fiend hero", "Cosplay Star hero"], ["5 Lucky Throws", "25 Lucky Throws"],
                                  ["30 min 2x Yen", "120 min 2x Yen"]], ["IconStar", "IconLuckyThrow", "IconYen"],
                      BLOOD)
    return feature_card("Starter", "StarterPackBanner", ["#B3262E", "#3A0610"], "#FFD45C", "BgBloodChains", BLOOD,
                        behind, front, "StarterTitle", ["STARTER PACK"], perks, ("StarterSticker", "ONE-TIME OFFER"),
                        "StarterBuyButton", "StarterPrice", PRODS["StarterPack"]["Robux"], "StarterViewport", inner,
                        rim)


def limited_card():
    """The First Sun Swordsman: sun breathing. A heat glow and a turning sun ring behind the frame, a flame arc
    sweeping round it, layered flame flipbooks licking up its corners and edges, flame tongues at his feet and a
    turning flame ring behind him inside the frame, embers rising through the card."""
    behind = [
        vfx("VfxHeat", "EnergyCloud", 320, [0.5, 0, 0, FF_CY + 10], tint="#FF6A10", alpha=0.3, z=2, breath=0.3,
            period=2.2),
        vfx("VfxSunRing", "Runes", 250, [0.5, 0, 0, FF_CY], tint="#FFB347", alpha=0.3, z=2, turn=10),
        vfx("VfxFlameArc", "FlameArc", 236, [0.5, 0, 0, FF_CY], tint="#FFD27A", alpha=0.15, z=2, turn=-40),
    ]
    # v5.3: in the frame, over the glass, under the hero (frame-local): flames licking up both sides from the
    # bottom corners, a column and a wisp climbing the left and right edges
    W = FF_W
    rim = [
        vfx("VfxFireA", "FireRoar", 136, [0, 20, 1, 12], (0.5, 1), tint="#FF7A2E", alpha=0.05, z=4),
        vfx("VfxFireB", "FireLove", 128, [0, W - 20, 1, 12], (0.5, 1), tint="#FF5A1E", alpha=0.05, z=4),
        vfx("VfxFireC", "FireColumn", 112, [0, 10, 1, -44], (0.5, 1), tint="#FF9A3D", alpha=0.05, z=4),
        vfx("VfxFireD", "FireWisp", 112, [0, W - 10, 1, -54], (0.5, 1), tint="#FFB04D", alpha=0.05, z=4),
    ]
    front = [*embers("VfxSpark", 8, FF_W + 30, -(FEAT_H - FF_Y - FF_H) - 4, "#FFB04D", size=12, rise=150, seed=5)]
    inner = [
        vfx("VfxFlameRing", "FlameSwirl", 150, [0.5, 0, 0.5, 0], tint="#FF9A3D", alpha=0.35, z=2, turn=-24),
        vfx("VfxFeetFire", "FireBlast", 120, [0.5, 0, 1, 18], (0.5, 1), tint="#FF8A2E", alpha=0.15, z=5),
    ]
    perks = perk_rows("Limited", [["Earns 3x your best", "Earns 12x your best"], ["Store exclusive"],
                                  ["Not in any scroll"]], ["IconYen", "IconLock", "IconScroll"], SUN)
    lim = next(p for p in CFG["PremiumCharacters"] if p["Source"] == "Limited")
    return feature_card("Limited", "LimitedHeroBanner", ["#C2304A", "#3A0816"], "#FFB38A", "BgRedMoon", SUN,
                        behind, front, "LimitedHeroName", [lim["Name"].upper(), "SWEET-TOOTH DETECTIVE"], perks,
                        ("LimitedSticker", "LIMITED HERO"), "LimitedHeroBuy", "LimitedHeroPrice",
                        PRODS["SakuraShogun"]["Robux"], "LimitedHeroViewport", inner, rim)


# =================================================================== GAMEPASSES

PASS_W, PASS_H, PAD = 310, 186, 12
BAND_H = 38
PASS_SLOT = 94
PASS_COL_X = PAD + PASS_SLOT + PAD + 4           # the text / button column
PASS_COL_W = PASS_W - PASS_COL_X - PAD
PASS_DESC = {
    "DoubleYen": "Every hero earns double yen, forever.",
    "DoubleTraining": "2x Power from every rep, perfect tap and boost.",
    "Vip": "+15% luck on every throw and +2 hero slots.",
    "AutoThrow": "Adds AUTO to your throw pad: it throws for you.",
    "LuckyAura": "x1.5 luck on every throw, forever.",
    "BigBench": "Your bench holds 60 heroes instead of 30.",
}


def pass_card_template(name="PassCardTemplate", key="DoubleTraining", robux=149, owned=False):
    """v5.1 grid: coloured header band with the name; below it the framed icon slot (left) and one column holding
    the description (top, left-aligned, 3 lines) and the price button (bottom, the same size on every card)."""
    s = SECTION["passes"]
    if owned:
        btn = v4.state_pill("PassBuyButton", "PassPrice", ["OWNED"], "S", w=PASS_COL_W)
    else:
        btn = vbtn("PassBuyButton", "confirm", "S", icon="IconRobux", samples=[str(robux), "999", "GIFT 149"],
                   text_name="PassPrice", w=PASS_COL_W, px=20)
    btn.update({"pos": [1, -PAD, 1, -PAD], "anchor": [1, 1]})
    body_y = 8 + BAND_H + 10
    body_h = PASS_H - body_y - PAD
    icon = v4.v1.PASS_NAMES[key][1] + "Big"
    slot = icon_slot(PASS_SLOT, icon, 72, pos=[0, PAD, 0, body_y + (body_h - PASS_SLOT) // 2], z=2)
    kids = [
        v42.card_bg(s["bg"]),
        sheen(corner=16, opacity=0.14, z=1),
        header_band(PASS_W - 16, BAND_H, s["hex"], [
            {**T("PassName", None, PASS_W - 48, 22, font="display", samples=[v4.v1.PASS_NAMES[key][0], "2x Training"],
                 pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5]), "z": 4}], pos=[0.5, 0, 0, 8], anchor=[0.5, 0], z=2),
        slot,
        {**T("PassDesc", None, PASS_COL_W, 16, lines=3, align="left",
             samples=list(PASS_DESC.values())[:1] + [PASS_DESC[key]], pos=[0, PASS_COL_X, 0, body_y]), "z": 3},
        btn,
    ]
    st = centred_ribbon("Sticker", "BEST VALUE", "StickerText", 126,
                        samples=["BEST VALUE", "MOST VALUE", "GOOD VALUE", "LIMITED", "NEW!"])
    st.update({"visible": False, "mockHide": True})
    kids.append(st)
    return {"type": "panel", "name": name, "colour": s["card"], "keyline": s["keyline"], "paintable": True,
            "depth": 0, "corner": 16, "size": [0, PASS_W, 0, PASS_H], "attrs": {"PassKey": key}, "children": kids}


# =================================================================== PRODUCTS

CARD_W, CARD_H = 148, 272
PBAND_Y, PBAND_H = 16, 44
PSLOT, PSLOT_Y = 84, 16 + 44 + 8
PDESC_Y = PSLOT_Y + 84 + 8
PROD_DESC = {
    "LuckyThrow1": "x12 luck on one throw", "LuckyThrow5": "x12 luck on 5 throws",
    "LuckyThrow25": "x12 luck on 25 throws", "ServerLuck": "Server luck up for 15 min",
    "Train5m": "5 min of training Power", "Train30m": "30 min of training Power",
    "YenPack15m": "15 min of your income", "YenPack2h": "2 hours of your income",
    "YenPack12h": "12 hours of your income",
}


def product_card_template(name="ProductCardTemplate", key="LuckyThrow25", robux=149, stick=None, section="boosts"):
    """v5.1 column: header band (name, 2 lines), framed icon slot, description (2 lines, centred), price button at
    the bottom; the same rows on every card, so a row of cards lines up."""
    s = SECTION[section]
    btn = vbtn("ProductBuyButton", "confirm", "S", icon="IconRobux", samples=[str(robux), "999"],
               text_name="ProductPrice", w=CARD_W - 2 * 10, px=20, pos=[0.5, 0, 1, -10], anchor=[0.5, 1])
    kids = [
        v42.card_bg(s["bg"]),
        sheen(corner=16, opacity=0.14, z=1),
        header_band(CARD_W - 16, PBAND_H, s["hex"], [
            {**T("ProductName", None, CARD_W - 32, 16, lines=2, font="display",
                 samples=[v4.v1.PRODUCT_NAMES[key][0], "30 min Training"], pos=[0.5, 0, 0.5, 0],
                 anchor=[0.5, 0.5]), "z": 4}], pos=[0.5, 0, 0, PBAND_Y], anchor=[0.5, 0], z=2),
        icon_slot(PSLOT, v4.v1.PRODUCT_NAMES[key][1] + "Big", 60, pos=[0.5, 0, 0, PSLOT_Y], anchor=[0.5, 0], z=2),
        {**T("ProductDesc", None, CARD_W - 20, 16, lines=2, samples=[PROD_DESC[key], "Server luck up for 15 min"],
             pos=[0.5, 0, 0, PDESC_Y], anchor=[0.5, 0]), "z": 3},
        btn,
    ]
    st = centred_ribbon("Sticker", stick or "BEST VALUE", "StickerText", 124,
                        samples=["BEST VALUE", "MOST VALUE", "GOOD VALUE", "LIMITED", "NEW!"])
    if not stick:
        st.update({"visible": False, "mockHide": True})
    kids.append(st)
    return {"type": "panel", "name": name, "colour": s["card"], "keyline": s["keyline"], "paintable": True,
            "depth": 0, "corner": 16, "size": [0, CARD_W, 0, CARD_H], "attrs": {"ProductKey": key}, "children": kids}


# =================================================================== section headers

def section_header(name, text, section, w=INNER_W):
    """v5.2 (owner's review 6): the title CENTRED, no icon, no box: a rule either side in the section colour,
    fading out towards the page edges, and a small diamond at each rule's inner end."""
    hexc = SECTION[section]["hex"]
    h = 40
    tw = math.ceil(max(mp4.measure(text, 24), 0.72 * 24 * len(text))) + 8
    gap = 14
    rule_w = (w - tw) // 2 - gap - 24
    kids = [{**T(f"{name}Text", text, tw, 24, font="display", pos=[0.5, 0, 0.5, 0], anchor=[0.5, 0.5]), "z": 3}]
    for side, sign in (("L", -1), ("R", 1)):
        inner_x = w / 2 + sign * (tw / 2 + gap)
        kids.append(scrim(f"{name}Rule{side}", rule_w, 3, hexc=hexc, start=0.0 if sign < 0 else 1.0,
                          stop=1.0 if sign < 0 else 0.0, rot=0, corner=2,
                          pos=[0, round(inner_x + (0 if sign > 0 else -rule_w) + sign * 12), 0.5, 0],
                          anchor=[0, 0.5]))
        kids.append({"type": "frame", "name": f"{name}Gem{side}", "colour": [mp4.light(hexc, 0.4), hexc],
                     "corner": 2, "size": [0, 8, 0, 8], "pos": [0, round(inner_x + sign * 4), 0.5, 0],
                     "anchor": [0.5, 0.5], "rotation": 45, "overhang": True, "children": []})
    # a panel with nothing painted (no fill, no rim): the title's own container, so fit_gate judges the title
    # against the header, not the window it scrolls out of
    return {"type": "panel", "name": name, "colour": ["#000000", "#000000"], "alpha": 1, "bare": True,
            "depth": 0, "corner": 0, "size": [0, w, 0, h], "children": kids}


def grid_of(name, cards, rows_, cell, cols):
    gridl = {"type": "grid", "cell": list(cell), "gap": 14, "cols": cols}
    h = rows_ * cell[1] + (rows_ - 1) * 14
    return frame(name, INNER_W, h, cards, layout=gridl, props={"AutomaticSize": "Y"})


# =================================================================== the page

def store():
    pass_keys = [p["Key"] for p in CFG["Monetization"]["Passes"]]
    pass_cards = [sample(pass_card_template(key=k, robux=PASSES[k]["Robux"], owned=(k == "DoubleYen")), i + 1)
                  for i, k in enumerate(pass_keys)]
    boost_keys = ["LuckyThrow1", "LuckyThrow5", "LuckyThrow25", "ServerLuck", "Train5m", "Train30m"]
    boost_stick = {"LuckyThrow25": "BEST VALUE", "LuckyThrow5": "GOOD VALUE"}
    boosts = [sample(product_card_template(key=k, robux=PRODS[k]["Robux"], stick=boost_stick.get(k)), i + 1)
              for i, k in enumerate(boost_keys)]
    yen_keys = ["YenPack15m", "YenPack2h", "YenPack12h"]
    yens = [sample(product_card_template(key=k, robux=PRODS[k]["Robux"], section="yen",
                                         stick="BEST VALUE" if k == "YenPack12h" else None), i + 1)
            for i, k in enumerate(yen_keys)]
    hdr = section_header
    scroll = v4.mp3_vscroll("StoreScroll", STORE_W, BODY_H, [
        hdr("FeaturedHeader", "FEATURED", "featured"),
        frame("FeaturedSpacer", INNER_W, 8),
        frame("FeaturedRow", INNER_W, FEAT_H, [starter_card(), limited_card()], layout=row(14, "center")),
        hdr("PassesHeader", "GAMEPASSES", "passes"),
        frame("PassesSpacer", INNER_W, 8),
        grid_of("PassScroller", pass_cards, 3, (PASS_W, PASS_H), 2),
        hdr("BoostsHeader", "LUCK & BOOSTS", "boosts"),
        frame("BoostsSpacer", INNER_W, 8),
        grid_of("ProductScroller", boosts, 2, (CARD_W, CARD_H), 4),
        hdr("YenHeader", "YEN PACKS", "yen"),
        frame("YenSpacer", INNER_W, 8),
        grid_of("YenScroller", yens, 1, (CARD_W, CARD_H), 4),
    ], col(12, "start"), pad=10, pos=[1, 0, 0, 0], anchor=[1, 0])
    banner = summon_banner()
    gift = vbtn("GiftTarget", "info", "S", icon="IconGift", samples=["GIFT A FRIEND", "FOR: Builderman"],
                text_name="GiftTargetText", pos=[0, 18, 0, 16], z=4, overhang=True)
    body_w = BANNER_W + 14 + STORE_W
    return page("Store", v4.window("STORE", body_w, BODY_H, [banner, scroll], colour="pink", icon="IconStoreBig",
                                   extra=[gift]))


def install(screens):
    """Swap this file's Store (and its two templates) into a screens module's SCREENS / TEMPLATES."""
    screens.SCREENS = [store if getattr(f, "__name__", "") == "store" else f for f in screens.SCREENS]
    screens.TEMPLATES = [(f, o) for f, o in screens.TEMPLATES if o != "Store"] + [
        (pass_card_template, "Store"), (product_card_template, "Store")]
    return screens


TEMPLATES_OVERRIDE = [(f, o) for f, o in v42.TEMPLATES if o != "Store"] + [
    (pass_card_template, "Store"), (product_card_template, "Store")]


def _preview_icons():
    """Mockup only: the renderer finds the owner-texture thumbnails (assets/ui/store_v5/Vfx_<id>[_f0].png) by key,
    whatever icon map build_ui passes in. Nothing here reaches the shipped tree."""
    prev = mp.ub.draw_node
    if getattr(prev, "_store_v5", False):
        return
    folder = ROOT / "assets" / "ui" / "store_v5"

    def draw_node(img, draw, node, theme, palette, icons):
        key = node.spec.get("icon")
        if isinstance(key, str) and key.startswith("Vfx_") and key not in icons and (folder / f"{key}.png").exists():
            icons[key] = folder / f"{key}.png"
        return prev(img, draw, node, theme, palette, icons)
    draw_node._store_v5 = True
    mp.ub.draw_node = draw_node


_preview_icons()


def _scrim_hooks():
    """v5.1 `scrim` frames (scrim()): the mockup draws the transparency ramp, the emitter gives the Frame one
    UIGradient whose Transparency runs from `from` to `to` (opacities) along `rot`. Same spec, both outputs."""
    ub = mp.ub
    if getattr(ub.draw_node, "_scrim", False):
        return
    from PIL import Image, ImageDraw
    prev_draw, prev_ti = ub.draw_node, ub.to_instances

    def draw_node(img, draw, node, theme, palette, icons):
        if node.spec.get("bare"):
            return   # v5.2: a "bare" panel paints nothing (its children still draw)
        sc = node.spec.get("scrim")
        if not sc:
            return prev_draw(img, draw, node, theme, palette, icons)
        SS = ub.SS
        x, y, w, h = (v * SS for v in node.rect)
        W, H = int(w), int(h)
        if W <= 0 or H <= 0:
            return
        vertical = round(sc["rot"]) % 180 == 90
        n = H if vertical else W
        flip = round(sc["rot"]) % 360 in (180, 270)
        vals = []
        for i in range(n):
            t = i / max(1, n - 1)
            t = 1 - t if flip else t
            vals.append(int(255 * (sc["from"] + (sc["to"] - sc["from"]) * t)))
        ramp = Image.new("L", (1, n) if vertical else (n, 1))
        ramp.putdata(vals)
        alpha = ramp.resize((W, H))
        mask = Image.new("L", (W, H), 0)
        cr = node.spec.get("corner", 0) or 0
        r = cr * min(w, h) if cr <= 1 else cr * SS
        ub.rounded(ImageDraw.Draw(mask), (0, 0, W - 1, H - 1), r, fill=255)
        alpha = Image.composite(alpha, Image.new("L", (W, H), 0), mask)
        layer = Image.new("RGBA", (W, H), tuple(ub.hex_rgb(node.spec["colour"][0])) + (255,))
        layer.putalpha(alpha)
        img.alpha_composite(layer, (int(x), int(y)))

    def to_instances(spec, theme, palette, counter=None):
        made = prev_ti(spec, theme, palette, counter)
        if spec.get("bare") and made:
            # v5.2: a "bare" panel: no fill, no rim (drop the UIStrokes of the panel and of its Face)
            def unrim(inst, depth=0):
                inst["children"] = [c for c in inst.get("children", []) if c.get("className") != "UIStroke"]
                if depth == 0:
                    for c in inst["children"]:
                        if c.get("name") == "Face":
                            unrim(c, 1)
            unrim(made[0])
        sc = spec.get("scrim")
        if sc and made:
            top = made[0]
            kids = [c for c in top.get("children", []) if c.get("className") not in ("UIGradient", "UIStroke")]
            props = top.setdefault("properties", {})
            props["BackgroundColor3"] = ub.col3(ub.hex_rgb(spec["colour"][0]))
            props["BackgroundTransparency"] = 0
            props["BorderSizePixel"] = 0
            kids.append(ub.instance("Fade", "UIGradient", {"Rotation": sc["rot"], "Transparency": {"NumberSequence": {
                "keypoints": [{"time": 0, "value": round(1 - sc["from"], 3), "envelope": 0},
                              {"time": 1, "value": round(1 - sc["to"], 3), "envelope": 0}]}}}))
            top["children"] = kids
        return made

    draw_node._scrim = True
    ub.draw_node = draw_node
    ub.to_instances = to_instances


_scrim_hooks()
