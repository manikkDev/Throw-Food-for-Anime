--!strict
local Support = require("./Support")
local Throw = require("../src/shared/Core/Throw")

local C = Support.Config
local Z = C.Zones

return {
	["a throw exactly at a gate lands in that zone"] = function()
		-- the boundary a player trains toward: reaching the number must count
		assert(Throw.zoneIndex(Z, Z[2].PowerReq) == 2)
		assert(Throw.zoneIndex(Z, Z[2].PowerReq - 0.001) == 1)
	end,

	["zero power still lands in the first zone"] = function()
		assert(Throw.zoneIndex(Z, 0) == 1)
	end,

	["huge power lands in the last zone, not past it"] = function()
		assert(Throw.zoneIndex(Z, 1e30) == #Z)
	end,

	["charge outside the bar is refused"] = function()
		local T = C.Throw
		assert(not Throw.validCharge(T, T.MinCharge - 0.01))
		assert(not Throw.validCharge(T, 1.01))
		assert(not Throw.validCharge(T, 0 / 0), "nan must be refused")
		assert(not Throw.validCharge(T, "1"), "a string must be refused")
		assert(Throw.validCharge(T, 1))
		assert(Throw.validCharge(T, T.MinCharge))
	end,

	["depth runs from 0 at the gate to 1 at the next gate"] = function()
		assert(Throw.depth(Z, 2, Z[2].PowerReq) == 0)
		assert(Throw.depth(Z, 2, Z[3].PowerReq) == 1)
		assert(Throw.depth(Z, 2, 1e30) == 1, "depth must clamp")
		local mid = (Z[2].PowerReq + Z[3].PowerReq) / 2
		assert(math.abs(Throw.depth(Z, 2, mid) - 0.5) < 1e-9)
	end,

	["the last zone still has depth to train into"] = function()
		local last = #Z
		assert(Throw.depth(Z, last, Z[last].PowerReq) == 0)
		assert(Throw.depth(Z, last, Z[last].PowerReq * 2) == 1)
	end,

	["landing Z stays inside its zone band"] = function()
		local world = { LaneStartZ = 40 }
		local from = 40
		for i, zone in Z do
			local lo = Throw.landingZ(world, Z, i, 0)
			local hi = Throw.landingZ(world, Z, i, 1)
			assert(lo > from and hi < from + zone.LengthStuds, `zone {i} landing leaves its band`)
			from += zone.LengthStuds
		end
	end,

	["perfect is the top of the bar only"] = function()
		local T = C.Throw
		assert(Throw.isPerfect(T, 1))
		assert(Throw.isPerfect(T, 1 - T.PerfectWindow))
		assert(not Throw.isPerfect(T, 1 - T.PerfectWindow - 0.01))
	end,

	["a new player can throw into the first band only"] = function()
		local open = Throw.openZones(Z, 0)
		assert(open >= 1 and open < #Z, "the first band is part of the lane")
		assert(Z[open + 1].RebirthReq == 1, "the zone after the first band needs rebirth one")
		assert(Throw.reach(Z, 1e300, 0) == open, "no Power throws past a sealed gate")
		assert(Throw.reach(Z, 0, 0) == 1)
	end,

	["each rebirth opens more of the lane, the last one all of it"] = function()
		local before = Throw.openZones(Z, 0)
		for tier = 1, #C.Rebirth.Tiers do
			local open = Throw.openZones(Z, tier)
			assert(open >= before, `rebirth {tier} closed a zone`)
			before = open
		end
		assert(before == #Z)
	end,

	["the seal is reached when Power meets the sealed gate"] = function()
		local open = Throw.openZones(Z, 0)
		local gate = Z[open + 1].PowerReq
		assert(not Throw.atSeal(Z, gate - 1, 0))
		assert(Throw.atSeal(Z, gate, 0))
		assert(not Throw.atSeal(Z, 1e300, #C.Rebirth.Tiers), "an open lane has no seal")
	end,

	["an aim lands in the chosen zone, never further than the reach"] = function()
		local T = C.Throw
		local full = Z[3].PowerReq * 2
		local zone, depth = Throw.landing(T, Z, full, 0, nil, 1)
		assert(zone == 3, "no aim = the furthest zone")
		assert(
			depth > 0 and depth < 1,
			"the furthest zone is only in range as deep as the Power goes"
		)
		zone, depth = Throw.landing(T, Z, full, 0, 1, 1)
		assert(zone == 1 and depth == 1, "an earlier zone is wholly in range")
		zone = Throw.landing(T, Z, full, 0, 99, 1)
		assert(zone == 3, "an aim past the reach is the reach")
		zone = Throw.landing(T, Z, full, 0, 0, 1)
		assert(zone == 3, "aim 0 means the furthest")
	end,

	["the meter decides how deep"] = function()
		local T = C.Throw
		local full = Z[3].PowerReq
		local _, shallow = Throw.landing(T, Z, full * 100, 0, 2, T.MinCharge)
		local _, deep = Throw.landing(T, Z, full * 100, 0, 2, 1)
		assert(shallow == 0 and deep == 1)
		local _, mid = Throw.landing(T, Z, full * 100, 0, 2, (T.MinCharge + 1) / 2)
		assert(math.abs(mid - 0.5) < 1e-9)
	end,

	["Power past a sealed gate fills the last open zone"] = function()
		local T = C.Throw
		local open = Throw.openZones(Z, 0)
		local zone, depth = Throw.landing(T, Z, 1e300, 0, nil, 1)
		assert(zone == open and depth == 1)
	end,

	["flight time stays inside its limits"] = function()
		local T = C.Throw
		assert(Throw.flightSeconds(T, 1, #Z) == T.FlightSecondsMin)
		assert(Throw.flightSeconds(T, #Z, #Z) == T.FlightSecondsMax)
	end,
}
