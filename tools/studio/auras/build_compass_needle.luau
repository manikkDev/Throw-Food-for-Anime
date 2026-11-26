-- build_compass_needle.luau - Studio EDIT mode, rerunnable:
--   python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file tools/studio/auras/build_compass_needle.luau
-- Builds ReplicatedStorage.Assets.Auras.CompassNeedle: Akaza's (crimson_fist_demon) hero aura, hand-authored with
-- the roblox-vfx skill's authoring route. Every texture is our own (tools/auras/compass_needle/make_tex.py, ids in
-- assets/auras/compass_needle/ids.json; the glint is ButterflyDance's). Writes NOTHING else.
-- HeroAura.luau's template format: every CFrame in the hero ROOT's space at rest, R15, feet at y -3, faces -Z.
-- Legendary (tier D): the furthest piece stays inside 6.5 studs.
--
-- The look (Demon Slayer, Upper Rank Three, Blood Demon Art "Destructive Death"): the COMPASS NEEDLE, a snowflake
-- compass (Koyuki's hairpin) open on the ground under him; his blows land as ice-blue shockwaves with snowflake
-- flashes, thrown so fast they pop all round him. Ice-white, cyan, electric blue over deep navy ink. No flames.
--   COMPASS   a compass rose (tick ring, cardinal marks, twelve needles) turning slowly, a branching snowflake
--             counter-turning at its heart (self-lit SurfaceGuis: blue glow, navy ink, ice-white lines)
--   FLARE     now and then the compass flares: a snowflake shock flat across it
--   BARRAGE   snowflake impact flashes in shock rings popping on a shell round him (Destructive Death: Disorder)
--   SPIRIT    small crisp snowflakes rising and turning round him (the fighting spirit he reads)
--   EYES      gold glints over his eyes (Upper Rank); one ice-cyan light

local RS = game:GetService("ReplicatedStorage")

local TEX = {
	rose = { core = 96534943790225, ink = 86025769745955, glow = 114868857587090 },
	flake = { core = 89210671540990, ink = 134848059314139, glow = 113571081778559 },
	snow = "rbxassetid://73733000789648",
	impact = "rbxassetid://84235141289531",
	streak = "rbxassetid://70446999640906",
	glint = "rbxassetid://94471435227120",
}

local KEY = "CompassNeedle"
local FEET = -3.0
local ICE = Color3.fromRGB(165, 238, 255)
local BLUE = Color3.fromRGB(40, 140, 255)
local NAVY = Color3.fromRGB(6, 16, 40)

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

local function plateGui(plate: BasePart, set, pxPerStud: number)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Compass"
	gui.Face = Enum.NormalId.Top
	gui.LightInfluence = 0
	gui.Brightness = 2.6
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
	layer("Glow", set.glow, BLUE, 0.3, 1)
	layer("Ink", set.ink, NAVY, 0.05, 2)
	layer("Core", set.core, ICE, 0, 3)
end

local rootG = group("HumanoidRootPart")

-- COMPASS
do
	local rose = carrier(
		rootG,
		"CompassRose",
		Vector3.new(8.4, 0.05, 8.4),
		CFrame.new(0, FEET + 0.05, 0),
		Vector3.new(0, 0.07, 0)
	)
	plateGui(rose, TEX.rose, 1024 / 8.4)
	local flake = carrier(
		rootG,
		"CompassFlake",
		Vector3.new(4.8, 0.05, 4.8),
		CFrame.new(0, FEET + 0.09, 0),
		Vector3.new(0, -0.22, 0)
	)
	plateGui(flake, TEX.flake, 1024 / 4.8)
	-- (the rising light needles from the compass points were removed: owner, 2026-11-25, "looks trash")
end

-- FLARE: a snowflake shock flat across the compass now and then
do
	local core = att(rootG, "Flare", CFrame.new(0, FEET + 0.2, 0), true)
	emitter(core, "CompassFlare", {
		Texture = TEX.impact,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(0.01, 0.01),
		Rate = 0.55,
		Lifetime = NumberRange.new(0.8, 0.9),
		Size = NS({ { 0, 1.8 }, { 1, 3.9 } }),
		Rotation = NumberRange.new(0, 360),
		Transparency = NS({ { 0, 0.1 }, { 1, 0.6 } }),
		LightEmission = 0.8,
		Brightness = 2,
		Color = CS({ { 0, ICE }, { 1, rgb(70, 170, 255) } }),
		LockedToPart = true,
	})
end

-- BARRAGE: snowflake impacts popping on a shell round him
do
	local shell = carrier(rootG, "Barrage", Vector3.new(5.2, 4.6, 5.2), CFrame.new(0, 0, 0), nil)
	emitter(shell, "DestructiveDeath", {
		Texture = TEX.impact,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Rate = 4.2,
		Lifetime = NumberRange.new(0.32, 0.4),
		Speed = NumberRange.new(0, 0),
		Size = NS({ { 0, 0.85, 0.2 }, { 1, 1.1, 0.2 } }),
		Rotation = NumberRange.new(0, 360),
		LightEmission = 0.75,
		Brightness = 2.2,
		Color = CS({ { 0, rgb(230, 252, 255) }, { 1, rgb(80, 185, 255) } }),
		ZOffset = 0.3,
	})
end

-- SPIRIT: snowflakes rising and turning round him
do
	local box = carrier(rootG, "Spirit", Vector3.new(5, 5.6, 5), CFrame.new(0, -0.2, 0), nil)
	emitter(box, "FightingSpirit", {
		Texture = TEX.snow,
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Rate = 9,
		Lifetime = NumberRange.new(1.8, 2.6),
		Speed = NumberRange.new(0.2, 0.45),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(30, 30),
		Acceleration = Vector3.new(0, 0.3, 0),
		Size = NS({ { 0, 0 }, { 0.15, 0.22, 0.06 }, { 0.8, 0.2, 0.06 }, { 1, 0 } }),
		Transparency = NS({ { 0, 0.1 }, { 1, 0.4 } }),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-60, 60),
		LightEmission = 0.6,
		Brightness = 1.7,
		Color = CS({ { 0, rgb(235, 252, 255) }, { 1, rgb(110, 200, 255) } }),
	})
end

-- EYES, LIGHT
do
	local head = group("Head")
	for _, x in { -0.2, 0.2 } do
		local a = att(head, "UpperRankEye", CFrame.new(x, 1.64, -0.63), true)
		emitter(a, "GoldEye", {
			Texture = TEX.glint,
			Rate = 2,
			Lifetime = NumberRange.new(0.7, 0.7),
			Speed = NumberRange.new(0, 0),
			Size = NS({ { 0, 0.08 }, { 0.5, 0.13 }, { 1, 0.08 } }),
			Transparency = NS({ { 0, 0.6 }, { 0.5, 0 }, { 1, 0.6 } }),
			Rotation = NumberRange.new(0, 0),
			LightEmission = 1,
			Brightness = 2.4,
			Color = CS({ { 0, rgb(255, 230, 120) }, { 1, rgb(255, 200, 70) } }),
			ZOffset = 0.6,
			LockedToPart = true,
		})
	end
	local chest = att(group("UpperTorso"), "Light", CFrame.new(0, 0.2, 0), true)
	local l = Instance.new("PointLight")
	l.Name = "Ice"
	l.Color = rgb(110, 210, 255)
	l.Brightness = 1.1
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
folder:SetAttribute("Source", "custom: tools/studio/auras/build_compass_needle.luau")
local old = dest:FindFirstChild(KEY)
if old then
	old:Destroy()
end
folder.Parent = dest
return `{KEY} built: live ~{math.floor(live + 0.5)} particles`
