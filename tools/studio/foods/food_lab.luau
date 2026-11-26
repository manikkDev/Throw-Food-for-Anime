-- food_lab.luau - Studio EDIT mode, rerunnable. (Plan 13 phase B.)
-- Gathers freshly generated food models into the judging row `Workspace.FoodLab`.
--
-- A generated model is named after its prompt, and every food prompt starts "FOOD_<id>:". This
-- takes each such model lying in Workspace, squares it (the generator inserts models turned to
-- face the camera), scales it so its longest side is SHOW studs, and stands it in the row in
-- ladder order with its name over it. A newer model of the same food replaces the older one
-- (the older goes to ServerStorage.FoodLabRejected).
-- Returns one line per food: its size and triangle hint, for the judge.
-- Run: python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --dm Edit --file <this file>
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config.GameConfig:Clone())

local ORIGIN = Vector3.new(-2400, 600, 0)
local SHOW = 5 -- longest side while judging
local GAP = 8

local order = {}
for i, food in Config.Foods do
	order[food.Id] = i
end

local lab = workspace:FindFirstChild("FoodLab")
if not lab then
	lab = Instance.new("Model")
	lab.Name = "FoodLab"
	lab.Parent = workspace
end
-- older tries are kept out of sight (ServerStorage.FoodLabRejected) until the batch is installed
local SS = game:GetService("ServerStorage")
local rejected = SS:FindFirstChild("FoodLabRejected")
if not rejected then
	rejected = Instance.new("Folder")
	rejected.Name = "FoodLabRejected"
	rejected.Parent = SS
end
local inLab = lab:FindFirstChild("Rejected")
if inLab then
	for _, child in inLab:GetChildren() do
		child.Parent = rejected
	end
	inLab:Destroy()
end

local function square(model: Model): MeshPart?
	local mesh = model:FindFirstChildWhichIsA("MeshPart", true)
	if not mesh then
		return nil
	end
	-- flatten: the mesh alone under the model, upright on the world axes, pivot at its centre
	mesh.Parent = model
	for _, child in model:GetChildren() do
		if child ~= mesh then
			child:Destroy()
		end
	end
	mesh.Anchored = true
	mesh.CanCollide = false
	mesh.CanQuery = false
	mesh.CanTouch = false
	mesh.CastShadow = true
	mesh.CFrame = CFrame.new(mesh.Position)
	model.PrimaryPart = mesh
	model.WorldPivot = CFrame.new(mesh.Position)
	return mesh
end

local taken = {}
for _, child in workspace:GetChildren() do
	local id = child:IsA("Model") and string.match(child.Name, "^FOOD_([%w_]+)")
	if id and order[id] then
		local mesh = square(child)
		if mesh then
			local old = lab:FindFirstChild("Food_" .. id)
			if old then
				old.Name = old.Name .. "_try" .. tostring(#rejected:GetChildren() + 1)
				old.Parent = rejected
			end
			child.Name = "Food_" .. id
			child.Parent = lab
			table.insert(taken, id)
		end
	end
end

-- the stage: a dark floor and wall, rebuilt to the row's length
local foods = {}
for _, child in lab:GetChildren() do
	local id = child:IsA("Model") and string.match(child.Name, "^Food_([%w_]+)")
	if id then
		table.insert(foods, { id = id, model = child })
	end
end
table.sort(foods, function(a, b)
	return (order[a.id] or 999) < (order[b.id] or 999)
end)
for _, name in { "Floor", "Wall" } do
	local old = lab:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end
local length = math.max(1, #foods) * GAP + 8
local function slab(name: string, size: Vector3, at: Vector3)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = ORIGIN + at
	part.Color = Color3.fromRGB(38, 40, 52)
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = lab
end
slab("Floor", Vector3.new(length, 1, 16), Vector3.new(length / 2 - 8, -0.5, 0))
slab("Wall", Vector3.new(length, 16, 1), Vector3.new(length / 2 - 8, 7.5, 8))

local out = {}
for i, row in foods do
	local model = row.model :: Model
	local mesh = model.PrimaryPart :: MeshPart
	local longest = math.max(mesh.Size.X, mesh.Size.Y, mesh.Size.Z)
	model:ScaleTo(model:GetScale() * SHOW / longest)
	model:PivotTo(CFrame.new(ORIGIN + Vector3.new((i - 1) * GAP, mesh.Size.Y / 2 + 0.05, 0)))
	local tag = model:FindFirstChild("Tag")
	if not tag then
		local gui = Instance.new("BillboardGui")
		gui.Name = "Tag"
		gui.Size = UDim2.fromOffset(220, 30)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
		gui.Adornee = mesh
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Text = row.id
		label.Parent = gui
		gui.Parent = model
	end
	table.insert(
		out,
		string.format(
			"%d %s size %.1f x %.1f x %.1f textured=%s x=%.0f",
			i,
			row.id,
			mesh.Size.X,
			mesh.Size.Y,
			mesh.Size.Z,
			tostring(mesh.TextureID ~= ""),
			model:GetPivot().Position.X
		)
	)
end
return "took " .. #taken .. " new (" .. table.concat(taken, ", ") .. ")\n" .. table.concat(out, "\n")
