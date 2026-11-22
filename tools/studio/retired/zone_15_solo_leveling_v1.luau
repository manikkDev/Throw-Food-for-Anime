-- RETIRED 2026-11-22: zone 15 on the old 320-wide lane (zone_lib). Kept for its content and numbers;
-- zones/zone_15_solo_leveling.luau (side_lib) builds the zone now.
-- zone_15_solo_leveling.luau - zone 15, "Gate of Shadows" (Solo Leveling), z 5200..5560. Map id
-- gate_of_shadows (no zone data yet). Run: python tools/studio/zones/run_zone.py build 15 [--no-terrain]
-- (rebuilt 2026-11-22: the first version was two gates, three knights, a king and obelisks on bare
-- rock.)
--
-- The picture: a dungeon gate torn open in the city, under deep purple rock.
--   +X (left from the throw stage), the hunters' side: the guild's dark glass tower behind its
--     checkpoint, the gate itself glowing in the wall, the ruined temple, and the seated stone king
--     at the far end facing the throwers.
--   -X, inside the dungeon: shadow knights on guard, the dragon's bones, a second gate, the ant
--     soldier, and the dark dagger in its stone at the far end.
--   Rune obelisks, broken pillars and blue crystals everywhere; glowing rune lines on the ground;
--   blue embers rising.
-- Templates: StoreAssets.Zone15_SoloLeveling (all generate_mesh, squared, fronting -Z).
local I = Enum.Material.Ice
local B = Enum.Material.Basalt
local root = begin({
	n = 15,
	id = "gate_of_shadows",
	title = "Gate of Shadows (Solo Leveling)",
	src = "Zone15_SoloLeveling",
	now = {
		face = { [-1] = 236, [1] = 236 },
		rise = { [-1] = 6, [1] = 6 },
		ledgeW = { [-1] = 24, [1] = 24 },
		ledgeY = { [-1] = 14, [1] = 14 },
		top = { [-1] = 68, [1] = 68 },
	},
	prev = { -- zone 14's white city
		face = { [-1] = 236, [1] = 236 },
		rise = { [-1] = 6, [1] = 6 },
		ledgeW = { [-1] = 28, [1] = 28 },
		ledgeY = { [-1] = 10, [1] = 10 },
		top = { [-1] = 60, [1] = 60 },
	},
	mats = {
		rock = I,
		prevRock = Enum.Material.Rock,
		terrace = B,
		prevTerrace = Enum.Material.Limestone,
		ledge = B,
		top = B,
	},
	colors = { [I] = Color3.fromRGB(74, 54, 128) },
	wobble = 0.4,
})
local sights = folder(root, "Sights")
local groundF = folder(root, "Ground")
local props = folder(root, "Props")
local ISEKAI = STORE.Zone08_Isekai

local FLOOR = Color3.fromRGB(46, 42, 62)
local RUNE = Color3.fromRGB(80, 190, 255)
local STONE = Color3.fromRGB(70, 66, 92)
local S0, S1 = Z0 + 82, Z1 + 10 -- the terrace clear of both gates' pillars
local GY = TERRACE + 0.35 -- the top of the paving
local function opt(name: string): Instance?
	return SRC:FindFirstChild(name)
end
local CRYSTAL = opt("CrystalSpire") or ISEKAI.Crystal
local PILLAR = opt("Column") or SRC.Obelisk

-- dark flagstones with glowing rune lines: a border, and a circle wherever something stands
local function dungeonFloor(side: number)
	pave(groundF, side, 163.5, 240, S0 - 4, S1 + 2, FLOOR, Enum.Material.Slate)
	for _, r in { { 165, 165.7, S0 - 2, S1 }, { 238, 238.7, S0 - 2, S1 } } do
		paint(groundF, side, r[1], r[2], r[3], r[4], RUNE, GY + 0.3).Material = Enum.Material.Neon
	end
	for lz = S0 + 20, S1 - 20, 44 do
		paint(groundF, side, 165, 238.7, lz, lz + 0.6, RUNE, GY + 0.3).Material = Enum.Material.Neon
	end
end
local function runeCircle(x: number, z: number, radius: number)
	local ring = cylinder(
		groundF,
		"RuneRing",
		radius * 2,
		0.3,
		CFrame.new(x, GY + 0.3, z),
		RUNE,
		Enum.Material.Neon
	)
	ring.CastShadow = false
	local inner = cylinder(
		groundF,
		"RuneRingInner",
		radius * 2 - 2.4,
		0.4,
		CFrame.new(x, GY + 0.32, z),
		FLOOR,
		Enum.Material.Slate
	)
	inner.CastShadow = false
end
local function plinth(x: number, z: number, radius: number)
	runeCircle(x, z, radius + 3)
	local p = cylinder(
		sights,
		"Plinth",
		radius * 2,
		3,
		CFrame.new(x, GY + 1.5, z),
		STONE,
		Enum.Material.Slate
	)
	p.CastShadow = false
	reserve(x, z, radius, radius, LY, GY + 4, "a plinth")
end

-- ================================================================================== +X: the hunters' side
do
	local side = 1
	dungeonFloor(side)
	local z = S0 + 2
	local guildZ0 = z
	z = row({ parent = sights, side = side, z = z, gap = 5, list = { { SRC.Guild, 1.9 } } })
	local gateZ0 = z
	z = row({ parent = sights, side = side, z = z, gap = 5, list = { { SRC.Gate, 2.0 } } })
	local gateZ1 = z - 5
	z = row({ parent = sights, side = side, z = z, gap = 5, list = { { SRC.Temple, 1.7 } } })
	local rowEnd = z - 5
	-- the checkpoint before the guild; a rune circle before the gate, obelisks flanking it
	place(props, SRC.Checkpoint, 1.5, facing(side), Vector3.new(172, GY, guildZ0 + 24))
	do
		local mid = (gateZ0 + gateZ1) / 2
		runeCircle(186, mid, 22)
		place(props, SRC.Obelisk, 1.2, 0, Vector3.new(180, GY, gateZ0 + 4))
		place(props, SRC.Obelisk, 1.2, 0, Vector3.new(180, GY, gateZ1 - 4))
	end
	-- the stone king on his plinth, facing the throw stage
	local kz = (rowEnd + 5 + S1) / 2
	plinth(202, kz, 26)
	place(sights, SRC.StoneKing, 1.5, 0, Vector3.new(202, GY + 3, kz), { over = true })
	-- crystals and pillars wherever there is room, last
	scatter({
		parent = props,
		templates = { CRYSTAL },
		count = 8,
		side = side,
		ax = { 176, 232 },
		z = { S0, S1 - 4 },
		scale = { 0.5, 1.0 },
		y = GY - 0.8,
		soft = true,
		sunkOk = 3,
	})
	scatter({
		parent = props,
		templates = { PILLAR },
		count = 4,
		side = side,
		ax = { 176, 200 },
		z = { S0, S1 - 30 },
		scale = { 0.7, 1.0 },
		y = GY - 0.2,
		soft = true,
	})
end

-- ================================================================================== -X: inside the dungeon
do
	local side = -1
	dungeonFloor(side)
	local z = S0 + 2
	local knightZ0 = z
	z = row({ parent = sights, side = side, z = z, gap = 6, list = { { SRC.Knight, 1.6 } } })
	z = row({
		parent = sights,
		side = side,
		z = z,
		gap = 6,
		front = 184,
		list = { { SRC.DragonBones, 2.0 } },
	})
	local knight2Z0 = z
	z = row({
		parent = sights,
		side = side,
		z = z,
		gap = 6,
		list = { { SRC.Knight, 1.6 }, { SRC.Gate, 1.7 }, { SRC.Knight, 1.6 } },
	})
	local rowEnd = z - 6
	-- the ant soldier stands out in front, by the lane
	place(
		sights,
		SRC.AntSoldier,
		1.2,
		facing(side),
		Vector3.new(-176, GY, knight2Z0 + 50),
		{ fit = 0.8 }
	)
	for _, kz in { knightZ0 + 16, knight2Z0 + 16 } do
		runeCircle(-190, kz, 9)
	end
	-- the dark dagger in its stone, facing the throw stage
	local dz = (rowEnd + 6 + S1) / 2
	plinth(-200, dz, 18)
	place(sights, SRC.Dagger, 3.4, 0, Vector3.new(-200, GY + 3, dz), { over = true })
	scatter({
		parent = props,
		templates = { CRYSTAL },
		count = 10,
		side = side,
		ax = { 176, 232 },
		z = { S0, S1 - 4 },
		scale = { 0.5, 1.1 },
		y = GY - 0.8,
		soft = true,
		sunkOk = 3,
	})
	scatter({
		parent = props,
		templates = { PILLAR, SRC.Obelisk },
		count = 6,
		side = side,
		ax = { 170, 186 },
		z = { S0, S1 - 30 },
		scale = { 0.7, 1.0 },
		y = GY - 0.2,
		soft = true,
	})
end

-- ================================================================================== ledges and rims
for _, side in { -1, 1 } do
	scatter({
		parent = props,
		templates = { CRYSTAL, ISEKAI.Crystal },
		count = 9,
		side = side,
		ax = { ledgeAx(side) - 8, ledgeAx(side) + 8 },
		z = { Z0 + 30, Z1 },
		scale = { 0.6, 1.2 },
		sink = 2,
		soft = true,
		sunkOk = 12,
	})
	scatter({
		parent = props,
		templates = { SRC.Obelisk, PILLAR },
		count = 5,
		side = side,
		ax = { ledgeAx(side) - 6, ledgeAx(side) + 6 },
		z = { Z0 + 40, Z1 - 10 },
		scale = { 0.6, 0.8 },
		sink = 1,
		soft = true,
		sunkOk = 8,
	})
	scatter({
		parent = props,
		templates = { ISEKAI.Crystal, CRYSTAL },
		count = 8,
		side = side,
		ax = { rimAx(side) + 2, rimAx(side) + 34 },
		z = { Z0 + 20, Z1 },
		scale = { 1.2, 2.2 },
		sink = 3,
		soft = true,
		sunkOk = 14,
	})
	scatter({
		parent = props,
		templates = { SRC.Obelisk },
		count = 4,
		side = side,
		ax = { rimAx(side) + 4, rimAx(side) + 30 },
		z = { Z0 + 30, Z1 - 10 },
		scale = { 1.2, 1.8 },
		sink = 2,
		soft = true,
		sunkOk = 12,
	})
end
-- blue embers rising through the dark
drift(
	"rbxassetid://5057182105",
	Color3.fromRGB(90, 170, 255),
	Color3.fromRGB(150, 90, 255),
	1,
	6,
	0.9
)

floor({
	title = "GATE OF SHADOWS",
	accent = Color3.fromRGB(70, 150, 255),
	strip = function(tile: number, track: number)
		if (tile + track) % 2 == 0 then
			return Color3.fromRGB(58, 40, 112), Color3.fromRGB(110, 86, 180)
		end
		return Color3.fromRGB(48, 126, 236), Color3.fromRGB(130, 190, 255)
	end,
	kerb = Color3.fromRGB(80, 230, 250),
	paving = Color3.fromRGB(64, 58, 86),
	pavingTex = Color3.fromRGB(116, 108, 146),
})
return finish()
