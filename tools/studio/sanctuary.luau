-- sanctuary.luau - Studio EDIT mode, safe to run again. The summon shrine's plaza, the hub's heart.
--
-- Owner (2026-11-22): "can you make this place even better". It was a flat pink ring, a small kit
-- shrine, four benches on the ring and the golden wish dragon on its own. Now a summoning sanctuary:
--   * a low stone dais with a gold rim (the hub's spawn point stays level with its front edge)
--   * a magic circle set into it: gold and cyan rings of light, a hexagram, twelve runes, motes
--     drifting up from it (particles, no script)
--   * the summon shrine as a small ornate pavilion: red pillars, a tiered black roof with gold
--     corners and finial, and inside a violet summoning orb floating over a stone pedestal, ringed
--     by two tilted halos. It is built round the prompt's anchor (Hub.Shrine), which is untouched,
--     so the summon prompt and its title work as before
--   * four stone pylons with floating light orbs, two braziers burning by the dragon
-- The old pink rings, the SummonCircle decal, the benches on the ring, two spirit lanterns and the
-- kit shrine model are archived once in ServerStorage.MapArchive.Sanctuary_v1 (never delete).
-- Run: python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file <this file>
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local hub, hubV2 = workspace.Map.Hub, workspace.Map.HubV2
local KIT = RS.Assets.Kit

local G = -1 -- the plaza's ground
local C = Vector3.new(0, 0, -100) -- the shrine's centre
local STONE = Color3.fromRGB(196, 186, 170)
local STONE_DARK = Color3.fromRGB(62, 58, 70)
local PYLON = Color3.fromRGB(128, 120, 112)
local RED = Color3.fromRGB(214, 52, 40)
local BLACK = Color3.fromRGB(30, 26, 32)
local GOLD = Color3.fromRGB(255, 196, 64)
local GOLD_GLOW = Color3.fromRGB(255, 214, 110)
local CYAN = Color3.fromRGB(90, 220, 255)
local VIOLET = Color3.fromRGB(160, 110, 255)

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	solid: boolean?
): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = solid == true
	p.CanQuery = solid == true
	p.CanTouch = false
	p.CastShadow = size.Magnitude > 8
	p.Parent = parent
	return p
end
-- a flat disc lying on the ground, its top at `top`
local function flat(
	parent: Instance,
	name: string,
	d: number,
	h: number,
	top: number,
	color: Color3,
	material: Enum.Material?,
	solid: boolean?
): BasePart
	local p = part(
		parent,
		name,
		Vector3.new(h, d, d),
		CFrame.new(C.X, top - h / 2, C.Z) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material,
		solid
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function column(
	parent: Instance,
	name: string,
	d: number,
	y0: number,
	y1: number,
	x: number,
	z: number,
	color: Color3,
	material: Enum.Material?,
	solid: boolean?
): BasePart
	local p = part(
		parent,
		name,
		Vector3.new(y1 - y0, d, d),
		CFrame.new(x, (y0 + y1) / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material,
		solid
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function ball(
	parent: Instance,
	name: string,
	d: number,
	at: Vector3,
	color: Color3,
	material: Enum.Material?
): BasePart
	local p = part(parent, name, Vector3.new(d, d, d), CFrame.new(at), color, material)
	p.Shape = Enum.PartType.Ball
	return p
end
local function light(p: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Parent = p
end
-- a ring of light: n short bars round `cf` (its Y the ring's axis)
local function halo(
	parent: Instance,
	cf: CFrame,
	d: number,
	n: number,
	thick: number,
	color: Color3
)
	local seg = math.pi * d / n + thick * 0.4
	for k = 0, n - 1 do
		part(
			parent,
			"Halo",
			Vector3.new(seg, thick, thick),
			cf * CFrame.Angles(0, k * 2 * math.pi / n, 0) * CFrame.new(0, 0, -d / 2),
			color,
			Enum.Material.Neon
		).CastShadow =
			false
	end
end
local function sparks(
	p: BasePart,
	rate: number,
	speed: NumberRange,
	life: NumberRange,
	size: number,
	c0: Color3,
	c1: Color3
)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Rate = rate
	e.Speed = speed
	e.Lifetime = life
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.EmissionDirection = Enum.NormalId.Top
	e.SpreadAngle = Vector2.new(10, 10)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Color = ColorSequence.new(c0, c1)
	e.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = p
	return e
end
local function place(parent: Instance, template: Instance, scale: number, cf: CFrame): Model
	local m = template:Clone() :: Model
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	if scale ~= 1 then
		m:ScaleTo(m:GetScale() * scale)
	end
	m:PivotTo(cf)
	m.Parent = parent
	return m
end

-- ---------------------------------------------------------------------------------- the old plaza
local archive = SS:FindFirstChild("MapArchive")
if not archive then
	archive = Instance.new("Folder")
	archive.Name = "MapArchive"
	archive.Parent = SS
end
local old = archive:FindFirstChild("Sanctuary_v1")
if not old then
	old = Instance.new("Folder")
	old.Name = "Sanctuary_v1"
	old:SetAttribute(
		"Note",
		"The summon plaza's rings, decal, benches, lanterns and kit shrine before sanctuary.luau (2026-11-22). Never delete."
	)
	old.Parent = archive
end
local plaza = hub:FindFirstChild("Plaza")
local function stow(inst: Instance?)
	if inst then
		inst.Parent = old
	end
end
if plaza then
	stow(plaza:FindFirstChild("RingInner"))
	stow(plaza:FindFirstChild("RingOuter"))
	for _, c in plaza:GetChildren() do
		local pos = if c:IsA("Model")
			then c:GetPivot().Position
			elseif c:IsA("BasePart") then c.Position
			else nil
		if
			pos
			and (pos - C).Magnitude < 34
			and (c.Name:find("Bench") or c.Name:find("SpiritLantern"))
		then
			stow(c)
		end
	end
end
stow(hubV2:FindFirstChild("SummonCircle"))
local anchor = hub:FindFirstChild("Shrine") :: BasePart
stow(anchor and anchor:FindFirstChild("Hub_SummonShrine"))

local root = hub:FindFirstChild("Sanctuary")
if root then
	root:Destroy()
end
root = Instance.new("Folder")
root.Name = "Sanctuary"

-- ---------------------------------------------------------------------------------- 1. the dais
local DAIS_D, TOP = 50, G + 1.2
flat(root, "Dais", DAIS_D, 1.8, TOP, STONE, Enum.Material.Slate, true)
flat(root, "DaisRim", DAIS_D + 0.8, 0.5, TOP - 0.2, GOLD)
flat(root, "DaisFloor", DAIS_D - 3, 0.1, TOP + 0.05, STONE_DARK, Enum.Material.Slate)

-- ---------------------------------------------------------------------------------- 2. the circle
do
	local y = TOP + 0.06
	for i, r in
		{
			{ 45, GOLD_GLOW, Enum.Material.Neon },
			{ 43.6, STONE_DARK, Enum.Material.Slate },
			{ 40, CYAN, Enum.Material.Neon },
			{ 38.6, STONE_DARK, Enum.Material.Slate },
			{ 23, GOLD_GLOW, Enum.Material.Neon },
			{ 21.6, STONE_DARK, Enum.Material.Slate },
		}
	do
		local p = flat(root, "Circle", r[1], 0.06, y + i * 0.02, r[2], r[3])
		p.CastShadow = false
	end
	local top = y + 0.16
	-- the hexagram: two triangles of light between the rings
	local R = 19
	local function pt(k: number): Vector3
		local a = math.rad(90 + k * 60)
		return C + Vector3.new(math.cos(a) * R, top, math.sin(a) * R)
	end
	for _, tri in { { 0, 2, 4 }, { 1, 3, 5 } } do
		for j = 1, 3 do
			local a, b = pt(tri[j]), pt(tri[j % 3 + 1])
			local bar = part(
				root,
				"Hexagram",
				Vector3.new(0.7, 0.06, (b - a).Magnitude),
				CFrame.lookAt((a + b) / 2, b),
				CYAN,
				Enum.Material.Neon
			)
			bar.CastShadow = false
		end
	end
	-- runes round the inner ring
	for k = 0, 11 do
		local a = math.rad(k * 30 + 15)
		local p = C + Vector3.new(math.cos(a) * 15.5, top, math.sin(a) * 15.5)
		part(
			root,
			"Rune",
			Vector3.new(1.6, 0.06, 1.6),
			CFrame.new(p) * CFrame.Angles(0, a + math.rad(45), 0),
			GOLD_GLOW,
			Enum.Material.Neon
		).CastShadow =
			false
	end
	-- motes drifting up off the circle
	local plate =
		part(root, "MoteSource", Vector3.new(36, 0.2, 36), CFrame.new(C.X, top + 0.3, C.Z), CYAN)
	plate.Transparency = 1
	sparks(plate, 10, NumberRange.new(3, 7), NumberRange.new(3, 5), 0.8, CYAN, GOLD_GLOW)
end

-- ---------------------------------------------------------------------------------- 3. the shrine
do
	local m = Instance.new("Model")
	m.Name = "SummonPavilion"
	local base = TOP + 1.6
	part(
		m,
		"Plinth",
		Vector3.new(16, 1.6, 16),
		CFrame.new(C.X, TOP + 0.8, C.Z),
		STONE,
		Enum.Material.Slate,
		true
	)
	part(m, "PlinthBand", Vector3.new(16.6, 0.4, 16.6), CFrame.new(C.X, base - 0.2, C.Z), GOLD)
	part(
		m,
		"Step",
		Vector3.new(8, 0.8, 2.4),
		CFrame.new(C.X, TOP + 0.4, C.Z + 9.2),
		STONE,
		Enum.Material.Slate,
		true
	)
	local ROOF_Y = base + 11
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local x, z = C.X + sx * 6.2, C.Z + sz * 6.2
			column(m, "Pillar", 1.7, base, ROOF_Y, x, z, RED)
			column(m, "PillarRing", 2, base, base + 0.6, x, z, GOLD)
			column(m, "PillarRing", 2, ROOF_Y - 2.2, ROOF_Y - 1.6, x, z, GOLD)
		end
	end
	-- lintels on all four sides
	for _, s in { -1, 1 } do
		part(
			m,
			"Lintel",
			Vector3.new(14.6, 1.1, 1.1),
			CFrame.new(C.X, ROOF_Y - 0.6, C.Z + s * 6.2),
			RED
		)
		part(
			m,
			"Lintel",
			Vector3.new(1.1, 1.1, 14.6),
			CFrame.new(C.X + s * 6.2, ROOF_Y - 0.6, C.Z),
			RED
		)
	end
	-- the roof: a black eave slab with a gold edge, a pyramid (hip) roof of four corner wedges,
	-- gold hips running down from the apex, flared gold corners, a gold finial
	part(m, "Eave", Vector3.new(20, 0.6, 20), CFrame.new(C.X, ROOF_Y + 0.3, C.Z), BLACK)
	part(m, "EaveEdge", Vector3.new(20.4, 0.3, 20.4), CFrame.new(C.X, ROOF_Y + 0.05, C.Z), GOLD)
	local A, RH = 9.6, 5.2 -- half the pyramid's base, its height
	local ry = ROOF_Y + 0.6
	-- a corner wedge peaks at its local (+X, -Z) corner: turn each so the peak meets the apex
	for _, q in { { 1, 1, 90 }, { -1, 1, 0 }, { 1, -1, 180 }, { -1, -1, -90 } } do
		local w = Instance.new("CornerWedgePart")
		w.Name = "Roof"
		w.Size = Vector3.new(A, RH, A)
		w.CFrame = CFrame.new(C.X + q[1] * A / 2, ry + RH / 2, C.Z + q[2] * A / 2)
			* CFrame.Angles(0, math.rad(q[3]), 0)
		w.Color = BLACK
		w.Material = Enum.Material.SmoothPlastic
		w.Anchored = true
		w.CanCollide = false
		w.CanQuery = false
		w.CanTouch = false
		w.Parent = m
	end
	local apex = Vector3.new(C.X, ry + RH, C.Z)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local foot = Vector3.new(C.X + sx * A, ry, C.Z + sz * A)
			part(
				m,
				"Hip",
				Vector3.new(0.5, 0.5, (apex - foot).Magnitude),
				CFrame.lookAt((apex + foot) / 2, apex),
				GOLD
			)
			local corner = CFrame.new(C.X + sx * 9.9, ROOF_Y + 0.9, C.Z + sz * 9.9)
				* CFrame.Angles(0, math.atan2(sx, sz), 0)
				* CFrame.Angles(math.rad(22), 0, 0)
			part(m, "Corner", Vector3.new(0.6, 0.45, 2.4), corner, GOLD)
		end
	end
	column(m, "Finial", 0.9, apex.Y - 0.4, apex.Y + 2.6, C.X, C.Z, GOLD)
	ball(m, "FinialOrb", 1.8, Vector3.new(C.X, apex.Y + 3, C.Z), GOLD)
	-- the summoning orb on its pedestal, ringed by two halos
	column(m, "Pedestal", 3, base, base + 3.6, C.X, C.Z, STONE, Enum.Material.Slate)
	column(m, "PedestalCap", 3.8, base + 3.6, base + 4.1, C.X, C.Z, GOLD)
	local orbAt = Vector3.new(C.X, base + 6.6, C.Z)
	local orb = ball(m, "SummonOrb", 3.4, orbAt, VIOLET, Enum.Material.Neon)
	light(orb, VIOLET, 22, 2.2)
	sparks(orb, 6, NumberRange.new(1, 3), NumberRange.new(1.5, 2.5), 0.5, VIOLET, CYAN)
	halo(
		m,
		CFrame.new(orbAt) * CFrame.Angles(math.rad(25), 0, math.rad(10)),
		6,
		18,
		0.25,
		GOLD_GLOW
	)
	halo(m, CFrame.new(orbAt) * CFrame.Angles(math.rad(-20), 0, math.rad(-30)), 7.2, 20, 0.25, CYAN)
	-- a third larger, about its foot: it sat small in the circle
	m.WorldPivot = CFrame.new(C.X, TOP, C.Z)
	m:ScaleTo(1.35)
	m.Parent = root
	-- the prompt's title floats over the new roof
	local title = anchor and anchor:FindFirstChild("Title")
	if title and title:IsA("BillboardGui") then
		title.StudsOffsetWorldSpace = Vector3.new(0, 28, 0)
	end
	-- the pavilion's plinth keeps players about 11 studs from the prompt's anchor: reach further
	local prompt = anchor and anchor:FindFirstChildWhichIsA("ProximityPrompt")
	if prompt then
		prompt.MaxActivationDistance = 16
	end
end

-- ---------------------------------------------------------------------------------- 4. pylons and fire
-- front pair either side of the spawn's approach, back pair clear of the dragon
for i, at in { { -26, -80 }, { 26, -80 }, { -36, -120 }, { 36, -120 } } do
	local x, z = at[1], at[2]
	local m = Instance.new("Model")
	m.Name = "Pylon"
	part(
		m,
		"PylonBase",
		Vector3.new(4.6, 1.4, 4.6),
		CFrame.new(x, G + 0.7, z),
		STONE,
		Enum.Material.Slate,
		true
	)
	part(
		m,
		"Pylon",
		Vector3.new(3, 12, 3),
		CFrame.new(x, G + 1.4 + 6, z),
		PYLON,
		Enum.Material.Slate,
		true
	)
	for _, y in { G + 4, G + 12 } do
		part(m, "PylonBand", Vector3.new(3.3, 0.5, 3.3), CFrame.new(x, y, z), GOLD)
	end
	part(m, "PylonCap", Vector3.new(4, 0.8, 4), CFrame.new(x, G + 13.8, z), BLACK)
	local color = if i % 2 == 0 then CYAN else GOLD_GLOW
	local orb = ball(m, "PylonOrb", 2.4, Vector3.new(x, G + 16.6, z), color, Enum.Material.Neon)
	light(orb, color, 16, 1.6)
	halo(m, CFrame.new(x, G + 16.6, z), 4, 12, 0.2, color)
	m.Parent = root
end
for _, s in { -1, 1 } do
	local b = place(root, KIT.Prop_store_Brazier, 1.4, CFrame.new(s * 38, G, -134))
	b.Name = "Brazier"
	local box, size = b:GetBoundingBox()
	local fire = part(
		root,
		"Flame",
		Vector3.new(4, 0.4, 4),
		CFrame.new(s * 38, box.Position.Y + size.Y / 2 - 0.6, -134),
		GOLD
	)
	fire.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/fire_main.dds"
	e.Rate = 48
	e.Speed = NumberRange.new(4, 8)
	e.Lifetime = NumberRange.new(0.8, 1.3)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 4.6),
		NumberSequenceKeypoint.new(1, 0.6),
	})
	e.EmissionDirection = Enum.NormalId.Top
	e.SpreadAngle = Vector2.new(12, 12)
	e.LightEmission = 0.9
	e.Color = ColorSequence.new(Color3.fromRGB(255, 200, 90), Color3.fromRGB(255, 80, 30))
	e.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = fire
	light(fire, Color3.fromRGB(255, 150, 70), 20, 2)
end

root.Parent = hub
local n = 0
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") then
		n += 1
	end
end
return string.format(
	"sanctuary: %d parts; prompt still on %s",
	n,
	anchor and anchor:GetFullName() or "nothing"
)
