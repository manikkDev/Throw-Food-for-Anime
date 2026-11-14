#!/usr/bin/env python3
"""Emit `src/server/Config/ServerConfig.luau` from `design/game.json` `server_config`.

    python tools/gen_server_config.py            write the file
    python tools/gen_server_config.py --check    exit 1 if it has drifted

WHY a second config: `GameConfig.luau` lives in ReplicatedStorage, so every client can read it.
That is right for prices and odds (the client shows them) and wrong for anything that must stay
unknown until it is announced - promo codes above all: a code in the shared config is leaked the
day it is added. `server_config` is generated into ServerScriptService, which never replicates.

The Luau emitter and the formatter step are the skill's own (gen_config.py), so both generated
files are laid out identically and both `--check`s compare formatted against formatted.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path.home() / ".claude" / "skills" / "create-roblox-game" / "scripts"))
import gen_config  # noqa: E402

BANNER = """--!strict
-- GENERATED FILE - DO NOT EDIT BY HAND.
-- Source: design/game.json `server_config`
-- Regenerate: python tools/gen_server_config.py
-- Server-only tunables: this module is under ServerScriptService and is never
-- sent to a client. Promo codes live here so they cannot be read before they
-- are announced.
"""


def render(section: dict) -> str:
    text = f"{BANNER}\nlocal ServerConfig = {gen_config.emit(section)}\n\nreturn ServerConfig\n"
    return gen_config.stylua(text, ROOT)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--check", action="store_true", help="exit 1 if the file on disk has drifted")
    a = ap.parse_args()

    game = ROOT / "design" / "game.json"
    out = ROOT / "src" / "server" / "Config" / "ServerConfig.luau"
    contract = json.loads(game.read_text(encoding="utf-8"))
    section = contract.get("server_config")
    if not isinstance(section, dict):
        print("FAIL design/game.json has no `server_config` object")
        return 1
    if "Codes" in contract.get("config", {}).get("Rewards", {}):
        print("FAIL promo codes are in `config` (sent to every client); move them to `server_config`")
        return 1
    text = render(section)

    if a.check:
        if not out.exists() or out.read_text(encoding="utf-8") != text:
            print(f"FAIL {out} has drifted from {game}; run tools/gen_server_config.py")
            return 1
        print(f"ok   ServerConfig matches the contract ({len(section)} sections)")
        return 0

    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text, encoding="utf-8", newline="\n")
    print(f"wrote {out} ({len(text)} bytes, {len(section)} sections)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
