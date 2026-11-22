-- LIB: side_lib
-- zone_13_one_punch.luau - zone 13, "City Z" (One Punch Man), on the slim lane (v2, 2026-11-22).
-- z 4480..4840 (map id city_z, no zone data yet), lane floor y -48, lane edges x +-100. Run with
--   python tools/studio/zones/run_zone.py build 13
-- then lane_border.luau. Safe to run again. v1 (zone_lib, the 320-wide lane): MapArchive.Zone13_v1_canyon
-- and tools/studio/retired/zone_13_one_punch_v1.luau.
--
-- A city that monsters keep wrecking, between grey concrete walls: a road along the lane each side.
--   +X, what still stands: the supermarket, the hero association's armoured headquarters, the bald
--     hero's cheap apartment block, a corner store, and his statue on a plinth facing the throwers
--   -X, the ghost town on cracked ground: a ruined tower, a sheared-off office block, the meteor in
--     its crater, the giant crab monster bursting out of the street, another ruin, the cyborg's
--     statue at the far end; flipped cars, hazard barriers, bent poles, rubble
--   hero billboards and a skyline on the shelves (whole on +X, broken on -X)
local SS = game:GetService("ServerStorage")
local map = workspace.Map
local SRC = SS.StoreAssets.Zone13_OnePunch
local Z4 = SS.StoreAssets.Zone04_MHA
local Z10 = SS.StoreAssets.Zone10_Chainsaw
local JUNGLE = SS.StoreAssets.Zone01_Naruto
local ID = "city_z"
local LY, HALF, Z0, Z1 = P.LY, P.HALF, 4480, 4840
local rng = Random.new(13107)

local ASPHALT = Color3.fromRGB(62, 64, 72)
local SIDEWALK = Color3.fromRGB(176, 176, 184)
local LINE = Color3.fromRGB(244, 240, 220)
local YELLOW = Color3.fromRGB(250, 208, 50)
local RED = Color3.fromRGB(214, 48, 48)
local CRACK = Color3.fromRGB(30, 30, 36)
local STEEL = Color3.fromRGB(90, 92, 104)
local CONCRETE = Color3.fromRGB(140, 142, 150)
local C = Enum.Material.Concrete
local GY = P.TERRACE_Y + 0.4

local function facing(side: number): number
	return if side > 0 then 90 else -90 -- a squared template fronts to -Z: turn it to the lane
end
local city: Folder, props: Folder -- set below, once the zone's folder is cleared
local function building(
	template: Instance,
	side: number,
	scale: number,
	ax: number,
	z: number
): Model?
	local m = front(city, template, side, scale, ax, z)
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
local function parked(template: Instance, scale: number, x: number, z: number, yaw: number)
	still(make(props, template, scale, yaw, Vector3.new(x, GY - 0.2, z)), false)
end
local function plinth(x: number, z: number, radius: number, rim: Color3): number
	cylinder(city, "Plinth", radius * 2, 3, CFrame.new(x, GY + 1.5, z), STEEL, C).CastShadow = false
	cylinder(city, "PlinthRim", radius * 2 + 1.2, 0.5, CFrame.new(x, GY + 3.1, z), rim)
	claim(rect(x - radius - 1, x + radius + 1, z - radius - 1, z + radius + 1, "Plinth"))
	return GY + 3.2
end
-- a red and white hazard barrier
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

-- ---------------------------------------------------------------------------------- the zone's folder
local scenery = map.Scenery
local archive = SS:FindFirstChild("MapArchive") or folder(SS, "MapArchive")
if not archive:FindFirstChild("Zone13_v1_canyon") then
	local keep = scenery["Zone_" .. ID]:Clone()
	keep.Name = "Zone13_v1_canyon"
	keep:SetAttribute(
		"Note",
		"Zone 13 (City Z) v1 on the 320-wide lane, before the slim-lane rebuild (2026-11-22). Never delete."
	)
	keep.Parent = archive
end
local root = scenery["Zone_" .. ID]
root:ClearAllChildren()
root:SetAttribute("Theme", "City Z (One Punch Man), zone_13_one_punch.luau v2 on side_lib")
local ground = folder(root, "Ground")
city = folder(root, "City")
props = folder(root, "Props")
local trees = folder(root, "Trees")

-- ---------------------------------------------------------------------------------- the ground
local STYLE = {
	stone = CONCRETE,
	material = C,
	band = STEEL,
	cap = Color3.fromRGB(184, 184, 192),
	capMaterial = C,
	rail = STEEL,
	buttress = 38,
}
if DO_TERRAIN then
	sideGround(Z0, Z1)
end
claimGates(Z0, Z1)
for _, s in { -1, 1 } do
	box(ground, "Kerb", s * HALF, s * P.KERB_OUT, LY - 2, LY + 3, Z0, Z1, YELLOW, C)
	revetment(ground, s, Z0, Z1, STYLE)
	pave(
		ground,
		s * P.KERB_OUT,
		s * P.STREET_OUT,
		Z0,
		Z1,
		GY - 0.2,
		ASPHALT,
		Enum.Material.Asphalt,
		"Road"
	)
	pave(
		ground,
		s * P.STREET_OUT,
		s * (P.TERRACE_OUT - P.BATTER + 0.5),
		Z0,
		Z1,
		GY,
		SIDEWALK,
		C,
		"Sidewalk"
	)
	for z = Z0 + 6, Z1 - 10, 14 do
		paint(ground, s * 109.7, s * 110.3, z, z + 7, LINE, GY - 0.2)
	end
	table.insert(claims, rect(s * HALF, s * P.STREET_OUT, Z0, Z1, "Road"))
end
-- the ghost town's ground is cracked
for _ = 1, 22 do
	local x, z = -rng:NextNumber(P.KERB_OUT + 2, 164), rng:NextNumber(Z0 + 50, Z1 - 6)
	block(
		ground,
		"Crack",
		Vector3.new(0.7, 0.2, rng:NextNumber(8, 22)),
		CFrame.new(x, GY + 0.12, z) * CFrame.Angles(0, math.rad(rng:NextNumber(0, 180)), 0),
		CRACK
	).CastShadow =
		false
end

-- utility poles down the sidewalk's edge; `lean` knocks them askew
local function poles(side: number, zs: { number }, lean: { number })
	for i, pz in zs do
		local pole =
			prop(Z10.UtilityPole, 1.8, side * (P.STREET_OUT + 5), pz, facing(side), { soft = 4 })
		if pole and lean[i] then
			pole:PivotTo(pole:GetPivot() * CFrame.Angles(0, 0, math.rad(lean[i])))
		end
	end
end

-- ================================================================================== +X: what still stands
building(SRC.Supermarket, 1, 1.6, 137, 4567)
building(SRC.HeroHQ, 1, 1.2, 139, 4611)
building(SRC.CheapApartment, 1, 1.5, 135, 4651)
building(Z4.Konbini, 1, 1.3, 149.2, 4690)
prop(Z10.VendingRow, 1.3, P.STREET_OUT + 6, 4590, facing(1))
prop(Z4.BusStop, 1.2, P.STREET_OUT + 7, 4672, facing(1))
parked(Z4.Car, 1.2, 110, 4556, 0)
parked(Z4.Taxi, 1.2, 110, 4596, 180)
parked(Z10.SirenCar, 1.2, 110, 4630, 0)
parked(Z4.Bus, 1.35, 110, 4700, 0)
poles(1, { 4548, 4628, 4708 }, { [2] = -8 })
-- the bald hero on his plinth, facing the throw stage
do
	local top = plinth(142, 4782, 15, YELLOW)
	still(make(city, SRC.BaldHero, 1.3, 0, Vector3.new(142, top, 4782)), true)
end

-- ================================================================================== -X: the ghost town
building(SRC.RuinedTower, -1, 1.4, 138, 4562)
building(SRC.CollapsedBlock, -1, 1.4, 134, 4602)
-- the meteor in its crater: rings of broken ground about it
do
	local mx, mz = -142, 4652
	for i, r in { 21, 16 } do
		cylinder(
			ground,
			"CraterRing",
			r * 2,
			0.5,
			CFrame.new(mx, GY + 0.1 + i * 0.25, mz),
			if i == 1 then Color3.fromRGB(96, 90, 86) else CRACK,
			Enum.Material.Slate
		).CastShadow =
			false
	end
	claim(rect(mx - 22, mx + 22, mz - 22, mz + 22, "Crater"))
	still(make(city, SRC.Meteor, 1.25, 20, Vector3.new(mx, GY - 2.5, mz)), true)
end
-- the crab monster bursting out of the road beyond it
do
	local cx, cz = -145, 4702
	claim(rect(cx - 17, cx + 17, cz - 17, cz + 17, "CrabMonster"))
	still(make(city, SRC.CrabMonster, 0.95, 100, Vector3.new(cx, GY - 0.4, cz)), true)
end
building(SRC.RuinedTower, -1, 1.15, 142, 4742)
-- the cyborg on his plinth, facing the throw stage
do
	local top = plinth(-142, 4796, 15, RED)
	still(make(city, SRC.Cyborg, 1.7, 0, Vector3.new(-142, top, 4796)), true)
end
-- wreckage: flipped cars, barriers, the wall with the fist's dent, bent poles, rubble
prop(SRC.FlippedCar, 1.3, -(P.STREET_OUT + 8), 4584, 0)
prop(SRC.FlippedCar, 1.3, -(P.STREET_OUT + 10), 4730, 90)
barrier(-110, 4620, 12)
barrier(-110, 4688, -10)
prop(SRC:FindFirstChild("PunchWall"), 1.0, -(P.STREET_OUT + 9), 4621, facing(-1))
poles(-1, { 4552, 4679, 4772 }, { 12, -9, 10 })
scatter({
	parent = props,
	templates = { SRC.Rubble },
	count = 8,
	side = -1,
	ax = { P.STREET_OUT + 4, 164 },
	z = { Z0 + 50, Z1 - 6 },
	scale = { 0.5, 0.9 },
})

-- ================================================================================== the shelves
local SHELF = P.REVET_OUT + 1.5
for _, s in { -1, 1 } do
	for i, z in { 4560, 4700 } do
		local b = front(props, Z4.HeroBillboard, s, 1.2, SHELF + 6, z)
		if b then
			still(b, false)
			if s < 0 and i == 2 then
				b:PivotTo(b:GetPivot() * CFrame.Angles(math.rad(10), 0, 0)) -- hanging askew over the ghost town
			end
		end
	end
	local skyline = if s > 0
		then { { Z4.Apartment, 1.0, 4630 }, { Z4.Skyscraper, 1.0, 4770 } }
		else { { SRC.RuinedTower, 0.85, 4630 }, { SRC.CollapsedBlock, 0.8, 4770 } }
	for _, t in skyline do
		building(t[1], s, t[2], SHELF, t[3])
	end
	for _, z in { 4520, 4806 } do
		local t = put(
			trees,
			JUNGLE.TreeBroad,
			0.85,
			rng:NextInteger(0, 3) * 90,
			s * 192,
			z,
			{ soft = 3.4 }
		)
		if t then
			still(t, false)
		end
	end
end
-- rubble and broken chunks on the ghost town's shelf
scatter({
	parent = props,
	templates = { SRC.Rubble },
	count = 4,
	side = -1,
	ax = { 184, 200 },
	z = { Z0 + 20, Z1 - 10 },
	scale = { 0.5, 0.8 },
})

-- ---------------------------------------------------------------------------------- the lane's floor
floorKit({
	id = ID,
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

markSlim(root, Z0, Z1)
return string.format("zone 13 City Z v2: %d parts\n%s", #partsOf(root), sideReport(root))
