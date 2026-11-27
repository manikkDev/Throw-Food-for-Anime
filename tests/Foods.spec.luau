--!strict
-- Foods and Beat (plan 13): food is luck by world, the training judge.
local Support = require("./Support")
local Icons = require("../src/shared/Config/Icons")
local Beat = require("../src/shared/Core/Beat")
local Foods = require("../src/shared/Core/Foods")

local C = Support.Config
local M = Support.Maps
local B = C.Training.Beat

return {
	-- ------------------------------------------------------------------ foods
	["every world sells a snack, a meal and a signature dish, each luckier and dearer"] = function()
		assert(#C.Foods == #C.Zones * 3, "three foods per world")
		for z = 1, #C.Zones do
			local set = Foods.ofZone(C, z)
			assert(#set == 3, `world {z} has {#set} foods`)
			assert(set[1].Role == "Snack" and set[2].Role == "Meal" and set[3].Role == "Signature")
			assert(set[1].Luck < set[2].Luck and set[2].Luck < set[3].Luck)
			assert(set[1].Cost < set[2].Cost and set[2].Cost < set[3].Cost)
		end
		assert(C.Foods[1].Cost == 0, "the starter food is free")
	end,

	["a food is stale past its own world, and the next world's snack beats the stale signature"] = function()
		for z = 1, #C.Zones - 1 do
			local here, there = Foods.ofZone(C, z), Foods.ofZone(C, z + 1)
			local signature = here[3]
			assert(Foods.luckAt(C, signature, z) == signature.Luck)
			assert(Foods.luckAt(C, signature, 1) == signature.Luck, "full luck in earlier worlds")
			assert(Foods.isStale(signature, z + 1) and not Foods.isStale(signature, z))
			local stale = Foods.luckAt(C, signature, z + 1)
			assert(Support.near(stale, signature.Luck * C.Luck.StaleFood, 1e-9))
			assert(there[1].Luck > stale, `world {z + 1}'s snack does not beat the stale signature`)
		end
	end,

	["auto-pick throws the best owned food for the world; a pinned food is kept"] = function()
		local first, second = Foods.ofZone(C, 1), Foods.ofZone(C, 2)
		local owned = { [first[1].Id] = true, [first[3].Id] = true, [second[1].Id] = true }
		assert((Foods.best(C, owned, 1) :: any).Id == first[3].Id)
		assert((Foods.best(C, owned, 2) :: any).Id == second[1].Id)
		local profile = { food = first[1].Id, foods = owned, autoFood = true }
		assert((Foods.forThrow(C, M.food, profile, 2) :: any).Id == second[1].Id)
		profile.autoFood = false
		assert((Foods.forThrow(C, M.food, profile, 2) :: any).Id == first[1].Id)
		profile.food = "not_a_food"
		assert((Foods.forThrow(C, M.food, profile, 2) :: any).Id == second[1].Id)
	end,

	["the cookbook counts complete worlds"] = function()
		local owned: { [string]: boolean } = {}
		for _, food in Foods.ofZone(C, 1) do
			owned[food.Id] = true
		end
		owned[Foods.ofZone(C, 2)[1].Id] = true
		assert(Foods.setComplete(C, owned, 1) and not Foods.setComplete(C, owned, 2))
		assert(Foods.setsComplete(C, owned) == 1)
	end,

	["every hero's favourite is a dish of its own world, and every dish is somebody's favourite"] = function()
		local zoneIndex: { [string]: number } = {}
		for i, zone in C.Zones do
			zoneIndex[zone.Id] = i
		end
		local loved: { [string]: boolean } = {}
		for _, character in C.Characters do
			local food = M.food[character.Favourite]
			assert(food ~= nil, `{character.Id} has no favourite dish`)
			assert(
				food.Zone == zoneIndex[character.Zone],
				`{character.Id} loves another world's dish`
			)
			loved[food.Id] = true
		end
		for _, food in C.Foods do
			assert(loved[food.Id], `nobody's favourite: {food.Name}`)
		end
	end,

	["every food has an icon of its own"] = function()
		for _, food in C.Foods do
			assert((Icons :: any)["Food_" .. food.Id] ~= nil, `no icon: {food.Name}`)
		end
	end,

	-- ------------------------------------------------------------------- beat
	["beat moments are in order, jittered, and the same for the same seed"] = function()
		for _, seconds in { 1, 2, 3, 4 } do
			local last = 0
			local offGrid = 0
			for n = 1, 200 do
				local t = Beat.moment(seconds, n, 7)
				assert(t > last, "beats out of order")
				assert(math.abs(t - n * seconds) <= 0.2 * seconds + 1e-9, "jitter past 20%")
				assert(t == Beat.moment(seconds, n, 7))
				if math.abs(t - n * seconds) > 0.02 * seconds then
					offGrid += 1
				end
				assert(Beat.nearest(seconds, t, 7) == n)
				last = t
			end
			assert(offGrid > 150, "the beats sit on a fixed grid: an auto-clicker could ride them")
		end
	end,

	["a tap is graded by its distance from the beat"] = function()
		assert(Beat.grade(B, 0) == "perfect" and Beat.grade(B, -B.PerfectWindow) == "perfect")
		assert(Beat.grade(B, B.PerfectWindow + 0.01) == "good")
		assert(Beat.grade(B, B.GoodWindow + 0.01) == "miss")
		assert(
			Beat.grade(B, B.GoodWindow + 0.01, 0.05) == "good",
			"lag allowance widens the window"
		)
		local mult, focus = Beat.reward(B, "perfect")
		assert(mult == 1 + B.PerfectBonus and focus == B.FocusPerfect)
		mult, focus = Beat.reward(B, "miss")
		assert(mult == 1 and focus == 0, "a miss still pays the plain reps")
	end,

	["playing is worth what the simulator assumes"] = function()
		assert(Beat.rate(B, 0, 0) == 1, "leaving it running is x1")
		assert(Support.near(Beat.rate(B, 0.4, 0.4), C.Sim.TapTypical, 0.05))
		assert(Support.near(Beat.rate(B, 1, 0), C.Sim.TapPerfect, 0.05))
		assert(Beat.rate(B, 1, 0) < 2.5, "the active ceiling stays under x2.5")
	end,
}
