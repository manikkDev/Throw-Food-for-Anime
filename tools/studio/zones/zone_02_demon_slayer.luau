-- LIB: side_lib
-- zone_02_demon_slayer.luau - zone 2, "Demon Slayer Corps", on the slim lane (v2, 2026-11-22).
-- z 520..880 (config id still pirate_harbor), lane floor y -48, lane edges x +-100. Run with
--   python tools/studio/zones/run_zone.py build 2
-- then lane_border.luau. Safe to run again: it clears Map.Scenery.Zone_pirate_harbor and rebuilds.
--
-- v1 stood in a dark clay canyon on the 320-wide lane (archived once in MapArchive.Zone2_v1_canyon).
-- Now, on side_lib's cross-section: a mountain pass in dark blue-grey stone with mossy caps, wisteria
-- spilling from the shelves.
--   * the floor is Tanjiro's haori: green and black checks, crimson kerbs
--   * +X: the Mugen Train (a locomotive and two carriages) on its rails along the terrace, smoke at the
--     stack, a wooden platform on the lane side with its station board and lamps
--   * -X: the Butterfly Estate (a Taisho mansion), the Corps' banners, a sword monument, and the
--     zone's landmark at its far end, one great wisteria
-- Needs ServerStorage.StoreAssets.Zone02_DemonSlayer (Locomotive, Carriage, Mansion, Cedar, MossRock,
-- Wisteria: generated, squared, front to -Z).
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local map = workspace.Map
local KIT = RS.Assets.Kit
local SRC = SS.StoreAssets.Zone02_DemonSlayer
local ID = "pirate_harbor" -- the zone's id in config until the anime zone data lands
local TITLE = "DEMON SLAYER CORPS"
local LY, HALF, Z0, Z1 = P.LY, P.HALF, 520, 880
local rng = Random.new(2207)

local CHECK_GREEN = Color3.fromRGB(47, 163, 107)
local CHECK_BLACK = Color3.fromRGB(36, 39, 46)
local CRIMSON = Color3.fromRGB(179, 38, 46)
local WISTERIA = Color3.fromRGB(155, 107, 223)
local WOOD = Color3.fromRGB(122, 84, 56)
local WOOD_DARK = Color3.fromRGB(74, 50, 38)
local IRON = Color3.fromRGB(52, 54, 62)
local PASS = Color3.fromRGB(98, 106, 102) -- the pass's stone: dark, mossy grey (a blue-grey read as a flat blue wall)
local PASS_DARK = Color3.fromRGB(66, 72, 70)
local MOSS = Color3.fromRGB(84, 122, 72)
local STREET = Color3.fromRGB(112, 116, 128)

local function facing(side: number): number
	return if side > 0 then 90 else -90 -- a squared template fronts to -Z: turn it to the lane
end

-- a tiled gable roof: at's X axis is the ridge, its origin the middle of the eave line
local function gable(
	parent: Instance,
	at: CFrame,
	length: number,
	half: number,
	height: number,
	color: Color3
)
	for _, sd in { -1, 1 } do
		local turn = if sd > 0 then CFrame.Angles(0, math.pi, 0) else CFrame.new()
		block(
			parent,
			"Roof",
			Vector3.new(length, height, half),
			at * CFrame.new(0, height / 2, sd * half / 2) * turn,
			color,
			Enum.Material.ClayRoofTiles,
			"WedgePart"
		).CastShadow =
			true
	end
	block(
		parent,
		"Ridge",
		Vector3.new(length + 1, 1.2, 1.6),
		at * CFrame.new(0, height + 0.3, 0),
		WOOD_DARK,
		Enum.Material.Wood
	)
end

-- ---------------------------------------------------------------------------------- the zone's folder
local scenery = map.Scenery
local archive = SS:FindFirstChild("MapArchive") or folder(SS, "MapArchive")
if not archive:FindFirstChild("Zone2_v1_canyon") then
	local keep = scenery["Zone_" .. ID]:Clone()
	keep.Name = "Zone2_v1_canyon"
	keep:SetAttribute(
		"Note",
		"Zone 2 (Demon Slayer) v1, in its canyon, before the slim-lane rebuild (2026-11-22). Never delete."
	)
	keep.Parent = archive
end
local root = scenery["Zone_" .. ID]
root:ClearAllChildren()
root:SetAttribute("Theme", "Demon Slayer Corps, zone_02_demon_slayer.luau v2 on side_lib")
local ground = folder(root, "Ground")
local buildings = folder(root, "Buildings")
local train = folder(root, "Train")
local props = folder(root, "Props")
local trees = folder(root, "Trees")

-- ---------------------------------------------------------------------------------- the ground
local STYLE = {
	stone = PASS,
	material = Enum.Material.Cobblestone,
	band = PASS_DARK,
	cap = MOSS,
	capMaterial = Enum.Material.Grass,
	rail = WOOD_DARK,
}
if DO_TERRAIN then
	sideGround(Z0, Z1)
end
claimGates(Z0, Z1)
for _, s in { -1, 1 } do
	box(
		ground,
		"Kerb",
		s * HALF,
		s * P.KERB_OUT,
		LY - 2,
		LY + 3,
		Z0,
		Z1,
		CRIMSON,
		Enum.Material.Slate
	)
	pave(
		ground,
		s * P.KERB_OUT,
		s * P.STREET_OUT,
		Z0,
		Z1,
		P.TERRACE_Y + 0.4,
		STREET,
		Enum.Material.Cobblestone,
		"Street"
	)
	table.insert(claims, rect(s * HALF, s * P.STREET_OUT, Z0, Z1, "Street"))
	revetment(ground, s, Z0, Z1, STYLE)
	-- a pier of the pass's stone where zone 1's revetment meets this one
	box(
		ground,
		"SeamPier",
		s * (P.TERRACE_OUT - P.BATTER - 1.5),
		s * (P.REVET_OUT + 0.5),
		P.TERRACE_Y - 1,
		P.SHELF_Y + 3,
		Z0 - 2.5,
		Z0 + 2.5,
		PASS_DARK,
		Enum.Material.Slate
	)
end

-- ---------------------------------------------------------------------------------- the Mugen Train (+X)
-- the platform on the lane side, the rails behind it; the train heads for the throw stage
local PLAT0, PLAT1 = P.STREET_OUT + 1, P.STREET_OUT + 14 -- the platform (x 117..130)
local TX = PLAT1 + 18 -- the track's centre line (148): the rail bed 36 wide, to x 166
local BED = LY + 2.4
local RZ0, RZ1 = 596, 836
-- The locomotive and the carriage were generated apart, so their wheels are not one gauge: these two
-- scales bring both to about 8.4 from the centre line, and a rail there carries both
local LOCO, CAR = 2.2, 2.8
box(
	train,
	"RailBed",
	TX - 18,
	TX + 18,
	LY,
	LY + 2.4,
	RZ0,
	RZ1,
	Color3.fromRGB(104, 100, 98),
	Enum.Material.Slate
)
for _, dx in { -8.4, 8.4 } do
	block(
		train,
		"Rail",
		Vector3.new(2.4, 1.5, RZ1 - RZ0),
		CFrame.new(TX + dx, BED + 0.75, (RZ0 + RZ1) / 2),
		IRON,
		Enum.Material.Metal
	)
end
for z = RZ0 + 4, RZ1 - 4, 8 do
	block(
		train,
		"Sleeper",
		Vector3.new(26, 0.7, 2.6),
		CFrame.new(TX, BED + 0.3, z),
		WOOD_DARK,
		Enum.Material.Wood
	).CastShadow =
		false
end
still(make(train, SRC.Locomotive, LOCO, 0, Vector3.new(TX, BED + 1.4, 632)), true)
for _, z in { 705, 787 } do
	still(make(train, SRC.Carriage, CAR, 0, Vector3.new(TX, BED + 0.1, z)), true)
end
table.insert(claims, rect(PLAT0, TX + 18, RZ0, RZ1, "MugenTrain"))
local stack = block(train, "Stack", Vector3.new(2, 2, 2), CFrame.new(TX, BED + 46, 612), IRON)
stack.Transparency = 1
stack.CastShadow = false
local smoke = Instance.new("ParticleEmitter")
smoke.Name = "Smoke"
smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
smoke.Color = ColorSequence.new(Color3.fromRGB(236, 236, 240), Color3.fromRGB(150, 150, 160))
smoke.Size =
	NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 13) })
smoke.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.35),
	NumberSequenceKeypoint.new(0.7, 0.6),
	NumberSequenceKeypoint.new(1, 1),
})
smoke.Lifetime = NumberRange.new(4, 6)
smoke.Rate = 7
smoke.Speed = NumberRange.new(7, 10)
smoke.EmissionDirection = Enum.NormalId.Top
smoke.SpreadAngle = Vector2.new(10, 10)
smoke.Acceleration = Vector3.new(0, 1, 5)
smoke.RotSpeed = NumberRange.new(-30, 30)
smoke.Parent = stack
-- the platform, its edge, lamps and the station board
box(train, "Platform", PLAT0, PLAT1, LY, LY + 5, RZ0 + 30, RZ1 - 6, WOOD, Enum.Material.WoodPlanks)
box(
	train,
	"PlatformEdge",
	PLAT1 - 0.4,
	PLAT1 + 1,
	LY,
	LY + 5.4,
	RZ0 + 30,
	RZ1 - 6,
	Color3.fromRGB(232, 222, 200),
	Enum.Material.Concrete
)
for _, z in { 660, 796 } do
	still(make(props, KIT.Prop_store_LampPost, 1.9, -90, Vector3.new(PLAT0 + 6, LY + 5, z)), false)
end
local BX = PLAT0 + 3 -- the board's line, on the platform's lane side
for _, z in { 714, 742 } do
	block(
		train,
		"SignPost",
		Vector3.new(1.2, 16, 1.2),
		CFrame.new(BX, LY + 13, z),
		WOOD_DARK,
		Enum.Material.Wood
	)
end
local board = block(
	train,
	"StationBoard",
	Vector3.new(0.8, 9, 30),
	CFrame.new(BX, LY + 18, 728),
	Color3.fromRGB(244, 236, 214),
	Enum.Material.Wood
)
local gui = Instance.new("SurfaceGui")
gui.Face = Enum.NormalId.Left -- the lane's side
gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
gui.PixelsPerStud = 20
gui.LightInfluence = 1
gui.Parent = board
local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1, 1)
label.BackgroundTransparency = 1
label.Text = "無限"
label.TextScaled = true
label.Font = Enum.Font.SourceSansBold
label.TextColor3 = Color3.fromRGB(34, 30, 30)
label.Parent = gui
block(
	train,
	"BoardFrame",
	Vector3.new(1.2, 10.4, 31.4),
	CFrame.new(BX + 0.3, LY + 18, 728),
	WOOD_DARK,
	Enum.Material.Wood
)
-- the station's canopy over the platform: posts on both edges, a dark tile roof (its eave above the board)
local CZ0, CZ1 = 640, 816
local ROOF_Y = LY + 25
for z = CZ0, CZ1, 22 do
	for _, x in { PLAT0 + 1, PLAT1 - 1.5 } do
		block(
			train,
			"CanopyPost",
			Vector3.new(1.2, ROOF_Y - LY - 5, 1.2),
			CFrame.new(x, (ROOF_Y + LY + 5) / 2, z),
			WOOD_DARK,
			Enum.Material.Wood
		)
	end
end
box(
	train,
	"CanopyBeam",
	PLAT0 + 0.2,
	PLAT1 - 0.6,
	ROOF_Y - 1,
	ROOF_Y,
	CZ0 - 1,
	CZ1 + 1,
	WOOD_DARK,
	Enum.Material.Wood
)
gable(
	train,
	CFrame.new((PLAT0 + PLAT1) / 2, ROOF_Y, (CZ0 + CZ1) / 2) * CFrame.Angles(0, math.pi / 2, 0),
	CZ1 - CZ0 + 4,
	7.5,
	4,
	Color3.fromRGB(66, 60, 66)
)

-- ---------------------------------------------------------------------------------- the estate (-X)
front(buildings, SRC.Mansion, -1, 1.15, P.STREET_OUT + 3, 700)
local function kit(name: string, scale: number, x: number, z: number, yaw: number): Model?
	local template = KIT:FindFirstChild(name)
	if not template then
		table.insert(refused, name .. " is not in the kit")
		return nil
	end
	return put(props, template, scale, yaw, x, z)
end
-- wisteria trellises (fuji-dana) along the estate's street: posts, beams, slats, hanging flowers
local function trellis(z0: number, z1: number)
	local xa, xb = -(P.STREET_OUT + 4), -(P.STREET_OUT + 26)
	if not claim(rect(xa + 1, xb - 1, z0 - 1, z1 + 1, "Trellis")) then
		return
	end
	local m = Instance.new("Model")
	m.Name = "WisteriaTrellis"
	local top = LY + 17
	for z = z0, z1, 10 do
		for _, x in { xa, xb } do
			block(
				m,
				"Post",
				Vector3.new(1.4, top - LY, 1.4),
				CFrame.new(x, (top + LY) / 2, z),
				WOOD_DARK,
				Enum.Material.Wood
			)
		end
	end
	for _, x in { xa, xb } do
		box(
			m,
			"Beam",
			x - 0.8,
			x + 0.8,
			top,
			top + 1.4,
			z0 - 2,
			z1 + 2,
			WOOD_DARK,
			Enum.Material.Wood
		)
	end
	local tones = { WISTERIA, Color3.fromRGB(184, 140, 236), Color3.fromRGB(132, 88, 204) }
	for z = z0 - 1, z1 + 1, 3 do
		box(
			m,
			"Slat",
			xb - 1,
			xa + 1,
			top + 1.4,
			top + 2,
			z - 0.4,
			z + 0.4,
			WOOD,
			Enum.Material.Wood
		)
		for _ = 1, 3 do
			local x = rng:NextNumber(xb + 1, xa - 1)
			local h = rng:NextNumber(3, 7.5)
			local p = block(
				m,
				"Bloom",
				Vector3.new(1.6, h, 1.6),
				CFrame.new(x, top + 1.4 - h / 2, z + rng:NextNumber(-1, 1)),
				tones[rng:NextInteger(1, #tones)],
				Enum.Material.SmoothPlastic
			)
			p.CastShadow = false
		end
	end
	m.Parent = props
end
trellis(586, 656)
trellis(744, 792)

-- the Corps' banner, white on black, read from the lane, at the terrace's back edge
local function corps(side: number, z: number)
	local x = side * (P.TERRACE_OUT - P.BATTER - 3)
	if not claim(rect(x - 2, x + 2, z - 1, z + 10, "CorpsBanner")) then
		return
	end
	block(
		props,
		"BannerPole",
		Vector3.new(1, 30, 1),
		CFrame.new(x, LY + 15, z),
		WOOD_DARK,
		Enum.Material.Wood
	)
	block(
		props,
		"BannerArm",
		Vector3.new(1, 1, 10),
		CFrame.new(x, LY + 29, z + 4.5),
		WOOD_DARK,
		Enum.Material.Wood
	)
	local cloth = block(
		props,
		"CorpsBanner",
		Vector3.new(0.3, 20, 8),
		CFrame.new(x, LY + 18.4, z + 5),
		Color3.fromRGB(26, 26, 32),
		Enum.Material.Fabric
	)
	local g = Instance.new("SurfaceGui")
	g.Face = if side > 0 then Enum.NormalId.Left else Enum.NormalId.Right
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 20
	g.Parent = cloth
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = "滅"
	t.TextScaled = true
	t.Font = Enum.Font.SourceSansBold
	t.TextColor3 = Color3.fromRGB(245, 245, 245)
	t.Parent = g
end
corps(-1, 640)
corps(-1, 748)
corps(1, 576)
corps(1, 846)
kit("Prop_store_StoneLantern", 1.7, -150, 622, 0)
kit("Prop_store_StoneLantern", 1.7, -150, 778, 0)
kit("Prop_store_StoneLantern", 1.7, 150, 586, 0)
kit("Prop_store_StoneLantern", 1.7, 150, 856, 0)
kit("Prop_samurai_castle_KatanaMonument", 2.4, -152, 800, 0)

-- ---------------------------------------------------------------------------------- wisteria, cedars, rock
local function plant(template: Instance, x: number, z: number, scale: number, soft: number?): Model?
	local m =
		put(trees, template, scale, rng:NextInteger(0, 3) * 90, x, z, { soft = soft or 4 * scale })
	if m then
		still(m, scale > 1.2)
	end
	return m
end
-- the landmark: one great wisteria at the estate side's far end
plant(SRC.Wisteria, -(P.STREET_OUT + 26), 840, 1.85, 10)
-- the shelves: +X a mountain village behind the train (farmhouses), -X shrines and bamboo behind the
-- estate; wisteria spilling over the edge, a few cedars (owner: not too many trees)
local SHELF = P.REVET_OUT + 1.5
local function shelfKit(name: string, side: number, scale: number, z: number)
	local template = KIT:FindFirstChild(name)
	if template then
		front(buildings, template, side, scale, SHELF, z)
	end
end
shelfKit("Prop_store_FarmHouseA", 1, 0.8, 600)
shelfKit("Prop_store_FarmHouseC", 1, 0.85, 690)
shelfKit("Prop_store_FarmHouseB", 1, 0.8, 790)
shelfKit("Prop_store_ShrineA", -1, 0.9, 610)
shelfKit("Prop_store_ShrineB", -1, 0.9, 790)
for _, t in
	{
		{ 192, 645, "W" },
		{ 192, 740, "C" },
		{ 192, 840, "W" },
		{ -192, 575, "C" },
		{ -192, 664, "W" },
		{ -192, 700, "C" },
		{ -192, 752, "W" },
		{ -192, 832, "C" },
	}
do
	if t[3] == "W" then
		plant(SRC.Wisteria, t[1], t[2], 1.05)
	else
		plant(SRC.Cedar, t[1], t[2], 1.4)
	end
end
for _, z in { 638, 726, 862 } do
	local m = put(
		trees,
		KIT.Prop_ninja_village_BambooCluster,
		1.4,
		rng:NextInteger(0, 3) * 90,
		-192,
		z,
		{ soft = 1 }
	)
	if m then
		still(m, false)
	end
end
-- mossy rocks at the revetment's foot
for _, r in { { -156, 594, 0.85 }, { 156, 572, 0.8 } } do
	plant(SRC.MossRock, r[1], r[2], r[3], 0)
end

-- petals on the wind
local fx = folder(root, "Fx")
for _, z in { 590, 680, 770, 850 } do
	local source = block(
		fx,
		"PetalSource",
		Vector3.new(2 * HALF - 8, 1, 70),
		CFrame.new(0, LY + 84, z),
		Color3.new(1, 1, 1)
	)
	source.Transparency = 1
	source.CastShadow = false
	local e = Instance.new("ParticleEmitter")
	e.Name = "Petals"
	e.Texture = "rbxassetid://5057182105"
	e.Color = ColorSequence.new(Color3.fromRGB(226, 180, 255), Color3.fromRGB(190, 140, 255))
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.1),
		NumberSequenceKeypoint.new(1, 1.6),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.1, 0),
		NumberSequenceKeypoint.new(0.85, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(9, 13)
	e.Rate = 5
	e.Speed = NumberRange.new(5, 9)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.SpreadAngle = Vector2.new(25, 25)
	e.Acceleration = Vector3.new(-2.5, -1, 1.5)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-110, 110)
	e.LightEmission = 0.75 -- the texture is warm: without this a purple tint comes out brown
	e.Parent = source
end

-- ---------------------------------------------------------------------------------- floor and gate
for _, c in kitItems(map.Lanes["Zone_" .. ID]) do
	local n = c.Name
	if c:IsA("BasePart") then
		if n:sub(1, 5) == "Strip" then
			-- green and black checks: the next tile and the next track both swap
			local tile = math.floor((c.Position.Z - 526) / 44.25 + 0.01)
			local track = math.floor(c.Position.X / 56 + 0.5)
			local green = (tile + track) % 2 == 0
			c.Color = if green then CHECK_GREEN else CHECK_BLACK
			local tex = c:FindFirstChildWhichIsA("Texture")
			if tex then
				tex.Color3 = if green
					then Color3.fromRGB(120, 214, 164)
					else Color3.fromRGB(78, 84, 96)
			end
		elseif n:sub(1, 4) == "Kerb" then
			c.Color = CRIMSON
		elseif n:sub(1, 6) == "Paving" or n == "MarginPaving" then
			c.Color = Color3.fromRGB(112, 116, 128)
			local tex = c:FindFirstChildWhichIsA("Texture")
			if tex then
				tex.Color3 = Color3.fromRGB(164, 168, 180)
			end
		elseif n:sub(1, 12) == "DistanceBand" then
			c.Color = Color3.fromRGB(250, 246, 236)
		end
	elseif n:sub(1, 5) == "Gate_" then
		for _, d in c:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "Accent" then
				d.Color = WISTERIA
			elseif d:IsA("TextLabel") then
				local needs = d.Text:match("\n(.*)$") or ""
				d.Text = TITLE .. "\n" .. needs
			end
		end
	end
end

markSlim(root, Z0, Z1)
return string.format("zone 2 Demon Slayer v2: %d parts\n%s", #partsOf(root), sideReport(root))
