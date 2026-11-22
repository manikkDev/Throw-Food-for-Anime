-- RETIRED 2026-11-22: the walled town was removed (owner: the map was too big). Do NOT run: it would
-- rebuild the town. The lobby wall is built by tools/studio/lobby_wall.luau now.
-- lobby_town.luau - Studio EDIT mode, safe to run again. The lobby's boundary and the walled town
-- around it.
--
-- Owner's briefs (2026-11-22): the lobby's surroundings were "random", "slop", "not forming proper
-- connected boundaries"; then, of the first four-terrace town: "map feels too big", remove the
-- three house terraces, make the last ring proper architecture with good spacing, "not only trees";
-- then: no forest outside, the outer walls taller and the end of the map.
--
-- The picture, from the plaza outwards:
--   * THE LOBBY WALL: one wall all round, in the Hidden Leaf great wall's dress (stone foot, white
--     plaster, timber posts, clay-tile roof), the same as zone 1's entrance and the funnel walls it
--     joins. A keep at each corner (the funnel walls meet the front two), a smaller one halfway
--     along each side and at a third and two thirds of the back. Leaf banners inside.
--   * THE RING STREET: a cobbled street right behind the lobby wall, round the back and down both
--     sides, stone lanterns on the verge.
--   * THE PRECINCT (one level, ground 8): walled compounds facing the street, each with its own
--     gate (a gatehouse in a low plaster wall) and its own ground:
--       back, middle: THE CASTLE on its stone base, a stair up from the street, two turrets
--       back, flanks:  the pond garden (pond, pavilion, cherry trees), the torii shrine (a walk of
--                      torii to a shrine), the watch corner (storehouses, a watchtower)
--       sides:         the pagoda temple, the side shrine at the end of a lane on the side axis,
--                      the dojo (training yard), the tea garden at the front
--   * THE TOWN WALL: the END of the map (owner: "the walls should be the end"). Zone 1's great wall
--     in the same dress and height runs right round the precinct, keeps on it in line with the
--     compound walls, its foot down in the sea that comes up to it on three sides. Zone 1's great
--     wall (z 196) meets it at the front corners and runs on out to the island's side.
-- Everything is mirrored about x = 0 and placed by footprint; a registry refuses anything that
-- would overlap something else, and the run ends with a pairwise check of what was built.
--
-- The old dressing is archived ONCE in ServerStorage.MapArchive.Lobby_v1 (never delete): the old
-- walls and facades, Scenery.HubBackdrop and the hill props that stood in the town's ground.
-- Run: python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --dm Edit --file <this file>
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local T = workspace.Terrain
local map = workspace.Map
local KIT = RS.Assets.Kit
local Z1 = SS.StoreAssets.Zone01_Naruto
local Z2 = SS.StoreAssets.Zone02_DemonSlayer
local Z9 = SS.StoreAssets.Zone09_Titan
local Z14 = SS.StoreAssets.Zone14_Bleach
local HUB = SS.StoreAssets.HubV2
local DO_TERRAIN = true
local rng = Random.new(2211)

local DECAL_LEAF = "rbxassetid://3786177973" -- the village emblem (zone 1's)
local WOOD_DARK = Color3.fromRGB(74, 50, 38)
local STONE = Color3.fromRGB(186, 170, 150)
local STONE_DARK = Color3.fromRGB(140, 126, 112)
local PLASTER = Color3.fromRGB(246, 234, 204)
local ROOF = Color3.fromRGB(196, 84, 58)
local ROOF_DARK = Color3.fromRGB(142, 56, 44)
local RED = Color3.fromRGB(196, 52, 46)
local STREET = Color3.fromRGB(168, 156, 140)
local PATH = Color3.fromRGB(196, 184, 160)
local GRAVEL = Color3.fromRGB(222, 214, 196) -- raked gravel of the shrine and temple courts
local YARD = Color3.fromRGB(214, 190, 150) -- the beaten earth of the dojo and the watch corner
local PLASTER_M, STONE_M = Enum.Material.Plaster, Enum.Material.Brick
local GRASS_M = Enum.Material.LeafyGrass

-- ---------------------------------------------------------------------------------- the plan
local FACE_X, FACE_Z = 358, -170 -- the lobby wall's outer faces
local WALL_X, WALL_Z, WALL_T = 350, -162, 16 -- its centre lines and thickness
local SIDE_END = 86 -- the side walls' front end: the funnel walls meet them here
local FRONT = 189 -- the town's front: zone 1's great wall stands at z 196 (189..203)
local G = 8 -- the precinct's ground
local IN_X, IN_Z = 452, -312 -- the town wall's inner faces
local RIM_T = 14 -- the town wall's thickness: zone 1's great wall, same dress and height
local WX, WZ = IN_X + RIM_T / 2, IN_Z - RIM_T / 2 -- its centre lines (459, -319)
local OUT_X, OUT_Z = IN_X + RIM_T, IN_Z - RIM_T -- its outer faces (466, -326): the map ends here
local WALL_BOTTOM = -44 -- the town wall's foot goes down into the sea
local SEA_Y = -4 -- the sea round the island (terrain water)
local EDGE_X, EDGE_Z = 548, -640 -- the town's terrain ends here: the island's side, the sea behind
local AXIS_Z = -40 -- the sides' middle: the side shrine's lane
local SB0, SB1 = FACE_Z - 18, FACE_Z - 6 -- the back street (z -188..-176)
local SS0, SS1 = FACE_X + 6, FACE_X + 18 -- the side streets (x 364..376)
local CW0, CW1 = FACE_Z - 22, FACE_Z - 26 -- the back compounds' front wall line (z -192..-196)
local SW0, SW1 = FACE_X + 22, FACE_X + 26 -- the side compounds' front wall line (x 380..384)
local ENTRANCE_A: Vector3, ENTRANCE_B: Vector3 -- the entrance walls' ends (+X), set in 1b
local KEEP_Z = IN_Z + 6 -- the back keeps' feet (26) reach z -306: compound walls stop there

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
local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end
local function setup(
	p: BasePart,
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	solid: boolean?
)
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = solid == true
	p.CanQuery = solid == true
	p.CanTouch = false
	p.CastShadow = size.Magnitude > 14
	p.Parent = parent
end
local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	solid: boolean?
): Part
	local p = Instance.new("Part")
	setup(p, parent, name, size, cf, color, material, solid)
	return p
end
-- a tiled gable roof: at's X axis is the ridge, its origin the middle of the eave line
local function gable(parent: Instance, at: CFrame, length: number, half: number, height: number)
	for _, s in { -1, 1 } do
		local w = Instance.new("WedgePart")
		local turn = if s > 0 then CFrame.Angles(0, math.pi, 0) else CFrame.new()
		setup(
			w,
			parent,
			"Roof",
			Vector3.new(length, height, half),
			at * CFrame.new(0, height / 2, s * half / 2) * turn,
			ROOF,
			Enum.Material.ClayRoofTiles
		)
		w.CastShadow = true
	end
	block(
		parent,
		"Ridge",
		Vector3.new(length + 1.5, 1.8, 2.4),
		at * CFrame.new(0, height + 0.4, 0),
		ROOF_DARK,
		Enum.Material.Wood
	)
	block(
		parent,
		"Eave",
		Vector3.new(length + 2, 1.4, half * 2 + 3),
		at * CFrame.new(0, -0.7, 0),
		ROOF_DARK,
		Enum.Material.Wood
	)
end
local function banner(parent: Instance, at: CFrame, width: number, height: number)
	-- a red cloth with the village emblem; at's -Z is the side it is read from
	local cloth =
		block(parent, "Banner", Vector3.new(width, height, 0.3), at, RED, Enum.Material.Fabric)
	local d = Instance.new("Decal")
	d.Texture = DECAL_LEAF
	d.Face = Enum.NormalId.Front
	d.Parent = cloth
	block(
		parent,
		"BannerRod",
		Vector3.new(width + 3, 0.9, 0.9),
		at * CFrame.new(0, height / 2 + 0.5, 0),
		WOOD_DARK,
		Enum.Material.Wood
	)
end
local function still(inst: Instance)
	for _, p in partsOf(inst) do
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
	end
end

-- ---------------------------------------------------------------------------------- footprints
-- Every rectangle that holds something is claimed here; a claim that crosses another is refused
-- and reported, so nothing is ever built through anything else.
type Rect = { x0: number, x1: number, z0: number, z1: number, name: string }
local claims: { Rect } = {}
local refused: { string } = {}
local function crosses(a: Rect, b: Rect): boolean
	return a.x0 < b.x1 - 0.05 and b.x0 < a.x1 - 0.05 and a.z0 < b.z1 - 0.05 and b.z0 < a.z1 - 0.05
end
local function free(r: Rect): Rect?
	for _, c in claims do
		if crosses(r, c) then
			return c
		end
	end
	return nil
end
local function claim(r: Rect): boolean
	local hit = free(r)
	if hit then
		table.insert(
			refused,
			string.format(
				"%s (%.0f..%.0f, %.0f..%.0f) crosses %s",
				r.name,
				r.x0,
				r.x1,
				r.z0,
				r.z1,
				hit.name
			)
		)
		return false
	end
	table.insert(claims, r)
	return true
end
local function rect(x0: number, x1: number, z0: number, z1: number, name: string): Rect
	return {
		x0 = math.min(x0, x1),
		x1 = math.max(x0, x1),
		z0 = math.min(z0, z1),
		z1 = math.max(z0, z1),
		name = name,
	}
end

-- a template's footprint about its pivot (the middle of its base), at yaw 0
local fpCache = {}
local function footprint(template: Instance): (number, number, number, number, number)
	if fpCache[template] then
		return table.unpack(fpCache[template])
	end
	local ts = template:GetAttribute("TrueSize")
	local res
	if typeof(ts) == "Vector3" then
		res = { -ts.X / 2, ts.X / 2, -ts.Z / 2, ts.Z / 2, ts.Y }
	else
		local piv = (template :: Model):GetPivot()
		local lo, hi = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
		for _, p in partsOf(template) do
			if p.Transparency < 1 then
				local half = p.Size / 2
				for _, sx in { -1, 1 } do
					for _, sy in { -1, 1 } do
						for _, sz in { -1, 1 } do
							local c = piv:PointToObjectSpace(
								(p.CFrame * CFrame.new(half.X * sx, half.Y * sy, half.Z * sz)).Position
							)
							lo, hi = lo:Min(c), hi:Max(c)
						end
					end
				end
			end
		end
		res = { lo.X, hi.X, lo.Z, hi.Z, hi.Y - lo.Y }
	end
	fpCache[template] = res
	return table.unpack(res)
end
-- the footprint turned by yaw (a multiple of 90) and scaled: x0, x1, z0, z1 about the pivot
local function turned(
	template: Instance,
	scale: number,
	yaw: number
): (number, number, number, number)
	local a0, a1, b0, b1 = footprint(template)
	a0, a1, b0, b1 = a0 * scale, a1 * scale, b0 * scale, b1 * scale
	local th = math.rad(yaw)
	local c, s = math.round(math.cos(th)), math.round(math.sin(th))
	local xs, zs = {}, {}
	for _, x in { a0, a1 } do
		for _, z in { b0, b1 } do
			-- CFrame.Angles(0, th, 0) maps local (x, z) to (x c + z s, -x s + z c)
			table.insert(xs, x * c + z * s)
			table.insert(zs, -x * s + z * c)
		end
	end
	return math.min(table.unpack(xs)),
		math.max(table.unpack(xs)),
		math.min(table.unpack(zs)),
		math.max(table.unpack(zs))
end

local made = 0
local function make(
	parent: Instance,
	template: Instance,
	scale: number,
	yaw: number,
	at: Vector3
): Model
	local m = template:Clone() :: Model
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	if scale ~= 1 then
		m:ScaleTo(m:GetScale() * scale)
	end
	m:PivotTo(CFrame.new(at) * CFrame.Angles(0, math.rad(yaw), 0))
	if not template:GetAttribute("TrueSize") then
		-- a template whose pivot is not at its feet (the hub's sakura, the torii): stand it on `at`
		local cf, size = m:GetBoundingBox()
		local lift = at.Y - (cf.Position.Y - size.Y / 2)
		if math.abs(lift) > 1 then
			m:PivotTo(m:GetPivot() + Vector3.new(0, lift, 0))
		end
	end
	still(m)
	m.Parent = parent
	made += 1
	return m
end
-- place a template with its pivot at (x, y, z) if its footprint (shrunk by `soft` on every side,
-- for canopies that may brush) is free
local function put(
	parent: Instance,
	template: Instance,
	scale: number,
	yaw: number,
	x: number,
	y: number,
	z: number,
	soft: number?
): Model?
	local x0, x1, z0, z1 = turned(template, scale, yaw)
	local k = soft or 0
	if not claim(rect(x + x0 + k, x + x1 - k, z + z0 + k, z + z1 - k, template.Name)) then
		return nil
	end
	return make(parent, template, scale, yaw, Vector3.new(x, y, z))
end

-- ---------------------------------------------------------------------------------- the old dressing
local archive = SS:FindFirstChild("MapArchive") or folder(SS, "MapArchive")
local hub, lanes, scenery = map.Hub, map.Lanes, map.Scenery
local function inTown(p: Vector3): boolean
	return (math.abs(p.X) > FACE_X - 3 and p.Z < 205) or p.Z < FACE_Z + 2
end
if not archive:FindFirstChild("Lobby_v1") then
	local old = folder(archive, "Lobby_v1")
	old:SetAttribute(
		"Note",
		"The lobby's walls and surroundings before lobby_town.luau (2026-11-22). Never delete."
	)
	for _, f in
		{ hub.Walls, hub.Facade, lanes.Walls_Plots, lanes.Facade_Plots, scenery.HubBackdrop }
	do
		local c = f:Clone()
		c.Name = f:GetFullName():gsub("^Workspace%.Map%.", ""):gsub("%.", "_")
		c.Parent = old
	end
	local hills = folder(old, "Hills")
	for _, u in scenery.Hills:GetChildren() do
		local pos = if u:IsA("Model")
			then u:GetPivot().Position
			elseif u:IsA("BasePart") then u.Position
			else nil
		if pos and inTown(pos) then
			u.Parent = hills
		end
	end
end
-- hill props a second run would meet (anything put back by hand)
for _, u in scenery.Hills:GetChildren() do
	local pos = if u:IsA("Model")
		then u:GetPivot().Position
		elseif u:IsA("BasePart") then u.Position
		else nil
	if pos and inTown(pos) then
		u:Destroy()
	end
end
for _, f in { hub.Walls, hub.Facade, lanes.Walls_Plots, lanes.Facade_Plots, scenery.HubBackdrop } do
	f:ClearAllChildren()
end
local oldTown = scenery:FindFirstChild("LobbyTown")
if oldTown then
	oldTown:Destroy()
end
local town = Instance.new("Folder")
town.Name = "LobbyTown"
town:SetAttribute("Theme", "The lobby's walled town, tools/studio/lobby_town.luau")
local fStreets = folder(town, "Streets")
local fCWalls = folder(town, "CompoundWalls")
local fCastle = folder(town, "Castle")
local fGarden = folder(town, "PondGarden")
local fShrine = folder(town, "ToriiShrine")
local fWatch = folder(town, "WatchCorner")
local fTemple = folder(town, "PagodaTemple")
local fLane = folder(town, "SideShrine")
local fDojo = folder(town, "Dojo")
local fTea = folder(town, "TeaGarden")
local fProps = folder(town, "Props")
local fTrees = folder(town, "Trees")
local fRim = folder(town, "TownWall")
local lobbyWall = hub.Walls

-- ---------------------------------------------------------------------------------- terrain
-- The precinct is rewritten flat at G; level terrain shows 2 studs above where it was written, so
-- its grass is written to G - 2. Outside the town wall there is no land: the sea comes up to the
-- wall's foot (owner, 2026-11-22: the walls should be the end). Zone 1's ground (z > 189) is never
-- touched.
local function fillBox(
	x0: number,
	x1: number,
	y0: number,
	y1: number,
	z0: number,
	z1: number,
	mat: Enum.Material
)
	if x1 - x0 < 0.5 or y1 - y0 < 0.5 or z1 - z0 < 0.5 then
		return
	end
	T:FillBlock(
		CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
		Vector3.new(x1 - x0, y1 - y0, z1 - z0),
		mat
	)
end
local POND = { x0 = 110, x1 = 174, z0 = -272, z1 = -234 } -- the garden's pond (+X side)
if DO_TERRAIN then
	for _, s in { -1, 1 } do
		local a, b = math.min(s * FACE_X, s * EDGE_X), math.max(s * FACE_X, s * EDGE_X)
		fillBox(a, b, -60, 150, EDGE_Z, FRONT + 3, Enum.Material.Air) -- to 192: zone 1's old rock lay in the voxel under the great wall
	end
	fillBox(-FACE_X, FACE_X, -60, 150, EDGE_Z, FACE_Z, Enum.Material.Air)
	-- the precinct, flat, to the town wall's outer faces
	for _, s in { -1, 1 } do
		-- 4 studs short of the wall's outer face: smooth terrain rounds out by a voxel, and grass
		-- showed along the wall's foot on the sea side
		local a, b = math.min(s * FACE_X, s * (OUT_X - 4)), math.max(s * FACE_X, s * (OUT_X - 4))
		fillBox(a, b, -40, G - 2, OUT_Z + 4, FRONT, GRASS_M)
		-- zone 1's hill reaches a few studs south of the great wall's face out there: cut it back
		-- under the wall's foot
		local c, d = math.min(s * OUT_X, s * EDGE_X), math.max(s * OUT_X, s * EDGE_X)
		fillBox(c, d, -60, 150, FRONT, FRONT + 4, Enum.Material.Air)
	end
	fillBox(-(OUT_X - 4), OUT_X - 4, -40, G - 2, OUT_Z + 4, FACE_Z, GRASS_M)
	-- the sea, from the wall out to the island's sides and back to the old shore (on to z 193 at the
	-- front, where lane_border.luau's sea begins): a sand bed and
	-- water up to the sea's surface (water shows where it is written, unlike level ground)
	for _, s in { -1, 1 } do
		local a, b = math.min(s * OUT_X, s * EDGE_X), math.max(s * OUT_X, s * EDGE_X)
		fillBox(a, b, -48, -40, EDGE_Z, FRONT + 4, Enum.Material.Sand)
		fillBox(a, b, -40, SEA_Y, EDGE_Z, FRONT + 4, Enum.Material.Water)
	end
	fillBox(-OUT_X, OUT_X, -48, -40, EDGE_Z, OUT_Z, Enum.Material.Sand)
	fillBox(-OUT_X, OUT_X, -40, SEA_Y, EDGE_Z, OUT_Z, Enum.Material.Water)
	-- the garden's ponds: water a stud and a half under the ground, in a stone rim
	for _, s in { -1, 1 } do
		local a, b = math.min(s * POND.x0, s * POND.x1), math.max(s * POND.x0, s * POND.x1)
		fillBox(a, b, G - 9, G + 4, POND.z0, POND.z1, Enum.Material.Air)
		fillBox(a, b, G - 12, G - 9, POND.z0, POND.z1, Enum.Material.Mud)
		fillBox(a, b, G - 9, G - 3.5, POND.z0, POND.z1, Enum.Material.Water)
	end
end
local onGround = RaycastParams.new()
onGround.FilterType = Enum.RaycastFilterType.Include
onGround.FilterDescendantsInstances = { T }
onGround.IgnoreWater = true
local function groundAt(x: number, z: number): number
	local hit = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), onGround)
	return if hit then hit.Position.Y else 0
end

-- ---------------------------------------------------------------------------------- paving
-- a paved slab IS the ground: the terrain under it is cut away so no grass comes through
local function pave(
	parent: Instance,
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	y: number,
	color: Color3,
	mat: Enum.Material,
	name: string
)
	x0, x1 = math.min(x0, x1), math.max(x0, x1)
	z0, z1 = math.min(z0, z1), math.max(z0, z1)
	if DO_TERRAIN then
		-- 2 studs short of the slab's edges: smooth terrain rounds a cut by a voxel, and a full-size
		-- cut left a 1.5-stud gully along every street (grass decoration is off: nothing pokes up)
		fillBox(x0 + 2, x1 - 2, y - 7, y + 4, z0 + 2, z1 - 2, Enum.Material.Air)
	end
	local slab = block(
		parent,
		name,
		Vector3.new(x1 - x0, 7, z1 - z0),
		CFrame.new((x0 + x1) / 2, y + 0.3 - 3.5, (z0 + z1) / 2),
		color,
		mat,
		true
	)
	slab.CastShadow = false
	return slab
end

-- ---------------------------------------------------------------------------------- stairs
-- a straight flight from ground y0 to y1; `dir` is the way up (a unit vector along x or z); it
-- starts at `foot` (the middle of its lowest step's front edge)
local function stair(
	parent: Instance,
	foot: Vector3,
	dir: Vector3,
	y0: number,
	y1: number,
	width: number,
	name: string
)
	local rise = 1
	local run = 1.5
	local n = math.ceil((y1 - y0) / rise)
	local side = Vector3.new(dir.Z, 0, -dir.X)
	local len = n * run
	local mid = foot + dir * (len / 2)
	local r = rect(
		mid.X - math.abs(dir.X) * len / 2 - math.abs(side.X) * (width / 2 + 2),
		mid.X + math.abs(dir.X) * len / 2 + math.abs(side.X) * (width / 2 + 2),
		mid.Z - math.abs(dir.Z) * len / 2 - math.abs(side.Z) * (width / 2 + 2),
		mid.Z + math.abs(dir.Z) * len / 2 + math.abs(side.Z) * (width / 2 + 2),
		name
	)
	if not claim(r) then
		return
	end
	local m = Instance.new("Model")
	m.Name = name
	local look = CFrame.lookAt(Vector3.zero, dir)
	for i = 1, n do
		local top = y0 + i * rise
		-- each step reaches back to the flight's foot, so the flight is solid underneath
		local d0 = (i - 1) * run
		local depth = len - d0
		local c = foot + dir * (d0 + depth / 2)
		block(
			m,
			"Step",
			Vector3.new(width, top - (y0 - 3), depth),
			CFrame.new(c.X, (top + y0 - 3) / 2, c.Z) * look.Rotation,
			if i % 2 == 0 then STONE else STONE:Lerp(STONE_DARK, 0.25),
			Enum.Material.Slate,
			true
		)
	end
	for _, s in { -1, 1 } do
		local c = foot + dir * (len / 2) + side * s * (width / 2 + 1)
		local h = y1 - y0 + 4
		block(
			m,
			"Cheek",
			Vector3.new(2, h, len),
			CFrame.new(c.X, y0 - 3 + h / 2, c.Z) * look.Rotation,
			STONE_DARK,
			STONE_M,
			true
		)
	end
	m.Parent = parent
end

-- ---------------------------------------------------------------------------------- low walls
-- a compound wall (tsuiji): stone foot, white plaster between timber posts, a small tile gable
local function lowWall(
	parent: Instance,
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	name: string,
	ground: number? -- default G
)
	x0, x1 = math.min(x0, x1), math.max(x0, x1)
	z0, z1 = math.min(z0, z1), math.max(z0, z1)
	if not claim(rect(x0, x1, z0, z1, name)) then
		return
	end
	local alongX = (x1 - x0) >= (z1 - z0)
	local len = if alongX then x1 - x0 else z1 - z0
	local th = if alongX then z1 - z0 else x1 - x0
	local at = CFrame.new((x0 + x1) / 2, ground or G, (z0 + z1) / 2)
		* (if alongX then CFrame.new() else CFrame.Angles(0, math.pi / 2, 0))
	local m = Instance.new("Model")
	m.Name = name
	block(m, "Foot", Vector3.new(len, 5.5, th), at * CFrame.new(0, -0.25, 0), STONE, STONE_M, true)
	block(
		m,
		"Body",
		Vector3.new(len, 6.5, th - 0.8),
		at * CFrame.new(0, 5.75, 0),
		PLASTER,
		PLASTER_M,
		true
	)
	local n = math.max(1, math.floor(len / 12))
	for i = 0, n do
		block(
			m,
			"Post",
			Vector3.new(1.2, 6.5, th - 0.4),
			at * CFrame.new(-len / 2 + 1 + i * (len - 2) / n, 5.75, 0),
			WOOD_DARK,
			Enum.Material.Wood
		)
	end
	gable(m, at * CFrame.new(0, 9.7, 0), len, th / 2 + 0.8, 2.2)
	m.Parent = parent
end

-- ---------------------------------------------------------------------------------- 1. the lobby wall
local KEEP = Z1.GateTowerMesh -- zone 1's gate keep (generated, 44 x 56 x 38)
-- stone foot, a dark band, white plaster with timber posts, a clay-tile gable; `at` is the wall's
-- middle at the lobby's ground, its X along the wall
local function wallAt(at: CFrame, len: number): Model
	local m = Instance.new("Model")
	m.Name = "LobbyWall"
	block(m, "Foot", Vector3.new(len, 19, WALL_T), at * CFrame.new(0, 6.5, 0), STONE, STONE_M, true)
	block(
		m,
		"FootBand",
		Vector3.new(len, 2, WALL_T + 1),
		at * CFrame.new(0, 17, 0),
		STONE_DARK,
		Enum.Material.Slate,
		true
	)
	block(
		m,
		"Body",
		Vector3.new(len, 10, WALL_T - 4),
		at * CFrame.new(0, 23, 0),
		PLASTER,
		PLASTER_M,
		true
	)
	local n = math.max(1, math.floor(len / 24))
	for i = 0, n do
		block(
			m,
			"Post",
			Vector3.new(2, 10, WALL_T - 3.2),
			at * CFrame.new(-len / 2 + 2 + i * (len - 4) / n, 23, 0),
			WOOD_DARK,
			Enum.Material.Wood
		)
	end
	gable(m, at * CFrame.new(0, 28.7, 0), len, WALL_T / 2 + 1, 6)
	m.Parent = lobbyWall
	return m
end
local function wallRun(x0: number, x1: number, z0: number, z1: number, along: string)
	local len = if along == "x" then x1 - x0 else z1 - z0
	local rot = if along == "x" then CFrame.new() else CFrame.Angles(0, math.pi / 2, 0)
	return wallAt(CFrame.new((x0 + x1) / 2, 0, (z0 + z1) / 2) * rot, len)
end
-- a keep on a stone tower; `yaw` turns the keep's front. Its foot is claimed outright: it stands
-- on (and across) a wall by design.
local function keep(
	parent: Instance,
	x: number,
	z: number,
	footW: number,
	footH: number,
	scale: number,
	yaw: number,
	ground: number,
	name: string
)
	local m = Instance.new("Model")
	m.Name = name
	block(
		m,
		"TowerFoot",
		Vector3.new(footW, footH - ground + 4, footW),
		CFrame.new(x, (footH + ground - 4) / 2, z),
		STONE,
		STONE_M,
		true
	)
	block(
		m,
		"TowerBand",
		Vector3.new(footW + 2, 2, footW + 2),
		CFrame.new(x, footH - 1, z),
		STONE_DARK,
		Enum.Material.Slate,
		true
	)
	make(m, KEEP, scale, yaw, Vector3.new(x, footH, z))
	m.Parent = parent
	table.insert(claims, rect(x - footW / 2, x + footW / 2, z - footW / 2, z + footW / 2, name))
	return m
end

-- zone 1's end turrets (x 365..395, z 179..213) stand in the town's front corner
for _, s in { -1, 1 } do
	claim(rect(s * 365, s * 395, 179, 213, "Zone1Turret"))
end
-- the back, corner to corner, then the sides from the back to the funnel walls
wallRun(-FACE_X, FACE_X, FACE_Z, FACE_Z + WALL_T, "x")
for _, s in { -1, 1 } do
	local x0, x1 = s * (FACE_X - WALL_T), s * FACE_X
	wallRun(math.min(x0, x1), math.max(x0, x1), FACE_Z + WALL_T, SIDE_END - 14, "z")
end
-- the keeps; the funnel walls end inside the front two. Each foot keeps out of the ring street,
-- which runs 6 studs off the wall.
local fKeeps = folder(lobbyWall, "Keeps")
for _, s in { -1, 1 } do
	local inward = if s > 0 then 90 else -90 -- the front looks across the lobby
	keep(fKeeps, s * WALL_X, WALL_Z, 28, 34, 0.74, 180, -3, "CornerKeep")
	keep(fKeeps, s * WALL_X, SIDE_END, 28, 34, 0.74, inward, -3, "FrontKeep")
	keep(fKeeps, s * (WALL_X - 3), AXIS_Z, 20, 31, 0.52, inward, -3, "SideKeep")
	keep(fKeeps, s * 175, WALL_Z + 3, 20, 31, 0.52, 180, -3, "BackKeep")
end
-- leaf banners on the inside, hung on the stone foot between the plaza's things
local fBanners = folder(lobbyWall, "Banners")
for _, x in { -315, -240, -60, 60, 240, 315 } do
	banner(
		fBanners,
		CFrame.new(x, 8.5, FACE_Z + WALL_T + 0.4) * CFrame.Angles(0, math.pi, 0),
		9,
		11
	)
end
for _, s in { -1, 1 } do
	for _, z in { -120, 15, 50 } do
		-- read from the plaza: the cloth's -Z turned to face the middle
		banner(
			fBanners,
			CFrame.new(s * (FACE_X - WALL_T - 0.4), 8.5, z)
				* CFrame.Angles(0, if s > 0 then math.pi / 2 else -math.pi / 2, 0),
			9,
			11
		)
	end
end

-- ---------------------------------------------------------------------------------- 1b. the entrance
-- Owner (2026-11-22): the lobby's join to the lane's entrance "feels weird". The old funnel walls
-- (Map.HubV2, plain stone with a roof zone 1 laid on them) ran from the front keeps to the torii's
-- pillars and stopped there in mid air, in front of zone 1's gate towers. Now each runs, in the
-- lobby wall's dress, from its front keep straight into zone 1's gate tower beside the torii: one
-- chain round the lobby, wall - keep - wall - gate tower - torii - gate tower - wall - keep - wall.
-- The old walls and zone 1's roofs on them are archived once in MapArchive.Entrance_v1.
ENTRANCE_A = Vector3.new(WALL_X, 0, SIDE_END) -- the front keep (+X)
ENTRANCE_B = Vector3.new(262, 0, 180) -- inside zone 1's gate tower's plinth (x 236..293, z 167..233)
do
	local archive = SS:FindFirstChild("MapArchive") or folder(SS, "MapArchive")
	local old = archive:FindFirstChild("Entrance_v1")
	if not old then
		old = folder(archive, "Entrance_v1")
		old:SetAttribute(
			"Note",
			"The lobby's funnel walls and zone 1's roofs on them, before the entrance walls of lobby_town.luau (2026-11-22). Never delete."
		)
	end
	for _, c in map.HubV2:GetChildren() do
		if c.Name == "FunnelWall" or c.Name == "FunnelCap" then
			c.Parent = old
		end
	end
	local z1e = map.Scenery:FindFirstChild("Zone_sakura_schoolyard")
	z1e = z1e and z1e:FindFirstChild("Entrance")
	if z1e then
		for _, c in z1e:GetChildren() do
			if
				c:IsA("BasePart") and (c.Name == "Roof" or c.Name == "Ridge" or c.Name == "Eave")
			then
				local q = c.Position
				if math.abs(q.X) > 150 and math.abs(q.X) < 370 and q.Z > 80 and q.Z < 175 then
					c.Parent = old
				end
			end
		end
	end
	for _, s in { -1, 1 } do
		local a = Vector3.new(s * ENTRANCE_A.X, 0, ENTRANCE_A.Z)
		local b = Vector3.new(s * ENTRANCE_B.X, 0, ENTRANCE_B.Z)
		local at = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0)
		local w = wallAt(at, (b - a).Magnitude)
		w.Name = "EntranceWall"
	end
	-- Between the throw stage's end and zone 1's gate tower the lawn stopped at a kerb over the
	-- drop into the lane (owner: "it feels like an open area"). A compound wall closes it, on the
	-- ledge's wing (z 160..166), from a stone post at the stage's end into the tower's plinth. It is
	-- low (top 15): the torii's pillar and zone 1's gate leaves still show over it from the stage,
	-- and it stands outside the lane (x 160), so no throw is hidden.
	local LAWN = 1 -- the lobby's lawn here
	for _, s in { -1, 1 } do
		-- the ground along the wall: the lawn's edge and zone 1's trench lip rose through its plaster
		if DO_TERRAIN then
			fillBox(
				math.min(s * 160, s * 244),
				math.max(s * 160, s * 244),
				LAWN + 2,
				40,
				160.5,
				169,
				Enum.Material.Air
			)
		end
		lowWall(lobbyWall, s * 164, s * 233, 161, 165, "LedgeParapet", LAWN)
		-- a post at each end: a slim one at the stage, a pier built into the gate tower's plinth
		-- (its front face is at z 167, 2 behind the wall's back)
		for _, e in { { x = 161, w = 6, d = 6, z = 163 }, { x = 238, w = 10, d = 10, z = 164 } } do
			local post = Instance.new("Model")
			post.Name = "LedgePost"
			local top = LAWN + 16
			block(
				post,
				"Post",
				Vector3.new(e.w, top + 3, e.d),
				CFrame.new(s * e.x, (top - 3) / 2, e.z),
				STONE,
				STONE_M,
				true
			)
			block(
				post,
				"PostBand",
				Vector3.new(e.w + 1, 1.2, e.d + 1),
				CFrame.new(s * e.x, LAWN + 5.5, e.z),
				STONE_DARK,
				Enum.Material.Slate
			)
			block(
				post,
				"PostCap",
				Vector3.new(e.w + 1.5, 1.6, e.d + 1.5),
				CFrame.new(s * e.x, top + 0.8, e.z),
				STONE_DARK,
				Enum.Material.Slate
			)
			post.Parent = lobbyWall
		end
	end
end

-- ---------------------------------------------------------------------------------- 2. the town wall
-- One wall all round the town, in zone 1's great-wall dress and at its height (foot to g + 20, a
-- plaster body between posts, a tile gable: the top is g + 44), its foot down in the sea. `inward`
-- is the way its inner face looks (the banners hang there, at the along-positions `banners`).
local function bigWall(
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	g: number,
	bottom: number,
	inward: Vector3,
	banners: { number }?
)
	local alongX = (x1 - x0) >= (z1 - z0)
	local len = if alongX then x1 - x0 else z1 - z0
	local th = if alongX then z1 - z0 else x1 - x0
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local at = CFrame.new(cx, g, cz)
		* (if alongX then CFrame.new() else CFrame.Angles(0, math.pi / 2, 0))
	local m = Instance.new("Model")
	m.Name = "TownWall"
	block(
		m,
		"Foot",
		Vector3.new(len, 20 + g - bottom, th),
		at * CFrame.new(0, (20 - (g - bottom)) / 2, 0),
		STONE,
		STONE_M,
		true
	)
	block(
		m,
		"FootBand",
		Vector3.new(len, 2.4, th + 2),
		at * CFrame.new(0, 21.2, 0),
		STONE_DARK,
		Enum.Material.Slate,
		true
	)
	block(
		m,
		"Body",
		Vector3.new(len, 14, th - 3),
		at * CFrame.new(0, 29.4, 0),
		PLASTER,
		PLASTER_M,
		true
	)
	local n = math.max(1, math.floor(len / 24))
	for i = 0, n do
		block(
			m,
			"Post",
			Vector3.new(2, 14, th - 2.2),
			at * CFrame.new(-len / 2 + 2 + i * (len - 4) / n, 29.4, 0),
			WOOD_DARK,
			Enum.Material.Wood
		)
	end
	gable(m, at * CFrame.new(0, 37.1, 0), len, th / 2 + 3, 7)
	-- banners on the inner face, read from inside: the cloth's -Z (its decal) looks along `inward`
	local face = (th - 3) / 2 + 0.3
	for _, a in banners or {} do
		local p = if alongX then Vector3.new(a, g + 28.6, cz) else Vector3.new(cx, g + 28.6, a)
		p += inward * face
		banner(m, CFrame.lookAt(p, p + inward), 9, 11)
	end
	m.Parent = fRim
	claim(rect(x0, x1, z0, z1, "TownWall"))
end
-- the sides from the back wall's inner face to zone 1's great wall; the back corner to corner
for _, s in { -1, 1 } do
	local x0, x1 = s * IN_X, s * OUT_X
	bigWall(
		math.min(x0, x1),
		math.max(x0, x1),
		IN_Z,
		FRONT,
		G,
		WALL_BOTTOM,
		Vector3.new(-s, 0, 0),
		{ -245, -106, 24, 142 }
	)
end
bigWall(
	-OUT_X,
	OUT_X,
	OUT_Z,
	IN_Z,
	G,
	WALL_BOTTOM,
	Vector3.new(0, 0, 1),
	{ -398, -272, -142, 0, 142, 272, 398 }
)
-- keeps, each in line with something inside: the corners bigger; on the sides the back street's
-- end, the side shrine's lane and the dojo's front wall; on the back every compound wall. Their
-- feet stand in the sea like the wall's.
for _, s in { -1, 1 } do
	local side = if s > 0 then 90 else -90
	keep(fRim, s * WX, WZ, 28, G + 40, 0.66, 180, WALL_BOTTOM, "RimCornerKeep")
	keep(fRim, s * WX, 196, 28, G + 40, 0.66, side, WALL_BOTTOM, "RimCornerKeep")
	for _, z in { -172, AXIS_Z, 88 } do
		keep(fRim, s * WX, z, 26, G + 38, 0.58, side, WALL_BOTTOM, "RimKeep")
	end
	for _, x in { 78, 206, 338 } do
		keep(fRim, s * x, WZ, 26, G + 38, 0.58, 180, WALL_BOTTOM, "RimKeep")
	end
end
-- zone 1's great wall (z 189..203): from its end turret (x 365..395) to the town wall's front
-- keep. North of it is the sea (lane_border.luau), so its foot goes down into the water.
do
	local GW_Z, GW_T = 196, 14
	for _, s in { -1, 1 } do
		local function seg(a: number, b: number, g: number)
			local x0, x1 = s * a, s * b
			local flags = if b - a > 40 then { s * (a + b) / 2 } else nil
			bigWall(
				math.min(x0, x1),
				math.max(x0, x1),
				GW_Z - GW_T / 2,
				GW_Z + GW_T / 2,
				g,
				WALL_BOTTOM,
				Vector3.new(0, 0, -1),
				flags
			)
		end
		seg(395, WX - 14, G)
	end
end

-- ---------------------------------------------------------------------------------- 3. the ring street
local LANTERN = KIT.Prop_store_StoneLantern
local function H(name: string): Instance
	return KIT["Prop_store_" .. name]
end
pave(fStreets, -(IN_X - 6), IN_X - 6, SB0, SB1, G, STREET, Enum.Material.Cobblestone, "BackStreet")
claim(rect(-(IN_X - 6), IN_X - 6, SB0, SB1, "BackStreet"))
for _, s in { -1, 1 } do
	local x0, x1 = s * SS0, s * SS1
	pave(fStreets, x0, x1, SB1, 177, G, STREET, Enum.Material.Cobblestone, "SideStreet")
	claim(rect(math.min(x0, x1), math.max(x0, x1), SB1, 177, "SideStreet"))
end
-- stone lanterns on the verge between the lobby wall and the street
for _, x in { 40, 110, 240, 300 } do
	for _, s in { -1, 1 } do
		put(fProps, LANTERN, 1.0, 0, s * x, G - 0.2, FACE_Z - 3)
	end
end
for _, z in { -130, -90, 10, 50, 130, 165 } do
	for _, s in { -1, 1 } do
		put(fProps, LANTERN, 1.0, 0, s * (FACE_X + 3), G - 0.2, z)
	end
end

-- ---------------------------------------------------------------------------------- 4. the compounds
-- Everything is written for the +X side and mirrored: x -> -x, a yaw of 90 (faces -X) -> -90.
local Y = G - 0.2 -- a building's pivot on the ground
local function P(
	parent: Instance,
	tpl: Instance,
	scale: number,
	yaw: number,
	s: number,
	x: number,
	z: number,
	y: number?,
	soft: number?
): Model?
	return put(parent, tpl, scale, if s < 0 then -yaw else yaw, s * x, y or Y, z, soft)
end
local function W(s: number, x0: number, x1: number, z0: number, z1: number, name: string)
	lowWall(fCWalls, s * x0, s * x1, z0, z1, name)
end
local function PV(
	parent: Instance,
	s: number,
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	y: number,
	color: Color3,
	mat: Enum.Material,
	name: string
)
	pave(parent, s * x0, s * x1, z0, z1, y, color, mat, name)
end
local GATE = Z14.Gatehouse -- 44 x 20 x 13
local TORII = HUB.DojoGate -- 34 x 26 x 4 (its pivot is 12.8 above its feet: make() stands it up)
local SAKURA = H("SakuraFluffy")
local PINE = Z14.Pine
local function torii(parent: Instance, s: number, scale: number, yaw: number, x: number, z: number)
	return P(parent, TORII, scale, yaw, s, x, z, G - 0.2)
end

for _, s in { -1, 1 } do
	-- separators between the back compounds, from the front wall line to the back keeps' feet
	for _, x in { 76, 204, 336 } do
		W(s, x, x + 4, CW0, KEEP_Z, "CompoundWall")
	end
end

-- THE CASTLE: a forecourt off the back street, a stair up the stone base, the keep and two turrets
do
	local BY = G + 14
	local run = math.ceil(BY + 0.6 - G) * 1.5
	local bz0 = SB0 - run -- the base's front, at the top of its stair
	local bz1 = IN_Z + 12
	local bx = 70
	pave(fCastle, -76, 76, SB0, bz0 - 1, G, PATH, Enum.Material.Slate, "Forecourt")
	local base = Instance.new("Model")
	base.Name = "CastleBase"
	block(
		base,
		"Ishigaki",
		Vector3.new(bx * 2, BY - G + 8, bz0 - bz1),
		CFrame.new(0, (BY + G - 8) / 2, (bz0 + bz1) / 2),
		STONE,
		STONE_M,
		true
	)
	block(
		base,
		"IshigakiBand",
		Vector3.new(bx * 2 + 2, 1.6, bz0 - bz1 + 2),
		CFrame.new(0, BY - 0.4, (bz0 + bz1) / 2),
		STONE_DARK,
		Enum.Material.Slate,
		true
	)
	block(
		base,
		"Court",
		Vector3.new(bx * 2 - 6, 0.6, bz0 - bz1 - 6),
		CFrame.new(0, BY + 0.3, (bz0 + bz1) / 2),
		Color3.fromRGB(214, 204, 184),
		Enum.Material.Sand,
		true
	)
	base.Parent = fCastle
	claim(rect(-bx - 1, bx + 1, bz1, bz0, "CastleBase"))
	stair(fCastle, Vector3.new(0, G, SB0), Vector3.new(0, 0, -1), G, BY + 0.6, 22, "CastleStair")
	local cz = (bz0 + bz1) / 2 - 2
	local castle = make(fCastle, H("Castle"), 1.0, 180, Vector3.new(0, BY + 0.6, cz))
	castle.Name = "Castle"
	for _, s in { -1, 1 } do
		make(fCastle, H("TowerBig"), 0.9, 180, Vector3.new(s * (bx - 14), BY + 0.6, bz0 - 14))
		make(fCastle, PINE, 1.0, 0, Vector3.new(s * (bx - 14), BY + 0.4, bz1 + 12))
		make(fCastle, LANTERN, 1.3, 0, Vector3.new(s * 22, BY + 0.4, bz0 - 6))
		P(fCastle, H("StoneLanternWide"), 1.0, 0, s, 20, (SB0 + bz0) / 2)
		P(fCastle, H("StoneLanternWide"), 1.0, 0, s, 46, (SB0 + bz0) / 2)
		P(fCastle, PINE, 1.0, 0, s, 63, (SB0 + bz0) / 2)
	end
end

for _, s in { -1, 1 } do
	-- THE POND GARDEN (x 80..204): a gatehouse off the street, a gravel walk to the pond, the
	-- pavilion beyond it, cherry trees in the corners
	do
		local gx = 142
		P(fGarden, GATE, 1.0, 180, s, gx, CW0 - 6.5 + 0.1 - 0.2)
		W(s, 80, gx - 22, CW0, CW1, "CompoundWall")
		W(s, gx + 22, 204, CW0, CW1, "CompoundWall")
		PV(
			fGarden,
			s,
			gx - 5,
			gx + 5,
			CW0,
			POND.z1 + 3,
			G + 0.15,
			PATH,
			Enum.Material.Slate,
			"Walk"
		)
		-- the pond's stone rim (the water was let into the terrain above)
		local r = 3
		local rim = Instance.new("Model")
		rim.Name = "PondRim"
		local px0, px1 = math.min(s * POND.x0, s * POND.x1), math.max(s * POND.x0, s * POND.x1)
		local function rimBlock(x0: number, x1: number, z0: number, z1: number)
			block(
				rim,
				"Rim",
				Vector3.new(x1 - x0, 7, z1 - z0),
				CFrame.new((x0 + x1) / 2, G + 0.8 - 3.5, (z0 + z1) / 2),
				STONE,
				Enum.Material.Slate,
				true
			)
		end
		rimBlock(px0 - r, px1 + r, POND.z0 - r, POND.z0)
		rimBlock(px0 - r, px1 + r, POND.z1, POND.z1 + r)
		rimBlock(px0 - r, px0, POND.z0, POND.z1)
		rimBlock(px1, px1 + r, POND.z0, POND.z1)
		rim.Parent = fGarden
		claim(rect(px0 - r, px1 + r, POND.z0 - r, POND.z1 + r, "Pond"))
		P(fGarden, H("BridgeCover"), 1.0, 180, s, gx, -292)
		for _, c in { { 100, -215 }, { 184, -215 }, { 98, -292 }, { 186, -292 } } do
			P(fGarden, SAKURA, 1.0, rng:NextInteger(0, 3) * 90, s, c[1], c[2], G - 0.4, 1)
		end
		P(fGarden, HUB.SakuraSoft, 1.0, 0, s, 95, -253, G - 0.4, 1)
		P(fGarden, HUB.SakuraSoft, 1.0, 0, s, 189, -253, G - 0.4, 1)
		P(fGarden, H("ZenLantern"), 1.3, 0, s, POND.x0 - 1, POND.z1 + 6)
		P(fGarden, H("ZenLantern"), 1.3, 0, s, POND.x1 + 1, POND.z1 + 6)
		P(fGarden, LANTERN, 1.1, 0, s, gx - 12, CW1 - 14)
		P(fGarden, LANTERN, 1.1, 0, s, gx + 12, CW1 - 14)
		P(fGarden, Z2.MossRock, 0.45, 0, s, POND.x0 + 4, POND.z0 - 8)
		P(fGarden, Z2.MossRock, 0.4, 90, s, POND.x1 - 4, POND.z0 - 8)
		P(fGarden, H("Bonsai"), 1.2, 0, s, gx - 22, CW1 - 14)
		P(fGarden, H("Bonsai"), 1.2, 0, s, gx + 22, CW1 - 14)
	end

	-- THE TORII SHRINE (x 208..336): open to the street, a walk under four torii to the shrine,
	-- a smaller shrine either side facing the walk, braziers, a gong, pines at the front
	do
		local ax = 272
		PV(fShrine, s, 208, 336, SB0, KEEP_Z, G, GRAVEL, Enum.Material.Sand, "Court")
		PV(fShrine, s, ax - 9, ax + 9, SB0, -276, G + 0.15, PATH, Enum.Material.Slate, "Walk")
		for _, z in { -202, -214, -226, -238, -250 } do
			torii(fShrine, s, 1.0, 0, ax, z)
		end
		for _, z in { -208, -220, -232, -244 } do
			P(fShrine, LANTERN, 1.0, 0, s, ax - 21, z)
			P(fShrine, LANTERN, 1.0, 0, s, ax + 21, z)
		end
		P(fShrine, H("ShrineA"), 1.6, 180, s, ax, -287)
		P(fShrine, H("ShrineB"), 1.25, -90, s, 228, -285)
		P(fShrine, H("ShrineB"), 1.25, 90, s, 316, -285)
		P(fShrine, H("Brazier"), 1.0, 0, s, ax - 26, -262)
		P(fShrine, H("Brazier"), 1.0, 0, s, ax + 26, -262)
		P(fShrine, SAKURA, 1.0, 0, s, 232, -222, G - 0.4, 1)
		P(fShrine, SAKURA, 1.0, 90, s, 312, -222, G - 0.4, 1)
		P(fShrine, H("GongA"), 1.0, -90, s, 228, -245)
		P(fShrine, H("GongB"), 1.0, 90, s, 316, -245)
		P(fShrine, PINE, 1.0, 0, s, 222, -206)
		P(fShrine, PINE, 1.0, 0, s, 322, -206)
		P(fShrine, H("StoneLanternWide"), 1.0, 0, s, 214, SB0 - 4)
		P(fShrine, H("StoneLanternWide"), 1.0, 0, s, 330, SB0 - 4)
	end

	-- THE WATCH CORNER (x 340..452): a gatehouse, storehouses round a yard with a well, a hall
	-- and a watchtower at the back
	do
		local gx = 396
		PV(fWatch, s, 340, IN_X, CW1, IN_Z, G, YARD, Enum.Material.Sand, "Yard")
		P(fWatch, GATE, 1.0, 180, s, gx, CW0 - 6.5 + 0.1 - 0.2)
		W(s, 340, gx - 22, CW0, CW1, "CompoundWall")
		W(s, gx + 22, IN_X, CW0, CW1, "CompoundWall")
		P(fWatch, H("FarmHouseC"), 1.0, 180, s, 360, -226)
		P(fWatch, H("HallB"), 1.0, 180, s, 432, -224)
		P(fWatch, Z9.Well, 1.0, 0, s, gx, -246)
		P(fWatch, Z9.Wagon, 1.0, 90, s, 410, -262)
		P(fWatch, H("MarketTent"), 1.0, 0, s, 378, -256)
		P(fWatch, Z14.Hall, 1.2, 180, s, 372, -288)
		P(fWatch, H("TowerBig"), 1.0, 180, s, 430, -290)
		P(fWatch, Z14.Lantern, 1.0, 0, s, gx - 12, CW1 - 14)
		P(fWatch, Z14.Lantern, 1.0, 0, s, gx + 12, CW1 - 14)
		for i, c in { { 349, -246 }, { 354, -246 }, { 351, -250 } } do
			P(fWatch, if i == 2 then H("Crate") else H("Barrel"), 1.2, 0, s, c[1], c[2])
		end
	end

	-- THE PAGODA TEMPLE (x 384..452, z -172..-62): a gatehouse on the side street, the pagoda
	-- behind it, cherry trees in the court's corners
	do
		local gz = -117
		PV(fTemple, s, SW1, IN_X, SB1 + 4, -62, G, GRAVEL, Enum.Material.Sand, "Court")
		W(s, SW0, IN_X - 6, SB1, SB1 + 4, "CompoundWall")
		W(s, SW0, SW1, SB1 + 4, gz - 22, "CompoundWall")
		W(s, SW0, SW1, gz + 22, -62, "CompoundWall")
		W(s, SW0, IN_X, -62, -58, "CompoundWall")
		P(fTemple, GATE, 1.0, 90, s, SW0 + 6.6, gz)
		PV(fTemple, s, SW1 + 4, 409, gz - 8, gz + 8, G + 0.15, PATH, Enum.Material.Slate, "Walk")
		P(fTemple, H("PagodaTemple"), 0.86, 90, s, 428, gz)
		P(fTemple, LANTERN, 1.1, 0, s, 398, gz - 13)
		P(fTemple, LANTERN, 1.1, 0, s, 398, gz + 13)
		for _, c in { { 398, -158 }, { 436, -158 }, { 398, -76 }, { 436, -76 } } do
			P(fTemple, SAKURA, 1.0, rng:NextInteger(0, 3) * 90, s, c[1], c[2], G - 0.4, 1)
		end
	end

	-- THE SIDE SHRINE (the lane on the side axis, z -58..-22): a torii at its mouth, a shrine at
	-- its end against the town wall
	do
		PV(fLane, s, SS1, IN_X, -58, -22, G, PATH, Enum.Material.Slate, "Lane")
		torii(fLane, s, 0.9, 90, 392, AXIS_Z)
		P(fLane, H("ShrineA"), 1.2, 90, s, 432, AXIS_Z)
		for _, z in { AXIS_Z - 12, AXIS_Z + 12 } do
			P(fLane, LANTERN, 1.1, 0, s, 405, z)
			P(fLane, LANTERN, 1.1, 0, s, 414, z)
		end
	end

	-- THE DOJO (x 384..452, z -18..86): a gatehouse, a training yard with posts, the dojo at the
	-- back, pines in the corners
	do
		local gz = 34
		PV(fDojo, s, SW1, IN_X, -18, 86, G, YARD, Enum.Material.Sand, "Yard")
		W(s, SW0, IN_X, -22, -18, "CompoundWall")
		W(s, SW0, SW1, -18, gz - 22, "CompoundWall")
		W(s, SW0, SW1, gz + 22, 86, "CompoundWall")
		W(s, SW0, IN_X - 6, 86, 90, "CompoundWall")
		P(fDojo, GATE, 1.0, 90, s, SW0 + 6.6, gz)
		P(fDojo, Z14.Dojo, 1.2, 90, s, 432, gz)
		for _, x in { 398, 408 } do
			for _, z in { 4, 16, 52, 64 } do
				P(fDojo, H("TrainingPole"), 1.0, 90, s, x, z)
			end
		end
		P(fDojo, Z14.Lantern, 1.0, 0, s, 412, gz - 12)
		P(fDojo, Z14.Lantern, 1.0, 0, s, 412, gz + 12)
		for _, c in { { 396, -8 }, { 436, -8 }, { 396, 76 }, { 436, 76 } } do
			P(fDojo, PINE, 1.0, 0, s, c[1], c[2])
		end
		P(fDojo, Z14.SwordRack, 1.0, 90, s, 440, 6)
		P(fDojo, Z14.SwordRack, 1.0, 90, s, 440, 62)
	end

	-- THE TEA GARDEN (x 376..452, z 90..177): open to the street at the town's front; a sweet
	-- shop, the teahouse, a wisteria, the pavilion by zone 1's great wall
	do
		PV(fTea, s, SS1, 419, 128, 134, G + 0.15, PATH, Enum.Material.Slate, "Walk")
		P(fTea, Z14.SweetShop, 1.0, 90, s, 387, 110)
		P(fTea, H("FarmHouseA"), 1.0, 90, s, 433, 122)
		P(fTea, Z2.Wisteria, 1.0, 0, s, 392, 152, G - 0.4, 1)
		P(fTea, H("BridgeCover"), 1.0, 90, s, 427, 161)
		P(fTea, LANTERN, 1.1, 0, s, 410, 124)
		P(fTea, LANTERN, 1.1, 0, s, 410, 138)
		P(fTea, H("Bonsai"), 1.2, 0, s, 400, 98)
	end
end

-- ---------------------------------------------------------------------------------- 5. the forecourts
-- Behind each entrance wall, up to zone 1's great wall and its gate tower, the town's ground goes on:
-- raised to G and paved like its streets, in strips 6 wide that each start inside the wall's body
-- (nothing reaches into the lobby, no slot shows), cherry trees and lanterns along the wall. In
-- front of it, the strip the old funnel wall cut off is the lobby's lawn again, at its level.
do
	local A, B = ENTRANCE_A, ENTRANCE_B
	local function lineZ(x: number): number -- the entrance wall's middle line (+X)
		return A.Z + (A.X - x) * (B.Z - A.Z) / (A.X - B.X)
	end
	local function oldZ(x: number): number -- the old funnel wall's middle line (+X)
		return 89 + (355 - x) * (163 - 89) / (355 - 165)
	end
	local HALF = WALL_T / 2 / math.cos(math.atan((B.Z - A.Z) / (A.X - B.X))) -- half the wall along z
	for _, s in { -1, 1 } do
		claim(rect(s * 234, s * 295, 165, 235, "Zone1GateTower"))
		claim(rect(s * 293, s * 368, 189, 203, "Zone1GreatWall"))
		-- the lobby's lawn where the old funnel wall stood and behind it, up to the new wall, the
		-- ledge (z 160) and zone 1's tower
		if DO_TERRAIN then
			for x0 = 160, A.X - 4, 4 do
				local x1 = x0 + 4
				local z0 = oldZ(x0) - 5
				local z1 = math.min(lineZ(x1) - HALF + 1, if x1 <= 241 then 160 else 166)
				if z1 - z0 > 1 then
					local a, b = math.min(s * x0, s * x1), math.max(s * x0, s * x1)
					fillBox(a, b, 0, 40, z0, z1 + 3, Enum.Material.Air) -- into the wall: no lawn creeps up its foot
					fillBox(a, b, -12, -1, z0, z1 - 1, Enum.Material.Grass)
					-- zone 1's ledge stone and the town's grass showed through as blotches: one lawn
					for _, m in
						{ Enum.Material.Slate, Enum.Material.Rock, GRASS_M, Enum.Material.Ground }
					do
						T:ReplaceMaterial(
							Region3.new(Vector3.new(a, -16, z0 - 6), Vector3.new(b, 8, z1 + 6))
								:ExpandToGrid(4),
							4,
							m,
							Enum.Material.Grass
						)
					end
				end
			end
		end
		-- the forecourt
		for x0 = math.floor(B.X / 6) * 6, FACE_X - 6, 6 do
			local x1 = x0 + 6
			local z0 = lineZ(x0) - 0.5
			local z1 = if x1 <= 293 then 167 else FRONT
			if z1 - z0 > 1 then
				local a, b = math.min(s * x0, s * x1), math.max(s * x0, s * x1)
				if DO_TERRAIN then
					fillBox(a, b, -10, G - 2, z0 + 1, z1, GRASS_M)
				end
				pave(fStreets, a, b, z0, z1, G, STREET, Enum.Material.Cobblestone, "Forecourt")
			end
		end
		-- cherry trees and lanterns along the wall's outer face
		local a, b = Vector3.new(s * A.X, 0, A.Z), Vector3.new(s * B.X, 0, B.Z)
		local u = (b - a).Unit
		local n = Vector3.new(-u.Z, 0, u.X)
		if n.Z < 0 then
			n = -n
		end
		for t = 30, 100, 30 do
			local p = a + u * t + n * 24
			put(fTrees, SAKURA, 1.2, rng:NextInteger(0, 3) * 90, p.X, G - 0.4, p.Z, 2)
			local q = a + u * (t + 15) + n * 13
			put(fProps, LANTERN, 1.2, 0, q.X, G - 0.2, q.Z)
		end
	end
end

town.Parent = scenery

-- ---------------------------------------------------------------------------------- report
-- the claims are footprints; check what was actually built, pairwise, by its parts' boxes
local function box(inst: Instance): (Vector3, Vector3)
	local lo, hi = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
	for _, p in partsOf(inst) do
		if p.Transparency < 1 then
			local cf, half = p.CFrame, p.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local c = (cf * CFrame.new(half.X * sx, half.Y * sy, half.Z * sz)).Position
						lo, hi = lo:Min(c), hi:Max(c)
					end
				end
			end
		end
	end
	return lo, hi
end
local built = {}
for _, f in { fCastle, fGarden, fShrine, fWatch, fTemple, fLane, fDojo, fTea, fCWalls } do
	for _, m in f:GetChildren() do
		if m:IsA("Model") and not m.Name:match("Stair$") and m.Name ~= "CompoundWall" then
			local lo, hi = box(m)
			table.insert(built, { m = m, lo = lo, hi = hi })
		end
	end
end
local clashes = {}
for i = 1, #built do
	for j = i + 1, #built do
		local a, b = built[i], built[j]
		local ox = math.min(a.hi.X, b.hi.X) - math.max(a.lo.X, b.lo.X)
		local oz = math.min(a.hi.Z, b.hi.Z) - math.max(a.lo.Z, b.lo.Z)
		local oy = math.min(a.hi.Y, b.hi.Y) - math.max(a.lo.Y, b.lo.Y)
		if ox > 0.5 and oz > 0.5 and oy > 0.5 then
			table.insert(
				clashes,
				string.format(
					"%s @%.0f,%.0f x %s @%.0f,%.0f (%.1f x %.1f)",
					a.m.Name,
					(a.lo.X + a.hi.X) / 2,
					(a.lo.Z + a.hi.Z) / 2,
					b.m.Name,
					(b.lo.X + b.hi.X) / 2,
					(b.lo.Z + b.hi.Z) / 2,
					ox,
					oz
				)
			)
		end
	end
end
local counts = {}
for _, f in town:GetChildren() do
	table.insert(counts, f.Name .. "=" .. #f:GetChildren())
end
return string.format(
	"lobby town: %d models, %s\nrefused %d:\n  %s\nbuilt clashes %d:\n  %s",
	made,
	table.concat(counts, " "),
	#refused,
	table.concat(refused, "\n  "),
	#clashes,
	table.concat(clashes, "\n  ")
)
