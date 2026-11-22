# 10 - Slim map: smaller lobby boundary, 3 tracks, rebuilt zone sides

Owner's brief (2026-11-22): the map feels too big and may not render fully for many players. Make it smaller:

1. Remove the outer part of the lobby (the town wall and everything between it and the lobby wall). The lobby wall is
   the end; it must join the lane's walls smoothly.
2. Remove 2 of the 5 tracks: 3 tracks, same lane LENGTH, the sides "stuck" back onto the narrower lane.
3. Then, zone by zone: replace the clay-looking terrain sides with a structured, textured, lower profile. The border
   wall stands right on each zone's edge, a little taller than the zone's sides. Keep the props and buildings, laid out
   properly, with few trees. Every size must be a parameter, so the corridor can be widened or lowered later.

Work in that order. Each phase ends with a check, a saved place version and your go-ahead before the next.

---

## 1. What the map is today (measured 2026-11-22)

| Thing | Now |
|---|---|
| Lane | 320 wide (x -160..160), floor y -48, z 160..6280 (17 zones x 360) |
| Tracks | 5, one per base: `World.laneX(plot) = (plot - 3) * 56` gives x -112, -56, 0, 56, 112 |
| Floor kit, per zone | 5 strips 38 wide, 10 kerbs, 10 paving bands, 2 margin pavings (x 140..160), distance bands and signs, a threshold 320 wide |
| Zone sides | terraces x 160..236 at y -46, then a TERRAIN canyon (rise, ledge, rise, top at y 58..76 near x 280..300), sloping down to the outer edge at x 368 |
| Lane border | wall at x +-366..380, top y 52, keeps at every gate; sea outside to x 548 |
| Lobby | plaza and 5 bases inside the lobby wall (x +-358, z -170); the LobbyTown precinct and the town wall (x +-466, z -326) outside it; sea beyond |
| Parts | 15,300 in `Workspace.Map` (Scenery 7,200, Lanes 4,500, Plots 1,900, Hub 1,100). LobbyTown alone is 1,524 |
| Streaming | on, target radius 576, min 256, `PauseOutsideLoadedArea` |

**What actually costs the most to render is the terrain, not the part count.** Each zone writes its canyon as smooth
terrain x 160..368, about 120 tall and 360 long, on both sides: around 17 x 2 x 208 x 130 x 360 studs of voxels. The
sea is a single flat slab and is cheap. Within the 576 streaming radius a player loads about 1.5 zones of canyon. The
lane's floor and the parts are light.

## 2. Code that depends on the tracks (the one risky part)

- `src/shared/Core/World.luau`: `laneX(plot)`, `throwSpot(plot)` (the stage spot = the track's x), `landingX(plot, jitter)`.
- Used by `ThrowService` (server: where the player is held, where the food lands), `ThrowController` and
  `ThrowSequence` (client: camera, arc, landing side). The landing roll does not depend on x, only on distance (z),
  so 3 tracks change NO odds or economy.
- Config `World`: `LaneWidth 320`, `LanePitch 56`, `LandingJitterX 18` (in `design/game.json`, regenerated into
  `GameConfig.luau`). `tests/World.spec.luau` checks these functions.
- The throw stage (`HubV2.ThrowStage`, 312 wide) has five coloured spots at x -112..112, one per base.

5 players and 3 tracks means **two bases share each outer track**. Proposed (decision A below):

| Base | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| Track | left (x -56) | left | centre (x 0) | right (x 56) | right |
| Lands on | left half (x -65) | right half (x -47) | centre | left half (x 47) | right half (x 65) |
| Stage spot | x -66 | x -46 | x 0 | x 46 | x 66 |

The food stays on the strips, every player still has a spot of their own on the stage, and the jitter drops from 18
to 6 so food stays in its half. `World` gets `TrackPitch`, `PlotTrack` and `PlotTrackSide` as config (so 4 or 5 tracks
later is a config edit), and `World.spec` gets the new cases. Nothing else in the code changes.

## 3. Phase 1 - the lobby: tighter bases, the lobby wall as the map's edge

Goal: the lobby wall is the map's edge, sea outside, the lobby itself compact. Owner's additions (2026-11-22): too much
lawn between the outer bases and the side walls; bases a perfect square with an even, smaller border; no bushes along
the bases' sides; bases a little closer together; one training station per side instead of two.

**Status: done 2026-11-22**, place version 659 (version 657 is the rollback point from before it). Checked: aerial and
eye-level views, a play boot with no errors, the spawn on base 1's walk, both stations snap and lock the trainee at their
new spots, the meditate station locked until the Sandbag, the gear models on their stands.

### 3a. The bases (config + place, `tools/studio/base_layout.luau`, rerunnable)

| | Now | New |
|---|---|---|
| Deck | 84 x 72, border 15.5 at the sides, 9.5 behind, 17.5 in front (the spawn stood on it) | 65 x 65, a 6-stud border on all four sides (z -44..21) |
| Pedestal grid | 7 x 6, 8 apart both ways (53 x 45 with the bodies) | 7 x 6, 8 apart across, 9.6 apart front to back (53 x 53: square). Same 42 slots |
| Spawn | on the deck, z 20 | on the walk just in front of the deck, z 26 |
| Slot sign | z 36.5, on the gravel | z 26, beside the spawn |
| Pitch | 108 (bases 24 apart) | 92 (bases 27 apart, a garden path between), centres 0, +-92, +-184 |
| Bushes | 16 along each base's sides | removed (archived) |
| Training | 2 courts 30 wide, 2 stations each | 2 courts 18 wide (x 14.5..32.5 from the base's centre), 1 station each: Strike Dummy (left) and Waterfall Focus (right) |

Training: the strike station keeps the dojo gear (tiers 1-3); the meditate station keeps the spirit gear (waterfall and
up), and opens at gear 2 instead of 5, so the right court is used from early on. Power per rep comes from the gear
tier, not the station, so no number in the economy changes. Curls and Stone Push go (their props are archived); the
Stone Pillar (gear 4) is still bought and shown in the upgrade card, it just has no station of its own. The two
courts are where the new mini-games can go.

Code: `World.pedestalOffset` reads `PedestalSpacingZ` (falls back to `PedestalSpacing`); config `World` gets the
numbers above; `Training.Stations` keeps two rows; `World.spec` checks the even border instead of the old entrance court.

### 3b. The lobby wall (`tools/studio/lobby_wall.luau`, rerunnable; the town builder is retired)

- Side walls come in from x +-358 to +-262 (inner face +-246): 29.5 studs of lawn beside the outer bases (now 86).
  The lobby goes from 716 to 524 wide.
- The back districts move in with them: Hall of Legends and Ramen Alley from x +-282 to +-192, Rewards and
  Rankings from +-110 to +-96 (6 studs between neighbouring decks). Their prompts and the leaderboards move with them.
- The lobby wall in zone 1's great-wall dress (the same as the lane's border walls), top y 44, its foot down into the
  sea. Keeps at the corners, the front, halfway along the sides and on the back.
- The side walls run straight on past the front keeps into zone 1's gate towers: one line from the back corner to the
  lane, no angled funnel walls. Outside it, the sea.
- Removed and archived (`MapArchive.LobbyTown_v1`): the walled town and the town wall (2,224 parts), the side lawns'
  pagodas, trees, lanterns and bushes, the old lobby and entrance walls.

Check: an aerial view all round, the views from the plaza and a base, a play boot (spawn, training at both stations,
prompts, a throw), then a saved version.

## 4. Phase 2 - 3 tracks, sides stuck back on

**Status: done 2026-11-22**, place version 661. `tools/studio/lane_slim.luau` (the shift, once: attribute `LaneSlim`),
then zone_gates, lane_border, finale and lobby_wall rerun with the narrower numbers. Checked: aerial and eye-level
views from the stage, zones 3 and 4, the finale; a play boot with no errors; base 1's pad puts the player at x -66 and
a throw landed at x -68 (its half of the left track). Bases 2-5 are covered by the World spec only (one test player).
Note: the lane border (x 306..320) is now wider than the lobby (x 262); phase 3 brings it in to the zones' edge.
The zone builders refuse to run until phase 3 rewrites them.

Goal: the lane is 200 wide (x -100..100), same length, and nothing between the lane and its sides is left open.

1. Config and code (section 2): new mapping, jitter 6, `LaneWidth 200`. Gates (`check.py`), `World.spec` updated.
2. Floor kits, all 17 zones: keep the 3 middle strips (x -56, 0, 56) with their kerbs and paving. Remove the strips at
   x +-112 with their kerbs, paving and distance bands and signs. Margin paving at x 84..100, kerbstone at 100..104,
   thresholds 200 wide.
3. "Stick" every side inward by 60: every zone's scenery models outside the lane, its terrain (voxels copied 60 studs
   in, 15 voxels, then the old strip cleared), the gates' torii (pillars x 175 to 115), the lane border wall (x 366 to
   306), the finale, zone 1's entrance towers and ledge, the lobby's throw stage (312 to 200 wide, spots at the new x),
   ledge wall and parapets, the barriers (x 362 to 302). One rerunnable script, `tools/studio/lane_slim.luau`, with the
   shift as a parameter. It moves things and never rebuilds them, so every prop and building keeps its place on its
   terrace.
4. The zone builders still describe the 5-track lane after this. Phase 3 rewrites each zone on the new
   cross-section, so they become current one zone at a time (noted in CLAUDE.md as each one lands).

Check: a throw from every base (all 5 spots) in play, landings on the right halves, the camera through the gates, an
aerial view, the lane from the stage, `audit` for things left in the lane. Then a saved version.

## 5. Phase 3 - the zones, one at a time

**Zone 1: done 2026-11-22**, place version 664. Built by `tools/studio/zones/zone_01_naruto.luau` v2 on
`tools/studio/zones/side_lib.luau` (`run_zone.py build 1`), then `lane_border.luau` (stands the wall on slim zones'
edges, steps out where a slim zone meets an old one) and `lobby_wall.luau` (ledge parapets to the new gate towers, the
lawn corner beside them). The real numbers are side_lib's `P` table (they differ a little from the sketch below:
terrace to 172, revetment 168..178 with a batter, shelf 178..206, wall 206..220 top 26).

**Zone 2: done 2026-11-22**, place version 665 (`run_zone.py build 2`, then lane_border.luau).

**Zone 3: done 2026-11-22**, place version 666: a harbour zone (the terrace band is water).

**Zone 4: done 2026-11-22**, place version 667.

**Zone 5: done 2026-11-22**, place version 669.

**Zone 6: done 2026-11-22**, place version 670. Zones 1-6 are the game's six playable zones (config.Zones).

**Zone 7: done 2026-11-22**, place version 672.

**Zone 8: done 2026-11-22**, place version 674.

**Zone 9: done 2026-11-22**, place version 675.

**Zone 10: done 2026-11-22**, place version 676.

**Zone 11: done 2026-11-22**, place version 677.

**Zone 12: done 2026-11-22**, place version 678.

**Zone 13: done 2026-11-22**, place version 679.

**Zone 14: done 2026-11-22**, place version 680.

**Zone 15: done 2026-11-22**, place version 681.

**Zone 16: done 2026-11-22**, place version 682.

**Zone 17: done 2026-11-22**, place version 683: a harbour zone like zone 3, islands in the water. Its sides run on
past the lane's end to the end wall (z 6372), so the harbours open into the finale's bay; `markSlim(root, 5920, 6394)`
keeps the slim wall line to the end wall (lane_border.luau builds no cross wall at or behind END_Z0 and, with a slim
zone 17, lays the bay only the lane's width). finale.luau's corner towers moved in to x +-213 (`CORNER_X`), its end
wall now runs 104..193 with two banners a side.

**Phase 3 is complete: all 17 zones are on side_lib, the border wall stands at x +-206..220 from zone 1 to the end wall.**

Found while doing it: Phase 2's resize step read a cached old config (Studio caches `require`), so the stage, spots,
margins and barriers were fixed afterwards (lane_slim rerun with a fresh require), and the terrain copy of zones 2-17 took
the wrong band (their ground at x 100..160 is missing in places). Every zone's rebuild clears and rewrites its own
ground, so this goes away zone by zone.

### The cross-section as first sketched (the built numbers: side_lib's `P`)

```
 x:  0 .. 75     84    100 104                170 176           200 206        220
     | 3 tracks | pave | margin |kerb| terrace (street + buildings) |wall| shelf (landmarks) |wall| BORDER |  sea
 y:  -48 lane floor              -46 terrace          up to  -14         -14            up to +16    wall top +26
```

- **Terrace** x 104..170 at y -46: the street and the frontage of buildings, as the rework made them, laid in rows.
- **Revetment** x 170..176: a BUILT stone retaining wall in the zone's material (castle stone, brick, concrete,
  rock), 32 tall, with a cap and buttresses: no terrain face.
- **Shelf** x 176..200 at y -14: the zone's landmarks (the rim's set pieces), a few trees, lamps, fences.
- **Border wall** x 206..220, top y +26 (12 to 40 above the shelf): the lane border, on the zone's edge, in the town
  wall's dress, with its foot in the sea and the keeps at the gates.
- Corridor 440 wide (now 760: 42% narrower). The sides top out at y +26 (now about 76 for the canyon, 100+ for keeps).
- Terrain only where it is ground (grass, sand, water on the sea zones 3 and 17), flat, in one material per zone. Faces
  are parts with real materials (Slate, Brick, Cobblestone, Concrete, Rock) and colour, so nothing looks like clay.
- Trees: a few per zone on the shelf, never a row of them.

### The loop, per zone (zone 1 first, then 2, 3 ... 17)

1. Look at the zone and list its buildings and props (they are kept).
2. Rewrite its builder on the new profile in `zone_lib` (shared helpers `revetment{}`, `shelf{}`, `borderWall{}`).
3. Lay the terrace rows and the shelf's landmarks; `audit` at 0 overlaps / 0 ground faults / 0 in the lane.
4. Look from the stage, along the lane, each side and above. Fix, look again.
5. A play boot, `REWORK_PROGRESS.md` updated, your go-ahead, then the next zone.

Zones 1 and 2 were your approved bar: their buildings and set pieces (the Hokage rock heads, the train, the mansion)
are kept and re-laid. Only their terrain sides change.

## 6. Rollback

Before each phase: `save_place` (a version) plus archives in `ServerStorage.MapArchive.*` (never deleted). Any phase
can be undone from Version History.

## 7. Decisions for you

- **A. Five players on three tracks**: the plan above (two bases share each outer track, each on its own half, five
  distinct stage spots), or every player throws down the centre track from five spots.
- **B. Lobby wall height**: top about y 44 (proposed), or keep it at 35.
- **C. Zone side height**: shelf at y -14 and wall top at y +26 (proposed: sides about 60% of today's height), or higher
  (for example shelf y 0, wall top y +36).
