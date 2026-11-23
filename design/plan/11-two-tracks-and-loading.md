# 11 - Two tracks, throw spots on the stage, a shorter walk, the whole map loaded

Owner's request, 2026-11-23 (with two screenshots: the lane fading out past zone 2 even on max graphics, and the
hub from above):

- A. take one more track out (3 -> 2) and stick the sides to the lane "without any issues"
- B. no throw pad at the bases
- C. less space between the bases and the zone entrance, but not congested
- D. the whole map loaded for every player, rendered without lag

## 1. What the place is now (measured 2026-11-23)

- `Workspace.Map`: 13,519 parts (3,075 MeshParts, 123 unions), 122 lights (10 casting shadows), 75 particle
  effects, 1,843 models, every one `LevelOfDetail = Automatic`.
- Streaming is ON: target radius 576, min radius 256, `StreamOutBehavior` Default. The lane runs 6,120 studs
  (z 160..6280). A player on the stage gets at most ~576 studs of it; everything further is not on their machine
  at all, and with `Automatic` level of detail nothing is drawn in its place. **That is the empty far lane in the
  screenshot, and max graphics cannot fix it: the server never sends that part of the map.**
- Hub, along z: bases (decks) -44..21, slot sign 26, training courts 34..56, throw pads at 70 (radius 7), then
  ~55 studs of empty lawn to the throw stage (135..163); the lane starts at 160. Lawn is terrain Grass.
- Dev scenery in Workspace is deleted by the server on start (`ZoneLab` 4,023 parts, `AuraShowcase`,
  `AuraPackBrowser` with 1,794 effects, `MapV2`). Three leftovers do ship: `Sketchfab_Scene`, `UpperTorso`,
  `Characters_R15_New` (tiny or empty).

**Fewer tracks alone will not make the map load.** One track out takes 28 studs off each side, about 13% of the
map's width and nothing off its length. The loading fix is D. Both are done; D is what makes the far map appear.

## 2. Decisions

1. **Two tracks**, 56 wide each, centred at x -28 and 28: the lane is 144 wide (x +-72). Five throwers on two
   tracks: bases 1-2 share the left track (each on its own half), bases 4-5 the right, base 3 throws down the seam
   in the middle. Landings at x -40, -16, 0, 16, 40 (+-6 jitter). Config `World`: `LaneWidth` 144,
   `TrackCount` 2, `PlotTrack` {1, 1, 1.5, 2, 2}, `PlotTrackSide` {-1, 1, 0, -1, 1}, `TrackSideOffset` 12.
   The stage's five spots stand at those x, 16-24 apart.
2. **The throw spot is the player's own coloured circle on the stage.** Walk onto it: the server holds you there,
   exactly as the pad did (same remote, same lock, same exit by the meter's X / Backspace, which sets you down just
   behind the circle). Each circle takes its base's colour, and a floating "YOU" marker hangs over your own
   (client side). The five pads go from the bases; `World.throwPad` becomes the stage spot; `Blockout` builds none.
3. **The hub moves 40 studs closer to the lane** (40: a whole number of terrain voxels). Bases, yards, courts,
   lanterns, sakura, spawn, plaza, districts, sanctuary, statues and the lobby's back wall all move 40 toward the
   lane; the stage, the ledge and the lane do not move. The empty lawn between the courts and the stage goes from
   ~80 to ~40 studs (the pads' strip is gone too), so it is shorter but not crowded. The lobby gets 40 shorter at
   the back (back wall's inner face z -116), and the strip it gives up becomes sea. Config: `PlotBackZ`,
   `PlotFrontZ`, `PedestalCenterZ`, `SlotSignZ`, `CourtZ` and the training stations' `Z` +40.
4. **Loading: show the whole map without sending all of it.**
   - `StreamingTargetRadius` 1024 (Roblox's recommended value), `StreamingMinRadius` 64, `StreamOutBehavior`
     Opportunistic (a low-memory phone drops far parts early instead of running out of memory).
   - Every static scenery model gets `LevelOfDetail = SLIM`: Roblox's cloud builds a merged, lower-detail copy that
     is drawn when the real model is not loaded. That keeps the lane visible all the way to the sealed gate while
     each client holds only ~1,000 studs of real parts. Loose parts (kerbs, revetments, paving, floor kits, walls)
     are first grouped into chunk models about 60-90 studs long, as Roblox advises for SLIM.
   - Things that change while playing stay out of SLIM: plots and the heroes on pedestals, gate plaques (their
     "needs X power" line), prompts, the stage spots.
   - Lag: the 10 shadow-casting lights stop casting; decorative MeshParts get box collision and no touch/query;
     small props stop casting shadows; the three leftovers in Workspace go.
   - SLIM copies are made in Roblox's cloud from the saved place (Team Create is on), and the first time can take a
     few minutes. On a device that does not support SLIM yet, models fall back to today's behaviour: only what is
     near is drawn, but at radius 1024 instead of 576.

## 3. Phases (each: build, look, play boot, save a place version, docs)

**Phase 1: done 2026-11-23**, place version 686 (`tools/studio/throw_spots.luau`, rerunnable; pads archived in
`MapArchive.ThrowPads_v1`; tutorial and store texts say "spot"). Played: walk onto the circle -> held facing the lane,
throw, catch -> set down at z 132 behind the stage, carrying; back on the circle with a hero -> the toast.

**Phase 1 - throw spots on the stage, no pads.** Code: `World.throwPad` -> the spot, `PlotService:OnThrowPad`,
`ThrowService:SetPad` (set down behind the circle), `ThrowController` (the lock and the "YOU" marker), `DevPanel`
teleport, `Blockout`, `tests/World.spec.luau`. Place: pads out of the five plots (`base_layout.luau` no longer makes
them), spot rings in base colours. Check: from every base, walk to your circle, throw, leave; a carried hero still
says "place it first".

**Phase 2: done 2026-11-23**, place version 688. `tools/studio/hub_forward.luau` moved 550 pieces and copied the
hub terrain once; lobby_wall.luau rebuilt the walls with the back at z -116 (side keeps at -20 and 86, lanterns at
20/70/120); base_layout.luau rerun left the bases where they were (a no-op check). Played: spawn at the base (z 66),
food cart opens the shop, training on the moved court works, all prompts and boards in place. The lawn from the courts'
front (z 96) to the stage (135) is ~40 studs. lobby_wall's two crossings (the wish dragon's tail, the rankings district
by a back keep) are the same as before the move.

**Phase 2 - the hub 40 closer.** Config +40 on the hub's z numbers; a one-off `hub_forward.luau` (attribute
`HubForward` on `Workspace.Map`) moves the hub's pieces and lays sea behind the new back wall; the rerunnable
scripts that place hub pieces (`base_layout`, `lobby_wall`, `plaza_districts`, `sanctuary`) take the new numbers
so a rerun does not undo it. Check: prompts (food cart, booth, chest, gift, index, summon) still work, spawn
lands on the lawn, leaderboards still fill.

**Phase 3: done 2026-11-23**, place version 690. Config two tracks; `tools/studio/lane_two.luau` (one-off, attribute
`LaneTwo` 28) moved 850 floor-kit pieces in and removed the middle track's 459, narrowed the stage, ledge and side
barriers; throw_spots.luau put the spots at x -40, -16, 0, 16, 40. side_lib got `P.SHIFT` 28 (terrain in `fill`, parts in
`markSlim`'s `settle`); zones 3 and 17 write their harbour water through `fill`; zone 1's great wall reaches the lobby
(`LOBBY_OUT = 262 + P.SHIFT`) and its ledge piers sit at x +-30, +-68. All 17 zones rebuilt: every count (parts, placed,
refused) the same as their last builds, nothing in the lane. Then zone_gates (PX 87), lobby_wall (`STAGE_HALF` 72,
`TOWER_IN` 132), lane_border (wall 178..192, 0 crossings; its two crossings in lobby_wall are the old ones), finale
(`CORNER_X` 185, dragons at x +-47), lane_thresholds (144 wide). Looked at from the stage, over the lane mouth, over
zone 3's harbour and at the sealed gate. Played: walk onto spot 1 -> held at x -40, throw -> lands on the left track in
zone 2, no errors.

**Phase 3 - two tracks.** Config as above; a one-off `lane_two.luau` re-lays the floor kits for two tracks (the
middle strips go, the outer ones move in 28, kerbs, margin paving, thresholds) and narrows the stage, ledge,
barriers and the ledge's parapets. `side_lib` gets a 28-stud `SHIFT`: the zone files keep their numbers and
side_lib moves everything a zone builds (parts and terrain) 28 toward the lane, so the 17 zones are REBUILT, not
rewritten (17 rewrites would be 17 chances to misplace something). Then `zone_gates` (pillars at x +-87),
`lane_border` (wall 178..192), `finale` (`CORNER_X` 185), `lobby_wall`, `lane_thresholds`. Zones 1-17 rebuilt
in order, each looked at; zone 1's entrance is the one special case (it joins the lobby, which keeps its width).

**Phase 4: done 2026-11-23**, place version 691. `tools/studio/lod_chunks.luau` (rerunnable; rerun after any zone,
lane_border, finale or lane_thresholds run): 5,090 loose parts of Map.Scenery and Map.Lanes grouped into 1,006
64-stud `LodChunk` models, `LevelOfDetail = SLIM` on 1,993 static models (92 big containers opened up, `Gate_*` and
merged meshes whole, no Humanoids found), the 10 shadow-casting lights and 208 small parts no longer cast shadows,
nothing there takes touches; streaming 64 / 1024, Opportunistic; the three Workspace leftovers moved to
`ServerStorage.MapArchive.WorkspaceLeftovers`. Hub, HubV2 and Plots are untouched (runtime code finds anchors there by
name). Tools that read a floor kit use `kitItems` to see inside the chunks. Measured in play: before, from the stage
the lane ended past zone 3 (the client held 7,750 of 13.5k map parts, nothing beyond ~z 1240); after, the camera over
zone 9 drew the whole zone and the next one with 0 of its parts on the client, and from zone 4 the lane reads unbroken
to the sealed gate. The client holds 8,270 parts (radius 1024). SLIM copies are built in Roblox's cloud after a save:
the first play after it logged "Asset content representation is being generated" for several minutes (511 still
pending ~10 minutes in); they then persist. A throw from spot 1 works, no errors. NOT measured: a valid frame rate
(a Roblox Player window held the foreground, so Studio was throttled) and a phone in the Device Simulator.

**Phase 4 - loading and lag.** A rerunnable `lod_chunks.luau` (chunk loose parts, SLIM on static models, collision
and shadow cleanup), the streaming settings, the leftovers removed. Measured before and after, Studio focused: from
the stage the lane visible to the sealed gate; client memory, instance count and FPS; a low-end phone in the
Device Simulator; the streaming panel (Shift+Ctrl+F3) and SLIM tint mode to see the stand-ins.

Phase 4 goes last because phase 3 rebuilds the zones and so replaces the models SLIM is set on (the script is
rerunnable, so nothing is lost if it runs earlier too). If the loading matters most right now, the streaming
settings alone can go in first.

## 4. Risks

- After phase 3 a zone file's x numbers are 28 off the world's (side_lib adds the shift). CLAUDE.md and side_lib's
  header will say so.
- Client code that reads far scenery (`FxController`, `CarryController`, `TrainingController`, `UpgradeController`,
  `ThrowController`) already has to cope with streamed-out parts at radius 576; phase 4 re-checks each.
- `Workspace.ModelStreamingBehavior` and `EnableSLIMAvatars` cannot be set from a script in this Studio build; they
  are optional and stay as they are.
