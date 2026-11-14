--!strict
-- Throw - where a throw lands. Pure.
--
-- effective power = Power x food.PowerMult x charge. The landing zone is the
-- FURTHEST zone whose PowerReq the effective power meets, so the charge bar is
-- a zone selector: release early to farm an earlier zone on purpose.

local Throw = {}

--- A charge the server will accept: a real number inside [MinCharge, 1].
function Throw.validCharge(cfgThrow: any, charge: any): boolean
	if type(charge) ~= "number" or charge ~= charge then
		return false
	end
	return charge >= cfgThrow.MinCharge and charge <= 1
end

function Throw.effectivePower(power: number, foodPowerMult: number, charge: number): number
	return power * foodPowerMult * charge
end

--- 1-based index of the furthest zone reachable with `eff`. Zone 1 has
--- PowerReq 0, so there is always an answer.
function Throw.zoneIndex(zones: { any }, eff: number): number
	local index = 1
	for i, zone in zones do
		if eff >= zone.PowerReq then
			index = i
		end
	end
	return index
end

--- How deep into zone `index` the throw lands, 0..1. Between this zone's gate
--- and the next one; in the last zone, between its gate and twice its gate.
function Throw.depth(zones: { any }, index: number, eff: number): number
	local from = zones[index].PowerReq
	local nextZone = zones[index + 1]
	local to = if nextZone then nextZone.PowerReq else math.max(from * 2, 1)
	if to <= from then
		return 0
	end
	return math.clamp((eff - from) / (to - from), 0, 1)
end

--- World Z of the landing point. Lanes start at `world.LaneStartZ` and every
--- zone band is `LengthStuds` long. Depth is kept off the gates by 8%.
function Throw.landingZ(world: any, zones: { any }, index: number, depth: number): number
	local z = world.LaneStartZ
	for i = 1, index - 1 do
		z += zones[i].LengthStuds
	end
	return z + zones[index].LengthStuds * (0.08 + 0.84 * math.clamp(depth, 0, 1))
end

--- Released inside the top `PerfectWindow` of the bar.
function Throw.isPerfect(cfgThrow: any, charge: number): boolean
	return charge >= 1 - cfgThrow.PerfectWindow
end

--- The smallest charge that reaches zone `index`, or nil if full charge cannot.
--- Drives the zone marks on the charge bar.
function Throw.chargeForZone(
	cfgThrow: any,
	zones: { any },
	power: number,
	foodPowerMult: number,
	index: number
): number?
	local full = power * foodPowerMult
	if full <= 0 then
		return nil
	end
	local need = zones[index].PowerReq / full
	if need > 1 then
		return nil
	end
	return math.max(need, cfgThrow.MinCharge)
end

--- Flight time grows with distance but stays inside [Min, Max] so a throw into
--- the last zone is not a ten-second wait.
function Throw.flightSeconds(cfgThrow: any, index: number, zoneCount: number): number
	local t = if zoneCount > 1 then (index - 1) / (zoneCount - 1) else 0
	return cfgThrow.FlightSecondsMin + (cfgThrow.FlightSecondsMax - cfgThrow.FlightSecondsMin) * t
end

return Throw
