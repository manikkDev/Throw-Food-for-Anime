# 08 Build order: what each section does and how it is proven

One section per session. First command of each: 
`python ~/.claude/skills/create-roblox-game/scripts/section.py resume --game "throw food"`.
Each section ends: gates green -> `section.py close N` -> user approves -> commit -> tag
`section-N` -> `save_place` with notes "Section N approved (git section-N)".

## Section 2: code and the playable loop (on placeholder art)

Order matters: each step is green on `check.py` before the next.

1. `gen_config.py` -> `GameConfig.luau`; add `gen_config.py --check` and
   `tools/balance_sim.py --check` to the gate run.
2. Core + specs in this order: Format, Schema, Throw, Luck, Roll, Income, Costs, Training,
   Squad, Offline, Index, Rebirth, Rewards, Receipt. Port the sim's roll to call the same rules
   (or assert both produce the same rates) so the sim and the game cannot disagree.
3. Net.luau, Types.luau, DataService (vendor ProfileStore; dev store name in Studio).
4. PlotService + blockout map (04 section 6) emitted by `roblox-map`.
5. ThrowService + ThrowController with a placeholder flight (a ball, a coloured capsule hero).
6. SquadService, EconomyService tick, StateController, minimal HUD text.
7. TrainingService, FoodService, slot buying. **Play the loop now** (throw, catch, earn, buy,
   train, reach zone 2) before anything else is written.
8. IndexService, RebirthService, RewardsService, LuckService sources, EventService.
9. StoreService with ids = 0 (prompts no-op in Studio; grants tested through the Dev module).
10. LeaderboardService, TutorialService, TelemetryService.
11. Performance probe: 144 placeholder rigs (real R15 dummies) on six plots, measure frame time;
    fix the render budget numbers now, not in section 5.
12. `roblox-reviewer` pass on remotes and data safety; fix findings.

Exit: four gates green; build stamp in Output; a two-client playtest reaches zone 3, buys food,
gear and a slot, fuses, rebirths (via Dev grants) and rejoins with data intact.

## Section 3: world and visuals

1. Characters: `looks.json`, bake, QA sheets, manifest (03 section 1). Close the three open
   checks first (published-server load, accessory limits, phone cost).
2. Foods, gear, plot kit, zone props (03 sections 2 to 4), licence ledger.
3. Map: full `roblox-map` spec from `map.json`, prover PASS, emit, dress with props.
4. UI: every screen in `ui.json` as a resolved tree, `verify_ui.py`, icons uploaded, screens
   bound to StateController, all opened in play at phone and desktop size.
Fan-out: map, mesh and UI workers in parallel; every Studio write on the main thread.

## Section 4: motion and sound

Animation (14 clips), VFX (27), SFX (34 roles), per 06. Then the throw sequence is assembled and
tuned as one piece (camera, timing, skip), because that seam belongs to no single worker.

## Section 5: assembly and playtest

Integration pass over every row of `asset_plan`; `verify_wired.py` static and live; mint passes
and products and write the ids into config; two-client playtest; `HANDOVER.md` with the matrix:
every hero spawned and seen, every food thrown, every screen opened, every effect seen, every
sound role heard or UNTESTED, two rebirths, purchases in test mode, data survives rejoin and
server shutdown, phone-size run.

## Section 6: publish

07 section 5. Needs the user's go-ahead.

## Inputs needed from the user

| # | What | When | Why I cannot do it |
|---|---|---|---|
| 1 | Confirm or veto the original-roster rule (03 section 1) | before section 3 | it is your business risk; the plan assumes original tropes |
| 2 | Optional: save anime-style outfits on your Roblox account, or send user/outfit ids you like | before section 3 | fastest source of whole looks; anything that copies one specific character will be skipped |
| 3 | Add scopes to the Open Cloud key: universe-places write, developer-product and game-pass write, (asset write exists) | before section 5 | keys are yours; you run `set-secret.ps1` |
| 4 | Game Settings > Security > "Enable Studio Access to API Services" ON | start of section 2 | DataStore tests in Studio; a settings toggle I should not flip for you |
| 5 | If animation upload by API is not possible: right-click > Save to Roblox on 14 clips | section 4 | animations must be owned by you to play live |
| 6 | Press Play/Stop when asked; listen to the sound pass; play one session on your phone | sections 2, 4, 5 | nothing in the toolchain can hear or hold a phone |
| 7 | Publish go-ahead, questionnaire answers, ad budget | section 6 | yours to decide |
| 8 | A Roblox group, if you want revenue split or co-owners later | any time | optional; user-owned works |

## Risk register

| Risk | Likelihood | Effect | Plan |
|---|---|---|---|
| A look item is moderated later | medium | one hero looks wrong | manifest lists every asset id per hero; swap the item, re-bake that hero |
| 100+ dressed rigs too heavy on phones | medium | low fps on full servers | measured in section 2 (step 11) and 3; animate/visible caps; low-detail mode; layered clothing limited to 1 item |
| Paid/off-sale avatar items fail to load on NPCs in live servers | low-medium | missing accessories | tested in a private published server before the roster is committed; fall back to free items |
| Marketplace-items-in-experiences policy returns | low | must offer items for sale or drop some | research/03 open item 4; roster favours free items so the exposure is small |
| Animation upload needs a manual step | medium | 5 minutes of the user's time | input 5 |
| Economy feels different from the sim | medium | pacing off | sim runs in the gate; telemetry in week 1; all numbers are data |
| DataStore loss or duplication | low | player trust | ProfileStore session lock, receipts ledger, kick on load failure, reviewer pass |
| Genre fatigue or a faster anime clone | medium | weaker launch | the reveal, cravings, fusion and rebirth are the differences; ship weekly |
| Scope | high | never ships | P0 = sections 2 loop; anything not in `asset_plan` or `systems` waits for an update |
