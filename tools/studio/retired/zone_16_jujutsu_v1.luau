-- RETIRED 2026-11-22: zone 16 on the old 320-wide lane (zone_lib). Kept for its content and numbers;
-- zones/zone_16_jujutsu.luau (side_lib) builds the zone now.
-- zone_16_jujutsu.luau - zone 16, "Shibuya" (Jujutsu Kaisen), z 5560..5920. Map id shibuya (no zone
-- data yet). Run: python tools/studio/zones/run_zone.py build 16 [--no-terrain]
-- (rebuilt 2026-11-22: the first version was a tower, a station, a shrine, two hands and three
-- blocks on bare pavement.)
--
-- The picture: the Shibuya crossing. The lane is one giant zebra crossing and so is each street.
--   +X (left from the throw stage), the crossing: the cylindrical fashion tower, the ad-screen
--     tower, the station with a train at its platform and the subway entrance, the faithful dog's
--     statue, and the panda's statue at the far end facing the throwers.
--   -X, the sorcerers: the school's temple hall behind a torii, tower blocks and a noodle shop, the
--     cursed shrine on its skulls, the sealed box on its altar, and the giant clawed hand at the
--     far end.
--   Crossing signals at every corner, cars and a bus, vending machines; neon and screens on the
--   ledges; a skyline on the rims.
-- Templates: StoreAssets.Zone16_Jujutsu (all generate_mesh, squared, fronting -Z); vehicles and
-- street furniture are zones 4's and 10's.
local P = Enum.Material.Pavement
local C = Enum.Material.Concrete
local root = begin({
	n = 16,
	id = "shibuya",
	title = "Shibuya (Jujutsu Kaisen)",
	src = "Zone16_Jujutsu",
	now = {
		face = { [-1] = 236, [1] = 236 },
		rise = { [-1] = 6, [1] = 6 },
		ledgeW = { [-1] = 26, [1] = 26 },
		ledgeY = { [-1] = 8, [1] = 8 },
		top = { [-1] = 62, [1] = 62 },
	},
	prev = { -- zone 15's dungeon
		face = { [-1] = 236, [1] = 236 },
		rise = { [-1] = 6, [1] = 6 },
		ledgeW = { [-1] = 24, [1] = 24 },
		ledgeY = { [-1] = 14, [1] = 14 },
		top = { [-1] = 68, [1] = 68 },
	},
	mats = {
		rock = C,
		prevRock = Enum.Material.Ice,
		terrace = P,
		prevTerrace = Enum.Material.Basalt,
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
local Z10 = STORE.Zone10_Chainsaw
local JUNGLE = STORE.Zone01_Naruto

local ASPHALT = Color3.fromRGB(52, 54, 62)
local SIDEWALK = Color3.fromRGB(160, 162, 172)
local WHITE = Color3.fromRGB(244, 244, 240)
local YELLOW = Color3.fromRGB(250, 208, 40)
local PURPLE = Color3.fromRGB(120, 80, 220)
local STEEL = Color3.fromRGB(84, 86, 98)
local S0, S1 = Z0 + 82, Z1 + 10 -- the terrace clear of both gates' pillars
local GY = TERRACE + 0.35 -- the top of the paving
local SCREENS =
	{ "SHIBUYA 109", "JUJUTSU HIGH", "CURSED ENERGY", "TOKYO METRO", "DOMAIN EXPANSION", "SHIBUYA" }

-- a road by the lane with zebra crossings across it, a sidewalk behind
local function streetGround(side: number, crossings: { number })
	pave(groundF, side, 163.5, 183, S0 - 4, S1 + 2, ASPHALT, Enum.Material.Asphalt)
	pave(groundF, side, 183, 240, S0 - 4, S1 + 2, SIDEWALK, C)
	paint(groundF, side, 182.3, 183.5, S0 - 4, S1 + 2, Color3.fromRGB(128, 130, 140), GY + 0.4) -- the kerb
	for _, cz in crossings do
		for i = 0, 5 do
			paint(groundF, side, 165.5 + i * 2.9, 167.4 + i * 2.9, cz - 7, cz + 7, WHITE, GY + 0.3)
		end
	end
end
local function plinth(x: number, z: number, radius: number, rim: Color3)
	local p = cylinder(city, "Plinth", radius * 2, 3, CFrame.new(x, GY + 1.5, z), STEEL, C)
	p.CastShadow = false
	cylinder(city, "PlinthRim", radius * 2 + 1.2, 0.5, CFrame.new(x, GY + 3.1, z), rim)
	reserve(x, z, radius, radius, LY, GY + 4, "a plinth")
end

-- ================================================================================== +X: the crossing
do
	local side = 1
	local z = S0 + 2
	local fashionZ0 = z
	local towerW = sizeOf(SRC.FashionTower).X * 1.7
	local adW = sizeOf(SRC.AdTower).X * 1.9
	local stationW = sizeOf(SRC.Station).X * 1.6
	local adZ0 = fashionZ0 + towerW + 4
	local stationZ0 = adZ0 + adW + 4
	streetGround(side, { adZ0 - 2, stationZ0 - 2, stationZ0 + stationW + 2 })
	z = row({
		parent = city,
		side = side,
		z = z,
		gap = 4,
		list = { { SRC.FashionTower, 1.7 }, { SRC.AdTower, 1.9 }, { SRC.Station, 1.6 }, { Z10.Cinema, 2.0 } },
	})
	local rowEnd = z - 4
	-- the train at the station's platform, the subway entrance, the faithful dog
	try(props, SRC.Train, 1.5, 0, Vector3.new(171, GY, stationZ0 + stationW / 2))
	place(
		props,
		SRC.Subway,
		1.1,
		facing(side),
		Vector3.new(196, GY, rowEnd + 11),
		{ fit = 0.9 }
	)
	place(props, SRC.DogStatue, 1.0, facing(side), Vector3.new(187.5, GY, fashionZ0 + towerW / 2), { fit = 0.8 })
	try(props, Z4.Taxi, 1.3, 0, Vector3.new(169, GY, fashionZ0 + 12))
	try(props, Z4.Car, 1.3, 180, Vector3.new(177, GY, adZ0 + 20))
	try(props, Z10.VendingRow, 1.2, facing(side), Vector3.new(186, GY, stationZ0 - 2))
	for _, sz in { adZ0 - 11, stationZ0 - 11, stationZ0 + stationW + 11 } do
		try(props, SRC.Signal, 3.2, facing(side), Vector3.new(184.5, GY, sz), { fit = 0.6 })
	end
	-- the panda on its plinth, facing the throw stage
	local pz = (rowEnd + 4 + S1) / 2
	plinth(200, pz, 20, YELLOW)
	place(city, SRC.Panda, 1.7, 0, Vector3.new(200, GY + 3.2, pz), { over = true })
end

-- ================================================================================== -X: the sorcerers
do
	local side = -1
	local z = S0 + 2
	local schoolW = sizeOf(SRC.School).X * 1.8
	local shrineZ0 = S0
		+ 2
		+ schoolW
		+ 4
		+ sizeOf(Z4.Skyscraper).X * 2.0
		+ 4
		+ sizeOf(Z10.NoodleShop).X * 1.8
		+ 4
	streetGround(side, { S0 + 2 + schoolW + 2, shrineZ0 - 2 })
	local schoolZ0 = z
	z = row({
		parent = city,
		side = side,
		z = z,
		gap = 4,
		list = {
			{ SRC.School, 1.8 },
			{ Z4.Skyscraper, 2.0 },
			{ Z10.NoodleShop, 1.8 },
			{ SRC.Shrine, 1.6 },
			{ Z4.Konbini, 1.8 },
		},
	})
	local rowEnd = z - 4
	-- a torii before the school, the sealed box on its altar before the shrine
	try(
		props,
		KIT.Prop_realm_of_legends_GreatTorii,
		0.8,
		facing(side),
		Vector3.new(-190, GY, schoolZ0 + schoolW / 2)
	)
	place(
		props,
		SRC.SealedBox,
		1.0,
		facing(side),
		Vector3.new(-189, GY, shrineZ0 - 28),
		{ fit = 0.8 }
	)
	try(props, Z4.Bus, 1.6, 0, Vector3.new(-171, GY, schoolZ0 + schoolW + 30))
	try(props, Z4.Car, 1.3, 180, Vector3.new(-177, GY, schoolZ0 + 16))
	try(props, Z10.SirenCar, 1.25, 0, Vector3.new(-169, GY, shrineZ0 + 34))
	for _, sz in { S0 + 2 + schoolW + 11, shrineZ0 - 11, shrineZ0 + 9 } do
		try(props, SRC.Signal, 3.2, facing(side), Vector3.new(-184.5, GY, sz), { fit = 0.6 })
	end
	-- the giant clawed hand on its plinth, facing the throw stage
	local hz = (rowEnd + 4 + S1) / 2
	plinth(-200, hz, 19, PURPLE)
	place(city, SRC.Finger, 3.0, 0, Vector3.new(-200, GY + 3.2, hz), { over = true })
end

-- ================================================================================== ledges and rims
for _, side in { -1, 1 } do
	-- screens on the ledge, read from the lane
	for i, bz in { Z0 + 100, Z0 + 190, Z0 + 280 } do
		local ax = ledgeAx(side) + 4
		local zz = bz + side * 18
		local by = ground(side, ax, zz)
		local glow = if i % 2 == 1
			then Color3.fromRGB(255, 80, 170)
			else Color3.fromRGB(80, 220, 255)
		local board = sign(
			props,
			SCREENS[(i + (if side > 0 then 0 else 3) - 1) % #SCREENS + 1],
			52,
			13,
			CFrame.new(side * ax, by + 11, zz) * CFrame.Angles(0, math.rad(facing(side)), 0),
			Color3.fromRGB(24, 24, 34),
			glow
		)
		board.Name = "Screen"
		board.Material = Enum.Material.Neon
		block(
			props,
			"ScreenEdge",
			Vector3.new(1, 14, 53),
			CFrame.new(side * (ax + 0.5), by + 11, zz),
			glow,
			Enum.Material.Neon
		)
		for _, d in { -21, 21 } do
			block(
				props,
				"ScreenLeg",
				Vector3.new(1.6, 6, 1.6),
				CFrame.new(side * (ax + 0.4), by + 2.5, zz + d),
				STEEL,
				Enum.Material.Metal
			)
		end
		reserve(side * ax, zz, 3, 28, by - 2, by + 24, "a screen")
	end
	-- the skyline on the rim
	for i, t in { { Z4.Apartment, 1.7 }, { SRC.AdTower, 1.5 }, { Z4.Skyscraper, 1.8 } } do
		local ax = rimAx(side) + 28 + (i % 2) * 8
		local zz = Z0 + 80 + (i - 1) * 105 + side * 24
		local b = place(
			city,
			t[1],
			t[2],
			facing(side),
			Vector3.new(side * ax, ground(side, ax, zz) + 3, zz)
		)
		footing(city, b, STEEL, C, 18, 1.04)
	end
	for tz = Z0 + 50, Z1 - 10, 46 do
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
	title = "SHIBUYA",
	accent = PURPLE,
	-- a zebra crossing: every other row of tiles is white, right across the lane
	strip = function(tile: number, _track: number)
		if tile % 2 == 0 then
			return Color3.fromRGB(244, 244, 240), Color3.fromRGB(255, 255, 255)
		end
		return Color3.fromRGB(50, 52, 62), Color3.fromRGB(100, 104, 118)
	end,
	kerb = YELLOW,
	paving = Color3.fromRGB(96, 98, 110),
	pavingTex = Color3.fromRGB(146, 148, 162),
})
return finish()
