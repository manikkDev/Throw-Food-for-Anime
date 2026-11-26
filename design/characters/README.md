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
  8 accessories against 7). REMOVED 2026-11-25 (owner: no stands in the game): moved out of his R15_Final rig and
  his template to `ServerStorage.CharacterSources.RemovedStands` (never delete). Josuke's (`pompadour_guardian`)
  Crazy Diamond went the same way (rig "Josuke (R15)" + template), and both were taken off the ZoneLab display. NO
  STANDS on any hero: the copies left in the archives (Originals_Batch4, R15_Prev, R15_PrevLayered) are not used.
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

## Batch 4: 97 more heroes (2026-11-22)

All the owner's remaining imports plus the heroes built from catalog items (`tools/studio/build_from_items.py`),
now 180 in `roster.json` (172 lane + 8 premium). Names, zones and rarities: `tools/register_new_heroes.py`
(the table in that file is the source; it writes `roster.json` and `design/zones/anime_zones.json`).

- **In-game names** are aliases, recognisable but not the franchise's name (`Rain God`, `Tide Swordsman`,
  `Blood-Stalker Girl`). `Source` (the real character) is for design files and the lab pads only.
- **Normalising** (`python tools/studio/normalize_heroes.py <json>`, `normalize_heroes.luau`): the Insert Avatar plugin
  leaves NO HumanoidDescription behind (so `build_r15.luau` says MISSING). `Humanoid:GetAppliedDescription()` gives it
  back: scales reset (1,1,1,1,0,0), fresh rig, then anything the description did not bring (hand-added accessories,
  layered clothing via `Humanoid:AddAccessory`) is carried across. Caveat: the applied description is the AVATAR's, not the
  live children: a piece deleted by hand (Igris's aura) comes back, delete it again in `R15_Final`.
  Rigs already built to the standard take `mode: inplace` (head rule + clean-up only).
- **Head rule** is automatic now: default head mesh (123480233606534) + a FaceCenter/FaceFront accessory at least 1.1 x 1.1 x 1.0
  hides the head; custom heads stay. Checked by eye in close-ups (5 per picture) on every rig: no forehead dots.
- **Layered clothing needs WrapTarget cages** on the body parts, or it balloons (Yoriichi's haori, 2026-11-22): rigs from
  `CreateHumanoidModelFromDescription` have them; an old hand-made rig does not (copy them from a working rig, same meshes).
- **Not wired into the game yet**: `config.Characters`/`config.Zones` in `design/game.json` still describe the old six zones.
  Batch 4 is in the roster, the baked templates (`Char_<id>`, 180) and the ZoneLab only.
- Rarity plan: 7 tiers exist in the game (`config.Rarities`, Secret included). Per zone every tier from Common to Legendary
  has at least one hero (the odds share a rarity's weight), Mythic in 12 zones, Secret on two heroes (Saitama, Whis).
- Archive: originals in `ServerStorage.CharacterSources.Originals_Batch4` (never delete), finals in `R15_Final` (180).
  Two heroes were named from the avatar alone and need the owner's confirmation: `Gin Ichimaru` (avatar DAVIDDDB2009) and
  `Don Lorenzo` (Blue Lock, alias `Number One Striker`).

### Standard body parts (2026-11-22, second pass)

Rigs rebuilt from an avatar's description kept that avatar's torso/arm/leg MESHES (Rthro, slim, bulky or whole-body
bundles): 34 heroes read as "lego" next to the rest. `python tools/studio/restandardize_bodies.py` finds every rig in
`R15_Final` whose body parts are not the standard R15 (torso 2 x 1.6 x 1, legs 1.22 / 1.19, ...) and rebuilds it with
torso/arms/legs = 0 in the description and every scale 1. Its head, face, clothes, body colours and every accessory
come from the OLD rig (hand edits survive); the old rig is archived in `ServerStorage.CharacterSources.R15_Prev`
(never delete). Check after any new import: all 180 templates must have the standard sizes (`work/norm/audit2.luau`).
Traps found on the way: a layered accessory's handle is not moved with the rig (reposition it from its attachment);
`Beru` was a whole-body avatar, now a dark standard body; `Nacht`'s Faust Cape was removed (the bell hid his arms and
body; the cape is kept in `R15_Prev`). `build_zone_lab.luau` now sets heroes to `ModelStreamingMode.Persistent`.

Layered clothing in Edit mode (2026-11-22): a layered garment (WrapLayer) can render floating or unfitted in Studio's
Edit mode (owner saw Nacht's cloak hover off his body). 22 layered garments were converted to plain welded accessories
(raw authored mesh on the standard body) and all looked right; Minato, Hinata and Genos stay layered because their
raw meshes sit hidden inside the body. The pre-conversion rigs are in `ServerStorage.CharacterSources.R15_PrevLayered`
(never delete). A converted garment needs no cage fitting, so it looks the same in Edit, Play and on every device.

## Frieren outfit swap (2026-11-22)
Owner supplied three catalog accessories (85968976647742 coat on BodyBack, 79448655086849 / 133247210652779 sleeve pieces on the
shoulders; loaded with `InsertService:LoadAsset`, not `insert_asset`, which 404s on catalog ids). They replaced the old collar,
front piece and skirt of `Frieren (R15)` (hero `angel_commander`). Kept: butterflies (`Spiritflies aura`), the staff on the back
(`Accessory (MeshPartAccessory)`; the owner said "sword"), and the elf hair and face (the new set has none). Old rig archived in `R15_Prev`.

## Geto outfit (2026-11-22)
The converted-to-rigid kimono (`Accessory (OutFit)`, 6.37 wide) ballooned past the arms. Restored the layered original from
`R15_PrevLayered` and scaled its handle to X 0.72, Z 0.9 so the sleeves sit on the arms (`R15_Final/Geto (R15)`), then re-baked.
Geto's forearm blocks (shirt-textured, wider than the mesh sleeve) read as flaps: `LeftLowerArm`/`RightLowerArm` are Transparency 1 in the rig.
Mahoraga (`wheel_guardian`): his full-body mesh sat 1.4 studs too high as a rigid accessory (the default head showed as a blob on his belly).
Weld lowered 1.38, Shirt/Pants removed, body recoloured white / black legs, default head hidden (HeadHidden). Rule for any layered-to-rigid
conversion: check the baked result next to the head, and remove clothing templates that the mesh replaces.

## Layered garments back, Gojo + Beru replaced (2026-11-25)
The rigid conversion of layered garments (above) put the authored mesh where the REFERENCE body's arms are, not ours: Itachi's
and Pain's robes stuck out past the hands, Yoriichi's haori stood off his shoulders, Sung Jinwoo's coat broke apart. All 17
rigs still wearing a converted garment got their layered original back from `R15_PrevLayered`
(`work/norm/restore_layered_all.luau`, the standard accessory weld). Seen in Edit on the baked templates, every one
fits. Geto: the unscaled layered outfit, forearms visible again. Kept rigid: Mahoraga (his whole-body mesh, fixed by hand).
**Do not convert layered clothing to rigid again**: the bake keeps WrapLayer accessories and the body's WrapTargets.
- Jiraiya's `Accessory (Handle)` (layered, BodyFront) was a small Naruto figure on his chest: removed.
- Gojo and Beru are the owner's new avatars (imports archived as `Originals_Batch4/gojo new (owner import 2026-11-25)` and
  `beru new (...)`), normalised (`normalize_heroes.py`) and, for Beru, `restandardize_bodies.py` (non-standard torso);
  Beru's default head is hidden under the Ant King head. Every replaced rig is in `R15_Prev` as `<name> [prev 1125]` / `[prev 1125b]`.
- The bake now welds every LAYERED accessory too (it already did rigid ones): Minato's coat was held only by a RigidConstraint,
  which the bake strips, so his template drew the coat loose (a black logo shirt, no coat). 23 layered items, all jointed.
- Geto, final answer (2026-11-25, owner: his hands looked wrong every time): NO layered outfit at all. The layered `Accessory (OutFit)`
  squeezed his arms into thin stubs with the hands poking out sideways; scaled, it hid the forearms. His classic Shirt/Pants
  (112476112968126 + pants) already draw the full kimono and kesa on normal arms, so the outfit is removed and every arm part is
  visible. Old rig: `R15_Prev/Geto (R15) [prev 1125c]`.
- Geto, owner's outfit (2026-11-25): catalog 88162273552292 "Geto Suguru Jujutsu Kaisen Outfit" (layered, BodyFront; loaded with
  `InsertService:LoadAsset`, kept in `CharacterSources.CatalogItems`) worn over his Shirt/Pants with the standard accessory weld;
  it sits on full-length arms. It replaced a first pick, catalog kimono 97488163432635 (also kept in `CatalogItems`).
  Previous rigs: `R15_Prev/Geto (R15) [prev 1125d]` (no outfit) and `[prev 1125e]` (the kimono).
- Akaza lost his hair in the layered restore (his hair and outfit are both named `Accessory (Akaza)`; the restore matched by name
  only). Hair put back from `R15_Prev/Akaza (R15) [prev 1125b]` (now `Accessory (Akaza Hair)`), the leftover rigid outfit removed.
  Every other rig of that pass was compared with its archive: same items. Match accessories by name AND attachment.

## Rare aura recoloured (2026-11-25, preview only)
Every Rare hero wears the owner's Rare aura (`JackpotGreen`, the "All Rare Characters" stand), recoloured to its theme. Its single
particle texture (10249842540) has the green baked in, so a WHITE copy of the same shape was made from the public thumbnail
(`work/rare_aura/RareFlameWhite.png`) and uploaded: rbxassetid://87752697532704. Per hero: Texture = that copy, Color = the hero's
colour (`RARE_COLOURS` in `tools/aura_assign.py`), Rate 30/s (the game's conversion had thinned it to 5.4/s; the pack's is 59/s),
Brightness 2 (the pack's 10 blew indigo/purple out to white). Not wired into the game yet: `design/auras.json` is unchanged.
- Gojo's aura (2026-11-25, preview): Crimson Moon (pack stand renamed "Gojo") + only the `Infinity Symbol` emitters of Infinite
  Reality (`EXTRAS` in `tools/aura_assign.py`), recoloured by a hand-made palette (`PALETTES`): navy-to-electric-blue dome,
  white-hot cyan sparks, a white-crested ring, a violet tail on the streaks (Hollow Purple), brightness cut from the pack's
  5-20 (stacked additive layers washed every blue to white). All the effect textures are neutral grey, so colour is per emitter.
- Julius's aura (VinnFlow, shown raw: no body rig) was placed by its bounding box (an invisible 8x10x8 part 0.7 off its own
  circles): off-centre and floating. `RAW_ANCHOR` now puts its lowest effect (the ground circle) dead centre under the root at
  the soles. Recoloured by `PALETTES["time_wizard_king"]`: time magic in gold, champagne-white highlights, amber and crimson
  shadows (his cape), the pack's purple dropped; brightness cut from 5-25. Palette keys may be `tex:<id>` (all 14 beams).
- Akaza's aura (2026-11-25, preview): Gravity God recoloured to his compass needle (`PALETTES["crimson_fist_demon"]`: ice-cyan to
  electric blue, white-hot highlights, the pack's magenta dropped, the soft quake layers kept low) and STAGED
  (`STAGING`): the quake rings and the light-column plane moved from mid-shin / overhead to the soles, and a FLOOR SIGIL under him:
  an original compass-needle drawing (`work/akaza/compass.py`: eight channel arms, hexagon plates, snowflake barbs, nodes,
  broken rings), uploaded as a crisp line layer (79305962339828) over a bloom layer (77093603756329), drawn on an unlit
  SurfaceGui (Brightness 3, 100 px/stud), 11 studs wide, plus a slow breathing pulse of the bloom. In the game the sigil must
  become a carrier part in the aura template (HeroAura already welds carrier parts); 11 studs is wider than a plot's pedestal pitch.
- Kokushibo's aura (2026-11-25, preview): RedOutline's body flames recoloured (`PALETTES["six_eyed_moon"]`: bright flames violet
  to blue, dark flames plum-crimson, sparks crimson to violet; rates raised from the A-tier thinning) plus FIVE custom layers
  (`STAGING["six_eyed_moon"].fx`, built by `build_aura_preview.luau` as shaped invisible emitter parts): moon-breathing
  crescent blades (an original drawing, `work/kokushibo/crescent.py`, rbxassetid://135460081122301) on a cylinder shell
  round him (cyan-hot to blue to violet, spinning), large faint far crescents with a crimson tail, small crimson-to-blue
  shards, a violet glow behind the body and a violet haze at the feet; a blue-violet light. In the game the fx layers must
  become carrier parts in an aura template.
- Kaido's aura (2026-11-25, preview): CyanStorm's six limb bolts recoloured white-hot to cyan to azure (from a flat Brightness-33
  blue) plus five custom layers (`STAGING["beast_emperor"].fx`): a glowing indigo-violet storm cloud round the shoulders
  (Beast Pirates; an unlit dark cloud read as dirt from above), big thunder arcs on a shell round him (an original branching
  bolt, `work/kaido/bolt.py`, rbxassetid://114181744965661), a swirling thunder shockwave on the floor (Thunder Bagua), cyan
  embers rising off the ground and an indigo glow behind him; a blue light.
- Kaido, toned down (owner: "too intense, I can't see the character"): limb bolts at 55% size, a third of the rate, brightness 3.5
  and a bluer (less white) core; thunder arcs smaller, rarer (3.5/s), dimmer, behind the body; storm cloud and glow thinner,
  fewer embers, a softer light. `PALETTES` now also takes `scale` (multiplies an emitter's Size) and `rate`.
- Kaido, balanced (owner: the toned-down pass was "too low"): halfway between the two passes (limb bolts 70% size, half rate,
  brightness 5; arcs 6/s, 2.3-2.6 studs, brightness 4.5; storm cloud 5.5/s; embers 12/s).
- Diavolo's aura (2026-11-25, preview): ShadowMonarch recoloured ONLY (owner: "already really good, just match the colour"):
  King Crimson's crimson, hot-pink (his hair) on the hottest flame cores and flares, wine-magenta smoke, deep wine shadow fire;
  every brightness, size and rate the pack's; the near-black outline layers kept (`keepDark`: a black and a blue emitter share
  the name Spec26).
- Tengen's aura (2026-11-25, preview): Cool Vapor recoloured gold / flame orange / crimson with pink dust tails, its floor
  layers dimmed (they stacked into a white glare over his legs), plus five custom layers (`STAGING["flashy_shinobi"].fx`):
  gold and rose FIREWORK bursts popping round his head and shoulders (original burst, `work/tengen/fx_textures.py`,
  rbxassetid://117907582997811), a GOLDEN FLAME RIBBON swirling at his feet, GLITTER (original four-point glint,
  rbxassetid://106676034954642) and rising EMBERS; a warm gold light.
- Douma's aura (2026-11-25, preview): Cryogen recoloured to an ice lotus (frost-white to lotus blue with an iridescent lilac/pink
  sheen; his leg shards ice blue, dust/shine dimmed: they glared white at the feet) plus original drawings
  (`work/douma/douma_textures.py`): a crisp LOTUS MANDALA on the floor (no bloom or pulse: they glared on the pedestal),
  LOTUS blooms opening and closing round his feet, ICE BUTTERFLIES with iridescent rose-violet-cyan-mint wings that flap
  (Squash) as they drift round him, and ice glints. The builder's fx now take `squash`; a floor takes `pulse: false`.
- Minato's aura (2026-11-25, preview): TitanBolt shortened (owner: "too tall") and recoloured. Its four beams ran 17 studs
  (from under the floor to far overhead): now spanned from the soles to 7.5 up, 5 wide (`STAGING["yellow_flash"].beams`);
  the streaks flew 35-65 studs/s: speed (and acceleration) cut to 22-50% (`PALETTES[...].speed`). Colour: flat yellow
  became white-hot cores into warm gold with Rasengan-blue lightning tails; a gold light.
- Jiraiya's aura (2026-11-25, preview): MUI recoloured to Sage Mode natural energy (white-hot into amber, orange and his crimson)
  plus original drawings (`work/jiraiya/jiraiya_textures.py`): a SUMMONING SEAL on the floor (script rings, spokes, the leaf
  swirl; crisp, no bloom), a RASENGAN spinning in his right hand (two vortex layers turning opposite ways, a blue light;
  fx `offset` {right, front} in the hero's frame) and rising SAGE WISPS.
- Sae Itoshi's aura (2026-11-25, preview): Red Ring of Death recoloured to his FLOW magenta (rings and intake dimmed so the numbers
  read; red embers kept) plus custom layers (`STAGING["midfield_genius"].fx`): glowing hand-written FLOW NUMBERS drifting up
  round him (a 4x4 flipbook of digits rendered from Segoe Script, `work/sae/digits.py`, rbxassetid://77269623679808; fx
  `flipbook` Grid4x4 + Random: each particle shows one), magenta flame wisps, unlit dark smoke behind him and red embers.
- PREVIEW TRAP: the platform runs ~32,000 live particles (130 auras), far over Roblox's budget, and a positioned
  `screen_capture` is taken the instant the camera arrives, before off-screen emitters have simulated: a freshly rebuilt hero
  can look aura-less. To judge one: park the camera with a delayed Scriptable CFrame, wait ~5 s, capture with NO position,
  then set the camera back to Fixed. In the game only the nearest 10 auras run, so this is a preview-only effect.
- Hisoka's aura (2026-11-25, preview): Daemon of Cards recoloured to his magenta Nen (black sparkle/glow layers kept, the pack's
  suit shapes halved) plus original drawings (`work/hisoka/hisoka_textures.py`): full-colour PLAYING CARDS (2x2 flipbook, a
  random suit each) fluttering and spinning round him, BUNGEE GUM strands stretching off both hands, his FACE MARKS (pink star,
  teal teardrop) twinkling round his head, and a magenta haze.
- SHARED STUDIO: other sessions hand-dress stands on Workspace.AuraAssignPreview; `tools/aura_assign.py build` rebuilds it and
  wipes them. Ping the other aura sessions before a build, and take turns on the camera ("CAM start" / "CAM done").
- Whitebeard's aura (2026-11-25, preview): Crystal determination recoloured from mint to shattered-air white and sky blue, plus
  original drawings (`work/whitebeard/quake_textures.py`): cracked glassy QUAKE BUBBLES charging round both fists, the AIR
  SHATTERING like glass round him, a SHOCKWAVE rippling out on the ground, GROUND CRACKS under him and falling tremor DEBRIS.
- `tools/aura_assign.py build --skip-convert --only=<heroId,...>` rebuilds ONLY those stands on the preview; use it instead of a
  full build while other sessions have hand-dressed stands.
- Whitebeard v2 (owner: the cracks "look like spider web splashing"): the air crack and quake bubble redrawn as ANGULAR glass
  fractures (`work/whitebeard/fracture.py`: straight legs with hard kinks, one level of acute forks, a few shard chords, no
  concentric rings), rbxassetid://102324797531062 and 113320563007188; the air cracks now snap open instead of growing.
- Frieren's aura (2026-11-25, preview, premium): the pack aura dropped (`noBase`) for her own magic, original drawings
  (`work/frieren/frieren_textures.py`): the white rune SPELL CIRCLE on the floor with a pale-blue copy turning over it, a
  CASTING CIRCLE (Zoltraak) rotating by her shoulder, BLUE MOONWEED blooming round her feet, drifting petals, flickering
  HEXAGONAL BARRIER panels and golden mana motes. Her Spiritflies butterflies stay.
- Power's aura (2026-11-25, preview, premium): the pack aura dropped (`noBase`) for her blood manipulation, original
  full-colour drawings (`work/power/power_textures.py`): a glossy BLOOD POOL under her, BLOOD SPIKES erupting round her, her
  spiked BLOOD HAMMER at her right hand, blood DROPLETS splashing up and falling back, a low crimson mist. Low LightEmission
  so the blood reads wet, not neon.
- Power v2 (owner: v1 "cartoon, low effort"): RENDERED blood (`work/power/blood_render.py`: height field per shape, normals,
  wet speculars, sky sheen, crevice AO, a bright lip where light passes through; a blurred-dome height for round drops).
  Layers: a scene-lit blood pool (floor `lit`), THOUSAND TERA BLOOD RAIN (spears falling tip-down round her), blood splashing
  up and falling back, her spiked blood hammer at her right hand, blood whips lashing round her body, a faint red ground
  glow and a crimson light. The dark haze was dropped (it read as dirt). Builder: floor `lit` -> SurfaceGui LightInfluence 1.
- Power v3 (owner: "no hammer, arrows and stuff, just an aura, way more advanced"): a pure layered BLOOD AURA. Rendered
  blood-flame flipbook (`work/power/aura_render.py`: hot crimson core, dark wine edges and tips, a liquid sheen) licking off
  her body parts (fx `bodyParts`: the emitter is parented to each part, so the aura follows her silhouette) and a larger
  outer shell BEHIND her (zOffset -2.5, low LightEmission so it reads as blood, not pink glow), a dark wine smoke veil,
  a crimson heart glow + light, rendered droplets floating up, slow blood streams and a crimson ground ripple. Tuned with
  every other preview emitter paused (the preview is over the particle budget), then re-enabled.
- Power tightened (owner: "spreading too much"): every layer's emitting shell cut to ~2.5 studs across, spreads to 2-4 deg
  with drag, the flame/veil/heart-glow/stream sizes and the ground ripple reduced: the aura now hugs her body.
- Frieren's casting circle moved from her right side to centred BEHIND her (offset {0, -0.9}, y 3.9, 3 studs, zOffset -2).
- Netero's aura (2026-11-25, preview): no pack (`noBase`); his 100-Type Guanyin Bodhisattva from original drawings
  (`work/netero/netero_v2.py` + `netero_textures.py`): the golden many-armed Bodhisattva (solid glowing silhouette, bright
  rim) towering behind him and breathing, a sutra halo turning behind his head, giant golden palms flashing round him,
  golden Nen off his body and rising prayer motes; a warm gold light.
- Netero v3 (owner: v2 "trash, too big"): compact. Rendered metal-gold textures (`work/netero/netero_v3.py`): a THOUSAND HANDS
  halo (18 golden palms round a double ring in a flame-edged mandorla) behind his head (2.9 studs), thin golden Nen off his
  body and a narrow flame shell behind him, small gold kanji 感謝 心 祈 drifting up, rare golden palm imprints at arm's
  length, a faint sutra ring underfoot (3.5 studs), motes. `plan` now refuses an fx missing a key (a trailing comment had
  swallowed one twice). The yard "vanishing" (2026-11-25) was it being grouped into `Workspace.Folder`: that old copy is
  in `ServerStorage.AuraAssignPreview_OldCopy` (not deleted). On the crowded preview Studio may not draw a hero's Shirt/Pants
  (Netero showed plain grey with every effect off; the template and its clothing are fine).

- Mahoraga (wheel_guardian) aura, 2026-11-25 (preview only, `STAGING["wheel_guardian"]` in tools/aura_assign.py, noBase):
  rendered textures from `work/mahoraga/mahoraga_textures.py` (DharmaWheel 101199162873719, CursedFlame 117092820695412
  (2x2), ShadowPool 100202570249582, AdaptRing 137368306775336). The gold eight-handled wheel floats above his head
  (y 6.2, 2.9 across), turning at 11.25 deg/s with a new particle every 4 s (one spoke = 45 deg, so the two live copies
  coincide); an adaptation ring pulses off it; dark violet cursed flames on a shell SIZED TO HIM (his avatar is 4.5
  studs wide: flames off body parts and a 2.2-wide veil were hidden behind him); an unlit shadow-pool floor; a few
  white-gold positive-energy motes.
  Owner, same day: "remove the flamelike thingy coming from him": CursedFlames, CursedShell and ShadowVeil removed;
  he keeps the wheel, the adaptation pulse, the shadow pool and the motes.
  v2, same day (owner: "add a cool aura, not the same basic flame thingy"): an ADAPTATION FIELD, no flames
  (`work/mahoraga/mahoraga_v2.py`): three gyroscope ORBIT RINGS (comet texture OrbitRing 136104383504235: white-hot
  head, gold tail) each in its own tilted plane via the builder's new `tilt` {pitch, roll, yaw} option, a line-art
  WheelSigil (98377888436913) turning on the shadow pool, a floor shockwave with the wheel's pulse, rising light streaks
  (Streak 120599533714425) and a few ink-black ones. Trap: a VelocityPerpendicular particle draws at TWICE its Size.
  Owner approved Mahoraga v2 ("Looks good", 2026-11-25).

- Owner, 2026-11-25: Mereoleona (crimson_lioness, was P:96) and Ace (blazing_pirate, was P:93) wear ENDEAVOR's aura
  (P:55): `WEARS` in tools/aura_assign.py (a hero moved onto another hero's aura; wins over the stand it was named on).
  Owner approved ("Looks good").
