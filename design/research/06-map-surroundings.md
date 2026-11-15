# 06 Map surroundings: the anime town, lane styling and free ready-made assets

Research date: 2026-11-15. Web pages, the public Creator Store (toolbox) API, and this project's own
files. Nothing was downloaded, nothing in the place or in `src/` was touched.

Evidence tags:

- **[measured]** read today from the Creator Store API (`apis.roblox.com/toolbox-service/v1`) or
  from `design/map.json`. Asset ids, creators, triangle and MeshPart counts in section 4a are all
  [measured]. Vote counts from that API are rounded, treat them as rough.
- **[opened]** the page was fetched and read today. **[snippet]** seen in a search result only.
- **[seen]** judged by eye from the owner's screenshots or from Creator Store thumbnails.
- **[inference]** my reasoning from the facts next to it. **UNKNOWN** = could not be verified.

## 0. Verdict

1. **The town is a good idea in one form and a bad one in another.** Good: a continuous *roofline*
   along the wall tops, a real hillside town behind the hub, one big landmark per zone. Bad: a dense
   walkable town filling the space between lanes. From the lane, about two thirds of every wall-top
   plateau is hidden by the wall's own edge (section 1.4), so a "huge town" up there is triangles
   nobody sees. No hit in this genre has any town at all; ours needs one only because our zones are
   named after places.
2. **The rejected hub skyline failed on composition and scale, not on the idea.** Eight unrelated
   landmarks, 22 to 48 studs tall [measured], evenly spaced on a bare lawn at one distance: a shelf of
   ornaments. The fix is one subject (a shrine town on a hill), three overlapping depth layers, and a
   far landmark 150+ studs tall.
3. **The map is already over its phone budget** (1.36M triangles in view against a 1.2M budget,
   10,005 MeshParts against 10,400 [measured, `map.json`]). New scenery must REPLACE the current
   wall-top props and landmarks and must average under about 400 triangles per building.
4. **The free Creator Store is the wrong main source.** I searched 159 keywords (6,578 models).
   There is no free, coherent, legitimately sourced Japanese or anime town pack. What exists free is:
   Roblox's own packs (city and nature, no Japanese), a handful of good single props, and a flood of
   re-uploads, including Unity Asset Store packs given away by people who say so in the description.
   Coherent Japanese packs on the store are now paid (USD 2.99 to 9.99).
5. **Best free route: CC0 packs from outside, uploaded under the owner's account**
   (KayKit, Kenney, Quaternius), with the reodesuxz low-poly Japanese packs as flat-colour massing
   for the Japanese zones, plus Roblox's official Synty City Pack for Hero City. Lane floor and walls
   get their "designed" look from 6 tinted pattern MaterialVariants, kerbs, pilasters and distance
   plaques, which cost almost nothing.

---

## 1. Is a continuous themed town a good idea?

### 1.1 What the successful games do

| Game | Border and backdrop | Evidence |
|---|---|---|
| Throw Food For Animals (362K online, 1.6M peak) | A corridor. Stepped cliff walls on both sides, taller than the camera, brick-pattern stud texture, bright stud-grass cap. Blocky trees on the cap roughly every 40 to 60 studs and a few at the wall foot. Two-tone checker stud floor. Zones change the floor colour. Haze at the far end. **No buildings, no landmarks.** | [seen] `img/ref_real_game_hub_lane.png`, research/05; stats [opened] rowatcher |
| Grow a Garden (about 22M peak) | Square plots in a row, shops across the map. Stud textures; first version built in about three days; press called it prototype-looking. | [opened] Wikipedia |
| Steal a Brainrot | Conveyor down the middle, bases on both sides, shops beside it. A guide calls the map fairly simple. Border type UNKNOWN. | [opened] Sportskeeda, Wikipedia |
| Escape Tsunami for Brainrots | Straight lane, base at one end, rarity zones in order. A fan ranking prefers the wide clear lane and marks down a map where the camera clips walls. | [opened] Beebom, TechWiser; ranking [snippet] |
| Strongman Simulator | A sequence of themed rooms, each behind a door. | [opened] Sportskeeda |
| Blade Ball, anime tower-defence lobbies | The art (stations, portals, boards, summon areas) lives in the hub; the arena is plain. | [opened] allthings.how; lobbies [snippet] |

Not verified: Pet Simulator 99, Pets Go, Race Clicker, Blox Fruits. No developer statement was found
saying simulators keep the lane clean on purpose; the pattern is visible, the stated reason is not.

Reading: the genre's hits ship with simple, loud, readable worlds, and the biggest one looked like a
prototype. A town is therefore **not needed to succeed**. It is a differentiator, and for this game a
justified one: the reference's zones are biomes (Forest, Savanna), which trees can carry. Ours are
places (Schoolyard, Harbor, Castle, City). A "Samurai Castle" zone that is a wall with lanterns
under-delivers on its own name [inference].

### 1.2 Where scenery helps and where it hurts

Helps:
- **First 10 seconds and thumbnails.** Roblox requires thumbnails and icons to match what players
  find in-game and to read at about 150 px [opened]. A hub shot with a castle on a hill is a
  thumbnail we are allowed to use only if it is really there. No data was found that a rich backdrop
  raises click-through or retention; do not expect a measurable lift from it alone.
- **Sense of progress.** A different skyline per zone tells the player how far the food went before
  the ribbon text does. Landmarks only work with a wide sightline and strong contrast in shape, colour
  or motion [opened, Level Design Book].

Hurts:
- **Noise in the lane.** Small detail spread evenly makes a space hard to read; cluster it and keep
  gameplay surfaces to clear shapes [opened, Level Design Book, Vaccaro]. In the reveal the hero and
  the food must be the most detailed thing on screen (squint test [opened, Blendo Games]).
- **Camera occlusion.** Our flight camera rides a few studs above the floor [seen,
  `design/world/v2_flight.jpg`]. Anything that overhangs the lane or crosses it fills the frame.
- **Phones.** Section 2. The map has no budget left.
- **Style clash.** Builders call detailed realistic structures inside chunky worlds out by name
  [opened, DevForum]. This is the real cause of the "AI generated" read: unrelated objects in
  unrelated styles. One style family for everything (section 4b).

### 1.3 Why the current hub was rejected (diagnosis from the two screenshots and `map.json`)

- Eight subjects from six different zones (lighthouse, pagoda, castle, clock tower, neon tower, robot,
  dragon) in one row. No single idea.
- Equal spacing, no overlap, all at one distance, each on its own patch of lawn. Nothing touches
  anything, so nothing reads as a town.
- Scale: the "castle" is 36 x 43 studs, the tallest tower 48 [measured]. A character is 5 studs tall.
  These are garden ornaments standing 60 studs from the player.
- No middle ground and no far ground: lawn, then sky.
- Mixed saturation (neon cyan next to dark green-grey) with no shared palette.

### 1.4 The sightline rule (the one number that decides everything on the wall tops)

Lane 56 wide, walls mostly 19 to 32 studs tall [measured], camera 3 to 10 studs up near the lane
centre. The wall's top edge hides everything on the plateau below the plane through the eye and that
edge. An object standing `s` studs back from the edge is visible only above

`hidden height = (wall height - camera height) x s / 28`, about **0.65 x s**.

| Setback from wall edge | Hidden below | Consequence |
|---|---|---|
| 0 to 6 studs | 0 to 4 | parapet, lanterns, banners, small trees all show |
| 6 to 14 | 4 to 9 | building facades 14 to 30 tall show their top floor and roof |
| 26 (centre of today's 52-stud gap) | 17 | only things 30+ tall are worth placing |
| 36 (centre of a 72-stud gap) | 24 | landmarks 60+ tall only |

This holds at every distance down the lane, because the edge is parallel to the view. It also means a
landmark on the plateau centre line is seen from both neighbouring lanes, so one model serves two.

### 1.5 Composition rules to apply

**Play lane (the 38-stud landing strip):** nothing. Two floor tones, painted markings, and the zone
gate at each boundary. No prop, no particle, no shadow-casting object.

**Wall foot (the 9-stud margin each side):**
1. Clusters of 2 or 3 props (one tall, one medium, one low), then 60 to 100 studs of bare wall; the
   pilasters, banners and lanterns of section 3.2 carry the rhythm in between. Today's
   1,066 foot props sit about one every 24 studs, evenly; regroup them and cut the count by about
   half (section 2.2 needs the instances).
2. Nothing taller than 8 studs, nothing past the kerb line, nothing thinner than 0.4 studs.
3. One wall-face feature per zone that repeats: a waterfall panel, a gate niche, a billboard.

**Wall tops:**
4. A continuous parapet in the first 2 studs: this is the line that makes the walls look finished.
5. A facade row at 6 to 14 studs back, in clusters of 3 to 5 buildings (80 to 120 studs long) with
   60 to 100 studs of trees between clusters. About 45% coverage. Buildings touch each other inside a
   cluster and share an eave height.
6. On the centre line, tall things only: one landmark per zone (60 to 110 studs), tree crowns, masts.
7. Nothing overhangs the lane. Nothing crosses it except the six zone gates (clear height 30+).

**Far backdrop (hub and outer sides):**
8. Three layers that overlap: near facades, mid hill with roofs, far silhouette. Detail falls with
   distance; the far layer is flat massing with no shadows [opened, DevForum, Roblox docs].
9. Far landmarks 150 to 220 studs tall, 300 to 500 studs from where players stand. Not further: the
   lowest quality level only guarantees about 500 studs of draw distance [opened].
10. One subject per view. The hub backdrop is the shrine town; zone landmarks live in their zones.

**Density per 360-stud zone, per lane side:** 2 facade clusters (6 to 8 buildings), 1 landmark
(alternate sides), 6 to 8 tree clumps on top, 3 prop clusters at the foot.

**Making six zones read as six places** (use all five levers, each changes at the gate):

| Zone | Floor hue and pattern | Wall body and parapet | Roofline silhouette | Landmark |
|---|---|---|---|---|
| Sakura Schoolyard | pink-white, ichimatsu check | cream plaster, school railing | flat school blocks, sakura crowns | clock-tower schoolhouse |
| Pirate Harbor | sand-orange, seigaiha waves | timber piles, rope and posts | masts, sails, crooked gables | lighthouse, moored ship |
| Ninja Village | moss green, asanoha | dark timber, bamboo fence | thatch roofs, bamboo, watchtowers | hidden gate with waterfall |
| Samurai Castle | red-grey, yagasuri arrows | stone base, white wall with tile cap | curved castle roofs, banners | keep (tenshu) |
| Hero City | cyan-slate, hex grid | concrete panels, guard rail, light strip | vertical glass towers, billboards | hero tower with rooftop pad |
| Realm of Legends | violet, shippo circles | pale stone, crystal balustrade | floating rocks, crystals, giant torii | great torii on a floating island |

Test for every zone: take a mid-flight screenshot, blur and desaturate it. The eye must land on the
food or the landing spot.

---

## 2. Roblox technical practice for a lot of scenery on phones

### 2.1 Settings to use

| Property | Value for this game | Why / source |
|---|---|---|
| `Workspace.StreamingMinRadius` | 64 (default) | docs recommend the default [opened] |
| `Workspace.StreamingTargetRadius` | 576 (default is 1024) | lowest quality level draws about 500 studs anyway; halves loaded scenery. No official guidance for linear maps; measure 512 / 576 / 640 on a phone [inference] |
| `Workspace.StreamOutBehavior` | `Opportunistic` | docs recommend it; frees memory beyond the radius [opened] |
| `Workspace.StreamingIntegrityMode` | `PauseOutsideLoadedArea` | docs recommend it [opened] |
| `Workspace.ModelStreamingBehavior` | `Improved` | docs recommend it [opened] |
| `Model.ModelStreamingMode` on scenery | `Atomic`, one Model per building cluster or landmark | `Persistent` is for "very rare" cases and never streams out [opened]. Keep Persistent to plots, hub, lane floors and gates, as today |
| `Model.LevelOfDetail` on landmarks and clusters | `StreamingMesh` now; A/B `SLIM` on a real phone | StreamingMesh = coarse untextured imposter shown when the model is streamed out, which suits flat colours. SLIM is the newer cloud-built LOD the docs prefer, still Client Beta, with an unanswered report of halved frame rate on a large map [opened] |
| `MeshPart.RenderFidelity` | `Automatic` (props `Performance`) | Automatic: full detail under 250 studs, medium to 500, lowest beyond [opened]. Never `Precise` on scenery |
| `CollisionFidelity` | `Box` on all decoration | collision data stays in memory even with CanCollide off [opened] |
| `CanCollide`, `CanTouch`, `CanQuery` | false on all decoration | docs [opened] |
| `Anchored` | true | docs [opened] |
| `CastShadow` | false, except the hub's near facades and the far keep | shadows are off below quality level 4 anyway; turn off on small parts and far foliage [opened] |
| Transparency | 0 or 1 only | partial transparency causes overdraw [opened] |
| Textures | none on town meshes, or ONE shared atlas per pack at 128 to 256 px | 1024 costs four times 512; docs say 512 at most, 256 for minor images [opened] |

During a throw the food leaves the streamed area. The project already calls
`RequestStreamAroundAsync` in `ThrowSequence.luau`; keep that, or add a second focus with
`Player:AddReplicationFocus()` for the flight (each extra focus costs server work [opened]).

Engine features that help without action: occlusion culling is live on all platforms including
Android since 27 Jan 2025 (iOS status has one conflicting [snippet]); large opaque simple Parts
occlude, CSG unions and tiny or highly detailed meshes do not [opened]. So **keep the lane walls as
big plain Parts**: they hide the neighbouring lanes' scenery for free. Texture streaming is live on
low-end phones [opened]. "Mesh Streaming and Improved Cloud LoDs"
(`Workspace.MeshStreamingAndImprovedLoDs`) has been opt-in since April 2026 and makes RenderFidelity
irrelevant; current default state UNKNOWN, do not depend on it.

### 2.2 Budgets

- Only official scene figure: stay "below 1,000 draw calls and 1,000,000 triangles" on the baseline
  device, given as an example, not a platform limit [opened]. No official instance budget exists.
- Low-end is defined as under 2 GB RAM in Roblox analytics; one forum report puts a 2 GB phone's
  crash point near 800 MB of client memory [opened, anecdotal].
- This map [measured]: 3.30M triangles total, 1.36M estimated in view at the plot row (budget 1.2M),
  10,005 MeshParts (budget 10,400), 1,066 wall-foot props, 245 wall-top props in the zones plus
  149 on the outer hills, 14 landmarks.

Budget for the new scenery (targets, to be measured after building):

| Layer | Unique meshes | Instances | Triangles each | Total | In view from a lane |
|---|---|---|---|---|---|
| Wall-top facade rows (12 edges x 2,160 studs, 45% covered) | 24 (4 per zone) | about 430 | 150 to 400 | under 175K | about 50 buildings, 20K |
| Centre-line landmarks | 6 to 8 | 12 to 18 | up to 3,000 | under 50K | 2 or 3 |
| Parapet modules (one 32-stud module per zone; plain Parts where a box rail is enough) | 6 | about 800 | 40 to 100 | under 80K | about 75 |
| Hub backdrop (3 layers) | 25 | about 120 | 300 to 1,500, keep 6,000 | under 150K | hub only |
| Outer ring: hills, mountains, clouds | 8 | 40 | 200 to 600 | under 20K | few |

Paid for by deleting the current 245 wall-top props and the 14 landmarks, and by the smaller
target radius. That is about 1,400 new instances against roughly 260 removed, so the MeshPart budget
(395 spare today) is the tighter limit, not triangles: also replace the 149 outer-hill props with the
ring, regroup the wall-foot props into fewer, larger clusters (rule 1 in 1.5) and drop about 600 of
them. Net: about +390, inside the budget.

### 2.3 Instancing, textures, Parts versus meshes

- Identical MeshParts batch into one draw call when their SurfaceAppearance or else their texture is
  identical; untextured ones batch on Material. Uploading the same mesh twice under two asset ids
  breaks it. Decals and Textures batch poorly [opened]. Colour and size differences did not break
  batching per the engine's 2018 instancing post; current docs are silent [opened, old].
- So: **30 to 60 unique meshes for the whole town, varied by Color and Size only.** This is why four
  buildings per zone, recoloured, beat forty unique ones.
- Built-in materials use far less memory than custom textures [opened]. SurfaceAppearance carries up
  to five maps; no PBR on scenery.
- Plain Parts batch by material and shape [opened, old]. A free model made of 40 plain Parts is fine
  as a far prop. A model made of hundreds of Parts, or of unions (20,000-triangle cap, never
  occluders, break SLIM [opened]), is not: reject it or rebuild it as one mesh.

Intake checklist for every free model, before it goes near `Workspace.Map`:
1. Read `hasScripts`, triangle and MeshPart counts from the store API first. Reject anything with
   scripts that should not have them (every mass re-upload found in section 4c has scripts).
2. Insert into an empty baseplate, never into the Team Create place. Delete every Script,
   LocalScript, ModuleScript, Sound, light, particle, weld, constraint, Decal, Texture, SurfaceGui.
3. Look at the mesh names (section 4c red flags). Note the creator and id in `design/meshes.json`.
4. Anchor, set the properties in 2.1, group as one Model per building, measure triangles.
5. Over 400 triangles for a row building or over 3,000 for a landmark: decimate (external CC0 only)
   or pick another.

---

## 3. Lane ground and walls

What makes the reference floor look designed [seen]: two tones in a regular check, a texture with a
visible unit (the stud), a hard edge where floor meets wall, and a colour change at each zone. Ours
today [seen, `v2_flight.jpg`, `v32_lane_samurai.jpg`]: one flat tone, one centre stripe, a wall
that meets the floor with no kerb, and a single wall material from start to end.

### 3.1 Floor

| Element | Spec | Cost |
|---|---|---|
| Base | one large Part per lane per zone (36 total, already there), zone hue | none |
| Pattern | **6 greyscale pattern MaterialVariants** (ichimatsu, seigaiha, asanoha, yagasuri, hex, shippo), 512 px colour map only, `StudsPerTile` 8 to 12, tinted by the Part's Color. Low contrast: the pattern is 10 to 15% darker than the base | 6 small textures in total |
| Two-tone bands | alternate two values of the zone hue every 24 studs along the lane (the reference's check, stretched to read at chase speed) | none, same Parts split |
| Landing strip edges | 1-stud white line each side of the 38-stud strip | 2 thin Parts per zone |
| Distance marks | a 2-stud white bar across the lane every 100 studs; the NUMBER goes on wall plaques at both sides, not on the floor (floor numbers are unreadable from a low chase camera) | 1 Part + 2 plaques per 100 studs |
| Zone boundary | an 8-stud band: white, then the next zone's key colour, under the gate arch | 2 Parts |
| Kerb | 2 wide, 0.6 high, at each wall foot, two-tone every 8 studs in the zone's trim colour | 1 instanced wedge-profile mesh |
| Margin (9 studs each side) | a second material: gravel, planks, shallow water channel, pavement | per zone |

Why MaterialVariant and not Texture instances for the pattern: a variant tiles by studs on any part
size, is tinted by part colour (one greyscale map serves every zone colour), and its `MaterialPattern`
can be `Regular` for geometric patterns [opened]. A MaterialService override replaces a base material
place-wide, so use NAMED variants per part, not overrides [opened]. Use a `Texture` (per face, with
`StudsPerTileU/V`, `OffsetStudsU/V`, `Color3` [opened]) only where one face needs a marking.

Free pattern sources: seigaiha on Wikimedia Commons is public domain and freesvg has a CC0 seamless
one [opened]; Commons asanoha is GFDL / CC BY-SA and shippo is CC BY-SA [opened / snippet], so
**redraw asanoha, shippo, yagasuri and ichimatsu ourselves**: they are ruler-and-compass geometry and
a redrawn tile carries no licence at all.

If the owner wants the reference's stud look: there is no official studs material. Community routes
are a stud decal over a grid, or stud MaterialVariants cloned at several `StudsPerTile` values to
avoid cut-off studs [opened, DevForum]. It is a legitimate choice, but then EVERYTHING must be stud
style (section 4a item 13 and 14), which conflicts with `kit.json`'s "no textures" art bible. Decide
once; do not mix.

### 3.2 Walls

Three bands, one rhythm:
- **Plinth** 3 studs, darker, proud by 0.5: grounds the wall and hides the floor seam with the kerb.
- **Body** in the zone material (table in 1.5), with a **pilaster** 2 wide and 1 proud every 24 studs.
  Pilasters turn a blank 2,000-stud surface into counted bays.
- **Coping** (the existing cap) plus the zone **parapet** module on top.
- On alternate pilasters: a hanging banner in the zone colour, then a lantern or lamp. Every fourth
  bay: the distance plaque. One wall-face feature per zone (waterfall panel, niche, billboard).
- Everything on the wall face stays within 2 studs of it.

Avoid: a Decal or SurfaceGui per bay (hundreds of unbatched draws; SurfaceGui also needs
`MaxDistance` raised from its default 1000 [opened]); Neon on long runs (bloom washes the lane);
unions for niches; scrolling textures on big areas; Terrain for the lane floor (cannot carry a
pattern); text meshes in fake Japanese.

---

## 4. Free ready-made assets

### 4a. Roblox Creator Store

Method: 159 keyword searches through the toolbox API (Japanese town, shrine, torii, pagoda, castle,
sakura, bamboo, lantern, stall, ramen, waterfall, cliff, pirate, ninja, samurai, city, floating
island, crystal, simulator, stud and more), details for 6,578 models, thumbnails viewed for 70,
plus the full list of 940 models published by the Roblox account. Link form: `https://create.roblox.com/store/asset/<id>`.

What the free store actually contains:
- **Roblox's own packs** (creator "Roblox", id 1): authorised, mesh-based, safe. City and nature only.
- **Good single props** by individual creators: trees, lanterns, a torii, a galleon, clouds.
- **Franchise maps** (named after well-known anime and games): unusable.
- **Re-uploads.** Hundreds of October 2026 copies from throwaway accounts and from one account
  already shown as "Content Deleted - 158552482", all with scripts added. Identical triangle and
  MeshPart counts give them away.
- **No free, coherent, original Japanese or anime town pack.** The coherent ones are paid.

Usable, verified today (all free, no scripts unless noted):

| # | Name | Creator | Asset id | Contents | Weight and notes |
|---|---|---|---|---|---|
| 1 | Synty City Pack | Roblox | 6933556508 | modular offices, apartments, shop fronts, roads, park, vehicles | 332 MeshParts, 256,709 tris in all. Low-poly, one palette atlas. Officially licensed "for use in any Roblox game" (description) |
| 2 | Synty Nature Pack | Roblox | 6933438443 | trees, bushes, flowers, logs, boulders, rocks | 200 MeshParts, 108,816 tris. Same style as 1 |
| 3 | City Building Pack | Roblox | 6418277837 | full buildings and stackable skyscraper sections | 682 MeshParts, 517,932 tris. Realistic; far silhouettes only |
| 4 | City Props Pack | Roblox | 6370681139 | street lights, poles, benches, bus stop, hydrant | 94 MeshParts, 66,318 tris, PBR, 2 scripts to delete |
| 5 | Modular Building Kit - Modern City | Roblox | 13168370735 | wall, cornice, awning, balcony pieces | 3,025 MeshParts, 796,055 tris, 8 scripts. Too heavy; pick pieces |
| 6 | Forest Pack | Roblox | 6432306802 | trees, bushes, rocks, wildlife | 83 MeshParts, 153,252 tris, PBR leaf cards, 13 scripts. Realistic: wrong style |
| 7 | Yasu's Stylized Tree Pack | mvyasu | 79689531752352 | 20 trees, 3 bushes, recolourable canopies, 128 leaf textures | 61 MeshParts, 40,144 tris. Author states own work. Alpha leaf cards: hub hero trees only |
| 8 | Sakura Tree | plentune | 3725991689 | one sakura | 1 MeshPart, 1,174 tris. Most used sakura on the store. Painterly alpha canopy: mid distance |
| 9 | Low Poly Torii | gewoon_aardbei | 15683214537 | one torii | 3 MeshParts, 312 tris. Flat colour, fits the art bible |
| 10 | Low poly Street Lantern | I4supraa | 8990192177 | post lantern | 8 MeshParts, 700 tris |
| 11 | japanese lantern | cybidal | 12521854808 | stone toro | 4 MeshParts, 3,334 tris. Heavy for scattering; use at shrine pockets only |
| 12 | Medieval Galleon | UndoneBuilder | 851218540 | sailing ship | 2 MeshParts, 5,226 tris. Author states own work, free to use |
| 13 | Stud pack V1 | Gaelrivera135 | 128071741625902 | stud cliff, stud trees, columns | 20 MeshParts, 4,058 tris. The reference game's look. Only if stud style is chosen |
| 14 | N6mer's Stud-Building Kit | N6mer | 87871395044454 | 30+ stud models, floor pattern ideas, old materials | 290 MeshParts, 328,326 tris, 435 decals. "feel free to use". Reference for patterns |
| 15 | Low Poly Palm Tree | LoucDu44 | 10354687850 | palm | 9 MeshParts, 1,368 tris |
| 16 | Low Poly Buildings Set | molegul | 4979175517 | a few city buildings | 26 MeshParts, 40,666 tris. Description allows any project, credit optional |
| 17 | Floating Island | Starblaze Games (group) | 16519830532 | island with trees and path | 40 MeshParts, 14,074 tris |
| 18 | low poly crystals | fishyfishcans | 9821727055 | crystal clusters on rocks | 58 MeshParts, 2,296 tris |
| 19 | Low Poly Cloud Pack | gavinpgamer6199 | 5345601430 | 7 clouds | 7 MeshParts, 2,244 tris. "no credit needed" |
| 20 | Low-Poly Rocky Mountain Border | DaveCam456 | 11751636142 | one rock ridge | 1 MeshPart, 557 tris |
| 21 | Low Poly Waterfall | Kenbooks56 | 16444908253 | curved sheet with streaks | 0 MeshParts (Parts and effects). Study the technique, then build ours |
| 22 | Japanese Bridge | HoudiniDev (original, 2015) | 270101983 | arched bridge | Part-built, 4,596 tris. 9006622520 is a later copy |

Looked good, rejected (reason [measured] from the description or fingerprint):

| Asset | Id | Why not |
|---|---|---|
| Low Poly Japanese Buildings Color 1 / 2, Prop Pack Color 1 / 2 (BL00MIE) | 3226471202, 3226472387, 3226579873, 3226580409 | the best-looking free Japanese set, but the description says "Imported from Unity": a third-party pack, source and licence unknown |
| Low-Poly Buildings Pack (Killercloudz) | 5511084119 | description: meshes "bought off the Unity Marketplace", given away. Not theirs to give |
| Low Poly City Pack (zaragosa126) | 13791056394 | "the popular low poley meshes": origin unknown |
| Low poly city Pack (Beacon studios.) | 15220197111 | 332 MeshParts, 256,709 tris: a copy of Roblox's Synty City Pack. Use the original |
| Synty CyberPunk City, Village Pack Low Poly (Mehdiw8); Synty Sci-Fi City Pack, Synty Farm Pack (RICHDBRO) | 8358474720, 9069668223, 12859782733, 12859888910 | Synty packs outside the six Roblox licensed |
| Cyberpunk city (creepercatchanel) | 11332829712 | credits a Sketchfab author; licence and attribution duty unknown |
| Genshin Impact buildings pack, Demon Slayer map, Pet Simulator X Map, and similar | 15162590798, 12822579006, 9724265395 | other games' IP by name |
| LOW-POLY Mountain-Border (starwarsfan1131) | 6865341186 | "i didnt make this i just found this". 200 triangles: remake it |
| Simulator Assets (BlizV3) | 13418164648 | demands visible credit "or else" |
| Japanese Castle (pxtrey), Japanese Village (lemonModel93), Japan Traditional House (aerqvin) | 9449904686, 7131460833, 7216709759 | 885 to 1,695 MeshParts and up to 2,557 decals each |

Not free, for the record (0 votes each, unreviewed, provenance UNKNOWN): Low Poly Japan Pack,
FreeflowStore, 75359600369342, USD 2.99, 96 MeshParts and only 15,174 triangles, flat chunky colours
[seen] (the closest match to our art bible found anywhere); Japanese Village - Low Poly, KashTheKing,
108834780220872, USD 4.99, 109 MeshParts, 122,016 triangles; Stylized Anime Japanese Town Pack - 120
Models, Naviworx, 119724934193367, USD 9.99. If the free Japanese route fails the eye test, USD 3
buys more than a day of reconciling packs.

### 4b. Free open-licence packs outside Roblox

None were downloaded: triangle counts per model, and how each looks next to our kit, are UNKNOWN
until the zips are opened in Blender. Style closeness to "bright, chunky, toy-like": KayKit (bevelled,
fat proportions, one gradient atlas) is closest; Kenney next (flat, very simple); Quaternius is toon
but textured; reodesuxz is flat colour and very crude.

| Pack | Author, URL | Licence | Formats, size | Contents that matter | Zone |
|---|---|---|---|---|---|
| Low Poly Japanese Town Pack | reodesuxz, reodesuxz.itch.io/low-poly-japanese-town-pack | custom: free for personal and commercial use, no attribution, no resale or redistribution of the files | FBX, GLB, OBJ, .blend; 31 models, 4,376 tris total, 519 kB | torii, shrine hall, pagoda, castle tower, stone lanterns, ramen shop, sakura, koi pond. Flat colour, no textures | hub, Sakura |
| Low Poly Japanese Castle Town Pack | reodesuxz, .../low-poly-japanese-castle-town-pack | same | 26 models, 3,206 tris | keep, gate, machiya, pagoda, torii, lanterns | Samurai Castle |
| Low Poly Ninja Dojo & Castle Pack; Japanese Shrine Pack | reodesuxz | same | 28 models, 2,218 tris; 29 models, 2,768 tris | dojo, garden, shrine architecture | Ninja Village |
| Low Poly School Pack | reodesuxz | same | 27 models, 4,616 tris | schoolhouse, bus, desks | Sakura Schoolyard |
| Low Poly Sky Islands Pack | reodesuxz | same | 30 models, 4,354 tris | 9 islands, 5 structures | Realm of Legends |
| Sushi Restaurant Kit | Quaternius, quaternius.com/packs/sushirestaurantkit.html | CC0 | FBX, OBJ, glTF, Blend; 108 models | torii, sakura tree, bamboo, shoji walls, door, signs, sushi truck | hub facades, wall foot |
| Pirate Kit | Quaternius, quaternius.com/packs/piratekit.html | CC0 | FBX, OBJ, glTF, Blend; 71 models (Nov 2023), textured | ship, small ship, docks, 3 houses, barrels, chests, anchor | Pirate Harbor |
| Pirate Kit | Kenney, kenney.nl/assets/pirate-kit | CC0 | 70 files | ships, boats, island pieces, fortress walls | Pirate Harbor |
| City Kit (Commercial) | Kenney, kenney.nl/assets/city-kit-commercial | CC0 | 50 files, v2.1 | complete buildings and skyscrapers | Hero City |
| City Builder Bits | Kay Lousberg, kaylousberg.itch.io/city-builder-bits | CC0 | FBX, glTF, OBJ; free tier 32+ models, 4.6 MB | toy city buildings, roads, cars | Hero City |
| KayKit Medieval Hexagon Pack | Kay Lousberg, kaylousberg.itch.io/kaykit-medieval-hexagon | CC0 | FBX, glTF, OBJ; free tier 200+ models, 33 MB, one 1024 atlas (works at 128) | **hills, mountains, clouds**, trees, rocks, water tiles, small complete buildings (European) | outer ring, sky, Realm |
| Free Modular Islands Pack | Marina_sunny_girl, marina-sunny-girl.itch.io/free-modular-islands-pack | CC0 | Blend, OBJ, FBX, GLB; 55 models, 4.9 MB | floating island pieces | Realm of Legends |
| Crystal Pack | iPoly3D, poly.pizza/bundle/Crystal-Pack-AywAG7aywi | CC0 | FBX, glTF; 28 models | crystals | Realm of Legends |
| Stylized Nature MegaKit | Quaternius (research/03) | CC0 | FBX, glTF; 68 models | trees, bushes, rocks, rock paths | everywhere |
| Ultimate Fantasy RTS | Quaternius, poly.pizza/bundle/Ultimate-Fantasy-RTS-nSDjmACoSU | CC0 | FBX, glTF; 107 models | temples (several), market stalls, docks, mountains | check if the temples read Japanese |

Checked and weaker: Quaternius Medieval Village MegaKit and Downtown City MegaKit are modular pieces,
not buildings; Kenney Castle Kit (75), Fantasy Town Kit (160), Nature Kit (330), Watercraft Kit (45),
City Kit Suburban (40) / Roads (90) exist and are CC0 but are European or generic; Poly Pizza's "Poly
by Google" pagodas are per-model licensed (usually CC BY: needs a credit line); Synty's free samples
are under Synty's own licence, not usable here; ithappy free packs forbid redistribution "as is";
Poly Haven and ambientCG are realistic PBR. No CC0 Japanese building pack of good quality was found
anywhere: that is the gap.

About reodesuxz: 48 packs released at once, about 120 triangles per model, no ratings, no comments,
tagged "No generative AI was used" [opened]. They look like scripted primitives [inference]. That is
exactly right for a wall-top row seen from 30+ studs and for backdrop massing, and too crude for a
landmark the camera gets close to. The licence allows commercial games; the no-redistribution clause
means the uploads stay private to the owner's account. The README inside each zip was not read.

Upload cost: use `tools/publish_meshes.py`; a whole pack is 30 to 60 small meshes. Upload under
user 3540923881 so the experience owns every asset id.

### 4c. Licence cautions

- **Synty.** Six packs are authorised: Roblox published Synty Nature, City and four Dungeon packs on
  10 June 2021, "completely free to use in anything you want to create on Roblox" [opened]. Any other
  POLYGON pack on the store is a third-party upload. Synty's licence bars sharing assets for reuse by
  others and names Roblox in its FAQ [opened]; Synty does send takedowns (itch.io published one in
  May 2024 [opened]).
- **Even authorised packs depend on someone else's asset ids.** In July 2024 the Synty City Pack's
  texture atlas was moderated and games using it went grey for about a week [opened].
- **Unity Asset Store and Sketchfab re-uploads** are common and sometimes self-declared (table in 4a).
  Buying a pack for Unity does not license giving it to others on Roblox.
- **What happens:** Roblox acts on valid DMCA notices with takedown and notification; repeat or
  egregious infringers are suspended or terminated; its guidelines say infringement can occur even if
  you downloaded, bought or credited the content [opened]. A staff reply says strikes come from
  rights-holder notices, not filters [snippet]. The practical failure is quieter: the mesh is
  moderated or its uploader deleted, and the building turns into a grey box or vanishes in a live game.
- **Asset privacy (full release 5 May 2026):** inserting a store asset in Studio grants the
  experience permission, which cannot currently be revoked; Open Use meshes work for anyone and that
  setting is permanent [opened]. Whether a mesh survives its uploader's deletion: UNKNOWN. Roblox's
  Terms of Use page (the free-asset licence wording) returned 403: UNKNOWN.

| Source | Risk for a monetised game |
|---|---|
| Unknown-uploader themed packs on the store | High |
| Single props by an identifiable original author | Low to medium, and cheap to replace |
| Roblox-published packs | Low (the 2024 incident shows not zero) |
| CC0 packs uploaded by the owner | Lowest: we own the ids |

Red flags: mesh names with `SM_Bld_`, `SM_Prop_`, `SM_Env_`, `POLYGON`, `_LOD0`, `SK_`, `T_`, `M_`;
one palette atlas across hundreds of meshes from an uploader with no other original work; "not mine",
"found this", "imported from Unity", "credits to"; a franchise name; the same triangle and MeshPart
counts as an older asset; scripts in a static model; emoji and keyword-stuffed titles from 2026.

---

## 5. Proposal: the layered scenery plan

One style family: flat or single-atlas low poly (KayKit, Kenney, reodesuxz, our own kit). Quaternius
pieces get their textures replaced by flat colours when they stand near ours. Nothing realistic.

**A. Gap between bases.** Raise `layout.wall_gap` from 52 to 72 (pitch 128; walking plot 1 to plot 6
goes from 540 to 640 studs). The extra width gives each plateau room for a facade row on both edges
plus a centre line. At the plot row each 72-stud gap becomes a walk-through pocket with its own
subject, so no two neighbours look alike: shrine pocket (torii, two toro, sakura), market alley (two
stalls, lantern string), koi pond with the arched bridge, bamboo grove with a hidden gate, taiko
stage. Five gaps, five pockets.

**B. Hub backdrop (replaces the eight landmarks).**
1. Near, on the ledge directly behind the hub wall: a continuous shopping-street facade, 12 to 16
   buildings touching, 20 to 35 studs tall, shared eave line, lantern strings. Shadows on.
2. Middle, 80 to 250 studs back, rising 30 to 60 studs: stepped terraces of roofs from 4 or 5 meshes
   reused and recoloured, sakura clumps, and one long stone stair climbing the hill under a row of
   12 torii. To one side a waterfall drops down the hill into a canal that reaches the plaza edge.
3. Far, 300 to 500 studs: ONE keep on the hilltop on the hub's centre axis, 150 to 200 studs tall;
   a pagoda at two thirds of that height off to one side; a ring of mountain pieces; clouds.

**C. Wall tops along every lane.** Parapet module per zone, facade clusters and tree clumps per 1.5,
centre-line landmark per zone alternating between plateaus so every lane sees one per zone.

**D. Outer sides (beyond lanes 1 and 6).** The plateau there has no far edge, so the roofline steps
back into hills: second row of roofs at 40 studs back and 20 higher, then the mountain ring. The
harbor zone opens to water on one outer side with the galleon moored and the lighthouse on a mole.

**E. Water.** Built in-engine, not downloaded: 2 or 3 flat strips per fall with one scrolling
streak texture (client-side `OffsetStudsV`), opaque, plus one mist emitter under 10 particles per
second that is disabled beyond 200 studs. One at the hub hill, one wall-face fall per Ninja Village
side, falls off the floating islands in Realm of Legends. No Terrain water on slopes, no stacked
transparency.

**F. Atmosphere.** Haze at the lane end already sells length in the reference; tune `Atmosphere`
density per the client-side zone tint so each zone's far wall dissolves into its key colour.

### Shortlist mapped to places

| # | Asset | Source | Free / licence | Goes to |
|---|---|---|---|---|
| 1 | Low Poly Japanese Town Pack | reodesuxz (itch) | free, custom | hub middle-layer roofs; Sakura wall-top rows; shrine pocket |
| 2 | Low Poly Japanese Castle Town Pack | reodesuxz | free, custom | Samurai Castle rows; keep scaled up as the hub's far landmark |
| 3 | Low Poly Ninja Dojo & Castle Pack + Japanese Shrine Pack | reodesuxz | free, custom | Ninja Village rows; shrine pockets between bases |
| 4 | Low Poly School Pack | reodesuxz | free, custom | Sakura Schoolyard landmark (schoolhouse) and row |
| 5 | Sushi Restaurant Kit | Quaternius | CC0 | hub near facades (shoji walls, doors, signs), torii stair, bamboo grove, sakura |
| 6 | Pirate Kit | Quaternius | CC0 | Pirate Harbor rows (houses), docks at the wall foot, second ship |
| 7 | Pirate Kit | Kenney | CC0 | Pirate Harbor parapet (fortress walls), boats, towers |
| 8 | Medieval Galleon, 851218540 | Creator Store | free | moored ship, outer side of Pirate Harbor |
| 9 | Synty City Pack, 6933556508 | Creator Store (Roblox) | free, licensed | Hero City facade rows and outer-side street |
| 10 | City Kit (Commercial) | Kenney | CC0 | Hero City centre-line towers and far skyline |
| 11 | Free Modular Islands Pack | Marina_sunny_girl | CC0 | Realm of Legends floating islands (centre line and outer sides) |
| 12 | Crystal Pack (or low poly crystals, 9821727055) | iPoly3D / Creator Store | CC0 / free | Realm of Legends parapet and foot clusters |
| 13 | KayKit Medieval Hexagon Pack | Kay Lousberg | CC0 | hills, mountain ring and clouds everywhere; Realm village |
| 14 | Stylized Nature MegaKit | Quaternius | CC0 | rocks, bushes, background trees, waterfall rock faces |
| 15 | Yasu's Stylized Tree Pack, 79689531752352 | Creator Store | free | 6 to 10 hero trees in the hub, recoloured sakura pink and maple red |
| 16 | Low Poly Torii, 15683214537 | Creator Store | free | torii stair on the hub hill (one mesh, 12 instances), pockets |
| 17 | Low poly Street Lantern, 8990192177 | Creator Store | free | wall pilasters, hub street |
| 18 | Low Poly Cloud Pack, 5345601430 | Creator Store | free | sky, 8 to 12 instances |
| 19 | Low-Poly Rocky Mountain Border, 11751636142 | Creator Store | free | far ring if the KayKit mountains are too soft |
| 20 | Stud pack V1, 128071741625902 | Creator Store | free | only if the owner chooses the stud look |

Fallback for the Japanese zones if items 1 to 4 look too crude in Blender: Low Poly Japan Pack,
75359600369342, USD 2.99 (not free).

Order of work: (1) lane floor, kerb, wall bands and parapet for one zone of one lane, judged in the
flight camera; (2) the hub backdrop, judged from the spawn point; (3) one zone's wall-top row and
landmark, judged against the sightline rule; (4) roll out, measuring triangles in view after each zone.

---

## 6. Not verified

- Every external pack's real look and per-model triangle count (nothing downloaded); the reodesuxz
  README; whether Quaternius "Temple" models read as Japanese.
- Whether `SLIM` is fully released on phone clients, and the current default of
  `MeshStreamingAndImprovedLoDs`. Whether Color differences still keep MeshParts in one batch.
- The exact sightline factor: it uses wall heights from `map.json` and an assumed camera height of
  3 to 10 studs. Measure once in the flight camera.
- Borders of Steal a Brainrot, Pet Simulator 99, Pets Go, Blox Fruits; any developer statement on
  lane readability; any data linking backdrop richness to click-through.
- Original authorship of the single Creator Store props (rows 8 to 12, 15 to 22 in 4a) beyond what
  their descriptions claim. Roblox Terms of Use wording for free assets (403).

## Sources

Roblox docs:
[streaming](https://create.roblox.com/docs/workspace/streaming),
[SLIM](https://create.roblox.com/docs/workspace/streaming/slim),
[improve performance](https://create.roblox.com/docs/performance-optimization/improve),
[design for performance](https://create.roblox.com/docs/performance-optimization/design),
[Model](https://create.roblox.com/docs/reference/engine/classes/Model),
[MeshPart](https://create.roblox.com/docs/reference/engine/classes/MeshPart),
[Workspace](https://create.roblox.com/docs/reference/engine/classes/Workspace),
[solid modeling](https://create.roblox.com/docs/parts/solid-modeling),
[SurfaceAppearance](https://create.roblox.com/docs/art/modeling/surface-appearance),
[textures and decals](https://create.roblox.com/docs/parts/textures-decals),
[Texture](https://create.roblox.com/docs/reference/engine/classes/Texture),
[materials](https://create.roblox.com/docs/parts/materials),
[MaterialVariant](https://create.roblox.com/docs/reference/engine/classes/MaterialVariant),
[in-experience UI containers](https://create.roblox.com/docs/ui/in-experience-containers),
[environmental art: construct](https://create.roblox.com/docs/tutorials/curriculums/environmental-art/construct-your-world),
[environmental art: optimize](https://create.roblox.com/docs/tutorials/curriculums/environmental-art/optimize-your-experience),
[thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails),
[experience icons](https://create.roblox.com/docs/production/publishing/experience-icons),
[Creator Store](https://create.roblox.com/docs/production/creator-store),
[asset privacy](https://create.roblox.com/docs/projects/assets/privacy),
[DMCA guidelines](https://create.roblox.com/docs/production/publishing/dmca-guidelines).

DevForum:
[occlusion culling live](https://devforum.roblox.com/t/occlusion-culling-now-live-in-roblox-client/3300953),
[SLIM client beta](https://devforum.roblox.com/t/client-beta-introducing-scalable-lightweight-interactive-models-slim/4034709),
[SLIM performance report](https://devforum.roblox.com/t/slim-scalable-lightweight-interactive-models-causes-major-performance-degradation-in-large-experience-with-updateinstancedclusters2/4070199),
[mesh streaming and cloud LoDs](https://devforum.roblox.com/t/introducing-mesh-streaming-and-improved-cloud-lods-in-published-experiences-opt-in-phase/4601232),
[model LOD improvements](https://devforum.roblox.com/t/improvements-to-model-level-of-detail-lod/2204938),
[texture streaming](https://devforum.roblox.com/t/introducing-texture-streaming/4144855),
[part instancing (2018)](https://devforum.roblox.com/t/part-instancing-pre-release-announcement/130333),
[low-end Android analytics](https://devforum.roblox.com/t/analytics-optimize-low-end-android-crash-rates-server-memory-and-cpu-performance/3145364),
[streaming memory crash report](https://devforum.roblox.com/t/streaming-enabled-can-run-over-memory-management-to-crash-client/3305729),
[free Synty packs](https://devforum.roblox.com/t/free-synty-asset-packs-released-in-the-marketplace/1283755),
[Synty City texture moderated](https://devforum.roblox.com/t/synth-city-pack-texture-was-moderated/3063788),
[asset privacy full release](https://devforum.roblox.com/t/full-release-privacy-for-newly-created-image-mesh-and-decal-assets/4620416),
[detail in inaccessible areas](https://devforum.roblox.com/t/builders-do-you-still-put-detail-into-areas-players-cannot-access/189514),
[stud island feedback](https://devforum.roblox.com/t/showcasing-my-stud-island-map-%E2%80%93-feedback-for-halloween-spooky-update/3968200),
[old stud texture](https://devforum.roblox.com/t/how-to-get-back-the-old-stud-texture-easily-includes-meshes-unions/3157449),
[stud texture](https://devforum.roblox.com/t/how-to-get-stud-texture/4880386),
[classic and modern fusion](https://devforum.roblox.com/t/fusion-of-classic-and-modern-style/3231203).

Games:
[Throw Food For Animals stats](https://rowatcher.com/games/10766972131/throw-food-for-animals),
[TFFA zones guide](https://bloxodes.com/articles/throw-food-for-animals-zones-food-guide),
[Grow a Garden](https://en.wikipedia.org/wiki/Grow_a_Garden),
[Steal a Brainrot](https://en.wikipedia.org/wiki/Steal_a_Brainrot),
[Steal a Brainrot map guide](https://www.sportskeeda.com/roblox-news/steal-brainrot-map-guide),
[Escape Tsunami walkthrough](https://beebom.com/escape-tsunami-for-brainrots-walkthrough-beginners-guide/),
[Escape Tsunami zones](https://techwiser.com/escape-tsunami-for-brainrots-all-zones/),
[Strongman Simulator](https://www.sportskeeda.com/esports/how-get-strength-roblox-strongman-simulator),
[Blade Ball guide](https://allthings.how/roblox-blade-ball-how-to-play-full-guide/).

Level design:
[Level Design Book: env art](https://book.leveldesignbook.com/process/env-art),
[wayfinding](https://book.leveldesignbook.com/process/blockout/wayfinding),
[composition](https://book.leveldesignbook.com/process/blockout/massing/composition),
[Vaccaro on environment art](https://80.lv/articles/environment-art-tips-from-anthony-vaccaro/),
[Blendo Games on readability](https://blendogames.com/news/post/2026-06-xx-leveldesign_readability/).

Asset packs and licences:
[reodesuxz Japanese Town](https://reodesuxz.itch.io/low-poly-japanese-town-pack),
[reodesuxz Castle Town](https://reodesuxz.itch.io/low-poly-japanese-castle-town-pack),
[reodesuxz Ninja Dojo & Castle](https://reodesuxz.itch.io/low-poly-ninja-dojo-castle-pack),
[reodesuxz School](https://reodesuxz.itch.io/low-poly-school-pack),
[reodesuxz Sky Islands](https://reodesuxz.itch.io/low-poly-sky-islands-pack),
[reodesuxz 48-pack thread](https://itch.io/t/7120179/48-new-free-game-asset-packs-24-low-poly-3d-24-pixel-art-2d),
[Quaternius Pirate Kit](https://quaternius.com/packs/piratekit.html),
[Quaternius Sushi Restaurant Kit](https://quaternius.com/packs/sushirestaurantkit.html),
[Quaternius Ultimate Fantasy RTS](https://poly.pizza/bundle/Ultimate-Fantasy-RTS-nSDjmACoSU),
[Kenney Pirate Kit](https://kenney.nl/assets/pirate-kit),
[Kenney City Kit (Commercial)](https://kenney.nl/assets/city-kit-commercial),
[KayKit Medieval Hexagon](https://kaylousberg.itch.io/kaykit-medieval-hexagon),
[KayKit City Builder Bits](https://kaylousberg.itch.io/city-builder-bits),
[Free Modular Islands Pack](https://marina-sunny-girl.itch.io/free-modular-islands-pack),
[Crystal Pack](https://poly.pizza/bundle/Crystal-Pack-AywAG7aywi),
[Poly Pizza pagoda search](https://poly.pizza/search/pagoda),
[Synty one-time licence](https://syntystore.com/pages/one-time-purchase-licence),
[Synty FAQ](https://syntystore.com/community/faq),
[Synty takedown on itch.io](https://itch.io/takedowns/2287788),
[ithappy free asset policy](https://ithappystudios.com/pages/free-asset-usage-policy).

Patterns:
[Seigaiha, Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Seigaiha.svg),
[seigaiha, freesvg](https://freesvg.org/seigaiha-blue-exact),
[Asanoha, Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Asanoha.svg).

Creator Store data: `https://apis.roblox.com/toolbox-service/v1/marketplace/10?keyword=...` and
`.../v1/items/details?assetIds=...` (public, no login), queried 2026-11-15.
