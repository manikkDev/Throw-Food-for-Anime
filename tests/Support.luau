--!strict
-- Shared by the specs: the real generated config, its id maps, and a seeded
-- random source so a roll spec gives the same answer on every run.

local Config = require("../src/shared/Config/GameConfig")
local Lookup = require("../src/shared/Core/Lookup")

local Support = {}

Support.Config = Config :: any
Support.Maps = Lookup.of(Config)

--- A deterministic generator returning numbers in [0, 1).
function Support.rng(seed: number): () -> number
	local state = seed
	return function(): number
		-- Park-Miller minimal standard generator
		state = (state * 48271) % 2147483647
		return (state - 1) / 2147483646
	end
end

--- `a` within `tolerance` (a fraction) of `b`.
function Support.near(a: number, b: number, tolerance: number): boolean
	if b == 0 then
		return math.abs(a) <= tolerance
	end
	return math.abs(a - b) / math.abs(b) <= tolerance
end

return Support
