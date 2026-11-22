-- zone_lib.luau - the shared half of every zone builder from zone 4 on. Never run alone:
-- `python tools/studio/zones/run_zone.py <n>` joins it to zone_<nn>_*.luau and runs the pair in
-- Studio (edit mode). The zone file calls begin{...}, places its own things with the helpers here,
-- and ends with `return finish()`. Zones 1 and 2 were written before this and stand alone.
--
-- A zone is 360 studs of the single lane: z0 = 160 + (n - 1) * 360. Lane floor y -48, lane edges
-- x = +-160. begin{} archives the old dressing once (ServerStorage.MapArchive, never delete), clears
-- Map.Scenery.Zone_<id> and writes the terrain walls: terrace (or sea), a rise, a ledge, a rise, the
-- top. `now` is the zone's numbers, `prev` the previous zone's, so the walls run on without a step.
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local T = workspace.Terrain
local map = workspace.Map
local KIT = RS.Assets.Kit
local STORE = SS.StoreAssets
local lanes, scenery = map.Lanes, map.Scenery
local LY, HALF, OUTER = -48, 160, 368
-- Smooth terrain written level at LY shows (and collides) 2 studs higher: a full voxel under an
-- empty one puts the surface at the empty one's middle. TERRACE is where a terrace's ground really
-- is; LY stays the lane's floor. (Paving laid at LY + 0.35 was invisible, under the terrain.)
local TERRACE = LY + 2

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
local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
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
-- cf's Y axis is the cylinder's axis
local function cylinder(
	parent: Instance,
	name: string,
	diameter: number,
	length: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = block(
		parent,
		name,
		Vector3.new(length, diameter, diameter),
		cf * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end
-- Every template's pivot is the middle of its base and it fronts to -Z (store_generated.py squares
-- generated meshes): a thing is placed by its pivot, never by its parts' boxes.
local function make(
	parent: Instance,
	template: Instance,
	scale: number,
	yaw: number,
	at: Vector3
): Model
	local m = template:Clone() :: Model
	m:ScaleTo(m:GetScale() * scale)
	m:PivotTo(CFrame.new(at) * CFrame.Angles(0, math.rad(yaw), 0))
	still(m, true)
	m.Parent = parent
	return m
end
-- the yaw that turns a template's front to the lane: on the +X wall the lane is at -X
local function facing(side: number): number
	return if side > 0 then 90 else -90
end
-- words on a board: `face` is the side they are read from
local function words(
	part: BasePart,
	face: Enum.NormalId,
	text: string,
	color: Color3,
	font: Enum.Font?
)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	-- scaled text stops growing at 100 px: size the canvas so 100 px is the face's short side,
	-- or a glyph on a 24-stud board comes out 5 studs tall (zone 11's katakana did)
	local s = part.Size
	local short = if face == Enum.NormalId.Left or face == Enum.NormalId.Right
		then math.min(s.Z, s.Y)
		elseif face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then math.min(
			s.X,
			s.Z
		)
		else math.min(s.X, s.Y)
	g.PixelsPerStud = math.min(20, 100 / short)
	g.LightInfluence = 1
	g.Parent = part
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = font or Enum.Font.FredokaOne
	t.TextColor3 = color
	t.Parent = g
end

-- ---------------------------------------------------------------------------------- the zone
local ID: string, Z0: number, Z1: number
local SRC: Instance
local rng: Random
local root: Folder
local NOW: any, PREV: any
-- every placed model claims its footprint here; see "nothing may overlap" below
local claims: { any } = {}
local faults: { string } = {}
local spec: any

local function profile(side: number, ax: number, z: number, outerH: number): (number, string)
	local t = smooth((z - Z0) / 44)
	local function v(key: string): number
		return lerp(PREV[key][side], NOW[key][side], t)
	end
	-- spec.wobble (default 1) scales how far the wall's foot wanders: a built street wants it near 0
	local wobble = (
		6 * math.noise(z / 46, side * 3.1, 0.5) + 3 * math.noise(z / 13, side * 9.7, 0.2)
	)
		* t
		* (spec.wobble or 1)
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
	if spec.fall and h > -2 then
		-- the last zone built: what stands above the lobby's level comes down at its far end
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
	local _, occ = T:ReadVoxels(
		Region3.new(Vector3.new(x, -32, key * 4), Vector3.new(x + 4, 100, key * 4 + 4)),
		4
	)
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
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { T }
groundParams.IgnoreWater = true
-- the ground's real height at a point: the terrain itself, as it stands. (The profile is only what
-- was asked for: the terrain it makes sits up to 2 studs off it.) run_zone.py builds twice when it
-- writes terrain, so that everything is placed on the terrain as written.
local function ground(side: number, ax: number, z: number): number
	local hit =
		workspace:Raycast(Vector3.new(side * ax, 240, z), Vector3.new(0, -400, 0), groundParams)
	if hit then
		return hit.Position.Y
	end
	return (profile(side, ax, z, outerHeight(side, z)))
end
local function ledgeAx(side: number): number
	return NOW.face[side] + NOW.rise[side] + NOW.ledgeW[side] / 2
end
-- the clifftop's edge: trees stand right on it, or the cliff shows a bare ridge to the lane
local function rimAx(side: number): number
	return NOW.face[side] + NOW.rise[side] + NOW.ledgeW[side] + 16
end

-- where the wall's foot is at z (the terrace ends there), and the nearest it comes over a span
local function wallFoot(side: number, z: number): number
	local t = smooth((z - Z0) / 44)
	local wobble = (
		6 * math.noise(z / 46, side * 3.1, 0.5) + 3 * math.noise(z / 13, side * 9.7, 0.2)
	)
		* t
		* (spec.wobble or 1)
	return lerp(PREV.face[side], NOW.face[side], t) + wobble
end
local function footOver(side: number, z0: number, z1: number): number
	local least = math.huge
	for z = z0, z1, 2 do
		least = math.min(least, wallFoot(side, z))
	end
	return math.min(least, wallFoot(side, z1))
end

local function writeTerrain()
	local M = spec.mats
	for material, color in spec.colors or {} do
		T:SetMaterialColor(material, color)
	end
	local SEABED, SURFACE = LY - 8, LY - 1.5
	local sea0, sea1 = Z0 + 24, Z1 - (spec.seaEnd or 12)
	local Y0, Y1 = -64, 180
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
					local gx = (profile(side, ax + 2, z, outer) - profile(side, ax - 2, z, outer))
						/ 4
					local gz = (
						profile(side, ax, z + 2, outerHeight(side, z + 2))
						- profile(side, ax, z - 2, outerHeight(side, z - 2))
					) / 4
					local steep = gx * gx + gz * gz
					local spread = 4 * math.sqrt(1 + math.min(steep, 30))
					local isSea = spec.sea and kind == "terrace" and z > sea0 and z < sea1
					for iy = 1, ny do
						local yb = Y0 + (iy - 1) * 4
						local o = math.clamp(0.5 + (h - (yb + 2)) / spread, 0, 1)
						-- the previous zone's materials give way to this zone's over the first 28 studs
						local mine = (z - Z0) / 28 + 0.6 * math.noise(z / 7, yb / 7, ax / 7) > 0.5
						local m: Enum.Material
						if isSea then
							if yb + 4 <= SEABED then
								m, o = Enum.Material.Sand, 1
							else
								m, o = Enum.Material.Water, math.clamp((SURFACE - yb) / 4, 0, 1)
							end
						elseif kind == "terrace" then
							m = if mine then M.terrace else M.prevTerrace
						elseif not mine then
							m = M.prevRock
						else
							m = M.rock
							-- strata: spec.strata = { every, thick, wander } (default 30, 12, 5: broad soft bands;
							-- thin level ones such as { 16, 4, 1.5 } read as bedded rock)
							local st = spec.strata or { 30, 12, 5 }
							if
								M.band
								and (yb + st[3] * math.noise(z / 30, ax / 30, 8.8)) % st[1]
									< st[2]
							then
								m = M.band
							end
						end
						if not isSea and kind == "level" and steep < 0.5 and yb + 4 > h - 6 then
							m = if h < LY + 24 then M.ledge else M.top
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
			T:WriteVoxels(
				Region3.new(Vector3.new(xa, Y0, z0), Vector3.new(xa + (OUTER - HALF), Y1, z1)),
				4,
				mats,
				occs
			)
		end
	end
end

-- begin{ n, id, src, now, prev, mats = { rock, band?, prevRock, terrace, prevTerrace, ledge, top },
--        colors?, sea?, fall? }
local function begin(s: any): Folder
	if workspace.Map:GetAttribute("LaneSlim") and HALF > 100 then
		-- the lane is 200 wide since lane_slim.luau (2026-11-22): this builder still lays the 320-wide one
		error(
			"this zone builder predates the 3-track lane: rewrite it on the new cross-section first (design/plan/10-slim-map.md, phase 3)"
		)
	end
	spec = s
	ID = s.id
	Z0, Z1 = 160 + (s.n - 1) * 360, 160 + s.n * 360
	NOW, PREV = s.now, s.prev
	SRC = STORE:FindFirstChild(s.src) or folder(STORE, s.src)
	rng = Random.new(1000 * s.n + 307)
	local old = {
		lanes:FindFirstChild("Walls_" .. ID),
		lanes:FindFirstChild("Facade_" .. ID),
		scenery:FindFirstChild("Town_" .. ID),
	}
	root = scenery:FindFirstChild("Zone_" .. ID) or folder(scenery, "Zone_" .. ID)
	local archive = SS:FindFirstChild("MapArchive") or folder(SS, "MapArchive")
	local name = string.format("Zone%d_%s_v1", s.n, ID)
	if not archive:FindFirstChild(name) then
		local a = folder(archive, name)
		a:SetAttribute("Note", "Zone " .. s.n .. " before its anime rework. Never delete.")
		for _, f in { old[1], old[2], old[3], root } do
			if f then
				f:Clone().Parent = a
			end
		end
		local hills = folder(a, "Hills")
		for _, u in scenery.Hills:GetDescendants() do
			if u:IsA("Model") and u.Parent and u.Name:sub(1, 5) == "Prop_" then
				local p = u:GetPivot().Position
				if math.abs(p.X) < 372 and p.Z > Z0 - 4 and p.Z < Z1 + 14 then
					u.Parent = hills
				end
			end
		end
	end
	for _, f in { old[1], old[2], old[3], root } do
		if f then
			f:ClearAllChildren()
		end
	end
	root:SetAttribute("Theme", s.title)
	root:SetAttribute("Z0", Z0)
	-- the gates' pillars stand IN the terraces (x 171..236, 35 either side of the gate's pivot, which
	-- is 45 studs into its zone): this zone's and the next one's are claimed before anything is placed
	table.clear(claims)
	table.clear(faults)
	for _, k in lanes:GetChildren() do
		if k.Name:sub(1, 5) == "Zone_" then
			for _, g in k:GetChildren() do
				if g.Name:sub(1, 5) == "Gate_" then
					local gz = g:GetPivot().Position.Z
					if gz > Z0 - 60 and gz < Z1 + 120 then
						for _, side in { -1, 1 } do
							table.insert(claims, {
								cx = side * 203.5,
								cz = gz,
								hx = 32.5,
								hz = 35,
								rx = 1,
								rz = 0,
								y0 = LY - 20,
								y1 = 220,
								name = "a gate pillar",
							})
						end
					end
				end
			end
		end
	end
	if DO_TERRAIN then
		writeTerrain()
	end
	return root
end

-- ---------------------------------------------------------------------------------- nothing may overlap
-- A claim is a box on the ground plan, turned with its model, with a height range. place() is
-- make() + claim and records a fault when it crosses an older claim; scatter() and plant() only
-- put things where the ground is free. run_zone.py audit checks the result again from outside.
local function sizeOf(template: Instance): Vector3
	local ts = template:GetAttribute("TrueSize")
	if ts then
		return ts
	end
	local _, size = (template :: Model):GetBoundingBox()
	return size
end
local function crosses(a: any, b: any): boolean
	if a.y0 >= b.y1 or b.y0 >= a.y1 then
		return false
	end
	local dx, dz = b.cx - a.cx, b.cz - a.cz
	for _, ax in { { a.rx, a.rz }, { -a.rz, a.rx }, { b.rx, b.rz }, { -b.rz, b.rx } } do
		local ra = a.hx * math.abs(a.rx * ax[1] + a.rz * ax[2])
			+ a.hz * math.abs(-a.rz * ax[1] + a.rx * ax[2])
		local rb = b.hx * math.abs(b.rx * ax[1] + b.rz * ax[2])
			+ b.hz * math.abs(-b.rz * ax[1] + b.rx * ax[2])
		if math.abs(dx * ax[1] + dz * ax[2]) >= ra + rb then
			return false
		end
	end
	return true
end
local function blockedBy(r: any): any?
	for _, c in claims do
		if crosses(r, c) then
			return c
		end
	end
	return nil
end
local function rectOf(m: Model, fit: number?): any
	local cf, size = m:GetBoundingBox()
	local r = cf.RightVector
	local len = math.max(math.sqrt(r.X * r.X + r.Z * r.Z), 1e-4)
	local k = fit or 0.94 -- a mesh never fills the corners of its box
	return {
		cx = cf.Position.X,
		cz = cf.Position.Z,
		hx = size.X / 2 * k,
		hz = size.Z / 2 * k,
		rx = r.X / len,
		rz = r.Z / len,
		y0 = cf.Position.Y - size.Y / 2,
		y1 = cf.Position.Y + size.Y / 2,
		name = m.Name,
	}
end
local function rectAt(
	x: number,
	z: number,
	hx: number,
	hz: number,
	yaw: number,
	y0: number,
	y1: number,
	name: string
): any
	local a = math.rad(yaw)
	return {
		cx = x,
		cz = z,
		hx = hx,
		hz = hz,
		rx = math.cos(a),
		rz = -math.sin(a),
		y0 = y0,
		y1 = y1,
		name = name,
	}
end
-- make() + claim. opts: fit (how much of its box the model claims), over = true (crossing is meant)
local function place(
	parent: Instance,
	template: Instance,
	scale: number,
	yaw: number,
	at: Vector3,
	opts: any?
): Model
	local m = make(parent, template, scale, yaw, at)
	local r = rectOf(m, opts and opts.fit)
	local hit = blockedBy(r)
	if hit and not (opts and opts.over) then
		table.insert(
			faults,
			string.format("%s at (%.0f, %.0f) crosses %s", m.Name, at.X, at.Z, hit.name)
		)
	end
	table.insert(claims, r)
	return m
end
-- place() only where the ground is free: for dressing that may be dropped when there is no room
local function try(
	parent: Instance,
	template: Instance,
	scale: number,
	yaw: number,
	at: Vector3,
	opts: any?
): Model?
	local size = sizeOf(template) * scale
	local k = (opts and opts.fit) or 0.94
	local r =
		rectAt(at.X, at.Z, size.X / 2 * k, size.Z / 2 * k, yaw, at.Y, at.Y + size.Y, template.Name)
	if blockedBy(r) then
		return nil
	end
	local m = make(parent, template, scale, yaw, at)
	table.insert(claims, r)
	return m
end
-- steps from (ax0, y0) up to (ax1, y1) across a terrace, z0..z1 wide: n blocks, each one solid to the ground
local function steps(
	parent: Instance,
	side: number,
	ax0: number,
	ax1: number,
	z0: number,
	z1: number,
	y0: number,
	y1: number,
	n: number,
	color: Color3,
	material: Enum.Material?
)
	for i = 1, n do
		local a, b = ax0 + (ax1 - ax0) * (i - 1) / n, ax0 + (ax1 - ax0) * i / n
		local top = y0 + (y1 - y0) * i / n
		local base = math.min(y0, y1) - 3
		block(
			parent,
			"Step",
			Vector3.new(math.abs(b - a) + 0.2, top - base, z1 - z0),
			CFrame.new(side * (a + b) / 2, (top + base) / 2, (z0 + z1) / 2),
			color,
			material or Enum.Material.WoodPlanks
		)
	end
end
-- claims ground for something built from parts (a deck feature, a fountain)
local function reserve(
	x: number,
	z: number,
	hx: number,
	hz: number,
	y0: number,
	y1: number,
	name: string
)
	table.insert(claims, rectAt(x, z, hx, hz, 0, y0, y1, name))
end
-- a tree (or anything rooted): judged at its trunk, skipped where the ground is taken
local function plant(
	parent: Instance,
	template: Instance,
	side: number,
	ax: number,
	z: number,
	scale: number,
	y: number?
): Model?
	local size = sizeOf(template) * scale
	local base = y or (ground(side, ax, z) - 0.8)
	local r =
		rectAt(side * ax, z, size.X * 0.25, size.Z * 0.25, 0, base, base + size.Y, template.Name)
	if blockedBy(r) then
		return nil
	end
	local m =
		make(parent, template, scale, rng:NextInteger(0, 359), Vector3.new(side * ax, base, z))
	m:SetAttribute("Soft", true)
	still(m, scale > 1.2)
	table.insert(claims, r)
	return m
end
-- scatter{ parent, templates, count, side, ax = { lo, hi }, z = { lo, hi }, scale = { lo, hi },
--          y?, sink?, yaw?, fit?, grow?, soft? }: random free spots in a region; returns how many went in
local function scatter(o: any): number
	local placed = 0
	for _ = 1, o.count * 14 do
		if placed >= o.count then
			break
		end
		local t = o.templates[rng:NextInteger(1, #o.templates)]
		local s = rng:NextNumber(o.scale[1], o.scale[2])
		local ax, z = rng:NextNumber(o.ax[1], o.ax[2]), rng:NextNumber(o.z[1], o.z[2])
		local size = sizeOf(t) * s
		local yaw = o.yaw or rng:NextInteger(0, 359)
		local base = o.y or (ground(o.side, ax, z) - (o.sink or 0.4))
		local k = o.fit or 0.9
		local r = rectAt(
			o.side * ax,
			z,
			size.X / 2 * k + (o.grow or 0),
			size.Z / 2 * k + (o.grow or 0),
			yaw,
			base,
			base + size.Y,
			t.Name
		)
		if not blockedBy(r) then
			local m = make(o.parent, t, s, yaw, Vector3.new(o.side * ax, base, z))
			if o.soft then
				m:SetAttribute("Soft", true)
			end
			if o.sunkOk then
				m:SetAttribute("SunkOk", o.sunkOk)
			end
			table.insert(claims, r)
			placed += 1
		end
	end
	return placed
end
-- row{ parent, side, z, list = { { template, scale, gapAfter? } }, front?, gap?, y?, backGap? }: buildings one
-- after another down a terrace, fronting the lane, never touching. `front` is the building line
-- (how far their faces stand from the middle of the lane); without it, or where a building is too
-- deep for it, the back of the building goes against the foot of the wall. Returns the z where the
-- row ended.
local function row(o: any): number
	local z = o.z
	for _, b in o.list do
		local size = sizeOf(b[1]) * b[2]
		local width, depth = size.X, size.Z -- turned to the lane, a model's X runs along it
		local foot = footOver(o.side, z, z + width) - 1.5 - (o.backGap or 0)
		local front = o.front
		if not front or front + depth > foot then
			front = foot - depth
		end
		place(
			o.parent,
			b[1],
			b[2],
			facing(o.side),
			Vector3.new(o.side * (front + depth / 2), o.y or (TERRACE - 0.3), z + width / 2),
			{ fit = 0.98 }
		)
		z += width + (b[3] or o.gap or 3)
	end
	return z
end
-- a slab of street, plaza or path on a terrace: bare terrain is never left as the ground.
-- The slab IS the ground where it lies: the terrain under it is cut away, because terrain is drawn
-- up to 2-4 studs above where its own voxels and raycasts put it (grass swells, hard materials are
-- drawn as blocks) and came up through a thin slab laid on top of it. Nobody walks on a terrace, so
-- only the look matters. The slab is 7 thick: its sides close the cut.
local function pave(
	parent: Instance,
	side: number,
	ax0: number,
	ax1: number,
	z0: number,
	z1: number,
	color: Color3,
	material: Enum.Material,
	top: number?
): Part
	local t = top or (TERRACE + 0.35)
	local p = block(
		parent,
		"Paving",
		Vector3.new(ax1 - ax0, 7, z1 - z0),
		CFrame.new(side * (ax0 + ax1) / 2, t - 3.5, (z0 + z1) / 2),
		color,
		material
	)
	p.CastShadow = false
	-- cut the terrain from 5 under the slab's top to well above it, a little inside the slab's edge
	local w, l = ax1 - ax0 - 1, z1 - z0 - 1
	if w > 4 and l > 4 then
		T:FillBlock(
			CFrame.new(side * (ax0 + ax1) / 2, t + 2.5, (z0 + z1) / 2),
			Vector3.new(w, 15, l),
			Enum.Material.Air
		)
	end
	return p
end
-- a painted mark on the ground (a road line, a court, a parking bay), just over the paving
local function paint(
	parent: Instance,
	side: number,
	ax0: number,
	ax1: number,
	z0: number,
	z1: number,
	color: Color3,
	top: number?
): Part
	local t = top or (TERRACE + 0.5)
	local p = block(
		parent,
		"Paint",
		Vector3.new(ax1 - ax0, 0.25, z1 - z0),
		CFrame.new(side * (ax0 + ax1) / 2, t - 0.12, (z0 + z1) / 2),
		color
	)
	p.CastShadow = false
	return p
end
-- a board with words: its front (the side the words are on) looks along cf's look vector
local function sign(
	parent: Instance,
	text: string,
	width: number,
	height: number,
	cf: CFrame,
	bg: Color3,
	fg: Color3,
	font: Enum.Font?
): Part
	local b = block(parent, "Sign", Vector3.new(width, height, 0.8), cf, bg)
	words(b, Enum.NormalId.Front, text, fg, font)
	return b
end
-- a line of posts and rails from (x0, z0) to (x1, z1) standing on y
local function fence(
	parent: Instance,
	x0: number,
	z0: number,
	x1: number,
	z1: number,
	y: number,
	height: number,
	color: Color3,
	material: Enum.Material?,
	step: number?
)
	local a, b = Vector3.new(x0, y, z0), Vector3.new(x1, y, z1)
	local len = (b - a).Magnitude
	local dir = CFrame.lookAt(a, b)
	local n = math.max(1, math.floor(len / (step or 8) + 0.5))
	for i = 0, n do
		block(
			parent,
			"FencePost",
			Vector3.new(0.9, height, 0.9),
			dir * CFrame.new(0, height / 2, -len * i / n),
			color,
			material or Enum.Material.Wood
		)
	end
	for _, h in { height * 0.9, height * 0.5 } do
		block(
			parent,
			"FenceRail",
			Vector3.new(0.5, 0.5, len),
			dir * CFrame.new(0, h, -len / 2),
			color,
			material or Enum.Material.Wood
		)
	end
end
-- a building with its lane-side face at frontAx and its middle at z, fronting the lane
local function building(
	parent: Instance,
	template: Instance,
	scale: number,
	side: number,
	frontAx: number,
	z: number,
	y: number?
): Model
	local depth = (template:GetAttribute("TrueSize") :: Vector3).Z * scale
	return place(
		parent,
		template,
		scale,
		facing(side),
		Vector3.new(side * (frontAx + depth / 2), y or LY, z)
	)
end
local function kit(parent: Instance, name: string, scale: number, at: Vector3, yaw: number): Model?
	local template = KIT:FindFirstChild(name)
	return if template then place(parent, template, scale, yaw, at) else nil
end
-- a row of buildings down one terrace: { template, scale, z offset from Z0, frontAx? }
local function street(parent: Instance, side: number, list: { any })
	for i, b in list do
		building(parent, b[1], b[2], side, b[4] or (168 + (i % 2) * 6), Z0 + b[3])
	end
end
-- lamps (any kit prop) down both of the lane's margins
local function lamps(parent: Instance, name: string, scale: number, step: number?)
	for z = Z0 + 96, Z1 - 24, step or 60 do
		for _, side in { -1, 1 } do
			local template = KIT:FindFirstChild(name)
			if template then
				local size = sizeOf(template) * scale
				local r = rectAt(side * 163, z, size.Z / 2, size.X / 2, 0, LY, LY + size.Y, name)
				if not blockedBy(r) then
					make(parent, template, scale, facing(side), Vector3.new(side * 163, LY, z))
					table.insert(claims, r)
				end
			end
		end
	end
end
-- trees on the rims and the ledges, bushes at the ledges' edge
local function forest(
	parent: Instance,
	templates: { Instance },
	bush: Instance?,
	rimStep: number?,
	rimScale: number?
)
	local function pick(): Instance
		return templates[rng:NextInteger(1, #templates)]
	end
	local s = rimScale or 1.6
	for _, side in { -1, 1 } do
		for z = Z0 + 40, Z1 - 20, rimStep or 32 do
			plant(
				parent,
				pick(),
				side,
				rimAx(side) + rng:NextNumber(-5, 8),
				z + rng:NextNumber(-8, 8),
				rng:NextNumber(s * 0.8, s * 1.2)
			)
		end
		if NOW.ledgeW[side] >= 20 then
			for z = Z0 + 60, Z1 - 30, 52 do
				plant(
					parent,
					pick(),
					side,
					ledgeAx(side) + rng:NextNumber(-5, 5),
					z + 24,
					rng:NextNumber(0.8, 1.1)
				)
				if bush then
					plant(parent, bush, side, ledgeAx(side) - 8, z + 6, 1.5)
				end
			end
		end
	end
end
-- a plank deck on posts (pier, boardwalk, stilt platform) between ax0..ax1 and z0..z1: its top at
-- `top`, its posts down to `foot`. rails = { lane = true, wall = true, z0 = true, z1 = true } fences
-- those edges. o: { planks, posts, step (post spacing), railHeight }
local function deck(
	parent: Instance,
	side: number,
	ax0: number,
	ax1: number,
	z0: number,
	z1: number,
	top: number,
	foot: number,
	o: any?,
	rails: any?
)
	local planks = (o and o.planks) or Color3.fromRGB(150, 106, 68)
	local dark = (o and o.posts) or Color3.fromRGB(92, 62, 44)
	local step = (o and o.step) or 16
	block(
		parent,
		"Deck",
		Vector3.new(ax1 - ax0, 1.4, z1 - z0),
		CFrame.new(side * (ax0 + ax1) / 2, top - 0.7, (z0 + z1) / 2),
		planks,
		Enum.Material.WoodPlanks
	)
	-- a darker beam under each long edge, so the deck has a thickness to it
	for _, ax in { ax0 + 0.6, ax1 - 0.6 } do
		block(
			parent,
			"DeckBeam",
			Vector3.new(1.2, 1.6, z1 - z0),
			CFrame.new(side * ax, top - 2.0, (z0 + z1) / 2),
			dark,
			Enum.Material.Wood
		)
	end
	local nx = math.max(1, math.floor((ax1 - ax0 - 3) / step + 0.5))
	local nz = math.max(1, math.floor((z1 - z0 - 3) / step + 0.5))
	for i = 0, nx do
		for j = 0, nz do
			if i == 0 or i == nx or j == 0 or j == nz then
				local ax = ax0 + 1.5 + (ax1 - ax0 - 3) * i / nx
				local z = z0 + 1.5 + (z1 - z0 - 3) * j / nz
				local p = block(
					parent,
					"DeckPost",
					Vector3.new(top + 2.2 - foot, 2.2, 2.2),
					CFrame.new(side * ax, (top + 2.2 + foot) / 2, z)
						* CFrame.Angles(0, 0, math.rad(90)),
					dark,
					Enum.Material.Wood
				)
				p.Shape = Enum.PartType.Cylinder
			end
		end
	end
	if rails then
		local h = (o and o.railHeight) or 3.4
		if rails.lane then
			fence(parent, side * (ax0 + 0.6), z0 + 2, side * (ax0 + 0.6), z1 - 2, top, h, dark)
		end
		if rails.wall then
			fence(parent, side * (ax1 - 0.6), z0 + 2, side * (ax1 - 0.6), z1 - 2, top, h, dark)
		end
		if rails.z0 then
			fence(parent, side * (ax0 + 2), z0 + 0.6, side * (ax1 - 2), z0 + 0.6, top, h, dark)
		end
		if rails.z1 then
			fence(parent, side * (ax0 + 2), z1 - 0.6, side * (ax1 - 2), z1 - 0.6, top, h, dark)
		end
	end
end
-- a waterfall down the wall at z: over the upper rise from the top, a stream across the ledge, a
-- second fall from the ledge to the terrace (or the sea). It follows the ground in short lengths
-- (one straight sheet from top to ledge ran inside the cliff, which bulges). Built parts and mist,
-- no script. Call it before trees are scattered: it claims its course.
local function waterfall(parent: Instance, side: number, z: number, width: number)
	local WATER = Color3.fromRGB(104, 196, 250)
	local FOAM = Color3.fromRGB(240, 250, 255)
	local a0 = NOW.face[side] + NOW.rise[side] -- the edge of the ledge over the terrace
	local a1 = a0 + NOW.ledgeW[side] -- where the upper rise starts
	local a2 = a1 + 10 -- the edge of the top
	local yFoot = if spec.sea then LY - 1.6 else LY + 0.2
	local function water(
		name: string,
		size: Vector3,
		cf: CFrame,
		color: Color3,
		transparency: number
	): Part
		local w = block(parent, name, size, cf, color, Enum.Material.SmoothPlastic)
		w.Transparency = transparency
		w.CastShadow = false
		return w
	end
	-- the course, from the river on the top down to the foot: points 2.4 studs proud of the ground
	local pts = {}
	for ax = a2 + 26, NOW.face[side] - 5, -2 do
		local y = if ax < NOW.face[side] then yFoot else ground(side, ax, z)
		-- on a steep stretch the sheet must stand off sideways, on a level one upwards
		local slope = math.abs(ground(side, ax + 1, z) - ground(side, ax - 1, z)) / 2
		local out = math.clamp(slope, 0, 3) * 0.8
		table.insert(
			pts,
			Vector3.new(
				side * (ax - out),
				y + 0.5 + math.clamp(1.6 - slope * 0.4, 0.3, 1.6) * 0.5,
				z
			)
		)
	end
	for i = 1, #pts - 1 do
		local p, q = pts[i], pts[i + 1]
		local len = (p - q).Magnitude
		local cf = CFrame.lookAt((p + q) / 2, q, Vector3.new(-side, 1, 0))
		water("Water", Vector3.new(width, 1.4, len + 0.8), cf, WATER, 0.1).Reflectance = 0.06
		if math.abs(p.Y - q.Y) > 1.5 then
			-- white water where it falls: broken streaks in five lanes, so it reads as moving water
			-- and not as a striped ribbon
			for k = -2, 2 do
				if (i + k) % 3 ~= 0 then
					water(
						"WhiteWater",
						Vector3.new(width * 0.07, 1.8, len + 0.8),
						cf * CFrame.new(k * width * 0.19 + ((i * 7 + k * 3) % 5 - 2) * 0.25, 0, 0),
						FOAM,
						0.3
					)
				end
			end
		end
	end
	local function foam(ax: number, y: number)
		local src =
			water("Foam", Vector3.new(width, 1, 4), CFrame.new(side * ax, y + 1.5, z), FOAM, 1)
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Color = ColorSequence.new(FOAM)
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 3),
			NumberSequenceKeypoint.new(1, 7),
		})
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		})
		e.Lifetime = NumberRange.new(1.2, 2.2)
		e.Rate = 10
		e.Speed = NumberRange.new(2, 5)
		e.SpreadAngle = Vector2.new(70, 70)
		e.EmissionDirection = Enum.NormalId.Top
		e.Acceleration = Vector3.new(0, 1.5, 0)
		e.Rotation = NumberRange.new(0, 360)
		e.LightEmission = 0.3
		e.Parent = src
	end
	local yLedge = ground(side, (a0 + a1) / 2, z)
	foam(a1 - 3, yLedge)
	foam(NOW.face[side] - 5, yFoot)
	reserve(
		side * (a0 + a1) / 2,
		z,
		(a1 - a0) / 2 + 3,
		width / 2 + 3,
		yLedge - 4,
		yLedge + 60,
		"the waterfall"
	)
	reserve(side * (a2 + 14), z, 16, width / 2 + 3, yLedge, yLedge + 200, "the river")
	reserve(
		side * (NOW.face[side] - 5),
		z,
		6,
		width / 2 + 2,
		LY - 12,
		LY + 20,
		"the foot of the waterfall"
	)
end
-- a grandstand built on a terrace, fitted to it: tiers stepping up from `front` to `back`, seat
-- rows broken by aisles, a low front wall, a roof on columns and beams.
-- o = { parent, side, z0, z1, front, back, tiers?, rise?, aisle?, base?, concrete, seat, seat2?,
--       wall, roof, steel }
local function grandstand(o: any)
	local side, z0, z1 = o.side, o.z0, o.z1
	local len, mid = z1 - z0, (z0 + z1) / 2
	local tiers = o.tiers or 8
	local depth = (o.back - o.front) / tiers
	local rise = o.rise or 5
	local base = o.base or (TERRACE + 0.35)
	local top = base + tiers * rise
	block(
		o.parent,
		"StandWall",
		Vector3.new(1.6, rise + 2.4, len),
		CFrame.new(side * (o.front - 0.8), base + (rise + 2.4) / 2, mid),
		o.wall
	)
	local n = math.max(1, math.floor(len / (o.aisle or 30) + 0.5))
	local seg = len / n
	for t = 1, tiers do
		local ax0 = o.front + (t - 1) * depth
		local y = base + t * rise
		-- each tier is solid to the ground: nothing shows through from the lane
		block(
			o.parent,
			"StandTier",
			Vector3.new(depth + 0.05, y - base, len),
			CFrame.new(side * (ax0 + depth / 2), (y + base) / 2, mid),
			o.concrete,
			Enum.Material.Concrete
		)
		for i = 0, n - 1 do
			local a, b = z0 + i * seg + 2.2, z0 + (i + 1) * seg - 2.2
			-- a row of seats: a bench with a back, in the stand's colours
			local color = if o.seat2 and (t + i) % 4 == 0 then o.seat2 else o.seat
			local bench = block(
				o.parent,
				"StandSeats",
				Vector3.new(depth * 0.5, 1.5, b - a),
				CFrame.new(side * (ax0 + depth * 0.58), y + 0.75, (a + b) / 2),
				color
			)
			bench.CastShadow = false
			local back = block(
				o.parent,
				"StandSeatBacks",
				Vector3.new(0.7, 2.6, b - a),
				CFrame.new(side * (ax0 + depth * 0.86), y + 2.2, (a + b) / 2),
				color
			)
			back.CastShadow = false
		end
	end
	-- the roof: a slab tipped up towards the pitch, on columns at the back and raking beams
	local roofW = (o.back - o.front) * 0.86
	local roofAx = o.back - roofW / 2 + 1
	local roofY = top + 13
	local tip = math.rad(side * 7)
	block(
		o.parent,
		"StandRoof",
		Vector3.new(roofW, 1.8, len + 6),
		CFrame.new(side * roofAx, roofY, mid) * CFrame.Angles(0, 0, tip),
		o.roof,
		Enum.Material.Metal
	)
	block(
		o.parent,
		"StandRoofEdge",
		Vector3.new(2.2, 3, len + 6),
		CFrame.new(
			side * (roofAx - roofW / 2 + 0.6),
			roofY + roofW / 2 * math.sin(math.rad(7)) + 0.4,
			mid
		),
		o.wall
	)
	local cols = math.max(2, math.floor(len / 34 + 0.5) + 1)
	for i = 0, cols - 1 do
		local z = z0 + 3 + (len - 6) * i / (cols - 1)
		block(
			o.parent,
			"StandColumn",
			Vector3.new(2.4, roofY - top + 2, 2.4),
			CFrame.new(side * (o.back - 2.4), (roofY + top) / 2, z),
			o.steel,
			Enum.Material.Metal
		)
		block(
			o.parent,
			"StandBeam",
			Vector3.new(roofW * 0.96, 1.6, 1.6),
			CFrame.new(side * roofAx, roofY - 1.6, z) * CFrame.Angles(0, 0, tip),
			o.steel,
			Enum.Material.Metal
		)
	end
	reserve(
		side * (o.front + o.back) / 2,
		mid,
		(o.back - o.front) / 2 + 1,
		len / 2 + 3,
		base - 4,
		roofY + 20,
		"a grandstand"
	)
end
-- a level footing under a model that stands on sloping ground (a rim, a beach): a block the size
-- of its footprint from just under its base down into the slope, so no edge floats or is buried
local function footing(
	parent: Instance,
	m: Model,
	color: Color3,
	material: Enum.Material?,
	depth: number?,
	grow: number?
): Part
	local cf, size = m:GetBoundingBox()
	local d = depth or 16
	local g = grow or 1.06
	local base = cf.Position.Y - size.Y / 2
	local p = block(
		parent,
		"Footing",
		Vector3.new(size.X * g, d, size.Z * g),
		cf.Rotation + Vector3.new(cf.Position.X, base + 0.3 - d / 2, cf.Position.Z),
		color,
		material or Enum.Material.Slate
	)
	m:SetAttribute("SunkOk", 40) -- the slope may rise past its base: the footing takes it
	return p
end
-- marks a model the audit must not judge against the ground under it (a ship, a flier)
local function afloat(m: Model): Model
	m:SetAttribute("Floats", true)
	return m
end
-- a model set on the ledge or the rim, fronting the lane
local function perch(
	parent: Instance,
	template: Instance,
	scale: number,
	side: number,
	where: string,
	z: number,
	yaw: number?
): Model
	local ax = if where == "rim" then rimAx(side) + 4 else ledgeAx(side)
	return place(
		parent,
		template,
		scale,
		yaw or facing(side),
		Vector3.new(side * ax, ground(side, ax, z) - 0.5, z)
	)
end
-- things drifting down the whole zone: petals, leaves, embers, snow
local function drift(
	texture: string,
	a: Color3,
	b: Color3,
	emission: number,
	rate: number?,
	size: number?
)
	local fx = root:FindFirstChild("Fx") or folder(root, "Fx")
	for i = 0, 3 do
		local source = block(
			fx,
			"DriftSource",
			Vector3.new(300, 1, 70),
			CFrame.new(0, LY + 84, Z0 + 50 + i * 88),
			Color3.new(1, 1, 1)
		)
		source.Transparency = 1
		source.CastShadow = false
		local e = Instance.new("ParticleEmitter")
		e.Texture = texture
		e.Color = ColorSequence.new(a, b)
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, size or 1.2),
			NumberSequenceKeypoint.new(1, (size or 1.2) * 1.4),
		})
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.1, 0),
			NumberSequenceKeypoint.new(0.85, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		e.Lifetime = NumberRange.new(9, 13)
		e.Rate = rate or 5
		e.Speed = NumberRange.new(5, 9)
		e.EmissionDirection = Enum.NormalId.Bottom
		e.SpreadAngle = Vector2.new(25, 25)
		e.Acceleration = Vector3.new(2, -1, 1.5)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-110, 110)
		e.LightEmission = emission
		e.Parent = source
	end
end
-- floor{ strip = function(tile, track) -> color, textureColor, kerb, paving, pavingTex, band }
local function floor(f: any)
	local kitFolder = lanes:FindFirstChild("Zone_" .. ID)
	if not kitFolder then
		return
	end
	-- The lane's paving ends at x 160 and the terrace's ground only starts to show near 164: between
	-- them the terrain dips out of sight and the void shows through as a sky-blue stripe. A kerbstone
	-- along the whole zone closes it (a sea zone has its quay there instead).
	if not spec.sea then
		for _, side in { -1, 1 } do
			local edge = block(
				root,
				"LaneEdge",
				Vector3.new(4.2, 8, Z1 - Z0),
				CFrame.new(side * 162, TERRACE + 0.35 - 4, (Z0 + Z1) / 2),
				f.edge or f.paving,
				Enum.Material.Slate
			)
			edge.CastShadow = false
		end
	end
	for _, c in kitFolder:GetChildren() do
		local n = c.Name
		if c:IsA("BasePart") then
			if n:sub(1, 5) == "Strip" then
				local tile = math.floor((c.Position.Z - (Z0 + 6)) / 44.25 + 0.01)
				local track = math.floor(c.Position.X / 56 + 0.5)
				local color, texColor = f.strip(tile, track)
				c.Color = color
				local tex = c:FindFirstChildWhichIsA("Texture")
				if tex then
					tex.Color3 = texColor
				end
			elseif n:sub(1, 4) == "Kerb" then
				c.Color = f.kerb
			elseif n:sub(1, 6) == "Paving" or n == "MarginPaving" then
				c.Color = f.paving
				local tex = c:FindFirstChildWhichIsA("Texture")
				if tex then
					tex.Color3 = f.pavingTex
				end
			elseif n:sub(1, 12) == "DistanceBand" then
				c.Color = f.band or Color3.fromRGB(255, 255, 255)
			end
		elseif n:sub(1, 5) == "Gate_" then
			for _, d in c:GetDescendants() do
				if d:IsA("BasePart") and d.Name == "Accent" then
					d.Color = f.accent
				elseif d:IsA("TextLabel") then
					local needs = d.Text:match("\n(.*)$") or ""
					d.Text = f.title .. "\n" .. needs
				end
			end
		end
	end
end
local function finish(): string
	local scripts = 0
	for _, d in root:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			scripts += 1
		end
	end
	local report = string.format(
		"zone %d %s: %d parts in Scenery.Zone_%s, z %d..%d, scripts %d, placement faults %d",
		spec.n,
		spec.title,
		#partsOf(root),
		ID,
		Z0,
		Z1,
		scripts,
		#faults
	)
	for i = 1, math.min(#faults, 25) do
		report ..= string.char(10) .. "  FAULT " .. faults[i]
	end
	return report
end
