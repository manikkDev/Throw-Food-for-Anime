-- lane_ledge.luau - Studio EDIT mode, ONE-OFF (2026-11-21), after single_lane.luau. Owner's review of
-- the single lane: "the base and the lane are too close, it should be a funnel, ONE big tall shrine
-- gate instead of five, our base above and the lane below like the real game".
--
--   * the whole lane moves 64 studs away from the bases (config World.LaneStartZ 96 -> 160) and
--     24 studs DOWN (World.LaneY -24): players throw from a ledge into a sunken lane
--   * the straight wall across the mouth goes; two walls funnel in from the hub's side walls to the
--     lane's edges; the forecourt between is paved
--   * the throw stage moves to the ledge's edge (World.StageZ 148), a retaining wall under it
--   * every row of five torii becomes ONE gate, 470 wide and 247 tall: its pillars stand ON the walls
--     (a gate only as wide as the lane put a pillar in the outer players' view), 45 studs into its zone
-- Tall lane walls are left for the zone work. Rollback: place version 508 + git tag hub-v2.
-- Run: python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --dm Edit --file <this file>
local map = workspace.Map
assert(map:GetAttribute("Lane") ~= nil, "run single_lane.luau first")
assert(map:GetAttribute("Ledge") == nil, "the lane is already on a ledge")
local DZ, DY = 64, -24
local HALF = 160 -- half the lane's width
local START = 160 -- World.LaneStartZ: the ledge's edge

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
local function shift(inst: Instance, d: Vector3)
	for _, p in partsOf(inst) do
		p.CFrame += d
	end
end
local function extent(inst: Instance): (Vector3, Vector3, Vector3)
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
	return (lo + hi) / 2, lo, hi
end
local function units(folder: Instance): { Instance }
	local list = {}
	local function walk(node: Instance)
		for _, c in node:GetChildren() do
			if c:IsA("Folder") then
				walk(c)
			elseif c:IsA("Model") or c:IsA("BasePart") then
				table.insert(list, c)
			end
		end
	end
	walk(folder)
	return list
end

-- 1. the lane: back and down; one gate per zone
local moved, gates = 0, 0
local lastZ = START
local marginSample: BasePart? = nil
for _, group in { map.Lanes, map.Scenery } do
	for _, folder in group:GetChildren() do
		local n = folder.Name
		local isLane = (n:sub(1, 5) == "Zone_" or n:sub(1, 5) == "Town_" or n == "Finale" or n:sub(1, 6) == "Walls_" or n:sub(1, 7) == "Facade_")
			and n ~= "Walls_Plots"
			and n ~= "Facade_Plots"
		if isLane then
			local zoneGates = {}
			for _, u in units(folder) do
				shift(u, Vector3.new(0, DY, DZ))
				moved += 1
				if u.Name:sub(1, 5) == "Gate_" and u:IsA("Model") then
					table.insert(zoneGates, u)
				elseif u.Name == "MarginPaving" and u:IsA("BasePart") then
					marginSample = marginSample or u
				end
				local _, _, hi = extent(u)
				if group == map.Lanes then
					lastZ = math.max(lastZ, hi.Z)
				end
			end
			if #zoneGates > 0 then
				table.sort(zoneGates, function(a, b)
					return math.abs(extent(a).X) < math.abs(extent(b).X)
				end)
				for k = 2, #zoneGates do
					zoneGates[k]:Destroy()
				end
				local gate = zoneGates[1] :: Model
				local c, lo, hi = extent(gate)
				gate:ScaleTo(gate:GetScale() * 470 / (hi.X - lo.X))
				local c2, lo2 = extent(gate)
				shift(gate, Vector3.new(-c2.X, lo.Y - lo2.Y, (c.Z - 10 + 45) - c2.Z))
				gates += 1
			end
		end
	end
end
local barriers = map:FindFirstChild("Barriers")
if barriers then
	local endWall = barriers:FindFirstChild("Barrier_End")
	if endWall then
		shift(endWall, Vector3.new(0, 0, DZ))
	end
	local block = barriers:FindFirstChild("LaneBlock")
	if block and block:IsA("BasePart") then
		block.CFrame = CFrame.new(0, block.Position.Y, START + 1.5)
	end
end

-- 2. terrain: the forecourt up at hub level, the lane cut out below it
local T = workspace.Terrain
T:FillBlock(CFrame.new(0, -5, (92 + START) / 2), Vector3.new(760, 8, START - 92), Enum.Material.Grass)
T:FillBlock(CFrame.new(0, -4.9, (84 + START) / 2), Vector3.new(2 * HALF + 16, 8, START - 84), Enum.Material.Cobblestone)
do
	local z = START
	local stop = lastZ + 90
	while z < stop do
		local len = math.min(400, stop - z)
		T:FillBlock(CFrame.new(0, 14, z + len / 2), Vector3.new(2 * (HALF + 66), 116, len), Enum.Material.Air)
		z += len
	end
end

-- 3. the mouth: the wall across it goes, two walls funnel in
local body: BasePart? = nil
local cap: BasePart? = nil
for _, folder in { map.Lanes.Walls_Plots, map.Lanes.Facade_Plots } do
	for _, u in units(folder) do
		local c, lo, hi = extent(u)
		if u:IsA("BasePart") and u.Name:sub(1, 8) == "WallBody" then
			body = body or u
		elseif u:IsA("BasePart") and u.Name:sub(1, 7) == "WallCap" then
			cap = cap or u
		end
		if c.Z > 76 and hi.Z - lo.Z <= 14 then
			if u ~= body and u ~= cap then
				u:Destroy()
			end
		end
	end
end
local new = map.HubV2
local function wall(name: string, like: BasePart?, size: Vector3, cf: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = if like then like.Color else color
	p.Material = if like then like.Material else Enum.Material.Brick
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = new
	return p
end
for _, side in { -1, 1 } do
	local a = Vector3.new(side * 352, 0, 90)
	local b = Vector3.new(side * (HALF + 8), 0, START + 2)
	local length = (b - a).Magnitude + 6
	local mid = (a + b) / 2
	wall("FunnelWall", body, Vector3.new(12, 32, length), CFrame.lookAt(mid + Vector3.new(0, 12, 0), b + Vector3.new(0, 12, 0)), Color3.fromRGB(160, 110, 90))
	wall("FunnelCap", cap, Vector3.new(16, 4, length), CFrame.lookAt(mid + Vector3.new(0, 30, 0), b + Vector3.new(0, 30, 0)), Color3.fromRGB(240, 210, 235))
end
-- the mouth pieces used as a colour sample were part of the wall that goes
for _, sample in { body, cap } do
	if sample then
		local c, lo, hi = extent(sample)
		if c.Z > 76 and hi.Z - lo.Z <= 14 then
			sample:Destroy()
		end
	end
end

-- 4. the ledge: the throw stage at its edge, a retaining wall under it, the lane floor beginning below
local stage = new:FindFirstChild("ThrowStage")
if stage then
	-- up 0.9 so the deck stands clear of the forecourt's terrain, which is cut away under it
	shift(stage, Vector3.new(0, 0.9, 148 - 90))
	T:FillBlock(CFrame.new(0, 3, 149), Vector3.new(316, 10, 30), Enum.Material.Air)
end
-- the retaining wall stops at the deck's top: any higher and it is a lip in front of the thrower
wall("LedgeWall", body, Vector3.new(2 * HALF + 4, -DY + 5.3, 4), CFrame.new(0, (1.3 + DY - 4) / 2, START + 1), Color3.fromRGB(160, 110, 90))
local filler = wall("LedgeFloor", marginSample, Vector3.new(2 * HALF, 2, 10), CFrame.new(0, DY - 1, START + 5), Color3.fromRGB(230, 220, 200))
if marginSample then
	filler.CFrame = CFrame.new(0, marginSample.Position.Y, START + 5)
	filler.Size = Vector3.new(2 * HALF, marginSample.Size.Y, 10)
end

map:SetAttribute("Ledge", "lane 24 below the hub from z 160; funnel forecourt; one gate per zone (2026-11-21)")
return string.format("ledge: %d lane units moved, %d big gates, lane now z %d..%d at y %d", moved, gates, START, lastZ, DY)
