"""Blender 4.5: render Roblox-frame GLBs three-quarter, or a zone contact sheet, and measure them.

blender --background --python render_zone.py -- --out x.png [--sheet] [--json m.json] a.glb b.glb ...

Colour comes from the _RRGGBB suffix of each material name (the hex the converter carries),
not from baseColorFactor, so the render shows what the name promises. --json writes measured
tris / bounds (in studs, Roblox frame: x width, y up, z depth) per GLB, re-imported in Blender.
--sheet lays the props in a row left to right with a 4 x 5.5 x 2 character box, one scale.
"""
import bpy, sys, re, json, math, os
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
out = argv[argv.index("--out") + 1]
sheet = "--sheet" in argv
jpath = argv[argv.index("--json") + 1] if "--json" in argv else None
skip = {out, jpath}
glbs = [a for a in argv if a.lower().endswith(".glb")]

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def srgb(h):
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


measures = {}
groups = []
for path in glbs:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    objs = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    lo = Vector((1e9,) * 3); hi = Vector((-1e9,) * 3); tris = 0; parts = []
    for o in objs:
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
        o.data.calc_loop_triangles()
        tris += len(o.data.loop_triangles)
        for ms in o.material_slots:
            m = ms.material
            hx = re.search(r"_([0-9A-Fa-f]{6})(\.\d+)?$", m.name)
            if hx:
                c = srgb(hx.group(1))
                m.diffuse_color = (*[lin(x) for x in c], 1)
                bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None) if m.node_tree else None
                fac = list(bsdf.inputs["Base Color"].default_value)[:3] if bsdf else None
                parts.append({"part": m.name.split(".")[0], "hex": "#" + hx.group(1).upper(),
                              "baseColorFactor_linear": [round(x, 4) for x in fac] if fac else None})
    # Blender Z-up -> Roblox: x, y=Bz, z=-By
    name = os.path.basename(path)[:-4]
    measures[name] = {"tris": tris, "mesh_objects": len(objs),
                      "bounds_studs": [round(hi.x - lo.x, 3), round(hi.z - lo.z, 3), round(hi.y - lo.y, 3)],
                      "min_studs": [round(lo.x, 3), round(lo.z, 3), round(-hi.y, 3)],
                      "max_studs": [round(hi.x, 3), round(hi.z, 3), round(-lo.y, 3)],
                      "parts": parts}
    groups.append((name, objs, lo.copy(), hi.copy()))

if jpath:
    with open(jpath, "w") as f:
        json.dump(measures, f, indent=1)

# Lay out: in sheet mode, a row along X with gaps; character box first.
GAP = 4.0
if sheet:
    x = 0.0
    bpy.ops.mesh.primitive_cube_add(size=1)
    cb = bpy.context.object
    cb.scale = (4, 2, 5.5)
    cb.location = (x + 2, 0, 2.75)
    m = bpy.data.materials.new("CharBox"); m.diffuse_color = (0.9, 0.9, 0.95, 0.35)
    cb.data.materials.append(m)
    x += 4 + GAP
    for name, objs, lo, hi in groups:
        dx = x - lo.x
        roots = set()
        for o in objs:
            while o.parent is not None:
                o = o.parent
            roots.add(o)
        for r in roots:
            r.location.x += dx
        bpy.context.view_layer.update()
        x += (hi.x - lo.x) + GAP
    span = x - GAP
else:
    span = None

# Ground
bpy.ops.mesh.primitive_plane_add(size=2000)
g = bpy.context.object
gm = bpy.data.materials.new("Ground"); gm.diffuse_color = (0.55, 0.6, 0.62, 1)
g.data.materials.append(gm)

FLAT = "--flat" in argv  # exact albedo, for colour sampling
if FLAT:
    scene.render.engine = "BLENDER_WORKBENCH"
    sh = scene.display.shading
    sh.light = "FLAT"
    sh.color_type = "MATERIAL"
else:
    # EEVEE, sun + sky fill: roughly Roblox daylight. Matte materials (no glossy highlight).
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE"
    for m in bpy.data.materials:
        if m.node_tree:
            b = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
            if b:
                b.inputs["Roughness"].default_value = 0.9
                for k in ("Specular IOR Level", "Specular"):
                    if k in b.inputs:
                        b.inputs[k].default_value = 0.1
                b.inputs["Metallic"].default_value = 0.0
    gm.use_nodes = True
    gb = next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    gb.inputs["Base Color"].default_value = (0.32, 0.36, 0.38, 1)
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 2.5
    sun.data.angle = math.radians(4)
    sun.rotation_euler = (math.radians(40), math.radians(-12), math.radians(150))
    scene.collection.objects.link(sun)
    scene.world = bpy.data.worlds.new("W")
    scene.world.use_nodes = True
    bg = next(n for n in scene.world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.75, 0.85, 1.0, 1)
    bg.inputs["Strength"].default_value = 0.9
    try:
        scene.eevee.use_shadows = True
    except AttributeError:
        pass
    scene.render.film_transparent = False
scene.view_settings.view_transform = "Standard"

# Bounds of everything
lo = Vector((1e9,) * 3); hi = Vector((-1e9,) * 3)
for o in bpy.data.objects:
    if o.type == "MESH" and o != g:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
ctr = (lo + hi) / 2
size = hi - lo

cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
scene.collection.objects.link(cam)
scene.camera = cam
cam.data.type = "ORTHO"
if sheet:
    # Front three-quarter (front of every prop is -Z Roblox = +Y Blender), gentle angle.
    d = Vector((0.35, 1.0, 0.45)).normalized()
    scene.render.resolution_x, scene.render.resolution_y = 2400, 1000
    cam.data.ortho_scale = max(size.x * 1.08, size.z * 2.5)
else:
    d = Vector((0.85, 1.0, 0.7)).normalized()  # three-quarter from front-right, above
    scene.render.resolution_x, scene.render.resolution_y = 1000, 1000
    cam.data.ortho_scale = max(size.x, size.y, size.z) * 1.55
cam.location = ctr + d * (size.length * 3 + 50)
cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
cam.data.clip_end = 5000
# Fit the ortho frame to the camera-projected bounds of every prop (no cropping).
bpy.context.view_layer.update()
inv = cam.matrix_world.inverted()
pts = []
for o in bpy.data.objects:
    if o.type == "MESH" and o != g:
        for c in o.bound_box:
            pts.append(inv @ (o.matrix_world @ Vector(c)))
xs = [p.x for p in pts]; ys = [p.y for p in pts]
w, h = max(xs) - min(xs), max(ys) - min(ys)
aspect = scene.render.resolution_x / scene.render.resolution_y
cam.data.ortho_scale = max(w, h * aspect) * 1.06
cam.data.shift_x = ((max(xs) + min(xs)) / 2) / cam.data.ortho_scale
cam.data.shift_y = ((max(ys) + min(ys)) / 2) / cam.data.ortho_scale
scene.render.filepath = out
bpy.ops.render.render(write_still=True)
print("RENDERED", out, json.dumps({k: (v["tris"], v["bounds_studs"]) for k, v in measures.items()}))
