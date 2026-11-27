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
	["one ground per rebirth band, on alternating courts, each with gear tiers of its own"] = function()
		assert(#T.Grounds == 8)
		local covered = 0
		for g, row in T.Grounds do
			assert(row.Rebirth == g - 1, `ground {g} opens at rebirth {row.Rebirth}`)
			assert(
				Grounds.court(C, g) == (g - 1) % 2 + 1,
				"courts alternate, the first on the left"
			)
			local first, last = Grounds.tiers(C, g)
			assert(
				first == covered + 1 and last >= first + 1,
				`ground {g} has tiers {first}..{last}`
			)
			covered = last
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
			local newest = math.min(rebirth + 1, #T.Grounds)
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
		assert(Grounds.template(C, 2, 5) == "Ground_falls_T5")
	end,

	["the grounds of phase D have everything the framework reads"] = function()
		for g = 1, 2 do
			local row = T.Grounds[g]
			assert(row.Clip and row.AwakeClip and row.Hint, `ground {g} has no clips or hint`)
			assert(#row.Marks >= 1 and row.ClipSeconds > 0)
			for i, mark in row.Marks do
				assert(mark > 0 and mark < row.ClipSeconds)
				assert(i == 1 or mark > row.Marks[i - 1])
			end
		end
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
		for g = 1, 2 do
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
}
