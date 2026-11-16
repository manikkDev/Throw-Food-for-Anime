--!strict
-- TrainingService - Power, from the four training stations on the player's own plot
-- (config Training.Stations: strike, lift, push, meditate; two mirrored courts).
--
-- A session belongs to ONE station:
--   * Start(player, i): the plot is theirs, the station is unlocked (gear tier >= Unlock). The
--     character is SNAPPED to the station's stand point facing the target, at contact distance,
--     and LOCKED there (root anchored, WalkSpeed 0, no jump) until Stop. The client cannot walk
--     off mid-rep or punch the air from across the court (owner's review, 2026-11-15).
--   * reps run on the SERVER's clock (RepSeconds); the client only plays the clip.
--   * the timing game: a tap (TrainTap) inside the last PerfectWindow of a rep's cycle (plus a
--     small latency allowance) makes that rep PERFECT: + PerfectBonus of its Power. One per rep,
--     taps rate-limited, all judged here against the session's own start time.
--   * Stop(player) (the Exit button, a death, leaving) restores movement.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Progress = require(ReplicatedStorage.Shared.Core.Progress)
local World = require(ReplicatedStorage.Shared.Core.World)
local Guard = require(script.Parent.Parent.Logic.Guard)

local REP = Config.Training.RepSeconds
local COUNT = Config.Server.PlotCount
-- a tap this soon AFTER a rep boundary still counts for the rep that just ended (network lag)
local LATE_ALLOWANCE = 0.12

type Session = {
	station: number,
	start: number, -- os.clock() of the start: reps and the timing game run from it
	startServer: number, -- the same instant as workspace:GetServerTimeNow(), for the client's ring
	last: number,
	perfectRep: number, -- the last rep index that was already made perfect
	saved: { walk: number, jump: number, jumpPower: number }?,
}

local TrainingService = Knit.CreateService({
	Name = "TrainingService",
	_sessions = {} :: { [Player]: Session },
})

function TrainingService:KnitInit()
	self._set = Net.server("TrainSet")
	self._tapRemote = Net.server("TrainTap")
end

function TrainingService:IsTraining(player: Player): boolean
	return self._sessions[player] ~= nil
end

--- The state the client needs for the session (nil when not training).
function TrainingService:View(player: Player): { station: number, start: number, rep: number }?
	local session = self._sessions[player]
	if not session then
		return nil
	end
	return { station = session.station, start = session.startServer, rep = REP }
end

local function parts(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return humanoid, if root and root:IsA("BasePart") then root else nil
end

function TrainingService:Start(player: Player, station: number)
	local profile = self._data:Get(player)
	local row = Config.Training.Stations[station]
	if not profile or not row then
		return
	end
	if self._sessions[player] then
		self:Stop(player)
	end
	if (profile.gear or 0) < row.Unlock then
		local gear = Config.Training.Equipment[row.Unlock]
		self._state:Toast(
			player,
			`{row.Name} unlocks with the {if gear then gear.Name else "next gear"}`,
			"info"
		)
		return
	end
	local index = self._plots:IndexOf(player)
	local humanoid, root = parts(player)
	if not index or not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	local tx, tz, sx, sz = World.station(Config.World, Config.Training, index, COUNT, station)
	-- contact: the clip's fists / palms reach Contact studs in front of the root, so the root
	-- stands Contact in front of the target's real front face (the strike gear changes size
	-- with the tier: wooden dummy, sandbag, iron dummy)
	if row.Contact then
		local face = self:_targetFace(index, row, station)
		if face then
			sz = face + row.Contact
		end
	end
	if not self._plots:Near(player, sx, sz, Config.World.StationRadius + 10) then
		self._state:Toast(player, "Walk up to the station to train", "info")
		return
	end
	-- snap: stand point, facing the target, feet on the court
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { player.Character :: Model }
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit =
		workspace:Raycast(Vector3.new(sx, root.Position.Y + 10, sz), Vector3.new(0, -40, 0), params)
	local floorY = if hit then hit.Position.Y else Config.World.GroundY
	local y = floorY + humanoid.HipHeight + root.Size.Y / 2
	local saved =
		{ walk = humanoid.WalkSpeed, jump = humanoid.JumpHeight, jumpPower = humanoid.JumpPower }
	humanoid.WalkSpeed = 0
	humanoid.JumpHeight = 0
	humanoid.JumpPower = 0
	root.AssemblyLinearVelocity = Vector3.zero
	-- strike / push face their target; curls and meditation (no contact) face out to the court,
	-- back to the log and the falls, so the camera sees them from the front
	local facing = if row.Contact then Vector3.new(tx, y, tz) else Vector3.new(sx, y, sz + 10)
	root.CFrame = CFrame.lookAt(Vector3.new(sx, y, sz), facing)
	root.Anchored = true
	local now = os.clock()
	self._sessions[player] = {
		station = station,
		start = now,
		startServer = workspace:GetServerTimeNow(),
		last = now,
		perfectRep = -1,
		saved = saved,
	}
	self._state:MarkDirty(player)
end

-- The +Z (front) face of a station's target in world Z, from its bounding box; nil if missing.
function TrainingService:_targetFace(index: number, row: any, station: number): number?
	local map = workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")
	local plot = plots and plots:FindFirstChild("Plot" .. index)
	if not plot then
		return nil
	end
	local target: Instance? = nil
	if row.Prop == "gear_strike" then
		local anchor = plot:FindFirstChild("Gear")
		target = anchor and anchor:FindFirstChild("GearModel")
	elseif row.Prop == "gear_spirit" then
		local anchor = plot:FindFirstChild("SpiritGear")
		target = anchor and anchor:FindFirstChild("GearModel")
	else
		local anchor = plot:FindFirstChild("Target" .. station, true)
		target = anchor and (anchor:FindFirstChild("GearModel") or anchor)
	end
	if target and target:IsA("Model") then
		local cf, size = target:GetBoundingBox()
		return cf.Position.Z + size.Z / 2
	elseif target and target:IsA("BasePart") then
		return target.Position.Z + target.Size.Z / 2
	end
	return nil
end

function TrainingService:Stop(player: Player)
	local session = self._sessions[player]
	if not session then
		return
	end
	self._sessions[player] = nil
	local humanoid, root = parts(player)
	if root then
		root.Anchored = false
	end
	if humanoid and session.saved then
		humanoid.WalkSpeed = session.saved.walk
		humanoid.JumpHeight = session.saved.jump
		humanoid.JumpPower = session.saved.jumpPower
	end
	self._state:MarkDirty(player)
end

--- A prompt on station `station` (InteractService): start there, or stop if already there.
function TrainingService:Toggle(player: Player, station: number?)
	local session = self._sessions[player]
	if session and (station == nil or session.station == station) then
		self:Stop(player)
	elseif station then
		self:Start(player, station)
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
		-- the client's RANK UP banner celebrates it (owner's review 3: one alert, not two)
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

-- the timing game: is this tap inside the perfect window of a rep not yet made perfect?
function TrainingService:_tap(player: Player)
	local session = self._sessions[player]
	local profile = self._data:Get(player)
	if not session or not profile then
		return
	end
	local elapsed = os.clock() - session.start
	local rep = math.floor(elapsed / REP)
	local phase = (elapsed - rep * REP) / REP
	local window = Config.Training.PerfectWindow
	local target: number? = nil
	if phase >= 1 - window then
		target = rep
	elseif phase * REP <= LATE_ALLOWANCE then
		target = rep - 1
	end
	if target == nil or target <= session.perfectRep or target < 0 then
		return
	end
	session.perfectRep = target
	local double = self._store:Has(player, "DoubleTraining")
	local perRep = Progress.powerPerRep(Config, profile.gear, double)
	self:AddPower(player, perRep * Config.Training.PerfectBonus)
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
		-- the client can only END a session (Exit); starting is a prompt on the station
		if on ~= true then
			self:Stop(player)
		end
	end)
	self._tapRemote.OnServerEvent:Connect(function(player: Player)
		local rate = Config.Training.MaxTapsPerSecond
		if not Guard.allow(player, "TrainTap", rate, rate * 2) then
			return
		end
		self:_tap(player)
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
				local humanoid, root = parts(player)
				if
					not profile
					or not humanoid
					or not root
					or humanoid.Health <= 0
					or not root.Anchored
				then
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
