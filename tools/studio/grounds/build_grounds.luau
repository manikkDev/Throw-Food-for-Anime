-- build_grounds.luau - Studio EDIT mode, rerunnable. (Plan 13 phase D.)
-- Builds the set pieces of the training grounds into ReplicatedStorage.Assets.Grounds:
-- (SIX grounds share the 19 gear tiers, 3 / 3 / 3 / 3 / 3 / 4: tools/economy/econ_v3.py GEAR_GROUND)
--   Ground_post_T1..T3      Striking Post   (left court):  Wooden Post, Banded Post, Iron Post
--   Ground_falls_T4..T6     Waterfall Focus (right court): Mountain Falls, Shrine Falls, Dragon Falls
--   Ground_boulder_T7..T9   Boulder Breaker (left court):  Granite Boulder, Obsidian Boulder, Magma Boulder
--   Ground_peak_T10..T12    Thunder Peak    (right court): Storm Peak, Thunder Peak, Heaven's Peak
--   Ground_gravity_T13..T15 Gravity Chamber (left court):  Gravity Room, Gravity Core, Singularity
--   Ground_orb_T16..T19     Spirit Orb      (right court): Spirit Orb, Sun Orb, Star Orb, Galaxy Orb
--   Show_<id>_T<tier>     a small display model of each tier, for dialogs and reward cards
--
-- RUN IT THROUGH  python tools/studio/grounds/run_build.py  (it puts the effect texture ids in
-- front of this file as the table TEX; run by hand, the water and the fires have no textures).
--
-- A set piece is built round its court's centre: origin on the court floor, +Z toward the lane
-- (the front), the court 18 wide (x) and 22 deep (z). Its pivot is the origin, so the server
-- stands it with PivotTo(anchor.CFrame). What the game reads from it (PlotService,
-- TrainingService, GroundController):
--   Stand        invisible part: the trainee's feet and facing
--   Sign         invisible part over the notice board's panel: SurfaceGui Board (Title, Level, Next)
--   Target       Model: the thing that is struck / the centrepiece that pops in on an upgrade
--   Fx.Strike / Fx.Seat / Fx.Pool   invisible parts: where effects are played
--   Water.Left / Water.Right        the two halves of the falls (Beams with attribute Flow)
--   Fx.Floor / Fx.Hum / Floaters    the gravity deck's floor spot, its machine, what drifts up
--   Fx.Orb / Fx.Field / Target.Core + Shell   the spirit orb: where it rests, the charge, its two balls
--   attributes Energy (the tier's colour), OrbRest / OrbFull / OrbAwake (diameters)
--   emitters with attribute When = "awake" / "calm"
--   L2, L3       Models: what gear levels II and III add (the server removes them below that level)
--   Lock         Model: chains and a board (the server removes it when the ground is open)
-- The meshes are the generated pieces of the judging row (tools/studio/grounds/ground_lab.luau);
-- they are copied to ServerStorage.StoreAssets.Grounds (never delete) and read from there.
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local TEX: { [string]: number } = (_G :: any).GROUND_TEX or {}
-- (a clone: `require` is cached for the whole Studio session and would not see a config edit)
local Config = require(RS.Shared.Config.GameConfig:Clone())

local function tex(key: string): string
	local id = TEX[key]
	return if id then "rbxassetid://" .. tostring(id) else ""
end

-- ------------------------------------------------------------------ the pieces
local store = SS:FindFirstChild("StoreAssets")
local kept = store:FindFirstChild("Grounds")
if not kept then
	kept = Instance.new("Folder")
	kept.Name = "Grounds"
	kept.Parent = store
end
local lab = workspace:FindFirstChild("GroundLab")
if lab then
	for _, piece in lab:GetChildren() do
		if piece:IsA("Model") and piece:GetAttribute("TrueSize") then
			local old = kept:FindFirstChild(piece.Name)
			if old then
				old:Destroy()
			end
			local copy = piece:Clone()
			local tag = copy:FindFirstChild("Tag")
			if tag then
				tag:Destroy()
			end
			copy:PivotTo(CFrame.new())
			copy.Parent = kept
		end
	end
end

local RGB = Color3.fromRGB
local HEX = Color3.fromHex
local V = Vector3.new
local M = Enum.Material

local SHADE: { [string]: Color3 } = {
	river_rocks = Color3.fromRGB(150, 156, 162),
	stone_lantern = Color3.fromRGB(205, 205, 200),
	-- (its cradle came out cream, not gold)
	gravity_singularity = Color3.fromRGB(255, 205, 140),
}

local function flat(v: Vector3): Vector3
	return V(v.X, 0, v.Z).Unit
end

-- A part. `cf` is its CENTRE.
local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, solid: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = solid == true
	p.CanQuery = solid == true
	p.CanTouch = false
	p.Parent = parent
	return p
end

-- A box standing on the floor point `at` (its base centre), turned `yaw` degrees.
local function box(parent: Instance, name: string, size: Vector3, at: Vector3, color: Color3, material: Enum.Material?, solid: boolean?, yaw: number?): Part
	return part(parent, name, size, CFrame.new(at + V(0, size.Y / 2, 0)) * CFrame.Angles(0, math.rad(yaw or 0), 0), color, material, solid)
end

local function cyl(parent: Instance, name: string, length: number, diameter: number, cf: CFrame, color: Color3, material: Enum.Material?, solid: boolean?): Part
	-- a cylinder's axis is its X: `cf` looks along the axis with its X
	local p = part(parent, name, V(length, diameter, diameter), cf, color, material, solid)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- an upright cylinder standing on `at`
local function post(parent: Instance, name: string, height: number, diameter: number, at: Vector3, color: Color3, material: Enum.Material?, solid: boolean?): Part
	return cyl(parent, name, height, diameter, CFrame.new(at + V(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, material, solid)
end

local function ghost(parent: Instance, name: string, size: Vector3, cf: CFrame): Part
	local p = part(parent, name, size, cf, RGB(255, 255, 255), M.SmoothPlastic, false)
	p.Transparency = 1
	p.CastShadow = false
	return p
end

-- A generated piece standing on the floor point `at`, its front (-Z as generated) turned to `front`.
-- `size`: a number scales it, a Vector3 sets its box (the generator does not keep proportions).
local function mesh(parent: Instance, key: string, name: string, size: number | Vector3, at: Vector3, front: Vector3?, solid: boolean?): MeshPart
	local template = kept:FindFirstChild(key)
	assert(template, "no generated piece " .. key .. " (run ground_lab.luau)")
	local source = template:FindFirstChildWhichIsA("MeshPart") :: MeshPart
	local m = source:Clone()
	m.Name = name
	m.Size = if typeof(size) == "number" then source.Size * size else size
	local dir = if front then flat(front) else V(0, 0, -1)
	local centre = at + V(0, m.Size.Y / 2, 0)
	m.CFrame = CFrame.lookAt(centre, centre + dir)
	m.Anchored = true
	m.CanCollide = solid == true
	m.CanQuery = solid == true
	m.CanTouch = false
	-- some pieces came out paler than asked for: the part's colour multiplies its texture
	local shade = SHADE[key]
	if shade then
		m.Color = shade
	end
	m.Parent = parent
	return m
end

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Text on a face of a part.
local function words(p: BasePart, face: Enum.NormalId, text: string, color: Color3, px: number?, stroke: Color3?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Words"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = px or 60
	gui.LightInfluence = 0.2
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
	if stroke then
		local s = Instance.new("UIStroke")
		s.Color = stroke
		s.Thickness = 3
		s.Parent = label
	end
	return label
end

local function emitter(parent: Instance, name: string, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.LightInfluence = 0
	for key, value in props do
		if key == "When" then
			e:SetAttribute("When", value)
		else
			(e :: any)[key] = value
		end
	end
	e.Parent = parent
	return e
end

local function NS(...: { number }): NumberSequence
	local keys = {}
	for _, k in { ... } do
		table.insert(keys, NumberSequenceKeypoint.new(k[1], k[2]))
	end
	return NumberSequence.new(keys)
end

local function CS(...: any): ColorSequence
	local list = { ... }
	if #list == 1 then
		return ColorSequence.new(list[1])
	end
	local keys = {}
	for i, c in list do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#list - 1), c))
	end
	return ColorSequence.new(keys)
end

local function glow(parent: Instance, color: Color3, range: number, brightness: number, when: string?): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	if when then
		l:SetAttribute("When", when)
		l.Enabled = when ~= "awake"
	end
	l.Parent = parent
	return l
end

-- A rope hanging between two points (a sagging run of short cylinders).
local function rope(parent: Instance, name: string, a: Vector3, b: Vector3, sag: number, thick: number, color: Color3, segments: number)
	local last = a
	for i = 1, segments do
		local u = i / segments
		local p = a:Lerp(b, u) - V(0, sag * 4 * u * (1 - u), 0)
		local mid = (last + p) / 2
		local run = p - last
		-- the cylinder's X along the run
		local cf = CFrame.lookAt(mid, p) * CFrame.Angles(0, math.rad(90), 0)
		cyl(parent, name, run.Magnitude + thick * 0.4, thick, cf, color, M.Fabric)
		last = p
	end
end

-- white zigzag paper streamers (shide) hung under a rope point
local function shide(parent: Instance, at: Vector3, facing: Vector3)
	local right = facing:Cross(V(0, 1, 0)).Unit
	for i = 0, 2 do
		local c = at - V(0, 0.35 + i * 0.42, 0) + right * (if i % 2 == 0 then 0.12 else -0.12)
		local p = part(parent, "Shide", V(0.5, 0.45, 0.06), CFrame.lookAt(c, c + facing) * CFrame.Angles(0, 0, math.rad(if i % 2 == 0 then 14 else -14)), RGB(250, 250, 245), M.SmoothPlastic)
		p.CastShadow = false
	end
end

-- A banner on a pole (nobori): `text` reads down the cloth on both faces.
local function banner(parent: Instance, at: Vector3, facing: Vector3, height: number, cloth: Color3, ink: Color3, text: string)
	post(parent, "BannerPole", height, 0.28, at, RGB(60, 40, 28), M.Wood)
	local right = facing:Cross(V(0, 1, 0)).Unit
	local arm = at + V(0, height - 0.5, 0) + right * 0.95
	part(parent, "BannerArm", V(2.1, 0.2, 0.2), CFrame.lookAt(arm, arm + facing), RGB(60, 40, 28), M.Wood)
	local centre = at + V(0, height - 0.7 - (height * 0.62) / 2, 0) + right * 1.05
	local flag = part(parent, "BannerCloth", V(1.7, height * 0.62, 0.08), CFrame.lookAt(centre, centre + facing), cloth, M.Fabric)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local label = words(flag, face, text, ink, 50)
		label.TextScaled = true
		label.Font = Enum.Font.SourceSansBold
	end
end

-- The notice board: the generated board with the game's text over its panel. Returns the Sign part.
local function noticeBoard(parent: Instance, at: Vector3, facing: Vector3): Part
	local m = mesh(parent, "sign_board", "NoticeBoard", 1.3, at, facing, true)
	-- the dark panel sits in the middle of the board, between the posts, under the roof
	local w, h = m.Size.X * 0.60, m.Size.Y * 0.31
	local centre = m.CFrame * CFrame.new(0, m.Size.Y * 0.06, -m.Size.Z * 0.16)
	local sign = ghost(parent, "Sign", V(w, h, 0.1), centre)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Board"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 120
	gui.LightInfluence = 0
	gui.Parent = sign
	local function line(name: string, y: number, height: number, color: Color3, text: string)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.Position = UDim2.fromScale(0.5, y)
		label.Size = UDim2.fromScale(0.94, height)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = color
		label.Text = text
		label.Parent = gui
		local s = Instance.new("UIStroke")
		s.Color = RGB(30, 18, 10)
		s.Thickness = 3
		s.Parent = label
	end
	line("Title", 0.04, 0.38, HEX("FFD23F"), "STRIKING POST")
	line("Level", 0.44, 0.26, HEX("FFFFFF"), "Wooden Post I   +1 / rep")
	line("Next", 0.72, 0.24, HEX("FFE9A8"), "NEXT: Wooden Post II  330 yen")
	return sign
end

-- The chains and board of a ground that is not open yet. `side`: the court's inner side (+1 / -1 x).
local function lock(parent: Instance): Model
	local m = model(parent, "Lock")
	local dark = RGB(40, 40, 46)
	for _, x in { -7.6, 7.6 } do
		post(m, "LockPost", 3.6, 0.7, V(x, 0, 6.6), RGB(170, 36, 36), M.SmoothPlastic, true)
		post(m, "LockCap", 0.4, 0.95, V(x, 3.6, 6.6), dark, M.Metal)
	end
	rope(m, "Chain", V(-7.6, 3.2, 6.6), V(-2.2, 2.9, 6.6), 0.5, 0.26, dark, 6)
	rope(m, "Chain", V(2.2, 2.9, 6.6), V(7.6, 3.2, 6.6), 0.5, 0.26, dark, 6)
	rope(m, "Chain", V(-7.6, 1.6, 6.6), V(7.6, 1.6, 6.6), 0.7, 0.26, dark, 10)
	local plank = part(m, "LockBoard", V(4.8, 2.6, 0.3), CFrame.new(0, 2.9, 6.6), RGB(74, 46, 28), M.Wood)
	part(m, "LockTrim", V(5.1, 2.9, 0.2), CFrame.new(0, 2.9, 6.56), RGB(170, 36, 36), M.SmoothPlastic)
	local face = ghost(m, "LockFace", V(4.6, 2.4, 0.05), CFrame.new(0, 2.9, 6.78))
	local gui = Instance.new("SurfaceGui")
	gui.Name = "LockGui"
	gui.Face = Enum.NormalId.Back -- the +Z face: toward the lane, where the player walks up
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 100
	gui.LightInfluence = 0
	gui.Parent = face
	local function line(name: string, y: number, height: number, color: Color3, text: string)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.Position = UDim2.fromScale(0.5, y)
		label.Size = UDim2.fromScale(0.92, height)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = color
		label.Text = text
		label.Parent = gui
		local s = Instance.new("UIStroke")
		s.Color = RGB(30, 18, 10)
		s.Thickness = 3
		s.Parent = label
	end
	line("LockTitle", 0.06, 0.42, HEX("FF5A4E"), "LOCKED")
	line("LockText", 0.5, 0.44, HEX("FFD23F"), "REBIRTH 1")
	local _ = plank
	return m
end

-- A fire in a bowl: flames, embers and a light on `top`.
local function fire(parent: Instance, top: Vector3, size: number)
	local p = ghost(parent, "Fire", V(0.9 * size, 0.2, 0.9 * size), CFrame.new(top))
	emitter(p, "Flames", {
		Texture = tex("flame"),
		Rate = 9,
		Lifetime = NumberRange.new(0.5, 0.75),
		Speed = NumberRange.new(2.5, 4.5),
		SpreadAngle = Vector2.new(10, 10),
		EmissionDirection = Enum.NormalId.Top,
		Size = NS({ 0, 1.3 * size }, { 0.4, 2.1 * size }, { 1, 0.3 * size }),
		Transparency = NS({ 0, 0.1 }, { 0.7, 0.2 }, { 1, 1 }),
		Color = CS(HEX("FFF3A0"), HEX("FFA62B"), HEX("E0431A")),
		LightEmission = 0.35,
		Rotation = NumberRange.new(-12, 12),
		ZOffset = 0.3,
	})
	emitter(p, "Embers", {
		Texture = tex("ember"),
		Rate = 6,
		Lifetime = NumberRange.new(0.8, 1.3),
		Speed = NumberRange.new(3, 6),
		SpreadAngle = Vector2.new(25, 25),
		EmissionDirection = Enum.NormalId.Top,
		Size = NS({ 0, 0 }, { 0.2, 0.35 * size }, { 1, 0 }),
		Color = CS(HEX("FFE38A"), HEX("FF7A1A")),
		LightEmission = 0.6,
		Drag = 0.5,
	})
	glow(p, HEX("FF9A3D"), 14, 1.4)
end

-- ------------------------------------------------------------------ a template
local function begin(name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	local root = ghost(m, "Root", V(1, 0.2, 1), CFrame.new(0, 0.1, 0))
	m.PrimaryPart = root
	model(m, "L2")
	model(m, "L3")
	local fx = Instance.new("Folder")
	fx.Name = "Fx"
	fx.Parent = m
	lock(m)
	return m
end

local folder = RS.Assets:FindFirstChild("Grounds")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Grounds"
	folder.Parent = RS.Assets
end

-- every run builds every template: whatever an older tier numbering left behind goes
for _, old in folder:GetChildren() do
	if string.match(old.Name, "^Ground_") or string.match(old.Name, "^Show_") then
		old:Destroy()
	end
end

local out = {}
local function finish(m: Model)
	local old = folder:FindFirstChild(m.Name)
	if old then
		old:Destroy()
	end
	-- the pivot is the court's centre on the floor, whatever the bounding box does
	m.WorldPivot = CFrame.new()
	local count = 0
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			count += 1
		end
	end
	m.Parent = folder
	table.insert(out, string.format("%s: %d parts", m.Name, count))
end

-- ================================================================== STRIKING POST
-- Left court: the walkway (the open side) is +X. The trainee faces -Z, toward the post and the
-- dojo wall behind it; the training camera looks from +X, in profile.
local DECK = 0.32 -- the top of the training deck

local POSTS = {
	[1] = { key = "post1", scale = 0.98, deck = HEX("7A5433"), trim = HEX("5B3D25") },
	[2] = { key = "post2", scale = 0.82, deck = HEX("6B4A2E"), trim = HEX("7C8088") },
	[3] = { key = "post3", scale = 1.06, deck = HEX("4A2F22"), trim = HEX("B0282A") },
}

local function dojoWall(m: Instance, tier: number)
	local z = -9.7
	if tier == 1 then
		-- a rustic plank fence
		for i = -4, 4 do
			local h = 4.6 + (if i % 2 == 0 then 0.35 else 0)
			box(m, "FencePlank", V(1.5, h, 0.3), V(i * 1.6, 0, z), if i % 2 == 0 then HEX("8A5A32") else HEX("7D4F2B"), M.WoodPlanks, true)
		end
		box(m, "FenceRail", V(15, 0.4, 0.5), V(0, 3.4, z + 0.1), HEX("5B3D25"), M.Wood)
		box(m, "FenceRail", V(15, 0.4, 0.5), V(0, 1.2, z + 0.1), HEX("5B3D25"), M.Wood)
		return 4.6
	end
	-- a plastered dojo wall with a timber frame and a tiled cap
	local frame = if tier == 3 then HEX("9E2A2B") else HEX("4A3222")
	local tile = if tier == 3 then HEX("2B2F3A") else HEX("3E4350")
	box(m, "WallPlaster", V(15, 5.6, 0.5), V(0, 0, z), HEX("EFE7D6"), M.SmoothPlastic, true)
	box(m, "WallFoot", V(15.4, 0.9, 0.8), V(0, 0, z), HEX("8E8A84"), M.Slate)
	for _, x in { -7.3, -3.65, 0, 3.65, 7.3 } do
		box(m, "WallPost", V(0.55, 5.6, 0.7), V(x, 0, z), frame, M.Wood)
	end
	box(m, "WallBeam", V(15.4, 0.5, 0.8), V(0, 5.3, z), frame, M.Wood)
	box(m, "WallBeam", V(15.4, 0.35, 0.7), V(0, 2.6, z), frame, M.Wood)
	-- the cap: two rows of tile sloping away from a ridge
	for _, side in { -1, 1 } do
		local w = Instance.new("WedgePart")
		w.Name = "RoofTile"
		w.Anchored = true
		w.Size = V(16, 0.9, 1.5)
		w.CFrame = CFrame.new(0, 6.25, z + side * 0.75) * CFrame.Angles(0, if side == 1 then math.pi else 0, 0)
		w.Color = tile
		w.Material = M.Slate
		w.CanCollide = false
		w.Parent = m
	end
	box(m, "RoofRidge", V(16.2, 0.35, 0.45), V(0, 6.5, z), if tier == 3 then HEX("E3B341") else HEX("2B2F3A"), if tier == 3 then M.Metal else M.Slate)
	for x = -7.5, 7.5, 1.5 do
		box(m, "RoofRib", V(0.22, 0.2, 3.1), V(x, 6.05, z), tile:Lerp(RGB(0, 0, 0), 0.25), M.Slate)
	end
	if tier == 3 then
		for _, x in { -8.1, 8.1 } do
			box(m, "RidgeEnd", V(0.5, 0.9, 0.6), V(x, 6.4, z), HEX("E3B341"), M.Metal)
		end
	end
	return 5.6
end

local function buildPost(tier: number)
	local spec = POSTS[tier]
	local m = begin("Ground_post_T" .. tier)
	local L2, L3, fx = m.L2, m.L3, m.Fx

	-- the training deck
	box(m, "Deck", V(13, DECK, 12.5), V(0, 0, -2.2), spec.deck, M.WoodPlanks, true)
	for _, e in { { V(13.5, DECK + 0.08, 0.5), V(0, 0, 4.05) }, { V(13.5, DECK + 0.08, 0.5), V(0, 0, -8.45) }, { V(0.5, DECK + 0.08, 12.5), V(-6.5, 0, -2.2) }, { V(0.5, DECK + 0.08, 12.5), V(6.5, 0, -2.2) } } do
		box(m, "DeckEdge", e[1], e[2], spec.trim, if tier == 2 then M.Slate else M.Wood)
	end
	if tier == 3 then
		for _, c in { V(-6.5, 0, 4.05), V(6.5, 0, 4.05), V(-6.5, 0, -8.45), V(6.5, 0, -8.45) } do
			box(m, "DeckCorner", V(0.8, DECK + 0.2, 0.8), c, HEX("E3B341"), M.Metal)
		end
	end
	local wallTop = dojoWall(m, tier)

	-- the scroll on the wall: POWER
	local scroll = part(m, "Scroll", V(2.2, 3.3, 0.12), CFrame.new(0, 3.0, -9.38), HEX("F6EFD9"), M.Fabric)
	part(m, "ScrollRod", V(2.6, 0.22, 0.22), CFrame.new(0, 4.7, -9.38), HEX("3A2618"), M.Wood)
	part(m, "ScrollRod", V(2.6, 0.22, 0.22), CFrame.new(0, 1.3, -9.38), HEX("3A2618"), M.Wood)
	local kanji = words(scroll, Enum.NormalId.Back, "力", if tier == 3 then HEX("B0282A") else RGB(24, 20, 20), 60)
	kanji.Font = Enum.Font.SourceSansBold

	-- the post
	local target = model(m, "Target")
	local postMesh = mesh(target, spec.key, "Post", spec.scale, V(0, DECK, -5), V(0, 0, 1), true)
	target.PrimaryPart = postMesh
	target.WorldPivot = CFrame.new(0, DECK, -5)
	local face = -5 + postMesh.Size.Z / 2
	-- where the fist lands (chest height) and where the trainee stands (the clip's contact distance)
	ghost(fx, "Strike", V(0.4, 0.4, 0.4), CFrame.new(0, DECK + 3.5, face + 0.12))
	local standAt = V(0, DECK, face + Config.Training.Grounds[1].Contact)
	ghost(m, "Stand", V(2, 0.1, 2), CFrame.lookAt(standAt, standAt - V(0, 0, 1)))

	-- the outer side (-X): a weapon rack against the fence
	mesh(m, "weapon_rack", "WeaponRack", 1.05, V(-5.2, DECK, -7.7), V(0.35, 0, 1), true)

	-- the notice board, at the open front corner
	noticeBoard(m, V(6.6, 0, 8.3), V(0.55, 0, 0.83))

	mesh(m, "straw_dummy", "StrawDummy", 1.5, V(-4.9, DECK, -1.2), V(1, 0, 0.15), true)

	-- LEVEL II: the yard fills up: a war drum, two banners, a sacred rope on the wall
	mesh(L2, "taiko", "Taiko", 0.95, V(-6.9, 0, 6.9), V(0.7, 0, -0.5), true)
	banner(L2, V(-7.8, 0, -8.6), V(0, 0, 1), 9.2, HEX("C8302C"), HEX("FFF4D6"), "拳\n魂")
	-- (not at the inner back corner: the training camera stands there, and the cloth filled the shot)
	banner(L2, V(-7.9, 0, 2.4), V(1, 0, 0), 8.4, HEX("F6EFD9"), HEX("C8302C"), "不\n屈")
	local ropeY = wallTop - 0.9
	rope(L2, "SacredRope", V(-6.2, ropeY, -9.2), V(6.2, ropeY, -9.2), 0.7, 0.34, HEX("D8B56A"), 12)
	for _, x in { -4.2, -1.8, 1.8, 4.2 } do
		shide(L2, V(x, ropeY - 0.7 * 4 * ((x + 6.2) / 12.4) * (1 - (x + 6.2) / 12.4) - 0.1, -9.1), V(0, 0, 1))
	end

	-- LEVEL III: fire and gold: two braziers behind the post, a crest ring let into the deck
	-- (wide apart and against the wall: nearer the post, the inner one filled the training camera's
	-- foreground)
	for _, x in { -4.4, 4.4 } do
		local b = mesh(L3, "brazier", "Brazier", 1.3, V(x, DECK, -7.9), V(0, 0, 1), true)
		fire(L3, V(x, DECK + b.Size.Y * 0.74, -7.9), 1.1)
	end
	local ring = model(L3, "CrestRing")
	local centreZ = standAt.Z - 0.4
	for _, row in { { 3.3, 0.14, 32 }, { 2.95, 0.06, 28 } } do
		local radius, thick, count = row[1], row[2], row[3]
		for i = 0, count - 1 do
			local a = i / count * math.pi * 2
			local c = V(math.cos(a) * radius, DECK + 0.02, centreZ + math.sin(a) * radius)
			local length = 2 * math.pi * radius / count + 0.03
			local seg = part(ring, "CrestSeg", V(length, 0.05, thick), CFrame.new(c) * CFrame.Angles(0, -a + math.pi / 2, 0), HEX("FFC83D"), M.Neon)
			seg.CastShadow = false
		end
	end
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local c = V(math.cos(a) * 3.3, DECK + 0.03, centreZ + math.sin(a) * 3.3)
		part(ring, "CrestStud", V(0.42, 0.07, 0.42), CFrame.new(c) * CFrame.Angles(0, math.pi / 4, 0), HEX("FFE9A8"), M.Neon).CastShadow = false
	end
	finish(m)

	-- the display model: the post on a round of deck
	local show = Instance.new("Model")
	show.Name = "Show_post_T" .. tier
	local base = cyl(show, "Base", 0.4, 5.2, CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)), spec.deck, M.WoodPlanks)
	mesh(show, spec.key, "Post", spec.scale, V(0, 0.4, 0), V(0, 0, 1))
	show.PrimaryPart = base
	local old = folder:FindFirstChild(show.Name)
	if old then
		old:Destroy()
	end
	show.Parent = folder
end

-- ================================================================== WATERFALL FOCUS
-- Right court: the walkway is -X. The trainee sits on a stone in the pool, back to the falls,
-- facing +Z (the lane); the training camera looks from the front.
local SURFACE = 0.5 -- the pool's water level

local function waterBeam(parent: Instance, name: string, a0: Attachment, a1: Attachment, texture: string, width: number, length: number, speed: number, alpha: number, z: number): Beam
	local b = Instance.new("Beam")
	b.Name = name
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Texture = tex(texture)
	b.TextureMode = Enum.TextureMode.Wrap
	b.TextureLength = length
	b.TextureSpeed = speed
	b.Width0 = width
	b.Width1 = width * 1.06
	b.CurveSize0 = 1.6
	b.CurveSize1 = 1.2
	b.Segments = 14
	b.FaceCamera = false
	-- (lit by the world, hardly emissive: at max graphics an emissive sheet bloomed to plain white
	-- and lost its streaks)
	b.LightEmission = 0.05
	b.LightInfluence = 0.8
	b.Brightness = 1
	b.Color = ColorSequence.new(RGB(255, 255, 255))
	b.Transparency = NS({ 0, alpha }, { 0.9, alpha }, { 1, math.min(1, alpha + 0.3) })
	b.ZOffset = z
	b:SetAttribute("Flow", true)
	b.Parent = parent
	return b
end

-- One half of the falls: pours out over the lip at `top` and comes down to `bottom`.
local function fallsHalf(water: Instance, name: string, top: Vector3, bottom: Vector3, width: number)
	local half = model(water, name)
	local lip = ghost(half, "Lip", V(0.2, 0.2, 0.2), CFrame.new(top))
	local foot = ghost(half, "Foot", V(0.2, 0.2, 0.2), CFrame.new(bottom))
	half.PrimaryPart = lip
	-- the beam leaves an attachment along its +X and its width lies along its Y (seen in Studio:
	-- with the width on Z the sheets stood edge-on): out over the lip (+Z of the world), then
	-- straight down into the pool, the sheet facing the court
	-- (parented first: WorldCFrame on an attachment without a parent is taken as its local CFrame)
	local a0 = Instance.new("Attachment")
	a0.Name = "Pour"
	a0.Parent = lip
	a0.WorldCFrame = CFrame.fromMatrix(top, V(0, 0, 1), V(1, 0, 0), V(0, 1, 0))
	local a1 = Instance.new("Attachment")
	a1.Name = "Land"
	a1.Parent = foot
	a1.WorldCFrame = CFrame.fromMatrix(bottom, V(0, -1, 0), V(1, 0, 0), V(0, 0, 1))
	waterBeam(lip, "Sheet", a0, a1, "water_sheet", width, 11, 1.5, 0.04, 0)
	waterBeam(lip, "Foam", a0, a1, "water_foam", width * 0.94, 8, 2.5, 0.12, 0.08)
	-- where it lands: spray, a ring of splash, mist
	local splash = ghost(half, "Splash", V(width, 0.3, 0.8), CFrame.new(bottom + V(0, 0.1, 0.2)))
	emitter(splash, "Spray", {
		When = "calm",
		Texture = tex("dot"),
		Rate = 26,
		Lifetime = NumberRange.new(0.35, 0.6),
		Speed = NumberRange.new(5, 10),
		SpreadAngle = Vector2.new(38, 38),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = V(0, -32, 0),
		Size = NS({ 0, 0.32 }, { 0.7, 0.26 }, { 1, 0 }),
		Color = CS(RGB(255, 255, 255), HEX("BFEBFF")),
		LightEmission = 0.3,
	})
	emitter(splash, "Foam", {
		When = "calm",
		Texture = tex("splash"),
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		FlipbookFramerate = NumberRange.new(30),
		Rate = 5,
		Lifetime = NumberRange.new(0.5, 0.55),
		Speed = NumberRange.new(0.5, 1),
		EmissionDirection = Enum.NormalId.Top,
		Size = NS({ 0, 1.8 }, { 0.4, 3.0 }, { 1, 3.4 }),
		Transparency = NS({ 0, 0.1 }, { 0.7, 0.25 }, { 1, 1 }),
		Color = CS(RGB(255, 255, 255)),
		LightEmission = 0.2,
		ZOffset = 0.4,
	})
	emitter(splash, "Mist", {
		Texture = tex("mist"),
		Rate = 3,
		Lifetime = NumberRange.new(1.4, 2.0),
		Speed = NumberRange.new(1, 2.4),
		SpreadAngle = Vector2.new(50, 50),
		EmissionDirection = Enum.NormalId.Top,
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-20, 20),
		Size = NS({ 0, 2.2 }, { 1, 5.2 }),
		Transparency = NS({ 0, 1 }, { 0.2, 0.72 }, { 0.7, 0.82 }, { 1, 1 }),
		Color = CS(RGB(255, 255, 255)),
		LightEmission = 0.1,
	})
end

local function buildFalls(tier: number)
	local m = begin("Ground_falls_T" .. tier)
	local L2, L3, fx = m.L2, m.L3, m.Fx
	local tall = tier >= 5

	-- the rock: the generated cliff, with the pool at its foot
	local target = model(m, "Target")
	local rock: MeshPart
	if tall then
		rock = mesh(target, "cliff2", "Cliff", V(10.2, 13.8, 6.2), V(0, 0, -7.9), V(0, 0, 1), true)
		mesh(target, "cliff1", "ShoulderL", V(6.4, 7.6, 5.0), V(-6.0, 0, -8.5), V(-0.3, 0, 1), true)
		mesh(target, "cliff1", "ShoulderR", V(6.4, 6.8, 5.0), V(6.0, 0, -8.5), V(1, 0, 0.2), true)
	else
		rock = mesh(target, "cliff1", "Cliff", V(13.2, 9.8, 5.8), V(0, 0, -8.1), V(0, 0, 1), true)
	end
	target.PrimaryPart = rock
	target.WorldPivot = CFrame.new(0, 0, -8)
	local lipY = rock.Size.Y - (if tall then 0.9 else 0.5)
	local faceZ = rock.Position.Z + rock.Size.Z / 2

	-- the pool: a stone kerb round three sides, deep water, a ripple on it
	local kerb = HEX("8F8E8A")
	box(m, "KerbFront", V(14.2, 0.75, 0.9), V(0, 0, 4.1), kerb, M.Slate, true)
	for _, x in { -6.65, 6.65 } do
		box(m, "KerbSide", V(0.9, 0.75, 10.2), V(x, 0, -0.9), kerb, M.Slate, true)
	end
	box(m, "PoolBed", V(12.6, 0.12, 9.8), V(0, 0, -0.9), HEX("1F5E9E"), M.SmoothPlastic)
	local waterTop = part(m, "PoolWater", V(12.6, SURFACE - 0.12, 9.8), CFrame.new(0, 0.12 + (SURFACE - 0.12) / 2, -0.9), HEX("48B4EE"), M.SmoothPlastic)
	waterTop.Transparency = 0.3
	waterTop.CastShadow = false
	waterTop.Reflectance = 0.08
	local ripples = Instance.new("Texture")
	ripples.Name = "Ripples"
	ripples.Face = Enum.NormalId.Top
	ripples.Texture = tex("pool_ripple")
	ripples.StudsPerTileU = 5
	ripples.StudsPerTileV = 5
	ripples.Transparency = 0.45
	ripples.Parent = waterTop
	-- rocks round the pool (the generated "river rocks" came out near-white and a textured mesh
	-- cannot be tinted: these are the seat stone again, in other sizes and turns)
	mesh(m, "med_stone", "RockFL", V(3.0, 2.0, 2.4), V(-6.4, 0, 4.2), V(-0.4, 0, 1), true)
	mesh(m, "med_stone", "RockFL2", V(1.8, 1.1, 1.6), V(-4.6, 0, 4.6), V(1, 0, 0.2), true)
	mesh(m, "med_stone", "RockFR", V(2.4, 1.5, 2.1), V(6.5, 0, 4.1), V(1, 0, 0.6), true)
	mesh(m, "med_stone", "RockBL", V(3.4, 2.6, 2.8), V(-5.3, 0, -4.6), V(1, 0, -0.3), true)
	mesh(m, "med_stone", "RockBL2", V(2.0, 1.4, 1.8), V(-3.3, 0, -4.2), V(0.2, 0, 1), true)
	mesh(m, "med_stone", "RockBR", V(3.0, 2.2, 2.6), V(5.5, 0, -4.5), V(-1, 0, 0.4), true)
	mesh(m, "med_stone", "RockBR2", V(1.7, 1.2, 1.5), V(3.4, 0, -4.1), V(-0.3, 0, 1), true)

	-- the seat: a flat stone in the pool, in front of the falls
	local stone = mesh(m, "med_stone", "Seat", 1.4, V(0, 0.05, -1.7), V(0, 0, 1), true)
	-- the seated clips hold the hips 0.32 above their floor (assets/animations batch r8): the "floor"
	-- is set that far into the stone's domed top, so the trainee sits ON it
	local seatTop = 0.05 + stone.Size.Y - 0.32
	local standAt = V(0, seatTop, -1.7)
	ghost(m, "Stand", V(2, 0.1, 2), CFrame.lookAt(standAt, standAt + V(0, 0, 1)))
	ghost(fx, "Seat", V(0.4, 0.4, 0.4), CFrame.new(0, SURFACE + 0.05, -1.7))
	local landZ = -1.7 - stone.Size.Z / 2 - 0.75
	ghost(fx, "Pool", V(0.4, 0.4, 0.4), CFrame.new(0, SURFACE + 0.05, landZ + 0.3))

	-- the falls: two halves side by side (they part in the awakening)
	local water = model(m, "Water")
	-- (they overlap by a third of a stud: side by side, their soft edges left a dark seam)
	local half, lap = 2.75, 0.34
	fallsHalf(water, "Left", V(-half / 2 + lap / 2, lipY, faceZ - 0.5), V(-half / 2 + lap / 2, SURFACE, landZ), half + lap)
	fallsHalf(water, "Right", V(half / 2 - lap / 2, lipY, faceZ - 0.5), V(half / 2 - lap / 2, SURFACE, landZ + 0.02), half + lap)
	-- the awakening: water and light run UP the gap between the halves
	local gap = ghost(water, "Gap", V(3.6, 0.3, 0.9), CFrame.new(0, SURFACE + 0.1, landZ - 0.2))
	emitter(gap, "UpDrops", {
		When = "awake",
		Enabled = false,
		Texture = tex("dot"),
		Rate = 46,
		Lifetime = NumberRange.new(0.6, 0.9),
		Speed = NumberRange.new(13, 20),
		SpreadAngle = Vector2.new(4, 4),
		EmissionDirection = Enum.NormalId.Top,
		Size = NS({ 0, 0 }, { 0.15, 0.5 }, { 0.8, 0.4 }, { 1, 0 }),
		Color = CS(RGB(255, 255, 255), HEX("7FE0FF")),
		LightEmission = 0.5,
	})
	emitter(gap, "UpStreaks", {
		When = "awake",
		Enabled = false,
		Texture = tex("streak"),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Rate = 22,
		Lifetime = NumberRange.new(0.35, 0.5),
		Speed = NumberRange.new(22, 32),
		SpreadAngle = Vector2.new(2, 2),
		EmissionDirection = Enum.NormalId.Top,
		Size = NS({ 0, 1.6 }, { 1, 0.5 }),
		Color = CS(RGB(255, 255, 255), HEX("7FE0FF")),
		LightEmission = 0.5,
	})
	-- (weak: a bright lamp on the pale rock whited the court out at max graphics)
	glow(gap, HEX("4FC4FF"), 12, 0.45, "awake")

	if tier == 6 then
		-- Dragon Falls: a stone dragon on each shoulder of the cliff spouts into the pool, and the
		-- kerb's corners are capped in gold
		for _, row in { { -6.0, 7.6 }, { 6.0, 6.8 } } do
			local x, top = row[1], row[2]
			local head = mesh(m, "dragon_spout", "Dragon", 1.4, V(x, top - 0.5, -6.6), V(-x * 0.2, 0, 1), true)
			-- the spout: an arc of the falls' own water from the mouth down into the pool (a stream of
			-- particles read as a string of beads)
			local mouth = V(x * 0.97, top - 0.5 + head.Size.Y * 0.42, -6.6 + head.Size.Z / 2)
			local landing = V(x * 0.7, SURFACE, -3.4)
			local holder = ghost(m, "Spout", V(0.3, 0.3, 0.3), CFrame.new(mouth))
			local out = (landing - mouth) * V(1, 0, 1)
			local a0 = Instance.new("Attachment")
			a0.Name = "Mouth"
			a0.Parent = holder
			a0.WorldCFrame = CFrame.lookAt(mouth, mouth + out) * CFrame.Angles(0, math.rad(90), 0)
			local a1 = Instance.new("Attachment")
			a1.Name = "Pool"
			a1.Parent = holder
			a1.WorldCFrame = CFrame.new(landing) * CFrame.Angles(0, 0, math.rad(-90))
			for _, layer in { { "water_sheet", 0.85, 0.2, 0 }, { "water_foam", 0.55, 0.35, 0.1 } } do
				local beam = waterBeam(holder, "Spout", a0, a1, layer[1], layer[2], 3, 4, layer[3], layer[4])
				beam.CurveSize0 = out.Magnitude * 0.55
				beam.CurveSize1 = 0.6
				beam.FaceCamera = true
				beam:SetAttribute("Flow", nil)
			end
			local splash = ghost(m, "SpoutSplash", V(0.8, 0.2, 0.8), CFrame.new(landing))
			emitter(splash, "Splash", {
				Texture = tex("dot"),
				Rate = 14,
				Lifetime = NumberRange.new(0.3, 0.45),
				Speed = NumberRange.new(2.5, 4),
				SpreadAngle = Vector2.new(35, 35),
				EmissionDirection = Enum.NormalId.Top,
				Acceleration = V(0, -18, 0),
				Size = NS({ 0, 0.25 }, { 1, 0 }),
				Color = CS(RGB(255, 255, 255)),
				LightEmission = 0.1,
			})
		end
		for _, c in { V(-6.65, 0, 4.1), V(6.65, 0, 4.1) } do
			box(m, "KerbCap", V(1.2, 0.95, 1.2), c, HEX("E3B341"), M.Metal, true)
		end
	end

	-- the notice board, at the open front corner (the walkway is -X here)
	noticeBoard(m, V(-6.6, 0, 8.3), V(-0.55, 0, 0.83))
	-- a stone lantern beside the rock (not at the front corner: it stood in the training camera's foreground)
	mesh(m, "stone_lantern", "Lantern", 1.25, V(7.8, 0, -2.6), V(-0.4, 0, 1), true)

	-- LEVEL II: the falls are made sacred: a rope with streamers across them, two lit lanterns
	local ropeY = lipY - 1.5
	rope(L2, "SacredRope", V(-4.6, ropeY + 0.5, faceZ + 0.35), V(4.6, ropeY + 0.5, faceZ + 0.35), 1.0, 0.42, HEX("D8B56A"), 12)
	for _, x in { -3.2, -1.1, 1.1, 3.2 } do
		local u = (x + 4.6) / 9.2
		shide(L2, V(x, ropeY + 0.5 - 4 * u * (1 - u) - 0.15, faceZ + 0.5), V(0, 0, 1))
	end
	for _, x in { -7.8, 7.8 } do
		local lantern = mesh(L2, "stone_lantern", "LitLantern", 1.25, V(x, 0, 1.2), V(0, 0, 1), true)
		local light = ghost(L2, "LanternLight", V(0.3, 0.3, 0.3), CFrame.new(x, lantern.Size.Y * 0.62, 1.2))
		glow(light, HEX("FFC97A"), 11, 1.6)
		emitter(light, "Motes", {
			Texture = tex("glint"),
			Rate = 2,
			Lifetime = NumberRange.new(1.2, 1.8),
			Speed = NumberRange.new(0.6, 1.4),
			SpreadAngle = Vector2.new(60, 60),
			EmissionDirection = Enum.NormalId.Top,
			Size = NS({ 0, 0 }, { 0.3, 0.5 }, { 1, 0 }),
			Color = CS(HEX("FFE9B0")),
			LightEmission = 0.7,
		})
	end

	-- LEVEL III: the pool glows: lotus lanterns afloat, spirit lights rising off the water
	for _, at in { V(-4.3, SURFACE - 0.05, 1.9), V(4.5, SURFACE - 0.05, 1.3), V(-3.6, SURFACE - 0.05, -2.9), V(3.9, SURFACE - 0.05, -3.2), V(1.6, SURFACE - 0.05, 2.9) } do
		local lotus = mesh(L3, "lotus_lantern", "Lotus", 0.95, at, V(math.sin(at.X * 3), 0, math.cos(at.Z * 2)))
		glow(lotus, HEX("FFB6D9"), 7, 1.2)
	end
	local spirits = ghost(L3, "Spirits", V(11.5, 0.2, 8.6), CFrame.new(0, SURFACE + 0.2, -0.9))
	emitter(spirits, "Wisps", {
		Texture = tex("glint"),
		Rate = 7,
		Lifetime = NumberRange.new(2.0, 3.2),
		Speed = NumberRange.new(0.8, 1.8),
		SpreadAngle = Vector2.new(20, 20),
		EmissionDirection = Enum.NormalId.Top,
		Rotation = NumberRange.new(0, 90),
		Size = NS({ 0, 0 }, { 0.2, 0.7 }, { 0.8, 0.5 }, { 1, 0 }),
		Color = CS(HEX("CFF6FF"), HEX("7FE0FF")),
		LightEmission = 0.8,
		Drag = 0.3,
	})
	finish(m)

	-- the display model: the rock, the seat and a plain sheet of water (beams do not draw in a card)
	local show = Instance.new("Model")
	show.Name = "Show_falls_T" .. tier
	local base = cyl(show, "Base", 0.4, 13, CFrame.new(0, 0.2, 2.2) * CFrame.Angles(0, 0, math.rad(90)), HEX("48B4EE"), M.SmoothPlastic)
	for _, piece in target:GetChildren() do
		local copy = piece:Clone()
		copy.CFrame = copy.CFrame + V(0, 0.2, 8)
		copy.Parent = show
	end
	local seat = stone:Clone()
	seat.CFrame = seat.CFrame + V(0, 0.3, 8)
	seat.Parent = show
	local sheet = part(show, "Sheet", V(5.4, lipY, 0.3), CFrame.new(0, 0.4 + lipY / 2, faceZ + 8 + 0.2), HEX("BFEBFF"), M.SmoothPlastic)
	sheet.Transparency = 0.15
	show.PrimaryPart = base
	local old = folder:FindFirstChild(show.Name)
	if old then
		old:Destroy()
	end
	show.Parent = folder
end

-- a gold crest ring let into a deck, round `centre` (level III of the striking grounds)
local function crestRing(parent: Instance, centre: Vector3, radius: number)
	local ring = model(parent, "CrestRing")
	for _, row in { { radius, 0.14, 32 }, { radius - 0.35, 0.06, 28 } } do
		local r, thick, count = row[1], row[2], row[3]
		for i = 0, count - 1 do
			local a = i / count * math.pi * 2
			local c = centre + V(math.cos(a) * r, 0.02, math.sin(a) * r)
			local length = 2 * math.pi * r / count + 0.03
			local seg = part(ring, "CrestSeg", V(length, 0.05, thick), CFrame.new(c) * CFrame.Angles(0, -a + math.pi / 2, 0), HEX("FFC83D"), M.Neon)
			seg.CastShadow = false
		end
	end
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local c = centre + V(math.cos(a) * radius, 0.03, math.sin(a) * radius)
		part(ring, "CrestStud", V(0.42, 0.07, 0.42), CFrame.new(c) * CFrame.Angles(0, math.pi / 4, 0), HEX("FFE9A8"), M.Neon).CastShadow = false
	end
end

local function showModel(name: string, base: BasePart, build: (Model) -> ())
	local show = Instance.new("Model")
	show.Name = name
	base.Parent = show
	build(show)
	show.PrimaryPart = base
	local old = folder:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	show.Parent = folder
end

-- ================================================================== BOULDER BREAKER (phase E)
-- Left court, like the post: the walkway is +X, the trainee faces -Z toward the boulder and the
-- quarry wall behind it, the training camera looks from +X in profile.
local BOULDERS = {
	[7] = { key = "boulder1", size = V(5.6, 6.2, 5.0), deck = HEX("8D8E93"), trim = HEX("5E5F66"), crack = RGB(26, 24, 30) },
	[8] = { key = "boulder2", size = V(5.6, 7.2, 5.2), deck = HEX("4B4650"), trim = HEX("2C2A33"), crack = HEX("FF8A2A") },
	[9] = { key = "boulder3", size = V(6.2, 6.6, 5.8), deck = HEX("3A2A2A"), trim = HEX("7A2E1E"), crack = HEX("FFD23F") },
}

local function buildBoulder(tier: number)
	local spec = BOULDERS[tier]
	local m = begin("Ground_boulder_T" .. tier)
	local L2, L3, fx = m.L2, m.L3, m.Fx

	-- the quarry floor: stone flags
	box(m, "Deck", V(13, DECK, 12.5), V(0, 0, -2.2), spec.deck, M.Slate, true)
	for _, e in { { V(13.5, DECK + 0.08, 0.5), V(0, 0, 4.05) }, { V(13.5, DECK + 0.08, 0.5), V(0, 0, -8.45) }, { V(0.5, DECK + 0.08, 12.5), V(-6.5, 0, -2.2) }, { V(0.5, DECK + 0.08, 12.5), V(6.5, 0, -2.2) } } do
		box(m, "DeckEdge", e[1], e[2], spec.trim, M.Cobblestone)
	end
	-- the quarry face behind: three lengths of dry-stone wall
	for _, x in { -5.1, 0, 5.1 } do
		mesh(m, "rock_wall", "QuarryWall", V(5.3, 5.4, 2.8), V(x, 0, -9.9), V(0, 0, 1), true)
	end

	-- the boulder
	local target = model(m, "Target")
	local rock = mesh(target, spec.key, "Boulder", spec.size, V(0, DECK, -5.4), V(0, 0, 1), true)
	target.PrimaryPart = rock
	target.WorldPivot = CFrame.new(0, DECK, -5.4)
	-- it is round: at chest height its face stands a little behind its foremost point
	local face = -5.4 + rock.Size.Z / 2 - 0.35
	ghost(fx, "Strike", V(0.4, 0.4, 0.4), CFrame.new(0, DECK + 3.5, face + 0.12))
	local standAt = V(0, DECK, face + Config.Training.Grounds[3].Contact)
	ghost(m, "Stand", V(2, 0.1, 2), CFrame.lookAt(standAt, standAt - V(0, 0, 1)))
	-- the cracks that grow with Focus: four panes on the struck face, one crack each, each turned
	-- another way (GroundController:Focus shows them stage by stage)
	local cracks = model(target, "Cracks")
	for stage, turn in { 0, 115, 205, 290 } do
		local pane = ghost(cracks, "Pane" .. stage, V(2.6 + stage * 0.5, 2.6 + stage * 0.5, 0.05), CFrame.new(0, DECK + 3.3, face + 0.03 + stage * 0.01) * CFrame.Angles(0, 0, math.rad(turn)))
		local decal = Instance.new("Decal")
		decal.Name = "Crack"
		decal.Face = Enum.NormalId.Back
		decal.Texture = tex("crack")
		decal.Color3 = spec.crack
		decal.Transparency = 1
		decal:SetAttribute("Stage", stage)
		decal.Parent = pane
	end

	-- the yard: a quarry crane and lifting stones on the outer side, rubble against the wall
	mesh(m, "quarry_crane", "Crane", 2.1, V(-5.4, 0, -4.4), V(1, 0, 0.15), true)
	mesh(m, "stone_weights", "Weights", 1.0, V(-4.9, DECK, 1.9), V(1, 0, 0.2), true)
	mesh(m, "rubble_pile", "Rubble", 0.9, V(3.4, DECK, -7.5), V(0.3, 0, 1), true)
	mesh(m, "rubble_pile", "Rubble", 0.7, V(-2.9, DECK, -7.6), V(-1, 0, 0.4), true)
	noticeBoard(m, V(6.6, 0, 8.3), V(0.55, 0, 0.83))

	-- LEVEL II: the rock is made sacred: a rope round it, a stone fist and two banners
	local ropeY = DECK + rock.Size.Y * 0.62
	local radius = rock.Size.X / 2 * 0.93
	local last: Vector3? = nil
	for i = 0, 16 do
		local a = i / 16 * math.pi * 2
		local at = V(math.cos(a) * radius, ropeY + 0.18 * math.sin(a * 3), -5.4 + math.sin(a) * radius * (rock.Size.Z / rock.Size.X))
		if last then
			local mid = (last + at) / 2
			cyl(L2, "SacredRope", (at - last).Magnitude + 0.14, 0.38, CFrame.lookAt(mid, at) * CFrame.Angles(0, math.rad(90), 0), HEX("D8B56A"), M.Fabric)
		end
		last = at
	end
	for _, a in { 0.9, 1.35, 1.8, 2.25 } do
		shide(L2, V(math.cos(a) * radius, ropeY - 0.2, -5.4 + math.sin(a) * radius * (rock.Size.Z / rock.Size.X) + 0.12), V(0, 0, 1))
	end
	mesh(L2, "stone_fist", "StoneFist", 1.25, V(-7.2, 0, 7.0), V(1, 0, -0.35), true)
	banner(L2, V(-7.9, 0, -8.6), V(0, 0, 1), 9.2, HEX("3A3F4A"), HEX("FFE9A8"), "岩\n砕")
	banner(L2, V(-7.9, 0, 3.6), V(1, 0, 0), 8.4, HEX("F6EFD9"), HEX("3A3F4A"), "剛\n力")

	-- LEVEL III: fire and gold
	-- (both on the far side: the training camera looks in from +X, and a brazier there stood big in
	-- the right of the shot)
	for _, at in { V(-5.9, DECK, -7.3), V(-6.0, DECK, -1.2) } do
		local b = mesh(L3, "brazier", "Brazier", 1.3, at, V(0, 0, 1), true)
		fire(L3, at + V(0, b.Size.Y * 0.74, 0), 1.1)
	end
	crestRing(L3, V(0, DECK, standAt.Z - 0.4), 3.3)
	finish(m)

	showModel("Show_boulder_T" .. tier, cyl(folder, "Base", 0.4, 7.4, CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)), spec.deck, M.Slate), function(show)
		mesh(show, spec.key, "Boulder", spec.size, V(0, 0.4, 0), V(0, 0, 1))
	end)
end

-- ================================================================== THUNDER PEAK (phase E)
-- Right court, like the falls: the walkway is -X. The trainee stands on the summit rock facing +Z
-- (the lane); three lightning rods stand behind them (rod 1 = -X = the camera's left, rod 2 the
-- tall middle one, rod 3 = +X); the training camera looks from the front, from below eye level.
local PEAKS = {
	[10] = { rod = "lightning_rod", side = 1.5, mid = 1.9, deck = HEX("5A5F6B"), clouds = 1 },
	[11] = { rod = "rod2", side = 1.45, mid = 1.85, deck = HEX("474A58"), clouds = 2 },
	-- Heaven's Peak: golden dragon rods on a pale summit
	[12] = { rod = "rod3", side = 1.15, mid = 1.48, deck = HEX("8E93A8"), clouds = 2 },
}
local VOLT = HEX("FFE85A")

local function buildPeak(tier: number)
	local spec = PEAKS[tier]
	local m = begin("Ground_peak_T" .. tier)
	local L2, L3, fx = m.L2, m.L3, m.Fx

	-- the mountain top: slate flags with drifts of snow
	box(m, "Deck", V(15.5, 0.25, 15), V(0, 0, -1.6), spec.deck, M.Slate, true)
	for _, d in { { V(-5.6, 0.25, 3.6), V(3.4, 0.08, 2.2) }, { V(5.9, 0.25, -3.4), V(2.6, 0.08, 3.4) }, { V(-6.2, 0.25, -5.2), V(2.4, 0.08, 2.8) }, { V(2.2, 0.25, 4.6), V(3.0, 0.08, 1.6) } } do
		local snow = part(m, "Snow", d[2], CFrame.new(d[1] + V(0, 0.04, 0)), RGB(240, 246, 252), M.Sand)
		snow.CastShadow = false
	end
	-- the summit rock the trainee stands on
	local summit = mesh(m, "peak_rock", "Summit", V(8.4, 2.8, 7.4), V(0, 0.25, -1.2), V(0, 0, 1), true)
	local top = 0.25 + summit.Size.Y - 0.3
	local standAt = V(0, top, -0.8)
	ghost(m, "Stand", V(2, 0.1, 2), CFrame.lookAt(standAt, standAt + V(0, 0, 1)))
	ghost(fx, "Seat", V(0.4, 0.4, 0.4), CFrame.new(0, top + 0.05, -0.8))
	-- two crags behind, either side
	mesh(m, "peak_rock", "Crag", V(5.6, 8.6, 4.6), V(-6.6, 0.25, -8.6), V(-0.3, 0, 1), true)
	mesh(m, "peak_rock", "Crag", V(5.2, 7.4, 4.4), V(6.7, 0.25, -8.7), V(1, 0, 0.5), true)

	-- the three rods: the centrepiece
	local target = model(m, "Target")
	local places = { { -4.3, -6.4, spec.side }, { 0, -7.6, spec.mid }, { 4.3, -6.4, spec.side } }
	for lane, at in places do
		local rod = mesh(target, spec.rod, "Rod" .. lane, at[3], V(at[1], 0.25, at[2]), V(0, 0, 1), true)
		if lane == 2 then
			target.PrimaryPart = rod
		end
		-- its tip: where the bolt lands, and the mark that shows it is next
		local tip = ghost(fx, "Rod" .. lane, V(0.6, 0.6, 0.6), CFrame.new(at[1], 0.25 + rod.Size.Y - 0.25, at[2]))
		local mark = emitter(tip, "Mark", {
			Texture = tex("boltsprite"),
			Rate = 16,
			Lifetime = NumberRange.new(0.08, 0.16),
			Speed = NumberRange.new(0, 0.5),
			Rotation = NumberRange.new(0, 360),
			Size = NS({ 0, 1.6 }, { 1, 2.8 }),
			Color = CS(RGB(255, 255, 255), VOLT),
			LightEmission = 0.4,
			ZOffset = 0.5,
		})
		mark.Enabled = false
		local lamp = glow(tip, VOLT, 12, 1.2)
		lamp.Enabled = false
	end
	target.WorldPivot = CFrame.new(0, 0.25, -7.6)
	-- the bolt that runs from a rod to the trainee's hand (GroundController copies it per catch)
	local holder = ghost(fx, "Arc", V(0.2, 0.2, 0.2), CFrame.new(0, 6, -4))
	local bolt = Instance.new("Beam")
	bolt.Name = "Arc"
	bolt.Texture = tex("bolt")
	bolt.TextureMode = Enum.TextureMode.Stretch
	bolt.TextureLength = 1
	bolt.Width0 = 1.7
	bolt.Width1 = 1.2
	bolt.Segments = 12
	bolt.FaceCamera = true
	bolt.LightEmission = 0.4
	bolt.LightInfluence = 0
	bolt.Brightness = 1.6
	bolt.Color = CS(RGB(255, 255, 255), VOLT)
	bolt.Transparency = NumberSequence.new(0)
	bolt.Enabled = false
	bolt.Parent = holder

	-- the storm overhead
	-- (built of dark balls: the generated cloud came sky blue twice, and a textured mesh cannot be tinted)
	local puffs = { { 0, 0, 0, 5.2 }, { -3.0, -0.3, 0.4, 4.2 }, { 3.1, -0.2, -0.3, 4.4 }, { -5.4, -0.7, -0.2, 3.0 }, { 5.6, -0.6, 0.3, 3.2 },
		{ -1.4, 1.1, -0.6, 3.6 }, { 1.7, 1.2, 0.5, 3.4 }, { 0.3, -0.9, 1.6, 3.4 }, { -2.2, -0.8, -1.7, 3.2 }, { 2.6, -0.9, -1.6, 3.0 }, { -4.0, -1.0, 1.2, 2.8 }, { 4.2, -1.0, 1.1, 2.8 },
		{ 1.4, -1.2, -0.2, 3.2 }, { -1.3, -1.2, 0.3, 3.0 } }
	for i = 1, spec.clouds do
		local centre = if i == 1 then V(0.4, 17.2, -7.2) else V(-5.2, 14.8, -3.6)
		local scale = if i == 1 then 1 else 0.62
		local cloud = model(m, "StormCloud")
		for n, puff in puffs do
			local ball = part(cloud, "Puff", V(puff[4], puff[4], puff[4]) * scale, CFrame.new(centre + V(puff[1], puff[2], puff[3]) * scale),
				-- (matte and charcoal, not black plastic: shiny black balls read as balloons)
				if n % 3 == 0 then RGB(96, 100, 116) else RGB(74, 78, 94), M.Sand)
			ball.Shape = Enum.PartType.Ball
			ball.CastShadow = false
		end
		-- the flicker inside it while the trainee is awakened (no flat belly: a slab under the puffs
		-- read as a black tray from the training camera, which looks up at it)
		local heart = ghost(cloud, "Heart", V(1, 1, 1), CFrame.new(centre - V(0, 1.2 * scale, 0)))
		glow(heart, VOLT, 18, 0.5, "awake")
	end

	noticeBoard(m, V(-6.6, 0, 8.3), V(-0.55, 0, 0.83))

	-- LEVEL II: the thunder drums and the first storm crystals
	-- (back beside the crag: at the front corner they stood big in the training shot)
	mesh(L2, "thunder_drums", "ThunderDrums", 1.9, V(7.4, 0.25, -3.9), V(-0.8, 0, 0.6), true)
	for _, at in { V(-5.0, 0.25, 1.8), V(4.9, 0.25, -1.0) } do
		mesh(L2, "storm_crystal", "Crystal", 1.0, at, V(at.X, 0, 1), true)
	end

	-- LEVEL III: the peak is charged: glowing crystals round the rock, a ring of light under it
	-- (none in front of the summit: the training camera looks up at the trainee from there)
	for _, at in { V(-6.6, 0.25, -1.4), V(6.9, 0.25, 0.6), V(-6.5, 0.25, 4.7) } do
		local crystal = mesh(L3, "storm_crystal", "Crystal", 1.25, at, V(-at.X, 0, 1), true)
		glow(crystal, HEX("9FE3FF"), 9, 1.0)
	end
	crestRing(L3, V(0, 0.25, -1.2), 5.6)
	finish(m)

	showModel("Show_peak_T" .. tier, cyl(folder, "Base", 0.4, 13, CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)), spec.deck, M.Slate), function(show)
		mesh(show, "peak_rock", "Summit", V(8.4, 2.8, 7.4), V(0, 0.4, 2.4), V(0, 0, 1))
		for lane, at in places do
			mesh(show, spec.rod, "Rod" .. lane, at[3], V(at[1], 0.4, at[2] + 3.6), V(0, 0, 1))
		end
	end)
end

-- a ring of glowing segments let into a floor (any colour; the gold crest ring is crestRing)
local function neonRing(parent: Instance, centre: Vector3, radius: number, thick: number, color: Color3, count: number, name: string?)
	for i = 0, count - 1 do
		local a = i / count * math.pi * 2
		local c = centre + V(math.cos(a) * radius, 0.02, math.sin(a) * radius)
		local length = 2 * math.pi * radius / count + 0.03
		local seg = part(parent, name or "RingSeg", V(length, 0.05, thick), CFrame.new(c) * CFrame.Angles(0, -a + math.pi / 2, 0), color, M.Neon)
		seg.CastShadow = false
	end
end

-- ================================================================== GRAVITY CHAMBER (phase E, pair 2)
-- Left court, like the post: the walkway is +X, the trainee does push-ups facing -Z toward the
-- generator, the training camera looks from +X in profile and LOW (nothing tall stands between
-- x 0 and 9 beside the trainee). A round steel deck under a ring held up by four emitter pylons.
local GRAVITY = {
	[13] = { machine = "gravity_generator", scale = 1.1, energy = HEX("B58CFF"), neon = HEX("7A3CFF"), deck = HEX("34364A"), trim = HEX("8C7A4A"), g = { "10 G", "25 G", "50 G" } },
	[14] = { machine = "gravity_core", scale = 1.08, energy = HEX("FF5CD6"), neon = HEX("E01FB4"), deck = HEX("26222E"), trim = HEX("C9A24A"), g = { "100 G", "250 G", "500 G" } },
	[15] = { machine = "gravity_singularity", scale = 1.1, energy = HEX("FF8A5C"), neon = HEX("FF3A14"), deck = HEX("1C1A1E"), trim = HEX("D8B24A"), g = { "1000 G", "2500 G", "5000 G" } },
}

local function buildGravity(tier: number)
	local spec = GRAVITY[tier]
	local m = begin("Ground_gravity_T" .. tier)
	local L2, L3, fx = m.L2, m.L3, m.Fx
	m:SetAttribute("Energy", spec.energy)
	local TOP_Y = 0.36
	local C = V(0, 0, -1.2) -- the deck's centre

	-- the deck: a steel disc on a wider brass-edged step, rings of light let into it
	post(m, "DeckStep", 0.2, 14.2, C, spec.trim, M.Metal, true)
	post(m, "Deck", TOP_Y, 13.2, C, spec.deck, M.DiamondPlate, true)
	neonRing(m, C + V(0, TOP_Y, 0), 6.2, 0.16, spec.neon, 36)
	neonRing(m, C + V(0, TOP_Y, 0), 3.4, 0.1, spec.neon, 24)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2 + math.pi / 8
		local mid = C + V(math.cos(a) * 4.8, TOP_Y + 0.01, math.sin(a) * 4.8)
		part(m, "DeckSeam", V(2.7, 0.04, 0.12), CFrame.new(mid) * CFrame.Angles(0, -a, 0), HEX("15161F"), M.Metal).CastShadow = false
	end
	local standAt = V(0, TOP_Y, -0.6)
	ghost(m, "Stand", V(2, 0.1, 2), CFrame.lookAt(standAt, standAt - V(0, 0, 1)))
	-- under the chest (the plank lies from the toes at +2.1 behind to the hands at 1.3 in front)
	ghost(fx, "Floor", V(0.4, 0.2, 0.4), CFrame.new(0, TOP_Y + 0.05, -1.2))

	-- the machine behind the deck: the centrepiece
	local target = model(m, "Target")
	local machine = mesh(target, spec.machine, "Machine", spec.scale, V(0, 0, -9.0), V(0, 0, 1), true)
	target.PrimaryPart = machine
	target.WorldPivot = CFrame.new(0, 0, -9.0)
	local hum = ghost(fx, "Hum", V(0.4, 0.4, 0.4), CFrame.new(0, 3.6, -8.4))
	glow(hum, spec.energy, 12, 0.6)

	-- four emitter pylons hold a ring over the deck
	local RING_Y, RING_R = 10.6, 5.0
	-- (the two on the camera's side stand wide: at x 6.2 the far one stood in the training shot)
	local pylons = { V(7.5, 0, 3.8), V(7.5, 0, -7.6), V(-6.2, 0, 4.4), V(-6.2, 0, -6.8) }
	for _, at in pylons do
		local pylon = mesh(m, "gravity_pylon", "Pylon", 1.2, at, V(-at.X, 0, -at.Z + C.Z), true)
		local tip = at + V(0, pylon.Size.Y - 0.5, 0)
		local dir = (C - at) * V(1, 0, 1)
		local hold = C + V(0, RING_Y, 0) - dir.Unit * RING_R
		local mid = (tip + hold) / 2
		cyl(m, "Strut", (hold - tip).Magnitude, 0.22, CFrame.lookAt(mid, hold) * CFrame.Angles(0, math.rad(90), 0), HEX("23242E"), M.Metal)
	end
	local ring = model(m, "FieldRing")
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		local c = C + V(math.cos(a) * RING_R, RING_Y, math.sin(a) * RING_R)
		local length = 2 * math.pi * RING_R / 24 + 0.05
		part(ring, "RingBody", V(length, 0.55, 0.7), CFrame.new(c) * CFrame.Angles(0, -a + math.pi / 2, 0), HEX("23242E"), M.Metal)
		local lit = part(ring, "RingLight", V(length, 0.14, 0.74), CFrame.new(c - V(0, 0.3, 0)) * CFrame.Angles(0, -a + math.pi / 2, 0), spec.neon, M.Neon)
		lit.CastShadow = false
	end
	-- the field itself: faint columns of light from the ring to the deck (they run DOWN; awakened, UP)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2 + 0.3
		local foot = C + V(math.cos(a) * RING_R, TOP_Y + 0.05, math.sin(a) * RING_R)
		local holder = ghost(ring, "FieldLine", V(0.2, 0.2, 0.2), CFrame.new(foot))
		local a0 = Instance.new("Attachment")
		a0.Parent = holder
		a0.WorldCFrame = CFrame.new(foot + V(0, RING_Y - TOP_Y - 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90))
		local a1 = Instance.new("Attachment")
		a1.Parent = holder
		a1.WorldCFrame = CFrame.new(foot) * CFrame.Angles(0, 0, math.rad(90))
		for _, when in { "calm", "awake" } do
			local beam = Instance.new("Beam")
			beam.Name = "Field_" .. when
			beam.Attachment0 = if when == "calm" then a0 else a1
			beam.Attachment1 = if when == "calm" then a1 else a0
			beam.Texture = tex("streakline")
			beam.TextureMode = Enum.TextureMode.Wrap
			beam.TextureLength = 5
			beam.TextureSpeed = if when == "calm" then 1.4 else 4.5
			beam.Width0 = 0.9
			beam.Width1 = 0.9
			beam.FaceCamera = true
			beam.LightEmission = 0.3
			beam.LightInfluence = 0
			beam.Color = CS(spec.energy)
			beam.Transparency = NS({ 0, 1 }, { 0.2, if when == "calm" then 0.72 else 0.45 }, { 0.8, if when == "calm" then 0.72 else 0.45 }, { 1, 1 })
			beam:SetAttribute("When", when)
			beam.Enabled = when == "calm"
			beam.Parent = holder
		end
	end
	local heart = ghost(ring, "RingHeart", V(1, 1, 1), CFrame.new(C + V(0, RING_Y - 1, 0)))
	glow(heart, spec.energy, 20, 0.5, "awake")

	-- the readout: how heavy it is in there, on a glass panel behind the trainee (the training
	-- camera reads it from +X) and on the console at the front (the player walking up reads that)
	local function readout(parent: Instance, text: string, grow: number)
		local panel = part(parent, "Readout", V(0.12 + grow, 2.0 + grow, 4.6 + grow), CFrame.new(-5.0, 5.2, -1.2), HEX("12121C"), M.Glass)
		panel.Transparency = 0.35
		panel.CastShadow = false
		for _, face in { Enum.NormalId.Right, Enum.NormalId.Left } do
			local label = words(panel, face, text, spec.energy, 60, HEX("12121C"))
			label.Parent.LightInfluence = 0
		end
		local dial = part(parent, "DialReadout", V(1.5 + grow, 0.62 + grow, 0.06 + grow / 2), CFrame.new(-5.3, 4.55, 7.62) * CFrame.Angles(0, math.rad(-17), 0), HEX("12121C"), M.SmoothPlastic)
		dial.CastShadow = false
		local label = words(dial, Enum.NormalId.Back, text, spec.energy, 80)
		label.Parent.LightInfluence = 0
	end
	for _, z in { -3.2, 0.8 } do
		post(m, "ReadoutPost", 4.3, 0.18, V(-5.0, 0, z), HEX("23242E"), M.Metal)
	end
	box(m, "ReadoutFoot", V(0.8, 0.3, 4.8), V(-5.0, 0, -1.2), HEX("23242E"), M.Metal, true)
	readout(m, spec.g[1], 0)
	mesh(m, "gravity_console", "Console", 1.0, V(-5.6, 0, 6.6), V(0.3, 0, 1), true)
	noticeBoard(m, V(6.6, 0, 8.3), V(0.55, 0, 0.83))

	-- what is loose: it drifts up when gravity is turned over (GroundController: Floaters)
	local floaters = model(m, "Floaters")
	local function loose(parent: Instance, name: string, build: (Model) -> ())
		local one = model(parent, name)
		build(one)
		local cf = one:GetBoundingBox()
		one.WorldPivot = cf
	end
	for i, row in { { V(-3.9, TOP_Y, -4.6), 0.95 }, { V(-3.4, TOP_Y, 2.9), 0.62 }, { V(3.3, TOP_Y, -5.9), 0.55 } } do
		loose(floaters, "Weight" .. i, function(one)
			mesh(one, "iron_weight", "Weight", row[2], row[1], V(1, 0, 0.3 * i), true)
		end)
	end
	for i, row in { { -1.9, -5.3, 0.7 }, { -4.6, -1.4, 0.5 }, { -2.6, 0.9, 0.42 }, { 1.6, -5.9, 0.45 }, { -4.9, 1.4, 0.6 }, { -1.4, 3.6, 0.38 } } do
		loose(floaters, "Plate" .. i, function(one)
			local slab = part(one, "Plate", V(row[3] * 2, row[3] * 0.5, row[3] * 1.4), CFrame.new(row[1], TOP_Y + row[3] * 0.25, row[2] - 1.2 + 1.2) * CFrame.Angles(0, i * 1.1, 0), spec.deck, M.DiamondPlate, true)
			local _ = slab
		end)
	end

	-- LEVEL II: heavier: more iron, the banners, the higher reading
	for i, row in { { V(-5.6, 0, -3.9), 1.15 }, { V(4.9, TOP_Y, 3.4), 0.5 } } do
		loose(floaters, "Heavy" .. i, function(one)
			mesh(one, "iron_weight", "Weight", row[2], row[1], V(1, 0, -0.4), true)
		end)
		-- (in Floaters so it flies, but it belongs to level II: the server takes L2 away, so mark it)
		local heavy = floaters:FindFirstChild("Heavy" .. i) :: Model
		heavy.Parent = L2
		heavy.Name = "Floater"
	end
	readout(L2, spec.g[2], 0.06)
	banner(L2, V(-7.9, 0, -8.6), V(0, 0, 1), 9.2, HEX("2A2440"), spec.energy, "重\n力")
	banner(L2, V(-7.9, 0, 3.4), V(1, 0, 0), 8.4, HEX("F6EFD9"), HEX("2A2440"), "百\n倍")

	-- LEVEL III: the chamber at full power: a second ring of light overhead, the crest in the deck
	readout(L3, spec.g[3], 0.12)
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		local c = C + V(math.cos(a) * (RING_R + 0.9), RING_Y + 0.5, math.sin(a) * (RING_R + 0.9))
		local length = 2 * math.pi * (RING_R + 0.9) / 24 + 0.05
		local lit = part(L3, "OuterLight", V(length, 0.2, 0.2), CFrame.new(c) * CFrame.Angles(0, -a + math.pi / 2, 0), HEX("FFB81F"), M.Neon)
		lit.CastShadow = false
	end
	crestRing(L3, C + V(0, TOP_Y, 0), 5.3)
	for _, at in pylons do
		local lamp = ghost(L3, "PylonLamp", V(0.4, 0.4, 0.4), CFrame.new(at + V(0, 6.9, 0)))
		glow(lamp, spec.energy, 9, 0.9)
	end
	finish(m)

	showModel("Show_gravity_T" .. tier, cyl(folder, "Base", 0.4, 9, CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)), spec.deck, M.DiamondPlate), function(show)
		mesh(show, spec.machine, "Machine", spec.scale, V(0, 0.4, -0.6), V(0, 0, 1))
		mesh(show, "iron_weight", "Weight", 0.7, V(-3.0, 0.4, 1.8), V(1, 0, 0.3))
		mesh(show, "iron_weight", "Weight", 0.5, V(3.0, 0.4, 2.0), V(-1, 0, 0.3))
	end)
end

-- ================================================================== SPIRIT ORB (phase E, pair 2)
-- Right court, like the falls: the walkway is -X. The trainee stands on a stone dais facing +Z (the
-- lane) with the orb over their raised hands; the shrine stands behind them between standing
-- stones; the training camera looks from the front, from below eye level.
local ORBS = {
	[16] = { stone = "spirit_monolith", size = V(2.3, 5.0, 2.3), energy = HEX("7CF59A"), neon = HEX("12C552"), body = HEX("46E882"), deck = HEX("C9CBC4"), step = HEX("9A9E98"), rest = 1.6, full = 4.0, awake = 8.5 },
	[17] = { stone = "sun_pillar", size = V(3.2, 7.5, 2.5), energy = HEX("FFB02E"), neon = HEX("FF7A14"), body = HEX("FFA62B"), deck = HEX("E6D3A6"), step = HEX("C9A86A"), rest = 1.9, full = 4.6, awake = 9.5 },
	[18] = { stone = "star_pillar", size = V(3.0, 7.2, 2.7), energy = HEX("8FC4FF"), neon = HEX("2A6BFF"), body = HEX("5AA0FF"), deck = HEX("C9D2E6"), step = HEX("8E9BB8"), rest = 2.1, full = 5.0, awake = 10 },
	[19] = { stone = "galaxy_pillar", size = V(2.9, 7.6, 2.9), energy = HEX("E08CFF"), neon = HEX("A02CFF"), body = HEX("C45CFF"), deck = HEX("4A3F66"), step = HEX("2A2140"), rest = 2.3, full = 5.4, awake = 10.5 },
}

local function buildOrb(tier: number)
	local spec = ORBS[tier]
	local m = begin("Ground_orb_T" .. tier)
	local L2, L3, fx = m.L2, m.L3, m.Fx
	m:SetAttribute("Energy", spec.energy)
	m:SetAttribute("OrbRest", spec.rest)
	m:SetAttribute("OrbFull", spec.full)
	m:SetAttribute("OrbAwake", spec.awake)
	local TOP_Y = 0.55
	local C = V(0, 0, -0.8)

	-- the dais: two steps of pale stone, a ring of light let into the top
	post(m, "DaisStep", 0.28, 14.4, C, spec.step, M.Slate, true)
	post(m, "Dais", TOP_Y, 12.8, C, spec.deck, M.Slate, true)
	neonRing(m, C + V(0, TOP_Y, 0), 5.9, 0.16, spec.neon, 36)
	neonRing(m, C + V(0, TOP_Y, 0), 2.7, 0.1, spec.neon, 20)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local c = C + V(math.cos(a) * 4.3, TOP_Y + 0.02, math.sin(a) * 4.3)
		part(m, "RuneStud", V(0.5, 0.06, 0.5), CFrame.new(c) * CFrame.Angles(0, a + math.pi / 4, 0), spec.neon, M.Neon).CastShadow = false
	end
	local standAt = V(0, TOP_Y, -0.4)
	ghost(m, "Stand", V(2, 0.1, 2), CFrame.lookAt(standAt, standAt + V(0, 0, 1)))
	ghost(fx, "Seat", V(0.4, 0.4, 0.4), CFrame.new(0, TOP_Y + 0.05, -0.4))

	-- the orb: its underside rests on this point over the raised hands (the root stands 3 above the
	-- floor, the hands reach 2.2 above that; the client carries it on the hands while someone trains)
	local restAt = V(0, TOP_Y + 3 + 2.2 + 0.45, -0.2)
	ghost(fx, "Orb", V(0.3, 0.3, 0.3), CFrame.new(restAt))
	local target = model(m, "Target")
	local centre = restAt + V(0, spec.rest / 2, 0)
	-- (a lit ball under a glowing shell: a Neon ball alone drew as a flat disc and bloomed to cyan-white)
	local core = part(target, "Core", V(spec.rest, spec.rest, spec.rest), CFrame.new(centre), spec.body, M.SmoothPlastic)
	core.Shape = Enum.PartType.Ball
	core.CastShadow = false
	local shell = part(target, "Shell", V(spec.rest, spec.rest, spec.rest) * 1.16, CFrame.new(centre), spec.neon, M.Neon)
	shell.Shape = Enum.PartType.Ball
	shell.Transparency = 0.6
	shell.CastShadow = false
	target.PrimaryPart = core
	target.WorldPivot = CFrame.new(centre)
	glow(core, spec.energy, 12, 0.7)
	-- wisps that leave it all the time; a corona while it is enormous
	emitter(core, "Wisps", {
		Texture = tex("dot"),
		Rate = 7,
		Lifetime = NumberRange.new(0.7, 1.1),
		Speed = NumberRange.new(1, 2.4),
		SpreadAngle = Vector2.new(180, 180),
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Size = NS({ 0, 0 }, { 0.2, 0.34 }, { 1, 0 }),
		Color = CS(Color3.new(1, 1, 1), spec.energy),
		LightEmission = 0.45,
		ZOffset = 0.5,
	})
	emitter(core, "Corona", {
		When = "awake",
		Enabled = false,
		Texture = tex("glint"),
		Rate = 14,
		Lifetime = NumberRange.new(0.35, 0.6),
		Speed = NumberRange.new(3, 7),
		SpreadAngle = Vector2.new(180, 180),
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Rotation = NumberRange.new(0, 90),
		Size = NS({ 0, 0 }, { 0.3, 1.6 }, { 1, 0 }),
		Color = CS(Color3.new(1, 1, 1), spec.energy),
		LightEmission = 0.5,
		ZOffset = 1,
	})
	-- the wake it leaves when it is thrown
	local t0 = Instance.new("Attachment")
	t0.Name = "TrailA"
	t0.Position = V(0, 0.5, 0)
	t0.Parent = core
	local t1 = Instance.new("Attachment")
	t1.Name = "TrailB"
	t1.Position = V(0, -0.5, 0)
	t1.Parent = core
	local trail = Instance.new("Trail")
	trail.Attachment0 = t0
	trail.Attachment1 = t1
	trail.Lifetime = 0.45
	trail.WidthScale = NS({ 0, 5 }, { 1, 0.5 })
	trail.FaceCamera = true
	trail.LightEmission = 0.4
	trail.LightInfluence = 0
	trail.Color = CS(Color3.new(1, 1, 1), spec.energy)
	trail.Transparency = NS({ 0, 0.15 }, { 1, 1 })
	trail.Enabled = false
	trail.Parent = core
	-- the charge: motes drawn IN to the orb from all round (GroundController turns Motes on while the
	-- player holds; Gather runs through the awakening)
	local field = ghost(fx, "Field", V(10, 10, 10), CFrame.new(restAt + V(0, 1.6, 0)))
	field.Shape = Enum.PartType.Ball
	for name, rate in { Motes = 22, Gather = 34 } do
		local e = emitter(field, name, {
			Texture = tex("dot"),
			Rate = rate,
			Lifetime = NumberRange.new(0.5, 0.75),
			Speed = NumberRange.new(5.5, 7.5),
			Shape = Enum.ParticleEmitterShape.Sphere,
			ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			Size = NS({ 0, 0 }, { 0.25, 0.42 }, { 1, 0.15 }),
			Color = CS(spec.energy, Color3.new(1, 1, 1)),
			LightEmission = 0.45,
			ZOffset = 0.5,
		})
		e.Enabled = false
		if name == "Gather" then
			e:SetAttribute("When", "awake")
		end
	end

	-- the shrine behind, between standing stones
	mesh(m, "spirit_shrine", "Shrine", 1.0, V(0, 0, -8.8), V(0, 0, 1), true)
	local stones = { V(-4.7, TOP_Y, -4.3), V(4.7, TOP_Y, -4.3), V(-7.5, 0, -1.4), V(7.5, 0, -1.4) }
	for _, at in stones do
		mesh(m, spec.stone, "Stone", spec.size, at, V(-at.X * 0.4, 0, 1), true)
	end
	-- incense at the front corners
	-- (small and beside the dais: at the front corners they filled the corners of the training shot)
	for _, x in { -7.4, 7.4 } do
		local urn = mesh(m, "incense_burner", "Incense", 0.68, V(x, 0, 2.6), V(-x * 0.3, 0, 1), true)
		local top = ghost(m, "IncenseTop", V(0.5, 0.2, 0.5), CFrame.new(x, urn.Size.Y + 0.05, 2.6))
		emitter(top, "Smoke", {
			Texture = tex("mist"),
			Rate = 3,
			Lifetime = NumberRange.new(2.2, 3.0),
			Speed = NumberRange.new(0.8, 1.4),
			SpreadAngle = Vector2.new(8, 8),
			EmissionDirection = Enum.NormalId.Top,
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-20, 20),
			Size = NS({ 0, 0.4 }, { 1, 1.7 }),
			Transparency = NS({ 0, 0.6 }, { 0.6, 0.8 }, { 1, 1 }),
			Color = CS(RGB(235, 235, 240)),
			LightEmission = 0.05,
			LightInfluence = 1,
		})
	end
	noticeBoard(m, V(-6.6, 0, 8.3), V(-0.55, 0, 0.83))

	-- LEVEL II: the ground is made sacred: a rope from stone to stone, paper streamers, the banners
	local hang = spec.size.Y * 0.74
	local run = { stones[3] + V(0, hang, 0), stones[1] + V(0, hang - TOP_Y + 0.55, 0), stones[2] + V(0, hang - TOP_Y + 0.55, 0), stones[4] + V(0, hang, 0) }
	for i = 1, 3 do
		rope(L2, "SacredRope", run[i], run[i + 1], if i == 2 then 1.1 else 0.6, 0.3, HEX("D8B56A"), if i == 2 then 12 else 6)
	end
	for _, x in { -2.4, -0.8, 0.8, 2.4 } do
		local sag = 1.1 * 4 * ((x + 4.7) / 9.4) * (1 - (x + 4.7) / 9.4)
		shide(L2, V(x, run[2].Y - sag - 0.1, -4.3 + 0.1), V(0, 0, 1))
	end
	banner(L2, V(7.9, 0, -8.6), V(0, 0, 1), 9.2, HEX("1F3A34"), spec.energy, "霊\n気")
	banner(L2, V(7.9, 0, 3.4), V(-1, 0, 0), 8.4, HEX("F6EFD9"), HEX("1F3A34"), "集\n中")

	-- LEVEL III: spirit lights gather round the dais, the crest in the stone
	crestRing(L3, C + V(0, TOP_Y, 0), 5.2)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2 + 0.5
		-- (none straight in front: the training camera looks up at the trainee from there)
		if math.sin(a) < 0.8 then
			local at = C + V(math.cos(a) * 6.9, 2.6 + (i % 3) * 0.9, math.sin(a) * 6.9)
			local wisp = part(L3, "SpiritLight", V(0.55, 0.55, 0.55), CFrame.new(at), spec.neon, M.Neon)
			wisp.Shape = Enum.PartType.Ball
			wisp.CastShadow = false
			glow(wisp, spec.energy, 7, 0.7)
			emitter(wisp, "Tail", {
				Texture = tex("dot"),
				Rate = 5,
				Lifetime = NumberRange.new(0.6, 1.0),
				Speed = NumberRange.new(0.6, 1.4),
				SpreadAngle = Vector2.new(30, 30),
				EmissionDirection = Enum.NormalId.Top,
				Size = NS({ 0, 0.3 }, { 1, 0 }),
				Color = CS(Color3.new(1, 1, 1), spec.energy),
				LightEmission = 0.45,
			})
		end
	end
	finish(m)

	showModel("Show_orb_T" .. tier, cyl(folder, "Base", 0.4, 8.5, CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)), spec.deck, M.Slate), function(show)
		mesh(show, spec.stone, "Stone", spec.size * 0.8, V(-2.6, 0.4, -0.6), V(0.3, 0, 1))
		mesh(show, spec.stone, "Stone", spec.size * 0.8, V(2.6, 0.4, -0.6), V(-0.3, 0, 1))
		local ball = part(show, "Core", V(2.6, 2.6, 2.6), CFrame.new(0, 4.4, 0.4), spec.neon, M.Neon)
		ball.Shape = Enum.PartType.Ball
		local halo = part(show, "Shell", V(3.1, 3.1, 3.1), CFrame.new(0, 4.4, 0.4), spec.energy, M.Neon)
		halo.Shape = Enum.PartType.Ball
		halo.Transparency = 0.72
	end)
end

for tier = 1, 3 do
	buildPost(tier)
end
for tier = 4, 6 do
	buildFalls(tier)
end
for tier = 7, 9 do
	buildBoulder(tier)
end
for tier = 10, 12 do
	buildPeak(tier)
end
for tier = 13, 15 do
	buildGravity(tier)
end
for tier = 16, 19 do
	buildOrb(tier)
end

-- the eight old gear models are kept, out of the game (plan 13 section 7)
local gear = RS.Assets:FindFirstChild("Gear")
if gear then
	local archive = SS:FindFirstChild("MapArchive") or Instance.new("Folder")
	archive.Name = "MapArchive"
	archive.Parent = SS
	gear.Name = "Gear_v1"
	gear.Parent = archive
	table.insert(out, "Assets.Gear archived as MapArchive.Gear_v1")
end
return table.concat(out, "\n")
