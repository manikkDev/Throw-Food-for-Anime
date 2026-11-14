--!strict
-- ThrowController - the core verb on the client: charge, release, watch.
--
-- The client only sends (charge, useLuckyThrow). Everything it then shows
-- (flight, landing, reveal) is a replay of a result the server has ALREADY
-- decided and granted, so skipping, lagging or leaving loses nothing.
--
-- The charge bar swings 0 -> 1 -> 0. Marks on it show the smallest charge that
-- reaches each unlocked zone, so releasing early is how a player farms an
-- earlier zone on purpose; the top slice is the perfect window (+luck).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local Throw = require(ReplicatedStorage.Shared.Core.Throw)
local World = require(ReplicatedStorage.Shared.Core.World)
local Make = require(script.Parent.Parent.Ui.Make)

local MAPS = Lookup.of(Config)
local T = Config.Throw
local W = Config.World
local COUNT = Config.Server.PlotCount
local player = Players.LocalPlayer

local FLAVOR_COLORS: { [string]: Color3 } = {
	Savory = Color3.fromRGB(240, 200, 120),
	Sweet = Color3.fromRGB(255, 150, 200),
	Spicy = Color3.fromRGB(255, 90, 60),
	Seafood = Color3.fromRGB(110, 200, 255),
}

local ThrowController = Knit.CreateController({
	Name = "ThrowController",
	_busy = false,
	_charging = false,
	_chargeStart = 0,
	_useLucky = false,
	_auto = false,
	_skip = false,
	_onPad = false,
	_sentAt = 0,
	_playing = false,
	_lastZone = nil :: number?,
})

local function rootPart(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

function ThrowController:_charge(): number
	local phase = (os.clock() - self._chargeStart) / T.ChargeSeconds
	local wave = 1 - math.abs((phase % 2) - 1) -- 0 -> 1 -> 0
	return T.MinCharge + (1 - T.MinCharge) * wave
end

function ThrowController:_canThrow(): boolean
	-- never ask before the server cooldown has passed: a refused throw gets
	-- no answer, and the pad would then sit locked waiting for one
	return self._onPad
		and not self._busy
		and self._state.State ~= nil
		and os.clock() - self._sentAt >= T.ServerCooldownSeconds + 0.1
end

function ThrowController:_begin()
	if self._charging or not self:_canThrow() then
		return
	end
	self._charging = true
	self._chargeStart = os.clock()
end

function ThrowController:_send(charge: number)
	self._busy = true
	self._sentAt = os.clock()
	self._request:FireServer(charge, self._useLucky)
	-- a refused throw sends nothing back: free the pad again
	task.delay(2.5, function()
		if self._busy and os.clock() - self._sentAt >= 2.4 and not self._playing then
			self._busy = false
		end
	end)
end

function ThrowController:_release()
	if not self._charging then
		return
	end
	self._charging = false
	self:_send(self:_charge())
end

-- ------------------------------------------------------------------- ui --

function ThrowController:_buildUi()
	local gui = Make.screen("ThrowUi", 20)
	local root = Make.frame(gui, {
		Name = "Root",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(520, 190),
		Visible = false,
	})
	self._zoneLabel = Make.label(root, "", {
		Name = "ZonePreviewLabel",
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 0),
	})
	local bar = Make.frame(root, {
		Name = "ChargeBar",
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.fromOffset(0, 40),
		BackgroundColor3 = Make.INK,
	})
	Make.corner(bar, 10)
	Make.stroke(bar, 3, Color3.new(1, 1, 1))
	local perfect = Make.frame(bar, {
		Name = "PerfectWindow",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(T.PerfectWindow / (1 - T.MinCharge), 1),
		BackgroundColor3 = Make.BUY,
		BackgroundTransparency = 0.35,
	})
	Make.corner(perfect, 10)
	self._fill = Make.frame(bar, {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Make.GOOD,
	})
	Make.corner(self._fill, 10)
	self._marks = Make.frame(bar, {
		Name = "ZoneMarks",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	})
	self._throwButton = Make.button(root, "HOLD TO THROW", Make.GOOD, {
		Name = "ThrowButton",
		Size = UDim2.fromOffset(260, 84),
		Position = UDim2.new(0.5, -130, 0, 96),
	})
	self._luckyButton = Make.button(root, "LUCKY x0", Make.INFO, {
		Name = "LuckyThrowToggle",
		Size = UDim2.fromOffset(118, 56),
		Position = UDim2.fromOffset(0, 110),
	})
	self._autoButton = Make.button(root, "AUTO OFF", Make.PANEL, {
		Name = "AutoToggle",
		Size = UDim2.fromOffset(118, 56),
		Position = UDim2.new(1, -118, 0, 110),
		Visible = false,
	})
	gui.Parent = player:WaitForChild("PlayerGui")
	self._root = root

	self._throwButton.MouseButton1Down:Connect(function()
		self:_begin()
	end)
	self._throwButton.MouseButton1Up:Connect(function()
		self:_release()
	end)
	self._throwButton.MouseLeave:Connect(function()
		self:_release()
	end)
	self._luckyButton.Activated:Connect(function()
		self._useLucky = not self._useLucky
		self:_refreshUi()
	end)
	self._autoButton.Activated:Connect(function()
		self._auto = not self._auto
		self:_refreshUi()
	end)
end

-- zone marks and labels depend on power and food, so they follow the state
function ThrowController:_refreshUi()
	local state = self._state.State
	if not state or not self._root then
		return
	end
	local food = MAPS.food[state.food]
	local throws = state.luckyThrows or 0
	if throws <= 0 then
		self._useLucky = false
	end
	self._luckyButton.Text = `LUCKY x{throws}`
	self._luckyButton.BackgroundColor3 = if self._useLucky then Make.BUY else Make.INFO
	self._luckyButton.Visible = throws > 0
	self._autoButton.Visible = state.passes ~= nil and state.passes.AutoThrow == true
	self._autoButton.Text = if self._auto then "AUTO ON" else "AUTO OFF"
	self._autoButton.BackgroundColor3 = if self._auto then Make.GOOD else Make.PANEL

	self._marks:ClearAllChildren()
	for index, zone in Config.Zones do
		local need = Throw.chargeForZone(T, Config.Zones, state.power, food.PowerMult, index)
		if need and index > 1 then
			local at = (need - T.MinCharge) / (1 - T.MinCharge)
			local mark = Make.frame(self._marks, {
				Name = "Mark" .. index,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(at, 0),
				Size = UDim2.new(0, 4, 1, 0),
				BackgroundColor3 = Color3.new(1, 1, 1),
			})
			Make.label(mark, tostring(index), {
				Size = UDim2.fromOffset(26, 22),
				Position = UDim2.fromOffset(-11, -24),
			})
			mark:SetAttribute("Zone", zone.Id)
		end
	end
end

function ThrowController:_tickUi()
	local root = self._root
	if not root then
		return
	end
	root.Visible = self._onPad and not self._busy
	local state = self._state.State
	if not root.Visible or not state then
		return
	end
	local charge = if self._charging then self:_charge() else T.MinCharge
	local shown = (charge - T.MinCharge) / (1 - T.MinCharge)
	self._fill.Size = UDim2.fromScale(shown, 1)
	self._fill.BackgroundColor3 = if Throw.isPerfect(T, charge) then Make.BUY else Make.GOOD
	local food = MAPS.food[state.food]
	local full = if self._charging then charge else 1
	local eff = Throw.effectivePower(state.power, food.PowerMult, full)
	local zone = Config.Zones[Throw.zoneIndex(Config.Zones, eff)]
	self._zoneLabel.Text = if self._charging
		then `Lands in: {zone.Name}`
		else `Hold to charge, release near the top  (best: {zone.Name})`
end

-- -------------------------------------------------------------- sequence --

local function makeFood(foodId: string): Part
	local food = MAPS.food[foodId]
	local ball = Instance.new("Part")
	ball.Name = "ThrownFood"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(1.8, 1.8, 1.8)
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.Material = Enum.Material.Neon
	ball.Color = if food then FLAVOR_COLORS[food.Flavor] else Color3.new(1, 1, 1)
	local trail = Instance.new("Trail")
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.7, 0)
	a1.Position = Vector3.new(0, -0.7, 0)
	a0.Parent = ball
	a1.Parent = ball
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.4
	trail.Color = ColorSequence.new(ball.Color)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Parent = ball
	ball.Parent = workspace
	return ball
end

local function arcPoint(from: Vector3, to: Vector3, t: number): Vector3
	local height = math.clamp((to - from).Magnitude * 0.14, 14, 70)
	return from:Lerp(to, t) + Vector3.new(0, height * 4 * t * (1 - t), 0)
end

-- waits `seconds`, ending early when the player skips; returns true if skipped
function ThrowController:_hold(seconds: number): boolean
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		if self._skip then
			return true
		end
		RunService.RenderStepped:Wait()
	end
	return false
end

function ThrowController:_play(result: any)
	self._playing = true
	self._busy = true
	self._skip = false
	self._hud:HoldIncome(true)
	local camera = workspace.CurrentCamera
	local root = rootPart()
	local from = if root
		then root.Position + Vector3.new(0, 2.5, 3)
		else Vector3.new(result.x, 4, W.ThrowPadZ)
	local target = Vector3.new(result.x, W.GroundY + 1, result.z)
	local state = self._state.State
	local ball = makeFood(if state then state.food else "")
	local hero: Model? = nil

	local ok, err = pcall(function()
		task.spawn(function()
			pcall(function()
				player:RequestStreamAroundAsync(target, 4)
			end)
		end)
		camera.CameraType = Enum.CameraType.Scriptable
		-- flight: the camera chases the food down the lane
		local t0 = os.clock()
		while true do
			local t = math.clamp((os.clock() - t0) / result.flight, 0, 1)
			local position = arcPoint(from, target, t)
			ball.Position = position
			local behind = position + Vector3.new(0, 7, -16)
			camera.CFrame = CFrame.lookAt(behind, position + Vector3.new(0, 0, 10))
			if t >= 1 or self._skip then
				break
			end
			RunService.RenderStepped:Wait()
		end
		ball.Position = target
		self._hud:Flash(result.perfect, result.lucky)
		local skipped = self._skip or self:_hold(T.LandPauseSeconds)

		-- reveal: the hero appears where the food landed, facing the camera
		local model, scale = self._heroes:Build(result.id, result.mut, result.size)
		hero = model
		model:PivotTo(CFrame.new(result.x, W.GroundY + 0.2, result.z))
		model.Parent = workspace
		self._heroes:Animate(model)
		local eye = target + Vector3.new(5 * scale, 4 * scale + 2, -(11 * scale + 4))
		camera.CFrame = CFrame.lookAt(eye, target + Vector3.new(0, 3 * scale, 0))
		self._hud:Reveal(result)
		if not skipped then
			skipped = self:_hold(result.reveal)
		end
		if skipped and result.uid then
			self._heroes:ArriveNow(result.uid)
		end
	end)
	if not ok then
		warn(`[ThrowController] throw sequence failed inert: {err}`)
	end
	-- always give the camera and the pad back, whatever happened above
	self._hud:HideReveal()
	self._hud:HoldIncome(false)
	ball:Destroy()
	if hero then
		hero:Destroy()
	end
	camera.CameraType = Enum.CameraType.Custom
	self._playing = false
	self._busy = false
	self._lastZone = result.zone
end

-- another player's throw: the food flies and a label pops, no camera
function ThrowController:_watch(seen: any)
	local x, z = World.throwPad(W, seen.plot, COUNT)
	local from = Vector3.new(x, W.GroundY + 5, z + 3)
	local target = Vector3.new(seen.x, W.GroundY + 1, seen.z)
	local ball = makeFood(seen.food)
	task.spawn(function()
		local t0 = os.clock()
		while ball.Parent do
			local t = math.clamp((os.clock() - t0) / seen.flight, 0, 1)
			ball.Position = arcPoint(from, target, t)
			if t >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
		task.wait(seen.reveal + T.LandPauseSeconds)
		ball:Destroy()
	end)
end

function ThrowController:KnitStart()
	self._state = Knit.GetController("StateController")
	self._heroes = Knit.GetController("HeroController")
	self._hud = Knit.GetController("HudController")
	local request = Net.client("ThrowRequest")
	local result = Net.client("ThrowResult")
	local seen = Net.client("ThrowSeen")
	if not (request and result and seen) then
		warn("[ThrowController] throw remotes missing: throwing is disabled")
		return
	end
	self._request = request
	self:_buildUi()

	result.OnClientEvent:Connect(function(payload: any)
		-- a new result while the last one is still on screen (Auto Throw, or a
		-- fast hand): cut the old sequence short, never run two cameras at once
		while self._playing do
			self._skip = true
			task.wait()
		end
		self:_play(payload)
	end)
	seen.OnClientEvent:Connect(function(payload: any)
		local ok, err = pcall(function()
			self:_watch(payload)
		end)
		if not ok then
			warn(`[ThrowController] watch failed inert: {err}`)
		end
	end)
	self._state:Observe(function()
		self:_refreshUi()
	end)
	self._state.Ticked:Connect(function()
		-- power moves the zone marks while training
		if self._onPad and not self._charging then
			self:_refreshUi()
		end
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if self._playing then
			-- any press after a short grace skips the flight and the reveal
			local pressed = input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
				or input.KeyCode == Enum.KeyCode.Space
				or input.KeyCode == Enum.KeyCode.ButtonA
			if pressed and os.clock() - self._sentAt > T.RevealSkipSeconds then
				self._skip = true
			end
			return
		end
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.T or input.KeyCode == Enum.KeyCode.ButtonX then
			self:_begin()
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.T or input.KeyCode == Enum.KeyCode.ButtonX then
			self:_release()
		end
	end)

	local lastAuto = 0
	RunService.RenderStepped:Connect(function()
		local state = self._state.State
		local root = rootPart()
		if state and state.plot and root then
			local x, z = World.throwPad(W, state.plot, COUNT)
			local distance = World.distance(root.Position.X, root.Position.Z, x, z)
			self._onPad = distance <= W.ThrowPadRadius + 3
		else
			self._onPad = false
		end
		if not self._onPad and self._charging then
			self._charging = false
		end
		self:_tickUi()
		-- Auto Throw pass: rethrow just below the perfect window, so throwing
		-- by hand is still worth a little more
		local now = os.clock()
		if self._auto and self:_canThrow() and not self._charging and now - lastAuto > 0.6 then
			if state and state.passes and state.passes.AutoThrow then
				lastAuto = now
				self:_send(1 - T.PerfectWindow - 0.01)
			end
		end
	end)
end

--- True while the player is standing on their own throw pad.
function ThrowController:OnPad(): boolean
	return self._onPad
end

--- The zone index the player's last throw landed in (for the tutorial).
function ThrowController:LastZone(): number?
	return self._lastZone
end

return ThrowController
