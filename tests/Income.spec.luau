--!strict
local Support = require("./Support")
local Income = require("../src/shared/Core/Income")

local C = Support.Config
local M = Support.Maps

local COMMON = M.zoneCharacters[C.Zones[1].Id][1]
local MODS: Income.Mods = { doubleYen = false, rebirthTier = 0, eventMult = 1 }

local function hero(
	id: string,
	slot: number,
	mut: string?,
	size: string?,
	stars: number?
): Income.Hero
	return { id = id, mut = mut, size = size, stars = stars or 0, slot = slot }
end

return {
	["a plain zone-one common earns the zone's base income"] = function()
		local value = Income.lane(C, M, hero(COMMON.Id, 1))
		assert(value == C.Zones[1].BaseIncome * C.Rarities[COMMON.Rarity].IncomeMult)
	end,

	["mutation, size and stars multiply"] = function()
		local base = Income.lane(C, M, hero(COMMON.Id, 1))
		local full = Income.lane(C, M, hero(COMMON.Id, 1, "Golden", "Big", 2))
		local want = base
			* M.mutation.Golden.IncomeMult
			* M.size.Big.IncomeMult
			* C.Plot.StarIncomeMult ^ 2
		assert(Support.near(full, want, 1e-9))
	end,

	["an unknown hero id earns nothing instead of erroring"] = function()
		assert(Income.lane(C, M, hero("deleted_in_an_update", 1)) == 0)
	end,

	["only heroes on a slot earn"] = function()
		local heroes = { h1 = hero(COMMON.Id, 1), h2 = hero(COMMON.Id, 0) }
		assert(Income.player(C, M, heroes, MODS) == Income.lane(C, M, heroes.h1))
	end,

	["a premium hero follows the best lane hero and is never its own best"] = function()
		local premium = C.PremiumCharacters[1]
		local heroes = { h1 = hero(COMMON.Id, 1), p1 = hero(premium.Id, 2) }
		local best = Income.best(C, M, heroes)
		assert(best == Income.lane(C, M, heroes.h1), "best must ignore premium heroes")
		assert(
			Support.near(Income.hero(C, M, heroes.p1, best), premium.BestIncomeMult * best, 1e-9)
		)
	end,

	["a premium hero bought with an empty plot still earns"] = function()
		local premium = C.PremiumCharacters[1]
		assert(Income.hero(C, M, hero(premium.Id, 1), 0) > 0)
	end,

	["double yen doubles and each rebirth adds its bonus"] = function()
		local heroes = { h1 = hero(COMMON.Id, 1) }
		local base = Income.player(C, M, heroes, MODS)
		local doubled =
			Income.player(C, M, heroes, { doubleYen = true, rebirthTier = 0, eventMult = 1 })
		assert(doubled == base * 2)
		local reborn =
			Income.player(C, M, heroes, { doubleYen = false, rebirthTier = 2, eventMult = 1 })
		assert(Support.near(reborn, base * (1 + 2 * C.Rebirth.Tiers[1].IncomeBonus), 1e-9))
	end,

	["each zone's common out-earns the previous zone's rare"] = function()
		-- the reason to push for the next gate: its worst catch beats most of
		-- what the last zone could give
		for i = 2, #C.Zones do
			local common = C.Zones[i].BaseIncome * C.Rarities.Common.IncomeMult
			local prevRare = C.Zones[i - 1].BaseIncome * C.Rarities.Rare.IncomeMult
			assert(common > prevRare, `zone {i} common does not beat zone {i - 1} rare`)
		end
	end,
}
