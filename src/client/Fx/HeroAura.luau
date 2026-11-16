--!strict
-- HeroAura - a character aura (ReplicatedStorage.Assets.Auras.<Key>, built from the owner's
-- hand-picked aura dummies by tools/studio/build_auras.luau) fitted onto one hero model.
--
-- The template stores every piece in the dummy's ROOT space, already scaled to our R15 rig:
--   <Part>/Attachment (attr RS)   -> parented to that body part, CFrame converted
--   <Part>/Direct/<emitter>       -> parented to the body part itself (emits from its volume)
--   <Part>/<BasePart> (RootCF)    -> welded to the body part (Spin: rad/s, turned while live)
--   Beams/<beam or trail>         -> parented to the root (their attachment refs survive the clone)
-- Offsets are taken from the hero TEMPLATE's rest pose, never from the live (animating) pose, so an
-- aura put on mid-emote still sits right. Everything is client-side and pcall-isolated by Fx/Vfx.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HeroAura = {}

export type Handle = { stop: () -> (), live: number }

local restCache: { [string]: { [string]: CFrame } } = {}

local function folder(): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	return assets and assets:FindFirstChild("Auras")
end

--- The estimated live particles of an aura key (0 when the template is missing).
function HeroAura.cost(key: string): number
	local f = folder()
	local t = f and f:FindFirstChild(key)
	return if t then (t:GetAttribute("Live") or 0) :: number else 0
end

-- part name -> CFrame relative to the root, from the hero template at rest
local function restPose(model: Model): { [string]: CFrame }
	local id = model:GetAttribute("HeroId")
	local key = if typeof(id) == "string" then id else model.Name
	local cached = restCache[key]
	if cached then
		return cached
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local chars = assets and assets:FindFirstChild("Characters")
	local template = chars and chars:FindFirstChild(model.Name)
	local source: Instance = if template and template:IsA("Model") then template else model
	local root = source:FindFirstChild("HumanoidRootPart")
	local pose: { [string]: CFrame } = {}
	if root and root:IsA("BasePart") then
		for _, p in source:GetChildren() do
			if p:IsA("BasePart") then
				pose[p.Name] = root.CFrame:ToObjectSpace(p.CFrame)
			end
		end
	end
	restCache[key] = pose
	return pose
end

local function scaleNS(ns: NumberSequence, k: number): NumberSequence
	local kps = {}
	for _, p in ns.Keypoints do
		table.insert(kps, NumberSequenceKeypoint.new(p.Time, p.Value * k, p.Envelope * k))
	end
	return NumberSequence.new(kps)
end

local function scaleEffects(root: Instance, k: number, rate: number)
	local list = root:GetDescendants()
	table.insert(list, root)
	for _, e in list do
		if e:IsA("ParticleEmitter") then
			if k ~= 1 then
				e.Size = scaleNS(e.Size, k)
				e.Speed = NumberRange.new(e.Speed.Min * k, e.Speed.Max * k)
				e.Acceleration *= k
				e.ZOffset *= k
			end
			if rate ~= 1 then
				e.Rate = math.max(e.Rate * rate, 0.5)
			end
		elseif e:IsA("Beam") and k ~= 1 then
			e.Width0 *= k
			e.Width1 *= k
			e.CurveSize0 *= k
			e.CurveSize1 *= k
		elseif e:IsA("Light") and k ~= 1 then
			e.Range *= k
		elseif e:IsA("Attachment") and k ~= 1 and e ~= root and not e:GetAttribute("RS") then
			-- (an RS attachment is in root space: placed, and scaled, by attach)
			e.Position *= k
		end
	end
end

local function scaled(cf: CFrame, k: number): CFrame
	return cf.Rotation + cf.Position * k
end

--- Put aura `key` on `model` (a hero, already scaled by `scale`). `rate` thins every emitter
--- (low detail). Returns nil when the template or the root is missing.
function HeroAura.attach(model: Model, key: string, scale: number?, rate: number?): Handle?
	local f = folder()
	local template = f and f:FindFirstChild(key)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not template or not root or not root:IsA("BasePart") then
		return nil
	end
	local k = scale or 1
	local r = rate or 1
	local pose = restPose(model)
	local made: { Instance } = {}
	local spinners: { { weld: Weld, base: CFrame, spin: Vector3 } } = {}
	local clone = template:Clone()
	scaleEffects(clone, k, r)
	for _, group in clone:GetChildren() do
		if group.Name == "Beams" then
			for _, b in group:GetChildren() do
				b.Parent = root
				table.insert(made, b)
			end
			continue
		end
		local target = model:FindFirstChild(group.Name)
		if not target or not target:IsA("BasePart") then
			target = root
		end
		local targetRest = scaled(pose[(target :: BasePart).Name] or CFrame.new(), k)
		for _, piece in group:GetChildren() do
			if piece:IsA("Attachment") then
				piece.CFrame = targetRest:ToObjectSpace(scaled(piece.CFrame, k))
				piece.Parent = target
				table.insert(made, piece)
			elseif piece.Name == "Direct" then
				for _, e in piece:GetChildren() do
					e.Parent = target
					table.insert(made, e)
				end
			elseif piece:IsA("BasePart") then
				local rootCf = piece:GetAttribute("RootCF")
				local rel = targetRest:ToObjectSpace(
					scaled(if typeof(rootCf) == "CFrame" then rootCf else CFrame.new(), k)
				)
				if k ~= 1 then
					piece.Size *= k
					local mesh = piece:FindFirstChildOfClass("SpecialMesh")
					if mesh then
						mesh.Scale *= k
						mesh.Offset *= k
					end
				end
				piece.Anchored = false
				piece.CFrame = (target :: BasePart).CFrame * rel
				local weld = Instance.new("Weld")
				weld.Part0 = target :: BasePart
				weld.Part1 = piece
				weld.C0 = rel
				weld.Parent = piece
				piece.Parent = model
				table.insert(made, piece)
				local spin = piece:GetAttribute("Spin")
				if typeof(spin) == "Vector3" and spin.Magnitude > 0 then
					table.insert(spinners, { weld = weld, base = rel, spin = spin })
				end
			end
		end
	end
	clone:Destroy()
	local conn: RBXScriptConnection? = nil
	if #spinners > 0 then
		local t = 0
		conn = RunService.Heartbeat:Connect(function(dt)
			t += dt
			for _, s in spinners do
				s.weld.C0 = s.base * CFrame.Angles(s.spin.X * t, s.spin.Y * t, s.spin.Z * t)
			end
		end)
	end
	local live = ((template:GetAttribute("Live") or 0) :: number) * r
	return {
		live = live,
		stop = function()
			if conn then
				conn:Disconnect()
				conn = nil
			end
			for _, inst in made do
				inst:Destroy()
			end
			table.clear(made)
		end,
	}
end

return HeroAura
