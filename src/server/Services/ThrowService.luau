--!strict
-- ThrowService - the core verb. A client says "I threw at this charge"; the
-- server decides everything else: whether the throw is allowed, which zone it
-- lands in, the luck, the roll, and the grant.
--
-- What the server trusts from the client: the charge value, inside
-- [MinCharge, 1], and the zone the player AIMS at. A cheater can therefore
-- always send a perfect charge, which is worth PerfectLuckBonus and the full
-- depth and nothing more; an aim past the player's reach is the reach.
-- Everything of value (zone, rarity, mutation, size, placement) is computed
-- here.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local Luck = require(ReplicatedStorage.Shared.Core.Luck)
local Progress = require(ReplicatedStorage.Shared.Core.Progress)
local Roll = require(ReplicatedStorage.Shared.Core.Roll)
local Throw = require(ReplicatedStorage.Shared.Core.Throw)
local World = require(ReplicatedStorage.Shared.Core.World)
local Guard = require(script.Parent.Parent.Logic.Guard)

local MAPS = Lookup.of(Config)
local T = Config.Throw
local COUNT = Config.Server.PlotCount
-- seconds between the food landing and the hero reaching its pedestal, on top
-- of the rarity's reveal time
local LAND_PAUSE = T.LandPauseSeconds
local DASH_SECONDS = T.DashSeconds

local ThrowService = Knit.CreateService({
	Name = "ThrowService",
	_last = {} :: { [Player]: number },
	_focusToken = {} :: { [Player]: number },
	_placeFirstAt = {} :: { [Player]: number },
	_forced = {} :: { [Player]: { rarity: string?, mutation: string?, size: string? } },
	_forcedLook = nil :: { mutation: string?, size: string? }?,
	-- players held on their throw pad: what their humanoid had before
	_pad = {} :: { [Player]: { walk: number, jump: number, jumpPower: number } },
	_random = Random.new(),
})

function ThrowService:KnitInit()
	self._request = Net.server("ThrowRequest")
	self._result = Net.server("ThrowResult")
	self._seen = Net.server("ThrowSeen")
end

function ThrowService:_refuse(player: Player, why: string)
	if workspace:GetAttribute("TFADebug") then
		print(`[ThrowService] refused {player.Name}: {why}`)
	end
end

-- "set your hero down first", at most once every few seconds (the pad and a throw both ask)
local PLACE_FIRST_GAP = 4
function ThrowService:_placeFirst(player: Player)
	local now = os.clock()
	local last = self._placeFirstAt[player]
	if last and now - last < PLACE_FIRST_GAP then
		return
	end
	self._placeFirstAt[player] = now
	self._state:Toast(player, "Place your hero on a pedestal first!", "bad")
end

-- The very first throw of a new player is a guaranteed good catch from the
-- first zone, so the tutorial's first reveal is never a let-down.
function ThrowService:_firstCatch(zoneCharacters: { any }, luck: number): Roll.Result?
	local rows = Roll.heroWeights(Config, zoneCharacters, luck, nil)
	for _, row in rows do
		if row.rarity == T.FirstThrowRarity then
			return {
				id = row.id,
				rarity = row.rarity,
				mutation = nil,
				size = nil,
				pHero = row.chance,
				pMutation = 1,
				pSize = 1,
				oneInN = Roll.score(Config, MAPS, zoneCharacters, row.rarity, nil, nil),
			}
		end
	end
	return nil
end

function ThrowService:_handle(
	player: Player,
	charge: unknown,
	lucky: unknown,
	auto: unknown,
	aim: unknown
)
	local profile = self._data:Get(player)
	local index = self._plots:IndexOf(player)
	if not profile or not index then
		return self:_refuse(player, "no profile or plot")
	end
	if not Throw.validCharge(T, charge) then
		return self:_refuse(player, "bad charge")
	end
	local now = os.clock()
	local last = self._last[player]
	if last and now - last < T.ServerCooldownSeconds then
		return self:_refuse(player, "cooldown")
	end
	if not self._pad[player] and not self._plots:OnThrowPad(player) then
		return self:_refuse(player, "not on own throw pad")
	end
	-- a hero in the hands is set down first: a throw would fling food with a hero still held
	-- (owner's review of section 5)
	if self._plots:Carrying(player) then
		self:_placeFirst(player)
		return self:_refuse(player, "carrying a hero")
	end
	local food = MAPS.food[profile.food]
	if not food or not profile.foods[profile.food] then
		return self:_refuse(player, "equipped food not owned")
	end
	self._last[player] = now
	self._training:Stop(player)

	local useLucky = lucky == true and profile.luckyThrows > 0
	-- the aim is remembered; 0 (or anything that is not a zone) = as far as the Power reaches
	if typeof(aim) == "number" and aim == aim and aim >= 0 and aim <= #Config.Zones then
		profile.aim = math.floor(aim :: number)
	end
	local full = profile.power * food.PowerMult
	Progress.touch(profile, Throw.reach(Config.Zones, full, profile.rebirth))
	local zoneIndex, depth = Throw.landing(
		T,
		Config.Zones,
		full,
		profile.rebirth,
		if profile.aim > 0 then profile.aim else nil,
		charge :: number
	)
	local zone = Config.Zones[zoneIndex]
	local perfect = Throw.isPerfect(T, charge :: number)
	-- a Lucky Throw is never below its floor rarity
	local floor: string? = if useLucky then T.LuckyFloor else nil

	local sources = self._state:LuckSources(player)
	sources.foodLuck = food.Luck
	sources.depth = depth
	sources.perfect = perfect
	sources.luckyThrow = useLucky
	sources.dry = profile.dry
	local luck = Luck.total(Config, sources)

	local zoneCharacters = MAPS.zoneCharacters[zone.Id]
	local firstEver = profile.stats.caught == 0
	local result: Roll.Result? = nil
	if firstEver then
		result = self:_firstCatch(MAPS.zoneCharacters[Config.Zones[1].Id], luck)
	end
	if not result then
		result = Roll.throw(Config, MAPS, zoneCharacters, luck, food.Flavor, function(): number
			return self._random:NextNumber()
		end, self._events:MutationMult(), floor)
		-- Studio test (AdminService "nextrarity"): re-roll until the forced rarity comes up
		local forced = self._forced[player]
		if forced then
			self._forced[player] = nil
			self._forcedLook = { mutation = forced.mutation, size = forced.size }
			for _ = 1, 20000 do
				if result and (forced.rarity == nil or result.rarity == forced.rarity) then
					break
				end
				result = Roll.throw(
					Config,
					MAPS,
					zoneCharacters,
					Config.Luck.Max,
					food.Flavor,
					function(): number
						return self._random:NextNumber()
					end,
					self._events:MutationMult(),
					forced.rarity
				)
			end
		end
	end
	local roll = result :: Roll.Result
	local forcedLook = self._forcedLook
	if forcedLook then
		self._forcedLook = nil
		if forcedLook.mutation then
			roll.mutation = if forcedLook.mutation == "none" then nil else forcedLook.mutation
		end
		if forcedLook.size then
			roll.size = if forcedLook.size == "none" then nil else forcedLook.size
		end
	end
	if forcedLook then
		-- a forced look changes the catch: its score is what it now is
		roll.oneInN =
			Roll.score(Config, MAPS, zoneCharacters, roll.rarity, roll.mutation, roll.size)
	end
	if useLucky then
		profile.luckyThrows -= 1
	end
	-- the dry streak: every throw without the reset rarity (or better) adds a little luck
	local resetOrder = Config.Rarities[T.DryStreakResetRarity].Order
	if Config.Rarities[roll.rarity].Order >= resetOrder then
		profile.dry = 0
	else
		profile.dry += 1
	end

	local flight = Throw.flightSeconds(T, zoneIndex, #Config.Zones)
	local reveal = Config.Rarities[roll.rarity].RevealSeconds
	if profile.settings.fastReveal then
		reveal *= 0.5
	end
	local arriveIn = flight + LAND_PAUSE + reveal + DASH_SECONDS

	local grant = self._squad:Grant(player, roll.id, roll.mutation, roll.size, arriveIn)
	if not grant then
		return
	end
	profile.stats.caught += 1
	if roll.oneInN > profile.stats.rarestOneIn then
		profile.stats.rarestOneIn = roll.oneInN
		profile.stats.rarestId = roll.id
	end
	self._state:MarkDirty(player)

	local x = World.landingX(Config.World, index, COUNT, self._random:NextNumber(-1, 1))
	local z = Throw.landingZ(Config.World, Config.Zones, zoneIndex, depth)
	self:_focus(player, x, z, flight, flight + LAND_PAUSE + reveal + 1.5)
	-- a hand throw: the catch comes back to the thrower's hands, to be set on a pedestal of their
	-- choice (Auto Throw seats it as before). Its data is already saved in its slot.
	if grant.uid and auto ~= true then
		self._plots:SetCarry(player, grant.uid, 0)
	end
	self._result:FireClient(player, {
		zone = zoneIndex,
		x = x,
		z = z,
		flight = flight,
		reveal = reveal,
		id = roll.id,
		rarity = roll.rarity,
		mut = roll.mutation,
		size = roll.size,
		oneInN = roll.oneInN,
		stamp = Roll.stamp(Config, roll.oneInN),
		depth = depth,
		-- the Power would carry past the sealed gate: time to offer the rebirth
		sealed = Throw.atSeal(Config.Zones, full, profile.rebirth),
		luck = luck,
		perfect = perfect,
		lucky = useLucky,
		isNew = grant.isNew,
		isBest = grant.isBest,
		action = grant.action,
		slot = grant.slot,
		uid = grant.uid,
		income = grant.income,
		soldYen = grant.soldYen,
		flavorMatch = MAPS.character[roll.id].Craves == food.Flavor,
	})
	local seen = {
		plot = index,
		x = x,
		z = z,
		flight = flight,
		reveal = reveal,
		id = roll.id,
		rarity = roll.rarity,
		mut = roll.mutation,
		size = roll.size,
		food = food.Id,
	}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			self._seen:FireClient(other, seen)
		end
	end
	self._events:CatchAnnounce(player, roll, arriveIn - DASH_SECONDS)
	self._telemetry:Throw(player, zone.Id, roll.rarity, luck, firstEver)
end

-- Streaming follows the food: the lane is far longer than the streaming radius, so without this
-- the landing spot (and the lane behind the revealed hero) is only partly streamed in and the map
-- "disappears" behind the reveal (found in play 2026-11-15). A focus part glides down the lane with
-- the food for the flight, holds at the landing spot through the reveal, then streaming goes back
-- to the character.
function ThrowService:_focus(player: Player, x: number, z: number, flight: number, hold: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local folder = workspace:FindFirstChild("StreamFocus")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "StreamFocus"
		folder.Parent = workspace
	end
	local part = folder:FindFirstChild(tostring(player.UserId))
	if not part then
		local new = Instance.new("Part")
		new.Name = tostring(player.UserId)
		new.Anchored = true
		new.CanCollide = false
		new.CanQuery = false
		new.CanTouch = false
		new.Transparency = 1
		new.Size = Vector3.new(1, 1, 1)
		new.Parent = folder
		part = new
	end
	local focus = part :: BasePart
	focus.CFrame = CFrame.new(root.Position)
	player.ReplicationFocus = focus
	TweenService:Create(focus, TweenInfo.new(math.max(flight, 0.1), Enum.EasingStyle.Linear), {
		CFrame = CFrame.new(x, Config.World.LaneY + 6, z),
	}):Play()
	local token = (self._focusToken[player] or 0) + 1
	self._focusToken[player] = token
	task.delay(hold, function()
		if self._focusToken[player] == token and player.Parent then
			player.ReplicationFocus = nil
		end
	end)
end

-- the floor under (x, z), ignoring the character
local function floorAt(x: number, z: number, fromY: number, ignore: Instance?): number
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = if ignore then { ignore } else {}
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local hit = workspace:Raycast(Vector3.new(x, fromY + 8, z), Vector3.new(0, -60, 0), params)
	return if hit then hit.Position.Y else Config.World.GroundY
end

--- Hold `player` on their throw spot, the coloured circle on the stage (snapped to its centre facing
--- down the lane, anchored, no walking or jumping) or let them off it (set down just behind the
--- stage, facing their plot). There is no pad at the bases since 2026-11-23: the spot is the pad.
--- The client asks; the server does it, so nothing on the client can drift the character off.
function ThrowService:SetPad(player: Player, on: boolean)
	local index = self._plots:IndexOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not index or not humanoid or not root or not root:IsA("BasePart") then
		self._pad[player] = nil
		return
	end
	local x, z = World.throwPad(Config.World, index, COUNT)
	local lift = humanoid.HipHeight + root.Size.Y / 2
	if on then
		if self._pad[player] or humanoid.Health <= 0 or not self._plots:OnThrowPad(player) then
			return
		end
		if self._plots:Carrying(player) then
			self:_placeFirst(player)
			return
		end
		self._training:Stop(player)
		self._pad[player] = {
			walk = humanoid.WalkSpeed,
			jump = humanoid.JumpHeight,
			jumpPower = humanoid.JumpPower,
		}
		humanoid.WalkSpeed = 0
		humanoid.JumpHeight = 0
		humanoid.JumpPower = 0
		-- everyone throws from the middle (owner, 2026-11-21): the player walked onto their own spot
		local sx, sz = World.throwSpot(Config.World, index, COUNT)
		local y = floorAt(sx, sz, root.Position.Y, character) + lift
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.lookAt(Vector3.new(sx, y, sz), Vector3.new(sx, y, sz + 10))
		root.Anchored = true
	else
		local saved = self._pad[player]
		if not saved then
			return
		end
		self._pad[player] = nil
		local backZ = z - (Config.World.ThrowPadRadius + 9) -- off the stage's back edge, on the lawn
		local y = floorAt(x, backZ, root.Position.Y, character) + lift
		root.Anchored = false
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.lookAt(Vector3.new(x, y, backZ), Vector3.new(x, y, backZ - 10))
		humanoid.WalkSpeed = saved.walk
		humanoid.JumpHeight = saved.jump
		humanoid.JumpPower = saved.jumpPower
	end
end

--- True while `player` is held on their throw pad.
function ThrowService:OnPad(player: Player): boolean
	return self._pad[player] ~= nil
end

--- Studio test only (AdminService checks): the next throw of `player` lands `rarity`.
--- Studio tests: the next throw lands this rarity and/or wears this mutation / size ("none"
--- clears it). Calls merge, so rarity, mutation and size can be set one after another.
function ThrowService:ForceNext(
	player: Player,
	what: { rarity: string?, mutation: string?, size: string? }
)
	local was = self._forced[player] or {}
	self._forced[player] = {
		rarity = what.rarity or was.rarity,
		mutation = what.mutation or was.mutation,
		size = what.size or was.size,
	}
end

function ThrowService:KnitStart()
	self._data = Knit.GetService("DataService")
	self._state = Knit.GetService("StateService")
	self._plots = Knit.GetService("PlotService")
	self._squad = Knit.GetService("SquadService")
	self._training = Knit.GetService("TrainingService")
	self._events = Knit.GetService("EventService")
	self._telemetry = Knit.GetService("TelemetryService")

	self._request.OnServerEvent:Connect(
		function(player: Player, charge: unknown, lucky: unknown, auto: unknown, aim: unknown)
			if not Guard.allow(player, "ThrowRequest", 2, 3) then
				return
			end
			self:_handle(player, charge, lucky, auto, aim)
		end
	)
	self._padRemote = Net.server("ThrowPad")
	self._padRemote.OnServerEvent:Connect(function(player: Player, on: unknown)
		if typeof(on) ~= "boolean" or not Guard.allow(player, "ThrowPad", 4, 4) then
			return
		end
		self:SetPad(player, on)
	end)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			self._pad[player] = nil
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		self._last[player] = nil
		self._focusToken[player] = nil
		self._placeFirstAt[player] = nil
		self._pad[player] = nil
		local folder = workspace:FindFirstChild("StreamFocus")
		local focus = folder and folder:FindFirstChild(tostring(player.UserId))
		if focus then
			focus:Destroy()
		end
	end)
end

return ThrowService
