--!strict
-- TrainingService - Power. A player starts a session on their dojo pad; the
-- server counts the reps on ITS clock and adds the Power. The client only
-- plays the animation: it cannot report reps or Power.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Progress = require(ReplicatedStorage.Shared.Core.Progress)
local Guard = require(script.Parent.Parent.Logic.Guard)

local REP = Config.Training.RepSeconds

local TrainingService = Knit.CreateService({
	Name = "TrainingService",
	_sessions = {} :: { [Player]: { last: number } },
})

function TrainingService:KnitInit()
	self._set = Net.server("TrainSet")
end

function TrainingService:IsTraining(player: Player): boolean
	return self._sessions[player] ~= nil
end

function TrainingService:Start(player: Player)
	if self._sessions[player] or not self._data:Get(player) then
		return
	end
	if not self._plots:OnDojoPad(player) then
		self._state:Toast(player, "Stand on your dojo pad to train", "info")
		return
	end
	self._sessions[player] = { last = os.clock() }
	self._state:MarkDirty(player)
end

function TrainingService:Stop(player: Player)
	if self._sessions[player] then
		self._sessions[player] = nil
		self._state:MarkDirty(player)
	end
end

function TrainingService:Toggle(player: Player)
	if self._sessions[player] then
		self:Stop(player)
	else
		self:Start(player)
	end
end

--- Add Power directly and announce a new rank if one was crossed.
function TrainingService:AddPower(player: Player, amount: number)
	local profile = self._data:Get(player)
	if not profile or amount <= 0 then
		return
	end
	local before = Progress.rank(Config, profile.power).index
	profile.power += amount
	local after = Progress.rank(Config, profile.power)
	if after.index > before then
		self._state:Toast(player, `New rank: {after.name}!`, "good")
		self._state:MarkDirty(player)
	end
	self._state:Tick(player)
end

--- The Power of `minutes` of training on the player's current gear (the
--- training-skip products).
function TrainingService:GrantMinutes(player: Player, minutes: number)
	local profile = self._data:Get(player)
	if not profile then
		return
	end
	local double = self._store:Has(player, "DoubleTraining")
	local reps = Progress.repsIn(Config, minutes * 60)
	self:AddPower(player, reps * Progress.powerPerRep(Config, profile.gear, double))
end

function TrainingService:KnitStart()
	self._data = Knit.GetService("DataService")
	self._state = Knit.GetService("StateService")
	self._plots = Knit.GetService("PlotService")
	self._store = Knit.GetService("StoreService")

	self._set.OnServerEvent:Connect(function(player: Player, on: unknown)
		if not Guard.allow(player, "TrainSet", 3, 6) then
			return
		end
		if on == true then
			self:Start(player)
		else
			self:Stop(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		self._sessions[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = os.clock()
			for player, session in table.clone(self._sessions) do
				local profile = self._data:Get(player)
				if not profile or not self._plots:OnDojoPad(player) then
					self:Stop(player)
					continue
				end
				local reps = math.floor((now - session.last) / REP)
				if reps > 0 then
					session.last += reps * REP
					local double = self._store:Has(player, "DoubleTraining")
					local perRep = Progress.powerPerRep(Config, profile.gear, double)
					self:AddPower(player, reps * perRep)
				end
			end
		end
	end)
end

return TrainingService
