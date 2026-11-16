--!strict
-- HeroController - every hero rig in the world, built on THIS client.
--
-- The server sends a compact state per plot (slot, hero id, mutation, size,
-- stars); this controller turns it into rigs cloned from the baked templates
-- in ReplicatedStorage.Assets.Characters. The server never spawns a rig, so a
-- full server costs it nothing and no Humanoid is ever replicated.
--
-- A hero whose entry carries a future arrival time `t` is not shown until its
-- throw has landed and been revealed; then it dashes in from the lane.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local World = require(ReplicatedStorage.Shared.Core.World)
local Motion = require(script.Parent.Parent.Fx.Motion)
local Vfx = require(script.Parent.Parent.Fx.Vfx)
local Nameplate = require(script.Parent.Parent.Ui.Nameplate)
local Theme = require(script.Parent.Parent.Ui.Theme)
local Sound = require(script.Parent.SoundController)

local MAPS = Lookup.of(Config)
local W = Config.World
local COUNT = Config.Server.PlotCount
local DASH = Config.Throw.DashSeconds
-- Roblox's own R15 idle and run: owned by Roblox, so they play in any
-- experience. The idle is only the fallback for a hero whose authored idle
-- (Config.Characters[].Idle) is not uploaded or registered yet; the run is the
-- dash home.
local IDLE_ANIMATION = "rbxassetid://507766388"
local RUN_ANIMATION = "rbxassetid://913376220"
-- a random Roblox emote every EMOTE_MIN..EMOTE_MAX seconds on the pedestal
local EMOTE_MIN, EMOTE_MAX = 20, 40
local EMOTE_LONGEST = 6

local MUTATION_COLORS = Theme.MUTATION

-- the plate over each hero is Ui/Nameplate (what it shows); here only which
-- heroes have one and which is focused (the nearest the camera is aimed at)
local PLATE_DISTANCE = Nameplate.DISTANCE
local FOCUS_SECONDS = 0.25
local FOCUS_AIM = 0.94 -- cosine of how far off the camera's aim still counts

type Record = {
	key: string,
	plot: number,
	entry: any,
	model: Model?,
	thread: thread?,
	track: AnimationTrack?,
	emote: AnimationTrack?,
	nextEmote: number,
	plate: Nameplate.Plate?,
}

type Dash = {
	model: Model,
	from: Vector3,
	goal: CFrame,
	t0: number,
	fx: Vfx.Handle,
	run: AnimationTrack?,
	own: boolean,
}

local HeroController = Knit.CreateController({
	Name = "HeroController",
	_rigs = {} :: { [number]: { [number]: Record } },
	_dashes = {} :: { [Model]: Dash },
	_expected = {} :: { [string]: number },
	_folder = nil :: Folder?,
	_templates = nil :: Instance?,
	_state = nil :: any,
	_platesHidden = false,
	_focus = nil :: Record?,
})

local function rarityColor(id: string): Color3
	local character = MAPS.character[id]
	if character then
		return Color3.fromHex(Config.Rarities[character.Rarity].Color)
	end
	return Color3.fromRGB(255, 79, 163) -- premium
end

-- A stand-in for a hero whose template is not in the place yet (the premium
-- heroes, until their avatars are imported). Loud on purpose.
local function placeholder(id: string): Model
	local model = Instance.new("Model")
	model.Name = "Char_" .. id
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2.4, 5, 1.4)
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Color = rarityColor(id)
	root.Material = Enum.Material.Neon
	root.PivotOffset = CFrame.new(0, -2.5, 0)
	root.Parent = model
	model.PrimaryPart = root
	return model
end

-- Templates are baked with the pivot at the soles, under the root, and every
-- caller places that point (a pedestal top, the lane). Re-check it on the
-- built model: after ScaleTo a pivot that was even slightly off the soles is
-- off by that much times the scale, and a Titan sinks into its pedestal or
-- stands beside it.
local function settle(model: Model, scale: number)
	local root = model.PrimaryPart
	if not root then
		return
	end
	local lowest = math.huge
	local function consider(piece: BasePart)
		local cf, half = piece.CFrame, piece.Size / 2
		local reach = math.abs(cf.XVector.Y) * half.X
			+ math.abs(cf.YVector.Y) * half.Y
			+ math.abs(cf.ZVector.Y) * half.Z
		lowest = math.min(lowest, cf.Position.Y - reach)
	end
	for _, name in { "LeftFoot", "RightFoot" } do
		local foot = model:FindFirstChild(name, true)
		if foot and foot:IsA("BasePart") then
			consider(foot)
		end
	end
	if lowest == math.huge then
		for _, piece in model:GetDescendants() do
			if piece:IsA("BasePart") then
				consider(piece)
			end
		end
	end
	if lowest == math.huge then
		return
	end
	local pivot = model:GetPivot()
	local at = pivot.Position
	local centre = root.Position
	local offCentre = Vector2.new(at.X - centre.X, at.Z - centre.Z).Magnitude > 0.5 * scale
	local x = if offCentre then centre.X else at.X
	local z = if offCentre then centre.Z else at.Z
	if offCentre or math.abs(at.Y - lowest) > 0.02 then
		local wanted = pivot.Rotation + Vector3.new(x, lowest, z)
		root.PivotOffset = root.CFrame:ToObjectSpace(wanted)
	end
end

--- A hero model for (id, mutation, size), not parented. Used for plots and
--- for the reveal at the landing spot.
function HeroController:Build(
	id: string,
	mut: string?,
	size: string?,
	bare: boolean?
): (Model, number)
	local template = self._templates and self._templates:FindFirstChild("Char_" .. id)
	local model: Model
	if template and template:IsA("Model") then
		model = template:Clone()
	else
		model = placeholder(id)
	end
	local sizeRow = if size then MAPS.size[size] else nil
	local scale = if sizeRow then sizeRow.Scale else 1
	if scale ~= 1 then
		-- about the pivot (the soles): the hero grows upward from its feet
		model:ScaleTo(scale)
	end
	settle(model, scale)
	-- the auras: Aura_<Mutation> on a mutated hero, Aura_Titan under a Titan.
	-- Fx/Vfx decides which are live (the nearest 24 in the world).
	local auras: { string } = {}
	if mut and MUTATION_COLORS[mut] then
		table.insert(auras, "Aura_" .. mut)
	end
	if size == "Titan" then
		table.insert(auras, "Aura_Titan")
	end
	-- and the hero's own character aura (design/auras.json, by rarity or hand-matched)
	local heroKey = if bare then nil else Vfx.heroAuraKey(id)
	if not bare and (#auras > 0 or heroKey) then
		Vfx.aura(model, auras, scale, if mut then MUTATION_COLORS[mut] else nil, heroKey)
	end
	return model, scale
end

-- the id a built hero model stands for ("Char_<id>")
local function idOf(model: Model): string
	return (model.Name:gsub("^Char_", ""))
end

--- Start the idle on a model that is now in the world and return its track.
--- Fails inert (returns nil).
function HeroController:Animate(model: Model): AnimationTrack?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end
	local id = idOf(model)
	local row = MAPS.character[id] or MAPS.premium[id]
	local idle = if row and typeof(row.Idle) == "string" then row.Idle else nil
	-- the hero's own idle at Core priority, else Roblox's
	local track = if idle then Motion.play(humanoid, idle, { fade = 0.2 }) else nil
	if not track then
		track = Motion.playId(
			humanoid,
			IDLE_ANIMATION,
			{ fade = 0.2, looped = true, priority = "Core" }
		)
	end
	if track then
		local playing = track
		pcall(function()
			-- heroes side by side never breathe in step
			playing.TimePosition = math.random() * math.max(playing.Length, 1)
		end)
	end
	return track
end

--- The caught hero's entrance at the final beat of a reveal (`holding`: it already holds the
--- food, so only the bite): RevealLand
--- (Land_Impact at the feet on its "Land" marker), then Eat (eat_munch on each
--- "Bite"), over its idle. Without the clips it simply idles.
function HeroController:RevealAnimate(model: Model, holding: boolean?)
	local ok, err = pcall(function()
		self:Animate(model)
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if holding and humanoid then
			-- it picked the food up in the suspense (owner's review 4): no landing, a bite of it
			local eat = Motion.play(humanoid, "Eat", { fade = 0.2 })
			Motion.onMarker(eat, "Bite", function()
				Sound:Play("eat_munch", model.PrimaryPart, { pitchVary = 0.08 })
			end)
			return
		end
		local land = if humanoid then Motion.play(humanoid, "RevealLand", { fade = 0.05 }) else nil
		if not land then
			return
		end
		Motion.onMarker(land, "Land", function()
			Vfx.play("Land_Impact", model:GetPivot().Position, { scale = model:GetScale() })
		end)
		land.Stopped:Once(function()
			if not model.Parent then
				return
			end
			local eat = Motion.play(humanoid, "Eat", { fade = 0.1 })
			Motion.onMarker(eat, "Bite", function()
				Sound:Play("eat_munch", model.PrimaryPart, { pitchVary = 0.08 })
			end)
		end)
	end)
	if not ok then
		warn(`[HeroController] reveal clips failed inert: {err}`)
	end
end

--- Hide every nameplate (a throw sequence is playing) or bring them back.
function HeroController:SetPlatesHidden(hidden: boolean)
	if hidden == self._platesHidden then
		return
	end
	self._platesHidden = hidden
	for _, slots in self._rigs do
		for _, record in slots do
			if record.plate then
				record.plate.gui.Enabled = not hidden
			end
		end
	end
end

-- The one plate that shows its tags and stars: the nearest hero the camera
-- is aimed at, if any is close enough to have a plate at all.
function HeroController:_refocus()
	if self._platesHidden then
		return
	end
	local camera = workspace.CurrentCamera
	local eye, aim = camera.CFrame.Position, camera.CFrame.LookVector
	local best: Record? = nil
	local bestAim = FOCUS_AIM
	for _, slots in self._rigs do
		for _, record in slots do
			local model = record.model
			if model and model.Parent and record.plate then
				local to = model:GetPivot().Position + Vector3.new(0, 3, 0) - eye
				local distance = to.Magnitude
				if distance <= PLATE_DISTANCE and distance > 0.1 then
					local onAim = to:Dot(aim) / distance
					if onAim > bestAim then
						bestAim = onAim
						best = record
					end
				end
			end
		end
	end
	local was = self._focus
	if was == best then
		return
	end
	self._focus = best
	if was and was.plate then
		was.plate.focused = false
		Nameplate.write(was.plate, was.entry)
	end
	if best and best.plate then
		best.plate.focused = true
		Nameplate.write(best.plate, best.entry)
	end
end

function HeroController:_goal(plot: number, slot: number): CFrame
	local x, z = World.pedestal(W, plot, COUNT, slot)
	-- templates face -Z; heroes on a plot face the lane (+Z)
	return CFrame.new(x, W.GroundY + W.PedestalTop, z) * CFrame.Angles(0, math.pi, 0)
end

--- The local player is setting hero `uid` on a pedestal (CarryController): when it appears there,
--- it pops in instead of just standing there.
function HeroController:ExpectPlace(uid: string)
	self._expected[uid] = os.clock()
end

-- a placed hero grows in from small with a little overshoot
-- (the aura waits for the full size: Vfx skips a model while "Popping" is set)
local function popIn(model: Model)
	local target = model:GetScale()
	model:SetAttribute("Popping", true)
	model:ScaleTo(target * 0.25)
	task.spawn(function()
		local t0 = os.clock()
		while model.Parent and os.clock() - t0 < 0.4 do
			local u = (os.clock() - t0) / 0.4
			local back = 1 + 2.4 * (u - 1) ^ 3 + 1.4 * (u - 1) ^ 2
			model:ScaleTo(target * math.max(0.25 + 0.75 * back, 0.05))
			RunService.Heartbeat:Wait()
		end
		model:ScaleTo(target)
		model:SetAttribute("Popping", nil)
		Vfx.touchAuras()
	end)
end

function HeroController:_show(record: Record, dashIn: boolean)
	if record.model or not self._folder then
		return
	end
	local placed = self._expected[record.entry.u]
	if placed then
		self._expected[record.entry.u] = nil
		if os.clock() - placed < 5 then
			dashIn = false
		else
			placed = nil
		end
	end
	local entry = record.entry
	local model, scale = self:Build(entry.id, entry.m, entry.z)
	record.plate = Nameplate.make(model, entry, scale, self._platesHidden)
	local goal = self:_goal(record.plot, entry.s)
	record.model = model
	if dashIn then
		local from = Vector3.new(
			World.plotX(W, record.plot, COUNT),
			W.GroundY + W.PedestalTop,
			W.PlotFrontZ + 18
		)
		model:PivotTo(CFrame.lookAt(from, Vector3.new(goal.X, from.Y, goal.Z)))
		model.Parent = self._folder
		-- the dash home: Roblox's run, a trail, a whoosh
		local root = model.PrimaryPart
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local state = self._state.State
		self._dashes[model] = {
			model = model,
			from = from,
			goal = goal,
			t0 = os.clock(),
			fx = Vfx.play("DashHome_Trail", root or from, { loop = true }),
			run = Motion.playId(
				humanoid,
				RUN_ANIMATION,
				{ fade = 0.1, looped = true, speed = 1.5 }
			),
			own = state ~= nil and state.plot == record.plot,
		}
		Sound:Play("dash_whoosh", root)
	else
		model:PivotTo(goal)
		model.Parent = self._folder
		if placed then
			popIn(model)
		end
	end
	self:_budget(record)
end

-- Decide, for one hero, whether it is drawn and whether it is animated.
-- Budget (Config.World): beyond HeroViewDistance a hero is not drawn, beyond
-- HeroAnimateDistance it stands still. "Hide other plots" draws only your own,
-- "Low detail" turns idles off and pulls the view distance in.
function HeroController:_budget(record: Record)
	local model = record.model
	if not model or not self._folder or self._dashes[model] then
		return
	end
	local state = self._state.State
	local settings = if state then state.settings else nil
	local low = settings ~= nil and settings.lowDetail == true
	local hideOthers = settings ~= nil and settings.hideOthers == true
	local own = state ~= nil and state.plot == record.plot
	local camera = workspace.CurrentCamera
	local distance = (model:GetPivot().Position - camera.CFrame.Position).Magnitude
	local viewDistance = W.HeroViewDistance * (if low then 0.6 else 1)
	local visible = distance <= viewDistance and (own or not hideOthers)
	if visible and model.Parent ~= self._folder then
		model.Parent = self._folder
		Vfx.touchAuras() -- shown or hidden: the aura budget is re-checked now
	elseif not visible and model.Parent ~= nil then
		model.Parent = nil
		Vfx.touchAuras()
	end
	if visible and record.plate then
		Nameplate.fit(record.plate)
	end
	local animate = visible and not low and distance <= W.HeroAnimateDistance
	if animate and not record.track then
		record.track = self:Animate(model)
		record.nextEmote = os.clock() + math.random(EMOTE_MIN, EMOTE_MAX)
	elseif not animate and record.track then
		-- only stopped: Fx/Motion keeps one track per clip per rig
		Motion.stop(record.track, 0)
		Motion.stop(record.emote, 0)
		record.track = nil
		record.emote = nil
	elseif animate and os.clock() >= record.nextEmote then
		self:_emote(record, model)
	end
end

-- A random Roblox emote on a hero standing on its pedestal, now and then.
function HeroController:_emote(record: Record, model: Model)
	record.nextEmote = os.clock() + math.random(EMOTE_MIN, EMOTE_MAX)
	local emotes = Motion.emotes()
	if #emotes == 0 then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local track =
		Motion.playId(humanoid, emotes[math.random(1, #emotes)], { fade = 0.3, looped = false })
	if track then
		record.emote = track
		local length = if track.Length > 0 then math.clamp(track.Length, 1, EMOTE_LONGEST) else 4
		task.delay(length, function()
			if record.emote == track then
				Motion.stop(track, 0.3)
				record.emote = nil
			end
		end)
	end
end

function HeroController:_drop(record: Record)
	record.track = nil
	record.plate = nil
	if self._focus == record then
		self._focus = nil
	end
	if record.thread then
		pcall(task.cancel, record.thread)
		record.thread = nil
	end
	local model = record.model
	if model then
		local dash = self._dashes[model]
		if dash then
			dash.fx.stop()
		end
		self._dashes[model] = nil
		model:Destroy()
		record.model = nil
	end
end

function HeroController:_spawn(plot: number, entry: any, key: string): Record
	local record: Record = { key = key, plot = plot, entry = entry, nextEmote = 0 }
	local wait = if entry.t then entry.t - workspace:GetServerTimeNow() - DASH else 0
	if wait > 0.05 then
		record.thread = task.delay(wait, function()
			record.thread = nil
			self:_show(record, true)
		end)
	else
		self:_show(record, entry.t ~= nil)
	end
	return record
end

--- Bring a hero that is still "on its way" in right now (the thrower skipped
--- the reveal).
function HeroController:ArriveNow(uid: string)
	for _, slots in self._rigs do
		for _, record in slots do
			if record.entry.u == uid and record.thread then
				pcall(task.cancel, record.thread)
				record.thread = nil
				self:_show(record, true)
				return
			end
		end
	end
end

function HeroController:_render(plot: number, state: any)
	local current = self._rigs[plot]
	if not current then
		current = {}
		self._rigs[plot] = current
	end
	local seen: { [number]: boolean } = {}
	if state then
		for _, entry in state.heroes do
			local key = `{entry.u}|{entry.id}|{entry.m}|{entry.z}|{entry.st}`
			seen[entry.s] = true
			local have = current[entry.s]
			if have and have.key == key then
				-- same hero: only its income line can have changed
				local income = have.entry.i
				have.entry = entry
				if income ~= entry.i and have.plate then
					Nameplate.write(have.plate, entry)
				end
			else
				if have then
					self:_drop(have)
				end
				current[entry.s] = self:_spawn(plot, entry, key)
			end
		end
	end
	for slot, record in current do
		if not seen[slot] then
			self:_drop(record)
			current[slot] = nil
		end
	end
end

function HeroController:KnitStart()
	local folder = Instance.new("Folder")
	folder.Name = "Heroes"
	folder.Parent = workspace
	self._folder = folder

	local assets = ReplicatedStorage:WaitForChild("Assets", 10)
	self._templates = assets and assets:WaitForChild("Characters", 10)
	if not self._templates then
		warn("[HeroController] ReplicatedStorage.Assets.Characters is missing: placeholders only")
	end

	local StateController = Knit.GetController("StateController")
	self._state = StateController
	StateController:ObservePlots(function(plot: number, state: any)
		local ok, err = pcall(function()
			self:_render(plot, state)
		end)
		if not ok then
			warn(`[HeroController] render of plot {plot} failed: {err}`)
		end
	end)

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for model, dash in self._dashes do
			local alpha = math.clamp((now - dash.t0) / DASH, 0, 1)
			if alpha >= 1 or not model.Parent then
				self._dashes[model] = nil
				dash.fx.stop()
				Motion.stop(dash.run, 0.2)
				if model.Parent then
					model:PivotTo(dash.goal)
					if dash.own then
						-- home: the hero starts earning
						Vfx.play("Coin_Pop", dash.goal.Position + Vector3.new(0, 3, 0))
						Sound:Play("coin_tick")
					end
				end
				for _, slots in self._rigs do
					for _, record in slots do
						if record.model == model then
							self:_budget(record)
						end
					end
				end
			else
				local eased = 1 - (1 - alpha) ^ 3
				local position = dash.from:Lerp(dash.goal.Position, eased)
				model:PivotTo(
					CFrame.lookAt(position, dash.goal.Position + Vector3.new(0, 0, -0.01))
				)
			end
		end
	end)

	-- which plate is open follows the camera's aim, a few times a second
	task.spawn(function()
		while true do
			task.wait(FOCUS_SECONDS)
			self:_refocus()
		end
	end)

	-- the draw and animation budget, re-checked for every hero about once a second
	task.spawn(function()
		while true do
			task.wait(0.8)
			for _, slots in self._rigs do
				for _, record in slots do
					self:_budget(record)
				end
			end
		end
	end)
end

return HeroController
