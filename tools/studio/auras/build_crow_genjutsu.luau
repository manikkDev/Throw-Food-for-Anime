-- build_crow_genjutsu.luau - Studio EDIT mode, rerunnable:
--   python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file tools/studio/auras/build_crow_genjutsu.luau
-- Builds ReplicatedStorage.Assets.Auras.CrowGenjutsu: Itachi Uchiha's (crow_illusionist) hero aura,
-- hand-authored with the roblox-vfx skill's authoring route. Every texture is our own
-- (tools/auras/crow_genjutsu/make_tex.py, ids in assets/auras/crow_genjutsu/ids.json).
-- Then re-dresses Itachi's stand in Workspace.AuraAssignPreview (if it is there) with it.
-- Layout is HeroAura.luau's template format (every CFrame in the hero ROOT's space at rest, R15,
-- feet at y -3, the hero faces -Z):
--   <BodyPart>/<Attachment RS=true>/<emitter>   rides that body part
--   <BodyPart>/Direct/<light>                    parented to the body part itself
--   HumanoidRootPart/<Part RootCF, Spin>/...     welded to the root, turned while live
--
-- The look (the owner's key art: ink-black shapes rimmed in crimson, crows, a blood moon red):
--   SIGIL     his Mangekyo pinwheel under his feet, a ring of three tomoe and gliding crows round it,
--             the two turning opposite ways (SurfaceGui, self-lit, normal blend: reads on a pale floor)
--   AMATERASU black flame tongues licking up round his feet, taller ones behind his shoulders
--   INK       ink smoke billowing low round his legs and eroding away
--   MURDER    crows circling him on a turning ring, each fading in and out like an illusion,
--             and single crows taking off from his shoulders
--   FEATHERS  black feathers tumbling down round him
--   EMBERS    small crimson sparks rising (the only additive layer: tiny, never over the black)
--   MOON      Tsukuyomi's blood moon behind his head and shoulders (a self-lit billboard, depth
--             tested: his body hides its middle, the circling crows cross in front of it)
--   ARCS      rare crimson-violet lightning flickering round his body (additive, a few frames each)
--   EYES      a red glint at each eye (the sharingan)
--   LIGHT     one crimson point light (no shadows)
-- A dark aura must not glow: every dark layer is pre-coloured in its texture and drawn with Color
-- white, LightEmission 0, LightInfluence 0 (an additive red over black reads as candy floss).

local RS = game:GetService("ReplicatedStorage")

local TEX = {
	flame = "rbxassetid://106559804619350",
	crow = "rbxassetid://121492025226654",
	ember = "rbxassetid://110141306941410",
	feather = "rbxassetid://75172166514409",
	glow = "rbxassetid://134564573698323",
	smoke = "rbxassetid://73431300485165",
	mangekyo = "rbxassetid://96027688255397",
	tomoe = "rbxassetid://114290542573134",
	moon = "rbxassetid://104441794720027",
	lightning = "rbxassetid://125518386322481",
}

local KEY = "CrowGenjutsu"
local FEET = -3.0
local WHITE = Color3.new(1, 1, 1)

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
local function NR(a, b)
	return NumberRange.new(a, b or a)
end

-- one emitter from a table of properties (anything not given keeps Roblox's default)
local function emitter(name: string, props: { [string]: any }, parent: Instance): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.LightInfluence = 0
	e.LightEmission = 0
	e.Color = CS({ { 0, WHITE }, { 1, WHITE } })
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

-- dark, pre-coloured flipbook layer defaults (see the header)
local function dark(t: { [string]: any }): { [string]: any }
	t.LightEmission = 0
	t.LightInfluence = 0
	t.Brightness = 1
	t.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
	return t
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

-- an attachment that rides `bodyPart`, placed in ROOT space (HeroAura converts it)
local function attach(bodyPart: string, name: string, cf: CFrame): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.CFrame = cf
	a:SetAttribute("RS", true)
	a.Parent = group(bodyPart)
	return a
end

-- an invisible carrier part welded to the root (volume emitters, spinning rings)
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

-- a flat self-lit image on a carrier's top face (the ground sigil)
local function decalDisc(p: Part, image: string, transparency: number, brightness: number)
	local g = Instance.new("SurfaceGui")
	g.Name = "Sigil"
	g.Face = Enum.NormalId.Top
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 72
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
	img.ImageTransparency = transparency
	img.Parent = g
end

local live = 0
local function cost(rate: number, life: number, n: number?)
	live += rate * life * (n or 1)
end

---------------------------------------------------------------- SIGIL (ground, turning both ways)
do
	local core = carrier("SigilCore", Vector3.new(4.6, 0.05, 4.6), CFrame.new(0, FEET + 0.03, 0), Vector3.new(0, 0.45, 0))
	decalDisc(core, TEX.mangekyo, 0.05, 1.15)
	local ring = carrier("SigilRing", Vector3.new(7.0, 0.05, 7.0), CFrame.new(0, FEET + 0.05, 0), Vector3.new(0, -0.28, 0))
	decalDisc(ring, TEX.tomoe, 0, 1.1)
end

---------------------------------------------------------------- AMATERASU (black flames)
do
	-- round his feet: a ring-shaped volume would be ideal; a flat box under the robe reads the same
	local feet = carrier("FlameFeet", Vector3.new(4.6, 0.2, 3.4), CFrame.new(0, FEET + 0.25, 0)) -- wider than him: tongues show beside his legs
	local rate, life = 20, 1.0
	emitter("BlackFlame", dark({
		Texture = TEX.flame,
		FlipbookMode = Enum.ParticleFlipbookMode.Loop,
		FlipbookFramerate = NR(18, 24),
		FlipbookStartRandom = true,
		Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
		Size = NS({ { 0, 0.55 }, { 0.18, 1.35, 0.2 }, { 0.7, 1.25, 0.15 }, { 1, 0.35 } }),
		Transparency = NS({ { 0, 1 }, { 0.12, 0 }, { 0.78, 0.05 }, { 1, 1 } }),
		Lifetime = NR(0.75, 1.15),
		Rate = rate,
		Speed = NR(1.0, 2.2),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(8, 8),
		Acceleration = Vector3.new(0, 1.6, 0),
		Drag = 0.8,
		Rotation = NR(-7, 7),
		RotSpeed = NR(-10, 10),
	}), feet)
	cost(rate, life)

	-- taller tongues in two columns behind his shoulders, FLANKING the moon (one column over the
	-- middle smeared the moon into a red mass in Studio, v4)
	for _, side in { 1, -1 } do
		local back = carrier("FlameBack", Vector3.new(1.3, 1.0, 0.4), CFrame.new(side * 1.75, 1.5, 0.75))
		rate, life = 6, 1.2
		emitter("BlackFlameTall", dark({
			Texture = TEX.flame,
			FlipbookMode = Enum.ParticleFlipbookMode.Loop,
			FlipbookFramerate = NR(16, 22),
			FlipbookStartRandom = true,
			Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
			Size = NS({ { 0, 0.8 }, { 0.2, 2.1, 0.25 }, { 0.75, 1.9, 0.2 }, { 1, 0.6 } }),
			Transparency = NS({ { 0, 1 }, { 0.15, 0 }, { 0.75, 0.08 }, { 1, 1 } }),
			Lifetime = NR(0.95, 1.4),
			Rate = rate,
			Speed = NR(1.4, 2.4),
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(6, 4),
			Acceleration = Vector3.new(side * 0.5, 1.2, 0), -- lean outward, away from the moon
			Drag = 0.9,
			Rotation = NR(-9, 9),
			ZOffset = -1.2,
		}), back)
		cost(rate, life)
	end
end

---------------------------------------------------------------- INK (smoke at his legs)
do
	local pool = carrier("InkPool", Vector3.new(4.2, 0.6, 3.4), CFrame.new(0, FEET + 0.5, 0.2))
	local rate, life = 5, 1.8
	emitter("InkSmoke", dark({
		Texture = TEX.smoke,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NS({ { 0, 0.7 }, { 0.5, 1.3, 0.15 }, { 1, 1.5, 0.15 } }),
		Transparency = NS({ { 0, 0.15 }, { 0.7, 0.2 }, { 1, 0.5 } }),
		Lifetime = NR(1.5, 2.1),
		Rate = rate,
		Speed = NR(0.4, 0.9),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(55, 55),
		Acceleration = Vector3.new(0, 0.5, 0),
		Drag = 1.2,
		Rotation = NR(0, 360),
		RotSpeed = NR(-18, 18),
		ZOffset = -0.4,
	}), pool)
	cost(rate, life)
end

---------------------------------------------------------------- MURDER (crows)
do
	-- a turning ring at chest height: each crow is locked to its point on the ring, so it circles him;
	-- one crow per point at a time (interval 1/Rate > Lifetime), fading in and out like an illusion
	local orbit = carrier("CrowOrbit", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 0.6, 0), Vector3.new(0, -1.05, 0))
	local points = {
		CFrame.new(2.9, 0.2, 0),
		CFrame.new(-1.6, 1.4, 2.3),
		CFrame.new(-1.3, -0.5, -2.6),
		CFrame.new(1.1, 2.2, -2.2),
	}
	for i, cf in points do
		local a = Instance.new("Attachment")
		a.Name = "Crow" .. i
		a.CFrame = cf
		a.Parent = orbit
		local rate, life = 0.3, 2.9
		emitter("CircleCrow", dark({
			Texture = TEX.crow,
			FlipbookMode = Enum.ParticleFlipbookMode.Loop,
			FlipbookFramerate = NR(17, 21),
			FlipbookStartRandom = true,
			Orientation = Enum.ParticleOrientation.FacingCamera,
			LockedToPart = true,
			Size = NS({ { 0, 0.7 }, { 0.2, 1.0 }, { 0.8, 1.0 }, { 1, 0.75 } }),
			Transparency = NS({ { 0, 1 }, { 0.18, 0 }, { 0.78, 0 }, { 1, 1 } }),
			Lifetime = NR(2.6, 3.0),
			Rate = rate,
			Speed = NR(0, 0),
			Rotation = NR(-14, 14),
		}), a)
		cost(rate, life)
	end

	-- a crow taking off from each shoulder now and then, up and out, gone in a few studs
	for _, side in { 1, -1 } do
		local a = attach("UpperTorso", "CrowLaunch", CFrame.new(side * 0.95, 0.85, 0.15) * CFrame.Angles(0, 0, -side * 0.55))
		local rate, life = 0.45, 1.8
		emitter("LaunchCrow", dark({
			Texture = TEX.crow,
			FlipbookMode = Enum.ParticleFlipbookMode.Loop,
			FlipbookFramerate = NR(24, 28),
			FlipbookStartRandom = true,
			Orientation = Enum.ParticleOrientation.FacingCamera,
			Size = NS({ { 0, 0.2 }, { 0.22, 0.72 }, { 0.8, 0.78 }, { 1, 0.4 } }),
			Transparency = NS({ { 0, 1 }, { 0.1, 0 }, { 0.72, 0 }, { 1, 1 } }),
			Lifetime = NR(1.5, 2.0),
			Rate = rate,
			Speed = NR(2.8, 4.0),
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(22, 22),
			Acceleration = Vector3.new(0, 0.9, 0),
			Drag = 0.9,
			Rotation = NR(-15, 15),
		}), a)
		cost(rate, life)
	end
end

---------------------------------------------------------------- FEATHERS (tumbling down)
do
	local cloud = carrier("FeatherCloud", Vector3.new(5.0, 1.2, 3.4), CFrame.new(0, 2.9, 0.2))
	local rate, life = 3.2, 3.0
	emitter("Feather", dark({
		Texture = TEX.feather,
		FlipbookMode = Enum.ParticleFlipbookMode.Loop,
		FlipbookFramerate = NR(8, 14),
		FlipbookStartRandom = true,
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NS({ { 0, 0.3 }, { 1, 0.34 } }),
		Transparency = NS({ { 0, 1 }, { 0.12, 0 }, { 0.8, 0 }, { 1, 1 } }),
		Lifetime = NR(2.6, 3.4),
		Rate = rate,
		Speed = NR(0.2, 0.6),
		EmissionDirection = Enum.NormalId.Bottom,
		SpreadAngle = Vector2.new(30, 30),
		Acceleration = Vector3.new(0.2, -1.1, 0),
		Drag = 1.3,
		Rotation = NR(0, 360),
		RotSpeed = NR(-80, 80),
	}), cloud)
	cost(rate, life)
end

---------------------------------------------------------------- EMBERS (tiny, additive)
do
	local vol = carrier("EmberVolume", Vector3.new(3.2, 1.8, 2.6), CFrame.new(0, FEET + 1.0, 0))
	local rate, life = 11, 1.3
	emitter("Ember", {
		Texture = TEX.ember,
		LightEmission = 1,
		LightInfluence = 0,
		Brightness = 2.2,
		Color = CS({ { 0, rgb(255, 120, 80) }, { 0.35, rgb(255, 36, 40) }, { 1, rgb(140, 0, 12) } }),
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NS({ { 0, 0.05 }, { 0.25, 0.12, 0.04 }, { 1, 0 } }),
		Transparency = NS({ { 0, 0 }, { 0.75, 0.15 }, { 1, 1 } }),
		Lifetime = NR(1.0, 1.6),
		Rate = rate,
		Speed = NR(1.4, 3.0),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(28, 28),
		Acceleration = Vector3.new(0, 1.0, 0),
		Drag = 0.7,
		ZOffset = 0.4,
	}, vol)
	cost(rate, life)
end

---------------------------------------------------------------- MOON (Tsukuyomi)
do
	local a = attach("HumanoidRootPart", "MoonAnchor", CFrame.new(0, 2.4, 1.35))
	local g = Instance.new("BillboardGui")
	g.Name = "BloodMoon"
	g.Size = UDim2.fromScale(4.4, 4.4) -- studs; the disc is 0.74 of it, the rest is its halo
	g.LightInfluence = 0
	g.Brightness = 0.9 -- above 1 the disc saturates to one flat red and the craters are lost
	g.AlwaysOnTop = false
	g.MaxDistance = 140
	g.ResetOnSpawn = false
	g.Parent = a
	local img = Instance.new("ImageLabel")
	img.Name = "Image"
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = TEX.moon
	img.ImageTransparency = 0.12
	img.Parent = g
end

---------------------------------------------------------------- ARCS (crimson-violet lightning)
do
	local vol = carrier("ArcVolume", Vector3.new(3.2, 3.6, 1.8), CFrame.new(0, 0.1, 0))
	local rate, life = 2.4, 0.17
	emitter("Arc", {
		Texture = TEX.lightning,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.Loop,
		FlipbookFramerate = NR(26, 32),
		FlipbookStartRandom = true,
		LightEmission = 1,
		LightInfluence = 0,
		Brightness = 2.6,
		Color = CS({ { 0, rgb(255, 60, 80) }, { 0.5, rgb(235, 40, 90) }, { 1, rgb(160, 60, 255) } }),
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NS({ { 0, 0.8 }, { 1, 1.1 } }),
		Transparency = NS({ { 0, 0 }, { 0.6, 0.1 }, { 1, 1 } }),
		Lifetime = NR(0.12, 0.22),
		Rate = rate,
		Speed = NR(0),
		Rotation = NR(0, 360),
		ZOffset = 0.5,
	}, vol)
	cost(rate, life)
end

---------------------------------------------------------------- EYES (sharingan glint)
do
	for _, side in { 1, -1 } do
		local a = attach("Head", "EyeGlint", CFrame.new(side * 0.2, 1.66, -0.61))
		local rate, life = 5, 0.4
		emitter("Eye", {
			Texture = TEX.ember,
			LightEmission = 1,
			LightInfluence = 0,
			Brightness = 3,
			Color = CS({ { 0, rgb(255, 215, 215) }, { 0.5, rgb(255, 70, 70) }, { 1, rgb(255, 20, 30) } }), -- white-hot: red on his red eyes did not show
			Orientation = Enum.ParticleOrientation.FacingCamera,
			LockedToPart = true,
			Size = NS({ { 0, 0.06 }, { 0.5, 0.11 }, { 1, 0.06 } }),
			Transparency = NS({ { 0, 0.4 }, { 0.5, 0.1 }, { 1, 0.4 } }),
			Lifetime = NR(life),
			Rate = rate,
			Speed = NR(0),
			ZOffset = 0.25,
		}, a)
		cost(rate, life)
	end
end

---------------------------------------------------------------- LIGHT
do
	local d = Instance.new("Folder")
	d.Name = "Direct"
	d.Parent = group("UpperTorso")
	local l = Instance.new("PointLight")
	l.Name = "CrimsonLight"
	l.Color = rgb(255, 34, 44)
	l.Brightness = 1.6
	l.Range = 9
	l.Shadows = false
	l.Parent = d
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
out:SetAttribute("Source", "custom:crow_genjutsu")
out:SetAttribute("Tier", "C")
out:SetAttribute("K", 1)
local old = dest:FindFirstChild(KEY)
if old then
	old:Destroy()
end
out.Parent = dest
table.insert(report, ("%s built: live ~%d"):format(KEY, math.floor(live + 0.5)))

---------------------------------------------------------------- re-dress Itachi's preview stand
-- (Workspace.AuraAssignPreview, dev only; built by tools/aura_assign.py): a fresh hero from the
-- template, the aura put on the way build_aura_preview.luau's attach does (anchored, no spin)
local yard = workspace:FindFirstChild("AuraAssignPreview")
local slot = yard and yard:FindFirstChild("Heroes") and yard.Heroes:FindFirstChild("Itachi Uchiha")
local oldHero = slot and slot:FindFirstChild("crow_illusionist")
local template = assets.Characters:FindFirstChild("Char_crow_illusionist")
if slot and oldHero and template then
	local pivot = oldHero:GetPivot()
	local hero = template:Clone()
	hero.Name = "crow_illusionist"
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
				piece.CFrame = root.CFrame * (if typeof(rootCf) == "CFrame" then rootCf else CFrame.new())
				piece.Parent = hero
			end
		end
	end
	clone:Destroy()
	oldHero:Destroy()
	hero.Parent = slot
	-- the stand's sign names the aura
	local renamed = 0
	for _, d in slot:GetDescendants() do
		if d:IsA("TextLabel") and string.find(d.Text, "InkShadow", 1, true) then
			d.Text = string.gsub(d.Text, "InkShadow", "Crow Genjutsu")
			renamed += 1
		end
	end
	table.insert(report, ("preview stand re-dressed (%d sign line(s) renamed)"):format(renamed))
else
	table.insert(report, "no preview stand for Itachi (skipped)")
end

return table.concat(report, "\n")
