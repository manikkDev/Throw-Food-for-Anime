-- RETIRED 2026-11-22: zone 17 on the old 320-wide lane (zone_lib). Kept for its content and numbers;
-- zones/zone_17_dragon_ball.luau (side_lib) builds the zone now.
-- zone_17_dragon_ball.luau - zone 17, "Planet of the Gods" (Dragon Ball), z 5920..6280: the lane's
-- last zone. Map id planet_of_gods (no zone data yet). Run: python tools/studio/zones/run_zone.py build 17 [--no-terrain]
-- (rebuilt 2026-11-22: the first version was five models standing in open water.)
--
-- The picture: a warm sea under orange cliffs, and islands in it. Real water either side of the lane.
--   +X (left from the throw stage): the little pink house on its island, the tournament arena on a
--     big island with a bridge from the quay, the lookout tower rising from the sea, and the seven
--     star balls on their altar facing the throwers.
--   -X: the yellow dome corporation on its island with capsule cars and a bridge, the dragon coiling
--     up out of the water, the space pod in its crater, and the stone fighter at the far end.
--   Dome houses and palms on the beaches; mesas and the god's temple on the rims; little golden
--   clouds in the air; a waterfall each side. The walls come down at the far end: nothing is built
--   beyond it.
-- Templates: StoreAssets.Zone17_DragonBall (all generate_mesh, squared, fronting -Z); palms, buoys
-- and boats are zone 3's.
local G = Enum.Material.LeafyGrass
local SAND = Enum.Material.Sand
local root = begin({
	n = 17,
	id = "planet_of_gods",
	title = "Planet of the Gods (Dragon Ball)",
	src = "Zone17_DragonBall",
	now = {
		face = { [-1] = 244, [1] = 244 },
		rise = { [-1] = 8, [1] = 8 },
		ledgeW = { [-1] = 30, [1] = 30 },
		ledgeY = { [-1] = -40, [1] = -40 }, -- a beach just above the water
		top = { [-1] = 58, [1] = 58 },
	},
	prev = { -- zone 16's city
		face = { [-1] = 236, [1] = 236 },
		rise = { [-1] = 6, [1] = 6 },
		ledgeW = { [-1] = 26, [1] = 26 },
		ledgeY = { [-1] = 8, [1] = 8 },
		top = { [-1] = 62, [1] = 62 },
	},
	-- zone 3's warm rock, alone (two banded materials come out as blotches)
	mats = {
		rock = Enum.Material.Sandstone,
		prevRock = Enum.Material.Concrete,
		terrace = SAND,
		prevTerrace = Enum.Material.Pavement,
		ledge = SAND,
		top = G,
	},
	sea = true,
	fall = true,
	wobble = 0.35,
})
local sights = folder(root, "Sights")
local docks = folder(root, "Docks")
local props = folder(root, "Props")
local trees = folder(root, "Trees")
local sky = folder(root, "Sky")
local Z3 = STORE.Zone03_OnePiece
local PALM = Z3.Palm
local JUNGLE = STORE.Zone01_Naruto

local SURFACE, DECK, FOOT = LY - 1.5, LY - 0.4, LY - 9
local SEA0, SEA1 = Z0 + 24, Z1 - 12
local SANDC = Color3.fromRGB(240, 216, 160)
local WET = Color3.fromRGB(214, 190, 138)
local STONE = Color3.fromRGB(226, 214, 190)
local BEACH0 = NOW.face[1] + NOW.rise[1] + 2 -- the sand starts here...
local BEACH1 = BEACH0 + NOW.ledgeW[1] - 5 -- ...and the cliff takes over here
local TOP = SURFACE + 1.5 -- an island's top

-- a round island: a wet shore just over the water, dry sand above it. Returns its top's height.
local function island(x: number, z: number, radius: number): number
	local shore = cylinder(
		docks,
		"IslandShore",
		(radius + 3) * 2,
		6,
		CFrame.new(x, SURFACE - 2.6, z),
		WET,
		SAND
	)
	shore.CastShadow = false
	local top = cylinder(docks, "Island", radius * 2, 7, CFrame.new(x, TOP - 3.5, z), SANDC, SAND)
	top.CastShadow = false
	return TOP
end

-- the waterfalls, first, so nothing is planted in their course
waterfall(docks, 1, Z0 + 283, 18)
waterfall(docks, -1, Z0 + 166, 18)

-- a stone quay either side: the lane's edge against the water; lamps on it
for _, side in { -1, 1 } do
	block(
		docks,
		"Quay",
		Vector3.new(3.2, 5, SEA1 - SEA0),
		CFrame.new(side * 161.6, LY - 2.1, (SEA0 + SEA1) / 2),
		STONE,
		Enum.Material.Slate
	)
	for lz = Z0 + 100, Z1 - 30, 56 do
		local lamp = make(
			props,
			KIT.Prop_store_LampPost,
			1.5,
			facing(side),
			Vector3.new(side * 161.4, LY + 0.4, lz)
		)
		lamp:SetAttribute("AuditSkip", true) -- on the quay's top, clear of everything by position
	end
end

-- ================================================================================== +X
do
	-- the pink house: its mesh is its own island
	afloat(
		place(sights, SRC.IslandHouse, 2.0, facing(1), Vector3.new(202, SURFACE - 1.5, Z0 + 112))
	)
	-- the tournament arena on the big island, a bridge to it from the quay
	local az = Z0 + 182
	island(204, az, 34)
	deck(docks, 1, 163, 172, az - 5, az + 5, DECK, FOOT, { step = 30 })
	place(sights, SRC.Arena, 1.7, facing(1), Vector3.new(206, TOP - 0.3, az))
	for _, d in { -24, 24 } do
		try(trees, PALM, 1.0, 0, Vector3.new(180, TOP - 0.8, az + d), { fit = 0.4 })
	end
	-- the lookout, rising from its islet
	local lz = Z0 + 248
	island(206, lz, 20)
	place(sights, SRC.Lookout, 1.5, 0, Vector3.new(206, TOP - 0.3, lz))
	-- the seven star balls on their altar, facing the throw stage
	local sz = Z0 + 318
	island(200, sz, 22)
	place(sights, SRC.StarBalls, 3.0, 0, Vector3.new(200, TOP - 0.2, sz))
end

-- ================================================================================== -X
do
	-- the dome corporation on its island, capsule cars before it, a bridge from the quay
	local cz = Z0 + 122
	island(-204, cz, 36)
	deck(docks, -1, 163, 170, cz - 5, cz + 5, DECK, FOOT, { step = 30 })
	place(sights, SRC.Corporation, 1.8, facing(-1), Vector3.new(-210, TOP - 0.3, cz))
	try(props, SRC.CapsuleCar, 1.3, 20, Vector3.new(-176, TOP, cz - 16))
	try(props, SRC.CapsuleCar, 1.3, 160, Vector3.new(-176, TOP, cz + 16))
	-- the dragon, coiling up out of the water
	afloat(place(sights, SRC.Dragon, 1.9, facing(-1), Vector3.new(-200, SURFACE - 3, Z0 + 208)))
	-- the space pod in its crater on an islet
	local pz = Z0 + 264
	island(-200, pz, 22)
	place(sights, SRC.SpacePod, 1.6, 40, Vector3.new(-200, TOP - 0.4, pz))
	-- the stone fighter, facing the throw stage
	local fz = Z0 + 320
	island(-200, fz, 24)
	place(sights, SRC.Fighter, 1.9, 0, Vector3.new(-200, TOP - 0.2, fz))
end

-- ================================================================================== both sides
for _, side in { -1, 1 } do
	-- buoys and a boat or two in the open water
	for bz = Z0 + 96, Z1 - 24, 60 do
		local b = try(docks, Z3.Buoy, 1.2, 0, Vector3.new(side * 168, SURFACE - 2.4, bz))
		if b then
			afloat(b)
		end
	end
	-- dome houses on the beach, each on a stone footing
	for _, hz in
		if side > 0 then { Z0 + 112, Z0 + 196, Z0 + 330 } else { Z0 + 110, Z0 + 236, Z0 + 316 }
	do
		local ax = BEACH0 + 13
		local house = place(
			sights,
			SRC.DomeHouse,
			0.85,
			facing(side),
			Vector3.new(side * ax, ground(side, ax, hz) + 1.2, hz)
		)
		footing(sights, house, STONE, Enum.Material.Slate, 8, 1.04)
	end
	-- the rims: mesas, and on -X the god's temple
	local mesas = if side > 0 then { Z0 + 110, Z0 + 216, Z0 + 330 } else { Z0 + 96, Z0 + 320 }
	for i, mz in mesas do
		local ax = rimAx(side) + 20 + (i % 2) * 10
		local m = place(
			sights,
			SRC.Mesa,
			2.4,
			i * 70,
			Vector3.new(side * ax, ground(side, ax, mz) - 20, mz)
		)
		m:SetAttribute("SunkOk", 48) -- rock standing in the hillside
		m:SetAttribute("HangOk", 14)
	end
	if side < 0 then
		local ax = rimAx(side) + 26
		local tz = Z0 + 212
		local temple = place(
			sights,
			SRC.GodTemple,
			1.6,
			facing(side),
			Vector3.new(side * ax, ground(side, ax, tz) + 3, tz)
		)
		footing(sights, temple, Color3.fromRGB(150, 110, 190), Enum.Material.Slate, 20, 1.04)
	end
	-- palms and bushes on the beaches, palms and broadleaf on the rims: never through anything
	scatter({
		parent = trees,
		templates = { PALM },
		count = 10,
		side = side,
		ax = { BEACH0 + 2, BEACH1 },
		z = { Z0 + 92, Z1 - 20 },
		scale = { 1.0, 1.5 },
		sink = 0.8,
		fit = 0.5,
		soft = true,
	})
	scatter({
		parent = trees,
		templates = { JUNGLE.BushLeafy },
		count = 7,
		side = side,
		ax = { BEACH0 + 8, BEACH1 - 2 },
		z = { Z0 + 92, Z1 - 20 },
		scale = { 1.2, 1.8 },
		sink = 0.6,
		soft = true,
	})
	for tz = Z0 + 24, Z1 - 26, 24 do
		plant(
			trees,
			if rng:NextNumber() < 0.5 then PALM else JUNGLE.TreeBroad,
			side,
			rimAx(side) + rng:NextNumber(-6, 8),
			tz + rng:NextNumber(-7, 7),
			rng:NextNumber(1.4, 1.9)
		)
	end
	-- little golden clouds in the air
	for i = 1, 5 do
		local c = make(
			sky,
			SRC.Cloud,
			3.2,
			rng:NextInteger(0, 359),
			Vector3.new(
				side * rng:NextNumber(170, 230),
				TERRACE + 34 + (i * 11) % 30,
				Z0 + 70 + i * 52 + side * 10
			)
		)
		c:SetAttribute("AuditSkip", true) -- in the air by design
	end
end

floor({
	title = "PLANET OF THE GODS",
	accent = Color3.fromRGB(40, 110, 230),
	strip = function(tile: number, track: number)
		if (tile + track) % 2 == 0 then
			return Color3.fromRGB(244, 122, 32), Color3.fromRGB(252, 178, 104)
		end
		return Color3.fromRGB(250, 196, 64), Color3.fromRGB(255, 228, 150)
	end,
	kerb = Color3.fromRGB(40, 110, 230),
	paving = Color3.fromRGB(226, 214, 190),
	pavingTex = Color3.fromRGB(244, 236, 218),
})
return finish()
