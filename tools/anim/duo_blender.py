"""Two rigs in one Blender scene: the carrier (the loaded rig, scale 1) and a carried hero made of COPIES of the
rig's own part meshes, scaled and placed per frame. Both are posed by the real Blender rig, nothing is a proxy.

  pass 1 (per hero clip):
    blender --background <rig> --enable-autoexec --python duo_blender.py -- track <hero_spec.json> <track.json>
      runs the skill's anim_render.py in dry mode (the Action is keyed exactly as for a render) and writes, for
      every clip frame, each part mesh's world matrix relative to the rest HumanoidRootPart.
  pass 2 (per carrier clip):
    blender ... --python duo_blender.py -- render <carrier_spec.json> <outdir> <duo.json> [--dry]
      duo.json = {"tracks": {"ride": "<track.json>", ...},
                  "frames": [{"track": "ride", "f": 0, "M": [[4x4]]}, ...]   one per carrier clip frame
                  "colour": [r, g, b]}
      M maps hero rig space (rest HumanoidRootPart = origin, scale 1) into carrier rig space and INCLUDES the hero
      scale. The hero part copies are keyed per frame, then scene_render.py (which adds _scene / _attach and runs
      anim_render.py) renders the carrier clip. At exit, a CLASH report measured on the real meshes: every
      carrier part x hero part pair as oriented boxes from each mesh's own bounds (separating-axis depth), worst
      frame per pair, plus the worst pair on every frame.
"""
import json
import os
import runpy
import sys

import bpy
import numpy as np
from mathutils import Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
argv = sys.argv[sys.argv.index("--") + 1:]
MODE = argv[0]
START = 10
PARTS = ["Head", "UpperTorso", "LowerTorso", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm",
         "LeftLowerArm", "LeftHand", "RightUpperLeg", "RightLowerLeg", "RightFoot", "LeftUpperLeg",
         "LeftLowerLeg", "LeftFoot"]
SKILL = os.path.join(os.path.expanduser("~/.claude/skills/roblox-animation/scripts"), "anim_render.py")

arm = next(o for o in bpy.data.objects
           if o.type == "ARMATURE" and "RightUpperLeg" in o.data.bones and "HumanoidRootPart" in o.data.bones)
sc = bpy.context.scene
sc.frame_set(0)
bpy.context.view_layer.update()
ORIGIN = (arm.matrix_world @ arm.pose.bones["HumanoidRootPart"].head).copy()
T_O, T_NO = Matrix.Translation(ORIGIN), Matrix.Translation(-ORIGIN)


def m2l(m):
    return [[float(m[i][j]) for j in range(4)] for i in range(4)]


def obb(o):
    """oriented box (centre, axes columns, half extents) of a mesh object from its local bounds, world space,
    relative to ORIGIN"""
    dg = bpy.context.evaluated_depsgraph_get()
    oe = o.evaluated_get(dg)
    mw = np.array(oe.matrix_world)
    bb = np.array([list(c) for c in oe.bound_box])
    lo, hi = bb.min(0), bb.max(0)
    c = mw[:3, :3] @ ((lo + hi) / 2) + mw[:3, 3] - np.array(ORIGIN)
    ax, half = [], []
    for i in range(3):
        v = mw[:3, i] * (hi[i] - lo[i]) / 2
        n = np.linalg.norm(v)
        ax.append(v / n if n > 1e-9 else np.eye(3)[i])
        half.append(n)
    return c, np.array(ax).T, np.array(half)


def depth(a, b):
    ca, A, ha = a
    cb, B, hb = b
    d = cb - ca
    axes = [A[:, i] for i in range(3)] + [B[:, i] for i in range(3)]
    for i in range(3):
        for j in range(3):
            v = np.cross(A[:, i], B[:, j])
            n = np.linalg.norm(v)
            if n > 1e-6:
                axes.append(v / n)
    best = 1e9
    for x in axes:
        ov = sum(ha[i] * abs(x @ A[:, i]) for i in range(3)) + sum(hb[i] * abs(x @ B[:, i]) for i in range(3)) - abs(x @ d)
        if ov <= 0:
            return 0.0
        best = min(best, ov)
    return best


def run_skill(spec_path, outdir, wrapper=None):
    sys.argv = [sys.argv[0], "--", spec_path, outdir]
    runpy.run_path(wrapper or SKILL, run_name="__main__")


if MODE == "track":
    spec_path, out = argv[1], argv[2]
    spec = json.load(open(spec_path))
    spec["dry"] = True
    tmp = out + ".spec.json"
    json.dump(spec, open(tmp, "w"))
    nfr = int(round(spec["duration"] * spec.get("fps", 30))) + (0 if spec.get("loop") else 1)
    _real_exit = os._exit

    def _dump(code):
        if code == 0:
            frames = []
            for i in range(nfr):
                sc.frame_set(START + i)
                bpy.context.view_layer.update()
                dg = bpy.context.evaluated_depsgraph_get()
                frames.append({p: m2l(T_NO @ bpy.data.objects[p].evaluated_get(dg).matrix_world) for p in PARTS})
            json.dump({"spec": spec["name"], "frames": frames}, open(out, "w"))
            print(f"=== TRACK {spec['name']}: {nfr} frames -> {out}")
            sys.stdout.flush()
        _real_exit(code)

    os._exit = _dump
    run_skill(tmp, os.path.join(os.path.dirname(out), "_track_frames"))
    _dump(0)

elif MODE == "render":
    spec_path, outdir, duo_path = argv[1], argv[2], argv[3]
    DRY = "--dry" in argv
    duo = json.load(open(duo_path))
    tracks = {k: json.load(open(v))["frames"] for k, v in duo["tracks"].items()}
    col = duo.get("colour", [0.95, 0.55, 0.15])
    mat = bpy.data.materials.new("HeroOrange")
    mat.use_nodes = True
    b = mat.node_tree.nodes.get("Principled BSDF")
    if b:
        b.inputs["Base Color"].default_value = (col[0], col[1], col[2], 1)
        b.inputs["Roughness"].default_value = 0.6
    copies = {}
    for p in PARTS:
        src = bpy.data.objects[p]
        o = bpy.data.objects.new("Hero_" + p, src.data.copy())
        bpy.context.collection.objects.link(o)
        o.data.materials.clear()
        o.data.materials.append(mat)
        o["prop_keep_material"] = True
        o.rotation_mode = "QUATERNION"
        copies[p] = o
    for i, fr in enumerate(duo["frames"]):
        M = Matrix(fr["M"])
        mats = tracks[fr["track"]][fr["f"]]
        for p, o in copies.items():
            o.matrix_world = T_O @ M @ Matrix(mats[p])
            for path in ("location", "rotation_quaternion", "scale"):
                o.keyframe_insert(path, frame=START + i)
    for o in copies.values():
        for fc in o.animation_data.action.fcurves:
            for k in fc.keyframe_points:
                k.interpolation = "CONSTANT"
    nfr = len(duo["frames"])
    allow = {tuple(x) for x in duo.get("allow", [])}     # (carrier part, hero part) pairs allowed to touch (grip)
    _real_exit = os._exit

    def _clash(code):
        if code == 0:
            worst_pair, per_frame = {}, []
            for i in range(nfr):
                sc.frame_set(START + i)
                bpy.context.view_layer.update()
                C = {p: obb(bpy.data.objects[p]) for p in PARTS}
                H = {p: obb(copies[p]) for p in PARTS}
                fw = (0.0, "", "")
                for cp, cb in C.items():
                    for hp, hb in H.items():
                        d = depth(cb, hb)
                        if d <= 0:
                            continue
                        key = (cp, hp)
                        if d > worst_pair.get(key, (0, 0))[0]:
                            worst_pair[key] = (d, i)
                        if key not in allow and d > fw[0]:
                            fw = (d, cp, hp)
                per_frame.append(fw)
            print("=== CLASH (real meshes, carrier part x hero part, oriented-box depth, studs)")
            for (cp, hp), (d, i) in sorted(worst_pair.items(), key=lambda kv: -kv[1][0]):
                tag = " (allowed: grip)" if (cp, hp) in allow else ""
                print(f"    {cp:14s} x hero {hp:14s} {d:.3f} at frame {i}{tag}")
            if not worst_pair:
                print("    none: no carrier part touches any hero part on any frame")
            w = max(per_frame, key=lambda x: x[0])
            print(f"=== CLASH worst not-allowed: {w[0]:.3f} {w[1]} x hero {w[2]}")
            print("    per frame: " + " ".join(f"{i}:{x[0]:.2f}" for i, x in enumerate(per_frame)))
            sys.stdout.flush()
        _real_exit(code)

    os._exit = _clash
    spec = json.load(open(spec_path))
    if DRY:
        spec["dry"] = True
        tmp = os.path.join(outdir, "_dry_" + os.path.basename(spec_path))
        os.makedirs(outdir, exist_ok=True)
        json.dump(spec, open(tmp, "w"))
        spec_path = tmp
    run_skill(spec_path, outdir, wrapper=os.path.join(HERE, "scene_render.py"))
    _clash(0)
