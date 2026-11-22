-- LIB: side_lib
-- zone_10_chainsaw.luau - zone 10, "Public Safety HQ" (Chainsaw Man), on the slim lane (v2, 2026-11-22).
-- z 3400..3760 (map id public_safety, no zone data yet), lane floor y -48, lane edges x +-100. Run with
--   python tools/studio/zones/run_zone.py build 10
-- then lane_border.luau. Safe to run again. v1 (zone_lib, the 320-wide lane): MapArchive.Zone10_v1_canyon
-- and tools/studio/retired/zone_10_chainsaw_v1.luau.
--
-- A gritty Tokyo street between dark concrete walls: a road along the lane each side (black siren cars,
-- a taxi, a bus), a sidewalk with utility poles and their sagging wires, vending machines, a bus stop.
--   +X: the bureau's grey government block, the cinema, the family diner, a screen tower, and the
--     giant chainsaw on a hazard-rimmed plinth, its broad side to the throwers
--   -X: the noodle shop, the shabby apartments, the old headquarters, the corner store, and the little
--     chainsaw dog's statue at the far end
--   on the shelves: signboards read from the lane, a skyline, the red lattice tower
local SS = game:GetService("ServerStorage")
local map = workspace.Map
local SRC = SS.StoreAssets.Zone10_Chainsaw
local Z4 = SS.StoreAssets.Zone04_MHA
local JUNGLE = SS.StoreAssets.Zone01_Naruto
local ID = "public_safety"
local LY, HALF, Z0, Z1 = P.LY, P.HALF, 3400, 3760
local rng = Random.new(10107)

local ASPHALT = Color3.fromRGB(54, 56, 64)
local SIDEWALK = Color3.fromRGB(150, 152, 160)
local LINE = Color3.fromRGB(240, 240, 236)
local HAZARD = Color3.fromRGB(250, 208, 40)
local RED = Color3.fromRGB(214, 48, 40)
local DARK = Color3.fromRGB(34, 34, 40)
local STEEL = Color3.fromRGB(70, 72, 82)
local C = Enum.Material.Concrete
local GY = P.TERRACE_Y + 0.4
local BOARDS = { "PUBLIC SAFETY", "DEVIL HUNTERS WANTED", "SPECIAL DIVISION 4", "KEEP TOKYO SAFE" }

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

-- ---------------------------------------------------------------------------------- the zone's folder
local scenery = map.Scenery
local archive = SS:FindFirstChild("MapArchive") or folder(SS, "MapArchive")
if not archive:FindFirstChild("Zone10_v1_canyon") then
	local keep = scenery["Zone_" .. ID]:Clone()
	keep.Name = "Zone10_v1_canyon"
	keep:SetAttribute(
		"Note",
		"Zone 10 (Public Safety HQ) v1 on the 320-wide lane, before the slim-lane rebuild (2026-11-22). Never delete."
	)
	keep.Parent = archive
end
local root = scenery["Zone_" .. ID]
root:ClearAllChildren()
root:SetAttribute("Theme", "Public Safety HQ (Chainsaw Man), zone_10_chainsaw.luau v2 on side_lib")
local ground = folder(root, "Ground")
city = folder(root, "City")
props = folder(root, "Props")
local trees = folder(root, "Trees")

-- ---------------------------------------------------------------------------------- the ground
local STYLE = {
	stone = STEEL,
	material = C,
	band = DARK,
	cap = Color3.fromRGB(120, 122, 130),
	capMaterial = C,
	rail = Color3.fromRGB(96, 98, 108),
	buttress = 38,
}
if DO_TERRAIN then
	sideGround(Z0, Z1)
end
claimGates(Z0, Z1)
for _, s in { -1, 1 } do
	box(ground, "Kerb", s * HALF, s * P.KERB_OUT, LY - 2, LY + 3, Z0, Z1, HAZARD, C)
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

-- utility poles down the sidewalk's edge, wires sagging from one to the next
local function poles(side: number, zs: { number })
	local last: Vector3? = nil
	for _, pz in zs do
		local pole =
			prop(SRC.UtilityPole, 1.8, side * (P.STREET_OUT + 5), pz, facing(side), { soft = 4 })
		if pole then
			local _, size = pole:GetBoundingBox()
			local top = Vector3.new(side * (P.STREET_OUT + 5), GY + size.Y * 0.9, pz)
			if last then
				local mid = (last + top) / 2 - Vector3.new(0, 2.2, 0)
				for _, seg in { { last, mid }, { mid, top } } do
					local a, b = seg[1], seg[2]
					block(
						props,
						"Wire",
						Vector3.new(0.25, 0.25, (a - b).Magnitude),
						CFrame.lookAt((a + b) / 2, b),
						DARK
					).CastShadow =
						false
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
	cylinder(city, "Plinth", radius * 2, 3, CFrame.new(x, GY + 1.5, z), STEEL, C).CastShadow = false
	cylinder(city, "PlinthRim", radius * 2 + 1.2, 0.5, CFrame.new(x, GY + 3.1, z), HAZARD)
	claim(rect(x - radius - 1, x + radius + 1, z - radius - 1, z + radius + 1, "Plinth"))
end

-- ================================================================================== +X: the bureau
building(SRC.GovOffice, 1, 1.6, 126, 3482)
building(SRC.Cinema, 1, 1.6, 132.5, 3532)
building(SRC.Diner, 1, 1.8, 137, 3581)
building(Z4.ScreenBuilding, 1, 1.3, 142, 3622)
prop(SRC.VendingRow, 1.3, P.STREET_OUT + 6, 3508, facing(1))
prop(Z4.BusStop, 1.2, P.STREET_OUT + 7, 3558, facing(1))
parked(SRC.SirenCar, 1.2, 110, 3470, 0)
parked(SRC.SirenCar, 1.2, 110, 3492, 0)
parked(Z4.Taxi, 1.2, 110, 3545, 0)
parked(Z4.Car, 1.2, 110, 3600, 180)
poles(1, { 3466, 3516, 3566, 3616, 3666 })
-- the giant chainsaw on its plinth, its broad side to the throw stage
plinth(142, 3702, 14)
still(make(city, SRC.Chainsaw, 1.4, 90, Vector3.new(142, GY + 3.2, 3702)), true)

-- ================================================================================== -X: the neighbourhood
building(SRC.NoodleShop, -1, 1.5, 136, 3484)
building(SRC.OldApartment, -1, 1.9, 138, 3532)
building(SRC.HQ, -1, 1.15, 130, 3582)
building(Z4.Konbini, -1, 1.3, 149, 3624)
prop(SRC.VendingRow, 1.3, -(P.STREET_OUT + 6), 3508, facing(-1))
parked(Z4.Car, 1.2, -110, 3480, 0)
parked(Z4.Taxi, 1.2, -110, 3530, 180)
parked(SRC.SirenCar, 1.2, -110, 3584, 0)
parked(Z4.Bus, 1.35, -110, 3640, 0)
poles(-1, { 3470, 3520, 3570, 3620, 3670 })
-- the little chainsaw dog on its plinth, facing the throw stage
plinth(-142, 3700, 18)
still(make(city, SRC.DogStatue, 1.3, 0, Vector3.new(-142, GY + 3.0, 3700)), true)

-- ================================================================================== the shelves
local SHELF = P.REVET_OUT + 1.5
for _, s in { -1, 1 } do
	-- signboards read from the lane
	for i, bz in { 3500, 3650 } do
		local ax = SHELF + 4
		local accent = if i % 2 == 1 then RED else HAZARD
		local board = sign(
			props,
			BOARDS[(i + (if s > 0 then 0 else 2) - 1) % #BOARDS + 1],
			44,
			10,
			CFrame.new(s * ax, P.SHELF_Y + 10, bz) * CFrame.Angles(0, math.rad(facing(s)), 0),
			DARK,
			accent
		)
		board.Name = "Signboard"
		block(
			props,
			"SignboardEdge",
			Vector3.new(1, 11, 45),
			CFrame.new(s * (ax + 0.5), P.SHELF_Y + 10, bz),
			accent
		)
		for _, d in { -17, 17 } do
			block(
				props,
				"SignboardLeg",
				Vector3.new(1.6, 6, 1.6),
				CFrame.new(s * (ax + 0.4), P.SHELF_Y + 2.5, bz + d),
				STEEL,
				Enum.Material.Metal
			)
		end
		claim(rect(s * (ax - 1), s * (ax + 2), bz - 23, bz + 23, "Signboard"))
	end
	-- the skyline
	if s > 0 then
		building(Z4.Apartment, s, 1.0, SHELF, 3448)
		building(Z4.Skyscraper, s, 1.0, SHELF + 1, 3575)
		building(SRC.OldApartment, s, 1.2, SHELF + 4, 3712)
	else
		building(Z4.Skyscraper, s, 1.0, SHELF + 1, 3448)
		building(SRC.RedTower, s, 0.8, SHELF + 5, 3575)
		building(Z4.Apartment, s, 1.0, SHELF, 3712)
	end
	for _, z in { 3540, 3610 } do
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

-- ---------------------------------------------------------------------------------- the lane's floor
floorKit({
	id = ID,
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

markSlim(root, Z0, Z1)
return string.format("zone 10 Public Safety HQ v2: %d parts\n%s", #partsOf(root), sideReport(root))
