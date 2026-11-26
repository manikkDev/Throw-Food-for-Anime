"""One OBJ (Roblox axes: x right, y up, front -Z) -> FBX for an Open Cloud Model upload, smooth shaded.
Same axis handling as the roblox-vfx skill's sim/mesh/obj_to_fbx.py (measured in Studio: without the half turn
about up, OBJ -Z lands on Roblox +Z).

    <blender 4.5> -b --python tools/auras/almighty/obj_to_fbx_one.py -- <in.obj> <out.fbx>
"""
import math
import sys

import bpy

src, dst = sys.argv[sys.argv.index("--") + 1:][:2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.obj_import(filepath=src, forward_axis="NEGATIVE_Z", up_axis="Y")
objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in objs:
    o.select_set(True)
    o.rotation_euler[2] += math.pi
bpy.context.view_layer.objects.active = objs[0]
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
o = bpy.context.view_layer.objects.active
for p in o.data.polygons:
    p.use_smooth = True
xs = [v.co for v in o.data.vertices]
lo = [min(c[i] for c in xs) for i in range(3)]
hi = [max(c[i] for c in xs) for i in range(3)]
bpy.ops.export_scene.fbx(
    filepath=dst, use_selection=False, object_types={"MESH"},
    axis_forward="-Z", axis_up="Y", apply_unit_scale=True, apply_scale_options="FBX_SCALE_NONE",
    bake_space_transform=True, mesh_smooth_type="FACE", path_mode="STRIP", embed_textures=False,
)
print(f"FBX {dst}: verts {len(xs)} tris {sum(len(p.vertices) - 2 for p in o.data.polygons)} "
      f"size(xyz roblox) {hi[0]-lo[0]:.3f} {hi[2]-lo[2]:.3f} {hi[1]-lo[1]:.3f}")
