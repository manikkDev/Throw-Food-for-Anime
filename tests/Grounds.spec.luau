--!strict
-- Training grounds (plan 13 phase D): which grounds a base shows, what they
-- look like, and the judge's rules for held beats and for clips that keep time.
local Support = require("./Support")
local Beat = require("../src/shared/Core/Beat")
local Grounds = require("../src/shared/Core/Grounds")

local C = Support.Config
local T = C.Training
local B = T.Beat

return {
	["six grounds on alternating courts, each with gear tiers of its own, open when its gear is reached"] = function()
		assert(#T.Grounds == 6)
		local covered = 0
		local opened = -1
		for g, row in T.Grounds do
			assert(row.Rebirth > opened, `ground {g} opens after the one before it`)
			opened = row.Rebirth
			assert(
				Grounds.court(C, g) == (g - 1) % 2 + 1,
				"courts alternate, the first on the left"
			)
			local first, last = Grounds.tiers(C, g)
			assert(
				first == covered + 1 and last >= first + 2,
				`ground {g} has tiers {first}..{last}`
			)
			covered = last
			-- its first gear tier's world is reached in the rebirth tier that opens it, not before:
			-- the ground the owner's gear belongs to is then always one of the two a base shows
			local firstRow = T.Equipment[(first - 1) * 3 + 1]
			local need = firstRow.RebirthReq or C.Zones[firstRow.Zone].RebirthReq
			assert(row.Rebirth == need, `ground {g} opens at {row.Rebirth}, its gear at {need}`)
		end
		-- whatever gear a player can own at a rebirth tier, its ground is on show
		for i, gear in T.Equipment do
			local need = gear.RebirthReq or C.Zones[gear.Zone].RebirthReq
			local shown = Grounds.shown(C, need)
			assert(
				shown[1].ground == gear.Ground or shown[2].ground == gear.Ground,
				`gear {i} ({gear.Name}) trains on a ground that is not shown at rebirth {need}`
			)
		end
		assert(covered == #T.Equipment / 3, "every gear tier belongs to a ground")
		for i, row in T.Equipment do
			assert(row.Tier == math.ceil(i / 3) and row.Level == (i - 1) % 3 + 1)
			assert(row.Model == Grounds.tierName(C, row.Tier) and row.Model ~= "")
		end
	end,

	["a base shows the two newest grounds; before the first rebirth the second is locked"] = function()
		local start = Grounds.shown(C, 0)
		assert(start[1].ground == 1 and start[1].locked == nil)
		assert(start[2].ground == 2 and start[2].locked == 1, "the waterfall waits for rebirth 1")
		for rebirth = 1, 10 do
			local shown = Grounds.shown(C, rebirth)
			local newest = 1
			for g, row in T.Grounds do
				if row.Rebirth <= rebirth then
					newest = g
				end
			end
			local seen = { [shown[1].ground] = true, [shown[2].ground] = true }
			assert(seen[newest] and seen[newest - 1], `rebirth {rebirth} shows the wrong grounds`)
			assert(shown[1].locked == nil and shown[2].locked == nil)
			assert(
				Grounds.court(C, shown[1].ground) == 1 and Grounds.court(C, shown[2].ground) == 2
			)
		end
	end,

	["a ground wears the owner's gear, an older one its best look, a newer one its first"] = function()
		assert(select("#", Grounds.look(C, 1, 0)) == 2)
		local tier, level = Grounds.look(C, 1, 0)
		assert(tier == 1 and level == 1, "an empty base shows the first look")
		tier, level = Grounds.look(C, 1, 5) -- Banded Post II
		assert(tier == 2 and level == 2)
		tier, level = Grounds.look(C, 1, 13) -- on the falls' gear: the post is at its best
		assert(tier == 3 and level == 3)
		tier, level = Grounds.look(C, 2, 9) -- Iron Post III: the falls have not been bought into yet
		assert(tier == 4 and level == 1)
		tier, level = Grounds.look(C, 2, 15)
		assert(tier == 5 and level == 3)
		tier, level = Grounds.look(C, 2, 30) -- far past the falls: their last tier at its best
		assert(tier == 6 and level == 3)
		tier, level = Grounds.look(C, 6, 57)
		assert(tier == 19 and level == 3, "the last gear is the orb's fourth tier")
		assert(Grounds.template(C, 2, 5) == "Ground_falls_T5")
	end,

	["the grounds built so far have everything the framework reads"] = function()
		for g = 1, #T.Grounds do
			local row = T.Grounds[g]
			assert(row.Clip and row.AwakeClip and row.Hint, `ground {g} has no clips or hint`)
			-- a clip that keeps time names its reps; a reflex ground's waiting loop has none
			if row.Marks then
				assert(#row.Marks >= 1 and row.ClipSeconds > 0)
				for i, mark in row.Marks do
					assert(mark > 0 and mark < row.ClipSeconds)
					assert(i == 1 or mark > row.Marks[i - 1])
				end
			else
				assert(row.Lanes, `ground {g} has neither reps nor lanes`)
			end
		end
		local peak = T.Grounds[4]
		assert(peak.Lanes == 3 and #peak.LaneClips == 3, "one answer clip per rod")
		assert(
			peak.React > 0.3 and peak.React < peak.Lead,
			"a Perfect needs a human reaction, inside the lead"
		)
		assert(
			peak.Lead < peak.BeatSeconds * 0.8 - B.GoodWindow,
			"the mark shows after the beat before is over"
		)
		assert(T.Grounds[2].Game == "breath" and T.Grounds[2].MinHold > B.PerfectWindow)
		assert(
			T.Grounds[2].MinHold < T.Grounds[2].BeatSeconds * 0.5,
			"the hold fits in the shortest beat"
		)
	end,

	["a held beat is graded on the release, and a flick is a miss"] = function()
		assert(Beat.gradeHold(B, 0, 1.2, 0.6) == "perfect")
		assert(Beat.gradeHold(B, B.PerfectWindow + 0.02, 1.2, 0.6) == "good")
		assert(Beat.gradeHold(B, 0, 0.2, 0.6) == "miss", "a tap on the beat is not a hold")
		assert(
			Beat.gradeHold(B, 0, 0.55, 0.6, 0.08) == "perfect",
			"the lag allowance covers the hold"
		)
	end,

	["a reflex beat: the right lane fast is Perfect, later Good, wrong or guessed a miss"] = function()
		local lead, react = T.Grounds[4].Lead, T.Grounds[4].React
		assert(Beat.gradeReflex(B, -lead + 0.3, 2, 2, lead, react) == "perfect")
		assert(Beat.gradeReflex(B, -lead + react + 0.05, 2, 2, lead, react) == "good")
		assert(
			Beat.gradeReflex(B, -0.01, 2, 2, lead, react) == "good",
			"any time before the strike"
		)
		assert(
			Beat.gradeReflex(B, B.PerfectWindow + 0.05, 2, 2, lead, react) == "miss",
			"after the strike"
		)
		assert(Beat.gradeReflex(B, -lead + 0.3, 1, 2, lead, react) == "miss", "the wrong rod")
		assert(
			Beat.gradeReflex(B, -lead - 0.2, 2, 2, lead, react) == "miss",
			"before the mark: a guess"
		)
	end,

	["lanes: every rod gets its share, never three times running, the same for server and client"] = function()
		for _, seed in { 1, 77, 4242 } do
			local counts = { 0, 0, 0 }
			local run, last = 0, 0
			for n = 1, 600 do
				local lane = Beat.lane(n, seed, 3)
				assert(lane >= 1 and lane <= 3 and lane == Beat.lane(n, seed, 3))
				counts[lane] += 1
				run = if lane == last then run + 1 else 1
				last = lane
				assert(run <= 2, `seed {seed}: lane {lane} three times running at beat {n}`)
			end
			for lane = 1, 3 do
				assert(
					counts[lane] > 120,
					`seed {seed}: rod {lane} is struck only {counts[lane]} times in 600`
				)
			end
		end
	end,

	["a slow beat gives as much Focus as the reps it carries: every ground awakens alike"] = function()
		assert(Beat.focus(B, "perfect", 1, 1) == B.FocusPerfect)
		assert(Beat.focus(B, "perfect", 3, 1) == 3 * B.FocusPerfect)
		assert(Beat.focus(B, "good", 3, 1) == 3 * B.FocusGood)
		assert(Beat.focus(B, "miss", 3, 1) == 0)
	end,

	["the beat to play: it stays the one until it is late, and its progress runs 0 to 1"] = function()
		for _, seconds in { 1, 3 } do
			for n = 2, 30 do
				local moment = Beat.moment(seconds, n, 11)
				local before = Beat.moment(seconds, n - 1, 11)
				local got, gap, progress = Beat.upcoming(seconds, moment, 11, B.GoodWindow)
				assert(got == n and math.abs(gap) < 1e-6 and math.abs(progress - 1) < 1e-6)
				got, gap = Beat.upcoming(seconds, moment + B.GoodWindow - 0.01, 11, B.GoodWindow)
				assert(got == n and gap > 0, "still gradable just inside the good window")
				got = Beat.upcoming(seconds, moment + B.GoodWindow + 0.01, 11, B.GoodWindow)
				assert(got == n + 1, "then the next beat is up")
				got, gap, progress =
					Beat.upcoming(seconds, before + B.GoodWindow + 0.02, 11, B.GoodWindow)
				assert(got == n and gap < 0 and progress > 0 and progress < 1)
			end
		end
	end,

	["a clip in time: every rep of the clip falls on a beat, at a speed a body can move at"] = function()
		for g = 1, 3 do
			local row = T.Grounds[g]
			local seconds, marks, length = row.BeatSeconds, row.Marks, row.ClipSeconds
			for n = 1, 40 do
				local moment = Beat.moment(seconds, n, 5)
				local clip = Beat.clipAt(seconds, moment - 1e-4, 5, marks, length)
				local mark = marks[(n - 1) % #marks + 1]
				local off = math.abs(clip - mark)
				assert(
					math.min(off, length - off) < 0.01,
					`beat {n}: the clip is at {clip}, its rep at {mark}`
				)
				local _, speed = Beat.clipAt(seconds, moment - seconds * 0.3, 5, marks, length)
				assert(speed > 0.55 and speed < 1.8, `beat {n} runs the clip at x{speed}`)
			end
			-- it never runs backwards or jumps: a step of time is a step of clip
			local last = Beat.clipAt(seconds, 0, 5, marks, length)
			for i = 1, 400 do
				local t = i * 0.05
				local clip, speed = Beat.clipAt(seconds, t, 5, marks, length)
				local step = (clip - last) % length
				assert(step > 0 and step < 0.05 * 1.8 + 1e-6, `the clip jumped {step} at {t}`)
				assert(speed > 0)
				last = clip
			end
		end
	end,

	["rests: one beat in every hand, never two together, and the played beats pay for the hand"] = function()
		for seed = 1, 30 do
			assert(not Beat.rest(1, seed, 4), "a session opens on a played beat")
			local played = 0
			for n = 1, 200 do
				local rest = Beat.rest(n, seed, 4)
				assert(not (rest and Beat.rest(n + 1, seed, 4)), `two rests together at {n}`)
				if not rest then
					played += 1
				end
				assert(Beat.played(n, seed, 4) == played, `played count at {n}`)
			end
			assert(played == 150, "three beats in four are played")
		end
		assert(Beat.share(4) == 0.75 and Beat.share(nil) == 1)
		assert(not Beat.rest(7, 3, nil) and Beat.played(9, 3, nil) == 9)
	end,

	["a clip over rests: reps only on played beats, the top of the push-up held over a rest"] = function()
		local row
		for _, ground in T.Grounds do
			if ground.Rests then
				row = ground
			end
		end
		assert(row, "a ground with rests")
		local seconds, marks, length, rests = row.BeatSeconds, row.Marks, row.ClipSeconds, row.Rests
		local k = 0
		for n = 1, 60 do
			local moment = Beat.moment(seconds, n, 9)
			local clip, speed = Beat.clipAt(seconds, moment - 1e-4, 9, marks, length, rests)
			if Beat.rest(n, 9, rests) then
				-- midway between two reps and still
				local before, after = marks[(k - 1) % #marks + 1], marks[k % #marks + 1]
				local mid = (before + (after - before) % length / 2) % length
				local off = math.abs(clip - mid)
				assert(
					math.min(off, length - off) < 0.01,
					`rest {n}: the clip is at {clip}, not {mid}`
				)
				assert(speed == 0, "held")
			else
				k += 1
				local mark = marks[(k - 1) % #marks + 1]
				local off = math.abs(clip - mark)
				assert(
					math.min(off, length - off) < 0.01,
					`beat {n}: the clip is at {clip}, its rep at {mark}`
				)
			end
		end
		local last = Beat.clipAt(seconds, 0, 9, marks, length, rests)
		for i = 1, 800 do
			local t = i * 0.025
			local clip, speed = Beat.clipAt(seconds, t, 9, marks, length, rests)
			local step = (clip - last) % length
			assert(step < 0.025 * 1.8 + 1e-6, `the clip jumped {step} at {t}`)
			assert(speed >= 0 and speed < 1.8)
			last = clip
		end
	end,
}
