#!/usr/bin/env python3
"""Emit `src/shared/Config/Animations.luau` from the animation spec and the uploaded clip ids.

    python tools/gen_anim_ids.py            write the file
    python tools/gen_anim_ids.py --check    exit 1 if it has drifted

Sources:
    design/animations.json      the 14 clips (name, priority, looped) and the Roblox-owned emotes
    assets/animations/ids.json  {"<ClipName>": assetId} once the clips are uploaded (optional)

A clip with no uploaded id ships with id = "": the client (Fx/Motion.luau) then plays the
KeyframeSequence ReplicatedStorage.Assets.Anims.<Name> registered for this session (Studio
play-testing), or nothing. WHY generated: an id only exists after an upload, a clip can be
re-uploaded (new id) without any code changing, and a clip with no id must stay silent.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SPEC = ROOT / "design" / "animations.json"
IDS = ROOT / "assets" / "animations" / "ids.json"
OUT = ROOT / "src" / "shared" / "Config" / "Animations.luau"

BANNER = """--!strict
-- GENERATED FILE - DO NOT EDIT BY HAND.
-- Source: design/animations.json + assets/animations/ids.json (uploaded clip ids)
-- Regenerate: python tools/gen_anim_ids.py
-- id = "" means not uploaded yet: Fx/Motion falls back to the session KeyframeSequence.
"""

PRIORITIES = {"Core", "Idle", "Movement", "Action", "Action2", "Action3", "Action4"}


def clip_priority(clip: dict) -> str:
    explicit = clip.get("priority")
    if isinstance(explicit, str) and explicit in PRIORITIES:
        return explicit
    # animations.json: idles at Core (default walk/run still shows on the legs), the rest Action
    return "Core" if clip["name"].startswith("Idle") else "Action"


def clip_looped(clip: dict) -> bool:
    explicit = clip.get("looped")
    if isinstance(explicit, bool):
        return explicit
    # the idles and the three training reps are loops; the rest are one-shots
    return clip["name"].startswith(("Idle", "Train"))


def render() -> str:
    spec = json.loads(SPEC.read_text(encoding="utf-8"))
    ids: dict[str, int] = {}
    if IDS.exists():
        for key, value in json.loads(IDS.read_text(encoding="utf-8")).items():
            if isinstance(value, int) and not key.startswith("_"):
                ids[key] = value
    lines = [
        BANNER,
        "export type Clip = { id: string, priority: string, looped: boolean }",
        "",
        "local Animations: { Clips: { [string]: Clip }, Emotes: { string } } = {",
        "\tClips = {",
    ]
    for clip in sorted(spec["clips"], key=lambda c: c["name"]):
        name = clip["name"]
        asset = f"rbxassetid://{ids[name]}" if name in ids else ""
        looped = "true" if clip_looped(clip) else "false"
        lines.append(
            f'\t\t{name} = {{ id = "{asset}", priority = "{clip_priority(clip)}", looped = {looped} }},'
        )
    lines += ["\t},", "\t-- Roblox-owned emotes: play in any experience (variety on the pedestals)", "\tEmotes = {"]
    for emote in spec.get("roblox_owned", {}).get("emotes_for_variety", []):
        lines.append(f'\t\t"rbxassetid://{int(emote)}",')
    lines += ["\t},", "}", "", "return Animations", ""]
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    text = render()
    uploaded = text.count('id = "rbxassetid')
    if a.check:
        if not OUT.exists() or OUT.read_text(encoding="utf-8") != text:
            print(f"FAIL {OUT} has drifted from design/animations.json / assets/animations/ids.json; "
                  "run tools/gen_anim_ids.py")
            return 1
        print(f"ok   Animations matches the spec ({uploaded} clips uploaded)")
        return 0
    OUT.write_text(text, encoding="utf-8", newline="\n")
    print(f"wrote {OUT} ({uploaded} clips uploaded)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
