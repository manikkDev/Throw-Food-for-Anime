-- plaza_districts.luau - Studio EDIT mode, safe to run again. The hub plaza's four districts.
--
-- Owner (2026-11-22): the districts' stalls, gifts and boards "look ass"; make them "advanced, flashy
-- and interactive", professionally made, no rushing. Each district is now a set piece with one look:
--   * a lit gateway in place of the plain wooden sign frame: lacquered pillars on black bases, a
--     curved black top beam with gold caps, a framed sign with a glowing border in the district's
--     colour, paper lanterns hanging inside the pillars
--   * RAMEN ALLEY (west, orange): the food cart is a full yatai (wheels, counter, a steaming pot,
--     bowls, noren curtains, a striped awning, a lit FOOD SHOP sign); a noodle shop, a sweet shop, a
--     market stall and vending machines round it; strings of glowing lanterns over the alley
--   * HALL OF LEGENDS (east, violet): a temple hall front at the back, the six hero statues on round
--     lit pedestals with gold name plates, the squad booth as a hero registry with glowing cards
--   * REWARDS (east of centre, gold): the daily chest on a lit altar with a beam of light and coin
--     piles, a stack of wrapped gifts with ribbons and confetti, the hero index as a framed shrine
--     board of glowing cards, dragon-ball pedestals either side
--   * RANKINGS (west of centre, cyan): each leaderboard in a black and gold frame with a crest, a
--     three-step podium with the trophy, a red carpet, searchlights crossing over it
--   * every station's floating title is a coloured pill with an icon
-- Every prompt stays on its anchor (Hub.FoodCart, SellBooth, DailyChest, GiftBox, IndexBoard) and the
-- leaderboard anchors (Hub.BoardYen, BoardCaught, BoardRarest) keep their names, sizes and faces, so
-- MenuController, WorldUiController and LeaderboardService work as before. Movement is all particles
-- and lights: no scripts. What was replaced is archived once in ServerStorage.MapArchive.Plaza_v1.
-- Run: python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file <this file>
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local map = workspace.Map
local hub, hubV2 = map.Hub, map.HubV2
local KIT = RS.Assets.Kit
local STORE = SS.StoreAssets

local G = -1 -- the plaza's ground
local DECK = -0.6 -- a district deck's top
local RED = Color3.fromRGB(214, 52, 40)
local RED_DARK = Color3.fromRGB(150, 34, 28)
local BLACK = Color3.fromRGB(30, 26, 32)
local GOLD = Color3.fromRGB(255, 196, 64)
local GOLD_GLOW = Color3.fromRGB(255, 214, 110)
local STONE = Color3.fromRGB(196, 186, 170)
local STONE_DARK = Color3.fromRGB(110, 102, 96)
local WOOD = Color3.fromRGB(150, 98, 58)
local WOOD_DARK = Color3.fromRGB(84, 54, 36)
local CREAM = Color3.fromRGB(255, 244, 220)
local INK = Color3.fromRGB(28, 24, 44)
local LANTERN = Color3.fromRGB(226, 60, 40)
local ORANGE = Color3.fromRGB(255, 140, 50)
local VIOLET = Color3.fromRGB(160, 100, 255)
local CYAN = Color3.fromRGB(70, 210, 255)
local PINK = Color3.fromRGB(255, 110, 180)

-- ---------------------------------------------------------------------------------- helpers
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
	p.CastShadow = size.Magnitude > 6
	p.Parent = parent
	return p
end
local function neon(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3
): BasePart
	local p = part(parent, name, size, cf, color, Enum.Material.Neon)
	p.CastShadow = false
	return p
end
-- an upright cylinder from y0 to y1
local function column(
	parent: Instance,
	name: string,
	d: number,
	y0: number,
	y1: number,
	x: number,
	z: number,
	color: Color3,
	material: Enum.Material?,
	solid: boolean?
): BasePart
	local p = part(
		parent,
		name,
		Vector3.new(y1 - y0, d, d),
		CFrame.new(x, (y0 + y1) / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material,
		solid
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end
-- a cylinder lying from a to b
local function rod(
	parent: Instance,
	name: string,
	d: number,
	a: Vector3,
	b: Vector3,
	color: Color3,
	material: Enum.Material?
): BasePart
	local p = part(
		parent,
		name,
		Vector3.new((b - a).Magnitude, d, d),
		CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0),
		color,
		material
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function ball(
	parent: Instance,
	name: string,
	d: number,
	at: Vector3,
	color: Color3,
	material: Enum.Material?
): BasePart
	local p = part(parent, name, Vector3.new(d, d, d), CFrame.new(at), color, material)
	p.Shape = Enum.PartType.Ball
	return p
end
local function light(p: Instance, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Parent = p
end
local function emitter(p: Instance, o: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = o.texture or "rbxasset://textures/particles/sparkles_main.dds"
	e.Rate = o.rate or 8
	e.Speed = o.speed or NumberRange.new(2, 5)
	e.Lifetime = o.life or NumberRange.new(1.5, 3)
	e.Size = o.size
		or NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.8),
			NumberSequenceKeypoint.new(1, 0),
		})
	e.EmissionDirection = o.dir or Enum.NormalId.Top
	e.SpreadAngle = o.spread or Vector2.new(15, 15)
	e.LightEmission = o.emission or 1
	e.LightInfluence = 0
	e.Color = o.color or ColorSequence.new(GOLD_GLOW)
	e.Transparency = o.transparency
		or NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(1, 1),
		})
	e.Acceleration = o.accel or Vector3.zero
	e.Rotation = o.rotation or NumberRange.new(0, 0)
	e.RotSpeed = o.rotSpeed or NumberRange.new(0, 0)
	e.Parent = p
	return e
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
	stroke: Color3?,
	glow: boolean?
): TextLabel
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 100 / short -- a scaled label stops growing at 100 px
	g.LightInfluence = if glow then 0 else 0.6
	g.Parent = p
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(0.94, 0.86)
	t.Position = UDim2.fromScale(0.03, 0.07)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = font
	t.TextColor3 = color
	t.Parent = g
	if stroke then
		local s = Instance.new("UIStroke")
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		s.Color = stroke
		s.Thickness = 2
		s.Parent = t
	end
	return t
end
-- a paper lantern (chochin) hanging with its top at `top`
local function chochin(
	parent: Instance,
	x: number,
	top: number,
	z: number,
	body: Color3,
	band: Color3,
	scale: number?
)
	local k = scale or 1
	column(parent, "LanternCap", 2.8 * k, top - 0.7 * k, top, x, z, BLACK)
	local b = column(
		parent,
		"Lantern",
		4 * k,
		top - 5.9 * k,
		top - 0.7 * k,
		x,
		z,
		body,
		Enum.Material.Neon
	)
	b.CastShadow = false
	column(parent, "LanternBand", 4.2 * k, top - 2.4 * k, top - 1.9 * k, x, z, band)
	column(parent, "LanternBand", 4.2 * k, top - 4.7 * k, top - 4.2 * k, x, z, band)
	column(parent, "LanternCap", 2.8 * k, top - 6.6 * k, top - 5.9 * k, x, z, BLACK)
	light(b, Color3.fromRGB(255, 160, 100), 10 * k, 1)
end
-- a string of lanterns sagging from a to b
local function lanternString(
	parent: Instance,
	a: Vector3,
	b: Vector3,
	sag: number,
	every: number,
	colors: { Color3 }
)
	local n = math.max(2, math.floor((b - a).Magnitude / every))
	local function at(t: number): Vector3
		return a:Lerp(b, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
	end
	for i = 0, n - 1 do
		rod(parent, "Cord", 0.25, at(i / n), at((i + 1) / n), BLACK)
	end
	for i = 1, n - 1 do
		local p = at(i / n)
		chochin(parent, p.X, p.Y - 0.2, p.Z, colors[(i - 1) % #colors + 1], GOLD, 0.55)
	end
end
-- a district's gateway, its readable face to +Z (the plaza), its pillars `half` either side of x
local function gateway(
	parent: Instance,
	x: number,
	z: number,
	half: number,
	title: string,
	accent: Color3
)
	local m = Instance.new("Model")
	m.Name = "Gateway"
	local TOP = 30 -- above every stall's own sign and title
	for _, s in { -1, 1 } do
		local px = x + s * half
		column(m, "Base", 4.6, G, G + 2.2, px, z, BLACK, nil, true)
		column(m, "Pillar", 3, G + 2.2, TOP, px, z, RED, nil, true).Reflectance = 0.04
		for _, y in { G + 2.4, TOP - 4.6 } do
			column(m, "PillarRing", 3.5, y, y + 0.6, px, z, GOLD)
		end
		chochin(m, px - s * 4, TOP - 3.4, z, LANTERN, accent, 0.9)
	end
	part(m, "Shimaki", Vector3.new(half * 2 + 6, 1.8, 2.4), CFrame.new(x, TOP - 2.6, z), RED_DARK)
	part(m, "Kasagi", Vector3.new(half * 2 - 2, 2.2, 3.6), CFrame.new(x, TOP + 0.4, z), BLACK)
	for _, s in { -1, 1 } do
		local th = math.rad(9)
		local seg = 7
		local cf = CFrame.new(
			x + s * (half - 1 + seg / 2 * math.cos(th)),
			TOP + 0.4 + seg / 2 * math.sin(th),
			z
		) * CFrame.Angles(0, 0, s * th)
		part(m, "Kasagi", Vector3.new(seg + 0.6, 2.2, 3.6), cf, BLACK)
		part(
			m,
			"KasagiCap",
			Vector3.new(1, 2.4, 3.8),
			cf * CFrame.new(s * (seg / 2 + 0.3), 0, 0),
			GOLD
		)
	end
	-- the sign, hung from the red beam on two gold rods
	local W, H = half * 2 - 14, 6
	for _, s in { -1, 1 } do
		part(
			m,
			"SignRod",
			Vector3.new(0.4, 1.6, 0.4),
			CFrame.new(x + s * (W / 2 - 2), TOP - 4.3, z),
			GOLD
		)
	end
	local SY = TOP - 4.9 - H / 2
	neon(m, "SignGlow", Vector3.new(W + 0.8, H + 0.8, 0.5), CFrame.new(x, SY, z), accent)
	part(m, "SignFrame", Vector3.new(W, H, 0.8), CFrame.new(x, SY, z), BLACK)
	local face = part(
		m,
		"Sign",
		Vector3.new(W - 1, H - 1, 0.9),
		CFrame.new(x, SY, z),
		Color3.fromRGB(44, 30, 30)
	)
	words(face, Enum.NormalId.Back, title, CREAM, Enum.Font.LuckiestGuy, H - 1, accent, true)
	words(face, Enum.NormalId.Front, title, CREAM, Enum.Font.LuckiestGuy, H - 1, accent, true)
	light(face, accent, 18, 1.2)
	m.Parent = parent
	return m
end
-- a station's floating title: a pill in the district's colour with an icon (the label stays "Text")
local function titlePill(
	anchor: BasePart,
	icon: string,
	text: string,
	accent: Color3,
	height: number
)
	local old = anchor:FindFirstChild("Title")
	if old then
		old:Destroy()
	end
	local b = Instance.new("BillboardGui")
	b.Name = "Title"
	b.Size = UDim2.fromScale(15, 3.6)
	b.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	b.MaxDistance = 140
	b.LightInfluence = 0
	b.Parent = anchor
	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.Size = UDim2.fromScale(1, 1)
	pill.BackgroundColor3 = accent
	pill.Parent = b
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = pill
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.fromRGB(255, 255, 255)
	edge.Thickness = 3
	edge.Parent = pill
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 190, 190))
	grad.Rotation = 90
	grad.Parent = pill
	local iconLabel = Instance.new("TextLabel")
	iconLabel.Name = "Icon"
	iconLabel.Size = UDim2.fromScale(0.22, 0.9)
	iconLabel.Position = UDim2.fromScale(0.03, 0.05)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = icon
	iconLabel.TextScaled = true
	iconLabel.Parent = pill
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.Size = UDim2.fromScale(0.72, 0.78)
	t.Position = UDim2.fromScale(0.25, 0.11)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.LuckiestGuy
	t.TextColor3 = Color3.fromRGB(255, 255, 255)
	t.Parent = pill
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Color = INK
	s.Thickness = 2.5
	s.Parent = t
end
-- a round lit dais under a station, its top at DECK + h
local function dais(parent: Instance, x: number, z: number, d: number, h: number, accent: Color3)
	column(parent, "Dais", d, G, DECK + h, x, z, STONE, Enum.Material.Slate, true)
	column(parent, "DaisRim", d + 0.6, DECK + h - 0.35, DECK + h - 0.05, x, z, GOLD)
	local ring = column(
		parent,
		"DaisGlow",
		d - 2,
		DECK + h,
		DECK + h + 0.05,
		x,
		z,
		accent,
		Enum.Material.Neon
	)
	ring.CastShadow = false
	column(
		parent,
		"DaisTop",
		d - 3,
		DECK + h,
		DECK + h + 0.08,
		x,
		z,
		STONE_DARK,
		Enum.Material.Slate
	)
	return DECK + h + 0.08
end
local function moveAnchor(anchor: BasePart, at: Vector3)
	anchor.CFrame = CFrame.new(at) * (anchor.CFrame - anchor.CFrame.Position)
end

-- ---------------------------------------------------------------------------------- the old dressing
local archive = SS:FindFirstChild("MapArchive")
if not archive then
	archive = Instance.new("Folder")
	archive.Name = "MapArchive"
	archive.Parent = SS
end
local old = archive:FindFirstChild("Plaza_v1")
if not old then
	old = Instance.new("Folder")
	old.Name = "Plaza_v1"
	old:SetAttribute(
		"Note",
		"The plaza districts' props, signs and station models before plaza_districts.luau (2026-11-22). Never delete."
	)
	old.Parent = archive
end
local stowed = 0
local function stow(inst: Instance?)
	if inst and inst.Parent ~= old then
		inst.Parent = old
		stowed += 1
	end
end
-- the districts' decks (x0, x1, z0, z1): their loose props go, their statues stay
local DECKS = {
	{ -334, -230, -140, -88 },
	{ 230, 334, -140, -88 },
	{ 66, 154, -146, -98 },
	{ -154, -66, -146, -98 },
}
local KEEP_NAMES = {
	RamenDeck = true,
	RamenDeckRim = true,
	LegendsDeck = true,
	LegendsDeckRim = true,
	RewardsDeck = true,
	RewardsDeckRim = true,
	RewardsStage = true,
	RewardsStageRim = true,
	RankingsDeck = true,
	RankingsDeckRim = true,
	RankingsStage = true,
	RankingsStageRim = true,
}
for _, f in { hub:FindFirstChild("Plaza"), hub:FindFirstChild("Dressing"), hubV2 } do
	if f then
		for _, c in f:GetChildren() do
			local pos = if c:IsA("Model")
				then c:GetPivot().Position
				elseif c:IsA("BasePart") then c.Position
				else nil
			if pos and not KEEP_NAMES[c.Name] and c.Name:sub(1, 7) ~= "Statue_" then
				for _, d in DECKS do
					if pos.X > d[1] and pos.X < d[2] and pos.Z > d[3] and pos.Z < d[4] then
						stow(c)
						break
					end
				end
			end
		end
	end
end
for _, c in hubV2:GetChildren() do
	if c.Name:sub(1, 5) == "Sign_" then
		stow(c)
	end
end
-- the stations' own models (their anchors stay)
for _, pair in
	{
		{ "FoodCart", "Hub_FoodCart" },
		{ "SellBooth", "Hub_SellBooth" },
		{ "DailyChest", "Hub_DailyChest" },
		{ "GiftBox", "Hub_GiftBox" },
		{ "IndexBoard", "Hub_IndexBoard" },
	}
do
	local a = hub:FindFirstChild(pair[1])
	stow(a and a:FindFirstChild(pair[2]))
end
for _, n in { "BoardYen", "BoardCaught", "BoardRarest" } do
	local a = hub:FindFirstChild(n)
	stow(a and a:FindFirstChild("Hub_LeaderboardFrame"))
end

local root = hub:FindFirstChild("Districts")
if root then
	root:Destroy()
end
root = Instance.new("Folder")
root.Name = "Districts"

-- ---------------------------------------------------------------------------------- RAMEN ALLEY
do
	local f = Instance.new("Folder")
	f.Name = "RamenAlley"
	f.Parent = root
	local CX = -282
	gateway(f, CX, -89, 22, "RAMEN ALLEY", ORANGE)
	-- the shops round the back and sides, fronts to the plaza
	place(
		f,
		STORE.Zone10_Chainsaw.NoodleShop,
		1,
		CFrame.new(CX, DECK, -127) * CFrame.Angles(0, math.rad(180), 0)
	)
	place(
		f,
		STORE.Zone14_Bleach.SweetShop,
		1,
		CFrame.new(CX - 33, DECK, -123) * CFrame.Angles(0, math.rad(180), 0)
	)
	place(
		f,
		STORE.Zone06_BlackClover.MarketStall,
		1.1,
		CFrame.new(CX + 31, DECK, -124) * CFrame.Angles(0, math.rad(180), 0)
	)
	place(
		f,
		STORE.Zone10_Chainsaw.VendingRow,
		1,
		CFrame.new(CX + 42, DECK, -135) * CFrame.Angles(0, math.rad(180), 0)
	)
	-- the food cart: a yatai on wheels, centre front, facing the plaza
	local Z = -106
	local yatai = Instance.new("Model")
	yatai.Name = "FoodYatai"
	local W = 18
	part(
		yatai,
		"Body",
		Vector3.new(W, 5, 7),
		CFrame.new(CX, DECK + 3.1, Z),
		WOOD,
		Enum.Material.Wood,
		true
	)
	part(
		yatai,
		"BodyTrim",
		Vector3.new(W + 0.4, 0.6, 7.4),
		CFrame.new(CX, DECK + 0.9, Z),
		WOOD_DARK,
		Enum.Material.Wood
	)
	part(
		yatai,
		"Counter",
		Vector3.new(W + 1.6, 0.6, 8.6),
		CFrame.new(CX, DECK + 5.9, Z + 0.6),
		WOOD_DARK,
		Enum.Material.Wood,
		true
	)
	-- a red apron panel on the front with the food kanji
	local apron =
		part(yatai, "Apron", Vector3.new(W - 3, 3.6, 0.3), CFrame.new(CX, DECK + 3.3, Z + 3.6), RED)
	words(apron, Enum.NormalId.Back, "食", CREAM, Enum.Font.GothamBlack, 3.6, BLACK)
	for _, s in { -1, 1 } do
		rod(
			yatai,
			"Wheel",
			5.4,
			Vector3.new(CX + s * (W / 2 + 0.2), DECK + 2.7, Z),
			Vector3.new(CX + s * (W / 2 + 1.2), DECK + 2.7, Z),
			WOOD_DARK,
			Enum.Material.Wood
		)
		rod(
			yatai,
			"Hub",
			1.6,
			Vector3.new(CX + s * (W / 2 + 1.1), DECK + 2.7, Z),
			Vector3.new(CX + s * (W / 2 + 1.5), DECK + 2.7, Z),
			GOLD
		)
	end
	-- posts and the striped awning, sloping to the front
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			column(
				yatai,
				"Post",
				0.8,
				DECK + 6.2,
				DECK + 14.5 + (if sz < 0 then 1 else 0),
				CX + sx * (W / 2 - 0.6),
				Z + sz * 3.2,
				WOOD_DARK,
				Enum.Material.Wood
			)
		end
	end
	local roofTilt = CFrame.Angles(math.rad(-12), 0, 0)
	local stripes = 9
	for i = 0, stripes - 1 do
		local x = CX - (W + 3) / 2 + (i + 0.5) * (W + 3) / stripes
		part(
			yatai,
			"Awning",
			Vector3.new((W + 3) / stripes, 0.4, 10),
			CFrame.new(x, DECK + 15.4, Z + 0.4) * roofTilt,
			if i % 2 == 0 then RED else CREAM,
			Enum.Material.Fabric
		)
	end
	-- the scalloped valance and the noren curtains under it, front side
	for i = 0, 5 do
		local x = CX - W / 2 + 1.5 + i * (W - 3) / 5
		local noren = part(
			yatai,
			"Noren",
			Vector3.new((W - 3) / 6 - 0.3, 3.4, 0.15),
			CFrame.new(x, DECK + 12.4, Z + 4.4),
			Color3.fromRGB(34, 40, 90),
			Enum.Material.Fabric
		)
		words(
			noren,
			Enum.NormalId.Back,
			({ "ラ", "ー", "メ", "ン", "!", "★" })[i + 1],
			CREAM,
			Enum.Font.GothamBlack,
			(W - 3) / 6 - 0.3
		)
	end
	-- the menu sign on the roof
	local sign = part(
		yatai,
		"MenuSign",
		Vector3.new(13, 3.4, 0.6),
		CFrame.new(CX, DECK + 18.2, Z + 0.4),
		Color3.fromRGB(44, 30, 30)
	)
	neon(
		yatai,
		"MenuGlow",
		Vector3.new(13.8, 4.2, 0.4),
		CFrame.new(CX, DECK + 18.2, Z + 0.3),
		ORANGE
	)
	words(sign, Enum.NormalId.Back, "HOT RAMEN", CREAM, Enum.Font.LuckiestGuy, 3.4, ORANGE, true)
	words(sign, Enum.NormalId.Front, "HOT RAMEN", CREAM, Enum.Font.LuckiestGuy, 3.4, ORANGE, true)
	-- on the counter: a steaming pot, bowls, a soup ladle; lanterns at the roof's front corners
	local pot = column(
		yatai,
		"Pot",
		3.2,
		DECK + 6.2,
		DECK + 8.4,
		CX - 4,
		Z + 0.4,
		Color3.fromRGB(70, 70, 76),
		Enum.Material.Metal
	)
	column(
		yatai,
		"PotRim",
		3.5,
		DECK + 8.2,
		DECK + 8.6,
		CX - 4,
		Z + 0.4,
		Color3.fromRGB(120, 120, 128),
		Enum.Material.Metal
	)
	emitter(pot, {
		texture = "rbxasset://textures/particles/smoke_main.dds",
		rate = 6,
		speed = NumberRange.new(1.5, 3),
		life = NumberRange.new(2, 3.2),
		size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.2),
			NumberSequenceKeypoint.new(1, 3.4),
		}),
		color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
		transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		}),
		emission = 0,
	})
	for i, x in { 1, 4, 7 } do
		column(
			yatai,
			"Bowl",
			2,
			DECK + 6.2,
			DECK + 7.1,
			CX + x,
			Z + 2.4,
			if i == 2 then CREAM else RED
		)
		column(
			yatai,
			"Noodles",
			1.6,
			DECK + 7.0,
			DECK + 7.2,
			CX + x,
			Z + 2.4,
			Color3.fromRGB(250, 220, 140)
		)
	end
	for _, s in { -1, 1 } do
		chochin(yatai, CX + s * (W / 2 + 0.6), DECK + 15.2, Z + 4.6, LANTERN, ORANGE, 0.8)
		-- stools for customers
		column(yatai, "Stool", 2.2, DECK, DECK + 2.6, CX + s * 4, Z + 7.2, RED)
	end
	yatai.Parent = f
	local anchor = hub:FindFirstChild("FoodCart") :: BasePart
	if anchor then
		moveAnchor(anchor, Vector3.new(CX, DECK + 5, Z + 1))
		titlePill(anchor, "🍜", "FOOD SHOP", ORANGE, 17)
		local prompt = anchor:FindFirstChildWhichIsA("ProximityPrompt")
		if prompt then
			prompt.MaxActivationDistance = 14
		end
	end
	-- lantern strings over the alley, from poles at its sides
	for _, z in { -98, -116 } do
		for _, s in { -1, 1 } do
			column(
				f,
				"LanternPole",
				0.9,
				DECK,
				DECK + 20,
				CX + s * 46,
				z,
				WOOD_DARK,
				Enum.Material.Wood
			)
			column(f, "PoleCap", 1.4, DECK + 20, DECK + 20.6, CX + s * 46, z, GOLD)
		end
		lanternString(
			f,
			Vector3.new(CX - 46, DECK + 19.6, z),
			Vector3.new(CX + 46, DECK + 19.6, z),
			5,
			7,
			{ LANTERN, ORANGE, Color3.fromRGB(255, 220, 120) }
		)
	end
end

-- ---------------------------------------------------------------------------------- HALL OF LEGENDS
do
	local f = Instance.new("Folder")
	f.Name = "HallOfLegends"
	f.Parent = root
	local CX = 282
	gateway(f, CX, -89, 22, "HALL OF LEGENDS", VIOLET)
	-- the hall's front at the back of the deck: six red pillars, a black and gold roof, a plaque
	local hall = Instance.new("Model")
	hall.Name = "HallFront"
	local HZ = -146
	part(
		hall,
		"HallBase",
		Vector3.new(76, 2, 10),
		CFrame.new(CX, DECK + 1, HZ),
		STONE,
		Enum.Material.Slate,
		true
	)
	part(
		hall,
		"HallWall",
		Vector3.new(72, 22, 2),
		CFrame.new(CX, DECK + 13, HZ - 3.5),
		Color3.fromRGB(60, 30, 60),
		Enum.Material.Wood,
		true
	)
	for i = 0, 5 do
		local x = CX - 32 + i * 12.8
		column(hall, "HallPillar", 2.6, DECK + 2, DECK + 24, x, HZ + 2, RED)
		column(hall, "HallRing", 3, DECK + 2, DECK + 2.6, x, HZ + 2, GOLD)
		column(hall, "HallRing", 3, DECK + 22, DECK + 22.6, x, HZ + 2, GOLD)
	end
	part(hall, "HallBeam", Vector3.new(76, 2.4, 3), CFrame.new(CX, DECK + 24.6, HZ + 2), RED_DARK)
	part(hall, "HallRoof", Vector3.new(84, 1.6, 14), CFrame.new(CX, DECK + 26.6, HZ), BLACK)
	part(hall, "HallRoofEdge", Vector3.new(84.6, 0.5, 14.6), CFrame.new(CX, DECK + 25.9, HZ), GOLD)
	part(hall, "HallRoof", Vector3.new(70, 1.4, 10), CFrame.new(CX, DECK + 28.2, HZ - 1), BLACK)
	part(hall, "HallRidge", Vector3.new(60, 1.2, 1.6), CFrame.new(CX, DECK + 29.4, HZ - 1), GOLD)
	for _, s in { -1, 1 } do
		part(
			hall,
			"Shachi",
			Vector3.new(1.4, 3.6, 2),
			CFrame.new(CX + s * 30, DECK + 31, HZ - 1) * CFrame.Angles(0, 0, math.rad(s * -15)),
			GOLD
		)
	end
	local plaque = part(
		hall,
		"HallPlaque",
		Vector3.new(26, 5, 0.6),
		CFrame.new(CX, DECK + 20.6, HZ + 3.8),
		BLACK
	)
	neon(
		hall,
		"HallPlaqueGlow",
		Vector3.new(27, 6, 0.4),
		CFrame.new(CX, DECK + 20.6, HZ + 3.6),
		VIOLET
	)
	words(plaque, Enum.NormalId.Back, "英雄殿", GOLD_GLOW, Enum.Font.GothamBlack, 5, BLACK, true)
	-- purple banners between the pillars
	for i = 0, 4 do
		local x = CX - 25.6 + i * 12.8
		local b = part(
			hall,
			"HallBanner",
			Vector3.new(6, 15, 0.3),
			CFrame.new(x, DECK + 12, HZ - 2.2),
			Color3.fromRGB(90, 40, 150),
			Enum.Material.Fabric
		)
		words(b, Enum.NormalId.Back, "★", GOLD_GLOW, Enum.Font.GothamBlack, 6)
		part(
			hall,
			"HallBannerRod",
			Vector3.new(7.4, 0.5, 0.5),
			CFrame.new(x, DECK + 19.6, HZ - 2),
			GOLD
		)
	end
	hall.Parent = f
	-- the six heroes on round lit pedestals with gold name plates: four along the back, two forward
	local SPOTS =
		{ { -36, -124 }, { -12, -128 }, { 12, -128 }, { 36, -124 }, { -40, -104 }, { 40, -104 } }
	local statues = {}
	for _, c in hubV2:GetChildren() do
		if c.Name:sub(1, 7) == "Statue_" then
			table.insert(statues, c)
		end
	end
	table.sort(statues, function(a, b)
		return a.Name < b.Name
	end)
	for i, st in statues do
		local spot = SPOTS[i]
		if not spot then
			break
		end
		local x, z = CX + spot[1], spot[2]
		local top = dais(f, x, z, 10, 3, VIOLET)
		local box, size = st:GetBoundingBox()
		local lift = top - (box.Position.Y - size.Y / 2)
		local rot = st:GetPivot() - st:GetPivot().Position
		st:PivotTo(CFrame.new(x, st:GetPivot().Position.Y + lift, z) * rot)
		local b2 = st:GetBoundingBox()
		st:PivotTo(st:GetPivot() + Vector3.new(x - b2.Position.X, 0, z - b2.Position.Z))
		-- a spotlight from the pedestal's edge, a name plate in front
		local sp = part(
			f,
			"Spot",
			Vector3.new(1, 1, 1),
			CFrame.lookAt(Vector3.new(x, top + 0.5, z + 5.5), Vector3.new(x, top + 6, z)),
			GOLD
		)
		sp.Transparency = 1
		local spot2 = Instance.new("SpotLight")
		spot2.Face = Enum.NormalId.Front
		spot2.Angle = 50
		spot2.Range = 16
		spot2.Brightness = 3
		spot2.Color = Color3.fromRGB(230, 200, 255)
		spot2.Parent = sp
		local name = st.Name:sub(8):gsub("_", " "):upper()
		local plate = part(
			f,
			"NamePlate",
			Vector3.new(8, 1.6, 0.4),
			CFrame.new(x, DECK + 1.9, z + 5.15) * CFrame.Angles(math.rad(-15), 0, 0),
			GOLD
		)
		words(plate, Enum.NormalId.Back, name, INK, Enum.Font.LuckiestGuy, 1.6)
	end
	-- the squad booth: a hero registry, centre front
	local Z = -106
	local booth = Instance.new("Model")
	booth.Name = "HeroRegistry"
	part(
		booth,
		"Counter",
		Vector3.new(16, 4.6, 5),
		CFrame.new(CX, DECK + 2.3, Z),
		BLACK,
		Enum.Material.SmoothPlastic,
		true
	)
	part(booth, "CounterTop", Vector3.new(17, 0.5, 6), CFrame.new(CX, DECK + 4.85, Z), GOLD)
	neon(booth, "CounterGlow", Vector3.new(16.2, 0.4, 5.2), CFrame.new(CX, DECK + 1, Z), VIOLET)
	local front = part(
		booth,
		"CounterFace",
		Vector3.new(12, 2.6, 0.2),
		CFrame.new(CX, DECK + 2.6, Z + 2.6),
		Color3.fromRGB(70, 30, 110)
	)
	words(
		front,
		Enum.NormalId.Back,
		"HERO REGISTRY",
		GOLD_GLOW,
		Enum.Font.LuckiestGuy,
		2.6,
		BLACK,
		true
	)
	-- the back screen: three glowing hero cards in a violet frame
	part(booth, "ScreenFrame", Vector3.new(18, 11, 1), CFrame.new(CX, DECK + 10.6, Z - 3), BLACK)
	neon(
		booth,
		"ScreenGlow",
		Vector3.new(18.8, 11.8, 0.6),
		CFrame.new(CX, DECK + 10.6, Z - 3.3),
		VIOLET
	)
	for i, c in { { -5.6, CYAN, "★" }, { 0, GOLD_GLOW, "★★★" }, { 5.6, PINK, "★★" } } do
		local card = part(
			booth,
			"Card",
			Vector3.new(4.4, 7.2, 0.3),
			CFrame.new(CX + c[1], DECK + 10.6 + (if i == 2 then 0.6 else 0), Z - 2.4),
			Color3.fromRGB(40, 24, 70)
		)
		neon(
			booth,
			"CardEdge",
			Vector3.new(4.9, 7.7, 0.2),
			CFrame.new(CX + c[1], DECK + 10.6 + (if i == 2 then 0.6 else 0), Z - 2.5),
			c[2]
		)
		words(
			card,
			Enum.NormalId.Back,
			"?\n" .. c[3],
			c[2],
			Enum.Font.LuckiestGuy,
			4.4,
			BLACK,
			true
		)
	end
	for _, s in { -1, 1 } do
		column(booth, "BoothPost", 1, DECK + 5, DECK + 17, CX + s * 8.6, Z - 2.6, RED)
	end
	part(booth, "BoothRoof", Vector3.new(21, 1, 6.4), CFrame.new(CX, DECK + 17.4, Z - 1.6), BLACK)
	part(
		booth,
		"BoothRoofEdge",
		Vector3.new(21.4, 0.4, 6.8),
		CFrame.new(CX, DECK + 16.9, Z - 1.6),
		GOLD
	)
	local sign = part(
		booth,
		"BoothSign",
		Vector3.new(13, 3.2, 0.6),
		CFrame.new(CX, DECK + 19.8, Z - 1.6),
		Color3.fromRGB(50, 26, 80)
	)
	neon(
		booth,
		"BoothSignGlow",
		Vector3.new(13.8, 4, 0.4),
		CFrame.new(CX, DECK + 19.8, Z - 1.7),
		VIOLET
	)
	words(sign, Enum.NormalId.Back, "HEROES", CREAM, Enum.Font.LuckiestGuy, 3.2, VIOLET, true)
	words(sign, Enum.NormalId.Front, "HEROES", CREAM, Enum.Font.LuckiestGuy, 3.2, VIOLET, true)
	local sparkle =
		part(booth, "Sparkle", Vector3.new(16, 0.2, 4), CFrame.new(CX, DECK + 5.3, Z), VIOLET)
	sparkle.Transparency = 1
	emitter(sparkle, {
		rate = 6,
		color = ColorSequence.new(VIOLET, GOLD_GLOW),
		speed = NumberRange.new(1, 3),
		size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.6),
			NumberSequenceKeypoint.new(1, 0),
		}),
	})
	light(sparkle, VIOLET, 18, 1.6)
	booth.Parent = f
	local anchor = hub:FindFirstChild("SellBooth") :: BasePart
	if anchor then
		moveAnchor(anchor, Vector3.new(CX, DECK + 5, Z + 1))
		titlePill(anchor, "🛡️", "MY SQUAD", VIOLET, 18)
		local prompt = anchor:FindFirstChildWhichIsA("ProximityPrompt")
		if prompt then
			prompt.MaxActivationDistance = 14
		end
	end
end

-- ---------------------------------------------------------------------------------- REWARDS
do
	local f = Instance.new("Folder")
	f.Name = "Rewards"
	f.Parent = root
	local CX = 110
	gateway(f, CX, -99, 20, "REWARDS", GOLD)
	-- the daily chest on a lit altar, a beam of light, coins
	do
		local x, z = CX - 20, -120
		local top = dais(f, x, z, 16, 2.2, GOLD)
		local chest = place(
			f,
			STORE.Zone03_OnePiece.Chest,
			0.85,
			CFrame.new(x, top, z) * CFrame.Angles(0, math.rad(180), 0)
		)
		chest.Name = "TreasureChest"
		local beam =
			column(f, "ChestBeam", 3, top + 6, top + 40, x, z, GOLD_GLOW, Enum.Material.Neon)
		beam.Transparency = 0.7
		beam.CastShadow = false
		local glow = part(f, "ChestGlow", Vector3.new(8, 0.2, 8), CFrame.new(x, top + 0.3, z), GOLD)
		glow.Transparency = 1
		emitter(glow, {
			rate = 10,
			speed = NumberRange.new(3, 6),
			life = NumberRange.new(2, 3.5),
			color = ColorSequence.new(GOLD_GLOW, Color3.fromRGB(255, 255, 220)),
		})
		light(glow, GOLD_GLOW, 20, 2)
		for i = 0, 5 do
			local a = math.rad(i * 60 + 20)
			local cx, cz = x + math.cos(a) * 6.4, z + math.sin(a) * 6.4
			for k = 0, (i % 3) + 1 do
				column(
					f,
					"Coin",
					1.4,
					top + k * 0.3,
					top + k * 0.3 + 0.25,
					cx + (k % 2) * 0.15,
					cz,
					GOLD,
					Enum.Material.Metal
				)
			end
		end
		local anchor = hub:FindFirstChild("DailyChest") :: BasePart
		if anchor then
			moveAnchor(anchor, Vector3.new(x, top + 2.6, z))
			titlePill(anchor, "🎁", "DAILY CHEST", GOLD, 12)
		end
	end
	-- a stack of wrapped gifts with ribbons, confetti
	do
		local x, z = CX + 20, -120
		local top = dais(f, x, z, 16, 2.2, PINK)
		local function gift(
			cx: number,
			y: number,
			cz: number,
			s: number,
			yaw: number,
			body: Color3,
			ribbon: Color3
		)
			local cf = CFrame.new(cx, y + s / 2, cz) * CFrame.Angles(0, math.rad(yaw), 0)
			part(f, "Gift", Vector3.new(s, s, s), cf, body)
			part(f, "Ribbon", Vector3.new(s + 0.1, s + 0.1, s * 0.16), cf, ribbon)
			part(f, "Ribbon", Vector3.new(s * 0.16, s + 0.1, s + 0.1), cf, ribbon)
			part(
				f,
				"Lid",
				Vector3.new(s + 0.4, s * 0.14, s + 0.4),
				cf * CFrame.new(0, s / 2 - s * 0.05, 0),
				body:Lerp(Color3.new(1, 1, 1), 0.15)
			)
			for _, a in { 45, -45 } do
				part(
					f,
					"Bow",
					Vector3.new(s * 0.5, s * 0.28, s * 0.14),
					cf
						* CFrame.new(0, s / 2 + s * 0.15, 0)
						* CFrame.Angles(0, math.rad(a), math.rad(25)),
					ribbon
				)
				part(
					f,
					"Bow",
					Vector3.new(s * 0.5, s * 0.28, s * 0.14),
					cf
						* CFrame.new(0, s / 2 + s * 0.15, 0)
						* CFrame.Angles(0, math.rad(a + 180), math.rad(25)),
					ribbon
				)
			end
		end
		gift(x - 1, top, z + 0.5, 6.4, 8, PINK, GOLD)
		gift(x - 0.6, top + 7.3, z + 0.2, 4.4, -18, CYAN, Color3.fromRGB(255, 255, 255))
		gift(x + 5.6, top, z + 4, 3.4, 30, GOLD, RED)
		gift(x - 6.2, top, z + 3.6, 3, -25, Color3.fromRGB(120, 230, 140), PINK)
		local beam = column(f, "GiftBeam", 3, top + 14, top + 40, x, z, PINK, Enum.Material.Neon)
		beam.Transparency = 0.72
		beam.CastShadow = false
		local src = part(f, "Confetti", Vector3.new(8, 0.2, 8), CFrame.new(x, top + 13, z), PINK)
		src.Transparency = 1
		emitter(src, {
			texture = "rbxasset://textures/particles/sparkles_main.dds",
			rate = 14,
			speed = NumberRange.new(6, 10),
			life = NumberRange.new(2, 3),
			spread = Vector2.new(50, 50),
			accel = Vector3.new(0, -6, 0),
			color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, PINK),
				ColorSequenceKeypoint.new(0.5, CYAN),
				ColorSequenceKeypoint.new(1, GOLD_GLOW),
			}),
			size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.9),
				NumberSequenceKeypoint.new(1, 0.3),
			}),
			rotSpeed = NumberRange.new(-180, 180),
		})
		light(src, PINK, 18, 1.6)
		local anchor = hub:FindFirstChild("GiftBox") :: BasePart
		if anchor then
			moveAnchor(anchor, Vector3.new(x, top + 2.6, z))
			titlePill(anchor, "🎉", "PLAYTIME GIFTS", PINK, 17)
		end
	end
	-- the hero index: a framed shrine board of glowing cards at the back, a roof over it
	do
		local x, z = CX, -139
		local m = Instance.new("Model")
		m.Name = "IndexShrine"
		part(
			m,
			"IndexBase",
			Vector3.new(24, 2, 5),
			CFrame.new(x, DECK + 1, z - 1),
			STONE,
			Enum.Material.Slate,
			true
		)
		for _, s in { -1, 1 } do
			column(m, "IndexPost", 1.6, DECK + 2, DECK + 19, x + s * 11, z - 1, RED)
			column(m, "IndexPostRing", 2, DECK + 2, DECK + 2.6, x + s * 11, z - 1, GOLD)
		end
		part(m, "IndexBack", Vector3.new(20, 14, 0.8), CFrame.new(x, DECK + 10, z - 1.6), BLACK)
		neon(m, "IndexGlow", Vector3.new(20.8, 14.8, 0.4), CFrame.new(x, DECK + 10, z - 1.9), GOLD)
		local panel = part(
			m,
			"IndexPanel",
			Vector3.new(18.4, 10.4, 0.4),
			CFrame.new(x, DECK + 9.4, z - 1.1),
			Color3.fromRGB(36, 26, 52)
		)
		-- a grid of cards: the collection
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Back
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 20
		g.LightInfluence = 0
		g.Parent = panel
		local grid = Instance.new("Frame")
		grid.Size = UDim2.fromScale(0.94, 0.9)
		grid.Position = UDim2.fromScale(0.03, 0.05)
		grid.BackgroundTransparency = 1
		grid.Parent = g
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.fromScale(0.15, 0.3)
		layout.CellPadding = UDim2.fromScale(0.02, 0.04)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Parent = grid
		local tints = { CYAN, GOLD_GLOW, PINK, VIOLET, Color3.fromRGB(120, 230, 140), ORANGE }
		for i = 1, 18 do
			local cell = Instance.new("TextLabel")
			cell.BackgroundColor3 = Color3.fromRGB(24, 18, 40)
			cell.Text = if i % 4 == 1 then "★" else "?"
			cell.TextScaled = true
			cell.Font = Enum.Font.LuckiestGuy
			cell.TextColor3 = tints[(i - 1) % #tints + 1]
			cell.Parent = grid
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.15, 0)
			corner.Parent = cell
			local edge = Instance.new("UIStroke")
			edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			edge.Color = tints[(i - 1) % #tints + 1]
			edge.Thickness = 3
			edge.Parent = cell
		end
		local title = part(
			m,
			"IndexTitle",
			Vector3.new(14, 2.8, 0.6),
			CFrame.new(x, DECK + 16.4, z - 0.9),
			Color3.fromRGB(44, 30, 30)
		)
		words(
			title,
			Enum.NormalId.Back,
			"HERO INDEX",
			CREAM,
			Enum.Font.LuckiestGuy,
			2.8,
			GOLD,
			true
		)
		part(m, "IndexRoof", Vector3.new(26, 1, 6), CFrame.new(x, DECK + 19.4, z - 1), BLACK)
		part(
			m,
			"IndexRoofEdge",
			Vector3.new(26.4, 0.4, 6.4),
			CFrame.new(x, DECK + 18.9, z - 1),
			GOLD
		)
		part(m, "IndexRidge", Vector3.new(20, 0.8, 1.2), CFrame.new(x, DECK + 20.3, z - 1), GOLD)
		m.Parent = f
		light(panel, GOLD_GLOW, 16, 1)
		local anchor = hub:FindFirstChild("IndexBoard") :: BasePart
		if anchor then
			moveAnchor(anchor, Vector3.new(x, DECK + 5, z + 1))
			titlePill(anchor, "📖", "HERO INDEX", Color3.fromRGB(60, 150, 255), 18)
		end
		-- the seven star balls on pedestals either side
		for _, s in { -1, 1 } do
			place(
				f,
				STORE.Zone17_DragonBall.StarBalls,
				0.7,
				CFrame.new(x + s * 28, DECK, z + 1) * CFrame.Angles(0, math.rad(180), 0)
			)
		end
	end
	-- gold lantern strings over the deck
	for _, s in { -1, 1 } do
		column(
			f,
			"LanternPole",
			0.8,
			DECK,
			DECK + 17,
			CX + s * 41,
			-104,
			WOOD_DARK,
			Enum.Material.Wood
		)
		column(f, "PoleCap", 1.3, DECK + 17, DECK + 17.6, CX + s * 41, -104, GOLD)
	end
	lanternString(
		f,
		Vector3.new(CX - 41, DECK + 16.6, -104),
		Vector3.new(CX + 41, DECK + 16.6, -104),
		4,
		7,
		{ GOLD_GLOW, LANTERN, PINK }
	)
end

-- ---------------------------------------------------------------------------------- RANKINGS
do
	local f = Instance.new("Folder")
	f.Name = "Rankings"
	f.Parent = root
	local CX = -110
	gateway(f, CX, -99, 20, "RANKINGS", CYAN)
	-- each leaderboard in a black and gold frame with a glowing edge and a crest
	for _, b in { { "BoardCaught", "🎯" }, { "BoardYen", "💰" }, { "BoardRarest", "✨" } } do
		local anchor = hub:FindFirstChild(b[1]) :: BasePart
		if anchor then
			-- raised so the podium in front never hides a row
			moveAnchor(anchor, Vector3.new(anchor.Position.X, 13, anchor.Position.Z))
			local p = anchor.Position
			local z = p.Z - 0.7 -- behind the board's face
			part(f, "BoardBack", Vector3.new(13, 17, 1), CFrame.new(p.X, p.Y + 0.6, z), BLACK)
			neon(
				f,
				"BoardGlow",
				Vector3.new(13.8, 17.8, 0.6),
				CFrame.new(p.X, p.Y + 0.6, z - 0.3),
				CYAN
			)
			for _, s in { -1, 1 } do
				part(
					f,
					"BoardSide",
					Vector3.new(0.8, 17, 1.6),
					CFrame.new(p.X + s * 6.3, p.Y + 0.6, z + 0.4),
					GOLD
				)
			end
			part(f, "BoardFoot", Vector3.new(14, 1, 2), CFrame.new(p.X, p.Y - 7.6, z + 0.4), GOLD)
			part(
				f,
				"BoardPlinth",
				Vector3.new(11, p.Y - 8.1 - G, 3.6),
				CFrame.new(p.X, (p.Y - 8.1 + G) / 2, z),
				STONE,
				Enum.Material.Slate,
				true
			)
			for _, s in { -1, 1 } do
				part(
					f,
					"PlinthBand",
					Vector3.new(11.4, 0.4, 4),
					CFrame.new(p.X, G + 1.4 + (s + 1) * 1.6, z),
					GOLD
				)
			end
			-- the crest: a gold disc with the board's icon, and a small roof (the middle board's crest
			-- sits under the trophy)
			if b[1] ~= "BoardYen" then
				local crest = column(f, "Crest", 5, z - 0.4, z + 0.4, p.X, 0, GOLD)
				crest.CFrame = CFrame.new(p.X, p.Y + 10.8, z + 0.2)
					* CFrame.Angles(0, math.rad(90), 0)
				local face = part(
					f,
					"CrestFace",
					Vector3.new(4, 4, 0.2),
					CFrame.new(p.X, p.Y + 10.8, z + 0.75),
					GOLD
				)
				face.Transparency = 1
				words(face, Enum.NormalId.Back, b[2], Color3.new(1, 1, 1), Enum.Font.GothamBlack, 4)
			end
			part(
				f,
				"BoardRoof",
				Vector3.new(15, 0.8, 3.4),
				CFrame.new(p.X, p.Y + 9.4, z + 0.6),
				BLACK
			)
			part(
				f,
				"BoardRoofEdge",
				Vector3.new(15.4, 0.3, 3.8),
				CFrame.new(p.X, p.Y + 9, z + 0.6),
				GOLD
			)
		end
	end
	-- the podium: 1st in the middle with the trophy, 2nd and 3rd either side
	local PZ = -118
	for _, step in
		{
			{ 0, 2.8, "1", GOLD },
			{ -9, 2, "2", Color3.fromRGB(210, 214, 226) },
			{ 9, 1.4, "3", Color3.fromRGB(214, 140, 80) },
		}
	do
		local x = CX + step[1]
		part(
			f,
			"Podium",
			Vector3.new(8.6, step[2], 7),
			CFrame.new(x, DECK + step[2] / 2, PZ),
			Color3.fromRGB(245, 242, 236),
			Enum.Material.SmoothPlastic,
			true
		)
		part(
			f,
			"PodiumTop",
			Vector3.new(9, 0.4, 7.4),
			CFrame.new(x, DECK + step[2] + 0.2, PZ),
			step[4]
		)
		local num = part(
			f,
			"PodiumFace",
			Vector3.new(3, step[2] - 0.4, 0.2),
			CFrame.new(x, DECK + step[2] / 2, PZ + 3.55),
			step[4]
		)
		words(num, Enum.NormalId.Back, step[3], INK, Enum.Font.LuckiestGuy, step[2] - 0.4)
	end
	-- the trophy crowns the middle board's frame
	local mid = hub:FindFirstChild("BoardYen") :: BasePart
	local TY = (if mid then mid.Position.Y else 13) + 10.6
	local trophy = place(
		f,
		STORE.Zone05_BlueLock.Trophy,
		0.36,
		CFrame.new(CX, TY, -138.4) * CFrame.Angles(0, math.rad(180), 0)
	)
	trophy.Name = "Trophy"
	local shine =
		part(f, "TrophyShine", Vector3.new(4, 0.2, 4), CFrame.new(CX, TY + 6, -138.4), GOLD)
	shine.Transparency = 1
	emitter(shine, {
		rate = 8,
		speed = NumberRange.new(1, 3),
		color = ColorSequence.new(GOLD_GLOW, Color3.new(1, 1, 1)),
		spread = Vector2.new(60, 60),
	})
	light(shine, GOLD_GLOW, 16, 1.8)
	-- a red carpet from the gateway to the podium, gold edged
	part(
		f,
		"Carpet",
		Vector3.new(8, 0.15, 19),
		CFrame.new(CX, DECK + 0.08, (-100 + PZ + 3.5) / 2),
		RED_DARK,
		Enum.Material.Fabric
	)
	for _, s in { -1, 1 } do
		part(
			f,
			"CarpetEdge",
			Vector3.new(0.4, 0.17, 19),
			CFrame.new(CX + s * 4.1, DECK + 0.09, (-100 + PZ + 3.5) / 2),
			GOLD
		)
		-- searchlights at the deck's front corners, beams crossing over the podium
		local base = Vector3.new(CX + s * 38, DECK, -104)
		part(
			f,
			"SearchlightBase",
			Vector3.new(3, 2, 3),
			CFrame.new(base + Vector3.new(0, 1, 0)),
			BLACK,
			nil,
			true
		)
		local tip = Vector3.new(CX - s * 22, 70, -150)
		local from = base + Vector3.new(0, 2.2, 0)
		local beam = rod(f, "SearchBeam", 2.6, from, tip, CYAN, Enum.Material.Neon)
		beam.Transparency = 0.78
		beam.CastShadow = false
		ball(f, "SearchLamp", 2.4, from, Color3.fromRGB(220, 250, 255), Enum.Material.Neon)
	end
end

root.Parent = hub
local n = 0
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") then
		n += 1
	end
end
return string.format("districts: %d parts, %d old things archived", n, stowed)
