--!strict
-- PlotService - which plot belongs to which player, and the compact plot
-- state every client renders heroes from.
--
-- THE SERVER SPAWNS NO HERO RIGS. A plot's state is a small table
--   { owner, name, slots, income, rebirth, heroes = { { s, u, id, m, z, st, t } } }
-- sent to all clients whenever it changes; each client builds the rigs. Six
-- players with 26 heroes each therefore cost the server nothing to replicate.
-- `t` is the server time a new hero ARRIVES (after its throw has landed and
-- been revealed), so nobody sees a catch standing on the plot before the food
-- has even hit the ground.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Income = require(ReplicatedStorage.Shared.Core.Income)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local Progress = require(ReplicatedStorage.Shared.Core.Progress)
local World = require(ReplicatedStorage.Shared.Core.World)
local Blockout = require(script.Parent.Parent.World.Blockout)
local Guard = require(script.Parent.Parent.Logic.Guard)

local MAPS = Lookup.of(Config)
local COUNT = Config.Server.PlotCount

local PlotService = Knit.CreateService({
	Name = "PlotService",
	_owner = {} :: { [number]: Player },
	_index = {} :: { [Player]: number },
	_state = {} :: { [number]: any },
	_arrive = {} :: { [Player]: { [string]: number } },
})

function PlotService:KnitInit()
	self._snapshot = Net.server("PlotsSnapshot")
	self._update = Net.server("PlotUpdate")
	self._clientReady = Net.server("ClientReady")
	self._map = Blockout.ensure(Config)
end

--- The plot index (1..PlotCount) this player owns, or nil.
function PlotService:IndexOf(player: Player): number?
	return self._index[player]
end

--- The player who owns plot `index`, or nil.
function PlotService:OwnerOf(index: number): Player?
	return self._owner[index]
end

function PlotService:_model(index: number): Instance?
	local plots = self._map:FindFirstChild("Plots")
	return if plots then plots:FindFirstChild("Plot" .. index) else nil
end

--- Is the player's character within `radius` studs (flat) of (x, z)?
function PlotService:Near(player: Player, x: number, z: number, radius: number): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	return World.distance(root.Position.X, root.Position.Z, x, z) <= radius
end

--- Is the player standing on their own throw pad (with a little slack)?
function PlotService:OnThrowPad(player: Player): boolean
	local index = self._index[player]
	if not index then
		return false
	end
	local x, z = World.throwPad(Config.World, index, COUNT)
	return self:Near(player, x, z, Config.World.ThrowPadRadius + 4)
end

--- Is the player standing on their own dojo pad?
function PlotService:OnDojoPad(player: Player): boolean
	local index = self._index[player]
	if not index then
		return false
	end
	local x, z = World.dojoPad(Config.World, index, COUNT)
	return self:Near(player, x, z, Config.World.DojoPadRadius + 4)
end

--- A hero just granted will appear on the plot `seconds` from now.
function PlotService:SetArrival(player: Player, uid: string, seconds: number)
	local arrivals = self._arrive[player]
	if arrivals then
		arrivals[uid] = workspace:GetServerTimeNow() + seconds
	end
end

-- premium heroes have no rarity row: their pedestal is the store's pink
local PREMIUM_PEDESTAL = Color3.fromHex("FF4FA3")

local function setText(anchor: Instance?, guiName: string, text: string)
	local gui = anchor and anchor:FindFirstChild(guiName)
	local label = gui and gui:FindFirstChild("Text")
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

-- The model of a training-gear tier, if the place has it
-- (ReplicatedStorage.Assets.Gear.Equip_<name>).
local function gearTemplate(tier: number): Model?
	local row = Config.Training.Equipment[tier]
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Gear")
	if not row or not folder then
		return nil
	end
	local slug = "Equip_" .. string.gsub(string.lower(row.Name), "%s+", "_")
	local found = folder:FindFirstChild(slug)
	return if found and found:IsA("Model") then found else nil
end

-- Stand the owner's gear tier on the dojo pad. The `Gear` anchor keeps the
-- prompt and the label; it turns invisible once a real model stands on it.
function PlotService:_showGear(model: Instance, tier: number)
	local anchor = model:FindFirstChild("Gear")
	if not anchor or not anchor:IsA("BasePart") or anchor:GetAttribute("Tier") == tier then
		return
	end
	anchor:SetAttribute("Tier", tier)
	local old = anchor:FindFirstChild("GearModel")
	if old then
		old:Destroy()
	end
	local template = gearTemplate(tier)
	if not template then
		-- an empty plot shows nothing; a plot whose model is missing keeps the box
		anchor.Transparency = if tier == 0 and gearTemplate(1) then 1 else 0
		return
	end
	local copy = template:Clone()
	copy.Name = "GearModel"
	local ground = anchor.Position - Vector3.new(0, anchor.Size.Y / 2, 0)
	copy:PivotTo(CFrame.new(ground))
	for _, piece in copy:GetDescendants() do
		if piece:IsA("BasePart") then
			piece.Anchored = true
		end
	end
	copy.Parent = anchor
	anchor.Transparency = 1
	anchor.CanCollide = false
end

function PlotService:_dress(index: number, player: Player?, profile: any?, income: number)
	local model = self:_model(index)
	if not model then
		return
	end
	self:_showGear(model, if profile then profile.gear else 0)
	local slots = if profile then profile.slots else 0
	-- an occupied pedestal wears the rarity colour of the hero standing on it
	local seated: { [number]: Color3 } = {}
	if profile then
		for _, hero in profile.heroes do
			local character = MAPS.character[hero.id]
			local rarity = character and Config.Rarities[character.Rarity]
			if hero.slot > 0 then
				seated[hero.slot] = if rarity
					then Color3.fromHex(rarity.Color)
					else PREMIUM_PEDESTAL
			end
		end
	end
	local pedestals = model:FindFirstChild("Pedestals")
	if pedestals then
		for _, pedestal in pedestals:GetChildren() do
			if pedestal:IsA("BasePart") then
				local slot = pedestal:GetAttribute("Slot") or 0
				local open = slot <= slots
				pedestal.Color = if not open
					then Color3.fromRGB(70, 70, 80)
					else seated[slot] or Color3.fromRGB(235, 235, 245)
				pedestal.Transparency = if open then 0 else 0.6
			end
		end
	end
	if not player or not profile then
		setText(model:FindFirstChild("NameBoard"), "Title", "Empty plot")
		setText(model:FindFirstChild("SlotSign"), "Title", "Plot slots")
		setText(model:FindFirstChild("Gear"), "Title", "Dojo gear")
		return
	end
	local stars = if profile.rebirth > 0 then ` [R{profile.rebirth}]` else ""
	setText(
		model:FindFirstChild("NameBoard"),
		"Title",
		`{player.DisplayName}{stars}\n{Format.short(income)} yen/s`
	)
	local slotCost = Progress.nextSlotCost(Config, profile.slots - profile.bonusSlots)
	setText(
		model:FindFirstChild("SlotSign"),
		"Title",
		if slotCost
			then `Slots {profile.slots} > {profile.slots + 1}\n{Format.short(slotCost)} yen`
			else `Slots {profile.slots} (MAX)`
	)
	local gear = Config.Training.Equipment[profile.gear]
	local gearCost = Progress.nextGearCost(Config, profile.gear)
	setText(
		model:FindFirstChild("Gear"),
		"Title",
		`{gear.Name}  +{Format.short(gear.PowerPerRep)}/rep\n`
			.. (if gearCost then `Next: {Format.short(gearCost)} yen` else "MAX")
	)
end

--- Rebuild this player's public plot state and send it to everyone.
function PlotService:Refresh(player: Player)
	local index = self._index[player]
	local profile = self._data:Get(player)
	if not index or not profile then
		return
	end
	local now = workspace:GetServerTimeNow()
	local arrivals = self._arrive[player] or {}
	local best = Income.best(Config, MAPS, profile.heroes)
	local heroes = {}
	for uid, hero in profile.heroes do
		if hero.slot > 0 then
			local arriveAt = arrivals[uid]
			if arriveAt and arriveAt <= now then
				arrivals[uid] = nil
				arriveAt = nil
			end
			table.insert(heroes, {
				s = hero.slot,
				u = uid,
				id = hero.id,
				m = hero.mut,
				z = hero.size,
				st = hero.stars,
				i = Income.hero(Config, MAPS, hero, best),
				t = arriveAt,
			})
		end
	end
	local income = self._state_service:Income(player)
	local state = {
		owner = player.UserId,
		name = player.DisplayName,
		slots = profile.slots,
		income = income,
		rebirth = profile.rebirth,
		heroes = heroes,
	}
	self._state[index] = state
	self._update:FireAllClients(index, state)
	self:_dress(index, player, profile, income)
end

function PlotService:_assign(player: Player)
	for index = 1, COUNT do
		if not self._owner[index] then
			self._owner[index] = player
			self._index[player] = index
			self._arrive[player] = {}
			local model = self:_model(index)
			local spawn = model and model:FindFirstChild("Spawn")
			if spawn and spawn:IsA("SpawnLocation") then
				player.RespawnLocation = spawn
				local character = player.Character
				if character then
					character:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0))
				end
			end
			return
		end
	end
	player:Kick("This server is full. Please join another one.")
end

function PlotService:KnitStart()
	self._data = Knit.GetService("DataService")
	self._state_service = Knit.GetService("StateService")

	self._data:OnLoaded(function(player: Player)
		self:_assign(player)
	end)
	self._data:OnReady(function(player: Player)
		self:Refresh(player)
	end)
	self._data:OnReleasing(function(player: Player)
		local index = self._index[player]
		self._index[player] = nil
		self._arrive[player] = nil
		if index then
			self._owner[index] = nil
			self._state[index] = nil
			self._update:FireAllClients(index, nil)
			self:_dress(index, nil, nil, 0)
		end
	end)

	self._clientReady.OnServerEvent:Connect(function(player: Player)
		if not Guard.allow(player, "PlotsSnapshot", 0.2, 2) then
			return
		end
		-- string keys: a remote drops the holes of a sparse array
		local all = {}
		for index, state in self._state do
			all[tostring(index)] = state
		end
		self._snapshot:FireClient(player, all)
	end)

	for index = 1, COUNT do
		self:_dress(index, nil, nil, 0)
	end
end

return PlotService
