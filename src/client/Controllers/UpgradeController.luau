--!strict
-- UpgradeController - buying the next training gear level and the next plot slot (owner's review 3).
--
-- The notice board of each training ground carries a prompt (F, "Upgrade gear"); it and the slot
-- sign's prompt do not buy on the spot: they open a confirmation (HudController:Confirm) that
-- shows the model, what changes and the price; CONFIRM sends ShopBuy. The server re-checks
-- everything (ShopService), so this is only presentation.
--
-- While the player can afford the next gear level and is NOT training, the board of the ground
-- that level belongs to wears a bouncing gold "UPGRADE!" marker and the prompts turn gold (the
-- training bar says the same while they train: the upgrade never interrupts a session). When
-- the gear goes up, it arrives with a burst, a light column and a pop of the ground's centrepiece
-- (plan 13 phase D: a gear row is a tier and a level of a ground, Core/Grounds).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Progress = require(ReplicatedStorage.Shared.Core.Progress)
local Vfx = require(script.Parent.Parent.Fx.Vfx)
local GroundLook = require(script.Parent.Parent.Ui.GroundLook)
local Sound = require(script.Parent.SoundController)

local player = Players.LocalPlayer
local TR = Config.Training
local GOLD = Color3.fromHex("FFC83D")
local GREEN = Color3.fromHex("37D67A")

local UpgradeController = Knit.CreateController({
	Name = "UpgradeController",
	_marker = nil :: BillboardGui?,
	_markerFor = nil :: Instance?,
	_lastGear = nil :: number?,
	_dialog = nil :: any,
})

-- the plot model of the local player (Workspace.Map.Plots.Plot<n>)
local function plotModel(plot: number?): Instance?
	local map = workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")
	return if plots and plot then plots:FindFirstChild("Plot" .. plot) else nil
end

function UpgradeController:_training(): boolean
	local training = self._training_ctl :: any
	return training ~= nil and training.IsTraining ~= nil and training:IsTraining()
end

-- "unlocks when you reach <zone>" / "unlocks at Rebirth N", or nil when the row is open
local function lockText(row: any, state: any): string?
	local lock = Progress.lock(row, state.bestZone or 1, state.rebirth or 0)
	if not lock then
		return nil
	end
	if lock.rebirth then
		return `unlocks at Rebirth {lock.rebirth}`
	end
	return `unlocks when you reach {Config.Zones[lock.zone :: number].Name}`
end

-- --------------------------------------------------------------- dialogs --

function UpgradeController:_confirmGear()
	local state = self._state.State
	local hud = self._hud :: any
	if not state or not hud then
		return
	end
	local cost = Progress.nextGearCost(Config, state.gear)
	if not cost then
		hud:Toast("Your training gear is maxed", "info")
		return
	end
	local locked = lockText(TR.Equipment[state.gear + 1], state)
	if locked then
		hud:Toast(`{TR.Equipment[state.gear + 1].Name} {locked}`, "bad")
		return
	end
	local now = TR.Equipment[state.gear]
	local nextRow = TR.Equipment[state.gear + 1]
	local rows = {
		{
			label = "Power per rep",
			from = if now then `+{Format.short(now.PowerPerRep)}` else "+0",
			to = `+{Format.short(nextRow.PowerPerRep)}`,
			icon = "IconPower",
		},
	}
	local ground = GroundLook.groundOf(state.gear + 1)
	if ground then
		table.insert(rows, { label = "Training ground", to = ground.Name, icon = "IconTrain" })
	end
	if not hud.Confirm then
		self._buy:FireServer("gear")
		return
	end
	self._dialog = hud:Confirm({
		title = "UPGRADE GEAR",
		name = nextRow.Name,
		tag = GroundLook.tag(state.gear + 1),
		tagColor = GOLD,
		model = GroundLook.display(state.gear + 1),
		rows = rows,
		cost = cost,
		costKind = "yen",
		canAfford = state.yen >= cost,
		affordCheck = function(): boolean
			local live = self._state.State
			return live ~= nil and live.yen >= cost
		end,
		confirmText = "UPGRADE",
		color = GOLD,
		onConfirm = function()
			self._buy:FireServer("gear")
		end,
	})
end

function UpgradeController:_confirmSlot()
	local state = self._state.State
	local hud = self._hud :: any
	if not state or not hud then
		return
	end
	local cost = Progress.nextSlotCost(Config, state.slots, state.bonusSlots or 0)
	if not cost then
		hud:Toast("Your plot is at its maximum", "info")
		return
	end
	local locked = lockText(
		{ Zone = Progress.nextSlotZone(Config, state.slots, state.bonusSlots or 0) },
		state
	)
	if locked then
		hud:Toast(`The next slot {locked}`, "bad")
		return
	end
	if not hud.Confirm then
		self._buy:FireServer("slot")
		return
	end
	self._dialog = hud:Confirm({
		title = "NEW HERO SLOT",
		name = `Slot {state.slots + 1}`,
		tag = "PLOT UPGRADE",
		tagColor = GREEN,
		image = "IconPlaceBig",
		rows = {
			{
				label = "Hero slots",
				from = tostring(state.slots),
				to = tostring(state.slots + 1),
				icon = "IconPlace",
			},
		},
		cost = cost,
		costKind = "yen",
		canAfford = state.yen >= cost,
		affordCheck = function(): boolean
			local live = self._state.State
			return live ~= nil and live.yen >= cost
		end,
		confirmText = "BUY SLOT",
		color = GREEN,
		onConfirm = function()
			self._buy:FireServer("slot")
		end,
	})
end

-- ---------------------------------------------------------- the marker --

-- a bouncing gold "UPGRADE!" over the gear stand
local function makeMarker(): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "UpgradeMarker"
	gui.Size = UDim2.fromScale(5.2, 2.2)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 6.5, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 90
	-- the notice board stands where the player walks: from nearer than this the marker stops growing
	-- (seen in play: beside the board it filled a quarter of the screen)
	gui.DistanceLowerLimit = 30
	gui.AlwaysOnTop = false
	gui.ResetOnSpawn = false
	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Position = UDim2.fromScale(0.5, 0.42)
	plate.Size = UDim2.fromScale(1, 0.62)
	plate.BackgroundColor3 = GOLD
	plate.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = plate
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromHex("7A4A00")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = plate
	local gloss = Instance.new("UIGradient")
	gloss.Rotation = 90
	gloss.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("FFF1B8")),
		ColorSequenceKeypoint.new(0.48, Color3.fromHex("FFD34D")),
		ColorSequenceKeypoint.new(1, Color3.fromHex("F59E0B")),
	})
	gloss.Parent = plate
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(0.92, 0.8)
	text.AnchorPoint = Vector2.new(0.5, 0.5)
	text.Position = UDim2.fromScale(0.5, 0.5)
	text.Font = Enum.Font.FredokaOne
	text.Text = "UPGRADE!"
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Parent = plate
	local outline = Instance.new("UIStroke")
	outline.Thickness = 2.5
	outline.Color = Color3.fromHex("7A4A00")
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	outline.Parent = text
	local arrow = Instance.new("TextLabel")
	arrow.Name = "Arrow"
	arrow.BackgroundTransparency = 1
	arrow.AnchorPoint = Vector2.new(0.5, 0)
	arrow.Position = UDim2.fromScale(0.5, 0.74)
	arrow.Size = UDim2.fromScale(0.3, 0.3)
	arrow.Font = Enum.Font.FredokaOne
	arrow.Text = "▼"
	arrow.TextScaled = true
	arrow.TextColor3 = GOLD
	arrow.Parent = gui
	local arrowStroke = outline:Clone()
	arrowStroke.Parent = arrow
	return gui
end

function UpgradeController:_paintMarker()
	local state = self._state.State
	local model = state and plotModel(state.plot)
	local cost = state and Progress.nextGearCost(Config, state.gear)
	local hud = self._hud :: any
	local cinematic = hud ~= nil and hud.IsCinematic ~= nil and hud:IsCinematic()
	local ready = state ~= nil
		and cost ~= nil
		and state.yen >= cost
		and lockText(TR.Equipment[state.gear + 1], state) == nil
		and not self:_training()
		and not cinematic
	-- the marker stands on the board of the ground the next level belongs to (the first court's
	-- when that ground is not on the base yet)
	local court = if state then GroundLook.courtOf(state.gear + 1, state.rebirth or 0) else nil
	local stand = if model then model:FindFirstChild("GearSign" .. (court or 1)) else nil
	-- the gear prompts turn gold while an upgrade is affordable (PromptController reads Accent)
	for index = 1, #TR.Courts do
		local sign = model and model:FindFirstChild("GearSign" .. index)
		local prompt = sign and sign:FindFirstChildWhichIsA("ProximityPrompt", true)
		local anchor = model and model:FindFirstChild("Ground" .. index)
		if prompt then
			prompt:SetAttribute("Accent", if ready then GOLD else nil)
			-- (an empty court, or one whose set piece is missing, keeps its prompt off: PlotService)
			prompt.Enabled = not self:_training()
				and anchor ~= nil
				and anchor:FindFirstChild("GroundModel") ~= nil
		end
	end
	if not ready or not stand or not stand:IsA("BasePart") then
		if self._marker then
			self._marker.Enabled = false
		end
		return
	end
	if not self._marker then
		self._marker = makeMarker()
	end
	local marker = self._marker :: BillboardGui
	if self._markerFor ~= stand then
		self._markerFor = stand
		marker.Adornee = stand
		marker.Parent = player:WaitForChild("PlayerGui")
	end
	marker.Enabled = true
end

function UpgradeController:_bob(now: number)
	local marker = self._marker
	if not marker or not marker.Enabled then
		return
	end
	local plate = marker:FindFirstChild("Plate")
	local arrow = marker:FindFirstChild("Arrow")
	local bounce = math.abs(math.sin(now * 3.2))
	if plate and plate:IsA("GuiObject") then
		plate.Position = UDim2.fromScale(0.5, 0.42 - 0.08 * bounce)
		plate.Rotation = math.sin(now * 1.6) * 3
	end
	if arrow and arrow:IsA("GuiObject") then
		arrow.Position = UDim2.fromScale(0.5, 0.74 - 0.05 * bounce)
	end
end

-- ------------------------------------------------------- the arrival --

-- the new gear arrives on its ground: a burst, a light column, the centrepiece pops up from small
function UpgradeController:_arrive(gear: number)
	local state = self._state.State
	local model = state and plotModel(state.plot)
	local court = if state then GroundLook.courtOf(gear, state.rebirth or 0) else nil
	local anchor = model and court and model:FindFirstChild("Ground" .. court)
	if not anchor or not anchor:IsA("BasePart") then
		return
	end
	Sound:Play("upgrade_burst", nil)
	Sound:Play("level_up", nil)
	task.spawn(function()
		-- the server swaps the set piece for the new look; wait for it (its Look attribute moves)
		local before = anchor:GetAttribute("Look")
		local t0 = os.clock()
		while anchor:GetAttribute("Look") == before and os.clock() - t0 < 3 do
			RunService.Heartbeat:Wait()
		end
		local piece = anchor:FindFirstChild("GroundModel")
		local target = piece and piece:FindFirstChild("Target")
		if not target or not target:IsA("Model") then
			return
		end
		local pivot = target:GetPivot()
		Vfx.play("Slot_Unlock", pivot.Position, { tint = GOLD })
		Vfx.play("PowerUp_Burst", pivot.Position, { tint = GOLD })
		-- grow it from small, with a turn (a centrepiece carrying beams or emitters keeps them)
		local full = target:GetScale()
		t0 = os.clock()
		while target.Parent and os.clock() - t0 < 0.55 do
			local u = (os.clock() - t0) / 0.55
			local back = 1 + 2.4 * (u - 1) ^ 3 + 1.4 * (u - 1) ^ 2
			target:ScaleTo(full * math.max(0.15 + 0.85 * back, 0.05))
			target:PivotTo(pivot * CFrame.Angles(0, (1 - u) * math.pi, 0))
			RunService.Heartbeat:Wait()
		end
		if target.Parent then
			target:ScaleTo(full)
			target:PivotTo(pivot)
		end
	end)
end

function UpgradeController:KnitStart()
	self._state = Knit.GetController("StateController")
	self._hud = Knit.GetController("HudController")
	self._training_ctl = Knit.GetController("TrainingController")
	self._buy = Net.client("ShopBuy")

	-- the prompts the server no longer acts on (InteractService): gear and slot open a dialog
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		local action = prompt:GetAttribute("Action")
		local state = self._state.State
		local plot = prompt:GetAttribute("Plot")
		if not state or (plot ~= nil and plot ~= state.plot) then
			return
		end
		if action == "gear" then
			if not self:_training() then
				self:_confirmGear()
			end
		elseif action == "slot" then
			self:_confirmSlot()
		end
	end)

	self._state:Observe(function()
		local state = self._state.State
		if not state then
			return
		end
		if self._lastGear and state.gear > self._lastGear then
			if self._dialog and self._dialog.Close then
				pcall(self._dialog.Close, self._dialog)
			end
			self:_arrive(state.gear)
		end
		self._lastGear = state.gear
		self:_paintMarker()
	end)
	-- the yen ticks without a full state change, and training starts and stops: repaint on a timer
	local nextPaint = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now >= nextPaint then
			nextPaint = now + 0.5
			self:_paintMarker()
		end
		self:_bob(now)
	end)
end

return UpgradeController
