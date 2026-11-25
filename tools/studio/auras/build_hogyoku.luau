-- build_hogyoku.luau - Studio EDIT mode, rerunnable:
--   python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file tools/studio/auras/build_hogyoku.luau
-- Builds ReplicatedStorage.Assets.Auras.Hogyoku: Sosuke Aizen's (void_empress, Premium) hero aura, hand-authored
-- with the roblox-vfx skill's authoring route. Every texture is our own (tools/auras/hogyoku/make_tex.py, ids in
-- assets/auras/hogyoku/ids.json). Then re-dresses Aizen's stand in Workspace.AuraAssignPreview (if it is there).
-- Layout is HeroAura.luau's template format (every CFrame in the hero ROOT's space at rest, R15, feet at y -3,
-- the hero faces -Z, +X is his right):
--   <BodyPart>/<Attachment RS=true>/<emitter|gui>  rides that body part
--   <BodyPart>/Direct/<light>                       parented to the body part itself
--   <BodyPart>/<Part RootCF, Spin>/...              welded to that body part, turned while live
--
-- The look (Bleach, Fake Karakura Town: Aizen fused with the Hogyoku):
--   HOGYOKU     the orb in his sternum: a violet nebula sphere (self-lit billboard) in a cross-shaped black seal
--               with glowing cracks on his coat, a heartbeat ring, an orchid glow, sparks drawn into it
--   THRONE      "from now on I will stand in heaven": a god-halo of his own powers behind him. Back plane: a
--               sunburst crown of twenty black Kurohitsugi blades with violet seams. Front plane: Kyoka Suigetsu as
--               a round mirror reflecting Las Noches and its crescent moon, cracked, its rim bursting mid-"Shatter",
--               ringed by 破道の九十 黒棺. In game the two turn opposite ways; glass breaks off the rim and falls.
--               (v1-v2 had butterfly wings here: the owner wanted something of Aizen's own.)
--   REIATSU     his spiritual pressure: violet-white light streaks shooting up round him, dark ones among them,
--               a violet backlight
--   KYOKA       Kyoka Suigetsu's "Shatter": mirror-glass shards with sky-to-violet reflections tumbling round
--               him, fading in and out like the illusion they are
--   SUIGETSU    the ground: 鏡花水月 "mirror flower, water moon": still water mirroring a broken moon, ripples
--               spreading on it
--   LIGHT       one orchid point light (no shadows)
-- (v1-v3 also raised Kurohitsugi coffin walls round him every ~10 s: the owner found it better without them.)

local RS = game:GetService("ReplicatedStorage")

local TEX = {
	glass = "rbxassetid://106460965723238",
	glassB = "rbxassetid://104187170992086",
	glow = "rbxassetid://96392767778748",
	hogyoku = "rbxassetid://138348664706273",
	mote = "rbxassetid://71961769206404",
	ripple = "rbxassetid://98642181897782",
	seal = "rbxassetid://99854986430226",
	streak = "rbxassetid://106353151188342",
	suigetsu = "rbxassetid://123276253831178",
	crown = "rbxassetid://128966190371459",
	mirror = "rbxassetid://122061366327456",
}

local KEY = "Hogyoku"
local TIER = "E"
local FEET = -3.0
local WHITE = Color3.new(1, 1, 1)
local CHEST = Vector3.new(0, 0.42, -0.62) -- his sternum, on the coat's front (root space)

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

-- an invisible carrier part welded to `bodyPart` (root space at rest)
local function carrier(
	name: string,
	size: Vector3,
	cf: CFrame,
	spin: Vector3?,
	bodyPart: string?
): Part
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
	p.Parent = group(bodyPart or "HumanoidRootPart")
	return p
end

local function surface(
	p: Part,
	face: Enum.NormalId,
	image: string,
	transparency: number,
	brightness: number,
	pps: number
)
	local g = Instance.new("SurfaceGui")
	g.Name = "Gui" .. face.Name
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

---------------------------------------------------------------- SUIGETSU (the ground)
do
	local disc = carrier(
		"WaterMoon",
		Vector3.new(7.4, 0.05, 7.4),
		CFrame.new(0, FEET + 0.04, 0),
		Vector3.new(0, 0.1, 0)
	)
	surface(disc, Enum.NormalId.Top, TEX.suigetsu, 0.04, 1.1, 64)
	local g = carrier("Ripples", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, FEET + 0.1, 0))
	local rate, life = 0.75, 2.4
	emitter("Ripple", {
		Texture = TEX.ripple,
		LightEmission = 0.4,
		Brightness = 1.4,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top,
		Size = NS({ { 0, 1.2 }, { 1, 7.0 } }),
		Transparency = NS({ { 0, 0.15 }, { 0.6, 0.45 }, { 1, 1 } }),
		Lifetime = NR(life),
		Rate = rate,
		Speed = NR(0.001),
		SpreadAngle = Vector2.new(0, 0),
	}, g)
	cost(rate, life)
end

---------------------------------------------------------------- THRONE (the god-halo behind him)
-- two planes behind his shoulders, both faces carrying the image (it is round and symmetric enough), turning
-- opposite ways about their own axis in game (Spin; static on the preview yard). The crown's empty middle and the
-- mirror's middle sit behind his body, so the halo frames his whole upper body like a mandorla.
do
	local crown = carrier(
		"Crown",
		-- (8.8 across was barely wider than his coat: its sides hid behind the pressure pillars; tier E reach is 7)
		Vector3.new(12.6, 12.6, 0.05),
		CFrame.new(0, 1.4, 1.3),
		Vector3.new(0, 0, 0.12)
	)
	surface(crown, Enum.NormalId.Front, TEX.crown, 0, 1.6, 48)
	surface(crown, Enum.NormalId.Back, TEX.crown, 0, 1.6, 48)
	local glass = carrier(
		"Mirror",
		Vector3.new(8.6, 8.6, 0.05),
		CFrame.new(0, 1.4, 1.05),
		Vector3.new(0, 0, -0.07)
	)
	surface(glass, Enum.NormalId.Front, TEX.mirror, 0.04, 1.45, 64)
	surface(glass, Enum.NormalId.Back, TEX.mirror, 0.04, 1.45, 64)
	-- shards breaking off the mirror's rim and falling (a ring-ish band: a box the mirror's size, most of it hidden
	-- behind him, the rest falls clear)
	local rim = carrier("MirrorRim", Vector3.new(7.8, 7.8, 0.3), CFrame.new(0, 1.4, 0.95))
	for i, tex in { TEX.glass, TEX.glassB } do
		local rate, life = 2.4, 1.8
		emitter("Falling" .. i, {
			Texture = tex,
			LightEmission = 0.3,
			Brightness = 1.4,
			Orientation = Enum.ParticleOrientation.FacingCamera,
			Size = NS({ { 0, 0.32, 0.1 }, { 1, 0.26, 0.08 } }),
			Transparency = NS({ { 0, 0 }, { 0.7, 0.1 }, { 1, 1 } }),
			Lifetime = NR(1.4, 2.2),
			Rate = rate,
			Speed = NR(0.4, 1.0),
			EmissionDirection = Enum.NormalId.Front,
			SpreadAngle = Vector2.new(40, 40),
			Acceleration = Vector3.new(0, -6, 0),
			Rotation = NR(0, 360),
			RotSpeed = NR(-200, 200),
			ZOffset = 0.2,
		}, rim)
		cost(rate, life)
	end
end

---------------------------------------------------------------- REIATSU (spiritual pressure)
-- (v1: one box under him, 60/s at Brightness 2.2: a white column blew out his whole lower half)
-- three strips round him (left, right, behind), never in front of him: a pillar of pressure he stands inside
do
	local strips = {
		carrier("PressureL", Vector3.new(0.9, 0.2, 2.6), CFrame.new(-2.1, FEET + 0.2, 0.2)),
		carrier("PressureR", Vector3.new(0.9, 0.2, 2.6), CFrame.new(2.1, FEET + 0.2, 0.2)),
		carrier("PressureB", Vector3.new(3.4, 0.2, 0.8), CFrame.new(0, FEET + 0.2, 1.4)),
	}
	for _, base in strips do
		local rate, life = 11, 0.55
		emitter("Streak", {
			Texture = TEX.streak,
			LightEmission = 0.5,
			Brightness = 1.5,
			Color = CS({
				{ 0, rgb(240, 220, 255) },
				{ 0.35, rgb(190, 130, 255) },
				{ 1, rgb(120, 50, 230) },
			}),
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Size = NS({ { 0, 2.4 }, { 1, 1.4 } }),
			Transparency = NS({ { 0, 0.15 }, { 0.7, 0.35 }, { 1, 1 } }),
			Lifetime = NR(0.4, 0.7),
			Rate = rate,
			Speed = NR(10, 15),
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(4, 4),
			Drag = 0.6,
		}, base)
		cost(rate, life)
		rate, life = 5, 0.6
		emitter("DarkStreak", {
			Texture = TEX.streak,
			Brightness = 1,
			Color = CS({ { 0, rgb(46, 14, 80) }, { 1, rgb(20, 6, 36) } }),
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Size = NS({ { 0, 2.6 }, { 1, 1.6 } }),
			Transparency = NS({ { 0, 0.15 }, { 0.7, 0.35 }, { 1, 1 } }),
			Lifetime = NR(0.45, 0.75),
			Rate = rate,
			Speed = NR(8, 12),
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(4, 4),
			Drag = 0.6,
			ZOffset = -0.2,
		}, base)
		cost(rate, life)
	end
	local back = attach("HumanoidRootPart", "Backlight", CFrame.new(0, 0.6, 0.8))
	local rate, life = 1.4, 1.8
	emitter("Backlight", {
		Texture = TEX.glow,
		LightEmission = 0.7,
		Brightness = 1.6,
		Color = CS({ { 0, rgb(170, 90, 255) }, { 1, rgb(110, 40, 220) } }),
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NS({ { 0, 7.0 }, { 0.5, 8.2 }, { 1, 7.0 } }),
		Transparency = NS({ { 0, 1 }, { 0.3, 0.68 }, { 0.7, 0.68 }, { 1, 1 } }),
		Lifetime = NR(life),
		Rate = rate,
		Speed = NR(0),
		ZOffset = -4,
	}, back)
	cost(rate, life)
end

---------------------------------------------------------------- HOGYOKU (in his sternum)
do
	-- the seal on his coat (flat, facing out of his chest), riding the upper torso
	local seal = carrier("Seal", Vector3.new(1.8, 1.8, 0.05), CFrame.new(CHEST), nil, "UpperTorso")
	surface(seal, Enum.NormalId.Front, TEX.seal, 0, 1.15, 160)
	-- the orb: a self-lit billboard just proud of the seal
	local a = attach("UpperTorso", "Hogyoku", CFrame.new(CHEST + Vector3.new(0, 0, -0.14)))
	local g = Instance.new("BillboardGui")
	g.Name = "Orb"
	g.Size = UDim2.fromScale(0.95, 0.95)
	g.LightInfluence = 0
	g.Brightness = 1.15
	g.AlwaysOnTop = false
	g.MaxDistance = 160
	g.ResetOnSpawn = false
	g.Parent = a
	local img = Instance.new("ImageLabel")
	img.Name = "Image"
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = TEX.hogyoku
	img.Parent = g
	-- a breathing orchid glow behind it
	local ga = attach("UpperTorso", "HogyokuGlow", CFrame.new(CHEST + Vector3.new(0, 0, -0.05)))
	local rate, life = 2.5, 1.1
	emitter("Glow", {
		Texture = TEX.glow,
		LightEmission = 1,
		Brightness = 2.2,
		Color = CS({ { 0, rgb(230, 130, 255) }, { 1, rgb(150, 70, 255) } }),
		Orientation = Enum.ParticleOrientation.FacingCamera,
		LockedToPart = true,
		Size = NS({ { 0, 1.0 }, { 0.5, 2.1 }, { 1, 1.0 } }),
		Transparency = NS({ { 0, 1 }, { 0.4, 0.35 }, { 1, 1 } }),
		Lifetime = NR(life),
		Rate = rate,
		Speed = NR(0),
		ZOffset = -0.3,
	}, ga)
	cost(rate, life)
	-- the heartbeat: a ring pulsing out of it
	rate, life = 0.65, 0.75
	emitter("Heartbeat", {
		Texture = TEX.ripple,
		LightEmission = 0.8,
		Brightness = 2,
		Color = CS({ { 0, rgb(255, 230, 255) }, { 1, rgb(200, 100, 255) } }),
		Orientation = Enum.ParticleOrientation.FacingCamera,
		LockedToPart = true,
		Size = NS({ { 0, 0.3 }, { 1, 3.4 } }),
		Transparency = NS({ { 0, 0.05 }, { 1, 1 } }),
		Lifetime = NR(life),
		Rate = rate,
		Speed = NR(0),
		ZOffset = 0.4,
	}, ga)
	cost(rate, life)
	-- sparks drawn into it from a shell round his chest
	local shell = carrier(
		"Draw",
		Vector3.new(3.4, 3.4, 3.4),
		CFrame.new(CHEST + Vector3.new(0, 0, -0.1)),
		nil,
		"UpperTorso"
	)
	rate, life = 22, 0.42
	emitter("Spark", {
		Texture = TEX.mote,
		LightEmission = 1,
		Brightness = 2.4,
		Color = CS({ { 0, rgb(200, 120, 255) }, { 1, rgb(255, 240, 255) } }),
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NS({ { 0, 0.08 }, { 1, 0.16 } }),
		Transparency = NS({ { 0, 1 }, { 0.3, 0 }, { 1, 0.3 } }),
		Lifetime = NR(life),
		Rate = rate,
		Speed = NR(3.6, 4.2),
		ZOffset = 0.5,
	}, shell)
	cost(rate, life)
end

---------------------------------------------------------------- KYOKA (Kyoka Suigetsu's mirror shards)
do
	local vol = carrier("Mirror", Vector3.new(6.6, 6.0, 4.6), CFrame.new(0, 0.2, 0.1))
	for i, tex in { TEX.glass, TEX.glassB } do
		local rate, life = 3.2, 3.4
		emitter("Shard" .. i, {
			Texture = tex,
			LightEmission = 0.25,
			Brightness = 1.35,
			Orientation = Enum.ParticleOrientation.FacingCamera,
			Size = NS({ { 0, 0.55, 0.2 }, { 1, 0.7, 0.2 } }),
			Transparency = NS({ { 0, 1 }, { 0.2, 0.05 }, { 0.75, 0.1 }, { 1, 1 } }),
			Lifetime = NR(2.8, 4.0),
			Rate = rate,
			Speed = NR(0.15, 0.4),
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(180, 180),
			Rotation = NR(0, 360),
			RotSpeed = NR(-35, 35),
			ZOffset = 0.4,
		}, vol)
		cost(rate, life)
	end
end

---------------------------------------------------------------- LIGHT
do
	local d = Instance.new("Folder")
	d.Name = "Direct"
	d.Parent = group("UpperTorso")
	local l = Instance.new("PointLight")
	l.Name = "HogyokuLight"
	l.Color = rgb(200, 110, 255)
	l.Brightness = 1.6
	l.Range = 11
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
out:SetAttribute("Source", "custom:hogyoku")
out:SetAttribute("Tier", TIER)
out:SetAttribute("K", 1)
local old = dest:FindFirstChild(KEY)
if old then
	old:Destroy()
end
out.Parent = dest
table.insert(report, ("%s built: live ~%d"):format(KEY, math.floor(live + 0.5)))

---------------------------------------------------------------- re-dress Aizen's preview stand
local yard = workspace:FindFirstChild("AuraAssignPreview")
local slot = yard and yard:FindFirstChild("Heroes") and yard.Heroes:FindFirstChild("Aizen Sosuke")
local oldHero = slot and slot:FindFirstChild("void_empress")
local template = assets.Characters:FindFirstChild("Char_void_empress")
if slot and oldHero and template then
	local pivot = oldHero:GetPivot()
	local hero = template:Clone()
	hero.Name = "void_empress"
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
		if d:IsA("TextLabel") and string.find(d.Text, "ChromaticVoid", 1, true) then
			d.Text = string.gsub(d.Text, "ChromaticVoid", "Hogyoku")
			renamed += 1
		end
	end
	-- the pack aura's raw pieces (clock, void cubes) were put on the stand by the yard builder: clear them
	local cleared = 0
	for _, c in slot:GetChildren() do
		if c ~= hero and c.Name ~= "Stand" and not c:IsA("BillboardGui") then
			local hasFx = c:FindFirstChildWhichIsA("ParticleEmitter", true)
				or c:FindFirstChildWhichIsA("Beam", true)
			if hasFx then
				c:Destroy()
				cleared += 1
			end
		end
	end
	table.insert(
		report,
		("preview stand re-dressed (%d sign line(s) renamed, %d old fx cleared)"):format(
			renamed,
			cleared
		)
	)
else
	table.insert(report, "no preview stand for Aizen (skipped)")
end

return table.concat(report, "\n")
