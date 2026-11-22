-- LIB: side_lib
-- zone_11_jojo.luau - zone 11, "Bizarre Streets" (JoJo's Bizarre Adventure), on the slim lane (v2,
-- 2026-11-22). z 3760..4120 (map id bizarre_streets, no zone data yet), lane floor y -48, lane edges
-- x +-100. Run with
--   python tools/studio/zones/run_zone.py build 11
-- then lane_border.luau. Safe to run again. v1 (zone_lib, the 320-wide lane): MapArchive.Zone11_v1_canyon
-- and tools/studio/retired/zone_11_jojo_v1.luau.
--
-- A sunlit Italian town on cobbles between warm limestone walls with terracotta caps.
--   +X: a palazzo, the baroque church with a fountain in its round piazza, a cafe, a townhouse, and the
--     golden arrow on its plinth facing the throwers
--   -X: the pizzeria, a townhouse, the clock tower with the yellow road roller parked askew before it,
--     a palazzo, a townhouse, and the fanged stone mask at the far end
--   scooters at the kerb, ladybug columns, lamps; the menacing katakana hang in the air over the
--   shelves; a palazzo and palms on each shelf
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local map = workspace.Map
local KIT = RS.Assets.Kit
local SRC = SS.StoreAssets.Zone11_JoJo
local JUNGLE = SS.StoreAssets.Zone01_Naruto
local PALM = SS.StoreAssets.Zone03_OnePiece.Palm
local ID = "bizarre_streets"
local LY, HALF, Z0, Z1 = P.LY, P.HALF, 3760, 4120
local rng = Random.new(11107)

local COBBLE = Color3.fromRGB(214, 196, 170)
local CREAM = Color3.fromRGB(240, 228, 204)
local STONE = Color3.fromRGB(204, 190, 166)
local STONE_DARK = Color3.fromRGB(164, 148, 124)
local TERRACOTTA = Color3.fromRGB(190, 108, 72)
local MENACE = Color3.fromRGB(150, 70, 210)
local GOLD = Color3.fromRGB(240, 198, 62)
local GY = P.TERRACE_Y + 0.4

local function facing(side: number): number
	return if side > 0 then 90 else -90 -- a squared template fronts to -Z: turn it to the lane
end
local town: Folder, props: Folder -- set below, once the zone's folder is cleared
local function building(
	template: Instance,
	side: number,
	scale: number,
	ax: number,
	z: number
): Model?
	local m = front(town, template, side, scale, ax, z)
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
local function plinth(x: number, z: number, radius: number, rim: Color3)
	cylinder(town, "Plinth", radius * 2, 3, CFrame.new(x, GY + 1.5, z), STONE, Enum.Material.Marble).CastShadow =
		false
	cylinder(town, "PlinthRim", radius * 2 + 1.2, 0.5, CFrame.new(x, GY + 3.1, z), rim)
	claim(rect(x - radius - 1, x + radius + 1, z - radius - 1, z + radius + 1, "Plinth"))
end

-- ---------------------------------------------------------------------------------- the zone's folder
local scenery = map.Scenery
local archive = SS:FindFirstChild("MapArchive") or folder(SS, "MapArchive")
if not archive:FindFirstChild("Zone11_v1_canyon") then
	local keep = scenery["Zone_" .. ID]:Clone()
	keep.Name = "Zone11_v1_canyon"
	keep:SetAttribute(
		"Note",
		"Zone 11 (Bizarre Streets) v1 on the 320-wide lane, before the slim-lane rebuild (2026-11-22). Never delete."
	)
	keep.Parent = archive
end
local root = scenery["Zone_" .. ID]
root:ClearAllChildren()
root:SetAttribute(
	"Theme",
	"Bizarre Streets (JoJo's Bizarre Adventure), zone_11_jojo.luau v2 on side_lib"
)
local ground = folder(root, "Ground")
town = folder(root, "Town")
props = folder(root, "Props")
local trees = folder(root, "Trees")

-- ---------------------------------------------------------------------------------- the ground
local STYLE = {
	stone = STONE,
	material = Enum.Material.Limestone,
	band = STONE_DARK,
	cap = TERRACOTTA,
	capMaterial = Enum.Material.Brick,
	rail = Color3.fromRGB(46, 42, 48),
	buttress = 36,
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
		Color3.fromRGB(236, 82, 150),
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
		COBBLE,
		Enum.Material.Cobblestone,
		"Cobbles"
	)
	table.insert(claims, rect(s * HALF, s * P.STREET_OUT, Z0, Z1, "Street"))
end
local lamp = KIT:FindFirstChild("Prop_store_LampPost")

-- ================================================================================== +X: the piazza
building(SRC.Palazzo, 1, 1.5, 135, 3842)
building(SRC.Church, 1, 1.6, 146.5, 3902)
building(SRC.Cafe, 1, 1.6, 132.5, 3960)
building(SRC.Townhouse, 1, 1.5, 140, 4007)
-- the church's piazza: a pale round of marble, the fountain in its middle, benches either side
do
	local px, pz = 127, 3902
	cylinder(ground, "Piazza", 34, 0.3, CFrame.new(px, GY + 0.15, pz), CREAM, Enum.Material.Marble).CastShadow =
		false
	prop(SRC.Fountain, 1.0, px, pz, 0)
	local bench = KIT:FindFirstChild("Prop_sakura_schoolyard_Bench")
	for _, dz in { -22, 22 } do
		prop(bench, 1.4, px + 8, pz + dz, facing(1))
	end
end
prop(SRC.Ladybug, 1.0, P.STREET_OUT + 7, 3830, facing(1))
-- the golden arrow on its plinth, facing the throw stage
plinth(142, 4072, 13, GOLD)
still(make(town, SRC.Arrow, 1.5, 0, Vector3.new(142, GY + 3.2, 4072)), true)

-- ================================================================================== -X: the street
building(SRC.Pizzeria, -1, 1.6, 132.5, 3830)
building(SRC.Townhouse, -1, 1.5, 140, 3868)
building(SRC.ClockTower, -1, 1.1, 151, 3906)
building(SRC.Palazzo, -1, 1.5, 135, 3946)
building(SRC.Townhouse, -1, 1.5, 140, 3996)
-- the road roller, parked askew before the clock tower
do
	local rx, rz = -131, 3908
	still(make(props, SRC.RoadRoller, 1.35, 150, Vector3.new(rx, GY, rz)), true)
	claim(rect(rx - 13, rx + 13, rz - 13, rz + 13, "RoadRoller"))
end
prop(SRC.Ladybug, 1.0, -(P.STREET_OUT + 7), 3956, facing(-1))
-- the stone mask on its plinth, facing the throw stage
plinth(-142, 4070, 16, MENACE)
still(make(town, SRC.StoneMask, 1.6, 0, Vector3.new(-142, GY + 3.2, 4070)), true)

-- ================================================================================== both streets and shelves
local SHELF = P.REVET_OUT + 1.5
for _, s in { -1, 1 } do
	for z = 3828, Z1 - 30, 46 do
		if lamp then
			prop(lamp, 1.5, s * (P.STREET_OUT + 2.5), z, facing(s))
		end
	end
	-- scooters at the kerb
	for i, z in { 3852, 3860, 3976, 4030, 4038 } do
		still(
			make(
				props,
				SRC.Scooter,
				1.5,
				(if s > 0 then 20 else 200) + i * 15,
				Vector3.new(s * (P.STREET_OUT - 4), GY, z)
			),
			false
		)
	end
	-- the menace: katakana hanging in the air over the shelf, read from the lane
	for i = 0, 4 do
		local size = 18 + (i % 3) * 6
		local sz = 3800 + i * 64 + s * 10
		local board = block(
			props,
			"Menace",
			Vector3.new(0.4, size, size),
			CFrame.new(s * (SHELF + 8), P.SHELF_Y + 22 + (i % 3) * 7, sz)
				* CFrame.Angles(math.rad((i % 2) * 14 - 7), 0, 0),
			MENACE
		)
		board.Transparency = 1
		board.CastShadow = false
		words(
			board,
			if s > 0 then Enum.NormalId.Left else Enum.NormalId.Right,
			"ゴ",
			MENACE,
			Enum.Font.SourceSansBold
		)
	end
	-- a palazzo on the shelf over the middle of the street, palms either side
	building(SRC.Palazzo, s, 0.9, SHELF, 3940 + s * 30)
	for _, z in { 3830, 3890, 4020, 4080 } do
		local t = put(
			trees,
			if rng:NextNumber() < 0.6 then PALM else JUNGLE.TreeBroad,
			0.95,
			rng:NextInteger(0, 3) * 90,
			s * 192,
			z + s * 6,
			{ soft = 3.8 }
		)
		if t then
			still(t, false)
		end
	end
end

-- ---------------------------------------------------------------------------------- the lane's floor
floorKit({
	id = ID,
	title = "BIZARRE STREETS",
	accent = Color3.fromRGB(150, 70, 210),
	strip = function(tile: number, track: number)
		if (tile + track) % 2 == 0 then
			return Color3.fromRGB(112, 62, 176), Color3.fromRGB(170, 130, 224)
		end
		return Color3.fromRGB(240, 198, 62), Color3.fromRGB(252, 230, 150)
	end,
	kerb = Color3.fromRGB(236, 82, 150),
	paving = Color3.fromRGB(214, 196, 170),
	pavingTex = Color3.fromRGB(236, 224, 204),
})

markSlim(root, Z0, Z1)
return string.format("zone 11 Bizarre Streets v2: %d parts\n%s", #partsOf(root), sideReport(root))
