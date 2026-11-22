-- LIB: side_lib
-- zone_16_jujutsu.luau - zone 16, "Shibuya" (Jujutsu Kaisen), on the slim lane (v2, 2026-11-22).
-- z 5560..5920 (map id shibuya, no zone data yet), lane floor y -48, lane edges x +-100. Run with
--   python tools/studio/zones/run_zone.py build 16
-- then lane_border.luau. Safe to run again. v1 (zone_lib, the 320-wide lane): MapArchive.Zone16_v1_canyon
-- and tools/studio/retired/zone_16_jujutsu_v1.luau.
--
-- The Shibuya crossing. The lane is one giant zebra crossing; each side a road along it with zebra
-- crossings and their signals, a sidewalk, dark concrete walls with a purple neon band.
--   +X, the crossing: the cylindrical fashion tower with the faithful dog's statue before it, the
--     ad-screen tower, the station with a train on the road, a cinema, the subway entrance, and the
--     panda's statue at the far end facing the throwers
--   -X, the sorcerers: the school's hall behind a torii, a tower block, a noodle shop, the cursed
--     shrine with the sealed box before it, a corner store, and the giant cursed finger at the far end
--   neon screens and a skyline on the shelves
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local map = workspace.Map
local KIT = RS.Assets.Kit
local SRC = SS.StoreAssets.Zone16_Jujutsu
local Z4 = SS.StoreAssets.Zone04_MHA
local Z10 = SS.StoreAssets.Zone10_Chainsaw
local JUNGLE = SS.StoreAssets.Zone01_Naruto
local ID = "shibuya"
local LY, HALF, Z0, Z1 = P.LY, P.HALF, 5560, 5920
local rng = Random.new(16107)

local ASPHALT = Color3.fromRGB(52, 54, 62)
local SIDEWALK = Color3.fromRGB(160, 162, 172)
local WHITE = Color3.fromRGB(244, 244, 240)
local YELLOW = Color3.fromRGB(250, 208, 40)
local PURPLE = Color3.fromRGB(120, 80, 220)
local STEEL = Color3.fromRGB(84, 86, 98)
local C = Enum.Material.Concrete
local GY = P.TERRACE_Y + 0.4
local SCREENS = { "SHIBUYA 109", "JUJUTSU HIGH", "CURSED ENERGY", "TOKYO METRO" }

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
local function parked(template: Instance, scale: number, x: number, z: number, yaw: number)
	still(make(props, template, scale, yaw, Vector3.new(x, GY - 0.2, z)), false)
end
local function plinth(x: number, z: number, radius: number, rim: Color3): number
	cylinder(city, "Plinth", radius * 2, 3, CFrame.new(x, GY + 1.5, z), STEEL, C).CastShadow = false
	cylinder(city, "PlinthRim", radius * 2 + 1.2, 0.5, CFrame.new(x, GY + 3.1, z), rim)
	claim(rect(x - radius - 1, x + radius + 1, z - radius - 1, z + radius + 1, "Plinth"))
	return GY + 3.2
end
-- a zebra crossing across the road at z, and the signals at its kerb
local function crossing(side: number, z: number)
	for i = 0, 3 do
		local a = P.KERB_OUT + 0.6 + i * 2.9
		paint(ground, side * a, side * (a + 1.9), z - 7, z + 7, WHITE, GY - 0.2)
	end
	prop(SRC.Signal, 2.6, side * (P.STREET_OUT + 3), z - 9, 0, { soft = 0.5 })
end

-- ---------------------------------------------------------------------------------- the zone's folder
local scenery = map.Scenery
local archive = SS:FindFirstChild("MapArchive") or folder(SS, "MapArchive")
if not archive:FindFirstChild("Zone16_v1_canyon") then
	local keep = scenery["Zone_" .. ID]:Clone()
	keep.Name = "Zone16_v1_canyon"
	keep:SetAttribute(
		"Note",
		"Zone 16 (Shibuya) v1 on the 320-wide lane, before the slim-lane rebuild (2026-11-22). Never delete."
	)
	keep.Parent = archive
end
local root = scenery["Zone_" .. ID]
root:ClearAllChildren()
root:SetAttribute("Theme", "Shibuya (Jujutsu Kaisen), zone_16_jujutsu.luau v2 on side_lib")
ground = folder(root, "Ground")
city = folder(root, "City")
props = folder(root, "Props")
local trees = folder(root, "Trees")

-- ---------------------------------------------------------------------------------- the ground
local STYLE = {
	stone = STEEL,
	material = C,
	band = PURPLE,
	cap = Color3.fromRGB(120, 122, 132),
	capMaterial = C,
	rail = Color3.fromRGB(110, 112, 124),
	buttress = 38,
}
if DO_TERRAIN then
	sideGround(Z0, Z1)
end
claimGates(Z0, Z1)
for _, s in { -1, 1 } do
	box(ground, "Kerb", s * HALF, s * P.KERB_OUT, LY - 2, LY + 3, Z0, Z1, YELLOW, C)
	local wall = revetment(ground, s, Z0, Z1, STYLE)
	for _, p in wall:GetChildren() do
		if p:IsA("BasePart") and p.Name == "Band" then
			p.Material = Enum.Material.Neon
		end
	end
	pave(
		ground,
		s * P.KERB_OUT,
		s * P.STREET_OUT,
		Z0,
		Z1,
		GY - 0.2,
		ASPHALT,
		Enum.Material.Asphalt,
		"Road"
	)
	pave(
		ground,
		s * P.STREET_OUT,
		s * (P.TERRACE_OUT - P.BATTER + 0.5),
		Z0,
		Z1,
		GY,
		SIDEWALK,
		C,
		"Sidewalk"
	)
	table.insert(claims, rect(s * HALF, s * P.STREET_OUT, Z0, Z1, "Road"))
end

-- ================================================================================== +X: the crossing
building(SRC.FashionTower, 1, 1.1, 141.5, 5637)
prop(SRC.DogStatue, 0.9, 125, 5637, facing(1))
building(SRC.AdTower, 1, 1.2, 139, 5673)
building(SRC.Station, 1, 1.3, 129, 5717)
building(Z10.Cinema, 1, 1.4, 137, 5761)
prop(SRC.Subway, 1.0, 128, 5794, facing(1))
parked(SRC.Train, 1.2, 110, 5717, 0)
parked(Z4.Taxi, 1.2, 110, 5640, 0)
parked(Z4.Car, 1.2, 110, 5770, 180)
for _, z in { 5655, 5693, 5740, 5810 } do
	crossing(1, z)
end
-- the panda on its plinth, facing the throw stage
do
	local top = plinth(142, 5862, 15, YELLOW)
	still(make(city, SRC.Panda, 1.3, 0, Vector3.new(142, top, 5862)), true)
end

-- ================================================================================== -X: the sorcerers
building(SRC.School, -1, 1.4, 131.5, 5641)
prop(
	KIT:FindFirstChild("Prop_realm_of_legends_GreatTorii"),
	0.6,
	-(P.STREET_OUT + 6),
	5641,
	facing(-1)
)
building(Z4.Skyscraper, -1, 1.2, 141.5, 5677)
building(Z10.NoodleShop, -1, 1.3, 140.5, 5713)
building(SRC.Shrine, -1, 1.15, 133.5, 5756)
prop(SRC.SealedBox, 1.0, -(P.STREET_OUT + 9), 5756, facing(-1))
building(Z4.Konbini, -1, 1.3, 149.2, 5793)
parked(Z4.Bus, 1.35, -110, 5690, 0)
parked(Z4.Car, 1.2, -110, 5640, 180)
parked(Z10.SirenCar, 1.2, -110, 5790, 0)
for _, z in { 5661, 5735, 5812 } do
	crossing(-1, z)
end
-- the giant cursed finger on its plinth, facing the throw stage
do
	local top = plinth(-142, 5864, 15, PURPLE)
	still(make(city, SRC.Finger, 2.2, 0, Vector3.new(-142, top, 5864)), true)
end

-- ================================================================================== the shelves
local SHELF = P.REVET_OUT + 1.5
for _, s in { -1, 1 } do
	for i, bz in { 5650, 5800 } do
		local ax = SHELF + 4
		local glow = if i % 2 == 1
			then Color3.fromRGB(255, 80, 170)
			else Color3.fromRGB(80, 220, 255)
		local board = sign(
			props,
			SCREENS[(i + (if s > 0 then 0 else 2) - 1) % #SCREENS + 1],
			44,
			11,
			CFrame.new(s * ax, P.SHELF_Y + 10, bz) * CFrame.Angles(0, math.rad(facing(s)), 0),
			Color3.fromRGB(24, 24, 34),
			glow
		)
		board.Name = "Screen"
		board.Material = Enum.Material.Neon
		block(
			props,
			"ScreenEdge",
			Vector3.new(1, 12, 45),
			CFrame.new(s * (ax + 0.5), P.SHELF_Y + 10, bz),
			glow,
			Enum.Material.Neon
		)
		for _, d in { -17, 17 } do
			block(
				props,
				"ScreenLeg",
				Vector3.new(1.6, 6, 1.6),
				CFrame.new(s * (ax + 0.4), P.SHELF_Y + 2.5, bz + d),
				STEEL,
				Enum.Material.Metal
			)
		end
		claim(rect(s * (ax - 1), s * (ax + 2), bz - 23, bz + 23, "Screen"))
	end
	building(if s > 0 then Z4.Apartment else Z4.Skyscraper, s, 1.0, SHELF, 5725)
	building(SRC.AdTower, s, 0.85, SHELF + 2, 5880)
	for _, z in { 5605, 5768 } do
		local t = put(
			trees,
			JUNGLE.TreeBroad,
			0.85,
			rng:NextInteger(0, 3) * 90,
			s * 192,
			z,
			{ soft = 3.4 }
		)
		if t then
			still(t, false)
		end
	end
end

-- ---------------------------------------------------------------------------------- the lane's floor
floorKit({
	id = ID,
	title = "SHIBUYA",
	accent = PURPLE,
	-- a zebra crossing: every other row of tiles is white, right across the lane
	strip = function(tile: number, _track: number)
		if tile % 2 == 0 then
			return Color3.fromRGB(244, 244, 240), Color3.fromRGB(255, 255, 255)
		end
		return Color3.fromRGB(50, 52, 62), Color3.fromRGB(100, 104, 118)
	end,
	kerb = YELLOW,
	paving = Color3.fromRGB(96, 98, 110),
	pavingTex = Color3.fromRGB(146, 148, 162),
})

markSlim(root, Z0, Z1)
return string.format("zone 16 Shibuya v2: %d parts\n%s", #partsOf(root), sideReport(root))
