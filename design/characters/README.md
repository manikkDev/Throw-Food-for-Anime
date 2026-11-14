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
