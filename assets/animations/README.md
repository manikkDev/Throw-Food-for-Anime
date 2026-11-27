# Animations (R15 clips, 30 fps, FK)

Authored headlessly with the `roblox-animation` skill on the calibrated rig
(`D:\Roblox Studio Games\_RobloxAI\rigs\MrXen0_R15RIG_v1.2.blend`, Blender 4.5 in env `BLENDER`).
Poses live as Python in `tools/anim/` (`clips_player.py`, `clips_hero.py`, `clips_train.py`, helpers in
`animlib.py`); the JSON specs in `specs/` are GENERATED from them. Edit the Python, not the JSON.

Rev 2 (2026-11-15, owner review): Throw, TrainStrike, TrainPush are re-authored and TrainLift is new
(`clips_train.py`). Their contacts are SOLVED, not eyeballed: `fkmodel.py` is a pure-Python copy of the
rig's FK (checked against Blender to 0.01 stud) and least squares finds the FK angles that put the fists /
palms ON the target plane and the planted feet flat on the floor. Every other clip is unchanged.

## Rebuild (from the project root)

```
python tools/anim/run.py gen                    # write specs/<Name>.json
python tools/anim/fkcheck.py <Name> ...         # instant: floor, foot slip, arm/body overlap, contact per marker
python tools/anim/run.py dry <Name> ...         # Blender: feet/hand tracks + CONTACT measured on the real meshes
python tools/anim/run.py render <Name> ...      # renders/<Name>_sheet.png (3 views) + <Name>.gif
python tools/anim/run.py keys <Name> out.png 6 18 30   # chosen frames, all views, for a close look
python tools/anim/run.py axis <Name> ...        # rbx_axis_check.py --mid (Blender vs Roblox CFrames, path too)
python tools/anim/run.py manifest               # manifest.json
python tools/anim/run.py build                  # work/anim/build.lua -> ReplicatedStorage.Assets.Anims
python tools/anim/run.py build4                 # batch r4 only -> work/anim/upload4/build_r4.lua (see its README)
python tools/anim/run.py build5                 # batch r5 only -> work/anim/upload5/build_r5.lua (see its README)
python tools/anim/run.py build6                 # batch r6 only -> work/anim/upload6/build_r6.lua (see its README)
python tools/anim/duo_run.py ride|place [--dry] # r6: carrier + 0.55 hero rendered together, real-mesh clash report
python tools/anim/run.py probe <Name> [--frames] # mesh_probe.py: floor, world foot slip (incl. game root travel), part overlaps on the real meshes
python tools/anim/look.py <Name> out.png 0 30 60 # judging renders: chosen frames, bigger, side/front/front34
```

Batch r4 (`clips_r4.py`, owner review "the reveal walk is childish/hyper"): HeroStalk replaces HeroWalkIn,
HeroMenace replaces HeroArrive, RebirthAwaken replaces RebirthEvolve (the old clips stay in place until the game
is switched over).

Renders go through `tools/anim/scene_render.py`, which adds the spec's static set dressing (`_scene`: the
bag, the boulder) and bone-parented props (`_attach`: the dumbbells) before running the skill's
`anim_render.py`, and prints the Blender-measured contact at every marker.

`build` writes export copies of the specs (`work/anim/export/`) with the ROOT loc X/Y sign corrected
(see progress.md): only the Throw moves the root horizontally.

Then paste `work/anim/build.lua` into Studio (`execute_luau`, yield-free, returns a summary) and upload the
KeyframeSequences with the skill's `scripts/upload_animation.py`.

## Clips

| Clip | Who | Priority | Loop | Length | Markers | What it is |
|---|---|---|---|---|---|---|
| Throw | player | Action | no | 1.5 | Release 0.7667 | **rev 2, NOT YET UPLOADED.** Full-power overhand throw: pivot step side-on, lead knee up, long stride, hips open before the shoulders, arm cocked and whipped over the top, release high in front of the head, follow-through across the body, back leg swings through, steps back to a stand |
| TrainStrike | player | Action | yes | 2.0 | Hit 0.2, 0.6, 1.0, 1.4 | **rev 2, NOT YET UPLOADED.** Heavy-bag combo jab, cross, left hook, right uppercut from an orthodox guard; every fist lands ON the bag face |
| TrainPush | player | Action | yes | 1.2 | Hit 0.5333 | **rev 2, NOT YET UPLOADED.** Long lunge into a boulder, palms flat on its face all loop; sink, then the rear leg drives and the arms lock out, strained tremor |
| TrainLift | player | Action | yes | 2.0 | Rep 0.4667, 1.4667 | **NEW, NOT YET UPLOADED.** Alternating standing hammer curls, a dumbbell in each hand |
| TrainMeditate | player | Action | yes | 1.0 | Pulse 0.5 | seated cross-legged, chest lifts and fists clench on the beat |
| Celebrate | player | Action | no | 1.2 | Peak 0.5 | crouch, jump with the fist punched up, land, "yes!" pump, ends in a neutral stand |
| IdleCool | hero | Core | yes | 3.0 | - | arms crossed, weight on one leg, slow look aside |
| IdleCheer | hero | Core | yes | 2.0 | - | idol wave above the shoulder, little bounce |
| IdleBlade | hero | Core | yes | 3.0 | - | left hand at the left hip where a katana hilt sits, right arm loose |
| IdleNinja | hero | Core | yes | 3.0 | - | low side-on crouch, two-finger seal at the chest |
| IdlePower | hero | Core | yes | 2.0 | - | feet wide, fists low, chest heaving |
| IdleShy | hero | Core | yes | 3.0 | - | hands behind the back, head down, sway and toe tap |
| IdleFloat | hero | Core | yes | 4.0 | - | hovering, slow drift on the root (owns the legs while it plays) |
| Eat | hero | Action | no | 1.6 | Bite 0.7, Bite 0.95 | crouch, pick up, two bites, thumbs up |
| RevealLand | hero | Action | no | 1.0 | Land 0.27 | drops in from above, three-point landing, rises into a pose |
| HeroStalk | hero | Movement | yes | 1.6667 | Step 0.2667 (R), Step 1.1 (L) | **r4, NOT YET UPLOADED.** Villain stalk: slow heavy heel-to-toe steps, 0.012 bob, chest forward, shoulders rolling, head low. **2.5 studs per cycle = 1.5 studs/s** ground speed |
| HeroMenace | hero | Action | no | 2.2 | Look 1.2, Power 1.6667 | **r4, NOT YET UPLOADED.** From the stalk's right Step: plant, one slow step, head comes up to the camera, shoulders roll back, fists clench and flex out with a chest lift; held. Root 0.5 studs Quad Out over 0.6667 s |
| RebirthAwaken | player | Action | no | 6.0 | Rise 1.2, Burst 3.5, Stance 4.4 | **r4, NOT YET UPLOADED.** Villain level-up: one knee down, fist on the ground, trembling rise, burst (head back, arms up and wide), power stance; held |
| CarryShoulder | player | Action | yes | 1.6 | - | **r6** (`clips_r6.py`, hand-off `work/anim/upload6`). Hero sits on the RIGHT shoulder (seat: hero LowerTorso `CFrame.new(1.25, 1.4345, -0.34)` in HRP space); right forearm level under its feet; upper body only, left arm and legs left to the walk. Replaces CarryHold in the game |
| CarriedRide | carried hero | Action | yes | 1.6 | - | **r6** seated on the carrier's shoulder, left hand on its head, right arm waving, hip bounce; start together with CarryShoulder |
| PlaceHero (v2) | player | Action | no | 1.3 | Hop 0.2, Grab 0.4333, Place 0.8 | **r6**, replaces r3's: hero hops off the shoulder, caught under the arms, set on the pedestal; hero path `work/anim/upload6/placehero_path.json` |
| HeroPickUp | hero | Action | no | 2.5 | Grab 1.2667, Lift 2.0333, Hold 2.2333 | **r5, NOT YET UPLOADED** (`clips_r5.py`, hand-off `work/anim/upload5`). From the stalk's right Step: plant, rear foot steps back, hip-hinge bend, right fist onto the top of the food (2.71 ahead, 1.01 right), slow rise, food held out at shoulder height to his right, head turned to it; held. Root 0.5 studs Quad Out over 0.6667 s. Food weld `CFrame.new(0, -(0.15 + r), 0)` on RightHand from Grab |
| HoldPitch | player | Action | yes | 2.0 | - | **r7** (`clips_r7.py`, plan 13 phase C, uploaded). On the throw spot with a one-hand food: the food on the upturned right hand beside the head (read from the aiming camera BEHIND the player) |
| HoldHeave | player | Action | yes | 2.0 | - | **r7** a bowl, plate or feast carried overhead in both hands, level |
| ThrowHeave | player | Action | no | 1.5 | Release 0.7667 | **r7** from HoldHeave: arch back, overhead throw-in with both arms, settle; the bowl level until Release |
| HoldSpin | player | Action | yes | 2.0 | - | **r7** a flat or stick food held flat out to the right at shoulder height, arm cocked |
| ThrowSpin | player | Action | no | 1.5 | Release 0.7 | **r7** from HoldSpin: coil, stride, side-arm sling across the body |
| TrainPost | player | Action | yes | 2.0 | Hit 0.5, 1.5 | **r8** (`clips_r8.py`, plan 13 phase D, uploaded). Makiwara practice from a left front stance: right reverse punch, left lunge punch; the post's face 2.87 in front of the HRP. The game runs it so each Hit falls on a beat (`Core/Beat.clipAt`) |
| PostFlurry | player | Action | yes | 1.0 | Hit x6, 0.1667 apart | **r8** the Striking Post's awakening: six alternating punches a second, leaning in |
| PostFinish | player | Action | no | 1.2 | Hit 0.5 | **r8** ends the awakening: wind-up, one blow 0.4 through the post's face; frame 0 = PostFlurry's, last frames = TrainPost's first |
| TrainBreath | player | Action | yes | 3.0 | Pulse 2.5 | **r8** seated under the falls: hands rise up the centre line through the inhale, turn over at Pulse, press down. Seat: LowerTorso 1.65 below standing, its underside 0.32 above the clip's floor |
| BreathAscend | player | Action | yes | 2.0 | - | **r8** the Waterfall's awakening: floating cross-legged 1.6 above the seat, arms open, a slow bob |

| TrainBoulder | player | Action | yes | 4.0 | Hit 1.5, 3.5 | **r9** (`clips_r9.py`, plan 13 phase E, uploaded). Two heavy palm blows on a boulder, 2 s apart; the rock's face 2.87 in front of the HRP |
| BoulderBarrage | player | Action | yes | 1.0 | Hit 0.1333, 0.3667, 0.6333, 0.8667 | **r9** Boulder Breaker's awakening: four alternating palm strikes a second |
| BoulderFinish | player | Action | no | 1.3 | Hit 0.6 | **r9** ends the awakening: a double palm thrust; frame 0 = BoulderBarrage's, last frames = TrainBoulder's first |
| PeakReady | player | Action | yes | 2.0 | - | **r9** Thunder Peak's waiting stance, facing the camera |
| PeakLeft / PeakMid / PeakRight | player | Action | no | 0.8 | Catch 0.1333 | **r9** the answer to a rod: one hand thrust toward it in 4 frames (left = the hero's RIGHT hand, toward the camera's left), held with a tremor, back to PeakReady |
| PeakStorm | player | Action | yes | 2.0 | - | **r9** Thunder Peak's awakening: arms in a V, trembling |

| TrainPushup | player | Action | yes | 2.0 | Rep 0.5, 1.5 | **r10** (`clips_r10.py`, plan 13 phase E, uploaded). Push-ups in profile, a plank on planted palms and toes; the game holds the top over a rest beat |
| GravityFloat | player | Action | yes | 2.0 | - | **r10** Gravity Chamber's awakening: weightless, about 2.4 above standing height |
| TrainOrb | player | Action | yes | 4.0 | Pulse 3.5 | **r10** Spirit Orb's loop: a growing orb held overhead on both palms, a push up at the Pulse; the game carries the orb on the hands |
| OrbAwaken | player | Action | yes | 2.0 | - | **r10** Spirit Orb's awakening: braced under an enormous orb |
| OrbThrow | player | Action | no | 1.2 | Release 0.5 | **r10** ends the awakening: the orb is thrown straight up |

Batch r10 hand-off (palm and toe positions, the hands' heights per clip, rough spots): `work/anim/upload10/README.md`.
Batch r9 hand-off (contacts, the catching hand's position per clip, rough spots): `work/anim/upload9/README.md`.
Batch r8 hand-off (contact table, knuckle points for hit effects, the author's list of rough spots):
`work/anim/upload8/README.md`. TrainStrike, TrainPush, TrainLift and TrainMeditate are no longer played by the game.

## Contact and props (rev 2) - what the main thread places

Distances are along the player's facing (Roblox `HumanoidRootPart.CFrame.LookVector`) from the
HumanoidRootPart centre, standard R15 block proportions (scale 1). Rig z is relative to the HRP centre
(the floor is z = -3.0). "Measured" = Blender, on the real hand meshes, at the marker frame.

| Clip | contact_distance (target front face) | measured at the markers | where on the face |
|---|---|---|---|
| TrainStrike | **2.47** (place the bag/dummy face here) | fists' frontmost point 2.45 to 2.48 at every Hit (solved onto 2.50 in the FK model) | jab x -0.5, cross x +0.45, hook x +0.1 (all z ~0.85), uppercut x 0.05 z 1.0; keep the face at least 1.7 wide, z -0.2..1.6 |
| TrainPush | **2.44** (place the boulder/pillar face here) | both palm faces 2.44 on every frame of the loop | palms at x +-1.4, z -0.05; face at least 4 wide |

TrainLift grip: a dumbbell welded to EACH hand. `Weld.Part0 = RightHand` (and `LeftHand`),
`C0 = CFrame.new(0, 0, 0)` with the dumbbell's long axis on the hand part's **Z** axis (front to back at
rest: hammer grip). For a dumbbell model built along its own X axis use
`C0 = CFrame.Angles(0, math.rad(90), 0)`. The render's dumbbell: handle 0.2 x 0.2 x 1.7, plates
0.78 x 0.3 x 0.78 centred 0.68 from the hand centre each way.

Throw: the food is held at the end of the right hand (RightHand bone, 0.5 stud down the fingers from the
wrist); at Release (0.7667 s) the right hand is ~3.4 studs in front of the HRP and ~1.3 above its centre.

Notes: idles are Core so the default walk/run still drives the legs when a hero moves; IdleFloat
poses the legs off the ground, so stop it before a hero walks.
