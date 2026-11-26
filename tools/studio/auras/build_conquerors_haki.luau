-- build_conquerors_haki.luau - Studio EDIT mode, rerunnable:
--   python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file tools/studio/auras/build_conquerors_haki.luau
-- Builds ReplicatedStorage.Assets.Auras.ConquerorsHaki: Shanks's (red_haired_emperor) hero aura, hand-authored
-- with the roblox-vfx skill's authoring route. Every texture is our own (tools/auras/conquerors_haki/make_tex.py,
-- ids in assets/auras/conquerors_haki/ids.json; the pressure streak reuses ShadowArise's upload).
-- Then re-dresses Shanks's stand in Workspace.AuraAssignPreview (if it is there).
-- Layout is HeroAura.luau's template format (every CFrame in the hero ROOT's space at rest, R15,
-- feet at y -3, the hero faces -Z; see build_demon_king.luau for the full list).
--
-- No flame tongues (the owner's brief). Shanks's own language is Conqueror's Haki:
--   LIGHTNING big black bolts edged in crimson lashing round him and out of the ground (big arcs AROUND
--             him: Mihawk's HawkEye has small black-and-crimson cracks ON his body, so these stay large)
--   PRESSURE  wind lines shooting radially out of him, a dark-red shockwave ring pulsing from his feet
--   GROUND    stone cracked under the pressure, crimson light glowing up through black fissures
--   LIGHT     one crimson point light (no shadows)

local RS = game:GetService("ReplicatedStorage")

local TEX = {
	bolt = "rbxassetid://139812203434572",
	ring = "rbxassetid://127287526243837",
	crater = "rbxassetid://136654840781472",
	streak = "rbxassetid://104487320138917",
}

local KEY = "ConquerorsHaki"
local TIER = "D"
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

-- an attachment whose X axis (a beam's curve direction) points along `axis`
local function axisCF(pos: Vector3, axis: Vector3): CFrame
	local x = axis.Unit
	local up = if math.abs(x.Y) > 0.9 then Vector3.new(0, 0, 1) else Vector3.new(0, 1, 0)
	local z = x:Cross(up).Unit
	local y = z:Cross(x).Unit
	return CFrame.fromMatrix(pos, x, y, z)
end

local live = 0
local function cost(rate: number, life: number)
	live += rate * life
end

---------------------------------------------------------------- GROUND
do
	local disc = carrier("Crater", Vector3.new(6.4, 0.05, 6.4), CFrame.new(0, FEET + 0.03, 0))
	decalDisc(disc, TEX.crater, 0, 1.4)
	-- the pressure: a dark-red shockwave ring pulsing out from his feet
	local at = attach("HumanoidRootPart", "Shockwave", CFrame.new(0, FEET + 0.1, 0))
	local rate, life = 0.8, 1.3
	emitter("Shockwave", {
		Texture = TEX.ring,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top,
		Speed = NR(0.01),
		Size = NS({ { 0, 0.6 }, { 0.5, 3.1 }, { 1, 3.9 } }),
		Transparency = NS({ { 0, 0 }, { 0.6, 0.35 }, { 1, 1 } }),
		Lifetime = NR(life),
		Rate = rate,
		ZOffset = 0.05,
	}, at)
	cost(rate, life)
end

---------------------------------------------------------------- LIGHTNING (Conqueror's Haki)
do
	local function bolts(name: string, vol: Part, size: { number }, rate: number)
		local life = 0.18
		emitter(name, {
			Texture = TEX.bolt,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
			FlipbookMode = Enum.ParticleFlipbookMode.Loop,
			FlipbookFramerate = NR(26, 34),
			FlipbookStartRandom = true,
			LightEmission = 0.25, -- the core is black: only the crimson rim may glow a little
			Brightness = 1.4,
			Orientation = Enum.ParticleOrientation.FacingCamera,
			Size = NS({ { 0, size[1] }, { 1, size[2] } }),
			Transparency = NS({ { 0, 0 }, { 0.7, 0 }, { 1, 1 } }),
			Lifetime = NR(0.12, 0.24),
			Rate = rate,
			Speed = NR(0),
			Rotation = NR(0, 360),
			ZOffset = 0.2,
		}, vol)
		cost(rate, life)
	end
	-- big arcs round him (a volume wider than his body) and lashing out of the ground
	-- (v1 rates 7 and 3.5 gave two bursts in 2.7 s in play: far too quiet for an Emperor)
	bolts("HakiArc", carrier("ArcVolume", Vector3.new(5.6, 4.2, 3.6), CFrame.new(0, -0.4, 0)), { 1.8, 2.6 }, 16)
	bolts("GroundArc", carrier("GroundArcVolume", Vector3.new(6.0, 0.4, 6.0), CFrame.new(0, FEET + 0.6, 0)), { 2.0, 2.7 }, 7)
end

---------------------------------------------------------------- PRESSURE (lines shooting out of him)
do
	-- DARK crimson lines carry it: pale additive lines vanished on the bright sky in play (v1)
	local core = carrier("PressureCore", Vector3.new(3.0, 3.0, 3.0), CFrame.new(0, -0.2, 0))
	local function wind(name: string, rate: number, color: ColorSequence, emission: number, size: { number })
		local life = 0.32
		emitter(name, {
			Texture = TEX.streak,
			Shape = Enum.ParticleEmitterShape.Sphere,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
			LightEmission = emission,
			Brightness = 1.2,
			Color = color,
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Rotation = NR(90), -- VelocityParallel lays the texture's X along the motion: the line is drawn upright
			Size = NS({ { 0, size[1] }, { 0.3, size[2] }, { 1, size[1] } }),
			Transparency = NS({ { 0, 1 }, { 0.15, 0.15 }, { 1, 1 } }),
			Lifetime = NR(0.25, 0.4),
			Rate = rate,
			Speed = NR(12, 18),
			Drag = 3,
			ZOffset = 0.1,
		}, core)
		cost(rate, life)
	end
	wind("PressureDark", 30, CS({ { 0, Color3.fromRGB(110, 0, 18) }, { 1, Color3.fromRGB(30, 0, 6) } }), 0, { 0.7, 1.25 })
	wind("PressurePale", 12, CS({ { 0, Color3.fromRGB(255, 236, 236) }, { 1, Color3.fromRGB(255, 150, 160) } }), 0.3, { 0.5, 0.9 })
end

---------------------------------------------------------------- LIGHTNING (Conqueror's Haki)
do
	local function bolts(name: string, vol: Part, size: { number }, rate: number)
		local life = 0.18
		emitter(name, {
			Texture = TEX.bolt,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
			FlipbookMode = Enum.ParticleFlipbookMode.Loop,
			FlipbookFramerate = NR(26, 34),
			FlipbookStartRandom = true,
			LightEmission = 0.25, -- the core is black: only the crimson rim may glow a little
			Brightness = 1.4,
			Orientation = Enum.ParticleOrientation.FacingCamera,
			Size = NS({ { 0, size[1] }, { 1, size[2] } }),
			Transparency = NS({ { 0, 0 }, { 0.7, 0 }, { 1, 1 } }),
			Lifetime = NR(0.12, 0.24),
			Rate = rate,
			Speed = NR(0),
			Rotation = NR(0, 360),
			ZOffset = 0.2,
		}, vol)
		cost(rate, life)
	end
	-- big arcs round him (a volume wider than his body) and lashing out of the ground
	-- (v1 rates 7 and 3.5 gave two bursts in 2.7 s in play: far too quiet for an Emperor)
	bolts("HakiArc", carrier("ArcVolume", Vector3.new(5.6, 4.2, 3.6), CFrame.new(0, -0.4, 0)), { 1.8, 2.6 }, 16)
	bolts("GroundArc", carrier("GroundArcVolume", Vector3.new(6.0, 0.4, 6.0), CFrame.new(0, FEET + 0.6, 0)), { 2.0, 2.7 }, 7)
end

---------------------------------------------------------------- PRESSURE (wind lines shooting out of him)
do
	local core = carrier("PressureCore", Vector3.new(3.0, 3.0, 3.0), CFrame.new(0, -0.2, 0))
	local rate, life = 26, 0.32
	emitter("PressureWind", {
		Texture = TEX.streak,
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
		LightEmission = 0.3,
		Brightness = 1.6,
		Color = CS({ { 0, Color3.fromRGB(255, 236, 236) }, { 1, Color3.fromRGB(255, 150, 160) } }),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Rotation = NR(90), -- VelocityParallel lays the texture's X along the motion: the line is drawn upright
		Size = NS({ { 0, 0.5 }, { 0.3, 0.9 }, { 1, 0.6 } }),
		Transparency = NS({ { 0, 1 }, { 0.15, 0.35 }, { 1, 1 } }),
		Lifetime = NR(0.25, 0.4),
		Rate = rate,
		Speed = NR(10, 15),
		Drag = 3,
		ZOffset = 0.1,
	}, core)
	cost(rate, life)
end

---------------------------------------------------------------- LIGHT
do
	local d = Instance.new("Folder")
	d.Name = "Direct"
	d.Parent = group("UpperTorso")
	local l = Instance.new("PointLight")
	l.Name = "CrimsonLight"
	l.Color = Color3.fromRGB(255, 40, 50)
	l.Brightness = 1.4
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
out:SetAttribute("Source", "custom:conquerors_haki")
out:SetAttribute("Tier", TIER)
out:SetAttribute("K", 1)
local old = dest:FindFirstChild(KEY)
if old then
	old:Destroy()
end
out.Parent = dest
table.insert(report, ("%s built: live ~%d"):format(KEY, math.floor(live + 0.5)))

---------------------------------------------------------------- re-dress Shanks's preview stand
local yard = workspace:FindFirstChild("AuraAssignPreview")
local slot = yard and yard:FindFirstChild("Heroes") and yard.Heroes:FindFirstChild("Shanks")
local oldHero = slot and slot:FindFirstChild("red_haired_emperor")
local template = assets.Characters:FindFirstChild("Char_red_haired_emperor")
if slot and oldHero and template then
	local pivot = oldHero:GetPivot()
	local hero = template:Clone()
	hero.Name = "red_haired_emperor"
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
				piece.CFrame = root.CFrame * (if typeof(rootCf) == "CFrame" then rootCf else CFrame.new())
				piece.Parent = hero
			end
		end
	end
	clone:Destroy()
	oldHero:Destroy()
	hero.Parent = slot
	local renamed = 0
	for _, d in slot:GetDescendants() do
		if d:IsA("TextLabel") and string.find(d.Text, "FieryRitual", 1, true) then
			d.Text = string.gsub(d.Text, "FieryRitual", "Conqueror's Haki")
			renamed += 1
		end
	end
	table.insert(report, ("preview stand re-dressed (%d sign line(s) renamed)"):format(renamed))
else
	table.insert(report, "no preview stand for Shanks (skipped)")
end

return table.concat(report, "\n")
