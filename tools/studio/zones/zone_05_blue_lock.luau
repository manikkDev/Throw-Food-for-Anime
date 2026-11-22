-- LIB: side_lib
-- zone_05_blue_lock.luau - zone 5, "Blue Lock Facility" (Blue Lock), on the slim lane (v2, 2026-11-22).
-- z 1600..1960 (config id still hero_city), lane floor y -48, lane edges x +-100. Run with
--   python tools/studio/zones/run_zone.py build 5
-- then lane_border.luau. Safe to run again. v1 (zone_lib, the 320-wide lane): MapArchive.Zone5_v1_canyon
-- and tools/studio/retired/zone_05_blue_lock_v1.luau.
--
-- A stadium. The lane is the pitch (mown stripes, white lines). Each side: a turf touchline with LED
-- boards along the lane, dugouts, practice goals, balls and a camera tower, in front of two roofed
-- grandstands whose backs stand against the revetment; beyond them an end plaza with cyan lines:
--   +X the golden trophy on its plinth, the team bus, the pentagon fortress
--   -X the golden striker in a bicycle kick on his plinth, the scoreboard, the facility
-- On the shelves: BLUE LOCK name boards over the stands, floodlights, a jumbotron, flags, two trees.
local SS = game:GetService("ServerStorage")
local map = workspace.Map
local SRC = SS.StoreAssets.Zone05_BlueLock
local JUNGLE = SS.StoreAssets.Zone01_Naruto
local ID = "hero_city" -- the zone's id in config until the anime zone data lands
local LY, HALF, Z0, Z1 = P.LY, P.HALF, 1600, 1960
local rng = Random.new(5507)

local NAVY = Color3.fromRGB(26, 36, 80)
local BLUE = Color3.fromRGB(34, 120, 236)
local CYAN = Color3.fromRGB(70, 220, 255)
local WHITE = Color3.fromRGB(240, 244, 250)
local STEEL = Color3.fromRGB(60, 70, 110)
local TURF = Color3.fromRGB(64, 156, 76)
local C = Enum.Material.Concrete
local GY = P.TERRACE_Y + 0.4
local LED =
	{ "BLUE LOCK", "EGOIST", "No.1 STRIKER", "GOAL!", "BLUE LOCK", "DEVOUR", "WORLD'S BEST" }

local function facing(side: number): number
	return if side > 0 then 90 else -90 -- a squared template fronts to -Z: turn it to the lane
end
local function setPiece(
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

-- ---------------------------------------------------------------------------------- the zone's folder
local scenery = map.Scenery
local archive = SS:FindFirstChild("MapArchive") or folder(SS, "MapArchive")
if not archive:FindFirstChild("Zone5_v1_canyon") then
	local keep = scenery["Zone_" .. ID]:Clone()
	keep.Name = "Zone5_v1_canyon"
	keep:SetAttribute(
		"Note",
		"Zone 5 (Blue Lock) v1 on the 320-wide lane, before the slim-lane rebuild (2026-11-22). Never delete."
	)
	keep.Parent = archive
end
local root = scenery["Zone_" .. ID]
root:ClearAllChildren()
root:SetAttribute("Theme", "Blue Lock Facility (Blue Lock), zone_05_blue_lock.luau v2 on side_lib")
local ground = folder(root, "Ground")
local stands = folder(root, "Stands")
local sights = folder(root, "Sights")
local props = folder(root, "Props")
local trees = folder(root, "Trees")

-- ---------------------------------------------------------------------------------- the ground
local STYLE = {
	stone = STEEL,
	material = C,
	band = NAVY,
	cap = WHITE,
	capMaterial = C,
	rail = Color3.fromRGB(140, 150, 176),
	buttress = 36,
}
if DO_TERRAIN then
	sideGround(Z0, Z1)
end
claimGates(Z0, Z1)
local STAND = 1.6
local SAX = P.TERRACE_OUT - P.BATTER - 33.3 -- the stands' fronts: their backs on the revetment's foot
local STANDS = { 1693, 1760 } -- the two stands' middles (64 wide each)
local T0, T1 = 1658, 1796 -- the touchline's turf
for _, s in { -1, 1 } do
	box(ground, "Kerb", s * HALF, s * P.KERB_OUT, LY - 2, LY + 3, Z0, Z1, WHITE, C)
	revetment(ground, s, Z0, Z1, STYLE)
	pave(ground, s * P.KERB_OUT, s * (P.TERRACE_OUT - P.BATTER + 0.5), Z0, Z1, GY, NAVY, C, "Plaza")
	pave(
		ground,
		s * P.KERB_OUT,
		s * (SAX - 0.3),
		T0,
		T1,
		GY + 0.1,
		TURF,
		Enum.Material.Grass,
		"Touchline"
	)
	paint(ground, s * 111.6, s * 112.3, T0, T1, WHITE, GY + 0.15)

	-- ------------------------------------------------------------------------------ stands and touchline
	for _, z in STANDS do
		setPiece(stands, SRC.Grandstand, s, STAND, SAX, z)
	end
	-- LED boards down the lane's edge, read from the pitch
	local n = 8
	local seg = (T1 - T0 - 4) / n
	for i = 0, n - 1 do
		local bz = T0 + 2 + (i + 0.5) * seg
		local dark = i % 2 == 0
		local board = sign(
			props,
			LED[(i + (if s > 0 then 0 else 3)) % #LED + 1],
			seg - 2,
			4.4,
			CFrame.new(s * (P.KERB_OUT + 1.6), GY + 2.5, bz)
				* CFrame.Angles(0, math.rad(facing(s)), 0),
			if dark then NAVY else CYAN,
			if dark then CYAN else NAVY
		)
		board.Material = Enum.Material.Neon
		board.Name = "LedBoard"
		block(
			props,
			"LedBoardFoot",
			Vector3.new(1.6, 0.6, seg - 2),
			CFrame.new(s * (P.KERB_OUT + 1.6), GY + 0.3, bz),
			NAVY
		)
	end
	table.insert(claims, rect(s * P.KERB_OUT, s * (P.KERB_OUT + 3), T0, T1, "LedBoards"))
	-- a dugout in front of each stand with training kit beside it; a camera tower where they meet
	for _, z in STANDS do
		setPiece(props, SRC.Dugout, s, 1.6, SAX - 9.4, z)
		for _, dz in { -20, 20 } do
			local t = put(props, SRC.TrainingSet, 1.3, 0, s * (SAX - 7), z + dz)
			if t then
				still(t, false)
			end
		end
	end
	setPiece(props, SRC.CameraTower, s, 1.15, SAX - 12, (STANDS[1] + STANDS[2]) / 2)
	-- practice goals at the touchline's ends, facing each other; balls about
	for _, g in { { T0 + 6, 0 }, { T1 - 6, 180 } } do
		local goal = put(props, SRC.Goal, 1.25, g[2], s * 116, g[1])
		if goal then
			still(goal, false)
		end
	end
	for _ = 1, 8 do
		still(
			make(
				props,
				SRC.Football,
				0.16,
				rng:NextInteger(0, 359),
				Vector3.new(
					s * rng:NextNumber(110, SAX - 16),
					GY + 0.1,
					rng:NextNumber(T0 + 14, T1 - 14)
				)
			),
			false
		)
	end

	-- ------------------------------------------------------------------------------ the end plaza
	local e0 = T1 + 4
	for _, r in
		{ { 106, 166, e0, e0 + 0.8 }, { 106, 166, Z1 - 4.8, Z1 - 4 }, { 106, 106.8, e0, Z1 - 4 } }
	do
		paint(ground, s * r[1], s * r[2], r[3], r[4], CYAN, GY).Material = Enum.Material.Neon
	end
	local px, pz = s * 142, 1836
	local radius = if s > 0 then 13 else 14
	local plinth = cylinder(sights, "Plinth", radius * 2, 3, CFrame.new(px, GY + 1.5, pz), NAVY, C)
	plinth.CastShadow = false
	cylinder(
		sights,
		"PlinthGlow",
		radius * 2 + 1.2,
		0.5,
		CFrame.new(px, GY + 3.1, pz),
		CYAN,
		Enum.Material.Neon
	)
	claim(rect(px - radius - 1, px + radius + 1, pz - radius - 1, pz + radius + 1, "Plinth"))
	if s > 0 then
		still(make(sights, SRC.Trophy, 1.2, 0, Vector3.new(px, GY + 3.2, pz)), true)
		local bus = put(props, SRC.TeamBus, 1.15, 0, 112, 1884, { free = true })
		if bus then
			still(bus, false)
		end
		setPiece(sights, SRC.Fortress, s, 0.85, 128.5, 1915)
	else
		still(make(sights, SRC.StrikerStatue, 1.0, 0, Vector3.new(px, GY + 3.2, pz)), true)
		setPiece(sights, SRC.Scoreboard, s, 1.0, 152, 1872)
		setPiece(sights, SRC.Facility, s, 0.85, 130.5, 1914)
	end

	-- ------------------------------------------------------------------------------ the shelf
	local SHELF = P.REVET_OUT + 1.5
	for _, z in STANDS do
		local ax = SHELF + 4
		local board = sign(
			props,
			"BLUE LOCK",
			54,
			11,
			CFrame.new(s * ax, P.SHELF_Y + 11, z) * CFrame.Angles(0, math.rad(facing(s)), 0),
			NAVY,
			CYAN
		)
		board.Name = "NameBoard"
		block(
			props,
			"NameBoardEdge",
			Vector3.new(1.2, 12.2, 55.2),
			CFrame.new(s * (ax + 0.5), P.SHELF_Y + 11, z),
			CYAN,
			Enum.Material.Neon
		)
		for _, dz in { -22, 22 } do
			block(
				props,
				"NameBoardLeg",
				Vector3.new(1.6, 6, 1.6),
				CFrame.new(s * (ax + 0.4), P.SHELF_Y + 2.5, z + dz),
				STEEL,
				Enum.Material.Metal
			)
		end
		claim(rect(s * (ax - 1), s * (ax + 2), z - 28, z + 28, "NameBoard"))
	end
	for _, z in { 1650, 1806 } do
		setPiece(props, SRC.Floodlight, s, 1.15, SHELF + 6, z)
	end
	setPiece(props, SRC.Jumbotron, s, 0.95, SHELF + 6, 1880)
	-- a flag between the name boards, two trees beyond them
	do
		local fz = (STANDS[1] + STANDS[2]) / 2
		local fx = s * (SHELF + 3)
		cylinder(
			props,
			"FlagPole",
			0.9,
			28,
			CFrame.new(fx, P.SHELF_Y + 14, fz),
			WHITE,
			Enum.Material.Metal
		).CastShadow =
			false
		block(
			props,
			"Flag",
			Vector3.new(0.3, 7, 11),
			CFrame.new(fx, P.SHELF_Y + 24, fz + 6),
			if s > 0 then BLUE else CYAN
		).CastShadow =
			false
	end
	for _, z in { 1838, 1938 } do
		local t = put(
			trees,
			JUNGLE.TreeBroad,
			0.9,
			rng:NextInteger(0, 3) * 90,
			s * 192,
			z,
			{ soft = 3.6 }
		)
		if t then
			still(t, false)
		end
	end
end

-- ---------------------------------------------------------------------------------- the lane's floor
floorKit({
	id = ID,
	title = "BLUE LOCK",
	accent = Color3.fromRGB(30, 144, 255),
	strip = function(tile: number, _track: number)
		if tile % 2 == 0 then
			return Color3.fromRGB(60, 158, 70), Color3.fromRGB(120, 204, 120)
		end
		return Color3.fromRGB(88, 188, 92), Color3.fromRGB(150, 224, 150)
	end,
	kerb = WHITE,
	paving = Color3.fromRGB(44, 70, 140),
	pavingTex = Color3.fromRGB(110, 140, 210),
})

markSlim(root, Z0, Z1)
return string.format("zone 5 Blue Lock v2: %d parts\n%s", #partsOf(root), sideReport(root))
