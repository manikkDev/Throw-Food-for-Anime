-- build_grounds.luau - Studio EDIT mode, rerunnable. (Plan 13 phase D.)
-- Builds the set pieces of the training grounds into ReplicatedStorage.Assets.Grounds:
--   Ground_post_T1..T3    Striking Post   (left court):  Wooden Post, Banded Post, Iron Post
--   Ground_falls_T4..T5   Waterfall Focus (right court): Mountain Falls, Shrine Falls
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
	local tall = tier == 5

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

for tier = 1, 3 do
	buildPost(tier)
end
for tier = 4, 5 do
	buildFalls(tier)
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
