#!/usr/bin/env python3
"""Economy v2: the 17-zone ladder, designed from pacing targets and checked by simulation.

    python tools/economy/econ_v2.py gen            # the numbers from the pacing targets -> 12-economy-draft.json
    python tools/economy/econ_v2.py apply          # writes those numbers into design/game.json `config`
    python tools/economy/econ_v2.py sim            # plays the draft, prints the milestone table
    python tools/economy/econ_v2.py sim --live --profile passes --runs 5    # plays design/game.json
    python tools/economy/econ_v2.py check          # the pacing GATE: game.json against config.Pacing
    python tools/economy/econ_v2.py odds           # the odds tables for the plan

To retune: edit the design inputs below (ZONE_MINUTES, GATES, BASE_INCOME, SHARE ...), then
`gen`, `apply`, `python tools/gen_characters.py`, gen_config.py, `python tools/gate.py`.
The owner approved plan 12 on 2026-11-26.

THE MODEL (plan 12 explains every rule):
  * 17 zones in 8 BANDS. Band 1 = zones 1-3; each rebirth unseals the next two zones.
  * A zone's gate is a Power number. Power comes from training (gear = power per rep).
  * Yen comes from heroes on the plot. Yen buys gear, food and plot slots.
  * Rebirth k: needs the Power of the sealed gate + a Yen fee. Resets Power and Yen ONLY: heroes,
    slots, gear and foods are kept (the first draft reset gear and put old heroes to sleep; the
    simulation showed the re-climb then hangs on Yen, because players sell their early-zone heroes).
    Gives +50% income, +25% training, +10% luck per tier, and "muscle memory": training x4
    while Power is below the player's own record, so the way back takes minutes.
  * Gear, foods and slots unlock by the furthest zone ever reached, so Yen can never buy a way
    round the training clock; their prices are fractions of what a zone pays in its target time
    (measured by a free-shopping run: `gen` runs it).
  * Rarity is a band roll, rarest first: chance = min(1, base x luck). Common is the rest.
"""

from __future__ import annotations

import argparse
import json
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DRAFT = ROOT / "design" / "plan" / "12-economy-draft.json"
GAME = ROOT / "design" / "game.json"
LINEUP = ROOT / "design" / "characters" / "lineup.json"

# ------------------------------------------------------------------ design inputs --------
ZONES = [  # (config id kept from the map, title, anime)
    ("sakura_schoolyard", "Hidden Leaf Village", "Naruto"),
    ("pirate_harbor", "Demon Slayer Corps", "Demon Slayer"),
    ("ninja_village", "Grand Line", "One Piece"),
    ("samurai_castle", "Hero Academy", "My Hero Academia"),
    ("hero_city", "Blue Lock Facility", "Blue Lock"),
    ("realm_of_legends", "Clover Kingdom", "Black Clover"),
    ("hunter_exam", "Hunter Exam", "Hunter x Hunter"),
    ("isekai_crossroads", "Isekai Crossroads", "Crossover: Other Worlds"),
    ("wall_maria", "Wall Maria", "Attack on Titan"),
    ("public_safety", "Public Safety HQ", "Chainsaw Man"),
    ("bizarre_streets", "Bizarre Streets", "JoJo"),
    ("shadow_council", "Shadow Council", "Crossover: Masterminds"),
    ("city_z", "City Z", "One Punch Man"),
    ("soul_society", "Soul Society", "Bleach"),
    ("gate_of_shadows", "Gate of Shadows", "Solo Leveling"),
    ("shibuya", "Shibuya", "Jujutsu Kaisen"),
    ("planet_of_gods", "Planet of the Gods", "Dragon Ball"),
]
# minutes a new free player should spend in each zone the FIRST time (the pacing target)
ZONE_MINUTES = [3, 9, 18, 30, 50, 60, 75, 90, 105, 120, 135, 150, 165, 180, 200, 220, 240]
# the last zone of each band: a rebirth is needed to throw past it
BAND_END = [3, 5, 7, 9, 11, 13, 15, 17]
# gate Power of each zone (zone 1 is 0), then the "gate" past zone 17 that rebirth 8 asks for
GATES = [0, 200, 2.5e3, 30e3, 350e3, 4e6, 50e6, 600e6, 7e9, 80e9, 1e12, 12e12, 150e12, 1.8e15, 22e15,
         260e15, 3e18, 36e18, 430e18, 5e21]
# what a Common of the zone earns per second
BASE_INCOME = [1, 8, 60, 480, 4e3, 32e3, 250e3, 2e6, 16e6, 130e6, 1e9, 8e9, 65e9, 500e9, 4e12, 32e12, 250e12]

RARITIES = {  # base chance per throw at luck 1 ("1 in N"), income multiplier
    "Common": {"OneIn": None, "IncomeMult": 1},
    "Uncommon": {"OneIn": None, "IncomeMult": 2.5},
    "Rare": {"OneIn": 9, "IncomeMult": 7},
    "Epic": {"OneIn": 50, "IncomeMult": 25},
    "Legendary": {"OneIn": 400, "IncomeMult": 120},
    "Mythic": {"OneIn": 10_000, "IncomeMult": 900},
    "Secret": {"OneIn": 1_000_000, "IncomeMult": 10_000},
}
ORDER = ["Secret", "Mythic", "Legendary", "Epic", "Rare"]  # the luck-scaled bands, rarest first
# Rare grows slower with luck, and always leaves COMMON_FLOOR of the roll to Uncommon + Common (when the
# rarer bands leave that much), which they split UNCOMMON_SHARE : rest. So a Common stays catchable for the
# Index at every luck a player can hold without a paid Lucky Throw.
LUCK_POWER = {"Secret": 1, "Mythic": 1, "Legendary": 1, "Epic": 1, "Rare": 0.6}
COMMON_FLOOR = 0.10
UNCOMMON_SHARE = 0.35
MUTATIONS = [("Galaxy", 0.001, 20), ("Lightning", 0.006, 8), ("Flame", 0.02, 4), ("Golden", 0.06, 2)]
SIZES = [("Titan", 0.003, 6), ("Huge", 0.02, 3), ("Big", 0.08, 1.5)]
MUTATION_LUCK = 0.25  # a mutation's chance grows with a quarter of the extra luck

# which rarities each zone holds (from design/characters/HERO_LIST_BY_RARITY.md + the two moves)
ZONE_RARITIES = {
    1: "CURELM", 2: "CURELM", 3: "CURELM", 4: "CURELM", 5: "CUREL", 6: "CURELM", 7: "CURELM", 8: "CUREL",
    9: "CUREL", 10: "CUREL", 11: "CUREL", 12: "CURELM", 13: "CURELMS", 14: "CURELM", 15: "CURELM",
    16: "CURELM", 17: "CURELMS",
}
LETTER = {"C": "Common", "U": "Uncommon", "R": "Rare", "E": "Epic", "L": "Legendary", "M": "Mythic", "S": "Secret"}
if LINEUP.exists():  # the lineup is the truth once it exists
    _seen: dict[int, set[str]] = {}
    for _row in json.loads(LINEUP.read_text(encoding="utf-8"))["lane"]:
        _seen.setdefault(_row["Zone"], set()).add(_row["Rarity"][0])
    ZONE_RARITIES = {z: "".join(c for c in "CURELMS" if c in letters) for z, letters in _seen.items()}

FOODS = [  # id, name, flavor, PowerMult, Luck, the zone it is priced for
    ("onigiri", "Onigiri", "Savory", 1.0, 1.0, 1), ("dango", "Dango", "Sweet", 1.15, 1.1, 1),
    ("sushi", "Sushi", "Seafood", 1.3, 1.25, 2), ("spicy_bun", "Spicy Bun", "Spicy", 1.5, 1.45, 3),
    ("gyoza", "Gyoza", "Savory", 1.75, 1.7, 4), ("ice_cream", "Ice Cream", "Sweet", 2.0, 2.0, 5),
    ("takoyaki", "Takoyaki", "Seafood", 2.3, 2.35, 6), ("ramen", "Ramen", "Savory", 2.65, 2.75, 8),
    ("curry", "Curry", "Spicy", 3.0, 3.2, 10), ("tempura", "Tempura", "Seafood", 3.5, 3.8, 12),
    ("festival_cake", "Festival Cake", "Sweet", 4.0, 4.5, 14), ("dragon_feast", "Dragon Feast", "Spicy", 5.0, 5.5, 16),
]
GEAR_NAMES = ["Wooden Dummy", "Sandbag", "Iron Dummy", "Stone Pillar", "Waterfall", "Gravity Dojo", "Dragon Shrine",
              "Star Forge", "Thunder Peak", "Spirit Chamber", "Titan Chains", "Void Anvil", "Phoenix Kiln",
              "Moon Temple", "Sun Crucible", "Celestial Gate", "God's Arena"]

START_SLOTS, MAX_SLOTS = 8, 24
THROW_SECONDS = 7.0
TAP_BONUS = 1.2  # an average player hits about 40% perfect reps (+50% each)
TRAIN_SHARE_OF_ZONE = 0.45  # share of a zone's minutes that is training in the design
MUSCLE_MEMORY = 4.0
REBIRTH = {"IncomeBonus": 0.5, "TrainBonus": 0.25, "LuckBonus": 0.1}
SELL_SECONDS = 30


def tier_of_zone(zone: int) -> int:
    """Rebirth tier a player has when they first stand in `zone` (1-based)."""
    for tier, end in enumerate(BAND_END):
        if zone <= end:
            return tier
    return len(BAND_END) - 1


def food_in_zone(zone: int) -> int:
    """Index of the best food a player owns while in `zone`."""
    best = 0
    for i, f in enumerate(FOODS):
        if f[5] <= zone:
            best = i
    return best


def rarity_chances(letters: str, luck: float) -> dict[str, float]:
    """Band roll, rarest first. Returns {rarity: probability} summing to 1."""
    have = {LETTER[c] for c in letters}
    left, out = 1.0, {}
    for name in ORDER:
        if name not in have:
            continue
        p = min(left, (max(1.0, luck) ** LUCK_POWER[name]) / RARITIES[name]["OneIn"])
        if name == "Rare":
            p = min(p, max(0.0, left - COMMON_FLOOR))
        out[name] = p
        left -= p
    left = max(left, 0.0)
    if "Uncommon" in have:
        out["Uncommon"] = left * UNCOMMON_SHARE
        left -= out["Uncommon"]
    out["Common"] = left
    return out


def variant_chances(table, luck: float, scale: float) -> list[tuple[str, float, float]]:
    left, out = 1.0, []
    for name, chance, mult in table:
        p = min(left, chance * (1 + (max(1.0, luck) - 1) * scale))
        out.append((name, p, mult))
        left -= p
    out.append(("none", max(left, 0.0), 1))
    return out


# ------------------------------------------------------------------ generator -----------
FACTORS_FILE = ROOT / "tools" / "economy" / "team_factors.json"
SHARE = {"gear": 0.12, "food": 0.22, "food_first": 0.03, "slot": 0.30, "rebirth": 0.22}


def team_factors() -> list[float]:
    """Mean plot income while in each zone, in units of that zone's Common income (no multipliers).

    Measured by `gen` from a free-shopping run of the simulator and stored, so costs are fractions
    of what a player REALLY earns in a zone's target time."""
    if FACTORS_FILE.exists():
        return json.loads(FACTORS_FILE.read_text(encoding="utf-8"))["factors"]
    return [30 + 60 * z for z in range(17)]


def generate(free: bool = False) -> dict:
    zones, gear, foods, slots, rebirths = [], [], [], [], []
    factors = team_factors()
    for i, (zid, title, anime) in enumerate(ZONES):
        zones.append({
            "Id": zid, "Name": title, "Anime": anime, "Index": i + 1, "PowerReq": GATES[i],
            "BaseIncome": BASE_INCOME[i], "LengthStuds": 360, "RebirthReq": tier_of_zone(i + 1),
            "Rarities": [LETTER[c] for c in ZONE_RARITIES[i + 1]], "TargetMinutes": ZONE_MINUTES[i],
        })

    def zone_yen(zone: int) -> float:
        """Yen a free player earns in `zone` during its target minutes."""
        tier = tier_of_zone(zone)
        return (BASE_INCOME[zone - 1] * factors[zone - 1] * (1 + REBIRTH["IncomeBonus"] * tier)
                * ZONE_MINUTES[zone - 1] * 60)

    def nice(x: float) -> float:
        if free or x <= 0:
            return 0
        if x < 100:
            return float(max(5, round(x / 5) * 5))
        mag = 10 ** (len(str(int(x))) - 2)
        return float(round(x / mag) * mag)

    # gear n is bought in zone n and trains the player to zone n+1's gate in the zone's training share
    for z in range(1, 18):
        tier = tier_of_zone(z)
        pm = FOODS[food_in_zone(z)][3]
        seconds = TRAIN_SHARE_OF_ZONE * ZONE_MINUTES[z - 1] * 60
        need = (GATES[z] - GATES[z - 1]) / pm
        ppr = need / (seconds * (1 + REBIRTH["TrainBonus"] * tier) * TAP_BONUS)
        cost = 0 if z == 1 else zone_yen(z) * SHARE["gear"]
        mag = 10 ** max(0, len(str(int(ppr))) - 2)
        gear.append({"Name": GEAR_NAMES[z - 1], "Cost": nice(cost), "PowerPerRep": max(1.0, round(ppr / mag) * mag),
                     "Zone": z})

    # endgame gear: sold after rebirth 8 and 9, sized so each endgame rebirth is hours, not days
    for n, (name, tier, pure_hours, yen_share) in enumerate((("Endless Dojo", 8, 8, 0.5), ("Hall of Gods", 9, 10, 1.0))):
        need = (GATES[18 + n] - GATES[17 + n]) / FOODS[-1][3]
        ppr = need / (pure_hours * 3600 * (1 + REBIRTH["TrainBonus"] * tier) * TAP_BONUS)
        mag = 10 ** max(0, len(str(int(ppr))) - 2)
        gear.append({"Name": name, "Cost": nice(zone_yen(17) * yen_share), "PowerPerRep": round(ppr / mag) * mag,
                     "Zone": 17, "RebirthReq": tier})

    for i, (fid, name, flavor, pm, luck, z) in enumerate(FOODS):
        cost = 0 if i == 0 else zone_yen(z) * (SHARE["food_first"] if i == 1 else SHARE["food"])
        foods.append({"Id": fid, "Name": name, "Tier": i + 1, "Flavor": flavor, "Cost": nice(cost),
                      "PowerMult": pm, "Luck": luck, "Zone": z})

    # one slot per zone from zone 2 on: sixteen purchases, 8 -> 24 (kept through a rebirth)
    for n in range(START_SLOTS + 1, MAX_SLOTS + 1):
        z = n - START_SLOTS + 1
        slots.append({"Slot": n, "Cost": nice(zone_yen(z) * SHARE["slot"]), "Zone": z})

    for tier in range(1, len(BAND_END)):
        end = BAND_END[tier - 1]
        rebirths.append({"Tier": tier, "PowerReq": GATES[end], "YenCost": nice(zone_yen(end) * SHARE["rebirth"]),
                         "Unseals": [end + 1, min(end + 2, 17)], "IncomeBonus": REBIRTH["IncomeBonus"],
                         "TrainBonus": REBIRTH["TrainBonus"], "LuckBonus": REBIRTH["LuckBonus"]})
    for extra, tier in enumerate((8, 9, 10)):
        rebirths.append({"Tier": tier, "PowerReq": GATES[17 + extra], "YenCost": nice(zone_yen(17) * (1 + extra)),
                         "Unseals": [], "IncomeBonus": REBIRTH["IncomeBonus"], "TrainBonus": REBIRTH["TrainBonus"],
                         "LuckBonus": REBIRTH["LuckBonus"]})

    return {
        "_what": "DRAFT of economy v2 (plan 12). Generated by tools/economy/econ_v2.py gen. Not the live config.",
        "Zones": zones, "Gear": gear, "Foods": foods, "Slots": slots, "Rebirth": rebirths,
        "Rarities": RARITIES, "LuckPower": LUCK_POWER, "CommonFloor": COMMON_FLOOR, "UncommonShare": UNCOMMON_SHARE,
        "Mutations": [{"Name": n, "Chance": c, "IncomeMult": m} for n, c, m in MUTATIONS],
        "Sizes": [{"Name": n, "Chance": c, "IncomeMult": m} for n, c, m in SIZES],
        "Constants": {"ThrowSeconds": THROW_SECONDS, "MuscleMemory": MUSCLE_MEMORY, "StartSlots": START_SLOTS,
                      "MaxSlots": MAX_SLOTS, "SellSeconds": SELL_SECONDS, "TapBonus": TAP_BONUS,
                      "Shares": SHARE},
    }


# ------------------------------------------------------------------ simulator -----------
PROFILES = {
    # yen x, training x, extra luck (added to the permanent group), offline hours of income per 90 min played
    "free": {"yen": 1, "train": 1, "luck": 0.0, "offline": 0.0},
    "free_daily": {"yen": 1, "train": 1, "luck": 0.0, "offline": 4.0},  # 8 h away at 50% once per session
    "x2yen": {"yen": 2, "train": 1, "luck": 0.0, "offline": 0.0},
    "x2train": {"yen": 1, "train": 2, "luck": 0.0, "offline": 0.0},
    "passes": {"yen": 2, "train": 2, "luck": 0.65, "offline": 0.0},  # both x2 + VIP + Lucky Aura
    "passes_daily": {"yen": 2, "train": 2, "luck": 0.65, "offline": 4.0},
}


def clock(seconds: float) -> str:
    h, rem = divmod(int(seconds), 3600)
    return f"{h}h{rem // 60:02d}m" if h else f"{rem // 60}m{rem % 60:02d}s"


def fmt(n: float) -> str:
    for suffix, size in (("Sx", 1e21), ("Qi", 1e18), ("Qa", 1e15), ("T", 1e12), ("B", 1e9), ("M", 1e6), ("K", 1e3)):
        if abs(n) >= size:
            return f"{n / size:.3g}{suffix}"
    return f"{n:.0f}"


def simulate(d: dict, prof: dict, hours: float, seed: int, train_share: float = 0.5, measure: bool = False) -> dict:
    rng = random.Random(seed)
    zones, gear, foods = d["Zones"], d["Gear"], d["Foods"]
    slot_costs = [s["Cost"] for s in d["Slots"]]
    rebirths = d["Rebirth"]
    yen, power, record = 0.0, 10.0, 10.0
    gear_i, food_i, slots, tier = 0, 0, START_SLOTS, 0
    heroes: list[tuple[float, int]] = []  # (income before multipliers, zone index 1-based)
    best_zone = 1
    t, next_offline = 0.0, 90 * 60.0
    marks: dict[str, float] = {}
    first_zone: dict[int, float] = {}
    samples: dict[int, list[float]] = {}
    throws = 0
    end = hours * 3600

    def open_max() -> int:
        return max(i + 1 for i, zone in enumerate(zones) if zone["RebirthReq"] <= tier)

    def reach() -> int:
        eff = power * foods[food_i]["PowerMult"]
        z = 1
        for i, zone in enumerate(zones):
            if eff >= zone["PowerReq"] and i + 1 <= open_max():
                z = i + 1
        return z

    while t < end:
        z = reach()
        if z not in first_zone:
            first_zone[z] = t
            marks[f"ZONE {z:>2} {zones[z - 1]['Name']}"] = t
        best_zone = max(best_zone, z)
        awake = sorted((h[0] for h in heroes), reverse=True)[:slots]
        income = sum(awake) * (1 + REBIRTH["IncomeBonus"] * tier) * prof["yen"]
        if measure and awake and z == best_zone:
            samples.setdefault(z, []).append(sum(awake) / zones[z - 1]["BaseIncome"])

        # ---- rebirth -------------------------------------------------------------------
        nxt = rebirths[tier] if tier < len(rebirths) else None
        at_seal = nxt is not None and power * foods[food_i]["PowerMult"] >= nxt["PowerReq"] and z == open_max()
        if at_seal and yen >= nxt["YenCost"]:
            tier += 1
            marks[f"REBIRTH {tier}"] = t
            yen, power = 0.0, 10.0
            continue

        # ---- spend: cheapest first -----------------------------------------------------
        while True:
            options = []
            if (gear_i + 1 < len(gear) and gear[gear_i + 1]["Zone"] <= best_zone
                    and tier >= gear[gear_i + 1].get("RebirthReq", 0)):
                options.append((gear[gear_i + 1]["Cost"], "gear"))
            if food_i + 1 < len(foods) and foods[food_i + 1]["Zone"] <= best_zone:
                options.append((foods[food_i + 1]["Cost"], "food"))
            if slots < MAX_SLOTS and d["Slots"][slots - START_SLOTS]["Zone"] <= best_zone:
                options.append((slot_costs[slots - START_SLOTS], "slot"))
            if at_seal:  # saving for the rebirth: only small buys
                options = [o for o in options if o[0] <= nxt["YenCost"] * 0.25]
            options.sort()
            if not options or yen < options[0][0]:
                break
            cost, kind = options[0]
            yen -= cost
            if kind == "gear":
                gear_i += 1
            elif kind == "food":
                food_i += 1
            else:
                slots += 1

        # ---- act -----------------------------------------------------------------------
        catching_up = power < record * 0.999
        target_exists = z < len(zones) or nxt is not None
        gate = zones[z]["PowerReq"] if z < len(zones) else (nxt["PowerReq"] if nxt else None)
        needs_power = gate is not None and power * foods[food_i]["PowerMult"] < gate
        if at_seal or not needs_power:
            p_train = 0.0 if at_seal else 0.15
        elif catching_up:
            p_train = 0.85
        elif len(awake) < slots:
            p_train = 0.2
        else:
            p_train = train_share
        if not target_exists:
            p_train = 0.0

        if rng.random() < p_train:
            mult = (1 + REBIRTH["TrainBonus"] * tier) * prof["train"] * TAP_BONUS
            if catching_up:
                mult *= MUSCLE_MEMORY
            power += gear[gear_i]["PowerPerRep"] * mult * THROW_SECONDS
            record = max(record, power)
        else:
            throws += 1
            luck = foods[food_i]["Luck"] * 1.18 * (1 + REBIRTH["LuckBonus"] * tier + prof["luck"])
            chances = rarity_chances("".join(c for c in ZONE_RARITIES[z]), luck)
            r, acc, rarity = rng.random(), 0.0, "Common"
            for name, p in chances.items():
                acc += p
                if r < acc:
                    rarity = name
                    break
            value = zones[z - 1]["BaseIncome"] * RARITIES[rarity]["IncomeMult"]
            for table, scale in ((MUTATIONS, MUTATION_LUCK), (SIZES, 0.0)):
                r, acc = rng.random(), 0.0
                for _, p, mult in variant_chances(table, luck, scale):
                    acc += p
                    if r < acc:
                        value *= mult
                        break
            heroes.append((value, z))
            if len(heroes) > MAX_SLOTS + 30:  # plot + bench: the weakest is sold
                heroes.sort(reverse=True)
                sold = heroes.pop()
                yen += sold[0] * SELL_SECONDS
            if rarity in ("Mythic", "Secret"):
                marks.setdefault(f"first {rarity}", t)
            if rarity == "Legendary":
                marks.setdefault("first Legendary", t)
            if rarity == "Epic":
                marks.setdefault("first Epic", t)

        yen += income * THROW_SECONDS
        t += THROW_SECONDS
        if prof["offline"] and t >= next_offline:
            yen += income * prof["offline"] * 3600
            next_offline += 90 * 60.0

    return {"marks": marks, "tier": tier, "zone": reach(), "throws": throws, "samples": samples,
            "income": income, "power": power, "slots": slots}


def load_live() -> dict:
    """design/game.json `config` in the shape the simulator plays. The roll and rebirth constants of this
    module are REPLACED by the config's, so `sim --live` and `check` measure the game, not this file."""
    global RARITIES, LUCK_POWER, COMMON_FLOOR, UNCOMMON_SHARE, MUTATIONS, SIZES, REBIRTH, MUSCLE_MEMORY
    global START_SLOTS, MAX_SLOTS, SELL_SECONDS, ZONE_RARITIES, MUTATION_LUCK, THROW_SECONDS
    cfg = json.loads(GAME.read_text(encoding="utf-8"))["config"]
    RARITIES = {n: {"OneIn": r.get("OneIn"), "IncomeMult": r["IncomeMult"]} for n, r in cfg["Rarities"].items()}
    LUCK_POWER = {n: r["LuckPower"] for n, r in cfg["Rarities"].items() if r.get("OneIn")}
    COMMON_FLOOR, UNCOMMON_SHARE = cfg["Roll"]["CommonFloor"], cfg["Roll"]["UncommonShare"]
    MUTATIONS = [(m["Name"], m["Chance"], m["IncomeMult"]) for m in cfg["Mutations"]]
    MUTATION_LUCK = cfg["Mutations"][0].get("LuckScale", 0)
    SIZES = [(m["Name"], m["Chance"], m["IncomeMult"]) for m in cfg["Sizes"]]
    tiers = cfg["Rebirth"]["Tiers"]
    REBIRTH = {k: tiers[0][k] for k in ("IncomeBonus", "TrainBonus", "LuckBonus")}
    MUSCLE_MEMORY = cfg["Training"]["MuscleMemory"]
    START_SLOTS, MAX_SLOTS = cfg["Plot"]["StartSlots"], cfg["Plot"]["MaxSlots"]
    SELL_SECONDS = cfg["Plot"]["SellSeconds"]
    THROW_SECONDS = cfg["Throw"]["CycleSeconds"]
    index = {z["Id"]: z["Index"] for z in cfg["Zones"]}
    seen: dict[int, set[str]] = {}
    for c in cfg["Characters"]:
        seen.setdefault(index[c["Zone"]], set()).add(c["Rarity"][0])
    ZONE_RARITIES = {z: "".join(c for c in "CURELMS" if c in letters) for z, letters in seen.items()}
    missing = [z["Name"] for z in cfg["Zones"] if z["Index"] not in ZONE_RARITIES]
    if missing:
        raise SystemExit(f"zones with no heroes: {missing}")
    plot = cfg["Plot"]
    return {
        "Zones": cfg["Zones"], "Gear": cfg["Training"]["Equipment"], "Foods": cfg["Foods"], "Rebirth": tiers,
        "Slots": [{"Slot": START_SLOTS + i + 1, "Cost": c, "Zone": plot["SlotZones"][i]}
                  for i, c in enumerate(plot["SlotCosts"])],
        "Pacing": cfg.get("Pacing", {}),
    }


RANKS = ["Rookie", "Trainee", "Fighter", "Elite", "Champion", "Hero", "Legend", "Mythic", "Godly", "Titan",
         "Overlord", "Celestial", "Divine", "Eternal", "Transcendent", "Omega", "Infinite"]
# minutes from a fresh start, free player: [earliest, latest] (about -25% / +35% round the simulated median)
PACING = {"ZONE 2": [1.5, 5], "ZONE 3": [9, 19], "REBIRTH 1": [25, 46], "REBIRTH 2": [93, 168],
          "REBIRTH 4": [370, 660], "REBIRTH 7": [1170, 2110], "ZONE 17": [1380, 2480]}


def apply() -> int:
    """Write the generated numbers into design/game.json `config` (zones, rarities, gear, food, plot, rebirth)."""
    d = generate()
    doc = json.loads(GAME.read_text(encoding="utf-8"))
    cfg = doc["config"]
    scenery = {z["Id"]: z.get("Scenery", "") for z in cfg["Zones"]}
    cfg["Zones"] = [{"Id": z["Id"], "Name": z["Name"], "Anime": z["Anime"], "Index": z["Index"],
                     "PowerReq": z["PowerReq"], "BaseIncome": z["BaseIncome"], "LengthStuds": z["LengthStuds"],
                     "RebirthReq": z["RebirthReq"], "Scenery": scenery.get(z["Id"]) or z["Anime"]}
                    for z in d["Zones"]]
    for name, row in cfg["Rarities"].items():
        row.pop("Weight", None)
        row.pop("LuckScale", None)
        row.pop("OneIn", None)
        row.pop("LuckPower", None)
        row["IncomeMult"] = RARITIES[name]["IncomeMult"]
        if RARITIES[name]["OneIn"]:
            row["OneIn"] = RARITIES[name]["OneIn"]
            row["LuckPower"] = LUCK_POWER[name]
    # a Legendary is a few an hour for each of five players at endgame luck: only Mythic and Secret
    # get the server banner by rarity; anything else earns it by its score (Roll.AnnounceOneIn)
    cfg["Rarities"]["Legendary"]["Announce"] = False
    cfg["Roll"] = {"CommonFloor": COMMON_FLOOR, "UncommonShare": UNCOMMON_SHARE,
                   "Stamps": [{"Name": "LUCKY", "OneIn": 100}, {"Name": "SUPER LUCKY", "OneIn": 10_000},
                              {"Name": "INSANE LUCK", "OneIn": 1_000_000}, {"Name": "GODLY", "OneIn": 100_000_000}],
                   "AnnounceOneIn": 100_000, "GlobalAnnounceOneIn": 100_000_000}
    cfg["Throw"].update({"CycleSeconds": THROW_SECONDS, "LuckyThrowLuck": 12, "LuckyFloor": "Epic",
                         "DryStreakPerThrow": 0.01, "DryStreakMax": 0.5, "DryStreakResetRarity": "Epic"})
    cfg["Luck"]["Max"] = 1000
    # hero zones and every price changed meaning: the old saves do not carry over
    cfg["Server"].update({"ProfileStore": "Profiles_v2", "ProfileStoreStudio": "Profiles_Dev_v2"})
    training = cfg["Training"]
    training["Equipment"] = [{k: g[k] for k in ("Name", "Cost", "PowerPerRep", "Zone", "RebirthReq") if k in g}
                             for g in d["Gear"]]
    training["MuscleMemory"] = MUSCLE_MEMORY
    training["Ranks"] = [{"Name": RANKS[i], "Power": GATES[i]} for i in range(17)]
    old_food = {f["Id"]: f for f in cfg["Foods"]}
    cfg["Foods"] = [dict(old_food.get(f["Id"], {}), **f) for f in d["Foods"]]
    plot = cfg["Plot"]
    plot.pop("SlotBaseCost", None)
    plot.pop("SlotCostGrowth", None)
    plot.update({"StartSlots": START_SLOTS, "MaxSlots": MAX_SLOTS, "SellSeconds": SELL_SECONDS,
                 "SlotCosts": [x["Cost"] for x in d["Slots"]], "SlotZones": [x["Zone"] for x in d["Slots"]]})
    cfg["Rebirth"] = {
        "Tiers": [dict(r, LuckyThrows=3) for r in d["Rebirth"]],
        "Keeps": ["Heroes", "PlotSlots", "Equipment", "Foods", "Index", "Passes", "LuckyThrows", "Settings", "Stats"],
        "Resets": ["Yen", "Power"],
    }
    cfg["Pacing"] = PACING
    cfg["Sim"] = {"TrainShare": 0.5, "TapBonus": TAP_BONUS, "Shares": SHARE,
                  "_note": "tools/economy/econ_v2.py: `check` plays this config against Pacing"}
    GAME.write_text(json.dumps(doc, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"applied economy v2 to {GAME.relative_to(ROOT)}: {len(cfg['Zones'])} zones, "
          f"{len(training['Equipment'])} gear tiers, {len(plot['SlotCosts'])} slot prices, "
          f"{len(cfg['Rebirth']['Tiers'])} rebirths")
    return 0


def median_marks(results: list[dict]) -> dict[str, float]:
    keys: list[str] = []
    for r in results:
        for k in r["marks"]:
            if k not in keys:
                keys.append(k)
    out = {}
    for k in keys:
        vals = sorted(r["marks"][k] for r in results if k in r["marks"])
        if len(vals) * 2 >= len(results):
            out[k] = vals[len(vals) // 2]
    return out


def run_check(a) -> int:
    d = load_live()
    results = [simulate(d, PROFILES["free"], a.hours, seed, 0.5) for seed in range(a.runs)]
    marks = median_marks(results)
    failed = 0
    for name, (lo, hi) in d["Pacing"].items():
        hit = next((v for k, v in marks.items() if " ".join(k.split()[:2]) == name), None)
        ok = hit is not None and lo * 60 <= hit <= hi * 60
        failed += 0 if ok else 1
        print(f"  {'ok  ' if ok else 'MISS'} {name:<12} target {lo:g}-{hi:g} min, got "
              f"{clock(hit) if hit is not None else 'never'}")
    if failed:
        print(f"{failed} pacing target(s) missed")
    return 1 if failed else 0


def run_sim(a) -> int:
    d = load_live() if a.live else json.loads(DRAFT.read_text(encoding="utf-8"))
    prof = PROFILES[a.profile]
    results = [simulate(d, prof, a.hours, seed, a.train_share, a.measure) for seed in range(a.runs)]
    marks = median_marks(results)
    print(f"profile {a.profile}  ({a.runs} runs of {a.hours:g} h, train share {a.train_share}"
          f"{', LIVE config' if a.live else ', draft'})")
    for k, v in sorted(marks.items(), key=lambda kv: kv[1]):
        print(f"  {k:<32}{clock(v):>9}")
    mid = results[len(results) // 2]
    print(f"  at {a.hours:g} h: rebirth {mid['tier']}, zone {mid['zone']}, {mid['throws']} throws, "
          f"income {fmt(mid['income'])}/s, power {fmt(mid['power'])}, slots {mid['slots']}")
    if a.measure:
        print("  team income in units of the zone's Common (median of samples):")
        for z in range(1, 18):
            vals = sorted(v for r in results for v in r["samples"].get(z, []))
            if vals:
                print(f"    zone {z:>2}: {vals[len(vals) // 2]:8.0f}   (design {team_factors()[z - 1]:.0f})")
    return 0


def run_odds(_a) -> int:
    print("rarity odds per throw (zones that hold every rarity), 1 in N")
    lucks = [1, 2, 3, 5, 8, 12, 20, 50, 150, 500]
    print("  luck      " + "".join(f"{l:>11}" for l in lucks))
    for name in ["Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Common"]:
        cells = []
        for l in lucks:
            p = rarity_chances("CURELMS", l).get(name, 0)
            cells.append(f"{(1 / p if p > 0 else float('inf')):>11,.1f}")
        print(f"  {name:<10}" + "".join(cells))
    print("\nexpected rarity income multiplier (mean of a catch, no mutation/size)")
    for l in lucks:
        ch = rarity_chances("CURELM", l)
        print(f"  luck {l:>4}: {sum(p * RARITIES[n]['IncomeMult'] for n, p in ch.items()):8.2f}")
    print("\nscore examples at base odds (hero x mutation x size), 1 in N")
    hero = {"Epic": 50 * 2.5, "Legendary": 400 * 2, "Mythic": 10_000, "Secret": 1_000_000}
    for h, hn in hero.items():
        for mn, mc, _ in [("none", 0.913, 1)] + [(n, c, m) for n, c, m in MUTATIONS]:
            for sn, sc, _ in [("none", 0.897, 1)] + [(n, c, m) for n, c, m in SIZES]:
                if mn == "none" and sn == "none":
                    continue
                print(f"  {h:<10}{mn:<10}{sn:<6} 1 in {hn / mc / sc:,.0f}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("gen")
    s = sub.add_parser("sim")
    s.add_argument("--profile", default="free", choices=sorted(PROFILES))
    s.add_argument("--hours", type=float, default=45)
    s.add_argument("--runs", type=int, default=5)
    s.add_argument("--train-share", type=float, default=0.5)
    s.add_argument("--measure", action="store_true")
    s.add_argument("--live", action="store_true", help="play design/game.json instead of the draft")
    sub.add_parser("odds")
    sub.add_parser("apply")
    c = sub.add_parser("check")
    c.add_argument("--hours", type=float, default=44)
    c.add_argument("--runs", type=int, default=3)
    a = ap.parse_args()
    if a.cmd == "apply":
        return apply()
    if a.cmd == "check":
        return run_check(a)
    if a.cmd == "gen":
        # 1. a run where everything is free (but still unlocks by zone): its clock is training alone,
        #    and it tells what a plot really earns in each zone
        free = generate(free=True)
        acc: dict[int, list[float]] = {}
        for seed in range(8):
            r = simulate(free, PROFILES["free"], 60, seed, 0.5, True)
            for z, vals in r["samples"].items():
                acc.setdefault(z, []).append(sum(vals) / len(vals))
        factors = [round(sum(acc[z]) / len(acc[z]), 1) if z in acc else 0 for z in range(1, 18)]
        FACTORS_FILE.write_text(json.dumps({"_what": "mean plot income per zone / the zone's Common income, "
                                            "from the free-shopping run (econ_v2.py gen)", "factors": factors}) + "\n",
                                encoding="utf-8")
        # 2. prices as fractions of what each zone pays in its target minutes
        DRAFT.write_text(json.dumps(generate(), indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"factors {factors}\nwrote {DRAFT.relative_to(ROOT)}")
        return 0
    return run_sim(a) if a.cmd == "sim" else run_odds(a)


if __name__ == "__main__":
    sys.exit(main())
