-- LIB: side_lib
-- zone_14_bleach.luau - zone 14, "Soul Society" (Bleach), on the slim lane (v2, 2026-11-22).
-- z 4840..5200 (map id soul_society, no zone data yet), lane floor y -48, lane edges x +-100. Run with
--   python tools/studio/zones/run_zone.py build 14
-- then lane_border.luau. Safe to run again. v1 (zone_lib, the 320-wide lane): MapArchive.Zone14_v1_canyon
-- and tools/studio/retired/zone_14_bleach_v1.luau.
--
-- The white city of the swordsmen, on pale stone over grey revetments (so its white walls show).
--   +X, the court: the great gatehouse, the captains' hall, the tiered white tower, the dojo with its
--     raked court and sword racks, and the giant sword on its plinth facing the throwers
--   -X, the outer town: the sweet shop, a hall, the tower on its hill, a second dojo with its court,
--     and the giant hollow mask at the far end
--   the city's long white wall with an orange tiled cap down both shelves, pines behind it; lanterns
--   along the streets; black butterflies in the air
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local map = workspace.Map
local KIT = RS.Assets.Kit
local SRC = SS.StoreAssets.Zone14_Bleach
local ID = "soul_society"
local LY, HALF, Z0, Z1 = P.LY, P.HALF, 4840, 5200
local rng = Random.new(14107)

local PAVE = Color3.fromRGB(206, 200, 188)
local GRAVEL = Color3.fromRGB(232, 228, 216)
local WHITE = Color3.fromRGB(244, 240, 232)
local TILE = Color3.fromRGB(226, 118, 44)
local WOOD = Color3.fromRGB(96, 66, 46)
local STONE = Color3.fromRGB(128, 126, 124)
local GY = P.TERRACE_Y + 0.4

local function facing(side: number): number
	return if side > 0 then 90 else -90 -- a squared template fronts to -Z: turn it to the lane
end
local city: Folder, props: Folder, ground: Folder -- set below, once the zone's folder is cleared
local function building(
	template: Instance,
	side: number,
	scale: number,
	ax: number,
	z: number
): Model?
	local m = front(city, template, side, scale, ax, z)
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
local function plinth(x: number, z: number, radius: number): number
	for i, r in { radius, radius - 3.5 } do
		cylinder(
			city,
			"Plinth",
			r * 2,
			1.4,
			CFrame.new(x, GY + i * 1.3 - 0.6, z),
			if i == 2 then WHITE else STONE,
			Enum.Material.Slate
		).CastShadow =
			false
	end
	claim(rect(x - radius - 1, x + radius + 1, z - radius - 1, z + radius + 1, "Plinth"))
	return GY + 2.5
end
-- a raked gravel court in front of a building (x signed: from the street to the building's face)
local function court(side: number, ax0: number, ax1: number, z0: number, z1: number)
	paint(ground, side * ax0, side * ax1, z0, z1, GRAVEL, GY).Material = Enum.Material.Sand
	for ax = ax0 + 2, ax1 - 2, 4 do
		paint(
			ground,
			side * ax,
			side * (ax + 0.5),
			z0 + 2,
			z1 - 2,
			Color3.fromRGB(206, 200, 186),
			GY + 0.05
		)
	end
	table.insert(claims, rect(side * ax0, side * ax1, z0, z1, "Court"))
end

-- ---------------------------------------------------------------------------------- the zone's folder
local scenery = map.Scenery
local archive = SS:FindFirstChild("MapArchive") or folder(SS, "MapArchive")
if not archive:FindFirstChild("Zone14_v1_canyon") then
	local keep = scenery["Zone_" .. ID]:Clone()
	keep.Name = "Zone14_v1_canyon"
	keep:SetAttribute(
		"Note",
		"Zone 14 (Soul Society) v1 on the 320-wide lane, before the slim-lane rebuild (2026-11-22). Never delete."
	)
	keep.Parent = archive
end
local root = scenery["Zone_" .. ID]
root:ClearAllChildren()
root:SetAttribute("Theme", "Soul Society (Bleach), zone_14_bleach.luau v2 on side_lib")
ground = folder(root, "Ground")
city = folder(root, "City")
local walls = folder(root, "Walls")
props = folder(root, "Props")
local trees = folder(root, "Trees")
local air = folder(root, "Butterflies")

-- ---------------------------------------------------------------------------------- the ground
local STYLE = {
	stone = STONE,
	material = Enum.Material.Slate,
	band = Color3.fromRGB(96, 94, 92),
	cap = Color3.fromRGB(160, 156, 150),
	capMaterial = Enum.Material.Slate,
	buttress = 40,
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
		Color3.fromRGB(34, 34, 40),
		Enum.Material.Slate
	)
	revetment(ground, s, Z0, Z1, STYLE)
	pave(
		ground,
		s * P.KERB_OUT,
		s * (P.TERRACE_OUT - P.BATTER + 0.5),
		Z0,
		Z1,
		GY,
		PAVE,
		Enum.Material.Slate,
		"Paving"
	)
	table.insert(claims, rect(s * HALF, s * P.STREET_OUT, Z0, Z1, "Street"))
	-- the city's wall down the shelf: white plaster on a grey footing, posts, a dark beam, an orange
	-- tiled cap (pines behind it)
	local x0, x1 = P.REVET_OUT + 3, P.REVET_OUT + 7
	local wz0, wz1 = Z0 + 4, Z1 - 4
	box(
		walls,
		"Footing",
		s * (x0 - 1.5),
		s * (x1 + 1.5),
		P.SHELF_Y,
		P.SHELF_Y + 4,
		wz0,
		wz1,
		STONE,
		Enum.Material.Slate
	)
	box(
		walls,
		"Wall",
		s * x0,
		s * x1,
		P.SHELF_Y + 4,
		P.SHELF_Y + 16,
		wz0,
		wz1,
		WHITE,
		Enum.Material.Plaster
	)
	box(
		walls,
		"Beam",
		s * (x0 - 0.6),
		s * (x1 + 0.6),
		P.SHELF_Y + 15,
		P.SHELF_Y + 17,
		wz0,
		wz1,
		WOOD,
		Enum.Material.Wood
	)
	box(
		walls,
		"Cap",
		s * (x0 - 3),
		s * (x1 + 3),
		P.SHELF_Y + 17,
		P.SHELF_Y + 19.4,
		wz0,
		wz1,
		TILE,
		Enum.Material.Brick
	)
	box(
		walls,
		"Ridge",
		s * (x0 + 0.5),
		s * (x1 - 0.5),
		P.SHELF_Y + 19.4,
		P.SHELF_Y + 21.2,
		wz0,
		wz1,
		TILE:Lerp(Color3.new(0, 0, 0), 0.3),
		Enum.Material.Brick
	)
	for pz = wz0 + 2, wz1 - 2, 30 do
		box(
			walls,
			"Post",
			s * (x0 - 0.8),
			s * (x1 + 0.8),
			P.SHELF_Y + 4,
			P.SHELF_Y + 15,
			pz - 1.5,
			pz + 1.5,
			WOOD,
			Enum.Material.Wood
		)
	end
	claim(rect(s * (x0 - 3), s * (x1 + 3), wz0, wz1, "CityWall"))
end

-- ================================================================================== +X: the court
building(SRC.Gatehouse, 1, 1.2, 152, 4926)
building(SRC.Hall, 1, 1.4, 133, 4976)
building(SRC.Tower, 1, 1.4, 134.5, 5017)
building(SRC.Dojo, 1, 1.4, 131.5, 5066)
court(1, P.STREET_OUT + 2, 131, 5046, 5086)
for _, z in { 5054, 5078 } do
	still(make(props, SRC.SwordRack, 1.3, facing(1), Vector3.new(127, GY, z)), false)
end
-- the giant sword in its plinth, facing the throw stage
do
	local top = plinth(142, 5152, 15)
	still(make(city, SRC.Katana, 1.35, 0, Vector3.new(142, top, 5152)), true)
end

-- ================================================================================== -X: the outer town
building(SRC.SweetShop, -1, 1.5, 143, 4921)
building(SRC.Hall, -1, 1.3, 135.5, 4959)
building(SRC.HillTower, -1, 1.4, 131.5, 5003)
building(SRC.Dojo, -1, 1.3, 134, 5050)
court(-1, P.STREET_OUT + 2, 133.5, 5032, 5068)
still(make(props, SRC.SwordRack, 1.3, facing(-1), Vector3.new(-129, GY, 5050)), false)
prop(KIT:FindFirstChild("Prop_sakura_schoolyard_Bench"), 1.4, -(P.STREET_OUT + 8), 4946, facing(-1))
-- the hollow mask on its plinth, facing the throw stage
do
	local top = plinth(-142, 5150, 16)
	still(make(city, SRC.HollowMask, 1.4, 0, Vector3.new(-142, top, 5150)), true)
end

-- ================================================================================== lanterns, pines, butterflies
for _, s in { -1, 1 } do
	for z = 4912, Z1 - 70, 40 do
		prop(SRC.Lantern, 1.3, s * (P.STREET_OUT + 4.5), z, 0)
	end
	for _, z in { 4900, 5000, 5100, 5185 } do
		local t =
			put(trees, SRC.Pine, 1.05, rng:NextInteger(0, 3) * 90, s * 197, z + s * 8, { soft = 4 })
		if t then
			still(t, false)
		end
	end
	for i = 1, 8 do
		local b = make(
			air,
			SRC.Butterfly,
			2.4,
			rng:NextInteger(0, 359),
			Vector3.new(
				s * rng:NextNumber(108, 160),
				GY + rng:NextNumber(14, 34),
				4880 + i * 38 + rng:NextNumber(-8, 8)
			)
		)
		b:PivotTo(
			b:GetPivot()
				* CFrame.Angles(
					math.rad(rng:NextNumber(-30, 30)),
					0,
					math.rad(rng:NextNumber(-30, 30))
				)
		)
		b:SetAttribute("LaneOk", true)
		still(b, false)
	end
end

-- ---------------------------------------------------------------------------------- the lane's floor
floorKit({
	id = ID,
	title = "SOUL SOCIETY",
	accent = Color3.fromRGB(236, 120, 40),
	strip = function(tile: number, track: number)
		if (tile + track) % 2 == 0 then
			return Color3.fromRGB(236, 124, 44), Color3.fromRGB(250, 178, 110)
		end
		return Color3.fromRGB(248, 240, 222), Color3.fromRGB(255, 252, 242)
	end,
	kerb = Color3.fromRGB(34, 34, 40),
	paving = Color3.fromRGB(214, 206, 192),
	pavingTex = Color3.fromRGB(238, 232, 220),
})

markSlim(root, Z0, Z1)
return string.format("zone 14 Soul Society v2: %d parts\n%s", #partsOf(root), sideReport(root))
