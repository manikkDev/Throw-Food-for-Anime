-- RETIRED 2026-11-22: zone 7 on the old 320-wide lane (zone_lib). Kept for its content and numbers;
-- zones/zone_07_hunter.luau (side_lib) builds the zone now.
-- zone_07_hunter.luau - zone 7, "Hunter Exam" (Hunter x Hunter), z 2320..2680. Map id hunter_exam
-- (no zone data yet: lane_extend.luau). Run: python tools/studio/zones/run_zone.py build 7 [--no-terrain]
-- (rebuilt 2026-11-22: the first version was a hall, a tower, a tree and an airship on bare grass;
-- the tree's crown reached 24 studs into the lane and stood in a lamp.)
--
-- The picture: a deep forest pass, and the exam held in it.
--   +X (left from the throw stage), the exam: the steakhouse that hides the way in, the exam hall,
--     the windowless trick tower, the examinees' camp, and at the far end the colossal stone
--     testing gate facing the throwers. The arena tower stands on the rim; the airship hangs above.
--   -X, the wild: tree houses, the world tree with a pond and a waterfall behind it, the ants'
--     earthen nest, and the stone fisher boy on his rock at the far end. Mushrooms, logs, mossy
--     rocks and young trees all over the forest floor.
-- Templates: StoreAssets.Zone07_Hunter (all generate_mesh, squared, fronting -Z).
local G = Enum.Material.LeafyGrass
local root = begin({
	n = 7,
	id = "hunter_exam",
	title = "Hunter Exam (Hunter x Hunter)",
	src = "Zone07_Hunter",
	now = {
		face = { [-1] = 236, [1] = 236 },
		rise = { [-1] = 6, [1] = 6 },
		ledgeW = { [-1] = 28, [1] = 28 },
		ledgeY = { [-1] = 12, [1] = 12 },
		top = { [-1] = 70, [1] = 66 },
	},
	prev = { -- zone 6's valley
		face = { [-1] = 236, [1] = 236 },
		rise = { [-1] = 6, [1] = 6 },
		ledgeW = { [-1] = 26, [1] = 26 },
		ledgeY = { [-1] = 8, [1] = 8 },
		top = { [-1] = 64, [1] = 64 },
	},
	mats = {
		rock = Enum.Material.Mud,
		prevRock = Enum.Material.Rock,
		terrace = G,
		prevTerrace = G,
		ledge = G,
		top = G,
	},
	colors = { [Enum.Material.Mud] = Color3.fromRGB(126, 94, 64) },
	wobble = 0.6,
})
local sights = folder(root, "Sights")
local groundF = folder(root, "Ground")
local props = folder(root, "Props")
local trees = folder(root, "Trees")
local JUNGLE = STORE.Zone01_Naruto
local MOSS = STORE.Zone02_DemonSlayer.MossRock
local CEDAR = STORE.Zone02_DemonSlayer.Cedar

local DIRT = Color3.fromRGB(146, 112, 80)
local STONE = Color3.fromRGB(140, 140, 136)
local WATER = Color3.fromRGB(96, 190, 244)
local S0, S1 = Z0 + 82, Z1 + 10 -- the terrace clear of both gates' pillars
local GY = TERRACE + 0.35 -- the top of the paving

-- the waterfall behind the world tree, first, so nothing is planted in its course
local FALL_Z = Z0 + 150
waterfall(groundF, -1, FALL_Z, 20)

-- ================================================================================== +X: the exam
do
	local side = 1
	pave(groundF, side, 163.5, 176, S0 - 4, S1 + 2, DIRT, Enum.Material.Ground)
	local z = S0 + 2
	z = row({
		parent = sights,
		side = side,
		z = z,
		gap = 6,
		list = { { SRC.Steakhouse, 2.2 }, { SRC.ExamHall, 1.4 }, { SRC.TrickTower, 1.9 } },
	})
	local rowEnd = z - 6
	-- the gate at the far end, across the whole terrace, facing the throw stage
	local gateZ = S1 - 17.3 -- its unfinished back stands against the next gate's pillar
	place(sights, SRC.TestingGate, 2.4, 0, Vector3.new(200, TERRACE - 0.6, gateZ), { fit = 1.0 })
	-- the examinees' camp between the tower and the gate
	do
		local c0, c1 = rowEnd + 6, gateZ - 24
		local mid = (c0 + c1) / 2
		place(props, SRC.Camp, 1.5, 200, Vector3.new(196, TERRACE - 0.2, mid - 12))
		place(props, SRC.Camp, 1.3, 60, Vector3.new(214, TERRACE - 0.2, mid + 14))
		place(props, SRC.Signpost, 1.5, facing(side), Vector3.new(180, GY, mid))
		try(props, SRC.FallenLog, 1.6, 70, Vector3.new(190, TERRACE - 0.4, mid + 24))
		try(props, KIT.Prop_store_Barrel, 1.5, 0, Vector3.new(184, TERRACE, mid - 20))
		try(props, KIT.Prop_store_Crate, 1.5, 30, Vector3.new(187.5, TERRACE, mid - 24))
	end
	-- lamps down the road
	for lz = S0 + 12, S1 - 50, 48 do
		try(props, KIT.Prop_store_LampPost, 1.6, facing(side), Vector3.new(166.6, GY, lz))
	end
	-- the arena tower on the rim, the airship above the hall heading for it
	do
		local ax = rimAx(side) + 24
		local tz = Z0 + 190
		local tower = place(
			sights,
			SRC.ArenaTower,
			2.4,
			facing(side),
			Vector3.new(ax, ground(side, ax, tz) + 3, tz)
		)
		footing(sights, tower, STONE, Enum.Material.Cobblestone, 18, 1.05)
		local ship = make(sights, SRC.Airship, 1.6, 0, Vector3.new(196, 40, Z0 + 260))
		ship:SetAttribute("AuditSkip", true) -- in the air, above everything, by design
	end
end

-- ================================================================================== -X: the wild
do
	local side = -1
	pave(groundF, side, 163.5, 174, S0 - 4, S1 + 2, DIRT, Enum.Material.Ground)
	-- the pond at the waterfall's foot, rimmed with mossy rocks
	do
		local pond =
			cylinder(groundF, "Pond", 30, 0.8, CFrame.new(-222, TERRACE + 0.5, FALL_Z), WATER)
		pond.Transparency = 0.1
		pond.Reflectance = 0.08
		pond.CastShadow = false
		reserve(-222, FALL_Z, 13, 15, LY, TERRACE + 3, "the pond")
		for i = 0, 6 do
			local a = math.rad(70 + i * 37)
			try(
				trees,
				MOSS,
				0.32,
				i * 50,
				Vector3.new(-222 + math.cos(a) * 17, TERRACE - 1.2, FALL_Z + math.sin(a) * 17)
			)
		end
	end
	-- tree house, world tree, tree house, the ants' nest, the fisher boy
	place(sights, SRC.TreeHouse, 1.7, facing(side), Vector3.new(-204, TERRACE - 0.5, S0 + 26))
	local giant = place(
		sights,
		SRC.GiantTree,
		2.0,
		0,
		Vector3.new(-208, TERRACE - 1, Z0 + 202),
		{ fit = 0.3 }
	)
	giant:SetAttribute("Soft", true) -- a tree: things may stand under its crown
	place(sights, SRC.TreeHouse, 1.5, facing(side) + 25, Vector3.new(-206, TERRACE - 0.5, Z0 + 270))
	place(sights, SRC.AntNest, 1.6, facing(side), Vector3.new(-206, TERRACE - 0.6, Z0 + 318))
	do
		local sz = S1 - 16
		local rock = cylinder(
			sights,
			"StatueRock",
			28,
			2.4,
			CFrame.new(-198, TERRACE + 1, sz),
			STONE,
			Enum.Material.Slate
		)
		rock.CastShadow = false
		reserve(-198, sz, 14, 14, LY, TERRACE + 3, "the statue's rock")
		place(
			sights,
			SRC.FisherStatue,
			2.0,
			0,
			Vector3.new(-198, TERRACE + 1.8, sz),
			{ over = true }
		)
	end
	for lz = S0 + 30, S1 - 30, 54 do
		try(props, KIT.Prop_store_LampPost, 1.6, facing(side), Vector3.new(-166.6, GY, lz))
	end
	try(props, SRC.Signpost, 1.5, facing(side), Vector3.new(-178, TERRACE, Z0 + 232))
	try(props, SRC.Camp, 1.3, 130, Vector3.new(-184, TERRACE - 0.2, Z0 + 290))
end

-- ================================================================================== the forest
for _, side in { -1, 1 } do
	-- the forest floor: mushrooms, logs, mossy rocks, young trees, bushes, wherever there is room
	local a0, a1 = 178, 232
	scatter({
		parent = trees,
		templates = { SRC.Mushrooms },
		count = if side < 0 then 9 else 5,
		side = side,
		ax = { a0, a1 },
		z = { S0, S1 - 6 },
		scale = { 0.7, 1.3 },
		y = TERRACE - 2.1,
		soft = true,
		sunkOk = 3,
	})
	scatter({
		parent = trees,
		templates = { SRC.FallenLog },
		count = if side < 0 then 4 else 2,
		side = side,
		ax = { a0, a1 },
		z = { S0, S1 - 6 },
		scale = { 1.3, 2.0 },
		y = TERRACE - 0.5,
		soft = true,
	})
	scatter({
		parent = trees,
		templates = { MOSS },
		count = if side < 0 then 6 else 3,
		side = side,
		ax = { a0, a1 },
		z = { S0, S1 - 6 },
		scale = { 0.3, 0.6 },
		y = TERRACE - 1.4,
		soft = true,
		sunkOk = 3,
	})
	scatter({
		parent = trees,
		templates = { JUNGLE.TreeTall, CEDAR },
		count = if side < 0 then 9 else 5,
		side = side,
		ax = { a0, a1 },
		z = { S0, S1 - 6 },
		scale = { 0.8, 1.2 },
		y = TERRACE - 0.8,
		fit = 0.4,
		soft = true,
	})
	scatter({
		parent = trees,
		templates = { JUNGLE.BushLeafy },
		count = if side < 0 then 14 else 8,
		side = side,
		ax = { a0, a1 },
		z = { S0, S1 - 6 },
		scale = { 1.2, 2.0 },
		y = TERRACE - 0.6,
		soft = true,
	})
	-- the ledges: a line of trees and bushes
	for tz = Z0 + 30, Z1 - 6, 24 do
		plant(
			trees,
			if rng:NextNumber() < 0.5 then JUNGLE.TreeBroad else CEDAR,
			side,
			ledgeAx(side) + rng:NextNumber(-8, 8),
			tz + rng:NextNumber(-6, 6),
			rng:NextNumber(0.8, 1.2)
		)
	end
	scatter({
		parent = trees,
		templates = { JUNGLE.BushLeafy, SRC.Mushrooms },
		count = 12,
		side = side,
		ax = { ledgeAx(side) - 11, ledgeAx(side) + 10 },
		z = { Z0 + 30, Z1 },
		scale = { 0.9, 1.7 },
		sink = 1.0,
		soft = true,
		sunkOk = 3,
	})
	-- the rims: two ranks of big trees
	for tz = Z0 + 14, Z1 - 4, 18 do
		local roll = rng:NextNumber()
		local template = if roll < 0.4
			then JUNGLE.TreeBroad
			elseif roll < 0.7 then JUNGLE.TreeTall
			else CEDAR
		plant(
			trees,
			template,
			side,
			rimAx(side) + rng:NextNumber(-6, 10),
			tz + rng:NextNumber(-6, 6),
			rng:NextNumber(1.5, 2.2)
		)
	end
	for tz = Z0 + 24, Z1 - 4, 28 do
		plant(
			trees,
			if rng:NextNumber() < 0.5 then JUNGLE.TreeBroad else JUNGLE.TreeTall,
			side,
			rimAx(side) + rng:NextNumber(28, 48),
			tz + rng:NextNumber(-9, 9),
			rng:NextNumber(1.8, 2.5)
		)
	end
end
drift("rbxassetid://5057182105", Color3.fromRGB(120, 200, 96), Color3.fromRGB(70, 150, 70), 0.1)

floor({
	title = "HUNTER EXAM",
	accent = Color3.fromRGB(214, 44, 52),
	strip = function(tile: number, track: number)
		if (tile + track) % 2 == 0 then
			return Color3.fromRGB(236, 142, 44), Color3.fromRGB(250, 196, 120)
		end
		return Color3.fromRGB(250, 226, 172), Color3.fromRGB(255, 244, 214)
	end,
	kerb = Color3.fromRGB(44, 110, 66),
	paving = Color3.fromRGB(190, 170, 140),
	pavingTex = Color3.fromRGB(224, 208, 184),
})
return finish()
