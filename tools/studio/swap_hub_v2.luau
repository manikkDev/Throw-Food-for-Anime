-- swap_hub_v2.luau - Studio EDIT mode, ONE-OFF (2026-11-21). Makes the reworked hub the live map.
--
--   Workspace.MapV2 (the reworked hub copy, 3,000 studs east)  ->  Workspace.Map, back at the origin
--   Workspace.Map   (the 6-base map)                           ->  ServerStorage.MapArchive.Map_v1_6lanes
--
-- The lanes are not rebuilt yet (the anime zones come 3 at a time): the old zone content is re-laid
-- for FIVE tracks. Everything up to the fifth lane's east edge moves half a pitch east, the sixth lane
-- and the wall before it are dropped, and the east outer wall and scenery move half a pitch west, so
-- the lane block is symmetric again (x -306..306) under bases at -216..216.
--
-- Config that goes with it (design/game.json): Server.PlotCount 5, World.PedestalRows 6.
-- Rollback: place version 506 (both maps intact) or git tag pre-single-lane + version 499.
-- Run: python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --dm Edit --file <this file>
local OFF = Vector3.new(3000, 0, 0)
local PITCH = 108
local HALF = PITCH / 2
local old = workspace:FindFirstChild("Map")
local v2 = workspace:FindFirstChild("MapV2")
assert(old and v2, "needs Workspace.Map (old) and Workspace.MapV2 (reworked hub)")
assert(old:FindFirstChild("Plots") and old.Plots:FindFirstChild("Plot6"), "Workspace.Map is not the 6-base map: already swapped?")

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
local function extent(inst: Instance): (Vector3, Vector3)
	local lo, hi = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
	for _, p in partsOf(inst) do
		local half = p.Size / 2
		local r = Vector3.new(half.Magnitude, half.Magnitude, half.Magnitude)
		-- parts are small against the 54-stud decisions made here: the bounding sphere is enough
		lo, hi = lo:Min(p.Position - r), hi:Max(p.Position + r)
	end
	return (lo + hi) / 2, hi - lo
end

-- 1. the reworked hub comes back to the origin
local map = v2
map.Name = "MapNext"
shift(map, -OFF)
map:SetAttribute("DevOnly", nil)
map:SetAttribute("Note", nil)
map:SetAttribute("Layout", "hub v2: 5 bases, pedestal rows 6, training on the forecourt (2026-11-21)")
local rework = map:FindFirstChild("Rework")
if rework then
	rework.Name = "HubV2"
end
local hubSpawn = map.Hub:FindFirstChild("HubSpawn")
local oldHubSpawn = old.Hub:FindFirstChild("HubSpawn")
if hubSpawn and oldHubSpawn then
	hubSpawn.Enabled = oldHubSpawn.Enabled
end

-- 2. pedestal slots: 6 rows of 7, numbered the way Core/World.pedestalOffset numbers them
local COLS, ROWS, SPACING, CENTER_Z = 7, 6, 8, -12
local named, missed = 0, 0
for i = 1, 5 do
	local plot = map.Plots["Plot" .. i]
	local cx = (i - 3) * PITCH
	local free = {}
	for _, p in plot.Pedestals:GetChildren() do
		if p:IsA("BasePart") then
			table.insert(free, p)
		end
	end
	for slot = 1, COLS * ROWS do
		local index = slot - 1
		local row, k = index // COLS, index % COLS
		local step = (k + 1) // 2
		local side = if k % 2 == 1 then -1 else 1
		local x = cx + step * side * SPACING
		local z = CENTER_Z + (ROWS - 1) / 2 * SPACING - row * SPACING
		local best, bestD, bestI = nil, 2, 0
		for n, p in free do
			local d = (Vector3.new(p.Position.X, 0, p.Position.Z) - Vector3.new(x, 0, z)).Magnitude
			if d < bestD then
				best, bestD, bestI = p, d, n
			end
		end
		if best then
			best.Name = "Pedestal" .. slot
			best:SetAttribute("Slot", slot)
			table.remove(free, bestI)
			named += 1
		else
			missed += 1
		end
	end
	for _, extra in free do
		extra:Destroy()
		missed += 1
	end
end

-- 3. the old zones, re-laid for five tracks
local kept, dropped, wide = 0, 0, 0
local function relay(node: Instance)
	for _, c in node:GetChildren() do
		if c:IsA("Folder") then
			relay(c)
		elseif c:IsA("Model") or c:IsA("BasePart") then
			local centre, size = extent(c)
			if centre.Z <= 100 then
				kept += 1 -- round the hub: stays where it is
			elseif size.X > 400 then
				wide += 1 -- spans the whole lane block: stays
				kept += 1
			elseif centre.X >= 298 then
				shift(c, Vector3.new(-HALF, 0, 0))
				kept += 1
			elseif centre.X >= 190 then
				c:Destroy()
				dropped += 1
			else
				shift(c, Vector3.new(HALF, 0, 0))
				kept += 1
			end
		end
	end
end
local HUB_SIDE = { Walls_Plots = true, Facade_Plots = true, Aprons = true, Plots = true, HubBackdrop = true }
for _, group in { "Lanes", "Scenery" } do
	for _, c in old[group]:GetChildren() do
		if not HUB_SIDE[c.Name] then
			local copy = c:Clone()
			relay(copy)
			copy.Parent = map[group]
		end
	end
end

-- 4. barriers: the outer ones as they were, ONE invisible wall across the open lane mouth
local barriers = Instance.new("Folder")
barriers.Name = "Barriers"
for _, b in old.Barriers:GetChildren() do
	if b.Name:sub(1, 9) ~= "LaneBlock" then
		b:Clone().Parent = barriers
	end
end
local block = old.Barriers:FindFirstChild("LaneBlock1")
if block then
	local wall = block:Clone()
	wall.Name = "LaneBlock"
	wall.Size = Vector3.new(720, block.Size.Y, block.Size.Z)
	wall.CFrame = CFrame.new(0, block.Position.Y, block.Position.Z)
	wall.Parent = barriers
end
barriers.Parent = map

-- 5. terrain: lawn where the sixth base stood, and the working copy's terrain cleared
local T = workspace.Terrain
for _, side in { -1, 1 } do
	T:FillBlock(CFrame.new(side * 302, -3, 18), Vector3.new(72, 4, 124), Enum.Material.Grass)
end
T:FillBlock(CFrame.new(3000, 24, -170), Vector3.new(1100, 150, 580), Enum.Material.Air)

-- 6. archive the old map, the new one takes its name
local ss = game:GetService("ServerStorage")
local archive = ss:FindFirstChild("MapArchive") or Instance.new("Folder")
archive.Name = "MapArchive"
archive.Parent = ss
old.Name = "Map_v1_6lanes"
old.Parent = archive
map.Name = "Map"
map.Parent = workspace

return string.format(
	"swapped: %d parts in the new map; pedestals named %d (missed %d); lane units kept %d, dropped %d (%d wide left in place); old map archived in ServerStorage.MapArchive",
	#partsOf(map),
	named,
	missed,
	kept,
	dropped,
	wide
)
