# FestivalLane map (v3: wide bases, styled lanes, the anime town): build, regenerate, extend

`tools/map/` is the source of truth. `work/map/` holds generated output only (spec report, plan,
terrain, chunks). `design/map.json` is GENERATED: never hand-edit it.

| File | Owns |
|---|---|
| `gen_map.py` | plots, hub, walls, terrain, pools (`pool()`, `legacy()`), budget fill, spec + chunk routing |
| `gen_lane_style.py` | lane floor (zone band, two-tone patterned strip tiles, kerbs, paving, distance marks) and wall faces (plinth, pilasters, hung elements, parapet) |
| `gen_town.py` | the town: terrace facade rows + centre-line landmarks, outer hill tiers, hub backdrop, harbour |
| `zones.json` | per zone: colours, floor/wall textures, `hung`, `town` mix; `generated_kinds`, `kind_fallback` |
| `design/store_assets.json` | Creator Store tags (kind, zones): the ONLY source of store models |
| `make_textures.py` | the 9 tile PNGs in `assets/map/textures/` (+ README with StudsPerTile) |
| `emit_chunks.py` | Luau chunks + the emitted-height audit |

## Build in Studio (EDIT mode, not Play)

`python tools/map/build_in_studio.py` runs every file in `work/map/chunks` in name order and waits
for each (it reads the `Chunk_<file stem>` attribute every chunk writes). By hand:
`python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file work/map/chunks/<file>`.

| Order | Files | What |
|---|---|---|
| 1 | `00_setup.lua` | DESTROYS any old `Workspace.Map`, makes `Map/{Plots,Hub,Lanes,Scenery,Barriers}` |
| 2 | `01_terrain_*` | `Terrain:Clear()` then the voxel rows (first file clears) |
| 3 | `02_plots_*` | plots: deck, Spawn, ThrowPad, DojoPad, Gear, SlotSign, NameBoard, 28 Pedestals, YardCourt + `Yard` anchor (`Reserved = "minigames"`), fences |
| 4 | `04_hub*` | hub stations, boards, HubSpawn, hub walls and their facade |
| 5 | `05_lanes_plots*` | walkways, lane mouths, garden strips between bases |
| 6 | `06_barriers` | 4 invisible walls |
| 7 | `07_hub_backdrop*` | the hillside town behind the hub (castle, pagodas, street, waterfalls) |
| 8 | `10_zoneNN_<id>*` | per zone: floor, kerbs, paving, marks, gates, walls, wall-foot clusters |
| 9 | `11_facadeNN_<id>*` | per zone: plinths, pilasters, hung elements, parapets |
| 10 | `12_townNN_<id>*` | per zone: terrace buildings, trees, landmarks |
| 11 | `90_scenery_hills_finale*` | outer hill tiers, end hill, finale |
| 12 | `99_lighting.lua` | lighting preset |

A chunk too large for one file is split `<cid>_1ofN ... _NofN`: ONLY `_1ofN` wipes the containers, so
re-run the whole set, in order (`--only 11_facade03`). A missing `ReplicatedStorage.Assets.Kit.<Name>`
becomes a translucent grey box named `<Name>` (counted in the chunk summary).

Textures: a part asks for a tile by name; the Texture is only emitted when `assets/map/ids_textures.json`
has an id for it (`{"setts": 123...}`). After writing that file, re-run `emit_chunks.py` and every chunk
that has floors or walls (02, 04, 05, 10, 11). `emit_report.json` lists every tile, how many parts
ask for it and whether it has an id.

## Regenerate (after any change to game.json, kit.json, zones.json, store_assets.json or a manifest)

```
python tools/map/gen_map.py                                                   # design/map.json (~2 min)
python ~/.claude/skills/roblox-map/scripts/build_map.py design/map.json --out work/map   # prove, plan, terrain
python tools/map/emit_chunks.py                                               # chunks + emitted-height audit
python ~/.claude/skills/roblox-map/scripts/lighting.py stylised_day --theme tools/map/theme_festival.json -o work/map/chunks/99_lighting.lua
```
`python tools/map/tcheck.py` runs only the terrain checks (~45 s). `report.json` must say PASS. The
generator prints the town counts, every pool fallback (zone/kind -> source:kind) and the generated
models still placed; the same is in the spec under `layout.town` / `layout.pools`.

## How to add a store building

One line in `design/store_assets.json` (`kind`, `zones`) plus its row in
`assets/meshes/manifest-store.json` (measured size, parts, tris). Regenerate: every pool of that kind
in those zones now draws it, and any generated model of the same kind in those zones stops being placed.
Part-built models (> 20 parts) are placed at most twice.

## How to add a zone / a plot

Zone: `config.Zones` row + `zones.json` entry (colours, `floor_texture`, `wall_texture`, `pave`, `hung`,
`town`, foot/set lists). Plot: `config.Server.PlotCount` + 1; everything derives from config.World. After
either, re-run EVERYTHING from `00_setup.lua`.

## After building

The emitter's audit (`work/map/emit_report.json`) checks the emitted heights: no visible top within
0.25 of y=0, strip tiles all at 0.3, walls and props clear of every landing strip, pedestals inside the
fence at PedestalTop.
