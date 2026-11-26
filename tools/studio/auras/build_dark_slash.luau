-- build_dark_slash.luau - Studio EDIT mode, rerunnable:
--   python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file tools/studio/auras/build_dark_slash.luau
-- Builds ReplicatedStorage.Assets.Auras.DarkSlash: Yami Sukehiro's (dark_slash_captain) hero aura,
-- hand-authored with the roblox-vfx skill's authoring route. Every texture is our own
-- (tools/auras/dark_slash/make_tex.py, ids in assets/auras/dark_slash/ids.json).
-- Then re-dresses Yami's stand in Workspace.AuraAssignPreview (if it is there).
-- Layout is HeroAura.luau's template format (every CFrame in the hero ROOT's space at rest, R15,
-- feet at y -3, the hero faces -Z; see build_demon_king.luau for the full list).
--
-- No flame tongues (the owner's brief). Yami's Dark Magic:
--   RIFTS     dimension slashes beside and above him at sword angles: a white-hot stroke swipes, splits open into a crescent of
--             black void, then seals
--   MOON      a black crescent moon with a white rim behind him (his Dark Cloaked Black Moon; a
--             self-lit billboard, depth tested)
--   GROUND    a black ink pool on the stand with two crossed dimension cuts in it
--   INK       calligraphy strokes of darkness rising round his legs and dissolving
--   LIGHT     one cold violet point light (no shadows)

local RS = game:GetService("ReplicatedStorage")

local TEX = {
	rift = "rbxassetid://125416359814784",
	moon = "rbxassetid://95658221517313",
	pool = "rbxassetid://109215954245909",
	brush = "rbxassetid://71238346206941",
}

local KEY = "DarkSlash"
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

---------------------------------------------------------------- GROUND
do
	local disc = carrier("InkPool", Vector3.new(7.2, 0.05, 7.2), CFrame.new(0, FEET + 0.03, 0)) -- 6.2 hid under his feet
	decalDisc(disc, TEX.pool, 0, 1)
end

---------------------------------------------------------------- MOON
do
	local a = attach("HumanoidRootPart", "BlackMoon", CFrame.new(0.25, 2.45, 1.0)) -- 3.8 at 2.15 hid behind his hair
	billboard(a, TEX.moon, 5.0, 0.02, 1.1)
end

---------------------------------------------------------------- RIFTS (dimension slashes)
do
	-- Slashes BESIDE and ABOVE him at sword angles, mirrored left and right, and an arc over his head.
	-- (v1 emitted them anywhere round his body at any angle 0-360: upside-down and vertical slits
	-- across his face read as odd.)
	local spots = {
		{ name = "RiftLeft", size = Vector3.new(1.4, 3.0, 1.2), at = CFrame.new(-2.3, 0.7, 0.1), rot = NR(14, 38), rate = 1.25 },
		{ name = "RiftRight", size = Vector3.new(1.4, 3.0, 1.2), at = CFrame.new(2.3, 0.7, 0.1), rot = NR(-38, -14), rate = 1.25 },
		{ name = "RiftCrown", size = Vector3.new(2.6, 0.5, 1.0), at = CFrame.new(0, 3.3, 0.3), rot = NR(172, 188), rate = 0.7 },
	}
	for _, sp in spots do
		local vol = carrier(sp.name, sp.size, sp.at)
		local life = 1.0
		emitter("Rift", {
			Texture = TEX.rift,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
			FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			LightEmission = 0.12,
			Brightness = 1.3,
			Orientation = Enum.ParticleOrientation.FacingCamera,
			Size = NS({ { 0, 2.0 }, { 1, 2.15 } }),
			Transparency = NS({ { 0, 0 }, { 1, 0 } }),
			Lifetime = NR(0.9, 1.1),
			Rate = sp.rate,
			Speed = NR(0),
			Rotation = sp.rot,
			ZOffset = 0.3,
		}, vol)
		cost(sp.rate, life)
	end
end

---------------------------------------------------------------- INK (brush strokes rising)
do
	local vol = carrier("InkVolume", Vector3.new(4.6, 0.6, 3.6), CFrame.new(0, FEET + 0.7, 0))
	local rate, life = 8, 1.2
	emitter("InkStroke", {
		Texture = TEX.brush,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		LightEmission = 0,
		Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
		Size = NS({ { 0, 0.95 }, { 1, 1.15 } }),
		Transparency = NS({ { 0, 0 }, { 1, 0.1 } }),
		Lifetime = NR(1.0, 1.4),
		Rate = rate,
		Speed = NR(1.0, 1.6),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(10, 10),
		Drag = 0.6,
		Rotation = NR(-20, 20),
		ZOffset = -0.5,
	}, vol)
	cost(rate, life)
end

---------------------------------------------------------------- LIGHT
do
	local d = Instance.new("Folder")
	d.Name = "Direct"
	d.Parent = group("UpperTorso")
	local l = Instance.new("PointLight")
	l.Name = "VioletLight"
	l.Color = Color3.fromRGB(130, 100, 200)
	l.Brightness = 1.1
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
out:SetAttribute("Source", "custom:dark_slash")
out:SetAttribute("Tier", TIER)
out:SetAttribute("K", 1)
local old = dest:FindFirstChild(KEY)
if old then
	old:Destroy()
end
out.Parent = dest
table.insert(report, ("%s built: live ~%d"):format(KEY, math.floor(live + 0.5)))

---------------------------------------------------------------- re-dress Yami's preview stand
local yard = workspace:FindFirstChild("AuraAssignPreview")
local slot = yard and yard:FindFirstChild("Heroes") and yard.Heroes:FindFirstChild("Yami Sukehiro")
local oldHero = slot and slot:FindFirstChild("dark_slash_captain")
local template = assets.Characters:FindFirstChild("Char_dark_slash_captain")
if slot and oldHero and template then
	local pivot = oldHero:GetPivot()
	local hero = template:Clone()
	hero.Name = "dark_slash_captain"
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
		if d:IsA("TextLabel") and string.find(d.Text, "Manifestation of Chaos", 1, true) then
			d.Text = string.gsub(d.Text, "Manifestation of Chaos", "Dark Slash")
			renamed += 1
		end
	end
	table.insert(report, ("preview stand re-dressed (%d sign line(s) renamed)"):format(renamed))
else
	table.insert(report, "no preview stand for Yami (skipped)")
end

return table.concat(report, "\n")
