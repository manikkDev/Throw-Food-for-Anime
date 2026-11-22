-- RETIRED 2026-11-22: zone 10 on the old 320-wide lane (zone_lib). Kept for its content and numbers;
-- zones/zone_10_chainsaw.luau (side_lib) builds the zone now.
-- zone_10_chainsaw.luau - zone 10, "Public Safety HQ" (Chainsaw Man), z 3400..3760. Map id
-- public_safety (no zone data yet). Run: python tools/studio/zones/run_zone.py build 10 [--no-terrain]
-- (rebuilt 2026-11-22: the first version was five buildings and a tower on bare pavement.)
--
-- The picture: a gritty Tokyo street under dark walls.
--   +X (left from the throw stage): the bureau's grey government block with its black cars, the
--     cinema, the family diner, and the giant chainsaw driven into a plinth facing the throwers.
--   -X: the noodle shop, the shabby apartments, the old headquarters, the corner store, and the
--     little chainsaw dog's statue at the far end.
--   A service road each side with utility poles and their wires, vending machines, a bus stop;
--   signboards on the ledges; a skyline and the red lattice tower on the rims.
-- Templates: StoreAssets.Zone10_Chainsaw (all generate_mesh, squared, fronting -Z); the vehicles,
-- the corner store and the skyline blocks are zone 4's.
local P = Enum.Material.Pavement
local C = Enum.Material.Concrete
local root = begin({
	n = 10,
	id = "public_safety",
	title = "Public Safety HQ (Chainsaw Man)",
	src = "Zone10_Chainsaw",
	now = {
		face = { [-1] = 236, [1] = 236 },
		rise = { [-1] = 6, [1] = 6 },
		ledgeW = { [-1] = 26, [1] = 26 },
		ledgeY = { [-1] = 8, [1] = 8 },
		top = { [-1] = 62, [1] = 62 },
	},
	prev = { -- zone 9's Walls
		face = { [-1] = 234, [1] = 234 },
		rise = { [-1] = 4, [1] = 4 },
		ledgeW = { [-1] = 34, [1] = 34 },
		ledgeY = { [-1] = 62, [1] = 62 },
		top = { [-1] = 62, [1] = 62 },
	},
	mats = {
		rock = Enum.Material.Basalt,
		prevRock = Enum.Material.Brick,
		terrace = P,
		prevTerrace = Enum.Material.Ground,
		ledge = P,
		top = Enum.Material.LeafyGrass,
	},
	wobble = 0.2,
})
local city = folder(root, "City")
local groundF = folder(root, "Ground")
local props = folder(root, "Props")
local trees = folder(root, "Trees")
local Z4 = STORE.Zone04_MHA
local JUNGLE = STORE.Zone01_Naruto

local ASPHALT = Color3.fromRGB(54, 56, 64)
local SIDEWALK = Color3.fromRGB(150, 152, 160)
local LINE = Color3.fromRGB(240, 240, 236)
local HAZARD = Color3.fromRGB(250, 208, 40)
local RED = Color3.fromRGB(214, 48, 40)
local DARK = Color3.fromRGB(34, 34, 40)
local STEEL = Color3.fromRGB(70, 72, 82)
local S0, S1 = Z0 + 82, Z1 + 10 -- the terrace clear of both gates' pillars
local GY = TERRACE + 0.35 -- the top of the paving
local BOARDS = {
	"PUBLIC SAFETY",
	"DEVIL HUNTERS WANTED",
	"SPECIAL DIVISION 4",
	"PUBLIC SAFETY",
	"KEEP TOKYO SAFE",
	"NO DEVILS ALLOWED",
}

-- a service road by the lane, a sidewalk behind it
local function streetGround(side: number)
	pave(groundF, side, 163.5, 181, S0 - 4, S1 + 2, ASPHALT, Enum.Material.Asphalt)
	pave(groundF, side, 181, 240, S0 - 4, S1 + 2, SIDEWALK, C)
	paint(groundF, side, 180.3, 181.5, S0 - 4, S1 + 2, Color3.fromRGB(120, 122, 130), GY + 0.4) -- the kerb
	for lz = S0, S1 - 6, 14 do
		paint(groundF, side, 172, 172.6, lz, lz + 7, LINE)
	end
end
-- utility poles down the kerb, wires sagging from one to the next
local function poles(side: number, zs: { number })
	local last: Vector3? = nil
	for _, pz in zs do
		local pole = try(
			props,
			SRC.UtilityPole,
			2.4,
			facing(side),
			Vector3.new(side * 184.5, GY, pz),
			{ fit = 0.5 }
		)
		if pole then
			local _, size = pole:GetBoundingBox()
			local top = Vector3.new(side * 184.5, GY + size.Y * 0.9, pz)
			if last then
				local mid = (last + top) / 2 - Vector3.new(0, 2.2, 0)
				for _, seg in { { last, mid }, { mid, top } } do
					local a, b = seg[1], seg[2]
					local wire = block(
						props,
						"Wire",
						Vector3.new(0.25, 0.25, (a - b).Magnitude),
						CFrame.lookAt((a + b) / 2, b),
						DARK
					)
					wire.CastShadow = false
				end
			end
			last = top
		else
			last = nil
		end
	end
end
-- a round plinth with a hazard-yellow rim
local function plinth(x: number, z: number, radius: number)
	local p = cylinder(city, "Plinth", radius * 2, 3, CFrame.new(x, GY + 1.5, z), STEEL, C)
	p.CastShadow = false
	cylinder(city, "PlinthRim", radius * 2 + 1.2, 0.5, CFrame.new(x, GY + 3.1, z), HAZARD)
	reserve(x, z, radius, radius, LY, GY + 4, "a plinth")
end

-- ================================================================================== +X: the bureau
do
	local side = 1
	streetGround(side)
	local z = S0 + 2
	local govZ0 = z
	z = row({ parent = city, side = side, z = z, gap = 4, list = { { SRC.GovOffice, 2.0 } } })
	local cinemaZ0 = z
	z = row({ parent = city, side = side, z = z, gap = 4, list = { { SRC.Cinema, 2.2 } } })
	local dinerZ0 = z
	z = row({
		parent = city,
		side = side,
		z = z,
		gap = 4,
		list = { { SRC.Diner, 2.2 }, { Z4.ScreenBuilding, 2.2 } },
	})
	local rowEnd = z - 4
	-- the bureau's black cars at the kerb, a taxi and a car further on
	try(props, SRC.SirenCar, 1.25, 0, Vector3.new(168.5, GY, govZ0 + 14))
	try(props, SRC.SirenCar, 1.25, 0, Vector3.new(168.5, GY, govZ0 + 42))
	try(props, SRC.SirenCar, 1.25, 180, Vector3.new(176.5, GY, govZ0 + 60))
	try(props, Z4.Taxi, 1.3, 0, Vector3.new(168.5, GY, cinemaZ0 + 24))
	try(props, Z4.Car, 1.3, 180, Vector3.new(176.5, GY, dinerZ0 + 30))
	try(props, SRC.VendingRow, 1.4, facing(side), Vector3.new(190, GY, cinemaZ0 - 2))
	try(props, Z4.BusStop, 1.4, facing(side), Vector3.new(187, GY, dinerZ0 + 6))
	poles(side, { S0 + 8, S0 + 58, S0 + 108, S0 + 158, S0 + 208 })
	-- the giant chainsaw on its plinth, its broad side to the throw stage
	local cz = (rowEnd + 4 + S1) / 2
	plinth(200, cz, 21)
	place(city, SRC.Chainsaw, 2.6, 90, Vector3.new(200, GY + 3.2, cz), { over = true })
end

-- ================================================================================== -X: the neighbourhood
do
	local side = -1
	streetGround(side)
	local z = S0 + 2
	local noodleZ0 = z
	z = row({ parent = city, side = side, z = z, gap = 4, list = { { SRC.NoodleShop, 2.0 } } })
	local aptZ0 = z
	z = row({ parent = city, side = side, z = z, gap = 4, list = { { SRC.OldApartment, 2.4 } } })
	local hqZ0 = z
	z = row({
		parent = city,
		side = side,
		z = z,
		gap = 4,
		list = { { SRC.HQ, 1.6 }, { Z4.Konbini, 2.0 } },
	})
	local rowEnd = z - 4
	try(props, SRC.VendingRow, 1.4, facing(side), Vector3.new(-190, GY, aptZ0 - 2))
	try(props, Z4.Car, 1.3, 0, Vector3.new(-168.5, GY, noodleZ0 + 20))
	try(props, Z4.Taxi, 1.3, 180, Vector3.new(-176.5, GY, aptZ0 + 34))
	try(props, SRC.SirenCar, 1.25, 0, Vector3.new(-168.5, GY, hqZ0 + 22))
	try(props, Z4.Bus, 1.6, 0, Vector3.new(-170.5, GY, hqZ0 + 74))
	poles(side, { S0 + 30, S0 + 80, S0 + 130, S0 + 180 })
	-- the little chainsaw dog on its plinth, facing the throw stage
	local dz = (rowEnd + 4 + S1) / 2
	plinth(-200, dz, 22)
	place(city, SRC.DogStatue, 1.9, 0, Vector3.new(-200, GY + 3.0, dz), { over = true })
end

-- ================================================================================== ledges and rims
for _, side in { -1, 1 } do
	-- signboards on the ledge, read from the lane
	for i, bz in { Z0 + 110, Z0 + 200, Z0 + 290 } do
		local ax = ledgeAx(side) + 4
		local zz = bz + side * 16
		local by = ground(side, ax, zz)
		local accent = if i % 2 == 1 then RED else HAZARD
		local text = BOARDS[(i + (if side > 0 then 0 else 3) - 1) % #BOARDS + 1]
		local board = sign(
			props,
			text,
			50,
			11,
			CFrame.new(side * ax, by + 10, zz) * CFrame.Angles(0, math.rad(facing(side)), 0),
			DARK,
			accent
		)
		board.Name = "Signboard"
		block(
			props,
			"SignboardEdge",
			Vector3.new(1, 12, 51),
			CFrame.new(side * (ax + 0.5), by + 10, zz),
			accent
		)
		for _, d in { -20, 20 } do
			block(
				props,
				"SignboardLeg",
				Vector3.new(1.6, 6, 1.6),
				CFrame.new(side * (ax + 0.4), by + 2.5, zz + d),
				STEEL,
				Enum.Material.Metal
			)
		end
		reserve(side * ax, zz, 3, 27, by - 2, by + 22, "a signboard")
	end
	-- the skyline: blocks on the rim, each on its footing; the red tower on the -X rim
	for i, t in
		{
			{ Z4.Apartment, 1.7, Z0 + 80 },
			{ Z4.Skyscraper, 1.8, Z0 + 180 },
			{ SRC.OldApartment, 1.5, Z0 + 290 },
		}
	do
		local ax = rimAx(side) + 28 + (i % 2) * 8
		local zz = t[3] + side * 24
		local b = place(
			city,
			t[1],
			t[2],
			facing(side),
			Vector3.new(side * ax, ground(side, ax, zz) + 3, zz)
		)
		footing(city, b, Color3.fromRGB(90, 92, 104), C, 18, 1.04)
	end
	if side < 0 then
		local ax = rimAx(side) + 14
		local tz = Z0 + 236
		local tower =
			place(city, SRC.RedTower, 1.5, 0, Vector3.new(side * ax, ground(side, ax, tz) + 2, tz))
		footing(city, tower, Color3.fromRGB(90, 92, 104), C, 14, 1.1)
	end
	-- a few street trees on the ledge, a thin wood on the rim
	for tz = Z0 + 50, Z1 - 10, 44 do
		plant(
			trees,
			JUNGLE.TreeBroad,
			side,
			ledgeAx(side) + rng:NextNumber(-8, -2),
			tz + rng:NextNumber(-6, 6),
			rng:NextNumber(0.8, 1.1)
		)
	end
	for tz = Z0 + 30, Z1 - 10, 30 do
		plant(
			trees,
			if rng:NextNumber() < 0.5 then JUNGLE.TreeBroad else JUNGLE.TreeTall,
			side,
			rimAx(side) + rng:NextNumber(-5, 10),
			tz + rng:NextNumber(-8, 8),
			rng:NextNumber(1.3, 1.9)
		)
	end
end

floor({
	title = "PUBLIC SAFETY HQ",
	accent = Color3.fromRGB(226, 60, 40),
	strip = function(tile: number, track: number)
		if (tile + track) % 2 == 0 then
			return Color3.fromRGB(240, 128, 36), Color3.fromRGB(252, 184, 110)
		end
		return Color3.fromRGB(52, 54, 62), Color3.fromRGB(104, 108, 120)
	end,
	kerb = HAZARD,
	paving = Color3.fromRGB(150, 150, 158),
	pavingTex = Color3.fromRGB(194, 194, 202),
})
return finish()
