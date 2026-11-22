-- LIB: side_lib
-- zone_09_titan.luau - zone 9, "Wall Maria" (Attack on Titan), on the slim lane (v2, 2026-11-22).
-- z 3040..3400 (map id wall_maria, no zone data yet), lane floor y -48, lane edges x +-100. Run with
--   python tools/studio/zones/run_zone.py build 9
-- then lane_border.luau. Safe to run again. v1 (zone_lib, the 320-wide lane): MapArchive.Zone9_v1_canyon
-- and tools/studio/retired/zone_09_titan_v1.luau.
--
-- A town inside the Walls. The revetment IS the Wall here: masonry with buttresses and a crenellated
-- parapet along the shelf, cannons and green banners on the shelf behind it. A cobbled street below.
--   +X, the town: town houses, the bakery with its well and a supply wagon, the great gate set in the
--     Wall, and the soldier's monument on its plinth facing the throwers
--   -X, the garrison: the bell tower, the headquarters, the stables, a house, and the training ground
--     with its giant-shaped dummies; above it a bastion of the Wall, and the colossal giant looking over
--     it at the lane
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local map = workspace.Map
local KIT = RS.Assets.Kit
local SRC = SS.StoreAssets.Zone09_Titan
local ID = "wall_maria"
local LY, HALF, Z0, Z1 = P.LY, P.HALF, 3040, 3400
local rng = Random.new(9907)

local COBBLE = Color3.fromRGB(168, 156, 140)
local STONE = Color3.fromRGB(146, 134, 118)
local DARK = Color3.fromRGB(108, 98, 86)
local GREEN = Color3.fromRGB(52, 112, 70)
local WOOD = Color3.fromRGB(104, 74, 50)
local B = Enum.Material.Brick
local GY = P.TERRACE_Y + 0.4

local function facing(side: number): number
	return if side > 0 then 90 else -90 -- a squared template fronts to -Z: turn it to the lane
end
local sights: Folder, props: Folder -- set below, once the zone's folder is cleared
local function sight(
	template: Instance,
	side: number,
	scale: number,
	ax: number,
	z: number,
	opts: any?
): Model?
	local m = front(sights, template, side, scale, ax, z, opts)
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

-- ---------------------------------------------------------------------------------- the zone's folder
local scenery = map.Scenery
local archive = SS:FindFirstChild("MapArchive") or folder(SS, "MapArchive")
if not archive:FindFirstChild("Zone9_v1_canyon") then
	local keep = scenery["Zone_" .. ID]:Clone()
	keep.Name = "Zone9_v1_canyon"
	keep:SetAttribute(
		"Note",
		"Zone 9 (Wall Maria) v1 on the 320-wide lane, before the slim-lane rebuild (2026-11-22). Never delete."
	)
	keep.Parent = archive
end
local root = scenery["Zone_" .. ID]
root:ClearAllChildren()
root:SetAttribute("Theme", "Wall Maria (Attack on Titan), zone_09_titan.luau v2 on side_lib")
local ground = folder(root, "Ground")
local masonry = folder(root, "Masonry")
sights = folder(root, "Sights")
props = folder(root, "Props")

-- ---------------------------------------------------------------------------------- the ground and the Wall
local STYLE =
	{ stone = STONE, material = B, band = DARK, cap = STONE, capMaterial = B, buttress = 40 }
if DO_TERRAIN then
	sideGround(Z0, Z1)
end
claimGates(Z0, Z1)
local BASTION_Z0, BASTION_Z1 = 3292, 3352 -- the -X bastion over the training ground
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
		Color3.fromRGB(112, 82, 54),
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
	-- the Wall's parapet: merlons along the shelf's edge (none where the bastion stands)
	for mz = Z0 + 7, Z1 - 5, 12 do
		if s > 0 or mz < BASTION_Z0 - 4 or mz > BASTION_Z1 + 4 then
			box(
				masonry,
				"Merlon",
				s * (P.REVET_OUT - 3.2),
				s * P.REVET_OUT,
				P.SHELF_Y + 1.2,
				P.SHELF_Y + 5.2,
				mz - 3,
				mz + 3,
				STONE,
				B
			)
		end
	end
	-- a plinth course at the Wall's foot
	box(
		masonry,
		"Plinth",
		s * (P.TERRACE_OUT - P.BATTER - 1.5),
		s * (P.TERRACE_OUT - P.BATTER + 1),
		GY - 0.4,
		GY + 4,
		Z0,
		Z1,
		DARK,
		B
	)
end
local lamp = KIT:FindFirstChild("Prop_store_LampPost")

-- ================================================================================== +X: the town
sight(SRC.TownHouse, 1, 1.4, 139, 3112)
sight(SRC.Bakery, 1, 1.5, 142, 3150)
sight(SRC.TownHouse, 1, 1.3, 141.5, 3186)
-- the great gate set in the Wall
sight(SRC.WallGate, 1, 1.4, 140, 3240)
prop(SRC.Well, 1.3, 129, 3150, 0)
prop(SRC.Wagon, 1.4, 126, 3190, 12)
prop(KIT:FindFirstChild("Prop_store_Barrel"), 1.5, 132, 3132, 0)
prop(KIT:FindFirstChild("Prop_store_Crate"), 1.5, 132, 3168, 30)
prop(KIT:FindFirstChild("Prop_pirate_harbor_BarrelStack"), 1.3, 130, 3218, 20)
-- the soldier's monument on its plinth, facing the throw stage
do
	local sx, sz = 142, 3330
	for i, r in { 16, 12.5 } do
		cylinder(
			sights,
			"MonumentPlinth",
			r * 2,
			1.4,
			CFrame.new(sx, GY + i * 1.3 - 0.6, sz),
			STONE,
			Enum.Material.Slate
		).CastShadow =
			false
	end
	claim(rect(sx - 17, sx + 17, sz - 17, sz + 17, "MonumentPlinth"))
	still(make(sights, SRC.Soldier, 1.4, 0, Vector3.new(sx, GY + 2.6, sz)), true)
end

-- ================================================================================== -X: the garrison
sight(SRC.BellTower, -1, 1.3, 141.5, 3114)
sight(SRC.Barracks, -1, 1.3, 136.5, 3158)
sight(SRC.Stable, -1, 1.6, 139, 3203)
sight(SRC.TownHouse, -1, 1.3, 141.5, 3240)
prop(SRC.Wagon, 1.4, -126, 3150, -10)
prop(KIT:FindFirstChild("Prop_store_Crate"), 1.5, -126, 3176, 20)
prop(SS.StoreAssets.Zone06_BlackClover:FindFirstChild("HayCart"), 1.4, -128, 3203, 200)
-- the training ground: giant-shaped dummies, a fence along the street, weapon crates
do
	local t0, t1 = 3268, 3394
	for i, dz in { 3292, 3322, 3352 } do
		prop(SRC.Dummy, 1.3, -148 + (i % 2) * 4, dz, 0)
	end
	fence(props, -(P.STREET_OUT + 4), t0, -(P.STREET_OUT + 4), t1, GY, 3.4, WOOD, 8)
	table.insert(claims, rect(-(P.STREET_OUT + 3), -(P.STREET_OUT + 5), t0, t1, "Fence"))
	prop(KIT:FindFirstChild("Prop_store_Crate"), 1.5, -128, 3280, 10)
	prop(KIT:FindFirstChild("Prop_pirate_harbor_BarrelStack"), 1.3, -136, 3372, 60)
end
-- the bastion of the Wall over the training ground, and the giant looking over it at the lane: only
-- its head, shoulders and hands show over the bastion
do
	local x0, x1 = P.TERRACE_OUT - P.BATTER, P.REVET_OUT + 9
	local top = P.SHELF_Y + 22
	box(masonry, "Bastion", -x0, -x1, LY - 2, top, BASTION_Z0, BASTION_Z1, STONE, B)
	box(
		masonry,
		"BastionPlinth",
		-(x0 - 1.5),
		-(x1 + 0.5),
		LY - 2,
		GY + 6,
		BASTION_Z0 - 1.5,
		BASTION_Z1 + 1.5,
		DARK,
		B
	)
	for _, y in { GY + 22, P.SHELF_Y + 8 } do
		box(
			masonry,
			"BastionCourse",
			-(x0 - 0.8),
			-(x1 + 0.4),
			y,
			y + 2.4,
			BASTION_Z0 - 0.8,
			BASTION_Z1 + 0.8,
			DARK,
			B
		)
	end
	for mz = BASTION_Z0 + 4, BASTION_Z1 - 4, 10 do
		box(masonry, "BastionMerlon", -x0, -(x0 + 4), top, top + 4.5, mz - 2.5, mz + 2.5, STONE, B)
	end
	claim(rect(-x0, -P.WALL_IN, BASTION_Z0, BASTION_Z1, "Bastion"))
	local giant = make(
		sights,
		SRC.Colossus,
		1.5,
		facing(-1),
		Vector3.new(-(P.REVET_OUT + 16), P.SHELF_Y - 6, (BASTION_Z0 + BASTION_Z1) / 2)
	)
	giant:SetAttribute("LaneOk", true)
	still(giant, true)
end

-- ================================================================================== the street and the walkway
for _, s in { -1, 1 } do
	for z = 3110, Z1 - 20, 46 do
		if lamp then
			prop(lamp, 1.5, s * (P.STREET_OUT + 2.5), z, facing(s))
		end
	end
	-- cannons on the walkway behind the parapet, muzzles to the lane; a green banner between each pair
	for cz = Z0 + 60, Z1 - 30, 56 do
		local c = prop(SRC.Cannon, 1.0, s * (P.REVET_OUT + 9), cz, facing(s))
		local fz = cz + 28
		local fx = s * (P.REVET_OUT + 5)
		if claim(rect(fx - 1.5, fx + 1.5, fz - 1, fz + 9, "Banner")) then
			cylinder(
				props,
				"BannerPole",
				1,
				26,
				CFrame.new(fx, P.SHELF_Y + 13, fz),
				WOOD,
				Enum.Material.Wood
			).CastShadow =
				false
			block(
				props,
				"Banner",
				Vector3.new(0.4, 13, 8),
				CFrame.new(fx, P.SHELF_Y + 19, fz + 4.6),
				GREEN,
				Enum.Material.Fabric
			).CastShadow =
				false
		end
		local _ = c
	end
end

-- ---------------------------------------------------------------------------------- the lane's floor
floorKit({
	id = ID,
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

markSlim(root, Z0, Z1)
local _ = rng
return string.format("zone 9 Wall Maria v2: %d parts\n%s", #partsOf(root), sideReport(root))
