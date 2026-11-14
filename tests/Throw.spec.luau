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

	["the bar mark for an unreachable zone is nil"] = function()
		local T = C.Throw
		assert(Throw.chargeForZone(T, Z, 10, 1, 3) == nil)
		local mark = Throw.chargeForZone(T, Z, Z[2].PowerReq * 2, 1, 2)
		assert(mark ~= nil and math.abs(mark - 0.5) < 1e-9)
		assert(Throw.chargeForZone(T, Z, 1000, 1, 1) == T.MinCharge)
	end,

	["flight time stays inside its limits"] = function()
		local T = C.Throw
		assert(Throw.flightSeconds(T, 1, #Z) == T.FlightSecondsMin)
		assert(Throw.flightSeconds(T, #Z, #Z) == T.FlightSecondsMax)
	end,
}
