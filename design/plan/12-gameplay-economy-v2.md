# 12 Gameplay and economy v2: the 17-zone game (approved 2026-11-26; build log in section 15)

Owner's request: put the updated roster into the real game, design the odds ("1 in N"), rebirth,
money, training and passes so they link into one fair loop that lasts, add a way to throw less far
on purpose, and cover anything missed. Research first, then this plan. **Nothing in this file is in
the game yet.** The numbers are in `design/plan/12-economy-draft.json`, generated and tested by
`tools/economy/econ_v2.py` (`gen`, `sim`, `odds`). `design/game.json` is untouched.

## 0. The plan on one screen

| Topic | Today | v2 |
|---|---|---|
| Zones in play | 6 (old names), zones 7-17 are scenery | all 17 anime zones |
| Heroes in play | 51 lane + 8 premium | 172 lane + 8 premium (the updated list) |
| Starter pack hero | Power | Goku. Power joins the Chainsaw Man zone as a Legendary |
| Rarity roll | weights; luck stops helping after about x10 | "1 in N" per rarity, divided by your luck |
| Biggest numbers | "1 in 10 billion" possible but by accident | designed: Secret 1 in 1,000,000; Mythic Galaxy Titan 1 in 3.3 billion |
| Rebirth | 10 tiers, first after about 15 hours, wipes heroes, gear, food | first at about 35 minutes; each rebirth opens the next two zones; resets Power and Yen only |
| Time to reach the last zone, free | about 8 hours (6 zones) | about 30 hours (17 zones); all passes about 16 hours |
| Throwing short on purpose | only by mistiming the meter | an Aim control with a "Lands in" readout |
| Passes | 6 passes, luck stacks without limit | same 6, each with a stated bound; total luck capped |

## 1. What the research says (and what I took from it)

Full reports are summarised here; sources are the URLs in brackets. "Single" = one source only.

**The reference game (Throw Food For Animals), state on 2026-11-26**
- Still **no rebirth**, quests, daily rewards or auto-throw; it lasts by adding a zone every week
  (20 zones now, lane 13,200 studs) and 5-minute events every 30 minutes. We cannot add a zone a
  week, so our length has to come from the loop itself. [rolimons.com/game/120219252362013, game.guide]
- **It has a power slider**: MIN to MAX with a live "Lands in: OCEAN" readout. This is what you saw.
  [nerdschalk.com/dreamland-event-throw-food-for-animals, showgamer.com] (two sources)
- Its luck score is 1 / (mutation chance x size chance), and older builds showed the square of it
  (961 = 31 squared). Largest published example "INSANE LUCK 1 in 48,400". Labels LUCKY, SUPER
  LUCKY, INSANE LUCK; thresholds not published. [bloxodes.com, allthings.how] (single each)
- Average session 17.3 minutes. Free players report finishing the old 17 zones in 5 to 6 hours.
- Monetisation is not called pay-to-win: "Robux only buys convenience and luck". x2 Training is
  rated the best early buy. [throwfoodforanimalswiki.com, timesaver.gg]

**The genre**
- Steal a Brainrot: first rebirth needs $500K plus two named brainrots, which is inside the first
  session; each rebirth gives about +1x cash and a slot; it wipes cash and brainrots.
  Plants vs Brainrots: +50% money and +50% luck per early rebirth and **keeps plants and gear**.
  [beebom.com/steal-a-brainrot-rebirth-guide-levels-and-rewards, sportskeeda.com]
- Mutations elsewhere: Gold x1.25 at 10%, Diamond x1.5 at 5%, Rainbow x10 at 1% (Steal a Brainrot);
  Gold x20 at 1%, Rainbow x50 at 0.1% (Grow a Garden). Ours sit inside that range.
- Sol's RNG shows "1 in 3,000,000,000" for its top aura; expected rolls = N / luck. That is the
  model v2 uses. [sol-s-rng.pages.dev/guides/luck-formula]
- Passes: x2 is the standard size; 1.5x appears only as VIP. Prices in hits run 99 to 400 R$ for
  the core passes. [buffget.com, u7buy.com] (single each)
- Benchmarks for big Roblox games: median session 6.6 min (75th percentile 14.5); day-1 retention
  10 to 13%, day-7 1.2 to 2.9%. Roblox's own advice: fun inside 5 minutes.
  [gameanalytics.com/reports/2025-roblox-report, create.roblox.com/docs/production/analytics/retention]
- Idle-game maths (Pecorella, "The Math of Idle Games"): costs must outgrow income; reset when a
  prestige gives +50% to +200%. [gamedeveloper.com/design/the-math-of-idle-games-part-i]

**Roblox policy that binds us**
- Anything random bought with Robux needs every outcome's odds as a percentage before purchase.
  **Paid luck boosts are covered: their effect must be a number and the odds must update live
  while the boost is active.** [create.roblox.com/docs/production/monetization/paid-random-items]
- `PolicyService` flag `ArePaidRandomItemsRestricted` (UK under-18 since 2024; Brazil under-18
  from March 2026, single source): the item must be hidden or sold directly for those players.
- Regional ("managed") pricing: prices shown must come from `MarketplaceService`, not hard-coded.
  [create.roblox.com/docs/production/monetization/managed-pricing]

## 2. The roster in the game

Source of truth: `design/characters/HERO_LIST_BY_RARITY.md` (180 heroes) with two moves:
- **Goku** (`instinct_warrior`) leaves the Dragon Ball zone and becomes the **Starter Pack** hero
  (earns 1.5x your best lane hero, like Power did).
- **Power** (`lucky_cat_mascot`) leaves the store and joins **zone 10, Chainsaw Man, as a
  Legendary** (the zone had one Legendary; she has a full custom aura). See decision 2.

| # | Zone (anime) | Opens at | C | U | R | E | L | M | S | Lane heroes |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Hidden Leaf Village (Naruto) | start | 2 | 2 | 3 | 3 | 2 | 1 | | 13 |
| 2 | Demon Slayer Corps | start | 2 | 2 | 2 | 3 | 2 | 1 | | 12 |
| 3 | Grand Line (One Piece) | start | 2 | 2 | 3 | 4 | 3 | 1 | | 15 |
| 4 | Hero Academy (My Hero Academia) | Rebirth 1 | 2 | 1 | 2 | 2 | 2 | 1 | | 10 |
| 5 | Blue Lock Facility | Rebirth 1 | 2 | 2 | 2 | 2 | 2 | | | 10 |
| 6 | Clover Kingdom (Black Clover) | Rebirth 2 | 1 | 2 | 2 | 2 | 2 | 1 | | 10 |
| 7 | Hunter Exam (Hunter x Hunter) | Rebirth 2 | 2 | 1 | 1 | 2 | 2 | 1 | | 9 |
| 8 | Isekai Crossroads | Rebirth 3 | 2 | 1 | 2 | 2 | 2 | | | 9 |
| 9 | Wall Maria (Attack on Titan) | Rebirth 3 | 1 | 1 | 2 | 2 | 2 | | | 8 |
| 10 | Public Safety HQ (Chainsaw Man) | Rebirth 4 | 1 | 1 | 1 | 1 | 2 | | | 6 |
| 11 | Bizarre Streets (JoJo) | Rebirth 4 | 1 | 2 | 1 | 3 | 2 | | | 9 |
| 12 | Shadow Council (Masterminds) | Rebirth 5 | 1 | 1 | 1 | 3 | 2 | 1 | | 9 |
| 13 | City Z (One Punch Man) | Rebirth 5 | 1 | 2 | 1 | 1 | 2 | 1 | 1 | 9 |
| 14 | Soul Society (Bleach) | Rebirth 6 | 1 | 2 | 2 | 3 | 2 | 1 | | 11 |
| 15 | Gate of Shadows (Solo Leveling) | Rebirth 6 | 1 | 1 | 1 | 1 | 2 | 1 | | 7 |
| 16 | Shibuya (Jujutsu Kaisen) | Rebirth 7 | 1 | 2 | 3 | 2 | 3 | 2 | | 13 |
| 17 | Planet of the Gods (Dragon Ball) | Rebirth 7 | 1 | 1 | 1 | 3 | 3 | 2 | 1 | 12 |

Premium (store, never thrown): the six summon heroes (Marin 40%, Lawliet 27%, Kaneki 18%, Makima
10%, Frieren 4%, Aizen 1%), Goku (starter pack), Yoriichi (limited, 399 R$).
`config.Characters` is generated from the roster by a new `tools/gen_characters.py` (id, name,
zone, rarity, craved flavour, idle clip), so the list and the game cannot drift apart.

## 3. The odds system

### 3.1 The rarity roll (replaces the weight table)

Each rarity has a base chance per throw. Your luck divides the "1 in N". The roll checks the
rarest first; what is left goes to Uncommon and Common.

| Rarity | Base odds (luck 1) | Earns (x the zone's Common) | At luck 3 | At luck 8 | At luck 20 (free endgame) |
|---|---|---|---|---|---|
| Common | about 1 in 1.8 | x1 | 1 in 2.1 | 1 in 3.6 | 1 in 15 |
| Uncommon | about 1 in 3.3 | x2.5 | 1 in 4 | 1 in 6.6 | 1 in 29 |
| Rare | 1 in 9 | x7 | 1 in 4.7 | 1 in 2.6 | 1 in 2.2 |
| Epic | 1 in 50 | x25 | 1 in 17 | 1 in 6 | 1 in 2.5 |
| Legendary | 1 in 400 | x120 | 1 in 133 | 1 in 50 | 1 in 20 |
| Mythic | 1 in 10,000 | x900 | 1 in 3,333 | 1 in 1,250 | 1 in 500 |
| Secret (Saitama, Whis) | 1 in 1,000,000 | x10,000 | 1 in 333,333 | 1 in 125,000 | 1 in 50,000 |

Rules: Epic and above scale fully with luck; Rare scales slower (luck to the power 0.6) and always
leaves 10% of the roll to Uncommon and Common, so a Common stays catchable for the Index.
Heroes of one rarity in a zone share that rarity's chance (two Legendaries: 1 in 800 each); a hero
that craves the thrown food's flavour counts three times inside its rarity (unchanged rule).
A zone without a Mythic simply has no Mythic band.

Why this replaces today's weights: with the current table every rarity above Common scales by the
same factor, so past about luck 10 the Mythic chance is stuck at 1 in 611 however much luck a
player buys. In v2 luck never stops mattering until the cap.

### 3.2 Luck, and how it stacks (the fair-stacking rule)

```
Luck = Food x Depth x Perfect x (1 + free bonuses) x VIP x Lucky Aura x Server Luck x Lucky Throw
       capped at 1,000
```

| Source | Value | Stacks how |
|---|---|---|
| Food | x1.0 (Onigiri) to x5.5 (Dragon Feast) | multiplies |
| Depth in the zone | up to x1.25 | multiplies (skill: more Power = deeper) |
| Perfect throw | x1.1 | multiplies (skill; Auto Throw never gets it) |
| Rebirth | +10% per rebirth (max +100%) | **added together** in one group |
| Index | +2% per completed zone (max +34%) | same group |
| Friends in the server | +10% each (max +30%) | same group |
| Daily streak | up to +10% | same group |
| Dry streak (new, bad-luck protection) | +1% per throw without an Epic or better, max +50% | same group |
| VIP pass | x1.15 | multiplies |
| Lucky Aura pass | x1.5 | multiplies |
| Server Luck (paid, whole server, 15 min) | x2, x4, x8 | multiplies |
| Lucky Throw (paid or earned) | x12, and never below Epic | multiplies |

Typical totals: new player 1.0 to 1.5; mid game (rebirth 3) about 4 to 5; free endgame about 21;
all passes about 36; a Lucky Throw under x8 Server Luck hits the cap of 1,000 (Mythic 1 in 10,
Secret 1 in 1,000). Today the same stack reaches about 4,000 with no cap.

### 3.3 Mutations and sizes (one roll each, unchanged values)

| Mutation | Base chance | Earns | | Size | Chance | Earns |
|---|---|---|---|---|---|---|
| Golden | 6% (1 in 17) | x2 | | Big | 8% (1 in 12.5) | x1.5 |
| Flame | 2% (1 in 50) | x4 | | Huge | 2% (1 in 50) | x3 |
| Lightning | 0.6% (1 in 167) | x8 | | Titan | 0.3% (1 in 333) | x6 |
| Galaxy | 0.1% (1 in 1,000) | x20 | | | | |

Mutation chance grows with a quarter of your extra luck (luck 21 = x6); Festival Hour doubles it.
Sizes do not move with luck. Three copies of a hero fuse into a star (x1.5 each, up to 3 stars).

### 3.4 The "1 in N" score: yes, we get the big numbers

Score = rarity odds x mutation odds x size odds, **at base odds (luck 1)**; no mutation or no size
counts as 1, so a plain Mythic is exactly "1 in 10,000" and a plain Secret "1 in 1,000,000". Today
the game uses the chances at the player's own luck (and the hero's share of its zone), so a
beginner gets a bigger number than a veteran for the same catch and the "Rarest catch" leaderboard
rewards low luck. Base odds fix both: the same catch shows the same number for everyone.

| Catch | Score |
|---|---|
| Epic, Golden | 1 in 833 |
| Legendary, Golden | 1 in 6,667 |
| Epic, Flame, Big | 1 in 31,250 |
| Mythic, Golden | 1 in 166,667 |
| Legendary, Flame, Big | 1 in 250,000 |
| Epic, Lightning, Huge | 1 in 416,667 |
| **Legendary, Lightning, Big** | **1 in 833,333** |
| Legendary, Flame, Huge | 1 in 1,000,000 |
| Secret (plain) | 1 in 1,000,000 |
| Mythic, Galaxy | 1 in 10 million |
| Mythic, Galaxy, Titan | 1 in 3.3 billion |
| Secret, Galaxy, Titan | 1 in 333 billion |

A number like the "1 in 638,743" you saw is a Legendary or an Epic with a mutation and a size.
How often, computed from the tables at about 280 throws an hour: a score of 500,000 or more comes
about every 57 hours of play at luck 3, every 13 hours at luck 8 and every 3 hours at free endgame
luck (20); a score of 100,000 or more about every 10 hours, 2.5 hours and 35 minutes. Stamps on the catch card: LUCKY (1 in 100+),
SUPER LUCKY (1 in 10,000+), INSANE LUCK (1 in 1 million+), GODLY (1 in 100 million+). Server banner
from 1 in 100,000; all-servers announcement for a Secret or 1 in 100 million+.

### 3.5 Odds on screen (required by Roblox, and fair)

A **Details** button on the throw panel opens the live table: every rarity's percentage and
"1 in N" at your current luck for the zone you aim at, the mutation and size tables, and the luck
breakdown line by line (the breakdown already exists in `Core/Luck`). Lucky Throws and Server Luck
are sold with their number ("x12 luck, never below Epic") and the table updates while they are on.

## 4. Progression: Power, zones, gear, food, slots

**Stamina:** the game has no stamina or energy stat and I do not plan one: an energy bar that stops
play shortens sessions. I read "stamina" as **Power** (the strength you train). See decision 4.

One ladder, every step x8 income and about x12 Power (so a rare catch stays useful for 2 to 3
zones: a Legendary of zone N earns about what an Epic of N+1 does, a Mythic lasts to N+3).

| # | Zone | Gate Power | Common earns /s | Gear sold here (Power per rep, price) | Target minutes in zone |
|---|---|---|---|---|---|
| 1 | Hidden Leaf Village | 0 | 1 | Wooden Dummy: 2, free | 3 |
| 2 | Demon Slayer Corps | 200 | 8 | Sandbag: 6, 47K | 9 |
| 3 | Grand Line | 2.5K | 60 | Iron Dummy: 31, 990K | 18 |
| 4 | Hero Academy | 30K | 480 | Stone Pillar: 150, 38M | 30 |
| 5 | Blue Lock Facility | 350K | 4K | Waterfall: 900, 790M | 50 |
| 6 | Clover Kingdom | 4M | 32K | Gravity Dojo: 6.9K, 16B | 60 |
| 7 | Hunter Exam | 50M | 250K | Dragon Shrine: 66K, 210B | 75 |
| 8 | Isekai Crossroads | 600M | 2M | Star Forge: 470K, 2.7T | 90 |
| 9 | Wall Maria | 7B | 16M | Thunder Peak: 4.6M, 31T | 105 |
| 10 | Public Safety HQ | 80B | 130M | Spirit Chamber: 39M, 410T | 120 |
| 11 | Bizarre Streets | 1T | 1B | Titan Chains: 420M, 3.6Qa | 135 |
| 12 | Shadow Council | 12T | 8B | Void Anvil: 3.6B, 63Qa | 150 |
| 13 | City Z | 150T | 65B | Phoenix Kiln: 39B, 850Qa | 165 |
| 14 | Soul Society | 1.8Qa | 500B | Moon Temple: 350B, 7.4Qi | 180 |
| 15 | Gate of Shadows | 22Qa | 4T | Sun Crucible: 3.7T, 84Qi | 200 |
| 16 | Shibuya | 260Qa | 32T | Celestial Gate: 28T, 1Sx | 220 |
| 17 | Planet of the Gods | 3Qi | 250T | God's Arena: 310T, 36Sx | 240 |
| | after rebirth 8 / 9 | | | Endless Dojo: 760T, 150Sx / Hall of Gods: 6.5Qa, 300Sx | endgame |

How the pieces link (this is the "everything coordinates" rule):
- **Training is the clock.** Each zone's gear is sized so that training from this gate to the next
  takes 45% of the zone's target minutes. One rep per second; a perfect tap gives +50%.
- **Yen is the second gate, never a way round the first.** Gear, food and plot slots **unlock when
  you first reach their zone**, so Yen (or a Yen pack) cannot buy tomorrow's gear today. Prices are
  fixed fractions of what a free player earns in that zone's target minutes, measured by the
  simulator: gear 12%, food 22%, the zone's plot slot 30%, the rebirth fee 22%.
- **Food** (12, the existing models, re-priced over 17 zones): Dango 180, Sushi 85K, Spicy Bun
  1.8M, Gyoza 70M, Ice Cream 1.4B, Takoyaki 29B, Ramen 4.9T (zone 8), Curry 760T (zone 10),
  Tempura 120Qa (zone 12), Festival Cake 14Qi (zone 14), Dragon Feast 1.9Sx (zone 16).
  Power x1.0 to x5.0 and luck x1.0 to x5.5 as today.
- **Plot slots:** 8 to 24, one new slot per zone from zone 2 (120K, 2.5M, 96M, 2B, 39B ... 89Sx),
  **kept through a rebirth**. VIP adds 2.

## 5. Rebirth: when, what it costs, what it gives

**When:** at the end of each band of zones, when your throw can reach the sealed gate and you hold
the fee. The first band is the three biggest anime; every rebirth opens the next two.

| Rebirth | Needs (Power to reach the gate, Yen fee) | Opens | Free player gets there at about |
|---|---|---|---|
| 1 | 30K, 1.8M | Hero Academy, Blue Lock | 35 min |
| 2 | 4M, 1.4B | Clover Kingdom, Hunter Exam | 2 h |
| 3 | 600M, 390B | Isekai Crossroads, Wall Maria | 4 h 45 |
| 4 | 80B, 57T | Public Safety HQ, Bizarre Streets | 8 h |
| 5 | 12T, 6.5Qa | Shadow Council, City Z | 13 h |
| 6 | 1.8Qa, 1.6Qi | Soul Society, Gate of Shadows | 19 h |
| 7 | 260Qa, 150Qi | Shibuya, Planet of the Gods | 26 h |
| 8, 9, 10 | 36Qi / 430Qi / 5Sx, fees 300 / 590 / 890Sx | endgame ranks and two endgame gear tiers (future zones can hang here) | 42 h, 60 h, 82 h |

**Each rebirth gives, forever:** +50% Yen income, +25% training speed, +10% luck, three Lucky
Throws, a rank on the nameplate, and the next two zones.

**It resets Power and Yen only.** Heroes, plot slots, gear, foods, the Index, passes and Lucky
Throws are kept (see decision 1). To make the way back short, **muscle memory**: training is x4
while your Power is below your own record. In the simulation the re-climb takes 2 minutes after
rebirth 1 and 27 minutes after rebirth 7, and on the way the player throws into early zones
again with far better luck, which is how the early Index gets finished.

Why not wipe the heroes (today's code does): the heroes with auras on the base are what the other
four players see, and a wipe every few hours removes exactly the catch a player is proudest of.
I first drafted "heroes sleep until you reach their zone again"; the simulation showed the re-climb
then hangs on Yen because players sell their early-zone heroes, so the simpler rule won.

## 6. Money

```
hero income   = zone's Common income x rarity x mutation x size x 1.5^stars
premium hero  = its multiple (1.1x to 12x) x your best lane hero
plot income   = sum of heroes on slots x (1 + 0.5 x rebirths) x 2 if Double Yen x event
```

- Selling pays 30 seconds of the hero's income (cleanup, not a strategy), as today.
- Offline: 50% of income for up to 8 hours away, as today. A daily player reaches the last zone
  about 10% sooner than one who never claims; training cannot be done offline, so offline never
  skips the clock.
- Index: finishing a zone pays 30 minutes of income once and +2% luck forever.
- Biggest possible single hero: a 3-star Secret Galaxy Titan in zone 17 earns about 1Sx per second.
  `Core/Format` already names numbers up to Dc; leaderboards already store log values.

## 7. What the simulation says (pacing)

`python tools/economy/econ_v2.py sim --profile <name>`: a simple player who throws every 7 s,
trains half the time, buys the cheapest useful thing. Median of 5 runs. It is a model, not a
playtest: real numbers come from telemetry after launch (section 11).

| Milestone | Free | Free, claims offline daily | x2 Yen | x2 Training | All passes |
|---|---|---|---|---|---|
| Zone 2 | 3 min | 3 min | 3 min | 2 min | 2 min |
| First Epic | 4 min | 4 min | 4 min | 4 min | 2 min |
| Zone 3 | 13 min | 13 min | 13 min | 9 min | 8 min |
| First Legendary | 33 min | 33 min | 43 min | 25 min | 12 min |
| Rebirth 1 (zones 4-5) | 34 min | 34 min | 29 min | 24 min | 17 min |
| Rebirth 2 | 2 h 04 | 2 h 04 | 1 h 52 | 1 h 25 | 1 h 04 |
| Rebirth 4 | 8 h 11 | 7 h 35 | 7 h 29 | 5 h 37 | 4 h 12 |
| Rebirth 7 (last two zones) | 26 h | 23 h 50 | 23 h 45 | 17 h 45 | 13 h 30 |
| Zone 17 reached | 30 h 40 | 27 h 35 | 27 h 50 | 20 h 30 | 15 h 50 |
| Rebirth 8 | 42 h | 32 h | 35 h | 29 h | 21 h |
| Rebirth 10 (the last rank) | 82 h | not run | not run | not run | 41 h |
| First Mythic (median) | 16 h | 14 h | 13 h | 11 h | 9 h |

First Epic, Legendary and Mythic are luck, so those rows swing from run to run (the x2 Yen column
happened to draw its first Legendary late).

- Play styles: a player who trains only 30% of the time reaches zone 17 in about 44 hours, one who
  trains 80% in about 27 hours. The spread is narrow because Yen binds when training does not.
- **The most a player can buy is about 2x speed** with every pass, plus packs. Nothing is locked.
- Collection is the long game: a specific Mythic at free endgame luck is about 1 in 500 throws
  (about 2 hours of throwing); all 14 Mythics about 30 to 35 hours on top of the lane; each Secret
  about 1 in 50,000 throws (about 180 hours free, or Lucky Throws). Stars, mutations and sizes have
  no end.
- First five minutes: zone 2 at 3 min, first Epic at about 4 min, the tutorial hands out one free
  Lucky Throw (guaranteed Epic or better), the 3-minute gift is a guaranteed Rare.

## 8. Passes and products: what each one does, and its bound

Prices and product ids stay as minted. Rule: **one pass doubles one thing; passes on different
things multiply; nothing a pass gives is locked for free players.**

| Pass | R$ | Effect | Bound, from the simulation |
|---|---|---|---|
| Double Yen | 99 | x2 plot income, multiplies with rebirth | last zone about 9% sooner (Yen is the second gate) |
| Double Training | 149 | x2 Power per rep, multiplies with rebirth and muscle memory | about a third sooner: the strongest pass, priced higher |
| VIP | 249 | x1.15 luck, +2 plot slots, tag and gold arch | luck and status |
| Lucky Aura | 299 | x1.5 luck | Mythic 1 in 500 becomes 1 in 333 at endgame |
| Auto Throw | 199 | re-throws while you stand on the spot; never a Perfect; Roblox still disconnects after 20 idle minutes | convenience only |
| Big Bench | 79 | bench 30 to 60 | collectors |

| Product | R$ | Effect | Rule |
|---|---|---|---|
| Lucky Throw x1 / 5 / 25 | 9 / 39 / 149 | x12 luck, never below Epic | odds table shown before buying |
| Server Luck | 29 per step | x2, x4, x8 for everyone, 15 min | number shown, table live |
| Yen pack 15 min / 2 h / 12 h | 29 / 99 / 299 | that much of YOUR income | cannot unlock gear early (zone locks) |
| Training 5 min / 30 min | 39 / 149 | that many minutes of reps at your gear | no muscle-memory bonus on packs |
| Offline x2 | 39 | doubles the claim on screen | |
| Summon scroll x1 / 3 / 10 | 79 / 199 / 599 | premium hero, odds 40/27/18/10/4/1 | hidden where paid random items are restricted; heroes then sold directly |
| Starter Pack | 49 | **Goku** + 5 Lucky Throws + 30 min of x2 Yen, once | |
| Yoriichi (limited) | 399 | earns 3x your best lane hero | |

Whale ceiling: every premium hero at three stars is about 100x the best lane hero, which is a
little over two zones of income (zones are x8 apart), and training still has to be done. Fair-play
line unchanged: no zone, food, gear or thrown hero is behind Robux, and "Rarest catch" counts only
thrown heroes.

To check when building (single-source in my research): whether paid Lucky Throws and Server Luck
must also be hidden for `ArePaidRandomItemsRestricted` players; the store must show live prices
from `MarketplaceService` for regional pricing.

## 9. Throwing short on purpose: the Aim control

On the throw panel, an **Aim** stepper (two arrows, or drag) with the readout
**"Lands in: Hidden Leaf Village"**. It lists every zone your Power can reach, and remembers your
choice. The timing meter then decides how deep in that zone the food lands (deeper = up to +25%
luck, top of the bar = Perfect). In your furthest zone the bar only reaches as deep as your Power
does. The server checks the aim against your Power, so it cannot be used to reach further.

Why players use it: to finish the Index of an old zone, to hunt one hero (aim at its zone and throw
the flavour it craves), and right after a rebirth. The reference game's version is a MIN-MAX
slider; ours steps by zone because our gates are x12 apart and a plain slider would squeeze sixteen
zones into its first millimetre.

## 10. UI work (mostly the screens you already approved, extended)

| Screen | Change |
|---|---|
| Throw panel | Aim stepper + "Lands in", Details (live odds), simpler meter (depth bands instead of 17 zone marks) |
| Catch card | base-odds score, the four stamps |
| Hero Index | 17 zone tabs (the page already clones tabs), sealed zones show silhouettes and "Rebirth N", per-zone reward state |
| Rebirth page | the new rule in three lines (resets / keeps / gives), the gate and fee, the two zones it opens |
| Food shop, gear panel | 17 gear tiers; "Unlocks at <zone>" on locked rows |
| Store | Goku on the Starter Pack card (new card art), pass texts with their numbers |
| Zone gates in the world | zone names instead of COMING SOON; sealed gates wear the finale's chains and seal with "REBIRTH N" |
| Squad, nameplates | rebirth rank; no layout change |
| New art needed | 11 zone pictures for the Index tabs, Goku's card, ambience for 11 zones (reuse where it fits) |

Every UI change is judged in the game, on a phone layout too, before it counts as done.

## 11. Things you did not list that matter

1. **Saved data.** Hero zones change (Yuji moves from zone 1 to 16), so old test profiles would be
   wrong. The game is private and only testers have data: start a fresh store (`Profiles_v2`).
2. **Bad-luck protection** (the dry streak in 3.2) so nobody sits 300 throws without an Epic.
3. **Auto-sell** for Common and Uncommon exists; add Rare, because at 280 throws an hour the bench
   fills constantly.
4. **Telemetry** for tuning after launch: time to each zone and rebirth, where players quit, luck
   at each catch, what is bought when. Every number in section 4 is one line in the config.
5. **Policy:** live odds table (3.5), restricted-region handling, live prices.
6. **Hero auras in the real game.** The auras you approved live only on the preview yard. Wiring
   them into play (with the phone budget: nearest heroes only) is its own phase below.
7. **Later, not now:** daily quests ("catch 20 heroes"), a weekly event hour, trading (heavy policy
   work). The loop does not depend on them.
8. **Launch reach (single source, to verify):** reaching under-13 and "Select" accounts in 2026
   needs creator age check, 2FA and a publishing step. Worth checking before the public launch.

## 12. Build order after you approve (one phase per session, gates green before Studio)

| Phase | What | Done when |
|---|---|---|
| A. Rules and numbers | config v2 into `design/game.json` from the generator; `Core/Roll`, `Throw`, `Luck`, `Progress`, `Income`, `Schema`; specs; the v2 simulator replaces `balance_sim.py` in `tools/gate.py` | all gates green, pacing check inside its windows |
| B. Roster and server | `gen_characters.py` (172 heroes, the two moves); ThrowService (aim, sealed zones, dry streak, Lucky floor, base score); rebirth; zone locks in ShopService; `Profiles_v2` | a fresh test account plays zone 1 to rebirth 2 with test commands |
| C. Screens | section 10 | every screen looked at in the game, desktop and phone |
| D. World | gate plaques, sealed gates, ambience, Index pictures | a throw into each of the 17 zones lands, reveals and streams |
| E. Auras in play | approved auras into the runtime, budget pass | 5 full bases on a phone profile hold frame rate |
| F. Full playtest and tuning | speed-run with test commands through all rebirths; fix; then snapshot (commit, tag, save) | your sign-off |

## 13. Decisions I need from you

1. **Rebirth keeps heroes, gear and food; resets Power and Yen** (recommended, section 5).
   The alternative is the classic wipe that today's code does.
2. **Power's rarity in the Chainsaw Man zone: Legendary** (recommended) or Epic.
3. **Length: about 30 hours of free play to reach the last zone, about 16 with every pass**
   (recommended). I can stretch or shorten it with one table (`ZONE_MINUTES`).
4. **No stamina / energy stat.** I read "stamina" as Power. Say so if you meant a real stamina bar.
5. **Phase E (auras into the real game) is part of this work**, after the gameplay phases.

## 14. What is not proven

- The pacing table is a simulation of a simple player. It has not been played. Real players
  dawdle, quit and binge; expect to move numbers after the first week of telemetry.
- Research gaps: no source gives the reference game's hours per zone, Steal a Brainrot's spawn
  odds, or measured time to first rebirth anywhere. Several policy details are single-source.
- The simulator does not model Lucky Throws, Server Luck, friends, events or the Index bonus, so
  real players are somewhat luckier than the table.

## 15. Build log

**2026-11-26: the owner approved all five decisions.** The build runs in a separate git worktree
(`D:\Roblox Studio Games\_worktrees\tfa-econ-v2`, branch `economy-v2`, nothing committed) so the
shared Studio and the other sessions' play tests are not broken half-way. It lands in the main
checkout in one step once phases A to C pass their gates.

**Phase A done (in the worktree).**
- `design/characters/lineup.json` (172 lane heroes with zone and rarity, 8 premium) is now the
  truth for gameplay; `tools/gen_characters.py` writes `config.Characters` / `PremiumCharacters`
  from it (`--check` is a gate). Goku is the Starter Pack hero, Power a zone-10 Legendary.
- `tools/economy/econ_v2.py apply` wrote the 17 zones, the rarity odds, 19 gear tiers (17 + two
  endgame), the re-priced foods, the 16 slot prices, the 10 rebirths and the pacing windows into
  `design/game.json`; `GameConfig.luau` regenerated.
- Rules rewritten: `Core/Roll` (rarest-first bands, lucky floor, base-odds score, stamps),
  `Core/Throw` (sealed zones, aim, depth by the meter), `Core/Luck` (the added group, the cap, the
  dry streak), `Core/Progress` (unlocks by furthest zone, muscle memory, slot table, rebirth resets
  Power and Yen only), `Core/Schema` (profile v2: `powerRecord`, `bestZone`, `dry`, `aim`).
- Specs: 117 pass (new `Luck.spec`, `Progress.spec`; `Roll.spec` rewritten).
- `tools/gate.py`: the pacing gate is now `econ_v2.py check` on the live config, plus the lineup
  check. All gates green. `tools/balance_sim.py` is retired to `tools/retired/`.
- Not yet true: the services and the client still call the old rules (changed signatures:
  `Roll.throw` takes `maps`; `Progress.applyRebirth(cfg, profile)`; `Throw.chargeForZone` is gone;
  `Progress.nextSlotCost(cfg, slots, bonusSlots)`). The worktree's game does not run until phase B
  and C are done. That is why it has not landed.

**To do at landing:** copy the worktree's changed files into the main checkout (do NOT copy
`design/auras.json` or `Auras.luau`: rerun `python tools/gen_auras.py` there instead, as Character
VFX 4 asked), tell the other sessions first, then gates, then the Studio playtest.

**Phase B done (in the worktree; gates green, NOT yet run in Studio).**
- ThrowService: the request carries an aim (5th argument, remembered in `profile.aim`); landing by
  `Throw.landing` (sealed zones, depth by the meter); dry streak counted; a Lucky Throw has the
  Epic floor; the result carries `stamp`, `depth` and `sealed` (Power would pass the sealed gate).
- ShopService: gear, food and slots refuse with "unlocks when you reach <zone>" / "at Rebirth N".
- TrainingService: `AddPower(player, amount, memory)`: reps and perfect taps get muscle memory,
  paid packs and test grants do not; the rebirth training bonus applies; reaching a new zone by
  Power marks the snapshot dirty. ProgressService: rebirth by `Progress.applyRebirth(cfg, profile)`.
- EventService: banner threshold from `config.Roll`; a Secret or a 1 in 100M+ catch is published
  to every server (MessagingService, best effort). Legendary no longer banners by rarity alone.
- Auto-sell Rare (setting `autoSellRare`); `LB_Rarest_v2` (the score changed meaning);
  stores `Profiles_v2` / `Profiles_Dev_v2`; test commands `zone <n>` and `rebirthnow`.
- New spec `Journey.spec` plays throw, unlock, rebirth and the climb back through the pure rules
  the way the services call them. 122 specs pass.
- Still to do before it can run: the CLIENT (phase C). Known callers of removed or changed rules:
  ThrowController (`Throw.chargeForZone`, the meter's zone marks, must send the aim),
  HeroIndex (`Throw.chargeForZone`, `Roll.heroWeights`), HudController (luck lines now have
  `add`), MenuController and Rebirth page (`Progress.canRebirth` takes the food's PowerMult),
  UpgradeController / WorldUiController / TrainingBar (`nextSlotCost(cfg, slots, bonusSlots)`,
  lock states, 19 gear tiers), Store and Celebrate (starter hero is `instinct_warrior`).

**Phase C part 1 done, and A + B + C1 LANDED in the main checkout (2026-11-26).** The worktree and its
branch are removed. `tools/gen_auras.py` rerun in main (155 heroes with an aura). All gates green in main.
- Client on the new rules with the screens it already had: ThrowController (aim by Q / E, the bumpers, or a
  tap on either half of the "Lands in" line; the meter is a depth meter showing the luck it is worth; the aim
  goes with the throw), HeroIndex (locks by reach and seal), MenuController ("REBIRTH READY" names the zone it
  opens; "SEALED GATE" when the throw reaches the seal but the fee is short), Rebirth page (throw power against
  the gate, the four rewards, keep / lose lists written at runtime), UpgradeController / WorldUiController /
  FoodShop / TrainingBar (lock states, slot table, muscle memory shown), DevPanel ("Reach a zone",
  "Ready + rebirth").
- **Play test in Studio (fresh profile on `Profiles_Dev_v2`), all through the real remotes:** first throw
  (guaranteed Uncommon, base score 3); shop refuses zone-2 gear in zone 1 with the right toast; jump to zone 3
  lands in zone 3; aim 1 lands in zone 1 at full depth; Power past zone 4's gate lands in zone 3 with
  `sealed = true`; gear and a slot bought once unlocked; rebirth 1 (Power back to 10, heroes and gear kept,
  +3 Lucky Throws); zone 5 reached after it; a Lucky Throw gave an Epic Golden, score 1 in 833, stamp LUCKY,
  luck 26. No errors in the console from the game's code. Screens looked at: throw panel, Rebirth, Hero Index.
- Not done yet (phase C part 2, needs art and in-game layout): a proper Aim stepper, the live odds (Details)
  panel, the four stamps on the catch card, pictures for 11 zone tabs, Rebirth page layout for the longer
  reward lines (text shortened for now). Phase D: gate plaques past zone 6 and sealed-gate visuals.
- Seen in passing, not touched: a free-model Tool with 7 scripts in Workspace ("IQ 1 Gazillion"), which runs
  in play and would ship to players.

**Phase C part 2 (2026-11-26), in main.** UI layer `tools/ui/screens_v51.py` (`build_ui.py` imports it):
- ThrowMeter: `AimBack` / `AimFurther` buttons either side of "Lands in" (the line narrowed to 340, the screen
  declares the player list off), `OddsButton`; the marker's label reads "+N% LUCK". The client hides the arrow
  that cannot move (by its Cell: the button alone leaves its lip).
- New page `ThrowOdds` + `ThrowOddsRowTemplate`, driven by `Ui/Pages/ThrowOdds.luau`: rarity, mutation and
  size odds as percent and "1 in N" at the player's current luck for the aimed zone, then the luck lines
  ("+30%" for the added group, "x1.5" for the rest); follows an armed Lucky Throw. Pages are blocked while the
  player is held on the spot, so the ODDS button lifts the "throwpad" cinematic for this page and restores it
  on close.
- Catch card: the server's stamp (`result.stamp`) is used; SUPER LUCKY and up outrank NEW.
- Rebirth page: "REBIRTH n", four short reward words, the chip reads "Opens <zone>".
- Build fixes for 17 zones: `ZONE_HEX` has 17 colours; the Index mock data no longer indexes six zones. The
  HeroIndex tree now ships 17 tabs.
- Looked at in the game: throw panel (both arrows, ODDS), Throw Odds (Hero Academy, luck x1.9: Mythic 0.02%
  1 in 5,270 ... Common 51.6%; sums to 100%), Rebirth page. NOT looked at in the game: the stamp on the catch
  card (my scripted throw was refused: the server did not see my client-side teleport in that session), the
  phone layout. Not done: pictures for the 11 new zone tabs.

**Phase D done (2026-11-26), in main.**
- Gate plaques: `tools/studio/zone_gate_plaques.luau` (rerunnable, reads the config) wrote all 17: the zone's
  name and "NEEDS <power> POWER" ("START HERE" on zone 1); "COMING SOON" is gone. Each gate model carries
  the attributes `ZoneIndex` and `RebirthReq`. Rerun after `econ_v2.py apply` moves a gate.
- The sealed gate: template `ReplicatedStorage.Assets.World.ZoneSeal` (82 instances; `tools/studio/zone_seal.luau`,
  rerunnable): a violet veil across the torii's opening, two iron chains in an X bolted to the corners, the
  finale's seal (gold and violet rings, twelve marks, the kanji) and a banner. NOT placed in the map: every
  client clones ONE onto the first gate its player cannot pass and writes "REBIRTH n TO ENTER"
  (`src/client/Controllers/SealController.luau`), because the lane is shared, each player has their own rebirth,
  and the first sealed gate is past the streaming radius from the throw stage (a local model is not streamed).
  Seen in Studio edit mode (a temporary copy on zone 6's gate) and confirmed in play: the client built it at
  (0, -47.6, 2005.4) for a rebirth-1 player.
- Ambience: zones 7 to 17 have no recorded bed, so `SoundController:SetAmbience` borrows one of the six by the
  zone's place down the lane. Not listened to.
- Index pictures: 17 cards cut from pictures of the zones themselves (`tools/ui/zone_shots.py`; shots in
  `work/zone_bg/shots/`), uploaded (`assets/ui/ids_zone_bg.json`), in `Icons.luau`; seen in the Index in play.
  Trap confirmed: a positioned `screen_capture` shows paving as flat green; park the camera first
  (`run_zone.py look`), then capture with no position.
- Not done: the seal has no break animation when the player rebirths (it just moves on); nothing was
  listened to; the lane's far zones were not thrown into in play (zones 1 to 5 were, in phase C).

**Phase E done (2026-11-26), in main: the approved auras are in the game.**
- The bridge: `python tools/aura_to_game.py` reads `design/aura_assignments.json` and `aura_assign.CUSTOM`.
  A hand-built aura keeps its own template (25 heroes). Every other aura hero's preview STAND is captured as
  it stands by `tools/studio/export_preview_auras.luau` (whatever the stand has that the baked character has
  not IS the aura; a RawAura beside the hero is flattened into root-welded pieces) into
  `ReplicatedStorage.Assets.Auras.H_<heroId>` in HeroAura's own format: 105 templates. `design/auras.json`:
  130 hero lines, the `by_rarity` pools emptied (Common and Uncommon wear none), exported templates
  registered as `custom` so the old builder never touches them. The Rare aura is capped at 200 live
  particles on export (about 500 on the yard). The file before: `work/econ_v2/auras_before_phase_e.json`.
- THE FINDING: an aura approved on the yard is not the aura a player sees. Roblox draws only a share of an
  emitter's rate by graphics quality (measured with a ruler of particles: engine level 1, 5, 10, 15, 21 =
  about 0.15, 0.35, 0.5, 0.75, 1) and adds bloom near the top. Studio's edit view (automatic quality) runs
  near 0.4; Play runs at the player's setting, here the maximum. Gojo's blue sphere was a solid white ball
  in play, with exactly the emitters of his approved stand.
- The fix: `src/shared/Core/AuraDensity.luau` (pure, spec `tests/AuraDensity.spec.luau`): an aura marked
  hot carries the share of its rate it may be DRAWN at; `Fx/Vfx` reads the player's graphics bars
  (`SavedQualityLevel`; Automatic counts as 10 on a desktop, 4 on a phone), thins a hot aura just enough,
  and refits every aura when the setting moves. Marks live in `design/auras.json` "hot" (hero id -> share)
  -> `Auras.Hot`. Low graphics are untouched: the engine has thinned them already.
- The audit: `python tools/aura_judge.py row <n>` stands the baked heroes on Plot5's pedestals in the game's
  spacing and puts their auras on with the game's own code; edit quality set to Level21 = the game at its
  thickest. All 130 looked at (16 rows; the last three are the one Rare aura). Each flagged hero was then
  compared unthinned against thinned. Marked 0.4 (the approved density): Gojo, Kashimo's lightning on
  lightning_duelist and clockwork_butler, panther_espada, quiet_bomber, and the black smoke of
  black_swordsman and decay_villain (it pooled across two pedestals). Checked in play: Gojo's smoke runs at
  20 instead of 50 and he is readable again.
- NOT the aura, and not touched: white-clothed heroes (Gin, Jiren, Jiraiya, Grimmjow ...) glare at maximum
  graphics with NO aura on at all. That is the map's bloom (`MapBloom` threshold 0.92, intensity 0.5) on
  white cloth in daylight, a lighting decision for the owner.
- Runtime budget unchanged: the 10 nearest aura heroes within 110 studs, 2,200 particles; a base with more
  aura heroes than that shows the nearest ten.
- Not done: no aura was judged on a phone or at low graphics in play; rows 17 to 19 (Rares) were not
  looked at one by one; the exported templates and `ZoneSeal` only ship once the place is saved.

**Phase F, the playtest (2026-11-26), in main. Snapshot NOT taken: it waits for the owner's sign-off.**
- Speed-run through every rebirth on a wiped `Profiles_Dev_v2` profile, driven through the real remotes
  (harness in the session scratchpad: server moves the character onto its spot, the client fires ThrowPad,
  ThrowRequest, AdminCommand `zone` / `rebirthnow`, and logs the server's answers). 146 s for all ten tiers.
  At every tier: the band's last zone lands, aiming at zone 1 lands in zone 1 (depth 1, the most depth luck),
  aiming past the seal is clamped to the last open zone; each rebirth reset Power (to 10) and Yen only and
  kept heroes (6 -> 40 over the run), gear, food, slots, best zone and the Power record; +3 Lucky Throws each;
  rebirth n opened zones 2n+2 and 2n+3; from rebirth 7 all 17 zones are open. A Lucky Throw gave an Epic
  (1 in 833, LUCKY).
- The real REBIRTH button (ProgressAction): refused without the 1.8M fee with "Rebirth needs a throw of 30K
  power and 1.8M yen"; works with it. Shop locks by `bestZone`: gear 4, the 11th slot and Gyoza say "unlocks
  when you reach Hero Academy" until the player reaches zone 4, then sell.
- Training (Strike Dummy, entered by its prompt): fresh +4 a rep (the Studio account is the creator and owns
  every pass: Double Training); after rebirth 1 +20 a rep, labelled "MUSCLE MEMORY X4" (4 x 1.25 x 4), and
  back to +5 the moment Power passes the 30K record.
- Seen in the game: a forced Mythic thrown into zone 17 by a rebirth-7 player: the lane streamed in all the
  way, the counter climbed to "1 IN 1,666,667" (Mythic x Lightning) and the card wore INSANE LUCK!.
- FIXED: on the throw stage the HUD is hidden, so a player whose Power passes the sealed gate got no hint at
  all (the server's `sealed` flag was unused). `ThrowController:_sealHint` now toasts after such a throw,
  once per rebirth tier and then every 10th: "SEALED GATE: rebirth for <fee> yen to go on", or, with the fee,
  "REBIRTH READY! Step off to open <zone>". The first wording ran off the toast; both now fit (48 characters).
- FIXED: the rebirth celebration's stat panel listed Rebirth, Income, Luck and "Index & passes KEPT"; it now
  adds Training (+25% a tier) and says "Heroes, gear & food KEPT" (the v2 rule).
- FIXED: phones could turn the game to portrait (`StarterGui.ScreenOrientation` was Sensor), where the 16:9
  HUD shrank to a strip of 15-pixel buttons. The client sets `PlayerGui.ScreenOrientation` LandscapeSensor
  (`src/client/init.client.luau`) and the place's StarterGui says the same (a place property: ships with the
  next save). Checked: the simulator held in portrait, the game stays landscape.
- Phones (Studio Device Simulator, Galaxy A06 705 x 338 and iPhone 17 Pro 750 x 381): HUD and the throw panel
  (aim arrow, "Lands in", meter, ODDS, Lucky, Throw, Auto) fit and read. Roblox's thumbstick ring sits over
  the bottom of the Power / Yen / Luck stack on the base (not on the stage: movement is held there).
- NOT verified: the Throw Odds and Rebirth pages on a phone (the MCP mouse tool clicks off-target on the
  simulated phone and threw instead; Roblox's own hit test puts ODDS on top at its real position, so a real
  tap opens it); frame rate with five full bases on a phone (phase E's bar); the seal on rebirth has no break
  animation; nothing was listened to.
- Still in the place, flagged and not removed: the free-model Tool "IQ 1 Gazillion" in Workspace runs scripts
  at server start (prints "IQ 1 Gazillion was been summon!" and errors on a bad Font) and would ship.

**Snapshot (2026-11-26), on the owner's sign-off ("Remove IQ tool, snapshot").** The free-model Tool
"IQ 1 Gazillion" (197 parts, 7 scripts: music, a weld, a rainbow, a name label; no require, loadstring or
HTTP) was deleted from Workspace; Workspace now holds no scripts. Gates green, commit 637aa02, tag
`economy-v2`, place version 903 ("Economy v2 approved (git economy-v2)"). Not pushed, not published.
