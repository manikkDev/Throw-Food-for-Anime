#!/usr/bin/env python3
"""Economy v3 DRAFT (plan 13): 51 foods and 57 training levels on the approved v2 ladder.

    python tools/economy/econ_v3.py gen      # numbers from the pacing targets -> design/plan/13-economy-draft.json
    python tools/economy/econ_v3.py sim      # plays the draft: milestones, per profile
    python tools/economy/econ_v3.py cadence  # minutes between purchases, zone by zone
    python tools/economy/econ_v3.py table    # the food and training tables for the plan

    python tools/economy/econ_v3.py apply    # writes the draft into design/game.json `config`
    python tools/economy/econ_v3.py check    # the pacing GATE: game.json against config.Pacing

The owner approved plan 13 on 2026-11-26. After `apply`: `python tools/gen_characters.py`,
gen_config.py, `python tools/gate.py`.
Everything not named here (zones, gates, base incomes, rarities, slots, rebirths, the roll) is
econ_v2's, imported, so the two cannot drift.

WHAT CHANGES AGAINST v2
  * Food is LUCK only. Reach (how far) comes from Power alone: food's PowerMult is gone.
  * Every zone has three foods of its own anime: a Snack, a Meal and a Signature dish (17 x 3 = 51).
    A food is worth its full Luck in its own zone and every earlier zone; thrown into a LATER
    zone it is STALE (x STALE): heroes want the food of their own world.
  * Training gear has three levels per tier (19 x 3 = 57 upgrades). A tier is still unlocked by
    the zone reached; the levels inside it are Yen.
  * Training: reps run by themselves at x1 (the AFK floor); playing the station's game is worth
    about x1.85 for a typical player and x2.3 played perfectly. The design average is TAP_BONUS.
"""

from __future__ import annotations

import argparse
import json
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import econ_v2 as v2  # noqa: E402

ROOT = v2.ROOT
DRAFT = ROOT / "design" / "plan" / "13-economy-draft.json"

# ------------------------------------------------------------------ design inputs --------
ROLES = ("Snack", "Meal", "Signature")
ROLE_LUCK = (1.0, 1.45, 2.0)  # x the zone's base luck
LUCK_GROWTH = 1.08  # the zone's base luck, zone on zone (zone 1 = 1.0)
STALE = 0.5  # a food thrown into a zone later than its own
FOOD_SHARE = (0.02, 0.07, 0.18)  # price as a share of what the zone pays in its target minutes

GEAR_LEVEL_MULT = (0.6, 1.0, 1.5)  # power per rep of levels I, II, III against the tier's base
GEAR_LEVEL_TIME = (0.20, 0.35, 0.45)  # share of the zone's training a player does at each level
GEAR_SHARE = (0.015, 0.045, 0.10)

TAP_BONUS = 1.5  # design average: about 60% of training played (x1.85), 40% left running (x1.0)
TAP_AFK, TAP_TYPICAL, TAP_PERFECT = 1.0, 1.85, 2.3
SHARE_SLOT, SHARE_REBIRTH = 0.30, 0.22

# id, name, flavour: three per zone in the order Snack, Meal, Signature. Names are dishes, never
# franchise names (the hero-alias rule).
FOODS = [
    # 1 Hidden Leaf Village
    ("onigiri", "Onigiri", "Savory"), ("tricolor_dango", "Tricolor Dango", "Sweet"),
    ("legend_ramen", "Legendary Ramen", "Savory"),
    # 2 Demon Slayer Corps
    ("ohagi", "Ohagi", "Sweet"), ("tempura_bowl", "Tempura Bowl", "Seafood"),
    ("flame_bento", "Flame Bento", "Savory"),
    # 3 Grand Line
    ("sea_takoyaki", "Sea King Takoyaki", "Seafood"), ("meat_on_bone", "Meat on the Bone", "Savory"),
    ("swirl_fruit", "Swirl Fruit", "Sweet"),
    # 4 Hero Academy
    ("cold_soba", "Cold Soba", "Savory"), ("hero_katsudon", "Hero's Katsudon", "Savory"),
    ("mapo_tofu", "Explosion Mapo Tofu", "Spicy"),
    # 5 Blue Lock Facility
    ("kintsuba", "Kintsuba", "Sweet"), ("striker_gyoza", "Striker Gyoza", "Savory"),
    ("rank_one_steak", "Rank One Steak", "Savory"),
    # 6 Clover Kingdom
    ("tatoes", "Village Tatoes", "Savory"), ("clover_cake", "Four-Leaf Cake", "Sweet"),
    ("sheep_feast", "Cotton Sheep Feast", "Savory"),
    # 7 Hunter Exam
    ("choco_robot", "Robo Choco Balls", "Sweet"), ("exam_sushi", "Exam Sushi", "Seafood"),
    ("boar_roast", "Giant Boar Roast", "Savory"),
    # 8 Isekai Crossroads
    ("isekai_apple", "Isekai Apple", "Sweet"), ("flying_cabbage", "Flying Cabbage Stir-fry", "Spicy"),
    ("floor_boss_stew", "Floor Boss Stew", "Savory"),
    # 9 Wall Maria
    ("steamed_potato", "Steamed Potato", "Savory"), ("scout_bread", "Scout Ration Bread", "Savory"),
    ("officers_ham", "Officer's Ham", "Savory"),
    # 10 Public Safety HQ
    ("jam_toast", "Jam Toast", "Sweet"), ("hunter_burger", "Devil Hunter Burger", "Savory"),
    ("devil_ice_cream", "Devil Ice Cream", "Sweet"),
    # 11 Bizarre Streets
    ("double_cherry", "Double Cherry", "Sweet"), ("margherita", "Margherita Pizza", "Savory"),
    ("healing_pasta", "Healing Squid Ink Pasta", "Seafood"),
    # 12 Shadow Council
    ("potato_chips", "Consomme Chips", "Savory"), ("red_apple", "Reaper's Apple", "Sweet"),
    ("detective_cake", "Detective's Cake Tower", "Sweet"),
    # 13 City Z
    ("hero_banana", "Hero's Banana", "Sweet"), ("hero_udon", "Hero Udon", "Savory"),
    ("crab_hot_pot", "Crab Hot Pot", "Seafood"),
    # 14 Soul Society
    ("soul_candy", "Soul Candy", "Sweet"), ("strawberry_daifuku", "Strawberry Daifuku", "Sweet"),
    ("captains_curry", "Captain's Curry", "Spicy"),
    # 15 Gate of Shadows
    ("kimbap", "Hunter Kimbap", "Savory"), ("rice_cakes", "Fire Rice Cakes", "Spicy"),
    ("elixir", "Elixir of Life", "Sweet"),
    # 16 Shibuya
    ("crepe", "Shibuya Crepe", "Sweet"), ("meatball_pot", "Meatball Hot Pot", "Spicy"),
    ("cream_mochi", "Infinity Cream Mochi", "Sweet"),
    # 17 Planet of the Gods
    ("hermit_bean", "Hermit Bean", "Savory"), ("god_pudding", "Destroyer's Pudding", "Sweet"),
    ("saiyan_feast", "Warrior's Feast", "Savory"),
]
assert len(FOODS) == 51

# the training grounds: one per rebirth band, alternating courts (plan 13 section 5)
GROUNDS = ["Striking Post", "Waterfall Focus", "Boulder Breaker", "Thunder Peak", "Gravity Chamber",
           "Spirit Orb", "Titan Chains", "Room of Time"]
LEVEL_NAMES = ("I", "II", "III")


def zone_luck(zone: int) -> float:
    return LUCK_GROWTH ** (zone - 1)


def round2(x: float) -> float:
    """Two significant digits (the numbers a player reads)."""
    if x <= 0:
        return 0.0
    if x < 10:
        return float(max(1, round(x)))
    mag = 10 ** (len(str(int(x))) - 2)
    return float(round(x / mag) * mag)


def generate(free: bool = False, factors: list[float] | None = None) -> dict:
    factors = factors or [30 + 60 * z for z in range(17)]

    def zone_yen(zone: int) -> float:
        tier = v2.tier_of_zone(zone)
        return (v2.BASE_INCOME[zone - 1] * factors[zone - 1] * (1 + v2.REBIRTH["IncomeBonus"] * tier)
                * v2.ZONE_MINUTES[zone - 1] * 60)

    def nice(x: float) -> float:
        if free or x <= 0:
            return 0
        if x < 100:
            return float(max(5, round(x / 5) * 5))
        mag = 10 ** (len(str(int(x))) - 2)
        return float(round(x / mag) * mag)

    zones = []
    for i, (zid, title, anime) in enumerate(v2.ZONES):
        zones.append({"Id": zid, "Name": title, "Anime": anime, "Index": i + 1, "PowerReq": v2.GATES[i],
                      "BaseIncome": v2.BASE_INCOME[i], "RebirthReq": v2.tier_of_zone(i + 1),
                      "TargetMinutes": v2.ZONE_MINUTES[i]})

    foods = []
    for n, (fid, name, flavor) in enumerate(FOODS):
        z, role = n // 3 + 1, n % 3
        cost = 0 if n == 0 else zone_yen(z) * FOOD_SHARE[role]
        foods.append({"Id": fid, "Name": name, "Flavor": flavor, "Zone": z, "Role": ROLES[role],
                      "Luck": round(zone_luck(z) * ROLE_LUCK[role], 2), "Cost": nice(cost)})

    # gear: tier z trains the player from gate z to gate z+1 in the zone's training share, the three
    # levels sharing that time as GEAR_LEVEL_TIME
    mean_mult = sum(m * w for m, w in zip(GEAR_LEVEL_MULT, GEAR_LEVEL_TIME))
    gear = []

    def add_tier(tier_no: int, zone: int, need: float, seconds: float, rebirth_tier: int, shares, req=None):
        base = need / (seconds * (1 + v2.REBIRTH["TrainBonus"] * rebirth_tier) * TAP_BONUS * mean_mult)
        for lv in range(3):
            ppr = float(lv + 1) if tier_no == 1 else max(1.0, round2(base * GEAR_LEVEL_MULT[lv]))  # zone 1: 1, 2, 3
            if gear and ppr <= gear[-1]["PowerPerRep"]:  # every upgrade is stronger than the one before
                ppr = max(gear[-1]["PowerPerRep"] + 1, round2(gear[-1]["PowerPerRep"] * 1.1))
            row = {"Tier": tier_no, "Level": lv + 1, "Zone": zone, "PowerPerRep": ppr,
                   "Cost": 0 if (tier_no == 1 and lv == 0) else nice(zone_yen(zone) * shares[lv])}
            if req:
                row["RebirthReq"] = req
            gear.append(row)

    for z in range(1, 18):
        add_tier(z, z, v2.GATES[z] - v2.GATES[z - 1], v2.TRAIN_SHARE_OF_ZONE * v2.ZONE_MINUTES[z - 1] * 60,
                 v2.tier_of_zone(z), GEAR_SHARE)
    for n, (tier, pure_hours, yen_share) in enumerate(((8, 8, 0.5), (9, 10, 1.0))):
        add_tier(18 + n, 17, v2.GATES[18 + n] - v2.GATES[17 + n], pure_hours * 3600, tier,
                 (yen_share * 0.4, yen_share * 0.7, yen_share), req=tier)

    slots = [{"Slot": n, "Zone": n - v2.START_SLOTS + 1,
              "Cost": nice(zone_yen(n - v2.START_SLOTS + 1) * SHARE_SLOT)}
             for n in range(v2.START_SLOTS + 1, v2.MAX_SLOTS + 1)]

    rebirths = []
    for tier in range(1, len(v2.BAND_END)):
        end = v2.BAND_END[tier - 1]
        rebirths.append({"Tier": tier, "PowerReq": v2.GATES[end], "YenCost": nice(zone_yen(end) * SHARE_REBIRTH),
                         "Unseals": [end + 1, min(end + 2, 17)]})
    for extra, tier in enumerate((8, 9, 10)):
        rebirths.append({"Tier": tier, "PowerReq": v2.GATES[17 + extra],
                         "YenCost": nice(zone_yen(17) * (1 + extra)), "Unseals": []})

    return {"_what": "DRAFT of economy v3 (plan 13): foods and training levels. Generated by "
                     "tools/economy/econ_v3.py gen. Not the live config.",
            "Zones": zones, "Foods": foods, "Gear": gear, "Slots": slots, "Rebirth": rebirths,
            "Factors": factors,
            "Constants": {"Stale": STALE, "RoleLuck": ROLE_LUCK, "LuckGrowth": LUCK_GROWTH, "TapBonus": TAP_BONUS,
                          "TapAfk": TAP_AFK, "TapTypical": TAP_TYPICAL, "TapPerfect": TAP_PERFECT,
                          "FoodShare": FOOD_SHARE, "GearShare": GEAR_SHARE, "GearLevelMult": GEAR_LEVEL_MULT}}


PROFILES = {
    # yen x, training x (passes), extra luck, offline hours per 90 min played, how training is played
    "free": {"yen": 1, "train": 1, "luck": 0.0, "offline": 0.0, "tap": TAP_BONUS},
    "free_afk": {"yen": 1, "train": 1, "luck": 0.0, "offline": 0.0, "tap": TAP_AFK},
    "free_active": {"yen": 1, "train": 1, "luck": 0.0, "offline": 0.0, "tap": TAP_TYPICAL},
    "free_perfect": {"yen": 1, "train": 1, "luck": 0.0, "offline": 0.0, "tap": TAP_PERFECT},
    "free_daily": {"yen": 1, "train": 1, "luck": 0.0, "offline": 4.0, "tap": TAP_BONUS},
    "x2yen": {"yen": 2, "train": 1, "luck": 0.0, "offline": 0.0, "tap": TAP_BONUS},
    "x2train": {"yen": 1, "train": 2, "luck": 0.0, "offline": 0.0, "tap": TAP_BONUS},
    "passes": {"yen": 2, "train": 2, "luck": 0.65, "offline": 0.0, "tap": TAP_BONUS},
}


def simulate(d: dict, prof: dict, hours: float, seed: int, train_share: float = 0.5, measure: bool = False) -> dict:
    rng = random.Random(seed)
    zones, gear, foods, rebirths = d["Zones"], d["Gear"], d["Foods"], d["Rebirth"]
    slot_rows = d["Slots"]
    yen, power, record = 0.0, 10.0, 10.0
    gear_i, food_i, slots, tier = 0, 0, v2.START_SLOTS, 0
    heroes: list[float] = []
    best_zone = 1
    t, next_offline = 0.0, 90 * 60.0
    marks: dict[str, float] = {}
    first_zone: dict[int, float] = {}
    samples: dict[int, list[float]] = {}
    buys: list[tuple[float, str, int]] = []  # (time, what, best zone at the time)
    throws = 0
    end = hours * 3600
    income = 0.0

    def open_max() -> int:
        return max(i + 1 for i, zone in enumerate(zones) if zone["RebirthReq"] <= tier)

    def reach() -> int:
        z = 1
        for i, zone in enumerate(zones):
            if power >= zone["PowerReq"] and i + 1 <= open_max():
                z = i + 1
        return z

    def food_luck(zone: int) -> float:
        return max(f["Luck"] * (1 if f["Zone"] >= zone else STALE) for f in foods[: food_i + 1])

    while t < end:
        z = reach()
        if z not in first_zone:
            first_zone[z] = t
            marks[f"ZONE {z:>2} {zones[z - 1]['Name']}"] = t
        best_zone = max(best_zone, z)
        awake = sorted(heroes, reverse=True)[:slots]
        income = sum(awake) * (1 + v2.REBIRTH["IncomeBonus"] * tier) * prof["yen"]
        if measure and awake and z == best_zone:
            samples.setdefault(z, []).append(sum(awake) / zones[z - 1]["BaseIncome"])

        nxt = rebirths[tier] if tier < len(rebirths) else None
        at_seal = nxt is not None and power >= nxt["PowerReq"] and z == open_max()
        if at_seal and yen >= nxt["YenCost"]:
            tier += 1
            marks[f"REBIRTH {tier}"] = t
            buys.append((t, "rebirth", best_zone))
            yen, power = 0.0, 10.0
            continue

        while True:
            options = []
            if (gear_i + 1 < len(gear) and gear[gear_i + 1]["Zone"] <= best_zone
                    and tier >= gear[gear_i + 1].get("RebirthReq", 0)):
                options.append((gear[gear_i + 1]["Cost"], "gear"))
            if food_i + 1 < len(foods) and foods[food_i + 1]["Zone"] <= best_zone:
                options.append((foods[food_i + 1]["Cost"], "food"))
            if slots < v2.MAX_SLOTS and slot_rows[slots - v2.START_SLOTS]["Zone"] <= best_zone:
                options.append((slot_rows[slots - v2.START_SLOTS]["Cost"], "slot"))
            if at_seal:
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
            if cost > 0:
                buys.append((t, kind, best_zone))

        catching_up = power < record * 0.999
        target_exists = z < len(zones) or nxt is not None
        gate = zones[z]["PowerReq"] if z < len(zones) else (nxt["PowerReq"] if nxt else None)
        needs_power = gate is not None and power < gate
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
            mult = (1 + v2.REBIRTH["TrainBonus"] * tier) * prof["train"] * prof["tap"]
            if catching_up:
                mult *= v2.MUSCLE_MEMORY
            power += gear[gear_i]["PowerPerRep"] * mult * v2.THROW_SECONDS
            record = max(record, power)
        else:
            throws += 1
            luck = food_luck(z) * 1.18 * (1 + v2.REBIRTH["LuckBonus"] * tier + prof["luck"])
            chances = v2.rarity_chances(v2.ZONE_RARITIES[z], luck)
            r, acc, rarity = rng.random(), 0.0, "Common"
            for name, p in chances.items():
                acc += p
                if r < acc:
                    rarity = name
                    break
            value = zones[z - 1]["BaseIncome"] * v2.RARITIES[rarity]["IncomeMult"]
            for table, scale in ((v2.MUTATIONS, v2.MUTATION_LUCK), (v2.SIZES, 0.0)):
                r, acc = rng.random(), 0.0
                for _, p, mult in v2.variant_chances(table, luck, scale):
                    acc += p
                    if r < acc:
                        value *= mult
                        break
            heroes.append(value)
            if len(heroes) > v2.MAX_SLOTS + 30:
                heroes.sort(reverse=True)
                yen += heroes.pop() * v2.SELL_SECONDS
            for name in ("Epic", "Legendary", "Mythic", "Secret"):
                if rarity == name:
                    marks.setdefault(f"first {name}", t)

        yen += income * v2.THROW_SECONDS
        t += v2.THROW_SECONDS
        if prof["offline"] and t >= next_offline:
            yen += income * prof["offline"] * 3600
            next_offline += 90 * 60.0

    return {"marks": marks, "tier": tier, "zone": reach(), "throws": throws, "samples": samples,
            "income": income, "power": power, "slots": slots, "buys": buys, "first_zone": first_zone,
            "foods": food_i + 1, "gear": gear_i + 1}


def measure_factors() -> list[float]:
    free = generate(free=True)
    acc: dict[int, list[float]] = {}
    for seed in range(8):
        r = simulate(free, PROFILES["free"], 60, seed, 0.5, True)
        for z, vals in r["samples"].items():
            acc.setdefault(z, []).append(sum(vals) / len(vals))
    return [round(sum(acc[z]) / len(acc[z]), 1) if z in acc else 0 for z in range(1, 18)]


def load() -> dict:
    return json.loads(DRAFT.read_text(encoding="utf-8"))


GROUND_ROWS = [  # id, name, rebirth tier that opens it, court side (-1 left, 1 right), the game, seconds per beat
    ("post", "Striking Post", 0, -1, "ring", 1), ("falls", "Waterfall Focus", 1, 1, "breath", 3),
    ("boulder", "Boulder Breaker", 2, -1, "sweep", 2), ("peak", "Thunder Peak", 3, 1, "reflex", 2),
    ("gravity", "Gravity Chamber", 4, -1, "rhythm", 1), ("orb", "Spirit Orb", 5, 1, "charge", 4),
    ("chains", "Titan Chains", 6, -1, "triple", 3), ("hall", "Timeless Hall", 7, 1, "medley", 2),
]
# what a ground needs beyond its numbers (plan 13 phase D; the grounds of phase E get theirs then):
# the clips (training loop, awakening loop, the one-shot that ends the awakening), the marker that is
# the rep, the line under the game, and for a game that is held: how long before the beat the hold
# must have begun
GROUND_FEEL = {
    # Marks: the seconds into Clip (ClipSeconds long) of its reps; the client runs the clip so that
    # each one falls on a beat. FinishAt: the seconds into FinishClip of its blow. Contact: how far in
    # front of the trainee the struck face is (the clips are authored to it: assets/animations batch
    # r8; the set piece's Stand part is placed from it, tools/studio/grounds/build_grounds.luau).
    "post": {"Clip": "TrainPost", "ClipSeconds": 2.0, "Marks": [0.5, 1.5], "AwakeClip": "PostFlurry",
             "FinishClip": "PostFinish", "FinishAt": 0.5, "Contact": 2.87, "Hint": "TAP AS THE RING LANDS"},
    "falls": {"Clip": "TrainBreath", "ClipSeconds": 3.0, "Marks": [2.5], "AwakeClip": "BreathAscend",
              "Hint": "HOLD, LET GO IN THE GOLD", "MinHold": 0.6},
    # phase E. Boulder: a needle sweeps a meter (the same judge as the ring, another picture).
    "boulder": {"Clip": "TrainBoulder", "ClipSeconds": 4.0, "Marks": [1.5, 3.5], "AwakeClip": "BoulderBarrage",
                "FinishClip": "BoulderFinish", "FinishAt": 0.6, "Contact": 2.87, "Hint": "TAP IN THE GOLD ZONE"},
    # Peak: a reflex game. Lanes = the rods; the rod is marked Lead seconds before the strike; the right
    # rod within React seconds of the mark is Perfect, later (before the strike) Good. LaneClips = the
    # clip played over the waiting loop when the player answers with that lane.
    "peak": {"Clip": "PeakReady", "AwakeClip": "PeakStorm", "Lanes": 3, "Lead": 1.0, "React": 0.55,
             "LaneClips": ["PeakLeft", "PeakMid", "PeakRight"], "Hint": "TAP THE MARKED ROD"},
}
# the look of each gear tier (its model: Assets.Grounds.Ground_<ground id>_T<tier>); three levels each
GEAR_MODELS = ["Wooden Post", "Banded Post", "Iron Post", "Mountain Falls", "Shrine Falls", "Granite Boulder",
               "Obsidian Boulder", "Storm Peak", "Thunder Peak", "Gravity Room", "Gravity Core", "Spirit Orb",
               "Sun Orb", "Titan Chains", "Colossus Chains", "Timeless Hall", "Hall of Ages", "Endless Dojo",
               "Hall of Gods"]
BEAT = {"PerfectBonus": 1.0, "GoodBonus": 0.5, "FocusPerfect": 2, "FocusGood": 1, "FocusFull": 40,
        "AwakeningSeconds": 8, "AwakeningMult": 1.5, "PerfectWindow": 0.12, "GoodWindow": 0.3,
        "MinTapGap": 0.1}


def load_live() -> dict:
    """design/game.json `config` in the shape the simulator plays (the roll and rebirth constants
    come from the config through econ_v2.load_live)."""
    global STALE
    v2.load_live()
    cfg = json.loads(v2.GAME.read_text(encoding="utf-8"))["config"]
    STALE = cfg["Luck"]["StaleFood"]
    plot = cfg["Plot"]
    return {"Zones": cfg["Zones"], "Foods": cfg["Foods"], "Gear": cfg["Training"]["Equipment"],
            "Rebirth": cfg["Rebirth"]["Tiers"], "Pacing": cfg.get("Pacing", {}),
            "Slots": [{"Slot": v2.START_SLOTS + i + 1, "Cost": c, "Zone": plot["SlotZones"][i]}
                      for i, c in enumerate(plot["SlotCosts"])]}


def run_apply(_a) -> int:
    """Write the draft into design/game.json `config`: foods, training levels and grounds, slot and
    rebirth prices. Zones, rarities and the roll stay as plan 12 set them."""
    d = load()
    doc = json.loads(v2.GAME.read_text(encoding="utf-8"))
    cfg = doc["config"]
    cfg["Foods"] = [{"Id": f["Id"], "Name": f["Name"], "Tier": n + 1, "Zone": f["Zone"], "Role": f["Role"],
                     "Luck": f["Luck"], "Cost": f["Cost"]} for n, f in enumerate(d["Foods"])]
    cfg.pop("Flavors", None)
    cfg["Luck"]["StaleFood"] = STALE
    names = GEAR_MODELS
    gear = []
    for g in d["Gear"]:
        model = names[g["Tier"] - 1]
        row = {"Name": f"{model} {LEVEL_NAMES[g['Level'] - 1]}", "Model": model, "Tier": g["Tier"],
               "Level": g["Level"], "Ground": min(8, v2.tier_of_zone(min(g["Tier"], 17)) + 1),
               "Cost": g["Cost"], "PowerPerRep": g["PowerPerRep"], "Zone": g["Zone"]}
        if g.get("RebirthReq"):
            row["RebirthReq"] = g["RebirthReq"]
        gear.append(row)
    training = cfg["Training"]
    training["Equipment"] = gear
    training["Grounds"] = [{"Id": gid, "Name": n, "Rebirth": t, "Side": side, "Game": game, "BeatSeconds": beat,
                            **GROUND_FEEL.get(gid, {})}
                           for gid, n, t, side, game, beat in GROUND_ROWS]
    training["Beat"] = BEAT
    for key in ("PerfectBonus", "PerfectWindow", "Stations"):
        training.pop(key, None)
    # the two courts of a base (court 1 left, court 2 right): where a ground's set piece is centred
    training["Courts"] = [{"Side": -1}, {"Side": 1}]
    plot = cfg["Plot"]
    plot["SlotCosts"] = [x["Cost"] for x in d["Slots"]]
    plot["SlotZones"] = [x["Zone"] for x in d["Slots"]]
    old = cfg["Rebirth"]["Tiers"]
    for row, new in zip(old, d["Rebirth"]):
        row["YenCost"] = new["YenCost"]
    cfg["Rebirth"]["Keeps"] = ["Heroes", "PlotSlots", "Equipment", "Foods", "Index", "Passes", "LuckyThrows",
                               "Settings", "Stats"]
    cfg["Server"].update({"ProfileStore": "Profiles_v3", "ProfileStoreStudio": "Profiles_Dev_v3"})
    cfg["Sim"] = {"TrainShare": 0.5, "TapBonus": TAP_BONUS, "TapAfk": TAP_AFK, "TapTypical": TAP_TYPICAL,
                  "TapPerfect": TAP_PERFECT, "FoodShare": FOOD_SHARE, "GearShare": GEAR_SHARE,
                  "_note": "tools/economy/econ_v3.py: `check` plays this config against Pacing"}
    v2.GAME.write_text(json.dumps(doc, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"applied economy v3: {len(cfg['Foods'])} foods, {len(gear)} training levels, "
          f"{len(training['Grounds'])} grounds")
    return 0


def run_check(a) -> int:
    d = load_live()
    results = [simulate(d, PROFILES["free"], a.hours, seed, 0.5) for seed in range(a.runs)]
    marks = v2.median_marks(results)
    failed = 0
    for name, (lo, hi) in d["Pacing"].items():
        hit = next((v for k, v in marks.items() if " ".join(k.split()[:2]) == name), None)
        ok = hit is not None and lo * 60 <= hit <= hi * 60
        failed += 0 if ok else 1
        print(f"  {'ok  ' if ok else 'MISS'} {name:<12} target {lo:g}-{hi:g} min, got "
              f"{v2.clock(hit) if hit is not None else 'never'}")
    if failed:
        print(f"{failed} pacing target(s) missed")
    return 1 if failed else 0


def run_gen(_a) -> int:
    factors = measure_factors()
    DRAFT.write_text(json.dumps(generate(factors=factors), indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"factors {factors}\nwrote {DRAFT.relative_to(ROOT)}")
    return 0


def run_sim(a) -> int:
    d = load()
    names = [a.profile] if a.profile else list(PROFILES)
    keys = ["ZONE  2", "ZONE  3", "REBIRTH 1", "REBIRTH 2", "REBIRTH 3", "REBIRTH 4", "REBIRTH 5", "REBIRTH 6",
            "REBIRTH 7", "ZONE 17", "REBIRTH 8", "first Epic", "first Legendary", "first Mythic"]
    table = {}
    for name in names:
        results = [simulate(d, PROFILES[name], a.hours, seed, a.train_share) for seed in range(a.runs)]
        table[name] = v2.median_marks(results)
    print(f"{'milestone':<18}" + "".join(f"{n:>14}" for n in names))
    for key in keys:
        cells = []
        for name in names:
            hit = next((v for k, v in table[name].items() if k.startswith(key)), None)
            cells.append(f"{v2.clock(hit) if hit is not None else '-':>14}")
        print(f"{key:<18}" + "".join(cells))
    if "free" in table:
        print("\npacing windows (plan 12, approved), free profile:")
        for name, (lo, hi) in v2.PACING.items():
            hit = next((v for k, v in table["free"].items() if " ".join(k.split()[:2]) == name), None)
            ok = hit is not None and lo * 60 <= hit <= hi * 60
            print(f"  {'ok  ' if ok else 'MISS'} {name:<10} {lo:g}-{hi:g} min, got {v2.clock(hit) if hit else 'never'}")
    return 0


def run_cadence(a) -> int:
    """Minutes between purchases, by the zone the player stands in (free profile, median of runs)."""
    d = load()
    per_zone: dict[int, list[float]] = {}
    longest: dict[int, list[float]] = {}
    counts: dict[int, list[int]] = {}
    for seed in range(a.runs):
        r = simulate(d, PROFILES["free"], a.hours, seed, a.train_share)
        times = sorted(r["first_zone"].items())
        for i, (z, start) in enumerate(times):
            stop = times[i + 1][1] if i + 1 < len(times) else a.hours * 3600
            if i + 1 >= len(times):
                continue
            inside = [t for t, _, _ in r["buys"] if start <= t < stop]
            edges = [start] + inside + [stop]
            gaps = [(b - c) / 60 for c, b in zip(edges, edges[1:])]
            counts.setdefault(z, []).append(len(inside))
            per_zone.setdefault(z, []).append((stop - start) / 60 / max(1, len(inside)))
            longest.setdefault(z, []).append(max(gaps))
    print("zone   minutes   buys   mean gap   longest gap  (minutes, median of runs)")
    for z in sorted(per_zone):
        med = lambda xs: sorted(xs)[len(xs) // 2]  # noqa: E731
        span = med(per_zone[z]) * max(1, med(counts[z]))
        print(f"{z:>4} {span:>9.0f} {med(counts[z]):>6} {med(per_zone[z]):>10.1f} {med(longest[z]):>13.1f}")
    return 0


def run_table(_a) -> int:
    d = load()
    print("FOODS")
    for f in d["Foods"]:
        print(f"  z{f['Zone']:>2} {f['Role']:<9} {f['Name']:<26} {f['Flavor']:<8} luck x{f['Luck']:<5} {v2.fmt(f['Cost']):>8}")
    print("GEAR")
    for g in d["Gear"]:
        print(f"  tier {g['Tier']:>2}.{g['Level']} zone {g['Zone']:>2}  +{v2.fmt(g['PowerPerRep']):>8}/rep  {v2.fmt(g['Cost']):>8}"
              + (f"  rebirth {g['RebirthReq']}" if g.get("RebirthReq") else ""))
    print("SLOTS " + ", ".join(v2.fmt(s["Cost"]) for s in d["Slots"]))
    print("REBIRTH " + ", ".join(f"{r['Tier']}: {v2.fmt(r['PowerReq'])} power + {v2.fmt(r['YenCost'])}" for r in d["Rebirth"]))
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("gen")
    s = sub.add_parser("sim")
    s.add_argument("--profile", default=None, choices=sorted(PROFILES))
    c = sub.add_parser("cadence")
    sub.add_parser("table")
    sub.add_parser("apply")
    k = sub.add_parser("check")
    k.add_argument("--hours", type=float, default=44)
    k.add_argument("--runs", type=int, default=3)
    for p in (s, c):
        p.add_argument("--hours", type=float, default=48)
        p.add_argument("--runs", type=int, default=5)
        p.add_argument("--train-share", type=float, default=0.5)
    a = ap.parse_args()
    return {"gen": run_gen, "sim": run_sim, "cadence": run_cadence, "table": run_table, "apply": run_apply,
            "check": run_check}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
