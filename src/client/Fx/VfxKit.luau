--!strict
-- VfxKit - the runtime for this game's authored effects (section 4).
--
-- Templates: ReplicatedStorage.Assets.Vfx.<Name>, built in EDIT mode by
-- work/vfx/build_templates.luau (generated from assets/vfx/effects/*.json by
-- assets/vfx/tools/pack_all.py). A template is a Folder of invisible carrier
-- Parts whose CFrames are RELATIVE to the effect origin, a "Timeline"
-- StringValue (JSON) and attributes Loop, Attach, Screen, Duration, NoTint,
-- MissingAssets. Every instance carries a "SimPath" the timeline addresses.
--
--   VfxKit.play(name, at, opts) -> Handle?
--     at   BasePart | Attachment | CFrame | Vector3
--     opts {scale, tint, duration, screen}
--          scale    1 = authored size (positions, sizes, speeds, widths, ranges)
--          tint     recolours layers marked Tint (keeps white cores); Reveal_* ignore it
--          duration loops stop themselves after this many seconds
--          screen   false = never shake the camera or draw the screen-edge flash
--   Handle {stop, destroy, setEnabled} (callable as h:stop() or h.stop())
--     loops (auras, trails, charge, sky) run until stop/destroy; one-shots
--     ignore stop and clean themselves up.
--   VfxKit.setLowDetail(on)  auras keep only their ground ring, particle counts halve
--   VfxKit.preload()         yields: fetches every template texture (call at join in a task)
--
-- Attach modes: "point" = placed once (upright, yaw kept); "part" = follows a
-- moving part, facing its direction of travel (food, hand); "root" = follows
-- the part's full CFrame (HumanoidRootPart). Followers are anchored and moved
-- every frame with BulkMoveTo, so nothing joins anyone's physics.
-- Camera shake and screen flashes only happen for effects whose template says
-- Screen, within 150 studs of the camera, on this client only.
-- Never throws: a missing template, a template with missing assets or any
-- runtime error returns nil and warns once per name.

local ContentProvider = game:GetService("ContentProvider")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

export type Opts = {
	scale: number?,
	tint: Color3?,
	duration: number?,
	screen: boolean?,
}

export type Handle = {
	stop: (...any) -> (),
	destroy: (...any) -> (),
	setEnabled: (...any) -> (),
}

local VfxKit = {}

local SCREEN_RANGE = 150
local SCALED_PROPS =
	{ Width0 = true, Width1 = true, Range = true, CurveSize0 = true, CurveSize1 = true }

local lowDetail = false
local warned: { [string]: boolean } = {}
local timelineCache: { [Instance]: { any } } = {}

local function warnOnce(name: string, message: string)
	if warned[name] then
		return
	end
	warned[name] = true
	warn(`[VfxKit] {name}: {message}`)
end

local function templates(): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	return assets and assets:FindFirstChild("Vfx")
end

local liveFolder: Folder? = nil
local function live(): Folder
	if liveFolder and liveFolder.Parent then
		return liveFolder
	end
	local f = Instance.new("Folder")
	f.Name = "VfxKitLive"
	f.Parent = workspace
	liveFolder = f
	return f
end

-- ------------------------------------------------------------------ values --

local function scaleNS(seq: NumberSequence, k: number): NumberSequence
	local keys = {}
	for _, key in seq.Keypoints do
		table.insert(keys, NumberSequenceKeypoint.new(key.Time, key.Value * k, key.Envelope * k))
	end
	return NumberSequence.new(keys)
end

local function tintColor(c: Color3, tint: Color3, grey: boolean): Color3
	local th, ts, tv = tint:ToHSV()
	local _, s, v = c:ToHSV()
	if grey then
		return Color3.fromHSV(th, ts, v * tv)
	end
	return Color3.fromHSV(th, ts * math.clamp(s / 0.6, 0, 1), v * (0.45 + 0.55 * tv))
end

local function tintSeq(seq: ColorSequence, tint: Color3): ColorSequence
	local grey = true
	for _, key in seq.Keypoints do
		local _, s = key.Value:ToHSV()
		if s > 0.15 then
			grey = false
		end
	end
	local keys = {}
	for _, key in seq.Keypoints do
		table.insert(keys, ColorSequenceKeypoint.new(key.Time, tintColor(key.Value, tint, grey)))
	end
	return ColorSequence.new(keys)
end

local function decode(v: any): any
	if type(v) ~= "table" then
		return v
	end
	if v.NR then
		return NumberRange.new(v.NR[1], v.NR[2])
	elseif v.NS then
		local keys = {}
		for _, k in v.NS do
			table.insert(keys, NumberSequenceKeypoint.new(k[1], k[2], math.min(k[3] or 0, k[2])))
		end
		return NumberSequence.new(keys)
	elseif v.CS then
		local keys = {}
		for _, k in v.CS do
			table.insert(keys, ColorSequenceKeypoint.new(k[1], Color3.new(k[2], k[3], k[4])))
		end
		return ColorSequence.new(keys)
	elseif v.C3 then
		return Color3.new(v.C3[1], v.C3[2], v.C3[3])
	elseif v.V3 then
		return Vector3.new(v.V3[1], v.V3[2], v.V3[3])
	elseif v.V2 then
		return Vector2.new(v.V2[1], v.V2[2])
	end
	return nil
end

local function easing(style: string?, dir: string?): (Enum.EasingStyle, Enum.EasingDirection)
	local okS, s = pcall(function()
		return (Enum.EasingStyle :: any)[style or "Linear"]
	end)
	local okD, d = pcall(function()
		return (Enum.EasingDirection :: any)[dir or "Out"]
	end)
	return if okS and s then s else Enum.EasingStyle.Linear,
		if okD and d then d else Enum.EasingDirection.Out
end

-- ---------------------------------------------------------- camera shake --

type Shake = { t0: number, amp: number, time: number, freq: number, seed: number }
local shakes: { Shake } = {}
local shakeOffset = CFrame.identity
local shakeBound = false

local function unbindShake()
	if shakeBound then
		shakeBound = false
		RunService:UnbindFromRenderStep("VfxKitShakeUndo")
		RunService:UnbindFromRenderStep("VfxKitShake")
	end
end

local function startShake(amp: number, time: number, freq: number)
	table.insert(
		shakes,
		{ t0 = os.clock(), amp = amp, time = time, freq = freq, seed = math.random() * 100 }
	)
	if shakeBound then
		return
	end
	shakeBound = true
	-- undo last frame's offset before the camera scripts run, apply after them: never drifts
	RunService:BindToRenderStep("VfxKitShakeUndo", Enum.RenderPriority.Camera.Value - 1, function()
		local cam = workspace.CurrentCamera
		if cam and shakeOffset ~= CFrame.identity then
			cam.CFrame = cam.CFrame * shakeOffset:Inverse()
		end
		shakeOffset = CFrame.identity
	end)
	RunService:BindToRenderStep("VfxKitShake", Enum.RenderPriority.Last.Value, function()
		local cam = workspace.CurrentCamera
		local now = os.clock()
		local x, y = 0, 0
		for i = #shakes, 1, -1 do
			local s = shakes[i]
			local age = now - s.t0
			if age >= s.time then
				table.remove(shakes, i)
			else
				local fall = 1 - age / s.time
				x += math.noise(s.seed, age * s.freq) * s.amp * fall
				y += math.noise(s.seed + 31, age * s.freq) * s.amp * fall
			end
		end
		if #shakes == 0 then
			unbindShake()
			return
		end
		if cam then
			shakeOffset = CFrame.new(x, y, 0)
			cam.CFrame = cam.CFrame * shakeOffset
		end
	end)
end

local function screenEdge(e: any)
	local player = Players.LocalPlayer
	local gui = player and player:FindFirstChildOfClass("PlayerGui")
	if not gui or type(e.image) ~= "string" or e.image == "" then
		return
	end
	local screen = Instance.new("ScreenGui")
	screen.Name = "VfxKitEdge"
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 50
	screen.ResetOnSpawn = false
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.Image = e.image
	local c = e.color or { 1, 1, 1 }
	image.ImageColor3 = Color3.new(c[1], c[2], c[3])
	image.ImageTransparency = 1
	image.Parent = screen
	screen.Parent = gui
	local fin, fout, total = e.fin or 0.05, e.fout or 0.25, e.time or 0.4
	local peak = e.transparency or 0.2
	TweenService:Create(image, TweenInfo.new(fin), { ImageTransparency = peak }):Play()
	task.delay(math.max(fin, total - fout), function()
		TweenService:Create(image, TweenInfo.new(fout), { ImageTransparency = 1 }):Play()
	end)
	task.delay(total + 0.1, function()
		screen:Destroy()
	end)
end

-- --------------------------------------------------------------- followers --

type Follower = {
	parts: { BasePart },
	rel: { CFrame },
	target: Instance,
	mode: string,
	frame: CFrame,
	last: Vector3?,
	dead: () -> boolean,
	onLost: () -> (),
}
local followers: { Follower } = {}
local followConn: RBXScriptConnection? = nil

local function targetCFrame(t: Instance): CFrame?
	if t:IsA("BasePart") then
		return t.CFrame
	elseif t:IsA("Attachment") then
		return t.WorldCFrame
	end
	return nil
end

local function stepFollowers()
	local parts: { BasePart } = {}
	local cfs: { CFrame } = {}
	for i = #followers, 1, -1 do
		local f = followers[i]
		local cf = if f.target.Parent then targetCFrame(f.target) else nil
		if f.dead() or not cf then
			table.remove(followers, i)
			if not f.dead() then
				f.onLost()
			end
		else
			local frame: CFrame
			if f.mode == "root" then
				frame = cf
			else
				local p = cf.Position
				local d = if f.last then p - f.last else Vector3.zero
				if d.Magnitude > 0.05 then
					frame = CFrame.lookAt(p, p + d)
				else
					frame = f.frame.Rotation + p
				end
				f.last = p
			end
			f.frame = frame
			for j, part in f.parts do
				table.insert(parts, part)
				table.insert(cfs, frame * f.rel[j])
			end
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
	if #followers == 0 and followConn then
		followConn:Disconnect()
		followConn = nil
	end
end

local function addFollower(f: Follower)
	table.insert(followers, f)
	if not followConn then
		followConn = RunService.PreRender:Connect(stepFollowers)
	end
end

-- ------------------------------------------------------------------- play --

local function upright(cf: CFrame): CFrame
	local look = cf.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		return CFrame.new(cf.Position)
	end
	return CFrame.lookAt(cf.Position, cf.Position + flat)
end

local function timelineOf(template: Instance): { any }
	local cached = timelineCache[template]
	if cached then
		return cached
	end
	local value = template:FindFirstChild("Timeline")
	local list = {}
	if value and value:IsA("StringValue") and value.Value ~= "" then
		list = HttpService:JSONDecode(value.Value)
	end
	timelineCache[template] = list
	return list
end

local function play(name: string, at: any, opts: Opts?): Handle?
	local o: Opts = opts or {}
	local folder = templates()
	local template = folder and folder:FindFirstChild(name)
	if not template then
		warnOnce(name, "no template at ReplicatedStorage.Assets.Vfx." .. name)
		return nil
	end
	if (template:GetAttribute("MissingAssets") or 0) > 0 then
		warnOnce(name, "template has textures without an asset id; rebuild it with the ids")
		return nil
	end
	local loop = template:GetAttribute("Loop") == true
	local attach = template:GetAttribute("Attach") or "point"
	local scale = o.scale or 1
	local tint = if template:GetAttribute("NoTint") then nil else o.tint

	-- the origin, and what (if anything) we follow
	local follow: Instance? = nil
	local origin: CFrame
	if typeof(at) == "CFrame" then
		origin = at
	elseif typeof(at) == "Vector3" then
		origin = CFrame.new(at)
	elseif typeof(at) == "Instance" and (at:IsA("BasePart") or at:IsA("Attachment")) then
		origin = targetCFrame(at) :: CFrame
		if attach ~= "point" then
			follow = at
		end
	else
		warnOnce(name, "play() needs a BasePart, Attachment, CFrame or Vector3")
		return nil
	end
	if attach ~= "root" then
		origin = upright(origin)
	end

	local clone = template:Clone()
	local timelineValue = clone:FindFirstChild("Timeline")
	if timelineValue then
		timelineValue:Destroy()
	end
	local byPath: { [string]: Instance } = {}
	local carriers: { BasePart } = {}
	local rel: { CFrame } = {}
	local toggles: { Instance } = {}
	local maxLife = 0.2
	local isAura = loop and attach == "root"
	for _, d in clone:GetDescendants() do
		local path = d:GetAttribute("SimPath")
		if type(path) == "string" then
			byPath[path] = d
		end
		local tinted = tint ~= nil and d:GetAttribute("Tint") == true
		local lowOff = lowDetail and isAura and d:GetAttribute("LowKeep") ~= true
		if d:IsA("BasePart") then
			local cf = d.CFrame
			local r = cf.Rotation + cf.Position * scale
			table.insert(carriers, d)
			table.insert(rel, r)
			if scale ~= 1 then
				d.Size *= scale
			end
		elseif d:IsA("Attachment") then
			if scale ~= 1 then
				d.Position *= scale
			end
		elseif d:IsA("ParticleEmitter") then
			if scale ~= 1 then
				d.Size = scaleNS(d.Size, scale)
				d.Speed = NumberRange.new(d.Speed.Min * scale, d.Speed.Max * scale)
				d.Acceleration *= scale
			end
			if tinted then
				d.Color = tintSeq(d.Color, tint :: Color3)
			end
			if lowDetail then
				d.Rate *= 0.5
			end
			maxLife = math.max(maxLife, d.Lifetime.Max)
		elseif d:IsA("Beam") then
			if scale ~= 1 then
				d.Width0 *= scale
				d.Width1 *= scale
				d.CurveSize0 *= scale
				d.CurveSize1 *= scale
			end
			if tinted then
				d.Color = tintSeq(d.Color, tint :: Color3)
			end
		elseif d:IsA("Trail") then
			if tinted then
				d.Color = tintSeq(d.Color, tint :: Color3)
			end
			maxLife = math.max(maxLife, d.Lifetime)
		elseif d:IsA("Light") then
			if scale ~= 1 then
				(d :: any).Range *= scale
			end
		end
		if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
			if lowOff then
				(d :: any).Enabled = false
			elseif (d :: any).Enabled then
				table.insert(toggles, d)
			end
		end
	end
	if #carriers > 0 then
		local cfs = table.create(#carriers)
		for i in carriers do
			cfs[i] = origin * rel[i]
		end
		for i, part in carriers do
			part.CFrame = cfs[i]
		end
	end

	local alive = true
	local stopping = false
	local tweens: { Tween } = {}
	local cam = workspace.CurrentCamera
	local screenOk = template:GetAttribute("Screen") == true
		and o.screen ~= false
		and cam ~= nil
		and (cam.CFrame.Position - origin.Position).Magnitude < SCREEN_RANGE

	local function destroy()
		if not alive then
			return
		end
		alive = false
		for _, t in tweens do
			t:Cancel()
		end
		clone:Destroy()
	end
	local function stop()
		if not alive or stopping or not loop then
			return
		end
		stopping = true
		for _, d in toggles do
			if d:IsA("Beam") then
				d.Enabled = false
			else
				(d :: any).Enabled = false
			end
		end
		task.delay(maxLife + 0.1, destroy)
	end
	local function setEnabled(a: any, b: any)
		local on = if type(a) == "boolean" then a else b == true
		if not alive or stopping then
			return
		end
		for _, d in toggles do
			(d :: any).Enabled = on
		end
	end

	clone.Parent = live()
	if follow then
		local f: Follower = {
			parts = carriers,
			rel = rel,
			target = follow,
			mode = attach,
			frame = origin,
			last = nil,
			dead = function()
				return not alive
			end,
			onLost = function()
				if loop then
					stop()
				end
			end,
		}
		addFollower(f)
	end

	-- the timeline
	local events = timelineOf(template)
	if #events > 0 then
		local function value(e: any, key: string, target: Instance): any
			local v = decode(e[key])
			if type(v) == "number" and SCALED_PROPS[e.prop] then
				v *= scale
			elseif
				typeof(v) == "ColorSequence"
				and tint
				and target:GetAttribute("Tint") == true
			then
				v = tintSeq(v, tint)
			end
			return v
		end
		local function run(e: any)
			local act = e["do"]
			local target = if e.target then byPath[e.target] else nil
			if act == "emit" and target then
				local n = e.count or 1
				if lowDetail then
					n = math.ceil(n * 0.5)
				end
				if target:IsA("ParticleEmitter") then
					target:Emit(n)
				else
					for _, d in target:GetDescendants() do
						if d:IsA("ParticleEmitter") then
							d:Emit(n)
						end
					end
				end
			elseif act == "set" and target then
				(target :: any)[e.prop] = value(e, "value", target)
			elseif act == "tween" and target then
				if e.from ~= nil then
					(target :: any)[e.prop] = value(e, "from", target)
				end
				local style, dir = easing(e.style, e.dir)
				local tw = TweenService:Create(
					target,
					TweenInfo.new(e.time or 0.2, style, dir, 0, e.reverses == true),
					{ [e.prop] = value(e, "to", target) }
				)
				table.insert(tweens, tw)
				tw:Play()
			elseif act == "enable" and target then
				(target :: any).Enabled = true
				if e.duration then
					task.delay(e.duration, function()
						if alive then
							(target :: any).Enabled = false
						end
					end)
				end
			elseif act == "disable" and target then
				(target :: any).Enabled = false
			elseif act == "shake" and screenOk then
				startShake((e.amp or 0.3) * math.min(scale, 1.5), e.time or 0.3, e.freq or 24)
			elseif act == "overlay" and screenOk then
				screenEdge(e)
			end
		end
		task.spawn(function()
			local t0 = os.clock()
			for _, e in events do
				local wait = (e.t or 0) - (os.clock() - t0)
				if wait > 0 then
					task.wait(wait)
				end
				if not alive then
					return
				end
				local ok, err = pcall(run, e)
				if not ok then
					warnOnce(name .. "/tl", tostring(err))
				end
			end
		end)
	end

	if loop then
		if o.duration then
			task.delay(o.duration, stop)
		end
	else
		local life = math.max(template:GetAttribute("Duration") or 2, o.duration or 0)
		task.delay(life + 0.25, destroy)
	end

	return {
		stop = function()
			stop()
		end,
		destroy = function()
			destroy()
		end,
		setEnabled = setEnabled,
	}
end

--- Play effect `name` at a part, attachment, CFrame or point. Returns nil (and
--- warns once per name) when the effect cannot play; never throws.
function VfxKit.play(name: string, at: any, opts: Opts?): Handle?
	local ok, result = pcall(play, name, at, opts)
	if not ok then
		warnOnce(name, tostring(result))
		return nil
	end
	return result
end

--- Low detail: auras keep only their ground ring and particle counts halve
--- (applies to effects started after the call).
function VfxKit.setLowDetail(on: boolean)
	lowDetail = on == true
end

--- Fetch every template texture now (yields; call once at join inside a task).
function VfxKit.preload()
	local folder = templates()
	if not folder then
		return
	end
	local seen: { [string]: boolean } = {}
	local list: { string } = {}
	for _, d in folder:GetDescendants() do
		if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
			local id = (d :: any).Texture
			if id ~= "" and not seen[id] then
				seen[id] = true
				table.insert(list, id)
			end
		end
	end
	pcall(function()
		ContentProvider:PreloadAsync(list)
	end)
end

return VfxKit
