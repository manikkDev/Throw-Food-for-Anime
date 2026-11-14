--!strict
-- StateService - the one place a player's state leaves the server.
--
-- Services change the profile table, then call :MarkDirty(player). A flush a
-- few times a second sends ONE snapshot per dirty player, however many
-- services touched it. Yen and Power change every second, so they travel on
-- the lighter StateTick instead.
--
-- It also answers the two questions several services ask about a player:
-- "what multiplies their income" and "what are their luck sources", so those
-- are computed in one place from the same inputs the client is shown.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Collection = require(ReplicatedStorage.Shared.Core.Collection)
local Income = require(ReplicatedStorage.Shared.Core.Income)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local Luck = require(ReplicatedStorage.Shared.Core.Luck)
local Guard = require(script.Parent.Parent.Logic.Guard)

local MAPS = Lookup.of(Config)
local FLUSH_SECONDS = 0.15

-- Profile fields the client never needs.
local PRIVATE = {
	receipts = true,
	grantedPasses = true,
	lastSeen = true,
	away = true, -- sent as view.offline
	v = true,
	nextUid = true,
}

-- Onboarding funnel step names, in order (TutorialController drives them).
local TUTORIAL_STEPS = {
	"OnThrowPad",
	"FirstCatch",
	"ThreeCatches",
	"BoughtSecondFood",
	"Trained",
	"ReachedZoneTwo",
}

-- Settings a client may change, and the type each must be.
local SETTINGS: { [string]: string } = {
	music = "number",
	sfx = "number",
	fastReveal = "boolean",
	lowDetail = "boolean",
	hideOthers = "boolean",
	autoSellCommon = "boolean",
	autoSellUncommon = "boolean",
}

local StateService = Knit.CreateService({
	Name = "StateService",
	_clientReady = {} :: { [Player]: boolean },
	_dirty = {} :: { [Player]: boolean },
	_joinedAt = {} :: { [Player]: number },
	_friends = {} :: { [Player]: number },
})

function StateService:KnitInit()
	self._snapshot = Net.server("StateSnapshot")
	self._tick = Net.server("StateTick")
	self._toast = Net.server("Toast")
	self._clientReadyRemote = Net.server("ClientReady")
	self._settingSet = Net.server("SettingSet")
end

--- Ask for a fresh snapshot to be sent to `player` on the next flush.
function StateService:MarkDirty(player: Player)
	self._dirty[player] = true
end

--- A short notice on the player's screen. kind: "good" | "bad" | "info".
function StateService:Toast(player: Player, text: string, kind: string?)
	self._toast:FireClient(player, text, kind or "info")
end

--- Seconds since this player's profile loaded in this server.
function StateService:SessionSeconds(player: Player): number
	local joined = self._joinedAt[player]
	return if joined then os.clock() - joined else 0
end

--- What multiplies this player's whole plot.
function StateService:IncomeMods(player: Player): Income.Mods
	local profile = self._data:Get(player)
	local timed = profile ~= nil and profile.doubleYenUntil > os.time()
	return {
		doubleYen = self._store:Has(player, "DoubleYen") or timed,
		rebirthTier = if profile then profile.rebirth else 0,
		eventMult = 1,
	}
end

--- Yen per second for this player right now.
function StateService:Income(player: Player): number
	local profile = self._data:Get(player)
	if not profile then
		return 0
	end
	return Income.player(Config, MAPS, profile.heroes, self:IncomeMods(player))
end

--- Luck sources that do not depend on a particular throw. The caller fills
--- foodLuck, depth, perfect and luckyThrow.
function StateService:LuckSources(player: Player): Luck.Sources
	local profile = self._data:Get(player)
	local index = if profile then profile.index else {}
	local streak = if profile then profile.daily.streak else 0
	return {
		foodLuck = 1,
		depth = 0,
		perfect = false,
		serverMult = self._events:ServerLuck(),
		friends = self._friends[player] or 0,
		vip = self._store:Has(player, "Vip"),
		luckyAura = self._store:Has(player, "LuckyAura"),
		zonesCompleted = Collection.completedZones(Config, MAPS, index),
		rebirthTier = if profile then profile.rebirth else 0,
		streakBonus = Luck.streakBonus(Config, streak),
		luckyThrow = false,
	}
end

function StateService:_view(player: Player, profile: any): any
	local view = {}
	for key, value in profile do
		if not PRIVATE[key] then
			view[key] = value
		end
	end
	view.passes = self._store:Passes(player)
	view.plot = self._plots:IndexOf(player)
	view.income = self:Income(player)
	view.luck = self:LuckSources(player)
	view.offline = self._economy:PendingOffline(player)
	view.benchSlots = self._squad:BenchSlots(player)
	view.training = self._training:IsTraining(player)
	view.randomRestricted = self._store:RandomItemsRestricted(player)
	view.sessionSeconds = self:SessionSeconds(player)
	view.serverNow = workspace:GetServerTimeNow()
	view.unixNow = os.time()
	view.mock = self._data:IsMock()
	view.admin = table.find(Config.Server.AdminUserIds, player.UserId) ~= nil
	view.studio = RunService:IsStudio()
	return view
end

function StateService:_send(player: Player)
	local profile = self._data:Get(player)
	if not profile or not self._clientReady[player] then
		return
	end
	self._snapshot:FireClient(player, self:_view(player, profile))
end

--- Send Yen and Power now (called by the income tick and by training).
function StateService:Tick(player: Player)
	local profile = self._data:Get(player)
	if profile and self._clientReady[player] then
		self._tick:FireClient(player, profile.yen, profile.power, workspace:GetServerTimeNow())
	end
end

function StateService:_countFriends(player: Player, leaver: Player?)
	local count = 0
	for _, other in Players:GetPlayers() do
		-- a player who is leaving is still in the list while PlayerRemoving runs
		if other ~= player and other ~= leaver then
			local ok, isFriend = pcall(function()
				return player:IsFriendsWithAsync(other.UserId)
			end)
			if ok and isFriend then
				count += 1
			end
		end
	end
	-- the check above yields: the player may have left meanwhile, and writing
	-- now would bring their entry back for good
	if self._data:Get(player) and self._friends[player] ~= count then
		self._friends[player] = count
		self:MarkDirty(player)
	end
end

function StateService:KnitStart()
	self._data = Knit.GetService("DataService")
	self._store = Knit.GetService("StoreService")
	self._events = Knit.GetService("EventService")
	self._plots = Knit.GetService("PlotService")
	self._economy = Knit.GetService("EconomyService")
	self._squad = Knit.GetService("SquadService")
	self._training = Knit.GetService("TrainingService")
	self._telemetry = Knit.GetService("TelemetryService")

	self._data:OnLoaded(function(player: Player)
		self._joinedAt[player] = os.clock()
		self._friends[player] = 0
	end)
	self._data:OnReady(function(player: Player)
		self:MarkDirty(player)
		-- friend luck changes for everyone when someone joins
		for _, other in Players:GetPlayers() do
			task.spawn(function()
				self:_countFriends(other)
			end)
		end
	end)
	self._data:OnReleasing(function(player: Player)
		self._clientReady[player] = nil
		self._dirty[player] = nil
		self._joinedAt[player] = nil
		self._friends[player] = nil
	end)
	Players.PlayerRemoving:Connect(function(leaver: Player)
		-- ClientReady can arrive before the profile does; a player who never
		-- gets one is never "released"
		self._clientReady[leaver] = nil
		for _, other in Players:GetPlayers() do
			if other ~= leaver then
				task.spawn(function()
					self:_countFriends(other, leaver)
				end)
			end
		end
	end)

	self._clientReadyRemote.OnServerEvent:Connect(function(player: Player)
		if not Guard.allow(player, "ClientReady", 0.2, 2) then
			return
		end
		self._clientReady[player] = true
		self:MarkDirty(player)
	end)

	self._settingSet.OnServerEvent:Connect(function(player: Player, key: unknown, value: unknown)
		if not Guard.allow(player, "SettingSet", 5, 10) then
			return
		end
		local profile = self._data:Get(player)
		if not profile or typeof(key) ~= "string" then
			return
		end
		if key == "tutorial" then
			-- the tutorial only ever moves forward
			if
				Guard.integer(value, 0, #TUTORIAL_STEPS)
				and (value :: number) > profile.tutorial
			then
				for step = profile.tutorial + 1, value :: number do
					self._telemetry:Funnel(player, step, TUTORIAL_STEPS[step])
				end
				profile.tutorial = value
				self:MarkDirty(player)
			end
			return
		end
		local wanted = SETTINGS[key]
		if not wanted or typeof(value) ~= wanted then
			return
		end
		if wanted == "number" then
			if not Guard.number(value) then
				return
			end
			value = math.clamp(value :: number, 0, 1)
		end
		profile.settings[key] = value
		self:MarkDirty(player)
	end)

	task.spawn(function()
		while true do
			task.wait(FLUSH_SECONDS)
			for player in table.clone(self._dirty) do
				self._dirty[player] = nil
				local ok, err = pcall(function()
					self:_send(player)
				end)
				if not ok then
					warn(`[StateService] snapshot failed for {player.Name}: {err}`)
				end
			end
		end
	end)
end

return StateService
