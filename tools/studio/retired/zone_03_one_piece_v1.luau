-- RETIRED 2026-11-22: zone 3 on the old 320-wide lane (zone_lib). Kept for its content and numbers;
-- zones/zone_03_one_piece.luau (side_lib) builds the zone now.
-- zone_03_one_piece.luau - zone 3, "Grand Line" (One Piece), z 880..1240. Config id still
-- ninja_village. Run: python tools/studio/zones/run_zone.py build 3 [--no-terrain]
-- (rewritten on zone_lib.luau, 2026-11-22: the first version stood alone and was thin: one ship a
-- side in empty water, props set inside a gate pillar and through the trees.)
--
-- The picture: a tropical cove. The lane is the sea (blue wave tiles, straw-yellow kerbs, a quay
-- either side) and between the quays and the cliffs lies real water, full of harbour.
--   +X (left from the throw stage), the pirates: the floating fish restaurant, a working pier with
--     its crane, the lion-headed ship, a second pier with cannon and treasure, a whale at the far
--     end; a boardwalk under the cliff, a beach bar and a wanted board on the sand; a windmill and
--     the giant straw hat on the rim.
--   -X, the navy and the port: the warship under the marine fortress on the rim, then a town on
--     stilts (shops, the tavern, market stalls), the little sheep-headed ship and rowboats at its
--     quay, a sea serpent at the far end, the lighthouse on the rim.
-- Templates: StoreAssets.Zone03_OnePiece (all generate_mesh, squared, fronting -Z): LionShip,
-- NavyShip, Tavern, Palm, StrawHat, FishRestaurant, MarineBase, PortHouseA, PortHouseB, Windmill,
-- SeaKing, Rowboat, Crane, TikiBar, and when they exist Whale2, SheepShip, Chest, WantedBoard, Buoy.
local G = Enum.Material.LeafyGrass
local SAND = Enum.Material.Sand
local root = begin({
	n = 3,
	id = "ninja_village",
	title = "Grand Line (One Piece)",
	src = "Zone03_OnePiece",
	now = {
		face = { [-1] = 240, [1] = 240 },
		rise = { [-1] = 8, [1] = 8 },
		ledgeW = { [-1] = 26, [1] = 26 }, -- the beach
		ledgeY = { [-1] = LY + 6, [1] = LY + 6 }, -- just over the water
		top = { [-1] = 62, [1] = 58 },
	},
	prev = { -- zone 2's valley
		face = { [-1] = 236, [1] = 234 },
		rise = { [-1] = 6, [1] = 6 },
		ledgeW = { [-1] = 26, [1] = 30 },
		ledgeY = { [-1] = 6, [1] = 12 },
		top = { [-1] = 68, [1] = 60 },
	},
	-- one warm rock, darker than the sand: two banded materials came out as blotches on the face
	mats = {
		rock = Enum.Material.Sandstone,
		prevRock = Enum.Material.Basalt,
		terrace = SAND,
		prevTerrace = SAND,
		ledge = SAND,
		top = G,
	},
	colors = {
		[Enum.Material.Sandstone] = Color3.fromRGB(202, 152, 102),
		[Enum.Material.Limestone] = Color3.fromRGB(240, 218, 176),
	},
	sea = true,
	seaEnd = 4, -- the water runs almost to zone 4's start: the whale needs it
	wobble = 0.35, -- the piers and the town's deck run to the cliff's foot: keep it near straight
})
local ships = folder(root, "Ships")
local docks = folder(root, "Docks")
local town = folder(root, "Town")
local props = folder(root, "Props")
local trees = folder(root, "Trees")
local JUNGLE = STORE.Zone01_Naruto

local SURFACE, DECK, FOOT, DRAFT = LY - 1.5, LY - 0.4, LY - 9, 6
local SEA0, SEA1 = Z0 + 24, Z1 - 4
local PLANK_DARK = Color3.fromRGB(92, 62, 44)
local STONE = Color3.fromRGB(214, 198, 168)
local function opt(name: string): Instance?
	return SRC:FindFirstChild(name)
end
local function beachY(side: number, ax: number, z: number): number
	return ground(side, ax, z) - 0.4
end
local BEACH0 = NOW.face[1] + NOW.rise[1] + 2 -- the sand starts here...
local BEACH1 = BEACH0 + NOW.ledgeW[1] - 5 -- ...and the cliff takes over here

-- ---------------------------------------------------------------------------------- the quays
for _, side in { -1, 1 } do
	block(
		docks,
		"Quay",
		Vector3.new(3.2, 5, SEA1 - SEA0),
		CFrame.new(side * 161.6, LY - 2.1, (SEA0 + SEA1) / 2),
		PLANK_DARK,
		Enum.Material.Wood
	)
	for z = SEA0 + 12, SEA1 - 12, 36 do
		local p = block(
			docks,
			"QuayPost",
			Vector3.new(12, 2.4, 2.4),
			CFrame.new(side * 163.6, LY - 3, z) * CFrame.Angles(0, 0, math.rad(90)),
			PLANK_DARK,
			Enum.Material.Wood
		)
		p.Shape = Enum.PartType.Cylinder
	end
end

-- ---------------------------------------------------------------------------------- the waterfalls
-- one each side, first, so that nothing is planted in their course
waterfall(docks, 1, Z0 + 192, 22)
waterfall(docks, -1, Z0 + 98, 22)

-- ---------------------------------------------------------------------------------- +X: the pirates
-- the fish restaurant, afloat, with a gangway from the quay
afloat(place(ships, SRC.FishRestaurant, 2.3, 0, Vector3.new(201, SURFACE - 5, Z0 + 123)))
deck(docks, 1, 163, 175, Z0 + 117, Z0 + 129, DECK, FOOT, { step = 30 })
-- the working pier: the crane, crates and barrels
deck(docks, 1, 163, 244, Z0 + 165, Z0 + 186, DECK, FOOT, nil, { z0 = true })
place(props, SRC.Crane, 1.3, 180, Vector3.new(186, DECK, Z0 + 176))
place(props, KIT.Prop_pirate_harbor_BarrelStack, 1.5, 25, Vector3.new(206, DECK, Z0 + 172))
place(props, KIT.Prop_store_Crate, 1.8, 10, Vector3.new(216, DECK, Z0 + 180))
place(props, KIT.Prop_store_Crate, 1.4, 40, Vector3.new(222, DECK, Z0 + 172))
place(props, KIT.Prop_store_Barrel, 1.6, 0, Vector3.new(170, DECK, Z0 + 181))
-- the lion-headed ship, heading for the throw stage
afloat(place(ships, SRC.LionShip, 2.3, 0, Vector3.new(201, SURFACE - DRAFT, Z0 + 246)))
-- the second pier: cannon, anchor, the open chest
deck(docks, 1, 163, 244, Z0 + 303, Z0 + 320, DECK, FOOT, nil, { z1 = true })
place(props, KIT.Prop_pirate_harbor_Cannon, 1.7, 0, Vector3.new(172, DECK, Z0 + 311.5))
place(props, KIT.Prop_pirate_harbor_GiantAnchor, 1.8, 90, Vector3.new(192, DECK, Z0 + 312))
if opt("Chest") then
	place(props, SRC.Chest, 1.3, facing(1), Vector3.new(222, DECK, Z0 + 311.5))
else
	place(props, KIT.Prop_pirate_harbor_TreasurePile, 1.6, 30, Vector3.new(222, DECK, Z0 + 315))
end
-- the boardwalk under the cliff, from pier to pier, behind the ship
deck(docks, 1, 232, 242, Z0 + 186, Z0 + 303, DECK, FOOT, nil, { lane = true })
for i, z in { Z0 + 204, Z0 + 246, Z0 + 288 } do
	try(
		props,
		KIT[if i == 2 then "Prop_pirate_harbor_BarrelStack" else "Prop_store_Barrel"],
		1.4,
		i * 40,
		Vector3.new(237.5, DECK, z)
	)
end
-- steps from the boardwalk up to the beach
steps(
	docks,
	1,
	244,
	251,
	Z0 + 213,
	Z0 + 224,
	DECK,
	ground(1, 253, Z0 + 200) - 0.2,
	5,
	Color3.fromRGB(150, 106, 68)
)
steps(
	docks,
	1,
	244,
	251,
	Z0 + 166,
	Z0 + 176,
	DECK,
	ground(1, 253, Z0 + 200) - 0.2,
	5,
	Color3.fromRGB(150, 106, 68)
)
-- the whale, at the far end
if opt("Whale2") then
	afloat(place(ships, SRC.Whale2, 1.2, 0, Vector3.new(200, SURFACE - 6, Z0 + 339)))
end
-- the beach: the bar, the wanted board, treasure, a boat pulled up on the sand
do
	local ax = BEACH0 + 12
	local bar = place(
		props,
		SRC.TikiBar,
		1.3,
		facing(1),
		Vector3.new(ax, beachY(1, ax, Z0 + 266) + 1.4, Z0 + 266)
	)
	footing(props, bar, Color3.fromRGB(150, 106, 68), Enum.Material.WoodPlanks, 8, 1.04)
	if opt("WantedBoard") then
		place(
			props,
			SRC.WantedBoard,
			1.4,
			facing(1),
			Vector3.new(BEACH0 + 5, beachY(1, BEACH0 + 5, Z0 + 240), Z0 + 240)
		)
	end
	place(
		props,
		SRC.Rowboat,
		2.2,
		28,
		Vector3.new(BEACH0 + 7, beachY(1, BEACH0 + 7, Z0 + 118), Z0 + 118)
	)
	place(
		props,
		KIT.Prop_pirate_harbor_TreasurePile,
		1.8,
		200,
		Vector3.new(BEACH0 + 10, beachY(1, BEACH0 + 10, Z0 + 150), Z0 + 150)
	)
	place(
		props,
		KIT.Prop_pirate_harbor_TreasurePile,
		1.4,
		40,
		Vector3.new(BEACH0 + 8, beachY(1, BEACH0 + 8, Z0 + 304), Z0 + 304)
	)
end
-- the rim: the windmill above the restaurant, the straw hat above the ship
do
	local ax = rimAx(1) + 14
	local mill = place(
		props,
		SRC.Windmill,
		1.5,
		facing(1),
		Vector3.new(ax, ground(1, ax, Z0 + 128) + 1.5, Z0 + 128)
	)
	footing(props, mill, STONE, Enum.Material.Cobblestone, 14)
	local hx = rimAx(1) + 20
	local hat = place(
		props,
		SRC.StrawHat,
		3.2,
		0,
		Vector3.new(hx, ground(1, hx, Z0 + 268) + 0.4, Z0 + 268),
		{ fit = 1.05 }
	)
	hat:PivotTo(hat:GetPivot() * CFrame.Angles(0, 0, math.rad(14)))
	hat:SetAttribute("HangOk", 20) -- tipped on purpose: its brim lifts off the grass on one side
	hat:SetAttribute("SunkOk", 12)
end

-- ---------------------------------------------------------------------------------- -X: the navy and the port
-- the warship, under the fortress on the rim
afloat(place(ships, SRC.NavyShip, 2.1, 0, Vector3.new(-201, SURFACE - DRAFT, Z0 + 132)))
do
	local ax = rimAx(-1) + 22
	local base = place(
		props,
		SRC.MarineBase,
		1.6,
		facing(-1),
		Vector3.new(-ax, ground(-1, ax, Z0 + 150) + 4, Z0 + 150)
	)
	footing(props, base, Color3.fromRGB(232, 232, 236), Enum.Material.Slate, 24, 1.02)
	local lx = rimAx(-1) + 8
	place(
		props,
		KIT.Prop_pirate_harbor_Lighthouse,
		2.2,
		0,
		Vector3.new(-lx, ground(-1, lx, Z0 + 338) - 1, Z0 + 338)
	)
end
-- a battery on the navy's beach, muzzles to the lane
for _, z in { Z0 + 126, Z0 + 148, Z0 + 170 } do
	local ax = BEACH0 + 6
	place(
		props,
		KIT.Prop_pirate_harbor_Cannon,
		1.7,
		facing(-1),
		Vector3.new(-ax, beachY(-1, ax, z), z)
	)
end
-- the port: a deck on stilts from the cliff's foot, a pier across to the quay
local T0, T1 = Z0 + 186, Z0 + 330
deck(docks, -1, 196, 244, T0, T1, DECK, FOOT, nil, { lane = true, z0 = true, z1 = true })
deck(docks, -1, 163, 196, Z0 + 190, Z0 + 204, DECK, FOOT, { step = 30 })
row({
	parent = town,
	side = -1,
	z = T0 + 3,
	y = DECK,
	gap = 3,
	list = {
		{ SRC.PortHouseB, 1.9 },
		{ SRC.Tavern, 1.2 },
		{ SRC.PortHouseA, 2.0 },
		{ SRC.PortHouseB, 1.7 },
	},
})
-- the tavern's mesh stands on its own disc of water: sunk until the disc is under the planks
for _, m in town:GetChildren() do
	if m.Name == "Tavern" then
		m:PivotTo(m:GetPivot() - Vector3.new(0, 3.4, 0))
		m:SetAttribute("SunkOk", 4)
	end
end
-- the market on the promenade, in front of the narrower houses
place(props, KIT.Prop_pirate_harbor_FishStall, 1.4, facing(-1), Vector3.new(-203, DECK, Z0 + 286))
try(props, KIT.Prop_store_ProduceTable, 1.0, facing(-1), Vector3.new(-203, DECK, Z0 + 316))
for i, z in { Z0 + 212, Z0 + 268, Z0 + 300, Z0 + 324 } do
	try(
		props,
		KIT[if i % 2 == 0 then "Prop_store_Barrel" else "Prop_store_Crate"],
		1.6,
		i * 33,
		Vector3.new(-200, DECK, z)
	)
end
for _, z in { T0 + 8, T0 + 52, T0 + 96, T1 - 8 } do
	try(props, KIT.Prop_store_LampPost, 1.5, facing(-1), Vector3.new(-198.5, DECK, z))
end
-- at the town's quay: the little sheep-headed ship and the rowboats
if opt("SheepShip") then
	afloat(place(ships, SRC.SheepShip, 1.2, 0, Vector3.new(-179, SURFACE - 3.5, Z0 + 268)))
end
for i, z in { Z0 + 222, Z0 + 316 } do
	local boat =
		try(ships, SRC.Rowboat, 2.0, 10 - i * 14, Vector3.new(-176 - i * 3, SURFACE - 1.6, z))
	if boat then
		afloat(boat)
	end
end
-- the sea serpent, at the far end
afloat(place(ships, SRC.SeaKing, 1.5, 0, Vector3.new(-201, SURFACE - 2.5, Z0 + 348)))

-- ---------------------------------------------------------------------------------- both sides
-- buoys off the quays, lamps on them
for _, side in { -1, 1 } do
	if opt("Buoy") then
		for z = Z0 + 96, Z1 - 20, 62 do
			local b = try(ships, SRC.Buoy, 1.2, 0, Vector3.new(side * 168, SURFACE - 2.4, z))
			if b then
				afloat(b)
			end
		end
	end
	for z = Z0 + 110, Z1 - 30, 56 do
		local lamp = make(
			props,
			KIT.Prop_store_LampPost,
			1.5,
			facing(side),
			Vector3.new(side * 161.4, LY + 0.4, z)
		)
		lamp:SetAttribute("AuditSkip", true) -- on the quay's top, clear of everything by position
	end
end
-- palms and bushes on the beaches, jungle on the rims: never through anything already standing
for _, side in { -1, 1 } do
	scatter({
		parent = trees,
		templates = { SRC.Palm },
		count = 11,
		side = side,
		ax = { BEACH0 + 2, BEACH1 },
		z = { Z0 + 92, Z1 - 6 },
		scale = { 1.0, 1.5 },
		sink = 0.8,
		fit = 0.5,
		soft = true,
	})
	scatter({
		parent = trees,
		templates = { JUNGLE.BushLeafy },
		count = 8,
		side = side,
		ax = { BEACH0 + 10, BEACH1 - 2 },
		z = { Z0 + 92, Z1 - 6 },
		scale = { 1.2, 1.9 },
		sink = 0.6,
		soft = true,
	})
	scatter({
		parent = trees,
		templates = { JUNGLE.RockOutcrop },
		count = 3,
		side = side,
		ax = { BEACH1 - 2, BEACH1 + 3 },
		z = { Z0 + 92, Z1 - 6 },
		scale = { 0.35, 0.6 },
		sink = 1.2,
		sunkOk = 12, -- rocks at the foot of the cliff lean into it
		soft = true,
	})
	for z = Z0 + 24, Z1 - 16, 22 do
		local roll = rng:NextNumber()
		local template = if roll < 0.35
			then SRC.Palm
			elseif roll < 0.7 then JUNGLE.TreeBroad
			else JUNGLE.TreeTall
		plant(
			trees,
			template,
			side,
			rimAx(side) + rng:NextNumber(-6, 10),
			z + rng:NextNumber(-7, 7),
			rng:NextNumber(1.4, 2.0)
		)
	end
	-- a second rank further back, so the rim is a jungle and not one line of trees
	for z = Z0 + 34, Z1 - 16, 34 do
		plant(
			trees,
			if rng:NextNumber() < 0.5 then JUNGLE.TreeBroad else JUNGLE.TreeTall,
			side,
			rimAx(side) + rng:NextNumber(26, 44),
			z + rng:NextNumber(-10, 10),
			rng:NextNumber(1.6, 2.3)
		)
	end
end

floor({
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
local _ = STONE
return finish()
