-- build_demon_circle.luau - Studio EDIT mode, rerunnable:
--   python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file tools/studio/auras/build_demon_circle.luau
-- Builds ReplicatedStorage.Assets.Auras.DemonCircle: Anos Voldigoad's (tyrant_demon_lord) hero aura, hand-authored
-- with the roblox-vfx skill's authoring route. Every texture is our own (tools/auras/demon_circle/make_tex.py, ids in
-- assets/auras/demon_circle/ids.json; the crack is HawkEye's, the glint ButterflyDance's). Writes NOTHING else.
-- HeroAura.luau's template format: every CFrame in the hero ROOT's space at rest, R15, feet at y -3, faces -Z.
-- Anos: head centre y 1.5 (face at z -0.6), spiky hair to y 2.75, a white jacket, no cape.
--
-- The look (The Misfit of Demon King Academy): his power is MAGIC CIRCLES, layered rings of demon script and
-- geometry that stack and turn against each other, crimson-hot lines over black ink, and the Demon Eyes of
-- Destruction. No flames. Every circle is a self-lit SurfaceGui on a turning plate: a soft crimson glow, a black ink
-- copy of the lines a hair wider, the crimson-hot lines on top (reads on a lit pedestal, in daylight and at night).
--   ARRAY    three circles under him: runes (outer), a heptagram over a hexagram (middle), a crest with a demon eye
--            (inner), turning against each other
--   HALO     a large vertical array behind his shoulders, turning slowly (seen from the front and the back)
--   CASTING  a small spinning array beside each hand, as if he were mid-spell
--   EYES     the Demon Eyes of Destruction: crimson ring pupils over his eyes, pulsing
--   RUNES    single runes in a ring orbiting his chest, and runes lifting off the array and fading
--   SPARKS   short black cracks in a crimson halo at the array's edge; crimson motes; one crimson light

local RS = game:GetService("ReplicatedStorage")

local TEX = {
	outer = { core = 122624910345759, ink = 92765087881124, glow = 115946203562512 },
	mid = { core = 136846008548770, ink = 103322554300735, glow = 140372293050031 },
	inner = { core = 101622033638668, ink = 131626146659038, glow = 85576039673683 },
	halo = { core = 98022327712250, ink = 129657202894097, glow = 129965903157537 },
	cast = { core = 74422068560071, ink = 138958905453859, glow = 103129278896284 },
	glyphs = "rbxassetid://131866355667685",
	eye = "rbxassetid://102320513433921",
	bolt = "rbxassetid://136960814808642",
	glint = "rbxassetid://94471435227120",
}

local KEY = "DemonCircle"
local FEET = -3.0
local HOT = Color3.fromRGB(255, 58, 48)
local GLOW = Color3.fromRGB(220, 20, 30)
local INK = Color3.fromRGB(8, 3, 5)

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local function NS(points)
	local kps = {}
	for _, p in points do
		table.insert(kps, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0))
	end
	return NumberSequence.new(kps)
end
local function CS(points)
	local kps = {}
	for _, p in points do
		table.insert(kps, ColorSequenceKeypoint.new(p[1], p[2]))
	end
	return ColorSequence.new(kps)
end

local live = 0
local function emitter(parent: Instance, name: string, props: { [string]: any })
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.LightInfluence = 0
	e.LockedToPart = false
	for k, v in props do
		(e :: any)[k] = v
	end
	live += e.Rate * (e.Lifetime.Min + e.Lifetime.Max) / 2
	e.Parent = parent
	return e
end

local function att(parent: Instance, name: string, cf: CFrame, rootSpace: boolean)
	local a = Instance.new("Attachment")
	a.Name = name
	a.CFrame = cf
	if rootSpace then
		a:SetAttribute("RS", true)
	end
	a.Parent = parent
	return a
end

local function carrier(
	parent: Instance,
	name: string,
	size: Vector3,
	rootCf: CFrame,
	spin: Vector3?
)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.CFrame = rootCf
	p:SetAttribute("RootCF", rootCf)
	if spin then
		p:SetAttribute("Spin", spin)
	end
	p.Parent = parent
	return p
end

local folder = Instance.new("Folder")
folder.Name = KEY
local function group(name: string): Instance
	local g = folder:FindFirstChild(name)
	if not g then
		g = Instance.new("Folder")
		g.Name = name
		g.Parent = folder
	end
	return g
end

-- a magic circle on one face of a plate: glow under, black ink, crimson-hot lines on top
local function circleGui(
	plate: BasePart,
	face: Enum.NormalId,
	set,
	pxPerStud: number,
	strength: number
)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Circle" .. face.Name
	gui.Face = face
	gui.LightInfluence = 0
	gui.Brightness = 1.6
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pxPerStud
	gui.Parent = plate
	local function layer(name, id, colour, transparency, scale, z)
		local l = Instance.new("ImageLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5, 0.5)
		l.Size = UDim2.fromScale(scale, scale)
		l.Image = "rbxassetid://" .. id
		l.ImageColor3 = colour
		l.ImageTransparency = transparency
		l.ZIndex = z
		l.Parent = gui
	end
	layer("Glow", set.glow, GLOW, 1 - 0.32 * strength, 1.0, 1) -- low: on a lit pedestal a strong glow floods the disc red
	layer("Ink", set.ink, INK, 1 - 0.95 * strength, 1.0, 2)
	layer("Core", set.core, HOT, 1 - 1.0 * strength, 1.0, 3)
	return gui
end

local rootG = group("HumanoidRootPart")

-- ARRAY: three circles under his feet, turning against each other
do
	local rings = {
		{ "OuterCircle", TEX.outer, 7.6, 0.05, 0.18 },
		{ "MidCircle", TEX.mid, 5.8, 0.08, -0.32 },
		{ "InnerCircle", TEX.inner, 3.6, 0.11, 0.6 },
	}
	for _, r in rings do
		local plate = carrier(
			rootG,
			r[1],
			Vector3.new(r[3], 0.05, r[3]),
			CFrame.new(0, FEET + r[4], 0),
			Vector3.new(0, r[5], 0)
		)
		circleGui(plate, Enum.NormalId.Top, r[2], 1024 / r[3], 1)
	end
end

-- HALO: a vertical array behind his shoulders (the plate's Front face looks forward at the viewer)
do
	local plate = carrier(
		rootG,
		"HaloCircle",
		Vector3.new(4.8, 4.8, 0.05),
		CFrame.new(0, 0.95, 1.25),
		Vector3.new(0, 0, 0.15)
	)
	circleGui(plate, Enum.NormalId.Front, TEX.halo, 1024 / 4.8, 0.8)
	circleGui(plate, Enum.NormalId.Back, TEX.halo, 1024 / 4.8, 0.8)
end

-- CASTING: a small array beside each hand, angled out toward the viewer, spinning
do
	for _, side in { -1, 1 } do
		local cf = CFrame.new(2.4 * side, -0.65, -0.25) * CFrame.Angles(0, math.rad(-32 * side), 0)
		local plate = carrier(
			rootG,
			if side < 0 then "CastLeft" else "CastRight",
			Vector3.new(1.5, 1.5, 0.05),
			cf,
			Vector3.new(0, 0, 1.3 * side)
		)
		circleGui(plate, Enum.NormalId.Front, TEX.cast, 512 / 1.5, 0.95)
		circleGui(plate, Enum.NormalId.Back, TEX.cast, 512 / 1.5, 0.95)
	end
end

-- EYES: the Demon Eyes of Destruction
do
	local head = group("Head")
	for _, x in { -0.2, 0.2 } do
		local a = att(head, "DemonEye", CFrame.new(x, 1.55, -0.64), true)
		emitter(a, "DestructionEye", {
			Texture = TEX.eye,
			Rate = 2,
			Lifetime = NumberRange.new(0.7, 0.7),
			Speed = NumberRange.new(0, 0),
			Size = NS({ { 0, 0.12 }, { 0.5, 0.17 }, { 1, 0.12 } }),
			Transparency = NS({ { 0, 0.55 }, { 0.5, 0 }, { 1, 0.55 } }),
			RotSpeed = NumberRange.new(60, 90),
			LightEmission = 1,
			Brightness = 2.6,
			Color = CS({ { 0, rgb(255, 90, 70) }, { 1, rgb(255, 40, 40) } }),
			ZOffset = 0.7,
			LockedToPart = true,
		})
	end
end

-- RUNES: a ring of single runes orbiting his chest, and runes lifting off the array
local function runeProps(rate, life, size, extra)
	local p = {
		Texture = TEX.glyphs,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.Loop,
		FlipbookFramerate = NumberRange.new(0.01, 0.01), -- a random rune per particle, held
		FlipbookStartRandom = true,
		Rate = rate,
		Lifetime = life,
		Speed = NumberRange.new(0, 0),
		Size = NS({
			{ 0, 0 },
			{ 0.15, size, size * 0.1 },
			{ 0.8, size, size * 0.1 },
			{ 1, size * 0.6 },
		}),
		Transparency = NS({ { 0, 1 }, { 0.15, 0.05 }, { 0.75, 0.1 }, { 1, 1 } }),
		LightEmission = 0.8,
		Brightness = 1.8,
		Color = CS({ { 0, rgb(255, 120, 90) }, { 1, rgb(230, 30, 40) } }),
	}
	for k, v in extra or {} do
		p[k] = v
	end
	return p
end
do
	local ring = carrier(
		rootG,
		"RuneRing",
		Vector3.new(0.2, 0.2, 0.2),
		CFrame.new(0, 0.25, 0),
		Vector3.new(0, -0.45, 0)
	)
	for i = 1, 12 do
		local a = 2 * math.pi * (i - 1) / 12
		local at =
			att(ring, "Rune" .. i, CFrame.new(math.cos(a) * 2.35, 0, math.sin(a) * 2.35), false)
		emitter(
			at,
			"OrbitRune",
			runeProps(0.55, NumberRange.new(1.8, 2.2), 0.2, { LockedToPart = true })
		)
	end
	local disc =
		carrier(rootG, "RuneLift", Vector3.new(7, 0.2, 7), CFrame.new(0, FEET + 0.2, 0), nil)
	emitter(
		disc,
		"RisingRune",
		runeProps(4, NumberRange.new(1.6, 2.4), 0.2, {
			Shape = Enum.ParticleEmitterShape.Disc,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			EmissionDirection = Enum.NormalId.Top,
			Speed = NumberRange.new(0.6, 1.1),
			Drag = 0.4,
		})
	)
end

-- SPARKS: destruction cracks at the array's edge, crimson motes, a crimson light
do
	local edge =
		carrier(rootG, "ArrayEdge", Vector3.new(7.2, 0.2, 7.2), CFrame.new(0, FEET + 0.4, 0), nil)
	emitter(edge, "DestructionSparks", {
		Texture = TEX.bolt,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Shape = Enum.ParticleEmitterShape.Disc,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		EmissionDirection = Enum.NormalId.Top,
		Rate = 3,
		Lifetime = NumberRange.new(0.22, 0.3),
		Speed = NumberRange.new(0, 0),
		Size = NS({ { 0, 0.55, 0.15 }, { 1, 0.65, 0.15 } }),
		Rotation = NumberRange.new(0, 360),
		LightEmission = 0.2,
		Brightness = 1.4,
		Color = CS({ { 0, rgb(255, 255, 255) }, { 1, rgb(255, 255, 255) } }),
		ZOffset = 0.2,
	})
	local box = carrier(rootG, "Motes", Vector3.new(5, 6, 5), CFrame.new(0, -0.2, 0), nil)
	emitter(box, "MagicMotes", {
		Texture = TEX.glint,
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Rate = 8,
		Lifetime = NumberRange.new(0.8, 1.3),
		Speed = NumberRange.new(0.2, 0.5),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(25, 25),
		Acceleration = Vector3.new(0, 0.7, 0),
		Size = NS({ { 0, 0 }, { 0.25, 0.15, 0.04 }, { 1, 0 } }),
		Transparency = NS({ { 0, 0 }, { 1, 0.3 } }),
		Rotation = NumberRange.new(0, 90),
		LightEmission = 1,
		Brightness = 1.6,
		Color = CS({ { 0, rgb(255, 150, 120) }, { 1, rgb(220, 20, 40) } }),
	})
	local chest = att(group("UpperTorso"), "Light", CFrame.new(0, 0.2, 0), true)
	local l = Instance.new("PointLight")
	l.Name = "Crimson"
	l.Color = rgb(255, 60, 60)
	l.Brightness = 1.1
	l.Range = 9
	l.Shadows = false
	l.Parent = chest
end

local assets = RS:WaitForChild("Assets")
local dest = assets:FindFirstChild("Auras")
assert(dest, "ReplicatedStorage.Assets.Auras missing")
folder:SetAttribute("K", 1)
folder:SetAttribute("Tier", "E")
folder:SetAttribute("Live", math.floor(live + 0.5))
folder:SetAttribute("Source", "custom: tools/studio/auras/build_demon_circle.luau")
local old = dest:FindFirstChild(KEY)
if old then
	old:Destroy()
end
folder.Parent = dest
return `{KEY} built: live ~{math.floor(live + 0.5)} particles`
