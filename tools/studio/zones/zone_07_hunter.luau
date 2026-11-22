-- LIB: side_lib
-- zone_07_hunter.luau - zone 7, "Hunter Exam" (Hunter x Hunter), on the slim lane (v2, 2026-11-22).
-- z 2320..2680 (map id hunter_exam, no zone data yet), lane floor y -48, lane edges x +-100. Run with
--   python tools/studio/zones/run_zone.py build 7
-- then lane_border.luau. Safe to run again. v1 (zone_lib, the 320-wide lane): MapArchive.Zone7_v1_canyon
-- and tools/studio/retired/zone_07_hunter_v1.luau.
--
-- A forest pass, and the exam held in it: earthen stone with mossy caps, dirt roads, a forest floor
-- of mushrooms, logs and mossy rocks (and only a few trees: owner).
--   +X, the exam: the steakhouse that hides the way in, the exam hall, the windowless trick tower,
--     the examinees' camp, and across the terrace's far end the colossal stone testing gate facing
--     the throwers; the arena tower on the shelf, the airship hanging over the camp
--   -X, the wild: a tree house, a waterfall into a pond, the world tree, a second tree house, the
--     ants' earthen nest, and the stone fisher boy on his rock at the far end
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local map = workspace.Map
local KIT = RS.Assets.Kit
local SRC = SS.StoreAssets.Zone07_Hunter
local JUNGLE = SS.StoreAssets.Zone01_Naruto
local MOSS = SS.StoreAssets.Zone02_DemonSlayer.MossRock
local CEDAR = SS.StoreAssets.Zone02_DemonSlayer.Cedar
local ID = "hunter_exam"
local LY, HALF, Z0, Z1 = P.LY, P.HALF, 2320, 2680
local rng = Random.new(7707)

local DIRT = Color3.fromRGB(146, 112, 80)
local EARTH = Color3.fromRGB(122, 104, 86)
local EARTH_DARK = Color3.fromRGB(84, 70, 56)
local MOSS_CAP = Color3.fromRGB(86, 132, 72)
local WOOD = Color3.fromRGB(96, 66, 44)
local STONE = Color3.fromRGB(140, 140, 136)
local WATER = Color3.fromRGB(96, 190, 244)
local GY = P.TERRACE_Y + 0.4

local function facing(side: number): number
	return if side > 0 then 90 else -90 -- a squared template fronts to -Z: turn it to the lane
end
local sights: Folder, props: Folder -- set below, once the zone's folder is cleared
local function sight(
	template: Instance,
	side: number,
	scale: number,
	ax: number,
	z: number,
	opts: any?
): Model?
	local m = front(sights, template, side, scale, ax, z, opts)
	if m then
		still(m, true)
	end
	return m
end
local function prop(
	template: Instance?,
	scale: number,
	x: number,
	z: number,
	yaw: number,
	opts: any?
): Model?
	if not template then
		return nil
	end
	local m = put(props, template, scale, yaw, x, z, opts)
	if m then
		still(m, false)
	end
	return m
end

-- ---------------------------------------------------------------------------------- the zone's folder
local scenery = map.Scenery
local archive = SS:FindFirstChild("MapArchive") or folder(SS, "MapArchive")
if not archive:FindFirstChild("Zone7_v1_canyon") then
	local keep = scenery["Zone_" .. ID]:Clone()
	keep.Name = "Zone7_v1_canyon"
	keep:SetAttribute(
		"Note",
		"Zone 7 (Hunter Exam) v1 on the 320-wide lane, before the slim-lane rebuild (2026-11-22). Never delete."
	)
	keep.Parent = archive
end
local root = scenery["Zone_" .. ID]
root:ClearAllChildren()
root:SetAttribute("Theme", "Hunter Exam (Hunter x Hunter), zone_07_hunter.luau v2 on side_lib")
local ground = folder(root, "Ground")
sights = folder(root, "Sights")
props = folder(root, "Props")
local trees = folder(root, "Trees")

-- ---------------------------------------------------------------------------------- the ground
local STYLE = {
	stone = EARTH,
	material = Enum.Material.Cobblestone,
	band = EARTH_DARK,
	cap = MOSS_CAP,
	capMaterial = Enum.Material.Grass,
	rail = WOOD,
	buttress = 32,
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
		Color3.fromRGB(44, 110, 66),
		Enum.Material.Slate
	)
	revetment(ground, s, Z0, Z1, STYLE)
	pave(
		ground,
		s * P.KERB_OUT,
		s * (P.STREET_OUT + 2),
		Z0,
		Z1,
		GY - 0.1,
		DIRT,
		Enum.Material.Ground,
		"DirtRoad"
	)
	table.insert(claims, rect(s * HALF, s * (P.STREET_OUT + 2), Z0, Z1, "Road"))
end
local lamp = KIT:FindFirstChild("Prop_store_LampPost")

-- ================================================================================== +X: the exam
sight(SRC.Steakhouse, 1, 1.6, 132.5, 2394)
sight(SRC.ExamHall, 1, 1.1, 123.5, 2436)
sight(SRC.TrickTower, 1, 1.4, 129, 2484)
-- the testing gate across the terrace's far end, facing the throw stage
local gate = put(sights, SRC.TestingGate, 1.6, 0, 142, 2652, { name = "TestingGate" })
if gate then
	still(gate, true)
end
-- the examinees' camp between the tower and the gate
do
	local mid = 2560
	prop(SRC.Camp, 1.3, 140, mid - 22, 200)
	prop(SRC.Camp, 1.2, 150, mid + 18, 60)
	prop(SRC.Signpost, 1.4, P.STREET_OUT + 6, mid, facing(1))
	prop(SRC.FallenLog, 1.5, 132, mid + 2, 70)
	prop(KIT:FindFirstChild("Prop_store_Barrel"), 1.5, 160, mid - 2, 0)
	prop(KIT:FindFirstChild("Prop_store_Crate"), 1.5, 160, mid + 40, 30)
end
-- the airship over the camp, heading for the arena tower (in the air: no claim)
local ship = make(sights, SRC.Airship, 1.25, 0, Vector3.new(150, 16, 2560))
ship:SetAttribute("LaneOk", true)
still(ship, true)

-- ================================================================================== -X: the wild
sight(SRC.TreeHouse, -1, 1.3, 136.5, 2392)
-- a waterfall down the revetment into a pond rimmed with mossy rocks
do
	local fz = 2440
	sheetFall(ground, -1, fz, 16, GY + 0.6)
	local pond = cylinder(ground, "Pond", 30, 0.8, CFrame.new(-148, GY + 0.3, fz), WATER)
	pond.Transparency = 0.15
	pond.Reflectance = 0.08
	pond.CastShadow = false
	claim(rect(-168, -132, fz - 16, fz + 16, "Pond"))
	for i = 0, 5 do
		local a = math.rad(100 + i * 32)
		still(
			make(
				trees,
				MOSS,
				0.3,
				i * 50,
				Vector3.new(-148 + math.cos(a) * 16, GY - 1.2, fz + math.sin(a) * 16)
			),
			false
		)
	end
end
-- the world tree: a big crown, claimed only at its trunk (things may stand under it)
local giant = put(sights, SRC.GiantTree, 1.15, 0, -143, 2492, { soft = 18 })
if giant then
	still(giant, true)
	giant:SetAttribute("Soft", true)
end
sight(SRC.TreeHouse, -1, 1.15, 140, 2548)
sight(SRC.AntNest, -1, 1.2, 132, 2592)
-- the fisher boy on his rock at the far end
do
	local sx, sz = -142, 2646
	cylinder(
		sights,
		"StatueRock",
		26,
		2.4,
		CFrame.new(sx, GY + 0.8, sz),
		STONE,
		Enum.Material.Slate
	).CastShadow =
		false
	claim(rect(sx - 14, sx + 14, sz - 14, sz + 14, "StatueRock"))
	still(make(sights, SRC.FisherStatue, 1.2, 0, Vector3.new(sx, GY + 2, sz)), true)
end

-- ================================================================================== lamps and the forest floor
for _, s in { -1, 1 } do
	for z = 2392, Z1 - 40, 52 do
		if lamp then
			prop(lamp, 1.5, s * (P.STREET_OUT + 3.5), z, facing(s))
		end
	end
	local t0, t1 = P.STREET_OUT + 4, P.TERRACE_OUT - P.BATTER - 2
	scatter({
		parent = trees,
		templates = { SRC.Mushrooms },
		count = 4,
		side = s,
		ax = { t0, t1 },
		z = { 2380, Z1 - 10 },
		scale = { 0.5, 0.8 },
		soft = 1,
	})
	scatter({
		parent = trees,
		templates = { SRC.FallenLog },
		count = 2,
		side = s,
		ax = { t0, t1 },
		z = { 2380, Z1 - 10 },
		scale = { 1.2, 1.6 },
		soft = 1,
	})
	scatter({
		parent = trees,
		templates = { MOSS },
		count = 3,
		side = s,
		ax = { t0, t1 },
		z = { 2380, Z1 - 10 },
		scale = { 0.3, 0.5 },
		soft = 1,
	})
	scatter({
		parent = trees,
		templates = { JUNGLE.BushLeafy },
		count = 4,
		side = s,
		ax = { t0, t1 },
		z = { 2380, Z1 - 10 },
		scale = { 1.2, 1.7 },
		soft = 1,
	})
end

-- ================================================================================== the shelves
local SHELF = P.REVET_OUT + 1.5
sight(SRC.ArenaTower, 1, 1.0, SHELF + 1, 2436)
local function tree(x: number, z: number, scale: number, template: Instance?)
	local t = put(
		trees,
		template or (if rng:NextNumber() < 0.5 then JUNGLE.TreeBroad else CEDAR),
		scale,
		rng:NextInteger(0, 3) * 90,
		x,
		z,
		{ soft = 4 * scale }
	)
	if t then
		still(t, false)
	end
end
for _, t in
	{
		{ 192, 2380, 1.0 },
		{ 192, 2500, 1.05 },
		{ 192, 2610, 1.0 },
		{ -192, 2396, 1.0 },
		{ -192, 2520, 1.1 },
		{ -192, 2640, 1.0 },
	}
do
	tree(t[1], t[2], t[3])
end
for _, s in { -1, 1 } do
	scatter({
		parent = trees,
		templates = { SRC.Mushrooms, JUNGLE.BushLeafy },
		count = 4,
		side = s,
		ax = { 184, 200 },
		z = { Z0 + 20, Z1 - 10 },
		scale = { 0.6, 1.2 },
		soft = 1,
	})
	scatter({
		parent = trees,
		templates = { SRC.FallenLog, MOSS },
		count = 2,
		side = s,
		ax = { 184, 200 },
		z = { Z0 + 20, Z1 - 10 },
		scale = { 0.4, 1.2 },
		soft = 1,
	})
end

-- leaves on the wind
local fx = folder(root, "Fx")
for _, z in { 2390, 2480, 2570, 2650 } do
	local source = block(
		fx,
		"LeafSource",
		Vector3.new(2 * HALF - 8, 1, 70),
		CFrame.new(0, LY + 84, z),
		Color3.new(1, 1, 1)
	)
	source.Transparency = 1
	source.CastShadow = false
	local e = Instance.new("ParticleEmitter")
	e.Name = "Leaves"
	e.Texture = "rbxassetid://5057182105"
	e.Color = ColorSequence.new(Color3.fromRGB(120, 200, 96), Color3.fromRGB(70, 150, 70))
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 1.7),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.1, 0),
		NumberSequenceKeypoint.new(0.85, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(9, 13)
	e.Rate = 4
	e.Speed = NumberRange.new(5, 9)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.SpreadAngle = Vector2.new(25, 25)
	e.Acceleration = Vector3.new(2.5, -1, 1.5)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-110, 110)
	e.LightEmission = 0.1
	e.Parent = source
end

-- ---------------------------------------------------------------------------------- the lane's floor
floorKit({
	id = ID,
	title = "HUNTER EXAM",
	accent = Color3.fromRGB(214, 44, 52),
	strip = function(tile: number, track: number)
		if (tile + track) % 2 == 0 then
			return Color3.fromRGB(236, 142, 44), Color3.fromRGB(250, 196, 120)
		end
		return Color3.fromRGB(250, 226, 172), Color3.fromRGB(255, 244, 214)
	end,
	kerb = Color3.fromRGB(44, 110, 66),
	paving = Color3.fromRGB(190, 170, 140),
	pavingTex = Color3.fromRGB(224, 208, 184),
})

markSlim(root, Z0, Z1)
return string.format("zone 7 Hunter Exam v2: %d parts\n%s", #partsOf(root), sideReport(root))
