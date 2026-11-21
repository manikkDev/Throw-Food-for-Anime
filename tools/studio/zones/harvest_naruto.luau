-- harvest_naruto.luau - Studio EDIT mode, ONE-OFF (2026-11-22). Zone 1 "Hidden Leaf Village".
-- Takes the buildings picked from free Creator Store packs and makes them cheap enough to place
-- many times: every script, sound and GUI was already stripped in Workspace.Quarantine (four of the
-- packs carried the hidden Runtime/ScreenBuilder backdoor), here the part-built buildings are baked
-- (mesh-scaled bricks and cylinders become real parts) and merged per colour and material with
-- GeometryService, so a 478-part house becomes a few dozen instances.
--
-- Sources (Creator Store asset ids, free):
--   13900207152  "Konoha" village pack  -> KonohaTower (House3), KonohaHall (House2), KonohaHouse
--                                          (House1), KonohaAcademy, KonohaBlueHall
--   17756262963  "Konoha"               -> HokageResidence
--   136593468800525 "Hidden Leaf Village Gate Naruto RP" -> LeafGate
-- Before: insert them under Workspace.Quarantine, strip everything that is not a part, mesh or
-- decal, and clone the picks into Workspace.Quarantine.Picks under the names above.
-- After: Workspace.Quarantine.Opt holds the optimised templates in a row for a look; the zone
-- builder (zone_01_naruto.luau) reads them from ServerStorage.StoreAssets.Zone01_Naruto.
-- It yields, so the result goes to the workspace attribute "HarvestLog".
-- Run: python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --dm Edit --file <this file>
local GS = game:GetService("GeometryService")
local q = workspace.Quarantine
local picks = q.Picks
local ORDER = { "KonohaTower", "KonohaHall", "KonohaHouse", "KonohaAcademy", "KonohaBlueHall", "HokageResidence", "LeafGate" }
local BATCH = 50

local old = q:FindFirstChild("Opt")
if old then
	old:Destroy()
end
local opt = Instance.new("Folder")
opt.Name = "Opt"
opt.Parent = q

local function plain(like: BasePart, class: string): BasePart
	local p = Instance.new(class) :: BasePart
	p.Name = like.Name
	p.Color = like.Color
	p.Material = like.Material
	p.Transparency = like.Transparency
	p.Reflectance = like.Reflectance
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

-- mesh-scaled bricks and cylinders become real parts, so they can be merged
local function bake(model: Model): number
	local baked = 0
	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	for _, p in parts do
		p.Parent = model -- flat: no part inside a part
	end
	for _, p in parts do
		local mesh = p:FindFirstChildWhichIsA("DataModelMesh")
		local skin = p:FindFirstChildWhichIsA("Decal") or p:FindFirstChildWhichIsA("Texture")
		if skin or p:IsA("MeshPart") or p:IsA("UnionOperation") then
			continue
		end
		local new: BasePart? = nil
		if mesh then
			local scale = (mesh :: any).Scale :: Vector3
			local at = p.CFrame * CFrame.new((mesh :: any).Offset)
			if mesh:IsA("CylinderMesh") then
				new = plain(p, "Part")
				local n = new :: Part
				n.Shape = Enum.PartType.Cylinder
				local d = math.max(p.Size.X * scale.X, p.Size.Z * scale.Z)
				n.Size = Vector3.new(p.Size.Y * scale.Y, d, d)
				n.CFrame = at * CFrame.Angles(0, 0, math.rad(90))
			elseif mesh:IsA("BlockMesh") or (mesh:IsA("SpecialMesh") and mesh.MeshType == Enum.MeshType.Brick) then
				new = plain(p, "Part")
				local n = new :: Part
				n.Size = p.Size * scale
				n.CFrame = at
			elseif mesh:IsA("SpecialMesh") and mesh.MeshType == Enum.MeshType.Wedge then
				new = plain(p, "WedgePart")
				local n = new :: BasePart
				n.Size = p.Size * scale
				n.CFrame = at
			end
		elseif not (p:IsA("Part") or p:IsA("WedgePart") or p:IsA("CornerWedgePart")) then
			-- seats, spawns, trusses: a plain block does the same job here
			new = plain(p, "Part")
			local n = new :: Part
			n.Size = p.Size
			n.CFrame = p.CFrame
		end
		if new then
			new.Parent = model
			p:Destroy()
			baked += 1
		end
	end
	return baked
end

local function merge(model: Model): (number, number, number)
	local groups, order = {}, {}
	for _, d in model:GetChildren() do
		if d:IsA("BasePart") then
			local skinned = d:FindFirstChildWhichIsA("Decal") or d:FindFirstChildWhichIsA("Texture")
			if d.Transparency >= 0.99 and not skinned then
				d:Destroy()
			elseif not d:IsA("MeshPart") and #d:GetChildren() == 0 then
				local key = d.Material.Name .. "_" .. d.Color:ToHex() .. "_" .. math.round(d.Transparency * 10) .. math.round(d.Reflectance * 10)
				if not groups[key] then
					groups[key] = {}
					table.insert(order, key)
				end
				table.insert(groups[key], d)
			end
		end
	end
	local made, tris, fails = 0, 0, 0
	for _, key in order do
		local g = groups[key]
		for i = 1, #g, BATCH do
			local chunk = {}
			for j = i, math.min(i + BATCH - 1, #g) do
				table.insert(chunk, g[j])
			end
			if #chunk >= 2 then
				local main = table.remove(chunk, 1)
				local ok, res = pcall(function()
					return GS:UnionAsync(main, chunk, {
						CollisionFidelity = Enum.CollisionFidelity.Box,
						RenderFidelity = Enum.RenderFidelity.Automatic,
						SplitApart = false,
					})
				end)
				if ok and res and #res >= 1 then
					for _, u in res do
						u.Name = "M_" .. key
						u.Anchored = true
						u.Parent = model
						made += 1
						tris += u.TriangleCount
					end
					main:Destroy()
					for _, p in chunk do
						p:Destroy()
					end
				else
					fails += 1
				end
			end
		end
	end
	return made, tris, fails
end

-- the packs stand at odd angles: the yaw most of a building's volume agrees on (mod 90 degrees)
local function yawOf(model: Model): number
	local bins = table.create(90, 0)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local cf = d.CFrame
			local best, flat = cf.RightVector, math.abs(cf.RightVector.Y)
			for _, v in { cf.UpVector, cf.LookVector } do
				if math.abs(v.Y) < flat then
					best, flat = v, math.abs(v.Y)
				end
			end
			local deg = math.round(math.deg(math.atan2(best.X, best.Z))) % 90
			bins[deg + 1] += d.Size.X * d.Size.Y * d.Size.Z
		end
	end
	local top, at = -1, 0
	for i = 1, 90 do
		if bins[i] > top then
			top, at = bins[i], i - 1
		end
	end
	return math.rad(if at > 45 then at - 90 else at)
end

-- The bounds are measured BEFORE the merge: a GeometryService union keeps its first part's CFrame
-- and is not centred on its own geometry, so Position and Size say nothing about where it stands.
-- The pivot goes to the middle of the base and the real size into the attribute "TrueSize":
-- the zone builder places a template by those two, never by its parts' boxes.
local function measure(model: Model): Vector3
	local lo, hi = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.99 then
			local cf, h = d.CFrame, d.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local c = (cf * CFrame.new(h.X * sx, h.Y * sy, h.Z * sz)).Position
						lo, hi = lo:Min(c), hi:Max(c)
					end
				end
			end
		end
	end
	model.WorldPivot = CFrame.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2)
	model:SetAttribute("TrueSize", hi - lo)
	return hi - lo
end

local function finish(model: Model): number
	local n = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		end
	end
	return n
end

workspace:SetAttribute("HarvestLog", "running")
task.spawn(function()
	local log = {}
	local x = 3000
	for _, name in ORDER do
		local src = picks:FindFirstChild(name)
		if not src then
			table.insert(log, name .. ": MISSING in Quarantine.Picks")
			continue
		end
		local t0 = os.clock()
		local before = 0
		for _, d in src:GetDescendants() do
			if d:IsA("BasePart") then
				before += 1
			end
		end
		local model = Instance.new("Model")
		model.Name = name
		for _, c in src:Clone():GetChildren() do
			c.Parent = model
		end
		model.Parent = opt
		local ok, err = pcall(function()
			local yaw = yawOf(model)
			local baked = bake(model)
			model:PivotTo(CFrame.Angles(0, -yaw, 0) * model:GetPivot()) -- square to the world axes
			local size = measure(model)
			local made, tris, fails = merge(model)
			local after = finish(model)
			model:PivotTo(CFrame.new(x + size.X / 2, 600, -6500))
			x += size.X + 50
			table.insert(
				log,
				string.format(
					"%s: %d -> %d parts (%d baked, %d unions, %d tris, %d failed), %.0fx%.0fx%.0f, %.1fs",
					name,
					before,
					after,
					baked,
					made,
					tris,
					fails,
					size.X,
					size.Y,
					size.Z,
					os.clock() - t0
				)
			)
		end)
		if not ok then
			table.insert(log, name .. ": ERROR " .. tostring(err))
		end
		workspace:SetAttribute("HarvestLog", table.concat(log, "\n") .. "\nrunning")
		task.wait()
	end
	workspace:SetAttribute("HarvestLog", table.concat(log, "\n") .. "\ndone")
end)
return "started: read workspace attribute HarvestLog"
