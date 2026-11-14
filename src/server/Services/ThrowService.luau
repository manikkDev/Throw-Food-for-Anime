--!strict
-- ThrowService - the core verb. A client says "I threw at this charge"; the
-- server decides everything else: whether the throw is allowed, which zone it
-- lands in, the luck, the roll, and the grant.
--
-- What the server trusts from the client: the charge value, inside
-- [MinCharge, 1]. A cheater can therefore always send a perfect charge, which
-- is worth PerfectLuckBonus and nothing more. Everything of value (zone,
-- rarity, mutation, size, placement) is computed here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local Luck = require(ReplicatedStorage.Shared.Core.Luck)
local Roll = require(ReplicatedStorage.Shared.Core.Roll)
local Throw = require(ReplicatedStorage.Shared.Core.Throw)
local World = require(ReplicatedStorage.Shared.Core.World)
local Guard = require(script.Parent.Parent.Logic.Guard)

local MAPS = Lookup.of(Config)
local T = Config.Throw
local COUNT = Config.Server.PlotCount
-- seconds between the food landing and the hero reaching its pedestal, on top
-- of the rarity's reveal time
local LAND_PAUSE = T.LandPauseSeconds
local DASH_SECONDS = T.DashSeconds

local ThrowService = Knit.CreateService({
	Name = "ThrowService",
	_last = {} :: { [Player]: number },
	_random = Random.new(),
})

function ThrowService:KnitInit()
	self._request = Net.server("ThrowRequest")
	self._result = Net.server("ThrowResult")
	self._seen = Net.server("ThrowSeen")
end

function ThrowService:_refuse(player: Player, why: string)
	if workspace:GetAttribute("TFADebug") then
		print(`[ThrowService] refused {player.Name}: {why}`)
	end
end

-- The very first throw of a new player is a guaranteed good catch from the
-- first zone, so the tutorial's first reveal is never a let-down.
function ThrowService:_firstCatch(zoneCharacters: { any }, luck: number): Roll.Result?
	local rows = Roll.heroWeights(Config, zoneCharacters, luck, nil)
	for _, row in rows do
		if row.rarity == T.FirstThrowRarity then
			return {
				id = row.id,
				rarity = row.rarity,
				mutation = nil,
				size = nil,
				pHero = row.chance,
				pMutation = 1,
				pSize = 1,
				oneInN = 1 / math.max(row.chance, 1e-9),
			}
		end
	end
	return nil
end

function ThrowService:_handle(player: Player, charge: unknown, lucky: unknown)
	local profile = self._data:Get(player)
	local index = self._plots:IndexOf(player)
	if not profile or not index then
		return self:_refuse(player, "no profile or plot")
	end
	if not Throw.validCharge(T, charge) then
		return self:_refuse(player, "bad charge")
	end
	local now = os.clock()
	local last = self._last[player]
	if last and now - last < T.ServerCooldownSeconds then
		return self:_refuse(player, "cooldown")
	end
	if not self._plots:OnThrowPad(player) then
		return self:_refuse(player, "not on own throw pad")
	end
	local food = MAPS.food[profile.food]
	if not food or not profile.foods[profile.food] then
		return self:_refuse(player, "equipped food not owned")
	end
	self._last[player] = now
	self._training:Stop(player)

	local useLucky = lucky == true and profile.luckyThrows > 0
	local eff = Throw.effectivePower(profile.power, food.PowerMult, charge :: number)
	local zoneIndex = Throw.zoneIndex(Config.Zones, eff)
	local zone = Config.Zones[zoneIndex]
	local depth = Throw.depth(Config.Zones, zoneIndex, eff)
	local perfect = Throw.isPerfect(T, charge :: number)

	local sources = self._state:LuckSources(player)
	sources.foodLuck = food.Luck
	sources.depth = depth
	sources.perfect = perfect
	sources.luckyThrow = useLucky
	local luck = Luck.total(Config, sources)

	local zoneCharacters = MAPS.zoneCharacters[zone.Id]
	local firstEver = profile.stats.caught == 0
	local result: Roll.Result? = nil
	if firstEver then
		result = self:_firstCatch(MAPS.zoneCharacters[Config.Zones[1].Id], luck)
	end
	if not result then
		result = Roll.throw(Config, zoneCharacters, luck, food.Flavor, function(): number
			return self._random:NextNumber()
		end, self._events:MutationMult())
	end
	local roll = result :: Roll.Result
	if useLucky then
		profile.luckyThrows -= 1
	end

	local flight = Throw.flightSeconds(T, zoneIndex, #Config.Zones)
	local reveal = Config.Rarities[roll.rarity].RevealSeconds
	if profile.settings.fastReveal then
		reveal *= 0.5
	end
	local arriveIn = flight + LAND_PAUSE + reveal + DASH_SECONDS

	local grant = self._squad:Grant(player, roll.id, roll.mutation, roll.size, arriveIn)
	if not grant then
		return
	end
	profile.stats.caught += 1
	if roll.oneInN > profile.stats.rarestOneIn then
		profile.stats.rarestOneIn = roll.oneInN
		profile.stats.rarestId = roll.id
	end
	self._state:MarkDirty(player)

	local x = World.landingX(Config.World, index, COUNT, self._random:NextNumber(-1, 1))
	local z = Throw.landingZ(Config.World, Config.Zones, zoneIndex, depth)
	self._result:FireClient(player, {
		zone = zoneIndex,
		x = x,
		z = z,
		flight = flight,
		reveal = reveal,
		id = roll.id,
		rarity = roll.rarity,
		mut = roll.mutation,
		size = roll.size,
		oneInN = roll.oneInN,
		luck = luck,
		perfect = perfect,
		lucky = useLucky,
		isNew = grant.isNew,
		isBest = grant.isBest,
		action = grant.action,
		slot = grant.slot,
		uid = grant.uid,
		income = grant.income,
		soldYen = grant.soldYen,
		flavorMatch = MAPS.character[roll.id].Craves == food.Flavor,
	})
	local seen = {
		plot = index,
		x = x,
		z = z,
		flight = flight,
		reveal = reveal,
		id = roll.id,
		rarity = roll.rarity,
		mut = roll.mutation,
		size = roll.size,
		food = food.Id,
	}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			self._seen:FireClient(other, seen)
		end
	end
	self._events:CatchAnnounce(player, roll, arriveIn - DASH_SECONDS)
	self._telemetry:Throw(player, zone.Id, roll.rarity, luck, firstEver)
end

function ThrowService:KnitStart()
	self._data = Knit.GetService("DataService")
	self._state = Knit.GetService("StateService")
	self._plots = Knit.GetService("PlotService")
	self._squad = Knit.GetService("SquadService")
	self._training = Knit.GetService("TrainingService")
	self._events = Knit.GetService("EventService")
	self._telemetry = Knit.GetService("TelemetryService")

	self._request.OnServerEvent:Connect(function(player: Player, charge: unknown, lucky: unknown)
		if not Guard.allow(player, "ThrowRequest", 2, 3) then
			return
		end
		self:_handle(player, charge, lucky)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		self._last[player] = nil
	end)
end

return ThrowService
