-- build_shadow_monarch.luau - Studio EDIT mode, rerunnable:
--   python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file tools/studio/auras/build_shadow_monarch.luau
-- Builds ReplicatedStorage.Assets.Auras.ShadowArise: Sung Jinwoo's (shadow_monarch) hero aura,
-- hand-authored with the roblox-vfx skill's authoring route. Every texture is our own
-- (tools/auras/shadow_monarch/make_tex.py, ids in assets/auras/shadow_monarch/ids.json; the lightning
-- arcs reuse CrowGenjutsu's upload of the roblox-vfx library flipbook).
-- Then re-dresses Jinwoo's stand in Workspace.AuraAssignPreview (if it is there) with it.
-- Layout is HeroAura.luau's template format (every CFrame in the hero ROOT's space at rest, R15,
-- feet at y -3, the hero faces -Z):
--   <BodyPart>/<Attachment RS=true>/<emitter>   rides that body part
--   <BodyPart>/Direct/<light>                    parented to the body part itself
--   HumanoidRootPart/<Part RootCF, Spin>/...     welded to the root, turned while live
--
-- The look (Solo Leveling, the Shadow Monarch): void black rimmed in violet, the shadow army rising.
--   DOMAIN    a black void pool under him, ragged violet edge and shadow spikes, turning slowly, and a
--             ring of violet runes turning the other way (SurfaceGui, self-lit)
--   ARISE     his shadow soldiers (a plumed knight, a horned knight, an ant soldier, a hooded mage)
--             rising out of the pool at his sides and behind him, eyes glowing, fading as they rise
--   FLAMES    a mantle of big violet-black tongues drawn behind his body (one silhouette round him),
--             short flames at his feet, two tall columns behind his shoulders
--   STREAKS   thin violet energy lines shooting up round him
--   SMOKE     shadow smoke billowing low and eroding away
--   EYES      his eyes burning blue-violet: a streak flare on each
--   MOTES     violet glints rising from the pool (additive, tiny)
--   ARCS      rare violet lightning round his body (additive, a few frames each)
--   LIGHT     one violet point light (no shadows)
-- A dark aura must not glow: every dark layer is pre-coloured in its texture and drawn with Color
-- white, LightEmission 0, LightInfluence 0. He wears black, so the dark textures carry a wide violet band.

local RS = game:GetService("ReplicatedStorage")

local TEX = {
	flame = "rbxassetid://137307520261450",
	smoke = "rbxassetid://76078867831147",
	knight = "rbxassetid://96757684236493",
	horned = "rbxassetid://121931303615495",
	ant = "rbxassetid://128478186944235",
	mage = "rbxassetid://120236415103541",
	pool = "rbxassetid://93776340718030",
	runes = "rbxassetid://78634721720727",
	eye = "rbxassetid://124207407785051",
	spark = "rbxassetid://103499805716782",
	lightning = "rbxassetid://125518386322481",
	streak = "rbxassetid://104487320138917",
}

local KEY = "ShadowArise"
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

local function dark(t: { [string]: any }): { [string]: any }
	t.LightEmission = 0
	t.LightInfluence = 0
	t.Brightness = 1
	return t
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

local live = 0
local function cost(rate: number, life: number, n: number?)
	live += rate * life * (n or 1)
end

local function flame(name: string, parent: Instance, o: { [string]: any })
	emitter(name, dark({
		Texture = TEX.flame,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.Loop,
		FlipbookFramerate = NR(18, 24),
		FlipbookStartRandom = true,
		Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
		Size = o.Size,
		Transparency = NS({ { 0, 1 }, { 0.12, 0 }, { 0.78, 0.05 }, { 1, 1 } }),
		Lifetime = o.Lifetime,
		Rate = o.Rate,
		Speed = o.Speed,
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(8, 6),
		Acceleration = o.Acceleration or Vector3.new(0, 1.6, 0),
		Drag = 0.8,
		Rotation = NR(-8, 8),
		ZOffset = o.ZOffset or 0,
	}), parent)
	cost(o.Rate, (o.Lifetime.Min + o.Lifetime.Max) / 2)
end

---------------------------------------------------------------- DOMAIN (ground)
do
	local pool = carrier("VoidPool", Vector3.new(6.2, 0.05, 6.2), CFrame.new(0, FEET + 0.03, 0), Vector3.new(0, 0.12, 0))
	decalDisc(pool, TEX.pool, 0, 1)
	local ring = carrier("RuneRing", Vector3.new(7.8, 0.05, 7.8), CFrame.new(0, FEET + 0.05, 0), Vector3.new(0, -0.3, 0))
	decalDisc(ring, TEX.runes, 0, 1.5)
end

---------------------------------------------------------------- ARISE (the shadow army)
do
	-- The army MATERIALISES behind him, at each shoulder: a soldier fades in out of welling shadow smoke,
	-- barely rises, holds, and dissolves (v1 slid up like paper cut-outs). Each soldier type has its own
	-- slightly different rate on each side so they never appear in sync.
	local rates = {
		[1] = { knight = 0.085, horned = 0.07, ant = 0.078, mage = 0.064 },
		[-1] = { knight = 0.067, horned = 0.081, ant = 0.073, mage = 0.088 },
	}
	for _, side in { 1, -1 } do
		local spot = carrier("Arise", Vector3.new(1.0, 0.2, 1.0), CFrame.new(side * 2.9, FEET + 2.4, 1.2)) -- clear of his arms (2.05 hid them)
		for _, who in { "knight", "horned", "ant", "mage" } do
			local rate, life = rates[side][who], 3.7
			emitter("Soldier_" .. who, dark({
				Texture = TEX[who],
				Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
				Size = NS({ { 0, 2.2 }, { 1, 2.5 } }),
				Transparency = NS({ { 0, 1 }, { 0.18, 0.12 }, { 0.78, 0.18 }, { 1, 1 } }),
				Lifetime = NR(3.4, 4.0),
				Rate = rate,
				Speed = NR(0.15, 0.3),
				EmissionDirection = Enum.NormalId.Top,
				SpreadAngle = Vector2.new(0, 0),
				Drag = 0.5,
				ZOffset = -2.0,
			}), spot)
			cost(rate, life)
		end
		-- the shadow they rise out of: smoke welling up from the pool at that spot
		local well = carrier("AriseSmoke", Vector3.new(1.4, 0.2, 1.0), CFrame.new(side * 2.8, FEET + 0.3, 1.1))
		local rate, life = 2.6, 1.6
		emitter("AriseSmoke", dark({
			Texture = TEX.smoke,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
			FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			Orientation = Enum.ParticleOrientation.FacingCamera,
			Size = NS({ { 0, 0.5 }, { 0.5, 0.95, 0.1 }, { 1, 1.1 } }),
			Transparency = NS({ { 0, 0.35 }, { 0.6, 0.45 }, { 1, 1 } }),
			Lifetime = NR(1.0, 1.4),
			Rate = rate,
			Speed = NR(0.3, 0.6), -- hug the floor: at 1-1.6 it climbed to his hips and hung there as dark clouds
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(12, 12),
			Drag = 0.8,
			Rotation = NR(0, 360),
			RotSpeed = NR(-20, 20),
			ZOffset = -1.8,
		}), well)
		cost(rate, life)
	end
end

---------------------------------------------------------------- FLAMES
do
	-- v1 scattered many small flames over his legs and sides: at viewing range each read as a dark
	-- blotch (confetti). Now: a MANTLE of big tongues drawn BEHIND his body, so the aura makes one
	-- silhouette round him, short flames only at his feet, and two tall columns at his shoulders.
	local mantle = carrier("FlameMantle", Vector3.new(4.6, 2.8, 0.3), CFrame.new(0, -0.7, 0.85)) -- wider than his arms
	flame("MantleFlame", mantle, {
		Size = NS({ { 0, 0.9 }, { 0.2, 2.3, 0.25 }, { 0.75, 2.1, 0.2 }, { 1, 0.7 } }),
		Lifetime = NR(1.0, 1.4),
		Rate = 12,
		Speed = NR(1.6, 2.6),
		Acceleration = Vector3.new(0, 1.2, 0),
		ZOffset = -1.6,
	})
	local feet = carrier("FlameFeet", Vector3.new(4.0, 0.2, 3.0), CFrame.new(0, FEET + 0.2, 0))
	flame("FeetFlame", feet, {
		Size = NS({ { 0, 0.45 }, { 0.2, 1.05, 0.15 }, { 0.7, 0.95, 0.1 }, { 1, 0.3 } }),
		Lifetime = NR(0.55, 0.85),
		Rate = 11,
		Speed = NR(0.8, 1.5),
	})
	for _, side in { 1, -1 } do
		local back = carrier("FlameBack", Vector3.new(1.2, 1.0, 0.4), CFrame.new(side * 1.6, 1.3, 0.75))
		flame("BackFlame", back, {
			Size = NS({ { 0, 0.8 }, { 0.2, 2.0, 0.25 }, { 0.75, 1.8, 0.2 }, { 1, 0.6 } }),
			Lifetime = NR(0.95, 1.4),
			Rate = 5,
			Speed = NR(1.4, 2.4),
			Acceleration = Vector3.new(side * 0.5, 1.2, 0),
			ZOffset = -1.2,
		})
	end
end

---------------------------------------------------------------- STREAKS (rising energy lines)
do
	-- thin violet lines shooting up round his body: the anime "powered up" read
	local vol = carrier("StreakVolume", Vector3.new(3.4, 4.4, 2.2), CFrame.new(0, -0.6, 0.1))
	local rate, life = 18, 0.45
	emitter("Streak", {
		Texture = TEX.streak,
		LightEmission = 0.35, -- fully additive violet vanished in daylight (Studio, v2)
		LightInfluence = 0,
		Brightness = 2.5,
		Color = CS({ { 0, rgb(190, 165, 255) }, { 0.5, rgb(125, 70, 255) }, { 1, rgb(80, 40, 210) } }),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Rotation = NR(90), -- VelocityParallel lays the texture's X along the motion: the line is drawn upright
		Size = NS({ { 0, 0.7 }, { 0.4, 1.2 }, { 1, 0.8 } }),
		Transparency = NS({ { 0, 1 }, { 0.2, 0.25 }, { 0.7, 0.35 }, { 1, 1 } }),
		Lifetime = NR(0.35, 0.55),
		Rate = rate,
		Speed = NR(6, 9),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(4, 4),
		Drag = 1.5,
		ZOffset = 0.2,
	}, vol)
	cost(rate, life)
end

---------------------------------------------------------------- SMOKE
do
	local pool = carrier("ShadowSmoke", Vector3.new(4.4, 0.6, 3.6), CFrame.new(0, FEET + 0.5, 0.2))
	local rate, life = 5, 1.8
	emitter("Smoke", dark({
		Texture = TEX.smoke,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NS({ { 0, 0.7 }, { 0.5, 1.3, 0.15 }, { 1, 1.5, 0.15 } }),
		Transparency = NS({ { 0, 0.15 }, { 0.7, 0.2 }, { 1, 0.5 } }),
		Lifetime = NR(1.5, 2.1),
		Rate = rate,
		Speed = NR(0.4, 0.9),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(55, 55),
		Acceleration = Vector3.new(0, 0.5, 0),
		Drag = 1.2,
		Rotation = NR(0, 360),
		RotSpeed = NR(-18, 18),
		ZOffset = -0.4,
	}), pool)
	cost(rate, life)
end

---------------------------------------------------------------- EYES (the Monarch's eyes)
do
	for _, side in { 1, -1 } do
		local a = attach("Head", "EyeFlare", CFrame.new(side * 0.2, 1.56, -0.62))
		local rate, life = 7, 0.35
		emitter("Eye", {
			Texture = TEX.eye,
			LightEmission = 1,
			LightInfluence = 0,
			Brightness = 4,
			Color = CS({ { 0, rgb(165, 150, 255) }, { 0.5, rgb(120, 95, 255) }, { 1, rgb(95, 70, 255) } }),
			Orientation = Enum.ParticleOrientation.FacingCamera,
			LockedToPart = true,
			Size = NS({ { 0, 0.17 }, { 0.5, 0.25 }, { 1, 0.17 } }),
			Transparency = NS({ { 0, 0.3 }, { 0.5, 0 }, { 1, 0.3 } }),
			Lifetime = NR(life),
			Rate = rate,
			Speed = NR(0),
			ZOffset = 0.3,
		}, a)
		cost(rate, life)
	end
end

---------------------------------------------------------------- MOTES (additive, tiny)
do
	local vol = carrier("MoteVolume", Vector3.new(5.0, 0.4, 4.0), CFrame.new(0, FEET + 0.3, 0))
	local rate, life = 10, 1.8
	emitter("Mote", {
		Texture = TEX.spark,
		LightEmission = 1,
		LightInfluence = 0,
		Brightness = 2.4,
		Color = CS({ { 0, rgb(210, 195, 255) }, { 0.4, rgb(150, 100, 255) }, { 1, rgb(80, 40, 200) } }),
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NS({ { 0, 0.05 }, { 0.3, 0.15, 0.05 }, { 1, 0 } }),
		Transparency = NS({ { 0, 0 }, { 0.75, 0.15 }, { 1, 1 } }),
		Lifetime = NR(1.4, 2.2),
		Rate = rate,
		Speed = NR(1.2, 2.6),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(15, 15),
		Acceleration = Vector3.new(0, 0.8, 0),
		Drag = 0.6,
		Rotation = NR(0, 45),
		ZOffset = 0.4,
	}, vol)
	cost(rate, life)
end

---------------------------------------------------------------- ARCS (violet lightning)
do
	local vol = carrier("ArcVolume", Vector3.new(3.2, 3.6, 1.8), CFrame.new(0, 0.1, 0))
	local rate, life = 2.2, 0.17
	emitter("Arc", {
		Texture = TEX.lightning,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.Loop,
		FlipbookFramerate = NR(26, 32),
		FlipbookStartRandom = true,
		LightEmission = 1,
		LightInfluence = 0,
		Brightness = 2.6,
		Color = CS({ { 0, rgb(210, 190, 255) }, { 0.5, rgb(140, 90, 255) }, { 1, rgb(90, 60, 255) } }),
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NS({ { 0, 0.8 }, { 1, 1.1 } }),
		Transparency = NS({ { 0, 0 }, { 0.6, 0.1 }, { 1, 1 } }),
		Lifetime = NR(0.12, 0.22),
		Rate = rate,
		Speed = NR(0),
		Rotation = NR(0, 360),
		ZOffset = 0.5,
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
	l.Color = rgb(130, 80, 255)
	l.Brightness = 1.6
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
out:SetAttribute("Source", "custom:shadow_monarch")
out:SetAttribute("Tier", TIER)
out:SetAttribute("K", 1)
local old = dest:FindFirstChild(KEY)
if old then
	old:Destroy()
end
out.Parent = dest
table.insert(report, ("%s built: live ~%d"):format(KEY, math.floor(live + 0.5)))

---------------------------------------------------------------- re-dress Jinwoo's preview stand
-- (Workspace.AuraAssignPreview, dev only; built by tools/aura_assign.py): a fresh hero from the
-- template, the aura put on the way build_aura_preview.luau's attach does (anchored, no spin)
local yard = workspace:FindFirstChild("AuraAssignPreview")
local slot = yard and yard:FindFirstChild("Heroes") and yard.Heroes:FindFirstChild("Sung Jinwoo")
local oldHero = slot and slot:FindFirstChild("shadow_monarch")
local template = assets.Characters:FindFirstChild("Char_shadow_monarch")
if slot and oldHero and template then
	local pivot = oldHero:GetPivot()
	local hero = template:Clone()
	hero.Name = "shadow_monarch"
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
		if d:IsA("TextLabel") and string.find(d.Text, "uh (Pack4)", 1, true) then
			d.Text = string.gsub(d.Text, "uh %(Pack4%)", "Shadow Arise")
			renamed += 1
		end
	end
	table.insert(report, ("preview stand re-dressed (%d sign line(s) renamed)"):format(renamed))
else
	table.insert(report, "no preview stand for Jinwoo (skipped)")
end

return table.concat(report, "\n")
