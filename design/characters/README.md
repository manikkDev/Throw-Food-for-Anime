# Character import: state on 2026-11-14 (after section 1, before section 2)

The user imported 31 avatars by hand (R6, Load Character plugin) and chose them as the roster.
This replaces the original-trope roster in `design/game.json` and `plan/03` section 1; the
contract has NOT been updated yet (do it when the user confirms these finals).

## Where things are in the place

- `Workspace.<Name>` x31: the user's R6 originals. Untouched. Source for the rebuilds.
- `Workspace.Characters_R15` x31: the rebuilt R15 set, laid out 8 per row, rows 30 studs apart,
  with name labels. This is the candidate final set, awaiting the user's confirmation.
- Pictures: `design/characters/final/` (rows 1 to 4, two close-ups), `preview/` (R6 vs R15, pose test).

Names: Naruto Uzumaki, Sasuke Uchiha, Madara Uchiha, Itachi Uchiha, Kakashi Hatake, Goku, Vegeta,
Luffy, Luffy Wano, Zoro, Sanji, Shanks, Kaido, Doflamingo, Trafalgar Law, Tanjiro, Nezuko,
Kokushibo, Muzan, Yuji, Sukuna, Toji Fushiguro, Deku, Saitama, Garou, Ichigo Kurosaki, Asta,
Light Yagami, Esdeath, Sae Itoshi, Qin Shi Huang.
In-game display names are still to be changed (the user's own plan); the IP risk in
`research/02` D and `research/04` stands and was accepted by the user.

## How the R15 set was built (repeat this for every new character)

1. Base rig: `Players:CreateHumanoidModelFromDescription(desc, R15)` with HeightScale, WidthScale,
   DepthScale, HeadScale = 1 and **BodyTypeScale = 0, ProportionScale = 0**. A fresh
   HumanoidDescription defaults to BodyTypeScale 0.3 / ProportionScale 1, which gives a taller,
   narrower body (root at 3.19 instead of 3.00) that classic accessories do not fit.
2. If the original carries a HumanoidDescription (8 of 31): clone it, reset the six scales, build.
   Otherwise (23 of 31): copy BodyColors into the description, build, then clone Shirt, Pants and
   ShirtGraphic across and re-attach every Accessory.
3. Accessory attach = from attachments, never from the old weld: find the body Attachment with the
   same name as the Handle's Attachment, set `Handle.CFrame = bodyAtt.WorldCFrame * handleAtt.CFrame:Inverse()`,
   and create a Weld named AccessoryWeld (Part0 = Handle, Part1 = body part, C0 = handleAtt.CFrame,
   C1 = bodyAtt.CFrame). Afterwards assert every Accessory has a weld with both parts set
   (one hair came out without one and was re-welded).
4. Ground it: `PivotTo`, then lower by the foot's bottom Y. All 31 stand at y = 0.
5. **Head rule (the "two dots on the forehead" fix):** the default R15 head is 0.09 studs taller
   than the classic head, so its printed face shows above a classic full-head cover. If the rig
   has an Accessory on `FaceCenterAttachment` whose Handle is at least 1.15 in X, Y and Z, the
   cover IS the head: set `Head.Transparency = 1` and attribute `HeadHidden = true`.
   Six more (Madara, Kakashi, Goku, Vegeta, Muzan, Asta) wear a hair or hat piece that carries the face and
   fail the size rule; the default head showed around it (Vegeta's cheeks). Rule 2: if the rig still has the
   DEFAULT head mesh (123480233606534) and an anime face is visible with the head hidden, hide it. Check by eye.
   28 rigs are hidden; 3 keep the head because the head itself is the face (custom heads: Sasuke, Itachi, Nezuko).

## Measured result

31 rigs, 0 accessories without a weld, 0 off the ground, shoulder height 4.00 on 30 rigs and
3.85 on Nezuko (her saved outfit has its own torso package). Average 19 parts per rig.

## Traps found (each cost time)

- In edit mode, setting `CFrame` on each part of a welded rig moves the WHOLE assembly every
  time, so a per-part loop throws the rig far away or scrambles it. Move rigs with `PivotTo` only.
- `screen_capture` returns a blank dark frame while the Studio window is minimised; restore the
  window first. Right after building rigs, meshes have not loaded yet: capture again.
- A wide shot makes side figures look turned: judge faces only from a centred close-up.
- R6 originals built by the plugin: Nezuko and Asta use `CharacterMesh` (R6 only). In R15, Asta
  gets the standard body.
- Three saved outfits carry items the R6 imports did not show: Kakashi (lightning aura on the
  shoulders), Light Yagami (figure on the shoulder), Itachi (eyebrows). They are in the R15 set.

## Baked on 2026-11-14 (section 2)

`tools/studio/bake_characters.luau` turned the 31 rigs into templates under
`ReplicatedStorage.Assets.Characters` (`Char_<id>`, ids from `roster.json`): 15 hand-built
Motor6Ds each, every accessory welded, about 103 instances per hero (was 314), root anchored and
pivoting at the feet, Humanoid kept with its state machine off. `Humanoid:BuildRigFromAttachments`
does NOT produce Motor6Ds in this Studio (it rebuilds the physics constraints), so the bake builds
the joints from the RigAttachment pairs. The Workspace sets were then archived:
`ServerStorage.CharacterSources.R15_Final` and `.R6_Originals`. Measured in play: 135 heroes
(2,521 parts, 130 idle tracks) held 60 fps on the dev PC; a phone is still untested.

## Still to do

- User confirmation of the finals, then: update `config.Characters` (zones, rarities, cravings,
  idle clips for these 31), `plan/03`, `out_of_scope`, and HANDOFF.
- Section 3: write `assets/meshes/manifest.json` entries for the 31 rigs, and source avatars for the 8 premium heroes (they render as neon placeholders until then).
- Not yet tested: real animations in a running game on these rigs; phone performance with many.
- Sleeve accessories (Ichigo) do not bend at the elbow: give those characters gentle-elbow idles.

## Batch 2: 12 more heroes (2026-11-14, section 3)

Guts, Sung Jinwoo, Killua, Eren Yeager, Obito Uchiha, Eren Titan, Lelouch, Cid Kagenou, Joseph
Joestar, Diavolo, Dio Brando, Jotaro Joestar. Roster is now 43 (7 per zone, plus the Mythic).

- This time the plugin imported them as **R15 with the wearer's own body scales**: shoulder height
  ran from 3.68 (Joseph) to 5.01 (Lelouch) studs, BodyTypeScale from 0 to 1. Every one carried a
  HumanoidDescription, so the rebuild is: clone it, set Height/Width/Depth/Head = 1 and
  BodyTypeScale/ProportionScale = 0, `CreateHumanoidModelFromDescription`. Result: all 12 at
  shoulder 4.00, root 3.00, every accessory welded, feet on y = 0.
- The tool is `tools/studio/build_r15.luau` (edit its LIST, run it with `studio_mcp.py luau --file`;
  it yields, so the report is read back from the `TFABuild` attribute). It also copies across
  anything the description did not bring and re-welds any accessory more than 0.05 studs off its
  attachment.
- Head rule as code (same two rules as batch 1): hide the head when a FaceCenter accessory is at
  least 1.15 in X, Y and Z, OR when the head is still the default mesh 123480233606534 (its printed
  face shows as the forehead dots). Hidden: Guts, Killua, Obito, Lelouch, Cid, Joseph, Diavolo, Dio,
  Jotaro. Kept (the custom head IS the face): Sung Jinwoo, Eren Yeager, Eren Titan. Checked in four
  close-up pictures: `final/batch2_*.jpg`, one face each, no dots.
- Jotaro's saved outfit carries one item the import did not show (his stand figure on the shoulder,
  8 accessories against 7). Kept, like Kakashi's and Light Yagami's extras in batch 1.
- Three rigs have one layered-clothing item (Sung Jinwoo's coat, Cid, Jotaro); the bake keeps their
  WrapTargets.
- Archive: the finished rigs are in `ServerStorage.CharacterSources.R15_Final` (43); the owner's 12
  imports are in `ServerStorage.CharacterSources.Originals_Batch2` (never delete).
- Bake: `python tools/studio/run_bake.py` fills the roster line from `roster.json` and runs the
  bake; it fails unless every hero comes out with 15 motors. 43 templates, checked in Play: all 12
  new ones load and play an idle (12 of 12 animated).
- Adding heroes no longer moves the economy: heroes of one rarity SHARE that rarity's weight
  (`Core/Roll.heroWeights`, two specs), so a zone's rarity odds are the same with 5 heroes or 50.

### To add the next batch
1. Import the avatars into Workspace (any rig type). 2. Put their names in `build_r15.luau` LIST and
run it. 3. Look at close-ups; apply the head rule. 4. Add rows to `design/game.json`
`config.Characters` (zone, rarity, craving, idle), `roster.json`, `meshes.json` and `asset_plan`;
update each zone's `Slots`; `gen_config.py`. 5. Move rigs to `R15_Final`, originals to an
`Originals_Batch<N>` folder. 6. `run_bake.py`, then `python tools/gate.py`.

## Batch 3: 16 more avatars (2026-11-14, section 3)

Tengen Uzui, Aizen Sosuke, Ken Kaneki, Frieren, Lawliet, Denji, Power, Naoya Zenin, Makima, Megumi
Fushiguro, Marin Kitagawa, Ayanokoji, Subaru Natsuki, Mahoraga, Zenitsu Agatsuma, Yoriichi Tsugikuni.
Same route as batch 2 (`tools/studio/build_r15.luau`, all had a HumanoidDescription). Shoulder 4.00
on 12; four keep a body package and sit within 0.15 of it (Frieren 4.08, Megumi 4.03, Makima 3.85,
Marin 3.99). Head hidden on 12 (cover or default head), kept on 4 with custom heads (Aizen, Makima,
Mahoraga, Yoriichi). Checked in close-ups: `final/batch3_*.jpg`.

- 8 became lane heroes (51 lane heroes, 8 or 9 per zone, two Mythics in the last zone).
- 8 became the PREMIUM set: the ids stay (`starlight_idol` ... `sakura_shogun`, because products and
  saved profiles refer to them) and the display names changed: Cosplay Star, Sweet-Tooth Detective,
  One-Eyed Ghoul, Control Devil, Elf Archmage, Illusion Overlord, Blood Fiend (starter pack), First
  Sun Swordsman (limited). `roster.json` maps each id to its avatar and marks them `Premium`.
- Archive: `ServerStorage.CharacterSources.Originals_Batch3` (16, never delete); `R15_Final` holds 59.
- Sizes on the plot were cut to Big 1.2 / Huge 1.4 / Titan 1.7 (`config.Sizes`): at 2.2 a Titan was
  8.8 studs wide on pedestals 7 studs apart and stood on its neighbours.

## Edits to imported avatars

- 2026-11-15: Copy Ninja (Kakashi Hatake): the accessory `Dragon_Head_Lightning_01_White` (a black dragon round the body) was removed from `R15_Final` and the baked template at the owner's request. The untouched original stays in `R6_Originals`.
