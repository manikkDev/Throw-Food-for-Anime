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
local PLACE_AT = 0.55 -- the PlaceHero clip's "Place" marker, if the marker never comes
local PROMPT_DISTANCE = 9

local characterStamp: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local stampCount = 0

type Carried = {
	key: string,
	model: Model,
	weld: WeldConstraint?,
	track: AnimationTrack?,
}

local CarryController = Knit.CreateController({
	Name = "CarryController",
	_carried = {} :: { [Player]: Carried },
	_prompts = {} :: { ProximityPrompt },
	_glows = {} :: { Highlight },
	_hold = nil :: AnimationTrack?,
	_placing = false,
	_toldFull = nil :: string?,
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

-- every part of a carried hero rides along: no mass, no collision, no queries, no humanoid physics
local function passenger(model: Model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
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

-- where the carried hero rides: held up by the ankles in the CarryHold clip's hands, upright, facing
-- the way the carrier faces. The clip puts the hero's LowerTorso at (0, 3.31, -0.42) in root space
-- (work/anim/upload3/README.md); without the clip the same spot still reads as "held overhead".
local GRIP = Vector3.new(0, 3.31, -0.42)
local function rideOffset(_character: Model, model: Model): CFrame
	local lower = model:FindFirstChild("LowerTorso") or model:FindFirstChild("HumanoidRootPart")
	local pivot = model:GetPivot()
	local lowerFromPivot = if lower and lower:IsA("BasePart")
		then pivot:PointToObjectSpace(lower.Position)
		else Vector3.new(0, 1, 0)
	return CFrame.new(GRIP - lowerFromPivot)
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
	model:PivotTo(root.CFrame * rideOffset(character, model))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	weld.Parent = model
	model.Parent = workspace
	local track = self._heroes:Animate(model)
	self._carried[owner] = { key = key, model = model, weld = weld, track = track }
	-- it arrives: a pop in and a lift sound
	local target = model:GetScale()
	model:ScaleTo(target * 0.2)
	task.spawn(function()
		local t0 = os.clock()
		while model.Parent and os.clock() - t0 < 0.3 do
			local u = (os.clock() - t0) / 0.3
			local back = 1 + 2.2 * (u - 1) ^ 3 + 1.2 * (u - 1) ^ 2 -- ease out with a little overshoot
			model:ScaleTo(target * math.max(0.2 + 0.8 * back, 0.05))
			model:PivotTo(root.CFrame * rideOffset(character, model))
			RunService.Heartbeat:Wait()
		end
		if model.Parent then
			model:ScaleTo(target)
			model:PivotTo(root.CFrame * rideOffset(character, model))
		end
	end)
	-- no sparkle or aura while it is carried (owner's review 3): the effects wait for the pedestal
	Sound:Play("hero_pickup", root)
	if owner == player then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		self._hold = Motion.play(humanoid, "CarryHold", { fade = 0.25, looped = true })
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
	local state = self._state.State
	if not uid or not id or not state or not state.plot then
		return
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
	local done = false
	local function commit()
		if done then
			return
		end
		done = true
		self._heroes:ExpectPlace(uid)
		self._squadAction:FireServer("place", uid, slot)
		local top = pedestal.Position + Vector3.new(0, pedestal.Size.Y / 2, 0)
		local carried = self._carried[player]
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
