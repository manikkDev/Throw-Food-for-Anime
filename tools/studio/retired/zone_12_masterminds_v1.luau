-- RETIRED 2026-11-22: zone 12 on the old 320-wide lane (zone_lib). Kept for its content and numbers;
-- zones/zone_12_masterminds.luau (side_lib) builds the zone now.
-- zone_12_masterminds.luau - zone 12, "Shadow Council" (crossover: masterminds), z 4120..4480. Map
-- id shadow_council (no zone data yet). Run: python tools/studio/zones/run_zone.py build 12 [--no-terrain]
-- (rebuilt 2026-11-22: the first version was a cathedral, a throne and five chess pieces on bare
-- asphalt.)
--
-- The picture: the schemers' hall, under dark rock seamed with fire. The lane is a chessboard and
-- so are both terraces.
--   +X (left from the throw stage), the council's seat: the gothic cathedral with a red carpet to
--     its door, the library tower, the mansion, the council's long table, and the throne on its
--     steps facing the throwers.
--   -X, the board: a whole back rank of giant pieces (rook, knight, bishop, queen, king, bishop,
--     knight, rook) against the wall, gargoyle columns standing before them like pawns.
--   Braziers along both kerbs, small pieces on the ledges, dark cedars on the rims, embers in the air.
-- Templates: StoreAssets.Zone12_Masterminds (all generate_mesh, squared, fronting -Z).
local A = Enum.Material.Asphalt
local root = begin({
	n = 12,
	id = "shadow_council",
	title = "Shadow Council (masterminds)",
	src = "Zone12_Masterminds",
	now = {
		face = { [-1] = 236, [1] = 236 },
		rise = { [-1] = 6, [1] = 6 },
		ledgeW = { [-1] = 24, [1] = 24 },
		ledgeY = { [-1] = 14, [1] = 14 },
		top = { [-1] = 70, [1] = 70 },
	},
	prev = { -- zone 11's Italian street
		face = { [-1] = 236, [1] = 236 },
		rise = { [-1] = 6, [1] = 6 },
		ledgeW = { [-1] = 26, [1] = 26 },
		ledgeY = { [-1] = 10, [1] = 10 },
		top = { [-1] = 62, [1] = 62 },
	},
	-- zone 2's dark rock, seamed with cracked lava; dark level surfaces
	mats = {
		rock = Enum.Material.Basalt,
		band = Enum.Material.CrackedLava,
		prevRock = Enum.Material.Sandstone,
		terrace = A,
		prevTerrace = Enum.Material.Cobblestone,
		ledge = A,
		top = A,
	},
	wobble = 0.2,
})
local sights = folder(root, "Sights")
local groundF = folder(root, "Ground")
local props = folder(root, "Props")
local trees = folder(root, "Trees")
local CEDAR = STORE.Zone02_DemonSlayer.Cedar

local DARK = Color3.fromRGB(36, 36, 44)
local LIGHT = Color3.fromRGB(196, 192, 186)
local CARPET = Color3.fromRGB(150, 24, 36)
local GOLDTRIM = Color3.fromRGB(214, 170, 70)
local STONE = Color3.fromRGB(70, 70, 82)
local S0, S1 = Z0 + 82, Z1 + 10 -- the terrace clear of both gates' pillars
local GY = TERRACE + 0.35 -- the top of the paving

-- the terrace as a chessboard: dark marble, every other square pale
local function board(side: number)
	pave(groundF, side, 163.5, 240, S0 - 4, S1 + 2, DARK, Enum.Material.Marble)
	local sq = 17.5
	for i = 0, 3 do
		for j = 0, 16 do
			if (i + j) % 2 == 0 then
				local a, z = 164 + i * sq, S0 - 2 + j * sq
				if z + sq <= S1 + 2 then
					paint(groundF, side, a, a + sq, z, z + sq, LIGHT, GY + 0.25).Material =
						Enum.Material.Marble
				end
			end
		end
	end
end

-- ================================================================================== +X: the council's seat
do
	local side = 1
	board(side)
	local z = S0 + 2
	local cathZ0 = z
	z = row({ parent = sights, side = side, z = z, gap = 5, list = { { SRC.Cathedral, 1.5 } } })
	local cathZ1 = z - 5
	z = row({
		parent = sights,
		side = side,
		z = z,
		gap = 5,
		list = { { SRC.Library, 1.9 }, { SRC.Mansion, 1.9 } },
	})
	local rowEnd = z - 5
	-- a red carpet from the lane to the cathedral's door
	do
		local mid = (cathZ0 + cathZ1) / 2
		paint(groundF, side, 164, 176, mid - 5, mid + 5, CARPET, GY + 0.35).Material =
			Enum.Material.Fabric
		paint(groundF, side, 164, 176, mid - 5.8, mid - 5, GOLDTRIM, GY + 0.4)
		paint(groundF, side, 164, 176, mid + 5, mid + 5.8, GOLDTRIM, GY + 0.4)
	end
	-- the council's table, between the mansion and the throne
	local tableZ = rowEnd + 26
	place(sights, SRC.CouncilTable, 1.6, 90, Vector3.new(198, GY, tableZ))
	-- the throne on three round steps, a carpet up to it, facing the throw stage
	do
		local tz = S1 - 30
		for i, r in { 27, 23, 19 } do
			local ring = cylinder(
				sights,
				"ThroneStep",
				r * 2,
				1.4,
				CFrame.new(200, GY + i * 1.3 - 0.6, tz),
				if i == 3 then CARPET else STONE,
				Enum.Material.Marble
			)
			ring.CastShadow = false
		end
		reserve(200, tz, 27, 27, LY, GY + 5, "the throne's steps")
		place(sights, SRC.Throne, 2.3, 0, Vector3.new(200, GY + 3.9, tz), { over = true })
	end
	for bz = S0 + 14, S1 - 60, 44 do
		try(props, SRC.Brazier, 1.4, 0, Vector3.new(167.5, GY, bz))
	end
	try(props, SRC.Gargoyle, 1.6, facing(side), Vector3.new(172, GY, cathZ1 + 2.5))
	try(props, SRC.Gargoyle, 1.6, facing(side), Vector3.new(172, GY, rowEnd + 2))
end

-- ================================================================================== -X: the board
do
	local side = -1
	board(side)
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
	local list = {}
	for _, piece in rank do
		table.insert(list, { piece, 2.0 })
	end
	row({ parent = sights, side = side, z = S0 + 4, gap = 5, list = list })
	-- gargoyle columns before them, like pawns; braziers at the kerb
	for i = 0, 7 do
		try(props, SRC.Gargoyle, 1.6, facing(side), Vector3.new(-188, GY, S0 + 20 + i * 34))
	end
	for bz = S0 + 14, S1 - 10, 44 do
		try(props, SRC.Brazier, 1.4, 0, Vector3.new(-167.5, GY, bz))
	end
end

-- ================================================================================== ledges and rims
for _, side in { -1, 1 } do
	local pieces =
		{ SRC.ChessKing, SRC.ChessKnight, SRC.ChessQueen, SRC.ChessRook, SRC.ChessBishop }
	for i, pz in { Z0 + 60, Z0 + 130, Z0 + 200, Z0 + 270, Z0 + 340 } do
		local ax = ledgeAx(side) + 1
		local zz = pz + side * 14
		local m = place(
			props,
			pieces[(i + (if side > 0 then 0 else 2) - 1) % #pieces + 1],
			0.75,
			facing(side),
			Vector3.new(side * ax, ground(side, ax, zz) + 0.6, zz)
		)
		footing(props, m, STONE, Enum.Material.Marble, 6, 1.15)
	end
	for tz = Z0 + 30, Z1 - 10, 40 do
		plant(
			trees,
			CEDAR,
			side,
			rimAx(side) + rng:NextNumber(-4, 8),
			tz + rng:NextNumber(-8, 8),
			rng:NextNumber(1.3, 1.8)
		)
	end
	for tz = Z0 + 50, Z1 - 10, 60 do
		plant(
			trees,
			CEDAR,
			side,
			rimAx(side) + rng:NextNumber(26, 42),
			tz + rng:NextNumber(-8, 8),
			rng:NextNumber(1.6, 2.2)
		)
	end
end
-- embers on the air
drift(
	"rbxassetid://5057182105",
	Color3.fromRGB(255, 90, 60),
	Color3.fromRGB(200, 40, 40),
	0.9,
	5,
	0.8
)

floor({
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
return finish()
