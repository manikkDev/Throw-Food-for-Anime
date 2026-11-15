"""Build zone props: sync prelude, Kiln render, convert to Roblox GLB, record measurements.

    python build.py Name [Name ...]      (or --all)

Writes assets/meshes/zones/<Name>.glb, work/models/zones_a/<Name>/{kiln.glb,views.png,kiln.json,convert.json}.
"""
import json, os, re, subprocess, sys, pathlib

HERE = pathlib.Path(__file__).resolve().parent
GAME = HERE.parents[3]
OUT = GAME / "assets" / "meshes" / "zones"
WORK = GAME / "work" / "models" / "zones_a"
KILN = os.environ["KILN_HOME"]
CONV = pathlib.Path.home() / ".claude/skills/roblox-3d-model/scripts/kiln_to_roblox.mjs"
PRE = (HERE / "_prelude.js").read_text(encoding="utf-8")
PAT = re.compile(r"// ---- PRELUDE BEGIN.*?// ---- PRELUDE END ----\n", re.S)


def sync(path):
    src = path.read_text(encoding="utf-8")
    new = PAT.sub(lambda _: PRE, src) if PAT.search(src) else src
    if new != src:
        path.write_text(new, encoding="utf-8")


def build(name):
    src = HERE / f"{name}.kiln.js"
    sync(src)
    wd = WORK / name
    wd.mkdir(parents=True, exist_ok=True)
    npx = "npx.cmd" if os.name == "nt" else "npx"
    r = subprocess.run([npx, "--prefix", KILN, "kiln", "render", str(src), "--out", str(wd / "kiln.glb"),
                        "--views", str(wd / "views.png"), "--backdrop", "light", "--json"],
                       capture_output=True, text=True, encoding="utf-8")
    (wd / "kiln.json").write_text(r.stdout + "\n" + r.stderr, encoding="utf-8")
    if r.returncode != 0:
        print(f"{name}: KILN FAIL\n{r.stdout[-1500:]}\n{r.stderr[-1500:]}")
        return False
    k = json.loads(r.stdout)
    qa = k.get("qaReport", {})
    finds = [f for d in qa.get("dimensions", {}).values() for f in d.get("findings", [])]
    c = subprocess.run(["node", str(CONV), str(wd / "kiln.glb"), str(OUT / f"{name}.glb")],
                       capture_output=True, text=True, encoding="utf-8")
    (wd / "convert.json").write_text(c.stdout, encoding="utf-8")
    if c.returncode != 0:
        print(f"{name}: CONVERT FAIL {c.stderr}")
        return False
    j = json.loads(c.stdout[c.stdout.index("{"):])
    tris = sum(m["tris"] for m in j["meshes"])
    print(f"{name}: tris={tris} size={j['sizeStuds']} min={j['boundsStuds']['min']} "
          f"parts={[m['material'] for m in j['meshes']]} qa={qa.get('acceptance')}/{qa.get('disposition')} "
          f"findings={[(f.get('code') or f.get('id'), f.get('disposition') or f.get('severity')) for f in finds][:6]}")
    b = subprocess.run([os.environ["BLENDER"], "--background", "--python", str(HERE / "render_zone.py"), "--",
                        "--out", str(wd / "q34.png"), "--json", str(wd / "measure.json"), str(OUT / f"{name}.glb")],
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    if "RENDERED" not in b.stdout:
        print(f"{name}: RENDER FAIL {b.stdout[-800:]} {b.stderr[-800:]}")
        return False
    return True


if __name__ == "__main__":
    names = sys.argv[1:]
    if names == ["--all"]:
        names = sorted(p.name[:-8] for p in HERE.glob("Prop_*.kiln.js"))
    ok = all([build(n) for n in names])
    sys.exit(0 if ok else 1)
