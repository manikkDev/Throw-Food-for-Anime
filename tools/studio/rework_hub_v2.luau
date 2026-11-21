-- rework_hub_v2.luau - Studio EDIT mode. Rebuilds Workspace.MapV2 as a COPY of the live hub
-- (Workspace.Map, never touched) 3,000 studs east, then reworks the copy with the hub's own assets
-- (design/plan/09-single-lane-rework.md, owner's brief 2026-11-21: keep the hub's spacing, organise it).
--
--   1 five bases, re-centred on the same 108 pitch          4 food cart and sell booth at every throw pad
--   2 bases hold heroes only (6 rows of 7 pedestals)        5 the plaza in districts, fillers grouped
--   3 training courts move to the lawns in front            6 the lane mouth opened: no walls between tracks
--
-- Run: python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --dm Edit --file <this file>
-- All coordinates below are the LIVE map's coordinates; OFF is added when something is placed.
local OFF = Vector3.new(3000, 0, 0)
local PITCH = 108
-- the source is the 6-base map: Workspace.Map before the swap (tools/studio/swap_hub_v2.luau), the archive after it
local map = workspace:FindFirstChild("Map")
if not (map and map:FindFirstChild("Plots") and map.Plots:FindFirstChild("Plot6")) then
	map = game:GetService("ServerStorage").MapArchive.Map_v1_6lanes
end

local old = workspace:FindFirstChild("MapV2")
if old then
	old:Destroy()
end
local root = Instance.new("Model")
root.Name = "MapV2"
root:SetAttribute("DevOnly", true)

-- ------------------------------------------------------------------ helpers
local function partsOf(inst: Instance): { BasePart }
	local list = {}
	if inst:IsA("BasePart") then
		table.insert(list, inst)
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

-- bounding box in LIVE coordinates: centre, size
local function box(inst: Instance): (Vector3, Vector3)
	local lo, hi = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
	for _, p in partsOf(inst) do
		local cf, half = p.CFrame, p.Size / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local corner = (cf * CFrame.new(half.X * sx, half.Y * sy, half.Z * sz)).Position
					lo, hi = lo:Min(corner), hi:Max(corner)
				end
			end
		end
	end
	return (lo + hi) / 2 - OFF, hi - lo
end

local function shift(inst: Instance, d: Vector3)
	for _, p in partsOf(inst) do
		p.CFrame += d
	end
end

-- turn a group about the vertical through its own centre
local function turn(inst: Instance, yaw: number)
	local c = box(inst) + OFF
	local t = CFrame.new(c) * CFrame.Angles(0, yaw, 0) * CFrame.new(-c)
	for _, p in partsOf(inst) do
		p.CFrame = t * p.CFrame
	end
end

-- put a group's centre at (x, z); `faceYaw` sets the yaw of a root Part, `dy` lifts it
local function place(inst: Instance, x: number, z: number, faceYaw: number?, dy: number?)
	if faceYaw and inst:IsA("BasePart") then
		local _, yaw = inst.CFrame:ToOrientation()
		turn(inst, faceYaw - yaw)
	end
	local c = box(inst)
	shift(inst, Vector3.new(x - c.X, dy or 0, z - c.Z))
end

local function copy(src: Instance, parent: Instance): Instance
	local c = src:Clone()
	for _, d in c:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("SpawnLocation") then
			d.Enabled = false
		end
	end
	if c:IsA("SpawnLocation") then
		c.Enabled = false
	end
	shift(c, OFF)
	c.Parent = parent
	return c
end

local function named(parent: Instance, prefix: string): { Instance }
	local list = {}
	for _, c in parent:GetChildren() do
		if c.Name:sub(1, #prefix) == prefix then
			table.insert(list, c)
		end
	end
	table.sort(list, function(a, b)
		return box(a).X < box(b).X
	end)
	return list
end

local made = 0
local function block(name: string, size: Vector3, x: number, y: number, z: number, color: Color3, material: Enum.Material, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = CFrame.new(Vector3.new(x, y, z) + OFF)
	p.Anchored = true
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	made += 1
	return p
end

-- ------------------------------------------------------- 0. the faithful copy
local hub = copy(map.Hub, root)
local plots = copy(map.Plots, root)
local lanes = Instance.new("Folder")
lanes.Name = "Lanes"
lanes.Parent = root
local walls = copy(map.Lanes.Walls_Plots, lanes)
local facade = copy(map.Lanes.Facade_Plots, lanes)
local aprons = copy(map.Lanes.Aprons, lanes)
local scenery = Instance.new("Folder")
scenery.Name = "Scenery"
scenery.Parent = root
local yard = copy(map.Scenery.Plots, scenery)
copy(map.Scenery.HubBackdrop, scenery)
local T = workspace.Terrain
do
	local lo = Vector3int16.new(-536 / 4, -48 / 4, -452 / 4)
	local hi = Vector3int16.new(536 / 4, 96 / 4, 112 / 4)
	local region = T:CopyRegion(Region3int16.new(lo, hi))
	T:PasteRegion(region, Vector3int16.new(lo.X + OFF.X / 4, lo.Y, lo.Z), true)
end
local new = Instance.new("Folder")
new.Name = "Rework"
new.Parent = root

-- ------------------------------------------------ 1. five bases, re-centred
plots.Plot6:Destroy()
for i = 1, 5 do
	shift(plots["Plot" .. i], Vector3.new(PITCH / 2, 0, 0))
end
local EDGE = 2 * PITCH + 46 -- 262: the outer edge of the row's own dressing
for _, folder in { yard, aprons } do
	for _, c in folder:GetChildren() do
		shift(c, Vector3.new(PITCH / 2, 0, 0))
		if box(c).X > EDGE then
			c:Destroy()
		end
	end
end
local function plotX(i: number): number
	return (i - 3) * PITCH
end
-- where the sixth base and half a pitch of the first stood is lawn now
for _, side in { -1, 1 } do
	T:FillBlock(CFrame.new(Vector3.new(side * 302, -3, 18) + OFF), Vector3.new(72, 4, 124), Enum.Material.Grass)
end

-- ------------------------- 2 + 3. heroes-only bases, training on the lawns
local COURT_DX, COURT_DY, COURT_DZ = 8, -1.2, 31 -- the court's move: outward, down to the lawn, forward
local function isCourtPiece(name: string): boolean
	return name:sub(1, 5) == "Court" or name:sub(1, 7) == "Station" or name == "Gear" or name == "SpiritGear" or name:sub(1, 6) == "Target"
end
local lawnClear = {} -- court rectangles, to clear the lawn dressing under them
for i = 1, 5 do
	local plot = plots["Plot" .. i]
	local cx = plotX(i)
	local pieces = {}
	for _, c in plot:GetChildren() do
		if isCourtPiece(c.Name) then
			table.insert(pieces, c)
		end
	end
	for _, c in plot.Dressing:GetChildren() do
		if isCourtPiece(c.Name) then
			table.insert(pieces, c)
		end
	end
	for _, piece in pieces do
		-- a folder of stations holds pieces of both courts: move each child by its own side
		local members = if piece:IsA("Folder") then piece:GetChildren() else { piece }
		for _, m in members do
			local side = if box(m).X < cx then -1 else 1
			shift(m, Vector3.new(side * COURT_DX, COURT_DY, COURT_DZ))
		end
	end
	for _, side in { -1, 1 } do
		table.insert(lawnClear, { x = cx + side * 33, z = 45 })
	end
	-- two more rows of pedestals where the courts were: 6 rows of 7
	for _, folder in { plot.Pedestals, plot.Dressing } do
		for _, c in folder:GetChildren() do
			if folder == plot.Pedestals or c.Name:sub(1, 12) == "PedestalBody" then
				local z = box(c).Z
				if z < -20 then
					local twin = c:Clone()
					shift(twin, Vector3.new(0, 0, 32))
					twin.Parent = folder
				end
			end
		end
	end
	local spawn = plot:FindFirstChild("Spawn")
	if spawn then
		shift(spawn, Vector3.new(0, 0, 8))
	end
end
for _, c in yard:GetChildren() do
	local p = box(c)
	for _, r in lawnClear do
		if math.abs(p.X - r.x) < 18 and math.abs(p.Z - r.z) < 13 then
			if c.Name:find("LanternString") then
				shift(c, Vector3.new(0, 0, 60 - p.Z)) -- the lantern line moves to the front of the court
			else
				c:Destroy()
			end
			break
		end
	end
end

-- --------------------------------- 4. food cart and sell booth at every pad
for i = 1, 5 do
	local cx = plotX(i)
	local cart = hub.FoodCart:Clone()
	cart.Name = "FoodCart"
	cart.Parent = plots["Plot" .. i]
	place(cart, cx - 26, 66, 0)
	local booth = hub.SellBooth:Clone()
	booth.Name = "SellBooth"
	booth.Parent = plots["Plot" .. i]
	place(booth, cx + 26, 66, 0)
end
hub.FoodCart:Destroy()
hub.SellBooth:Destroy()

-- ----------------------------------------------- 5. the plaza in districts
local plaza, dressing = hub.Plaza, hub.Dressing
local WOOD = Color3.fromRGB(222, 178, 112)
local DARKWOOD = Color3.fromRGB(110, 72, 48)
local RED = Color3.fromRGB(200, 52, 48)

local function sign(x: number, z: number, text: string)
	local model = Instance.new("Model")
	model.Name = "Sign_" .. text
	for _, sx in { -1, 1 } do
		block("Post", Vector3.new(1.8, 21, 1.8), x + sx * 17, 9.3, z, DARKWOOD, Enum.Material.Wood, model)
	end
	-- a gateway: the board hangs 13 studs up, so the district behind it is seen and walked into under it
	local board = block("Board", Vector3.new(32.2, 5.4, 0.8), x, 16.2, z, RED, Enum.Material.SmoothPlastic, model)
	block("Roof", Vector3.new(40, 1, 3.4), x, 19.6, z, DARKWOOD, Enum.Material.Wood, model)
	block("RoofCap", Vector3.new(43, 0.7, 4.8), x, 20.4, z, Color3.fromRGB(60, 44, 40), Enum.Material.Wood, model)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0.2
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 244, 214)
		label.Text = text
		local pad = Instance.new("UIPadding")
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0.12, 0), UDim.new(0.12, 0)
		pad.Parent = label
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(70, 20, 20)
		stroke.Thickness = 3
		stroke.Parent = label
		label.Parent = gui
		gui.Parent = board
	end
	model.Parent = new
end

local function deck(name: string, x: number, z: number, w: number, d: number, top: number)
	-- a wooden festival deck: a rim and a planked top, like the bases
	block(name .. "Rim", Vector3.new(w + 2, 0.5, d + 2), x, top - 0.45, z, DARKWOOD, Enum.Material.Wood, new)
	block(name, Vector3.new(w, 0.4, d), x, top - 0.2, z, WOOD, Enum.Material.WoodPlanks, new)
end

-- Rankings (west of the shrine): three boards side by side on a stage, facing the bases
deck("RankingsDeck", -110, -122, 84, 44, -0.6)
deck("RankingsStage", -110, -139, 70, 10, 0.2)
place(hub.BoardYen, -110, -139, math.pi, 0.8)
place(hub.BoardCaught, -134, -139, math.pi, 0.8)
place(hub.BoardRarest, -86, -139, math.pi, 0.8)
sign(-110, -98, "RANKINGS")
local strayLantern = plaza:FindFirstChild("Prop_store_StoneLanternWide")
if strayLantern then
	place(strayLantern, -156, -104) -- it stood in the middle of the new deck
end
-- Rewards and index (east of the shrine)
deck("RewardsDeck", 110, -122, 84, 44, -0.6)
deck("RewardsStage", 110, -139, 70, 10, 0.2)
place(hub.IndexBoard, 110, -139, math.pi, 0.8)
place(hub.DailyChest, 92, -124, math.pi, 0.6)
place(hub.GiftBox, 128, -124, math.pi, 0.6)
sign(110, -98, "REWARDS")

-- back-wall fillers that stood where a district is now
for _, c in dressing:GetChildren() do
	local p = box(c)
	if p.Z < -140 and math.abs(math.abs(p.X) - 110) < 46 and not c.Name:find("LanternString") then
		if c.Name:find("Gong") or c.Name:find("KoiFlagPole") or c.Name:find("StoneLantern") then
			c:Destroy()
		end
	end
end

-- Ramen alley (far west): the food props that were scattered, in two rows facing each other
deck("RamenDeck", -282, -114, 96, 48, -0.6)
local vending = named(dressing, "Prop_shared_VendingMachine")
local _, vendingYaw = (function()
	for _, v in vending do
		if box(v).Z < -145 then
			return true, v
		end
	end
	return false, vending[1]
end)()
for k, v in vending do
	-- every machine gets the facing of one that already stood against the back wall
	local ref = (vendingYaw :: Instance):GetPivot()
	if v ~= vendingYaw then
		v:PivotTo(CFrame.new(v:GetPivot().Position) * ref.Rotation)
	end
	place(v, -322 + (k - 1) * 8, -132)
end
place(plaza.Prop_store_RamenShop, -264, -130)
place(plaza.Prop_store_RamenCart, -282, -100)
for k, stand in named(dressing, "Prop_shared_RamenStand") do
	place(stand, if k == 1 then -312 else -252, -100)
end
place(plaza.Prop_store_MarketTent, -244, -124)
place(plaza.Prop_store_ProduceTable, -244, -126)
sign(-282, -88, "RAMEN ALLEY")

-- Hall of Legends (far east): gold statues of the game's own heroes round a horned shrine. The
-- daruma, lucky cats and dango statues that stood here read as filler (owner, 2026-11-21): removed.
deck("LegendsDeck", 282, -114, 96, 48, -0.6)
for _, prefix in { "Prop_shared_Daruma", "Prop_shared_DangoStatue", "Prop_shared_LuckyCat" } do
	for _, c in named(dressing, prefix) do
		c:Destroy()
	end
end
plaza.Prop_store_Brazier:Destroy()
sign(282, -88, "HALL OF LEGENDS")

-- spirit lanterns: a pair on each district stage
local spirits = named(dressing, "Prop_realm_of_legends_SpiritLantern")
local spots = { { -147, -134 }, { -73, -134 }, { 73, -134 }, { 147, -134 }, { 240, -92 } }
for k, s in spirits do
	if spots[k] then
		place(s, spots[k][1], spots[k][2])
	end
end

-- the planted trees: an even row along the promenade, in line with the bases
local trees = {}
for _, t in plaza:GetChildren() do
	if t.Name:find("Sakura") then
		table.insert(trees, t)
	end
end
local planters, soils = named(plaza, "Planter"), named(plaza, "Soil")
-- never on a district's centre line (110 and 282 either side): a tree there hides the gateway
local row = { -216, -162, -70, 70, 162, 216, -190, 190 }
for k, planter in planters do
	local p = box(planter)
	local group = { planter }
	local function nearest(list)
		local best, bestD = nil, 9
		for _, c in list do
			local q = box(c)
			local d = (Vector3.new(q.X, 0, q.Z) - Vector3.new(p.X, 0, p.Z)).Magnitude
			if d < bestD and not table.find(group, c) then
				best, bestD = c, d
			end
		end
		return best
	end
	local soil, tree = nearest(soils), nearest(trees)
	if soil then
		table.insert(group, soil)
	end
	if tree then
		table.insert(group, tree)
	end
	local x = row[k] or p.X
	local z = if k <= 6 then -64 else -128
	local d = Vector3.new(x - p.X, 0, z - p.Z)
	for _, g in group do
		shift(g, d)
	end
end

-- ----------------------------------------------------- 6. the lane mouth
-- no walls between the tracks: keep the two outer wall runs, bring one segment in on each side
for _, folder in { walls, facade } do
	for _, c in folder:GetChildren() do
		local p = box(c)
		if math.abs(p.X) < 326 and p.Z > 60 then
			c:Destroy()
		elseif math.abs(p.X) < 331 and p.Z > 60 and folder == walls then
			local twin = c:Clone()
			shift(twin, Vector3.new(if p.X > 0 then -PITCH / 2 else PITCH / 2, 0, 0))
			twin.Parent = folder
		end
	end
end
-- a torii over every track, as today
local gates = {}
for _, d in map.Lanes:GetDescendants() do
	if d:IsA("Model") and d.Name == "Lane_ZoneGate" then
		local c = d:GetPivot().Position
		if c.Z < 200 then
			table.insert(gates, d)
		end
	end
end
table.sort(gates, function(a, b)
	return a:GetPivot().Position.X < b:GetPivot().Position.X
end)
for i = 1, math.min(5, #gates) do
	local g = gates[i]:Clone()
	shift(g, OFF + Vector3.new(PITCH / 2, 0, 0))
	g.Parent = new
end
-- between the tracks: a low stone planter with bushes and a koi pole, instead of a wall
local bush = yard:FindFirstChild("Prop_store_Bush")
local pole = yard:FindFirstChild("Prop_shared_KoiFlagPole")
for _, x in { -270, -162, -54, 54, 162, 270 } do
	block("MedianPlanter", Vector3.new(46, 2.2, 9), x, -0.1, 90, Color3.fromRGB(150, 148, 150), Enum.Material.Slate, new)
	block("MedianSoil", Vector3.new(44, 0.4, 7), x, 1.1, 90, Color3.fromRGB(96, 70, 52), Enum.Material.Ground, new)
	if bush then
		for _, dx in { -16, -8, 8, 16 } do
			local b = bush:Clone()
			b.Parent = new
			place(b, x + dx, 90, nil, 1.6)
		end
	end
	if pole then
		local p = pole:Clone()
		p.Parent = new
		place(p, x, 90, nil, 1.6)
	end
end

-- ----------------------------------------- the two side gardens (new lawn)
local cherry = yard:FindFirstChild("Prop_store_BigCherry")
local pink = yard:FindFirstChild("Prop_store_SakuraPink")
local lantern = yard:FindFirstChild("Prop_store_StoneLanternWide")
for _, side in { -1, 1 } do
	if cherry then
		local c = cherry:Clone()
		c.Parent = new
		place(c, side * 300, 18)
	end
	if pink then
		for _, at in { { 288, 62 }, { 322, 50 } } do
			local c = pink:Clone()
			c.Parent = new
			place(c, side * at[1], at[2])
		end
	end
	if lantern then
		for _, at in { { 280, 36 }, { 326, 26 } } do
			local c = lantern:Clone()
			c.Parent = new
			place(c, side * at[1], at[2])
		end
	end
	if bush then
		for z = -36, 72, 9 do
			local b = bush:Clone()
			b.Parent = new
			place(b, side * 333, z)
		end
	end
end

-- ------------------------------------------------------------ 7. the look
-- Creator Store models, cleaned in quarantine (every script, sound and GUI stripped; four of ten
-- candidates carried the Studio backdoor of CLAUDE.md's known traps) and kept in ServerStorage.StoreAssets.HubV2.
local kit = game:GetService("ServerStorage").StoreAssets:FindFirstChild("HubV2")
local characters = game:GetService("ReplicatedStorage").Assets:FindFirstChild("Characters")

-- a kit model at (x, z), standing on `ground`, scaled; returns it
local function asset(name: string, x: number, z: number, scale: number, ground: number, yaw: number?): Model?
	local src = kit and kit:FindFirstChild(name)
	if not src then
		return nil
	end
	local m = src:Clone()
	m:ScaleTo(scale)
	if yaw then
		m:PivotTo(m:GetPivot() * CFrame.Angles(0, yaw, 0))
	end
	local cf, size = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() + (Vector3.new(x, ground + size.Y / 2, z) + OFF - cf.Position))
	m.Parent = new
	return m
end

local function bottomOf(inst: Instance): number
	local c, size = box(inst)
	return c.Y - size.Y / 2
end

-- the summon shrine is the centrepiece: a summoning circle on the ring with the altar at its centre,
-- and the dragon rising behind it. (Before: the altar stood hidden behind a lucky-cat statue.)
do
	local ringTop = select(1, box(plaza.RingInner)).Y + select(2, box(plaza.RingInner)).Y / 2
	plaza.Prop_shared_LuckyCat:Destroy()
	for _, tier in named(plaza, "Tier") do
		tier:Destroy()
	end
	local circle = asset("SummonCircle", 0, -100, 1.9, ringTop + 0.05)
	if circle then
		for _, d in circle:GetDescendants() do
			if d:IsA("BasePart") then
				d.Color = Color3.fromRGB(255, 214, 80) -- gold, not the pack's green
			end
		end
	end
	place(hub.Shrine, 0, -100, math.pi)
	shift(hub.Shrine, Vector3.new(0, ringTop - bottomOf(hub.Shrine), 0))
	-- the mesh is authored turned 119 degrees: turn it back so its long side faces the bases
	local dragon = asset("WishDragon", 0, -142, 0.6, bottomOf(plaza.RingOuter), math.rad(-119))
	if dragon then
		for _, d in dragon:GetDescendants() do
			if d:IsA("BasePart") then
				d.Material = Enum.Material.SmoothPlastic -- it shipped as glass, which read as pale ice
				d.Color = Color3.fromRGB(255, 196, 64)
				d.Reflectance = 0.2
			end
		end
	end
	for k, gong in named(plaza, "Prop_store_GongB") do
		place(gong, if k == 1 then -44 else 44, -146)
	end
end

-- the cherry trees: the blobby store cherry and the low-poly planter sakura are swapped for full trees
local function swapTrees(prefix: string, with: string, scale: number)
	local list = {}
	for _, d in root:GetDescendants() do
		if d:IsA("Model") and d.Name:sub(1, #prefix) == prefix then
			table.insert(list, d)
		end
	end
	for _, tree in list do
		local c = box(tree)
		asset(with, c.X, c.Z, scale, bottomOf(tree))
		tree:Destroy()
	end
	return #list
end
local lush = swapTrees("Prop_store_BigCherry", "SakuraLush", 0.5)
local soft = swapTrees("Prop_store_Sakura", "SakuraSoft", 0.62)

-- the Hall of Legends: the horned shrine at the back, six gold statues of the game's own heroes in front
do
	local deckTop = -0.6
	asset("CursedShrine", 282, -130, 0.5, deckTop)
	local GOLD = Color3.fromRGB(255, 196, 64)
	local legends = {
		{ "fox_ninja", "FOX NINJA", 250, -103 },
		{ "straw_hat_rookie", "STRAW HAT ROOKIE", 268, -99 },
		{ "instinct_warrior", "INSTINCT WARRIOR", 296, -99 },
		{ "limitless_teacher", "LIMITLESS TEACHER", 314, -103 },
		{ "sun_breather", "SUN BREATHER", 244, -122 },
		{ "bald_cape_hero", "BALD CAPE HERO", 320, -122 },
	}
	for _, row in legends do
		local template = characters and characters:FindFirstChild("Char_" .. row[1])
		if template then
			local x, z = row[3], row[4]
			local plinth = block("Plinth", Vector3.new(2.6, 8, 8), x, deckTop + 1.3, z, GOLD, Enum.Material.Metal, new)
			plinth.Shape = Enum.PartType.Cylinder
			plinth.CFrame = CFrame.new(Vector3.new(x, deckTop + 1.3, z) + OFF) * CFrame.Angles(0, 0, math.rad(90))
			local statue = template:Clone()
			statue.Name = "Statue_" .. row[1]
			-- full colour: a hero stripped to bare gold is a yellow mannequin, the outfit IS the character
			for _, d in statue:GetDescendants() do
				if d:IsA("LuaSourceContainer") then
					d:Destroy()
				elseif d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
				elseif d:IsA("Humanoid") then
					d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				end
			end
			statue:ScaleTo(1.9)
			-- a baked hero pivots at its feet and faces -Z: turn it to face the promenade (+Z)
			statue:PivotTo(CFrame.new(Vector3.new(x, deckTop + 2.6, z) + OFF) * CFrame.Angles(0, math.pi, 0))
			statue.Parent = new
			local plaque = block("Plaque", Vector3.new(7, 1.5, 0.4), x, deckTop + 0.9, z + 4, Color3.fromRGB(60, 44, 40), Enum.Material.Wood, new)
			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Back
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 50
			gui.LightInfluence = 0.2
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.FredokaOne
			label.TextScaled = true
			label.TextColor3 = GOLD
			label.Text = row[2]
			label.Parent = gui
			gui.Parent = plaque
		end
	end
end

-- ------------------------------------------------------- 8. the bases' look
-- A dojo courtyard per base, each with its own accent colour so a player knows theirs at a glance:
-- dark walnut floor with an accent runner, lacquered fence rails, gold-rimmed pedestals, a lantern-lit
-- torii at the front gate with a stone lantern either side. A pagoda stands in each side garden.
do
	local ACCENTS = {
		Color3.fromRGB(226, 75, 74),
		Color3.fromRGB(63, 140, 255),
		Color3.fromRGB(79, 200, 120),
		Color3.fromRGB(170, 100, 255),
		Color3.fromRGB(255, 150, 60),
	}
	local WALNUT = Color3.fromRGB(118, 80, 58)
	local DARK = Color3.fromRGB(62, 40, 34)
	local GOLD = Color3.fromRGB(255, 204, 72)
	local function paintFence(fence: Instance, accent: Color3)
		for _, d in fence:GetDescendants() do
			if d:IsA("BasePart") then
				if d.Name:sub(1, 4) == "Rail" then
					d.Color = accent
				elseif d.Name:sub(1, 4) == "Post" or d.Name:sub(1, 4) == "Foot" then
					d.Color = DARK
				elseif d.Name:sub(1, 3) == "Cap" then
					d.Color = GOLD
				end
			end
		end
	end
	for i = 1, 5 do
		local plot = plots["Plot" .. i]
		local cx = plotX(i)
		local accent = ACCENTS[i]
		plot.Base.Color = WALNUT
		local top = select(1, box(plot.Base)).Y + select(2, box(plot.Base)).Y / 2
		local runner = block("Runner", Vector3.new(10, 0.12, 70), cx, top + 0.06, -8, accent, Enum.Material.Fabric, plot)
		runner.CanCollide = false
		for _, edge in { -1, 1 } do
			block("RunnerTrim", Vector3.new(0.8, 0.14, 70), cx + edge * 5.4, top + 0.07, -8, GOLD, Enum.Material.SmoothPlastic, plot).CanCollide = false
		end
		for _, c in plot.Dressing:GetChildren() do
			if c.Name:sub(1, 10) == "Plot_Fence" then
				paintFence(c, accent)
			elseif c.Name:sub(1, 12) == "PedestalBody" then
				for _, d in c:GetDescendants() do
					if d:IsA("BasePart") then
						d.Color = if d.Name:sub(1, 3) == "Rim" then GOLD else DARK
					end
				end
			end
		end
		for _, marker in plot.Pedestals:GetChildren() do
			if marker:IsA("BasePart") then
				marker.Color = accent:Lerp(Color3.new(1, 1, 1), 0.35)
				marker.Material = Enum.Material.Neon
			end
		end
		asset("DojoGate", cx, 29, 0.8, top)
		for _, side in { -1, 1 } do
			asset("ToroLantern", cx + side * 19, 31, 1.3, -1)
		end
	end
	-- the forecourt fences take the colour of the base they stand in front of
	for _, c in yard:GetChildren() do
		if c.Name:sub(1, 10) == "Plot_Fence" then
			local i = math.clamp(math.floor(box(c).X / PITCH + 3.5), 1, 5)
			paintFence(c, ACCENTS[i])
		end
	end
	for _, side in { -1, 1 } do
		asset("Pagoda", side * 302, -16, 0.45, -1)
	end
end

root.Parent = workspace
local total = #partsOf(root)
return string.format("hub v2: %d parts in the copy (%d new blocks), %d + %d trees swapped, pitch %d", total, made, lush, soft, PITCH)
