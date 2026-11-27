"""Blender (4.5): the batch r7 food stand-ins as GLB files, at the sizes the brief gives.

  blender --background --python tools/anim/r7_props.py -- <outdir>

  ball.glb  sphere r 0.9 (pitch: rice ball, apple, burger)
  bowl.glb  cylinder d 2.6 x 1.1 tall with a 0.12 rim lip drawn INSIDE the envelope (heave: bowls, pots, trays)
  disc.glb  cylinder d 2.4 x 0.3 thick (spin: pizza, toast, a skewer)

Authored Blender Z-up with the centre at the origin, so the prop's own frame is the food's centre and its
flat axis is the prop's +Z (Roblox +Y after anim_render's axis map).
"""
import os
import sys

import bpy

out = sys.argv[sys.argv.index("--") + 1]
os.makedirs(out, exist_ok=True)


def clear():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)


def export(name):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(out, name + ".glb"), export_format="GLB", use_selection=True)
    print("wrote", os.path.join(out, name + ".glb"))


clear()
bpy.ops.mesh.primitive_uv_sphere_add(radius=0.9, segments=32, ring_count=16)
bpy.ops.object.shade_smooth()
export("ball")

clear()
bpy.ops.mesh.primitive_cylinder_add(radius=1.3, depth=1.1, vertices=48)
bpy.ops.mesh.primitive_cylinder_add(radius=1.1, depth=0.12, vertices=48, location=(0, 0, 0.5))   # soup surface
export("bowl")

clear()
bpy.ops.mesh.primitive_cylinder_add(radius=1.2, depth=0.3, vertices=48)
export("disc")
sys.stdout.flush()
os._exit(0)
