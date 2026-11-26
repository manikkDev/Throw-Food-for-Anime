--!strict
local Support = require("./Support")
local Luck = require("../src/shared/Core/Luck")

local C = Support.Config

local function sources(over: { [string]: any }?): Luck.Sources
	local s: any = {
		foodLuck = 1,
		depth = 0,
		perfect = false,
		serverMult = 1,
		friends = 0,
		vip = false,
		luckyAura = false,
		zonesCompleted = 0,
		rebirthTier = 0,
		streakBonus = 0,
		luckyThrow = false,
		dry = 0,
	}
	for key, value in over or {} do
		s[key] = value
	end
	return s
end

local function auraLuck(): number
	for _, pass in C.Monetization.Passes do
		if pass.Key == "LuckyAura" then
			return pass.Luck
		end
	end
	error("no LuckyAura pass")
end

return {
	["a new player's luck is exactly one"] = function()
		assert(Luck.total(C, sources()) == 1)
		assert(#Luck.breakdown(C, sources()) == 0, "a line worth nothing is not shown")
	end,

	["the free bonuses are added together, not multiplied"] = function()
		local L = C.Luck
		local s = sources({ rebirthTier = 4, zonesCompleted = 5, friends = 2, streakBonus = 0.1 })
		local added = 4 * C.Rebirth.Tiers[1].LuckBonus
			+ 5 * L.IndexZoneBonus
			+ 2 * L.FriendBonusEach
			+ 0.1
		assert(Support.near(Luck.total(C, s), 1 + added, 1e-9))
		for _, line in Luck.breakdown(C, s) do
			assert(line.add ~= nil, `{line.label} must be in the added group`)
		end
	end,

	["food, depth, a perfect and the passes each multiply"] = function()
		local T = C.Throw
		local s = sources({ foodLuck = 2, depth = 1, perfect = true, vip = true, luckyAura = true })
		local want = 2
			* (1 + T.DepthLuckBonus)
			* (1 + T.PerfectLuckBonus)
			* (1 + C.Luck.VipBonus)
			* auraLuck()
		assert(Support.near(Luck.total(C, s), want, 1e-9))
	end,

	["the group multiplies with the rest once"] = function()
		local s = sources({ foodLuck = 3, rebirthTier = 5, luckyAura = true })
		local want = 3 * (1 + 5 * C.Rebirth.Tiers[1].LuckBonus) * auraLuck()
		assert(Support.near(Luck.total(C, s), want, 1e-9))
	end,

	["friends and the dry streak stop at their caps"] = function()
		local L, T = C.Luck, C.Throw
		assert(Support.near(Luck.total(C, sources({ friends = 99 })), 1 + L.FriendBonusMax, 1e-9))
		assert(Support.near(Luck.total(C, sources({ dry = 100000 })), 1 + T.DryStreakMax, 1e-9))
		assert(Luck.dryBonus(C, 0) == 0)
		assert(Support.near(Luck.dryBonus(C, 10), 10 * T.DryStreakPerThrow, 1e-9))
	end,

	["a free endgame player holds about twenty luck"] = function()
		-- the number the odds and the Common floor were designed against
		local best = C.Foods[#C.Foods]
		local s = sources({
			foodLuck = best.Luck,
			depth = 1,
			perfect = true,
			friends = 3,
			zonesCompleted = #C.Zones,
			rebirthTier = #C.Rebirth.Tiers,
			streakBonus = C.Luck.DailyStreakBonusMax,
		})
		local total = Luck.total(C, s)
		assert(total > 15 and total < 30, `free endgame luck is {total}`)
	end,

	["luck is capped"] = function()
		local s = sources({
			foodLuck = 5.5,
			depth = 1,
			perfect = true,
			serverMult = 8,
			friends = 3,
			vip = true,
			luckyAura = true,
			zonesCompleted = #C.Zones,
			rebirthTier = #C.Rebirth.Tiers,
			streakBonus = 0.1,
			luckyThrow = true,
			dry = 50,
		})
		assert(Luck.total(C, s) == C.Luck.Max, "the full paid stack must hit the cap")
	end,

	["the streak bonus grows to its cap on day seven"] = function()
		assert(Luck.streakBonus(C, 0) == 0)
		assert(Support.near(Luck.streakBonus(C, 7), C.Luck.DailyStreakBonusMax, 1e-9))
		assert(Support.near(Luck.streakBonus(C, 30), C.Luck.DailyStreakBonusMax, 1e-9))
	end,
}
