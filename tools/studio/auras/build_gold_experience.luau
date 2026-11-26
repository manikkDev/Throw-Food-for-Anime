-- build_gold_experience.luau - Studio EDIT mode, rerunnable:
--   python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file tools/studio/auras/build_gold_experience.luau
-- Builds ReplicatedStorage.Assets.Auras.GoldExperience: Giorno's (gold_gang_boss) hero aura, hand-authored with the
-- roblox-vfx skill's authoring route. Every texture is our own (tools/auras/gold_experience/make_tex.py, ids in
-- assets/auras/gold_experience/ids.json; the upright ribbon and the glint are ButterflyDance's). Writes NOTHING else.
-- HeroAura.luau's template format: every CFrame in the hero ROOT's space at rest, R15, feet at y -3, faces -Z.
-- Legendary (tier D): the furthest piece stays inside 6.5 studs.
--
-- The look (JoJo Part 5, "Golden Wind"): Gold Experience gives LIFE; its emblem is the ladybug (his brooches); the
-- part is the golden wind. Gold, his suit's magenta (the ink), leaf green, petal pink. No flames, no stand figure,
-- no menacing text (owner: no stands; the Jotaro aura owns the menacing look).
--   CREST    a gold ring wreathed in a vine, three ladybug emblems, a golden-wind spiral at its heart, turning slowly
--   LIFE     flowers sprouting round him: stems grow, leaves unfurl, buds open pink and gold, petals fall
--   LADYBUGS golden ladybugs with buzzing wings flying up from a turning ring
--   WIND     gold light ribbons sweeping round him at three heights (the golden wind)
--   PETALS   pink petals drifting; gold motes rising; one warm gold light

local RS = game:GetService("ReplicatedStorage")

local TEX = {
	crest = { core = 105743309124242, ink = 134667103975483, glow = 125404460036031 },
	flower = "rbxassetid://91923096735497",
	ladybug = "rbxassetid://134036155041799",
	petal = "rbxassetid://92188242869894",
	ribbon = "rbxassetid://80339304571346",
	glint = "rbxassetid://94471435227120",
}

local KEY = "GoldExperience"
local FEET = -3.0
local GOLD = Color3.fromRGB(255, 208, 72)
local GOLD_GLOW = Color3.fromRGB(255, 160, 30)
local INK = Color3.fromRGB(40, 8, 36)
local WHITE = ColorSequence.new(Color3.new(1, 1, 1))

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

local rootG = group("HumanoidRootPart")

-- CREST
do
	local plate = carrier(
		rootG,
		"Crest",
		Vector3.new(8.2, 0.05, 8.2),
		CFrame.new(0, FEET + 0.05, 0),
		Vector3.new(0, 0.06, 0)
	)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Crest"
	gui.Face = Enum.NormalId.Top
	gui.LightInfluence = 0
	gui.Brightness = 2.2
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 1024 / 8.2
	gui.Parent = plate
	local function layer(name, id, colour, transparency, z)
		local l = Instance.new("ImageLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5, 0.5)
		l.Size = UDim2.fromScale(1, 1)
		l.Image = "rbxassetid://" .. id
		l.ImageColor3 = colour
		l.ImageTransparency = transparency
		l.ZIndex = z
		l.Parent = gui
	end
	layer("Glow", TEX.crest.glow, GOLD_GLOW, 0.7, 1) -- low: on a yellow pedestal the glow floods the disc
	layer("Ink", TEX.crest.ink, INK, 0.05, 2)
	layer("Core", TEX.crest.core, GOLD, 0, 3)
end

-- LIFE: flowers sprouting round him (the texture's ground line sits 0.84 x Size below the particle's centre)
do
	local size = 1.0
	local ring = carrier(
		rootG,
		"Garden",
		Vector3.new(0.2, 0.2, 0.2),
		CFrame.new(0, FEET + 0.84 * size, 0),
		nil
	)
	for i = 1, 12 do
		local a = math.rad(i * 30 + (if i % 2 == 0 then 8 else -6))
		local r = if i % 2 == 0 then 3.35 else 2.8
		local at = att(ring, "Sprout" .. i, CFrame.new(math.cos(a) * r, 0, math.sin(a) * r), false)
		emitter(at, "LifeFlower", {
			Texture = TEX.flower,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
			FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
			Rate = 0.3,
			Lifetime = NumberRange.new(2.8, 3.4),
			Speed = NumberRange.new(0, 0),
			Size = NS({ { 0, size, 0.08 }, { 1, size, 0.08 } }),
			LightEmission = 0.05,
			LightInfluence = 0.2,
			Brightness = 1.2,
			Color = WHITE,
			LockedToPart = true,
		})
	end
end

-- LADYBUGS: released from a turning ring, flying up and away
do
	local ring = carrier(
		rootG,
		"Ladybugs",
		Vector3.new(0.2, 0.2, 0.2),
		CFrame.new(0, -0.3, 0),
		Vector3.new(0, 0.9, 0)
	)
	local spots = { { 0, 2.3, -1.6 }, { 90, 2.5, -0.2 }, { 180, 2.2, 1.0 }, { 270, 2.4, 2.0 } }
	for i, s in spots do
		local a = math.rad(s[1])
		local at = att(
			ring,
			"Ladybug" .. i,
			CFrame.new(math.cos(a) * s[2], s[3], math.sin(a) * s[2]),
			false
		)
		emitter(at, "GoldenLadybug", {
			Texture = TEX.ladybug,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
			FlipbookMode = Enum.ParticleFlipbookMode.Loop,
			FlipbookFramerate = NumberRange.new(24, 32),
			FlipbookStartRandom = true,
			Rate = 1.2,
			Lifetime = NumberRange.new(2.4, 3.2),
			Speed = NumberRange.new(0.3, 0.7),
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(60, 60),
			Acceleration = Vector3.new(0, 0.35, 0),
			Drag = 0.5,
			Size = NS({ { 0, 0 }, { 0.1, 0.42, 0.05 }, { 0.8, 0.4, 0.05 }, { 1, 0.18 } }),
			Transparency = NS({ { 0, 1 }, { 0.1, 0 }, { 0.8, 0 }, { 1, 1 } }),
			Rotation = NumberRange.new(-30, 30),
			RotSpeed = NumberRange.new(-40, 40),
			LightEmission = 0.2,
			Brightness = 1.4,
			Color = WHITE,
		})
	end
end

-- WIND: gold ribbons sweeping round him (upright strip: Roblox runs a trail texture's vertical axis along it)
do
	local heights = { { -1.9, 2.6, 1.6 }, { 0.1, 2.85, -1.3 }, { 1.9, 2.5, 1.9 } }
	for i, h in heights do
		local ring = carrier(
			rootG,
			"Wind" .. i,
			Vector3.new(0.2, 0.2, 0.2),
			CFrame.new(0, h[1], 0),
			Vector3.new(0, h[3], 0)
		)
		local hi = att(ring, "WindHi", CFrame.new(h[2], 0.24, 0), false)
		local lo = att(ring, "WindLo", CFrame.new(h[2], -0.24, 0), false)
		local t = Instance.new("Trail")
		t.Name = "GoldenWind"
		t.Attachment0 = hi
		t.Attachment1 = lo
		t.Texture = TEX.ribbon
		t.TextureMode = Enum.TextureMode.Stretch
		t.FaceCamera = true
		t.Lifetime = 1.1
		t.MinLength = 0.05
		t.LightEmission = 0.7
		t.LightInfluence = 0
		t.Brightness = 1.8
		t.WidthScale = NS({ { 0, 1 }, { 0.6, 0.5 }, { 1, 0 } })
		t.Transparency = NS({ { 0, 0.1 }, { 0.5, 0.35 }, { 1, 1 } })
		t.Color = CS({ { 0, rgb(255, 244, 200) }, { 0.35, GOLD }, { 1, rgb(230, 120, 30) } })
		t.Parent = ring
	end
end

-- PETALS, MOTES, LIGHT
do
	local box = carrier(rootG, "Air", Vector3.new(5.2, 5.6, 5.2), CFrame.new(0, -0.2, 0), nil)
	emitter(box, "Petals", {
		Texture = TEX.petal,
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Rate = 6,
		Lifetime = NumberRange.new(2.2, 3.0),
		Speed = NumberRange.new(0.3, 0.7),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0.3, -0.35, 0.2),
		Drag = 0.8,
		Size = NS({ { 0, 0.17, 0.04 }, { 1, 0.17, 0.04 } }),
		Transparency = NS({ { 0, 1 }, { 0.1, 0 }, { 0.8, 0 }, { 1, 1 } }),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-120, 120),
		LightEmission = 0.1,
		LightInfluence = 0.3,
		Brightness = 1.3,
		Color = WHITE,
	})
	emitter(box, "LifeMotes", {
		Texture = TEX.glint,
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Rate = 6,
		Lifetime = NumberRange.new(0.6, 1.0),
		Speed = NumberRange.new(0.3, 0.6),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(25, 25),
		Acceleration = Vector3.new(0, 0.6, 0),
		Size = NS({ { 0, 0 }, { 0.3, 0.17, 0.05 }, { 1, 0 } }),
		Rotation = NumberRange.new(0, 90),
		LightEmission = 1,
		Brightness = 1.8,
		Color = CS({ { 0, rgb(255, 245, 180) }, { 1, GOLD } }),
	})
	local chest = att(group("UpperTorso"), "Light", CFrame.new(0, 0.2, 0), true)
	local l = Instance.new("PointLight")
	l.Name = "Gold"
	l.Color = rgb(255, 210, 110)
	l.Brightness = 1
	l.Range = 9
	l.Shadows = false
	l.Parent = chest
end

local assets = RS:WaitForChild("Assets")
local dest = assets:FindFirstChild("Auras")
assert(dest, "ReplicatedStorage.Assets.Auras missing")
folder:SetAttribute("K", 1)
folder:SetAttribute("Tier", "D")
folder:SetAttribute("Live", math.floor(live + 0.5))
folder:SetAttribute("Source", "custom: tools/studio/auras/build_gold_experience.luau")
local old = dest:FindFirstChild(KEY)
if old then
	old:Destroy()
end
folder.Parent = dest
return `{KEY} built: live ~{math.floor(live + 0.5)} particles`
