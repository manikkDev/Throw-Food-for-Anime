"""Renders the cloak round a stand-in R15 body (front, side, back, three-quarter) to check its shape and clearance.

    <blender 4.5> -b --python tools/auras/almighty/preview_cloak.py -- <cloak.obj> <out.png>
Roblox axes in the OBJ (x right, y up, front -Z); here imported Y-up so Blender sees x, -z, y.
"""
import math
import sys

import bpy

src, dst = sys.argv[sys.argv.index("--") + 1:][:2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.obj_import(filepath=src, forward_axis="NEGATIVE_Z", up_axis="Y")
cloak = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
for p in cloak.data.polygons:
    p.use_smooth = True
mat = bpy.data.materials.new("ink")
mat.diffuse_color = (0.05, 0.05, 0.08, 1)
cloak.data.materials.append(mat)


def box(name, lo, hi, colour):
    # lo/hi in ROBLOX axes -> Blender (x, -z, y)
    cx, cy, cz = [(a + b) / 2 for a, b in zip(lo, hi)]
    sx, sy, sz = [(b - a) for a, b in zip(lo, hi)]
    bpy.ops.mesh.primitive_cube_add(location=(cx, -cz, cy))
    o = bpy.context.active_object
    o.name = name
    o.scale = (sx / 2, sz / 2, sy / 2)
    m = bpy.data.materials.new(name)
    m.diffuse_color = colour
    o.data.materials.append(m)


skin = (0.85, 0.7, 0.6, 1)
coat = (0.9, 0.9, 0.92, 1)
box("Head", (-0.6, 0.98, -0.6), (0.6, 2.19, 0.6), skin)
box("Torso", (-1, -1.0, -0.5), (1, 1.0, 0.5), coat)
box("LArm", (-2, -1.0, -0.5), (-1, 0.95, 0.5), coat)
box("RArm", (1, -1.0, -0.5), (2, 0.95, 0.5), coat)
box("LLeg", (-1, -3, -0.5), (0, -1.0, 0.5), coat)
box("RLeg", (0, -3, -0.5), (1, -1.0, 0.5), coat)
box("Floor", (-5, -3.1, -5), (5, -3.0, 5), (0.35, 0.55, 0.3, 1))

scene = bpy.context.scene
try:
    scene.render.engine = "BLENDER_WORKBENCH"
except TypeError:
    pass
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "MATERIAL"
scene.display.shading.show_cavity = True
scene.render.resolution_x = 640
scene.render.resolution_y = 640
cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = 8.5
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam

views = {"front": (0, 12, 0), "side": (-90, 12, 0), "back": (180, 12, 0), "three_quarter": (-40, 22, 0)}
import os
tiles = []
for name, (yaw, pitch, _) in views.items():
    # Roblox front is -Z = Blender +Y; a camera in front looks along -Y... place it at +Y looking back
    r = 14
    ya, pa = math.radians(yaw), math.radians(pitch)
    x = r * math.sin(ya) * math.cos(pa)
    y = r * math.cos(ya) * math.cos(pa)
    z = -0.6 + r * math.sin(pa)
    cam.location = (x, y, z)
    direction = (-x, -y, -0.6 - z)
    import mathutils
    cam.rotation_euler = mathutils.Vector(direction).to_track_quat("-Z", "Y").to_euler()
    path = os.path.splitext(dst)[0] + f"_{name}.png"
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    tiles.append(path)
print("rendered", tiles)
