--!strict
-- World - where things are, as plain numbers. Pure.
--
-- One function per "where is X" so the server (validation), the client
-- (rendering) and the blockout builder cannot disagree. Plots sit in a row
-- along X; ONE lane, centred on x = 0, runs along +Z (since 2026-11-21). Every
-- player throws down a track in it (LanePitch apart; two bases share each outer track, each on its
-- own half, since 2026-11-22) from a throw spot of their own on the stage at
-- the lane mouth: stepping on the pad in front of the base takes them there.
--
--   z = PlotBackZ ...... hub side
--       pedestal grid   (back half; heroes face +Z, toward the lane)
--   z = PlotFrontZ ..... the deck's edge: an even border all round the pedestals
--       front yard      (spawn and slot sign, then one training court each side of the walk)
--   z = ThrowPadZ ...... the base's own pad: the way to the throw stage
--   z = StageZ ......... the throw stage: a ledge at the end of the forecourt
--   z = LaneStartZ ..... the ledge's edge; the lane begins BELOW it, at y = LaneY
--                        (the hub stands at GroundY: players throw down into the lane)

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
	-- rows can stand further apart than columns: 7 x 6 pedestals make a square grid (2026-11-22)
	local spacingZ = world.PedestalSpacingZ or world.PedestalSpacing
	local frontZ = world.PedestalCenterZ + (rows - 1) / 2 * spacingZ
	return dx, frontZ - row * spacingZ
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

--- World (x, z) of the throw pad: in front of the player's own base. Stepping
--- on it takes the player to their throw spot.
function World.throwPad(world: any, plotIndex: number, count: number): (number, number)
	return World.plotX(world, plotIndex, count), world.ThrowPadZ
end

--- Centre X of the track plot `plotIndex` throws down. Since 2026-11-22 the lane has fewer tracks
--- than there are bases (config PlotTrack: bases 1-2 share the left track, 4-5 the right);
--- without PlotTrack every base has its own track.
function World.trackX(world: any, plotIndex: number, count: number): number
	local track, tracks = plotIndex, count
	if world.PlotTrack then
		track, tracks = world.PlotTrack[plotIndex], world.TrackCount
	end
	return (track - (tracks + 1) / 2) * world.LanePitch
end

--- Centre X of the player's own part of the lane: its track, or its half of a shared track.
function World.laneX(world: any, plotIndex: number, count: number): number
	local side = if world.PlotTrackSide then world.PlotTrackSide[plotIndex] else 0
	return World.trackX(world, plotIndex, count) + side * (world.TrackSideOffset or 0)
end

--- World (x, z) of the player's spot on the throw stage, at the head of their track:
--- where they are held while they throw.
function World.throwSpot(world: any, plotIndex: number, count: number): (number, number)
	return World.laneX(world, plotIndex, count), world.StageZ
end

--- World (x, z) of the slot sign.
function World.slotSign(world: any, plotIndex: number, count: number): (number, number)
	return World.plotX(world, plotIndex, count) + world.SlotSignX, world.SlotSignZ
end

--- Training station `i` (config Training.Stations): the target's world (x, z) and the point the
--- trainee is snapped to, (standX, standZ). The trainee faces -Z, toward the target.
function World.station(
	world: any,
	training: any,
	plotIndex: number,
	count: number,
	i: number
): (number, number, number, number)
	local row = training.Stations[i]
	local x = World.plotX(world, plotIndex, count) + row.X
	return x, row.Z, x, row.Z + row.Stand
end

--- A training court: side -1 (left, -X) or 1 (right): centre (x, z) and size (width, depth).
function World.court(
	world: any,
	plotIndex: number,
	count: number,
	side: number
): (number, number, number, number)
	return World.plotX(world, plotIndex, count) + side * world.CourtX,
		world.CourtZ,
		world.CourtWidth,
		world.CourtDepth
end

--- World X of a landing: the centre of the player's track plus jitter in [-1, 1].
function World.landingX(world: any, plotIndex: number, count: number, jitter: number): number
	return World.laneX(world, plotIndex, count) + math.clamp(jitter, -1, 1) * world.LandingJitterX
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
