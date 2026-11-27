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
local Grounds = require(ReplicatedStorage.Shared.Core.Grounds)
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
	-- the hero a player is carrying (a just-caught hero, until they set it on a pedestal): its data
	-- is already saved in its slot; it is only left off the plot until placed (or timed out)
	_carry = {} :: { [Player]: { uid: string, token: number } },
	_carryToken = 0,
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

--- Is the player standing on their own throw spot on the stage (with a little slack)?
function PlotService:OnThrowPad(player: Player): boolean
	local index = self._index[player]
	if not index then
		return false
	end
	local x, z = World.throwPad(Config.World, index, COUNT)
	-- generous: the server's copy of a walking player lags behind it, and the lock snaps them to the
	-- centre anyway (owner's review 5: a refused lock let the player walk through the pad)
	return self:Near(player, x, z, Config.World.ThrowPadRadius + 8)
end

--- `player` now carries hero `uid` (shown in their hands by every client, off its pedestal) from
--- `seconds` from now, until they place it, drop it or CARRY_SECONDS pass. A hero already carried
--- goes down on its own slot first.
local CARRY_SECONDS = 150
function PlotService:SetCarry(player: Player, uid: string, seconds: number)
	local profile = self._data:Get(player)
	local hero = profile and profile.heroes[uid]
	if not hero then
		return
	end
	self:ClearCarry(player, true)
	self._carryToken += 1
	local token = self._carryToken
	self._carry[player] = { uid = uid, token = token }
	task.delay(seconds, function()
		local carry = self._carry[player]
		if carry and carry.token == token and player.Parent then
			local now = profile.heroes[uid]
			if not now then
				self:ClearCarry(player)
				return
			end
			player:SetAttribute(
				"Carrying",
				`{uid}|{now.id}|{now.mut or ""}|{now.size or ""}|{now.stars or 0}`
			)
		end
	end)
	task.delay(seconds + CARRY_SECONDS, function()
		local carry = self._carry[player]
		if carry and carry.token == token then
			self:ClearCarry(player)
		end
	end)
	self:Refresh(player)
end

--- The uid `player` is carrying, if any.
function PlotService:Carrying(player: Player): string?
	local carry = self._carry[player]
	return carry and carry.uid
end

--- Put the carried hero down on the slot it holds in the data (or nowhere, if it is benched).
function PlotService:ClearCarry(player: Player, quiet: boolean?)
	local carry = self._carry[player]
	if not carry then
		return
	end
	self._carry[player] = nil
	-- set down by hand: it is there now, not still "on its way" from the reveal
	local arrivals = self._arrive[player]
	if arrivals then
		arrivals[carry.uid] = nil
	end
	if player.Parent then
		player:SetAttribute("Carrying", nil)
	end
	if not quiet then
		self:Refresh(player)
	end
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

-- THE TRAINING GROUNDS (plan 13 phase D). Each court of a plot has an anchor part `Ground<court>`
-- at its centre, on the floor; the set piece of the ground that court shows stands on it
-- (ReplicatedStorage.Assets.Grounds.Ground_<id>_T<tier>, built by tools/studio/grounds). A set piece
-- carries what the game reads:
--   Stand   an invisible part: where the trainee's feet go and (its LookVector) which way they face
--   Sign    the notice board: a SurfaceGui `Board` with the labels Title, Level and Next
--   L2, L3  what gear levels II and III add; taken out of a copy below that level
-- The two prompts of a court live in the place, on `TrainSpot<court>` and `GearSign<court>`; they
-- are moved onto the set piece's Stand and Sign whenever it changes.
local function groundsFolder(): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	return assets and assets:FindFirstChild("Grounds")
end

local function setLabel(root: Instance?, name: string, text: string)
	local label = root and root:FindFirstChild(name, true)
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

-- Stand the right set piece on court `court` of plot `model`: the ground `shown` at the look of
-- gear row `gear`. Nothing happens when it already stands there.
function PlotService:_showGround(
	model: Instance,
	court: number,
	shown: Grounds.Shown?,
	gear: number
)
	local anchor = model:FindFirstChild("Ground" .. court)
	if not anchor or not anchor:IsA("BasePart") then
		return
	end
	local tier, level = 0, 0
	if shown then
		tier, level = Grounds.look(Config, shown.ground, gear)
	end
	local key = if shown then `{shown.ground}/{tier}/{level}/{shown.locked or 0}` else ""
	if anchor:GetAttribute("Look") == key then
		return
	end
	anchor:SetAttribute("Look", key)
	anchor:SetAttribute("Ground", if shown then shown.ground else nil)
	anchor:SetAttribute("Tier", if shown then tier else nil)
	anchor:SetAttribute("Level", if shown then level else nil)
	anchor:SetAttribute("Locked", if shown then shown.locked else nil)
	local old = anchor:FindFirstChild("GroundModel")
	if old then
		old:Destroy()
	end
	local folder = groundsFolder()
	local template = if shown and folder
		then folder:FindFirstChild(Grounds.template(Config, shown.ground, tier))
		else nil
	local spot = model:FindFirstChild("TrainSpot" .. court)
	local sign = model:FindFirstChild("GearSign" .. court)
	for _, holder in { spot, sign } do
		local prompt = holder and holder:FindFirstChildWhichIsA("ProximityPrompt")
		if prompt then
			-- an empty plot, or a ground whose set piece is not in the place, has nothing to walk up to
			prompt.Enabled = template ~= nil
		end
	end
	if not shown or not template or not template:IsA("Model") then
		return
	end
	local copy = template:Clone()
	copy.Name = "GroundModel"
	for extra = level + 1, 3 do
		local piece = copy:FindFirstChild("L" .. extra)
		if piece then
			piece:Destroy()
		end
	end
	local lock = copy:FindFirstChild("Lock")
	if lock and not shown.locked then
		lock:Destroy()
	elseif lock then
		setLabel(lock, "LockText", `REBIRTH {shown.locked}`)
	end
	copy:PivotTo(anchor.CFrame)
	-- where the centrepiece stands at rest: clients move it (a blow, the awakening) and put it back here
	local target = copy:FindFirstChild("Target")
	if target and target:IsA("Model") then
		target:SetAttribute("Rest", target:GetPivot())
	end
	copy.Parent = anchor
	local stand = copy:FindFirstChild("Stand")
	if stand and stand:IsA("BasePart") and spot and spot:IsA("BasePart") then
		spot.CFrame = stand.CFrame + Vector3.new(0, 3, 0)
	end
	local board = copy:FindFirstChild("Sign")
	if board and board:IsA("BasePart") and sign and sign:IsA("BasePart") then
		sign.CFrame = board.CFrame
	end
end

--- Where a trainee stands on court `court` of plot `index`: feet position and facing. The set
--- piece's Stand part; the court's centre, facing the base, when there is no set piece.
function PlotService:GroundStand(index: number, court: number): CFrame
	local model = self:_model(index)
	local anchor = model and model:FindFirstChild("Ground" .. court)
	local piece = anchor and anchor:FindFirstChild("GroundModel")
	local stand = piece and piece:FindFirstChild("Stand")
	if stand and stand:IsA("BasePart") then
		return stand.CFrame
	end
	local side = Config.Training.Courts[court].Side
	local x, z = World.court(Config.World, index, Config.Server.PlotCount, side)
	local y = if anchor and anchor:IsA("BasePart") then anchor.Position.Y else Config.World.GroundY
	return CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(x, y, z - 10))
end

-- The set pieces of a plot and what their boards say.
function PlotService:_showGrounds(model: Instance, profile: any?)
	local shown = if profile then Grounds.shown(Config, profile.rebirth or 0) else {}
	local gear = if profile then profile.gear else 0
	local row = if profile then Config.Training.Equipment[gear] else nil
	local nextRow = if profile then Config.Training.Equipment[gear + 1] else nil
	for court = 1, #Config.Training.Courts do
		local here: Grounds.Shown? = shown[court]
		self:_showGround(model, court, here, gear)
		local anchor = model:FindFirstChild("Ground" .. court)
		local piece = anchor and anchor:FindFirstChild("GroundModel")
		local ground = here and Config.Training.Grounds[here.ground]
		local spot = model:FindFirstChild("TrainSpot" .. court)
		local trainPrompt = spot and spot:FindFirstChildWhichIsA("ProximityPrompt")
		if trainPrompt and ground then
			trainPrompt.ObjectText = ground.Name
			trainPrompt.ActionText = if here and here.locked then "Locked" else "Train"
		end
		local sign = model:FindFirstChild("GearSign" .. court)
		local gearPrompt = sign and sign:FindFirstChildWhichIsA("ProximityPrompt")
		if gearPrompt then
			gearPrompt.ObjectText = "Training gear"
		end
		if not piece or not here or not ground or not row then
			continue
		end
		-- the board: the ground, the gear the owner trains on, the next upgrade
		setLabel(piece, "Title", ground.Name:upper())
		if here.locked then
			setLabel(piece, "Level", `OPENS AT REBIRTH {here.locked}`)
			setLabel(piece, "Next", "")
			continue
		end
		-- the gear is named on the board of the ground it belongs to; the other ground pays the same
		-- Power (the gear is the owner's, not the ground's) and says only that
		setLabel(
			piece,
			"Level",
			if row.Ground == here.ground
				then `{row.Name}   +{Format.short(row.PowerPerRep)} / rep`
				else `+{Format.short(row.PowerPerRep)} POWER / rep`
		)
		setLabel(
			piece,
			"Next",
			if nextRow
				then `NEXT: {nextRow.Name}  {Format.short(nextRow.Cost)} yen`
				else "MAX LEVEL"
		)
	end
end

function PlotService:_dress(index: number, player: Player?, profile: any?, income: number)
	local model = self:_model(index)
	if not model then
		return
	end
	self:_showGrounds(model, profile)
	-- the prompts' small line: what the thing is, not the part's name
	local OBJECT_TEXT = { SlotSign = "Plot slots", NameBoard = "Your squad" }
	for name, text in OBJECT_TEXT do
		local anchor = model:FindFirstChild(name)
		local prompt = anchor and anchor:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt then
			prompt.ObjectText = text
		end
	end
	local slots = if profile then profile.slots else 0
	-- an occupied pedestal wears the rarity colour of the hero standing on it
	local seated: { [number]: Color3 } = {}
	if profile then
		local carried = if player then self:Carrying(player) else nil
		for uid, hero in profile.heroes do
			local character = MAPS.character[hero.id]
			local rarity = character and Config.Rarities[character.Rarity]
			if hero.slot > 0 and uid ~= carried then
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
		return
	end
	local stars = if profile.rebirth > 0 then ` [R{profile.rebirth}]` else ""
	setText(
		model:FindFirstChild("NameBoard"),
		"Title",
		`{player.DisplayName}{stars}\n{Format.short(income)} yen/s`
	)
	local slotCost = Progress.nextSlotCost(Config, profile.slots, profile.bonusSlots)
	setText(
		model:FindFirstChild("SlotSign"),
		"Title",
		if slotCost
			then `Slots {profile.slots} > {profile.slots + 1}\n{Format.short(slotCost)} yen`
			else `Slots {profile.slots} (MAX)`
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
	local carried = self:Carrying(player)
	for uid, hero in profile.heroes do
		if hero.slot > 0 and uid ~= carried then
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
		self._carry[player] = nil
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
