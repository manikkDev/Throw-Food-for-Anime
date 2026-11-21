-- zone_02_demon_slayer.luau - Studio EDIT mode. Builds zone 2, "Demon Slayer Corps", in the single
-- lane: z 520..880, lane floor y -48 (config World.LaneY), lane edges x = +-160. Safe to run again:
-- it clears what it made (Map.Scenery.Zone_<id>) and rebuilds; the first run archives the old pirate
-- harbor dressing in ServerStorage.MapArchive.Zone2_pirate_harbor_v1 (never delete).
--
-- The picture: a mountain pass. Dark mossy rock either side, wisteria spilling over its ledges.
--   * the floor is Tanjiro's haori: green and black checks, crimson kerbs
--   * +X (left from the throw stage): the Mugen Train, a locomotive and two carriages on rails
--     under the cliff, smoke at the stack, a wooden platform with its station board
--   * -X: a Taisho mansion (the Butterfly Estate), a sword monument, and the zone's
--     landmark, one giant wisteria on the ledge at the far end
-- The walls join zone 1's at z 520 (same heights there) and run on into zone 3's at 880.
--
-- Needs ServerStorage.StoreAssets.Zone02_DemonSlayer: Locomotive, Carriage, Mansion, Cedar, MossRock,
-- Wisteria, all made with Studio's mesh generator ("..., anime game art style, hand painted texture"),
-- then squared with square_templates.luau: they front to -Z.
-- Run: python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --dm Edit --file <this file>
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local T = workspace.Terrain
local map = workspace.Map
local KIT = RS.Assets.Kit
local SRC = SS.StoreAssets.Zone02_DemonSlayer
local ID = "pirate_harbor" -- the zone's id in config until the anime zone data lands
local TITLE = "DEMON SLAYER CORPS"
local LY, HALF, Z0, Z1 = -48, 160, 520, 880
local DO_TERRAIN = true
local rng = Random.new(2207)

local CHECK_GREEN = Color3.fromRGB(47, 163, 107)
local CHECK_BLACK = Color3.fromRGB(36, 39, 46)
local CRIMSON = Color3.fromRGB(179, 38, 46)
local WISTERIA = Color3.fromRGB(155, 107, 223)
local WOOD = Color3.fromRGB(122, 84, 56)
local WOOD_DARK = Color3.fromRGB(74, 50, 38)
local IRON = Color3.fromRGB(52, 54, 62)

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
-- every template's pivot is the middle of its base: a thing is placed by its pivot
local function make(parent: Instance, template: Instance, scale: number, yaw: number, at: Vector3): Model
	local m = template:Clone() :: Model
	m:ScaleTo(m:GetScale() * scale)
	m:PivotTo(CFrame.new(at) * CFrame.Angles(0, math.rad(yaw), 0))
	still(m)
	m.Parent = parent
	return m
end

-- ---------------------------------------------------------------------------------- the old dressing
local lanes, scenery = map.Lanes, map.Scenery
local archive = SS:FindFirstChild("MapArchive") or folder(SS, "MapArchive")
if not archive:FindFirstChild("Zone2_pirate_harbor_v1") then
	local old = folder(archive, "Zone2_pirate_harbor_v1")
	old:SetAttribute("Note", "Zone 2 before the Demon Slayer rework (2026-11-22). Never delete.")
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
root:SetAttribute("Theme", "Demon Slayer Corps, zone_02_demon_slayer.luau")

-- ---------------------------------------------------------------------------------- the canyon
-- The same shape either side: terrace, a rise, a ledge, a rise, the top. NOW is this zone's numbers,
-- PREV is zone 1's at z 520 (its far end): the first 44 studs blend from one to the other so the
-- walls run on without a step.
local NOW = {
	face = { [-1] = 236, [1] = 234 },
	rise = { [-1] = 6, [1] = 6 },
	ledgeW = { [-1] = 26, [1] = 30 },
	ledgeY = { [-1] = 6, [1] = 12 },
	top = { [-1] = 68, [1] = 60 },
}
local PREV = {
	face = { [-1] = 240, [1] = 228 },
	rise = { [-1] = 5, [1] = 6 },
	ledgeW = { [-1] = 9, [1] = 34 },
	ledgeY = { [-1] = -18, [1] = 8 },
	top = { [-1] = 80, [1] = 56 },
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
	-- (no fall at the far end: zone 3's walls carry on from z 880)
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
	T:SetMaterialColor(Enum.Material.Basalt, Color3.fromRGB(96, 102, 124)) -- the pass's rock: dark, blue-grey
	local Y0, Y1 = -56, 124
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
					-- a voxel's fill is its distance to the surface: steep ground stays smooth
					local gx = (profile(side, ax + 2, z, outer) - profile(side, ax - 2, z, outer)) / 4
					local gz = (profile(side, ax, z + 2, outerHeight(side, z + 2)) - profile(side, ax, z - 2, outerHeight(side, z - 2))) / 4
					local steep = gx * gx + gz * gz
					local spread = 4 * math.sqrt(1 + math.min(steep, 30))
					for iy = 1, ny do
						local yb = Y0 + (iy - 1) * 4
						local o = math.clamp(0.5 + (h - (yb + 2)) / spread, 0, 1)
						if o > 0.02 then
							-- zone 1's tan rock gives way to this zone's dark rock over the first 28 studs
							local mine = (z - Z0) / 28 + 0.6 * math.noise(z / 7, yb / 7, ax / 7) > 0.5
							local m = if mine then Enum.Material.Basalt else Enum.Material.Slate
							if kind == "terrace" and yb < h + 1 then
								m = if mine then Enum.Material.LeafyGrass else Enum.Material.Ground
							elseif kind == "level" and steep < 0.5 and yb + 4 > h - 6 then
								m = Enum.Material.LeafyGrass
							end
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

local buildings = folder(root, "Buildings")
local train = folder(root, "Train")
local props = folder(root, "Props")
local trees = folder(root, "Trees")
local function ledgeAx(side: number): number
	return NOW.face[side] + NOW.rise[side] + NOW.ledgeW[side] / 2
end
local function rimAx(side: number): number
	return NOW.face[side] + NOW.rise[side] + NOW.ledgeW[side] + 26
end

-- ---------------------------------------------------------------------------------- the Mugen Train (+X)
local TX = 199 -- the track's centre line
local BED = LY + 2.4
-- The locomotive and the carriage were generated apart, so their wheels are not one gauge:
-- measured from the meshes, the wheels stand 4.4 from the centre line on a 14.2-wide locomotive and
-- 2.7 on an 11.9-wide carriage. These two scales bring both to about 8.4, and a 2.4-wide rail there
-- carries both (and covers the short rails modelled under the carriage).
local LOCO, CAR = 2.2, 2.8
block(train, "RailBed", Vector3.new(36, 2.4, 240), CFrame.new(TX, LY + 1.2, 716), Color3.fromRGB(104, 100, 98), Enum.Material.Slate)
for _, dx in { -8.4, 8.4 } do
	block(train, "Rail", Vector3.new(2.4, 1.5, 240), CFrame.new(TX + dx, BED + 0.75, 716), IRON, Enum.Material.Metal)
end
for z = 600, 832, 8 do
	block(train, "Sleeper", Vector3.new(26, 0.7, 2.6), CFrame.new(TX, BED + 0.3, z), WOOD_DARK, Enum.Material.Wood).CastShadow = false
end
-- squared templates front to -Z: no turn, and the train heads for the throw stage
still(make(train, SRC.Locomotive, LOCO, 0, Vector3.new(TX, BED + 1.4, 632)), true)
for _, z in { 705, 787 } do
	still(make(train, SRC.Carriage, CAR, 0, Vector3.new(TX, BED + 0.1, z)), true)
end
local stack = block(train, "Stack", Vector3.new(2, 2, 2), CFrame.new(TX, BED + 46, 612), IRON)
stack.Transparency = 1
stack.CastShadow = false
local smoke = Instance.new("ParticleEmitter")
smoke.Name = "Smoke"
smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
smoke.Color = ColorSequence.new(Color3.fromRGB(236, 236, 240), Color3.fromRGB(150, 150, 160))
smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 13) })
smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.7, 0.6), NumberSequenceKeypoint.new(1, 1) })
smoke.Lifetime = NumberRange.new(4, 6)
smoke.Rate = 7
smoke.Speed = NumberRange.new(7, 10)
smoke.EmissionDirection = Enum.NormalId.Top
smoke.SpreadAngle = Vector2.new(10, 10)
smoke.Acceleration = Vector3.new(0, 1, 5)
smoke.RotSpeed = NumberRange.new(-30, 30)
smoke.Parent = stack
-- the platform and its station board
block(train, "Platform", Vector3.new(13, 5, 170), CFrame.new(172.5, LY + 2.5, 728), WOOD, Enum.Material.WoodPlanks)
block(train, "PlatformEdge", Vector3.new(1.4, 5.4, 170), CFrame.new(179.6, LY + 2.7, 728), Color3.fromRGB(232, 222, 200), Enum.Material.Concrete)
for _, z in { 660, 796 } do
	local m = make(props, KIT.Prop_store_LampPost, 1.9, -90, Vector3.new(172, LY + 5, z))
	still(m, false)
end
for _, z in { 714, 742 } do
	block(train, "SignPost", Vector3.new(1.2, 16, 1.2), CFrame.new(170, LY + 13, z), WOOD_DARK, Enum.Material.Wood)
end
local board = block(train, "StationBoard", Vector3.new(0.8, 9, 30), CFrame.new(170, LY + 18, 728), Color3.fromRGB(244, 236, 214), Enum.Material.Wood)
local gui = Instance.new("SurfaceGui")
gui.Face = Enum.NormalId.Left -- the lane's side
gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
gui.PixelsPerStud = 20
gui.LightInfluence = 1
gui.Parent = board
local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1, 1)
label.BackgroundTransparency = 1
label.Text = "無限"
label.TextScaled = true
label.Font = Enum.Font.SourceSansBold
label.TextColor3 = Color3.fromRGB(34, 30, 30)
label.Parent = gui
block(train, "BoardFrame", Vector3.new(1.2, 10.4, 31.4), CFrame.new(170.3, LY + 18, 728), WOOD_DARK, Enum.Material.Wood)

-- ---------------------------------------------------------------------------------- the estate (-X)
-- squared templates front to -Z: a quarter turn puts the mansion's steps to the lane
local MANSION = 1.5
still(make(buildings, SRC.Mansion, MANSION, -90, Vector3.new(-(170 + 42 * MANSION / 2), LY, 700)), true)
local function kit(name: string, scale: number, x: number, z: number, yaw: number, y: number?)
	local template = KIT:FindFirstChild(name)
	if template then
		make(props, template, scale, yaw, Vector3.new(x, y or LY, z))
	end
end
for _, z in { 630, 770 } do -- clear of the banners beside them
	kit("Prop_store_StoneLantern", 1.7, -166, z, 0)
end
-- the Corps' banner, white on black, read from the lane
local function corps(x: number, z: number)
	local side = if x > 0 then 1 else -1
	block(props, "BannerPole", Vector3.new(1, 30, 1), CFrame.new(x, LY + 15, z), WOOD_DARK, Enum.Material.Wood)
	block(props, "BannerArm", Vector3.new(1, 1, 10), CFrame.new(x, LY + 29, z + 4.5), WOOD_DARK, Enum.Material.Wood)
	local cloth = block(props, "CorpsBanner", Vector3.new(0.3, 20, 8), CFrame.new(x, LY + 18.4, z + 5), Color3.fromRGB(26, 26, 32), Enum.Material.Fabric)
	local g = Instance.new("SurfaceGui")
	g.Face = if side > 0 then Enum.NormalId.Left else Enum.NormalId.Right
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 20
	g.Parent = cloth
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = "滅"
	t.TextScaled = true
	t.Font = Enum.Font.SourceSansBold
	t.TextColor3 = Color3.fromRGB(245, 245, 245)
	t.Parent = g
end
corps(-164, 644) -- clear of the mansion's front (it spans z 659..741)
corps(-164, 746)
corps(164, 608)
corps(164, 838)
kit("Prop_samurai_castle_KatanaMonument", 2.6, -178, 790, 0)
kit("Prop_store_StoneLantern", 1.7, 166, 600, 0)
kit("Prop_store_StoneLantern", 1.7, 166, 836, 0)

-- ---------------------------------------------------------------------------------- wisteria, cedars, rock
local function plant(template: Instance, side: number, ax: number, z: number, scale: number, y: number?): Model
	local m = make(trees, template, scale, rng:NextInteger(0, 359), Vector3.new(side * ax, y or (ground(side, ax, z) - 0.8), z))
	still(m, scale > 1.2)
	return m
end
-- the landmark: one giant wisteria on the far ledge of the estate's side
plant(SRC.Wisteria, -1, ledgeAx(-1) + 2, 826, 2.6)
for _, side in { -1, 1 } do
	-- wisteria along the ledges, cedars on the rims
	for z = 566, 850, 48 do
		if not (side < 0 and z > 790) then
			plant(SRC.Wisteria, side, ledgeAx(side) + rng:NextNumber(-3, 3), z + rng:NextNumber(-8, 8), rng:NextNumber(1.0, 1.35))
		end
	end
	for z = 548, 860, 32 do
		plant(SRC.Cedar, side, rimAx(side) + rng:NextNumber(0, 22), z + rng:NextNumber(-8, 8), rng:NextNumber(1.4, 2.0))
	end
	-- mossy rock at the cliff's foot
	for _, z in { 572, 618, 846 } do
		plant(SRC.MossRock, side, NOW.face[side] - 3, z + rng:NextNumber(-6, 6), rng:NextNumber(0.9, 1.5), LY - 2)
	end
end
plant(SRC.MossRock, -1, 232, 752, 1.2, LY - 2)
plant(SRC.MossRock, 1, 222, 840, 1.3, LY - 2)
-- street level, either end of the estate and beyond the train
plant(SRC.Wisteria, -1, 204, 628, 1.2, LY)
plant(SRC.Wisteria, -1, 206, 772, 1.2, LY)
plant(SRC.Wisteria, 1, 180, 852, 1.1, LY)
plant(SRC.Cedar, 1, 216, 596, 1.0, LY)

-- petals on the wind
local fx = folder(root, "Fx")
for _, z in { 590, 680, 770, 850 } do
	local source = block(fx, "PetalSource", Vector3.new(300, 1, 70), CFrame.new(0, LY + 84, z), Color3.new(1, 1, 1))
	source.Transparency = 1
	source.CastShadow = false
	local e = Instance.new("ParticleEmitter")
	e.Name = "Petals"
	e.Texture = "rbxassetid://5057182105"
	e.Color = ColorSequence.new(Color3.fromRGB(226, 180, 255), Color3.fromRGB(190, 140, 255))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.1), NumberSequenceKeypoint.new(1, 1.6) })
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.1, 0),
		NumberSequenceKeypoint.new(0.85, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(9, 13)
	e.Rate = 6
	e.Speed = NumberRange.new(5, 9)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.SpreadAngle = Vector2.new(25, 25)
	e.Acceleration = Vector3.new(-2.5, -1, 1.5)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-110, 110)
	e.LightEmission = 0.75 -- the texture is warm: without this a purple tint comes out brown
	e.Parent = source
end

-- ---------------------------------------------------------------------------------- floor and gate
for _, c in lanes["Zone_" .. ID]:GetChildren() do
	local n = c.Name
	if c:IsA("BasePart") then
		if n:sub(1, 5) == "Strip" then
			-- green and black checks: the next tile and the next track both swap
			local tile = math.floor((c.Position.Z - 526) / 44.25 + 0.01)
			local track = math.floor(c.Position.X / 56 + 0.5)
			local green = (tile + track) % 2 == 0
			c.Color = if green then CHECK_GREEN else CHECK_BLACK
			local tex = c:FindFirstChildWhichIsA("Texture")
			if tex then
				tex.Color3 = if green then Color3.fromRGB(120, 214, 164) else Color3.fromRGB(78, 84, 96)
			end
		elseif n:sub(1, 4) == "Kerb" then
			c.Color = CRIMSON
		elseif n:sub(1, 6) == "Paving" or n == "MarginPaving" then
			c.Color = Color3.fromRGB(112, 116, 128)
			local tex = c:FindFirstChildWhichIsA("Texture")
			if tex then
				tex.Color3 = Color3.fromRGB(164, 168, 180)
			end
		elseif n:sub(1, 12) == "DistanceBand" then
			c.Color = Color3.fromRGB(250, 246, 236)
		end
	elseif n:sub(1, 5) == "Gate_" then
		for _, d in c:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "Accent" then
				d.Color = WISTERIA
			elseif d:IsA("TextLabel") then
				local needs = d.Text:match("\n(.*)$") or ""
				d.Text = TITLE .. "\n" .. needs
			end
		end
	end
end

return string.format("zone 2 Demon Slayer: %d parts in Scenery.Zone_%s (%d train, %d trees and rocks)", #partsOf(root), ID, #partsOf(train), #trees:GetChildren())
