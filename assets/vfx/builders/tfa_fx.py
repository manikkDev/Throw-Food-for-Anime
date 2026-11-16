"""Shared helpers for this game's VFX builders (Throw Food for Anime).

Every builder in this folder writes assets/vfx/effects/<Name>.json: a roblox-vfx sim definition
(instances + timeline, sim units, CFrame = [x, y, z, rxDeg, ryDeg, rzDeg]) plus a "game" block the
runtime (src/client/Fx/VfxKit.luau) and the template builder (work/vfx/build_templates.luau) read:

  "game": {"loop": bool, "attach": "point"|"part"|"root", "screen": bool}

Rules the runtime relies on:
- every visible thing hangs off an invisible carrier Part (Transparency 1); carrier CFrames are
  relative to the effect origin; for attach part/root the carriers are welded to the target
- one-shot emitters: Rate 0 + "emit" events, or Enabled false + "enable" events with a duration
- loop emitters: Enabled true with a Rate (they stream until stop)
- events flagged "sim": True are staging for the sim only (moving the carrier like the food does);
  the template packer drops them
- "attrs" on an instance become Instance attributes: Tint (recolour with opts.tint), LowKeep (the
  one layer an aura keeps in low detail)
"""
import colorsys
import json
import sys
from pathlib import Path

SKILL_SIM = Path.home() / ".claude" / "skills" / "roblox-vfx" / "sim"
VFX = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(SKILL_SIM / "effects"))
from roblox_units import to_roblox_units  # noqa: E402

RARITY = {  # design/game.json config.Rarities[].Color
    "Common": "B8C0CC", "Uncommon": "4ADE80", "Rare": "38BDF8", "Epic": "A855F7",
    "Legendary": "FACC15", "Mythic": "FB3B6B", "Secret": "111111",
}
ORDER = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret"]
WHITE = (1, 1, 1)


def hexc(h):
    h = h.lstrip("#")
    return tuple(round(int(h[i:i + 2], 16) / 255, 4) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t, 4) for i in range(3))


def hsv(h, s, v):
    return tuple(round(x, 4) for x in colorsys.hsv_to_rgb(h % 1, s, v))


def NR(a, b=None):
    return {"NumberRange": [a, a if b is None else b]}


def NS(*k):
    return {"NumberSequence": [list(p) for p in k]}


def CS(*k):
    if len(k) == 1 and not isinstance(k[0][0], (int, float)):
        k = ((0, k[0]), (1, k[0]))
    if len(k) == 1:
        k = ((0, k[0]), (1, k[0]))
    return {"ColorSequence": [[t, list(c)] for t, c in k]}


def C3(c):
    return {"Color3": list(c)}


def E(e):
    return {"Enum": e}


def V3(x, y, z):
    return {"Vector3": [x, y, z]}


def V2(x, y):
    return {"Vector2": [x, y]}


def tex(name):
    """'tfa/clover_cel' -> this game's texture; anything else -> the skill library (sim:lib/...)."""
    if name.startswith("tfa/"):
        p = VFX / "textures" / (name[4:] + ".png")
        sid = "sim:" + name
    else:
        p = SKILL_SIM / "textures" / "lib" / (name + ".png")
        sid = "sim:lib/" + name
    if not p.exists():
        raise FileNotFoundError(f"texture missing: {name} ({p})")
    return sid


FB4 = {"FlipbookLayout": E("ParticleFlipbookLayout.Grid4x4"), "FlipbookMode": E("ParticleFlipbookMode.OneShot"), "FlipbookBlendFrames": False}
FB4LOOP = {"FlipbookLayout": E("ParticleFlipbookLayout.Grid4x4"), "FlipbookMode": E("ParticleFlipbookMode.Loop"), "FlipbookBlendFrames": False}
FLAT = {"Orientation": E("ParticleOrientation.VelocityPerpendicular"), "EmissionDirection": E("NormalId.Top"), "Speed": NR(0.01)}
STREAK = {"Orientation": E("ParticleOrientation.VelocityParallel")}


def pe(name, attrs=None, **p):
    d = {"class": "ParticleEmitter", "name": name, "props": dict({"Rate": 0, "LightInfluence": 0}, **p)}
    if attrs:
        d["attrs"] = attrs
    return d


def beam(name, a0, a1, attrs=None, **p):
    d = {"class": "Beam", "name": name, "props": dict({"Attachment0": {"Ref": a0}, "Attachment1": {"Ref": a1}, "FaceCamera": True,
                                                       "Segments": 10, "LightInfluence": 0}, **p)}
    if attrs:
        d["attrs"] = attrs
    return d


def trail(name, a0, a1, attrs=None, **p):
    d = {"class": "Trail", "name": name, "props": dict({"Attachment0": {"Ref": a0}, "Attachment1": {"Ref": a1}, "FaceCamera": True,
                                                        "LightInfluence": 0}, **p)}
    if attrs:
        d["attrs"] = attrs
    return d


def att(name, cf=(0, 0, 0, 0, 0, 0), children=()):
    return {"class": "Attachment", "name": name, "CFrame": list(cf), "children": list(children)}


def carrier(name, cf=(0, 0, 0, 0, 0, 0), children=(), size=(1, 1, 1), **extra):
    d = {"class": "Part", "name": name, "CFrame": list(cf), "Size": list(size), "Transparency": 1, "children": list(children)}
    d.update(extra)
    return d


def light(name, cf, color, rng=14):
    return carrier(name, cf, [{"class": "PointLight", "name": "L", "props": {"Brightness": 0, "Range": rng, "Color": C3(color)}}])


class TL(list):
    def at(self, t, **e):
        e["t"] = round(max(0.0, t), 4)
        self.append(e)
        return e


def write(d, strip=None):
    """Write assets/vfx/effects/<name>.json in Roblox units. strip = times for the judging strip."""
    if strip:
        d["strip"] = [round(x, 3) for x in strip]
    d.setdefault("seed", 7)
    d.setdefault("stage", {"ground": "light", "dummy": True})
    out = VFX / "effects" / f"{d['name']}.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(to_roblox_units(d), indent=1))
    print("wrote", out.name)
    return out
