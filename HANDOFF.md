<!-- section: 2 -->
# HANDOFF: section 2 of 6 closed (Code and the playable loop)

Game: `D:\Roblox Studio Games\Throw food for Anime`
Written: 2026-11-14T17:27:01+05:30

A cleared session starts from this file alone. Read it in full, then run:

```bash
python ~/.claude/skills/create-roblox-game/scripts/section.py resume --dir "D:\Roblox Studio Games\Throw food for Anime"
```

## Where things are
- Code (all new this section): `src/shared/Net.luau` (22 remotes, each documented); `src/shared/Core/` = `Throw, Luck, Roll, Income, Progress, Squad, Collection, Schema, Session, World, Lookup, Format`; `src/shared/Config/GameConfig.luau` (GENERATED from `design/game.json`, never hand-edit); `src/server/Services/` = `Data, State, Plot, Squad, Economy, Shop, Throw, Training, Event, Progress, Rewards, Store, Leaderboard, Interact, Admin, Telemetry`; `src/server/Logic/Guard.luau`; `src/server/Config/ServerConfig.luau` (GENERATED from `server_config` by `tools/gen_server_config.py`); `src/server/World/Blockout.luau`; `src/client/Controllers/` = `State, Hero, Throw, Hud, Menu, Tutorial`; `src/client/Ui/Make.luau`.
- Tests: `tests/*.spec.luau` (Format, Throw, Roll, Income, Squad, Collection, World) + `tests/Support.luau`. 88 tests.
- Tools: `tools/gate.py` (all four gates), `tools/balance_sim.py`, `tools/studio/bake_characters.luau`.
- Hook: `.claude/hooks/luau_gate.py` now auto-formats format-only failures and reports only failing lines (copied to `_RobloxAI/bootstrap/luau_gate.py`).
- Contract: `design/game.json` (roster replaced by the 31 imported heroes; zones renamed; `config.World`, server, reward and product fields added; `systems` now lists what exists). Specs regenerated: `design/{map,meshes,ui,sfx,animations,vfx}.json`.
- Characters: `design/characters/README.md` (how the R15 set was built, the head rule, the bake, traps), `design/characters/roster.json` (hero id -> source avatar), pictures in `design/characters/final/` and `preview/`.
- Plans updated: `design/plan/00-INDEX.md`, `01`, `02` (section 10 "As built"), `03`, `04`, `08`.
- Studio (the place, not Rojo): `ReplicatedStorage.Assets.Characters` = 31 baked templates `Char_<id>`. `ServerStorage.CharacterSources.R15_Final` (31 finished rigs) and `.R6_Originals` (the user's 31 imports, never delete). Workspace now holds only Terrain, Camera, Baseplate, SpawnLocation; the map is built by code at server start.
- CLAUDE.md: new "Where the game's pieces live" block and three traps.

## Done this section
- `python tools/gate.py`: PASS code gates (rojo build, 88 lune tests, selene, stylua), PASS config matches contract, PASS server config matches contract, PASS contract valid, PASS pacing (zone 2 at 1 m 48, zone 3 at 13 m 47, zone 4 at 43 m 48, zone 5 at 2 h 31, zone 6 at 6 h 29, rebirth 1 at 13 h 09).
- Studio is live-synced by Rojo: build stamp `BUILD s2-05` printed by server and client; Studio holds the 16 services and 6 controllers.
- Played in Studio through the MCP (see "Loop playtest" below): throw, catch, plot fill, income, buy food/gear/slot, training, daily, code, gift timer, lucky throw into zone 2, every store product and three passes through the test grant path, index zone claim, fuse, bench, place, sell, rebirth, rejoin with data intact, another player's plot and throw (simulated through the real remotes), Auto Throw, low-detail and hide-others settings.
- Characters: 31 R15 rigs rebuilt, confirmed by the user ("go with R15"), head rule applied to 28, baked to templates (15 Motor6Ds each, about 103 instances per hero).
- Performance: 135 heroes (2,521 parts, 130 idle tracks) at 60.0 fps average, worst frame 19.1 ms, +106 MB, on the dev PC.
- Saving: real DataStore in Studio (`Profiles_Dev`), profile survived stop/start (rebirth tier, premium heroes, VIP slots).

- Independent review (roblox-reviewer, static read of all of `src/`): no remote where a bad payload gives a server error, a free grant or a corrupted profile. 18 findings (3 high, 6 medium, 9 low). What was done about each:
  - FIXED, seen in play: final saves started by PlayerRemoving were not waited for at shutdown, which left the save lock behind and locked the profile out for 10 minutes (this is what broke the Studio sessions on 2026-11-14). `DataService` now counts every release in flight and BindToClose waits for all of them. Check: Stop during Auto Throw, then the record read back with `lock=none` and the last 7 catches saved.
  - FIXED, seen in play and in specs: a lock left behind no longer locks a player out. `Core/Session`: Studio sessions take each other's locks at once; any live-looking lock is taken over after 30 s of waiting (the old server's next save refuses to write, so there is still one writer); dead after 600 s as before. Check: a planted `studio-*` lock was taken over on join ("took over a save lock left behind" in Output), HUD filled.
  - FIXED: lifecycle is strictly ordered per player (loaded, ready, releasing): a leave waits for the join handlers, so a plot can no longer be assigned to a player who has already been released; late-registered handlers run exactly once; the "data opened on another server" path now runs the release handlers; a rejoin to the same server waits for the previous final save.
  - FIXED: the pass "purchase finished" signal is client-raised, so it is now a hint: confirmed with `UserOwnsGamePassAsync` before anything is saved; unconfirmed turns the pass on for the session only (no VIP slots written). Failed ownership checks at join are retried instead of being remembered as "not owned".
  - FIXED: a gift is acknowledged only after the receiver's profile is saved too; a receipt whose save failed is saved again on retry before "granted" is returned.
  - FIXED, seen in play: offline pay is banked in the profile (`away`), `lastSeen` is stamped when it is banked and every tick, and rebirth clears it. Check: left without claiming, rejoined, "Away 8m 44s: +1.52T yen" was still there and paid once.
  - FIXED, seen in play: the client no longer asks for a throw inside the server cooldown (Auto Throw was losing every second throw with fast reveal). Check: 5 auto throws at 3.0 to 3.6 s, none refused.
  - FIXED: leaderboard ClientReady rate-limited; leaderboard loop asks `IsMock()` after DataService has decided; SquadAction limited to 3/s and Equip Best only broadcasts when a seat moved; friend-luck recount excludes the leaver and never writes for a player who left; `_clientReady` and gift targets cleared on PlayerRemoving; `Schema.upgrade` never stamps a newer save down.
  - FIXED: promo codes moved out of the replicated config into `server_config` in `design/game.json`, generated to `src/server/Config/ServerConfig.luau` by `tools/gen_server_config.py` (gate fails if a code is put back in `config`).
  - PARTLY: the test menu still rebuilds its list on every snapshot; it now skips the rebuild while a text box in it is focused (a half-typed code is no longer wiped). The real UI in section 3 must update rows in place.
  - PARTLY: plot refreshes are not coalesced into a dirty set; the rate limit and the no-change skip bound them.
  - NOT CHANGED: `Server.AdminUserIds` stays in the shared config (the owner's user id is public on the game page; the check is server-side).
- New Unproven from these fixes: the 30 s takeover of a LIVE server's lock is covered by specs only (needs two real servers); both branches of the pass-purchase confirmation need a real pass purchase (section 5, when pass ids exist) to learn whether Roblox confirms in-session.

## Decisions and why
1. Roster = the user's 31 imported avatars (R15), with our own display names ("Fox Ninja", "Curse King"...). Owner decision on 2026-11-14, overruling the original-trope roster; risk recorded in `plan/03` section 1. Five heroes per zone, one per rarity, a Mythic in the last zone, so the roll table changed (Common 67.6% at base luck) and pacing was re-tuned.
2. Zones renamed to fit the heroes: Sakura Schoolyard, Pirate Harbor, Ninja Village, Samurai Castle, Hero City, Realm of Legends.
3. R15 over R6: identical standing still, but elbows/knees/waist allow real idles and Roblox emotes; pose test held for capes, auras and weapons.
4. Head rule: the default R15 head is hidden when a face cover or a hair-with-face piece replaces it (it is 0.09 studs taller than the classic head those pieces were made for).
5. Bake builds 15 Motor6Ds by hand: `Humanoid:BuildRigFromAttachments` rebuilds physics constraints in this Studio.
6. Own session lock instead of a vendored ProfileStore: nothing downloaded, the lock rule is a pure tested module (`Core/Session`: dead after 600 s, taken over after a 30 s wait, Studio sessions take each other at once).
7. The server spawns no hero rigs; clients render from compact plot state (confirmed cheap: see performance).
8. Whole-snapshot replication (coalesced) plus a one-second Yen/Power tick: simplest thing that is debuggable; a profile is a few KB.
9. World prompts are server-side ProximityPrompts (`InteractService`): no remote to forge.
10. The map is a code-built blockout, not a roblox-map spec: nothing in the place can drift, and section 3 replaces it behind the same anchor names.
11. The UI is a code-built test HUD and one list panel that reaches every feature; section 3 replaces the instances and keeps controller methods and remotes.
12. Charge bar swings 0 -> 1 -> 0; marks show the charge that reaches each zone; top 8% is perfect (+10% luck). Auto Throw releases just below perfect so throwing by hand is still worth more.
13. A catch never blocks: auto-place, swap, bench, or sell, decided in `Core/Squad.placement`; premium heroes are never displaced or auto-sold.
14. Premium heroes earn a multiple of the player's best lane hero; "minutes of your income" for rewards and Yen packs: nothing sold goes stale.
15. Lucky Throw luck lowered from 25 to 12 after the first play test (one free throw produced a 1,200 yen/s hero at minute five).
16. Throw cycle measured at about 2.3 to 3.5 s (plan assumed 5 s); the simulator now uses 3.5 s and the last zone gate moved from 36M to 40M Power to stay on target.
17. Studio sessions use their own stores (`Profiles_Dev`, `LB_*_Dev`) after a test grant reached the live-named leaderboard (cleaned: 0 entries left).
18. The HUD income line is frozen during the throw sequence so it cannot give the catch away.

## Unproven
- A real second client. A second player's plot and throws were simulated through the real remotes; plot assignment for two real players, friend luck and gifting between players are unexercised. Needs one "Server & Clients" test with 2 players.
- Anything on a phone: frame rate with a full server, touch on the THROW button, the scaled test HUD.
- Real Robux purchases: product and pass ids are 0 until section 5; `ProcessReceipt` has only been read, never run. Grants were tested through the Studio-only test path that calls the same `GrantProduct`.
- Festival Hour and the server-luck timer running out (only their start was seen).
- Playtime gifts actually paying (only the "not ready" message was seen), day rollover of the daily streak (covered by specs, not by play).
- BindToClose and autosave under a real (non-Studio) server shutdown; Stop in Studio was checked (lock released, data saved).
- Leaderboards in a live server (they worked in Studio with API access).
- StreamingEnabled is on: far zones loaded for the follow-camera on the dev PC; not checked on a slow connection.
- The catch reveal card during a real throw was not photographed (timing); it was seen for granted heroes.
- Sound, animation beyond Roblox's default idle, VFX, real UI, real map, food meshes: not built (sections 3 and 4).
- The 8 premium heroes have no avatars: they render as neon blocks.
- The reference game was never played by us.

## Debts
- Intervention (logged): the user imported 31 named avatars and chose them as the roster; then chose R15; then reported the forehead dots twice (the second time naming Vegeta). All healed: contract updated, head rule covers 28 of 31 and the other 3 have nothing underneath.
- Process note: sections 1 and 2 ran in ONE chat session at the user's request ("let's begin with the implementation"), against the skill's one-section-per-session default.
- Fallback: blockout built in code instead of with roblox-map (decision 10). The proven map is section 3's job; nothing is owed.
- Fallback: two-client playtest replaced by simulation through the remotes plus a request to the user; listed under Unproven.
- No stalls over 30 minutes.
- Debt for section 3: avatars for the 8 premium heroes; `assets/meshes/manifest.json` entries for the 31 rigs.
- Debt for section 5: mint passes and products and write the ids into `config.Monetization`; needs Open Cloud key scopes (plan/08 input 3).

## Ledger

Initialised once in section 1. Never run `init` again.

```bash
python ~/.claude/skills/roblox-build-orchestrator/scripts/run_log.py counter --dir "D:\Roblox Studio Games\Throw food for Anime\build-runs" --run "ThrowFoodForAnime"
```

## Place
Published place opened from Roblox with Team Create on. Universe 10776373502, place 106586376894468. `section-1` = place version 34. The place now also contains the baked templates and the archived character sources. After approval: commit, tag `section-2`, `save_place` with notes "Section 2 approved (git section-2)".
No new place version was saved at close (CLAUDE.md rule 5: one labelled save per approved section). The Team Create place holds the current state, including the 31 baked templates; the labelled save and its version number are recorded in CLAUDE.md on approval.

## Loop playtest
Run in Studio Play through the MCP on 2026-11-14 (one real client; server and client build stamps `s2-01` to `s2-05` seen in Output; no script errors in any run; the only Output warning is a Roblox asset-type message for an id that is in none of our instances).

| What | Result |
|---|---|
| Boot | plot 1 assigned, character moved to the plot spawn, HUD filled, 22 remotes |
| First throw (T held 1 s on the pad) | guaranteed Uncommon "Emerald Hero" on pedestal 1, +3 yen/s |
| 6 more throws | 7 heroes, fanned out from the centre pedestal; objective advanced to "Buy Dango" |
| Buy Dango, Sandbag, slot 9 | toasts; food chip, gear label and slot sign updated; unknown food id ignored |
| Daily, code WELCOME, gift | paid once each; second claim refused; gift reported time left |
| +500 Power, Lucky Throw at full charge | landed in zone 2, Flame Big Epic, "1 in 984", luck 31.7 (before the Lucky Throw nerf) |
| Products (LuckyThrow5, ServerLuck, YenPack15m, Train5m, SummonScroll3, StarterPack, SakuraShogun, OfflineDouble) | all granted; server-luck banner; 3 summon heroes swapped onto the plot |
| Passes Vip, DoubleYen, AutoThrow | income doubled; VIP +2 slots after the fix; Auto Throw made 7 throws in 16 s |
| Training 4 s on Sandbag | +12 Power (3 per rep), training line shown, stopped on request |
| Index | zone 1 completed, claimed once (+44.2M yen = 30 min of income), second claim refused; panel shows live chances |
| Fuse, bench, place, sell | 3 identical -> 1 star; second fuse refused; slot 99 and double sell ignored |
| Rebirth | at 200M Power and 1T yen: reset to 10 Power, 0 yen, starter food, 5 premium heroes kept, board shows [R1] |
| Stop and start | rebirth tier, yen, premium heroes and VIP slots all back |
| Second plot (26 heroes) and another player's throw | rendered; their food flew down their lane |
| Settings | low detail: 0 idle tracks; hide others: 5 rigs; both off: 31 rigs, 26 tracks |
| Bad input | charge 5, table as uid, unknown ids: ignored, no error |
| Wipe then throw | fresh profile, tutorial restarted, income line held until the reveal |

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
Section 3: World and visuals (4 map (full), 5 meshes + colour + materials, 6 ui).
Read `design/plan/00-INDEX.md`, `03-characters-and-assets.md`, `04-world-and-map.md`, `05-ui-ux.md`, `design/characters/README.md` and `08-build-order.md` (Section 3). Ask for Roblox Studio screen access. Then:

```bash
python tools/gate.py
python ~/.claude/skills/roblox-build-orchestrator/scripts/run_log.py start --dir "D:\Roblox Studio Games\Throw food for Anime\build-runs" --run "ThrowFoodForAnime" --stage map
```

Order inside section 3: (1) ask the user for the two things only they can do: a 2-player "Server & Clients" test of this build, and avatars for the 8 premium heroes (or the word to assemble them); (2) the real map with `roblox-map`, keeping the anchor names at the top of `src/server/World/Blockout.luau`; (3) foods, gear, plot kit and zone props per `design/meshes.json`; (4) the real UI from `design/ui.json`, replacing the instances built by `HudController` and `MenuController` and keeping their methods and remotes.

## Earlier handoffs

- `D:\Roblox Studio Games\Throw food for Anime\design\handoffs\HANDOFF-section-1.md`
