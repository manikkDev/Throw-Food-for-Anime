"""Render Roblox-ready GLBs in Blender 4.5 (env BLENDER), for judging by eye.

  blender --background --python render.py -- --mode views --out a.png  m.glb
  blender --background --python render.py -- --mode row   --out sheet.png --char a.glb b.glb ...
  blender --background --python render.py -- --mode icon  --out icon.png --size 256 m.glb

views : one model, four views (front, 3/4 front, side, back 3/4) in one image.
row   : models in a row at ONE scale, standing on the ground, optional 4x5.5 character box first.
icon  : one model, transparent background, three-quarter view, square.

Colour: glTF base colours are linear; the view transform is Standard so the
saved PNG's sRGB pixels equal the authored hex on a fully lit flat face.
"""
import argparse
import math
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("--mode", default="views")
ap.add_argument("--out", default="")
ap.add_argument("--size", type=int, default=0)
ap.add_argument("--char", action="store_true")
ap.add_argument("--gap", type=float, default=1.5)
ap.add_argument("--labels", default="")
ap.add_argument("--outline", type=float, default=0.0, help="freestyle line px, 0 = off")
ap.add_argument("--az", type=float, default=0)
ap.add_argument("--spin", type=float, default=30)
ap.add_argument("--el", type=float, default=14)
ap.add_argument("--outdir", default="")
ap.add_argument("glbs", nargs="+")
a = ap.parse_args(argv)
import os
a.out = os.path.abspath(a.out)
a.glbs = [os.path.abspath(g) for g in a.glbs]

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
try:
    scene.render.engine = "BLENDER_EEVEE_NEXT"
except TypeError:
    scene.render.engine = "BLENDER_EEVEE"
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "None"
world = bpy.data.worlds.new("W")
scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
bg.inputs[0].default_value = (0.42, 0.5, 0.62, 1)
bg.inputs[1].default_value = 1.0


def import_glb(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    objs = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in objs if o.type == "MESH"]
    for o in meshes:
        for m in o.data.materials:
            if not m or not m.use_nodes:
                continue
            p = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
            if p:
                p.inputs["Roughness"].default_value = 0.75
                p.inputs["Metallic"].default_value = 0.0
                if "Specular IOR Level" in p.inputs:
                    p.inputs["Specular IOR Level"].default_value = 0.25
    root = bpy.data.objects.new("Asset", None)
    scene.collection.objects.link(root)
    for o in objs:
        if o.parent is None:
            o.parent = root
    bpy.context.view_layer.update()
    return root, meshes


def bbox(meshes):
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in meshes:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


def add_lights():
    sun = bpy.data.lights.new("Key", "SUN")
    sun.energy = 2.3
    so = bpy.data.objects.new("Key", sun)
    so.rotation_euler = (math.radians(50), 0, math.radians(-35 + 180))
    scene.collection.objects.link(so)
    fill = bpy.data.lights.new("Fill", "SUN")
    fill.energy = 0.7
    fill.angle = math.radians(30)
    fo = bpy.data.objects.new("Fill", fill)
    fo.rotation_euler = (math.radians(70), 0, math.radians(120 + 180))
    scene.collection.objects.link(fo)


def add_ground(lo, hi, z=0.0):
    bpy.ops.mesh.primitive_plane_add(size=1, location=((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, z - 0.001))
    g = bpy.context.object
    g.scale = (2000, 2000, 1)
    m = bpy.data.materials.new("Ground")
    m.use_nodes = True
    p = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    p.inputs["Base Color"].default_value = (0.3, 0.36, 0.45, 1)
    p.inputs["Roughness"].default_value = 1.0
    g.data.materials.append(m)


def camera(az_deg, el_deg, lo, hi, aspect, margin=1.08):
    cam = bpy.data.cameras.new("Cam")
    cam.type = "ORTHO"
    co = bpy.data.objects.new("Cam", cam)
    scene.collection.objects.link(co)
    scene.camera = co
    # Roblox front (-Z) imports as Blender +Y; az 0 = looking at the front.
    az, el = math.radians(az_deg), math.radians(el_deg)
    d = Vector((math.sin(az) * math.cos(el), math.cos(az) * math.cos(el), math.sin(el)))
    centre = (lo + hi) / 2
    co.location = centre + d * 100
    co.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    bpy.context.view_layer.update()
    inv = co.matrix_world.inverted()
    xs, ys = [], []
    for x in (lo.x, hi.x):
        for y in (lo.y, hi.y):
            for z in (lo.z, hi.z):
                p = inv @ Vector((x, y, z))
                xs.append(p.x)
                ys.append(p.y)
    w, h = max(xs) - min(xs), max(ys) - min(ys)
    cx, cy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
    co.location = co.matrix_world @ Vector((cx, cy, 0))
    cam.ortho_scale = max(w, h * aspect) * margin
    cam.clip_end = 1000
    co["fit"] = (w, h)
    return co


def text(s, loc, size):
    cu = bpy.data.curves.new("T", "FONT")
    cu.body = s
    cu.size = size
    cu.align_x = "CENTER"
    t = bpy.data.objects.new("T", cu)
    t.location = loc
    t.rotation_euler = (0, 0, math.radians(180))
    m = bpy.data.materials.new("Ink")
    m.use_nodes = True
    p = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    p.inputs["Base Color"].default_value = (0.006, 0.007, 0.03, 1)
    cu.materials.append(m)
    scene.collection.objects.link(t)


def char_box(x0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x0 + 2.0, 0, 2.75))
    c = bpy.context.object
    c.scale = (4, 1.5, 5.5)
    m = bpy.data.materials.new("Char")
    m.use_nodes = True
    p = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    p.inputs["Base Color"].default_value = (0.25, 0.27, 0.32, 1)
    c.data.materials.append(m)
    return c


def outline(px):
    scene.render.use_freestyle = True
    scene.render.line_thickness_mode = "ABSOLUTE"
    scene.render.line_thickness = px
    vl = bpy.context.view_layer
    ls = vl.freestyle_settings.linesets[0] if vl.freestyle_settings.linesets else vl.freestyle_settings.linesets.new("L")
    ls.select_by_visibility = True
    ls.select_silhouette = True
    ls.select_border = True
    ls.select_crease = False
    ls.linestyle.color = (0.006, 0.007, 0.03)


def render(path, w, h, transparent=False):
    scene.render.resolution_x = w
    scene.render.resolution_y = h
    scene.render.film_transparent = transparent
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA" if transparent else "RGB"
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


add_lights()
if a.outline > 0:
    outline(a.outline)

if a.mode == "views":
    root, meshes = import_glb(a.glbs[0])
    lo, hi = bbox(meshes)
    add_ground(lo, hi, lo.z)
    tiles = []
    import os
    base = os.path.splitext(a.out)[0]
    for i, (az, el) in enumerate(((0, 8), (35, 25), (90, 10), (180 + 35, 25))):
        co = camera(az, el, lo, hi, 1.0)
        p = f"{base}_v{i}.png"
        render(p, a.size or 512, a.size or 512)
        tiles.append(p)
        bpy.data.objects.remove(co)
    # stitch 2x2 with Blender's image API (no PIL in Blender's Python)
    n = a.size or 512
    imgs = [bpy.data.images.load(t) for t in tiles]
    out = bpy.data.images.new("sheet", n * 2, n * 2)
    px = [0.0] * (n * 2 * n * 2 * 4)
    for k, im in enumerate(imgs):
        src = list(im.pixels)
        ox, oy = (k % 2) * n, (1 - k // 2) * n
        for row in range(n):
            d = ((oy + row) * n * 2 + ox) * 4
            s = row * n * 4
            px[d:d + n * 4] = src[s:s + n * 4]
    out.pixels = px
    out.filepath_raw = a.out
    out.file_format = "PNG"
    out.save()
    for t in tiles:
        os.remove(t)
elif a.mode == "row":
    labels = a.labels.split(",") if a.labels else []
    x = 0.0
    all_lo, all_hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    if a.char:
        c = char_box(x - 4)
        text("char 4x5.5", Vector((x - 2.0, 1.1, 0.02)), 0.6)
        all_lo, all_hi = Vector((x - 4, -0.75, 0)), Vector((x, 0.75, 5.5))
        x -= 4 + a.gap
    for i, g in enumerate(a.glbs):
        root, meshes = import_glb(g)
        root.rotation_euler = (0, 0, math.radians(a.spin))
        bpy.context.view_layer.update()
        lo, hi = bbox(meshes)
        ground = a.char  # gear stands on y=0; foods are centred, so drop them onto the ground
        root.location = (x - hi.x, 0, 0 if ground else -lo.z)
        bpy.context.view_layer.update()
        lo, hi = bbox(meshes)
        if i < len(labels):
            text(labels[i], Vector(((lo.x + hi.x) / 2, hi.y + 0.3, 0.02)), 0.6 if a.char else 0.28)
        all_lo = Vector(map(min, all_lo, lo))
        all_hi = Vector(map(max, all_hi, hi))
        x = lo.x - a.gap
    add_ground(all_lo, all_hi, 0.0)
    lo2 = all_lo.copy()
    W = a.size or 3200
    co = camera(a.az, a.el, lo2, all_hi, 1.0, margin=1.0)
    w, h = co["fit"]
    co.data.ortho_scale = w * 1.04
    render(a.out, W, int(W * h * 1.08 / (w * 1.04)))
elif a.mode == "icon":
    root, meshes = import_glb(a.glbs[0])
    lo, hi = bbox(meshes)
    camera(35, 28, lo, hi, 1.0, margin=1.12)
    n = a.size or 256
    render(a.out, n, n, transparent=True)
elif a.mode == "icons":
    # one transparent three-quarter icon per GLB, written as <outdir>/<stem>.png
    n = a.size or 256
    for g in a.glbs:
        for o in [o for o in bpy.data.objects if o.type in ("MESH", "EMPTY", "CAMERA")]:
            bpy.data.objects.remove(o)
        root, meshes = import_glb(g)
        lo, hi = bbox(meshes)
        co = camera(35, 28, lo, hi, 1.0, margin=1.1)
        render(os.path.join(os.path.abspath(a.outdir), os.path.splitext(os.path.basename(g))[0] + ".png"), n, n, transparent=True)
