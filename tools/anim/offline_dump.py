"""Build the upload dump (the JSON dump_kfs.luau returns from Studio) straight from export specs, offline.

  python tools/anim/offline_dump.py <out_dump.json> <export_spec.json> ...
  python tools/anim/offline_dump.py --verify work/anim/upload2/dump.json work/anim/export/Throw.json

It reproduces what to_roblox.py's builder makes in Studio, value for value: the spec is converted with
to_roblox.convert (axis map, ease map, 4-decimal rounding as emitted into the Luau), every Pose CFrame is
CFrame.new(p) * Angles(0,0,z) * Angles(0,y,0) * Angles(x,0,0), only keyed joints and their ancestors get
a Pose (unkeyed ancestors as Weight-0 holders), the HumanoidRootPart pose is identity, Linear/In.
upload_animation.py --dump <this> --build then makes the .rbxm files without Studio. --verify compares
against a dump Studio really returned (same clip) and prints the worst CFrame component difference.
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.expanduser("~/.claude/skills/roblox-animation/scripts"))
import to_roblox as T  # noqa: E402

STYLE = {"Linear": 0, "Constant": 1, "Elastic": 2, "Cubic": 3, "Bounce": 4}
DIRECTION = {"In": 0, "Out": 1, "InOut": 2}
PRIORITY = {"Idle": 0, "Movement": 1, "Action": 2, "Action2": 3, "Action3": 4, "Action4": 5, "Core": 1000}
PARENT = dict(T.TREE)


def _mat(r):
    x, y, z = (math.radians(v) for v in r)
    cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
    rz = [[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]]
    ry = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    rx = [[1, 0, 0], [0, cx, -sx], [0, sx, cx]]
    mul = lambda a, b: [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    return mul(mul(rz, ry), rx)


def _f32(v):
    import struct
    return struct.unpack("f", struct.pack("f", v))[0]


def clip_dump(path):
    d = T.convert(path)
    frames = []
    for k in d["keyframes"]:
        t = float(T._n(k["t"]))
        keep = set()
        for j in k["poses"]:
            while j and j != "HumanoidRootPart":
                keep.add(j)
                j = PARENT[j]
        nodes = {}
        for j, _ in T.TREE:
            if j not in keep:
                continue
            v = k["poses"].get(j)
            m, p = [[1, 0, 0], [0, 1, 0], [0, 0, 1]], [0.0, 0.0, 0.0]
            if v:
                if "r" in v:
                    m = _mat([float(T._n(a)) for a in v["r"]])
                if "p" in v:
                    p = [float(T._n(a)) for a in v["p"]]
            nodes[j] = {"name": j, "cf": [_f32(a) for a in p] + [_f32(m[i][jj]) for i in range(3) for jj in range(3)],
                        "style": STYLE[k["s"]], "dir": DIRECTION[k["d"]], "weight": 1 if v else 0, "children": []}
        root = {"name": "HumanoidRootPart", "cf": [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1], "style": 0, "dir": 0,
                "weight": 1, "children": []}
        for j, par in T.TREE:
            if j in nodes:
                (root if par == "HumanoidRootPart" else nodes[par])["children"].append(nodes[j])
        ms = [{"name": m, "value": ""} for m, mt in d["markers"] if abs(mt - k["t"]) < 1e-6]
        frames.append({"name": "KF" + T._n(k["t"]), "time": _f32(t), "poses": [root], "markers": ms})
    return {"name": d["name"], "priority": PRIORITY[d["priority"]], "loop": d["loop"], "keyframes": frames}


def _flat(p, out, path=""):
    out[path + p["name"]] = p
    for c in p["children"]:
        _flat(c, out, path + p["name"] + "/")
    return out


def verify(studio_dump, spec):
    mine = clip_dump(spec)
    theirs = next(c for c in json.load(open(studio_dump)) if c["name"] == mine["name"])
    tk = {round(k["time"], 4): k for k in theirs["keyframes"]}
    worst, missing, meta = 0.0, 0, 0
    for k in mine["keyframes"]:
        o = tk.get(round(k["time"], 4))
        if o is None:
            missing += 1
            continue
        a, b = _flat(k["poses"][0], {}), _flat(o["poses"][0], {})
        if set(a) != set(b):
            meta += 1
        for n in a:
            if n in b:
                worst = max(worst, max(abs(x - y) for x, y in zip(a[n]["cf"], b[n]["cf"])))
                if (a[n]["style"], a[n]["dir"], a[n]["weight"]) != (b[n]["style"], b[n]["dir"], b[n]["weight"]):
                    meta += 1
        if [m["name"] for m in k["markers"]] != [m["name"] for m in o["markers"]]:
            meta += 1
    print(f"{mine['name']}: {len(mine['keyframes'])} kf (studio {len(theirs['keyframes'])}), missing {missing}, "
          f"pose-tree/ease/weight/marker mismatches {meta}, worst CFrame component diff {worst:.2e}; "
          f"priority {mine['priority']}/{theirs['priority']} loop {mine['loop']}/{theirs['loop']}")


if __name__ == "__main__":
    if sys.argv[1] == "--verify":
        verify(sys.argv[2], sys.argv[3])
    else:
        out = [clip_dump(p) for p in sys.argv[2:]]
        json.dump(out, open(sys.argv[1], "w"))
        print(sys.argv[1], [c["name"] for c in out])
