-- build_demon_king.luau - Studio EDIT mode, rerunnable:
--   python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file tools/studio/auras/build_demon_king.luau
-- Builds ReplicatedStorage.Assets.Auras.DemonKing: Muzan Kibutsuji's (demon_progenitor) hero aura,
-- hand-authored with the roblox-vfx skill's authoring route. Every texture is our own
-- (tools/auras/demon_king/make_tex.py, ids in assets/auras/demon_king/ids.json; the eye flare reuses
-- ShadowArise's upload). Then re-dresses Muzan's stand in Workspace.AuraAssignPreview (if it is there).
-- Layout is HeroAura.luau's template format (every CFrame in the hero ROOT's space at rest, R15,
-- feet at y -3, the hero faces -Z):
--   <BodyPart>/<Attachment RS=true>/...          rides that body part
--   <BodyPart>/Direct/<light>                    parented to the body part itself
--   HumanoidRootPart/<Part RootCF, Spin>/...     welded to the root, turned while live
--   Beams/<beam>                                 parented to the root; its attachment refs survive the clone
--
-- The owner's brief: NO flame tongues (Itachi's and Jinwoo's auras use them). Muzan's own language:
--   WHIPS     six thorned flesh whips (his biokinesis) arcing out of his back; their tips ride small
--             carriers behind his shoulders that turn about their own axes, so in game the whips writhe
--             behind him and never cross his face (the preview yard does not turn them: frozen arcs)
--   LILIES    blue spider lilies, the flower he hunts, blooming and wilting round the edge of his stand
--             (each on its own rate so they never bloom in unison)
--   BLOOD     a dark glossy blood pool under him with veins crawling over the stand, a heartbeat ring
--             pulsing out of it, droplets rising off it, a low blood mist creeping over the floor
--   EYES      a red glint at each eye
--   LIGHT     one crimson point light (no shadows)

local RS = game:GetService("ReplicatedStorage")

local TEX = {
	pool = "rbxassetid://115142564820686",
	pulse = "rbxassetid://80872042996195",
	whip = "rbxassetid://127838850138517",
	lily = "rbxassetid://74259476796790",
	drop = "rbxassetid://123941896374823",
	mist = "rbxassetid://89331996672714",
	eye = "rbxassetid://124207407785051",
}

local KEY = "DemonKing"
local TIER = "E"
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

---------------------------------------------------------------- BLOOD (ground)
do
	local pool = carrier("BloodPool", Vector3.new(6.6, 0.05, 6.6), CFrame.new(0, FEET + 0.03, 0), Vector3.new(0, 0.05, 0))
	decalDisc(pool, TEX.pool, 0, 1)
	-- the heartbeat: a ring laid flat, growing out from his feet and fading
	local beat = attach("HumanoidRootPart", "Heartbeat", CFrame.new(0, FEET + 0.08, 0))
	local rate, life = 0.9, 1.0
	emitter("Heartbeat", {
		Texture = TEX.pulse,
		LightEmission = 0.15,
		Brightness = 2.2, -- at 1.4 the ring barely showed on his pink stand (play test)
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top,
		Speed = NR(0.01),
		Size = NS({ { 0, 0.6 }, { 0.35, 2.6 }, { 1, 3.4 } }),
		Transparency = NS({ { 0, 0 }, { 0.55, 0.3 }, { 1, 1 } }),
		Lifetime = NR(life),
		Rate = rate,
		ZOffset = 0.05,
	}, beat)
	cost(rate, life)

	-- droplets rising off the pool (a demon's blood does not fall)
	local vol = carrier("DropVolume", Vector3.new(4.2, 0.2, 4.2), CFrame.new(0, FEET + 0.15, 0))
	rate, life = 9, 2.7
	emitter("BloodDrop", {
		Texture = TEX.drop,
		LightEmission = 0.1,
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NS({ { 0, 0.03 }, { 0.15, 0.1, 0.03 }, { 0.85, 0.09, 0.03 }, { 1, 0 } }),
		Transparency = NS({ { 0, 1 }, { 0.1, 0 }, { 0.8, 0 }, { 1, 1 } }),
		Lifetime = NR(2.2, 3.2),
		Rate = rate,
		Speed = NR(0.4, 1.0),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(10, 10),
		Acceleration = Vector3.new(0, 0.6, 0),
		Drag = 0.3,
	}, vol)
	cost(rate, life)

	-- a low blood mist creeping over the floor
	local fog = carrier("MistVolume", Vector3.new(5.0, 0.3, 5.0), CFrame.new(0, FEET + 0.35, 0))
	rate, life = 4, 2.4
	emitter("BloodMist", {
		Texture = TEX.mist,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Orientation = Enum.ParticleOrientation.FacingCamera,
		Size = NS({ { 0, 1.1 }, { 1, 1.9 } }),
		Transparency = NS({ { 0, 0.3 }, { 1, 0.5 } }),
		Lifetime = NR(2.0, 2.8),
		Rate = rate,
		Speed = NR(0.2, 0.45),
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(80, 80),
		Drag = 0.6,
		Rotation = NR(0, 360),
		RotSpeed = NR(-10, 10),
		ZOffset = -0.5,
	}, fog)
	cost(rate, life)
end

---------------------------------------------------------------- WHIPS (biokinesis)
do
	local beams = group("Beams")
	-- per side: where on his back the whip grows, the carrier its tip rides (centre, spin rad/s about
	-- the carrier's own axes) and the tip's offset on that carrier
	local plan = {
		-- v1's whips were 3.4 studs long and tucked behind his back: hair-thin from the front. Now
		-- they arc wide past his shoulders, up to 4.6 studs out (Mythic reach 7)
		-- spread SIDEWAYS (seen from the front a whip running backward looks short): a fan round him
		{ root = Vector3.new(0.45, 0.8, 0.5), c = Vector3.new(3.6, 3.1, 0.9), spin = Vector3.new(0, 0, 1.1), tip = Vector3.new(0, 1.0, 0), w = 1.5 },
		{ root = Vector3.new(0.6, 0.35, 0.5), c = Vector3.new(4.3, 1.0, 0.8), spin = Vector3.new(0, 0, -0.8), tip = Vector3.new(0.6, 0, 0), w = 1.3 },
		{ root = Vector3.new(0.35, -0.2, 0.5), c = Vector3.new(3.6, -1.0, 0.6), spin = Vector3.new(0.95, 0, 0), tip = Vector3.new(0, 0.8, 0), w = 1.15 },
	}
	for _, side in { 1, -1 } do
		for i, p in plan do
			local s = Vector3.new(side, 1, 1)
			local rootPos = p.root * s
			local cPos = p.c * s
			local spin = Vector3.new(p.spin.X, p.spin.Y, p.spin.Z * side) * (if i == 2 then 1.15 else 1)
			local a0 = attach("UpperTorso", "WhipRoot", axisCF(rootPos, Vector3.new(side * 0.9, 1, 0.45)))
			local c = carrier("WhipTip", Vector3.new(0.2, 0.2, 0.2), CFrame.new(cPos), spin)
			local a1 = Instance.new("Attachment")
			a1.Name = "Tip"
			a1.CFrame = axisCF(p.tip * s, Vector3.new(0, -1, 0)) -- the whip comes down onto its tip
			a1.Parent = c
			local b = Instance.new("Beam")
			b.Name = "Whip"
			b.Attachment0 = a0
			b.Attachment1 = a1
			b.Texture = TEX.whip
			b.TextureMode = Enum.TextureMode.Wrap
			b.TextureLength = 2.6
			b.TextureSpeed = 0.45
			b.Width0 = p.w
			b.Width1 = 0.1
			b.CurveSize0 = 2.5
			b.CurveSize1 = 1.6
			b.Segments = 24
			b.FaceCamera = true
			b.LightEmission = 0
			b.LightInfluence = 0
			b.Brightness = 1
			b.Color = CS({ { 0, WHITE }, { 1, WHITE } })
			b.Transparency = NS({ { 0, 0 }, { 0.85, 0 }, { 1, 0.3 } })
			b.ZOffset = -0.2
			b.Parent = beams
		end
	end
end

---------------------------------------------------------------- LILIES (blue spider lilies)
do
	local n = 8
	for i = 1, n do
		local a = (i - 0.5) / n * math.pi * 2
		local r = 2.75 + (i % 2) * 0.35
		local at = attach("HumanoidRootPart", "Lily", CFrame.new(math.cos(a) * r, FEET + 0.82, math.sin(a) * r))
		local rate, life = 0.17 + 0.015 * ((i * 3) % 5), 5.0
		emitter("SpiderLily", {
			Texture = TEX.lily,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
			FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			LightEmission = 0.25,
			Brightness = 1.3,
			Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
			Size = NS({ { 0, 0.85 }, { 1, 0.9 } }),
			Transparency = NS({ { 0, 0 }, { 1, 0 } }),
			Lifetime = NR(4.6, 5.2),
			Rate = rate,
			Speed = NR(0),
		}, at)
		cost(rate, life)
	end
end

---------------------------------------------------------------- EYES
do
	for _, side in { 1, -1 } do
		local a = attach("Head", "EyeGlint", CFrame.new(side * 0.2, 1.66, -0.62))
		local rate, life = 6, 0.35
		emitter("Eye", {
			Texture = TEX.eye,
			LightEmission = 1,
			Brightness = 3,
			Color = CS({ { 0, rgb(255, 120, 120) }, { 0.5, rgb(255, 40, 50) }, { 1, rgb(210, 0, 20) } }),
			Orientation = Enum.ParticleOrientation.FacingCamera,
			LockedToPart = true,
			Size = NS({ { 0, 0.14 }, { 0.5, 0.2 }, { 1, 0.14 } }),
			Transparency = NS({ { 0, 0.3 }, { 0.5, 0 }, { 1, 0.3 } }),
			Lifetime = NR(life),
			Rate = rate,
			Speed = NR(0),
			ZOffset = 0.3,
		}, a)
		cost(rate, life)
	end
end

---------------------------------------------------------------- LIGHT
do
	local d = Instance.new("Folder")
	d.Name = "Direct"
	d.Parent = group("UpperTorso")
	local l = Instance.new("PointLight")
	l.Name = "CrimsonLight"
	l.Color = rgb(255, 30, 50)
	l.Brightness = 1.5
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
out:SetAttribute("Source", "custom:demon_king")
out:SetAttribute("Tier", TIER)
out:SetAttribute("K", 1)
local old = dest:FindFirstChild(KEY)
if old then
	old:Destroy()
end
out.Parent = dest
table.insert(report, ("%s built: live ~%d"):format(KEY, math.floor(live + 0.5)))

---------------------------------------------------------------- re-dress Muzan's preview stand
local yard = workspace:FindFirstChild("AuraAssignPreview")
local slot = yard and yard:FindFirstChild("Heroes") and yard.Heroes:FindFirstChild("Muzan")
local oldHero = slot and slot:FindFirstChild("demon_progenitor")
local template = assets.Characters:FindFirstChild("Char_demon_progenitor")
if slot and oldHero and template then
	local pivot = oldHero:GetPivot()
	local hero = template:Clone()
	hero.Name = "demon_progenitor"
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
		if d:IsA("TextLabel") and string.find(d.Text, "Fiery Ritual of Hallownest", 1, true) then
			d.Text = string.gsub(d.Text, "Fiery Ritual of Hallownest", "Demon King")
			renamed += 1
		end
	end
	table.insert(report, ("preview stand re-dressed (%d sign line(s) renamed)"):format(renamed))
else
	table.insert(report, "no preview stand for Muzan (skipped)")
end

return table.concat(report, "\n")
