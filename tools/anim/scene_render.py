"""Blender wrapper around the skill's anim_render.py that adds STATIC set dressing and bone-parented
props before the render, so contact can be judged on the sheet (a fist on the bag, palms on the boulder,
dumbbells in the hands).

  blender --background <rig> --enable-autoexec --python scene_render.py -- <spec.json> <outdir>

Spec fields (ignored by to_roblox.py and rbx_axis_check.py):
  "_scene":  [{"pos": [x, y, z], "size": [sx, sy, sz], "colour": [r, g, b]}]   rig space (+X right,
             +Y forward, +Z up, origin = rest HumanoidRootPart), box centre and full size
  "_attach": [{"bone": "LeftHand", "pos": [...], "size": [...], "colour": [...]}]  boxes placed in rig
             space AT REST and parented to that deform bone, so they follow it on every frame
  optional per item: "shape": "sphere" (size = diameters), "show": [first, end) clip frames it is visible
  "_track":  [{"glb": path, "colour": [r, g, b], "frames": [[12 floats: rotation rows (3x3, rig axes) + centre
             (rig space)] per clip frame]}]  an object keyed per frame (e.g. a bowl placed from BOTH hands, which
             no single-bone weld can show); after the last listed frame it holds (a thrown object left in the air)
"""
import json
import math
import os
import runpy
import sys

import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
spec = json.load(open(argv[0]))
SCRIPT = os.path.join(os.path.expanduser("~/.claude/skills/roblox-animation/scripts"), "anim_render.py")

arm = next(o for o in bpy.data.objects
           if o.type == "ARMATURE" and "RightUpperLeg" in o.data.bones and "HumanoidRootPart" in o.data.bones)
bpy.context.scene.frame_set(0)
bpy.context.view_layer.update()
ORIGIN = arm.matrix_world @ arm.pose.bones["HumanoidRootPart"].head


def box(item, name):
    if item.get("shape") == "sphere":     # "size" is then the diameter on each axis
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.5, segments=24, ring_count=12)
        bpy.ops.object.shade_smooth()
    else:
        bpy.ops.mesh.primitive_cube_add(size=1.0)
    o = bpy.context.active_object
    o.name = name
    o.scale = tuple(item["size"])
    o.location = ORIGIN + Vector(item["pos"])
    if "rot" in item:                 # optional XYZ Euler (deg) at rest, e.g. to undo a posed hand's turn
        o.rotation_euler = [math.radians(a) for a in item["rot"]]
    col = item.get("colour", [0.55, 0.4, 0.3])
    mat = bpy.data.materials.new(name + "_M")
    mat.use_nodes = True
    b = mat.node_tree.nodes.get("Principled BSDF")
    if b:
        b.inputs["Base Color"].default_value = (col[0], col[1], col[2], 1)
        b.inputs["Roughness"].default_value = 0.6
    o.data.materials.append(mat)
    o["prop_keep_material"] = True
    return o


def show_keys(o, item):
    """[first, end) clip frames the prop is visible on (render frame = 10 + clip frame); keyed AFTER the
    prop is placed and parented (keying before the bone-parenting left the prop at scale 1, misplaced)"""
    if "show" not in item:
        return
    a, b = item["show"]
    for f, hide in ((0, True), (10 + a, False), (10 + b, True)):
        o.hide_render = hide
        o.hide_viewport = hide
        o.keyframe_insert("hide_render", frame=f)
        o.keyframe_insert("hide_viewport", frame=f)
    for fc in o.animation_data.action.fcurves:
        for k in fc.keyframe_points:
            k.interpolation = "CONSTANT"


for i, it in enumerate(spec.get("_scene", [])):
    show_keys(box(it, f"Scene{i}"), it)
bpy.context.view_layer.update()
for i, it in enumerate(spec.get("_attach", [])):
    o = box(it, f"Attach{i}")
    bpy.context.view_layer.update()
    world = o.matrix_world.copy()
    o.parent = arm
    o.parent_type = "BONE"
    o.parent_bone = it["bone"]
    bpy.context.view_layer.update()
    o.matrix_world = world          # keep the rest placement; Blender solves the bone-relative offset
    bpy.context.view_layer.update()
    show_keys(o, it)

def track_items():
    for ti, it in enumerate(spec.get("_track", [])):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=it["glb"])
        meshes = [o for o in set(bpy.data.objects) - before if o.type == "MESH"]
        col = it.get("colour", [0.8, 0.4, 0.2])
        mat = bpy.data.materials.new(f"Track{ti}_M")
        mat.use_nodes = True
        b = mat.node_tree.nodes.get("Principled BSDF")
        if b:
            b.inputs["Base Color"].default_value = (col[0], col[1], col[2], 1)
        holder = bpy.data.objects.new(f"Track{ti}", None)
        bpy.context.collection.objects.link(holder)
        for o in meshes:
            o.parent = None
            bpy.context.view_layer.update()
            bpy.ops.object.select_all(action="DESELECT")
            o.select_set(True)
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
            o.data.materials.clear()
            o.data.materials.append(mat)
            o.parent = holder
            o["prop_keep_material"] = True
        n = int(round(spec["duration"] * spec.get("fps", 30))) + (0 if spec.get("loop") else 1)
        fr_ = it["frames"]
        for i in range(n):
            m = fr_[min(i, len(fr_) - 1)]
            M4 = Matrix(((m[0], m[1], m[2], m[9] + ORIGIN.x), (m[3], m[4], m[5], m[10] + ORIGIN.y),
                         (m[6], m[7], m[8], m[11] + ORIGIN.z), (0, 0, 0, 1)))
            holder.matrix_world = M4
            holder.keyframe_insert("location", frame=10 + i)
            holder.rotation_mode = "XYZ"
            holder.keyframe_insert("rotation_euler", frame=10 + i)


track_items()


def contact_report():
    """GROUND TRUTH from Blender's own meshes: at each marker, the frontmost (+Y) vertex of each hand
    mesh relative to the rest HumanoidRootPart, and the lowest foot vertex vs the floor (z -3.0)."""
    sc = bpy.context.scene
    fps = spec.get("fps", 30)
    dg = bpy.context.evaluated_depsgraph_get()
    print("=== CONTACT (Blender meshes; rig space, y = along the facing from the HumanoidRootPart)")
    for m in spec.get("markers", []):
        sc.frame_set(10 + int(round(m["time"] * fps)))
        bpy.context.view_layer.update()
        cells = []
        for part in ("RightHand", "LeftHand"):
            o = bpy.data.objects.get(part)
            if o is None:
                continue
            oe = o.evaluated_get(dg)
            vs = [oe.matrix_world @ v.co - ORIGIN for v in oe.data.vertices]
            fy = max(v.y for v in vs)
            cells.append(f"{part} front-y {fy:.3f} (z {min(v.z for v in vs):.2f}..{max(v.z for v in vs):.2f}, "
                         f"x {min(v.x for v in vs):.2f}..{max(v.x for v in vs):.2f})")
        for o in bpy.data.objects:      # props: where they are, how big, whether they render
            if o.name.startswith(("Attach", "Scene")):
                oe = o.evaluated_get(dg)
                c = oe.matrix_world.translation - ORIGIN
                sx = oe.matrix_world.to_scale()
                cells.append(f"{o.name} at ({c.x:.3f}, {c.y:.3f}, {c.z:.3f}) scale ({sx.x:.2f}, {sx.y:.2f}, "
                             f"{sx.z:.2f}) {'hidden' if oe.hide_render else 'shown'}")
        ho = bpy.data.objects.get("RightHand")
        if ho is not None:
            he = ho.evaluated_get(dg)
            vs = [he.matrix_world @ v.co - ORIGIN for v in he.data.vertices]
            cc = [(min(v[i] for v in vs) + max(v[i] for v in vs)) / 2 for i in range(3)]
            cells.append(f"RightHand bbox centre ({cc[0]:.3f}, {cc[1]:.3f}, {cc[2]:.3f})")
        print(f"    {m['name']} t={m['time']}: " + " | ".join(cells))
    sys.stdout.flush()


_real_exit = os._exit


def _exit_hook(code):
    if code == 0:
        contact_report()
    _real_exit(code)


os._exit = _exit_hook
sys.argv = [sys.argv[0], "--", *argv]
runpy.run_path(SCRIPT, run_name="__main__")
contact_report()
