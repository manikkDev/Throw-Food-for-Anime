--!strict
local Support = require("./Support")
local Collection = require("../src/shared/Core/Collection")
local Schema = require("../src/shared/Core/Schema")

local C = Support.Config
local M = Support.Maps
local ZONE1 = M.zoneCharacters[C.Zones[1].Id]

return {
	["a hero is new exactly once"] = function()
		local index = {}
		assert(Collection.discover(index, "a", nil, nil) == true)
		assert(Collection.discover(index, "a", "Golden", "Big") == false)
		assert(index.a.muts.Golden and index.a.sizes.Big, "variants are still recorded")
	end,

	["a zone completes only when every hero in it is found"] = function()
		local index = {}
		for i, character in ZONE1 do
			assert(Collection.completedZones(C, M, index) == 0, "completed early")
			Collection.discover(index, character.Id, nil, nil)
			local have, total = Collection.zoneProgress(index, ZONE1)
			assert(have == i and total == #ZONE1)
		end
		assert(Collection.completedZones(C, M, index) == 1)
	end,

	["the first daily claim starts a streak of one"] = function()
		local state = Collection.dailyState({ day = 0, streak = 0 }, 20000)
		assert(state.canClaim and state.streak == 1 and state.dayIndex == 1)
	end,

	["claiming the next day extends the streak, the same day is refused"] = function()
		local daily = { day = 20000, streak = 3 }
		assert(not Collection.dailyState(daily, 20000).canClaim)
		local nextDay = Collection.dailyState(daily, 20001)
		assert(nextDay.canClaim and nextDay.streak == 4 and nextDay.dayIndex == 4)
	end,

	["a missed day restarts the streak"] = function()
		local state = Collection.dailyState({ day = 20000, streak = 6 }, 20002)
		assert(state.canClaim and state.streak == 1)
	end,

	["day eight wraps back to the first tile"] = function()
		local state = Collection.dailyState({ day = 20000, streak = 7 }, 20001)
		assert(state.streak == 8 and state.dayIndex == 1)
	end,

	["the day changes at UTC midnight"] = function()
		assert(Collection.dayOf(86399) == 0 and Collection.dayOf(86400) == 1)
	end,

	["lucky throws arrive on the promised streak days"] = function()
		for day, amount in C.Rewards.DailyLuckyThrowsOnDay do
			assert(Collection.dailyReward(C, tonumber(day) :: number).luckyThrows == amount)
		end
		assert(Collection.dailyReward(C, 1).luckyThrows == 0)
		assert(Collection.dailyReward(C, 1).yenMinutes > 0)
	end,

	["a playtime gift needs the time, and only pays once a day"] = function()
		local gifts = { day = 0, claimed = {} }
		local minutes = C.Rewards.PlaytimeMinutes[1]
		assert(not Collection.giftClaimable(C, gifts, 500, minutes * 60 - 1, 1))
		assert(Collection.giftClaimable(C, gifts, 500, minutes * 60, 1))
		Collection.claimGift(gifts, 500, 1)
		assert(not Collection.giftClaimable(C, gifts, 500, 99999, 1), "claimed twice in a day")
		assert(Collection.giftClaimable(C, gifts, 501, 99999, 1), "a new day resets it")
		assert(not Collection.giftClaimable(C, gifts, 500, 99999, 99), "no such gift")
	end,

	["a code redeems once and ignores case and spaces"] = function()
		local codes = { WELCOME = { luckyThrows = 3 } }
		local redeemed = {}
		assert(Collection.canRedeem(codes, redeemed, " welcome "))
		redeemed[Collection.codeKey("welcome")] = true
		assert(not Collection.canRedeem(codes, redeemed, "WELCOME"))
		assert(not Collection.canRedeem(codes, redeemed, "nope"))
	end,

	["the same receipt is granted once and the ledger stays bounded"] = function()
		local receipts = {}
		assert(not Collection.receiptSeen(receipts, "p1"))
		Collection.recordReceipt(receipts, "p1", 3)
		assert(Collection.receiptSeen(receipts, "p1"))
		for i = 2, 5 do
			Collection.recordReceipt(receipts, "p" .. i, 3)
		end
		assert(#receipts == 3 and receipts[3] == "p5")
	end,

	["a new profile starts with the starter food and an empty plot"] = function()
		local p = Schema.default(C)
		assert(p.food == C.Foods[1].Id and p.foods[p.food])
		assert(p.slots == C.Plot.StartSlots and next(p.heroes) == nil)
		assert(p.power == C.Training.StartPower and p.v == Schema.VERSION)
	end,

	["an old save gains new fields and keeps its data"] = function()
		local old =
			{ yen = 5000, heroes = { h1 = { id = "x", slot = 1 } }, settings = { music = 0 } }
		local p = Schema.upgrade(old, C)
		assert(p.yen == 5000 and p.heroes.h1.id == "x", "data was lost")
		assert(p.heroes.h1.stars == 0, "missing hero fields are filled")
		assert(p.settings.music == 0 and p.settings.sfx ~= nil, "settings merge, not replace")
		assert(p.luckyThrows == 0 and p.v == Schema.VERSION)
	end,

	["garbage loads as a fresh profile, not an error"] = function()
		local p = Schema.upgrade("corrupt" :: any, C)
		assert(p.v == Schema.VERSION and p.yen == 0)
	end,

	["a hero in a slot the player no longer has is benched"] = function()
		local p =
			Schema.upgrade({ slots = 8, heroes = { h1 = { id = "x", slot = 20, stars = 0 } } }, C)
		assert(p.heroes.h1.slot == 0)
	end,

	["hero uids never repeat"] = function()
		local p = Schema.default(C)
		local a = Schema.newHero(p, "x", nil, nil)
		local b = Schema.newHero(p, "x", "Golden", nil)
		assert(a ~= b and p.heroes[a] ~= nil and p.heroes[b].mut == "Golden")
	end,
}
