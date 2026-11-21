-- single_lane.luau - Studio EDIT mode, ONE-OFF (2026-11-21). Turns the five walled lanes of hub v2
-- into ONE open lane, 320 wide, with five tracks side by side and a throw stage in the middle of its
-- mouth (owner: "one lane, narrowed a little, everyone throws from the middle").
--
--   before: lanes at x = 0, 108, 216 either side, a wall and a town terrace between each pair
--   after : tracks at x = 0, 56, 112 either side (config World.LanePitch), walls only at x = 160
--
-- The zone content is still the OLD six zones (the anime zones replace them 3 at a time): each lane's
-- own floor kit is slid in beside its neighbour, the walls, facades, props and towns BETWEEN lanes
-- are removed, the two outer walls and everything on them move in to the new edge.
-- Goes with config World.LaneWidth 320, LanePitch 56, StageZ 90 (design/game.json).
-- Rollback: place version 508 + git tag hub-v2.
-- Run: python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --dm Edit --file <this file>
local map = workspace.Map
assert(map:GetAttribute("Lane") == nil, "already a single lane")
local PITCH, TRACK, HALF = 108, 56, 160
local OUTER = 244 -- the old outer walls' inner face
local IN = OUTER - HALF -- how far the outer walls move in

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
local function sign(x: number): number
	return if x < 0 then -1 else 1
end
-- a unit of one lane slides in beside its neighbour: the lane it belongs to moves from PITCH to TRACK
local function slide(unit: Instance, x: number)
	local k = math.clamp(math.round(x / PITCH), -2, 2)
	shift(unit, Vector3.new(-k * (PITCH - TRACK), 0, 0))
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

local kept, removed = 0, 0
local zoneRanges = {} -- id -> { z0, z1 } from the floor strips
for _, folder in map.Lanes:GetChildren() do
	local name = folder.Name
	if name:sub(1, 5) == "Zone_" then
		local id = name:sub(6)
		local z0, z1 = 1e9, -1e9
		local paving: BasePart? = nil
		for _, u in units(folder) do
			local c, lo, hi = extent(u)
			if u.Name:sub(1, 5) == "Line_" then
				u:Destroy()
				removed += 1
			else
				if u.Name:sub(1, 5) == "Gate_" and u:IsA("Model") then
					-- five gates side by side: a gate is 61 wide, a track 56
					local bottom = lo.Y
					u:ScaleTo(0.9)
					local _, lo2 = extent(u)
					shift(u, Vector3.new(0, bottom - lo2.Y, 0))
				elseif u.Name:sub(1, 5) == "Strip" then
					z0, z1 = math.min(z0, lo.Z), math.max(z1, hi.Z)
				elseif u.Name:sub(1, 6) == "Paving" and u:IsA("BasePart") then
					paving = u
				end
				slide(u, c.X)
				kept += 1
			end
		end
		zoneRanges[id] = { z0, z1 }
		-- the margin between the outer tracks and the walls
		if paving and z1 > z0 then
			for _, side in { -1, 1 } do
				local m = paving:Clone()
				m.Name = "MarginPaving"
				m.Size = Vector3.new(HALF - 2.5 * TRACK, paving.Size.Y, z1 - z0)
				m.CFrame = CFrame.new(side * (HALF + 2.5 * TRACK) / 2, paving.Position.Y, (z0 + z1) / 2)
				m.Parent = folder
			end
		end
	elseif name:sub(1, 6) == "Walls_" and name ~= "Walls_Plots" or name:sub(1, 7) == "Facade_" and name ~= "Facade_Plots" then
		for _, u in units(folder) do
			local c = extent(u)
			if math.abs(c.X) < OUTER - 12 or c.Z <= 101 then
				u:Destroy()
				removed += 1
			else
				shift(u, Vector3.new(-sign(c.X) * IN, 0, 0))
				kept += 1
			end
		end
	end
end
for _, folder in map.Scenery:GetChildren() do
	local name = folder.Name
	if name:sub(1, 5) == "Zone_" or name:sub(1, 5) == "Town_" then
		for _, u in units(folder) do
			local c = extent(u)
			if math.abs(c.X) < OUTER - 12 then
				u:Destroy()
				removed += 1
			else
				shift(u, Vector3.new(-sign(c.X) * IN, 0, 0))
				kept += 1
			end
		end
	elseif name == "Finale" then
		for _, u in units(folder) do
			local c = extent(u)
			if c.Z > 101 then
				if math.abs(c.X) < OUTER - 12 then
					slide(u, c.X)
				else
					shift(u, Vector3.new(-sign(c.X) * IN, 0, 0))
				end
				kept += 1
			end
		end
	end
end

-- the lane mouth: a wall either side of a 320-wide opening, and the throw stage in the opening
for _, u in units(map.Lanes.Aprons) do
	if u.Name:sub(1, 5) == "Apron" then
		u:Destroy()
	end
end
for _, u in units(map.Lanes.Walls_Plots) do
	local c = extent(u)
	if c.Z > 60 and math.abs(math.abs(c.X) - 275) < 12 then
		for _, d in { 54, 84 } do
			local twin = u:Clone()
			shift(twin, Vector3.new(-sign(c.X) * d, 0, 0))
			twin.Parent = u.Parent
		end
	end
end
local hv = map:FindFirstChild("HubV2")
for _, c in hv:GetChildren() do
	local n = c.Name
	if n == "MedianPlanter" or n == "MedianSoil" then
		c:Destroy()
	elseif n:sub(1, 15) == "Prop_store_Bush" or n:sub(1, 23) == "Prop_shared_KoiFlagPole" then
		local e = extent(c)
		if math.abs(e.Z - 90) < 4 then
			c:Destroy()
		end
	end
end

local stage = Instance.new("Model")
stage.Name = "ThrowStage"
local function block(name: string, size: Vector3, at: Vector3, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = CFrame.new(at)
	p.Anchored = true
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = stage
	return p
end
local STAGE_Z, TOP = 90, 0.5
block("Deck", Vector3.new(2 * HALF - 12, 4, 24), Vector3.new(0, TOP - 2, STAGE_Z + 1), Color3.fromRGB(118, 80, 58), Enum.Material.WoodPlanks)
block("Rim", Vector3.new(2 * HALF - 8, 3.6, 28), Vector3.new(0, TOP - 2.2, STAGE_Z + 1), Color3.fromRGB(62, 40, 34), Enum.Material.Wood)
for _, z in { STAGE_Z - 10.6, STAGE_Z + 12.6 } do
	block("Trim", Vector3.new(2 * HALF - 12, 0.2, 0.8), Vector3.new(0, TOP + 0.05, z), Color3.fromRGB(255, 204, 72), Enum.Material.SmoothPlastic).CanCollide = false
end
local ACCENTS = {
	Color3.fromRGB(226, 75, 74),
	Color3.fromRGB(63, 140, 255),
	Color3.fromRGB(79, 200, 120),
	Color3.fromRGB(170, 100, 255),
	Color3.fromRGB(255, 150, 60),
}
for i = 1, 5 do
	local x = (i - 3) * TRACK
	local ring = block("SpotRing" .. i, Vector3.new(0.2, 15, 15), Vector3.new(x, TOP + 0.06, STAGE_Z), Color3.fromRGB(255, 250, 235), Enum.Material.SmoothPlastic)
	ring.Shape = Enum.PartType.Cylinder
	ring.CFrame = CFrame.new(x, TOP + 0.06, STAGE_Z) * CFrame.Angles(0, 0, math.rad(90))
	ring.CanCollide = false
	local spot = block("ThrowSpot" .. i, Vector3.new(0.24, 12.5, 12.5), Vector3.new(x, TOP + 0.1, STAGE_Z), ACCENTS[i], Enum.Material.Neon)
	spot.Shape = Enum.PartType.Cylinder
	spot.CFrame = CFrame.new(x, TOP + 0.1, STAGE_Z) * CFrame.Angles(0, 0, math.rad(90))
	spot.CanCollide = false
	spot.Transparency = 0.15
end
stage.Parent = hv

-- lawn over the ground the outer lanes and walls stood on
local T = workspace.Terrain
local last = 0
for _, r in zoneRanges do
	last = math.max(last, r[2])
end
for _, side in { -1, 1 } do
	T:FillBlock(CFrame.new(side * 294, -4, (100 + last) / 2), Vector3.new(144, 4, last - 100), Enum.Material.Grass)
end
map:SetAttribute("Lane", "single: 320 wide, 5 tracks 56 apart, throw stage at z 90 (2026-11-21)")
return string.format("single lane: %d units kept, %d removed, %d parts in the map now, lane ends at z %d", kept, removed, #partsOf(map), last)
