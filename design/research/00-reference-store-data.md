# Reference game: hard data from Roblox's public APIs (pulled 2026-11-14)

Source endpoints (unauthenticated, read by `curl`):
`apis.roblox.com/universes/v1/places/120219252362013/universe`,
`games.roblox.com/v1/games?universeIds=10766972131`, `games.roblox.com/v1/games/votes`,
`apis.roblox.com/game-passes/v1/universes/10766972131/game-passes`,
`apis.roblox.com/developer-products/v2/universes/10766972131/developerproducts`.

## Identity and scale

| Field | Value |
|---|---|
| Name | Throw Food For Animals |
| Universe / root place | 10766972131 / 120219252362013 |
| Creator | group "Goofy Chupacabra" (670988975), not verified |
| Created | 2026-09-18 (8 weeks old on the pull date) |
| Last updated | 2026-11-14 (updated the day of the pull: live-ops is daily/weekly) |
| Playing now | 426,424 |
| Visits | 215,230,425 |
| Favourites | 214,979 |
| Votes | 112,693 up / 6,672 down = 94.4 % |
| **Max players per server** | **5** |
| Avatar type | MorphToR15 |
| Genre | Simulation / Tycoon |
| Private servers | not allowed |

Own description of the loop (paraphrased): throw food as far as you can; attract and collect
animals from different areas; earn money from them; buy better food to attract rarer animals;
train on pull-up stands for Throw Power; reach new areas with stronger, rarer animals.

## Gamepasses (2)

| R$ | Name | Effect |
|---|---|---|
| 99 | x2 Cash | double cash from every animal, forever |
| 149 | x2 Training Power | double XP on every pull-up, forever |

Both are also sold as **giftable developer products** at the same price.

## Developer products (50), grouped

**Throw power, bought directly:** Pack 1 +5 (2 R$), Pack 2 +30 (9), Pack 3 +150 (39), Pack 4 +500 (99).

**Training time skips** ("instantly get the strength of N minutes of training"):
2 min (39), 5 min (39 and 99: two SKUs, price test or tiered by progress), 15 min (99 and 179),
30 min (179). Plus "2x Training Boost (30s)" (49).

**Money time skips** ("as much as your animals make in N"): 3 min (24), 18 min (59), 90 min (79),
5 h (199). Scales with the buyer's own income, so it never goes stale.

**Lucky throws** (consumable, banked, used on demand): Super Lucky Throw x1 (9), x3 (27),
x5 (39), x10 (69), x35 (299), x50 (299), x60 (499), x100 (499). Two descriptions exist:
"best of 30 rolls each" and "100x luck", i.e. the mechanic was re-tuned and both SKU sets remain.

**Server luck** (benefits everyone in the server, stacks in steps, +15 min each):
1x→2x (19), 2x→4x (39), 4x→8x (79), 8x→16x max (159).

**Offline:** 2x Offline Earnings (49 in the API; the popup in the screenshot showed 19, so the
price is varied by amount or A/B tested).

**Eggs (paid random items)**, placed on the plot to hatch:
Enchanted Egg x1 (79 / 99), x3 (199 / 249), x10 (649 / 799): "up to 1200 % of your best animal".
Screenshot odds: 40 / 27 / 18 / 10 / 4 / 1 % for 110 / 175 / 250 / 350 / 550 / 1200 %.
Rainbow Egg x1 (99), x3 (249): Rainbow mutation + Giant size guaranteed.
Magma Egg x1 (60), x3 (150). Halloween Egg x1 (80), x3 (200): "up to 900 % of your best animal".

**Direct-purchase animals:** Woolly Mammoth (199, "150 % of your best animal"), Giant Squid
(299, 300 %), Pumpkin Monster (499, Halloween, 900 %), Jellyfish (40, $7.5M/s), Fenrir (156,
$100B/s), Velociraptor (4,400, $150T/s), Hydra (12,000, $10Qi/s). Ultra Pack (640): $60Qi cash
+ two animals.

## What this tells us (design reading, mine)

1. **Income scaling is relative.** The best-selling shape is "N % of your best animal" and
   "N minutes of your income". A purchase is never obsolete and never needs re-pricing.
2. **Luck is the main lever**, sold three ways: per-throw consumables, server-wide timed boosts
   (social pressure, visible to 5 players), and food tier (soft currency).
3. **Strength is sold both as flat power and as time skips**, plus a permanent 2x pass.
4. **Tiny servers (5)** keep every plot visible and make server luck feel personal.
5. **Only two gamepasses.** Almost all revenue design is consumable products.
6. Whale SKUs exist (4,400 and 12,000 R$) as anchors.
7. Live-ops: seasonal egg + seasonal direct animal within 6 weeks of launch.
