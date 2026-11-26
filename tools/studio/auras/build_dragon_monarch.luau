-- build_dragon_monarch.luau - Studio EDIT mode, rerunnable:
--   python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file tools/studio/auras/build_dragon_monarch.luau
-- Builds ReplicatedStorage.Assets.Auras.DragonMonarch: Antares's (dragon_monarch, Legendary) hero aura.
--
-- His body keeps the pack aura he wears, COPIED VERBATIM from its preview conversion
-- (ServerStorage.AuraPreview.Templates.P22 = Pack1 "Cinder"); the owner's rule: an aura he already has is kept
-- exactly and built around. This adds the King of Dragons' imagery round it, never more fire:
--   WINGS    a pair of crimson dragon wings on his back, beating slowly (a 2 s beat), black finger bones,
--            glowing scalloped edges; planes fixed to his back (VelocityPerpendicular along +Z), not sprites
--            that turn to the camera, so they read right from behind too
--   SEAL     the Monarch of Destruction's mark on the floor (SurfaceGui, turning): a dark stone disc torn by
--            three molten dragon-claw gouges, red cracks spreading, a ring of dragon scales
--   FEAR     Dragon's Fear: a dark red pressure wave rolling out over the floor every 2.4 s
--   SCALES   crimson dragon scales drifting up off him
-- Textures: tools/auras/dragon_monarch/make_tex.py (ids in assets/auras/dragon_monarch/ids.json); the ripple is
-- the roblox-vfx skill's library (uploaded for SunBreathing). Layout is HeroAura.luau's template format (every
-- CFrame in the hero ROOT's space at rest, R15, feet at y -3, the hero faces -Z). Size is HALF the drawn width.

local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local TEX = {
	wingR = "rbxassetid://103421225861609", -- root at the frame's LEFT edge
	wingL = "rbxassetid://100117565289321", -- mirrored: root at the RIGHT edge
	seal = "rbxassetid://84679189516666",
	scale = "rbxassetid://79052555805617",
	ripple = "rbxassetid://74763263739033", -- lib ripple_fb_glow_02 (4x4 one-shot)
}

local KEY = "DragonMonarch"
local HERO = "dragon_monarch"
local SLOT = "Antares"
local ORIGINAL = "P22" -- ServerStorage.AuraPreview.Templates.P22 = Pack1 "Cinder", converted
local OLD_NAME = "Cinder"
local NEW_NAME = "Dragon Monarch"
local FEET = -3.0
local SEAL_R = 3.4
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

---------------------------------------------------------------- THE ORIGINAL (copied verbatim)
local templates = SS:FindFirstChild("AuraPreview") and SS.AuraPreview:FindFirstChild("Templates")
local original = templates and templates:FindFirstChild(ORIGINAL)
assert(
	original,
	"ServerStorage.AuraPreview.Templates."
		.. ORIGINAL
		.. " is missing: run tools/aura_assign.py build first"
)
for _, g in original:GetChildren() do
	for _, piece in g:GetChildren() do
		piece:Clone().Parent = group(g.Name)
	end
end
live += (original:GetAttribute("Live") or 0) :: number

---------------------------------------------------------------- WINGS (beating slowly)
do
	-- each wing is one particle on a plane fixed to his back: velocity along +Z (behind him), so the quad lies
	-- in his back's plane. The wing's root is at the texture's edge, so each particle sits half its width out
	-- from the shoulder blade. A 2 s beat (16 frames at 8 fps); two copies alive, born exactly one beat apart,
	-- so they always show the same frame (no doubling), and a new one fades in under the old one.
	local S = 2.9 -- half the drawn width: a ~5.8-stud wing (2.0 barely cleared his head, v1)
	local ROOT_X, ROOT_Y, ROOT_Z = 0.3, 0.55, 0.65
	for _, side in { 1, -1 } do
		local a = attach(
			"UpperTorso",
			"Wing",
			CFrame.new(side * (ROOT_X + S * 0.95), ROOT_Y + 0.35, ROOT_Z)
		)
		local life = 4
		emitter("DragonWing", {
			-- his +X side reads on the viewer's left from the front: that wing's root is the texture's RIGHT edge
			Texture = if side == 1 then TEX.wingL else TEX.wingR,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
			FlipbookMode = Enum.ParticleFlipbookMode.Loop,
			FlipbookFramerate = NR(8),
			FlipbookStartRandom = false,
			Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
			EmissionDirection = Enum.NormalId.Back,
			SpreadAngle = Vector2.new(0, 0),
			Speed = NR(0.001),
			LockedToPart = true,
			Size = NS({ { 0, S }, { 1, S } }),
			Transparency = NS({ { 0, 1 }, { 0.1, 0 }, { 0.9, 0 }, { 1, 1 } }),
			Lifetime = NR(life),
			Rate = 2 / life,
			Rotation = NR(0),
			ZOffset = -1.2,
			LightEmission = 0.15,
			Brightness = 1.2,
		}, a)
		cost(2 / life, life)
	end
end

---------------------------------------------------------------- SEAL (the Monarch of Destruction's mark)
do
	local seal = carrier(
		"MonarchSeal",
		Vector3.new(SEAL_R * 2, 0.05, SEAL_R * 2),
		CFrame.new(0, FEET + 0.04, 0),
		Vector3.new(0, -0.15, 0)
	)
	local g = Instance.new("SurfaceGui")
	g.Name = "Seal"
	g.Face = Enum.NormalId.Top
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 64
	g.LightInfluence = 0
	g.Brightness = 1.3
	g.AlwaysOnTop = false
	g.ClipsDescendants = true
	g.Parent = seal
	local img = Instance.new("ImageLabel")
	img.Name = "Image"
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = TEX.seal
	img.Parent = g
end

---------------------------------------------------------------- FEAR (a pressure wave over the floor)
do
	local floor = carrier("FearFloor", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, FEET + 0.1, 0))
	local rate, life = 1 / 2.4, 1.3
	emitter("DragonFear", {
		Texture = TEX.ripple,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular, -- flat on the floor
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(0, 0),
		Speed = NR(0.001),
		LockedToPart = true,
		Size = NS({ { 0, 4.0 }, { 1, 4.6 } }),
		Transparency = NS({ { 0, 0.25 }, { 0.7, 0.5 }, { 1, 1 } }),
		Color = ColorSequence.new(Color3.fromHex("C81E14"), Color3.fromHex("6A0A0A")),
		Lifetime = NR(life),
		Rate = rate,
		LightEmission = 0.4,
		Brightness = 1.2,
		ZOffset = 0.1,
	}, floor)
	cost(rate, life)
end

---------------------------------------------------------------- SCALES (drifting up off him)
do
	local vol = carrier("ScaleVolume", Vector3.new(3.6, 3.6, 2.2), CFrame.new(0, -0.8, 0.3))
	local rate, life = 5, 2.2
	emitter("DragonScale", {
		Texture = TEX.scale,
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NS({ { 0, 0 }, { 0.15, 0.15 }, { 0.85, 0.13 }, { 1, 0 } }),
		Transparency = NS({ { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } }),
		Lifetime = NR(life * 0.7, life * 1.3),
		Rate = rate,
		Speed = NR(0.6, 1.4),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(40, 40),
		Acceleration = Vector3.new(0, 0.4, 0),
		Drag = 0.6,
		Rotation = NR(0, 360),
		RotSpeed = NR(-120, 120),
		ZOffset = 0.3,
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
	"custom:dragon_monarch (Cinder pack verbatim + dragon wings, Monarch seal)"
)
out:SetAttribute("Tier", "D")
out:SetAttribute("K", 1)
local old = dest:FindFirstChild(KEY)
if old then
	old:Destroy()
end
out.Parent = dest
table.insert(report, ("%s built: live ~%d"):format(KEY, math.floor(live + 0.5)))

---------------------------------------------------------------- re-dress Antares's preview stand
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
			d.Text = string.gsub(d.Text, OLD_NAME, NEW_NAME)
			table.insert(signs, d.Text)
		end
	end
	table.insert(report, "preview stand re-dressed; sign: " .. table.concat(signs, " | "))
else
	table.insert(report, "no preview stand for Antares (skipped)")
end

return table.concat(report, "\n")
