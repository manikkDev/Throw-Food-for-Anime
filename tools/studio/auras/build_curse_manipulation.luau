-- build_curse_manipulation.luau - Studio EDIT mode, rerunnable:
--   python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file tools/studio/auras/build_curse_manipulation.luau
-- Builds ReplicatedStorage.Assets.Auras.CurseManipulation: Geto's (curse_manipulator) hero aura, hand-authored
-- with the roblox-vfx skill's authoring route. Every texture is our own
-- (tools/auras/curse_manipulation/make_tex.py, ids in assets/auras/curse_manipulation/ids.json).
-- Then re-dresses Geto's stand in Workspace.AuraAssignPreview (if it is there).
-- Layout is HeroAura.luau's template format (every CFrame in the hero ROOT's space at rest, R15,
-- feet at y -3, the hero faces -Z; see build_demon_king.luau for the full list).
--
-- No flame tongues (the owner's brief). Geto's Curse Manipulation:
--   ORBS      black cursed-spirit spheres with a single eye that looks about and blinks, circling him
--             on a turning ring (each fades in and out; the preview yard does not turn them)
--   ABSORB    little cursed spirits (one great eye, a toothy grin, a cluster of eyes) drifting in from
--             all round him and shrinking into him as he takes them in
--   UZUMAKI   a spiral vortex of compressed curses turning on the ground, eyes along its arms
--   LIGHT     one violet point light (no shadows)

local RS = game:GetService("ReplicatedStorage")

local TEX = {
	orb = "rbxassetid://134625413767463",
	spiritEye = "rbxassetid://103816314965723",
	spiritGrin = "rbxassetid://109125910621576",
	spiritMany = "rbxassetid://129915740015684",
	uzumaki = "rbxassetid://78505726776316",
}

local KEY = "CurseManipulation"
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

---------------------------------------------------------------- UZUMAKI (ground)
do
	local disc = carrier("Uzumaki", Vector3.new(6.6, 0.05, 6.6), CFrame.new(0, FEET + 0.03, 0), Vector3.new(0, 0.6, 0))
	decalDisc(disc, TEX.uzumaki, 0, 1.1)
end

---------------------------------------------------------------- ORBS (cursed-spirit spheres circling him)
do
	-- one orb per point on a turning ring, each fading in and out (interval 1/Rate > Lifetime)
	local ring = carrier("OrbRing", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 0.6, 0), Vector3.new(0, 0.9, 0))
	local points = {
		CFrame.new(2.7, 0.4, 0),
		CFrame.new(-1.4, 1.5, 2.3),
		CFrame.new(-1.6, -0.6, -2.2),
		CFrame.new(1.3, 2.3, -2.2),
		CFrame.new(-2.6, 2.6, -0.6),
	}
	for i, cf in points do
		local a = Instance.new("Attachment")
		a.Name = "Orb" .. i
		a.CFrame = cf
		a.Parent = ring
		local rate, life = 0.3, 3.0
		emitter("CurseOrb", {
			Texture = TEX.orb,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
			FlipbookMode = Enum.ParticleFlipbookMode.Loop,
			FlipbookFramerate = NR(8, 11),
			FlipbookStartRandom = true,
			LightEmission = 0.05,
			Orientation = Enum.ParticleOrientation.FacingCamera,
			LockedToPart = true,
			Size = NS({ { 0, 0.3 }, { 0.15, 0.75 }, { 0.85, 0.75 }, { 1, 0.45 } }), -- 0.48 read as dots at viewing distance
			Transparency = NS({ { 0, 1 }, { 0.15, 0 }, { 0.85, 0 }, { 1, 1 } }),
			Lifetime = NR(2.8, 3.0),
			Rate = rate,
			Speed = NR(0),
		}, a)
		cost(rate, life)
	end
end

---------------------------------------------------------------- ABSORB (spirits drifting into him)
do
	-- emitted on a sphere round him and moving INWARD, shrinking to nothing as they reach him
	local shell = carrier("AbsorbShell", Vector3.new(7.4, 5.6, 7.4), CFrame.new(0, 0.4, 0))
	for _, tex in { TEX.spiritEye, TEX.spiritGrin, TEX.spiritMany } do
		local rate, life = 1.1, 2.0
		emitter("CurseSpirit", {
			Texture = tex,
			Shape = Enum.ParticleEmitterShape.Sphere,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
			LightEmission = 0,
			Orientation = Enum.ParticleOrientation.FacingCamera,
			Size = NS({ { 0, 0.3 }, { 0.15, 0.85 }, { 0.7, 0.7 }, { 1, 0 } }), -- 0.55 was lost on his dark robe
			Transparency = NS({ { 0, 1 }, { 0.15, 0 }, { 0.85, 0.05 }, { 1, 1 } }),
			Lifetime = NR(1.7, 2.3),
			Rate = rate,
			Speed = NR(1.3, 1.8),
			Drag = 0.2,
			Rotation = NR(-15, 15),
			RotSpeed = NR(-20, 20),
		}, shell)
		cost(rate, life)
	end
end

---------------------------------------------------------------- LIGHT
do
	local d = Instance.new("Folder")
	d.Name = "Direct"
	d.Parent = group("UpperTorso")
	local l = Instance.new("PointLight")
	l.Name = "VioletLight"
	l.Color = Color3.fromRGB(150, 90, 230)
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
out:SetAttribute("Source", "custom:curse_manipulation")
out:SetAttribute("Tier", TIER)
out:SetAttribute("K", 1)
local old = dest:FindFirstChild(KEY)
if old then
	old:Destroy()
end
out.Parent = dest
table.insert(report, ("%s built: live ~%d"):format(KEY, math.floor(live + 0.5)))

---------------------------------------------------------------- re-dress Geto's preview stand
local yard = workspace:FindFirstChild("AuraAssignPreview")
local slot = yard and yard:FindFirstChild("Heroes") and yard.Heroes:FindFirstChild("Geto")
local oldHero = slot and slot:FindFirstChild("curse_manipulator")
local template = assets.Characters:FindFirstChild("Char_curse_manipulator")
if slot and oldHero and template then
	local pivot = oldHero:GetPivot()
	local hero = template:Clone()
	hero.Name = "curse_manipulator"
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
		if d:IsA("TextLabel") and string.find(d.Text, "s (Pack2)", 1, true) then
			d.Text = string.gsub(d.Text, "s %(Pack2%)", "Curse Manipulation")
			renamed += 1
		end
	end
	table.insert(report, ("preview stand re-dressed (%d sign line(s) renamed)"):format(renamed))
else
	table.insert(report, "no preview stand for Geto (skipped)")
end

return table.concat(report, "\n")
