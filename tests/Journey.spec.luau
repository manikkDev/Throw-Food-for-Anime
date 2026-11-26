--!strict
-- A player's first hours, played through the pure rules the way the server
-- services call them: throw, touch the reach, unlock, buy, rebirth, climb
-- back. No service code runs here, but every rule a service leans on does,
-- together, on the real config.
local Support = require("./Support")
local Income = require("../src/shared/Core/Income")
local Luck = require("../src/shared/Core/Luck")
local Progress = require("../src/shared/Core/Progress")
local Roll = require("../src/shared/Core/Roll")
local Schema = require("../src/shared/Core/Schema")
local Throw = require("../src/shared/Core/Throw")

local C = Support.Config
local M = Support.Maps
local Z = C.Zones
local T = C.Throw

local function sources(profile: any, food: any, depth: number): Luck.Sources
	return {
		foodLuck = food.Luck,
		depth = depth,
		perfect = false,
		serverMult = 1,
		friends = 0,
		vip = false,
		luckyAura = false,
		zonesCompleted = 0,
		rebirthTier = profile.rebirth,
		streakBonus = 0,
		luckyThrow = false,
		dry = profile.dry,
	}
end

-- one throw, as ThrowService does it; returns the zone it landed in
local function throw(profile: any, rng: () -> number, charge: number): (number, Roll.Result)
	local food = M.food[profile.food]
	local full = profile.power
	Progress.touch(profile, Throw.reach(Z, full, profile.rebirth))
	local aim = if profile.aim > 0 then profile.aim else nil
	local zone, depth = Throw.landing(T, Z, full, profile.rebirth, aim, charge)
	local luck = Luck.total(C, sources(profile, food, depth))
	local result = Roll.throw(C, M, M.zoneCharacters[Z[zone].Id], luck, food.Id, rng)
	if C.Rarities[result.rarity].Order >= C.Rarities[T.DryStreakResetRarity].Order then
		profile.dry = 0
	else
		profile.dry += 1
	end
	local _, hero = Schema.newHero(profile, result.id, result.mutation, result.size)
	hero.slot = 1
	return zone, result
end

-- training, as TrainingService does it: reps with muscle memory
local function train(profile: any, reps: number)
	for _ = 1, reps do
		local gain = Progress.powerPerRep(C, profile.gear, false, profile.rebirth)
		if Progress.catchingUp(profile.power, profile.powerRecord) then
			profile.power = Progress.addPower(
				C,
				profile.power,
				profile.powerRecord,
				gain * C.Training.MuscleMemory
			)
		else
			profile.power += gain
		end
		Progress.touch(profile, Throw.reach(Z, profile.power, profile.rebirth))
	end
end

return {
	["a new player throws into zone one and everything past it is locked"] = function()
		local profile = Schema.default(C)
		local zone = throw(profile, Support.rng(1), 1)
		assert(zone == 1 and profile.bestZone == 1)
		assert(Progress.lock(C.Training.Equipment[4], profile.bestZone, profile.rebirth) ~= nil)
		assert(Progress.nextSlotZone(C, profile.slots, profile.bonusSlots) == 2)
		assert(Income.player(C, M, profile.heroes, {
			doubleYen = false,
			rebirthTier = 0,
			eventMult = 1,
		}) > 0)
	end,

	["training to the next gate opens the next zone's gear, food and slot"] = function()
		local profile = Schema.default(C)
		train(profile, math.ceil(Z[2].PowerReq / C.Training.Equipment[1].PowerPerRep) + 1)
		assert(profile.bestZone == 2, `best zone is {profile.bestZone}`)
		assert(Progress.lock(C.Training.Equipment[4], profile.bestZone, profile.rebirth) == nil)
		local zone = throw(profile, Support.rng(2), 1)
		assert(zone == 2)
		-- aiming back at zone one works, and is remembered
		profile.aim = 1
		assert(throw(profile, Support.rng(3), 1) == 1)
	end,

	["the first band ends at a sealed gate and the rebirth opens it"] = function()
		local profile = Schema.default(C)
		local first = C.Rebirth.Tiers[1]
		local open = Throw.openZones(Z, 0)
		profile.power = first.PowerReq * 5
		Progress.touch(profile, Throw.reach(Z, profile.power, 0))
		assert(profile.bestZone == open, "Power alone does not pass the seal")
		assert(throw(profile, Support.rng(4), 1) == open)
		assert(Throw.atSeal(Z, profile.power, 0))
		assert(not Progress.canRebirth(C, 0, profile.power, 0), "the fee is needed too")
		profile.yen = first.YenCost
		assert(Progress.canRebirth(C, 0, profile.power, profile.yen))

		local record = profile.power
		local heroes = 0
		for _ in profile.heroes do
			heroes += 1
		end
		Progress.applyRebirth(C, profile)
		profile.aim = 0
		assert(profile.rebirth == 1 and profile.power == C.Training.StartPower)
		local kept = 0
		for _ in profile.heroes do
			kept += 1
		end
		assert(kept == heroes, "the heroes are kept")
		assert(throw(profile, Support.rng(5), 1) == 1, "after a rebirth the throw is short again")

		-- muscle memory: back to the record in a quarter of the reps
		local plain = Progress.powerPerRep(C, profile.gear, false, profile.rebirth)
		local reps = math.ceil((record - profile.power) / (plain * C.Training.MuscleMemory)) + 1
		train(profile, reps)
		assert(profile.power >= record, `only {profile.power} of {record} after {reps} reps`)
		assert(profile.bestZone > open, "the rebirth opened the next zone")
		assert(throw(profile, Support.rng(6), 1) == open + 1)
	end,

	["a dry streak builds luck and an Epic resets it"] = function()
		local profile = Schema.default(C)
		local rng = Support.rng(11)
		local sawReset = false
		local maxDry = 0
		for _ = 1, 600 do
			local before = profile.dry
			local _, result = throw(profile, rng, 1)
			maxDry = math.max(maxDry, profile.dry)
			if C.Rarities[result.rarity].Order >= C.Rarities.Epic.Order then
				assert(profile.dry == 0)
				sawReset = sawReset or before > 0
			end
		end
		assert(sawReset and maxDry > 5, "600 throws never showed a dry streak ending")
	end,

	["the whole lane can be walked: every seal has a rebirth that opens it"] = function()
		local profile = Schema.default(C)
		profile.power = 1e300
		profile.yen = 1e300
		local rng = Support.rng(21)
		for _ = 1, #C.Rebirth.Tiers do
			profile.power = 1e300
			profile.yen = 1e300
			Progress.touch(profile, Throw.reach(Z, profile.power, profile.rebirth))
			assert(Progress.canRebirth(C, profile.rebirth, profile.power, profile.yen))
			Progress.applyRebirth(C, profile)
		end
		profile.power = 1e300
		assert(throw(profile, rng, 1) == #Z, "the last rebirth leaves the lane's end out of reach")
		assert(profile.bestZone == #Z)
		assert(not Progress.canRebirth(C, profile.rebirth, 1e300, 1e300))
	end,
}
