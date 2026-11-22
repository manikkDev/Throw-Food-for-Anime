-- RETIRED 2026-11-22: zone 11 on the old 320-wide lane (zone_lib). Kept for its content and numbers;
-- zones/zone_11_jojo.luau (side_lib) builds the zone now.
-- zone_11_jojo.luau - zone 11, "Bizarre Streets" (JoJo's Bizarre Adventure), z 3760..4120. Map id
-- bizarre_streets (no zone data yet). Run: python tools/studio/zones/run_zone.py build 11 [--no-terrain]
-- (rebuilt 2026-11-22: the first version was six copies of one townhouse, a clock tower, a roller
-- and an arrow on bare cobbles, with its katakana hanging inside the houses.)
--
-- The picture: a sunlit Italian town under warm cliffs.
--   +X (left from the throw stage): a palazzo, the baroque church with a fountain in its piazza, a
--     cafe, a townhouse, and the golden arrow on its plinth facing the throwers.
--   -X: the pizzeria, townhouses, the clock tower, a palazzo, the yellow road roller parked askew,
--     and the fanged stone mask at the far end.
--   Scooters at the kerb, ladybug columns, lamps; the menacing katakana hang in the air over both
--   ledges; palms and a palazzo on each rim.
-- Templates: StoreAssets.Zone11_JoJo (all generate_mesh, squared, fronting -Z).
local G = Enum.Material.LeafyGrass
local root = begin({
	n = 11,
	id = "bizarre_streets",
	title = "Bizarre Streets (JoJo's Bizarre Adventure)",
	src = "Zone11_JoJo",
	now = {
		face = { [-1] = 236, [1] = 236 },
		rise = { [-1] = 6, [1] = 6 },
		ledgeW = { [-1] = 26, [1] = 26 },
		ledgeY = { [-1] = 10, [1] = 10 },
		top = { [-1] = 62, [1] = 62 },
	},
	prev = { -- zone 10's Tokyo street
		face = { [-1] = 236, [1] = 236 },
		rise = { [-1] = 6, [1] = 6 },
		ledgeW = { [-1] = 26, [1] = 26 },
		ledgeY = { [-1] = 8, [1] = 8 },
		top = { [-1] = 62, [1] = 62 },
	},
	-- zone 3's warm rock, alone: two banded materials come out as blotches
	mats = {
		rock = Enum.Material.Sandstone,
		prevRock = Enum.Material.Basalt,
		terrace = Enum.Material.Cobblestone,
		prevTerrace = Enum.Material.Pavement,
		ledge = G,
		top = G,
	},
	wobble = 0.3,
})
local town = folder(root, "Town")
local groundF = folder(root, "Ground")
local props = folder(root, "Props")
local trees = folder(root, "Trees")
local JUNGLE = STORE.Zone01_Naruto
local PALM = STORE.Zone03_OnePiece.Palm

local COBBLE = Color3.fromRGB(214, 196, 170)
local CREAM = Color3.fromRGB(240, 228, 204)
local STONE = Color3.fromRGB(190, 180, 164)
local MENACE = Color3.fromRGB(150, 70, 210)
local GOLD = Color3.fromRGB(240, 198, 62)
local S0, S1 = Z0 + 82, Z1 + 10 -- the terrace clear of both gates' pillars
local GY = TERRACE + 0.35 -- the top of the paving

local function plinth(x: number, z: number, radius: number, rim: Color3)
	local p = cylinder(
		town,
		"Plinth",
		radius * 2,
		3,
		CFrame.new(x, GY + 1.5, z),
		STONE,
		Enum.Material.Marble
	)
	p.CastShadow = false
	cylinder(town, "PlinthRim", radius * 2 + 1.2, 0.5, CFrame.new(x, GY + 3.1, z), rim)
	reserve(x, z, radius, radius, LY, GY + 4, "a plinth")
end

-- ================================================================================== +X: the piazza
do
	local side = 1
	pave(groundF, side, 163.5, 240, S0 - 4, S1 + 2, COBBLE, Enum.Material.Cobblestone)
	local z = S0 + 2
	local palazzoZ0 = z
	z = row({ parent = town, side = side, z = z, gap = 4, list = { { SRC.Palazzo, 1.9 } } })
	local churchZ0 = z
	z = row({ parent = town, side = side, z = z, gap = 4, list = { { SRC.Church, 2.0 } } })
	local churchZ1 = z - 4
	local cafeZ0 = z
	z = row({
		parent = town,
		side = side,
		z = z,
		gap = 4,
		list = { { SRC.Cafe, 2.1 }, { SRC.Townhouse, 1.6 } },
	})
	local rowEnd = z - 4
	-- the church's piazza: a pale round of paving, the fountain in its middle
	do
		local mid = (churchZ0 + churchZ1) / 2
		local round = cylinder(
			groundF,
			"Piazza",
			46,
			0.3,
			CFrame.new(184, GY + 0.15, mid),
			CREAM,
			Enum.Material.Marble
		)
		round.CastShadow = false
		place(props, SRC.Fountain, 1.5, 0, Vector3.new(184, GY + 0.2, mid))
		for _, dz in { -26, 26 } do
			try(
				props,
				KIT.Prop_sakura_schoolyard_Bench,
				1.5,
				facing(side),
				Vector3.new(199, GY, mid + dz)
			)
		end
	end
	-- a ladybug column, scooters and lamps down the street
	try(props, SRC.Ladybug, 1.2, facing(side), Vector3.new(172, GY, palazzoZ0 + 8))
	for i, sz in { palazzoZ0 + 26, palazzoZ0 + 34, cafeZ0 + 4, cafeZ0 + 70 } do
		try(props, SRC.Scooter, 1.6, 20 + i * 15, Vector3.new(168 + (i % 2) * 2, GY, sz))
	end
	for lz = S0 + 12, rowEnd, 46 do
		try(props, KIT.Prop_store_LampPost, 1.6, facing(side), Vector3.new(166.6, GY, lz))
	end
	-- the golden arrow on its plinth, facing the throw stage
	local az = (rowEnd + 4 + S1) / 2
	plinth(200, az, 17, GOLD)
	place(town, SRC.Arrow, 2.3, 0, Vector3.new(200, GY + 3.2, az), { over = true })
end

-- ================================================================================== -X: the street
do
	local side = -1
	pave(groundF, side, 163.5, 240, S0 - 4, S1 + 2, COBBLE, Enum.Material.Cobblestone)
	local z = S0 + 2
	local pizzaZ0 = z
	z = row({
		parent = town,
		side = side,
		z = z,
		gap = 4,
		list = { { SRC.Pizzeria, 2.3 }, { SRC.Townhouse, 2.0 } },
	})
	local clockZ0 = z
	z = row({ parent = town, side = side, z = z, gap = 4, list = { { SRC.ClockTower, 1.5 } } })
	local palazzoZ0 = z
	z = row({
		parent = town,
		side = side,
		z = z,
		gap = 4,
		list = { { SRC.Palazzo, 1.8 }, { SRC.Townhouse, 1.8 } },
	})
	local rowEnd = z - 4
	-- the road roller, parked askew before the clock tower
	place(props, SRC.RoadRoller, 1.7, 150, Vector3.new(-182, GY, clockZ0 + 10))
	try(props, SRC.Ladybug, 1.2, facing(side), Vector3.new(-172, GY, palazzoZ0 + 8))
	for i, sz in { pizzaZ0 + 6, pizzaZ0 + 50, pizzaZ0 + 58, palazzoZ0 + 30, palazzoZ0 + 74 } do
		try(props, SRC.Scooter, 1.6, 200 - i * 15, Vector3.new(-(168 + (i % 2) * 2), GY, sz))
	end
	for lz = S0 + 30, rowEnd, 46 do
		try(props, KIT.Prop_store_LampPost, 1.6, facing(side), Vector3.new(-166.6, GY, lz))
	end
	-- the stone mask on its plinth, facing the throw stage
	local mz = (rowEnd + 4 + S1) / 2
	plinth(-200, mz, 21, MENACE)
	place(town, SRC.StoneMask, 2.3, 0, Vector3.new(-200, GY + 3.2, mz), { over = true })
end

-- ================================================================================== ledges and rims
for _, side in { -1, 1 } do
	-- the menace: katakana "go" hanging in the air over the ledge, read from the lane
	for i = 0, 5 do
		local size = 22 + (i % 3) * 8
		local sz = Z0 + 60 + i * 52 + side * 10
		local ax = ledgeAx(side) + (i % 2) * 8
		local board = block(
			props,
			"Menace",
			Vector3.new(0.4, size, size),
			CFrame.new(side * ax, ground(side, ax, sz) + 20 + (i % 3) * 9, sz)
				* CFrame.Angles(math.rad((i % 2) * 14 - 7), 0, 0),
			MENACE
		)
		board.Transparency = 1
		board.CastShadow = false
		words(
			board,
			if side > 0 then Enum.NormalId.Left else Enum.NormalId.Right,
			"ゴ",
			MENACE,
			Enum.Font.SourceSansBold
		)
	end
	-- a palazzo on the rim, over the middle of the street
	do
		local ax = rimAx(side) + 26
		local pz = Z0 + 200 + side * 40
		local b = place(
			town,
			SRC.Palazzo,
			1.5,
			facing(side),
			Vector3.new(side * ax, ground(side, ax, pz) + 3, pz)
		)
		footing(town, b, STONE, Enum.Material.Cobblestone, 18, 1.04)
	end
	-- trees: small ones and bushes on the ledge, palms and broadleaf on the rim
	for tz = Z0 + 40, Z1 - 8, 32 do
		plant(
			trees,
			if rng:NextNumber() < 0.5 then PALM else JUNGLE.TreeBroad,
			side,
			ledgeAx(side) + rng:NextNumber(-7, 7),
			tz + rng:NextNumber(-6, 6),
			rng:NextNumber(0.8, 1.1)
		)
	end
	scatter({
		parent = trees,
		templates = { JUNGLE.BushLeafy },
		count = 9,
		side = side,
		ax = { ledgeAx(side) - 10, ledgeAx(side) + 9 },
		z = { Z0 + 30, Z1 },
		scale = { 1.2, 1.8 },
		sink = 0.6,
		soft = true,
	})
	for tz = Z0 + 20, Z1 - 6, 24 do
		plant(
			trees,
			if rng:NextNumber() < 0.45 then PALM else JUNGLE.TreeBroad,
			side,
			rimAx(side) + rng:NextNumber(-6, 10),
			tz + rng:NextNumber(-7, 7),
			rng:NextNumber(1.4, 1.9)
		)
	end
end

floor({
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
return finish()
