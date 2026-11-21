--!strict
-- ThrowController - the core verb on the client: stand on the pad, tap, watch.
--
-- The client only sends (charge, useLuckyThrow). Everything it then shows
-- (wind-up, flight, landing, reveal: Fx/ThrowSequence) is a replay of a result
-- the server has ALREADY decided and granted, so skipping, lagging or leaving
-- loses nothing.
--
-- THROW MODE. While the player stands on their own pad (and no page is open)
-- the camera settles behind the shoulder looking down the lane, the HUD steps
-- aside, and the meter's marker slides up and down by itself, one sweep every
-- Throw.ChargeSeconds. ONE tap (the THROW button, Space, T, gamepad X or R2)
-- throws with the charge the marker shows at that instant. Bands on the meter
-- mark the height that reaches each zone, so tapping low is how a player farms
-- an earlier zone on purpose; the top slice is the perfect band (+luck).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local Throw = require(ReplicatedStorage.Shared.Core.Throw)
local World = require(ReplicatedStorage.Shared.Core.World)
local Motion = require(script.Parent.Parent.Fx.Motion)
local ThrowSequence = require(script.Parent.Parent.Fx.ThrowSequence)
local Vfx = require(script.Parent.Parent.Fx.Vfx)
local Screens = require(script.Parent.Parent.Ui.Screens)
local Theme = require(script.Parent.Parent.Ui.Theme)
local Sound = require(script.Parent.SoundController)

local MAPS = Lookup.of(Config)
-- zone id -> its index down the lane
local ZONE_INDEX: { [string]: number } = {}
for index, zone in Config.Zones do
	ZONE_INDEX[zone.Id] = index
end
-- a catch of this rarity order or better makes the player celebrate
local CELEBRATE_ORDER = Config.Rarities.Rare.Order
-- each region's colour on its banner as the food crosses into it
local ZONE_COLORS: { [number]: Color3 } = {
	Color3.fromHex("FF8FC8"), -- Sakura Schoolyard
	Color3.fromHex("3FB6FF"), -- Pirate Harbor
	Color3.fromHex("FF9A3C"), -- Ninja Village
	Color3.fromHex("E8434F"), -- Samurai Castle
	Color3.fromHex("FFD23F"), -- Hero City
	Color3.fromHex("B266FF"), -- Realm of Legends
}
local T = Config.Throw
local W = Config.World
local COUNT = Config.Server.PlotCount
local player = Players.LocalPlayer

local TAP_ACTION = "ThrowTap"
local TAP_KEYS = {
	Enum.KeyCode.Space,
	Enum.KeyCode.T,
	Enum.KeyCode.ButtonX,
	Enum.KeyCode.ButtonR2,
}
-- how long the meter stays up after the tap, into the wind-up, so the
-- player sees where the marker stopped and the "PERFECT!"
local METER_LINGER = 0.4

local ThrowController = Knit.CreateController({
	Name = "ThrowController",
	_busy = false,
	_useLucky = false,
	_auto = false,
	_autoThrown = false,
	_onPad = false,
	-- the throw spot holds the player (owner's review 2026-11-15): stepping on locks them to the
	-- pad centre facing the lane; only the Exit button (or Backspace) lets them off
	_locked = false,
	_lockedAt = 0,
	_carryToastAt = 0,
	_leaving = false,
	_padRemote = nil :: RemoteEvent?,
	_sentAt = 0,
	_playing = false,
	_playStart = 0,
	_abort = false,
	_taps = 0,
	_tapAt = 0,
	_lastZone = nil :: number?,
	_mode = "normal",
	_sweepStart = 0,
	_frozen = nil :: number?,
	_bonusText = "",
	_zoneText = "",
	_zoneBands = {} :: { [number]: GuiObject },
	_zoneColors = {} :: { [number]: Color3 },
	_bestZone = 0,
	_sweep = -1,
	_charge = nil :: Sound?,
	_luckyFx = nil :: Vfx.Handle?,
})

local function rootPart(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Throw mode's camera: close behind and just above the right shoulder,
-- looking straight down the lane and a touch downward. That puts the
-- character, from the knees up, in the left-centre third of the screen with
-- its head just under the middle, and leaves the gate and the corridor the
-- rest (the meter sits to the right of the character). Taken from where the
-- character really stands (the pad is a raised stage), never from a pad
-- height. Facing down the lane (+Z) the right shoulder is on -X.
local SHOULDER_EYE = Vector3.new(-2.6, 4.4, -8.5) -- from the root: right, up, behind
local SHOULDER_AIM = Vector3.new(0, -3.4, 40) -- from the eye: down the lane
local function shoulderCamera(root: BasePart): CFrame
	local eye = root.Position + SHOULDER_EYE
	return CFrame.lookAt(eye, eye + SHOULDER_AIM)
end

-- where the marker is: 0 (bottom of the meter) .. 1 (top), 0 -> 1 -> 0
function ThrowController:_value(): number
	local frozen = self._frozen
	if frozen then
		return frozen
	end
	local phase = (os.clock() - self._sweepStart) / T.ChargeSeconds
	return 1 - math.abs((phase % 2) - 1)
end

-- the charge a marker height stands for: never below MinCharge
local function chargeOf(value: number): number
	return math.clamp(T.MinCharge + (1 - T.MinCharge) * value, T.MinCharge, 1)
end

function ThrowController:_canThrow(): boolean
	-- never ask before the server cooldown has passed: a refused throw gets
	-- no answer, and the pad would then sit locked waiting for one
	return self._mode == "throw"
		and not self._busy
		and player:GetAttribute("Carrying") == nil
		and self._state.State ~= nil
		and os.clock() - self._sentAt >= T.ServerCooldownSeconds + 0.1
end

function ThrowController:_send(value: number, auto: boolean)
	local charge = chargeOf(value)
	self._busy = true
	self._frozen = value
	self._autoThrown = auto
	self._sentAt = os.clock()
	self._request:FireServer(charge, self._useLucky, auto)
	if self._charge then
		Sound:Stop(self._charge, 0.1)
		self._charge = nil
	end
	if self._tapLabel then
		self._tapLabel.Text = if Throw.isPerfect(T, charge) then "PERFECT!" else "NICE THROW!"
	end
	-- a refused throw sends nothing back: free the pad again
	task.delay(2.5, function()
		if self._busy and os.clock() - self._sentAt >= 2.4 and not self._playing then
			self._busy = false
			self:_rearm()
		end
	end)
end

-- the marker slides again
function ThrowController:_rearm()
	self._frozen = nil
	self._sweepStart = os.clock()
	self._sweep = -1
	if self._tapLabel then
		self._tapLabel.Text = "TAP TO THROW!"
	end
end

-- One press of the throw input: a throw on the pad, a skip during the
-- sequence (the first jumps to the final beat, the second ends it).
function ThrowController:_tap()
	local now = os.clock()
	if self._playing then
		if now - self._playStart > T.RevealSkipSeconds and now - self._tapAt > 0.2 then
			self._tapAt = now
			self._taps += 1
		end
	elseif self:_canThrow() then
		self._tapAt = now
		self:_send(self:_value(), false)
	end
end

-- ------------------------------------------------------------------- ui --
-- The ThrowMeter screen (src/ui): a vertical meter with a band per reachable
-- zone and the perfect band on top, the marker and the bonus it is worth, the
-- Lucky Throw toggle and (with the pass) AUTO.

-- the wrapper that holds a toggle in its layout, or the toggle itself
local function cellOf(gui: Instance, name: string): GuiObject
	local cell = gui:FindFirstChild(name .. "Cell", true)
	if cell and cell:IsA("GuiObject") then
		return cell
	end
	return Screens.button(gui, name)
end

function ThrowController:_bindUi()
	local gui = Screens.get("ThrowMeter")
	gui.Enabled = false
	self._gui = gui
	local bar = Screens.frame(gui, "MeterBar")
	self._marker = Screens.frame(bar, "MeterMarker")
	self._bonusLabel = Screens.label(self._marker, "BonusLabel")
	self._bands = Screens.frame(gui, "ZoneBands")
	self._zoneLabel = Screens.label(gui, "ZonePreviewLabel")
	self._tapLabel = Screens.label(gui, "TapLabel")
	self._foodIcon = Screens.image(gui, "FoodIcon")
	self._luckyCell = cellOf(gui, "LuckyThrowToggle")
	self._luckyButton = Screens.button(gui, "LuckyThrowToggle")
	self._luckyCount = Screens.label(gui, "LuckyCount")
	self._autoCell = cellOf(gui, "AutoToggle")
	self._autoButton = Screens.button(gui, "AutoToggle")
	self._autoState = Screens.label(gui, "AutoState")
	self._autoState.Text = ""
	self._bonusLabel.Text = ""
	self._zoneLabel.Text = ""
	self._luckyCount.Text = ""
	self._tapLabel.Text = "TAP TO THROW!"
	local exit = gui:FindFirstChild("ExitButton", true)
	if exit and exit:IsA("GuiButton") then
		exit.Activated:Connect(function()
			self:_exitPad()
		end)
	end
	self._luckyCell.Visible = false
	self._autoCell.Visible = false

	-- the perfect band is the top slice of the meter, as tall as the config says
	local band = Screens.frame(gui, "PerfectBand")
	band.Size =
		UDim2.new(band.Size.X.Scale, band.Size.X.Offset, T.PerfectWindow / (1 - T.MinCharge), 0)

	-- a zone's key colour is the one its tab carries in the Hero Index
	local index = Screens.get("HeroIndex")
	for zone in Config.Zones do
		local tab = index:FindFirstChild("ZoneTab" .. zone, true)
		local fill = tab and tab:FindFirstChild("Fill", true)
		self._zoneColors[zone] = if fill and fill:IsA("GuiObject")
			then fill.BackgroundColor3
			else Theme.WHITE
	end

	-- The tap is read on the way DOWN: the charge is the marker at that
	-- instant. ThrowButton is the big invisible tap area, ThrowButtonFace the
	-- button the player sees; both throw.
	local tapArea = Screens.button(gui, "ThrowButton")
	tapArea.MouseButton1Down:Connect(function()
		self:_tap()
	end)
	Screens.button(gui, "ThrowButtonFace").MouseButton1Down:Connect(function()
		self:_tap()
	end)
	-- The tap area reaches the real screen edges (the canvas is 16:9 and
	-- centred, a window can be wider). On a phone its left 40% is left to
	-- the thumbstick, or the player could never walk off the pad.
	local authoredWidth = tapArea.Size.X.Offset
	local function layoutTapArea(extra: number)
		local full = authoredWidth + extra
		local keep = if UserInputService.TouchEnabled then full * 0.4 else 0
		tapArea.Position =
			UDim2.new(0, keep - extra / 2, tapArea.Position.Y.Scale, tapArea.Position.Y.Offset)
		tapArea.Size = UDim2.new(0, full - keep, tapArea.Size.Y.Scale, tapArea.Size.Y.Offset)
	end
	layoutTapArea(Screens.extraWidth())
	Screens.Fitted:Connect(layoutTapArea)

	-- "TAP TO THROW!" belongs under the meter, clear of the character on the
	-- left: centre it on the meter instead of on the screen
	local tapLabel = self._tapLabel
	tapLabel.Position = UDim2.new(
		bar.Position.X.Scale,
		bar.Position.X.Offset + (0.5 - bar.AnchorPoint.X) * bar.Size.X.Offset,
		tapLabel.Position.Y.Scale,
		tapLabel.Position.Y.Offset
	)
	self._luckyButton.Activated:Connect(function()
		self._useLucky = not self._useLucky
		self:_refreshUi()
	end)
	self._autoButton.Activated:Connect(function()
		self._auto = not self._auto
		self:_refreshUi()
	end)
end

-- the toggles, the food and the zone bands follow the state (power and food
-- move the bands)
function ThrowController:_refreshUi()
	local state = self._state.State
	if not state or not self._gui then
		return
	end
	local food = MAPS.food[state.food]
	local throws = state.luckyThrows or 0
	if throws <= 0 then
		self._useLucky = false
	end
	self._luckyCount.Text = `x{throws}`
	Screens.setButtonState(self._luckyButton, if self._useLucky then "gold" else "shipped")
	self._luckyCell.Visible = throws > 0
	self._autoCell.Visible = state.passes ~= nil and state.passes.AutoThrow == true
	Screens.setButtonState(self._autoButton, if self._auto then "afford" else "shipped")
	self._autoState.Text = if self._auto then "ON" else "OFF"
	if self._gui:GetAttribute("FoodShown") ~= state.food then
		self._gui:SetAttribute("FoodShown", state.food)
		Screens.setIcon(self._foodIcon, "Food_" .. state.food)
	end

	-- one band per zone, made the first time the zone is reachable and then
	-- only moved: its height is the smallest marker value that reaches it. Zones already reached
	-- at the minimum charge all sit at the bottom: only the furthest of them shows (their names
	-- stacked on one another under the meter, found in the owner's review 2026-11-15)
	local bottom = 0
	for index in Config.Zones do
		local need = Throw.chargeForZone(T, Config.Zones, state.power, food.PowerMult, index)
		if need and index > 1 and (need - T.MinCharge) / (1 - T.MinCharge) <= 0.02 then
			bottom = index
		end
	end
	for index, zone in Config.Zones do
		local need = Throw.chargeForZone(T, Config.Zones, state.power, food.PowerMult, index)
		local band = self._zoneBands[index]
		if need and index > 1 then
			if not band then
				band = Screens.template("ZoneMarkTemplate")
				band.Name = "ZoneBand" .. index
				Screens.tint(band, self._zoneColors[index] or Theme.WHITE)
				Screens.label(band, "ZoneMarkName").Text = zone.Name
				band.Parent = self._bands
				self._zoneBands[index] = band
			end
			local height = (need - T.MinCharge) / (1 - T.MinCharge)
			band.Position = UDim2.new(band.Position.X.Scale, band.Position.X.Offset, 1 - height, 0)
			band.Visible = height > 0.02 or index == bottom
		elseif band then
			band.Visible = false
		end
	end
end

-- every frame the meter is up: the marker, what it is worth, where it lands
function ThrowController:_tickMeter()
	local state = self._state.State
	if not state then
		return
	end
	local value = self:_value()
	self._marker.Position = UDim2.fromScale(0.5, 1 - value)
	local food = MAPS.food[state.food]
	local charge = chargeOf(value)
	local base = Throw.effectivePower(state.power, food.PowerMult, T.MinCharge)
	local eff = Throw.effectivePower(state.power, food.PowerMult, charge)
	local bonus = `+{Format.short(math.floor(eff - base))} POWER`
	if bonus ~= self._bonusText then
		self._bonusText = bonus
		self._bonusLabel.Text = bonus
	end
	local zone = Config.Zones[Throw.zoneIndex(Config.Zones, eff)]
	local lands = `Lands in: {zone.Name}`
	if lands ~= self._zoneText then
		self._zoneText = lands
		self._zoneLabel.Text = lands
	end
end

-- The meter's sounds and the lucky glow: throw_charge each time the marker
-- starts up the meter, LuckyThrow_Charge on the hand while a lucky throw is
-- armed (it goes when the food leaves the hand).
function ThrowController:_tickCharge()
	if not self._frozen and not self._busy then
		local sweep = math.floor((os.clock() - self._sweepStart) / (2 * T.ChargeSeconds))
		if sweep ~= self._sweep then
			self._sweep = sweep
			self._charge = Sound:Play("throw_charge")
		end
	end
	self:_setLuckyFx(self._useLucky)
end

function ThrowController:_setLuckyFx(on: boolean)
	local live = self._luckyFx
	if on and not live then
		local character = player.Character
		local hand = character and character:FindFirstChild("RightHand")
		if hand and hand:IsA("BasePart") then
			self._luckyFx = Vfx.play("LuckyThrow_Charge", hand, { loop = true })
		end
	elseif not on and live then
		live.stop()
		self._luckyFx = nil
	end
end

-- The furthest zone this player has caught a hero in (the index carries every
-- hero ever caught): a gate past it is a first, and fires Zone_Unlock.
function ThrowController:_readBestZone(state: any)
	local best = self._bestZone
	for id in state.index or {} do
		local character = MAPS.character[id]
		local zone = if character then ZONE_INDEX[character.Zone] else nil
		if zone and zone > best then
			best = zone
		end
	end
	self._bestZone = best
end

-- ----------------------------------------------------------------- lock --

local controls: any = nil
local function getControls(): any
	if controls then
		return controls
	end
	local ok, module = pcall(function()
		local scripts = player:FindFirstChild("PlayerScripts")
		local playerModule = scripts and scripts:FindFirstChild("PlayerModule")
		return if playerModule then (require :: any)(playerModule) else nil
	end)
	if ok and module then
		controls = module:GetControls()
	end
	return controls
end

-- Hold the player on the throw spot. The SERVER snaps them to the pad centre facing the lane and
-- anchors them (ThrowService:SetPad, like training); here the controls go off, the HUD fades out
-- and the camera is throw mode's. Released by the Exit button (or X) only. Found in play
-- 2026-11-16: the client-only hold leaked (the player still walked off the pad), and the old exit
-- walked the character away with Humanoid:MoveTo, which could resume seconds later on its own.
function ThrowController:_lock(on: boolean)
	if on == self._locked then
		return
	end
	self._locked = on
	self._lockedAt = os.clock()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local c = getControls()
	local root = rootPart()
	-- The client holds the player AT ONCE (owner's review 5: "after I enter the throwing area I
	-- can still move"): the server refused the lock whenever its copy of a walking player was
	-- still a few studs short of the pad, and this Roblox build has no control module to switch
	-- off, so the player walked straight through. Snap to the pad centre and anchor locally; the
	-- server's own snap and anchor follow (asked twice, in case the first ask arrives early).
	local state = self._state.State
	if on and root and state and state.plot then
		-- the pad in front of the base takes the player to their spot on the middle throw stage
		local x, z = World.throwSpot(W, state.plot, COUNT)
		local at = Vector3.new(x, root.Position.Y, z)
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.lookAt(at, at + Vector3.zAxis)
		root.Anchored = true
	elseif not on and root then
		root.Anchored = false
	end
	if self._padRemote then
		local remote = self._padRemote
		remote:FireServer(on)
		if on then
			task.delay(0.5, function()
				if self._locked then
					remote:FireServer(true)
				end
			end)
		end
	end
	-- the pad's own "THROW HERE" sign is pointless while standing on it
	local pads = workspace:FindFirstChild("Map")
	pads = pads and pads:FindFirstChild("Plots")
	local plotModel = if pads
			and state
			and state.plot
		then pads:FindFirstChild("Plot" .. state.plot)
		else nil
	local pad = plotModel and plotModel:FindFirstChild("ThrowPad")
	local hint = pad and pad:FindFirstChild("Hint", true)
	if hint and hint:IsA("BillboardGui") then
		hint.Enabled = not on
	end
	if humanoid then
		-- cancel any walk target left over from before (a MoveTo resumes when walking is back)
		humanoid:Move(Vector3.zero)
		if root then
			humanoid:MoveTo(root.Position)
		end
		humanoid.AutoRotate = not on
	end
	if on then
		if c then
			c:Disable()
		end
		Sound:Play("pad_enter")
		-- the throw clip is fetched now, not on the first throw (owner's review 4: the wind-up came
		-- late, the food sat in a still hand)
		if humanoid then
			Motion.load(humanoid, "Throw")
		end
	elseif c then
		c:Enable()
	end
	local hud = self._hud :: any
	if hud and hud.SetCinematic then
		hud:SetCinematic("throwpad", on)
	end
end

-- Leave the throw spot: the server sets the character down just behind the pad, facing the plot.
function ThrowController:_exitPad()
	if not self._locked or self._playing then
		return
	end
	self._leaving = true
	self:_lock(false)
	Sound:Play("ui_close")
end

-- ----------------------------------------------------------------- mode --

function ThrowController:_setMode(mode: string)
	local was = self._mode
	if mode == was then
		return
	end
	self._mode = mode
	self._hud:SetMode(mode)
	self._heroes:SetPlatesHidden(mode == "cinematic")
	local camera = workspace.CurrentCamera
	if mode == "normal" then
		ContextActionService:UnbindAction(TAP_ACTION)
		camera.CameraType = Enum.CameraType.Custom
		self:_setLuckyFx(false)
		if self._charge then
			Sound:Stop(self._charge, 0.1)
			self._charge = nil
		end
		return
	end
	if was == "normal" then
		-- Space would jump off the pad: while throwing, it throws
		ContextActionService:BindActionAtPriority(
			TAP_ACTION,
			function(_, inputState: Enum.UserInputState)
				if inputState == Enum.UserInputState.Begin then
					self:_tap()
				end
				return Enum.ContextActionResult.Sink
			end,
			false,
			Enum.ContextActionPriority.High.Value,
			table.unpack(TAP_KEYS)
		)
	end
	if mode == "throw" then
		camera.CameraType = Enum.CameraType.Scriptable
		local root = rootPart()
		if was == "cinematic" and root then
			-- back from a sequence, under its white flash: cut, do not travel
			camera.CFrame = shoulderCamera(root)
		end
		if was == "normal" then
			self:_rearm()
		end
	end
end

-- -------------------------------------------------------------- sequence --

-- The food's real model, if the place has it (ReplicatedStorage.Assets.Foods).
local function foodTemplate(foodId: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local foods = assets and assets:FindFirstChild("Foods")
	local found = foods and foods:FindFirstChild("Food_" .. foodId)
	return if found and found:IsA("Model") then found else nil
end

-- Thrown food is drawn bigger than it is in the hand: it has to read from the
-- far end of a lane on a phone.
local FLIGHT_SCALE = 1.7

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
	ball.Color = if food then Theme.FLAVOR[food.Flavor] else Color3.new(1, 1, 1)
	local trail = Instance.new("Trail")
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.9, 0)
	a1.Position = Vector3.new(0, -0.9, 0)
	a0.Parent = ball
	a1.Parent = ball
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.55
	trail.LightEmission = 0.6
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1), ball.Color)
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.Parent = ball
	local template = foodTemplate(foodId)
	if template then
		-- the ball stays as the invisible carrier (the flight code moves it and
		-- the trail hangs off it); the model rides on it
		ball.Transparency = 1
		local model = template:Clone()
		model:ScaleTo(FLIGHT_SCALE)
		model:PivotTo(ball.CFrame)
		for _, piece in model:GetDescendants() do
			if piece:IsA("BasePart") then
				piece.Anchored = false
				piece.CanCollide = false
				piece.CanQuery = false
				piece.CanTouch = false
				piece.Massless = true
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = ball
				weld.Part1 = piece
				weld.Parent = piece
			end
		end
		model.Parent = ball
		-- tumble IN FLIGHT only (ThrowSequence sets "Tumble"); landed or in a hand it stays upright
		-- (owner's review 5: "rotating like a tyre even after landing and in the hand")
		local spin = RunService.RenderStepped:Connect(function()
			if ball:GetAttribute("Tumble") == true then
				local t = os.clock()
				ball.CFrame = CFrame.new(ball.Position) * CFrame.Angles(t * 5, t * 3, 0)
			end
		end)
		ball.Destroying:Once(function()
			spin:Disconnect()
		end)
	end
	ball.Parent = workspace
	return ball
end

function ThrowController:_play(result: any)
	local state = self._state.State
	self._playing = true
	self._busy = true
	self._abort = false
	self._taps = 0
	self._playStart = os.clock()
	self:_setMode("cinematic")
	self._hud:HoldIncome(true)

	local fast = self._autoThrown or (state ~= nil and state.settings.fastReveal == true)
	local early = false
	local ok, err = pcall(function()
		early = ThrowSequence.play({
			result = result,
			foodId = if state then state.food else "",
			plot = if state and state.plot then state.plot else 1,
			fast = fast,
			sentAt = self._sentAt,
			taps = function(): number
				return self._taps
			end,
			aborted = function(): boolean
				return self._abort
			end,
			makeFood = makeFood,
			build = function(
				id: string,
				mut: string?,
				size: string?,
				bare: boolean?
			): (Model, number)
				return self._heroes:Build(id, mut, size, bare)
			end,
			animate = function(model: Model): any
				return self._heroes:Animate(model)
			end,
			land = function(model: Model, holding: boolean?)
				self._heroes:RevealAnimate(model, holding)
			end,
			bestZone = self._bestZone,
			released = function()
				self:_setLuckyFx(false)
			end,
			zoneCross = function(index: number)
				local zone = Config.Zones[index]
				local hud = self._hud :: any
				if zone and hud and hud.ZoneCross then
					hud:ZoneCross(zone.Name, ZONE_COLORS[index] or Color3.new(1, 1, 1), index)
				else
					Sound:Play("zone_cross")
				end
			end,
		})
	end)
	if not ok then
		warn(`[ThrowController] throw sequence failed inert: {err}`)
	end
	-- it ended before the server's arrival time (skipped, or the fast
	-- version): the hero comes to the plot now instead of standing unseen
	if (early or not ok) and result.uid then
		self._heroes:ArriveNow(result.uid)
	end
	self._hud:HoldIncome(false)
	self._playing = false
	self._busy = false
	self._lastZone = result.zone
	self._bestZone = math.max(self._bestZone, result.zone or 0)
	-- a hand-thrown catch comes to the hands: the throw is over, the player steps off the pad
	-- holding it and walks to a pedestal (owner's review 3). Auto Throw seats its catches itself.
	local carrying = result.uid ~= nil and player:GetAttribute("Carrying") ~= nil
	if carrying and self._locked then
		self._leaving = true
		self:_lock(false)
	end
	pcall(self._afterCatch, self, result, carrying)
	self:_rearm()
	self:_setMode(self:_wantedMode())
end

-- Back on the pad after a catch: a Rare or better makes the player
-- celebrate; a hero auto-sold for yen pops coins.
function ThrowController:_afterCatch(result: any, carrying: boolean?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = rootPart()
	local rarity = Config.Rarities[result.rarity]
	-- no cheer while the hands are full (CarryHold plays)
	if humanoid and rarity and rarity.Order >= CELEBRATE_ORDER and not carrying then
		Motion.play(humanoid, "Celebrate")
	end
	if typeof(result.soldYen) == "number" and result.soldYen > 0 and root then
		Vfx.play("Coin_Pop", root.Position + Vector3.new(0, 2, 0))
		Sound:Play("coin_tick")
	end
end

-- Where another player's throw starts: over their own character if it is
-- there (their pad is a raised stage), else over their pad.
function ThrowController:_throwerPosition(plot: number): Vector3
	local plotState = self._state.Plots[plot]
	local owner = if plotState and plotState.owner
		then Players:GetPlayerByUserId(plotState.owner)
		else nil
	local character = owner and owner.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position + Vector3.new(0, 2.5, 3)
	end
	local x, z = World.throwSpot(W, plot, COUNT)
	return Vector3.new(x, W.GroundY + 8, z + 3)
end

-- another player's throw: only the food flying and a small burst, no camera
function ThrowController:_watch(seen: any)
	local from = self:_throwerPosition(seen.plot)
	local target = Vector3.new(seen.x, W.LaneY + 2, seen.z)
	local ball = makeFood(seen.food)
	local trailName, tint = ThrowSequence.trailFor(seen.food)
	local trailFx = Vfx.play(trailName, ball, { loop = true, tint = tint })
	local trail = ball:FindFirstChildOfClass("Trail")
	if trail and trailFx.authored then
		trail.Enabled = false
	end
	task.spawn(function()
		local t0 = os.clock()
		while ball.Parent do
			local t = math.clamp((os.clock() - t0) / seen.flight, 0, 1)
			ball.Position = ThrowSequence.arcPoint(from, target, t)
			if t >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
		trailFx.stop()
		Vfx.play(
			"Land_Impact",
			Vector3.new(seen.x, W.LaneY + 0.15, seen.z),
			{ scale = 0.7, mult = 0.5 }
		)
		task.wait(seen.reveal + T.LandPauseSeconds)
		-- a short reveal, no camera, no sound
		Vfx.play("Reveal_" .. tostring(seen.rarity), target, {
			scale = 0.6,
			tint = Theme.rarity(seen.rarity),
			mult = 0.3,
		})
		ball:Destroy()
	end)
end

function ThrowController:_wantedMode(): string
	if self._playing then
		return "cinematic"
	end
	return if self._onPad and not self._leaving and not Screens.isOpen() then "throw" else "normal"
end

function ThrowController:KnitStart()
	-- the clips of a throw, its reveal, the carry and a rebirth are fetched at once, not on first use
	Motion.preload({
		"Throw",
		"HeroStalk",
		"HeroPickUp",
		"HeroMenace",
		"Eat",
		"CarryHold",
		"PlaceHero",
		"RebirthAwaken",
	})
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
	self._padRemote = Net.client("ThrowPad")
	self:_bindUi()

	result.OnClientEvent:Connect(function(payload: any)
		-- a new result while the last one is still on screen (Auto Throw, or a
		-- fast hand): end the old sequence, never run two cameras at once
		while self._playing do
			self._abort = true
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
	self._state:Observe(function(state: any)
		self:_refreshUi()
		if not self._playing then
			self:_readBestZone(state)
		end
	end)
	self._state.Ticked:Connect(function()
		-- power moves the zone bands while training
		if self._mode == "throw" then
			self:_refreshUi()
		end
	end)

	-- during the sequence any click, touch or gamepad A is a skip press (the
	-- throw keys reach _tap through the bound action)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		-- A throw key that reached here UNPROCESSED was not taken by the bound
		-- action (input injected by a test tool can bypass ContextActionService):
		-- it still throws. One the action took arrives processed, and so does
		-- a key typed into a text box, so neither is counted twice or by mistake.
		if
			not processed
			and self._locked
			and not self._playing
			and (input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.X)
		then
			self:_exitPad()
			return
		end
		if not processed and self._mode ~= "normal" and table.find(TAP_KEYS, input.KeyCode) then
			self:_tap()
			return
		end
		if not self._playing then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA
		then
			self:_tap()
		end
	end)

	player.CharacterAdded:Connect(function()
		self._locked = false
		self._leaving = false
		local c = getControls()
		if c then
			c:Enable()
		end
		local hud = self._hud :: any
		if hud and hud.SetCinematic then
			hud:SetCinematic("throwpad", false)
		end
	end)

	local lastAuto = 0
	RunService.RenderStepped:Connect(function(dt: number)
		local state = self._state.State
		local root = rootPart()
		if state and state.plot and root then
			local x, z = World.throwPad(W, state.plot, COUNT)
			local distance = World.distance(root.Position.X, root.Position.Z, x, z)
			-- held, the player stands on the throw stage, not on the pad
			local sx, sz = World.throwSpot(W, state.plot, COUNT)
			local held = World.distance(root.Position.X, root.Position.Z, sx, sz)
			-- locked, the player IS on the pad (the server holds them there); unlocked, stepping
			-- well onto it locks them
			self._onPad = self._locked or distance <= W.ThrowPadRadius + 1.5
			if self._leaving and distance > W.ThrowPadRadius + 4 then
				-- set down off the stage: the next step onto it locks again
				self._leaving = false
			end
			if
				self._onPad
				and not self._leaving
				and not self._locked
				and player:GetAttribute("Carrying") ~= nil
				and not self._playing
			then
				-- a hero in the hands: no pad until it is set down (the server says so once);
				-- walking on does not lock until the player steps off and back on
				self._leaving = true
				local hud = self._hud :: any
				if hud and hud.Toast and os.clock() - self._carryToastAt > 4 then
					self._carryToastAt = os.clock()
					hud:Toast("Place your hero on a pedestal first!", "bad")
				end
			elseif self._onPad and not self._leaving and not self._locked then
				self:_lock(true)
			elseif
				self._locked
				and held > W.ThrowPadRadius + 8
				and os.clock() - self._lockedAt > 2
			then
				-- moved off by something else (a teleport, a respawn): let go
				self:_lock(false)
			end
		else
			self._onPad = false
		end
		local mode = self:_wantedMode()
		if mode ~= self._mode then
			self:_setMode(mode)
		end

		-- the meter: up in throw mode, and for a moment into the wind-up
		local gui = self._gui
		local lingering = self._playing
			and not self._autoThrown
			and os.clock() - self._playStart < METER_LINGER
		local shown = mode == "throw" or lingering
		if gui.Enabled ~= shown then
			gui.Enabled = shown
		end
		if mode ~= "throw" then
			return
		end
		self:_tickMeter()
		self:_tickCharge()
		if root then
			-- ease in behind the shoulder, and follow small steps on the pad
			local camera = workspace.CurrentCamera
			camera.CFrame = camera.CFrame:Lerp(shoulderCamera(root), 1 - math.exp(-7 * dt))
		end
		-- Auto Throw pass: tap just under the perfect band, so throwing by hand
		-- is still worth a little more
		local now = os.clock()
		if self._auto and self:_canThrow() and now - lastAuto > 0.6 then
			if state and state.passes and state.passes.AutoThrow then
				lastAuto = now
				local charge = 1 - T.PerfectWindow - 0.01
				self:_send((charge - T.MinCharge) / (1 - T.MinCharge), true)
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
