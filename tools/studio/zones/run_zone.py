"""Zone tools for Studio (edit mode), from zone 4 on. One file, four commands:

  python tools/studio/zones/run_zone.py build 4 [--no-terrain]
      joins zone_lib.luau to zone_04_*.luau and runs the pair: rebuilds that zone (a zone file whose
      head says "-- LIB: side_lib" is joined to side_lib.luau instead: the slim-lane zones)
  python tools/studio/zones/run_zone.py store Zone04_MHA "Tower=A tall hero" "Tree=A round" [--view]
      takes the models Studio's mesh generator left in Workspace (matched by the start of their
      name, which is the prompt), squares them (the generator turns its model to face the camera)
      and stores them in ServerStorage.StoreAssets.<folder>; --view also lines copies up at
      (3000, 600, -9000) in Workspace.Quarantine to be looked at
  python tools/studio/zones/run_zone.py clear
      deletes Workspace.Quarantine
  python tools/studio/zones/run_zone.py check samurai_castle
      ground check of every model in Map.Scenery.Zone_<id>, scripts, leftovers
  python tools/studio/zones/run_zone.py audit samurai_castle [--shrink=0.86] [--tolerance=1.5]
      placement audit: models overlapping each other or a gate pillar, models sunk in or hanging
      over the ground under their footprint, models reaching into the lane. Attributes on a model
      excuse it: Floats, SunkOk / HangOk (studs), LaneOk, Soft (treated like a tree), AuditSkip
  python tools/studio/zones/run_zone.py look 166 -40 2262 200 -46 2290 [seconds]
      parks the camera, wakes the display, waits: then call screen_capture with NO camera position
  python tools/studio/zones/run_zone.py inspect Zone04_MHA
      numbers for each stored mesh (vertices, box, how they fill it): the only check there is
      when the screen is locked and nothing can be looked at
"""
import glob
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
MCP = os.path.join(os.path.expanduser("~"), ".claude", "skills", "create-roblox-game", "scripts", "studio_mcp.py")


def run(code: str) -> int:
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False, encoding="utf8", newline="\n") as f:
        f.write(code)
        path = f.name
    try:
        out = subprocess.run([sys.executable, MCP, "luau", "--dm", "Edit", "--file", path], capture_output=True, text=True, encoding="utf8", errors="replace")
        text = (out.stdout or "") + (out.stderr or "")
        print("\n".join(text.strip().splitlines()[-40:]))
        return out.returncode
    finally:
        os.unlink(path)


def build(args):
    n = int(args[0])
    files = glob.glob(os.path.join(HERE, f"zone_{n:02d}_*.luau"))
    assert len(files) == 1, f"expected one zone_{n:02d}_*.luau, found {files}"
    zone = open(files[0], encoding="utf8").read()
    if "-- LIB: side_lib" in zone[:400]:
        # the slim-lane zones (design/plan/10-slim-map.md, phase 3): one pass, terrain and all
        lib = open(os.path.join(HERE, "side_lib.luau"), encoding="utf8").read()
        dt = "false" if "--no-terrain" in args else "true"
        return run("local DO_TERRAIN = " + dt + chr(10) + lib + chr(10) + zone)
    lib = open(os.path.join(HERE, "zone_lib.luau"), encoding="utf8").read()
    if "--no-terrain" not in args:
        # the builder places things on the terrain as it stands (it measures the ground): so the
        # terrain is written first, and everything is placed in a second pass
        code = run(f"local DO_TERRAIN = true\n{lib}\n{zone}")
        if code != 0:
            return code
    return run(f"local DO_TERRAIN = false\n{lib}\n{zone}")


STORE = '''
local store = game:GetService("ServerStorage").StoreAssets
local dest = store:FindFirstChild("%(folder)s") or Instance.new("Folder")
dest.Name = "%(folder)s"
dest:SetAttribute("Note", "Zone templates (Studio generate_mesh results, squared). Never delete.")
dest.Parent = store
local KEYS = { %(keys)s }
local VIEW = %(view)s
local stage = workspace:FindFirstChild("Quarantine")
if VIEW and not stage then
	stage = Instance.new("Folder")
	stage.Name = "Quarantine"
	stage.Parent = workspace
end
local out = {}
local x = 3000
for _, c in workspace:GetChildren() do
	for _, k in KEYS do
		if c:IsA("Model") and c.Name:sub(1, #k[2]) == k[2] then
			local mesh = c:FindFirstChildWhichIsA("MeshPart", true)
			if mesh then
				local old = dest:FindFirstChild(k[1])
				if old then
					old:Destroy()
				end
				local model = Instance.new("Model")
				model.Name = k[1]
				local m = mesh:Clone()
				m.Name = "Mesh"
				m.Anchored = true
				m.CanCollide = false
				m.CanQuery = false
				m.CanTouch = false
				m.Massless = true
				m.CFrame = CFrame.new(m.Position) -- squared: the generator turns its model to the camera
				m.Parent = model
				model.WorldPivot = CFrame.new(m.Position.X, m.Position.Y - m.Size.Y / 2, m.Position.Z)
				model:PivotTo(CFrame.new(0, 0, 0))
				model:SetAttribute("TrueSize", m.Size)
				model.Parent = dest
				if VIEW then
					local view = model:Clone()
					view:PivotTo(CFrame.new(x, 600, -9000))
					view.Parent = stage
				end
				table.insert(out, string.format("%%s %%.0fx%%.0fx%%.0f x=%%d", k[1], m.Size.X, m.Size.Y, m.Size.Z, x))
				x += math.max(m.Size.X, 30) + 30
				c:Destroy()
			end
		end
	end
end
local have = {}
for _, c in dest:GetChildren() do
	table.insert(have, c.Name)
end
return "stored: " .. table.concat(out, "; ") .. " | folder now has: " .. table.concat(have, ", ")
'''


def store(args):
    folder = args[0]
    pairs = [a for a in args[1:] if "=" in a]
    keys = ", ".join('{ "%s", "%s" }' % tuple(p.split("=", 1)) for p in pairs)
    return run(STORE % {"folder": folder, "keys": keys, "view": "true" if "--view" in args else "false"})


CHECK = '''
local zone = workspace.Map.Scenery:FindFirstChild("Zone_%(id)s")
if not zone then
	return "no Map.Scenery.Zone_%(id)s"
end
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { workspace.Terrain }
params.IgnoreWater = true
local out, checked, bad = {}, 0, 0
for _, m in zone:GetDescendants() do
	if m:IsA("Model") and m.Parent:IsA("Folder") then -- (Workspace is itself a Model: ask the parent)
		local p = m:GetPivot().Position
		local hit = workspace:Raycast(p + Vector3.new(0, 80, 0), Vector3.new(0, -300, 0), params)
		checked += 1
		local gap = hit and (p.Y - hit.Position.Y) or 999
		if gap > 2.5 or gap < -6 then
			bad += 1
			if #out < 14 then
				table.insert(out, string.format("  %%s/%%s (%%.0f, %%.0f, %%.0f): %%.1f above the ground", m.Parent.Name, m.Name, p.X, p.Y, p.Z, gap))
			end
		end
	end
end
local scripts, parts = 0, 0
for _, d in zone:GetDescendants() do
	if d:IsA("LuaSourceContainer") then
		scripts += 1
	elseif d:IsA("BasePart") then
		parts += 1
	end
end
table.insert(out, 1, string.format("Zone_%(id)s: %%d parts, %%d models checked, %%d off the ground, %%d scripts, quarantine left: %%s", parts, checked, bad, scripts, tostring(workspace:FindFirstChild("Quarantine") ~= nil)))
return table.concat(out, "\\n")
'''


def check(args):
    return run(CHECK % {"id": args[0]})


INSPECT_START = '''
local AssetService = game:GetService("AssetService")
local dest = game:GetService("ServerStorage").StoreAssets:FindFirstChild("%(folder)s")
workspace:SetAttribute("InspectLog", "running")
task.spawn(function()
	local log = {}
	for _, template in dest:GetChildren() do
		local mp = template:FindFirstChildWhichIsA("MeshPart")
		if mp then
			local ok, em = pcall(function()
				return AssetService:CreateEditableMeshAsync(Content.fromUri(mp.MeshId))
			end)
			if not ok then
				table.insert(log, template.Name .. ": cannot read mesh")
			else
				local ids = em:GetVertices()
				local lo, hi = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
				local n = #ids
				-- how the vertices sit in height: a healthy solid object has them at every level
				local bands = table.create(5, 0)
				local pts = table.create(n)
				for i, id in ids do
					local p = em:GetPosition(id)
					pts[i] = p
					lo, hi = lo:Min(p), hi:Max(p)
				end
				local size = hi - lo
				-- how much of the box's footprint the vertices cover, on an 8 x 8 grid
				local cells, used = {}, 0
				for _, p in pts do
					local b = math.clamp(math.floor((p.Y - lo.Y) / size.Y * 5) + 1, 1, 5)
					bands[b] += 1
					local key = math.clamp(math.floor((p.X - lo.X) / size.X * 8), 0, 7) * 8 + math.clamp(math.floor((p.Z - lo.Z) / size.Z * 8), 0, 7)
					if not cells[key] then
						cells[key] = true
						used += 1
					end
				end
				for i = 1, 5 do
					bands[i] = math.round(bands[i] / n * 100)
				end
				table.insert(log, string.format("%%s: %%d verts, box %%.0fx%%.0fx%%.0f, footprint cover %%d/64, verts by height %%%% %%s", template.Name, n, mp.Size.X, mp.Size.Y, mp.Size.Z, used, table.concat(bands, "/")))
			end
			task.wait()
		end
	end
	workspace:SetAttribute("InspectLog", table.concat(log, string.char(10)))
end)
return "started"
'''


def inspect(args):
    import time
    run(INSPECT_START % {"folder": args[0]})
    for _ in range(12):
        time.sleep(4)
        with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False, encoding="utf8") as f:
            f.write('return workspace:GetAttribute("InspectLog")')
            path = f.name
        out = subprocess.run([sys.executable, MCP, "luau", "--dm", "Edit", "--file", path], capture_output=True, text=True, encoding="utf8", errors="replace")
        os.unlink(path)
        text = (out.stdout or "").strip()
        if text and "running" not in text.splitlines()[-1]:
            print(text)
            return 0
    print("inspect: no answer")
    return 1


AUDIT = '''
-- Placement audit of one zone: model against model (boxes turned with the model, shrunk a little
-- because a mesh never fills its box's corners), model against the gates' pillars, model against
-- the ground under its footprint, and anything that reaches into the lane.
local ID = "%(id)s"
local map = workspace.Map
local zone = map.Scenery:FindFirstChild("Zone_" .. ID)
if not zone then
	return "no Map.Scenery.Zone_" .. ID
end
local SHRINK = %(shrink)s
local units = {}
for _, m in zone:GetDescendants() do
	if m:IsA("Model") and m.Parent:IsA("Folder") and not m:GetAttribute("AuditSkip") then
		local cf, size = m:GetBoundingBox()
		local tree = m.Parent.Name == "Trees" or m:GetAttribute("Soft") == true
		local k = if tree then 0.45 else SHRINK
		table.insert(units, { m = m, name = m.Parent.Name .. "/" .. m.Name, cf = cf, size = size, hx = size.X / 2 * k, hz = size.Z / 2 * k, y0 = cf.Position.Y - size.Y / 2, y1 = cf.Position.Y + size.Y / 2, tree = tree })
	end
end
-- the gates' pillars and beams (this zone's and the next one's) are obstacles too
local obstacles = {}
local z0 = zone:GetAttribute("Z0")
for _, kit in map.Lanes:GetChildren() do
	if kit.Name:sub(1, 5) == "Zone_" then
		for _, g in kit:GetChildren() do
			if g.Name:sub(1, 5) == "Gate_" then
				-- the gate is a few big meshes, so its pillars are given by measure: x 171..236, 35
				-- either side of the pivot, which stands 45 studs into its zone
				local gz = g:GetPivot().Position.Z
				for _, side in { -1, 1 } do
					table.insert(obstacles, { name = "the gate pillar of " .. kit.Name:sub(6), cf = CFrame.new(side * 203.5, 80, gz), size = Vector3.new(65, 260, 70), hx = 32.5, hz = 35, y0 = -70, y1 = 220 })
				end
			end
		end
	end
end
local function axes(u)
	local r, l = u.cf.RightVector, u.cf.LookVector
	return Vector2.new(r.X, r.Z).Unit, Vector2.new(l.X, l.Z).Unit
end
local function overlap(a, b): number
	local yo = math.min(a.y1, b.y1) - math.max(a.y0, b.y0)
	if yo <= 0 then
		return 0
	end
	local ar, al = axes(a)
	local br, bl = axes(b)
	local d = Vector2.new(b.cf.Position.X - a.cf.Position.X, b.cf.Position.Z - a.cf.Position.Z)
	local least = yo
	for _, ax in { ar, al, br, bl } do
		local ra = a.hx * math.abs(ar:Dot(ax)) + a.hz * math.abs(al:Dot(ax))
		local rb = b.hx * math.abs(br:Dot(ax)) + b.hz * math.abs(bl:Dot(ax))
		local pen = ra + rb - math.abs(d:Dot(ax))
		if pen <= 0 then
			return 0
		end
		least = math.min(least, pen)
	end
	return least
end
local out = {}
local nOverlap, nGround, nLane = 0, 0, 0
for i = 1, #units do
	local a = units[i]
	for j = i + 1, #units do
		local b = units[j]
		if not (a.tree and b.tree) then
			local pen = overlap(a, b)
			if pen > %(tolerance)s then
				nOverlap += 1
				table.insert(out, string.format("  OVERLAP %%.1f: %%s (%%.0f, %%.0f) x %%s (%%.0f, %%.0f)", pen, a.name, a.cf.Position.X, a.cf.Position.Z, b.name, b.cf.Position.X, b.cf.Position.Z))
			end
		end
	end
	for _, o in obstacles do
		local pen = overlap(a, o)
		if pen > 1 then
			nOverlap += 1
			table.insert(out, string.format("  OVERLAP %%.1f: %%s (%%.0f, %%.0f) x %%s", pen, a.name, a.cf.Position.X, a.cf.Position.Z, o.name))
		end
	end
end
-- the ground under each footprint: terrain, and the zone's own built parts (piers, plinths, islets)
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
local solid = { workspace.Terrain, map.Lanes }
-- built parts (decks, piers, plinths, islets) are not queryable, so they are tested by their boxes
local built = {}
for _, d in zone:GetDescendants() do
	if d:IsA("BasePart") and d.Transparency < 1 then
		local owner = d:FindFirstAncestorWhichIsA("Model")
		if not owner or not owner:IsDescendantOf(zone) then
			local c, h = d.CFrame, d.Size / 2
			local r, up, l = c.RightVector, c.UpVector, c.LookVector
			local hx = math.abs(r.X) * h.X + math.abs(up.X) * h.Y + math.abs(l.X) * h.Z
			local hy = math.abs(r.Y) * h.X + math.abs(up.Y) * h.Y + math.abs(l.Y) * h.Z
			local hz = math.abs(r.Z) * h.X + math.abs(up.Z) * h.Y + math.abs(l.Z) * h.Z
			table.insert(built, { x0 = d.Position.X - hx, x1 = d.Position.X + hx, z0 = d.Position.Z - hz, z1 = d.Position.Z + hz, top = d.Position.Y + hy })
		end
	end
end
local function builtTop(x: number, z: number, under: number): number
	local best = -999
	for _, bx in built do
		if x >= bx.x0 and x <= bx.x1 and z >= bx.z0 and z <= bx.z1 and bx.top <= under and bx.top > best then
			best = bx.top
		end
	end
	return best
end
params.IgnoreWater = true
for _, u in units do
	if not u.m:GetAttribute("Floats") then
		local r, l = u.cf.RightVector, u.cf.LookVector
		local lo, hi = math.huge, -math.huge
		params.FilterDescendantsInstances = solid
		-- a tree is judged at its trunk only: its crown may hang over a cliff's edge
		for _, s in if u.tree then { { 0, 0 } } else { { 0, 0 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
			local at = u.cf.Position + r * (s[1] * u.hx * 0.8) + l * (s[2] * u.hz * 0.8)
			local hit = workspace:Raycast(Vector3.new(at.X, u.y1 + 60, at.Z), Vector3.new(0, -400, 0), params)
			local h = math.max(hit and hit.Position.Y or -999, builtTop(at.X, at.Z, u.y0 + 4))
			lo, hi = math.min(lo, h), math.max(hi, h)
		end
		local sunk, hang = hi - u.y0, u.y0 - lo
		local limit = if u.tree then 5 else 3.5
		if sunk > limit + (u.m:GetAttribute("SunkOk") or 0) or hang > limit + (u.m:GetAttribute("HangOk") or 0) then
			nGround += 1
			table.insert(out, string.format("  GROUND %%s (%%.0f, %%.0f, %%.0f): ground reaches %%.1f above its base, falls %%.1f below it", u.name, u.cf.Position.X, u.y0, u.cf.Position.Z, sunk, hang))
		end
	end
	-- the lane: nothing below 60 studs above the floor may cross the lane's edge
	local r, l = u.cf.RightVector, u.cf.LookVector
	local reach = math.abs(u.cf.Position.X) - (math.abs(r.X) * u.size.X / 2 + math.abs(l.X) * u.size.Z / 2)
	if reach < 159 and u.y0 < 12 and not u.m:GetAttribute("LaneOk") then
		nLane += 1
		table.insert(out, string.format("  LANE %%s (%%.0f, %%.0f): its box reaches x %%.0f, inside the lane's edge at 160", u.name, u.cf.Position.X, u.cf.Position.Z, reach))
	end
end
table.sort(out)
local shown = {}
for i = 1, math.min(#out, 60) do
	shown[i] = out[i]
end
table.insert(shown, 1, string.format("audit Zone_%%s: %%d models, %%d overlaps, %%d ground faults, %%d in the lane", ID, #units, nOverlap, nGround, nLane))
return table.concat(shown, string.char(10))
'''


def audit(args):
    shrink = "0.86"
    tolerance = "1.5"
    for a in args[1:]:
        if a.startswith("--shrink="):
            shrink = a.split("=", 1)[1]
        if a.startswith("--tolerance="):
            tolerance = a.split("=", 1)[1]
    return run(AUDIT % {"id": args[0], "shrink": shrink, "tolerance": tolerance})


def look(args):
    """look x y z tx ty tz [seconds]: parks the Studio camera there, wakes the display and waits, so the
    terrain has refined before screen_capture is called WITHOUT a camera position. (A capture that
    carries its own camera position is taken at once, with the terrain still in its coarse far-away
    form: flat ground then shows as raised blocks that swallow paving.)"""
    import time
    x, y, z, tx, ty, tz = [float(a) for a in args[:6]]
    wait = float(args[6]) if len(args) > 6 else 6
    code = (
        "local cam = workspace.CurrentCamera cam.CameraType = Enum.CameraType.Scriptable "
        f"cam.CFrame = CFrame.lookAt(Vector3.new({x}, {y}, {z}), Vector3.new({tx}, {ty}, {tz})) "
        f"cam.Focus = CFrame.new({tx}, {ty}, {tz}) return 'camera parked'"
    )
    front = os.path.join(os.path.dirname(HERE), "front.ps1")
    subprocess.run(["powershell", "-File", front], capture_output=True)
    code_rc = run(code)
    time.sleep(wait)
    subprocess.run(["powershell", "-File", front], capture_output=True)
    return code_rc


def clear(_args):
    return run('local q = workspace:FindFirstChild("Quarantine") if q then q:Destroy() end return "quarantine cleared"')


if __name__ == "__main__":
    command, rest = sys.argv[1], sys.argv[2:]
    sys.exit({"build": build, "store": store, "check": check, "clear": clear, "inspect": inspect, "audit": audit, "look": look}[command](rest))
