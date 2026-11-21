#!/usr/bin/env python3
"""The aura showcase (Workspace.AuraShowcase, Studio only): build it, or sync the owner's renames.

    python tools/studio/aura_showcase.py build   (re)build the showcase from design/auras.json
    python tools/studio/aura_showcase.py sync    read the owner's renames, record them, rebuild

The owner gives an aura to a hero by RENAMING that aura's dummy (AuraShowcase/Auras/<AuraKey>) to
the hero's name (or id). `sync` reads every dummy whose name is no longer its AuraKey attribute,
matches the name to a hero (name or id, any case), writes the line into design/auras.json
"heroes", regenerates Auras.luau (tools/gen_auras.py), rebuilds the aura templates in Studio and
the showcase. A name that matches no hero is reported and left alone. Studio must be open in EDIT
mode with the Studio MCP on.
"""
from __future__ import annotations

import json
import subprocess
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = ROOT / "design" / "auras.json"
GAME = ROOT / "design" / "game.json"
BUILDER = ROOT / "tools" / "studio" / "build_aura_showcase.luau"
WORK = ROOT / "work" / "auras"
MCP = Path.home() / ".claude" / "skills" / "create-roblox-game" / "scripts" / "studio_mcp.py"
ORIGIN = (-820, 320, -40)

sys.path.insert(0, str(ROOT / "tools"))
from gen_auras import assignments  # noqa: E402


def load():
    return json.loads(SPEC.read_text(encoding="utf-8")), json.loads(GAME.read_text(encoding="utf-8"))


def luau(code_file: Path, timeout: int = 600) -> str:
    out = subprocess.run([sys.executable, str(MCP), "luau", "--dm", "Edit", "--file", str(code_file)],
                         capture_output=True, text=True, timeout=timeout)
    if out.returncode != 0:
        raise SystemExit(f"studio call failed:\n{out.stdout}\n{out.stderr}")
    return out.stdout.strip()


def lua_value(v) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return json.dumps(v)
    if isinstance(v, list):
        return "{" + ", ".join(lua_value(x) for x in v) + "}"
    if isinstance(v, dict):
        return "{" + ", ".join(f"{k} = {lua_value(x)}" for k, x in v.items()) + "}"
    if v is None:
        return "nil"
    raise TypeError(v)


def build() -> None:
    spec, game = load()
    cfg = game["config"]
    colours = {name: "#" + row["Color"].lstrip("#") for name, row in cfg["Rarities"].items()}
    given = assignments(spec, game)
    names = {c["Id"]: c["Name"] for c in cfg["Characters"] + cfg["PremiumCharacters"]}
    users: dict[str, list[tuple[str, str]]] = {}
    for hid, key in given.items():
        users.setdefault(key, []).append((names.get(hid, hid), hid))
    tiers = {"A": "#9AA4B8", "B": "#4FD18B", "C": "#3FB6FF", "D": "#B266FF", "E": "#FFC83D"}
    auras = []
    for key, row in sorted(spec["templates"].items(), key=lambda kv: (kv[1]["tier"], kv[0])):
        auras.append({"key": key, "source": row["source"], "heroes": [n for n, _ in sorted(users.get(key, []))],
                      "ids": [i for _, i in sorted(users.get(key, []))],
                      "template": True, "color": tiers.get(row["tier"], "#FFFFFF")})
    dummy = next(c["Id"] for c in cfg["Characters"] if c["Rarity"] == "Common")
    # templates that did not convert (a pack with no body rig) are shown raw
    check = WORK / "showcase_check.luau"
    WORK.mkdir(parents=True, exist_ok=True)
    keys = ", ".join(json.dumps(a["key"]) for a in auras)
    check.write_text("local f = game.ReplicatedStorage.Assets.Auras\nlocal out = {}\nfor _, k in {" + keys
                     + "} do if not f:FindFirstChild(k) then table.insert(out, k) end end\n"
                     + "return table.concat(out, ',')", encoding="utf-8")
    lines = luau(check, 120).splitlines()
    missing = set(filter(None, lines[-1].split(","))) if lines else set()
    for a in auras:
        if a["key"] in missing:
            a["template"] = False
    header = "_G.SHOWCASE = " + lua_value({"origin": list(ORIGIN), "dummy": dummy}) + "\n"
    header += "_G.SHOWCASE.auras = " + lua_value(auras) + "\n"
    # every hero, in ranking order: lane heroes by rarity (Common first), then the premium heroes from
    # most to least likely; each wears its aura or none. Auras nobody wears follow, on mannequins.
    rank = {name: row["Order"] for name, row in cfg["Rarities"].items()}
    lane = sorted(enumerate(cfg["Characters"]), key=lambda ic: (rank.get(ic[1]["Rarity"], 99), ic[0]))
    entries = []
    for _, c in lane:
        entries.append({"id": c["Id"], "name": c["Name"], "key": given.get(c["Id"], ""),
                        "rank": c["Rarity"], "color": colours.get(c["Rarity"], "#FFFFFF")})
    for c in sorted(cfg["PremiumCharacters"], key=lambda c: -c.get("OddsPercent", 0)):
        entries.append({"id": c["Id"], "name": c["Name"], "key": given.get(c["Id"], ""),
                        "rank": "Premium", "color": "#FF5FA2"})
    for a in auras:
        if not a["heroes"]:
            entries.append({"id": "", "name": "", "key": a["key"], "rank": "", "color": a["color"]})
    header += "_G.SHOWCASE.entries = " + lua_value(entries) + "\n"
    out = WORK / "showcase.luau"
    out.write_text(header + BUILDER.read_text(encoding="utf-8"), encoding="utf-8")
    print(luau(out))
    if missing:
        print("shown raw (no body rig to convert):", ", ".join(sorted(missing)))


def sync() -> None:
    spec, game = load()
    cfg = game["config"]
    by_name = {}
    for row in cfg["Characters"] + cfg["PremiumCharacters"]:
        by_name[row["Name"].strip().lower()] = row["Id"]
        by_name[row["Id"].lower()] = row["Id"]
    read = WORK / "showcase_read.luau"
    WORK.mkdir(parents=True, exist_ok=True)
    read.write_text(
        "local s = workspace:FindFirstChild('AuraShowcase')\n"
        "local f = s and s:FindFirstChild('Auras')\nif not f then return 'NONE' end\n"
        "local out = {}\nfor _, m in f:GetChildren() do\n"
        "  local k = m:GetAttribute('AuraKey')\n"
        "  local was = m:GetAttribute('Label') or k\n"
        "  if k and m.Name ~= was then table.insert(out, k .. '=' .. m.Name) end\nend\n"
        "return 'RENAMED ' .. table.concat(out, ';')", encoding="utf-8")
    line = luau(read, 120).splitlines()[-1]
    if line == "NONE":
        raise SystemExit("no Workspace.AuraShowcase in the open place: run `build` first")
    pairs = [p for p in line.removeprefix("RENAMED ").split(";") if p]
    if not pairs:
        print("no dummy was renamed: nothing to sync")
        return
    changed, unknown = [], []
    for pair in pairs:
        key, _, label = pair.partition("=")
        if not key:  # a hero stand with no aura: nothing to give
            continue
        # one dummy may carry several heroes: "Hero A, Hero B" (or "Hero A + Hero B")
        for name in [n for n in label.replace("+", ",").split(",") if n.strip()]:
            hero = by_name.get(name.strip().lower())
            if not hero:
                unknown.append(name.strip())
                continue
            spec["heroes"][hero] = key
            changed.append(f"{hero} -> {key}")
    SPEC.write_text(json.dumps(spec, indent=1, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    print("recorded:", *changed, sep="\n  ")
    if unknown:
        print("no hero by these names (left alone):", ", ".join(unknown))
    subprocess.run([sys.executable, str(ROOT / "tools" / "gen_auras.py")], check=True)
    print(luau(WORK / "build.luau"))
    build()


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "build"
    {"build": build, "sync": sync}[cmd]()
