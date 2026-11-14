# Creator Store, avatar catalogue and Studio probes (2026-11-14, run by the main thread)

Everything here was measured, not read. Probe objects were deleted from the place afterwards.

## 1. Free "anime character" models on the Creator Store are not usable

Searched (Studio MCP `search_asset` and the toolbox API): "anime character R15 rig", "anime
characters pack", "anime girl rig", "chibi character rig", "anime boy npc r15", "samurai npc r15",
"ninja npc r15", "anime npc original".

- The hits are named copies of copyrighted characters (the first three results were a pirate
  captain, a ninja and a ninja animation pack from two of the best-known series, by name).
- The uploader of the top results shows as **"Content Deleted - 158552482"**: Roblox has already
  deleted that account. A game built on those meshes inherits the same fate.
- Most other results are spam re-uploads from throwaway accounts (dozens of identical "skybox" and
  "morph" entries with 0 votes).
- Nothing found was an original, consistent, anime-styled set.

Conclusion: do not source characters from Creator Store free models.

## 2. The avatar route works, in edit mode, in under a second

`Players:CreateHumanoidModelFromDescription(desc, R15)` run through `execute_luau` in Edit mode
(inside `task.spawn`, result read by a second call because the call yields):

| Probe | Result |
|---|---|
| Hair only | built in 0.58 s; 289 descendants, 16 MeshParts, 1 Accessory |
| 4 full looks (hair + anime face head + outfit + weapon) | all built; see `img/probe-character-route.jpg` |
| `Players:GetHumanoidDescriptionFromUserId(<owner>)` | works in edit mode: 6 accessories (2 layered), shirt, pants, head, idle animation |
| `avatar.roblox.com/v2/avatar/users/<id>/outfits` | public, no login: lists a user's saved outfits with ids |

So a **whole ready-made look** can be taken three ways: a user id (their current avatar), an
outfit id (a saved outfit), or an explicit item list. This is what the "Load Character" plugin
does, without the plugin.

Traps found (each cost a failed probe):

1. `HumanoidDescription:SetAccessories(list, true)` **replaces** the rigid accessories set through
   `HairAccessory`, `HatAccessory`, `BackAccessory`... Call `SetAccessories(layeredOnly, false)`
   first, then set the rigid properties.
2. Rigid accessories passed inside `SetAccessories` with `IsLayered = false` were silently dropped.
3. A fresh rig has **no Motor6Ds**: 15 `AnimationConstraint` + 14 `BallSocketConstraint`. Code that
   looks for Motor6Ds finds none.
4. 289 instances per rig, about 250 of them not needed for display (27 Animation objects, 71
   Vector3Values, the Animate script, constraints for ragdoll). The bake strips them.
5. Some "anime face" items are hats that sit over the head and do not fit every head shape. Every
   look needs a visual check; none can be accepted from its catalogue thumbnail.
6. The non-Async method names are deprecated (research/03): use the `...Async` forms in new code.

## 3. The catalogue has plenty of free anime-style parts

`catalog.roblox.com/v1/search/items/details?Keyword=...&MaxPrice=0&Limit=30` (one call at a
time; parallel calls return 429): 30 free anime hairs on the first page, free anime face heads,
free katanas, wings, halos, auras, kimono and school uniforms (layered). Asset type codes seen:
8 hat, 41 hair, 42 face, 44 shoulder, 45 front, 46 back, 47 waist, 65/67/72 layered clothing.
Roblox-made free items alone give almost no anime look; it comes from community items.

## 4. What this decides

- Characters = baked R15 rigs from whole avatar looks. No external models, no generation.
- Looks are **snapshotted** (resolved to an explicit item list in `design/looks.json`) at bake
  time, so a hero never changes when the source avatar changes.
- Looks that copy a specific copyrighted character are excluded (section 1 shows what Roblox does
  to them). The roster is built from anime tropes: ninja, samurai, idol, hero, spirit.
- VFX harvest library on this machine is empty and the Creator Store "aura pack" search returned
  mostly unrelated or character-named packs: effects are authored in the roblox-vfx simulator.
