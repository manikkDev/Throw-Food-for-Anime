-- lane_slim.luau - Studio EDIT mode. The lane from five tracks to three (owner, 2026-11-22: the map
-- felt too big to render; "remove 2 tracks ... and stick them", the zones' sides follow the lane in).
--
--   * the floor kits (Map.Lanes.Zone_*): the outer strips (x +-112) and their kerbs, paving, distance
--     bands and signs go; the margin paving now runs from the last kerb (x 92) to the lane's edge
--     (x 100); the thresholds are 200 wide
--   * the lane's sides come in by SLIM (60): every zone's scenery outside the lane (Map.Scenery.Zone_*)
--     and its terrain (copied voxel for voxel, 15 voxels in; behind zone 1's gate towers only the
--     terraces, z < 192), the ledge's parapets and posts beside the throw stage
--   * the throw stage, its spots (World.throwSpot: two bases share each outer track, each on its own
--     half), the ledge's wall and floor: 200 wide; the side barriers in to x +-322
-- The torii, the lane border and the finale are REBUILT narrower by their own scripts (zone_gates,
-- lane_border, finale), and the lobby wall's ends by lobby_wall.luau: run those after this.
-- The shift is done ONCE (attribute LaneSlim on Workspace.Map); a rerun only redoes the resizes.
-- Run: python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file <this file>
local RS = game:GetService("ReplicatedStorage")
-- a fresh copy each run: Studio caches a required module for the whole session, so an edited (and
-- synced) config would not be seen (lane_slim's first run read the old lane width this way)
local function fresh(m: ModuleScript): any
	return require(m:Clone())
end
local Config = fresh(RS.Shared.Config.GameConfig)
local World = fresh(RS.Shared.Core.World)
local W = Config.World
local COUNT = Config.Server.PlotCount
local T = workspace.Terrain
local map = workspace.Map

local SLIM = 60 -- 320 -> 200 wide: each side comes in 60 (a multiple of the 4-stud voxel)
local HALF = W.LaneWidth / 2 -- 100: the lane's new edge
local OLD_HALF = HALF + SLIM -- 160
local SRC_OUT = 372 -- the zones' terrain reaches x 368; the lane border's foot starts at 366
local Y0, Y1 = -68, 132 -- the terrain worked on (the canyons top out under 100)
local Z0, Z_TOWER, Z1 = 160, 192, 6400 -- the lane's start, the end of zone 1's gate towers, past the end
local log = {}

-- ------------------------------------------------------------------------------ helpers
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
local function boxOf(inst: Instance): (Vector3, Vector3)
	local lo, hi = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
	for _, p in partsOf(inst) do
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
	return lo, hi
end
local function shift(inst: Instance, d: Vector3)
	if inst:IsA("Model") then
		inst:PivotTo(inst:GetPivot() + d)
		return
	end
	for _, p in partsOf(inst) do
		p.CFrame += d
	end
	for _, m in inst:GetDescendants() do
		if m:IsA("Model") and not m.PrimaryPart then
			m.WorldPivot += d
		end
	end
end
-- a part's width along X set about x = 0 (or about `cx`), its depth and height kept
local function widthX(p: BasePart, w: number, cx: number?)
	p.Size = Vector3.new(w, p.Size.Y, p.Size.Z)
	p.CFrame = CFrame.new(cx or 0, p.Position.Y, p.Position.Z) * p.CFrame.Rotation
end

local DRY = false -- true: only report what would move
local done = DRY or map:GetAttribute("LaneSlim") == SLIM

-- ------------------------------------------------------------------------------ 1. terrain
-- each side's voxels from x 160..372 to 100..312, then the strip it leaves (312..372) cleared: the
-- lane border lays the sea there. Behind zone 1's gate towers (z < 192) only the terraces move (the
-- lobby's sea and walls are lobby_wall.luau's).
local moved = 0
if not done then
	local function copy(s: number, sx0: number, sx1: number, z0: number, z1: number)
		local function region(a: number, b: number): Region3
			local lo, hi = math.min(s * a, s * b), math.max(s * a, s * b)
			return Region3.new(Vector3.new(lo, Y0, z0), Vector3.new(hi, Y1, z1))
		end
		local src = region(sx0, sx1)
		local mats, occ = T:ReadVoxels(src, 4)
		local dst = region(sx0 - SLIM, sx1 - SLIM)
		T:WriteVoxels(dst, 4, mats, occ)
		moved += 1
	end
	for _, s in { -1, 1 } do
		copy(s, OLD_HALF, 240, Z0, Z_TOWER)
		local z = Z_TOWER
		while z < Z1 do
			local zz = math.min(z + 320, Z1)
			copy(s, OLD_HALF, SRC_OUT, z, zz)
			z = zz
		end
		-- what the copy left behind, outside the new border
		local lo, hi =
			math.min(s * (SRC_OUT - SLIM), s * SRC_OUT), math.max(s * (SRC_OUT - SLIM), s * SRC_OUT)
		local zc = Z_TOWER
		while zc < Z1 do
			local zz = math.min(zc + 512, Z1)
			T:FillBlock(
				CFrame.new((lo + hi) / 2, (Y0 + Y1) / 2, (zc + zz) / 2),
				Vector3.new(hi - lo, Y1 - Y0, zz - zc),
				Enum.Material.Air
			)
			zc = zz
		end
	end
end

-- ------------------------------------------------------------------------------ 2. scenery
-- each zone's pieces outside the lane move in; a model spanning both sides is opened up
local inside, shifted = {}, 0
local function walk(inst: Instance)
	for _, c in inst:GetChildren() do
		if c:IsA("Folder") then
			walk(c)
		elseif c:IsA("Model") or c:IsA("BasePart") then
			local lo, hi = boxOf(c)
			if c:IsA("Model") and lo.X < -40 and hi.X > 40 then
				walk(c)
			else
				local x = (lo.X + hi.X) / 2
				if math.abs(x) >= HALF then
					if not done then
						shift(c, Vector3.new(-math.sign(x) * SLIM, 0, 0))
						shifted += 1
					end
				else
					table.insert(
						inside,
						string.format("%s @%.0f,%.0f", c:GetFullName(), x, (lo.Z + hi.Z) / 2)
					)
				end
			end
		end
	end
end
for _, f in map.Scenery:GetChildren() do
	if f.Name:sub(1, 5) == "Zone_" then
		walk(f)
	end
end
-- inside the lane: the zones' particle boxes are made as wide as the lane; zone 1's ledge face keeps
-- the piers that fit (x +-30, +-90) and its outer banners hang between them
for _, f in map.Scenery:GetChildren() do
	local fx = f.Name:sub(1, 5) == "Zone_" and f:FindFirstChild("Fx")
	if fx then
		for _, p in fx:GetDescendants() do
			if p:IsA("BasePart") and p.Name:match("Source$") and p.Size.X > W.LaneWidth then
				widthX(p, W.LaneWidth - 8, p.Position.X)
			end
		end
	end
end
local entrance = map.Scenery:FindFirstChild("Zone_sakura_schoolyard")
entrance = entrance and entrance:FindFirstChild("Entrance")
if entrance and not done then
	for _, p in entrance:GetChildren() do
		if p:IsA("BasePart") then
			local x = p.Position.X
			if p.Name == "LedgePier" and math.abs(x) > HALF then
				p:Destroy()
			elseif
				(p.Name == "Banner" or p.Name == "BannerRod")
				and math.abs(math.abs(x) - 120) < 2
			then
				p.CFrame += Vector3.new(-math.sign(x) * 60, 0, 0)
			end
		end
	end
end
for _, c in map.Hub.Walls:GetChildren() do
	if (c.Name == "LedgeParapet" or c.Name == "LedgePost") and not done then
		local lo, hi = boxOf(c)
		shift(c, Vector3.new(-math.sign(lo.X + hi.X) * SLIM, 0, 0))
		shifted += 1
	end
end

-- ------------------------------------------------------------------------------ 3. the floor kits
local removed, odd = 0, {}
for _, zone in map.Lanes:GetChildren() do
	if zone.Name:sub(1, 5) == "Zone_" then
		for _, c in zone:GetChildren() do
			if c:IsA("BasePart") then
				local x, ax = c.Position.X, math.abs(c.Position.X)
				local n = c.Name
				if
					(n:match("^Strip_") and math.abs(ax - 112) < 2)
					or (n == "DistanceBand" and math.abs(ax - 112) < 2)
					or (n == "Kerb" and math.abs(ax - 132) < 2)
					or (n == "Paving" and math.abs(ax - 136) < 2)
					or (n == "DistanceSign" and ax > 120)
				then
					c:Destroy()
					removed += 1
				elseif n == "MarginPaving" then
					widthX(c, HALF - 92.5, math.sign(x) * (HALF + 92.5) / 2)
				elseif n == "Threshold" then
					widthX(c, W.LaneWidth)
				elseif ax + c.Size.X / 2 > HALF + 0.5 and c.Size.X < 200 then
					table.insert(odd, string.format("%s.%s @%.0f", zone.Name, n, x))
				end
			elseif c:IsA("Model") and c.Name == "DistanceSign" then
				local lo, hi = boxOf(c)
				if math.abs((lo.X + hi.X) / 2) > 120 then
					c:Destroy()
					removed += 1
				end
			end
		end
	end
end

-- ------------------------------------------------------------------------------ 4. the stage, ledge, barriers
local stage = map.HubV2.ThrowStage
for _, c in stage:GetChildren() do
	if c:IsA("BasePart") then
		if c.Name == "Deck" or c.Name == "Trim" then
			widthX(c, W.LaneWidth)
		elseif c.Name == "Rim" then
			widthX(c, W.LaneWidth + 4)
		end
	end
end
for i = 1, COUNT do
	local x = World.throwSpot(W, i, COUNT)
	for _, name in { "ThrowSpot" .. i, "SpotRing" .. i } do
		local p = stage:FindFirstChild(name) :: BasePart
		if p then
			p.CFrame = CFrame.new(x, p.Position.Y, p.Position.Z) * p.CFrame.Rotation
		end
	end
end
widthX(map.HubV2.LedgeWall, W.LaneWidth + 4)
widthX(map.HubV2.LedgeFloor, W.LaneWidth)
for _, b in map.Barriers:GetChildren() do
	if b:IsA("BasePart") and (b.Name == "Barrier_East" or b.Name == "Barrier_West") then
		b.CFrame = CFrame.new(math.sign(b.Position.X) * (HALF + 222), b.Position.Y, b.Position.Z)
	end
end

map:SetAttribute("LaneSlim", SLIM)
table.insert(
	log,
	string.format(
		"terrain chunks %d, scenery moved %d, kit parts removed %d",
		moved,
		shifted,
		removed
	)
)
table.insert(
	log,
	string.format("inside the lane (not moved) %d:\n  %s", #inside, table.concat(inside, "\n  "))
)
table.insert(
	log,
	string.format("kit pieces past the edge %d:\n  %s", #odd, table.concat(odd, "\n  "))
)
return table.concat(log, "\n")
