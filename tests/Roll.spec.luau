--!strict
local Support = require("./Support")
local Roll = require("../src/shared/Core/Roll")

local C = Support.Config
local M = Support.Maps

local function zoneOf(index: number): { any }
	return M.zoneCharacters[C.Zones[index].Id]
end

local function holds(zone: { any }, rarity: string): boolean
	for _, character in zone do
		if character.Rarity == rarity then
			return true
		end
	end
	return false
end

-- the first zone that holds every rarity from Common to Mythic and no Secret
local FULL: { any }
for index in C.Zones do
	local zone = zoneOf(index)
	if holds(zone, "Mythic") and holds(zone, "Common") and not holds(zone, "Secret") then
		FULL = zone
		break
	end
end

local function sum(chances: { [string]: number }): number
	local total = 0
	for _, p in chances do
		total += p
	end
	return total
end

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-9
end

return {
	["every zone has heroes and its chances sum to one at any luck"] = function()
		for index, zone in C.Zones do
			local heroes = zoneOf(index)
			assert(#heroes >= 5, `{zone.Name} has only {#heroes} heroes`)
			for _, luck in { 1, 3, 20, 150, C.Luck.Max } do
				local total = sum(Roll.rarityChances(C, heroes, luck, nil))
				assert(near(total, 1), `{zone.Name} at luck {luck} sums to {total}`)
				local rows = Roll.heroWeights(C, heroes, luck, nil)
				local rowTotal = 0
				for _, row in rows do
					rowTotal += row.chance
				end
				assert(near(rowTotal, 1), `{zone.Name} heroes at luck {luck} sum to {rowTotal}`)
			end
		end
	end,

	["base odds are the stated one-in-N"] = function()
		local chances = Roll.rarityChances(C, FULL, 1, nil)
		for _, name in { "Rare", "Epic", "Legendary", "Mythic" } do
			assert(near(chances[name], 1 / C.Rarities[name].OneIn), `{name} at luck 1`)
		end
		-- what the bands leave is split between Uncommon and Common
		local left = 1 - chances.Rare - chances.Epic - chances.Legendary - chances.Mythic
		assert(near(chances.Uncommon, left * C.Roll.UncommonShare))
		assert(near(chances.Common, left * (1 - C.Roll.UncommonShare)))
	end,

	["the roll uses the same closed form as the pacing simulator"] = function()
		-- tools/economy/econ_v2.py `rarity_chances`: bands rarest first,
		--   p = min(left, luck ^ LuckPower / OneIn); the last band (Rare) leaves
		--   CommonFloor; Uncommon takes UncommonShare of what is left.
		-- At luck 20 in a zone holding Common..Mythic that is exactly:
		local chances = Roll.rarityChances(C, FULL, 20, nil)
		assert(near(chances.Mythic, 20 / 10000))
		assert(near(chances.Legendary, 20 / 400))
		assert(near(chances.Epic, 20 / 50))
		local left = 1 - 0.002 - 0.05 - 0.4
		assert(near(chances.Rare, left - C.Roll.CommonFloor), "Rare is cut to leave the floor")
		assert(near(chances.Uncommon, C.Roll.CommonFloor * C.Roll.UncommonShare))
		assert(near(chances.Common, C.Roll.CommonFloor * (1 - C.Roll.UncommonShare)))
	end,

	["luck divides the one-in-N of Epic and above"] = function()
		for _, luck in { 2, 4, 8 } do
			local chances = Roll.rarityChances(C, FULL, luck, nil)
			for _, name in { "Epic", "Legendary", "Mythic" } do
				assert(near(chances[name], luck / C.Rarities[name].OneIn), `{name} at luck {luck}`)
			end
		end
	end,

	["luck never stops helping the top of the table"] = function()
		-- the old weights froze a Mythic at 1 in 611 past luck 10
		local before = 0
		for _, luck in { 1, 5, 10, 20, 50, 200, 1000 } do
			local p = Roll.rarityChances(C, FULL, luck, nil).Mythic
			assert(p > before, `Mythic did not grow at luck {luck}`)
			before = p
		end
	end,

	["luck never lowers the chance of this rarity or rarer"] = function()
		local order = { "Mythic", "Legendary", "Epic", "Rare", "Uncommon" }
		for index in C.Zones do
			local heroes = zoneOf(index)
			local previous: { [string]: number } = {}
			for _, luck in { 1, 1.5, 3, 6, 12, 25, 60, 300, 1000 } do
				local chances = Roll.rarityChances(C, heroes, luck, nil)
				local acc = chances.Secret or 0
				for _, name in order do
					acc += chances[name] or 0
					assert(
						acc >= (previous[name] or 0) - 1e-9,
						`zone {index}: "{name} or rarer" fell at luck {luck}`
					)
					previous[name] = acc
				end
			end
		end
	end,

	["a Common stays catchable at the luck a free player can hold"] = function()
		-- free endgame luck is about 21 (plan 12, section 3.2)
		for index in C.Zones do
			local chances = Roll.rarityChances(C, zoneOf(index), 21, nil)
			assert(chances.Common > 0.05, `zone {index}: Common is {chances.Common} at luck 21`)
		end
	end,

	["heroes of one rarity share its chance equally"] = function()
		local chances = Roll.rarityChances(C, FULL, 3, nil)
		local count: { [string]: number } = {}
		for _, character in FULL do
			count[character.Rarity] = (count[character.Rarity] or 0) + 1
		end
		for _, row in Roll.heroWeights(C, FULL, 3, nil) do
			assert(near(row.chance, chances[row.rarity] / count[row.rarity]), row.id)
		end
	end,

	["a craving moves chance inside the rarity, never between rarities"] = function()
		local flavor = FULL[1].Favourite
		local plain = Roll.rarityChances(C, FULL, 3, nil)
		local byRarity: { [string]: number } = {}
		local craving, other: any = nil, nil
		for _, row in Roll.heroWeights(C, FULL, 3, flavor) do
			byRarity[row.rarity] = (byRarity[row.rarity] or 0) + row.chance
			if row.rarity == FULL[1].Rarity then
				if row.weight > 1 then
					craving = craving or row
				else
					other = other or row
				end
			end
		end
		for name, p in plain do
			assert(near(byRarity[name] or 0, p), `{name} changed with a craving`)
		end
		assert(craving ~= nil, "the first hero's favourite dish is the thrown food")
		if other then
			assert(near(craving.chance, other.chance * C.Throw.CravingWeightMult))
		end
	end,

	["adding a hero to a zone never changes its rarity odds"] = function()
		local grown = table.clone(FULL)
		local copy = table.clone(FULL[1])
		copy.Id = "an_extra_hero"
		table.insert(grown, copy)
		local a = Roll.rarityChances(C, FULL, 4, nil)
		local b = Roll.rarityChances(C, grown, 4, nil)
		for name, p in a do
			assert(near(p, b[name]), `{name} moved when a hero was added`)
		end
	end,

	["a zone only rolls the rarities it holds"] = function()
		local secrets = 0
		for index, zone in C.Zones do
			local heroes = zoneOf(index)
			local chances = Roll.rarityChances(C, heroes, 5, nil)
			for name in C.Rarities do
				if holds(heroes, name) then
					assert((chances[name] or 0) > 0, `{zone.Name} never gives its {name}`)
				else
					assert(chances[name] == nil, `{zone.Name} rolls a {name} it does not hold`)
				end
			end
			if holds(heroes, "Secret") then
				secrets += 1
				assert(near(chances.Secret, 5 / C.Rarities.Secret.OneIn))
			end
		end
		assert(secrets >= 1, "no zone holds a Secret")
	end,

	["a lucky throw is never below its floor"] = function()
		local floor = C.Throw.LuckyFloor
		local floorOrder = C.Rarities[floor].Order
		for index in C.Zones do
			local heroes = zoneOf(index)
			local chances = Roll.rarityChances(C, heroes, C.Throw.LuckyThrowLuck, floor)
			assert(near(sum(chances), 1))
			for name, p in chances do
				if C.Rarities[name].Order < floorOrder then
					assert(p == 0, `zone {index}: a lucky throw can give a {name}`)
				end
			end
			for _, row in Roll.heroWeights(C, heroes, C.Throw.LuckyThrowLuck, nil, floor) do
				if C.Rarities[row.rarity].Order < floorOrder then
					assert(row.chance == 0)
				end
			end
		end
	end,

	["the score is base odds: the same number at any luck"] = function()
		assert(near(Roll.score(C, M, FULL, "Mythic", nil, nil), C.Rarities.Mythic.OneIn))
		local full = Roll.score(C, M, FULL, "Mythic", "Galaxy", "Titan")
		local want = C.Rarities.Mythic.OneIn / M.mutation.Galaxy.Chance / M.size.Titan.Chance
		assert(Support.near(full, want, 1e-9), `Mythic Galaxy Titan scores {full}`)
		assert(full > 3e9, "the designed top score of a Mythic is over three billion")
		-- two players with very different luck catch the same thing
		local function catch(luck: number): Roll.Result
			local rng = Support.rng(7)
			for _ = 1, 20000 do
				local result = Roll.throw(C, M, FULL, luck, nil, rng)
				if
					result.rarity == "Legendary"
					and result.mutation == "Golden"
					and not result.size
				then
					return result
				end
			end
			error("no Golden Legendary in 20000 throws at luck " .. luck)
		end
		assert(catch(3).oneInN == catch(40).oneInN, "the score moved with luck")
	end,

	["stamps follow the score"] = function()
		assert(Roll.stamp(C, 50) == nil)
		assert(Roll.stamp(C, 100) == "LUCKY")
		assert(Roll.stamp(C, 833_333) == "SUPER LUCKY")
		assert(Roll.stamp(C, 1_000_000) == "INSANE LUCK")
		assert(Roll.stamp(C, 3.3e9) == "GODLY")
	end,

	["rolled rates match the stated chances over 100k throws"] = function()
		local luck = 3
		local want = Roll.rarityChances(C, FULL, luck, nil)
		local got: { [string]: number } = {}
		local mutated = 0
		local rng = Support.rng(20261126)
		local n = 100000
		for _ = 1, n do
			local result = Roll.throw(C, M, FULL, luck, nil, rng)
			got[result.rarity] = (got[result.rarity] or 0) + 1
			if result.mutation then
				mutated += 1
			end
		end
		for _, name in { "Common", "Uncommon", "Rare", "Epic" } do
			assert(
				Support.near((got[name] or 0) / n, want[name], 0.06),
				`{name}: rolled {(got[name] or 0) / n}, stated {want[name]}`
			)
		end
		assert(Support.near((got.Legendary or 0) / n, want.Legendary, 0.2), "Legendary rate")
		local anyMutation = 0
		for _, mutation in C.Mutations do
			anyMutation += mutation.Chance * (1 + (luck - 1) * (mutation.LuckScale or 0))
		end
		assert(Support.near(mutated / n, anyMutation, 0.06), "mutation rate")
	end,

	["a legendary in zone one is rare but reachable"] = function()
		local p = Roll.rarityChances(C, zoneOf(1), 1, nil).Legendary
		assert(p > 1 / 1000 and p < 1 / 100, `zone-one Legendary is 1 in {1 / p}`)
	end,
}
