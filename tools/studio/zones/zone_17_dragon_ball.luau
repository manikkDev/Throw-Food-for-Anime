-- LIB: side_lib
-- zone_17_dragon_ball.luau - zone 17, "Planet of the Gods" (Dragon Ball), on the slim lane (v2,
-- 2026-11-22). z 5920..6280 (map id planet_of_gods, no zone data yet), lane floor y -48, lane edges
-- x +-100: the lane's last zone. Run with
--   python tools/studio/zones/run_zone.py build 17
-- then lane_border.luau and finale.luau. Safe to run again. v1 (zone_lib, the 320-wide lane):
-- MapArchive.Zone17_v1_canyon and tools/studio/retired/zone_17_dragon_ball_v1.luau.
--
-- A warm sea under orange sandstone, and islands in it. Like zone 3, the terrace is real water behind
-- a stone quay; unlike every other zone the sides run on past the lane's end (z 6280) to the end wall
-- (z 6372), so the harbours open into the finale's bay.
--   +X: the little house that is its own island, the tournament arena on a big island with a gangway
--     from the quay, the lookout on its islet, and the seven star balls facing the throwers
--   -X: the dome corporation on its island (capsule cars parked on the gate plaza), the dragon coiling
--     up out of the water, the space pod on its islet, and the stone fighter facing the throwers
--   dome houses, mesas and the god's temple on the shelves, palms, golden clouds in the air, and a
--   waterfall each side into the bay
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local map = workspace.Map
local KIT = RS.Assets.Kit
local SRC = SS.StoreAssets.Zone17_DragonBall
local Z3 = SS.StoreAssets.Zone03_OnePiece
local JUNGLE = SS.StoreAssets.Zone01_Naruto
local ID = "planet_of_gods"
local LY, HALF, Z0, Z1 = P.LY, P.HALF, 5920, 6280
local ZE = 6372 -- the end wall's face (finale.luau): the sides run on to it
local rng = Random.new(17107)

local SURFACE = LY - 1.5 -- the harbour's water, the bay's too (lane_border's END_WATER)
local DECK = LY - 0.4
local QUAY = HALF + 6 -- the quay along the lane (x 100..106); the harbour from here to the wall
local HARBOUR_Z0 = 5972 -- before it, a stone plaza where the gate stands
local HX = (QUAY + P.TERRACE_OUT - P.BATTER) / 2 -- the harbour's middle line (137)
local TOP = LY -- an island's top
local STONE = Color3.fromRGB(226, 214, 190)
local SANDC = Color3.fromRGB(240, 216, 160)
local WET = Color3.fromRGB(214, 190, 138)
local PLANK = Color3.fromRGB(150, 106, 68)
local PLANK_DARK = Color3.fromRGB(92, 62, 44)
local BLUE = Color3.fromRGB(40, 110, 230)
local ORANGE = Color3.fromRGB(222, 150, 88)

local function facing(side: number): number
	return if side > 0 then 90 else -90 -- a squared template fronts to -Z: turn it to the lane
end
local sights: Folder, docks: Folder, props: Folder -- set below, once the zone's folder is cleared
-- a round island in the harbour: a wet shore just over the water, dry sand on top (at TOP)
local function island(x: number, z: number, radius: number)
	cylinder(
		docks,
		"IslandShore",
		(radius + 3) * 2,
		6,
		CFrame.new(x, SURFACE - 2.6, z),
		WET,
		Enum.Material.Sand
	).CastShadow =
		false
	cylinder(docks, "Island", radius * 2, 7, CFrame.new(x, TOP - 3.5, z), SANDC, Enum.Material.Sand).CastShadow =
		false
	claim(rect(x - radius - 3, x + radius + 3, z - radius - 3, z + radius + 3, "Island"))
end
-- a gangway from the quay to an island's shore
local function gangway(side: number, ax1: number, z: number)
	deck(docks, side * QUAY, side * ax1, z - 5, z + 5, DECK, PLANK)
	claim(rect(side * QUAY, side * ax1, z - 5, z + 5, "Gangway"))
end
local function onIsland(template: Instance, scale: number, yaw: number, x: number, z: number): Model
	local m = make(sights, template, scale, yaw, Vector3.new(x, TOP - 0.3, z))
	still(m, true)
	return m
end
local function float(
	template: Instance,
	scale: number,
	yaw: number,
	x: number,
	z: number,
	sink: number
): Model?
	local m = afloat(put(sights, template, scale, yaw, x, z, { y = SURFACE - sink }))
	if m then
		still(m, true)
	end
	return m
end
local SHELF = P.REVET_OUT + 1.5
local function shelf(template: Instance, side: number, scale: number, z: number): Model?
	local m = front(sights, template, side, scale, SHELF, z)
	if m then
		still(m, true)
	end
	return m
end

-- ---------------------------------------------------------------------------------- the zone's folder
local scenery = map.Scenery
local archive = SS:FindFirstChild("MapArchive") or folder(SS, "MapArchive")
if not archive:FindFirstChild("Zone17_v1_canyon") then
	local keep = scenery["Zone_" .. ID]:Clone()
	keep.Name = "Zone17_v1_canyon"
	keep:SetAttribute(
		"Note",
		"Zone 17 (Planet of the Gods) v1 on the 320-wide lane, before the slim-lane rebuild (2026-11-22). Never delete."
	)
	keep.Parent = archive
end
local root = scenery["Zone_" .. ID]
root:ClearAllChildren()
root:SetAttribute(
	"Theme",
	"Planet of the Gods (Dragon Ball), zone_17_dragon_ball.luau v2 on side_lib"
)
local ground = folder(root, "Ground")
sights = folder(root, "Sights")
docks = folder(root, "Docks")
props = folder(root, "Props")
local trees = folder(root, "Trees")
local sky = folder(root, "Sky")

-- ---------------------------------------------------------------------------------- the ground and the harbour
local STYLE = {
	stone = ORANGE,
	material = Enum.Material.Sandstone,
	band = Color3.fromRGB(186, 112, 64),
	cap = STONE,
	capMaterial = Enum.Material.Slate,
	rail = BLUE,
	buttress = 34,
	wet = SURFACE,
}
if DO_TERRAIN then
	sideGround(Z0, ZE, { grass = Enum.Material.Sand })
	for _, s in { -1, 1 } do
		-- the harbour: the terrace's ground cut away, a sand bed and water up to the surface; past the
		-- lane's end it reaches the lane's edge and is the bay's
		for _, seg in { { QUAY, HARBOUR_Z0, Z1 }, { HALF, Z1, ZE } } do
			local a, b =
				math.min(s * seg[1], s * (P.TERRACE_OUT + 1)),
				math.max(s * seg[1], s * (P.TERRACE_OUT + 1))
			-- through side_lib's fill: it moves the x to the two-track lane
			fill(a, b, LY - 24, LY + 16, seg[2], seg[3], Enum.Material.Air)
			fill(a, b, LY - 20, LY - 14, seg[2], seg[3], Enum.Material.Sand)
			fill(a, b, LY - 14, SURFACE, seg[2], seg[3], Enum.Material.Water)
		end
	end
end
claimGates(Z0, Z1)
for _, s in { -1, 1 } do
	-- the quay: pale stone with a blue edge to the lane, a timber edge to the harbour, bollards, lamps
	box(docks, "Quay", s * HALF, s * QUAY, LY - 14, LY + 0.6, Z0, Z1, STONE, Enum.Material.Slate)
	box(
		docks,
		"QuayBand",
		s * HALF,
		s * (HALF + 1),
		LY + 0.6,
		LY + 0.9,
		Z0,
		Z1,
		BLUE,
		Enum.Material.Slate
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
		STONE,
		Enum.Material.Slate,
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
	revetment(ground, s, Z0, ZE, STYLE)
end
-- a waterfall down each wall into the bay, either side of the finale's pier
sheetFall(docks, 1, 6322, 18, SURFACE)
sheetFall(docks, -1, 6330, 18, SURFACE)
claim(rect(148, 168, 6310, 6334, "Waterfall"))
claim(rect(-168, -148, 6318, 6342, "Waterfall"))

-- ================================================================================== +X
float(SRC.IslandHouse, 1.4, facing(1), HX + 3, 6012, 1.5) -- its mesh is its own island
do
	local az = 6074
	island(HX + 2, az, 26)
	gangway(1, HX + 2 - 29, az)
	onIsland(SRC.Arena, 1.25, facing(1), HX + 2, az)
end
do
	local lz = 6146
	island(HX + 3, lz, 16)
	onIsland(SRC.Lookout, 1.0, 0, HX + 3, lz)
end
-- the seven star balls on their island, facing the throw stage
do
	local sz = 6222
	island(HX + 3, sz, 18)
	onIsland(SRC.StarBalls, 2.2, 0, HX + 3, sz)
end

-- ================================================================================== -X
do
	local cz = 6014
	island(-(HX + 2), cz, 26)
	gangway(-1, HX + 2 - 29, cz)
	onIsland(SRC.Corporation, 1.15, facing(-1), -(HX + 2), cz)
	-- its capsule cars, parked on the gate plaza
	for _, c in { { -114, 5934, 0 }, { -161, 5944, 180 } } do
		local car = put(props, SRC.CapsuleCar, 1.2, c[3], c[1], c[2], { y = P.TERRACE_Y + 0.4 })
		if car then
			still(car, false)
		end
	end
end
float(SRC.Dragon, 1.2, facing(-1), -HX, 6082, 3) -- coiling up out of the water
do
	local pz = 6146
	island(-(HX + 3), pz, 15)
	onIsland(SRC.SpacePod, 1.1, 40, -(HX + 3), pz)
end
-- the stone fighter on his island, facing the throw stage
do
	local fz = 6222
	island(-(HX + 3), fz, 18)
	onIsland(SRC.Fighter, 1.45, 0, -(HX + 3), fz)
end

-- ================================================================================== both sides
for _, s in { -1, 1 } do
	-- buoys between the quay and the islands, a rowboat in the bay
	for _, z in if s > 0 then { 6030, 6115, 6183, 6262, 6300 } else { 6060, 6110, 6183, 6266, 6304 } do
		afloat(put(props, Z3.Buoy, 1.2, 0, s * (QUAY + 5), z, { y = SURFACE - 2.4 }))
	end
	afloat(put(props, Z3.Rowboat, 1.8, s * 20, s * (QUAY + 22), 6350, { y = SURFACE - 1.6 }))
	-- the shelves: dome houses, mesas, the god's temple on -X, palms between
	local houses = if s > 0 then { 5992, 6112, 6254 } else { 5998, 6236 }
	for _, z in houses do
		shelf(SRC.DomeHouse, s, 0.9, z)
	end
	local mesas = if s > 0 then { 6052, 6184, 6336 } else { 6066, 6326 }
	for i, z in mesas do
		local m = shelf(SRC.Mesa, s, 0.95 + (i % 2) * 0.15, z)
		if m then
			m:SetAttribute("HangOk", 6)
		end
	end
	if s < 0 then
		shelf(SRC.GodTemple, s, 0.75, 6150)
	end
	scatter({
		parent = trees,
		templates = { Z3.Palm },
		count = 6,
		side = s,
		ax = { 186, 198 },
		z = { Z0 + 20, ZE - 10 },
		scale = { 0.95, 1.2 },
		soft = 4,
	})
	scatter({
		parent = trees,
		templates = { JUNGLE.BushLeafy },
		count = 3,
		side = s,
		ax = { 186, 200 },
		z = { Z0 + 20, ZE - 10 },
		scale = { 1.2, 1.5 },
		soft = 1,
	})
	-- little golden clouds over the harbour
	for i = 1, 5 do
		local c = make(
			sky,
			SRC.Cloud,
			3.0,
			rng:NextInteger(0, 359),
			Vector3.new(
				s * rng:NextNumber(116, 160),
				P.TERRACE_Y + 30 + (i * 7) % 16,
				Z0 + 40 + i * 62 + s * 12
			)
		)
		c:SetAttribute("LaneOk", true)
		still(c, false)
	end
end

-- ---------------------------------------------------------------------------------- the lane's floor
floorKit({
	id = ID,
	title = "PLANET OF THE GODS",
	accent = BLUE,
	strip = function(tile: number, track: number)
		if (tile + track) % 2 == 0 then
			return Color3.fromRGB(244, 122, 32), Color3.fromRGB(252, 178, 104)
		end
		return Color3.fromRGB(250, 196, 64), Color3.fromRGB(255, 228, 150)
	end,
	kerb = BLUE,
	paving = Color3.fromRGB(226, 214, 190),
	pavingTex = Color3.fromRGB(244, 236, 218),
})

-- the border wall stands on this zone's edge right to the end wall (lane_border.luau reads this)
markSlim(root, Z0, 6394)
return string.format(
	"zone 17 Planet of the Gods v2: %d parts\n%s",
	#partsOf(root),
	sideReport(root)
)
