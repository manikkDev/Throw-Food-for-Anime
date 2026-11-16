"""Judging renders (not deliverables): chosen frames of a spec at a larger size, in up to four views.

  python tools/anim/look.py <Name> <out.png> f1 f2 ... [--views side,front,left,front34] [--size 420]

Renders the whole clip in those views (the camera frames the whole take, as for the deliverable), then tiles
the asked frames: one row per view. Frames go to work/anim/look/<Name>/.
"""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import run  # noqa: E402

ALL = {"side": [1.0, 0.0, 0.08], "left": [-1.0, 0.0, 0.08], "front": [0.0, 1.0, 0.08],
       "front34": [0.7, 1.0, 0.3], "back34": [-0.6, -1.0, 0.35]}


def main():
    args = [a for a in sys.argv[1:]]
    views = ["side", "front", "front34"]
    size = 420
    if "--views" in args:
        i = args.index("--views")
        views = args[i + 1].split(",")
        del args[i:i + 2]
    if "--size" in args:
        i = args.index("--size")
        size = int(args[i + 1])
        del args[i:i + 2]
    name, out, frames = args[0], args[1], [int(a) for a in args[2:]]
    spec = json.load(open(run.spec_path(name)))
    spec["views"] = {v: ALL[v] for v in views}
    spec["w"] = spec["h"] = size
    spec["track"] = []
    d = os.path.join(run.WORK, "look", name)
    os.makedirs(d, exist_ok=True)
    for f in os.listdir(d):
        os.remove(os.path.join(d, f))
    p = os.path.join(d, "_spec.json")
    json.dump(spec, open(p, "w"))
    code, log = run.blender("anim_render.py", p, d)
    if code != 0:
        print("\n".join(log.splitlines()[-15:]))
        sys.exit(1)
    ins, fc = [], ""
    k = len(frames)
    for v in views:
        for f in frames:
            ins += ["-i", os.path.join(d, f"{v}_{f:03d}.png")]
    for vi in range(len(views)):
        fc += "".join(f"[{vi * k + j}]" for j in range(k)) + f"hstack={k}[r{vi}];" if k > 1 else f"[{vi * k}]null[r{vi}];"
    fc += "".join(f"[r{vi}]" for vi in range(len(views))) + (f"vstack={len(views)}" if len(views) > 1 else "null")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", *ins, "-filter_complex", fc, "-frames:v", "1", out], check=True)
    print(out)


if __name__ == "__main__":
    main()
