<!-- section: 3 -->
# HANDOFF: section 3 of 6 closed (World and visuals)

Game: `D:\Roblox Studio Games\Throw food for Anime`
Written: 2026-11-14T20:13:40+05:30

A cleared session starts from this file alone. Read it in full, then run:

```bash
python ~/.claude/skills/create-roblox-game/scripts/section.py resume --dir "D:\Roblox Studio Games\Throw food for Anime"
```

## REWORK 4 (2026-11-15): done, awaiting approval

Owner's asks after `s3-v3-03` (logged): HUD side buttons touched; stat pills worse than before, keep it simple like the reference (`work/ui/owner_v32/REFERENCE_real_game_hud.png`); training bar too big; bigger bases with room for future mini games; more gap between bases; walls off the bases; styled lane floors and walls; replace the generated skyline, buildings, robot and cherry trees with ready-made anime/Japanese assets as a town round the hub and along every lane; research first.

- Research: `design/research/06-map-surroundings.md`. Verdict used: a town as a ROOFLINE (facade rows near the wall edges, tall landmarks on the terrace centre line: from the lane everything below about 0.65 x its setback is hidden), a hillside shrine town in layers behind the hub with one big castle, replace rather than add (the map was at its phone budget).
- UI v3.3 + client, build `s3-v3-04`: plain aligned stat rows (icon column, value column, small line under), 14 px clear between side buttons (the `gap` check now measures the painted box: 93 failures before, 0 after), compact training bar (440 x 86 at 720p). `design/ui/CHANGES-v3.md` v3.3.
- Store assets: 61 templates. Complete buildings assembled from the free modular pack by `tools/studio/assemble_store_buildings.luau` (castle, keep, 2 pagodas, 2 shrines, 6 houses, 3 halls, stage, dark towers), 3 farmhouses, 2 waterfalls, 2 sakura trees. Tags `design/store_assets.json` (the generator builds every pool from kind + zones), sizes `assets/meshes/manifest-store.json`, sources `ServerStorage.StoreAssets` (never delete).
- Map v3: config.World PlotPitch 108, PlotWidth 84, PlotBackZ -44 (72 deep), pedestals in the back half (spacing 8), DojoPad -26/12, SlotSign 32/-6, Yard keys (a 28 x 24 court with an invisible `Yard` part, `Reserved = "minigames"`), HubDepth 110; `World.yard()` + 3 specs. Generator = `gen_map.py` + `gen_lane_style.py` + `gen_town.py` + `make_textures.py` (11 tiles, ids in `assets/map/ids_textures.json`). Lane floors patterned per zone with kerbs and distance plaques; walls with base course, pilasters, coping, cloth banners/noren with designs, shoji windows; forecourt with aprons, stepping stones, hedges, lanterns, trees; garden strips between bases; town on the 52-wide terraces and outer tiers; hub backdrop = castle 172 studs tall, pagodas, house rows, sakura, waterfalls.
- Streaming set in the place: target radius 576, min 256, Opportunistic, PauseOutsideLoadedArea.

Verified in play on `s3-v3-04` (one real client, 1482x673, no script errors):

| What | Result |
|---|---|
| Map prover | RESULT PASS; built by 35 chunks, 0 missing models |
| Parts | 13,298 BaseParts in the spec (first v3 build: 21,560), 6,468 max within 576 studs of a stage; about 8,270 streamed in on the stage in play |
| Frame rate (Studio confirmed in front, on the throw stage) | 52.4 fps average, worst frame 68 ms (the previous map: 60.0) |
| Base | spawn on the plot, heroes on the back pedestals, yard text "TRAINING YARD" upright for a player facing the lane, gear on its pad |
| Throw | throw mode, flight over the town terraces, final beat in Ninja Village (shoji walls, hexagon floor, distance plaque) |
| HUD | plain stats and spaced buttons as on the sheet |
| Gates | `tools/gate.py` green |

Not verified this round: the training bar in play (the test tool could not trigger the dojo prompt; it passes the fit gate and the sheet `work/ui/mockups/v33_TrainingBar_3sizes.png`); lane floor zone names by eye; zones 3 to 6 on foot; phones (the frame rate fell from 60 to 52 on the dev PC, so a phone check matters more now).

Licence note told to the owner twice: the modular building pack and the prop pack by BL00MIE say "Imported from Unity"; if Roblox removes them those pieces go blank. Every piece is a tagged template: swapping is a change in `design/store_assets.json`.

## Where things are
- Art bible and size table for every model: `design/kit.json`.
- Models (64): Kiln sources `assets/meshes/src/{kit,gear,foods,zones}/*.kiln.js`, GLBs `assets/meshes/{kit,gear,foods,zones}/*.glb`, worker manifests `assets/meshes/manifest_*.json`, Roblox asset ids `assets/meshes/ids.json`, merged measured manifest `assets/meshes/manifest.json` (64 models + 43 hero rigs).
- Model tools: `tools/publish_meshes.py` (upload once, by content hash), `tools/studio/install_models.py` (LoadAsset -> clean template: colour from the hex in each part name, pivot at the base), `tools/merge_manifest.py`.
- Map: spec `design/map.json`; generator and emitter `tools/map/gen_map.py`, `tools/map/emit_chunks.py`, `tools/map/RUN.md`; runner `tools/map/build_in_studio.py`. Generated output (gitignored): `work/map/{report.json, plan.png, terrain/, chunks/*.lua}`. Regenerate with the commands in `tools/map/RUN.md`.
- UI: specs `design/ui/*.json` + `design/ui/theme.json` + `design/ui/templates/`; shipping trees `src/ui/*.model.json` (18 screens) and `src/ui/Templates/*.model.json` (11), mounted at `ReplicatedStorage.Ui` by `default.project.json`; generated binding list `design/ui/BINDINGS.md`; build tools `tools/ui/{build_ui,mangapop,screens,icons,bindings}.py`; icons `assets/ui/icons/` (39), food icons `assets/ui/food_icons/` (12), patterns `assets/ui/patterns/` (3), uploaded ids `assets/ui/ids_*.json`; `tools/gen_icons.py` -> `src/shared/Config/Icons.luau` (GENERATED); mockups `assets/ui/mockup.png` and `mockup_phone.png`.
- Client: `src/client/Ui/{Screens,Viewports,Theme,DevPanel}.luau`, `src/client/Ui/Pages/*.luau` (13 pages), controllers rewritten onto the screens: `Hud, Menu, Throw, Hero` + new `WorldUiController`. `DevHud`, `DevMenu`, `ThrowUi` are gone.
- Server: `PlotService` (gear model on the dojo pad, pedestals in rarity colours), `InteractService` (hub stations no longer act server-side), `DataService` (refuses to start a fresh profile over an unreadable save).
- Heroes: `tools/studio/build_r15.luau`, `tools/studio/run_bake.py`, `design/characters/README.md` (batch 2), `design/characters/roster.json` (43), `design/characters/final/batch2_*.jpg`. `Core/Roll.heroWeights`: heroes of one rarity share its weight.
- Pictures of the result: `design/world/*.jpg` (map in Studio, UI in play).
- Studio (the place, not Rojo): `Workspace.Map` (Plots, Hub, Lanes, Scenery, Barriers + terrain), `ReplicatedStorage.Assets.{Kit (46), Gear (8), Foods (12), Characters (43)}`, `ServerStorage.CharacterSources.{R15_Final (43), R6_Originals (31), Originals_Batch2 (12)}`. Lighting preset applied. Baseplate and the template SpawnLocation are gone.
- Skills changed (exported and committed in `_RobloxAI`, commit 5472be3): `roblox-ui/scripts/ui_build.py`, `create-roblox-game/scripts/validate.py`.

- REWORK after the owner played s3-03 (same day): reference recording notes `design/research/05-reference-recording.md` + frame sheets `design/research/img/ref_*.jpg`; 37 more models (36 set pieces `zone_props_v2` in `design/kit.json`, the new `Lane_ZoneGate`, `Plot_ThrowStage`; manifests `assets/meshes/manifest_zones_a2.json`, `manifest_zones_b2.json`, updated `manifest_kit.json`); map v2 (`tools/map/zones.json`, `tools/map/post_build.luau`, 20 chunks in `work/map/chunks/`); UI v2 (`tools/ui/screens_v2.py`, 20 glossy icons `assets/ui/icons_v2/` + `assets/ui/ids_icons_v2.json`); client v2 (`src/client/Fx/{ThrowSequence,ThrowPose,Particles}.luau`, `src/client/Ui/RevealUi.luau`); hero batch 3 (`design/characters/final/batch3_*.jpg`, `ServerStorage.CharacterSources.Originals_Batch3`). Pictures of the result: `design/world/v2_*.jpg`.
- Counts now: 59 heroes (51 lane + 8 premium), 101 world models, `Workspace.Map` = 8,863 MeshParts + 1,506 parts + terrain, `ReplicatedStorage.Assets.{Kit (81), Gear (8), Foods (12), Characters (59)}`.

- REWORK 2 after the owner played s3-v2-05 ("most things face the opposite direction", "button texts out of the box, buttons unnecessarily big and very normal", "try Creator Store anime props"), same day:
  - Facing: `tools/studio/install_models.py` turns every template half a turn and puts its pivot at the base centre; `tools/map/emit_chunks.py` sign faces (Back on a kit `Face_<hex>` part, Front on a plain anchor). All 101 templates reinstalled, the map rebuilt.
  - Hub plaza and skyline: `hub_plaza()` in `tools/map/gen_map.py` (giant lucky cat on a plinth, inlaid ring, lanterns, benches, cherry trees in planters, drums, foxes, banners, eight scaled zone landmarks behind a back wall lowered from 30-36 to 15-19 studs). `--meshpart-budget` default is now 9100.
  - UI v3: `tools/ui/mp3.py` (the button system), `tools/ui/screens_v3.py`, `tools/ui/fit_gate.py` (run by `build_ui.py`), `design/ui/CHANGES-v3.md` (what the client must do), large icons `assets/ui/icons_big/` + `assets/ui/ids_icons_big.json` (27 keys `...Big`), `FxSunburst`. `tools/gen_icons.py` no longer reads `ids_icons_v2.json` (83 images in `Icons.luau`).
  - Client v3: `Screens.setButtonState` / `Screens.tint` / press feedback / `TouchScale` in `src/client/Ui/Screens.luau`, `Theme.BUTTON` in `Theme.luau`, pages rewritten onto them.
  - Pictures: `design/world/v3_*.jpg` (game), `work/ui/before_v3/` and `work/ui/after_v3/` (the defects), `work/ui/mockups/` (sheets).
- Counts now: `Workspace.Map` about 9,015 MeshParts in 2,011 placements + terrain (3.30M triangles, 1.22M within 600 studs of the plots), 101 world models, 59 heroes, 18 screens + 11 templates, 83 images.

- REWORK 3 after the owner played s3-v3-02 ("buttons touching each other", "food shop should scroll horizontally", "HUD texts too small and unstable", "use the free Creator Store assets"), same day:
  - UI v3.2: spacing and a 13 px text floor are properties of the helpers (`tools/ui/mp3.py`) and two new `fit_gate.py` checks (`gap`, `min_text`); Food Shop is one horizontal row (`FoodScroller`, attribute `WheelScrollsX`); HUD side buttons carry their caption inside the face; stats are three aligned pills. Client: sideways wheel scrolling in `Screens.luau`, scroll-to-NEXT in `Pages/FoodShop.luau`. `design/ui/CHANGES-v3.md` has the v3.1 and v3.2 sections.
  - Creator Store props: 36 free models, scripts and effects stripped, archived as sources in `ServerStorage.StoreAssets` (attributes `AssetId`, `Creator`; never delete). `python tools/studio/install_store_assets.py` squares each one up and installs `ReplicatedStorage.Assets.Kit.Prop_store_<Name>`, and writes `assets/meshes/manifest-store.json` (read by the map generator, not by the upload tools). Placed by `hub_plaza()` and the zone pools in `tools/map/zones.json`.
  - Pictures: `design/world/v32_*.jpg`.
- Counts now: `Workspace.Map` about 10,000 model parts in 2,281 placements (314 of them Creator Store pieces) + terrain, about 3.5M triangles estimated (1.24M within 600 studs of the plots); 101 own models + 36 store templates; 59 heroes; 18 screens + 11 templates; 83 images.

## Done this section
- `python tools/gate.py`: PASS code gates (rojo build, 90 lune specs, selene, stylua), config, server config, contract, pacing (unchanged by the 12 new heroes).
- `verify_labels.py --ui src/ui --client src/client`: PASS, all 201 dynamic labels are written by client code. `verify_ui.py` (through `tools/ui/build_ui.py`): 0 failures at 1280x720 and 844x390 on all 18 screens and 11 templates.
- Map prover (`work/map/report.json`): RESULT PASS (grounding, standable surface, enclosure, overlap, clear routes, performance budget; terrain reachability at both tides). Built in Studio by 15 chunks: 4,062 MeshParts, 97 plain parts, 0 missing models. Anchor contract checked by probe: 6 plots x 28 pedestals (tops at 1.00), every prompt with its Action/Plot, 7 spawns.
- Models: 64 of 64 uploaded (ids on record), installed, sizes within 5% of each manifest row; all under their triangle budgets (measured by the workers' converters).
- Heroes: 12 new avatars rebuilt to shoulder 4.00 / root 3.00, checked in four close-ups, 43 templates baked with 15 motors each; in Play 12 of 12 new ones loaded and animated.
- Play test on 2026-11-14 (build `s3-03`, one real client, no script errors in Output in any run):

| What | Result |
|---|---|
| Boot | 18 screens mounted, 0 visible `<unbound>`, 119 icon slots filled, HUD shows live values |
| Throw (mouse held on THROW, real input) | meter shown only on the pad; first catch = guaranteed Uncommon, +3 yen/s |
| Food shop | 12 cards, 3D food models spin in the viewports, prices and "N new heroes" lines |
| Squad | hero portraits, rarity / size / mutation tags, income, bench and sell |
| Store | starter pack, passes, items, summon scroll with SEE ODDS |
| Hero index | 7 tiles in zone 1 with live chances (sum 99.97%) |
| Welcome back | opened once at join: "away 3m 36s, +492M"; CLAIM paid it |
| Daily chest (walk up, press E) | opened Daily Rewards; nothing was claimed until the button; then "1 DAY STREAK", TOMORROW |
| Gifts button | routed to Free Gifts with six timers |
| Settings -> Codes | typed "welcome", redeemed: "Code redeemed!", Lucky Throws x3 |
| Training (E on the dojo pad) | training bar shown, Power 10 -> 15, "NEW GEAR: Sandbag 600" |
| Saving | yen and heroes from the previous session were there at the next join |
| Frame rate (Studio in front, graphics level 21) | 60.2 fps average, worst frame 18 ms, 3,743 parts streamed in |

- REWORK, verified in play on build `s3-v2-05` (2026-11-14, one real client, no script errors in Output):

| What | Result |
|---|---|
| Map v2 prover | RESULT PASS; built by 20 chunks, 0 missing models; a 7-zone variant generated from data alone also passes |
| Spawn | on the plot (z 12); throw stage 42 studs in front of the base, lane starts at z 96 |
| Throw mode | HUD buttons hide, vertical meter with sliding marker, "+23 POWER", PERFECT band; T / tap throws |
| Sequence | letterbox, luck label over the top bar, zone ribbon, chase camera under the gate, food with trail, "1 in N" climbing, black silhouette, name puzzle with one slot per letter |
| Final beat | whole hero framed between the odds starburst and the name block; rarity ribbon, CRAVING tag, income, "sent to your bench", "tap to continue"; holds 2.6 s |
| HUD v2 | edge-hugging icon columns with the new icons, stats block bottom-left, slim hint; Welcome Back content visible after the z-order fix |
| Frame rate (Studio in front, level 21, on the throw stage) | 60.2 fps average, worst frame 18 ms, 6,200 parts streamed in |
| Gates | `tools/gate.py` green (90 specs), `verify_labels.py` PASS (211 labels), `verify_ui.py` 0 failures at 1280x720, 844x390, 1920x1080 |

- REWORK 2, verified in play on build `s3-v3-02` (2026-11-14, one real client, 1482x673, no script errors in Output):

| What | Result |
|---|---|
| Facing | stage arrow and steps point down the lane; gate banners ("SAKURA SCHOOLYARD START HERE") face the thrower; hub stations, cats and boards face the plaza; leaderboards readable from the plaza; heroes face the lane; gear stands on its pad (base 0.75 on a pad top of 0.70) |
| Map prover | RESULT PASS after the plaza (3,509 parts); built by 19 chunks, 0 missing models |
| Frame rate (Studio in front, on the throw stage) | 60.0 fps average, worst frame 19 ms, 6,140 parts streamed in |
| fit gate (new) | 152 failures on the v2 trees, 0 on v3 at 1280x720, 1345x611, 844x390, 1920x1080 |
| HUD | hint pill hugs its text; gear in the top-right corner; side buttons with their own caption rows; the gift chip takes the caption row; nothing over a window's close button |
| Food Shop | vertical grid; flavour-tinted art tile with sunburst and a large food; NEXT tag and gold keyline on the first unowned food; one sized price button per card; EQUIPPED state pill |
| Store | summon panel with head-and-shoulders viewport and two-line price buttons, BEST VALUE above the x10 face; passes and items in one vertical scroll |
| Squad, Hero Index, Free Gifts, Rebirth, Welcome Back | opened in play and correct (rows right-aligned, unknown heroes as coloured question marks, locks, six tabs inside the window, "2X [robux] 39" in one row) |
| Throw | T and the THROW button both throw; odds counter below the letterbox; final beat frames the hero |
| Gates | `tools/gate.py` green (7 steps), `verify_labels.py` 214/214, `verify_ui.py` 0 failures at four sizes |

- REWORK 3, verified in play on build `s3-v3-03` (2026-11-14, one real client, 1482x673, no script errors in Output):

| What | Result |
|---|---|
| fit gate | `gap` 37 -> 0, `min_text` 91 -> 0, all other checks 0 at four sizes |
| HUD | captions inside the side buttons (15 px at 720p), three stat pills with one icon column and one value column, rank chip and yen/s inside their pills, food chip as one pill |
| Food Shop | one horizontal row, every element on its own row with gaps, large food pictures, mouse wheel scrolls sideways (3 notches = 3 cards), opens scrolled to the NEXT card |
| Store, Hero Index | reopened after the spacing pass: correct |
| Map prover | RESULT PASS with the store props |
| Frame rate (Studio in front, on the throw stage) | 60.0 fps average, worst frame 19 ms, 7,062 parts streamed in |
| Gates | `tools/gate.py` green, `verify_labels.py` 214/214 |

## Decisions and why
1. Look: "toy-block anime festival" (`design/kit.json`). The owner called the greybox plain; the genre's hits are bright, chunky and readable from far. Everything is code-modelled with Kiln in flat colours, one MeshPart per colour: one hand, no downloads, exact sizes.
2. No asset packs were downloaded (no explicit permission for downloads): the CC0 route in plan 03 was replaced by Kiln for all 64 models.
3. The 12 new heroes go two per zone (7 per zone). Heroes of one rarity now SHARE that rarity's weight, so adding heroes never changes a zone's rarity odds or the economy (two new specs).
4. Hub stations open their screen on the client; the server no longer acts on the food / daily / gift / index / summon / squad prompts. Walking up to a cart must never spend Yen, and it makes Daily Rewards reachable after the claim.
5. The summon shrine opens the Store (it was wired to Rebirth in the blockout); the sell booth opens the Squad.
6. HUD shrunk after the first play test (stat chips 190x54, hint a 460x44 pill): the first version covered a third of the screen. The verifier's text floor for the two project sizes is now the plan's 14 px at 720p.
7. Pedestals wear the rarity colour of the hero on them (premium = store pink); locked ones are dim.
8. Training gear is placed by the server on the `Gear` anchor from `Assets.Gear.Equip_<name>`; thrown food is the real model riding an invisible carrier part, drawn 1.7x so it reads down the lane.
9. Icons ship as keys (`IconKey`, `PatternName`), ids live in the generated `Icons.luau`: an image can be re-uploaded without touching a screen file.
10. The map lives in the place (`Workspace.Map`); `Blockout.ensure` returns it untouched. The map's source of truth is `design/map.json` + `tools/map/`.
11. Fan-out: six workers (map, four model workers, UI) plus one for the client rewiring. All Studio work, uploads and play tests stayed on one thread.
12. `DataService` refuses to treat an unreadable stored value as a new player (it kicks instead of starting fresh).

13. (rework) The throw is a TAP on a self-sliding marker, not hold-and-release: it is what the genre's players know, it works with one thumb, and the server contract (`ThrowRequest(charge, lucky)`) did not change.
14. (rework) The catch is a staged reveal with two moving numbers (luck in flight, odds after landing), a silhouette and a self-solving name, ending on a 2.6 s final beat; the card that covered the hero is gone. Timings come from config (`Throw.Flight*`, `LandPauseSeconds`, `Rarities[*].RevealSeconds` 4.6 to 9.4); the whole sequence ends when the server says the hero arrives. Pacing still passes with `Throw.CycleSeconds` = 7.
15. (rework) Lanes are 56-wide walled corridors, zones 360 studs long, throw stage out in front of the base (`World.ThrowPadZ` 70, `LaneStartZ` 96). Walls are parts with a built-in material per zone (terrain ridges 12 studs wide render as jagged voxels and fail the prover).
16. (rework) Set pieces were modelled (Kiln, one style) instead of pulled from the Creator Store: the owner's complaint was sparse and generic surroundings, and mixed-source props would have added a second problem (mixed styles, scripts to vet).
17. (rework) The map total is 3.25M triangles against the skill's 1.5M guideline, by the map worker's choice and accepted here: about 1.18M sit within 600 studs of the plots and the rest streams by distance; 60 fps measured on the dev PC. Strict version: `gen_map.py --tris-budget 1450000`.
18. (rework) Premium heroes are 8 of the owner's batch-3 avatars; the premium ids did not change (products and saves refer to them), only names and looks.
19. (rework) Plot sizes cut to Big 1.2 / Huge 1.4 / Titan 1.7 so every hero fits a pedestal 7 studs from its neighbour.
20. (rework) Icons: 20 glossy icons generated with Cloudflare Workers AI (owner's key, owner's request) replace glyphs under the same keys; 6 that generated badly keep their glyph.

21. (rework 2) Models are turned once, in the installer, not per placement: Roblox's importer delivers an uploaded glTF model half a turn about Y (measured on `Plot_ThrowStage`: the arrow authored 1.1 toward +Z sat 1.1 toward -Z). The generator's rule stays "front is -Z, yaw turns it".
22. (rework 2) Creator Store props were tried, as the owner suggested, and not used. Six free packs were inserted into a quarantine folder and audited: three were reuploads carrying scripts and GUI (removed), one forest pack is 9,570 Parts, and the two clean ones (BL00MIE "Low Poly Japanese Prop Pack / Buildings") carry the mesh names of a commercial Unity pack ("SM_Prop_...", "SM_Bld_...", "Imported from Unity") in a dull realistic palette. Putting those in a monetised game risks a takedown that blanks the meshes, and they do not match the toy-block style. Everything was deleted from the place again. The owner can overrule this.
23. (rework 2) The hub's back wall is low (15-19 studs) so one scaled-up landmark of every zone stands over it; the invisible barrier does the containing.
24. (rework 2) UI: three button sizes (34 / 44 / 56 at 1280x720), every caption in its own padded box that can only shrink, icon + caption as one centred row, one gloss and lip everywhere, colour means one thing (green afford, slate cannot, blue neutral, pink Robux, red destructive, grey pill = state). These are properties of the helpers in `tools/ui/mp3.py`, checked by `fit_gate.py`, so a screen cannot opt out.
25. (rework 2) Icons: size decides style. Under 30 px the flat ink-outlined glyph (base key); 40 px and up the glossy family (`...Big` keys), all post-processed the same way (shadow removed, ink outline, white keyline). Auto, Savory and Throw failed generation twice and keep the glyph at large size.
26. (rework 2) The mockup renderer cannot be trusted for text fit (it does not have Roblox's font metrics): the fit gate uses a conservative width rule, and every UI change is judged in the game before it is called done.

27. (rework 3) Creator Store models ARE used now, at the owner's explicit request (this reverses decision 22). Chosen for fit: 21 single-mesh Japanese props and buildings (BL00MIE packs 3226580409 and 3226471202), 12 bright simulator props (moberyt1 18411844605), a ramen shop (m1crowave2457 2244003427), a ramen cart (Eqbert 3449117633) and a large cherry tree (xxlKittyIxx 2340650385). Rejected after audit: a 14,000-part shrine, a 4,000-part island, a 9,570-part forest, a 1,100-part ramen shop, and three reuploads that carried scripts. Known risk, told to the owner: the BL00MIE packs carry the mesh names of a commercial Unity pack; if Roblox takes them down those props go blank. Every one is a named template, so replacing one is a one-line change in `zones.json` or `hub_plaza()`.
28. (rework 3) The Food Shop scrolls sideways because the owner asked for it (it was a vertical grid for one round); the client maps the mouse wheel to it.
29. (rework 3) Spacing rule at 1280x720: 8 px between controls in a row, 10 px between stacked rows in a card, 14 px between cards, 12 px card padding; text never under 13 px; a box grows rather than its text shrinking.

## Unproven
- Why the owner's Studio test save reads as new: the version history shows it intact (12.3T yen, 49 heroes) about an hour before the first s3 UI test and blank after. Nothing in the logged steps wipes it; the TEST panel's wipe button is the only code path. Asked the owner; the old version is still in the history.
- A real second player (plots for two, friend luck, gifting, the gift-recipient cycle in the Store).
- Anything on a phone: touch on THROW (release is read from InputEnded), the HUD at phone size in a running game (only the verifier and mockups saw 844x390), frame rate.
- Frame rate was measured on the dev PC only, standing at the plot.
- Rebirth was opened but not performed on the new UI; fuse, place, bench, sell, zone claim and the Store's test purchases were not clicked on the new UI (the remotes are unchanged from section 2).
- Reveal card, announcement banner, toasts stack, server-luck bar and Festival: seen in mockups; in play only the first reveal ran (not photographed).
- Nameplates are sized in studs by code, not at the authored pixel size; readability on a full plot not judged.
- Leaderboard and slot-sign faces (mounted by `WorldUiController` on the anchors): facing not checked in play.
- Hub station prompts other than the daily chest (food cart, gift box, index board, shrine, sell booth) were rewired but not pressed.
- Map: the lanes were not walked end to end by a player; barriers not tested by walking into them; zones 2 to 6 only seen from the air.
- `tools/map/` was copied from `work/map/tools` with its root path changed and three edits (smaller labels, station actions, `max` distance); the generator has not been re-run from the new location.
- Glow: lamp cores, lantern flames, the chest glow and the shrine altar are flat colour (no Neon, no lights): section 4.
- Real Robux purchases, a published server, StreamingEnabled on a slow connection: as in section 2.

- (rework) The wind-up throw animation on the player's character was never caught in a frame (captures are about one per second): it is code-driven (`Fx/ThrowPose.luau`) until section 4 authors real clips.
- (rework) The skip tap, the fast-reveal version, Auto Throw on the new sequence, a Legendary or mutated catch (stamp, burst colour, long reveal), and another player's throw (`ThrowSeen`) were not exercised on client v2.
- (rework) Map v2: zones 2 to 6 and the hub seen from the air only; lanes not walked; barriers not walked into; two built models are not placed (`Prop_pirate_harbor_TreasurePile`, `Prop_ninja_village_RopeBridge`); `Prop_sakura_schoolyard_SchoolBuilding` is 4,338 triangles against a 4,000 class budget (accepted in the spec).
- (rework) Phone: nothing on v2 was tried on a phone; the 3.25M-triangle map rests on streaming.

- (rework 2) Not opened in play on UI v3: Daily Rewards, Settings, Codes, Summon Odds, the training bar, a notice card, a toast. They are built from the same helpers and pass the fit gate.
- (rework 2) Phone: 82 controls are under 44 px physical at 844x390 even with `TouchScale` (list: `fit_gate.py` touch report). A phone layout pass (fewer columns, taller rows) is owed before publish; nothing was tried on a phone.
- (rework 2) The settings gear sits in the top-right corner, where Roblox's player list opens: with the list open the gear may be under it.
- (rework 2) Output shows `ContentId: rbxassetid://203785492 failed: Asset type does not match requested type` three times per session. The id is not in `src/`, `tools/` or the contract: most likely an accessory inside one of the owner's avatars. Harmless so far, not traced.
- (rework 2) A second player, zones 3 to 6 on foot, the skip tap, fast reveal and Auto Throw are still untested (as before).

- (rework 3) Store props: looked at in the hub and at the first lane in play; zones 2 to 6 from the generator's report only. Triangle counts for them are estimates (600 per mesh, 12 per plain part).
- (rework 3) The 831x526 window the owner plays in was checked by the fit gate and the mockup sheet, not in the game (the test capture is 1482x673).

## Debts
- Intervention (logged): the owner imported 12 more avatars and asked for the same rebuild. Healed: 43 heroes baked and in the contract.
- Healed: the 8 premium heroes now have avatars (owner's batch 3); `stages.meshes` is `done`.
- Process note: section 3 ran in the same chat as sections 1 and 2, at the owner's request.
- Fallback: Kiln for every model instead of CC0 packs (decision 2). Nothing owed.
- Stalls: none over 30 minutes. All six workers hit their turn limit once and were resumed.
- Defects found and fixed at the source: text outlines drawn as boxes (roblox-ui emitter); 63 grey parts (installer regex); oversized world labels; HUD size.
- Stray files outside the project that a safety check stopped the workers from deleting: `C:\renders\` (2 PNGs) and `C:\work\models\gear\` (4 PNGs). The owner's to remove.
- Debt for section 4: glow and lights on the kit; the real reveal, banner and toast motion; `Festival in X` countdown has no slot in the HUD tree.
- Debt for section 5: gift-recipient picker in the Store; pass and product display names in config; mint passes and products.

- Interventions (logged), all acted on: the owner's play-test feedback with a recording of the reference game (HUD, alerts, page size, reveal, throw feel, map size and borders, big heroes), then the gate ("small and lame") and the throw point being too close to the base, then "no compromises, keep it extensible".
- Stalls: none over 30 minutes. Defects found in play and fixed at the source: text outlines as boxes (skill emitter); page content hidden behind `BodyArt` and other equal-ZIndex siblings (Rojo does not keep sibling order: explicit `z` everywhere now); stray empty reveal pill; luck label under the letterbox; HUD inset on wide windows; final-beat camera hiding the hero.
- Debt for section 4: authored throw, catch and idle clips (replace `Fx/ThrowPose.luau`), real VFX for trail, landing, burst and auras (replace `Fx/Particles.luau`), every sound; reveal beats need their ticks and stings.
- Debt for a later pass: place the treasure pile and rope bridge; re-run the generator end to end from `tools/map/`; trim the school building under budget.

- Intervention (logged), acted on: facing, UI buttons, Creator Store props (rework 2 above).
- Stalls: none over 30 minutes. Found in play and fixed at the source: sign faces after the turn; two trees hiding the leaderboards; hint pill 439 px wide; gear over the Store's close button; gift chip over its caption; "2X" dropped from the double button; BEST VALUE over "x10"; odds counter under the letterbox; food picture at 40% of its tile; notices raised under an open page.
- Debt for section 5: the phone layout pass; move the gear if the player list covers it; trace the content warning.

- Intervention (logged), acted on: touching buttons, horizontal food shop, small HUD text, use Creator Store assets (rework 3 above).
- Found in play and fixed at the source this round: store models arrive at arbitrary angles (the installer squares them up and sets the wide side to the front); the prover's hub variety budget (40 unique models) and one per-model triangle class, met by trimming the hub mix and one stated exception.

## Ledger

Initialised once in section 1. Never run `init` again.

```bash
python ~/.claude/skills/roblox-build-orchestrator/scripts/run_log.py counter --dir "D:\Roblox Studio Games\Throw food for Anime\build-runs" --run "ThrowFoodForAnime"
```

## Place
Published place opened from Roblox with Team Create on. Universe 10776373502, place 106586376894468. `section-2` = place version 57. The place now also holds `Workspace.Map`, the 66 model templates and 43 hero templates. Saved at the first section close as place version 96 (2026-11-14, unlabelled); saved after rework 2 as version 108 and after rework 3 as place version 115 (build `s3-v3-03`), and after rework 4 as place version 121 (2026-11-15, unlabelled, build `s3-v3-04`). The approved snapshot (commit, tag `section-3`, `save_place` with notes "Section 3 approved (git section-3)") happens on approval.

## Rules

1. ONE SECTION PER SESSION. Finish this section's whole scope, then stop. Inside a section the skill's 'the run does not stop' rule applies in full; `section.py close N` passing is the only place you stop. Never start the next section's work, even with budget left.
2. STAY INSIDE CLAUDE CODE AND ROBLOX STUDIO. Work through the skills, MCPs and CLIs. No browser-driving tools (browser pane, Chrome), no web-GUI generators. WebSearch and WebFetch inside Claude Code are fine. Screen access is for Roblox Studio only.
3. NOTHING IN STUDIO BY THE USER'S HAND. Never ask the user to place, type, edit or configure anything in Studio, and never ask them to leave Claude Code or Studio. You may ask for: pressing Play or Stop, clicking Publish, approving a tool call, restarting a stuck MCP, or something purely mechanical no API or screen action of yours can reach.
4. LOG INTERVENTIONS AS THEY HAPPEN (run_log.py event --kind intervention): the user writes or edits code, makes a design or art decision (a genre named in the section 1 prompt is the brief, not an intervention), chooses between options, tells you WHAT is wrong rather than THAT something is wrong, or does something in Studio by hand. So never offer options: decide, and say why.
5. TIER 2 FIRST, fallback pre-authorised: take it without asking and log it as a fallback. 30-minute stall rule: one problem eats 30 minutes, fall back, log it, keep moving.
6. EVERY SESSION: ask for Roblox Studio screen access first (a grant does not survive a cleared session). 'Continue with the development of the <genre> game' means `section.py resume --game "<genre>"`: it finds the game and says which section is next.
7. THE LEDGER IS INITIALISED ONCE, in section 1. Every later call passes the --dir and --run recorded in HANDOFF.md. Bracket each ledger stage with start/end.
8. BEFORE CLOSING: save the place, write HANDOFF.md with `section.py handoff N`, replace every placeholder, run `section.py close N`. Then stop and ask the user to approve. Approval is free. If the user asks for changes, make them, log an intervention if they named what was wrong, update HANDOFF.md and close again. When the user approves ("approved", "yes that's all good"), run `section.py approve N` and say it is safe to clear the chat. Do not start the next section.

## Next section: first step
Section 4: Motion and sound (7 animation, 8 vfx, 9 sfx).
Section 4: Motion and sound (7 animation, 8 vfx, 9 sfx). Read `design/plan/06-motion-vfx-sound.md`, `design/animations.json`, `design/vfx.json`, `design/sfx.json`, then:

```bash
python tools/gate.py
python ~/.claude/skills/roblox-build-orchestrator/scripts/run_log.py start --dir "D:\Roblox Studio Games\Throw food for Anime\build-runs" --run "ThrowFoodForAnime" --stage animation
```

Brief any model or animation worker with the batch routine from the start (4 to 6 items per batch, one contact sheet per batch, manifest written after every batch): each worker in section 3 used its first 40 turns on tooling and one or two items.

## Earlier handoffs

- `D:\Roblox Studio Games\Throw food for Anime\design\handoffs\HANDOFF-section-1.md`
- `D:\Roblox Studio Games\Throw food for Anime\design\handoffs\HANDOFF-section-2.md`
