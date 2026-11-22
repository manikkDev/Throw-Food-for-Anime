-- RETIRED 2026-11-22: zone 5 on the old 320-wide lane (zone_lib). Kept for its content and numbers;
-- zones/zone_05_blue_lock.luau (side_lib) builds the zone now.
-- zone_05_blue_lock.luau - zone 5, "Blue Lock Facility" (Blue Lock), z 1600..1960. Config id still
-- hero_city. Run: python tools/studio/zones/run_zone.py build 5 [--no-terrain]
-- (rebuilt 2026-11-22: the first version was nine models; its stands were bare coloured blocks and
-- its facility was scaled until it stood 77 studs inside the wall.)
--
-- The picture: a stadium. The lane is the pitch (mown stripes, white lines). Either side, two big
-- roofed grandstands whose roofs meet the ledge, and a touchline in front of them: LED boards,
-- dugouts, practice goals, balls, a camera tower. Beyond the stands:
--   +X (left from the throw stage): the golden trophy on its plinth, the team bus.
--   -X: the golden striker frozen in a bicycle kick, facing the throwers.
-- Above: name boards on the ledges; on the rims floodlights, jumbotrons, flags, and the pentagon
-- fortress itself looking down on the pitch from +X, the training hall from -X.
-- Templates: StoreAssets.Zone05_BlueLock (all generate_mesh, squared, fronting -Z).
local P = Enum.Material.Pavement
local C = Enum.Material.Concrete
local root = begin({
	n = 5,
	id = "hero_city",
	title = "Blue Lock Facility (Blue Lock)",
	src = "Zone05_BlueLock",
	now = {
		face = { [-1] = 236, [1] = 236 },
		rise = { [-1] = 6, [1] = 6 },
		ledgeW = { [-1] = 20, [1] = 20 },
		ledgeY = { [-1] = 16, [1] = 16 }, -- the stands' roofs meet it
		top = { [-1] = 62, [1] = 62 },
	},
	prev = { -- zone 4's city
		face = { [-1] = 236, [1] = 236 },
		rise = { [-1] = 6, [1] = 6 },
		ledgeW = { [-1] = 26, [1] = 26 },
		ledgeY = { [-1] = 8, [1] = 8 },
		top = { [-1] = 62, [1] = 62 },
	},
	-- zone 4's clean concrete carries on: navy asphalt came out an olive, mottled brown
	mats = {
		rock = C,
		prevRock = C,
		terrace = P,
		prevTerrace = P,
		ledge = P,
		top = Enum.Material.LeafyGrass,
	},
	wobble = 0.2,
})
local stands = folder(root, "Stands")
local sights = folder(root, "Sights")
local groundF = folder(root, "Ground")
local props = folder(root, "Props")
local trees = folder(root, "Trees")
local JUNGLE = STORE.Zone01_Naruto

local NAVY = Color3.fromRGB(26, 36, 80)
local BLUE = Color3.fromRGB(34, 120, 236)
local CYAN = Color3.fromRGB(70, 220, 255)
local WHITE = Color3.fromRGB(240, 244, 250)
local STEEL = Color3.fromRGB(60, 70, 110)
local TURF = Color3.fromRGB(64, 156, 76)
local S0, S1 = Z0 + 82, Z1 + 10 -- the terrace clear of both gates' pillars
local GY = TERRACE + 0.35 -- the top of the paving
local STAND = 2.6
local standW = sizeOf(SRC.Grandstand).X * STAND
local standD = sizeOf(SRC.Grandstand).Z * STAND
local LED =
	{ "BLUE LOCK", "EGOIST", "No.1 STRIKER", "GOAL!", "BLUE LOCK", "DEVOUR", "WORLD'S BEST" }

-- a round plinth with a glowing rim, for the two golden set pieces
local function plinth(x: number, z: number, radius: number)
	local p = cylinder(sights, "Plinth", radius * 2, 3, CFrame.new(x, GY + 1.5, z), NAVY, C)
	p.CastShadow = false
	cylinder(
		sights,
		"PlinthGlow",
		radius * 2 + 1.2,
		0.5,
		CFrame.new(x, GY + 3.1, z),
		CYAN,
		Enum.Material.Neon
	)
	reserve(x, z, radius, radius, LY, GY + 4, "a plinth")
end

for _, side in { -1, 1 } do
	-- ------------------------------------------------------------------------------ stands and touchline
	pave(groundF, side, 163.5, 240, S0 - 4, S1 + 2, NAVY, C)
	local z = S0 + 2
	local standsZ0 = z
	z = row({
		parent = stands,
		side = side,
		z = z,
		gap = 3,
		list = { { SRC.Grandstand, STAND }, { SRC.Grandstand, STAND } },
	})
	local standsZ1 = z - 3
	local front = footOver(side, standsZ0, standsZ1) - 1.5 - standD -- where the stands' fronts are
	local midZ = (standsZ0 + standsZ1) / 2
	-- the touchline: turf from the lane's edge to the stands, with its white line
	pave(
		groundF,
		side,
		163.5,
		front - 0.5,
		standsZ0 - 2,
		standsZ1 + 2,
		TURF,
		Enum.Material.Grass,
		GY + 0.1
	)
	paint(groundF, side, 167.6, 168.3, standsZ0 - 2, standsZ1 + 2, WHITE, GY + 0.3)

	-- LED boards down the lane's edge, read from the pitch
	do
		local n = 7
		local seg = (standsZ1 - standsZ0) / n
		for i = 0, n - 1 do
			local bz = standsZ0 + (i + 0.5) * seg
			local dark = i % 2 == 0
			local board = sign(
				props,
				LED[(i + (if side > 0 then 0 else 3)) % #LED + 1],
				seg - 3,
				5,
				CFrame.new(side * 164.6, GY + 2.6, bz) * CFrame.Angles(0, math.rad(facing(side)), 0),
				if dark then NAVY else CYAN,
				if dark then CYAN else NAVY
			)
			board.Material = Enum.Material.Neon
			board.Name = "LedBoard"
			block(
				props,
				"LedBoardFoot",
				Vector3.new(1.6, 0.6, seg - 3),
				CFrame.new(side * 164.6, GY + 0.3, bz),
				NAVY
			)
		end
	end
	-- a dugout in front of each stand; a camera tower where the two stands meet
	for i = 0, 1 do
		local sz = standsZ0 + standW * (i + 0.5) + i * 3
		place(props, SRC.Dugout, 2.0, facing(side), Vector3.new(side * (front - 6), GY, sz))
		try(props, SRC.TrainingSet, 1.6, 0, Vector3.new(side * (front - 7), GY, sz + 22))
		try(props, SRC.TrainingSet, 1.6, 180, Vector3.new(side * (front - 7), GY, sz - 22))
	end
	place(props, SRC.CameraTower, 1.3, facing(side), Vector3.new(side * (front - 7.5), GY, midZ))
	-- practice goals at the touchline's two ends, facing each other
	place(props, SRC.Goal, 1.4, 0, Vector3.new(side * (front - 8.5), GY, standsZ0 + 5))
	place(props, SRC.Goal, 1.4, 180, Vector3.new(side * (front - 8.5), GY, standsZ1 - 5))
	for _ = 1, 9 do
		local ball = try(
			props,
			SRC.Football,
			0.16,
			rng:NextInteger(0, 359),
			Vector3.new(
				side * rng:NextNumber(170, front - 3),
				GY,
				rng:NextNumber(standsZ0 + 14, standsZ1 - 14)
			)
		)
		if ball then
			ball:SetAttribute("Soft", true)
		end
	end

	-- ------------------------------------------------------------------------------ beyond the stands
	local e0 = standsZ1 + 4
	local ez = (e0 + S1) / 2
	if side > 0 then
		-- the trophy on its plinth, the team bus by the lane
		plinth(side * 204, ez, 20)
		place(sights, SRC.Trophy, 2.2, 0, Vector3.new(side * 204, GY + 3.2, ez), { over = true })
		try(props, SRC.TeamBus, 1.5, 0, Vector3.new(side * 171, GY, ez))
	else
		-- the striker on his plinth, facing the throwers
		plinth(side * 202, ez, 23)
		place(
			sights,
			SRC.StrikerStatue,
			2.0,
			0,
			Vector3.new(side * 202, GY + 3.2, ez),
			{ over = true }
		)
	end
	-- cyan lines round the end plaza
	for _, r in { { 166, 238, e0, e0 + 0.8 }, { 166, 238, S1 - 0.8, S1 }, { 166, 166.8, e0, S1 } } do
		paint(groundF, side, r[1], r[2], r[3], r[4], CYAN, GY + 0.3).Material = Enum.Material.Neon
	end

	-- ------------------------------------------------------------------------------ ledge and rim
	-- the name, once over each stand, on the ledge
	for i = 0, 1 do
		local bz = standsZ0 + standW * (i + 0.5) + i * 3
		local ax = ledgeAx(side) + 4
		local by = ground(side, ax, bz)
		local board = sign(
			props,
			"BLUE LOCK",
			76,
			17,
			CFrame.new(side * ax, by + 13, bz) * CFrame.Angles(0, math.rad(facing(side)), 0),
			NAVY,
			CYAN
		)
		board.Name = "NameBoard"
		for _, dz in { -30, 30 } do
			block(
				props,
				"NameBoardLeg",
				Vector3.new(1.8, 7, 1.8),
				CFrame.new(side * (ax + 0.4), by + 3, bz + dz),
				STEEL,
				Enum.Material.Metal
			)
		end
		block(
			props,
			"NameBoardEdge",
			Vector3.new(1.2, 18.2, 77.2),
			CFrame.new(side * (ax + 0.5), by + 13, bz),
			CYAN,
			Enum.Material.Neon
		)
		reserve(side * ax, bz, 3, 40, by - 2, by + 30, "a name board")
	end
	-- on the rim: the fortress (+X) or the training hall (-X) over the stands' middle
	do
		local ax = rimAx(side) + 34
		local big = if side > 0 then SRC.Fortress else SRC.TrainingHall
		local s = if side > 0 then 1.9 else 2.4
		local m = place(
			sights,
			big,
			s,
			facing(side),
			Vector3.new(side * ax, ground(side, ax, midZ) + 4, midZ)
		)
		footing(sights, m, NAVY, C, 24, 1.03)
	end
	-- floodlights at the stands' two ends, a jumbotron over the end plaza
	for _, fz in { standsZ0 + 6, standsZ1 - 18 } do
		local ax = rimAx(side) + 6
		local f = place(
			props,
			SRC.Floodlight,
			2.8,
			facing(side),
			Vector3.new(side * ax, ground(side, ax, fz) + 1, fz)
		)
		footing(props, f, STEEL, C, 10, 1.1)
	end
	do
		local ax = rimAx(side) + 10
		local j = place(
			props,
			SRC.Jumbotron,
			1.5,
			facing(side),
			Vector3.new(side * ax, ground(side, ax, ez) + 1.5, ez)
		)
		footing(props, j, STEEL, C, 10, 1.0)
	end
	-- flags along the rim, where nothing else stands
	for fz = Z0 + 50, Z1 - 10, 44 do
		local ax = rimAx(side) + 2
		local gy = ground(side, ax, fz)
		local r = {
			cx = side * ax,
			cz = fz + 5,
			hx = 2,
			hz = 8,
			rx = 1,
			rz = 0,
			y0 = gy - 2,
			y1 = gy + 40,
			name = "a flag",
		}
		if not blockedBy(r) then
			local pole = cylinder(
				props,
				"FlagPole",
				0.9,
				30,
				CFrame.new(side * ax, gy + 14, fz),
				WHITE,
				Enum.Material.Metal
			)
			pole.CastShadow = false
			local flag = block(
				props,
				"Flag",
				Vector3.new(0.3, 7, 11),
				CFrame.new(side * ax, gy + 25, fz + 6),
				if (fz // 44) % 2 == 0 then BLUE else CYAN
			)
			flag.CastShadow = false
			table.insert(claims, r)
		end
	end
	-- a few trees on the rim, behind the lights
	for tz = Z0 + 30, Z1 - 10, 36 do
		plant(
			trees,
			if rng:NextNumber() < 0.5 then JUNGLE.TreeBroad else JUNGLE.TreeTall,
			side,
			rimAx(side) + rng:NextNumber(20, 30),
			tz + rng:NextNumber(-8, 8),
			rng:NextNumber(1.4, 2.0)
		)
	end
end

floor({
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
return finish()
