-- lane_two.luau - Studio EDIT mode. The lane from three tracks to two (owner, 2026-11-23: "remove
-- another track and stick them properly", the far map would not load; design/plan/11 phase 3).
--
--   * the floor kits (Map.Lanes.Zone_*): the middle track (strip, band, signs) and its kerbs and paving
--     go; the outer tracks' sets (strip, kerbs, paving, margin, band, signs) move 28 in, to x +-28; two
--     of the middle's pavings close the 16 studs between the tracks (x +-4). The thresholds are
--     lane_thresholds.luau's (rerun it): the lane is 144 wide (x +-72)
--   * the throw stage's deck, trim and rim, the ledge's wall and floor: the lane's width; the side
--     barriers to x +-(72 + 222)
-- The zones' sides are REBUILT (run_zone.py build 1..17: side_lib moves them 28 in), then zone_gates,
-- lane_border, finale, lobby_wall (the ledge's parapets), lane_thresholds and throw_spots run again.
-- The kit move is done ONCE (attribute LaneTwo on Workspace.Map); a rerun only redoes the resizes.
-- Run: python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file <this file>
local RS = game:GetService("ReplicatedStorage")
-- a fresh copy: Studio caches a required module for the whole session
local W = require(RS.Shared.Config.GameConfig:Clone()).World
local map = workspace.Map
local SHIFT = 28
local HALF = W.LaneWidth / 2 -- 72
assert(HALF == 72, "sync the two-track config first (LaneWidth 144)")
local MID = 36 -- the old middle track's set lies inside |x| < 36; the outer sets from 36 out

local function centreX(inst: Instance): number
	if inst:IsA("BasePart") then
		return inst.Position.X
	end
	local cf = (inst :: Model):GetBoundingBox()
	return cf.Position.X
end
local function move(inst: Instance, dx: number)
	if inst:IsA("Model") then
		inst:PivotTo(inst:GetPivot() + Vector3.new(dx, 0, 0))
	else
		local p = inst :: BasePart
		p.CFrame += Vector3.new(dx, 0, 0)
	end
end
-- a part's width along X set about x = 0, its depth and height kept
local function widthX(p: BasePart, w: number)
	p.Size = Vector3.new(w, p.Size.Y, p.Size.Z)
	p.CFrame = CFrame.new(0, p.Position.Y, p.Position.Z) * p.CFrame.Rotation
end

-- ------------------------------------------------------------------------------ 1. the floor kits
local done = map:GetAttribute("LaneTwo") == SHIFT
local moved, removed, odd = 0, 0, {}
if not done then
	for _, zone in map.Lanes:GetChildren() do
		if zone.Name:sub(1, 5) == "Zone_" then
			for _, c in zone:GetChildren() do
				local n = c.Name
				if n:sub(1, 5) == "Gate_" or n == "Threshold" then
					continue -- the torii (zone_gates.luau) and the threshold (lane_thresholds.luau)
				end
				if not (c:IsA("BasePart") or c:IsA("Model")) then
					continue
				end
				if c:IsA("BasePart") and c.Size.X > 60 then
					table.insert(odd, string.format("%s.%s w%.0f", zone.Name, n, c.Size.X))
					continue
				end
				local x = centreX(c)
				if math.abs(x) >= MID then
					move(c, -math.sign(x) * SHIFT)
					moved += 1
				elseif n == "Paving" and math.abs(math.abs(x) - 24) < 1 then
					move(c, -math.sign(x) * 20) -- 24 -> 4: between the two tracks' kerbs (x +-8)
					moved += 1
				else
					c:Destroy()
					removed += 1
				end
			end
		end
	end
	map:SetAttribute("LaneTwo", SHIFT)
end

-- ------------------------------------------------------------------------------ 2. the stage, ledge, barriers
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
widthX(map.HubV2.LedgeWall, W.LaneWidth + 4)
widthX(map.HubV2.LedgeFloor, W.LaneWidth)
for _, b in map.Barriers:GetChildren() do
	if b:IsA("BasePart") and (b.Name == "Barrier_East" or b.Name == "Barrier_West") then
		b.CFrame = CFrame.new(math.sign(b.Position.X) * (HALF + 222), b.Position.Y, b.Position.Z)
	end
end

-- ------------------------------------------------------------------------------ report
-- a kit piece past the new edge
for _, zone in map.Lanes:GetChildren() do
	if zone.Name:sub(1, 5) == "Zone_" then
		for _, c in zone:GetChildren() do
			if c:IsA("BasePart") and c.Name ~= "Threshold" then
				local reach = math.abs(c.Position.X) + c.Size.X / 2
				if reach > HALF + 0.6 and c.Size.X < 60 then
					table.insert(odd, string.format("%s.%s reaches %.1f", zone.Name, c.Name, reach))
				end
			end
		end
	end
end
return string.format(
	"lane two%s: kit pieces moved %d, removed %d; odd %d:\n  %s",
	if done then " (kits already done)" else "",
	moved,
	removed,
	#odd,
	table.concat(odd, "\n  ", 1, math.min(#odd, 40))
)
