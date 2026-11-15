--!strict
-- DailyRewards - the seven-day strip, the streak and the claim button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Collection = require(ReplicatedStorage.Shared.Core.Collection)
local Luck = require(ReplicatedStorage.Shared.Core.Luck)
local Screens = require(script.Parent.Parent.Screens)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Types)

local DAYS = 7 -- DayCell1..7 ship in the tree

local DailyRewards = { name = "DailyRewards" } :: Types.Page

local ctx: Types.Ctx
local gui: ScreenGui

function DailyRewards.render(state: any)
	local now = ctx.now()
	local today = Collection.dayOf(now)
	local daily = Collection.dailyState(state.daily, today)
	-- the streak the player HAS, not the one claiming now would make
	local streak = if daily.canClaim then daily.streak - 1 else daily.streak
	local bonus = math.floor(Luck.streakBonus(Config, streak) * 100 + 0.5)
	Screens.label(gui, "StreakLabel").Text = if streak <= 0
		then "CLAIM TO START A STREAK!"
		elseif bonus > 0 then `{streak} DAY STREAK!  +{bonus}% LUCK`
		else `{streak} DAY STREAK!`

	for day = 1, DAYS do
		local cell = Screens.frame(gui, "DayCell" .. day)
		local reward = Collection.dailyReward(Config, day)
		local claimed = day < daily.dayIndex or (day == daily.dayIndex and not daily.canClaim)
		Screens.label(cell, "RewardText").Text = `{reward.yenMinutes} min yen`
			.. (if reward.luckyThrows > 0 then ` +{reward.luckyThrows} Lucky` else "")
		Screens.image(cell, "ClaimedTick").Visible = claimed
		Screens.tint(
			cell,
			if claimed
				then Theme.DAY_CLAIMED
				elseif day == daily.dayIndex then Theme.DAY_TODAY
				else Theme.DAY_AHEAD
		)
	end

	local claim = Screens.button(gui, "ClaimButton")
	Screens.label(claim, "ClaimText").Text = if daily.canClaim
		then `CLAIM DAY {daily.dayIndex}`
		else "TOMORROW"
	Screens.setButtonState(
		claim,
		if daily.canClaim then "afford" else "off",
		nil,
		if daily.canClaim then "IconGift" else "IconTimer"
	)
	Screens.label(gui, "NextIn").Text = if daily.canClaim
		then "Ready now!"
		else `Next reward in {Screens.clock((today + 1) * 86400 - now)}`
end

DailyRewards.tick = DailyRewards.render

function DailyRewards.init(context: Types.Ctx)
	ctx = context
	gui = Screens.get("DailyRewards")
	for day = 1, DAYS do
		-- a day that gives Lucky Throws shows the throw, the others the coin
		local reward = Collection.dailyReward(Config, day)
		Screens.setIcon(
			Screens.image(Screens.frame(gui, "DayCell" .. day), "Icon"),
			if reward.luckyThrows > 0 then "IconLuckyThrow" else "IconYen"
		)
	end
	Screens.button(gui, "ClaimButton").Activated:Connect(function()
		ctx.fire("RewardClaim", "daily")
	end)
end

return DailyRewards
