-- build_zone_lab.luau - Studio EDIT mode. Builds Workspace.ZoneLab: the planned anime zones
-- (design/zones/anime_zones.json) laid out side by side, one column per zone, far west of the map.
-- Run through tools/studio/zone_lab.py (it embeds _G.ZONELAB); never by hand.
--
--   ZoneLab/Zones/<NN Anime>/<Source>     a hero on its stand (attrs Id, Anime, Zone, Rarity)
--   ZoneLab/Zones/<NN Anime>/Add <Name>   a grey pad: a popular character to import next
--   ZoneLab/Zones/<NN Anime>/Spare <k>    an empty pad: room for one more
--
-- In each column the heroes stand from the front (Common) to the back (Mythic, then Premium),
-- so a new character goes on the first pad of its rarity. DEV ONLY: the server deletes it on start.
local spec = _G.ZONELAB
assert(spec, "_G.ZONELAB missing: run tools/studio/zone_lab.py")
local chars = game:GetService("ReplicatedStorage").Assets.Characters

local old = workspace:FindFirstChild("ZoneLab")
if old then
	old:Destroy()
end
local root = Instance.new("Model")
root.Name = "ZoneLab"
root:SetAttribute("DevOnly", true)
local zonesFolder = Instance.new("Folder")
zonesFolder.Name = "Zones"
zonesFolder.Parent = root

local origin = Vector3.new(spec.origin[1], spec.origin[2], spec.origin[3])
local COL = 18 -- column width (x)
local ROW = 12 -- pad spacing (z)

local function part(name, size, cf, color, parent, shape)
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

local function sign(adornee, lines, color, height, wide, tall, range)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Adornee = adornee
	gui.Size = UDim2.fromScale(wide or 11, tall or 2.6)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = range or 90 -- near signs only: from far away every sign at once is a wall of text
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

-- an invisible, unrotated anchor to hang a sign from (a sign on the rotated cylinder goes sideways)
local function anchor(parent, at)
	local a = part("SignAnchor", Vector3.new(1, 1, 1), CFrame.new(at), Color3.new(1, 1, 1), parent)
	a.Transparency = 1
	a.CanCollide = false
	a.CanQuery = false
	return a
end

local function pad(parent, at, color, transparency)
	local p = part(
		"Stand",
		Vector3.new(1, 8, 8),
		CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		parent,
		Enum.PartType.Cylinder
	)
	p.Transparency = transparency or 0
	return p
end

local zones = spec.zones
local depthRows = spec.rows
local width = #zones * COL + 24
local depth = depthRows * ROW + 60

-- the floor: one tinted strip per zone so the columns read apart
part(
	"Floor",
	Vector3.new(width, 2, depth),
	CFrame.new(origin + Vector3.new(0, -1.1, depth / 2 - 36)),
	Color3.fromRGB(52, 48, 82),
	root
)
local readme = anchor(root, origin + Vector3.new(0, 2, -44))
sign(readme, {
	"ZONE LAB (Studio only, removed when the game runs)",
	"One column per planned zone, zone 1 on the left. Front = Common, back = Mythic, then Premium.",
	"Grey pads = characters to import next. Empty pads = room for more.",
}, Color3.fromRGB(255, 214, 64), 6, 34, 4, 600)
local legend = anchor(root, origin + Vector3.new(-width / 2 + 30, 2, -44))
local legendLines = { "RARITY" }
for _, r in spec.rarityOrder do
	table.insert(legendLines, r)
end
sign(legend, legendLines, Color3.fromRGB(255, 255, 255), 8, 9, 9, 600)

local made, missing, toAdd = 0, {}, 0
for zi, z in zones do
	local x = origin.X - (zi - (#zones + 1) / 2) * COL -- zone 1 on the left as seen from the readme
	local folder = Instance.new("Folder")
	folder.Name = string.format("%02d %s", z.n, z.anime)
	folder:SetAttribute("Anime", z.anime)
	folder:SetAttribute("Zone", z.n)
	folder.Parent = zonesFolder
	local stripColor = if z.mixed then Color3.fromRGB(78, 60, 92) elseif zi % 2 == 0 then Color3.fromRGB(64, 58, 100) else Color3.fromRGB(58, 70, 108)
	part(
		"Strip",
		Vector3.new(COL - 2, 0.2, depthRows * ROW + 16),
		CFrame.new(x, origin.Y - 0.05, origin.Z + (depthRows * ROW) / 2 - 8),
		stripColor,
		folder
	)
	-- the zone's banner at the front of its column
	local banner = anchor(folder, Vector3.new(x, origin.Y + 2, origin.Z - 24))
	sign(banner, {
		string.format("ZONE %d", z.n),
		string.upper(z.anime),
		z.title,
		string.format("%d heroes, %d to add", z.heroCount, z.suggestCount),
	}, Color3.fromHex(z.color), 6, 15, 6, 600)

	for row0, slot in z.rows do
		local row = row0 - 1
		local c = slot.hero
		local name = slot.suggest
		if c then
		local at = Vector3.new(x, origin.Y, origin.Z + row * ROW)
		local holder = Instance.new("Model")
		holder.Name = c.source
		holder:SetAttribute("Id", c.id)
		holder:SetAttribute("Anime", z.anime)
		holder:SetAttribute("Zone", z.n)
		holder:SetAttribute("Rarity", c.rarity)
		local color = Color3.fromHex(c.color)
		local base = pad(holder, at, color)
		holder.PrimaryPart = base
		local template = chars:FindFirstChild("Char_" .. c.id)
		if template then
			local h = template:Clone()
			h.Name = c.id
			h.LevelOfDetail = Enum.ModelLevelOfDetail.Disabled -- full model at any distance, never a far-away stand-in
			h:PivotTo(CFrame.new(at + Vector3.new(0, 0.5, 0)))
			for _, d in h:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
				elseif d:IsA("Humanoid") then
					d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				end
			end
			h.Parent = holder
		else
			table.insert(missing, c.source)
		end
		local label = anchor(holder, at + Vector3.new(0, 0.5, 0))
		sign(label, { c.source, c.alias .. "  |  " .. c.rarity }, color, 8, 9, 2.2)
		holder.Parent = folder
		made += 1
		elseif name then
		local at = Vector3.new(x, origin.Y, origin.Z + row * ROW)
		local holder = Instance.new("Model")
		holder.Name = "Add " .. name
		holder:SetAttribute("Suggested", name)
		holder:SetAttribute("Anime", z.anime)
		pad(holder, at, Color3.fromRGB(120, 124, 140), 0.35)
		local label = anchor(holder, at + Vector3.new(0, 0.5, 0))
		sign(label, { "ADD: " .. name, "suggested" }, Color3.fromRGB(150, 156, 175), 2.5, 8, 1.8)
		holder.Parent = folder
		toAdd += 1
		else
		local holder = Instance.new("Model")
		holder.Name = "Spare"
		pad(holder, Vector3.new(x, origin.Y, origin.Z + row * ROW), Color3.fromRGB(90, 94, 116), 0.6)
		holder.Parent = folder
		end
	end
	local row = #z.rows
	local k = 0
	while row < depthRows do
		k += 1
		local holder = Instance.new("Model")
		holder.Name = "Spare " .. k
		pad(holder, Vector3.new(x, origin.Y, origin.Z + row * ROW), Color3.fromRGB(90, 94, 116), 0.6)
		holder.Parent = folder
		row += 1
	end
end

root.Parent = workspace
return string.format(
	"zone lab: %d zones, %d heroes placed, %d pads to add, floor %d x %d%s",
	#zones,
	made,
	toAdd,
	width,
	depth,
	if #missing > 0 then "\nMISSING TEMPLATE: " .. table.concat(missing, ", ") else ""
)
