--!strict
-- Make - a few lines of plain code-built GUI, used ONLY by Ui/DevPanel (the
-- owner / Studio TEST panel, which is not a player screen and so is not in
-- design/ui). Every player-facing screen is an authored tree under src/ui,
-- reached through Ui/Screens. Nothing here is the game's look.

local Make = {}

Make.INK = Color3.fromRGB(13, 15, 43)
Make.PANEL = Color3.fromRGB(27, 31, 75)
Make.GOOD = Color3.fromRGB(52, 209, 122)
Make.BAD = Color3.fromRGB(240, 68, 56)
Make.BUY = Color3.fromRGB(255, 201, 60)
Make.INFO = Color3.fromRGB(56, 189, 248)

export type Props = { [string]: any }

-- No text under 13 px at the 720p reference: scaled text may shrink to fit
-- its box, but never below this.
local MIN_TEXT = 13

local function floorText(label: Instance)
	local floor = Instance.new("UITextSizeConstraint")
	floor.MinTextSize = MIN_TEXT
	floor.MaxTextSize = 100
	floor.Parent = label
end

local function apply(instance: Instance, props: Props?)
	if props then
		for key, value in props do
			(instance :: any)[key] = value
		end
	end
end

function Make.corner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

function Make.stroke(parent: Instance, thickness: number, color: Color3?)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness
	stroke.Color = color or Make.INK
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
end

function Make.frame(parent: Instance, props: Props?): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Make.PANEL
	frame.BorderSizePixel = 0
	apply(frame, props)
	frame.Parent = parent
	return frame
end

function Make.label(parent: Instance, text: string, props: Props?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Make.INK
	label.TextScaled = true
	label.Text = text
	apply(label, props)
	floorText(label)
	label.Parent = parent
	return label
end

function Make.button(parent: Instance, text: string, color: Color3, props: Props?): TextButton
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.FredokaOne
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextStrokeTransparency = 0
	button.TextStrokeColor3 = Make.INK
	button.TextScaled = true
	button.Text = text
	apply(button, props)
	floorText(button)
	Make.corner(button, 10)
	Make.stroke(button, 3)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = button
	button.Parent = parent
	return button
end

function Make.list(parent: Instance, direction: Enum.FillDirection, gap: number): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = direction
	layout.Padding = UDim.new(0, gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent
	return layout
end

function Make.screen(name: string, order: number): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = order
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- everything is laid out for 1280 x 720 and scaled to the real screen, so
	-- the test HUD is usable on a phone as well
	local scale = Instance.new("UIScale")
	scale.Parent = gui
	local function fit()
		local camera = workspace.CurrentCamera
		local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		scale.Scale = math.clamp(math.min(view.X / 1280, view.Y / 720), 0.45, 1.25)
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	return gui
end

return Make
