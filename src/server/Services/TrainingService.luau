--!strict
-- TrainingService - Power, from the training grounds on the player's own plot (plan 13 phase D).
--
-- A base has two courts; each shows one training ground (Core/Grounds: the two newest the owner
-- has opened). A session belongs to ONE court:
--   * Start(player, court): the plot is theirs and the ground is open (its rebirth). The character
--     is SNAPPED to the ground's stand point (the `Stand` part of the set piece PlotService placed)
--     and LOCKED there (root anchored, WalkSpeed 0, no jump) until Stop. The client cannot walk
--     off mid-rep or punch the air from across the court (owner's review, 2026-11-15).
--   * reps run on the SERVER's clock (RepSeconds); the client only plays the clip.
--   * the game (Core/Beat): beats come at jittered moments from the session's seed, the ground's
--     BeatSeconds apart. One input per beat is graded here against the session's own clock: a TAP
--     on the beat (ring), or a HOLD let go on the beat (breath: the hold must have begun MinHold
--     before; charge the same with a long hold), an answer with a LANE (reflex), or a tap on
--     every beat but the RESTS (rhythm: a tap on a rest is a slip that costs Focus).
--     PERFECT / GOOD add to that beat's reps and fill FOCUS; a full bar AWAKENS the hero
--     for a few seconds (every rep an automatic perfect, x AwakeningMult), during which input does
--     not count. A player who never touches anything still gets every rep: the x1 floor.
--   * everyone sees it: the character carries TrainPlot / TrainCourt while it trains and
--     TrainAwake (the server time the awakening ends) while awakened; clients draw from those.
--   * Stop(player) (the Exit button, a death, leaving) restores movement.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Beat = require(ReplicatedStorage.Shared.Core.Beat)
local Grounds = require(ReplicatedStorage.Shared.Core.Grounds)
local Progress = require(ReplicatedStorage.Shared.Core.Progress)
local Throw = require(ReplicatedStorage.Shared.Core.Throw)
local Guard = require(script.Parent.Parent.Logic.Guard)

local REP = Config.Training.RepSeconds
local BEAT = Config.Training.Beat
-- how far a tap may be off because of the network: added to both grading windows
local LAG_ALLOWANCE = 0.08

type Session = {
	station: number, -- the court (1 left, 2 right)
	ground: number, -- index into Training.Grounds
	minHold: number?, -- a held game: seconds the hold must last before its release counts
	lanes: number?, -- a reflex game: how many lanes a beat can fall on (the input names one)
	lead: number, -- a reflex game: seconds before the beat its lane is marked
	react: number, -- a reflex game: seconds after the mark an answer is still Perfect
	rests: number?, -- a game with gaps: one beat in every hand of this many is a rest (Beat.rest)
	holdStart: number?, -- os.clock() the current hold began at
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
		ground = session.ground,
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

function TrainingService:Start(player: Player, court: number)
	local profile = self._data:Get(player)
	if not profile or (court ~= 1 and court ~= 2) then
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
	local shown = Grounds.shown(Config, profile.rebirth or 0)[court]
	local row = shown and Config.Training.Grounds[shown.ground]
	if not shown or not row then
		return
	end
	if shown.locked then
		self._state:Toast(player, `{row.Name} opens at Rebirth {shown.locked}`, "info")
		return
	end
	local index = self._plots:IndexOf(player)
	local humanoid, root = parts(player)
	if not index or not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	-- the stand point of the set piece on that court: where the feet go and which way they face
	local stand: CFrame = self._plots:GroundStand(index, court)
	local reach = Config.World.StationRadius + 10
	if not self._plots:Near(player, stand.Position.X, stand.Position.Z, reach) then
		self._state:Toast(player, "Walk up to the training ground", "info")
		return
	end
	local y = stand.Position.Y + humanoid.HipHeight + root.Size.Y / 2
	local saved =
		{ walk = humanoid.WalkSpeed, jump = humanoid.JumpHeight, jumpPower = humanoid.JumpPower }
	humanoid.WalkSpeed = 0
	humanoid.JumpHeight = 0
	humanoid.JumpPower = 0
	root.AssemblyLinearVelocity = Vector3.zero
	local at = Vector3.new(stand.Position.X, y, stand.Position.Z)
	local look = stand.LookVector
	root.CFrame = CFrame.lookAt(at, at + Vector3.new(look.X, 0, look.Z))
	root.Anchored = true
	local now = os.clock()
	self._sessions[player] = {
		station = court,
		ground = shown.ground,
		minHold = row.MinHold,
		lanes = row.Lanes,
		lead = row.Lead or 0,
		react = row.React or 0,
		rests = row.Rests,
		start = now,
		startServer = workspace:GetServerTimeNow(),
		last = now,
		seed = math.random(1, 100000),
		beat = row.BeatSeconds,
		judged = 0,
		lastTap = 0,
		focus = 0,
		awakeUntil = 0,
		awakeServer = 0,
		saved = saved,
	}
	local character = player.Character
	if character then
		character:SetAttribute("TrainPlot", index)
		character:SetAttribute("TrainCourt", court)
		character:SetAttribute("TrainAwake", nil)
	end
	self._state:MarkDirty(player)
end

function TrainingService:Stop(player: Player)
	local session = self._sessions[player]
	if not session then
		return
	end
	self._sessions[player] = nil
	local character = player.Character
	if character then
		character:SetAttribute("TrainPlot", nil)
		character:SetAttribute("TrainCourt", nil)
		character:SetAttribute("TrainAwake", nil)
	end
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

-- the game: grade this input against the nearest beat. One grade per beat; an input that misses
-- still uses its beat up, so mashing the screen lands on "miss", not on a lucky "good".
-- `down`: a held game sends true when the hold begins and false when it is let go (the release is
-- what is graded); a tapped game sends nothing. `lane`: a reflex game sends the lane it answers with.
function TrainingService:_tap(player: Player, down: boolean?, lane: number?)
	local session = self._sessions[player]
	local profile = self._data:Get(player)
	if not session or not profile then
		return
	end
	local now = os.clock()
	if now < session.awakeUntil then
		session.holdStart = nil
		return
	end
	local held: number? = nil
	if session.minHold then
		if down == true then
			session.holdStart = session.holdStart or now
			return
		elseif down ~= false or not session.holdStart then
			return
		end
		held = now - session.holdStart
		session.holdStart = nil
	end
	if now - session.lastTap < BEAT.MinTapGap then
		return
	end
	session.lastTap = now
	local elapsed = now - session.start
	local n = Beat.nearest(session.beat, elapsed, session.seed)
	if n <= session.judged then
		return
	end
	session.judged = n
	if Beat.rest(n, session.seed, session.rests) then
		-- a tap in the gap: nothing is paid and the slip costs a little Focus
		session.focus = math.max(0, session.focus - BEAT.FocusGood * 2)
		self._tapRemote:FireClient(player, "miss", session.focus, session.awakeServer)
		return
	end
	-- a ground that rests some beats: the played ones pay, and fill Focus, for the whole hand
	local share = Beat.share(session.rests)
	local gap = elapsed - Beat.moment(session.beat, n, session.seed)
	local grade: Beat.Grade
	if session.lanes then
		local expected = Beat.lane(n, session.seed, session.lanes)
		grade = Beat.gradeReflex(
			BEAT,
			gap,
			lane or 0,
			expected,
			session.lead,
			session.react,
			LAG_ALLOWANCE
		)
	elseif held and session.minHold then
		grade = Beat.gradeHold(BEAT, gap, held, session.minHold, LAG_ALLOWANCE)
	else
		grade = Beat.grade(BEAT, gap, LAG_ALLOWANCE)
	end
	local mult = Beat.reward(BEAT, grade)
	if mult > 1 then
		-- the reps themselves are paid by the clock: this is the bonus on the beat's reps
		local reps = session.beat / REP / share
		self:AddPower(player, self:_perRep(player, profile) * reps * (mult - 1), true)
	end
	session.focus += Beat.focus(BEAT, grade, session.beat, REP) / share
	if session.focus >= BEAT.FocusFull then
		session.focus = 0
		session.awakeUntil = now + BEAT.AwakeningSeconds
		session.awakeServer = workspace:GetServerTimeNow() + BEAT.AwakeningSeconds
		local character = player.Character
		if character then
			character:SetAttribute("TrainAwake", session.awakeServer)
		end
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
	self._tapRemote.OnServerEvent:Connect(function(player: Player, down: unknown)
		local rate = Config.Training.MaxTapsPerSecond * 2
		if not Guard.allow(player, "TrainTap", rate, rate * 2) then
			return
		end
		self:_tap(
			player,
			if typeof(down) == "boolean" then down else nil,
			if typeof(down) == "number"
					and down == math.floor(down)
					and down >= 1
					and down <= 8
				then down
				else nil
		)
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
