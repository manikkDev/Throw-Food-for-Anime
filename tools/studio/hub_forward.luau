-- hub_forward.luau - Studio EDIT mode. The hub 40 studs closer to the lane (owner, 2026-11-23: "reduce the
-- space between the bases and the zone entrance, dont make it congested"; design/plan/11 phase 2).
--
--   * every hub piece moves 40 toward the lane (+Z): the bases (Map.Plots, Scenery.Plots, Lanes.Aprons),
--     HubV2's decks, statues, sakura, lanterns, shrine and dragon, everything in Map.Hub but its walls,
--     the hub barrier. NOT the throw stage, the ledge, the lane, zone 1, the lobby's walls (lobby_wall.luau
--     rebuilds those with the new back line) or the ledge's parapets.
--   * the hub's terrain (z -164..84, the lobby's width) is copied 40 forward ONCE (attribute
--     HubForwardTerrain on Workspace.Map): the cobbled plaza, the bases' paving, the lawn; the strip in
--     front of the stage keeps its cobbles.
-- Rerunnable: each moved piece remembers where this script left it (attribute HubZAt). A piece still
-- there is skipped; a piece a builder has put back in the old frame (plaza_districts.luau,
-- sanctuary.luau rebuild at fixed positions) is moved again. So after rerunning one of those builders,
-- run lobby_wall.luau (the districts' x moves) and then this.
-- The config's hub numbers (PlotBackZ, PlotFrontZ, PedestalCenterZ, SlotSignZ, CourtZ, the stations' Z)
-- moved 40 with it, so base_layout.luau lays the bases where this left them.
-- Run: python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file tools/studio/hub_forward.luau
local DZ = 40 -- a whole number of 4-stud voxels
local LIMIT_Z = 130 -- hub pieces end before this (the throw stage starts at 135)
local map = workspace.Map
local T = workspace.Terrain
local moved, skipped = 0, 0

local function zOf(inst: Instance): number
	if inst:IsA("Model") then
		return inst:GetPivot().Position.Z
	end
	return (inst :: BasePart).Position.Z
end
local function extent(inst: Instance): (number, number)
	local lo, hi = math.huge, -math.huge
	local list = if inst:IsA("BasePart") then { inst } else {}
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	for _, p in list do
		local b = p :: BasePart
		local h = b.Size.Magnitude / 2
		lo, hi = math.min(lo, b.Position.Z - h), math.max(hi, b.Position.Z + h)
	end
	return lo, hi
end
local function move(inst: Instance)
	if inst:IsA("Folder") then
		for _, c in inst:GetChildren() do
			move(c)
		end
		return
	end
	if not (inst:IsA("Model") or inst:IsA("BasePart")) then
		return
	end
	local at = inst:GetAttribute("HubZAt")
	if typeof(at) == "number" and math.abs(zOf(inst) - at) < 0.05 then
		skipped += 1
		return
	end
	if inst:IsA("Model") then
		inst:PivotTo(inst:GetPivot() + Vector3.new(0, 0, DZ))
	else
		local root = inst :: BasePart
		for _, d in root:GetDescendants() do
			if d:IsA("BasePart") then
				d.CFrame += Vector3.new(0, 0, DZ)
			end
		end
		root.CFrame += Vector3.new(0, 0, DZ)
	end
	inst:SetAttribute("HubZAt", zOf(inst))
	moved += 1
end

-- 1. the pieces
for _, plot in map.Plots:GetChildren() do
	move(plot)
end
move(map.Scenery.Plots)
move(map.Lanes.Aprons)
local KEEP_V2 = { ThrowStage = true, LedgeWall = true, LedgeFloor = true }
for _, c in map.HubV2:GetChildren() do
	if not KEEP_V2[c.Name] then
		local _, hi = extent(c)
		if hi < LIMIT_Z then
			move(c)
		end
	end
end
for _, c in map.Hub:GetChildren() do
	if c.Name ~= "Walls" then
		move(c)
	end
end
move(map.Barriers.Barrier_Hub)

-- 2. the terrain, once
local terrainNote = "already copied"
if not map:GetAttribute("HubForwardTerrain") then
	local region = Region3.new(Vector3.new(-264, -52, -164), Vector3.new(264, 28, 84))
	local mats, occ = T:ReadVoxels(region, 4)
	T:WriteVoxels(
		Region3.new(Vector3.new(-264, -52, -164 + DZ), Vector3.new(264, 28, 84 + DZ)),
		4,
		mats,
		occ
	)
	map:SetAttribute("HubForwardTerrain", DZ)
	terrainNote = "copied z -164..84 to -124..124"
end
map:SetAttribute("HubForward", DZ)
return string.format(
	"hub forward %d: moved %d, already there %d; terrain %s",
	DZ,
	moved,
	skipped,
	terrainNote
)
