-- build_aura_pack_browser.luau - Studio EDIT mode. Lays out the owner's whole aura pack
-- (ServerStorage.ImportedVfx.AuraPacksAll, the first pack taken in) like the aura showcase: ONE
-- character per stand, in a grid, each with a name sign, on its own platform east of the showcase.
-- Workspace.AuraPackBrowser is DEV ONLY (attr DevOnly; the server deletes it on start,
-- src/server/init.server.luau). The archive in ServerStorage is never touched.
--
--   AuraPackBrowser/Auras/<unit name>   a stand with that pack character on it (attrs Pack, Unit)
--
-- Every copy is stripped of every script and sound first: this pack held 20 scripts (one named
-- "Read this rn") and free packs have carried a Studio-only backdoor (CLAUDE.md, known traps).
-- Nothing in the copies can run.
--
-- Run: python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --dm Edit --file <this file>
local SS = game:GetService("ServerStorage")
local folder = SS.ImportedVfx.AuraPacksAll:FindFirstChild("Folder")
local source = folder and folder:FindFirstChild("Aura packs all")
assert(source, "ServerStorage.ImportedVfx.AuraPacksAll.Folder['Aura packs all'] not found")

local old = workspace:FindFirstChild("AuraPackBrowser")
if old then
	old:Destroy()
end

local ORIGIN = Vector3.new(-600, 320, -40) -- east of the showcase (its floor spans x -896..-744)
local COLS = 10
local PITCH = 14
local PACK_COLOURS = {
	Color3.fromRGB(63, 182, 255),
	Color3.fromRGB(79, 209, 139),
	Color3.fromRGB(255, 200, 61),
	Color3.fromRGB(178, 102, 255),
	Color3.fromRGB(255, 120, 160),
	Color3.fromRGB(255, 150, 70),
	Color3.fromRGB(120, 220, 220),
	Color3.fromRGB(200, 200, 215),
	Color3.fromRGB(150, 160, 255),
}

-- every model that holds a Humanoid is one unit (a wrapper model around a unit is not)
local units: { { model: Model, pack: string } } = {}
local function collect(x: Instance, pack: string)
	for _, c in x:GetChildren() do
		if c:IsA("Model") then
			if c:FindFirstChildOfClass("Humanoid") then
				table.insert(units, { model = c, pack = pack })
			else
				collect(c, pack)
			end
		elseif c:IsA("Folder") then
			collect(c, pack)
		end
	end
end
local packOrder = {}
for _, pack in source:GetChildren() do
	table.insert(packOrder, pack)
end
table.sort(packOrder, function(a, b)
	return a.Name < b.Name
end)
for _, pack in packOrder do
	collect(pack, if pack.Name == "Model" then "Pack9" else pack.Name)
end

local root = Instance.new("Model")
root.Name = "AuraPackBrowser"
root:SetAttribute("DevOnly", true)
local stands = Instance.new("Folder")
stands.Name = "Auras"
stands.Parent = root

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, parent: Instance, shape: Enum.PartType?)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function sign(adornee: BasePart, lines: { string }, color: Color3, height: number, wide: number?)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Adornee = adornee
	gui.Size = UDim2.fromScale(wide or 9, 2.6)
	gui.StudsOffsetWorldSpace = adornee.CFrame:VectorToObjectSpace(Vector3.new(0, height, 0))
	gui.LightInfluence = 0
	gui.MaxDistance = 140
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.fromRGB(24, 20, 48)
	t.BackgroundTransparency = 0.15
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Text = table.concat(lines, "\n")
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color
	stroke.Thickness = 3
	stroke.Parent = t
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = t
	t.Parent = gui
	gui.Parent = adornee
end

local rows = math.ceil(#units / COLS)
local depth = (rows + 3) * PITCH + 20
local width = COLS * PITCH + 40
part(
	"Floor",
	Vector3.new(width, 2, depth),
	CFrame.new(ORIGIN + Vector3.new(0, -1, depth / 2 - 10)),
	Color3.fromRGB(64, 58, 96),
	root
)
local readme = part(
	"Readme",
	Vector3.new(2, 2, 2),
	CFrame.new(ORIGIN + Vector3.new(0, 4, -14)),
	Color3.fromRGB(255, 214, 64),
	root
)
readme.Transparency = 1
sign(readme, {
	"AURA PACK (a copy: scripts removed, Studio only)",
	`{#units} characters from {#packOrder} packs. Each sign: pack and name.`,
	"Tell Claude the names you want converted to game auras.",
}, Color3.fromRGB(255, 214, 64), 6, 12)

local totals: { [string]: number } = {}
for _, u in units do
	totals[u.model.Name] = (totals[u.model.Name] or 0) + 1
end
local packColour: { [string]: Color3 } = {}
for i, pack in packOrder do
	packColour[if pack.Name == "Model" then "Pack9" else pack.Name] = PACK_COLOURS[(i - 1) % #PACK_COLOURS + 1]
end

local stripped, made = 0, 0
local seen: { [string]: number } = {}
for i, unit in units do
	local c = (i - 1) % COLS
	local r = math.floor((i - 1) / COLS)
	local at = ORIGIN + Vector3.new((c - (COLS - 1) / 2) * PITCH, 0, r * PITCH)
	local colour = packColour[unit.pack]
	local holder = Instance.new("Model")
	holder.Name = unit.model.Name
	holder:SetAttribute("Pack", unit.pack)
	holder:SetAttribute("Unit", unit.model.Name)
	local base = part(
		"Stand",
		Vector3.new(1, 7, 7),
		CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90)),
		colour,
		holder,
		Enum.PartType.Cylinder
	)
	holder.PrimaryPart = base

	local copy = unit.model:Clone()
	for _, d in copy:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("ForceField") then
			d:Destroy()
			stripped += 1
		end
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		elseif d:IsA("Humanoid") then
			d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	end
	local hrp = copy:FindFirstChild("HumanoidRootPart")
	local anchorPart = (hrp or copy:FindFirstChild("Torso") or copy:FindFirstChild("UpperTorso")) :: BasePart?
	if anchorPart then
		-- soles on the stand, facing the viewer (-Z): the lowest foot or leg decides the height
		local lowest = math.huge
		for _, d in copy:GetDescendants() do
			if d:IsA("BasePart") and (d.Name:find("Foot") or d.Name:find("Leg")) then
				lowest = math.min(lowest, d.Position.Y - d.Size.Y / 2)
			end
		end
		local drop = if lowest < math.huge then anchorPart.Position.Y - lowest else 3
		local pivotInRoot = anchorPart.CFrame:ToObjectSpace(copy:GetPivot())
		copy:PivotTo(CFrame.new(at + Vector3.new(0, 0.5 + drop, 0)) * pivotInRoot)
	else
		copy:PivotTo(CFrame.new(at + Vector3.new(0, 4, 0)))
	end
	copy.Parent = holder
	seen[unit.model.Name] = (seen[unit.model.Name] or 0) + 1
	local label = unit.model.Name:gsub("^POF:RE AURA:?%s*", ""):gsub("^PoF:RE Aura[^:]*:%s*", "")
	label = if #label == 0 then unit.model.Name else label
	if (totals[unit.model.Name] or 0) > 1 then
		label ..= ` #{seen[unit.model.Name]}`
		holder.Name = unit.model.Name .. ` #{seen[unit.model.Name]}`
	end
	sign(base, { label, unit.pack }, colour, 8)
	holder.Parent = stands
	made += 1
end

root.Parent = workspace
return string.format(
	"pack browser: %d stands from %d packs, %d scripts/sounds stripped, floor %d x %d",
	made,
	#packOrder,
	stripped,
	width,
	depth
)
