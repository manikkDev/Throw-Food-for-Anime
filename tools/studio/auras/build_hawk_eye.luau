-- build_hawk_eye.luau - Studio EDIT mode, rerunnable:
--   python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file tools/studio/auras/build_hawk_eye.luau
-- Builds ReplicatedStorage.Assets.Auras.HawkEye: Mihawk's (hawkeye_swordsman) hero aura, hand-authored with the
-- roblox-vfx skill's authoring route. Every texture is our own (tools/auras/hawk_eye/make_tex.py, ids in
-- assets/auras/hawk_eye/ids.json; wisp/glint/glow shared with ButterflyDance). Writes NOTHING else.
-- HeroAura.luau's template format: every CFrame in the hero ROOT's space at rest, R15, feet at y -3, faces -Z.
-- Mihawk carries Yoru across his back (z +0.8, 6.3 tall, 4.6 wide) and a wide plumed hat (brim ~3.4 across).
--
-- The look (the world's greatest swordsman, calm, deadly; his green flying slash at Marineford, Haki, hawk eyes):
--   SIGIL    a cut ring under his feet: rings scored by sixteen sword cuts round Yoru's cross and a hawk eye,
--            emerald over a black ink outline, turning very slowly (SurfaceGui, self-lit)
--   SLASHES  emerald crescents (white-hot edge, green-black belly) cut round him at every angle and vanish;
--            darker "Kokuto" slashes between them, a little wider (camera-facing arcs that ring his silhouette)
--   HAKI     short black lightning cracks in a crimson halo on his body (Conqueror's Haki)
--   MANTLE   green-black flame tongues on a turning ring at his silhouette's edge, emerald ones among them,
--            pushed back in depth so they frame him
--   FEATHERS barred hawk feathers with an emerald rim tumbling down round him
--   EYES     two gold glints over his eyes (the hawk's stare); a gold gleam at Yoru's guard
--   PRESENCE a dark green haze behind his silhouette, emerald glints in the air, one emerald light

local RS = game:GetService("ReplicatedStorage")

local TEX = {
	slash = "rbxassetid://90450165261873",
	bolt = "rbxassetid://136960814808642",
	sigil = "rbxassetid://74146380599847",
	feather = "rbxassetid://94234629948543",
	wisp = "rbxassetid://105910302884912",
	glint = "rbxassetid://94471435227120",
	glow = "rbxassetid://114990150725293",
}

local KEY = "HawkEye"
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

local function group(parent: Instance, name: string)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- ------------------------------------------------------------------------------------------------
local assets = RS:WaitForChild("Assets")
local dest = assets:FindFirstChild("Auras")
assert(dest, "ReplicatedStorage.Assets.Auras missing")
local folder = Instance.new("Folder")
folder.Name = KEY
local rootG = group(folder, "HumanoidRootPart")
local torsoG = group(folder, "UpperTorso")
local headG = group(folder, "Head")

-- SIGIL
do
	local plate = carrier(
		rootG,
		"Sigil",
		Vector3.new(6.4, 0.05, 6.4),
		CFrame.new(0, FEET + 0.07, 0),
		Vector3.new(0, 0.12, 0)
	)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SigilGui"
	gui.Face = Enum.NormalId.Top
	gui.LightInfluence = 0
	gui.Brightness = 1.1
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 80
	gui.Parent = plate
	local function layer(name, image, colour, transparency, scale, z)
		local l = Instance.new("ImageLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5, 0.5)
		l.Size = UDim2.fromScale(scale, scale)
		l.Image = image
		l.ImageColor3 = colour
		l.ImageTransparency = transparency
		l.ZIndex = z
		l.Parent = gui
	end
	layer("Pool", TEX.glow, rgb(18, 150, 86), 0.55, 1.05, 1)
	layer("Ink", TEX.sigil, rgb(4, 10, 7), 0.04, 1.02, 2)
	layer("Ring", TEX.sigil, rgb(52, 236, 146), 0, 1, 3)
end

-- SLASHES: centred on his chest, camera-facing crescents at random angles, turning as they cut: the arc lies
-- 2.6+ studs out (outside his silhouette), so from ANY view they ring him and pass behind his body (depth test).
-- (Flat 3D planes were edge-on from a level camera half the time and vanished.)
do
	local chest = att(rootG, "SlashCore", CFrame.new(0, 0.2, 0), true)
	local common = {
		Texture = TEX.slash,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Speed = NumberRange.new(0, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-140, 140),
		Transparency = NS({ { 0, 0 }, { 0.75, 0 }, { 1, 0.4 } }),
	}
	local emerald = table.clone(common)
	emerald.Rate = 2.2
	emerald.Lifetime = NumberRange.new(0.4, 0.48)
	emerald.Size = NS({ { 0, 2.9, 0.25 }, { 1, 3.15, 0.25 } })
	emerald.LightEmission = 0.35
	emerald.Brightness = 1.5
	emerald.Color = CS({ { 0, rgb(255, 255, 255) }, { 1, rgb(255, 255, 255) } })
	emitter(chest, "Slash", emerald)
	local kokuto = table.clone(common)
	kokuto.Rate = 1.0
	kokuto.Lifetime = NumberRange.new(0.45, 0.55)
	kokuto.Size = NS({ { 0, 3.2, 0.25 }, { 1, 3.45, 0.25 } })
	kokuto.LightEmission = 0
	kokuto.Brightness = 1
	kokuto.Color = CS({ { 0, rgb(70, 92, 80) }, { 1, rgb(70, 92, 80) } })
	emitter(chest, "KokutoSlash", kokuto)
end

-- HAKI: cracks on his body (Direct = emitted from the body part's own volume)
do
	local function haki(partName, rate)
		local g = folder:FindFirstChild(partName) or group(folder, partName)
		local direct = g:FindFirstChild("Direct") or group(g, "Direct")
		emitter(direct, "HakiCrack", {
			Texture = TEX.bolt,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
			FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			Rate = rate,
			Lifetime = NumberRange.new(0.22, 0.3),
			Speed = NumberRange.new(0, 0),
			Size = NS({ { 0, 0.75, 0.2 }, { 1, 0.85, 0.2 } }),
			Rotation = NumberRange.new(0, 360),
			LightEmission = 0.2,
			Brightness = 1.4,
			Color = CS({ { 0, rgb(255, 255, 255) }, { 1, rgb(255, 255, 255) } }),
			ZOffset = 0.6,
			LockedToPart = true,
		})
	end
	haki("UpperTorso", 2.2)
	haki("LowerTorso", 0.8)
	haki("LeftUpperArm", 0.7)
	haki("RightUpperArm", 0.7)
	haki("LeftLowerLeg", 0.6)
	haki("RightLowerLeg", 0.6)
end

-- MANTLE: green-black tongues on a turning ring at the silhouette's edge
do
	local ring = carrier(
		rootG,
		"Mantle",
		Vector3.new(0.2, 0.2, 0.2),
		CFrame.new(0, FEET + 0.3, 0),
		Vector3.new(0, -0.55, 0)
	)
	local common = {
		Texture = TEX.wisp,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(8, 8),
		Speed = NumberRange.new(2.0, 3.0),
		Acceleration = Vector3.new(0, 2.6, 0),
		Drag = 0.6,
		Rotation = NumberRange.new(-10, 10),
	}
	local shade = table.clone(common)
	shade.Rate = 2.8
	shade.Lifetime = NumberRange.new(1.0, 1.35)
	shade.Size = NS({ { 0, 1.3, 0.12 }, { 0.5, 1.75, 0.15 }, { 1, 1.95, 0.12 } })
	shade.Transparency = NS({ { 0, 0.08 }, { 0.5, 0.02 }, { 1, 1 } })
	shade.LightEmission = 0
	shade.Brightness = 1
	shade.Color = CS({ { 0, rgb(16, 40, 28) }, { 0.4, rgb(6, 14, 10) }, { 1, rgb(2, 4, 3) } })
	shade.ZOffset = -2.6
	local green = table.clone(common)
	green.Rate = 2.2
	green.Lifetime = NumberRange.new(0.85, 1.15)
	green.Size = NS({ { 0, 1.15, 0.1 }, { 0.5, 1.55, 0.12 }, { 1, 1.7 } })
	green.Transparency = NS({ { 0, 0.15 }, { 0.5, 0.08 }, { 1, 1 } })
	green.LightEmission = 0.3
	green.Brightness = 1.7
	green.Color =
		CS({ { 0, rgb(214, 255, 230) }, { 0.25, rgb(40, 240, 140) }, { 1, rgb(6, 110, 60) } })
	green.ZOffset = -2.3
	for i = 1, 8 do
		local a = (i - 1) * math.pi / 4 + (if i % 2 == 0 then 0.2 else 0)
		local r = if i % 2 == 0 then 2.25 else 2.0
		local at = att(ring, "Root" .. i, CFrame.new(math.cos(a) * r, 0, math.sin(a) * r), false)
		emitter(at, "ShadeTongues", shade)
		emitter(at, "GreenTongues", green)
	end
end

-- FEATHERS: tumbling down round him from above his hat
do
	local sky = carrier(rootG, "Feathers", Vector3.new(5.6, 1.6, 5.6), CFrame.new(0, 3.4, 0), nil)
	emitter(sky, "HawkFeathers", {
		Texture = TEX.feather,
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Rate = 1.0,
		Lifetime = NumberRange.new(3.6, 4.6),
		Speed = NumberRange.new(0.1, 0.4),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -0.55, 0),
		Drag = 1.1,
		Size = NS({ { 0, 0.38, 0.06 }, { 1, 0.38, 0.06 } }),
		Transparency = NS({ { 0, 1 }, { 0.08, 0 }, { 0.8, 0 }, { 1, 1 } }),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-50, 50),
		LightEmission = 0,
		LightInfluence = 0.5,
		Brightness = 1.2,
		Color = CS({ { 0, rgb(255, 255, 255) }, { 1, rgb(255, 255, 255) } }),
	})
end

-- EYES: the hawk's stare (gold glints over his eyes); a gold gleam at Yoru's guard
do
	for _, x in { -0.21, 0.21 } do
		local eye = att(headG, "Eye", CFrame.new(x, 1.66, -0.64), true)
		emitter(eye, "HawkEye", {
			Texture = TEX.glint,
			Rate = 2,
			Lifetime = NumberRange.new(0.7, 0.7),
			Speed = NumberRange.new(0, 0),
			Size = NS({ { 0, 0.1 }, { 0.5, 0.17 }, { 1, 0.1 } }),
			Transparency = NS({ { 0, 0.6 }, { 0.5, 0 }, { 1, 0.6 } }),
			Rotation = NumberRange.new(0, 0),
			LightEmission = 1,
			Brightness = 2.2,
			Color = CS({ { 0, rgb(255, 226, 110) }, { 1, rgb(255, 190, 60) } }),
			ZOffset = 0.6,
			LockedToPart = true,
		})
	end
	local guard = att(torsoG, "YoruGuard", CFrame.new(0, 2.0, 0.95), true)
	emitter(guard, "YoruGleam", {
		Texture = TEX.glint,
		Rate = 0.8,
		Lifetime = NumberRange.new(0.55, 0.7),
		Speed = NumberRange.new(0, 0),
		Size = NS({ { 0, 0 }, { 0.3, 0.45 }, { 1, 0 } }),
		Rotation = NumberRange.new(0, 45),
		LightEmission = 1,
		Brightness = 2,
		Color = CS({ { 0, rgb(255, 236, 160) }, { 1, rgb(255, 200, 80) } }),
		LockedToPart = true,
	})
end

-- PRESENCE: a dark green haze behind him, emerald glints in the air, one emerald light
do
	local core = att(rootG, "Presence", CFrame.new(0, 0.2, 0), true)
	emitter(core, "Haze", {
		Texture = TEX.glow,
		Rate = 1.5,
		Lifetime = NumberRange.new(1.8, 1.8),
		Speed = NumberRange.new(0, 0),
		Size = NS({ { 0, 2.8 }, { 0.5, 3.1 }, { 1, 2.8 } }),
		Transparency = NS({ { 0, 1 }, { 0.3, 0.5 }, { 0.7, 0.5 }, { 1, 1 } }),
		LightEmission = 0,
		Brightness = 1,
		Color = CS({ { 0, rgb(14, 58, 36) }, { 1, rgb(6, 30, 18) } }),
		ZOffset = -2.6,
		LockedToPart = true,
	})
	local box = carrier(rootG, "Air", Vector3.new(4.8, 5.6, 4.8), CFrame.new(0, -0.2, 0), nil)
	emitter(box, "EmeraldGlints", {
		Texture = TEX.glint,
		Shape = Enum.ParticleEmitterShape.Box,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Rate = 7,
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(0.1, 0.3),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, 0.4, 0),
		Size = NS({ { 0, 0 }, { 0.3, 0.22, 0.05 }, { 1, 0 } }),
		Transparency = NS({ { 0, 0 }, { 1, 0.3 } }),
		Rotation = NumberRange.new(0, 90),
		LightEmission = 1,
		Brightness = 1.7,
		Color = CS({ { 0, rgb(206, 255, 226) }, { 1, rgb(40, 220, 130) } }),
	})
	local chest = att(torsoG, "Light", CFrame.new(0, 0.2, 0), true)
	local l = Instance.new("PointLight")
	l.Name = "Emerald"
	l.Color = rgb(60, 230, 140)
	l.Brightness = 0.9
	l.Range = 7
	l.Shadows = false
	l.Parent = chest
end

folder:SetAttribute("K", 1)
folder:SetAttribute("Tier", "C")
folder:SetAttribute("Live", math.floor(live + 0.5))
folder:SetAttribute("Source", "custom: tools/studio/auras/build_hawk_eye.luau")
local old = dest:FindFirstChild(KEY)
if old then
	old:Destroy()
end
folder.Parent = dest
return `{KEY} built: live ~{math.floor(live + 0.5)} particles`
