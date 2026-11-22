-- finale.luau - Studio EDIT mode, safe to run again. The end of the lane: THE SEALED GATE.
--
-- Owner (2026-11-22): "work on the end of the lane ... in an advanced and professional anime based
-- way". The reference game has no ending (its lane just grows a zone or two each update and fades
-- into haze), so ours is a destination and a promise of more:
--   * a sando over the water: a torii, then a stone pier lined with lanterns from the lane's end
--     to the gate, two guardian dragons (zone 17's) on stone plinths either side of it
--   * the gate, set into the lane's end wall (lane_border.luau leaves x -70..70 open for it): two
--     keeps like the border's, lacquered black doors with gold studs and frames, chained shut in an
--     X behind a glowing seal (rings of gold and violet light, the kanji for "seal" at its heart)
--   * over the doors, under the gate's tile roof, an anime "TO BE CONTINUED" arrow banner: the
--     next worlds are sealed for now (new zones land here)
--   * the end wall in two storeys (top ~106) with banners, tall corner towers and gate keeps
--   * behind the gate a pillar of light: core and sheaths, a ray burst on the water, halo rings,
--     rising sparks, and the hub's golden wish dragon coiled round it
-- The old finale props are archived once in ServerStorage.MapArchive.Finale_v1 (never delete).
-- Run lane_border.luau first (it lays the bay's water and leaves the gap), then this.
-- Run: python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file <this file>
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local scenery = workspace.Map.Scenery
local KIT = RS.Assets.Kit
local STORE = SS.StoreAssets
local KEEP = STORE.Zone01_Naruto.GateTowerMesh
local DRAGON = STORE.Zone17_DragonBall.Dragon

local STONE = Color3.fromRGB(186, 170, 150)
local STONE_DARK = Color3.fromRGB(140, 126, 112)
local PIER = Color3.fromRGB(206, 196, 180)
local RED = Color3.fromRGB(214, 52, 40)
local ROOF = Color3.fromRGB(196, 84, 58)
local ROOF_DARK = Color3.fromRGB(142, 56, 44)
local PLASTER = Color3.fromRGB(246, 234, 204)
local WOOD_DARK = Color3.fromRGB(74, 50, 38)
local DOOR = Color3.fromRGB(32, 26, 42)
local GOLD = Color3.fromRGB(255, 196, 64)
local GOLD_GLOW = Color3.fromRGB(255, 214, 110)
local VIOLET = Color3.fromRGB(170, 90, 255)
local CHAIN = Color3.fromRGB(78, 76, 88)

local WATER = -49.5 -- the bay's water (zone 17's level)
local DECK = -47.6 -- the pier's top: level with the lane's floor
local LANE_END = 6280
local WALL_Z0, WALL_Z1 = 6380, 6394 -- the end wall
local DOOR_Z = 6378 -- the doors' middle (their front at 6376)
local DOOR_TOP = 62
local GATE_X = 64 -- the doors' half width; the keeps stand outside it

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	solid: boolean?
): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = solid == true
	p.CanQuery = solid == true
	p.CanTouch = false
	p.CastShadow = size.Magnitude > 10
	p.Parent = parent
	return p
end
-- a disc facing -Z (towards the lane): a cylinder whose axis runs along Z
local function disc(
	parent: Instance,
	name: string,
	d: number,
	thick: number,
	at: Vector3,
	color: Color3,
	material: Enum.Material?
): BasePart
	local p = part(
		parent,
		name,
		Vector3.new(thick, d, d),
		CFrame.new(at) * CFrame.Angles(0, math.rad(90), 0),
		color,
		material
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end
-- a cylinder standing up
local function column(
	parent: Instance,
	name: string,
	d: number,
	h: number,
	at: Vector3,
	color: Color3,
	material: Enum.Material?
): BasePart
	local p = part(
		parent,
		name,
		Vector3.new(h, d, d),
		CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function gable(parent: Instance, at: CFrame, length: number, half: number, height: number)
	for _, s in { -1, 1 } do
		local w = Instance.new("WedgePart")
		w.Name = "Roof"
		w.Size = Vector3.new(length, height, half)
		w.CFrame = at
			* CFrame.new(0, height / 2, s * half / 2)
			* (if s > 0 then CFrame.Angles(0, math.pi, 0) else CFrame.new())
		w.Color = ROOF
		w.Material = Enum.Material.ClayRoofTiles
		w.Anchored = true
		w.CanCollide = false
		w.CanQuery = false
		w.CanTouch = false
		w.Parent = parent
	end
	part(
		parent,
		"Ridge",
		Vector3.new(length + 1.5, 1.8, 2.4),
		at * CFrame.new(0, height + 0.4, 0),
		ROOF_DARK,
		Enum.Material.Wood
	)
	part(
		parent,
		"Eave",
		Vector3.new(length + 2, 1.4, half * 2 + 3),
		at * CFrame.new(0, -0.7, 0),
		ROOF_DARK,
		Enum.Material.Wood
	)
end
local function place(parent: Instance, template: Instance, scale: number, cf: CFrame): Model
	local m = template:Clone() :: Model
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	if scale ~= 1 then
		m:ScaleTo(m:GetScale() * scale)
	end
	m:PivotTo(cf)
	if not template:GetAttribute("TrueSize") then
		-- a template whose pivot is not at its feet: stand it on cf
		local box, size = m:GetBoundingBox()
		local lift = cf.Position.Y - (box.Position.Y - size.Y / 2)
		if math.abs(lift) > 1 then
			m:PivotTo(m:GetPivot() + Vector3.new(0, lift, 0))
		end
	end
	m.Parent = parent
	return m
end
local function words(
	p: BasePart,
	face: Enum.NormalId,
	text: string,
	color: Color3,
	font: Enum.Font,
	short: number,
	glow: boolean?
)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 100 / short -- a scaled label stops growing at 100 px
	g.LightInfluence = if glow then 0 else 0.7
	g.Parent = p
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = font
	t.TextColor3 = color
	t.Parent = g
	return t
end

-- ---------------------------------------------------------------------------------- the old finale
local archive = SS:FindFirstChild("MapArchive")
if not archive then
	archive = Instance.new("Folder")
	archive.Name = "MapArchive"
	archive.Parent = SS
end
local finale = scenery:FindFirstChild("Finale")
if finale and not archive:FindFirstChild("Finale_v1") then
	local old = finale:Clone()
	old.Name = "Finale_v1"
	old:SetAttribute("Note", "The lane's end props before finale.luau (2026-11-22). Never delete.")
	old.Parent = archive
end
if finale then
	finale:Destroy()
end
finale = Instance.new("Folder")
finale.Name = "Finale"
finale:SetAttribute("Theme", "The Sealed Gate, tools/studio/finale.luau")

-- ---------------------------------------------------------------------------------- 1. the sando
local sando = Instance.new("Folder")
sando.Name = "Sando"
sando.Parent = finale
local PIER_X = 22
local pierZ0, pierZ1 = LANE_END - 2, DOOR_Z - 4
part(
	sando,
	"Deck",
	Vector3.new(PIER_X * 2, 3, pierZ1 - pierZ0),
	CFrame.new(0, DECK - 1.5, (pierZ0 + pierZ1) / 2),
	PIER,
	Enum.Material.Slate,
	true
)
for _, s in { -1, 1 } do
	part(
		sando,
		"Kerb",
		Vector3.new(2.4, 1.6, pierZ1 - pierZ0),
		CFrame.new(s * (PIER_X - 1.2), DECK + 0.8, (pierZ0 + pierZ1) / 2),
		STONE_DARK,
		Enum.Material.Slate,
		true
	)
	-- posts down into the water
	for z = pierZ0 + 8, pierZ1 - 4, 16 do
		column(
			sando,
			"Post",
			3,
			12,
			Vector3.new(s * (PIER_X - 3), DECK - 8, z),
			WOOD_DARK,
			Enum.Material.Wood
		)
	end
	-- stone lanterns along both sides, glowing
	for z = pierZ0 + 22, pierZ1 - 14, 20 do
		local l =
			place(sando, KIT.Prop_store_StoneLantern, 1.7, CFrame.new(s * (PIER_X - 5), DECK, z))
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 190, 120)
		light.Range = 14
		light.Brightness = 1.2
		light.Parent = l:FindFirstChildWhichIsA("BasePart", true)
	end
end
-- a torii at the pier's head (the zones' own, cloned from the last zone's gate and scaled down)
do
	local last
	for _, d in workspace.Map.Lanes:GetDescendants() do
		if d.Name == "Torii" and d:IsA("Model") then
			if not last or d:GetPivot().Position.Z > last:GetPivot().Position.Z then
				last = d
			end
		end
	end
	if last then
		local t = last:Clone() :: Model
		-- no sign on this one: it marks the path, the gate says the rest
		for _, d in t:GetDescendants() do
			if
				d.Name == "Accent"
				or d.Name == "Plaque"
				or d.Name == "PlaqueRim"
				or d.Name == "PlaqueCap"
				or d.Name == "Stud"
				or d.Name == "Gakuzuka"
				or d.Name:match("^Lion")
				or d.Name == "Komainu"
			then
				d:Destroy()
			end
		end
		local _, size = t:GetBoundingBox()
		-- scaled to the pier from the zone gates' torii (pillars at x +-115)
		t:ScaleTo(t:GetScale() * ((PIER_X * 2 + 18) / (115 * 2 + 16)))
		local box, s2 = t:GetBoundingBox()
		t:PivotTo(
			t:GetPivot()
				+ Vector3.new(
					-box.Position.X,
					DECK - (box.Position.Y - s2.Y / 2),
					pierZ0 + 8 - box.Position.Z
				)
		)
		t.Name = "PierTorii"
		t.Parent = sando
		local _ = size
	end
end

-- ---------------------------------------------------------------------------------- 2. the guardians
for _, s in { -1, 1 } do
	local x, z = s * 64, 6326
	column(finale, "DragonPlinth", 38, 18, Vector3.new(x, WATER - 4, z), STONE, Enum.Material.Slate)
	column(
		finale,
		"DragonPlinthCap",
		40,
		1.6,
		Vector3.new(x, WATER + 5.8, z),
		STONE_DARK,
		Enum.Material.Slate
	)
	column(finale, "DragonPlinthBand", 39, 1, Vector3.new(x, WATER + 1.5, z), GOLD)
	-- front to the lane (-Z), turned a little in towards the pier
	local d = place(
		finale,
		DRAGON,
		1.75,
		CFrame.new(x, WATER + 6.4, z) * CFrame.Angles(0, math.rad(-s * 14), 0)
	)
	d.Name = "GuardianDragon"
end

-- ---------------------------------------------------------------------------------- 3. the end wall
-- Two storeys like a castle's long gate-house: a stone foot from the water, a plaster storey with
-- posts and dark windows under a tile roof, a second storey set back under its own roof (top
-- about y 106, twice the border's), tall red banners on the stonework, and a tower at each corner.
local FACE_Z = 6380 -- the end wall's front face
local KEEP_HALF = 20 -- the gate keeps' and corner towers' feet are 40 wide
local CORNER_X = 213 -- on the slim border (x +-206..220; 313 on the old line, 373 with five tracks)
local TOWER_TOP = 122
local wallF = Instance.new("Model")
wallF.Name = "EndWall"
wallF.Parent = finale
local function storeyWall(x0: number, x1: number)
	local len, cx = x1 - x0, (x0 + x1) / 2
	part(
		wallF,
		"Foot",
		Vector3.new(len, 44 + 66, 16),
		CFrame.new(cx, (44 - 66) / 2, FACE_Z + 8),
		STONE,
		Enum.Material.Brick,
		true
	)
	part(
		wallF,
		"FootBand",
		Vector3.new(len, 3, 18),
		CFrame.new(cx, 45.5, FACE_Z + 8),
		STONE_DARK,
		Enum.Material.Slate,
		true
	)
	-- storey 1
	part(
		wallF,
		"Storey1",
		Vector3.new(len, 23, 12),
		CFrame.new(cx, 47 + 11.5, FACE_Z + 9),
		PLASTER,
		Enum.Material.Plaster,
		true
	)
	local n = math.max(1, math.floor(len / 22))
	for i = 0, n do
		local x = x0 + 1.5 + i * (len - 3) / n
		part(
			wallF,
			"Post",
			Vector3.new(2.2, 23, 12.6),
			CFrame.new(x, 58.5, FACE_Z + 9),
			WOOD_DARK,
			Enum.Material.Wood
		)
		if i < n then
			-- a lattice window between each pair of posts
			local wx = x + (len - 3) / n / 2
			part(
				wallF,
				"Window",
				Vector3.new(7, 5, 12.8),
				CFrame.new(wx, 60, FACE_Z + 9),
				Color3.fromRGB(40, 30, 28),
				Enum.Material.Wood
			)
			for k = -1, 1 do
				part(
					wallF,
					"Lattice",
					Vector3.new(0.6, 5, 13),
					CFrame.new(wx + k * 2.2, 60, FACE_Z + 9),
					WOOD_DARK,
					Enum.Material.Wood
				)
			end
		end
	end
	gable(wallF, CFrame.new(cx, 70.7, FACE_Z + 9), len, 10, 7)
	-- storey 2, set back
	part(
		wallF,
		"Storey2",
		Vector3.new(len, 18, 8),
		CFrame.new(cx, 78 + 9, FACE_Z + 11),
		PLASTER,
		Enum.Material.Plaster,
		true
	)
	for i = 0, n do
		part(
			wallF,
			"Post",
			Vector3.new(2, 18, 8.6),
			CFrame.new(x0 + 1.5 + i * (len - 3) / n, 87, FACE_Z + 11),
			WOOD_DARK,
			Enum.Material.Wood
		)
	end
	gable(wallF, CFrame.new(cx, 96.7, FACE_Z + 11), len, 7, 8)
end
local GATE_KEEP_X = GATE_X + KEEP_HALF -- 84
for _, s in { -1, 1 } do
	local a, b = s * (GATE_KEEP_X + KEEP_HALF), s * (CORNER_X - KEEP_HALF)
	storeyWall(math.min(a, b), math.max(a, b))
	-- banners on the stonework: red cloth, a gold dragon kanji
	for bx = 128, CORNER_X - KEEP_HALF - 12, 32 do
		local cloth = part(
			wallF,
			"Banner",
			Vector3.new(11, 32, 0.4),
			CFrame.new(s * bx, 18, FACE_Z - 0.4),
			RED,
			Enum.Material.Fabric
		)
		part(
			wallF,
			"BannerRod",
			Vector3.new(15, 1, 1),
			CFrame.new(s * bx, 34.6, FACE_Z - 0.8),
			WOOD_DARK,
			Enum.Material.Wood
		)
		part(
			wallF,
			"BannerHem",
			Vector3.new(11, 1.4, 0.5),
			CFrame.new(s * bx, 2.7, FACE_Z - 0.5),
			GOLD
		)
		local t = words(cloth, Enum.NormalId.Front, "龍", GOLD, Enum.Font.GothamBlack, 11)
		t.Size = UDim2.fromScale(1, 0.4)
		t.Position = UDim2.fromScale(0, 0.12)
	end
end
-- towers: the two corners and the gate's two keeps, all to the same height
local function tower(x: number, name: string, scale: number)
	local m = Instance.new("Model")
	m.Name = name
	part(
		m,
		"TowerFoot",
		Vector3.new(KEEP_HALF * 2, TOWER_TOP + 66, KEEP_HALF * 2),
		CFrame.new(x, (TOWER_TOP - 66) / 2, FACE_Z + 8),
		STONE,
		Enum.Material.Brick,
		true
	)
	for _, y in { 45.5, TOWER_TOP - 1.5 } do
		part(
			m,
			"TowerBand",
			Vector3.new(KEEP_HALF * 2 + 2, 3, KEEP_HALF * 2 + 2),
			CFrame.new(x, y, FACE_Z + 8),
			STONE_DARK,
			Enum.Material.Slate,
			true
		)
	end
	local k = place(m, KEEP, scale, CFrame.new(x, TOWER_TOP, FACE_Z + 8))
	k.Name = "Keep"
	m.Parent = finale
end
for _, s in { -1, 1 } do
	tower(s * CORNER_X, "CornerTower", 1.2)
	tower(s * GATE_KEEP_X, "GateKeep", 1.25)
end

-- ---------------------------------------------------------------------------------- 4. the gate
local gate = Instance.new("Model")
gate.Name = "SealedGate"
gate.Parent = finale
local DOOR_H = DOOR_TOP - WATER
local DOOR_CY = (DOOR_TOP + WATER) / 2
for _, s in { -1, 1 } do
	-- a red pillar in front of each keep, framing the doors
	column(
		gate,
		"GatePillar",
		9,
		DOOR_TOP + 10 - WATER,
		Vector3.new(s * (GATE_X + 4.5), (DOOR_TOP + 10 + WATER) / 2, DOOR_Z - 5),
		RED
	)
	for _, y in { WATER + 3, 20, DOOR_TOP - 4 } do
		column(gate, "PillarRing", 10, 1.8, Vector3.new(s * (GATE_X + 4.5), y, DOOR_Z - 5), GOLD)
	end
	-- the leaf: lacquered black, framed and studded in gold
	local cx = s * GATE_X / 2
	part(
		gate,
		"Door",
		Vector3.new(GATE_X, DOOR_H, 4),
		CFrame.new(cx, DOOR_CY, DOOR_Z),
		DOOR,
		Enum.Material.SmoothPlastic,
		true
	)
	for _, f in
		{
			{ Vector3.new(GATE_X, 2.4, 0.6), Vector3.new(cx, DOOR_TOP - 1.2, 0) },
			{ Vector3.new(GATE_X, 2.4, 0.6), Vector3.new(cx, WATER + 1.2, 0) },
			{ Vector3.new(2.4, DOOR_H, 0.6), Vector3.new(s * (GATE_X - 1.2), DOOR_CY, 0) },
			{ Vector3.new(2.4, DOOR_H, 0.6), Vector3.new(s * 1.2, DOOR_CY, 0) },
			{ Vector3.new(GATE_X, 1.6, 0.6), Vector3.new(cx, DOOR_TOP - 22, 0) },
			{ Vector3.new(GATE_X, 1.6, 0.6), Vector3.new(cx, WATER + 22, 0) },
		}
	do
		part(gate, "DoorFrame", f[1], CFrame.new(f[2].X, f[2].Y, DOOR_Z - 2.2), GOLD)
	end
	for col = 0, 4 do
		for _, y in { DOOR_TOP - 7, DOOR_TOP - 14, WATER + 8, WATER + 15 } do
			disc(
				gate,
				"Stud",
				2.6,
				1,
				Vector3.new(s * (7 + col * ((GATE_X - 14) / 4)), y, DOOR_Z - 2.3),
				GOLD
			)
		end
	end
end
-- lintel, the banner's panel, the gate roof, and an upper storey with its own roof
local GW = (GATE_KEEP_X + KEEP_HALF) * 2 -- across both keeps
part(
	gate,
	"Lintel",
	Vector3.new(GATE_X * 2 + 22, 8, 12),
	CFrame.new(0, DOOR_TOP + 4, DOOR_Z - 1),
	RED,
	Enum.Material.SmoothPlastic,
	true
)
part(
	gate,
	"LintelLine",
	Vector3.new(GATE_X * 2 + 22, 1, 0.4),
	CFrame.new(0, DOOR_TOP + 1.2, DOOR_Z - 7.2),
	GOLD
)
part(
	gate,
	"Panel",
	Vector3.new(GATE_X * 2 + 8, 18, 10),
	CFrame.new(0, DOOR_TOP + 17, DOOR_Z + 1),
	PLASTER,
	Enum.Material.Plaster,
	true
)
for _, x in { -GATE_X - 3, -GATE_X / 2, 0, GATE_X / 2, GATE_X + 3 } do
	part(
		gate,
		"PanelPost",
		Vector3.new(2.4, 18, 10.6),
		CFrame.new(x, DOOR_TOP + 17, DOOR_Z + 1),
		WOOD_DARK,
		Enum.Material.Wood
	)
end
gable(gate, CFrame.new(0, DOOR_TOP + 26.7, DOOR_Z + 1), GATE_X * 2 + 26, 14, 10)
part(
	gate,
	"Upper",
	Vector3.new(GATE_X * 2 - 30, 18, 12),
	CFrame.new(0, DOOR_TOP + 45, DOOR_Z + 4),
	PLASTER,
	Enum.Material.Plaster,
	true
)
for _, x in { -GATE_X + 15, -GATE_X / 3, GATE_X / 3, GATE_X - 15 } do
	part(
		gate,
		"UpperPost",
		Vector3.new(2.4, 18, 12.6),
		CFrame.new(x, DOOR_TOP + 45, DOOR_Z + 4),
		WOOD_DARK,
		Enum.Material.Wood
	)
end
-- a gold disc with the dragon kanji on the upper storey
do
	local emblem = disc(
		gate,
		"Emblem",
		14,
		1,
		Vector3.new(0, DOOR_TOP + 45, DOOR_Z - 2.5),
		GOLD,
		Enum.Material.SmoothPlastic
	)
	local face = part(
		gate,
		"EmblemFace",
		Vector3.new(11, 11, 0.2),
		CFrame.new(0, DOOR_TOP + 45, DOOR_Z - 3.1),
		GOLD
	)
	face.Transparency = 1
	words(face, Enum.NormalId.Front, "龍", Color3.fromRGB(120, 24, 20), Enum.Font.GothamBlack, 11)
	local _ = emblem
end
gable(gate, CFrame.new(0, DOOR_TOP + 54.7, DOOR_Z + 4), GATE_X * 2 - 10, 11, 12)
-- gold finials at the upper ridge's ends
for _, s in { -1, 1 } do
	part(
		gate,
		"Finial",
		Vector3.new(3, 6, 3),
		CFrame.new(s * (GATE_X - 6), DOOR_TOP + 70, DOOR_Z + 4)
			* CFrame.Angles(0, 0, math.rad(s * -20)),
		GOLD
	)
end
local _ = GW

-- the seal: rings of gold and violet light, runes, the kanji for "seal" at its heart
local SEAL = Vector3.new(0, DOOR_CY + 2, DOOR_Z - 2)
for _, r in
	{
		{ 100, 0.4, GOLD_GLOW, Enum.Material.Neon },
		{ 94, 0.6, DOOR, Enum.Material.SmoothPlastic },
		{ 86, 0.8, VIOLET, Enum.Material.Neon },
		{ 79, 1.0, DOOR, Enum.Material.SmoothPlastic },
		{ 52, 1.2, GOLD_GLOW, Enum.Material.Neon },
		{ 47, 1.4, Color3.fromRGB(46, 20, 70), Enum.Material.SmoothPlastic },
	}
do
	disc(gate, "Seal", r[1], r[2], SEAL - Vector3.new(0, 0, r[2] / 2), r[3], r[4])
end
for i = 0, 11 do
	local a = math.rad(i * 30 + 15)
	local p = SEAL + Vector3.new(math.cos(a) * 32.5, math.sin(a) * 32.5, -1.1)
	part(
		gate,
		"SealMark",
		Vector3.new(4.6, 4.6, 0.4),
		CFrame.new(p) * CFrame.Angles(0, 0, a + math.rad(45)),
		GOLD_GLOW,
		Enum.Material.Neon
	)
end
do
	local face = part(
		gate,
		"SealFace",
		Vector3.new(38, 38, 0.2),
		CFrame.new(SEAL - Vector3.new(0, 0, 1.6)),
		DOOR
	)
	face.Transparency = 1
	local t = words(face, Enum.NormalId.Front, "封", GOLD_GLOW, Enum.Font.GothamBlack, 38, true)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(120, 40, 200)
	stroke.Thickness = 4
	stroke.Parent = t
	local glow = Instance.new("PointLight")
	glow.Color = VIOLET
	glow.Range = 60
	glow.Brightness = 2.5
	glow.Parent = face
end
-- the chains, an X across both leaves behind the seal
do
	local function chain(a: Vector3, b: Vector3)
		local dir = (b - a).Unit
		local len = (b - a).Magnitude
		local i = 0
		for d = 0, len, 4.4 do
			local p = a + dir * d
			local cf = CFrame.lookAt(p, p + dir)
				* CFrame.Angles(0, 0, if i % 2 == 0 then 0 else math.rad(90))
			part(gate, "ChainLink", Vector3.new(1.9, 0.9, 5.4), cf, CHAIN, Enum.Material.Metal)
			i += 1
		end
	end
	local z = DOOR_Z - 2.9
	local tl, tr =
		Vector3.new(-GATE_X + 4, DOOR_TOP - 5, z), Vector3.new(GATE_X - 4, DOOR_TOP - 5, z)
	local bl, br = Vector3.new(-GATE_X + 4, WATER + 7, z), Vector3.new(GATE_X - 4, WATER + 7, z)
	chain(tl, br)
	chain(tr, bl)
	for _, p in { tl, tr, bl, br } do
		disc(gate, "ChainBolt", 5.5, 1.2, p + Vector3.new(0, 0, 0.4), GOLD)
	end
end
-- "TO BE CONTINUED": the arrow banner on the panel over the doors
do
	local Y, Z = DOOR_TOP + 17, DOOR_Z - 4.4
	local BODY = Color3.fromRGB(118, 86, 46)
	local W, H, TIP = 116, 13, 16
	local x0 = -(W + TIP) / 2
	local body =
		part(gate, "ToBeContinued", Vector3.new(W, H, 0.8), CFrame.new(x0 + W / 2, Y, Z), BODY)
	part(
		gate,
		"ToBeContinuedEdge",
		Vector3.new(W + 1.2, H + 1.2, 0.6),
		CFrame.new(x0 + W / 2, Y, Z + 0.2),
		Color3.fromRGB(56, 38, 20)
	)
	local t = words(
		body,
		Enum.NormalId.Front,
		"TO BE CONTINUED",
		Color3.fromRGB(252, 236, 186),
		Enum.Font.Bangers,
		H
	)
	t.Size = UDim2.fromScale(0.96, 0.84)
	t.Position = UDim2.fromScale(0.02, 0.08)
	local axis = Vector3.new(x0 + W + TIP / 2, Y, Z)
	for _, flip in { false, true } do
		local w = Instance.new("WedgePart")
		w.Name = "ToBeContinuedTip"
		w.Size = Vector3.new(0.8, H * 0.85, TIP)
		local cf = CFrame.new(axis + Vector3.new(0, H * 0.85 / 2, 0))
			* CFrame.Angles(0, math.rad(-90), 0)
		if flip then
			cf = CFrame.new(axis) * CFrame.Angles(math.pi, 0, 0) * CFrame.new(-axis) * cf
		end
		w.CFrame = cf
		w.Color = BODY
		w.Material = Enum.Material.SmoothPlastic
		w.Anchored = true
		w.CanCollide = false
		w.CanQuery = false
		w.CanTouch = false
		w.Parent = gate
	end
end

-- ---------------------------------------------------------------------------------- 5. the sky
-- A pillar of light behind the gate: a white-hot core in two gold sheaths, a burst of rays on the
-- water at its foot, five tilted halo rings up its length, sparks rising for ever (particles,
-- no script), and the golden wish dragon of the hub coiled round it above the wall.
local SKY = Instance.new("Model")
SKY.Name = "LightPillar"
SKY.Parent = finale
local BZ = 6446 -- the beam's axis, behind the end wall
local HEIGHT = 1400
for _, layer in
	{
		{ 64, Color3.fromRGB(255, 214, 120), 0.94 },
		{ 32, Color3.fromRGB(255, 232, 160), 0.78 },
		{ 11, Color3.fromRGB(255, 252, 236), 0.1 },
	}
do
	local b = column(
		SKY,
		"Beam",
		layer[1],
		HEIGHT,
		Vector3.new(0, -4 + HEIGHT / 2, BZ),
		layer[2],
		Enum.Material.Neon
	)
	b.Transparency = layer[3]
	b.CastShadow = false
end
-- the foot: a glowing pool and rays across the water
do
	local pool =
		disc(SKY, "Pool", 110, 0.4, Vector3.new(0, -3.6, BZ), GOLD_GLOW, Enum.Material.Neon)
	pool.CFrame = CFrame.new(0, -3.6, BZ) * CFrame.Angles(0, 0, math.rad(90))
	pool.Transparency = 0.55
	pool.CastShadow = false
	for i = 0, 15 do
		local a = math.rad(i * 22.5)
		local len = if i % 2 == 0 then 120 else 80
		local ray = part(
			SKY,
			"Ray",
			Vector3.new(len, 0.5, 3),
			CFrame.new(0, -3.3, BZ) * CFrame.Angles(0, a, 0) * CFrame.new(len / 2 + 18, 0, 0),
			GOLD_GLOW,
			Enum.Material.Neon
		)
		ray.Transparency = 0.35
		ray.CastShadow = false
	end
end
-- halo rings, each of 32 short bars, tilted a little this way and that
for i, h in { { 150, 170 }, { 240, 136 }, { 350, 108 }, { 490, 86 }, { 660, 68 } } do
	local y, d = h[1], h[2]
	local tilt = CFrame.Angles(
		math.rad(if i % 2 == 0 then 8 else -8),
		0,
		math.rad(if i % 2 == 0 then -5 else 5)
	)
	local centre = CFrame.new(0, y, BZ) * tilt
	local n = 32
	local seg = math.pi * d / n + 0.6
	for k = 0, n - 1 do
		local a = k * 2 * math.pi / n
		local bar = part(
			SKY,
			"Halo",
			Vector3.new(seg, 2.6, 2.6),
			centre * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -d / 2),
			GOLD_GLOW,
			Enum.Material.Neon
		)
		bar.Transparency = 0.15
		bar.CastShadow = false
	end
end
-- sparks rising up the beam
do
	local emitterPart =
		part(SKY, "SparkSource", Vector3.new(30, 1, 30), CFrame.new(0, -2, BZ), GOLD)
	emitterPart.Transparency = 1
	for _, spec in
		{
			{
				"rbxasset://textures/particles/sparkles_main.dds",
				30,
				NumberRange.new(60, 110),
				NumberSequence.new({
					NumberSequenceKeypoint.new(0, 5),
					NumberSequenceKeypoint.new(1, 1),
				}),
			},
			{
				"rbxasset://textures/particles/sparkles_main.dds",
				6,
				NumberRange.new(25, 45),
				NumberSequence.new({
					NumberSequenceKeypoint.new(0, 14),
					NumberSequenceKeypoint.new(1, 4),
				}),
			},
		}
	do
		local e = Instance.new("ParticleEmitter")
		e.Texture = spec[1]
		e.Rate = spec[2]
		e.Speed = spec[3]
		e.Size = spec[4]
		e.Lifetime = NumberRange.new(7, 11)
		e.EmissionDirection = Enum.NormalId.Top
		e.SpreadAngle = Vector2.new(6, 6)
		e.LightEmission = 1
		e.LightInfluence = 0
		e.Color = ColorSequence.new(Color3.fromRGB(255, 236, 170), Color3.fromRGB(255, 190, 90))
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.8, 0.4),
			NumberSequenceKeypoint.new(1, 1),
		})
		e.Parent = emitterPart
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 220, 150)
	light.Range = 60
	light.Brightness = 3
	light.Parent = emitterPart
end
-- the hub's golden wish dragon, coiled round the beam above the wall, facing the lane
do
	local wish = STORE.HubV2:FindFirstChild("WishDragon")
	if wish then
		local d = place(SKY, wish, 1.8, CFrame.new(0, 114, BZ) * CFrame.Angles(0, math.rad(180), 0))
		d.Name = "WishDragon"
		-- the stored template is Glass (it renders a washed-out white): the hub's is gold lacquer
		for _, p in d:GetDescendants() do
			if p:IsA("BasePart") then
				p.Material = Enum.Material.SmoothPlastic
				p.Color = GOLD
				p.Reflectance = 0.12
			end
		end
		-- centred on the beam, its coil round it (the sheaths are faint enough to leave it gold)
		local box = d:GetBoundingBox()
		d:PivotTo(d:GetPivot() + Vector3.new(-box.Position.X, 0, BZ - box.Position.Z))
	end
end

finale.Parent = scenery
local n = 0
for _, d in finale:GetDescendants() do
	if d:IsA("BasePart") then
		n += 1
	end
end
return string.format("finale: %d parts", n)
