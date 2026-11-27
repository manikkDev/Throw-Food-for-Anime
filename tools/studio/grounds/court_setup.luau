-- court_setup.luau - Studio EDIT mode, rerunnable. (Plan 13 phase D.)
-- Gets the two training courts of every base ready for the training GROUNDS.
--
-- Until phase D a court held a round station mat (`Station<i>`, with the Train prompt and a title
-- board) and a gear anchor (`Gear` on the left with the Upgrade prompt, `SpiritGear` on the right).
-- A ground is a whole set piece, placed by the server (PlotService:_showGround), so a court now
-- holds only:
--   Ground<court>     an invisible anchor at the court's centre, on its floor: the set piece's pivot
--   TrainSpot<court>  holds the Train prompt (Action "train", Station = court); the server moves it
--                     onto the set piece's stand point
--   GearSign<court>   holds the Upgrade prompt (Action "gear"); the server moves it onto the set
--                     piece's notice board
-- (court 1 = CourtL, court 2 = CourtR). The old mats, anchors and their dressing go to
-- ServerStorage.MapArchive.TrainingCourts_v1 (never delete).
-- Run: python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --dm Edit --file <this file>
local SS = game:GetService("ServerStorage")
local plots = workspace.Map.Plots

local archiveRoot = SS:FindFirstChild("MapArchive") or Instance.new("Folder")
archiveRoot.Name = "MapArchive"
archiveRoot.Parent = SS
local archive = archiveRoot:FindFirstChild("TrainingCourts_v1")
if not archive then
	archive = Instance.new("Folder")
	archive.Name = "TrainingCourts_v1"
	archive.Parent = archiveRoot
end

local function holder(plot: Instance, name: string, at: Vector3): Part
	local part = plot:FindFirstChild(name)
	if not part then
		part = Instance.new("Part")
		part.Name = name
		part.Parent = plot
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.CFrame = CFrame.new(at)
	return part
end

local function prompt(parent: Instance, name: string, action: string, text: string, key: Enum.KeyCode, plot: number, from: ProximityPrompt?): ProximityPrompt
	local p = parent:FindFirstChild(name)
	if not p then
		p = if from then from else Instance.new("ProximityPrompt")
		p.Name = name
		p.Parent = parent
	end
	p.ActionText = text
	p.KeyboardKeyCode = key
	p.HoldDuration = 0
	p.MaxActivationDistance = 11
	p.RequiresLineOfSight = false
	p:SetAttribute("Action", action)
	p:SetAttribute("Plot", plot)
	return p
end

local out = {}
for _, plot in plots:GetChildren() do
	local index = tonumber(string.match(plot.Name, "^Plot(%d+)$"))
	if not index then
		continue
	end
	local keep = archive:FindFirstChild(plot.Name)
	if not keep then
		keep = Instance.new("Folder")
		keep.Name = plot.Name
		keep.Parent = archive
	end
	local moved = 0
	for court, courtName in { "CourtL", "CourtR" } do
		local slab = plot:FindFirstChild(courtName)
		if not slab then
			table.insert(out, plot.Name .. ": no " .. courtName)
			continue
		end
		local top = slab.Position.Y + slab.Size.Y / 2
		local centre = Vector3.new(slab.Position.X, top, slab.Position.Z)
		local ground = holder(plot, "Ground" .. court, centre)
		ground.Size = Vector3.new(2, 0.2, 2)
		ground:SetAttribute("Court", court)
		-- the Train prompt: taken over from the old mat, so it keeps whatever it carried
		local mat = plot:FindFirstChild("Station" .. court)
		local old = mat and mat:FindFirstChild("Prompt_train")
		local spot = holder(plot, "TrainSpot" .. court, centre + Vector3.new(0, 3, 0))
		local train = prompt(spot, "Prompt_train", "train", "Train", Enum.KeyCode.E, index, old)
		train:SetAttribute("Station", court)
		-- the Upgrade prompt: the left court's comes from the old gear anchor, the right gets a copy
		local gear = plot:FindFirstChild("Gear")
		local oldGear = gear and gear:FindFirstChild("Prompt_gear")
		local sign = holder(plot, "GearSign" .. court, centre + Vector3.new(0, 3, 8))
		prompt(sign, "Prompt_gear", "gear", "Upgrade gear", Enum.KeyCode.F, index, oldGear)
	end
	-- the old anchors and the round mats' dressing
	for _, name in { "Gear", "SpiritGear", "Station1", "Station2" } do
		local part = plot:FindFirstChild(name)
		if part then
			part.Parent = keep
			moved += 1
		end
	end
	local dressing = plot:FindFirstChild("Dressing")
	if dressing then
		for _, piece in dressing:GetChildren() do
			if string.sub(piece.Name, 1, 7) == "Station" then
				piece.Parent = keep
				moved += 1
			end
		end
	end
	table.insert(out, string.format("%s: courts ready, %d old pieces archived", plot.Name, moved))
end
return table.concat(out, "\n")
