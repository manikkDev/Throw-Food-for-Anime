-- LIB: side_lib
-- zone_04_mha.luau - zone 4, "Hero Academy" (My Hero Academia), on the slim lane (v2, 2026-11-22).
-- z 1240..1600 (config id still samurai_castle), lane floor y -48, lane edges x +-100. Run with
--   python tools/studio/zones/run_zone.py build 4
-- then lane_border.luau. Safe to run again. v1 (zone_lib, the 320-wide lane): MapArchive.Zone4_v1_canyon
-- and tools/studio/retired/zone_04_mha_v1.luau.
--
-- The hero school and the city it guards, on side_lib's cross-section (a concrete city revetment).
--   +X, the campus behind its white wall and blue gate: the training dome, the glass main building
--     at the head of a tree-lined path, the dormitory with its basketball court, the bronze hero on a
--     round plinth, a class block; on the shelf a skyline of towers and hero billboards
--   -X, the city: a road along the lane with a bus at its stop, a taxi and cars; the screen tower,
--     the convenience store and its car park, the hero agency, an apartment block, and at the far end
--     the giant exam robot among rubble; towers and billboards on the shelf
-- v1's scales made the main building 114 tall: everything is sized now to the terrace and under the
-- border wall (owner: not too big, not too tall).
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local map = workspace.Map
local KIT = RS.Assets.Kit
local SRC = SS.StoreAssets.Zone04_MHA
local JUNGLE = SS.StoreAssets.Zone01_Naruto
local ID = "samurai_castle" -- the zone's id in config until the anime zone data lands
local LY, HALF, Z0, Z1 = P.LY, P.HALF, 1240, 1600
local rng = Random.new(4407)

local WHITE = Color3.fromRGB(240, 242, 246)
local PLAZA = Color3.fromRGB(214, 218, 226)
local PATH = Color3.fromRGB(168, 176, 192)
local ASPHALT = Color3.fromRGB(58, 60, 70)
local SIDEWALK = Color3.fromRGB(186, 190, 198)
local LINE = Color3.fromRGB(250, 250, 250)
local YELLOW = Color3.fromRGB(255, 206, 44)
local UA_BLUE = Color3.fromRGB(40, 104, 220)
local CITY = Color3.fromRGB(150, 156, 170)
local CITY_DARK = Color3.fromRGB(112, 120, 140)
local C = Enum.Material.Concrete
local GY = P.TERRACE_Y + 0.4 -- the paving's top: what stands on the terrace stands on this
local B0 = 1282 -- the terrace's buildings start behind the gate's lions (z 1255..1279)

local function facing(side: number): number
	return if side > 0 then 90 else -90 -- a squared template fronts to -Z: turn it to the lane
end
local function kit(name: string): Instance?
	local t = KIT:FindFirstChild(name)
	if not t then
		table.insert(refused, name .. " is not in the kit")
	end
	return t
end

-- ---------------------------------------------------------------------------------- the zone's folder
local scenery = map.Scenery
local archive = SS:FindFirstChild("MapArchive") or folder(SS, "MapArchive")
if not archive:FindFirstChild("Zone4_v1_canyon") then
	local keep = scenery["Zone_" .. ID]:Clone()
	keep.Name = "Zone4_v1_canyon"
	keep:SetAttribute(
		"Note",
		"Zone 4 (Hero Academy) v1 on the 320-wide lane, before the slim-lane rebuild (2026-11-22). Never delete."
	)
	keep.Parent = archive
end
local root = scenery["Zone_" .. ID]
root:ClearAllChildren()
root:SetAttribute("Theme", "Hero Academy (My Hero Academia), zone_04_mha.luau v2 on side_lib")
local ground = folder(root, "Ground")
local campus = folder(root, "Campus")
local city = folder(root, "City")
local props = folder(root, "Props")
local trees = folder(root, "Trees")

-- ---------------------------------------------------------------------------------- the ground
local STYLE = {
	stone = CITY,
	material = C,
	band = CITY_DARK,
	cap = WHITE,
	capMaterial = C,
	rail = Color3.fromRGB(96, 102, 116),
	buttress = 40,
}
if DO_TERRAIN then
	sideGround(Z0, Z1)
end
claimGates(Z0, Z1)
for _, s in { -1, 1 } do
	box(ground, "Kerb", s * HALF, s * P.KERB_OUT, LY - 2, LY + 3, Z0, Z1, YELLOW, C)
	revetment(ground, s, Z0, Z1, STYLE)
end
-- +X: the campus is one plaza; -X: the road along the lane and the sidewalk to the wall
pave(ground, P.KERB_OUT, P.TERRACE_OUT - P.BATTER + 0.5, Z0, Z1, GY, PLAZA, C, "CampusPlaza")
pave(ground, -P.KERB_OUT, -P.STREET_OUT, Z0, Z1, GY - 0.2, ASPHALT, Enum.Material.Asphalt, "Road")
pave(ground, -P.STREET_OUT, -(P.TERRACE_OUT - P.BATTER + 0.5), Z0, Z1, GY, SIDEWALK, C, "Sidewalk")
for z = Z0 + 6, Z1 - 10, 14 do
	paint(ground, -109.7, -110.3, z, z + 7, LINE, GY) -- the road's broken centre line
end
for _, s in { -1, 1 } do
	table.insert(claims, rect(s * HALF, s * P.STREET_OUT, Z0, Z1, "Street"))
end

-- ================================================================================== +X: the campus
local A = P.STREET_OUT + 6 -- the building line behind the campus wall
local function building(
	parent: Instance,
	template: Instance,
	side: number,
	scale: number,
	ax: number,
	z: number,
	opts: any?
): Model?
	local m = front(parent, template, side, scale, ax, z, opts)
	if m then
		still(m, true)
	end
	return m
end
building(campus, SRC.TrainingDome, 1, 1.15, A + 5, 1312)
local main = building(campus, SRC.UAMain, 1, 1.45, 143, 1370)
building(campus, SRC.Dorm, 1, 1.15, 140, 1425)
building(campus, SRC.Academy, 1, 0.95, A + 8, 1566)
-- the gate at the street, a path to the main building's steps, planter trees and benches either side
local MAIN_Z = 1370
local gate = put(campus, SRC.UAGate, 1.25, facing(1), A - 1.5, MAIN_Z, { y = GY, name = "UAGate" })
if gate then
	still(gate, true)
end
paint(ground, A + 3, 143, MAIN_Z - 9, MAIN_Z + 9, PATH, GY)
paint(ground, A + 3, 143, MAIN_Z - 0.6, MAIN_Z + 0.6, UA_BLUE, GY + 0.05)
if main then
	for i = 1, 4 do
		block(
			campus,
			"EntranceStep",
			Vector3.new(2.2, 1.2 * i, 34 - i * 3),
			CFrame.new(143 - (5 - i) * 2.2 + 1.1, GY + 0.6 * i, MAIN_Z),
			Color3.fromRGB(236, 240, 246),
			C
		)
	end
end
for _, dz in { -15, 15 } do
	for _, x in { A + 7, A + 16 } do
		local t = put(props, SRC.PlanterTree, 0.85, 0, x, MAIN_Z + dz, { y = GY, soft = 1.5 })
		if t then
			still(t, false)
		end
	end
end
-- the campus wall along the street, broken for the gate
local GATE_HALF = 20
for _, span in { { B0, MAIN_Z - GATE_HALF }, { MAIN_Z + GATE_HALF, Z1 - 4 } } do
	local x0, x1 = P.STREET_OUT + 1, P.STREET_OUT + 3.2
	box(campus, "CampusWall", x0, x1, GY, GY + 6, span[1], span[2], WHITE, C)
	box(
		campus,
		"CampusWallCap",
		x0 - 0.5,
		x1 + 0.5,
		GY + 6,
		GY + 7,
		span[1],
		span[2],
		UA_BLUE,
		Enum.Material.SmoothPlastic
	)
	for pz = span[1] + 1.5, span[2] - 1, 24 do
		box(campus, "CampusWallPier", x0 - 0.6, x1 + 0.6, GY, GY + 8, pz - 1.7, pz + 1.7, WHITE, C)
	end
end
table.insert(claims, rect(P.STREET_OUT, P.STREET_OUT + 4, B0, Z1, "CampusWall"))
sign(
	campus,
	"U.A. HIGH SCHOOL",
	30,
	5,
	CFrame.new(P.STREET_OUT + 5, GY + 12, MAIN_Z - GATE_HALF - 18)
		* CFrame.Angles(0, math.rad(facing(1)), 0),
	UA_BLUE,
	WHITE
)
for _, z in { MAIN_Z - GATE_HALF - 31, MAIN_Z - GATE_HALF - 5 } do
	block(
		campus,
		"SignPost",
		Vector3.new(1.4, 10, 1.4),
		CFrame.new(P.STREET_OUT + 5.4, GY + 5, z),
		WHITE,
		C
	)
end
-- the dormitory's court: a half court with its hoop, benches and a vending machine
do
	local c0, c1 = 1412, 1440
	local x0, x1 = A + 2, 138
	paint(ground, x0, x1, c0, c1, Color3.fromRGB(226, 146, 84), GY)
	for _, r in
		{
			{ x0, x1, c0, c0 + 0.5 },
			{ x0, x1, c1 - 0.5, c1 },
			{ x0, x0 + 0.5, c0, c1 },
			{ x1 - 0.5, x1, c0, c1 },
		}
	do
		paint(ground, r[1], r[2], r[3], r[4], LINE, GY + 0.05)
	end
	table.insert(claims, rect(x0, x1, c0, c1, "Court"))
	local hoop = kit("Prop_sakura_schoolyard_BasketballHoop")
	if hoop then
		still(make(props, hoop, 1.4, facing(1), Vector3.new(x1 - 2, GY, (c0 + c1) / 2)), false)
	end
	local bench = kit("Prop_sakura_schoolyard_Bench")
	if bench then
		still(make(props, bench, 1.4, 180, Vector3.new((x0 + x1) / 2, GY, c1 + 3.5)), false)
	end
	local vend = kit("Prop_shared_VendingMachine")
	if vend then
		still(make(props, vend, 1.5, facing(1), Vector3.new(x0 + 1, GY, c1 + 4)), false)
	end
end
-- the dome's training ground: a track with hurdles in front of it
do
	local t0, t1 = 1292, 1330
	local x0, x1 = A + 1, A + 4.5
	paint(ground, x0 - 1, x1 + 1, t0, t1, Color3.fromRGB(206, 92, 70), GY)
	local hurdle = kit("Prop_sakura_schoolyard_TrackHurdle")
	if hurdle then
		for _, hz in { t0 + 8, t0 + 20, t0 + 32 } do
			still(make(props, hurdle, 1.0, 90, Vector3.new((x0 + x1) / 2, GY, hz)), false)
		end
	end
end
-- the bronze hero on a round plinth with steps, facing the throw stage
do
	local sx, sz = 144, 1500
	for i, r in { 17, 14, 11 } do
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
	claim(rect(sx - 18, sx + 18, sz - 18, sz + 18, "StatuePlinth"))
	still(make(campus, SRC.HeroStatue, 1.25, 0, Vector3.new(sx, GY + 3.9, sz)), true)
	for _, dz in { -24, 24 } do
		local t = put(props, SRC.PlanterTree, 0.8, 0, sx, sz + dz, { y = GY, soft = 1.5 })
		if t then
			still(t, false)
		end
	end
end

-- ================================================================================== -X: the city
local CA = P.STREET_OUT + 4 -- the sidewalk's building line
building(city, SRC.ScreenBuilding, -1, 1.3, 142, 1306)
building(city, SRC.Konbini, -1, 1.25, 150, 1341)
building(city, SRC.HeroAgency, -1, 1.4, 138, 1378)
building(city, SRC.Apartment, -1, 1.2, 139, 1418)
building(city, SRC.Skyscraper, -1, 1.15, 141, 1572)
-- the store's car park: bays painted in front of it, two cars nosed in
do
	local z0, z1 = 1328, 1354
	pave(ground, -CA, -148, z0, z1, GY + 0.15, ASPHALT, Enum.Material.Asphalt, "CarPark")
	for i = 0, 2 do
		paint(ground, -(CA + 4), -147, z0 + 1 + i * 12, z0 + 1.5 + i * 12, LINE, GY + 0.2)
	end
	table.insert(claims, rect(-CA, -148, z0, z1, "CarPark"))
	still(make(props, SRC.Car, 1.2, facing(-1), Vector3.new(-(CA + 15), GY + 0.15, z0 + 7)), false)
	still(
		make(props, SRC.Taxi, 1.2, facing(-1), Vector3.new(-(CA + 15), GY + 0.15, z0 + 19)),
		false
	)
end
-- the bus at its stop in front of the agency; cars parked along the road
still(make(props, SRC.Bus, 1.4, 0, Vector3.new(-110, GY - 0.2, 1378)), false)
local stop = put(props, SRC.BusStop, 1.2, facing(-1), -(CA + 5), 1378, { y = GY })
if stop then
	still(stop, false)
end
for _, c in
	{ { SRC.Taxi, 1298, 0 }, { SRC.Car, 1328, 180 }, { SRC.Car, 1440, 0 }, { SRC.Taxi, 1545, 180 } }
do
	still(make(props, c[1], 1.15, c[3], Vector3.new(-110, GY - 0.2, c[2])), false)
end
-- street lamps, vending machines and trees down the sidewalk, only where there is room
for z = 1292, Z1 - 10, 46 do
	local lamp = kit("Prop_hero_city_StreetLamp")
	if lamp then
		put(props, lamp, 1.5, facing(-1), -(CA - 1.5), z, { y = GY })
	end
end
-- the exam robot at the far end among rubble, facing the throwers
do
	local rz = 1502
	local robot = front(city, SRC.Robot, -1, 1.6, 136, rz)
	if robot then
		still(robot, true)
	end
	for i = 1, 14 do
		local s = rng:NextNumber(3, 7)
		local ax = rng:NextNumber(CA + 2, 164)
		local dz = rng:NextNumber(-56, 52)
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
			if i % 3 == 0 then CITY_DARK else Color3.fromRGB(160, 164, 174),
			C
		)
		slab.CastShadow = false
	end
end

-- ================================================================================== the shelves
local SHELF = P.REVET_OUT + 1.5
for _, s in { -1, 1 } do
	local plan = if s > 0
		then {
			{ "B", 1300 },
			{ SRC.Apartment, 1345 },
			{ "T", 1382 },
			{ SRC.Skyscraper, 1420 },
			{ "B", 1462 },
			{ "T", 1498 },
			{ SRC.Apartment, 1540 },
			{ "T", 1584 },
		}
		else {
			{ SRC.Skyscraper, 1302 },
			{ "B", 1345 },
			{ "T", 1384 },
			{ SRC.Apartment, 1428 },
			{ "B", 1470 },
			{ "T", 1512 },
			{ SRC.Skyscraper, 1556 },
		}
	for _, e in plan do
		if e[1] == "B" then
			local b = front(props, SRC.HeroBillboard, s, 1.2, SHELF + 6, e[2])
			if b then
				still(b, false)
			end
		elseif e[1] == "T" then
			local t = put(
				trees,
				JUNGLE.TreeBroad,
				0.9,
				rng:NextInteger(0, 3) * 90,
				s * 192,
				e[2],
				{ soft = 3.6 }
			)
			if t then
				still(t, false)
			end
		else
			building(city, e[1], s, 1.0, SHELF, e[2])
		end
	end
end

-- ---------------------------------------------------------------------------------- the lane's floor
floorKit({
	id = ID,
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

markSlim(root, Z0, Z1)
return string.format("zone 4 Hero Academy v2: %d parts\n%s", #partsOf(root), sideReport(root))
