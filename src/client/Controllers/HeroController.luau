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
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local World = require(ReplicatedStorage.Shared.Core.World)
local Screens = require(script.Parent.Parent.Ui.Screens)
local Theme = require(script.Parent.Parent.Ui.Theme)

local MAPS = Lookup.of(Config)
local W = Config.World
local COUNT = Config.Server.PlotCount
local DASH = Config.Throw.DashSeconds
-- Roblox's own R15 idle: owned by Roblox, so it plays in any experience.
-- Section 4 replaces it with the authored idles named in Config.Characters.
local IDLE_ANIMATION = "rbxassetid://507766388"

local MUTATION_COLORS = Theme.MUTATION

-- The Nameplate tree is authored in pixels (320 x 132). Over a hero it is
-- sized in studs instead, and kept small: a plot can hold 28 heroes, and 28
-- full plates are a wall of text. So a plate is ONE line (name and income),
-- shown only near the camera (PLATE_DISTANCE) and never during a throw
-- sequence; only the plate the camera is aimed at opens up to show its tags
-- and stars.
local PLATE_STUDS = 6.5
local PLATE_DISTANCE = 35
local PLATE_LINE = 48 / 132 -- the name line's share of the plate's height
local FOCUS_SECONDS = 0.25
local FOCUS_AIM = 0.94 -- cosine of how far off the camera's aim still counts

type Record = {
	key: string,
	plot: number,
	entry: any,
	model: Model?,
	thread: thread?,
	track: AnimationTrack?,
	plate: Plate?,
}

type Plate = {
	gui: BillboardGui,
	scale: UIScale,
	width: number,
	studsWide: number,
	studsHigh: number,
	headTop: number,
	name: TextLabel,
	income: TextLabel,
	focused: boolean,
}

type Dash = { model: Model, from: Vector3, goal: CFrame, t0: number }

local HeroController = Knit.CreateController({
	Name = "HeroController",
	_rigs = {} :: { [number]: { [number]: Record } },
	_dashes = {} :: { [Model]: Dash },
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

local function displayName(id: string): string
	local row = MAPS.character[id] or MAPS.premium[id]
	return if row then row.Name else id
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
function HeroController:Build(id: string, mut: string?, size: string?): (Model, number)
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
	if mut and MUTATION_COLORS[mut] then
		-- placeholder aura: a glowing ring at the feet. Section 4 replaces it
		-- with the authored Aura_<Mutation> effect.
		local ring = Instance.new("Part")
		ring.Name = "AuraRing"
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.25, 7 * scale, 7 * scale)
		ring.CFrame = model:GetPivot() * CFrame.Angles(0, 0, math.rad(90))
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.Material = Enum.Material.Neon
		ring.Color = MUTATION_COLORS[mut]
		ring.Transparency = 0.25
		ring.Parent = model
	end
	return model, scale
end

--- Start the idle on a model that is now in the world and return its track.
--- Fails inert (returns nil).
function HeroController:Animate(model: Model): AnimationTrack?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end
	local track: AnimationTrack? = nil
	local ok, err = pcall(function()
		local animation = Instance.new("Animation")
		animation.AnimationId = IDLE_ANIMATION
		local loaded = animator:LoadAnimation(animation)
		loaded.Looped = true
		loaded:Play(0.2)
		loaded.TimePosition = math.random() * 2
		track = loaded
	end)
	if not ok then
		warn(`[HeroController] idle failed inert: {err}`)
	end
	return track
end

-- keep the plate's contents the size of the plate on screen
local function fitPlate(plate: Plate)
	local target = math.clamp(plate.gui.AbsoluteSize.X / plate.width, 0.05, 1)
	if math.abs(plate.scale.Scale - target) > 0.03 * target then
		plate.scale.Scale = target
	end
end

-- What a plate says. One line unless it is the plate the camera is aimed at.
local function writePlate(plate: Plate, entry: any)
	local gui = plate.gui
	local focused = plate.focused
	local name = displayName(entry.id)
	local income = `+{Format.short(entry.i or 0)}/s`
	plate.name.Text = if focused then name else `{name}  {income}`
	plate.income.Text = income
	Screens.frame(gui, "TagRow").Visible = focused and (entry.z ~= nil or entry.m ~= nil)
	Screens.frame(gui, "BottomRow").Visible = focused
	local high = if focused then plate.studsHigh else plate.studsHigh * PLATE_LINE
	gui.Size = UDim2.fromScale(plate.studsWide, high)
	gui.StudsOffsetWorldSpace = Vector3.new(0, plate.headTop + 0.4 + high / 2, 0)
end

-- The plate over a hero: name and yen/s; tags and star pips when focused.
local function makePlate(model: Model, entry: any, scale: number, hidden: boolean): Plate?
	local root = model.PrimaryPart
	local gui = Screens.world("Nameplate")
	if not root or not gui or not gui:IsA("BillboardGui") then
		return nil
	end
	local canvas = Screens.frame(gui, "CanvasFrame")
	local refWidth = canvas:GetAttribute("RefWidth")
	local refHeight = canvas:GetAttribute("RefHeight")
	local width = if typeof(refWidth) == "number" then refWidth else 320
	local height = if typeof(refHeight) == "number" then refHeight else 132
	local studsWide = PLATE_STUDS * (1 + (scale - 1) * 0.5)
	local box, size = model:GetBoundingBox()
	gui.StudsOffset = Vector3.zero
	gui.MaxDistance = PLATE_DISTANCE
	gui.Adornee = root
	gui.Enabled = not hidden
	-- the canvas keeps its authored pixel size, hangs from the top of the
	-- plate, and is scaled to the plate's size on screen
	canvas.AnchorPoint = Vector2.new(0.5, 0)
	canvas.Position = UDim2.fromScale(0.5, 0)
	canvas.Size = UDim2.fromOffset(width, height)
	local uiScale = Instance.new("UIScale")
	uiScale.Name = "PlateScale"
	uiScale.Parent = canvas

	local name = Screens.label(gui, "HeroName")
	name.TextColor3 = rarityColor(entry.id)
	Screens.frame(gui, "SizeTagCell").Visible = entry.z ~= nil
	Screens.label(gui, "SizeText").Text = if entry.z then entry.z:upper() else ""
	Screens.frame(gui, "MutationTagCell").Visible = entry.m ~= nil
	Screens.label(gui, "MutationText").Text = if entry.m then entry.m:upper() else ""
	Screens.tint(Screens.frame(gui, "MutationTag"), Theme.mutation(entry.m))
	for star = 1, 3 do
		Screens.image(gui, "Star" .. star).Visible = star <= (entry.st or 0)
	end

	local made: Plate = {
		gui = gui,
		scale = uiScale,
		width = width,
		studsWide = studsWide,
		studsHigh = studsWide * height / width,
		headTop = box.Position.Y + size.Y / 2 - root.Position.Y,
		name = name,
		income = Screens.label(gui, "YenPerSecond"),
		focused = false,
	}
	writePlate(made, entry)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		fitPlate(made)
	end)
	gui.Parent = root
	return made
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
		writePlate(was.plate, was.entry)
	end
	if best and best.plate then
		best.plate.focused = true
		writePlate(best.plate, best.entry)
	end
end

function HeroController:_goal(plot: number, slot: number): CFrame
	local x, z = World.pedestal(W, plot, COUNT, slot)
	-- templates face -Z; heroes on a plot face the lane (+Z)
	return CFrame.new(x, W.GroundY + W.PedestalTop, z) * CFrame.Angles(0, math.pi, 0)
end

function HeroController:_show(record: Record, dashIn: boolean)
	if record.model or not self._folder then
		return
	end
	local entry = record.entry
	local model, scale = self:Build(entry.id, entry.m, entry.z)
	record.plate = makePlate(model, entry, scale, self._platesHidden)
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
		self._dashes[model] = { model = model, from = from, goal = goal, t0 = os.clock() }
	else
		model:PivotTo(goal)
		model.Parent = self._folder
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
	elseif not visible and model.Parent ~= nil then
		model.Parent = nil
	end
	if visible and record.plate then
		fitPlate(record.plate)
	end
	local animate = visible and not low and distance <= W.HeroAnimateDistance
	if animate and not record.track then
		record.track = self:Animate(model)
	elseif not animate and record.track then
		record.track:Stop(0)
		record.track:Destroy()
		record.track = nil
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
		self._dashes[model] = nil
		model:Destroy()
		record.model = nil
	end
end

function HeroController:_spawn(plot: number, entry: any, key: string): Record
	local record: Record = { key = key, plot = plot, entry = entry }
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
					writePlate(have.plate, entry)
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
				if model.Parent then
					model:PivotTo(dash.goal)
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
