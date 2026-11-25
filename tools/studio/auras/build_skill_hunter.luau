-- build_skill_hunter.luau - Studio EDIT mode, rerunnable:
--   python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file tools/studio/auras/build_skill_hunter.luau
-- Builds ReplicatedStorage.Assets.Auras.SkillHunter: Chrollo Lucilfer's (spider_thief_boss, Legendary) hero aura,
-- hand-authored with the roblox-vfx skill's authoring route. Every texture is our own
-- (tools/auras/skill_hunter/make_tex.py, ids in assets/auras/skill_hunter/ids.json). Then re-dresses his stand in
-- Workspace.AuraAssignPreview (if it is there). HeroAura.luau's template format (root space at rest, R15, feet at
-- y -3, the hero faces -Z, +X is his right).
--
-- The look (Hunter x Hunter: the Phantom Troupe's leader and his Nen ability, Skill Hunter):
--   BANDIT'S SECRET his grimoire floating open before his right side (a self-lit billboard: dark leather, gold
--                   corners, the crimson handprint, a page of glyphs), a cold glow and Nen motes lifting off it
--                   (v1-v2 also turned a page over it every second: the owner wanted it gone)
--   STOLEN PAGES    torn pages of the abilities he took (Sun and Moon, Black Voice's antenna, the order stamp), each
--                   with the handprint, drifting and tumbling round him
--   WEB             the Spiders: a silver web behind him with TWELVE spokes, one per Troupe member; pulses of cold
--                   Nen light run out along every spoke (beams: they move on the preview yard too), dew winks on
--                   and off, a slow glow breathes behind it; it also turns very slowly in game
--   SIGIL           the Troupe's twelve-legged spider facing front (his way), four inverted crosses (his coat),
--                   幻影旅団 and 盗賊の極意; it holds still
--   GYO             his Nen as thin cold aura lines rising off his silhouette (born inside him, drawn behind), a low
--                   charcoal mist at his feet
--   LIGHT           one cold white point light (no shadows)

local RS = game:GetService("ReplicatedStorage")

local TEX = {
	book = "rbxassetid://99054445713172",
	pageSun = "rbxassetid://72510544481214",
	pageMoon = "rbxassetid://107253878491488",
	pageAntenna = "rbxassetid://113390111241678",
	pageStamp = "rbxassetid://91501460961424",
	web = "rbxassetid://121427219896196",
	pulse = "rbxassetid://125705105947257",
	sigil = "rbxassetid://111795244504040",
	nen = "rbxassetid://116790700329244",
	mist = "rbxassetid://114329365726206",
	mote = "rbxassetid://109449294139290",
	glow = "rbxassetid://90004998745593",
}

local KEY = "SkillHunter"
local TIER = "D"
local FEET = -3.0
local WHITE = Color3.new(1, 1, 1)
local BOOK = Vector3.new(1.5, 0.4, -1.1) -- held up before his right side, chest height (root space; at the hand it sat by his hip)

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

-- an invisible carrier part welded to `bodyPart` (root space at rest)
local function carrier(
	name: string,
	size: Vector3,
	cf: CFrame,
	spin: Vector3?,
	bodyPart: string?
): Part
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
	p.Parent = group(bodyPart or "HumanoidRootPart")
	return p
end

local function surface(
	p: Part,
	face: Enum.NormalId,
	image: string,
	transparency: number,
	brightness: number,
	pps: number
)
	local g = Instance.new("SurfaceGui")
	g.Name = "Gui" .. face.Name
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = pps
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

---------------------------------------------------------------- SIGIL (the Troupe's seal on the ground)
do
	-- the spider faces FRONT, the way he faces (the image's top lies toward the part's +Z on a Top face, so the
	-- disc is turned half round); no spin, so it keeps facing front (v1 turned, and its spider faced his back)
	local disc = carrier(
		"Seal",
		Vector3.new(6.6, 0.05, 6.6),
		CFrame.new(0, FEET + 0.04, 0) * CFrame.Angles(0, math.pi, 0)
	)
	surface(disc, Enum.NormalId.Top, TEX.sigil, 0.02, 1.1, 64)
end

---------------------------------------------------------------- WEB (the Spiders: twelve spokes, one per member)
-- a silver web on a plane behind him, both faces; it turns very slowly in game (static on the preview yard)
do
	local w = carrier(
		"Web",
		Vector3.new(10.6, 10.6, 0.05),
		CFrame.new(0, 1.2, 1.15),
		Vector3.new(0, 0, 0.05)
	)
	surface(w, Enum.NormalId.Front, TEX.web, 0, 1.5, 48)
	surface(w, Enum.NormalId.Back, TEX.web, 0, 1.5, 48)
	-- movement (v1 was still on the preview yard: spinning parts only turn in game, beams and particles move
	-- everywhere): pulses of cold Nen light running out along each of the twelve spokes, each at its own speed
	local R0, R1 = 1.6, 5.0 -- the hub's edge and the spokes' ends (the image: r 0.14 and 0.48 of 10.6 studs)
	for i = 0, 11 do
		local a = -math.pi / 2 + i * math.pi / 6 + 0.04 * math.sin(i * 2.3) -- the image's spoke angle (y down)
		-- a Front-face image reads with its right toward the part's -X and its down toward -Y
		local dir = Vector3.new(-math.cos(a), -math.sin(a), 0)
		local a0 = Instance.new("Attachment")
		a0.Name = "Spoke" .. i .. "Hub"
		a0.Position = dir * R0 + Vector3.new(0, 0, -0.04)
		a0.Parent = w
		local a1 = Instance.new("Attachment")
		a1.Name = "Spoke" .. i .. "Tip"
		a1.Position = dir * R1 + Vector3.new(0, 0, -0.04)
		a1.Parent = w
		local bm = Instance.new("Beam")
		bm.Name = "Pulse" .. i
		bm.Attachment0 = a0
		bm.Attachment1 = a1
		bm.Segments = 2
		bm.FaceCamera = true
		bm.Width0 = 0.2
		bm.Width1 = 0.14
		bm.Texture = TEX.pulse
		bm.TextureMode = Enum.TextureMode.Wrap
		bm.TextureLength = 2.4 + 0.3 * (i % 3)
		bm.TextureSpeed = -(0.32 + 0.07 * ((i * 5) % 6)) -- (negative runs hub -> tip)
		bm.LightEmission = 1
		bm.LightInfluence = 0
		bm.Brightness = 2
		bm.Color = ColorSequence.new(Color3.fromRGB(210, 232, 255))
		bm.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.6),
			NumberSequenceKeypoint.new(0.2, 0.05),
			NumberSequenceKeypoint.new(0.85, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		})
		bm.Parent = w
	end
	-- dew glinting: small sparks winking on and off across the web
	local glints = carrier(
		"WebGlints",
		Vector3.new(8.6, 0.1, 8.6),
		CFrame.new(0, 1.2, 1.05) * CFrame.Angles(math.pi / 2, 0, 0)
	)
	local rate, life = 7, 0.9
	emitter("Dew", {
		Texture = TEX.mote,
		LightEmission = 1,
		Brightness = 2.6,
		Color = CS({ { 0, rgb(255, 255, 255) }, { 1, rgb(190, 220, 255) } }),
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NS({ { 0, 0 }, { 0.35, 0.34 }, { 1, 0 } }),
		Transparency = NS({ { 0, 0 }, { 1, 0 } }),
		Lifetime = NR(0.7, 1.1),
		Rate = rate,
		Speed = NR(0),
		ZOffset = 0.2,
	}, glints)
	cost(rate, life)
	-- a slow breathing glow behind the web (two overlapping, so it swells and ebbs without a pop)
	local breath = attach("HumanoidRootPart", "WebBreath", CFrame.new(0, 1.2, 1.4))
	rate, life = 0.6, 3.4
	emitter("WebBreath", {
		Texture = TEX.glow,
		LightEmission = 0.5,
		Brightness = 1.4,
		Color = CS({ { 0, rgb(150, 175, 240) }, { 1, rgb(110, 130, 220) } }),
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NS({ { 0, 8 }, { 0.5, 10.5 }, { 1, 8 } }),
		Transparency = NS({ { 0, 1 }, { 0.5, 0.72 }, { 1, 1 } }),
		Lifetime = NR(life),
		Rate = rate,
		Speed = NR(0),
		ZOffset = -4,
	}, breath)
	cost(rate, life)
end

---------------------------------------------------------------- BANDIT'S SECRET (the grimoire at his right hand)
do
	local a = attach("RightHand", "Grimoire", CFrame.new(BOOK))
	local g = Instance.new("BillboardGui")
	g.Name = "Book"
	g.Size = UDim2.fromScale(2.3, 2.3)
	g.LightInfluence = 0
	g.Brightness = 1.05
	g.AlwaysOnTop = false
	g.MaxDistance = 160
	g.ResetOnSpawn = false
	g.Parent = a
	local img = Instance.new("ImageLabel")
	img.Name = "Image"
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = TEX.book
	img.Parent = g
	-- a cold light off the open pages
	local ga = attach("RightHand", "GrimoireGlow", CFrame.new(BOOK + Vector3.new(0, 0.15, 0.1)))
	local rate, life = 2, 1.3
	emitter("PageGlow", {
		Texture = TEX.glow,
		LightEmission = 1,
		Brightness = 1.8,
		Color = CS({ { 0, rgb(220, 236, 255) }, { 1, rgb(150, 190, 255) } }),
		Orientation = Enum.ParticleOrientation.FacingCamera,
		LockedToPart = true,
		Size = NS({ { 0, 1.6 }, { 0.5, 2.4 }, { 1, 1.6 } }),
		Transparency = NS({ { 0, 1 }, { 0.4, 0.55 }, { 1, 1 } }),
		Lifetime = NR(life),
		Rate = rate,
		Speed = NR(0),
		ZOffset = -0.3,
	}, ga)
	cost(rate, life)
	-- Nen motes lifting off the pages
	rate, life = 9, 1.4
	emitter("PageMotes", {
		Texture = TEX.mote,
		LightEmission = 1,
		Brightness = 2,
		Color = CS({ { 0, rgb(255, 255, 255) }, { 1, rgb(160, 200, 255) } }),
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NS({ { 0, 0.04 }, { 0.3, 0.14 }, { 1, 0 } }),
		Transparency = NS({ { 0, 1 }, { 0.15, 0 }, { 1, 0.3 } }),
		Lifetime = NR(1.0, 1.8),
		Rate = rate,
		Speed = NR(0.6, 1.3),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(30, 30),
		Acceleration = Vector3.new(0, 0.4, 0),
		ZOffset = 0.3,
	}, ga)
	cost(rate, life)
end

---------------------------------------------------------------- STOLEN PAGES (the abilities he took)
-- torn pages drifting and tumbling round him, fading in and out
do
	-- (v1: one volume round him at 0.78 studs, 0.75/s each: pages crowded his face and chest) two side volumes,
	-- clear of his body, smaller and fewer
	local vols = {
		carrier("PagesL", Vector3.new(1.8, 4.6, 3.6), CFrame.new(-3.0, 0.8, 0.3)),
		carrier("PagesR", Vector3.new(1.8, 4.6, 3.6), CFrame.new(3.2, 0.8, 0.3)),
	}
	for i, tex in { TEX.pageSun, TEX.pageMoon, TEX.pageAntenna, TEX.pageStamp } do
		local vol = vols[(i % 2) + 1]
		local rate, life = 0.45, 4.6
		emitter("Page" .. i, {
			Texture = tex,
			LightEmission = 0.1,
			Brightness = 1.15,
			Orientation = Enum.ParticleOrientation.FacingCamera,
			Size = NS({ { 0, 0.45 }, { 0.15, 0.62, 0.06 }, { 1, 0.62, 0.06 } }),
			Transparency = NS({ { 0, 1 }, { 0.22, 0 }, { 0.72, 0.05 }, { 1, 1 } }),
			Lifetime = NR(4.0, 5.2),
			Rate = rate,
			Speed = NR(0.15, 0.35),
			EmissionDirection = Enum.NormalId.Top,
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, 0.05, 0),
			Rotation = NR(-25, 25),
			RotSpeed = NR(-14, 14),
			ZOffset = 0.4,
		}, vol)
		cost(rate, life)
	end
end

---------------------------------------------------------------- GYO (his Nen, seen as a thin outline)
do
	local body = carrier("Gyo", Vector3.new(2.8, 4.8, 0.4), CFrame.new(0, -0.6, 0.15))
	local rate, life = 11, 1.3
	emitter("Gyo", {
		Texture = TEX.nen,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.Loop,
		FlipbookFramerate = NR(14, 18),
		FlipbookStartRandom = true,
		LightEmission = 0.6,
		Brightness = 1.6,
		Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
		Size = NS({ { 0, 1.6 }, { 0.5, 2.3 }, { 1, 2.0 } }),
		Transparency = NS({ { 0, 1 }, { 0.2, 0.2 }, { 0.75, 0.3 }, { 1, 1 } }),
		Lifetime = NR(1.0, 1.6),
		Rate = rate,
		Speed = NR(0.5, 1.0),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(25, 6),
		ZOffset = -1.3,
	}, body)
	cost(rate, life)
	local feet = carrier("Mist", Vector3.new(4.0, 0.3, 3.0), CFrame.new(0, FEET + 0.3, 0.2))
	rate, life = 3, 2.6
	emitter("Mist", {
		Texture = TEX.mist,
		Brightness = 1,
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NS({ { 0, 1.4 }, { 1, 2.8 } }),
		Transparency = NS({ { 0, 1 }, { 0.3, 0.45 }, { 1, 1 } }),
		Lifetime = NR(2.2, 3.0),
		Rate = rate,
		Speed = NR(0.2, 0.5),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(70, 70),
		Rotation = NR(0, 360),
		RotSpeed = NR(-12, 12),
		ZOffset = -0.3,
	}, feet)
	cost(rate, life)
end

---------------------------------------------------------------- LIGHT
do
	local d = Instance.new("Folder")
	d.Name = "Direct"
	d.Parent = group("UpperTorso")
	local l = Instance.new("PointLight")
	l.Name = "NenLight"
	l.Color = rgb(200, 222, 255)
	l.Brightness = 1.2
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
out:SetAttribute("Source", "custom:skill_hunter")
out:SetAttribute("Tier", TIER)
out:SetAttribute("K", 1)
local old = dest:FindFirstChild(KEY)
if old then
	old:Destroy()
end
out.Parent = dest
table.insert(report, ("%s built: live ~%d"):format(KEY, math.floor(live + 0.5)))

---------------------------------------------------------------- re-dress Chrollo's preview stand
local yard = workspace:FindFirstChild("AuraAssignPreview")
local slot = yard and yard:FindFirstChild("Heroes") and yard.Heroes:FindFirstChild("Chrollo")
local oldHero = slot and slot:FindFirstChild("spider_thief_boss")
local template = assets.Characters:FindFirstChild("Char_spider_thief_boss")
if slot and oldHero and template then
	local pivot = oldHero:GetPivot()
	local hero = template:Clone()
	hero.Name = "spider_thief_boss"
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
	local renamed = 0
	for _, d in slot:GetDescendants() do
		if d:IsA("TextLabel") and string.find(d.Text, "uh (Pack4)", 1, true) then
			d.Text = string.gsub(d.Text, "uh %(Pack4%)", "Skill Hunter")
			renamed += 1
		end
	end
	-- the pack aura's raw pieces (clock, void cubes) were put on the stand by the yard builder: clear them
	local cleared = 0
	for _, c in slot:GetChildren() do
		if c ~= hero and c.Name ~= "Stand" and not c:IsA("BillboardGui") then
			local hasFx = c:FindFirstChildWhichIsA("ParticleEmitter", true)
				or c:FindFirstChildWhichIsA("Beam", true)
			if hasFx then
				c:Destroy()
				cleared += 1
			end
		end
	end
	table.insert(
		report,
		("preview stand re-dressed (%d sign line(s) renamed, %d old fx cleared)"):format(
			renamed,
			cleared
		)
	)
else
	table.insert(report, "no preview stand for Chrollo (skipped)")
end

return table.concat(report, "\n")
