--!strict
local Support = require("./Support")
local Income = require("../src/shared/Core/Income")
local Progress = require("../src/shared/Core/Progress")

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

	["the slot cost matches the simulator's formula and stops at the cap"] = function()
		local P = C.Plot
		assert(Progress.nextSlotCost(C, P.StartSlots) == P.SlotBaseCost)
		local second = Progress.nextSlotCost(C, P.StartSlots + 1) :: number
		assert(Support.near(second, P.SlotBaseCost * P.SlotCostGrowth, 0.001))
		assert(Progress.nextSlotCost(C, P.MaxSlots) == nil)
	end,

	["gear is bought in order and ends"] = function()
		assert(Progress.nextGearCost(C, 1) == C.Training.Equipment[2].Cost)
		assert(Progress.nextGearCost(C, #C.Training.Equipment) == nil)
	end,

	["double training doubles power per rep"] = function()
		assert(Progress.powerPerRep(C, 2, true) == Progress.powerPerRep(C, 2, false) * 2)
	end,

	["rank thresholds are inclusive"] = function()
		local ranks = C.Training.Ranks
		assert(Progress.rank(C, ranks[2].Power).index == 2, "exactly on the number is the new rank")
		assert(Progress.rank(C, ranks[2].Power - 1).index == 1)
		assert(Progress.rank(C, 1e30).progress == 1)
	end,

	["offline pays nothing for a short absence and stops at the cap"] = function()
		local O = C.Offline
		assert(Progress.offline(C, O.MinSecondsAway - 1, 100) == 0)
		local full = Progress.offline(C, O.CapHours * 3600, 100)
		local over = Progress.offline(C, O.CapHours * 3600 * 10, 100)
		assert(full == over, "time past the cap must not pay")
		assert(full == math.floor(O.CapHours * 3600 * 100 * O.Rate))
	end,

	["rebirth needs both power and yen"] = function()
		local t = C.Rebirth.Tiers[1]
		assert(not Progress.canRebirth(C, 0, t.PowerReq, t.YenCost - 1))
		assert(not Progress.canRebirth(C, 0, t.PowerReq - 1, t.YenCost))
		assert(Progress.canRebirth(C, 0, t.PowerReq, t.YenCost))
		assert(
			not Progress.canRebirth(C, #C.Rebirth.Tiers, 1e300, 1e300),
			"the last tier is the cap"
		)
	end,

	["rebirth resets progress and keeps premium heroes"] = function()
		local premium = C.PremiumCharacters[1]
		local profile = {
			rebirth = 0,
			yen = 5e12,
			power = 9e8,
			foods = { onigiri = true, ramen = true },
			food = "ramen",
			gear = 6,
			slots = 20,
			bonusSlots = 2,
			heroes = { h1 = hero(COMMON.Id, 1), h7 = hero(premium.Id, 19) },
			index = { [COMMON.Id] = { muts = {}, sizes = {} } },
			luckyThrows = 4,
		}
		profile.away = { yen = 5000, seconds = 600 }
		Progress.applyRebirth(C, M, profile)
		assert(profile.away.yen == 0, "unclaimed offline pay must not survive a rebirth")
		assert(profile.rebirth == 1 and profile.yen == 0)
		assert(profile.power == C.Training.StartPower and profile.gear == 1)
		assert(profile.slots == C.Plot.StartSlots + 2, "bonus slots survive")
		assert(profile.food == C.Foods[1].Id and profile.foods.ramen == nil)
		assert(profile.heroes.h1 == nil, "lane heroes are gone")
		assert(profile.heroes.h7 ~= nil and profile.heroes.h7.slot == 1, "premium re-seated")
		assert(
			profile.index[COMMON.Id] ~= nil and profile.luckyThrows == 4,
			"index and throws kept"
		)
	end,
}
