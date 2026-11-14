# 03 Characters and assets: where every model comes from

Rule for the whole file: a real asset or nothing. No stand-in parts, no asset that the game does
not load. Evidence for every choice is in `design/research/03` and `04`.

## 1. Characters: baked R15 rigs from whole avatar looks

Decided with the user on 2026-11-14: use ready-made avatars (what the "Load Character" plugin
does) instead of picking each item. Proven in Studio the same day (research/04).

**A look** is one of:
- `outfit`: a saved outfit id (`GetHumanoidDescriptionFromOutfitIdAsync`)
- `user`: a user id, taken as that avatar is today (`GetHumanoidDescriptionFromUserIdAsync`)
- `items`: an explicit list (hair, head/face, shirt, pants, up to four more accessories)

**Pipeline** (section 3, one Studio thread):

1. `design/looks.json`: one row per hero in `config.Characters` and `PremiumCharacters`:
   `{ heroId, source: {outfit|user|items}, notes }`. Candidates come from catalogue searches by
   the hero's `Look` text and from outfits the owner saves on their own account.
2. `tools/studio/bake_characters.luau` (run by `execute_luau`, in batches of 8): resolve the
   source to a HumanoidDescription, **write the resolved item list back to `looks.json`**
   (the snapshot: the hero no longer depends on the source avatar), build the rig, strip it
   (02 section 7), name it `Char_<heroId>`, parent to `ReplicatedStorage.Assets.Characters`.
3. QA sheet: all rigs of a zone in a row, front and three-quarter, one screenshot per zone,
   looked at. Reject and re-pick when: a face item does not fit the head, an accessory floats or
   clips, the silhouette matches another hero, the look reads as a specific existing character,
   more than 6 accessories or more than 1 layered item, over 12K triangles.
4. Manifest: `assets/meshes/manifest.json` gets one entry per rig with measured extents,
   triangle count, accessory count and the asset ids it uses.
5. Thumbnails for the UI are rendered from the rigs themselves (ViewportFrame at runtime for
   Squad and Index; no separate portrait art to drift).

**Roster decision (owner, 2026-11-14).** After section 1 the owner imported 31 avatars of
well-known characters and chose them as the launch roster, with changed display names. The
build follows that decision; the R15 rebuild, the head rule and the traps are in
`design/characters/README.md`, the id-to-avatar map is `design/characters/roster.json`, and the
rigs are in `Workspace.Characters_R15`. What follows is the risk as it was stated, kept on record:
Roblox removes content on a rights holder's notice and generally does not reopen a removed game
(research/02 D); the free models of named characters we found were uploaded by an account Roblox
has already deleted (research/04); a look is judged by how it looks, so a new name protects
nothing. A game we expect to earn from cannot rest on assets that can be pulled in one notice.
Mitigations that are in the build: display names are our own titles ("Fox Ninja", "Curse King"),
no series name, logo, music or official art appears in any text, icon, thumbnail or store
listing, and every hero is one data row plus one rig, so any of them can be swapped out in
minutes if a notice ever arrives. The eight premium heroes are original designs.

**Variants.** Mutation = aura effect + a soft colour grade on the nameplate, never a recolour of
the avatar items. Size = `Model:ScaleTo`. Stars = star pips on the nameplate.

**Open checks** (close in section 3 before committing the roster): do off-sale or paid items
load on NPCs in a published server (test one private server); accessory count limits; cost of
30 / 60 / 90 dressed rigs on a phone profile.

## 2. Foods (12)

| Food | Flavour | Source |
|---|---|---|
| Onigiri, Dango, Sushi, Spicy Bun, Gyoza, Ramen | mixed | Quaternius Sushi Restaurant Kit, CC0 |
| Ice Cream, Festival Cake | Sweet | Quaternius Ultimate Food Pack / Kenney Food Kit, CC0 |
| Takoyaki, Curry, Tempura, Dragon Feast | mixed | built with `roblox-3d-model` (no CC0 model exists) |

Import route for CC0: download the pack -> Blender 4.5 headless: weld, check tris (budget 1.5K),
set pivot at the grip point, one palette pass so the two packs match -> GLB -> upload as Model
with the 3D skill's uploader -> `Assets.Foods.Food_<id>`. The four built foods go through the
skill's concept gate and are painted to the same palette. Food icons are renders of the meshes.

## 3. Dojo gear (8), plot and hub kit (12)

Hard-surface, so the Kiln route of `roblox-3d-model` (code-as-model, exact, local): Wooden
Dummy, Sandbag, Iron Dummy, Stone Pillar, Waterfall (rock arch + water plane), Gravity Dojo,
Dragon Shrine, Star Forge; fence, pedestal, throw pad, slot sign, name arch, sell booth, food
cart, summon shrine, leaderboard frame, daily chest, zone gate, yen coin. Each gear tier must be
visibly bigger and brighter than the last. Food cart and shrine may come from the Quaternius
kit if the style matches after the palette pass.

## 4. Zone props (30)

Five per zone (`meshes.json`). Source order: Quaternius (Sushi Restaurant Kit: torii, sakura
tree, bamboo, shoji; Stylized Nature MegaKit: trees, rocks), CC0, then Kiln for what is missing
(clock tower, drum tower, neon tower, floating island). One palette pass per zone so mixed
sources read as one world. Reuse identical meshes for instancing; budget 4K tris each.

## 5. Licence ledger

`assets/LICENSES.md` gets a row per imported pack: name, URL, licence sentence, date, files
used. CC0 needs no credit; anything CC-BY gets a credit line in Settings. Roblox avatar items:
ids recorded in the manifest so a moderated item can be found and replaced in one edit.

## 6. What each asset must be wired to (checked at the section 5 gate)

| Asset | Loaded by |
|---|---|
| `Char_*` | SquadRenderController (plots), ThrowController (reveal), ViewportFrames (Squad, Index, Store) |
| `Food_*` | ThrowController (hand + flight), FoodShop viewport |
| `Equip_*` | PlotService places the owned tier on the dojo pad |
| plot, hub, lane, zone props | the map build; `Workspace.Map` |
