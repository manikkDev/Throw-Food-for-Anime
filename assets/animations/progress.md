# Section 4 animation progress

Resume: every command runs from the project root with env BLENDER set (Blender 4.5).
`python tools/anim/run.py gen` -> `python tools/anim/fkcheck.py <names>` -> `dry <names>` -> `render <names>`
-> `axis <names>` -> `manifest` -> `build`.

## Batch 1 (player) - DONE 2026-11-15
Throw, TrainStrike, TrainPush, TrainMeditate, Celebrate: specs, sheets, GIFs, axis check pass.
- TrainMeditate: plain (arms straight to the knees), reads as seated cross-legged.

## Batch 2 (hero idles, Core) - DONE 2026-11-15
IdleCool, IdleCheer, IdleBlade, IdleNinja: rendered, judged on one tiled sheet, axis pass (worst 1.18 deg).
Hand placements found by dry-run grid search (work/anim/grid.py), not by renders.

## Batch 3 (heroes) - DONE 2026-11-15
IdlePower, IdleShy, IdleFloat, Eat, RevealLand: rendered, judged on one tiled sheet, axis pass (worst 1.39 deg).
Fixed after looking: Eat thumbs-up arm folded into the face (shoulder+elbow 140 deg) -> upright fist.

## Rev 2 after the owner's review - DONE on disk 2026-11-15, NOT YET BUILT/UPLOADED
Owner: the throw was "lame", a small arm move; punches landed "from far away". The main thread snaps the
player to a stand point in front of each training target, so every training clip now lands at a known,
documented distance. New code: `tools/anim/clips_train.py` (the four clips), `fkmodel.py` (pure-Python FK
of the rig + least-squares solvers), `fkcheck.py` (per-frame numeric checks), `scene_render.py` (bag /
boulder / dumbbells in the renders + Blender-measured contact per marker).

- Throw (1.5 s, Release 0.7667 = frame 23): pivot step, balance (lead knee up), stride 1.6 studs, foot plant
  with ~38 deg hip-shoulder separation and the arm cocked, layback, release with the trunk forward and over
  to the glove side, follow-through across the body, back leg swings through, steps back to a stand. The
  hips travel -0.25 -> +0.58 studs along the facing (ROOT loc), see "ROOT loc export" below.
- TrainStrike (2.0 s loop, Hit 0.2/0.6/1.0/1.4): jab, cross, left hook, right uppercut, each followed by a
  3-frame recoil so the fist never sinks into the bag; feet planted (foot lock), rear heel pivots on the cross.
- TrainPush (1.2 s loop, Hit 0.5333): long lunge, both palms pinned to the boulder face on EVERY frame
  (arms re-solved per frame), sink -> drive -> strained tremor.
- TrainLift (2.0 s loop, Rep 0.4667 / 1.4667): alternating hammer curls, a dumbbell bone-parented to each hand.
- Checks: fkcheck feet within 0.03 of the floor everywhere (Throw: 0.024), no fist past the bag face by
  more than 0.05 (the jab's approach frame), palms never past the boulder; Blender mesh contact
  strike 2.45-2.48, push 2.44; axis check worst 1.34 / 0.98 / 0.71 / 0.42 deg, and NO path warnings
  after the slerp pass (below).

### Problems found and fixed on the way
- Perspective lies about contact: in the side view a fist ON the bag face looked 0.5 stud short (it was
  on the far side of the bag, so parallax shifted it). Contact is now proved by numbers twice (FK model +
  Blender meshes), the sheet only judges the pose.
- Keys off the 30 fps grid (0.56, 0.92) made the Blender marker report sample the frame AFTER the hit and
  show the hook 0.15 through the bag. All rev-2 keys and markers sit on frames (`fr(n)`).
- FK Euler lerp between two planted keys slid / sank the feet (0.13 under the floor in the uppercut dip):
  `lock_feet` bakes such segments per frame with the legs re-solved (yaw/heel pivots interpolated).
- The arm solver returned far-apart but equivalent Euler triples (X -167 vs +13) and Roblox slerps while
  Blender lerps: rbx_axis_check --mid flagged 176 deg on the throw's hand between release and
  follow-through. `slerp_pass` re-expresses every key as the Euler nearest the previous one and keys any
  segment that still differs (>6 deg) on the slerp path per frame. Axis --mid: no warnings.
- Guard arms intruded 0.55 into the chest (block arms are 1 stud thick): the solvers now carry an
  arm/body intrusion residual (`avoid`), worst 0.30 left (arm surface touching the chest in guard).

### ROOT loc export (only the Throw uses it) - VERIFY IN STUDIO
The rig's ROOT bone rests with local X = world -X and local Y = world -Y (probed), so a spec loc
(lx, ly, lz) moves the body by world (-lx, -ly, lz) in Blender (traps.md #45). The skill's to_roblox.py
maps loc to Roblox (lx, lz, -ly), which plays X and Y mirrored. `run.py build` therefore exports copies
with loc (-lx, -ly, lz) (`work/anim/export/`), giving Roblox (dx, dz, -dy): forward stays forward. The skill
itself is untouched. Check in Studio: during Throw the body must move TOWARD the throw (LowerTorso about
0.6 stud forward of the HumanoidRootPart around the release), not away from it.

## Build
work/anim/build.lua (15 specs, folder ReplicatedStorage.Assets.Anims, yield-free); manifest 15/15 axis pass.
Left for the coordinator: paste build.lua in Studio, upload with upload_animation.py (Throw, TrainStrike,
TrainPush changed; TrainLift new), update ids.json, `python tools/gen_anim_ids.py`; in-game check of the
contact distances and the Throw's root travel.

## Known weak spots
- RevealLand: the fist stops ~0.3 stud above the floor and the front foot dips ~0.3 below it for a few
  frames mid-rise (0.55-0.7 s).
- Eat: crouch frames dip the feet ~0.1 below the floor between keys.
- TrainMeditate (unchanged): seated with the root dropped 1.65, the folded feet sit ~0.37 below the floor
  plane and the seat ~0.35 above it; reads fine without a floor, may show on flat ground.
- Throw: the lead foot slides ~0.2 stud over the last two frames of the step back (frames 41-43).
- TrainStrike: the jab's approach frame (5) is 0.05 past the face before contact at frame 6.
- Root-joint pivot: TORSO leans pivot at the waist in the rig; if Roblox's Root joint pivots lower, a lean
  shifts the legs by about 0.4 * sin(lean). The rev-2 clips keep TORSO leans <= 10 deg (<= 0.07 stud).

## Problems found
- to_roblox.py read `markers` only as a {name: time} dict, so two "Hit" (or "Bite") markers collapsed into
  one. Patched in the skill to also accept a list of {name, time}; specs here use the list form.
- ROOT loc +Y moves the body BACKWARD in the render but to_roblox maps it to Roblox forward (handled at
  build time, above).
- ffmpeg 9 removed -vsync (use -fps_mode passthrough).
- Bash heredocs containing an apostrophe fail in this harness: write Python edits to a file with the Write tool.

## Batch r6 (shoulder carry) - DONE and UPLOADED 2026-11-16
CarryShoulder 92687348195038, CarriedRide 129171837155585, PlaceHero v2 77773650101040. See work/anim/upload6/README.md.
- A 0.55 hero cannot straddle a 1.2-stud block head (hips at +-0.275, leg < 1 stud): one-shoulder seat instead, measured with tools/anim/duo.py.
- New tooling: duo.py (two rigs as oriented part boxes, SAT depth), duo_blender.py / duo_run.py (hero = copies of the rig's real part meshes keyed per frame; renders + real-mesh clash report). The shipped CarryHold measured 0.10 of hero foot inside the player's head on most frames.
