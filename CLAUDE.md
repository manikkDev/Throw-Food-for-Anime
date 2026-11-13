# Throw Food for Anime: agent guide

Roblox game built almost entirely by AI agents with the SyphoDev Roblox skills
(`~/.claude/skills/*`). This file is loaded automatically in every session. Keep it short and true.

## How work is driven

- Front door: the `create-roblox-game` skill, **one section per session**
  (1 research+design, 2 code+loop, 3 world+visuals, 4 motion+sound, 5 assembly+playtest, 6 publish).
  First command of every later session:
  `python ~/.claude/skills/create-roblox-game/scripts/section.py resume --game "throw food"`
- `new_game.py` was ALREADY run for this game on 2026-11-13 (scaffold + `design/game.json` full of
  TODOs). Section 1 must NOT run it again; it fills `design/game.json` instead.
- `design/game.json` is the contract. `publish.place_id` = 106586376894468,
  `publish.universe_id` = 10776373502 (owner: user 3540923881). The place has Team Create on.

## Toolchain (all verified 2026-11-13)

| Thing | Version / location |
|---|---|
| Rojo CLI + Studio plugin | 7.7.1 both (Creator Store plugin). Never mix versions: 7.6 plugin cannot talk to 7.7 server |
| Rokit tools (`rokit.toml`) | rojo 7.7.1, wally 0.3.2, selene 0.32.0, stylua 2.6.0, lune 0.11.1 |
| Gates | `python ~/.claude/skills/roblox-code/scripts/check.py` (rojo build, lune tests, selene, stylua) |
| Blender for skill scripts | 4.5.16 LTS: env `BLENDER` (`D:\Roblox Studio Games\_RobloxAI\tools\...`) |
| Blender for MCP / by hand | 5.2 (`C:\Program Files\Blender Foundation\Blender 5.2`). Never run skill scripts on 5.x |
| MCP servers (user scope) | `Roblox_Studio` (built-in Studio MCP), `blender` (`mcp-for-blender@2.2.7`) |
| Shared toolkit | `D:\Roblox Studio Games\_RobloxAI` (rigs, Kiln, VFX library, bootstrap scripts) |

## Hard rules

1. **Disk is the source of truth for code.** Edit `src/`, sync with `rojo serve`. Never edit scripts
   in Studio and never write script source over MCP. MCP is for geometry, inspection, playtests.
2. **Gates green before Studio.** Run `check.py` after every code change; do not hand broken code to Rojo.
3. **Exactly one Studio MCP, one Rojo connection, one Studio window with the place.** Two of any of
   these duplicates modules or deadlocks. Never `open_application` Roblox Studio with computer-use
   when it is already running (it launches a second Studio).
4. **Secrets never appear in chat, files, logs or commits.** Keys live in user env vars
   (`ROBLOX_API_KEY`, `HF_TOKEN`, `CF_API_TOKEN`, ...). Check presence only, e.g.
   `python -c "import os;print(bool(os.environ.get('ROBLOX_API_KEY')))"`. Never print, echo, or
   pass a key on a command line. To set or rotate one, the user runs
   `D:\Roblox Studio Games\_RobloxAI\bootstrap\set-secret.ps1` themselves.
5. **Never press Ctrl+S in Studio** (it publishes). Publishing is section 6 and needs the user's go-ahead.
6. **No AI slop.** Real meshes, not stand-ins; VFX judged frame by frame in the sim; animations judged
   on rendered frames; every generated asset must be wired into the game (an unused asset is a failed stage).
7. **Git:** commit at the end of each approved section; push only when the user says so.
   Never commit `*.rbxl`, `Packages/`, `work/`, or anything secret (see `.gitignore`).

## Known traps on this machine

- Studio MCP drops every 5-15 min and its "Enable Studio as MCP server" toggle can turn off after a
  Studio update: re-enable it (Assistant > ... > Manage MCP Servers), don't debug your code.
- `execute_luau` drops all output if the script yields: split the call or use `task.delay`.
- Direct Studio calls without the client: `python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py`
  (`luau --code ...`, `--dm Server` reaches the running playtest server).
- After reinstalling the skills, re-apply local fixes:
  `python "D:\Roblox Studio Games\_RobloxAI\bootstrap\patch_skills.py"`.
