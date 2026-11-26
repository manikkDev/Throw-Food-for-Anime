-- install_foods.luau - Studio EDIT mode, rerunnable. (Plan 13 phase B.) Run it through
-- install_foods.py, which fills SPEC from design/foods.json.
--
-- Every `Food_<id>` standing in Workspace.FoodLab (not in its Rejected folder) that has a line in
-- SPEC becomes the game's template `ReplicatedStorage.Assets.Foods.Food_<id>`: turned as SPEC says,
-- scaled so its longest side is the food's size in the hand, pivot at its centre, anchored, no
-- collisions. The raw lab model is kept in ServerStorage.StoreAssets.Foods_v2 (never delete), and
-- a template that was there before goes to ServerStorage.MapArchive.Foods_v1 once.
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local SPEC = {} --[[SPEC]]
local ONLY = {} --[[ONLY]]

local lab = workspace:FindFirstChild("FoodLab")
if not lab then
	return "FAIL no Workspace.FoodLab: run food_lab.luau first"
end
local foods = RS.Assets.Foods
local function folder(parent: Instance, name: string): Instance
	local found = parent:FindFirstChild(name)
	if not found then
		found = Instance.new("Folder")
		found.Name = name
		found.Parent = parent
	end
	return found
end
local raw = folder(folder(SS, "StoreAssets"), "Foods_v2")
local archive = folder(folder(SS, "MapArchive"), "Foods_v1")

local out = {}
for id, spec in SPEC do
	local source = lab:FindFirstChild("Food_" .. id)
	if not source or (next(ONLY) ~= nil and not ONLY[id]) then
		continue
	end
	local kept = raw:FindFirstChild("Food_" .. id)
	if kept then
		kept:Destroy()
	end
	local copy = source:Clone()
	local tag = copy:FindFirstChild("Tag")
	if tag then
		tag:Destroy()
	end
	copy.Parent = raw

	local model = copy:Clone()
	local mesh = model.PrimaryPart :: MeshPart
	local turn = spec.turn
	mesh.CFrame = CFrame.new(mesh.Position)
		* CFrame.Angles(math.rad(turn[1]), math.rad(turn[2]), math.rad(turn[3]))
	-- the model's own axes are the world's: the pivot carries no turn. (The pivot of a model with
	-- a PrimaryPart IS that part's pivot, so the turn is taken out of the part's PivotOffset;
	-- setting WorldPivot does nothing here and PivotTo would stand the mesh back as it came.)
	mesh.PivotOffset = mesh.CFrame.Rotation:Inverse()
	local box = model:GetExtentsSize()
	model:ScaleTo(model:GetScale() * spec.size / math.max(box.X, box.Y, box.Z))
	model:PivotTo(CFrame.new())
	model:SetAttribute("FrontIs", "-Z")
	model:SetAttribute("Throw", spec.throw)
	model.Name = "Food_" .. id
	local old = foods:FindFirstChild(model.Name)
	if old then
		if archive:FindFirstChild(model.Name) or old:GetAttribute("Plan13") then
			old:Destroy()
		else
			old.Parent = archive
		end
	end
	model:SetAttribute("Plan13", true)
	model.Parent = foods
	local size = model:GetExtentsSize()
	table.insert(out, string.format("%s|%.2f,%.2f,%.2f|%s", model.Name, size.X, size.Y, size.Z, spec.throw))
end
table.sort(out)
return table.concat(out, "\n")
