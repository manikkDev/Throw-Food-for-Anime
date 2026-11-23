-- LIB: side_lib
-- zone_01_naruto.luau - zone 1, "Hidden Leaf Village" (Naruto), on the slim lane (v2, 2026-11-22).
-- z 160..520, lane floor y -48, lane edges x +-100. Run with
--   python tools/studio/zones/run_zone.py build 1
-- (joins side_lib.luau in front: P, sideGround, revetment, front, put, ...). Safe to run again: it
-- clears Map.Scenery.Zone_sakura_schoolyard and rebuilds it. Then run lane_border.luau (the border
-- wall) and lobby_wall.luau (the lobby's corner beside the gate tower).
--
-- v1 (the owner's approved bar) stood in a clay terrain canyon 56..80 studs above a 320-wide lane;
-- the owner then asked for the map smaller and the clay gone, the buildings and props kept and laid
-- out properly, few trees (2026-11-22). The picture now, from the lobby inwards:
--   * THE ENTRANCE, built: the ledge's retaining wall from the throw stage to two gate towers (castle
--     keeps on stone plinths, x 160..217) that flank the zone's torii; the village's great wall from
--     each tower out to the lobby wall, its foot in the sea
--   * the gate's two green leaves ("a" and "n") on their own posts behind the torii's pillars
--   * +X, the village: houses, the tower, the residence and the hall in a row along the street, a
--     second row of small houses on the shelf over the stone revetment
--   * -X, the Hokage Rock: four stone heads carved in a built rock cliff that rises from the shelf,
--     a training ground and a ramen stand at its foot, low so the heads stay in view
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local map = workspace.Map
local KIT = RS.Assets.Kit
local SRC = SS.StoreAssets.Zone01_Naruto
local ID = "sakura_schoolyard" -- the zone's id in config until the anime zone data lands
local LY, HALF, Z0, Z1 = P.LY, P.HALF, 160, 520
local TOWER_IN, TW, TD, PLINTH = 160, 57, 66, 14 -- the gate towers: x 160..217, z 167..233
local TOWER_OUT = TOWER_IN + TW
local BACK = 234 -- the towers' backs: the terrace's buildings and the shelf start here
-- the lobby wall's outer face (world x 262): the great wall runs from the tower to it. The lobby kept
-- its width when the lane went to two tracks, so in this file's frame it is SHIFT further out
local LOBBY_OUT = 262 + P.SHIFT
local rng = Random.new(1107)

local DECAL_A = "rbxassetid://3768467328" -- the gate's kana
local DECAL_N = "rbxassetid://3768465254"
local DECAL_LEAF = "rbxassetid://3786177973" -- the village emblem
local GREEN = Color3.fromRGB(62, 142, 65)
local GREEN_DARK = Color3.fromRGB(38, 98, 48)
local WOOD_DARK = Color3.fromRGB(74, 50, 38)
local STONE = Color3.fromRGB(186, 170, 150)
local STONE_DARK = Color3.fromRGB(140, 126, 112)
local PLASTER = Color3.fromRGB(246, 234, 204)
local ROOF = Color3.fromRGB(196, 84, 58)
local ROOF_DARK = Color3.fromRGB(142, 56, 44)
local RED = Color3.fromRGB(196, 52, 46)
local ROCK = Color3.fromRGB(176, 150, 120) -- the Hokage Rock: warm sandstone
local ROCK_DARK = Color3.fromRGB(132, 108, 84)
local STREET = Color3.fromRGB(198, 182, 156)
local PLASTER_M, STONE_M = Enum.Material.Plaster, Enum.Material.Brick

-- ---------------------------------------------------------------------------------- helpers
local function gable(parent: Instance, at: CFrame, length: number, half: number, height: number)
	for _, s in { -1, 1 } do
		-- a wedge is thick at its +Z end: turn the thick end to the ridge
		local turn = if s > 0 then CFrame.Angles(0, math.pi, 0) else CFrame.new()
		block(
			parent,
			"Roof",
			Vector3.new(length, height, half),
			at * CFrame.new(0, height / 2, s * half / 2) * turn,
			ROOF,
			Enum.Material.ClayRoofTiles,
			"WedgePart"
		).CastShadow =
			true
	end
	block(
		parent,
		"Ridge",
		Vector3.new(length + 1.5, 1.8, 2.4),
		at * CFrame.new(0, height + 0.4, 0),
		ROOF_DARK,
		Enum.Material.Wood
	)
	block(
		parent,
		"Eave",
		Vector3.new(length + 2, 1.4, half * 2 + 3),
		at * CFrame.new(0, -0.7, 0),
		ROOF_DARK,
		Enum.Material.Wood
	)
end
local function banner(parent: Instance, at: CFrame, width: number, height: number)
	-- a red cloth with the village emblem; at's -Z is the side it is read from
	local cloth =
		block(parent, "Banner", Vector3.new(width, height, 0.3), at, RED, Enum.Material.Fabric)
	local d = Instance.new("Decal")
	d.Texture = DECAL_LEAF
	d.Face = Enum.NormalId.Front
	d.Parent = cloth
	block(
		parent,
		"BannerRod",
		Vector3.new(width + 3, 0.9, 0.9),
		at * CFrame.new(0, height / 2 + 0.5, 0),
		WOOD_DARK,
		Enum.Material.Wood
	)
end
local function facing(side: number): number
	return if side > 0 then 90 else -90 -- a squared template fronts to -Z: turn it to the lane
end

-- ---------------------------------------------------------------------------------- the zone's folder
local scenery = map.Scenery
local archive = SS:FindFirstChild("MapArchive") or folder(SS, "MapArchive")
if not archive:FindFirstChild("Zone1_v1_canyon") then
	-- v1 (the canyon, the owner's approved bar), once: never delete
	local keep = scenery["Zone_" .. ID]:Clone()
	keep.Name = "Zone1_v1_canyon"
	keep:SetAttribute(
		"Note",
		"Zone 1 (Hidden Leaf) v1, in its clay canyon, before the slim-lane rebuild (2026-11-22). Never delete."
	)
	keep.Parent = archive
end
local root = scenery["Zone_" .. ID]
root:ClearAllChildren()
root:SetAttribute("Theme", "Hidden Leaf Village (Naruto), zone_01_naruto.luau v2 on side_lib")
local entrance = folder(root, "Entrance")
local ground = folder(root, "Ground")
local buildings = folder(root, "Buildings")
local monument = folder(root, "Monument")
local gate = folder(root, "Gate")
local props = folder(root, "Props")
local trees = folder(root, "Trees")

-- ---------------------------------------------------------------------------------- the ground
local STYLE = {
	stone = STONE,
	material = Enum.Material.Cobblestone,
	band = STONE_DARK,
	cap = STONE_DARK,
	rail = WOOD_DARK,
}
-- the Hokage Rock takes the -X revetment's place over these z
local ROCK_Z0, ROCK_Z1 = 316, 496
if DO_TERRAIN then
	sideGround(166, Z1, { shelfFrom = BACK })
end
claimGates(Z0, Z1)
for _, s in { -1, 1 } do
	box(
		ground,
		"Kerb",
		s * HALF,
		s * P.KERB_OUT,
		LY - 2,
		LY + 3,
		166,
		Z1,
		STONE_DARK,
		Enum.Material.Slate
	)
	pave(
		ground,
		s * P.KERB_OUT,
		s * P.STREET_OUT,
		166,
		Z1,
		P.TERRACE_Y + 0.4,
		STREET,
		Enum.Material.Cobblestone,
		"Street"
	)
	-- (claimed outright: the torii's pillars stand on the street by design)
	table.insert(claims, rect(s * HALF, s * P.STREET_OUT, 166, Z1, "Street"))
	if s > 0 then
		revetment(ground, s, BACK, Z1, STYLE)
	else
		revetment(ground, s, BACK, ROCK_Z0 - 12, STYLE)
		revetment(ground, s, ROCK_Z1 + 12, Z1, STYLE)
	end
	-- nothing on the terrace between the towers' backs and the lane: the torii and the lions
	table.insert(claims, rect(s * P.STREET_OUT, s * TOWER_IN, 166, BACK, "GateCourt"))
	claim(rect(s * TOWER_IN, s * P.WALL_OUT, 166, BACK, "GateTower"))
end

-- ---------------------------------------------------------------------------------- the entrance
local WALL_MID = 196 -- the great wall's centre line
for _, side in { -1, 1 } do
	local function X(ax: number): number
		return side * ax
	end
	-- the ledge's retaining wall carries on from the stage to the tower, and turns in to meet it
	local top = 1.3
	block(
		entrance,
		"LedgeWing",
		Vector3.new(TOWER_IN - (HALF + 2), top - LY + 2, 6),
		CFrame.new(X((HALF + 2 + TOWER_IN) / 2), (top + LY - 2) / 2, 163),
		STONE,
		STONE_M
	)
	block(
		entrance,
		"LedgeWingCap",
		Vector3.new(TOWER_IN - HALF, 2.2, 8),
		CFrame.new(X((HALF + TOWER_IN) / 2), top + 1.1, 163),
		STONE_DARK,
		Enum.Material.Slate
	)
	-- the gate tower: a castle keep (generated mesh, 44 x 56 x 38) on a stone plinth
	local tx, tz = X(TOWER_IN + TW / 2), 200
	local tower = Instance.new("Model")
	tower.Name = "GateTower"
	block(
		tower,
		"Plinth",
		Vector3.new(TW, PLINTH - LY + 2, TD),
		CFrame.new(tx, (PLINTH + LY - 2) / 2, tz),
		STONE,
		STONE_M
	)
	block(
		tower,
		"PlinthBand",
		Vector3.new(TW + 3, 3, TD + 3),
		CFrame.new(tx, PLINTH - 1.5, tz),
		STONE_DARK,
		Enum.Material.Slate
	)
	local keep = make(tower, SRC.GateTowerMesh, 1.5, facing(side), Vector3.new(tx, PLINTH, tz))
	still(keep, true)
	banner(tower, CFrame.new(tx, -12, tz + TD / 2 + 0.4) * CFrame.Angles(0, math.pi, 0), 18, 26)
	tower.Parent = entrance
	-- the great wall, from the tower out to the lobby wall (which runs into its end); its foot in the sea
	local x0, x1 = TOWER_OUT, LOBBY_OUT
	local len, mid = x1 - x0, X((x0 + x1) / 2)
	local wall = Instance.new("Model")
	wall.Name = "GreatWall"
	block(wall, "Foot", Vector3.new(len, 72, 14), CFrame.new(mid, -8, WALL_MID), STONE, STONE_M)
	block(
		wall,
		"FootBand",
		Vector3.new(len, 2.4, 16),
		CFrame.new(mid, 29.2, WALL_MID),
		STONE_DARK,
		Enum.Material.Slate
	)
	block(
		wall,
		"Body",
		Vector3.new(len, 14, 11),
		CFrame.new(mid, 37.4, WALL_MID),
		PLASTER,
		PLASTER_M
	)
	for i = 0, 2 do
		block(
			wall,
			"Post",
			Vector3.new(2, 14, 11.8),
			CFrame.new(X(x0 + 4 + i * (len - 8) / 2), 37.4, WALL_MID),
			WOOD_DARK,
			Enum.Material.Wood
		)
	end
	gable(wall, CFrame.new(mid, 45.1, WALL_MID), len, 10, 7)
	banner(wall, CFrame.new(mid, 36.6, WALL_MID - 5.8), 9, 11)
	wall.Parent = entrance
end
local ledgeWall = map.HubV2:FindFirstChild("LedgeWall")
if ledgeWall and ledgeWall:IsA("BasePart") then
	ledgeWall.Color = STONE -- one wall from tower to tower
	ledgeWall.Material = STONE_M
end
-- seen from the lane, the ledge is one long wall under the throw stage: piers, and the emblem
-- (world x: inside the old lane nothing is moved; the two-track ledge is 148 wide)
for _, x in { -68, -30, 30, 68 } do
	-- they stop 5 below the lip: any higher and the thrower sees their tops past the stage's edge
	block(
		entrance,
		"LedgePier",
		Vector3.new(9, -4 - LY + 2, 3),
		CFrame.new(x, (-4 + LY - 2) / 2, 166.4),
		STONE_DARK,
		STONE_M
	)
end
banner(entrance, CFrame.new(0, -20, 166.2) * CFrame.Angles(0, math.pi, 0), 44, 36)
for _, x in { -49, 49 } do
	banner(entrance, CFrame.new(x, -22, 166.2) * CFrame.Angles(0, math.pi, 0), 20, 28)
end

-- ---------------------------------------------------------------------------------- the gate's leaves
-- On their own posts behind the torii's pillars, swung open and angled in towards the lane so the
-- kana reads from the lobby and from the throw stage.
local LEAF_POST, LEAF_FREE = Vector3.new(128, LY, 248), Vector3.new(110, LY + 4, 312)
local function leaf(side: number, kana: string)
	local m = Instance.new("Model")
	m.Name = "GateLeaf"
	local tall = 46
	local post = Vector3.new(side * LEAF_POST.X, LEAF_POST.Y, LEAF_POST.Z)
	block(
		m,
		"PostFoot",
		Vector3.new(15, 12, 15),
		CFrame.new(post + Vector3.new(0, 6, 0)),
		STONE,
		STONE_M
	)
	block(
		m,
		"Post",
		Vector3.new(11, tall + 2, 11),
		CFrame.new(post + Vector3.new(0, 12 + (tall + 2) / 2, 0)),
		PLASTER,
		PLASTER_M
	)
	block(
		m,
		"PostBelt",
		Vector3.new(12.2, 2, 12.2),
		CFrame.new(post + Vector3.new(0, tall + 4, 0)),
		WOOD_DARK,
		Enum.Material.Wood
	)
	gable(m, CFrame.new(post + Vector3.new(0, tall + 14.7, 0)), 18, 9, 6)
	local hinge = post + Vector3.new(-side * 4, 4, 7)
	local free = Vector3.new(side * LEAF_FREE.X, LEAF_FREE.Y, LEAF_FREE.Z)
	local len = (free - hinge).Magnitude
	local along = (free - hinge).Unit
	local out = along:Cross(Vector3.new(0, 1, 0)) * side -- towards the lane
	local at = CFrame.fromMatrix(
		(hinge + free) / 2 + Vector3.new(0, tall / 2, 0),
		out,
		Vector3.new(0, 1, 0),
		out:Cross(Vector3.new(0, 1, 0))
	)
	block(m, "Leaf", Vector3.new(2.6, tall, len), at, GREEN, Enum.Material.WoodPlanks)
	for _, y in { 2.5 - tall / 2, tall / 2 - 2.5 } do
		block(
			m,
			"Rail",
			Vector3.new(3.8, 5, len + 1.6),
			at * CFrame.new(0, y, 0),
			GREEN_DARK,
			Enum.Material.Wood
		)
	end
	for _, z in { -len / 2, len / 2 } do
		block(
			m,
			"Stile",
			Vector3.new(3.8, tall, 5),
			at * CFrame.new(0, 0, z),
			GREEN_DARK,
			Enum.Material.Wood
		)
	end
	for _, y in { 10, tall - 6 } do
		cylinder(
			m,
			"Hinge",
			4,
			6,
			CFrame.new(hinge + Vector3.new(0, y, 0)),
			Color3.fromRGB(40, 42, 48),
			Enum.Material.Metal
		)
	end
	local panel = block(
		m,
		"Kana",
		Vector3.new(0.2, 36, 33),
		at * CFrame.new(1.5, 0, 0),
		GREEN,
		Enum.Material.SmoothPlastic
	)
	panel.Transparency = 1
	local d = Instance.new("Decal")
	d.Texture = kana
	d.Face = Enum.NormalId.Right
	d.Parent = panel
	m.Parent = gate
	claim(rect(
		side * P.STREET_OUT, -- the leaf swings out over the street (claimed already)
		side * (LEAF_POST.X + 8),
		LEAF_POST.Z - 8,
		LEAF_FREE.Z + 4,
		"GateLeaf"
	))
end
leaf(1, DECAL_A) -- from the throw stage +X is on the left: "a" hangs on the left, as on the real gate
leaf(-1, DECAL_N)

-- ---------------------------------------------------------------------------------- the Hokage Rock
-- A built cliff on -X between the revetments, never terrain: vertical facets of layered sandstone
-- (Slate in three warm tones), each a little forward or back, taller or shorter, a little turned;
-- each head set half into the rock in its own darker alcove, standing on a ledge; a jagged crown with
-- moss and bushes; ends that step down to the shelf.
do
	local m = Instance.new("Model")
	m.Name = "HokageRock"
	local s = -1
	local TOP, LEDGE = 12, -32
	local x0 = P.TERRACE_OUT - 4 -- the face line (168)
	local SAND = {
		Color3.fromRGB(206, 170, 126),
		Color3.fromRGB(190, 152, 110),
		Color3.fromRGB(218, 184, 140),
	}
	local ALCOVE = Color3.fromRGB(150, 116, 82)
	local SLATE = Enum.Material.Slate
	local HEADS = { "Head4_Bangs", "Head3_Goatee", "Head2_FaceGuard", "Head1_LongHair" }
	local step = (ROCK_Z1 - ROCK_Z0) / #HEADS
	local function headAt(z: number): boolean
		for i = 1, #HEADS do
			if math.abs(z - (ROCK_Z0 + (i - 0.5) * step)) < 17 then
				return true
			end
		end
		return false
	end
	-- the core, set back: the facets hide it
	box(m, "Core", s * (x0 + 6), s * P.WALL_IN, LY - 2, TOP - 4, ROCK_Z0, ROCK_Z1, SAND[2], SLATE)
	local z = ROCK_Z0
	while z < ROCK_Z1 - 0.5 do
		local zz = math.min(z + rng:NextNumber(8, 13), ROCK_Z1)
		local mid = (z + zz) / 2
		local alcove = headAt(mid)
		local face = x0 + (if alcove then 7 else rng:NextNumber(-1.5, 1.5))
		local depth = P.WALL_IN - face - rng:NextNumber(2, 10)
		local top = if alcove then TOP - rng:NextNumber(0, 3) else TOP + rng:NextNumber(-2, 9)
		block(
			m,
			if alcove then "Alcove" else "Facet",
			Vector3.new(depth, top - LY + 2, zz - z + 1.2),
			CFrame.new(s * (face + depth / 2), (top + LY - 2) / 2, mid)
				* CFrame.Angles(
					0,
					math.rad(rng:NextNumber(-4, 4)),
					math.rad(s * rng:NextNumber(-3, 1))
				),
			if alcove then ALCOVE else SAND[rng:NextInteger(1, #SAND)],
			SLATE
		)
		if zz >= ROCK_Z1 then
			break -- the last facet: (zz - 1) never passes the limit (that froze Studio twice)
		end
		z = zz - 1
	end
	box(
		m,
		"Ledge",
		s * (x0 - 12),
		s * (x0 + 1),
		LY - 2,
		LEDGE,
		ROCK_Z0 + 4,
		ROCK_Z1 - 4,
		ALCOVE,
		SLATE
	)
	box(
		m,
		"LedgeLip",
		s * (x0 - 12.6),
		s * (x0 - 11),
		LEDGE - 2.5,
		LEDGE + 0.6,
		ROCK_Z0 + 4,
		ROCK_Z1 - 4,
		SAND[2],
		SLATE
	)
	-- the crown: jagged blocks of rock along the top, set back from the face
	z = ROCK_Z0 + 2
	while z < ROCK_Z1 - 6 do
		local w = rng:NextNumber(10, 20)
		local h = rng:NextNumber(4, 12)
		local cx = x0 + rng:NextNumber(10, 22)
		block(
			m,
			"Crown",
			Vector3.new(rng:NextNumber(12, 20), h, w),
			CFrame.new(s * cx, TOP + h / 2 - 2, z + w / 2)
				* CFrame.Angles(
					math.rad(rng:NextNumber(-8, 8)),
					math.rad(rng:NextNumber(-20, 20)),
					math.rad(rng:NextNumber(-8, 8))
				),
			SAND[rng:NextInteger(1, #SAND)],
			Enum.Material.Rock
		)
		z += w * 0.7
	end
	box(
		m,
		"Moss",
		s * (x0 + 8),
		s * (P.WALL_IN - 2),
		TOP - 0.4,
		TOP + 0.6,
		ROCK_Z0 + 6,
		ROCK_Z1 - 6,
		Color3.fromRGB(96, 150, 74),
		Enum.Material.Grass
	)
	-- the ends step down to the shelf's revetment
	for _, e in { { ROCK_Z0, -1 }, { ROCK_Z1, 1 } } do
		local tops = { TOP - 6, TOP - 16, P.SHELF_Y + 2 }
		for k, t in tops do
			local z0 = e[1] + e[2] * (k - 1) * 4
			local z1 = z0 + e[2] * 5
			local face = P.TERRACE_OUT - P.BATTER + (k - 1) * 1.5
			block(
				m,
				"RockStep",
				Vector3.new(P.WALL_IN - face, t - LY + 2, math.abs(z1 - z0) + 1),
				CFrame.new(s * (face + P.WALL_IN) / 2, (t + LY - 2) / 2, (z0 + z1) / 2)
					* CFrame.Angles(0, math.rad(rng:NextNumber(-3, 3)), 0),
				SAND[rng:NextInteger(1, #SAND)],
				SLATE
			)
		end
	end
	m.Parent = monument
	claim(rect(s * (x0 - 13), s * P.WALL_IN, ROCK_Z0 - 12, ROCK_Z1 + 12, "HokageRock"))
	-- 1st to 4th reads left to right from the lane, so the 1st stands farthest; each head is set
	-- half into its alcove, standing on the ledge
	for i, name in HEADS do
		local hz = ROCK_Z0 + (i - 0.5) * step
		local head =
			make(monument, SRC[name], 0.95, facing(s), Vector3.new(s * (x0 + 6), LEDGE, hz))
		still(head, true)
	end
	-- bushes on the crown
	for _, bz in { ROCK_Z0 + 20, (ROCK_Z0 + ROCK_Z1) / 2 + 8, ROCK_Z1 - 18 } do
		still(
			make(
				trees,
				SRC.BushLeafy,
				1.5,
				rng:NextInteger(0, 3) * 90,
				Vector3.new(s * (P.WALL_IN - 10), TOP + 0.4, bz)
			),
			false
		)
	end
end

-- ---------------------------------------------------------------------------------- the village
-- +X, along the street (lane-side faces at x 118..137) and a second row on the shelf
local B = SRC
local A = P.STREET_OUT + 3 -- the terrace's front line: buildings start here
local ROW = {
	{ B.KonohaHouse, 0.88, 137.5, 268 }, -- beside the gate leaf
	{ B.KonohaHouse, 0.88, 137.5, 296 },
	{ B.KonohaTower, 1.22, A, 361 },
	{ B.HokageResidence, 0.74, A + 2, 425 },
	{ B.KonohaHall, 0.7, A, 482 },
}
for _, b in ROW do
	front(buildings, b[1], 1, b[2], b[3], b[4])
end
-- the shelf's row: small houses and little towers
for _, b in
	{
		{ B.KonohaHouse, 0.72, 262 },
		{ B.KonohaTower, 0.4, 296 },
		{ B.KonohaHouse, 0.72, 340 },
		{ B.KonohaHouse, 0.72, 410 },
		{ B.KonohaTower, 0.4, 446 },
		{ B.KonohaHouse, 0.72, 488 },
	}
do
	front(buildings, b[1], 1, b[2], P.REVET_OUT + 1, b[3])
end
-- -X: before the rock, a house on each band
front(buildings, B.KonohaHouse, -1, 0.72, P.REVET_OUT + 1, 262)

-- ---------------------------------------------------------------------------------- trees and rocks
local TREES = { SRC.TreeBroad, SRC.TreeTall }
local function tree(x: number, z: number, scale: number)
	local m = put(
		trees,
		TREES[rng:NextInteger(1, #TREES)],
		scale,
		rng:NextInteger(0, 3) * 90,
		x,
		z,
		{ soft = 4 * scale }
	)
	if m then
		still(m, scale > 1.1)
	end
end
local function bush(x: number, z: number, scale: number)
	local m = put(trees, SRC.BushLeafy, scale, rng:NextInteger(0, 3) * 90, x, z, { soft = 1 })
	if m then
		still(m, false)
	end
end
-- few trees (owner): on the shelves between the houses, two by the street
for _, t in { { 192, 318, 1.15 }, { 192, 376, 1.1 }, { 192, 468, 1.15 }, { -192, 244, 1.15 } } do
	tree(t[1], t[2], t[3])
end
for _, b in
	{
		{ 162, 361, 1.2 },
		{ 162, 452, 1.1 },
		{ -192, 298, 1.3 },
		{ -150, 306, 1.2 },
	}
do
	bush(b[1], b[2], b[3])
end
-- boulders at the rock's foot
for _, r in { { -142, 486, 1.0 } } do
	local m = put(trees, SRC.RockOutcrop, r[3], rng:NextInteger(0, 3) * 90, r[1], r[2])
	if m then
		still(m, true)
	end
end

-- ---------------------------------------------------------------------------------- props
local function prop(
	name: string,
	scale: number,
	x: number,
	z: number,
	yaw: number,
	opts: any?
): Model?
	local template = KIT:FindFirstChild(name)
	if not template then
		table.insert(refused, name .. " is not in the kit")
		return nil
	end
	return put(props, template, scale, yaw, x, z, opts)
end
-- the training ground beside the gate leaf, under the rock's first head
for i, z in { 262, 276, 290 } do
	prop("Prop_ninja_village_TrainingLog", 2.0, -146, z, 90 + i * 20)
end
prop("Prop_store_TrainingPole", 1.5, -160, 270, 90)
prop("Prop_store_TrainingPole", 1.5, -160, 296, 90)
prop("Prop_ninja_village_GiantShuriken", 1.6, -130, 340, 60)
prop("Prop_ninja_village_ScrollStand", 1.6, -130, 376, 90)
-- the ramen stand at the rock's foot, low, with its barrels and crate
prop("Prop_shared_RamenStand", 2.2, -136, 420, 90)
prop("Prop_store_Barrel", 1.4, -128, 446, 0)
prop("Prop_store_Barrel", 1.4, -134, 450, 30)
prop("Prop_store_Crate", 1.4, -150, 444, 15)
for _, z in { 320, 360, 400, 470 } do
	prop("Prop_store_StoneLantern", 1.3, -150, z, 0)
end
-- watch posts on the shelves
prop("Prop_ninja_village_WatchPost", 2.0, 194, 510, facing(1))
prop("Prop_ninja_village_WatchPost", 2.0, -194, 284, facing(-1))

-- power poles along both streets, wires between them
local function pole(side: number, z: number): Vector3
	local x = side * (P.KERB_OUT + 2.5)
	local m = Instance.new("Model")
	m.Name = "PowerPole"
	cylinder(m, "Pole", 1.8, 40, CFrame.new(x, LY + 20, z), WOOD_DARK, Enum.Material.Wood)
	block(m, "Arm", Vector3.new(1, 1, 9), CFrame.new(x, LY + 36, z), WOOD_DARK, Enum.Material.Wood)
	block(m, "Arm", Vector3.new(1, 1, 7), CFrame.new(x, LY + 32, z), WOOD_DARK, Enum.Material.Wood)
	cylinder(
		m,
		"Can",
		2.6,
		4,
		CFrame.new(x + side * 1.6, LY + 28, z),
		Color3.fromRGB(150, 156, 164),
		Enum.Material.Metal
	)
	m.Parent = props
	return Vector3.new(x, LY + 36.4, z)
end
for _, side in { -1, 1 } do
	local last: Vector3? = nil
	for _, z in { 330, 392, 454, 512 } do
		local top = pole(side, z)
		if last then
			for _, dz in { -4, 4 } do
				local a, b = last + Vector3.new(0, 0, dz), top + Vector3.new(0, 0, dz)
				local wire = block(
					props,
					"Wire",
					Vector3.new(0.4, 0.4, (b - a).Magnitude),
					CFrame.lookAt((a + b) / 2, b),
					Color3.fromRGB(30, 30, 34)
				)
				wire.CastShadow = false
			end
		end
		last = top
	end
end

-- leaves on the wind, the whole length of the street
local fx = folder(root, "Fx")
for _, z in { 250, 340, 430, 505 } do
	local source = block(
		fx,
		"LeafSource",
		Vector3.new(2 * HALF - 8, 1, 70),
		CFrame.new(0, LY + 84, z),
		Color3.new(1, 1, 1)
	)
	source.Transparency = 1
	source.CastShadow = false
	local e = Instance.new("ParticleEmitter")
	e.Name = "Leaves"
	e.Texture = "rbxassetid://5057182105"
	e.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(96, 190, 84)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(58, 150, 66)),
	})
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.3),
		NumberSequenceKeypoint.new(1, 1.8),
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
	e.LightEmission = 0
	e.LightInfluence = 1
	e.Parent = source
end

-- ---------------------------------------------------------------------------------- floor and gate
local lanes = map.Lanes
local SAND_A, SAND_B = Color3.fromRGB(246, 214, 144), Color3.fromRGB(238, 198, 120)
for _, c in kitItems(lanes["Zone_" .. ID]) do
	local n = c.Name
	if c:IsA("BasePart") then
		if n:sub(1, 5) == "Strip" then
			local tile = math.floor((c.Position.Z - Z0) / 44.25)
			c.Color = if tile % 2 == 0 then SAND_A else SAND_B
			local tex = c:FindFirstChildWhichIsA("Texture")
			if tex then
				tex.Color3 = Color3.fromRGB(255, 236, 190)
			end
		elseif n:sub(1, 4) == "Kerb" then
			c.Color = GREEN
		elseif n:sub(1, 6) == "Paving" or n == "MarginPaving" then
			c.Color = Color3.fromRGB(214, 192, 158)
			local tex = c:FindFirstChildWhichIsA("Texture")
			if tex then
				tex.Color3 = Color3.fromRGB(236, 222, 196)
			end
		elseif n:sub(1, 12) == "DistanceBand" then
			c.Color = Color3.fromRGB(255, 248, 226)
		end
	elseif n:sub(1, 5) == "Gate_" then
		for _, d in c:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "Accent" then
				d.Color = GREEN
			elseif d:IsA("TextLabel") then
				d.Text = "HIDDEN LEAF VILLAGE\nSTART HERE"
			end
		end
	end
end

-- the lane border wall stands from the towers' backs on (lane_border.luau reads this)
markSlim(root, BACK - 4, Z1)
return string.format("zone 1 Hidden Leaf v2: %d parts\n%s", #partsOf(root), sideReport(root))
