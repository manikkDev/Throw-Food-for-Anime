-- LIB: side_lib
-- zone_12_masterminds.luau - zone 12, "Shadow Council" (crossover: masterminds), on the slim lane (v2,
-- 2026-11-22). z 4120..4480 (map id shadow_council, no zone data yet), lane floor y -48, lane edges
-- x +-100. Run with
--   python tools/studio/zones/run_zone.py build 12
-- then lane_border.luau. Safe to run again. v1 (zone_lib, the 320-wide lane): MapArchive.Zone12_v1_canyon
-- and tools/studio/retired/zone_12_masterminds_v1.luau.
--
-- The schemers' hall between dark basalt walls seamed with fire. The lane is a chessboard and so are
-- both terraces.
--   +X, the council's seat: the gothic cathedral with a red carpet to its door, the library tower,
--     the mansion, the council's long table, and the throne on its steps facing the throwers
--   -X, the board: a whole back rank of giant pieces against the wall, gargoyle columns before them
--     like pawns, and the great king on his plinth at the far end
--   braziers along both kerbs, small pieces and dark cedars on the shelves, embers in the air
local SS = game:GetService("ServerStorage")
local map = workspace.Map
local SRC = SS.StoreAssets.Zone12_Masterminds
local CEDAR = SS.StoreAssets.Zone02_DemonSlayer.Cedar
local ID = "shadow_council"
local LY, HALF, Z0, Z1 = P.LY, P.HALF, 4120, 4480
local rng = Random.new(12107)

local DARK = Color3.fromRGB(36, 36, 44)
local LIGHT = Color3.fromRGB(196, 192, 186)
local CARPET = Color3.fromRGB(150, 24, 36)
local GOLDTRIM = Color3.fromRGB(214, 170, 70)
local STONE = Color3.fromRGB(70, 70, 82)
local BASALT = Color3.fromRGB(52, 52, 62)
local EMBER = Color3.fromRGB(255, 96, 40)
local GY = P.TERRACE_Y + 0.4

local function facing(side: number): number
	return if side > 0 then 90 else -90 -- a squared template fronts to -Z: turn it to the lane
end
local sights: Folder, props: Folder -- set below, once the zone's folder is cleared
local function sight(template: Instance, side: number, scale: number, ax: number, z: number): Model?
	local m = front(sights, template, side, scale, ax, z)
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
-- stepped rounds under a set piece
local function steps(x: number, z: number, radii: { number }, top: Color3)
	for i, r in radii do
		cylinder(
			sights,
			"Step",
			r * 2,
			1.4,
			CFrame.new(x, GY + i * 1.3 - 0.6, z),
			if i == #radii then top else STONE,
			Enum.Material.Marble
		).CastShadow =
			false
	end
	local r = radii[1]
	claim(rect(x - r - 1, x + r + 1, z - r - 1, z + r + 1, "Steps"))
	return GY + #radii * 1.3 - 0.1
end

-- ---------------------------------------------------------------------------------- the zone's folder
local scenery = map.Scenery
local archive = SS:FindFirstChild("MapArchive") or folder(SS, "MapArchive")
if not archive:FindFirstChild("Zone12_v1_canyon") then
	local keep = scenery["Zone_" .. ID]:Clone()
	keep.Name = "Zone12_v1_canyon"
	keep:SetAttribute(
		"Note",
		"Zone 12 (Shadow Council) v1 on the 320-wide lane, before the slim-lane rebuild (2026-11-22). Never delete."
	)
	keep.Parent = archive
end
local root = scenery["Zone_" .. ID]
root:ClearAllChildren()
root:SetAttribute("Theme", "Shadow Council (masterminds), zone_12_masterminds.luau v2 on side_lib")
local ground = folder(root, "Ground")
sights = folder(root, "Sights")
props = folder(root, "Props")
local trees = folder(root, "Trees")

-- ---------------------------------------------------------------------------------- the ground
local STYLE = {
	stone = BASALT,
	material = Enum.Material.Basalt,
	band = EMBER,
	cap = STONE,
	capMaterial = Enum.Material.Slate,
	rail = GOLDTRIM,
	buttress = 36,
}
if DO_TERRAIN then
	sideGround(Z0, Z1)
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
		Z0,
		Z1,
		Color3.fromRGB(190, 30, 44),
		Enum.Material.Slate
	)
	local wall = revetment(ground, s, Z0, Z1, STYLE)
	-- the fire in the rock: the band glows, and a second seam lower down
	for _, p in wall:GetChildren() do
		if p:IsA("BasePart") and p.Name == "Band" then
			p.Material = Enum.Material.Neon
		end
	end
	box(
		wall,
		"EmberSeam",
		s * (P.TERRACE_OUT - P.BATTER * 0.4 - 0.4),
		s * (P.TERRACE_OUT - P.BATTER * 0.4 + 0.6),
		GY + 9,
		GY + 9.8,
		Z0,
		Z1,
		EMBER,
		Enum.Material.Neon
	)
	-- the terrace as a chessboard: dark marble, every other square pale
	local x0, x1 = P.KERB_OUT, P.TERRACE_OUT - P.BATTER
	pave(ground, s * x0, s * (x1 + 0.5), Z0, Z1, GY, DARK, Enum.Material.Marble, "Board")
	local sq = (x1 - x0) / 4
	for i = 0, 3 do
		for j = 0, math.floor((Z1 - Z0) / sq) - 1 do
			if (i + j) % 2 == 0 then
				local a, z = x0 + i * sq, Z0 + j * sq
				paint(ground, s * a, s * (a + sq), z, z + sq, LIGHT, GY).Material =
					Enum.Material.Marble
			end
		end
	end
	table.insert(claims, rect(s * HALF, s * P.STREET_OUT, Z0, Z1, "Street"))
end

-- ================================================================================== +X: the council's seat
sight(SRC.Cathedral, 1, 1.05, 126, 4205)
sight(SRC.Library, 1, 1.0, 147.5, 4245)
sight(SRC.Mansion, 1, 1.3, 135, 4283)
-- a red carpet from the lane to the cathedral's door, gold at its edges
paint(ground, P.KERB_OUT, 126, 4200, 4210, CARPET, GY + 0.1).Material = Enum.Material.Fabric
paint(ground, P.KERB_OUT, 126, 4199.2, 4200, GOLDTRIM, GY + 0.15)
paint(ground, P.KERB_OUT, 126, 4210, 4210.8, GOLDTRIM, GY + 0.15)
table.insert(claims, rect(P.STREET_OUT, 126, 4199, 4211, "Carpet"))
-- the council's table, between the mansion and the throne
prop(SRC.CouncilTable, 1.3, 142, 4336, 90)
-- the throne on three round steps, facing the throw stage
do
	local top = steps(142, 4426, { 20, 16.5, 13 }, CARPET)
	still(make(sights, SRC.Throne, 1.45, 0, Vector3.new(142, top, 4426)), true)
end
prop(SRC.Gargoyle, 1.4, P.STREET_OUT + 6, 4240, facing(1))
prop(SRC.Gargoyle, 1.4, P.STREET_OUT + 6, 4302, facing(1))

-- ================================================================================== -X: the board
do
	local rank = {
		SRC.ChessRook,
		SRC.ChessKnight,
		SRC.ChessBishop,
		SRC.ChessQueen,
		SRC.ChessKing,
		SRC.ChessBishop,
		SRC.ChessKnight,
		SRC.ChessRook,
	}
	local z = 4186
	local back = P.TERRACE_OUT - P.BATTER - 1
	for _, piece in rank do
		local x0, x1, z0, z1 = turned(piece, 1.3, facing(-1))
		local depth, width = x1 - x0, z1 - z0
		local m = put(sights, piece, 1.3, facing(-1), -(back - depth / 2), z + width / 2)
		if m then
			still(m, true)
		end
		z += width + 5
	end
	-- gargoyle columns before them, like pawns
	for i = 0, 7 do
		prop(SRC.Gargoyle, 1.3, -(P.STREET_OUT + 17), 4196 + i * 24, facing(-1))
	end
	-- the great king on his plinth at the far end
	local top = steps(-142, 4436, { 17, 13.5 }, Color3.fromRGB(96, 26, 36))
	still(make(sights, SRC.ChessKing, 1.45, 0, Vector3.new(-142, top, 4436)), true)
end

-- ================================================================================== braziers and the shelves
local SHELF = P.REVET_OUT + 1.5
for _, s in { -1, 1 } do
	for z = 4186, Z1 - 70, 44 do
		prop(SRC.Brazier, 1.3, s * (P.STREET_OUT + 4.5), z, 0)
	end
	local pieces =
		{ SRC.ChessKing, SRC.ChessKnight, SRC.ChessQueen, SRC.ChessRook, SRC.ChessBishop }
	for i, pz in { 4190, 4270, 4350, 4430 } do
		local m = front(
			props,
			pieces[(i + (if s > 0 then 0 else 2) - 1) % #pieces + 1],
			s,
			0.7,
			SHELF + 4,
			pz + s * 10
		)
		if m then
			still(m, true)
		end
	end
	for _, z in { 4230, 4310, 4392 } do
		local t = put(trees, CEDAR, 1.3, rng:NextInteger(0, 3) * 90, s * 192, z, { soft = 5 })
		if t then
			still(t, false)
		end
	end
end

-- embers on the air
local fx = folder(root, "Fx")
for _, z in { 4190, 4280, 4370, 4450 } do
	local source = block(
		fx,
		"EmberSource",
		Vector3.new(2 * HALF - 8, 1, 70),
		CFrame.new(0, LY + 70, z),
		Color3.new(1, 1, 1)
	)
	source.Transparency = 1
	source.CastShadow = false
	local e = Instance.new("ParticleEmitter")
	e.Name = "Embers"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 120, 60), Color3.fromRGB(220, 40, 40))
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(1, 0.3),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(6, 9)
	e.Rate = 5
	e.Speed = NumberRange.new(1, 3)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.SpreadAngle = Vector2.new(40, 40)
	e.Acceleration = Vector3.new(0, 1.5, 0)
	e.LightEmission = 0.9
	e.Parent = source
end

-- ---------------------------------------------------------------------------------- the lane's floor
floorKit({
	id = ID,
	title = "SHADOW COUNCIL",
	accent = Color3.fromRGB(190, 30, 44),
	strip = function(tile: number, track: number)
		if (tile + track) % 2 == 0 then
			return Color3.fromRGB(30, 30, 36), Color3.fromRGB(78, 78, 90)
		end
		return Color3.fromRGB(236, 234, 226), Color3.fromRGB(255, 255, 250)
	end,
	kerb = Color3.fromRGB(190, 30, 44),
	paving = Color3.fromRGB(70, 70, 82),
	pavingTex = Color3.fromRGB(124, 124, 138),
})

markSlim(root, Z0, Z1)
return string.format("zone 12 Shadow Council v2: %d parts\n%s", #partsOf(root), sideReport(root))
