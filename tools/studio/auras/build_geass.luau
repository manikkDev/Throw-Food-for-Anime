-- build_geass.luau - Studio EDIT mode, rerunnable:
--   python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file tools/studio/auras/build_geass.luau
-- Builds ReplicatedStorage.Assets.Auras.Geass: Lelouch's (rebel_emperor, Epic) hero aura.
--
-- His body keeps the pack aura he wears, COPIED VERBATIM from its preview conversion
-- (ServerStorage.AuraPreview.Templates.P58 = Pack4 "Heaven", cloned as ONE piece: its limb beams must keep
-- pointing at the copied attachments). Round it, his own power and his own symbol, never fire:
--   BOARD    the floor (SurfaceGui): a round chessboard, black and royal-purple lacquer squares, gold inlay,
--            the Geass bird engraved in dark crimson at the centre (he reads the war as a board)
--   SIGIL    the engraving lit from inside (a second SurfaceGui on the board's own canvas, so it lies exactly on
--            the engraving), a crimson glow breathing under it and the Geass's ring rolling out over the board
--   EYE      the Geass in his LEFT eye: the bird sigil white-hot in a crimson halo, and a crimson light on his face
--   CAST     every 2.5 s the Geass is cast: the eye flares and a train of crimson rings flies out of it and grows
--   KINGS    the BLACK KING (Zero) floating at his right hand, tilted, turning slowly over a crimson glow; the
--            WHITE KING toppled on the board's edge (his opponent has resigned): real meshes,
--            ServerStorage.AuraSources.Geass.BlackKing / .WhiteKing (generate_mesh; never delete)
--   MOTES    crimson diamond glints rising off the board
-- Textures: tools/auras/geass/make_tex.py (ids in assets/auras/geass/ids.json). Layout is HeroAura.luau's template
-- format (every CFrame in the hero ROOT's space at rest, R15, feet at y -3, the hero faces -Z, his left is -X).
-- ParticleEmitter Size is HALF the drawn width.

local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local TEX = {
	board = "rbxassetid://71643905840537",
	sigilLit = "rbxassetid://71183470940841", -- on the board's canvas
	eye = "rbxassetid://84755562942873",
	wave = "rbxassetid://76130450390122",
	mote = "rbxassetid://112624866168576",
	soft = "rbxassetid://113778679887869",
}

local KEY = "Geass"
local HERO = "rebel_emperor"
local SLOT = "Lelouch"
local ORIGINAL = "P58" -- ServerStorage.AuraPreview.Templates.P58 = Pack4 "Heaven", converted
local OLD_NAME = "Heaven"
local NEW_NAME = "Geass"
local FEET = -3.0
local BOARD_R = 3.2
local EYE = Vector3.new(-0.29, 1.56, -0.62) -- his LEFT eye's red iris (-X) on the face decal (head centre y 1.586)
local KING_AT = CFrame.new(2.35, -0.35, -0.75) * CFrame.Angles(0, 0, math.rad(-9))
local WHITE = Color3.new(1, 1, 1)

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
	e.LightEmission = 0
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

local live = 0
local function cost(rate: number, life: number, n: number?)
	live += rate * life * (n or 1)
end

local CRIMSON = ColorSequence.new(hex("FF2A4A"), hex("E0102C"))

---------------------------------------------------------------- THE ORIGINAL (copied verbatim)
-- cloned as ONE piece first, so its Beams keep pointing at the copied attachments
local templates = SS:FindFirstChild("AuraPreview") and SS.AuraPreview:FindFirstChild("Templates")
local original = templates and templates:FindFirstChild(ORIGINAL)
assert(
	original,
	"ServerStorage.AuraPreview.Templates."
		.. ORIGINAL
		.. " is missing: run tools/aura_assign.py build first"
)
local copy = original:Clone()
for _, g in copy:GetChildren() do
	for _, piece in g:GetChildren() do
		piece.Parent = group(g.Name)
	end
end
copy:Destroy()
live += (original:GetAttribute("Live") or 0) :: number

---------------------------------------------------------------- BOARD (the floor) and SIGIL (its engraving, lit)
do
	local p = carrier(
		"KingsBoard",
		Vector3.new(BOARD_R * 2, 0.05, BOARD_R * 2),
		CFrame.new(0, FEET + 0.04, 0)
	)
	local g = Instance.new("SurfaceGui")
	g.Name = "Image"
	g.Face = Enum.NormalId.Top
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 80
	g.LightInfluence = 0
	g.Brightness = 1
	g.AlwaysOnTop = false
	g.ClipsDescendants = true
	g.Parent = p
	local img = Instance.new("ImageLabel")
	img.Name = "Image"
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = TEX.board
	img.Parent = g

	-- the engraving LIT: a second SurfaceGui the board's size, painted on the board's own canvas, so it lies
	-- exactly on the engraving (a flat particle's in-plane turn is not stable: v1's flipbook lay at an angle to
	-- it and turned with the camera). Motion comes from layers that look the same at any turn:
	local glow = carrier(
		"SigilGlow",
		Vector3.new(BOARD_R * 2, 0.05, BOARD_R * 2),
		CFrame.new(0, FEET + 0.07, 0)
	)
	local g2 = Instance.new("SurfaceGui")
	g2.Name = "Image"
	g2.Face = Enum.NormalId.Top
	g2.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g2.PixelsPerStud = 80
	g2.LightInfluence = 0
	g2.Brightness = 1.6
	g2.AlwaysOnTop = false
	g2.ClipsDescendants = true
	g2.Parent = glow
	local img2 = Instance.new("ImageLabel")
	img2.Name = "Image"
	img2.BackgroundTransparency = 1
	img2.Size = UDim2.fromScale(1, 1)
	img2.Image = TEX.sigilLit
	img2.Parent = g2

	local flat = carrier("SigilPulse", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, FEET + 0.1, 0))
	-- a crimson glow breathing under the bird (one at a time: rate x life = 1)
	emitter("SigilBreath", {
		Texture = TEX.soft,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(0, 0),
		Speed = NR(0.001),
		LockedToPart = true,
		Size = NS({ { 0, 1.8 }, { 0.5, 2.3 }, { 1, 1.8 } }),
		Transparency = NS({ { 0, 1 }, { 0.5, 0.45 }, { 1, 1 } }),
		Color = ColorSequence.new(hex("FF1E46"), hex("B0103A")),
		Lifetime = NR(2),
		Rate = 0.5,
		LightEmission = 1,
		Brightness = 1.3,
		ZOffset = 0.05,
	}, flat)
	cost(0.5, 2)
	-- the Geass's ring rolling out over the board from his feet, every 2 s
	emitter("BoardRipple", {
		Texture = TEX.wave,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(0, 0),
		Speed = NR(0.001),
		LockedToPart = true,
		Size = NS({ { 0, 0.6 }, { 1, 3.1 } }),
		Transparency = NS({ { 0, 1 }, { 0.15, 0.35 }, { 0.7, 0.6 }, { 1, 1 } }),
		Color = CRIMSON,
		Lifetime = NR(1.8),
		Rate = 0.5,
		LightEmission = 1,
		Brightness = 1.6,
		ZOffset = 0.06,
	}, flat)
	cost(0.5, 1.8)
end

---------------------------------------------------------------- EYE (the Geass in his left eye)
do
	local a = attach("Head", "GeassEye", CFrame.new(EYE))
	local life = 1.2
	emitter("GeassEye", {
		Texture = TEX.eye,
		Orientation = Enum.ParticleOrientation.FacingCamera,
		LockedToPart = true,
		Size = NS({ { 0, 0.17 }, { 0.5, 0.2 }, { 1, 0.17 } }),
		Transparency = NS({ { 0, 1 }, { 0.15, 0 }, { 0.85, 0 }, { 1, 1 } }),
		Lifetime = NR(life),
		Rate = 2 / life,
		Speed = NR(0),
		LightEmission = 1,
		Brightness = 3,
		ZOffset = 1,
	}, a)
	cost(2 / life, life)
	-- a crimson light on his face from the eye (a light lights surfaces: keep it small)
	local direct = group("Head"):FindFirstChild("Direct") or Instance.new("Folder")
	direct.Name = "Direct"
	direct.Parent = group("Head")
	local l = Instance.new("PointLight")
	l.Name = "GeassLight"
	l.Color = hex("FF2040")
	l.Range = 3.5
	l.Brightness = 1.2
	l.Shadows = false
	l.Parent = direct
end

---------------------------------------------------------------- CAST (every 2.5 s)
do
	-- the eye flares and a train of rings flies out of it. The two emitters share one rate and are made
	-- together, so they fire on the same frame.
	local a = attach("Head", "GeassCast", CFrame.new(EYE))
	local rate = 0.4
	emitter("CastFlare", {
		Texture = TEX.eye,
		Orientation = Enum.ParticleOrientation.FacingCamera,
		LockedToPart = true,
		Size = NS({ { 0, 0.2 }, { 0.25, 0.6 }, { 1, 0.15 } }),
		Transparency = NS({ { 0, 0 }, { 0.6, 0.3 }, { 1, 1 } }),
		Lifetime = NR(0.5),
		Rate = rate,
		Speed = NR(0),
		LightEmission = 1,
		Brightness = 3,
		ZOffset = 1.1,
	}, a)
	cost(rate, 0.5)
	emitter("CastWave", {
		Texture = TEX.wave,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Front,
		SpreadAngle = Vector2.new(0, 0),
		Size = NS({ { 0, 0.1 }, { 1, 1.05 } }),
		Transparency = NS({ { 0, 0.05 }, { 0.6, 0.25 }, { 1, 1 } }),
		Color = CRIMSON,
		Lifetime = NR(0.7),
		Rate = rate,
		Speed = NR(5.5),
		Drag = 1.5,
		LightEmission = 1,
		Brightness = 2.5,
		ZOffset = 0.5,
	}, a)
	cost(rate, 0.7)
end

---------------------------------------------------------------- KINGS (the black king floats, the white king lies)
local src = SS:FindFirstChild("AuraSources") and SS.AuraSources:FindFirstChild("Geass")
local missing = {}
local function piece(name: string, cf: CFrame, spin: Vector3?, tint: Color3?): MeshPart?
	local m = src and src:FindFirstChild(name)
	if not (m and m:IsA("MeshPart")) then
		table.insert(missing, name)
		return nil
	end
	local p = m:Clone()
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.CFrame = cf
	p:SetAttribute("RootCF", cf)
	if spin then
		p:SetAttribute("Spin", spin)
	end
	if tint then
		-- the generated texture came out grey marble: a SurfaceAppearance over the same map, tinted down
		local sa = Instance.new("SurfaceAppearance")
		sa.ColorMap = p.TextureID
		sa.Color = tint
		sa.Parent = p
	end
	p.Parent = group("HumanoidRootPart")
	return p
end
do
	-- the black king, tilted and turning about its own axis (it precesses a little: the tilt is in its RootCF)
	piece("BlackKing", KING_AT, Vector3.new(0, 0.55, 0), Color3.fromRGB(58, 54, 72))
	-- a crimson glow behind and under it
	local a = attach("HumanoidRootPart", "KingGlow", KING_AT * CFrame.new(0, -0.5, 0.25))
	local life = 1.6
	emitter("KingGlow", {
		Texture = TEX.soft,
		Orientation = Enum.ParticleOrientation.FacingCamera,
		LockedToPart = true,
		Size = NS({ { 0, 1.05 }, { 0.5, 1.2 }, { 1, 1.05 } }),
		Transparency = NS({ { 0, 1 }, { 0.2, 0.55 }, { 0.8, 0.55 }, { 1, 1 } }),
		Color = ColorSequence.new(hex("C8102E"), hex("6A1BB0")),
		Lifetime = NR(life),
		Rate = 2 / life,
		Speed = NR(0),
		LightEmission = 1,
		Brightness = 1.4,
		ZOffset = -1,
	}, a)
	cost(2 / life, life)
	-- the white king, toppled on the board's front-left edge (lying on its side, crown toward the rim)
	piece(
		"WhiteKing",
		CFrame.new(-1.75, FEET + 0.36, -1.75)
			* CFrame.Angles(0, math.rad(-35), 0)
			* CFrame.Angles(0, 0, math.rad(90)),
		nil
	)
end

---------------------------------------------------------------- MOTES (glints rising off the board)
do
	local p = carrier("MoteField", Vector3.new(4.6, 0.1, 4.6), CFrame.new(0, FEET + 0.12, 0))
	local rate, life = 5, 1.8
	emitter("GeassMote", {
		Texture = TEX.mote,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		EmissionDirection = Enum.NormalId.Top,
		Size = NS({ { 0, 0.06 }, { 0.5, 0.1 }, { 1, 0 } }),
		Transparency = NS({ { 0, 1 }, { 0.15, 0.1 }, { 1, 1 } }),
		Color = ColorSequence.new(hex("FF8098"), hex("E0102C")),
		Lifetime = NR(life * 0.7, life * 1.2),
		Rate = rate,
		Speed = NR(0.9, 1.8),
		SpreadAngle = Vector2.new(6, 6),
		Drag = 0.4,
		LightEmission = 1,
		Brightness = 2,
		ZOffset = 0.2,
	}, p)
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
	"custom:geass (Heaven pack verbatim + chessboard, Geass sigil, eye, cast rings, black and white kings)"
)
out:SetAttribute("Tier", "C")
out:SetAttribute("K", 1)
local old = dest:FindFirstChild(KEY)
if old then
	old:Destroy()
end
out.Parent = dest
table.insert(report, ("%s built: live ~%d"):format(KEY, math.floor(live + 0.5)))
if #missing > 0 then
	table.insert(
		report,
		"MISSING meshes (skipped): ServerStorage.AuraSources.Geass." .. table.concat(missing, ", ")
	)
end

---------------------------------------------------------------- re-dress Lelouch's preview stand
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
	local clone = out:Clone() -- one piece: the beams keep their attachments
	for _, g in clone:GetChildren() do
		local target = hero:FindFirstChild(g.Name)
		if not target or not target:IsA("BasePart") then
			target = root
		end
		local rest = pose[target.Name] or CFrame.new()
		for _, item in g:GetChildren() do
			if item:IsA("Attachment") then
				item.CFrame = rest:ToObjectSpace(item.CFrame)
				item.Parent = target
			elseif item.Name == "Direct" then
				for _, e in item:GetChildren() do
					e.Parent = target
				end
			elseif item:IsA("BasePart") then
				local rootCf = item:GetAttribute("RootCF")
				item.Anchored = true
				item.CFrame = root.CFrame
					* (if typeof(rootCf) == "CFrame" then rootCf else CFrame.new())
				item.Parent = hero
			end
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
	table.insert(report, "no preview stand for Lelouch (skipped)")
end

return table.concat(report, "\n")
