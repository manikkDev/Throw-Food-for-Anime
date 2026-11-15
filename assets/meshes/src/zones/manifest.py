"""Write assets/meshes/manifest_zones_a.json from MEASURED data (Blender re-import of each GLB +
converter output). Gate results and notes come from GATE below, written after looking at renders."""
import json, pathlib, sys
HERE = pathlib.Path(__file__).resolve().parent
GAME = HERE.parents[3]; WORK = GAME / "work/models/zones_a"
kit = json.load(open(GAME / "design/kit.json", encoding="utf-8"))
props = {**kit["zone_props"], **kit.get("zone_props_v2", {})}; keys = kit["style"]["zone_key_colours"]
GATEF, OUTF = (sys.argv[1], sys.argv[2]) if len(sys.argv) > 2 else ("gate.json", "manifest_zones_a.json")
GATE = json.load(open(HERE / GATEF, encoding="utf-8"))
entries = []
for n, g in GATE.items():
    m = json.load(open(WORK / n / "measure.json"))[n]
    _c = (WORK / n / "convert.json").read_text(); conv = json.loads(_c[_c.index("{"):])
    zone = next((z for z in keys if n.startswith(f"Prop_{z}_")), "shared")
    hexes = [p["hex"] for p in m["parts"]]
    tgt = props[n]["size"]
    entries.append({
        "name": n, "path": f"assets/meshes/zones/{n}.glb", "source": f"assets/meshes/src/zones/{n}.kiln.js",
        "tris": m["tris"], "bounds_studs": m["bounds_studs"], "bounds_converter_studs": conv["sizeStuds"],
        "target_studs": tgt, "size_error_pct": [round(100 * (a - b) / b, 1) for a, b in zip(m["bounds_studs"], tgt)],
        "min_studs": m["min_studs"], "colour_parts": [{"part": p["part"], "hex": p["hex"]} for p in m["parts"]],
        "zone_key": keys.get(zone, "#FFD23F+#FFFFFF"), "zone_key_present": (keys[zone] in hexes) if zone in keys else ("#FFD23F" in hexes and "#FFFFFF" in hexes),
        "tier": 3, "route": "kiln -> kiln_to_roblox.mjs", "front": "-Z", "verified": g["verified"],
        "gate": g.get("gate", {}), "notes": g.get("notes", ""),
    })
out = GAME / "assets/meshes" / OUTF
out.write_text(json.dumps({"generated_by": "assets/meshes/src/zones/manifest.py",
    "measured_with": "Blender 4.5 re-import of each GLB (tris, bounds); converter sizeStuds cross-check",
    "integrator_notes": [
        "One MeshPart per colour; the hex is the _RRGGBB suffix of each mesh/material name. GLB baseColorFactor is the linear encoding of that hex (checked: #8A -> 0.2542).",
        "Not uploaded: no modelId / meshId / image ids exist yet. No textures: colour is per-part, so there is no colour-map id to attach.",
        "Set CollisionFidelity (Box/Hull) or CanCollide=false on decorative parts: mesh collision is on by default.",
        "Non-bible colours used: red #F04848 (hurdle, lighthouse), yellow #FFD23F (warm highlight), cream #FFF1DC (clock tower walls), brick #D0603F (school gate)."],
    "assets": entries}, indent=1), encoding="utf-8")
print("manifest", len(entries), "entries ->", out)
