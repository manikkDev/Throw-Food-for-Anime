-- icon_stage.luau - Studio EDIT mode. (Plan 13 phase B: food icons from the real models.)
-- Run through tools/ui/food_icons_v2.py, which fills IDS, ROW and WALL and takes the captures.
--
-- Stands the food templates named in IDS (the tool sends one at a time) in front of one flat wall,
-- high over the map. The same view
-- is captured twice, once on a BLACK wall and once on a WHITE one: the difference between the two
-- pictures is the food's exact outline (no colour key, so a pink, green or blue food is safe).
-- ROW = 0 removes the stage and puts the camera back.
local RS = game:GetService("ReplicatedStorage")

local IDS = {} --[[IDS]]
local ROW = 0 --[[ROW]]
local WALL = "black" --[[WALL]]

local ORIGIN = Vector3.new(-2400, 900, 0)
local SPACING = 8.4
local SHOW = 6.2 -- longest side on the stage

local old = workspace:FindFirstChild("FoodIconStage")
if old then
	old:Destroy()
end
if ROW == 0 then
	task.delay(1, function()
		workspace.CurrentCamera.CameraType = Enum.CameraType.Fixed
	end)
	return "stage removed"
end

local stage = Instance.new("Model")
stage.Name = "FoodIconStage"
local wall = Instance.new("Part")
wall.Name = "Wall"
wall.Anchored = true
wall.CastShadow = false
wall.Size = Vector3.new(400, 400, 1)
wall.CFrame = CFrame.new(ORIGIN + Vector3.new(0, 0, 14))
wall.Material = Enum.Material.Neon
wall.Color = if WALL == "white" then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
wall.Parent = stage

local placed = {}
for i, id in IDS do
	local template = RS.Assets.Foods:FindFirstChild("Food_" .. id)
	if template then
		local model = template:Clone()
		local box = model:GetExtentsSize()
		model:ScaleTo(model:GetScale() * SHOW / math.max(box.X, box.Y, box.Z))
		-- a quarter turn toward the camera's left, so a box or a tray shows two sides
		model:PivotTo(
			CFrame.new(ORIGIN + Vector3.new((i - (#IDS + 1) / 2) * SPACING, 0, 0)) * CFrame.Angles(0, math.rad(-25), 0)
		)
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.CastShadow = false
			end
			if part:IsA("MeshPart") then
				-- the capture is taken the instant the camera arrives: no level-of-detail mesh
				part.RenderFidelity = Enum.RenderFidelity.Precise
			end
		end
		model.Parent = stage
		table.insert(placed, id)
	end
end
stage.Parent = workspace
return "row " .. ROW .. " on " .. WALL .. ": " .. table.concat(placed, ",")
