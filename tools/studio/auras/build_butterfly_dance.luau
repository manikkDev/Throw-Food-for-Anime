-- build_butterfly_dance.luau - Studio EDIT mode, rerunnable:
--   python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file tools/studio/auras/build_butterfly_dance.luau
-- Builds ReplicatedStorage.Assets.Auras.ButterflyDance: Shinobu Kocho's (butterfly_swordswoman) hero aura,
-- hand-authored with the roblox-vfx skill's authoring route. Every texture is our own
-- (tools/auras/butterfly_dance/make_tex.py, ids in assets/auras/butterfly_dance/ids.json).
-- Writes NOTHING else. Layout is HeroAura.luau's template format (every CFrame in the hero ROOT's
-- space at rest, R15, feet at y -3, the hero faces -Z):
--   <BodyPart>/<Attachment RS=true>/<emitter|light>   rides that body part
--   HumanoidRootPart/<Part RootCF, Spin>/...          welded to the root, turned while live
--
-- The look (Insect Breathing; the key art: violet light, cyan glints, glass-like wing shards):
--   SIGIL     a stained-glass butterfly sigil under her feet, turning slowly (SurfaceGui, self-lit)
--   SWARM     spirit butterflies released round her on a turning ring: they spiral up and fade
--   HAORI     a few white-and-black butterflies in her haori's pattern drifting off her back
--   MANTLE    violet flame tongues rising round her legs, a few cyan ones among them
--   BACKLIGHT a violet halo pushed behind her silhouette
--   SCALES    cyan and lilac wing-scale glints and turning glass shards in the air round her
--   LIGHT     one violet point light (no shadows)

local RS = game:GetService("ReplicatedStorage")

local TEX = {
	spirit = "rbxassetid://94046598968824",
	haori = "rbxassetid://134142611044610",
	sigil = "rbxassetid://71843741887857",
	glow = "rbxassetid://114990150725293",
	wisp = "rbxassetid://105910302884912",
	glint = "rbxassetid://94471435227120",
	shard = "rbxassetid://88218407121003",
	ribbon = "rbxassetid://80339304571346",
}

local KEY = "ButterflyDance"
local FEET = -3.0

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

-- ------------------------------------------------------------------------------------------------
local assets = RS:WaitForChild("Assets")
local dest = assets:FindFirstChild("Auras")
assert(dest, "ReplicatedStorage.Assets.Auras missing")
local folder = Instance.new("Folder")
folder.Name = KEY
local rootG = Instance.new("Folder")
rootG.Name = "HumanoidRootPart"
rootG.Parent = folder
local torsoG = Instance.new("Folder")
torsoG.Name = "UpperTorso"
torsoG.Parent = folder

-- SIGIL: a SurfaceGui on a thin turning plate just above the feet (self-lit, no particle overlap)
do
	local plate = carrier(
		rootG,
		"Sigil",
		Vector3.new(6.4, 0.05, 6.4),
		CFrame.new(0, FEET + 0.07, 0),
		Vector3.new(0, 0.35, 0)
	)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SigilGui"
	gui.Face = Enum.NormalId.Top
	gui.LightInfluence = 0
	gui.Brightness = 1.15
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 80
	gui.ClipsDescendants = false
	gui.Parent = plate
	local pool = Instance.new("ImageLabel")
	pool.Name = "Pool"
	pool.BackgroundTransparency = 1
	pool.AnchorPoint = Vector2.new(0.5, 0.5)
	pool.Position = UDim2.fromScale(0.5, 0.5)
	pool.Size = UDim2.fromScale(1.05, 1.05)
	pool.Image = TEX.glow
	pool.ImageColor3 = rgb(118, 56, 240)
	pool.ImageTransparency = 0.5
	pool.ZIndex = 1
	pool.Parent = gui
	-- the dark copy under the bright lines, a hair larger: an ink outline that holds on a lit pedestal and in daylight
	local ink = Instance.new("ImageLabel")
	ink.Name = "Ink"
	ink.BackgroundTransparency = 1
	ink.AnchorPoint = Vector2.new(0.5, 0.5)
	ink.Position = UDim2.fromScale(0.5, 0.5)
	ink.Size = UDim2.fromScale(1.018, 1.018)
	ink.Image = TEX.sigil
	ink.ImageColor3 = rgb(34, 8, 78)
	ink.ImageTransparency = 0.05
	ink.ZIndex = 2
	ink.Parent = gui
	local ring = Instance.new("ImageLabel")
	ring.Name = "Ring"
	ring.BackgroundTransparency = 1
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromScale(1, 1)
	ring.Image = TEX.sigil
	ring.ImageColor3 = rgb(150, 72, 255)
	ring.ImageTransparency = 0
	ring.ZIndex = 3
	ring.Parent = gui
end

-- SWARM: three release points on a ring turning about the root; the butterflies stay in the world
do
	local ring = carrier(
		rootG,
		"Swarm",
		Vector3.new(0.2, 0.2, 0.2),
		CFrame.new(0, -0.4, 0),
		Vector3.new(0, 1.05, 0)
	)
	local spots = {
		{ ang = 0, r = 2.35, y = -1.9 },
		{ ang = 90, r = 2.55, y = -0.6 },
		{ ang = 180, r = 2.4, y = 0.7 },
		{ ang = 270, r = 2.1, y = 1.9 },
	}
	for i, s in spots do
		local a = math.rad(s.ang)
		local at =
			att(ring, "Spot" .. i, CFrame.new(math.cos(a) * s.r, s.y, math.sin(a) * s.r), false)
		emitter(at, "Butterflies", {
			Texture = TEX.spirit,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
			FlipbookMode = Enum.ParticleFlipbookMode.Loop,
			FlipbookFramerate = NumberRange.new(16, 24),
			FlipbookStartRandom = true,
			Rate = 2.0,
			Lifetime = NumberRange.new(2.2, 3.0),
			Speed = NumberRange.new(0.35, 0.9),
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(55, 55),
			Acceleration = Vector3.new(0, 0.55, 0),
			Drag = 0.45,
			Size = NS({ { 0, 0 }, { 0.1, 0.5, 0.07 }, { 0.75, 0.47, 0.07 }, { 1, 0.22 } }),
			Transparency = NS({ { 0, 1 }, { 0.1, 0 }, { 0.7, 0.05 }, { 1, 1 } }),
			Rotation = NumberRange.new(-18, 18),
			RotSpeed = NumberRange.new(-14, 14),
			LightEmission = 0.25,
			Brightness = 1.5,
			Color = CS({ { 0, rgb(255, 255, 255) }, { 1, rgb(214, 232, 255) } }),
			ZOffset = 0.3,
		})
		-- the comet trail of wing scales they shed along the ring
		emitter(at, "Trail", {
			Texture = TEX.glint,
			Rate = 7,
			Lifetime = NumberRange.new(0.6, 1.1),
			Speed = NumberRange.new(0.05, 0.25),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, 0.35, 0),
			Size = NS({ { 0, 0 }, { 0.2, 0.2, 0.05 }, { 1, 0 } }),
			Transparency = NS({ { 0, 0 }, { 0.7, 0.2 }, { 1, 1 } }),
			Rotation = NumberRange.new(0, 90),
			LightEmission = 1,
			Brightness = 1.6,
			Color = CS({
				{ 0, rgb(205, 246, 255) },
				{ 0.5, rgb(150, 215, 255) },
				{ 1, rgb(176, 130, 255) },
			}),
		})
		-- the flowing ribbon of light (key art 2): a tapered trail riding this spot round her, two of the four
		if i == 1 or i == 3 then
			local hi = att(
				ring,
				"RibbonHi" .. i,
				CFrame.new(math.cos(a) * (s.r + 0.25), s.y + 0.22, math.sin(a) * (s.r + 0.25)),
				false
			)
			local lo = att(
				ring,
				"RibbonLo" .. i,
				CFrame.new(math.cos(a) * (s.r + 0.25), s.y - 0.22, math.sin(a) * (s.r + 0.25)),
				false
			)
			local t = Instance.new("Trail")
			t.Name = "Ribbon"
			t.Attachment0 = hi
			t.Attachment1 = lo
			t.Texture = TEX.ribbon
			t.TextureMode = Enum.TextureMode.Stretch
			t.FaceCamera = true
			t.Lifetime = 1.15
			t.MinLength = 0.05
			t.LightEmission = 0.6
			t.LightInfluence = 0
			t.Brightness = 1.6
			t.WidthScale = NS({ { 0, 1 }, { 0.6, 0.55 }, { 1, 0 } })
			t.Transparency = NS({ { 0, 0.1 }, { 0.5, 0.35 }, { 1, 1 } })
			t.Color = if i == 1
				then CS({
					{ 0, rgb(236, 214, 255) },
					{ 0.3, rgb(170, 100, 255) },
					{ 1, rgb(96, 44, 220) },
				})
				else CS({
					{ 0, rgb(220, 250, 255) },
					{ 0.3, rgb(96, 210, 255) },
					{ 1, rgb(140, 100, 255) },
				})
			t.Parent = ring
		end
	end
end

-- HAORI: her pattern, drifting off her back and rising
do
	local back = att(torsoG, "HaoriBack", CFrame.new(0, 0.45, 0.6), true)
	emitter(back, "HaoriButterflies", {
		Texture = TEX.haori,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.Loop,
		FlipbookFramerate = NumberRange.new(12, 17),
		FlipbookStartRandom = true,
		Rate = 1.0,
		Lifetime = NumberRange.new(3.2, 4.2),
		Speed = NumberRange.new(1.0, 1.7),
		EmissionDirection = Enum.NormalId.Back,
		SpreadAngle = Vector2.new(65, 40),
		Acceleration = Vector3.new(0, 0.42, 0),
		Drag = 0.75,
		Size = NS({ { 0, 0 }, { 0.08, 0.46, 0.05 }, { 0.8, 0.44, 0.05 }, { 1, 0.25 } }),
		Transparency = NS({ { 0, 1 }, { 0.08, 0 }, { 0.75, 0 }, { 1, 1 } }),
		Rotation = NumberRange.new(-25, 25),
		RotSpeed = NumberRange.new(-20, 20),
		LightEmission = 0.12,
		LightInfluence = 0.15,
		Brightness = 1.1,
		Color = CS({ { 0, rgb(255, 255, 255) }, { 1, rgb(255, 255, 255) } }),
	})
end

-- MANTLE: flame tongues from a disc round her legs
do
	-- eight points on a slowly turning ring at the edge of her silhouette (not a filled disc: tongues born in
	-- front of her covered her body). ZOffset pushes them back in depth, so the ones in front of her legs draw
	-- BEHIND her and the flames frame her outline instead of hiding her.
	local ring = carrier(
		rootG,
		"Mantle",
		Vector3.new(0.2, 0.2, 0.2),
		CFrame.new(0, FEET + 0.3, 0),
		Vector3.new(0, 0.7, 0)
	)
	local common = {
		Texture = TEX.wisp,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(9, 9),
		Speed = NumberRange.new(2.0, 3.0),
		Acceleration = Vector3.new(0, 2.8, 0),
		Drag = 0.6,
		Rotation = NumberRange.new(-10, 10),
		LightEmission = 0.3,
	}
	local violet = table.clone(common)
	violet.Rate = 3.6
	violet.Lifetime = NumberRange.new(0.9, 1.3)
	violet.Size = NS({ { 0, 1.25, 0.12 }, { 0.5, 1.7, 0.15 }, { 1, 1.9, 0.12 } })
	violet.Transparency = NS({ { 0, 0.12 }, { 0.5, 0.05 }, { 1, 1 } })
	violet.Brightness = 1.4
	violet.Color =
		CS({ { 0, rgb(226, 196, 255) }, { 0.3, rgb(160, 92, 255) }, { 1, rgb(86, 40, 200) } })
	violet.ZOffset = -2.4
	local cyan = table.clone(common)
	cyan.Rate = 1
	cyan.Lifetime = NumberRange.new(0.8, 1.1)
	cyan.Size = NS({ { 0, 0.8, 0.1 }, { 0.5, 1.1, 0.12 }, { 1, 1.2 } })
	cyan.Transparency = NS({ { 0, 0.15 }, { 0.5, 0.1 }, { 1, 1 } })
	cyan.Brightness = 1.3
	cyan.Color =
		CS({ { 0, rgb(206, 246, 255) }, { 0.4, rgb(84, 200, 255) }, { 1, rgb(110, 96, 240) } })
	cyan.ZOffset = -2.3
	-- the dark copy under the bright strokes: deep indigo, not additive, so they hold on grass and sky
	local shade = table.clone(common)
	shade.Rate = 0.8
	shade.Lifetime = NumberRange.new(1.0, 1.3)
	shade.Size = NS({ { 0, 1.2, 0.1 }, { 0.5, 1.6, 0.12 }, { 1, 1.7 } })
	shade.Transparency = NS({ { 0, 0.45 }, { 0.5, 0.4 }, { 1, 1 } })
	shade.LightEmission = 0
	shade.Brightness = 1
	shade.Color = CS({ { 0, rgb(92, 44, 186) }, { 1, rgb(52, 22, 120) } })
	shade.ZOffset = -2.8
	for i = 1, 8 do
		local a = (i - 1) * math.pi / 4 + (if i % 2 == 0 then 0.2 else 0)
		local r = if i % 2 == 0 then 2.2 else 1.95
		local at = att(ring, "Root" .. i, CFrame.new(math.cos(a) * r, 0, math.sin(a) * r), false)
		emitter(at, "Tongues", violet)
		emitter(at, "CyanTongues", cyan)
		emitter(at, "ShadeTongues", shade)
	end
end

-- BACKLIGHT: a violet halo pushed behind her
do
	local core = att(rootG, "Backlight", CFrame.new(0, 0.1, 0), true)
	emitter(core, "Halo", {
		Texture = TEX.glow,
		Rate = 1.6,
		Lifetime = NumberRange.new(1.6, 1.6),
		Speed = NumberRange.new(0, 0),
		Size = NS({ { 0, 2.7 }, { 0.5, 3.0 }, { 1, 2.7 } }),
		Transparency = NS({ { 0, 1 }, { 0.3, 0.42 }, { 0.7, 0.42 }, { 1, 1 } }),
		LightEmission = 0.35,
		Brightness = 1.2,
		Color = CS({ { 0, rgb(150, 92, 255) }, { 1, rgb(120, 110, 255) } }),
		ZOffset = -2.5,
		LockedToPart = true,
	})
end

-- SCALES: glints and glass shards in a box round her
do
	local box = carrier(rootG, "Scales", Vector3.new(4.6, 5.4, 4.6), CFrame.new(0, -0.3, 0), nil)
	emitter(box, "CyanGlints", {
		Texture = TEX.glint,
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Rate = 10,
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(0.1, 0.3),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 0.4, 0),
		Size = NS({ { 0, 0 }, { 0.3, 0.26, 0.06 }, { 1, 0 } }),
		Transparency = NS({ { 0, 0 }, { 1, 0.3 } }),
		Rotation = NumberRange.new(0, 90),
		LightEmission = 1,
		Brightness = 1.8,
		Color = CS({ { 0, rgb(214, 248, 255) }, { 1, rgb(120, 214, 255) } }),
	})
	emitter(box, "LilacGlints", {
		Texture = TEX.glint,
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Rate = 6,
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(0.1, 0.3),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 0.4, 0),
		Size = NS({ { 0, 0 }, { 0.3, 0.23, 0.05 }, { 1, 0 } }),
		Transparency = NS({ { 0, 0 }, { 1, 0.3 } }),
		Rotation = NumberRange.new(0, 90),
		LightEmission = 1,
		Brightness = 1.6,
		Color = CS({ { 0, rgb(236, 214, 255) }, { 1, rgb(176, 120, 255) } }),
	})
	emitter(box, "Shards", {
		Texture = TEX.shard,
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Rate = 6,
		Lifetime = NumberRange.new(1.6, 2.4),
		Speed = NumberRange.new(0.4, 0.9),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 0.3, 0),
		Drag = 0.5,
		Size = NS({ { 0, 0 }, { 0.12, 0.26, 0.05 }, { 0.8, 0.24, 0.05 }, { 1, 0 } }),
		Transparency = NS({ { 0, 0.1 }, { 0.8, 0.2 }, { 1, 1 } }),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-160, 160),
		LightEmission = 0.35,
		Brightness = 1.6,
		Color = CS({
			{ 0, rgb(232, 214, 255) },
			{ 0.5, rgb(190, 160, 255) },
			{ 1, rgb(140, 220, 255) },
		}),
	})
end

-- LIGHT
do
	local chest = att(torsoG, "Light", CFrame.new(0, 0.2, 0), true)
	local l = Instance.new("PointLight")
	l.Name = "Violet"
	l.Color = rgb(170, 110, 255)
	l.Brightness = 1.2
	l.Range = 7
	l.Shadows = false
	l.Parent = chest
end

folder:SetAttribute("K", 1)
folder:SetAttribute("Tier", "C")
folder:SetAttribute("Live", math.floor(live + 0.5))
folder:SetAttribute("Source", "custom: tools/studio/auras/build_butterfly_dance.luau")
local old = dest:FindFirstChild(KEY)
if old then
	old:Destroy()
end
folder.Parent = dest
return `{KEY} built: live ~{math.floor(live + 0.5)} particles`
