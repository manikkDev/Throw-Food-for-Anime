--!strict
-- StateController - the client's copy of everything the server tells it.
--
-- No other controller listens to a state remote. They read .State, .Plots,
-- .Env here and subscribe to the signals, so "what does the client believe"
-- has exactly one answer. The client never changes this state itself: it asks
-- the server and waits for the next snapshot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Net = require(ReplicatedStorage.Shared.Net)

local StateController = Knit.CreateController({
	Name = "StateController",
	State = nil :: any, -- the last snapshot, or nil before the first one
	Plots = {} :: { [number]: any },
	Env = nil :: any,
	Boards = nil :: any,
	Changed = Signal.new(), -- (state)
	Ticked = Signal.new(), -- (yen, power)
	PlotChanged = Signal.new(), -- (index, plotState | nil)
	EnvChanged = Signal.new(), -- (env)
	BoardsChanged = Signal.new(), -- (boards)
})

--- Run `handler(state)` now if a snapshot exists, and on every later one.
function StateController:Observe(handler: (any) -> ())
	self.Changed:Connect(handler)
	if self.State then
		task.spawn(handler, self.State)
	end
end

--- Run `handler(index, plotState)` for every plot known now and every change.
function StateController:ObservePlots(handler: (number, any) -> ())
	self.PlotChanged:Connect(handler)
	for index, plot in self.Plots do
		task.spawn(handler, index, plot)
	end
end

--- Server time, for anything timed against a server timestamp.
function StateController:ServerNow(): number
	return workspace:GetServerTimeNow()
end

function StateController:KnitStart()
	local snapshot = Net.client("StateSnapshot")
	local tick = Net.client("StateTick")
	local plotsSnapshot = Net.client("PlotsSnapshot")
	local plotUpdate = Net.client("PlotUpdate")
	local env = Net.client("EnvUpdate")
	local boards = Net.client("Leaderboards")
	local ready = Net.client("ClientReady")
	if not (snapshot and tick and plotsSnapshot and plotUpdate and env and boards and ready) then
		warn("[StateController] state remotes missing: the HUD will stay empty")
		return
	end

	snapshot.OnClientEvent:Connect(function(state: any)
		self.State = state
		self.Changed:Fire(state)
	end)
	tick.OnClientEvent:Connect(function(yen: number, power: number)
		local state = self.State
		if state then
			state.yen = yen
			state.power = power
		end
		self.Ticked:Fire(yen, power)
	end)
	plotsSnapshot.OnClientEvent:Connect(function(all: { [string]: any })
		for key, plot in all do
			local index = tonumber(key)
			if index then
				self.Plots[index] = plot
				self.PlotChanged:Fire(index, plot)
			end
		end
	end)
	plotUpdate.OnClientEvent:Connect(function(index: number, plot: any)
		self.Plots[index] = plot
		self.PlotChanged:Fire(index, plot)
	end)
	env.OnClientEvent:Connect(function(state: any)
		self.Env = state
		self.EnvChanged:Fire(state)
	end)
	boards.OnClientEvent:Connect(function(data: any)
		self.Boards = data
		self.BoardsChanged:Fire(data)
	end)

	-- every controller has connected by the next frame: now ask for state
	task.defer(function()
		ready:FireServer()
	end)
end

return StateController
