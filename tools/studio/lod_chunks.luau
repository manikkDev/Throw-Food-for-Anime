-- lod_chunks.luau - Studio EDIT mode, RERUNNABLE (and rerun it after any zone, border or finale rebuild).
-- The whole map drawn for every player without sending all of it (owner, 2026-11-23: "make sure that
-- the whole map should be loaded for players ... without causing lag"; design/plan/11 phase 4).
--
-- Streaming sends each client only what is near it (Workspace.StreamingTargetRadius). Roblox's SLIM
-- (Model.LevelOfDetail = SLIM) makes a merged, lighter copy of a static Model in the cloud that is DRAWN
-- when the real model is not on the client, so the lane stays visible to the sealed gate. SLIM works on
-- Models only, best ones about 64 studs across. So, in the lane's static content (Map.Scenery,
-- Map.Lanes; nothing in them is looked up by name at runtime):
--   * every Model about 100 studs across or less is one SLIM unit; so is a merged mesh (TrueSize), a
--     zone's torii (Gate_*), and a chunk made here (LodChunk)
--   * a bigger Model (a revetment, a floor kit, a long wall) is opened up: its pieces are units again,
--     its loose parts grouped as below
--   * loose parts (paving, kerbs, the zones' particle boxes, floor tiles) are grouped by a 64-stud grid
--     into Models named LodChunk (with their container, so the folders stay as they are)
--   * a model with a Humanoid is never SLIM
-- And the lag: no light casts shadows; nothing here takes touches; small parts cast no shadow.
-- The streaming settings and the Workspace leftovers: see the end.
-- Run: python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file tools/studio/lod_chunks.luau
local SS = game:GetService("ServerStorage")
local map = workspace.Map
local CELL = 64 -- the chunk grid (Roblox: keep a SLIM model about 64 studs across)
local UNIT = 100 -- a model up to this across stays whole
local SMALL = 8 -- parts smaller than this cast no shadow
local SLIM = Enum.ModelLevelOfDetail.SLIM

local stats = {
	empty = 0,
	units = 0,
	opened = 0,
	chunks = 0,
	chunked = 0,
	humanoid = 0,
	lights = 0,
	small = 0,
}

local function across(m: Model): number
	local _, size = m:GetBoundingBox()
	return math.max(size.X, size.Z)
end
local function whole(m: Model): boolean
	return m.Name == "LodChunk"
		or m.Name:sub(1, 5) == "Gate_"
		or m:GetAttribute("TrueSize") ~= nil
		or across(m) <= UNIT
end
local function unit(m: Model)
	if m:FindFirstChildWhichIsA("Humanoid", true) then
		m.LevelOfDetail = Enum.ModelLevelOfDetail.Disabled
		stats.humanoid += 1
		return
	end
	m.LevelOfDetail = SLIM
	stats.units += 1
end
-- the container's loose parts into LodChunk models by the grid
local function chunk(container: Instance)
	local cells: { [string]: { BasePart } } = {}
	for _, c in container:GetChildren() do
		if c:IsA("BasePart") then
			local key = math.floor(c.Position.X / CELL) .. "," .. math.floor(c.Position.Z / CELL)
			cells[key] = cells[key] or {}
			table.insert(cells[key], c)
		end
	end
	for _, list in cells do
		local m = Instance.new("Model")
		m.Name = "LodChunk"
		for _, p in list do
			p.Parent = m
		end
		m.Parent = container -- walk() makes it a unit
		stats.chunks += 1
		stats.chunked += #list
	end
end
local function walk(container: Instance)
	chunk(container)
	for _, c in container:GetChildren() do
		if c:IsA("Folder") then
			walk(c)
		elseif c:IsA("Model") then
			if c.Name == "LodChunk" and not c:FindFirstChildWhichIsA("BasePart", true) then
				c:Destroy() -- its parts were rebuilt elsewhere (lane_thresholds.luau, a zone)
				stats.empty += 1
			elseif c.Name == "LodChunk" then
				unit(c)
			elseif whole(c) then
				unit(c)
			else
				c.LevelOfDetail = Enum.ModelLevelOfDetail.Disabled -- a container: its pieces carry SLIM
				stats.opened += 1
				walk(c)
			end
		end
	end
end
walk(map.Scenery)
walk(map.Lanes)

-- ------------------------------------------------------------------------------ lag
for _, d in map:GetDescendants() do
	if d:IsA("Light") and d.Shadows then
		d.Shadows = false
		stats.lights += 1
	end
end
for _, f in { map.Scenery, map.Lanes } do
	for _, d in f:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanTouch = false
			if d.CastShadow and d.Size.Magnitude < SMALL then
				d.CastShadow = false
				stats.small += 1
			end
		end
	end
end

-- ------------------------------------------------------------------------------ streaming
-- Roblox's recommended values: the client holds 1024 studs round the player (SLIM draws the rest), a
-- phone short of memory drops far parts early instead of running out
workspace.StreamingTargetRadius = 1024
workspace.StreamingMinRadius = 64
workspace.StreamOutBehavior = Enum.StreamOutBehavior.Opportunistic

-- ------------------------------------------------------------------------------ leftovers
-- three things in Workspace that are not the game (an imported scene, a loose torso, an empty
-- folder): kept, out of the place's world
local archive = SS:FindFirstChild("MapArchive")
local left = archive and archive:FindFirstChild("WorkspaceLeftovers")
if archive and not left then
	left = Instance.new("Folder")
	left.Name = "WorkspaceLeftovers"
	left:SetAttribute(
		"Note",
		"Loose things found in Workspace, moved here 2026-11-23 (lod_chunks.luau). Never delete."
	)
	left.Parent = archive
end
local moved = {}
for _, name in { "Sketchfab_Scene", "UpperTorso", "Characters_R15_New" } do
	local c = workspace:FindFirstChild(name)
	if c and left then
		c.Parent = left
		table.insert(moved, name)
	end
end

return string.format(
	"SLIM units %d (chunks made %d holding %d parts, empty ones removed %d), containers opened %d, humanoid models %d\n"
		.. "lights unshadowed %d, small parts unshadowed %d\nstreaming %d/%d %s; leftovers moved: %s",
	stats.units,
	stats.chunks,
	stats.chunked,
	stats.empty,
	stats.opened,
	stats.humanoid,
	stats.lights,
	stats.small,
	workspace.StreamingMinRadius,
	workspace.StreamingTargetRadius,
	tostring(workspace.StreamOutBehavior),
	if #moved > 0 then table.concat(moved, ", ") else "none"
)
