-- RETIRED 2026-11-22: zone 9 on the old 320-wide lane (zone_lib). Kept for its content and numbers;
-- zones/zone_09_titan.luau (side_lib) builds the zone now.
-- zone_09_titan.luau - zone 9, "Wall Maria" (Attack on Titan), z 3040..3400. Map id wall_maria (no
-- zone data yet). Run: python tools/studio/zones/run_zone.py build 9 [--no-terrain]
-- (rebuilt 2026-11-22: the first version was six copies of one house, a tower and a gate on bare
-- earth under blank walls.)
--
-- The picture: a town inside the Walls. Both sides are sheer masonry walls 110 studs tall with a
-- walkway on top: buttresses, a parapet, cannons, banners. At their foot, a cobbled street.
--   +X (left from the throw stage): town houses, the bakery, the well and a supply wagon, the great
--     gate set in the wall, and the soldier's monument facing the throwers.
--   -X: the bell tower, the garrison's headquarters, the stables, a house, the training ground
--     with its giant-shaped dummies, and the giant itself looking over the wall above it.
-- Templates: StoreAssets.Zone09_Titan (all generate_mesh, squared, fronting -Z).
local B = Enum.Material.Brick
local root = begin({
	n = 9,
	id = "wall_maria",
	title = "Wall Maria (Attack on Titan)",
	src = "Zone09_Titan",
	now = { -- one sheer rise to the walkway, then level
		face = { [-1] = 234, [1] = 234 },
		rise = { [-1] = 4, [1] = 4 },
		ledgeW = { [-1] = 34, [1] = 34 },
		ledgeY = { [-1] = 62, [1] = 62 },
		top = { [-1] = 62, [1] = 62 },
	},
	prev = { -- zone 8's crossroads
		face = { [-1] = 236, [1] = 236 },
		rise = { [-1] = 6, [1] = 6 },
		ledgeW = { [-1] = 26, [1] = 26 },
		ledgeY = { [-1] = 10, [1] = 10 },
		top = { [-1] = 64, [1] = 64 },
	},
	mats = {
		rock = B,
		prevRock = Enum.Material.Glacier,
		terrace = Enum.Material.Ground,
		prevTerrace = Enum.Material.LeafyGrass,
		ledge = Enum.Material.Cobblestone,
		top = Enum.Material.Cobblestone,
	},
	colors = { [B] = Color3.fromRGB(178, 168, 152) },
	wobble = 0, -- a wall: dead straight
})
local sights = folder(root, "Sights")
local groundF = folder(root, "Ground")
local masonry = folder(root, "Masonry")
local props = folder(root, "Props")
local trees = folder(root, "Trees")
local JUNGLE = STORE.Zone01_Naruto

local COBBLE = Color3.fromRGB(168, 156, 140)
local STONE = Color3.fromRGB(146, 134, 118) -- clearly darker than the wall, or the masonry vanishes
local DARK = Color3.fromRGB(108, 98, 86)
local GREEN = Color3.fromRGB(52, 112, 70)
local WOOD = Color3.fromRGB(104, 74, 50)
local S0, S1 = Z0 + 82, Z1 + 10 -- the terrace clear of both gates' pillars
local GY = TERRACE + 0.35 -- the top of the paving
local TOP = NOW.top[1]
local skip = { [-1] = {}, [1] = {} } -- stretches of wall the buttresses and merlons leave free

-- ================================================================================== +X: the town
do
	local side = 1
	pave(groundF, side, 163.5, 240, S0 - 4, S1 + 2, COBBLE, Enum.Material.Cobblestone)
	local z = S0 + 2
	local houseZ0 = z
	z = row({
		parent = sights,
		side = side,
		z = z,
		gap = 4,
		backGap = 6,
		list = { { SRC.TownHouse, 1.9 } },
	})
	local bakeryZ0 = z
	z = row({
		parent = sights,
		side = side,
		z = z,
		gap = 4,
		backGap = 6,
		list = { { SRC.Bakery, 1.9 }, { SRC.TownHouse, 1.7 } },
	})
	local gateZ0 = z
	z = row({
		parent = sights,
		side = side,
		z = z,
		gap = 4,
		backGap = 6,
		list = { { SRC.WallGate, 1.9 } },
	})
	local gateZ1 = z - 4
	table.insert(skip[side], { gateZ0 - 6, gateZ1 + 6 })
	-- the well, the wagon, crates and barrels in the street
	place(props, SRC.Well, 1.5, 0, Vector3.new(180, GY, houseZ0 + 21))
	place(props, SRC.Wagon, 1.5, 12, Vector3.new(172, GY, bakeryZ0 + 24))
	try(props, KIT.Prop_store_Barrel, 1.6, 0, Vector3.new(184, GY, bakeryZ0 + 8))
	try(props, KIT.Prop_store_Crate, 1.6, 30, Vector3.new(186, GY, bakeryZ0 + 46))
	try(props, KIT.Prop_pirate_harbor_BarrelStack, 1.4, 20, Vector3.new(171, GY, gateZ0 + 8))
	for lz = S0 + 10, gateZ1, 44 do
		try(props, KIT.Prop_store_LampPost, 1.6, facing(side), Vector3.new(166.6, GY, lz))
	end
	-- the soldier's monument on its plinth, facing the throw stage
	do
		local sz = (gateZ1 + 4 + S1) / 2
		for i, r in { 20, 16 } do
			local ring = cylinder(
				sights,
				"MonumentPlinth",
				r * 2,
				1.4,
				CFrame.new(200, GY + i * 1.3 - 0.6, sz),
				STONE,
				Enum.Material.Slate
			)
			ring.CastShadow = false
		end
		reserve(200, sz, 20, 20, LY, GY + 4, "the monument's plinth")
		place(sights, SRC.Soldier, 2.2, 0, Vector3.new(200, GY + 2.6, sz), { over = true })
		for _, dz in { -24, 24 } do
			try(
				trees,
				JUNGLE.TreeBroad,
				0.8,
				0,
				Vector3.new(220, TERRACE - 0.6, sz + dz),
				{ fit = 0.4 }
			)
		end
	end
end

-- ================================================================================== -X: the garrison
do
	local side = -1
	pave(groundF, side, 163.5, 240, S0 - 4, S1 + 2, COBBLE, Enum.Material.Cobblestone)
	local z = S0 + 2
	z = row({
		parent = sights,
		side = side,
		z = z,
		gap = 4,
		backGap = 6,
		list = { { SRC.BellTower, 1.8 } },
	})
	local hqZ0 = z
	z = row({
		parent = sights,
		side = side,
		z = z,
		gap = 4,
		backGap = 6,
		list = { { SRC.Barracks, 1.9 } },
	})
	local stableZ0 = z
	z = row({
		parent = sights,
		side = side,
		z = z,
		gap = 4,
		backGap = 6,
		list = { { SRC.Stable, 1.8 }, { SRC.TownHouse, 1.8 } },
	})
	local rowEnd = z - 4
	-- a wagon and supplies before the headquarters, hay by the stables
	place(props, SRC.Wagon, 1.5, -10, Vector3.new(-172, GY, hqZ0 + 20))
	try(props, KIT.Prop_store_Crate, 1.6, 20, Vector3.new(-171, GY, hqZ0 + 44))
	try(props, KIT.Prop_store_Crate, 1.3, 50, Vector3.new(-175, GY, hqZ0 + 48))
	try(props, STORE.Zone06_BlackClover.HayCart, 1.5, 200, Vector3.new(-176, GY, stableZ0 + 12))
	try(props, KIT.Prop_store_Barrel, 1.6, 0, Vector3.new(-170, GY, stableZ0 + 34))
	for lz = S0 + 30, rowEnd, 48 do
		try(props, KIT.Prop_store_LampPost, 1.6, facing(side), Vector3.new(-166.6, GY, lz))
	end
	-- the training ground: giant-shaped dummies in a row, a fence, weapon crates
	local tz = (rowEnd + 4 + S1) / 2
	do
		for i = -1, 1 do
			place(props, SRC.Dummy, 1.4, 0, Vector3.new(-202 + i * 2, GY, tz + i * 20))
		end
		fence(props, -176, rowEnd + 6, -176, S1 - 4, GY, 3.4, WOOD, Enum.Material.Wood, 8)
		try(props, KIT.Prop_store_Crate, 1.6, 10, Vector3.new(-184, GY, tz - 8))
		try(props, KIT.Prop_pirate_harbor_BarrelStack, 1.4, 60, Vector3.new(-186, GY, tz + 12))
	end
	-- the giant looks over the wall above the training ground: only its head, shoulders and hands
	-- show, the rest stands in the wall
	do
		local s = 2.3
		local height = sizeOf(SRC.Colossus).Y * s
		-- its mesh carries its own piece of wall under the hands: a raised bastion on the walkway
		-- encloses that piece, so the hands grip the bastion's top and the head looks over it
		local face = NOW.face[side]
		local giant = make(
			sights,
			SRC.Colossus,
			s,
			facing(side),
			Vector3.new(-(face + 22), TOP - height * 0.56 + 19, tz)
		)
		giant:SetAttribute("AuditSkip", true) -- behind the wall on purpose
		-- a tower from the street to above the top of the wall, proud of its face: the mesh's own
		-- piece of wall and its fingertips came through anything smaller
		block(
			masonry,
			"Bastion",
			Vector3.new(30, TOP + 19 - LY, 82),
			CFrame.new(-(face + 8), (TOP + 19 + LY) / 2, tz),
			STONE,
			B
		)
		block(
			masonry,
			"BastionCourse",
			Vector3.new(31, 3, 83),
			CFrame.new(-(face + 8), TOP + 13, tz),
			DARK,
			B
		)
		block(
			masonry,
			"BastionCourse",
			Vector3.new(31, 3, 83),
			CFrame.new(-(face + 8), LY + 58, tz),
			DARK,
			B
		)
		block(
			masonry,
			"BastionPlinth",
			Vector3.new(33, 10, 85),
			CFrame.new(-(face + 8), LY + 5, tz),
			DARK,
			B
		)
		for _, dz in { -38, -28, 28, 38 } do
			block(
				masonry,
				"BastionMerlon",
				Vector3.new(6, 5, 6),
				CFrame.new(-(face - 4), TOP + 21.5, tz + dz),
				STONE,
				B
			)
		end
		table.insert(skip[side], { tz - 42, tz + 42 })
	end
end

-- ================================================================================== the Walls
-- bare terrain read as a blank sheet: each face gets a plinth, a string course, buttresses and a
-- crenellated parapet, and the walkway gets cannons and banners
local function free(side: number, z: number, margin: number): boolean
	for _, s in skip[side] do
		if z > s[1] - margin and z < s[2] + margin then
			return false
		end
	end
	return true
end
for _, side in { -1, 1 } do
	local face = NOW.face[side]
	local len, mid = Z1 - Z0, (Z0 + Z1) / 2
	block(
		masonry,
		"Plinth",
		Vector3.new(8, 9, len),
		CFrame.new(side * (face - 2), LY + 4.5, mid),
		DARK,
		B
	)
	block(
		masonry,
		"Course",
		Vector3.new(5, 3, len),
		CFrame.new(side * (face - 1), LY + 58, mid),
		DARK,
		B
	)
	block(
		masonry,
		"Parapet",
		Vector3.new(6, 5, len),
		CFrame.new(side * (face + 2), TOP + 2, mid),
		STONE,
		B
	)
	for bz = Z0 + 22, Z1 - 10, 44 do
		if free(side, bz, 6) then
			block(
				masonry,
				"Buttress",
				Vector3.new(9, TOP - LY + 2, 12),
				CFrame.new(side * (face - 1.5), (TOP + LY) / 2 + 1, bz),
				STONE,
				B
			)
			block(
				masonry,
				"ButtressCap",
				Vector3.new(11, 4, 14),
				CFrame.new(side * (face - 1.5), TOP + 4, bz),
				DARK,
				B
			)
		end
	end
	for mz = Z0 + 8, Z1 - 6, 14 do
		if free(side, mz, -8) then
			block(
				masonry,
				"Merlon",
				Vector3.new(6, 5, 7),
				CFrame.new(side * (face + 2), TOP + 7, mz),
				STONE,
				B
			)
		end
	end
	-- cannons on the walkway, muzzles to the lane; a banner between each pair
	for cz = Z0 + 60, Z1 - 30, 56 do
		local ax = face + NOW.rise[side] + 13
		if free(side, cz, 4) then
			place(
				props,
				SRC.Cannon,
				1.5,
				facing(side),
				Vector3.new(side * ax, ground(side, ax, cz) - 0.2, cz)
			)
		end
		local fz = cz + 28
		if free(side, fz, 4) then
			local gy = ground(side, ax, fz)
			local pole = cylinder(
				props,
				"BannerPole",
				1,
				26,
				CFrame.new(side * (face + 6), gy + 13, fz),
				WOOD,
				Enum.Material.Wood
			)
			pole.CastShadow = false
			local cloth = block(
				props,
				"Banner",
				Vector3.new(0.4, 13, 8),
				CFrame.new(side * (face + 6), gy + 19, fz + 4.6),
				GREEN,
				Enum.Material.Fabric
			)
			cloth.CastShadow = false
		end
	end
end

floor({
	title = "WALL MARIA",
	accent = Color3.fromRGB(46, 110, 160),
	strip = function(tile: number, track: number)
		if (tile + track) % 2 == 0 then
			return Color3.fromRGB(88, 122, 72), Color3.fromRGB(150, 186, 130)
		end
		return Color3.fromRGB(204, 184, 144), Color3.fromRGB(232, 218, 190)
	end,
	kerb = Color3.fromRGB(112, 82, 54),
	paving = Color3.fromRGB(170, 160, 146),
	pavingTex = Color3.fromRGB(206, 198, 186),
})
return finish()
