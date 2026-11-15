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
			assert(z > W.PlotBackZ + 2 and z < W.ThrowPadZ - W.ThrowPadRadius, `slot {slot} z = {z}`)
		end
	end,

	["the dojo pad and the sign are inside the plot; the throw stage is out in front"] = function()
		local padX, padZ = World.throwPad(W, 1, COUNT)
		local dojoX, dojoZ = World.dojoPad(W, 1, COUNT)
		local x0 = World.plotX(W, 1, COUNT)
		-- the throw stage stands out in FRONT of the base, a walk away from the
		-- pedestals, and before the first zone begins
		assert(padX == x0)
		assert(padZ - W.ThrowPadRadius > W.PlotFrontZ + 20, "the throw stage is too close to the base")
		assert(padZ + W.ThrowPadRadius < W.LaneStartZ, "the throw stage reaches into the first zone")
		assert(math.abs(dojoX - x0) <= W.PlotWidth / 2 and dojoZ < W.PlotFrontZ)
		-- the two pads must not overlap: a player training must not count as "on the throw pad"
		local gap = World.distance(padX, padZ, dojoX, dojoZ)
		assert(gap > W.ThrowPadRadius + W.DojoPadRadius + 8, `pads are only {gap} studs apart`)
	end,

	["pedestals fill the back half, the front half is an open yard"] = function()
		local mid = (W.PlotBackZ + W.PlotFrontZ) / 2
		for slot = 1, World.pedestalCount(W) do
			local _, z = World.pedestalOffset(W, slot)
			assert(z + 2.5 < mid + 1, `slot {slot} (z = {z}) reaches into the front yard`)
		end
		local _, dojoZ = World.dojoPad(W, 1, COUNT)
		assert(dojoZ > mid, "the dojo pad is not in the front yard")
	end,

	["the training yard is inside the plot, clear of the spawn, dojo pad and sign"] = function()
		local x0 = World.plotX(W, 1, COUNT)
		local yx, yz, yw, yd = World.yard(W, 1, COUNT)
		local mid = (W.PlotBackZ + W.PlotFrontZ) / 2
		assert(math.abs(yx - x0) + yw / 2 <= W.PlotWidth / 2 - 2, "the yard pokes out of the plot side")
		assert(yz - yd / 2 >= mid and yz + yd / 2 <= W.PlotFrontZ - 2, "the yard is not in the front half")
		assert(yw >= 24 and yd >= 20, "the yard is too small for a mini game")
		-- the spawn (6 x 6 at plot centre, PlotFrontZ - 16) stays outside the yard
		assert(math.abs(yx - x0) - yw / 2 > 3, "the spawn stands in the yard")
		local dojoX = World.dojoPad(W, 1, COUNT)
		assert(math.abs(dojoX - yx) > yw / 2 + W.DojoPadRadius, "the dojo pad is in the yard")
		local signX, signZ = World.slotSign(W, 1, COUNT)
		local inX = math.abs(signX - yx) < yw / 2 + 2
		local inZ = math.abs(signZ - yz) < yd / 2 + 2
		assert(not (inX and inZ), "the slot sign is in the yard")
	end,

	["neighbouring bases have a garden gap between them"] = function()
		assert(W.PlotPitch - W.PlotWidth >= 20, `only {W.PlotPitch - W.PlotWidth} studs between bases`)
	end,

	["a landing stays inside its own lane"] = function()
		for plot = 1, COUNT do
			for _, jitter in { -1, 0, 1, 5 } do
				local x = World.landingX(W, plot, COUNT, jitter)
				local off = math.abs(x - World.plotX(W, plot, COUNT))
				assert(off <= W.LaneWidth / 2, `plot {plot} landing leaves the lane`)
			end
		end
	end,

	["lanes do not overlap their neighbours"] = function()
		assert(W.LaneWidth < W.PlotPitch, "lane strips would overlap")
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
		assert(Session.TIMEOUT >= C.Server.AutosaveSeconds * 3, "one slow autosave must not lose the lock")
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
