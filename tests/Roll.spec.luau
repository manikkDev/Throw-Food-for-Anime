--!strict
local Support = require("./Support")
local Roll = require("../src/shared/Core/Roll")
local Luck = require("../src/shared/Core/Luck")

local C = Support.Config
local M = Support.Maps
local ZONE1 = M.zoneCharacters[C.Zones[1].Id]
local LAST = M.zoneCharacters[C.Zones[#C.Zones].Id]

local function chanceOf(rows: { any }, rarity: string): number
	local total = 0
	for _, row in rows do
		if row.rarity == rarity then
			total += row.chance
		end
	end
	return total
end

local BASE: Luck.Sources = {
	foodLuck = 1,
	depth = 0,
	perfect = false,
	serverMult = 1,
	friends = 0,
	vip = false,
	luckyAura = false,
	zonesCompleted = 0,
	rebirthTier = 0,
	streakBonus = 0,
	luckyThrow = false,
}

return {
	["every zone has heroes and its chances sum to one"] = function()
		for _, zone in C.Zones do
			local rows = Roll.heroWeights(C, M.zoneCharacters[zone.Id], 1, nil)
			assert(#rows >= 5, `{zone.Name} has only {#rows} heroes`)
			local sum = 0
			for _, row in rows do
				sum += row.chance
			end
			assert(math.abs(sum - 1) < 1e-9, `{zone.Name} chances sum to {sum}`)
		end
	end,

	["the roll uses the same closed form as the pacing simulator"] = function()
		-- tools/balance_sim.py computes, per rarity:
		--   weight = Weight x (1 + (luck - 1) x LuckScale)   for each rarity the
		--   zone has, however many heroes share it
		-- and per variant:  chance = Chance x (1 + (luck - 1) x LuckScale), capped
		-- at what is left. If this spec and the simulator ever disagree, the
		-- pacing table is describing a different game.
		for _, luck in { 1, 2.5, 12 } do
			for _, zone in C.Zones do
				local total = 0
				local want: { [string]: number } = {}
				for rarity in zone.Slots do
					local row = C.Rarities[rarity]
					want[rarity] = row.Weight * (1 + (luck - 1) * row.LuckScale)
					total += want[rarity]
				end
				local rows = Roll.heroWeights(C, M.zoneCharacters[zone.Id], luck, nil)
				for rarity, weight in want do
					local got = chanceOf(rows, rarity)
					assert(
						Support.near(got, weight / total, 1e-9),
						`{zone.Name} {rarity} at luck {luck}: {got} vs {weight / total}`
					)
				end
			end
			local left = 1
			for _, variant in C.Mutations do
				local want = math.min(variant.Chance * (1 + (luck - 1) * variant.LuckScale), left)
				left -= want
				-- measure the band by sweeping the roll
				local hits = 0
				local steps = 20000
				for i = 0, steps - 1 do
					if Roll.variant(C.Mutations, luck, (i + 0.5) / steps, 1) == variant.Name then
						hits += 1
					end
				end
				assert(
					math.abs(hits / steps - want) < 2 / steps + 1e-9,
					`{variant.Name} at luck {luck}: {hits / steps} vs {want}`
				)
			end
		end
	end,

	["every zone's Slots table matches the heroes actually in it"] = function()
		-- the simulator reads Slots; the game reads Characters. They must agree.
		for _, zone in C.Zones do
			local counts: { [string]: number } = {}
			for _, character in M.zoneCharacters[zone.Id] do
				counts[character.Rarity] = (counts[character.Rarity] or 0) + 1
			end
			for rarity, count in zone.Slots do
				assert(
					counts[rarity] == count,
					`{zone.Name} has {counts[rarity]} {rarity}, Slots says {count}`
				)
				counts[rarity] = nil
			end
			assert(next(counts) == nil, `{zone.Name} has heroes of a rarity missing from Slots`)
		end
	end,

	["adding a hero to a zone never changes its rarity odds"] = function()
		-- the roster grows by importing avatars; that must never move the economy
		local before = Roll.heroWeights(C, ZONE1, 2, nil)
		local grown = table.clone(ZONE1)
		for _, rarity in { "Common", "Legendary", "Legendary" } do
			table.insert(grown, { Id = "extra_" .. #grown, Rarity = rarity, Craves = "None" })
		end
		local after = Roll.heroWeights(C, grown, 2, nil)
		for rarity in C.Zones[1].Slots do
			assert(
				Support.near(chanceOf(after, rarity), chanceOf(before, rarity), 1e-9),
				`{rarity} odds moved when heroes were added`
			)
		end
	end,

	["heroes of one rarity share its chance equally"] = function()
		for _, zone in C.Zones do
			local rows = Roll.heroWeights(C, M.zoneCharacters[zone.Id], 1, nil)
			for rarity, count in zone.Slots do
				local whole = chanceOf(rows, rarity)
				for _, row in rows do
					if row.rarity == rarity then
						assert(
							Support.near(row.chance, whole / count, 1e-9),
							`{row.id} share is off`
						)
					end
				end
			end
		end
	end,

	["luck never lowers the chance of a rarer hero"] = function()
		local at1 = Roll.heroWeights(C, ZONE1, 1, nil)
		local at8 = Roll.heroWeights(C, ZONE1, 8, nil)
		for _, rarity in { "Rare", "Epic", "Legendary" } do
			assert(chanceOf(at8, rarity) > chanceOf(at1, rarity), `{rarity} got rarer with luck`)
		end
		assert(chanceOf(at8, "Common") < chanceOf(at1, "Common"))
	end,

	["a craving triples exactly one hero's weight"] = function()
		local plain = Roll.heroWeights(C, ZONE1, 1, nil)
		local target = ZONE1[1]
		local craved = Roll.heroWeights(C, ZONE1, 1, target.Craves)
		for i, row in craved do
			local hero = M.character[row.id]
			local expected = if hero.Craves == target.Craves
				then plain[i].weight * C.Throw.CravingWeightMult
				else plain[i].weight
			assert(math.abs(row.weight - expected) < 1e-9, `{row.id} weight is wrong`)
		end
	end,

	["a legendary in zone one is rare but reachable"] = function()
		-- pins the DESIGN: roughly 1 in 300 at base luck. If someone retunes
		-- the weights this fails and forces the conversation.
		local p = chanceOf(Roll.heroWeights(C, ZONE1, 1, nil), "Legendary")
		assert(p > 1 / 600 and p < 1 / 150, `legendary chance is 1 in {1 / p}`)
	end,

	["the mythic exists only in the last zone"] = function()
		assert(chanceOf(Roll.heroWeights(C, ZONE1, 1, nil), "Mythic") == 0)
		assert(chanceOf(Roll.heroWeights(C, LAST, 1, nil), "Mythic") > 0)
	end,

	["at most one mutation and one size per catch"] = function()
		local rng = Support.rng(7)
		for _ = 1, 2000 do
			local name, p = Roll.variant(C.Mutations, 1, rng(), 1)
			assert(p > 0 and p <= 1)
			assert(name == nil or M.mutation[name] ~= nil)
		end
	end,

	["variant chances cannot exceed certainty however high the luck"] = function()
		local total = 0
		for i = 0, 999 do
			local name = Roll.variant(C.Mutations, 1e6, i / 1000, 1)
			if name then
				total += 1
			end
		end
		assert(total == 1000, "at absurd luck every catch is mutated, never more than every catch")
	end,

	["rolled rates match the stated chances over 100k throws"] = function()
		local rng = Support.rng(12345)
		local n = 100000
		local seen: { [string]: number } = {}
		local golden = 0
		for _ = 1, n do
			local result = Roll.throw(C, ZONE1, 1, nil, rng)
			seen[result.rarity] = (seen[result.rarity] or 0) + 1
			if result.mutation == "Golden" then
				golden += 1
			end
		end
		local rows = Roll.heroWeights(C, ZONE1, 1, nil)
		for _, rarity in { "Common", "Uncommon", "Rare" } do
			local want = chanceOf(rows, rarity)
			local got = (seen[rarity] or 0) / n
			assert(Support.near(got, want, 0.05), `{rarity}: rolled {got}, stated {want}`)
		end
		assert(Support.near(golden / n, M.mutation.Golden.Chance, 0.08), "golden rate is off")
	end,

	["one in N is the product of the three chances"] = function()
		local rng = Support.rng(99)
		for _ = 1, 200 do
			local r = Roll.throw(C, ZONE1, 3, nil, rng)
			local want = 1 / (r.pHero * r.pMutation * r.pSize)
			assert(Support.near(r.oneInN, want, 1e-9))
			assert(r.oneInN >= 1)
		end
	end,

	["summon odds sum to one hundred and every row can be drawn"] = function()
		local odds = {}
		local total = 0
		for _, hero in C.PremiumCharacters do
			if hero.Source == "Summon" then
				table.insert(odds, hero)
				total += hero.OddsPercent
			end
		end
		assert(total == 100, `summon odds sum to {total}, the odds screen must show 100`)
		local drawn = {}
		for i = 0, 999 do
			drawn[Roll.byPercent(odds, i / 1000).Id] = true
		end
		for _, hero in odds do
			assert(drawn[hero.Id], `{hero.Id} can never be drawn`)
		end
	end,

	["luck sources multiply and the list explains the total"] = function()
		assert(Luck.total(C, BASE) == 1)
		local s = table.clone(BASE)
		s.foodLuck = 2
		s.serverMult = 4
		s.perfect = true
		local total = Luck.total(C, s)
		assert(Support.near(total, 2 * 4 * (1 + C.Throw.PerfectLuckBonus), 1e-9))
		local product = 1
		for _, line in Luck.breakdown(C, s) do
			product *= line.mult
		end
		assert(Support.near(product, total, 1e-9), "the breakdown must multiply to the total")
	end,

	["friend luck is capped"] = function()
		local s = table.clone(BASE)
		s.friends = 50
		assert(Support.near(Luck.total(C, s), 1 + C.Luck.FriendBonusMax, 1e-9))
	end,
}
