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
   Tag `section-2` = place version 57. Tag `section-3` = place version 121. Tag `section-4` = place version 271. Tag `section-5` = place version 284. Tag `section-6` = place version 284 too (published, private; section 6 changed no place content).
   Tag `economy-v2` = place version 903 (plan 12 phases A to F, owner-approved 2026-11-26; NOT published).

## Where the game's pieces live (since section 2)

- Code: `src/` (16 server services, 15 client controllers + `src/client/Ui/` (Screens, Pages), 16 pure Core modules with specs in `tests/`).
  `src/shared/Config/GameConfig.luau` is GENERATED from `design/game.json`: edit the JSON, then
  `python ~/.claude/skills/create-roblox-game/scripts/gen_config.py --dir .`. Pacing gate:
  `python tools/economy/econ_v2.py check` (the old `balance_sim.py` is retired). Server-only tunables (promo codes) live in `server_config`
  in the same JSON: `python tools/gen_server_config.py` writes `src/server/Config/ServerConfig.luau`.
  Never put a code in `config` (it is sent to every client). Every gate at once: `python tools/gate.py`.
- Hero templates: `ReplicatedStorage.Assets.Characters.Char_<id>` (in the place, not in Rojo).
  Rebuilt from `ServerStorage.CharacterSources.R15_Final` by `tools/studio/bake_characters.luau`.
  The user's imports are archived in `ServerStorage.CharacterSources.R6_Originals` (31) and
  `.Originals_Batch2` (12) and `.Originals_Batch3` (16): never delete. New avatars: `tools/studio/build_r15.luau` rebuilds them to
  the standard rig, `python tools/studio/run_bake.py` bakes the whole roster (180 heroes: 172 lane + 8 premium, ALL in `config.Characters` / `PremiumCharacters` since economy v2, 2026-11-26).
  Roster map: `design/characters/roster.json`; rules and traps: `design/characters/README.md`.
- The map is `Workspace.Map` in the place: **hub v2 since 2026-11-21** (about 12,800 parts): FIVE bases (since
  2026-11-22, `tools/studio/base_layout.luau`, rerunnable, reads the synced config: a config edit + a rerun re-lays them)
  65 x 65 square decks with an even 6-stud border round 6 rows of 7 pedestals (`PedestalSpacingZ` 9.6 makes the grid
  square), 92 apart (x -184..184), the spawn and slot sign on the walk in front of the deck, one training court each side
  of the walk, no bushes along the sides (archived in `MapArchive.BaseLayout_v1`), ONE
  shared food cart (`Hub.FoodCart`, before the RAMEN ALLEY sign) and squad booth (`Hub.SellBooth`, before HALL OF LEGENDS)
  since `tools/studio/base_cleanup.luau` (owner: one per base was unnecessary; it also took away the bases' small torii,
  koi windsocks, lantern strings and the props in their back gates, all in `MapArchive.BaseDressing_v1`), a plaza in five districts, store models in `Map.HubV2`. It was made by
  `tools/studio/rework_hub_v2.luau` (rebuilds a copy `Workspace.MapV2` from the old map) + `tools/studio/swap_hub_v2.luau`
  (one-off: installs it, re-lays the old zones for five tracks). The old 6-base map is archived in
  `ServerStorage.MapArchive.Map_v1_6lanes`: never delete. **Do NOT run `python tools/map/build_in_studio.py`**: the old
  generator (`design/map.json` + `tools/map/`) still describes the 6-base map and would overwrite the hub. There is ONE lane
  (`tools/studio/single_lane.luau`, one-off), centred on x = 0: since 2026-11-22 (`tools/studio/lane_slim.luau`, one-off,
  attribute `LaneSlim` 60) three tracks, and since 2026-11-23 (`tools/studio/lane_two.luau`, one-off, attribute
  `LaneTwo` 28; design/plan/11 phase 3) 144 wide (x +-72) with TWO tracks at x -28 and 28. Bases 1-2 share the left
  track, 4-5 the right (each on its own half), base 3 throws down the seam: config `World.PlotTrack` {1,1,1.5,2,2},
  `PlotTrackSide` {-1,1,0,-1,1}, `TrackSideOffset` 12, so the stage spots and landings are x -40, -16, 0, 16, 40
  (+- `LandingJitterX` 6) (`World.trackX`, `World.laneX`). The zones' sides were REBUILT 28 in (side_lib's `SHIFT`, below);
  the torii, lane border, finale and the ledge's parapets were rebuilt narrower by their own scripts. The lane lies 48 studs BELOW the hub (`World.LaneY` -48: 24 from `lane_ledge.luau`, 24 more from `tools/studio/lane_deeper.luau`, both one-off) from z 160 (`World.LaneStartZ`;
  `tools/studio/lane_ledge.luau`, one-off): a paved funnel forecourt runs from the bases to a ledge, one 247-tall gate
  stands at the start of every zone, and anything placed in the lane uses `LaneY`, not `GroundY`. Everyone throws from the middle: since 2026-11-23 there is NO pad at the bases (archived in
  `MapArchive.ThrowPads_v1`); the player walks to their own coloured circle on `Map.HubV2.ThrowStage` (`World.throwPad`
  = `World.throwSpot`, `World.StageZ` 148) and is held there; letting go sets them down on the lawn behind the stage.
  `tools/studio/throw_spots.luau` (rerunnable) places the spots from config and the hidden "YOUR SPOT" signs
  (`ThrowStage.SpotHint<i>`); ThrowController shows only the player's own. The zone CONTENT is still the old six zones; the anime zones replace them 3 at a time (`design/plan/09-single-lane-rework.md`,
  `design/zones/anime_zones.json`). `Blockout.luau` only builds a grey fallback when the place has no `Workspace.Map`.
- Creator Store models (free, the owner's request): cleaned sources in `ServerStorage.StoreAssets` (61, never delete; buildings assembled by `tools/studio/assemble_store_buildings.luau`; tags `design/store_assets.json` feed the map generator's pools) ->
  `python tools/studio/install_store_assets.py` -> `ReplicatedStorage.Assets.Kit.Prop_store_<Name>` and
  `assets/meshes/manifest-store.json`. Take a new one in through a quarantine folder: strip every script, GUI, sound,
  constraint and effect, count its parts (reject thousands), look at it, then add it to `StoreAssets`.
- Models: `design/kit.json` (art bible + sizes) -> Kiln sources `assets/meshes/src/` -> `tools/publish_meshes.py`
  (upload) -> `tools/studio/install_models.py` (templates in `ReplicatedStorage.Assets.{Kit,Gear,Foods}`) ->
  `tools/merge_manifest.py`. Parts are coloured from the hex at the end of their name.
- UI v3: one button system (`tools/ui/mp3.py`, screens `tools/ui/screens_v3.py`), checked by `tools/ui/fit_gate.py`; client side
  `Screens.setButtonState` and `Theme.BUTTON`. Icons v4: ONE rendered family for base and `...Big` keys (`tools/ui/icons_v4_shapes.py` -> `icons_v4_blender.py`
  (Blender 4.5) -> `icons_v4.py`, one thin ink outline, never a white keyline; gate `tools/ui/icon_fit_check.py`);
  `assets/ui/ids_icons_v4.json` is read last and overrides the older maps. `icon_post.py` is retired.
  A UI change is only done when it has been looked at IN THE GAME (the mockups do not have Roblox's font metrics).
- UI: specs `design/ui/` -> `python tools/ui/build_ui.py` -> `src/ui/*.model.json` (`ReplicatedStorage.Ui`) and
  `design/ui/BINDINGS.md`; icon ids: `python tools/gen_icons.py` -> `src/shared/Config/Icons.luau` (GENERATED).
  Dead-label gate: `python ~/.claude/skills/roblox-ui/scripts/verify_labels.py --ui src/ui --client src/client`.
- Motion and sound (section 4): clips `assets/animations/` -> `ReplicatedStorage.Assets.Anims` + uploaded ids -> `python tools/gen_anim_ids.py`
  (`src/shared/Config/Animations.luau`, GENERATED); effects `assets/vfx/` -> `python assets/vfx/tools/pack_all.py` -> run
  `work/vfx/build_templates.luau` in Studio -> `ReplicatedStorage.Assets.Vfx`; sounds `assets/sfx/manifest.json` -> roblox-sfx
  `emit_bank.py` -> `src/shared/Config/SoundBank.luau`. Play them only through `Fx/Motion`, `Fx/Vfx`, `SoundController`.
- Hero auras: the owner's imported packs are archived in `ServerStorage.ImportedVfx` (`HandPicked` = the owner's picks,
  `AuraPacksAll`, `ParticlePacks`; never delete, nothing in them runs). `design/auras.json` (who wears what, tiers, caps,
  footprint, runtime budget) -> `python tools/gen_auras.py` (`src/shared/Config/Auras.luau` + `work/auras/build.luau`, run
  that in Studio edit mode -> `ReplicatedStorage.Assets.Auras`); runtime `src/client/Fx/HeroAura.luau` via `Fx/Vfx` (nearest
  heroes only, phones get the low-detail budget). Clock / purple flare / landing impact: `tools/studio/build_fx_imports.luau`
  -> `ReplicatedStorage.Assets.FxImported`, played by `Fx/ImportedFx`.
- APPROVED AURAS IN THE GAME (plan 12 phase E, 2026-11-26): who wears what is the owner's assignment on the preview
  yard (`tools/aura_assign.py`, `design/aura_assignments.json`). `python tools/aura_to_game.py` (Studio edit mode, yard
  built; `--only=<ids>` for some) keeps the 25 hand-built auras and captures every other stand as it stands
  (`tools/studio/export_preview_auras.luau`) into `Assets.Auras.H_<heroId>`, then rewrites `design/auras.json` (130 hero
  lines; never hand-edit an `H_` line; `by_rarity` is EMPTY on purpose: Common and Uncommon wear none) and runs
  gen_auras.py. After the owner changes an aura on the yard: rerun it for that hero, then judge it (next line).
- JUDGE AN AURA WHERE IT IS WORN, AT MAXIMUM GRAPHICS. Studio's edit view draws about 40% of an emitter's rate and
  little bloom; a player at max graphics gets all of it (Gojo's approved blue sphere was a white ball in play).
  `python tools/aura_judge.py row <n>` (or `show <ids>`, `--raw`, `id=0.3`, `clear`) stands heroes on Plot5 with the
  game's own aura code; set `settings().Rendering.EditQualityLevel` to Level21 to look and back to Automatic after.
  An aura that washes out gets a mark in `design/auras.json` "hot" (hero id -> share of its rate it may be drawn at;
  0.4 = the approved density) -> `Auras.Hot`; `Core/AuraDensity` + `Fx/Vfx` thin it on high graphics only. White-clothed
  heroes glare at max graphics with no aura at all: that is `MapBloom` on white cloth, not an aura fault.
- Aura showcase (owner's view of who wears what): `python tools/studio/aura_showcase.py build` -> `Workspace.AuraShowcase`
  (dev only, deleted by the server on start). The owner renames a dummy in `AuraShowcase.Auras` to a hero's name; then
  `python tools/studio/aura_showcase.py sync` records it in `design/auras.json` and rebuilds.
- Caught heroes are carried (Player attr `Carrying`, `PlotService:SetCarry`, client `Controllers/CarryController`) and set
  on a pedestal with E; the hero is saved in its slot at the catch, so nothing is lost if never placed (150 s timeout).
- Robux purchases: server `StoreService:ShowPurchase` -> remote `Purchased` -> client `Ui/Celebrate` (closes the Store, waits
  for Roblox's purchase dialog to close) + `Ui/CardReveal` (tap-to-reveal card, one tier per tap; a single item then slides
  aside for the PerkList details panel). Card art: `tools/ui/cards_art.py` -> `assets/ui/cards/` + `assets/ui/ids_cards.json`
  (`--upload-only`, then `tools/gen_icons.py`). Screens are now `tools/ui/screens_v50.py` (imported by `build_ui.py`).
- Gear and slot purchases go through a client confirmation (`Controllers/UpgradeController`, `HudController:Confirm`); prompts never spend. Prompts are drawn by `Controllers/PromptController` (Style Custom).
- The throw spot (the old pad's code and names) is held by the server (`ThrowService:SetPad`, remote `ThrowPad`), like training.
- Training: two courts per base, each showing one training GROUND (see TRAINING GROUNDS below; the old stations and
  gear models are gone since plan 13 phase D). Power per rep is the gear's, not the ground's; the server snaps and locks
  the trainee and judges every beat (`TrainTap`); client `Controllers/TrainingController`. The throw pad locks the player
  too (`ThrowController:_lock`, exit by the meter's X / Backspace); one invisible wall (`Map.Barriers.LaneBlock`) closes
  the lane mouth behind the throw stage.
- Studio sessions use their own stores (`Profiles_Dev`, `LB_*_Dev`); test commands are the TEST menu.
- Hub v2 store models (cherry trees, dragon, summoning circle, horned shrine, torii, stone lantern, pagoda) are kept clean in
  `ServerStorage.StoreAssets.HubV2` (never delete). Servers hold 5 players (`config.Server.MaxPlayers`); the place's own
  max-players setting in Game Settings must be set to 5 by the owner before the next publish.

- LOBBY WALL (2026-11-22, owner: the map felt too big, "remove the outer part of the lobby completely", little space
  between the outer bases and the wall): `tools/studio/lobby_wall.luau` (rerunnable, run after base_layout.luau and lane_slim.luau) builds
  `Map.Hub.Walls.Lobby`: ONE wall in zone 1's great-wall dress (top 44, foot down to -44 in the sea), inner faces x +-248
  and z -116, outer x +-262 and z -130: the MAP'S END (the back was -156/-170 until the hub moved 40 forward, below). The sides run straight on into zone 1's great wall (z 192; between the wall and zone 1's gate
  tower a lawn corner): one line from the back corner to the lane. Keeps at the corners, z -40, z 86 and x +-120 on the back; stone lanterns on
  the lawn strip beside the outer bases. Outside: the sea (water to -4 on a sand bed) out to x 560 and z -660. The back
  districts moved in with it (attribute `ShiftX` on each district folder: Hall of Legends and Ramen Alley 90, Rewards and
  Rankings 14, with their decks, statues, stations and boards). Zone 1's great wall (z 189..203) and turret got a stone
  foot to the sea bed. The walled town (`Scenery.LobbyTown`), its town wall, the old lobby and entrance walls and the side
  lawns' props are in `MapArchive.LobbyTown_v1` (never delete); its builder is retired to
  `tools/studio/retired/lobby_town_v1.luau` (do NOT run it: it would rebuild the town). The `LedgeParapet`s (x 76..129,
  top 15, a `LedgePost` at each end; lobby_wall.luau's `STAGE_HALF` 72 and `TOWER_IN` 132) close the lawn beside the throw stage.
  zone_01_naruto.luau restyles HubV2 funnel walls only if they exist, so a rerun of it is safe.
- LANE BORDER (2026-11-22, owner: the lane's sides looked "weird", "keep the map minimal"): `tools/studio/lane_border.luau`
  (rerunnable; run AFTER lobby_wall.luau and after any zone builder) builds `Map.Scenery.LaneBorder`: the town's outer
  wall (same dress, top 52) down both sides of the lane at x +-306..320 (`SLIM` 60 in the script; +-366..380 before) from zone 1's turret (z 213) to an end wall
  behind the finale (z 6380..6394), a keep at every zone gate (z 205 + 360 k); the end wall and its corners are finale.luau's. Outside it there
  is no land: terrain from x 372 out is cleared and the sea laid (sand bed, water to -4) to x 548; inside the end walls
  the lane ends in water at zone 17's level (-49.5). The zone builders only write x 160..368, so a zone rebuild keeps
  this. Zones' content ends by x 360; the old hill props outside went to `ServerStorage.MapArchive.LaneHills_v1`. Mirrored about x 0, placed by footprint with a claim registry that refuses overlaps; the run ends
  with a built-clash check. Old walls, `HubBackdrop` and hill props: `ServerStorage.MapArchive.Lobby_v1` (never delete).
  `Zone14_Bleach.Pine` is a POTTED pine (courtyards only, never on a hill); `HubV2.DojoGate` (torii) and `HubV2.SakuraSoft`
  have their pivots mid-height (`make` stands any non-TrueSize template on its feet).
- Anime zones (since 2026-11-22): one builder per zone in `tools/studio/zones/`, run in Studio edit mode and safe to run
  again. `zone_01_naruto.luau` = zone 1 "Hidden Leaf Village": it rebuilds `Map.Scenery.Zone_sakura_schoolyard` (643 parts:
  a BUILT entrance of great wall + two gate keeps round the torii, the gate leaves on their own posts, the Hokage Rock,
  the village), the terrain canyon walls either side of z 160..520 (56 and 80 studs above the lobby), restyles that zone's
  floor kit and gate, and the lobby's two funnel walls. Its templates live in `ServerStorage.StoreAssets.Zone01_Naruto`
  (never delete): buildings from `harvest_naruto.luau` + `harvest_naruto_store.luau` (quarantined store packs); the stone
  heads, trees, bush, gate keep and rock outcrop are Studio `generate_mesh` results. The old zone-1 dressing is in
  `ServerStorage.MapArchive.Zone1_sakura_schoolyard_v1` (never delete). Since economy v2 (2026-11-26) the game's zone DATA is the 17 anime zones too (the config ids are still the old map ids).
  `zone_02_demon_slayer.luau` = zone 2 "Demon Slayer Corps" (z 520..880, config id still `pirate_harbor`): checkered
  floor, the Mugen Train, a Taisho mansion, wisteria; templates in `ServerStorage.StoreAssets.Zone02_DemonSlayer` (never
  delete, all `generate_mesh`), old dressing in `MapArchive.Zone2_pirate_harbor_v1`. A zone's walls JOIN the previous
  zone's at its start (its `PREV` table holds the neighbour's numbers) and fall to the lobby's level at its far end until
  the next zone is built: when zone N+1 lands, remove zone N's end fall and rerun zone N first.
  `zone_03_one_piece.luau` = zone 3 "Grand Line" (z 880..1240, config id still `ninja_village`): the lane as the sea,
  real terrain WATER either side between quays and cliffs, ships, piers, a town on stilts; rewritten on `zone_lib` in the
  rework below. Templates in `StoreAssets.Zone03_OnePiece`, old dressing in `MapArchive.Zone3_ninja_village_v1`. Owner's bar for a zone (2026-11-22): the entrance must be built
  architecture, never terrain mounds; walls must not tower over the lobby; no lollipop trees.
- HUB FORWARD (2026-11-23, owner: less space between the bases and the zone entrance, not congested): the whole hub
  (bases, yards, courts, lanterns, sakura, spawn, plaza, districts, sanctuary, statues, dragon, hub barrier, its terrain)
  is 40 studs closer to the lane; the stage, ledge and lane did not move. `tools/studio/hub_forward.luau` (rerunnable:
  each piece remembers where it left it, attribute `HubZAt`; the terrain copy runs once, attribute `HubForwardTerrain`).
  plaza_districts.luau and sanctuary.luau still build at their OLD fixed positions: after rerunning either, rerun
  lobby_wall.luau (district x moves) and then hub_forward.luau. Config's hub z numbers (PlotBackZ -4, PlotFrontZ 61,
  PedestalCenterZ 28.5, SlotSignZ 66, CourtZ 85, stations Z 80) moved with it. Bases z -4..61, courts 74..96, stage 135.
- PLAZA DISTRICTS (2026-11-22, owner: stalls, gifts, boards "look ass", make them flashy and professional):
  `tools/studio/plaza_districts.luau` (rerunnable) builds `Map.Hub.Districts`: a lit gateway per district (top 30, sign in
  the district's colour) and RAMEN ALLEY (the food cart as a yatai: wheels, steaming pot, noren, striped awning; noodle
  shop, sweet shop, market stall, vending row, lantern strings), HALL OF LEGENDS (hall front with 英雄殿, the six hub
  statues on lit pedestals with gold name plates, the squad booth as a hero registry with glowing cards), REWARDS (daily
  chest = zone 3's chest on a lit altar with a light beam and coins, a gift stack with confetti, the hero index as a
  framed board of glowing cards, star-ball pedestals), RANKINGS (boards raised to y 13 in black/gold frames with crests,
  the trophy on the middle frame, a low podium, red carpet, searchlights). Station anchors (Hub.FoodCart, SellBooth,
  DailyChest, GiftBox, IndexBoard) were MOVED into the new pieces with their prompts; each Title is now a coloured pill
  (label still named Text). Leaderboard anchors keep names/sizes/faces. Old props and signs: `MapArchive.Plaza_v1`.
- SANCTUARY (2026-11-22, owner: make the summon plaza "even better"): `tools/studio/sanctuary.luau` (rerunnable) builds
  `Map.Hub.Sanctuary` round the untouched prompt anchor `Hub.Shrine` (summon prompt, reach raised to 16, title lifted
  to +28): a gold-rimmed stone dais (d 50, top 0.2, level with HubSpawn's edge), a magic circle of gold/cyan light with a
  hexagram, runes and rising motes, an ornate pavilion (scaled 1.35: red pillars, corner-wedge pyramid roof with gold hips,
  a floating violet orb in halos), four pylons with light orbs, two burning braziers by the wish dragon. The old rings,
  decal, benches, two lanterns and kit shrine: `MapArchive.Sanctuary_v1`.
- FINALE (2026-11-22, owner: make the lane's end anime and professional; the reference game has no ending, its lane just
  grows): `tools/studio/finale.luau` (rerunnable; run after lane_border.luau) rebuilds `Map.Scenery.Finale` as THE SEALED
  GATE: a pier over the end bay from the lane's end (z 6278) with a small torii and glowing stone lanterns, two zone-17
  guardian dragons on plinths, and the END ITSELF (owner: "bigger and majestic"): a two-storey end wall (stone foot,
  plaster storeys with lattice windows, two tile roofs, top ~106, red 龍 banners), four towers to y 122 with large keeps,
  and the sealed gate (doors 128 x 111, black and gold, chained in an X behind a glowing seal with the kanji 封, a "TO BE
  CONTINUED" arrow banner, a two-tier gate roof). Behind it a layered light pillar (core + two faint sheaths, a ray
  burst on the water, five tilted halo rings, rising spark particles) with the hub's golden wish dragon coiled round it
  (the StoreAssets copy is Glass: the script recolours it gold). lane_border.luau no longer builds the end wall or its
  corner keeps. Its corner towers stand on the border (`CORNER_X` 185), the end wall 104..165; the guardian dragons at x +-47 in the bay. New zones "unseal" it. Old finale props: `MapArchive.Finale_v1`.
- ZONE GATES (2026-11-22, owner: the old torii mesh was "too big and fat", no detail): `tools/studio/zone_gates.luau`
  (rerunnable) builds a part-made myojin torii (`Torii`) in every `Map.Lanes.Zone_*.Gate_*` model: slim vermilion pillars
  at x +-87 (`PX`; 115 with three tracks, 175 with five: just outside the lane's kerb; owner: it must span the lane, not
  beyond) on black bases, a stone komainu on a pedestal beside each (x +-114, z gate-18), gold rings, nuki/shimaki/curved kasagi with gold
  caps, a framed plaque front and back, a sagging shimenawa with shide, two glowing lanterns; top about y 125 (was 198).
  Parts named `Accent` (plaque frame, lantern bands) and the plaque's TextLabel keep the zone builders' recolour/retitle
  working. Deleting a gate model's old mesh reset its pivot: the script reads and restores `WorldPivot`. Old meshes:
  `MapArchive.ZoneGates_v1`.
- ALL 17 ZONES ARE BUILT (2026-11-22), the lane runs z 160..6280. `tools/studio/lane_extend.luau` (one-off, run) cloned
  zone 6's floor kit eleven times; `tools/studio/lane_thresholds.luau` (rerunnable) lays the stone slot between kits.
  **SLIM ZONES (phase 3 of design/plan/10-slim-map.md, one zone at a time):** a rewritten zone's file starts with
  `-- LIB: side_lib`; `run_zone.py build <n>` then joins `tools/studio/zones/side_lib.luau` (not zone_lib) and runs one
  pass. side_lib's table `P` IS the cross-section (change a number, rebuild the slim zones), written in the
  THREE-track frame (lane edge 100) like every zone file: kerb x 100..104, terrace y -46 to x 172 (street 104..116,
  buildings facing the lane), a battered stone revetment 168..178 up to the shelf y -14 (178..206), the border wall
  206..220. **`P.SHIFT` 28 (two tracks, 2026-11-23): side_lib moves everything a zone builds 28 toward the lane** (terrain
  in `fill`, parts in `markSlim`; whatever stands inside the old lane stays, particle boxes are cut to the lane), so in
  the WORLD: kerb 72..76, terrace to 144, revetment 140..150, shelf 150..178, border wall 178..192 (lane_border.luau,
  top 26), the sea outside. A zone file's x numbers are 28 off the world's; never write `workspace.Terrain` in a zone
  file (use `fill`, which shifts). Zone 1's great wall reaches the lobby wall by `LOBBY_OUT = 262 + P.SHIFT`. Ground: thin flat terrain lawn;
  streets, kerbs, walls are parts. Placement by `front`/`put` with a claim registry (refusals and anything in the lane
  are reported). A slim zone sets attributes SlimZ0/SlimZ1/SlimWall* on its Scenery folder; lane_border.luau reads them,
  stands the wall on the zone's edge there and steps out to the old line (a cross wall) where it meets an old zone.
  After a slim zone: run lane_border.luau, and for zone 1 lobby_wall.luau. DONE: zone 1 (v2, 2026-11-22; v1 archived in
  `MapArchive.Zone1_v1_canyon`), zone 2 (v2: train with a station canopy, estate with wisteria trellises, farmhouses,
  shrines and bamboo on the shelves; v1 in `MapArchive.Zone2_v1_canyon`), zone 3 (v2: the terrace is a HARBOUR of real
  water behind a stone quay, ships at 1.45-1.5 scale, piers, a town on a deck, waterfalls; v1 in `MapArchive.Zone3_v1_canyon`,
  its zone_lib builder in `tools/studio/retired/`), zone 4 (v2: campus +X, city -X, towers and billboards on the shelves;
  everything resized to the terrace and under the wall), zone 5 (v2: touchline and two grandstands against the
  revetment, end plazas with the trophy and the striker, name boards and floodlights on the shelves), zone 6 (v2: the
  capital on cobbles +X, the village by a dirt road -X, floating grimoires, cottages on the shelves), zone 7 (v2: the
  exam +X with the testing gate across its end, the wild -X with the world tree and a pond; a light forest floor),
  zone 8 (v2: ice-blue Glacier walls, the starting town +X with the portal across its end, the monsters -X), zone 9
  (v2: the revetment IS the Wall: masonry, merlons, cannons and banners on the shelf; the Colossus over a -X bastion).
  Zone 10 (v2: a Tokyo street each side, road with parked cars, poles and wires; the chainsaw and the dog on plinths).
  Zone 11 (v2: an Italian town on cobbles, limestone walls with terracotta caps, the menacing katakana over the shelves).
  Zone 12 (v2: chessboard terraces, basalt walls with neon ember seams, a back rank of giant pieces -X, the throne +X).
  Zone 13 (v2: the standing city +X, the ghost town -X with the meteor, the crab monster, wrecks and rubble).
  Zone 14 (v2: the court +X, the outer town -X, the white city wall with an orange cap down both shelves, butterflies).
  Zone 15 (v2: purple basalt walls with neon rune seams, dark flagstones with rune lines, the hunters +X, the dungeon -X).
  Zone 16 (v2: the Shibuya crossing +X, the sorcerers -X, roads with zebra crossings and signals, neon screens).
  Zone 17 (v2, the last: a harbour with islands like zone 3, the arena, lookout and star balls +X, the corporation, dragon
  and fighter -X; its sides run on past the lane's end to the end wall, opening into the finale's bay). ALL 17 ZONES ARE SLIM
  (phase 3 complete, place version 683); since two tracks (plan 11 phase 3, place version 690) the border wall stands
  at x +-178..192 the whole way.
  After a Studio restart generated meshes load late: a capture can show them grey or missing; wait and look again. The retired zone_lib builders of rebuilt zones are in
  `tools/studio/retired/` (content and numbers to port). side_lib also has deck, afloat, sheetFall, floorKit, words, sign, paint, fence, scatter, and revetment
  options buttress (spacing) and wet (waterline). zone_lib (below) is now used by no zone; its numbers (x 160..368, terraces, gate
  pillars) are the OLD layout and the place is 60 in.
  Zones 3 to 17 share `tools/studio/zones/zone_lib.luau` (terrain profile, placement helpers, `floor{}`, `words`) and are
  driven by `python tools/studio/zones/run_zone.py`: `build <n> [--no-terrain]`, `store <Folder> "Key=prompt prefix" ...`
  (squares the generated models lying in Workspace and files them under `StoreAssets.<Folder>` with `TrueSize`),
  `inspect <Folder>` (mesh numbers), `check <map id>` (scripts), `audit <map id>` (overlaps, ground faults, anything in
  the lane), `look x y z tx ty tz` (parks the camera for a screenshot). Each `zone_NN_*.luau` is a `begin{}` spec
  (its `prev` table = the previous zone's `now`), placements, `floor{}`, `return finish()`; only zone 17 has `fall`.
  Map ids: 4 samurai_castle (Hero Academy), 5 hero_city (Blue Lock), 6 realm_of_legends (Clover Kingdom), 7 hunter_exam,
  8 isekai_crossroads, 9 wall_maria, 10 public_safety, 11 bizarre_streets, 12 shadow_council, 13 city_z, 14 soul_society,
  15 gate_of_shadows, 16 shibuya, 17 planet_of_gods (real water, like zone 3). Templates: `StoreAssets.Zone04_MHA` ..
  `Zone17_DragonBall` (never delete, all `generate_mesh`); old dressing of zones 4-6 in `MapArchive.Zone<n>_<id>_v1`.
  Terrain material colours are GLOBAL and every zone owns some: before recolouring one, grep the zone files for it.
  Since economy v2 (2026-11-26) all 17 are in `config.Zones` and every hero is catchable; zones past the player's rebirth
  band are SEALED (see ECONOMY V2 below). Their gate plaques and seal visuals still need phase D of plan 12.
- ZONE REWORK (2026-11-22): the owner rejected the first, fast build of zones 3-17 ("too vague without any details",
  "poorly made", buildings "not even placed properly") and ordered them redone ONE BY ONE, quality over speed. Zones 3 to
  17 were each rewritten: 12 to 20 unique generated models, paved streets and plazas, a set piece on a plinth facing the
  throw stage at each terrace's far end, dressed ledges and rims, and `audit` at 0 overlaps / 0 ground faults / 0 in the
  lane. The standard, the per-zone log and every lesson are in `design/zones/REWORK_PROGRESS.md`: READ IT before touching
  a zone. Zones 1 and 2 are the owner-approved bar and were not touched. Rules that came out of it:
  the gates' pillars stand IN the terraces (x 171..236, 35 either side of the gate's pivot, 45 studs into its zone), so a
  terrace is usable from Z0+82 to Z1+10; place with `place` / `try` / `row{}` / `scatter{}` / `plant` (they claim ground and
  report crossings), never by hand; a terrace's real ground is `TERRACE` = LY + 2 (-46), not LY; `pave` IS the ground (it
  cuts the terrain away under its slab), so rebuild WITH terrain after changing a paving layout; `floor{}` lays a kerbstone
  down the lane's edge of every non-sea zone; wait for `store` to print a model's real size before writing a row.

- ECONOMY V2 (plan `design/plan/12-gameplay-economy-v2.md`, owner approved 2026-11-26; build log in its section 15).
  Numbers: design inputs at the top of `tools/economy/econ_v2.py` -> `gen` -> `apply` (writes zones, rarities, gear,
  foods, slots, rebirths, pacing into `design/game.json`) -> `python tools/gen_characters.py` (heroes from
  `design/characters/lineup.json`: THE truth for a hero's zone and rarity) -> gen_config.py -> `python tools/gate.py`.
  Rules (pure, `src/shared/Core`): Roll = "1 in N" bands rarest first, luck divides N, the score on the card is BASE odds;
  Luck = food x depth x perfect x (1 + added free bonuses) x passes x server x lucky, capped at `Luck.Max`; Throw = the
  player AIMS at a zone (5th argument of ThrowRequest), the meter decides depth, zones past `RebirthReq` are sealed;
  Progress = gear / food / slots unlock by `profile.bestZone`, rebirth resets Power and Yen ONLY, training x4 below
  `profile.powerRecord`. Saves: `Profiles_v2` / `Profiles_Dev_v2`. Test panel: "Reach a zone", "Ready + rebirth".
  UI layer `tools/ui/screens_v51.py` (aim arrows, ODDS button, the ThrowOdds page). World: gate plaques by
  `tools/studio/zone_gate_plaques.luau` (rerun after a gate's Power moves); the SEAL on a closed zone is a
  client-local clone of `ReplicatedStorage.Assets.World.ZoneSeal` (`tools/studio/zone_seal.luau`,
  `Controllers/SealController`), never part of the map. Index zone pictures: `tools/ui/zone_shots.py`.
  Phases A to F are done (F = the playtest through all ten rebirths, log in section 15) and snapshotted: git tag
  `economy-v2` = place version 903. Not published: that needs the owner's word (and Game Settings max players 5). Phones are landscape-only (`init.client.luau` +
  `StarterGui.ScreenOrientation` LandscapeSensor). On the stage the HUD is hidden: anything the player must know
  there goes through a toast from ThrowController (`_sealHint` is the example), and a toast holds ~48 characters.
- FOOD AND TRAINING V2 (plan `design/plan/13-food-and-training-v2.md`, owner approved 2026-11-26; build log in its
  section 11; phases A (rules and wiring), B (the 51 food models and icons), C (throw feel; commit 3f88e12 = place version 939)
  and D (the training framework + grounds 1 and 2; commit 224c9e1 = place version 954; awaiting the owner's play) are built;
  E is DONE with SIX grounds (owner, 2026-11-27: keep six, no grounds 7 and 8; pair 1 commit a8184f9 = place version 964, pair 2 commit c4d74da = place version 972); F (playtest) is not). Numbers:
  `tools/economy/econ_v3.py` (`gen`, `apply`, `check` = the pacing gate, `cadence`, `table`), then gen_characters.py,
  gen_config.py, gate.py. Rules: 51 foods = 3 per world (Snack, Meal, Signature); food gives LUCK only (reach = Power);
  a food counts half in a world later than its own (`Core/Foods`); the throw auto-picks the best owned food for the
  landing world unless the player pinned one (`profile.autoFood`); each hero has a `Favourite` dish (not a flavour;
  iconic pairs in `design/characters/favourites.json`). Training: 57 rows = 19 tiers x 3 levels (`Model` = the tier's
  template); `Core/Beat` grades one tap per jittered beat (Perfect / Good), Focus 40 = an 8 s awakening; leaving it
  running is x1. Client: `Ui/FoodLook` is the one place that says which food is thrown and how it is drawn (every
  food has its own model and icon since 2026-11-27). Food art: `design/foods.json` (size, turn, throw class) ->
  generate_mesh with the prompt starting `FOOD_<id>:` -> `tools/studio/foods/food_lab.luau` (judging row) ->
  `install_foods.py` -> `tools/ui/food_icons_v2.py` (then `--sheet` and LOOK, then `--upload`). Flight by the
  template's `Throw` attribute: heave = level, spin = end over end, else a slow tumble. Saves: `Profiles_v3` / `Profiles_Dev_v3`.
- THROW FEEL (plan 13 phase C, 2026-11-27; log in the plan's section 11). `src/client/Fx/FoodFx.luau` is the ONE
  place that says how a food is thrown: Snack = `ThrowTrail_Basic` + `Land_Impact`; Meal = `ThrowTrail_Meal` +
  `Land_Meal` + `Aroma_Meal`; Signature = its own `Sig_<id>_Trail` / `Sig_<id>_Land` + `Aroma_Signature`, a sting
  and an accent sound; a favourite dish adds `Favourite_Burst`. Per-food data: `design/foods.json` (`throw`,
  `land`, `accent`) -> `python tools/gen_food_feel.py` -> `src/shared/Config/FoodFeel.luau` (GENERATED; also the
  dish's own colour, taken from its icon; `--check` is a gate step and fails if a Signature dish lacks an effect
  or a sound). Effects: `assets/vfx/builders/build_food.py` (+ `tools/make_food_tex.py`) -> `tools/upload_tex.py`
  (new textures -> `ids.json`) -> `tools/pack_all.py` -> run `work/vfx/build_templates.luau` in edit mode.
  A FLIGHT EFFECT MUST RIDE WITH THE FOOD (`LockedToPart`, born behind the food): at 125 to 2,100 studs a second
  nothing left in the world is seen and a Trail's texture never reads. JUDGE IN THE GAME with
  `tools/studio/foods/fx_judge.luau` (client datamodel of a play session: `_G.FxJudge.fly(id)`, `.land(id, t)`
  freezes the burst, `.rest(id)`, `.stop()`), at QualityLevel 21: soft glow / "hot" flame sprites that look fine
  in the sim fuse into a pale cloud in the game (use the cel sprites), and a flipbook laid flat on the floor
  draws as a broken arc (use a ring sprite). The food in the hands on the throw spot: `ThrowController:_tickHeld`
  + `Fx/FoodHold` (the aiming camera is BEHIND the player: holds must read from behind). Sounds were picked from
  measured loudness curves, never heard: `SoundController` `STARTS` (skip a clip's lead-in) and `CAPS`.
- TRAINING GROUNDS (plan 13 phase D, 2026-11-27; log in the plan's section 11). A base's two courts each show one
  ground (`Core/Grounds`: the two newest opened by rebirth; before rebirth 1 the right court shows the Waterfall
  LOCKED). Built: ground 1 Striking Post (game `ring`: tap as the ring lands), ground 2 Waterfall Focus (game
  `breath`: hold, let go on the gold), ground 3 Boulder Breaker (`sweep`: tap as the needle crosses the gold zone)
  and ground 4 Thunder Peak (`reflex`: tap the rod the lightning marks; `Lanes`, `Lead`, `React`, `LaneClips`),
  ground 5 Gravity Chamber (`rhythm`: tap the notes, leave the REST, `Rests`) and ground 6 Spirit Orb (`charge`:
  a long hold, `MinHold` 2; the orb rides on the trainee's hands; a piece's colour is its attribute `Energy`);
  there are no more (the owner dropped grounds 7 and 8). The 19 gear tiers are shared out 3 / 3 / 3 / 3 / 3 / 4
  (`econ_v3.py` `GEAR_GROUND`; templates post T1-3, falls T4-6, boulder T7-9, peak T10-12, gravity T13-15, orb T16-19)
  and a ground opens at the rebirth tier where its first tier's world is reached (0, 1, 2, 4, 5, 7), so the gear's own
  ground is always on show (a ground with no template shows nothing and its prompts are off). Per-ground data is in `tools/economy/econ_v3.py` `GROUND_FEEL` (clips, `Marks` = the clip's rep
  times, `Contact`, `MinHold`, `Hint`) -> `apply` -> gen_config. Rules: `Core/Beat` (`gradeHold`, `focus` scaled by
  beat length, `upcoming`, `clipAt` = the clip run so its reps fall on the jittered beats, `lane` + `gradeReflex`). Server: `TrainingService`
  (a session per court, stand point from the set piece's `Stand`, attributes `TrainPlot` / `TrainCourt` / `TrainAwake`
  on the character); `PlotService:_showGrounds` stands `Assets.Grounds.Ground_<id>_T<tier>` on the anchor `Ground<court>`
  (removes `L2` / `L3` below that level and `Lock` when open, moves the prompt holders `TrainSpot<court>` and
  `GearSign<court>` onto `Stand` and `Sign`, writes the board). Client: `Controllers/TrainingController` (camera,
  clip sync, tap / hold / lane input, Focus bar; UI v5.4 `tools/ui/screens_v54.py`), `Controllers/GroundController` (the
  awakening show for EVERY player from the attributes, the reps (`STRIKE` = the grounds where a blow lands on a
  target), the rod marks, the boulder's cracks, the waterfall's sound), `Ui/GroundLook` (the card
  model `Show_<id>_T<tier>`). Set pieces: `tools/studio/grounds/` (`ground_lab.luau` gathers generated `GROUND_<key>`
  models -> `python tools/studio/grounds/run_build.py` clears and builds EVERY template with the effect texture ids;
  `preview.luau` stands two on a base, take them away before a play test; `court_setup.luau` was the one-off that
  made the anchors). Effects `assets/vfx/builders/build_train.py`, judged with `tools/studio/grounds/fx_judge.luau`;
  sounds measured with `python tools/studio/sfx_probe.py <candidates.json>` (play session). `python tools/ui/build_ui.py
  --only TrainingBar` rebuilds one screen (a full run rewrites every screen's sample text from today's config).
- Driving a playtest over MCP: move the character on the SERVER datamodel (a client-side teleport does not
  replicate; the throw is then refused "not on own throw pad", printed only with workspace attribute `TFADebug`),
  then fire the remotes from the Client datamodel in a `task.spawn` and log into a StringValue (output from a
  yielding call is dropped). In the Device Simulator `user_mouse_input` clicks off-target: hit-test with
  `PlayerGui:GetGuiObjectsAtPosition` instead.

## Known traps on this machine

- STUDIO DIES WHEN THE PC RUNS OUT OF MEMORY (2026-11-27: another app held 36 GB; "paging file is too small", then
  Studio was gone mid play test at graphics level 21). Team Create had kept every edit. Check first
  (`(Get-CimInstance Win32_OperatingSystem).FreeVirtualMemory`, under ~3 GB is too little for a play test at level
  21), tell the owner what is holding the memory, and relaunch with
  `RobloxStudioBeta.exe -task EditPlace -placeId 106586376894468 -universeId 10776373502` (the MCP gets a NEW studio
  id; the Rojo plugin reconnected by itself). `settings().Rendering.QualityLevel` is a Studio setting and survives:
  set it back to Automatic after judging.
- An Attachment's `WorldCFrame` set BEFORE it has a parent is taken as its local CFrame (the waterfall's beams stood
  13 studs up in the sky). A Beam's width lies along its attachments' Y axis, not Z. A generated mesh with a texture
  cannot be tinted through `Color`.
- A script tab left open in Studio makes `screen_capture` return a blank dark frame with only the corner axes (the
  3D view is not the active tab): close the tabs (`ScriptEditorService:GetScriptDocuments()`, `doc:CloseAsync()` in a
  `task.spawn`) and capture again. A test command that jumps rebirths (`best <n>`) plays the rebirth cinematic for
  several seconds: wait about 10 s before starting a training session, or the cinematic's end takes the camera.
- `VirtualInputManager` is closed to `execute_luau` ("lacking capability RobloxScript"): to play a training game in a
  test, fire `Players.LocalPlayer.TrainTestInput` (a BindableEvent TrainingController makes only in Studio:
  `Fire("press", lane?)` / `Fire("release")`) from the Client datamodel when the HUD shows the moment; it goes through
  the real input path. A `screen_capture` lands several seconds after the call that precedes it: to catch a moment,
  read the time left from an attribute, return about 4 s early and take five or six captures in one message.
- A Neon part in a pale colour blooms to white (and a Neon ball draws as a flat disc): give Neon a saturated colour and
  build a glowing ball as a lit ball under a transparent Neon shell. A particle is always SQUARE, and VelocityParallel
  runs the texture's UP along its travel: a line that must fall or rise straight needs an upright line in a square
  image (`tfa/speed_line`), not the library's slanted streak. A ProximityPrompt can be pressed with `prompt:InputHoldBegin()` / `InputHoldEnd()`.

- A `GeometryService:UnionAsync` result keeps its FIRST part's CFrame: its Position and Size do not say where the geometry
  is. Measure a model BEFORE merging (attribute `TrueSize`, pivot at the base centre) and place it by its pivot, never by
  its parts' boxes (the zone-1 houses floated 8 studs until this was fixed).
- Studio's `generate_mesh` is the best source of hero props here (keeps, trees, statues beat every free store model
  tried) but it makes one OBJECT, not scenery: ask for one stone head, not "a cliff with five faces" (that came
  back as a pillar ringed with heads). The word "ninja" tripped its moderation filter.
- `generate_mesh` inserts its model TURNED TO FACE THE CAMERA: a template stored as it comes carries that yaw (zone 2's
  were 15 degrees off: a skewed mansion, carriages pointing off the rails). After storing generated meshes run
  `tools/studio/zones/square_templates.luau`; squared, a generated mesh fronts to -Z. Two meshes generated apart do not
  share a scale either (the locomotive's and the carriage's wheel gauges differed): measure, do not assume.
- Every zone's floor kit stops 6 studs short of the next (`tools/studio/lane_thresholds.luau` lays a stone threshold in
  each slot); anything that deepens the trench exposes such slots as void.
- Terrain written from a height map comes out as stairs on anything steeper than 45 degrees: fill each voxel by its
  distance to the surface, not its depth under it (see `zone_01_naruto.luau`).

- FREE MODELS CAN CARRY MALWARE. The owner's aura/VFX packs held a hidden `Runtime` Script +
  `ScreenBuilder` LocalScript (deep under `RuntimeInput.RuntimeInputContext...`) that runs only in Studio
  and shows an "overlay window" asking the developer to paste code into the command bar (a backdoor
  installer). Removed 2026-11-15 (8 copies). Before using any imported model: list every LuaSourceContainer
  in it, delete anything you did not write, and never run code a model's UI tells you to.
- The lane is 6,120 studs; streaming radius 1024 (min 64, `StreamOutBehavior` Opportunistic, since plan 11 phase 4):
  anything shown far down the lane needs the server's `ReplicationFocus` moved there (ThrowService `_focus`), or the
  map behind it is half missing.
- LOAD / SLIM (plan 11 phase 4): `tools/studio/lod_chunks.luau` (rerunnable; RERUN IT after any zone, lane_border,
  finale or lane_thresholds run) groups the loose parts of `Map.Scenery` and `Map.Lanes` into 64-stud `LodChunk`
  models and sets `LevelOfDetail = SLIM` on every static model there (models over 100 across are opened up, merged
  meshes and `Gate_*` stay whole), turns light shadows off and sets the streaming numbers. Tools that read a floor kit
  use `kitItems` (side_lib, lane_thresholds) to see inside the chunks. The Hub, HubV2 and Plots are NOT chunked: runtime
  code finds anchors there by name. SLIM copies are built in Roblox's cloud from a SAVED place (Team Create).

- This Roblox build has NO `PlayerModule` in `PlayerScripts`: never `WaitForChild` it (a 5 s stall per call, which delayed the pad lock and the rebirth). Hold a character by its humanoid (WalkSpeed/JumpHeight 0) or, better, on the server (anchor), like training and the throw pad.
- `BillboardGui.StudsOffsetWorldSpace` is in the ADORNEE's axes: on a cylinder lying on its side (station mats, stands) "up" goes sideways. Hang labels from an unrotated invisible anchor part. An always-on-top BillboardGui did not draw at all in play (on the mats, and again for the custom prompt card on any part): draw world labels with AlwaysOnTop off, and anything that must stay on top (prompt cards) in a ScreenGui placed with WorldToViewportPoint (`PromptController`).
- A `screen_capture` while Studio is not the foreground window can return the SAME stale frame: bring the window to the front (ShowWindow 3 + SetForegroundWindow after an Alt tap) before judging anything.
- Studio MCP drops every 5-15 min and its "Enable Studio as MCP server" toggle can turn off after a
  Studio update: re-enable it (Assistant > ... > Manage MCP Servers), don't debug your code.
- `execute_luau` output is capped at 100 KB: dump big data in groups.
- `require` in execute_luau is CACHED for the whole Studio session: a config edited and synced by Rojo after the
  first require is NOT seen (lane_slim's first run read the old lane width: stage, spots, margins wrong). Builders
  that read config require a clone: `require(module:Clone())`.
- An endless loop in a builder freezes Studio until it CRASHES (2026-11-22: a `while z < limit` whose step
  `z = zz - 1` never passed the limit, twice: the request seemed to run again when Studio came back). Every
  `while` in a builder must provably end (break on the last step); after a crash, send one trivial call first.
- `execute_luau` drops all output if the script yields: split the call or use `task.delay`.
- Direct Studio calls without the client: `python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py`
  (`luau --code ...`, `--dm Server` reaches the running playtest server).
- `screen_capture` returns a blank dark frame (or a black world behind live GUI) whenever the Studio
  window is minimised. Restore the window (Win32 ShowWindow on the running process), never
  `open_application`.
- During Play, `execute_luau` cannot see the game's Knit services or controllers (its `require` is a
  separate copy). Read state through instances and GUI text, fire remotes from the Client datamodel,
  and hook remotes to log what the server answered.
- `tools/studio/front.ps1` can bring a ROBLOX PLAYER window to the front instead of Studio when the owner has the game
  open (2026-11-23): check the foreground process before trusting an fps reading. To test SLIM, park the play camera
  over a zone ~3000 studs from the player and count that zone's parts on the client: 0 parts and the zone drawn = SLIM.
- Studio renders at about 15 fps whenever its window is not in front: a frame-rate reading is only valid with
  Studio focused (measured: 15 fps with the whole world hidden, 60 fps a minute later in front).
- A locked or sleeping screen stops Studio rendering: `screen_capture` times out and a RenderStepped probe never returns.
  Check `Get-Process LogonUI`; building the map still works. The same happens when Windows blanks the display (its
  timeout was 1 minute): a key tap wakes it, so run `tools/studio/front.ps1` (Alt tap + foreground) before each batch
  of captures. `screen_capture` takes `camera_position` / `look_at_position`: no camera script needed.
- A scaled TextLabel stops growing at 100 px: on a SurfaceGui size the canvas so 100 px is the face's short side
  (`zone_lib.words`), or a glyph on a 24-stud board comes out 5 studs tall.
- Workspace is itself a Model: `FindFirstAncestorWhichIsA("Model")` is always true. Filter on the parent's class.
- `screen_capture` WITH a camera position is taken at once, while the terrain is still in its coarse far-away form: flat
  ground then shows as raised blocks that swallow paving and plinths. For anything about the ground, park the camera
  first (`python tools/studio/zones/run_zone.py look ...`, which also wakes the display) and capture with NO position.
- NEVER leave the edit camera Scriptable (`run_zone.py look` sets it). Studio's execute_luau records the camera type at
  the start of each call and RESTORES it afterwards, so once it is Scriptable it cannot be fixed over MCP and the owner
  loses right-click rotate. Fix: Command Bar (Window > Script > Command Bar):
  `workspace.CurrentCamera.CameraType = Enum.CameraType.Fixed` (Fixed is Studio's normal edit camera).
  It CAN be fixed over MCP with a delayed task that runs after the restore:
  `task.delay(1, function() workspace.CurrentCamera.CameraType = Enum.CameraType.Fixed end)` (worked 2026-11-22).
  `screen_capture` with a camera position also leaves the camera Scriptable: after a batch of such shots, run that.
- Level smooth terrain shows (and collides) 2 studs above the height it was written at; grass is drawn swollen higher
  still and comes up through a thin part laid on it. Lay paving with `zone_lib.pave`.
- Two terrain materials banded on a cliff face render as blotches; Asphalt tinted navy renders olive-brown. One rock
  material per wall. Studio's `generate_material` gave noisy small-tile textures (rejected).
- `generate_mesh` moderation refuses prompts with injuries or weapons on a creature (a blade "out of its forehead", a
  target "on its neck"); reword tamely. Meshes often have a flat unfinished BACK: stand them against a wall or pillar.
- A `generate_mesh` result can come back with the wrong proportions (a squat box for a tall request) or a broken part
  (a tree with a flat slab for a canopy): `run_zone.py inspect` catches the first, only a look catches the second.
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
