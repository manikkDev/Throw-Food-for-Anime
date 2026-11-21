-- lane_deeper.luau - Studio EDIT mode, ONE-OFF (2026-11-22), after lane_ledge.luau. Owner's review of
-- zone 1: "elevate our base lobby even higher or put the lane ground lower, the walls feel kind of
-- high". The lane drops another 24 studs: 48 below the hub (config World.LaneY -24 -> -48). A deeper
-- lane lets the zone walls stand lower over the lobby and still be canyon walls from inside.
--   * every lane unit (floor kits, gates, old zone walls and their towns, the finale) moves down 24
--   * the trench in the terrain is cut 24 deeper
--   * the ledge's retaining wall grows down to the new floor, its foot strip moves with the lane
-- Zone 1's own dressing is rebuilt by tools/studio/zones/zone_01_naruto.luau afterwards.
-- Run: python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --dm Edit --file <this file>
local map = workspace.Map
assert(map:GetAttribute("Ledge") ~= nil, "run lane_ledge.luau first")
assert(map:GetAttribute("Deeper") == nil, "the lane is already 48 below the hub")
local DY = -24
local HALF, START = 160, 160

local moved, lastZ = 0, START
for _, group in { map.Lanes, map.Scenery } do
	for _, folder in group:GetChildren() do
		local n = folder.Name
		local isLane = (n:sub(1, 5) == "Zone_" or n:sub(1, 5) == "Town_" or n == "Finale" or n:sub(1, 6) == "Walls_" or n:sub(1, 7) == "Facade_")
			and n ~= "Walls_Plots"
			and n ~= "Facade_Plots"
		if isLane then
			for _, d in folder:GetDescendants() do
				if d:IsA("BasePart") then
					d.CFrame += Vector3.new(0, DY, 0)
					moved += 1
					if group == map.Lanes then
						lastZ = math.max(lastZ, d.Position.Z + d.Size.Z / 2)
					end
				end
			end
		end
	end
end

-- the trench: it was cut to y -44, the floor kit now reaches -52
local T = workspace.Terrain
local z = START
local stop = lastZ + 90
while z < stop do
	local len = math.min(400, stop - z)
	T:FillBlock(CFrame.new(0, -54, z + len / 2), Vector3.new(2 * (HALF + 66), 20, len), Enum.Material.Air)
	z += len
end

local hub = map.HubV2
local wall = hub:FindFirstChild("LedgeWall")
if wall and wall:IsA("BasePart") then
	local top = wall.Position.Y + wall.Size.Y / 2
	local bottom = wall.Position.Y - wall.Size.Y / 2 + DY
	wall.Size = Vector3.new(wall.Size.X, top - bottom, wall.Size.Z)
	wall.CFrame = CFrame.new(wall.Position.X, (top + bottom) / 2, wall.Position.Z)
end
local foot = hub:FindFirstChild("LedgeFloor")
if foot and foot:IsA("BasePart") then
	foot.CFrame += Vector3.new(0, DY, 0)
end

map:SetAttribute("Deeper", "lane 48 below the hub (2026-11-22)")
return string.format("lane lowered: %d parts moved %d, trench cut to z %d", moved, DY, stop)
