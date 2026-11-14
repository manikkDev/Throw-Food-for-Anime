--!strict
-- Guard - what every remote handler runs first: a rate limit and type checks.
--
-- A client can fire any remote with anything, as fast as it likes. Each handler
-- asks Guard.allow(player, "Name", rate, burst) before doing work, so one
-- client in a loop costs a table lookup instead of a DataStore write.

local Players = game:GetService("Players")

local Guard = {}

type Bucket = { tokens: number, t: number }

local buckets: { [Player]: { [string]: Bucket } } = {}

--- Token bucket: `rate` per second, at most `burst` saved up.
function Guard.allow(player: Player, key: string, rate: number, burst: number): boolean
	local mine = buckets[player]
	if not mine then
		mine = {}
		buckets[player] = mine
	end
	local now = os.clock()
	local bucket = mine[key]
	if not bucket then
		bucket = { tokens = burst, t = now }
		mine[key] = bucket
	end
	bucket.tokens = math.min(burst, bucket.tokens + (now - bucket.t) * rate)
	bucket.t = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

--- A finite number (not nan, not infinity).
function Guard.number(value: any): boolean
	return typeof(value) == "number" and value == value and math.abs(value) ~= math.huge
end

--- A whole number inside [lo, hi].
function Guard.integer(value: any, lo: number, hi: number): boolean
	return Guard.number(value) and value % 1 == 0 and value >= lo and value <= hi
end

--- A string no longer than `max`.
function Guard.text(value: any, max: number): boolean
	return typeof(value) == "string" and #value <= max
end

Players.PlayerRemoving:Connect(function(player: Player)
	buckets[player] = nil
end)

return Guard
