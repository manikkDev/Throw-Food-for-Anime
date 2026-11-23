-- zone_gates.luau - Studio EDIT mode, safe to run again. The torii at the start of every zone.
--
-- Owner (2026-11-22): the old gate (one generated kit mesh, 470 x 247, Lane_ZoneGate) "feels ass,
-- without any detailing", "too big and fat"; make it far better, with anime vibes. Each gate is now
-- built from parts as a myojin torii, a third lower and with pillars half as thick:
--   * vermilion lacquered pillars on black bases (kamebara) on stone, gold rings (nemaki)
--   * a straight tie beam (nuki) with black wedges, a red beam (shimaki) with a gold line, and the
--     black top beam (kasagi) curving up at its ends (sori) to gold caps
--   * a framed name plaque on a black strut (gakuzuka), read from the stage and from the lane
--   * a straw shimenawa rope sagging between the pillars with zigzag paper (shide) and tassels
--   * a glowing red paper lantern (chochin) hanging inside each pillar
-- The pillars stand where the old ones did (x +-203.5, the footprint every zone builder keeps free).
-- The zone builders still work on it: they recolour every part named "Accent" (the plaque's frame,
-- the lanterns' bands) and rewrite the one TextLabel to "<title>\n<needs>".
-- The old meshes are archived once in ServerStorage.MapArchive.ZoneGates_v1 (never delete).
-- Run: python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file <this file>
local SS = game:GetService("ServerStorage")
local T = workspace.Terrain
local lanes = workspace.Map.Lanes
local KIT = game:GetService("ReplicatedStorage").Assets.Kit

local RED = Color3.fromRGB(226, 58, 40)
local RED_DARK = Color3.fromRGB(176, 38, 30)
local BLACK = Color3.fromRGB(30, 26, 32)
local GOLD = Color3.fromRGB(255, 196, 64)
local STONE = Color3.fromRGB(168, 160, 150)
local STRAW = Color3.fromRGB(246, 228, 172)
local STRAW_DARK = Color3.fromRGB(206, 176, 112)
local PAPER = Color3.fromRGB(252, 250, 244)
local CREAM = Color3.fromRGB(255, 246, 222)
local INK = Color3.fromRGB(24, 22, 44)
local LANTERN = Color3.fromRGB(214, 44, 34)

local PX = 87 -- the pillars' centres (x +-): just outside the lane's kerb (x 72..76; 115 with three
-- tracks, 175 with five)
local NUKI_Y, SHIMAKI_Y, KASAGI_Y = 82, 100, 108.5
local PILLAR_D = 16

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = size.Magnitude > 12
	p.Parent = parent
	return p
end
-- a cylinder standing up (its axis along Y) at `at`
local function post(
	parent: Instance,
	name: string,
	d: number,
	h: number,
	at: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	return part(
		parent,
		name,
		Vector3.new(h, d, d),
		CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material,
		Enum.PartType.Cylinder
	)
end
-- a cylinder lying from a to b
local function rod(
	parent: Instance,
	name: string,
	d: number,
	a: Vector3,
	b: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local len = (b - a).Magnitude
	-- a cylinder's axis is its X: point X from a to b
	local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
	return part(parent, name, Vector3.new(len, d, d), cf, color, material, Enum.PartType.Cylinder)
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { T }
groundParams.IgnoreWater = true
local function groundAt(x: number, z: number): number
	local hit = workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -200, 0), groundParams)
	return if hit then math.max(hit.Position.Y, -70) else -48
end

local function build(gate: Model, title: string, accent: Color3, Z: number): Model
	local m = Instance.new("Model")
	m.Name = "Torii"

	for _, s in { -1, 1 } do
		local x = s * PX
		local g = groundAt(x, Z)
		-- stone footing, black base, gold ring, the pillar, two gold rings high up
		part(
			m,
			"Footing",
			Vector3.new(26, 6, 26),
			CFrame.new(x, g - 2, Z),
			STONE,
			Enum.Material.Slate
		)
		post(m, "Kamebara", 22, 11, Vector3.new(x, g + 6.5, Z), BLACK)
		post(m, "BaseRing", 19, 1.6, Vector3.new(x, g + 12.4, Z), GOLD, Enum.Material.SmoothPlastic)
		local top = SHIMAKI_Y - 4
		local pillar =
			post(m, "Pillar", PILLAR_D, top - (g + 12), Vector3.new(x, (top + g + 12) / 2, Z), RED)
		pillar.Reflectance = 0.04
		post(m, "Nemaki", PILLAR_D + 1.4, 2.2, Vector3.new(x, NUKI_Y - 8, Z), GOLD)
		post(m, "Nemaki", PILLAR_D + 1.4, 1.2, Vector3.new(x, NUKI_Y - 11, Z), BLACK)
		-- black wedges (kusabi) where the tie beam passes through the pillar
		for _, dz in { -1, 1 } do
			part(
				m,
				"Kusabi",
				Vector3.new(3, 9.6, 3),
				CFrame.new(x + s * (PILLAR_D / 2 + 1.5), NUKI_Y, Z + dz * 2.2),
				BLACK
			)
		end
	end

	-- the tie beam, the red beam with its gold line, the strut under the plaque
	part(m, "Nuki", Vector3.new(2 * (PX + 20), 9, 7), CFrame.new(0, NUKI_Y, Z), RED)
	part(m, "Shimaki", Vector3.new(2 * (PX + 32), 8, 10), CFrame.new(0, SHIMAKI_Y, Z), RED_DARK)
	for _, dz in { -1, 1 } do
		part(
			m,
			"GoldLine",
			Vector3.new(2 * (PX + 32), 1, 0.4),
			CFrame.new(0, SHIMAKI_Y - 2.4, Z + dz * 5.1),
			GOLD
		)
	end
	part(
		m,
		"Gakuzuka",
		Vector3.new(8, SHIMAKI_Y - 4 - (NUKI_Y + 4.5), 6),
		CFrame.new(0, (SHIMAKI_Y - 4 + NUKI_Y + 4.5) / 2, Z),
		BLACK
	)

	-- the top beam: straight in the middle, then curving up in three steps to a gold cap
	part(m, "Kasagi", Vector3.new(2 * (PX - 54), 9, 14), CFrame.new(0, KASAGI_Y, Z), BLACK)
	for _, s in { -1, 1 } do
		local joint = Vector3.new(s * (PX - 54), KASAGI_Y, Z)
		for i, deg in { 3, 7, 12 } do
			local seg = 33
			local th = math.rad(deg)
			local dir = Vector3.new(s * math.cos(th), math.sin(th), 0)
			local tilt = CFrame.Angles(0, 0, s * th)
			part(
				m,
				"Kasagi",
				Vector3.new(seg + 1.2, 9, 14),
				CFrame.new(joint + dir * (seg / 2)) * tilt,
				BLACK
			)
			joint += dir * seg
			if i == 3 then
				part(
					m,
					"KasagiCap",
					Vector3.new(3, 10, 15),
					CFrame.new(joint + dir * 1) * tilt,
					GOLD
				)
			end
		end
	end

	-- the plaque, in front of the beams (and behind, read from the lane)
	for _, dz in { -1, 1 } do
		local z = Z + dz * 6.6
		local frame = part(m, "Accent", Vector3.new(156, 32, 1.6), CFrame.new(0, 88, z), accent)
		frame.Reflectance = 0.05
		part(m, "PlaqueRim", Vector3.new(150, 26, 1.8), CFrame.new(0, 88, z + dz * 0.2), BLACK)
		local face =
			part(m, "Plaque", Vector3.new(146, 22, 2), CFrame.new(0, 88, z + dz * 0.3), CREAM)
		part(m, "PlaqueCap", Vector3.new(162, 2.2, 3.2), CFrame.new(0, 103, z), BLACK)
		for _, cx in { -74, 74 } do
			for _, cy in { 76, 100 } do
				post(m, "Stud", 2.6, 0.8, Vector3.new(cx, cy, z + dz * 0.9), GOLD).CFrame = CFrame.new(
					cx,
					cy,
					z + dz * 0.9
				) * CFrame.Angles(0, math.rad(90), 0)
			end
		end
		local gui = Instance.new("SurfaceGui")
		gui.Face = if dz < 0 then Enum.NormalId.Front else Enum.NormalId.Back
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		-- a scaled label stops growing at 100 px: 100 px is the face's short side (22 studs)
		gui.PixelsPerStud = 100 / 22
		gui.LightInfluence = 0.6
		gui.Parent = face
		local label = Instance.new("TextLabel")
		label.Name = "Title"
		label.Size = UDim2.fromScale(0.94, 0.86)
		label.Position = UDim2.fromScale(0.03, 0.07)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.LuckiestGuy
		label.TextScaled = true
		label.TextColor3 = INK
		label.Text = title
		label.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		stroke.Color = Color3.fromRGB(255, 255, 255)
		stroke.Thickness = 1.5
		stroke.Parent = label
	end

	-- the shimenawa: a straw rope sagging between the pillars, thick in the middle and thinner at
	-- the ends, twisted (dark bands at a slant), knotted at each pillar, with shide and tassels
	local x0, yEnd, sag = PX - PILLAR_D / 2 - 1, NUKI_Y - 7, 17
	local function ropeY(x: number): number
		return yEnd - sag * (1 - (x / x0) ^ 2)
	end
	local function ropeD(x: number): number
		return 4 + 4 * (1 - (x / x0) ^ 2)
	end
	local n = 32
	for i = 0, n - 1 do
		local xa, xb = -x0 + 2 * x0 * i / n, -x0 + 2 * x0 * (i + 1) / n
		local xm = (xa + xb) / 2
		local a, b = Vector3.new(xa, ropeY(xa), Z), Vector3.new(xb, ropeY(xb), Z)
		rod(
			m,
			"Shimenawa",
			ropeD(xm),
			a,
			b + (b - a).Unit * 0.6,
			STRAW,
			Enum.Material.SmoothPlastic
		)
		-- a twist: a thin dark band round the rope, leaning along it
		local mid = (a + b) / 2
		local band = rod(
			m,
			"RopeTwist",
			ropeD(xm) + 0.5,
			mid - (b - a).Unit * 0.35,
			mid + (b - a).Unit * 0.35,
			STRAW_DARK
		)
		band.CFrame = band.CFrame * CFrame.Angles(0, math.rad(28), 0)
	end
	for _, s in { -1, 1 } do
		-- the knot at the pillar
		local k = Vector3.new(s * (x0 - 1), yEnd + 0.5, Z)
		part(
			m,
			"RopeKnot",
			Vector3.new(6, 6, 6),
			CFrame.new(k) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
			STRAW_DARK
		)
	end
	for i = -3, 3 do
		-- spread along the rope between the pillars (126 apart at PX 175: 0.24 PX)
		local sx = math.round(i * 0.24 * PX)
		local y = ropeY(sx) - ropeD(sx) / 2
		if math.abs(i) == 2 then
			-- a straw tassel
			post(m, "Tassel", 3.4, 10, Vector3.new(sx, y - 5, Z), STRAW_DARK, Enum.Material.Fabric)
		elseif sx ~= 0 then
			-- zigzag paper: four steps, each one stepping out to the other side
			for k = 0, 3 do
				local off = if k % 2 == 0 then -1.5 else 1.5
				part(
					m,
					"Shide",
					Vector3.new(4.2, 4.4, 0.3),
					CFrame.new(sx + off, y - 2.2 - k * 4.2, Z - 0.4),
					PAPER
				)
			end
		end
	end

	-- the lanterns, hung from the tie beam inside each pillar
	for _, s in { -1, 1 } do
		local lx = s * (PX - 30)
		local cy = NUKI_Y - 21
		rod(m, "Cord", 0.4, Vector3.new(lx, NUKI_Y - 4.5, Z), Vector3.new(lx, cy + 7.5, Z), BLACK)
		post(m, "LanternCap", 6.4, 1.4, Vector3.new(lx, cy + 6.9, Z), BLACK)
		local body = post(m, "Lantern", 9, 12, Vector3.new(lx, cy, Z), LANTERN, Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 150, 90)
		light.Range = 16
		light.Brightness = 1.4
		light.Parent = body
		post(m, "Accent", 9.4, 1.2, Vector3.new(lx, cy + 3.2, Z), accent)
		post(m, "Accent", 9.4, 1.2, Vector3.new(lx, cy - 3.2, Z), accent)
		post(m, "LanternCap", 6.4, 1.4, Vector3.new(lx, cy - 6.9, Z), BLACK)
		post(m, "Tassel", 1.2, 4, Vector3.new(lx, cy - 9.6, Z), GOLD)
	end

	-- a pair of guardian lions (komainu) on stone pedestals beside the pillars, turned in towards
	-- whoever comes through: they fill the ground by the pillars, which looked bare
	for _, s in { -1, 1 } do
		local lx, lz = s * (PX + 27), Z - 18
		local g = groundAt(lx, lz)
		part(
			m,
			"LionPedestal",
			Vector3.new(20, 9, 20),
			CFrame.new(lx, g + 1.5, lz),
			STONE,
			Enum.Material.Slate
		)
		part(
			m,
			"LionPedestalCap",
			Vector3.new(22, 1.6, 22),
			CFrame.new(lx, g + 6.8, lz),
			STONE:Lerp(BLACK, 0.3),
			Enum.Material.Slate
		)
		local lion = KIT:FindFirstChild(if s < 0 then "Prop_store_LionA" else "Prop_store_LionB")
		if lion then
			local l = lion:Clone() :: Model
			for _, d in l:GetDescendants() do
				if d:IsA("LuaSourceContainer") then
					d:Destroy()
				elseif d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanQuery = false
					d.CanTouch = false
				end
			end
			l:ScaleTo(l:GetScale() * 3)
			l:PivotTo(CFrame.new(lx, g + 7.6, lz) * CFrame.Angles(0, math.rad(s * 30), 0))
			l.Name = "Komainu"
			l.Parent = m
		end
	end

	m.Parent = gate
	return m
end

-- ---------------------------------------------------------------------------------- every gate
local archive = SS:FindFirstChild("MapArchive")
if not archive then
	archive = Instance.new("Folder")
	archive.Name = "MapArchive"
	archive.Parent = SS
end
local old = archive:FindFirstChild("ZoneGates_v1")
if not old then
	old = Instance.new("Folder")
	old.Name = "ZoneGates_v1"
	old:SetAttribute(
		"Note",
		"The zone gates' kit meshes (Lane_ZoneGate) before zone_gates.luau (2026-11-22). Never delete."
	)
	old.Parent = archive
end

local built = {}
for _, zone in lanes:GetChildren() do
	if zone.Name:sub(1, 5) == "Zone_" then
		for _, gate in zone:GetChildren() do
			if gate:IsA("Model") and gate.Name:sub(1, 5) == "Gate_" then
				-- the sign's text and the zone's accent, from what stands there now
				local title, accent = "ZONE", GOLD
				for _, d in gate:GetDescendants() do
					if d:IsA("TextLabel") and d.Text ~= "" then
						title = d.Text
					elseif d:IsA("BasePart") and d.Name == "Accent" then
						accent = d.Color
					end
				end
				local pivot = gate:GetPivot()
				for _, c in gate:GetChildren() do
					if c.Name == "Lane_ZoneGate" then
						local keep = c:Clone()
						keep.Name = gate.Name
						keep.Parent = old
						c:Destroy()
					elseif c.Name == "Torii" then
						c:Destroy()
					end
				end
				build(gate, title, accent, pivot.Position.Z)
				gate.WorldPivot = pivot -- the zone builders find a gate by its pivot's z
				table.insert(
					built,
					string.format(
						"%s %.0f [%s]",
						gate.Name,
						pivot.Position.Z,
						(title:gsub("\n", " / "))
					)
				)
			end
		end
	end
end
table.sort(built)
return #built .. " gates:\n" .. table.concat(built, "\n")
