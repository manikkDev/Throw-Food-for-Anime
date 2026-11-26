-- build_anti_magic.luau - Studio EDIT mode, rerunnable:
--   python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file tools/studio/auras/build_anti_magic.luau
-- Builds ReplicatedStorage.Assets.Auras.AntiMagic: Liebe's (devil_knight, Legendary) hero aura.
--
-- His body keeps the pack aura he wears, COPIED VERBATIM from its preview conversion
-- (ServerStorage.AuraPreview.Templates.P8 = Pack9 "one winged angel": a black wing mesh with black mist and
-- feathers): the single black wing is how anti-magic first shows in Black Clover (the owner's rule: an aura
-- he already likes is kept exactly and built around). This file adds his own imagery round it:
--   SEAL     his grimoire on the floor: a black five-leaf clover with silver edges and blood-red veins, a red
--            devil's eye at its heart, white anti-magic crackle running round a black band; PRE-COLOURED on a
--            SurfaceGui, turning slowly
--   CLOVERS  five black five-leaf clovers gliding round him on a slow orbit, turning smoothly, fading in and
--            out; single leaves come away and float up, turning
--   SLASHES  black anti-magic sword cuts (crescents with an ash edge) flashing beside him
--   (no flames, no flame-shaped wisps, no flipping pages: the owner's calls, 2026-11-25)
--   CRACKLE  black anti-magic lightning flickering round his legs and crawling over the seal
--   SHARDS   black anti-magic flakes drifting up
--   LIGHT    a dim blood-red light at his feet
-- A DARK aura must not glow: every layer here is pre-coloured and drawn with Color white, LightEmission 0,
-- LightInfluence 0. Textures: tools/auras/anti_magic/make_tex.py (ids in assets/auras/anti_magic/ids.json).
-- Layout is HeroAura.luau's template format (every CFrame in the hero ROOT's space at rest, R15, feet at
-- y -3, the hero faces -Z). ParticleEmitter Size is HALF the drawn width.

local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local TEX = {
	seal = "rbxassetid://91403139311975",
	clover = "rbxassetid://97579242397575",
	leaf = "rbxassetid://117291273636929",
	slash = "rbxassetid://139319218395249",
	crackle = "rbxassetid://130814795547391",
	shard = "rbxassetid://116324620818374",
}

local KEY = "AntiMagic"
local HERO = "devil_knight"
local SLOT = "Liebe"
local ORIGINAL = "P8" -- ServerStorage.AuraPreview.Templates.P8 = Pack9 "one winged angel", converted
local OLD_NAME = "one winged angel"
local NEW_NAME = "Anti-Magic"
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

-- a dark, pre-coloured layer: what is painted is what shows
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

---------------------------------------------------------------- SEAL (his grimoire, turning)
do
	local seal = carrier(
		"GrimoireSeal",
		Vector3.new(SEAL_R * 2, 0.05, SEAL_R * 2),
		CFrame.new(0, FEET + 0.04, 0),
		Vector3.new(0, -0.18, 0)
	)
	local g = Instance.new("SurfaceGui")
	g.Name = "Seal"
	g.Face = Enum.NormalId.Top
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 64
	g.LightInfluence = 0
	g.Brightness = 1.25
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

---------------------------------------------------------------- CLOVERS (five five-leaf clovers gliding round him)
do
	-- five black five-leaf clovers, one per leaf of his grimoire, gliding round him on a slow orbit, each
	-- turning smoothly (Rotation, no flipbook) and fading in and out softly; now and then a single leaf
	-- comes away and floats up, turning. (v1 had flame-shaped miasma here, v2 flipping grimoire pages; the
	-- owner asked for the five-leaf clover, moving smoothly, 2026-11-25)
	local orbit = carrier(
		"CloverOrbit",
		Vector3.new(0.2, 0.2, 0.2),
		CFrame.new(0, -0.5, 0),
		Vector3.new(0, 0.45, 0)
	)
	local N = 5
	for i = 1, N do
		local a = (i - 1) / N * 2 * math.pi
		local att = Instance.new("Attachment")
		att.Name = "Clover" .. i
		att.CFrame = CFrame.new(math.cos(a) * 2.9, math.sin(a * 2) * 0.45, math.sin(a) * 2.9)
		att.Parent = orbit
		-- one clover at a time per point: it fades in, turns, fades out, and the next one rises in its place
		local rate, life = 1 / 4.2, 4.2
		emitter("Clover", {
			Texture = TEX.clover,
			Orientation = Enum.ParticleOrientation.FacingCamera,
			LockedToPart = true,
			Size = NS({ { 0, 0.5 }, { 0.25, 0.64 }, { 0.75, 0.66 }, { 1, 0.56 } }),
			Transparency = NS({ { 0, 1 }, { 0.22, 0 }, { 0.78, 0 }, { 1, 1 } }),
			Lifetime = NR(life),
			Rate = rate,
			Speed = NR(0),
			Rotation = NR(0, 360),
			RotSpeed = NR(18, 26),
			ZOffset = 0.2,
		}, att)
		cost(rate, life)
		rate, life = 0.5, 2.6
		emitter("CloverLeaf", {
			Texture = TEX.leaf,
			Orientation = Enum.ParticleOrientation.FacingCamera,
			Size = NS({ { 0, 0 }, { 0.15, 0.2 }, { 0.85, 0.18 }, { 1, 0 } }),
			Transparency = NS({ { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } }),
			Lifetime = NR(life * 0.8, life * 1.2),
			Rate = rate,
			Speed = NR(0.3, 0.7),
			SpreadAngle = Vector2.new(50, 50),
			EmissionDirection = Enum.NormalId.Top,
			Acceleration = Vector3.new(0, 0.3, 0),
			Drag = 0.8,
			Rotation = NR(0, 360),
			RotSpeed = NR(-50, 50),
			ZOffset = 0.15,
		}, att)
		cost(rate, life)
	end
end

---------------------------------------------------------------- SLASHES (black anti-magic sword cuts)
do
	-- the cuts of the anti-magic swords he lends Asta as the Devil Knight: black crescents with an ash
	-- edge flashing in the air beside him, never in front of him
	for _, side in { 1, -1 } do
		local box =
			carrier("SlashBox", Vector3.new(1.4, 3.2, 1.6), CFrame.new(side * 2.6, -0.4, 0.3))
		local rate, life = 0.9, 0.45
		emitter("BlackSlash", {
			Texture = TEX.slash,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
			FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			Orientation = Enum.ParticleOrientation.FacingCamera,
			Size = NS({ { 0, 2.1 }, { 1, 2.4 } }),
			Transparency = NS({ { 0, 0 }, { 1, 0 } }),
			Lifetime = NR(life),
			Rate = rate,
			Speed = NR(0),
			Rotation = NR(-75, 75),
			ZOffset = -0.4,
		}, box)
		cost(rate, life)
	end
end

---------------------------------------------------------------- CRACKLE (black anti-magic lightning)
do
	-- beside him, never in front: black lightning vanished against his black body and legs (v1)
	for _, side in { 1, -1 } do
		local legs =
			carrier("CrackleVolume", Vector3.new(1.4, 3.2, 1.8), CFrame.new(side * 2.3, -1.2, 0.2))
		local rate, life = 1.6, 0.2
		emitter("BlackCrackle", {
			Texture = TEX.crackle,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
			FlipbookMode = Enum.ParticleFlipbookMode.Loop,
			FlipbookFramerate = NR(26, 32),
			FlipbookStartRandom = true,
			Orientation = Enum.ParticleOrientation.FacingCamera,
			Size = NS({ { 0, 0.9 }, { 1, 1.2 } }),
			Transparency = NS({ { 0, 0 }, { 0.7, 0.1 }, { 1, 1 } }),
			Lifetime = NR(life * 0.7, life * 1.2),
			Rate = rate,
			Speed = NR(0),
			Rotation = NR(0, 360),
			ZOffset = 0.3,
		}, legs)
		cost(rate, life)
	end
	-- lightning crawling over the seal itself (flat on the floor)
	local floor = carrier(
		"CrackleFloor",
		Vector3.new(SEAL_R * 1.5, 0.05, SEAL_R * 1.5),
		CFrame.new(0, FEET + 0.12, 0)
	)
	local rate, life = 3.2, 0.3
	emitter("FloorCrackle", {
		Texture = TEX.crackle,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.Loop,
		FlipbookFramerate = NR(24, 30),
		FlipbookStartRandom = true,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular, -- flat
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(0, 0),
		Speed = NR(0.001),
		Size = NS({ { 0, 1.6 }, { 1, 1.9 } }),
		Transparency = NS({ { 0, 0 }, { 0.7, 0.15 }, { 1, 1 } }),
		Lifetime = NR(life * 0.7, life * 1.2),
		Rate = rate,
		Rotation = NR(0, 360),
		ZOffset = 0.1,
	}, floor)
	cost(rate, life)
end

---------------------------------------------------------------- SHARDS (anti-magic flakes drifting up)
do
	local vol = carrier(
		"ShardVolume",
		Vector3.new(SEAL_R * 1.7, 0.3, SEAL_R * 1.7),
		CFrame.new(0, FEET + 0.3, 0)
	)
	local rate, life = 6, 2.0
	emitter("AntiShard", {
		Texture = TEX.shard,
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NS({ { 0, 0 }, { 0.15, 0.16 }, { 0.85, 0.13 }, { 1, 0 } }),
		Transparency = NS({ { 0, 0 }, { 0.8, 0.1 }, { 1, 1 } }),
		Lifetime = NR(life * 0.7, life * 1.3),
		Rate = rate,
		Speed = NR(0.8, 2.0),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(20, 20),
		Acceleration = Vector3.new(0, 0.4, 0),
		Drag = 0.6,
		Rotation = NR(0, 360),
		RotSpeed = NR(-160, 160),
		ZOffset = 0.2,
	}, vol)
	cost(rate, life)
end

---------------------------------------------------------------- LIGHT (dim blood red, from below)
do
	local a = Instance.new("Attachment")
	a.Name = "UnderLight"
	a.CFrame = CFrame.new(0, FEET + 0.6, -0.6)
	a:SetAttribute("RS", true)
	a.Parent = group("HumanoidRootPart")
	local l = Instance.new("PointLight")
	l.Name = "BloodLight"
	l.Color = Color3.fromRGB(190, 20, 30)
	l.Brightness = 1.2
	l.Range = 8
	l.Shadows = false
	l.Parent = a
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
out:SetAttribute("Source", "custom:anti_magic (one winged angel pack verbatim + grimoire seal)")
out:SetAttribute("Tier", "D")
out:SetAttribute("K", 1)
local old = dest:FindFirstChild(KEY)
if old then
	old:Destroy()
end
out.Parent = dest
table.insert(report, ("%s built: live ~%d"):format(KEY, math.floor(live + 0.5)))

---------------------------------------------------------------- re-dress Liebe's preview stand
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
	table.insert(report, "no preview stand for Liebe (skipped)")
end

return table.concat(report, "\n")
