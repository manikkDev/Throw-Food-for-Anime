# VFX: 64 authored effects (section 4: 25; plan 13 phase C: the 39 food effects)

Authored with the roblox-vfx skill's authoring route: own textures (the skill's maths-made library
`sim/textures/lib` + this game's own in `textures/`), judged frame by frame in the skill's browser
sim, exported as data. No harvested effects, no meshes (every shape is a sprite, flipbook, beam or
trail texture; the coin is a 16-frame render of a spinning yen coin).

Style: `stylised_game` with `anime_cel` accents (cel stars/rings + soft glow halos), LightEmission
0.3-0.7, no screen effects except Reveal_Mythic, Reveal_Secret and Rebirth_Nova (screen-edge flash +
short shake, local player only).

## The food effects (plan 13 phase C)

`builders/build_food.py` builds `ThrowTrail_Meal`, `Land_Meal`, `Aroma_Meal`, `Aroma_Signature`, `Favourite_Burst`
and one `Sig_<food id>_Trail` + `Sig_<food id>_Land` for each of the 17 Signature dishes (`python
builders/build_food.py [meal aroma favourite <food id> ...]`). Their own textures: `tools/make_food_tex.py`.
New textures go up with `python tools/upload_tex.py` (Open Cloud, writes `ids.json`), then `pack_all.py`.
Rules that came out of judging them in the game (`tools/studio/foods/fx_judge.luau`), all in the builder's header:
a flight effect rides WITH the food (`LockedToPart`, born 2.2 studs behind its centre); soft glow / "hot" flame
sprites fuse into a pale cloud at max graphics (use the cel sprites); a flipbook laid flat draws as a broken arc
(use a ring sprite); beam strips are not particle textures. An instance with `"sim": true` is a stand-in for the
judging strips only (the thrown food) and is dropped by the packer.

## Layout

| Path | What |
|---|---|
| `builders/build_*.py` | parametric builders (`tfa_fx.py` = shared helpers). `build_reveal.py` = all 7 rarities |
| `effects/<Name>.json` | effect definitions (sim format + a `game` block: loop, attach, screen, origin) |
| `textures/*.png` | this game's own textures (`tools/make_tfa_tex.py`: clover, yen coin flipbook, screen edge, aurora) |
| `strips/<Name>.jpg` | judging strips: row 1 light floor, row 2 dark floor, numbered frames at the phase times |
| `metrics/<Name>.json` | per-frame luma / sat / hot / live particle count |
| `kits/<Name>.luau` | the skill's Studio kits (`sim/studio_kit.js`), Lune compile + build checked (`kits/_checks.json`) |
| `upload/` + `upload_list.json` | every texture PNG to upload as **Image** (Beam/Trail textures already transposed: `__vt`) |
| `ids.json` | YOU write it after uploading: `{"textures": {"<file>": <id>}, "meshes": {}}` |
| `manifest.json` | one row per effect (loop, duration, attach, particles_peak, strip, kit, critic, notes) |
| `../../work/vfx/build_templates.luau` | the ONE Studio template builder (generated, git-ignored) |

## Rebuild

```
python assets/vfx/tools/make_tfa_tex.py                 # own textures (only if changed)
for b in assets/vfx/builders/build_*.py; do python $b; done
python assets/vfx/tools/serve_tfa.py &                  # sim on :8766 (serves the skill's sim, writes nothing there)
node assets/vfx/tools/strip.mjs assets/vfx/effects/*.json   # headless Edge over CDP -> strips/ + metrics/
python assets/vfx/tools/pack_all.py --kits              # upload/, upload_list.json, build_templates.luau, kits, manifest
lune run assets/vfx/tools/check_templates.luau          # runs build_templates against Roblox reflection
```

## Into Studio

1. Upload every file in `upload_list.json` (`path`) as an **Image**; write `assets/vfx/ids.json`
   keyed by the `file` field.
2. `python assets/vfx/tools/pack_all.py` (embeds the ids), then run `work/vfx/build_templates.luau`
   in EDIT mode (command bar / execute_luau). It is yield-free and returns a report:
   `built N/27 | FAILED | PROP_FAILS | textures without id | templates with missing assets`.
   `_G.VFX_ONLY = {"Reveal_Epic"}` first builds a subset; `_G.VFX_IDS = {...}` overrides the ids.
3. Templates land in `ReplicatedStorage.Assets.Vfx.<Name>`.

## Runtime: `src/client/Fx/VfxKit.luau`

```lua
VfxKit.play(name, at, opts) -> Handle?   -- at: BasePart | Attachment | CFrame | Vector3
  opts = {scale: number?, tint: Color3?, duration: number?, screen: boolean?}
Handle = {stop, destroy, setEnabled}     -- h:stop() and h.stop() both work
VfxKit.setLowDetail(on)                  -- auras keep only the LowKeep ground ring; counts and rates halve
VfxKit.preload()                         -- yields; fetch every template texture at join
```

- Loops (auras, ThrowTrail_*, LuckyThrow_Charge, DashHome_Trail, ServerLuck_Sky) run until
  stop/destroy (or `opts.duration`); stop lets the last particles and trail segments finish.
  One-shots ignore stop and clean up after their Duration.
- attach `point`: placed once, upright. `part`: follows the part and faces its travel direction
  (food, hand). `root`: follows the HumanoidRootPart's full CFrame (auras sit 2.9 studs below the
  root: pass `scale` = hero scale for bigger heroes).
- `tint` recolours layers marked Tint, keeping white cores (ThrowTrail_Basic is all-white: it takes
  the food colour fully). Reveal_* ignore tint (they carry the rarity colours and the colour climb).
- Burst layers (Rate 0) are emitted by the timeline; the runtime implements emit, set, tween,
  enable(+duration), disable, shake, overlay (screen-edge ImageLabel).
- Missing template / missing asset ids / any error: returns nil, warns once per name, never throws.
