-- build_aura_preview.luau - Studio EDIT mode, run ONLY through `python tools/aura_assign.py build`
-- (it prepends _G.PREVIEW, from design/aura_assignments.json, and the convert() of build_auras.luau).
--
-- A PREVIEW of the owner's aura naming pass, not wired into the game:
--   phase "convert": every pack aura the plan uses is converted to our R15 rig (same convert() as the
--     game's auras) into ServerStorage.AuraPreview.Templates.P<index>. ReplicatedStorage is untouched.
--   phase "build": Workspace.AuraAssignPreview (DevOnly; the server deletes it on start): every hero
--     with an aura on a stand, rarest first, a sign each (character, in-game name, rarity, aura).
--     Rare heroes wear the shared Rare aura recoloured to their colour.
local spec = _G.PREVIEW
assert(spec, "_G.PREVIEW missing: run tools/aura_assign.py build")
local SSv = game:GetService("ServerStorage")
local RSv = game:GetService("ReplicatedStorage")

local store = SSv:FindFirstChild("AuraPreview")
if not store then
	store = Instance.new("Folder")
	store.Name = "AuraPreview"
	store.Parent = SSv
end
local templates = store:FindFirstChild("Templates")
if not templates then
	templates = Instance.new("Folder")
	templates.Name = "Templates"
	templates.Parent = store
end

-- the pack units in the order build_aura_pack_browser.luau laid them out (index = stand number)
local function packUnits()
	local source = SSv.ImportedVfx.AuraPacksAll.Folder["Aura packs all"]
	local units = {}
	local function collect(x)
		for _, c in x:GetChildren() do
			if c:IsA("Model") then
				if c:FindFirstChildOfClass("Humanoid") then
					table.insert(units, c)
				else
					collect(c)
				end
			elseif c:IsA("Folder") then
				collect(c)
			end
		end
	end
	local packs = source:GetChildren()
	table.sort(packs, function(a, b)
		return a.Name < b.Name
	end)
	for _, p in packs do
		collect(p)
	end
	return units
end

if spec.phase == "convert" then
	local units = packUnits()
	local report = {}
	for _, a in spec.auras do
		if a.kind ~= "pack" then
			continue
		end
		local unit = units[a.index]
		if not unit or unit.Name ~= a.unit then
			table.insert(report, `P{a.index} MISMATCH: expected {a.unit}, found {unit and unit.Name or "nothing"}`)
			continue
		end
		local rig = rigsOf(unit)[1]
		if not rig then
			table.insert(report, `P{a.index} NO RIG in {a.unit}`)
			continue
		end
		_G.AURA_FIT = { size = a.size, reach = a.reach }
		local ok, folder, line = pcall(convert, rig, "P" .. a.index, a.cap, a.unit)
		_G.AURA_FIT = nil
		if ok then
			local old = templates:FindFirstChild(folder.Name)
			if old then
				old:Destroy()
			end
			folder:SetAttribute("Tier", a.tier)
			folder:SetAttribute("Pack", a.pack)
			folder.Parent = templates
			table.insert(report, line)
		else
			table.insert(report, `P{a.index} FAIL: {folder}`)
		end
	end
	return table.concat(report, "\n")
end

-- ===================================================================== build
local auraByRef = {}
for _, a in spec.auras do
	auraByRef[a.ref] = a
end
local function templateOf(a)
	if a.kind == "key" then
		return RSv.Assets.Auras:FindFirstChild(a.key)
	end
	return templates:FindFirstChild("P" .. a.index)
end

-- a hero's colour design (aura_assign.py PALETTES): per emitter name a gradient and a Brightness, and the light colour
local function paint(root: Instance, pal)
	if not pal then
		return
	end
	for _, d in root:GetDescendants() do
		local tex = if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then string.match(d.Texture, "%d+") else nil
		local key = if pal.colours[d.Name] then d.Name elseif tex and pal.colours["tex:" .. tex] then "tex:" .. tex else nil
		local rows = key and pal.colours[key]
		-- keepDark: the aura's black outline layers keep their colour (a black and a blue emitter can share a name)
		if rows and pal.keepDark and (d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail")) then
			local dark = true
			for _, kp in d.Color.Keypoints do
				if math.max(kp.Value.R, kp.Value.G, kp.Value.B) > 0.15 then
					dark = false
				end
			end
			if dark then
				rows = nil
			end
		end
		if (d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail")) and rows then
			local k = {}
			for _, r in rows do
				table.insert(k, ColorSequenceKeypoint.new(r[1], Color3.fromHex(r[2])))
			end
			d.Color = ColorSequence.new(k)
			if pal.brightness[key] then
				d.Brightness = pal.brightness[key]
			end
			if pal.rate and pal.rate[key] and d:IsA("ParticleEmitter") then
				d.Rate *= pal.rate[key]
			end
			if pal.speed and pal.speed[key] and d:IsA("ParticleEmitter") then
				local m = pal.speed[key]
				d.Speed = NumberRange.new(d.Speed.Min * m, d.Speed.Max * m)
				d.Acceleration *= m
			end
			if pal.scale and pal.scale[key] and d:IsA("ParticleEmitter") then
				local k = {}
				for _, kp in d.Size.Keypoints do
					table.insert(k, NumberSequenceKeypoint.new(kp.Time, kp.Value * pal.scale[key], kp.Envelope * pal.scale[key]))
				end
				d.Size = NumberSequence.new(k)
			end
		elseif d:IsA("Light") and pal.light then
			d.Color = Color3.fromHex(pal.light)
		end
	end
end

-- HeroAura.attach (src/client/Fx/HeroAura.luau) for a given template, on a still model at rest
local function attach(model: Model, template: Instance)
	local root = model:FindFirstChild("HumanoidRootPart")
	local pose = {}
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			pose[p.Name] = root.CFrame:ToObjectSpace(p.CFrame)
		end
	end
	local clone = template:Clone()
	for _, group in clone:GetChildren() do
		if group.Name == "Beams" then
			for _, b in group:GetChildren() do
				b.Parent = root
			end
			continue
		end
		local target = model:FindFirstChild(group.Name)
		if not target or not target:IsA("BasePart") then
			target = root
		end
		local targetRest = pose[target.Name] or CFrame.new()
		for _, piece in group:GetChildren() do
			if piece:IsA("Attachment") then
				piece.CFrame = targetRest:ToObjectSpace(piece.CFrame)
				piece.Parent = target
			elseif piece.Name == "Direct" then
				for _, e in piece:GetChildren() do
					e.Parent = target
				end
			elseif piece:IsA("BasePart") then
				local rootCf = piece:GetAttribute("RootCF")
				local rel = targetRest:ToObjectSpace(if typeof(rootCf) == "CFrame" then rootCf else CFrame.new())
				piece.Anchored = true
				piece.CanCollide = false
				piece.CFrame = target.CFrame * rel
				piece.Parent = model
			end
		end
	end
	clone:Destroy()
end

local function part(name, size, cf, color, parent, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function sign(adornee, lines, color, height, wide, tall)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Adornee = adornee
	gui.Size = UDim2.fromScale(wide or 11, tall or 3)
	gui.StudsOffsetWorldSpace = adornee.CFrame:VectorToObjectSpace(Vector3.new(0, height, 0))
	gui.LightInfluence = 0
	gui.MaxDistance = 160
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.fromRGB(24, 20, 48)
	t.BackgroundTransparency = 0.15
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Text = table.concat(lines, "\n")
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color
	stroke.Thickness = 3
	stroke.Parent = t
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = t
	t.Parent = gui
	gui.Parent = adornee
end

-- spec.only = { heroId = true, ... }: rebuild ONLY those stands in the existing preview, leave every other stand (and
-- anything other sessions hand-dressed on it) untouched. Without it the whole preview is rebuilt.
local ONLY = spec.only
local old = workspace:FindFirstChild("AuraAssignPreview")
local rootModel, stands
if ONLY and old and old:FindFirstChild("Heroes") then
	rootModel = old
	stands = old.Heroes
	for _, s in stands:GetChildren() do
		if ONLY[s:GetAttribute("Hero")] then
			s:Destroy()
		end
	end
else
	ONLY = nil
	if old then
		old:Destroy()
	end
	rootModel = Instance.new("Model")
	rootModel.Name = "AuraAssignPreview"
	rootModel:SetAttribute("DevOnly", true)
	stands = Instance.new("Folder")
	stands.Name = "Heroes"
	stands.Parent = rootModel
end

local ORIGIN = Vector3.new(-1040, 320, -40) -- west of the aura showcase (x -896..-744)
local COLS, PITCH, GAP = 10, 14, 10
local chars = RSv.Assets.Characters

-- rows: each rarity starts a new row, with a header in the gap before it
local placed = {}
local z = 0
local headers = {}
for _, rarity in spec.order do
	local list = {}
	for _, h in spec.heroes do
		if h.rarity == rarity then
			table.insert(list, h)
		end
	end
	if #list == 0 then
		continue
	end
	table.insert(headers, { rarity = rarity, z = z, count = #list })
	z += GAP
	for i, h in list do
		local c = (i - 1) % COLS
		if i > 1 and c == 0 then
			z += PITCH
		end
		table.insert(placed, { h = h, at = ORIGIN + Vector3.new(((COLS - 1) / 2 - c) * PITCH, 0, z) })
	end
	z += PITCH
end
local depth = z + 30
local width = COLS * PITCH + 40
if not ONLY then
	part("Floor", Vector3.new(width, 2, depth), CFrame.new(ORIGIN + Vector3.new(0, -1, depth / 2 - 20)),
		Color3.fromRGB(44, 40, 70), rootModel)
	local readme = part("Readme", Vector3.new(2, 2, 2), CFrame.new(ORIGIN + Vector3.new(0, 5, -16)),
		Color3.fromRGB(255, 214, 64), rootModel)
	readme.Transparency = 1
	sign(readme, {
		"AURA ASSIGNMENT PREVIEW (Studio only, not in the game yet)",
		`{#placed} heroes with an aura, rarest first. Common and Uncommon wear none.`,
		"Each sign: character (in-game name) / rarity - aura.",
	}, Color3.fromRGB(255, 214, 64), 0, 16, 3.4)
	for _, hd in headers do
		local a = part("Header_" .. hd.rarity, Vector3.new(1, 1, 1), CFrame.new(ORIGIN + Vector3.new(0, 4, hd.z - 2)),
			Color3.new(1, 1, 1), rootModel)
		a.Transparency = 1
		local col = Color3.fromHex(spec.colours[hd.rarity] or "FFFFFF")
		sign(a, { `{string.upper(hd.rarity)}  ({hd.count})` }, col, 0, 14, 2)
	end

end

local made, failed = 0, {}
for _, p in placed do
	local h, at = p.h, p.at
	if ONLY and not ONLY[h.id] then
		continue
	end
	local a = auraByRef[h.aura]
	local col = Color3.fromHex(spec.colours[h.rarity] or "FFFFFF")
	local m = Instance.new("Model")
	m.Name = h.character
	m:SetAttribute("Hero", h.id)
	m:SetAttribute("Rarity", h.rarity)
	m:SetAttribute("Aura", a.label)
	m:SetAttribute("AuraRef", a.ref)
	if h.colour then
		m:SetAttribute("Colour", h.colour)
	end
	local base = part("Stand", Vector3.new(1, 7, 7), CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90)), col, m,
		Enum.PartType.Cylinder)
	m.PrimaryPart = base
	local tpl = chars:FindFirstChild("Char_" .. h.id)
	if tpl then
		local d = tpl:Clone()
		d.Name = h.id
		d:PivotTo(CFrame.new(at + Vector3.new(0, 0.5, 0)))
		for _, x in d:GetDescendants() do
			if x:IsA("BasePart") then
				x.Anchored = true
			elseif x:IsA("Humanoid") then
				x.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			end
		end
		d.Parent = m
		-- noBase: the assigned pack aura is NOT worn, only the hero's own fx/floor (Frieren: the pack read as irrelevant)
		local t = if h.noBase then nil else templateOf(a)
		if h.colour and t then
			-- RARE (owner, 2026-11-25): the owner's Rare aura itself (JackpotGreen, the "All Rare Characters"
			-- stand) on every Rare hero, recoloured. Its one particle texture has the green baked in, so it
			-- is swapped for a WHITE copy of the same shape (spec.rareTexture) and Color gives the hero's
			-- colour exactly. Rate spec.rareRate: the game's conversion had thinned it to 5.4/s (the pack's is 59/s).
			local use = t:Clone()
			for _, e in use:GetDescendants() do
				if e:IsA("ParticleEmitter") then
					e.Texture = spec.rareTexture
					e.Color = ColorSequence.new(Color3.fromHex(h.colour))
					e.Rate = spec.rareRate
					-- the pack's Brightness 10 blew mid-tone colours (indigo, purple) out to white on the white texture
					e.Brightness = spec.rareBrightness
				end
			end
			local ok, err = pcall(attach, d, use)
			use:Destroy()
			if not ok then
				table.insert(failed, `{h.character}: {err}`)
			end
		elseif t then
			local use = if h.palette then t:Clone() else t
			paint(use, h.palette)
			local ok, err = pcall(attach, d, use)
			if use ~= t then
				use:Destroy()
			end
			if not ok then
				table.insert(failed, `{h.character}: {err}`)
			end
			-- extras: a second aura on top, cut down to the named effects (Gojo: Infinite Reality's infinity symbol only)
			for _, x in h.extras or {} do
				local xt = templateOf(auraByRef[x.aura])
				if not xt then
					table.insert(failed, `{h.character}: no template for extra {x.aura}`)
					continue
				end
				local keep = {}
				for _, n in x.keep do
					keep[n] = true
				end
				local cut = xt:Clone()
				for _, e in cut:GetDescendants() do
					if (e:IsA("ParticleEmitter") or e:IsA("Beam") or e:IsA("Trail") or e:IsA("Light")) and not keep[e.Name] then
						e:Destroy()
					end
				end
				-- drop whatever now holds no effect (carrier parts, empty attachments)
				for _, e in cut:GetDescendants() do
					if e.Parent and (e:IsA("BasePart") or e:IsA("Attachment")) and not e:FindFirstChildWhichIsA("ParticleEmitter", true) then
						e:Destroy()
					end
				end
				paint(cut, h.palette)
				local ok2, err2 = pcall(attach, d, cut)
				cut:Destroy()
				if not ok2 then
					table.insert(failed, `{h.character}: extra {err2}`)
				end
			end
		elseif h.noBase then
			-- nothing from the pack
		elseif a.kind == "key" and HAND:FindFirstChild(a.source) then
			-- no body rig to convert (build_aura_showcase.luau does the same): the raw effect, scripts,
			-- sounds, guis and joints stripped, centred on the chest
			local raw = HAND:FindFirstChild(a.source):Clone()
			for _, x in raw:GetDescendants() do
				if x:IsA("LuaSourceContainer") or x:IsA("Sound") or x:IsA("LayerCollector") or x:IsA("JointInstance") then
					x:Destroy()
				end
			end
			local chest = d:FindFirstChild("UpperTorso")
			if raw:IsA("BasePart") then
				raw.Anchored = true
				raw.CanCollide = false
				raw.Transparency = 1
				raw.CFrame = chest.CFrame
			else
				for _, x in raw:GetDescendants() do
					if x:IsA("BasePart") then
						x.Anchored = true
						x.CanCollide = false
					end
				end
				local cf = raw:GetBoundingBox()
				raw:PivotTo(raw:GetPivot() + (chest.Position - cf.Position))
				if a.anchor == "ground" then
					-- a ground aura (a magic circle): its LOWEST effect attachment goes dead centre under the hero, at the soles.
					-- (Its bounding box is an invisible 8x10x8 part 0.7 off its own circles: by the box it sat off-centre and floated.)
					local low
					for _, x in raw:GetDescendants() do
						if x:IsA("Attachment") and x:FindFirstChildWhichIsA("ParticleEmitter") and (not low or x.WorldPosition.Y < low.WorldPosition.Y) then
							low = x
						end
					end
					local root = d:FindFirstChild("HumanoidRootPart")
					local foot = d:FindFirstChild("LeftFoot")
					if low and root and foot then
						local want = Vector3.new(root.Position.X, foot.Position.Y - foot.Size.Y / 2 + 0.15, root.Position.Z)
						raw:PivotTo(raw:GetPivot() + (want - low.WorldPosition))
					end
				end
			end
			paint(raw, h.palette)
			raw.Name = "RawAura"
			raw.Parent = m
		else
			table.insert(failed, `{h.character}: no template for {a.ref}`)
		end
		-- ground: named effects dropped to the soles (Akaza's quake rings and light-column plane hovered mid-shin / overhead)
		local foot = d:FindFirstChild("LeftFoot")
		local root = d:FindFirstChild("HumanoidRootPart")
		local soles = if foot then foot.Position.Y - foot.Size.Y / 2 else at.Y + 0.5
		if h.ground and root then
			local want = {}
			for _, n in h.ground do
				want[n] = true
			end
			for _, x in d:GetDescendants() do
				if want[x.Name] and x:IsA("Attachment") then
					local w = x.WorldPosition
					x.WorldPosition = Vector3.new(w.X, soles + 0.12, w.Z)
				elseif want[x.Name] and x:IsA("BasePart") and x.Transparency >= 1 then
					x.CFrame = x.CFrame.Rotation + Vector3.new(x.Position.X, soles + 0.12, x.Position.Z)
				end
			end
		end
		-- beams: span every beam from soles+bottom to soles+top (Minato's ran 17 studs, from under the floor)
		if h.beams and root then
			for _, b in d:GetDescendants() do
				if b:IsA("Beam") and b.Attachment0 and b.Attachment1 then
					local a0, a1 = b.Attachment0, b.Attachment1
					local lo, hi = a0, a1
					if a0.WorldPosition.Y > a1.WorldPosition.Y then
						lo, hi = a1, a0
					end
					lo.WorldPosition = Vector3.new(lo.WorldPosition.X, soles + h.beams.bottom, lo.WorldPosition.Z)
					hi.WorldPosition = Vector3.new(hi.WorldPosition.X, soles + h.beams.top, hi.WorldPosition.Z)
					if h.beams.width then
						b.Width0 = h.beams.width
						b.Width1 = h.beams.width
					end
				end
			end
		end
		-- floor: a glowing sigil under the hero (Akaza's compass needle): a crisp line layer over a soft bloom on an
		-- unlit SurfaceGui (Brightness above 1 blooms), plus a slow breathing pulse of the bloom as a flat particle
		if h.floor and root then
			local fl = h.floor
			local p = Instance.new("Part")
			p.Name = "AuraFloor"
			p.Size = Vector3.new(fl.size, 0.05, fl.size)
			p.Transparency = 1
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.CFrame = CFrame.new(root.Position.X, soles + 0.06, root.Position.Z)
			local g = Instance.new("SurfaceGui")
			g.Face = Enum.NormalId.Top
			g.LightInfluence = if fl.lit then 1 else 0 -- lit: shaded by the scene (wet blood), not self-lit
			g.Brightness = fl.brightness
			g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			g.PixelsPerStud = 100
			g.Adornee = p
			for i, layer in { { fl.glow, fl.glowColour, fl.glowTransparency or 0 }, { fl.core, fl.coreColour, 0 } } do
				local img = Instance.new("ImageLabel")
				img.Name = if i == 1 then "Glow" else "Core"
				img.Size = UDim2.fromScale(1, 1)
				img.BackgroundTransparency = 1
				img.Image = layer[1]
				img.ImageColor3 = Color3.fromHex(layer[2])
				img.ImageTransparency = layer[3]
				img.ZIndex = i
				img.Parent = g
			end
			g.Parent = p
			if fl.pulse ~= false then
			local att = Instance.new("Attachment")
			att.Name = "FloorPulse"
			att.Position = Vector3.new(0, 0.05, 0)
			att.Parent = p
			local e = Instance.new("ParticleEmitter")
			e.Name = "FloorPulse"
			e.Texture = fl.glow
			e.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
			e.EmissionDirection = Enum.NormalId.Top
			e.Speed = NumberRange.new(0.01)
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, fl.size * 0.92), NumberSequenceKeypoint.new(1, fl.size * 1.04) })
			e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.35, 0.55), NumberSequenceKeypoint.new(1, 1) })
			e.Color = ColorSequence.new(Color3.fromHex(fl.glowColour))
			e.LightEmission = 1
			e.LightInfluence = 0
			e.Brightness = 2
			e.Lifetime = NumberRange.new(1.6)
			e.Rate = 1.2
			e.LockedToPart = true
			e.Parent = att
			end
			p.Parent = d
		end
		-- fx: custom emitter layers designed for one hero (Kokushibo's moon-breathing crescents): each an invisible
		-- part round the hero whose SHAPE emits (a cylinder shell, a disc at the feet), every particle setting from the spec
		for _, fx in (if root then h.fx else nil) or {} do
			local p = Instance.new("Part")
			p.Name = "AuraFx_" .. fx.name
			local sz = fx.part or { 0.2, 0.2, 0.2 } -- (bodyParts layers have no shell of their own)
			p.Size = Vector3.new(sz[1], sz[2], sz[3])
			p.Transparency = 1
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			-- a Cylinder part's axis is X: stand it up
			local up = if fx.shape == "Cylinder" then CFrame.Angles(0, 0, math.rad(90)) else CFrame.new()
			-- offset {right, front} in the hero's own frame (a Rasengan in the right hand)
			local off = fx.offset or { 0, 0 }
			local at = root.CFrame * CFrame.new(off[1], 0, -off[2])
			p.CFrame = CFrame.new(at.X, soles + (fx.y or 0), at.Z) * up
			if fx.tilt then
				-- tilt {pitch, roll, yaw} in degrees in the hero's own frame: a VelocityPerpendicular ring then lies in a
				-- tilted plane round the body (Mahoraga's gyroscope rings)
				local yaw = root.CFrame - root.CFrame.Position
				p.CFrame = CFrame.new(at.X, soles + (fx.y or 0), at.Z)
					* yaw
					* CFrame.Angles(0, math.rad(fx.tilt[3] or 0), 0)
					* CFrame.Angles(math.rad(fx.tilt[1]), 0, math.rad(fx.tilt[2]))
					* up
			end
			local e = Instance.new("ParticleEmitter")
			e.Name = fx.name
			e.Texture = fx.texture
			e.Shape = Enum.ParticleEmitterShape[fx.shape or "Box"]
			e.ShapeStyle = Enum.ParticleEmitterShapeStyle[fx.style or "Volume"]
			e.ShapeInOut = Enum.ParticleEmitterShapeInOut[fx.inout or "Outward"]
			e.EmissionDirection = Enum.NormalId[fx.dir or "Top"]
			e.Orientation = Enum.ParticleOrientation[fx.orient or "FacingCamera"]
			local function ns(rows)
				local k = {}
				for _, r in rows do
					table.insert(k, NumberSequenceKeypoint.new(r[1], r[2], r[3] or 0))
				end
				return NumberSequence.new(k)
			end
			local ck = {}
			for _, r in fx.colour do
				table.insert(ck, ColorSequenceKeypoint.new(r[1], Color3.fromHex(r[2])))
			end
			e.Color = ColorSequence.new(ck)
			e.Size = ns(fx.size)
			if fx.flipbook then
				-- a sheet of frames; Random: each particle shows one frame (Sae's flow numbers)
				e.FlipbookLayout = Enum.ParticleFlipbookLayout[fx.flipbook]
				e.FlipbookMode = Enum.ParticleFlipbookMode[fx.flipbookMode or "Random"]
			end
			if fx.squash then
				e.Squash = ns(fx.squash) -- e.g. a butterfly's wings flapping
			end
			e.Transparency = ns(fx.transparency)
			e.Lifetime = NumberRange.new(fx.life[1], fx.life[2])
			e.Rate = fx.rate
			e.Speed = NumberRange.new(fx.speed[1], fx.speed[2])
			e.Rotation = NumberRange.new(fx.rotation and fx.rotation[1] or 0, fx.rotation and fx.rotation[2] or 360)
			e.RotSpeed = NumberRange.new(fx.rotSpeed and fx.rotSpeed[1] or 0, fx.rotSpeed and fx.rotSpeed[2] or 0)
			e.SpreadAngle = Vector2.new(fx.spread and fx.spread[1] or 0, fx.spread and fx.spread[2] or 0)
			e.Acceleration = Vector3.new(table.unpack(fx.accel or { 0, 0, 0 }))
			e.Drag = fx.drag or 0
			e.LightEmission = fx.lightEmission or 1
			e.LightInfluence = 0
			e.Brightness = fx.brightness or 1
			e.ZOffset = fx.zOffset or 0
			e.LockedToPart = fx.locked or false
			e.Parent = p
			if fx.light then
				local l = Instance.new("PointLight")
				l.Color = Color3.fromHex(fx.light)
				l.Range = fx.lightRange or 10
				l.Brightness = fx.lightBrightness or 1.5
				l.Parent = p
			end
			if fx.bodyParts then
				-- emit from her body parts' own volumes: the aura follows the silhouette (Power's blood flames)
				for _, name in fx.bodyParts do
					local bp = d:FindFirstChild(name)
					if bp and bp:IsA("BasePart") then
						local c = e:Clone()
						c.Parent = bp
					end
				end
				for _, l in p:GetChildren() do
					if l:IsA("Light") and d:FindFirstChild("UpperTorso") then
						l.Parent = d.UpperTorso
					end
				end
				p:Destroy()
			else
				p.Parent = d
			end
		end
	else
		table.insert(failed, `{h.character}: no Char_{h.id}`)
	end
	local auraName = if a.kind == "pack" and #a.label <= 5 then `{a.unit} ({a.pack})` else a.label
	if h.colour then
		auraName = "Rare aura #" .. h.colour
	end
	if h.noBase then
		auraName = "own magic (custom)"
	end
	for _, x in h.extras or {} do
		auraName ..= " + " .. x.label
	end
	sign(base, { `{h.character} ({h.name})`, `{h.rarity} - {auraName}` }, col, 8.5)
	m.Parent = stands
	made += 1
end
if not ONLY then
	rootModel.Parent = workspace
end
return string.format("preview: %d heroes, floor %d x %d, %d failed%s", made, width, depth, #failed,
	#failed > 0 and ("\n" .. table.concat(failed, "\n")) or "")
