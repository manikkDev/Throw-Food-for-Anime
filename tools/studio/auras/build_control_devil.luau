-- build_control_devil.luau - Studio EDIT mode, rerunnable:
--   python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file tools/studio/auras/build_control_devil.luau
-- Builds ReplicatedStorage.Assets.Auras.ControlDevil: Makima's (demon_lord_heir) hero aura, hand-authored
-- with the roblox-vfx skill's authoring route. Every texture is our own (tools/auras/control_devil/make_tex.py,
-- ids in assets/auras/control_devil/ids.json; the glint and the eye flare reuse ShadowArise's uploads).
-- Then re-dresses Makima's stand in Workspace.AuraAssignPreview (if it is there).
-- Layout is HeroAura.luau's template format (every CFrame in the hero ROOT's space at rest, R15,
-- feet at y -3, the hero faces -Z; see build_demon_king.luau for the full list).
--
-- No flame tongues (the owner's brief). Makima's own language:
--   GAZE      her ringed iris as a sigil under her feet (turning slowly), gold rings rippling out of it,
--             and the same rings as a halo behind her head (a self-lit billboard, depth tested)
--   LEASHES   two of her dogs sitting at her sides (profile billboards, facing outward), a chain from
--             each hand sagging to the gold ring on its collar
--   CONTRACTS two more chains from her back pinned into the ground behind her
--   MENACE    a dark crimson haze welling up behind her (soft, slow: no flames)
--   GLINTS    gold glints rising, a gold glint at her eyes, one amber light

local RS = game:GetService("ReplicatedStorage")

local TEX = {
	sigil = "rbxassetid://102159254841618",
	halo = "rbxassetid://139022732517188",
	chain = "rbxassetid://95070851575174",
	dogL = "rbxassetid://111179516061437",
	dogR = "rbxassetid://90318809747203",
	pulse = "rbxassetid://92469778497088",
	spark = "rbxassetid://103499805716782",
	eye = "rbxassetid://124207407785051",
	haze = "rbxassetid://89331996672714", -- DemonKing's blood mist
}

local KEY = "ControlDevil"
local TIER = "E"
local FEET = -3.0
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 196, 52)

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

local function billboard(a: Attachment, image: string, size: number, transparency: number, brightness: number)
	local g = Instance.new("BillboardGui")
	g.Name = "Billboard"
	g.Size = UDim2.fromScale(size, size) -- studs
	g.LightInfluence = 0
	g.Brightness = brightness
	g.AlwaysOnTop = false
	g.MaxDistance = 140
	g.ResetOnSpawn = false
	g.Parent = a
	local img = Instance.new("ImageLabel")
	img.Name = "Image"
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = image
	img.ImageTransparency = transparency
	img.Parent = g
end

local function chainBeam(a0: Attachment, a1: Attachment, width: number, c0: number, c1: number)
	local b = Instance.new("Beam")
	b.Name = "Chain"
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Texture = TEX.chain
	b.TextureMode = Enum.TextureMode.Wrap
	b.TextureLength = width * 4 -- the strip is 4:1, so the links keep their shape
	b.Width0 = width
	b.Width1 = width
	b.CurveSize0 = c0
	b.CurveSize1 = c1
	b.Segments = 16
	b.FaceCamera = true
	b.LightEmission = 0
	b.LightInfluence = 0
	b.Brightness = 1.5
	b.Color = CS({ { 0, WHITE }, { 1, WHITE } })
	b.Transparency = NS({ { 0, 0 }, { 1, 0 } })
	b.Parent = group("Beams")
end

---------------------------------------------------------------- GAZE
do
	local disc = carrier("GazeSigil", Vector3.new(6.4, 0.05, 6.4), CFrame.new(0, FEET + 0.03, 0), Vector3.new(0, 0.12, 0))
	decalDisc(disc, TEX.sigil, 0, 1.15)
	local ripple = attach("HumanoidRootPart", "Ripple", CFrame.new(0, FEET + 0.08, 0))
	local rate, life = 0.6, 1.7
	emitter("GazeRipple", {
		Texture = TEX.pulse,
		LightEmission = 0.4,
		Brightness = 1.6,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top,
		Speed = NR(0.01),
		Size = NS({ { 0, 0.5 }, { 0.6, 2.8 }, { 1, 3.4 } }),
		Transparency = NS({ { 0, 0.1 }, { 0.6, 0.4 }, { 1, 1 } }),
		Lifetime = NR(life),
		Rate = rate,
		ZOffset = 0.05,
	}, ripple)
	cost(rate, life)
	local h = attach("HumanoidRootPart", "Halo", CFrame.new(0, 1.95, 0.9)) -- v1 hid behind her head and hair
	billboard(h, TEX.halo, 4.4, 0.02, 1.6)
end

---------------------------------------------------------------- LEASHES (her dogs)
do
	-- her right hand is +X; seen from the front that is the viewer's left, so the +X dog is the one facing left
	for _, side in { 1, -1 } do
		local size = 2.25
		local dogAt = Vector3.new(side * 2.75, FEET + size / 2 - 0.09, 0.35)
		local d = attach("HumanoidRootPart", "Dog", CFrame.new(dogAt))
		billboard(d, if side == 1 then TEX.dogL else TEX.dogR, size, 0, 1)
		-- the collar ring sits 0.3 toward the dog's front (outward) and 1.15 above its feet
		local collar = attach("HumanoidRootPart", "Collar", axisCF(Vector3.new(side * 3.1, FEET + 1.36, 0.3), Vector3.new(0, 1, 0)))
		local hand = attach(if side == 1 then "RightHand" else "LeftHand", "Leash",
			axisCF(Vector3.new(side * 1.5, -1.0, -0.05), Vector3.new(0, -1, 0)))
		chainBeam(hand, collar, 0.36, 0.6, 0.5) -- both curve points below the line: the leash sags
	end
end

---------------------------------------------------------------- CONTRACTS (chains into the ground behind her)
do
	for _, side in { 1, -1 } do
		local back = attach("UpperTorso", "Contract", axisCF(Vector3.new(side * 0.4, 0.1, 0.5), Vector3.new(side * 0.3, -0.2, 1)))
		local pin = attach("HumanoidRootPart", "Pin", axisCF(Vector3.new(side * 1.7, FEET + 0.08, 2.6), Vector3.new(0, 1, 0)))
		chainBeam(back, pin, 0.3, 1.0, 0.6)
	end
end

---------------------------------------------------------------- MENACE (a dark crimson haze behind her)
do
	local vol = carrier("HazeVolume", Vector3.new(5.0, 3.6, 0.6), CFrame.new(0, -0.6, 0.9)) -- wider than her: 3.4 hid behind her body
	local rate, life = 5, 2.6
	emitter("Haze", {
		Texture = TEX.haze,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NS({ { 0, 1.2 }, { 1, 2.3 } }),
		Transparency = NS({ { 0, 0.25 }, { 1, 0.6 } }),
		Lifetime = NR(2.2, 3.0),
		Rate = rate,
		Speed = NR(0.3, 0.7),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(25, 25),
		Drag = 0.5,
		Rotation = NR(0, 360),
		RotSpeed = NR(-8, 8),
		ZOffset = -1.6,
	}, vol)
	cost(rate, life)
end

---------------------------------------------------------------- GLINTS
do
	local vol = carrier("GlintVolume", Vector3.new(5.2, 0.4, 5.2), CFrame.new(0, FEET + 0.3, 0))
	local rate, life = 6, 2.2
	emitter("Glint", {
		Texture = TEX.spark,
		LightEmission = 0.6,
		Brightness = 2.2,
		Color = CS({ { 0, Color3.fromRGB(255, 235, 170) }, { 0.5, GOLD }, { 1, Color3.fromRGB(214, 120, 18) } }),
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NS({ { 0, 0.04 }, { 0.3, 0.14, 0.04 }, { 1, 0 } }),
		Transparency = NS({ { 0, 0 }, { 0.75, 0.15 }, { 1, 1 } }),
		Lifetime = NR(1.8, 2.6),
		Rate = rate,
		Speed = NR(0.6, 1.4),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(12, 12),
		Drag = 0.6,
		Rotation = NR(0, 45),
		ZOffset = 0.3,
	}, vol)
	cost(rate, life)
	for _, side in { 1, -1 } do
		local a = attach("Head", "EyeGlint", CFrame.new(side * 0.19, 1.56, -0.6))
		local r2, l2 = 6, 0.35
		emitter("Eye", {
			Texture = TEX.eye,
			LightEmission = 1,
			Brightness = 2.6,
			Color = CS({ { 0, Color3.fromRGB(255, 235, 170) }, { 1, GOLD } }),
			Orientation = Enum.ParticleOrientation.FacingCamera,
			LockedToPart = true,
			Size = NS({ { 0, 0.12 }, { 0.5, 0.17 }, { 1, 0.12 } }),
			Transparency = NS({ { 0, 0.3 }, { 0.5, 0 }, { 1, 0.3 } }),
			Lifetime = NR(l2),
			Rate = r2,
			Speed = NR(0),
			ZOffset = 0.3,
		}, a)
		cost(r2, l2)
	end
	local d = Instance.new("Folder")
	d.Name = "Direct"
	d.Parent = group("UpperTorso")
	local l = Instance.new("PointLight")
	l.Name = "AmberLight"
	l.Color = Color3.fromRGB(255, 170, 70)
	l.Brightness = 1.2
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
out:SetAttribute("Source", "custom:control_devil")
out:SetAttribute("Tier", TIER)
out:SetAttribute("K", 1)
local old = dest:FindFirstChild(KEY)
if old then
	old:Destroy()
end
out.Parent = dest
table.insert(report, ("%s built: live ~%d"):format(KEY, math.floor(live + 0.5)))

---------------------------------------------------------------- re-dress Makima's preview stand
local yard = workspace:FindFirstChild("AuraAssignPreview")
local slot = yard and yard:FindFirstChild("Heroes") and yard.Heroes:FindFirstChild("Makima")
local oldHero = slot and slot:FindFirstChild("demon_lord_heir")
local template = assets.Characters:FindFirstChild("Char_demon_lord_heir")
if slot and oldHero and template then
	local pivot = oldHero:GetPivot()
	local hero = template:Clone()
	hero.Name = "demon_lord_heir"
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
		if d:IsA("TextLabel") and string.find(d.Text, "Hellzone Champion", 1, true) then
			d.Text = string.gsub(d.Text, "Hellzone Champion", "Control Devil")
			renamed += 1
		end
	end
	table.insert(report, ("preview stand re-dressed (%d sign line(s) renamed)"):format(renamed))
else
	table.insert(report, "no preview stand for Makima (skipped)")
end

return table.concat(report, "\n")
