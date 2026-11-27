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

--- Grade a HELD beat (hold, let go on the beat): the release is graded like a
--- tap, but only when the hold began at least `minHold` seconds before it. A
--- flick is a miss, so tapping fast cannot stand in for holding.
function Beat.gradeHold(
	cfgBeat: any,
	gap: number,
	held: number,
	minHold: number,
	lag: number?
): Grade
	if held < minHold - (lag or 0) then
		return "miss"
	end
	return Beat.grade(cfgBeat, gap, lag)
end

--- The Focus a graded beat gives on a ground whose beats are `beatSeconds`
--- apart: a slow beat carries as many reps as it is long, and as much Focus,
--- so every ground awakens at the same rate.
function Beat.focus(cfgBeat: any, grade: Grade, beatSeconds: number, repSeconds: number): number
	local _, focus = Beat.reward(cfgBeat, grade)
	return focus * math.max(1, beatSeconds / repSeconds)
end

--- Where a session is at `t` seconds: the beat to play next (a beat stays the
--- one to play until `late` seconds after its moment), the seconds to its
--- moment (negative = before it) and how far the way from the beat before it
--- has gone (0..1 at the moment, a little over 1 after it).
function Beat.upcoming(
	beatSeconds: number,
	t: number,
	seed: number,
	late: number
): (number, number, number)
	local n = Beat.nearest(beatSeconds, t, seed)
	local moment = Beat.moment(beatSeconds, n, seed)
	if t - moment > late then
		n += 1
		moment = Beat.moment(beatSeconds, n, seed)
	end
	local before = if n > 1 then Beat.moment(beatSeconds, n - 1, seed) else 0
	local span = math.max(moment - before, 1e-3)
	return n, t - moment, math.clamp((t - before) / span, 0, 1.25)
end

--- A clip whose reps fall on the beats. `marks` are the seconds into the clip
--- (one loop is `length` long) of its reps, in order; beat n lands on mark
--- ((n - 1) mod #marks) + 1. Returns the clip time (0..length) the clip should
--- be at when the session is at `t`, and the speed it should run at there.
function Beat.clipAt(
	beatSeconds: number,
	t: number,
	seed: number,
	marks: { number },
	length: number
): (number, number)
	local count = #marks
	-- the clip time of beat n's rep, unwrapped (it grows by `length` every `count` beats)
	-- (beat 0 is the session's start: the last rep of the loop before)
	local function at(n: number): number
		return marks[(n - 1) % count + 1] + math.floor((n - 1) / count) * length
	end
	-- the beat whose moment is next after t
	local n = math.max(1, math.floor(t / beatSeconds))
	while Beat.moment(beatSeconds, n, seed) <= t do
		n += 1
	end
	while n > 1 and Beat.moment(beatSeconds, n - 1, seed) > t do
		n -= 1
	end
	local t1 = Beat.moment(beatSeconds, n, seed)
	local t0 = if n > 1 then Beat.moment(beatSeconds, n - 1, seed) else 0
	local c1, c0 = at(n), at(n - 1)
	local speed = (c1 - c0) / math.max(t1 - t0, 1e-3)
	local clip = c0 + (t - t0) * speed
	return clip % length, speed
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
--- `perfect` and `good` shares of the beats (the same on every ground: a slow
--- beat carries more reps and as much more Focus, see Beat.focus). The
--- simulator's TapTypical and TapPerfect are this function's values.
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
