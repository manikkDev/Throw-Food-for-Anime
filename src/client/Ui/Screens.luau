--!strict
-- Screens - the authored UI (ReplicatedStorage.Ui, built from design/ui) at
-- runtime. Every controller reaches a screen through here and nowhere else.
--
-- What this owns, once, for every screen:
--   * one clone of each ScreenGui in PlayerGui, scaled to the real viewport
--     (each CanvasFrame is 1280 x 720 with a `Scale` UIScale)
--   * the mockup rows (attribute Sample=true) are destroyed
--   * every IconKey / PatternName slot gets its image from Config.Icons
--   * every dynamic label (shipped as "<unbound>") starts empty
--   * every button gets hover and press feedback from its attributes
--   * pages (UIKind="page"): one open at a time, OpensPage / ClosesPage
--     buttons, Tab or gamepad B closes
--
-- The finders (label, button, frame ...) never return nil: a name the tree
-- does not carry warns once and yields a detached instance, so a renamed
-- label costs one feature and never the whole client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Signal = require(ReplicatedStorage.Packages.Signal)
local Icons: { [string]: string } = require(ReplicatedStorage.Shared.Config.Icons)
local Theme = require(script.Parent.Theme)
local UiFx = require(script.Parent.UiFx)

local REF_WIDTH, REF_HEIGHT = 1280, 720
local OPEN_TIME, CLOSE_TIME, OPEN_FROM = 0.18, 0.1, 0.85
local BIG_ICON = 40 -- a slot this many px or more (at 720p) takes the `...Big` icon
local PRESS = TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local UNBOUND = "<unbound>" -- what every dynamic label ships showing
local HOVER_SOUND_GAP = 0.07 -- the least time between two ui_hover sounds
-- pages are capped on big screens: at most this share of the viewport (never
-- smaller than they are authored at 1280 x 720, so phones and laptops are untouched)
local PAGE_MAX_W, PAGE_MAX_H = 0.68, 0.82
-- v4.4 (owner's review 5: windows "kinda big"): every page window on a
-- keyboard / mouse screen is drawn at this share of the size worked out above
-- (8% smaller at 720p and on big monitors alike). Touch keeps its thumb-sized fill.
local PAGE_SCALE = 0.92
local SHINE_SECONDS = 0.8 -- a hover / press shine crossing a button

local player = Players.LocalPlayer

export type RowSet = {
	container: Instance,
	template: string,
	rows: { [string]: GuiObject },
}

local Screens = {}

Screens.Opened = Signal.new() -- (pageName)
Screens.Closed = Signal.new() -- (pageName)
Screens.Fitted = Signal.new() -- (extraWidth) after every rescale
Screens.Pressed = Signal.new() -- (button) any button on any screen was activated (click sound)

local phase = "idle" -- "idle" | "starting" | "ready"
local source: Instance? = nil
local screens: { [string]: ScreenGui } = {}
local openName: string? = nil
local backTo: string? = nil
local closing: { [ScreenGui]: Tween } = {}
local router: ((string, string?) -> string)? = nil
local warned: { [string]: boolean } = {}
local cameraConnection: RBXScriptConnection? = nil
-- On touch every page window is enlarged (a UIScale named TouchScale on the
-- page's Window) so its controls are big enough for a thumb. The same UIScale
-- carries the open and close pop: an instance can only have one.
local touchMode = false
local touchFactor: { [ScreenGui]: number } = {}
-- Screens whose edge groups hug the real screen edges, not the 16:9 canvas.
local EDGE_HUGGING: { [string]: boolean } = { HUD = true }
local authoredX: { [GuiObject]: UDim } = {}
local extraWidth = 0
local blocked = false -- pages cannot open (the HUD is in a cinematic)
local soundHook: ((string) -> ())? = nil
local lastHover = 0

-- ---------------------------------------------------------------- finders --

local function missing(root: Instance, name: string, class: string): Instance
	local key = `{root.Name}/{name}`
	if not warned[key] then
		warned[key] = true
		warn(`[Screens] {root.Name} has no {class} named {name}`)
	end
	local stand = Instance.new(class)
	stand.Name = name
	return stand
end

function Screens.label(root: Instance, name: string): TextLabel
	local found = root:FindFirstChild(name, true)
	if found and found:IsA("TextLabel") then
		return found
	end
	return missing(root, name, "TextLabel") :: TextLabel
end

function Screens.button(root: Instance, name: string): GuiButton
	local found = root:FindFirstChild(name, true)
	if found and found:IsA("GuiButton") then
		return found
	end
	return missing(root, name, "TextButton") :: TextButton
end

function Screens.frame(root: Instance, name: string): GuiObject
	local found = root:FindFirstChild(name, true)
	if found and found:IsA("GuiObject") then
		return found
	end
	return missing(root, name, "Frame") :: Frame
end

function Screens.image(root: Instance, name: string): ImageLabel
	local found = root:FindFirstChild(name, true)
	if found and found:IsA("ImageLabel") then
		return found
	end
	return missing(root, name, "ImageLabel") :: ImageLabel
end

function Screens.viewport(root: Instance, name: string): ViewportFrame
	local found = root:FindFirstChild(name, true)
	if found and found:IsA("ViewportFrame") then
		return found
	end
	return missing(root, name, "ViewportFrame") :: ViewportFrame
end

function Screens.scroller(root: Instance, name: string): ScrollingFrame
	local found = root:FindFirstChild(name, true)
	if found and found:IsA("ScrollingFrame") then
		return found
	end
	return missing(root, name, "ScrollingFrame") :: ScrollingFrame
end

function Screens.box(root: Instance, name: string): TextBox
	local found = root:FindFirstChild(name, true)
	if found and found:IsA("TextBox") then
		return found
	end
	return missing(root, name, "TextBox") :: TextBox
end

-- ------------------------------------------------------------------ sound --

--- Who plays UI sounds (HudController hands the SoundController in; Screens
--- cannot require it, the SoundController requires Screens).
function Screens.setSound(play: (string) -> ())
	soundHook = play
end

--- Play a sound role through the hook (silent before it is set).
function Screens.sound(role: string)
	local play = soundHook
	if play then
		pcall(play, role)
	end
end

-- --------------------------------------------------------------- painting --

--- The image for an IconKey / PatternName, or "" (the slot stays blank).
function Screens.icon(key: string): string
	return Icons[key] or ""
end

--- Put the icon for `key` in a slot. The icon bank has two families: flat
--- glyphs under the base key and large glossy ones under `<key>Big`. A slot
--- of 40 px or more takes the Big one when there is one; a smaller slot
--- always takes the flat glyph. Callers pass either spelling.
function Screens.setIcon(image: ImageLabel, key: string)
	local base = (key:gsub("Big$", ""))
	local size = math.min(image.Size.X.Offset, image.Size.Y.Offset)
	if size <= 0 then
		size = math.min(image.AbsoluteSize.X, image.AbsoluteSize.Y)
	end
	local big = if size >= BIG_ICON then Icons[base .. "Big"] else nil
	image.Image = big or Icons[base] or ""
end

-- A control's FACE carries its colour: the `Face` child (cards, rows, the
-- buttons built around one) or the control itself (self-faced buttons,
-- chips, ribbons). Its LIP is the darker slab under the face: the `Shadow`
-- beside the face, which for a self-faced control sits in its `<Name>Cell`.
local function faceOf(control: GuiObject): GuiObject
	local face = control:FindFirstChild("Face")
	return if face and face:IsA("GuiObject") then face else control
end

local function lipOf(control: GuiObject): GuiObject?
	local own = control:FindFirstChild("Shadow")
	if own and own:IsA("GuiObject") then
		return own
	end
	local cell = control.Parent
	if cell and cell.Name == control.Name .. "Cell" then
		local under = cell:FindFirstChild("Shadow")
		if under and under:IsA("GuiObject") then
			return under
		end
	end
	return nil
end

--- Recolour a control: its face, and its lip in the matching darker shade.
--- nil puts back exactly what the tree shipped (face and lip). For cards,
--- tiles, chips, ribbons and toasts; buttons go through setButtonState.
function Screens.tint(control: GuiObject, color: Color3?)
	local face = faceOf(control)
	local lip = lipOf(control)
	if typeof(control:GetAttribute("ShippedFace")) ~= "Color3" then
		control:SetAttribute("ShippedFace", face.BackgroundColor3)
		if lip then
			control:SetAttribute("ShippedLip", lip.BackgroundColor3)
		end
	end
	-- v4.2: a button's rim is a pale tint of its own face colour (attribute Rim =
	-- how pale), so it follows every repaint
	local rim = control:GetAttribute("Rim")
	local cell = control.Parent
	if typeof(rim) ~= "number" and cell and cell.Name == control.Name .. "Cell" then
		rim = cell:GetAttribute("Rim")
	end
	if typeof(rim) == "number" then
		local stroke: UIStroke? = nil
		for _, child in face:GetChildren() do
			if child:IsA("UIStroke") and child.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then
				stroke = child
			end
		end
		if stroke then
			local base = color or control:GetAttribute("ShippedFace") :: Color3
			stroke.Color = base:Lerp(Color3.new(1, 1, 1), rim)
		end
	end
	if color then
		face.BackgroundColor3 = color
		if lip then
			lip.BackgroundColor3 = Theme.lip(color)
		end
	else
		face.BackgroundColor3 = control:GetAttribute("ShippedFace") :: Color3
		local shippedLip = control:GetAttribute("ShippedLip")
		if lip and typeof(shippedLip) == "Color3" then
			lip.BackgroundColor3 = shippedLip
		end
	end
end

-- the caption and the icon of a button face (a two-line button keeps them
-- in its PriceRow)
local function captionOf(face: GuiObject): TextLabel?
	local row = face:FindFirstChild("PriceRow")
	return (row or face):FindFirstChildWhichIsA("TextLabel")
end

local function iconOf(face: GuiObject): ImageLabel?
	local row = face:FindFirstChild("PriceRow")
	local icon = (row or face):FindFirstChild("Icon")
	return if icon and icon:IsA("ImageLabel") then icon else nil
end

-- buttons whose face is pressed down by their PressLip: how to let go
-- (a strong table: a weak Instance key is dropped when its Luau wrapper is collected)
local pressRest: { [GuiObject]: () -> () } = {}

--- THE way a button shows what it is (Theme.BUTTON): "afford", "cannot",
--- "neutral", "robux", "danger", "off", "idle", "panel", "gold"; "state" for
--- something that is no longer a button (EQUIPPED, CLAIMED, OWNED: a flat
--- grey pill with a tick, not pressable); "shipped" for the colour the tree
--- gave it. Paints the face and the lip, writes `caption` when given, turns
--- the caption soft red on "cannot", and sets the icon (`iconKey`, else the
--- tick for a state, else the icon the tree shipped).
function Screens.setButtonState(
	button: GuiObject,
	state: string,
	caption: string?,
	iconKey: string?
)
	local face = faceOf(button)
	Screens.tint(button, Theme.BUTTON[state])

	local isState = state == "state"
	local lip = lipOf(button)
	if lip then
		lip.Visible = not isState
	end
	if button.Active == isState then
		button.Active = not isState
		local rest = pressRest[button]
		if rest then
			rest()
		end
	end

	local label = captionOf(face)
	if label then
		if caption then
			label.Text = caption
		end
		local shippedText = label:GetAttribute("ShippedText")
		if typeof(shippedText) ~= "Color3" then
			shippedText = label.TextColor3
			label:SetAttribute("ShippedText", shippedText)
		end
		label.TextColor3 = if state == "cannot" then Theme.SOFT_RED else shippedText :: Color3
	end
	local icon = iconOf(face)
	if icon then
		local key = iconKey or (if isState then "IconTick" else icon:GetAttribute("IconKey"))
		if typeof(key) == "string" then
			Screens.setIcon(icon, key)
		end
	end
end

--- Set a bar's `Fill` to a fraction. Fills ship inset 3 px inside their bar.
function Screens.fill(fill: GuiObject, fraction: number)
	local f = math.clamp(fraction, 0, 1)
	fill.Visible = f > 0.005
	fill.Size = UDim2.new(f, -6 * f, 1, -6)
end

--- Fade a label and its outline together (a UIStroke does not follow
--- TextTransparency).
function Screens.fadeText(label: TextLabel, from: number, to: number, seconds: number)
	local info = TweenInfo.new(seconds)
	label.TextTransparency = from
	TweenService:Create(label, info, { TextTransparency = to }):Play()
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = from
		TweenService:Create(stroke, info, { Transparency = to }):Play()
	end
end

--- A quick pop: the element jumps to `from` times its size and settles back.
function Screens.pop(target: GuiObject, from: number)
	local scale = target:FindFirstChild("PopScale")
	if not scale or not scale:IsA("UIScale") then
		local made = Instance.new("UIScale")
		made.Name = "PopScale"
		made.Parent = target
		scale = made
	end
	local uiScale = scale :: UIScale
	uiScale.Scale = from
	TweenService:Create(
		uiScale,
		TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()
end

--- 754 -> "12:34", 3723 -> "1:02:03".
function Screens.clock(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	if s >= 3600 then
		return string.format("%d:%02d:%02d", s // 3600, (s % 3600) // 60, s % 60)
	end
	return string.format("%d:%02d", s // 60, s % 60)
end

-- ---------------------------------------------------------------- buttons --

local function easing(name: any): Enum.EasingStyle
	local ok, style = pcall(function()
		return (Enum.EasingStyle :: any)[name]
	end)
	return if ok and style then style else Enum.EasingStyle.Quad
end

-- Where a button's visual parts live. A self-faced button sits in a
-- `<Name>Cell` with its lip (Shadow) beside it: the cell holds the parts. A
-- button built around a `Face` holds its own Face and Shadow. Scaling and
-- shining the PARTS (never the laid-out button or cell) keeps a list layout
-- from reflowing and lets a hover grow from the centre.
local function partsOf(button: GuiButton): ({ GuiObject }, Instance?, GuiObject)
	local face = faceOf(button)
	local holder: Instance? = nil
	if face ~= button then
		holder = button
	else
		local cell = button.Parent
		if cell and cell:IsA("GuiObject") and cell.Name == button.Name .. "Cell" then
			holder = cell
		end
	end
	local parts: { GuiObject } = {}
	if holder then
		for _, child in holder:GetChildren() do
			if child:IsA("GuiObject") then
				table.insert(parts, child)
			end
		end
	else
		parts = { button }
	end
	return parts, holder, face
end

-- Re-anchor a part on its centre without moving it, so a UIScale on it grows
-- from the middle (a UIScale scales about the AnchorPoint). Not for a part a
-- layout places.
local function centreAnchor(part: GuiObject)
	local parent = part.Parent
	if parent and parent:FindFirstChildWhichIsA("UIGridStyleLayout") then
		return
	end
	local a = part.AnchorPoint
	if a.X == 0.5 and a.Y == 0.5 then
		return
	end
	local size = part.Size
	part.Position = part.Position
		+ UDim2.new(
			(0.5 - a.X) * size.X.Scale,
			(0.5 - a.X) * size.X.Offset,
			(0.5 - a.Y) * size.Y.Scale,
			(0.5 - a.Y) * size.Y.Offset
		)
	part.AnchorPoint = Vector2.new(0.5, 0.5)
end

local function scaleOf(part: GuiObject): UIScale
	local found = part:FindFirstChildOfClass("UIScale")
	if found then
		return found
	end
	local made = Instance.new("UIScale")
	made.Name = "MotionScale"
	made.Parent = part
	return made
end

-- Press feedback of the v3 button system: the face (and its shine) goes down
-- by the button's PressLip (onto its lip) while the button is held, and comes
-- back when it is let go or the pointer leaves. Mouse and touch both arrive as
-- MouseButton1 on a GuiButton. Returns false for a button with no lip.
local function wirePress(button: GuiButton, face: GuiObject, overlays: { GuiObject }): boolean
	local lip = button:GetAttribute("PressLip")
	local cell = button.Parent
	if typeof(lip) ~= "number" and cell and cell.Name == button.Name .. "Cell" then
		lip = cell:GetAttribute("PressLip")
	end
	if typeof(lip) ~= "number" then
		return false
	end
	local moving: { GuiObject } = { face }
	for _, layer in overlays do
		table.insert(moving, layer)
	end
	local ups: { UDim2 } = {}
	for i, part in moving do
		ups[i] = part.Position
	end
	local function move(down: boolean)
		for i, part in moving do
			local to = if down then ups[i] + UDim2.fromOffset(0, lip) else ups[i]
			TweenService:Create(part, PRESS, { Position = to }):Play()
		end
	end
	button.MouseButton1Down:Connect(function()
		move(true)
	end)
	button.MouseButton1Up:Connect(function()
		move(false)
	end)
	button.MouseLeave:Connect(function()
		move(false)
	end)
	pressRest[button] = function()
		for i, part in moving do
			part.Position = ups[i]
		end
	end
	return true
end

local function wireMotion(button: GuiButton)
	local hoverScale = button:GetAttribute("HoverScale")
	local parts, holder, face = partsOf(button)
	-- every part re-anchored on its centre BEFORE the press positions are taken
	if holder then
		for _, part in parts do
			centreAnchor(part)
		end
	end
	-- the permanent gloss and the soft shine streak, laid over the face (siblings,
	-- so the face's own layout never moves them). The shine crosses on hover and
	-- once on a press; it never runs on a timer (owner's review 3).
	local shine: Frame? = nil
	local overlays: { GuiObject } = {}
	-- v4.3: the gloss and the shine go ONLY on a painted face. A transparent
	-- button (the HUD's food chip, a tile that is all icon and text) has no
	-- surface to light, and an opaque white layer the size of its box showed as
	-- a translucent white panel across it (owner's review 4). Opt out of either
	-- per button with the attribute Gloss = false.
	local painted = face.BackgroundTransparency < 0.95
		or (face:IsA("ImageButton") and (face :: ImageButton).Image ~= "")
		or (face:IsA("ImageLabel") and (face :: ImageLabel).Image ~= "")
	if button:GetAttribute("Gloss") == false or not painted then
		holder = nil
	end
	if holder then
		local gloss = UiFx.makeGloss(face, holder)
		local made = UiFx.makeShine(face, holder)
		shine = made
		for _, layer in { gloss :: GuiObject, made :: GuiObject } do
			table.insert(overlays, layer)
			if not table.find(parts, layer) then
				table.insert(parts, layer)
			end
		end
	elseif
		painted
		and button:GetAttribute("Gloss") ~= false
		and not face:FindFirstChildWhichIsA("UIGridStyleLayout")
		and face:IsA("GuiButton")
	then
		-- a lone self-faced button (no cell, no layout inside): the layers go inside it
		UiFx.makeGloss(face, face, true)
		shine = UiFx.makeShine(face, face, true)
	end
	if shine then
		button.Activated:Connect(function()
			UiFx.sweep(shine :: Frame, SHINE_SECONDS)
		end)
	end
	-- a button with a lip is pressed DOWN, not shrunk
	local pressScale = if wirePress(button, face, overlays)
		then nil
		else button:GetAttribute("PressScale")
	if typeof(hoverScale) ~= "number" and typeof(pressScale) ~= "number" then
		return
	end
	local scales: { UIScale } = {}
	for _, part in parts do
		table.insert(scales, scaleOf(part))
	end
	local hoverTime = button:GetAttribute("HoverTime")
	local pressTime = button:GetAttribute("PressTime")
	local hoverInfo = TweenInfo.new(
		if typeof(hoverTime) == "number" then math.max(hoverTime, 0.14) else 0.14,
		easing(button:GetAttribute("HoverStyle")),
		Enum.EasingDirection.Out
	)
	local pressInfo = TweenInfo.new(
		if typeof(pressTime) == "number" then pressTime else 0.08,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
	local function scaleTo(value: number, info: TweenInfo)
		for _, scale in scales do
			TweenService:Create(scale, info, { Scale = value }):Play()
		end
	end
	local hovered = false
	local function rest()
		scaleTo(if hovered and typeof(hoverScale) == "number" then hoverScale else 1, hoverInfo)
	end
	button.MouseEnter:Connect(function()
		hovered = true
		rest()
		if button.Active then
			if shine then
				UiFx.sweep(shine, SHINE_SECONDS)
			end
			local now = os.clock()
			if now - lastHover >= HOVER_SOUND_GAP then
				lastHover = now
				Screens.sound("ui_hover")
			end
		end
	end)
	button.MouseLeave:Connect(function()
		hovered = false
		rest()
	end)
	if typeof(pressScale) == "number" then
		button.MouseButton1Down:Connect(function()
			scaleTo(pressScale, pressInfo)
		end)
		button.MouseButton1Up:Connect(rest)
	end
end

-- A button caption (attribute FitText = its size) grows with its text up to
-- its UISizeConstraint; a string too long for that shrinks its TextSize until
-- it fits, so a caption never spills out of its button.
local function fitText(label: TextLabel)
	local cap = label:GetAttribute("FitText")
	if typeof(cap) ~= "number" then
		return
	end
	-- measured with TextService, never TextFits: TextFits is false while the label is hidden or its
	-- font is still loading, which shrank every caption to the floor (found in play 2026-11-16)
	local limit = label:FindFirstChildOfClass("UISizeConstraint")
	local token = 0
	local function fit()
		token += 1
		local mine = token
		label.TextSize = cap
		local room = if limit then limit.MaxSize.X else math.huge
		if room == math.huge or label.Text == "" then
			return
		end
		task.spawn(function()
			local size = cap
			while size > 12 do
				local params = Instance.new("GetTextBoundsParams")
				params.Text = label.Text
				params.Font = label.FontFace
				params.Size = size
				params.Width = 100000
				local ok, bounds = pcall(TextService.GetTextBoundsAsync, TextService, params)
				if mine ~= token or not ok or bounds.X <= room then
					break
				end
				size -= 2
			end
			if mine == token then
				label.TextSize = size
			end
		end)
	end
	label:GetPropertyChangedSignal("Text"):Connect(fit)
	fit()
end

local function pageOf(instance: Instance): string?
	local gui = instance:FindFirstAncestorWhichIsA("ScreenGui")
	if gui and gui:GetAttribute("UIKind") == "page" then
		return gui.Name
	end
	return nil
end

local function wireButton(button: GuiButton)
	wireMotion(button)
	button.Activated:Connect(function()
		Screens.Pressed:Fire(button)
	end)
	local opens = button:GetAttribute("OpensPage")
	if typeof(opens) == "string" then
		button.Activated:Connect(function()
			Screens.switch(opens, pageOf(button))
		end)
	end
	if button:GetAttribute("ClosesPage") == true then
		button.Activated:Connect(function()
			Screens.close()
		end)
	end
end

-- Rows that scroll SIDEWAYS (attribute WheelScrollsX). Roblox only scrolls a
-- ScrollingFrame up and down with the mouse wheel, so for these the wheel is
-- read here: while the pointer is over the row, each notch moves it about
-- one card along, eased. Touch drag needs nothing: it is native.
local wheelRows: { ScrollingFrame } = {}
local wheelGoal: { [ScrollingFrame]: number } = {}
local wheelTween: { [ScrollingFrame]: Tween } = {}
local WHEEL = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- one notch: the width of a card plus the gap to the next (canvas units)
local function wheelStep(row: ScrollingFrame): number
	local layout = row:FindFirstChildOfClass("UIListLayout")
	local gap = if layout then layout.Padding.Offset else 0
	for _, child in row:GetChildren() do
		if child:IsA("GuiObject") and child.Visible and child.Size.X.Offset > 0 then
			return child.Size.X.Offset + gap
		end
	end
	return 200
end

local function onWheel(notches: number)
	local pointer = UserInputService:GetMouseLocation()
	for _, row in wheelRows do
		local gui = row:FindFirstAncestorWhichIsA("ScreenGui")
		local from, size = row.AbsolutePosition, row.AbsoluteSize
		if
			gui
			and gui.Enabled
			and pointer.X >= from.X
			and pointer.X <= from.X + size.X
			and pointer.Y >= from.Y
			and pointer.Y <= from.Y + size.Y
		then
			-- from where the row is heading if it is still moving, else from
			-- where it is; wheel down goes along the row, wheel up comes back
			local moving = wheelTween[row]
			local base = if moving and moving.PlaybackState == Enum.PlaybackState.Playing
				then wheelGoal[row]
				else row.CanvasPosition.X
			local goal = math.max(0, base - notches * wheelStep(row))
			wheelGoal[row] = goal
			if moving then
				moving:Cancel()
			end
			local tween = TweenService:Create(
				row,
				WHEEL,
				{ CanvasPosition = Vector2.new(goal, row.CanvasPosition.Y) }
			)
			wheelTween[row] = tween
			tween:Play()
			return
		end
	end
end

--- Make a cloned tree live: drop the mockup rows, fill icons and patterns,
--- wire its buttons. Called once per screen and once per template clone.
function Screens.prepare(root: Instance)
	for _, descendant in root:GetDescendants() do
		if descendant:GetAttribute("Sample") == true then
			descendant:Destroy()
		end
	end
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("ImageLabel") then
			local iconKey = descendant:GetAttribute("IconKey")
			local pattern = descendant:GetAttribute("PatternName")
			if typeof(iconKey) == "string" then
				-- a food slot ships as FoodIcon_<id>; the bank names it Food_<id>
				descendant.Image = Icons[iconKey]
					or Icons[(iconKey:gsub("^FoodIcon_", "Food_"))]
					or ""
			elseif typeof(pattern) == "string" then
				descendant.Image = Icons[pattern] or ""
			end
		elseif descendant:IsA("GuiButton") then
			wireButton(descendant)
		elseif descendant:IsA("ScrollingFrame") then
			if descendant:GetAttribute("WheelScrollsX") == true then
				table.insert(wheelRows, descendant)
			end
		elseif descendant:IsA("TextLabel") then
			if descendant.Text == UNBOUND then
				-- a dynamic label ships with a placeholder: it is empty until
				-- the code that owns it has real data to show
				descendant.Text = ""
			end
			fitText(descendant)
		end
	end
	UiFx.scan(root)
end

-- ------------------------------------------------------------------ scale --

-- The canvas is 16:9 and centred, so on a wider window everything laid out
-- from its left or right edge sits inset from the screen edge. Widen the
-- canvas to the whole viewport and keep each top-level group its authored
-- distance from the edge it belongs to: groups in the left third stay put
-- (they are placed from the left), groups in the right third move out with
-- the right edge, and the middle stays in the middle. Groups placed by scale
-- (0.5, 1) follow the wider canvas by themselves.
local function hugEdges(canvas: GuiObject, extra: number)
	local refWidth = canvas:GetAttribute("RefWidth")
	local width = if typeof(refWidth) == "number" then refWidth else REF_WIDTH
	canvas.Size = UDim2.new(0, width + extra, canvas.Size.Y.Scale, canvas.Size.Y.Offset)
	for _, child in canvas:GetChildren() do
		if child:IsA("GuiObject") then
			local x = authoredX[child]
			if not x then
				x = child.Position.X
				authoredX[child] = x
			end
			if x.Scale == 0 then
				local span = child.Size.X.Offset
				local centre = x.Offset + (0.5 - child.AnchorPoint.X) * span
				local shift = if centre > width * 2 / 3
					then extra
					elseif centre > width / 3 then extra / 2
					else 0
				child.Position =
					UDim2.new(0, x.Offset + shift, child.Position.Y.Scale, child.Position.Y.Offset)
			end
		end
	end
end

--- How much wider than the 16:9 canvas the screen is, in canvas pixels.
function Screens.extraWidth(): number
	return extraWidth
end

local function fit()
	local camera = workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(REF_WIDTH, REF_HEIGHT)
	if view.X < 1 or view.Y < 1 then
		return
	end
	local scale = math.min(view.X / REF_WIDTH, view.Y / REF_HEIGHT)
	extraWidth = math.max(0, view.X / scale - REF_WIDTH)
	for name, gui in screens do
		local canvas = gui:FindFirstChild("CanvasFrame")
		local uiScale = canvas and canvas:FindFirstChild("Scale")
		if uiScale and uiScale:IsA("UIScale") then
			uiScale.Scale = scale
		end
		if EDGE_HUGGING[name] and canvas and canvas:IsA("GuiObject") then
			hugEdges(canvas, extraWidth)
		end
		-- the canvas is letterboxed on anything that is not 16:9; the scrim
		-- behind a page still has to cover the whole screen
		local scrim = canvas and canvas:FindFirstChild("Scrim")
		if scrim and scrim:IsA("GuiObject") then
			scrim.AnchorPoint = Vector2.new(0.5, 0.5)
			scrim.Position = UDim2.fromScale(0.5, 0.5)
			scrim.Size = UDim2.fromOffset(view.X / scale + 4, view.Y / scale + 4)
		end
		-- touch: the window grows to fill up to 94% x 90% of the screen
		local window = canvas and canvas:FindFirstChild("Window")
		if window and window:IsA("GuiObject") then
			local width, height = window.Size.X.Offset, window.Size.Y.Offset
			local factor = 1
			if touchMode and width > 0 and height > 0 then
				factor = math.max(
					1,
					math.min(0.94 * view.X / (width * scale), 0.90 * view.Y / (height * scale))
				)
			elseif width > 0 and height > 0 and gui:GetAttribute("UIKind") == "page" then
				-- a stable size on a big monitor: at most PAGE_MAX_W x PAGE_MAX_H of
				-- the screen, never below the authored 720p pixel size
				local cap = math.min(
					PAGE_MAX_W * view.X / (width * scale),
					PAGE_MAX_H * view.Y / (height * scale)
				)
				factor = PAGE_SCALE * math.min(1, math.max(1 / scale, cap))
			end
			touchFactor[gui] = factor
			local touch = window:FindFirstChild("TouchScale")
			if touch and touch:IsA("UIScale") and gui.Enabled and not closing[gui] then
				touch.Scale = factor
			end
		end
	end
	Screens.Fitted:Fire(extraWidth)
end

-- touch or not, from the last thing the player used; other input kinds
-- (focus, text, sensors) leave it as it was
local function readInput(kind: Enum.UserInputType)
	local now = touchMode
	if kind == Enum.UserInputType.Touch then
		now = true
	elseif
		kind == Enum.UserInputType.Keyboard
		or kind == Enum.UserInputType.MouseMovement
		or kind == Enum.UserInputType.MouseButton1
		or kind == Enum.UserInputType.MouseButton2
		or kind == Enum.UserInputType.MouseWheel
		or kind == Enum.UserInputType.Gamepad1
	then
		now = false
	end
	if now ~= touchMode then
		touchMode = now
		fit()
	end
end

local function watchCamera()
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end
	local camera = workspace.CurrentCamera
	if camera then
		cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	fit()
end

-- ------------------------------------------------------------------ pages --

local function windowScale(gui: ScreenGui): UIScale?
	local canvas = gui:FindFirstChild("CanvasFrame")
	local window = canvas and canvas:FindFirstChild("Window")
	if not window then
		return nil
	end
	local scale = window:FindFirstChild("TouchScale")
	if not scale then
		local made = Instance.new("UIScale")
		made.Name = "TouchScale"
		made.Scale = touchFactor[gui] or 1
		made.Parent = window
		scale = made
	end
	return if scale:IsA("UIScale") then scale else nil
end

local function show(gui: ScreenGui)
	local pending = closing[gui]
	if pending then
		closing[gui] = nil
		pending:Cancel()
	end
	local scale = windowScale(gui)
	local from = gui:GetAttribute("OpenFrom")
	local seconds = gui:GetAttribute("OpenTime")
	local full = touchFactor[gui] or 1
	if scale and gui:GetAttribute("OpenStyle") ~= "instant" then
		scale.Scale = full * (if typeof(from) == "number" then from else OPEN_FROM)
		gui.Enabled = true
		TweenService:Create(
			scale,
			TweenInfo.new(
				if typeof(seconds) == "number" then seconds else OPEN_TIME,
				Enum.EasingStyle.Back,
				Enum.EasingDirection.Out
			),
			{ Scale = full }
		):Play()
	else
		if scale then
			scale.Scale = full
		end
		gui.Enabled = true
	end
end

local function hide(gui: ScreenGui)
	local scale = windowScale(gui)
	if not scale or gui:GetAttribute("OpenStyle") == "instant" then
		gui.Enabled = false
		return
	end
	local tween = TweenService:Create(
		scale,
		TweenInfo.new(CLOSE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Scale = (touchFactor[gui] or 1) * OPEN_FROM }
	)
	closing[gui] = tween
	tween.Completed:Once(function(playback: Enum.PlaybackState)
		if closing[gui] == tween then
			closing[gui] = nil
			if playback == Enum.PlaybackState.Completed then
				gui.Enabled = false
			end
		end
	end)
	tween:Play()
end

--- Open a page (closing whichever page is open). `from` is the page whose
--- button opened it: closing the new page returns there.
function Screens.open(name: string, from: string?)
	Screens.init()
	if blocked then
		return -- the HUD is in a cinematic: no page opens over it
	end
	local gui = screens[name]
	if not gui or gui:GetAttribute("UIKind") ~= "page" then
		warn(`[Screens] no page named {name}`)
		return
	end
	if openName == name then
		return
	end
	local previous = openName
	if previous then
		openName = nil
		hide(screens[previous])
		Screens.Closed:Fire(previous)
	end
	backTo = if from ~= name then from else nil
	openName = name
	show(gui)
	Screens.Opened:Fire(name)
end

--- Close the open page. A page opened from another page returns to it.
function Screens.close()
	local name = openName
	if not name then
		return
	end
	local back = backTo
	openName = nil
	backTo = nil
	hide(screens[name])
	Screens.Closed:Fire(name)
	if back then
		Screens.open(back)
	end
end

--- What an OpensPage button does: open the page, or close it if it is open.
function Screens.switch(name: string, from: string?)
	local target = if router then router(name, from) else name
	if openName == target or openName == name then
		backTo = nil
		Screens.close()
	else
		Screens.open(target, from)
	end
end

--- While blocked (the HUD is in a cinematic) no page opens, and an open
--- page closes.
function Screens.setBlocked(on: boolean)
	blocked = on
	if on and openName then
		backTo = nil
		Screens.close()
	end
end

--- True while pages are blocked.
function Screens.isBlocked(): boolean
	return blocked
end

--- Let the game decide which page a button really opens (name, fromPage).
function Screens.setRouter(handler: (string, string?) -> string)
	router = handler
end

--- True while a page is open (or while `name` is the open page).
function Screens.isOpen(name: string?): boolean
	if name then
		return openName == name
	end
	return openName ~= nil
end

--- The open page's name, if any.
function Screens.current(): string?
	return openName
end

-- ------------------------------------------------------------- lifecycles --

--- The live ScreenGui for a screen. Never nil: an unknown name warns and
--- returns a detached, disabled ScreenGui.
function Screens.get(name: string): ScreenGui
	Screens.init()
	local gui = screens[name]
	if gui then
		return gui
	end
	local stand = missing(player, name, "ScreenGui") :: ScreenGui
	stand.Enabled = false
	screens[name] = stand
	return stand
end

--- A fresh, prepared clone of a row / card template (not parented).
function Screens.template(name: string): GuiObject
	Screens.init()
	local folder = source and source:FindFirstChild("Templates")
	local found = folder and folder:FindFirstChild(name)
	if found and found:IsA("GuiObject") then
		local clone = found:Clone()
		Screens.prepare(clone)
		return clone
	end
	return missing(player, name, "Frame") :: Frame
end

--- A fresh, prepared clone of a world gui (Nameplate, Leaderboard, SlotSign),
--- not parented. Nil when the tree is not there.
function Screens.world(name: string): LayerCollector?
	Screens.init()
	local found = source and source:FindFirstChild(name)
	if found and (found:IsA("BillboardGui") or found:IsA("SurfaceGui")) then
		local clone = found:Clone()
		Screens.prepare(clone)
		return clone
	end
	return nil
end

--- A keyed list inside `container`, built from `template`.
function Screens.rows(container: Instance, template: string): RowSet
	return { container = container, template = template, rows = {} }
end

--- Bring a keyed list in line with `keys`, IN PLACE: a row is created the
--- first time its key appears and then only updated, so a scroll position
--- or a half-typed code survives every snapshot. Rows whose key is gone are
--- destroyed, or only hidden when `keep` is set (their viewports stay built).
function Screens.syncRows(
	set: RowSet,
	keys: { string },
	update: (row: GuiObject, key: string, index: number, isNew: boolean) -> (),
	keep: boolean?
)
	local seen: { [string]: boolean } = {}
	for index, key in keys do
		seen[key] = true
		local row = set.rows[key]
		local isNew = row == nil
		if not row then
			row = Screens.template(set.template)
			row.Name = "Row_" .. key
			set.rows[key] = row
		end
		row.LayoutOrder = index
		row.Visible = true
		update(row, key, index, isNew)
		if isNew then
			row.Parent = set.container
		end
	end
	for key, row in set.rows do
		if not seen[key] then
			if keep then
				row.Visible = false
			else
				set.rows[key] = nil
				row:Destroy()
			end
		end
	end
end

--- Clone every screen into PlayerGui. Safe to call from every controller.
function Screens.init()
	if phase == "ready" then
		return
	end
	if phase == "starting" then
		while phase ~= "ready" do
			task.wait()
		end
		return
	end
	phase = "starting"
	local ui = ReplicatedStorage:WaitForChild("Ui", 10)
	local playerGui = player:WaitForChild("PlayerGui")
	if not ui then
		warn("[Screens] ReplicatedStorage.Ui is missing: there is no UI")
		phase = "ready"
		return
	end
	source = ui
	for _, child in ui:GetChildren() do
		if child:IsA("ScreenGui") then
			local gui = child:Clone()
			gui.ResetOnSpawn = false
			if gui:GetAttribute("UIKind") == "page" then
				gui.Enabled = false
				local canvas = gui:FindFirstChild("CanvasFrame")
				local scrim = canvas and canvas:FindFirstChild("Scrim")
				if scrim and scrim:IsA("GuiObject") then
					scrim.Active = true -- a page swallows taps meant for the world
				end
			end
			Screens.prepare(gui)
			screens[gui.Name] = gui
			gui.Parent = playerGui
		end
	end
	phase = "ready"

	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	touchMode = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	watchCamera()
	UserInputService.LastInputTypeChanged:Connect(readInput)
	readInput(UserInputService:GetLastInputType())
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseWheel and #wheelRows > 0 then
			onWheel(input.Position.Z)
		end
	end)

	-- the shared UI motion loop (UiFx) runs while a page is open
	Screens.Opened:Connect(function()
		UiFx.activate("page", true)
	end)
	Screens.Closed:Connect(function()
		if not openName then
			UiFx.activate("page", false)
		end
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject)
		if not openName then
			return
		end
		-- Tab closes too, unless the player is typing a code
		local tab = input.KeyCode == Enum.KeyCode.Tab
			and UserInputService:GetFocusedTextBox() == nil
		if tab or input.KeyCode == Enum.KeyCode.ButtonB then
			Screens.close()
		end
	end)
end

return Screens
