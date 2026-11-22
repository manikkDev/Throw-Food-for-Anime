-- LIB: side_lib
-- zone_03_one_piece.luau - zone 3, "Grand Line" (One Piece), on the slim lane (v2, 2026-11-22).
-- z 880..1240 (config id still ninja_village), lane floor y -48, lane edges x +-100. Run with
--   python tools/studio/zones/run_zone.py build 3
-- then lane_border.luau. Safe to run again. v1 (zone_lib, the 320-wide lane): MapArchive.Zone3_v1_canyon
-- and tools/studio/retired/zone_03_one_piece_v1.luau.
--
-- A tropical harbour. The lane is the sea (blue swell tiles, straw-yellow kerbs); on each side a stone
-- quay along it, then the HARBOUR (real water where the other zones have their terrace), the
-- sandstone harbour wall (the revetment) with a waterfall, and the shelf above it, sand and palms.
--   +X, the pirates: the floating fish restaurant, a working pier with its crane, the lion-headed
--     ship, a pier with cannon, anchor and chest, the whale; on the shelf the windmill, the beach
--     bar, the giant straw hat and the wanted board
--   -X, the navy and the port: the warship, a town on a deck over the water (port houses, the
--     tavern, a market), the sheep-headed ship and rowboats, the sea king; on the shelf the marine
--     fortress, a battery of cannon and the lighthouse
-- Ships are smaller than v1's (owner: the map must not be too tall): their masts end near the wall.
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local map = workspace.Map
local KIT = RS.Assets.Kit
local SRC = SS.StoreAssets.Zone03_OnePiece
local JUNGLE = SS.StoreAssets.Zone01_Naruto
local ID = "ninja_village" -- the zone's id in config until the anime zone data lands
local LY, HALF, Z0, Z1 = P.LY, P.HALF, 880, 1240
local rng = Random.new(3307)

local SURFACE = LY - 1.5 -- the harbour's water
local DECK = LY - 0.4 -- piers and the town's deck
local QUAY = HALF + 6 -- the quay along the lane (x 100..106); the harbour from here to the wall
local HARBOUR_Z0 = 932 -- before it, a stone plaza where the gate stands
local PLANK = Color3.fromRGB(150, 106, 68)
local PLANK_DARK = Color3.fromRGB(92, 62, 44)
local SANDSTONE = Color3.fromRGB(214, 180, 132)
local SANDSTONE_DARK = Color3.fromRGB(170, 132, 92)
local QUAY_STONE = Color3.fromRGB(224, 208, 176)

local function facing(side: number): number
	return if side > 0 then 90 else -90 -- a squared template fronts to -Z: turn it to the lane
end
local function opt(name: string): Instance?
	return SRC:FindFirstChild(name)
end

-- ---------------------------------------------------------------------------------- the zone's folder
local scenery = map.Scenery
local archive = SS:FindFirstChild("MapArchive") or folder(SS, "MapArchive")
if not archive:FindFirstChild("Zone3_v1_canyon") then
	local keep = scenery["Zone_" .. ID]:Clone()
	keep.Name = "Zone3_v1_canyon"
	keep:SetAttribute(
		"Note",
		"Zone 3 (Grand Line) v1, the 320-wide lane's harbour canyon, before the slim-lane rebuild (2026-11-22). Never delete."
	)
	keep.Parent = archive
end
local root = scenery["Zone_" .. ID]
root:ClearAllChildren()
root:SetAttribute("Theme", "Grand Line (One Piece), zone_03_one_piece.luau v2 on side_lib")
local ground = folder(root, "Ground")
local ships = folder(root, "Ships")
local docks = folder(root, "Docks")
local town = folder(root, "Town")
local props = folder(root, "Props")
local trees = folder(root, "Trees")

-- ---------------------------------------------------------------------------------- the ground and the harbour
local STYLE = {
	stone = SANDSTONE,
	material = Enum.Material.Sandstone,
	band = SANDSTONE_DARK,
	cap = PLANK_DARK,
	capMaterial = Enum.Material.WoodPlanks,
	rail = PLANK_DARK,
	buttress = 30,
	wet = SURFACE,
}
if DO_TERRAIN then
	sideGround(Z0, Z1, { grass = Enum.Material.Sand })
	for _, s in { -1, 1 } do
		-- the harbour: the terrace's ground cut away, a sand bed and water up to the surface
		local a, b =
			math.min(s * QUAY, s * (P.TERRACE_OUT + 1)), math.max(s * QUAY, s * (P.TERRACE_OUT + 1))
		workspace.Terrain:FillBlock(
			CFrame.new((a + b) / 2, LY - 4, (HARBOUR_Z0 + Z1) / 2),
			Vector3.new(b - a, 40, Z1 - HARBOUR_Z0),
			Enum.Material.Air
		)
		workspace.Terrain:FillBlock(
			CFrame.new((a + b) / 2, LY - 17, (HARBOUR_Z0 + Z1) / 2),
			Vector3.new(b - a, 6, Z1 - HARBOUR_Z0),
			Enum.Material.Sand
		)
		workspace.Terrain:FillBlock(
			CFrame.new((a + b) / 2, (LY - 14 + SURFACE) / 2, (HARBOUR_Z0 + Z1) / 2),
			Vector3.new(b - a, SURFACE - LY + 14, Z1 - HARBOUR_Z0),
			Enum.Material.Water
		)
	end
end
claimGates(Z0, Z1)
for _, s in { -1, 1 } do
	-- the quay: stone, a timber edge to the harbour, bollards and lamps
	box(
		docks,
		"Quay",
		s * HALF,
		s * QUAY,
		LY - 14,
		LY + 0.6,
		Z0,
		Z1,
		QUAY_STONE,
		Enum.Material.Cobblestone
	)
	box(
		docks,
		"QuayEdge",
		s * (QUAY - 1),
		s * (QUAY + 0.4),
		LY - 14,
		LY + 0.9,
		HARBOUR_Z0,
		Z1,
		PLANK_DARK,
		Enum.Material.Wood
	)
	for z = HARBOUR_Z0 + 14, Z1 - 10, 26 do
		cylinder(
			docks,
			"Bollard",
			1.8,
			2.4,
			CFrame.new(s * (QUAY - 2.2), LY + 1.8, z),
			Color3.fromRGB(40, 42, 48),
			Enum.Material.Metal
		)
	end
	for z = HARBOUR_Z0 + 40, Z1 - 20, 64 do
		still(
			make(
				props,
				KIT.Prop_store_LampPost,
				1.4,
				facing(s),
				Vector3.new(s * (HALF + 3.6), LY + 0.6, z)
			),
			false
		)
	end
	table.insert(claims, rect(s * HALF, s * QUAY, Z0, Z1, "Quay"))
	-- the gate's plaza, stone, before the harbour
	pave(
		ground,
		s * QUAY,
		s * (P.TERRACE_OUT - P.BATTER),
		Z0,
		HARBOUR_Z0,
		P.TERRACE_Y + 0.4,
		QUAY_STONE,
		Enum.Material.Cobblestone,
		"GatePlaza"
	)
	box(
		docks,
		"PlazaEdge",
		s * QUAY,
		s * (P.TERRACE_OUT - P.BATTER),
		LY - 14,
		P.TERRACE_Y + 0.6,
		HARBOUR_Z0 - 1.2,
		HARBOUR_Z0,
		PLANK_DARK,
		Enum.Material.Wood
	)
	revetment(ground, s, Z0, Z1, STYLE)
end
-- a waterfall down each harbour wall
sheetFall(docks, 1, 1014, 14, SURFACE)
sheetFall(docks, -1, 1022, 14, SURFACE)
claim(rect(150, 168, 1004, 1024, "Waterfall"))
claim(rect(-168, -150, 1012, 1032, "Waterfall"))

-- ---------------------------------------------------------------------------------- +X: the pirates
local HX = (QUAY + P.TERRACE_OUT - P.BATTER) / 2 -- the harbour's middle line (137)
local function ship(template: Instance?, scale: number, x: number, z: number, sink: number): Model?
	if not template then
		return nil
	end
	return afloat(put(ships, template, scale, 0, x, z, { y = SURFACE - sink }))
end
-- the fish restaurant, afloat, a gangway from the quay
ship(SRC.FishRestaurant, 1.45, HX + 4, 980, 4)
deck(docks, QUAY, HX - 12, 974, 984, DECK, PLANK)
-- the working pier: the crane, crates and barrels
local function pier(side: number, z0: number, z1: number)
	deck(docks, side * QUAY, side * (P.TERRACE_OUT - P.BATTER), z0, z1, DECK, PLANK)
	table.insert(claims, rect(side * QUAY, side * (P.TERRACE_OUT - P.BATTER), z0, z1, "Pier"))
end
pier(1, 1032, 1050)
local function onPier(template: Instance?, scale: number, x: number, z: number, yaw: number)
	if template then
		still(make(props, template, scale, yaw, Vector3.new(x, DECK, z)), false)
	end
end
onPier(SRC.Crane, 1.1, 156, 1041, 180)
onPier(KIT:FindFirstChild("Prop_pirate_harbor_BarrelStack"), 1.4, 136, 1037, 25)
onPier(KIT.Prop_store_Crate, 1.6, 124, 1044, 10)
onPier(KIT.Prop_store_Barrel, 1.4, 114, 1038, 0)
-- the lion-headed ship, heading for the throw stage
ship(SRC.LionShip, 1.5, HX, 1092, 4)
-- the second pier: cannon, anchor, the open chest
pier(1, 1134, 1150)
onPier(KIT:FindFirstChild("Prop_pirate_harbor_Cannon"), 1.5, 116, 1142, 0)
onPier(KIT:FindFirstChild("Prop_pirate_harbor_GiantAnchor"), 1.5, 136, 1142, 90)
onPier(
	opt("Chest") or KIT:FindFirstChild("Prop_pirate_harbor_TreasurePile"),
	1.1,
	156,
	1142,
	facing(1)
)
-- the whale, at the far end
ship(opt("Whale2"), 1.0, HX, 1200, 6)
-- the shelf: the windmill, the beach bar, the straw hat, the wanted board, palms
local SHELF = P.REVET_OUT + 1.5
local function shelf(
	template: Instance?,
	side: number,
	scale: number,
	z: number,
	opts: any?
): Model?
	if not template then
		return nil
	end
	local m = front(props, template, side, scale, SHELF, z, opts)
	if m then
		still(m, true)
	end
	return m
end
shelf(SRC.Windmill, 1, 0.9, 978)
shelf(SRC.TikiBar, 1, 1.05, 1046)
local hat = shelf(SRC.StrawHat, 1, 1.15, 1098)
if hat then
	hat:PivotTo(hat:GetPivot() * CFrame.Angles(0, 0, math.rad(14))) -- tipped, as if dropped
	hat:SetAttribute("HangOk", 12)
end
shelf(opt("WantedBoard"), 1, 1.1, 1150)

-- ---------------------------------------------------------------------------------- -X: the navy and the port
ship(SRC.NavyShip, 1.45, -HX, 978, 4)
-- the town on a deck over the water, a promenade on its lane side
local T0, T1 = 1036, 1162
deck(docks, -QUAY, -(P.TERRACE_OUT - P.BATTER), T0, T1, DECK, PLANK)
table.insert(claims, rect(-QUAY, -(QUAY + 22), T0, T1, "Promenade"))
do
	local z = T0 + 4
	for _, b in
		{
			{ SRC.PortHouseB, 1.0 },
			{ SRC.Tavern, 0.8 },
			{ SRC.PortHouseA, 1.05 },
			{ SRC.PortHouseB, 0.95 },
			{ SRC.PortHouseA, 1.0 },
		}
	do
		local x0, x1 = turned(b[1], b[2], facing(-1))
		local _, _, zz0, zz1 = turned(b[1], b[2], facing(-1))
		local width = zz1 - zz0
		local depth = x1 - x0
		local m = put(
			town,
			b[1],
			b[2],
			facing(-1),
			-(P.TERRACE_OUT - P.BATTER - depth / 2 - 0.5),
			z + width / 2,
			{ y = DECK }
		)
		if m then
			still(m, true)
		end
		z += width + 3.5
	end
end
-- the market on the promenade
for _, s in
	{
		{ "Prop_pirate_harbor_FishStall", 1.3, 1058 },
		{ "Prop_store_ProduceTable", 1.0, 1098 },
		{ "Prop_store_Barrel", 1.4, 1076 },
		{ "Prop_store_Crate", 1.5, 1122 },
		{ "Prop_store_Barrel", 1.3, 1146 },
	}
do
	local t = KIT:FindFirstChild(s[1])
	if t then
		still(make(props, t, s[2], facing(-1), Vector3.new(-(QUAY + 11), DECK, s[3])), false)
	end
end
for _, z in { T0 + 10, T0 + 62, T1 - 10 } do
	still(
		make(props, KIT.Prop_store_LampPost, 1.4, facing(-1), Vector3.new(-(QUAY + 3), DECK, z)),
		false
	)
end
-- the little sheep-headed ship, rowboats, the sea king at the far end
ship(opt("SheepShip"), 1.0, -HX, 1186, 3)
for i, z in { 1170, 1206 } do
	local boat = put(ships, SRC.Rowboat, 1.8, 10 - i * 14, -(QUAY + 6), z, { y = SURFACE - 1.6 })
	afloat(boat)
end
ship(SRC.SeaKing, 1.15, -HX - 2, 1222, 2.5)
-- the shelf: the marine fortress, a battery of cannon, the lighthouse
shelf(SRC.MarineBase, -1, 0.75, 960)
for _, z in { 998, 1036, 1048 } do
	local t = KIT:FindFirstChild("Prop_pirate_harbor_Cannon")
	if t then
		put(props, t, 1.5, facing(-1), -192, z)
	end
end
shelf(KIT:FindFirstChild("Prop_pirate_harbor_Lighthouse"), -1, 1.15, 1214)

-- ---------------------------------------------------------------------------------- both sides
-- buoys between the quays and the ships
for _, b in { { 1, 1020 }, { 1, 1124 }, { 1, 1166 }, { -1, 1022 }, { -1, 1236 } } do
	if opt("Buoy") then
		afloat(put(ships, SRC.Buoy, 1.1, 0, b[1] * (QUAY + 5), b[2], { y = SURFACE - 2.2 }))
	end
end
-- palms and a few bushes on the shelves (owner: not too many trees)
local function palm(x: number, z: number, scale: number)
	local m = put(trees, SRC.Palm, scale, rng:NextInteger(0, 3) * 90, x, z, { soft = 4 * scale })
	if m then
		still(m, true)
	end
end
for _, t in
	{
		{ 192, 1012, 1.1 },
		{ 192, 1124, 1.0 },
		{ 192, 1190, 1.15 },
		{ 192, 1226, 1.0 },
		{ -192, 1080, 1.1 },
		{ -192, 1130, 1.0 },
		{ -192, 1170, 1.15 },
	}
do
	palm(t[1], t[2], t[3])
end
for _, b in { { 192, 1072 }, { -192, 1012 }, { -192, 1100 } } do
	local m =
		put(trees, JUNGLE.BushLeafy, 1.4, rng:NextInteger(0, 3) * 90, b[1], b[2], { soft = 1 })
	if m then
		still(m, false)
	end
end

-- ---------------------------------------------------------------------------------- the lane's floor
floorKit({
	id = ID,
	title = "GRAND LINE",
	accent = Color3.fromRGB(214, 48, 49),
	-- the sea: two blues, tile by tile, like swell
	strip = function(tile: number, _track: number)
		if tile % 2 == 0 then
			return Color3.fromRGB(46, 150, 214), Color3.fromRGB(120, 200, 244)
		end
		return Color3.fromRGB(84, 186, 232), Color3.fromRGB(170, 226, 250)
	end,
	kerb = Color3.fromRGB(242, 201, 76),
	paving = Color3.fromRGB(226, 206, 160),
	pavingTex = Color3.fromRGB(244, 232, 200),
})

markSlim(root, Z0, Z1)
return string.format("zone 3 Grand Line v2: %d parts\n%s", #partsOf(root), sideReport(root))
