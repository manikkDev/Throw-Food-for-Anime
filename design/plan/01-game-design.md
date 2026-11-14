# 01 Game design: rules and formulas

All numbers live in `design/game.json` `config` and are generated into `src/shared/Config`.
This file says what the numbers MEAN. Names in `code font` are config keys.

## 1. One throw, start to finish

```
on pad -> hold (charge 0..1 over ChargeSeconds) -> release
  client: sends Throw.Request(charge, useLuckyThrow)
  server: validates -> zone -> luck -> roll -> grants hero -> replies Throw.Result
  client: flight (follow-cam) -> land -> reveal -> hero dashes home -> pedestal
```

Server validation (reject silently with a reason code, never trust the client):
on own `Plot_ThrowPad` (distance check), `ServerCooldownSeconds` since last accepted throw,
`MinCharge <= charge <= 1`, equipped food owned, lucky throw count > 0 if requested.

**Zone.** `eff = Power x food.PowerMult x charge`. Landing zone = the furthest zone with
`PowerReq <= eff`. The charge bar shows one mark per unlocked zone, so releasing early is how a
player farms an earlier zone on purpose. `depth` = how far `eff` sits between this zone's
`PowerReq` and the next one (0..1, clamped; 1 in the last zone when eff >= 2x its PowerReq).
Landing Z inside the band = `z_from + depth x LengthStuds`; X = lane centre +/- small jitter.

**Perfect.** Release inside the top `PerfectWindow` of the bar: +`PerfectLuckBonus` luck and the
PerfectThrow_Flash. This is the skill beat; it keeps mattering at every stage because it is luck,
not distance (in the reference game the timing meter becomes irrelevant after the first zones).

**Luck** (LuckService, pure in `Core/Luck`): product of
food.Luck, `1 + depth x DepthLuckBonus`, perfect, server luck step, `1 + friends x FriendBonusEach`
(max `FriendBonusMax`), VIP, Lucky Aura pass, `1 + zonesCompleted x IndexZoneBonus`,
`1 + rebirthTier x LuckBonus`, daily streak bonus, Festival Hour, and `LuckyThrowLuck` if armed.

**Roll** (`Core/Roll`, seeded RNG injected so specs are deterministic):
1. Hero: for each hero in the zone, `w = Rarity.Weight x (1 + (luck - 1) x Rarity.LuckScale)`;
   x `CravingWeightMult` if the hero craves the thrown food's flavour. Pick by weight.
2. Mutation: walk `Mutations` rarest first, chance = `Chance x (1 + (luck - 1) x LuckScale)`,
   capped at 1; first hit wins; none = no mutation. Festival Hour multiplies the chances.
3. Size: same walk over `Sizes` (no luck scaling).
4. `oneInN = 1 / (pHero x pMutation x pSize)` at the luck used. Shown on the reveal and on the
   server banner. This is the honest number, computed from the same weights that rolled.

**Grant** (SquadService, never blocks the next throw):
free slot -> place. Else if its income beats the weakest hero on the plot -> swap, the weakest
goes to the bench. Else -> bench. Bench full -> auto-sell the lowest-income bench hero (toast).
Settings `AutoSellCommon` / `AutoSellUncommon` sell those rarities on arrival unless NEW or
mutated. NEW (first time in index) and NEW BEST (highest income owned) are flagged in the result.

## 2. Income

`heroIncome = Zone.BaseIncome x Rarity.IncomeMult x Mutation.IncomeMult x Size.IncomeMult x StarIncomeMult^stars`

Premium heroes: `BestIncomeMult x (highest heroIncome among the player's non-premium heroes)`,
recomputed whenever that best changes, so a purchase never goes stale.

`playerIncome = sum(heroes on slots) x (2 if DoubleYen) x (1 + rebirthTier x IncomeBonus) x eventMult`

EconomyService adds `playerIncome x IncomeTickSeconds` each tick. Money is automatic; there is no
walk-to-collect. Coins pop from pedestals on the client purely as feedback.

Offline: on join, `min(secondsAway, CapHours x 3600) x playerIncome x Rate` if away longer than
`MinSecondsAway`. Claim, or double it with the OfflineDouble product.

Sell value = `heroIncome x SellSeconds`. Selling is a tidy-up, not an income source; fusion is the
real use for duplicates.

## 3. Training

Stand on the dojo pad, press Train: the server starts a session and counts one rep per
`RepSeconds` on its own clock until Stop, leaving the pad, or throwing. `Power += Equipment[tier].PowerPerRep`
(x2 with DoubleTraining). Client plays the gear's `StyleByTier` clip and Train_Hit per rep.
Ranks (`Training.Ranks`) are names for Power thresholds: the TrainingBar shows progress to the
next rank and PowerUp_Burst fires on each. Gear is bought at the pad (proximity prompt) in order.

## 4. Sinks and curves

| Sink | Rule |
|---|---|
| Food | `Foods[i].Cost`, bought once, any owned food can be equipped |
| Dojo gear | `Equipment[i].Cost`, in order |
| Plot slot n | `SlotBaseCost x SlotCostGrowth^(n - StartSlots - 1)`, up to `MaxSlots` (first one 1.5K: an early goal, unlike the reference's 40M wall) |
| Rebirth | `Rebirth.Tiers[t]`: needs Power and Yen |

## 5. Squad rules

Place / pick up: any time, between slots and bench. Equip Best: fills slots with the highest
income heroes. Fuse: three heroes with the same id, mutation and size -> one with +1 star (max
`MaxStars`), keeps the best slot. Index: a hero is discovered on first grant; variants
(mutation, size) are tracked for the long game. Completing a zone's eight heroes: claim
`IndexZoneYenMinutes` of income and a permanent `IndexZoneBonus` luck.

## 6. Rebirth

Needs `Tiers[next].PowerReq` and `YenCost`. Resets `Rebirth.Resets`, keeps `Rebirth.Keeps`.
Each tier: +`IncomeBonus` income and +`LuckBonus` luck, permanently. Ten tiers at launch, each
x5 Power and x7 Yen, so each loop is faster than the last but the gate keeps moving.

## 7. Server events

Festival Hour: every `FestivalHourEveryMinutes` for `FestivalHourMinutes`, mutation chances x
`FestivalMutationMult`, music swaps, sky effect. Server luck: each ServerLuck purchase raises the
step (1, 2, 4, 8) and adds `ServerStepMinutes`; when time runs out it drops to 1. Banner to the
whole server for `Rarities[r].Announce` catches. Admin commands (owner only): start Festival
Hour, set server luck, broadcast, grant lucky throws to everyone present.

## 8. Pacing targets (`config.Pacing`, checked by `python tools/balance_sim.py --check`)

| Milestone | Target | Simulated floor player |
|---|---|---|
| Festival Street | 1.5 to 4 min | 2 min |
| Ninja Village | 10 to 20 min | 14 min |
| Samurai Castle | 40 to 75 min | 51 min |
| Hero City | 2 h 10 to 3 h 40 | 2 h 44 |
| Spirit Realm | 6 h 20 to 9 h 20 | 7 h 18 |
| First rebirth | 11 h 40 to 16 h 40 | 15 h 11 |

The reference game's free players report finishing all content in five to six hours. Ours takes
about that long to reach the last launch zone, and rebirth then restarts the curve ten times.
Section 2 re-runs the sim against the real Core modules (the sim and the game must agree).

## 9. What we learned from the reference and did differently

| Reference (research/01) | Ours |
|---|---|
| One timing tap; meter stops mattering | Hold-to-charge picks the zone; perfect window gives luck forever |
| Food only picks the rarity centre | Food has power, luck and a flavour; heroes crave flavours |
| Duplicates are sold for 20 s of income | Fusion into stars |
| No rebirth; content ends in 5 to 6 h | Ten rebirth tiers |
| Luck is opaque | Real "1 in N", chances shown in the Index |
| Catch cutscene players reset to skip | Tap to skip, Fast Reveal setting, 0.8 s for commons |
| First slot upgrade 40M | First slot 1.5K, smooth x3.6 curve |
| Nothing to do with the other four players | Friend luck, shared server luck, banners, visitable plots |
