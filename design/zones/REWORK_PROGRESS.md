# Zone rework: progress (read this first after any context loss)

Owner's order, 2026-11-22 (asleep, will not prompt again): the 17 zones built overnight "look so shit", "too vague
without any details", "poorly made", "some buildings are not even placed properly". Rework them **one by one, starting
from zone 3**, quality over quantity, no overlaps, everything placed properly with the map, check every screenshot for
overlaps and ugliness, do not stop, never batch zones. Zones 1 and 2 are the bar and are not to be touched.

## The standard every zone must meet before moving on

1. Both terraces (x 160..236 either side, 360 long) read as a built place: a near-continuous frontage of varied
   buildings, a paved street / plaza / path on the ground (never bare terrain), kerbs or edging.
2. At least 8 unique theme models (generate_mesh), plus small props: lamps, fences, signs, crates, benches, carts,
   bushes, rocks, banners. One or two big set pieces sized to be seen from the throw stage.
3. Walls dressed: something built or planted on the face, the ledge and the rim. No bare sheet of terrain.
4. `python tools/studio/zones/run_zone.py audit <map id>`: 0 overlaps, 0 embedded, 0 floating (or each one explained).
5. Looked at from: down the lane, each side from the lane, each terrace at street level, from above. Fix what looks
   wrong, look again.
6. `check` clean, 0 scripts, play boot "problems 0".
7. This file updated, then the next zone.

Do not commit, push, save a place version or publish: the owner has not approved.
Screenshots: run `tools/studio/front.ps1` first (wakes the display), then `screen_capture` with camera/look-at.

## Status

| Zone | Map id | State |
|---|---|---|
| 1 Hidden Leaf | sakura_schoolyard | owner-approved, do not touch |
| 2 Demon Slayer | pirate_harbor | owner-approved, do not touch |
| 3 Grand Line | ninja_village | DONE 2026-11-22: rebuilt on zone_lib (19 unique models, piers, stilt town, boardwalk, waterfalls); audit 0/0/0; play boot clean |
| 4 Hero Academy | samurai_castle | DONE 2026-11-22: rebuilt (18 unique models: campus with wall, gate, track, court, statue plaza; street with road, car park, bus, cars, exam robot; rim skyline); audit 0/0/0; play boot clean |
| 5 Blue Lock | hero_city | DONE 2026-11-22: rebuilt as a stadium (16 unique models: roofed stands, touchline with LED boards, dugouts, goals; trophy and striker plinths; fortress, hall, floodlights, jumbotrons on the rims); audit 0/0/0; play boot clean |
| 6 Clover Kingdom | realm_of_legends | DONE 2026-11-22: rebuilt (14 unique models: capital with castle, town houses, grimoire tower, fountain, market, wizard king plaza and waterfall; village with church, farm, guild base, giant skull; floating grimoires, banners); audit 0/0/0; play boot clean |
| 7 Hunter Exam | hunter_exam | DONE 2026-11-22: rebuilt (14 unique models: steakhouse, exam hall, trick tower, camp, testing gate, arena tower on the rim, airship; tree houses, world tree, pond + waterfall, ant nest, fisher statue; forest floor of mushrooms, logs, rocks); audit 0/0/0; play boot clean |
| 8 Isekai Crossroads | isekai_crossroads | DONE 2026-11-22: rebuilt (14 unique models: guild hall, item shop, forge, pig tavern, altar, portal; giant slime + little ones, demon castle, dragon on gold, hero's sword; crystals, mimics, floating islands); audit 0/0/0; play boot clean |
| 9 Wall Maria | wall_maria | DONE 2026-11-22: rebuilt (12 unique models: town houses, bakery, well, wagons, great gate, soldier monument; bell tower, garrison HQ, stables, training ground; dark buttressed walls with parapet, cannons, banners; the giant looking over a wall tower); audit 0/0/0; play boot clean |
| 10 Public Safety | public_safety | DONE 2026-11-22: rebuilt (12 unique models + zone 4's vehicles: government block, cinema, diner, screen tower, giant chainsaw; noodle shop, old apartments, old HQ, corner store, puppy statue; roads, black cars, utility poles with wires, vending machines, signboards, rim skyline, red tower); audit 0/0/0; play boot clean |
| 11 Bizarre Streets | bizarre_streets | DONE 2026-11-22: rebuilt (12 unique models: palazzo, baroque church + fountain piazza, cafe, golden arrow; pizzeria, townhouses, clock tower, road roller, stone mask; scooters, ladybug columns, katakana over the ledges, rim palazzi); audit 0/0/0; play boot clean |
| 12 Shadow Council | shadow_council | DONE 2026-11-22: rebuilt (12 unique models: cathedral with red carpet, library, mansion, council table, throne on steps; a full back rank of giant chess pieces with gargoyle pawns; chessboard terraces, braziers, small pieces on the ledges); audit 0/0/0; play boot clean |
| 13 City Z | city_z | DONE 2026-11-22: rebuilt (13 unique models: supermarket, hero HQ, cheap apartments, bald hero statue; ruined towers, collapsed block, meteor in its crater, crab monster, punched wall, flipped car, rubble, cyborg statue; cracked roads, bent poles, barriers, broken rim skyline); audit 0/0/0; play boot clean |
| 14 Soul Society | soul_society | DONE 2026-11-22: rebuilt (12 unique models: gatehouse, captains' hall, tiered tower, dojos with raked courts and sword racks, giant sword; sweet shop, hill tower, hollow mask; lanterns, pines, black butterflies, tiled white walls on grey rock); audit 0/0/0; play boot clean |
| 15 Gate of Shadows | gate_of_shadows | DONE 2026-11-22: rebuilt (13 unique models: hunters' guild + checkpoint, the gate, ruined temple, stone king; shadow knights, dragon bones, second gate, ant soldier, dark dagger; crystal spires, obelisks, columns, glowing rune floor); audit 0/0/0; play boot clean |
| 16 Shibuya | shibuya | DONE 2026-11-22: rebuilt (12 unique models: fashion tower, ad-screen tower, station + train, cinema, subway entrance, dog statue, panda statue; sorcerer school + torii, cursed shrine, sealed box, clawed hand; zebra crossings, signals, neon screens, rim skyline); audit 0/0/0; play boot clean |
| 17 Planet of the Gods | planet_of_gods | DONE 2026-11-22: rebuilt (13 unique models on islands in real water: pink island house, tournament arena + bridge, lookout, star balls; dome corporation + capsule cars, dragon, space pod, fighter statue; dome houses on the beaches, mesas and the god's temple on the rims, golden clouds, two waterfalls); audit 0/0/0; play boot clean |

## Notes that carry between zones

- Per-zone loop that worked for zone 3: look (6 shots) + `audit` -> list faults -> design a full layout on paper with
  real sizes (`sizeOf`, TrueSize) -> generate 12-14 models in batches of 5 (`generate_mesh` async, `store ... --view`,
  look at the lineup at (3000.., 600, -9000) from z -9100) -> write the zone file -> build -> audit -> look -> fix -> repeat.
- zone_lib helpers added for the rework (use them, do not hand-place): `place` (make + claim, reports a fault on a
  crossing), `try` (place only if free), `row{}` (buildings one after another, backs to the wall's foot), `scatter{}`,
  `plant` (skips taken ground), `pave`, `fence`, `deck` (piers/boardwalks on posts), `steps`, `footing` (level base for
  anything on sloping ground: rims, beaches), `waterfall`, `afloat`, `reserve`, `wallFoot`/`footOver`, spec `wobble`
  (0.35 keeps the wall's foot near straight), spec `seaEnd`. finish() prints placement faults.
- THE GATE PILLARS STAND IN THE TERRACES: x 171..236, z gate pivot +-35, and the gate's pivot is 45 studs into its zone
  (zone 3: z 925). Usable terrace per side is z Z0+82 .. Z1+12. begin{} claims them; the audit knows them.
- Two terrain materials banded on a cliff face come out as blotches; thin strata come out as blocky glyphs. One rock
  material per wall. Studio `generate_material` gave noisy small-tile textures: rejected, variants deleted.
- A straight waterfall sheet from rim to ledge runs inside the cliff (the face bulges): `waterfall` follows the ground.
- stylua wraps the zone files at 120 columns: patch them with the Edit tool or by anchors, not by whole-line strings.
- Bash heredocs break on apostrophes inside Python/Luau: write patch scripts with the Write tool.
- Zone 4 must take zone 3's new `now` as its `prev`: face 240, rise 8, ledgeW 26, ledgeY LY+6 (-42), top {-1: 62, 1: 58},
  prevRock Sandstone, prevTerrace Sand.
- THE TERRACE'S REAL GROUND IS LY + 2 (-46), not LY: level smooth terrain shows 2 studs above what was written. zone_lib
  has `TERRACE` and `ground()` now raycasts the real terrain; `run_zone.py build N` (with terrain) runs two passes so the
  second places things on the terrain as written. Lay paving with `pave` (top TERRACE + 0.35), marks with `paint`; stand
  props on `TERRACE + 0.35`. Paving at LY + 0.35 was invisible (zone 4, first build).
- Every zone built before the rework placed things at LY (2 studs sunk) and used the old helpers: each must be rewritten
  on the new helpers, not patched. Zone 5 `prev` = zone 4's `now` (face 236, rise 6, ledgeW 26, ledgeY 8, top 62; rock
  Concrete, terrace Pavement).
- Reusable city dressing lives in StoreAssets.Zone04_MHA: Car, Taxi, Bus, BusStop, PlanterTree, HeroBillboard, Konbini,
  ScreenBuilding, Skyscraper, Apartment (zones 10, 13, 16 are cities too: reuse the vehicles and street furniture, give
  each its own landmark buildings).
- A generated building can carry a dark blob under its doorway: sink it (`row{ y = TERRACE - 3.5 }`, attribute SunkOk)
  and put built steps across its front.
- `check` only knows terrain: use `audit` for ground and overlaps, `check` for the script count.
- Zone 6 `prev` = zone 5's `now`: face 236, rise 6, ledgeW 20, ledgeY 16, top 62; prevRock Concrete, prevTerrace Pavement.
- Terrain Asphalt tinted navy renders olive-brown and mottled: do not use it for walls. Concrete (zone 4's blue-grey) is clean.
- `sign(parent, text, w, h, cf, bg, fg)` + Neon material makes LED boards and name boards; `words` scales text to the board.
- A model that fails as a mesh twice gets built from parts instead (`grandstand{}` exists in zone_lib as that fallback).
- Big landmark too deep for the terrace: put it on the rim with `footing` (zone 5's fortress, zone 3's fortress and mill).
- SCREENSHOTS: `screen_capture` with a camera position is taken AT ONCE, while the terrain is still in its coarse
  far-away form: flat ground shows as raised blocks 2-4 studs high that swallow paving and plinths (cost an hour on zone 6).
  Use `python tools/studio/zones/run_zone.py look x y z tx ty tz` (parks the camera, wakes the display, waits 6 s), then
  `screen_capture` with NO camera position. Wide shots of buildings are fine either way; anything about the GROUND needs `look`.
- `pave` now cuts the terrain away under its slab (the slab is the ground, 7 thick). After changing a zone's paving layout
  rebuild WITH terrain (no `--no-terrain`), or the old cuts stay as holes. Two slabs must share an edge exactly (no slot).
- `floor{}` lays a kerbstone (`LaneEdge`, x 160..164) down both sides of every non-sea zone: without it the void showed
  as a sky-blue stripe between the lane's paving and the terrace.
- Zone 7 `prev` = zone 6's `now`: face 236, rise 6, ledgeW 26, ledgeY 8, top 64; prevRock Rock, prevTerrace LeafyGrass.
- Emoji work in `words` (zone 6's clover banners).
- Zone 8 `prev` = zone 7's `now`: face 236, rise 6, ledgeW 28, ledgeY 12, top {-1: 70, 1: 66}; prevRock Mud, prevTerrace LeafyGrass.
- Generated meshes often have an unfinished flat BACK (zone 7's gate: a plain blue panel): back them against a wall, a
  cliff or a gate pillar. Meshes asked for "on a patch of moss/grass" come with a SQUARE base: sink it (y = TERRACE - 2).
- Reusable forest dressing in StoreAssets.Zone07_Hunter: Mushrooms, FallenLog, Camp, Signpost, TreeHouse.
- Zone 9 `prev` = zone 8's `now`: face 236, rise 6, ledgeW 26, ledgeY 10, top 64; prevRock Glacier, prevTerrace LeafyGrass.
- Zone 8 built with 0 faults first time using the pattern: `row{}` per side (each building its own `row` call so its z0 is
  known for the props in front of it), an end plaza with a set piece facing the stage (yaw 0) on a `cylinder` plinth +
  `reserve`, `scatter{}` for small dressing, landmarks on the rim with `footing`, sky dressing with attribute AuditSkip.
- Zone 10 `prev` = zone 9's `now`: face 234, rise 4, ledgeW 34, ledgeY 62, top 62; prevRock Brick, prevTerrace Ground.
- `row{ backGap = 6 }` keeps buildings clear of built wall dressing (zone 9's buttresses). Built masonry on a terrain wall
  must stand 2-3 studs PROUD of the face and be clearly DARKER than the terrain, or it vanishes at a distance.
- A mesh generated "looking over a wall" carries its own wall piece: enclose it in built masonry (zone 9's wall tower).
- The mesh generator's moderation refused "giant ... target on its neck"; keep prompts tame.
- Never put a `-- comment` inside a one-line table before stylua has wrapped it (it swallows the rest of the line).
- Zone 11 `prev` = zone 10's `now`: face 236, rise 6, ledgeW 26, ledgeY 8, top 62; prevRock Basalt, prevTerrace Pavement.
- SIZE CHECK BEFORE WRITING A ROW: `store` prints each model's real size, which is often smaller than asked for. A row must
  add up to about 215 studs (S0+2 .. Z0+300), leaving a 60-70 stud end plaza: sum (stored X * scale) + gaps. A building's
  depth (stored Z * scale) must stay under 50 where there is a road (front no nearer than x 182).
- City helpers written in zone 10's file (copy for zones 13, 16): `streetGround(side)`, `poles(side, zs)` with wires,
  `plinth(x, z, radius)`, part-built signboards with `sign`.
- Moderation also refused "chainsaw blade sticking out of its forehead": describe mascots tamely.
- Zone 12 `prev` = zone 11's `now`: face 236, rise 6, ledgeW 26, ledgeY 10, top 62; prevRock Sandstone, prevTerrace Cobblestone.
- Zone 11 worked first time by waiting for `store` (real sizes) BEFORE writing the rows. Do that every time.
- Zone 13 `prev` = zone 12's `now`: face 236, rise 6, ledgeW 24, ledgeY 14, top 70; prevRock Basalt, prevTerrace Asphalt.
- A patterned terrace floor = one `pave` (base colour) + `paint` squares on it (zone 12's chessboard).
- Zone 14 `prev` = zone 13's `now`: face 236, rise 6, ledgeW 26, ledgeY 8, top 62; prevRock Concrete, prevTerrace Pavement.
- `scatter{}` for loose dressing goes LAST in a side's block (after every plinth is reserved), with `ax` from 176 so
  nothing reaches the lane. After each zone, check `workspace` for stray generated models (names over 40 chars) and
  either store or delete them: a late async generation lands at the camera.
- Zone 15 `prev` = zone 14's `now`: face 236, rise 6, ledgeW 28, ledgeY 10, top 60; prevRock Rock (zone 14 no longer
  recolours Snow), prevTerrace Limestone.
- Zone 16 `prev` = zone 15's `now`: face 236, rise 6, ledgeW 24, ledgeY 14, top 68; prevRock Ice (purple), prevTerrace Basalt.
- Neon `paint` lines (`.Material = Enum.Material.Neon`) make glowing floor markings (zone 15's runes, zone 5's plaza).
- Zone 17 `prev` = zone 16's `now`: face 236, rise 6, ledgeW 26, ledgeY 8, top 62; prevRock Concrete, prevTerrace Pavement.
- Props in front of a building: check the building's FRONT x first (236 - 1.5 - depth); anything deeper than 50 leaves
  no sidewalk. Scale the building down rather than squeezing props against it.
- ALL OF ZONES 3 TO 17 ARE REWORKED (2026-11-22). What is left is the final whole-lane pass and the owner's review.
- Sea zones (3, 17): `island(x, z, radius)` (two cylinders) is in zone 17's file; things in open water get `afloat()`.
  Rocks on the rim's outer slope are sunk 20 studs with SunkOk 48.
- Play boot check: `start_stop_play` true, wait 16 s, `python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py
  luau --dm Server --file tools/studio/zones/boot_check.luau` -> "players 1, character true, problems 0", then stop.
