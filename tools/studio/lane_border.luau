-- lane_border.luau - Studio EDIT mode, safe to run again. The border of the lane's zones.
--
-- Owner's brief (2026-11-22): the lane's sides looked "weird" (old lime hills and cliffs at every
-- height out to the island's edge); keep the map minimal, one border that blends in and connects the
-- lobby and the lane. So the lobby town's outer wall (zone 1's great-wall dress, top at 52) runs on
-- down both sides of the whole lane and closes it behind the finale, and outside it there is only
-- the sea, as round the town:
--   * the walls: x +-306..320 (+-366..380 before the lane lost two tracks; inside: the zones' canyons, untouched; their content ends by x 360),
--     from zone 1's corner turret (x 365..395, z 179..213) to the end wall behind the finale
--     (z 6380..6394); a keep at every zone gate (z 205 + 360 k), at the corners and mid-end
--   * outside: no land. Terrain from x 372 out is cleared (the zone builders only write x 160..368,
--     so a rerun of any zone keeps this), a sand bed and water to the sea's level (-4) out to x 548
--     and 260 beyond the end; inside the end walls the lane's floor ends in water at zone 17's level
--   * the old hill props beyond the wall are archived once in ServerStorage.MapArchive.LaneHills_v1
-- Run lobby_wall.luau first (it lays the sea round the lobby), then this.
-- Run: python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file <this file>
local SS = game:GetService("ServerStorage")
local T = workspace.Terrain
local map = workspace.Map
local scenery = map.Scenery
local KEEP = SS.StoreAssets.Zone01_Naruto.GateTowerMesh -- zone 1's gate keep (generated)

local STONE = Color3.fromRGB(186, 170, 150)
local STONE_DARK = Color3.fromRGB(140, 126, 112)
local PLASTER = Color3.fromRGB(246, 234, 204)
local WOOD_DARK = Color3.fromRGB(74, 50, 38)
local ROOF = Color3.fromRGB(196, 84, 58)
local ROOF_DARK = Color3.fromRGB(142, 56, 44)
local STONE_M, PLASTER_M = Enum.Material.Brick, Enum.Material.Plaster

local G = 8 -- the walls' ground: the town's (top at G + 44 = 52 all round the map)
local SLIM = 60 -- how far the lane's sides came in when the lane went from 5 tracks to 3 (2026-11-22)
local IN_X, OUT_X = 366 - SLIM, 380 - SLIM -- the lane walls' faces
local Z_START = 213 -- the north face of zone 1's corner turret
local END_Z0, END_Z1 = 6380, 6394 -- the end wall, behind the finale (its last prop reaches z 6372)
local LANE_END = 6280 -- the zones' terrain ends here
local BOTTOM = -66 -- the walls' feet, under the sea and the lane-end water
local SEA_Y, SEA_X, SEA_END = -4, 548, 6640
local END_WATER = -49.5 -- zone 17's water level (LY - 1.5)
local DO_TERRAIN = true

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
	solid: boolean?
): Part
	local p = Instance.new("Part")
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
local function gable(parent: Instance, at: CFrame, length: number, half: number, height: number)
	for _, s in { -1, 1 } do
		local w = Instance.new("WedgePart")
		w.Name = "Roof"
		w.Size = Vector3.new(length, height, half)
		w.CFrame = at
			* CFrame.new(0, height / 2, s * half / 2)
			* (if s > 0 then CFrame.Angles(0, math.pi, 0) else CFrame.new())
		w.Color = ROOF
		w.Material = Enum.Material.ClayRoofTiles
		w.Anchored = true
		w.CanCollide = false
		w.CanQuery = false
		w.CanTouch = false
		w.Parent = parent
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

local root = scenery:FindFirstChild("LaneBorder")
if root then
	root:Destroy()
end
root = Instance.new("Folder")
root.Name = "LaneBorder"
root:SetAttribute(
	"Theme",
	"The lane's border wall and the sea outside it, tools/studio/lane_border.luau"
)
local fWalls = folder(root, "Walls")
local fKeeps = folder(root, "Keeps")

-- ---------------------------------------------------------------------------------- the old hills
-- props of the first map's hills that stood outside the new wall: archived once, then gone
do
	local archive = SS:FindFirstChild("MapArchive") or folder(SS, "MapArchive")
	local keepOld = archive:FindFirstChild("LaneHills_v1")
	local hills = scenery:FindFirstChild("Hills")
	if hills then
		if not keepOld then
			keepOld = folder(archive, "LaneHills_v1")
			keepOld:SetAttribute(
				"Note",
				"Hill props beside the lane, outside its border wall, before lane_border.luau (2026-11-22). Never delete."
			)
		end
		for _, u in hills:GetChildren() do
			local pos = if u:IsA("Model")
				then u:GetPivot().Position
				elseif u:IsA("BasePart") then u.Position
				else nil
			if pos and math.abs(pos.X) > IN_X - 4 and pos.Z > 186 then
				if keepOld:FindFirstChild(u.Name) and keepOld:GetAttribute("Done") then
					u:Destroy()
				else
					u.Parent = keepOld
				end
			end
		end
		keepOld:SetAttribute("Done", true)
	end
end

-- ---------------------------------------------------------------------------------- slim zones
-- The zones rebuilt on the slim cross-section (zones/side_lib.luau, design/plan/10-slim-map.md
-- phase 3) say where their border stands: attributes SlimZ0, SlimZ1, SlimWallIn, SlimWallOut,
-- SlimWallG on Map.Scenery.Zone_<id>. There the wall stands on the zone's edge, lower; where a slim
-- zone meets an old one, a cross wall steps out to the old line.
type Line = { z0: number, z1: number, inX: number, outX: number, g: number }
local slim: { Line } = {}
for _, f in scenery:GetChildren() do
	local z0, z1 = f:GetAttribute("SlimZ0"), f:GetAttribute("SlimZ1")
	if typeof(z0) == "number" and typeof(z1) == "number" then
		table.insert(slim, {
			z0 = z0,
			z1 = z1,
			inX = f:GetAttribute("SlimWallIn") :: number,
			outX = f:GetAttribute("SlimWallOut") :: number,
			g = f:GetAttribute("SlimWallG") :: number,
		})
	end
end
table.sort(slim, function(a, b)
	return a.z0 < b.z0
end)
local function lineAt(z: number): (number, number, number)
	for _, r in slim do
		if z >= r.z0 and z < r.z1 then
			return r.inX, r.outX, r.g
		end
	end
	return IN_X, OUT_X, G
end

-- ---------------------------------------------------------------------------------- terrain
local function fillBox(
	x0: number,
	x1: number,
	y0: number,
	y1: number,
	z0: number,
	z1: number,
	mat: Enum.Material
)
	x0, x1 = math.min(x0, x1), math.max(x0, x1)
	if x1 - x0 < 0.5 or y1 - y0 < 0.5 or z1 - z0 < 0.5 then
		return
	end
	-- in slices: one FillBlock over thousands of studs is slow and can stall
	local z = z0
	while z < z1 do
		local zz = math.min(z + 512, z1)
		T:FillBlock(
			CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z + zz) / 2),
			Vector3.new(x1 - x0, y1 - y0, zz - z),
			mat
		)
		z = zz
	end
end
if DO_TERRAIN then
	for _, s in { -1, 1 } do
		-- no land outside the wall: from x 372 (inside the wall's foot) out, the lane's whole length
		-- (from z 192: the town's ground ends at 189 under its front wall, whose foot reaches 203)
		fillBox(s * (IN_X + 6), s * 600, -70, 220, 192, SEA_END, Enum.Material.Air)
		fillBox(s * OUT_X, s * SEA_X, -48, -40, 192, SEA_END, Enum.Material.Sand)
		fillBox(s * OUT_X, s * SEA_X, -40, SEA_Y, 192, SEA_END, Enum.Material.Water)
	end
	-- past the lane's end: the end walls' bay in water at zone 17's level, then the sea (a slim
	-- zone 17 runs its own harbour on to the end wall either side, so the bay is then the lane's width)
	local slimEnd = lineAt(LANE_END + 1) ~= IN_X
	local bayAir = if slimEnd then 100 else IN_X + 6
	local bayW = if slimEnd then 100 else IN_X
	fillBox(-bayAir, bayAir, -70, 220, LANE_END, END_Z0, Enum.Material.Air)
	fillBox(-(IN_X + 6), IN_X + 6, -70, 220, END_Z0, SEA_END, Enum.Material.Air)
	fillBox(-bayW, bayW, -64, -56, LANE_END, END_Z0, Enum.Material.Sand)
	fillBox(-bayW, bayW, -56, END_WATER, LANE_END, END_Z0, Enum.Material.Water)
	fillBox(-OUT_X, OUT_X, -48, -40, END_Z1, SEA_END, Enum.Material.Sand)
	fillBox(-OUT_X, OUT_X, -40, SEA_Y, END_Z1, SEA_END, Enum.Material.Water)
	-- the slim zones: no land from inside their wall's foot out
	for _, r in slim do
		for _, s in { -1, 1 } do
			fillBox(s * (r.inX + 6), s * 600, -70, 220, r.z0, r.z1, Enum.Material.Air)
			fillBox(s * r.outX, s * SEA_X, -48, -40, r.z0, r.z1, Enum.Material.Sand)
			fillBox(s * r.outX, s * SEA_X, -40, SEA_Y, r.z0, r.z1, Enum.Material.Water)
		end
	end
end

-- ---------------------------------------------------------------------------------- the wall
-- zone 1's great-wall dress, as the lobby town's: stone foot to G + 20, a band, a plaster body
-- between posts, a tile gable (top G + 44)
local function wall(x0: number, x1: number, z0: number, z1: number, g: number?)
	local base = g or G -- a slim zone's wall stands lower (side_lib's WALL_G)
	local alongX = (x1 - x0) >= (z1 - z0)
	local len = if alongX then x1 - x0 else z1 - z0
	local th = if alongX then z1 - z0 else x1 - x0
	local at = CFrame.new((x0 + x1) / 2, base, (z0 + z1) / 2)
		* (if alongX then CFrame.new() else CFrame.Angles(0, math.pi / 2, 0))
	local m = Instance.new("Model")
	m.Name = "BorderWall"
	block(
		m,
		"Foot",
		Vector3.new(len, 20 + base - BOTTOM, th),
		at * CFrame.new(0, (20 - (base - BOTTOM)) / 2, 0),
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
	m.Parent = fWalls
	return m
end
local function keep(x: number, z: number, foot: number, yaw: number, name: string, g: number?)
	local m = Instance.new("Model")
	m.Name = name
	local top = (g or G) + 38
	block(
		m,
		"TowerFoot",
		Vector3.new(foot, top - BOTTOM, foot),
		CFrame.new(x, (top + BOTTOM) / 2, z),
		STONE,
		STONE_M,
		true
	)
	block(
		m,
		"TowerBand",
		Vector3.new(foot + 2, 2, foot + 2),
		CFrame.new(x, top - 1, z),
		STONE_DARK,
		Enum.Material.Slate,
		true
	)
	local k = KEEP:Clone() :: Model
	for _, d in k:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	k:ScaleTo(k:GetScale() * (if foot > 26 then 0.66 else 0.58))
	k:PivotTo(CFrame.new(x, top, z) * CFrame.Angles(0, math.rad(yaw), 0))
	k.Parent = m
	m.Parent = fKeeps
	return m
end

-- the sides, broken by a keep at every zone's gate; the walls run into each keep's foot
local KEEP_ZS = {}
for k = 1, 16 do
	table.insert(KEEP_ZS, 205 + 360 * k)
end
local events = {}
for _, kz in KEEP_ZS do
	table.insert(events, { z = kz, keep = true })
end
for _, r in slim do
	table.insert(events, { z = r.z0, keep = false })
	table.insert(events, { z = r.z1, keep = false })
end
table.sort(events, function(a, b)
	return a.z < b.z
end)
local start = Z_START
for _, r in slim do
	if Z_START >= r.z0 - 40 and Z_START < r.z1 then
		start = r.z0 -- zone 1 slim: the wall starts behind its gate tower
	end
end
for _, s in { -1, 1 } do
	local inward = if s > 0 then 90 else -90
	local function run(a: number, b: number)
		if b - a > 1 then
			local inX, outX, g = lineAt((a + b) / 2)
			wall(math.min(s * inX, s * outX), math.max(s * inX, s * outX), a, b, g)
		end
	end
	local z = start
	for _, e in events do
		if e.z > z then
			if e.keep then
				run(z, e.z - 13)
				local inX, outX, g = lineAt(e.z)
				keep(s * (inX + outX) / 2, e.z, 26, inward, "BorderKeep", g)
				z = e.z + 13
			else
				local i1, o1, g1 = lineAt(e.z - 1)
				local i2, o2, g2 = lineAt(e.z + 1)
				if (i1 ~= i2 or o1 ~= o2) and e.z < END_Z0 then -- none behind the end wall
					run(z, e.z)
					-- the cross wall where the line steps, as tall as the taller side
					local a, b = math.min(i1, i2), math.max(o1, o2)
					wall(
						math.min(s * a, s * b),
						math.max(s * a, s * b),
						e.z - 7,
						e.z + 7,
						math.max(g1, g2)
					)
					z = e.z
				end
			end
		end
	end
	run(z, END_Z0)
end
-- the end itself (its two corner towers, the two-storey end wall and the sealed gate) is the
-- finale's: finale.luau builds it

root.Parent = scenery

-- ---------------------------------------------------------------------------------- report
-- anything of the zones' that the walls or keeps go through
local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { root, T }
local hits = {}
local seen = {}
for _, f in { fWalls, fKeeps } do
	for _, m in f:GetChildren() do
		local cf, size = m:GetBoundingBox()
		-- the stonework only (the keep's mesh is above everything)
		size = Vector3.new(size.X - 1, math.min(size.Y, 80), size.Z - 1)
		for _, p in
			workspace:GetPartBoundsInBox(CFrame.new(cf.Position.X, G, cf.Position.Z), size, params)
		do
			local who = p:GetFullName()
			if not seen[who] and p.Transparency < 1 then
				seen[who] = true
				table.insert(
					hits,
					string.format(
						"%s @%.0f,%.0f,%.0f",
						who,
						p.Position.X,
						p.Position.Y,
						p.Position.Z
					)
				)
			end
		end
	end
end
return string.format(
	"lane border: %d walls, %d keeps; crossing %d:\n  %s",
	#fWalls:GetChildren(),
	#fKeeps:GetChildren(),
	#hits,
	table.concat(hits, "\n  ", 1, math.min(#hits, 40))
)
