-- RETIRED 2026-11-22: zone 6 on the old 320-wide lane (zone_lib). Kept for its content and numbers;
-- zones/zone_06_black_clover.luau (side_lib) builds the zone now.
-- zone_06_black_clover.luau - zone 6, "Clover Kingdom" (Black Clover), z 1960..2320. Config id
-- still realm_of_legends. Run: python tools/studio/zones/run_zone.py build 6 [--no-terrain]
-- (rebuilt 2026-11-22: the first version was a castle, four houses and a tower on bare grass, with a
-- house in a gate pillar and trees through the houses on the ledges.)
--
-- The picture: a fantasy kingdom in a green valley.
--   +X (left from the throw stage), the royal capital on cobbles: the castle, tall town houses, the
--     grimoire tower with the fountain at its foot, a market down the street, and the stone wizard
--     king on his plinth facing the throwers, a waterfall behind him.
--   -X, the village: the church, a farmhouse with its garden and hay cart, the crooked guild base,
--     and the colossal horned skull at the far end.
--   Grimoires hang in the air over both streets; clover leaves on the wind; cottages and a wood on
--   the ledges and rims, a tower and a windmill above.
-- Templates: StoreAssets.Zone06_BlackClover (all generate_mesh, squared, fronting -Z).
local G = Enum.Material.LeafyGrass
local root = begin({
	n = 6,
	id = "realm_of_legends",
	title = "Clover Kingdom (Black Clover)",
	src = "Zone06_BlackClover",
	now = {
		face = { [-1] = 236, [1] = 236 },
		rise = { [-1] = 6, [1] = 6 },
		ledgeW = { [-1] = 26, [1] = 26 },
		ledgeY = { [-1] = 8, [1] = 8 },
		top = { [-1] = 64, [1] = 64 },
	},
	prev = { -- zone 5's stadium (as rebuilt)
		face = { [-1] = 236, [1] = 236 },
		rise = { [-1] = 6, [1] = 6 },
		ledgeW = { [-1] = 20, [1] = 20 },
		ledgeY = { [-1] = 16, [1] = 16 },
		top = { [-1] = 62, [1] = 62 },
	},
	-- the hills' own grey rock: this zone is a valley in them
	mats = {
		rock = Enum.Material.Rock,
		prevRock = Enum.Material.Concrete,
		terrace = G,
		prevTerrace = Enum.Material.Pavement,
		ledge = G,
		top = G,
	},
	wobble = 0.5,
})
local town = folder(root, "Town")
local village = folder(root, "Village")
local groundF = folder(root, "Ground")
local props = folder(root, "Props")
local trees = folder(root, "Trees")
local books = folder(root, "Grimoires")
local JUNGLE = STORE.Zone01_Naruto

local COBBLE = Color3.fromRGB(176, 170, 160)
local DIRT = Color3.fromRGB(150, 116, 82)
local WOOD = Color3.fromRGB(112, 78, 52)
local GREEN = Color3.fromRGB(44, 150, 80)
local GOLD = Color3.fromRGB(236, 196, 76)
local STONE = Color3.fromRGB(150, 150, 156)
local S0, S1 = Z0 + 82, Z1 + 10 -- the terrace clear of both gates' pillars
local GY = TERRACE + 0.35 -- the top of the paving

-- a clover banner on a pole, facing the lane
local function banner(side: number, ax: number, z: number, y: number)
	local r = {
		cx = side * ax,
		cz = z,
		hx = 1.5,
		hz = 4,
		rx = 1,
		rz = 0,
		y0 = y,
		y1 = y + 24,
		name = "a banner",
	}
	if blockedBy(r) then
		return
	end
	local pole = cylinder(
		props,
		"BannerPole",
		0.9,
		22,
		CFrame.new(side * ax, y + 11, z),
		WOOD,
		Enum.Material.Wood
	)
	pole.CastShadow = false
	local cloth = block(
		props,
		"Banner",
		Vector3.new(0.4, 12, 6),
		CFrame.new(side * ax, y + 15, z + 3.6),
		GREEN,
		Enum.Material.Fabric
	)
	cloth.CastShadow = false
	words(cloth, if side > 0 then Enum.NormalId.Left else Enum.NormalId.Right, "🍀", GOLD)
	table.insert(claims, r)
end

-- the waterfall behind the wizard king, first, so nothing is planted in its course
waterfall(groundF, 1, Z1 - 20, 22)

-- ================================================================================== +X: the royal capital
do
	local side = 1
	local z = S0 + 2
	z = row({ parent = town, side = side, z = z, gap = 4, list = { { SRC.Castle, 1.8 } } })
	local houseAZ0 = z
	z = row({ parent = town, side = side, z = z, gap = 4, list = { { SRC.NobleHouse, 2.1 } } })
	local towerZ0 = z
	z = row({ parent = town, side = side, z = z, gap = 4, list = { { SRC.GrimoireTower, 1.8 } } })
	local towerZ1 = z - 4
	local houseBZ0 = z
	z = row({ parent = town, side = side, z = z, gap = 4, list = { { SRC.NobleHouse, 1.9 } } })
	local rowEnd = z - 4
	-- the street's cobbles run up to the plaza's, with no slot between the two slabs
	pave(groundF, side, 163.5, 240, S0 - 4, rowEnd + 2, COBBLE, Enum.Material.Cobblestone)

	-- the fountain at the foot of the grimoire tower
	place(props, SRC.Fountain, 1.6, 0, Vector3.new(180, GY, (towerZ0 + towerZ1) / 2))
	-- the market: stalls by the lane, in front of the two houses, with their goods about them
	for i, sz in { houseAZ0 + 12, houseAZ0 + 34, houseBZ0 + 19 } do
		place(props, SRC.MarketStall, 1.5, facing(side), Vector3.new(172.5, GY, sz))
		try(
			props,
			KIT[if i % 2 == 0 then "Prop_store_Barrel" else "Prop_store_Crate"],
			1.5,
			i * 37,
			Vector3.new(184, GY, sz - 7)
		)
		try(props, KIT.Prop_store_Crate, 1.2, i * 21, Vector3.new(186.5, GY, sz + 6))
	end
	-- lamps and clover banners down the street
	for lz = S0 + 10, rowEnd, 46 do
		try(props, KIT.Prop_store_LampPost, 1.6, facing(side), Vector3.new(166.6, GY, lz))
		banner(side, 166.4, lz + 23, GY)
	end

	-- the end plaza: the wizard king on a stepped plinth, facing the throw stage
	do
		local pz = (rowEnd + 4 + S1) / 2
		pave(groundF, side, 163.5, 226, rowEnd + 2, S1 + 2, COBBLE, Enum.Material.Cobblestone)
		for i, r in { 23, 19 } do
			local ring = cylinder(
				town,
				"KingPlinth",
				r * 2,
				1.4,
				CFrame.new(198, GY + i * 1.3 - 0.6, pz),
				STONE,
				Enum.Material.Slate
			)
			ring.CastShadow = false
		end
		reserve(198, pz, 23, 23, LY, GY + 4, "the king's plinth")
		place(town, SRC.WizardKing, 2.2, 0, Vector3.new(198, GY + 2.6, pz), { over = true })
		banner(side, 170, pz - 20, GY)
		banner(side, 170, pz + 20, GY)
	end
end

-- ================================================================================== -X: the village
do
	local side = -1
	-- a dirt road by the lane, grass behind it
	pave(groundF, side, 163.5, 174, S0 - 4, S1 + 2, DIRT, Enum.Material.Ground)
	local z = S0 + 2
	local churchZ0 = z
	z = row({ parent = village, side = side, z = z, gap = 4, list = { { SRC.Church, 1.9 } } })
	local farmZ0 = z
	z = row({ parent = village, side = side, z = z, gap = 4, list = { { SRC.House, 1.9 } } })
	local farmZ1 = z - 4
	local baseZ0 = z
	z = row({ parent = village, side = side, z = z, gap = 4, list = { { SRC.BullsBase, 2.2 } } })
	local baseZ1 = z - 4
	local rowEnd = z - 4

	-- the church's path and its lamp
	pave(groundF, side, 174, 186, churchZ0 + 16, churchZ0 + 26, DIRT, Enum.Material.Ground)
	try(props, KIT.Prop_store_LampPost, 1.6, facing(side), Vector3.new(-176, GY, churchZ0 + 8))
	-- the farmhouse's garden: fenced rows of crops, the hay cart, a barrel
	do
		local g0, g1 = farmZ0 + 3, farmZ1 - 3
		fence(props, -175, g0, -175, g1, TERRACE, 3.2, WOOD, Enum.Material.Wood, 7)
		fence(props, -175, g0, -192, g0, TERRACE, 3.2, WOOD, Enum.Material.Wood, 7)
		fence(props, -175, g1, -192, g1, TERRACE, 3.2, WOOD, Enum.Material.Wood, 7)
		for i = 0, 3 do
			local ax = 178 + i * 3.6
			local soil = block(
				groundF,
				"Soil",
				Vector3.new(2.2, 0.6, g1 - g0 - 22),
				CFrame.new(-ax, TERRACE + 0.3, (g0 + g1) / 2 + 9),
				Color3.fromRGB(104, 76, 54),
				Enum.Material.Ground
			)
			soil.CastShadow = false
			for cz = g0 + 23, g1 - 3, 3.4 do
				local crop = block(
					groundF,
					"Crop",
					Vector3.new(1.6, 1.6, 1.6),
					CFrame.new(-ax, TERRACE + 1.3, cz) * CFrame.Angles(0, math.rad(45), 0),
					if i % 2 == 0 then Color3.fromRGB(96, 190, 84) else Color3.fromRGB(236, 150, 60),
					Enum.Material.Grass
				)
				crop.CastShadow = false
			end
		end
		reserve(-184, (g0 + g1) / 2 + 9, 9, (g1 - g0 - 22) / 2, LY, TERRACE + 3, "the crops")
		place(props, SRC.HayCart, 1.6, 20, Vector3.new(-183, TERRACE, g0 + 10))
		try(props, KIT.Prop_store_Barrel, 1.5, 0, Vector3.new(-178, TERRACE, g0 + 20))
	end
	-- the guild base's yard: the great cauldron-grimoire, barrels, crates
	place(props, SRC.Grimoire, 0.8, facing(side), Vector3.new(-173.5, TERRACE, churchZ0 + 36))
	try(props, KIT.Prop_pirate_harbor_BarrelStack, 1.4, 30, Vector3.new(-170, TERRACE, baseZ1 - 10))
	try(props, KIT.Prop_store_Crate, 1.6, 15, Vector3.new(-169, TERRACE, baseZ1 - 22))
	-- lamps and banners down the road
	for lz = S0 + 30, rowEnd, 52 do
		try(props, KIT.Prop_store_LampPost, 1.6, facing(side), Vector3.new(-166.6, GY, lz))
		banner(side, 166.4, lz + 26, GY)
	end
	-- the colossal skull at the far end, facing the throw stage
	do
		local sz = (rowEnd + 4 + S1) / 2
		local skull = place(village, SRC.DemonSkull, 1.75, 0, Vector3.new(-200, TERRACE - 1.2, sz))
		skull:SetAttribute("SunkOk", 4)
	end
end

-- ================================================================================== both sides
-- grimoires hanging in the air over the streets
for _, side in { -1, 1 } do
	for i = 1, 5 do
		local bz = S0 + 14 + (i - 1) * 52 + side * 9
		local book = make(
			books,
			SRC.FloatingBook,
			1.4,
			rng:NextInteger(0, 359),
			Vector3.new(side * rng:NextNumber(168, 180), TERRACE + 20 + (i * 7) % 16, bz)
		)
		book:PivotTo(
			book:GetPivot()
				* CFrame.Angles(
					math.rad(rng:NextNumber(-22, 22)),
					0,
					math.rad(rng:NextNumber(-22, 22))
				)
		)
		book:SetAttribute("AuditSkip", true) -- in the air, above everything, by design
	end
	-- a cottage on the ledge, and above it the tower (+X) or the mill (-X) on the rim
	do
		local lz = Z0 + 150 + (side + 1) * 55
		local ax = ledgeAx(side) + 1
		local c = place(
			village,
			SRC.House,
			1.0,
			facing(side),
			Vector3.new(side * ax, ground(side, ax, lz) + 1.2, lz)
		)
		footing(village, c, STONE, Enum.Material.Cobblestone, 8, 1.04)
		local rx = rimAx(side) + 20
		local rz = Z0 + 250 - (side + 1) * 55
		local big = if side > 0 then SRC.WizardTower else STORE.Zone03_OnePiece.Windmill
		local m = place(
			village,
			big,
			1.5,
			facing(side),
			Vector3.new(side * rx, ground(side, rx, rz) + 2, rz)
		)
		footing(village, m, STONE, Enum.Material.Cobblestone, 14, 1.06)
	end
	-- trees and bushes on the ledge, a deep wood on the rim
	for tz = Z0 + 40, Z1 - 10, 34 do
		plant(
			trees,
			JUNGLE.TreeBroad,
			side,
			ledgeAx(side) + rng:NextNumber(-7, 7),
			tz + rng:NextNumber(-6, 6),
			rng:NextNumber(0.8, 1.2)
		)
	end
	scatter({
		parent = trees,
		templates = { JUNGLE.BushLeafy },
		count = 10,
		side = side,
		ax = { ledgeAx(side) - 10, ledgeAx(side) + 9 },
		z = { Z0 + 30, Z1 },
		scale = { 1.2, 1.9 },
		sink = 0.6,
		soft = true,
	})
	for tz = Z0 + 20, Z1 - 6, 22 do
		local roll = rng:NextNumber()
		local template = if roll < 0.4
			then JUNGLE.TreeBroad
			elseif roll < 0.75 then JUNGLE.TreeTall
			else STORE.Zone02_DemonSlayer.Cedar
		plant(
			trees,
			template,
			side,
			rimAx(side) + rng:NextNumber(-6, 10),
			tz + rng:NextNumber(-7, 7),
			rng:NextNumber(1.4, 2.0)
		)
	end
	for tz = Z0 + 30, Z1 - 6, 32 do
		plant(
			trees,
			if rng:NextNumber() < 0.5 then JUNGLE.TreeBroad else JUNGLE.TreeTall,
			side,
			rimAx(side) + rng:NextNumber(28, 46),
			tz + rng:NextNumber(-10, 10),
			rng:NextNumber(1.6, 2.3)
		)
	end
end
-- clover leaves on the wind
drift("rbxassetid://5057182105", Color3.fromRGB(120, 220, 120), Color3.fromRGB(60, 170, 90), 0.5)

floor({
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
return finish()
