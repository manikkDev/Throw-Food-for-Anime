-- ground_lab.luau - Studio EDIT mode, rerunnable. (Plan 13 phase D.)
-- Gathers freshly generated training-ground pieces into the judging row `Workspace.GroundLab`.
--
-- Every piece's prompt starts "GROUND_<key>:" and the generated model is named after its prompt.
-- This takes each such model lying in Workspace, squares it (the generator inserts models turned
-- to face the camera; squared, a generated mesh fronts to -Z), keeps the mesh alone with the
-- model's pivot at the middle of its base and the attribute TrueSize, and stands it in the row
-- with its key over it. A newer try of a key replaces the older one (the older goes to
-- ServerStorage.GroundLabRejected). build_grounds.luau reads the pieces from this row.
-- Returns one line per piece: its size.
-- Run: python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --dm Edit --file <this file>
local SS = game:GetService("ServerStorage")
local ORIGIN = Vector3.new(-2400, 600, 200)
local GAP = 16

local lab = workspace:FindFirstChild("GroundLab")
if not lab then
	lab = Instance.new("Model")
	lab.Name = "GroundLab"
	lab.Parent = workspace
end
local rejected = SS:FindFirstChild("GroundLabRejected")
if not rejected then
	rejected = Instance.new("Folder")
	rejected.Name = "GroundLabRejected"
	rejected.Parent = SS
end

local function square(model: Model): MeshPart?
	local mesh = model:FindFirstChildWhichIsA("MeshPart", true)
	if not mesh then
		return nil
	end
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
	model.PrimaryPart = nil
	model.WorldPivot = CFrame.new(mesh.Position.X, mesh.Position.Y - mesh.Size.Y / 2, mesh.Position.Z)
	model:SetAttribute("TrueSize", mesh.Size)
	return mesh
end

for _, child in workspace:GetChildren() do
	local key = child:IsA("Model") and string.match(child.Name, "^GROUND_([%w_]+)")
	if key and square(child) then
		local old = lab:FindFirstChild(key)
		if old then
			old.Name = key .. "_try" .. tostring(#rejected:GetChildren() + 1)
			old.Parent = rejected
		end
		child.Name = key
		child.Parent = lab
	end
end

local pieces = {}
for _, child in lab:GetChildren() do
	if child:IsA("Model") then
		table.insert(pieces, child)
	end
end
table.sort(pieces, function(a, b)
	return a.Name < b.Name
end)
for _, name in { "Floor", "Wall" } do
	local old = lab:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end
local length = math.max(1, #pieces) * GAP + 8
local function slab(name: string, size: Vector3, at: Vector3)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = ORIGIN + at
	part.Color = Color3.fromRGB(150, 156, 170)
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = lab
end
slab("Floor", Vector3.new(length, 1, 24), Vector3.new(length / 2 - GAP / 2, -0.5, 0))
slab("Wall", Vector3.new(length, 22, 1), Vector3.new(length / 2 - GAP / 2, 10.5, -12))

local out = {}
for i, model in pieces do
	local size = model:GetAttribute("TrueSize") :: Vector3
	-- fronts to -Z as generated; the row is looked at from +Z, so turn its front to the camera
	model:PivotTo(CFrame.new(ORIGIN + Vector3.new((i - 1) * GAP, 0, 0)) * CFrame.Angles(0, math.pi, 0))
	local tag = model:FindFirstChild("Tag")
	if tag then
		tag:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Tag"
	gui.Size = UDim2.fromOffset(200, 26)
	gui.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 2, 0)
	gui.Adornee = model:FindFirstChildWhichIsA("MeshPart")
	gui.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = model.Name
	label.Parent = gui
	gui.Parent = model
	table.insert(out, string.format("%d %s  %.1f x %.1f x %.1f  at x %.0f", i, model.Name, size.X, size.Y, size.Z, ORIGIN.X + (i - 1) * GAP))
end
return table.concat(out, "\n")
