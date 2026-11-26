-- build_limitless.luau - Studio EDIT mode, rerunnable:
--   python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file tools/studio/auras/build_limitless.luau
-- Builds ReplicatedStorage.Assets.Auras.Limitless: Satoru Gojo's (limitless_teacher, Mythic) hero aura.
--
-- His body keeps the aura the OWNER TUNED for him, rebuilt exactly as the preview yard builds it
-- (tools/studio/build_aura_preview.luau): the Crimson Moon pack (ServerStorage.AuraPreview.Templates.P82) painted
-- with his palette (PALETTE below = tools/aura_assign.py PALETTES["limitless_teacher"]; keep the two in step),
-- plus the Infinite Reality pack (P52) cut down to its "Infinity Symbol" emitters, painted the same way.
-- Added round it, his Limitless (v2: v1's static orbs and flat floor were rejected as low effort):
--   VOID     Unlimited Void in three layers: the base (nebula, stars, galaxies, kanji 無量空処), a black hole with a
--            white-hot photon ring and a swirling accretion disc turning faster round his feet, and animated
--            streams of white information rushing inward, laid flat
--   ORBS     Lapse Blue (a bright ball of blue energy, swirls turning into it) and Reversal Red (a white-hot core,
--            tendrils flung out, sparks) orbiting him at chest height on opposite sides, animated flipbooks
--   PURPLE   Hollow Purple every 6 s above him, hand-animated: Blue and Red spiral in, collide in a flash, become a
--            crackling sphere of imaginary mass and implode into a shock ring
--   EYES     the Six Eyes: an anamorphic cyan-white flare at each eye, twinkling
--   STREAKS  thin streaks of light rising fast inside his dome
-- Textures: tools/auras/limitless/make_tex.py (ids in assets/auras/limitless/ids.json).
-- Layout is HeroAura.luau's template format (every CFrame in the hero ROOT's space at rest, R15, feet at y -3,
-- the hero faces -Z). ParticleEmitter Size is HALF the drawn width.

local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local TEX = {
	voidFloor = "rbxassetid://99010663947672",
	blackhole = "rbxassetid://86862768632320",
	stream = "rbxassetid://131967873711780", -- 4x4 loop
	blue = "rbxassetid://127018943018023", -- 4x4 loop
	red = "rbxassetid://113177053815419", -- 4x4 loop
	purple = "rbxassetid://86250424770502", -- 4x4 one-shot
	eyeFlare = "rbxassetid://114083036006750",
	streak = "rbxassetid://100353899392362",
	ember = "rbxassetid://94599216225372", -- SunBreathing's spark
}

local KEY = "Limitless"
local HERO = "limitless_teacher"
local SLOT = "Gojo"
local BASE = "P82" -- Crimson Moon
local EXTRA = "P52" -- Infinite Reality
local EXTRA_KEEP = { ["Infinity Symbol"] = true }
local OLD_NAME = "Crimson Moon %+ Infinite Reality: infinity symbol only"
local NEW_NAME = "Limitless"
local FEET = -3.0
local VOID_R = 3.5
local WHITE = Color3.new(1, 1, 1)

-- tools/aura_assign.py PALETTES["limitless_teacher"] (the owner's colour design for Gojo)
local PALETTE = {
	colours = {
		InnerSmoke = { { 0, "0B2A9E" }, { 0.5, "2F7BFF" }, { 1, "0B2A9E" } },
		Smoke = { { 0, "1F4FFF" }, { 0.6, "2F86FF" }, { 1, "5B2EE0" } },
		Ash = { { 0, "F2FDFF" }, { 0.5, "A6EEFF" }, { 1, "35C8FF" } },
		Mist = { { 0, "0F2A80" }, { 1, "2A1F80" } },
		Power = { { 0, "7FC8FF" }, { 1, "1E4BFF" } },
		Ring = { { 0, "FFFFFF" }, { 0.45, "8FE6FF" }, { 1, "2F7BFF" } },
		Pulsation = { { 0, "1A4BE8" }, { 1, "6FCBFF" } },
		["Infinity Symbol"] = { { 0, "FFFFFF" }, { 1, "B5F1FF" } },
	},
	brightness = { Smoke = 3, Power = 1.6, Ring = 3, Pulsation = 2.5, Ash = 12 },
	light = "4FA8FF",
}

local function NS(points)
	local kps = {}
	for _, p in points do
		table.insert(kps, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0))
	end
	return NumberSequence.new(kps)
end
local function NR(a, b)
	return NumberRange.new(a, b or a)
end
local function hex(h: string): Color3
	return Color3.fromHex(h)
end

local function emitter(name: string, props: { [string]: any }, parent: Instance): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.LightInfluence = 0
	e.LightEmission = 1
	e.Brightness = 1
	e.Color = ColorSequence.new(WHITE)
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

local function attach(bodyPart: string, name: string, cf: CFrame): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.CFrame = cf
	a:SetAttribute("RS", true)
	a.Parent = group(bodyPart)
	return a
end

local function carrier(name: string, size: Vector3, cf: CFrame, spin: Vector3?, body: string?): Part
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
	p.Parent = group(body or "HumanoidRootPart")
	return p
end

local live = 0
local function cost(rate: number, life: number, n: number?)
	live += rate * life * (n or 1)
end

-- build_aura_preview.luau's paint(): per emitter name a gradient and a Brightness, and the light colour
local function paint(root: Instance)
	for _, d in root:GetDescendants() do
		local rows = PALETTE.colours[d.Name]
		if (d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail")) and rows then
			local k = {}
			for _, r in rows do
				table.insert(k, ColorSequenceKeypoint.new(r[1], hex(r[2])))
			end
			d.Color = ColorSequence.new(k)
			if PALETTE.brightness[d.Name] then
				d.Brightness = PALETTE.brightness[d.Name]
			end
		elseif d:IsA("Light") then
			d.Color = hex(PALETTE.light)
		end
	end
end

-- move every piece of a (cloned) template into this aura's folders
local function merge(t: Instance)
	for _, g in t:GetChildren() do
		for _, piece in g:GetChildren() do
			piece.Parent = group(g.Name)
		end
	end
end

---------------------------------------------------------------- THE OWNER'S TUNED AURA (rebuilt exactly)
local templates = SS:FindFirstChild("AuraPreview") and SS.AuraPreview:FindFirstChild("Templates")
local base = templates and templates:FindFirstChild(BASE)
local extra = templates and templates:FindFirstChild(EXTRA)
assert(
	base and extra,
	"ServerStorage.AuraPreview.Templates.P82 / P52 missing: run tools/aura_assign.py build first"
)
do
	local b = base:Clone()
	paint(b)
	merge(b)
	b:Destroy()
	live += (base:GetAttribute("Live") or 0) :: number
	local cut = extra:Clone()
	for _, e in cut:GetDescendants() do
		if
			(e:IsA("ParticleEmitter") or e:IsA("Beam") or e:IsA("Trail") or e:IsA("Light"))
			and not EXTRA_KEEP[e.Name]
		then
			e:Destroy()
		end
	end
	for _, e in cut:GetDescendants() do
		if
			e.Parent
			and (e:IsA("BasePart") or e:IsA("Attachment"))
			and not e:FindFirstChildWhichIsA("ParticleEmitter", true)
		then
			e:Destroy()
		end
	end
	for _, e in cut:GetDescendants() do
		if e:IsA("ParticleEmitter") then
			live += e.Rate * (e.Lifetime.Min + e.Lifetime.Max) / 2
		end
	end
	paint(cut)
	merge(cut)
	cut:Destroy()
end

---------------------------------------------------------------- VOID (Unlimited Void, three layers deep)
do
	-- 1: the base (nebula, stars, galaxies, the kanji ring), turning slowly
	local function disc(
		name: string,
		d: number,
		y: number,
		spin: number,
		image: string,
		brightness: number
	)
		local p = carrier(
			name,
			Vector3.new(d, 0.05, d),
			CFrame.new(0, FEET + y, 0),
			Vector3.new(0, spin, 0)
		)
		local g = Instance.new("SurfaceGui")
		g.Name = "Image"
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
	disc("UnlimitedVoid", VOID_R * 2, 0.04, 0.06, TEX.voidFloor, 1.25)
	-- 2: the black hole at the void's heart, stood UPRIGHT behind him as a halo (Unlimited Void's shot of Gojo
	-- before the glowing ring): its black disc frames his white hair, the photon ring and the cobalt/violet
	-- accretion disc turn slowly round his head. (On the floor his legs hid it.)
	do
		local d = 6.6
		local p = carrier(
			"VoidHalo",
			Vector3.new(d, d, 0.05),
			CFrame.new(0, 2.25, 1.05),
			Vector3.new(0, 0, 0.3)
		)
		local g = Instance.new("SurfaceGui")
		g.Name = "Image"
		g.Face = Enum.NormalId.Front
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 64
		g.LightInfluence = 0
		g.Brightness = 1.3
		g.AlwaysOnTop = false
		g.ClipsDescendants = true
		g.Parent = p
		local img = Instance.new("ImageLabel")
		img.Name = "Image"
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = TEX.blackhole
		img.Parent = g
	end
	-- 3: streams of information rushing inward, laid flat (an animated flipbook, two copies a loop apart)
	local floor = carrier("InfoStream", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, FEET + 0.1, 0))
	emitter("InfoStream", {
		Texture = TEX.stream,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.Loop,
		FlipbookFramerate = NR(16),
		FlipbookStartRandom = false,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(0, 0),
		Speed = NR(0.001),
		LockedToPart = true,
		Size = NS({ { 0, 3.2 }, { 1, 3.2 } }),
		Transparency = NS({ { 0, 1 }, { 0.15, 0.15 }, { 0.85, 0.15 }, { 1, 1 } }),
		Color = ColorSequence.new(hex("E8FBFF"), hex("8FE6FF")),
		Lifetime = NR(2),
		Rate = 1,
		Brightness = 1.5,
		ZOffset = 0.1,
	}, floor)
	cost(1, 2)
end

---------------------------------------------------------------- BLUE and RED (orbiting him)
do
	-- Lapse Blue and Reversal Red on opposite sides of one turning frame at chest height. Each orb is an animated
	-- flipbook (16 frames a second) shown as two locked copies born exactly one loop apart, so they always show the
	-- same frame: the swirl never doubles, and the orb never blinks.
	local orbit = carrier(
		"OrbOrbit",
		Vector3.new(0.2, 0.2, 0.2),
		CFrame.new(0, 0.45, 0),
		Vector3.new(0, 0.75, 0)
	)
	local orbs = {
		{ "LapseBlue", 0, TEX.blue },
		{ "ReversalRed", math.pi, TEX.red },
	}
	local redPoint: Attachment? = nil
	for _, o in orbs do
		local a = Instance.new("Attachment")
		a.Name = o[1]
		a.CFrame = CFrame.new(math.cos(o[2]) * 2.45, 0, math.sin(o[2]) * 2.45)
		a.Parent = orbit
		emitter(o[1], {
			Texture = o[3],
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
			FlipbookMode = Enum.ParticleFlipbookMode.Loop,
			FlipbookFramerate = NR(16),
			FlipbookStartRandom = false,
			Orientation = Enum.ParticleOrientation.FacingCamera,
			LockedToPart = true,
			Size = NS({ { 0, 1.1 }, { 0.5, 1.18 }, { 1, 1.1 } }),
			Transparency = NS({ { 0, 1 }, { 0.12, 0 }, { 0.88, 0 }, { 1, 1 } }),
			Lifetime = NR(2),
			Rate = 1,
			Speed = NR(0),
			LightEmission = 0.1,
			Brightness = 1.4,
			ZOffset = 0.35,
		}, a)
		cost(1, 2)
		if o[1] == "ReversalRed" then
			redPoint = a
		end
	end
	-- Red repels: sparks flung out of it (they are left behind as it travels: a trail of repulsion)
	local rate, life = 10, 0.45
	emitter("ReversalSpark", {
		Texture = TEX.ember,
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NS({ { 0, 0.09 }, { 1, 0 } }),
		Transparency = NS({ { 0, 0 }, { 1, 0.4 } }),
		Color = ColorSequence.new(hex("FFE2C8"), hex("FF3A20")),
		Lifetime = NR(life * 0.7, life * 1.2),
		Rate = rate,
		Speed = NR(2.4, 3.8),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 3,
		LightEmission = 1,
		Brightness = 2,
		ZOffset = 0.4,
	}, redPoint :: Attachment)
	cost(rate, life)
end

---------------------------------------------------------------- HOLLOW PURPLE (the event above him)
do
	-- every 6 s the whole technique plays once, hand-animated in one flipbook: Blue and Red spiral in from either
	-- side, collide in a white flash, become a crackling sphere of imaginary mass, implode into a shock ring
	local a = attach("HumanoidRootPart", "HollowPurple", CFrame.new(0, 3.55, 0.35))
	local rate, life = 1 / 6, 2.2
	emitter("HollowPurple", {
		Texture = TEX.purple,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Orientation = Enum.ParticleOrientation.FacingCamera,
		LockedToPart = true,
		Size = NS({ { 0, 2.1 }, { 1, 2.1 } }),
		Transparency = NS({ { 0, 0 }, { 1, 0 } }),
		Lifetime = NR(life),
		Rate = rate,
		Speed = NR(0),
		LightEmission = 0.4,
		Brightness = 1.6,
		ZOffset = 0.2,
	}, a)
	cost(rate, life)
end

---------------------------------------------------------------- EYES (the Six Eyes)
do
	for _, side in { 1, -1 } do
		local a = attach("Head", "SixEyes", CFrame.new(side * 0.21, 1.66, -0.63))
		local life = 1.2
		emitter("SixEyes", {
			Texture = TEX.eyeFlare,
			Orientation = Enum.ParticleOrientation.FacingCamera,
			LockedToPart = true,
			Size = NS({ { 0, 0.55 }, { 0.25, 0.68 }, { 0.5, 0.58 }, { 0.75, 0.7 }, { 1, 0.55 } }),
			Transparency = NS({ { 0, 1 }, { 0.15, 0 }, { 0.85, 0 }, { 1, 1 } }),
			Color = ColorSequence.new(hex("FFFFFF"), hex("8FE6FF")),
			Lifetime = NR(life),
			Rate = 2 / life,
			Speed = NR(0),
			LightEmission = 1,
			Brightness = 2,
			ZOffset = 0.9,
		}, a)
		cost(2 / life, life)
	end
end

---------------------------------------------------------------- STREAKS (information rising in the dome)
do
	local vol = carrier("StreakVolume", Vector3.new(4.2, 0.4, 3.4), CFrame.new(0, FEET + 0.4, 0.3))
	local rate, life = 5, 0.7
	emitter("InfoStreak", {
		Texture = TEX.streak,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Size = NS({ { 0, 0.45 }, { 1, 0.6 } }),
		Transparency = NS({ { 0, 0.2 }, { 0.7, 0.35 }, { 1, 1 } }),
		Color = ColorSequence.new(hex("FFFFFF"), hex("6FCBFF")),
		Lifetime = NR(life * 0.8, life * 1.2),
		Rate = rate,
		Speed = NR(5, 8),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(3, 3),
		Drag = 1,
		LightEmission = 1,
		Brightness = 1.6,
		ZOffset = 0.2,
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
out:SetAttribute(
	"Source",
	"custom:limitless v2 (owner's tuned Crimson Moon + infinity symbol, Blue, Red, Hollow Purple, Unlimited Void)"
)
out:SetAttribute("Tier", "E")
out:SetAttribute("K", 1)
local old = dest:FindFirstChild(KEY)
if old then
	old:Destroy()
end
out.Parent = dest
table.insert(report, ("%s built: live ~%d"):format(KEY, math.floor(live + 0.5)))

---------------------------------------------------------------- re-dress Gojo's preview stand
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
		if g.Name == "Beams" then
			continue
		end
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
	local beams = clone:FindFirstChild("Beams")
	if beams then
		for _, b in beams:GetChildren() do
			b.Parent = root
		end
	end
	clone:Destroy()
	oldHero:Destroy()
	hero.Parent = slot
	local signs = {}
	for _, d in slot:GetDescendants() do
		if d:IsA("TextLabel") then
			d.Text = string.gsub(d.Text, OLD_NAME, NEW_NAME)
			table.insert(signs, d.Text)
		end
	end
	table.insert(report, "preview stand re-dressed; sign: " .. table.concat(signs, " | "))
else
	table.insert(report, "no preview stand for Gojo (skipped)")
end

return table.concat(report, "\n")
