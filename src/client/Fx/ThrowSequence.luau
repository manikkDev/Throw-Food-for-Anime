--!strict
-- ThrowSequence - the thrower's own cinematic, start to finish. A replay of
-- a result the server has ALREADY decided and granted: nothing here changes
-- the game, so it can be skipped, shortened or interrupted freely.
--
-- THE TIMELINE (t0 = the result arrives; F = flight, P = Throw.LandPauseSeconds,
-- R = reveal, all from the server's result):
--
--   t0                 letterbox in, close side shot, wind-up (the Throw clip,
--                      or ThrowPose without it)
--   t0 + 0.55          RELEASE: the food leaves the hand (the clip's "Release"
--                      marker; 0.72 * W with ThrowPose, W = wind-up, 0.5 s)
--   .. t0 + F          flight: chase camera, wider FOV, trail, the luck
--                      counter climbs to the throw's luck, the zone ribbon
--                      follows the food across each gate
--   t0 + F             LANDING: dust ring, two bounces, cut to a low camera
--                      that pushes in; the odds counter appears at "1 in 1"
--   t0 + F + P         SUSPENSE: a black silhouette stalks up the lane toward
--                      the food over five or six shots (see the SUSPENSE block);
--                      the odds tremble and climb (slow, then fast); the name is
--                      blank slots in the last shot only
--   end - 3.0          FINAL BEAT: flash, the real hero, burst in the rarity
--                      colour, stamp / variant / name / ribbon / income, a
--                      small orbit; "tap to continue" 0.5 s later
--   end - 0.2          white flash out
--   end                = t0 + F + P + R, less the time the result took to
--                      arrive: never later than the server's arrival time
--
-- A tap jumps to the final beat; a second tap ends it. `fast` (the Fast
-- reveal setting, Auto Throw) keeps the flight and the landing and plays a
-- 1.5 s final beat with no suspense.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local World = require(ReplicatedStorage.Shared.Core.World)
local ImportedFx = require(script.Parent.ImportedFx)
local Motion = require(script.Parent.Motion)
local ThrowPose = require(script.Parent.ThrowPose)
local Vfx = require(script.Parent.Vfx)
local Sound = require(script.Parent.Parent.Controllers.SoundController)
local RevealUi = require(script.Parent.Parent.Ui.RevealUi)
local Theme = require(script.Parent.Parent.Ui.Theme)
local Viewports = require(script.Parent.Parent.Ui.Viewports)

local MAPS = Lookup.of(Config)
local T = Config.Throw
local W = Config.World
local COUNT = Config.Server.PlotCount
local player = Players.LocalPlayer

-- The authored Throw clip releases the food on its "Release" marker, or at
-- RELEASE_AT seconds into the clip (at speed 1) if the marker never comes.
local RELEASE_AT = 0.7667 -- the full-power Throw clip (2026-11-15): Release at frame 23 of 1.5 s
-- the rarity sting for each rarity (Secret plays Mythic's, slowed)
local STINGS: { [string]: { role: string, speed: number? } } = {
	Common = { role = "reveal_common" },
	Uncommon = { role = "reveal_common" },
	Rare = { role = "reveal_rare" },
	Epic = { role = "reveal_epic" },
	Legendary = { role = "reveal_legendary" },
	Mythic = { role = "reveal_mythic" },
	Secret = { role = "reveal_mythic", speed = 0.85 },
}

--- The trail effect for a food: by its tier (1-4, 5-8, 9-12).
local function trailFor(foodId: string): (string, Color3?)
	local food = MAPS.food[foodId]
	if not food then
		return "ThrowTrail_Basic", nil
	end
	local name = if food.Tier >= 9
		then "ThrowTrail_Epic"
		elseif food.Tier >= 5 then "ThrowTrail_Hot"
		else "ThrowTrail_Basic"
	return name, Theme.FLAVOR[food.Flavor]
end

-- The rarities from least to most rare: the suspense escalates through them one step at a time
-- (white, green, blue, purple, gold, red, black) and stops at the catch's own rarity.
local RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }
local RARITY_INDEX: { [string]: number } = {}
for index, name in RARITY_ORDER do
	RARITY_INDEX[name] = index
end
-- the imported purple flare bursts on these reveals (its colours fit them; gold has its own pillar)
local FLARE_RARITIES: { [string]: boolean } = { Epic = true, Mythic = true, Secret = true }

local WINDUP = 0.8 -- seconds of wind-up and release before the food flies (the clip releases at 0.77 s)
local FINAL_HOLD = 5.0 -- the final beat starts this long before the end: long enough to SEE the catch
local FAST_SECONDS = 1.5 -- the whole reveal in the fast version
local SKIP_HOLD = 2.5 -- how long the final beat stays after a skip
local EXIT_FLASH = 0.2
local FOOD_REST = 0.95 -- height of the resting food's centre over the ground (HeroPickUp reaches it there)
local HAND_OFFSET = CFrame.new(0, -1.1, -0.5) -- the food, in the right hand
-- The gate at the lane mouth: its beams start about 20 studs over the lane
-- ground. The food goes under them no higher than this, and the chase camera
-- stays under this until it is through.
local GATE_FOOD_Y = 12
local GATE_CAMERA_Y = 16
-- seconds of flight ahead of the food at which a gate crossing is announced
local GATE_LEAD = 0.28
-- The suspense walk: Roblox's own R15 walk stands in until the HeroWalkIn clip is in the place.
local DEFAULT_WALK = "rbxassetid://507777826"
local STEP_STUDS = 1.3 -- one footstep per this much ground covered (when the clip has no markers)
-- ground speed at playback speed 1 (studs per second): HeroStalk (owner's review 3, the slow villain
-- stride) and HeroWalkIn (the earlier stride, the stand-in)
local STALK_SPEED = 1.5 -- HeroStalk: 2.5 studs per 1.6667 s cycle
local WALKIN_SPEED = 2.1063
-- the reveal's phases (owner's review 4): its own eyes first for at least POV_MIN, walk shots of
-- at least SHOT_MIN each, the pick-up (HeroPickUp) last
local POV_MIN = 2.4
local SHOT_MIN = 3.0
-- the stalk is played slower than its own pace: a slow, heavy villain stride (0.8 = 1.2 studs/s)
local STALK_PACE = 0.8
local SETTLE_STUDS = 0.5
local SETTLE_SECONDS = 0.6667
local PICKUP_SECONDS = 2.5
-- after the pick-up, the shape holds its catch this long before the flash (owner's review 5)
local HOLD_LINGER = 1.8
-- no reveal camera comes closer than this to the food on the ground
local FOOD_CLEAR = 4.5
-- where the food lies from the hero's root when it bends for it (HeroPickUp's reach), and the
-- food in its right hand from the grab on
local PICK_REACH = 2.71
local PICK_SIDE = 1.01
local HELD_GRIP = CFrame.new(0, -1.05, 0) -- HeroPickUp: knuckles on the top of a 0.9-radius food
local HELD_SCALE = 0.55 -- the food in a hand, against its size on the ground

export type Deps = {
	result: any,
	foodId: string,
	plot: number,
	--- The 1.5 s version (Fast reveal setting, Auto Throw).
	fast: boolean,
	--- os.clock() when the request was sent (to end no later than the server).
	sentAt: number,
	--- Skip presses counted since the sequence began.
	taps: () -> number,
	--- True when the sequence must end at once (a newer result is waiting).
	aborted: () -> boolean,
	makeFood: (foodId: string) -> Part,
	--- `bare`: no auras (the suspense silhouette: an aura would give the catch away).
	build: (id: string, mut: string?, size: string?, bare: boolean?) -> (Model, number),
	animate: (model: Model) -> any,
	--- The caught hero's entrance at the final beat (RevealLand, Eat, idle); `holding`: it picked
	--- the food up in the suspense, so no landing, straight to the bite.
	land: (model: Model, holding: boolean?) -> (),
	--- The furthest zone (index) this player had reached before this throw:
	--- a gate past it fires Zone_Unlock.
	bestZone: number,
	--- Called once, the instant the food leaves the hand.
	released: () -> (),
	--- The food crossed into zone `index` (the HUD's region banner).
	zoneCross: (index: number) -> (),
}

type Windup = {
	--- os.clock() of the release (moved earlier by the clip's marker).
	releaseAt: number,
	hand: BasePart?,
	--- True once the clip's "Release" marker has been reached.
	marked: boolean,
	stop: () -> (),
}

local ThrowSequence = {}

ThrowSequence.trailFor = trailFor

-- The wind-up: the authored Throw clip when there is one (released on its
-- "Release" marker or at RELEASE_AT, whichever is first), else the
-- code-driven ThrowPose. `budget` is the most time the wind-up may take.
local function windUp(character: Model?, budget: number): Windup
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local track = if humanoid then Motion.load(humanoid, "Throw") else nil
	if not track then
		local pose = ThrowPose.start(character, budget)
		return { releaseAt = pose.releaseAt, hand = pose.hand, marked = false, stop = pose.stop }
	end
	local hand = character and character:FindFirstChild("RightHand")
	local speed = math.clamp(RELEASE_AT / math.max(budget * 1.1, 0.05), 1, 2.5)
	local handle: Windup = {
		releaseAt = os.clock() + RELEASE_AT / speed,
		hand = if hand and hand:IsA("BasePart") then hand else nil,
		marked = false,
		stop = function() end,
	}
	local marker = Motion.onMarker(track, "Release", function()
		if not handle.marked then
			handle.marked = true
			handle.releaseAt = math.min(handle.releaseAt, os.clock())
		end
	end)
	Motion.play(humanoid, "Throw", { fade = 0.08, speed = speed })
	handle.stop = function()
		if marker then
			marker:Disconnect()
		end
		-- the follow-through plays out; only a clip still running is faded
		Motion.stop(track, 0.25)
	end
	return handle
end

-- Index of the zone whose band of the lane holds world `z` (0 before the
-- lane mouth), and the z of the gate at the start of zone `index`.
local function zoneIndexAt(z: number): number
	if z < W.LaneStartZ then
		return 0
	end
	local edge = W.LaneStartZ
	for index, zone in Config.Zones do
		edge += zone.LengthStuds
		if z < edge then
			return index
		end
	end
	return #Config.Zones
end

local function gateZ(index: number): number
	local edge = W.LaneStartZ
	for i = 1, index - 1 do
		edge += Config.Zones[i].LengthStuds
	end
	return edge
end

--- A point on the food's arc from `from` to `to` at fraction `t`. The arc is
--- as high as the throw is long, but never so high that the food would hit
--- the gate at the lane mouth: it passes the gate (at Config.World.LaneStartZ)
--- no higher than GATE_FOOD_Y over the lane ground.
function ThrowSequence.arcPoint(from: Vector3, to: Vector3, t: number): Vector3
	local height = math.clamp((to - from).Magnitude * 0.14, 14, 70)
	local span = to.Z - from.Z
	if span > 1 then
		local atGate = (W.LaneStartZ - from.Z) / span
		if atGate > 0.02 and atGate < 0.98 then
			local line = from.Y + (to.Y - from.Y) * atGate
			local room = W.GroundY + GATE_FOOD_Y - line
			height = math.min(height, math.max(room, 1) / (4 * atGate * (1 - atGate)))
		end
	end
	return from:Lerp(to, t) + Vector3.new(0, height * 4 * t * (1 - t), 0)
end

local function smooth(u: number): number
	local x = math.clamp(u, 0, 1)
	return x * x * (3 - 2 * x)
end

-- "_ _ _ _ _   _ _ _ _" for a name: one slot per letter with the letters at
-- `shown` filled in. Every slot stands apart (adjacent underscores under a
-- thick outline merge into one bar), and a space in the name is a wider gap.
local function puzzle(name: string, order: { number }, shown: number): string
	local chars = table.create(#name, "_")
	for index = 1, #name do
		if name:sub(index, index) == " " then
			chars[index] = " "
		end
	end
	for index = 1, math.min(shown, #order) do
		local at = order[index]
		chars[at] = name:sub(at, at)
	end
	return table.concat(chars, " ")
end

--- Play the whole sequence for `deps.result`. Yields until it is over and
--- everything it made is gone. Returns true when it ended BEFORE the server's
--- arrival time (skipped or the fast version), so the caller can bring the
--- hero to the plot now.
function ThrowSequence.play(deps: Deps): boolean
	local result = deps.result
	local camera = workspace.CurrentCamera
	local character = player.Character
	local rootInstance = character and character:FindFirstChild("HumanoidRootPart")
	local root = if rootInstance and rootInstance:IsA("BasePart") then rootInstance else nil

	-- the clock: everything is laid out against absolute times, so a slow
	-- frame shortens a phase instead of pushing the end back
	local t0 = os.clock()
	local lag = math.clamp(t0 - deps.sentAt, 0, 1)
	local flightEnd = t0 + math.max(1, result.flight - lag)
	local revealStart = flightEnd + T.LandPauseSeconds
	local serverEnd = revealStart + result.reveal
	local revealSeconds = if deps.fast then math.min(result.reveal, FAST_SECONDS) else result.reveal
	local tEnd = revealStart + revealSeconds
	local tFinal = if deps.fast then revealStart else math.max(revealStart + 0.3, tEnd - FINAL_HOLD)
	local windup = math.min(WINDUP, (flightEnd - t0) * 0.4)

	local laneX = World.plotX(W, deps.plot, COUNT)
	local ground = W.GroundY
	local target = Vector3.new(result.x, ground + FOOD_REST, result.z)
	-- the hero stands on the side of the food with more lane, and walks in
	-- from that side
	local side = if result.x > laneX then -1 else 1
	-- where the hero stops: just up the lane from the food, the food in front of its right foot
	-- (it walks toward -Z, so its right is +X)
	local heroSpot = Vector3.new(result.x - PICK_SIDE, ground + 0.3, result.z + PICK_REACH)
	local farCam = CFrame.lookAt(target + Vector3.new(-side * 4, 6, -30), target)
	local lowCam = CFrame.lookAt(
		target + Vector3.new(-side * 2.6, 1.3 - FOOD_REST + 1.2, -9.5),
		target + Vector3.new(side * 2.2, 1, 0)
	)

	-- Move the carrier with CFrame, never Position: setting Position on a part held by a
	-- WeldConstraint re-welds it in place and leaves the welded food model behind (found in
	-- play 2026-11-15: the model hung 175 studs from the flying carrier).
	local baseFov = camera.FieldOfView
	local ball = deps.makeFood(deps.foodId)
	do
		local food = ball:FindFirstChildWhichIsA("Model")
		if food then
			local _, size = food:GetBoundingBox()
			target =
				Vector3.new(target.X, ground + math.max(FOOD_REST, size.Y / 2 + 0.25), target.Z)
		end
	end
	local trail = ball:FindFirstChildOfClass("Trail")
	if trail then
		trail.Enabled = false
	end
	local pose: Windup? = nil
	local silhouette: Model? = nil
	local hero: Model? = nil
	local trailFx: Vfx.Handle? = nil
	local drumroll: Sound? = nil
	local flightSound: Sound? = nil
	local riser: Sound? = nil
	local heartbeat: Sound? = nil
	local wind: Sound? = nil
	local pickedUp = false -- the hero picked the food up in the suspense
	local rarityIndex = RARITY_INDEX[tostring(result.rarity)] or 1
	-- the colour grade of the suspense (darker and less saturated the rarer the catch) and the
	-- one-frame anime "impact frame" at the final beat; removed whatever happens
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "RevealGrade"
	grade.Parent = Lighting
	local shake = 0 -- camera shake amplitude (studs), decays every frame
	local kick = 0 -- extra field of view when the food crosses a gate, decays every frame
	local tapsSeen = deps.taps()

	-- run `step(now)` every frame until `untilTime` (or until `early()` says
	-- so); false if a tap cut it short
	local function frames(
		untilTime: number,
		step: (now: number) -> (),
		early: (() -> boolean)?
	): boolean
		while true do
			if deps.aborted() or deps.taps() > tapsSeen then
				return false
			end
			local now = os.clock()
			step(math.min(now, untilTime))
			if now >= untilTime or (early and early()) then
				return true
			end
			RunService.RenderStepped:Wait()
		end
	end

	local lastPop = 0
	local lastOdds = 0
	local function climbOdds(now: number)
		-- 1 -> oneInN on a curve that crawls, then runs: the exponent of the
		-- real odds grows with time, so each step is bigger than the last
		local u = math.clamp((now - flightEnd) / math.max(tFinal - flightEnd, 0.01), 0, 1)
		local value = math.max(1, math.floor(math.max(result.oneInN, 1) ^ (u ^ 2.1)))
		local canPop = now - lastPop > 0.12
		if RevealUi.odds(value, canPop) and canPop then
			lastPop = now
		end
		if value ~= lastOdds then
			-- one tick per step of the counter (the controller caps it), higher as it runs
			lastOdds = value
			Sound:Play("odds_tick", nil, { speed = 0.85 + 0.7 * u })
		end
	end
	local function shaken(cf: CFrame): CFrame
		if shake <= 0.01 then
			return cf
		end
		local jitter = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * shake
		shake *= 0.86
		return cf * CFrame.new(jitter)
	end
	local function pushIn(now: number)
		local u = smooth((now - flightEnd) / math.max(tFinal - flightEnd, 0.01))
		camera.CFrame = shaken(farCam:Lerp(lowCam, u))
		camera.FieldOfView = baseFov - 4 * u
	end

	local ok, err = pcall(function()
		task.spawn(function()
			pcall(function()
				player:RequestStreamAroundAsync(target, 4)
			end)
		end)
		RevealUi.enable(true)
		RevealUi.letterbox(true, 0.25)
		camera.CameraType = Enum.CameraType.Scriptable

		-- WIND-UP: a close shot from the lane side, the food in the hand
		-- everything starts from where the character really stands (the pad is
		-- a raised stage); the fallback is only for a character that is gone
		local stand = if root then root.Position else Vector3.new(laneX, ground + 6, W.ThrowPadZ)
		if root then
			root.CFrame = CFrame.lookAt(stand, stand + Vector3.zAxis)
		end
		-- on the character's right (the throwing arm), the same side as throw
		-- mode's shoulder camera, so the cut does not flip the screen
		-- a true side view (2026-11-15): the full-power clip strides 1.6 studs and releases 3.4
		-- studs in front of the root, so a camera in front had the food fill the lens
		local sideCam =
			CFrame.lookAt(stand + Vector3.new(-10, 2.2, 2.2), stand + Vector3.new(0, 1, 2))
		local thrown = windUp(character, windup)
		pose = thrown
		local hand = thrown.hand
		local inHand = stand + Vector3.new(1, 1.5, 1)
		local flowing = frames(thrown.releaseAt, function(now: number)
			ball.CFrame = if hand then hand.CFrame * HAND_OFFSET else CFrame.new(inHand)
			local u = smooth((now - t0) / math.max(thrown.releaseAt - t0, 0.01))
			camera.CFrame = sideCam * CFrame.new(0, 0, -1.5 * u)
		end, function(): boolean
			return thrown.marked
		end)

		-- RELEASE: the whoosh, the perfect flash, the trail by food tier
		local released = os.clock()
		local from = ball.Position
		ball:SetAttribute("Tumble", true)
		deps.released()
		Sound:Play("throw_whoosh", nil, { pitchVary = 0.06 })
		if result.perfect then
			Vfx.play("PerfectThrow_Flash", hand or from)
			Sound:Play("perfect_ding")
		end
		-- the food rushes through the air: a wind loop on the food, rising in pitch with the speed
		flightSound = Sound:Play("food_flight", ball, { fadeIn = 0.15 })
		local trailName, trailTint = trailFor(deps.foodId)
		trailFx = Vfx.play(trailName, ball, { loop = true, tint = trailTint })
		if trail and not (trailFx and trailFx.authored) then
			-- the plain trail only stands in for an authored one
			trail.Enabled = true
		end

		-- FLIGHT: chase the food down the lane; each gate it passes clicks,
		-- the zone's ambience fades in under the music, and a gate this player
		-- has never been past before opens with Zone_Unlock
		local zoneAt = zoneIndexAt(from.Z)
		if flowing then
			local cut = camera.CFrame
			flowing = frames(flightEnd, function(now: number)
				local u = math.clamp((now - released) / math.max(flightEnd - released, 0.01), 0, 1)
				local position = ThrowSequence.arcPoint(from, target, u)
				ball.CFrame = ball.CFrame.Rotation + position
				-- a gate is announced a moment BEFORE the food reaches it (owner's review 4: the sound
				-- and the banner came late): the whoosh peaks and the banner is up as it passes
				local ahead = math.clamp(u + GATE_LEAD / math.max(flightEnd - released, 0.01), 0, 1)
				local zone = zoneIndexAt(ThrowSequence.arcPoint(from, target, ahead).Z)
				if zone > zoneAt then
					for crossed = zoneAt + 1, zone do
						deps.zoneCross(crossed)
						shake = math.max(shake, 0.25 + 0.08 * crossed)
						kick = 6
						if crossed > deps.bestZone then
							Vfx.play("Zone_Unlock", Vector3.new(laneX, ground, gateZ(crossed)))
						end
					end
					zoneAt = zone
					Sound:SetAmbience(Config.Zones[zone].Id)
				end
				-- behind and above the food; held under the gate's beams until
				-- the camera itself is through the gate, then let up again
				local eye = position + Vector3.new(0, 7, -15)
				local through = smooth((eye.Z - (W.LaneStartZ + 8)) / 24)
				local capped = math.min(eye.Y, ground + GATE_CAMERA_Y)
				eye = Vector3.new(eye.X, capped + (eye.Y - capped) * through, eye.Z)
				local chase = CFrame.lookAt(eye, position + Vector3.new(0, -1, 12))
				local blend = smooth((now - released) / 0.35)
				camera.CFrame = shaken(cut:Lerp(chase, blend))
				kick *= 0.9
				camera.FieldOfView = baseFov + 12 * smooth((now - released) / 0.6) + kick
				if flightSound then
					flightSound.PlaybackSpeed = 0.85
						+ 0.45 * math.sin(math.pi * math.min(u, 1) * 0.5)
				end
				RevealUi.flight(1 + (result.luck - 1) * smooth(u), "")
			end)
		end
		thrown.stop()
		RevealUi.endFlight()
		if flightSound then
			Sound:Stop(flightSound, 0.2)
			flightSound = nil
		end

		-- LANDING: the impact, two bounces, the low camera starts to push in;
		-- the drumroll starts 0.2 s after the food lands
		if flowing then
			local floor = Vector3.new(target.X, ground + 0.15, target.Z)
			ball:SetAttribute("Tumble", false)
			local firstHop = T.LandPauseSeconds * 0.45
			local secondHop = T.LandPauseSeconds * 0.3
			local dusted = false
			Vfx.play("Land_Impact", floor)
			-- the owner's rock-and-crack impact under our dust ring, a deep boom, a kick of the camera
			ImportedFx.play("LandingImpact", CFrame.new(floor))
			Sound:Play("food_land", ball)
			Sound:Play("food_impact")
			shake = 0.9
			flowing = frames(revealStart, function(now: number)
				local since = now - flightEnd
				local lift = 0
				if since < firstHop then
					local u = since / firstHop
					lift = 3.2 * 4 * u * (1 - u)
				elseif since < firstHop + secondHop then
					if not dusted then
						dusted = true
						Vfx.play("Land_Impact", floor, { scale = 0.6, mult = 0.4 })
					end
					local u = (since - firstHop) / secondHop
					lift = 1.3 * 4 * u * (1 - u)
				end
				if since >= 0.2 and not drumroll and not deps.fast then
					drumroll = Sound:Play("reveal_drumroll")
				end
				ball.CFrame = CFrame.new(target + Vector3.new(0, lift, 0))
				pushIn(now)
				climbOdds(now)
			end)
		end
		ball:SetAttribute("Tumble", false)
		ball.CFrame = CFrame.new(target)
		if trail then
			trail.Enabled = false
		end
		if trailFx then
			trailFx.stop()
			trailFx = nil
		end

		-- SUSPENSE (not in the fast version). Owner's reviews 3 and 4: a slow villain entry, nothing
		-- hurried. 1) Through ITS OWN EYES first (at least 1.6 s): it walks up the lane toward the
		-- food on the ground, its line of dialogue typed out (Rare and up). 2) Slow shots of the
		-- black silhouette stalking on (HeroStalk, 1.5 studs/s: a footstep, dust and a bump of the
		-- camera on every step), two seconds or more each: its feet from the ground ahead, a
		-- waist-high profile, from the ground in front looking up, over its shoulder. 3) It stops at
		-- the food and PICKS IT UP (HeroPickUp: the food rides in its right hand from "Grab"), the
		-- camera low beside the food, tilting up with the hand. 4) The flash: the real hero, still
		-- holding the food (the final beat). The rarity escalation relights its outline step by step
		-- while the odds tremble and climb; the name is blank slots from the pick-up and is spelled
		-- out at the final beat. (Found in play: the walk was loaded before the silhouette was in
		-- the world, so it never played and the shape slid: it is parented first now.)
		if flowing and not deps.fast then
			if drumroll then
				Sound:Stop(drumroll, 0.6)
				drumroll = nil
			end
			wind = Sound:Play("reveal_wind", nil, { fadeIn = 1.2 })
			local shape = deps.build(result.id, nil, nil, true)
			silhouette = shape
			Viewports.blacken(shape)
			-- and flat black whatever the light does: nothing to read but a shape
			local shade = Instance.new("Highlight")
			shade.FillColor = Color3.new(0, 0, 0)
			shade.FillTransparency = 0
			shade.OutlineTransparency = 1
			shade.DepthMode = Enum.HighlightDepthMode.Occluded
			shade.Parent = shape
			local span = math.max(tFinal - revealStart, 0.3)
			local forward = -Vector3.zAxis -- up the lane toward the food and the base
			local perp = forward:Cross(Vector3.yAxis).Unit -- its right hand side
			local camSide = perp * side -- the lane-centre side: room for the camera
			-- the pick-up is filmed from its RIGHT (the food is by its right hand) unless the lane
			-- wall is too close on that side
			local pickSide = if target.X + 9 <= laneX + W.LaneWidth / 2 - 2 then perp else -perp
			-- the phases: its own eyes, the walk shots, the pick-up
			local pickupTime = math.min(PICKUP_SECONDS + HOLD_LINGER, span * 0.42)
			local povTime = math.max(POV_MIN, span * 0.24)
			local pickAt = revealStart + span - pickupTime
			local povEnd = math.min(revealStart + povTime, pickAt)
			local walkShots = math.clamp(math.floor((pickAt - povEnd) / SHOT_MIN), 0, 4)
			local shotLength = if walkShots > 0 then (pickAt - povEnd) / walkShots else 0
			local SHOTS = { "feet", "profile", "low", "shoulder" }
			-- it walks the whole way to the food, then picks it up
			-- the stride stops SETTLE_STUDS short; HeroPickUp's first step slides the root the rest
			local walkEnd = heroSpot - forward * SETTLE_STUDS
			local walkDistance =
				math.clamp((pickAt - revealStart) * STALK_SPEED * STALK_PACE, 2, 16)
			local laneEnd = gateZ(#Config.Zones + 1) - 4
			local fromSpot = walkEnd - forward * walkDistance
			if fromSpot.Z > laneEnd then
				fromSpot = Vector3.new(fromSpot.X, fromSpot.Y, math.max(laneEnd, walkEnd.Z + 1))
				walkDistance = (fromSpot - walkEnd).Magnitude
			end
			local groundSpeed = walkDistance / math.max(pickAt - revealStart, 0.2)
			-- IN THE WORLD FIRST, then the clips (a track loaded on a rig outside the DataModel never
			-- plays)
			shape:PivotTo(CFrame.lookAt(fromSpot, fromSpot + forward))
			shape.Parent = workspace
			local walkTrack = Motion.load(shape, "HeroStalk")
			-- and the pick-up is loaded on this rig now, so it starts on time later
			Motion.load(shape, "HeroPickUp")
			local studsPerSecond, playSpeed = STALK_SPEED, 1
			if not walkTrack then
				walkTrack = Motion.load(shape, "HeroWalkIn")
				studsPerSecond, playSpeed = WALKIN_SPEED * 0.7, 0.7
			end
			if not walkTrack then
				walkTrack = Motion.loadId(shape, DEFAULT_WALK)
				studsPerSecond, playSpeed = 10 * 0.32, 0.32
			end
			local authored = Motion.has("HeroStalk") or Motion.has("HeroWalkIn")
			if walkTrack then
				walkTrack.Looped = true
				walkTrack:Play(
					0.2,
					1,
					math.clamp(playSpeed * groundSpeed / math.max(studsPerSecond, 0.1), 0.3, 1.6)
				)
			end
			-- its own body is not drawn while we look through its eyes
			local parts: { BasePart } = {}
			for _, piece in shape:GetDescendants() do
				if piece:IsA("BasePart") then
					table.insert(parts, piece)
				end
			end
			local function bodyShown(on: boolean)
				for _, piece in parts do
					piece.LocalTransparencyModifier = if on then 0 else 1
				end
				shade.Enabled = on
			end
			bodyShown(false)
			local function footstep(strength: number, dust: number)
				Sound:Play(
					"footstep_heavy",
					nil,
					{ pitchVary = 0.06, speed = 0.92 - 0.03 * rarityIndex }
				)
				shake = math.max(shake, strength)
				local foot = shape:GetPivot().Position
				Vfx.play("Land_Impact", foot, { scale = dust, mult = 0.1 + 0.03 * rarityIndex })
			end
			local stepMarker = if authored and walkTrack
				then Motion.onMarker(walkTrack, "Step", function()
					footstep(0.06 + 0.03 * rarityIndex, 0.16 + 0.02 * rarityIndex)
				end)
				else nil
			local name = RevealUi.heroName(result)
			-- the letters of the name in a random order (spaces stay spaces)
			local order: { number } = {}
			for index = 1, #name do
				if name:sub(index, index) ~= " " then
					table.insert(order, math.random(1, #order + 1), index)
				end
			end
			local letters = 0
			-- the escalation: one step per rarity above Common, spread over the suspense
			local rungs = rarityIndex - 1
			local stepAt: { number } = {}
			for rung = 1, rungs do
				stepAt[rung] = revealStart
					+ span * (0.16 + 0.76 * ((rung - 0.5) / math.max(rungs, 1)) ^ 0.85)
			end
			local stepped = 0
			if rarityIndex >= 4 then
				-- Epic and up: a riser that peaks on the final beat
				task.delay(math.max(tFinal - os.clock() - 3.0, 0), function()
					if not deps.aborted() and silhouette then
						riser = Sound:Play("suspense_riser")
					end
				end)
			end
			if rarityIndex >= 5 then
				heartbeat = Sound:Play("heartbeat", nil, { fadeIn = 1.2 })
			end
			local line = RevealUi.lineFor(result)
			local said = false
			local shot = ""
			local walked = 0
			local lastAt = fromSpot
			local picking = false
			local grabbed = false
			local lifted = false
			local blanks = false
			local marks: { RBXScriptConnection } = {}
			local heroHand = shape:FindFirstChild("RightHand", true)
			-- the food shrinks to a size one hand can hold as it is picked up
			local function shrinkFood()
				local food = ball:FindFirstChildWhichIsA("Model")
				if not food then
					return
				end
				local full = food:GetScale()
				task.spawn(function()
					local began = os.clock()
					while food.Parent and os.clock() - began < 0.35 do
						food:ScaleTo(
							full * (1 - (1 - HELD_SCALE) * smooth((os.clock() - began) / 0.35))
						)
						RunService.Heartbeat:Wait()
					end
					if food.Parent then
						food:ScaleTo(full * HELD_SCALE)
					end
				end)
			end
			local function headAt(): Vector3
				local head = shape:FindFirstChild("Head")
				return if head and head:IsA("BasePart")
					then head.Position
					else shape:GetPivot().Position + Vector3.new(0, 4.6, 0)
			end
			flowing = frames(tFinal, function(now: number)
				local u = math.clamp((now - revealStart) / span, 0, 1)
				-- the walk: an even, unhurried stride all the way to the food
				if now < pickAt then
					local walk = math.clamp((now - revealStart) / (pickAt - revealStart), 0, 1)
					local at = fromSpot:Lerp(walkEnd, walk)
					shape:PivotTo(CFrame.lookAt(at, at + forward))
					walked += (at - lastAt).Magnitude
					lastAt = at
					if not stepMarker and walked >= STEP_STUDS then
						walked -= STEP_STUDS
						footstep(0.06 + 0.03 * rarityIndex, 0.16 + 0.02 * rarityIndex)
					end
				else
					-- the settling step into the bend: SETTLE_STUDS over SETTLE_SECONDS, Quad Out
					local settle = math.clamp((now - pickAt) / SETTLE_SECONDS, 0, 1)
					local at = walkEnd:Lerp(heroSpot, 1 - (1 - settle) ^ 2)
					shape:PivotTo(CFrame.lookAt(at, at + forward))
				end
				if now >= pickAt and not picking then
					picking = true
					if walkTrack then
						walkTrack:Stop(0.3)
					end
					if stepMarker then
						stepMarker:Disconnect()
						stepMarker = nil
					end
					footstep(0.18 + 0.05 * rarityIndex, 0.26 + 0.03 * rarityIndex)
					local pick = Motion.play(shape, "HeroPickUp", { fade = 0.12 })
					if pick then
						local grab = Motion.onMarker(pick, "Grab", function()
							grabbed = true
							shrinkFood()
							Sound:Play("hero_pickup", nil, { speed = 0.85 })
						end)
						local lift = Motion.onMarker(pick, "Lift", function()
							lifted = true
							Sound:Play("villain_power")
							shake = math.max(shake, 0.2 + 0.05 * rarityIndex)
							shade.OutlineTransparency = 0
						end)
						for _, mark in { grab, lift } do
							if mark then
								table.insert(marks, mark)
							end
						end
					else
						-- the stand-in until HeroPickUp is in the place: it plants and powers up, and the
						-- food comes up to its hand half way through
						Motion.play(shape, "HeroMenace", { fade = 0.25 })
						task.delay(pickupTime * 0.45, function()
							grabbed = true
							shrinkFood()
							lifted = true
						end)
					end
				end
				-- the food floats on the spot (a slow bob) until it is grabbed
				if not grabbed then
					ball.CFrame = CFrame.new(target + Vector3.new(0, 0.12 * math.sin(now * 2.4), 0))
				end
				-- the food in its right hand from the grab on
				if grabbed and heroHand and heroHand:IsA("BasePart") then
					ball.CFrame = CFrame.new((heroHand.CFrame * HELD_GRIP).Position)
				end
				-- the cameras
				local want
				if now < povEnd then
					want = "eyes"
				elseif now < pickAt and walkShots > 0 then
					want =
						SHOTS[math.clamp(math.floor((now - povEnd) / shotLength) + 1, 1, walkShots)]
				else
					want = "pickup"
				end
				local startsAt = if want == "eyes"
					then revealStart
					elseif want == "pickup" then pickAt
					else povEnd + shotLength * (math.clamp(
						math.floor((now - povEnd) / shotLength),
						0,
						walkShots - 1
					))
				local length = if want == "eyes"
					then povEnd - revealStart
					elseif want == "pickup" then tFinal - pickAt
					else shotLength
				if want ~= shot then
					if shot == "eyes" then
						bodyShown(true)
						task.delay(0.9, function()
							RevealUi.say(nil, nil, nil)
						end)
					end
					if shot ~= "" then
						Sound:Play("cam_whoosh", nil, { pitchVary = 0.05, speed = 0.8 })
						kick = -3
					end
					shot = want
				end
				local k = smooth((now - startsAt) / math.max(length, 0.01))
				local body = shape:GetPivot().Position
				local head = headAt()
				local eye: Vector3, at: Vector3, fov: number
				if shot == "eyes" then
					-- its own eyes: the lane and the food ahead, swaying slowly with its steps
					local sway = math.sin((now - revealStart) * math.pi * 1.2)
					eye = head + forward * 0.35 + Vector3.new(0, 0.15 + 0.05 * math.abs(sway), 0)
					at = target + Vector3.new(0.25 * sway, -0.3, 0)
					fov = baseFov + 2
					if not said and line and now - revealStart > 0.35 then
						said = true
						RevealUi.say("???", line, Theme.rarity(RARITY_ORDER[stepped + 1]))
					end
				elseif shot == "feet" then
					-- on the ground ahead of it, a long lens on the feet coming down, backing away
					eye = body + forward * (4.0 - 0.6 * k) + camSide * 2.6 + Vector3.new(0, 0.28, 0)
					at = body + Vector3.new(0, 0.8, 0)
					fov = baseFov - 26
				elseif shot == "profile" then
					-- waist high from the side, gliding along with it
					eye = body + camSide * (6 - 0.8 * k) + forward * 1.2 + Vector3.new(0, 2.5, 0)
					at = body + forward * 0.5 + Vector3.new(0, 2.9, 0)
					fov = baseFov - 14
				elseif shot == "low" then
					-- from the ground in front, looking up at it as it comes on
					eye = body + forward * (6.5 - 1.2 * k) + camSide * 0.8 + Vector3.new(0, 0.35, 0)
					at = head + Vector3.new(0, -0.4, 0)
					fov = baseFov - 10
				elseif shot == "shoulder" then
					-- over its shoulder: the food on the ground ahead
					eye = body
						- forward * (3.4 - 0.6 * k)
						+ camSide * 1.5
						+ Vector3.new(0, head.Y - body.Y + 0.6, 0)
					at = target + Vector3.new(0, -0.3, 0)
					fov = baseFov - 6
				else
					-- the pick-up: from its side (never from behind the food, which hid it: owner's
					-- review 5), low, the bend and the food both in frame; tilting up with the hand,
					-- then a slow push in on the shape holding its catch
					local mid = body:Lerp(target, 0.45)
					eye = mid + pickSide * (8.6 - 1.8 * k) + forward * 1.6 + Vector3.new(0, 1.1, 0)
					local held = if heroHand and heroHand:IsA("BasePart")
						then heroHand.Position
						else target
					at = if lifted then held:Lerp(head, 0.5) else mid + Vector3.new(0, 1.4, 0)
					fov = baseFov - 10 - 6 * k
					if not heartbeat and rarityIndex >= 3 then
						heartbeat = Sound:Play("heartbeat", nil, { fadeIn = 0.5 })
					end
				end
				-- the food never fills the lens: when it sits between the camera and the hero, close
				-- to the camera, the camera steps sideways (owner's review 5)
				if not grabbed and shot ~= "eyes" then
					local sight = at - eye
					local along = math.clamp((target - eye):Dot(sight.Unit), 0, sight.Magnitude)
					local miss = (eye + sight.Unit * along - target).Magnitude
					if along < 5 and miss < 2.4 then
						eye += camSide * (2.6 - miss)
					end
				end
				-- and never closer than FOOD_CLEAR to it (flat distance; not through its own eyes)
				if not grabbed and shot ~= "eyes" then
					local flat = (eye - target) * Vector3.new(1, 0, 1)
					if flat.Magnitude < FOOD_CLEAR then
						local away = if flat.Magnitude > 0.1 then flat.Unit else camSide
						eye = Vector3.new(target.X, eye.Y, target.Z) + away * FOOD_CLEAR
					end
				end
				-- the name spells itself out, a letter at a time, from the end of its own eyes to the
				-- final beat (owner's review 6); the last letter is kept for the flash
				if now >= povEnd then
					local told = math.clamp((now - povEnd) / math.max(tFinal - povEnd, 0.01), 0, 1)
					local shown = math.min(math.floor(told * #order), #order - 1)
					if not blanks or shown > letters then
						blanks = true
						letters = shown
						RevealUi.name(puzzle(name, order, shown))
						Sound:Play("letter_type", nil, { pitchVary = 0.05 })
					end
				end
				kick *= 0.9
				camera.CFrame = shaken(CFrame.lookAt(eye, at))
				camera.FieldOfView = fov + kick
				while stepped < rungs and now >= stepAt[stepped + 1] do
					stepped += 1
					local color = Theme.rarity(RARITY_ORDER[stepped + 1])
					shade.OutlineTransparency = 0
					shade.OutlineColor = color
					Sound:Play("rarity_step", nil, { speed = 0.9 + 0.09 * stepped })
					RevealUi.oddsTier(color, stepped)
					kick = -3
					shake = math.max(shake, 0.1 * stepped)
				end
				-- the rarer the catch, the darker and flatter the world grows around the shape
				local dark = u * math.clamp((rarityIndex - 1) / 6, 0.15, 1)
				grade.Brightness = -0.16 * dark
				grade.Saturation = -0.5 * dark
				grade.Contrast = 0.14 * dark
				if rarityIndex >= 5 and dark > 0.6 then
					shake = math.max(shake, 0.05 * (rarityIndex - 4))
				end
				RevealUi.oddsTension(0.12 + 0.75 * u * u)
				climbOdds(now)
			end)
			pickedUp = grabbed
			if stepMarker then
				stepMarker:Disconnect()
			end
			for _, mark in marks do
				mark:Disconnect()
			end
			if walkTrack then
				walkTrack:Stop(0)
			end
			RevealUi.say(nil, nil, nil)
			RevealUi.oddsTension(0)
		end

		-- FINAL BEAT: always reached, at its time or straight from a tap
		local skipped = not flowing
		tapsSeen = deps.taps()
		if deps.aborted() then
			return
		end
		if silhouette then
			silhouette:Destroy()
			silhouette = nil
		end
		local finalAt = os.clock()
		if drumroll then
			Sound:Stop(drumroll)
			drumroll = nil
		end
		if heartbeat then
			Sound:Stop(heartbeat, 0.3)
			heartbeat = nil
		end
		riser = nil
		if wind then
			Sound:Stop(wind, 0.4)
			wind = nil
		end
		RevealUi.endFlight()
		RevealUi.flash(0.05, 0.35)
		-- the world's colour comes back with the flash; Rare and up get an anime impact frame
		grade.Brightness, grade.Saturation, grade.Contrast = 0, 0, 0
		if rarityIndex >= 3 and not deps.fast then
			grade.Contrast = 1
			grade.Saturation = -1
			grade.TintColor = Theme.rarity(tostring(result.rarity)):Lerp(Color3.new(1, 1, 1), 0.55)
			task.delay(0.09, function()
				grade.Contrast, grade.Saturation = 0, 0
				grade.TintColor = Color3.new(1, 1, 1)
			end)
			if rarityIndex >= 4 then
				Sound:Play("impact_frame")
			end
			shake = 0.35 + 0.12 * rarityIndex
		end
		if rarityIndex >= 2 and not deps.fast then
			Sound:Play("odds_slam")
		end
		local model, scale = deps.build(result.id, result.mut, result.size)
		hero = model
		-- the whole hero in the TOP half of the frame (owner's review 4: the hero info card covers
		-- the bottom third): the camera aims low, at its shins, from in front and a little to the side
		-- the WHOLE hero, centred between the odds at the top and the info card at the bottom (owner's
		-- review 7: "it might get cut at the top"): framed from its measured height, so it fills
		-- about half the frame whatever its size, aimed a little below its middle
		local tall = math.max(model:GetExtentsSize().Y, 3)
		local view = math.rad(baseFov - 12)
		local back = tall / (0.5 * 2 * math.tan(view / 2))
		local toward = Vector3.new(-side * 0.22, 0, -1).Unit
		local finalCam = CFrame.lookAt(
			heroSpot + toward * back + Vector3.new(0, tall * 0.55, 0),
			heroSpot + Vector3.new(0, tall * 0.44, 0)
		)
		model:PivotTo(
			CFrame.lookAt(
				heroSpot,
				Vector3.new(finalCam.Position.X, heroSpot.Y, finalCam.Position.Z)
			)
		)
		model.Parent = workspace
		-- it picked the food up: it is still in its hand (and it takes a bite, Eat), else it lands
		local finalHand = model:FindFirstChild("RightHand", true)
		local holding = pickedUp and finalHand ~= nil and finalHand:IsA("BasePart")
		deps.land(model, holding)
		if FLARE_RARITIES[tostring(result.rarity)] then
			ImportedFx.play(
				"VoidFlare",
				CFrame.new(heroSpot + Vector3.new(0, 2.6 * scale, 0)),
				{ scale = scale }
			)
		end
		Vfx.play("Reveal_" .. tostring(result.rarity), heroSpot, {
			scale = scale,
			tint = Theme.rarity(result.rarity),
			mult = if deps.fast then 0.5 else 1,
		})
		local sting = STINGS[result.rarity] or STINGS.Common
		Sound:Play(sting.role, nil, {
			speed = sting.speed,
			-- slowed, the sting outlasts its measured length: fade it before
			-- Sfx's clean-up would cut it
			cap = if sting.speed then 4.6 else nil,
		})
		if result.isNew then
			task.delay(0.6, function()
				Sound:Play("index_new")
			end)
		end
		RevealUi.final(result)
		-- the bars go for the final beat: they cut the hero's head off (owner's review 5)
		RevealUi.letterbox(false, 0.45)
		camera.FieldOfView = baseFov - 12

		local holdUntil = if skipped then math.min(tEnd, finalAt + SKIP_HOLD) else tEnd
		local orbitAround = heroSpot + Vector3.new(0, 1.5 * scale, 0)
		local hinted = false
		-- trailer shot: Rare and up open on a low angle close to the hero, looking UP at it, and
		-- dolly back out to the framed shot (longer the rarer the catch)
		local dolly = if deps.fast or rarityIndex < 3 then 0 else 0.45 + 0.15 * (rarityIndex - 3)
		local chest = heroSpot + Vector3.new(0, 2.4 * scale, 0)
		local toCam = (finalCam.Position - chest) * Vector3.new(1, 0, 1)
		local lowEye = chest
			+ (if toCam.Magnitude > 0.1 then toCam.Unit else Vector3.zAxis) * (6.5 * scale)
			+ Vector3.new(0, -1.2 * scale, 0)
		local trailerCam = CFrame.lookAt(lowEye, chest + Vector3.new(0, 1.2 * scale, 0))
		frames(holdUntil - EXIT_FLASH, function(now: number)
			if holding and finalHand and finalHand:IsA("BasePart") then
				ball.CFrame = CFrame.new((finalHand.CFrame * HELD_GRIP).Position)
			end
			-- a small orbit around the hero and the food
			local turn = math.rad(-side * 14) * smooth((now - finalAt) / 1.6)
			local orbit = CFrame.new(orbitAround)
				* CFrame.Angles(0, turn, 0)
				* CFrame.new(-orbitAround)
				* finalCam
			local d = if dolly > 0 then smooth((now - finalAt) / dolly) else 1
			camera.CFrame = shaken(trailerCam:Lerp(orbit, d))
			if not hinted and now - finalAt > 0.5 then
				hinted = true
				RevealUi.skipHint(true)
			end
		end)
		if not deps.aborted() then
			-- white flash back to the plot (asked to be streamed around the player first: a lane-end
			-- reveal moved streaming away from it)
			task.spawn(function()
				pcall(function()
					player:RequestStreamAroundAsync(stand, 2)
				end)
			end)
			RevealUi.flash(EXIT_FLASH, 0.4, true)
			task.wait(EXIT_FLASH)
		end
	end)
	if not ok then
		warn(`[ThrowSequence] failed inert: {err}`)
	end

	-- whatever happened above, leave nothing behind
	if pose then
		pose.stop()
	end
	if trailFx then
		trailFx.stop()
	end
	if drumroll then
		Sound:Stop(drumroll)
	end
	if flightSound then
		Sound:Stop(flightSound, 0.2)
	end
	if heartbeat then
		Sound:Stop(heartbeat, 0.2)
	end
	if riser then
		Sound:Stop(riser, 0.2)
	end
	if wind then
		Sound:Stop(wind, 0.2)
	end
	grade:Destroy()
	Sound:SetAmbience(nil)
	ball:Destroy()
	if silhouette then
		silhouette:Destroy()
	end
	if hero then
		hero:Destroy()
	end
	camera.FieldOfView = baseFov
	RevealUi.enable(false)
	return os.clock() < serverEnd - 0.15
end

return ThrowSequence
