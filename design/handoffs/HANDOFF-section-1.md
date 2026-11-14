<!-- section: 1 -->
# HANDOFF: section 1 of 6 closed (Research and design)

Game: `D:\Roblox Studio Games\Throw food for Anime`
Written: 2026-11-14T13:37:37+05:30

A cleared session starts from this file alone. Read it in full, then run:

```bash
python ~/.claude/skills/create-roblox-game/scripts/section.py resume --dir "D:\Roblox Studio Games\Throw food for Anime"
```

## Where things are

- Contract: `design/game.json` (loop, 25 systems, `config` with every number, 23-section `plan`, 254-row `asset_plan`, publish ids).
- Stage spec seeds, generated from the contract so names match the asset plan: `design/map.json`, `design/meshes.json`, `design/ui.json`, `design/animations.json`, `design/vfx.json`, `design/sfx.json`.
- Implementation plans: `design/plan/00-INDEX.md` (start here), `01-game-design.md`, `02-architecture.md`, `03-characters-and-assets.md`, `04-world-and-map.md`, `05-ui-ux.md`, `06-motion-vfx-sound.md`, `07-monetisation-liveops.md`, `08-build-order.md`.
- Research: `design/research/00-reference-store-data.md` (public API pull), `01-reference-game.md` (teardown, 953 lines), `02-market-and-policy.md`, `03-external-assets.md` (583 lines), `04-creator-store-and-studio-probes.md`, `img/probe-character-route.jpg`.
- Pacing simulator: `tools/balance_sim.py` (reads `design/game.json`).
- Ledger: `build-runs/ThrowFoodForAnime/`.
- Studio: nothing added. Probe rigs were built under `Workspace.__probe` and deleted; the place was saved as version 10 with no content change.
- No code in `src/` was touched.

## Done this section

- Preflight: every required row green (Kaggle off by design). Screen access to Roblox Studio granted.
- Reference game read from Roblox's public APIs: 426,424 playing, 215.2M visits, 94.4% likes, created 2026-09-18, 5 players per server, 2 passes, 50 developer products with prices.
- Three research files written by sub-agents with cited sources; opened and read by the main thread.
- Character route proven in Studio edit mode: `CreateHumanoidModelFromDescription` built a rig in 0.58 s; four full looks built and screenshotted; `GetHumanoidDescriptionFromUserId` works; the public outfits endpoint lists outfit ids.
- Economy tuned by simulation. `python tools/balance_sim.py --check --runs 7 --hours 20`: all six pacing targets ok (zone 2 at 2 min, zone 3 at 14 min, zone 4 at 51 min, zone 5 at 2 h 46, zone 6 at 7 h 18, rebirth 1 at 15 h 11).
- `python ~/.claude/skills/create-roblox-game/scripts/validate.py`: "contract valid", 23 plan sections answered, 0 declined, no unfilled markers in any spec.

## Decisions and why

1. Same genre, own game: the loop is shared with the reference; map, art, UI, names, numbers and features are ours. A 1:1 copy is removable and repeats the faults its own players list (research/01 section 15).
2. Original trope roster (ninja, ronin, idol, hero, spirit...), not renamed copies of known characters: Roblox removes on DMCA notice and does not reopen; the free named-character models on the Creator Store came from an account Roblox already deleted. The user's brief asked for the opposite; this is flagged as input 1 in `plan/08`.
3. Characters are whole avatar looks (user id, outfit id or item list) baked to R15 rigs and snapshotted into `design/looks.json`: the user's idea, proven in Studio, no per-item modelling.
4. The server never spawns hero rigs; clients render from compact plot state: 144 Humanoids would otherwise replicate.
5. Hold-to-charge picks the zone, perfect window gives luck: keeps a skill beat that matters at every stage.
6. Cravings (food flavour triples a hero's weight), fusion (3 identical -> +1 star), 10 rebirth tiers, real "1 in N" odds, skippable reveals: each answers a documented complaint about the reference.
7. Six players per server, six zones, 48 + 8 heroes, 12 foods at launch; zones 7 to 10 are data-only updates.
8. Foods: 8 from CC0 packs (Quaternius, Kenney), 4 built with the 3D skill because no CC0 model exists.
9. VFX authored in the roblox-vfx simulator: the harvest library on this machine is empty and the Creator Store aura search returned nothing usable.
10. Money is automatic (no walk-to-collect), first plot slot costs 1.5K: mobile-friendly, and the reference's 40M first slot is a known quit point.
11. Paid random items (summon scrolls) ship with disclosed odds and a PolicyService fallback to fixed-price sales: Roblox policy.
12. All tunables in `design/game.json` `config`, generated to Luau by `gen_config.py`; the simulator's targets live in `config.Pacing`.

## Unproven

- Whether paid or off-sale avatar items load on NPCs in a published server (only Studio edit mode was tested).
- Accessory count limits per rig, and whether the non-deprecated `...Async` method names behave the same in edit mode (the probe used the older names).
- Frame cost of 30 / 60 / 90 / 144 dressed R15 rigs on a phone.
- Whether Open Cloud can upload Animation assets with the current key.
- Whether the simulator's pacing matches the game: the Core modules do not exist yet; section 2 must make them agree.
- The reference game was never played by us: throw cycle time, cooldown and how its luck multiplier works are unknown (research/01 "Open questions"). Our design does not depend on them.
- Status of Roblox's paused 2023 policy on marketplace items inside experiences.
- No real avatar looks have been chosen yet; the roster is names and look briefs only.
- Free CC0 packs were verified by licence page, not downloaded: triangle counts and exact model names are unmeasured.

## Debts

- Intervention 1 (logged): the user chose ready-made whole avatars as the character source and pre-authorised building food, animation, VFX and models where no free asset exists. Adopted in `plan/03`; nothing to heal.
- No fallbacks, no stalls.
- Scope note: the skill's default "one core loop, no shop, no datastore" was overridden by the brief (a publishable, monetised game). `out_of_scope` lists what is still cut.

## Ledger

Initialised once in section 1. Never run `init` again.

```bash
python ~/.claude/skills/roblox-build-orchestrator/scripts/run_log.py counter --dir "D:\Roblox Studio Games\Throw food for Anime\build-runs" --run "ThrowFoodForAnime"
```

## Place

Published place opened from Roblox with Team Create on. Universe 10776373502, place 106586376894468 (owner user 3540923881). Saved as place version 10 on 2026-11-14 (no content change this section). Baseline tag `setup-baseline` = version 6. After approval: commit, tag `section-1`, `save_place` with notes "Section 1 approved (git section-1)".

## Rules

1. ONE SECTION PER SESSION. Finish this section's whole scope, then stop. Inside a section the skill's 'the run does not stop' rule applies in full; `section.py close N` passing is the only place you stop. Never start the next section's work, even with budget left.
2. STAY INSIDE CLAUDE CODE AND ROBLOX STUDIO. Work through the skills, MCPs and CLIs. No browser-driving tools (browser pane, Chrome), no web-GUI generators. WebSearch and WebFetch inside Claude Code are fine. Screen access is for Roblox Studio only.
3. NOTHING IN STUDIO BY THE USER'S HAND. Never ask the user to place, type, edit or configure anything in Studio, and never ask them to leave Claude Code or Studio. You may ask for: pressing Play or Stop, clicking Publish, approving a tool call, restarting a stuck MCP, or something purely mechanical no API or screen action of yours can reach.
4. LOG INTERVENTIONS AS THEY HAPPEN (run_log.py event --kind intervention): the user writes or edits code, makes a design or art decision (a genre named in the section 1 prompt is the brief, not an intervention), chooses between options, tells you WHAT is wrong rather than THAT something is wrong, or does something in Studio by hand. So never offer options: decide, and say why.
5. TIER 2 FIRST, fallback pre-authorised: take it without asking and log it as a fallback. 30-minute stall rule: one problem eats 30 minutes, fall back, log it, keep moving.
6. EVERY SESSION: ask for Roblox Studio screen access first (a grant does not survive a cleared session). 'Continue with the development of the <genre> game' means `section.py resume --game "<genre>"`: it finds the game and says which section is next.
7. THE LEDGER IS INITIALISED ONCE, in section 1. Every later call passes the --dir and --run recorded in HANDOFF.md. Bracket each ledger stage with start/end.
8. BEFORE CLOSING: save the place, write HANDOFF.md with `section.py handoff N`, replace every placeholder, run `section.py close N`. Then stop and ask the user to approve. Approval is free. If the user asks for changes, make them, log an intervention if they named what was wrong, update HANDOFF.md and close again. When the user approves ("approved", "yes that's all good"), run `section.py approve N` and say it is safe to clear the chat. Do not start the next section.

## Next section: first step
Section 2: Code and the playable loop (3 code, 4 map BLOCKOUT only, then play the loop on placeholder art).

Read `design/plan/00-INDEX.md`, `01-game-design.md`, `02-architecture.md` and `08-build-order.md` (section 2 steps 1 to 12). Ask for Roblox Studio screen access. Then, from the game folder:

```bash
python ~/.claude/skills/create-roblox-game/scripts/gen_config.py --dir "D:\Roblox Studio Games\Throw food for Anime"
python ~/.claude/skills/roblox-code/scripts/check.py
python ~/.claude/skills/roblox-build-orchestrator/scripts/run_log.py start --dir "D:\Roblox Studio Games\Throw food for Anime\build-runs" --run "ThrowFoodForAnime" --stage code
```

The first code written is `src/shared/Core/Format.luau` with `tests/Format.spec.luau`. Ask the user once to turn on Game Settings > Security > Enable Studio Access to API Services (input 4 in `plan/08`).
