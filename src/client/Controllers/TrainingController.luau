--!strict
-- TrainingController - the training games, client side (plan 13 phase D). The server owns the
-- reps, the Power and every judgement (Services/TrainingService); this is what the player sees,
-- hears and presses.
--
-- While a session runs (state.trainSession = { station = court, ground, start, rep, seed, beat,
-- focus, awake }):
--   * the server has snapped the character onto the ground's stand point and locked it; here the
--     camera frames the ground its own way (Scriptable) and the ground's clip loops, RUN IN TIME:
--     its reps (config Marks) fall on the beats (Core/Beat.clipAt), so the fist lands as the ring
--     does and the breath is let out on the gold
--   * the game, one beat at a time (Core/Beat.upcoming), drawn in TrainingBar.TimingRing:
--       ring    (Striking Post)    the Shrink ring closes on the gold Target; TAP as it lands
--       breath  (Waterfall Focus)  the Fill disc swells out to the gold ring; HOLD, let go on it
--       sweep   (Boulder Breaker)  the Needle sweeps the SweepMeter; TAP as it crosses the gold zone
--                                  (the ring's judge, another picture)
--       reflex  (Thunder Peak)     lightning marks one of the three Rods; tap THAT one (its button, A / S /
--                                  D, the arrow keys, or that third of the screen) before the strike
--       rhythm  (Gravity Chamber)  the beats ride the BeatTrack as notes; TAP as each sits in the gold Hit
--                                  ring. One beat in four is a REST (a gap, a small dim note): no tap
--       charge  (Spirit Orb)       HOLD: the ChargeMeter's Fill climbs and the orb grows; let go in the gold
--                                  (the breath's judge with a long hold, another picture)
--     the grade is shown at once from the rule the server grades by; the server's answer
--     (TrainTap: Focus, the awakening) follows
--   * FOCUS fills the FocusBar; full = AWAKENING: the awakening clip, the ground's own show and
--     the aura (Controllers/GroundController, for everyone), a closer camera, no input needed
--   * Exit: the TrainingBar's ExitButton (bound by Pages/TrainingBar), Backspace or X

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Beat = require(ReplicatedStorage.Shared.Core.Beat)
local Motion = require(script.Parent.Parent.Fx.Motion)
local Screens = require(script.Parent.Parent.Ui.Screens)
local Sound = require(script.Parent.SoundController)

local TR = Config.Training
local BEAT = TR.Beat
local player = Players.LocalPlayer

local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromHex("FFC93C")
local GREEN = Color3.fromHex("48D687")
local CYAN = Color3.fromHex("5FD8FF")
local PALE = Color3.fromHex("BFE9FF")
local JADE = Color3.fromHex("5CF0B4")
local GREY = Color3.fromHex("8A8FB8")
local FOV = 70

type Live = {
	court: number,
	row: any, -- the Training.Grounds row
	id: string,
	hold: boolean, -- a held game (breath): press, let go on the beat
	game: string, -- the picture: "ring", "breath", "sweep", "reflex", "rhythm", "charge"
	rests: number?, -- a game with gaps: one beat in every hand of this many is a rest
	lanes: number?, -- a reflex game: how many lanes; the input names one
	laneTrack: AnimationTrack?, -- the answer clip playing over the loop
	start: number, -- server time the session began at
	seed: number,
	beat: number, -- seconds between beats
	focus: number,
	awake: number, -- server time the awakening ends at
	judged: number, -- the last beat an input was graded for
	grades: { [number]: string }, -- what this client graded each beat, until its rep has landed
	landed: number, -- the last beat whose rep has been shown
	combo: number,
	pressAt: number?, -- server time the current hold began at
	piece: Model?, -- the ground's set piece on the plot
	stand: CFrame, -- where the trainee stands, facing
	inward: number, -- +1 / -1: the world X side of the court that faces the walkway
	track: AnimationTrack?, -- the training loop
	awakeTrack: AnimationTrack?,
	finishTrack: AnimationTrack?,
	marks: { RBXScriptConnection },
	wasAwake: boolean,
}

local TrainingController = Knit.CreateController({
	Name = "TrainingController",
	_live = nil :: Live?,
	-- the lens of the shot the camera is on (or moving to)
	_fov = FOV,
	_warned = false,
})

local function character(): (Model?, Humanoid?, BasePart?)
	local c = player.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	local r = c and c:FindFirstChild("HumanoidRootPart")
	return c, h, if r and r:IsA("BasePart") then r else nil
end

local function gui(): ScreenGui?
	local pg = player:FindFirstChildOfClass("PlayerGui")
	local g = pg and pg:FindFirstChild("TrainingBar")
	return if g and g:IsA("ScreenGui") then g else nil
end

local function find(name: string): GuiObject?
	local g = gui()
	local o = g and g:FindFirstChild(name, true)
	return if o and o:IsA("GuiObject") then o else nil
end

local function child(parent: Instance?, name: string): GuiObject?
	local o = parent and parent:FindFirstChild(name)
	return if o and o:IsA("GuiObject") then o else nil
end

-- colour a frame the UI build painted with a gradient (its own colour then multiplies it)
local function paint(frame: GuiObject, colour: Color3)
	local gradient = frame:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Color = ColorSequence.new(colour:Lerp(WHITE, 0.4), colour)
		frame.BackgroundColor3 = WHITE
	else
		frame.BackgroundColor3 = colour
	end
end

-- --------------------------------------------------------------- camera --

-- The two framings of a ground: training and awakened. The ring sits right of centre on the HUD,
-- so every shot aims a little right of the trainee: they stand in the left third, clear of it.
function TrainingController:_shot(live: Live, awake: boolean): (CFrame, number)
	local at = live.stand.Position
	local forward = live.stand.LookVector
	local side = Vector3.new(live.inward, 0, 0)
	local eye: Vector3, look: Vector3, fov: number
	if live.game == "rhythm" then
		-- push-ups: side-on and LOW, the whole plank in profile along the floor
		if awake then
			-- they float up and so does everything loose: back and up
			-- (no further out: the pylon on the camera's side then stands in the shot)
			eye = at + side * 9.6 + forward * 0.4 + Vector3.new(0, 2.2, 0)
			look = at + forward * 0.4 + Vector3.new(0, 3.9, 0)
			fov = 72
		else
			eye = at + side * 9 + forward * 0.4 + Vector3.new(0, 1.5, 0)
			look = at + forward * 0.4 + Vector3.new(0, 1.5, 0)
			fov = FOV
		end
	elseif live.game == "charge" then
		-- the orb overhead: from the front, below eye level, hero and orb both in the shot
		if awake then
			-- the orb is enormous: well back, looking up at it
			-- (from the far side of the walkway: on its own side the notice board stood in the shot)
			eye = at + forward * 15 - side * 3.2 + Vector3.new(0, 1.6, 0)
			look = at + Vector3.new(0, 7.6, 0)
			fov = 74
		else
			eye = at + forward * 12.5 + side * 1.0 + Vector3.new(0, 2.2, 0)
			look = at + Vector3.new(0, 5.0, 0)
			fov = FOV
		end
	elseif live.lanes then
		-- on the peak, facing out, the three rods behind and above them: from the front and from
		-- BELOW eye level, so the rods' tips and the sky are in the shot
		-- (well to one side: straight on, the middle rod stood hidden behind the trainee)
		if awake then
			eye = at + forward * 11.5 + side * 3.6 + Vector3.new(0, 2.2, 0)
			look = at + Vector3.new(0, 5.4, 0)
			fov = 70
		else
			eye = at + forward * 12 + side * 3.6 + Vector3.new(0, 1.6, 0)
			look = at + Vector3.new(0, 5.6, 0)
			fov = 72
		end
	elseif live.hold then
		-- seated under the falls, facing out: from the front, the water behind them
		if awake then
			-- they float 1.6 up and the falls open: back and up, the whole column in frame
			eye = at + forward * 13 + side * 1.2 + Vector3.new(0, 3.2, 0)
			look = at + Vector3.new(0, 4.6, 0)
			fov = 66
		else
			-- (straight on: from the side the trainee hid the falls instead of sitting in them)
			eye = at + forward * 9.5 + side * 0.8 + Vector3.new(0, 2.6, 0)
			look = at + Vector3.new(0, 2.6, 0)
			fov = FOV
		end
	else
		-- striking: side-on, a touch toward the target, so every punch reads in profile
		if awake then
			eye = at + side * 7.2 + forward * 1.9 + Vector3.new(0, 2.2, 0)
			look = at + forward * 1.5 + Vector3.new(0, 3.3, 0)
			fov = 62
		else
			eye = at + side * 9 + forward * 1.6 + Vector3.new(0, 3.4, 0)
			look = at + forward * 1.1 + Vector3.new(0, 3.3, 0)
			fov = FOV
		end
	end
	local aim = CFrame.lookAt(eye, look)
	return CFrame.lookAt(eye, look + aim.RightVector * (if awake then 1.6 else 2.6)), fov
end

function TrainingController:_frameCamera(live: Live, awake: boolean, seconds: number)
	local camera = workspace.CurrentCamera
	local cf, fov = self:_shot(live, awake)
	camera.CameraType = Enum.CameraType.Scriptable
	-- the move and the lens are two tweens: a lens push (below) must not cut the move short
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(camera, info, { CFrame = cf }):Play()
	TweenService:Create(camera, info, { FieldOfView = fov }):Play()
	self._fov = fov
end

-- A quick push of the lens on a heavy blow, back to the shot's own lens (not to whatever the
-- lens was at that instant: when the push came after the camera had started back from the
-- awakening, it froze the lens at the awakened shot's 62; seen in a play test).
function TrainingController:_punch(amount: number)
	local camera = workspace.CurrentCamera
	local rest = self._fov
	camera.FieldOfView = rest - amount
	TweenService:Create(
		camera,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FieldOfView = rest }
	):Play()
end

-- ---------------------------------------------------------------- clips --

-- the training loop, started (or started again after an awakening)
function TrainingController:_loop(live: Live)
	local _, humanoid = character()
	live.track = Motion.play(humanoid, live.row.Clip or "TrainPost", { fade = 0.25, looped = true })
end

-- keep the loop in time: the clip's reps fall on the beats (a beat is jittered, so the clip is
-- run a little faster or slower between every two beats, and put right if it has drifted)
function TrainingController:_sync(live: Live, elapsed: number)
	local track = live.track
	local marks, length = live.row.Marks, live.row.ClipSeconds
	if not track or not marks or not length or track.Length <= 0 then
		return
	end
	local clip, speed = Beat.clipAt(live.beat, elapsed, live.seed, marks, length, live.rests)
	if math.abs(track.Speed - speed) > 0.02 then
		track:AdjustSpeed(speed)
	end
	local off = math.abs(track.TimePosition - clip)
	if math.min(off, length - off) > 0.12 then
		track.TimePosition = clip
	end
end

-- the reps whose beat has come: each one lands on the ground (GroundController), as hard as
-- the grade the player got for it
function TrainingController:_land(live: Live, elapsed: number)
	for _ = 1, 4 do
		local n = live.landed + 1
		local moment = Beat.moment(live.beat, n, live.seed)
		if moment > elapsed then
			return
		end
		live.landed = n
		-- a beat that passed long ago (the awakening ran over it) is not replayed; a rest has no rep
		if elapsed - moment < 0.4 and not Beat.rest(n, live.seed, live.rests) then
			self._ground:Contact(live.piece, live.id, live.grades[n], self:_laneOf(live, n))
		end
		live.grades[n] = nil
	end
end

-- the lane beat `n` falls on (a reflex game), else nil
function TrainingController:_laneOf(live: Live, n: number): number?
	return if live.lanes then Beat.lane(n, live.seed, live.lanes) else nil
end

-- --------------------------------------------------------------- a session --

function TrainingController:_begin(session: any)
	local state = self._state.State
	local row = TR.Grounds[session.ground or 1]
	local _, _, root = character()
	if not state or not state.plot or not row or not root then
		return
	end
	local court = session.station
	local piece, id = self._ground:Piece(state.plot, court)
	local live: Live = {
		court = court,
		row = row,
		id = id or row.Id,
		hold = row.MinHold ~= nil,
		game = row.Game,
		lanes = row.Lanes,
		rests = row.Rests,
		start = session.start,
		seed = session.seed or 1,
		beat = session.beat or row.BeatSeconds,
		focus = session.focus or 0,
		awake = session.awake or 0,
		judged = 0,
		grades = {},
		landed = 0,
		combo = 0,
		piece = piece,
		-- the server has stood the character on the stand point, facing: read it from the root
		stand = root.CFrame - Vector3.new(0, root.Size.Y / 2 + 2, 0),
		inward = -TR.Courts[court].Side,
		marks = {},
		wasAwake = false,
	}
	local standPart = piece and piece:FindFirstChild("Stand")
	if standPart and standPart:IsA("BasePart") then
		live.stand = standPart.CFrame
	end
	-- a session picked up midway (a respawn of the page): do not replay the beats behind us
	live.landed =
		math.max(0, Beat.nearest(live.beat, self._state:ServerNow() - live.start, live.seed) - 1)
	self._live = live
	ProximityPromptService.Enabled = false
	self:_frameCamera(live, false, 0.5)
	self:_loop(live)
	-- Space / gamepad A would jump (the server has already zeroed the jump): they play instead
	ContextActionService:BindActionAtPriority(
		"TrainTap",
		function(_, inputState: Enum.UserInputState)
			if inputState == Enum.UserInputState.Begin then
				self:_press()
			elseif inputState == Enum.UserInputState.End then
				self:_release()
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.Space,
		Enum.KeyCode.ButtonA
	)
	-- the HUD: the ground's name is on its board in the world, not repeated by the ring
	local title = find("StationTitle")
	if title then
		title.Visible = false
	end
	-- one picture per game, in the ring's place
	local ring, rods = find("TimingRing"), find("Rods")
	local shrink, fill = child(ring, "Shrink"), child(ring, "Fill")
	if ring then
		ring.Visible = live.game == "ring" or live.game == "breath"
	end
	for name, game in
		{ SweepMeter = "sweep", Rods = "reflex", BeatTrack = "rhythm", ChargeMeter = "charge" }
	do
		local picture = find(name)
		if picture then
			picture.Visible = live.game == game
		end
	end
	if shrink then
		shrink.Visible = not live.hold
	end
	if fill then
		fill.Visible = live.hold
	end
	if live.lanes then
		-- the rods: their buttons, and A / S / D or the arrow keys
		for lane = 1, live.lanes do
			local button = child(rods, "Rod" .. lane)
			if button and button:IsA("GuiButton") then
				table.insert(
					live.marks,
					button.Activated:Connect(function()
						self:_press(lane)
					end)
				)
			end
		end
		local keys = {
			[Enum.KeyCode.A] = 1,
			[Enum.KeyCode.Left] = 1,
			[Enum.KeyCode.S] = 2,
			[Enum.KeyCode.Up] = 2,
			[Enum.KeyCode.Down] = 2,
			[Enum.KeyCode.D] = 3,
			[Enum.KeyCode.Right] = 3,
		}
		ContextActionService:BindActionAtPriority(
			"TrainLane",
			function(_, inputState: Enum.UserInputState, input: InputObject)
				local lane = keys[input.KeyCode]
				if
					inputState == Enum.UserInputState.Begin
					and lane
					and lane <= (live.lanes or 0)
				then
					self:_press(lane)
				end
				return Enum.ContextActionResult.Sink
			end,
			false,
			Enum.ContextActionPriority.High.Value,
			Enum.KeyCode.A,
			Enum.KeyCode.S,
			Enum.KeyCode.D,
			Enum.KeyCode.Left,
			Enum.KeyCode.Up,
			Enum.KeyCode.Down,
			Enum.KeyCode.Right
		)
	end
	local hint = find("TapHint")
	if hint and hint:IsA("TextLabel") then
		hint.Text = row.Hint or "TAP AS THE RING LANDS"
		hint.Visible = true
	end
	-- the grade flashes over the game's picture, except on the beat track: there it would hide the
	-- notes on every beat, so it flashes under the track
	local flash = find("PerfectLabel")
	if flash then
		local home = flash:GetAttribute("Home")
		if typeof(home) ~= "UDim2" then
			home = flash.Position
			flash:SetAttribute("Home", home)
		end
		flash.Position = if live.game == "rhythm" then home + UDim2.fromOffset(0, 58) else home
	end
	local combo = find("Combo")
	if combo then
		combo.Visible = false
	end
end

--- True while the local player is in a training session.
function TrainingController:IsTraining(): boolean
	return self._live ~= nil
end

function TrainingController:_end()
	local live = self._live
	if not live then
		return
	end
	self._live = nil
	for _, c in live.marks do
		c:Disconnect()
	end
	Motion.stop(live.track, 0.3)
	Motion.stop(live.awakeTrack, 0.2)
	Motion.stop(live.finishTrack, 0.2)
	Motion.stop(live.laneTrack, 0.15)
	self._ground:Mark(live.piece, 0)
	self._ground:Hold(live.piece, live.id, false)
	self._ground:Charge(live.piece, 0)
	ContextActionService:UnbindAction("TrainTap")
	ContextActionService:UnbindAction("TrainLane")
	ProximityPromptService.Enabled = true
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = FOV
	local hint = find("TapHint")
	if hint then
		hint.Visible = false
	end
end

-- ------------------------------------------------------------ awakening --

function TrainingController:_awaken(live: Live)
	local _, humanoid = character()
	live.combo = 0
	live.pressAt = nil
	Motion.stop(live.track, 0.2)
	live.track = nil
	live.awakeTrack =
		Motion.play(humanoid, live.row.AwakeClip or "", { fade = 0.25, looped = true })
	-- the flurry: every blow of the awakening clip lands on the post
	local conn = Motion.onMarker(live.awakeTrack, "Hit", function()
		if self._live == live then
			self._ground:Flurry(live.piece, live.id)
		end
	end)
	if conn then
		table.insert(live.marks, conn)
	end
	Sound:Play("focus_full", nil)
	self:_flash("AWAKENING!", 1.4)
	self:_frameCamera(live, true, 0.45)
	local combo = find("Combo")
	if combo then
		combo.Visible = false
	end
end

-- the blow that ends the awakening (Striking Post): timed so it lands as the time runs out
function TrainingController:_finisher(live: Live)
	local _, humanoid = character()
	local track = Motion.play(humanoid, live.row.FinishClip, { fade = 0.08, looped = false })
	if not track then
		return
	end
	live.finishTrack = track
	Motion.stop(live.awakeTrack, 0.1)
	live.awakeTrack = nil
	-- (the blow of a strike, or the orb leaving the hands)
	for _, marker in { "Hit", "Release" } do
		local hit = Motion.onMarker(track, marker, function()
			if self._live == live then
				self:_punch(9)
			end
		end)
		if hit then
			table.insert(live.marks, hit)
		end
	end
	track.Stopped:Once(function()
		if self._live == live and live.finishTrack == track then
			live.finishTrack = nil
			if not live.track and not live.wasAwake then
				self:_loop(live)
			end
		end
	end)
end

function TrainingController:_calm(live: Live)
	Motion.stop(live.awakeTrack, 0.3)
	live.awakeTrack = nil
	if not live.finishTrack then
		self:_loop(live)
	end
	if live.game == "charge" then
		-- the orb has just left the hands: the camera follows it up, sees it burst over the court,
		-- and comes back down
		local at = live.stand.Position
		local eye = at
			+ live.stand.LookVector * 24
			- Vector3.new(live.inward, 0, 0) * 2
			+ Vector3.new(0, 1.5, 0)
		local camera = workspace.CurrentCamera
		local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(
			camera,
			info,
			{ CFrame = CFrame.lookAt(eye, at + Vector3.new(0, 23, 0)), FieldOfView = 74 }
		):Play()
		self._fov = 74
		task.delay(1.7, function()
			if self._live == live and not live.wasAwake then
				self:_frameCamera(live, false, 0.7)
			end
		end)
		return
	end
	self:_frameCamera(live, false, 0.6)
	if live.game == "rhythm" then
		-- gravity comes back: everything slams down
		self:_punch(8)
	end
end

-- ---------------------------------------------------------------- input --

function TrainingController:_flash(text: string, hold: number)
	local label = find("PerfectLabel")
	if label and label:IsA("TextLabel") then
		label.Text = text
		label.Visible = true
		Screens.pop(label, 1.3)
		task.delay(hold, function()
			if label.Text == text then
				label.Visible = false
			end
		end)
	end
end

-- a beat was graded here (the same rule the server uses): show it, keep it for the rep's landing
function TrainingController:_grade(
	live: Live,
	n: number,
	grade: string,
	gap: number,
	short: boolean
)
	live.judged = n
	local combo = find("Combo")
	if grade == "miss" then
		live.combo = 0
		if combo then
			combo.Visible = false
		end
		self:_flash(
			if short
				then (if live.lanes then "WRONG ROD" else "HOLD LONGER")
				elseif gap < 0 then "TOO EARLY"
				else "TOO LATE",
			0.4
		)
		return
	end
	live.combo += 1
	if n > live.landed then
		live.grades[n] = grade
	else
		-- a touch late: the rep has already landed, so its bonus lands now
		self._ground:Contact(live.piece, live.id, grade, self:_laneOf(live, n))
	end
	if not live.hold and not live.lanes then
		Sound:Play(
			"perfect_ding",
			nil,
			{ pitchVary = 0.04, volume = if grade == "perfect" then 1 else 0.6 }
		)
	end
	self:_flash(if grade == "perfect" then "PERFECT!" else "GOOD", 0.5)
	if combo and combo:IsA("TextLabel") and live.combo >= 2 then
		combo.Text = `x{live.combo} COMBO`
		combo.Visible = true
		Screens.pop(combo, 1.2)
	end
end

-- a tap (ring, sweep), the start of a hold (breath), or an answer with a lane (reflex)
function TrainingController:_press(lane: number?)
	local live = self._live
	local now = self._state:ServerNow()
	if not live or now < live.awake then
		return
	end
	if live.lanes then
		local row = live.row
		local n, gap = Beat.upcoming(live.beat, now - live.start, live.seed, BEAT.GoodWindow)
		-- nothing is marked yet (or this beat is answered): the tap is not an answer
		if not lane or n <= live.judged or gap < -row.Lead then
			return
		end
		if self._tapRemote then
			self._tapRemote:FireServer(lane)
		end
		-- the hero reaches for that rod, right or wrong
		local _, humanoid = character()
		local clip = row.LaneClips and row.LaneClips[lane]
		if clip then
			Motion.stop(live.laneTrack, 0.05)
			live.laneTrack =
				Motion.play(humanoid, clip, { fade = 0.05, looped = false, priority = "Action2" })
		end
		local expected = Beat.lane(n, live.seed, live.lanes)
		local grade = Beat.gradeReflex(BEAT, gap, lane, expected, row.Lead, row.React)
		self:_grade(live, n, grade, gap, lane ~= expected)
		return
	end
	if live.hold then
		if not live.pressAt then
			live.pressAt = now
			if self._tapRemote then
				self._tapRemote:FireServer(true)
			end
			self._ground:Hold(live.piece, live.id, true)
		end
		return
	end
	local n, gap = Beat.upcoming(live.beat, now - live.start, live.seed, BEAT.GoodWindow)
	if n <= live.judged then
		return
	end
	if self._tapRemote then
		self._tapRemote:FireServer()
	end
	if Beat.rest(n, live.seed, live.rests) then
		-- a tap in the gap: a slip (the server takes a little Focus for it)
		live.judged = n
		live.combo = 0
		local combo = find("Combo")
		if combo then
			combo.Visible = false
		end
		self:_flash("REST!", 0.4)
		return
	end
	self:_grade(live, n, Beat.grade(BEAT, gap), gap, false)
end

-- the end of a hold: this is what is graded
function TrainingController:_release()
	local live = self._live
	if not live or not live.hold or not live.pressAt then
		return
	end
	local now = self._state:ServerNow()
	local held = now - live.pressAt
	live.pressAt = nil
	self._ground:Hold(live.piece, live.id, false)
	if now < live.awake then
		return
	end
	if self._tapRemote then
		self._tapRemote:FireServer(false)
	end
	local n, gap = Beat.upcoming(live.beat, now - live.start, live.seed, BEAT.GoodWindow)
	if n <= live.judged then
		return
	end
	local minHold = live.row.MinHold or 0
	self:_grade(live, n, Beat.gradeHold(BEAT, gap, held, minHold), gap, held < minHold)
end

-- the server's grade of an input: the Focus it left and when an awakening ends
function TrainingController:_graded(focus: number, awake: number)
	local live = self._live
	if not live then
		return
	end
	if focus > live.focus then
		Sound:Play(
			"stat_tick",
			nil,
			{ speed = 0.9 + 0.5 * math.clamp(focus / BEAT.FocusFull, 0, 1) }
		)
	end
	live.focus = focus
	if awake > live.awake then
		live.awake = awake
	end
end

-- ----------------------------------------------------------------- frame --

function TrainingController:_draw(live: Live, elapsed: number, awake: boolean, now: number)
	local upcoming, gap, progress = Beat.upcoming(live.beat, elapsed, live.seed, BEAT.GoodWindow)
	local ring = find("TimingRing")
	local targetScale = ((ring and ring:GetAttribute("TargetScale")) or 0.62) :: number
	local sweet = math.abs(gap) <= BEAT.PerfectWindow
	local holding = live.pressAt ~= nil
	if live.game == "charge" then
		-- the gauge: the level climbs to the gold band on the beat. Held, it is the Fill (grey when the
		-- hold began too late to count); not held, only the Marker shows where it would be
		local gauge = find("ChargeMeter")
		local fill, marker = child(gauge, "Fill"), child(gauge, "Marker")
		local sweetAt = ((gauge and gauge:GetAttribute("SweetAt")) or 0.84) :: number
		local level = if awake then sweetAt else math.min(sweetAt * progress, 0.98)
		local late = live.pressAt ~= nil
			and live.pressAt - live.start > elapsed - gap - (live.row.MinHold or 0)
		if fill then
			fill.Visible = awake or holding
			fill.Size = UDim2.new(1, -12, level, -6)
			paint(fill, if awake then GOLD elseif late then GREY elseif sweet then GREEN else JADE)
		end
		if marker then
			marker.Position = UDim2.fromScale(0.5, 1 - level)
			paint(marker, if awake then GOLD elseif sweet then GREEN else WHITE)
		end
		-- the orb over the hero grows with the hold (the show has it while awakened)
		self._ground:Charge(live.piece, if holding and not late then math.min(progress, 1.1) else 0)
	elseif live.game == "rhythm" then
		-- the notes: one per beat, riding right to left; a beat is in the Hit ring at its moment
		local track = find("BeatTrack")
		local hitAt = ((track and track:GetAttribute("HitAt")) or 0.16) :: number
		local perSecond = ((track and track:GetAttribute("PerSecond")) or 0.27) :: number
		local first = math.max(1, upcoming - 1)
		for i = 1, 6 do
			local note = child(track, "Note" .. i)
			if note then
				local n = first + i - 1
				local x = hitAt + (Beat.moment(live.beat, n, live.seed) - elapsed) * perSecond
				local rest = Beat.rest(n, live.seed, live.rests)
				note.Visible = not awake and n > live.judged and x > hitAt - 0.07 and x < 1.02
				if note.Visible then
					local side = if rest then 14 else 36
					note.Position = UDim2.fromScale(x, 0.5)
					note.Size = UDim2.fromOffset(side, side)
					local fade = math.clamp((x - 0.86) / 0.14, 0, 1)
					note.BackgroundTransparency = if rest then 0.45 + 0.55 * fade else fade
					local stroke = note:FindFirstChildOfClass("UIStroke")
					if stroke then
						stroke.Transparency = if rest then 1 else fade
					end
					paint(
						note,
						if rest then GREY elseif n == upcoming and sweet then GREEN else WHITE
					)
				end
			end
		end
		local hit = child(track, "Hit")
		local stroke = hit and hit:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if awake
					or not sweet
					or Beat.rest(upcoming, live.seed, live.rests)
				then GOLD
				else GREEN
		end
	elseif live.hold then
		-- the breath: the disc swells out to the gold ring on the beat (and a little past it)
		local fill = child(ring, "Fill")
		if fill then
			local s = if awake then targetScale else targetScale * (0.16 + 0.84 * progress)
			fill.Size = UDim2.fromScale(s, s)
			fill.BackgroundTransparency = if awake then 0.1 elseif holding then 0.15 else 0.55
			paint(
				fill,
				if awake
					then GOLD
					elseif holding and sweet then GREEN
					elseif holding then CYAN
					else PALE
			)
		end
	elseif live.game == "sweep" then
		-- the needle runs along the meter and crosses the middle of the gold zone on the beat
		local meter = find("SweepMeter")
		local needle = child(meter, "Needle")
		if meter and needle then
			local sweetAt = (meter:GetAttribute("SweetAt") or 0.74) :: number
			local x = if awake then sweetAt else math.min(0.04 + (sweetAt - 0.04) * progress, 0.97)
			needle.Position = UDim2.fromScale(x, 0.5)
			paint(needle, if awake then GOLD elseif sweet then GREEN else WHITE)
		end
	elseif live.lanes then
		-- the marked rod: from Lead seconds before the strike until it has struck
		local rods = find("Rods")
		local n = Beat.upcoming(live.beat, elapsed, live.seed, BEAT.GoodWindow)
		local marked = if not awake
				and gap >= -live.row.Lead
				and gap < 0
			then Beat.lane(n, live.seed, live.lanes)
			else 0
		-- in the world too: the rod's tip crackles (it stays lit after the answer, until it strikes)
		self._ground:Mark(live.piece, marked)
		if n <= live.judged then
			marked = 0
		end
		for lane = 1, live.lanes do
			local button = child(rods, "Rod" .. lane)
			-- (the build puts the ring inside the button's face, not directly under the button)
			local mark = button and button:FindFirstChild("Mark", true)
			if mark and mark:IsA("GuiObject") then
				mark.Visible = awake or lane == marked
				local scale = mark:FindFirstChildOfClass("UIScale")
				if not scale then
					scale = Instance.new("UIScale")
					scale.Parent = mark
				end
				scale.Scale = 1 + 0.08 * math.sin(now * 18)
			end
		end
	else
		-- the ring closes on the gold target at the beat's moment; awake, it rests on it
		local shrink = child(ring, "Shrink")
		if shrink then
			local s = if awake then targetScale else 1 - (1 - targetScale) * math.min(progress, 1)
			shrink.Size = UDim2.fromScale(s, s)
			shrink.BackgroundTransparency = 1
			local stroke = shrink:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = if awake then GOLD elseif sweet then GREEN else WHITE
			end
		end
	end
	local hint = find("TapHint")
	if hint and hint:IsA("TextLabel") then
		hint.Text = if awake
			then `AWAKENED!  x{Format.short(Beat.awakenedMult(BEAT))} POWER`
			elseif live.lanes then (if gap >= -live.row.Lead
				then "NOW!"
				else live.row.Hint or "")
			elseif not live.hold then live.row.Hint or ""
			elseif holding then "LET GO IN THE GOLD"
			elseif live.game == "charge" then live.row.Hint or "HOLD"
			else "HOLD"
	end
	-- Focus: fills with every good beat; awake, it is the time left, running down
	self._ground:Focus(live.piece, if awake then 1 else live.focus / BEAT.FocusFull)
	local bar = find("FocusBar")
	local fill, text = child(bar, "Fill"), bar and bar:FindFirstChild("FocusText", true)
	local fraction = if awake
		then math.clamp((live.awake - now) / BEAT.AwakeningSeconds, 0, 1)
		else math.clamp(live.focus / BEAT.FocusFull, 0, 1)
	if fill then
		fill.Visible = fraction > 0.01
		fill.Size = UDim2.new(fraction, -6 * fraction, 1, -6)
		paint(fill, if awake then GOLD:Lerp(WHITE, 0.3 + 0.3 * math.sin(now * 12)) else GOLD)
	end
	if text and text:IsA("TextLabel") then
		text.Text = if awake
			then `AWAKENED!  {math.max(1, math.ceil(live.awake - now))}s`
			else `FOCUS {math.floor(fraction * 100 + 0.5)}%`
	end
end

function TrainingController:_frame()
	local live = self._live
	if not live then
		return
	end
	local now = self._state:ServerNow()
	local elapsed = now - live.start
	local awake = now < live.awake
	-- the camera is ours for the whole session: something else that takes it and hands it back to
	-- the player (a rank or rebirth cinematic ending) is put right at once
	local camera = workspace.CurrentCamera
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		self:_frameCamera(live, awake, 0.3)
	end
	if awake and not live.wasAwake then
		live.wasAwake = true
		self:_awaken(live)
	elseif not awake and live.wasAwake then
		live.wasAwake = false
		self:_calm(live)
	end
	if awake then
		local lead = live.row.FinishAt
		if
			lead
			and live.row.FinishClip
			and live.awakeTrack
			and not live.finishTrack
			and live.awake - now <= lead
		then
			self:_finisher(live)
		end
	else
		self:_sync(live, elapsed)
		self:_land(live, elapsed)
	end
	self:_draw(live, elapsed, awake, now)
end

function TrainingController:KnitStart()
	self._state = Knit.GetController("StateController")
	self._ground = Knit.GetController("GroundController")
	-- the grounds' clips, fetched now: a clip's first play otherwise waits for its download
	local clips = {}
	for _, row in TR.Grounds do
		for _, key in { "Clip", "AwakeClip", "FinishClip" } do
			if row[key] then
				table.insert(clips, row[key])
			end
		end
		for _, clip in row.LaneClips or {} do
			table.insert(clips, clip)
		end
	end
	Motion.preload(clips)
	self._tapRemote = Net.client("TrainTap")
	if self._tapRemote then
		self._tapRemote.OnClientEvent:Connect(
			function(_grade: unknown, focus: unknown, awake: unknown)
				if typeof(focus) == "number" and typeof(awake) == "number" then
					self:_graded(focus, awake)
				end
			end
		)
	end
	local exit = Net.client("TrainSet")
	self._state:Observe(function(state: any)
		local session = state and state.trainSession
		local live = self._live
		if
			session and (not live or live.court ~= session.station or live.start ~= session.start)
		then
			self:_end()
			local ok, err = pcall(function()
				self:_begin(session)
			end)
			if not ok then
				warn(`[TrainingController] start failed inert: {err}`)
			end
		elseif not session and live then
			self:_end()
		end
	end)
	-- every rep: "+N POWER" on the HUD
	local lastPower: number? = nil
	self._state.Ticked:Connect(function(_yen: number, power: number)
		if self._live and lastPower and power > lastPower then
			local label = find("RepPower")
			if label and label:IsA("TextLabel") then
				label.Text = `+{Format.short(power - lastPower)} POWER`
				Screens.pop(label, 1.15)
			end
		end
		lastPower = power
	end)
	local function pointer(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
	end
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not self._live or processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.X then
			if exit then
				exit:FireServer(false)
			end
			return
		end
		if pointer(input) then
			local live = self._live
			if live and live.lanes then
				-- that third of the screen is that rod
				local width = workspace.CurrentCamera.ViewportSize.X
				local third =
					math.clamp(math.floor(input.Position.X / width * live.lanes) + 1, 1, live.lanes)
				self:_press(third)
			else
				self:_press()
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if self._live and pointer(input) then
			self:_release()
		end
	end)
	-- Studio only: a play test driven by script cannot press keys (VirtualInputManager is closed to
	-- it), so it plays through this event: Fire("press", lane?) / Fire("release")
	if RunService:IsStudio() then
		local test = Instance.new("BindableEvent")
		test.Name = "TrainTestInput"
		test.Event:Connect(function(kind: unknown, lane: unknown)
			if kind == "press" then
				self:_press(if typeof(lane) == "number" then lane else nil)
			elseif kind == "release" then
				self:_release()
			end
		end)
		test.Parent = player
	end
	RunService.RenderStepped:Connect(function()
		if self._live then
			local ok, err = pcall(function()
				self:_frame()
			end)
			if not ok and not self._warned then
				self._warned = true
				warn(`[TrainingController] frame failed inert: {err}`)
			end
		end
	end)
	player.CharacterAdded:Connect(function()
		self:_end()
	end)
end

return TrainingController
