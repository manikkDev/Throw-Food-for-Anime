--!strict
-- ProgressService - the long game: Hero Index zone rewards and rebirth.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Collection = require(ReplicatedStorage.Shared.Core.Collection)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local Progress = require(ReplicatedStorage.Shared.Core.Progress)
local Guard = require(script.Parent.Parent.Logic.Guard)

local MAPS = Lookup.of(Config)

local ProgressService = Knit.CreateService({
	Name = "ProgressService",
})

function ProgressService:KnitInit()
	self._action = Net.server("ProgressAction")
end

--- Claim the reward for a completed zone. Returns true if it paid.
function ProgressService:ClaimZone(player: Player, zoneId: string): boolean
	local profile = self._data:Get(player)
	local zone = MAPS.zone[zoneId]
	if not profile or not zone or profile.zonesClaimed[zoneId] then
		return false
	end
	local have, total = Collection.zoneProgress(profile.index, MAPS.zoneCharacters[zoneId])
	if total == 0 or have < total then
		return false
	end
	profile.zonesClaimed[zoneId] = true
	local amount = self._economy:MinutesOfIncome(player, Config.Rewards.IndexZoneYenMinutes)
	self._economy:Add(player, amount, "index")
	self._state:MarkDirty(player)
	self._state:Toast(player, `{zone.Name} complete! +{Format.short(amount)} yen`, "good")
	return true
end

--- Claim every completed zone that has not been claimed (the index board prompt).
function ProgressService:ClaimAllZones(player: Player)
	local any = false
	for _, zone in Config.Zones do
		if self:ClaimZone(player, zone.Id) then
			any = true
		end
	end
	if not any then
		local profile = self._data:Get(player)
		local have, total = 0, 0
		if profile then
			have, total = Collection.total(Config, profile.index)
		end
		self._state:Toast(player, `Index {have}/{total}. Complete a zone for a reward`, "info")
	end
end

--- Rebirth if the requirements are met.
function ProgressService:Rebirth(player: Player)
	local profile = self._data:Get(player)
	if not profile then
		return
	end
	local nextTier = Progress.nextRebirth(Config, profile.rebirth)
	if not nextTier then
		self._state:Toast(player, "You are at the highest rebirth", "info")
		return
	end
	if not Progress.canRebirth(Config, profile.rebirth, profile.power, profile.yen) then
		self._state:Toast(
			player,
			`Rebirth needs {Format.short(nextTier.PowerReq)} power`
				.. ` and {Format.short(nextTier.YenCost)} yen`,
			"bad"
		)
		return
	end
	self._training:Stop(player)
	self._telemetry:Economy(player, "sink", "rebirth", nextTier.YenCost, 0)
	Progress.applyRebirth(Config, MAPS, profile)
	self._plots:Refresh(player)
	self._state:MarkDirty(player)
	self._state:Tick(player)
	self._telemetry:Custom(player, "Rebirth", profile.rebirth)
	self._events:Announce("rebirth", {
		text = `{player.DisplayName} reached REBIRTH {profile.rebirth}!`,
	})
end

function ProgressService:KnitStart()
	self._data = Knit.GetService("DataService")
	self._state = Knit.GetService("StateService")
	self._economy = Knit.GetService("EconomyService")
	self._plots = Knit.GetService("PlotService")
	self._training = Knit.GetService("TrainingService")
	self._events = Knit.GetService("EventService")
	self._telemetry = Knit.GetService("TelemetryService")

	self._action.OnServerEvent:Connect(function(player: Player, action: unknown, arg: unknown)
		if not Guard.allow(player, "ProgressAction", 2, 4) then
			return
		end
		if action == "claimZone" and Guard.text(arg, 40) then
			self:ClaimZone(player, arg :: string)
		elseif action == "claimAll" then
			self:ClaimAllZones(player)
		elseif action == "rebirth" then
			self:Rebirth(player)
		end
	end)
end

return ProgressService
