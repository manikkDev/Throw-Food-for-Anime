<!-- section: 5 -->
# HANDOFF: section 5 of 6 closed (Assembly, playtest and self-correction)

Game: `D:\Roblox Studio Games\Throw food for Anime`
Written: 2026-11-16T13:21:52+05:30

A cleared session starts from this file alone. Read it in full, then run:

```bash
python ~/.claude/skills/create-roblox-game/scripts/section.py resume --dir "D:\Roblox Studio Games\Throw food for Anime"
```

## Where things are
- REWORK 1 (owner's review of section 5, build `s5-04`):
  - `src/client/Controllers/HudController.luau`: toasts in their own top layer (`_raiseToasts`, `ToastLayer` DisplayOrder 40), bottom centre while a page is open, identical toasts merged; the BOOSTS tray (`_refreshBuffs`, `BUFF_ROWS`) replaces the event chip.
  - `tools/ui/screens_v47.py` (build_ui now imports it) -> `src/ui/HUD.model.json`, `src/ui/Reveal.model.json`: DAILY button, `BuffTray`, right column at y 140, odds at y 14, `"coreGui": {"playerList": false}`.
  - `src/client/Ui/RevealUi.luau` `finalOdds(oneInN, color, rarity)` + `ODDS_STYLE`; `src/client/Fx/ThrowSequence.luau` final framing 46%.
  - `src/client/Controllers/MenuController.luau`: `BtnDaily` badge, key 6, Gifts no longer routes to Daily.
  - Carry rules: `src/server/Services/ThrowService.luau` (`_placeFirst`, refuses throw and pad), `src/server/Services/TrainingService.luau` (refuses training), `src/client/Controllers/ThrowController.luau` (no pad lock, no throw), `src/client/Controllers/CarryController.luau` (plot-full message).
  - `src/client/init.client.luau`: Roblox player list off.
  - Icon `IconDaily` / `IconDailyBig` = rbxassetid://138384433800619 (`tools/ui/icons_v4_shapes.py`, `icons_v4_blender.py`, `icons_v4.py`, `assets/ui/icons_v4/IconDaily*.png`, `assets/ui/ids_icons_v4.json`).
  - `design/game.json` asset_plan: `ServerLuckBar` -> `BuffTray`.
  - Place: `ServerStorage.ImportedVfx` 76 emitters with a moderated texture: `ModeratedTexture` attribute holds the id, Texture blank (nothing deleted).
  - Skill: `~/.claude/skills/roblox-ui/scripts/verify_ui.py` player-list opt-out, exported, `_RobloxAI` commit 9d135d0.
- `HANDOVER.md`: the pre-handover matrix (every row measured or UNTESTED), the loop as played, defects fixed.
- `tools/mint_monetization.py` (new): creates the passes and developer products on the universe over Open Cloud, idempotent by name, writes the ids into `design/game.json` `config.Monetization`. Then `gen_config.py`.
- `design/game.json`: 23 `ProductId`s (6 passes 2087909054..2089703129, 17 products 3732218785..3732219154); `wiring_ignore` (archives the game never loads); `src/shared/Config/GameConfig.luau` regenerated.
- `src/client/Ui/Moments.luau` (`affordCheck`: the confirm dialog re-checks while open), `src/client/Controllers/UpgradeController.luau` (gear and slot dialogs pass it).
- `src/client/Ui/Pages/Squad.luau`: SELL asks first (`confirmSell`, red dialog: hero, yen, income lost).
- `src/server/Services/ProgressService.luau`: rebirth drops a carry whose hero it wiped.
- `tools/studio/build_auras.luau` (MODERATED texture list, dropped also on directly copied emitters) -> `work/auras/build.luau` -> `ReplicatedStorage.Assets.Auras` rebuilt in the place (UltraInstinct 22 emitters, FieryRitual 9).
- `tools/gen_icons.py` (FoodIcon_ aliases, PlayerHeadshot runtime key) -> `src/shared/Config/Icons.luau`; `tools/ui/screens_store_v5.py` (featured stage z 2) -> `src/ui/Store.model.json`.
- `assets/map/ids_textures.json`: 8 lane tiles re-uploaded and swapped in the place (1,130 Textures); 4 empty `DevForHireAsset` MeshParts deleted from the WaterfallCliff kit and its map copies (the `ServerStorage.StoreAssets` source untouched).
- Build stamp `s5-02` (`src/client/init.client.luau`, `src/server/init.server.luau`).
- Skill: `~/.claude/skills/create-roblox-game/scripts/verify_wired.py` (model.json scan, Icons bank, pointer attributes, FileMesh-only SpecialMesh, `wiring_ignore`, one DEFERRED line per key) exported and committed in `_RobloxAI` (b7abaf8).
- `work/wired_probe.lua` / `work/wired_report.txt`: the live wiring pass (re-run after the aura rebuild).

## Done this section
- REWORK 1: every point of the owner's review fixed and played in Studio (build `s5-04`); measurements in `HANDOVER.md` "Owner's review of section 5". Gates: `tools/gate.py` all green, `build_ui` 0 project-rule failures (fit_gate clean at 4 sizes), `verify_wired.py` static + LIVE green, `validate.py --stage-gate` green.
- Integration pass: `verify_wired.py` static + LIVE green ("every asset in the shipped tree resolves to a real id, and every live stage is represented"), re-run at the end; `validate.py --stage-gate` green; `tools/gate.py` all gates green (lune specs 93 passed); `build_ui.py` 0 project-rule failures, fit_gate clean at 4 sizes.
- Structural: 59 heroes (template, R15 rig, height, aura), 24 animation clips load (Length > 0), 78 sound roles load (TimeLength > 0), 351/378 keyed images resolve (the 27 others are leaderboard avatars filled at run time; measured loading in play).
- Played through the real UI on a wiped profile: throw -> catch -> carry -> place -> income -> train (taps, exit, locked station) -> gear (dialog) -> slot (dialog) -> food shop -> rebirth x3 -> daily -> playtime gift -> index zone claim -> squad bench / sell / fuse -> settings -> code (and re-use refused) -> store -> summon odds (100%) -> a Robux test purchase (lucky throws x4 -> x5). Every step's read-back is in `HANDOVER.md`.
- Monetisation: 6 passes and 17 products created on universe 10776373502 with names, descriptions and the game's icons; the list endpoint read back each id and price.
- 4 defects found in play and fixed, each re-measured (`HANDOVER.md` "Defects found and fixed").

## Decisions and why
- Toasts get their own top layer instead of raising the whole HUD: the HUD must stay under the pages, only the notices must not. With a page open they sit at the bottom centre (the page's title stays readable).
- Roblox's player list is off: the game has world leaderboards and no leaderstats to list, and the top-right corner holds the settings gear, the boosts tray and the right column; with the list on, a second player's arrival would cover them.
- The boosts tray has no Robux button: Server Luck is in the Store; a buy button in the top-right corner sat in the player-list zone and made the tray a shop.
- A full plot keeps the hand-carry: the catch is already saved on the bench, so carrying it costs nothing and lets the player swap it onto any pedestal; the toast says both options.
- Passes and products were created now (plan/08 section 5 lists it; the section 2 and 3 handoffs carried it as a debt). Names and descriptions are the Store's own copy, so the Roblox listing and the game say the same thing; images are the game's v4 icons. Regional pricing off (prices are the design's).
- SELL gets a confirmation and FUSE does not: selling loses a hero, fusing only upgrades one.
- Moderated textures are dropped in the builder, not hand-deleted in the place, so a rebuild cannot bring them back.
- The owner's account owns every pass it creates, so the owner plays with all pass effects; pass-free play has to be checked on another account (two-player test).
- `wiring_ignore` lists archives the game never loads (ImportedVfx, CharacterSources, StoreAssets, AuraShowcase): the owner's raw imports must stay (never delete) and are not part of what players see.
- The Studio-only dev route for purchases (`state.studio` -> AdminCommand) is now bypassed for every row because all ids are non-zero; it stays as the fallback for a row added later without an id.

## Unproven
- Rework 1: the 1-in-N looks for Common, Rare, Epic, Mythic and Secret (only Legendary seen); the timed 2x Yen row of the tray; a full plot AND a full bench in play (spec only); toasts with two pages stacked (Codes over Settings).
- Two players: plot ownership side by side, two-row leaderboards, gifting a pass, server luck stacking, each player's HUD. Studio MCP runs one client.
- Phones: verify_ui reports 87 touch targets under 44 px at 844x390; no phone session played.
- Sounds heard (78 roles load; nothing here can hear).
- A pass bought through the Roblox prompt (the owner already owns all passes); the starter pack, summon scrolls, limited hero, yen/training packs, server luck, offline 2x and gift products bought through the prompt (only Lucky Throw x1 was bought; all share the receipt path, which is not evidence).
- 42 lane heroes and 8 premium heroes not caught in play this section (structural checks only); 10 of 12 foods not thrown; TrainLift / TrainPush / TrainMeditate not seen; jump and land not watched; OfflineEarnings page not opened.
- Each VFX and aura looked at frame by frame this section (the owner reviewed them in section 4).
- `rbxassetid://203785492` (wrong asset type, 3 lines per client): source not found in the game's tree or the tester's avatar.

## Debts
- Interventions this section: 1 (owner's review of section 5: toasts behind pages, odds on the head and flashier by rarity, boosts tray, Daily button, throwing while carrying, full plot, console errors). Healed: all points fixed and measured in play.
- The 14 earlier owner requests in the ledger (sections 1-4 reviews) were closed as `resolved`: each was carried out and approved with its section. `run_log.py debts`: nothing open.
- No fallbacks or stalls. Test-tool notes, not game defects: a click sent right after a move can miss (wait 200-300 ms), rows below a ScrollingFrame's view must be scrolled into view first, and `screen_capture` does not draw Roblox's purchase dialog (a desktop screenshot does).

## Ledger

Initialised once in section 1. Never run `init` again.

```bash
python ~/.claude/skills/roblox-build-orchestrator/scripts/run_log.py counter --dir "D:\Roblox Studio Games\Throw food for Anime\build-runs" --run "ThrowFoodForAnime"
```

## Place
Saved to Roblox (Team Create) 2026-11-16 as place version 284 (build `s5-04`, rework 1); before it version 277 (build `s5-02`). Universe 10776373502, place 106586376894468, owner user 3540923881. Not published. Rollback point for the approved section 4: tag `section-4` = place version 271.

## Playtest findings
Rework 1 (owner's review): see `HANDOVER.md` "Owner's review of section 5" - all seven points fixed and measured in play.
Full matrix in `HANDOVER.md`. Found and fixed:
1. Gear/slot dialogs stuck on NEED MORE YEN after income passed the price -> re-check while open (measured flip to BUY SLOT when 5K yen arrived).
2. SELL removed a hero in one click -> confirmation dialog (looked at in game; sold after confirm, plot 8 -> 7).
3. Rebirth left a wiped hero in the hands for up to 150 s -> carry dropped (measured `Carrying` nil after rebirth 3).
4. 7 aura emitters on moderated textures logged "Asset is not approved" on every server and client -> removed by the builder (0 left; console clean of them).
5. Store products had id 0 -> 23 created; a test purchase granted its lucky throw.
Measured fine: training gain 23 -> 36 power with taps; bench income 461 -> 281/s (120 x 1.5 rebirth); fuse +1 -> +2/s; zone claim luck x1.12 -> x1.14; daily +1.5K and +1% luck; code once only; data back after 5 server shutdowns; legs move while carrying (hip -4..62 deg).

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
Section 6: Publish (12 publish).
Ask for Roblox Studio screen access, then run `python ~/.claude/skills/create-roblox-game/scripts/section.py resume --game "throw food"`. Before publishing, the owner should cover the two-player and phone rows (input 6 in `design/plan/08-build-order.md`): Studio Test > Clients and Servers with 2 players, and one session on a phone. Publishing itself needs the owner's go-ahead (plan/08 input 7).

## Earlier handoffs

- `D:\Roblox Studio Games\Throw food for Anime\design\handoffs\HANDOFF-section-1.md`
- `D:\Roblox Studio Games\Throw food for Anime\design\handoffs\HANDOFF-section-2.md`
- `D:\Roblox Studio Games\Throw food for Anime\design\handoffs\HANDOFF-section-3.md`
- `D:\Roblox Studio Games\Throw food for Anime\design\handoffs\HANDOFF-section-4.md`
