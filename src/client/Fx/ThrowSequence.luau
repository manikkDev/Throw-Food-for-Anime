--!strict
-- ThrowSequence - the thrower's own cinematic, start to finish. A replay of
-- a result the server has ALREADY decided and granted: nothing here changes
-- the game, so it can be skipped, shortened or interrupted freely.
--
-- THE TIMELINE (t0 = the result arrives; F = flight, P = Throw.LandPauseSeconds,
-- R = reveal, all from the server's result):
--
--   t0                 letterbox in, close side shot, wind-up (ThrowPose)
--   t0 + 0.72 * W      RELEASE: the food leaves the hand (W = wind-up, 0.5 s)
--   .. t0 + F          flight: chase camera, wider FOV, trail, the luck
--                      counter climbs to the throw's luck, the zone ribbon
--                      follows the food across each gate
--   t0 + F             LANDING: dust ring, two bounces, cut to a low camera
--                      that pushes in; the odds counter appears at "1 in 1"
--   t0 + F + P         SUSPENSE: a black silhouette walks in from the side of
--                      the lane; the odds climb (slow, then fast); the name
--                      spells itself out, letters in random order
--   end - 2.6          FINAL BEAT: flash, the real hero, burst in the rarity
--                      colour, stamp / variant / name / ribbon / income, a
--                      small orbit; "tap to continue" 0.5 s later
--   end - 0.2          white flash out
--   end                = t0 + F + P + R, less the time the result took to
--                      arrive: never later than the server's arrival time
--
-- A tap jumps to the final beat; a second tap ends it. `fast` (the Fast
-- reveal setting, Auto Throw) keeps the flight and the landing and plays a
-- 1.5 s final beat with no suspense.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local World = require(ReplicatedStorage.Shared.Core.World)
local Particles = require(script.Parent.Particles)
local ThrowPose = require(script.Parent.ThrowPose)
local RevealUi = require(script.Parent.Parent.Ui.RevealUi)
local Theme = require(script.Parent.Parent.Ui.Theme)
local Viewports = require(script.Parent.Parent.Ui.Viewports)

local T = Config.Throw
local W = Config.World
local COUNT = Config.Server.PlotCount
local player = Players.LocalPlayer

local WINDUP = 0.5 -- seconds of wind-up and release before the food flies
local FINAL_HOLD = 2.6 -- the final beat starts this long before the end: long enough to SEE the catch
local FAST_SECONDS = 1.5 -- the whole reveal in the fast version
local SKIP_HOLD = 2.5 -- how long the final beat stays after a skip
local EXIT_FLASH = 0.2
local FOOD_REST = 2 -- height of the resting food's centre over the ground
local HAND_OFFSET = CFrame.new(0, -1.1, -0.5) -- the food, in the right hand
-- The gate at the lane mouth: its beams start about 20 studs over the lane
-- ground. The food goes under them no higher than this, and the chase camera
-- stays under this until it is through.
local GATE_FOOD_Y = 12
local GATE_CAMERA_Y = 16

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
	build: (id: string, mut: string?, size: string?) -> (Model, number),
	animate: (model: Model) -> any,
}

local ThrowSequence = {}

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

-- the zone whose band of the lane holds world `z`
local function zoneNameAt(z: number): string
	local edge = W.LaneStartZ
	for index, zone in Config.Zones do
		edge += zone.LengthStuds
		if z < edge or index == #Config.Zones then
			return zone.Name
		end
	end
	return ""
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
	local windup = math.min(WINDUP, (flightEnd - t0) * 0.3)

	local laneX = World.plotX(W, deps.plot, COUNT)
	local ground = W.GroundY
	local target = Vector3.new(result.x, ground + FOOD_REST, result.z)
	-- the hero stands on the side of the food with more lane, and walks in
	-- from that side
	local side = if result.x > laneX then -1 else 1
	local heroSpot = Vector3.new(result.x + side * 4.2, ground + 0.3, result.z + 0.5)
	local walkFrom = Vector3.new(
		math.clamp(result.x + side * 22, laneX - W.LaneWidth / 2 + 3, laneX + W.LaneWidth / 2 - 3),
		heroSpot.Y,
		result.z + 2.5
	)
	local farCam = CFrame.lookAt(target + Vector3.new(-side * 4, 6, -30), target)
	local lowCam = CFrame.lookAt(
		target + Vector3.new(-side * 2.6, 1.3 - FOOD_REST + 1.2, -9.5),
		target + Vector3.new(side * 2.2, 1, 0)
	)

	local baseFov = camera.FieldOfView
	local ball = deps.makeFood(deps.foodId)
	local trail = ball:FindFirstChildOfClass("Trail")
	if trail then
		trail.Enabled = false
	end
	local pose: ThrowPose.Handle? = nil
	local silhouette: Model? = nil
	local hero: Model? = nil
	local tapsSeen = deps.taps()

	-- run `step(now)` every frame until `untilTime`; false if a tap cut it short
	local function frames(untilTime: number, step: (now: number) -> ()): boolean
		while true do
			if deps.aborted() or deps.taps() > tapsSeen then
				return false
			end
			local now = os.clock()
			step(math.min(now, untilTime))
			if now >= untilTime then
				return true
			end
			RunService.RenderStepped:Wait()
		end
	end

	local lastPop = 0
	local function climbOdds(now: number)
		-- 1 -> oneInN on a curve that crawls, then runs: the exponent of the
		-- real odds grows with time, so each step is bigger than the last
		local u = math.clamp((now - flightEnd) / math.max(tFinal - flightEnd, 0.01), 0, 1)
		local value = math.max(1, math.floor(math.max(result.oneInN, 1) ^ (u ^ 1.7)))
		local canPop = now - lastPop > 0.12
		if RevealUi.odds(value, canPop) and canPop then
			lastPop = now
		end
	end
	local function pushIn(now: number)
		local u = smooth((now - flightEnd) / math.max(tFinal - flightEnd, 0.01))
		camera.CFrame = farCam:Lerp(lowCam, u)
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
		local sideCam =
			CFrame.lookAt(stand + Vector3.new(-6, 1.6, 6.5), stand + Vector3.new(0.5, 0.8, 1))
		local thrown = ThrowPose.start(character, windup)
		pose = thrown
		local hand = thrown.hand
		local inHand = stand + Vector3.new(1, 1.5, 1)
		local flowing = frames(thrown.releaseAt, function(now: number)
			ball.CFrame = if hand then hand.CFrame * HAND_OFFSET else CFrame.new(inHand)
			local u = smooth((now - t0) / math.max(thrown.releaseAt - t0, 0.01))
			camera.CFrame = sideCam * CFrame.new(0, 0, -1.5 * u)
		end)

		-- FLIGHT: chase the food down the lane
		local released = os.clock()
		local from = ball.Position
		if trail then
			trail.Enabled = true
		end
		if flowing then
			local cut = camera.CFrame
			flowing = frames(flightEnd, function(now: number)
				local u = math.clamp((now - released) / math.max(flightEnd - released, 0.01), 0, 1)
				local position = ThrowSequence.arcPoint(from, target, u)
				ball.Position = position
				-- behind and above the food; held under the gate's beams until
				-- the camera itself is through the gate, then let up again
				local eye = position + Vector3.new(0, 7, -15)
				local through = smooth((eye.Z - (W.LaneStartZ + 8)) / 24)
				local capped = math.min(eye.Y, ground + GATE_CAMERA_Y)
				eye = Vector3.new(eye.X, capped + (eye.Y - capped) * through, eye.Z)
				local chase = CFrame.lookAt(eye, position + Vector3.new(0, -1, 12))
				local blend = smooth((now - released) / 0.35)
				camera.CFrame = cut:Lerp(chase, blend)
				camera.FieldOfView = baseFov + 12 * smooth((now - released) / 0.6)
				RevealUi.flight(1 + (result.luck - 1) * smooth(u), zoneNameAt(position.Z))
			end)
		end
		thrown.stop()
		RevealUi.endFlight()

		-- LANDING: dust, two bounces, the low camera starts to push in
		if flowing then
			local floor = Vector3.new(target.X, ground + 0.15, target.Z)
			local firstHop = T.LandPauseSeconds * 0.45
			local secondHop = T.LandPauseSeconds * 0.3
			local dusted = false
			Particles.dust(floor, 1)
			flowing = frames(revealStart, function(now: number)
				local since = now - flightEnd
				local lift = 0
				if since < firstHop then
					local u = since / firstHop
					lift = 3.2 * 4 * u * (1 - u)
				elseif since < firstHop + secondHop then
					if not dusted then
						dusted = true
						Particles.dust(floor, 0.6)
					end
					local u = (since - firstHop) / secondHop
					lift = 1.3 * 4 * u * (1 - u)
				end
				ball.Position = target + Vector3.new(0, lift, 0)
				pushIn(now)
				climbOdds(now)
			end)
		end
		ball.Position = target
		if trail then
			trail.Enabled = false
		end

		-- SUSPENSE: who is it? (not in the fast version)
		if flowing and not deps.fast then
			local shape = deps.build(result.id, nil, nil)
			silhouette = shape
			Viewports.blacken(shape)
			-- and flat black whatever the light does: nothing to read but a shape
			local shade = Instance.new("Highlight")
			shade.FillColor = Color3.new(0, 0, 0)
			shade.FillTransparency = 0
			shade.OutlineTransparency = 1
			shade.DepthMode = Enum.HighlightDepthMode.Occluded
			shade.Parent = shape
			shape:PivotTo(CFrame.new(walkFrom))
			shape.Parent = workspace
			deps.animate(shape)
			if shape.PrimaryPart then
				Particles.sparkles(shape.PrimaryPart)
			end
			local name = RevealUi.heroName(result)
			local order: { number } = {}
			for index = 1, #name do
				if name:sub(index, index) ~= " " then
					table.insert(order, math.random(1, #order + 1), index)
				end
			end
			local walkEnd = revealStart + math.min((tFinal - revealStart) * 0.6, 2.4)
			local faceCamera = CFrame.lookAt(
				heroSpot,
				Vector3.new(lowCam.Position.X, heroSpot.Y, lowCam.Position.Z)
			)
			flowing = frames(tFinal, function(now: number)
				local walk =
					math.clamp((now - revealStart) / math.max(walkEnd - revealStart, 0.01), 0, 1)
				if walk < 1 then
					local at = walkFrom:Lerp(heroSpot, smooth(walk))
					local hop = math.abs(math.sin((now - revealStart) * 9)) * 0.35
					shape:PivotTo(CFrame.lookAt(at, heroSpot) + Vector3.new(0, hop, 0))
				else
					shape:PivotTo(faceCamera)
				end
				local told = (now - revealStart) / math.max(tFinal - revealStart, 0.01)
				-- the last letter is kept for the final beat
				RevealUi.name(puzzle(name, order, math.min(math.floor(told * #order), #order - 1)))
				pushIn(now)
				climbOdds(now)
			end)
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
		RevealUi.endFlight()
		RevealUi.flash(0.05, 0.35)
		local model, scale = deps.build(result.id, result.mut, result.size)
		hero = model
		local finalCam = CFrame.lookAt(
			-- far enough back that the WHOLE hero stands between the odds (top) and
			-- the name (bottom): the catch is the star of this shot
			target + Vector3.new(-side * 2.6, 1.2 + (scale - 1) * 2.5, -13.5 - (scale - 1) * 11),
			Vector3.new(heroSpot.X - side * 1.2, ground + 3.7 * scale, heroSpot.Z)
		)
		model:PivotTo(
			CFrame.lookAt(
				heroSpot,
				Vector3.new(finalCam.Position.X, heroSpot.Y, finalCam.Position.Z)
			)
		)
		model.Parent = workspace
		deps.animate(model)
		Particles.burst(
			heroSpot + Vector3.new(0, 3 * scale, 0),
			Theme.rarity(result.rarity),
			if deps.fast then 40 else 80
		)
		RevealUi.final(result)
		camera.FieldOfView = baseFov - 12

		local holdUntil = if skipped then math.min(tEnd, finalAt + SKIP_HOLD) else tEnd
		local orbitAround = Vector3.new(heroSpot.X - side * 1.2, ground + 2, heroSpot.Z)
		local hinted = false
		frames(holdUntil - EXIT_FLASH, function(now: number)
			-- a small orbit around the hero and the food
			local turn = math.rad(-side * 14) * smooth((now - finalAt) / 1.6)
			camera.CFrame = CFrame.new(orbitAround)
				* CFrame.Angles(0, turn, 0)
				* CFrame.new(-orbitAround)
				* finalCam
			if not hinted and now - finalAt > 0.5 then
				hinted = true
				RevealUi.skipHint(true)
			end
		end)
		if not deps.aborted() then
			-- white flash back to the plot
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
