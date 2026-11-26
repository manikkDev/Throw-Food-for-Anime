-- build_sun_breathing.luau - Studio EDIT mode, rerunnable:
--   python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file tools/studio/auras/build_sun_breathing.luau
-- Builds ReplicatedStorage.Assets.Auras.SunBreathing: Yoriichi Tsugikuni's (sakura_shogun, Premium) hero aura.
--
-- v3 (owner, 2026-11-25): "the original one looks way better, bring it back and create a perfect base for
-- him". So his BODY wears the original Solar Flare pack aura EXACTLY as converted for the preview yard
-- (ServerStorage.AuraPreview.Templates.P99, copied verbatim: Burst, Flam, Spark, Glow, Dust, Dust2 and its
-- light), and this file adds only the BASE under his feet: THE SUN SEAL.
--   SEAL     the outer seal: a double gold rim, a band of brush kanji 日の呼吸 (Sun Breathing), and the 13th
--            form, twelve curling flame commas chasing round; PRE-COLOURED on a SurfaceGui (keeps its colours
--            on any floor), turning slowly
--   SUN      the hanafuda sun of his earrings (crimson disc, gold rim, sixteen rays) turning the other way
--   BREATH   a ring of light pulsing out over the floor every 1.6 s (Total Concentration Breathing)
--   GLINT    a sun glint racing round the rim with a short trail of light
--   FIRE     a continuous ring of fire on the rim, in layers: a floor glow where it burns, a white-hot base
--            band, the flame body (one-shot flame licks from a ring emitter, so it is seamless), taller
--            tongues now and then (an uneven crown), and sparks spitting up
--   EMBERS   embers rising off the seal
-- Textures: tools/auras/sun_breathing/make_tex.py (ids in assets/auras/sun_breathing/ids.json; lib_* are the
-- roblox-vfx skill's generated library). v1 (cel ukiyo-e fire) and v2 (a re-lit Solar Flare with layers on
-- his body) were rejected: see tools/auras/README.md.
-- Layout is HeroAura.luau's template format (every CFrame in the hero ROOT's space at rest, R15, feet at
-- y -3, the hero faces -Z). ParticleEmitter Size is HALF the drawn width.

local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local TEX = {
	sealOuter = "rbxassetid://105985273415115",
	sealInner = "rbxassetid://95416872184980",
	ember = "rbxassetid://94599216225372",
	ripple = "rbxassetid://74763263739033", -- lib ripple_fb_glow_02 (4x4 one-shot)
	flare = "rbxassetid://126954519228333", -- lib flare_glow_04
	flameLick = "rbxassetid://111489275803146", -- 4x4 one-shot flame lick
	ring = "rbxassetid://7216856402", -- Solar Flare pack: soft ring (the fire's floor glow)
	glow = "rbxassetid://1075864321", -- Solar Flare pack: soft glow
}

local KEY = "SunBreathing"
local HERO = "sakura_shogun"
local SLOT = "Yoriichi Tsugikuni"
local ORIGINAL = "P99" -- ServerStorage.AuraPreview.Templates.P99 = POF:RE AURA SOLAR FLARE, converted
local FEET = -3.0
local SEAL_R = 3.7 -- the outer seal's radius (studs)

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
local function NR(a, b)
	return NumberRange.new(a, b or a)
end
local function hex(h: string): Color3
	return Color3.fromHex(h)
end

-- saturated ramps: additive pale gold goes white over the bright 13:12 sky
local RAMP = CS({ { 0, hex("FFA030") }, { 0.4, hex("FF6A10") }, { 1, hex("C81E00") } })

local function emitter(name: string, props: { [string]: any }, parent: Instance): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.LightInfluence = 0
	e.LightEmission = 1
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local out = Instance.new("Folder")
out.Name = KEY

local function group(name: string): Folder
	local g = out:FindFirstChild(name) :: Folder?
	if not g then
		g = Instance.new("Folder")
		g.Name = name
		g.Parent = out
	end
	return g :: Folder
end

local function carrier(name: string, size: Vector3, cf: CFrame, spin: Vector3?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p:SetAttribute("RootCF", cf)
	if spin then
		p:SetAttribute("Spin", spin)
	end
	p.Parent = group("HumanoidRootPart")
	return p
end

local function topImage(p: Part, image: string, brightness: number)
	local g = Instance.new("SurfaceGui")
	g.Name = "Seal"
	g.Face = Enum.NormalId.Top
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 64
	g.LightInfluence = 0
	g.Brightness = brightness
	g.AlwaysOnTop = false
	g.ClipsDescendants = true
	g.Parent = p
	local img = Instance.new("ImageLabel")
	img.Name = "Image"
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = image
	img.Parent = g
end

local live = 0
local function cost(rate: number, life: number, n: number?)
	live += rate * life * (n or 1)
end

---------------------------------------------------------------- THE ORIGINAL (copied verbatim)
local templates = SS:FindFirstChild("AuraPreview") and SS.AuraPreview:FindFirstChild("Templates")
local original = templates and templates:FindFirstChild(ORIGINAL)
assert(
	original,
	"ServerStorage.AuraPreview.Templates."
		.. ORIGINAL
		.. " is missing: run tools/aura_assign.py build first"
)
for _, g in original:GetChildren() do
	g:Clone().Parent = out
end
live += (original:GetAttribute("Live") or 0) :: number

---------------------------------------------------------------- SEAL + SUN (pre-coloured, turning)
do
	local seal = carrier(
		"SunSeal",
		Vector3.new(SEAL_R * 2, 0.05, SEAL_R * 2),
		CFrame.new(0, FEET + 0.04, 0),
		Vector3.new(0, -0.22, 0)
	)
	topImage(seal, TEX.sealOuter, 1.5)
	-- the sun sits inside the seal's inner ring (radius 0.42 of the seal)
	local d = SEAL_R * 2 * 0.42 * 0.98
	local sun = carrier(
		"HanafudaSun",
		Vector3.new(d, 0.05, d),
		CFrame.new(0, FEET + 0.06, 0),
		Vector3.new(0, 0.4, 0)
	)
	topImage(sun, TEX.sealInner, 1.45)
end

---------------------------------------------------------------- BREATH (a ring of light every 1.6 s)
do
	local floor = carrier("BreathFloor", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, FEET + 0.1, 0))
	local rate, life = 1 / 1.6, 1.1
	emitter("BreathRipple", {
		Texture = TEX.ripple,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular, -- flat on the floor
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(0, 0),
		Speed = NR(0.001),
		LockedToPart = true,
		Size = NS({ { 0, 4.0 }, { 1, 4.4 } }),
		Transparency = NS({ { 0, 0.2 }, { 0.7, 0.45 }, { 1, 1 } }),
		Color = CS({ { 0, hex("FF8A1A") }, { 1, hex("E03A00") } }),
		Lifetime = NR(life),
		Rate = rate,
		LightEmission = 0.8,
		Brightness = 1.2,
		ZOffset = 0.1,
	}, floor)
	cost(rate, life)
end

---------------------------------------------------------------- GLINT (racing round the rim)
do
	local ring = carrier(
		"GlintRing",
		Vector3.new(0.2, 0.2, 0.2),
		CFrame.new(0, FEET + 0.2, 0),
		Vector3.new(0, 1.25, 0)
	)
	for i, ang in { 0, math.pi } do
		local a = Instance.new("Attachment")
		a.Name = "Glint" .. i
		a.CFrame = CFrame.new(math.cos(ang) * (SEAL_R - 0.12), 0, math.sin(ang) * (SEAL_R - 0.12))
		a.Parent = ring
		-- the glint itself: a locked flare, twinkling
		emitter("RimGlint", {
			Texture = TEX.flare,
			Orientation = Enum.ParticleOrientation.FacingCamera,
			LockedToPart = true,
			Size = NS({ { 0, 0.55 }, { 0.25, 0.85 }, { 0.5, 0.6 }, { 0.75, 0.85 }, { 1, 0.55 } }),
			Transparency = NS({ { 0, 1 }, { 0.2, 0.05 }, { 0.8, 0.05 }, { 1, 1 } }),
			Color = CS({ { 0, hex("FFC050") }, { 1, hex("FF8A1A") } }),
			Lifetime = NR(1.2),
			Rate = 2 / 1.2,
			Speed = NR(0),
			Rotation = NR(-10, 10),
			Brightness = 1.4,
			ZOffset = 0.3,
		}, a)
		cost(2 / 1.2, 1.2)
		-- its trail: small sparks left behind, fading along the rim
		emitter("RimTrail", {
			Texture = TEX.ember,
			Orientation = Enum.ParticleOrientation.FacingCamera,
			Size = NS({ { 0, 0.2 }, { 1, 0 } }),
			Transparency = NS({ { 0, 0.1 }, { 1, 1 } }),
			Color = RAMP,
			Lifetime = NR(0.45),
			Rate = 26,
			Speed = NR(0),
			Brightness = 1.6,
			ZOffset = 0.2,
		}, a)
		cost(26, 0.45)
	end
end

---------------------------------------------------------------- FIRE (a continuous ring of fire on the rim)
do
	-- 24 points round the rim, each emitting every layer: the flames (1.4 wide) overlap the 0.97-stud gaps,
	-- so the ring is seamless (v1 was 14 soft blobs; a Disc emitter with ShapePartial 0.93 emitted almost
	-- nothing in Studio, so no shape tricks). FacingCameraWorldUp quads are centred on the particle, so each
	-- layer is lifted HALF its size above the floor: the flame's base lands on the seal.
	local N = 24
	local base = carrier("FireRing", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, FEET, 0))
	local points: { Attachment } = {}
	for i = 1, N do
		local ang = (i - 0.5) / N * 2 * math.pi
		local a = Instance.new("Attachment")
		a.Name = "Fire" .. i
		a.CFrame = CFrame.new(math.cos(ang) * (SEAL_R - 0.1), 0, math.sin(ang) * (SEAL_R - 0.1))
		a.Parent = base
		points[i] = a
	end
	local function ringEmitter(name: string, lift: number, every: number, props: { [string]: any })
		-- `props.Rate` is the WHOLE ring's rate; every `every`-th point carries the layer
		local count = 0
		for i = 1, N, every do
			count += 1
		end
		local total = props.Rate
		props.Rate = total / count
		props.EmissionDirection = Enum.NormalId.Top
		for i = 1, N, every do
			local a = points[i]
			local holder = Instance.new("Attachment")
			holder.Name = name .. "At"
			holder.CFrame = a.CFrame * CFrame.new(0, lift, 0)
			holder.Parent = base
			emitter(name, table.clone(props), holder)
		end
	end
	local FIRE = CS({
		{ 0, hex("FFB040") },
		{ 0.3, hex("FF7012") },
		{ 0.7, hex("E23A00") },
		{ 1, hex("A01800") },
	})

	-- the floor glow where the fire burns (the pack's soft ring, lying flat, breathing a little)
	local glow = carrier("FireGlow", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, FEET + 0.08, 0))
	emitter("FireFloorGlow", {
		Texture = TEX.ring,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(0, 0),
		Speed = NR(0.001),
		LockedToPart = true,
		Size = NS({ { 0, 4.95 }, { 0.5, 5.15 }, { 1, 4.95 } }),
		Transparency = NS({ { 0, 1 }, { 0.3, 0.6 }, { 0.7, 0.6 }, { 1, 1 } }),
		Color = CS({ { 0, hex("FF6A10") }, { 1, hex("E03A00") } }),
		Lifetime = NR(1.6),
		Rate = 2 / 1.6,
		Brightness = 1.3,
	}, glow)
	cost(2 / 1.6, 1.6)

	-- the white-hot base band: small, fast, low
	local rate, life = 60, 0.35
	ringEmitter("FireCore", 0.26, 1, {
		Texture = TEX.flameLick,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
		Size = NS({ { 0, 0.3, 0.06 }, { 1, 0.3, 0.06 } }),
		Transparency = NS({ { 0, 0.15 }, { 0.8, 0.3 }, { 1, 1 } }),
		Color = CS({ { 0, hex("FFD27A") }, { 0.5, hex("FF9A2A") }, { 1, hex("FF5A00") } }),
		Lifetime = NR(life * 0.8, life * 1.2),
		Rate = rate,
		Speed = NR(0.2, 0.5),
		Rotation = NR(-8, 8),
		Brightness = 1.5,
		ZOffset = 0.05,
	})
	cost(rate, life)

	-- the flame body: one-shot licks, seamless round the rim
	rate, life = 80, 0.7
	ringEmitter("FireBody", 0.66, 1, {
		Texture = TEX.flameLick,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
		Size = NS({ { 0, 0.7, 0.12 }, { 1, 0.72, 0.12 } }),
		Transparency = NS({ { 0, 0.1 }, { 0.75, 0.2 }, { 1, 1 } }),
		Color = FIRE,
		Lifetime = NR(life * 0.8, life * 1.2),
		Rate = rate,
		Speed = NR(0.3, 0.8),
		Acceleration = Vector3.new(0, 0.6, 0),
		Drag = 0.8,
		Rotation = NR(-10, 10),
		-- partly additive: pure light vanished over the bright gold rim at the front (v1)
		LightEmission = 0.5,
		Brightness = 1.5,
	})
	cost(rate, life)

	-- tall tongues now and then: the crown's edge is uneven, never a fence
	rate, life = 7, 0.95
	ringEmitter("FireTongue", 1.05, 3, {
		Texture = TEX.flameLick,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
		Size = NS({ { 0, 1.05, 0.15 }, { 1, 1.1, 0.15 } }),
		Transparency = NS({ { 0, 0.15 }, { 0.75, 0.25 }, { 1, 1 } }),
		Color = FIRE,
		Lifetime = NR(life * 0.85, life * 1.15),
		Rate = rate,
		Speed = NR(0.4, 1.0),
		Acceleration = Vector3.new(0, 0.8, 0),
		Drag = 0.8,
		Rotation = NR(-12, 12),
		LightEmission = 0.55,
		Brightness = 1.45,
	})
	cost(rate, life)

	-- sparks spitting up out of the fire
	rate, life = 18, 0.8
	ringEmitter("FireSparks", 0.4, 3, {
		Texture = TEX.ember,
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NS({ { 0, 0.07 }, { 0.5, 0.06 }, { 1, 0 } }),
		Transparency = NS({ { 0, 0 }, { 0.8, 0.2 }, { 1, 1 } }),
		Color = RAMP,
		Lifetime = NR(life * 0.6, life * 1.3),
		Rate = rate,
		Speed = NR(2.5, 5),
		SpreadAngle = Vector2.new(22, 22),
		Acceleration = Vector3.new(0, -1.5, 0),
		Drag = 1.4,
		Brightness = 2,
		ZOffset = 0.2,
	})
	cost(rate, life)
end

---------------------------------------------------------------- EMBERS (rising off the seal)
do
	local vol = carrier(
		"EmberVolume",
		Vector3.new(SEAL_R * 1.8, 0.3, SEAL_R * 1.8),
		CFrame.new(0, FEET + 0.25, 0)
	)
	local rate, life = 10, 1.7
	emitter("Ember", {
		Texture = TEX.ember,
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NS({ { 0, 0.05 }, { 0.3, 0.1, 0.03 }, { 1, 0 } }),
		Transparency = NS({ { 0, 0 }, { 0.8, 0.15 }, { 1, 1 } }),
		Color = RAMP,
		Lifetime = NR(1.2, 2.2),
		Rate = rate,
		Speed = NR(1.4, 3.0),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(15, 15),
		Acceleration = Vector3.new(0, 0.8, 0),
		Drag = 0.6,
		Brightness = 1.8,
		ZOffset = 0.3,
	}, vol)
	cost(rate, life)
end

---------------------------------------------------------------- install
local report = {}
local assets = RS:WaitForChild("Assets")
local dest = assets:FindFirstChild("Auras")
if not dest then
	dest = Instance.new("Folder")
	dest.Name = "Auras"
	dest.Parent = assets
end
out:SetAttribute("Live", math.floor(live + 0.5))
out:SetAttribute("Source", "custom:sun_breathing (Solar Flare pack verbatim + Sun Seal base)")
out:SetAttribute("Tier", "E")
out:SetAttribute("K", 1)
local old = dest:FindFirstChild(KEY)
if old then
	old:Destroy()
end
out.Parent = dest
table.insert(report, ("%s built: live ~%d"):format(KEY, math.floor(live + 0.5)))

---------------------------------------------------------------- re-dress Yoriichi's preview stand
local yard = workspace:FindFirstChild("AuraAssignPreview")
local slot = yard and yard:FindFirstChild("Heroes") and yard.Heroes:FindFirstChild(SLOT)
local oldHero = slot and slot:FindFirstChild(HERO)
local template = assets.Characters:FindFirstChild("Char_" .. HERO)
if slot and oldHero and template then
	local pivot = oldHero:GetPivot()
	local hero = template:Clone()
	hero.Name = HERO
	for _, p in hero:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
		end
	end
	hero:PivotTo(pivot)
	local root = hero:FindFirstChild("HumanoidRootPart") :: BasePart
	local pose = {}
	for _, p in hero:GetChildren() do
		if p:IsA("BasePart") then
			pose[p.Name] = root.CFrame:ToObjectSpace(p.CFrame)
		end
	end
	local clone = out:Clone()
	for _, g in clone:GetChildren() do
		local target = hero:FindFirstChild(g.Name)
		if not target or not target:IsA("BasePart") then
			target = root
		end
		local rest = pose[target.Name] or CFrame.new()
		for _, piece in g:GetChildren() do
			if piece:IsA("Attachment") then
				piece.CFrame = rest:ToObjectSpace(piece.CFrame)
				piece.Parent = target
			elseif piece.Name == "Direct" then
				for _, e in piece:GetChildren() do
					e.Parent = target
				end
			elseif piece:IsA("BasePart") then
				local rootCf = piece:GetAttribute("RootCF")
				piece.Anchored = true
				piece.CFrame = root.CFrame
					* (if typeof(rootCf) == "CFrame" then rootCf else CFrame.new())
				piece.Parent = hero
			end
		end
	end
	clone:Destroy()
	oldHero:Destroy()
	hero.Parent = slot
	local signs = {}
	for _, d in slot:GetDescendants() do
		if d:IsA("TextLabel") then
			d.Text = string.gsub(d.Text, "Sun Breathing", "Solar Flare + Sun Seal")
			table.insert(signs, d.Text)
		end
	end
	table.insert(report, "preview stand re-dressed; sign: " .. table.concat(signs, " | "))
else
	table.insert(report, "no preview stand for Yoriichi (skipped)")
end

return table.concat(report, "\n")
