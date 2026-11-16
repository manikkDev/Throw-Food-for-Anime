"""Blender ground truth for a spec, no render: floor contact, planted-foot slip and part interpenetration,
measured on the rig's real part meshes on EVERY frame.

  blender --background <rig> --enable-autoexec --python mesh_probe.py -- <spec.json> [--frames]
  (or: python tools/anim/run.py probe <Name> ...)

Runs the skill's anim_render.py with "dry": true (so the Action is keyed exactly as for a render), then:
  * per part: lowest vertex vs the floor (z -3.0) over the clip, and when
  * feet (and any part that touches the floor): SLIP = horizontal travel, frame to frame, of the vertices
    that are on the floor (within 0.03) in both frames. A heel-to-toe roll keeps its contact vertices still,
    so it reads 0; a skating foot does not. A walk cycle (spec "_walk".speed_studs_per_s) is played in
    place while the game moves the root forward, so its slip is measured in the WORLD: the foot's in-place
    motion plus the root's forward travel (a planted foot then reads 0).
  * every NON-adjacent part pair: deepest vertex of A inside B's box (parts are boxes), worst frame.
--frames prints one line per frame (lowest foot / knee / hand vertex, and the frame's worst overlap).
"""
import json
import os
import runpy
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
spec_path = argv[0]
PER_FRAME = "--frames" in argv
spec = json.load(open(spec_path))
spec["dry"] = True
spec.pop("report", None)
tmp = os.path.join(os.path.dirname(os.path.abspath(spec_path)), "_probe_" + os.path.basename(spec_path))
SCRIPT = os.path.join(os.path.expanduser("~/.claude/skills/roblox-animation/scripts"), "anim_render.py")
FLOOR = -3.0
PARTS = ["Head", "UpperTorso", "LowerTorso", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm",
         "LeftLowerArm", "LeftHand", "RightUpperLeg", "RightLowerLeg", "RightFoot", "LeftUpperLeg",
         "LeftLowerLeg", "LeftFoot"]
ADJ = {("Head", "UpperTorso"), ("UpperTorso", "LowerTorso"), ("UpperTorso", "RightUpperArm"),
       ("UpperTorso", "LeftUpperArm"), ("RightUpperArm", "RightLowerArm"), ("RightLowerArm", "RightHand"),
       ("LeftUpperArm", "LeftLowerArm"), ("LeftLowerArm", "LeftHand"), ("LowerTorso", "RightUpperLeg"),
       ("LowerTorso", "LeftUpperLeg"), ("RightUpperLeg", "RightLowerLeg"), ("RightLowerLeg", "RightFoot"),
       ("LeftUpperLeg", "LeftLowerLeg"), ("LeftLowerLeg", "LeftFoot")}


def adjacent(a, b):
    return (a, b) in ADJ or (b, a) in ADJ


def probe():
    sc = bpy.context.scene
    arm = next(o for o in bpy.data.objects
               if o.type == "ARMATURE" and "RightUpperLeg" in o.data.bones and "HumanoidRootPart" in o.data.bones)
    sc.frame_set(0)
    bpy.context.view_layer.update()
    origin = arm.matrix_world @ arm.pose.bones["HumanoidRootPart"].head
    objs = {p: bpy.data.objects[p] for p in PARTS}
    local = {p: [v.co.copy() for v in o.data.vertices] for p, o in objs.items()}
    half = {}
    centre = {}
    for p, vs in local.items():
        lo = Vector([min(v[i] for v in vs) for i in range(3)])
        hi = Vector([max(v[i] for v in vs) for i in range(3)])
        half[p], centre[p] = (hi - lo) / 2, (hi + lo) / 2
    fps = spec.get("fps", 30)
    speed = float(spec.get("_walk", {}).get("speed_studs_per_s", 0.0))
    arr = spec.get("_arrive", {})

    def travel(i):
        """game-driven root travel along the facing at frame i (the clip itself is in place)"""
        t = i / fps
        if arr:
            u = min(1.0, t / arr["root_travel_time"])
            return arr["root_travel"] * (1 - (1 - u) ** 2)
        return speed * t
    n = int(round(spec["duration"] * fps)) + (0 if spec.get("loop") else 1)
    low = {p: (9.0, 0) for p in PARTS}
    slip = {p: (0.0, 0) for p in PARTS}
    pen = {}
    prev = {}
    for i in range(n):
        sc.frame_set(10 + i)
        bpy.context.view_layer.update()
        mw = {p: objs[p].matrix_world.copy() for p in PARTS}
        world = {p: [mw[p] @ v - origin for v in local[p]] for p in PARTS}
        frame_low = {}
        for p in PARTS:
            z = min(v.z for v in world[p])
            frame_low[p] = z - FLOOR
            if z - FLOOR < low[p][0]:
                low[p] = (z - FLOOR, i)
            if p in prev:
                ws, pv = world[p], prev[p]
                step = Vector((0.0, travel(i) - travel(i - 1), 0.0))
                moves = [((ws[k] - pv[k]) + step).xy.length for k in range(len(ws))
                         if ws[k].z - FLOOR < 0.03 and pv[k].z - FLOOR < 0.03]
                if moves and max(moves) > slip[p][0]:
                    slip[p] = (max(moves), i)
            prev[p] = world[p]
        worst_f = (0.0, "")
        for ai, a in enumerate(PARTS):
            inv = mw[a].inverted()
            for b in PARTS:
                if a == b or adjacent(a, b):
                    continue
                d = 0.0
                for v in world[b]:
                    q = inv @ (v + origin) - centre[a]
                    dd = min(half[a][k] - abs(q[k]) for k in range(3))
                    if dd > d:
                        d = dd
                key = tuple(sorted((a, b)))
                if d > pen.get(key, (0.0, 0))[0]:
                    pen[key] = (d, i)
                if d > worst_f[0]:
                    worst_f = (d, f"{b} in {a}")
        if PER_FRAME:
            print(f"  f{i:03d} t={i / fps:.3f} feet R{frame_low['RightFoot']:+.3f} L{frame_low['LeftFoot']:+.3f} "
                  f"lowleg R{frame_low['RightLowerLeg']:+.3f} L{frame_low['LeftLowerLeg']:+.3f} "
                  f"hand R{frame_low['RightHand']:+.3f} L{frame_low['LeftHand']:+.3f}  overlap {worst_f[0]:.3f} {worst_f[1]}")
    print(f"=== MESH PROBE {spec['name']}: {n} frames (floor z {FLOOR}; + = above)"
          + (f"; slip in the world at root speed {speed:.4f} studs/s" if speed else "")
          + (f"; slip in the world with the root coasting {arr['root_travel']} in {arr['root_travel_time']} s" if arr else ""))
    for p in PARTS:
        g, f = low[p]
        s, sf = slip[p]
        if g < 0.6 or s > 0:
            print(f"  {p:14s} lowest {g:+.3f} (f{f})   floor slip max {s:.3f}/frame (f{sf})")
    bad = sorted(((d, f, k) for k, (d, f) in pen.items() if d > 0.05), reverse=True)
    print("  overlaps > 0.05 (non-adjacent parts, depth of a vertex inside the other box):")
    for d, f, k in bad[:12]:
        print(f"    {k[0]} / {k[1]}: {d:.3f} at f{f}")
    if not bad:
        print("    none")
    sys.stdout.flush()


_real_exit = os._exit


def _exit_hook(code):
    if code == 0:
        try:
            probe()
        finally:
            try:
                os.remove(tmp)
            except OSError:
                pass
    _real_exit(code)


json.dump(spec, open(tmp, "w"))
os._exit = _exit_hook
sys.argv = [sys.argv[0], "--", tmp, os.path.join(os.path.dirname(tmp), "_probe_out")]
runpy.run_path(SCRIPT, run_name="__main__")
_exit_hook(0)
