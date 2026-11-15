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
2. **Gates green before Studio.** A project hook (`.claude/hooks/luau_gate.py`) runs `check.py`
   after every `.luau` edit and reports failures back; fix them before moving on, never bypass it.
3. **Exactly one Studio MCP, one Rojo connection, one Studio window with the place.** Two of any of
   these duplicates modules or deadlocks. Never `open_application` Roblox Studio with computer-use
   when it is already running (it launches a second Studio).
4. **Secrets never appear in chat, files, logs or commits.** Keys live in user env vars
   (`ROBLOX_API_KEY`, `HF_TOKEN`, `CF_API_TOKEN`, ...). Check presence only, e.g.
   `python -c "import os;print(bool(os.environ.get('ROBLOX_API_KEY')))"`. Never print, echo, or
   pass a key on a command line. To set or rotate one, the user runs
   `D:\Roblox Studio Games\_RobloxAI\bootstrap\set-secret.ps1` themselves.
5. **Saving is not publishing.** `mcp__Roblox_Studio__save_place` saves a new place VERSION to
   Roblox (Team Create) and never publishes. Publishing (players see it) is section 6 and needs
   the user's go-ahead. Do not save after every edit: each save adds a version.
6. **No AI slop.** Real meshes, not stand-ins; VFX judged frame by frame in the sim; animations judged
   on rendered frames; every generated asset must be wired into the game (an unused asset is a failed stage).
7. **Git:** commit at the end of each approved section; push only when the user says so.
   Never commit `*.rbxl`, `Packages/`, `work/`, or anything secret (see `.gitignore`).
8. **Snapshot every approved section** (rollback point for code AND place, matched):
   gates green -> `git commit` -> `git tag section-<N>` -> `save_place` with
   notes `"Section <N> approved (git section-<N>)"`. Push only when the user says, and push the tag explicitly (`git push origin main section-<N>`;
   `--follow-tags` skips these lightweight tags).
   Roll back: `git checkout section-<N>` + Creator Hub > place > Version History > restore that version.
   Baseline: tag `setup-baseline` = place version 6. Tag `section-1` = place version 34.
   Tag `section-2` = place version 57. Tag `section-3` = place version 121.

## Where the game's pieces live (since section 2)

- Code: `src/` (16 server services, 7 client controllers + `src/client/Ui/` (Screens, Pages), 12 pure Core modules with specs in `tests/`).
  `src/shared/Config/GameConfig.luau` is GENERATED from `design/game.json`: edit the JSON, then
  `python ~/.claude/skills/create-roblox-game/scripts/gen_config.py --dir .`. Pacing gate:
  `python tools/balance_sim.py --check`. Server-only tunables (promo codes) live in `server_config`
  in the same JSON: `python tools/gen_server_config.py` writes `src/server/Config/ServerConfig.luau`.
  Never put a code in `config` (it is sent to every client). Every gate at once: `python tools/gate.py`.
- Hero templates: `ReplicatedStorage.Assets.Characters.Char_<id>` (in the place, not in Rojo).
  Rebuilt from `ServerStorage.CharacterSources.R15_Final` by `tools/studio/bake_characters.luau`.
  The user's imports are archived in `ServerStorage.CharacterSources.R6_Originals` (31) and
  `.Originals_Batch2` (12) and `.Originals_Batch3` (16): never delete. New avatars: `tools/studio/build_r15.luau` rebuilds them to
  the standard rig, `python tools/studio/run_bake.py` bakes the whole roster (59 heroes today: 51 lane + 8 premium).
  Roster map: `design/characters/roster.json`; rules and traps: `design/characters/README.md`.
- The map is `Workspace.Map` in the place (terrain + about 13,300 parts: bases 84 x 72 on a 108 pitch, styled lanes, a store-asset town on the wall terraces and behind the hub; generator = `gen_map.py` + `gen_lane_style.py` + `gen_town.py`, textures `tools/map/make_textures.py` -> `assets/map/ids_textures.json`). Source: `design/map.json` + `tools/map/`
  (generator, emitter, `RUN.md`); build it with `python tools/map/build_in_studio.py`. `Blockout.luau` only
  builds a grey fallback when the place has no `Workspace.Map`.
- Creator Store models (free, the owner's request): cleaned sources in `ServerStorage.StoreAssets` (61, never delete; buildings assembled by `tools/studio/assemble_store_buildings.luau`; tags `design/store_assets.json` feed the map generator's pools) ->
  `python tools/studio/install_store_assets.py` -> `ReplicatedStorage.Assets.Kit.Prop_store_<Name>` and
  `assets/meshes/manifest-store.json`. Take a new one in through a quarantine folder: strip every script, GUI, sound,
  constraint and effect, count its parts (reject thousands), look at it, then add it to `StoreAssets`.
- Models: `design/kit.json` (art bible + sizes) -> Kiln sources `assets/meshes/src/` -> `tools/publish_meshes.py`
  (upload) -> `tools/studio/install_models.py` (templates in `ReplicatedStorage.Assets.{Kit,Gear,Foods}`) ->
  `tools/merge_manifest.py`. Parts are coloured from the hex at the end of their name.
- UI v3: one button system (`tools/ui/mp3.py`, screens `tools/ui/screens_v3.py`), checked by `tools/ui/fit_gate.py`; client side
  `Screens.setButtonState` and `Theme.BUTTON`. Icons: base key = flat glyph under 30 px, `...Big` key = glossy at 40 px and up.
  A UI change is only done when it has been looked at IN THE GAME (the mockups do not have Roblox's font metrics).
- UI: specs `design/ui/` -> `python tools/ui/build_ui.py` -> `src/ui/*.model.json` (`ReplicatedStorage.Ui`) and
  `design/ui/BINDINGS.md`; icon ids: `python tools/gen_icons.py` -> `src/shared/Config/Icons.luau` (GENERATED).
  Dead-label gate: `python ~/.claude/skills/roblox-ui/scripts/verify_labels.py --ui src/ui --client src/client`.
- Studio sessions use their own stores (`Profiles_Dev`, `LB_*_Dev`); test commands are the TEST menu.

## Known traps on this machine

- Studio MCP drops every 5-15 min and its "Enable Studio as MCP server" toggle can turn off after a
  Studio update: re-enable it (Assistant > ... > Manage MCP Servers), don't debug your code.
- `execute_luau` drops all output if the script yields: split the call or use `task.delay`.
- Direct Studio calls without the client: `python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py`
  (`luau --code ...`, `--dm Server` reaches the running playtest server).
- `screen_capture` returns a blank dark frame (or a black world behind live GUI) whenever the Studio
  window is minimised. Restore the window (Win32 ShowWindow on the running process), never
  `open_application`.
- During Play, `execute_luau` cannot see the game's Knit services or controllers (its `require` is a
  separate copy). Read state through instances and GUI text, fire remotes from the Client datamodel,
  and hook remotes to log what the server answered.
- Studio renders at about 15 fps whenever its window is not in front: a frame-rate reading is only valid with
  Studio focused (measured: 15 fps with the whole world hidden, 60 fps a minute later in front).
- A locked or sleeping screen stops Studio rendering: `screen_capture` times out and a RenderStepped probe never returns.
  Check `Get-Process LogonUI`; building the map still works.
- A UIStroke under a TextLabel must be `Contextual` to outline the letters; `Border` draws a box round the label.
- Roblox's importer delivers an uploaded glTF model turned half a turn about Y (front authored at -Z arrives at +Z).
  `tools/studio/install_models.py` turns every template back and puts its pivot at the base centre; a GUI adorned to a
  kit `Face_<hex>` MeshPart goes on `NormalId.Back`, a GUI on a plain anchor Part in front of a model on `Front`.
- `user_mouse_input` / `character_navigation` need the exact instance path: get it from a probe, never guess.
- The Luau gate hook auto-runs the formatter on format-only failures and reports only failing lines.
- After reinstalling the skills, re-apply local fixes:
  `python "D:\Roblox Studio Games\_RobloxAI\bootstrap\patch_skills.py"`.
- After improving a skill (a correction written back into it), version it in the toolkit repo:
  `python "D:\Roblox Studio Games\_RobloxAI\bootstrap\sync_skills.py" export`, then commit there.
