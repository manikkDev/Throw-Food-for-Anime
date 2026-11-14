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

local MAPS = Lookup.of(Config)
local W = Config.World
local COUNT = Config.Server.PlotCount
local DASH = Config.Throw.DashSeconds
-- Roblox's own R15 idle: owned by Roblox, so it plays in any experience.
-- Section 4 replaces it with the authored idles named in Config.Characters.
local IDLE_ANIMATION = "rbxassetid://507766388"

local MUTATION_COLORS: { [string]: Color3 } = {
	Golden = Color3.fromRGB(255, 210, 60),
	Flame = Color3.fromRGB(255, 110, 40),
	Lightning = Color3.fromRGB(120, 200, 255),
	Galaxy = Color3.fromRGB(190, 110, 255),
}

type Record = {
	key: string,
	plot: number,
	entry: any,
	model: Model?,
	thread: thread?,
	track: AnimationTrack?,
}

type Dash = { model: Model, from: Vector3, goal: CFrame, t0: number }

local HeroController = Knit.CreateController({
	Name = "HeroController",
	_rigs = {} :: { [number]: { [number]: Record } },
	_dashes = {} :: { [Model]: Dash },
	_folder = nil :: Folder?,
	_templates = nil :: Instance?,
	_state = nil :: any,
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
		model:ScaleTo(scale)
	end
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

local function plate(model: Model, entry: any, scale: number)
	local root = model.PrimaryPart
	if not root then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Nameplate"
	gui.Size = UDim2.fromScale(9, 3)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 6.4 * scale + 1.6, 0)
	gui.MaxDistance = 80
	gui.Adornee = root
	gui.Parent = root

	local tags = {}
	if entry.z then
		table.insert(tags, entry.z:upper())
	end
	if entry.m then
		table.insert(tags, entry.m:upper())
	end
	local stars = string.rep("*", entry.st or 0)
	local lines = {
		{
			text = table.concat(tags, " ")
				.. (if #tags > 0 and stars ~= "" then " " else "")
				.. stars,
		},
		{ text = displayName(entry.id), color = rarityColor(entry.id) },
		{ text = Format.short(entry.i or 0) .. " yen/s", color = Color3.fromRGB(140, 255, 150) },
	}
	for i, line in lines do
		local label = Instance.new("TextLabel")
		label.Name = "Line" .. i
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1 / 3)
		label.Position = UDim2.fromScale(0, (i - 1) / 3)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextStrokeTransparency = 0
		label.TextColor3 = line.color or MUTATION_COLORS[entry.m or ""] or Color3.new(1, 1, 1)
		label.Text = line.text
		label.Parent = gui
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
	plate(model, entry, scale)
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
				local model = have.model
				local root = model and model.PrimaryPart
				local gui = root and root:FindFirstChild("Nameplate")
				local line = gui and gui:FindFirstChild("Line3")
				if income ~= entry.i and line and line:IsA("TextLabel") then
					line.Text = Format.short(entry.i or 0) .. " yen/s"
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
