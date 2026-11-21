--!strict
local Support = require("./Support")
local World = require("../src/shared/Core/World")
local Session = require("../src/shared/Core/Session")

local C = Support.Config
local W = C.World
local COUNT = C.Server.PlotCount

return {
	["plots are centred on x = 0 and one pitch apart"] = function()
		local first = World.plotX(W, 1, COUNT)
		local last = World.plotX(W, COUNT, COUNT)
		assert(math.abs(first + last) < 1e-9, "the plot row is not centred")
		assert(World.plotX(W, 2, COUNT) - first == W.PlotPitch)
	end,

	["there is a pedestal for every slot a player can own"] = function()
		local most = C.Plot.MaxSlots + C.Plot.VipBonusSlots
		assert(World.pedestalCount(W) >= most, `only {World.pedestalCount(W)} pedestals for {most}`)
	end,

	["slot one is front and centre"] = function()
		local dx, z = World.pedestalOffset(W, 1)
		assert(dx == 0, "slot 1 is not on the plot's centre line")
		for slot = 2, World.pedestalCount(W) do
			local _, otherZ = World.pedestalOffset(W, slot)
			assert(otherZ <= z, `slot {slot} is in front of slot 1`)
		end
	end,

	["no two pedestals share a spot and all sit inside the plot"] = function()
		local seen = {}
		for slot = 1, World.pedestalCount(W) do
			local dx, z = World.pedestalOffset(W, slot)
			local key = `{dx}|{z}`
			assert(not seen[key], `slot {slot} overlaps slot {seen[key]}`)
			seen[key] = slot
			assert(math.abs(dx) <= W.PlotWidth / 2 - 2, `slot {slot} is outside the plot width`)
			assert(
				z > W.PlotBackZ + 2 and z < W.ThrowPadZ - W.ThrowPadRadius,
				`slot {slot} z = {z}`
			)
		end
	end,

	["the slot sign stands by the walkway out to the throw stage, off the walkway itself"] = function()
		local x0 = World.plotX(W, 1, COUNT)
		local signX, signZ = World.slotSign(W, 1, COUNT)
		local _, padZ = World.throwPad(W, 1, COUNT)
		assert(padZ > W.PlotFrontZ, "the throw stage is not in front of the plot")
		assert(
			signZ > W.PlotFrontZ and signZ < padZ - W.ThrowPadRadius,
			"the sign is not on the forecourt"
		)
		assert(
			math.abs(signX - x0) > 8 and math.abs(signX - x0) < W.PlotWidth / 2,
			"the sign blocks the walkway"
		)
	end,

	["pedestals fill the base and leave an entrance court behind the front gate"] = function()
		-- bases hold heroes only (2026-11-21): the grid runs from the back gate to an entrance
		-- court 12 studs deep, where the player spawns
		for slot = 1, World.pedestalCount(W) do
			local _, z = World.pedestalOffset(W, slot)
			assert(z + 2.5 <= W.PlotFrontZ - 12, `slot {slot} (z = {z}) stands in the entrance court`)
			assert(z - 2.5 >= W.PlotBackZ + 8, `slot {slot} (z = {z}) crowds the gate`)
		end
	end,

	["training stations: inside their court on the forecourt lawn, mirrored, clear of the walkway"] = function()
		local x0 = World.plotX(W, 1, COUNT)
		local stations = C.Training.Stations
		assert(#stations % 2 == 0, "stations come in mirrored pairs")
		for i, row in stations do
			local x, z, sx, sz = World.station(W, C.Training, 1, COUNT, i)
			local cx, cz, cw, cd = World.court(W, 1, COUNT, row.Side)
			assert(
				math.abs(x - cx) <= cw / 2 - 2 and math.abs(sx - cx) <= cw / 2 - 2,
				`{row.Id} pokes out of its court`
			)
			assert(z - cz >= -cd / 2 and sz <= cz + cd / 2, `{row.Id} pokes out of its court (z)`)
			-- the courts stand on the lawn in front of the base: clear of the walkway (16 wide), short
			-- of the neighbour's court, between the base's front edge and the throw stage
			assert(math.abs(cx - x0) - cw / 2 >= 8 + 2, "a court covers the walkway")
			assert(math.abs(cx - x0) + cw / 2 <= W.PlotPitch / 2 - 4, "a court reaches the neighbour's lawn")
			assert(cz - cd / 2 >= W.PlotFrontZ + 2, "a court reaches into the base")
			assert(cz + cd / 2 <= W.ThrowPadZ - W.ThrowPadRadius, "a court reaches the throw stage")
			-- its mirror twin
			local twin = false
			for _, other in stations do
				if
					other.Side == -row.Side
					and math.abs(other.X + row.X) < 0.01
					and other.Z == row.Z
				then
					twin = true
				end
			end
			assert(twin, `{row.Id} has no mirrored twin`)
			for j, other in stations do
				if j ~= i then
					local ox = World.station(W, C.Training, 1, COUNT, j)
					assert(
						math.abs(ox - x) >= 2 * W.StationRadius + 4,
						`{row.Id} and {other.Id} are too close`
					)
				end
			end
		end
		local signX, signZ = World.slotSign(W, 1, COUNT)
		for _, side in { -1, 1 } do
			local cx, cz, cw, cd = World.court(W, 1, COUNT, side)
			assert(
				not (math.abs(signX - cx) < cw / 2 and math.abs(signZ - cz) < cd / 2),
				"the slot sign is in a court"
			)
		end
	end,

	["neighbouring bases have a garden gap between them"] = function()
		assert(
			W.PlotPitch - W.PlotWidth >= 20,
			`only {W.PlotPitch - W.PlotWidth} studs between bases`
		)
	end,

	["a landing stays inside its own track, and inside the lane"] = function()
		for plot = 1, COUNT do
			for _, jitter in { -1, 0, 1, 5 } do
				local x = World.landingX(W, plot, COUNT, jitter)
				local off = math.abs(x - World.laneX(W, plot, COUNT))
				assert(off < W.LanePitch / 2, `plot {plot} landing leaves its track`)
				assert(math.abs(x) <= W.LaneWidth / 2 - 10, `plot {plot} landing is at the lane wall`)
			end
		end
	end,

	["one lane: the tracks fit side by side, centred, narrower than the row of bases"] = function()
		assert(COUNT * W.LanePitch <= W.LaneWidth, "the tracks are wider than the lane")
		assert(World.laneX(W, 1, COUNT) == -World.laneX(W, COUNT, COUNT), "the lane is off centre")
		assert(W.LaneWidth < COUNT * W.PlotPitch, "the lane is as wide as the row of bases")
	end,

	["the lane lies below the hub: players throw down into it from a ledge"] = function()
		assert(W.LaneY <= W.GroundY - 12, `the lane is only {W.GroundY - W.LaneY} studs below the hub`)
		assert(W.LaneStartZ - W.ThrowPadZ >= 60, "the lane starts right in front of the bases")
		assert(W.LaneStartZ - W.StageZ <= 16, "the throw stage is far from the ledge's edge")
	end,

	["everyone throws from the middle: a spot on the stage at the head of their own track"] = function()
		for plot = 1, COUNT do
			local x, z = World.throwSpot(W, plot, COUNT)
			local _, padZ = World.throwPad(W, plot, COUNT)
			assert(x == World.laneX(W, plot, COUNT), `plot {plot} throws from beside its track`)
			assert(z > padZ and z < W.LaneStartZ, `plot {plot} spot (z = {z}) is not at the lane mouth`)
			if plot > 1 then
				local before = World.throwSpot(W, plot - 1, COUNT)
				assert(x - before >= 2 * W.ThrowPadRadius, "two throwers would stand in each other")
			end
		end
	end,

	["a free or own lock can be taken, a live foreign one cannot"] = function()
		assert(Session.canAcquire(nil, "a", 1000))
		assert(Session.canAcquire({ job = "a", t = 1000 }, "a", 1000))
		assert(not Session.canAcquire({ job = "b", t = 1000 }, "a", 1000 + Session.TIMEOUT))
	end,

	["a dead server's lock expires"] = function()
		assert(Session.canAcquire({ job = "b", t = 1000 }, "a", 1001 + Session.TIMEOUT))
	end,

	["a missing lock is not ours to save under"] = function()
		-- another server took the profile and released it: writing now would
		-- overwrite whatever that server saved
		assert(not Session.owns(nil, "a"))
		assert(not Session.owns({ job = "b", t = 1 }, "a"))
		assert(Session.owns({ job = "a", t = 1 }, "a"))
	end,

	["the lock timeout outlasts several autosaves"] = function()
		assert(
			Session.TIMEOUT >= C.Server.AutosaveSeconds * 3,
			"one slow autosave must not lose the lock"
		)
	end,

	["a lock left behind is taken over after a short wait, not before"] = function()
		-- a crashed server never releases: the player must not be locked out
		-- for the whole timeout, and must not be let in the instant they hop
		local live = { job = "b", t = 1000 }
		assert(not Session.canAcquire(live, "a", 1005, 0))
		assert(not Session.canAcquire(live, "a", 1005, Session.STEAL_AFTER - 1))
		assert(Session.canAcquire(live, "a", 1005, Session.STEAL_AFTER))
		assert(Session.STEAL_AFTER >= 20, "a normal server hop needs time to save and release")
	end,

	["a Studio session takes the last Studio session's lock at once"] = function()
		-- stopping a play test can cut the final save short; the next play test
		-- must still load. A live server's lock is never taken this way.
		local a, b = Session.studioJob("one"), Session.studioJob("two")
		assert(Session.isStudio(a) and not Session.isStudio("7f3c-live-job"))
		assert(Session.canAcquire({ job = a, t = 1000 }, b, 1001, 0))
		assert(not Session.canAcquire({ job = "7f3c-live-job", t = 1000 }, b, 1001, 0))
		assert(not Session.canAcquire({ job = a, t = 1000 }, "7f3c-live-job", 1001, 0))
	end,
}
