# 02 Architecture: how the code is built

Follows the `roblox-code` skill: disk is the source of truth, Knit for lifecycle only, plain
RemoteEvents declared in one `Net.luau`, every tunable in generated Config, every rule that can
be pure is a pure Core module with a Lune spec. Four gates (`check.py`) green after every system.

## 1. Layout

```
src/shared/Config/GameConfig.luau     GENERATED from design/game.json (gen_config.py); never hand-edited
src/shared/Core/*.luau                pure rules, plain numbers and tables only (no Vector3/Instance)
src/shared/Net.luau                   every remote name, in one table
src/shared/Types.luau                 exported Luau types: Profile, HeroInstance, ThrowResult, PlotState
src/server/Services/*.luau            Knit services (systems list in game.json)
src/server/Vendor/ProfileStore.luau   session-locked DataStore library (vendored single file)
src/client/Controllers/*.luau         Knit controllers
src/client/Controllers/Screens/*.luau one module per screen, driven by UIController
tests/*.spec.luau                     one spec per Core module
tools/balance_sim.py                  pacing check against config.Pacing
```

Not in Rojo's tree (lives in the place, rebuilt by scripts kept on disk):
`ReplicatedStorage.Assets.{Characters,Foods,Props,VFX,Sounds}` and `Workspace.Map`.
Rojo only manages `ReplicatedStorage.Shared/Packages`, `ServerScriptService.Server`,
`StarterPlayerScripts.Client`, so those folders survive a sync. Their rebuild scripts
(`tools/studio/*.luau`, run through `execute_luau`) are the disk copy.

## 2. Core modules and what their specs pin

| Module | Rules | Spec must pin |
|---|---|---|
| `Throw` | effective power, landing zone, depth, landing Z, perfect window | a throw exactly at a zone's PowerReq lands in that zone; charge below MinCharge is rejected; depth clamps |
| `Luck` | combine every luck source | each source alone; caps (friends, server steps); order does not matter |
| `Roll` | hero, mutation, size, oneInN (RNG injected) | weights sum; craving triples one hero only; luck never lowers a rarer hero's chance; 100k seeded rolls match expected rates within 2% |
| `Income` | hero income, premium (best x mult), player income, sell value | stacking order; premium follows best; a premium hero is never its own "best" |
| `Offline` | earnings from seconds away | below MinSecondsAway pays 0; cap at CapHours |
| `Training` | reps -> power, rank from power | rank boundaries inclusive; DoubleTraining doubles reps not ranks |
| `Costs` | slot cost, affordability | slot n formula matches the table the sim uses |
| `Squad` | auto-place decision, equip best, fuse | the auto-place table in 01 section 1, case by case; fuse needs 3 identical; max stars |
| `Rebirth` | can rebirth, what resets, multipliers | reset keeps exactly `Keeps`; tier 10 is the cap |
| `Index` | discovery, zone completion, chance display | completing 8 of 8 only; variants do not count toward base completion |
| `Rewards` | daily streak, playtime gifts, codes | day rollover at UTC; a missed day resets to 1; double claim refused |
| `Receipt` | idempotent grants | the same receipt id twice grants once |
| `Schema` | default profile, migrations | every old version migrates to current; unknown keys survive |
| `Format` | 1.23K / M / B / T / Qa / Qi..., time | boundaries (999, 1000, 999999); never scientific notation |

Core takes and returns plain tables. RNG is passed in as a function so specs are deterministic.

## 3. Profile (saved data, `Schema` v1)

```lua
{ v = 1, yen = 0, yenLifetime = 0, power = 10, rebirth = 0,
  foods = { onigiri = true }, food = "onigiri", gear = 1, slots = 8,
  heroes = { [uid] = { id, mut, size, stars, slot } },   -- slot 1..slots, or 0 = bench
  nextUid = 1, index = { [heroId] = { seen = true, muts = {}, sizes = {} } }, zonesClaimed = {},
  luckyThrows = 0, passes = {}, receipts = {},            -- last 100 receipt ids
  daily = { day = 0, streak = 0 }, gifts = { day = 0, claimed = {} }, codes = {},
  tutorial = 0, settings = { music = 0.6, sfx = 0.8, fastReveal = false, lowDetail = false, autoSell = {} },
  stats = { caught = 0, rarest = 0 }, lastSeen = 0 }
```

DataService: ProfileStore session lock; load failure kicks with a retry message (never a blank
profile); autosave `AutosaveSeconds`; release on leave and in BindToClose. A profile is about
2 KB plus 40 bytes per hero (bench 60 + slots 24 = well under the 4 MB limit).
Studio: uses a separate store name (`Profiles_Dev`) so tests never touch live data.

## 4. Replication

- **Own state:** `State.Init` (whole profile-derived view) on join, then `State.Patch(path, value)`
  deltas. StateController is the only client code that listens; screens subscribe to it.
- **Plots:** PlotService holds `PlotState[plotId] = { owner, slots, heroes = { [slot] = {id, mut, size, stars} } }`.
  `Plots.Init` on join, `Plots.Patch` on change. **The server creates no character rigs.**
  SquadRenderController builds rigs on each client from `Assets.Characters`, so six players with
  24 heroes each cost the server nothing and never replicate a Humanoid.
- **Throw:** `Throw.Request` -> `Throw.Result { zone, z, heroUid, id, mut, size, oneInN, isNew, isBest, placed, sold }`
  to the thrower; `Throw.Seen { plotId, z, id, rarity }` to others (a lighter flight and reveal).

## 5. Net.luau (client -> server intents; server validates everything)

`Throw.Request(charge:number, lucky:boolean)`, `Train.Start()`, `Train.Stop()`, `Gear.Buy()`,
`Food.Buy(id)`, `Food.Equip(id)`, `Slot.Buy()`, `Squad.Place(uid, slot)`, `Squad.Bench(uid)`,
`Squad.Sell(uid)`, `Squad.EquipBest()`, `Squad.Fuse(uid)`, `Index.ClaimZone(zoneId)`,
`Rebirth.Do()`, `Daily.Claim()`, `Gift.Claim(i)`, `Code.Redeem(text)`, `Offline.Claim()`,
`Settings.Set(key, value)`, `Tutorial.Step(n)`, `Store.Gift(targetUserId, key)`.
Server -> client: `State.Init`, `State.Patch`, `Plots.Init`, `Plots.Patch`, `Throw.Result`,
`Throw.Seen`, `Toast`, `Announce`, `Event.State`, `Luck.State`.

Every handler: type check -> range check -> ownership check -> rate limit (token bucket per
player per remote) -> act. Ids are looked up in Config, never used as table keys unchecked.
Purchases with Robux never use a remote to grant: only `ProcessReceipt`.

## 6. StoreService

`ProcessReceipt`: look up `ProductId` in Config -> if `receipts[id]` return Granted -> apply the
grant to the profile -> record the receipt -> return `PurchaseGranted` only when the profile is
active (else `NotProcessedYet`). Passes: `UserOwnsGamePassAsync` cached on join, refreshed on
`PromptGamePassPurchaseFinished`. Summon scrolls: `PolicyService:GetPolicyInfoForPlayerAsync`;
when `ArePaidRandomItemsRestricted` the scroll cards are hidden and the six heroes are sold at
fixed prices instead. Odds come from `PremiumCharacters[].OddsPercent` (sum 100) and the same
table drives the SummonOdds screen, so the screen cannot disagree with the roll.

## 7. Character rendering on the client (the heavy part)

Template: `Assets.Characters.<heroId>` = baked R15 Model with a cheap Humanoid
(`EvaluateStateMachine = false`, name/health display off, `RequiresNeck = false`), root anchored,
every part `CanCollide/CanQuery/CanTouch = false`, Animate script and value objects stripped.
The Humanoid stays because classic shirts and pants only render beside one.

Per hero on a plot: clone -> `ScaleTo(Size.Scale)` -> pivot to pedestal -> Nameplate ->
idle clip on its Animator -> aura if mutated. Budgets (`meshes.json` budgets): animate at most
40 rigs (nearest first), show at most 90, others get a static pose or are hidden; `lowDetail`
halves both and turns auras into a ring. A pool reuses rigs when heroes are swapped.
Measured in section 2 on placeholder rigs, again in section 5 on a phone profile.

## 8. Other services (short)

LeaderboardService: three OrderedDataStores, written on a 60 s stagger per player, read every
60 s into a cache, shown on SurfaceGuis. EventService: Festival Hour clock from `os.time()`
so all servers agree; MessagingService for global banners (Mythic and above). TelemetryService:
`AnalyticsService` onboarding funnel (tutorial steps 1 to 8), economy events (every source and
sink), custom events (throw, rarity, rebirth, store open, purchase). TutorialService: step
persisted so a rejoin resumes.

## 9. Debug and test hooks

Every gameplay service prints why it refused an intent when `workspace:GetAttribute("TFADebug")`
is set (one lookup when off). Owner-only admin remotes are compiled out for non-owners by a
server check on `UserId`. A `Dev` server module (Studio only) can grant yen, power and heroes so
the pre-handover matrix can reach rebirth without playing fifteen hours.

## 10. As built in section 2 (where the code differs from the plan above)

- **Core modules** are fewer and broader than section 2's table: `Throw`, `Luck`, `Roll`, `Income`,
  `Progress` (training, costs, offline pay, rebirth), `Squad` (auto-place, equip best, fusion),
  `Collection` (index, daily and playtime rewards, codes, receipts), `Schema`, `Session` (the save
  lock), `World` (layout), `Lookup` (id maps), `Format`. Specs: `tests/*.spec.luau`, 84 tests.
  Core modules never require each other: callers pass `Lookup.of(Config)` in, so the same file
  runs under Lune and in Roblox.
- **No vendored ProfileStore.** DataService has its own session lock (`Core/Session`): one record
  `{ data, lock = { job, t } }`, taken on load, refreshed on every save, cleared on leave, honoured
  for 600 s. Nothing was downloaded into the project.
- **Replication** is whole snapshots, not path patches: `StateSnapshot` (coalesced, about every
  0.15 s when dirty) plus `StateTick(yen, power)` once a second; `PlotsSnapshot` / `PlotUpdate`
  carry whole plot states.
- **Remotes** are fewer and take an action word: `ThrowRequest`, `TrainSet`, `ShopBuy`,
  `FoodEquip`, `SquadAction`, `ProgressAction`, `RewardClaim`, `SettingSet`, `StoreGiftTarget`,
  `AdminCommand`, `ClientReady` (client to server); `StateSnapshot`, `StateTick`, `PlotsSnapshot`,
  `PlotUpdate`, `ThrowResult`, `ThrowSeen`, `HeroGranted`, `Toast`, `Announce`, `EnvUpdate`,
  `Leaderboards` (server to client). Every one is documented in `src/shared/Net.luau`.
- **World prompts** (train, gear, slot, equip best, food cart, daily, gift, index, rebirth) are
  ProximityPrompts handled on the server by `InteractService`: no remote to forge.
- **The map** is built by `src/server/World/Blockout.luau` at server start when `Workspace.Map`
  does not exist. Section 3's authored map must keep the anchor names listed at the top of that file.
- **UI** is a test HUD built in code (`HudController`, `MenuController`, `Ui/Make`). Section 3
  replaces the instances and keeps the controller methods and the remotes.
- **Services**: `ShopService` (foods, gear, slots), `ProgressService` (index rewards, rebirth),
  `EventService` (server luck, Festival Hour, banners), `InteractService`, `AdminService` replace
  the planned Food/Luck/Index/Rebirth/Tutorial services; luck sources and the tutorial step live in
  `StateService`.
