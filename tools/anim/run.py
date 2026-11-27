"""Animation pipeline for this game (roblox-animation skill, headless Blender 4.5).

  python tools/anim/run.py gen                      write every spec to assets/animations/specs
  python tools/anim/run.py dry Throw Celebrate      assertions + per-frame feet/hand track, no render
  python tools/anim/fkcheck.py Throw ...            pure-Python FK: floor, foot slip, arm/body overlap, contact
  python tools/anim/run.py render Throw ...         frames -> <Name>_sheet.png + <Name>.gif
  python tools/anim/run.py axis Throw ...           rbx_axis_check.py --mid, result cached
  python tools/anim/run.py batch out.png A B ...    stack the clips' sheets into one image
  python tools/anim/run.py manifest                 rewrite assets/animations/manifest.json
  python tools/anim/run.py build                    work/anim/build.lua (yield-free)
  python tools/anim/run.py build3                   batch r3 only -> work/anim/upload3/build_r3.lua
  python tools/anim/run.py build4                   batch r4 only -> work/anim/upload4/build_r4.lua
  python tools/anim/run.py build5                   batch r5 only -> work/anim/upload5/build_r5.lua
  python tools/anim/run.py build6                   batch r6 only -> work/anim/upload6/build_r6.lua
  python tools/anim/run.py build7                   batch r7 only -> work/anim/upload7/build_r7.lua
  python tools/anim/run.py build8                   batch r8 only -> work/anim/upload8/build_r8.lua
  python tools/anim/run.py build9                   batch r9 only -> work/anim/upload9/build_r9.lua
  python tools/anim/run.py build10                  batch r10 only -> work/anim/upload10/build_r10.lua
  python tools/anim/run.py probe A B ... [--frames]  mesh_probe.py: floor, foot slip, part overlaps (real meshes)
"""
import concurrent.futures as cf
import json
import math
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
SKILL = os.path.expanduser("~/.claude/skills/roblox-animation/scripts")
BLENDER = os.environ.get("BLENDER")
RIG = r"D:\Roblox Studio Games\_RobloxAI\rigs\MrXen0_R15RIG_v1.2.blend"
SPECS = os.path.join(ROOT, "assets", "animations", "specs")
RENDERS = os.path.join(ROOT, "assets", "animations", "renders")
WORK = os.path.join(ROOT, "work", "anim")
AXIS = os.path.join(WORK, "axis.json")
REV2 = {"Throw", "TrainStrike", "TrainPush", "TrainLift"}   # re-authored after the owner's review
ORDER = ["Throw", "TrainStrike", "TrainPush", "TrainLift", "TrainMeditate", "Celebrate",
         "IdleCool", "IdleCheer", "IdleBlade", "IdleNinja",
         "IdlePower", "IdleShy", "IdleFloat", "Eat", "RevealLand"]
R3 = ["HeroWalkIn", "HeroArrive", "CarryHold", "PlaceHero", "RebirthEvolve"]   # clips_r3.py, batch r3
ORDER += R3
R4 = ["HeroStalk", "HeroMenace", "RebirthAwaken"]   # clips_r4.py, batch r4 (renders in assets/animations/renders)
ORDER += R4
R5 = ["HeroPickUp"]   # clips_r5.py, batch r5
ORDER += R5
R6 = ["CarryShoulder", "CarriedRide", "PlaceHero"]   # clips_r6.py, batch r6 (PlaceHero v2 replaces r3's)
ORDER += [n for n in R6 if n not in ORDER]
R7 = ["HoldPitch", "HoldHeave", "ThrowHeave", "HoldSpin", "ThrowSpin"]   # clips_r7.py, batch r7 (plan 13 phase C)
ORDER += R7
R8 = ["TrainPost", "PostFlurry", "PostFinish", "TrainBreath", "BreathAscend"]   # clips_r8.py, batch r8 (plan 13 phase D)
ORDER += R8
R9 = ["TrainBoulder", "BoulderBarrage", "BoulderFinish", "PeakReady", "PeakLeft", "PeakMid", "PeakRight",
      "PeakStorm"]   # clips_r9.py, batch r9 (plan 13 phase E)
ORDER += R9
R10 = ["TrainPushup", "GravityFloat", "TrainOrb", "OrbAwaken", "OrbThrow"]   # clips_r10.py, batch r10 (plan 13 phase E)
ORDER += R10
R3_RENDERS = os.path.join(WORK, "r3")       # batch r3 keeps its sheets / GIFs here


def all_clips():
    import clips_player
    out = dict(clips_player.CLIPS)
    for mod in ("clips_hero", "clips_r3", "clips_r4", "clips_r5", "clips_r6", "clips_r7", "clips_r8", "clips_r9", "clips_r10"):
        try:
            out.update(__import__(mod).CLIPS)
        except ImportError:
            pass
    return out


def blender(script, *args):
    # anim_render.py runs through scene_render.py, which adds the spec's static set dressing
    # (_scene: the bag, the boulder) and bone-parented props (_attach: dumbbells) first.
    if script == "anim_render.py":
        path = os.path.join(HERE, "scene_render.py")
    elif script == "mesh_probe.py":
        path = os.path.join(HERE, script)
    else:
        path = os.path.join(SKILL, script)
    cmd = [BLENDER, "--background", RIG, "--enable-autoexec", "--python-exit-code", "1",
           "--python", path, "--", *args]
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    return r.returncode, r.stdout + r.stderr


def spec_path(n):
    return os.path.join(SPECS, n + ".json")


def gen(names):
    from animlib import write
    clips = all_clips()
    for n in names or clips:
        print("wrote", write(clips[n](), SPECS))


def dry(names):
    os.makedirs(WORK, exist_ok=True)
    for n in names:
        s = json.load(open(spec_path(n)))
        s.update(dry=True, track=["RightFoot", "LeftFoot", "RightHand", "LeftHand", "Head", "RightLowerLeg", "LowerTorso", "RightUpperArm"])
        p = os.path.join(WORK, f"dry_{n}.json")
        json.dump(s, open(p, "w"))
        code, out = blender("anim_render.py", p, os.path.join(WORK, "dryout"))
        lines = [ln for ln in out.splitlines() if re.match(r"\s+\w+\s+x\[", ln)
                 or "FAILED" in ln or "front-y" in ln or "=== CONTACT" in ln]
        print(f"--- {n} (exit {code})")
        print("\n".join(lines))
        if "--frames" in sys.argv:
            print("\n".join(ln for ln in out.splitlines() if re.match(r"\s+f\d\d t=", ln)))


def renders_for(n):
    return R3_RENDERS if (n in R3 and n not in R6) else RENDERS


def sheet_and_gif(n, frames, views):
    nfr = len([f for f in os.listdir(frames) if f.startswith(views[0] + "_")])
    step = max(1, math.ceil(nfr / 10))
    cols = math.ceil(nfr / step)
    RENDERS = renders_for(n)
    os.makedirs(RENDERS, exist_ok=True)
    ins, filt = [], []
    for i, v in enumerate(views):
        ins += ["-start_number", "0", "-i", os.path.join(frames, v + "_%03d.png")]
        filt.append(f"[{i}]select='not(mod(n\\,{step}))',scale=150:-1,tile={cols}x1[t{i}]")
    filt.append("".join(f"[t{i}]" for i in range(len(views))) + f"vstack={len(views)}")
    sheet = os.path.join(RENDERS, n + "_sheet.png")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", *ins, "-filter_complex", ";".join(filt),
                    "-frames:v", "1", "-fps_mode", "passthrough", sheet], check=True)
    gif = os.path.join(RENDERS, n + ".gif")
    gins = []
    for v in views:
        gins += ["-framerate", "30", "-start_number", "0", "-i", os.path.join(frames, v + "_%03d.png")]
    fc = ("".join(f"[{i}]scale=240:-1[v{i}];" for i in range(len(views)))
          + "".join(f"[v{i}]" for i in range(len(views)))
          + f"hstack={len(views)},split[s0][s1];[s0]palettegen=stats_mode=diff[p];"
          "[s1][p]paletteuse=dither=bayer:bayer_scale=3")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", *gins, "-filter_complex", fc, "-loop", "0", gif],
                   check=True)
    return sheet, gif


def render_one(n):
    s = json.load(open(spec_path(n)))
    frames = os.path.join(WORK, "frames", n)
    if os.path.isdir(frames):
        for f in os.listdir(frames):
            os.remove(os.path.join(frames, f))
    code, out = blender("anim_render.py", spec_path(n), frames)
    done = [ln for ln in out.splitlines() if ln.startswith("=== done") or "FAILED" in ln]
    if code != 0:
        return f"{n}: RENDER FAILED\n" + "\n".join(out.splitlines()[-15:])
    sheet, gif = sheet_and_gif(n, frames, list(s["views"]))
    return f"{n}: {' '.join(done)}\n   {sheet}\n   {gif}"


def render(names):
    with cf.ThreadPoolExecutor(max_workers=3) as ex:
        for res in ex.map(render_one, names):
            print(res, flush=True)


def axis(names):
    code, out = blender("rbx_axis_check.py", *[spec_path(n) for n in names], "--mid")
    cache = json.load(open(AXIS)) if os.path.exists(AXIS) else {}
    for n in names:
        m = re.search(rf"=== {re.escape(n)}\.json \([^)]*\): worst part error ([\d.]+) deg", out)
        if not m:
            cache[n] = "fail: no result (see log)"
            continue
        err = float(m.group(1))
        cache[n] = "pass" if err <= 2.0 else f"fail: worst {err:.2f} deg > 2.0"
        print(f"{n}: worst {err:.2f} deg -> {cache[n]}")
    for ln in out.splitlines():
        if "in-game path differs" in ln or "suggest beat" in ln or "FAILED" in ln:
            print("  ", ln[:220])
    os.makedirs(WORK, exist_ok=True)
    json.dump(cache, open(AXIS, "w"), indent=1)


def batch(out, names):
    ins = []
    for n in names:
        ins += ["-i", os.path.join(renders_for(n), n + "_sheet.png")]
    fc = "".join(f"[{i}]scale=1500:-1,pad=1500:ih+6:0:0:gray[p{i}];" for i in range(len(names)))
    fc += "".join(f"[p{i}]" for i in range(len(names))) + f"vstack={len(names)}"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", *ins, "-filter_complex", fc, "-frames:v", "1", out],
                   check=True)
    print(out)


def manifest():
    cache = json.load(open(AXIS)) if os.path.exists(AXIS) else {}
    clips = []
    for n in ORDER:
        p = spec_path(n)
        if not os.path.exists(p):
            continue
        s = json.load(open(p))
        rel = lambda q: os.path.relpath(q, ROOT).replace("\\", "/")
        clips.append({"name": n, "priority": s["priority"], "loop": s["loop"], "duration": s["duration"],
                      "markers": [{"name": m["name"], "time": m["time"]} for m in s.get("markers", [])],
                      "spec": rel(p), "sheet": rel(os.path.join(renders_for(n), n + "_sheet.png")),
                      "gif": rel(os.path.join(renders_for(n), n + ".gif")),
                      "axis_check": cache.get(n, "fail: not run")})
        if n in REV2:
            clips[-1]["upload"] = "NOT YET UPLOADED (rev 2, 2026-11-15): build in Studio and upload; ids.json still holds the old clip's id"
        for k in ("_contact", "_grip"):
            if k in s:
                clips[-1][k.lstrip("_")] = s[k]
    out = os.path.join(ROOT, "assets", "animations", "manifest.json")
    json.dump({"clips": clips}, open(out, "w"), indent=1)
    print(out, len(clips), "clips")


def export_copy(n):
    """Spec copy for to_roblox.py with the ROOT loc X/Y sign fixed.

    The rig's ROOT bone rests with local X = world -X and local Y = world -Y (probed), so a spec loc
    (lx, ly, lz) moves the body by world (-lx, -ly, lz) in the render (traps.md #45). to_roblox.py maps
    loc -> Roblox (lx, lz, -ly), i.e. it reads loc as a WORLD offset, so X and Y come out mirrored. Hand
    it the world offset (-lx, -ly, lz) and the game gets Roblox (dx, dz, -dy): forward stays forward.
    Clips that move the root on Z only are unchanged by this."""
    s = json.load(open(spec_path(n)))
    for k in s["keyframes"]:
        r = k["bones"].get("ROOT")
        if r and "loc" in r:
            lx, ly, lz = r["loc"]
            r["loc"] = [-lx + 0.0, -ly + 0.0, lz]
    p = os.path.join(WORK, "export", n + ".json")
    os.makedirs(os.path.dirname(p), exist_ok=True)
    json.dump(s, open(p, "w"), indent=1)
    return p


def build(names=None, out=None):
    specs = [export_copy(n) for n in (names or ORDER) if os.path.exists(spec_path(n))]
    r = subprocess.run([sys.executable, os.path.join(SKILL, "to_roblox.py"), *specs,
                        "--folder", "ReplicatedStorage.Assets.Anims", "--no-verify"],
                       capture_output=True, text=True, check=True)
    out = out or os.path.join(WORK, "build.lua")
    open(out, "w", encoding="utf-8").write(r.stdout)
    print(out, len(specs), "specs,", len(r.stdout), "chars")


if __name__ == "__main__":
    cmd, rest = sys.argv[1], [a for a in sys.argv[2:] if not a.startswith("--")]
    if cmd == "gen":
        gen(rest)
    elif cmd == "dry":
        dry(rest)
    elif cmd == "sheets":
        for n in rest:
            print(sheet_and_gif(n, os.path.join(WORK, "frames", n), list(json.load(open(spec_path(n)))["views"])))
    elif cmd == "keys":
        # keys <Name> <out.png> f1 f2 ... : chosen frames, both views, 220 px, for a close look
        n, outp, idx = rest[0], rest[1], rest[2:]
        fr = os.path.join(WORK, "frames", n)
        vs = list(json.load(open(spec_path(n)))["views"])
        ins = []
        for v in vs:
            for i in idx:
                ins += ["-i", os.path.join(fr, f"{v}_{int(i):03d}.png")]
        k = len(idx)
        fc = "".join(f"[{j}]scale=220:-1[s{j}];" for j in range(k * len(vs)))
        for vi in range(len(vs)):
            fc += "".join(f"[s{vi * k + j}]" for j in range(k)) + f"hstack={k}[r{vi}];"
        fc += "".join(f"[r{vi}]" for vi in range(len(vs))) + f"vstack={len(vs)}"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", *ins, "-filter_complex", fc,
                        "-frames:v", "1", outp], check=True)
        print(outp)
    elif cmd == "render":
        render(rest)
    elif cmd == "axis":
        axis(rest)
    elif cmd == "batch":
        batch(rest[0], rest[1:])
    elif cmd == "manifest":
        manifest()
    elif cmd == "build":
        build()
    elif cmd == "probe":
        for n in rest:
            code, out = blender("mesh_probe.py", spec_path(n), *(["--frames"] if "--frames" in sys.argv else []))
            lines = out.splitlines()
            i = next((k for k, ln in enumerate(lines) if ln.startswith(("=== MESH", "  f000"))), 0)
            print(f"--- {n} (exit {code})")
            print("\n".join(ln for ln in lines[i:] if ln.startswith(("===", "  "))) if code == 0
                  else "\n".join(lines[-20:]))
    elif cmd == "build10":
        os.makedirs(os.path.join(WORK, "upload10"), exist_ok=True)
        build(R10, os.path.join(WORK, "upload10", "build_r10.lua"))
    elif cmd == "build9":
        os.makedirs(os.path.join(WORK, "upload9"), exist_ok=True)
        build(R9, os.path.join(WORK, "upload9", "build_r9.lua"))
    elif cmd == "build8":
        os.makedirs(os.path.join(WORK, "upload8"), exist_ok=True)
        build(R8, os.path.join(WORK, "upload8", "build_r8.lua"))
    elif cmd == "build7":
        os.makedirs(os.path.join(WORK, "upload7"), exist_ok=True)
        build(R7, os.path.join(WORK, "upload7", "build_r7.lua"))
    elif cmd == "build6":
        os.makedirs(os.path.join(WORK, "upload6"), exist_ok=True)
        build(R6, os.path.join(WORK, "upload6", "build_r6.lua"))
    elif cmd == "build5":
        os.makedirs(os.path.join(WORK, "upload5"), exist_ok=True)
        build(R5, os.path.join(WORK, "upload5", "build_r5.lua"))
    elif cmd == "build4":
        os.makedirs(os.path.join(WORK, "upload4"), exist_ok=True)
        build(R4, os.path.join(WORK, "upload4", "build_r4.lua"))
    elif cmd == "build3":
        # batch r3 only: work/anim/upload3/build_r3.lua
        os.makedirs(os.path.join(WORK, "upload3"), exist_ok=True)
        build(R3, os.path.join(WORK, "upload3", "build_r3.lua"))
