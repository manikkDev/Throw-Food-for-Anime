-- harvest_naruto_store.luau - Studio EDIT mode, ONE-OFF (2026-11-22), after harvest_naruto.luau.
-- Moves the optimised picks out of Workspace.Quarantine into ServerStorage.StoreAssets.Zone01_Naruto
-- (never delete: the zone builder reads its templates there) and adds:
--   * Head1..Head4: the Hokage Rock busts, made with Studio's mesh generator (one prompt per head,
--     "giant carved stone statue head ... monolithic tan sandstone"); they stand in
--     Workspace.Quarantine.Heads, faces to -Z
--   * KonohaTree: one low-poly tree (trunk + crown) from the village pack
-- Every template ends up with its pivot at the middle of its base, square to the world axes.
-- Run: python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --dm Edit --file <this file>
local q = workspace.Quarantine
local store = game:GetService("ServerStorage").StoreAssets
local dest = store:FindFirstChild("Zone01_Naruto")
if dest then
	dest:Destroy()
end
dest = Instance.new("Folder")
dest.Name = "Zone01_Naruto"
dest:SetAttribute("Note", "Zone 1 Hidden Leaf Village templates (stripped store models + generated heads). Never delete.")
dest.Parent = store

local function basePivot(model: Model)
	local lo, hi = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
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
end

local out = {}
for _, name in { "KonohaTower", "KonohaHall", "KonohaHouse", "HokageResidence", "LeafGate" } do
	local m = q.Opt:FindFirstChild(name)
	if m then
		-- its pivot (base centre) and attribute TrueSize come from the harvest: a merged part's
		-- box does not say where it stands, so nothing is measured again here
		local c = m:Clone()
		c:PivotTo(CFrame.new(0, 0, 0))
		c.Parent = dest
		table.insert(out, name .. " " .. tostring(c:GetAttribute("TrueSize")))
	end
end
for _, head in q.Heads:GetChildren() do
	local mesh = head:FindFirstChildWhichIsA("MeshPart", true)
	if mesh then
		local model = Instance.new("Model")
		model.Name = head.Name
		local c = mesh:Clone()
		c.Name = "Stone"
		c.Parent = model
		basePivot(model)
		model:PivotTo(CFrame.new(0, 0, 0))
		model.Parent = dest
		table.insert(out, head.Name)
	end
end
local pack = q:FindFirstChild("Q_Konoha_erg")
local tree = pack and pack.Konoha.Tree:FindFirstChildWhichIsA("Model")
tree = tree and tree:FindFirstChildWhichIsA("Model")
if tree then
	local c = tree:Clone()
	c.Name = "KonohaTree"
	for _, d in c:GetDescendants() do
		if d:IsA("MeshPart") then
			d.Name = if d.Name:find("Leaves") then "Crown" else "Trunk"
		end
	end
	basePivot(c)
	c:PivotTo(CFrame.new(0, 0, 0))
	c.Parent = dest
	table.insert(out, "KonohaTree")
end
return "stored in ServerStorage.StoreAssets.Zone01_Naruto: " .. table.concat(out, ", ")
