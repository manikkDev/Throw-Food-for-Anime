--!strict
-- EconomyService - Yen: the income tick, earning, spending and offline pay.
--
-- Money is automatic: every hero on a slot pays each second, nothing has to be
-- walked to or collected. This service is the only code that changes
-- profile.yen, so every source and sink passes through :Add or :Spend.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Progress = require(ReplicatedStorage.Shared.Core.Progress)

local TICK = Config.Server.IncomeTickSeconds

local EconomyService = Knit.CreateService({
	Name = "EconomyService",
})

--- Give Yen. Counts toward lifetime earnings (the Top Yen board).
function EconomyService:Add(player: Player, amount: number, reason: string)
	local profile = self._data:Get(player)
	if not profile or amount <= 0 or amount ~= amount then
		return
	end
	profile.yen += amount
	profile.yenLifetime += amount
	self._telemetry:Economy(player, "source", reason, amount, profile.yen)
	self._state:Tick(player)
end

--- Take Yen if the player has it. Returns false (and takes nothing) if not.
function EconomyService:Spend(player: Player, amount: number, reason: string): boolean
	local profile = self._data:Get(player)
	if not profile or amount < 0 or amount ~= amount or profile.yen < amount then
		return false
	end
	profile.yen -= amount
	self._telemetry:Economy(player, "sink", reason, amount, profile.yen)
	self._state:Tick(player)
	return true
end

--- Yen worth `minutes` of this player's current income. Rewards and Yen packs
--- are priced this way so they never go stale. Has a floor so a brand-new
--- player with an empty plot still gets something.
function EconomyService:MinutesOfIncome(player: Player, minutes: number): number
	local income = math.max(self._state:Income(player), Config.Zones[1].BaseIncome * 5)
	return math.floor(income * minutes * 60)
end

--- Offline earnings waiting to be claimed, or nil. They live in the profile
--- (profile.away), so they survive leaving without claiming.
function EconomyService:PendingOffline(player: Player): { amount: number, seconds: number }?
	local profile = self._data:Get(player)
	if not profile or profile.away.yen <= 0 then
		return nil
	end
	return { amount = profile.away.yen, seconds = profile.away.seconds }
end

--- Bank what this player's heroes earned over `secondsAway` seconds away.
function EconomyService:BankAway(player: Player, secondsAway: number)
	local profile = self._data:Get(player)
	if not profile then
		return
	end
	local amount, seconds = Progress.offline(Config, secondsAway, self._state:Income(player))
	if amount > 0 then
		local away = profile.away
		away.yen += amount
		away.seconds = math.min(away.seconds + seconds, Config.Offline.CapHours * 3600)
		self._state:MarkDirty(player)
	end
end

--- Pay out the offline earnings, times `mult` (2 with the OfflineDouble product).
function EconomyService:ClaimOffline(player: Player, mult: number): number
	local profile = self._data:Get(player)
	if not profile or profile.away.yen <= 0 then
		return 0
	end
	local amount = profile.away.yen * mult
	profile.away = { yen = 0, seconds = 0 }
	self:Add(player, amount, "offline")
	self._state:MarkDirty(player)
	return amount
end

function EconomyService:KnitStart()
	self._data = Knit.GetService("DataService")
	self._state = Knit.GetService("StateService")
	self._telemetry = Knit.GetService("TelemetryService")

	-- OnReady, not OnLoaded: pass ownership (2x Yen) must be known first
	self._data:OnReady(function(player: Player, profile: any)
		if profile.lastSeen > 0 then
			self:BankAway(player, os.time() - profile.lastSeen)
		end
		-- stamped as soon as the time away is banked, and kept current by the
		-- tick below: the same hours can never be paid twice, and a server
		-- crash does not turn play time into "time away"
		profile.lastSeen = os.time()
	end)
	self._data:OnReleasing(function(_player: Player, profile: any)
		profile.lastSeen = os.time()
	end)

	task.spawn(function()
		while true do
			local dt = task.wait(TICK)
			for player, profile in self._data:All() do
				local income = self._state:Income(player)
				profile.lastSeen = os.time()
				if income > 0 then
					local amount = income * dt
					profile.yen += amount
					profile.yenLifetime += amount
				end
				self._state:Tick(player)
			end
		end
	end)
end

return EconomyService
