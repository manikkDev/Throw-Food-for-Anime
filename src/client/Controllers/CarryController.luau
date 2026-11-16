--!strict
-- CarryController - a caught hero comes back in the thrower's hands (owner's review 2026-11-16):
-- they carry it overhead to any pedestal of their plot and set it down there.
--
-- The server owns the truth: the hero is already saved in a slot when it is caught; while it is
-- carried (Player attribute "Carrying" = "uid|id|mut|size|stars", PlotService:SetCarry) it is only
-- left off the plot. This draws the carried hero over EVERY carrying player's head (every client
-- builds its own, like the plot heroes), and for the local player lights up their pedestals with
-- a "Place hero" prompt. Placing plays the PlaceHero clip and sends SquadAction "place"; the
-- server clears the carry and the hero appears on that pedestal (HeroController pops it in).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Net = require(ReplicatedStorage.Shared.Net)
local CarryPath = require(ReplicatedStorage.Shared.Config.CarryPath)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local ImportedFx = require(script.Parent.Parent.Fx.ImportedFx)
local Motion = require(script.Parent.Parent.Fx.Motion)
local Vfx = require(script.Parent.Parent.Fx.Vfx)
local Theme = require(script.Parent.Parent.Ui.Theme)
local Sound = require(script.Parent.SoundController)

local MAPS = Lookup.of(Config)
local player = Players.LocalPlayer

local CARRY_SCALE = 0.55 -- the carried hero, against its plot size
local PLACE_AT = CarryPath.Place -- the PlaceHero clip's "Place" marker, if the marker never comes
local PROMPT_DISTANCE = 9

local characterStamp: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local stampCount = 0

type Carried = {
	key: string,
	model: Model,
	track: AnimationTrack?,
	seat: CFrame, -- the hero's LowerTorso from its pivot
	sway: any, -- Sway (declared below)
	pop: number, -- seconds into the arrival pop
	target: number?, -- the model's full scale
	placing: boolean?, -- the place clip moves it now
	parts: { BasePart }, -- kept non-solid every physics step
}

local CarryController = Knit.CreateController({
	Name = "CarryController",
	_carried = {} :: { [Player]: Carried },
	_prompts = {} :: { ProximityPrompt },
	_glows = {} :: { Highlight },
	_hold = nil :: AnimationTrack?,
	_placing = false,
	_toldFull = nil :: string?,
	_muted = {} :: { [ProximityPrompt]: boolean },
})

local function parse(value: any): (string?, string?, string?, string?, number)
	if typeof(value) ~= "string" or value == "" then
		return nil, nil, nil, nil, 0
	end
	local parts = string.split(value, "|")
	local function opt(text: string?): string?
		return if text and text ~= "" then text else nil
	end
	return parts[1], parts[2], opt(parts[3]), opt(parts[4]), tonumber(parts[5]) or 0
end

-- every part of a carried hero rides along: no mass, no collision, no queries, no humanoid physics.
-- Only its root is anchored (the ride moves it every frame): the limbs stay on their Motor6Ds, so
-- the hero's own ride animation plays
local function passenger(model: Model)
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = part == root
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = true
		humanoid.EvaluateStateMachine = false
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

-- WHERE the carried hero rides (owner's review after section 6: "the carry can be more realistic").
-- A SHOULDER RIDE: the hero sits on the player's RIGHT shoulder beside the head, legs over the chest,
-- its left hand on the player's head, waving with the right (CarriedRide); the player rests its feet on
-- a level right forearm (CarryShoulder, upper body only, so the walk keeps the legs). A centred
-- straddle is not possible on these rigs (the 1.2-stud block head is wider than a 0.55 hero's hips:
-- measured in work/anim/upload6/README.md). SEAT is the hero's LowerTorso centre in the carrier's root
-- space at CARRY_SCALE; the two loops are 1.6 s and start in the same frame.
-- Until those clips exist in this session the old overhead hold is used (CarryHold, GRIP).
local CARRY_CLIP, RIDE_CLIP = "CarryShoulder", "CarriedRide"
local SEAT = CFrame.new(1.25, 1.4345, -0.34)
local GRIP = CFrame.new(0, 3.31, -0.42)

local function shoulderRide(): boolean
	return Motion.has(CARRY_CLIP) and Motion.has(RIDE_CLIP)
end

-- the hero's LowerTorso relative to its model pivot (measured once, after scaling)
local function seatOffset(model: Model): CFrame
	local lower = model:FindFirstChild("LowerTorso") or model:FindFirstChild("HumanoidRootPart")
	local pivot = model:GetPivot()
	local fromPivot = if lower and lower:IsA("BasePart")
		then pivot:PointToObjectSpace(lower.Position)
		else Vector3.new(0, 1, 0)
	return CFrame.new(fromPivot)
end

-- HOW it rides: not a rigid weld. Every frame the hero follows the carrier with inertia, all of it
-- turning about the SEAT (as a body on the shoulders does):
--   * it bounces with each step (faster and higher the faster the carrier moves)
--   * it leans back when the carrier sets off and tips forward when they stop, then settles
--   * it rolls outward in a turn and its facing lags a beat behind the carrier's
-- A damped spring per axis gives the settle its small overshoot. Every client runs this for every
-- carrier, from the carrier's replicated root (it is all visual).
type Sway = {
	pitch: number,
	roll: number,
	yaw: number,
	vPitch: number,
	vRoll: number,
	vYaw: number,
	acc: Vector3,
	lastVel: Vector3?,
	lastYaw: number?,
	phase: number,
	t: number,
}
local SPRING, DAMP = 58, 7.5
local function newSway(): Sway
	return {
		pitch = 0,
		roll = 0,
		yaw = 0,
		vPitch = 0,
		vRoll = 0,
		vYaw = 0,
		acc = Vector3.zero,
		phase = 0,
		t = 0,
	}
end

local function spring(x: number, v: number, target: number, dt: number): (number, number)
	v += ((target - x) * SPRING - v * DAMP) * dt
	return x + v * dt, v
end

local function wrap(angle: number): number
	return (angle + math.pi) % (2 * math.pi) - math.pi
end

-- the frame's ride CFrame of the hero's LowerTorso, in the carrier's root space
local function ride(sway: Sway, root: BasePart, dt: number, shoulder: boolean): CFrame
	dt = math.clamp(dt, 1 / 240, 1 / 15)
	local cf = root.CFrame
	local vel = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	local localVel = cf:VectorToObjectSpace(vel)
	local last = sway.lastVel or localVel
	sway.lastVel = localVel
	sway.acc = sway.acc:Lerp((localVel - last) / dt, math.min(1, dt * 10))
	local look = cf.LookVector
	local yawNow = math.atan2(-look.X, -look.Z)
	local turn = wrap(yawNow - (sway.lastYaw or yawNow)) / dt
	sway.lastYaw = yawNow
	local speed = localVel.Magnitude
	local moving = math.min(speed / 16, 1.3)
	-- the targets (radians): inertia against the push
	-- (a Roblox character reaches full speed almost at once: ~160 studs/s/s, so the gains are small and
	-- the lean is capped at ~11 degrees, measured 17.6 uncapped)
	local pitchT = math.clamp(-sway.acc.Z * 0.008, -0.2, 0.2)
	local rollT = math.clamp(-turn * 0.06 * moving + sway.acc.X * 0.007, -0.2, 0.2)
	local yawT = math.clamp(-turn * 0.06, -0.35, 0.35)
	sway.pitch, sway.vPitch = spring(sway.pitch, sway.vPitch, pitchT, dt)
	sway.roll, sway.vRoll = spring(sway.roll, sway.vRoll, rollT, dt)
	sway.yaw, sway.vYaw = spring(sway.yaw, sway.vYaw, yawT, dt)
	-- the step bounce: up on every footfall; a slow breath when standing
	sway.phase += dt * speed * 0.62
	sway.t += dt
	local bounce = math.abs(math.sin(sway.phase)) * 0.11 * moving
	local nod = math.sin(sway.phase * 2) * 0.05 * moving
	local breath = math.sin(sway.t * 2.1) * 0.02 * (1 - math.min(moving, 1))
	local base = if shoulder then SEAT else GRIP
	return base
		* CFrame.new(0, bounce + breath, 0)
		* CFrame.Angles(sway.pitch + nod, sway.yaw, sway.roll)
end

function CarryController:_isPlaying(): boolean
	local throw = self._throw :: any
	return throw ~= nil and throw._playing == true
end

function CarryController:_drop(owner: Player)
	local carried = self._carried[owner]
	if not carried then
		return
	end
	self._carried[owner] = nil
	if carried.model.Parent then
		carried.model:Destroy()
	end
	if owner == player then
		Motion.stop(self._hold, 0.3)
		self._hold = nil
		self:_setPrompts(nil)
	end
end

-- (re)build the hero `owner` carries, or drop it
function CarryController:_refresh(owner: Player)
	local value = owner:GetAttribute("Carrying")
	local uid, id, mut, size, stars = parse(value)
	local character = owner.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local carried = self._carried[owner]
	if not uid or not id or not character or not root or not root:IsA("BasePart") then
		self:_drop(owner)
		return
	end
	-- the local player's catch is in the reveal: it comes to the hands when the reveal ends
	if owner == player and self:_isPlaying() then
		self:_drop(owner)
		return
	end
	-- a respawned character is a new carrier: number each character the first time it is seen
	local stamp = characterStamp[character]
	if not stamp then
		stampCount += 1
		stamp = stampCount
		characterStamp[character] = stamp
	end
	local key = `{value}|{stamp}`
	if carried and carried.key == key and carried.model.Parent then
		return
	end
	self:_drop(owner)
	local model, scale = self._heroes:Build(id, mut, size, true)
	model.Name = "Carried_" .. id
	model:ScaleTo(math.max(scale * CARRY_SCALE, 0.05))
	passenger(model)
	local seat = seatOffset(model)
	model:PivotTo(root.CFrame * (if shoulderRide() then SEAT else GRIP) * seat:Inverse())
	model.Parent = workspace
	local track = self._heroes:Animate(model)
	local humanoidOfHero = model:FindFirstChildOfClass("Humanoid")
	if shoulderRide() and humanoidOfHero then
		-- on the shoulders it sits and waves instead of standing in its idle
		Motion.stop(track, 0)
		track = Motion.play(humanoidOfHero, RIDE_CLIP, { fade = 0.15, looped = true })
	end
	local parts: { BasePart } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	self._carried[owner] = {
		key = key,
		model = model,
		track = track,
		seat = seat,
		sway = newSway(),
		pop = 0,
		parts = parts,
	}
	-- it arrives: a pop in (the ride loop scales it up from 20% with a little overshoot) and a lift sound
	local target = model:GetScale()
	self._carried[owner].target = target
	model:ScaleTo(target * 0.2)
	self._carried[owner].seat = seatOffset(model)
	-- no sparkle or aura while it is carried (owner's review 3): the effects wait for the pedestal
	Sound:Play("hero_pickup", root)
	if owner == player then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		self._hold = Motion.play(
			humanoid,
			if shoulderRide() then CARRY_CLIP else "CarryHold",
			{ fade = 0.25, looped = true }
		)
		self:_setPrompts(uid, id, stars)
		-- a full plot: the catch was saved on the bench. Say what to do with it, once per catch
		-- (owner's review of section 5: "what if the plots are full?")
		local state = self._state.State
		local hero = state and state.heroes and state.heroes[uid]
		if hero and hero.slot == 0 and self._toldFull ~= uid then
			self._toldFull = uid
			local hud = Knit.GetController("HudController") :: any
			hud:Toast(
				"Plot full! Swap it onto a pedestal with E, or it waits on your bench",
				"info"
			)
		end
	end
end

-- the local player's pedestals: a prompt and a soft glow on each open one while carrying
function CarryController:_setPrompts(uid: string?, id: string?, _stars: number?)
	for _, prompt in self._prompts do
		prompt:Destroy()
	end
	for _, glow in self._glows do
		glow:Destroy()
	end
	table.clear(self._prompts)
	table.clear(self._glows)
	-- while a hero is in the hands, E means "place it": the plot's other E prompts (training
	-- stations, the slot sign, the squad board) are switched off on this client. They stand in front
	-- of the pedestal rows and Roblox arms ONE prompt per key, so near those pedestals E started
	-- training instead (found in play). They come back when the hero is set down.
	for prompt in self._muted do
		if prompt.Parent then
			prompt.Enabled = true
		end
	end
	table.clear(self._muted)
	local state = self._state.State
	if not uid or not id or not state or not state.plot then
		return
	end
	local mapFolder = workspace:FindFirstChild("Map")
	local plotsFolder = mapFolder and mapFolder:FindFirstChild("Plots")
	local myPlot = plotsFolder and plotsFolder:FindFirstChild("Plot" .. state.plot)
	if myPlot then
		for _, d in myPlot:GetDescendants() do
			if
				d:IsA("ProximityPrompt")
				and d.Name ~= "PlaceHero"
				and d.Enabled
				and d.KeyboardKeyCode == Enum.KeyCode.E
			then
				d.Enabled = false
				self._muted[d] = true
			end
		end
	end
	local map = workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")
	local plot = plots and plots:FindFirstChild("Plot" .. state.plot)
	local pedestals = plot and plot:FindFirstChild("Pedestals")
	if not pedestals then
		return
	end
	local occupied: { [number]: string } = {}
	local plotState = self._state.Plots[state.plot]
	if plotState then
		for _, entry in plotState.heroes do
			local row = MAPS.character[entry.id] or MAPS.premium[entry.id]
			occupied[entry.s] = if row then row.Name else entry.id
		end
	end
	local row = MAPS.character[id] or MAPS.premium[id]
	local color = Theme.rarity(if row and row.Rarity then row.Rarity else "Premium")
	for _, pedestal in pedestals:GetChildren() do
		local slot = pedestal:GetAttribute("Slot")
		if pedestal:IsA("BasePart") and typeof(slot) == "number" and slot <= (state.slots or 0) then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "PlaceHero"
			prompt.ActionText = if occupied[slot] then "Swap here" else "Place hero"
			prompt.ObjectText = if occupied[slot]
				then `replaces {occupied[slot]}`
				else `Pedestal {slot}`
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = PROMPT_DISTANCE
			prompt.RequiresLineOfSight = false
			prompt.UIOffset = Vector2.new(0, 40)
			-- the custom prompt (PromptController) tints its key cap with this
			prompt:SetAttribute("Accent", Color3.fromHex("37D67A"))
			prompt.Triggered:Connect(function()
				self:_place(uid, slot, pedestal)
			end)
			prompt.Parent = pedestal
			table.insert(self._prompts, prompt)
			if not occupied[slot] then
				local glow = Instance.new("Highlight")
				glow.Adornee = pedestal
				glow.FillColor = color
				glow.OutlineColor = Color3.new(1, 1, 1)
				glow.FillTransparency = 0.55
				glow.OutlineTransparency = 0.2
				glow.DepthMode = Enum.HighlightDepthMode.Occluded
				glow.Parent = pedestal
				table.insert(self._glows, glow)
			end
		end
	end
end

-- set the carried hero down on `slot`
function CarryController:_place(uid: string, slot: number, pedestal: BasePart)
	if self._placing then
		return
	end
	self._placing = true
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		-- face the pedestal
		local at = root.Position
		local to = Vector3.new(pedestal.Position.X, at.Y, pedestal.Position.Z)
		if (to - at).Magnitude > 0.5 then
			root.CFrame = CFrame.lookAt(at, to)
		end
	end
	Motion.stop(self._hold, 0.15)
	self._hold = nil
	local track = Motion.play(humanoid, "PlaceHero", { fade = 0.1 })
	-- the hero travels with the hands (CarryPath: the clip's own hero path): it hops off the shoulder,
	-- is caught under the arms (Grab: it stops riding and hangs standing) and set on the pedestal
	local carried = self._carried[player]
	local follow: RBXScriptConnection? = nil
	if track and carried and shoulderRide() and root and root:IsA("BasePart") then
		carried.placing = true
		local started = os.clock()
		local grabbed = false
		local frames = CarryPath.LowerTorso
		follow = RunService.RenderStepped:Connect(function()
			if not carried.model.Parent then
				return
			end
			local t = if track.IsPlaying then track.TimePosition else os.clock() - started
			local at = math.clamp(t * CarryPath.Fps + 1, 1, #frames)
			local i = math.floor(at)
			local a, b = frames[i], frames[math.min(i + 1, #frames)]
			local pos = a:Lerp(b, at - i)
			if t >= CarryPath.Grab and not grabbed then
				grabbed = true
				Motion.stop(carried.track, 0.1)
			end
			if carried.target then
				carried.model:ScaleTo(carried.target)
			end
			carried.model:PivotTo(root.CFrame * CFrame.new(pos) * carried.seat:Inverse())
		end)
	end
	local done = false
	local function commit()
		if done then
			return
		end
		done = true
		if follow then
			follow:Disconnect()
		end
		self._heroes:ExpectPlace(uid)
		self._squadAction:FireServer("place", uid, slot)
		local top = pedestal.Position + Vector3.new(0, pedestal.Size.Y / 2, 0)
		local rarity = "Common"
		if carried then
			local row = MAPS.character[(carried.model.Name:gsub("^Carried_", ""))]
			rarity = if row then row.Rarity else "Premium"
		end
		Sound:Play("hero_place", pedestal)
		ImportedFx.play("LandingImpact", CFrame.new(top), { scale = 0.45, mult = 0.6 })
		Vfx.play("Reveal_" .. rarity, top, { scale = 0.6, tint = Theme.rarity(rarity), mult = 0.5 })
		self:_drop(player)
		task.delay(0.6, function()
			self._placing = false
		end)
	end
	if track then
		Motion.onMarker(track, "Place", commit)
	end
	task.delay(if track then PLACE_AT + 0.25 else 0, commit)
end

function CarryController:KnitStart()
	self._heroes = Knit.GetController("HeroController")
	self._state = Knit.GetController("StateController")
	self._throw = Knit.GetController("ThrowController")
	self._squadAction = Net.client("SquadAction")

	local function watch(owner: Player)
		owner:GetAttributeChangedSignal("Carrying"):Connect(function()
			self:_refresh(owner)
		end)
		owner.CharacterAdded:Connect(function()
			task.defer(function()
				self:_refresh(owner)
			end)
		end)
		self:_refresh(owner)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(owner: Player)
		self:_drop(owner)
	end)
	for _, owner in Players:GetPlayers() do
		task.spawn(watch, owner)
	end

	-- a carried hero is never solid. Its Humanoid switches CanCollide back ON for its torso every
	-- physics step, and on the shoulder those parts overlap the carrier, who was then shoved and
	-- turned by them ("walking like a drunk, no control", owner's report). Off again before each step.
	RunService.Stepped:Connect(function()
		for _, carried in self._carried do
			for _, part in carried.parts do
				if part.CanCollide then
					part.CanCollide = false
				end
			end
		end
	end)

	-- every carried hero, every frame: the ride (and the arrival pop)
	RunService.RenderStepped:Connect(function(dt: number)
		local shoulder = shoulderRide()
		for owner, carried in self._carried do
			local character = owner.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local model = carried.model
			if not root or not root:IsA("BasePart") or not model.Parent or carried.placing then
				continue
			end
			local target = carried.target
			if target and carried.pop < 0.3 then
				carried.pop += dt
				local u = math.min(carried.pop / 0.3, 1)
				local back = 1 + 2.2 * (u - 1) ^ 3 + 1.2 * (u - 1) ^ 2 -- ease out with a little overshoot
				model:ScaleTo(target * math.max(0.2 + 0.8 * back, 0.05))
				if u >= 1 then
					model:ScaleTo(target)
					carried.seat = seatOffset(model)
				end
			end
			local seatCF = root.CFrame * ride(carried.sway, root, dt, shoulder)
			model:PivotTo(seatCF * carried.seat:Inverse())
		end
	end)

	-- the local catch reaches the hands when its reveal is over; slots bought or heroes moved
	-- change which prompts show
	local wasPlaying = false
	RunService.Heartbeat:Connect(function()
		local playing = self:_isPlaying()
		local ended = wasPlaying and not playing
		wasPlaying = playing
		if ended then
			local ok, err = pcall(self._refresh, self, player)
			if not ok then
				warn(`[CarryController] carry failed inert: {err}`)
			end
		end
	end)
	self._state:ObservePlots(function(plot: number)
		local state = self._state.State
		if state and plot == state.plot and self._carried[player] and not self._placing then
			local uid, id, _, _, stars = parse(player:GetAttribute("Carrying"))
			self:_setPrompts(uid, id, stars)
		end
	end)
end

return CarryController
