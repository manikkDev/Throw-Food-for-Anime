# 09 - Single-lane rework (PLAN v2, 2026-11-21, nothing built yet)

Status: proposal for the owner. No code, map or config has changed.
v1 (a crescent of bases around a plaza with one shared launch stage) was REJECTED by the owner:
too far to walk, and it threw away a layout that already works. v2 keeps today's structure.

## 1. Owner's brief for v2

- Keep the shape of today's hub: shops and leaderboards BEHIND the bases, bases in a row, the throw in FRONT.
- ONE throwing lane. 5 players per server (was 6).
- Training close to each player's own base; the base itself holds only heroes.
- Players hate travelling: nothing in the throw loop may need a trip.
- Zones are built 3 at a time, with time spent on each. No slop.
- Free assets from the Creator Store or anywhere online are fine.

## 2. Why one lane (unchanged from v1)

| Measure | Today (6 lanes x 6 zones) | Budget | Same design at 17 zones |
|---|---|---|---|
| Parts in the map | 13,699 | 14,000 | about 36,000 |
| Parts within 576 studs of a throw stage | 6,911 | 7,000 | already at the limit |
| Triangles in view | 1.28 M | 1.2 M (over) | over |

## 3. What is wrong with today's hub (measured in `design/map.json`)

- The ONLY food cart and sell booth are at the centre (x = -30 and +30). From an outer base (x = 270) that is
  about 270 studs each way, for the two things a player uses most.
- The three leaderboards are bunched on one side (x = -34 to -74), chest and gift on the other (58 to 78),
  the index board at 36: no symmetry, no reading order.
- The hub is 680 studs wide because six bases sit on a 108 pitch; most of its back wall is filler props.

## 4. The hub, v2

Axis: lane runs +Z. z = 0 is the front edge of the bases. All numbers are studs (starting values for the greybox).

| Strip (front to back) | z | What |
|---|---|---|
| Lane | from 96 | 5 tracks, 40 apart: strip 200 wide. Each player throws straight down their own track |
| Lane lip | 64 | the Rift Gate spans the mouth: every throw passes under it |
| Throw deck | 28 to 60 | per player: throw pad (z 46) with a food cart on its left and a sell booth on its right |
| Training yard | 2 to 26 | per player: two courts 26 x 22 either side of an 8-wide path; the same 4 mini-games |
| Bases | -72 to 0 | 5 bases, 56 wide x 72 deep, on a 64 pitch (x = 0, 64, 128 either side). Heroes only: 6 x 7 = 42 places |
| Festival street | -150 to -80 | shared: summon shrine on the centre line, a leaderboard either side of it, Rewards (daily chest, gift box, codes) at the west end, Index and Store at the east end |
| Backdrop town | behind -150 | scenery only |

- Pads sit at x = 0, 40 and 80 either side, bases at 0, 64 and 128: the forecourt narrows toward the lane.
  Front gate to throw pad: 46 studs (centre base), 51, 67 (outer bases). Today: 42.
- Everything in the loop is on the player's own lot: spawn at the front gate, train, buy food, throw, sell,
  place the hero. The street behind is for the occasional and social things only.
- Every base has a back gate onto the street. Back gate to shrine: 10 to 130 studs.
- Hub footprint about 340 wide x 215 deep (today about 720 x 250): half the width, all inside streaming range.
- Budget: 2,500 instances, 500 k triangles.

Rejected alternatives: a lane as wide as the base row (320: reads as a field, not a lane); one shared throw
stage (owner: too much travel); bases narrower than 56 (heroes at Titan size need the room).

## 5. The lane

- One lane, 5 tracks. Strip 200 wide, 20 of foreground each side, backdrops outside that.
- 17 zone modules, each exactly 320 long: 5,440 studs. (Today: 6 x 360 = 2,160.)
- Every zone is a self-contained model `Map/Lane/Zone_NN` with the same interface, so zone ORDER can change
  without rebuilding anything.
- Low dividers between tracks are part of each zone's theme (rope lines, lantern rows, painted lines).

### Zone module anatomy

| Layer | What | Budget |
|---|---|---|
| Gate | themed arch across the lane, zone name banner | 1 |
| Floor | themed strip, track dividers, boundary line | 12 parts |
| Foreground | props within 20 studs of the strip | 150 instances |
| Midground | buildings 20-60 tall, the anime's architecture | 250 instances |
| Landmark | ONE hero piece 80-140 tall, readable from two zones away | 60 instances |
| Skyline | flat low-poly silhouettes behind, no collision, no shadows | 20 instances |
| Atmosphere | client-side: sky tint, fog colour, ambient particles, ambient loop | no parts |

Per zone: at most 700 instances, 250 k triangles, 12 unique meshes. Within 600 studs of any camera: at most
3,500 instances and 700 k triangles (today 6,911 and 1.28 M).

### Streaming and flight

- Hub persistent. A lane SKELETON is persistent too (floor, backdrop slabs, gate, low-poly landmark: about 40
  instances per zone, 680 in all), so a flight never crosses empty space. Zone detail streams.
- The focus part already glides with the food (`ThrowService:_focus`); for long throws it jumps to the landing
  zone at wind-up so the destination is loaded on arrival.
- Flight time grows to about 6.5 s for the last zone, eased: fast through beaten zones, slow for the last 300 studs.

## 6. Zones are built 3 at a time

| Batch | Zones | Note |
|---|---|---|
| 1 | Naruto, Demon Slayer, One Piece | the three already stocked with heroes; sets the quality bar |
| 2 | My Hero Academia, Blue Lock, Black Clover | need heroes first |
| 3 | Hunter x Hunter, Other Worlds, Attack on Titan | |
| 4 | Chainsaw Man, JoJo, Masterminds | |
| 5 | One Punch Man, Bleach, Solo Leveling | |
| 6 | Jujutsu Kaisen, Dragon Ball | |

Per zone, in this order: mood board (3-5 places from the anime) -> asset hunt -> build in a workshop area
beside ZoneLab -> lighting and atmosphere -> performance check -> owner looks at it in Studio -> install in
the lane. A batch is finished when the owner has approved all three in the game. Zones not built yet sit
behind a "coming soon" gate.

## 7. Assets

Creator Store and online free packs are both allowed. Every asset still goes through quarantine: every
script, sound and GUI is stripped before it enters the place (a pack in this project carried a Studio
backdoor: CLAUDE.md, known traps). A model that only works through its script (a spinning sign, a door) is
re-driven by our own code or left static. Parts are counted (thousands = rejected) and each piece is
recoloured to the zone palette. When nothing good exists, the landmark is modelled for the zone.

## 8. Risks and fixes

| # | Risk | Fix |
|---|---|---|
| 1 | 17 hand-built zones is months of art | 3 per batch, publishable after batch 1 |
| 2 | Mid-lane not streamed during a long flight | persistent skeleton + focus jump |
| 3 | Camera too fast over 5,440 studs | eased, longer flight |
| 4 | 17 zones need a new economy (power gates, incomes, anime foods, gear) | placeholder curve for the greybox; real balance with `tools/balance_sim.py` before batch 2 |
| 5 | Outer players walk a diagonal to their pad | 67 studs at worst, 4 seconds |
| 6 | Current map and generators are retired | props are reused: ninja village -> Naruto, pirate harbor -> One Piece, samurai and sakura -> Demon Slayer |
| 7 | Saved test profiles refer to the 6 old zones | game is private: reset the stores at the switch |

## 9. Code and data touched (when building starts)

`config.Server` (5 players, 5 plots), `config.World` (pitch 64, base size, pad positions, yard and deck
offsets), `Zones` (17), `Training.Stations` (courts move from inside the base to the yard), `Throw` flight
times. `src/shared/Core/World.luau` (pad x differs from base x; one lane) and its users: ThrowService,
TrainingService, HeroController, TrainingController, ThrowSequence, Blockout, `tests/World.spec`. Food cart
and sell booth become per-player prompts. `tools/map/*` is replaced by a zone-module installer. HeroIndex UI:
17 zone pages. Unchanged: heroes, auras, UI system, store, saving, the mini-games themselves.

## 10. Build order

| Phase | What | Done when |
|---|---|---|
| 0 | Commit and tag today's state as the rollback point | tag exists |
| 1 | Greybox: hub v2, 17 blank zone modules, skeleton; code on the new layout | a full throw to zone 17 plays on grey boxes; fps measured |
| 2 | Hub art pass: festival street, bases, yards, throw deck, Rift Gate | owner approves the hub in the game |
| 3 | Zone batch 1 | owner approves all three |
| 4 | Economy and anime foods for 17 zones | `balance_sim.py --check` green |
| 5 | Later batches, one at a time | each approved in turn |

## 11. Still open

1. Zone length: 320 for every zone, or longer late zones like the reference.
2. Reset the test profiles and retire the 6 old zones: yes or no.
