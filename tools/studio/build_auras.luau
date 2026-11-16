--!nocheck
-- build_auras.luau - run in Studio EDIT mode (execute_luau / studio_mcp.py luau --file).
--
-- Turns the owner's imported aura dummies (ServerStorage.ImportedVfx.HandPicked, archived,
-- never deleted) into HERO aura templates: ReplicatedStorage.Assets.Auras.<Key>.
--
-- Spec: `_G.AURA_SPEC = { { key = "SSJ2", source = "Goku - SSJ2 Aura", rig = 1, cap = 120 }, ... }`
-- (written by tools/gen_auras.py from design/auras.json). With no spec it converts EVERY rig it
-- finds, uncapped, under the key "Review_<n>" (the review pass).
--
-- WHY A CONVERSION AND NOT THE DUMMY: the dummies are R6 (one of them a 2.4x giant) and our heroes
-- are R15; their effects hang off R6 limbs, carrier parts welded to the dummy and beams between
-- attachments on different parts, and many carry scripts (spinners, emit loops, an emote player,
-- a song visualiser). So every effect is re-expressed in the dummy's ROOT space, scaled to our rig
-- (k = 2 / R6 torso height, 1.6 / R15 torso height), assigned to the R15 part that matches the
-- limb it rode on, stripped of everything that is not an effect, and capped to a particle budget.
--
-- Template layout (read by src/client/Fx/HeroAura.luau):
--   Folder <Key>  attrs: Live (estimated live particles), Source, K
--     Folder <R15 part name>
--       Attachment ...   attr RS=true: its CFrame is ROOT space (convert on apply)
--       Folder Direct    emitters that emit from the part's own volume: parent to the part
--       BasePart ...     carrier parts: attr RootCF (root space), Spin (rad/s, optional)
--     Folder Beams       beams/trails parented to a part, not an attachment (refs intact)

local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local HAND = SS.ImportedVfx.HandPicked

local R6MAP = {
	Head = "Head",
	Torso = "UpperTorso",
	HumanoidRootPart = "HumanoidRootPart",
	["Left Arm"] = "LeftLowerArm",
	["Right Arm"] = "RightLowerArm",
	["Left Leg"] = "LeftLowerLeg",
	["Right Leg"] = "RightLowerLeg",
}
local R15 = {}
for _, n in { "Head", "UpperTorso", "LowerTorso", "HumanoidRootPart", "LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg",
	"RightLowerLeg", "RightFoot" } do
	R15[n] = n
end
R15.RootPart = "HumanoidRootPart"

local EFFECT = {
	ParticleEmitter = true, Beam = true, Trail = true, PointLight = true, SpotLight = true, SurfaceLight = true,
	Fire = true, Smoke = true, Sparkles = true,
}
local KEEP = {
	Attachment = true, SpecialMesh = true, Decal = true, Texture = true, SurfaceAppearance = true,
}
for k in EFFECT do
	KEEP[k] = true
end

local function bodyName(name)
	return R6MAP[name] or R15[name]
end

local function scaleNS(ns, k)
	local kps = {}
	for _, p in ns.Keypoints do
		table.insert(kps, NumberSequenceKeypoint.new(p.Time, p.Value * k, p.Envelope * k))
	end
	return NumberSequence.new(kps)
end

local function scaleEffect(e, k)
	if e:IsA("ParticleEmitter") then
		e.Size = scaleNS(e.Size, k)
		e.Speed = NumberRange.new(e.Speed.Min * k, e.Speed.Max * k)
		e.Acceleration *= k
		e.ZOffset *= k
	elseif e:IsA("Beam") then
		e.Width0 *= k
		e.Width1 *= k
		e.CurveSize0 *= k
		e.CurveSize1 *= k
	elseif e:IsA("Light") then
		e.Range *= k
	end
end

-- strip a clone down to effects (and visual bits of a carrier), never scripts/sounds/guis/joints
local function strip(inst, keepParts)
	for _, d in inst:GetDescendants() do
		if d.Parent == nil then
			continue
		end
		local cls = d.ClassName
		if d:IsA("BasePart") then
			if not keepParts then
				d:Destroy()
			end
		elseif not KEEP[cls] and not EFFECT[cls] then
			d:Destroy()
		end
	end
	-- drop emitters nothing will ever drive (scripted bursts / toggles are gone)
	for _, d in inst:GetDescendants() do
		if d:IsA("ParticleEmitter") and (not d.Enabled or d.Rate <= 0) then
			d:Destroy()
		elseif (d:IsA("Beam") or d:IsA("Trail")) and not d.Enabled then
			d:Destroy()
		end
	end
end

local function hasEffect(inst)
	if EFFECT[inst.ClassName] then
		return true
	end
	for _, d in inst:GetDescendants() do
		if EFFECT[d.ClassName] then
			return true
		end
	end
	return false
end

-- the angular step of a "spin" script under a part (rad per wait() -> rad/s at ~30 Hz)
local function spinOf(part)
	for _, s in part:GetChildren() do
		if s:IsA("Script") then
			local ok, src = pcall(function()
				return s.Source
			end)
			if ok then
				local a, b, c = src:match("fromEulerAnglesXYZ%(%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)")
				if a then
					return Vector3.new(tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0) * 30
				end
			end
		end
	end
	return nil
end

-- every rig (a model with a torso) inside a source item
local function rigsOf(src)
	local rigs = {}
	local seen = {}
	local function consider(m)
		if m and not seen[m] and (m:FindFirstChild("Torso") or m:FindFirstChild("UpperTorso")) then
			seen[m] = true
			table.insert(rigs, m)
		end
	end
	if src:IsA("Model") then
		consider(src)
	end
	for _, d in src:GetDescendants() do
		if d:IsA("Model") then
			consider(d)
		end
	end
	return rigs
end

local function weldTarget(part, rig)
	for _, j in rig:GetDescendants() do
		if j:IsA("JointInstance") or j:IsA("WeldConstraint") then
			local a, b = j.Part0, j.Part1
			if a == part and b and bodyName(b.Name) and b:IsDescendantOf(rig) then
				return bodyName(b.Name)
			elseif b == part and a and bodyName(a.Name) and a:IsDescendantOf(rig) then
				return bodyName(a.Name)
			end
		end
	end
	return "HumanoidRootPart"
end

local function convert(rig, key, cap, sourceName)
	local torso = rig:FindFirstChild("Torso") or rig:FindFirstChild("UpperTorso")
	local r6 = torso.Name == "Torso"
	local k = if r6 then 2 / torso.Size.Y else 1.6 / torso.Size.Y
	-- root frame: the R6 torso IS the root; an R15 root sits under the upper torso
	local frame
	local hrp = rig:FindFirstChild("HumanoidRootPart")
	if r6 then
		frame = torso.CFrame
	elseif hrp and (hrp.Position - torso.Position).Magnitude < 4 then
		frame = hrp.CFrame
	else
		frame = torso.CFrame * CFrame.new(0, -torso.Size.Y * 0.35, 0)
	end
	local function rootSpace(cf)
		local rel = frame:ToObjectSpace(cf)
		return rel.Rotation + rel.Position * k
	end

	local out = Instance.new("Folder")
	out.Name = key
	local beamsFolder = Instance.new("Folder")
	beamsFolder.Name = "Beams"
	beamsFolder.Parent = out
	local function folderFor(part)
		local f = out:FindFirstChild(part)
		if not f then
			f = Instance.new("Folder")
			f.Name = part
			f.Parent = out
		end
		return f
	end

	-- attachments referenced by beams/trails must come along even if they hold no effect
	local referenced = {}
	for _, d in rig:GetDescendants() do
		if d:IsA("Beam") or d:IsA("Trail") then
			if d.Attachment0 then
				referenced[d.Attachment0] = true
			end
			if d.Attachment1 then
				referenced[d.Attachment1] = true
			end
		end
	end

	local map = {} -- original attachment -> clone
	local clones = {} -- every cloned root we made (for ref remap)
	local carriers, emitters, beams = 0, 0, 0

	for _, part in rig:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end
		if part:FindFirstAncestorWhichIsA("Accessory") and not hasEffect(part) then
			continue
		end
		local body = bodyName(part.Name)
		if body then
			local f = folderFor(body)
			for _, ch in part:GetChildren() do
				if ch:IsA("Attachment") and (hasEffect(ch) or referenced[ch]) then
					local c = ch:Clone()
					strip(c, false)
					c.CFrame = rootSpace(ch.WorldCFrame)
					c:SetAttribute("RS", true)
					for _, e in c:GetDescendants() do
						scaleEffect(e, k)
					end
					for _, sub in c:GetDescendants() do
						if sub:IsA("Attachment") then
							sub.Position *= k
						end
					end
					c.Parent = f
					map[ch] = c
					-- nested attachments too
					local o, n = ch:GetDescendants(), c:GetDescendants()
					for i, od in o do
						if od:IsA("Attachment") then
							for _, nd in n do
								if nd:IsA("Attachment") and nd.Name == od.Name and not map[od] then
									map[od] = nd
									break
								end
							end
						end
					end
					table.insert(clones, c)
				elseif EFFECT[ch.ClassName] then
					local c = ch:Clone()
					scaleEffect(c, k)
					if c:IsA("Beam") or c:IsA("Trail") then
						c.Parent = beamsFolder
					else
						local direct = f:FindFirstChild("Direct") or Instance.new("Folder")
						direct.Name = "Direct"
						direct.Parent = f
						c.Parent = direct
					end
					strip(c, false)
					if c.Parent then
						table.insert(clones, c)
					end
				end
			end
		elseif hasEffect(part) or (part.Transparency < 1 and part:FindFirstAncestorWhichIsA("Accessory") == nil and math.max(part.Size.X, part.Size.Y, part.Size.Z) < 14) then
			-- a carrier: an effect part or a visible aura piece welded to the dummy
			if part.Transparency >= 1 and not hasEffect(part) then
				continue
			end
			local target = weldTarget(part, rig)
			local c = part:Clone()
			for _, ch in c:GetChildren() do
				if ch:IsA("BasePart") then
					ch:Destroy()
				end
			end
			strip(c, true)
			c.Anchored = false
			c.CanCollide = false
			c.CanQuery = false
			c.CanTouch = false
			c.Massless = true
			c.CastShadow = false
			c.Size *= k
			local mesh = c:FindFirstChildOfClass("SpecialMesh")
			if mesh then
				mesh.Scale *= k
				mesh.Offset *= k
			end
			for _, e in c:GetDescendants() do
				scaleEffect(e, k)
				if e:IsA("Attachment") then
					e.Position *= k
				end
			end
			c:SetAttribute("RootCF", rootSpace(part.CFrame))
			local spin = spinOf(part)
			if spin then
				c:SetAttribute("Spin", spin)
			end
			c.Parent = folderFor(target)
			carriers += 1
			-- attachments inside the carrier keep their refs through the map
			local o = part:GetDescendants()
			local n = c:GetDescendants()
			for _, od in o do
				if od:IsA("Attachment") then
					for _, nd in n do
						if nd:IsA("Attachment") and nd.Name == od.Name and not map[od] then
							map[od] = nd
							break
						end
					end
				end
			end
			table.insert(clones, c)
		end
	end

	-- remap beam/trail attachment references to the clones
	local broken = 0
	for _, d in out:GetDescendants() do
		if d:IsA("Beam") or d:IsA("Trail") then
			beams += 1
			local a0 = d.Attachment0 and (map[d.Attachment0] or (d.Attachment0:IsDescendantOf(out) and d.Attachment0))
			local a1 = d.Attachment1 and (map[d.Attachment1] or (d.Attachment1:IsDescendantOf(out) and d.Attachment1))
			if a0 and a1 then
				d.Attachment0 = a0
				d.Attachment1 = a1
			else
				broken += 1
				d:Destroy()
			end
		end
	end

	-- footprint: a pedestal is 8 studs from the next one, so no particle may grow past maxSize
	-- studs and no attachment/carrier may sit further than maxReach from the root (sigils that
	-- hovered 12 studs up, blood pools 20 studs wide). Sizes shrink by ratio, offsets are pulled in.
	local maxSize = (_G.AURA_FIT and _G.AURA_FIT.size) or 6
	local maxReach = (_G.AURA_FIT and _G.AURA_FIT.reach) or 6
	local shrunk = 0
	-- sideways: within maxReach of the root (neighbours are 8 studs away); up: may float above the
	-- head (a sigil, a halo) up to maxReach + 5; down: never below the soles
	local function fit(p)
		local h = Vector2.new(p.X, p.Z)
		local x, z = p.X, p.Z
		if h.Magnitude > maxReach then
			local u = h.Unit * maxReach
			x, z = u.X, u.Y
		end
		local y = math.clamp(p.Y, -3.2, maxReach + 5)
		if x == p.X and z == p.Z and y == p.Y then
			return p
		end
		return Vector3.new(x, y, z)
	end
	for _, d in out:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			local big = 0
			for _, kp in d.Size.Keypoints do
				big = math.max(big, kp.Value + kp.Envelope)
			end
			if big > maxSize then
				local f = maxSize / big
				d.Size = scaleNS(d.Size, f)
				d.Speed = NumberRange.new(d.Speed.Min * f, d.Speed.Max * f)
				d.Acceleration *= f
				shrunk += 1
			end
		elseif d:IsA("Beam") then
			d.Width0 = math.min(d.Width0, maxSize)
			d.Width1 = math.min(d.Width1, maxSize)
		elseif d:IsA("Attachment") and d:GetAttribute("RS") then
			local p, q = d.CFrame.Position, fit(d.CFrame.Position)
			if q ~= p then
				d.CFrame = d.CFrame.Rotation + q
				shrunk += 1
			end
		elseif d:IsA("BasePart") then
			local cf = d:GetAttribute("RootCF")
			if typeof(cf) == "CFrame" and fit(cf.Position) ~= cf.Position then
				d:SetAttribute("RootCF", cf.Rotation + fit(cf.Position))
				shrunk += 1
			end
			local m = math.max(d.Size.X, d.Size.Y, d.Size.Z)
			if m > maxSize * 1.5 then
				local f = maxSize * 1.5 / m
				d.Size *= f
				local mesh = d:FindFirstChildOfClass("SpecialMesh")
				if mesh then
					mesh.Scale *= f
				end
				for _, a in d:GetDescendants() do
					if a:IsA("Attachment") then
						a.Position *= f
					end
				end
				shrunk += 1
			end
		end
	end
	out:SetAttribute("Shrunk", shrunk)

	-- particle budget
	local live = 0
	for _, d in out:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			emitters += 1
			live += d.Rate * d.Lifetime.Max
		end
	end
	local before = live
	if cap and live > cap then
		local f = cap / live
		live = 0
		for _, d in out:GetDescendants() do
			if d:IsA("ParticleEmitter") then
				d.Rate = math.max(d.Rate * f, 0.5)
				live += d.Rate * d.Lifetime.Max
			end
		end
	end
	-- empty part folders go
	for _, f in out:GetChildren() do
		if f:IsA("Folder") and #f:GetChildren() == 0 then
			f:Destroy()
		end
	end
	out:SetAttribute("Live", math.floor(live + 0.5))
	out:SetAttribute("Source", sourceName)
	out:SetAttribute("K", k)
	return out,
		string.format(
			"%s <- %s (%s k=%.2f) emitters=%d beams=%d carriers=%d broken=%d live %d -> %d",
			key,
			sourceName,
			if r6 then "R6" else "R15",
			k,
			emitters,
			beams,
			carriers,
			broken,
			before,
			live
		)
end

local assets = RS.Assets
local dest = assets:FindFirstChild("Auras")
if not dest then
	dest = Instance.new("Folder")
	dest.Name = "Auras"
	dest.Parent = assets
end

local report = {}
local spec = _G.AURA_SPEC
if spec == nil then
	local n = 0
	for _, item in HAND:GetChildren() do
		for ri, rig in rigsOf(item) do
			n += 1
			local key = string.format("Review_%02d", n)
			local ok, folder, line = pcall(convert, rig, key, nil, item.Name .. "#" .. ri)
			if ok then
				local old = dest:FindFirstChild(key)
				if old then
					old:Destroy()
				end
				folder.Parent = dest
				table.insert(report, line)
			else
				table.insert(report, key .. " FAIL " .. item.Name .. ": " .. tostring(folder))
			end
		end
	end
else
	for _, row in spec do
		local item = HAND:FindFirstChild(row.source)
		if not item then
			table.insert(report, row.key .. " MISSING source " .. row.source)
			continue
		end
		local rig = rigsOf(item)[row.rig or 1]
		if not rig then
			table.insert(report, row.key .. " NO RIG in " .. row.source)
			continue
		end
		_G.AURA_FIT = { size = row.size, reach = row.reach }
		local ok, folder, line = pcall(convert, rig, row.key, row.cap, row.source .. "#" .. (row.rig or 1))
		_G.AURA_FIT = nil
		if ok then
			local old = dest:FindFirstChild(row.key)
			if old then
				old:Destroy()
			end
			folder:SetAttribute("Tier", row.tier)
			folder.Parent = dest
			table.insert(report, line)
		else
			table.insert(report, row.key .. " FAIL: " .. tostring(folder))
		end
	end
end
return table.concat(report, "\n")
