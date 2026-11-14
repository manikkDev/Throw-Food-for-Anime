--!strict
-- TelemetryService - funnel, economy and custom analytics events.
--
-- Tuning the game is done from these numbers, not from opinion: where new
-- players stop in the first five minutes, where Yen comes from and goes, how
-- long each zone really takes. Every call is pcall-wrapped and sampled, so
-- analytics can never break or slow gameplay (and never hits Roblox's
-- per-minute event limit).

local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local STUDIO = RunService:IsStudio()

-- reason -> the transaction type Roblox's economy dashboard groups by
local TRANSACTION = {
	food = "Shop",
	gear = "Shop",
	slot = "Shop",
	rebirth = "Shop",
	offline = "TimedReward",
	daily = "TimedReward",
	gift = "TimedReward",
	index = "Gameplay",
	code = "Onboarding",
	yenpack = "IAP",
}

local TelemetryService = Knit.CreateService({
	Name = "TelemetryService",
	_throws = {} :: { [Player]: number },
})

local function safely(what: string, fn: () -> ())
	if STUDIO then
		return -- nothing useful to record from a Studio session
	end
	local ok, err = pcall(fn)
	if not ok then
		warn(`[Telemetry] {what} failed inert: {err}`)
	end
end

--- Onboarding step `step` (1..8, the tutorial beats) reached.
function TelemetryService:Funnel(player: Player, step: number, name: string)
	safely("funnel", function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)
	end)
end

--- Yen entering ("source") or leaving ("sink"). Selling is skipped: it fires
--- on most throws and says nothing the throw event does not.
function TelemetryService:Economy(
	player: Player,
	flow: string,
	reason: string,
	amount: number,
	balance: number
)
	local kind = TRANSACTION[reason]
	if not kind then
		return
	end
	safely("economy", function()
		AnalyticsService:LogEconomyEvent(
			player,
			if flow == "sink"
				then Enum.AnalyticsEconomyFlowType.Sink
				else Enum.AnalyticsEconomyFlowType.Source,
			"Yen",
			amount,
			balance,
			kind,
			reason
		)
	end)
end

--- One in four throws is recorded, plus every first throw.
function TelemetryService:Throw(
	player: Player,
	zoneId: string,
	rarity: string,
	luck: number,
	first: boolean
)
	local n = (self._throws[player] or 0) + 1
	self._throws[player] = n
	if not first and n % 4 ~= 0 then
		return
	end
	safely("throw", function()
		AnalyticsService:LogCustomEvent(player, "Throw", luck, {
			[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = zoneId,
			[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = rarity,
		})
	end)
end

--- Anything else worth a count: "Rebirth", "StoreOpen", "Purchase"...
function TelemetryService:Custom(player: Player, name: string, value: number?, detail: string?)
	safely(name, function()
		AnalyticsService:LogCustomEvent(player, name, value or 1, {
			[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = detail or "",
		})
	end)
end

function TelemetryService:KnitStart()
	game:GetService("Players").PlayerRemoving:Connect(function(player: Player)
		self._throws[player] = nil
	end)
end

return TelemetryService
