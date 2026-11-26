# Throw Food for Anime: plan index (section 1, 2026-11-14)

**The game in one line:** train your Power, throw food down a lane of anime worlds, and whoever
it lures joins your plot and earns Yen; further throws reach rarer heroes.

## What to read

| File | What it answers |
|---|---|
| `design/game.json` | THE CONTRACT: loop, systems, every number (`config`), 23-section plan, 254-row asset plan |
| `plan/01-game-design.md` | rules and formulas: throw, luck, roll, income, training, squad, rebirth, pacing |
| `plan/02-architecture.md` | code: modules, specs, saved data, replication, remotes, security, rendering |
| `plan/03-characters-and-assets.md` | where every model comes from; the character bake pipeline; the IP rule |
| `plan/04-world-and-map.md` | layout, zones, prover checks, streaming |
| `plan/05-ui-ux.md` | style, every screen, rules, input |
| `plan/06-motion-vfx-sound.md` | the throw sequence, 14 clips, 27 effects, 34 sounds |
| `plan/07-monetisation-liveops.md` | store, policy, retention, analytics, launch |
| `plan/08-build-order.md` | sections 2 to 6 step by step, inputs needed from the user, risks |
| `plan/12-gameplay-economy-v2.md` | PLAN (2026-11-26, awaiting the owner): all 17 zones and 172 lane heroes in play, the "1 in N" odds, rebirth every band, passes and their bounds, the Aim control; numbers in `plan/12-economy-draft.json`, tested by `python tools/economy/econ_v2.py sim` |
| `plan/13-food-and-training-v2.md` | PLAN (2026-11-26, awaiting the owner): 51 foods (three per world, luck only, home-world rule, favourite dish), 8 training grounds with one-thumb games, 57 training levels; numbers in `plan/13-economy-draft.json`, tested by `python tools/economy/econ_v3.py sim` |
| `research/00` to `04` | evidence: store data, reference teardown, market and policy, external assets, Studio probes |
| `design/{map,meshes,ui,animations,vfx,sfx}.json` | per-stage spec seeds, names matching the asset plan |
| `tools/balance_sim.py` | pacing check: `python tools/balance_sim.py --check` |

## Decisions made in this section (and why)

1. **Same genre, our own game.** The loop (throw, lure, collect, idle income, train) is a genre.
   The map, art, UI, names, numbers and features are ours. A 1:1 copy of the reference would be
   both removable and worse: its own players list what is wrong with it (research/01 section 15).
2. **Roster: 31 avatars imported by the owner** (well-known characters, changed display names,
   R15). The original-trope roster first planned here was overruled by the owner on 2026-11-14 with
   the takedown risk stated; see `03-characters-and-assets.md` section 1 and `design/characters/README.md`.
3. **Characters are whole avatar looks baked to R15 rigs** (the user's Load Character idea),
   snapshotted so they never change. Proven in Studio.
4. **The server never spawns hero rigs;** clients render from compact plot state.
5. **Five differences from the reference, each answering a complaint about it:** hold-to-charge
   zone select with a perfect window, cravings, fusion, rebirth, honest odds with skippable
   reveals.
6. **Six players, six zones, 43 + 8 heroes, 12 foods at launch;** more heroes by import, later zones are data.
7. **Numbers were tuned with a simulator,** and its targets are part of the contract.
8. **Free assets first** (CC0 packs, catalogue items, Creator Store audio); the 3D, animation and
   VFX skills build what is missing.

## Counts

43 lane heroes + 8 premium (premium avatars not imported yet), 6 zones, 7 rarities, 4 mutations, 3 sizes, 12 foods, 8 dojo gear
tiers, 10 rebirth tiers, 6 passes, 17 products, 22 screens, 30 icons, 14 animation clips,
27 effects, 34 sound roles, 62 non-character meshes, 16 server services, 9 client controllers,
14 Core modules.
