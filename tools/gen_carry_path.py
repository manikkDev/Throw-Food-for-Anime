"""PlaceHero's hero path (work/anim/upload6/placehero_path.json, written by the animation stage) ->
src/shared/Config/CarryPath.luau (GENERATED): where the carried hero's LowerTorso is, in the carrier's
HumanoidRootPart space, every 1/30 s of the PlaceHero clip up to its Place marker, and the markers.
CarryController moves the hero along it so it travels with the player's hands.

    python tools/gen_carry_path.py
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "work" / "anim" / "upload6" / "placehero_path.json"
RIDE = ROOT / "work" / "anim" / "upload6" / "ride.json"
OUT = ROOT / "src" / "shared" / "Config" / "CarryPath.luau"


def main() -> int:
    d = json.loads(SRC.read_text(encoding="utf-8"))
    markers = d["markers"]
    lines = [
        "--!strict",
        "-- GENERATED FILE - DO NOT EDIT BY HAND.",
        "-- Source: work/anim/upload6/placehero_path.json (the PlaceHero clip's hero path)",
        "-- Regenerate: python tools/gen_carry_path.py",
        "-- Space: the carrier's HumanoidRootPart (X right, Y up, -Z forward), R15 scale 1, hero scale 0.55.",
        "",
        "local CarryPath = {",
        f"\tFps = {d['fps']},",
        f"\tHop = {markers['Hop']},",
        f"\tGrab = {markers['Grab']},",
        f"\tPlace = {markers['Place']},",
        "\t-- the hero's LowerTorso centre at each frame, from t = 0 to the Place marker",
        "\tLowerTorso = {",
    ]
    for f in d["frames"]:
        if f["t"] > markers["Place"] + 1e-6:
            break
        x, y, z = f["lowertorso"]
        lines.append(f"\t\tVector3.new({x}, {y}, {z}),")
    lines += ["\t},", "}", "", "return CarryPath", ""]
    OUT.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print(f"wrote {OUT} ({sum(1 for line in lines if 'Vector3.new' in line)} frames)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
