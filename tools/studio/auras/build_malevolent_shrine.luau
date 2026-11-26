-- build_malevolent_shrine.luau - Studio EDIT mode, rerunnable:
--   python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file tools/studio/auras/build_malevolent_shrine.luau
-- Builds ReplicatedStorage.Assets.Auras.MalevolentShrine: Ryomen Sukuna's (curse_king, Mythic) hero aura.
--
-- His body keeps the KingOfCurses aura he wore (his red cursed energy), COPIED VERBATIM from
-- ReplicatedStorage.Assets.Auras.KingOfCurses into this new key, so the other heroes who wear KingOfCurses are not
-- touched. It already spends the whole Mythic budget (320), so what is added is cheap, and it is his technique and
-- his domain, drawn the way the anime shows them:
--   DISMANTLE  volleys of razor-thin, perfectly straight slashes cutting the air round him in quick succession
--              (mostly parallel, one crossing), a white flash where each lands: beside him and above his head
--   CLEAVE     now and then a heavy X cut that opens a black void line in the air, white-edged, glowing red
--   FLOOR      Dismantle cutting across the floor of his domain
--   DOMAIN     the Malevolent Shrine's floor under him (SurfaceGui): a blood pool, a ring of fangs, carved slash
--              scars, a band of kanji (Fukuma Mizushi) with skulls
--   (no shrine standing behind him: the owner had it removed, 2026-11-25)
-- All pre-coloured (white-hot cores, crimson fringes, black hairlines) so they read on the 13:12 sky and at night.
-- Textures: tools/auras/malevolent_shrine/make_tex.py (ids in assets/auras/malevolent_shrine/ids.json).
-- Layout is HeroAura.luau's template format (every CFrame in the hero ROOT's space at rest, R15, feet at y -3,
-- the hero faces -Z). ParticleEmitter Size is HALF the drawn width.

local RS = game:GetService("ReplicatedStorage")

local TEX = {
	dismantle = "rbxassetid://82634146698419",
	cleave = "rbxassetid://123044460521821",
	seal = "rbxassetid://89124299068911",
}

local KEY = "MalevolentShrine"
local HERO = "curse_king"
local SLOT = "Sukuna"
local ORIGINAL = "KingOfCurses" -- ReplicatedStorage.Assets.Auras.KingOfCurses (the game's own template)
local OLD_NAME = "KingOfCurses"
local NEW_NAME = "Malevolent Shrine"
local FEET = -3.0
local SEAL_R = 3.5
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
-- cloned as ONE piece first, so any Beams keep pointing at the copied attachments
local original = RS.Assets.Auras:FindFirstChild(ORIGINAL)
assert(original, "ReplicatedStorage.Assets.Auras." .. ORIGINAL .. " is missing")
local copy = original:Clone()
for _, g in copy:GetChildren() do
	for _, piece in g:GetChildren() do
		piece.Parent = group(g.Name)
	end
end
copy:Destroy()
live += (original:GetAttribute("Live") or 0) :: number

---------------------------------------------------------------- DOMAIN (the shrine's floor)
do
	local p = carrier(
		"DomainFloor",
		Vector3.new(SEAL_R * 2, 0.05, SEAL_R * 2),
		CFrame.new(0, FEET + 0.04, 0),
		Vector3.new(0, -0.05, 0)
	)
	local g = Instance.new("SurfaceGui")
	g.Name = "Domain"
	g.Face = Enum.NormalId.Top
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 64
	g.LightInfluence = 0
	g.Brightness = 1.2
	g.AlwaysOnTop = false
	g.ClipsDescendants = true
	g.Parent = p
	local img = Instance.new("ImageLabel")
	img.Name = "Image"
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = TEX.seal
	img.Parent = g
end

---------------------------------------------------------------- DISMANTLE (razor volleys round him)
do
	local spots = {
		{ "DismantleLeft", Vector3.new(1.6, 3.4, 2.2), CFrame.new(-2.5, -0.2, 0.2) },
		{ "DismantleRight", Vector3.new(1.6, 3.4, 2.2), CFrame.new(2.5, -0.2, 0.2) },
		{ "DismantleHigh", Vector3.new(3.6, 1.0, 1.6), CFrame.new(0, 2.9, 0.6) },
	}
	for _, sp in spots do
		local box = carrier(sp[1], sp[2], sp[3])
		local rate, life = 1.3, 0.6
		emitter("Dismantle", {
			Texture = TEX.dismantle,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
			FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			Orientation = Enum.ParticleOrientation.FacingCamera,
			Size = NS({ { 0, 2.5 }, { 1, 2.7 } }),
			Transparency = NS({ { 0, 0 }, { 1, 0 } }),
			Lifetime = NR(life),
			Rate = rate,
			Speed = NR(0),
			Rotation = NR(0, 360),
			LightEmission = 0.45,
			Brightness = 1.5,
			ZOffset = 0.4,
		}, box)
		cost(rate, life)
	end
end

---------------------------------------------------------------- CLEAVE (a heavy X that opens the air)
do
	local box = carrier("CleaveVolume", Vector3.new(5.6, 3.6, 2.0), CFrame.new(0, 0.2, 0.4))
	local rate, life = 0.45, 0.75
	emitter("Cleave", {
		Texture = TEX.cleave,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NS({ { 0, 2.8 }, { 1, 3.0 } }),
		Transparency = NS({ { 0, 0 }, { 1, 0 } }),
		Lifetime = NR(life),
		Rate = rate,
		Speed = NR(0),
		Rotation = NR(-35, 35),
		LightEmission = 0.3,
		Brightness = 1.3,
		ZOffset = -0.3,
	}, box)
	cost(rate, life)
end

---------------------------------------------------------------- FLOOR (Dismantle cutting the ground)
do
	local floor = carrier(
		"FloorCuts",
		Vector3.new(SEAL_R * 1.4, 0.05, SEAL_R * 1.4),
		CFrame.new(0, FEET + 0.12, 0)
	)
	local rate, life = 1.5, 0.6
	emitter("FloorDismantle", {
		Texture = TEX.dismantle,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular, -- flat
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(0, 0),
		Speed = NR(0.001),
		Size = NS({ { 0, 2.2 }, { 1, 2.4 } }),
		Transparency = NS({ { 0, 0 }, { 1, 0 } }),
		Lifetime = NR(life),
		Rate = rate,
		Rotation = NR(0, 360),
		LightEmission = 0.4,
		Brightness = 1.4,
		ZOffset = 0.1,
	}, floor)
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
	"custom:malevolent_shrine (KingOfCurses verbatim + Dismantle, Cleave, domain floor)"
)
out:SetAttribute("Tier", "E")
out:SetAttribute("K", 1)
local old = dest:FindFirstChild(KEY)
if old then
	old:Destroy()
end
out.Parent = dest
table.insert(report, ("%s built: live ~%d"):format(KEY, math.floor(live + 0.5)))

---------------------------------------------------------------- re-dress Sukuna's preview stand
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
	table.insert(report, "no preview stand for Sukuna (skipped)")
end

return table.concat(report, "\n")
