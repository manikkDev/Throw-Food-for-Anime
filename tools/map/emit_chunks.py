"""Emit design/map.json as Studio-runnable Luau chunks (each under ~150 KB).

    python tools/map/emit_chunks.py            # after build_map.py wrote work/map/terrain

WHY NOT emit.py. The skill's emit.py writes bare Parts: no mesh clones, no
ProximityPrompts, no GUIs, no terrain. serve_map.py needs an HTTP loop. The game
needs Workspace.Map with the Blockout anchor contract, so this emitter reads the
SAME resolved tree (spec.load -> both gates, spec.resolve, emit._apply_lift) and
the SAME terrain output (work/map/terrain, hash-checked against the spec), and
adds the contract on top from each part's "build" block.

Every chunk is re-runnable: it destroys the containers it owns, then rebuilds
them. It yields (task.wait) between batches, so execute_luau may drop its
printed output; every chunk also writes its summary to Workspace.Map attribute
"Chunk_<id>" and Workspace.Map attribute "LastChunk".

Finally the EMITTED files are parsed back and every top face is audited
against y=0 (the skill's trap: a lift dropped by an emitter left surfaces at
exactly 0.00 while the spec looked fine).
"""

from __future__ import annotations

import json
import math
import os
import re
import sys

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SKILL = os.path.join(os.path.expanduser("~"), ".claude", "skills", "roblox-map", "scripts")
sys.path.insert(0, SKILL)
import emit as emitmod  # noqa: E402
import spec as specmod  # noqa: E402
import terrain as terrainmod  # noqa: E402

SPEC = os.path.join(ROOT, "design", "map.json")
TEX_IDS_FILE = os.path.join(ROOT, "assets", "map", "ids_textures.json")
TEX_IDS = {}
if os.path.isfile(TEX_IDS_FILE):
    with open(TEX_IDS_FILE, encoding="utf-8") as _fh:
        TEX_IDS = {k: v for k, v in json.load(_fh).items() if not k.startswith("_") and v}
TEX_USE = {}          # texture name -> parts that ask for it (reported, with or without an id)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_textures import TEXTURES as _TEXTURES  # noqa: E402
TEX_STUDS = {k: v[1] for k, v in _TEXTURES.items()}
OUT = os.path.join(ROOT, "work", "map", "chunks")
TERR = os.path.join(ROOT, "work", "map", "terrain")
LIMIT = 140_000
# Floor text (zone names, TRAINING YARD) on a part's TOP face. Measured by eye 2026-11-15: with
# Rotation 0 the text runs along Z, i.e. the Top-face canvas's up axis is +-X. For a player facing
# +Z (base -> lane) the text must run along X with its top toward +Z. Reading of the convention: the
# canvas up is world -X, so a -90 (anticlockwise) turn puts it at +Z. If it reads upside down in
# Studio, set 90. The label is resized to the part's X:Z aspect before turning so it fills the face.
FLOOR_TEXT_ROTATION = -90
BATCH = 30
B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

TERRAIN_COLOURS = {   # kit.json palette; Terrain:SetMaterialColor is global per material
    "Grass": "#5BD43A", "LeafyGrass": "#3FBF6A", "Sand": "#F4D58A", "Rock": "#8E98A8",
    "Ground": "#E2B97A", "Cobblestone": "#CBB89A", "Slate": "#9AA4B2", "Basalt": "#4A5070",
    "Salt": "#D9C9FF", "Limestone": "#F7E7C4", "Mud": "#8A5A2B", "WoodPlanks": "#B5793F",
}


def f(v):
    s = f"{v:.3f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def lstr(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def ltable(d):
    if isinstance(d, dict):
        return "{" + ",".join(f"{k}={ltable(v)}" for k, v in d.items()) + "}"
    if isinstance(d, (list, tuple)):
        return "{" + ",".join(ltable(v) for v in d) + "}"
    if isinstance(d, bool):
        return "true" if d else "false"
    if isinstance(d, (int, float)):
        return f(float(d))
    return lstr(d)


HELPERS = "local FLOOR_TEXT_ROTATION = " + str(FLOOR_TEXT_ROTATION) + "\n" + r'''
local RS = game:GetService("ReplicatedStorage")
local MAP = workspace:FindFirstChild("Map")
if not MAP then error("Workspace.Map is missing: run 00_setup.lua first") end
local ASSETS = RS:FindFirstChild("Assets")
local KIT = ASSETS and ASSETS:FindFirstChild("Kit")
local ACCENT = Color3.fromRGB(255, 0, 255)
local stats = {parts = 0, meshes = 0, missing = 0, missingNames = {}, anchors = 0, prompts = 0, textures = 0}

local MODEL_CONTAINERS = {Hub = true, Aprons = true}
local function container(path)
	local node = MAP
	for seg in string.gmatch(path, "[^/]+") do
		local c = node:FindFirstChild(seg)
		if not c then
			local isPlot = string.match(seg, "^Plot(%d+)$")
			local isLaneZone = node.Name == "Lanes" and string.match(seg, "^Zone_")
			if isPlot or MODEL_CONTAINERS[seg] or isLaneZone then
				c = Instance.new("Model")
				pcall(function() c.ModelStreamingMode = Enum.ModelStreamingMode.Persistent end)
				if isPlot then c:SetAttribute("Plot", tonumber(isPlot)) end
			else
				c = Instance.new("Folder")
			end
			c.Name = seg
			c.Parent = node
		end
		node = c
	end
	return node
end

local function wipe(paths)
	for _, p in ipairs(paths) do
		local node = MAP
		for seg in string.gmatch(p, "[^/]+") do
			node = node and node:FindFirstChild(seg)
		end
		if node then node:Destroy() end
	end
end

local function isAccent(c)
	return math.abs(c.R - 1) < 0.02 and c.G < 0.02 and math.abs(c.B - 1) < 0.02
end

local function setCollide(inst, collide, fidelity)
	local fid = Enum.CollisionFidelity[fidelity or "Box"]
	local list = inst:IsA("BasePart") and {inst} or inst:GetDescendants()
	for _, d in ipairs(list) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = collide
			d.CanTouch = false
			if not collide then d.CanQuery = false end
			if d:IsA("MeshPart") then
				-- research 06 s2.1: collision data stays in memory even with CanCollide off: Box always
				pcall(function() d.CollisionFidelity = collide and fid or Enum.CollisionFidelity.Box end)
			end
		end
	end
end

local function farModel(inst, far, shadow)
	-- research 06 s2.1: far layers get a StreamingMesh imposter and cast no shadows
	if far and inst:IsA("Model") then
		pcall(function() inst.LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh end)
	end
	if far or shadow == false then
		for _, d in ipairs(inst:IsA("BasePart") and {inst} or inst:GetDescendants()) do
			if d:IsA("BasePart") then d.CastShadow = false end
		end
	end
end

-- Place a kit model with its BASE CENTRE at (x, y, z) facing yaw. Never trusts the
-- pivot (SKILL.md: a PrimaryPart moves the pivot): orient, measure, translate.
local function kitModel(kit, name, x, y, z, yaw, s, collide, parent, scale, fidelity)
	local tpl = KIT and KIT:FindFirstChild(kit)
	local inst
	if tpl then
		inst = tpl:Clone()
		local rot = CFrame.Angles(0, math.rad(yaw), 0)
		if inst:IsA("Model") then
			if scale and scale ~= 1 then inst:ScaleTo(inst:GetScale() * scale) end
			inst:PivotTo(rot)
			local cf, size = inst:GetBoundingBox()
			inst:PivotTo(inst:GetPivot() + (Vector3.new(x, y + size.Y / 2, z) - cf.Position))
			pcall(function() inst.ModelStreamingMode = Enum.ModelStreamingMode.Atomic end)
		elseif inst:IsA("BasePart") then
			inst.CFrame = CFrame.new(x, y + inst.Size.Y / 2, z) * rot
		end
		setCollide(inst, collide, fidelity)
		stats.meshes += 1
	else
		inst = Instance.new("Part")
		inst.Size = Vector3.new(s[1], s[2], s[3])
		inst.CFrame = CFrame.new(x, y + s[2] / 2, z) * CFrame.Angles(0, math.rad(yaw), 0)
		inst.Transparency = 0.5
		inst.Color = Color3.fromRGB(163, 162, 165)
		inst.Material = Enum.Material.SmoothPlastic
		inst.TopSurface = Enum.SurfaceType.Smooth
		inst.BottomSurface = Enum.SurfaceType.Smooth
		inst.CastShadow = false
		inst:SetAttribute("MissingMesh", true)
		setCollide(inst, collide)
		stats.missing += 1
		stats.missingNames[kit] = (stats.missingNames[kit] or 0) + 1
	end
	inst.Name = name or kit
	inst:SetAttribute("Kit", kit)
	inst.Parent = parent
	return inst
end

local function recolour(inst, rgb)
	local list = inst:IsA("BasePart") and {inst} or inst:GetDescendants()
	for _, d in ipairs(list) do
		if d:IsA("BasePart") and isAccent(d.Color) then
			d.Color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
		end
	end
end

local function billboard(parent, b)
	local gui = Instance.new("BillboardGui")
	gui.Name = b.name
	gui.Size = UDim2.fromScale(b.studs, b.studs / 4)
	-- the offset is in the parent's own axes: say world up in them (a cylinder lies on its side)
	gui.StudsOffsetWorldSpace = if parent:IsA("BasePart") then parent.CFrame:VectorToObjectSpace(Vector3.new(0, b.height, 0)) else Vector3.new(0, b.height, 0)
	gui.MaxDistance = b.max or 260
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0
	t.Text = b.text
	t.Parent = gui
	gui.Parent = parent
end

local KEYS = {E = Enum.KeyCode.E, F = Enum.KeyCode.F}
local function prompt(parent, p)
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "Prompt_" .. p.action
	pr.ActionText = p.text
	pr.ObjectText = parent.Name
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 12
	pr.RequiresLineOfSight = false
	pr.KeyboardKeyCode = KEYS[p.key] or Enum.KeyCode.E
	pr:SetAttribute("Action", p.action)
	if p.plot then pr:SetAttribute("Plot", p.plot) end
	if p.station then pr:SetAttribute("Station", p.station) end
	pr.Parent = parent
	stats.prompts += 1
end

-- The kit's blank faces are a part named Face_<hex>. MEASURED 2026-11-14 on the installed
-- templates: the panel's outward side is the MeshPart's BACK face (the importer's half turn
-- lives in the part's frame), so a GUI adorned to a Face part uses NormalId.Back. A GUI on a
-- plain anchor Part placed in front of a model uses NormalId.Front (the part looks outward).
local function findFace(inst)
	if not inst or inst:GetAttribute("MissingMesh") then return nil end
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") and string.match(d.Name, "^Face_") then return d end
	end
	return nil
end

local function surfaceText(parent, guiName, face, text, canvas, textSize, adornee)
	local gui = Instance.new("SurfaceGui")
	gui.Name = guiName
	gui.Face = face
	gui.CanvasSize = canvas
	gui.LightInfluence = 0
	if adornee then gui.Adornee = adornee end
	local ink = adornee and (adornee.Color.R + adornee.Color.G + adornee.Color.B) > 1.8
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = ink and Color3.fromRGB(13, 15, 43) or Color3.new(1, 1, 1)
	t.TextStrokeTransparency = ink and 1 or 0
	if textSize then
		t.TextSize = textSize
		t.TextYAlignment = Enum.TextYAlignment.Top
	else
		t.TextScaled = true
	end
	t.Text = text
	t.Parent = gui
	gui.Parent = parent
end

local function anchorPart(name, size, cf, parent)
	local a = Instance.new("Part")
	a.Name = name
	a.Size = Vector3.new(size[1], size[2], size[3])
	a.CFrame = cf
	a.Anchored = true
	a.CanCollide = false
	a.CanTouch = false
	a.CanQuery = false
	a.Transparency = 1
	a.CastShadow = false
	a.Parent = parent
	stats.anchors += 1
	return a
end

local function plainPart(e, parent)
	local p = Instance.new("Part")
	p.Name = e.name
	if e.shape == "ball" then
		p.Shape = Enum.PartType.Ball
		local d = math.min(e.s[1], e.s[2], e.s[3])
		p.Size = Vector3.new(d, d, d)
		p.CFrame = CFrame.new(e.x, e.y, e.z)
	elseif e.shape == "cylinder" then
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(e.s[2], e.s[1], e.s[3])
		p.CFrame = CFrame.new(e.x, e.y, e.z) * CFrame.Angles(0, math.rad(e.yaw), math.rad(90))
	else
		p.Size = Vector3.new(e.s[1], e.s[2], e.s[3])
		p.CFrame = CFrame.new(e.x, e.y, e.z) * CFrame.Angles(0, math.rad(e.yaw), 0)
	end
	p.Anchored = true
	p.CanCollide = e.col ~= false
	p.Transparency = e.vis == false and 1 or 0
	if e.rgb then p.Color = Color3.fromRGB(e.rgb[1], e.rgb[2], e.rgb[3]) end
	p.Material = Enum.Material[e.mat or "SmoothPlastic"]
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if e.attrs then for k, v in pairs(e.attrs) do p:SetAttribute(k, v) end end
	if e.noshadow then p.CastShadow = false end
	if e.noquery then p.CanQuery = false; p.CanTouch = false end
	if e.tex then
		-- a tiled Texture per face (brief D); only emitted when assets/map/ids_textures.json has the id
		for _, face in ipairs(e.tex.faces) do
			local t = Instance.new("Texture")
			t.Name = "Tile_" .. e.tex.name
			t.Texture = "rbxassetid://" .. e.tex.id
			t.Face = Enum.NormalId[face]
			t.StudsPerTileU = e.tex.su
			t.StudsPerTileV = e.tex.sv
			t.Color3 = Color3.fromRGB(e.tex.c[1], e.tex.c[2], e.tex.c[3])
			t.Parent = p
			stats.textures += 1
		end
	end
	if e.facetext then
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Plaque"
		gui.Face = Enum.NormalId[e.facetext.face]
		gui.LightInfluence = 0
		gui.MaxDistance = 400
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		local t = Instance.new("TextLabel")
		t.Name = "Text"
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = Color3.fromRGB(13, 15, 43)
		t.Text = e.facetext.text
		t.Parent = gui
		gui.Parent = p
	end
	if e.toplabel then
		local gui = Instance.new("SurfaceGui")
		gui.Name = "FloorLabel"
		gui.Face = Enum.NormalId.Top
		gui.LightInfluence = 0
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 20
		local t = Instance.new("TextLabel")
		t.Name = "Text"
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = Color3.new(1, 1, 1)
		t.TextTransparency = 0.05
		t.TextStrokeTransparency = 0.4
		t.Text = e.toplabel
		-- the Top-face canvas runs along Z (measured): make the label the part's X:Z shape, then turn it
		-- by FLOOR_TEXT_ROTATION so it reads along X, upright for a player facing +Z
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.Position = UDim2.fromScale(0.5, 0.5)
		t.Size = UDim2.fromScale(e.s[1] / e.s[3], e.s[3] / e.s[1])
		t.Rotation = FLOOR_TEXT_ROTATION
		t.Parent = gui
		gui.Parent = p
	end
	p.Parent = parent
	stats.parts += 1
	return p
end

local BUILD = {}
BUILD.part = function(e)
	local parent = container(e.f)
	local p = plainPart(e, parent)
	if e.prompt then prompt(p, e.prompt) end
	if e.billboard then billboard(p, e.billboard) end
	if e.primary and parent:IsA("Model") then parent.PrimaryPart = p end
end
BUILD.barrier = function(e)
	local p = plainPart(e, container(e.f))
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
end
BUILD.mesh = function(e)
	local parent = container(e.f)
	local holder = parent
	if e.banner then
		holder = Instance.new("Model")
		holder.Name = e.name
		pcall(function() holder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent end)
		holder.Parent = parent
	end
	local m = kitModel(e.kit, e.banner and e.kit or nil, e.x, e.y, e.z, e.yaw, e.s, e.col, holder, e.scale)
	if e.accent then recolour(m, e.accent) end
	farModel(m, e.far, e.shadow)
	if e.banner then
		local face = findFace(m)
		if face then
			surfaceText(face, "Banner", Enum.NormalId.Back, e.banner.text, Vector2.new(520, 80), nil, face)
		else
			local rot = CFrame.Angles(0, math.rad(e.yaw), 0)
			local front = rot.LookVector * (e.s[3] / 2 + 0.15)
			local a = anchorPart("Banner", {e.banner.size[1], e.banner.size[2], 0.2},
				CFrame.new(e.x, e.y + e.banner.dy, e.z) * rot + front, holder)
			surfaceText(a, "Banner", Enum.NormalId.Front, e.banner.text, Vector2.new(520, 80))
		end
	end
end
BUILD.anchor = function(e)
	local parent = container(e.f)
	local rot = CFrame.Angles(0, math.rad(e.yaw), 0)
	local size = e.asize or e.s
	local cy = e.ady and (e.y + e.ady) or (e.y + e.s[2] / 2)
	local a = anchorPart(e.name, size, CFrame.new(e.x, cy, e.z) * rot, parent)
	local m = kitModel(e.kit, nil, e.x, e.y, e.z, e.yaw, e.s, e.col, a, e.scale, e.fid)
	local face = findFace(m)
	if e.billboard and face and e.billboard.name == "Title" and e.facegui then
		-- the server's setText finds anchor.Title.Text: a SurfaceGui named Title, adorned to the face
		surfaceText(a, "Title", Enum.NormalId.Back, e.billboard.text, Vector2.new(400, 160), nil, face)
	elseif e.billboard then
		billboard(a, e.billboard)
	end
	if face and e.facelabel then
		surfaceText(face, "Label", Enum.NormalId.Back, e.facelabel, Vector2.new(300, 260), nil, face)
	end
	if e.prompt then prompt(a, e.prompt) end
end
BUILD.board = function(e)
	local parent = container(e.f)
	local rot = CFrame.Angles(0, math.rad(e.yaw), 0)
	local front = rot.LookVector * (e.s[3] / 2 + 0.12)
	local a = anchorPart(e.name, {e.face[1], e.face[2], 0.2},
		CFrame.new(e.x, e.y + e.fdy, e.z) * rot + front, parent)
	local m = kitModel(e.kit, nil, e.x, e.y, e.z, e.yaw, e.s, e.col, a)
	-- LeaderboardService paints Hub.<name>.Board.Text: the SurfaceGui stays a child of the
	-- anchor and is adorned to the frame's Face part when the template has one
	-- on the anchor itself (it sits 0.12 in front of the frame and looks outward): the client
	-- mounts its own board on this part and face, and an Adornee can be streamed out
	surfaceText(a, "Board", Enum.NormalId.Front, e.name, Vector2.new(360, 440), 26)
end
BUILD.pedestal = function(e)
	local parent = container(e.f)
	local body = container(e.dress)
	local m = kitModel(e.kit, "PedestalBody" .. e.slot, e.x, e.y, e.z, e.yaw, e.s, true, body)
	local accent
	if m:GetAttribute("MissingMesh") then
		accent = m
	else
		local best, bestTop = nil, -math.huge
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				if isAccent(d.Color) then accent = d break end
				local top = d.Position.Y + d.Size.Y / 2
				if top > bestTop then best, bestTop = d, top end
			end
		end
		accent = accent or best
		m:SetAttribute("AccentDetached", accent ~= nil)
	end
	if accent then
		accent.Name = "Pedestal" .. e.slot
		accent:SetAttribute("Slot", e.slot)
		accent:SetAttribute("Kit", e.kit)
		accent.Anchored = true
		accent.CanCollide = true
		accent.Parent = parent
	end
end
BUILD.spawn = function(e)
	local s = Instance.new("SpawnLocation")
	s.Name = e.name
	s.Anchored = true
	s.Neutral = true
	s.Enabled = false -- used through Player.RespawnLocation, never as a random spawn
	s.Transparency = 1
	s.CanCollide = false
	s.Duration = 0
	s.Size = Vector3.new(e.s[1], e.s[2], e.s[3])
	s.Position = Vector3.new(e.x, e.y, e.z)
	s.Parent = container(e.f)
end
BUILD.hubspawn = function(e)
	local s = Instance.new("SpawnLocation")
	s.Name = e.name
	s.Anchored = true
	s.Neutral = true
	s.Enabled = true -- the join spawn; PlotService then moves the player to their plot Spawn
	s.Transparency = 1
	s.CanCollide = false
	s.Duration = 0
	s.Size = Vector3.new(e.s[1], e.s[2], e.s[3])
	s.Position = Vector3.new(e.x, e.y, e.z)
	s.Parent = container(e.f)
end

local function run(id, owned, list)
	wipe(owned)
	for i, e in ipairs(list) do
		BUILD[e.k](e)
		if i % BATCH == 0 then task.wait() end
	end
	local miss = {}
	for k, n in pairs(stats.missingNames) do table.insert(miss, k .. " x" .. n) end
	table.sort(miss)
	local msg = string.format("%s: %d placements, %d plain parts, %d meshes cloned, %d MISSING (grey boxes), %d anchors, %d prompts, %d textures%s",
		id, #list, stats.parts, stats.meshes, stats.missing, stats.anchors, stats.prompts, stats.textures,
		#miss > 0 and (" | missing: " .. table.concat(miss, ", ")) or "")
	MAP:SetAttribute("Chunk_" .. id, msg)
	MAP:SetAttribute("LastChunk", id)
	print(msg)
	return msg
end
'''


def entry(b, raw):
    """One placement -> Luau table, from the RESOLVED box b and the raw build block."""
    bd = raw["build"]
    k = bd["kind"]
    sx, sy, sz = b.size
    cx, cy, cz = b.centre
    e = {"k": k, "f": bd["folder"], "name": bd.get("name", raw["id"]), "x": cx, "z": cz, "yaw": b.yaw,
         "s": [sx, sy, sz]}
    if k in ("mesh", "anchor", "board", "pedestal"):
        e["y"] = cy - sy / 2               # base of the box: the model's base sits here
        e["kit"] = bd["kit"]
        e["col"] = bool(bd.get("collide", True))
        if k == "mesh" and "name" not in bd:
            e.pop("name")
    else:
        e["y"] = cy
    if k == "part" or k == "barrier":
        e["rgb"] = b.meta.get("color")
        e["mat"] = b.meta.get("material", "SmoothPlastic")
        e["col"] = bool(b.solid)
        e["vis"] = bool(b.visible)
        if b.meta.get("shape") in ("cylinder", "ball"):
            e["shape"] = b.meta.get("shape")
    if k == "part" and raw.get("texture"):
        t = raw["texture"]
        t = t if isinstance(t, dict) else {"name": t}
        tid = TEX_IDS.get(t["name"])
        TEX_USE[t["name"]] = TEX_USE.get(t["name"], 0) + 1
        if tid:
            rgb = b.meta.get("color") or [255, 255, 255]
            tint = t.get("tint") or [round(c + (255 - c) * 0.6) for c in rgb]
            st = t.get("studs") or TEX_STUDS.get(t["name"], 8)
            e["tex"] = {"name": t["name"], "id": str(tid), "faces": t.get("faces") or ["Top"],
                        "su": t.get("su") or st, "sv": t.get("sv") or st, "c": tint}
    for src, dst in (("far", "far"), ("shadow", "shadow"), ("facetext", "facetext"), ("noshadow", "noshadow"), ("toplabel", "toplabel"), ("labelrot", "labelrot"), ("fidelity", "fid"), ("scale", "scale"), ("facegui", "facegui"), ("facelabel", "facelabel"), ("prompt", "prompt"), ("billboard", "billboard"), ("accent", "accent"),
                     ("banner", "banner"), ("attrs", "attrs"), ("primary", "primary"), ("face", "face"), ("noquery", "noquery")):
        if src in bd:
            e[dst] = bd[src]
    if "anchor_size" in bd:
        e["asize"] = bd["anchor_size"]
    if "anchor_dy" in bd:
        e["ady"] = bd["anchor_dy"]
    if "face_dy" in bd:
        e["fdy"] = bd["face_dy"]
    if k == "pedestal":
        e["slot"] = bd["slot"]
        e["dress"] = bd["folder"].rsplit("/", 1)[0] + "/Dressing"
    order = ["k", "f", "name", "kit", "x", "y", "z", "yaw", "s"]
    out = {key: e[key] for key in order if key in e}
    out.update({key: v for key, v in e.items() if key not in out})
    return out


def write(name, text):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    data = text.encode("utf-8")
    if len(data) > 150_000:
        raise SystemExit(f"{name} is {len(data)} bytes - over the 150 KB chunk limit")
    with open(path, "wb") as fh:
        fh.write(data)
    return path, len(data)


def part_chunks(groups):
    """groups: list of (chunk_id, owned_paths, [entries]) -> split by size."""
    files = []
    for cid, owned, ents in groups:
        lines = [ltable(e) for e in ents]
        parts, cur, size = [], [], 0
        for ln in lines:
            if cur and size + len(ln) > LIMIT - len(HELPERS) - 2000:
                parts.append(cur)
                cur, size = [], 0
            cur.append(ln)
            size += len(ln) + 2
        parts.append(cur)
        # a chunk too big for one file is split into <cid>_<k>of<N>: ONLY the first wipes the owned
        # containers, so run the set in name order (build_in_studio.py does)
        for k, body_lines in enumerate(parts, 1):
            fid = cid if len(parts) == 1 else f"{cid}_{k}of{len(parts)}"
            wipe = owned if k == 1 else []
            note = f"wipes {', '.join(owned)} first" if wipe else f"run after {cid}_1of{len(parts)}"
            body = (f"-- Throw Food for Anime map chunk {fid}. GENERATED by tools/map/emit_chunks.py "
                    f"from design/map.json. Re-runnable as a set: {note}.\n"
                    f"local BATCH = {BATCH}\n" + HELPERS +
                    f"\nreturn run({lstr(fid)}, {{{','.join(lstr(o) for o in wipe)}}}, {{\n"
                    + ",\n".join(body_lines) + "\n})\n")
            files.append((fid, body))
    return files


SETUP = r'''-- Throw Food for Anime map chunk 00_setup. GENERATED by tools/map/emit_chunks.py.
-- Creates Workspace.Map {Plots, Hub, Lanes, Scenery, Barriers} FRESH (destroys an old Map),
-- removes the template Baseplate/SpawnLocation, and sets the terrain material colours.
for _, n in ipairs({"Baseplate", "SpawnLocation"}) do
	local o = workspace:FindFirstChild(n)
	if o then o:Destroy() end
end
local old = workspace:FindFirstChild("Map")
if old then old:Destroy() end
local map = Instance.new("Folder")
map.Name = "Map"
map:SetAttribute("Blockout", false)
map:SetAttribute("Spec", "design/map.json FestivalLane")
map:SetAttribute("SpecHash", "%(hash)s")
for _, n in ipairs({"Plots", "Hub", "Lanes", "Scenery", "Barriers"}) do
	local c
	if n == "Hub" then
		c = Instance.new("Model")
		pcall(function() c.ModelStreamingMode = Enum.ModelStreamingMode.Persistent end)
	else
		c = Instance.new("Folder")
	end
	c.Name = n
	c.Parent = map
end
map.Parent = workspace
local T = workspace.Terrain
-- no animated grass blades: they hid the landing strip, the food and the hero's feet
pcall(function() T.Decoration = false end)
local cols = %(cols)s
for name, rgb in pairs(cols) do
	pcall(function() T:SetMaterialColor(Enum.Material[name], Color3.fromRGB(rgb[1], rgb[2], rgb[3])) end)
end
return "00_setup: Workspace.Map created with Plots, Hub, Lanes, Scenery, Barriers; terrain colours set"
'''

TERRAIN_HEAD = r'''-- Throw Food for Anime map chunk %(cid)s: smooth voxel terrain rows %(r0)d..%(r1)d of %(nz)d.
-- GENERATED by tools/map/emit_chunks.py from work/map/terrain (terrain.py output, hash %(hash)s).
-- Re-runnable: each tile writes EVERY voxel of its region (ground, water, air) from floorY up.
-- Column code: 2 chars height ((h + 64) * 8, base64) + 1 char material index. Same voxel rule as
-- the skill's build_terrain.lua: partial occupancy in the top voxel, top 2 voxels wear the surface
-- material, deeper is Rock; Water fills empty voxels below the tide line (%(tide)s).
local T = workspace.Terrain
local V = 4
local NX, X0, Z0, FLOORY, NY, TIDE = %(nx)d, %(x0)s, %(z0)s, %(floory)d, %(ny)d, %(tide)s
local MATS = %(mats)s
local DEEP = Enum.Material.Rock
local WATER, AIR = Enum.Material.Water, Enum.Material.Air
local B = {}
local A = "%(alpha)s"
for i = 1, 64 do B[string.byte(A, i)] = i - 1 end
local function tile(r0, rows, data)
	local occ, mat = table.create(NX), table.create(NX)
	for ix = 1, NX do
		local ocol, mcol = table.create(NY), table.create(NY)
		for iy = 1, NY do
			ocol[iy] = table.create(rows, 0)
			mcol[iy] = table.create(rows, AIR)
		end
		occ[ix], mat[ix] = ocol, mcol
	end
	for iz = 1, rows do
		for ix = 1, NX do
			local p = ((iz - 1) * NX + (ix - 1)) * 3 + 1
			local hv = (B[string.byte(data, p)] * 64 + B[string.byte(data, p + 1)]) / 8 - 64
			local surface = MATS[B[string.byte(data, p + 2)]] or Enum.Material.Grass
			local ocol, mcol = occ[ix], mat[ix]
			for iy = 1, NY do
				local y0 = FLOORY + (iy - 1) * V
				local o = (hv - y0) / V
				if o > 0 then
					if o > 1 then o = 1 end
					ocol[iy][iz] = o
					mcol[iy][iz] = (hv - y0 <= V * 2) and surface or DEEP
				elseif y0 + V <= TIDE then
					ocol[iy][iz] = 1
					mcol[iy][iz] = WATER
				end
			end
		end
	end
	local z0 = Z0 + r0 * V
	local region = Region3.new(Vector3.new(X0, FLOORY, z0), Vector3.new(X0 + NX * V, FLOORY + NY * V, z0 + rows * V))
	T:WriteVoxels(region, V, mat, occ)
end
local done = 0
'''


def terrain_chunks(spec):
    t = terrainmod.load_output(TERR)
    meta = t["meta"]
    import hashlib
    want = hashlib.sha256(json.dumps(spec["terrain"], sort_keys=True).encode()).hexdigest()[:16]
    if meta["hash"] != want:
        raise SystemExit(f"work/map/terrain is stale (hash {meta['hash']} vs spec {want}): rerun build_map.py")
    h, m = t["height"], t["material"]
    g = meta["grid"]
    nz, nx = h.shape
    tide = float(meta["tide"]["high"])
    floory = int(math.floor((float(h.min()) - 8) / 4) * 4)
    top = float(h.max())
    ny = int(math.ceil((top - floory) / 4)) + 1
    q = np.clip(np.round((h + 64.0) * 8), 0, 4095).astype(int)
    mats = "{" + ",".join(f"[{i}]=Enum.Material.{n}" for i, n in enumerate(meta["materials"])) + "}"
    head = TERRAIN_HEAD % {"cid": "%(cid)s", "r0": 0, "r1": 0, "nz": nz, "hash": meta["hash"], "tide": f(tide),
                           "nx": nx, "x0": f(g["x0"]), "z0": f(g["z0"]), "floory": floory, "ny": ny,
                           "mats": mats, "alpha": B64}
    rows_per_tile = 24
    tiles = []
    for r0 in range(0, nz, rows_per_tile):
        rows = min(rows_per_tile, nz - r0)
        buf = []
        for iz in range(r0, r0 + rows):
            for ix in range(nx):
                v = q[iz, ix]
                buf.append(B64[v >> 6] + B64[v & 63] + B64[int(m[iz, ix])])
        tiles.append((r0, rows, "".join(buf)))
    files, cur, size, k = [], [], 0, 0
    budget = LIMIT - len(head) - 1500
    for tl in tiles:
        ln = len(tl[2]) + 40
        if cur and size + ln > budget:
            files.append(cur)
            cur, size = [], 0
        cur.append(tl)
        size += ln
    if cur:
        files.append(cur)
    out = []
    for i, group in enumerate(files, 1):
        cid = f"01_terrain_{i}of{len(files)}"
        body = (head.replace("%(cid)s", cid)
                .replace("rows 0..0", f"rows {group[0][0]}..{group[-1][0] + group[-1][1] - 1}"))
        if i == 1:
            body += "T:Clear() -- first terrain chunk: start from empty terrain\n"
        for (r0, rows, data) in group:
            body += f'tile({r0}, {rows}, "{data}")\ndone += 1\ntask.wait()\n'
        body += (f'local msg = "{cid}: wrote " .. done .. " tiles of {nx} x 24 columns, voxel floor {floory}, '
                 f'{ny} voxel layers"\n'
                 'local map = workspace:FindFirstChild("Map")\n'
                 f'if map then map:SetAttribute("Chunk_{cid}", msg) map:SetAttribute("LastChunk", "{cid}") end\n'
                 "print(msg)\nreturn msg\n")
        out.append((cid, body))
    return out, {"nx": nx, "nz": nz, "floory": floory, "ny": ny, "tide": tide,
                 "voxels_written": nx * nz * ny, "hash": meta["hash"]}


def main():
    m = specmod.load(SPEC)            # both gates (slab ground, mesh first) run here
    lift = emitmod._apply_lift(m)     # explicit 0 for this map; applied anyway so a change cannot be lost
    raw_spec = json.load(open(SPEC, encoding="utf-8"))
    raw = {p["id"]: p for p in raw_spec["parts"]}

    # chunk ids and owned container paths come from the spec (gen_map.chunk_of), so a new zone or
    # plot gets its own re-runnable chunk without touching this file
    groups = {}
    for b in m.boxes:
        r = raw.get(b.name)
        if r is None or "build" not in r or "chunk" not in r["build"]:
            raise SystemExit(f"part {b.name} has no build block / chunk")
        groups.setdefault(r["build"]["chunk"], []).append(entry(b, r))

    def owned(key, ents):
        return raw_spec["chunks"][key]

    for f_ in os.listdir(OUT) if os.path.isdir(OUT) else []:
        if f_.endswith(".lua"):
            os.remove(os.path.join(OUT, f_))
    written = []
    hash_ = json.load(open(os.path.join(TERR, "terrain.json"), encoding="utf-8"))["hash"]
    cols = "{" + ",".join(f"{k}={{{','.join(str(v) for v in [int(c[1:3], 16), int(c[3:5], 16), int(c[5:7], 16)])}}}"
                          for k, c in TERRAIN_COLOURS.items()) + "}"
    written.append(write("00_setup.lua", SETUP % {"hash": hash_, "cols": cols}))
    tch, tinfo = terrain_chunks(raw_spec)
    for cid, body in tch:
        written.append(write(f"{cid}.lua", body))
    for cid, body in part_chunks([(k, owned(k, v), v) for k, v in sorted(groups.items())]):
        written.append(write(f"{cid}.lua", body))

    # ---- audit the EMITTED numbers, not the spec's
    audit = audit_emitted(raw_spec)
    tex = {n: {"parts": c, "id": TEX_IDS.get(n)} for n, c in sorted(TEX_USE.items())}
    report = {"lift": lift, "textures": tex,
              "files": [{"file": os.path.basename(p), "bytes": n} for p, n in written],
              "terrain": tinfo, "audit": audit,
              "counts": {k: len(v) for k, v in sorted(groups.items())}}
    with open(os.path.join(ROOT, "work", "map", "emit_report.json"), "w", encoding="utf-8") as fh:
        json.dump(report, fh, indent=1)
    for w in report["files"]:
        print(f"{w['file']:40s} {w['bytes']:8d} bytes")
    print("terrain:", tinfo)
    print("textures (parts asking / id):", {n: (v["parts"], v["id"] or "NO ID - plain colour") for n, v in tex.items()})
    print("audit:", json.dumps(audit, indent=1)[:3000])
    if audit["errors"]:
        raise SystemExit("EMITTED-HEIGHT AUDIT FAILED")


ENTRY_RE = re.compile(r"^\{k=\"(\w+)\",f=\"([^\"]+)\",(?:name=\"([^\"]+)\",)?(?:kit=\"([^\"]+)\",)?"
                      r"x=(-?[\d.]+),y=(-?[\d.]+),z=(-?[\d.]+),yaw=(-?[\d.]+),s=\{(-?[\d.]+),(-?[\d.]+),(-?[\d.]+)\}")


def audit_emitted(raw_spec):
    """Parse the chunk files back and check what will actually be built."""
    errors, notes = [], []
    tops = []
    n = 0
    lanes = []
    kinds = {}
    for fn in sorted(os.listdir(OUT)):
        if not fn.endswith(".lua") or "terrain" in fn or "setup" in fn:
            continue
        for line in open(os.path.join(OUT, fn), encoding="utf-8"):
            mm = ENTRY_RE.match(line.strip())
            if not mm:
                continue
            n += 1
            k, folder, name, kit = mm.group(1), mm.group(2), mm.group(3), mm.group(4)
            x, y, z, yaw = (float(mm.group(i)) for i in (5, 6, 7, 8))
            sx, sy, sz = (float(mm.group(i)) for i in (9, 10, 11))
            kinds[k] = kinds.get(k, 0) + 1
            if k in ("mesh", "anchor", "board", "pedestal"):
                top, bottom = y + sy, y
            else:
                top, bottom = y + sy / 2, y - sy / 2
            invisible = k in ("spawn", "hubspawn", "barrier")
            if not invisible and abs(top) < 0.25:
                errors.append(f"{fn}: {name or kit} top face at y={top:.2f}")
            tops.append((top, name or kit))
            if name and name.startswith("Strip_"):
                lanes.append((x, z, sx, sz, top))
            # strips must be clear: nothing but a gate may stand on a landing strip in plan
    W = json.load(open(os.path.join(ROOT, "design", "game.json"), encoding="utf-8"))
    W = W.get("config", W)["World"]
    strip_tops = sorted({round(t[4], 3) for t in lanes})
    if strip_tops != [0.3]:
        errors.append(f"strip tops {strip_tops}, expected [0.3]")
    # the central strip of every lane must be clear: no wall or wall cap may touch it either
    for p in raw_spec["parts"]:
        if "wall" in p["roles"]:
            for (lx, lz, lw, ll, _) in lanes:
                if abs(p["pos"][0] - lx) < lw / 2 + p["size"][0] / 2 and abs(p["pos"][2] - lz) < ll / 2 + p["size"][2] / 2:
                    errors.append(f"{p['id']} (wall) overlaps landing strip at x={lx}")
                    break
    # props on strips (plan overlap, rotated footprint)
    for p in raw_spec["parts"]:
        if not p.get("mesh") or p["mesh"] == "Lane_ZoneGate":
            continue
        if p["pos"][1] - p["size"][1] / 2 > 30:      # clouds and floating islands are sky, not on the strip
            continue
        r = math.radians(p.get("yaw", 0))
        hx = (abs(math.cos(r)) * p["size"][0] + abs(math.sin(r)) * p["size"][2]) / 2
        hz = (abs(math.sin(r)) * p["size"][0] + abs(math.cos(r)) * p["size"][2]) / 2
        for (lx, lz, lw, ll, _) in lanes:
            if abs(p["pos"][0] - lx) < lw / 2 + hx and abs(p["pos"][2] - lz) < ll / 2 + hz:
                errors.append(f"{p['id']} ({p['mesh']}) overlaps landing strip at x={lx}")
                break
    # pedestals inside the fence, tops at PedestalTop
    for p in raw_spec["parts"]:
        if p["id"].split("_")[-1].startswith("Pedestal") and p.get("mesh") == "Plot_Pedestal":
            i = int(p["id"].split("_")[0][1:])
            x0 = (i - (raw_spec["layout"]["plots"] + 1) / 2) * W["PlotPitch"]
            top = p["pos"][1] + p["size"][1] / 2
            if abs(top - (W["GroundY"] + W["PedestalTop"])) > 1e-6:
                errors.append(f"{p['id']} top {top} != PedestalTop")
            inner = W["PlotWidth"] / 2 - 0.8
            if abs(p["pos"][0] - x0) + p["size"][0] / 2 > inner or not (
                    W["PlotBackZ"] + 0.8 < p["pos"][2] - p["size"][2] / 2 and p["pos"][2] + p["size"][2] / 2 < W["PlotFrontZ"]):
                errors.append(f"{p['id']} not inside its fence")
    # terrain surface near y=0 over flat ground (the grid shows on broad flat surfaces at 0)
    t = terrainmod.load_output(TERR)
    h = t["height"]
    gz, gx = np.gradient(h, 4.0)
    sl = np.degrees(np.arctan(np.hypot(gx, gz)))
    surf = h + 2.0
    flat0 = int(((np.abs(surf) < 0.5) & (sl < 4)).sum())
    if flat0 > 20:
        errors.append(f"{flat0} flat terrain columns with an estimated surface within 0.5 of y=0")
    notes.append(f"flat terrain columns with estimated surface |y|<0.5: {flat0}")
    notes.append(f"lowest emitted visible top {min(tops)[0]:.2f}; tops within 0.25 of 0: "
                 f"{sum(1 for tt, _ in tops if abs(tt) < 0.25)} (invisible spawns/barriers excluded)")
    return {"placements": n, "by_kind": kinds, "errors": errors, "notes": notes}


if __name__ == "__main__":
    main()
