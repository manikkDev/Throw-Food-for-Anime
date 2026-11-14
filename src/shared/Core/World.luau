--!strict
-- World - where things are, as plain numbers. Pure.
--
-- One function per "where is X" so the server (validation), the client
-- (rendering) and the blockout builder cannot disagree. Plots sit in a row
-- along X; every plot faces its own lane, which runs along +Z.
--
--   z = PlotBackZ ...... hub side
--       pedestal grid   (heroes face +Z, toward the lane)
--   z = ThrowPadZ ...... throw pad, dojo pad, slot sign
--   z = PlotFrontZ ..... plot edge
--   z = LaneStartZ ..... first zone band begins

local World = {}

--- Centre X of plot `index` (1..count). Plots are centred on x = 0.
function World.plotX(world: any, index: number, count: number): number
	return (index - (count + 1) / 2) * world.PlotPitch
end

--- How many pedestals a plot has room for.
function World.pedestalCount(world: any): number
	return world.PedestalColumns * world.PedestalRows
end

--- Offset of pedestal `slot` from the plot centre: (dx, z). Slot 1 is the
--- middle of the front row (nearest the throw pad) and slots fan outward,
--- then back row by row, so a new player's first heroes stand front and
--- centre instead of in a corner.
function World.pedestalOffset(world: any, slot: number): (number, number)
	local columns, rows = world.PedestalColumns, world.PedestalRows
	local index = math.clamp(slot, 1, columns * rows) - 1
	local row = index // columns -- 0 = front row
	local k = index % columns -- 0 = centre, then alternating left/right
	local step = (k + 1) // 2
	local side = if k % 2 == 1 then -1 else 1
	local dx = step * side * world.PedestalSpacing
	local frontZ = world.PedestalCenterZ + (rows - 1) / 2 * world.PedestalSpacing
	return dx, frontZ - row * world.PedestalSpacing
end

--- World (x, z) of pedestal `slot` on plot `plotIndex`.
function World.pedestal(
	world: any,
	plotIndex: number,
	count: number,
	slot: number
): (number, number)
	local dx, z = World.pedestalOffset(world, slot)
	return World.plotX(world, plotIndex, count) + dx, z
end

--- World (x, z) of the throw pad.
function World.throwPad(world: any, plotIndex: number, count: number): (number, number)
	return World.plotX(world, plotIndex, count), world.ThrowPadZ
end

--- World (x, z) of the dojo pad (training).
function World.dojoPad(world: any, plotIndex: number, count: number): (number, number)
	return World.plotX(world, plotIndex, count) + world.DojoPadX, world.DojoPadZ
end

--- World (x, z) of the slot sign.
function World.slotSign(world: any, plotIndex: number, count: number): (number, number)
	return World.plotX(world, plotIndex, count) + world.SlotSignX, world.SlotSignZ
end

--- World X of a landing: the plot's lane centre plus jitter in [-1, 1].
function World.landingX(world: any, plotIndex: number, count: number, jitter: number): number
	return World.plotX(world, plotIndex, count) + math.clamp(jitter, -1, 1) * world.LandingJitterX
end

--- Total lane length for a zone list.
function World.laneLength(zones: { any }): number
	local total = 0
	for _, zone in zones do
		total += zone.LengthStuds
	end
	return total
end

--- Flat distance between two (x, z) points.
function World.distance(ax: number, az: number, bx: number, bz: number): number
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

return World
