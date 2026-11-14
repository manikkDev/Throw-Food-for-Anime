# 04 World and map

Numbers are in `design/map.json`. Built with `roblox-map` (layout + prover), dressed with the
props in 03. Blockout in section 2, full build in section 3.

## 1. Layout (top view, not to scale)

```
            z = 1360  ............ end wall (later zones append here)
 Spirit Realm      |  |  |  |  |  |      6 parallel lanes, 40 wide,
 Hero City         |  |  |  |  |  |      each zone band 220 long,
 Samurai Castle    |  |  |  |  |  |      a Lane_ZoneGate arch at every band start
 Ninja Village     |  |  |  |  |  |      showing the Power needed
 Festival Street   |  |  |  |  |  |
 Sakura Schoolyard |  |  |  |  |  |
            z = 40   -------------------
 plots            [1][2][3][4][5][6]     56 x 48 each, pitch 68, throw pad on the lane edge
            z = -20  -------------------
 hub              food cart, sell booth, summon shrine, daily chest, 3 leaderboards, spawns
```

Why this shape: landing zone is just the Z coordinate (one pure function, easy to prove); every
player sees every other plot and every throw; the far end can grow by appending a band.

## 2. A plot

Name arch (owner, total yen/s) at the hub side. Pedestal grid 6 x 4 (24 = MaxSlots); locked
pedestals are dim with a lock icon. Dojo pad on the left with the owned gear tier. Slot sign on
the right. Throw pad centred on the lane edge with a ring decal. Fence around the rest.
Camera when throwing looks down the lane from behind the pad.

## 3. Zones

| Zone | Key colour | Landmarks | Mood |
|---|---|---|---|
| Sakura Schoolyard | pink | school gate, clock tower, cherry trees, track | sunny morning |
| Festival Street | orange | stalls, lantern strings, drum tower | dusk lanterns |
| Ninja Village | green | bamboo, rope bridge, hidden gate | misty |
| Samurai Castle | red | keep, stone walls, red bridge, banners | golden hour |
| Hero City | cyan | neon towers, billboards, rooftop pad | night neon |
| Spirit Realm | violet | floating islands, great torii, glowing river | dream glow |

Each band has a clear 28-stud landing strip down every lane (no props: the food and the hero
must be seen) and scenery between and beside the lanes. Lighting is global (Future, bloom,
colour grade); zone mood comes from prop colour, local lights and particles, not from changing
Lighting per player, except a client-side tint while the follow-cam is inside a zone.

## 4. What the prover must pass (`map.json` prove)

Every plot point reachable from its spawn; no escape or fall-through; pedestals inside the
fence and not interpenetrating; landing strips flat and clear; lanes walkable end to end;
nothing at y = 0. UNVERIFIABLE is a failure.

## 5. Streaming and budgets

StreamingEnabled; plot row, hub, lane ground and gates are persistent; zone props stream. Before
a reveal the client requests the landing area (`RequestStreamAroundAsync`) during the flight so
the camera never arrives at an empty zone. Target: under 12K parts and 1.2M triangles in view on
a phone at the plot row, 60 fps on mid phones with `lowDetail` off.

## 6. Section 2 blockout

Grey ground, six plot rectangles, lane strips coloured per zone, gate arches as simple frames,
pad markers. Enough to throw, land, see a placeholder hero arrive and walk everywhere. The loop
is played on this before any art is made.
