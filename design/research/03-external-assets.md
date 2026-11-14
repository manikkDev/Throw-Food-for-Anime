# 03 - External assets and Roblox platform facts

Research date: 2026-11-14. Web only (no downloads, no Studio tests). Scope: everything OUTSIDE the
Roblox Creator Store, plus Roblox platform facts for the character route.

Conventions used below:

- "Opened" = the page itself was fetched and read today. Everything stated as fact comes from an opened page.
- "(snippet only)" = seen in a search result, page not opened or blocked. Treat as a lead, not a fact.
- UNKNOWN = could not be verified from an opened page. Several of these are cheap to settle with a
  two-minute Studio test; those are listed in section 8.
- Poly counts are almost never published on pack pages. Where a number exists it is quoted; otherwise UNKNOWN
  (measure after download, before import).

---

## 0. Headline conclusions

1. **Characters: do not use external models.** No external source offers 60-120 anime-style humanoids that
   are both legally clean and cheap to convert to R15. The realistic route is Roblox avatar items applied
   through `HumanoidDescription` (zero rig conversion, native R15, native animation). Details in sections 3 and 4.
2. **Food: Quaternius (CC0) is the primary source**, because its Sushi Restaurant Kit is the only CC0 pack
   found that contains the Japanese hero items (ramen, udon, onigiri, dango, nigiri, rolls, gyoza, steamed bun).
   Kenney Food Kit (CC0) fills western items. Six items on the wish list have no CC0 source and must be generated.
3. **Environment: Quaternius again for consistency** (torii, sakura tree, bamboo, shoji walls, nature kit),
   with the reodesuxz Japanese packs (custom free-commercial licence, not CC0) as the fallback for pagoda,
   shrine hall, stone lanterns, koi pond.
4. **Fonts: Fredoka One, Luckiest Guy and Bangers are built into the engine.** Titan One is not in the
   built-in list.
5. **Music: use Roblox's Creator Store audio.** Uploading outside music is possible but adds licence and
   fingerprint-screening risk for no real gain.

---

## 1. Food props

### 1.1 Sources opened

| Source | URL | Licence (sentence that matters) | Commercial | Attribution | Formats | Polys | Style | Usable items |
|---|---|---|---|---|---|---|---|---|
| Quaternius - Sushi Restaurant Kit | https://quaternius.com/packs/sushirestaurantkit.html | Page field "License: CC0" (links to CC0 1.0). | Yes | No | FBX, OBJ, Blend, glTF | UNKNOWN per model. The Sketchfab upload of the whole kit shows 116.9k triangles for 100+ models (roughly 1k each on average) | Stylised low poly, textured | 108 models (May 2023). About 35 are food; the rest are interior pieces, 6 animated characters, props |
| Quaternius - Ultimate Food Pack | https://quaternius.com/packs/ultimatefood.html | "License: CC0"; "free to use in personal and commercial projects." | Yes | No | FBX, OBJ, Blend | UNKNOWN | Low poly, flat colours (page marks it not textured) | 103 models (Oct 2019); Poly Pizza lists 50 of them by name |
| Kenney - Food Kit | https://kenney.nl/assets/food-kit and https://kenney-assets.itch.io/food-kit | "CC0 1.0 Universal"; "You're allowed to use these game assets in any project including commercial ones."; "giving attribution is not required" | Yes | No | OBJ, FBX, glTF | UNKNOWN | Kenney flat-colour low poly | kenney.nl says 200 files, version 2.0 "Completely remade". Poly Pizza still lists the 2022 version with 148 named models |
| KayKit - Restaurant Bits | https://kaylousberg.itch.io/restaurant-bits | "Creative Commons Zero v1.0 Universal"; "Free for personal and commercial use, no attribution required." (plus a request not to resell unmodified copies) | Yes | No | OBJ, FBX, GLTF | UNKNOWN ("low poly optimized") | Chunky stylised, one 1024x1024 gradient atlas (can be downsampled to 128) | 140+ free (75+ more in the paid $7.95 tier). Foods are split by ingredient and state (raw/cooked/chopped). Individual names not listed on the page |
| Felipe Greboge - Low Poly Food Pack | https://greboge.itch.io/low-poly-food-pack | "Creative Commons Zero v1.0 Universal" | Yes | No | .glb only | UNKNOWN | Very low poly, single shared palette texture (Imphenzia PixPal). A commenter reported meshes arriving grey in Unreal, so the palette material needs re-linking on import | 289 meshes: vegetables 67, fruits 41, pork 22, beef 27, chicken 9, eggs 17, fish and sushi 41, utensils 47, misc 18 |
| 3DModelsCC0 - Free CC0 Food & Drinks | https://3dmodelscc0.itch.io/free-cc0-food-drinks | "all offered under a CC0 public domain license." | Yes | No | UNKNOWN (single .rar, 35 MB) | UNKNOWN | Early, lower-quality pack by the author's own description; tagged "No generative AI was used" | 10: baked pizza, canned foods, canned tuna, coffee, frozen pizza, hamburger, hot dog, ice cream, milk, sushi |
| Poly Pizza (aggregator) | https://poly.pizza | Per model. Bundle and model pages show a badge such as "Public Domain (CC0)". The site's own licence page could not be found (two URL guesses returned 404), so the CC-BY wording is UNKNOWN | Per model | Per model | FBX, glTF | Not shown | Mixed | Use it as a per-model browser for Quaternius and Kenney packs, not as a licence authority |

Licence discrepancy to be aware of: the Sketchfab mirror of the Sushi Restaurant Kit
(https://sketchfab.com/3d-models/sushi-restaurant-kit-100-models-19605b53f8fe45bcbe167fab1bac43ed) has its licence
field set to CC Attribution while its description says CC0. Download from quaternius.com, where the field is CC0.

### 1.2 Named models (from opened Poly Pizza bundle pages, all badged "Public Domain (CC0)")

Quaternius "Modular Sushi Restaurant Kit" bundle (86 of the 108 models are listed,
https://poly.pizza/bundle/Modular-Sushi-Restaurant-Kit-LJZrZsNPM7). Food and Japanese props:
Ramen, Udon, Onigiri, Rice Ball, Dango, Gyoza, Chukaman, Chukaman Steamer, Maguro Nigiri, Salmon Nigiri,
Ebi Nigiri, Octopus Nigiri, Tamago Nigiri, Salmon Roll, Sushi Roll, Sea Urchin Roll, Sea Urchin, Sea Urchin Open,
Ebi, Crabsticks, Wasabi, Shimesaba, Fish Fillet, Salmon, Squid, Tentacle, Avocado, Cucumber, Sliced Cucumber,
Bowl, Plate, Bottle, plus Torii Gate, Sushi Truck, Shoji Wall, Japanese Door.
The GDevelop listing of the same kit (https://gdevelop.io/asset-store/free/3d-sushi-restaurant-3d-sushi-restaurant)
additionally names Sakura Tree, Sakura Flower, Bamboo, Bell, Nori, Rice, Eel, Mackerel, Flounder.

Quaternius "Ultimate Food Pack" bundle (50 listed, https://poly.pizza/bundle/Ultimate-Food-Pack-h3WC1gyRb4):
Burger, Cheeseburger, Double Cheeseburger, Pizza, Pizza Slice, Ice Cream, Popsicle, Popsicle Chocolate, Donut,
Cupcake, Hotdog, Corndog, Fries, Waffle, Pancakes Stack, Croissant, Bread, Chicken Leg, Steak, Bacon, Egg Fried,
Apple Green, Banana, Avocado, Carrot, Tomato, Broccoli, Pumpkin, Chocolate Bar, Soda, Sushi, Sushi Nigiri, Chopsticks.

Kenney "Food Kit" bundle (148 listed, 2022 version, https://poly.pizza/bundle/Food-Kit-vOc58LJ0ge):
Apple, Apple Half, Burger, Burger Cheese, Pizza, Pizza Box, Cake, Cake Birthday, Cupcake, Ice Cream, Sundae,
Popsicle, Donut Sprinkles, Donut Chocolate, Hot Dog, Corn Dog, Fries, Taco, Sandwich, Sub, Pancakes, Waffle,
Croissant, Cookie, Muffin, Pie, Pudding, Turkey, Whole Ham, Watermelon, Pineapple, Banana, Strawberry, Cherries,
Sushi Egg, Sushi Salmon, Rice Ball, Bowl Broth, Bowl Soup, Chinese (takeaway box), Steamer, Soy, Skewer Vegetables,
Lollypop, Chocolate, Candy Bar Wrapper, Soda Can. Names in the 2.0 remake are UNKNOWN until the zip is opened.

### 1.3 Recommendation and coverage

**Primary: Quaternius Sushi Restaurant Kit**, extended with the same author's Ultimate Food Pack.
One author, CC0, formats Blender reads directly. Fallback and gap filler: Kenney Food Kit.

| Wanted item | Covered by | Note |
|---|---|---|
| Ramen bowl | Quaternius Sushi Kit "Ramen" (also "Udon") | Hero item, confirmed CC0 on its model page https://poly.pizza/m/DTOzkHhvDK |
| Onigiri | Sushi Kit "Onigiri", "Rice Ball" | Kenney "Rice Ball" as alternate |
| Dango | Sushi Kit "Dango" | |
| Sushi | Sushi Kit nigiri x5, rolls x3 | Gives several throwables from one family |
| Ice cream | Ultimate Food Pack "Ice Cream" | Kenney "Ice Cream", "Sundae", "Popsicle" |
| Burger | Ultimate Food Pack "Burger", "Cheeseburger" | |
| Pizza | Ultimate Food Pack "Pizza", "Pizza Slice" | |
| Apple | Ultimate Food Pack "Apple Green" | Kenney "Apple" if red is wanted |
| Cake | Kenney Food Kit "Cake", "Cake Birthday" | Quaternius only has "Cupcake" |
| Bonus Japanese | Sushi Kit "Gyoza", "Chukaman" (steamed bun), "Udon" | Not on the list, free variety |
| **Takoyaki** | GAP | Poly Pizza has "Takoyaki" by sugamo; its licence was not opened (UNKNOWN) |
| **Bento** | GAP | Nothing free found (Poly Pizza search returned no bento) |
| **Mochi / daifuku** | GAP | Only "kagami-mochi" by sugamo on Poly Pizza, licence UNKNOWN |
| **Taiyaki** | GAP | Nothing found |
| **Tempura** | GAP | Nothing found. Sushi Kit "Ebi" (shrimp) is the nearest shape, but it is not tempura |
| **Curry rice** | GAP | Nothing found |

With bonus items the two Quaternius packs plus Kenney give roughly 25-30 throwables without touching the gaps.
The six gaps are small single props: generate them with the project's `roblox-3d-model` skill (paint to match the
flat-colour look) rather than buying a paid Japanese food pack. Paid packs that do contain them were only seen as
search snippets (CGTrader "Japanese food pack" at $10.99) and are not recommended.

Style caution: the Sushi Kit is marked textured, the Ultimate Food Pack and Kenney kit are flat-coloured.
Judge them side by side in Blender before committing; a re-bake to one palette may be needed.

---

## 2. Stylised Japanese / anime environment props

### 2.1 Sources opened

| Source | URL | Licence | Commercial | Attribution | Formats | Polys | Relevant content |
|---|---|---|---|---|---|---|---|
| Quaternius - Sushi Restaurant Kit | https://quaternius.com/packs/sushirestaurantkit.html | CC0 | Yes | No | FBX, OBJ, Blend, glTF | see section 1 | Torii Gate, Sakura Tree, Sakura Flower, Bamboo, Shoji Wall, Shoji Interior, Japanese Door, Red Wood Wall, Arch, signs x3, wall light, bell, Sushi Truck (usable as a market stall), benches, stools, tables |
| Quaternius - Stylized Nature MegaKit | https://quaternius.com (pack list) and https://poly.pizza/bundle/Stylized-Nature-MegaKit-T34GZFA0fm | "Public Domain (CC0)" | Yes | No | FBX, glTF on Poly Pizza | UNKNOWN | 68 listed: trees x5, twisted trees x5, pines x5, dead trees, bushes, grass, ferns, flowers, flower petals x5, rocks x3, rock paths x10, pebbles x11. The Quaternius home page tags this kit "Ghibli". No sakura, bamboo or clouds |
| Quaternius - Ultimate Stylized Nature Pack | https://quaternius.com/packs/ultimatestylizednature.html | CC0; "free to use in personal and commercial projects." | Yes | No | FBX, OBJ, glTF, Blend | UNKNOWN | 63 models "with seamless textures and normal maps". Contents not itemised; no sakura/bamboo mentioned |
| Quaternius - Ultimate Fantasy RTS | https://poly.pizza/bundle/Ultimate-Fantasy-RTS-nSDjmACoSU | "Licence: Public Domain (CC0)" | Yes | No | FBX, glTF | UNKNOWN | 107 listed: Temple x6 variants, Market Stalls x5, Village Market, mountains, rocks, walls, docks. Tags are "Medieval / RTS"; whether the temples read as Japanese is UNKNOWN (not viewed) |
| reodesuxz - Low Poly Japanese Town Pack | https://reodesuxz.itch.io/low-poly-japanese-town-pack | Custom: "Free for personal and commercial projects. No attribution required." and "Please do not resell or redistribute the files." | Yes | No | FBX, GLB, OBJ, one .blend | 4,376 triangles for the whole pack | 31 models: torii gates, shrine hall, pagoda, castle tower, stone lanterns, vending machines, ramen shop, sakura tree, koi pond "and more". Flat colour, no textures. itch tag "No generative AI was used" |
| reodesuxz - Low Poly Japanese Shrine Pack | https://reodesuxz.itch.io/low-poly-japanese-shrine-pack | Same custom licence | Yes | No | FBX, GLB, OBJ, .blend | 2,768 triangles total | 29 models in Architecture / Props / Nature. Names not listed |
| reodesuxz - other packs (thread only) | https://itch.io/t/7120179/48-new-free-game-asset-packs-24-low-poly-3d-24-pixel-art-2d | Thread states "Commercial use OK, no attribution required." and "Don't resell the raw packs." | Yes | No | FBX, GLB, OBJ, .blend | per-pack totals in thread | Japanese Castle Town (26), Sushi & Japan Street (29), Farmers Market (26), Alchemy Market (27). Individual pack pages not opened |
| Poly Pizza search results | https://poly.pizza/search/torii , /sakura , /bamboo , /japanese%20lantern | Per model, NOT opened individually: UNKNOWN | - | - | - | - | Leads only: "Torii Gate" (Hattie Stroud), "Japanese Torii" (Jacques Fourie), "Japanese Stone Lamp" (Flopsi), "Bamboo" and "Bamboo Mid" (Quaternius), "Hanging Lantern" / "Post Lantern" / "Lantern" (Kay Lousberg), "Cherry tree" and "Pagoda" (Poly by Google), "Bamboo Fence Panel" (Jarlan Perez) |

Checked and found empty: Kenney's 3D category page 1 (16 packs) has no Japanese or Asian themed kit
(pages 2-4 not opened); KayKit's pack list has no Japanese-themed pack; Poly Pizza's 115 bundles contain no
bundle named Japanese, sakura, torii, temple, ninja or samurai. Blocked: itch.io tag browse pages (HTTP 403).

Note on the reodesuxz packs: the author released 48 packs at once and the licence is a plain-language custom
grant, not CC0. It allows commercial games. The "do not redistribute the files" clause means the meshes should be
uploaded to Roblox as private/Restricted assets and never listed on the Creator Store. Each zip is said to contain
a README and licence file; that file was not read (UNKNOWN) and should be read before use.

### 2.2 Recommended consistent set

| Need | Take from | Status |
|---|---|---|
| Torii gate | Quaternius Sushi Kit "Torii Gate" | CC0, confirmed |
| Sakura trees | Quaternius Sushi Kit "Sakura Tree" (+ "Sakura Flower", MegaKit "Flower Petal" for falling petals) | CC0. Only one tree: recolour/scale variants |
| Bamboo | Quaternius Sushi Kit "Bamboo" | CC0 |
| Rocks, paths, grass, bushes, background trees | Quaternius Stylized Nature MegaKit | CC0 |
| Market stalls | Quaternius "Sushi Truck" + Ultimate Fantasy RTS "Market Stalls" | CC0; style match UNKNOWN |
| Dojo / shrine hall, pagoda | reodesuxz Japanese Town / Shrine packs | Custom free-commercial licence |
| Stone lanterns, koi pond | reodesuxz Japanese Town pack | Same |
| Paper lanterns | GAP in CC0 packs opened. Trivial to build from Roblox parts with a PointLight | Build in-engine |
| Fences, bridges | Not confirmed in any opened pack (reodesuxz lists are incomplete: UNKNOWN) | Build from parts or generate |
| Clouds | Nothing found | Build in-engine (parts/meshes) or generate one mesh and reuse |
| Walls / doors for buildings | Quaternius Sushi Kit shoji walls, Japanese Door, Red Wood Wall | CC0 |

Primary = Quaternius for everything it covers; reodesuxz only for the Japanese architecture Quaternius lacks.
Both are low poly, but one is textured and one is flat colour: put a torii from each side by side before mixing.

---

## 3. Anime-style humanoid characters outside Roblox

What "becoming an R15 character" requires (Roblox docs, opened):

- 15 MeshParts (`UpperTorso_Geo`, `LowerTorso_Geo`, upper/lower arm and hand x2, upper/lower leg and foot x2, `Head_Geo`)
  on the standard R15 joints, with named attachments, or a skinned mesh on that skeleton
  (https://create.roblox.com/docs/art/characters/specifications).
- Marketplace bodies: total 10,742 triangles (head 4,000; torso 1,750; each limb 1,248).
- Any single mesh: "Individual meshes can not exceed 20,000 triangles"; "A vertex can not be influenced by more than 4
  bones or joints" (https://create.roblox.com/docs/art/modeling/specifications).
- Studio's Avatar Setup tool can generate rig, skinning, cages, 15-part partitioning and attachments from a body mesh.
  Its "Development Avatar" preset is described as intended for "non-player characters (NPCs) or starter player
  characters for your games" and "generates a less restrictive setup" (https://create.roblox.com/docs/avatar-setup).
  Input requirements (https://create.roblox.com/docs/avatar-setup/auto-setup-requirements): humanoid shape in A- or
  T-pose facing -Z, watertight, distinct neck, 2 eyes and 3 mouth parts as separate geometry, at least one texture,
  and the body must NOT include "hair, eyebrows, beards, and eyelashes". Hair and clothes must be separated and
  processed as accessories bundled with a base body. It is an interactive Studio tool, one character at a time.

| Source | URL opened | Licence | Anime style? | Count | Formats / rig | Work to reach R15 | Verdict |
|---|---|---|---|---|---|---|---|
| VRoid Hub | https://vrm.dev/en/vrm/meta/license/ (VRM licence fields). VRoid Hub help, developer guidelines and model search pages all returned HTTP 403 | Per model, chosen by the uploader. VRM meta carries "For commercial use: Disallow / Allow" and a licence type from "Redistribution Prohibited", "Copyright wavier (CC0)", CC_BY, CC_BY_NC, CC_BY_SA, CC_BY_NC_SA, CC_BY_ND, CC_BY_NC_ND, "Other". Whether the Hub UI has a CC0 / commercial-OK search filter: UNKNOWN | Yes, strongly | Large; share that is downloadable and commercial-OK is UNKNOWN | .vrm (glTF-based), humanoid skeleton plus secondary bones | Very high per model: licence check per model; decimate to Roblox limits; bake the toon materials to one texture; strip and separate hair/eyebrows/clothing; run Avatar Setup or re-skin to R15 in Blender; fix weights; test. The VRM licence page also never says game use is covered; it speaks about avatar use in VR/communication | Not viable for 60-120 characters. Also high IP risk: many Hub models are fan likenesses |
| VRoid Studio sample models | (snippet only: OpenGameArt "VRoid Studio CC0 models"; page returned 403; vroid.com guidelines returned 403) | Reported CC0 for alpha-era samples: UNKNOWN from an opened page | Yes | A handful | .vrm | Same conversion work as above | Lead only |
| Quaternius - Universal Base Characters | https://quaternius.com/packs/universalbasecharacters.html | CC0; "Free to use in personal, educational and commercial projects." | Not described as anime. Realistic-stylised proportions (Superhero, Regular, Teen) | 6 bodies, 20 hairstyles; "60-70%" free in the Standard tier | OBJ, FBX, glTF; humanoid rig for retargeting; about 13k triangles average | High: 13k average exceeds the 10,742 marketplace total, hair is separate (good), still needs Avatar Setup or manual re-rig per body, and clothing is not included | Useful only as ONE custom base body, not as a roster |
| Quaternius - Ultimate Modular Women / Men | https://quaternius.com/packs/ultimatemodularwomen.html , bundle list on Poly Pizza | CC0 | No (generic low-poly people) | 10 women, 11 men; each split into 4 swappable parts; 24 animations | FBX, OBJ, glTF, Blend; "humanoid rig version also included" | High: own skeleton, must be re-rigged to R15 | Wrong style |
| Quaternius "Ultimate Anime ..." | Site pack list opened (84 packs) | - | - | No pack with "anime" in its name exists in the list | - | - | Does not exist |
| KayKit - Adventurers | https://kaylousberg.itch.io/kaykit-adventurers | "Creative Commons Zero v1.0 Universal"; "Free for personal and commercial use, no attribution required. (CC0 Licensed)" | No. Chibi fantasy (knight, mage, barbarian...) | 5 free, 8 with the $7.95 tier | FBX, GLTF; "fully rigged and animated"; one 1024 gradient atlas | Medium-high: custom KayKit rig ("Rig_Medium"), not R15; needs re-rig. The separate free animation pack (161 animations) says it works in Roblox, but that is for their own rig | Wrong genre, too few |
| Polygonal Mind - 100 Avatars R1 / R2 | https://poly.pizza/bundle/100-Avatars-R1-amJ23JjkKG | "Public Domain (CC0)" | No. Quirky low-poly mascots (Watermelon Character, Astronaut, Old Guy...) | 73 + 94 on Poly Pizza | FBX, glTF | High: per-character re-rig | Wrong style |
| Mixamo | Adobe's FAQ page returned HTTP 403. Opened instead: a 2022 community-forum FAQ post (author not identified as Adobe staff) | That post says games are allowed, no royalties, no credit needed, and "really the only thing you can't do is distribute the raw character and animation files." Official current terms: UNKNOWN. Whether uploading the mesh to Roblox as an asset counts as distributing raw files: UNKNOWN | No (realistic / generic) | Dozens | FBX, Mixamo skeleton | High, and the animations target the Mixamo skeleton | No |
| Sketchfab CC0 anime / chibi packs | Search only; https://sketchfab.com/licenses describes only store Standard/Editorial licences | Per model | Some | No CC0 anime pack confirmed | varies | High | No pack found |
| itch.io / OpenGameArt leads | (snippet only) styloo "Chibi Characters", OpenGameArt "Base Rigged Stylized Humanoid Character (YW)" tagged CC0/anime | UNKNOWN | Partly | 1 to a few | varies | High | Leads only |

### Conclusion for section 3

No external source is realistically better than assembling characters from Roblox avatar items.
The blockers are the same everywhere: (1) nothing CC0 is both anime-styled and available in the dozens,
(2) every external rig needs per-character conversion (strip hair, decimate, re-skin or Avatar Setup, fix, test),
which for 60-120 characters is weeks of semi-manual work that the team said it will not do, and
(3) the truly anime-looking supply (VRoid Hub) is per-model licensed and heavy with fan likenesses.

If a custom look is ever wanted, the cheapest hybrid is ONE custom anime base body (made or converted once through
Avatar Setup's Development Avatar preset) dressed with catalogue hair and classic clothing. That is an option for
later, not the roster plan.

---

## 4. Roblox platform route for characters

### 4a. HumanoidDescription, CreateHumanoidModelFromDescription, ApplyDescription

Opened: https://create.roblox.com/docs/characters/appearance , the Players, Humanoid, HumanoidDescription and
InsertService class pages (Markdown versions), the AssetTypeVerification enum page, and three DevForum announcements.

**API names changed.** The non-Async methods are now marked deprecated and "superseded by" Async twins that
"should be used in new work":

- `Players:CreateHumanoidModelFromDescriptionAsync(description, rigType, assetTypeVerification?)` returns a character Model.
- `Players:GetHumanoidDescriptionFromOutfitIdAsync(outfitId)`: "can be user-created or the outfit of a Roblox-created bundle"
  (paraphrased from the page). `Players:GetHumanoidDescriptionFromUserIdAsync(userId)`.
- `Humanoid:ApplyDescriptionAsync(description, assetTypeVerification?)` and `Humanoid:ApplyDescriptionResetAsync(...)`
  (the Reset variant is for characters changed outside the description system).

All yield. All list "Security: None", thread safety Unsafe, capability AvatarAppearance (plus Players for the
Players methods).

**What a description can carry** (docs): scale; accessories (`HatAccessory`, `HairAccessory`, `FaceAccessory`,
`NeckAccessory`, `ShouldersAccessory`, `FrontAccessory`, `BackAccessory`, `WaistAccessory`, each a comma-separated
string of asset ids); classic clothing (`Shirt`, `Pants`, `GraphicTShirt`, each must be an asset of that exact
type, not a Decal or Image); body parts (`Head`, `Torso`, `LeftArm`, `RightArm`, `LeftLeg`, `RightLeg`, `Face`);
body colours; animations; emotes (`AddEmote`, `SetEmotes`, must be Emote assets); `MoodAnimation` and
`StaticFacialAnimation` for dynamic heads. Layered clothing goes through
`SetAccessories({ {Order=, AssetId=, AccessoryType=} ... }, includeRigidAccessories)`.
Bundles are not a property: use the bundle's outfit id with `GetHumanoidDescriptionFromOutfitIdAsync`, or set the
individual body part ids listed in the bundle.

**Does the experience have to own the items? Technically no.**

- None of the opened API pages mention an ownership check for description assets.
- The InsertService page states that "benign asset types such as t-shirts, shirts, pants and avatar accessories are
  loadable from any game" because they are OpenUse.
- The Avatar Team announcement of 7 Oct 2025
  (https://devforum.roblox.com/t/potential-action-required-update-for-humanoiddescription-apis/3982903) changed the
  default `assetTypeVerification` to `Enum.AssetTypeVerification.Always` from 27 Oct 2025. Experiences that "only load
  standard avatar assets from the catalog" need no action. The check is on asset TYPE, not ownership: with `Always`,
  only genuine catalogue avatar assets in the correct slot will load. Custom, non-catalogue assets need
  `ClientOnly` passed explicitly.
- Price is therefore technically irrelevant for NPCs: a paid item loads the same as a free one.

**Policy, not technology, is the open question.**

- The 2023 "Experiences using Marketplace Items" policy
  (https://devforum.roblox.com/t/experiences-using-marketplace-items-policy-update/2605893) targeted experiences that
  let USERS equip Marketplace items they have not bought (purchase prompt required, no off-sale items). Its rollout
  was paused on 19 Sep 2023. The post does not mention NPCs. Whether it was later finalised: UNKNOWN (no later
  announcement found; the Community Standards page returned HTTP 403).
- Marketplace Policy (https://create.roblox.com/docs/marketplace/marketplace-policy) governs item creators, not NPC
  use, but states the IP rule that matters: "If you are not the original creator or owner of the IP, you must have
  permission from the IP owner to sell their content or inspired content."
- Practical reading: dressing NPCs in catalogue items is technically supported and widely done; the residual risks
  are (1) UGC items that copy a real anime character (the item can be moderated and then stops loading, and a roster
  of named-character lookalikes is an IP exposure for a monetised game), and (2) a future revival of the 2023 policy.
  Mitigate by preferring Roblox-made items and generic "anime-style" UGC, never items named after or cloning a show.

**Accessory limit per character: no official number.** The HumanoidDescription page states no limit per type or in
total. Community reports (snippets only, not opened): the in-game avatar editor allows 3 hats and 1 each of hair,
face, neck, shoulder, front, back, waist, with a cap of 10 rigid accessories; and a July 2026 bug report mentions an
"Accessory Limit Method" in Universe Avatar Settings interacting with `HumanoidDescription.UseAvatarSettings`.
The Avatar Settings announcement of 21 Jul 2025 (opened) confirms experience-level controls that can "Remove or
Replace items based on their category" and that "If your experience uses a StarterCharacter, Avatar Settings will
not have an effect", but gives no numbers and does not mention NPCs. Treat the limit as UNKNOWN and test
(section 8). Design the roster to need at most 1 hair + 1-2 other accessories and it cannot matter.

**Studio edit mode and server runtime.**

- Server runtime: yes. All doc examples are server Scripts.
- Client: docs are silent; forum posts disagree (snippets only). Do not design around client-side ApplyDescription.
- Edit mode (command bar / plugin / Studio MCP `execute_luau`): docs do not say. One forum reply (snippet only) says
  edit-time calls are unaffected by the 2025 change. UNKNOWN until tested. Remember these methods yield, and this
  project's CLAUDE.md notes that `execute_luau` drops output if the script yields.

**Recommended pattern:** build each roster character ONCE at edit time (or in a one-off server run) with
`CreateHumanoidModelFromDescriptionAsync`, store the resulting R15 models in the place, and clone them at runtime.
That removes 60-120 web calls per server start and makes the roster deterministic. Keep the source of truth as a
data table of asset ids in `src/` so the models can be regenerated.

### 4b. Free Roblox-made items and the catalogue API

**Working endpoints (all fetched today, unauthenticated GET):**

1. Details search (the useful one):
   `https://catalog.roblox.com/v1/search/items/details?Category=1&MaxPrice=0&Limit=30&CreatorName=Roblox`
   - Optional and verified: `&Keyword=anime`, `&SortType=2`, `&SortType=3`.
   - `Category=1` (all) and `Category=12` (avatar animations and emotes) work.
   - `Limit` must be small: `Limit=30` works, `Limit=120` returned HTTP 400 on this endpoint.
   - Returned HTTP 400: `Category=4`, `Category=17`, `category=Characters`. `Subcategory=1` returned HTTP 500.
   - Three parallel requests triggered HTTP 429 with `Retry-After: 5`. Fetch sequentially.
   - Paging: response gives `nextPageCursor` (for example `2_1_38779a3fd2b0fca961bea8477f756df6`); the request
     parameter name for the cursor was not tested (UNKNOWN, conventionally `Cursor`).
2. Ids only: `https://catalog.roblox.com/v1/search/items?category=All&maxPrice=0&limit=120&creatorName=Roblox`
   returned 120 entries (38 Bundle, 82 Asset) of the form `{"id": 299652, "itemType": "Bundle"}`.
3. Bundle contents: `https://catalog.roblox.com/v1/bundles/741/details`.
4. `https://catalog.roblox.com/v2/search/items/details?...&maxPrice=0&creatorName=Roblox&limit=30` also answered
   with the same shape.

**Response shape (details search):**

```json
{
  "keyword": null,
  "previousPageCursor": null,
  "nextPageCursor": "2_1_...",
  "data": [
    {
      "id": 741, "itemType": "Bundle", "bundleType": 1,
      "name": "Linlin", "description": "...", "productId": 0,
      "creatorType": "User", "creatorTargetId": 1, "creatorName": "Roblox",
      "creatorHasVerifiedBadge": true,
      "price": 0, "lowestPrice": 0, "lowestResalePrice": 0, "priceStatus": "Free",
      "itemStatus": [], "itemRestrictions": [],
      "favoriteCount": 0, "offSaleDeadline": null, "collectibleItemId": null,
      "totalQuantity": 0, "unitsAvailableForConsumption": 0,
      "saleLocationType": "...", "hasResellers": false, "isRecolorable": false,
      "itemCreatedUtc": "...", "taxonomy": [],
      "bundledItems": [ { "id": 6494077172, "name": "Linlin - Hair", "type": "Asset" } ]
    }
  ]
}
```

Key names are exact (28 keys were enumerated). Values above are illustrative except id, name, creatorTargetId,
price and the bundled item. Asset rows carry `assetType` (number) instead of `bundleType`.

Bundle details shape: `{ id, name, description, bundleType, isRecolorable, items: [{id, name, type}], creator,
product: { ... isFree, isForSale, priceInRobux ... }, collectibleItemDetail }`.
For Linlin (741): body part assets 6494051962 (left arm), 6494053789 (left leg), 6494055013 (right arm),
6494055897 (right leg), 6494056892 (torso), hair 6494077172, dynamic head 85216210917123, mood 80204915687167,
`UserOutfit` 4886052516 (full outfit) and 4733326728456126 (head only). The UserOutfit id is what
`GetHumanoidDescriptionFromOutfitIdAsync` takes.

**Free Roblox-made items seen in today's responses** (creator Roblox, price 0):

- Character bundles (bundleType 1): John 126, Casey 127, Lin 130, Oakley 125, Dennis 605, Junkbot 589, Linlin 741,
  City Life Woman 337, Knights of Redcliff: Paladin 338, ROBLOX Girl 282.
- Dynamic head bundles (bundleType 4): Silly Fun 299652, Man Face 949, Check It 968.
- Shoes bundle (bundleType 3): Roblox Sneakers - Gray 872.
- Hair: True Blue Hair 451221329, Lavender Updo 451220849, Belle Of Belfast Long Red Hair 2956239660,
  Orange Beanie with Black Hair 1103003368, plus bundle hair (John's, Lin's, Linlin, City Life Woman - Short Bob).
- Layered clothing: Zip Hoodie - Black 7192553841, Knit Sweater - Black 9240757332, Casual Sweats - Black 6984763785.
- Classic shirts/pants: ROBLOX Jacket 607785314, Denim Jacket with White Hoodie 398633584, Blue Plaid Shirt 398635081,
  Pastel Starburst Top with Gray Jacket 398634295, Black Jeans with White Shoes 398633812, Ripped Skater Pants
  398635338, Beautiful You Jeans 398634487.
- Animation bundle (bundleType 2): Rthro Animation Package 356.

**Is there a free Roblox-made anime look? Barely.** Searching `Keyword=anime` with `CreatorName=Roblox` and
`MaxPrice=0` returned exactly one item (Rthro Animation Package). Which Roblox bundles read as anime was not judged
visually (Linlin is the candidate by name; UNKNOWN until seen). The same query without the creator filter returned
30 free items on page one, all community UGC, for example Green Anime Straight Hair 134530454927483,
Fluffy Black Anime Boy Hair 98792055682533, Black Long Anime GIrl Hair with Wispy Bangs 83247129474703,
cute wispy anime low pigtails blue 116972352726272, Anime Girl Face Head & Black Hair Headphones 88016102655837.
So an anime roster means UGC hair and faces. Because ownership is not required for NPC use, the selection criterion
should be look, creator reliability and IP cleanliness, not price. The Creator Store / Marketplace search that is
running separately should own the final item list.

### 4c. Performance with many humanoid NPCs

From https://create.roblox.com/docs/performance-optimization/improve (opened, quoted):

- Problems: "Leaving all HumanoidStateTypes enabled on NPCs"; "Static NPCs that do not move generally have no need
  for the Humanoid class."; "NPC animations that run on the server need to be simulated on the server and replicated
  to the client."; instantiating or modifying Humanoid models frequently "can be intensive for the engine to process,
  particularly if these models use layered clothing."; "Size/scale changes cause FastCluster to be rebuilt."
- Mitigations: "For static NPCs, use a simple AnimationController, because they don't need to move around but just
  need to play animations."; "consider creating the Animator on the client and running the animations locally.";
  "Use Humanoid:SetStateEnabled() to only enable necessary states for each humanoid."; "Pool NPC models with frequent
  respawning"; "Only spawn NPCs when users are nearby".
- The same page: "a Humanoid comes with a significant computation cost"; anchor parts that do not need physics;
  instance streaming loads only what is near the player.

From the Humanoid class page (opened):

- `EvaluateStateMachine = false` disables the Humanoid's internal physics and state machine (no forces, no floor or
  ladder sensors, no automatic state transitions) but does NOT stop appearance: HumanoidDescription, clothes and
  accessories keep working, and state events still fire.
- `SetStateEnabled` does not replicate between server and client.
- `DisplayDistanceType = None` hides name and health bar "under any circumstances".
- `RequiresNeck` can be turned off so a rig does not die when its Neck joint is disturbed.

Clothing without a Humanoid:

- Classic clothing: NO. The Shirt page says "To be visible, a `Shirt` must be a sibling of a Humanoid".
- Layered clothing: YES with manual setup. Appearance docs: "If your target model is not R15, or doesn't include a
  Humanoid, you must add a Weld object to the layering MeshPart."
- Rigid accessories without a Humanoid: not covered by an opened page (UNKNOWN; community posts say manual welds).
- A community plugin "RigWrap" claims classic clothing without Humanoids (snippet only, unverified).

Consequence for this game: a roster built from catalogue shirts, pants and accessories NEEDS a Humanoid in each
character. The right configuration is therefore not "AnimationController instead of Humanoid" but
"Humanoid kept, made as cheap as possible":

1. `EvaluateStateMachine = false`, all unused `HumanoidStateType`s disabled, `DisplayDistanceType = None`.
2. `HumanoidRootPart` anchored; no physics on display characters.
3. Idle animations played from a client script on a client-created Animator, only for characters near the camera.
4. No layered clothing on roster characters unless the look needs it (it is the expensive path on spawn/modify).
5. Never rescale at runtime; build once and clone or pool; avoid re-applying descriptions.
6. StreamingEnabled so other players' plots stream out; consider rendering far plots as cheaper stand-ins.
7. If profiling still shows a problem, the fallback is baking a character to Humanoid-less MeshParts with the
   clothing texture composited onto the body (loses classic-clothing rendering, needs its own pipeline).

Official numbers found:

- Avatar body budget 10,742 triangles in total (head 4,000, torso 1,750, limbs 1,248 each); single mesh cap 20,000.
- Textures: a 1024x1024 texture uses four times the memory of 512x512; images usually need "at most 512x512".
- The only scene-level figures are an EXAMPLE, not a platform budget: "you need to stay below 1,000 draw calls and
  1,000,000 triangles for the game to run well on your baseline device"
  (https://create.roblox.com/docs/performance-optimization/design). Same page: lower-end mobile devices "have severe
  memory limitations"; lowest quality level still draws "at least 500 studs"; Studio's emulator overstates memory.
- No official per-device instance budget or NPC count was found.

Sanity arithmetic (mine, from the numbers above): 100 visible characters at a full 10,742-triangle body is about
1.07 million triangles before hair and accessories, which already exceeds that example budget. A full roster on
screen at once is therefore a real mobile risk. Measure a 30 / 60 / 120 character plot on a phone early, and plan
for a cap on simultaneously rendered characters or distance-based stand-ins.

### 4d. Animations

- Playing: Humanoid rigs need an `Animator` under the Humanoid; non-Humanoid rigs "must create an AnimationController
  with a child Animator" (https://create.roblox.com/docs/animation/using).
- That page publishes Roblox catalogue animation ids per bundle. Examples (run, walk, jump, idle x3, fall, swim,
  swim idle, climb):
  - Rthro: 2510198475, 2510202577, 2510197830, 2510197257 / 2510196951 / 3711062489, 2510195892, 2510199791,
    2510201162, 2510192778
  - Ninja: 656118852, 656121766, 656117878, 656117400 / 656118341 / 886742569, 656115606, 656119721, 656121397, 656114359
  - Stylish: 616140816, 616146177, 616139451, 616136790 / 616138447 / 886888594, 616134815, 616143378, 616144772, 616133594
  - Cartoony: 742638842, 742640026, 742637942, 742637544 / 742638445 / 885477856, 742637151, 742639220, 742639812, 742636889
  - Also listed: Astronaut, Bubbly, Elder, Knight, Levitation, Mage, Pirate, Robot, Superhero, Toy, Vampire,
    Werewolf, Zombie.
- Free Roblox emotes returned by the catalogue API today (`Category=12`, creator Roblox, price 0): Salute 3360689775,
  Applaud 5915779043, Tilt 3360692915, Hello 3576686446, Shrug 3576968026, Stadium 3360686498, Point2 3576823880,
  plus the Rthro Animation Package bundle 356 (Idle 2510235063, Walk 2510242378, Run 2510238627, Jump 2510236649,
  Fall 2510233257, Climb 2510230574, Swim 2510240941). These are catalogue ASSET ids (emote / package assets) for
  use in `HumanoidDescription` (`AddEmote`, `IdleAnimation`, ...) and `Humanoid:PlayEmote`. The raw Animation ids
  inside the emotes are UNKNOWN.
- Default R15 `Animate` script ids: not found on an opened official page. Forum snippets cite 507766388 (idle,
  reported changed around April 2023), 507777826 (walk), 507767714 (run), 507767968 (fall). Unverified; read the
  `Animate` script inside a playtest character instead.
- The ownership rule, as it stands now: animations are covered by the asset privacy system. Restricted assets load
  only for the owner's own experiences or where the owner has granted permission
  (https://create.roblox.com/docs/projects/assets/privacy: "Creators or games can only use the asset after the asset
  owner grants permission"; an asset without permission "will not load in Studio"). Staff post of 21 Aug 2025
  (https://devforum.roblox.com/t/sharing-animation-assets-with-connections-and-groups/3892540): animations can now be
  shared with connections and groups and granted to specific experiences, and public sharing is still only being
  "looked into". So a third party's animation id will not play in this experience unless its owner grants this
  universe (10776373502). An explicit sentence that Roblox-owned animations play in every experience was NOT found
  on the pages opened; it is implied by the official docs publishing the ids above for replacing default
  animations. Animations made with the project's `roblox-animation` skill must be uploaded by the experience owner
  (user 3540923881). Note also: "Once you grant a game permission to use a restricted asset, that permission cannot
  be revoked", and "Open Use is irreversible."

---

## 5. Fonts and icons

### Fonts inside Roblox

Opened: https://create.roblox.com/docs/reference/engine/datatypes/Font (Markdown version).
The dedicated UI fonts guide URL guessed (`/docs/ui/fonts`) returned 404.

- Constructors: `Font.new`, `Font.fromEnum`, `Font.fromName` ("creating fonts from the content folder"; no spaces in
  the name), `Font.fromId` ("creating fonts from an asset ID number"). "Font families are a type of asset, like
  images or meshes."
- Built-in families listed with `rbxasset://fonts/families/<Name>.json`: Accanthis ADF Std, Amatic SC, Arimo,
  Balthazar, **Bangers**, Builder Extended, Builder Mono, Builder Sans, Comic Neue Angular, Creepster, Denk One,
  Fondamento, **Fredoka One**, Grenze Gotisch, Guru, Highway Gothic, Inconsolata, Indie Flower, Josefin Sans, Jura,
  Kalam, **Luckiest Guy**, Merriweather, Michroma, Montserrat, Nunito, Oswald, Patrick Hand, Permanent Marker,
  Press Start 2P, Roboto, Roboto Condensed, Roboto Mono, Roman Antique, Sarpanch, Source Sans Pro, Special Elite,
  Titillium Web, Ubuntu, Zekton.
- Usage: `Font.fromName("FredokaOne")`, `Font.fromName("LuckiestGuy")`, `Font.fromName("Bangers")`. No upload, no
  licence step, nothing to attribute in-game.
- **Titan One is not in the built-in list.** It would need `Font.fromId(<Creator Store font id>)`; that id and the
  Creator Store font terms are UNKNOWN (the page does not mention the Creator Store or custom font upload).
- No CJK family appears in the list. Japanese-script signage should be image decals, not TextLabels.
- Individual font licences are not stated on the page (UNKNOWN there); they ship with the engine.

Suggestion: Fredoka One for body/UI, Luckiest Guy or Bangers for impact numbers and titles. All three built-in.

### Icon packs

| Pack | URL | Licence (sentence that matters) | Commercial | Attribution | Format | Count |
|---|---|---|---|---|---|---|
| Kenney - Game Icons | https://kenney.nl/assets/game-icons | CC0. Kenney support page: "You're free to use them, even in commercial projects." and "Attribution is not required." | Yes | No | Not listed on the page (UNKNOWN) | 105 files. Related: Game Icons (Expansion), Board Game Icons |
| game-icons.net | https://game-icons.net/about.html | "They are provided provided under the terms of the Creative Commons 3.0 BY license." (sic) | Yes | **Yes**: credit the author, e.g. "Icons made by {author}. Available on https://game-icons.net" | SVG | Author table sums to 4,183 (Delapouite 2,022; Lorc 1,429) |
| Lucide | https://lucide.dev/license | ISC: "Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted" provided the copyright and permission notice "appear in all copies"; Feather-derived icons are MIT | Yes | Keep the licence notice (put it on the credits screen / repo) | SVG | UNKNOWN |

Kenney first (zero obligations). game-icons.net only if a credits screen is built, with the per-author line.
Food item icons are better rendered from the actual 3D props (consistent with the meshes) via the `roblox-ui` skill.

---

## 6. Music and SFX

### The usual route: Roblox's own library

- Creator Store audio: "more than 100,000 professionally-produced sound effects and music tracks"
  (https://create.roblox.com/docs/audio/assets). The page names no partners.
- Licensed music: the staff post "Amplify Your Experiences with New Music"
  (https://devforum.roblox.com/t/amplify-your-experiences-with-new-music/3164792) describes DistroKid "Fresh Music" in
  the Creator Store, and its update of 13 Feb 2025 lists DistroKid, Monstercat, APM, Clippsly and BSlick as
  distributors (in the context of the "What's Playing" feature). Rules stated there: "All music on Creator Store is
  meant to be solely used on Roblox."; the grant is specific to the USER who acquires or inserts the asset (Team
  Create collaborators do not receive it); groups could not acquire Creator Store audio at the time; uploads are
  screened with Audible Magic.
  Relevance: this place is user-owned (user 3540923881), so that account must be the one that acquires/inserts
  every track.
- Newer partnerships (snippets only, not opened): Too Lost catalogue, a Universal Music Group agreement, and a quoted
  limit of 250 distinct licensed tracks per experience. UNKNOWN until opened.

### Current upload and visibility rules (docs carry a 2026 footer)

- Upload: one stream in ".mp3, .ogg, .wav or .flac", "less than 20 MB in size and 7 minutes in duration", sample rate
  up to 48 kHz. "If you're ID verified, you can import 2,000 free audio assets per 30 days"; 100 if not.
- Privacy: uploaded audio is private; you are "initially the only one who can view and use private audio assets" and
  can "grant usage permissions to specific friends and experiences". Granting an experience is permanent
  ("cannot be revoked"). An asset without permission does not load in Studio or at runtime.
- Sharing rules (https://devforum.roblox.com/t/new-asset-privacy-and-permissions-features-for-audio-and-video/2725248):
  a user must be on your friends list to be shared with; sharing does not itself grant their experience access.
- Creator Store distribution of your own audio is free-only and needs the audio legal agreements enabled; limits on
  that page are 100 audio assets per 30 days verified, 10 unverified
  (https://create.roblox.com/docs/production/publishing/creator-store). Not needed for this game.
- Songs can appear on the experience details page only after moderation and copyright checks, with an ID-verified
  uploader who accepted the Audio Terms of Use.

### Outside sources with clean licences (only if something is missing from the Creator Store)

| Source | URL | Licence | Commercial | Attribution |
|---|---|---|---|---|
| Kenney audio packs (Music Jingles, UI Audio, Interface Sounds, Impact Sounds, RPG Audio, Casino Audio, Digital Audio) | https://kenney.nl/assets/category:Audio | CC0 per Kenney support page: "all game assets on the asset pages are public domain licensed (CC0)" | Yes | No |
| Kevin MacLeod / incompetech | https://incompetech.com/music/royalty-free/faq.html | "Licensed under Creative Commons: By Attribution 4.0" | Yes with credit (page: "Probably. Be sure to credit me or purchase a license.") | **Yes**: "Title Kevin MacLeod (incompetech.com) / Licensed under Creative Commons: By Attribution 4.0 / https://creativecommons.org/licenses/by/4.0/" |
| Pixabay | https://pixabay.com/service/license-summary/ | Pixabay Content Licence: "Use Content without having to attribute the author"; "You cannot sell or distribute Content ... on a Standalone basis." | Yes, inside a work | No. Keep the upload private; do not put it on the Creator Store |
| FreePD | https://freepd.com/ | Only the phrase "free-to-use, Public Domain music"; no licence text on the page | UNKNOWN (no formal grant found) | UNKNOWN |

Risk note: Roblox screens uploads with Audible Magic. Widely distributed CC music may be fingerprinted and blocked
even when the licence allows the use (inference, not tested). Another reason to stay inside the Creator Store, which
the project's `roblox-sfx` skill already automates.

---

## 7. Recommended sourcing plan

| Asset class | Primary source | Fallback | Licence note | Conversion work needed |
|---|---|---|---|---|
| Roster characters (60-120) | Roblox avatar items via `HumanoidDescription` (Roblox-made bodies/heads + generic anime-style UGC hair, faces, classic clothing), built once at edit time and stored in the place | One custom anime base body through Avatar Setup "Development Avatar", dressed with catalogue hair | No ownership needed technically (accessories and clothing are OpenUse). Avoid items cloning real anime IP. 2023 marketplace-items policy is paused, status UNKNOWN | None for rigging. A data table of asset ids plus a build script. Per-character performance config (section 4c) |
| Food props, Japanese | Quaternius Sushi Restaurant Kit | Kenney Food Kit (Rice Ball, Sushi Egg, Sushi Salmon) | CC0, no attribution | Low: import glTF/FBX in Blender 4.5, check scale and triangle count, set pivot, export as MeshPart; unify palette |
| Food props, western | Quaternius Ultimate Food Pack | Kenney Food Kit (Cake, Cake Birthday and others) | CC0 | Low, as above |
| Food gaps (takoyaki, bento, mochi, taiyaki, tempura, curry) | Generate with the `roblox-3d-model` skill | Poly Pizza singles by sugamo (licence UNKNOWN, check each) | Own work | Medium: generate, paint to match, verify in-engine |
| Environment, nature | Quaternius Stylized Nature MegaKit | Quaternius Ultimate Stylized Nature Pack | CC0 | Low. Watch total triangles when scattering; reuse identical meshes for instancing |
| Environment, Japanese props | Quaternius Sushi Kit (torii, sakura tree, bamboo, shoji walls, doors, signs) | reodesuxz Japanese Town / Shrine packs (pagoda, shrine hall, stone lanterns, koi pond) | CC0 / custom "free for personal and commercial projects", no redistribution of files: keep uploads Restricted and read the README in the zip | Low to medium: two styles to reconcile (textured vs flat colour) |
| Market stalls, dojo | Quaternius Sushi Truck and Ultimate Fantasy RTS stalls/temples | reodesuxz Farmers Market / Castle Town packs; or build from Sushi Kit modular walls | CC0 / custom | Medium: style check needed, RTS pieces may be too small-scale |
| Lanterns, fences, bridges, clouds | Build in Studio from parts (and one generated cloud mesh) | KayKit lantern singles on Poly Pizza (licence per model UNKNOWN) | Own work | Low |
| Fonts | Built-in Fredoka One, Luckiest Guy, Bangers via `Font.fromName` | Creator Store font via `Font.fromId` (Titan One id UNKNOWN) | Engine-provided | None |
| UI icons | Kenney Game Icons (+ Expansion); item icons rendered from the 3D props | game-icons.net | CC0 / CC BY 3.0 needs an in-game credit line | Low: upload as Images |
| Animations | Roblox catalogue animations and free emotes (ids in 4d) | Own animations via the `roblox-animation` skill, uploaded by user 3540923881 | Third-party animations need the owner to grant this universe | None / own pipeline |
| Music and SFX | Roblox Creator Store audio via the `roblox-sfx` skill, acquired by the place owner account | Kenney CC0 audio; Kevin MacLeod CC BY 4.0 with credit | Creator Store music is Roblox-only; uploads are private and fingerprint-screened | None / upload and grant to universe 10776373502 |

---

## 8. Open items (UNKNOWN) and the cheapest way to close each

| # | Unknown | How to close it |
|---|---|---|
| 1 | Do `CreateHumanoidModelFromDescriptionAsync` / `ApplyDescriptionAsync` run in Studio edit mode (command bar, MCP)? | One `execute_luau` call that builds a model from 2-3 known free ids. The call yields, so use `task.delay` or the `studio_mcp.py` helper as CLAUDE.md describes |
| 2 | Real accessory limit per type and in total when applied by `ApplyDescriptionAsync`, and whether Universe Avatar Settings apply to NPCs | Apply a description with 4 hats + 2 hair + 2 back accessories and count what arrives |
| 3 | Does a paid or off-sale UGC accessory load on an NPC in a published server (not just Studio)? | Test in a private published server before committing the roster |
| 4 | Is the 2023 "Experiences using Marketplace Items" policy in force in any form? | Read the current Community Standards while logged in (page blocked to the fetcher) |
| 5 | Which free Roblox bundles and heads actually look anime | Visual pass in Studio over the bundle ids in 4b, by the Creator Store research track |
| 6 | Triangle counts of every chosen prop | Blender stats after download, before import |
| 7 | Kenney Food Kit 2.0 model names | Open the zip |
| 8 | reodesuxz README licence text and full model lists | Open the zips |
| 9 | Licence of individual Poly Pizza singles (takoyaki, kagami-mochi, stone lamp, lanterns) | Open each model page; the badge shows CC0 or CC-BY |
| 10 | VRoid Hub filter for commercial-OK / CC0 models; CC0 status of VRoid sample models | Only matters if the custom-body option is ever pursued |
| 11 | Mobile cost of 30 / 60 / 120 dressed R15 characters on one plot | Device test in section 5 of the build; decides the on-screen cap |
| 12 | Default R15 `Animate` ids and raw Animation ids inside free emotes | Read from a playtest character |

## 9. Pages that could not be opened

HTTP 403: VRoid help centre article on conditions of use, developer.vroid.com guidelines and SDK licence page,
hub.vroid.com model search, vroid.com Studio guidelines, helpx.adobe.com Mixamo FAQ, Roblox Community Standards
(en.help.roblox.com), opengameart.org pages, itch.io tag browse pages.
HTTP 404: poly.pizza licence page (two guessed URLs), create.roblox.com/docs/ui/fonts,
create.roblox.com/docs/art/characters/auto-setup (moved to /docs/avatar-setup), ely-dev.itch.io/mini-japan,
gdevelop.io Food Kit listing.
