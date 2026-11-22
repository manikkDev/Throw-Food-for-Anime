-- RETIRED 2026-11-22: zone 4 on the old 320-wide lane (zone_lib). Kept for its content and numbers;
-- zones/zone_04_mha.luau (side_lib) builds the zone now.
-- zone_04_mha.luau - zone 4, "Hero Academy" (My Hero Academia), z 1240..1600. Config id still
-- samurai_castle. Run: python tools/studio/zones/run_zone.py build 4 [--no-terrain]
-- (rebuilt 2026-11-22: the first version was four towers and a statue on bare pavement, with props
-- standing inside the gate pillars and trees through the billboards.)
--
-- The picture: the hero school and the city it guards.
--   +X (left from the throw stage), the campus behind its white wall and blue gate: the training
--     dome with a hurdle track, the glass H of the main building at the head of a tree-lined path,
--     the brick dormitory with its basketball court, and the bronze hero on a round plinth facing
--     the throwers.
--   -X, the city street: a service road with a bus at its stop, a taxi and cars; a skyscraper, a
--     convenience store with its car park, the hero agency, the screen tower; and at the far end
--     the giant exam robot, loose among rubble.
--   Hero billboards and trees on the ledges, a skyline of towers and trees on the rims.
-- Templates: StoreAssets.Zone04_MHA (all generate_mesh, squared, fronting -Z).
local C, P = Enum.Material.Concrete, Enum.Material.Pavement
local G = Enum.Material.LeafyGrass
local root = begin({
	n = 4,
	id = "samurai_castle",
	title = "Hero Academy (My Hero Academia)",
	src = "Zone04_MHA",
	now = {
		face = { [-1] = 236, [1] = 236 },
		rise = { [-1] = 6, [1] = 6 },
		ledgeW = { [-1] = 26, [1] = 26 },
		ledgeY = { [-1] = 8, [1] = 8 },
		top = { [-1] = 62, [1] = 62 },
	},
	prev = { -- zone 3's cove (as rebuilt)
		face = { [-1] = 240, [1] = 240 },
		rise = { [-1] = 8, [1] = 8 },
		ledgeW = { [-1] = 26, [1] = 26 },
		ledgeY = { [-1] = LY + 6, [1] = LY + 6 },
		top = { [-1] = 62, [1] = 58 },
	},
	mats = {
		rock = C,
		prevRock = Enum.Material.Sandstone,
		terrace = P,
		prevTerrace = Enum.Material.Sand,
		ledge = G,
		top = G,
	},
	-- dark: pale walls swallowed the pale towers
	colors = { [C] = Color3.fromRGB(112, 120, 140), [P] = Color3.fromRGB(92, 96, 108) },
	wobble = 0.2, -- a city: the wall's foot runs straight behind the buildings
})
local campus = folder(root, "Campus")
local city = folder(root, "City")
local groundF = folder(root, "Ground")
local props = folder(root, "Props")
local trees = folder(root, "Trees")
local JUNGLE = STORE.Zone01_Naruto

local WHITE = Color3.fromRGB(240, 242, 246)
local PLAZA = Color3.fromRGB(214, 218, 226)
local PATH = Color3.fromRGB(168, 176, 192)
local ASPHALT = Color3.fromRGB(58, 60, 70)
local SIDEWALK = Color3.fromRGB(186, 190, 198)
local LINE = Color3.fromRGB(250, 250, 250)
local YELLOW = Color3.fromRGB(255, 206, 44)
local UA_BLUE = Color3.fromRGB(40, 104, 220)
local S0, S1 = Z0 + 82, Z1 + 10 -- the terrace clear of both gates' pillars
local GY = TERRACE + 0.35 -- the top of the paving: what stands on a terrace stands on this

-- ================================================================================== +X: the campus
do
	local side = 1
	pave(groundF, side, 163.5, 240, S0 - 4, S1 + 2, PLAZA, C)
	-- the buildings, backs to the wall: dome, main building, dormitory
	local z = S0 + 2
	local domeZ0 = z
	z = row({ parent = campus, side = side, z = z, gap = 6, list = { { SRC.TrainingDome, 1.5 } } })
	local mainZ0 = z
	z = row({
		parent = campus,
		side = side,
		z = z,
		gap = 6,
		list = { { SRC.UAMain, 2.6 } },
		y = TERRACE - 3.5,
	})
	campus.UAMain:SetAttribute("SunkOk", 5) -- sunk on purpose: its mesh has a dark underside
	-- white entrance steps across its front: they give the building a podium and cover the dark
	-- patch the mesh carries under its doorway
	do
		local cf, size = campus.UAMain:GetBoundingBox()
		local frontX = cf.Position.X - size.Z / 2
		for i = 1, 4 do
			block(
				campus,
				"EntranceStep",
				Vector3.new(7 + (4 - i) * 3.2, 1.3, size.X * 0.84 - i * 2),
				CFrame.new(
					frontX + 1.5 - (4 - i) * 1.6,
					TERRACE + 0.35 + i * 1.3 - 0.65,
					cf.Position.Z
				),
				Color3.fromRGB(236, 240, 246),
				Enum.Material.Concrete
			)
		end
	end
	local mainZ1 = z - 6
	local dormZ0 = z
	z = row({ parent = campus, side = side, z = z, gap = 6, list = { { SRC.Dorm, 2.0 } } })
	local dormZ1 = z - 6
	local mainZ = (mainZ0 + mainZ1) / 2

	-- the gate at the lane's edge, the path from it to the main building's steps, the campus wall
	local gate = place(campus, SRC.UAGate, 1.8, facing(side), Vector3.new(174, GY, mainZ))
	local _, gsize = gate:GetBoundingBox()
	local gateHalf = gsize.Z / 2 + 1
	paint(groundF, side, 180, 198, mainZ - 9, mainZ + 9, PATH)
	paint(groundF, side, 180, 198, mainZ - 0.6, mainZ + 0.6, UA_BLUE)
	for _, span in { { S0, mainZ - gateHalf }, { mainZ + gateHalf, S1 - 44 } } do
		local len = span[2] - span[1]
		block(
			campus,
			"CampusWall",
			Vector3.new(2.2, 6, len),
			CFrame.new(166.2, GY + 3, (span[1] + span[2]) / 2),
			WHITE,
			C
		)
		block(
			campus,
			"CampusWallCap",
			Vector3.new(3.2, 1, len),
			CFrame.new(166.2, GY + 6.5, (span[1] + span[2]) / 2),
			UA_BLUE
		)
		for pz = span[1] + 1.5, span[2] - 1, 24 do
			block(
				campus,
				"CampusWallPier",
				Vector3.new(3.4, 8, 3.4),
				CFrame.new(166.2, GY + 4, pz),
				WHITE,
				C
			)
		end
	end
	sign(
		campus,
		"U.A. HIGH SCHOOL",
		44,
		7,
		CFrame.new(167.6, GY + 12, mainZ - gateHalf - 26)
			* CFrame.Angles(0, math.rad(facing(side)), 0),
		UA_BLUE,
		WHITE
	)
	block(
		campus,
		"SignPost",
		Vector3.new(1.4, 9, 1.4),
		CFrame.new(168.2, GY + 4.5, mainZ - gateHalf - 44),
		WHITE,
		C
	)
	block(
		campus,
		"SignPost",
		Vector3.new(1.4, 9, 1.4),
		CFrame.new(168.2, GY + 4.5, mainZ - gateHalf - 8),
		WHITE,
		C
	)

	-- the path's trees, in planters, either side
	for _, dz in { -15, 15 } do
		for _, ax in { 184, 194 } do
			try(props, SRC.PlanterTree, 1.25, 0, Vector3.new(ax, GY, mainZ + dz))
		end
	end
	for _, dz in { -30, 30 } do
		try(
			props,
			KIT.Prop_sakura_schoolyard_Bench,
			1.5,
			facing(side),
			Vector3.new(196, GY, mainZ + dz)
		)
	end

	-- the dome's training ground: a three-lane track with hurdles
	do
		local t0, t1 = domeZ0 + 2, mainZ0 - 10
		paint(groundF, side, 170, 185, t0, t1, Color3.fromRGB(206, 92, 70))
		for _, ax in { 170, 175, 180, 185 } do
			paint(groundF, side, ax - 0.25, ax + 0.25, t0, t1, LINE, GY + 0.3)
		end
		for i, hz in { t0 + 9, t0 + 21, t0 + 33 } do
			for lane = 0, 2 do
				if (i + lane) % 2 == 0 then
					try(
						props,
						KIT.Prop_sakura_schoolyard_TrackHurdle,
						1.2,
						90,
						Vector3.new(172.5 + lane * 5, GY, hz)
					)
				end
			end
		end
	end

	-- the dormitory's court: a half court with its hoop, benches, bikes, a vending machine
	do
		local c0, c1 = dormZ0 + 6, dormZ0 + 36
		paint(groundF, side, 170, 186, c0, c1, Color3.fromRGB(226, 146, 84))
		for _, r in
			{
				{ 170, 186, c0, c0 + 0.5 },
				{ 170, 186, c1 - 0.5, c1 },
				{ 170, 170.5, c0, c1 },
				{ 185.5, 186, c0, c1 },
				{ 174, 182, c0 + 9.5, c0 + 10 },
			}
		do
			paint(groundF, side, r[1], r[2], r[3], r[4], LINE, GY + 0.3)
		end
		try(
			props,
			KIT.Prop_sakura_schoolyard_BasketballHoop,
			1.5,
			0,
			Vector3.new(178, GY, c0 + 1.5)
		)
		try(props, KIT.Prop_sakura_schoolyard_Bench, 1.5, 180, Vector3.new(173, GY, c1 + 5))
		try(props, KIT.Prop_sakura_schoolyard_Bench, 1.5, 180, Vector3.new(184, GY, c1 + 5))
		try(
			props,
			KIT.Prop_sakura_schoolyard_BikeRack,
			1.4,
			facing(side),
			Vector3.new(171, GY, dormZ1 - 4)
		)
		try(
			props,
			KIT.Prop_shared_VendingMachine,
			1.5,
			facing(side),
			Vector3.new(186.5, GY, dormZ1 - 2)
		)
	end

	-- the bronze hero, on a round plinth with steps, facing the throw stage
	do
		local sz = (dormZ1 + S1) / 2 + 2
		local sx = 201
		for i, r in { 24, 20, 16 } do
			local ring = cylinder(
				campus,
				"Plinth",
				r * 2,
				1.2,
				CFrame.new(sx, GY + i * 1.1, sz),
				if i == 3 then UA_BLUE else WHITE,
				C
			)
			ring.CastShadow = false
		end
		reserve(sx, sz, 24, 24, LY, GY + 5, "the statue's plinth")
		place(campus, SRC.HeroStatue, 2.4, 0, Vector3.new(sx, GY + 3.9, sz), { over = true })
		for _, a in { 40, 140, 220, 320 } do
			local r = math.rad(a)
			try(
				props,
				SRC.PlanterTree,
				1.0,
				0,
				Vector3.new(sx + math.cos(r) * 30, GY, sz + math.sin(r) * 28)
			)
		end
	end
end

-- ================================================================================== -X: the city street
do
	local side = -1
	-- a service road along the lane, a sidewalk, asphalt under the blocks
	pave(groundF, side, 163.5, 181, S0 - 4, S1 + 2, ASPHALT, Enum.Material.Asphalt)
	pave(groundF, side, 181, 240, S0 - 4, S1 + 2, SIDEWALK, C)
	paint(groundF, side, 180.4, 181.6, S0 - 4, S1 + 2, Color3.fromRGB(150, 154, 164), GY + 0.4) -- the kerb
	for z = S0, S1 - 6, 14 do
		paint(groundF, side, 172, 172.6, z, z + 7, LINE) -- the road's broken centre line
	end
	local z = S0 + 2
	local skyZ0 = z
	z = row({ parent = city, side = side, z = z, gap = 4, list = { { SRC.ScreenBuilding, 2.4 } } })
	local shopZ0 = z
	z = row({ parent = city, side = side, z = z, gap = 4, list = { { SRC.Konbini, 1.8 } } })
	local shopZ1 = z - 4
	local agencyZ0 = z
	z = row({ parent = city, side = side, z = z, gap = 4, list = { { SRC.HeroAgency, 2.4 } } })
	local rowEnd = z

	-- the store's car park: bays painted on asphalt, two cars nosed in
	do
		pave(
			groundF,
			side,
			183,
			206,
			shopZ0 + 1,
			shopZ1 - 1,
			ASPHALT,
			Enum.Material.Asphalt,
			GY + 0.15
		)
		local bays = math.floor((shopZ1 - shopZ0 - 2) / 9)
		for i = 0, bays do
			paint(groundF, side, 189, 205, shopZ0 + 1 + i * 9, shopZ0 + 1.5 + i * 9, LINE, GY + 0.3)
		end
		try(props, SRC.Car, 1.3, facing(side), Vector3.new(-197, GY, shopZ0 + 5.5 + 9))
		try(props, SRC.Taxi, 1.3, facing(side), Vector3.new(-197, GY, shopZ0 + 5.5 + 27))
		try(props, KIT.Prop_sakura_schoolyard_BikeRack, 1.4, 0, Vector3.new(-186, GY, shopZ0 + 4))
	end
	-- the bus at its stop, in front of the agency
	try(props, SRC.Bus, 1.6, 0, Vector3.new(-170.5, GY, agencyZ0 + 22))
	try(props, SRC.BusStop, 1.4, facing(side), Vector3.new(-185, GY, agencyZ0 + 22))
	-- parked along the road
	try(props, SRC.Taxi, 1.3, 0, Vector3.new(-168.5, GY, skyZ0 + 14))
	try(props, SRC.Car, 1.3, 180, Vector3.new(-168.5, GY, skyZ0 + 40))
	try(props, SRC.Car, 1.3, 0, Vector3.new(-168.5, GY, agencyZ0 + 52))
	try(props, SRC.Taxi, 1.3, 0, Vector3.new(-168.5, GY, shopZ0 + 20))
	-- street trees, lamps and benches down the sidewalk: only where there is room
	for sz = S0 + 6, rowEnd - 6, 26 do
		try(props, SRC.PlanterTree, 1.1, 0, Vector3.new(-185.5, GY, sz))
	end
	for sz = S0 + 19, rowEnd, 52 do
		try(props, KIT.Prop_hero_city_StreetLamp, 1.6, facing(side), Vector3.new(-182.5, GY, sz))
		try(
			props,
			KIT.Prop_shared_VendingMachine,
			1.5,
			facing(side),
			Vector3.new(-188.5, GY, sz + 7)
		)
	end

	-- the exam robot at the far end, turned to the lane and the throwers, among rubble
	do
		local rz = (rowEnd + S1) / 2
		place(city, SRC.Robot, 2.6, -70, Vector3.new(-200, GY, rz))
		for i = 1, 12 do
			local s = rng:NextNumber(3, 8)
			local ax, dz =
				rng:NextNumber(168, 232),
				rng:NextNumber(-(S1 - rowEnd) / 2 + 2, (S1 - rowEnd) / 2 - 2)
			local slab = block(
				city,
				"Rubble",
				Vector3.new(s, s * rng:NextNumber(0.3, 0.6), s * rng:NextNumber(0.7, 1.4)),
				CFrame.new(-ax, GY + s * 0.15, rz + dz)
					* CFrame.Angles(
						math.rad(rng:NextNumber(-24, 24)),
						math.rad(rng:NextNumber(0, 180)),
						math.rad(rng:NextNumber(-24, 24))
					),
				if i % 3 == 0 then Color3.fromRGB(120, 126, 140) else Color3.fromRGB(160, 164, 174),
				C
			)
			slab.CastShadow = false
		end
	end
end

-- ================================================================================== ledges and rims
for _, side in { -1, 1 } do
	-- hero billboards on the ledge, turned to the lane
	for _, z in { Z0 + 120, Z0 + 230, Z0 + 330 } do
		local ax = ledgeAx(side) + 2
		local b = place(
			props,
			SRC.HeroBillboard,
			1.6,
			facing(side),
			Vector3.new(side * ax, ground(side, ax, z + side * 14) + 0.6, z + side * 14)
		)
		footing(props, b, Color3.fromRGB(120, 126, 140), C, 6, 1.0)
	end
	-- the skyline: towers on the rim, each on its own footing
	for i, t in
		{
			{ SRC.Apartment, 1.7, Z0 + 70 },
			{ SRC.Skyscraper, 1.8, Z0 + 180 },
			{ SRC.Apartment, 1.6, Z0 + 290 },
		}
	do
		local ax = rimAx(side) + 26 + (i % 2) * 8
		local zz = t[3] + side * 22
		local b = place(
			city,
			t[1],
			t[2],
			facing(side),
			Vector3.new(side * ax, ground(side, ax, zz) + 3, zz)
		)
		footing(city, b, Color3.fromRGB(150, 156, 170), C, 18, 1.04)
	end
	-- trees: a line on the ledge, a wood on the rim
	for z = Z0 + 50, Z1 - 10, 30 do
		plant(
			trees,
			JUNGLE.TreeBroad,
			side,
			ledgeAx(side) + rng:NextNumber(-7, 7),
			z + rng:NextNumber(-6, 6),
			rng:NextNumber(0.8, 1.1)
		)
	end
	scatter({
		parent = trees,
		templates = { JUNGLE.BushLeafy },
		count = 9,
		side = side,
		ax = { ledgeAx(side) - 10, ledgeAx(side) + 9 },
		z = { Z0 + 40, Z1 },
		scale = { 1.2, 1.8 },
		sink = 0.6,
		soft = true,
	})
	for z = Z0 + 30, Z1 - 10, 24 do
		plant(
			trees,
			if rng:NextNumber() < 0.5 then JUNGLE.TreeBroad else JUNGLE.TreeTall,
			side,
			rimAx(side) + rng:NextNumber(-5, 10),
			z + rng:NextNumber(-8, 8),
			rng:NextNumber(1.3, 1.9)
		)
	end
end

floor({
	title = "HERO ACADEMY",
	accent = Color3.fromRGB(226, 54, 54),
	strip = function(tile: number, track: number)
		if (tile + track) % 2 == 0 then
			return Color3.fromRGB(40, 100, 206), Color3.fromRGB(110, 160, 240)
		end
		return Color3.fromRGB(96, 150, 236), Color3.fromRGB(170, 204, 250)
	end,
	kerb = YELLOW,
	paving = Color3.fromRGB(206, 210, 218),
	pavingTex = Color3.fromRGB(232, 234, 240),
})
return finish()
