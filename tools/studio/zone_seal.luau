-- zone_seal.luau (rerunnable, Studio edit mode): the SEAL that closes a zone gate the player has not opened.
--
--   python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --dm Edit --file tools/studio/zone_seal.luau
--
-- Builds the template ReplicatedStorage.Assets.World.ZoneSeal. Nothing is placed in the map: the lane is one
-- for all five players and each has their own rebirth, and the first sealed gate is past the streaming
-- radius from the throw stage, so every CLIENT clones this once, onto the first gate it cannot pass
-- (src/client/Controllers/SealController.luau) and moves it on when the player rebirths.
--
-- The look is the finale's Sealed Gate (tools/studio/finale.luau), sized to a zone torii's opening
-- (pillars' inner faces at x +-79, the lane floor to the tie beam: 156 x 125): a violet veil, two iron
-- chains in an X bolted to the corners, the seal's rings of gold and violet light with the kanji for
-- "seal" at its heart, and a banner under it whose text the client writes ("REBIRTH 3 TO ENTER").
--
-- The model's pivot (its Root part) is the middle of the opening on the lane floor; it faces -Z, the throw
-- stage.
local RS = game:GetService("ReplicatedStorage")

local W, H = 156, 125 -- the opening
local DOOR = Color3.fromRGB(32, 26, 42)
local GOLD = Color3.fromRGB(255, 196, 64)
local GOLD_GLOW = Color3.fromRGB(255, 214, 110)
local VIOLET = Color3.fromRGB(170, 90, 255)
local DEEP = Color3.fromRGB(46, 20, 70)
local CHAIN = Color3.fromRGB(78, 76, 88)

local assets = RS:WaitForChild("Assets")
local world = assets:FindFirstChild("World")
if not world then
	world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = assets
end
local old = world:FindFirstChild("ZoneSeal")
if old then
	old:Destroy()
end

local seal = Instance.new("Model")
seal.Name = "ZoneSeal"

local function part(
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
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
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = seal
	return p
end
-- a disc facing -Z: a cylinder whose axis runs along Z
local function disc(
	name: string,
	d: number,
	thick: number,
	at: Vector3,
	color: Color3,
	material: Enum.Material?
): BasePart
	local p = part(
		name,
		Vector3.new(thick, d, d),
		CFrame.new(at) * CFrame.Angles(0, math.rad(90), 0),
		color,
		material
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function words(p: BasePart, text: string, color: Color3, short: number): TextLabel
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 100 / short -- a scaled label stops growing at 100 px
	g.LightInfluence = 0
	g.Parent = p
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = color
	t.Parent = g
	return t
end

local root = part("Root", Vector3.new(1, 1, 1), CFrame.new(0, 0, 0), DOOR)
root.Transparency = 1
seal.PrimaryPart = root

-- the veil: the opening filled with faint violet light
local veil =
	part("Veil", Vector3.new(W, H, 0.6), CFrame.new(0, H / 2, 0), VIOLET, Enum.Material.Neon)
veil.Transparency = 0.84

-- the chains, an X bolted to the four corners
do
	local z = -1.2
	local tl, tr = Vector3.new(-W / 2 + 5, H - 6, z), Vector3.new(W / 2 - 5, H - 6, z)
	local bl, br = Vector3.new(-W / 2 + 5, 7, z), Vector3.new(W / 2 - 5, 7, z)
	local function chain(a: Vector3, b: Vector3)
		local dir = (b - a).Unit
		local len = (b - a).Magnitude
		local i = 0
		for d = 0, len, 7.8 do
			local p = a + dir * d
			local cf = CFrame.lookAt(p, p + dir)
				* CFrame.Angles(0, 0, if i % 2 == 0 then 0 else math.rad(90))
			part("ChainLink", Vector3.new(4.2, 1.9, 9.4), cf, CHAIN, Enum.Material.Metal)
			i += 1
		end
	end
	chain(tl, br)
	chain(tr, bl)
	for _, p in { tl, tr, bl, br } do
		disc("ChainBolt", 11, 2, p + Vector3.new(0, 0, -0.6), GOLD, Enum.Material.Metal)
	end
end

-- the seal: rings of gold and violet light, twelve marks, the kanji at its heart
local SEAL = Vector3.new(0, H / 2 + 4, -2.4)
for _, r in
	{
		{ 80, 0.4, GOLD_GLOW, Enum.Material.Neon },
		{ 75, 0.6, DOOR, Enum.Material.SmoothPlastic },
		{ 68, 0.8, VIOLET, Enum.Material.Neon },
		{ 62, 1.0, DOOR, Enum.Material.SmoothPlastic },
		{ 42, 1.2, GOLD_GLOW, Enum.Material.Neon },
		{ 37, 1.4, DEEP, Enum.Material.SmoothPlastic },
	}
do
	disc("Seal", r[1], r[2], SEAL - Vector3.new(0, 0, r[2] / 2), r[3], r[4])
end
for i = 0, 11 do
	local a = math.rad(i * 30 + 15)
	local p = SEAL + Vector3.new(math.cos(a) * 26, math.sin(a) * 26, -1.1)
	part(
		"SealMark",
		Vector3.new(4, 4, 0.4),
		CFrame.new(p) * CFrame.Angles(0, 0, a + math.rad(45)),
		GOLD_GLOW,
		Enum.Material.Neon
	)
end
do
	-- (a part's Front face looks down -Z: at the throw stage)
	local face =
		part("SealFace", Vector3.new(31, 31, 0.2), CFrame.new(SEAL - Vector3.new(0, 0, 1.6)), DOOR)
	face.Transparency = 1
	local t = words(face, "封", GOLD_GLOW, 31)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(120, 40, 200)
	stroke.Thickness = 4
	stroke.Parent = t
	local glow = Instance.new("PointLight")
	glow.Color = VIOLET
	glow.Range = 60
	glow.Brightness = 2
	glow.Shadows = false
	glow.Parent = face
end

-- the banner under the seal: the client writes what opens it
do
	local Y, Z = 18, -2.6
	part("BannerRim", Vector3.new(104, 20, 1), CFrame.new(0, Y, Z + 0.3), GOLD, Enum.Material.Metal)
	local banner = part("Banner", Vector3.new(100, 16, 1), CFrame.new(0, Y, Z), DOOR)
	local t = words(banner, "REBIRTH 1 TO ENTER", GOLD_GLOW, 16)
	t.Name = "SealText"
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.12, 0)
	pad.PaddingBottom = UDim.new(0.12, 0)
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.Parent = t
end

seal:SetAttribute("Opening", Vector2.new(W, H))
seal.Parent = world
return `ZoneSeal built: {#seal:GetDescendants()} instances in ReplicatedStorage.Assets.World`
