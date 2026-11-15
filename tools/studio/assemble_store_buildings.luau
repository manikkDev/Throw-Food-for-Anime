-- assemble_store_buildings.luau - run in Studio EDIT mode, with the modular pack inserted.
--
-- The free "Low Poly Japanese Buildings" packs (Creator Store 3226471202 colour 1, 3226472387
-- colour 2, by BL00MIE) are a CATALOGUE of single-mesh pieces (bases, roofs, tiers), not finished
-- buildings. This stacks pieces into complete buildings and stores each as a source model in
-- ServerStorage.StoreAssets (then: python tools/studio/install_store_assets.py).
--
-- Expects the pack under Workspace.TFA_StoreTrial.<PACK> (see PACKS). Safe to re-run: a source of
-- the same name is replaced. `sink` = how far a piece is lowered into the one under it.

local ServerStorage = game:GetService("ServerStorage")

local PACKS = {
	A = { folder = "T_Buildings1", id = 3226471202 }, -- cream walls, red and green roofs
	B = { folder = "T_Buildings2", id = 3226472387 }, -- tan walls, dark roofs
}

-- name -> { pack, { {piece suffix, sink}, ... } }
-- (two-storey and stone-plinth houses were tried and dropped: the pieces do not line up)
local RECIPES = {
	Castle = { "A", { { "Base_Large_01", 0 }, { "Castle_Base_Large_Windows_01", 0.3 }, { "Castle_Roof_Large_01", 0.3 }, { "Castle_Base_Medium_Windows_01", 4.6 }, { "Castle_Roof_Medium_01", 0.3 }, { "Castle_Base_Small_Windows_01", 3.4 }, { "Castle_Roof_Small_01", 0.3 }, { "Castle_Base_Top_01", 2.8 }, { "Castle_Roof_Top_01", 0.3 } } },
	CastleKeepSmall = { "B", { { "Base_Large_02", 0 }, { "Castle_Base_Medium_Windows_01", 0.3 }, { "Castle_Roof_Medium_01", 0.3 }, { "Castle_Base_Small_Windows_01", 3.4 }, { "Castle_Roof_Small_01", 0.3 }, { "Castle_Base_Top_01", 2.8 }, { "Castle_Roof_Top_01", 0.3 } } },
	PagodaTemple = { "A", { { "Platform_Medium_01", 0 }, { "Temple_Base_Large_01", 0.2 }, { "Temple_Roof_Large_01", 0.3 }, { "Temple_Base_Medium_01", 2.6 }, { "Temple_Roof_Medium_01", 0.3 }, { "Temple_Base_Small_01", 2.6 }, { "Temple_Roof_Small_01", 0.3 }, { "Temple_Roof_Tip_01", 2.0 } } },
	PagodaDark = { "B", { { "Temple_Base_Large_01", 0 }, { "Temple_Roof_Large_01", 0.3 }, { "Temple_Base_Medium_01", 2.6 }, { "Temple_Roof_Medium_01", 0.3 }, { "Temple_Base_Small_01", 2.6 }, { "Temple_Roof_Small_01", 0.3 }, { "Temple_Roof_Tip_01", 2.0 } } },
	ShrineA = { "A", { { "Platform_Small_01", 0 }, { "Temple_Base_Medium_01", 0.2 }, { "Temple_Roof_Small_02", 0.3 } } },
	ShrineB = { "A", { { "Block_Stairs_01", 0 }, { "Temple_Base_Small_01", 0.3 }, { "Temple_Roof_Small_01", 0.3 } } },
	HouseA = { "A", { { "House_Base_01", 0 }, { "House_Roof_Wood_01", 0.3 } } },
	HouseB = { "A", { { "House_Base_02", 0 }, { "House_Roof_Thatch_01", 0.3 } } },
	HouseC = { "A", { { "House_Base_Long_01", 0 }, { "House_Roof_Long_Wood_01", 0.3 } } },
	HouseD = { "A", { { "House_Base_Long_03", 0 }, { "House_Roof_Long_Thatch_01", 0.3 } } },
	HouseG = { "B", { { "House_Base_01", 0 }, { "House_Roof_Thatch_01", 0.3 } } },
	HouseH = { "B", { { "House_Base_Long_01", 0 }, { "House_Roof_Long_Thatch_01", 0.3 } } },
	HallA = { "A", { { "Room_Long_01", 0 } } },
	HallB = { "A", { { "Room_Long_02", 0 } } },
	HallC = { "B", { { "Room_Long_03", 0 } } },
	StageA = { "A", { { "Platform_Large_Legs_01", 0 }, { "Platform_Large_01", 0.2 } } },
	TowerDark = { "B", { { "Tower_01", 0 } } },
	TowerSlimDark = { "B", { { "Tower_02", 0 } } },
}

local stage = workspace:FindFirstChild("TFA_StoreTrial")
if not stage then
	return "FAIL no Workspace.TFA_StoreTrial"
end
local archive = ServerStorage:FindFirstChild("StoreAssets")
if not archive then
	return "FAIL no ServerStorage.StoreAssets"
end

local function corners(part: BasePart): { Vector3 }
	local out, half = {}, part.Size / 2
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				table.insert(out, part.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)))
			end
		end
	end
	return out
end

local function box(part: BasePart): (Vector3, Vector3)
	local lo = Vector3.new(math.huge, math.huge, math.huge)
	local hi = -lo
	for _, p in corners(part) do
		lo, hi = lo:Min(p), hi:Max(p)
	end
	return lo, hi
end

local function turn(part: BasePart, degrees: number)
	local lo, hi = box(part)
	local c = (lo + hi) / 2
	part.CFrame = CFrame.new(c) * CFrame.Angles(0, math.rad(degrees), 0) * CFrame.new(-c) * part.CFrame
end

-- square a piece to the axes, long side along X
local function square(part: BasePart)
	local pts = corners(part)
	local best, bestArea = 0, math.huge
	for degrees = 0, 89 do
		local co, si = math.cos(math.rad(degrees)), math.sin(math.rad(degrees))
		local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
		for _, p in pts do
			local x, z = p.X * co + p.Z * si, -p.X * si + p.Z * co
			x0, x1, z0, z1 = math.min(x0, x), math.max(x1, x), math.min(z0, z), math.max(z1, z)
		end
		local area = (x1 - x0) * (z1 - z0)
		if area < bestArea - 1e-3 then
			best, bestArea = degrees, area
		end
	end
	if best ~= 0 then
		turn(part, best)
	end
	local lo, hi = box(part)
	if (hi.Z - lo.Z) > (hi.X - lo.X) + 0.05 then
		turn(part, 90)
	end
end

local function findPiece(pack: Instance, suffix: string): BasePart?
	for _, d in pack:GetDescendants() do
		if d:IsA("BasePart") and string.sub(d.Name, -#suffix) == suffix then
			return d
		end
	end
	return nil
end

local lines = {}
local names = {}
for name in RECIPES do
	table.insert(names, name)
end
table.sort(names)
for _, name in names do
	local recipe = RECIPES[name]
	local packInfo = PACKS[recipe[1]]
	local pack = stage:FindFirstChild(packInfo.folder)
	if not pack then
		table.insert(lines, "SKIP " .. name .. ": pack " .. packInfo.folder .. " not inserted")
		continue
	end
	local model = Instance.new("Model")
	model.Name = "Prop_store_" .. name
	local top, missing = 0, nil
	for _, step in recipe[2] do
		local src = findPiece(pack, step[1])
		if not src then
			missing = step[1]
			break
		end
		local piece = src:Clone()
		piece.Anchored = true
		piece.Parent = model
		square(piece)
		local lo, hi = box(piece)
		local centre = (lo + hi) / 2
		piece.CFrame = piece.CFrame + Vector3.new(-centre.X, top - step[2] - lo.Y, -centre.Z)
		local _, hi2 = box(piece)
		top = hi2.Y
	end
	if missing then
		model:Destroy()
		table.insert(lines, "FAIL " .. name .. ": no piece " .. missing)
		continue
	end
	model:SetAttribute("AssetId", packInfo.id)
	model:SetAttribute("Creator", "BL00MIE")
	model:SetAttribute("Parts", #model:GetChildren())
	model:SetAttribute("Assembled", true)
	local old = archive:FindFirstChild(model.Name)
	if old then
		old:Destroy()
	end
	model.Parent = archive
	table.insert(lines, string.format("ok %s pieces=%d height=%.1f", model.Name, #model:GetChildren(), top))
end
return table.concat(lines, "\n")
