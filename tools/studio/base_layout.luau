-- base_layout.luau - Studio EDIT mode, safe to run again. Lays the five bases out from the game's own
-- numbers (ReplicatedStorage.Shared.Config.GameConfig + Core.World, synced by Rojo), so a change of
-- PlotPitch, PlotWidth, the pedestal grid or the courts is a config edit and a rerun.
--
-- Owner (2026-11-22): the bases a perfect square with an even, smaller border round the heroes; no
-- bushes along their sides; the bases a little closer together; one training station per side.
--   * each Plot<i> model moves to World.plotX; its deck, runner, pedestals, fence ring, spawn, slot
--     sign, courts and stations are set from the config (relative to the plot's centre)
--   * the stations that are no longer in config.Training.Stations (lift, push: Station2, Station3,
--     the pillar anchor Target3, the training log) go to ServerStorage.MapArchive.BaseLayout_v1, and
--     Station4 (meditate) becomes Station2 (its prompt's Station attribute too). Once per plot.
--   * per-base pieces outside the plot models (walk aprons, walkway fences, gravel, toro lanterns)
--     move with their base; the pieces between bases (garden paths, lanterns, cherry trees) move to
--     the middle between the new bases. Each remembers its anchor (attributes Anchor, AnchorX), so
--     a rerun moves it from where it is, not from where it was.
--   * the bushes along the bases' sides are archived.
-- Run: python ~/.claude/skills/create-roblox-game/scripts/studio_mcp.py luau --file <this file>
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
-- a fresh copy each run: Studio caches a required module for the whole session, so an edited (and
-- synced) config would not be seen (lane_slim's first run read the old lane width this way)
local function fresh(m: ModuleScript): any
	return require(m:Clone())
end
local Config = fresh(RS.Shared.Config.GameConfig)
local World = fresh(RS.Shared.Core.World)
local W = Config.World
local TR = Config.Training
local COUNT = Config.Server.PlotCount
local OLD_PITCH = 108 -- the pitch the place was built at (first run only)
local map = workspace.Map

local archiveRoot = SS:FindFirstChild("MapArchive")
assert(archiveRoot, "no ServerStorage.MapArchive")
local archive = archiveRoot:FindFirstChild("BaseLayout_v1")
if not archive then
	archive = Instance.new("Folder")
	archive.Name = "BaseLayout_v1"
	archive:SetAttribute(
		"Note",
		"The bases' pieces taken out by base_layout.luau (2026-11-22): the lift and push stations, the side bushes. Never delete."
	)
	archive.Parent = archiveRoot
end
local log = {}
local function stash(inst: Instance, tag: string)
	inst.Name = tag .. "_" .. inst.Name
	inst.Parent = archive
end

local function pos(inst: Instance): Vector3
	if inst:IsA("Model") then
		-- by its box: the HubV2 models' pivots sit 3000 studs off (built in a copy, then moved)
		return (inst:GetBoundingBox()).Position
	end
	return (inst :: BasePart).Position
end
local function shift(inst: Instance, d: Vector3)
	if d.Magnitude < 1e-4 then
		return
	end
	if inst:IsA("Model") then
		inst:PivotTo(inst:GetPivot() + d)
	elseif inst:IsA("BasePart") then
		-- a part with parts under it (a sign with its model) moves as one
		local kids = {}
		for _, k in inst:GetDescendants() do
			if k:IsA("BasePart") then
				table.insert(kids, k)
			end
		end
		inst.CFrame += d
		for _, k in kids do
			k.CFrame += d
		end
	end
end
-- set a part's size and centre (x, z relative to `cx`), keeping its height
local function setBox(p: BasePart, cx: number, x: number, z: number, sx: number, sz: number)
	p.Size = Vector3.new(sx, p.Size.Y, sz)
	p.CFrame = CFrame.new(cx + x, p.Position.Y, z) * p.CFrame.Rotation
end

-- ------------------------------------------------------------------------------ anchors
-- Anchor k: half-pitch steps from x = 0 (even k = a base's centre, odd k = the middle between two)
local function anchorOf(inst: Instance): (number, number)
	local k = inst:GetAttribute("Anchor")
	local ax = inst:GetAttribute("AnchorX")
	if typeof(k) ~= "number" or typeof(ax) ~= "number" then
		k = math.round(pos(inst).X / (OLD_PITCH / 2))
		ax = k * OLD_PITCH / 2
	end
	return k :: number, ax :: number
end
local function moveToAnchor(inst: Instance): (number, number)
	local k, ax = anchorOf(inst)
	local nx = k * W.PlotPitch / 2
	shift(inst, Vector3.new(nx - ax, 0, 0))
	inst:SetAttribute("Anchor", k)
	inst:SetAttribute("AnchorX", nx)
	return k, nx
end

-- ------------------------------------------------------------------------------ 1. the plots
local HALF = W.PlotWidth / 2
local DEPTH = W.PlotFrontZ - W.PlotBackZ
local MIDZ = (W.PlotBackZ + W.PlotFrontZ) / 2
local stationIndex: { [string]: number } = {}
for i, row in TR.Stations do
	stationIndex[row.Id] = i
end
local ANCHOR_OF = { strike = "Gear", meditate = "SpiritGear" } -- the gear model each station shows

for i = 1, COUNT do
	local plot = map.Plots:FindFirstChild("Plot" .. i) :: Model
	assert(plot, "no Plot" .. i)
	local _, cx = moveToAnchor(plot)
	local dressing = plot:FindFirstChild("Dressing") :: Folder

	-- 1a. the stations: once, the lift and push stations go and meditate becomes Station2
	if not plot:GetAttribute("TwoStations") then
		local function isStationDressing(p: Instance, mat: BasePart): boolean
			return p.Name:match("^Station") ~= nil
				and p:IsA("BasePart")
				and math.abs(p.Position.X - mat.Position.X) < 6
				and math.abs(p.Position.Z - mat.Position.Z) < 6
		end
		for _, name in { "Station2", "Station3" } do
			local mat = plot:FindFirstChild(name) :: BasePart
			if mat then
				for _, p in dressing:GetChildren() do
					if isStationDressing(p, mat) then
						stash(p, "Plot" .. i .. name)
					end
				end
				stash(mat, "Plot" .. i)
			end
		end
		for _, name in { "Target3" } do
			local a = plot:FindFirstChild(name)
			if a then
				stash(a, "Plot" .. i)
			end
		end
		local props = plot:FindFirstChild("Stations")
		if props then
			for _, m in props:GetChildren() do
				stash(m, "Plot" .. i)
			end
		end
		local med = plot:FindFirstChild("Station4") :: BasePart
		if med then
			med.Name = "Station2"
			for _, d in med:GetDescendants() do
				if d:IsA("ProximityPrompt") and d:GetAttribute("Station") == 4 then
					d:SetAttribute("Station", stationIndex.meditate)
				end
			end
		end
		plot:SetAttribute("TwoStations", true)
	end

	-- 1b. the deck: a square with an even border, the runner down its middle
	local base = plot:FindFirstChild("Base") :: BasePart
	setBox(base, cx, 0, MIDZ, W.PlotWidth, DEPTH)
	local runner = plot:FindFirstChild("Runner") :: BasePart
	setBox(runner, cx, 0, MIDZ, runner.Size.X, DEPTH)
	for _, r in plot:GetChildren() do
		if r.Name == "RunnerTrim" and r:IsA("BasePart") then
			setBox(r, cx, (if r.Position.X < cx then -1 else 1) * 5.4, MIDZ, r.Size.X, DEPTH)
		end
	end

	-- 1c. the pedestals and their bodies, from the same function the heroes stand by
	for slot = 1, World.pedestalCount(W) do
		local dx, z = World.pedestalOffset(W, slot)
		local top = plot.Pedestals:FindFirstChild("Pedestal" .. slot) :: BasePart
		if top then
			top.CFrame = CFrame.new(cx + dx, top.Position.Y, z) * top.CFrame.Rotation
		end
		local body = dressing:FindFirstChild("PedestalBody" .. slot) :: Model
		if body then
			local pv = body:GetPivot()
			body:PivotTo(CFrame.new(cx + dx, pv.Y, z) * pv.Rotation)
		end
	end

	-- 1d. the fence ring round the deck: a gap at the back for the name arch, one at the front
	-- for the walk; pieces 8 long, evenly spread
	local fences = {}
	for _, f in dressing:GetChildren() do
		if f.Name == "Plot_Fence" and f:IsA("Model") then
			table.insert(fences, f)
		end
	end
	assert(#fences > 0, "Plot" .. i .. " has no fence pieces")
	local fenceY = fences[1]:GetPivot().Y
	local spots = {}
	local function run(a: number, b: number, fixed: number, alongX: boolean)
		local n = math.max(1, math.ceil((b - a) / 7.9))
		for j = 0, n - 1 do
			local t = if n == 1 then (a + b) / 2 else a + 4 + j * (b - a - 8) / (n - 1)
			if alongX then
				table.insert(spots, CFrame.new(cx + t, fenceY, fixed))
			else
				table.insert(
					spots,
					CFrame.new(cx + fixed, fenceY, t) * CFrame.Angles(0, math.pi / 2, 0)
				)
			end
		end
	end
	local IN = 0.4
	local backZ, frontZ = W.PlotBackZ + IN, W.PlotFrontZ - IN
	for _, s in { -1, 1 } do
		run(backZ, frontZ, s * (HALF - IN), false) -- the sides
		local a, b = 12, HALF - IN -- the back, beside the name arch
		run(math.min(s * a, s * b), math.max(s * a, s * b), backZ, true)
		a = 8 -- the front, beside the walk
		run(math.min(s * a, s * b), math.max(s * a, s * b), frontZ, true)
	end
	for j, cf in spots do
		local f = fences[j]
		if not f then
			f = fences[1]:Clone()
			f.Parent = dressing
			fences[j] = f
		end
		f:PivotTo(cf)
	end
	for j = #spots + 1, #fences do
		fences[j]:Destroy()
	end

	-- 1e. the spawn and the slot sign: side by side on the walk just in front of the deck
	local spawn = plot:FindFirstChild("Spawn") :: BasePart
	spawn.CFrame = CFrame.new(cx, spawn.Position.Y, W.SlotSignZ) * spawn.CFrame.Rotation
	local sign = plot:FindFirstChild("SlotSign") :: BasePart
	local sx, sz = World.slotSign(W, i, COUNT)
	shift(sign, Vector3.new(sx - sign.Position.X, 0, sz - sign.Position.Z))

	-- 1f. the courts: one station each, its rim of posts and trims
	for _, side in { -1, 1 } do
		local ccx, ccz, cw, cd = World.court(W, i, COUNT, side)
		local court = plot:FindFirstChild(if side < 0 then "CourtL" else "CourtR") :: BasePart
		setBox(court, 0, ccx, ccz, cw, cd)
		local ex, ez = cw / 2 + 0.4, cd / 2 + 0.5
		for _, p in dressing:GetChildren() do
			if p:IsA("BasePart") and p.Name:match("^Court") and (p.Position.X - cx) * side > 0 then
				local qx = if p.Position.X - (cx + side * W.CourtX) < 0 then -1 else 1
				local qz = if p.Position.Z < ccz then -1 else 1
				if p.Name == "CourtPost" or p.Name == "CourtPostCap" then
					p.CFrame = CFrame.new(ccx + qx * ex, p.Position.Y, ccz + qz * ez)
				elseif p.Name == "CourtTrim" then
					if p.Size.X > p.Size.Z then -- front or back
						p.Size = Vector3.new(cw + 1.8, p.Size.Y, p.Size.Z)
						p.CFrame = CFrame.new(ccx, p.Position.Y, ccz + qz * (cd / 2 + 0.5))
					else
						p.Size = Vector3.new(p.Size.X, p.Size.Y, cd)
						p.CFrame = CFrame.new(ccx + qx * ex, p.Position.Y, ccz)
					end
				end
			end
		end
	end
	-- 1g. the stations: the mat, its rings and studs and the gear it shows, to the config's X
	for idx, row in TR.Stations do
		local mat = plot:FindFirstChild("Station" .. idx) :: BasePart
		assert(mat, `Plot{i} has no Station{idx}`)
		local d = Vector3.new(cx + row.X - mat.Position.X, 0, 0)
		local moving = {}
		for _, p in dressing:GetChildren() do
			if
				p:IsA("BasePart")
				and p.Name:match("^Station")
				and math.abs(p.Position.X - mat.Position.X) < 6
				and math.abs(p.Position.Z - mat.Position.Z) < 6
			then
				table.insert(moving, p)
			end
		end
		local anchorName = ANCHOR_OF[row.Id]
		local anchor = anchorName and plot:FindFirstChild(anchorName)
		if anchor then
			table.insert(moving, anchor)
		end
		table.insert(moving, mat)
		for _, p in moving do
			shift(p, d)
		end
	end
	table.insert(log, string.format("Plot%d x %.0f", i, cx))
end

-- ------------------------------------------------------------------------------ 2. outside the plots
-- per-base pieces move with their base; the pieces between bases to the new middle
local moved, stashed = 0, 0
local function lay(inst: Instance)
	local k, nx = moveToAnchor(inst)
	moved += 1
	return k, nx
end
for _, c in map.Scenery.Plots:GetChildren() do
	if c.Name == "Prop_store_Bush" then
		stash(c, "Side")
		stashed += 1
	elseif c.Name == "Plot_Fence" or c.Name == "Prop_store_StoneLanternWide" then
		lay(c)
	elseif c.Name == "ForecourtGravel" and c:IsA("BasePart") then
		local _, nx = lay(c)
		-- between the walkway's fence (x 8.6) and the court's edge
		local s = if c.Position.X < nx then -1 else 1
		local inner, outer = 8.9, W.CourtX - W.CourtWidth / 2
		setBox(c, nx, s * (inner + outer) / 2, c.Position.Z, outer - inner, c.Size.Z)
	elseif c.Name == "GardenPath" and c:IsA("BasePart") then
		local _, nx = lay(c)
		setBox(c, nx, 0, MIDZ, c.Size.X, DEPTH)
	end
end
for _, c in map.Lanes.Aprons:GetChildren() do
	if c:IsA("BasePart") and c.Name:match("^Walk") then
		local _, nx = lay(c)
		local z0, z1 = W.PlotFrontZ, c.Position.Z + c.Size.Z / 2
		setBox(c, nx, 0, (z0 + z1) / 2, c.Size.X, z1 - z0)
	end
end
for _, c in map.HubV2:GetChildren() do
	if c:IsA("Model") then
		local p = pos(c)
		local inBand = p.Z > -50 and p.Z < 60 and math.abs(p.X) < 250
		if inBand and (c.Name == "ToroLantern" or c.Name:match("^Sakura")) then
			lay(c)
		end
	end
end

return string.format(
	"%s\nmoved %d pieces outside the plots, archived %d bushes",
	table.concat(log, ", "),
	moved,
	stashed
)
