"""The anime town for gen_map.py (map v3, brief E + research 06 sections 1.4, 1.5 and 5).

Every model comes from gen_map.pool(zone, kind) (design/store_assets.json tags + the measured
manifest; generated models only where no store piece of that kind exists for the zone). Nothing
here names a store model.

  terraces()    wall tops: parapet is in gen_lane_style; here a FACADE ROW 6+ studs back from each
                lane edge in clusters of 3-5 touching buildings with tree gaps (~45% coverage), and
                ONE centre-line landmark per zone, alternating walls so every lane sees one per zone
  outer_tiers() the town continuing up the hills behind the outer walls, thinning with distance
  hub_backdrop() one subject: a hillside shrine town in three layers, the castle as far landmark
  harbour()     the pirate bay (ship, docks, rock; palms and lighthouse only if no store piece)

Every placement loop has a hard iteration cap (guard()): a loop whose step can reach zero raises
with its own name instead of spinning (a v3 run hung for minutes on exactly that).
"""
from __future__ import annotations

import math
import random

G_ = {}
LOOP_CAP = 20000
FACADE_SETBACK = 6.0       # research 1.4/1.5: facade row 6-14 back, top floor and roof show
ROW_DEPTH_INNER = 18.0     # deepest footprint a row building may have on a 52-wide terrace
ROW_DEPTH_OUTER = 30.0
CLUSTER = (3, 5)           # buildings per cluster
TREE_GAP = (60, 100)       # studs of trees between clusters
MIN_SCALE = 0.62
LANDMARK_H = (55, 110)     # wanted landmark height (research 1.5 rule 6: 60-110)
STATS = {"row_buildings": 0, "row_trees": 0, "landmarks": 0, "tier_props": 0, "hub_backdrop": 0,
         "gap_props": 0}


def install(ns):
    G_.update(ns)


def guard(name, n):
    if n > LOOP_CAP:
        raise SystemExit(f"gen_town.{name}: placement loop exceeded {LOOP_CAP} iterations (step <= 0?)")


def _g(k):
    return G_[k]


def size_of(kit, scale=1.0):
    return [v * scale for v in _g("SIZES")[kit]]


def pick(zone, kind, k, prev=None, fit=None):
    """A model of `kind` for `zone`, cycled from k, not prev, passing fit(kit) -> scale or None."""
    names = _g("pool")(zone, kind)
    avail = _g("available")
    for t in range(len(names)):
        c = names[(k + t) % len(names)]
        if c == prev or not avail(c):
            continue
        sc = fit(c) if fit else 1.0
        if sc:
            return c, sc
    return None, None


def walls():
    """Every terrace: (key, centre x, width, faces = directions toward the lanes)."""
    out = []
    for k, gx in enumerate(_g("GAPS"), 1):
        out.append((f"WallIn{k}", gx, _g("WALL_GAP"), (-1, 1)))
    OUTER, OUTER_T = _g("OUTER"), _g("OUTER_T")
    out.insert(0, ("WallOutW", -(OUTER + OUTER_T / 2), OUTER_T, (1,)))
    out.append(("WallOutE", OUTER + OUTER_T / 2, OUTER_T, (-1,)))
    return out


def top_at(key, z0, z1):
    tops = [t for kk, segs in _g("WALL_TOPS").items() if kk == key or kk.startswith(key)
            for (a, b, t) in segs if a < z1 and b > z0]
    return min(tops) if tops else None, (max(tops) if tops else None)


def terraces(rng):
    band_at, mesh, BANDS = _g("band_at"), _g("mesh"), _g("BANDS")
    WALL_Z0, WALL_Z1 = _g("WALL_Z0"), _g("WALL_Z1")
    W = walls()
    excl = {}
    # ---- landmarks: one per zone, alternating walls so every lane has one beside it per zone
    for zi, b in enumerate(BANDS):
        chosen = [w for wi, w in enumerate(W) if wi % 2 == (1 if zi % 2 == 0 else 0)]
        for wj, (key, xc, width, faces) in enumerate(chosen):
            if b.get("bay") and key == "WallOutE":
                continue
            kinds = b.get("town", {}).get("landmark", ["tower"])

            def fit(c, width=width):
                sx, sy, sz = size_of(c)
                sc = min((width - 6) / max(sx, sz), LANDMARK_H[1] / sy)
                return sc if sy * sc >= 40 else None
            kit, sc = None, None
            for t, kind in enumerate(kinds):
                kit, sc = pick(b["id"], kind, zi + wj + t, fit=fit)
                if kit:
                    break
            if not kit:
                continue
            z = (b["z0"] + b["z1"]) / 2 + rng.uniform(-50, 50) + (40 if wj % 2 else -40)
            sx, sy, sz = size_of(kit, sc)
            lo, hi = top_at(key, z - sz / 2, z + sz / 2)
            if lo is None:
                continue
            mesh(f"LM_{b['id']}_{key}", kit, xc, hi - 0.3, z, yaw=180 if xc < 0 else 0, solid=False,
                 folder=f"Scenery/Town_{b['id']}", biome=b["id"], scale=round(sc, 3), extra={"far": True})
            excl.setdefault(key, []).append((z - max(sx, sz) / 2 - 6, z + max(sx, sz) / 2 + 6))
            STATS["landmarks"] += 1
    # ---- facade rows: one per lane-facing edge of every terrace
    for wi, (key, xc, width, faces) in enumerate(W):
        for side in faces:
            dmax = ROW_DEPTH_INNER if len(faces) == 2 else ROW_DEPTH_OUTER
            edge = xc + side * width / 2
            yaw = 270 if side > 0 else 90
            z = WALL_Z0 + 34 + rng.uniform(0, 50) + (0 if side > 0 else 45)
            kcyc = wi * 7 + (side > 0) * 3
            it = 0
            while z < WALL_Z1 - 24:
                it += 1
                guard("terraces.row", it)
                b = band_at(z)
                zone = b["id"]
                row = b.get("town", {}).get("row", ["house"])
                if any(a <= z <= c for a, c in excl.get(key, [])):
                    z = next(c for a, c in excl[key] if a <= z <= c) + 1
                    continue
                if b.get("bay") and key == "WallOutE":
                    z = b["z1"] + 1
                    continue
                # a cluster of touching buildings sharing (about) one eave line
                n = rng.randint(*CLUSTER)
                prev = None
                placed = 0
                for j in range(n):
                    kind = row[(kcyc + j) % len(row)]

                    def fit(c):
                        sx, sy, sz = size_of(c)
                        sc = min(1.0, dmax / sz)
                        return sc if sc >= MIN_SCALE else None
                    kit, sc = pick(zone, kind, kcyc + j, prev, fit)
                    if not kit:
                        continue
                    sx, sy, sz = size_of(kit, sc)
                    if z + sx > b["z1"] - 4 or any(a <= z + sx and z <= c for a, c in excl.get(key, [])):
                        break
                    lo, hi = top_at(key, z, z + sx)
                    if lo is None or hi - lo > 4:
                        break          # a big step in the wall top under one building: end the cluster
                    x = edge - side * (FACADE_SETBACK + sz / 2)
                    mesh(f"Row_{key}_{side}_{int(z)}", kit, x, hi - 0.3, z + sx / 2, yaw=yaw, solid=False,
                         folder=f"Scenery/Town_{zone}", biome=zone, scale=round(sc, 3), extra={"atomic": True})
                    STATS["row_buildings"] += 1
                    placed += 1
                    prev = kit
                    z += sx + 0.4
                kcyc += max(placed, 1)
                # trees (and one gap piece) between clusters, on the row line
                gap = rng.uniform(*TREE_GAP)
                spine = [k for k in b.get("town", {}).get("spine", ["tree"]) if k != "lantern"] or ["tree"]
                gap_kinds = b.get("town", {}).get("gap", [])
                zt = z + 8
                t = 0
                while zt < min(z + gap - 8, b["z1"] - 6):
                    t += 1
                    guard("terraces.trees", t)
                    kind = gap_kinds[0] if (gap_kinds and t == 2 and STATS["gap_props"] < 40) else spine[t % len(spine)]
                    kit, sc = pick(zone, kind, kcyc + t,
                                   fit=lambda c: min(1.0, (dmax + 2) / max(size_of(c)[0], size_of(c)[2])))
                    if kit:
                        sx, sy, sz = size_of(kit, sc)
                        lo, hi = top_at(key, zt - sx / 2, zt + sx / 2)
                        if lo is not None:
                            along = kind in gap_kinds and sz > sx
                            x = edge - side * (FACADE_SETBACK + (sx if along else sz) / 2 + 1)
                            mesh(f"RowT_{key}_{side}_{int(zt)}", kit, x, lo - 0.3, zt,
                                 yaw=0 if along else rng.uniform(0, 360), solid=False,
                                 folder=f"Scenery/Town_{zone}", biome=zone, scale=round(sc, 3))
                            if kind in gap_kinds:
                                STATS["gap_props"] += 1
                            else:
                                STATS["row_trees"] += 1
                    zt += rng.uniform(22, 32)
                z += gap


def outer_tiers(G, rng):
    """The town continues up the hills behind the outer walls in three treads (HILL_PROFILE),
    thinning with distance: houses every 40-55 on the first, 60-85 on the second, trees on the top."""
    band_at, mesh, OW = _g("band_at"), _g("mesh"), _g("OW")
    LANE0, LANE_END, HUB_Z0 = _g("LANE0"), _g("LANE_END"), _g("HUB_Z0")
    tiers = _g("HILL_TIERS")
    n = 0
    for sx in (-1, 1):
        for ti, (d, step, kinds_key) in enumerate(tiers):
            z = HUB_Z0 + 40 + ti * 23 + rng.uniform(0, 20)
            k = ti * 5 + (sx > 0)
            it = 0
            while z < LANE_END + 60:
                it += 1
                guard("outer_tiers", it)
                b = band_at(max(z, LANE0))
                kinds = b.get("town", {}).get("hills", ["house", "tree"])
                kind = kinds[k % len(kinds)] if kinds_key == "mix" else "tree"
                k += 1
                x = sx * (OW + 2 + d)
                if G.raw(x, z) < 4:
                    z += step[0]
                    continue

                def fit(c):
                    s_ = size_of(c)
                    return min(1.0, 24.0 / max(s_[0], s_[2]))
                kit, sc = pick(b["id"], kind, k, fit=fit)
                if kit:
                    s_ = size_of(kit, sc)
                    mesh(f"Tier_{n}", kit, x, G.foot(x, z, s_[0] / 2, s_[2] / 2) - 0.8, z,
                         yaw=(90 if sx > 0 else 270) if kind != "tree" else rng.uniform(0, 360), solid=False,
                         folder="Scenery/Hills", biome=b["id"], scale=round(sc, 3), extra={"far": True})
                    n += 1
                    STATS["tier_props"] += 1
                z += rng.uniform(*step)
    # the far-end hill: a thin line of the last zone's trees
    last = _g("BANDS")[-1]
    x = -OW - 100
    it = 0
    while x < OW + 100:
        it += 1
        guard("outer_tiers.end", it)
        z = LANE_END + 110 + rng.uniform(-10, 10)
        if G.raw(x, z) > -2:
            kit, sc = pick(last["id"], "tree", it, fit=lambda c: 1.0)
            if kit:
                mesh(f"EndTree_{it}", kit, x, G.surf(x, z) - 0.8, z, yaw=rng.uniform(0, 360), solid=False,
                     folder="Scenery/Hills", biome="hills", extra={"far": True})
                STATS["tier_props"] += 1
        x += rng.uniform(60, 80)


def hub_backdrop(G, rng):
    """Research 1.3/5B: ONE subject, a hillside shrine town in three layers behind the low hub wall.
    Near: a continuous street of touching facades on the ledge. Mid: roofs stepping up two treads,
    sakura between them, the waterfalls. Far: the castle on the centre axis, 150-200 studs tall, with
    a pagoda at about two thirds of its height to each side."""
    mesh, OCC = _g("mesh"), _g("OCC")
    HUB = _g("HUB_HILL")
    zc, xr = HUB["zc"], _g("HOME_HALF") - 30
    F = "Scenery/HubBackdrop"

    def z_at(d):
        return zc + HUB["half"] - d          # distance d in from the hill's front edge

    def place(pid, kit, x, z, yaw=180, scale=1.0, far=False, sink=0.8):
        s_ = size_of(kit, scale)
        base = G.foot(x, z, s_[0] / 2 * 0.6, s_[2] / 2 * 0.6) - sink
        mesh(pid, kit, x, base, z, yaw=yaw, solid=False, folder=F, biome="hub", scale=round(scale, 3),
             extra={"far": far, "shadow": not far})
        OCC.append((x, z, max(s_[0], s_[2]) / 2))
        STATS["hub_backdrop"] += 1
        return s_

    # FAR: the castle
    castle, _ = pick("hub", "castle", 0, fit=lambda c: 1.0)
    if castle:
        sc = 172.0 / size_of(castle)[1]
        # sunk 30 so the hill swallows its stone plinth; a row of houses and sakura dresses its foot
        place("HubCastle", castle, 0, z_at(HUB["half"]), scale=sc, far=True, sink=30)
    temples = _g("pool")("hub", "temple")
    for k, (x, hgt) in enumerate(((-175, 112), (190, 92))):
        if temples:
            t = temples[k % len(temples)]
            place(f"HubPagoda{k}", t, x, z_at(HUB["tiers"][2][0] + 10), scale=hgt / size_of(t)[1], far=True, sink=4)
    # NEAR: one street of touching facades, 1.5x (20-26 tall), shadows on
    houses = _g("pool")("hub", "house") + _g("pool")("hub", "shop")
    x, k, it = -xr, 0, 0
    zn = z_at(HUB["tiers"][0][0])
    while x < xr and houses:
        it += 1
        guard("hub_backdrop.near", it)
        kit = houses[k % len(houses)]
        k += 1
        sc = 1.5
        w = size_of(kit, sc)[0]
        if x + w > xr:
            break
        place(f"HubNear{k}", kit, x + w / 2, zn - size_of(kit, sc)[2] / 2, scale=sc, sink=1.0)
        x += w + 0.4
    # MID: two treads of roofs stepping up, gaps for sakura; waterfalls on the risers
    trees = _g("pool")("hub", "tree")
    falls = _g("pool")("hub", "waterfall")
    for ti, (d, step, sc) in enumerate(((HUB["tiers"][1][0] + 8, (36, 52), 1.2), (HUB["tiers"][2][0] + 12, (48, 70), 1.1))):
        x, it = -xr + rng.uniform(0, 30), 0
        zz = z_at(d)
        while x < xr:
            it += 1
            guard("hub_backdrop.mid", it)
            if it % 3 == 0 and trees:
                t = trees[it % len(trees)]
                if _g("available")(t):
                    place(f"HubSakura{ti}_{it}", t, x, zz + rng.uniform(-6, 6), yaw=rng.uniform(0, 360), scale=1.2)
            elif houses:
                h = houses[(it + ti) % len(houses)]
                place(f"HubMid{ti}_{it}", h, x, zz, scale=sc, far=ti == 1)
            x += rng.uniform(*step)
    sheet = next((f for f in falls if size_of(f)[0] < 40), None)
    cliff = next((f for f in falls if size_of(f)[0] >= 40), None)
    if cliff:
        place("HubWaterfallCliff", cliff, 120, z_at(HUB["tiers"][1][0] + 4), scale=0.7, far=False, sink=6)
    if sheet:
        for k, x in enumerate((-90, 40)):
            d = HUB["tiers"][1][0] - 2
            place(f"HubWaterfall{k}", sheet, x, z_at(d), scale=1.3, sink=2)


def harbour(G, rng):
    """The pirate bay on the east side: ship and docks (no store piece of that role exists), rock;
    palms and the lighthouse come from the pools, so store pieces replace the generated ones."""
    BAY, b = _g("BAY"), _g("BAY_BAND")
    if not b:
        return
    mesh, OW = _g("mesh"), _g("OW")
    F = f"Scenery/Town_{b['id']}"
    bx, bz = BAY["c"]
    mesh("Bay_Ship", "Prop_pirate_harbor_PirateShip", bx + 4, -8.0, bz - 6, yaw=-12, solid=False, folder=F,
         biome=b["id"], extra={"far": True})
    mesh("Bay_SkullRock", "Prop_pirate_harbor_SkullRock", bx + 30, -10.0, bz + 70, yaw=200, solid=False,
         folder=F, biome=b["id"], extra={"far": True})
    tower, sc = pick(b["id"], "tower", 0, fit=lambda c: 1.0)
    if tower:
        lx, lz = bx + 30, b["z1"] + 10
        mesh("Bay_Tower", tower, lx, G.foot(lx, lz, 6, 6) - 1.0, lz, yaw=200, roles=("landmark", "prop"),
             solid=False, folder=F, biome=b["id"], extra={"far": True})
    for k, dz in enumerate((-46, 4, 52)):
        mesh(f"Bay_Dock{k}", "Prop_pirate_harbor_Dock", OW + 26, -2.4, bz + dz, yaw=90, solid=False,
             folder=F, biome=b["id"])
    for k, dz in enumerate((-80, -20, 40, 96)):
        palm, _ = pick(b["id"], "tree", k, fit=lambda c: 1.0)
        if palm:
            x = OW + 8
            mesh(f"Bay_Palm{k}", palm, x, G.surf(x, bz + dz) - 0.8, bz + dz, yaw=rng.uniform(0, 360), solid=False,
                 folder=F, biome=b["id"])
