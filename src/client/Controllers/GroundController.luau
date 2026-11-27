--!strict
-- GroundController - what a training ground DOES in the world (plan 13 phase D), for every
-- player in sight, not only the one training.
--
-- The server marks a training character with TrainPlot / TrainCourt and, while awakened,
-- TrainAwake (the server time the awakening ends). From those alone every client plays the
-- ground's AWAKENING on that plot's set piece:
--   Striking Post    the post shakes under a flurry of hits and glows; when the time is up it
--                    bursts into splinters and a new one rises out of the floor
--   Waterfall Focus  the falls part down the middle and run UPWARD, a column of light stands
--                    where the trainee floats; when the time is up the water crashes back
--   Boulder Breaker  the boulder shakes and glows under a barrage; when the time is up it
--                    shatters and a new one drops out of the sky
--   Thunder Peak     lightning strikes the rods again and again and arcs to the trainee, who is
--                    wrapped in it; when the time is up one enormous bolt comes down
--   Gravity Chamber  gravity flips: everything loose (the Floaters) drifts up with the trainee;
--                    when the time is up it all slams back down
--   Spirit Orb       the orb over the trainee swells enormous; when the time is up it is thrown
--                    into the sky and bursts, and a new one gathers
-- plus the aura on the trainee. The trainee's own client also calls Contact for every rep (the
-- beats are known only to it and the server).
--
-- A set piece (ReplicatedStorage.Assets.Grounds, tools/studio/grounds/build_grounds.luau) gives:
--   Target          the thing that is struck (a Model): it wobbles, bursts and rises
--   Fx.Strike       where a fist lands;  Fx.Seat  where the trainee sits;  Fx.Pool  the splash
--   Water.Left / Water.Right   the two halves of the falls (Models with the flow Beams)
--   Fx.Rod1..3      the tips of the lightning rods (a `Mark` emitter and light on each);
--   Fx.Arc          a part holding the Beam `Arc`, copied for every bolt from a rod to a hand
--   Cracks          a part on the boulder's face whose Decals show as Focus grows
--   Fx.Floor        the floor under the push-up;  Floaters  Models that drift up when gravity flips
--   Fx.Hum          a part that carries the chamber's hum
--   Fx.Orb          where the orb's underside rests (over the raised hands); Target.Core / .Shell
--                   the orb's two balls; attributes OrbRest / OrbFull / OrbAwake (diameters) and
--                   Energy (the tier's colour) on the piece
--   emitters with attribute When = "awake" (on only during an awakening) or "calm" (off then)
-- Everything here is local and cosmetic; whatever is moved is put back exactly.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Vfx = require(script.Parent.Parent.Fx.Vfx)
local Sound = require(script.Parent.SoundController)

local player = Players.LocalPlayer

-- the colour of a ground's energy: the aura, the awakening burst, a perfect rep
local ENERGY: { [string]: Color3 } = {
	post = Color3.fromHex("FFB13B"),
	falls = Color3.fromHex("5FD8FF"),
	boulder = Color3.fromHex("FF8A3D"),
	peak = Color3.fromHex("FFE85A"),
	gravity = Color3.fromHex("B58CFF"),
	orb = Color3.fromHex("7CF59A"),
}
-- the loop under an awakening, where it is not the common one
local HUM: { [string]: string } = { peak = "storm_loop", orb = "orb_loop" }
-- set pieces that are heard from the court: the spot that carries the loop
local AMBIENCE: { [string]: string } = { Pool = "falls_loop", Hum = "gravity_hum" }

-- the grounds where a blow lands on a target: what plays for a rep, through the awakening, and
-- how the awakening ends (the target bursts; a new one RISES out of the floor or DROPS from the sky)
local STRIKE: { [string]: { [string]: any } } = {
	post = {
		hit = "Train_Hit",
		hitSound = "post_hit",
		critSound = "post_crit",
		wobble = 1,
		storm = "Train_Flurry",
		flurrySound = "flurry_hit",
		burst = "Post_Burst",
		burstSound = "post_break",
		arrive = "rise",
		arriveFx = "Post_Rise",
		arriveSound = "post_rise",
	},
	boulder = {
		hit = "Boulder_Hit",
		hitSound = "boulder_hit",
		critSound = "boulder_crit",
		wobble = 0.3,
		storm = "Boulder_Barrage",
		flurrySound = "barrage_hit",
		burst = "Boulder_Shatter",
		burstSound = "boulder_shatter",
		arrive = "drop",
		arriveFx = "Boulder_Land",
		arriveSound = "boulder_land",
	},
}
local WHITE = Color3.new(1, 1, 1)

type Show = {
	--- Ends the awakening: `completed` = it ran its full time (the big finish), else it was cut short.
	finish: (completed: boolean) -> (),
}

local GroundController = Knit.CreateController({
	Name = "GroundController",
	_shows = {} :: { [Model]: Show },
	_wobbling = {} :: { [Instance]: boolean },
	-- targets a finished show is still moving (the post gone, then rising): nothing else moves them
	_busy = {} :: { [Instance]: boolean },
	-- the orb of each Spirit Orb piece: its diameter now (Charge eases it toward what is asked)
	_orbs = {} :: { [Model]: number },
	_charge = nil :: Sound?,
})

--- The set piece on court `court` of plot `plot`, and its ground id ("post", "falls").
function GroundController:Piece(plot: number?, court: number?): (Model?, string?)
	local map = workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")
	local folder = plots and plot and plots:FindFirstChild("Plot" .. plot)
	local anchor = folder and court and folder:FindFirstChild("Ground" .. court)
	local piece = anchor and anchor:FindFirstChild("GroundModel")
	if not anchor or not piece or not piece:IsA("Model") then
		return nil, nil
	end
	local row = Config.Training.Grounds[anchor:GetAttribute("Ground") :: number]
	return piece, if row then row.Id else nil
end

--- The energy colour of ground `id` (a set piece may carry its tier's own: attribute Energy).
function GroundController:Energy(id: string?, piece: Instance?): Color3
	local own = piece and piece:GetAttribute("Energy")
	if typeof(own) == "Color3" then
		return own
	end
	return (id and ENERGY[id]) or WHITE
end

local function spot(piece: Instance?, name: string): BasePart?
	local fx = piece and piece:FindFirstChild("Fx")
	local found = fx and fx:FindFirstChild(name)
	return if found and found:IsA("BasePart") then found else nil
end

-- sounds: in the head for the trainee's own client, in the world for everyone else
local function sound(role: string, own: boolean, at: Instance?, opts: any?)
	Sound:Play(role, if own then nil else at, opts)
end

-- emitters and beams that only run during an awakening (When = "awake") or only outside one
local function setWhen(piece: Instance, awake: boolean)
	for _, item in piece:GetDescendants() do
		local when = item:GetAttribute("When")
		if when == "awake" or when == "calm" then
			local on = (when == "awake") == awake
			if item:IsA("ParticleEmitter") or item:IsA("Beam") or item:IsA("Light") then
				(item :: any).Enabled = on
			end
		end
	end
end

-- Where a target stands when nothing is moving it: the server writes it on the target when it
-- places the set piece (attribute Rest). Never read from the pivot of the moment: a blow that
-- landed while the new post was still rising took that height for the post's place and left it
-- 0.3 studs up (seen in a play test).
local function restOf(target: Model): CFrame
	local rest = target:GetAttribute("Rest")
	return if typeof(rest) == "CFrame" then rest else target:GetPivot()
end

-- a short damped wobble of the target about its base (it was struck)
function GroundController:_wobble(target: Instance?, strength: number)
	if
		not target
		or not target:IsA("Model")
		or self._wobbling[target]
		or self._busy[target]
		or self._shows[target.Parent :: any]
	then
		return
	end
	self._wobbling[target] = true
	local base = restOf(target)
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local taken = self._busy[target] or self._shows[target.Parent :: any]
		if t > 0.4 or not target.Parent or taken then
			conn:Disconnect()
			self._wobbling[target] = nil
			if target.Parent and not taken then
				target:PivotTo(base)
			end
			return
		end
		-- it leans away from the blow (the trainee stands on its +Z side) and rings back
		local angle = -math.rad(5 * strength) * math.sin(t * 30) * math.exp(-t * 8)
		target:PivotTo(base * CFrame.Angles(angle, 0, 0))
	end)
end

-- A bolt from a rod's tip to a hand: a copy of the set piece's Arc beam, alive for a blink.
local function arc(piece: Instance, from: BasePart, hand: BasePart?)
	local holder = spot(piece, "Arc")
	local template = holder and holder:FindFirstChild("Arc")
	if not template or not template:IsA("Beam") or not hand then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = from.CFrame
	local a0 = Instance.new("Attachment")
	a0.Parent = anchor
	local a1 = Instance.new("Attachment")
	a1.Parent = hand
	local beam = template:Clone()
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.CurveSize0 = (math.random() - 0.5) * 6
	beam.CurveSize1 = (math.random() - 0.5) * 6
	beam.Enabled = true
	beam.Parent = anchor
	anchor.Parent = workspace
	-- on, a blink off, on, gone
	task.delay(0.08, function()
		beam.Enabled = false
	end)
	task.delay(0.12, function()
		beam.Enabled = true
	end)
	task.delay(0.26, function()
		anchor:Destroy()
		a1:Destroy()
	end)
end

-- Where the orb's underside rests: on the trainee's two raised palms (the clips move the hands: they
-- sink as the orb grows heavy and whip up at the throw), or with no trainee the set piece's own point.
local function orbBase(piece: Model, character: Model?): Vector3?
	local left = character and character:FindFirstChild("LeftHand")
	local right = character and character:FindFirstChild("RightHand")
	if left and right and left:IsA("BasePart") and right:IsA("BasePart") then
		return (left.Position + right.Position) / 2 + Vector3.new(0, 0.3, 0)
	end
	local rest = spot(piece, "Orb")
	return if rest then rest.Position else nil
end

-- The orb of a Spirit Orb piece, `diameter` across, its underside on `base`.
local function setOrb(piece: Model, diameter: number, base: Vector3?, lift: number?)
	local target = piece:FindFirstChild("Target")
	local core = target and target:FindFirstChild("Core")
	local shell = target and target:FindFirstChild("Shell")
	if not base or not core or not core:IsA("BasePart") then
		return
	end
	local centre = base + Vector3.new(0, diameter / 2 + (lift or 0), 0)
	core.Size = Vector3.one * diameter
	core.CFrame = CFrame.new(centre)
	if shell and shell:IsA("BasePart") then
		shell.Size = Vector3.one * (diameter * 1.16)
		shell.CFrame = CFrame.new(centre)
	end
end

local function orbSize(piece: Model, key: string, fallback: number): number
	local value = piece:GetAttribute(key)
	return if typeof(value) == "number" then value else fallback
end

local function handOf(character: Model?, lane: number): BasePart?
	-- the trainee faces the camera: the rod on the camera's left is on their own right
	local hand = character
		and character:FindFirstChild(if lane == 3 then "LeftHand" else "RightHand")
	return if hand and hand:IsA("BasePart") then hand else nil
end

--- A rep of the local trainee lands on `piece` (ground `id`). `grade`: "perfect", "good" or nil.
--- `lane`: the rod the lightning strikes (Thunder Peak).
function GroundController:Contact(piece: Model?, id: string?, grade: string?, lane: number?)
	if not piece or not id then
		return
	end
	local perfect = grade == "perfect"
	local strength = if perfect then 1.5 elseif grade == "good" then 1.1 else 0.75
	local strike = STRIKE[id]
	if strike then
		local at = spot(piece, "Strike")
		if at then
			Vfx.play(strike.hit, at.Position, { scale = strength })
			if perfect then
				Vfx.play("Train_Crit", at.Position)
			end
		end
		self:_wobble(piece:FindFirstChild("Target"), strength * strike.wobble)
		Sound:Play(strike.hitSound, nil, { pitchVary = 0.07 })
		if perfect then
			Sound:Play(strike.critSound, nil, { pitchVary = 0.04 })
		end
	elseif id == "falls" then
		local at = spot(piece, "Seat")
		if at then
			Vfx.play("Train_Pulse", at.Position, {
				scale = if perfect then 1.35 else 1,
				tint = if perfect then Color3.fromHex("FFE38A") else ENERGY.falls,
				mult = strength,
			})
		end
		Sound:Play(if perfect then "breath_perfect" else "breath_pulse", nil, { pitchVary = 0.03 })
	elseif id == "gravity" then
		-- the push-up lands: the floor rings under the chest
		local at = spot(piece, "Floor")
		if at then
			Vfx.play("Gravity_Pulse", at.Position, {
				scale = if perfect then 1.3 else 1,
				tint = if perfect then Color3.fromHex("FFE38A") else self:Energy(id, piece),
				mult = strength,
			})
		end
		Sound:Play("gravity_pulse", nil, { pitchVary = 0.06 })
		if perfect then
			Sound:Play("gravity_perfect", nil, { pitchVary = 0.04 })
		end
	elseif id == "orb" then
		-- the charge is let go as a pulse from the orb (only a graded release: a miss just fades)
		local core = piece:FindFirstChild("Core", true)
		if core and core:IsA("BasePart") and grade then
			Vfx.play("Orb_Release", core.Position, {
				scale = if perfect then 1.4 else 1,
				tint = if perfect then Color3.fromHex("FFE38A") else self:Energy(id, piece),
			})
			Sound:Play(if perfect then "orb_perfect" else "orb_release", nil, { pitchVary = 0.04 })
		end
	elseif id == "peak" and lane then
		-- the bolt strikes its rod whatever the player did; caught, it runs on into the hand
		local rod = spot(piece, "Rod" .. lane)
		if rod then
			Vfx.play("Peak_Strike", rod.Position)
			Sound:Play("thunder_strike", nil, { pitchVary = 0.06 })
			if grade == "perfect" or grade == "good" then
				local hand = handOf(player.Character, lane)
				arc(piece, rod, hand)
				if hand then
					Vfx.play("Peak_Catch", hand.Position, {
						scale = if perfect then 1.3 else 1,
						tint = if perfect then ENERGY.peak else Color3.fromHex("9FE3FF"),
					})
				end
				Sound:Play(
					if perfect then "bolt_perfect" else "bolt_catch",
					nil,
					{ pitchVary = 0.05 }
				)
			end
		end
	end
end

--- One blow of the awakening's flurry (the trainee's own client, on the clip's markers).
function GroundController:Flurry(piece: Model?, id: string?)
	local strike = STRIKE[id or "post"] or STRIKE.post
	local at = spot(piece, "Strike")
	if at then
		local jitter = Vector3.new(0, (math.random() - 0.5) * 1.4, 0)
			+ at.CFrame.RightVector * ((math.random() - 0.5) * 1.1)
		Vfx.play(strike.hit, at.Position + jitter, { scale = 0.8, mult = 0.6 })
	end
	Sound:Play(strike.flurrySound, nil, { pitchVary = 0.12 })
end

--- The rod the lightning has marked (0 = none): its tip crackles and glows until it strikes.
function GroundController:Mark(piece: Model?, lane: number)
	if not piece or piece:GetAttribute("Marked") == lane then
		return
	end
	piece:SetAttribute("Marked", lane)
	for index = 1, 3 do
		local rod = spot(piece, "Rod" .. index)
		if rod then
			for _, item in rod:GetChildren() do
				if item:IsA("ParticleEmitter") or item:IsA("Light") then
					(item :: any).Enabled = index == lane
				end
			end
		end
	end
	if lane > 0 then
		Sound:Play("rod_mark", nil, { pitchVary = 0.08 })
	end
end

--- The local trainee's hold began or ended (Spirit Orb: the charge is heard).
function GroundController:Hold(_piece: Model?, id: string?, on: boolean)
	if self._charge then
		Sound:Stop(self._charge, 0.15)
		self._charge = nil
	end
	if on and id == "orb" then
		-- (the clip is 2.5 s: slowed, it rises through the whole charge)
		self._charge = Sound:Play("orb_charge", nil, { speed = 0.7 })
	end
end

--- How far the local trainee's charge has come (0 = nothing held, 1 = the gold): the orb over them
--- grows with it, and eases back when the hold ends. Called every frame of a charge session.
function GroundController:Charge(piece: Model?, fraction: number)
	if not piece or not spot(piece, "Orb") or self._shows[piece] or self._busy[piece] then
		return
	end
	local rest, full = orbSize(piece, "OrbRest", 1.6), orbSize(piece, "OrbFull", 4.2)
	local want = rest + (full - rest) * math.clamp(fraction, 0, 1.1)
	local now = self._orbs[piece] or rest
	-- it swells with the gauge and falls away fast when let go
	now += (want - now) * (if want < now then 0.22 else 0.35)
	if math.abs(want - now) < 0.01 then
		now = want
	end
	self._orbs[piece] = now
	setOrb(piece, now, orbBase(piece, player.Character))
	local field = spot(piece, "Field")
	local motes = field and field:FindFirstChild("Motes")
	if motes and motes:IsA("ParticleEmitter") then
		motes.Enabled = fraction > 0.02
	end
end

--- How full the trainee's Focus is (0..1): the boulder's face cracks further as it fills.
function GroundController:Focus(piece: Model?, fraction: number)
	local cracks = piece and piece:FindFirstChild("Cracks", true)
	if not cracks then
		return
	end
	local stage = math.floor(math.clamp(fraction, 0, 1) * 4 + 0.001)
	if cracks:GetAttribute("Stage") == stage then
		return
	end
	local grew = stage > ((cracks:GetAttribute("Stage") :: number?) or 0)
	cracks:SetAttribute("Stage", stage)
	for _, decal in cracks:GetDescendants() do
		if decal:IsA("Decal") then
			local at = (decal:GetAttribute("Stage") :: number?) or 1
			decal.Transparency = if stage >= at then 0.05 else 1
		end
	end
	if grew then
		Sound:Play("rock_crack", nil, { pitchVary = 0.1 })
	end
end

-- ------------------------------------------------------------- the shows --

-- Striking Post, Boulder Breaker: the target is shaken and glows through the flurry; at the end it
-- bursts, and a new one rises out of the floor (post) or drops from the sky (boulder).
local function showStrike(self: any, piece: Model, own: boolean, id: string): Show
	local kind = STRIKE[id]
	local target = piece:FindFirstChild("Target")
	local strike = spot(piece, "Strike")
	local base = if target and target:IsA("Model") then restOf(target) else CFrame.identity
	local glow = Instance.new("Highlight")
	glow.Name = "AwakeGlow"
	glow.FillColor = ENERGY[id]
	glow.OutlineColor = Color3.fromHex("FFF1C2")
	glow.FillTransparency = 0.75
	glow.OutlineTransparency = 0.2
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Adornee = target
	glow.Parent = piece
	local sparks = if strike then Vfx.play(kind.storm, strike, { loop = true }) else nil
	local t0 = os.clock()
	local shake = RunService.RenderStepped:Connect(function()
		if target and target:IsA("Model") and target.Parent then
			local t = os.clock() - t0
			-- struck eight times a second: a fast shiver that grows as the post gives way
			local grow = 0.6 + 0.4 * math.min(t / Config.Training.Beat.AwakeningSeconds, 1)
			local lean = math.rad(2.6 * grow * kind.wobble) * math.sin(t * 50)
			local twist = math.rad(1.4 * grow * kind.wobble) * math.sin(t * 37 + 1)
			target:PivotTo(base * CFrame.Angles(-math.abs(lean), twist, 0))
			glow.FillTransparency = 0.72 - 0.25 * grow * (0.5 + 0.5 * math.sin(t * 16))
		end
	end)
	return {
		finish = function(completed: boolean)
			shake:Disconnect()
			if sparks then
				sparks.stop()
			end
			glow:Destroy()
			if not target or not target:IsA("Model") or not target.Parent then
				return
			end
			if not completed then
				target:PivotTo(base)
				return
			end
			-- the last blow: the target flies apart, then a new one arrives
			self._busy[target] = true
			local _, size = target:GetBoundingBox()
			if strike then
				Vfx.play(kind.burst, strike.Position)
			end
			sound(kind.burstSound, own, strike)
			self:Focus(piece, 0)
			local drop = kind.arrive == "drop"
			-- out of sight: under the floor (it will rise) or high above (it will fall)
			local away = if drop then Vector3.new(0, 60, 0) else Vector3.new(0, -(size.Y + 2), 0)
			target:PivotTo(base + away)
			task.delay(0.45, function()
				if not target.Parent then
					self._busy[target] = nil
					return
				end
				if not drop then
					Vfx.play(kind.arriveFx, base.Position)
					sound(kind.arriveSound, own, strike)
				end
				local t1 = os.clock()
				local seconds = if drop then 0.38 else 0.5
				local landed = false
				local conn: RBXScriptConnection
				conn = RunService.RenderStepped:Connect(function()
					local u = math.clamp((os.clock() - t1) / seconds, 0, 1)
					if not target.Parent then
						conn:Disconnect()
						self._busy[target] = nil
						return
					end
					if drop then
						-- it falls faster and faster, lands, and the floor takes it
						target:PivotTo(base + away * (1 - u * u))
						if u >= 1 and not landed then
							landed = true
							Vfx.play(kind.arriveFx, base.Position)
							sound(kind.arriveSound, own, strike)
						end
					else
						-- up fast, a small overshoot, settle
						local back = 1 + 2.2 * (u - 1) ^ 3 + 1.2 * (u - 1) ^ 2
						target:PivotTo(base + away * (1 - back))
					end
					if u >= 1 then
						conn:Disconnect()
						target:PivotTo(base)
						self._busy[target] = nil
					end
				end)
			end)
		end,
	}
end

-- Thunder Peak: lightning strikes the rods again and again and arcs to the trainee; at the end one
-- enormous bolt comes down on them.
local function showPeak(_self: any, piece: Model, own: boolean, _id: string, character: Model): Show
	setWhen(piece, true)
	local root = character:FindFirstChild("HumanoidRootPart")
	local storm = if root then Vfx.play("Peak_Storm", root, { loop = true }) else nil
	local alive = true
	task.spawn(function()
		local n = 0
		while alive and piece.Parent and character.Parent do
			n += 1
			local lane = (n * 2) % 3 + 1
			local rod = spot(piece, "Rod" .. lane)
			if rod then
				Vfx.play("Peak_Strike", rod.Position)
				arc(piece, rod, handOf(character, if n % 2 == 0 then 1 else 3))
				sound("thunder_strike", own, rod, { pitchVary = 0.1 })
			end
			task.wait(0.42)
		end
	end)
	return {
		finish = function(completed: boolean)
			alive = false
			if storm then
				storm.stop()
			end
			setWhen(piece, false)
			if completed and root and root:IsA("BasePart") then
				Vfx.play("Peak_Finale", root.Position - Vector3.new(0, 3, 0))
				sound("storm_finale", own, root)
			end
		end,
	}
end

-- Gravity Chamber: gravity flips. Everything loose drifts up and turns slowly; at the end it all
-- drops and the floor takes it.
local function showGravity(self: any, piece: Model, own: boolean, id: string): Show
	local floor = spot(piece, "Floor")
	local colour = self:Energy(id, piece)
	local loose: { { model: Model, base: CFrame, rise: number, turn: number, phase: number } } = {}
	local floaters = piece:FindFirstChild("Floaters")
	if floaters then
		for i, item in floaters:GetChildren() do
			if item:IsA("Model") then
				table.insert(loose, {
					model = item,
					base = item:GetPivot(),
					rise = 2.2 + (i * 1.37) % 2.6,
					turn = (if i % 2 == 0 then 1 else -1) * (0.25 + (i * 0.31) % 0.4),
					phase = i * 1.7,
				})
			end
		end
	end
	setWhen(piece, true)
	sound("gravity_flip", own, floor)
	if floor then
		Vfx.play("Gravity_Flip", floor.Position, { tint = colour })
	end
	local drift = if floor
		then Vfx.play("Gravity_Float", floor, { loop = true, tint = colour })
		else nil
	local t0 = os.clock()
	local up = 0
	local conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		up = 1 - (1 - math.clamp(t / 0.9, 0, 1)) ^ 3
		for _, row in loose do
			if row.model.Parent then
				local bob = 0.22 * math.sin(t * 1.3 + row.phase)
				row.model:PivotTo(
					(row.base + Vector3.new(0, row.rise * up + bob * up, 0))
						* CFrame.Angles(
							0.12 * up * math.sin(t * 0.8 + row.phase),
							row.turn * t * up,
							0
						)
				)
			end
		end
	end)
	return {
		finish = function(completed: boolean)
			conn:Disconnect()
			if drift then
				drift.stop()
			end
			setWhen(piece, false)
			-- gravity comes back: everything falls faster and faster and the floor takes it
			local from: { CFrame } = {}
			for i, row in loose do
				from[i] = row.model:GetPivot()
			end
			local c0 = os.clock()
			local back: RBXScriptConnection
			back = RunService.RenderStepped:Connect(function()
				local u = math.clamp((os.clock() - c0) / 0.2, 0, 1)
				for i, row in loose do
					if row.model.Parent then
						row.model:PivotTo(
							if u >= 1 then row.base else from[i]:Lerp(row.base, u * u)
						)
					end
				end
				if u >= 1 then
					back:Disconnect()
					if completed then
						if floor then
							Vfx.play("Gravity_Slam", floor.Position, { tint = colour })
						end
						sound("gravity_slam", own, floor)
					end
				end
			end)
		end,
	}
end

-- Spirit Orb: the orb swells enormous over the trainee; at the end it is thrown into the sky and
-- bursts there, and a new one gathers over the hands.
local function showOrb(self: any, piece: Model, own: boolean, id: string, character: Model): Show
	local colour = self:Energy(id, piece)
	local rest = orbSize(piece, "OrbRest", 1.6)
	local big = orbSize(piece, "OrbAwake", 8.5)
	local core = piece:FindFirstChild("Core", true)
	local trail = core and core:FindFirstChildOfClass("Trail")
	setWhen(piece, true)
	local t0 = os.clock()
	local from = self._orbs[piece] or rest
	local size = from
	local conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local u = 1 - (1 - math.clamp(t / 0.7, 0, 1)) ^ 3
		-- it swells, then breathes
		size = (from + (big - from) * u) * (1 + 0.035 * u * math.sin(t * 9))
		setOrb(piece, size, orbBase(piece, character))
	end)
	return {
		finish = function(completed: boolean)
			conn:Disconnect()
			setWhen(piece, false)
			self._busy[piece] = true
			local c0 = os.clock()
			local start = size
			local thrown = completed
			-- it leaves the hands from where they are now
			local launch = orbBase(piece, character)
			local burst = false
			if thrown then
				sound("orb_throw", own, core)
				if trail then
					trail.Enabled = true
				end
			end
			local back: RBXScriptConnection
			back = RunService.RenderStepped:Connect(function()
				local t = os.clock() - c0
				if not piece.Parent then
					back:Disconnect()
					self._busy[piece] = nil
					return
				end
				if thrown and t < 0.55 then
					-- away: faster and faster, straight up, shrinking with the distance
					local u = t / 0.55
					setOrb(piece, start * (1 - 0.45 * u), launch, 40 * u * u)
				elseif thrown and not burst then
					burst = true
					if launch then
						Vfx.play("Orb_Burst", launch + Vector3.new(0, 40, 0), { tint = colour })
					end
					sound("orb_burst", own, core)
					if trail then
						trail.Enabled = false
					end
					setOrb(piece, 0.05, launch)
				elseif thrown and t < 1.0 then
					setOrb(piece, 0.05, orbBase(piece, character))
				else
					-- a new orb gathers (or, cut short, the big one sinks back)
					local u = math.clamp((t - (if thrown then 1.0 else 0)) / 0.5, 0, 1)
					local now = if thrown then rest * u else start + (rest - start) * u
					setOrb(piece, math.max(now, 0.05), orbBase(piece, character))
					if u >= 1 then
						back:Disconnect()
						self._orbs[piece] = rest
						self._busy[piece] = nil
					end
				end
			end)
		end,
	}
end

-- Waterfall Focus: the falls part and run upward; at the end the water crashes back.
local function showFalls(_self: any, piece: Model, own: boolean, _id: string): Show
	local water = piece:FindFirstChild("Water")
	local seat = spot(piece, "Seat")
	local pool = spot(piece, "Pool")
	local halves: { { model: Model, base: CFrame, dir: number } } = {}
	local beams: { { beam: Beam, speed: number } } = {}
	if water then
		for _, name in { "Left", "Right" } do
			local half = water:FindFirstChild(name)
			if half and half:IsA("Model") then
				table.insert(
					halves,
					{ model = half, base = half:GetPivot(), dir = if name == "Left" then -1 else 1 }
				)
			end
		end
		for _, item in water:GetDescendants() do
			if item:IsA("Beam") and item:GetAttribute("Flow") then
				table.insert(beams, { beam = item, speed = item.TextureSpeed })
			end
		end
	end
	setWhen(piece, true)
	sound("falls_split", own, seat)
	local column = if seat then Vfx.play("Falls_Ascend", seat, { loop = true }) else nil
	-- part the halves, turn the flow round
	local t0 = os.clock()
	local open = 0
	local conn = RunService.RenderStepped:Connect(function()
		local u = math.clamp((os.clock() - t0) / 0.7, 0, 1)
		open = 1 - (1 - u) ^ 3
		for _, half in halves do
			if half.model.Parent then
				-- along the falls' own width (the set piece's right vector)
				half.model:PivotTo(
					half.base + piece:GetPivot().RightVector * (half.dir * 2.1 * open)
				)
			end
		end
		for _, row in beams do
			row.beam.TextureSpeed = row.speed * (1 - 2.6 * open)
		end
	end)
	return {
		finish = function(completed: boolean)
			conn:Disconnect()
			if column then
				column.stop()
			end
			setWhen(piece, false)
			if completed then
				if pool then
					Vfx.play("Falls_Crash", pool.Position)
				end
				sound("falls_crash", own, pool)
			end
			-- the water closes again and falls
			local c0 = os.clock()
			local from = open
			local back: RBXScriptConnection
			back = RunService.RenderStepped:Connect(function()
				local u = math.clamp((os.clock() - c0) / 0.35, 0, 1)
				local now = from * (1 - u) ^ 2
				for _, half in halves do
					if half.model.Parent then
						half.model:PivotTo(
							half.base + piece:GetPivot().RightVector * (half.dir * 2.1 * now)
						)
					end
				end
				for _, row in beams do
					row.beam.TextureSpeed = row.speed * (1 - 2.6 * now)
				end
				if u >= 1 then
					back:Disconnect()
					for _, half in halves do
						if half.model.Parent then
							half.model:PivotTo(half.base)
						end
					end
					for _, row in beams do
						row.beam.TextureSpeed = row.speed
					end
				end
			end)
		end,
	}
end

local SHOWS: { [string]: (self: any, piece: Model, own: boolean, id: string, character: Model) -> Show } =
	{
		post = showStrike,
		boulder = showStrike,
		falls = showFalls,
		peak = showPeak,
		gravity = showGravity,
		orb = showOrb,
	}

-- A character's TrainAwake changed: run (or end) the awakening on its ground.
function GroundController:_awake(character: Model)
	local untilT = character:GetAttribute("TrainAwake")
	local now = workspace:GetServerTimeNow()
	if typeof(untilT) ~= "number" or untilT <= now then
		return
	end
	local piece, id = self:Piece(
		character:GetAttribute("TrainPlot") :: number?,
		character:GetAttribute("TrainCourt") :: number?
	)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not piece or not id or not root or self._shows[piece] then
		return
	end
	local own = character == player.Character
	local colour = self:Energy(id, piece)
	local show = if SHOWS[id]
		then SHOWS[id](self, piece, own, id, character)
		else { finish = function() end }
	self._shows[piece] = show
	Vfx.play("Train_Awaken", root, { tint = colour })
	local aura = Vfx.play("Train_Aura", root, { loop = true, tint = colour })
	sound("awaken_start", own, root)
	if own then
		Sound:Play("awaken_sting", nil)
	end
	local hum = Sound:Play(HUM[id] or "awaken_loop", if own then nil else root, { fadeIn = 0.4 })
	task.spawn(function()
		-- until the time is up, or the session ends early (the attribute goes, the character goes)
		local completed = false
		while character.Parent and piece.Parent do
			if character:GetAttribute("TrainAwake") ~= untilT then
				break
			end
			if workspace:GetServerTimeNow() >= untilT then
				completed = true
				break
			end
			task.wait()
		end
		aura.stop()
		if hum then
			TweenService:Create(hum, TweenInfo.new(0.3), { Volume = 0 }):Play()
			task.delay(0.35, function()
				hum:Destroy()
			end)
		end
		self._shows[piece] = nil
		if piece.Parent then
			show.finish(completed)
		end
		if completed and character.Parent then
			Vfx.play("Train_Awaken", root, { tint = colour, scale = 0.7 })
		end
	end)
end

function GroundController:_watch(character: Model)
	character:GetAttributeChangedSignal("TrainAwake"):Connect(function()
		local ok, err = pcall(function()
			self:_awake(character)
		end)
		if not ok then
			warn(`[GroundController] awakening failed inert: {err}`)
		end
	end)
	task.defer(function()
		pcall(function()
			self:_awake(character)
		end)
	end)
end

-- Some grounds are heard from the court: the falls' water, the gravity chamber's machine.
function GroundController:_ambience()
	local map = workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")
	if not plots then
		return
	end
	for _, plot in plots:GetChildren() do
		for court = 1, #Config.Training.Courts do
			local anchor = plot:FindFirstChild("Ground" .. court)
			local piece = anchor and anchor:FindFirstChild("GroundModel")
			for name, role in AMBIENCE do
				local at = spot(piece, name)
				if at and not at:FindFirstChild(role) then
					local loop = Sound:Play(role, at, { fadeIn = 0.8 })
					if loop then
						loop.Name = role
						loop.RollOffMode = Enum.RollOffMode.InverseTapered
						loop.RollOffMinDistance = 10
						loop.RollOffMaxDistance = 70
					end
				end
			end
		end
	end
end

function GroundController:KnitStart()
	task.spawn(function()
		while true do
			pcall(function()
				self:_ambience()
			end)
			task.wait(2)
		end
	end)
	local function follow(other: Player)
		if other.Character then
			self:_watch(other.Character)
		end
		other.CharacterAdded:Connect(function(character: Model)
			self:_watch(character)
		end)
	end
	for _, other in Players:GetPlayers() do
		follow(other)
	end
	Players.PlayerAdded:Connect(follow)
end

return GroundController
