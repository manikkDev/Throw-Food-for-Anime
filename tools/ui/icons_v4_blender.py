"""Icons v4, the rendered set: every icon is a small 3D model rendered in Blender 4.5 (Cycles, headless).

    "%BLENDER%" -b --factory-startup -P tools/ui/icons_v4_blender.py -- [--only Gift,Yen] [--samples 64]
    -> work/icons_v4/render/<Key>.png  (512 x 512 RGBA, transparent film)

WHY A RENDERER AND NOT FLUX (measured 2026-11-15, see work/icons_v4/progress.md): FLUX.1-schnell gives
premium-looking renders but on a grey ground with a soft contact shadow and a pale rim, and a flood-fill
cut cannot separate either from the object (shadow halos, eaten silver shackles and bars); asking for an
outline is not obeyed reliably. A render has a perfect alpha channel, ONE camera, ONE light rig and ONE
material model for the whole set, so the family is consistent by construction and nothing is ever cut off.

Look (owner's references: Pet Simulator 99 / Throw Food For Animals shop icons): chunky toy shapes,
saturated colour with a top-light gradient baked into every material, clear-coat gloss, a big soft key
light top left, a strong rim light from behind, a gradient world so metals have something to reflect.
No ground, no shadow catcher, no text. The thin ink outline is added after (tools/ui/icons_v4.py).

Coordinates: X right, Z up, the camera looks along +Y from slightly above. 2D compositions (symbols,
slabs) are built on PLANE, an empty turned to face the camera: there X is right, Y is up, +Z is toward
the viewer. Shapes come from work/icons_v4/shapes.json (tools/ui/icons_v4_shapes.py).
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT_DIR = Path(__file__).resolve().parents[2]
SHAPES = json.loads((ROOT_DIR / "work" / "icons_v4" / "shapes.json").read_text(encoding="utf-8"))
OUT = ROOT_DIR / "work" / "icons_v4" / "render"
RES = 512
CAM_ELEV = 14.0  # degrees above the horizon

R = math.radians


# ----------------------------------------------------------------------------------------------- materials

def lin(hexcol: str):
    h = hexcol.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]


_MATS: dict = {}


def mat(col: str, dark: str | None = None, light: str | None = None, rough=0.32, metal=0.0, coat=0.8,
        emit=0.0, flat=False):
    """A glossy material whose colour runs dark (bottom) -> col -> light (top) in world Z, so even a flat
    face carries the top-lit gradient of a rendered game icon."""
    key = (col, dark, light, rough, metal, coat, emit, flat)
    if key in _MATS:
        return _MATS[key]
    m = bpy.data.materials.new(f"m{len(_MATS)}")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    base = lin(col)
    d = lin(dark) if dark else [c * 0.42 for c in base]
    li = lin(light) if light else [min(1.0, c * 1.55 + 0.03) for c in base]
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    rng = nt.nodes.new("ShaderNodeMapRange")
    rng.inputs["From Min"].default_value = -1.15
    rng.inputs["From Max"].default_value = 1.15
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = 0.0, (*d, 1)
    els[1].position, els[1].color = 1.0, (*li, 1)
    mid = els.new(0.5)
    mid.color = (*base, 1)
    nt.links.new(geo.outputs["Position"], sep.inputs[0])
    nt.links.new(sep.outputs["Z"], rng.inputs["Value"])
    nt.links.new(rng.outputs["Result"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Coat Weight"].default_value = coat
    bsdf.inputs["Coat Roughness"].default_value = 0.06
    if emit:
        nt.links.new(ramp.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = emit
    _MATS[key] = m
    return m


# palette (saturated, chosen to stand out on the navy #2A2F6B windows and on the coloured buttons)
WHITE = dict(col="#F6F8FF", dark="#AEB8E6", light="#FFFFFF", rough=0.25)
GOLD = dict(col="#FFC21A", dark="#E0700C", light="#FFF39A", metal=0.35, rough=0.22, coat=0.8)
GOLD_P = dict(col="#FFC531", dark="#E07A0C", light="#FFF4A8", rough=0.28)
SILVER = dict(col="#DCE4F5", dark="#7F8DB8", light="#FFFFFF", metal=0.4, rough=0.2, coat=0.6)
RED = dict(col="#FF2E44", dark="#9A0B2A", light="#FF5A4A")
CORAL = dict(col="#FF5A55", dark="#B81F3C", light="#FF8E6E")
PINK = dict(col="#FF4FA8", dark="#B01870", light="#FFA3D6")
ORANGE = dict(col="#FF8A1F", dark="#C2410C", light="#FFD27A")
GREEN = dict(col="#2FD873", dark="#0E8A4A", light="#A6FFB0")
LIME = dict(col="#7BE33A", dark="#2E9A1C", light="#D8FF8A")
TEAL = dict(col="#1ED2C6", dark="#0B7F8F", light="#9CFFF0")
SKY = dict(col="#3CB8FF", dark="#1650C8", light="#A6E6FF")
BLUE = dict(col="#2F7BFF", dark="#1A2FB0", light="#8CC4FF")
VIOLET = dict(col="#B04BFF", dark="#5A1AB8", light="#E0A6FF")
CREAM = dict(col="#FFF1D2", dark="#D9A86A", light="#FFFFFF", rough=0.45, coat=0.3)
BROWN = dict(col="#B8682C", dark="#6B3414", light="#E6A066", rough=0.45, coat=0.4)
INK = dict(col="#2A2452", dark="#120F2A", light="#4A4688", rough=0.3)
NORI = dict(col="#24483A", dark="#0F241C", light="#3F7A5E", rough=0.5, coat=0.3)
RICE = dict(col="#FFFFFF", dark="#C9CFE6", light="#FFFFFF", rough=0.5, coat=0.3)


def M(spec, **over):
    return mat(**{**spec, **over})


# ----------------------------------------------------------------------------------------------- geometry

ROOT = None
PLANE = None


def slab(shape, m, size=2.0, depth=0.3, bevel=0.07, loc=(0, 0, 0), rot=0.0, flip=False, parent=None, res=6):
    """Extrude a traced 2D shape into a bevelled slab on PLANE (front face toward the viewer).

    The curve is only used to FILL and EXTRUDE the outline; it is then turned into a mesh and bevelled by
    a modifier limited by angle, so only the front and back rims round over. A curve bevel along a dense
    traced outline self-intersects at every tight turn (measured: a smeared tick, a clover turned into a
    square), which is why the bevel is not done on the curve.
    """
    cu = bpy.data.curves.new(shape, "CURVE")
    cu.dimensions = "2D"
    cu.fill_mode = "BOTH"
    cu.extrude = depth / 2
    for loop in SHAPES[shape]:
        sp = cu.splines.new("POLY")
        sp.points.add(len(loop) - 1)
        for i, (x, y) in enumerate(loop):
            xx = (x - 0.5) * size
            sp.points[i].co = (-xx if flip else xx, (y - 0.5) * size, 0, 1)
        sp.use_cyclic_u = True
    tmp = bpy.data.objects.new("tmp", cu)
    bpy.context.collection.objects.link(tmp)
    bpy.context.view_layer.update()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    bpy.data.objects.remove(tmp)
    for poly in me.polygons:
        poly.use_smooth = True
    ob = bpy.data.objects.new(shape, me)
    bpy.context.collection.objects.link(ob)
    bv = ob.modifiers.new("bevel", "BEVEL")
    bv.width = bevel
    bv.segments = res
    bv.limit_method = "ANGLE"
    bv.angle_limit = R(50)
    bv.harden_normals = True
    ob.parent = parent or PLANE
    ob.data.materials.append(m)
    ob.location = loc
    ob.rotation_euler = (0, 0, R(rot))
    return ob


def prim(kind, m, loc=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0), bevel=0.0, parent=None, **kw):
    if kind == "cube":
        bpy.ops.mesh.primitive_cube_add(size=2)
    elif kind == "cyl":
        bpy.ops.mesh.primitive_cylinder_add(vertices=kw.get("verts", 96), radius=1, depth=2)
    elif kind == "sphere":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=96, ring_count=48, radius=1)
    elif kind == "torus":
        bpy.ops.mesh.primitive_torus_add(major_radius=kw["major"], minor_radius=kw["minor"],
                                         major_segments=128, minor_segments=32)
    elif kind == "cone":
        bpy.ops.mesh.primitive_cone_add(vertices=kw.get("verts", 96), radius1=kw.get("r1", 1),
                                        radius2=kw.get("r2", 0), depth=2)
    ob = bpy.context.active_object
    ob.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        b = ob.modifiers.new("bevel", "BEVEL")
        b.width = bevel
        b.segments = 8
        b.limit_method = "ANGLE"
        b.harden_normals = True
    bpy.ops.object.shade_smooth()
    ob.data.materials.append(m)
    ob.parent = parent or ROOT
    ob.location = loc
    ob.rotation_euler = tuple(R(a) for a in rot)
    return ob


def tube(points, r, m, parent=None, caps=True):
    cu = bpy.data.curves.new("tube", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = r
    cu.bevel_resolution = 8
    cu.use_fill_caps = caps
    sp = cu.splines.new("POLY")
    sp.points.add(len(points) - 1)
    for i, p in enumerate(points):
        sp.points[i].co = (*p, 1)
    sp.use_smooth = True
    ob = bpy.data.objects.new("tube", cu)
    bpy.context.collection.objects.link(ob)
    ob.parent = parent or ROOT
    ob.data.materials.append(m)
    return ob


def cut_below(ob, z):
    """Boolean away everything under world z (flat bases)."""
    bpy.ops.mesh.primitive_cube_add(size=2, location=(0, 0, z - 5))
    cutter = bpy.context.active_object
    cutter.scale = (10, 10, 5)
    cutter.hide_render = True
    cutter.parent = ROOT
    b = ob.modifiers.new("cut", "BOOLEAN")
    b.operation = "DIFFERENCE"
    b.object = cutter
    return ob


def arc(cx, cz, r, a0, a1, n=64, y=0.0):
    return [(cx + math.cos(R(a0 + (a1 - a0) * i / n)) * r, y, cz + math.sin(R(a0 + (a1 - a0) * i / n)) * r)
            for i in range(n + 1)]


# ----------------------------------------------------------------------------------------------- the icons
# Each builder makes the model around the origin, about 2 units across, and returns the root pose
# (yaw, pitch, roll) in degrees. Positive yaw turns the right side away from the camera.

def b_tick():
    slab("tick", M(WHITE), depth=0.46, bevel=0.11)
    return (-14, 0, 0)


def b_close():
    slab("close", M(WHITE), depth=0.46, bevel=0.11)
    return (-14, 0, 0)


def b_plus():
    slab("plus", M(WHITE), depth=0.46, bevel=0.11)
    return (-14, 0, 0)


def b_arrow():
    slab("arrow_up", M(WHITE), depth=0.46, bevel=0.11)
    return (-14, 0, 0)


def b_info():
    prim("cyl", M(WHITE), scale=(1, 1, 0.2), rot=(90, 0, 0), bevel=0.12)
    slab("info_i", M(SKY), size=1.4, depth=0.2, bevel=0.06, loc=(0, 0, 0.2))
    return (-16, 0, 0)


def b_star():
    slab("star5", M(GOLD), depth=0.55, bevel=0.17)
    return (-16, 0, 0)


def b_yen():
    prim("cyl", M(GOLD), scale=(1, 1, 0.17), rot=(90, 0, 0), bevel=0.06)
    prim("torus", M(GOLD), loc=(0, -0.17, 0), rot=(90, 0, 0), major=0.86, minor=0.075)
    slab("yen", M(GOLD, col="#F08200", dark="#8E3A00", light="#FFB830"), size=1.22, depth=0.14, bevel=0.04,
         loc=(0, 0, 0.17))
    return (-24, 0, 0)


def b_robux_big():
    g = dict(col="#2CD86E", dark="#0B7A3E", light="#B8FFC0")
    slab("robux_ring", M(g), depth=0.42, bevel=0.1)
    slab("robux_square", M(g), depth=0.42, bevel=0.07)
    return (-16, 0, 0)


def b_dumbbell(colour=None):
    c = M(colour or SKY)
    s = M(SILVER)
    prim("cyl", s, scale=(0.11, 0.11, 0.95), rot=(0, 90, 0))
    for sx in (-1, 1):
        prim("cyl", c, loc=(sx * 0.52, 0, 0), scale=(0.6, 0.6, 0.13), rot=(0, 90, 0), bevel=0.06)
        prim("cyl", c, loc=(sx * 0.76, 0, 0), scale=(0.47, 0.47, 0.1), rot=(0, 90, 0), bevel=0.05)
        prim("cyl", s, loc=(sx * 0.93, 0, 0), scale=(0.16, 0.16, 0.07), rot=(0, 90, 0), bevel=0.03)
    return (28, 0, -22)


def b_luck():
    g = M(GREEN)
    for a in (45, 135, 225, 315):
        x, y = math.cos(R(a)) * 0.5, math.sin(R(a)) * 0.5
        slab("heart", g, size=1.05, depth=0.34, bevel=0.1, loc=(x, y, 0), rot=a - 90)
    pts = [(0.0 + 0.5 * t ** 1.3, 0.0, -0.1 - 0.85 * t) for t in [i / 20 for i in range(21)]]
    tube([(x, -0.05, z) for x, _, z in pts], 0.07, M(GREEN, col="#1FB85E"))
    return (-14, 0, 0)


def b_lucky_throw():
    slab("sparkle4", M(GOLD), size=1.9, depth=0.4, bevel=0.12, loc=(-0.15, -0.12, 0))
    slab("sparkle4", M(PINK), size=0.75, depth=0.3, bevel=0.08, loc=(0.72, 0.68, 0.05))
    return (-14, 0, 0)


def b_squad():
    def person(x, z, y, spec, s=1.0):
        mm = M(spec)
        prim("sphere", mm, loc=(x, y, z + 0.42 * s), scale=(0.34 * s,) * 3)
        body = prim("sphere", mm, loc=(x, y, z - 0.32 * s), scale=(0.58 * s, 0.42 * s, 0.5 * s))
        cut_below(body, z - 0.42 * s)
    person(0.42, 0.12, 0.25, PINK, 0.88)
    person(-0.25, 0.0, -0.2, SKY, 1.0)
    return (-10, 0, 0)


def b_index():
    cover = M(BLUE)
    for y in (-0.2, 0.2):
        prim("cube", cover, loc=(0, y, 0), scale=(0.74, 0.05, 0.94), bevel=0.04)
    prim("cube", M(BLUE, col="#2563EB"), loc=(-0.72, 0, 0), scale=(0.07, 0.25, 0.94), bevel=0.05)
    prim("cube", M(CREAM, col="#FFF6E2"), loc=(0.0, 0.0, 0), scale=(0.7, 0.16, 0.88), bevel=0.02)
    slab("star5", M(GOLD), size=0.95, depth=0.12, bevel=0.04, loc=(0.02, 0.05, 0.25))
    return (-30, 4, 0)


def b_shop():
    bowl = prim("sphere", M(RED), scale=(1.0, 1.0, 0.78))
    bpy.ops.mesh.primitive_cube_add(size=2, location=(0, 0, 5))
    c = bpy.context.active_object
    c.scale = (10, 10, 5)
    c.hide_render = True
    c.parent = ROOT
    b = bowl.modifiers.new("cut", "BOOLEAN")
    b.operation = "DIFFERENCE"
    b.object = c
    prim("torus", M(WHITE), loc=(0, 0, 0.0), major=0.96, minor=0.075)
    prim("cyl", M(dict(col="#FFB43D", dark="#D9700F", light="#FFE29A")), loc=(0, 0, 0.01), scale=(0.92, 0.92, 0.02))
    noodle = M(dict(col="#FFE07A", dark="#E0A030", light="#FFF6C8"))
    for i, yv in enumerate((-0.45, -0.22, 0.01, 0.24, 0.47)):
        half = math.sqrt(max(0.0, 0.8 - yv * yv)) * 0.95
        pts = [(-half + 2 * half * t / 40, yv + 0.05 * math.sin(t / 40 * 18 + i), 0.05) for t in range(41)]
        tube(pts, 0.05, noodle)
    prim("sphere", M(WHITE), loc=(0.42, -0.25, 0.08), scale=(0.3, 0.24, 0.09))
    prim("sphere", M(ORANGE), loc=(0.42, -0.27, 0.14), scale=(0.14, 0.11, 0.05))
    prim("cyl", M(WHITE), loc=(-0.45, 0.3, 0.08), scale=(0.24, 0.24, 0.04), bevel=0.02)
    prim("torus", M(PINK), loc=(-0.45, 0.3, 0.12), major=0.1, minor=0.03, scale=(1, 1, 0.4))
    for x, y in ((-0.1, -0.5), (0.0, -0.42), (0.12, -0.55)):
        prim("cyl", M(GREEN), loc=(x, y, 0.08), scale=(0.06, 0.06, 0.03))
    stick = M(BROWN, col="#8A3A1A", dark="#4A1A0A", light="#C46A3A")
    prim("cyl", stick, loc=(-0.05, 0.1, 0.55), scale=(0.06, 0.06, 1.0), rot=(0, 62, 18))
    prim("cyl", stick, loc=(0.08, 0.15, 0.6), scale=(0.06, 0.06, 1.0), rot=(0, 55, 30))
    return (8, 30, 0)


def b_store():
    import bmesh
    me = bpy.data.meshes.new("gem")
    bm = bmesh.new()
    n = 8
    table = [bm.verts.new((math.cos(R(i * 360 / n + 22.5)) * 0.52, math.sin(R(i * 360 / n + 22.5)) * 0.52, 0.42))
             for i in range(n)]
    girdle = [bm.verts.new((math.cos(R(i * 360 / n)) * 1.0, math.sin(R(i * 360 / n)) * 1.0, 0.08)) for i in range(n)]
    tip = bm.verts.new((0, 0, -0.95))
    bm.faces.new(table)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((girdle[i], girdle[j], table[i]))
        bm.faces.new((table[i], girdle[j], table[j]))
        bm.faces.new((girdle[j], girdle[i], tip))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    ob = bpy.data.objects.new("gem", me)
    bpy.context.collection.objects.link(ob)
    ob.parent = ROOT
    ob.data.materials.append(M(PINK, emit=0.25, rough=0.12))
    return (12, -16, 0)


def b_rebirth():
    slab("rebirth", M(VIOLET), depth=0.42, bevel=0.11)
    return (-14, 0, 0)


def b_gift():
    red, gold = M(RED), M(GOLD)
    prim("cube", red, loc=(0, 0, -0.32), scale=(0.72, 0.72, 0.6), bevel=0.07)
    prim("cube", red, loc=(0, 0, 0.36), scale=(0.8, 0.8, 0.16), bevel=0.06)
    prim("cube", gold, loc=(0, 0, -0.32), scale=(0.15, 0.74, 0.61), bevel=0.03)
    prim("cube", gold, loc=(0, 0, -0.32), scale=(0.74, 0.15, 0.61), bevel=0.03)
    prim("cube", gold, loc=(0, 0, 0.36), scale=(0.16, 0.82, 0.17), bevel=0.03)
    prim("cube", gold, loc=(0, 0, 0.36), scale=(0.82, 0.16, 0.17), bevel=0.03)
    for sx in (-1, 1):
        prim("torus", gold, loc=(sx * 0.27, 0, 0.66), rot=(90, sx * 35, 0), scale=(1.0, 0.72, 0.42), major=0.25,
             minor=0.12)
    prim("sphere", gold, loc=(0, 0, 0.58), scale=(0.15, 0.15, 0.12))
    return (36, 10, 0)


def b_settings():
    slab("gear", M(SILVER, metal=0.6, col="#C9D6F0"), depth=0.42, bevel=0.08)
    prim("torus", M(SKY), loc=(0, 0, 0), rot=(90, 0, 0), major=0.27, minor=0.07)
    return (-16, 0, 0)


def b_codes():
    slab("ticket", M(VIOLET, col="#9D5CFF"), size=2.0, depth=0.3, bevel=0.07, rot=12)
    slab("star5", M(GOLD), size=0.62, depth=0.12, bevel=0.04, loc=(-0.28, 0.08, 0.15), rot=12)
    return (-16, 0, 0)


def b_crown():
    slab("crown", M(GOLD), depth=0.42, bevel=0.1)
    for x, z in ((-0.92, 0.48), (0.92, 0.48)):
        prim("sphere", M(SKY, emit=0.2), loc=(x, -0.05, z), scale=(0.15,) * 3)
    prim("sphere", M(RED, emit=0.2), loc=(0, -0.05, 0.72), scale=(0.17,) * 3)
    prim("sphere", M(RED, emit=0.2), loc=(0, -0.22, -0.22), scale=(0.2, 0.08, 0.24))
    for x in (-0.5, 0.5):
        prim("sphere", M(SKY, emit=0.2), loc=(x, -0.2, -0.26), scale=(0.13, 0.07, 0.13))
    return (-14, 0, 0)


def b_lock():
    shackle = arc(0, 0.25, 0.47, 0, 180, 48)
    pts = [(0.47, 0, -0.2)] + shackle + [(-0.47, 0, -0.2)]
    tube(pts, 0.13, M(SILVER))
    prim("cube", M(GOLD), loc=(0, 0, -0.42), scale=(0.8, 0.32, 0.6), bevel=0.2)
    slab("keyhole", M(INK), size=0.9, depth=0.1, bevel=0.03, loc=(0, -0.42, 0.33))
    return (-18, 0, 0)


def b_timer():
    frame = M(BLUE)
    prim("cyl", frame, scale=(0.9, 0.9, 0.2), rot=(90, 0, 0), bevel=0.1)
    prim("cyl", M(WHITE), loc=(0, -0.12, -0.0), scale=(0.72, 0.72, 0.12), rot=(90, 0, 0), bevel=0.04)
    prim("cyl", frame, loc=(0, 0, 1.0), scale=(0.11, 0.11, 0.14), bevel=0.03)
    prim("cube", M(GOLD), loc=(0, 0, 1.17), scale=(0.24, 0.12, 0.08), bevel=0.05)
    prim("cyl", frame, loc=(0.72, 0, 0.72), scale=(0.08, 0.08, 0.1), rot=(0, 45, 0), bevel=0.03)
    ink = M(INK)
    tube([(0, -0.26, 0), (0, -0.26, 0.5)], 0.06, ink)
    tube([(0, -0.26, 0), (0.36, -0.26, -0.2)], 0.06, ink)
    prim("sphere", M(RED), loc=(0, -0.28, 0), scale=(0.09,) * 3)
    return (-18, 0, 0)


def b_sell():
    slab("tag", M(CORAL), size=2.0, depth=0.3, bevel=0.08, rot=-30)
    a = R(-30)
    hx, hy = (0.28 - 0.5) * 2.0, 0.0
    cx, cy = hx * math.cos(a) - hy * math.sin(a), hx * math.sin(a) + hy * math.cos(a)
    prim("torus", M(GOLD), loc=(cx, 0, cy), rot=(90, 0, 0), major=0.16, minor=0.05)
    tube([(cx - 0.1, -0.02, cy + 0.12), (cx - 0.35, -0.02, cy + 0.42), (cx - 0.3, -0.02, cy + 0.75)], 0.035,
         M(GOLD_P))
    return (-14, 0, 0)


def b_fuse():
    slab("merge", M(LIME), depth=0.44, bevel=0.1)
    return (-14, 0, 0)


def b_bench():
    seat = M(RED)
    wood = M(BROWN)
    prim("cube", seat, loc=(0, 0, -0.05), scale=(1.0, 0.36, 0.11), bevel=0.08)
    prim("cube", seat, loc=(0, 0.3, 0.38), scale=(1.0, 0.09, 0.33), rot=(-12, 0, 0), bevel=0.07)
    for x in (-0.82, 0.82):
        prim("cube", wood, loc=(x, -0.18, -0.42), scale=(0.07, 0.07, 0.3), bevel=0.02)
        prim("cube", wood, loc=(x, 0.22, -0.2), scale=(0.07, 0.07, 0.55), bevel=0.02)
        prim("cube", wood, loc=(x, 0.02, 0.08), scale=(0.08, 0.3, 0.05), bevel=0.02)
    return (24, 8, 0)


def b_place():
    prim("cyl", M(SKY), loc=(0, 0, -0.55), scale=(0.95, 0.95, 0.16), bevel=0.06)
    prim("cyl", M(GOLD), loc=(0, 0, -0.75), scale=(1.02, 1.02, 0.08), bevel=0.04)
    p = slab("arrow_up", M(GREEN), size=1.15, depth=0.34, bevel=0.09, loc=(0, 0.35, 0), rot=180)
    return (0, 16, 0)


def b_scroll():
    paper = M(CREAM)
    prim("cube", paper, scale=(0.62, 0.04, 0.72), bevel=0.02)
    for z in (0.78, -0.78):
        prim("cyl", M(CREAM, col="#F7DDAA"), loc=(0, 0, z), scale=(0.17, 0.17, 0.72), rot=(0, 90, 0), bevel=0.03)
        for x in (-0.8, 0.8):
            prim("sphere", M(RED), loc=(x, 0, z), scale=(0.14, 0.14, 0.14))
    for z in (0.3, 0.05, -0.2):
        prim("cube", M(BROWN, col="#C9925A"), loc=(0, -0.06, z), scale=(0.4, 0.01, 0.035), bevel=0.01)
    prim("cyl", M(RED), loc=(0.0, -0.08, -0.5), scale=(0.17, 0.17, 0.04), rot=(90, 0, 0), bevel=0.02)
    return (-14, 0, -8)


def b_throw():
    prim("sphere", M(ORANGE, col="#FFA32A", light="#FFE08A"), loc=(0.5, 0, 0), scale=(0.6,) * 3)
    for z, x0 in ((0.34, -0.55), (0.0, -0.95), (-0.34, -0.55)):
        tube([(x0, 0.1, z), (0.05, 0.1, z)], 0.085, M(WHITE))
    return (-10, 0, 0)


def b_auto():
    prim("cyl", M(GREEN), scale=(0.72, 0.72, 0.2), rot=(90, 0, 0), bevel=0.1)
    slab("play", M(WHITE), size=0.72, depth=0.16, bevel=0.05, loc=(0.06, 0, 0.2))
    slab("circle_arrow", M(GOLD_P), size=2.05, depth=0.22, bevel=0.06)
    return (-14, 0, 0)


def b_hide():
    slab("eye", M(WHITE), size=2.0, depth=0.3, bevel=0.08)
    prim("cyl", M(SKY), loc=(0, -0.15, 0), scale=(0.42, 0.42, 0.06), rot=(90, 0, 0), bevel=0.04)
    prim("cyl", M(INK), loc=(0, -0.2, 0), scale=(0.2, 0.2, 0.05), rot=(90, 0, 0), bevel=0.03)
    slab("slash", M(RED), size=2.0, depth=0.22, bevel=0.07, loc=(0, 0, 0.32))
    return (-14, 0, 0)


def b_lowdetail():
    for i, (x, z) in enumerate(((-0.5, 0.5), (0.5, 0.5), (-0.5, -0.5), (0.5, -0.5))):
        spec = (TEAL, SKY, SKY, TEAL)[i]
        prim("cube", M(spec), loc=(x, 0, z), scale=(0.42, 0.18, 0.42), bevel=0.1)
    return (-16, 0, 0)


def b_music():
    slab("note", M(PINK), depth=0.4, bevel=0.1)
    return (-14, 0, 0)


def b_sfx():
    slab("speaker", M(ORANGE), depth=0.4, bevel=0.1)
    return (-14, 0, 0)


def b_fast():
    slab("fastfwd", M(ORANGE, col="#FFA51F"), depth=0.42, bevel=0.11)
    return (-14, 0, 0)


def b_savory():
    slab("onigiri", M(RICE), depth=0.62, bevel=0.24)
    slab("nori", M(NORI, col="#3A7458", light="#6AAE88"), size=1.7, depth=0.64, bevel=0.06, loc=(0, -0.12, 0.02))
    return (-14, 0, 0)


def b_sweet():
    prim("cyl", M(dict(col="#FFE3F2", dark="#E9A0C6", light="#FFFFFF")), loc=(0, 0, 0.22),
         scale=(0.8, 0.8, 0.18), rot=(90, 0, 0), bevel=0.14)
    slab("swirl", M(PINK), size=1.6, depth=0.08, bevel=0.03, loc=(0, 0.22, 0.17))
    tube([(0, 0.0, -0.5), (0, 0, -0.98)], 0.08, M(WHITE))
    return (-10, 0, -14)


def b_spicy():
    slab("chili", M(RED), depth=0.5, bevel=0.2)
    tube([(-0.5, 0, 0.7), (-0.5, 0, 0.88), (-0.38, 0, 1.02)], 0.07, M(GREEN, col="#22B04F"))
    prim("sphere", M(GREEN, col="#22B04F"), loc=(-0.48, 0, 0.66), scale=(0.3, 0.2, 0.1))
    return (-12, 0, 0)


def b_seafood():
    slab("fish", M(SKY, col="#2EC4F0"), depth=0.5, bevel=0.2)
    slab("fin", M(BLUE), depth=0.2, bevel=0.06, loc=(0, 0, -0.05))
    prim("sphere", M(WHITE), loc=(-0.48, -0.2, 0.1), scale=(0.15, 0.08, 0.15))
    prim("sphere", M(INK), loc=(-0.5, -0.27, 0.1), scale=(0.08, 0.05, 0.08))
    return (-14, 0, 0)


BUILDERS = {
    "Tick": b_tick, "Close": b_close, "Plus": b_plus, "Arrow": b_arrow, "Info": b_info, "Star": b_star,
    "Yen": b_yen, "RobuxBig": b_robux_big, "Power": b_dumbbell, "Luck": b_luck, "LuckyThrow": b_lucky_throw,
    "Squad": b_squad, "Index": b_index, "Shop": b_shop, "Store": b_store, "Rebirth": b_rebirth, "Gift": b_gift,
    "Settings": b_settings, "Codes": b_codes, "Crown": b_crown, "Lock": b_lock, "Timer": b_timer, "Sell": b_sell,
    "Fuse": b_fuse, "Bench": b_bench, "Place": b_place, "Scroll": b_scroll, "Throw": b_throw, "Auto": b_auto,
    "Hide": b_hide, "LowDetail": b_lowdetail, "Music": b_music, "Sfx": b_sfx, "Fast": b_fast,
    "FlavorSavory": b_savory, "FlavorSweet": b_sweet, "FlavorSpicy": b_spicy, "FlavorSeafood": b_seafood,
}


# ----------------------------------------------------------------------------------------------- scene

def light(name, loc, size, energy, colour=(1, 1, 1)):
    ld = bpy.data.lights.new(name, "AREA")
    ld.size = size
    ld.energy = energy
    ld.color = colour
    ob = bpy.data.objects.new(name, ld)
    bpy.context.collection.objects.link(ob)
    ob.location = loc
    ob.rotation_euler = (-Vector(loc)).to_track_quat("-Z", "Y").to_euler()


def world():
    w = bpy.data.worlds.new("w")
    bpy.context.scene.world = w
    w.use_nodes = True
    nt = w.node_tree
    bg = next(n for n in nt.nodes if n.type == "BACKGROUND")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    rng = nt.nodes.new("ShaderNodeMapRange")
    rng.inputs["From Min"].default_value = -0.4
    rng.inputs["From Max"].default_value = 0.9
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (0.05, 0.05, 0.12, 1)
    ramp.color_ramp.elements[1].color = (1.0, 0.98, 0.95, 1)
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    nt.links.new(sep.outputs["Z"], rng.inputs["Value"])
    nt.links.new(rng.outputs["Result"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 0.45


def setup(samples):
    global ROOT, PLANE
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _MATS.clear()
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.render.film_transparent = True
    sc.render.resolution_x = sc.render.resolution_y = RES
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"
    try:
        sc.view_settings.look = "Medium High Contrast"
    except TypeError:
        pass
    world()
    light("key", (-5.5, -7.0, 7.5), 6.0, 2000)
    light("fill", (7.0, -6.0, 0.5), 7.0, 480, (0.82, 0.88, 1.0))
    light("rim", (3.0, 7.0, 5.0), 4.0, 3200, (1.0, 0.96, 0.9))
    light("rim2", (-6.0, 6.0, -1.0), 4.0, 1400, (0.8, 0.85, 1.0))
    ROOT = bpy.data.objects.new("ROOT", None)
    sc.collection.objects.link(ROOT)
    PLANE = bpy.data.objects.new("PLANE", None)
    sc.collection.objects.link(PLANE)
    PLANE.parent = ROOT
    PLANE.rotation_euler = (R(90), 0, 0)


def frame_camera():
    sc = bpy.context.scene
    cd = bpy.data.cameras.new("cam")
    cd.type = "ORTHO"
    cam = bpy.data.objects.new("cam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    d = 30.0
    cam.location = (0, -d * math.cos(R(CAM_ELEV)), d * math.sin(R(CAM_ELEV)))
    cam.rotation_euler = (-Vector(cam.location)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    inv = cam.matrix_world.inverted()
    xs, ys = [], []
    for ob in sc.objects:
        if ob.type not in {"MESH", "CURVE"} or ob.hide_render:
            continue
        ev = ob.evaluated_get(dg)
        me = ev.to_mesh()
        mw = ev.matrix_world
        for v in me.vertices:
            p = inv @ (mw @ v.co)
            xs.append(p.x)
            ys.append(p.y)
        ev.to_mesh_clear()
    w, h = max(xs) - min(xs), max(ys) - min(ys)
    cd.ortho_scale = max(w, h) * 1.12
    cd.shift_x = (max(xs) + min(xs)) / 2 / cd.ortho_scale
    cd.shift_y = (max(ys) + min(ys)) / 2 / cd.ortho_scale


def main() -> int:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default=None)
    ap.add_argument("--samples", type=int, default=64)
    ap.add_argument("--out", default=str(OUT))
    a = ap.parse_args(argv)
    keys = [k.strip() for k in a.only.split(",")] if a.only else list(BUILDERS)
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    for key in keys:
        setup(a.samples)
        yaw, pitch, roll = BUILDERS[key]()
        ROOT.rotation_euler = (R(pitch), R(roll), R(yaw))  # +pitch tips the top toward the camera
        frame_camera()
        bpy.context.scene.render.filepath = str(out / f"{key}.png")
        bpy.ops.render.render(write_still=True)
        print(f"ICON {key} -> {out / (key + '.png')}", flush=True)
    return 0


if __name__ == "__main__":
    main()
