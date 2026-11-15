-- install_store_assets.luau - run in Studio EDIT mode (python tools/studio/install_store_assets.py).
--
-- Free Creator Store models the owner asked for live in ServerStorage.StoreAssets as cleaned
-- sources (scripts, GUIs, sounds, constraints and effects stripped when they were taken in;
-- attributes AssetId and Creator say where each came from). They are in the place, not in Rojo,
-- like the hero avatars. This turns each source into a kit template the map emitter can place:
--   ReplicatedStorage.Assets.Kit.Prop_store_<Name>
--     * a world-aligned invisible Root part is the PrimaryPart, so GetBoundingBox is upright
--       whatever angle the creator left the meshes at (Unity imports arrive tilted)
--     * pivot at the base centre, front at -Z (source attribute Front = degrees to turn it),
--       source attribute Scale applied
--     * everything anchored, CanTouch off
-- Returns one line per template: name|parts|sizeX,sizeY,sizeZ (the wrapper writes the manifest).
-- Safe to re-run: a template is replaced.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sources = ServerStorage:FindFirstChild("StoreAssets")
if not sources then
	return "FAIL no ServerStorage.StoreAssets"
end
local kit = ReplicatedStorage.Assets.Kit

local function bounds(model: Model): (Vector3, Vector3)
	local lo = Vector3.new(math.huge, math.huge, math.huge)
	local hi = -lo
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Root" then
			local half = d.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local p = d.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
						lo = lo:Min(p)
						hi = hi:Max(p)
					end
				end
			end
		end
	end
	return lo, hi
end

local lines = {}
local list = sources:GetChildren()
table.sort(list, function(a, b)
	return a.Name < b.Name
end)
for _, source in list do
	if not source:IsA("Model") then
		continue
	end
	local model = source:Clone()
	local parts = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanTouch = false
			parts += 1
		end
	end
	-- scale first (about the model's own pivot), then turn the front to -Z
	local scale = source:GetAttribute("Scale")
	if typeof(scale) == "number" and scale ~= 1 then
		model:ScaleTo(scale)
	end
	local function turnBy(degrees: number)
		local lo0, hi0 = bounds(model)
		local c = (lo0 + hi0) / 2
		local turn = CFrame.new(c) * CFrame.Angles(0, math.rad(degrees), 0) * CFrame.new(-c)
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.CFrame = turn * d.CFrame
			end
		end
	end
	-- 1. square it up: creators leave models at any angle (the Unity imports sit at about 30
	--    degrees). Try every whole degree and keep the turn with the smallest footprint.
	local best, bestArea = 0, math.huge
	local corners = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local half = d.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						table.insert(corners, d.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)))
					end
				end
			end
		end
	end
	local step = if #corners > 800 then math.ceil(#corners / 800) else 1
	for degrees = 0, 89 do
		local co, si = math.cos(math.rad(degrees)), math.sin(math.rad(degrees))
		local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
		for i = 1, #corners, step do
			local p = corners[i]
			local x, z = p.X * co + p.Z * si, -p.X * si + p.Z * co
			x0, x1, z0, z1 = math.min(x0, x), math.max(x1, x), math.min(z0, z), math.max(z1, z)
		end
		local area = (x1 - x0) * (z1 - z0)
		if area < bestArea - 1e-3 then
			best, bestArea = degrees, area
		end
	end
	if best ~= 0 then
		turnBy(best)
	end
	-- 2. the wide side faces front: the thin horizontal axis becomes Z (flags, fences, gongs)
	local lo, hi = bounds(model)
	if (hi.Z - lo.Z) > (hi.X - lo.X) + 0.05 then
		turnBy(90)
	end
	-- 3. the owner of the source says which of the four sides is the front (degrees, by eye)
	local front = source:GetAttribute("Front")
	if typeof(front) == "number" and front % 360 ~= 0 then
		turnBy(front)
	end
	lo, hi = bounds(model)
	local centre = (lo + hi) / 2
	local size = hi - lo
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.CastShadow = false
	root.CFrame = CFrame.new(centre.X, lo.Y + 0.5, centre.Z)
	root.PivotOffset = CFrame.new(0, -0.5, 0)
	root.Parent = model
	model.PrimaryPart = root
	model:PivotTo(CFrame.new(0, 0, 0))
	model:SetAttribute("FrontIs", "-Z")
	model:SetAttribute("Store", true)
	local old = kit:FindFirstChild(model.Name)
	if old then
		old:Destroy()
	end
	model.Parent = kit
	table.insert(lines, string.format("%s|%d|%.2f,%.2f,%.2f", model.Name, parts, size.X, size.Y, size.Z))
end
return table.concat(lines, "\n")
