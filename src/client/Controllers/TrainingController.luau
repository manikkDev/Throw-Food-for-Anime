--!strict
-- TrainingController - the four training mini-games, client side (the server owns the reps, the
-- Power and the "perfect" judgement: Services/TrainingService).
--
-- While a session runs (state.trainSession = { station, start, rep }):
--   * the server has snapped the character onto the station's mat at contact distance and
--     locked it; here the camera frames the station from the court side (Scriptable), the
--     station's clip loops, and every "Hit" / "Rep" / "Pulse" marker lands on the target: it
--     wobbles, the hit effect fires at the contact point, the station's sound plays
--   * the TIMING RING (TrainingBar.CanvasFrame.TimingRing): Shrink closes on Target once per rep,
--     on the server's clock; a tap (click, touch, Space, gamepad A) while it is close is PERFECT
--     (TrainTap: the server re-judges it and pays + PerfectBonus); perfects in a row build a combo
--   * the curls: a dumbbell is welded into each hand for the whole session
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
local World = require(ReplicatedStorage.Shared.Core.World)
local Motion = require(script.Parent.Parent.Fx.Motion)
local Vfx = require(script.Parent.Parent.Fx.Vfx)
local Screens = require(script.Parent.Parent.Ui.Screens)
local Sound = require(script.Parent.SoundController)

local W = Config.World
local TR = Config.Training
local COUNT = Config.Server.PlotCount
local player = Players.LocalPlayer
local LATE = 0.12 -- the same latency allowance the server gives

-- per station kind: the marker(s) that are a contact, the sound, where the hit effect goes
local KIND = {
	strike = { markers = { "Hit" }, sound = "train_hit", effect = true },
	lift = { markers = { "Rep" }, sound = "train_curl", effect = false },
	push = { markers = { "Hit" }, sound = "train_push", effect = true },
	meditate = { markers = { "Pulse" }, sound = nil, effect = false },
}

type Live = {
	station: number,
	start: number,
	rep: number,
	track: AnimationTrack?,
	marks: { RBXScriptConnection },
	weights: Instance?,
	judged: number, -- the last rep cycle a tap was judged in
	combo: number,
}

local TrainingController = Knit.CreateController({
	Name = "TrainingController",
	_live = nil :: Live?,
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

-- the station's target in the world (the strike gear, the log, the pillar, the spirit gear)
local function targetOf(plot: number, station: number): Instance?
	local map = workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")
	local folder = plots and plots:FindFirstChild("Plot" .. plot)
	if not folder then
		return nil
	end
	local row = TR.Stations[station]
	if row.Prop == "gear_strike" then
		local a = folder:FindFirstChild("Gear")
		return a and (a:FindFirstChild("GearModel") or a)
	elseif row.Prop == "gear_spirit" then
		local a = folder:FindFirstChild("SpiritGear")
		return a and (a:FindFirstChild("GearModel") or a)
	end
	local a = folder:FindFirstChild("Target" .. station, true)
	return a and (a:FindFirstChild("GearModel") or a)
end

-- a short damped wobble of the target, about its base (it was struck or shoved)
local function wobble(target: Instance?, strength: number)
	if not target or not (target:IsA("Model") or target:IsA("BasePart")) then
		return
	end
	local pv = target :: PVInstance
	if pv:GetAttribute("Wobbling") then
		return
	end
	pv:SetAttribute("Wobbling", true)
	local base = pv:GetPivot()
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t > 0.45 or not pv.Parent then
			conn:Disconnect()
			pcall(function()
				pv:PivotTo(base)
				pv:SetAttribute("Wobbling", nil)
			end)
			return
		end
		local angle = math.rad(7 * strength) * math.sin(t * 28) * math.exp(-t * 7)
		pv:PivotTo(base * CFrame.Angles(angle, 0, 0))
	end)
end

function TrainingController:_camera(plot: number, station: number)
	local tx, tz, sx, sz = World.station(W, TR, plot, COUNT, station)
	local row = TR.Stations[station]
	local _, _, root = character()
	local y = if root then root.Position.Y else W.GroundY + 3
	local stand = Vector3.new(sx, y, sz)
	local target = Vector3.new(tx, y, tz)
	-- from the court side nearer the plot centre (inside the court), a little in front
	local inward = -row.Side
	-- a profile view (the trainee faces -Z): beside them, a touch toward the target, so the
	-- punches, the curls and the push all read side-on
	local eye = if row.Contact
		then stand + Vector3.new(inward * 9, 2.4, -1.6)
		else stand + Vector3.new(inward * 3.5, 2.6, 9) -- facing out: from the front
	local look = if row.Contact
		then stand:Lerp(target, 0.45) + Vector3.new(0, 0.6, 0)
		else stand + Vector3.new(0, 0.8, 0)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	TweenService
		:Create(camera, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			-- aim a little right of the trainee: they stand in the left third, clear of the timing
			-- ring (which sits right of centre on the HUD)
			CFrame = CFrame.lookAt(eye, look + CFrame.lookAt(eye, look).RightVector * 2.6),
		})
		:Play()
end

-- the curls: one dumbbell welded to each hand (the TrainLift clip's grip: centred in the hand
-- part, long axis on the hand's Z; handle 0.2 x 0.2 x 1.7, plates 0.78 x 0.3 x 0.78 at +-0.68)
local function dumbbell(hand: BasePart): Model
	local model = Instance.new("Model")
	model.Name = "Dumbbell"
	local function piece(
		size: Vector3,
		offset: CFrame,
		colour: Color3,
		material: Enum.Material
	): Part
		local p = Instance.new("Part")
		p.Size = size
		p.Color = colour
		p.Material = material
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = false
		p.CFrame = hand.CFrame * offset
		local weld = Instance.new("Weld")
		weld.Part0 = hand
		weld.Part1 = p
		weld.C0 = offset
		weld.Parent = p
		p.Parent = model
		return p
	end
	local steel = Color3.fromRGB(70, 74, 92)
	piece(
		Vector3.new(0.2, 0.2, 1.7),
		CFrame.new(),
		Color3.fromRGB(190, 192, 200),
		Enum.Material.Metal
	)
	for _, z in { -0.68, 0.68 } do
		local plate = piece(
			Vector3.new(0.3, 0.78, 0.78),
			CFrame.new(0, 0, z) * CFrame.Angles(0, math.rad(90), 0),
			steel,
			Enum.Material.Metal
		)
		plate.Shape = Enum.PartType.Cylinder
	end
	return model
end

function TrainingController:_holdWeights(live: Live)
	local c = player.Character
	local holder = Instance.new("Folder")
	holder.Name = "TrainWeights"
	for _, name in { "LeftHand", "RightHand" } do
		local hand = c and c:FindFirstChild(name)
		if hand and hand:IsA("BasePart") then
			dumbbell(hand).Parent = holder
		end
	end
	holder.Parent = c
	live.weights = holder
end

-- the station signs of the player's own plot: hidden while training (they float through the shot)
local function signs(plot: number?, visible: boolean)
	local map = workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")
	local folder = plots and plot and plots:FindFirstChild("Plot" .. plot)
	if not folder then
		return
	end
	for i = 1, #TR.Stations do
		local mat = folder:FindFirstChild("Station" .. i)
		local board = mat and mat:FindFirstChild("Title", true)
		if board and board:IsA("BillboardGui") then
			board.Enabled = visible
		end
	end
end

function TrainingController:_begin(session: any)
	local state = self._state.State
	local row = TR.Stations[session.station]
	if not state or not state.plot or not row then
		return
	end
	local live: Live = {
		station = session.station,
		start = session.start,
		rep = session.rep,
		marks = {},
		judged = -1,
		combo = 0,
	}
	self._live = live
	ProximityPromptService.Enabled = false
	signs(state.plot, false)
	self:_camera(state.plot, session.station)
	local _, humanoid = character()
	local kind = KIND[row.Id] or KIND.strike
	local track = Motion.play(humanoid, row.Clip, { fade = 0.25 })
	live.track = track
	local target = targetOf(state.plot, session.station)
	for _, marker in kind.markers do
		local conn = Motion.onMarker(track, marker, function()
			self:_contact(live, target, kind)
		end)
		if conn then
			table.insert(live.marks, conn)
		end
	end
	if row.Id == "lift" then
		self:_holdWeights(live)
	end
	-- Space / gamepad A would jump (the server has already zeroed the jump): they tap instead
	ContextActionService:BindActionAtPriority(
		"TrainTap",
		function(_, inputState: Enum.UserInputState)
			if inputState == Enum.UserInputState.Begin then
				self:_tap()
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.Space,
		Enum.KeyCode.ButtonA
	)
	-- the station's name is already on its plate in the world: not repeated by the ring (owner's
	-- review 3)
	local title = find("StationTitle")
	if title and title:IsA("GuiObject") then
		title.Visible = false
	end
	local hint = find("TapHint")
	if hint and hint:IsA("TextLabel") then
		hint.Text = "TAP IN THE RING!"
		hint.Visible = true
	end
	local combo = find("Combo")
	if combo then
		combo.Visible = false
	end
end

function TrainingController:_contact(live: Live, target: Instance?, kind: any)
	if self._live ~= live then
		return
	end
	local _, _, root = character()
	if kind.sound then
		-- not placed in the world: the training camera looks from the side, so a sound on the
		-- character panned hard into one ear (owner's review 3: strike only in the left headphone)
		Sound:Play(kind.sound, nil, { pitchVary = 0.08 })
	end
	if target then
		wobble(target, if kind.effect then 1 else 0.4)
	end
	if kind.effect and root then
		-- where the fist (or the palms) meet the target: in front of the chest
		local at = root.CFrame * CFrame.new(0, 0.6, -2.2)
		Vfx.play("Train_Hit", at.Position)
	elseif not kind.effect and root then
		Vfx.play("Train_Hit", root.Position + Vector3.new(0, 1.5, 0), { scale = 0.6, mult = 0.5 })
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
	if live.weights then
		live.weights:Destroy()
	end
	ContextActionService:UnbindAction("TrainTap")
	ProximityPromptService.Enabled = true
	local state = self._state.State
	signs(state and state.plot, true)
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	local hint = find("TapHint")
	if hint then
		hint.Visible = false
	end
end

-- the phase (0..1) of the current rep on the server's clock, and the rep's index
function TrainingController:_phase(live: Live): (number, number)
	local elapsed = self._state:ServerNow() - live.start
	local rep = math.floor(elapsed / live.rep)
	return (elapsed - rep * live.rep) / live.rep, rep
end

function TrainingController:_tap()
	local live = self._live
	if not live then
		return
	end
	local phase, rep = self:_phase(live)
	local target: number? = nil
	if phase >= 1 - TR.PerfectWindow then
		target = rep
	elseif phase * live.rep <= LATE then
		target = rep - 1
	end
	if self._tapRemote then
		self._tapRemote:FireServer()
	end
	local perfect = find("PerfectLabel")
	local combo = find("Combo")
	if target and target > live.judged then
		live.judged = target
		live.combo += 1
		Sound:Play("perfect_ding", nil, { pitchVary = 0.04 })
		if perfect and perfect:IsA("TextLabel") then
			perfect.Text = "PERFECT!"
			perfect.Visible = true
			Screens.pop(perfect, 1.3)
			task.delay(0.5, function()
				if perfect.Text == "PERFECT!" then
					perfect.Visible = false
				end
			end)
		end
		if combo and combo:IsA("TextLabel") and live.combo >= 2 then
			combo.Text = `x{live.combo} COMBO`
			combo.Visible = true
			Screens.pop(combo, 1.2)
		end
		local _, _, root = character()
		if root then
			Vfx.play("PerfectThrow_Flash", root.Position + Vector3.new(0, 2, 0), { scale = 0.6 })
		end
	elseif target == nil then
		live.combo = 0
		if combo then
			combo.Visible = false
		end
		if perfect and perfect:IsA("TextLabel") then
			perfect.Text = if phase < 0.5 then "TOO EARLY" else "ALMOST!"
			perfect.Visible = true
			task.delay(0.35, function()
				if perfect.Text ~= "PERFECT!" then
					perfect.Visible = false
				end
			end)
		end
	end
end

function TrainingController:_frame()
	local live = self._live
	if not live then
		return
	end
	local phase = self:_phase(live)
	local ring = find("TimingRing")
	local shrink = ring and ring:FindFirstChild("Shrink")
	if ring and shrink and shrink:IsA("GuiObject") then
		local targetScale = (ring:GetAttribute("TargetScale") or 0.62) :: number
		local s = 1 - (1 - targetScale) * phase
		shrink.Size = UDim2.fromScale(s, s)
		local hot = phase >= 1 - TR.PerfectWindow
		shrink.BackgroundTransparency = 1
		local stroke = shrink:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if hot then Color3.fromHex("48D687") else Color3.fromHex("FFFFFF")
		end
	end
end

function TrainingController:KnitStart()
	self._state = Knit.GetController("StateController")
	self._tapRemote = Net.client("TrainTap")
	local exit = Net.client("TrainSet")
	self._state:Observe(function(state: any)
		local session = state and state.trainSession
		local live = self._live
		if
			session
			and (not live or live.station ~= session.station or live.start ~= session.start)
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
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			self:_tap()
		end
	end)
	RunService.RenderStepped:Connect(function()
		if self._live then
			local ok = pcall(function()
				self:_frame()
			end)
			if not ok then
				return
			end
		end
	end)
	player.CharacterAdded:Connect(function()
		self:_end()
	end)
end

return TrainingController
