-- build_demons_extract.luau - Studio EDIT mode, rerunnable:
--   python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file tools/studio/auras/build_demons_extract.luau
-- Builds ReplicatedStorage.Assets.Auras.DemonsExtract: Esdeath's (ice_general, Epic) hero aura, hand-authored with
-- the roblox-vfx skill's authoring route. Every texture is our own (tools/auras/demons_extract/make_tex.py, ids in
-- assets/auras/demons_extract/ids.json). Then re-dresses her stand in Workspace.AuraAssignPreview (if it is there).
-- HeroAura.luau's template format (root space at rest, R15, feet at y -3, the hero faces -Z, +X is her right).
--
-- The look (Akame ga Kill!: her Teigu Demon's Extract makes ice out of thin air):
--   HOARFROST     the ground: frost ferns in six-fold symmetry round an ice crest; a ring of outward ice crystals
--                 spreads across the ground every few seconds
--   ERUPTIONS     at eight points round her (none in front) an ice cluster bursts up out of the ground, glints and
--                 shatters (16-frame one-shot), each on its own rhythm so they roll round her
--   HAGELSPRUNG   ice shards streaking down out of the sky round her
--   SNOW          three snowflake designs drifting down, diamond dust winking in the air
--   COLD          a pale blue mist rolling off the ground; one cold cyan light
-- (v1 also stood a glacier crown of ice spires behind her: removed, owner.)

local RS = game:GetService("ReplicatedStorage")

local TEX = {
	frost = "rbxassetid://70383169960480",
	icering = "rbxassetid://95071596851255",
	glint = "rbxassetid://89457197874896",
	mist = "rbxassetid://78397546919201",
	spike = "rbxassetid://78749226116141",
	shard = "rbxassetid://107805494953530",
	flakeA = "rbxassetid://114355745442662",
	flakeB = "rbxassetid://88070425982344",
	flakeC = "rbxassetid://114837010221478",
	glow = "rbxassetid://110639181797311",
}

local KEY = "DemonsExtract"
local TIER = "C"
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

---------------------------------------------------------------- HOARFROST (the ground)
do
	local disc = carrier(
		"Frost",
		Vector3.new(6.4, 0.05, 6.4),
		CFrame.new(0, FEET + 0.04, 0),
		Vector3.new(0, 0.08, 0)
	)
	surface(disc, Enum.NormalId.Top, TEX.frost, 0.02, 1.15, 64)
	-- the frost shockwave: a ring of outward ice crystals spreading across the ground every few seconds
	local g = carrier("FrostWave", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, FEET + 0.12, 0))
	local rate, life = 0.28, 1.7
	emitter("FrostWave", {
		Texture = TEX.icering,
		LightEmission = 0.4,
		Brightness = 1.6,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top,
		Size = NS({ { 0, 1.6 }, { 1, 9.0 } }),
		Transparency = NS({ { 0, 1 }, { 0.08, 0.05 }, { 0.6, 0.35 }, { 1, 1 } }),
		Lifetime = NR(life),
		Rate = rate,
		Speed = NR(0.001),
		SpreadAngle = Vector2.new(0, 0),
	}, g)
	cost(rate, life)
end

---------------------------------------------------------------- ICE ERUPTIONS (spikes raised from the ground)
-- eight points round her; at each an ice cluster bursts up, glints and shatters (16-frame one-shot drawn with its
-- base at 0.94 of the frame, so the attachment sits that far above the ground). Each point has its own rate, so the
-- eruptions roll round her instead of firing together. None straight in front of her.
do
	local points = {
		{ -3.0, 0.6, 2.2 },
		{ 3.0, 0.6, 2.2 },
		{ -2.4, 2.0, 2.6 },
		{ 2.4, 2.0, 2.6 },
		{ -1.2, 2.8, 2.0 },
		{ 1.2, 2.8, 2.0 },
		{ -2.8, -1.6, 1.8 },
		{ 2.8, -1.6, 1.8 },
	}
	for i, p in points do
		local size = p[3]
		local a =
			attach("HumanoidRootPart", "Eruption" .. i, CFrame.new(p[1], FEET + size * 0.44, p[2]))
		local rate, life = 0.19 + 0.027 * i, 1.8
		emitter("Eruption", {
			Texture = TEX.spike,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
			FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			LightEmission = 0.1,
			Brightness = 1.25,
			Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
			Size = NS({ { 0, size }, { 1, size } }),
			Transparency = NS({ { 0, 0 }, { 1, 0 } }),
			Lifetime = NR(life),
			Rate = rate,
			Speed = NR(0),
			ZOffset = -0.2,
		}, a)
		cost(rate, life)
	end
end

---------------------------------------------------------------- HAGELSPRUNG (hail)
do
	local sky = carrier("Hail", Vector3.new(7.0, 0.2, 5.0), CFrame.new(0, 6.0, 0.4))
	local rate, life = 3, 1.0
	emitter("Hail", {
		Texture = TEX.shard,
		LightEmission = 0.3,
		Brightness = 1.6,
		Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
		Size = NS({ { 0, 0.42 }, { 1, 0.36 } }),
		Transparency = NS({ { 0, 1 }, { 0.1, 0 }, { 0.75, 0 }, { 1, 1 } }),
		Lifetime = NR(0.9, 1.1),
		Rate = rate,
		Speed = NR(8.5, 10),
		EmissionDirection = Enum.NormalId.Bottom,
		SpreadAngle = Vector2.new(4, 4),
		Rotation = NR(180, 180), -- the shard's point leads as it falls
		ZOffset = 0.2,
	}, sky)
	cost(rate, life)
end

---------------------------------------------------------------- SNOW (and diamond dust)
do
	local cloud = carrier("Snow", Vector3.new(8.4, 0.6, 6.0), CFrame.new(0, 4.4, 0.4))
	for i, tex in { TEX.flakeA, TEX.flakeB, TEX.flakeC } do
		local rate, life = 2.2, 4.4
		emitter("Snow" .. i, {
			Texture = tex,
			LightEmission = 0.5,
			Brightness = 1.8,
			Orientation = Enum.ParticleOrientation.FacingCamera,
			Size = NS({ { 0, 0.2, 0.06 }, { 1, 0.22, 0.06 } }),
			Transparency = NS({ { 0, 1 }, { 0.12, 0 }, { 0.82, 0 }, { 1, 1 } }),
			Lifetime = NR(3.8, 5.0),
			Rate = rate,
			Speed = NR(0.9, 1.5),
			EmissionDirection = Enum.NormalId.Bottom,
			SpreadAngle = Vector2.new(20, 20),
			Acceleration = Vector3.new(0.15, 0, 0),
			Rotation = NR(0, 360),
			RotSpeed = NR(-40, 40),
			ZOffset = 0.4,
		}, cloud)
		cost(rate, life)
	end
	local air = carrier("DiamondDust", Vector3.new(6.4, 6.0, 4.6), CFrame.new(0, 0.2, 0.2))
	local rate, life = 9, 1.0
	emitter("Dust", {
		Texture = TEX.glint,
		LightEmission = 1,
		Brightness = 2.4,
		Color = CS({ { 0, rgb(255, 255, 255) }, { 1, rgb(170, 228, 255) } }),
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NS({ { 0, 0 }, { 0.35, 0.3 }, { 1, 0 } }),
		Transparency = NS({ { 0, 0 }, { 1, 0 } }),
		Lifetime = NR(0.8, 1.2),
		Rate = rate,
		Speed = NR(0.1, 0.3),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(180, 180),
		ZOffset = 0.6,
	}, air)
	cost(rate, life)
end

---------------------------------------------------------------- COLD (mist rolling off the ground, light)
do
	local feet = carrier("ColdMist", Vector3.new(3.6, 0.3, 2.8), CFrame.new(0, FEET + 0.25, 0.1))
	local rate, life = 4, 3.0
	emitter("Mist", {
		Texture = TEX.mist,
		LightEmission = 0.2,
		Brightness = 1.2,
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NS({ { 0, 1.4 }, { 1, 3.6 } }),
		Transparency = NS({ { 0, 1 }, { 0.25, 0.5 }, { 1, 1 } }),
		Lifetime = NR(2.4, 3.6),
		Rate = rate,
		Speed = NR(0.4, 0.8),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(80, 80),
		Acceleration = Vector3.new(0, -0.12, 0),
		Rotation = NR(0, 360),
		RotSpeed = NR(-12, 12),
		ZOffset = -0.2,
	}, feet)
	cost(rate, life)
	local d = Instance.new("Folder")
	d.Name = "Direct"
	d.Parent = group("UpperTorso")
	local l = Instance.new("PointLight")
	l.Name = "IceLight"
	l.Color = rgb(170, 225, 255)
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
out:SetAttribute("Source", "custom:demons_extract")
out:SetAttribute("Tier", TIER)
out:SetAttribute("K", 1)
local old = dest:FindFirstChild(KEY)
if old then
	old:Destroy()
end
out.Parent = dest
table.insert(report, ("%s built: live ~%d"):format(KEY, math.floor(live + 0.5)))

---------------------------------------------------------------- re-dress Esdeath's preview stand
local yard = workspace:FindFirstChild("AuraAssignPreview")
local slot = yard and yard:FindFirstChild("Heroes") and yard.Heroes:FindFirstChild("Esdeath")
local oldHero = slot and slot:FindFirstChild("ice_general")
local template = assets.Characters:FindFirstChild("Char_ice_general")
if slot and oldHero and template then
	local pivot = oldHero:GetPivot()
	local hero = template:Clone()
	hero.Name = "ice_general"
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
		if d:IsA("TextLabel") and string.find(d.Text, "Blue Heat", 1, true) then
			d.Text = string.gsub(d.Text, "Blue Heat", "Demon's Extract")
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
	table.insert(report, "no preview stand for Esdeath (skipped)")
end

return table.concat(report, "\n")
