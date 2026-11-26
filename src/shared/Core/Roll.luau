--!strict
-- Roll - who a throw lures, and how rare that really was. Pure.
--
-- Three independent draws: hero, mutation, size.
--
-- THE HERO (plan 12, section 3.1). Each rarity from Rare up has a base chance
-- "1 in OneIn". Luck divides it: chance = luck ^ LuckPower / OneIn. The roll
-- is one number cut into bands, RAREST FIRST, so luck never stops helping the
-- top of the table. What the bands leave goes to Uncommon and Common
-- (UncommonShare of it to Uncommon); the least rare band (Rare) always leaves
-- them CommonFloor of the roll, so a Common stays catchable for the Index.
-- Heroes of one rarity share its chance; a hero whose FAVOURITE dish is the
-- thrown food counts CravingWeightMult times inside its rarity (plan 13).
--
-- THE SCORE. The "1 in N" on the catch card is rarity odds x mutation odds x
-- size odds AT BASE ODDS (luck 1): the same catch shows the same number for
-- every player, so the leaderboard cannot reward low luck. No mutation / no
-- size counts as 1: a plain Mythic is exactly "1 in 10,000".
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
	-- what really rolled, at the player's luck
	pHero: number,
	pMutation: number,
	pSize: number,
	-- the score: base odds, the same for everyone
	oneInN: number,
}

--- Chance of each rarity the zone holds at `luck`. `floor` (a rarity name)
--- moves everything rarer-than-nothing-below-it up: a Lucky Throw is never
--- below Epic. Sums to 1.
function Roll.rarityChances(
	cfg: any,
	zoneCharacters: { any },
	luck: number,
	floor: string?
): { [string]: number }
	local present: { [string]: boolean } = {}
	for _, character in zoneCharacters do
		present[character.Rarity] = true
	end
	-- the luck-scaled bands, rarest first
	local bands: { string } = {}
	for name, rarity in cfg.Rarities do
		if present[name] and rarity.OneIn then
			table.insert(bands, name)
		end
	end
	table.sort(bands, function(a, b)
		return cfg.Rarities[a].Order > cfg.Rarities[b].Order
	end)

	local l = math.max(1, luck)
	local chances: { [string]: number } = {}
	local left = 1
	local hasPlain = present.Common or present.Uncommon
	for i, name in bands do
		local rarity = cfg.Rarities[name]
		local p = math.min(left, l ^ rarity.LuckPower / rarity.OneIn)
		if i == #bands and hasPlain then
			-- the least rare band leaves room for the plain heroes
			p = math.min(p, math.max(0, left - cfg.Roll.CommonFloor))
		end
		chances[name] = p
		left -= p
	end
	left = math.max(left, 0)
	if present.Uncommon then
		local share = if present.Common then cfg.Roll.UncommonShare else 1
		chances.Uncommon = left * share
		left -= chances.Uncommon
	end
	if present.Common then
		chances.Common = left
		left = 0
	end
	if left > 0 and #bands > 0 then
		-- a zone of only rare heroes: the remainder is its least rare band's
		chances[bands[#bands]] += left
	end

	if floor ~= nil and cfg.Rarities[floor] then
		local floorOrder = cfg.Rarities[floor].Order
		-- the lowest rarity the zone holds that is at least the floor
		local target: string? = nil
		for name in chances do
			local order = cfg.Rarities[name].Order
			if
				order >= floorOrder
				and (target == nil or order < cfg.Rarities[target :: string].Order)
			then
				target = name
			end
		end
		if target then
			for name, p in chances do
				if cfg.Rarities[name].Order < floorOrder then
					chances[target] += p
					chances[name] = 0
				end
			end
		end
	end
	return chances
end

--- Weight and chance of every hero in a zone at `luck`, optionally with a
--- thrown food id `foodId` and a rarity `floor`.
--- `zoneCharacters` is Lookup.of(cfg).zoneCharacters[zoneId].
function Roll.heroWeights(
	cfg: any,
	zoneCharacters: { any },
	luck: number,
	foodId: string?,
	floor: string?
): { HeroWeight }
	local chances = Roll.rarityChances(cfg, zoneCharacters, luck, floor)
	-- inside a rarity every hero counts once, a craving hero several times
	local sharing: { [string]: number } = {}
	local rows: { HeroWeight } = {}
	for _, character in zoneCharacters do
		local weight = if foodId ~= nil and character.Favourite == foodId
			then cfg.Throw.CravingWeightMult
			else 1
		sharing[character.Rarity] = (sharing[character.Rarity] or 0) + weight
		table.insert(
			rows,
			{ id = character.Id, rarity = character.Rarity, weight = weight, chance = 0 }
		)
	end
	for _, row in rows do
		row.chance = (chances[row.rarity] or 0) * row.weight / sharing[row.rarity]
	end
	return rows
end

--- Pick a row by chance. `r` in [0, 1).
function Roll.pick(rows: { HeroWeight }, r: number): HeroWeight
	local acc = 0
	local last = rows[#rows]
	for _, row in rows do
		acc += row.chance
		if row.chance > 0 then
			last = row
			if r < acc then
				return row
			end
		end
	end
	return last
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

--- "1 in N" of a rarity in this zone at base odds (luck 1, no craving).
function Roll.rarityOneIn(cfg: any, zoneCharacters: { any }, rarity: string): number
	local p = Roll.rarityChances(cfg, zoneCharacters, 1, nil)[rarity] or 0
	return if p > 0 then 1 / p else math.huge
end

--- The score of a catch: base rarity odds x base mutation odds x base size
--- odds. `maps` is Lookup.of(cfg).
function Roll.score(
	cfg: any,
	maps: any,
	zoneCharacters: { any },
	rarity: string,
	mutation: string?,
	size: string?
): number
	local n = Roll.rarityOneIn(cfg, zoneCharacters, rarity)
	if mutation and maps.mutation[mutation] then
		n /= maps.mutation[mutation].Chance
	end
	if size and maps.size[size] then
		n /= maps.size[size].Chance
	end
	return n
end

--- The stamp a score earns ("LUCKY" ... "GODLY"), or nil below the first.
function Roll.stamp(cfg: any, oneInN: number): string?
	local best: string? = nil
	for _, stamp in cfg.Roll.Stamps do
		if oneInN >= stamp.OneIn then
			best = stamp.Name
		end
	end
	return best
end

--- A full catch. `floor`: the lowest rarity this throw can give (Lucky Throw).
function Roll.throw(
	cfg: any,
	maps: any,
	zoneCharacters: { any },
	luck: number,
	foodId: string?,
	rng: () -> number,
	mutationMult: number?,
	floor: string?
): Result
	local rows = Roll.heroWeights(cfg, zoneCharacters, luck, foodId, floor)
	local hero = Roll.pick(rows, rng())
	local mutation, pMutation = Roll.variant(cfg.Mutations, luck, rng(), mutationMult or 1)
	local size, pSize = Roll.variant(cfg.Sizes, luck, rng(), 1)
	return {
		id = hero.id,
		rarity = hero.rarity,
		mutation = mutation,
		size = size,
		pHero = hero.chance,
		pMutation = pMutation,
		pSize = pSize,
		oneInN = Roll.score(cfg, maps, zoneCharacters, hero.rarity, mutation, size),
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

function Roll.rarityOrder(cfg: any, rarity: string): number
	return cfg.Rarities[rarity].Order
end

return Roll
