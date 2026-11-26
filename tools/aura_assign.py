#!/usr/bin/env python3
"""Aura assignment v2 (owner's naming pass, 2026-11-25): a PREVIEW, not wired into the game.

    python tools/aura_assign.py read      read the owner's renames from Studio (both aura displays)
    python tools/aura_assign.py plan      write design/aura_assignments.json from the renames
    python tools/aura_assign.py build     convert the auras + build Workspace.AuraAssignPreview
    python tools/aura_assign.py all       read + plan + build

The owner renamed aura stands to REAL character names, in Workspace.AuraShowcase (converted auras,
key = attr AuraKey) and Workspace.AuraPackBrowser (raw pack units, attrs Pack/Unit; a stand's place in
the grid gives the unit's index in ServerStorage.ImportedVfx.AuraPacksAll). Rules (owner):
  * Common and Uncommon heroes wear no aura.
  * Every Rare hero wears the owner's Rare aura ("All Rare Characters" stand, JackpotGreen) with a WHITE copy of its
    texture (RARE_TEXTURE), tinted to the hero's colour (RARE_COLOURS).
  * Epic and up: the aura the owner named the hero on; if none, the aura the hero already wore under
    its nickname (an unrenamed showcase stand); if neither, a pick that suits the character (PICKS).
Stands still named after a nickname or an aura are not the owner's naming and are ignored.
Nothing here touches design/auras.json, Auras.luau or ReplicatedStorage.Assets.Auras: the preview's
converted pack auras live in ServerStorage.AuraPreview, and the preview platform is dev only.
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / "work" / "aura_assign"
OUT = ROOT / "design" / "aura_assignments.json"
LIST = ROOT / "design" / "characters" / "HERO_LIST_BY_RARITY.md"
GAME = ROOT / "design" / "game.json"
AURAS = ROOT / "design" / "auras.json"
CONVERT = ROOT / "tools" / "studio" / "build_auras.luau"
BUILDER = ROOT / "tools" / "studio" / "build_aura_preview.luau"
MCP = Path.home() / ".claude" / "skills" / "create-roblox-game" / "scripts" / "studio_mcp.py"

RARE_STAND = "All Rare Characters"
# spelling in the owner's names -> the roster's character name
ALIAS = {"shiragaki": "Shigaraki", "endeaver": "Endeavor", "cifer": "Ulquiorra"}
# words on a stand that are not a character (the stand's old aura name left in)
NOT_A_NAME = {"atomic"}
# a hero named on two stands: the one kept (by the stand's aura, "S:<key>" or "P:<pack index>")
TIEBREAK = {
    "legendary_berserker": "P:32",  # Broly: Green power (his aura is green)
    "hawkeye_swordsman": "P:81",  # Mihawk: NANO, his own stand
    "limitless_teacher": "P:82",  # Gojo: Crimson Moon (the owner renamed it to Gojo, 2026-11-25)
    "demon_lord_heir": "P:89",  # Makima: Hellzone Champion
    "blade_captain": "P:77",  # Levi: Midnight Blues, his own stand
    "hollow_bat": "S:TorsoBlaze",  # Ulquiorra: "Cifer" (Ulquiorra Cifer) over the shared red outline
}
# per-hero staging: effects dropped to the soles (by attachment/part name) and a glowing floor sigil under the hero
STAGING = {
    # Mahoraga (Wheel Guardian): built from his lore, compact. The EIGHT-HANDLED WHEEL over his head (rendered gold metal)
    # turning slowly (rotSpeed 11.25 with a new particle every 4 s = exactly one spoke, so the two live copies always
    # coincide); a white-gold ADAPTATION pulse ringing off it every few seconds (the clank of a turn); the TEN SHADOWS
    # pool he rises from as an unlit ink floor (owner: no flames coming off him, so the cursed flames went); a few
    # white-gold POSITIVE-energy motes (the Sword of Extermination). Textures: work/mahoraga/mahoraga_textures.py.
    # v2 (owner: "add a cool aura, not the same basic flame thingy"): an ADAPTATION FIELD, no flames
    # (work/mahoraga/mahoraga_v2.py). Three gyroscope ORBIT RINGS round his body, each a comet (white-hot head, gold tail)
    # in its own tilted plane (`tilt`), spinning so the head ORBITS him; each ring's spin x its spawn interval = 360, so
    # the two live copies coincide and one comet shows. Ring B is flipped (pitch 180-) so it runs the other way. A line-art
    # WHEEL SIGIL turns on the shadow pool (15 deg/s x 3 s = 45, its symmetry); a gold SHOCKWAVE rolls out along the floor
    # with the wheel's pulse; an updraft of thin LIGHT STREAKS (and a few ink-black ones) rises round him.
    "wheel_guardian": {
        "noBase": True,
        "floor": {"core": "rbxassetid://100202570249582", "glow": "rbxassetid://100202570249582", "size": 7,
                  "coreColour": "FFFFFF", "glowColour": "FFFFFF", "brightness": 1, "glowTransparency": 1,
                  "pulse": False, "lit": True},
        "fx": [
            {"name": "DharmaWheel", "texture": "rbxassetid://101199162873719", "shape": "Box", "style": "Volume",
             "part": [0.1, 0.1, 0.1], "y": 6.2, "offset": [0, -0.45], "rate": 0.25, "life": [8, 8], "speed": [0, 0],
             "size": [[0, 2.9], [1, 2.9]], "transparency": [[0, 1], [0.12, 0.1], [0.88, 0.1], [1, 1]],
             "colour": [[0, "FFFFFF"], [1, "FFFFFF"]], "rotation": [0, 0], "rotSpeed": [11.25, 11.25],
             "brightness": 1.6, "lightEmission": 0.4, "zOffset": -1, "locked": True,
             "light": "FFD27A", "lightRange": 7, "lightBrightness": 0.8},
            {"name": "AdaptPulse", "texture": "rbxassetid://137368306775336", "shape": "Box", "style": "Volume",
             "part": [0.1, 0.1, 0.1], "y": 6.2, "offset": [0, -0.4], "rate": 0.35, "life": [0.9, 0.9], "speed": [0, 0],
             "size": [[0, 1.6], [1, 4.2]], "transparency": [[0, 0.1], [0.4, 0.45], [1, 1]],
             "colour": [[0, "FFF6DC"], [1, "FFCF70"]], "rotation": [0, 0],
             "brightness": 2, "lightEmission": 1, "zOffset": -0.5, "locked": True},
            {"name": "OrbitA", "texture": "rbxassetid://136104383504235", "shape": "Box", "part": [0.1, 0.1, 0.1],
             "y": 3.7, "tilt": [18, 0, 0], "orient": "VelocityPerpendicular", "dir": "Top", "rate": 1 / 3,
             "life": [6, 6], "speed": [0.01, 0.01], "size": [[0, 3.0], [1, 3.0]],
             "transparency": [[0, 1], [0.1, 0], [0.9, 0], [1, 1]], "colour": [[0, "FFFFFF"], [1, "FFFFFF"]],
             "rotation": [0, 0], "rotSpeed": [120, 120], "brightness": 2, "lightEmission": 1, "locked": True},
            {"name": "OrbitB", "texture": "rbxassetid://136104383504235", "shape": "Box", "part": [0.1, 0.1, 0.1],
             "y": 2.6, "tilt": [158, 0, 50], "orient": "VelocityPerpendicular", "dir": "Top", "rate": 0.25,
             "life": [8, 8], "speed": [0.01, 0.01], "size": [[0, 3.2], [1, 3.2]],
             "transparency": [[0, 1], [0.1, 0], [0.9, 0], [1, 1]], "colour": [[0, "FFFFFF"], [1, "FFFFFF"]],
             "rotation": [0, 0], "rotSpeed": [90, 90], "brightness": 2, "lightEmission": 1, "locked": True},
            {"name": "OrbitC", "texture": "rbxassetid://136104383504235", "shape": "Box", "part": [0.1, 0.1, 0.1],
             "y": 3.1, "tilt": [32, 0, -65], "orient": "VelocityPerpendicular", "dir": "Top", "rate": 0.2,
             "life": [10, 10], "speed": [0.01, 0.01], "size": [[0, 3.5], [1, 3.5]],
             "transparency": [[0, 1], [0.1, 0.25], [0.9, 0.25], [1, 1]], "colour": [[0, "FFFFFF"], [1, "FFFFFF"]],
             "rotation": [0, 0], "rotSpeed": [72, 72], "brightness": 1.6, "lightEmission": 1, "locked": True},
            {"name": "WheelSigil", "texture": "rbxassetid://98377888436913", "shape": "Box", "part": [0.1, 0.1, 0.1],
             "y": 0.15, "orient": "VelocityPerpendicular", "dir": "Top", "rate": 1 / 3, "life": [6, 6],
             "speed": [0.01, 0.01], "size": [[0, 2.9], [1, 2.9]], "transparency": [[0, 1], [0.15, 0.15], [0.85, 0.15], [1, 1]],
             "colour": [[0, "FFFFFF"], [1, "FFFFFF"]], "rotation": [0, 0], "rotSpeed": [15, 15],
             "brightness": 1.5, "lightEmission": 1, "locked": True},
            {"name": "Shockwave", "texture": "rbxassetid://137368306775336", "shape": "Box", "part": [0.1, 0.1, 0.1],
             "y": 0.2, "orient": "VelocityPerpendicular", "dir": "Top", "rate": 0.35, "life": [0.9, 0.9],
             "speed": [0.01, 0.01], "size": [[0, 1.3], [1, 4.0]], "transparency": [[0, 0.1], [0.5, 0.5], [1, 1]],
             "colour": [[0, "FFF6DC"], [1, "FFCF70"]], "rotation": [0, 0], "brightness": 2, "lightEmission": 1,
             "locked": True},
            {"name": "LightStreaks", "texture": "rbxassetid://120599533714425", "shape": "Cylinder", "style": "Surface",
             "part": [0.3, 5.0, 3.8], "y": 0.4, "orient": "FacingCameraWorldUp", "rate": 18, "life": [0.45, 0.7],
             "speed": [0.2, 0.4], "size": [[0, 1.2], [0.5, 1.7], [1, 1.4]], "transparency": [[0, 1], [0.2, 0.1], [1, 1]],
             "colour": [[0, "FFF3CF"], [1, "FFC45A"]], "rotation": [0, 0], "accel": [0, 13, 0],
             "brightness": 2, "lightEmission": 1},
            {"name": "InkStreaks", "texture": "rbxassetid://120599533714425", "shape": "Cylinder", "style": "Surface",
             "part": [0.3, 4.6, 3.4], "y": 0.4, "orient": "FacingCameraWorldUp", "rate": 6, "life": [0.5, 0.75],
             "speed": [0.2, 0.4], "size": [[0, 1.2], [0.5, 1.8], [1, 1.4]], "transparency": [[0, 1], [0.2, 0.2], [1, 1]],
             "colour": [[0, "120A1E"], [1, "05030A"]], "rotation": [0, 0], "accel": [0, 11, 0],
             "brightness": 1, "lightEmission": 0},
            {"name": "PositiveMotes", "texture": "rbxassetid://12159555294", "shape": "Cylinder", "style": "Volume",
             "part": [4.4, 4.8, 3.6], "y": 2.4, "rate": 6, "life": [1.2, 1.8], "speed": [0.4, 0.9],
             "size": [[0, 0.12], [0.5, 0.09], [1, 0]], "transparency": [[0, 0], [0.8, 0.2], [1, 1]],
             "colour": [[0, "FFFBEA"], [1, "FFD27A"]], "accel": [0, 0.5, 0], "drag": 0.5,
             "brightness": 2, "lightEmission": 1},
        ],
    },
    # Netero (Prayer Master) v3 (owner: v2 "trash, low effort, too big"). A COMPACT aura (nothing wider than his
    # shoulders bar a soft halo) from his lore: the THOUSAND HANDS of the 100-Type Guanyin as a halo of rendered gold palms
    # behind his shoulders, golden NEN flames off his body and a thin outer flame shell behind him, GRATITUDE (感謝 心 祈)
    # drifting up as small gold kanji, rare golden PALM imprints flashing at arm's length (the Bodhisattva's strikes), a
    # faint sutra ring underfoot and motes. All textures rendered metal-gold (work/netero/netero_v3.py). No pack (noBase).
    "prayer_master": {
        "noBase": True,
        "fx": [
            {"name": "ThousandHands", "texture": "rbxassetid://128212180686429", "shape": "Box", "style": "Volume",
             "part": [0.1, 0.1, 0.1], "y": 4.2, "offset": [0, -0.8], "rate": 0.5, "life": [4, 4], "speed": [0, 0],
             "size": [[0, 2.8], [0.5, 2.9], [1, 2.8]], "transparency": [[0, 1], [0.2, 0.15], [0.8, 0.15], [1, 1]],  # owner: "a little smaller"
             "colour": [[0, "FFFFFF"], [1, "FFFFFF"]], "rotation": [0, 360], "rotSpeed": [6, 6],
             "brightness": 1.3, "lightEmission": 0.6, "zOffset": -3, "locked": True,
             "light": "FFCF70", "lightRange": 9, "lightBrightness": 0.9},
            {"name": "GoldenNen", "texture": "rbxassetid://102788242727813", "flipbook": "Grid2x2",
             "bodyParts": ["UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm"], "rate": 5, "life": [0.5, 0.8], "speed": [1.2, 2.0],
             "size": [[0, 0.3], [0.35, 0.7], [1, 0.25]], "transparency": [[0, 1], [0.15, 0.55], [0.7, 0.7], [1, 1]],
             "colour": [[0, "FFFFFF"], [1, "FFFFFF"]], "rotation": [-8, 8], "spread": [2, 2],
             "accel": [0, 2.2, 0], "drag": 1.5, "brightness": 1.1, "lightEmission": 0.3, "zOffset": -2},
            {"name": "NenShell", "texture": "rbxassetid://102788242727813", "flipbook": "Grid2x2",
             "shape": "Cylinder", "style": "Surface", "part": [4.2, 2.0, 2.0], "y": 2.5, "rate": 8,
             "life": [0.5, 0.8], "speed": [1.2, 1.9], "size": [[0, 0.8], [0.35, 1.5], [1, 0.6]],
             "transparency": [[0, 1], [0.18, 0.35], [0.75, 0.55], [1, 1]], "colour": [[0, "FFFFFF"], [1, "FFFFFF"]],
             "rotation": [-8, 8], "spread": [2, 2], "accel": [0, 2.2, 0], "drag": 1.5,
             "brightness": 1.0, "lightEmission": 0.25, "zOffset": -3.5},
            {"name": "Gratitude", "texture": "rbxassetid://90709107449153", "flipbook": "Grid2x2",
             "shape": "Cylinder", "style": "Surface", "part": [1.5, 2.8, 2.8], "y": 3.6, "rate": 1.3,
             "life": [1.6, 2.2], "speed": [0.5, 0.9], "size": [[0, 0], [0.15, 0.42], [0.85, 0.38], [1, 0]],
             "transparency": [[0, 1], [0.15, 0.05], [0.8, 0.2], [1, 1]], "colour": [[0, "FFFFFF"], [1, "FFFFFF"]],
             "rotation": [0, 0], "accel": [0, 0.4, 0], "drag": 0.5, "brightness": 1.4, "lightEmission": 0.7,
             "zOffset": 0.5},
            {"name": "PalmImprint", "texture": "rbxassetid://113988170550430", "shape": "Cylinder", "style": "Surface",
             "part": [2.6, 3.4, 3.4], "y": 2.9, "rate": 0.7, "life": [0.32, 0.42], "speed": [0, 0],
             "size": [[0, 0.6], [0.25, 1.0], [1, 1.15]], "transparency": [[0, 0], [0.35, 0.1], [1, 1]],
             "colour": [[0, "FFFFFF"], [1, "FFFFFF"]], "rotation": [-25, 25],
             "brightness": 1.8, "lightEmission": 0.8, "zOffset": 0.6},
            {"name": "SutraRing", "texture": "rbxassetid://78509864546046", "shape": "Box",
             "part": [0.2, 0.2, 0.2], "y": 0.1, "orient": "VelocityPerpendicular", "dir": "Top", "rate": 0.5,
             "life": [4, 4], "speed": [0.01, 0.01], "size": [[0, 3.4], [1, 3.5]],
             "transparency": [[0, 1], [0.2, 0.5], [0.8, 0.5], [1, 1]], "colour": [[0, "FFE6A8"], [1, "FFC45A"]],
             "rotation": [0, 360], "rotSpeed": [-8, -8], "brightness": 1.2, "lightEmission": 0.8, "locked": True},
            {"name": "PrayerMotes", "texture": "rbxassetid://12159555294", "shape": "Cylinder", "style": "Volume",
             "part": [3.6, 2.4, 2.4], "y": 2.2, "rate": 7, "life": [1.2, 1.8], "speed": [0.4, 1.0],
             "size": [[0, 0.13], [0.5, 0.1], [1, 0]], "transparency": [[0, 0], [0.8, 0.2], [1, 1]],
             "colour": [[0, "FFFBEA"], [1, "FFC45A"]], "accel": [0, 0.5, 0], "drag": 0.5,
             "brightness": 2.2, "lightEmission": 1},
        ],
    },
    # Power (premium, Blood Fiend), v3 (owner: "no hammer, arrows and stuff, just an aura, way more advanced"). A pure,
    # layered BLOOD AURA, built like a pro aura from back to front: a dark wine VEIL rising behind her (unlit, for depth and
    # contrast), soft BLOOD FLAMES licking straight off her body parts so it follows her silhouette (rendered blood-flame
    # flipbook, work/power/aura_render.py: hot crimson core, dark wine edges, a liquid sheen), a larger OUTER flame shell, a
    # pulsing crimson HEART glow behind her chest, blood DROPLETS floating up against gravity (rendered, wet-lit), slow
    # blood STREAMS curling round her, a faint crimson RIPPLE on the ground and a crimson rim light. No props, no pack.
    "lucky_cat_mascot": {
        "noBase": True,
        "fx": [
            {"name": "DarkVeil", "texture": "rbxassetid://103697196498225", "shape": "Cylinder", "style": "Surface",
             "part": [4.6, 2.4, 2.4], "y": 2.8, "rate": 12, "life": [0.8, 1.1], "speed": [1.6, 2.4],
             "size": [[0, 1.6], [0.5, 3.0], [1, 2.2]], "transparency": [[0, 1], [0.2, 0.12], [1, 1]],
             "colour": [[0, "3A0410"], [1, "0E0104"]], "rotation": [-10, 10], "spread": [3, 3],
             "accel": [0, 1.5, 0], "drag": 1, "brightness": 1, "lightEmission": 0, "zOffset": -3},
            {"name": "BloodFlames", "texture": "rbxassetid://116122699380457", "flipbook": "Grid2x2",
             "bodyParts": ["UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftUpperLeg", "RightUpperLeg"], "rate": 8, "life": [0.5, 0.8], "speed": [1.4, 2.6],
             "size": [[0, 0.6], [0.35, 1.5], [1, 0.5]], "transparency": [[0, 1], [0.15, 0.15], [0.7, 0.3], [1, 1]],
             "colour": [[0, "FFFFFF"], [1, "E6C8CC"]], "rotation": [-8, 8], "spread": [2, 2],
             "accel": [0, 2.5, 0], "drag": 1.5, "brightness": 1.2, "lightEmission": 0.25, "zOffset": -0.6},
            {"name": "OuterFlames", "texture": "rbxassetid://116122699380457", "flipbook": "Grid2x2",
             "shape": "Cylinder", "style": "Surface", "part": [4.6, 2.5, 2.5], "y": 2.5, "rate": 14,
             "life": [0.6, 0.9], "speed": [1.6, 2.6], "size": [[0, 1.1], [0.35, 2.3], [1, 0.8]],
             "transparency": [[0, 1], [0.18, 0.05], [0.75, 0.25], [1, 1]], "colour": [[0, "FFFFFF"], [1, "FFFFFF"]],
             "rotation": [-8, 8], "spread": [2, 2], "accel": [0, 2.5, 0], "drag": 1.5,
             "brightness": 0.9, "lightEmission": 0.12, "zOffset": -2.5},
            {"name": "HeartGlow", "texture": "rbxassetid://12159555294", "shape": "Box", "style": "Volume",
             "part": [0.1, 0.1, 0.1], "y": 3.6, "rate": 2, "life": [1.0, 1.0], "speed": [0, 0],
             "size": [[0, 3.2], [0.4, 4.4], [1, 3.6]], "transparency": [[0, 1], [0.4, 0.6], [1, 1]],
             "colour": [[0, "E0102A"], [1, "7A0418"]], "brightness": 1.6, "lightEmission": 1, "zOffset": -4,
             "locked": True, "light": "E0182E", "lightRange": 12, "lightBrightness": 2.4},
            {"name": "RisingDrops", "texture": "rbxassetid://89368617950947", "shape": "Cylinder", "style": "Volume",
             "part": [4, 2.8, 2.8], "y": 2.2, "orient": "VelocityParallel", "rate": 8, "life": [1.2, 1.8],
             "speed": [1.2, 2.6], "size": [[0, 0], [0.15, 0.26], [1, 0.08]],
             "transparency": [[0, 0], [0.8, 0.1], [1, 1]], "colour": [[0, "FFFFFF"], [1, "FFFFFF"]],
             "rotation": [180, 180], "spread": [4, 4], "accel": [0, 0.8, 0], "drag": 0.6,
             "brightness": 1, "lightEmission": 0.1},
            {"name": "BloodStreams", "texture": "rbxassetid://130113799767686", "shape": "Cylinder", "style": "Surface",
             "part": [4.4, 2.6, 2.6], "y": 2.6, "rate": 2, "life": [0.7, 1.0], "speed": [0.6, 1.0],
             "size": [[0, 0.8], [0.4, 1.5], [1, 1.7]], "transparency": [[0, 1], [0.25, 0.3], [1, 1]],
             "colour": [[0, "FFFFFF"], [1, "FFFFFF"]], "rotation": [0, 360], "rotSpeed": [-160, 160],
             "accel": [0, 1.2, 0], "brightness": 1, "lightEmission": 0.1, "zOffset": -0.5},
            {"name": "Ripple", "texture": "http://www.roblox.com/asset/?id=11557895555", "shape": "Box",
             "part": [0.2, 0.2, 0.2], "y": 0.12, "orient": "VelocityPerpendicular", "dir": "Top", "rate": 0.9,
             "life": [1.1, 1.3], "speed": [0.01, 0.01], "size": [[0, 2.2], [1, 5]],
             "transparency": [[0, 0.25], [1, 1]], "colour": [[0, "FF3048"], [1, "6A0616"]],
             "rotation": [0, 360], "brightness": 1.4, "lightEmission": 0.8, "locked": True},
        ],
    },
    # Frieren (premium): her OWN magic, no pack aura (noBase; owner: the pack read as irrelevant). Original drawings
    # (work/frieren/frieren_textures.py): the anime's white SPELL CIRCLE glowing on the floor with a second copy slowly
    # turning over it, a floating CASTING CIRCLE by her shoulder (Zoltraak), a field of BLUE MOONWEED blooming round her
    # feet (the flower she searched for), soft PETALS drifting up, panels of her HEXAGONAL BARRIER flickering round her and
    # golden MANA motes. Palette: white and pale gold magic, moonweed blue, a cyan barrier.
    "angel_commander": {
        "noBase": True,
        "floor": {"core": "rbxassetid://139425774580328", "glow": "rbxassetid://139425774580328", "size": 8.5,
                  "coreColour": "FFF2D0", "glowColour": "FFF2D0", "brightness": 1.5, "glowTransparency": 1,
                  "pulse": False},
        "fx": [
            {"name": "CircleTurn", "texture": "rbxassetid://139425774580328", "shape": "Box",
             "part": [0.2, 0.2, 0.2], "y": 0.1, "orient": "VelocityPerpendicular", "dir": "Top",
             "rate": 0.7, "life": [3.2, 3.2], "speed": [0.01, 0.01],
             "size": [[0, 6.4], [1, 6.6]], "transparency": [[0, 1], [0.3, 0.45], [0.7, 0.45], [1, 1]],
             "colour": [[0, "CFE6FF"], [1, "9FC8FF"]], "rotation": [0, 360], "rotSpeed": [18, 18],
             "brightness": 1.4, "lightEmission": 1, "locked": True,
             "light": "E6EEFF", "lightRange": 9, "lightBrightness": 0.9},
            {"name": "CastingCircle", "texture": "rbxassetid://139425774580328", "shape": "Box",
             "part": [0.1, 0.1, 0.1], "y": 3.9, "offset": [0, -0.9], "rate": 0.7, "life": [3.0, 3.0], "speed": [0, 0],
             "size": [[0, 2.9], [1, 3.1]], "transparency": [[0, 1], [0.25, 0.1], [0.75, 0.1], [1, 1]],  # centred behind her (owner: it sat off to one side)
             "colour": [[0, "FFFFFF"], [1, "FFE6B0"]], "rotation": [0, 360], "rotSpeed": [-30, -30],
             "brightness": 1.8, "lightEmission": 1, "locked": True, "zOffset": -2},
            {"name": "MoonweedField", "texture": "rbxassetid://97003048377547", "shape": "Cylinder", "style": "Volume",
             "part": [0.2, 5.4, 5.4], "y": 0.45, "orient": "FacingCameraWorldUp", "rate": 4, "life": [2.6, 3.4],
             "speed": [0, 0], "size": [[0, 0], [0.2, 0.75], [0.85, 0.8], [1, 0]],
             "transparency": [[0, 1], [0.15, 0], [0.85, 0.05], [1, 1]],
             "colour": [[0, "FFFFFF"], [1, "FFFFFF"]], "rotation": [-15, 15],
             "brightness": 1.2, "lightEmission": 0.3, "zOffset": 0.4},
            {"name": "Petals", "texture": "rbxassetid://76635208444627", "shape": "Cylinder", "style": "Volume",
             "part": [0.3, 5, 5], "y": 0.6, "rate": 6, "life": [2.2, 3.2], "speed": [0.6, 1.2],
             "size": [[0, 0], [0.15, 0.22], [1, 0.12]], "transparency": [[0, 0.1], [0.8, 0.3], [1, 1]],
             "colour": [[0, "E6F0FF"], [0.5, "9FC0FF"], [1, "C8B8FF"]],
             "rotation": [0, 360], "rotSpeed": [-120, 120], "spread": [30, 30], "accel": [0, 0.5, 0], "drag": 0.6,
             "brightness": 1.5, "lightEmission": 0.8},
            {"name": "HexBarrier", "texture": "rbxassetid://105074940545440", "shape": "Cylinder", "style": "Surface",
             "part": [4.4, 4.6, 4.6], "y": 2.8, "orient": "FacingCamera", "rate": 2.5, "life": [0.6, 0.9],
             "speed": [0, 0], "size": [[0, 0.4], [0.2, 0.85], [1, 0.9]],
             "transparency": [[0, 1], [0.2, 0.35], [0.7, 0.5], [1, 1]],
             "colour": [[0, "DFF6FF"], [1, "6FC8FF"]], "rotation": [0, 0],
             "brightness": 1.5, "lightEmission": 1, "zOffset": 0.3},
            {"name": "ManaMotes", "texture": "rbxassetid://12159555294", "shape": "Cylinder", "style": "Volume",
             "part": [4, 4.4, 4.4], "y": 2.2, "rate": 10, "life": [1.2, 1.8], "speed": [0.5, 1.2],
             "size": [[0, 0.18], [0.5, 0.14], [1, 0]], "transparency": [[0, 0], [0.8, 0.2], [1, 1]],
             "colour": [[0, "FFFBEA"], [1, "FFD98A"]], "accel": [0, 0.6, 0], "drag": 0.5,
             "brightness": 2.5, "lightEmission": 1},
        ],
    },
    # Whitebeard: the tremor-tremor fruit. Original drawings (work/whitebeard/quake_textures.py): QUAKE BUBBLES (glassy cracked
    # spheres) charging round BOTH fists, the AIR SHATTERING like glass round him, a SHOCKWAVE rippling out along the ground,
    # GROUND CRACKS under him and DEBRIS kicked up by the tremor.
    "quake_captain": {
        "floor": {"core": "rbxassetid://122143460318748", "glow": "rbxassetid://122143460318748", "size": 9,
                  "coreColour": "D8F2FF", "glowColour": "6FA8E8", "brightness": 1.6, "glowTransparency": 1,
                  "pulse": False},
        "fx": [
            {"name": "QuakeOrbR", "texture": "rbxassetid://113320563007188", "shape": "Box", "style": "Volume",
             "part": [0.1, 0.1, 0.1], "y": 1.9, "offset": [1.6, 0.4], "rate": 3, "life": [0.6, 0.8], "speed": [0, 0],
             "size": [[0, 0.8], [1, 1.9]], "transparency": [[0, 0.1], [0.6, 0.35], [1, 1]],
             "colour": [[0, "FFFFFF"], [1, "9FD0F0"]], "rotation": [0, 360], "rotSpeed": [-40, 40],
             "brightness": 1.8, "lightEmission": 1, "locked": True,
             "light": "CFEEFF", "lightRange": 7, "lightBrightness": 1.2},
            {"name": "QuakeOrbL", "texture": "rbxassetid://113320563007188", "shape": "Box", "style": "Volume",
             "part": [0.1, 0.1, 0.1], "y": 1.9, "offset": [-1.6, 0.4], "rate": 3, "life": [0.6, 0.8], "speed": [0, 0],
             "size": [[0, 0.8], [1, 1.9]], "transparency": [[0, 0.1], [0.6, 0.35], [1, 1]],
             "colour": [[0, "FFFFFF"], [1, "9FD0F0"]], "rotation": [0, 360], "rotSpeed": [-40, 40],
             "brightness": 1.8, "lightEmission": 1, "locked": True},
            {"name": "AirShatter", "texture": "rbxassetid://102324797531062", "shape": "Cylinder", "style": "Surface",
             "part": [4.4, 5.8, 5.8], "y": 3.0, "rate": 2.2, "life": [0.25, 0.4], "speed": [0, 0],
             "size": [[0, 1.6], [0.15, 2.4], [1, 2.6]], "transparency": [[0, 0], [0.5, 0.15], [1, 1]],  # snaps open
             "colour": [[0, "FFFFFF"], [1, "AEDCFF"]], "rotation": [0, 360],
             "brightness": 2, "lightEmission": 1, "zOffset": 0.5},
            {"name": "Shockwave", "texture": "http://www.roblox.com/asset/?id=11557895555", "shape": "Box",
             "part": [0.2, 0.2, 0.2], "y": 0.15, "orient": "VelocityPerpendicular", "dir": "Top",
             "rate": 1.4, "life": [0.9, 1.1], "speed": [0.01, 0.01],
             "size": [[0, 2], [1, 9]], "transparency": [[0, 0.1], [0.6, 0.5], [1, 1]],
             "colour": [[0, "FFFFFF"], [0.5, "BFE6FF"], [1, "6FA8E8"]],
             "rotation": [0, 360], "brightness": 2, "lightEmission": 1, "locked": True},
            {"name": "TremorDebris", "texture": "rbxassetid://12159555294", "shape": "Cylinder", "style": "Volume",
             "part": [0.3, 4.4, 4.4], "y": 0.25, "rate": 9, "life": [0.6, 1.0], "speed": [3, 6],
             "size": [[0, 0.22], [1, 0.1]], "transparency": [[0, 0], [0.8, 0.3], [1, 1]],
             "colour": [[0, "E6F6FF"], [1, "8FB8D8"]],
             "spread": [25, 25], "accel": [0, -14, 0], "brightness": 1.5, "lightEmission": 0.5},
        ],
    },
    # Hisoka: the magician. Original drawings (work/hisoka/hisoka_textures.py): PLAYING CARDS (full colour, a random suit each)
    # fluttering and spinning round him, BUNGEE GUM strands stretching off both hands, his FACE MARKS (a pink star, a teal
    # teardrop) twinkling round his head, and a soft magenta NEN haze.
    "card_magician": {
        "fx": [
            {"name": "FlyingCards", "texture": "rbxassetid://88310227210137", "flipbook": "Grid2x2",
             "shape": "Cylinder", "style": "Surface", "part": [5, 6.2, 6.2], "y": 3.0,
             "rate": 4, "life": [2.0, 2.8], "speed": [0.3, 0.8],
             "size": [[0, 0], [0.12, 0.95], [0.85, 0.9], [1, 0]],
             "transparency": [[0, 1], [0.12, 0], [0.85, 0.05], [1, 1]],
             "colour": [[0, "FFFFFF"], [1, "FFFFFF"]],
             "rotation": [0, 360], "rotSpeed": [-160, 160], "spread": [180, 180], "accel": [0, 0.3, 0], "drag": 1,
             "brightness": 1.2, "lightEmission": 0, "zOffset": 1},
            {"name": "BungeeGumR", "texture": "rbxassetid://128245794821063", "shape": "Box", "style": "Volume",
             "part": [0.3, 0.3, 0.3], "y": 2.3, "offset": [1.6, 0.2], "orient": "VelocityParallel", "dir": "Right",
             "rate": 2.2, "life": [0.7, 1.1], "speed": [1.5, 2.5],
             "size": [[0, 0.4], [0.3, 1.6], [1, 1.2]], "transparency": [[0, 0.2], [0.7, 0.35], [1, 1]],
             "colour": [[0, "FFB8E8"], [0.5, "FF5FC8"], [1, "D0208A"]],
             "spread": [55, 55], "drag": 2, "brightness": 1.6, "lightEmission": 0.8},
            {"name": "BungeeGumL", "texture": "rbxassetid://128245794821063", "shape": "Box", "style": "Volume",
             "part": [0.3, 0.3, 0.3], "y": 2.3, "offset": [-1.6, 0.2], "orient": "VelocityParallel", "dir": "Left",
             "rate": 2.2, "life": [0.7, 1.1], "speed": [1.5, 2.5],
             "size": [[0, 0.4], [0.3, 1.6], [1, 1.2]], "transparency": [[0, 0.2], [0.7, 0.35], [1, 1]],
             "colour": [[0, "FFB8E8"], [0.5, "FF5FC8"], [1, "D0208A"]],
             "spread": [55, 55], "drag": 2, "brightness": 1.6, "lightEmission": 0.8},
            {"name": "FaceMarks", "texture": "rbxassetid://106659789249068", "flipbook": "Grid2x2",
             "shape": "Cylinder", "style": "Surface", "part": [1.6, 3.6, 3.6], "y": 4.6,
             "rate": 3, "life": [1.0, 1.5], "speed": [0.2, 0.5],
             "size": [[0, 0], [0.25, 0.4], [1, 0]], "transparency": [[0, 0.1], [1, 0.4]],
             "colour": [[0, "FFFFFF"], [1, "FFFFFF"]],
             "rotation": [-25, 25], "rotSpeed": [-40, 40], "accel": [0, 0.4, 0],
             "brightness": 1.5, "lightEmission": 0.6, "zOffset": 1},
            {"name": "NenHaze", "texture": "rbxassetid://11989899750", "shape": "Cylinder", "style": "Surface",
             "part": [4.2, 3.4, 3.4], "y": 2.4, "rate": 4, "life": [1.0, 1.5], "speed": [0.8, 1.6],
             "size": [[0, 1], [1, 2.4]], "transparency": [[0, 1], [0.3, 0.78], [1, 1]],
             "colour": [[0, "FF6AD0"], [0.5, "B02AB0"], [1, "4A1460"]],
             "rotation": [0, 360], "rotSpeed": [-30, 30], "accel": [0, 0.8, 0],
             "brightness": 1, "lightEmission": 0.6, "zOffset": -2},
        ],
    },
    # Sae Itoshi: the FLOW look from his anime art. Hand-written glowing NUMBERS drifting up round him (a 4x4 flipbook of
    # digits, work/sae/digits.py; each particle a random one), MAGENTA FLAMES licking up his body, DARK SMOKE behind him
    # (unlit, so it reads as smoke, not glow) and RED EMBERS rising.
    "midfield_genius": {
        "fx": [
            {"name": "FlowNumbers", "texture": "rbxassetid://77269623679808", "flipbook": "Grid4x4",
             "shape": "Cylinder", "style": "Surface", "part": [5.2, 7.2, 7.2], "y": 2.8,
             "rate": 12, "life": [1.4, 2.0], "speed": [0.6, 1.2],
             "size": [[0, 0], [0.15, 1.05, 0.2], [0.8, 0.95], [1, 0]],  # owner: "too big" (was 1.9)  # (0.85 was too small to read)
             "transparency": [[0, 1], [0.15, 0], [0.75, 0.1], [1, 1]],
             "colour": [[0, "FFA8EC"], [0.3, "FF40C8"], [1, "B0108A"]],  # (whiter read as white smears)
             "rotation": [-20, 20], "rotSpeed": [-15, 15], "spread": [10, 10], "accel": [0, 0.8, 0], "drag": 0.6,
             "brightness": 1.8, "lightEmission": 1, "zOffset": 1.5,
             "light": "FF3FC0", "lightRange": 11, "lightBrightness": 1.3},
            {"name": "FlowFlames", "texture": "rbxassetid://11989899750", "shape": "Cylinder", "style": "Surface",
             "part": [4.2, 3.2, 3.2], "y": 2.4, "rate": 10, "life": [0.6, 0.9], "speed": [1.5, 3],
             "size": [[0, 0.8], [0.5, 1.6], [1, 0.4]],
             "transparency": [[0, 1], [0.25, 0.55], [1, 1]],
             "colour": [[0, "FF8AE0"], [0.5, "E020A8"], [1, "70105A"]],
             "rotation": [0, 360], "rotSpeed": [-60, 60], "spread": [8, 8], "accel": [0, 2, 0],
             "brightness": 2, "lightEmission": 1, "zOffset": -0.5},
            {"name": "DarkSmoke", "texture": "rbxassetid://11989899750", "shape": "Cylinder", "style": "Surface",
             "part": [4.4, 4.2, 4.2], "y": 2.6, "rate": 6, "life": [1.2, 1.8], "speed": [0.8, 1.6],
             "size": [[0, 1.2], [1, 3]],
             "transparency": [[0, 1], [0.3, 0.45], [1, 1]],
             "colour": [[0, "3A0A2A"], [1, "120410"]],
             "rotation": [0, 360], "rotSpeed": [-30, 30], "accel": [0, 0.8, 0],
             "brightness": 1, "lightEmission": 0, "zOffset": -2},
            {"name": "RedEmbers", "texture": "rbxassetid://12159555294", "shape": "Cylinder", "style": "Volume",
             "part": [3.6, 4.4, 4.4], "y": 2.2, "rate": 12, "life": [0.9, 1.4], "speed": [1, 2.5],
             "size": [[0, 0.3], [0.6, 0.22], [1, 0]], "transparency": [[0, 0], [0.8, 0.2], [1, 1]],
             "colour": [[0, "FFB07A"], [0.4, "FF2A3A"], [1, "8A0A1A"]],
             "spread": [40, 40], "accel": [0, 1.2, 0], "drag": 0.8, "brightness": 3, "lightEmission": 1},
        ],
    },
    # Jiraiya: a SUMMONING SEAL glowing on the floor (an original drawing: rings of script, spokes, the leaf swirl;
    # work/jiraiya/jiraiya_textures.py), a spinning RASENGAN in his right hand (an original vortex, cyan-white core, two
    # layers turning opposite ways, a blue light), and SAGE WISPS of natural energy rising round him.
    "toad_sage": {
        "floor": {"core": "rbxassetid://129804047032090", "glow": "rbxassetid://129804047032090", "size": 9,
                  "coreColour": "FFE2A8", "glowColour": "E0601E", "brightness": 2, "glowTransparency": 1,
                  "pulse": False},
        "fx": [
            {"name": "Rasengan", "texture": "rbxassetid://102248145348282", "shape": "Box", "style": "Volume",
             "part": [0.1, 0.1, 0.1], "y": 2.6, "offset": [1.7, 0.7], "rate": 9, "life": [0.35, 0.5],
             "speed": [0, 0], "size": [[0, 1.3], [1, 1.5]], "transparency": [[0, 0.3], [0.5, 0.05], [1, 1]],
             "colour": [[0, "BFF0FF"], [0.5, "3FAEFF"], [1, "2A5BFF"]],
             "rotation": [0, 360], "rotSpeed": [600, 800], "brightness": 1.6,  # (3 read as a plain white ball) "lightEmission": 1, "locked": True,
             "light": "5FB8FF", "lightRange": 8, "lightBrightness": 1.6},
            {"name": "RasenganShell", "texture": "rbxassetid://102248145348282", "shape": "Box", "style": "Volume",
             "part": [0.1, 0.1, 0.1], "y": 2.6, "offset": [1.7, 0.7], "rate": 6, "life": [0.3, 0.45],
             "speed": [0, 0], "size": [[0, 1.7], [1, 2.0]], "transparency": [[0, 0.5], [0.5, 0.35], [1, 1]],
             "colour": [[0, "8FD8FF"], [1, "2A5BFF"]],
             "rotation": [0, 360], "rotSpeed": [-700, -500], "brightness": 1.2, "lightEmission": 1, "locked": True},
            {"name": "SageWisps", "texture": "rbxassetid://12159555294", "shape": "Cylinder", "style": "Volume",
             "part": [0.4, 4.4, 4.4], "y": 0.3, "rate": 12, "life": [1.2, 1.8], "speed": [2, 4],
             "size": [[0, 0.35], [0.6, 0.28], [1, 0]], "transparency": [[0, 0], [0.8, 0.2], [1, 1]],
             "colour": [[0, "FFF0C0"], [0.4, "FFA040"], [1, "C8281A"]],
             "spread": [12, 12], "accel": [0, 1.2, 0], "drag": 0.6, "brightness": 3, "lightEmission": 1},
        ],
    },
    # Minato: the four TitanBolt beams ran 17 studs (from under the floor to far overhead): soles to just above his head
    "yellow_flash": {"beams": {"bottom": 0, "top": 7.5, "width": 5}},
    # Douma: the ICE LOTUS GARDEN (Barren Hanging Garden). Original drawings (work/douma/douma_textures.py, 2026-11-25):
    # LOTUS blooms rising and closing round his feet, ICE BUTTERFLIES with iridescent wings flapping (Squash) as they drift
    # round him, a frosted LOTUS MANDALA on the floor, a cold mist and ice glints.
    "crystal_cult_leader": {
        "floor": {"core": "rbxassetid://105355685560355", "glow": "rbxassetid://99306142891306", "size": 10,
                  "coreColour": "E6F7FF", "glowColour": "4A7CFF", "brightness": 2, "glowTransparency": 0.9,
                  "pulse": False},  # crisp lines only: the bloom + pulse glared white on the pedestal
        "fx": [
            {"name": "LotusGarden", "texture": "rbxassetid://106555028461223", "shape": "Cylinder", "style": "Surface",
             "part": [0.3, 6.2, 6.2], "y": 1.0, "orient": "FacingCameraWorldUp", "rate": 2.6, "life": [2.6, 3.4],
             "speed": [0, 0], "size": [[0, 0], [0.25, 1.9], [0.8, 2.0], [1, 0]],
             "transparency": [[0, 1], [0.2, 0.05], [0.8, 0.15], [1, 1]],
             "colour": [[0, "8FD0FF"], [0.5, "4A84FF"], [1, "8A72FF"]],  # deeper blue: pale lotuses vanished in the glow
             "rotation": [0, 0], "brightness": 1.8, "lightEmission": 1, "zOffset": 0.6},
            {"name": "IceButterflies", "texture": "rbxassetid://74157749062965", "shape": "Cylinder", "style": "Volume",
             "part": [5, 6.4, 6.4], "y": 3.3, "rate": 3, "life": [2.6, 3.6], "speed": [0.4, 0.9],
             "size": [[0, 0], [0.1, 1.05], [0.9, 1.0], [1, 0]],
             "squash": [[0.0, 0.0], [0.0625, 0.8], [0.125, 0.0], [0.1875, 0.8], [0.25, 0.0], [0.3125, 0.8], [0.375, 0.0], [0.4375, 0.8], [0.5, 0.0], [0.5625, 0.8], [0.625, 0.0], [0.6875, 0.8], [0.75, 0.0], [0.8125, 0.8], [0.875, 0.0], [0.9375, 0.8], [1.0, 0.0]],
             "transparency": [[0, 1], [0.1, 0.08], [0.85, 0.2], [1, 1]],
             "colour": [[0, "FF8AC8"], [0.33, "A88CFF"], [0.66, "6FD0FF"], [1, "7FFFD0"]],  # iridescent: rose, violet, cyan, mint
             "rotation": [-25, 25], "rotSpeed": [-20, 20], "spread": [180, 180], "accel": [0, 0.35, 0], "drag": 0.8,
             "brightness": 2, "lightEmission": 1, "zOffset": 0.5,
             "light": "9FC8FF", "lightRange": 12, "lightBrightness": 1.2},
            {"name": "IceGlints", "texture": "rbxassetid://106676034954642", "shape": "Cylinder", "style": "Volume",
             "part": [6, 5.4, 5.4], "y": 3.0, "rate": 10, "life": [0.4, 0.8], "speed": [0, 0.2],
             "size": [[0, 0], [0.3, 0.35], [1, 0]], "transparency": [[0, 0.1], [1, 0.4]],
             "colour": [[0, "FFFFFF"], [0.5, "CFE6FF"], [1, "FFC2E6"]],
             "rotation": [0, 45], "brightness": 3, "lightEmission": 1},
        ],
    },
    # Tengen: the flashiest Hashira. FIREWORKS popping round his head and shoulders (an original burst,
    # work/tengen/fx_textures.py), a GOLDEN FLAME RIBBON swirling round his feet (the reference's gold sweep), GLITTER
    # twinkling round him (an original four-point glint) and EMBERS rising off the floor.
    "flashy_shinobi": {
        "fx": [
            {"name": "Fireworks", "texture": "rbxassetid://117907582997811", "shape": "Sphere", "style": "Surface",
             "part": [7.5, 5.5, 7.5], "y": 5.2, "rate": 2.4, "life": [0.7, 0.95], "speed": [0, 0],
             "size": [[0, 0.4], [0.22, 2.6], [1, 3.3]],
             "transparency": [[0, 0], [0.5, 0.15], [1, 1]],
             "colour": [[0, "FFF2B8"], [0.3, "FFB02E"], [1, "FF4F8A"]],
             "rotation": [0, 360], "brightness": 3, "lightEmission": 1, "zOffset": -1,
             "light": "FFA848", "lightRange": 12, "lightBrightness": 1.3},
            {"name": "FireworksRose", "texture": "rbxassetid://117907582997811", "shape": "Sphere", "style": "Surface",
             "part": [8, 6, 8], "y": 5.4, "rate": 1.3, "life": [0.7, 0.95], "speed": [0, 0],
             "size": [[0, 0.3], [0.22, 2.0], [1, 2.6]],
             "transparency": [[0, 0], [0.5, 0.2], [1, 1]],
             "colour": [[0, "FFE0EC"], [0.3, "FF5A8A"], [1, "E0281A"]],
             "rotation": [0, 360], "brightness": 3, "lightEmission": 1, "zOffset": -1},
            {"name": "GoldRibbon", "texture": "http://www.roblox.com/asset/?id=11557895555", "shape": "Box",
             "part": [0.2, 0.2, 0.2], "y": 0.18, "orient": "VelocityPerpendicular", "dir": "Top",
             "rate": 2.6, "life": [0.9, 1.2], "speed": [0.01, 0.01],
             "size": [[0, 3.2], [1, 7.2]],
             "transparency": [[0, 0.2], [0.6, 0.45], [1, 1]],
             "colour": [[0, "FFE89A"], [0.5, "FF8A1E"], [1, "E0281A"]],
             "rotation": [0, 360], "rotSpeed": [200, 320], "brightness": 2, "lightEmission": 1, "locked": True},
            {"name": "Glitter", "texture": "rbxassetid://106676034954642", "shape": "Cylinder", "style": "Volume",
             "part": [6, 5.6, 5.6], "y": 3.0, "rate": 14, "life": [0.5, 0.9], "speed": [0, 0.3],
             "size": [[0, 0], [0.3, 0.45], [1, 0]],
             "transparency": [[0, 0.1], [1, 0.4]],
             "colour": [[0, "FFFFFF"], [0.4, "FFE08A"], [1, "FFB02E"]],
             "rotation": [0, 45], "rotSpeed": [-60, 60], "brightness": 4, "lightEmission": 1},
            {"name": "Embers", "texture": "rbxassetid://12159555294", "shape": "Cylinder", "style": "Volume",
             "part": [0.4, 4.6, 4.6], "y": 0.3, "rate": 10, "life": [1.0, 1.5], "speed": [2.5, 5],
             "size": [[0, 0.3], [0.6, 0.22], [1, 0]],
             "transparency": [[0, 0], [0.8, 0.2], [1, 1]],
             "colour": [[0, "FFF0B0"], [0.4, "FF9A2E"], [1, "E0281A"]],
             "spread": [14, 14], "accel": [0, 1.5, 0], "drag": 0.6, "brightness": 3.5, "lightEmission": 1},
        ],
    },
    # Kaido: the azure dragon's thunder storm. A Beast-Pirates violet STORM CLOUD rolling round his shoulders (not
    # additive, so it darkens like a real cloud), big THUNDER ARCS cracking on a shell round him (an original bolt,
    # work/kaido/bolt.py, uploaded 2026-11-25), a THUNDER SHOCKWAVE swirling out on the floor (his Thunder Bagua), cyan
    # EMBERS rising off the ground (the dragon's breath) and an indigo glow behind him. The pack's limb bolts stay.
    "beast_emperor": {
        "fx": [
            {"name": "StormCloud", "texture": "rbxassetid://11989899750", "shape": "Cylinder", "style": "Surface",
             "part": [1.2, 4.4, 4.4], "y": 4.9, "rate": 5.5, "life": [1.6, 2.4], "speed": [0.2, 0.5],
             "size": [[0, 1.5], [0.4, 3.4, 0.4], [1, 4.2]],
             "transparency": [[0, 1], [0.3, 0.47], [0.75, 0.6], [1, 1]],
             # a glowing indigo storm (an unlit dark cloud read as dirt on the pedestal from above)
             "colour": [[0, "5A3CC8"], [0.5, "3A2A9E"], [1, "221A5A"]],
             "rotation": [0, 360], "rotSpeed": [-40, 40], "spread": [50, 50], "accel": [0, 0.6, 0], "drag": 1,
             "brightness": 1.3, "lightEmission": 0.55, "zOffset": -1},
            {"name": "ThunderArcs", "texture": "rbxassetid://114181744965661", "shape": "Cylinder", "style": "Surface",
             "part": [5.6, 6.4, 6.4], "y": 3.0, "rate": 6, "life": [0.08, 0.15], "speed": [0, 0],
             "size": [[0, 2.3, 0.7], [1, 2.6, 0.7]],
             "transparency": [[0, 0.05], [0.7, 0.25], [1, 1]],
             "colour": [[0, "D8F6FF"], [0.5, "6FCFFF"], [1, "7A5CFF"]],
             "rotation": [-35, 35], "brightness": 4.5, "lightEmission": 1, "zOffset": -0.5,
             "light": "6FB8FF", "lightRange": 13, "lightBrightness": 1.4},
            {"name": "ThunderShock", "texture": "http://www.roblox.com/asset/?id=11557895555", "shape": "Box",
             "part": [0.2, 0.2, 0.2], "y": 0.12, "orient": "VelocityPerpendicular", "dir": "Top",
             "rate": 1.6, "life": [0.8, 1.0], "speed": [0.01, 0.01],
             "size": [[0, 2.5], [1, 9]],
             "transparency": [[0, 0.1], [0.6, 0.45], [1, 1]],
             "colour": [[0, "E8FBFF"], [0.35, "4FC3FF"], [1, "6A3CFF"]],
             "rotation": [0, 360], "rotSpeed": [-90, 90], "brightness": 3, "lightEmission": 1, "locked": True},
            {"name": "DragonEmbers", "texture": "rbxassetid://12159555294", "shape": "Cylinder", "style": "Volume",
             "part": [0.4, 4.4, 4.4], "y": 0.3, "rate": 12, "life": [1.0, 1.6], "speed": [3, 6],
             "size": [[0, 0.35], [0.6, 0.25], [1, 0]],
             "transparency": [[0, 0], [0.8, 0.2], [1, 1]],
             "colour": [[0, "E8FBFF"], [0.4, "45C2FF"], [1, "6A3CFF"]],
             "spread": [12, 12], "accel": [0, 2, 0], "drag": 0.6, "brightness": 4, "lightEmission": 1},
            {"name": "StormGlow", "texture": "rbxassetid://12159555294", "shape": "Box", "style": "Volume",
             "part": [1.8, 3.8, 0.8], "y": 3.0, "rate": 5, "life": [0.9, 1.4], "speed": [0, 0.2],
             "size": [[0, 4], [0.5, 5.8], [1, 4.6]],
             "transparency": [[0, 1], [0.35, 0.76], [1, 1]],
             "colour": [[0, "2F6BFF"], [0.6, "3A2AD0"], [1, "5A1E9E"]],
             "rotation": [0, 360], "rotSpeed": [-30, 30], "brightness": 1.6, "lightEmission": 1, "zOffset": -3},
        ],
    },
    # Kokushibo: moon-breathing crescent blades round him (work/kokushibo/crescent.py, uploaded 2026-11-25), three sizes
    # for depth, cyan-hot into blue, purple, a red tail; a violet haze at the feet. Emitted from shaped invisible parts.
    "six_eyed_moon": {
        "fx": [
            {"name": "MoonBlades", "texture": "rbxassetid://135460081122301", "shape": "Cylinder", "style": "Surface",
             "part": [5.6, 6.2, 6.2], "y": 3.0, "dir": "Top", "rate": 10, "life": [1.4, 2.1], "speed": [0.2, 0.6],
             "size": [[0, 0.3], [0.18, 1.2, 0.35], [0.8, 1.05, 0.3], [1, 0.2]],  # owner: "kinda big" (was 1.7 peak)
             "transparency": [[0, 1], [0.12, 0.05], [0.75, 0.2], [1, 1]],
             "colour": [[0, "BDF6FF"], [0.3, "38AEFF"], [0.7, "4A5CFF"], [1, "7A2CFF"]],
             "rotation": [0, 360], "rotSpeed": [-200, 200], "spread": [180, 180], "accel": [0, 0.6, 0], "drag": 1.5,
             "brightness": 2.2, "lightEmission": 1, "zOffset": 0.5,
             "light": "6F7CFF", "lightRange": 12, "lightBrightness": 1.6},
            {"name": "MoonBladesFar", "texture": "rbxassetid://135460081122301", "shape": "Cylinder", "style": "Surface",
             "part": [6.5, 7.6, 7.6], "y": 3.4, "rate": 3, "life": [2.2, 3.0], "speed": [0.1, 0.3],
             "size": [[0, 0.9], [0.25, 2.3, 0.4], [1, 1.9]],  # (was 3.2 peak)
             "transparency": [[0, 1], [0.25, 0.55], [0.75, 0.65], [1, 1]],
             "colour": [[0, "7C5CFF"], [0.55, "4B2CC8"], [1, "9A1240"]],
             "rotation": [0, 360], "rotSpeed": [-60, 60], "spread": [180, 180], "drag": 2,
             "brightness": 1.8, "lightEmission": 1, "zOffset": -1},
            {"name": "MoonShards", "texture": "rbxassetid://135460081122301", "shape": "Cylinder", "style": "Volume",
             "part": [5, 3.4, 3.4], "y": 2.8, "rate": 14, "life": [0.6, 1.1], "speed": [2, 4.5],
             "size": [[0, 0.5], [0.3, 0.55], [1, 0]],
             "transparency": [[0, 0.1], [0.7, 0.2], [1, 1]],
             "colour": [[0, "FF5A78"], [0.5, "9A4BFF"], [1, "45C2FF"]],
             "rotation": [0, 360], "rotSpeed": [-400, 400], "spread": [180, 180], "drag": 3,
             "brightness": 4, "lightEmission": 1},
            {"name": "MoonGlow", "texture": "rbxassetid://12159555294", "shape": "Box", "style": "Volume",
             "part": [1.6, 3.6, 0.8], "y": 3.0, "rate": 5, "life": [0.9, 1.4], "speed": [0, 0.2],
             "size": [[0, 3.5], [0.5, 5.2], [1, 4.2]],
             "transparency": [[0, 1], [0.35, 0.7], [1, 1]],
             "colour": [[0, "6A3CFF"], [0.6, "3A2AD0"], [1, "8A1A5A"]],
             "rotation": [0, 360], "rotSpeed": [-30, 30],
             "brightness": 1.6, "lightEmission": 1, "zOffset": -3},
            {"name": "MoonHaze", "texture": "rbxassetid://11989899750", "shape": "Cylinder", "style": "Volume",
             "part": [0.4, 6, 6], "y": 0.3, "rate": 3, "life": [1.8, 2.6], "speed": [0.2, 0.5],
             "size": [[0, 2.5], [1, 5.5]],
             "transparency": [[0, 1], [0.3, 0.72], [1, 1]],
             "colour": [[0, "5A2CC8"], [0.6, "2A1A8E"], [1, "6A0C30"]],
             "rotation": [0, 360], "rotSpeed": [-25, 25], "accel": [0, 0.4, 0],
             "brightness": 1.4, "lightEmission": 0.7, "zOffset": -2},
        ],
    },
    "crimson_fist_demon": {
        # the quake rings hovered mid-shin and the light-column plane sat above his head: both onto the floor
        "ground": ["Quake", "Aura"],
        # the compass needle: work/akaza/compass.py (an original drawing), uploaded 2026-11-25
        # (v2: bolder strokes; 9 studs read as hairlines on the pedestal, 11 reaches past it onto the dark floor)
        "floor": {"core": "rbxassetid://79305962339828", "glow": "rbxassetid://77093603756329", "size": 11,
                  "coreColour": "E6FDFF", "glowColour": "2BA8FF", "brightness": 3, "glowTransparency": 0.35},
    },
}
# auras shown raw (no body rig to convert) that belong on the ground: their lowest effect goes under the hero's feet
RAW_ANCHOR = {"VinnFlow": "ground"}

# a hero given a HAND-BUILT aura (own textures, its own Studio builder; design/auras.json template with "custom"):
# wins over every naming rule above. hero id -> (aura key in ReplicatedStorage.Assets.Auras, why)
CUSTOM = {
    "rebel_emperor": ("Geass", "the Heaven pack aura he wore, verbatim, on a round black-and-purple chessboard with the Geass bird engraved and lit crimson, the Geass glowing in his left eye and cast as rings every 2.5 s, the black king floating at his hand and the white king toppled (tools/studio/auras/build_geass.luau)"),
    "butterfly_swordswoman": ("ButterflyDance", "custom aura: Insect Breathing butterflies (tools/studio/auras/build_butterfly_dance.luau)"),
    "crow_illusionist": ("CrowGenjutsu", "custom aura: crows, Amaterasu, Mangekyo sigil, blood moon (tools/studio/auras/build_crow_genjutsu.luau)"),
    "shadow_monarch": ("ShadowArise", "custom aura: the shadow army rising from a void pool, violet shadow flames, glowing eyes (tools/studio/auras/build_shadow_monarch.luau)"),
    "demon_progenitor": ("DemonKing", "custom aura: flesh whips, blue spider lilies, a blood pool with a heartbeat (tools/studio/auras/build_demon_king.luau)"),
    "demon_lord_heir": ("ControlDevil", "custom aura: her ringed gaze as a sigil and a halo, two dogs on chain leashes, contract chains (tools/studio/auras/build_control_devil.luau)"),
    "red_haired_emperor": ("ConquerorsHaki", "custom aura: Conqueror's Haki, big black-and-crimson lightning, radial pressure wind, a shockwave, cracked stone (tools/studio/auras/build_conquerors_haki.luau)"),
    "dark_slash_captain": ("DarkSlash", "custom aura: dimension-slash rifts, a black crescent moon, an ink pool with crossed cuts, ink brush strokes (tools/studio/auras/build_dark_slash.luau)"),
    "curse_manipulator": ("CurseManipulation", "custom aura: cursed-spirit orbs with eyes circling him, spirits drifting in to be absorbed, an Uzumaki spiral (tools/studio/auras/build_curse_manipulation.luau)"),
    "hawkeye_swordsman": ("HawkEye", "custom aura: Yoru's emerald flying slashes, Haki cracks, hawk eyes and feathers (tools/studio/auras/build_hawk_eye.luau)"),
    "star_delinquent": ("StarPlatinum", "custom aura: Joestar star crest, shooting-star orbits, menacing ゴゴゴ, ORA impacts, starlight glints, time-stop pulse, stat-hexagon sigil (tools/studio/auras/build_star_platinum.luau)"),
    "emperor_striker": ("EmperorThorns", "custom aura: Kaiser's blue rose blooming on thorn vines that spiral up him, rose petals, a rose crest, a gold crown, Kaiser Impact lightning and shock ring (tools/studio/auras/build_emperor_thorns.luau)"),
    "blood_war_king": ("TheAlmighty", "custom aura: The Almighty, eyes opening in his black shadow over head and body, a shadow pool, Quincy reishi (tools/studio/auras/build_almighty.luau)"),
    "sakura_shogun": ("SunBreathing", "the original Solar Flare (owner's pick, verbatim) on a Sun Seal base: kanji 日の呼吸, the 13th-form flame ring, the hanafuda sun, breath pulse, rim glints (tools/studio/auras/build_sun_breathing.luau)"),
    "devil_knight": ("AntiMagic", "his one winged angel (owner's pick, verbatim) round a black five-leaf clover grimoire seal, five five-leaf clovers gliding round him, black anti-magic sword cuts, black lightning and shards (tools/studio/auras/build_anti_magic.luau)"),
    "dragon_monarch": ("DragonMonarch", "his Cinder (owner's pick, verbatim) with a pair of crimson dragon wings beating on his back, the Monarch of Destruction's claw-torn seal, Dragon's Fear waves and drifting scales (tools/studio/auras/build_dragon_monarch.luau)"),
    "sorcerer_hunter": ("HeavenlyRestriction", "his Dummy pack (owner's pick, verbatim) on a caved-in cracked crater, sorcerer-killer cuts splitting the air, dust and stone chips; no glow: he has no cursed energy (tools/studio/auras/build_heavenly_restriction.luau)"),
    "curse_king": ("MalevolentShrine", "his KingOfCurses (verbatim) with Dismantle volleys of razor slashes, Cleave X cuts opening the air, his domain's floor (tools/studio/auras/build_malevolent_shrine.luau)"),
    "tyrant_demon_lord": ("DemonCircle", "custom aura: layered demon magic circles (ground array, halo, casting arrays), Demon Eyes of Destruction, orbiting runes (tools/studio/auras/build_demon_circle.luau)"),
    "void_empress": ("Hogyoku", "custom aura: the Hogyoku in his chest seal, a god-halo (Kurohitsugi blade crown + Kyoka Suigetsu shattered mirror), reiatsu pillars, Kyoka Suigetsu mirror shards, water-moon sigil (tools/studio/auras/build_hogyoku.luau)"),
    "crimson_fist_demon": ("CompassNeedle", "custom aura: Destructive Death, the snowflake Compass Needle on the ground, needle pulses, snowflake impact barrage (tools/studio/auras/build_compass_needle.luau)"),
    "number_one_striker": ("AceEater", "custom aura: the Ace Eater, his pitch and coin ring, undead hands (Zombie-step), gold-grill jaws, an orbiting football (tools/studio/auras/build_ace_eater.luau)"),
    "gold_gang_boss": ("GoldExperience", "custom aura: Gold Experience gives life (flowers blooming round him), golden ladybugs, the golden wind, a vine-and-ladybug crest (tools/studio/auras/build_gold_experience.luau)"),
    "spider_thief_boss": ("SkillHunter", "custom aura: the grimoire Bandit's Secret at his hand, stolen-ability pages, the Troupe web (12 spokes, pulses running out along them), the spider seal facing front, Gyo aura lines (tools/studio/auras/build_skill_hunter.luau)"),
    "ice_general": ("DemonsExtract", "custom aura: ice clusters erupting round her, hoarfrost seal and frost shockwave, hail, snow and diamond dust (tools/studio/auras/build_demons_extract.luau)"),
}
# a second aura worn on top, cut down to the named effects only (owner, 2026-11-25: "use the infinity symbol only")
EXTRAS = {
    "limitless_teacher": [{"aura": "P:52", "keep": ["Infinity Symbol"], "label": "Infinite Reality: infinity symbol only"}],
}
# a hand-made colour design for one hero's auras (owner, 2026-11-25: Gojo's Crimson Moon "bluish, like a VFX designer"):
# per effect (by emitter name) a gradient over its life, a Brightness (the pack's additive layers at 5-20 stacked into
# white), and the light colour. Applied to the main aura AND the extras.
PALETTES = {
    # Ashborn (Galactic Center): owner, 2026-11-25: "make the aura lil smaller, the character should be visible too
    # kinda, dont overdo". Colours unchanged (the pack's own), only sizes: the nebulas to 55-65 %, and the DARK smokes
    # (Smoke 1 has negative LightEmission, Black Smoke is 15 studs of near-black) to about half and thinner: his dark
    # armour melted into them. The stars are untouched. (scale/rate apply only to emitters listed in colours.)
    "shadow_sovereign": {
        "colours": {
            "Nebula 1": [[0, "FFFFFF"], [1, "FFFFFF"]], "Nebula 2": [[0, "FFFFFF"], [1, "FFFFFF"]],
            "Nebula 3": [[0, "FFFFFF"], [1, "FFFFFF"]], "Nebula 4": [[0, "FFFFFF"], [1, "FFFFFF"]],
            "Nebula 5": [[0, "FFFFFF"], [1, "FFFFFF"]],
            "Smoke 1": [[0, "00000A"], [1, "00000A"]], "Smoke 2": [[0, "190F41"], [1, "190F41"]],
            "Black Smoke": [[0, "00050A"], [1, "00050A"]], "Space Mini Star": [[0, "FFFFFF"], [1, "FFFFFF"]],
        },
        "brightness": {},
        # (v2: nebulas 0.7, not 0.55: smaller, they hid behind his body and the galaxy glow was lost; the drifting
        # Black Smoke thinned further so it stops wandering across the floor)
        "scale": {"Nebula 1": 0.75, "Nebula 2": 0.7, "Nebula 3": 0.7, "Nebula 4": 0.7, "Nebula 5": 0.7,
                  "Smoke 1": 0.55, "Smoke 2": 0.55, "Black Smoke": 0.45, "Space Mini Star": 0.75},
        "rate": {"Smoke 1": 0.7, "Black Smoke": 0.4},
        # the dark smokes fly out every way at 1-4.5 studs/s: some drifted IN FRONT of him and dimmed him; slower,
        # they stay clustered behind him where their ZOffset hides them behind his body
        "speed": {"Smoke 1": 0.4, "Smoke 2": 0.5, "Black Smoke": 0.55},
        "light": "0800FF",
    },
    # Whitebeard (Crystal determination): the GURA GURA quake. The pack's mint becomes shattered-air white into sky blue with a
    # faint steel shadow; the quake bubbles, air cracks and ground cracks are STAGING fx and floor.
    "quake_captain": {
        "colours": {
            "Determination": [[0, "F2FBFF"], [0.5, "BFE6FF"], [1, "6FA8E8"]],
            "Determination2": [[0, "FFFFFF"], [0.5, "CFEEFF"], [1, "7FB8F0"]],
            "1": [[0, "FFFFFF"], [1, "BFE6FF"]], "2": [[0, "FFFFFF"], [1, "BFE6FF"]],
            "Beam": [[0, "E6F6FF"], [1, "8FC8F0"]],
        },
        "brightness": {},
        "light": "BFE6FF",
    },
    # Hisoka (Daemon of Cards): his NEN, magenta-pink with violet depth, the black sparkle/glow layers kept dark; the
    # pack's suit shapes kept but smaller (they were 1.5 studs of flat white). Cards, Bungee Gum and his face marks are fx.
    "card_magician": {
        "colours": {
            "Smoke 1": [[0, "FFB8E8"], [0.5, "FF4FC0"], [1, "8A1A9A"]],
            "Smoke 2": [[0, "E0309A"], [1, "5A1478"]],
            "Red Spiral": [[0, "C0208A"], [1, "5A0A50"]],
            "Crimson Flare": [[0, "7A1468"], [1, "3A0A3A"]],
            "Star Bits": [[0, "FFFFFF"], [0.5, "FFB8E8"], [1, "FF4FC0"]],
            "Sparkles": [[0, "FFFFFF"], [1, "FF9AD8"]],
            "Sparkle Droplets": [[0, "FFE6F6"], [1, "FF6AD0"]],
            "Cape1-2Main": [[0, "FF4FC0"], [1, "9A1A9A"]],
            "Cape1-2BG": [[0, "FFE6F6"], [1, "FF9AD8"]],
            "Beam1-1Glow": [[0, "FF4FC0"], [1, "B01A9A"]], "Beam2-2Glow": [[0, "FF4FC0"], [1, "B01A9A"]],
            "Beam1-1": [[0, "FFFFFF"], [1, "FFC2EC"]], "Beam2-2": [[0, "FFFFFF"], [1, "FFC2EC"]],
            "BeamCapeLeft": [[0, "FFFFFF"], [1, "FFC2EC"]], "BeamCapeRight": [[0, "FFFFFF"], [1, "FFC2EC"]],
        },
        "brightness": {"Cape1-2BG": 3},
        "scale": {"Hearts": 0.5, "Diamonds": 0.5, "Clubs": 0.5, "Spades": 0.5},
        "keepDark": True,
        "light": "FF4FC0",
    },
    # Sae Itoshi (Red Ring of Death): his FLOW in the anime is a magenta aura with dark smoke, red embers and glowing
    # hand-written numbers. The rings and intake go magenta with hot-pink-white cores; the debris stays red embers.
    "midfield_genius": {
        "colours": {
            "Ring": [[0, "FFC2EC"], [0.5, "FF3FC0"], [1, "B0108A"]],
            "Intake": [[0, "FFE0F4"], [0.5, "FF4FC8"], [1, "C0109A"]],
            "OutdoorParticle": [[0, "C0189A"], [1, "5A0840"]],
            "Debris": [[0, "FF7A5A"], [0.5, "FF2A3A"], [1, "8A0A1A"]],
        },
        "brightness": {"Ring": 1.8, "Intake": 2.2},  # (brighter drowned out the numbers)
        "light": "FF3FC0",
    },
    # Jiraiya (MUI): SAGE MODE. The pack's silver-blue-violet becomes natural energy: white-hot cores into amber and orange,
    # ending in his outfit's crimson; the smoke deep red-brown. The seal, the Rasengan and the sage wisps are STAGING fx.
    "toad_sage": {
        "colours": {
            "Flame": [[0, "FFF4D0"], [0.4, "FFB03A"], [1, "C8281A"]],
            "Smoke2": [[0, "FF9A3A"], [0.5, "D0501E"], [1, "5A1410"]],
            "Smoke3": [[0, "FFB24A"], [1, "B0281A"]],
            "2": [[0, "FFC860"], [1, "E0601E"]],
            "ParticleEmitter": [[0, "FFE0A0"], [1, "FFB03A"]],
            "Sphere thingy": [[0, "FFFFFF"], [0.5, "FFC24A"], [1, "E0501E"]],
            "Sphere thingy2": [[0, "FFFFFF"], [0.5, "FFC24A"], [1, "E0501E"]],
            "Sphere thingy3": [[0, "FFFFFF"], [0.5, "FFC24A"], [1, "E0501E"]],
            "1": [[0, "FFE6A8"], [1, "FF8A2E"]], "2 ": [[0, "FFE6A8"], [1, "FF8A2E"]],
            "3": [[0, "FFE6A8"], [1, "FF8A2E"]], "4": [[0, "FFE6A8"], [1, "FF8A2E"]], "5": [[0, "FFE6A8"], [1, "FF8A2E"]],
        },
        "brightness": {},
        "light": "FF9A3A",
    },
    # Minato (TitanBolt): the YELLOW FLASH. Flat 0xFFFF00 everywhere becomes white-hot cores into warm gold, the lightning
    # tails a touch of Rasengan blue. The streaks flew 35-65 studs/s (a column far over his head): speed halved. The
    # beams are spanned by STAGING.
    "yellow_flash": {
        "colours": {
            "tex:12414458390": [[0, "FFF6C8"], [0.5, "FFD23A"], [1, "FFB000"]],
            "tex:13712010201": [[0, "FFF6C8"], [0.5, "FFD23A"], [1, "FFB000"]],
            "tex:13370272316": [[0, "FFF6C8"], [0.5, "FFD23A"], [1, "FFB000"]],
            "tex:13712011229": [[0, "FFF6C8"], [0.5, "FFD23A"], [1, "FFB000"]],
            "Lines": [[0, "FFFFFF"], [0.4, "FFE45A"], [1, "FFB000"]],
            "Upward": [[0, "FFFFFF"], [0.4, "FFE45A"], [1, "FFB000"]],
            "Lightning 1": [[0, "FFFBE0"], [0.5, "FFD23A"], [1, "3FA8FF"]],
            "Lightning 2": [[0, "FFFBE0"], [0.5, "FFD23A"], [1, "3FA8FF"]],
            "Explosions 1": [[0, "FFF2A0"], [1, "FFB000"]], "Explosions 2": [[0, "FFF2A0"], [1, "FFB000"]],
            "Explosion 1": [[0, "FFF2A0"], [1, "FFB000"]], "Explosion 2": [[0, "FFF2A0"], [1, "FFB000"]],
            "Bolts": [[0, "FFFFFF"], [0.5, "FFE45A"], [1, "5FB8FF"]],
        },
        "brightness": {},
        "speed": {"Lines": 0.3, "Upward": 0.25, "Lightning 1": 0.22, "Lightning 2": 0.22, "Explosions 1": 0.5,
                  "Explosions 2": 0.5},  # (at half speed the bolts still flew well above his head)
        "light": "FFD84A",
    },
    # Douma (Cryogen): the ICE LOTUS. The pack's steel blue becomes frost-white into lotus blue with an iridescent lilac and
    # pink sheen (the rainbow shimmer of his art); the shards stay near-white ice. Beams by texture (their names repeat).
    "crystal_cult_leader": {
        "colours": {
            "tex:11975023580": [[0, "DFF7FF"], [0.5, "7FB8FF"], [1, "B89CFF"]],  # the frost-ring beams: an iridescent sweep
            "tex:11975030489": [[0, "DFF7FF"], [0.5, "7FB8FF"], [1, "B89CFF"]],
            "tex:11290368841": [[0, "CFEFFF"], [1, "9A8CFF"]],
            "tex:11290366632": [[0, "CFEFFF"], [1, "9A8CFF"]],
            "tex:11172050895": [[0, "E6F7FF"], [1, "8FB0FF"]],
            "Shine": [[0, "E6F7FF"], [0.6, "9FC8FF"], [1, "C9B8FF"]],
            "Glow": [[0, "7FB8FF"], [1, "7A7CFF"]],
            "Dust": [[0, "E6F7FF"], [0.35, "A9D8FF"], [0.7, "D9B8FF"], [1, "FFC2E0"]],  # frost dust with a rainbow tail
            "ParticleEmitter": [[0, "BFE9FF"], [1, "B89CFF"]],
            # the white shards/spikes on his legs glared white over the pedestal: ice blue
            "Shard1": [[0, "A8D8FF"], [1, "6F9CFF"]], "Shard2": [[0, "A8D8FF"], [1, "6F9CFF"]], "Shard3": [[0, "A8D8FF"], [1, "6F9CFF"]],
            "Shard falling1": [[0, "A8D8FF"], [1, "6F9CFF"]], "Shard falling2": [[0, "A8D8FF"], [1, "6F9CFF"]],
            "Spike1": [[0, "A8D8FF"], [1, "6F9CFF"]], "Spike2": [[0, "A8D8FF"], [1, "6F9CFF"]],
        },
        # the pack's dust and shine on his legs stacked into a white glare at the feet
        "brightness": {"Dust": 0.55, "Shine": 0.6, "Glow": 0.7},
        "rate": {"Dust": 0.6},
        "light": "8FC8FF",
    },
    # Tengen Uzui (Cool Vapor): FLASHY. The pack's purple/orange becomes his gold, flame orange and crimson, the dust tails
    # pink (fireworks); the spins, glows, the floor sigil and the light streaks keep their shapes. Fireworks, a golden
    # ribbon, glitter and embers are STAGING fx.
    "flashy_shinobi": {
        "colours": {
            "SPIN": [[0, "FFD54A"], [0.5, "FF8A1E"], [1, "E0281A"]],
            "LIGHT": [[0, "FFD06A"], [0.5, "FF8A1E"], [1, "E0281A"]],
            "SQUARE": [[0, "FFE08A"], [0.5, "FF7A1E"], [1, "FFE08A"]],  # the floor sigil: gold, flame at its peak
            "DUST": [[0, "FFF2B0"], [0.5, "FFB02E"], [1, "FF4F8A"]],  # rising dust: gold to a pink spark
            "SPOTLIGHT": [[0, "FFE6A0"], [1, "FF6A1A"]],
            "SPOTLIGHT2": [[0, "FFE6A0"], [1, "FF6A1A"]],
        },
        # the floor layers stacked into a white glare over his legs: dimmer and thinner
        "brightness": {"LIGHT": 0.55, "SQUARE": 0.7, "SPOTLIGHT": 0.8, "SPOTLIGHT2": 0.8},
        "rate": {"LIGHT": 0.6},
        "light": "FFA040",
    },
    # Diavolo (ShadowMonarch): colour ONLY (owner: "it's already really good, just match the colour"); every brightness,
    # size and rate is the pack's. King Crimson: crimson body, hot pink (his hair) on the hottest cores, deep wine
    # shadows and smoke, a magenta hint of erased time; the near-black outline layers untouched (keepDark).
    "crimson_boss": {
        "colours": {
            "Flame Burst": [[0, "FFC4D8"], [0.4, "FF4F7E"], [1, "C0103A"]],  # hot-pink-white core into crimson
            "Clean Flame Blast": [[0, "FF6FA8"], [0.5, "E0204A"], [1, "7A0A2A"]],
            "Dark Glow Fire": [[0, "FF3A5A"], [1, "8A0A2E"]],
            "Dark Shadow Fire": [[0, "B0123A"], [1, "3A0418"]],
            "Smoke": [[0, "8A1E5A"], [1, "2A0614"]],  # wine smoke with a magenta cast
            "Spec2": [[0, "FF8AB8"], [1, "E0204A"]],
            "Spec26": [[0, "FF4F8E"], [1, "B0103A"]],
        },
        "brightness": {},
        "keepDark": True,
        "light": "E0306A",
    },
    # Kaido (CyanStorm): the AZURE DRAGON'S THUNDER. The pack's six limb bolts ran at Brightness 33 (flat white-blue):
    # now white-hot cores cooling to electric cyan then azure, at a brightness that keeps the gradient; the sparks
    # white into cyan. The storm, the arcs and the shockwave are STAGING fx.
    "beast_emperor": {
        "colours": {
            "Lightning1": [[0, "C8F2FF"], [0.4, "4FB8FF"], [1, "2A5BFF"]],
            "Lightning2": [[0, "BFE8FF"], [0.5, "3FA8FF"], [1, "3A3CD8"]],
            "Lightning3": [[0, "C8F2FF"], [0.4, "4FB8FF"], [1, "2A5BFF"]],
            "Lightning4": [[0, "BFE8FF"], [0.5, "3FA8FF"], [1, "4A2CD8"]],
            "Lightning5": [[0, "C8F2FF"], [0.4, "4FB8FF"], [1, "2A5BFF"]],
            "Lightning6": [[0, "BFE8FF"], [0.5, "3FA8FF"], [1, "4A2CD8"]],
            "Detail": [[0, "FFFFFF"], [1, "5FD0FF"]],
        },
        # owner: "too intense, I can't see the character": limb bolts dimmer and half as frequent
        "brightness": {"Lightning1": 5, "Lightning2": 5, "Lightning3": 5, "Lightning4": 5, "Lightning5": 5,
                       "Lightning6": 5, "Detail": 6},
        "rate": {"Lightning1": 0.5, "Lightning2": 0.5, "Lightning3": 0.5, "Lightning4": 0.5, "Lightning5": 0.5,
                 "Lightning6": 0.5, "Detail": 0.8},
        # the limb bolts were 4.5 studs: drawn over his whole body
        "scale": {"Lightning1": 0.7, "Lightning2": 0.7, "Lightning3": 0.7, "Lightning4": 0.7, "Lightning5": 0.7,
                  "Lightning6": 0.7},  # (owner: 0.55 "too low", 1.0 "too intense")
        "light": "5FB0FF",
    },
    # Kokushibo (RedOutline, the body flames): Upper Moon One's mix. Bright flames violet into blue, the dark (subtractive)
    # flames crimson-black for depth, sparks crimson (his eyes, his blood); the crescents are STAGING fx. The A-tier
    # conversion had thinned this to 3.8/s: rates x2.5.
    "six_eyed_moon": {
        "colours": {
            "Fire18": [[0, "B07CFF"], [0.45, "6A4BFF"], [1, "2B2FC8"]],  # bright flame: violet core into blue
            "Fire2": [[0, "5A1240"], [1, "200A2A"]],  # the dark flame: plum-crimson into black
            "Dark Shadow Fire": [[0, "4A1478"], [1, "160A2E"]],  # shadow flame: deep indigo
            "Spec1": [[0, "FF5A6E"], [0.6, "D0154A"], [1, "7A1FD0"]],  # sparks: crimson cooling to violet
        },
        "brightness": {"Fire18": 3, "Fire2": 2, "Dark Shadow Fire": 2.5, "Spec1": 6},
        "rate": {"Fire18": 2.5, "Fire2": 1.3, "Dark Shadow Fire": 1.5, "Spec1": 2},  # dark layers kept thin: muddy when dense
        "light": "7A6CFF",
    },
    # Akaza (Gravity God): his Compass Needle. Ice-cyan to electric blue with white-hot highlights, the pack's magenta
    # dropped; the floor sigil (FLOORS) carries the look, the quake rings and the light columns frame it.
    "crimson_fist_demon": {
        "colours": {
            "Ring": [[0, "C8FAFF"], [1, "1E9BFF"]],  # the quake rings: ice-white crest to electric blue
            "Glow": [[0, "2BB8FF"], [1, "0B57D9"]],  # the disc glow
            "Star": [[0, "E8FFFF"], [1, "5FD8FF"]],  # the star burst
            "StarGlow": [[0, "5FD8FF"], [1, "1E7BFF"]],
            "RingGlow": [[0, "DFFBFF"], [1, "39C2FF"]],
            "Ambient": [[0, "1E9BFF"], [1, "0B3FB0"]],  # the haze: deep blue, for depth
            "Debris": [[0, "E8FFFF"], [1, "39C2FF"]],  # flying shards: frost
            "Debris2": [[0, "FFFFFF"], [1, "7FE9FF"]],  # the flickers: white-hot
            "LightBeams": [[0, "A8F4FF"], [0.5, "39B8FF"], [1, "1E6BFF"]],  # the light columns rising off the floor
        },
        # the quake's soft layers kept low: at the pack's level they flooded the centre and hid the sigil
        "brightness": {"Ring": 2, "Glow": 1, "Star": 2, "StarGlow": 1.2, "RingGlow": 2, "Ambient": 0.8,
                       "Debris": 3, "Debris2": 6, "LightBeams": 4},
        "light": "4FD2FF",
    },
    # Julius Novachrono (VinnFlow): TIME MAGIC, the Wizard King. Gold as the hero colour, champagne-white highlights,
    # amber and his cape's deep crimson in the shadows (the pack's purple was the opposite of his look). Keys: an emitter
    # name, or "tex:<id>" for every particle/beam with that texture (14 beams share three textures).
    "time_wizard_king": {
        "colours": {
            "tex:125283151882051": [[0, "FFF1C9"], [1, "FFB22E"]],  # thin light shafts: champagne to gold
            "tex:113083314207224": [[0, "FFE29A"], [1, "E8891C"]],  # medium shafts: gold to amber
            "tex:137185023437881": [[0, "FFC94D"], [0.6, "D9711A"], [1, "8E1F1A"]],  # the wide pillar: gold, amber, crimson
            "tex:12159555294": [[0, "FFF4D1"], [1, "FFB63A"]],  # motes
            "Circle12": [[0, "FFFFFF"], [1, "FFE2A0"]],  # the clock rings: white-hot to pale gold
            "Dull Triangular Circle": [[0, "FFD460"], [1, "D9781E"]],  # the magic circles: gold to amber
            "Fire40": [[0, "FFD877"], [0.5, "F0921F"], [1, "A8321C"]],  # the flame: gold, amber, crimson tail
            "Rune_Heal_In003": [[0, "FFE6A3"], [1, "FFB03A"]],  # the rune disc
            "rune_11": [[0, "FFFFFF"], [1, "FFD15C"]],  # the runes: white to gold
        },
        # the pack ran these at 5-25: stacked additive glow washes gold to white
        "brightness": {"tex:125283151882051": 2.5, "tex:113083314207224": 2.5, "tex:137185023437881": 4,
                       "Circle12": 6, "Dull Triangular Circle": 3, "Fire40": 5, "Rune_Heal_In003": 6, "rune_11": 5},
        "light": "FFC45C",
    },
    "limitless_teacher": {
        "colours": {
            "InnerSmoke": [[0, "0B2A9E"], [0.5, "2F7BFF"], [1, "0B2A9E"]],  # the dome inside: deep electric blue
            "Smoke": [[0, "1F4FFF"], [0.6, "2F86FF"], [1, "5B2EE0"]],  # streaks: cobalt, violet tail (Hollow Purple)
            "Ash": [[0, "F2FDFF"], [0.5, "A6EEFF"], [1, "35C8FF"]],  # sparks: white-hot to ice cyan
            "Mist": [[0, "0F2A80"], [1, "2A1F80"]],  # haze: navy into indigo, for depth
            "Power": [[0, "7FC8FF"], [1, "1E4BFF"]],  # flash behind the body
            "Ring": [[0, "FFFFFF"], [0.45, "8FE6FF"], [1, "2F7BFF"]],  # the dome's edge: white crest to blue
            "Pulsation": [[0, "1A4BE8"], [1, "6FCBFF"]],  # pulse: blue into a pale cyan rim
            "Infinity Symbol": [[0, "FFFFFF"], [1, "B5F1FF"]],  # white with a cyan afterglow
        },
        "brightness": {"Smoke": 3, "Power": 1.6, "Ring": 3, "Pulsation": 2.5, "Ash": 12},
        "light": "4FA8FF",
    },
}
# the owner moved a hero onto ANOTHER hero's aura (wins over the stand it was named on): hero id -> (ref, whose)
WEARS = {
    # owner 2026-11-25: "give the aura of endeavor to mereleona and ace ... endeavor's aura would be perfect"
    "crimson_lioness": ("P:55", "Endeavor"),  # Mereoleona (was P:96)
    "blazing_pirate": ("P:55", "Endeavor"),  # Ace (was P:93)
}
# Epic and up that the owner did not name and that had no nickname aura: picked to suit them
PICKS = {
    "staff_angel_mentor": ("P:97", "an angel"),  # Whis: ANGEL
    "angel_commander": ("P:94", "her own magic, the pack is not worn (STAGING noBase)"),  # Frieren
    "perfect_bio_android": ("P:50", "Perfect Cell's sparking aura"),  # Cell: Electrical Charge
    "butterfly_swordswoman": ("P:16", "her poison"),  # Shinobu: POISON
}
# Rare heroes: the colour of their aura (their power or signature colour)
RARE_COLOURS = {
    "Kakashi Hatake": "7FD4FF",  # lightning blade
    "Boruto": "4AA8FF",  # rasengan blue
    "Gaara": "D9A05B",  # sand
    "Rengoku": "E8261A",  # flame red (orange vanished into his own flame wings)
    "Giyu Tomioka": "2F8BFF",  # water breathing
    "Trafalgar Law": "00C2D8",  # ROOM
    "Boa Hancock": "FF4FA8",  # love-love
    "Zoro": "3CCB5A",  # green
    "Dabi": "1E5BFF",  # blue fire
    "Todoroki": "A8E6FF",  # ice
    "Barou": "C0143C",  # crimson king
    "Nagi": "E0E6FF",  # white
    "Magna": "FF4500",  # fire magic
    "Yuno": "4CE0B3",  # wind spirit
    "Kurapika": "FF2D55",  # scarlet eyes
    "Kirito": "3D5AFE",  # black swordsman's blue
    "Qin Shi Huang": "FFD24A",  # the first emperor's gold
    "Erwin": "2E8B57",  # survey corps green
    "Mikasa": "E53935",  # red scarf
    "Aki Hayakawa": "FF8C42",  # fox devil
    "Pucci": "9C6ADE",  # whitesnake
    "Ayanokoji": "8E9AAF",  # cold grey
    "Genos": "FF9E1B",  # incineration
    "Toshiro Hitsugaya": "7FE7FF",  # hyorinmaru
    "Ichigo Kurosaki": "5AC8FA",  # getsuga
    "Igris": "B00020",  # blood-red knight
    "Todo": "7E57C2",  # boogie woogie
    "Megumi Fushiguro": "7B7BFF",  # ten shadows (lighter violet: dark indigo vanished on dark ground)
    "Naoya Zenin": "E6B800",  # projection frames
    "Gohan": "FFE135",  # super saiyan gold
}
# the Rare aura's particle texture as a WHITE copy (same shape; work/rare_aura/RareFlameWhite.png, uploaded
# 2026-11-25) so ParticleEmitter.Color tints it exactly; and its rate per emitter (the pack's is 59/s)
RARE_TEXTURE = "rbxassetid://87752697532704"
RARE_RATE = 30
# the pack's particles have Brightness 10: on the white texture that turns indigo or purple to white
RARE_BRIGHTNESS = 2
TIER_OF = {"Epic": "C", "Legendary": "D", "Mythic": "E", "Premium": "E", "Secret": "E", "Rare": "B"}
ORDER = ["Secret", "Premium", "Mythic", "Legendary", "Epic", "Rare"]


def luau(path: Path, timeout: int = 900) -> str:
    out = subprocess.run([sys.executable, str(MCP), "luau", "--dm", "Edit", "--file", str(path)],
                         capture_output=True, text=True, encoding="utf-8", timeout=timeout)
    if out.returncode != 0:
        raise SystemExit(f"studio call failed:\n{out.stdout}\n{out.stderr}")
    return out.stdout.strip()


def read() -> None:
    WORK.mkdir(parents=True, exist_ok=True)
    code = WORK / "read_names.luau"
    code.write_text("""local HS = game:GetService("HttpService")
local out = { showcase = {}, packs = {} }
local showcase = workspace:FindFirstChild("AuraShowcase")
if not showcase then
  out.showcase = "GONE"
end
for _, m in (showcase and showcase.Auras:GetChildren() or {}) do
  table.insert(out.showcase, { name = m.Name, key = m:GetAttribute("AuraKey"), label = m:GetAttribute("Label"),
    hero = m:GetAttribute("Hero"), rank = m:GetAttribute("Rank") })
end
local ORIGIN = Vector3.new(-600, 320, -40) -- build_aura_pack_browser.luau: 10 columns, pitch 14
for _, m in workspace.AuraPackBrowser.Auras:GetChildren() do
  local p = m.Stand.Position - ORIGIN
  local c = math.floor(p.X / 14 + 4.5 + 0.5)
  local r = math.floor(p.Z / 14 + 0.5)
  table.insert(out.packs, { name = m.Name, unit = m:GetAttribute("Unit"), pack = m:GetAttribute("Pack"), index = r * 10 + c + 1 })
end
return "NAMES " .. HS:JSONEncode(out)
""", encoding="utf-8")
    text = luau(code, 120)
    data = json.loads(text[text.index("NAMES ") + 6:].strip())
    if data["showcase"] == "GONE":
        # the owner removed Workspace.AuraShowcase (2026-11-25): keep the names read from it before
        old = WORK / "names.json"
        data["showcase"] = json.loads(old.read_text(encoding="utf-8"))["showcase"] if old.exists() else []
        print("Workspace.AuraShowcase is gone: kept the showcase names read earlier")
    (WORK / "names.json").write_text(json.dumps(data, indent=1, ensure_ascii=False), encoding="utf-8")
    print(f"read {len(data['showcase'])} showcase stands, {len(data['packs'])} pack stands")


def heroes() -> list[dict]:
    md = LIST.read_text(encoding="utf-8").split("\n---")[0]
    rows, rarity = [], None
    for line in md.splitlines():
        m = re.match(r"## (\w+) \(", line)
        if m:
            rarity = m.group(1)
            continue
        c = [x.strip() for x in line.split("|")]
        if len(c) > 6 and c[1].isdigit():
            rows.append({"rarity": rarity, "name": c[2], "src": c[3], "zone": int(c[4]), "id": c[5]})
    return rows


def words(s: str) -> list[str]:
    return re.sub(r"[^a-z0-9 ]", "", s.lower()).split()


def plan() -> None:
    names = json.loads((WORK / "names.json").read_text(encoding="utf-8"))
    hs = heroes()
    by_id = {h["id"]: h for h in hs}
    tiers = json.loads(AURAS.read_text(encoding="utf-8"))["tiers"]

    def find(name: str) -> list[dict]:
        n = ALIAS.get(name.strip().lower(), name.strip())
        t = words(n)
        exact = [h for h in hs if words(h["src"]) == t]
        return exact or [h for h in hs if set(t) <= set(words(h["src"]))]

    auras: dict[str, dict] = {}
    claims: dict[str, list[str]] = {}
    notes: list[str] = []

    sources = {k: v.get("source") or "custom: " + v.get("custom", "")
               for k, v in json.loads(AURAS.read_text(encoding="utf-8"))["templates"].items()}

    def aura_ref_showcase(s: dict) -> str:
        ref = "S:" + s["key"]
        auras.setdefault(ref, {"ref": ref, "kind": "key", "key": s["key"], "label": s["key"],
                               "source": sources.get(s["key"], ""), **({"anchor": RAW_ANCHOR[s["key"]]} if s["key"] in RAW_ANCHOR else {})})
        return ref

    def claim(label: str, ref: str) -> None:
        for nm in [x.strip() for x in label.replace("+", ",").split(",") if x.strip()]:
            if nm.lower() in NOT_A_NAME:
                continue
            found = find(nm)
            if len(found) != 1:
                notes.append(f"'{nm}' matches no single hero ({', '.join(h['src'] for h in found) or 'none'}): ignored")
                continue
            claims.setdefault(found[0]["id"], []).append(ref)

    rare_ref = None
    nick: dict[str, str] = {}
    for s in names["showcase"]:
        if s["name"] == RARE_STAND:
            rare_ref = aura_ref_showcase(s)
        elif s["name"] != s["label"]:
            claim(s["name"], aura_ref_showcase(s))
        elif s.get("hero") and s.get("key"):
            nick[s["hero"]] = aura_ref_showcase(s)
    for p in names["packs"]:
        if p["name"] and not p["name"].startswith(p["unit"]):
            ref = f"P:{p['index']}"
            label = re.sub(r"^(POF:RE|PoF:Re|pof:re) AURA:?\s*", "", p["unit"], flags=re.I).strip() or p["unit"]
            auras.setdefault(ref, {"ref": ref, "kind": "pack", "index": p["index"], "pack": p["pack"],
                                   "unit": p["unit"], "label": label.title() if label.isupper() else label})
            claim(p["name"], ref)
    for hid, (ref, _) in PICKS.items():
        idx = int(ref[2:])
        p = next(p for p in names["packs"] if p["index"] == idx)
        label = re.sub(r"^(POF:RE|PoF:Re|pof:re) AURA:?\s*", "", p["unit"], flags=re.I).strip()
        auras.setdefault(ref, {"ref": ref, "kind": "pack", "index": idx, "pack": p["pack"], "unit": p["unit"],
                               "label": label.title() if label.isupper() else label})
    assert rare_ref, f"no stand named '{RARE_STAND}'"

    out = []
    for h in hs:
        r = h["rarity"]
        row = {"id": h["id"], "name": h["name"], "character": h["src"], "rarity": r, "zone": h["zone"]}
        mine = claims.get(h["id"], [])
        if h["id"] in CUSTOM:
            key, why = CUSTOM[h["id"]]
            ref = "S:" + key
            auras.setdefault(ref, {"ref": ref, "kind": "key", "key": key, "label": key, "source": sources.get(key, "")})
            row.update(aura=ref, why=why)
            # no STAGING: a hand-built aura's builder owns its whole look (a staged floor would stack under it)
            out.append(row)
            continue
        if r in ("Common", "Uncommon"):
            if mine:
                notes.append(f"{h['src']} is {r}: named on {', '.join(auras[m]['label'] for m in mine)}, but {r} wears no aura")
            continue
        if r == "Rare":
            row.update(aura=rare_ref, colour=RARE_COLOURS[h["src"]], why="Rare: the owner's Rare aura, in the hero's colour")
            if mine:
                notes.append(f"{h['src']} is Rare: named on {', '.join(auras[m]['label'] for m in mine)}; "
                             "given the Rare aura instead (owner's rule)")
        elif h["id"] in WEARS:
            ref, who = WEARS[h["id"]]
            if ref not in auras:
                raise SystemExit(f"WEARS {h['id']}: {ref} is not an aura on any stand")
            row.update(aura=ref, why=f"the owner gave it {who}'s aura")
        elif mine:
            pick = mine[0]
            if len(set(mine)) > 1:
                pick = TIEBREAK.get(h["id"], mine[0])
                if pick not in mine:
                    raise SystemExit(f"TIEBREAK for {h['id']} names {pick}, not one of {mine}")
                notes.append(f"{h['src']} was named on {len(mine)} stands ("
                             + ", ".join(auras[m]["label"] for m in mine) + f"): kept {auras[pick]['label']}")
            row.update(aura=pick, why="named by the owner")
            if h["id"] in EXTRAS:
                row["extras"] = EXTRAS[h["id"]]
            if h["id"] in PALETTES:
                row["palette"] = PALETTES[h["id"]]
        elif h["id"] in nick:
            row.update(aura=nick[h["id"]], why="not named: kept the aura it wore under its nickname")
        elif h["id"] in PICKS:
            row.update(aura=PICKS[h["id"]][0], why="not named: picked to suit it (" + PICKS[h["id"]][1] + ")")
        else:
            notes.append(f"{h['src']} ({r}) has no aura")
            continue
        if h["id"] in PALETTES and "palette" not in row:
            row["palette"] = PALETTES[h["id"]]
        row.update(STAGING.get(h["id"], {}))
        out.append(row)
    # each pack aura is converted at the tier of its rarest wearer
    rank = {r: i for i, r in enumerate(ORDER)}
    for a in auras.values():
        users = [o for o in out if o["aura"] == a["ref"]
                 or any(x["aura"] == a["ref"] for x in o.get("extras", []))]
        best = min((o["rarity"] for o in users), key=lambda r: rank[r], default="Epic")
        t = tiers[TIER_OF[best]]
        a.update(tier=TIER_OF[best], cap=t["cap"], size=t["size"], reach=t["reach"],
                 wearers=[o["character"] for o in users])
    for o in out:  # every fx needs these or the Studio builder dies on a nil (a comment once swallowed a key)
        for f in o.get("fx", []):
            missing = [k for k in ("texture", "size", "transparency", "colour", "life", "speed", "rate") if k not in f]
            if missing:
                raise SystemExit(f"STAGING {o['id']} fx {f.get('name')}: missing {missing}")
    used = {o["aura"] for o in out} | {x["aura"] for o in out for x in o.get("extras", [])}
    spec = {
        "_what": "PREVIEW of the owner's aura naming pass (2026-11-25); NOT wired into the game. "
                 "Made by tools/aura_assign.py; shown on Workspace.AuraAssignPreview.",
        "rules": "Common/Uncommon none; Rare = 'All Rare Characters' recoloured; Epic+ = named, else nickname aura, else a pick",
        "notes": notes,
        "auras": [a for a in auras.values() if a["ref"] in used],
        "heroes": out,
    }
    OUT.write_text(json.dumps(spec, indent=1, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    print(f"wrote {OUT.relative_to(ROOT)}: {len(out)} heroes, {len(spec['auras'])} auras")
    for n in notes:
        print("  note:", n)
    del by_id


def lua(v) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return json.dumps(v, ensure_ascii=False)
    if isinstance(v, list):
        return "{" + ", ".join(lua(x) for x in v) + "}"
    if isinstance(v, dict):
        return "{" + ", ".join(f"[{json.dumps(k)}] = {lua(x)}" for k, x in v.items()) + "}"
    raise TypeError(v)


def build() -> None:
    spec = json.loads(OUT.read_text(encoding="utf-8"))
    game = json.loads(GAME.read_text(encoding="utf-8"))
    colours = {k: v["Color"] for k, v in game["config"]["Rarities"].items()}
    colours["Premium"] = "FF5FA2"
    convert = CONVERT.read_text(encoding="utf-8").split("\nlocal assets = RS.Assets")[0]
    head = "_G.PREVIEW = " + lua({"auras": spec["auras"], "heroes": spec["heroes"], "colours": colours,
                                    "order": ORDER, "rareTexture": RARE_TEXTURE, "rareRate": RARE_RATE, "rareBrightness": RARE_BRIGHTNESS}) + "\n"
    only = [a.split("=", 1)[1] for a in sys.argv if a.startswith("--only=")]
    if only:  # rebuild just these heroes' stands (comma-separated ids); other stands are left alone
        head += "_G.PREVIEW.only = {" + ", ".join(f"[{json.dumps(i)}] = true" for i in only[0].split(",")) + "}\n"
    phases = ("build",) if "--skip-convert" in sys.argv else ("convert", "build")
    for phase in phases:
        f = WORK / f"preview_{phase}.luau"
        f.write_text(head + f'_G.PREVIEW.phase = "{phase}"\n' + convert + "\n"
                     + BUILDER.read_text(encoding="utf-8"), encoding="utf-8")
        print(luau(f))


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "all"
    if cmd in ("read", "all"):
        read()
    if cmd in ("plan", "all"):
        plan()
    if cmd in ("build", "all"):
        build()
