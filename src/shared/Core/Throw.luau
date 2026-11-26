--!strict
-- Throw - where a throw lands. Pure.
--
-- full power = the player's Power (food gives luck only, plan 13). It decides
-- the FURTHEST zone a player
-- can reach; a zone whose RebirthReq they have not earned is SEALED, and a
-- throw never passes a sealed gate.
--
-- The player AIMS at any zone they can reach (plan 12, section 9): the meter
-- then only decides how DEEP in that zone the food lands. In the furthest
-- zone the bar reaches as deep as the player's Power does; in an earlier zone
-- the whole zone is in range.
local Throw = {}

--- A charge the server will accept: a real number inside [MinCharge, 1].
function Throw.validCharge(cfgThrow: any, charge: any): boolean
	if type(charge) ~= "number" or charge ~= charge then
		return false
	end
	return charge >= cfgThrow.MinCharge and charge <= 1
end

function Throw.effectivePower(power: number, charge: number): number
	return power * charge
end

--- 1-based index of the furthest zone whose gate `eff` meets, ignoring seals.
--- Zone 1 has PowerReq 0, so there is always an answer.
function Throw.zoneIndex(zones: { any }, eff: number): number
	local index = 1
	for i, zone in zones do
		if eff >= zone.PowerReq then
			index = i
		end
	end
	return index
end

--- The last zone a player of rebirth `tier` may throw into.
function Throw.openZones(zones: { any }, tier: number): number
	local open = 1
	for i, zone in zones do
		if (zone.RebirthReq or 0) <= tier then
			open = i
		end
	end
	return open
end

--- The furthest zone this player can land in: by Power, stopped by the seal.
function Throw.reach(zones: { any }, full: number, tier: number): number
	return math.min(Throw.zoneIndex(zones, full), Throw.openZones(zones, tier))
end

--- True when the player's Power would carry past the sealed gate: the
--- moment to offer the rebirth.
function Throw.atSeal(zones: { any }, full: number, tier: number): boolean
	local open = Throw.openZones(zones, tier)
	return open < #zones and full >= zones[open + 1].PowerReq
end

--- How deep into zone `index` power `eff` lands, 0..1. Between this zone's gate
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

--- The zone a throw lands in and how deep (0..1).
---   `aim`    the zone the player chose, or nil / 0 for the furthest
---   `charge` the meter, MinCharge..1: the share of the reachable depth
function Throw.landing(
	cfgThrow: any,
	zones: { any },
	full: number,
	tier: number,
	aim: number?,
	charge: number
): (number, number)
	local reach = Throw.reach(zones, full, tier)
	local index = reach
	if aim ~= nil and aim >= 1 and aim < reach then
		index = math.floor(aim)
	end
	-- an earlier zone is wholly in range; so is a zone the seal cut the throw short in
	local maxDepth = if index < reach or Throw.zoneIndex(zones, full) > reach
		then 1
		else Throw.depth(zones, index, full)
	local span = 1 - cfgThrow.MinCharge
	local share = if span > 0 then math.clamp((charge - cfgThrow.MinCharge) / span, 0, 1) else 1
	return index, maxDepth * share
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

--- Flight time grows with distance but stays inside [Min, Max] so a throw into
--- the last zone is not a ten-second wait.
function Throw.flightSeconds(cfgThrow: any, index: number, zoneCount: number): number
	local t = if zoneCount > 1 then (index - 1) / (zoneCount - 1) else 0
	return cfgThrow.FlightSecondsMin + (cfgThrow.FlightSecondsMax - cfgThrow.FlightSecondsMin) * t
end

return Throw
