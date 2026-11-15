--!strict
-- Settings - two volume sliders and the toggles. A slider moves locally while
-- it is dragged and sends ONE SettingSet when it is let go; a toggle sends
-- its new value and shows it when the next snapshot says so.

local UserInputService = game:GetService("UserInputService")

local Screens = require(script.Parent.Parent.Screens)
local Types = require(script.Parent.Types)

type Slider = {
	key: string,
	bar: GuiObject,
	knob: GuiButton,
	fill: GuiObject,
	value: TextLabel,
}

local SLIDERS = {
	{ key = "music", bar = "MusicSlider", knob = "MusicKnob", value = "MusicValue" },
	{ key = "sfx", bar = "SfxSlider", knob = "SfxKnob", value = "SfxValue" },
}
local TOGGLES = {
	{ key = "fastReveal", button = "FastReveal", label = "FastRevealState" },
	{ key = "lowDetail", button = "LowDetail", label = "LowDetailState" },
	{ key = "hideOthers", button = "HideOtherPlots", label = "HideOtherPlotsState" },
}
local AUTO_SELL = {
	{ key = "autoSellCommon", button = "AutoSellCommon" },
	{ key = "autoSellUncommon", button = "AutoSellUncommon" },
}

local Settings = { name = "Settings" } :: Types.Page

local ctx: Types.Ctx
local gui: ScreenGui
local sliders: { Slider } = {}
local dragging: Slider? = nil
local dragConnections: { RBXScriptConnection } = {}

local function show(slider: Slider, fraction: number)
	local f = math.clamp(fraction, 0, 1)
	slider.knob.Position = UDim2.fromScale(f, 0.5)
	Screens.fill(slider.fill, f)
	slider.value.Text = `{math.floor(f * 100 + 0.5)}%`
end

local function stopDrag(send: boolean)
	local slider = dragging
	dragging = nil
	for _, connection in dragConnections do
		connection:Disconnect()
	end
	table.clear(dragConnections)
	if slider and send then
		local fraction = math.clamp(slider.knob.Position.X.Scale, 0, 1)
		ctx.fire("SettingSet", slider.key, math.floor(fraction * 20 + 0.5) / 20)
	end
end

local function startDrag(slider: Slider)
	stopDrag(false)
	dragging = slider
	local function follow(input: InputObject)
		local width = slider.bar.AbsoluteSize.X
		if width > 0 then
			show(slider, (input.Position.X - slider.bar.AbsolutePosition.X) / width)
		end
	end
	table.insert(
		dragConnections,
		UserInputService.InputChanged:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			then
				follow(input)
			end
		end)
	)
	table.insert(
		dragConnections,
		UserInputService.InputEnded:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				stopDrag(true)
			end
		end)
	)
end

function Settings.render(state: any)
	local settings = state.settings
	for _, slider in sliders do
		if dragging ~= slider then
			local value = settings[slider.key]
			show(slider, if typeof(value) == "number" then value else 0)
		end
	end
	-- a toggle that is on is green with a tick, off is slate with a cross
	local function look(button: GuiObject, on: boolean)
		Screens.setButtonState(
			button,
			if on then "afford" else "off",
			nil,
			if on then "IconTick" else "IconClose"
		)
	end
	for _, toggle in TOGGLES do
		local button = Screens.button(gui, toggle.button)
		local on = settings[toggle.key] == true
		Screens.label(button, toggle.label).Text = if on then "ON" else "OFF"
		look(button, on)
	end
	for _, toggle in AUTO_SELL do
		look(Screens.button(gui, toggle.button), settings[toggle.key] == true)
	end
end

function Settings.closed()
	stopDrag(true)
end

function Settings.init(context: Types.Ctx)
	ctx = context
	gui = Screens.get("Settings")
	for _, spec in SLIDERS do
		local bar = Screens.frame(gui, spec.bar)
		local slider: Slider = {
			key = spec.key,
			bar = bar,
			knob = Screens.button(bar, spec.knob),
			fill = Screens.frame(bar, "Fill"),
			value = Screens.label(gui, spec.value),
		}
		slider.value.Text = ""
		table.insert(sliders, slider)
		slider.knob.MouseButton1Down:Connect(function()
			startDrag(slider)
		end)
	end
	local function flip(key: string)
		local state = ctx.state()
		if state then
			ctx.fire("SettingSet", key, state.settings[key] ~= true)
		end
	end
	for _, toggle in TOGGLES do
		Screens.label(gui, toggle.label).Text = ""
		Screens.button(gui, toggle.button).Activated:Connect(function()
			flip(toggle.key)
		end)
	end
	for _, toggle in AUTO_SELL do
		Screens.button(gui, toggle.button).Activated:Connect(function()
			flip(toggle.key)
		end)
	end
end

return Settings
