--!strict
-- PromptController - our own look for every ProximityPrompt (owner's review 3).
--
-- Every prompt in the world (now and later) is set to Style = Custom, so
-- Roblox draws nothing; on PromptShown we draw the authored PromptCard
-- (design/ui/PromptCard.json) over the prompt's part. Found in play: as an
-- always-on-top BillboardGui it never drew, and without always-on-top the
-- character hides it, so the card's canvas is moved into a screen layer
-- (PromptLayer) and placed each frame where the part is on screen:
--   * a key cap: the KeyboardKeyCode letter on PC, the gamepad button on a
--     pad, a tap ripple on touch; tinted by the prompt's optional `Accent`
--     Color3 attribute (watched while shown: the gear stand turns gold when an
--     upgrade is affordable, Place hero is green)
--   * ActionText bold, ObjectText small (the action alone sits centred)
--   * a ring of 16 pips around the key cap that fills while a HoldDuration
--     prompt is held (PromptButtonHoldBegan / Ended)
--   * a pop-in from the centre (prompt_show), a press bounce (ui_click)
--   * touch: the card itself is a button that holds the prompt
--     (InputHoldBegin / InputHoldEnd)
-- PromptShown already respects Enabled, MaxActivationDistance and
-- RequiresLineOfSight, so a card exists exactly while Roblox would show one.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)
local Ui = script.Parent.Parent.Ui
local Screens = require(Ui.Screens)
local UiFx = require(Ui.UiFx)

local player = Players.LocalPlayer
local PIPS = 16
local POP_IN = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local POP_OUT = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local PIP_OFF = 0.75
local CARD_BASE = Color3.fromHex("FFFFFF")

local PAD_NAMES: { [string]: string } = {
	ButtonA = "A",
	ButtonB = "B",
	ButtonX = "X",
	ButtonY = "Y",
	ButtonL1 = "LB",
	ButtonR1 = "RB",
	ButtonL2 = "LT",
	ButtonR2 = "RT",
	ButtonL3 = "L3",
	ButtonR3 = "R3",
	DPadUp = "UP",
	DPadDown = "DN",
}
local KEY_NAMES: { [string]: string } = {
	One = "1",
	Two = "2",
	Three = "3",
	Four = "4",
	Five = "5",
	Return = "ENT",
	Space = "SPC",
	LeftShift = "SHF",
	Backspace = "BK",
}

type Card = {
	prompt: ProximityPrompt,
	gui: GuiObject,
	adornee: Instance,
	pop: UIScale,
	pips: { GuiObject },
	holding: RBXScriptConnection?,
	links: { RBXScriptConnection },
	closing: boolean,
}

local PromptController = Knit.CreateController({
	Name = "PromptController",
	_cards = {} :: { [ProximityPrompt]: Card },
	_layer = nil :: ScreenGui?,
	_hud = nil :: any,
})

-- the world point a card sits on, and whether the part is flat (a mat the player stands on:
-- the card then goes beside them on screen instead of over them)
local function anchorPoint(adornee: Instance): (Vector3?, boolean)
	if adornee:IsA("Attachment") then
		return adornee.WorldPosition + Vector3.new(0, 1.2, 0), false
	elseif adornee:IsA("BasePart") then
		local cf, size = adornee.CFrame, adornee.Size
		local tall = math.abs(cf.RightVector.Y) * size.X
			+ math.abs(cf.UpVector.Y) * size.Y
			+ math.abs(cf.LookVector.Y) * size.Z
		local flat = tall < 2
		return adornee.Position + Vector3.new(0, if flat then 1 else 1.2, 0), flat
	end
	return nil, false
end

function PromptController:_layerGui(): ScreenGui
	local layer = self._layer
	if layer and layer.Parent then
		return layer
	end
	local made = Instance.new("ScreenGui")
	made.Name = "PromptLayer"
	made.ResetOnSpawn = false
	made.IgnoreGuiInset = true
	made.DisplayOrder = 2
	made.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	made.Parent = player:WaitForChild("PlayerGui")
	self._layer = made
	return made
end

-- every frame: each card where its part is on screen (hidden behind the camera)
function PromptController:_place()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	-- no cards over a cinematic (the throw pad, a reveal, a rebirth): owner's review 4
	local hud = self._hud :: any
	local hidden = hud ~= nil
		and (
			(hud.IsCinematic ~= nil and hud:IsCinematic())
			or (hud.Mode ~= nil and hud:Mode() == "cinematic")
		)
	-- each card ON its object (owner's review 4: "far away from the object"); when two cards
	-- would overlap, the farther prompt's card moves down under the nearer one
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local placed: { { card: Card, x: number, y: number, d: number } } = {}
	for _, card in self._cards do
		local at = anchorPoint(card.adornee)
		local visible = false
		if at and not hidden then
			local point, onScreen = camera:WorldToViewportPoint(at)
			visible = onScreen and point.Z > 0
			if visible then
				local shift = card.prompt.UIOffset * 0.5
				local d = if root and root:IsA("BasePart")
					then (root.Position - at).Magnitude
					else 0
				table.insert(
					placed,
					{ card = card, x = point.X + shift.X, y = point.Y + shift.Y, d = d }
				)
			end
		end
		card.gui.Visible = visible
	end
	table.sort(placed, function(a, b)
		return a.d < b.d
	end)
	local boxes: { { x: number, y: number, w: number, h: number } } = {}
	for _, entry in placed do
		local size = entry.card.gui.AbsoluteSize
		local x, y = entry.x, entry.y
		for _ = 1, 6 do
			local moved = false
			for _, box in boxes do
				if
					math.abs(x - box.x) < (size.X + box.w) / 2
					and math.abs(y - box.y) < (size.Y + box.h) / 2
				then
					y = box.y + (box.h + size.Y) / 2 + 6
					moved = true
				end
			end
			if not moved then
				break
			end
		end
		table.insert(boxes, { x = x, y = y, w = size.X, h = size.Y })
		entry.card.gui.Position = UDim2.fromOffset(x, y)
	end
end

local function custom(prompt: Instance)
	if prompt:IsA("ProximityPrompt") and prompt.Style ~= Enum.ProximityPromptStyle.Custom then
		prompt.Style = Enum.ProximityPromptStyle.Custom
	end
end

-- the part (or attachment) the card hangs on
local function adorneeOf(prompt: ProximityPrompt): Instance?
	local parent = prompt.Parent
	if parent and (parent:IsA("BasePart") or parent:IsA("Attachment")) then
		return parent
	end
	if parent and parent:IsA("Model") then
		return parent.PrimaryPart or parent:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function keyText(prompt: ProximityPrompt, input: Enum.ProximityPromptInputType): string
	if input == Enum.ProximityPromptInputType.Gamepad then
		local name = prompt.GamepadKeyCode.Name
		return PAD_NAMES[name] or name:sub(1, 3):upper()
	end
	local name = prompt.KeyboardKeyCode.Name
	return KEY_NAMES[name] or (if #name <= 3 then name:upper() else name:sub(1, 3):upper())
end

function PromptController:_paint(card: Card)
	local prompt = card.prompt
	local gui = card.gui
	local accent = prompt:GetAttribute("Accent")
	local colour = if typeof(accent) == "Color3" then accent else nil
	local keycap = Screens.frame(gui, "KeyCap")
	Screens.tint(keycap, colour or CARD_BASE)
	local glow = Screens.image(gui, "Glow")
	glow.ImageColor3 = colour or Color3.new(1, 1, 1)
	glow.ImageTransparency = if colour then 0.35 else 0.65
	for _, pip in card.pips do
		pip.BackgroundColor3 = colour or Color3.new(1, 1, 1)
	end
end

function PromptController:_text(card: Card, input: Enum.ProximityPromptInputType)
	local prompt = card.prompt
	local gui = card.gui
	local action = Screens.label(gui, "ActionText")
	local object = Screens.label(gui, "ObjectText")
	action.Text = prompt.ActionText
	object.Text = prompt.ObjectText
	object.Visible = prompt.ObjectText ~= ""
	-- the action alone sits centred on the card
	local home = action:GetAttribute("HomePosition")
	if typeof(home) ~= "UDim2" then
		home = action.Position
		action:SetAttribute("HomePosition", home)
	end
	local at = home :: UDim2
	action.Position = if object.Visible
		then at
		else UDim2.new(at.X.Scale, at.X.Offset, 0.5, -action.Size.Y.Offset / 2)
	local touch = input == Enum.ProximityPromptInputType.Touch
	local key = Screens.label(gui, "KeyText")
	key.Visible = not touch
	key.Text = keyText(prompt, input)
	local icon = Screens.image(gui, "KeyIcon")
	icon.Visible = touch
	if touch then
		Screens.setIcon(icon, "FxTap")
		if icon.Image == "" then
			icon.Image = Screens.icon("FxTap")
		end
	end
	local ring = Screens.frame(gui, "HoldRing")
	ring.Visible = prompt.HoldDuration > 0
	for _, pip in card.pips do
		pip.BackgroundTransparency = PIP_OFF
	end
end

function PromptController:_show(prompt: ProximityPrompt, input: Enum.ProximityPromptInputType)
	local old = self._cards[prompt]
	if old then
		self:_drop(old, true)
	end
	local adornee = adorneeOf(prompt)
	local made = Screens.world("PromptCard")
	if not adornee or not made or not made:IsA("BillboardGui") then
		return
	end
	local template = made :: BillboardGui
	-- pixel sized (like Roblox's own prompts), scaled to the screen
	local camera = workspace.CurrentCamera
	-- smaller than before (owner's review 4: "too big")
	local k = 0.74 * (if camera then math.clamp(camera.ViewportSize.Y / 720, 0.62, 1.15) else 1)
	local canvas = Screens.frame(template, "CanvasFrame")
	local refW = canvas:GetAttribute("RefWidth")
	local refH = canvas:GetAttribute("RefHeight")
	local w = if typeof(refW) == "number" then refW else 350
	local h = if typeof(refH) == "number" then refH else 112
	local gui = Instance.new("Frame")
	gui.Name = "PromptCard"
	gui.BackgroundTransparency = 1
	gui.AnchorPoint = Vector2.new(0.5, 0.5)
	gui.Size = UDim2.fromOffset(w * k, h * k)
	gui.Visible = false
	canvas.Parent = gui
	template:Destroy()
	canvas.AnchorPoint = Vector2.new(0.5, 0.5)
	canvas.Position = UDim2.fromScale(0.5, 0.5)
	canvas.Size = UDim2.fromOffset(w, h)
	local fitScale = Instance.new("UIScale")
	fitScale.Name = "FitScale"
	fitScale.Scale = k
	fitScale.Parent = canvas
	local cardFrame = Screens.frame(gui, "Card")
	local pop = Instance.new("UIScale")
	pop.Name = "PopScale"
	pop.Scale = 0.4
	pop.Parent = cardFrame

	local pips: { GuiObject } = {}
	for i = 1, PIPS do
		local pip = gui:FindFirstChild("Pip" .. i, true)
		if pip and pip:IsA("GuiObject") then
			table.insert(pips, pip)
		end
	end
	local card: Card = {
		prompt = prompt,
		gui = gui,
		adornee = adornee,
		pop = pop,
		pips = pips,
		holding = nil,
		links = {},
		closing = false,
	}
	self._cards[prompt] = card
	self:_text(card, input)
	self:_paint(card)

	-- touch: the card is the button
	local hit = Instance.new("TextButton")
	hit.Name = "CardButton"
	hit.Text = ""
	hit.BackgroundTransparency = 1
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 30
	hit.Parent = cardFrame
	table.insert(
		card.links,
		hit.InputBegan:Connect(function(io: InputObject)
			if
				io.UserInputType == Enum.UserInputType.Touch
				or io.UserInputType == Enum.UserInputType.MouseButton1
			then
				prompt:InputHoldBegin()
			end
		end)
	)
	table.insert(
		card.links,
		hit.InputEnded:Connect(function(io: InputObject)
			if
				io.UserInputType == Enum.UserInputType.Touch
				or io.UserInputType == Enum.UserInputType.MouseButton1
			then
				prompt:InputHoldEnd()
			end
		end)
	)
	table.insert(
		card.links,
		prompt:GetAttributeChangedSignal("Accent"):Connect(function()
			self:_paint(card)
		end)
	)
	for _, prop in { "ActionText", "ObjectText", "HoldDuration" } do
		table.insert(
			card.links,
			prompt:GetPropertyChangedSignal(prop):Connect(function()
				self:_text(card, input)
			end)
		)
	end
	table.insert(
		card.links,
		prompt.Destroying:Connect(function()
			self:_drop(card, true)
		end)
	)

	gui.Parent = self:_layerGui()
	self:_place()
	UiFx.scan(gui)
	TweenService:Create(pop, POP_IN, { Scale = 1 }):Play()
	Screens.sound("prompt_show")
end

function PromptController:_drop(card: Card, now: boolean?)
	if card.closing then
		return
	end
	card.closing = true
	if self._cards[card.prompt] == card then
		self._cards[card.prompt] = nil
	end
	if card.holding then
		card.holding:Disconnect()
		card.holding = nil
	end
	for _, link in card.links do
		link:Disconnect()
	end
	if now then
		card.gui:Destroy()
		return
	end
	local out = TweenService:Create(card.pop, POP_OUT, { Scale = 0 })
	out.Completed:Once(function()
		card.gui:Destroy()
	end)
	out:Play()
end

function PromptController:_holdBegan(prompt: ProximityPrompt)
	local card = self._cards[prompt]
	if not card or prompt.HoldDuration <= 0 then
		return
	end
	if card.holding then
		card.holding:Disconnect()
	end
	local t0 = os.clock()
	local duration = prompt.HoldDuration
	card.holding = RunService.RenderStepped:Connect(function()
		local lit = math.floor(math.clamp((os.clock() - t0) / duration, 0, 1) * #card.pips + 0.5)
		for i, pip in card.pips do
			pip.BackgroundTransparency = if i <= lit then 0 else PIP_OFF
		end
	end)
	TweenService
		:Create(card.pop, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Scale = 0.95 })
		:Play()
end

function PromptController:_holdEnded(prompt: ProximityPrompt)
	local card = self._cards[prompt]
	if not card then
		return
	end
	if card.holding then
		card.holding:Disconnect()
		card.holding = nil
	end
	for _, pip in card.pips do
		pip.BackgroundTransparency = PIP_OFF
	end
	TweenService:Create(card.pop, POP_IN, { Scale = 1 }):Play()
end

function PromptController:_triggered(prompt: ProximityPrompt)
	local card = self._cards[prompt]
	Screens.sound("ui_click")
	if not card then
		return
	end
	card.pop.Scale = 0.86
	TweenService:Create(card.pop, POP_IN, { Scale = 1 }):Play()
	Screens.pop(Screens.frame(card.gui, "KeyCap"), 1.25)
end

function PromptController:KnitStart()
	Screens.init()
	self._hud = Knit.GetController("HudController")
	for _, d in workspace:GetDescendants() do
		custom(d)
	end
	workspace.DescendantAdded:Connect(custom)
	ProximityPromptService.PromptShown:Connect(
		function(prompt: ProximityPrompt, input: Enum.ProximityPromptInputType)
			custom(prompt)
			local ok, err = pcall(self._show, self, prompt, input)
			if not ok then
				warn(`[PromptController] card failed inert: {err}`)
			end
		end
	)
	RunService.RenderStepped:Connect(function()
		if next(self._cards) then
			self:_place()
		end
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
		local card = self._cards[prompt]
		if card then
			self:_drop(card)
		end
	end)
	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt: ProximityPrompt)
		self:_holdBegan(prompt)
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt: ProximityPrompt)
		self:_holdEnded(prompt)
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		self:_triggered(prompt)
	end)
end

return PromptController
