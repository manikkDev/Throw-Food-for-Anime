# 01 - Reference game: "Throw Food For Animals" (Roblox place 120219252362013)

Research date: 2026-11-14. Desk research only (web pages + public Roblox APIs). Nobody played the game for this file.
The game changes weekly (Saturday updates), so every number below is a snapshot; the snapshot date is given where the source states one.

## How to read this file

Confidence tags used on every fact:

- **[C2+]** confirmed by two or more independent sources (or one source plus arithmetic that reproduces numbers printed in a different source)
- **[S1]** single source
- **[INF]** inferred by me from other facts (the reasoning is given)
- **[USER]** from the owner's own screenshots (given in the brief), used only to cross-check

Sources are cited inline with a short key in brackets. The key table with full URLs is at the end ("Sources opened"). Pages that blocked direct fetching are marked there.

Important caveat about source quality: most fan sites for this game are thin SEO pages that copy each other. The three sources that carry real data are (a) the public Roblox APIs, (b) game.guide (appears to be data-mined: it prints formulas, stud positions and odds that other sites do not have, and its formulas reproduce numbers shown in unrelated screenshots), and (c) allthings.how articles (written from real play screenshots with HUD text quoted). Where game.guide is the only source the tag is [S1] even though it looks reliable.

---

## 0. One-paragraph summary of the game

A 5-player-server idle/tycoon. Each player has a fenced plot at the head of a single very long straight lane (about 8,000 studs at 17 zones; longer since the Nov 7 update). You equip one food, step onto a throw strip, stop a 0-20 timing meter, and the camera follows the food down the lane. Distance = Throw Power (1 power = 1 stud, +5 per training level) + the 0-20 meter bonus. Where it lands picks the zone and how deep in the zone; the equipped food picks which rank of that zone's 8 animals the roll centres on; a mutation roll and a size roll are added; a "1 in N" luck score is shown. The animal goes to your backpack/plot and earns $/s. Money buys the next food (50 foods, each roughly x5-x10 the last), the next pull-up bar (58 bars, each doubles XP per rep), and plot slots (+2 per upgrade, very expensive). There is no rebirth. Monetisation is aggressive: lucky throws, server luck, "% of your best animal" egg pets, time-skip packs, throw-power packs, 2x passes.

---

## 1. The throw

### 1.1 Input and meter

- You must own and **EQUIP** a food first; buying does not equip (except some later foods that auto-equip, e.g. Golden Apple). [C2+] [BX-beginner], [ATH-zones]
- Walk to the throw spot at the edge of your plot: described as a "throwing booth at the head of the runway" [ATH-foods] and a "checkered launch strip at the plot edge" [NC-update]. [C2+]
- Prompts, in order: **"TAP TO ENTER!"** (step into the throw zone) then **"TAP TO THROW!"**. [S1 for "TAP TO ENTER!": ATH-luck; C2+ for "TAP TO THROW!": ATH-foods, NC-update]
- When your avatar enters the throwing zone a vertical bar with a moving arrow appears; you tap/click once to stop it. [C2+] [SK-luck], [GGG-beginner]
- The meter runs **0 to 20**. The value you stop on is added to your throw as bonus power for that throw only ("+17 POWER", "+18 POWER GREAT!", "+19/+20 PERFECT!"). [C2+] [GGG-beginner], [ATH-foods], [ATH-zones], [TFA-timing]
  - PERFECT! = stop in the green top segment = +19 or +20 [ATH-zones]; another article says +18 to +20 [ATH-next]. GREAT! = +15 to +18 [ATH-luck] / "+17 or +18" [ATH-zones]. Sources disagree by one point on the band edges.
- It is a **single timing tap**. No source describes hold-to-charge, aiming, or direction control. The lane is straight. [INF from every guide describing only the tap]
- A **"Details" button** is visible only while preparing a throw; it shows your current mutation chances. [C2+] [GGG-mut], [SK-mut]
- A **Super Lucky Throw** button sits top-left during throw prep (paid, see section 10). [S1: YouTube comment on YT-vindooly; consistent with SK-sizes "appear when you step into the throwing area"]

### 1.2 What decides distance

- **Throw Power is measured in studs.** Formula: `studs = 18 + 5 x (level - 1)`, i.e. 18 at level 1, +5 per level. [S1 formula: GG-calc; the "+5 Throw Power per level" part is C2+: ATH-foods, ATH-zones, BX-luck, ATH-aa]
- The meter adds up to **+20 studs** on top. It affects distance only. [S1: GG-catch; consistent with all "+N POWER" popups]
- Cross-check [INF]: game.guide's "unlock level" for each zone equals the level at which a perfect throw reaches the zone start. Savanna starts at 173 studs, unlock level 28: 18 + 5x27 + 20 = 173. Ocean 677 studs, level 129: 18 + 5x128 + 20 = 678. The numbers are self-consistent.
- **Food does not change distance.** [C2+] [BX-foods], [ATH-luck], [GGG-mut]
- Paid: Throw Power Packs add flat Throw Power (+5 / +30 / +150 / +500). [C2+] [API-products], [GG-eggs]
- Admin Abuse "Power Boost" temporarily raises Throw Power. [C2+] [RB-aa], [PGG-aa]

### 1.3 Flight and landing

- The camera follows the food down the lane through each zone. [S1] [ATH-zones]
- A **Luck multiplier** is shown and climbs with distance during flight; a zone banner on landing names the zone and shows the Luck value used for the roll (e.g. "Forest 3.13X"). [C2+] [ATH-foods], [ATH-zones], [SK-luck]
- Luck is not a permanent stat; it exists only per throw. [C2+] [BX-luck], [SK-luck]
- The food lands at `distance` studs; that picks the zone and how deep you are in it. [S1] [GG-areas]

Luck multiplier readings by zone (from screenshots quoted in articles; no formula published anywhere):

| Zone | Luck shown | Source |
|---|---|---|
| Forest | 2.03X-3.72X (also 2.54-3.37) | [ATH-prep], [ATH-luck] |
| Savanna | 4.21X-6.71X | [ATH-luck], [ATH-foods] |
| Desert | 7.12X-9.99X | [ATH-prep], [ATH-luck] |
| Jungle | 10.5X-13.3X | [ATH-luck], [ATH-prep] |
| Ocean | 14.36X-16.57X | [ATH-luck] |
| Mountains | 17.51X-19.44X | [ATH-luck], [ATH-zones] |
| Taiga | 19.23X-20.67X | [ATH-luck] |
| Winter | about 22X | [ATH-next] |
| Prehistoric Forest | 27.48X-27.90X | [ATH-zones] |
| Deep Waters | 28.08X-30.04X | [ATH-zones], [ATH-next] |

A few extra Throw Power levels moved a Taiga landing from 19.48X to 20.67X. [S1] [ATH-luck]

### 1.4 How landing position + food pick the animal

All [S1] from game.guide unless noted; gameboost repeats the rank-cap rule, which makes that rule [C2+].

- Each zone has 8 animals ranked 1 (weakest) to 8 (strongest); Nuclear Wasteland and the two newest zones have 12. [C2+] [GG-home], [RB-animals], [TS-codes]
- **Rank cap by depth:** front third of a zone can only give ranks 1-4, middle third up to rank 6, back third all ranks. [C2+] [GG-areas], [GB-pets]
  - Shadow Realm, Phantom Harbor and Nuclear Wasteland hold their top animal until 90% of the way in. [S1] [GG-catch]
- **Food = "bait level".** Each zone is tuned for three consecutive foods: the first aims at about rank 2, the second about rank 5, the third about rank 8. A food from an earlier zone aims at rank 1. Odds fall off smoothly for ranks further from the aim; ranks above the depth cap are excluded. [S1] [GG-foods], [GG-catch]
- Example: Forest, back third (156 studs), best Forest food: Pony 84.6%, Cow 15.2%, Badger 0.17%, the rest under 0.01%. [S1] [GG-catch]
- With the best food and a back-third landing the top animal of most early zones lands about 78.6% of the time; about 22.5% for Nightmare / Ghost Pirate; just over 20% (21.8%) for Waste Harvester. [C2+] [GB-pets], [GG-animals]
- **Repeat penalty:** your last catch becomes 200x less likely on the next throw and the one before it 2.5x less likely. [S1] [GG-catch]
- How the Luck multiplier enters the animal roll is not documented. Guides say only that higher Luck means rarer results. [BX-luck], [SK-luck]

### 1.5 What happens on landing

- An animal from the landing zone walks toward the food. [C2+] [ATH-zones], [SK-luck]
- A counter cycles through odds ("1 in 3 ...") and settles; rare outcomes are stamped **LUCKY!**, **SUPER LUCKY!**, **INSANE LUCK!** with the final "1 in N". Examples: "LUCKY! 1 in 23", "SUPER LUCKY! 1 in 51", "INSANE LUCK 1 in 48,400". [C2+] [ATH-zones], [ATH-luck], [BX-luck]
- A result card names the animal, its size, its mutation and $/s, with **NEW!** (first time in Index) and **NEW BEST!** (new top earner) tags. [C2+] [ATH-zones], [ATH-luck], [BX-luck]
- Big catches trigger a cutscene with a rising **Score** number; a "tap to skip" prompt exists on at least some arrival scenes. [C2+] [SK-sizes], [ATH-zones]
- Where the animal goes next - sources differ, needs a playtest:
  - "your new animal walks out onto the course near you" and unplaced animals sit in the backpack earning nothing [ATH-zones]
  - you "walk up to the animal that comes to eat and collect it" [ATH-foods]
  - "a completed catch places the animal in the pen at the base plot" [NC-update]
  - generic guides say you "collect them and bring them to your base" [RB-beginner]
- After the first throw a **"Throw again"** prompt sits above the throw booth. [C2+] [ATH-foods], [USER]
- Score arithmetic [INF]: the "1 in N" value looks like 1 / (P(animal) x P(mutation) x P(size)). Diamond is 1 in 25; a top-rank animal at about 79% gives 25/0.79 = 31.6, and articles show "Diamond Fenrir, 1 in 31" [ATH-aa]. Large is 3.5% = 1 in 28.6; /0.8 = 36, and "Large Whale 1 in 36" is shown [ATH-next]. Older (late Oct / early Nov) screenshots show the square of that: Diamond Aardvark "1 in 961" (31 squared), Large Hyena "1 in 1,296" (36 squared), Huge Caracal score 16,641 (129 squared; Huge is 1 in 103, /0.79 = 130) [ATH-foods], [ATH-luck]. Either the display was reworked or two different numbers are shown. The "Luckiest Catch" leaderboard ranks this score [USER].

### 1.6 Cycle time, cooldown, auto-throw

- No source gives a throw cooldown or a full-cycle duration.
- No source mentions an in-game auto-throw. Exploit-script listings advertise "Auto Perfect Throw, Auto Buy, Auto Sell" (search-result titles only, pages not opened), which implies the base game has no auto-throw. [INF]
- Players report that throwing and then resetting the character awards the pet and skips the cutscene. [S1, two separate commenters] [YT-bemmy-inf], [YT-bacha]

**UNKNOWN:** exact meter speed and whether it accelerates with level; whether the meter oscillates or sweeps once; flight duration vs distance; whether flight can be skipped; cooldown between throws; whether you must walk back; whether the animal must be walked to/collected or is auto-granted; how Luck multiplies the animal/mutation/size odds; controller/keyboard bindings; whether other players see your throw.

---

## 2. Strength (Throw Power) and training

### 2.1 How it works

- A pull-up bar is attached to your plot; it unlocks after the tutorial. [C2+] [GGG-beginner], [PGG-beginner]
- Training is free. Once you are on the bar, reps cycle automatically; a red **STOP** button (bottom centre) leaves the bar. Avatar gets a translucent purple tint while training. [C2+] [ATH-mut], [ATH-foods], [USER]
- Each rep gives the bar's XP. XP fills a level bar ("Level 26 7/8"). Each level-up shows "LEVEL UP! Throw Power +5". [C2+] [ATH-foods], [ATH-zones], [BX-luck]
- Rep rate: one rep every 0.5 s (120/min) [S1] [GG-bars]. Conflict: an observed session on the Magenta Bar (16,384 XP/rep, x2 active) took 35-45 s per level at about 646K XP per level [ATH-mut], which works out to roughly 1 rep per 1-2 s, not 2 reps/s [INF]. Treat rep rate as unverified.
- **Bonus popup:** a purple "x2" button appears every 4-6 s while training. Sources disagree on its effect: "adds 1 extra rep" [GG-bars] vs "temporarily doubles training speed / XP" [GGG-beginner], [PGG-beginner], [ATH-zones]. Either way it rewards active tapping over AFK. [C2+ that it exists]
- You can stay on the bar AFK; active play is faster because of the popup. [C2+] [GGG-beginner], [PGG-beginner]
- Bars are bought with money at upgrade pads; each new bar doubles XP per rep. A "NEW EQUIPMENT!" popup with a SHOP button appears when you can afford the next bar, even mid-set. [C2+] [ATH-foods], [ATH-aa]
- HUD shows a flexed-arm icon with the strength total, plus Level and XP bar. One late-game screenshot shows floating "+16,384" (strength) and "+32,768 XP" per cycle with "x2!" above the bar. [S1] [ATH-mut]

### 2.2 Level curve (data points only; no source prints the full curve)

| Level | XP needed for next level | Source |
|---|---|---|
| 10 | 6 | [USER] |
| 26 | 8 | [ATH-foods] |
| 266 | 646K | [ATH-mut] |
| 277 | 735K | [ATH-mut] |

- Total XP level 1 to 129 (Ocean): 54.8K. Level 1 to about 1.2K (Nuclear Wasteland): 728T. [S1] [GG-calc]
- game.guide's description: XP per level "starts at 32.5 for the first area and multiplies by about 4 for each area past the first"; pace dips early and climbs steeply in the last areas. [S1] [GG-bars] The level-10 and level-26 data points above do not fit "32.5" literally, so treat the wording as approximate.
- Time examples (level 1 to 129): Cyan Bar 51m 53s (6.8K reps), Violet 25m 56s, Ruby 12m 58s, Amber 6m 29s, Chrome 3m 15s, Obsidian 1m 37s. [S1] [GG-calc]
- Level reaching the end of the 17-zone lane: about 1.6K (18 + 5x1599 = 8,013 studs). [S1] [GG-calc]
- After the Nov 7 update the strength cap was raised (value not published) [C2+] [SK-u3], [BX-zones]. A player comment reports "max fruit and bar, 11,434 power" [S1] [YT-bacha], which would be about level 2,284 [INF].

### 2.3 Training bars (46 before Nov 7; 12 more added Nov 7 with no published names)

Source for the whole table: [GG-bars]. Rows also confirmed by a second source are marked.

| # | Bar | Price | XP/rep | 2nd source |
|---|---|---|---|---|
| 1 | Wooden Bar | $1 (default) | 1 | [TFA-bars] names it |
| 2 | Steel Bar | $50 | 2 | [BX-beginner], [ATH-foods], [USER] |
| 3 | Gold Bar | $2K | 4 | [ATH-foods] |
| 4 | Cyan Bar | $12K | 8 | [ATH-foods] |
| 5 | Violet Bar | $100K | 16 | [ATH-foods] |
| 6 | Ruby Bar | $600K | 32 | [ATH-prep], [BX-luck] |
| 7 | Amber Bar | $6M | 64 | [ATH-prep], [BX-luck] |
| 8 | Chrome Bar | $38M | 128 | [ATH-prep], [BX-luck] |
| 9 | Obsidian Bar | $320M | 256 | |
| 10 | Aqua Neon Bar | $2B | 512 | |
| 11 | Pink Neon Bar | $15B | 1K | |
| 12 | Lime Neon Bar | $90B | 2K | |
| 13 | Solar Bar | $680B | 4.1K | [ATH-luck] |
| 14 | Frost Bar | $4.2T | 8.2K | [ATH-luck] |
| 15 | Magenta Bar | $28T | 16.4K | [ATH-aa] |
| 16 | Crimson Bar | $170T | 32.8K | [ATH-aa] |
| 17 | Emerald Bar | $1.2Qa | 65.5K | |
| 18 | Sapphire Bar | $7Qa | 131K | [ATH-zones] |
| 19 | Amethyst Bar | $50Qa | 262K | [ATH-zones], [ATH-next] |
| 20 | Inferno Bar | $300Qa | 524K | [ATH-next] |
| 21 | Blue Flame Bar | $2Qi | 1M | |
| 22 | Holy Bar | $12Qi | 2.1M | |
| 23 | Celestial Bar | $80Qi | 4.2M | |
| 24 | Void Bar | $500Qi | 8.4M | |
| 25 | Dragon Bar | $3Sx | 16.8M | |
| 26 | Aurora Bar | $18Sx | 33.6M | |
| 27 | Galaxy Bar | $120Sx | 67.1M | |
| 28 | Infinity Bar | $700Sx | 134M | |
| 29 | Eclipse Bar | $3Sp | 268M | |
| 30 | Omega Bar | $300Sp | 537M | |
| 31 | Phantom Bar | $6Oc | 1.1B | |
| 32 | Nightfall Bar | $60Oc | 2.1B | |
| 33 | Eternal Bar | $500Oc | 4.3B | |
| 34 | Abyss Bar | $2.5No | 8.6B | |
| 35 | Scarecrow Bar | $90No | 17.2B | |
| 36 | Pumpkin Bar | $1.8Dc | 34.4B | |
| 37 | Harvest Moon Bar | $18Dc | 68.7B | |
| 38 | Anchor Bar | $2.2Ud | 137B | |
| 39 | Ghost Ship Bar | $45Ud | 275B | |
| 40 | Lighthouse Bar | $450Ud | 550B | |
| 41 | Hazard Bar | $150Dd | 1.1T | |
| 42 | Toxic Barrel Bar | $6Td | 2.2T | |
| 43 | Scaffold Bar | $60Td | 4.4T | |
| 44 | Siren Bar | $220Td | 8.8T | |
| 45 | Cooling Tower Bar | $600Td | 17.6T | |
| 46 | Reactor Core Bar | $2.4Qad | 35.2T | |

- One article calls the 131K bar "Coral Bar" [ATH-next]; game.guide calls it Sapphire. Possibly a rename.
- Pattern [INF from the table]: XP per rep exactly doubles each bar; price multiplies by about 6-8 each bar (with a few x40-x100 jumps: Steel to Gold, Eclipse to Omega). So XP-per-dollar falls steadily and bars are a pure money sink paced against zone income (each zone's income is about x40 the previous one, see section 4).

### 2.4 Multipliers and paid shortcuts

- **x2 Training Power** gamepass, 149 R$: doubles XP per rep permanently. [C2+] [API-passes], [BX-wiki]
- **2x Training Boost (30s)**, 49 R$ dev product. [S1] [API-products]
- **Training time packs**: instantly grant N minutes of training. Two price sets exist in the catalogue: 5m/15m/30m at 39/99/179 R$ and 2m/5m/15m at 39/99/179 R$ (the second set has later product ids, so it looks like a nerf of time per Robux). [S1] [API-products], order of sets is [INF]
- **Throw Power Packs**: +5 (2 R$), +30 (9 R$), +150 (39 R$), +500 (99 R$). [C2+] [API-products], [GG-eggs]
- Admin Abuse "Power Boost": faster pull-ups and more XP per pull-up for the event window. [C2+] [RB-aa], [PGG-aa]

**UNKNOWN:** full XP-per-level table; true rep interval; exact effect and duration of the x2 popup; whether an "auto-train" toggle exists beyond staying on the bar; whether you keep training while offline (no source says so); the new strength/level cap; names, prices and XP of the 12 bars added Nov 7; whether level has any effect other than +5 power.

---

## 3. Foods

- Only source of food is the **Food Shop**: a blue-and-white striped stall with a glowing ring, just left of the plot entrance. Step in the ring to open it. [C2+] [GGG-beginner], [PGG-beginner], [NC-update]
- The shop shows **three foods at a time**: the one you own and the next two. Buying slides the window forward. A "NEW FOOD UNLOCKED!" popup with a Shop button fires when your cash passes the next price. [C2+] [ATH-foods], [GB-foods], [ATH-aa]
- Foods are permanent and reusable (no consumable stock). [S1] [GR-foods]
- Each food has a rarity label and a "Tier" number. [C2+]
- **What food changes:** which rank of the landing zone's animals the roll centres on (bait level, section 1.4) [S1 for the mechanism: GG-foods; C2+ that "better food = rarer animals": every guide]. Several guides also say higher-tier food raises the Luck gained in flight [BX-luck], [SK-luck], [GGG-mut]; another says food does not raise Luck by itself and only changes the animal pool [ATH-luck]. Luck readings for different foods at similar distance are nearly identical (Banana 5.47X, Orange 5.48X in Savanna [ATH-foods]), which supports the second reading [INF].
- Food does not change distance. [C2+]
- No source gives any per-food mutation or size effect.

### 3.1 Full food list (50 = 42 through Nuclear Wasteland + 8 added Nov 7)

Primary source rows 1-42: [GG-foods]; independently listed by [GR-foods] (42), [BX-foods] (38), [PGG-beginner] (38), [ATH-zones] (partial). "Made for" column is [S1] [GG-foods]. Rows 43-50: [SK-u3], partially [BX-zones], [NC-update].

| # | Food | Rarity | Tier | Price | Made for (zone) | Notes on disagreements |
|---|---|---|---|---|---|---|
| 1 | Carrot | Common | 1 | Free (starter) | Forest | |
| 2 | Apple | Common | 1 | $30 | Forest | |
| 3 | Banana | Common | 1 | $150 | Forest, Savanna | |
| 4 | Toast | Uncommon | 2 | $4K | Savanna | |
| 5 | Orange | Uncommon | 2 | $20K | Savanna, Desert | |
| 6 | Pear | Uncommon | 3 | $200K | Desert | [GR-foods] says tier 2 |
| 7 | Cheese | Rare | 3 | $1M | Desert, Jungle | |
| 8 | Bread Loaf | Rare | 4 | $12M | Jungle | |
| 9 | Water Melon | Rare | 4 | $60M | Jungle, Ocean | |
| 10 | Croissant | Epic | 5 | $650M | Ocean | |
| 11 | Chocolate | Epic | 5 | $3.2B | Ocean, Mountains | |
| 12 | Mushroom | Epic | 6 | $30B | Mountains | |
| 13 | Bacon | Legendary | 6 | $150B | Mountains, Taiga | |
| 14 | Burger | Legendary | 7 | $1.3T | Taiga | |
| 15 | Shank | Legendary | 7 | $6.8T | Taiga, Winter | [PGG-beginner] prints $618T (likely typo) |
| 16 | Fillet | Mythic | 8 | $57T | Winter | [GR-foods] prints $5.7T |
| 17 | Steak | Mythic | 8 | $1.5Qa | Winter, Prehistoric Forest | |
| 18 | Royal Steak | Mythic | 9 | $50Qa | Prehistoric Forest | |
| 19 | Golden Apple | Secret | 9 | $120Qa | Prehistoric Forest, Deep Waters | |
| 20 | Crystal Melon | Secret | 10 | $4Qi | Deep Waters | |
| 21 | Ember Bacon | Secret | 10 | $18Qi | Deep Waters, Hell | |
| 22 | Lava Steak | Divine | 11 | $120Qi | Hell | |
| 23 | Elder Strawberry | Divine | 11 | $700Qi | Hell, Ancient Ruins | |
| 24 | Phoenix Fillet | Divine | 12 | $4Sx | Ancient Ruins | [GR-foods] prints $35Sx |
| 25 | Star Jelly | Celestial | 12 | $27Sx | Ancient Ruins | |
| 26 | Dragon's Apple | Celestial | 13 | $180Sx | Mythical Paradise | |
| 27 | Starlight Donut | Celestial | 13 | $450Sx | Mythical Paradise | |
| 28 | Glowshroom | Celestial | 13 | $1.4Sp | Mythical Paradise | |
| 29 | Sundae Tower | Celestial | 13 | $3.5Sp | Mythical Paradise | |
| 30 | Golden Corn | Eternal | 14 | $2.5Oc | Shadow Realm | |
| 31 | Roast Turkey | Eternal | 14 | $28Oc | Shadow Realm | |
| 32 | Caramel Apple | Eternal | 14 | $250Oc | Shadow Realm | |
| 33 | Candy Corn | Eternal | 15 | $750No | Harvest Fields | |
| 34 | Hot Cider | Eternal | 15 | $8.5Dc | Harvest Fields | |
| 35 | Golden Pumpkin | Eternal | 15 | $75Dc | Harvest Fields | |
| 36 | Ghost Chowder | Cosmic | 16 | $18Ud | Phantom Harbor | |
| 37 | Calamari Rings | Cosmic | 16 | $200Ud | Phantom Harbor | |
| 38 | Phantom Lobster | Cosmic | 16 | $1.8Dd | Phantom Harbor | |
| 39 | Toxic Donut | Supreme | 17 | $1.2Td | Nuclear Wasteland | |
| 40 | Mutant Melon | Supreme | 17 | $20Td | Nuclear Wasteland | |
| 41 | Atomic Pizza | Supreme | 17 | $400Td | Nuclear Wasteland | |
| 42 | Uranium Cake | Supreme | 17 | $9Qad | Nuclear Wasteland | |
| 43 | Ghost Popcorn | Supreme | 18 | $3Qid | Cursed Carnival [INF] | [SK-u3], [NC-update] agree on price |
| 44 | Cursed Candy Apple | Supreme | 18 | $58Qid | Cursed Carnival [INF] | [SK-u3] |
| 45 | Spectral Cotton Candy | Supreme | 18 | $900Qid | Cursed Carnival [INF] | [SK-u3] |
| 46 | Ringmaster Cake | Supreme | 18 | $125Sxd | Cursed Carnival [INF] | [NC-update] prints $12Sxd |
| 47 | Crescent Pear | Sovereign | 19 | $5Spd | Eclipse Kingdom [INF] | [SK-u3], [BX-zones], [NC-update] agree |
| 48 | Sunwheel (Tart) | Sovereign | 19 | $170Spd | Eclipse Kingdom [INF] | [SK-u3], [BX-zones] agree |
| 49 | Royal Mooncake | Sovereign | 19 | $3.5Ocd | Eclipse Kingdom [INF] | [SK-u3] |
| 50 | Black Sun Souffle | Sovereign | 19 | $31Ocd | Eclipse Kingdom [INF] | [SK-u3] |

Food rarity ladder: Common, Uncommon, Rare, Epic, Legendary, Mythic, Secret, Divine, Celestial, Eternal, Cosmic, Supreme, Sovereign (Sovereign added Nov 7). [C2+] [GG-foods], [SK-u3], [BX-zones]

**UNKNOWN:** the numeric bait level per food; whether food adds Luck (sources disagree); whether tier number has any mechanical meaning beyond shop grouping; rarity colours of food tiles.

---

## 4. Zones / biomes along the lane

- One straight lane. 17 zones span 5 to about 8,000 studs (game.guide home says 7,973-stud lane). [S1 for studs] [GG-home], [GG-areas]. Two more zones were appended on Nov 7 (19 total). [C2+] [SK-u3], [BX-zones], [NC-update]
- Zones are not gated by purchase; you reach a zone when your throw is long enough. [C2+] [TFA-home], [GG-areas]
- "Unlock level" = level where a perfect (+20) throw reaches the zone start. [S1] [GG-calc]
- Zones have their own ambience (added Nov 7). [C2+] [SK-u3], [BX-zones]

| # | Zone | Start-end (studs) | Length | Unlock level (perfect throw) | Top animal and $/s | Animals |
|---|---|---|---|---|---|---|
| 1 | Forest | 5-173 | 168 | 1 | Pony $25 | 8 |
| 2 | Savanna | 173-341 | 168 | 28 | Lion $1K | 8 |
| 3 | Desert | 341-509 | 168 | 62 | Kangaroo $38K | 8 |
| 4 | Jungle | 509-677 | 168 | 96 | Gorilla $1.5M | 8 |
| 5 | Ocean | 677-845 | 168 | 129 | Seal $62M | 8 |
| 6 | Mountains | 845-about 1,000 | about 155 | 163 | Griffin $2.5B | 8 |
| 7 | Taiga | about 1.0K-1.3K | about 300 | 201 | Fenrir $100B | 8 |
| 8 | Winter | about 1.3K-1.5K | about 200 | 244 | Sabertooth Tiger $3.8T | 8 |
| 9 | Prehistoric Forest | about 1.5K-1.8K | about 300 | 292 | Velociraptor $150T | 8 |
| 10 | Deep Waters | about 1.8K-2.0K | about 200 | 345 | Plesiosaur $6.2Qa | 8 |
| 11 | Hell | about 2.0K-2.4K | about 400 | 403 | Cerberus $250Qa | 8 |
| 12 | Ancient Ruins | about 2.4K-2.8K | about 400 | 470 | Hydra $10Qi | 8 |
| 13 | Mythical Paradise | about 2.8K-3.2K | about 400 | 547 | Phoenix $380Qi | 8 |
| 14 | Shadow Realm | about 3.2K-4.1K | about 900 | 643 | Nightmare $32Sp | 8 |
| 15 | Harvest Fields | about 4.1K-5.2K | about 1,100 | 811 | Headless Horseman $3.2No | 8 |
| 16 | Phantom Harbor | about 5.2K-6.2K | about 1,000 | about 1.0K | Ghost Pirate $256Dc | 8 |
| 17 | Nuclear Wasteland | about 6.2K-8.0K | about 1,800 | about 1.2K | Waste Harvester $410Dd | 12 |
| 18 | Cursed Carnival | starts at about 8,000 | UNKNOWN | UNKNOWN (about 1.6K [INF]) | UNKNOWN | 12 |
| 19 | Eclipse Kingdom | UNKNOWN | UNKNOWN | UNKNOWN | Eclipse Dragon (income UNKNOWN) | 12 |

Sources: studs and levels [GG-home], [GG-areas] (rounded values beyond 1K are as printed, hence "about"); top animals [TS-codes], [GG-home], [RB-animals]; Cursed Carnival "requires 8,000 Throw Power to enter" [SK-u3].

Corroborating play observations: level 341 throws still landed in Prehistoric Forest; Deep Waters first reached at level 344-348 with a +20 Perfect [ATH-zones] (game.guide says 345). [C2+]

Progression shape [INF from the table]:
- Zones 1-5 are a constant 168 studs = 34 levels apart. From zone 7 the zones get longer (300, then 400, then about 1,000, then 1,800), so the number of levels between zones grows from 34 to about 200+.
- Top-animal income multiplies by about x40 per zone through Mythical Paradise, then by much larger steps (x84,000 from Phoenix to Nightmare) [TS-codes says the same in words].
- Within a zone, the top animal earns about 25x the rank-1 animal. [S1] [GB-pets]

Zone-count history (explains why guides disagree): 7 named areas on a wiki snapshot of Oct 29 [TFA-home]; 15 zones in guides dated Oct 31-Nov 2 (no Hell, no Nuclear Wasteland) [GGG-beginner], [PGG-beginner]; 17 by Nov 5-11 [RB-animals], [TS-codes]; 19 after Nov 7 [SK-u3].

**UNKNOWN:** stud ranges and unlock levels of Cursed Carnival and Eclipse Kingdom; exact boundaries of front/middle/back thirds (game.guide states the rule, not the boundaries); whether zones have physical props/walls or are only floor themes; when Hell was added.

---

## 5. Animals

### 5.1 Counts

- Index total: 128 (late Oct) [ATH-foods], [GGG-beginner]; 140 (Nov 5-11: 16 zones x 8 + 12) [RB-animals], [TS-codes], [ATH-aa]; **164** after Nov 7 (+12 Cursed Carnival, +12 Eclipse Kingdom) [NC-update], [USER]. [C2+]
- Plus 8 egg/shop pets that are not lane catches (148 = 140 + 8 on game.guide and gameboost). [C2+] [GG-home], [GB-pets]
- The Index is grouped by zone ("Forest 2/8"), tiles are rarity-coloured, undiscovered entries show "???" silhouettes. [C2+] [NC-update], [ATH-foods], [USER]

### 5.2 Rarity tiers

Order (lowest to highest): Common, Uncommon, Rare, Epic, Legendary, Mythic, Secret, Divine, Celestial, Eternal, Cosmic, Supreme, and Sovereign (new Nov 7; two Eclipse Kingdom animals are Sovereign). [C2+] [GG-animals], [GB-pets], [TS-codes], [SK-u3]

- Rarity is a label on the species, not a separate roll. There are no per-rarity odds; the odds come from rank, depth and food (section 1.4). [INF from GG-catch; TS-codes also says the developer has published no spawn rates]
- Rarity does not set income: a Divine Plesiosaur (Deep Waters, $6.2Qa) earns far less than a Mythic Black Cat (Shadow Realm, $250Sx). Depth beats rarity. [S1] [GB-pets]
- Within each zone rarity climbs with rank, and each zone's rarity band shifts up by roughly one tier every 1-2 zones. [INF from the list below]

### 5.3 Full list of the 140 lane animals (rank order within zone; rarity; base $/s)

Sources: [GG-home] and [RB-animals] list all 140 independently; [BX-tier] lists the same incomes. Disagreements are noted below the table. **Sell value = 20 x $/s** (section 8).

| Zone | Rank 1 to 8 (rarity, base $/s) |
|---|---|
| Forest | Snail (C, 1); Frog (C, 2); Bunny (C, 3); Owl (U, 5); Kookaburra (U, 8); Badger (U, 12); Cow (R, 18); Pony (E, 25) |
| Savanna | Ostrich (C, 40); Quokka (C, 80); Giraffe (U, 120); Hyena (U, 200); Zebra (U, 320); Aardvark (R, 480); Elephant (R, 720); Lion (E, 1K) |
| Desert | Hamster (C, 1.5K); Vulture (U, 3K); Emu (U, 4.5K); Snake (U, 7.5K); Dingo (R, 12K); Jackal (R, 18K); Horse (E, 27K); Kangaroo (E, 38K) |
| Jungle | Lizard (U, 60K); Bat (U, 120K); Parrot (U, 180K); Koala (R, 300K); Cobra (R, 480K); Crocodile (E, 720K); Tiger (E, 1.1M); Gorilla (L, 1.5M) |
| Ocean | Crab (U, 2.5M); Turtle (U, 5M); Jellyfish (R, 7.5M); Goblin Shark (R, 12M); Seahorse (E, 20M); Mantis Shrimp (E, 30M); Leafy Sea Dragon (L, 45M); Seal (L, 62M) |
| Mountains | Llama (U, 100M); Guinea Pig (R, 200M); Roc (R, 300M); Capybara (E, 500M); Thunderbird (E, 800M); Bull (L, 1.2B); Yak (L, 1.8B); Griffin (My, 2.5B) |
| Taiga | Honey Badger (R, 4B); Cockatrice (R, 8B); Caracal (E, 12B); Wolf (E, 20B); Jackalope (L, 32B); Bear (L, 48B); Kitsune (My, 72B); Fenrir (My, 100B) |
| Winter | Husky (R, 150B); Goat (E, 300B); Tanuki (E, 450B); Caladrius (L, 750B); Polar Bear (L, 1.2T); Mammoth (My, 1.8T); Lindworm (My, 2.7T); Sabertooth Tiger (Se, 3.8T) |
| Prehistoric Forest | Pterodactyl (E, 6T); Triceratops (E, 12T); Dimetrodon (L, 18T); Gallimimus (L, 30T); Brachiosaurus (My, 48T); Spinosaurus (My, 72T); T-Rex (Se, 110T); Velociraptor (Se, 150T) |
| Deep Waters | Anglerfish (E, 250T); Swordfish (L, 500T); Shark (L, 750T); Whale (My, 1.2Qa); Megalodon (My, 2Qa); Mosasaurus (Se, 3Qa); Kraken (Se, 4.5Qa); Plesiosaur (Di, 6.2Qa) |
| Hell | Mothman (L, 10Qa); Bunyip (L, 20Qa); Gargoyle Bat (My, 30Qa); Winged Imp (My, 50Qa); Manticore (Se, 80Qa); Chupacabra (Se, 120Qa); Dullahan (Di, 180Qa); Cerberus (Di, 250Qa) |
| Ancient Ruins | Triple Cobra (L, 400Qa); Leviathan (My, 800Qa); Microraptor (My, 1.2Qi); Archaeopteryx (Se, 2Qi); Qilin (Se, 3.2Qi); Sphinx (Di, 4.8Qi); Minotaur (Di, 7.2Qi); Hydra (Ce, 10Qi) |
| Mythical Paradise | Raiju (My, 15Qi); Unicorn (My, 30Qi); Pegasus (Se, 45Qi); Simurgh (Se, 75Qi); Amphiptere (Di, 120Qi); Wyvern (Di, 180Qi); Dragon (Ce, 270Qi); Phoenix (Ce, 380Qi) |
| Shadow Realm | Black Cat (My, 250Sx); Cursed Raven (Se, 500Sx); Cursed Owl (Se, 1Sp); Shadow Wolf (Di, 2Sp); Phantom Dog (Di, 4Sp); Hellhound (Ce, 8Sp); Shadow Demon (Ce, 16Sp); Nightmare (Et, 32Sp) |
| Harvest Fields | Raven (Se, 25Oc); Zombie Crow (Se, 50Oc); Scarecrow (Di, 100Oc); Witch's Cat (Di, 200Oc); Jack-o'-Lantern (Ce, 400Oc); Witch (Ce, 800Oc); Pumpkin Golem (Et, 1.6No); Headless Horseman (Et, 3.2No) |
| Phantom Harbor | Ghost (Se, 2Dc); Poltergeist (Di, 4Dc); Wraith (Di, 8Dc); Specter (Ce, 16Dc); Banshee (Ce, 32Dc); Ghostly Horse (Et, 64Dc); Lich (Et, 128Dc); Ghost Pirate (Co, 256Dc) |
| Nuclear Wasteland (12) | Reactor Hound (Di, 200Ud); Uranium Stag (Di, 400Ud); Barrel Brute (Ce, 800Ud); Sludge Mimic (Ce, 1.6Dd); Reactor Golem (Ce, 3.2Dd); Siren Spire (Et, 6.4Dd); Glassback Colossus (Et, 12.8Dd); Isotope Angel (Et, 25.6Dd); Ferro Wyrm (Co, 51.2Dd); Rad Scarecrow (Co, 102Dd); Meltdown Idol (Su, 205Dd); Waste Harvester (Su, 410Dd) |

Rarity key: C Common, U Uncommon, R Rare, E Epic, L Legendary, My Mythic, Se Secret, Di Divine, Ce Celestial, Et Eternal, Co Cosmic, Su Supreme.

Disagreements between sources:
- Lion: Epic [GG-home] vs Rare [RB-animals].
- Zombie Crow: $50Oc [GG-home], [BX-tier] vs $40Oc [RB-animals].
- Caladrius: $750B [GG-home], [BX-tier] vs $720B [RB-animals].
- [BX-tier] tags each animal Front/Middle/Back, but its tags do not follow rank order (e.g. Kookaburra "Back", Badger "Middle"), which conflicts with the rank-cap rule from [GG-areas]. Treat per-animal band tags as unreliable.

Income pattern inside a zone [INF]: roughly 1, 2, 3, 5, 8, 12, 18, 25 times the rank-1 value. From Shadow Realm onward it is a clean doubling per rank.

### 5.4 Cursed Carnival and Eclipse Kingdom (added Nov 7) - partial

- 12 Index slots each. [C2+] [BX-zones], [NC-update], [SK-u3]
- Cursed Carnival names seen: Vampire Bat, Harlequin Hyena, Nightmare Griffin, Circus Chimera, Dreadmane Behemoth. [C2+ for the last three: BX-zones, SK-u3; S1 for the first two: NC-update]
- Eclipse Kingdom names seen: Royal Lamassu, Crownbreaker Aurochs, Eclipse Dragon; two of the 12 are Sovereign rarity. [C2+] [BX-zones], [SK-u3]
- Player comments and video chapters mention "bosses" in each zone and "late-game boss hunts". [S1, unexplained] [YT-bacha], [YT-jinn]. It may simply be slang for each zone's top animal.

### 5.5 Egg / shop pets (income is a multiple of your best animal, not a fixed $/s)

| Pet | Rarity | Income | Source of pet |
|---|---|---|---|
| Skeleton | Rare | 1x best animal | Halloween Egg 40% |
| Skeleton Horse | Epic | 1.5x | Halloween Egg 28% |
| Demon | Legendary | 2x | Halloween Egg 17% |
| Reaper Steed | Mythic | 3x | Halloween Egg 10% |
| Reaper | Celestial | 5x | Halloween Egg 4% |
| Pumpkin Monster | Divine | 9x | Halloween Egg 1%, or 499 R$ direct |
| Giant Squid | Celestial | 3x | 299 R$ direct |
| Woolly Mammoth | Mythic | 1.5x | 199 R$ direct |

[C2+] [GG-eggs], [GG-animals], [GB-pets], [BX-tier], [API-products]

**UNKNOWN:** rarity tile colours; full lists, rarities and incomes for the two newest zones; what "boss" means; whether animals have any stat besides $/s; whether there are zone-exclusive visual sizes; any hidden/secret animals outside the Index.

---

## 6. Mutations and sizes

### 6.1 Mutations (one roll per catch; at most one mutation per animal)

| Mutation | Look | Normal-throw chance | "Lucky Throw" chance (as printed) | Income and sell multiplier |
|---|---|---|---|---|
| none | | 79.5% | | x1 |
| Gold | sparkling gold skin | 13% (1 in 8) | 9.5% | x1.5 |
| Diamond | crystal skin | 4% (1 in 25) | 25% | x3 |
| Emerald | green | 2% (1 in 50) | 29% | x5 |
| Ruby | red | 1% (1 in 100) | 23% | x10 |
| Rainbow | multicolour | 0.5% (1 in 200) | 14% | x20 |

[C2+] [GGG-mut], [PGG-mut], [BX-mut], [GG-mut], [OZ-mut], [SK-mut]. The Lucky column sums to 100.5%, so it is rounded and implies almost no "none" outcome.

### 6.2 Sizes (a chain of size-ups; at most one size title per animal)

Mechanism [C2+] [GG-mut], [OZ-mut]: 20% chance of a first size-up; each success raises the chance of another by 5 points (25%, 30%, 35%) capped at 40%; the first miss ends the chain; hard stop at 40 size-ups. Each size-up multiplies the model's scale by 1.5.

| Title | Size-ups | Scale | Income multiplier (scale^1.8) | Normal chance | Lucky Throw chance (as printed) |
|---|---|---|---|---|---|
| (normal) | 0 | x1 | x1 | 80% | |
| BIG | 1 | x1.5 | x2.07 | 15% (1 in 7) | 21% |
| LARGE | 2 | x2.25 | x4.30 | 3.5% (1 in 29) | 42% |
| HUGE | 3 | x3.38 | x8.9 | 0.97-0.98% (1 in 103) | 22% |
| COLOSSAL | 4 | x5.06 | x18.5 | 0.31-0.32% (1 in 317) | 8.49% |
| GIGANTIC | 5 | x7.59 | x38.4 | 0.12-0.13% (1 in 794) | 3.6% |
| TITANIC | 6 | x11.39 | x79.8 | 0.05% (1 in 2K) | 1.48% |
| MONSTROUS | 7 | x17.09 | x165.5 | 0.02% (1 in 5K) | 0.6% |
| COSMIC | 8 | x25.63 | x343.3 | 0.008% (1 in 12.4K) | 0.24% |
| INFINITE | 9+ | x38.44+ | x712.3+ | 0.005% (1 in 18.6K-20K) | 0.16% |

Chances: [C2+] [GGG-mut], [PGG-mut], [OZ-mut], [GG-mut]. Scale column: [C2+] same sources (they label it "multiplier"). Income column: [S1 as a table] [GG-mut].

### 6.3 How they stack - sources disagree, arithmetic settles it

- games.gg and Pro Game Guides say the size "multiplier" is 1.5 / 2.25 / 3.38... and that mutation and size "stack additively". [GGG-mut], [PGG-mut]
- ofzenandcomputing says they multiply (Gold Big = 1.5 x 1.5 = 2.25x). [OZ-mut]
- game.guide says **income = base x mutation multiplier x scale^1.8**, rounded. [GG-mut], [GG-income]
- Check against incomes quoted from real screenshots in unrelated articles [INF, my arithmetic]:
  - Big Zebra $664/s: 320 x 1.5^1.8 = 320 x 2.075 = 664. Matches. [ATH-foods]
  - Large Hyena $861/s: 200 x 2.25^1.8 = 200 x 4.305 = 861. Matches. [ATH-foods]
  - Huge Caracal $107B/s: 12B x 3.375^1.8 = 12B x 8.93 = 107B. Matches. [ATH-luck]
  - Gold Goat (Big) $934B/s: 300B x 1.5 x 2.075 = 934B. Matches. [ATH-aa]
  - Diamond Aardvark $1.44K/s: 480 x 3. Emerald Parrot $900K/s: 180K x 5. Match. [ATH-foods], [ATH-prep]
- Conclusion **[C2+]**: mutation and size multiply, and the size income factor is scale^1.8 (BIG is about x2.07, not x1.5). The "1.5x / additive" tables in the big guide sites are wrong about income.
- Best named combo: Rainbow + Infinite = 20 x 712 = about x14,000 base income (game.guide's Rainbow Egg note gives Rainbow + Gigantic = about x769). [GG-eggs]; [INF] for the 14,000 figure.

### 6.4 What changes the odds

- Mutations and sizes come only from the catch roll. No weather, machines or post-catch upgrades as of the guides' "Update 1". [C2+] [GGG-mut], [SK-mut]
- **Super Lucky Throw** (paid): product text changed over time from "100x luck" to "best of 30 rolls" (mutation and size are rolled 30 times, best kept). [C2+] [API-products], [SK-luck]
- **Server Luck** 2x/4x/8x/16x for 15 minutes, whole server (section 10). [C2+]
- Guides claim Luck (distance) improves mutation and size odds [GGG-mut], [SK-sizes]; no numbers.
- Admin Abuse luck boost raises mutation and size chances. [C2+] [RB-aa], [PGG-aa]

**UNKNOWN:** how the Luck multiplier and Server Luck mathematically modify the mutation and size tables; whether any mutation exists beyond Rainbow (players ask; no source lists one); visual treatment of each size; whether size affects anything besides income/sell value and model scale (plot crowding?).

---

## 7. The plot

- Each player has a fenced plot ("base", "pen") at the head of the lane. Around the entrance: Food Shop left of the entrance, base-size upgrade sign/button right of the entrance, a red-and-white SELL stand right of the throwing area, the pull-up bar attached to the plot. [C2+] [GGG-beginner], [PGG-beginner], [RB-beginner]
- **Only animals placed on the plot earn.** Animals in the backpack/inventory earn nothing. [C2+] [ATH-zones], [GG-income], [BX-foods]
- Each placed animal shows a label with name, size tag, mutation tag and $/s. [C2+] [ATH-foods], [USER]

### 7.1 Capacity

- Starting capacity: **10**. [C2+] [GG-income], [KK-guide], [USER "ON YOUR PLOT 2/10"]
- Each upgrade adds **+2 slots**. [C2+] [GGG-beginner], [PGG-beginner], [BX-beginner]

| Upgrade | Price | Source | Roughly affordable in |
|---|---|---|---|
| 10 to 12 | $40M | [ATH-prep], [USER] [C2+] | Ocean (Crab is $2.5M/s) [INF] |
| 12 to 14 | $200T | [ATH-luck], [ATH-prep] [C2+] | Prehistoric Forest [INF] |
| 14 to 16 | $50Qi | [ATH-aa] [S1] | Mythical Paradise [INF] |
| 16 to 18, 18 to 20 | UNKNOWN | | |
| observed 20/20 | | [NC-update] [S1] | Nuclear Wasteland-level player |

Shape [INF]: prices jump by factors of about 5,000,000 and 250,000, i.e. one capacity upgrade roughly every 3-4 zones. Capacity is deliberately scarce; players sit on 10 slots for the first 4 zones.

### 7.2 Managing animals

- **Animals** button (orange paw, right side) opens "My Animals": lists everything owned, shows "ON YOUR PLOT n/cap", with PICK UP, SELL and EQUIP BEST. [C2+] [NC-update], [ATH-mut], [USER]
- **EQUIP BEST** fills every plot slot with your highest earners and confirms with "Your best N animals are on your plot!". [C2+] [NC-update], [ATH-aa], [ATH-luck]
- **SELL stand:** walk into its ring; prompt "Sell N animals for $X"; SELL ALL sells **backpack animals only**, plot animals are never sold by it. Examples: 5 animals for $608B and $1.94T; 7 for $35.7Qa; 8 duplicates for $628T. [C2+] [ATH-aa], [ATH-next], [ATH-zones], [ATH-luck]
- Individual animals can also be sold from the My Animals panel. [C2+] [NC-update], [PGG-beginner]
- Eggs bought with Robux are placed on the plot to hatch. [S1] [API-products] (Magma Egg description)

### 7.3 Collecting money

- Income accrues every second. No source describes walking over anything or pressing a collect button, and the "Welcome Back" popup is the only claim step mentioned. [INF: income is automatic]
- **Offline earnings:** a "Welcome Back!" popup on join shows what your animals earned while away, with CLAIM or a paid 2X. [C2+] [ATH-foods], [ATH-aa], [USER]
  - Rate: each hour away pays 2 minutes of your plot's income; capped at 48 hours. [S1] [GG-income]
  - Cross-check [INF]: the owner's screenshot shows $97.5K after 24h 37m. 24.62 h x 120 s = 2,954 s; $97.5K / 2,954 s = $33.0/s, which is exactly Pony (25) + Kookaburra (8), a plausible 2-animal plot. So the 2-minutes-per-hour rule fits.

**UNKNOWN:** prices of the upgrades beyond 16 and the maximum capacity; whether animals wander inside the fence or stand on fixed pads; whether size changes how much room an animal takes; whether there is a per-animal collect interaction; whether placed animals can be rearranged; whether the plot has cosmetic upgrades.

---

## 8. Economy

### 8.1 Sources of money

1. Passive $/s from placed animals (the main source). [C2+]
2. Selling animals: **sell price = 20 x the animal's own $/s** (including its mutation and size). [C2+] [GG-income], [GG-animals]; confirmed by "Reactor Golem sold for $64Dd" (3.2Dd x 20) [NC-update] and Waste Harvester $8.2Td (410Dd x 20) [GG-animals].
   - So selling is worth only 20 seconds of that animal's income: selling is inventory cleanup, not an income strategy. [INF]; fan wikis say the same in words [TFA-sell].
3. Offline earnings (2 min of income per hour away, 48 h cap) [S1] [GG-income].
4. Index completion cash rewards per zone (amounts unknown) [C2+ that they exist] [GGG-beginner], [PGG-beginner], [BX-beginner].
5. Paid: x2 Cash pass (doubles animal income, not sell price) [C2+] [API-passes], [GG-income]; Money Packs worth 3 min / 18 min / 90 min / 5 h of your current income [C2+] [API-products], [GG-eggs]; 2X offline claim [API-products]; Admin Abuse money event (2x for the window) [C2+] [RB-aa], [PGG-aa]; Ultra Pack ($60Qi cash) [API-products].

### 8.2 Sinks

1. Foods (50, one-time purchases).
2. Training bars (58, one-time purchases).
3. Plot capacity (+2 per purchase).
That is all. Food, bars and plot draw on the same wallet, which creates the "which do I buy next" decision the guides talk about. [C2+] [BX-foods], [TFA-food], [KK-guide]

### 8.3 Typical numbers by stage

| Stage | Zone | Typical animal $/s | Next food | Next bar | Notes |
|---|---|---|---|---|---|
| First minute | Forest | 1-25 | Apple $30 | Steel $50 | Free Hyena ($200/s) offered in shop [TFA-free], [TF-how] |
| Early | Savanna-Desert | 40-38K | Toast $4K, Cheese $1M | Gold $2K to Violet $100K | |
| Early-mid | Jungle-Ocean | 60K-62M | Bread Loaf $12M, Croissant $650M | Ruby $600K to Chrome $38M | first plot upgrade $40M |
| Mid | Mountains-Winter | 100M-3.8T | Mushroom $30B, Fillet $57T | Obsidian $320M to Frost $4.2T | offline payout example $611M [ATH-prep] |
| Mid-late | Prehistoric-Deep Waters | 6T-6.2Qa | Royal Steak $50Qa | Magenta $28T to Sapphire $7Qa | plot 12 to 14 = $200T; cash on hand about $10.5Qa at level 266 [ATH-mut] |
| Late | Hell-Mythical Paradise | 10Qa-380Qi | Lava Steak $120Qi | Amethyst $50Qa to Void $500Qi | plot 14 to 16 = $50Qi; offline payout example $32.3Qi [ATH-next] |
| End (pre Nov 7) | Shadow Realm-Nuclear Wasteland | 250Sx-410Dd | Uranium Cake $9Qad | Reactor Core $2.4Qad | |
| End (current) | Cursed Carnival-Eclipse Kingdom | UNKNOWN | Black Sun Souffle $31Ocd | UNKNOWN | |

Ratios [INF from the tables]:
- A food usually costs about 100-300 seconds of income from a full plot of the zone it is made for. Example: Toast $4K vs ten Ostriches at $40/s = 10 s per $400, so 100 s. Bread Loaf $12M vs ten Lizards $600K/s = 20 s. The whole lane is paced so each purchase is seconds-to-minutes of income once you hold the right animals, and impossible before.
- Reported free-to-play completion times: "5 hours from the start to Nuclear Wasteland" and "finished in 6 hours without Robux" (YouTube commenters, before the Nov 7 zones). [S1 each, two commenters] [YT-peach]

### 8.4 Number notation

K, M, B, T, Qa, Qi, Sx, Sp, Oc, No, Dc (decillion), Ud (undecillion), Dd (duodecillion), Td (tredecillion), Qad (quattuordecillion), Qid (quindecillion), Sxd (sexdecillion), Spd (septendecillion), Ocd (octodecillion). Top printed price: Black Sun Souffle $31Ocd (about 3.1e58). [C2+] [GG-foods], [GG-bars], [SK-u3]; a YouTube commenter also explains "OCD = octodecillion" [YT-peach].
The leaderboard score in the owner's screenshot ("854Sx") uses the same suffixes. [USER]

**UNKNOWN:** Index reward amounts; whether income ticks per second or in batches; rounding rules shown in UI; whether money has a cap; whether animal income is affected by anything positional (adjacency etc.; no source suggests it).

---

## 9. Rebirth / prestige, quests, daily rewards, gifts, codes, index rewards

- **Rebirth / prestige: none found.** No guide, wiki, calculator, product description or video chapter mentions a rebirth or reset. Three targeted searches returned nothing for this game. [INF: there is no rebirth layer as of 2026-11-14]. The long-term layer is simply more zones appended every Saturday plus mutation/size chase plus leaderboards.
- **Quests / objectives:** a tutorial objective list exists ("Buy new food" with a yellow arrow to the stall; buying advances the list). Nothing beyond the tutorial is documented. [S1] [ATH-foods]
- **Daily rewards / login streak:** not mentioned by any source. [TS-codes] explicitly lists none.
- **Playtime gifts:** not mentioned by any source.
- **Free shop item:** the Shop button sometimes shows a FREE tag [ATH-mut]; a free Hyena ($200/s) is offered in the shop during the beginner run [TFA-free], [TF-how]. [C2+]
- **Codes: none, and no redemption UI.** Checked by multiple trackers between Oct 30 and Nov 11. [C2+] [TS-codes], [GGG-beginner], [DX-codes], [GB-codes], [TFA-home]
- **Group / like rewards:** none mentioned; the group has no shout and no description. [C2+] [TS-codes], [API-group]
- **Index completion:** completing a zone's set in the Animal Index lets you claim a cash reward. Guides advise not chasing it because moving to the next zone pays more. [C2+] [GGG-beginner], [PGG-beginner], [BX-beginner], [RB-beginner]
- **Minigame:** the Nov 7 update videos have chapters "Mastering the ring minigame" and "The ring rush challenge". No written source explains it. [S1] [YT-bacha], [YT-bemmy-end]

**UNKNOWN:** Index reward amounts per zone and for full completion; what the ring minigame is, where it is and what it pays; whether any daily/playtime reward exists that guides simply ignored; what the FREE shop tag rotates through.

---

## 10. Monetisation

All Robux prices below are the catalogue prices returned by the public Roblox API on 2026-11-14 [API-products], [API-passes]. The owner's screenshots show lower prices (Enchanted Egg 35/79/259, 2X offline 19); those are about 32-39% of the API prices for the matching items (99/249/799 and 49), which is consistent with Roblox regional pricing [INF]. Sportskeeda's "Super Lucky Throw costs 4 Robux" vs the API's 9 is probably the same effect [INF].

### 10.1 Gamepasses (2)

| Pass | R$ | Effect |
|---|---|---|
| x2 Cash | 99 | doubles cash from every animal, permanent (not sell price) |
| x2 Training Power | 149 | doubles XP from every pull-up, permanent |

Created 2026-09-30, last updated 2026-11-03. Both can be gifted through dev products "Gift x2 Cash" (99) and "Gift x2 Training Power" (149). [C2+] [API-passes], [API-products], [BX-wiki]

### 10.2 Developer products (50 in the catalogue)

| Group | Item | R$ | Effect (from product text) |
|---|---|---|---|
| Luck | Super Lucky Throw x1 | 9 | one super lucky throw |
| | 3 / 35 / 60 Lucky Throws | 27 / 299 / 499 | saveable; "best of 30 rolls" (newer set) |
| | 5 / 10 / 50 / 100 Lucky Throws | 39 / 69 / 299 / 499 | saveable; "100x luck" (older set) |
| | Server Luck 2x | 19 | whole server 1x to 2x, +15 min |
| | Server Luck 4x | 39 | 2x to 4x, +15 min |
| | Server Luck 8x | 79 | 4x to 8x, +15 min |
| | Server Luck 16x | 159 | 8x to 16x (max), +15 min; at 16x just adds 15 min |
| Eggs | Enchanted Egg x1 / x3 / x10 | 99 / 249 / 799 | random Enchanted animal, up to 1200% (of best animal) |
| | Enchanted Egg / 3 / 10 (second set) | 79 / 199 / 649 | same text, cheaper set |
| | Halloween Egg x1 / x3 | 80 / 200 | Halloween limited; monster up to 900% of best animal |
| | Rainbow Egg x1 / x3 | 99 / 249 | hatches a Rainbow, Giant animal (LIMITED per owner's screenshot) |
| | Magma Egg x1 / x3 | 60 / 150 | egg placed on plot, hatches a fiery beast (reported no longer sold) |
| Direct pets | Pumpkin Monster | 499 | 900% of best animal (Halloween limited) |
| | Giant Squid | 299 | 300% of best animal |
| | Woolly Mammoth | 199 | 150% of best animal |
| Limited animals | Jellyfish | 40 | $7.5M/s |
| | Fenrir | 156 | $100B/s |
| | Velociraptor | 4,400 | $150T/s |
| | Hydra | 12,000 | $10Qi/s |
| Packs | Ultra Pack | 640 | $60Qi cash + Winged Imp + Cerberus |
| Money | Money Pack 1 / 2 / 3 / 4 | 24 / 59 / 79 / 199 | instant cash = 3 min / 18 min / 90 min / 5 h of your earnings |
| | 2x Offline Earnings | 49 | doubles the welcome-back payout |
| Power | Throw Power Pack 1 / 2 / 3 / 4 | 2 / 9 / 39 / 99 | +5 / +30 / +150 / +500 Throw Power |
| Training | 5m / 15m / 30m of Training | 39 / 99 / 179 | instant training time (older set) |
| | 2m / 5m / 15m Training Pack | 39 / 99 / 179 | instant training time (newer set) |
| | 2x Training Boost (30s) | 49 | no description |
| Gifting | Gift x2 Cash / Gift x2 Training Power | 99 / 149 | gifts the pass to another player |

[S1 for most rows: API-products; C2+ for server luck, lucky throws, money packs, power packs, eggs, direct pets: GG-eggs, TS-codes, BX-luck]

Notes:
- Duplicate price sets (two Enchanted Egg ladders, two training ladders, two lucky-throw ladders) suggest live price testing or re-pricing. Newer product ids carry the higher egg prices and shorter training times. [INF]
- Catalogue age by product id [INF]: launch batch = Magma/Rainbow eggs, server luck, Ultra Pack, limited animals, gifts; then Super Lucky Throw; then Halloween items; then money/power packs and lucky-throw bundles; then training packs, Enchanted Egg, 2x Offline; most recent = 2x Training Boost (30s).

### 10.3 Egg odds

| Egg | Outcomes |
|---|---|
| Halloween Egg | Skeleton 40% (1x best), Skeleton Horse 28% (1.5x), Demon 17% (2x), Reaper Steed 10% (3x), Reaper 4% (5x), Pumpkin Monster 1% (9x). Expected value about 1.75x best animal. [S1] [GG-eggs] |
| Magma Egg | Cockatrice 60% ($8B/s), Gargoyle Bat 30% ($30Qa/s), Wyvern 9% ($180Qi/s), Dragon 1% ($270Qi/s). Fixed animals, not percentages. [S1] [GG-eggs] |
| Rainbow Egg | one random animal from near your throw spot, Rainbow mutation at GIGANTIC size (about x769 base). [S1] [GG-eggs]; product text says "Rainbow-mutated, Giant animal" [API-products] |
| Enchanted Egg | six outcomes at 40 / 27 / 18 / 10 / 4 / 1 %, pets worth 110% to 1200% of best animal. [USER]; "up to 1200%" confirmed by [API-products]. Pet names not published anywhere. |

Design note [INF]: "% of your best animal" pets never go obsolete, so they stay worth buying at every stage; this is the game's main whale hook together with lucky throws.

### 10.4 Other

- Starter pack: none named "starter"; the Ultra Pack (640 R$) is the only bundle. [S1] [API-products]
- GIFT button in the Robux shop [USER]; only the two passes have gift products in the catalogue [API-products].
- Private servers: API flag createVipServersAllowed = false [API-game], and a stats site says VIP creation is off [TF-faq]; Sportskeeda says private servers cost 14 R$/month [SK-aa]. Conflict; the API is the more direct source.
- Earning rank: #6 on Roblox Top Earning (Oct 29-Nov 14). [S1] [RT-stats]

**UNKNOWN:** Enchanted Egg pet names; whether Rainbow Egg is still on sale; how "100x luck" and "best of 30 rolls" interact with Server Luck; whether lucky throws are also given free anywhere other than Admin Abuse; any first-purchase or timed-offer popups; whether prices differ per platform.

---

## 11. Social / multiplayer

- **5 players per server**, and servers run full (average 5.0). [C2+] [API-game], [RL-stats], [TS-codes]
- Private servers: see 10.4 (probably off).
- **Leaderboards** on the hub walls: Most Animals (animals caught), Top Money (total money earned), Luckiest Catch (highest lucky score). [C2+] [ATH-foods], [USER]. YouTubers treat "#1 on the leaderboard" as the end goal [YT-vindooly], [YT-meenyu], [YT-bacha].
- **Server Luck** is the only shared mechanic: one player's purchase boosts all five. A fan site notes it is wasted in an empty server. [C2+] [API-products], [TF-how]
- **Gifting** of the two passes. [S1] [API-products]
- **Trading: none documented.** Search for trading found only off-platform marketplaces. [INF: no trading]
- **Stealing / raiding: none documented.** [INF]
- Visiting other plots: not documented either way. With 5 plots along one lane head, other players' plots and animals are presumably visible; a "pet visibility" setting was added Nov 7, which suggests other players' pets are rendered. [INF] [SK-u3]
- Friend boosts, group-join rewards, like rewards: none documented. [TS-codes]
- Community: Roblox group "Goofy Chupacabra" (222,945 members on Nov 14) [API-group]; official Discord "Throw Food for Animals" (about 10.4K members), has a suggestions channel; the full changelog is said to live there [SK-u3], [DISCORD-invite].

**UNKNOWN:** whether you can walk onto other plots; whether other players' throws/animals are visible in the lane; any co-op or competitive mechanic besides leaderboards; whether leaderboards are global or per server; reset cadence of leaderboards.

---

## 12. Live ops

### 12.1 Cadence

Weekly, Saturdays, announced as Roblox event cards, typically 14:00 UTC (9:00 AM ET), each paired with a 30-60 minute "Admin Abuse" session; the content update goes live right after. [C2+] [TS-codes], [BC-aa], [ATH-countdown], [API-events]

### 12.2 Timeline

| Date (UTC) | What | Source | Confidence |
|---|---|---|---|
| 2026-09-18 21:29 | Experience created | [API-game] | C2+ |
| 2026-09-30 | Both gamepasses created | [API-passes] | S1 |
| 2026-10-24 | Title prefix changed from meat emoji to pumpkin; first appears on Up-and-Coming / Top Trending | [NTP-game] | S1 |
| 2026-10-25 to 11-01 | "Halloween Update" event: two new maps, more food and animals; Halloween Egg, Pumpkin Monster | [BX-wiki], [ATH-countdown], [TFA-eggs] | C2+ |
| 2026-10-25 / 27 / 29 / 30 | CCU passes 10K / 25K / 50K / 100K | [NTP-game] | S1 |
| 2026-10-31 16:00-17:00 | "NEW MAP + ADMIN ABUSE" (first Admin Abuse, "Halloween night"); a nuclear-themed zone appears in videos right after | [API-events], [SK-aa], [YT-search] | C2+ for the event, S1 for content |
| 2026-11-05 | Title prefix removed | [NTP-game] | S1 |
| 2026-11-07 14:00-14:30 | "New Map + Admin Abuse" = "Update 3": Cursed Carnival + Eclipse Kingdom (12 animals each), 8 foods (tiers 18-19), Sovereign rarity, 12 new bars, higher strength cap, music/SFX/pet-visibility settings, zone ambience, a ring minigame | [API-events], [SK-u3], [BX-zones], [NC-update], [YT-bacha] | C2+ |
| about 2026-11-07/08 | All-time peak CCU 1,560,200 | [RL-stats] | C2+ (RoWatcher 1.6M, RoTrends 1.5M) |
| 2026-11-07 | CCU passes 250K sustained | [NTP-game] | S1 |
| 2026-11-08 to 11-12 | Enchanted Egg, training packs, 2x Offline Earnings appear in catalogue (by product id order) | [API-products], [TS-codes] | INF |
| 2026-11-14 14:00-15:00 | "NEXT UPDATE!" event card; contents unannounced at research time | [API-events], [ATH-next] | C2+ |

Growth speed: 111.4M visits on Nov 8 [TS-codes] to 215.2M on Nov 14 [API-game], i.e. about 100M visits in six days. [C2+]

### 12.3 Admin Abuse events

- Developers join and switch on global boosts for about 30 minutes: **Luck Boost** (up to 16x; better animals, mutations, sizes), **Power Boost** (more Throw Power, faster pull-ups, more XP per pull-up), **Money Boost** (2x income), and **free Lucky Throws** for everyone present (they stay in inventory afterwards). [C2+] [RB-aa], [PGG-aa], [BC-aa]
- Boosts apply across servers. [S1] [SK-aa]
- RSVP scale: over 500K interested for Oct 31, over 380K for Nov 7, about 170K signed up for Nov 14 (a day before). [S1] [ATH-countdown]
- A commenter notes one expected session "did not happen on Saturday" (schedule confusion). [S1] [YT-kriphie]

### 12.4 Other live elements

- No weather system, no rotating shop stock, no machines as of early November. [C2+] [GGG-mut], [SK-mut]
- Limited items: Halloween Egg / Pumpkin Monster (seasonal), Rainbow Egg (LIMITED tag), Magma Egg (retired), four "limited-time" Robux animals. [C2+] [API-products], [GG-eggs], [USER]

**UNKNOWN:** what the Nov 14 update added; exact contents of "Update 1" and "Update 2" (guides use the labels without a changelog); whether Admin Abuse includes special spawns or drops beyond the boosts; whether events add temporary zones.

---

## 13. Onboarding: the first five minutes

Assembled from several sources; no single source gives the full tutorial script. Order of steps 1-5 is [S1] from a fan site summarising a beginner video [TF-how] plus [ATH-foods]; individual facts are tagged.

1. Spawn on your own plot at the head of the lane. A starter **Carrot** is already equipped. [C2+] [BX-wiki], [GR-foods]
2. Guided to the throw strip. "TAP TO THROW!" with the 0-20 meter. First throw lands in Forest and brings a **Frog ($2/s)** or **Bunny ($3/s)**. Result card with NEW!. [C2+] [TFA-home], [TF-how], [BX-wiki]
3. The animal ends up on the plot and starts earning; label over its head shows $/s. Money counter starts ticking. [C2+]
4. "Throw again" prompt above the booth. A couple more Forest throws. [C2+] [ATH-foods], [USER]
5. Objective "**Buy new food**" with a **yellow arrow** to the Food Shop stall. Step into the ring, buy **Apple ($30)**, see "Bought Apple!", then tap **EQUIP**. [S1] [ATH-foods]
6. Tutorial ends; the **pull-up bar unlocks**. Train (Level 1 upward, +5 Throw Power per level); buy **Steel Bar ($50, +2 XP/rep)** when "NEW EQUIPMENT!" pops. [C2+] [GGG-beginner], [PGG-beginner], [BX-beginner]
7. Shop button shows **FREE**: claim the free **Hyena ($200/s)**, which is about 8x the best Forest animal and makes Banana ($150) and Toast ($4K) quickly affordable. [C2+] [TFA-free], [TF-how], [ATH-mut]
8. "NEW FOOD UNLOCKED!" popups pull the player back to the shop each time cash crosses a price. [C2+] [ATH-foods], [ATH-aa]
9. Around level 28 (a few minutes on the bar) a perfect throw first reaches **Savanna**; the zone banner and a jump from single-digit to $40-$320/s animals is the first "new zone" moment. One beginner video trained to about 100 power before buying Banana and Toast. [C2+ for level 28: GG-home; S1 for the video detail: TF-how]
10. Plot fills toward 10; the player meets EQUIP BEST and the SELL stand. [C2+]

Hints and guidance devices seen: yellow arrow to objectives; objective text; "TAP TO ENTER!/TAP TO THROW!" prompts; "Throw again" sign; unlock popups with a Shop shortcut button; NEW!/NEW BEST! tags; a "Details" button for odds. [C2+ collectively]

**UNKNOWN:** the exact scripted tutorial steps and their wording; whether the first throw is forced/rigged; how long the tutorial takes; whether there is an intro cutscene; when the Robux shop and eggs are first shown; whether the Index and leaderboards are introduced or left to discovery.

---

## 14. Stats

| Stat | Value | Date | Source | Confidence |
|---|---|---|---|---|
| Developer | Group "Goofy Chupacabra" (id 670988975), not verified | Nov 14 | [API-game], [API-group] | C2+ |
| Group owner | user "misfitsbsthree", display name "ben", verified badge; profile says "Ben from Steal an Egg" and lists alt accounts MisfitsBS etc. | Nov 14 | [API-group], [API-user] | S1 (API) |
| Earlier group owner | KosmicarIII (as shown Oct 30) | Oct 30 | [TF-faq] | S1 |
| Group members | 222,945 (127,473 on Nov 8; about 175K a few days later) | Nov 14 | [API-group], [TS-codes], [NTP-game] | C2+ |
| Universe id | 10766972131 | | [API-universe] | S1 (API) |
| Created | 2026-09-18 21:29 UTC | | [API-game] | C2+ |
| Last updated | 2026-11-14 01:31 UTC | Nov 14 | [API-game] | S1 (API) |
| Visits | 215,243,525 | Nov 14 | [API-game] | C2+ (Rolimons 215.19M) |
| Playing now | 426,424 | Nov 14 | [API-game] | C2+ (Rolimons 426,521; RoTrends 417,984) |
| All-time peak CCU | 1,560,200 (about Nov 7-8) | | [RL-stats] | C2+ ([RW-stats] 1.6M, [RT-stats] 1.5M, [BX-stats] 1.4M) |
| Avg CCU (7d / 14d) | 238K / 177K | Nov 14 | [RT-stats] | S1 |
| Favourites | 214,985 | Nov 14 | [API-game] | C2+ |
| Votes | 112,703 up / 6,672 down = 94.4% | Nov 14 | [API-votes] | C2+ |
| Average session | 20.6-21.0 minutes | Nov 14 | [RT-stats], [RL-stats] | C2+ |
| Charts | #4 Top Playing Now, #3 Most Popular, #1 Top Trending, #1 Trending in Simulation, #6 Top Earning, #82 Top Revisited | Oct 29-Nov 14 | [RT-stats] | S1 |
| Genre | Simulation / Tycoon | | [API-game] | C2+ |
| Max server size | 5 | | [API-game] | C2+ |
| Avatar type | MorphToR15 | | [API-game] | S1 (API) |
| Private servers | creation not allowed (API flag) | Nov 14 | [API-game] | see 10.4 |
| Badges | none | Nov 14 | [API-badges] | C2+ ([RL-stats]) |
| Supported devices | Not returned by the API. A fan wiki shows "PC" only [TFA-home]; another fan site links PC, Mac and phone clients [TF-home]. All UI prompts say "TAP". | | | UNKNOWN officially; mobile support is [INF] |
| Server ping / FPS (Rolimons sample) | ping avg 131 ms, FPS avg 59.5 | Nov 14 | [RL-stats] | S1 |
| Exploit scripts | 53 scripts listed on one aggregator (search-result text only; page blocked) | Nov 11 | search result | S1, unopened |

**UNKNOWN:** official device list and whether console is supported; daily visit/CCU history; retention figures; ad spend or sponsorship; who actually builds the game (see 15.2).

---

## 15. Player complaints and praise

Honest note on evidence: Roblox has no review text, the group wall and Discord are not publicly readable, and no Reddit thread turned up in three searches. What exists is (a) YouTube comment samples (about 20 visible comments per video out of hundreds, eight videos sampled), (b) cautions written by guide authors, (c) behaviour visible in the numbers. Sample sizes are small; treat each item as a lead, not a measured rate. Items marked [INF] are my design reading, not something a player said.

### 15.1 Complaints and friction (what players actually said)

1. **Pay-to-win, getting worse with updates.** "The pay-to-win developers need to be stopped; free players suffer with each update" (12 likes) [YT-bacha]. A commenter mocks a YouTuber's method as "play briefly, pay to win, become #1" [YT-vindooly]. Another calls the 9 R$ rainbow lucky throws "overpowered" [YT-vindooly]. A child writes that the game is "too expensive, my mom would say no" [YT-foltyn]. A guide author warns "don't assume a paid run reflects free-play speed" and that copying a YouTuber's completion time leads to unnecessary purchases [KK-guide]. [C2+ as a theme]
2. **Distrust of the developer.** Top comment (81 likes) on a 626K-view video claims "Ben" is not a solo dev but the front man of a larger company who plays small to sell "support the dev" purchases; others add he also owns "DONT SPLASH!" [YT-bacha], [YT-bemmy-end]. The group owner's own profile says he is "Ben from Steal an Egg" [API-user]. [C2+ that the perception exists; the corporate claim itself is unverified]
3. **Too short / too easy for free players too.** "Actually easy: 5 hours from the start to Nuclear Wasteland"; "easiest game, finished in 6 hours without Robux" [YT-peach]. Content is consumed faster than weekly updates add it. [S1 video, several commenters]
4. **The catch cutscene is an annoyance once you grind.** Two commenters share tricks to skip it (throw then reset character; a click trick to stop it replaying) [YT-bemmy-inf], [YT-bacha]. People reset their character to avoid watching it. [C2+ across two videos]
5. **Opaque luck.** Viewers ask how to get "100x luck", "30x luck", "rainbow carrots" and how a YouTuber got a specific huge animal [YT-jinn], [YT-peach]; "luck only happens when he throws, I always get normal" [YT-jinn]; players ask whether Infinite is really the top size or whether "colossal" is a rarity [YT-meenyu], [YT-bemmy-inf]. Guide authors warn that the displayed rarity number is not your real chance [KK-guide] and that the "1 in 999B" banner is marketing art [TS-codes]. The real odds live behind a "Details" button that only appears during throw prep [GGG-mut]. [C2+ as a theme]
6. **RNG envy toward paid/creator luck.** Videos are titled around "infinite lucky throws" and "100 max-luck throws" [YT-search]; ordinary players compare their results with those and feel unlucky. [INF from 5 and the video titles]
7. **Event schedule confusion.** "Was there admin abuse earlier?" / "it did not happen on Saturday" [YT-kriphie]. Guide sites publish conflicting local times for the same event [RB-aa]. [S1]
8. **Genre fatigue.** "People already played that game" [YT-techy]; a viewer laments a creator's shift to "brainrot" games [YT-peach]; one flat "this game is trash" [YT-kriphie]. 5.6% of votes are dislikes [API-votes]. [S1 each]
9. **Exploits and automation.** Many auto-farm scripts are advertised ("Auto Perfect Throw, Auto Buy, Auto Sell"; search-result titles only), and commenters trade a throw-then-reset glitch. This means the core loop is repetitive enough that players want it automated, and that the top of the leaderboards is contaminated. [INF]

### 15.2 Praise and what clearly works

1. **Numbers.** 94.4% like ratio on 119K votes, about 21-minute average session, #1 Top Trending for three weeks, 1.56M peak CCU [API-votes], [RT-stats], [RL-stats]. [C2+]
2. **The throw is watchable.** The whole YouTube wave is built on the moment the food flies through zones and the odds counter rolls; titles are about distance, "end of zone", "rarest animal", "infinite size" [YT-search]. [INF]
3. **Leaderboard chase.** Several creators make "#1 player" videos; commenters cheer leaderboard appearances [YT-bacha], [YT-vindooly], [YT-meenyu]. [C2+]
4. **Updates land well.** "Update was pretty good" [YT-bemmy-end]; CCU rose 9-15% in the 48 h after each tracked update [BX-stats]. [C2+]
5. **Offline income** is repeatedly cited by guides as a reason to come back [PGG-beginner], [GGG-beginner]. [C2+]
6. **Low friction start.** First animal within one throw; guides call the early result "an animal earning money" [TFA-beginner]. [S1]
7. Viewers say they "love the new game" and want "more animal games" [YT-vindooly], [YT-foltyn]. [S1 each]

### 15.3 Where players probably quit (my reading of the structure, all [INF])

- **End of content.** A free player reaches the last zone in 5-6 hours; after that the only goals are mutation/size RNG and leaderboards that paying players dominate. There is no rebirth to restart the curve.
- **The long zones.** From Shadow Realm on, zones are 900-1,800 studs long (180-360 levels each) versus 34 levels early. The pleasant "new zone every few minutes" rhythm stops.
- **Plot capacity wall.** 10 slots for the first four zones, then prices of $40M, $200T, $50Qi. For long stretches the only way to raise income is replacing animals, so most catches are instantly sold for 20 seconds of income, which makes ordinary throws feel worthless.
- **Selling is pointless** (20 x $/s). Duplicates have no use: no merging, no trading, no feeding.
- **Solo experience in a 5-player server.** Nothing to do with other players except share a paid luck boost.
- **One-tap skill ceiling.** The meter adds at most 20 studs on throws of thousands of studs, so the only skill input becomes irrelevant after the first zones.

### 15.4 What players say they wish it had

Explicit wishes are rare in the samples. Seen: clearer explanation of luck sources [YT-jinn], [YT-peach]; a way to skip the cutscene [YT-bemmy-inf]; less pay-to-win pressure for free players [YT-bacha]; "more animal games" [YT-foltyn]. The Discord has a suggestions channel that could not be read [DISCORD-invite].

**UNKNOWN:** what the Discord suggestions channel asks for most; day-1/day-7 retention; reported bugs or data loss (none seen in samples); how mobile players experience the meter; whether lag is an issue at 5 players (Rolimons sample shows 59.5 FPS average).

---

## FLOW: one complete player session, from joining to the long-term milestone

There is no rebirth, so the milestone used is "reach the end of the lane / last zone", which free players report takes about 5-6 hours for the 17-zone version. Step facts are tagged in the sections above; this list is the stitched sequence.

1. Join; land on your fenced plot at the head of the lane with 4 other players' plots nearby. If returning: "Welcome Back!" popup pays offline income (2 min per hour away, 48 h cap), CLAIM or pay for 2X.
2. Carrot is equipped. Walk onto the throw strip: "TAP TO ENTER!", then the 0-20 meter, "TAP TO THROW!".
3. Camera follows the food; Luck multiplier climbs; food lands in Forest (18-38 studs at level 1).
4. An animal approaches; odds counter rolls; result card: Frog $2/s, NEW!.
5. Animal is now yours and earning on the plot. "Throw again" sign lights.
6. Repeat a few throws. Objective "Buy new food": yellow arrow to the Food Shop; buy Apple ($30); EQUIP.
7. Tutorial ends; pull-up bar unlocks. Hop on; reps auto-cycle; tap the purple x2 popup when it appears; STOP when bored. Each level: "+5 Throw Power".
8. Buy Steel Bar ($50, 2 XP/rep). Claim the FREE Hyena ($200/s) from the Shop.
9. Loop A (minutes 2-15): throw, collect, check plot, buy Banana ($150) and Toast ($4K), buy Gold Bar ($2K) and Cyan Bar ($12K), train to level 28 and reach Savanna, then level 62 and Desert.
10. Plot hits 10/10. Open Animals: EQUIP BEST. Walk into the SELL ring: "Sell N animals for $X" clears the backpack.
11. Loop B (first hour): for each zone, (a) train until a perfect throw reaches the back third, (b) buy the three foods tuned for the zone in order, (c) throw until the top-rank animal fills the plot, (d) spend the income on the next bar. First mutation and size tags (GOLD, BIG) appear; first LUCKY! stamps.
12. At about $40M (Ocean) buy plot 10 to 12.
13. Index button shows zone sets filling ("Forest 8/8"); claim the zone's cash reward.
14. Loop C (hours 1-5): zones lengthen; each needs 50-200+ levels. Sessions become: claim offline cash, buy whatever is affordable, park on the bar, throw 10-20 times, EQUIP BEST, SELL ALL, leave. Plot 12 to 14 at $200T (Prehistoric Forest), 14 to 16 at $50Qi (Mythical Paradise).
15. Saturday 14:00 UTC: join for Admin Abuse (16x luck, power boost, 2x money, free lucky throws); new zones unlock right after.
16. Reach Nuclear Wasteland (about level 1.2K) and then the lane end (about level 1.6K); since Nov 7, continue into Cursed Carnival and Eclipse Kingdom with tier 18-19 foods.
17. End state: plot full of top-zone animals; remaining goals are Index 164/164, Rainbow/Infinite rolls via lucky throws, the three leaderboards, and waiting for next Saturday.

---

## Open questions that only playing the game would answer

| # | Question | Why it matters for our design |
|---|---|---|
| 1 | How long is one full throw cycle (enter, meter, flight, roll, card, back to ready) at Forest, Ocean and late zones? Does flight time scale with distance or is it capped/sped up? | Core loop pacing and session rhythm |
| 2 | Does the meter sweep once or oscillate? Does its speed change with level or food? | Skill expression of the only input |
| 3 | After the roll, is the animal auto-added, or must the player walk to it / press a prompt? Does it go to backpack or straight onto the plot when there is space? | Sources contradict each other |
| 4 | Can the flight and the catch cutscene be skipped without resetting the character? | Biggest reported friction |
| 5 | Is there any cooldown between throws? Any auto-throw toggle or gamepass not in the catalogue? | Grind feel; automation demand |
| 6 | What does the "Details" panel show exactly (animal odds, mutation odds, size odds, luck)? | How transparent the RNG is |
| 7 | How does the Luck multiplier change the odds (animal rank? mutation? size? score only)? | Whether distance beyond a zone's back third is worth anything |
| 8 | Exact rep interval on the bar and what the purple x2 popup does (extra rep vs timed 2x) and for how long | Training pacing; sources disagree |
| 9 | XP needed per level at levels 1-30, 60, 100, 130 | Reconstruct the level curve |
| 10 | Plot upgrade prices beyond 16 slots and the maximum | Capacity curve |
| 11 | Do animals wander inside the fence or stand on fixed pads? Does size take more room? | Plot presentation |
| 12 | Is income fully automatic, or is there any walk-over / collect interaction? | Active vs idle balance |
| 13 | Index reward amount per zone and for full completion | Collection incentive strength |
| 14 | Rarity tile colours, and the visual treatment of each mutation and size title | UI/art reference |
| 15 | The scripted tutorial: exact steps, wording, arrows, forced first catch, duration | Onboarding beat sheet |
| 16 | When and how the Robux shop, eggs, lucky-throw button and 2X offline are first surfaced (popups? timers? first-session offers?) | Monetisation pressure map |
| 17 | What the ring minigame / "Ring Rush" is, where it sits and what it pays | New system since Nov 7 |
| 18 | What players mean by "bosses" in each zone | Possible system no guide documents |
| 19 | Can you enter other players' plots or see their throws and animals? Are leaderboards global or per server? | Social design gap |
| 20 | Enchanted Egg pet names and what "LIMITED" Rainbow Egg availability looks like | Egg design reference |
| 21 | Any daily reward, playtime gift, quest board or like/group reward that guides ignored | Retention systems inventory |
| 22 | Does the game run on phone/tablet/console, and how does the meter feel on touch | Device support |
| 23 | Stud ranges, animals, incomes of Cursed Carnival and Eclipse Kingdom; new level cap | Current end-game numbers |
| 24 | What the 2026-11-14 update added | Freshness |
| 25 | Does anything carry "pity" (guaranteed NEW after N throws) beyond the repeat penalty | Collection completion feel |

---

## Sources opened

Fetch notes: progameguides.com and gameboost.com returned HTTP 403 to direct fetch and were read through the r.jina.ai reader proxy (same public pages). YouTube pages were read through the same proxy; only metadata, auto-chapters and the first about 20 comments were visible (no transcripts). scriptblox.com (403) and the Roblox group wall API (404) could not be read at all. The Roblox game page itself rendered only the description, so stats come from the public Roblox APIs.

| Key | What | URL |
|---|---|---|
| ROBLOX-page | Roblox game page (description only) | https://www.roblox.com/games/120219252362013/Throw-Food-For-Animals |
| API-universe | place to universe id | https://apis.roblox.com/universes/v1/places/120219252362013/universe |
| API-game | game record (visits, playing, favourites, dates, max players, genre) | https://games.roblox.com/v1/games?universeIds=10766972131 |
| API-votes | up/down votes | https://games.roblox.com/v1/games/votes?universeIds=10766972131 |
| API-passes | gamepasses | https://apis.roblox.com/game-passes/v1/universes/10766972131/game-passes?passView=Full&pageSize=100 |
| API-products | 50 developer products with prices and descriptions | https://apis.roblox.com/developer-products/v2/universes/10766972131/developerproducts?limit=100 |
| API-group | group record | https://groups.roblox.com/v1/groups/670988975 |
| API-user | group owner's user record | https://users.roblox.com/v1/users/10751598093 |
| API-badges | badges (none) | https://badges.roblox.com/v1/universes/10766972131/badges?limit=100&sortOrder=Asc |
| API-events | event cards | https://apis.roblox.com/virtual-events/v1/universes/10766972131/virtual-events |
| DISCORD-invite | official Discord invite metadata | https://discord.com/api/v9/invites/GX55aFxKQV?with_counts=true |
| GG-home | game.guide hub (zones with studs/levels, all animals) | https://www.game.guide/throw-food-for-animals |
| GG-areas | game.guide areas | https://www.game.guide/throw-food-for-animals/areas |
| GG-animals | game.guide animals | https://www.game.guide/throw-food-for-animals/animals |
| GG-foods | game.guide foods | https://www.game.guide/throw-food-for-animals/foods |
| GG-bars | game.guide training bars | https://www.game.guide/throw-food-for-animals/training-bars |
| GG-calc | game.guide training calculator | https://www.game.guide/throw-food-for-animals/training-calculator |
| GG-mut | game.guide mutations and sizes | https://www.game.guide/throw-food-for-animals/mutations |
| GG-eggs | game.guide eggs and shop | https://www.game.guide/throw-food-for-animals/eggs-and-shop |
| GG-catch | game.guide catch calculator | https://www.game.guide/throw-food-for-animals/catch-calculator |
| GG-income | game.guide income calculator | https://www.game.guide/throw-food-for-animals/income-calculator |
| GGG-beginner | games.gg beginner guide (Nov 2) | https://games.gg/roblox/guides/roblox-throw-food-for-animals-beginners-guide/ |
| GGG-mut | games.gg mutations and sizes (Nov 6) | https://games.gg/roblox/guides/roblox-throw-food-for-animals-mutations-sizes-guide/ |
| PGG-beginner | Pro Game Guides beginner guide (Oct 31), via proxy | https://progameguides.com/roblox/complete-throw-food-for-animals-beginners-guide-roblox/ |
| PGG-mut | Pro Game Guides mutations (Nov 6), via proxy | https://progameguides.com/roblox/throw-food-for-animals-mutations-sizes-chances-multipliers/ |
| PGG-aa | Pro Game Guides admin abuse, via proxy | https://progameguides.com/roblox/throw-food-for-animals-admin-abuse/ |
| TFA-home | throw-food-for-animals.wiki home (snapshot Oct 29) | https://throw-food-for-animals.wiki/ |
| TFA-beginner | same wiki, beginner guide | https://throw-food-for-animals.wiki/guides/beginner-guide |
| TFA-howto | same wiki, how to play | https://throw-food-for-animals.wiki/guides/how-to-play |
| TFA-timing | same wiki, throw timing | https://throw-food-for-animals.wiki/training/throw-timing |
| TFA-bars | same wiki, bar upgrades | https://throw-food-for-animals.wiki/training/bar-upgrades |
| TFA-power | same wiki, throw power | https://throw-food-for-animals.wiki/training/throw-power |
| TFA-food | same wiki, food upgrades / best food | https://throw-food-for-animals.wiki/food/food-upgrades and https://throw-food-for-animals.wiki/food/best-food |
| TFA-mut | same wiki, mutations | https://throw-food-for-animals.wiki/animals/mutations |
| TFA-eggs | same wiki, Halloween eggs | https://throw-food-for-animals.wiki/animals/halloween-eggs |
| TFA-updates | same wiki, updates | https://throw-food-for-animals.wiki/updates/latest-updates |
| TFA-plot | same wiki, plot upgrades | https://throw-food-for-animals.wiki/animals/plot-upgrades |
| TFA-free | same wiki, free animal | https://throw-food-for-animals.wiki/animals/free-animal |
| TFA-sell | same wiki, sell animals | https://throw-food-for-animals.wiki/animals/sell-animals |
| TFA-get | same wiki, how to get animals | https://throw-food-for-animals.wiki/animals/how-to-get-animals |
| TFA-tips | same wiki, tips and tricks | https://throw-food-for-animals.wiki/guides/tips-and-tricks |
| BX-wiki | Bloxodes wiki hub (events, passes, stats) | https://bloxodes.com/wiki/throw-food-for-animals |
| BX-foods | Bloxodes foods (Oct 30) | https://bloxodes.com/wiki/throw-food-for-animals/foods |
| BX-zones | Bloxodes Update 3 zones and foods (Nov 8) | https://bloxodes.com/articles/throw-food-for-animals-zones-food-guide |
| BX-luck | Bloxodes luck guide (Nov 4) | https://bloxodes.com/articles/throw-food-for-animals-luck-guide |
| BX-beginner | Bloxodes beginner guide (Nov 1) | https://bloxodes.com/articles/throw-food-for-animals-beginners-guide |
| BX-tier | Bloxodes tier list (Nov 6) | https://bloxodes.com/articles/throw-food-for-animals-tier-list |
| BX-mut | Bloxodes mutations (Nov 6) | https://bloxodes.com/articles/throw-food-for-animals-mutations-guide |
| BX-stats | Bloxodes stats page | https://bloxodes.com/stats/games/throw-food-for-animals-10766972131 |
| RB-animals | Roonby all animals (Nov 11) | https://roonby.com/2026/11/11/all-animals-in-throw-food-for-animals-complete-index-and-income-list/amp/ |
| RB-beginner | Roonby beginner guide (Nov 11) | https://roonby.com/2026/11/11/throw-food-for-animals-beginner-guide-best-upgrades-food-and-money-farming-tips/amp/ |
| RB-aa | Roonby admin abuse (Nov 6) | https://roonby.com/2026/11/06/throw-food-for-animals-admin-abuse-event-guide-when-what-to-prepare/amp/ |
| ATH-foods | AllThingsHow: all food items and shop prices (Oct 31) | https://allthings.how/?p=318591 |
| ATH-mut | AllThingsHow: mutation guide / throw power training (Nov 7) | https://allthings.how/?p=330669 |
| ATH-zones | AllThingsHow: food and zone list (Nov 7) | https://allthings.how/?p=330932 |
| ATH-luck | AllThingsHow: luck guide, biome multipliers (Nov 5) | https://allthings.how/?p=327859 |
| ATH-aa | AllThingsHow: admin abuse schedule (Nov 7) | https://allthings.how/?p=330623 |
| ATH-next | AllThingsHow: next update Nov 14 (Nov 9) | https://allthings.how/?p=350623 |
| ATH-countdown | AllThingsHow: next update countdown and history | https://allthings.how/?p=315470 |
| ATH-prep | AllThingsHow: when is the next update and how to prepare (Nov 4) | https://allthings.how/?p=325247 |
| GB-pets | GameBoost all pets (Nov 9), via proxy | https://gameboost.com/blog/all-pets-throw-food-for-animals |
| GB-foods | GameBoost all foods (Nov 9), via proxy | https://gameboost.com/blog/throw-food-for-animals-all-foods |
| GB-codes | GameBoost codes and tips, via proxy | https://gameboost.com/blog/throw-food-for-animals-codes |
| GR-foods | GameRant all food (Nov 6) | https://gamerant.com/roblox-throw-food-for-animals-all-food-list-how-to-get/ |
| SK-u3 | Sportskeeda Update 3 patch notes (Nov 8) | https://www.sportskeeda.com/roblox-news/throw-food-for-animals-update-3-patch-notes |
| SK-mut | Sportskeeda mutations guide | https://www.sportskeeda.com/roblox-news/throw-food-for-animals-mutations-guide |
| SK-luck | Sportskeeda how to get luck | https://www.sportskeeda.com/roblox-news/how-get-luck-throw-food-for-animals |
| SK-sizes | Sportskeeda pet sizes | https://www.sportskeeda.com/roblox-news/all-pet-sizes-throw-food-for-animals |
| SK-aa | Sportskeeda next admin abuse | https://www.sportskeeda.com/roblox-news/when-next-throw-food-for-animals-admin-abuse |
| SK-beginner | Sportskeeda beginner guide | https://www.sportskeeda.com/roblox-news/throw-food-for-animals-a-beginner-s-guide |
| OZ-mut | Of Zen and Computing mutations and sizes | https://www.ofzenandcomputing.com/throw-food-for-animals-mutations-and-sizes/ |
| NC-update | Nerds Chalk update regions/pets/food (Nov 7) | https://nerdschalk.com/throw-food-for-animals-update-regions-pets-food/ |
| TS-codes | Timesaver.gg codes page (Nov 8) | https://timesaver.gg/blog/throw-food-for-animals-codes |
| DX-codes | Dexerto FR codes (Nov 11) | https://www.dexerto.fr/roblox/codes-throw-food-for-animals-1663873/ |
| BC-aa | BeatCop admin abuse schedule | https://beatcopgame.com/throw-food-animals-admin-abuse-event-schedule-what-to-expect/ |
| EL-aa | Eldorado admin abuse schedule | https://www.eldorado.gg/blog/roblox-en/throw-food-for-animals-admin-abuse-time-and-schedule/ |
| TX-update | Treyex Gaming new map update guide (Nov 7) | https://www.treyexgaming.com/?p=19760 |
| SG-update | Stealthy Gaming new map + admin abuse | https://stealthygaming.com/?p=36964 |
| KK-guide | kakao.gg upgrade-priority guide | https://www.kakao.gg/en/games/roblox/roblox-throw-food-for-animals-guide-when-to-upgrade-throw-power-or-food |
| CZ-guide | Cardzy blog (Nov 9) | https://cardzy.pl/en/blog/throw-food-for-animals-how-to-get-rare-animals-and-earn-cash |
| TF-home | throwfoodforanimals.com home | https://throwfoodforanimals.com/ |
| TF-how | throwfoodforanimals.com how to play (summarises YouTube beginner videos) | https://throwfoodforanimals.com/guides/how-to-play/ |
| TF-updates | throwfoodforanimals.com updates | https://throwfoodforanimals.com/updates/ |
| TF-faq | throwfoodforanimals.com FAQ | https://throwfoodforanimals.com/faq/ |
| TFW-home | throwfoodforanimals.wiki home (Oct 29 snapshot; no numbers) | https://www.throwfoodforanimals.wiki/ |
| TFW-update | throwfoodforanimals.wiki latest update | https://www.throwfoodforanimals.wiki/updates/Throw-Food-For-Animals-latest-update |
| NTP-game | newtoplay.com game page (milestones, renames) | https://newtoplay.com/games/throw-food-for-animals |
| RT-stats | RoTrends | https://www.rotrends.com/game/10766972131/Throw-Food-For-Animals |
| RW-stats | RoWatcher | https://rowatcher.com/games/10766972131/throw-food-for-animals |
| RL-stats | Rolimons | https://www.rolimons.com/game/120219252362013 |
| YT-search | YouTube search results (titles, views) | https://www.youtube.com/results?search_query=throw+food+for+animals+roblox |
| YT-bacha | BachaBlox, "I Can't be Stopped..." (Nov 7, 626K views) | https://www.youtube.com/watch?v=5ZDY1S2Z078 |
| YT-vindooly | Vindooly, "I Became The #1 Player..." (Nov 11, 308K) | https://www.youtube.com/watch?v=FJHE6Cs-Bkk |
| YT-foltyn | FoltynPlays (Oct 30, 907K) | https://www.youtube.com/watch?v=55cCOFQ6pzk |
| YT-peach | peach plays, "I Spent 24 Hours..." (Nov 13) | https://www.youtube.com/watch?v=oWgwgRLCVuY |
| YT-kriphie | Kriphie, admin abuse video (Nov 12) | https://www.youtube.com/watch?v=VuZM_ygVIvA |
| YT-bemmy-end | BemmyBlox, "end of new rarest zone" (Nov 7) | https://www.youtube.com/watch?v=Wmv0qdMxCC4 |
| YT-bemmy-inf | BemmyBlox, infinite size (Nov 12) | https://www.youtube.com/watch?v=4kIfU9IkArQ |
| YT-meenyu | MeEnyu, "#1 Player" (Nov 5) | https://www.youtube.com/watch?v=Mfj3jya9QLk |
| YT-jinn | Jinn, "100 hours" (Nov 8) | https://www.youtube.com/watch?v=pJtWX6mA5CM |
| YT-techy | More Techy (Nov 6, 479K) | https://www.youtube.com/watch?v=0TzFeq9ro1I |
| YT-basic | BasicBlox beginner run (Oct 28) | https://www.youtube.com/watch?v=dq4m5qt1sEw |
| YT-caylus | CaylusBlox (Oct 29; comments not visible) | https://www.youtube.com/watch?v=D6wVp6vArzU |

Not found / not available: no Fandom wiki, no Beebom / Pocket Tactics / Try Hard Guides / Destructoid pages for this game in search results, no Reddit threads, no official patch notes outside Discord.
