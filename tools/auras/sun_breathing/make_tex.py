#!/usr/bin/env python3
"""SunBreathing (Yoriichi Tsugikuni, "First Sun Swordsman", Premium) textures, v3: the SUN SEAL base.

    python tools/auras/sun_breathing/make_tex.py [names...]   -> assets/auras/sun_breathing/*.png (+ _sheet.jpg)

History: v1 (flat ukiyo-e cel fire) and v2 (the Solar Flare re-lit with extra layers on his body) were both
rejected: the owner wants the ORIGINAL Solar Flare pack aura on his body, untouched, and a perfect BASE under
him. So v3 draws only the base. The seal is PRE-COLOURED (shown on a SurfaceGui, not additive), so it keeps
its colours on any floor (v2's additive ground went white on the pale preview stand).

  seal_outer.png   the outer seal: a double gold rim, a band of brush kanji 日の呼吸 (Sun Breathing) four times
                   round with sun dots between, and the 13th form: twelve curling flame commas chasing round a
                   ring, crimson at heart, orange, a gold edge line with a warm glow; open in the middle
  seal_inner.png   the hanafuda sun (his earrings' sun): a crimson disc with a gold rim and a crown of sixteen
                   gold rays, warm glow; turns the other way inside the outer seal
  ember.png        a hot spark: white core + halo (tinted by Color)
  flame_lick_4x4   16-frame ONE-SHOT flame lick for the fire ring on the seal's rim: born low, licks up with a
                   white-hot churning core and a sharp wavering tip, a side tongue splits off, the tip tears off,
                   it burns away into wisps (white + alpha; the emitter's ramp colours it)
  lib_*.png        copies of the roblox-vfx skill's generated library (ours too): ripple_fb_glow_02_4x4 (the
                   breath pulse), flare_glow_04 (the glint racing round the rim)

Reuses EmperorThorns's helpers (tools/auras/emperor_thorns/make_tex.py).
"""
from __future__ import annotations

import importlib.util
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets" / "auras" / "sun_breathing"
_spec = importlib.util.spec_from_file_location("et", ROOT / "tools" / "auras" / "emperor_thorns" / "make_tex.py")
K = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(K)
smooth, over, down, grid, to_img = K.smooth, K.over, K.down, K.grid, K.to_img
SS = K.SS
FONT = Path("C:/Windows/Fonts/YuGothB.ttc")

GOLD = np.array([255, 214, 110], float)
PALE = np.array([255, 244, 205], float)
ORANGE = np.array([255, 122, 26], float)
RED = np.array([226, 52, 18], float)
CRIMSON = np.array([168, 24, 12], float)
DEEP = np.array([84, 10, 6], float)


def mix(c0, c1, t):
    return K.mix(c0, c1, t)


def layer(alpha, colour):
    """A flat-colour RGBA layer from an alpha map 0..1."""
    out = np.zeros(alpha.shape + (4,))
    out[..., :3] = colour
    out[..., 3] = np.clip(alpha, 0, 1) * 255
    return out


def glow_of(mask, radius_px, strength, colour):
    g = ndimage.gaussian_filter(mask.astype(float), radius_px)
    return layer(np.clip(g * strength, 0, 1), colour)


def line_ring(x, y, r, w):
    return np.abs(np.sqrt(x * x + y * y) - r) < w


# ---------------------------------------------------------------- the curling flame comma
def stroke(draw, pts, widths, fill=255):
    pts = np.asarray(pts, float)
    for i in range(len(pts) - 1):
        p0, p1 = pts[i], pts[i + 1]
        w0, w1 = widths[i], widths[i + 1]
        d = p1 - p0
        L = np.hypot(*d) + 1e-9
        nx, ny = -d[1] / L, d[0] / L
        draw.polygon([(p0[0] + nx * w0, p0[1] + ny * w0), (p1[0] + nx * w1, p1[1] + ny * w1),
                      (p1[0] - nx * w1, p1[1] - ny * w1), (p0[0] - nx * w0, p0[1] - ny * w0)], fill=fill)
        draw.ellipse([p1[0] - w1, p1[1] - w1, p1[0] + w1, p1[1] + w1], fill=fill)
    w = widths[0]
    draw.ellipse([pts[0][0] - w, pts[0][1] - w, pts[0][0] + w, pts[0][1] + w], fill=fill)


def curl_tongue(height, width, lean, curl_r, n=70):
    """Centreline + widths of a flame tongue rising from (0,0) (px, y down), its tip curling over."""
    pts, ws = [], []
    rise = int(n * 0.68)
    for i in range(rise):
        t = i / (rise - 1)
        pts.append((lean * t ** 2 + math.sin(t * math.pi) * width * 0.25, -height * t))
        ws.append(width * (1 - 0.72 * t))
    cx, cy = pts[-1][0] + curl_r, pts[-1][1]
    for i in range(1, n - rise + 1):
        t = i / (n - rise)
        a = math.pi + t * math.pi * 1.4
        r = curl_r * (1 - 0.55 * t)
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
        ws.append(width * 0.28 * (1 - 0.85 * t) + 0.6)
    return pts, ws


def comma_mask(n, cx, cy, ang, size):
    img = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(img)
    pts, ws = curl_tongue(size, size * 0.34, size * 0.1, size * 0.17)
    c, s = math.cos(ang), math.sin(ang)
    out = []
    for px, py in pts:
        fx, sx = -py, px
        out.append((cx + fx * c - sx * s, cy + fx * s + sx * c))
    stroke(d, out, ws)
    return np.asarray(img, float) / 255 > 0.5


# ---------------------------------------------------------------- the seal
def seal_outer(size=1024):
    n = size * SS
    x, y = grid(n)
    r = np.sqrt(x * x + y * y)
    out = np.zeros((n, n, 4))
    px = n / 2  # px per unit radius

    # a faint warm floor inside the seal (so it sits on any colour)
    out = over(out, layer(smooth(0.99, 0.9, r) * 0.22, DEEP))

    # kanji band: a dark crimson band between two gold rings, the glyphs gold
    band = (r > 0.80) & (r < 0.945)
    out = over(out, layer(band * 0.55, mix(DEEP, CRIMSON, 0.35)))
    glyphs = Image.new("L", (n, n), 0)
    font = ImageFont.truetype(str(FONT), int(n * 0.062))
    text = "日の呼吸"
    slots = 4 * (len(text) + 1)
    for k in range(slots):
        a = math.pi / 2 - k / slots * 2 * math.pi  # clockwise from the top
        rr = 0.872 * px
        cx, cy = n / 2 + rr * math.cos(a), n / 2 - rr * math.sin(a)
        i = k % (len(text) + 1)
        tile = Image.new("L", (int(n * 0.1), int(n * 0.1)), 0)
        td = ImageDraw.Draw(tile)
        if i < len(text):
            td.text((tile.width / 2, tile.height / 2), text[i], font=font, fill=255, anchor="mm")
        else:  # a sun dot between the words
            rd = tile.width * 0.12
            td.ellipse([tile.width / 2 - rd, tile.height / 2 - rd, tile.width / 2 + rd, tile.height / 2 + rd], fill=255)
        tile = tile.rotate(math.degrees(a) - 90, resample=Image.BICUBIC)  # the glyph's up points outward
        glyphs.paste(tile, (int(cx - tile.width / 2), int(cy - tile.height / 2)), tile)
    gm = np.asarray(glyphs, float) / 255
    out = over(out, glow_of(gm > 0.5, 5 * SS, 1.4, ORANGE))
    out = over(out, layer(gm, GOLD))
    for rr, w in ((0.975, 0.006), (0.955, 0.0035), (0.945, 0.004), (0.80, 0.004)):
        m = line_ring(x, y, rr, w)
        out = over(out, glow_of(m, 4 * SS, 2.0, ORANGE))
        out = over(out, layer(m.astype(float), GOLD))

    # the 13th form: twelve flame commas chasing round
    commas = np.zeros((n, n), bool)
    ringR = 0.61
    for i in range(12):
        a = i / 12 * 2 * math.pi
        cx = (1 + ringR * math.cos(a)) / 2 * n
        cy = (1 - ringR * math.sin(a)) / 2 * n
        commas |= comma_mask(n, cx, cy, -a - math.pi / 2, n * 0.145)
    din = ndimage.distance_transform_edt(commas)
    fill = mix(CRIMSON, RED, smooth(2 * SS, 10 * SS, din))
    fill = mix(fill, ORANGE, smooth(10 * SS, 22 * SS, din) * 0.8)
    body = np.zeros((n, n, 4))
    body[..., :3] = fill
    body[..., 3] = commas * 0.82 * 255
    out = over(out, glow_of(commas, 10 * SS, 1.2, ORANGE))
    out = over(out, body)
    edge = commas & (din < 2.6 * SS)
    out = over(out, glow_of(edge, 3 * SS, 1.6, GOLD))
    out = over(out, layer(edge.astype(float), PALE))
    # inner ring that holds the sun (the inner layer sits inside it)
    m = line_ring(x, y, 0.42, 0.005)
    out = over(out, glow_of(m, 4 * SS, 2.0, ORANGE))
    out = over(out, layer(m.astype(float), GOLD))
    return to_img(down(out, SS))


def seal_inner(size=512):
    n = size * SS
    x, y = grid(n)
    r = np.sqrt(x * x + y * y)
    th = np.arctan2(y, x)
    out = np.zeros((n, n, 4))
    out = over(out, layer(np.clip(1 - r, 0, 1) ** 1.5 * 0.45, ORANGE))  # glow pool
    # crown of 16 gold rays, alternating long / short
    N = 16
    ph = (th / (2 * math.pi) * N) % 1.0
    k = np.floor((th / (2 * math.pi) * N) % N).astype(int)
    tip = np.where(k % 2 == 0, 0.96, 0.8)
    r0 = 0.6
    half = 0.5 * (1 - (r - r0) / (tip - r0))
    rays = (r > r0) & (r < tip) & (np.abs(ph - 0.5) < half * 0.85)
    rdin = ndimage.distance_transform_edt(rays)
    rcol = mix(GOLD, ORANGE, smooth(r0, 0.95, r))
    rcol = np.where(((ph - 0.5) < 0)[..., None], mix(rcol, PALE, 0.4), rcol)
    rcol = np.where((rdin < 1.6 * SS)[..., None], mix(rcol, CRIMSON, 0.6), rcol)
    rl = np.zeros((n, n, 4))
    rl[..., :3] = rcol
    rl[..., 3] = rays * 255
    out = over(out, glow_of(rays, 6 * SS, 1.3, ORANGE))
    out = over(out, rl)
    # the hanafuda sun disc
    R = 0.5
    disc = r < R
    t = r / R
    dcol = mix(RED, CRIMSON, smooth(0.2, 1.0, t))
    dcol = mix(dcol, mix(ORANGE, RED, 0.3), (1 - smooth(0.0, 0.55, t)) * 0.5)  # warm heart
    dl = np.zeros((n, n, 4))
    dl[..., :3] = dcol
    dl[..., 3] = disc * 255
    out = over(out, dl)
    rim = np.abs(r - R) < 0.022
    out = over(out, glow_of(rim, 5 * SS, 1.8, ORANGE))
    out = over(out, layer(rim.astype(float), GOLD))
    return to_img(down(out, SS))


def ember(size=64):
    x, y = grid(size)
    d = np.sqrt(x * x + y * y)
    a = np.clip(np.clip(1 - d / 0.3, 0, 1) ** 1.2 + np.clip(1 - d, 0, 1) ** 3 * 0.45, 0, 1)
    rgba = np.zeros((size, size, 4))
    rgba[..., :3] = 255
    rgba[..., 3] = a * 255
    return to_img(rgba)


def _fbm(shape, scales, seed):
    """Sum of gaussian-filtered noises, -1..1, periodic."""
    out = np.zeros(shape)
    wsum = 0.0
    for i, s in enumerate(scales):
        w = 1.0 / (i + 1)
        n = np.random.default_rng(seed + i).standard_normal(shape)
        f = ndimage.gaussian_filter(n, s, mode="wrap")
        out += w * f / (np.abs(f).max() + 1e-9)
        wsum += w
    return out / wsum


def flame_lick(frame=256):
    """16-frame ONE-SHOT flame lick, white + alpha (the emitter's ramp colours it, drawn additive):
    born low and narrow (0-3), licks up to full height with a white-hot core and noise-carved edges (4-8),
    its tip tears off and rises on its own (8-11), the whole tongue thins and burns away into wisps (11-15).
    The noise scrolls upward through the frames, so the inside churns like a real flame."""
    n = frame * SS
    xs = (np.arange(n) + 0.5) / n * 2 - 1
    vs = 1 - (np.arange(n) + 0.5) / n  # 0 bottom .. 1 top
    U, V = np.meshgrid(xs, vs)
    tall = n * 3
    warp_n = _fbm((tall, n), [22 * SS, 9 * SS], 501)
    detail_n = _fbm((tall, n), [7 * SS, 3 * SS], 511)
    erode_n = _fbm((n, n), [6 * SS, 2.5 * SS], 521)
    frames = []
    for f in range(16):
        t = f / 15
        H = 0.34 + 0.6 * smooth(0.0, 0.45, t)  # the tip's height
        off = int(f * n * 0.11)  # the noise rises with the flame
        rows = (np.arange(n)[::-1] * 1 + off) % tall
        warp = warp_n[rows][:, :]
        detail = detail_n[rows][:, :]
        # sway grows with height; a slight lean that changes over the life
        sway = (0.2 * warp + 0.05 * math.sin(t * 5.0)) * V ** 1.1
        u = U - sway
        hv = np.clip(V / H, 0, 1.2)
        # a flame's profile: round at the base, widest low down, a long sharp tip (v1 was a trapezoid)
        prof = np.clip(hv / 0.22, 0, 1) ** 0.5 * np.clip(1 - hv, 0, 1) ** 1.25
        width = 0.42 * prof * (1 - 0.3 * smooth(0.5, 1.0, t))
        d = width - np.abs(u) + 0.12 * detail * (0.25 + hv) * smooth(0.0, 0.04, width)
        # a second, shorter tongue splitting off one side mid-life
        side = 1 if (f % 2 == 0) else -1
        hv2 = np.clip(V / (H * 0.62), 0, 1.2)
        prof2 = np.clip(hv2 / 0.3, 0, 1) ** 0.5 * np.clip(1 - hv2, 0, 1) ** 1.4
        u2 = u - side * (0.1 + 0.12 * V)
        d2 = 0.2 * prof2 - np.abs(u2) + 0.1 * detail * hv2
        d = np.maximum(d, d2 - (1 - smooth(0.2, 0.45, t)))  # (an inactive tongue sinks below 0, never to 0)
        dens = smooth(-0.015, 0.05, d) * smooth(0.0, 0.015, width + 0.2 * prof2)  # no threads past the tip
        # the tip tears off: a gap opens at 60 % of the height and the piece above rises
        tear = smooth(0.48, 0.68, t)
        gap_v = H * (0.58 + 0.25 * t)
        dens *= 1 - tear * np.exp(-(((V - gap_v) / (0.035 + 0.02 * t)) ** 2)) * smooth(0.0, 0.03, d + 0.02)
        # burning away: holes eat in from the edges, then everything
        burn = smooth(0.55, 1.0, t)
        dens *= smooth(burn * 0.95 - 0.1, burn * 0.95 + 0.12, (erode_n + 1) / 2 + d * 2.0)
        dens *= smooth(0.0, 0.14, V)  # the base melts into the floor glow (no hard cut)
        # intensity: a white-hot core low in the flame, churning, dimmer edges and tips
        core = smooth(0.02, 0.14, d) * np.clip(1.2 - hv, 0, 1)
        inten = np.clip(0.42 + 0.45 * core + 0.18 * detail, 0.25, 1)
        halo = ndimage.gaussian_filter(dens, 5 * SS) * 0.35
        a = np.clip(dens + halo * (1 - dens), 0, 1)
        g = np.where(dens > 0.02, inten, 0.45)
        rgba = np.zeros((n, n, 4))
        rgba[..., :3] = (g * 255)[..., None]
        rgba[..., 3] = a * 255
        frames.append(to_img(down(rgba, SS)))
    sheet = Image.new("RGBA", (frame * 4, frame * 4), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.paste(fr, ((i % 4) * frame, (i // 4) * frame))
    return sheet


LIB = Path.home() / ".claude" / "skills" / "roblox-vfx" / "sim" / "textures" / "lib"
LIB_PICKS = {
    "lib_ripple_fb_glow_02_4x4": "flipbooks/shockwaves/ripple_fb_glow_02_4x4",
    "lib_flare_glow_04": "sprites/flares/flare_glow_04",
}


def contact(files):
    tiles = []
    for name, im in files.items():
        t = im.copy()
        t.thumbnail((420, 420))
        for bg in ((18, 20, 34), (205, 196, 220)):
            b = Image.new("RGB", (430, 430), bg)
            b.paste(t, ((430 - t.width) // 2, (430 - t.height) // 2), t)
            ImageDraw.Draw(b).text((6, 4), name, fill=(255, 80, 80))
            tiles.append(b)
    s = Image.new("RGB", (430 * 4, 430 * ((len(tiles) + 3) // 4)))
    for i, t in enumerate(tiles):
        s.paste(t, ((i % 4) * 430, (i // 4) * 430))
    return s


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    only = set(sys.argv[1:])
    makers = {"seal_outer": seal_outer, "seal_inner": seal_inner, "ember": ember, "flame_lick_4x4": flame_lick}
    for name, rel in LIB_PICKS.items():
        makers[name] = lambda rel=rel: Image.open(LIB / (rel + ".png")).convert("RGBA")
    files = {}
    for k, mk in makers.items():
        p = OUT / f"{k}.png"
        if only and k not in only:
            if p.exists():
                files[k] = Image.open(p).convert("RGBA")
            continue
        files[k] = mk()
        files[k].save(p)
        print("wrote", k, files[k].size)
    contact({k: v for k, v in files.items() if k.startswith("seal")}).save(OUT / "_sheet.jpg", quality=90)
    print("wrote _sheet.jpg")


if __name__ == "__main__":
    main()
