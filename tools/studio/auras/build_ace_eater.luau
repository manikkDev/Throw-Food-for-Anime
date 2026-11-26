-- build_ace_eater.luau - Studio EDIT mode, rerunnable:
--   python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file tools/studio/auras/build_ace_eater.luau
-- Builds ReplicatedStorage.Assets.Auras.AceEater: Don Lorenzo's (number_one_striker) hero aura, hand-authored with
-- the roblox-vfx skill's authoring route. Every texture is our own (tools/auras/ace_eater/make_tex.py, ids in
-- assets/auras/ace_eater/ids.json; the glint is ButterflyDance's). Writes NOTHING else.
-- HeroAura.luau's template format: every CFrame in the hero ROOT's space at rest, R15, feet at y -3, faces -Z.
-- Legendary (tier D): the furthest piece stays inside 6.5 studs.
--
-- The look (Blue Lock, Don Lorenzo: "the Ace Eater", the Zombie-step dribble, a player who prices everyone by their
-- transfer fee): acid lime and violet-black (undead), bone, gold (his grill, his money). No flames.
--   PITCH     his pitch under him: a centre circle and halfway line, the Ace Eater crest (fangs biting a ball),
--             lime over violet-black ink; a ring of gold coins etched with fee marks turning the other way
--   (no rising hands: removed on the owner's request)
--   EATER     spectral jaws with a gold grill snapping shut on a shell round him
--   DRIBBLE   a football orbiting his feet fast (the Zombie-step), leaving lime afterimages
--   MONEY     gold glints rising; FLOW lime glints over his eyes; one lime light

local RS = game:GetService("ReplicatedStorage")

local TEX = {
	pitch = { core = 129814340992741, ink = 116059464133364, glow = 71469421315006 },
	coins = { core = 129962113209231, ink = 94429536477552, glow = 113215013695059 },
	hand = "rbxassetid://98855564840828",
	jaws = "rbxassetid://113484576797990",
	ball = "rbxassetid://94099426610665",
	glint = "rbxassetid://94471435227120",
}

local KEY = "AceEater"
local FEET = -3.0
local LIME = Color3.fromRGB(182, 255, 64)
local LIME_GLOW = Color3.fromRGB(110, 255, 50)
local GOLD = Color3.fromRGB(255, 210, 70)
local GOLD_GLOW = Color3.fromRGB(255, 170, 30)
local INK = Color3.fromRGB(20, 8, 28)
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

local function plateGui(
	plate: BasePart,
	set,
	pxPerStud: number,
	core: Color3,
	glow: Color3,
	glowT: number
)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Plate"
	gui.Face = Enum.NormalId.Top
	gui.LightInfluence = 0
	gui.Brightness = 2.2
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pxPerStud
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
	layer("Glow", set.glow, glow, glowT, 1)
	layer("Ink", set.ink, INK, 0.05, 2)
	layer("Core", set.core, core, 0, 3)
end

local rootG = group("HumanoidRootPart")

-- PITCH + COINS
do
	local pitch = carrier(
		rootG,
		"Pitch",
		Vector3.new(8.6, 0.05, 8.6),
		CFrame.new(0, FEET + 0.05, 0),
		Vector3.new(0, 0.04, 0)
	)
	plateGui(pitch, TEX.pitch, 1024 / 8.6, LIME, LIME_GLOW, 0.3)
	local coins = carrier(
		rootG,
		"Coins",
		Vector3.new(8.6, 0.05, 8.6),
		CFrame.new(0, FEET + 0.08, 0),
		Vector3.new(0, -0.12, 0)
	)
	plateGui(coins, TEX.coins, 1024 / 8.6, GOLD, GOLD_GLOW, 0.55)
end

-- (the undead hands rising round him were removed: owner, 2026-11-25)

-- EATER: jaws snapping shut on a shell round him
do
	local shell = carrier(rootG, "Eater", Vector3.new(5.2, 4.4, 5.2), CFrame.new(0, 0.2, 0), nil)
	emitter(shell, "AceEaterJaws", {
		Texture = TEX.jaws,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
		Rate = 1.8,
		Lifetime = NumberRange.new(0.7, 0.8),
		Speed = NumberRange.new(0, 0),
		Size = NS({ { 0, 1.05, 0.2 }, { 1, 1.2, 0.2 } }),
		LightEmission = 0.15,
		Brightness = 1.4,
		Color = WHITE,
		ZOffset = 0.3,
	})
end

-- DRIBBLE: a football orbiting his feet fast, with afterimages
do
	local ring = carrier(
		rootG,
		"Dribble",
		Vector3.new(0.2, 0.2, 0.2),
		CFrame.new(0, FEET + 0.5, 0),
		Vector3.new(0, 2.4, 0)
	)
	local at = att(ring, "Ball", CFrame.new(2.25, 0, 0), false)
	emitter(at, "Football", {
		Texture = TEX.ball,
		Rate = 0.25,
		Lifetime = NumberRange.new(4, 4),
		Speed = NumberRange.new(0, 0),
		Size = NS({ { 0, 0.4 }, { 1, 0.4 } }),
		Transparency = NS({ { 0, 1 }, { 0.04, 0 }, { 0.96, 0 }, { 1, 1 } }),
		RotSpeed = NumberRange.new(-420, -420),
		LightEmission = 0.1,
		LightInfluence = 0.3,
		Brightness = 1.2,
		Color = WHITE,
		LockedToPart = true,
	})
	emitter(at, "Afterimage", {
		Texture = TEX.ball,
		Rate = 14,
		Lifetime = NumberRange.new(0.22, 0.28),
		Speed = NumberRange.new(0, 0),
		Size = NS({ { 0, 0.38 }, { 1, 0.3 } }),
		Transparency = NS({ { 0, 0.55 }, { 1, 1 } }),
		LightEmission = 0.8,
		Brightness = 1.6,
		Color = CS({ { 0, LIME }, { 1, rgb(90, 200, 40) } }),
	})
end

-- MONEY, FLOW EYES, LIGHT
do
	local box = carrier(rootG, "Money", Vector3.new(5, 5.6, 5), CFrame.new(0, -0.2, 0), nil)
	emitter(box, "GoldGlints", {
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
		Color = CS({ { 0, rgb(255, 240, 160) }, { 1, GOLD } }),
	})
	local head = group("Head")
	for _, x in { -0.2, 0.2 } do
		local a = att(head, "FlowEye", CFrame.new(x, 1.62, -0.63), true)
		emitter(a, "FlowGlint", {
			Texture = TEX.glint,
			Rate = 2,
			Lifetime = NumberRange.new(0.7, 0.7),
			Speed = NumberRange.new(0, 0),
			Size = NS({ { 0, 0.08 }, { 0.5, 0.13 }, { 1, 0.08 } }),
			Transparency = NS({ { 0, 0.6 }, { 0.5, 0 }, { 1, 0.6 } }),
			Rotation = NumberRange.new(0, 0),
			LightEmission = 1,
			Brightness = 2.4,
			Color = CS({ { 0, rgb(220, 255, 140) }, { 1, LIME } }),
			ZOffset = 0.6,
			LockedToPart = true,
		})
	end
	local chest = att(group("UpperTorso"), "Light", CFrame.new(0, 0.2, 0), true)
	local l = Instance.new("PointLight")
	l.Name = "Lime"
	l.Color = rgb(150, 255, 80)
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
folder:SetAttribute("Source", "custom: tools/studio/auras/build_ace_eater.luau")
local old = dest:FindFirstChild(KEY)
if old then
	old:Destroy()
end
folder.Parent = dest
return `{KEY} built: live ~{math.floor(live + 0.5)} particles`
