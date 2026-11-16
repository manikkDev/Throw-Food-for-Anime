--!nocheck
-- build_fx_imports.luau - run in Studio EDIT mode. Turns three pieces of the owner's imported VFX
-- packs (archived in ServerStorage.ImportedVfx, never deleted) into clean one-shot templates:
-- ReplicatedStorage.Assets.FxImported.<Name> (played by src/client/Fx/ImportedFx.luau).
--
--   RebirthClock  <- HandPicked."Clock Aura"            the giant clock face, on rebirth (loop, 4 s)
--   VoidFlare     <- ParticlePacks."vfx pack".Explosion  the purple star flare, on an Epic+ reveal
--   LandingImpact <- ParticlePacks."vfx pack".f          rocks, crack, flash: where the food lands
--
-- Each template is ONE anchored, invisible Part (attrs Mode = "burst" | "loop", Duration, Life)
-- whose emitters are disabled; a burst emitter carries attr Burst (how many to Emit). Everything
-- that is not an effect (scripts, sounds, guis, welds) is stripped; sizes are scaled to the game.

local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local SRC = SS.ImportedVfx

local EFFECT = { ParticleEmitter = true, Beam = true, Trail = true, Attachment = true, PointLight = true }

local function scaleNS(ns, k)
	local kps = {}
	for _, p in ns.Keypoints do
		table.insert(kps, NumberSequenceKeypoint.new(p.Time, p.Value * k, p.Envelope * k))
	end
	return NumberSequence.new(kps)
end

local function make(name, source, mode, k, duration)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	local holder = source:Clone()
	-- a source Part: its own emitters sit on the part -> move them onto a centre attachment
	local centre = Instance.new("Attachment")
	centre.Name = "Centre"
	centre.Parent = part
	for _, d in holder:GetDescendants() do
		if not EFFECT[d.ClassName] and not d:IsA("BasePart") then
			d:Destroy()
		end
	end
	local life = 0
	for _, d in holder:GetChildren() do
		if d:IsA("Attachment") then
			d.Position *= k
			d.Parent = part
		elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
			d.Parent = centre
		end
	end
	holder:Destroy()
	for _, d in part:GetDescendants() do
		if d:IsA("Attachment") and d ~= centre and d.Parent ~= part then
			d.Position *= k
		elseif d:IsA("ParticleEmitter") then
			d.Size = scaleNS(d.Size, k)
			d.Speed = NumberRange.new(d.Speed.Min * k, d.Speed.Max * k)
			d.Acceleration *= k
			life = math.max(life, d.Lifetime.Max)
			if mode == "burst" then
				d:SetAttribute("Burst", math.clamp(math.floor(d.Rate * math.min(d.Lifetime.Max, 1) * 0.5 + 0.5), 1, 30))
			end
			d.Enabled = false
		elseif d:IsA("Beam") then
			d.Width0 *= k
			d.Width1 *= k
			d.Enabled = false
		end
	end
	part:SetAttribute("Mode", mode)
	part:SetAttribute("Duration", duration)
	part:SetAttribute("Life", life)
	return part
end

local assets = RS.Assets
local dest = assets:FindFirstChild("FxImported") or Instance.new("Folder")
dest.Name = "FxImported"
dest.Parent = assets

local report = {}
local jobs = {
	{ "RebirthClock", SRC.HandPicked:FindFirstChild("Clock Aura"), "loop", 0.42, 4.5 },
	{ "VoidFlare", SRC.ParticlePacks["vfx pack"]:FindFirstChild("Explosion"), "burst", 0.8, 0 },
	{ "LandingImpact", SRC.ParticlePacks["vfx pack"]:FindFirstChild("f"), "burst", 0.45, 0 },
}
for _, j in jobs do
	local name, source, mode, k, duration = table.unpack(j)
	if not source then
		table.insert(report, name .. ": SOURCE MISSING")
		continue
	end
	local old = dest:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local part = make(name, source, mode, k, duration)
	part.Parent = dest
	local em, bm = 0, 0
	for _, d in part:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			em += 1
		elseif d:IsA("Beam") then
			bm += 1
		end
	end
	table.insert(report, string.format("%s <- %s: %d emitters, %d beams, life %.1f s", name, source:GetFullName(), em, bm, part:GetAttribute("Life")))
end
return table.concat(report, "\n")
