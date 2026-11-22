-- lobby_wall.luau - Studio EDIT mode, safe to run again. The lobby's wall is the END of the map.
--
-- Owner (2026-11-22): the map feels too big: remove the outer part of the lobby completely (the town
-- wall and everything between it and the lobby wall), bring the lobby's sides in close to the bases
-- ("a lot of space" between the outermost base and the wall), and connect everything smoothly.
--   * ONE wall all round the lobby in zone 1's great-wall dress (the lane's border walls wear it
--     too): stone foot down in the sea, plaster body between timber posts, a tile gable, top y 44.
--     Inner faces x +-248 (29.5 studs of lawn beside the outer bases) and z -156. The sides run
--     straight on from the back corners into zone 1's great wall (z 192): one line from the back
--     of the lobby to the lane. Keeps at the corners, halfway, at the front and on the back.
--   * outside it, the sea (water to y -4 on a sand bed), as round the lane.
--   * the back districts come in with the sides: Hall of Legends and Ramen Alley 90 studs, Rewards
--     and Rankings 14 (their decks, statues, stations, leaderboards and prompts with them).
--   * zone 1's great wall (z 189..203) now stands in the sea: a stone foot down to the sea bed.
-- Archived once in ServerStorage.MapArchive.LobbyTown_v1 (never delete): Scenery.LobbyTown (the
-- walled town and its town wall), the old lobby and entrance walls, the side lawns' pagodas, trees,
-- lanterns and bushes, the back's gongs and poles where the districts now stand.
-- Run AFTER base_layout.luau. Run: python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py
-- luau --file <this file>
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local T = workspace.Terrain
local map = workspace.Map
local hub, hubV2 = map.Hub, map.HubV2
local KIT = RS.Assets.Kit
local KEEP = SS.StoreAssets.Zone01_Naruto.GateTowerMesh -- zone 1's gate keep (generated)
local LANTERN = KIT.Prop_store_StoneLantern
local DO_TERRAIN = true

-- ---------------------------------------------------------------------------------- the plan
local TH = 14 -- the wall's thickness
local IN_X, IN_Z = 248, -156 -- the inner faces: the lobby is inside these
local FACE_X, FACE_Z = IN_X + TH, IN_Z - TH -- the outer faces (262, -170): the map ends here
local WX, WZ = IN_X + TH / 2, IN_Z - TH / 2 -- the centre lines (255, -163)
local SIDE_END = 192 -- the sides end inside zone 1's great wall (x 217..262, z 189..203: zone_01_naruto.luau)
local TOWER_IN, TOWER_OUT = 160, 217 -- zone 1's gate tower plinths (zone_01_naruto.luau v2)
local STAGE_HALF = 100 -- the throw stage's half width (config World.LaneWidth / 2)
local G = 0 -- the lobby's ground
local BOTTOM = -44 -- the wall's foot goes down into the sea
local SEA_Y = -4
local EDGE_X, EDGE_Z = 560, -660 -- the sea is laid out to here
local GREAT_WALL_Z = 189 -- zone 1's great wall's south face: the sea comes up to it
local SHIFTS = { -- the districts' moves inward (x), with what belongs to each
	{
		folder = "HallOfLegends",
		dx = -90,
		v2 = { "LegendsDeck", "LegendsDeckRim", "CursedShrine", "Statue_" },
		hub = { "SellBooth" },
	},
	{ folder = "RamenAlley", dx = 90, v2 = { "RamenDeck", "RamenDeckRim" }, hub = { "FoodCart" } },
	{
		folder = "Rewards",
		dx = -14,
		v2 = { "RewardsDeck", "RewardsDeckRim", "RewardsStage", "RewardsStageRim" },
		hub = { "DailyChest", "GiftBox", "IndexBoard" },
	},
	{
		folder = "Rankings",
		dx = 14,
		v2 = { "RankingsDeck", "RankingsDeckRim", "RankingsStage", "RankingsStageRim" },
		hub = { "BoardYen", "BoardCaught", "BoardRarest" },
	},
}

local WOOD_DARK = Color3.fromRGB(74, 50, 38)
local STONE = Color3.fromRGB(186, 170, 150)
local STONE_DARK = Color3.fromRGB(140, 126, 112)
local PLASTER = Color3.fromRGB(246, 234, 204)
local ROOF = Color3.fromRGB(196, 84, 58)
local ROOF_DARK = Color3.fromRGB(142, 56, 44)
local RED = Color3.fromRGB(196, 52, 46)
local DECAL_LEAF = "rbxassetid://3786177973" -- the village emblem (zone 1's)
local STONE_M, PLASTER_M = Enum.Material.Brick, Enum.Material.Plaster

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
local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	solid: boolean?,
	class: string?
): BasePart
	local p = Instance.new(class or "Part") :: BasePart
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
	return p
end
-- a tiled gable roof: at's X axis is the ridge, its origin the middle of the eave line
local function gable(parent: Instance, at: CFrame, length: number, half: number, height: number)
	for _, s in { -1, 1 } do
		local turn = if s > 0 then CFrame.Angles(0, math.pi, 0) else CFrame.new()
		block(
			parent,
			"Roof",
			Vector3.new(length, height, half),
			at * CFrame.new(0, height / 2, s * half / 2) * turn,
			ROOF,
			Enum.Material.ClayRoofTiles,
			false,
			"WedgePart"
		).CastShadow =
			true
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
		-- a template whose pivot is not at its feet: stand it on `at`
		local cf, size = m:GetBoundingBox()
		local lift = at.Y - (cf.Position.Y - size.Y / 2)
		if math.abs(lift) > 1 then
			m:PivotTo(m:GetPivot() + Vector3.new(0, lift, 0))
		end
	end
	for _, p in partsOf(m) do
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
	end
	m.Parent = parent
	return m
end
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
-- an axis-aligned box of the visible parts of `inst`
local function boxOf(inst: Instance): (Vector3, Vector3)
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
local function centre(inst: Instance): Vector3
	if inst:IsA("Model") then
		return (inst:GetBoundingBox()).Position -- HubV2 pivots sit 3000 studs off
	elseif inst:IsA("BasePart") then
		return inst.Position
	end
	local lo, hi = boxOf(inst)
	return (lo + hi) / 2
end
local function shift(inst: Instance, d: Vector3)
	if inst:IsA("Model") then
		inst:PivotTo(inst:GetPivot() + d)
	else
		for _, p in partsOf(inst) do
			p.CFrame += d
		end
		for _, m in inst:GetDescendants() do
			if m:IsA("Model") and not m.PrimaryPart then
				m.WorldPivot += d
			end
		end
	end
end

-- ---------------------------------------------------------------------------------- 0. archive
local archiveRoot = SS:FindFirstChild("MapArchive") or folder(SS, "MapArchive")
local archive = archiveRoot:FindFirstChild("LobbyTown_v1")
if not archive then
	archive = folder(archiveRoot, "LobbyTown_v1")
	archive:SetAttribute(
		"Note",
		"The walled town round the lobby, the old lobby and entrance walls and the side lawns' props, before lobby_wall.luau (2026-11-22). Never delete."
	)
end
local stashed = 0
local function stash(inst: Instance, tag: string)
	inst.Name = tag .. "_" .. inst.Name
	inst.Parent = archive
	stashed += 1
end
local town = map.Scenery:FindFirstChild("LobbyTown")
if town then
	stash(town, "Scenery")
end
-- the old walls (the ledge's parapets and posts are rebuilt below, to zone 1's towers)
local walls = hub.Walls
local built = walls:FindFirstChild("Lobby")
if built then
	built:Destroy()
end
for _, c in walls:GetChildren() do
	if c.Name == "LedgeParapet" or c.Name == "LedgePost" then
		c:Destroy() -- rebuilt below
	else
		stash(c, "Walls")
	end
end
-- the side lawns' props: nothing may stand in the wall or outside it
for _, c in hubV2:GetChildren() do
	if c:IsA("Model") or c:IsA("BasePart") then
		local p = centre(c)
		if math.abs(p.X) > IN_X - 12 and p.Z > -80 and p.Z < 200 then
			stash(c, "HubV2")
		end
	end
end
for _, c in hub.Dressing:GetChildren() do
	local p = centre(c)
	if math.abs(p.X) > IN_X - 12 or (math.abs(p.X) > 140 and p.Z < -140) then
		stash(c, "Dressing")
	end
end

-- ---------------------------------------------------------------------------------- 1. the districts
local protected: { [Instance]: boolean } = {}
local decks = {}
for _, s in SHIFTS do
	local f = hub.Districts:FindFirstChild(s.folder) :: Folder
	assert(f, "no district " .. s.folder)
	local applied = f:GetAttribute("ShiftX") or 0
	local d = Vector3.new(s.dx - applied, 0, 0)
	local list = { f }
	for _, name in s.hub do
		table.insert(list, hub:FindFirstChild(name))
	end
	for _, c in hubV2:GetChildren() do
		for _, prefix in s.v2 do
			if c.Name == prefix or (prefix:sub(-1) == "_" and c.Name:sub(1, #prefix) == prefix) then
				table.insert(list, c)
			end
		end
	end
	for _, inst in list do
		protected[inst] = true
		if d.Magnitude > 0 then
			shift(inst, d)
		end
	end
	f:SetAttribute("ShiftX", s.dx)
	for _, inst in list do
		if inst:IsA("BasePart") and inst.Name:match("DeckRim$") then
			local lo, hi = boxOf(inst)
			table.insert(decks, { lo = lo - Vector3.new(2, 0, 2), hi = hi + Vector3.new(2, 0, 2) })
		end
	end
end
-- anything left standing on a district's deck goes (the planters and trees that filled the gaps)
for _, root in { hub.Plaza, hubV2, hub.Dressing } do
	for _, c in root:GetChildren() do
		if
			not protected[c]
			and (c:IsA("Model") or c:IsA("BasePart"))
			and not c.Name:match("Deck")
		then
			local p = centre(c)
			for _, r in decks do
				if p.X > r.lo.X and p.X < r.hi.X and p.Z > r.lo.Z and p.Z < r.hi.Z then
					stash(c, root.Name)
					break
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------------- 2. terrain
if DO_TERRAIN then
	for _, s in { -1, 1 } do
		-- outside the sides (from the wall's inner face: nothing pokes through its foot) to the sea,
		-- from the back of the map to zone 1's great wall
		local a, b = math.min(s * IN_X, s * EDGE_X), math.max(s * IN_X, s * EDGE_X)
		fillBox(a, b, -60, 160, EDGE_Z, GREAT_WALL_Z, Enum.Material.Air)
		local c, e = math.min(s * FACE_X, s * EDGE_X), math.max(s * FACE_X, s * EDGE_X)
		fillBox(c, e, -48, -40, EDGE_Z, GREAT_WALL_Z, Enum.Material.Sand)
		fillBox(c, e, -40, SEA_Y, EDGE_Z, GREAT_WALL_Z, Enum.Material.Water)
		-- the lawn strip along the side: the base row's paving ends short of the wall
		local l0, l1 = math.min(s * 228, s * IN_X), math.max(s * 228, s * IN_X)
		T:ReplaceMaterial(
			Region3.new(Vector3.new(l0, -12, -54), Vector3.new(l1, 8, 30)):ExpandToGrid(4),
			4,
			Enum.Material.Cobblestone,
			Enum.Material.Grass
		)
	end
	-- between zone 1's gate tower and the side wall, up to the great wall: a corner of the lobby's
	-- lawn (the old terraces there sank to the lane's level)
	for _, s in { -1, 1 } do
		local a, b = math.min(s * TOWER_OUT, s * IN_X), math.max(s * TOWER_OUT, s * IN_X)
		fillBox(a, b, -12, 160, 156, GREAT_WALL_Z, Enum.Material.Air)
		fillBox(a, b, -60, -12, 156, GREAT_WALL_Z, Enum.Material.Ground)
		fillBox(a, b, -12, -1, 156, GREAT_WALL_Z, Enum.Material.Grass)
	end
	fillBox(-IN_X, IN_X, -60, 160, EDGE_Z, IN_Z, Enum.Material.Air)
	-- the sea behind, the full width (the sides' sea starts at the side walls' outer faces)
	fillBox(-EDGE_X, EDGE_X, -48, -40, EDGE_Z, FACE_Z, Enum.Material.Sand)
	fillBox(-EDGE_X, EDGE_X, -40, SEA_Y, EDGE_Z, FACE_Z, Enum.Material.Water)
end
local onGround = RaycastParams.new()
onGround.FilterType = Enum.RaycastFilterType.Include
onGround.FilterDescendantsInstances = { T }
onGround.IgnoreWater = true
local function groundAt(x: number, z: number): number
	local hit = workspace:Raycast(Vector3.new(x, 100, z), Vector3.new(0, -200, 0), onGround)
	return if hit then hit.Position.Y else G
end

-- ---------------------------------------------------------------------------------- 3. the wall
local fWall = folder(walls, "Lobby")
local fKeeps = folder(fWall, "Keeps")
local footprints = {}
-- zone 1's great-wall dress: foot to g + 20, a dark band, a plaster body between posts, a tile gable
-- (top g + 44). `inward` is the way its inner face looks (banners hang there, at `banners`).
local function bigWall(
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	inward: Vector3,
	banners: { number }
)
	local alongX = (x1 - x0) >= (z1 - z0)
	local len = if alongX then x1 - x0 else z1 - z0
	local th = if alongX then z1 - z0 else x1 - x0
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local at = CFrame.new(cx, G, cz)
		* (if alongX then CFrame.new() else CFrame.Angles(0, math.pi / 2, 0))
	local m = Instance.new("Model")
	m.Name = "LobbyWall"
	block(
		m,
		"Foot",
		Vector3.new(len, 20 + G - BOTTOM, th),
		at * CFrame.new(0, (20 - (G - BOTTOM)) / 2, 0),
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
	local face = (th - 3) / 2 + 0.3
	for _, a in banners do
		local p = if alongX then Vector3.new(a, G + 28.6, cz) else Vector3.new(cx, G + 28.6, a)
		p += inward * face
		banner(m, CFrame.lookAt(p, p + inward), 9, 11)
	end
	m.Parent = fWall
	table.insert(footprints, { name = "wall", x0 = x0, x1 = x1, z0 = z0, z1 = z1 })
end
-- a keep on a stone tower whose foot stands in the sea like the wall's
local function keep(
	x: number,
	z: number,
	footW: number,
	footH: number,
	scale: number,
	yaw: number,
	name: string
)
	local m = Instance.new("Model")
	m.Name = name
	block(
		m,
		"TowerFoot",
		Vector3.new(footW, footH - BOTTOM, footW),
		CFrame.new(x, (footH + BOTTOM) / 2, z),
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
	m.Parent = fKeeps
	table.insert(footprints, {
		name = name,
		x0 = x - footW / 2,
		x1 = x + footW / 2,
		z0 = z - footW / 2,
		z1 = z + footW / 2,
	})
end

-- the back, corner to corner; the sides from the back's inner face into zone 1's gate towers
bigWall(-FACE_X, FACE_X, FACE_Z, IN_Z, Vector3.new(0, 0, 1), { -190, -60, 60, 190 })
for _, s in { -1, 1 } do
	local x0, x1 = s * IN_X, s * FACE_X
	bigWall(
		math.min(x0, x1),
		math.max(x0, x1),
		IN_Z,
		SIDE_END,
		Vector3.new(-s, 0, 0),
		{ -100, 20, 130 }
	)
end
for _, s in { -1, 1 } do
	local across = if s > 0 then 90 else -90 -- the keep's front looks across the lobby
	keep(s * WX, WZ, 28, 40, 0.66, 180, "CornerKeep")
	keep(s * WX, -40, 26, 38, 0.58, across, "SideKeep")
	keep(s * WX, 86, 26, 38, 0.58, across, "FrontKeep")
	keep(s * 120, WZ, 26, 38, 0.58, 180, "BackKeep")
end
-- the ledge beside the throw stage: the lobby's lawn runs to the lane's drop between the stage's end and
-- zone 1's gate tower. A low compound wall closes it (top 15, outside the lane: no throw is hidden),
-- a slim post at the stage's end, a pier built into the tower's plinth
local LAWN = 1
local function lowWall(x0: number, x1: number, z0: number, z1: number)
	x0, x1 = math.min(x0, x1), math.max(x0, x1)
	local len, th = x1 - x0, z1 - z0
	local at = CFrame.new((x0 + x1) / 2, LAWN, (z0 + z1) / 2)
	local m = Instance.new("Model")
	m.Name = "LedgeParapet"
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
	m.Parent = walls
end
for _, s in { -1, 1 } do
	if DO_TERRAIN then
		-- the lawn's edge and the ledge's lip rose through the plaster
		fillBox(
			math.min(s * STAGE_HALF, s * TOWER_IN),
			math.max(s * STAGE_HALF, s * TOWER_IN),
			LAWN + 2,
			40,
			160.5,
			169,
			Enum.Material.Air
		)
	end
	lowWall(s * (STAGE_HALF + 4), s * (TOWER_IN - 3), 161, 165)
	for _, e in
		{
			{ x = STAGE_HALF + 1, w = 6, d = 6, z = 163 },
			{ x = TOWER_IN + 2, w = 10, d = 10, z = 164 },
		}
	do
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
		post.Parent = walls
	end
end
-- stone lanterns on the lawn strip beside the outer bases
local fProps = folder(fWall, "Lanterns")
for _, s in { -1, 1 } do
	for _, z in { -20, 50, 120 } do
		local x = s * (IN_X - 10)
		make(
			fProps,
			LANTERN,
			1.0,
			if s > 0 then -90 else 90,
			Vector3.new(x, groundAt(x, z) - 0.2, z)
		)
	end
end

-- ---------------------------------------------------------------------------------- report
-- what the wall and keeps cross: anything of the lobby whose box reaches into their footprint
local hits = {}
local function check(root: Instance)
	for _, c in root:GetChildren() do
		if c ~= walls and (c:IsA("Model") or c:IsA("BasePart") or c:IsA("Folder")) then
			local kids = if c:IsA("Folder") then c:GetChildren() else { c }
			for _, k in kids do
				local lo, hi = boxOf(k)
				if hi.Y > G + 0.5 then
					for _, f in footprints do
						local ox = math.min(hi.X, f.x1) - math.max(lo.X, f.x0)
						local oz = math.min(hi.Z, f.z1) - math.max(lo.Z, f.z0)
						if ox > 0.5 and oz > 0.5 then
							table.insert(
								hits,
								string.format(
									"%s x %s (%.1f x %.1f)",
									k:GetFullName(),
									f.name,
									ox,
									oz
								)
							)
						end
					end
				end
			end
		end
	end
end
check(hub)
check(hubV2)
check(map.Plots)
check(map.Scenery.Plots)
return string.format(
	"lobby wall: %d keeps, archived %d, crossings %d:\n  %s",
	#fKeeps:GetChildren(),
	stashed,
	#hits,
	table.concat(hits, "\n  ")
)
