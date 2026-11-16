--!strict
-- ImportedFx - one-shot effects built from the owner's imported packs by
-- tools/studio/build_fx_imports.luau: ReplicatedStorage.Assets.FxImported.<Name>
-- (RebirthClock, VoidFlare, LandingImpact). Each is one invisible Part with disabled emitters:
--   Mode "burst": every emitter fires its Burst count once.
--   Mode "loop":  emitters and beams run for Duration seconds (or until stopped).
-- Client-only, fails inert (a missing template plays nothing), cleans itself up.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ImportedFx = {}

export type Handle = { stop: () -> () }

local INERT: Handle = { stop = function() end }
local FADE_OUT = 0.7 -- seconds a stopped loop's beams take to fade away

local function scaleNS(ns: NumberSequence, k: number): NumberSequence
	local kps = {}
	for _, p in ns.Keypoints do
		table.insert(kps, NumberSequenceKeypoint.new(p.Time, p.Value * k, p.Envelope * k))
	end
	return NumberSequence.new(kps)
end

--- Play `name` at `at`. `scale` multiplies the authored size, `mult` the burst counts,
--- `duration` overrides a loop's length. Returns a handle (stop ends a loop early).
function ImportedFx.play(
	name: string,
	at: CFrame,
	opts: { scale: number?, mult: number?, duration: number?, tint: Color3? }?
): Handle
	local o = opts or {}
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("FxImported")
	local template = folder and folder:FindFirstChild(name)
	if not template or not template:IsA("BasePart") then
		return INERT
	end
	local part = template:Clone()
	local k = o.scale or 1
	local mult = o.mult or 1
	part.CFrame = at
	if k ~= 1 then
		for _, d in part:GetDescendants() do
			if d:IsA("ParticleEmitter") then
				d.Size = scaleNS(d.Size, k)
				d.Speed = NumberRange.new(d.Speed.Min * k, d.Speed.Max * k)
				d.Acceleration *= k
			elseif d:IsA("Beam") then
				d.Width0 *= k
				d.Width1 *= k
			elseif d:IsA("Attachment") then
				d.Position *= k
			end
		end
	end
	if o.tint then
		for _, d in part:GetDescendants() do
			if d:IsA("ParticleEmitter") or d:IsA("Beam") then
				d.Color = ColorSequence.new(o.tint)
			end
		end
	end
	part.Parent = workspace
	local life = (part:GetAttribute("Life") or 2) :: number
	if part:GetAttribute("Mode") == "loop" then
		local duration = o.duration or (part:GetAttribute("Duration") or 3) :: number
		local stopped = false
		local function stop()
			if stopped then
				return
			end
			stopped = true
			-- emitters stop making particles (the live ones finish); beams FADE out over FADE_OUT
			-- seconds (owner's review 4: the rebirth clock vanished abruptly)
			local beams: { { beam: Beam, from: NumberSequence } } = {}
			for _, d in part:GetDescendants() do
				if d:IsA("ParticleEmitter") then
					d.Enabled = false
				elseif d:IsA("Beam") then
					table.insert(beams, { beam = d, from = d.Transparency })
				end
			end
			if #beams > 0 then
				task.spawn(function()
					local t0 = os.clock()
					while part.Parent and os.clock() - t0 < FADE_OUT do
						local u = (os.clock() - t0) / FADE_OUT
						for _, entry in beams do
							local keys = {}
							for _, key in entry.from.Keypoints do
								table.insert(
									keys,
									NumberSequenceKeypoint.new(
										key.Time,
										key.Value + (1 - key.Value) * u
									)
								)
							end
							entry.beam.Transparency = NumberSequence.new(keys)
						end
						RunService.Heartbeat:Wait()
					end
					for _, entry in beams do
						entry.beam.Enabled = false
					end
				end)
			end
			Debris:AddItem(part, math.max(life, FADE_OUT) + 0.5)
		end
		for _, d in part:GetDescendants() do
			if d:IsA("ParticleEmitter") then
				d.Enabled = true
				d:Emit(1)
			elseif d:IsA("Beam") then
				d.Enabled = true
			end
		end
		task.delay(duration, stop)
		return { stop = stop }
	end
	for _, d in part:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			local n = (d:GetAttribute("Burst") or 1) :: number
			d:Emit(math.max(1, math.floor(n * mult + 0.5)))
		end
	end
	Debris:AddItem(part, life + 0.5)
	return INERT
end

return ImportedFx
