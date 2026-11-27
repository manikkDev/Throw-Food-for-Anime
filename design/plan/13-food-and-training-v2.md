# Plan 13: food and training v2

**Status: APPROVED by the owner on 2026-11-26 (all seven decisions as recommended). Build log: section 11.**

The owner's ask: more and better foods that belong to the anime worlds, with calculated numbers so
nobody gets bored; food models, textures, animation and effects at a professional level; and the
training ("exercise") replaced by something interactive, fun, simple, playable AND leave-running,
that can evolve into another game after enough upgrades.

Numbers in this plan come from `tools/economy/econ_v3.py` (a draft tool: it writes
`design/plan/13-economy-draft.json`, never `design/game.json`). Rerun: `gen`, `sim`, `cadence`, `table`.

## 1. In one page

| | Today | Plan 13 |
|---|---|---|
| Foods | 12, generic, flat-coloured, no textures | **51: three per world (Snack, Meal, Signature), each a dish from that world's anime**, textured |
| What food does | luck x1 to x5.5 and reach x1 to x5 | **luck only**, strong steps (x1 → x1.45 → x2 inside every world); reach comes from Power alone |
| Where a food works | everywhere the same | full luck in its own world and every earlier one; **half luck in a later world** (heroes want the food of their own world) |
| Cravings | four flavours | **each hero has a favourite dish** of its own world (x3 chance inside its rarity, as today) |
| Training stations | 2 (punch a dummy, sit under a waterfall), one tap ring | **8 training grounds, one new one per rebirth**, each with its own one-thumb game |
| Training upgrades | 19 | **57 (three levels per tier)** |
| Leave it running | yes, loses about a third | yes, **x1.0**; playing is worth about **x1.85** (typical) to **x2.3** (perfect) |
| Things to buy per world | 2 or 3 (late worlds: one per 70 to 100 minutes) | **7 or 8 (late worlds: one per 25 to 30 minutes)** |
| Time to the last world, free | about 30 h | about 28 h; all seven approved pacing checks pass |

## 2. What is there today (measured in the place, 2026-11-26)

- `ReplicatedStorage.Assets.Foods`: 12 models, 3 to 5 flat-coloured mesh parts each, **0 textures**.
- `ReplicatedStorage.Assets.Gear`: 8 models for 19 gear tiers (11 tiers reuse a model), **0 textures**.
- Training: reps on a 1 s clock, one tap ring, +50% for a perfect tap. Two stations.
- Purchases: 19 gear + 12 foods + 16 slots + 10 rebirths = 57 in about 30 hours. Worlds 7, 9, 11,
  13, 15 and 17 have no new food at all.

Sample made for this plan with Studio's mesh generator (left) next to the current ramen (right):

![new ramen sample next to the current ramen](img/13-food-sample.jpg)

The same test also returned a failed model (a "meat on the bone" came back as a lump with six
bones). That is the honest state of the generator: every food has to be looked at, and remade
until it is right. The plan budgets for that (section 4).

## 3. Research

**The reference game, Throw Food For Animals (state on 2026-11-26)**
- 54 foods over 20 zones, all bought with cash, permanent, sold in a fixed order. 64 training bars.
  Every weekly update adds one zone, four foods and 6 to 8 bars.
  [game.guide/throw-food-for-animals/foods, eldorado.gg, bloxodes.com]
- Food is a "bait level" and nothing else: no distance, no power. Each zone has its own three
  foods; the first aims at about rank 2 of that zone's animals, the second at rank 5, the third at
  rank 8. Food from an earlier zone aims at rank 1. [game.guide, one source for the exact ranks]
- Training: pull-up bars, reps run by themselves every 0.5 s; a pop-up every 4 to 6 s is the only
  input and is worth about +10% (my arithmetic from the published numbers). Each bar doubles the
  one before. [game.guide/throw-food-for-animals/training-bars, allthings.how]
- No food variants, no food collection, no food behind Robux.

**Training games that do well on Roblox** (sources in the research agent's report; thin where
wikis blocked reading, and no public retention numbers exist)
- The genre standard is free auto-reps with an optional tap bonus. Where the bonus is tiny
  (+10%, the reference) players ignore it; where tapping is forced (stamina, click per rep)
  guides tell players to use auto-clickers.
- What works: an idle floor with an active ceiling 2 to 3 times higher, played in short bursts.
- Games that change the activity at milestones (Arm Wrestle Simulator's grips, barbells, bags,
  walls; Anime Fighting Simulator's Chakra Tree, Waterfall, Gravity Chamber; Gym League's boulder
  game at the fourth gym) keep a "what is the next one" goal. Re-skins alone (the reference's 64
  bars) are cheap but are the same activity for the whole game.
- Pay per judged event on the server, never per tap; ignore inputs closer than 0.1 s.

**What I take from it:** food as each world's own bait is the proven core of the genre and fits
"foods related to anime" exactly. Training is the reference's weakest part, so it is where this
game can be clearly better.

## 4. Food

### 4.1 Rules

1. **51 foods = 17 worlds x 3.** Every world sells a **Snack**, a **Meal** and a **Signature
   dish**, all dishes people know from that anime. Names are dishes, never franchise names (the
   same rule as the hero aliases).
2. **Food gives Luck, nothing else.** How far you throw is your Power (training). One job each.
3. **Luck inside a world:** Snack x1.0, Meal x1.45, Signature x2.0, times the world's base, which
   grows 8% per world (world 1 = 1.0, world 17 = 3.43). So the ladder runs from x1.0 (Onigiri) to
   x6.85 (Warrior's Feast), and every purchase inside a world is a step of about +40%.
4. **Home-world rule:** a food has its full Luck in its own world and in every earlier world. In a
   later world it counts **half**. On arriving in a new world the old Signature is worth less than
   the new Snack, so the new world's cheap Snack is the first thing to buy there.
   Going back to finish an old world's Index with a late food works at full strength.
5. **Auto-pick** (on by default): the game equips your best food for the world you aim at. A
   player who never opens the food bag is never punished by rule 4. Picking by hand stays possible.
6. **Favourite dish** (replaces the four flavours): every hero has one favourite among its own
   world's three dishes, shown on its Index tile and on the catch card. Throwing a hero's
   favourite makes it three times as likely inside its rarity (today's craving rule, unchanged).
   Favourites are spread over the three dishes in every world and rarity, iconic pairs first.
7. **Unlock and price:** a world's three foods unlock when you first reach that world; they cost
   2%, 7% and 18% of what that world pays a free player in its target time. Any unlocked food can
   be bought in any order.
8. **Cookbook:** a Foods tab in the Index. Owning all three dishes of a world gives one Lucky
   Throw (17 in total). No grind, no throw counters.
9. **Fair-play line unchanged:** no food is sold for Robux.

**Why 51.** The reference has 54 for 20 zones (2.7 per zone). Three per world gives every world
the same clear shape, an anime-true set of dishes, and with the training levels one thing to buy
every 1 to 4 minutes in the first worlds and every 25 to 30 minutes in the last ones. Two per
world (34) leaves gaps over an hour late in the game; four (68) adds 17 models without closing
any gap that matters.

### 4.2 The 51 foods (luck and price from the draft; names are open to the owner's changes)

| World | Snack | Meal | Signature dish |
|---|---|---|---|
| 1 Hidden Leaf Village | Onigiri, x1, free | Tricolor Dango, x1.45, 520 | Legendary Ramen, x2, 1.3K |
| 2 Demon Slayer Corps | Ohagi, x1.08, 12K | Tempura Bowl, x1.57, 43K | Flame Bento, x2.16, 110K |
| 3 Grand Line | Sea King Takoyaki, x1.17, 230K | Meat on the Bone, x1.69, 820K | Swirl Fruit, x2.33, 2.1M |
| 4 Hero Academy | Cold Soba, x1.26, 5.9M | Hero's Katsudon, x1.83, 21M | Explosion Mapo Tofu, x2.52, 53M |
| 5 Blue Lock Facility | Kintsuba, x1.36, 160M | Striker Gyoza, x1.97, 550M | Rank One Steak, x2.72, 1.4B |
| 6 Clover Kingdom | Village Tatoes, x1.47, 2.4B | Four-Leaf Cake, x2.13, 8.4B | Cotton Sheep Feast, x2.94, 22B |
| 7 Hunter Exam | Robo Choco Balls, x1.59, 43B | Exam Sushi, x2.3, 150B | Giant Boar Roast, x3.17, 390B |
| 8 Isekai Crossroads | Isekai Apple, x1.71, 490B | Flying Cabbage Stir-fry, x2.49, 1.7T | Floor Boss Stew, x3.43, 4.4T |
| 9 Wall Maria | Steamed Potato, x1.85, 5.1T | Scout Ration Bread, x2.68, 18T | Officer's Ham, x3.7, 46T |
| 10 Public Safety HQ | Jam Toast, x2, 82T | Devil Hunter Burger, x2.9, 290T | Devil Ice Cream, x4, 740T |
| 11 Bizarre Streets | Double Cherry, x2.16, 820T | Margherita Pizza, x3.13, 2.9Qa | Healing Squid Ink Pasta, x4.32, 7.4Qa |
| 12 Shadow Council | Consomme Chips, x2.33, 10Qa | Reaper's Apple, x3.38, 36Qa | Detective's Cake Tower, x4.66, 92Qa |
| 13 City Z | Hero's Banana, x2.52, 200Qa | Hero Udon, x3.65, 710Qa | Crab Hot Pot, x5.04, 1.8Qi |
| 14 Soul Society | Soul Candy, x2.72, 1.3Qi | Strawberry Daifuku, x3.94, 4.5Qi | Captain's Curry, x5.44, 12Qi |
| 15 Gate of Shadows | Hunter Kimbap, x2.94, 17Qi | Fire Rice Cakes, x4.26, 60Qi | Elixir of Life, x5.87, 150Qi |
| 16 Shibuya | Shibuya Crepe, x3.17, 160Qi | Meatball Hot Pot, x4.6, 550Qi | Infinity Cream Mochi, x6.34, 1.4Sx |
| 17 Planet of the Gods | Hermit Bean, x3.43, 9.1Sx | Destroyer's Pudding, x4.97, 32Sx | Warrior's Feast, x6.85, 82Sx |

Odds a free player sees per throw (food x average depth and perfect x rebirth luck):

| World | Food | Luck | Rare | Epic | Legendary | Mythic | Secret |
|---|---|---|---|---|---|---|---|
| 1 | Snack | x1.18 | 1 in 8 | 1 in 42 | 1 in 339 | 1 in 8,475 | not here |
| 1 | Signature | x2.36 | 1 in 5 | 1 in 21 | 1 in 169 | 1 in 4,237 | not here |
| 3 | Snack | x1.38 | 1 in 7 | 1 in 36 | 1 in 291 | 1 in 7,266 | not here |
| 3 | Signature | x2.75 | 1 in 5 | 1 in 18 | 1 in 145 | 1 in 3,633 | not here |
| 5 | Snack | x1.77 | 1 in 6 | 1 in 28 | 1 in 227 | not here | not here |
| 5 | Signature | x3.53 | 1 in 4 | 1 in 14 | 1 in 113 | not here | not here |
| 9 | Snack | x2.84 | 1 in 5 | 1 in 18 | 1 in 141 | not here | not here |
| 9 | Signature | x5.68 | 1 in 3 | 1 in 9 | 1 in 70 | not here | not here |
| 13 | Snack | x4.46 | 1 in 4 | 1 in 11 | 1 in 90 | 1 in 2,244 | 1 in 224,358 |
| 13 | Signature | x8.91 | 1 in 2 | 1 in 6 | 1 in 45 | 1 in 1,122 | 1 in 112,179 |
| 17 | Snack | x6.87 | 1 in 3 | 1 in 7 | 1 in 58 | 1 in 1,455 | 1 in 145,509 |
| 17 | Signature | x13.74 | 1 in 2 | 1 in 4 | 1 in 29 | 1 in 728 | 1 in 72,754 |

### 4.3 Look and feel (the quality bar)

Per food, all of these, or it is not done:

1. **Model:** one textured mesh from Studio's mesh generator, at most 3,000 triangles, made
   large and scaled down. Judged at maximum graphics in the hand, in flight and in the shop.
   Wrong shape, smeared texture or an unfinished back = remade (expect two or three tries each;
   a dish that never comes right is modelled by hand in Blender). Squared, pivot at the grip.
2. **Shop and HUD:** the real 3D model, slowly turning on its card, on a plate of its world's
   colour; Signature dishes get a gold frame and a shine sweep.
3. **Hold and throw, three classes:** one-hand pitch (small things), two-hand heave (bowls,
   plates, feasts), spin toss (skewers, pizza, flat things). Three hold poses and three throw
   clips, judged on rendered frames.
4. **Flight:** each class spins its own way (a bowl stays upright and trails steam, a skewer
   turns end over end). Snack: a clean streak. Meal: streak and sparks. Signature: its own
   effect (below).
5. **Landing:** Snack a dust puff; Meal a ring and aroma wisps; Signature a pillar of its own
   colour and aroma lines that the hero follows in. A favourite dish adds a "FAVOURITE!" burst
   and the hero's happy reaction.
6. **Sound:** a throw whoosh per class, a landing per dish type (bowl clink, sizzle, soft
   thump), a short sting for a Signature.

**The 17 Signature effects** (each built from the dish, textures made for it, judged frame by
frame in the simulator and then in the game at maximum graphics):

| World | Signature dish | Effect in flight and on landing |
|---|---|---|
| 1 | Legendary Ramen | steam spiral with a pink fish-cake swirl ring |
| 2 | Flame Bento | a tail of flame, embers on landing |
| 3 | Swirl Fruit | purple spiral ribbons, a dark pulse on landing |
| 4 | Explosion Mapo Tofu | orange pops along the path, a small blast |
| 5 | Rank One Steak | blue speed lines, a gold "1" flash |
| 6 | Cotton Sheep Feast | soft wool puffs and clover leaves |
| 7 | Giant Boar Roast | heavy smoke trail, ground shake |
| 8 | Floor Boss Stew | blue polygon shards (game-world break) |
| 9 | Officer's Ham | steam and green cape-wing feathers |
| 10 | Devil Ice Cream | cold mist, a red chain-link spark ring |
| 11 | Healing Squid Ink Pasta | golden sparkle with drifting menacing-style glyphs |
| 12 | Detective's Cake Tower | sugar cubes and black feathers |
| 13 | Crab Hot Pot | steam burst with a single clean shockwave |
| 14 | Captain's Curry | black and white spirit pressure streaks |
| 15 | Elixir of Life | violet rune circle, blue glow |
| 16 | Infinity Cream Mochi | blue and red orbs joining to violet |
| 17 | Warrior's Feast | golden aura flare, lightning crackle |

## 5. Training

### 5.1 One framework, eight grounds

Every training ground works the same way underneath, so the balance is one set of numbers:

- **Stand on it and it trains.** Reps run on the server's clock, one per second, at **x1.0**.
  This never stops and needs no input: the leave-it-running mode.
- **Play it and it pays more.** Each ground shows one **beat** at a time (a ring to hit, a hold
  to let go of, a side to tap). The server judges each beat: **Perfect** doubles that beat's
  reps, **Good** adds half, a miss still pays the plain reps. One thumb, big targets on the
  right side of the screen.
- **Focus and AWAKENING.** Perfect gives 2 Focus, Good gives 1. At 40 the hero awakens for 8
  seconds: aura on, every rep is an automatic Perfect and pays x1.5 on top, no input needed (the
  thumb rests and the player watches the payoff). Then Focus starts again.
- **What that is worth** (calculated):

| Player | Hits | Rate while playing | Awakening every |
|---|---|---|---|
| Leaves it running | none | x1.00 | never |
| Casual | 20% perfect, 50% good | x1.69 | 52 s |
| Typical | 40% perfect, 40% good | x1.87 | 41 s |
| Good | 60% perfect, 30% good | x2.04 | 35 s |
| Perfect | every beat | x2.29 | 28 s |

- **Cheating:** beats are placed and timed by the server with jitter, so a fixed-interval
  auto-clicker lands on Good at best; one judgement per beat, extra taps ignored.
- Double Training (pass), training packs, the rebirth bonus (+25% a tier) and muscle memory (x4
  below your record) all multiply this, as today.

### 5.2 The eight grounds

One new ground per rebirth band. A base always shows the **two newest** (one on each court), and
both pay the same, so there is always a choice of two games. In the first band the second court
shows the Waterfall locked, with "REBIRTH 1" on it: a visible reason to take the first rebirth.

| # | Ground | Opens | The game (one rule) | Beat | Awakening moment |
|---|---|---|---|---|---|
| 1 | Striking Post | start | a ring closes on a weak spot on the post: tap as it lands | 1 s | a flurry, the post bursts into splinters and a thicker one rises |
| 2 | Waterfall Focus | rebirth 1 | hold as the breath ring fills, let go in the gold band | 3 s | the waterfall splits and runs upward |
| 3 | Boulder Breaker | rebirth 2 | a needle sweeps a meter: tap in the sweet spot, each hit cracks the rock | 2 s | the boulder shatters, a bigger one drops in |
| 4 | Thunder Peak | rebirth 3 | lightning marks one of three rods: tap that side before it strikes | about 2 s | the hero is wrapped in lightning |
| 5 | Gravity Chamber | rebirth 4 | push-ups to a beat under a gravity dial (10G to 500G): tap on the beat | 1 s, with rests | gravity flips, the hero floats |
| 6 | Spirit Orb | rebirth 5 | hold to grow an energy orb overhead, let go on the gold pulse | 4 s | the orb is thrown to the sky and bursts |
| 7 | Titan Chains | rebirth 6 | three rings in a row (tap, tap, tap), then a rest, hauling a chained colossus weight | 3 s | the chains snap, the weight is lifted overhead |
| 8 | Timeless Hall | rebirth 7 | a medley: every 20 s it switches between the earlier games, faster | mixed | the white hall fills with every earlier aura |

> **Superseded 2026-11-27:** the owner kept SIX grounds. Grounds 7 and 8 were never built, and the gear tiers in the
> table below were shared out again over the six (3 / 3 / 3 / 3 / 3 / 4). See "six grounds, not eight" in section 11.

Each ground is a full set piece on the court: textured models, its own two animations (training
loop and awakening), effects, sounds and music sting, a sign with its name and level.

### 5.3 Upgrades: 57 levels

- The 19 gear tiers stay (17 by world reached, 2 for rebirths 8 and 9). Each tier now has **three
  levels (I, II, III)** bought with Yen: x0.6, x1.0 and x1.5 of the tier's base Power per rep.
- **Every tier changes the look** of its ground (the post gets iron bands, the waterfall gets
  taller, the gravity dial reads higher); every level adds a visible piece (ropes, charms, glow).
- **The evolution the owner asked for:** a ground has 6 upgrades (9 for the first, 12 for the
  last); the next upgrade after those needs the next rebirth, and it is a new ground with a new game.
- Prices: 1.5%, 4.5% and 10% of what the tier's world pays in its target time.

| Tier | Unlocks at | Ground | Power per rep I / II / III | Price I / II / III |
|---|---|---|---|---|
| 1 | world 1 | Striking Post | 1 / 2 / 3 | free / 330 / 740 |
| 2 | world 2 | Striking Post | 3 / 6 / 8 | 9.3K / 28K / 62K |
| 3 | world 3 | Striking Post | 20 / 33 / 49 | 180K / 530K / 1.2M |
| 4 | world 4 | Waterfall Focus | 110 / 180 / 280 | 4.4M / 13M / 29M |
| 5 | world 5 | Waterfall Focus | 760 / 1.3K / 1.9K | 120M / 350M / 790M |
| 6 | world 6 | Boulder Breaker | 6.6K / 11K / 17K | 1.8B / 5.4B / 12B |
| 7 | world 7 | Boulder Breaker | 63K / 110K / 160K | 32B / 97B / 220B |
| 8 | world 8 | Thunder Peak | 530K / 880K / 1.3M | 370B / 1.1T / 2.4T |
| 9 | world 9 | Thunder Peak | 5.1M / 8.6M / 13M | 3.8T / 11T / 26T |
| 10 | world 10 | Gravity Chamber | 50M / 83M / 120M | 62T / 180T / 410T |
| 11 | world 11 | Gravity Chamber | 530M / 880M / 1.3B | 620T / 1.8Qa / 4.1Qa |
| 12 | world 12 | Spirit Orb | 5.3B / 8.8B / 13B | 7.7Qa / 23Qa / 51Qa |
| 13 | world 13 | Spirit Orb | 58B / 96B / 140B | 150Qa / 460Qa / 1Qi |
| 14 | world 14 | Titan Chains | 580B / 970B / 1.5T | 970Qa / 2.9Qi / 6.5Qi |
| 15 | world 15 | Titan Chains | 6.2T / 10T / 15T | 13Qi / 38Qi / 85Qi |
| 16 | world 16 | Timeless Hall | 59T / 98T / 150T | 120Qi / 350Qi / 780Qi |
| 17 | world 17 | Timeless Hall | 650T / 1.1Qa / 1.6Qa | 6.8Sx / 20Sx / 46Sx |
| 18 | rebirth 8 | Timeless Hall | 1.6Qa / 2.7Qa / 4Qa | 91Sx / 160Sx / 230Sx |
| 19 | rebirth 9 | Timeless Hall | 14Qa / 23Qa / 34Qa | 180Sx / 320Sx / 460Sx |

## 6. The numbers, checked

`python tools/economy/econ_v3.py sim` (median of 7 simulated players per column, 48 h each):

| Milestone | Average | Leaves it running | Plays (typical) | Plays perfectly | x2 Training pass | All passes | Window (plan 12) |
|---|---|---|---|---|---|---|---|
| World 2 | 2m55s | 3m58s | 2m41s | 2m13s | 2m06s | 1m59s | 1.5 to 5 min |
| World 3 | 12m08s | 15m45s | 10m51s | 9m41s | 8m24s | 7m21s | 9 to 19 min |
| Rebirth 1 | 30m06s | 39m33s | 28m00s | 26m22s | 23m55s | 16m27s | 25 to 46 min |
| Rebirth 2 | 1h52m | 2h20m | 1h41m | 1h31m | 1h24m | 56m35s | 1h33 to 2h48 |
| Rebirth 4 | 7h19m | 9h29m | 6h45m | 5h58m | 5h32m | 3h55m | 6h10 to 11h |
| Rebirth 7 | 24h27m | 31h07m | 22h27m | 20h21m | 18h30m | 12h37m | 19h30 to 35h10 |
| World 17 (the last) | 28h12m | 36h01m | 25h51m | 22h53m | 21h14m | 14h37m | 23h to 41h20 |

- "Average" is the design player: plays about 60% of training time, leaves it running for the rest.
- All seven pacing windows approved in plan 12 pass for the average free player.
- Leaving training running for the whole game costs about 8 hours on the way to the last world;
  playing every beat perfectly saves about 5. Passes keep the bounds plan 12 approved.

Minutes between purchases, by world (average free player):

| World | Minutes there | Purchases | Average gap | Longest gap |
|---|---|---|---|---|
| 1 | 3 | 4 | 0.8 min | 1.1 min |
| 2 | 9 | 6 | 1.5 min | 2.0 min |
| 3 | 20 | 8 | 2.5 min | 4.1 min |
| 4 | 30 | 8 | 3.8 min | 6.9 min |
| 5 | 53 | 7 | 7.5 min | 10.8 min |
| 6 | 59 | 7 | 8.4 min | 13.2 min |
| 7 | 82 | 7 | 11.7 min | 18.6 min |
| 8 | 82 | 7 | 11.7 min | 19.7 min |
| 9 | 123 | 8 | 15.3 min | 22.6 min |
| 10 | 117 | 7 | 16.7 min | 28.2 min |
| 11 | 145 | 8 | 18.1 min | 32.1 min |
| 12 | 137 | 7 | 19.6 min | 32.7 min |
| 13 | 204 | 7 | 29.1 min | 55.1 min |
| 14 | 170 | 7 | 24.2 min | 37.9 min |
| 15 | 242 | 8 | 30.2 min | 47.7 min |
| 16 | 204 | 7 | 29.1 min | 44.9 min |
| 17 | 240 (target) | 7 | about 34 min | not simulated to its end |

In the last worlds a hero is still caught every 7 seconds, and each rebirth brings two worlds,
six foods and a new training ground, so the long gaps are between purchases, not between events.

Slot prices and rebirth fees move a little with the new income (all in the draft JSON); the
rebirth Power gates do not change.

## 7. What changes in the project

- **Numbers:** `econ_v3.py` gets an `apply` (as v2 has) and becomes the pacing gate; `design/game.json`
  gets `Foods` (51, with `Zone`, `Role`, `Luck`), `Training.Equipment` (57), `Training.Grounds` (8),
  the beat and Focus constants; `PowerMult` and `Flavors` go. `gen_characters.py` gives each hero a
  `Favourite` from `design/characters/lineup.json`.
- **Rules (pure modules with specs):** `Luck` (food luck by aimed world), `Throw` and `Progress`
  (reach = Power), `Roll` (favourite instead of flavour), new `Core/Beat` (the judge: windows,
  Focus, awakening, jitter) and `Core/Foods` (best food for a world, cookbook sets).
- **Server:** ThrowService, ShopService, ProgressService, RewardsService, AdminService (reach and
  food luck), TrainingService (grounds, beats, Focus, levels). Saves move to `Profiles_v3`
  (nothing is published, so no player data is lost).
- **Client:** FoodShop (grouped by world, 3D models, "BEST HERE" and "half luck here" tags),
  HUD food chip, aim panel and Throw Odds page (food luck for the aimed world), Index (favourite
  dish, Cookbook tab), TrainingController rebuilt on the beat framework with one small view per
  game, Rebirth page ("opens: 2 worlds, 6 foods, <ground>").
- **Place:** food templates replace `Assets.Foods`; ground templates replace `Assets.Gear`; the
  12 old foods and 8 old gear models go to `ServerStorage.MapArchive` (never deleted).

## 8. Build order (each phase ends with the owner's look)

| Phase | What | Done when |
|---|---|---|
| A | Rules, numbers, code and screens wired (old models stay in for this phase only) | all gates green, the pacing gate on `game.json`, a headless run through ten rebirths |
| B | The 51 foods, in six batches by rebirth band (9, 6, 6, 6, 6, 6+12) | each batch shown to the owner as a picture sheet from the game at maximum graphics |
| C | Throw feel: three hold/throw clips, flight, trails, 17 Signature effects, landings, sounds | judged in the game on a phone and a PC |
| D | Training framework + grounds 1 and 2 complete | the owner plays both and approves the bar |
| E | Grounds 3 to 8, two at a time | each pair played by the owner |
| F | Full playtest through all rebirths, phones, tuning, snapshot (commit, tag, save) | the owner's sign-off |

## 9. Risks and what is not proven yet

- **The mesh generator misses** (one of the two samples failed). Every food is judged; the plan
  counts on remakes. Its moderation also refuses some words; prompts are worded plainly.
- **Hit rates are assumptions** (40% perfect, 40% good for a typical player). Phase D measures
  real rates in play; the Focus and bonus constants are in config and the simulator covers the
  whole range from leave-running (36 h) to perfect (23 h), so a wrong guess moves a player
  inside a range that is already acceptable.
- **Phones:** 51 textured models are never loaded at once (only equipped foods and the open
  shop page); each ground is one set piece per base. Frame rate is measured in phase F.
- **Names:** dishes only, no show, character or place names. Where a show uses an invented word
  for a food, the plan uses a plain one instead (Swirl Fruit, Hermit Bean, Isekai Apple, Village
  Tatoes). The owner can change any name.

## 10. Decisions for the owner

1. **51 foods, three per world** (recommended). Other choices: 34 (two per world) or 68.
2. **Food gives luck only; throwing distance comes from training only** (recommended).
   Other choice: keep a small reach bonus on food as today.
3. **Home-world rule with auto-pick**: half luck in a later world (recommended).
   Other choice: one ladder that works the same everywhere, with steps of about +4% per food.
4. **Favourite dish replaces the four flavours** (recommended).
5. **Eight training grounds, one per rebirth, each with its own game** (recommended).
   Other choices: four grounds (one per two rebirths), or keep and polish the current two.
6. **57 training levels, three per tier** (recommended).
7. **Playing is worth about x1.85 over leaving it running** (x2.3 at most) (recommended).

## 11. Build log

**Phase A (rules, numbers, code, screens wired), 2026-11-26: built, awaiting the owner's look.**
- Numbers: `econ_v3.py` got `apply` and `check`; `tools/gate.py` runs it as the pacing gate.
  `design/game.json` has the 51 foods (`Zone`, `Role`, `Luck`), 57 training rows (`Tier`, `Level`,
  `Ground`, `Model` = the old tier model until phase D), `Training.Grounds`, `Training.Beat`,
  `Luck.StaleFood`, `Rewards.CookbookLuckyThrows`; `Flavors` and `PowerMult` are gone. Saves:
  `Profiles_v3` / `Profiles_Dev_v3`. Zone 1's levels are hand-set to 1, 2, 3 Power per rep and
  every upgrade is forced stronger than the one before.
- Heroes: `Favourite` (a food id) replaces `Craves`; iconic pairs in
  `design/characters/favourites.json`, the rest dealt by `gen_characters.py`.
- Rules: `Core/Foods` (luck by world, best food, cookbook), `Core/Beat` (the judge), `Throw` and
  `Progress` without food reach, `Roll` by favourite. Spec `tests/Foods.spec.luau`; 136 specs pass.
- Server: the throw picks the food AFTER the landing zone is known (auto-pick or the pinned one)
  and tells the client which (`result.food`); the shop pins on equip, `"auto"` unpins, and pays the
  cookbook; training grades one tap per jittered beat, fills Focus and awakens.
- Client: `Ui/FoodLook` (which food is thrown, how it is drawn; foods without a model of their own
  borrow one of the twelve old ones until phase B), HUD chip (AUTO / PINNED), throw panel, shop
  (worlds reached + the next, role, luck where the next throw goes, IN USE / PIN / PINNED),
  Index and catch card (favourite dish), rebirth page, training ring on beats with Focus in the
  hint line.
- Played in Studio: auto-pick threw the Legendary Ramen and doubled the luck (1.92 -> 3.88),
  the favourite match registered, pin and unpin work, the cookbook paid one Lucky Throw, a gear
  level was bought; 20 perfect taps filled Focus to 40, the awakening ran 8 s and taps during it
  were ignored. The food shop was looked at in the game.
- NOT done in phase A: the second court stays locked until rebirth 1 but still shows the old
  waterfall; the Index, catch card, rebirth page and training hint were not looked at on screen;
  the shop keeps its old one-row layout (an empty strip where the flavour filters were); no
  Cookbook tab yet; no ten-rebirth run in Studio (the headless Journey spec walks the whole lane).

**Phase B, batch 1 (worlds 1 to 3, nine foods), 2026-11-26: built, awaiting the owner's look.**

![batch 1](img/13-foods-batch1.jpg)

- Pipeline (rerunnable, in `tools/studio/foods/` and `tools/ui/food_icons_v2.py`; sizes, turns and throw
  classes in `design/foods.json`): generate_mesh with the prompt starting `FOOD_<id>:` -> `food_lab.luau`
  (judging row; a newer try replaces the older, old tries go to `ServerStorage.FoodLabRejected`) ->
  `install_foods.py` (templates `Assets.Foods.Food_<id>`, raw copies in `StoreAssets.Foods_v2`, the twelve
  old models in `MapArchive.Foods_v1`) -> `food_icons_v2.py` (icons rendered from the templates on a white
  and a black wall, cut out by their difference, ink outline, uploaded; `ids_food_icons_v2.json`).
- Tries: onigiri, dango, ramen, tempura bowl, takoyaki, swirl fruit 1 each; ohagi and bento 2; the meat 4
  (an American football, then pink and spotted three times) and then its texture redone with
  generate_texture. The meat is the weakest of the nine.
- Traps: a model with a PrimaryPart ignores `WorldPivot` (turn it through the part's `PivotOffset`); the
  generator lays some models down (`turn` in foods.json); a retextured mesh carries a SurfaceAppearance
  that loads late (its first icon came out grey); a capture now and then shows the wall before its new
  colour (the tool retries).
- Seen in the game: the shop cards (3D models, textured), the throw panel icon. A bowl, plate or tray now
  stays level in the hand during the wind-up (it was tipped on its side); that fix is not looked at yet.

**Phase B, batch 2 (worlds 4 and 5, six foods), 2026-11-26: built, awaiting the owner's look.**
- Cold Soba, Hero's Katsudon, Explosion Mapo Tofu, Kintsuba, Striker Gyoza: one try each. Rank One Steak:
  two (the first was a glossy red disc on a pink plate). 15 of 51 foods now have their own model and icon
  (sheet: `assets/ui/food_icons_v2_sheet.png`).
- The Kintsuba came on a stick and the gyoza without their plate; both read well and were kept.
- Not looked at in the game yet (the templates and icons are installed the same way as batch 1).

**Phase B, batch 3 (worlds 6 and 7, six foods) + flight styles, 2026-11-26: built, awaiting the owner's look.**
- Village Tatoes, Four-Leaf Cake, Cotton Sheep Feast, Robo Choco Balls, Exam Sushi, Giant Boar Roast: one try
  each. 21 of 51 foods have their own model and icon. The candy box has gears instead of a robot face and
  the sushi no board; both kept.
- Flight (owner's question: will a bowl look odd spinning): `ThrowController.flightTurn` reads the
  template's `Throw` attribute. heave = level, top leaning 22 degrees toward the chase camera, slow flat
  turn; spin = end over end; anything else = a tumble at about half the old speed. Measured in play on the
  Legendary Ramen: level in the hand, a constant lean through the flight, upright after landing.
- Open: in the landing close-up a bowl fills most of the frame (foods are drawn 1.7x in flight and the
  camera was set for the old, smaller models): phase C.

**Checkpoint, 2026-11-26:** phase A and food batches 1 to 3 committed (dfa0551) and saved as place version
921 ("Plan 13: rules + foods of worlds 1-7"). Not pushed, not published. Not a section snapshot: no tag.

**Phase B, batch 4 (worlds 8 and 9, six foods), 2026-11-26: built, awaiting the owner's look.**
- Isekai Apple, Flying Cabbage Stir-fry, Floor Boss Stew, Scout Ration Bread: one try each. Steamed Potato:
  two (the first was a pale lump). Officer's Ham: came pink like raw sausage, texture redone with
  generate_texture. 27 of 51 foods have their own model and icon.
- Trap: generate_texture hands the model back without its PrimaryPart and turned; set the PrimaryPart again
  before install_foods.py. A capture comes back as a blank dark frame when the display has blanked during a
  wait: run tools/studio/front.ps1 right before it.

**Phase B, batch 5 (worlds 10 and 11, six foods), 2026-11-26: built, awaiting the owner's look.**
- Jam Toast, Devil Hunter Burger, Devil Ice Cream, Double Cherry, Margherita Pizza, Healing Squid Ink Pasta:
  one try each. 33 of 51 foods have their own model and icon.
- Trap: one icon (the black pasta) came out as a small dark blob on its first render although the tool said
  ok: LOOK at the sheet after every icon run, the tool cannot tell a bad capture from a good one.

**Phase B, batch 6 (worlds 12 to 17, eighteen foods), 2026-11-27: built. PHASE B IS COMPLETE: all 51 foods
have their own textured model and icon (sheet: `assets/ui/food_icons_v2_sheet.png`).**
- Seventeen passed on the first try. The Warrior's Feast took two: its roast came with a cartoon face; the
  remake arrived standing on its edge (`turn` [90, 0, 0]).
- Trap: after a Studio restart the editor's grid lines show in the 3D view and in every capture; the icon
  cut-out took them for part of the food and nine icons came out tiny. `food_icons_v2.py` now erodes the mask
  before it measures the food (hairlines vanish) and refuses a food that is far too small in the picture.
- A spec now fails if any food in the config has no icon of its own.
- Whole phase, tries per food: 41 of 51 on the first try, 8 on the second, the meat on its fourth plus a
  texture pass, the ham on a texture pass. Not looked at in a play session: batches 2 to 6 (only batch 1's
  shop cards and the ramen's throw were seen in the game).

### 2026-11-27: phase B checked in the game

- New Studio test command `best <n>` (AdminService): a save that has reached world n (best zone, the rebirths
  that open it, the Power to land there), so the food shop and every world-gated page show up to that world.
- Food shop, all 51 cards seen (13 screens): every card has its own icon, the right world, role and luck,
  "(HALF)" on foods of earlier worlds, IN USE on the auto-picked Warrior's Feast. HUD chip shows the food's icon.
- "NEW FOOD!" cards: about half came up with an empty stage the first time a food was shown (the mesh had not
  downloaded yet); the same foods were fine later. Not fixed: preloading the food templates would fix it.
- BUG FOUND AND FIXED: the thrown food was `ScaleTo(1.7)` absolute, but `install_foods` sized each template
  with ScaleTo (template scales 0.37 to 0.70; only the dango is 1.04), so 50 of 51 foods flew and landed 2 to
  4.5 times their size (the swirl fruit was ~10 studs; the "landing close-up bowl too large" note). Now
  ThrowController keeps the template's own scale in the hand and grows to 1.7 x that over 0.25 s after the
  release (and snaps to it on landing, so a skipped flight still lands at flight size for the pick-up).
- Flight, measured on all three styles: pitch (swirl fruit) tumbles, spin (dango) turns end over end on one
  axis, heave (Warrior's Feast) is level in the hand, leans 22 degrees and turns slowly; all land upright.
  The hero holds the fruit at a believable size; the catch card shows "LOVES <dish>".
- Weakest models seen in the game: Officer's Ham (dark, dull), Healing Squid Ink Pasta (dark blob), Meat on
  the Bone; the Warrior's Feast reads as plain stacked cups in the landing close-up. The "YOUR SPOT" sign
  stays up while the player stands on the spot.

### 2026-11-27: phase C, throw feel (effects, sounds, the food in the hands)

What a throw is now, by the dish's role (`src/client/Fx/FoodFx.luau` decides, nothing else):

| | Flight | Landing | While it rests | Sound |
|---|---|---|---|---|
| Snack | `ThrowTrail_Basic`, in the dish's own colour | `Land_Impact` | none | the dish's landing class |
| Meal | `ThrowTrail_Meal` (streak + sparks that ride with the food) | `Land_Meal` (pop, dust, ring, aroma wisps) | `Aroma_Meal` | the same |
| Signature | `Sig_<id>_Trail`, its own effect | `Sig_<id>_Land`, its own effect with a pillar in the dish's colour | `Aroma_Signature` | + `sig_sting` and its own accent |

- **The 17 Signature effects** are built from the dish (table in 4.3): `assets/vfx/builders/build_food.py`,
  textures of their own in `assets/vfx/tools/make_food_tex.py` (fish-cake slice, gold "1", chain ring, the
  katakana sound-effect glyph, sugar cube, aroma line, light column).
- **Measured, and it decides how a flight effect must be built:** the food flies 125 to 2,100 studs a second
  with the camera 15 studs behind it. Anything left in the world is behind the camera within a frame, and a
  texture on a Trail never reads (only its first 15 studs are in view). So ribbons give colour only and
  everything that says what the dish IS rides with the food (`LockedToPart`, streaming out of its back, born
  2.2 studs behind its centre so it sits below the food on screen and never covers it).
- **Judged in the game, not only in the simulator.** `tools/studio/foods/fx_judge.luau` (client datamodel of
  a play session) flies a food in a loop with the game's chase camera, lands it and freezes every particle at
  a chosen moment under the game's landing camera. All 17 flights and all 17 landings were looked at this
  way at graphics level 21. What only the game showed, and was fixed:
  - soft "glow" and "hot" flame sprites fuse into a pale yellow cloud at this size (Flame Bento, Mapo Tofu,
    Warrior's Feast landings): rebuilt on hard-edged cel flames and the comic-pop flipbook;
  - a dark pulse behind the fruit on a dark floor read as nothing (Swirl Fruit): rebuilt as the fruit's own
    spiral, behind it and flat on the floor;
  - a flipbook shockwave laid flat drew as a broken arc (Crab Hot Pot): two sprite rings instead;
  - beam strips used as particle textures came out as blocks (Captain's Curry): brush-stroke sprites;
  - dark green feathers vanished on the green lane (Officer's Ham): lighter greens.
- **Effect textures were never preloaded** (`VfxKit.preload` existed, nothing called it): the first play of
  any effect drew nothing until its textures arrived. `Vfx.preload()` now runs at join; the food models are
  preloaded too (the blank "NEW FOOD!" cards of the phase B check).
- **The dish's own colour** (`src/shared/Config/FoodFeel.luau`, GENERATED by `tools/gen_food_feel.py` from
  `design/foods.json` + the food icons): the dominant hue of the icon; tints the Snack and Meal trail, the
  Meal landing and the aroma. A dish with almost no colour (rice ball, daifuku) gets warm cream.
- **Sounds:** 24 new roles (3 throw, 6 landing classes, a Signature sting, 12 accents, the favourite
  jingle, the food appearing in the hand). I cannot hear: each candidate's LOUDNESS CURVE was measured in a
  play session (`Sound.PlaybackLoudness`, 20 samples a second) and the pick is the one with a fast attack and
  one clean event; `SoundController` skips each clip's lead-in (`STARTS`) and fades it after its event
  (`CAPS`); volumes are evened from the measured peak. NOBODY HAS LISTENED TO THEM: the owner's first
  listen decides the swaps (one line each in `assets/sfx/manifest.json`, then emit_bank). Thirteen are from
  uploaders that are not Roblox-licensed libraries (food_ready, sizzle, steam, fire, blast, gold, wind,
  shatter, magic, electric, water, spirit, favourite): free Creator Store audio, but the rights rest on the uploader.
- **A landing is as heavy as the dish:** the owner's rock-and-crack impact, the boom and the camera shake
  scale with `FoodFx.weight` (a Snack half, a Signature feast full).
- **The favourite dish:** `Favourite_Burst` (hearts round the hero) and the favourite jingle at the reveal;
  after its bites the hero cheers (IdleCheer) instead of going back to its idle.
- **Other players' view** (`ThrowController:_watch`) had two bugs: the food was moved by `Position` (which
  re-welds the carrier and leaves the model behind) and never got its flight size or turn. It now flies the
  same effects and lands with the dish's own landing, smaller and silent.
- **The food in the hands:** on the throw spot the player holds the food the next throw will use
  (`ThrowController:_tickHeld`, `Fx/FoodHold`), in a hold pose for its throw class, and the throw is the
  class's own clip (`FoodFx.clips`): pitch = Throw, heave = ThrowHeave, spin = ThrowSpin. A clip that is not
  in the place falls back to Throw. The aiming camera is BEHIND the player, so the holds are built to read
  from behind: a bowl is carried overhead, a disc out to the right.
- **The five new clips** (animations batch r7, `tools/anim/clips_r7.py`, uploaded): HoldPitch (the food on
  the upturned right hand beside the head), HoldHeave (the bowl overhead in both hands), ThrowHeave (an
  overhead throw-in, Release 0.7667), HoldSpin (flat out to the right, arm cocked), ThrowSpin (a side-arm
  sling, Release 0.7). Seen in play from the aiming camera and frozen from the side: the bowl stays level
  between the hands through the arch-back and the release; the food keeps the size of `design/foods.json`
  (`FoodHold` places it from the hands and the real model's size, always level by the world: taking the
  pizza's up from the hand's own axes showed its underside on a real avatar). Known rough spots of the clips
  (the author's own list): at ThrowHeave's Release the palms sink 0.1 into the stand-in bowl; ThrowSpin's
  forearm passes 0.3 into the chest for four frames.
- **A flat spin food flies like a frisbee** (`disc`: a spin food under half as tall as it is wide: pizza,
  toast); a skewer or a banana still flips end over end.
- Not done in this phase: the hold poses are full-body Action clips, so a hero carried on the shoulder and a
  hold cannot play together (the game never does both: no throw spot while carrying). Nothing was tried on a
  phone (phase F).
- Retired: `ThrowTrail_Hot`, `ThrowTrail_Epic` (nothing uses them). New gate step: `gen_food_feel.py --check`
  (the table is current, and every Signature dish has both effects and every sound role it names).

Checkpoint: commit `3f88e12` (phase C) = place version 939 (saved 2026-11-27, not published, not pushed).

### 2026-11-27: phase D, the training framework and grounds 1 and 2

![phase D](img/13-phaseD-grounds.jpg)

**What training is now.** A base has two courts; each shows one training GROUND, a whole set piece
(`Core/Grounds`: the two newest the owner has opened; before the first rebirth the second court shows the
Waterfall chained off under a board "LOCKED / REBIRTH 1"). The old round mats, the gear anchors and the eight
gear models are archived (`MapArchive.TrainingCourts_v1`, `MapArchive.Gear_v1`).

| | Striking Post (start, left court) | Waterfall Focus (rebirth 1, right court) |
|---|---|---|
| The game | a ring closes on the gold ring: TAP as it lands, once a second | a disc swells out to the gold ring: HOLD, let go on it, every 3 s |
| Tiers (look) | Wooden Post, Banded Post, Iron Post (tiers 1 to 3) | Mountain Falls, Shrine Falls (tiers 4 and 5) |
| Level II adds | a war drum, two banners, a sacred rope on the wall | a sacred rope with streamers across the falls, two lit lanterns |
| Level III adds | two burning braziers, a gold crest ring in the deck | lotus lanterns afloat, spirit lights off the water |
| Awakening | a flurry, the post shakes and glows, then bursts into splinters and a new one rises | the falls part and run upward round a column of light, then crash back |
| Camera | side-on, 9 studs, closer and lower when awakened | straight on from the front, back and up when awakened |

- **The framework** (one set of numbers for every ground, as section 5.1 asked):
  - `Core/Beat` got the held beat (`gradeHold`: the release is graded, a hold shorter than the ground's
    `MinHold` is a miss, so tapping fast cannot stand in for holding), Focus by beat length (`focus`: a 3 s beat
    carries 3 reps and 3 times the Focus, so every ground awakens at the same rate), `upcoming` (the beat to
    play and how far the ring has come) and `clipAt` (below). `Core/Grounds`: which grounds a base shows and
    the tier and level each is drawn at. Spec `tests/Grounds.spec.luau` (9 cases; 145 specs pass).
  - **The clip keeps time.** A beat is jittered, so a looping clip drifts off it. `Beat.clipAt` gives, for any
    moment of a session, where the clip should be and how fast it should run so that its reps (config `Marks`)
    fall ON the beats; `TrainingController:_sync` sets the speed between every two beats and corrects drift. The
    fist lands as the ring does; the breath is let out on the gold.
  - Server (`TrainingService`): a session belongs to a court; the stand point and facing come from the set
    piece's `Stand` part; a held game sends hold-begin and hold-end and the server grades the release; the
    character carries `TrainPlot`, `TrainCourt` and, while awakened, `TrainAwake` (the server time it ends).
  - Everyone sees it (`Controllers/GroundController`): from those attributes alone every client plays the
    ground's awakening on that plot's set piece, with the aura on the trainee. The trainee's own client adds the
    reps (the beats are known only to it and the server).
  - HUD (UI v5.2, `tools/ui/screens_v52.py`): a Focus bar under the ring (gold and running down while
    awakened), the breath disc in the ring, the instruction over the ring ("HOLD", then "LET GO IN THE GOLD").
- **The set pieces** (`tools/studio/grounds/`): 15 generated pieces (three posts, two cliffs, the seat stone, the
  notice board, weapon rack, straw dummy, war drum, brazier, stone lantern, lotus lantern; kept in
  `StoreAssets.Grounds`) + part-built walls, decks, kerbs, ropes, banners and the lock. `ground_lab.luau` gathers
  and squares generated pieces, `build_grounds.luau` (through `run_build.py`, which passes the effect texture
  ids) builds `Assets.Grounds.Ground_<id>_T<tier>` and a small `Show_<id>_T<tier>` for dialogs, `court_setup.luau`
  prepared the five bases, `preview.luau` stands two templates on a base for a look. The waterfall is two Beams a
  side (a streaked sheet and faster foam, the game's own textures) pouring over the lip, with spray, a splash
  flipbook and mist at the foot; the notice board carries the ground's name, the gear the owner trains on and
  the next upgrade, and holds the Upgrade prompt.
- **Effects** (`assets/vfx/builders/build_train.py`, 10 effects, 4 textures of their own): the rep, the PERFECT
  critical over it, the flurry, the breath's rings, the awakening burst and aura (tinted with the ground's
  energy: gold for the post, cyan for the falls), the post's burst and rise, the falls' column and crash.
  Judged in the game with `tools/studio/grounds/fx_judge.luau`; what that fixed is in `assets/vfx/README.md`
  (flame sprites must not be velocity-parallel; a critical must start gold; lamps and halos on pale rock white
  the court out at max graphics).
- **Sounds:** 14 new roles, all from Roblox-licensed libraries this time (ProSoundEffects, APMOfficial), picked
  from measured loudness curves (`tools/studio/sfx_probe.py` -> `work/sfx/probe_d.json`, 116 candidates);
  lead-ins and caps in `SoundController`. The waterfall is heard in the world (`falls_loop` on every pool).
  NOBODY HAS LISTENED TO THEM (as in phase C): the owner's first listen decides the swaps.
- **The five clips** (animations batch r8, `tools/anim/clips_r8.py`, uploaded): TrainPost (makiwara practice
  from a front stance: a right reverse punch and a left lunge punch, Hit at 0.5 and 1.5 s), PostFlurry (six
  punches a second, leaning in), PostFinish (wind-up, then one blow 0.4 studs through the post; its first frame
  is the flurry's and its last the loop's, so nothing pops), TrainBreath (seated: the hands rise up the centre
  line through the inhale, turn over at the Pulse, press down) and BreathAscend (floating cross-legged, arms
  open). The post's face is 2.87 studs in front of the trainee (config `Contact`; the set piece's stand point is
  placed from it): the first pass at 2.47 gave a short, bunched punch and was redone. The author's own list of
  rough spots: PostFinish goes 0.4 through, not the 0.6 asked for; TrainBreath's hands meet side by side, not
  cupped (the rig has no forearm roll); the seated legs are the old TrainMeditate fold (they sink 0.4 into the
  seat); the back shin of the post stance dips 0.2 under the floor.
- **Played in Studio** (a fresh save; an auto-player that fires `TrainTap` exactly when the HUD's ring lands):
  - Striking Post: the capture caught the right fist on the rope pad with the hit burst on it and the ring on
    the gold in the same frame: the clip is in time. 20 Perfects filled Focus; the awakening ran 8 s (flurry,
    aura, hit storm, the post shaking and glowing, closer camera). A log of its end, ten samples a second:
    PostFinish starts 0.46 s before the end, its blow lands at +0.04 s, the post is gone at +0.08 with
    `Post_Burst`, `Post_Rise` at +0.5 and the new post is home by +0.95; the loop resumes in time.
  - Waterfall Focus (rebirth 1): seated on the stone, hands at the chest, the falls behind; 7 perfect breaths
    awakened it; the hero floats, the falls stand apart either side and water runs up the gap.
  - Buying a gear level swaps the set piece (`1/1/1` -> `1/1/2`: drum, banners, rope appear), the "NEW GEAR!"
    card shows, the board reads the new level; the locked Waterfall opens on the first rebirth.
  - Two bugs this found and fixed: a blow landing while the new post was still rising took that height for the
    post's place and left it 0.3 studs up (the server now writes the centrepiece's rest pose on it, clients put it
    back there); the final blow's lens push could freeze the camera at the awakened shot's lens (the push now
    returns to the shot's own lens, and the camera's move and lens are separate tweens).
- **Not done, not verified:** nobody has PLAYED it by hand (the taps were fired by a script on the beat; real
  hit rates, the feel of the windows and of the 3 s breath are the owner's to judge, as section 9 said); the
  sounds are unheard; nothing was tried on a phone; other players' view of an awakening was not watched from a
  second client (it is built from replicated attributes only); the post's burst itself was seen frozen with the
  judge tool and in the log, not in a live capture (a capture takes seconds); max-graphics captures of the
  awakenings were cut short by the PC running out of memory (the last ones were at Studio's automatic level).
  Grounds 3 to 8 are phase E: a player past rebirth 1 still sees the Waterfall and, from rebirth 2, an empty
  left court until Boulder Breaker is built.
- **Traps found:** an Attachment's `WorldCFrame` set before it has a parent is taken as its local CFrame (the
  falls stood 13 studs up in the sky); a Beam's width lies along its attachments' Y, not Z (the sheets stood
  edge-on); a textured generated mesh cannot be tinted by `Color` (the "river rocks" came near-white: the seat
  stone is used for them); `VirtualInputManager` is not open to `execute_luau` (the auto-player of the play
  tests fires `TrainTap` when the HUD's ring lands instead); Studio crashed twice when the PC ran out of memory
  with another heavy app open (Team Create kept everything; relaunch with
  `RobloxStudioBeta.exe -task EditPlace -placeId 106586376894468 -universeId 10776373502`).

Checkpoint: commit `224c9e1` (phase D) = place version 954 (saved 2026-11-27, not published, not pushed).

### 2026-11-27: phase E, pair 1: Boulder Breaker and Thunder Peak (grounds 3 and 4)

![phase E, pair 1](img/13-phaseE-pair1.jpg)

| | Boulder Breaker (rebirth 2, left court) | Thunder Peak (rebirth 3, right court) |
|---|---|---|
| The game | `sweep`: a needle runs along a meter; TAP as it crosses the gold zone, every 2 s | `reflex`: lightning marks one of three rods; tap THAT rod before it strikes, every 2 s |
| Input | tap, Space | the three rod buttons, A / S / D, the arrow keys, or that third of the screen |
| Tiers (look) | Granite Boulder, Obsidian Boulder (tiers 6, 7) | Storm Peak, Thunder Peak (tiers 8, 9) |
| Level II adds | a sacred rope round the rock, a stone fist, two banners | the thunder drums, two storm crystals |
| Level III adds | two braziers, a gold crest ring | three lit crystals, a ring of light round the summit |
| Awakening | a barrage, the boulder shakes and glows, shatters, a new one drops from the sky | lightning strikes the rods again and again and arcs to the hero, then one enormous bolt |
| Extra | cracks spread over the rock's face as Focus fills | the marked rod crackles; a caught bolt runs from the rod's tip into the hand |

- **Rules** (`Core/Beat`): `lane` (which rod a beat falls on: the beats are dealt in shuffled hands of three, so
  every rod gets its exact share and none comes more than twice running; the first version, a hash with a
  patch for runs, still gave three in a row and a spec caught it) and `gradeReflex` (the right rod within
  `React` 0.55 s of the mark is Perfect, any later before the strike Good; the wrong rod, a guess before the
  mark, or after the strike is a miss). The sweep is the ring's judge with another picture. 147 specs pass.
- **Server:** a reflex session carries `lanes`, `lead`, `react`; `TrainTap` takes the lane as a number.
- **Client:** `TrainingController` picks the picture by the ground's game (ring, breath disc, sweep meter, rods),
  plays the answer clip over the waiting loop, and now RE-TAKES the camera if something else hands it back to
  the player mid-session (found in the play test: a rebirth cinematic ending set it to Custom).
  `GroundController`: one table (`STRIKE`) drives every ground where a blow lands on a target (post, boulder):
  what plays for a rep, through the awakening, and whether the new target rises or drops; `Mark` (the rod's
  tip), `Focus` (the cracks), the bolt from rod to hand (a copy of the set piece's `Arc` beam, alive for a blink).
- **UI v5.3** (`tools/ui/screens_v53.py`): `SweepMeter` (Needle, Sweet, SweetCore) and `Rods` (Rod1..3, each
  with a `Mark` ring inside its face) in the ring's place.
- **Set pieces:** 15 more generated pieces (two boulders, quarry wall, crane, lifting stones, rubble, stone fist;
  summit rock, two kinds of lightning rod, storm crystals, thunder drums). The storm cloud is built of matte
  charcoal balls: the generator made it sky blue twice, and shiny black balls read as balloons.
- **Effects** (8, `build_train.py`): `Boulder_Hit`, `Boulder_Barrage`, `Boulder_Shatter`, `Boulder_Land`,
  `Peak_Strike` (a bolt from the sky as two beams that flicker twice), `Peak_Catch`, `Peak_Storm`, `Peak_Finale`;
  one new texture (`bolt_strip`). **Sounds:** 12 new roles, all ProSoundEffects, from 92 measured candidates
  (`work/sfx/probe_e1.json`); no mountain-wind ambience (only individual uploaders had one).
- **Clips** (batch r9, uploaded): TrainBoulder (two heavy palm blows 2 s apart), BoulderBarrage, BoulderFinish (a
  double palm thrust; the boulder shatters on it), PeakReady, PeakLeft / PeakMid / PeakRight (a 4-frame thrust of
  one hand toward the rod, held with a tremor), PeakStorm (arms in a V). The author's rough spots: a sideways
  arm raise is limited by the rig's shoulder, so the side catches go forward and out at about 45 degrees and
  PeakMid's hand is over the right shoulder, not centred; palms touch 0.01 to 0.03 into the rock.
- **Played in Studio** (auto-players that answer when the HUD shows the moment): the sweep filled Focus with
  10 Perfects and awakened; a log of the end: BoulderFinish lands at 0, the boulder is gone at +0.07 s, the new
  one falls from +0.5 and lands at +0.93 with `Boulder_Land`, the loop resumes in time. The reflex game
  scored with answers 0.3 s after the mark, awakened, and showed the catch at the hand, the marked rod and its
  ringed button. Seen and fixed: the middle rod stood hidden behind the hero (the camera now stands 3.6 to
  one side), the awakening's lights flooded the summit yellow (cloud light 1.6 -> 0.5, strike lamp 1.2 -> 0.5).
- **Not done, not verified:** as in phase D, nobody has played these by hand, the sounds are unheard, phones
  are untried (three rod buttons of 72 px are the smallest targets so far), and the bolt from the sky was never
  caught in a capture (it lives 0.2 s). Grounds 5 to 8 remain.


Checkpoint: commit `a8184f9` (phase E pair 1) = place version 964 (saved 2026-11-27, not published, not pushed).

### 2026-11-27: phase E, pair 2: Gravity Chamber and Spirit Orb (grounds 5 and 6)

![phase E, pair 2](img/13-phaseE-pair2.jpg)

(Top: the push-up game with a gap in the line; the awakening, gravity turned over; Gravity Core at level III.
Bottom: the orb charging; the awakening; the thrown orb bursting over the court.)

- **Two more games on the same judge.** `rhythm` (Gravity Chamber, 1 s beat): the beats ride a track as notes and
  are tapped as they sit in the gold ring; one beat in every hand of four is a REST (`Rests` 4, `Beat.rest`: never
  the hand's first, so two rests never meet and a session opens on a played beat). A tap on a rest is a slip: no
  pay, and it costs 2 Focus. The played beats pay and fill Focus for the whole hand (`Beat.share`, x 4/3), so the
  ground earns what the others do. `charge` (Spirit Orb, 4 s beat): the falls' held judge with a long hold
  (`MinHold` 2.0): hold to charge, let go in the gold; a hold that began too late shows grey on the gauge.
- **The clip over a rest** (`Beat.clipAt` with `rests`): reps fall only on played beats; over a rest the clip runs
  half the way to the next rep at its own pace, HOLDS there (the top of the push-up) and runs on in time. Specs
  for both.
- **Client.** `TrainingController`: BeatTrack and ChargeMeter pictures (UI v5.4, `tools/ui/screens_v54.py`), a low
  side-on shot for the push-ups, a front shot under the orb, and after the orb is thrown a shot that follows it up
  to its burst before coming back. The grade flashes UNDER the beat track (over it, it hid the notes on every
  beat). `GroundController`: `Contact` for both grounds, `Hold` (the charge is heard), `Charge` (the orb grows
  with the gauge and falls away when let go), the shows `showGravity` (everything in `Floaters` drifts up and
  turns, then drops) and `showOrb` (the orb swells to `OrbAwake`, is thrown 40 studs up, bursts, and a new one
  gathers). The orb rides on the trainee's two palms, read from the hands every frame (the R15 arm reaches only
  2.2 above the root, and the clips move the hands). A piece carries its tier's colour (attribute `Energy`).
- **Studio-only test input.** `Players.LocalPlayer.TrainTestInput` (a BindableEvent made only in Studio):
  `Fire("press", lane?)` / `Fire("release")` go through the controller's own input path, so a scripted play test
  plays the real client (grades, clips, effects), not only the remote.
- **Set pieces** (`buildGravity` tiers 10 and 11, `buildOrb` tiers 12 and 13; nine generated pieces): a steel deck
  with rings of light under a field ring held by four emitter pylons, the gravity generator (tier 11: the gravity
  core) behind, iron weights and plates that fly, a glass readout behind the trainee and on the console (10 / 25 /
  50 G, then 100 / 250 / 500 G by level); a stone dais between four standing stones (tier 13: sun pillars) before
  a shrine, incense, a rope and streamers at level II, spirit lights at level III. Seen and fixed: pale Neon
  blooms to white at once (every Neon part now takes a saturated colour of its own, `neon` in the spec); a Neon
  ball draws as a flat disc (the orb is a lit ball under a glowing shell); the far pylon on the camera's side and
  the notice board stood in the awakened shots (pylons moved out, the orb's awakened camera crosses the walkway).
- **Effects** (six, 87 in all): `Gravity_Pulse`, `Gravity_Flip`, `Gravity_Float` (loop), `Gravity_Slam`,
  `Orb_Release`, `Orb_Burst`, all tinted by the piece. A new texture `tfa/speed_line`: the library's streak is
  drawn lying at 20 degrees, so particles falling or rising straight (VelocityParallel) showed as rows of sideways
  dashes; the new line is drawn upright in a SQUARE image (a narrow image came out a fat cone: a particle is
  always square).
- **Sounds** (eleven, 139 roles, all ProSoundEffects, picked from measured curves in `work/sfx/probe_e2.json`):
  gravity_pulse, gravity_perfect, gravity_hum (heard from the court, like the falls), gravity_flip, gravity_slam,
  orb_charge (2.5 s, played at 0.7 speed so it rises through the charge), orb_release, orb_perfect, orb_loop,
  orb_throw, orb_burst.
- **Animations** batch r10, uploaded: TrainPushup 122314366779681, GravityFloat 118935430592079, TrainOrb
  115401504923373, OrbAwaken 106871952864981, OrbThrow 120378684758693 (hand-off and numbers:
  `work/anim/upload10/README.md`).
- **Played in Studio** through the test input: the push-up auto-player tapped every note in the ring and left the
  rests, Focus filled in about 20 s, the hero floated with the weights and the readout behind; the orb player
  held from the bottom of the gauge and let go in the gold: five Perfects to an awakening, the orb swelled, was
  thrown, burst in the sky shot and a new one gathered; the cadence was the same over three rounds.
- **Not done, not verified:** nobody has played these by hand, the sounds are unheard, phones are untried, and a
  second client's view is untried. (The captures were taken at graphics level 21: Studio's quality had been left
  there; it is back on Automatic.) The gravity slam and the release
  pulse were never caught in a capture (they pass in under half a second); they were judged in the simulator
  strips only. Once, a capture showed the word AWAKENING! two seconds after an awakening had ended; a frame-by-
  frame log of two more rounds did not show it again. The push-up's elbows read weakly in pure profile and the
  float is a little stiff (the animator's own notes). Grounds 7 and 8 remain.

Checkpoint: commit `c4d74da` (phase E pair 2) = place version 972 (saved 2026-11-27, not published, not pushed).

### 2026-11-27: six grounds, not eight (owner's decision)

The owner, after pair 2: "let these many games be there. don't add more ... lets keep only 6. distribute them
accordingly." Titan Chains and Timeless Hall (grounds 7 and 8 of section 5.2, never built) are dropped; phase E
ends here. What changed:

- **The 19 gear tiers are shared out 3 / 3 / 3 / 3 / 3 / 4** (`tools/economy/econ_v3.py` `GEAR_GROUND`); prices
  and Power per rep did not move, only which ground a tier belongs to and what it is called:

  | Ground | Opens at rebirth | Tiers | Looks |
  |---|---|---|---|
  | Striking Post | 0 | 1 to 3 | Wooden Post, Banded Post, Iron Post |
  | Waterfall Focus | 1 | 4 to 6 | Mountain Falls, Shrine Falls, **Dragon Falls** |
  | Boulder Breaker | 2 | 7 to 9 | Granite Boulder, Obsidian Boulder, **Magma Boulder** |
  | Thunder Peak | 4 | 10 to 12 | Storm Peak, Thunder Peak, **Heaven's Peak** |
  | Gravity Chamber | 5 | 13 to 15 | Gravity Room, Gravity Core, **Singularity** |
  | Spirit Orb | 7 | 16 to 19 | Spirit Orb, Sun Orb, **Star Orb**, **Galaxy Orb** |

- **A ground opens at the rebirth tier in which its first gear tier's world is reached** (0, 1, 2, 4, 5, 7; it
  was one per rebirth). So the ground the owner's gear belongs to is always one of the two a base shows: a spec
  checks it for all 57 gear rows. Rebirths 3 and 6 open no new ground (the gear moves to the ground's later tiers).
- **Six new tier looks** (the bold names), five new generated pieces: stone dragons that spout into the pool, a
  dark lava-cracked boulder (third try: the first came pale with craters, the second as a stepped cone), golden
  dragon rods, a singularity engine (tinted: its cradle came cream), star and galaxy pillars with a blue and a
  violet orb. The builder now clears every old template first and builds all 19 tiers (38 templates with the card
  models); the tier numbers of grounds 3 to 6 moved (Ground_boulder_T7..T9, peak T10..T12, gravity T13..T15, orb
  T16..T19).
- **Checked in a play session:** stepping a test save through worlds 4, 6, 9, 10, 13, 16 and 17 showed post +
  falls (locked, then open), boulder + falls, boulder + peak, gravity + peak, gravity + orb. The new tiers were
  looked at standing on a base in edit mode; none was trained on (they are the same builders as the tiers that
  were).
- **Not done:** as before, nothing here has been played by hand, heard, or tried on a phone or with a second
  client. Phase F (the full playtest and tuning) is what is left of plan 13.


Checkpoint: commit `5f76005` (six grounds, phase E closed) = place version 974 (saved 2026-11-27, not published, not pushed).

### 2026-11-27: phase F, the playtest. Snapshot NOT taken: it waits for the owner's sign-off.

- **Pacing gate** (`econ_v3.py check`): every target met (zone 3 at 11m33s, rebirth 1 at 28m42s, rebirth 4 at
  7h01m, rebirth 7 at 24h12m, zone 17 at 27h43m); the six-ground share-out moved no price.
- **The whole game in order, through the real remotes, on a wiped `Profiles_Dev_v3` save** (harness in the
  session scratchpad: the server stands the character on its throw spot, the client fires ShopBuy, ThrowPad,
  ThrowRequest, ProgressAction and AdminCommand `zone` / `yen` / `rebirthready`, and a hook logs StateSnapshot,
  ThrowResult and Toast). For each of the 17 worlds: its three foods, its gear rows and its slot bought through the
  shop; a throw "as far as it goes", one aimed at world 1 and one aimed past the seal. 417 s for all 17, then
  rebirths 8 to 10 and the last six gear rows.
  - Every "as far as it goes" throw landed in the world just reached; every throw aimed at world 1 landed there
    (depth 1, the most depth luck); every throw aimed past the seal was held to the last open world. The auto-pick
    threw that world's Signature dish every time (51 foods, 17 cookbooks, a Lucky Throw for each).
  - All ten rebirths: the real REBIRTH button refused without the fee ("Rebirth needs a throw of 30K power and
    2.5M yen" ... "5Sx power and 1.4Sp yen"), then reset Power (to 10) and Yen only and kept heroes, gear, foods,
    slots and the best world, +3 Lucky Throws each. (After rebirth 6 the Yen read 8.6T, not 0: the income of 39
    heroes during the 9 s cinematic.) An 11th rebirth says "You are at the highest rebirth", a 58th gear "maxed".
  - The courts at each step: post + falls (locked) -> post + falls -> boulder + falls (rebirth 2) -> boulder + peak
    (4) -> gravity + peak (5) -> gravity + orb (7); the ground the gear belongs to names it and its level on its
    board (Wooden Post III ... Galaxy Orb III), the other says the gear's Power per rep.
- **All six grounds played** at their new top tiers through the Studio test input (an auto-player that reads the HUD
  of every game): Galaxy Orb, Singularity (12 Perfect, an awakening), Magma Boulder (17 Perfect, an awakening),
  Dragon Falls (10 Perfect, an awakening), Heaven's Peak (16 Perfect, 1 Good, an awakening), Gravity Room, and the
  Striking Post on a fresh save (32 Perfect, an awakening).
- **FIXED, seen in those sessions:** the Singularity at 1.3x stood behind the beat track (now 1.1x like the other
  machines); Boulder Breaker's level-III brazier on the camera's side stood big in the right of the shot (both
  braziers now on the far side); Thunder Peak's level-II drums filled the bottom right (moved back beside the
  crag); Dragon Falls' spouts were strings of beads (now arcs of the falls' own water with a splash). The Rebirth
  page now names the training ground a rebirth opens ("Opens Clover Kingdom + Boulder Breaker"), as section 7 of
  this plan said it would; seen in the game on the PC.
- **Phones** (Studio Device Simulator, Galaxy A06 705 x 338): the beat track, the charge gauge and the rod buttons
  fit with the hint and the Focus bar. The rod buttons are 34 px there (under the usual 44 px), but a tap anywhere
  on that third of the screen answers for that rod. Roblox's thumbstick ring still sits over the Power / Yen / Luck
  stack. The Rebirth page could not be opened on the simulated phone (scripted clicks miss there, as in plan 12).
- **Frame rate: NOT measured.** In this Studio play test (server and client in one process, scripted calls) the
  hub alone ran at 26 fps and a Gravity Chamber awakening at 15 to 24, worst frame 69 ms either way: Studio is the
  limit here, not the grounds. A real phone is needed.
- **For the owner to decide (economy, not changed):** in world 13 the longest stretch with nothing to buy is about
  an hour (`econ_v3.py cadence`): the Crab Hot Pot (1.9Qi) and gear 13.3 (1Qi) cost more than world 14's first
  dish (1.3Qi) and gear (960Qa), and the 2.3Qi rebirth fee falls there. And gear 19.1 (190Sx) costs less than 18.3
  (230Sx).
- **Not done:** nothing was listened to; nothing was played by hand; a second client's view of the awakenings is
  untried.
