-- zone_03_one_piece.luau - Studio EDIT mode. Builds zone 3, "Grand Line" (One Piece), in the single
-- lane: z 880..1240, lane floor y -48 (config World.LaneY), lane edges x = +-160. Safe to run again:
-- it clears what it made (Map.Scenery.Zone_<id>) and rebuilds; the first run archives the old ninja
-- village dressing in ServerStorage.MapArchive.Zone3_ninja_village_v1 (never delete).
--
-- The picture: a tropical cove. The lane is the sea (blue wave tiles, straw-yellow kerbs, a quay
-- either side) and between the quays and the cliffs lies real water.
--   * +X (left from the throw stage): the pirates' lion-headed ship at its pier, a beach with palms
--     and treasure, and a giant straw hat on the rim above
--   * -X: the navy's warship, a skull rock in the water, a tavern on stilts with its pier, and a
--     lighthouse on the rim
-- The walls join zone 2's at z 880 and come down to the lobby's level at 1240 until zone 4 is built.
--
-- Needs ServerStorage.StoreAssets.Zone03_OnePiece: LionShip, NavyShip, Tavern, Palm, StrawHat (Studio
-- mesh generator, then square_templates.luau: they front to -Z), and Zone01_Naruto's trees.
-- Run: python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --dm Edit --file <this file>
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local T = workspace.Terrain
local map = workspace.Map
local KIT = RS.Assets.Kit
local SRC = SS.StoreAssets.Zone03_OnePiece
local JUNGLE = SS.StoreAssets.Zone01_Naruto
local ID = "ninja_village" -- the zone's id in config until the anime zone data lands
local TITLE = "GRAND LINE"
local LY, HALF, Z0, Z1 = -48, 160, 880, 1240
local SEA0, SEA1 = 904, 1228 -- the water lies between these; a sand bank closes each end
local SEABED, SURFACE = LY - 8, LY - 1.5
local DO_TERRAIN = true
local rng = Random.new(3307)

local SEA_A = Color3.fromRGB(46, 150, 214)
local SEA_B = Color3.fromRGB(84, 186, 232)
local STRAW = Color3.fromRGB(242, 201, 76)
local LUFFY_RED = Color3.fromRGB(214, 48, 49)
local PLANK = Color3.fromRGB(150, 106, 68)
local PLANK_DARK = Color3.fromRGB(92, 62, 44)

-- ---------------------------------------------------------------------------------- helpers
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
local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end
local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end
local function still(inst: Instance, shadow: boolean?)
	for _, p in partsOf(inst) do
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		if shadow ~= nil then
			p.CastShadow = shadow
		end
	end
end
local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end
local function block(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
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
	p.CastShadow = size.Magnitude > 14
	p.Parent = parent
	return p
end
local function post(parent: Instance, x: number, z: number, top: number, bottom: number)
	local p = block(parent, "Post", Vector3.new(top - bottom, 2.4, 2.4), CFrame.new(x, (top + bottom) / 2, z) * CFrame.Angles(0, 0, math.rad(90)), PLANK_DARK, Enum.Material.Wood)
	p.Shape = Enum.PartType.Cylinder
end
-- every template's pivot is the middle of its base: a thing is placed by its pivot
local function make(parent: Instance, template: Instance, scale: number, yaw: number, at: Vector3): Model
	local m = template:Clone() :: Model
	m:ScaleTo(m:GetScale() * scale)
	m:PivotTo(CFrame.new(at) * CFrame.Angles(0, math.rad(yaw), 0))
	still(m)
	m.Parent = parent
	return m
end
-- templates front to -Z; on the +X wall the lane is at -X, on the -X wall at +X
local function facing(side: number): number
	return if side > 0 then 90 else -90
end

-- ---------------------------------------------------------------------------------- the old dressing
local lanes, scenery = map.Lanes, map.Scenery
local archive = SS:FindFirstChild("MapArchive") or folder(SS, "MapArchive")
if not archive:FindFirstChild("Zone3_ninja_village_v1") then
	local old = folder(archive, "Zone3_ninja_village_v1")
	old:SetAttribute("Note", "Zone 3 before the One Piece rework (2026-11-22). Never delete.")
	for _, f in { lanes["Walls_" .. ID], lanes["Facade_" .. ID], scenery["Zone_" .. ID], scenery["Town_" .. ID] } do
		f:Clone().Parent = old
	end
	local hills = folder(old, "Hills")
	for _, u in scenery.Hills:GetDescendants() do
		if u:IsA("Model") and u.Parent and u.Name:sub(1, 5) == "Prop_" then
			local p = u:GetPivot().Position
			if math.abs(p.X) < 372 and p.Z > Z0 - 4 and p.Z < Z1 + 14 then
				u.Parent = hills
			end
		end
	end
end
for _, f in { lanes["Walls_" .. ID], lanes["Facade_" .. ID], scenery["Town_" .. ID], scenery["Zone_" .. ID] } do
	f:ClearAllChildren()
end
local root = scenery["Zone_" .. ID]
root:SetAttribute("Theme", "Grand Line (One Piece), zone_03_one_piece.luau")

-- ---------------------------------------------------------------------------------- the cove
-- The same shape either side: sea, a rise, a beach, a rise, the top. NOW is this zone's numbers,
-- PREV is zone 2's: the first 44 studs blend from one to the other.
local NOW = {
	face = { [-1] = 238, [1] = 238 },
	rise = { [-1] = 8, [1] = 8 },
	ledgeW = { [-1] = 22, [1] = 22 }, -- narrow, so the clifftop is wide enough to carry the jungle
	ledgeY = { [-1] = LY + 6, [1] = LY + 6 }, -- the beach, just over the water
	top = { [-1] = 62, [1] = 58 },
}
local PREV = {
	face = { [-1] = 236, [1] = 234 },
	rise = { [-1] = 6, [1] = 6 },
	ledgeW = { [-1] = 26, [1] = 30 },
	ledgeY = { [-1] = 6, [1] = 12 },
	top = { [-1] = 68, [1] = 60 },
}
local OUTER = 368
local function profile(side: number, ax: number, z: number, outerH: number): (number, string)
	local t = smooth((z - Z0) / 44)
	local function v(key: string): number
		return lerp(PREV[key][side], NOW[key][side], t)
	end
	local wobble = (6 * math.noise(z / 46, side * 3.1, 0.5) + 3 * math.noise(z / 13, side * 9.7, 0.2)) * t
	local d = ax - (v("face") + wobble)
	if d < 0 then
		return LY, "terrace"
	end
	local riseW, ledgeW = v("rise"), v("ledgeW")
	local ledge = v("ledgeY") + 1.2 * math.noise(ax / 9, z / 9, 3.3)
	local edge = v("top") + 6 * math.noise(z / 50, side * 5.5, 1.7)
	local h: number
	local kind = "face"
	if d < riseW then
		h = LY + (ledge - LY) * smooth(d / riseW)
	elseif d < riseW + ledgeW then
		h = ledge
		kind = "level"
	else
		h = ledge + (edge - ledge) * smooth((d - riseW - ledgeW) / 10)
	end
	local topStart = riseW + ledgeW + 10
	if d > topStart then
		kind = "level"
		h += 4 * math.noise(ax / 28, z / 28, 4.4) + 6 * math.min((d - topStart) / 60, 1)
	end
	-- the far end comes down to the lobby's level until zone 4 stands there
	-- (the beaches lie below the lobby: only what stands above it falls)
	if h > -2 then
		h = -2 + (h + 2) * (1 - smooth((z - (Z1 - 14)) / 14))
	end
	local outerStart = OUTER - 72
	if ax > outerStart then
		h += (outerH - h) * smooth((ax - outerStart) / 72)
	end
	return h, kind
end
local outerCache = { [-1] = {}, [1] = {} }
local function outerHeight(side: number, z: number): number
	local key = math.floor(z / 4)
	local cached = outerCache[side][key]
	if cached then
		return cached
	end
	local x = if side > 0 then OUTER else -OUTER - 4
	local _, occ = T:ReadVoxels(Region3.new(Vector3.new(x, -32, key * 4), Vector3.new(x + 4, 100, key * 4 + 4)), 4)
	local top = -2
	for y = 1, occ.Size.Y do
		if occ[1][y][1] > 0.1 then
			top = -32 + (y - 1) * 4 + occ[1][y][1] * 4
		end
	end
	top = math.clamp(top, -2, 40)
	outerCache[side][key] = top
	return top
end
local function ground(side: number, ax: number, z: number): number
	return (profile(side, ax, z, outerHeight(side, z)))
end

if DO_TERRAIN then
	T:SetMaterialColor(Enum.Material.Sandstone, Color3.fromRGB(202, 152, 102)) -- the cove's rock: warm bands...
	T:SetMaterialColor(Enum.Material.Limestone, Color3.fromRGB(240, 218, 176)) -- ...between pale ones
	local Y0, Y1 = -64, 124
	local ny = (Y1 - Y0) / 4
	for _, side in { -1, 1 } do
		for z0 = Z0, Z1 - 4, 60 do
			local z1 = math.min(z0 + 60, Z1)
			local nx, nz = (OUTER - HALF) / 4, (z1 - z0) / 4
			local mats, occs = table.create(nx), table.create(nx)
			for ix = 1, nx do
				local ax = HALF + (ix - 1) * 4 + 2
				local mcol, ocol = table.create(ny), table.create(ny)
				for iy = 1, ny do
					mcol[iy] = table.create(nz, Enum.Material.Air)
					ocol[iy] = table.create(nz, 0)
				end
				for iz = 1, nz do
					local z = z0 + (iz - 1) * 4 + 2
					local outer = outerHeight(side, z)
					local h, kind = profile(side, ax, z, outer)
					local gx = (profile(side, ax + 2, z, outer) - profile(side, ax - 2, z, outer)) / 4
					local gz = (profile(side, ax, z + 2, outerHeight(side, z + 2)) - profile(side, ax, z - 2, outerHeight(side, z - 2))) / 4
					local steep = gx * gx + gz * gz
					local spread = 4 * math.sqrt(1 + math.min(steep, 30))
					local sea = kind == "terrace" and z > SEA0 and z < SEA1
					for iy = 1, ny do
						local yb = Y0 + (iy - 1) * 4
						local o = math.clamp(0.5 + (h - (yb + 2)) / spread, 0, 1)
						-- banded rock: one pale smooth material read as a sand dune, not a cliff
						local band = (yb + 5 * math.noise(z / 30, ax / 30, 8.8)) % 30 < 12
						local m = if band then Enum.Material.Sandstone else Enum.Material.Limestone
						if sea then
							-- sand on the bed, water over it, air above
							if yb + 4 <= SEABED then
								m, o = Enum.Material.Sand, 1
							else
								m, o = Enum.Material.Water, math.clamp((SURFACE - yb) / 4, 0, 1)
							end
						elseif kind == "terrace" then
							m = Enum.Material.Sand
						else
							-- zone 2's dark rock gives way to this zone's pale rock over the first 28 studs
							local mine = (z - Z0) / 28 + 0.6 * math.noise(z / 7, yb / 7, ax / 7) > 0.5
							if not mine then
								m = Enum.Material.Basalt
							end
							if kind == "level" and steep < 0.5 and yb + 4 > h - 6 then
								m = if h < LY + 16 and mine then Enum.Material.Sand else Enum.Material.LeafyGrass
							end
						end
						if o > 0.02 then
							mcol[iy][iz] = m
							ocol[iy][iz] = o
						end
					end
				end
				local slot = if side > 0 then ix else nx - ix + 1
				mats[slot] = mcol
				occs[slot] = ocol
			end
			local xa = if side > 0 then HALF else -OUTER
			T:WriteVoxels(Region3.new(Vector3.new(xa, Y0, z0), Vector3.new(xa + (OUTER - HALF), Y1, z1)), 4, mats, occs)
		end
	end
end

local ships = folder(root, "Ships")
local docks = folder(root, "Docks")
local props = folder(root, "Props")
local trees = folder(root, "Trees")
local function beachAx(side: number): number
	return NOW.face[side] + NOW.rise[side] + NOW.ledgeW[side] / 2
end
-- the clifftop's edge: trees stand right on it, or the cliff shows a bare ridge to the lane
local function rimAx(side: number): number
	return NOW.face[side] + NOW.rise[side] + NOW.ledgeW[side] + 16
end
local function kit(name: string, scale: number, x: number, y: number, z: number, yaw: number)
	local template = KIT:FindFirstChild(name)
	if template then
		make(props, template, scale, yaw, Vector3.new(x, y, z))
	end
end
local DECK = LY - 0.4 -- a pier's top, level with the lane's paving

-- ---------------------------------------------------------------------------------- the quays
for _, side in { -1, 1 } do
	local x = side * 161.6
	block(docks, "Quay", Vector3.new(3.2, 5, SEA1 - SEA0), CFrame.new(x, LY - 2.1, (SEA0 + SEA1) / 2), PLANK_DARK, Enum.Material.Wood)
	for z = SEA0 + 12, SEA1 - 12, 36 do
		post(docks, side * 163.6, z, LY + 3, LY - 9)
	end
end
local function pier(side: number, ax0: number, ax1: number, z0: number, z1: number)
	local x = side * (ax0 + ax1) / 2
	block(docks, "Pier", Vector3.new(ax1 - ax0, 1.4, z1 - z0), CFrame.new(x, DECK - 0.7, (z0 + z1) / 2), PLANK, Enum.Material.WoodPlanks)
	for _, ax in { ax0 + 2, ax1 - 2 } do
		for z = z0 + 2, z1 - 2, math.max(12, (z1 - z0 - 4) / 3) do
			post(docks, side * ax, z, DECK + 3, LY - 9)
		end
	end
end

-- ---------------------------------------------------------------------------------- the pirates (+X)
-- squared templates front to -Z: both ships head for the throw stage
local DRAFT = 6 -- how deep a hull sits in the water
still(make(ships, SRC.LionShip, 2.3, 0, Vector3.new(200, SURFACE - DRAFT, 1076)), true) -- 1.7 looked like a toy
pier(1, 163, 176, 1034, 1118)
kit("Prop_pirate_harbor_Cannon", 1.7, 168, DECK, 1046, 90)
kit("Prop_pirate_harbor_BarrelStack", 1.5, 170, DECK, 1108, 20)
kit("Prop_pirate_harbor_GiantAnchor", 2.0, 170, DECK, 1076, 90)
kit("Prop_pirate_harbor_TreasurePile", 2.2, beachAx(1), ground(1, beachAx(1), 968) - 0.4, 968, 200)
kit("Prop_pirate_harbor_TreasurePile", 1.6, beachAx(1) + 6, ground(1, beachAx(1) + 6, 1180) - 0.4, 1180, 40)
-- the straw hat, set down on the rim above the ship
local hat = make(props, SRC.StrawHat, 4.0, 0, Vector3.new(rimAx(1) + 14, ground(1, rimAx(1) + 14, 1160) + 3, 1160))
hat:PivotTo(hat:GetPivot() * CFrame.Angles(0, 0, math.rad(16)))
still(hat, true)

-- ---------------------------------------------------------------------------------- the navy and the port (-X)
still(make(ships, SRC.NavyShip, 2.1, 0, Vector3.new(-200, SURFACE - DRAFT, 1016)), true)
-- the tavern stands on its stilts in the shallows, its front to the lane
local TAVERN = 1.8
local depth = (SRC.Tavern:GetAttribute("TrueSize") :: Vector3).Z * TAVERN
still(make(props, SRC.Tavern, TAVERN, facing(-1), Vector3.new(-(232 - depth / 2), SURFACE - 2, 1150)), true)
pier(-1, 163, 234 - depth, 1138, 1162)
kit("Prop_pirate_harbor_FishStall", 1.7, -172, DECK, 1150, -90)
kit("Prop_pirate_harbor_BarrelStack", 1.5, -170, DECK, 1160, 70)
kit("Prop_pirate_harbor_SkullRock", 2.6, -208, SURFACE - 4, 938, 90)
kit("Prop_pirate_harbor_Lighthouse", 2.2, -(rimAx(-1) + 2), ground(-1, rimAx(-1) + 2, 1204) - 0.6, 1204, 0)

-- ---------------------------------------------------------------------------------- palms and jungle
local function plant(template: Instance, side: number, ax: number, z: number, scale: number): Model
	local m = make(trees, template, scale, rng:NextInteger(0, 359), Vector3.new(side * ax, ground(side, ax, z) - 0.8, z))
	still(m, scale > 1.2)
	return m
end
for _, side in { -1, 1 } do
	for z = 928, 1216, 36 do
		plant(SRC.Palm, side, beachAx(side) + rng:NextNumber(-8, 8), z + rng:NextNumber(-8, 8), rng:NextNumber(1.0, 1.4))
	end
	for z = 904, 1220, 24 do
		local template = if rng:NextNumber() < 0.35 then SRC.Palm else (if rng:NextNumber() < 0.5 then JUNGLE.TreeBroad else JUNGLE.TreeTall)
		plant(template, side, rimAx(side) + rng:NextNumber(-6, 8), z + rng:NextNumber(-8, 8), rng:NextNumber(1.4, 2.0))
	end
end

-- ---------------------------------------------------------------------------------- floor and gate
for _, c in lanes["Zone_" .. ID]:GetChildren() do
	local n = c.Name
	if c:IsA("BasePart") then
		if n:sub(1, 5) == "Strip" then
			-- the sea: two blues, tile by tile, like swell
			local tile = math.floor((c.Position.Z - (Z0 + 6)) / 44.25 + 0.01)
			local a = tile % 2 == 0
			c.Color = if a then SEA_A else SEA_B
			local tex = c:FindFirstChildWhichIsA("Texture")
			if tex then
				tex.Color3 = if a then Color3.fromRGB(120, 200, 244) else Color3.fromRGB(170, 226, 250)
			end
		elseif n:sub(1, 4) == "Kerb" then
			c.Color = STRAW
		elseif n:sub(1, 6) == "Paving" or n == "MarginPaving" then
			c.Color = Color3.fromRGB(226, 206, 160)
			local tex = c:FindFirstChildWhichIsA("Texture")
			if tex then
				tex.Color3 = Color3.fromRGB(244, 232, 200)
			end
		elseif n:sub(1, 12) == "DistanceBand" then
			c.Color = Color3.fromRGB(255, 255, 255)
		end
	elseif n:sub(1, 5) == "Gate_" then
		for _, d in c:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "Accent" then
				d.Color = LUFFY_RED
			elseif d:IsA("TextLabel") then
				local needs = d.Text:match("\n(.*)$") or ""
				d.Text = TITLE .. "\n" .. needs
			end
		end
	end
end

return string.format("zone 3 Grand Line: %d parts in Scenery.Zone_%s (%d dock parts, %d trees)", #partsOf(root), ID, #partsOf(docks), #trees:GetChildren())
