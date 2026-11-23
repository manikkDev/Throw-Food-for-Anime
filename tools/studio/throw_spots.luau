-- throw_spots.luau - Studio EDIT mode, rerunnable. The throw spots on the stage ARE the pads (owner,
-- 2026-11-23: "remove the throwing pad thing from the bases"): a player walks to their own coloured
-- circle on Map.HubV2.ThrowStage and is held there (World.throwPad = World.throwSpot).
--   * the five pads (Map.Plots.Plot<i>.ThrowPad) are archived once to ServerStorage.MapArchive.ThrowPads_v1
--     and taken off the bases
--   * each spot (ThrowSpot<i> + SpotRing<i>) is set at World.throwSpot from the synced config
--   * over each spot an unrotated invisible anchor SpotHint<i> carries the "YOUR SPOT" sign (the spots
--     are cylinders lying on their side: a BillboardGui's offset would point sideways on them). Every
--     sign is saved hidden; ThrowController shows only the player's own.
-- Run: python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file tools/studio/throw_spots.luau
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
-- a fresh copy: Studio caches a required module for the whole session
local Config = require(RS.Shared.Config.GameConfig:Clone())
local World = require(RS.Shared.Core.World:Clone())
local W = Config.World
local COUNT = Config.Server.PlotCount
local map = workspace.Map
local stage = map.HubV2.ThrowStage
local log = {}

-- 1. the pads: archived once, then off the bases
local archive = SS:FindFirstChild("MapArchive") or Instance.new("Folder")
archive.Name = "MapArchive"
archive.Parent = SS
local kept = archive:FindFirstChild("ThrowPads_v1")
if not kept then
	kept = Instance.new("Folder")
	kept.Name = "ThrowPads_v1"
	kept:SetAttribute(
		"Note",
		"The five throw pads in front of the bases, removed 2026-11-23 (the stage spots are the pads now). Never delete."
	)
	kept.Parent = archive
end
for i = 1, COUNT do
	local plot = map.Plots:FindFirstChild("Plot" .. i)
	local pad = plot and plot:FindFirstChild("ThrowPad")
	if pad then
		if not kept:FindFirstChild("Plot" .. i .. "_ThrowPad") then
			local copy = pad:Clone()
			copy.Name = "Plot" .. i .. "_ThrowPad"
			copy.Parent = kept
		end
		pad:Destroy()
		table.insert(log, "pad " .. i .. " removed")
	end
end

-- 2. the spots and their signs
local template = kept:FindFirstChild("Plot1_ThrowPad")
template = template and template:FindFirstChild("Hint")
assert(template, "no archived pad sign to copy the style from")
for i = 1, COUNT do
	local x, z = World.throwSpot(W, i, COUNT)
	local top = 0
	for _, name in { "ThrowSpot" .. i, "SpotRing" .. i } do
		local p = stage:FindFirstChild(name) :: BasePart
		if p then
			p.CFrame = CFrame.new(x, p.Position.Y, z) * p.CFrame.Rotation
			top = math.max(top, p.Position.Y)
		end
	end
	local old = stage:FindFirstChild("SpotHint" .. i)
	if old then
		old:Destroy()
	end
	local anchor = Instance.new("Part")
	anchor.Name = "SpotHint" .. i
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(x, top + 0.5, z)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Parent = stage
	local hint = template:Clone()
	hint.Name = "Hint"
	hint.Enabled = false -- the player's own client shows it
	hint.Adornee = nil
	hint.Size = UDim2.fromScale(8, 2)
	hint.StudsOffset = Vector3.zero
	hint.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
	hint.MaxDistance = 260 -- seen from the base (~90 studs back)
	hint.AlwaysOnTop = false
	local label = hint:FindFirstChildWhichIsA("TextLabel", true)
	if label then
		label.Text = "YOUR SPOT"
	end
	hint.Parent = anchor
	table.insert(log, string.format("spot %d at x %.0f z %.0f", i, x, z))
end
return table.concat(log, "\n")
