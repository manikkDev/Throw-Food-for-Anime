-- RETIRED 2026-11-22: zone 14 on the old 320-wide lane (zone_lib). Kept for its content and numbers;
-- zones/zone_14_bleach.luau (side_lib) builds the zone now.
-- zone_14_bleach.luau - zone 14, "Soul Society" (Bleach), z 4840..5200. Map id soul_society (no zone
-- data yet). Run: python tools/studio/zones/run_zone.py build 14 [--no-terrain]
-- (rebuilt 2026-11-22: the first version was two halls, a gatehouse, a tower and two swords on bare
-- stone; its white walls vanished against white cliffs.)
--
-- The picture: the white city of the swordsmen, under grey rock so that its white walls show.
--   +X (left from the throw stage), the court: the great gatehouse, the captains' hall, the tiered
--     white tower, the dojo with its sword racks, and the giant sword in its plinth facing the
--     throwers.
--   -X, the outer town: the sweet shop, a hall, the tower on its hill, a second dojo, pines and
--     lanterns, and the giant hollow mask at the far end.
--   Long white walls with orange tiled caps down both ledges; black butterflies in the air; pines
--   on the rims.
-- Templates: StoreAssets.Zone14_Bleach (all generate_mesh, squared, fronting -Z).
local G = Enum.Material.LeafyGrass
local root = begin({
	n = 14,
	id = "soul_society",
	title = "Soul Society (Bleach)",
	src = "Zone14_Bleach",
	now = {
		face = { [-1] = 236, [1] = 236 },
		rise = { [-1] = 6, [1] = 6 },
		ledgeW = { [-1] = 28, [1] = 28 },
		ledgeY = { [-1] = 10, [1] = 10 },
		top = { [-1] = 60, [1] = 60 },
	},
	prev = { -- zone 13's city
		face = { [-1] = 236, [1] = 236 },
		rise = { [-1] = 6, [1] = 6 },
		ledgeW = { [-1] = 26, [1] = 26 },
		ledgeY = { [-1] = 8, [1] = 8 },
		top = { [-1] = 62, [1] = 62 },
	},
	-- the hills' grey rock: white walls and white buildings show against it (they vanished on white)
	mats = {
		rock = Enum.Material.Rock,
		prevRock = Enum.Material.Concrete,
		terrace = Enum.Material.Limestone,
		prevTerrace = Enum.Material.Pavement,
		ledge = G,
		top = G,
	},
	wobble = 0.3,
})
local city = folder(root, "City")
local groundF = folder(root, "Ground")
local walls = folder(root, "Walls")
local props = folder(root, "Props")
local trees = folder(root, "Trees")
local air = folder(root, "Butterflies")
local JUNGLE = STORE.Zone01_Naruto

local PAVE = Color3.fromRGB(206, 200, 188)
local GRAVEL = Color3.fromRGB(232, 228, 216)
local WHITE = Color3.fromRGB(244, 240, 232)
local TILE = Color3.fromRGB(226, 118, 44)
local WOOD = Color3.fromRGB(96, 66, 46)
local STONE = Color3.fromRGB(128, 126, 124)
local S0, S1 = Z0 + 82, Z1 + 10 -- the terrace clear of both gates' pillars
local GY = TERRACE + 0.35 -- the top of the paving

local function plinth(x: number, z: number, radius: number)
	for i, r in { radius, radius - 4 } do
		local ring = cylinder(
			city,
			"Plinth",
			r * 2,
			1.4,
			CFrame.new(x, GY + i * 1.3 - 0.6, z),
			if i == 2 then WHITE else STONE,
			Enum.Material.Slate
		)
		ring.CastShadow = false
	end
	reserve(x, z, radius, radius, LY, GY + 4, "a plinth")
end
-- a raked gravel court in front of a building: pale ground with darker raked lines
local function court(side: number, z0: number, z1: number)
	paint(groundF, side, 166, 196, z0, z1, GRAVEL, GY + 0.25).Material = Enum.Material.Sand
	for ax = 170, 194, 6 do
		paint(groundF, side, ax, ax + 0.6, z0 + 2, z1 - 2, Color3.fromRGB(206, 200, 186), GY + 0.35)
	end
end

-- ================================================================================== +X: the court
do
	local side = 1
	pave(groundF, side, 163.5, 240, S0 - 4, S1 + 2, PAVE, Enum.Material.Slate)
	local z = S0 + 2
	z = row({ parent = city, side = side, z = z, gap = 4, list = { { SRC.Gatehouse, 1.6 } } })
	local hallZ0 = z
	z = row({
		parent = city,
		side = side,
		z = z,
		gap = 4,
		list = { { SRC.Hall, 2.0 }, { SRC.Tower, 2.0 } },
	})
	local dojoZ0 = z
	z = row({ parent = city, side = side, z = z, gap = 4, list = { { SRC.Dojo, 1.8 } } })
	local rowEnd = z - 4
	-- the dojo's raked court with its sword racks
	court(side, dojoZ0 + 2, rowEnd - 2)
	place(props, SRC.SwordRack, 1.5, facing(side), Vector3.new(172, GY, dojoZ0 + 12))
	place(props, SRC.SwordRack, 1.5, facing(side), Vector3.new(172, GY, rowEnd - 12))
	try(props, SRC.Pine, 1.1, 30, Vector3.new(176, GY - 1.2, hallZ0 + 2), { fit = 0.5 })
	for lz = S0 + 14, rowEnd, 40 do
		try(props, SRC.Lantern, 1.4, 0, Vector3.new(167, GY, lz))
	end
	-- the giant sword in its plinth, facing the throw stage
	local kz = (rowEnd + 4 + S1) / 2
	plinth(200, kz, 20)
	place(city, SRC.Katana, 2.2, 0, Vector3.new(200, GY + 2.4, kz), { over = true })
end

-- ================================================================================== -X: the outer town
do
	local side = -1
	pave(groundF, side, 163.5, 240, S0 - 4, S1 + 2, PAVE, Enum.Material.Slate)
	local z = S0 + 2
	local shopZ0 = z
	z = row({
		parent = city,
		side = side,
		z = z,
		gap = 4,
		list = { { SRC.SweetShop, 2.0 }, { SRC.Hall, 1.8 } },
	})
	local hillZ0 = z
	z = row({ parent = city, side = side, z = z, gap = 4, list = { { SRC.HillTower, 2.0 } } })
	local dojoZ0 = z
	z = row({ parent = city, side = side, z = z, gap = 4, list = { { SRC.Dojo, 1.7 } } })
	local rowEnd = z - 4
	court(side, dojoZ0 + 2, rowEnd - 2)
	place(props, SRC.SwordRack, 1.5, facing(side), Vector3.new(-172, GY, dojoZ0 + 26))
	try(
		props,
		KIT.Prop_sakura_schoolyard_Bench,
		1.5,
		facing(side),
		Vector3.new(-172, GY, shopZ0 + 30)
	)
	try(props, SRC.Pine, 1.2, 80, Vector3.new(-178, GY - 1.2, hillZ0 + 2), { fit = 0.5 })
	try(props, SRC.Pine, 1.0, 200, Vector3.new(-176, GY - 1.2, dojoZ0 - 1), { fit = 0.5 })
	for lz = S0 + 30, rowEnd, 40 do
		try(props, SRC.Lantern, 1.4, 0, Vector3.new(-167, GY, lz))
	end
	-- the hollow mask on its plinth, facing the throw stage
	local mz = (rowEnd + 4 + S1) / 2
	plinth(-200, mz, 21)
	place(city, SRC.HollowMask, 2.2, 0, Vector3.new(-200, GY + 2.4, mz), { over = true })
end

-- ================================================================================== walls, ledges, rims
for _, side in { -1, 1 } do
	-- the city's wall: white plaster on a grey footing, a dark beam, an orange tiled cap
	do
		local len = Z1 - Z0 - 44
		local mid = (Z0 + Z1) / 2 + 2
		local ax = ledgeAx(side) + 2
		local y = ground(side, ax, mid)
		block(
			walls,
			"Footing",
			Vector3.new(7, 7, len),
			CFrame.new(side * ax, y + 2.5, mid),
			STONE,
			Enum.Material.Slate
		)
		block(walls, "Wall", Vector3.new(4, 14, len), CFrame.new(side * ax, y + 13, mid), WHITE)
		block(
			walls,
			"Beam",
			Vector3.new(5.5, 2, len),
			CFrame.new(side * ax, y + 20, mid),
			WOOD,
			Enum.Material.Wood
		)
		block(walls, "Cap", Vector3.new(11, 3, len), CFrame.new(side * ax, y + 22.5, mid), TILE)
		block(
			walls,
			"Ridge",
			Vector3.new(4.5, 2.5, len),
			CFrame.new(side * ax, y + 25, mid),
			TILE:Lerp(Color3.new(0, 0, 0), 0.3)
		)
		for pz = mid - len / 2 + 2, mid + len / 2 - 2, 30 do
			block(
				walls,
				"Post",
				Vector3.new(5.5, 21, 3),
				CFrame.new(side * ax, y + 10.5, pz),
				WOOD,
				Enum.Material.Wood
			)
		end
		reserve(side * ax, mid, 6, len / 2, y - 4, y + 30, "the city's wall")
	end
	-- pines before the wall on the ledge, pines and cedars on the rim
	for tz = Z0 + 40, Z1 - 10, 36 do
		plant(
			trees,
			SRC.Pine,
			side,
			ledgeAx(side) - 8 + rng:NextNumber(-2, 2),
			tz + rng:NextNumber(-6, 6),
			rng:NextNumber(0.8, 1.1)
		)
	end
	for tz = Z0 + 24, Z1 - 6, 26 do
		local roll = rng:NextNumber()
		local template = if roll < 0.5
			then SRC.Pine
			elseif roll < 0.8 then STORE.Zone02_DemonSlayer.Cedar
			else JUNGLE.TreeBroad
		plant(
			trees,
			template,
			side,
			rimAx(side) + rng:NextNumber(-5, 10),
			tz + rng:NextNumber(-7, 7),
			rng:NextNumber(1.4, 2.0)
		)
	end
	-- black butterflies, in a loose flight over each street
	for i = 1, 9 do
		local b = make(
			air,
			SRC.Butterfly,
			2.6,
			rng:NextInteger(0, 359),
			Vector3.new(
				side * rng:NextNumber(166, 200),
				TERRACE + rng:NextNumber(14, 40),
				Z0 + 60 + i * 34 + rng:NextNumber(-8, 8)
			)
		)
		b:PivotTo(
			b:GetPivot()
				* CFrame.Angles(
					math.rad(rng:NextNumber(-30, 30)),
					0,
					math.rad(rng:NextNumber(-30, 30))
				)
		)
		b:SetAttribute("AuditSkip", true) -- in the air by design
	end
end

floor({
	title = "SOUL SOCIETY",
	accent = Color3.fromRGB(236, 120, 40),
	strip = function(tile: number, track: number)
		if (tile + track) % 2 == 0 then
			return Color3.fromRGB(236, 124, 44), Color3.fromRGB(250, 178, 110)
		end
		return Color3.fromRGB(248, 240, 222), Color3.fromRGB(255, 252, 242)
	end,
	kerb = Color3.fromRGB(34, 34, 40),
	paving = Color3.fromRGB(214, 206, 192),
	pavingTex = Color3.fromRGB(238, 232, 220),
})
return finish()
