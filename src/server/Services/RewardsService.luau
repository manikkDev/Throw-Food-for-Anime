--!strict
-- RewardsService - reasons to come back: the daily streak, playtime gifts,
-- codes and the offline claim. All timing is the SERVER's clock.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local ServerConfig = require(script.Parent.Parent.Config.ServerConfig)
local Collection = require(ReplicatedStorage.Shared.Core.Collection)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local Throw = require(ReplicatedStorage.Shared.Core.Throw)
local Guard = require(script.Parent.Parent.Logic.Guard)

local MAPS = Lookup.of(Config)
local R = Config.Rewards

local RewardsService = Knit.CreateService({
	Name = "RewardsService",
})

function RewardsService:KnitInit()
	self._claim = Net.server("RewardClaim")
end

local function today(): number
	return Collection.dayOf(os.time())
end

--- Claim today's streak reward.
function RewardsService:ClaimDaily(player: Player)
	local profile = self._data:Get(player)
	if not profile then
		return
	end
	local state = Collection.dailyState(profile.daily, today())
	if not state.canClaim then
		self._state:Toast(player, "Daily reward claimed. Come back tomorrow!", "info")
		return
	end
	profile.daily.day = today()
	profile.daily.streak = state.streak
	local reward = Collection.dailyReward(Config, state.dayIndex)
	local yen = self._economy:MinutesOfIncome(player, reward.yenMinutes)
	self._economy:Add(player, yen, "daily")
	profile.luckyThrows += reward.luckyThrows
	self._state:MarkDirty(player)
	local extra = if reward.luckyThrows > 0 then ` and {reward.luckyThrows} Lucky Throws` else ""
	self._state:Toast(player, `Day {state.streak}: +{Format.short(yen)} yen{extra}`, "good")
end

-- The first gift of the day is a guaranteed hero from the furthest zone the
-- player can reach right now.
function RewardsService:_giftHero(player: Player, profile: any)
	local food = MAPS.food[profile.food]
	local eff = Throw.effectivePower(profile.power, food.PowerMult, 1)
	local zone = Config.Zones[Throw.zoneIndex(Config.Zones, eff)]
	for _, character in MAPS.zoneCharacters[zone.Id] do
		if character.Rarity == R.PlaytimeFirstGiftRarity then
			self._squad:GrantAndShow(player, character.Id, nil, nil, "gift")
			return
		end
	end
end

--- Claim playtime gift `i`. Returns true if it paid.
function RewardsService:ClaimGift(player: Player, i: number): boolean
	local profile = self._data:Get(player)
	if not profile then
		return false
	end
	local seconds = self._state:SessionSeconds(player)
	if not Collection.giftClaimable(Config, profile.gifts, today(), seconds, i) then
		return false
	end
	Collection.claimGift(profile.gifts, today(), i)
	if i == 1 then
		self:_giftHero(player, profile)
		self._state:Toast(player, "Gift: a new hero joined you!", "good")
	else
		local yen = self._economy:MinutesOfIncome(player, R.PlaytimeMinutes[i] / 2)
		self._economy:Add(player, yen, "gift")
		local throws = if i % 3 == 0 then 1 else 0
		profile.luckyThrows += throws
		local extra = if throws > 0 then " and a Lucky Throw" else ""
		self._state:Toast(player, `Gift: +{Format.short(yen)} yen{extra}`, "good")
	end
	self._state:MarkDirty(player)
	return true
end

--- Claim the first gift that is ready, or say how long until the next one.
function RewardsService:ClaimNextGift(player: Player)
	local profile = self._data:Get(player)
	if not profile then
		return
	end
	local seconds = self._state:SessionSeconds(player)
	for i, minutes in R.PlaytimeMinutes do
		if self:ClaimGift(player, i) then
			return
		end
		local claimed = profile.gifts.day == today() and profile.gifts.claimed[tostring(i)]
		if not claimed then
			local left = minutes * 60 - seconds
			self._state:Toast(player, `Next gift in {Format.duration(left)}`, "info")
			return
		end
	end
	self._state:Toast(player, "All of today's gifts are claimed", "info")
end

--- Redeem a code.
function RewardsService:Redeem(player: Player, text: string)
	local profile = self._data:Get(player)
	if not profile then
		return
	end
	if not Collection.canRedeem(ServerConfig.Codes, profile.codes, text) then
		self._state:Toast(player, "That code is not valid or was already used", "bad")
		return
	end
	local key = Collection.codeKey(text)
	local reward = ServerConfig.Codes[key]
	profile.codes[key] = true
	if reward.LuckyThrows then
		profile.luckyThrows += reward.LuckyThrows
	end
	if reward.YenMinutes then
		local yen = self._economy:MinutesOfIncome(player, reward.YenMinutes)
		self._economy:Add(player, yen, "code")
	end
	self._state:MarkDirty(player)
	self._state:Toast(player, "Code redeemed!", "good")
end

function RewardsService:KnitStart()
	self._data = Knit.GetService("DataService")
	self._state = Knit.GetService("StateService")
	self._economy = Knit.GetService("EconomyService")
	self._squad = Knit.GetService("SquadService")

	self._claim.OnServerEvent:Connect(function(player: Player, kind: unknown, arg: unknown)
		if not Guard.allow(player, "RewardClaim", 2, 4) then
			return
		end
		if kind == "daily" then
			self:ClaimDaily(player)
		elseif kind == "gift" then
			if Guard.integer(arg, 1, #R.PlaytimeMinutes) then
				self:ClaimGift(player, arg :: number)
			else
				self:ClaimNextGift(player)
			end
		elseif kind == "code" then
			if Guard.text(arg, 32) then
				self:Redeem(player, arg :: string)
			end
		elseif kind == "offline" then
			local amount = self._economy:ClaimOffline(player, 1)
			if amount > 0 then
				self._state:Toast(player, `Welcome back! +{Format.short(amount)} yen`, "good")
			end
		end
	end)
end

return RewardsService
