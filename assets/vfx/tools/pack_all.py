"""Pack every effect in assets/vfx/effects/ for Studio and the game.

    python assets/vfx/tools/pack_all.py            # upload list + build_templates.luau + manifest
    python assets/vfx/tools/pack_all.py --kits     # also the per-effect Studio kits + Lune checks

Writes
  assets/vfx/upload/<key>.png         every texture the effects need, one flat folder (Beam/Trail
                                      textures as transposed "__vt" copies: Roblox runs a beam
                                      texture's HEIGHT along the beam, the sim runs its width)
  assets/vfx/upload_list.json         {"textures": [{"file": key, "path": abs, "kind": "Image"}], "meshes": []}
  work/vfx/build_templates.luau       ONE edit-mode builder: every effect -> ReplicatedStorage.Assets.Vfx.<Name>
                                      (ids embedded from assets/vfx/ids.json when it exists; or set
                                      _G.VFX_IDS = {textures = {[key] = id}} before running it)
  assets/vfx/manifest.json            one row per effect
  assets/vfx/kits/<Name>.luau + .assets.json   (--kits) node sim/studio_kit.js, then Lune checks
"""
import json
import subprocess
import sys
from pathlib import Path

from PIL import Image

VFX = Path(__file__).resolve().parent.parent
ROOT = VFX.parent.parent
SIM = Path.home() / ".claude" / "skills" / "roblox-vfx" / "sim"
SKILL = SIM.parent
EFFECTS = sorted((VFX / "effects").glob("*.json"))


def tex_file(sid):
    base = sid[4:]
    vt = base.endswith("__vt")
    if vt:
        base = base[:-4]
    p = (VFX / "textures" / (base[4:] + ".png")) if base.startswith("tfa/") else (SIM / "textures" / (base + ".png"))
    return p, vt


def key_of(sid):
    return sid[4:].replace("/", "__") + ".png"


# --------------------------------------------------------------- value encoding (shared with the Luau decoder)
def enc(prop, v, beamish):
    if isinstance(v, dict):
        if "NumberRange" in v:
            return {"NR": v["NumberRange"]}
        if "NumberSequence" in v:
            return {"NS": [[round(x, 4) for x in k] for k in v["NumberSequence"]]}
        if "ColorSequence" in v:
            return {"CS": [[k[0]] + [round(c, 4) for c in k[1]] for k in v["ColorSequence"]]}
        if "Color3" in v:
            return {"C3": v["Color3"]}
        if "Vector3" in v:
            return {"V3": v["Vector3"]}
        if "Vector2" in v:
            return {"V2": v["Vector2"]}
        if "Enum" in v:
            return {"E": v["Enum"]}
        if "Ref" in v:
            return {"Ref": v["Ref"]}
        raise ValueError(f"unknown value {prop}={v}")
    if isinstance(v, str) and v.startswith("sim:"):
        if beamish and prop == "Texture":
            v = v + "__vt"
        return {"T": key_of(v)}, v
    return v


def pack_effect(d, needs):
    g = d.get("game", {})
    origin = g.get("origin", [0, 0, 0])
    beamish_paths = set()

    def node(n, top):
        cls = n["class"]
        beamish = cls in ("Beam", "Trail")
        out = {"c": cls, "n": n["name"]}
        if "CFrame" in n:
            cf = list(n["CFrame"])
            if top:
                cf = [round(cf[0] - origin[0], 3), round(cf[1] - origin[1], 3), round(cf[2] - origin[2], 3)] + cf[3:]
            out["cf"] = cf
        if "Size" in n:
            out["sz"] = n["Size"]
        if n.get("attrs"):
            out["a"] = n["attrs"]
        props = {}
        for k, v in (n.get("props") or {}).items():
            e = enc(k, v, beamish)
            if isinstance(e, tuple):
                e, sid = e
                needs.add(sid)
            props[k] = e
        if props:
            out["p"] = props
        if n.get("children"):
            out["k"] = [node(c, False) for c in n["children"]]
        return out

    inst = [node(n, True) for n in d["instances"]]
    tl = []
    for e in d.get("timeline", []):
        if e.get("sim"):
            continue
        act = e.get("do")
        if act not in ("emit", "set", "tween", "enable", "disable", "shake", "overlay"):
            raise ValueError(f"{d['name']}: timeline action {act} is not implemented by VfxKit")
        x = {k: v for k, v in e.items() if k not in ("kind", "spin", "seed", "rot")}
        for k in ("value", "from", "to"):
            if k in x and isinstance(x[k], dict):
                x[k] = enc(x.get("prop", ""), x[k], False)
        if act == "overlay":
            needs.add(x["image"])
            x["image"] = {"T": key_of(x["image"])}
        tl.append(x)
    tl.sort(key=lambda e: e["t"])
    meta = {"loop": bool(g.get("loop")), "attach": g.get("attach", "point"), "screen": bool(g.get("screen")),
            "duration": d["duration"], "notint": d["name"].startswith("Reveal_")}
    return {"name": d["name"], "meta": meta, "inst": inst, "tl": tl}


def lua_long(s):
    eq = "=" * 4
    while f"]{eq}]" in s:
        eq += "="
    return f"[{eq}[{s}]{eq}]"


def main():
    kits = "--kits" in sys.argv
    needs, packed = set(), []
    for f in EFFECTS:
        d = json.loads(f.read_text(encoding="utf-8"))
        packed.append(pack_effect(d, needs))

    # ---- upload set
    up = VFX / "upload"
    up.mkdir(exist_ok=True)
    rows = []
    for sid in sorted(needs):
        src, vt = tex_file(sid)
        dst = up / key_of(sid)
        im = Image.open(src).convert("RGBA")
        if vt:
            im = im.transpose(Image.TRANSPOSE)
        im.save(dst)
        rows.append({"file": key_of(sid), "path": str(dst), "kind": "Image", "source": str(src), "transposed": vt})
    (VFX / "upload_list.json").write_text(json.dumps({"textures": rows, "meshes": []}, indent=1))

    # ---- build_templates.luau
    ids_path = VFX / "ids.json"
    ids = json.loads(ids_path.read_text()) if ids_path.exists() else {"textures": {}, "meshes": {}}
    tmpl = (VFX / "tools" / "build_templates.template.luau").read_text(encoding="utf-8")
    data = "\n".join(f"\tEFFECTS[{json.dumps(p['name'])}] = {lua_long(json.dumps(p, separators=(',', ':')))}" for p in packed)
    out = tmpl.replace("--@@IDS@@", f"local IDS_JSON = {lua_long(json.dumps(ids, separators=(',', ':')))}")
    out = out.replace("--@@EFFECTS@@", data)
    wv = ROOT / "work" / "vfx"
    wv.mkdir(parents=True, exist_ok=True)
    (wv / "build_templates.luau").write_text(out, encoding="utf-8")
    print(f"build_templates.luau: {len(packed)} effects, {len(out):,} chars, {len(rows)} textures "
          f"({sum(1 for r in rows if r['file'] in ids.get('textures', {}))} with ids)")

    # ---- kits
    kit_ok = {}
    if kits:
        kd = VFX / "kits"
        kd.mkdir(exist_ok=True)
        for f in EFFECTS:
            r = subprocess.run(["node", str(SIM / "studio_kit.js"), str(f), str(kd)], capture_output=True, text=True, cwd=str(SIM))
            if r.returncode:
                print("KIT FAIL", f.stem, r.stderr[-400:])
        for f in EFFECTS:
            src = kd / (f.stem.lower() + ".luau")
            alt = [p for p in kd.glob("*.luau") if p.stem.lower() == f.stem.lower()]
            if alt and alt[0].name != f.stem + ".luau":
                alt[0].rename(kd / (f.stem + ".luau"))
                aj = kd / (alt[0].stem + ".assets.json")
                if aj.exists():
                    aj.rename(kd / (f.stem + ".assets.json"))
        for f in EFFECTS:
            k = kd / (f.stem + ".luau")
            res = []
            for chk in ("compile_check", "build_check"):
                r = subprocess.run(["lune", "run", str(SIM / "tools" / "lune" / f"{chk}.luau"), str(k)], capture_output=True, text=True, cwd=str(ROOT))
                res.append("OK" if r.returncode == 0 and "FAIL" not in r.stdout.upper() else "FAIL: " + (r.stdout + r.stderr)[-300:].strip())
            kit_ok[f.stem] = res
            print(f"{f.stem:22s} compile {res[0][:60]} | build {res[1][:60]}")
        (VFX / "kits" / "_checks.json").write_text(json.dumps(kit_ok, indent=1))
    elif (VFX / "kits" / "_checks.json").exists():
        kit_ok = json.loads((VFX / "kits" / "_checks.json").read_text())

    # ---- manifest
    rows = []
    for f, p in zip(EFFECTS, packed):
        d = json.loads(f.read_text(encoding="utf-8"))
        m = VFX / "metrics" / (f.stem + ".json")
        peak = max((x["n"] for x in json.loads(m.read_text())), default=0) if m.exists() else None
        crit = None
        if m.exists():
            r = subprocess.run([sys.executable, str(SKILL / "scripts" / "critic_gate.py"), str(f), "--metrics", str(m)], capture_output=True, text=True)
            lines = [ln for ln in r.stdout.splitlines() if ln[:4] in ("WARN", "FAIL")]
            crit = "PASS" if not lines else "; ".join(" ".join(ln.split()) for ln in lines)
        attach = p["meta"]["attach"]
        rows.append({"name": f.stem, "loop": p["meta"]["loop"], "duration": d["duration"], "attach": attach,
                     "particles_peak": peak, "strip": f"assets/vfx/strips/{f.stem}.jpg" if (VFX / "strips" / (f.stem + ".jpg")).exists() else None,
                     "kit": f"assets/vfx/kits/{f.stem}.luau" if (VFX / "kits" / (f.stem + ".luau")).exists() else None,
                     "kit_checks": kit_ok.get(f.stem), "critic": crit, "notes": d.get("note", "")})
    (VFX / "manifest.json").write_text(json.dumps({"effects": rows}, indent=1))
    print("manifest:", len(rows), "effects")


if __name__ == "__main__":
    main()
