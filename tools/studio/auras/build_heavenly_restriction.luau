-- build_heavenly_restriction.luau - Studio EDIT mode, rerunnable:
--   python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file tools/studio/auras/build_heavenly_restriction.luau
-- Builds ReplicatedStorage.Assets.Auras.HeavenlyRestriction: Toji Fushiguro's (sorcerer_hunter, Legendary) aura.
--
-- His body keeps the pack aura he wears, COPIED VERBATIM from its preview conversion
-- (ServerStorage.AuraPreview.Templates.P49 = Pack3 "Dummy", beams and all; the owner's rule: an aura he already
-- has is kept exactly and built around). It already spends his whole Legendary particle budget, and Toji has
-- NO cursed energy (Heavenly Restriction), so what is added is cheap and never glows: raw physical power.
--   CRATER   the floor caved in under him: a cracked stone crater, fractures running out past its rim, rubble
--            (pre-coloured SurfaceGui; no particles)
--   CUTS     sorcerer-killer cuts: razor-thin straight cuts flashing across the air beside him and splitting
--   DEBRIS   grey dust puffing off the crater's rim, stone chips hopping up and falling back
-- Textures: tools/auras/heavenly_restriction/make_tex.py (ids in assets/auras/heavenly_restriction/ids.json).
-- Layout is HeroAura.luau's template format (every CFrame in the hero ROOT's space at rest, R15, feet at y -3,
-- the hero faces -Z). ParticleEmitter Size is HALF the drawn width.

local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local TEX = {
	crater = "rbxassetid://92088465051279",
	cut = "rbxassetid://86529906213123",
	pebble = "rbxassetid://92353920442753",
	dust = "rbxassetid://98545631573152", -- lib dust_ground_soft_02 (4x4 one-shot)
}

local KEY = "HeavenlyRestriction"
local HERO = "sorcerer_hunter"
local SLOT = "Toji Fushiguro"
local ORIGINAL = "P49" -- ServerStorage.AuraPreview.Templates.P49 = Pack3 "Dummy", converted
local OLD_NAME = "Dummy %(Pack3%)"
local NEW_NAME = "Heavenly Restriction"
local FEET = -3.0
local CRATER_R = 3.4
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

local function carrier(name: string, size: Vector3, cf: CFrame): Part
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
	p.Parent = group("HumanoidRootPart")
	return p
end

local live = 0
local function cost(rate: number, life: number, n: number?)
	live += rate * life * (n or 1)
end

---------------------------------------------------------------- THE ORIGINAL (copied verbatim)
-- cloned as ONE piece first, so its Beams keep pointing at the copied attachments (a per-piece clone would
-- leave them pointing into the ServerStorage template)
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

---------------------------------------------------------------- CRATER (the floor caved in under him)
do
	local p = carrier(
		"Crater",
		Vector3.new(CRATER_R * 2, 0.05, CRATER_R * 2),
		CFrame.new(0, FEET + 0.04, 0)
	)
	local g = Instance.new("SurfaceGui")
	g.Name = "Crater"
	g.Face = Enum.NormalId.Top
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 64
	g.LightInfluence = 0.6 -- stone, lit by the scene like the floor it is part of
	g.Brightness = 1
	g.AlwaysOnTop = false
	g.ClipsDescendants = true
	g.Parent = p
	local img = Instance.new("ImageLabel")
	img.Name = "Image"
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = TEX.crater
	img.Parent = g
end

---------------------------------------------------------------- CUTS (razor-thin, splitting the air)
do
	for _, side in { 1, -1 } do
		local box = carrier("CutBox", Vector3.new(1.6, 3.4, 2.0), CFrame.new(side * 2.4, -0.4, 0.2))
		local rate, life = 1.2, 0.45 -- 0.75 at Size 1.8 barely showed in a still (v1)
		emitter("SorcererKillerCut", {
			Texture = TEX.cut,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
			FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			Orientation = Enum.ParticleOrientation.FacingCamera,
			Size = NS({ { 0, 2.5 }, { 1, 2.8 } }),
			Transparency = NS({ { 0, 0 }, { 1, 0 } }),
			Lifetime = NR(life),
			Rate = rate,
			Speed = NR(0),
			Rotation = NR(-70, 70),
			ZOffset = 0.3,
		}, box)
		cost(rate, life)
	end
end

---------------------------------------------------------------- DEBRIS (dust off the rim, stone chips)
do
	local rim = carrier(
		"DustRim",
		Vector3.new(CRATER_R * 1.7, 0.2, CRATER_R * 1.7),
		CFrame.new(0, FEET + 0.45, 0)
	)
	local rate, life = 2.2, 1.2
	emitter("RimDust", {
		Texture = TEX.dust,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
		Size = NS({ { 0, 0.95 }, { 1, 1.2 } }),
		Transparency = NS({ { 0, 0.1 }, { 1, 0.35 } }),
		Color = ColorSequence.new(Color3.fromRGB(200, 196, 188), Color3.fromRGB(150, 146, 140)),
		LightInfluence = 0.5,
		Lifetime = NR(life * 0.85, life * 1.15),
		Rate = rate,
		Speed = NR(0.2, 0.5),
		EmissionDirection = Enum.NormalId.Top,
		Drag = 1,
	}, rim)
	cost(rate, life)
	rate, life = 4, 0.9
	emitter("StoneChip", {
		Texture = TEX.pebble,
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NS({ { 0, 0.11 }, { 1, 0.08 } }),
		Transparency = NS({ { 0, 0 }, { 0.85, 0 }, { 1, 1 } }),
		LightInfluence = 0.5,
		Lifetime = NR(life * 0.8, life * 1.2),
		Rate = rate,
		Speed = NR(3.5, 6),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(25, 25),
		Acceleration = Vector3.new(0, -22, 0),
		Rotation = NR(0, 360),
		RotSpeed = NR(-300, 300),
		ZOffset = 0.2,
	}, rim)
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
	"custom:heavenly_restriction (Dummy pack verbatim + crater, cuts, debris)"
)
out:SetAttribute("Tier", "D")
out:SetAttribute("K", 1)
local old = dest:FindFirstChild(KEY)
if old then
	old:Destroy()
end
out.Parent = dest
table.insert(report, ("%s built: live ~%d"):format(KEY, math.floor(live + 0.5)))

---------------------------------------------------------------- re-dress Toji's preview stand
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
			continue -- moved last, once their attachments are in place
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
	local beams = clone:FindFirstChild("Beams")
	if beams then
		for _, b in beams:GetChildren() do
			b.Parent = root
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
	table.insert(report, "no preview stand for Toji (skipped)")
end

return table.concat(report, "\n")
