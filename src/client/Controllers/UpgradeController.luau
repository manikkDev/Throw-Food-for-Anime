--!strict
-- UpgradeController - buying the next dojo gear tier and the next plot slot (owner's review 3).
--
-- The gear stand's prompt (F, "Upgrade gear") and the slot sign's prompt no longer buy on the
-- spot: they open a confirmation (HudController:Confirm) that shows the model, what changes and
-- the price; CONFIRM sends ShopBuy. The server re-checks everything (ShopService), so this is
-- only presentation.
--
-- While the player can afford the next gear tier and is NOT training, the gear stand wears a
-- bouncing gold "UPGRADE!" marker and its prompt turns gold (the training bar says the same
-- while they train: the upgrade never interrupts a session). When the tier goes up, the new
-- gear arrives with a burst, a light column and a pop of the model.

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

-- the model template of gear tier `tier` (ReplicatedStorage.Assets.Gear.Equip_<name>)
local function gearTemplate(tier: number): Model?
	local row = TR.Equipment[tier]
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Gear")
	if not row or not folder then
		return nil
	end
	local found = folder:FindFirstChild(
		"Equip_" .. string.gsub(string.lower(row.Model or row.Name), "%s+", "_")
	)
	return if found and found:IsA("Model") then found else nil
end

-- the anchor that shows gear tier `tier` on the plot (PlotService:_showGear's rule)
local function anchorFor(model: Instance, tier: number): BasePart?
	local name = if tier <= 3 then "Gear" elseif tier >= 5 then "SpiritGear" else nil
	if not name then
		for i, row in TR.Stations do
			if string.sub(row.Prop, 1, 6) == "Equip_" then
				local eq = TR.Equipment[tier]
				if
					eq
					and "Equip_" .. string.gsub(string.lower(eq.Model or eq.Name), "%s+", "_") == row.Prop
				then
					name = "Target" .. i
				end
			end
		end
	end
	local found = name and model:FindFirstChild(name)
	return if found and found:IsA("BasePart") then found else nil
end

local function stationUnlockedAt(tier: number): string?
	for _, row in TR.Stations do
		if row.Unlock == tier then
			return row.Name
		end
	end
	return nil
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
		hud:Toast("Your dojo gear is maxed", "info")
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
	local unlock = stationUnlockedAt(state.gear + 1)
	if unlock then
		table.insert(rows, { label = "Unlocks", to = unlock, icon = "IconTrain" })
	end
	if not hud.Confirm then
		self._buy:FireServer("gear")
		return
	end
	self._dialog = hud:Confirm({
		title = "UPGRADE GEAR",
		name = nextRow.Name,
		tag = `TIER {state.gear + 1}`,
		tagColor = GOLD,
		model = gearTemplate(state.gear + 1),
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
	local stand = if model then model:FindFirstChild("Gear") else nil
	-- the gear prompt turns gold while an upgrade is affordable (PromptController reads Accent)
	local prompt = stand and stand:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt:SetAttribute("Accent", if ready then GOLD else nil)
		prompt.Enabled = not self:_training()
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

-- the new gear tier arrives on its stand: a burst, a light column, the model pops up from small
function UpgradeController:_arrive(tier: number)
	local state = self._state.State
	local model = state and plotModel(state.plot)
	local anchor = model and anchorFor(model, tier)
	if not anchor then
		return
	end
	local ground = anchor.Position - Vector3.new(0, anchor.Size.Y / 2, 0)
	Vfx.play("Slot_Unlock", ground, { tint = GOLD })
	Vfx.play("PowerUp_Burst", ground, { tint = GOLD })
	Sound:Play("upgrade_burst", nil)
	Sound:Play("level_up", nil)
	task.spawn(function()
		-- the server swaps the model in; wait for it, then grow it from small
		local gear = anchor:WaitForChild("GearModel", 3)
		if not gear or not gear:IsA("Model") then
			return
		end
		local pivot = gear:GetPivot()
		local t0 = os.clock()
		while gear.Parent and os.clock() - t0 < 0.55 do
			local u = (os.clock() - t0) / 0.55
			local back = 1 + 2.4 * (u - 1) ^ 3 + 1.4 * (u - 1) ^ 2
			gear:ScaleTo(math.max(0.15 + 0.85 * back, 0.05))
			gear:PivotTo(pivot * CFrame.Angles(0, (1 - u) * math.pi, 0))
			RunService.Heartbeat:Wait()
		end
		if gear.Parent then
			gear:ScaleTo(1)
			gear:PivotTo(pivot)
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
