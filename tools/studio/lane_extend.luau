-- lane_extend.luau - Studio EDIT mode, ONE-OFF (2026-11-23). The zone plan has 17 zones
-- (design/zones/anime_zones.json) and the lane had floor for six. This lays the floor for zones 7 to
-- 17: eleven copies of zone 6's floor kit and gate, each 360 studs further on, moves the finale and
-- the end barrier to the new end and cuts the trench for the lane.
--
-- ONLY THE MAP GROWS. The game's zone data (config.Zones: power gates, heroes, incomes) still ends at
-- zone 6, so a throw cannot land beyond z 2320 until that data is written: the new zones are built
-- and waiting. The gates say "COMING SOON" until then.
-- Run: python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --dm Edit --file <this file>
local map = workspace.Map
assert(map:GetAttribute("Deeper") ~= nil, "run lane_deeper.luau first")
assert(map:GetAttribute("Extended") == nil, "the lane already runs to zone 17")
local lanes, scenery = map.Lanes, map.Scenery
local SRC_ID = "realm_of_legends"
local NEW = {
	{ "hunter_exam", "HUNTER EXAM" },
	{ "isekai_crossroads", "ISEKAI CROSSROADS" },
	{ "wall_maria", "WALL MARIA" },
	{ "public_safety", "PUBLIC SAFETY HQ" },
	{ "bizarre_streets", "BIZARRE STREETS" },
	{ "shadow_council", "SHADOW COUNCIL" },
	{ "city_z", "CITY Z" },
	{ "soul_society", "SOUL SOCIETY" },
	{ "gate_of_shadows", "GATE OF SHADOWS" },
	{ "shibuya", "SHIBUYA" },
	{ "planet_of_gods", "PLANET OF THE GODS" },
}
local STEP = 360
local GROW = STEP * #NEW

local function shift(inst: Instance, dz: number)
	if inst:IsA("BasePart") then
		inst.CFrame += Vector3.new(0, 0, dz)
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame += Vector3.new(0, 0, dz)
		end
	end
end

-- the trench first: air where the lane will run (the hills stood here)
local T = workspace.Terrain
local z = 2320
while z < 2320 + GROW + 100 do
	T:FillBlock(CFrame.new(0, 58, z + 200), Vector3.new(328, 244, 400), Enum.Material.Air)
	z += 400
end

-- the finale and the lane's end move to the new end
shift(scenery.Finale, GROW)
local barriers = map:FindFirstChild("Barriers")
if barriers then
	local endWall = barriers:FindFirstChild("Barrier_End")
	if endWall then
		shift(endWall, GROW)
	end
	for _, n in { "Barrier_East", "Barrier_West" } do
		local b = barriers:FindFirstChild(n)
		if b and b:IsA("BasePart") then
			b.Size += Vector3.new(0, 0, GROW)
			b.CFrame += Vector3.new(0, 0, GROW / 2)
		end
	end
end

-- eleven more floors
local source = lanes["Zone_" .. SRC_ID]
local made = 0
for k, zone in NEW do
	local id, title = zone[1], zone[2]
	local f = source:Clone()
	f.Name = "Zone_" .. id
	shift(f, STEP * k)
	for _, c in f:GetDescendants() do
		c.Name = c.Name:gsub(SRC_ID, id)
		if c:IsA("TextLabel") then
			local n = tonumber(c.Text)
			if n then
				c.Text = tostring(n + STEP * k) -- a distance sign
			elseif c.Text:find("\n") then
				c.Text = title .. "\nCOMING SOON" -- the gate's banner
			end
		end
	end
	f.Parent = lanes
	made += 1
end
map:SetAttribute("Extended", "lane floor for zones 7..17 (2026-11-23); zone DATA still ends at zone 6")
return string.format("lane extended: %d zone floors laid, lane now ends at z %d", made, 2320 + GROW)
