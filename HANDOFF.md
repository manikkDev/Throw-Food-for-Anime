<!-- section: 6 -->
# HANDOFF: section 6 of 6 closed (Publish)

Game: `D:\Roblox Studio Games\Throw food for Anime`
Written: 2026-11-16T18:47:07+05:30

A cleared session starts from this file alone. Read it in full, then run:

```bash
python ~/.claude/skills/create-roblox-game/scripts/section.py resume --dir "D:\Roblox Studio Games\Throw food for Anime"
```

## Where things are
- `tools/live_check.luau` + `tools/live_check.py` (new): runs in a REAL Roblox server of the place (Open Cloud Luau Execution): loads every animation id (`Config/Animations.luau`) and every sound (`Config/SoundBank.luau`), reports failures; writes `work/live_check.json`.
- `tools/set_experience.py` (new): max players = `config.Server.MaxPlayers` (6) and the store description over Open Cloud. Never touches visibility.
- `design/game.json` `publish`: `published_version` 284, `build` s5-04, `visibility` PRIVATE (+ note), `live_check`, `open`.
- Roblox: the place was published by the owner from Studio (version 284). The experience stays PRIVATE.

## Done this section
- Published version 284 (the owner pressed Publish; Luau Execution tasks resolve the place to `versions/284`).
- Live server (Open Cloud Luau Execution on version 284): 24/24 animations readable (KeyframeSequenceProvider, keyframes > 0), 78/78 sounds loaded with TimeLength > 0, 59 hero templates, the map's plots present.
- The game's server boots in a live server: `Knit.AddServices(ServerScriptService.Server.Services)` + `Knit.Start()` -> started, no error, 24 remotes, plot boards dressed ("Empty plot"); the published HUD has `BuffTray` and `BtnDaily`, config has the 17 products.
- `tools/gate.py` all green; `validate.py --stage-gate` green.

## Decisions and why
- The experience stays PRIVATE: the owner releases it when they choose (2026-11-16). Nothing in the pipeline changes visibility; `set_experience.py` has no visibility option on purpose.
- The live check runs in Open Cloud Luau Execution instead of joining with the Roblox Player: it is a real Roblox server with the real asset permissions, needs no account action and returns numbers. A session there does NOT run the place's scripts (the boot line never appears, the dev showcase is not deleted), so the boot is checked by starting the Knit services inside the session.
- No store description or max-players change was written through Studio's Experience Settings: it is a web view the owner did not grant screen access to; the API route waits for the key's write operations.

## Unproven
- Max players is still 50 (the game has 6 plots: a 7th player is kicked with "This server is full"). The store description is NOT set either: a universe PATCH answers 200 and changes nothing (the text lives on the root place). Every place write (serverSize, displayName, description) still returns 403 "Scope not authorized" although the key lists `universe-places:write`. Fix: the owner sets Max Players to 6 on Creator Hub, or once the place scope works `python tools/set_experience.py --apply`.
- A player joining the live game (only the owner can, while private): the Player client, purchases in production, DataStores with a real profile.
- Two players, phones, sounds heard (carried from section 5).
- Icon, thumbnails, maturity questionnaire, sponsored ads: the owner's, at release (plan/07 section 5).

## Debts
- Interventions: 0 design changes. The owner pressed Publish and added API key scopes (both free asks: a click and their own credential), and decided the game stays private until they release it.
- Fallback: the Studio Experience Settings route was declined (web view access), so the settings go through the API; not healed until the key's write operations are on (see Unproven).
- No stalls. `run_log.py debts`: nothing open.

## Ledger

Initialised once in section 1. Never run `init` again.

```bash
python ~/.claude/skills/roblox-build-orchestrator/scripts/run_log.py counter --dir "D:\Roblox Studio Games\Throw food for Anime\build-runs" --run "ThrowFoodForAnime"
```

## Place
Universe 10776373502, place 106586376894468, owner user 3540923881. Published version 284 (build `s5-04`), 2026-11-16; also the Team Create save labelled "Section 5 approved (git section-5)". Visibility PRIVATE.

## Live server check
Open Cloud Luau Execution on version 284 (`python tools/live_check.py`): animations 24/24 ok, sounds 78/78 ok, 59 hero templates, plots present; Knit server boot in the same kind of session: started, no error, 24 remotes. Report: `work/live_check.json`.

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
None. This was the last section. When the owner wants to release: tick write on the key's `universe` and `universe-places`, run `python tools/set_experience.py --apply` (6 players, description), then the owner makes the experience public, fills the maturity questionnaire and adds the icon and thumbnails on Creator Hub.

## Earlier handoffs

- `D:\Roblox Studio Games\Throw food for Anime\design\handoffs\HANDOFF-section-1.md`
- `D:\Roblox Studio Games\Throw food for Anime\design\handoffs\HANDOFF-section-2.md`
- `D:\Roblox Studio Games\Throw food for Anime\design\handoffs\HANDOFF-section-3.md`
- `D:\Roblox Studio Games\Throw food for Anime\design\handoffs\HANDOFF-section-4.md`
- `D:\Roblox Studio Games\Throw food for Anime\design\handoffs\HANDOFF-section-5.md`
