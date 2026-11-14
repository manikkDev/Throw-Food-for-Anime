--!strict
-- Roll - who a throw lures, and how rare that really was. Pure.
--
-- Three independent draws: hero (by zone table, scaled by luck and craving),
-- mutation, size. The "1 in N" shown to the player is 1 / (pHero x pMutation x
-- pSize) computed from the SAME weights that rolled, so it cannot disagree
-- with what happened.
--
-- Randomness is injected: `rng()` returns a number in [0, 1). Specs pass a
-- seeded generator; the server passes Random:NextNumber.

local Roll = {}

export type HeroWeight = { id: string, rarity: string, weight: number, chance: number }

export type Result = {
	id: string,
	rarity: string,
	mutation: string?,
	size: string?,
	pHero: number,
	pMutation: number,
	pSize: number,
	oneInN: number,
}

--- Weight and chance of every hero in a zone at `luck`, optionally with a
--- thrown food `flavor` (a craved flavour multiplies that hero's weight).
--- `zoneCharacters` is Lookup.of(cfg).zoneCharacters[zoneId].
function Roll.heroWeights(
	cfg: any,
	zoneCharacters: { any },
	luck: number,
	flavor: string?
): { HeroWeight }
	local rows: { HeroWeight } = {}
	local total = 0
	for _, character in zoneCharacters do
		local rarity = cfg.Rarities[character.Rarity]
		local weight = rarity.Weight * (1 + (math.max(1, luck) - 1) * rarity.LuckScale)
		if flavor ~= nil and character.Craves == flavor then
			weight *= cfg.Throw.CravingWeightMult
		end
		total += weight
		table.insert(
			rows,
			{ id = character.Id, rarity = character.Rarity, weight = weight, chance = 0 }
		)
	end
	for _, row in rows do
		row.chance = if total > 0 then row.weight / total else 0
	end
	return rows
end

--- Pick a row by weight. `r` in [0, 1).
function Roll.pick(rows: { HeroWeight }, r: number): HeroWeight
	local acc = 0
	for _, row in rows do
		acc += row.chance
		if r < acc then
			return row
		end
	end
	return rows[#rows]
end

--- One draw over a variant table (Mutations or Sizes), rarest first. The
--- chances are bands of one roll, so at most one variant is ever returned.
--- Returns the variant name (or nil for "none") and the probability of exactly
--- that outcome.
function Roll.variant(
	variants: { any },
	luck: number,
	r: number,
	chanceMult: number
): (string?, number)
	local acc = 0
	local picked: string? = nil
	local pickedChance = 0
	for _, variant in variants do
		local scale = 1 + (math.max(1, luck) - 1) * (variant.LuckScale or 0)
		local chance = math.min(variant.Chance * scale * chanceMult, 1 - acc)
		if chance < 0 then
			chance = 0
		end
		if picked == nil and r >= acc and r < acc + chance then
			picked = variant.Name
			pickedChance = chance
		end
		acc += chance
	end
	if picked ~= nil then
		return picked, pickedChance
	end
	return nil, math.max(1 - acc, 1e-12)
end

--- A full catch.
function Roll.throw(
	cfg: any,
	zoneCharacters: { any },
	luck: number,
	flavor: string?,
	rng: () -> number,
	mutationMult: number?
): Result
	local rows = Roll.heroWeights(cfg, zoneCharacters, luck, flavor)
	local hero = Roll.pick(rows, rng())
	local mutation, pMutation = Roll.variant(cfg.Mutations, luck, rng(), mutationMult or 1)
	local size, pSize = Roll.variant(cfg.Sizes, luck, rng(), 1)
	local p = math.max(hero.chance * pMutation * pSize, 1e-300)
	return {
		id = hero.id,
		rarity = hero.rarity,
		mutation = mutation,
		size = size,
		pHero = hero.chance,
		pMutation = pMutation,
		pSize = pSize,
		oneInN = 1 / p,
	}
end

--- A hero picked from a fixed percentage table (the summon scroll). `odds` is
--- a list of { Id, OddsPercent } that sums to 100; the same list is what the
--- odds screen shows, so screen and roll cannot disagree.
function Roll.byPercent(odds: { any }, r: number): any
	local total = 0
	for _, row in odds do
		total += row.OddsPercent
	end
	local acc = 0
	for _, row in odds do
		acc += row.OddsPercent / total
		if r < acc then
			return row
		end
	end
	return odds[#odds]
end

--- Best of `count` hero draws by rarity order: used nowhere by default, kept
--- for event throws ("best of N").
function Roll.rarityOrder(cfg: any, rarity: string): number
	return cfg.Rarities[rarity].Order
end

return Roll
