--!strict
-- ThrowController - the core verb on the client: stand on the pad, tap, watch.
--
-- The client only sends (charge, useLuckyThrow, auto, aim). Everything it then shows
-- (wind-up, flight, landing, reveal: Fx/ThrowSequence) is a replay of a result
-- the server has ALREADY decided and granted, so skipping, lagging or leaving
-- loses nothing.
--
-- THROW MODE. While the player stands on their own pad (and no page is open)
-- the camera settles behind the shoulder looking down the lane, the HUD steps
-- aside, and the meter's marker slides up and down by itself, one sweep every
-- Throw.ChargeSeconds. ONE tap (the THROW button, Space, T, gamepad X or R2)
-- throws with the charge the marker shows at that instant.
--
-- AIM (plan 12, section 9). The player picks the zone to land in: any zone
-- their Power reaches (Q / E, the bumpers, or a tap on either half of the
-- "Lands in" line). The meter then only decides how DEEP in that zone the
-- food lands (deeper = more luck); the top slice is the perfect band.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Progress = require(ReplicatedStorage.Shared.Core.Progress)
local Throw = require(ReplicatedStorage.Shared.Core.Throw)
local World = require(ReplicatedStorage.Shared.Core.World)
local Motion = require(script.Parent.Parent.Fx.Motion)
local ThrowSequence = require(script.Parent.Parent.Fx.ThrowSequence)
local Vfx = require(script.Parent.Parent.Fx.Vfx)
local FoodLook = require(script.Parent.Parent.Ui.FoodLook)
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
	Color3.fromHex("FF9A3C"), -- Hidden Leaf Village
	Color3.fromHex("5BD6B0"), -- Demon Slayer Corps
	Color3.fromHex("3FB6FF"), -- Grand Line
	Color3.fromHex("5BE38A"), -- Hero Academy
	Color3.fromHex("3D7BFF"), -- Blue Lock Facility
	Color3.fromHex("8BD94A"), -- Clover Kingdom
	Color3.fromHex("FFB03C"), -- Hunter Exam
	Color3.fromHex("C084FF"), -- Isekai Crossroads
	Color3.fromHex("C9B28A"), -- Wall Maria
	Color3.fromHex("FF6A3C"), -- Public Safety HQ
	Color3.fromHex("FFD23F"), -- Bizarre Streets
	Color3.fromHex("9B6BFF"), -- Shadow Council
	Color3.fromHex("FFE14A"), -- City Z
	Color3.fromHex("FF8FC8"), -- Soul Society
	Color3.fromHex("7A5CFF"), -- Gate of Shadows
	Color3.fromHex("6FA8FF"), -- Shibuya
	Color3.fromHex("FFC83C"), -- Planet of the Gods
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
	-- the zone the player aims at; 0 = as far as their Power reaches
	_aim = 0,
	_aimSynced = false,
	_aimBack = nil :: GuiObject?,
	_aimFurther = nil :: GuiObject?,
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

-- the furthest zone the player's throw reaches (Power x food, stopped by a sealed gate)
function ThrowController:_reach(): number
	local state = self._state.State
	if not state then
		return 1
	end
	return Throw.reach(Config.Zones, state.power, state.rebirth or 0)
end

-- step the aim one zone back (-1) or further (+1); the furthest zone is "no aim"
function ThrowController:_stepAim(delta: number)
	if self._busy or self._mode ~= "throw" then
		return
	end
	local reach = self:_reach()
	local now = if self._aim > 0 then math.min(self._aim, reach) else reach
	local zone = math.clamp(now + delta, 1, reach)
	self._aim = if zone >= reach then 0 else zone
	self._zoneText = ""
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
	self._request:FireServer(charge, self._useLucky, auto, self._aim)
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
	-- AIM: the arrows either side of the "Lands in" line step the zone (UI v5.1)
	-- (the cell carries the button's lip: hide the cell, not only the button)
	self._aimBack = cellOf(gui, "AimBack")
	self._aimFurther = cellOf(gui, "AimFurther")
	Screens.button(gui, "AimBack").MouseButton1Down:Connect(function()
		self:_stepAim(-1)
	end)
	Screens.button(gui, "AimFurther").MouseButton1Down:Connect(function()
		self:_stepAim(1)
	end)
	-- ODDS: the live odds of the next throw (Pages/ThrowOdds)
	-- Pages are blocked while the player is held on the spot ("throwpad" cinematic): the odds
	-- page lifts that for itself and puts it back when it closes.
	Screens.button(gui, "OddsButton").Activated:Connect(function()
		if self._busy or self._playing then
			return
		end
		local hud = self._hud :: any
		if hud and hud.SetCinematic then
			hud:SetCinematic("throwpad", false)
		end
		Screens.open("ThrowOdds")
	end)
	Screens.Closed:Connect(function(name: string)
		local hud = self._hud :: any
		if name == "ThrowOdds" and self._locked and hud and hud.SetCinematic then
			hud:SetCinematic("throwpad", true)
		end
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		local key = input.KeyCode
		if key == Enum.KeyCode.Q or key == Enum.KeyCode.ButtonL1 then
			self:_stepAim(-1)
		elseif key == Enum.KeyCode.E or key == Enum.KeyCode.ButtonR1 then
			self:_stepAim(1)
		end
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

-- the toggles and the food follow the state
function ThrowController:_refreshUi()
	local state = self._state.State
	if not state or not self._gui then
		return
	end
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
	-- the food this throw will use: the best one owned for the aimed zone, or the pinned one
	local aimed = if self._aim > 0 then math.min(self._aim, self:_reach()) else self:_reach()
	local thrown = FoodLook.current(state, aimed)
	local thrownId = if thrown then thrown.Id else state.food
	if self._gui:GetAttribute("FoodShown") ~= thrownId then
		self._gui:SetAttribute("FoodShown", thrownId)
		Screens.setIcon(self._foodIcon, FoodLook.iconKey(thrownId))
	end

	-- the aim the server remembers, once
	if not self._aimSynced then
		self._aimSynced = true
		self._aim = if typeof(state.aim) == "number" then state.aim else 0
	end
	-- the meter is a DEPTH meter now: the old zone marks are gone
	for _, band in self._zoneBands do
		band.Visible = false
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
	local charge = chargeOf(value)
	local full = state.power
	local tier = state.rebirth or 0
	local zoneIndex, depth =
		Throw.landing(T, Config.Zones, full, tier, if self._aim > 0 then self._aim else nil, charge)
	-- deeper in the zone = more luck: that is what the marker is worth
	local bonus = `+{math.floor(depth * T.DepthLuckBonus * 100 + 0.5)}% LUCK`
	if bonus ~= self._bonusText then
		self._bonusText = bonus
		self._bonusLabel.Text = bonus
	end
	local zone = Config.Zones[zoneIndex]
	local lands = `Lands in: {zone.Name}`
	if lands ~= self._zoneText then
		self._zoneText = lands
		self._zoneLabel.Text = lands
		-- an arrow shows only when the aim can move that way
		local reach = Throw.reach(Config.Zones, full, tier)
		self._aimBack.Visible = zoneIndex > 1
		self._aimFurther.Visible = zoneIndex < reach
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

-- The "YOUR SPOT" sign over the player's own circle on the stage (Map.HubV2.ThrowStage.SpotHint<i>):
-- every sign starts hidden; each client shows only its own, and only while it is not standing on it.
-- nil while the stage is not streamed in.
function ThrowController:_spotHint(): BillboardGui?
	local state = self._state.State
	local stage = workspace:FindFirstChild("Map")
	stage = stage and stage:FindFirstChild("HubV2")
	stage = stage and stage:FindFirstChild("ThrowStage")
	local anchor = stage and state and state.plot and stage:FindFirstChild("SpotHint" .. state.plot)
	local hint = anchor and anchor:FindFirstChild("Hint")
	return if hint and hint:IsA("BillboardGui") then hint else nil
end

-- Hold the player on the throw spot. The SERVER snaps them to the spot's centre facing the lane and
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
	-- the spot's own "YOUR SPOT" sign is pointless while standing on it
	local hint = self:_spotHint()
	if hint then
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
	local found = foods and foods:FindFirstChild(FoodLook.modelKey(foodId))
	return if found and found:IsA("Model") then found else nil
end

-- Thrown food is drawn bigger than it is in the hand: it has to read from the
-- far end of a lane on a phone.
local FLIGHT_SCALE = 1.7
local FLIGHT_GROW = 0.25 -- seconds from hand size to FLIGHT_SCALE after the release

-- How a food turns in flight, by its template's Throw attribute (design/foods.json, plan 13):
--   heave  a bowl, plate, tray or box flies LEVEL, its top leaning toward the chase camera behind
--          it, with a slow flat turn: the soup never points at the ground
--   spin   a skewer or a flat thing flips end over end, like a thrown knife
--   else   a small solid food tumbles, slowly enough for its texture to be read
local HEAVE_LEAN = CFrame.Angles(math.rad(-22), 0, 0)
local function flightTurn(style: any, t: number): CFrame
	if style == "heave" then
		return HEAVE_LEAN * CFrame.Angles(0, t * 1.2, 0)
	elseif style == "spin" then
		return CFrame.Angles(t * 7, 0, 0)
	end
	return CFrame.Angles(t * 2.6, t * 1.5, 0)
end

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
	ball.Color = FoodLook.color(food)
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
		-- in the hand the food is its own size (design/foods.json `size`); it grows to
		-- FLIGHT_SCALE as it leaves the hand (below), so it is not torso-sized in the wind-up
		-- (a template's own Scale is NOT 1: install_foods sized each to its `size` with ScaleTo,
		-- so every size here is relative to it; an absolute ScaleTo(1.7) flew foods 2-4.5x big)
		local model = template:Clone()
		local handScale = model:GetScale()
		local flightScale = handScale * FLIGHT_SCALE
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
		local style = model:GetAttribute("Throw")
		-- tumble IN FLIGHT only (ThrowSequence sets "Tumble"); landed or in a hand it stays upright
		-- (owner's review 5: "rotating like a tyre even after landing and in the hand")
		local grownAt: number? = nil
		local spin = RunService.RenderStepped:Connect(function()
			if ball:GetAttribute("Tumble") == true then
				local t = os.clock()
				if grownAt == nil then
					grownAt = t
				end
				local g = math.clamp((t - (grownAt :: number)) / FLIGHT_GROW, 0, 1)
				if model.Parent and model:GetScale() < flightScale then
					model:ScaleTo(handScale + (flightScale - handScale) * (1 - (1 - g) * (1 - g)))
				end
				ball.CFrame = CFrame.new(ball.Position) * flightTurn(style, t)
			end
		end)
		-- landed (or the flight was skipped in a frame): flight size at once, which the
		-- pick-up in ThrowSequence shrinks back to hand size
		local landed = ball:GetAttributeChangedSignal("Tumble"):Connect(function()
			if ball:GetAttribute("Tumble") == false and model.Parent then
				model:ScaleTo(flightScale)
			end
		end)
		ball.Destroying:Once(function()
			spin:Disconnect()
			landed:Disconnect()
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
			-- the server says which food it threw (auto-pick); the pinned one is the fallback
			foodId = if typeof(result.food) == "string"
				then result.food
				elseif state then state.food
				else "",
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
	pcall(self._sealHint, self, result)
	self:_rearm()
	self:_setMode(self:_wantedMode())
end

-- The sealed gate stopped this throw (the server's `sealed`): the HUD and its REBIRTH notice are
-- hidden while the player is held on the stage, so the stage says it (phase F playtest: a player
-- past the seal kept throwing into the last open zone with no hint). Once per rebirth tier, then
-- every SEAL_HINT_EVERY sealed throws.
local SEAL_HINT_EVERY = 10
function ThrowController:_sealHint(result: any)
	local state = self._state.State
	if not result.sealed or not state then
		self._sealedThrows = 0
		return
	end
	local tier = state.rebirth or 0
	local nextTier = Progress.nextRebirth(Config, tier)
	if not nextTier then
		return
	end
	self._sealedThrows = (self._sealedThrows or 0) + 1
	if self._sealToldTier == tier and self._sealedThrows % SEAL_HINT_EVERY ~= 0 then
		return
	end
	self._sealToldTier = tier
	local opens = Config.Zones[nextTier.Unseals[1]]
	local hud = self._hud :: any
	if Progress.canRebirth(Config, tier, state.power, state.yen) then
		-- (a toast holds about 48 characters on one line)
		hud:Toast(
			`REBIRTH READY! Step off to open {if opens then opens.Name else "more zones"}`,
			"good"
		)
	else
		hud:Toast(`SEALED GATE: rebirth for {Format.short(nextTier.YenCost)} yen to go on`, "info")
	end
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
	local lastHint = 0
	RunService.RenderStepped:Connect(function(dt: number)
		local state = self._state.State
		local root = rootPart()
		if os.clock() - lastHint > 0.5 then
			-- the stage streams in after the player spawns: show the sign once it is there
			lastHint = os.clock()
			local hint = self:_spotHint()
			if hint then
				hint.Enabled = not self._locked
			end
		end
		if state and state.plot and root then
			local x, z = World.throwPad(W, state.plot, COUNT)
			local distance = World.distance(root.Position.X, root.Position.Z, x, z)
			-- the pad IS the spot on the stage since 2026-11-23 (no pad at the bases)
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
--- The zone the next throw is aimed at (the furthest in reach when no aim is set).
function ThrowController:AimZone(): number
	local reach = self:_reach()
	return if self._aim > 0 then math.min(self._aim, reach) else reach
end

--- True while a Lucky Throw is switched on for the next throw.
function ThrowController:LuckyArmed(): boolean
	return self._useLucky
end

function ThrowController:OnPad(): boolean
	return self._onPad
end

--- The zone index the player's last throw landed in (for the tutorial).
function ThrowController:LastZone(): number?
	return self._lastZone
end

return ThrowController
