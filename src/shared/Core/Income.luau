--!strict
-- Income - what a hero earns, and what the player earns. Pure.
--
--   lane hero    = Zone.BaseIncome x Rarity x Mutation x Size x StarMult^stars
--   premium hero = BestIncomeMult x (best lane-hero income the player owns)
--   player       = sum(heroes on a slot) x DoubleYen x rebirth x event
--
-- Premium heroes follow the player's best lane hero, so a purchase never goes
-- stale; a premium hero is never its own "best" (that would be a feedback loop).

local Income = {}

export type Hero = { id: string, mut: string?, size: string?, stars: number, slot: number }

export type Mods = { doubleYen: boolean, rebirthTier: number, eventMult: number }

--- Income of one LANE hero, or 0 if the id is not a lane hero.
--- `maps` is Lookup.of(cfg).
function Income.lane(cfg: any, maps: any, hero: Hero): number
	local character = maps.character[hero.id]
	if not character then
		return 0
	end
	local zone = maps.zone[character.Zone]
	local value = zone.BaseIncome * cfg.Rarities[character.Rarity].IncomeMult
	if hero.mut then
		local mutation = maps.mutation[hero.mut]
		if mutation then
			value *= mutation.IncomeMult
		end
	end
	if hero.size then
		local size = maps.size[hero.size]
		if size then
			value *= size.IncomeMult
		end
	end
	return value * cfg.Plot.StarIncomeMult ^ math.clamp(hero.stars or 0, 0, cfg.Plot.MaxStars)
end

--- The highest lane-hero income among everything the player owns (plot and
--- bench). 0 with no lane heroes.
function Income.best(cfg: any, maps: any, heroes: { [string]: Hero }): number
	local best = 0
	for _, hero in heroes do
		local value = Income.lane(cfg, maps, hero)
		if value > best then
			best = value
		end
	end
	return best
end

--- Income of any hero. Pass `best` (Income.best) so a whole squad is costed
--- with one scan.
function Income.hero(cfg: any, maps: any, hero: Hero, best: number): number
	local premium = maps.premium[hero.id]
	if premium then
		-- a brand-new player with no lane hero still gets something from a purchase
		local floor = cfg.Zones[1].BaseIncome
		return premium.BestIncomeMult
			* math.max(best, floor)
			* cfg.Plot.StarIncomeMult ^ math.clamp(hero.stars or 0, 0, cfg.Plot.MaxStars)
	end
	return Income.lane(cfg, maps, hero)
end

--- Multiplier applied to the whole plot.
function Income.multiplier(cfg: any, mods: Mods): number
	local perTier = if cfg.Rebirth.Tiers[1] then cfg.Rebirth.Tiers[1].IncomeBonus else 0
	return (if mods.doubleYen then 2 else 1)
		* (1 + math.max(0, mods.rebirthTier) * perTier)
		* math.max(0, mods.eventMult)
end

--- Yen per second for the player: only heroes standing on a slot earn.
function Income.player(cfg: any, maps: any, heroes: { [string]: Hero }, mods: Mods): number
	local best = Income.best(cfg, maps, heroes)
	local sum = 0
	for _, hero in heroes do
		if hero.slot > 0 then
			sum += Income.hero(cfg, maps, hero, best)
		end
	end
	return sum * Income.multiplier(cfg, mods)
end

--- What selling a hero pays.
function Income.sellValue(cfg: any, heroIncome: number): number
	return math.floor(heroIncome * cfg.Plot.SellSeconds)
end

return Income
