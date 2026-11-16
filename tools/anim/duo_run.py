"""Batch r6 two-rig renders: the carrier clip with the carried hero (real rig meshes, scale 0.55) placed per frame.

  python tools/anim/duo_run.py track CarriedRide            hero clip -> work/anim/upload6/duo/track_<Name>.json
  python tools/anim/duo_run.py ride  [--dry]                CarryShoulder + CarriedRide at the ride offset
  python tools/anim/duo_run.py place [--dry]                PlaceHero + the hero along the PlaceHero path
--dry: the clash report only (real meshes, every frame), no frames. Otherwise frames -> a sheet (every 4th frame,
3 views) + a GIF in assets/animations/renders/<Clip>_duo_sheet.png / <Clip>_duo.gif, and the clash report.
"""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import run  # noqa: E402

DUO = os.path.join(run.WORK, "upload6", "duo")


def blender_duo(*args):
    cmd = [run.BLENDER, "--background", run.RIG, "--enable-autoexec", "--python-exit-code", "1",
           "--python", os.path.join(HERE, "duo_blender.py"), "--", *args]
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    return r.returncode, r.stdout + r.stderr


def track(name, spec=None):
    os.makedirs(DUO, exist_ok=True)
    out = os.path.join(DUO, f"track_{name}.json")
    code, log = blender_duo("track", spec or run.spec_path(name), out)
    if code != 0:
        raise SystemExit(f"track {name} FAILED\n" + "\n".join(log.splitlines()[-20:]))
    print("\n".join(ln for ln in log.splitlines() if ln.startswith("=== TRACK")))
    return out


def M(T, S, yaw_pitch=(0.0, 0.0)):
    import numpy as np
    from scipy.spatial.transform import Rotation as Rot
    Rm = Rot.from_euler("zx", [yaw_pitch[0], yaw_pitch[1]], degrees=True).as_matrix() * S
    m = np.eye(4)
    m[:3, :3] = Rm
    m[:3, 3] = T
    return m.tolist()


def render(clip, duo, dry):
    p = os.path.join(DUO, f"duo_{clip}.json")
    json.dump(duo, open(p, "w"))
    frames = os.path.join(run.WORK, "frames", clip + "_duo")
    os.makedirs(frames, exist_ok=True)
    for f in os.listdir(frames):
        os.remove(os.path.join(frames, f))
    code, log = blender_duo("render", run.spec_path(clip), frames, p, *(["--dry"] if dry else []))
    lines = log.splitlines()
    i = next((k for k, ln in enumerate(lines) if ln.startswith("=== CLASH")), None)
    print("\n".join(ln for ln in lines if ln.startswith(("=== done", "=== animated")) or "FAILED" in ln))
    print("\n".join(lines[i:i + 40]) if i is not None else "\n".join(lines[-25:]))
    if code != 0 or dry:
        return
    views = list(json.load(open(run.spec_path(clip)))["views"])
    nfr = len([f for f in os.listdir(frames) if f.startswith(views[0] + "_")])
    sel = list(range(0, nfr, 4))
    ins, filt = [], []
    for vi, v in enumerate(views):
        ins += ["-start_number", "0", "-i", os.path.join(frames, v + "_%03d.png")]
        filt.append(rf"[{vi}]select='not(mod(n\,4))',scale=170:-1,tile={len(sel)}x1[t{vi}]")
    filt.append("".join(f"[t{vi}]" for vi in range(len(views))) + f"vstack={len(views)}")
    sheet = os.path.join(run.RENDERS, clip + "_duo_sheet.png")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", *ins, "-filter_complex", ";".join(filt), "-frames:v", "1",
                    "-fps_mode", "passthrough", sheet], check=True)
    gins = []
    for v in views:
        gins += ["-framerate", "30", "-start_number", "0", "-i", os.path.join(frames, v + "_%03d.png")]
    fc = ("".join(f"[{i}]scale=260:-1[v{i}];" for i in range(len(views))) + "".join(f"[v{i}]" for i in range(len(views)))
          + f"hstack={len(views)},split[s0][s1];[s0]palettegen=stats_mode=diff[p];[s1][p]paletteuse=dither=bayer:bayer_scale=3")
    gif = os.path.join(run.RENDERS, clip + "_duo.gif")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", *gins, "-filter_complex", fc, "-loop", "0", gif], check=True)
    print(sheet)
    print(gif)


def ride(dry):
    import clips_r6 as C6
    T, _, _ = C6.ride()
    tr = track("CarriedRide")
    duo = {"tracks": {"ride": tr}, "frames": [{"track": "ride", "f": i, "M": M(T, C6.S)} for i in range(C6.RIDE_F)],
           "allow": [["RightHand", "RightFoot"], ["RightHand", "LeftFoot"], ["Head", "LeftHand"]]}
    render("CarryShoulder", duo, dry)


def place(dry):
    import clips_r6 as C6
    path = C6.place_path()
    tr = track("CarriedRide")
    st = track("HeroStand", C6.stand_spec_path())
    frames = []
    for i, smp in enumerate(path["frames"]):
        frames.append({"track": "ride" if smp["pose"] == "CarriedRide" else "stand",
                       "f": smp.get("ride_frame", 0), "M": M(smp["origin_rig"], C6.S, (smp["yaw"], smp["pitch"]))})
    duo = {"tracks": {"ride": tr, "stand": st}, "frames": frames,
           "allow": [[h, p] for h in ("RightHand", "LeftHand") for p in ("LowerTorso", "UpperTorso", "RightFoot", "LeftFoot")]}
    render("PlaceHero", duo, dry)


if __name__ == "__main__":
    cmd, dry = sys.argv[1], "--dry" in sys.argv
    if cmd == "track":
        track(sys.argv[2])
    elif cmd == "ride":
        ride(dry)
    elif cmd == "place":
        place(dry)
