--!strict
-- Blockout - the placeholder world, built from Config when the place has no
-- authored map. Section 2 plays the loop on this; section 3 replaces it with
-- the dressed map, which must provide the SAME named anchors:
--
--   Workspace.Map.Plots.Plot<i>.{Spawn, ThrowPad, DojoPad, Gear, SlotSign,
--                                NameBoard, Pedestals.Pedestal<slot>}
--   Workspace.Map.Hub.{FoodCart, DailyChest, GiftBox, IndexBoard, Shrine,
--                      BoardYen, BoardCaught, BoardRarest}
--   every interactive anchor carries a ProximityPrompt with attribute
--   "Action" (and "Plot" for plot anchors); InteractService dispatches on it.
--
-- Positions come from Core/World, the same functions the client renders with.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage.Shared.Core.World)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)

local Blockout = {}

local ZONE_COLORS = {
	Color3.fromRGB(255, 170, 200),
	Color3.fromRGB(255, 170, 90),
	Color3.fromRGB(110, 200, 120),
	Color3.fromRGB(220, 90, 90),
	Color3.fromRGB(90, 200, 230),
	Color3.fromRGB(170, 120, 240),
}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Position = position
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function label(
	parent: BasePart,
	name: string,
	text: string,
	height: number,
	studs: number
): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = UDim2.fromScale(studs, studs / 4)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.MaxDistance = 260
	gui.Parent = parent
	local text_ = Instance.new("TextLabel")
	text_.Name = "Text"
	text_.Size = UDim2.fromScale(1, 1)
	text_.BackgroundTransparency = 1
	text_.Font = Enum.Font.FredokaOne
	text_.TextScaled = true
	text_.TextColor3 = Color3.new(1, 1, 1)
	text_.TextStrokeTransparency = 0
	text_.Text = text
	text_.Parent = gui
	return text_
end

local function prompt(
	parent: BasePart,
	action: string,
	text: string,
	plot: number?,
	key: Enum.KeyCode?
)
	local p = Instance.new("ProximityPrompt")
	p.Name = "Prompt_" .. action
	p.ActionText = text
	p.ObjectText = parent.Name
	p.HoldDuration = 0
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = key or Enum.KeyCode.E
	p:SetAttribute("Action", action)
	if plot then
		p:SetAttribute("Plot", plot)
	end
	p.Parent = parent
end

local function buildPlot(cfg: any, folder: Instance, index: number)
	local w = cfg.World
	local count = cfg.Server.PlotCount
	local x0 = World.plotX(w, index, count)
	local y = w.GroundY
	local midZ = (w.PlotBackZ + w.PlotFrontZ) / 2
	local depth = w.PlotFrontZ - w.PlotBackZ

	local plot = Instance.new("Model")
	plot.Name = "Plot" .. index
	plot:SetAttribute("Plot", index)

	local base = part(
		plot,
		"Base",
		Vector3.new(w.PlotWidth, 0.4, depth),
		Vector3.new(x0, y + 0.2, midZ),
		Color3.fromRGB(120, 200, 120)
	)
	plot.PrimaryPart = base

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Enabled = false -- used through Player.RespawnLocation, never as a random spawn
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = Vector3.new(x0, y + 0.9, w.PlotFrontZ - 8)
	spawn.Parent = plot

	local padX, padZ = World.throwPad(w, index, count)
	local pad = part(
		plot,
		"ThrowPad",
		Vector3.new(w.ThrowPadRadius * 2, 0.3, w.ThrowPadRadius * 2),
		Vector3.new(padX, y + 0.55, padZ),
		Color3.fromRGB(255, 220, 60)
	)
	pad.Material = Enum.Material.Neon
	label(pad, "Hint", "THROW SPOT", 7, 8) -- the fallback has no stage: a plain spot where it stands

	-- the training stations (a mat with the Train prompt, and the target) on their two courts
	for i, row in Config.Training.Stations do
		local tx, tz, sx, sz = World.station(w, Config.Training, index, count, i)
		local mat = part(
			plot,
			"Station" .. i,
			Vector3.new(w.StationRadius * 2, 0.3, w.StationRadius * 2),
			Vector3.new(sx, y + 0.55, sz),
			Color3.fromRGB(90, 150, 255)
		)
		mat:SetAttribute("Station", i)
		prompt(mat, "train", "Train: " .. row.Name, index, Enum.KeyCode.E)
		local p = mat:FindFirstChildOfClass("ProximityPrompt")
		if p then
			p:SetAttribute("Station", i)
		end
		local target = part(
			plot,
			if row.Prop == "gear_strike"
				then "Gear"
				elseif row.Prop == "gear_spirit" then "SpiritGear"
				else "Target" .. i,
			Vector3.new(3, 6, 3),
			Vector3.new(tx, y + 3.7, tz),
			Color3.fromRGB(150, 110, 70)
		)
		if row.Prop == "gear_strike" then
			label(target, "Title", "Dojo gear", 5, 16)
			prompt(target, "gear", "Upgrade gear", index, Enum.KeyCode.F)
		end
	end

	local signX, signZ = World.slotSign(w, index, count)
	local sign = part(
		plot,
		"SlotSign",
		Vector3.new(7, 5, 1),
		Vector3.new(signX, y + 3.2, signZ),
		Color3.fromRGB(200, 160, 90)
	)
	label(sign, "Title", "Plot slots", 4.5, 16)
	prompt(sign, "slot", "Buy a slot", index, Enum.KeyCode.E)

	local board = part(
		plot,
		"NameBoard",
		Vector3.new(16, 6, 1),
		Vector3.new(x0, y + 5, w.PlotBackZ + 1),
		Color3.fromRGB(60, 60, 90)
	)
	label(board, "Title", "Empty plot", 5.5, 26)
	prompt(board, "equipBest", "Equip best", index, Enum.KeyCode.E)

	local pedestals = Instance.new("Folder")
	pedestals.Name = "Pedestals"
	pedestals.Parent = plot
	for slot = 1, World.pedestalCount(w) do
		local px, pz = World.pedestal(w, index, count, slot)
		local pedestal = part(
			pedestals,
			"Pedestal" .. slot,
			Vector3.new(5, 0.6, 5),
			Vector3.new(px, y + w.PedestalTop - 0.3, pz),
			Color3.fromRGB(70, 70, 80)
		)
		pedestal:SetAttribute("Slot", slot)
	end

	plot.Parent = folder
end

local function buildHub(cfg: any, folder: Instance)
	local w = cfg.World
	local y = w.GroundY
	local hub = Instance.new("Model")
	hub.Name = "Hub"
	local z = w.PlotBackZ - 30

	local function station(
		name: string,
		x: number,
		color: Color3,
		title: string,
		action: string,
		text: string
	)
		local s = part(hub, name, Vector3.new(8, 6, 4), Vector3.new(x, y + 3, z), color)
		label(s, "Title", title, 5, 22)
		prompt(s, action, text)
		return s
	end
	station("FoodCart", -60, Color3.fromRGB(255, 140, 80), "FOOD CART", "food", "Buy next food")
	station("DailyChest", -30, Color3.fromRGB(255, 210, 70), "DAILY CHEST", "daily", "Claim daily")
	station("GiftBox", 0, Color3.fromRGB(255, 110, 170), "PLAYTIME GIFT", "gift", "Claim gift")
	station(
		"IndexBoard",
		30,
		Color3.fromRGB(90, 170, 255),
		"HERO INDEX",
		"index",
		"Claim zone rewards"
	)
	station("Shrine", 60, Color3.fromRGB(190, 120, 255), "REBIRTH SHRINE", "rebirth", "Rebirth")

	for i, name in { "BoardYen", "BoardCaught", "BoardRarest" } do
		local b = part(
			hub,
			name,
			Vector3.new(18, 22, 1),
			Vector3.new((i - 2) * 26, y + 12, z - 30),
			Color3.fromRGB(30, 34, 80)
		)
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Board"
		gui.Face = Enum.NormalId.Back
		gui.CanvasSize = Vector2.new(360, 440)
		gui.Parent = b
		local text = Instance.new("TextLabel")
		text.Name = "Text"
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.FredokaOne
		text.TextSize = 26
		text.TextColor3 = Color3.new(1, 1, 1)
		text.TextYAlignment = Enum.TextYAlignment.Top
		text.Text = name
		text.Parent = gui
	end
	hub.Parent = folder
end

local function buildLanes(cfg: any, folder: Instance)
	local w = cfg.World
	local count = cfg.Server.PlotCount
	local y = w.GroundY
	local width = count * w.PlotPitch + 40
	local lanes = Instance.new("Model")
	lanes.Name = "Lanes"

	-- one slab under the hub and the plot row
	local backZ = w.PlotBackZ - w.HubDepth
	part(
		lanes,
		"HomeGround",
		Vector3.new(width, 2, w.LaneStartZ - backZ),
		Vector3.new(0, y - 1, (w.LaneStartZ + backZ) / 2),
		Color3.fromRGB(95, 170, 110)
	)

	local z = w.LaneStartZ
	y = w.LaneY -- the lane lies below the hub
	for i, zone in cfg.Zones do
		local color = ZONE_COLORS[((i - 1) % #ZONE_COLORS) + 1]
		local ground = part(
			lanes,
			"Zone_" .. zone.Id,
			Vector3.new(width, 2, zone.LengthStuds),
			Vector3.new(0, y - 1, z + zone.LengthStuds / 2),
			color:Lerp(Color3.new(0, 0, 0), 0.35)
		)
		ground:SetAttribute("Zone", zone.Id)
		local tracks = w.TrackCount or count
		for track = 1, tracks do
			part(
				lanes,
				"Strip_" .. zone.Id .. "_" .. track,
				Vector3.new(w.LanePitch - 4, 0.2, zone.LengthStuds - 2),
				Vector3.new(
					(track - (tracks + 1) / 2) * w.LanePitch,
					y + 0.1,
					z + zone.LengthStuds / 2
				),
				color
			)
		end
		local gate = part(
			lanes,
			"Gate_" .. zone.Id,
			Vector3.new(width, 2, 2),
			Vector3.new(0, y + 16, z),
			color
		)
		gate.CanCollide = false
		gate.Material = Enum.Material.Neon
		label(gate, "Title", `{zone.Name}  -  needs {zone.PowerReq} power`, 4, 90)
		z += zone.LengthStuds
	end
	part(
		lanes,
		"EndWall",
		Vector3.new(width, 60, 4),
		Vector3.new(0, y + 30, z + 2),
		Color3.fromRGB(40, 40, 60)
	)
	lanes.Parent = folder
end

--- Build the placeholder map under Workspace unless a Map already exists.
--- Returns the Map folder.
function Blockout.ensure(cfg: any): Instance
	local existing = workspace:FindFirstChild("Map")
	if existing then
		return existing
	end
	for _, name in { "Baseplate", "SpawnLocation" } do
		local old = workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local map = Instance.new("Folder")
	map.Name = "Map"
	map:SetAttribute("Blockout", true)
	local plots = Instance.new("Folder")
	plots.Name = "Plots"
	plots.Parent = map
	for index = 1, cfg.Server.PlotCount do
		buildPlot(cfg, plots, index)
	end
	buildHub(cfg, map)
	buildLanes(cfg, map)
	map.Parent = workspace
	return map
end

return Blockout
