-- build_star_platinum.luau - Studio EDIT mode, rerunnable:
--   python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file tools/studio/auras/build_star_platinum.luau
-- Builds ReplicatedStorage.Assets.Auras.StarPlatinum: Jotaro Kujo's (star_delinquent) hero aura,
-- hand-authored with the roblox-vfx skill's authoring route. Every texture is our own
-- (tools/auras/star_platinum/make_tex.py, ids in assets/auras/star_platinum/ids.json).
-- Then re-dresses Jotaro's stand in Workspace.AuraAssignPreview (if it is there) with it.
-- Layout is HeroAura.luau's template format (every CFrame in the hero ROOT's space at rest, R15,
-- feet at y -3, the hero faces -Z, +X is his right):
--   <BodyPart>/<Attachment RS=true>/<emitter>   rides that body part
--   <BodyPart>/Direct/<light>                    parented to the body part itself
--   HumanoidRootPart/<Part RootCF, Spin>/...     welded to the root, turned while live
--
-- The look (Stardust Crusaders; the owner wants no stand, so everything is round Jotaro himself):
--   SIGIL     Star Platinum's stat hexagon (A A C A A A) round the Joestar star under his feet, and a
--             clock ring lettered STAR PLATINUM * THE WORLD turning the other way
--   ORBITS    two tilted rings of shooting stars flying round him in opposite directions: gold Joestar stars
--             with white-gold > pink > violet tails (scrolling Bezier beams; no particles, animate in edit mode)
--   EMBLEM    the Joestar star as a crest behind his shoulders: gold star in a gold ring, violet-pink rays
--   STARLIGHT gold-pink glints and small stars rising off his silhouette (born inside him, drawn behind)
--   MENACING  trembling ゴ letters rising in a slanted column beside him, one each side
--   ORA       the barrage: white-cyan impact flashes in front of him, and now and then an オラ
--   STARDUST  gold Joestar stars drifting up from his feet and tiny cyan-white sparkles round him
--   THE WORLD a time-stop sphere wave from his chest every few seconds, and its ripple on the ground
--   GLARE     a sparkle on his right eye now and then
--   LIGHT     one violet point light (no shadows)
-- (v1-v3 had violet stand-aura flames round him and his Star Platinum figure: removed 2026-11-25, owner.)

local RS = game:GetService("ReplicatedStorage")

local TEX = {
	go = "rbxassetid://126181113140478",
	ora = "rbxassetid://123184839523439",
	comet = "rbxassetid://124810292753260", -- comet_v: upright (a beam lays the VERTICAL axis along itself)
	emblem = "rbxassetid://131198669643506",
	impact = "rbxassetid://99539150076720",
	star = "rbxassetid://124941466708067",
	twinkle = "rbxassetid://89038753895314",
	pulse = "rbxassetid://100625958093092",
	sigil = "rbxassetid://137951377811979",
	clock = "rbxassetid://73898724317836",
	glow = "rbxassetid://134543970756391",
}

local KEY = "StarPlatinum"
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
	local core = carrier(
		"SigilCore",
		Vector3.new(4.8, 0.05, 4.8),
		CFrame.new(0, FEET + 0.04, 0),
		Vector3.new(0, 0.3, 0)
	)
	decalDisc(core, TEX.sigil, 0.05, 1.1)
	local ring = carrier(
		"SigilRing",
		Vector3.new(7.2, 0.05, 7.2),
		CFrame.new(0, FEET + 0.06, 0),
		Vector3.new(0, -0.18, 0)
	)
	decalDisc(ring, TEX.clock, 0, 1.15)
end

---------------------------------------------------------------- STARDUST ORBITS (shooting stars round him)
-- (replaces v3's stand-aura flames: the owner found them bad, and he wears no stand any more)
-- Each orbit is a tilted ring of two Bezier beams (front half + back half, a cubic Bezier with control
-- arms 4/3 r is a near-perfect semicircle) carrying the comet tile; the texture scrolls, so gold Joestar
-- stars with pink-violet tails fly round him. Beams animate in edit mode too (the preview yard), cost no
-- particles and need no spin. dir -1 builds the halves the other way round: that ring flies the other way.
local function orbit(
	name: string,
	cf: CFrame,
	r: number,
	width: number,
	tilesPerSec: number,
	dir: number
)
	local p = carrier(name, Vector3.new(0.2, 0.2, 0.2), cf)
	local c = r * 4 / 3
	local function half(label: string, fromX: number, axisZ: number)
		local a0 = Instance.new("Attachment")
		a0.Name = label .. "0"
		a0.CFrame = CFrame.fromMatrix(
			Vector3.new(fromX, 0, 0),
			Vector3.new(0, 0, axisZ),
			Vector3.new(0, 1, 0)
		)
		a0.Parent = p
		local a1 = Instance.new("Attachment")
		a1.Name = label .. "1"
		a1.CFrame = CFrame.fromMatrix(
			Vector3.new(-fromX, 0, 0),
			Vector3.new(0, 0, axisZ),
			Vector3.new(0, 1, 0)
		)
		a1.Parent = p
		local bm = Instance.new("Beam")
		bm.Name = label
		bm.Attachment0 = a0
		bm.Attachment1 = a1
		bm.CurveSize0 = c
		bm.CurveSize1 = -c -- Roblox puts the second arm at Attachment1 - Axis * CurveSize1: -c bends it forward too
		bm.Segments = 32
		bm.FaceCamera = true
		bm.Width0 = width
		bm.Width1 = width
		bm.Texture = TEX.comet
		bm.TextureMode = Enum.TextureMode.Wrap
		bm.TextureLength = width * 6 -- the tile is 6:1: no stretch
		bm.TextureSpeed = tilesPerSec
		bm.LightEmission = 0.5
		bm.LightInfluence = 0
		bm.Brightness = 2.2
		bm.Color = ColorSequence.new(WHITE)
		bm.Transparency = NumberSequence.new(0)
		bm.Parent = p
	end
	half("Front", -r * dir, -1) -- (dir 1) left to right across his front
	half("Back", r * dir, 1) -- right to left behind him: one closed loop
end

-- (v4: r 2.15-2.6 and width 0.5-1.0 were too thin to read next to the yard's neighbours)
orbit("OrbitWaist", CFrame.new(0, -0.6, 0.1) * CFrame.Angles(0.3, 0, 0.12), 2.8, 1.1, 0.5, 1)
orbit("OrbitChest", CFrame.new(0, 0.9, 0.1) * CFrame.Angles(-0.25, 0, -0.38), 2.5, 1.0, 0.6, -1)

---------------------------------------------------------------- JOESTAR EMBLEM (the crest behind him)
-- the family's star (his birthmark) as a crest behind his shoulders: a gold star in a gold ring with violet-pink
-- rays; his body hides its middle. Both faces carry it (seen from behind it is the same symmetric star); it turns
-- slowly about its own axis in game (Spin; the preview yard is static).
do
	-- (6.4 across: his body hid all but the ring's top)
	local crest = carrier(
		"Emblem",
		Vector3.new(8.6, 8.6, 0.05),
		CFrame.new(0, 1.0, 0.95),
		Vector3.new(0, 0, 0.22)
	)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local g = Instance.new("SurfaceGui")
		g.Name = "Crest" .. face.Name
		g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 64
		g.LightInfluence = 0
		g.Brightness = 1.05
		g.AlwaysOnTop = false
		g.Parent = crest
		local img = Instance.new("ImageLabel")
		img.Name = "Image"
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = TEX.emblem
		img.ImageTransparency = 0.08
		img.Parent = g
	end
end

---------------------------------------------------------------- STARLIGHT (glints off his silhouette)
-- born inside his body and drawn behind it (ZOffset), so only the glints past his outline show: a glittering
-- edge instead of a flame one
do
	local body = carrier("Starlight", Vector3.new(3.0, 5.2, 0.5), CFrame.new(0, -0.5, 0.15))
	local rate, life = 18, 1.2
	emitter("Glint", {
		Texture = TEX.twinkle,
		LightEmission = 0.8,
		Brightness = 2.2,
		Color = CS({
			{ 0, rgb(255, 240, 190) },
			{ 0.45, rgb(255, 130, 220) },
			{ 1, rgb(150, 110, 255) },
		}),
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NS({ { 0, 0 }, { 0.2, 0.42, 0.12 }, { 0.6, 0.2 }, { 0.8, 0.32 }, { 1, 0 } }),
		Transparency = NS({ { 0, 0 }, { 1, 0.15 } }),
		Lifetime = NR(0.9, 1.5),
		Rate = rate,
		Speed = NR(0.9, 1.8),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(35, 8),
		Acceleration = Vector3.new(0, 0.6, 0),
		Drag = 0.6,
		Rotation = NR(-20, 20),
		ZOffset = -1.2,
	}, body)
	cost(rate, life)
	rate, life = 5, 1.6
	emitter("MiniStar", {
		Texture = TEX.star,
		LightEmission = 0.2,
		Brightness = 1.3,
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NS({ { 0, 0 }, { 0.2, 0.26 }, { 0.8, 0.22 }, { 1, 0 } }),
		Transparency = NS({ { 0, 0 }, { 1, 0.1 } }),
		Lifetime = NR(1.3, 1.9),
		Rate = rate,
		Speed = NR(1.0, 1.8),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(35, 8),
		Rotation = NR(0, 360),
		RotSpeed = NR(-120, 120),
		ZOffset = -1.0,
	}, body)
	cost(rate, life)
end

---------------------------------------------------------------- MENACING (ゴゴゴ)
-- one slanted column each side: a letter is born beside his hip and drifts up and out, trembling
-- (the 2x2 flipbook is four jittered copies), so three or four are on screen per side at a time
do
	for _, side in { 1, -1 } do
		local a = attach(
			"HumanoidRootPart",
			"Menace",
			CFrame.new(side * 2.55, -1.6, -0.5) * CFrame.Angles(0, 0, -side * 0.42)
		)
		local rate, life = 1.25, 2.6
		emitter("Go", {
			Texture = TEX.go,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2,
			FlipbookMode = Enum.ParticleFlipbookMode.Loop,
			FlipbookFramerate = NR(11, 14),
			FlipbookStartRandom = true,
			Brightness = 1.1,
			Orientation = Enum.ParticleOrientation.FacingCamera,
			Size = NS({ { 0, 0.4 }, { 0.12, 1.05 }, { 0.2, 0.95 }, { 0.8, 1.0 }, { 1, 0.85 } }),
			Transparency = NS({ { 0, 1 }, { 0.08, 0 }, { 0.78, 0 }, { 1, 1 } }),
			Lifetime = NR(life),
			Rate = rate,
			Speed = NR(1.25),
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(0, 0),
			Rotation = NR(side * 4 - 6, side * 4 + 6),
			ZOffset = 1.2,
		}, a)
		cost(rate, life)
	end
end

---------------------------------------------------------------- ORA (the barrage in front of him)
do
	local fists = carrier("RushVolume", Vector3.new(2.4, 1.4, 0.4), CFrame.new(0.3, 0.6, -1.7))
	local rate, life = 3.5, 0.32
	emitter("Impact", {
		Texture = TEX.impact,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		LightEmission = 0.6,
		Brightness = 1.8,
		Color = CS({ { 0, WHITE }, { 1, rgb(200, 236, 255) } }),
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NS({ { 0, 0.9 }, { 1, 1.25 } }),
		Transparency = NS({ { 0, 0 }, { 1, 0.1 } }),
		Lifetime = NR(life),
		Rate = rate,
		Speed = NR(0),
		Rotation = NR(0, 360),
		ZOffset = 1.5,
	}, fists)
	cost(rate, life)

	local a = attach("HumanoidRootPart", "OraPop", CFrame.new(2.6, 2.3, -0.6))
	rate, life = 0.3, 1.1
	emitter("Ora", {
		Texture = TEX.ora,
		Brightness = 1.1,
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NS({ { 0, 0.3 }, { 0.1, 1.9 }, { 0.18, 1.55 }, { 0.85, 1.6 }, { 1, 1.75 } }),
		Transparency = NS({ { 0, 1 }, { 0.06, 0 }, { 0.8, 0 }, { 1, 1 } }),
		Lifetime = NR(life),
		Rate = rate,
		Speed = NR(0.35),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(15, 15),
		Rotation = NR(-10, 4),
		ZOffset = 1.6,
	}, a)
	cost(rate, life)
end

---------------------------------------------------------------- STARDUST (Joestar stars + sparkles)
do
	local feet = carrier("StarField", Vector3.new(4.4, 0.4, 3.0), CFrame.new(0, FEET + 0.4, 0.2))
	local rate, life = 2.4, 2.4
	emitter("JoestarStar", {
		Texture = TEX.star,
		LightEmission = 0.2,
		Brightness = 1.4,
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NS({ { 0, 0 }, { 0.15, 0.42 }, { 0.8, 0.36 }, { 1, 0 } }),
		Transparency = NS({ { 0, 0 }, { 0.8, 0.05 }, { 1, 1 } }),
		Lifetime = NR(2.0, 2.8),
		Rate = rate,
		Speed = NR(1.0, 1.8),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(12, 12),
		Acceleration = Vector3.new(0, 0.3, 0),
		Drag = 0.4,
		Rotation = NR(0, 360),
		RotSpeed = NR(-90, 90),
		ZOffset = 0.6,
	}, feet)
	cost(rate, life)

	local cloud = carrier("Stardust", Vector3.new(5.4, 6.4, 3.6), CFrame.new(0, 0.3, 0.2))
	rate, life = 11, 1.2
	emitter("Sparkle", {
		Texture = TEX.twinkle,
		LightEmission = 1,
		Brightness = 2.4,
		Color = CS({
			{ 0, rgb(255, 255, 255) },
			{ 0.5, rgb(170, 236, 255) },
			{ 1, rgb(255, 214, 110) },
		}),
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NS({ { 0, 0 }, { 0.3, 0.34, 0.1 }, { 0.6, 0.12 }, { 0.8, 0.3 }, { 1, 0 } }),
		Transparency = NS({ { 0, 0 }, { 1, 0.2 } }),
		Lifetime = NR(0.9, 1.5),
		Rate = rate,
		Speed = NR(0.2, 0.6),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(180, 180),
		Rotation = NR(-15, 15),
		ZOffset = 0.8,
	}, cloud)
	cost(rate, life)
end

---------------------------------------------------------------- THE WORLD (time-stop pulse)
do
	local a = attach("HumanoidRootPart", "WorldPulse", CFrame.new(0, 0.6, 0))
	local rate, life = 0.17, 1.15
	emitter("TimeStop", {
		Texture = TEX.pulse,
		LightEmission = 0.4,
		Brightness = 1.6,
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NS({ { 0, 0.5 }, { 0.55, 9.5 }, { 1, 11 } }),
		Transparency = NS({ { 0, 0.15 }, { 0.5, 0.35 }, { 1, 1 } }),
		Lifetime = NR(life),
		Rate = rate,
		Speed = NR(0),
		ZOffset = -0.5,
	}, a)
	cost(rate, life)

	local g = carrier("WorldRipple", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, FEET + 0.12, 0))
	emitter("TimeRipple", {
		Texture = TEX.pulse,
		LightEmission = 0.4,
		Brightness = 1.6,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top,
		Size = NS({ { 0, 1 }, { 0.6, 6.5 }, { 1, 7.5 } }),
		Transparency = NS({ { 0, 0.1 }, { 0.6, 0.4 }, { 1, 1 } }),
		Lifetime = NR(life),
		Rate = rate,
		Speed = NR(0.001),
		SpreadAngle = Vector2.new(0, 0),
	}, g)
	cost(rate, life)
end

---------------------------------------------------------------- GLARE (eye sparkle)
do
	local a = attach("Head", "Glare", CFrame.new(0.22, 1.68, -0.62))
	local rate, life = 0.45, 0.5
	emitter("Glare", {
		Texture = TEX.twinkle,
		LightEmission = 1,
		Brightness = 3,
		Color = CS({ { 0, rgb(255, 255, 255) }, { 1, rgb(170, 236, 255) } }),
		Orientation = Enum.ParticleOrientation.FacingCamera,
		LockedToPart = true,
		Size = NS({ { 0, 0 }, { 0.35, 0.75 }, { 1, 0 } }),
		Transparency = NS({ { 0, 0 }, { 1, 0 } }),
		Lifetime = NR(life),
		Rate = rate,
		Speed = NR(0),
		Rotation = NR(0, 0),
		RotSpeed = NR(80, 80),
		ZOffset = 0.5,
	}, a)
	cost(rate, life)
end

---------------------------------------------------------------- LIGHT
do
	local d = Instance.new("Folder")
	d.Name = "Direct"
	d.Parent = group("UpperTorso")
	local l = Instance.new("PointLight")
	l.Name = "StandLight"
	l.Color = rgb(150, 110, 255)
	l.Brightness = 1.4
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
out:SetAttribute("Source", "custom:star_platinum")
out:SetAttribute("Tier", "C")
out:SetAttribute("K", 1)
local old = dest:FindFirstChild(KEY)
if old then
	old:Destroy()
end
out.Parent = dest
table.insert(report, ("%s built: live ~%d"):format(KEY, math.floor(live + 0.5)))

---------------------------------------------------------------- re-dress Jotaro's preview stand
local yard = workspace:FindFirstChild("AuraAssignPreview")
local slot = yard and yard:FindFirstChild("Heroes") and yard.Heroes:FindFirstChild("Jotaro Joestar")
local oldHero = slot and slot:FindFirstChild("star_delinquent")
local template = assets.Characters:FindFirstChild("Char_star_delinquent")
if slot and oldHero and template then
	local pivot = oldHero:GetPivot()
	local hero = template:Clone()
	hero.Name = "star_delinquent"
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
	local renamed = 0
	for _, d in slot:GetDescendants() do
		if d:IsA("TextLabel") and string.find(d.Text, "Red Ring of Death", 1, true) then
			d.Text = string.gsub(d.Text, "Red Ring of Death", "Star Platinum")
			renamed += 1
		end
	end
	table.insert(report, ("preview stand re-dressed (%d sign line(s) renamed)"):format(renamed))
else
	table.insert(report, "no preview stand for Jotaro (skipped)")
end

return table.concat(report, "\n")
