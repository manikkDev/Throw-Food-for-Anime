-- zone_01_naruto.luau - Studio EDIT mode. Builds zone 1, "Hidden Leaf Village" (Naruto), in the single
-- lane: z 160..520, lane floor y -48 (config World.LaneY), lane edges x = +-160. Safe to run again:
-- it clears what it made (Map.Scenery.Zone_<id>) and rebuilds; the first run archived the old sakura
-- schoolyard dressing in ServerStorage.MapArchive.Zone1_sakura_schoolyard_v1 (never delete).
--
-- The picture, from the lobby inwards:
--   * THE ENTRANCE is built, not terrain: the village's great wall (stone foot, plaster, timber, clay
--     tiles) runs across behind the lobby's funnel walls, two gate towers flank the zone's torii, the
--     ledge's retaining wall carries on to the towers. v1 had two terrain mounds here and the owner
--     called it out: "the entrance decides the main look of this game".
--   * the gate's two green leaves ("a" and "n") hang on their own posts BEHIND the torii's pillars
--     (v1 hung them in front of the pillars and they clashed)
--   * right from the throw stage (-X): the Hokage Rock, four stone heads over a rock shelf, low
--     houses and a training ground at its foot so the heads stay in view
--   * left (+X): the village, tall houses and the Hokage residence under a hillside with a second
--     row of houses on a bench
-- Heights: the lane is 48 below the lobby, the walls rise 56 (village) and 80 (heads) above it: 104
-- and 128 from the lane floor, canyon walls from inside without towering over the lobby (v1: 128
-- and 150 above a lane only 24 down, "the walls height feels kinda high").
--
-- Needs ServerStorage.StoreAssets.Zone01_Naruto: buildings from harvest_naruto.luau +
-- harvest_naruto_store.luau; Head1..4, TreeBroad, TreeTall, BushLeafy, GateTowerMesh, RockOutcrop were made with Studio's mesh
-- generator (one prompt each: "giant carved stone statue head ...", "lush stylized broadleaf tree
-- ..., anime game art style, hand painted texture").
-- Run: python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --dm Edit --file <this file>
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local T = workspace.Terrain
local map = workspace.Map
local KIT = RS.Assets.Kit
local SRC = SS.StoreAssets.Zone01_Naruto
local ID = "sakura_schoolyard" -- the zone's id in config until the anime zone data lands
local LY, HALF, Z0, Z1 = -48, 160, 160, 520
local DO_TERRAIN = true
local rng = Random.new(1107)

local DECAL_A = "rbxassetid://3768467328" -- the gate's kana
local DECAL_N = "rbxassetid://3768465254"
local DECAL_LEAF = "rbxassetid://3786177973" -- the village emblem
local GREEN = Color3.fromRGB(62, 142, 65)
local GREEN_DARK = Color3.fromRGB(38, 98, 48)
local WOOD_DARK = Color3.fromRGB(74, 50, 38)
local STONE = Color3.fromRGB(186, 170, 150)
local STONE_DARK = Color3.fromRGB(140, 126, 112)
local PLASTER = Color3.fromRGB(246, 234, 204)
local ROOF = Color3.fromRGB(196, 84, 58)
local ROOF_DARK = Color3.fromRGB(142, 56, 44)
local RED = Color3.fromRGB(196, 52, 46)
local GOLD = Color3.fromRGB(255, 200, 70)

-- ---------------------------------------------------------------------------------- helpers
local function partsOf(inst: Instance): { BasePart }
	local list = {}
	if inst:IsA("BasePart") then
		table.insert(list, inst)
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end
local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end
local function still(inst: Instance, shadow: boolean?)
	for _, p in partsOf(inst) do
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		if shadow ~= nil then
			p.CastShadow = shadow
		end
	end
end
local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end
local function setup(p: BasePart, parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?)
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = size.Magnitude > 14
	p.Parent = parent
end
local function block(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	setup(p, parent, name, size, cf, color, material)
	return p
end
local function cylinder(parent: Instance, name: string, diameter: number, length: number, cf: CFrame, color: Color3, material: Enum.Material?): Part
	-- cf's Y axis is the cylinder's axis
	local p = block(parent, name, Vector3.new(length, diameter, diameter), cf * CFrame.Angles(0, 0, math.rad(90)), color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end
-- a tiled gable roof: at's X axis is the ridge, its origin the middle of the eave line
local function gable(parent: Instance, at: CFrame, length: number, half: number, height: number)
	for _, s in { -1, 1 } do
		local w = Instance.new("WedgePart")
		-- a wedge is thick at its +Z end: turn the thick end to the ridge
		local turn = if s > 0 then CFrame.Angles(0, math.pi, 0) else CFrame.new()
		setup(w, parent, "Roof", Vector3.new(length, height, half), at * CFrame.new(0, height / 2, s * half / 2) * turn, ROOF, Enum.Material.ClayRoofTiles)
		w.CastShadow = true
	end
	block(parent, "Ridge", Vector3.new(length + 1.5, 1.8, 2.4), at * CFrame.new(0, height + 0.4, 0), ROOF_DARK, Enum.Material.Wood)
	block(parent, "Eave", Vector3.new(length + 2, 1.4, half * 2 + 3), at * CFrame.new(0, -0.7, 0), ROOF_DARK, Enum.Material.Wood)
end
local function banner(parent: Instance, at: CFrame, width: number, height: number)
	-- a red cloth with the village emblem; at's -Z is the side it is read from
	local cloth = block(parent, "Banner", Vector3.new(width, height, 0.3), at, RED, Enum.Material.Fabric)
	local d = Instance.new("Decal")
	d.Texture = DECAL_LEAF
	d.Face = Enum.NormalId.Front
	d.Parent = cloth
	block(parent, "BannerRod", Vector3.new(width + 3, 0.9, 0.9), at * CFrame.new(0, height / 2 + 0.5, 0), WOOD_DARK, Enum.Material.Wood)
end

-- ---------------------------------------------------------------------------------- the old dressing
local lanes, scenery = map.Lanes, map.Scenery
local archive = SS:FindFirstChild("MapArchive") or folder(SS, "MapArchive")
local old = archive:FindFirstChild("Zone1_sakura_schoolyard_v1")
if not old then
	old = folder(archive, "Zone1_sakura_schoolyard_v1")
	old:SetAttribute("Note", "Zone 1 before the Hidden Leaf rework (2026-11-22). Never delete.")
	for _, f in { lanes["Walls_" .. ID], lanes["Facade_" .. ID], scenery["Zone_" .. ID], scenery["Town_" .. ID] } do
		f:Clone().Parent = old
	end
	-- hill props the new cliffs would bury
	local hills = folder(old, "Hills")
	for _, u in scenery.Hills:GetDescendants() do
		if u:IsA("Model") and u.Parent and u.Name:sub(1, 5) == "Prop_" then
			local p = u:GetPivot().Position
			if math.abs(p.X) < 372 and p.Z > 150 and p.Z < 534 then
				u.Parent = hills
			end
		end
	end
end
for _, f in { lanes["Walls_" .. ID], lanes["Facade_" .. ID], scenery["Town_" .. ID], scenery["Zone_" .. ID] } do
	f:ClearAllChildren()
end
local root = scenery["Zone_" .. ID]
root:SetAttribute("Theme", "Hidden Leaf Village (Naruto), zone_01_naruto.luau")

-- ---------------------------------------------------------------------------------- the canyon
-- One height function for both walls. ax = |x|. The terrace (lane level, where the village stands)
-- runs from the lane edge to the cliff's foot; the cliff steps up over a shelf or a bench; its top
-- slopes out to the hills that were already there. In front of z = WALL_Z the ground is the lobby's
-- (the built entrance stands there), so no rock shows towards the lobby.
local FACE = { [-1] = 240, [1] = 228 }
local TOP = { [-1] = 80, [1] = 56 }
local BENCH = 40 -- the width of the village wall's bench
local BENCH_Y = 8
local SHELF_Y = LY + 30 -- the rock shelf under the heads
local TOWER_IN, TOWER_OUT = 236, 293 -- a gate tower's two faces
local WALL_Z = 234 -- the gate towers' backs: the cliffs begin behind them
local OUTER = 368 -- the region's far edge
local function profile(side: number, ax: number, z: number, outerH: number): (number, string)
	local wobble = 6 * math.noise(z / 46, side * 3.1, 0.5) + 3 * math.noise(z / 13, side * 9.7, 0.2)
	-- beside the towers the terrace ends at their inner face
	local face = TOWER_IN + (FACE[side] - TOWER_IN + wobble) * smooth((z - 222) / 16)
	local d = ax - face
	if d < 0 then
		return LY, "terrace"
	end
	local rise = smooth((z - WALL_Z) / 12) -- no fall at the far end: zone 2's walls carry on from z 520
	local edge = -2 + (TOP[side] + 2 + 6 * math.noise(z / 50, side * 5.5, 1.7)) * rise
	local h: number
	local kind = "face"
	local topStart: number
	if side > 0 then
		-- the village's hillside: a bench with a second row of houses
		local bench = -2 + (BENCH_Y + 2) * rise
		topStart = BENCH + 10
		if d < 6 then
			h = LY + (bench - LY) * smooth(d / 6)
		elseif d < BENCH then
			h = bench + 1.2 * math.noise(ax / 9, z / 9, 3.3) * rise
			kind = "level"
		else
			h = bench + (edge - bench) * smooth((d - BENCH) / 10)
		end
	else
		-- the Hokage Rock: a shelf of rock, then the wall the heads are cut in
		local shelf = -2 + (SHELF_Y + 2 + 2 * math.noise(z / 17, 2.2, 0.9)) * rise -- the lobby's level where there is no cliff
		topStart = 24
		if d < 5 then
			h = LY + (shelf - LY) * smooth(d / 5)
		elseif d < 14 then
			h = shelf
			kind = "level"
		else
			h = shelf + (edge - shelf) * smooth((d - 14) / 10)
		end
	end
	if d > topStart then
		kind = "level"
		h += (4 * math.noise(ax / 28, z / 28, 4.4) + 6 * math.min((d - topStart) / 60, 1)) * rise
	end
	local outerStart = OUTER - 72
	if ax > outerStart then
		h += (outerH - h) * smooth((ax - outerStart) / 72)
	end
	return h, kind
end
-- the ground the cliffs' far side comes down to
local outerCache = { [-1] = {}, [1] = {} }
local function outerHeight(side: number, z: number): number
	local key = math.floor(z / 4)
	local cached = outerCache[side][key]
	if cached then
		return cached
	end
	local x = if side > 0 then OUTER else -OUTER - 4
	local region = Region3.new(Vector3.new(x, -32, key * 4), Vector3.new(x + 4, 100, key * 4 + 4))
	local _, occ = T:ReadVoxels(region, 4)
	local top = -2
	for y = 1, occ.Size.Y do
		if occ[1][y][1] > 0.1 then
			top = -32 + (y - 1) * 4 + occ[1][y][1] * 4
		end
	end
	top = math.clamp(top, -2, 40)
	outerCache[side][key] = top
	return top
end
local function ground(side: number, ax: number, z: number): number
	return (profile(side, ax, z, outerHeight(side, z)))
end

if DO_TERRAIN then
	T:SetMaterialColor(Enum.Material.Slate, Color3.fromRGB(206, 166, 120)) -- the rock: layered, warm
	local Y0, Y1 = -56, 180 -- up to 180 clears what v1 stood there
	local ny = (Y1 - Y0) / 4
	for _, side in { -1, 1 } do
		for z0 = 164, Z1 - 4, 64 do
			local z1 = math.min(z0 + 64, Z1)
			local nx, nz = (OUTER - HALF) / 4, (z1 - z0) / 4
			local mats = table.create(nx)
			local occs = table.create(nx)
			for ix = 1, nx do
				local ax = HALF + (ix - 1) * 4 + 2
				local mcol, ocol = table.create(ny), table.create(ny)
				for iy = 1, ny do
					mcol[iy] = table.create(nz, Enum.Material.Air)
					ocol[iy] = table.create(nz, 0)
				end
				for iz = 1, nz do
					local z = z0 + (iz - 1) * 4 + 2
					local outer = outerHeight(side, z)
					local h, kind = profile(side, ax, z, outer)
					-- how steep the ground is here: a voxel's fill is its distance to the surface, not
					-- its depth under it, or every slope steeper than 45 degrees comes out as stairs
					local gx = (profile(side, ax + 2, z, outer) - profile(side, ax - 2, z, outer)) / 4
					local gz = (profile(side, ax, z + 2, outerHeight(side, z + 2)) - profile(side, ax, z - 2, outerHeight(side, z - 2))) / 4
					local steep = gx * gx + gz * gz
					local spread = 4 * math.sqrt(1 + math.min(steep, 30))
					for iy = 1, ny do
						local yb = Y0 + (iy - 1) * 4
						local o = math.clamp(0.5 + (h - (yb + 2)) / spread, 0, 1)
						if o > 0.02 then
							local m = Enum.Material.Slate
							if kind == "terrace" and yb < h + 1 then
								m = Enum.Material.Ground
							elseif kind == "level" and steep < 0.5 and yb + 4 > h - 6 then
								m = Enum.Material.LeafyGrass -- level ground is green, anything steep is rock
							end
							mcol[iy][iz] = m
							ocol[iy][iz] = o
						end
					end
				end
				-- the heads' wall's region runs from -OUTER inwards
				local slot = if side > 0 then ix else nx - ix + 1
				mats[slot] = mcol
				occs[slot] = ocol
			end
			local xa = if side > 0 then HALF else -OUTER
			T:WriteVoxels(Region3.new(Vector3.new(xa, Y0, z0), Vector3.new(xa + (OUTER - HALF), Y1, z1)), 4, mats, occs)
		end
	end
end

-- ---------------------------------------------------------------------------------- placing things
-- templates look to -Z; on the +X wall the lane is at -X, on the -X wall at +X
local function facing(side: number): number
	return if side > 0 then 90 else -90
end
-- Every template's pivot is the middle of its base. A merged building's parts do NOT say where it
-- stands (a GeometryService union is not centred on its geometry), so nothing here measures parts:
-- a thing is placed by its pivot, and a building's footprint is its attribute TrueSize.
local function make(parent: Instance, template: Instance, scale: number, yaw: number, at: Vector3): Model
	local m = template:Clone() :: Model
	m:ScaleTo(m:GetScale() * scale)
	m:PivotTo(CFrame.new(at) * CFrame.Angles(0, math.rad(yaw), 0))
	still(m)
	m.Parent = parent
	return m
end

local entrance = folder(root, "Entrance")
local buildings = folder(root, "Buildings")
local monument = folder(root, "Monument")
local gate = folder(root, "Gate")
local props = folder(root, "Props")
local trees = folder(root, "Trees")

-- a building with its lane-side face at ax and its middle at z
local function building(side: number, name: string, scale: number, ax: number, z: number, y: number?): Model
	local template = SRC[name]
	local size = (template:GetAttribute("TrueSize") :: Vector3) * scale
	-- turned a quarter to face the lane: its depth is its template Z
	return make(buildings, template, scale, facing(side), Vector3.new(side * (ax + size.Z / 2), y or LY, z))
end

-- ---------------------------------------------------------------------------------- the entrance
local PLASTER_M, STONE_M = Enum.Material.Plaster, Enum.Material.Brick
local WALL_MID = 196 -- the great wall's centre line
for _, side in { -1, 1 } do
	local function X(ax: number): number
		return side * ax
	end
	-- the ledge's retaining wall carries on from the stage to the tower, and turns in to meet it
	local top = 1.3
	block(entrance, "LedgeWing", Vector3.new(TOWER_IN - 162, top - LY + 2, 6), CFrame.new(X((162 + TOWER_IN) / 2), (top + LY - 2) / 2, 163), STONE, STONE_M)
	block(entrance, "LedgeWingCap", Vector3.new(TOWER_IN - 160, 2.2, 8), CFrame.new(X((160 + TOWER_IN) / 2), top + 1.1, 163), STONE_DARK, Enum.Material.Slate)
	block(entrance, "LedgeReturn", Vector3.new(5, top - LY + 2, 18), CFrame.new(X(TOWER_IN + 2.5), (top + LY - 2) / 2, 172), STONE, STONE_M)

	-- the gate tower: a castle keep (generated mesh, 44 x 56 x 38) on a stone plinth. The plinth
	-- lifts it over the lobby's funnel walls, which hide everything below y 30 from the lobby.
	local TW, TD, PLINTH = 57, 66, 14 -- the keep is 38 x 44 at 1.5, its 44 along the lane
	local tx, tz = X(TOWER_IN + TW / 2), 200
	local tower = Instance.new("Model")
	tower.Name = "GateTower"
	block(tower, "Plinth", Vector3.new(TW, PLINTH - LY + 2, TD), CFrame.new(tx, (PLINTH + LY - 2) / 2, tz), STONE, STONE_M)
	block(tower, "PlinthBand", Vector3.new(TW + 3, 3, TD + 3), CFrame.new(tx, PLINTH - 1.5, tz), STONE_DARK, Enum.Material.Slate)
	-- a squared template fronts to -Z: its archway turns to the lane
	local keep = make(tower, SRC.GateTowerMesh, 1.5, facing(side), Vector3.new(tx, PLINTH, tz))
	still(keep, true)
	-- the emblem, facing down the street
	banner(tower, CFrame.new(tx, -12, tz + TD / 2 + 0.4) * CFrame.Angles(0, math.pi, 0), 18, 26)
	tower.Parent = entrance

	-- the great wall, from the tower out to the hills
	local x0, x1 = TOWER_OUT, OUTER
	local len, mid = x1 - x0, X((x0 + x1) / 2)
	local wall = Instance.new("Model")
	wall.Name = "GreatWall"
	block(wall, "Foot", Vector3.new(len, 34, 14), CFrame.new(mid, 11, WALL_MID), STONE, STONE_M)
	block(wall, "FootBand", Vector3.new(len, 2.4, 16), CFrame.new(mid, 29.2, WALL_MID), STONE_DARK, Enum.Material.Slate)
	block(wall, "Body", Vector3.new(len, 14, 11), CFrame.new(mid, 37.4, WALL_MID), PLASTER, PLASTER_M)
	for i = 0, 4 do
		local px = X(x0 + 4 + i * (len - 8) / 4)
		block(wall, "Post", Vector3.new(2, 14, 11.8), CFrame.new(px, 37.4, WALL_MID), WOOD_DARK, Enum.Material.Wood)
	end
	gable(wall, CFrame.new(mid, 45.1, WALL_MID), len, 10, 7)
	banner(wall, CFrame.new(mid, 36.6, WALL_MID - 5.8), 9, 11)
	-- the end turret, where the wall meets the hills
	local px = X(x1 + 12)
	block(wall, "TurretFoot", Vector3.new(30, 42, 34), CFrame.new(px, 11, WALL_MID), STONE, STONE_M)
	still(make(wall, SRC.GateTowerMesh, 0.78, facing(side), Vector3.new(px, 32, WALL_MID)), true)
	wall.Parent = entrance
end
local ledgeWall = map.HubV2:FindFirstChild("LedgeWall")
if ledgeWall and ledgeWall:IsA("BasePart") then
	ledgeWall.Color = STONE -- one wall from tower to tower
	ledgeWall.Material = STONE_M
end
-- seen from the lane, the ledge is one long wall under the throw stage: piers, and the emblem
for _, x in { -210, -150, -90, -30, 30, 90, 150, 210 } do
	-- they stop 5 below the lip: any higher and the thrower sees their tops past the stage's edge
	block(entrance, "LedgePier", Vector3.new(9, -4 - LY + 2, 3), CFrame.new(x, (-4 + LY - 2) / 2, 166.4), STONE_DARK, STONE_M)
end
banner(entrance, CFrame.new(0, -20, 166.2) * CFrame.Angles(0, math.pi, 0), 44, 36)
for _, x in { -120, 120 } do
	banner(entrance, CFrame.new(x, -22, 166.2) * CFrame.Angles(0, math.pi, 0), 20, 28)
end
-- the lobby's two funnel walls lead to the gate: the same stone and tiles as the great wall
-- (they were the lobby's pink brick with a lime cap, which fought the entrance)
for _, p in map.HubV2:GetChildren() do
	if p.Name == "FunnelWall" and p:IsA("BasePart") then
		p.Color = STONE
		p.Material = STONE_M
	elseif p.Name == "FunnelCap" and p:IsA("BasePart") then
		p.Color = STONE_DARK
		p.Material = Enum.Material.Slate
		-- the cap's long axis is its Z: the roof's ridge runs along it
		gable(entrance, p.CFrame * CFrame.new(0, p.Size.Y / 2 + 0.7, 0) * CFrame.Angles(0, math.pi / 2, 0), p.Size.Z, 9, 6)
	end
end

-- ---------------------------------------------------------------------------------- the gate's leaves
-- On their own posts behind the torii's pillars (which end at z 238), swung open and angled in
-- towards the lane so the kana reads from the lobby and from the throw stage.
local function leaf(side: number, kana: string)
	local m = Instance.new("Model")
	m.Name = "GateLeaf"
	local tall = 46 -- no taller: from the outer throw spots a 60-stud leaf hid half of two heads
	local post = Vector3.new(side * 188, LY, 248)
	block(m, "PostFoot", Vector3.new(15, 12, 15), CFrame.new(post + Vector3.new(0, 6, 0)), STONE, STONE_M)
	block(m, "Post", Vector3.new(11, tall + 2, 11), CFrame.new(post + Vector3.new(0, 12 + (tall + 2) / 2, 0)), PLASTER, PLASTER_M)
	block(m, "PostBelt", Vector3.new(12.2, 2, 12.2), CFrame.new(post + Vector3.new(0, tall + 4, 0)), WOOD_DARK, Enum.Material.Wood)
	gable(m, CFrame.new(post + Vector3.new(0, tall + 14.7, 0)), 18, 9, 6)
	local hinge = post + Vector3.new(-side * 4, 4, 7)
	local free = Vector3.new(side * 170, LY + 4, 312)
	local len = (free - hinge).Magnitude
	-- the leaf's frame: Z along the leaf, X out of its lane-side face
	local along = (free - hinge).Unit
	local out = along:Cross(Vector3.new(0, 1, 0)) * side -- towards the lane
	local at = CFrame.fromMatrix((hinge + free) / 2 + Vector3.new(0, tall / 2, 0), out, Vector3.new(0, 1, 0), out:Cross(Vector3.new(0, 1, 0)))
	block(m, "Leaf", Vector3.new(2.6, tall, len), at, GREEN, Enum.Material.WoodPlanks)
	for _, y in { 2.5 - tall / 2, tall / 2 - 2.5 } do
		block(m, "Rail", Vector3.new(3.8, 5, len + 1.6), at * CFrame.new(0, y, 0), GREEN_DARK, Enum.Material.Wood)
	end
	for _, z in { -len / 2, len / 2 } do
		block(m, "Stile", Vector3.new(3.8, tall, 5), at * CFrame.new(0, 0, z), GREEN_DARK, Enum.Material.Wood)
	end
	for _, y in { 10, tall - 6 } do
		cylinder(m, "Hinge", 4, 6, CFrame.new(hinge + Vector3.new(0, y, 0)), Color3.fromRGB(40, 42, 48), Enum.Material.Metal)
	end
	-- the kana, painted on the lane side
	local panel = block(m, "Kana", Vector3.new(0.2, 36, 33), at * CFrame.new(1.5, 0, 0), GREEN, Enum.Material.SmoothPlastic)
	panel.Transparency = 1
	local d = Instance.new("Decal")
	d.Texture = kana
	d.Face = Enum.NormalId.Right
	d.Parent = panel
	m.Parent = gate
end
leaf(1, DECAL_A) -- from the throw stage +X is on the left: "a" hangs on the left, as on the real gate
leaf(-1, DECAL_N)

-- ---------------------------------------------------------------------------------- the Hokage Rock
-- 1st to 4th reads left to right from the lane, so the 1st stands farthest
local HEADS = { { "Head4_Bangs", 318 }, { "Head3_Goatee", 370 }, { "Head2_FaceGuard", 422 }, { "Head1_LongHair", 474 } }
for _, h in HEADS do
	local m = make(monument, SRC[h[1]], 1.4, facing(-1), Vector3.new(-(FACE[-1] + 20), SHELF_Y + 2, h[2]))
	still(m, true)
end

-- ---------------------------------------------------------------------------------- the village
-- +X: the tall side
building(1, "KonohaTower", 1.5, 172, 372)
building(1, "HokageResidence", 1.25, 172, 462)
-- the hillside: a second row on the bench
for _, b in { { "KonohaHouse", 0.95, 258 }, { "KonohaTower", 0.72, 302 }, { "KonohaHouse", 0.95, 350 }, { "KonohaHouse", 0.95, 398 }, { "KonohaTower", 0.72, 448 }, { "KonohaHouse", 0.95, 496 } } do
	local ax = FACE[1] + 10
	building(1, b[1], b[2], ax, b[3], ground(1, ax + 14, b[3]) - 0.6)
end
-- -X: low, under the heads
building(-1, "KonohaHall", 0.78, 174, 364)
building(-1, "KonohaHouse", 1.2, 174, 486)
building(-1, "KonohaHouse", 1.2, 206, 508)

-- ---------------------------------------------------------------------------------- trees and bushes
local TREES = { SRC.TreeBroad, SRC.TreeTall }
local function tree(side: number, ax: number, z: number, scale: number, y: number?)
	local m = make(trees, TREES[rng:NextInteger(1, #TREES)], scale, rng:NextInteger(0, 359), Vector3.new(side * ax, y or (ground(side, ax, z) - 0.8), z))
	still(m, scale > 1.2)
end
local function bush(x: number, z: number, scale: number, y: number?)
	local side = if x > 0 then 1 else -1
	local m = make(trees, SRC.BushLeafy, scale, rng:NextInteger(0, 359), Vector3.new(x, y or (ground(side, math.abs(x), z) - 0.5), z))
	still(m, false)
end
for _, side in { -1, 1 } do
	-- the rims
	for z = 250, 500, 30 do
		local jitter = rng:NextNumber(-8, 8)
		tree(side, FACE[side] + (if side > 0 then BENCH + 22 else 38) + rng:NextNumber(0, 22), z + jitter, rng:NextNumber(1.5, 2.1))
	end
end
-- the bench, between its houses
for _, z in { 278, 326, 374, 424, 472 } do
	tree(1, FACE[1] + 12 + rng:NextNumber(-2, 4), z, rng:NextNumber(0.85, 1.15))
	bush(FACE[1] + 9, z + 12, 1.4)
end
-- the heads' shelf
for _, z in { 290, 344, 396, 448, 500 } do
	bush(-(FACE[-1] + 9), z, rng:NextNumber(1.3, 1.9))
end
-- street level
for _, t in { { 1, 204, 286, 1.0 }, { 1, 180, 316, 0.8 }, { 1, 184, 424, 0.8 }, { 1, 190, 506, 0.9 }, { -1, 214, 286, 1.0 }, { -1, 210, 414, 1.0 }, { -1, 216, 452, 0.9 } } do
	tree(t[1], t[2], t[3], t[4], LY)
end
for _, b in { { 168, 322 }, { 168, 424 }, { 170, 500 }, { -170, 318 }, { -170, 408 }, { -172, 470 }, { 200, 262 }, { -202, 262 } } do
	bush(b[1], b[2], 1.3, LY)
end

-- rock outcrops at the cliffs' feet and on their ledges
for _, r in {
	{ 1, FACE[1] - 4, 262, 1.5 }, { 1, FACE[1] - 2, 344, 1.1 }, { 1, FACE[1] - 4, 508, 1.6 },
	{ 1, FACE[1] + 36, 318, 1.2 }, { 1, FACE[1] + 36, 470, 1.3 },
	{ -1, FACE[-1] - 4, 268, 1.7 }, { -1, FACE[-1] - 2, 346, 1.2 }, { -1, FACE[-1] - 2, 398, 1.0 }, { -1, FACE[-1] - 4, 512, 1.8 },
	{ -1, FACE[-1] + 10, 296, 1.0 }, { -1, FACE[-1] + 10, 498, 1.1 },
} do
	local m = make(trees, SRC.RockOutcrop, r[4], rng:NextInteger(0, 359), Vector3.new(r[1] * r[2], ground(r[1], r[2], r[3]) - 2 * r[4], r[3]))
	still(m, true)
end

-- ---------------------------------------------------------------------------------- props
-- kit props (ReplicatedStorage.Assets.Kit): the hub's own models
local function prop(name: string, scale: number, x: number, z: number, yaw: number, y: number?): Model?
	local template = KIT:FindFirstChild(name)
	if not template then
		return nil
	end
	return make(props, template, scale, yaw, Vector3.new(x, y or LY, z))
end
-- the training ground under the Hokage Rock
for i, z in { 424, 438, 452 } do
	prop("Prop_ninja_village_TrainingLog", 2.3, -194, z, 90 + i * 20)
end
prop("Prop_store_TrainingPole", 1.6, -212, 420, 90)
prop("Prop_store_TrainingPole", 1.6, -214, 460, 90)
prop("Prop_ninja_village_GiantShuriken", 1.8, -178, 466, 60)
prop("Prop_ninja_village_ScrollStand", 1.8, -172, 418, 90)
prop("Prop_store_StoneLantern", 1.5, -170, 320, 0)
prop("Prop_store_StoneLantern", 1.5, -170, 410, 0)
-- the ramen stand on the village side
prop("Prop_shared_RamenStand", 2.6, 176, 430, -90)
prop("Prop_store_Barrel", 1.6, 168, 444, 0)
prop("Prop_store_Barrel", 1.6, 172, 447, 30)
prop("Prop_store_Crate", 1.6, 168, 418, 15)
prop("Prop_shared_LanternString", 2.2, 168, 430, 90, LY + 20)
-- watch posts on the rims
for _, w in { { 1, FACE[1] + BENCH + 24, 300 }, { 1, FACE[1] + BENCH + 26, 436 }, { -1, FACE[-1] + 40, 262 } } do
	prop("Prop_ninja_village_WatchPost", 2.2, w[1] * w[2], w[3], facing(w[1]), ground(w[1], w[2], w[3]) - 0.5)
end

-- power poles down both sides of the street, wires between them
local function pole(side: number, z: number): Vector3
	local x = side * 163
	local m = Instance.new("Model")
	m.Name = "PowerPole"
	cylinder(m, "Pole", 1.8, 40, CFrame.new(x, LY + 20, z), WOOD_DARK, Enum.Material.Wood)
	block(m, "Arm", Vector3.new(1, 1, 9), CFrame.new(x, LY + 36, z), WOOD_DARK, Enum.Material.Wood)
	block(m, "Arm", Vector3.new(1, 1, 7), CFrame.new(x, LY + 32, z), WOOD_DARK, Enum.Material.Wood)
	cylinder(m, "Can", 2.6, 4, CFrame.new(x + side * 1.6, LY + 28, z), Color3.fromRGB(150, 156, 164), Enum.Material.Metal)
	m.Parent = props
	return Vector3.new(x, LY + 36.4, z)
end
for _, side in { -1, 1 } do
	local last: Vector3? = nil
	for _, z in { 326, 388, 450, 512 } do
		local top = pole(side, z)
		if last then
			for _, dz in { -4, 4 } do
				local a, b = last + Vector3.new(0, 0, dz), top + Vector3.new(0, 0, dz)
				local wire = block(props, "Wire", Vector3.new(0.4, 0.4, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), Color3.fromRGB(30, 30, 34))
				wire.CastShadow = false
			end
		end
		last = top
	end
end

-- leaves on the wind, the whole length of the street
local fx = folder(root, "Fx")
for _, z in { 250, 340, 430, 505 } do
	local source = block(fx, "LeafSource", Vector3.new(300, 1, 70), CFrame.new(0, LY + 84, z), Color3.new(1, 1, 1))
	source.Transparency = 1
	source.CastShadow = false
	local e = Instance.new("ParticleEmitter")
	e.Name = "Leaves"
	e.Texture = "rbxassetid://5057182105"
	e.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(96, 190, 84)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(58, 150, 66)),
	})
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.3), NumberSequenceKeypoint.new(1, 1.8) })
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.1, 0),
		NumberSequenceKeypoint.new(0.85, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(9, 13)
	e.Rate = 5
	e.Speed = NumberRange.new(5, 9)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.SpreadAngle = Vector2.new(25, 25)
	e.Acceleration = Vector3.new(2.5, -1, 1.5)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-110, 110)
	e.LightEmission = 0
	e.LightInfluence = 1
	e.Parent = source
end
local ledgeFloor = map.HubV2:FindFirstChild("LedgeFloor")
if ledgeFloor and ledgeFloor:IsA("BasePart") then
	ledgeFloor.Color = Color3.fromRGB(214, 192, 158)
	local tex = ledgeFloor:FindFirstChildWhichIsA("Texture")
	if tex then
		tex.Color3 = Color3.fromRGB(236, 222, 196)
	end
end

-- ---------------------------------------------------------------------------------- floor and gate
local SAND_A, SAND_B = Color3.fromRGB(246, 214, 144), Color3.fromRGB(238, 198, 120)
for _, c in lanes["Zone_" .. ID]:GetChildren() do
	local n = c.Name
	if c:IsA("BasePart") then
		if n:sub(1, 5) == "Strip" then
			local tile = math.floor((c.Position.Z - Z0) / 44.25)
			c.Color = if tile % 2 == 0 then SAND_A else SAND_B
			local tex = c:FindFirstChildWhichIsA("Texture")
			if tex then
				tex.Color3 = Color3.fromRGB(255, 236, 190)
			end
		elseif n:sub(1, 4) == "Kerb" then
			c.Color = GREEN
		elseif n:sub(1, 6) == "Paving" or n == "MarginPaving" then
			c.Color = Color3.fromRGB(214, 192, 158)
			local tex = c:FindFirstChildWhichIsA("Texture")
			if tex then
				tex.Color3 = Color3.fromRGB(236, 222, 196)
			end
		elseif n:sub(1, 12) == "DistanceBand" then
			c.Color = Color3.fromRGB(255, 248, 226)
		end
	elseif n:sub(1, 5) == "Gate_" then
		for _, d in c:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "Accent" then
				d.Color = GREEN
			elseif d:IsA("TextLabel") then
				d.Text = "HIDDEN LEAF VILLAGE\nSTART HERE"
			end
		end
	end
end

local count = #partsOf(root)
return string.format("zone 1 Hidden Leaf: %d parts in Scenery.Zone_%s (%d entrance, %d buildings, %d trees, %d props)", count, ID, #partsOf(entrance), #buildings:GetChildren(), #trees:GetChildren(), #partsOf(props))
