--!strict
-- TrainingService - Power, from the training stations on the player's own plot
-- (config Training.Stations: strike and meditate since 2026-11-22, one on each mirrored court).
--
-- A session belongs to ONE station:
--   * Start(player, i): the plot is theirs, the station is unlocked (gear tier >= Unlock). The
--     character is SNAPPED to the station's stand point facing the target, at contact distance,
--     and LOCKED there (root anchored, WalkSpeed 0, no jump) until Stop. The client cannot walk
--     off mid-rep or punch the air from across the court (owner's review, 2026-11-15).
--   * reps run on the SERVER's clock (RepSeconds); the client only plays the clip.
--   * the game (plan 13, Core/Beat): beats come at jittered moments from the session's seed. One
--     tap (TrainTap) per beat is graded here against the session's own clock: PERFECT / GOOD add
--     to that beat's reps and fill FOCUS; a full bar AWAKENS the hero for a few seconds (every rep
--     an automatic perfect, x AwakeningMult), during which taps do not count. A player who never
--     taps still gets every rep: leaving it running is the x1 floor.
--   * Stop(player) (the Exit button, a death, leaving) restores movement.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Beat = require(ReplicatedStorage.Shared.Core.Beat)
local Progress = require(ReplicatedStorage.Shared.Core.Progress)
local Throw = require(ReplicatedStorage.Shared.Core.Throw)
local World = require(ReplicatedStorage.Shared.Core.World)
local Guard = require(script.Parent.Parent.Logic.Guard)

local REP = Config.Training.RepSeconds
local COUNT = Config.Server.PlotCount
local BEAT = Config.Training.Beat
-- how far a tap may be off because of the network: added to both grading windows
local LAG_ALLOWANCE = 0.08

type Session = {
	station: number,
	start: number, -- os.clock() of the start: reps and the timing game run from it
	startServer: number, -- the same instant as workspace:GetServerTimeNow(), for the client's ring
	last: number,
	seed: number, -- the beats' jitter (Beat.moment)
	beat: number, -- seconds between beats
	judged: number, -- the last beat that was graded
	lastTap: number,
	focus: number,
	awakeUntil: number, -- os.clock() the awakening ends at (0 = not awake)
	awakeServer: number, -- the same instant on the shared server clock, for the client
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
function TrainingService:View(player: Player): { [string]: number }?
	local session = self._sessions[player]
	if not session then
		return nil
	end
	return {
		station = session.station,
		start = session.startServer,
		rep = REP,
		seed = session.seed,
		beat = session.beat,
		focus = session.focus,
		awake = session.awakeServer,
	}
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
	-- not with a hero in the hands: set it down first (owner's review of section 5)
	if self._plots:Carrying(player) then
		self._state:Toast(player, "Place your hero on a pedestal first!", "bad")
		return
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
		seed = math.random(1, 100000),
		beat = REP,
		judged = 0,
		lastTap = 0,
		focus = 0,
		awakeUntil = 0,
		awakeServer = 0,
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
--- Add Power. `memory` (training reps and perfect taps, not paid packs or
--- test grants): muscle memory multiplies the gain while the player is below
--- their own record, and stops at the record.
function TrainingService:AddPower(player: Player, amount: number, memory: boolean?)
	local profile = self._data:Get(player)
	if not profile or amount <= 0 then
		return
	end
	local before = Progress.rank(Config, profile.power).index
	if memory and Progress.catchingUp(profile.power, profile.powerRecord) then
		profile.power = Progress.addPower(
			Config,
			profile.power,
			profile.powerRecord,
			amount * Config.Training.MuscleMemory
		)
	else
		profile.power += amount
	end
	local newZone =
		Progress.touch(profile, Throw.reach(Config.Zones, profile.power, profile.rebirth))
	local after = Progress.rank(Config, profile.power)
	if after.index > before or newZone then
		-- the client's RANK UP banner celebrates it (owner's review 3: one alert, not two);
		-- a new zone unlocks gear, food and a slot, which the snapshot carries
		self._state:MarkDirty(player)
	end
	self._state:Tick(player)
end

-- Power of one rep for this player: gear x Double Training x the rebirth bonus
function TrainingService:_perRep(player: Player, profile: any): number
	local double = self._store:Has(player, "DoubleTraining")
	return Progress.powerPerRep(Config, profile.gear, double, profile.rebirth)
end

--- The Power of `minutes` of training on the player's current gear (the
--- training-skip products).
--- Power for `minutes` of training, paid now. Returns the Power given.
function TrainingService:GrantMinutes(player: Player, minutes: number): number
	local profile = self._data:Get(player)
	if not profile then
		return 0
	end
	local reps = Progress.repsIn(Config, minutes * 60)
	-- a paid pack counts at the normal rate: no muscle memory (plan 12, section 8)
	local power = reps * self:_perRep(player, profile)
	self:AddPower(player, power)
	return power
end

-- the game: grade this tap against the nearest beat. One grade per beat; a tap that misses still
-- uses its beat up, so mashing the screen lands on "miss", not on a lucky "good".
function TrainingService:_tap(player: Player)
	local session = self._sessions[player]
	local profile = self._data:Get(player)
	if not session or not profile then
		return
	end
	local now = os.clock()
	if now < session.awakeUntil or now - session.lastTap < BEAT.MinTapGap then
		return
	end
	session.lastTap = now
	local elapsed = now - session.start
	local n = Beat.nearest(session.beat, elapsed, session.seed)
	if n <= session.judged then
		return
	end
	session.judged = n
	local gap = elapsed - Beat.moment(session.beat, n, session.seed)
	local grade = Beat.grade(BEAT, gap, LAG_ALLOWANCE)
	local mult, focus = Beat.reward(BEAT, grade)
	if mult > 1 then
		-- the reps themselves are paid by the clock: this is the bonus on the beat's reps
		local reps = session.beat / REP
		self:AddPower(player, self:_perRep(player, profile) * reps * (mult - 1), true)
	end
	session.focus += focus
	if session.focus >= BEAT.FocusFull then
		session.focus = 0
		session.awakeUntil = now + BEAT.AwakeningSeconds
		session.awakeServer = workspace:GetServerTimeNow() + BEAT.AwakeningSeconds
	end
	self._tapRemote:FireClient(player, grade, session.focus, session.awakeServer)
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
		local rate = Config.Training.MaxTapsPerSecond * 2
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
					local mult = if now < session.awakeUntil then Beat.awakenedMult(BEAT) else 1
					self:AddPower(player, reps * self:_perRep(player, profile) * mult, true)
				end
			end
		end
	end)
end

return TrainingService
