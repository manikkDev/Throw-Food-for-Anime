#!/usr/bin/env python3
"""Economy pacing simulator for Throw Food for Anime.

    python tools/balance_sim.py                      # reads design/game.json `config`
    python tools/balance_sim.py --config draft.json  # a bare config object
    python tools/balance_sim.py --hours 30 --runs 5 --check

WHY THIS EXISTS. The whole game is one exponential ladder (power -> zone -> income ->
equipment/food/slots -> power). A single wrong exponent moves a zone gate from "ten minutes"
to "four hours" and no code gate can see it, because the code is correct either way. This
script plays the ladder with a simple greedy player and prints WHEN each milestone lands, so a
balance pass is: edit the numbers in design/game.json, run this, read the table.

`--check` exits 1 when a milestone lands outside the target window in `config.Pacing`, so
pacing drift is caught by a command, not by a playtest three sections later.

The player model is deliberately dumb (it is a floor, not a speedrun): it throws on a fixed
cycle, trains whenever more power would unlock something, and buys the cheapest useful thing
it can afford. A real player with luck boosts and offline income is faster than this.
"""

from __future__ import annotations

import argparse
import json
import random
import sys
from pathlib import Path


def load_config(path: Path) -> dict:
    doc = json.loads(path.read_text(encoding="utf-8"))
    return doc.get("config", doc)


def fmt(n: float) -> str:
    for suffix, size in (("Qa", 1e15), ("T", 1e12), ("B", 1e9), ("M", 1e6), ("K", 1e3)):
        if abs(n) >= size:
            return f"{n / size:.2f}{suffix}"
    return f"{n:.0f}"


def clock(seconds: float) -> str:
    h, rem = divmod(int(seconds), 3600)
    return f"{h}h{rem // 60:02d}m" if h else f"{rem // 60}m{rem % 60:02d}s"


def roll_character(cfg: dict, zone_index: int, luck: float, rng: random.Random) -> float:
    """Return the income/s of one catch in `zone_index` (0-based) at `luck`."""
    zone = cfg["Zones"][zone_index]
    rar = cfg["Rarities"]
    names, weights = [], []
    for rarity, count in zone["Slots"].items():
        r = rar[rarity]
        w = r["Weight"] * (1 + (luck - 1) * r["LuckScale"]) * count
        names.append(rarity)
        weights.append(w)
    rarity = rng.choices(names, weights)[0]
    income = zone["BaseIncome"] * rar[rarity]["IncomeMult"]
    for table in (cfg["Mutations"], cfg["Sizes"]):
        roll, acc = rng.random(), 0.0
        for entry in table:
            acc += min(1.0, entry["Chance"] * (1 + (luck - 1) * entry.get("LuckScale", 0)))
            if roll < acc:
                income *= entry["IncomeMult"]
                break
    return income


def simulate(cfg: dict, hours: float, seed: int) -> dict:
    rng = random.Random(seed)
    zones, equip, foods = cfg["Zones"], cfg["Training"]["Equipment"], cfg["Foods"]
    plot = cfg["Plot"]
    throw_cycle = cfg["Throw"]["CycleSeconds"]
    rep_seconds = cfg["Training"]["RepSeconds"]

    yen, power = 0.0, float(cfg["Training"]["StartPower"])
    eq_i, food_i, slots = 0, 0, plot["StartSlots"]
    team: list[float] = []
    t, zone_i = 0.0, 0
    milestones: dict[str, float] = {}
    end = hours * 3600

    def slot_cost(n: int) -> float:  # cost of buying slot number n (1-based count after purchase)
        return plot["SlotBaseCost"] * plot["SlotCostGrowth"] ** (n - plot["StartSlots"] - 1)

    def best_zone() -> int:
        eff = power * foods[food_i]["PowerMult"]
        z = 0
        for i, zone in enumerate(zones):
            if eff >= zone["PowerReq"]:
                z = i
        return z

    while t < end:
        income = sum(team)
        # --- spend: cheapest useful purchase first -------------------------
        bought = True
        while bought:
            bought = False
            options = []
            if eq_i + 1 < len(equip):
                options.append((equip[eq_i + 1]["Cost"], "eq"))
            if food_i + 1 < len(foods):
                options.append((foods[food_i + 1]["Cost"], "food"))
            if slots < plot["MaxSlots"]:
                options.append((slot_cost(slots + 1), "slot"))
            options.sort()
            # In the last zone a sensible player saves for the rebirth instead of
            # sinking the same money into a slot or food that costs as much as it does.
            if zone_i == len(zones) - 1 and "REBIRTH 1 ready" not in milestones:
                cap = cfg["Rebirth"]["Tiers"][0]["YenCost"] * cfg["Sim"].get("SaveCapShare", 0.25)
                options = [o for o in options if o[1] == "eq" or o[0] <= cap]
            if options and yen >= options[0][0]:
                cost, kind = options[0]
                yen -= cost
                if kind == "eq":
                    eq_i += 1
                    milestones.setdefault(f"equip {eq_i + 1} {equip[eq_i]['Name']}", t)
                elif kind == "food":
                    food_i += 1
                    milestones.setdefault(f"food {food_i + 1} {foods[food_i]['Name']}", t)
                else:
                    slots += 1
                bought = True

        # --- act: train if the next zone is within reach of training, else throw
        z = best_zone()
        if z != zone_i:
            zone_i = z
            milestones.setdefault(f"ZONE {z + 1} {zones[z]['Name']}", t)
        nxt = zones[z + 1]["PowerReq"] if z + 1 < len(zones) else None
        eff = power * foods[food_i]["PowerMult"]
        ppr = equip[eq_i]["PowerPerRep"]
        train = False
        if nxt is not None:
            seconds_to_next = (nxt - eff) / (ppr * foods[food_i]["PowerMult"]) * rep_seconds
            # train when the gate is reachable in a reasonable sitting, and always keep
            # throwing enough to fill the plot first
            train = len(team) >= slots and seconds_to_next < 3600 * 2
        else:
            # last zone: nothing left to unlock, so power only matters for the rebirth gate
            train = len(team) >= cfg["Plot"]["StartSlots"] and rng.random() < 0.5
        if rng.random() < cfg["Sim"]["TrainShare"]:
            train = True if nxt is not None else train

        if train:
            # one decision = one throw-cycle's worth of reps, so TrainShare is a share of
            # TIME, not of decisions (a 1 s rep against a 5 s throw skewed it sixfold)
            reps = max(1, round(throw_cycle / rep_seconds))
            power += ppr * reps
            dt = rep_seconds * reps
        else:
            luck = foods[food_i]["Luck"]
            if nxt is not None:
                span = max(1.0, nxt - zones[z]["PowerReq"])
                depth = min(1.0, max(0.0, (eff - zones[z]["PowerReq"]) / span))
                luck *= 1 + depth * cfg["Throw"]["DepthLuckBonus"]
            catch = roll_character(cfg, z, luck, rng)
            if len(team) < slots:
                team.append(catch)
            else:
                worst = min(range(len(team)), key=team.__getitem__)
                if catch > team[worst]:
                    yen += team[worst] * plot["SellSeconds"]
                    team[worst] = catch
                else:
                    yen += catch * plot["SellSeconds"]
            dt = throw_cycle
        yen += income * dt
        t += dt

        rb = cfg["Rebirth"]["Tiers"][0]
        if "REBIRTH 1 ready" not in milestones and power >= rb["PowerReq"] and yen >= rb["YenCost"]:
            milestones["REBIRTH 1 ready"] = t

    return {"milestones": milestones, "income": sum(team), "power": power, "yen": yen, "slots": slots}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--config", default=str(Path(__file__).resolve().parent.parent / "design" / "game.json"))
    ap.add_argument("--hours", type=float, default=40)
    ap.add_argument("--runs", type=int, default=5)
    ap.add_argument("--check", action="store_true", help="exit 1 if a milestone misses its Pacing window")
    a = ap.parse_args()

    cfg = load_config(Path(a.config))
    results = [simulate(cfg, a.hours, seed) for seed in range(a.runs)]

    keys: list[str] = []
    for r in results:
        for k in r["milestones"]:
            if k not in keys:
                keys.append(k)
    median: dict[str, float] = {}
    for k in keys:
        vals = sorted(r["milestones"][k] for r in results if k in r["milestones"])
        if len(vals) * 2 >= len(results):
            median[k] = vals[len(vals) // 2]

    print(f"{'milestone':<34}{'median':>10}   (over {a.runs} runs, {a.hours:g}h each)")
    for k, v in sorted(median.items(), key=lambda kv: kv[1]):
        print(f"{k:<34}{clock(v):>10}")
    last = results[len(results) // 2]
    print(f"\nat {a.hours:g}h: income {fmt(last['income'])}/s  power {fmt(last['power'])}  "
          f"yen {fmt(last['yen'])}  slots {last['slots']}")

    failed = 0
    for name, (lo, hi) in cfg.get("Pacing", {}).items():
        hit = next((v for k, v in median.items() if k.startswith(name)), None)
        ok = hit is not None and lo * 60 <= hit <= hi * 60
        if not ok:
            failed += 1
        print(f"  {'ok  ' if ok else 'MISS'} {name:<18} target {lo:g}-{hi:g} min, got "
              f"{clock(hit) if hit is not None else 'never'}")
    if a.check and failed:
        print(f"\n{failed} pacing target(s) missed")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
