--!strict
-- Beat - the judge of every training game. Pure. (Plan 13, section 5.1.)
--
-- Reps run on the server's clock whether the player touches anything or not
-- (the leave-it-running floor, x1). A training ground shows one BEAT at a
-- time; the player's one input per beat is judged against the beat's moment:
--   Perfect  the beat's reps pay x (1 + PerfectBonus) and give FocusPerfect
--   Good     x (1 + GoodBonus), FocusGood
--   miss     the plain reps
-- At FocusFull the hero AWAKENS for AwakeningSeconds: every rep is an
-- automatic Perfect and pays x AwakeningMult on top; no input counts.
--
-- Beat moments are jittered from a seed the server picks, so a fixed-interval
-- auto-clicker cannot sit on the Perfect window.
local Beat = {}

export type Grade = "perfect" | "good" | "miss"

--- The moment (seconds from the session start) of beat `n` (1-based) for a
--- ground whose beats are `beatSeconds` apart. Jitter is up to +-20% of a
--- beat, the same for server and client from the same `seed`.
function Beat.moment(beatSeconds: number, n: number, seed: number): number
	local x = math.sin(n * 12.9898 + seed * 78.233) * 43758.5453
	local unit = x - math.floor(x) -- 0..1, deterministic
	return (n + (unit - 0.5) * 0.4) * beatSeconds
end

--- The beat whose moment is nearest `t`.
function Beat.nearest(beatSeconds: number, t: number, seed: number): number
	local guess = math.max(1, math.floor(t / beatSeconds + 0.5))
	local best, bestGap = guess, math.huge
	for n = math.max(1, guess - 1), guess + 1 do
		local gap = math.abs(Beat.moment(beatSeconds, n, seed) - t)
		if gap < bestGap then
			best, bestGap = n, gap
		end
	end
	return best
end

--- Grade an input `gap` seconds from the beat's moment. Windows are half
--- widths; `lag` widens both (network allowance).
function Beat.grade(cfgBeat: any, gap: number, lag: number?): Grade
	local slack = lag or 0
	local off = math.abs(gap)
	if off <= cfgBeat.PerfectWindow + slack then
		return "perfect"
	elseif off <= cfgBeat.GoodWindow + slack then
		return "good"
	end
	return "miss"
end

--- What a beat pays: the multiplier on its plain reps, and the Focus it gives.
function Beat.reward(cfgBeat: any, grade: Grade): (number, number)
	if grade == "perfect" then
		return 1 + cfgBeat.PerfectBonus, cfgBeat.FocusPerfect
	elseif grade == "good" then
		return 1 + cfgBeat.GoodBonus, cfgBeat.FocusGood
	end
	return 1, 0
end

--- The multiplier on every rep while awakened.
function Beat.awakenedMult(cfgBeat: any): number
	return (1 + cfgBeat.PerfectBonus) * cfgBeat.AwakeningMult
end

--- Long-run rate against leaving it running (x1), for a player who lands
--- `perfect` and `good` shares of one-second beats. The simulator's
--- TapTypical and TapPerfect are this function's values.
function Beat.rate(cfgBeat: any, perfect: number, good: number): number
	local base = 1 + perfect * cfgBeat.PerfectBonus + good * cfgBeat.GoodBonus
	local focusPerBeat = perfect * cfgBeat.FocusPerfect + good * cfgBeat.FocusGood
	if focusPerBeat <= 0 then
		return base
	end
	local fill = cfgBeat.FocusFull / focusPerBeat
	local awake = cfgBeat.AwakeningSeconds
	return (fill * base + awake * Beat.awakenedMult(cfgBeat)) / (fill + awake)
end

return Beat
