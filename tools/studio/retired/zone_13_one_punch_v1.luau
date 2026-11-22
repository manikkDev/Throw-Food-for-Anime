-- RETIRED 2026-11-22: zone 13 on the old 320-wide lane (zone_lib). Kept for its content and numbers;
-- zones/zone_13_one_punch.luau (side_lib) builds the zone now.
-- zone_13_one_punch.luau - zone 13, "City Z" (One Punch Man), z 4480..4840. Map id city_z (no zone
-- data yet). Run: python tools/studio/zones/run_zone.py build 13 [--no-terrain]
-- (rebuilt 2026-11-22: the first version was a headquarters, two ruined towers, a statue and a
-- meteor on bare pavement.)
--
-- The picture: a city that monsters keep wrecking, and the heroes who clean up after them.
--   +X (left from the throw stage), what still stands: the supermarket with its sale, the hero
--     association's armoured headquarters, the bald hero's cheap apartment block, and his statue
--     on a plinth facing the throwers.
--   -X, the ghost town: ruined towers and a sheared-off office block, a meteor in its crater, a
--     flipped car, rubble everywhere, a giant crab monster bursting out of the street, and the
--     cyborg's statue at the far end.
--   Cracked roads, bent poles, hazard barriers; hero billboards on the ledges; a broken skyline on
--   the rims.
-- Templates: StoreAssets.Zone13_OnePunch (all generate_mesh, squared, fronting -Z); vehicles and
-- street furniture are zone 4's and zone 10's.
local P = Enum.Material.Pavement
local C = Enum.Material.Concrete
local root = begin({
	n = 13,
	id = "city_z",
	title = "City Z (One Punch Man)",
	src = "Zone13_OnePunch",
	now = {
		face = { [-1] = 236, [1] = 236 },
		rise = { [-1] = 6, [1] = 6 },
		ledgeW = { [-1] = 26, [1] = 26 },
		ledgeY = { [-1] = 8, [1] = 8 },
		top = { [-1] = 62, [1] = 62 },
	},
	prev = { -- zone 12's hall
		face = { [-1] = 236, [1] = 236 },
		rise = { [-1] = 6, [1] = 6 },
		ledgeW = { [-1] = 24, [1] = 24 },
		ledgeY = { [-1] = 14, [1] = 14 },
		top = { [-1] = 70, [1] = 70 },
	},
	mats = {
		rock = C,
		prevRock = Enum.Material.Basalt,
		terrace = P,
		prevTerrace = Enum.Material.Asphalt,
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

local ASPHALT = Color3.fromRGB(62, 64, 72)
local SIDEWALK = Color3.fromRGB(176, 176, 184)
local LINE = Color3.fromRGB(244, 240, 220)
local YELLOW = Color3.fromRGB(250, 208, 50)
local RED = Color3.fromRGB(214, 48, 48)
local CRACK = Color3.fromRGB(30, 30, 36)
local STEEL = Color3.fromRGB(90, 92, 104)
local S0, S1 = Z0 + 82, Z1 + 10 -- the terrace clear of both gates' pillars
local GY = TERRACE + 0.35 -- the top of the paving

-- a service road by the lane, a sidewalk behind it; `broken` adds cracks across both
local function streetGround(side: number, broken: boolean)
	pave(groundF, side, 163.5, 181, S0 - 4, S1 + 2, ASPHALT, Enum.Material.Asphalt)
	pave(groundF, side, 181, 240, S0 - 4, S1 + 2, SIDEWALK, C)
	paint(groundF, side, 180.3, 181.5, S0 - 4, S1 + 2, Color3.fromRGB(140, 140, 150), GY + 0.4) -- the kerb
	for lz = S0, S1 - 6, 14 do
		paint(groundF, side, 172, 172.6, lz, lz + 7, LINE)
	end
	if broken then
		for i = 1, 16 do
			local ax, cz = rng:NextNumber(166, 228), rng:NextNumber(S0 + 4, S1 - 4)
			local len = rng:NextNumber(10, 26)
			local crack = block(
				groundF,
				"Crack",
				Vector3.new(0.7, 0.2, len),
				CFrame.new(side * ax, GY + 0.45, cz)
					* CFrame.Angles(0, math.rad(rng:NextNumber(0, 180)), 0),
				CRACK
			)
			crack.CastShadow = false
		end
	end
end
local function plinth(x: number, z: number, radius: number, rim: Color3)
	local p = cylinder(city, "Plinth", radius * 2, 3, CFrame.new(x, GY + 1.5, z), STEEL, C)
	p.CastShadow = false
	cylinder(city, "PlinthRim", radius * 2 + 1.2, 0.5, CFrame.new(x, GY + 3.1, z), rim)
	reserve(x, z, radius, radius, LY, GY + 4, "a plinth")
end
-- a red and white hazard barrier across the road
local function barrier(x: number, z: number, yaw: number)
	local cf = CFrame.new(x, GY, z) * CFrame.Angles(0, math.rad(yaw), 0)
	for i = -1, 1 do
		block(
			props,
			"BarrierBar",
			Vector3.new(4, 1.6, 0.6),
			cf * CFrame.new(i * 4, 3, 0),
			if i == 0 then Color3.new(1, 1, 1) else RED
		)
	end
	for _, dx in { -5, 5 } do
		block(props, "BarrierLeg", Vector3.new(0.6, 3.6, 2.4), cf * CFrame.new(dx, 1.8, 0), YELLOW)
	end
end

-- ================================================================================== +X: what still stands
do
	local side = 1
	streetGround(side, false)
	local z = S0 + 2
	local marketZ0 = z
	z = row({ parent = city, side = side, z = z, gap = 4, list = { { SRC.Supermarket, 2.2 } } })
	local hqZ0 = z
	z = row({ parent = city, side = side, z = z, gap = 4, list = { { SRC.HeroHQ, 1.9 } } })
	local aptZ0 = z
	z = row({
		parent = city,
		side = side,
		z = z,
		gap = 4,
		list = { { SRC.CheapApartment, 2.1 }, { Z4.Konbini, 2.0 } },
	})
	local rowEnd = z - 4
	try(props, Z4.Car, 1.3, 0, Vector3.new(168.5, GY, marketZ0 + 14))
	try(props, Z4.Taxi, 1.3, 180, Vector3.new(176.5, GY, marketZ0 + 40))
	try(props, Z10.SirenCar, 1.25, 0, Vector3.new(168.5, GY, hqZ0 + 20))
	try(props, Z4.Bus, 1.6, 0, Vector3.new(170.5, GY, aptZ0 + 30))
	try(props, Z10.VendingRow, 1.4, facing(side), Vector3.new(190, GY, hqZ0 - 2))
	try(props, Z4.BusStop, 1.4, facing(side), Vector3.new(186, GY, aptZ0 + 56))
	for i, pz in { S0 + 8, S0 + 62, S0 + 116, S0 + 170 } do
		local pole = try(
			props,
			Z10.UtilityPole,
			2.4,
			facing(side),
			Vector3.new(184.5, GY, pz),
			{ fit = 0.5 }
		)
		if pole and i == 3 then
			pole:PivotTo(pole:GetPivot() * CFrame.Angles(0, 0, math.rad(-8))) -- one knocked askew
		end
	end
	-- the bald hero on his plinth, facing the throw stage
	local sz = (rowEnd + 4 + S1) / 2
	plinth(200, sz, 21, YELLOW)
	place(city, SRC.BaldHero, 2.0, 0, Vector3.new(200, GY + 3.2, sz), { over = true })
end

-- ================================================================================== -X: the ghost town
do
	local side = -1
	streetGround(side, true)
	local z = S0 + 2
	z = row({
		parent = city,
		side = side,
		z = z,
		gap = 5,
		list = { { SRC.RuinedTower, 2.0 }, { SRC.CollapsedBlock, 2.0 } },
	})
	local meteorZ0 = z
	-- the meteor in its crater: rings of broken ground about it
	do
		local mz = meteorZ0 + 30
		for i, r in { 30, 24 } do
			local ring = cylinder(
				groundF,
				"CraterRing",
				r * 2,
				0.5,
				CFrame.new(-206, GY + 0.2 + i * 0.25, mz),
				if i == 1 then Color3.fromRGB(96, 90, 86) else CRACK,
				Enum.Material.Slate
			)
			ring.CastShadow = false
		end
		place(city, SRC.Meteor, 1.9, 20, Vector3.new(-206, GY - 2.5, mz), { fit = 0.8 })
		z = meteorZ0 + 92
	end
	z = row({ parent = city, side = side, z = z, gap = 5, list = { { SRC.RuinedTower, 1.6 } } })
	local rowEnd = z - 5
	-- the crab monster bursting out of the road, beyond the meteor
	place(
		city,
		SRC.CrabMonster,
		1.1,
		100,
		Vector3.new(-190, GY - 0.4, meteorZ0 + 70),
		{ fit = 0.8 }
	)
	-- wreckage: a flipped car, barriers, rubble wherever there is room
	try(props, SRC.FlippedCar, 1.4, 35, Vector3.new(-172, GY, S0 + 20))
	try(props, SRC.FlippedCar, 1.4, 250, Vector3.new(-170, GY, meteorZ0 + 104))
	barrier(-172, S0 + 104, 12)
	barrier(-172, meteorZ0 + 30, -10)
	for i, pz in { S0 + 30, S0 + 150, S0 + 210 } do
		local pole = try(
			props,
			Z10.UtilityPole,
			2.4,
			facing(side),
			Vector3.new(-184.5, GY, pz),
			{ fit = 0.5 }
		)
		if pole then
			pole:PivotTo(
				pole:GetPivot() * CFrame.Angles(0, 0, math.rad(if i % 2 == 0 then 12 else -9))
			)
		end
	end
	-- the cyborg on his plinth, facing the throw stage
	local sz = (rowEnd + 5 + S1) / 2
	plinth(-200, sz, 19, RED)
	place(city, SRC.Cyborg, 2.6, 0, Vector3.new(-200, GY + 3.2, sz), { over = true })
	-- the wall with the fist-shaped dent, standing in the ruins by the kerb, turned to the lane
	if SRC:FindFirstChild("PunchWall") then
		try(
			props,
			SRC.PunchWall,
			1.1,
			facing(side),
			Vector3.new(-178, GY - 0.3, S0 + 60),
			{ fit = 0.9 }
		)
	end
	-- rubble last, so it keeps clear of everything standing
	scatter({
		parent = props,
		templates = { SRC.Rubble },
		count = 14,
		side = side,
		ax = { 176, 232 },
		z = { S0, S1 - 6 },
		scale = { 0.8, 1.6 },
		y = GY - 0.3,
		soft = true,
	})
end

-- ================================================================================== ledges and rims
for _, side in { -1, 1 } do
	for _, bz in { Z0 + 110, Z0 + 220, Z0 + 320 } do
		local ax = ledgeAx(side) + 2
		local zz = bz + side * 14
		local b = place(
			props,
			Z4.HeroBillboard,
			1.6,
			facing(side),
			Vector3.new(side * ax, ground(side, ax, zz) + 0.6, zz)
		)
		footing(props, b, STEEL, C, 6, 1.0)
		if side < 0 and bz == Z0 + 220 then
			b:PivotTo(b:GetPivot() * CFrame.Angles(math.rad(10), 0, 0)) -- hanging askew over the ghost town
			b:SetAttribute("SunkOk", 8)
			b:SetAttribute("HangOk", 8)
		end
	end
	-- the skyline: whole on +X, ruined on -X
	local skyline = if side > 0
		then { { Z4.Apartment, 1.7 }, { Z4.Skyscraper, 1.8 }, { SRC.CheapApartment, 1.6 } }
		else { { SRC.RuinedTower, 1.5 }, { SRC.CollapsedBlock, 1.6 }, { SRC.RuinedTower, 1.4 } }
	for i, t in skyline do
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
	scatter({
		parent = trees,
		templates = { JUNGLE.BushLeafy },
		count = 7,
		side = side,
		ax = { ledgeAx(side) - 10, ledgeAx(side) + 9 },
		z = { Z0 + 30, Z1 },
		scale = { 1.2, 1.8 },
		sink = 0.6,
		soft = true,
	})
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
	title = "CITY Z",
	accent = YELLOW,
	strip = function(tile: number, track: number)
		if (tile + track) % 2 == 0 then
			return Color3.fromRGB(248, 206, 48), Color3.fromRGB(255, 232, 130)
		end
		return Color3.fromRGB(250, 240, 214), Color3.fromRGB(255, 252, 240)
	end,
	kerb = RED,
	paving = Color3.fromRGB(176, 176, 184),
	pavingTex = Color3.fromRGB(212, 212, 220),
})
return finish()
