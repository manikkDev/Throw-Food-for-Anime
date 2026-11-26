--!strict
local Support = require("./Support")
local Progress = require("../src/shared/Core/Progress")
local Schema = require("../src/shared/Core/Schema")
local Throw = require("../src/shared/Core/Throw")

local C = Support.Config
local Z = C.Zones
local GEAR = C.Training.Equipment

return {
	-- ------------------------------------------------------------ the ladder
	["gates, incomes and gear all climb"] = function()
		for i = 2, #Z do
			assert(Z[i].PowerReq > Z[i - 1].PowerReq, `zone {i} gate does not climb`)
			assert(Z[i].BaseIncome > Z[i - 1].BaseIncome, `zone {i} income does not climb`)
			assert(Z[i].RebirthReq >= Z[i - 1].RebirthReq, `zone {i} opens before zone {i - 1}`)
		end
		for i = 2, #GEAR do
			assert(GEAR[i].PowerPerRep > GEAR[i - 1].PowerPerRep, `gear {i} is not stronger`)
			-- inside a tier each level is dearer; a tier's first level is dearer than the
			-- last tier's first level (it may undercut that tier's level III: a new world's
			-- first upgrade is meant to be an easy buy)
			if GEAR[i].Tier == GEAR[i - 1].Tier then
				assert(GEAR[i].Cost > GEAR[i - 1].Cost, `gear {i} is not dearer`)
			elseif i > 3 then
				assert(GEAR[i].Cost > GEAR[i - 3].Cost, `gear {i} is not dearer than tier before`)
			end
		end
		for i = 2, #C.Foods do
			-- (prices inside a world: Foods.spec; a new world's snack may undercut the last signature)
			if i > 3 then
				assert(C.Foods[i].Cost > C.Foods[i - 3].Cost, `food {i} is not dearer`)
			end
			assert(C.Foods[i].Zone >= C.Foods[i - 1].Zone)
		end
	end,

	["every zone sells the gear that trains to the next gate"] = function()
		local seen: { [number]: boolean } = {}
		for _, gear in GEAR do
			if not gear.RebirthReq then
				seen[gear.Zone] = true
			end
		end
		for i in Z do
			assert(seen[i], `no gear is sold in zone {i}`)
		end
	end,

	["each rebirth opens the zones right after the seal"] = function()
		for _, tier in C.Rebirth.Tiers do
			for _, zone in tier.Unseals do
				assert(
					Z[zone].RebirthReq == tier.Tier,
					`zone {zone} is not opened by rebirth {tier.Tier}`
				)
			end
			if #tier.Unseals > 0 then
				-- the fee asks for the Power of the first sealed gate
				assert(tier.PowerReq == Z[tier.Unseals[1]].PowerReq)
			end
		end
		assert(Throw.openZones(Z, #C.Rebirth.Tiers) == #Z, "the last rebirth leaves a zone sealed")
	end,

	-- -------------------------------------------------------------- training
	["double training doubles power per rep"] = function()
		assert(Progress.powerPerRep(C, 2, true) == Progress.powerPerRep(C, 2, false) * 2)
	end,

	["each rebirth adds its training bonus, and muscle memory multiplies"] = function()
		local base = Progress.powerPerRep(C, 3, false)
		local bonus = C.Rebirth.Tiers[1].TrainBonus
		assert(Support.near(Progress.powerPerRep(C, 3, false, 4), base * (1 + 4 * bonus), 1e-9))
		assert(
			Support.near(
				Progress.powerPerRep(C, 3, false, 0, true),
				base * C.Training.MuscleMemory,
				1e-9
			)
		)
	end,

	["muscle memory stops at the record"] = function()
		local mm = C.Training.MuscleMemory
		assert(Progress.catchingUp(10, 500))
		assert(not Progress.catchingUp(500, 500))
		-- well below the record: the whole boosted gain counts
		assert(Progress.addPower(C, 100, 1000, 40) == 140)
		-- at or above it: nothing is boosted, the caller passes the plain gain
		assert(Progress.addPower(C, 1000, 1000, 10) == 1010)
		-- crossing it: only the part below the record was boosted
		local crossed = Progress.addPower(C, 990, 1000, 40)
		assert(Support.near(crossed, 1000 + 30 / mm, 1e-9), `crossing gave {crossed}`)
	end,

	["rank thresholds are inclusive"] = function()
		local ranks = C.Training.Ranks
		assert(Progress.rank(C, ranks[2].Power).index == 2, "exactly on the number is the new rank")
		assert(Progress.rank(C, ranks[2].Power - 1).index == 1)
		assert(Progress.rank(C, 1e300).progress == 1)
	end,

	-- --------------------------------------------------------------- unlocks
	["gear, food and slots unlock by the furthest zone reached"] = function()
		-- three levels per tier (plan 13): the fourth row is the first of zone two
		assert(GEAR[3].Zone == 1 and GEAR[4].Zone == 2)
		assert(Progress.lock(GEAR[3], 1, 0) == nil, "a tier's levels open with its zone")
		assert(Progress.lock(GEAR[4], 1, 0) ~= nil, "zone-two gear is locked in zone one")
		assert((Progress.lock(GEAR[4], 1, 0) :: any).zone == 2)
		assert(Progress.lock(GEAR[4], 2, 0) == nil)
		assert(Progress.lock(C.Foods[1], 1, 0) == nil, "the starter food is never locked")
		local last = C.Foods[#C.Foods]
		assert(Progress.lock(last, last.Zone - 1, 99) ~= nil)
		assert(Progress.lock(last, last.Zone, 0) == nil)
	end,

	["endgame gear waits for its rebirth"] = function()
		local endgame = GEAR[#GEAR]
		assert(endgame.RebirthReq ~= nil, "the last gear is endgame gear")
		local lock = Progress.lock(endgame, #Z, endgame.RebirthReq - 1)
		assert(lock ~= nil and lock.rebirth == endgame.RebirthReq)
		assert(Progress.lock(endgame, #Z, endgame.RebirthReq) == nil)
	end,

	["slot prices come from the table and a pass's bonus slots do not move them"] = function()
		local P = C.Plot
		assert(#P.SlotCosts == P.MaxSlots - P.StartSlots, "one price per slot that can be bought")
		assert(Progress.nextSlotCost(C, P.StartSlots) == P.SlotCosts[1])
		assert(Progress.nextSlotCost(C, P.StartSlots + 1) == P.SlotCosts[2])
		assert(Progress.nextSlotCost(C, P.MaxSlots) == nil)
		local bonus = P.VipBonusSlots
		assert(Progress.nextSlotCost(C, P.StartSlots + bonus, bonus) == P.SlotCosts[1])
		assert(Progress.nextSlotCost(C, P.MaxSlots + bonus, bonus) == nil)
		assert(Progress.nextSlotZone(C, P.StartSlots) == P.SlotZones[1])
	end,

	["gear is bought in order and ends"] = function()
		assert(Progress.nextGearCost(C, 1) == GEAR[2].Cost)
		assert(Progress.nextGearCost(C, #GEAR) == nil)
	end,

	-- --------------------------------------------------------------- rebirth
	["rebirth needs the throw to reach the gate, and the fee"] = function()
		local t = C.Rebirth.Tiers[1]
		assert(not Progress.canRebirth(C, 0, t.PowerReq, t.YenCost - 1))
		assert(not Progress.canRebirth(C, 0, t.PowerReq - 1, t.YenCost))
		assert(Progress.canRebirth(C, 0, t.PowerReq, t.YenCost))
		assert(
			not Progress.canRebirth(C, #C.Rebirth.Tiers, 1e300, 1e300),
			"the last tier is the cap"
		)
	end,

	["rebirth resets Power and Yen and keeps everything else"] = function()
		local profile = Schema.default(C)
		profile.yen = 5e12
		profile.power = 9e8
		profile.powerRecord = 9e8
		profile.bestZone = 3
		profile.foods[C.Foods[3].Id] = true
		profile.food = C.Foods[3].Id
		profile.gear = 3
		profile.slots = 12
		profile.heroes = { h1 = { id = "x", stars = 0, slot = 1 } }
		profile.index = { x = { muts = {}, sizes = {} } }
		profile.luckyThrows = 4
		profile.away = { yen = 5000, seconds = 600 }
		Progress.applyRebirth(C, profile)
		assert(profile.rebirth == 1 and profile.yen == 0)
		assert(profile.away.yen == 0, "unclaimed offline pay must not survive a rebirth")
		assert(profile.power == C.Training.StartPower)
		assert(profile.powerRecord == 9e8, "the record is what muscle memory climbs back to")
		assert(
			profile.gear == 3
				and profile.food == C.Foods[3].Id
				and profile.foods[C.Foods[3].Id] == true
		)
		assert(profile.slots == 12 and profile.heroes.h1 ~= nil and profile.index.x ~= nil)
		assert(profile.bestZone == 3, "unlocks are kept")
		assert(profile.luckyThrows == 4 + C.Rebirth.Tiers[1].LuckyThrows)
	end,

	["offline pays nothing for a short absence and stops at the cap"] = function()
		local O = C.Offline
		assert(Progress.offline(C, O.MinSecondsAway - 1, 100) == 0)
		local full = Progress.offline(C, O.CapHours * 3600, 100)
		local over = Progress.offline(C, O.CapHours * 3600 * 10, 100)
		assert(full == over, "time past the cap must not pay")
		assert(full == math.floor(O.CapHours * 3600 * 100 * O.Rate))
	end,

	-- --------------------------------------------------------------- profile
	["an old save is raised to what it already shows"] = function()
		local old: any = Schema.default(C)
		old.v = 1
		old.powerRecord = nil
		old.bestZone = nil
		old.dry = nil
		old.aim = nil
		old.power = Z[3].PowerReq
		old.gear = 999
		local upgraded = Schema.upgrade(old, C)
		assert(upgraded.v == Schema.VERSION)
		assert(upgraded.powerRecord == Z[3].PowerReq, "the record is at least the Power held")
		assert(upgraded.bestZone == 3, "zone three was reached by Power")
		assert(upgraded.dry == 0 and upgraded.aim == 0)
		assert(upgraded.gear == #GEAR, "gear past the table is clamped")
	end,

	["a save cannot claim a sealed zone by Power alone"] = function()
		local data: any = Schema.default(C)
		data.power = Z[#Z].PowerReq
		data.rebirth = 0
		local upgraded = Schema.upgrade(data, C)
		assert(upgraded.bestZone == Throw.openZones(Z, 0))
	end,
}
