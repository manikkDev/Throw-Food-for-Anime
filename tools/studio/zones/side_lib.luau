-- side_lib.luau - the zones' sides on the slim lane (design/plan/10-slim-map.md, phase 3). Joined in
-- front of a zone builder that starts with the line `-- LIB: side_lib` by
-- `python tools/studio/zones/run_zone.py build <n>`; everything here is a top-level local the zone's
-- code can use.
--
-- One cross-section for every zone, each side mirrored (owner, 2026-11-22: the clay terrain "looks
-- ass", the sides too big and too tall; a final wall sticking to the zone's border, a little taller
-- than the zone; the sizes must be adjustable later). From the lane's edge outward:
--
--   x 100..104  KERB        stone kerb along the lane (the lane floor kit ends at 100)
--   x 104..172  TERRACE     y -46: the street (104..116) and the buildings, in rows, facing the lane
--   x 168..178  REVETMENT   a built, battered stone retaining wall up to the shelf (no terrain face)
--   x 178..206  SHELF       y -14: the zone's second row, a few trees, landmarks
--   x 206..220  BORDER      the lane border wall (lane_border.luau builds it: top y 26, foot in the sea)
--   x 220..     the sea
--
-- Change a number in P and rebuild the zones: everything below reads P. The ground is terrain only
-- where it is lawn (thin, flat); streets, kerbs and walls are parts with real materials.
--
-- TWO TRACKS (2026-11-23, design/plan/11 phase 3): the lane is 144 wide (edges x +-72). The numbers
-- above, P and every zone file are still written for the three-track lane (edge 100): side_lib moves
-- what a zone builds SHIFT (28) toward the lane, terrain as it is written (`fill`), parts when the
-- zone is finished (`markSlim`). So in the WORLD: kerb 72..76, terrace to 144, revetment 140..150,
-- shelf 150..178, border wall 178..192. Anything a zone builds inside the old lane (|x| < 100: the
-- particle boxes, the ledge's piers) is not moved; the particle boxes are cut to the new lane.

local P = {
	SHIFT = 28, -- the sides' move toward the lane since the lane lost its third track
	LY = -48, -- the lane's floor (config World.LaneY)
	HALF = 100, -- the lane's edge IN THE ZONE FILES' FRAME (the world's: HALF - SHIFT = config LaneWidth / 2)
	KERB_OUT = 104,
	STREET_OUT = 116,
	TERRACE_Y = -46,
	TERRACE_OUT = 172, -- the revetment's foot (its batter reaches back to TERRACE_OUT - BATTER)
	BATTER = 4,
	REVET_OUT = 178,
	SHELF_Y = -14,
	WALL_IN = 206, -- the border wall's inner face (lane_border.luau reads the zone's attributes)
	WALL_OUT = 220,
	WALL_G = -18, -- the border wall's base line: its dress tops out at WALL_G + 44 = 26
	SEA_Y = -4,
	SEA_OUT = 560,
	CLEAR_OUT = 340, -- terrain is cleared out to here (the old sides reached x 320)
}

local SS_ = game:GetService("ServerStorage")
local T_ = workspace.Terrain

-- ---------------------------------------------------------------------------------- parts
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
	local f = parent:FindFirstChild(name)
	if f and f:IsA("Folder") then
		return f
	end
	local n = Instance.new("Folder")
	n.Name = name
	n.Parent = parent
	return n
end
local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	class: string?
): BasePart
	local p = Instance.new(class or "Part") :: BasePart
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
local function cylinder(
	parent: Instance,
	name: string,
	diameter: number,
	length: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): BasePart
	-- cf's Y axis is the cylinder's axis
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
-- a box from x0..x1 (any order), y0..y1, z0..z1
local function box(
	parent: Instance,
	name: string,
	x0: number,
	x1: number,
	y0: number,
	y1: number,
	z0: number,
	z1: number,
	color: Color3,
	material: Enum.Material?
): BasePart
	x0, x1 = math.min(x0, x1), math.max(x0, x1)
	return block(
		parent,
		name,
		Vector3.new(x1 - x0, y1 - y0, z1 - z0),
		CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
		color,
		material
	)
end

-- ---------------------------------------------------------------------------------- terrain
local function fill(
	x0: number,
	x1: number,
	y0: number,
	y1: number,
	z0: number,
	z1: number,
	mat: Enum.Material
)
	-- the zone files' frame to the world's: a side's x moves SHIFT toward the lane, the old lane's inside stays
	local function sx(x: number): number
		return if math.abs(x) >= P.HALF - 0.5 then x - math.sign(x) * P.SHIFT else x
	end
	x0, x1 = sx(x0), sx(x1)
	x0, x1 = math.min(x0, x1), math.max(x0, x1)
	if x1 - x0 < 0.5 or y1 - y0 < 0.5 or z1 - z0 < 0.5 then
		return
	end
	local z = z0
	while z < z1 do
		local zz = math.min(z + 512, z1)
		T_:FillBlock(
			CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z + zz) / 2),
			Vector3.new(x1 - x0, y1 - y0, zz - z),
			mat
		)
		z = zz
	end
end
-- The ground of both sides between z0 and z1: everything that stood there (the old canyons) is
-- cleared, then a thin flat lawn on the terrace and the shelf (level terrain shows 2 studs over
-- where it is written: written 2 low). `opts.terraceFrom` / `opts.shelfFrom` start a band later.
local function sideGround(z0: number, z1: number, opts: any?)
	local o = opts or {}
	local grass = o.grass or Enum.Material.LeafyGrass
	for _, s in { -1, 1 } do
		fill(s * P.HALF, s * P.CLEAR_OUT, P.LY - 24, 200, z0, z1, Enum.Material.Air)
		fill(
			s * P.KERB_OUT,
			s * (P.TERRACE_OUT + 2),
			P.LY - 14,
			P.TERRACE_Y - 2,
			o.terraceFrom or z0,
			z1,
			grass
		)
		fill(
			s * (P.REVET_OUT - 2),
			s * (P.WALL_IN + 4),
			P.TERRACE_Y - 2,
			P.SHELF_Y - 2,
			o.shelfFrom or z0,
			z1,
			grass
		)
		-- the sea outside the border wall (lane_border.luau lays it again)
		fill(s * P.WALL_OUT, s * P.SEA_OUT, -48, -40, z0, z1, Enum.Material.Sand)
		fill(s * P.WALL_OUT, s * P.SEA_OUT, -40, P.SEA_Y, z0, z1, Enum.Material.Water)
	end
end
-- a paved slab with its top at `top` (x signed); the lawn under it is cut so no grass pokes through
local function pave(
	parent: Instance,
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	top: number,
	color: Color3,
	material: Enum.Material,
	name: string?
): BasePart
	local p = box(parent, name or "Paving", x0, x1, top - 6, top, z0, z1, color, material)
	p.CastShadow = false
	local a, b = math.min(x0, x1), math.max(x0, x1)
	if b - a > 2 and z1 - z0 > 2 then
		fill(a + 0.5, b - 0.5, top - 4, top + 12, z0 + 0.5, z1 - 0.5, Enum.Material.Air)
	end
	return p
end

-- ---------------------------------------------------------------------------------- the revetment
-- The retaining wall between the terrace and the shelf: a battered stone face (a castle's ishigaki),
-- a dark band, a cap level with the shelf, and (style.rail) a low rail along the shelf's edge.
-- style: { stone, material, band, cap, capMaterial, rail (Color3 or nil), buttress (spacing), wet (water level) }
local function revetment(parent: Instance, side: number, z0: number, z1: number, style: any)
	local m = Instance.new("Model")
	m.Name = "Revetment"
	local s = side
	local h = P.SHELF_Y - P.TERRACE_Y
	local len = z1 - z0
	local cz = (z0 + z1) / 2
	box(
		m,
		"Core",
		s * P.TERRACE_OUT,
		s * P.REVET_OUT,
		P.TERRACE_Y - 4,
		P.SHELF_Y,
		z0,
		z1,
		style.stone,
		style.material
	)
	-- the batter: a wedge whose slope faces the lane, from the foot (TERRACE_OUT - BATTER) to the top
	local wedge = block(
		m,
		"Batter",
		Vector3.new(len, h, P.BATTER),
		CFrame.new(s * (P.TERRACE_OUT - P.BATTER / 2), P.TERRACE_Y + h / 2, cz)
			* CFrame.Angles(0, if s > 0 then math.pi / 2 else -math.pi / 2, 0), -- its thick end (+Z) on the core
		style.stone,
		style.material,
		"WedgePart"
	)
	wedge.CastShadow = true
	box(
		m,
		"Band",
		s * (P.TERRACE_OUT - 0.6),
		s * (P.TERRACE_OUT + 0.4),
		P.SHELF_Y - 7,
		P.SHELF_Y - 5.4,
		z0,
		z1,
		style.band or style.stone,
		Enum.Material.Slate
	)
	box(
		m,
		"Cap",
		s * (P.TERRACE_OUT - 1.2),
		s * (P.REVET_OUT + 0.4),
		P.SHELF_Y - 0.6,
		P.SHELF_Y + 1.2,
		z0,
		z1,
		style.cap or style.stone,
		style.capMaterial or Enum.Material.Slate
	)
	-- buttresses (style.buttress = their spacing): stone piers proud of the batter, capped
	if style.buttress then
		local n = math.max(1, math.floor(len / style.buttress))
		for i = 1, n - 1 do
			local z = z0 + i * len / n
			box(
				m,
				"Buttress",
				s * (P.TERRACE_OUT - P.BATTER - 2),
				s * P.TERRACE_OUT,
				P.TERRACE_Y - 4,
				P.SHELF_Y - 1.5,
				z - 2,
				z + 2,
				style.stone,
				style.material
			)
			box(
				m,
				"ButtressCap",
				s * (P.TERRACE_OUT - P.BATTER - 2.6),
				s * (P.TERRACE_OUT + 0.2),
				P.SHELF_Y - 2.4,
				P.SHELF_Y - 0.6,
				z - 2.6,
				z + 2.6,
				style.band or style.stone,
				Enum.Material.Slate
			)
		end
	end
	-- a wet band at the waterline (style.wet = the water's level)
	if style.wet then
		box(
			m,
			"WetBand",
			s * (P.TERRACE_OUT - P.BATTER - 0.3),
			s * P.TERRACE_OUT,
			style.wet - 2,
			style.wet + 2.5,
			z0,
			z1,
			(style.band or style.stone):Lerp(Color3.new(0, 0, 0), 0.35),
			style.material
		)
	end
	if style.rail then
		local n = math.max(1, math.floor(len / 8))
		for i = 0, n do
			local z = z0 + 1 + i * (len - 2) / n
			box(
				m,
				"RailPost",
				s * (P.REVET_OUT - 2.2),
				s * (P.REVET_OUT - 1),
				P.SHELF_Y + 1.2,
				P.SHELF_Y + 5,
				z - 0.6,
				z + 0.6,
				style.rail,
				Enum.Material.Wood
			)
		end
		box(
			m,
			"Rail",
			s * (P.REVET_OUT - 2.3),
			s * (P.REVET_OUT - 0.9),
			P.SHELF_Y + 4,
			P.SHELF_Y + 5.2,
			z0 + 0.5,
			z1 - 0.5,
			style.rail,
			Enum.Material.Wood
		)
	end
	m.Parent = parent
	return m
end

-- ---------------------------------------------------------------------------------- placing things
-- Every rectangle that holds something is claimed; a claim that crosses another is refused and
-- reported, so nothing is built through anything else. Templates are placed by their pivot (the
-- middle of their base) and their footprint is TrueSize, or their parts' box about the pivot.
type Rect = { x0: number, x1: number, z0: number, z1: number, name: string }
local claims: { Rect } = {}
local refused: { string } = {}
local function rect(x0: number, x1: number, z0: number, z1: number, name: string): Rect
	return {
		x0 = math.min(x0, x1),
		x1 = math.max(x0, x1),
		z0 = math.min(z0, z1),
		z1 = math.max(z0, z1),
		name = name,
	}
end
local function claim(r: Rect): boolean
	for _, c in claims do
		if
			r.x0 < c.x1 - 0.05
			and c.x0 < r.x1 - 0.05
			and r.z0 < c.z1 - 0.05
			and c.z0 < r.z1 - 0.05
		then
			table.insert(
				refused,
				string.format(
					"%s (%.0f..%.0f, %.0f..%.0f) crosses %s",
					r.name,
					r.x0,
					r.x1,
					r.z0,
					r.z1,
					c.name
				)
			)
			return false
		end
	end
	table.insert(claims, r)
	return true
end
local fpCache = {}
local function footprint(template: Instance): (number, number, number, number, number)
	if fpCache[template] then
		return table.unpack(fpCache[template])
	end
	local ts = template:GetAttribute("TrueSize")
	local res
	if typeof(ts) == "Vector3" then
		res = { -ts.X / 2, ts.X / 2, -ts.Z / 2, ts.Z / 2, ts.Y }
	else
		local piv = (template :: Model):GetPivot()
		local lo, hi = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
		for _, p in partsOf(template) do
			if p.Transparency < 1 then
				local half = p.Size / 2
				for _, sx in { -1, 1 } do
					for _, sy in { -1, 1 } do
						for _, sz in { -1, 1 } do
							local c = piv:PointToObjectSpace(
								(p.CFrame * CFrame.new(half.X * sx, half.Y * sy, half.Z * sz)).Position
							)
							lo, hi = lo:Min(c), hi:Max(c)
						end
					end
				end
			end
		end
		res = { lo.X, hi.X, lo.Z, hi.Z, hi.Y - lo.Y }
	end
	fpCache[template] = res
	return table.unpack(res)
end
-- the footprint turned by yaw (a multiple of 90) and scaled, about the pivot
local function turned(
	template: Instance,
	scale: number,
	yaw: number
): (number, number, number, number)
	local a0, a1, b0, b1 = footprint(template)
	a0, a1, b0, b1 = a0 * scale, a1 * scale, b0 * scale, b1 * scale
	local th = math.rad(yaw)
	local c, s = math.round(math.cos(th)), math.round(math.sin(th))
	local xs, zs = {}, {}
	for _, x in { a0, a1 } do
		for _, z in { b0, b1 } do
			table.insert(xs, x * c + z * s)
			table.insert(zs, -x * s + z * c)
		end
	end
	return math.min(table.unpack(xs)),
		math.max(table.unpack(xs)),
		math.min(table.unpack(zs)),
		math.max(table.unpack(zs))
end
-- the ground a thing at |x| = ax stands on
local function surface(ax: number): number
	if ax < P.TERRACE_OUT then
		return P.TERRACE_Y
	end
	return P.SHELF_Y
end
-- the band a footprint must stay inside: the terrace (kerb to the batter's foot) or the shelf
local function inBand(x0: number, x1: number): boolean
	local a, b = math.min(math.abs(x0), math.abs(x1)), math.max(math.abs(x0), math.abs(x1))
	if x0 < 0 and x1 > 0 then
		return false
	end
	local terrace = a >= P.KERB_OUT - 0.05 and b <= P.TERRACE_OUT - P.BATTER + 0.05
	local shelf = a >= P.REVET_OUT - 0.05 and b <= P.WALL_IN + 0.05
	return terrace or shelf
end
local placed = 0
local sideRng = Random.new(9001)
local function make(
	parent: Instance,
	template: Instance,
	scale: number,
	yaw: number,
	at: Vector3
): Model
	local m = template:Clone() :: Model
	for _, d in m:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	if scale ~= 1 then
		m:ScaleTo(m:GetScale() * scale)
	end
	m:PivotTo(CFrame.new(at) * CFrame.Angles(0, math.rad(yaw), 0))
	if not template:GetAttribute("TrueSize") then
		-- a template whose pivot is not at its feet: stand it on `at`
		local cf, size = m:GetBoundingBox()
		local lift = at.Y - (cf.Position.Y - size.Y / 2)
		if math.abs(lift) > 1 then
			m:PivotTo(m:GetPivot() + Vector3.new(0, lift, 0))
		end
	end
	still(m)
	m.Parent = parent
	placed += 1
	return m
end
-- place a template at (x, z) on its band's ground (or at opts.y), if its footprint is free and
-- inside a band. opts: { y, soft (shrink the claim, for canopies), free (no band check), name }
local function put(
	parent: Instance,
	template: Instance,
	scale: number,
	yaw: number,
	x: number,
	z: number,
	opts: any?
): Model?
	local o = opts or {}
	local x0, x1, z0, z1 = turned(template, scale, yaw)
	local k = o.soft or 0
	local r = rect(x + x0 + k, x + x1 - k, z + z0 + k, z + z1 - k, o.name or template.Name)
	if not o.free and not inBand(r.x0, r.x1) then
		table.insert(refused, string.format("%s (%.0f..%.0f) is off its band", r.name, r.x0, r.x1))
		return nil
	end
	if not claim(r) then
		return nil
	end
	return make(parent, template, scale, yaw, Vector3.new(x, o.y or surface(math.abs(x)), z))
end
-- a template facing the lane, its lane-side face at |x| = ax, its middle at z
local function front(
	parent: Instance,
	template: Instance,
	side: number,
	scale: number,
	ax: number,
	z: number,
	opts: any?
): Model?
	local yaw = if side > 0 then 90 else -90 -- a squared template fronts to -Z
	local x0, x1 = turned(template, scale, yaw)
	local depth = x1 - x0
	return put(parent, template, scale, yaw, side * (ax + depth / 2), z, opts)
end
-- scatter{ parent, templates, count, side, ax = { lo, hi }, z = { lo, hi }, scale = { lo, hi },
--          soft?, y? }: up to `count` things at random free spots in a band (14 tries each, at most);
-- returns how many went in
local function scatter(o: any): number
	local n = 0
	for _ = 1, o.count * 14 do
		if n >= o.count then
			break
		end
		local t = o.templates[sideRng:NextInteger(1, #o.templates)]
		local sc = sideRng:NextNumber(o.scale[1], o.scale[2])
		local x = o.side * sideRng:NextNumber(o.ax[1], o.ax[2])
		local z = sideRng:NextNumber(o.z[1], o.z[2])
		local before = #refused
		local m = put(
			o.parent,
			t,
			sc,
			sideRng:NextInteger(0, 3) * 90,
			x,
			z,
			{ soft = (o.soft or 0) * sc, y = o.y }
		)
		-- a refused try is not a fault here: the spot was taken
		for _ = before + 1, #refused do
			table.remove(refused)
		end
		if m then
			still(m, false)
			n += 1
		end
	end
	return n
end
-- the gate pillars and the lions of the gates at the zone's ends: nothing may stand there
local function claimGates(z0: number, z1: number)
	for _, zone in workspace.Map.Lanes:GetChildren() do
		if zone.Name:sub(1, 5) == "Zone_" then
			for _, g in zone:GetChildren() do
				if g:IsA("Model") and g.Name:sub(1, 5) == "Gate_" then
					local gz = g:GetPivot().Position.Z
					if gz > z0 - 80 and gz < z1 + 80 then
						for _, s in { -1, 1 } do
							claim(rect(s * 105, s * 125, gz - 10, gz + 10, "GatePillar"))
							claim(rect(s * 130, s * 154, gz - 30, gz - 6, "GateLion"))
						end
					end
				end
			end
		end
	end
end
-- the finished zone's parts from the zone files' frame to the world's: everything on a side moves
-- SHIFT toward the lane; a model reaching across the lane is opened up; what stands inside the old
-- lane stays, and a particle box wider than the new lane is cut to it
local function settle(root: Instance)
	local half = P.HALF - P.SHIFT
	local function worldBox(inst: Instance): (number, number)
		local lo, hi = math.huge, -math.huge
		for _, p in partsOf(inst) do
			local cf, h = p.CFrame, p.Size / 2
			for _, a in { -1, 1 } do
				for _, b in { -1, 1 } do
					for _, c in { -1, 1 } do
						local x = (cf * CFrame.new(h.X * a, h.Y * b, h.Z * c)).X
						lo, hi = math.min(lo, x), math.max(hi, x)
					end
				end
			end
		end
		return lo, hi
	end
	local function move(inst: Instance, dx: number)
		local d = Vector3.new(dx, 0, 0)
		if inst:IsA("Model") then
			inst:PivotTo(inst:GetPivot() + d)
			return
		end
		for _, p in partsOf(inst) do
			p.CFrame += d
		end
	end
	local function walk(inst: Instance)
		for _, c in inst:GetChildren() do
			if c:IsA("Folder") then
				walk(c)
			elseif c:IsA("Model") or c:IsA("BasePart") then
				local x
				if c:IsA("Model") and c:GetAttribute("TrueSize") then
					x = c:GetPivot().Position.X -- a merged mesh's parts do not say where it is
				else
					local lo, hi = worldBox(c)
					if c:IsA("Model") and lo < -40 and hi > 40 then
						walk(c)
						continue
					end
					x = (lo + hi) / 2
				end
				if math.abs(x) >= P.HALF - 0.5 then
					move(c, -math.sign(x) * P.SHIFT)
				elseif c:IsA("BasePart") and c.Name:match("Source$") and c.Size.X > 2 * half then
					c.Size = Vector3.new(2 * half - 8, c.Size.Y, c.Size.Z)
				end
			end
		end
	end
	walk(root)
end
-- the zone is finished: its parts go to the world's frame, and it tells lane_border.luau where its
-- border wall stands (world x)
local function markSlim(root: Instance, z0: number, z1: number)
	settle(root)
	root:SetAttribute("SlimZ0", z0)
	root:SetAttribute("SlimZ1", z1)
	root:SetAttribute("SlimWallIn", P.WALL_IN - P.SHIFT)
	root:SetAttribute("SlimWallOut", P.WALL_OUT - P.SHIFT)
	root:SetAttribute("SlimWallG", P.WALL_G)
	root:SetAttribute("SlimShift", P.SHIFT)
end
-- what the run refused, and anything of the zone's that reaches into the lane
local function sideReport(root: Instance): string
	local inLane = {}
	for _, d in root:GetDescendants() do
		if d:IsA("Model") and d.Parent and d.Parent:IsA("Folder") and d.Parent.Name ~= "Fx" then
			local cf, size = d:GetBoundingBox()
			local x0, x1 = cf.X - size.X / 2, cf.X + size.X / 2
			-- a merged building's box does not say where its geometry is: those are placed by TrueSize
			local merged = d:GetAttribute("TrueSize") ~= nil
			if
				not merged
				and not d:GetAttribute("LaneOk")
				and x1 > -(P.HALF - P.SHIFT) + 0.5 -- after markSlim: the world's lane
				and x0 < (P.HALF - P.SHIFT) - 0.5
			then
				table.insert(inLane, string.format("%s @%.0f,%.0f", d.Name, cf.X, cf.Z))
			end
		end
	end
	return string.format(
		"placed %d; refused %d:\n  %s\nin the lane %d:\n  %s",
		placed,
		#refused,
		table.concat(refused, "\n  "),
		#inLane,
		table.concat(inLane, "\n  ")
	)
end
-- ---------------------------------------------------------------------------------- water zones
-- a plank deck over water or ground (x signed, any order), piles down to the bed under its edges
local function deck(
	parent: Instance,
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	top: number,
	color: Color3,
	bed: number?
)
	local m = Instance.new("Model")
	m.Name = "Deck"
	box(m, "Planks", x0, x1, top - 1.2, top, z0, z1, color, Enum.Material.WoodPlanks)
	local a, b = math.min(x0, x1), math.max(x0, x1)
	local foot = bed or (P.LY - 12)
	local nz = math.max(1, math.floor((z1 - z0) / 12))
	for i = 0, nz do
		local z = z0 + 1 + i * (z1 - z0 - 2) / nz
		for _, x in { a + 1, b - 1 } do
			cylinder(
				m,
				"Pile",
				1.8,
				top - 1.2 - foot,
				CFrame.new(x, (top - 1.2 + foot) / 2, z),
				color:Lerp(Color3.new(0, 0, 0), 0.35),
				Enum.Material.Wood
			)
		end
	end
	m.Parent = parent
	return m
end
-- a thing that floats: the audits leave it alone
local function afloat(m: Model?): Model?
	if m then
		m:SetAttribute("Floats", true)
	end
	return m
end
-- a waterfall down the revetment's face (side, its middle at z, `width` wide) into `pool`'s level
local function sheetFall(parent: Instance, side: number, z: number, width: number, pool: number)
	local m = Instance.new("Model")
	m.Name = "Waterfall"
	local top, x0 = P.SHELF_Y + 1.6, P.TERRACE_OUT - P.BATTER - 0.6
	-- the sheet leans out over the batter: a thin slab from the cap's lip to the pool
	local a, b =
		Vector3.new(side * (P.TERRACE_OUT - 1.5), top, z), Vector3.new(side * (x0 - 1.5), pool, z)
	local sheet = block(
		m,
		"Sheet",
		Vector3.new(width, (a - b).Magnitude, 1),
		CFrame.fromMatrix((a + b) / 2, Vector3.new(0, 0, 1), (a - b).Unit),
		Color3.fromRGB(170, 222, 255),
		Enum.Material.Glass
	)
	sheet.Transparency = 0.25
	sheet.CastShadow = false
	local foam = block(
		m,
		"Foam",
		Vector3.new(8, 1, width + 4),
		CFrame.new(side * (x0 - 5), pool + 0.3, z),
		Color3.new(1, 1, 1),
		Enum.Material.SmoothPlastic
	)
	foam.Transparency = 0.2
	foam.CastShadow = false
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.new(1, 1, 1))
	e.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 6) })
	e.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(1, 1.8)
	e.Rate = 14
	e.Speed = NumberRange.new(2, 5)
	e.SpreadAngle = Vector2.new(60, 60)
	e.Parent = foam
	box(
		m,
		"Lip",
		side * (P.TERRACE_OUT - 1.4),
		side * (P.REVET_OUT - 2),
		P.SHELF_Y - 0.2,
		top,
		z - width / 2,
		z + width / 2,
		Color3.fromRGB(150, 206, 240),
		Enum.Material.Glass
	).Transparency =
		0.3
	m.Parent = parent
	return m
end

-- ---------------------------------------------------------------------------------- words, signs, marks
-- text on a part's face; a scaled label stops growing at 100 px, so 100 px is the face's short side
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
-- a board with words on its front (cf's look vector is the side they are read from)
local function sign(
	parent: Instance,
	text: string,
	width: number,
	height: number,
	cf: CFrame,
	bg: Color3,
	fg: Color3,
	font: Enum.Font?
): BasePart
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
			Enum.Material.Wood
		)
	end
	for _, h in { height * 0.9, height * 0.5 } do
		block(
			parent,
			"FenceRail",
			Vector3.new(0.5, 0.5, len),
			dir * CFrame.new(0, h, -len / 2),
			color,
			Enum.Material.Wood
		)
	end
end
-- a painted mark on the ground (x signed, any order), its top just over `top`
local function paint(
	parent: Instance,
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	color: Color3,
	top: number
): BasePart
	local p = box(
		parent,
		"Paint",
		x0,
		x1,
		top - 0.1,
		top + 0.15,
		z0,
		z1,
		color,
		Enum.Material.SmoothPlastic
	)
	p.CastShadow = false
	return p
end

-- ---------------------------------------------------------------------------------- the lane's floor
-- a floor kit's pieces, also those lod_chunks.luau grouped into LodChunk models (for SLIM)
local function kitItems(kit: Instance): { Instance }
	local list = {}
	for _, c in kit:GetChildren() do
		if c:IsA("Model") and c.Name == "LodChunk" then
			for _, d in c:GetChildren() do
				table.insert(list, d)
			end
		else
			table.insert(list, c)
		end
	end
	return list
end
-- recolours this zone's floor kit (Map.Lanes.Zone_<id>) and retitles its gate (the "needs" line kept).
-- f: { id, title, accent, strip = function(tile, track) -> color, texColor; kerb, paving, pavingTex, band }
local function floorKit(f: any)
	local kit = workspace.Map.Lanes:FindFirstChild("Zone_" .. f.id)
	assert(kit, "no floor kit for " .. f.id)
	local z0 = math.huge
	for _, c in kitItems(kit) do
		if c:IsA("BasePart") and c.Name:sub(1, 5) == "Strip" then
			z0 = math.min(z0, c.Position.Z - c.Size.Z / 2)
		end
	end
	for _, c in kitItems(kit) do
		local n = c.Name
		if c:IsA("BasePart") then
			local tex = c:FindFirstChildWhichIsA("Texture")
			if n:sub(1, 5) == "Strip" and f.strip then
				local tile = math.floor((c.Position.Z - c.Size.Z / 2 - z0) / 44.25 + 0.5)
				local track = math.floor(c.Position.X / 56 + 0.5)
				local color, texColor = f.strip(tile, track)
				c.Color = color
				if tex and texColor then
					tex.Color3 = texColor
				end
			elseif n:sub(1, 4) == "Kerb" and f.kerb then
				c.Color = f.kerb
			elseif (n:sub(1, 6) == "Paving" or n == "MarginPaving") and f.paving then
				c.Color = f.paving
				if tex and f.pavingTex then
					tex.Color3 = f.pavingTex
				end
			elseif n:sub(1, 12) == "DistanceBand" and f.band then
				c.Color = f.band
			end
		elseif n:sub(1, 5) == "Gate_" then
			for _, d in c:GetDescendants() do
				if d:IsA("BasePart") and d.Name == "Accent" and f.accent then
					d.Color = f.accent
				elseif d:IsA("TextLabel") and f.title then
					local needs = d.Text:match("\n(.*)$") or ""
					d.Text = f.title .. "\n" .. needs
				end
			end
		end
	end
end
local _ = {
	SS_,
	cylinder,
	sideGround,
	pave,
	revetment,
	front,
	claimGates,
	markSlim,
	sideReport,
	deck,
	afloat,
	sheetFall,
	floorKit,
	kitItems,
	folder,
	words,
	sign,
	paint,
	fence,
	scatter,
}
