-- build_emperor_thorns.luau - Studio EDIT mode, rerunnable:
--   python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file tools/studio/auras/build_emperor_thorns.luau
-- Builds ReplicatedStorage.Assets.Auras.EmperorThorns: Michael Kaiser's (emperor_striker) hero aura,
-- hand-authored with the roblox-vfx skill's authoring route. Every texture is our own
-- (tools/auras/emperor_thorns/make_tex.py, ids in assets/auras/emperor_thorns/ids.json).
-- Then re-dresses Kaiser's stand in Workspace.AuraAssignPreview (if it is there) with it.
-- Layout is HeroAura.luau's template format (every CFrame in the hero ROOT's space at rest, R15,
-- feet at y -3, the hero faces -Z):
--   <BodyPart>/<Attachment RS=true>/<emitter>   rides that body part
--   <BodyPart>/Direct/<light>                    parented to the body part itself
--   <BodyPart>/<Part RootCF, Spin>/...           welded to that body part, turned while live
--   Beams/<beam>                                 parented to the root (refs survive the clone)
--
-- No flames (owner, 2026-11-25: flames on every hero are repetitive; Kaiser's is roses, thorns, a crown).
-- The look (Blue Lock: Kaiser's blue-rose tattoo, its thorn stem from his neck down his left arm, the
-- thorns that lead to a crown, and the Kaiser Impact drawn as blue lightning):
--   SIGIL    a full blue rose on a thorn wreath under his feet, a gold ring with four crowns round it,
--            the two turning opposite ways
--   ROSES    three blue roses blooming in turn round his feet on a slowly turning frame (no thorn vines:
--            the owner had them removed, 2026-11-25)
--   CREST    three blue roses blooming behind his head and shoulders, the middle one behind the crown
--   PETALS   blue rose petals spiralling up off a turning ring; more shed off the tattoo at his neck
--   CROWN    a gold crown of eight prong panels floating over his head (rides the head), glints on it
--   IMPACT   Kaiser Impact: blue lightning crackling at his legs, a shock ring snapping out from his
--            feet, speed streaks shooting up past him
--   GLINTS   sapphire four-point twinkles, a soft blue backlight, one blue point light
-- Cel layers (roses, petals, crown) are pre-coloured with a navy ink line and drawn with
-- Color white, LightEmission <= 0.25, LightInfluence 0, so they read on the bright 13:12 floor; only the
-- lightning, ring, streaks and glints are additive.

local RS = game:GetService("ReplicatedStorage")

local TEX = {
	bolt = "rbxassetid://134403280705031",
	crown = "rbxassetid://82632930393869",
	glint = "rbxassetid://97166343843469",
	glow = "rbxassetid://92224141650572",
	petal = "rbxassetid://97402209773928",
	rose = "rbxassetid://94097828076099",
	shock = "rbxassetid://120676903869333",
	sigilCore = "rbxassetid://101965845438465",
	sigilRing = "rbxassetid://84472565839333",
}

local KEY = "EmperorThorns"
local HERO = "emperor_striker"
local SLOT = "Kaiser"
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

-- pre-coloured cel layer defaults
local function cel(t: { [string]: any }): { [string]: any }
	t.LightEmission = t.LightEmission or 0
	t.LightInfluence = 0
	t.Brightness = t.Brightness or 1
	t.FlipbookLayout = t.FlipbookLayout or Enum.ParticleFlipbookLayout.Grid4x4
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

local function surfaceImage(
	p: Part,
	face: Enum.NormalId,
	image: string,
	transparency: number,
	brightness: number,
	pps: number
)
	local g = Instance.new("SurfaceGui")
	g.Name = "Img" .. face.Name
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = pps
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
	local core = carrier(
		"SigilCore",
		Vector3.new(4.2, 0.05, 4.2),
		CFrame.new(0, FEET + 0.03, 0),
		Vector3.new(0, 0.32, 0)
	)
	surfaceImage(core, Enum.NormalId.Top, TEX.sigilCore, 0.04, 1.15, 72)
	local ring = carrier(
		"SigilRing",
		Vector3.new(7.2, 0.05, 7.2),
		CFrame.new(0, FEET + 0.05, 0),
		Vector3.new(0, -0.2, 0)
	)
	surfaceImage(ring, Enum.NormalId.Top, TEX.sigilRing, 0, 1.1, 72)
end

---------------------------------------------------------------- ROSES (blooming round his feet)
do
	-- three blue roses blooming in turn round his feet on a slowly turning frame (they were the roots of
	-- thorn vines that spiralled up him; the owner had the vines removed, 2026-11-25: "it looks bad")
	local frame = carrier(
		"RoseFrame",
		Vector3.new(0.2, 0.2, 0.2),
		CFrame.new(0, 0, 0),
		Vector3.new(0, 0.42, 0)
	)
	for v = 1, 3 do
		local a = (v - 1) * (2 * math.pi / 3) + 0.35
		local att = Instance.new("Attachment")
		att.Name = "Rose" .. v
		att.CFrame = CFrame.new(math.cos(a) * 1.55, FEET + 0.15, math.sin(a) * 1.55)
		att.Parent = frame
		local rate, life = 0.34, 1.9
		emitter(
			"RoseBloom",
			cel({
				Texture = TEX.rose,
				FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
				Orientation = Enum.ParticleOrientation.FacingCamera,
				LockedToPart = true,
				Size = NS({ { 0, 1.05 }, { 1, 1.2 } }),
				Transparency = NS({ { 0, 0 }, { 1, 0 } }),
				Lifetime = NR(life - 0.2, life + 0.2),
				Rate = rate,
				Speed = NR(0),
				Rotation = NR(-25, 25),
				RotSpeed = NR(-6, 6),
				Brightness = 1.1,
			}),
			att
		)
		cost(rate, life)
	end
end

---------------------------------------------------------------- CREST (blue roses blooming behind him)
do
	-- the emperor's backdrop: three roses fanned behind his head and shoulders, blooming and shedding in
	-- turn; drawn behind him (ZOffset), so his silhouette cuts them and the middle one haloes his head
	local spots = {
		{ CFrame.new(-1.75, 1.45, 0.9), 1.6, 0.0 }, -- out past the shoulders: at x 1.25 his arms hid them (v3)
		{ CFrame.new(0, 2.5, 1.0), 1.9, 0.6 }, -- behind the crown
		{ CFrame.new(1.75, 1.45, 0.9), 1.6, 1.2 },
	}
	for i, sp in spots do
		local a = attach("UpperTorso", "Crest" .. i, sp[1])
		local rate, life = 0.42, 2.3
		emitter(
			"CrestRose",
			cel({
				Texture = TEX.rose,
				FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
				Orientation = Enum.ParticleOrientation.FacingCamera,
				LockedToPart = true,
				Size = NS({ { 0, sp[2] * 0.92 }, { 1, sp[2] } }),
				Transparency = NS({ { 0, 0 }, { 1, 0 } }),
				Lifetime = NR(life),
				Rate = rate,
				Speed = NR(0),
				Rotation = NR(-20, 20),
				RotSpeed = NR(-5, 5),
				ZOffset = -2.2,
				Brightness = 1.1,
			}),
			a
		)
		cost(rate, life)
	end
end

---------------------------------------------------------------- PETALS (spiral up; shed off the tattoo)
do
	local orbit = carrier(
		"PetalOrbit",
		Vector3.new(0.2, 0.2, 0.2),
		CFrame.new(0, -1.6, 0),
		Vector3.new(0, 1.15, 0)
	)
	for i = 1, 4 do
		local a = (i - 1) * math.pi / 2
		local att = Instance.new("Attachment")
		att.Name = "PetalPoint" .. i
		att.CFrame = CFrame.new(math.cos(a) * 2.15, (i % 2) * 0.9, math.sin(a) * 2.15)
		att.Parent = orbit
		local rate, life = 3.6, 2.6
		emitter(
			"Petal",
			cel({
				Texture = TEX.petal,
				FlipbookMode = Enum.ParticleFlipbookMode.Loop,
				FlipbookFramerate = NR(10, 18),
				FlipbookStartRandom = true,
				Orientation = Enum.ParticleOrientation.FacingCamera,
				Size = NS({ { 0, 0 }, { 0.12, 0.44, 0.08 }, { 0.8, 0.4, 0.06 }, { 1, 0 } }),
				Transparency = NS({ { 0, 0 }, { 0.85, 0.05 }, { 1, 1 } }),
				Lifetime = NR(2.2, 3.0),
				Rate = rate,
				Speed = NR(0.8, 1.6),
				EmissionDirection = Enum.NormalId.Top,
				SpreadAngle = Vector2.new(40, 40),
				Acceleration = Vector3.new(0, 0.55, 0),
				Drag = 0.7,
				Rotation = NR(0, 360),
				RotSpeed = NR(-120, 120),
				Brightness = 1.15,
			}),
			att
		)
		cost(rate, life)
	end

	-- the tattoo: a blue rose at the left of his neck, its stem down the left arm (canon): a faint glint
	-- there and petals peeling off it, drifting down along the arm
	local neck = attach("UpperTorso", "TattooRose", CFrame.new(-0.42, 0.98, -0.05))
	local rate, life = 1.8, 1.8
	emitter(
		"TattooPetal",
		cel({
			Texture = TEX.petal,
			FlipbookMode = Enum.ParticleFlipbookMode.Loop,
			FlipbookFramerate = NR(12, 18),
			FlipbookStartRandom = true,
			Orientation = Enum.ParticleOrientation.FacingCamera,
			Size = NS({ { 0, 0.1 }, { 0.2, 0.24 }, { 1, 0.18 } }),
			Transparency = NS({ { 0, 0.2 }, { 0.15, 0 }, { 0.8, 0.1 }, { 1, 1 } }),
			Lifetime = NR(1.5, 2.1),
			Rate = rate,
			Speed = NR(0.6, 1.1),
			EmissionDirection = Enum.NormalId.Left,
			SpreadAngle = Vector2.new(35, 35),
			Acceleration = Vector3.new(-0.25, -0.9, 0),
			Drag = 0.8,
			Rotation = NR(0, 360),
			RotSpeed = NR(-140, 140),
			Brightness = 1.15,
			ZOffset = 0.2,
		}),
		neck
	)
	cost(rate, life)
	rate, life = 2.5, 0.9
	emitter("TattooGlint", {
		Texture = TEX.glint,
		LightEmission = 1,
		Brightness = 2.4,
		Color = CS({ { 0, rgb(200, 236, 255) }, { 1, rgb(60, 130, 255) } }),
		Orientation = Enum.ParticleOrientation.FacingCamera,
		LockedToPart = true,
		Size = NS({ { 0, 0 }, { 0.4, 0.5 }, { 1, 0 } }),
		Transparency = NS({ { 0, 0.1 }, { 1, 0.4 } }),
		Lifetime = NR(life),
		Rate = rate,
		Speed = NR(0),
		Rotation = NR(0, 45),
		ZOffset = 0.5,
	}, neck)
	cost(rate, life)
end

---------------------------------------------------------------- CROWN (eight gold prong panels over his head)
do
	local N = 8
	local W, H = 0.66, 0.82 -- the panel texture is 256 x 320
	local r = W / (2 * math.tan(math.pi / N)) -- panels meet edge to edge
	local headTop = 1.49 + 0.6
	local cy = headTop + 0.22 + H / 2
	for i = 1, N do
		local a = (i - 1) * 2 * math.pi / N
		-- in the HEAD's group (rides the head), placed in root space; flared out 9 degrees
		local cf = CFrame.new(0, cy, 0)
			* CFrame.Angles(0, a, 0)
			* CFrame.new(0, 0, -r)
			* CFrame.Angles(math.rad(-9), 0, 0)
		local p = carrier("CrownPanel", Vector3.new(W, H, 0.02), cf, nil, "Head")
		surfaceImage(p, Enum.NormalId.Front, TEX.crown, 0.02, 1.35, 160)
		surfaceImage(p, Enum.NormalId.Back, TEX.crown, 0.18, 0.85, 160) -- the inside: dimmer
	end
	local a = attach("Head", "CrownSpark", CFrame.new(0, cy + 0.05, 0))
	local rate, life = 3.2, 0.8
	emitter("CrownGlint", {
		Texture = TEX.glint,
		LightEmission = 1,
		Brightness = 2.6,
		Color = CS({ { 0, rgb(255, 246, 210) }, { 1, rgb(255, 214, 110) } }),
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Shape = Enum.ParticleEmitterShape.Cylinder,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
		LockedToPart = true,
		Size = NS({ { 0, 0 }, { 0.35, 0.42 }, { 1, 0 } }),
		Transparency = NS({ { 0, 0 }, { 1, 0.3 } }),
		Lifetime = NR(0.6, 1.0),
		Rate = rate,
		Speed = NR(0),
		Rotation = NR(0, 45),
		ZOffset = 0.6,
	}, a)
	cost(rate, life)
end

---------------------------------------------------------------- IMPACT (lightning, shock ring, streaks)
do
	local legs = carrier("ImpactVolume", Vector3.new(2.6, 2.4, 1.6), CFrame.new(0.25, -1.8, 0))
	local rate, life = 3.0, 0.18
	emitter("ImpactBolt", {
		Texture = TEX.bolt,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.Loop,
		FlipbookFramerate = NR(28, 34),
		FlipbookStartRandom = true,
		LightEmission = 1,
		Brightness = 3,
		Color = CS({
			{ 0, rgb(225, 245, 255) },
			{ 0.5, rgb(90, 175, 255) },
			{ 1, rgb(40, 90, 255) },
		}),
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NS({ { 0, 1.1 }, { 1, 1.5 } }),
		Transparency = NS({ { 0, 0 }, { 0.6, 0.1 }, { 1, 1 } }),
		Lifetime = NR(0.13, 0.22),
		Rate = rate,
		Speed = NR(0),
		Rotation = NR(0, 360),
		ZOffset = 0.6,
	}, legs)
	cost(rate, life)

	local ground = carrier("ShockRing", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, FEET + 0.15, 0))
	rate, life = 0.5, 0.55
	emitter("ImpactRing", {
		Texture = TEX.shock,
		LightEmission = 0.9,
		Brightness = 2.2,
		Color = CS({
			{ 0, rgb(230, 248, 255) },
			{ 0.4, rgb(110, 190, 255) },
			{ 1, rgb(40, 90, 255) },
		}),
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		Size = NS({ { 0, 0.6 }, { 0.35, 4.6 }, { 1, 6.2 } }),
		Transparency = NS({ { 0, 0 }, { 0.45, 0.25 }, { 1, 1 } }),
		Lifetime = NR(life),
		Rate = rate,
		Speed = NR(0.05),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(0, 0),
		ZOffset = 0.2,
	}, ground)
	cost(rate, life)

	local streakVol =
		carrier("StreakVolume", Vector3.new(4.4, 0.3, 3.4), CFrame.new(0, FEET + 0.3, 0))
	rate, life = 7, 0.45
	emitter("SpeedStreak", {
		Texture = TEX.glow,
		LightEmission = 1,
		Brightness = 2.2,
		Color = CS({ { 0, rgb(210, 240, 255) }, { 1, rgb(70, 140, 255) } }),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Size = NS({ { 0, 0.09 }, { 0.3, 0.13 }, { 1, 0.04 } }),
		Squash = NS({ { 0, -2.2 }, { 1, -2.2 } }),
		Transparency = NS({ { 0, 0.3 }, { 0.6, 0.35 }, { 1, 1 } }),
		Lifetime = NR(0.35, 0.55),
		Rate = rate,
		Speed = NR(9, 13),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(2, 2),
		Drag = 2.5,
		ZOffset = 0.3,
	}, streakVol)
	cost(rate, life)
end

---------------------------------------------------------------- GLINTS + BACKLIGHT + LIGHT
do
	local vol = carrier("GlintVolume", Vector3.new(4.0, 4.6, 2.8), CFrame.new(0, -0.6, 0))
	local rate, life = 6, 0.9
	emitter("Sapphire", {
		Texture = TEX.glint,
		LightEmission = 1,
		Brightness = 2.4,
		Color = CS({ { 0, rgb(235, 248, 255) }, { 1, rgb(90, 170, 255) } }),
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NS({ { 0, 0 }, { 0.3, 0.38 }, { 1, 0 } }),
		Transparency = NS({ { 0, 0 }, { 1, 0.3 } }),
		Lifetime = NR(0.7, 1.1),
		Rate = rate,
		Speed = NR(0.2, 0.6),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(180, 180),
		Rotation = NR(0, 45),
		ZOffset = 0.5,
	}, vol)
	cost(rate, life)

	local back = attach("UpperTorso", "Backlight", CFrame.new(0, -0.2, 0.9))
	rate, life = 1.4, 2.2
	emitter("Backlight", {
		Texture = TEX.glow,
		LightEmission = 1,
		Brightness = 1.4,
		Color = CS({ { 0, rgb(70, 140, 255) }, { 1, rgb(40, 80, 230) } }),
		Orientation = Enum.ParticleOrientation.FacingCamera,
		LockedToPart = true,
		Size = NS({ { 0, 4.6 }, { 0.5, 5.4 }, { 1, 5.0 } }),
		Transparency = NS({ { 0, 1 }, { 0.3, 0.72 }, { 0.7, 0.75 }, { 1, 1 } }),
		Lifetime = NR(life),
		Rate = rate,
		Speed = NR(0),
		ZOffset = -3,
	}, back)
	cost(rate, life)

	local d = Instance.new("Folder")
	d.Name = "Direct"
	d.Parent = group("UpperTorso")
	local l = Instance.new("PointLight")
	l.Name = "SapphireLight"
	l.Color = rgb(70, 140, 255)
	l.Brightness = 1.8
	l.Range = 10
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
out:SetAttribute("Source", "custom:emperor_thorns")
out:SetAttribute("Tier", "D")
out:SetAttribute("K", 1)
local old = dest:FindFirstChild(KEY)
if old then
	old:Destroy()
end
out.Parent = dest
table.insert(report, ("%s built: live ~%d"):format(KEY, math.floor(live + 0.5)))

---------------------------------------------------------------- re-dress Kaiser's preview stand
-- (Workspace.AuraAssignPreview, dev only; built by tools/aura_assign.py): a fresh hero from the
-- template, the aura put on the way build_aura_preview.luau's attach does (anchored, no spin)
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
			for _, b in g:GetChildren() do
				b.Parent = root
			end
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
	clone:Destroy()
	oldHero:Destroy()
	hero.Parent = slot
	local signs = {}
	for _, d in slot:GetDescendants() do
		if d:IsA("TextLabel") then
			d.Text = string.gsub(d.Text, "North Star", "Emperor Thorns")
			table.insert(signs, d.Text)
		end
	end
	table.insert(report, "preview stand re-dressed; sign: " .. table.concat(signs, " | "))
else
	table.insert(report, "no preview stand for Kaiser (skipped)")
end

return table.concat(report, "\n")
