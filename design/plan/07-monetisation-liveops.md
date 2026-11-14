# 07 Monetisation, retention, live-ops and launch

Prices and keys: `config.Monetization`. Product and pass ids are 0 until minted in section 5.

## 1. What is sold, and why each one sells

| Key | R$ | What | Why a player wants it |
|---|---|---|---|
| DoubleYen (pass) | 99 | x2 income, forever | the reference's cheapest pass; first purchase for most |
| DoubleTraining (pass) | 149 | x2 Power per rep | zone gates are Power gates |
| Vip (pass) | 249 | +15% luck, +2 slots, VIP tag, gold name arch | status the other five players see |
| AutoThrow (pass) | 199 | re-throws automatically while on the pad | the reference's players script this themselves; sell it honestly |
| LuckyAura (pass) | 299 | x1.5 luck | the stat everyone asks about |
| BigBench (pass) | 79 | bench 30 -> 60 | fusion collectors |
| LuckyThrow x1/5/25 | 9/39/149 | banked throws at x25 luck | impulse, cheapest thing in the store |
| ServerLuck | 29 | next luck step (2x, 4x, 8x) for all six, +15 min | visible generosity; others chip in |
| YenPack 15m/2h/12h | 29/99/299 | that many minutes of YOUR income | never stale, no re-pricing |
| Train 5m/30m | 39/149 | that many minutes of reps | skip a gate |
| OfflineDouble | 39 | doubles the claim on screen | shown at the moment of desire |
| SummonScroll x1/3/10 | 79/199/599 | random premium hero, odds 40/27/18/10/4/1 | the chase; heroes earn a multiple of your best |
| StarterPack | 49 | Lucky Cat Mascot + 5 lucky throws + 30 min of 2x yen, once | first-session conversion |
| SakuraShogun | 399 | limited hero, 3x your best | fixed-price alternative to the scroll |
| Gift DoubleYen/Training | 99/149 | buy a pass for another player | friends |

Fair-play line (the reference is criticised for pay-to-win): no zone, food, gear or throw-caught
hero is locked behind Robux; premium heroes are stronger slots, not exclusive progress; leaderboard
"rarest catch" counts only thrown heroes.

## 2. Policy that must be built in (research/02 B)

- **Paid random items:** SummonOdds lists every outcome with its real percentage (sum 100)
  before any purchase button; the same table drives the roll. `PolicyService` is checked per
  player; where `ArePaidRandomItemsRestricted` is true the scrolls are hidden and the six heroes
  are offered at fixed prices. The experience questionnaire declares paid random items.
- **Luck boosts** state their effect before purchase ("x1.5 to every luck roll").
- Purchases are granted only in `ProcessReceipt`, idempotently, and acknowledged only after the
  profile holds the grant.
- No trading at launch, so `IsPaidItemTradingAllowed` is not in play.

## 3. Retention loop

| When | Hook |
|---|---|
| Session start | OfflineEarnings claim; streak day; Festival Hour clock visible |
| Every 3 to 60 min | PlaytimeGifts (six, the first at 3 min is a guaranteed Rare hero) |
| Every 30 min | Festival Hour (x2 mutation chance for 3 min) |
| Daily | 7-day streak: yen worth minutes of income, lucky throws on days 3, 5, 7 |
| Ongoing | zone index rewards, rebirth, leaderboards, friend luck |
| Weekly (live-ops) | one new zone (8 looks + a config row + 5 props), a code, a limited hero, an owner-run event hour |

## 4. Analytics (so tuning is evidence, not opinion)

Onboarding funnel steps 1 to 8 (tutorial beats). Economy events for every source and sink.
Custom: throw (zone, rarity, luck), reveal skipped, store opened, product viewed, purchase,
rebirth. Read weekly: step-to-step drop, D1/D7, minutes to zone 2 and 3, first-purchase product,
and whether real pacing matches `config.Pacing`.

## 5. Launch plan (section 6)

1. Private test with the owner and two alts or friends: the pre-handover matrix.
2. Publish; experience questionnaire (paid random items: yes); R15 only; 6 players; private
   servers off at launch.
3. Icon and three thumbnails captured in-engine (a Mythic reveal, a full Titan plot, the lane at
   sunset) with the title lettered in the UI fonts; preview video from the throw sequence.
4. Soft launch: a small sponsored-ad test on the three thumbnails to pick the best click-through
   before spending more (amount is the user's call).
5. Week 1: read the funnel, fix the worst step, ship zone 7 and a code.

## 6. Later, in order of value

Zones 7 to 10 (Pirate Harbour, Neon Mech City, Demon Castle, Celestial Arena), mutation index
rewards, seasonal mutation (Sakura), fusion to 5 stars, plot themes, trading (only with policy
checks), rewarded ads if eligible.
