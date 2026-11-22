-- LIB: side_lib
-- zone_06_black_clover.luau - zone 6, "Clover Kingdom" (Black Clover), on the slim lane (v2, 2026-11-22).
-- z 1960..2320 (config id still realm_of_legends), lane floor y -48, lane edges x +-100. Run with
--   python tools/studio/zones/run_zone.py build 6
-- then lane_border.luau. Safe to run again. v1 (zone_lib, the 320-wide lane): MapArchive.Zone6_v1_canyon
-- and tools/studio/retired/zone_06_black_clover_v1.luau.
--
-- A fantasy kingdom, grey hill stone with mossy caps.
--   +X, the royal capital on cobbles: the castle, tall town houses, the grimoire tower with the
--     fountain at its foot, a market in front of the houses, and the stone wizard king on his plinth
--     facing the throwers, a waterfall into a basin behind him
--   -X, the village by a dirt road on the green: the church, a farmhouse with its fenced garden and
--     hay cart, the crooked guild base, a cottage, and the colossal horned skull at the far end
--   grimoires hang in the air over both streets, clover banners and lamps along them, clover leaves
--   on the wind; on the shelves cottages, the wizard tower, a windmill and a few trees
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local map = workspace.Map
local KIT = RS.Assets.Kit
local SRC = SS.StoreAssets.Zone06_BlackClover
local JUNGLE = SS.StoreAssets.Zone01_Naruto
local ID = "realm_of_legends" -- the zone's id in config until the anime zone data lands
local LY, HALF, Z0, Z1 = P.LY, P.HALF, 1960, 2320
local rng = Random.new(6607)

local COBBLE = Color3.fromRGB(176, 170, 160)
local DIRT = Color3.fromRGB(150, 116, 82)
local WOOD = Color3.fromRGB(112, 78, 52)
local GREEN = Color3.fromRGB(44, 150, 80)
local GOLD = Color3.fromRGB(236, 196, 76)
local STONE = Color3.fromRGB(150, 150, 156)
local STONE_DARK = Color3.fromRGB(110, 110, 118)
local MOSS = Color3.fromRGB(86, 132, 72)
local GY = P.TERRACE_Y + 0.4

local function facing(side: number): number
	return if side > 0 then 90 else -90 -- a squared template fronts to -Z: turn it to the lane
end
local function building(
	parent: Instance,
	template: Instance,
	side: number,
	scale: number,
	ax: number,
	z: number,
	opts: any?
): Model?
	local m = front(parent, template, side, scale, ax, z, opts)
	if m then
		still(m, true)
	end
	return m
end
local function kit(name: string): Instance?
	local t = KIT:FindFirstChild(name)
	if not t then
		table.insert(refused, name .. " is not in the kit")
	end
	return t
end

-- ---------------------------------------------------------------------------------- the zone's folder
local scenery = map.Scenery
local archive = SS:FindFirstChild("MapArchive") or folder(SS, "MapArchive")
if not archive:FindFirstChild("Zone6_v1_canyon") then
	local keep = scenery["Zone_" .. ID]:Clone()
	keep.Name = "Zone6_v1_canyon"
	keep:SetAttribute(
		"Note",
		"Zone 6 (Clover Kingdom) v1 on the 320-wide lane, before the slim-lane rebuild (2026-11-22). Never delete."
	)
	keep.Parent = archive
end
local root = scenery["Zone_" .. ID]
root:ClearAllChildren()
root:SetAttribute(
	"Theme",
	"Clover Kingdom (Black Clover), zone_06_black_clover.luau v2 on side_lib"
)
local ground = folder(root, "Ground")
local town = folder(root, "Town")
local village = folder(root, "Village")
local props = folder(root, "Props")
local trees = folder(root, "Trees")
local books = folder(root, "Grimoires")

-- ---------------------------------------------------------------------------------- the ground
local STYLE = {
	stone = STONE,
	material = Enum.Material.Cobblestone,
	band = STONE_DARK,
	cap = MOSS,
	capMaterial = Enum.Material.Grass,
	rail = WOOD,
	buttress = 30,
}
if DO_TERRAIN then
	sideGround(Z0, Z1)
end
claimGates(Z0, Z1)
for _, s in { -1, 1 } do
	box(ground, "Kerb", s * HALF, s * P.KERB_OUT, LY - 2, LY + 3, Z0, Z1, GOLD, Enum.Material.Slate)
	revetment(ground, s, Z0, Z1, STYLE)
	table.insert(claims, rect(s * HALF, s * P.STREET_OUT, Z0, Z1, "Street"))
end
pave(
	ground,
	P.KERB_OUT,
	P.TERRACE_OUT - P.BATTER + 0.5,
	Z0,
	Z1,
	GY,
	COBBLE,
	Enum.Material.Cobblestone,
	"Cobbles"
)
pave(
	ground,
	-P.KERB_OUT,
	-(P.STREET_OUT + 2),
	Z0,
	Z1,
	GY - 0.1,
	DIRT,
	Enum.Material.Ground,
	"DirtRoad"
)

-- a clover banner on a pole, facing the lane
local function banner(side: number, ax: number, z: number)
	if not claim(rect(side * (ax - 1.5), side * (ax + 1.5), z - 1, z + 8, "Banner")) then
		return
	end
	cylinder(
		props,
		"BannerPole",
		0.9,
		22,
		CFrame.new(side * ax, GY + 11, z),
		WOOD,
		Enum.Material.Wood
	).CastShadow =
		false
	local cloth = block(
		props,
		"Banner",
		Vector3.new(0.4, 12, 6),
		CFrame.new(side * ax, GY + 15, z + 3.6),
		GREEN,
		Enum.Material.Fabric
	)
	cloth.CastShadow = false
	words(cloth, if side > 0 then Enum.NormalId.Left else Enum.NormalId.Right, "🍀", GOLD)
end

-- ================================================================================== +X: the royal capital
building(town, SRC.Castle, 1, 1.1, 129.5, 2050)
building(town, SRC.NobleHouse, 1, 1.25, 141.5, 2094)
building(town, SRC.GrimoireTower, 1, 1.0, 143.5, 2126)
building(town, SRC.NobleHouse, 1, 1.2, 142.5, 2158)
building(town, SRC.NobleHouse, 1, 1.1, 145, 2196)
-- the fountain at the foot of the grimoire tower
local fountain = put(props, SRC.Fountain, 1.15, 0, 129, 2126)
if fountain then
	still(fountain, true)
end
-- the market: stalls in front of the houses, their goods about them
for i, z in { 2094, 2158 } do
	building(props, SRC.MarketStall, 1, 1.25, P.STREET_OUT + 5, z)
	local goods = kit(if i == 1 then "Prop_store_Crate" else "Prop_store_Barrel")
	if goods then
		put(props, goods, 1.4, i * 37, 136, z - 9)
	end
end
-- the end plaza: the wizard king on a stepped plinth, facing the throw stage; the waterfall behind
do
	local px, pz = 142, 2246
	for i, r in { 18, 14.5 } do
		cylinder(
			town,
			"KingPlinth",
			r * 2,
			1.4,
			CFrame.new(px, GY + i * 1.3 - 0.6, pz),
			STONE,
			Enum.Material.Slate
		).CastShadow =
			false
	end
	claim(rect(px - 19, px + 19, pz - 19, pz + 19, "KingPlinth"))
	still(make(town, SRC.WizardKing, 1.3, 0, Vector3.new(px, GY + 2.6, pz)), true)
	banner(1, P.STREET_OUT + 3, pz - 26)
	banner(1, P.STREET_OUT + 3, pz + 20)
	sheetFall(ground, 1, 2292, 16, GY + 0.6)
	-- the waterfall's basin
	local b0, b1 = 2280, 2304
	box(
		ground,
		"BasinRim",
		P.TERRACE_OUT - P.BATTER - 14,
		P.TERRACE_OUT - P.BATTER,
		GY,
		GY + 2.2,
		b0,
		b1,
		STONE_DARK,
		Enum.Material.Slate
	)
	local water = box(
		ground,
		"BasinWater",
		P.TERRACE_OUT - P.BATTER - 12.8,
		P.TERRACE_OUT - P.BATTER,
		GY + 1,
		GY + 2,
		b0 + 1.2,
		b1 - 1.2,
		Color3.fromRGB(90, 170, 220),
		Enum.Material.Glass
	)
	water.Transparency = 0.3
	claim(rect(P.TERRACE_OUT - P.BATTER - 14, P.TERRACE_OUT - P.BATTER, b0, b1, "Basin"))
end

-- ================================================================================== -X: the village
building(village, SRC.Church, -1, 1.15, 136, 2034)
building(village, SRC.House, -1, 1.2, 142, 2076)
building(village, SRC.BullsBase, -1, 1.1, 139, 2126)
building(village, SRC.House, -1, 1.0, 146, 2186)
-- the church's path and lamp
pave(ground, -(P.STREET_OUT + 2), -136, 2028, 2040, GY, DIRT, Enum.Material.Ground, "ChurchPath")
local lampT = kit("Prop_store_LampPost")
-- the farmhouse's garden: fenced rows of crops, the hay cart, a barrel
do
	local g0, g1 = 2060, 2092
	local x0, x1 = -(P.STREET_OUT + 4), -140
	fence(props, x0, g0, x0, g1, GY, 3.2, WOOD, 7)
	fence(props, x0, g0, x1, g0, GY, 3.2, WOOD, 7)
	fence(props, x0, g1, x1, g1, GY, 3.2, WOOD, 7)
	for i = 0, 3 do
		local x = -(P.STREET_OUT + 10 + i * 3.6)
		box(
			ground,
			"Soil",
			x - 1.1,
			x + 1.1,
			GY,
			GY + 0.6,
			g0 + 14,
			g1 - 2,
			Color3.fromRGB(104, 76, 54),
			Enum.Material.Ground
		).CastShadow =
			false
		for cz = g0 + 15.5, g1 - 3, 3.4 do
			block(
				ground,
				"Crop",
				Vector3.new(1.6, 1.6, 1.6),
				CFrame.new(x, GY + 1.3, cz) * CFrame.Angles(0, math.rad(45), 0),
				if i % 2 == 0 then Color3.fromRGB(96, 190, 84) else Color3.fromRGB(236, 150, 60),
				Enum.Material.Grass
			).CastShadow =
				false
		end
	end
	claim(rect(x0, x1, g0, g1, "Garden"))
	still(make(props, SRC.HayCart, 1.4, 20, Vector3.new(-(P.STREET_OUT + 18), GY, g0 + 7)), false)
end
-- the guild base's yard: the great grimoire, barrels and crates
local grim = put(props, SRC.Grimoire, 0.6, facing(-1), -(P.STREET_OUT + 12), 2116)
if grim then
	still(grim, true)
end
local stack = kit("Prop_pirate_harbor_BarrelStack")
if stack then
	put(props, stack, 1.3, 30, -(P.STREET_OUT + 12), 2140)
end
-- the colossal skull at the far end, facing the throw stage
local skull = building(village, SRC.DemonSkull, -1, 1.2, 124, 2252, { y = GY - 1.2 })
if skull then
	skull:SetAttribute("SunkOk", 4)
end

-- ================================================================================== both streets
for _, s in { -1, 1 } do
	for z = 2026, Z1 - 20, 48 do
		if lampT then
			put(props, lampT, 1.5, facing(s), s * (P.STREET_OUT + 1.5), z)
		end
		banner(s, P.STREET_OUT + 1.5, z + 22)
	end
	-- grimoires hanging in the air over the street (above everything: no claim)
	for i = 1, 5 do
		local bz = 2030 + (i - 1) * 56 + s * 9
		local book = make(
			books,
			SRC.FloatingBook,
			1.2,
			rng:NextInteger(0, 359),
			Vector3.new(s * rng:NextNumber(110, 122), GY + 22 + (i * 7) % 14, bz)
		)
		book:PivotTo(
			book:GetPivot()
				* CFrame.Angles(
					math.rad(rng:NextNumber(-22, 22)),
					0,
					math.rad(rng:NextNumber(-22, 22))
				)
		)
		book:SetAttribute("LaneOk", true)
		still(book, false)
	end
end

-- ================================================================================== the shelves
local SHELF = P.REVET_OUT + 1.5
local function tree(x: number, z: number, scale: number)
	local t = put(
		trees,
		if rng:NextNumber() < 0.5 then JUNGLE.TreeBroad else JUNGLE.TreeTall,
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
building(village, SRC.WizardTower, 1, 0.85, SHELF + 2, 2050)
building(village, SRC.House, 1, 0.85, SHELF + 2, 2110)
building(village, SRC.House, 1, 0.85, SHELF + 2, 2206)
tree(192, 2160, 0.95)
tree(192, 2256, 1.0)
building(village, SS.StoreAssets.Zone03_OnePiece.Windmill, -1, 0.8, SHELF + 3, 2062)
building(village, SRC.House, -1, 0.85, SHELF + 2, 2140)
building(village, SRC.House, -1, 0.85, SHELF + 2, 2230)
tree(-192, 2100, 0.95)
tree(-192, 2186, 1.0)
tree(-192, 2290, 0.95)
for _, b in { { 192, 2080 }, { 192, 2296 }, { -192, 2016 } } do
	local m =
		put(trees, JUNGLE.BushLeafy, 1.4, rng:NextInteger(0, 3) * 90, b[1], b[2], { soft = 1 })
	if m then
		still(m, false)
	end
end

-- clover leaves on the wind
local fx = folder(root, "Fx")
for _, z in { 2030, 2120, 2210, 2290 } do
	local source = block(
		fx,
		"CloverSource",
		Vector3.new(2 * HALF - 8, 1, 70),
		CFrame.new(0, LY + 84, z),
		Color3.new(1, 1, 1)
	)
	source.Transparency = 1
	source.CastShadow = false
	local e = Instance.new("ParticleEmitter")
	e.Name = "Clovers"
	e.Texture = "rbxassetid://5057182105"
	e.Color = ColorSequence.new(Color3.fromRGB(120, 220, 120), Color3.fromRGB(60, 170, 90))
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
	e.LightEmission = 0.5
	e.Parent = source
end

-- ---------------------------------------------------------------------------------- the lane's floor
floorKit({
	id = ID,
	title = "CLOVER KINGDOM",
	accent = Color3.fromRGB(52, 168, 84),
	strip = function(tile: number, track: number)
		if (tile + track) % 2 == 0 then
			return Color3.fromRGB(44, 46, 54), Color3.fromRGB(92, 96, 110)
		end
		return Color3.fromRGB(46, 150, 82), Color3.fromRGB(120, 210, 150)
	end,
	kerb = Color3.fromRGB(232, 190, 70),
	paving = Color3.fromRGB(196, 190, 176),
	pavingTex = Color3.fromRGB(228, 222, 208),
})

markSlim(root, Z0, Z1)
return string.format("zone 6 Clover Kingdom v2: %d parts\n%s", #partsOf(root), sideReport(root))
