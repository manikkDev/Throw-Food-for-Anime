-- export_preview_auras.luau (Studio EDIT mode, rerunnable): the owner's approved preview auras, as GAME templates.
--
--   python tools/aura_to_game.py        (runs this with the hero list, then updates design/auras.json)
--
-- The owner judged every Rare-and-up hero's aura on the preview yard (Workspace.AuraAssignPreview, built by
-- tools/aura_assign.py + tools/studio/build_aura_preview.luau: a pack aura, a per-hero palette, extra layers,
-- staged emitters, a floor sigil). This script CAPTURES each stand exactly as it stands and writes it as that
-- hero's own runtime template, ReplicatedStorage.Assets.Auras.H_<heroId>, in the format src/client/Fx/HeroAura
-- wears (see its header): nothing is re-derived, so the game shows what was approved.
--
-- HOW: a stand's hero is the baked character (ReplicatedStorage.Assets.Characters.Char_<id>) at rest, plus the
-- aura. Whatever the stand has that the character template has not IS the aura:
--   an Attachment in a body part        -> <Part>/Attachment, CFrame in ROOT space, attribute RS
--   an emitter / light in a body part   -> <Part>/Direct/<it>
--   a Beam or Trail                     -> Beams/<it> (its attachments are captured too: the clone keeps the links)
--   a BasePart (staged emitter shells, the floor sigil, an aura mesh) -> <Part or HumanoidRootPart>/<part>,
--                                          attribute RootCF (its CFrame in root space); HeroAura welds it on
-- The hero list comes in _G.EXPORT_AURAS = { only = { [heroId] = true }? , skip = { [heroId] = true },
-- cap = { [heroId] = live particles } }: an aura over its cap has its emitter rates scaled down to it (the
-- Rare aura runs about 500 live particles on the yard; a base holds many Rares and the runtime budget is
-- shared, so the game wears it thinner).
-- Heroes with a hand-built aura (aura_assign.py CUSTOM) are skipped: their templates are built by their own
-- scripts. Returns one line per hero: "<heroId> H_<heroId> <live particles> <pieces>".
local RS = game:GetService("ReplicatedStorage")

local args = _G.EXPORT_AURAS or {}
_G.EXPORT_AURAS = nil
local yard = workspace:FindFirstChild("AuraAssignPreview")
local heroes = yard and yard:FindFirstChild("Heroes")
if not heroes then
	return "FAIL no Workspace.AuraAssignPreview.Heroes: build the preview first (python tools/aura_assign.py build)"
end
local chars = RS.Assets.Characters
local dest = RS.Assets:FindFirstChild("Auras")
if not dest then
	dest = Instance.new("Folder")
	dest.Name = "Auras"
	dest.Parent = RS.Assets
end

local function pathOf(inst: Instance, top: Instance): string
	local parts = {}
	local cur: Instance? = inst
	while cur and cur ~= top do
		table.insert(parts, 1, cur.Name .. ":" .. cur.ClassName)
		cur = cur.Parent
	end
	return table.concat(parts, "/")
end

local function isEffect(d: Instance): boolean
	return d:IsA("ParticleEmitter")
		or d:IsA("Light")
		or d:IsA("Fire")
		or d:IsA("Smoke")
		or d:IsA("Sparkles")
		or d:IsA("Highlight")
end

local function export(model: Model, id: string): string
	local char = chars:FindFirstChild("Char_" .. id)
	if not char then
		return id .. " FAIL no Char_" .. id
	end
	-- what the baked character already has: everything else on the stand is the aura
	local known: { [string]: number } = {}
	for _, d in char:GetDescendants() do
		local key = pathOf(d, char)
		known[key] = (known[key] or 0) + 1
	end
	local clone = model:Clone()
	local root = clone:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		clone:Destroy()
		return id .. " FAIL no HumanoidRootPart"
	end
	local seen: { [string]: number } = {}
	local added: { Instance } = {}
	local function walk(parent: Instance)
		for _, d in parent:GetChildren() do
			local key = pathOf(d, clone)
			seen[key] = (seen[key] or 0) + 1
			if seen[key] > (known[key] or 0) then
				table.insert(added, d) -- new here: the whole subtree is the aura's
			else
				walk(d)
			end
		end
	end
	walk(clone)

	local out = Instance.new("Folder")
	out.Name = "H_" .. id
	local beams = Instance.new("Folder")
	beams.Name = "Beams"
	beams.Parent = out
	local function group(name: string): Folder
		local f = out:FindFirstChild(name)
		if not f then
			f = Instance.new("Folder")
			f.Name = name
			f.Parent = out
		end
		return f :: Folder
	end
	local function direct(name: string): Folder
		local g = group(name)
		local f = g:FindFirstChild("Direct")
		if not f then
			f = Instance.new("Folder")
			f.Name = "Direct"
			f.Parent = g
		end
		return f :: Folder
	end
	-- the body part an added piece belongs to (the model itself = the root)
	local function partName(d: Instance): string
		local p = d.Parent
		return if p and p ~= clone and p:IsA("BasePart") then p.Name else "HumanoidRootPart"
	end

	local pieces = 0
	local rootCf = root.CFrame
	for _, d in added do
		if d:IsA("Attachment") then
			local owner = partName(d)
			local world = d.WorldCFrame
			d.Parent = group(owner)
			d.CFrame = rootCf:ToObjectSpace(world)
			d:SetAttribute("RS", true)
			pieces += 1
		elseif d:IsA("Beam") or d:IsA("Trail") then
			d.Parent = beams
			pieces += 1
		elseif d:IsA("BasePart") then
			local owner = partName(d)
			d:SetAttribute("RootCF", rootCf:ToObjectSpace(d.CFrame))
			-- the stand held it in place; in the game HeroAura welds it to the hero
			for _, w in d:GetDescendants() do
				if w:IsA("JointInstance") or w:IsA("WeldConstraint") then
					w:Destroy()
				end
			end
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			d.Parent = group(owner)
			pieces += 1
		elseif isEffect(d) then
			d.Parent = direct(partName(d))
			pieces += 1
		end
		-- anything else new on a stand (a script, a value) is not part of an aura: left behind
	end
	-- A RAW aura (aura_assign.py: a pack with no body rig, shown beside the hero: Julius's flow on the ground,
	-- Ulquiorra's blaze) is the stand's own child, not the hero's. Every part of it becomes a piece that
	-- HeroAura welds to the root, so it follows the hero as it stood on the yard.
	local raw = model.Parent and model.Parent:FindFirstChild("RawAura")
	if raw then
		local rc = raw:Clone()
		local parts: { BasePart } = {}
		if rc:IsA("BasePart") then
			table.insert(parts, rc)
		end
		for _, d in rc:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(parts, d)
			end
		end
		for _, d in parts do
			d:SetAttribute("RootCF", rootCf:ToObjectSpace(d.CFrame))
		end
		for _, d in parts do
			for _, w in d:GetChildren() do
				if w:IsA("JointInstance") or w:IsA("WeldConstraint") then
					w:Destroy()
				end
			end
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			d.Parent = group("HumanoidRootPart")
			pieces += 1
		end
		for _, d in rc:GetDescendants() do
			if d:IsA("Beam") or d:IsA("Trail") then
				d.Parent = beams
			end
		end
		if not rc:IsA("BasePart") then
			rc:Destroy()
		end
	end
	-- beams keep working only if their attachments came along
	for _, b in beams:GetChildren() do
		if
			b:IsA("Beam")
			and not (
				b.Attachment0
				and b.Attachment0:IsDescendantOf(out)
				and b.Attachment1
				and b.Attachment1:IsDescendantOf(out)
			)
		then
			b:Destroy()
		end
	end
	local live = 0
	for _, e in out:GetDescendants() do
		if e:IsA("ParticleEmitter") then
			-- a stand another session paused for a solo look is exported running
			if e:GetAttribute("SoloOff") then
				e:SetAttribute("SoloOff", nil)
				e.Enabled = true
			end
			if e.Enabled then
				live += e.Rate * e.Lifetime.Max
			end
		elseif e:IsA("BillboardGui") or e:IsA("SurfaceGui") then
			e:SetAttribute("SoloHide", nil)
			e.Enabled = true
		end
	end
	for _, f in out:GetChildren() do
		if f:IsA("Folder") and #f:GetChildren() == 0 then
			f:Destroy()
		end
	end
	clone:Destroy()
	if pieces == 0 then
		out:Destroy()
		return id .. " NONE (the stand wears nothing)"
	end
	local cap = args.cap and args.cap[id]
	if typeof(cap) == "number" and live > cap then
		local f = cap / live
		live = 0
		for _, e in out:GetDescendants() do
			if e:IsA("ParticleEmitter") and e.Enabled then
				e.Rate = math.max(e.Rate * f, 0.5)
				live += e.Rate * e.Lifetime.Max
			end
		end
	end
	out:SetAttribute("Live", math.floor(live + 0.5))
	out:SetAttribute("Source", "preview stand " .. (model.Parent and model.Parent.Name or "?"))
	out:SetAttribute("K", 1)
	local old = dest:FindFirstChild(out.Name)
	if old then
		old:Destroy()
	end
	out.Parent = dest
	return string.format("%s %s %d %d", id, out.Name, math.floor(live + 0.5), pieces)
end

local report = {}
for _, stand in heroes:GetChildren() do
	local model: Model? = nil
	for _, d in stand:GetDescendants() do
		if d:IsA("Model") and typeof(d:GetAttribute("HeroId")) == "string" then
			model = d
			break
		end
	end
	if model then
		local id = model:GetAttribute("HeroId") :: string
		if (args.only == nil or args.only[id]) and not (args.skip and args.skip[id]) then
			local ok, line = pcall(export, model, id)
			table.insert(report, if ok then line else id .. " FAIL " .. tostring(line))
		end
	end
end
table.sort(report)
return table.concat(report, "\n")
