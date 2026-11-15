--!strict
-- RevealUi - the `Reveal` screen: everything 2D the throw sequence shows.
-- Letterbox bars, the luck counter and zone ribbon in flight, then the odds
-- counter, the name that spells itself out, and the final beat (stamp,
-- variant, name, rarity ribbon, income).
--
-- The sequence (Fx/ThrowSequence) decides WHEN; this only knows HOW each
-- element is shown. Every element is hidden until it has something real to
-- say. The bars and the flash are direct children of the ScreenGui, so they
-- cover the whole screen whatever its shape.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)

local MAPS = Lookup.of(Config)
local POP = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local BAR_HEIGHT = 0.11 -- each letterbox bar, as a share of the screen height

-- Each element: the instance shown and hidden as a whole, and the label
-- inside it that carries the text.
local ELEMENTS: { [string]: { holder: string, text: string? } } = {
	Luck = { holder = "LuckLabel", text = "LuckLabel" },
	Zone = { holder = "ZoneBanner", text = "ZoneBannerText" },
	Odds = { holder = "OddsLabel", text = "OddsLabel" },
	Burst = { holder = "OddsBurst" },
	Stamp = { holder = "StampLabel", text = "StampLabel" },
	Variant = { holder = "VariantLabel", text = "VariantLabel" },
	Name = { holder = "NameLabel", text = "NameLabel" },
	Ribbon = { holder = "RarityRibbon", text = "RarityText" },
	Income = { holder = "IncomeRow", text = "IncomeLabel" },
	Sold = { holder = "SoldLabel", text = "SoldLabel" },
	Skip = { holder = "SkipHint" },
}

local RevealUi = {}

local gui: ScreenGui? = nil
local holders: { [string]: GuiObject } = {}
-- what is switched on and off for an element: its holder, or the `<Name>Cell`
-- around it when it has one (the cell also carries the element's drop shadow,
-- which would otherwise stay on screen as an empty dark pill)
local shown: { [string]: GuiObject } = {}
local labels: { [string]: TextLabel } = {}
local bars: { GuiObject } = {}
local flashFrame: GuiObject? = nil
local flashId = 0

local function pop(target: GuiObject, from: number)
	local scale = target:FindFirstChild("PopScale")
	if not scale or not scale:IsA("UIScale") then
		local made = Instance.new("UIScale")
		made.Name = "PopScale"
		made.Parent = target
		scale = made
	end
	local uiScale = scale :: UIScale
	uiScale.Scale = from
	TweenService:Create(uiScale, POP, { Scale = 1 }):Play()
end

local function show(element: string, visible: boolean)
	local whole = shown[element]
	if whole and whole.Visible ~= visible then
		whole.Visible = visible
	end
end

local function write(element: string, text: string)
	local label = labels[element]
	if label and label.Text ~= text then
		label.Text = text
	end
end

--- Find the screen's elements. Safe to call more than once.
function RevealUi.bind()
	if gui then
		return
	end
	local screen = Screens.get("Reveal")
	gui = screen
	screen.Enabled = false
	for element, names in ELEMENTS do
		local holder = Screens.frame(screen, names.holder)
		holders[element] = holder
		if names.text then
			labels[element] = Screens.label(screen, names.text)
		end
		local cell = holder.Parent
		local whole = if cell
				and cell:IsA("GuiObject")
				and cell.Name == names.holder .. "Cell"
			then cell
			else holder
		shown[element] = whole
		-- nothing is on screen before its beat
		whole.Visible = false
	end
	-- The bars are plain black rectangles, a little wider than the screen so
	-- no corner or edge ever shows, and they sit UNDER the canvas: the luck
	-- counter and the zone ribbon are drawn over the top bar.
	local canvas = screen:FindFirstChild("CanvasFrame")
	local under = (if canvas and canvas:IsA("GuiObject") then canvas.ZIndex else 1) - 1
	for _, name in { "LetterboxTop", "LetterboxBottom" } do
		local bar = Screens.frame(screen, name)
		local corner = bar:FindFirstChildOfClass("UICorner")
		if corner then
			corner:Destroy()
		end
		bar.ZIndex = under
		bar.BorderSizePixel = 0
		bar.Position = UDim2.new(0, -2, bar.Position.Y.Scale, bar.Position.Y.Offset)
		bar.Size = UDim2.new(1, 4, 0, 0)
		bar.Visible = false
		table.insert(bars, bar)
	end
	local flash = Screens.frame(screen, "FlashFrame")
	flash.Visible = false
	flashFrame = flash
end

--- Hide every element (the bars and the flash are left as they are).
function RevealUi.clear()
	for element in ELEMENTS do
		show(element, false)
	end
end

--- Turn the screen on with nothing showing, or off again.
function RevealUi.enable(on: boolean)
	RevealUi.bind()
	local screen = gui
	local flash = flashFrame
	if not screen or not flash then
		return
	end
	RevealUi.clear()
	if on then
		-- a flash still fading from the last sequence must not switch this
		-- one off when it ends
		flashId += 1
		flash.Visible = false
		screen.Enabled = true
	else
		for _, bar in bars do
			bar.Visible = false
		end
		-- a closing flash may still be fading: it turns the screen off itself
		if not flash.Visible then
			screen.Enabled = false
		end
	end
end

--- Slide the cinematic bars in (or out) over `seconds`.
function RevealUi.letterbox(on: boolean, seconds: number)
	for _, bar in bars do
		local width = bar.Size.X
		local closed = UDim2.new(width.Scale, width.Offset, 0, 0)
		local open = UDim2.new(width.Scale, width.Offset, BAR_HEIGHT, 0)
		if on then
			bar.Size = closed
			bar.Visible = true
		end
		TweenService:Create(
			bar,
			TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = if on then open else closed }
		):Play()
	end
end

--- A full-screen white flash: up over `rise`, then down over `fall`. With
--- `thenOff` the screen is switched off when the flash has gone.
function RevealUi.flash(rise: number, fall: number, thenOff: boolean?)
	local frame = flashFrame
	local screen = gui
	if not frame or not screen then
		return
	end
	flashId += 1
	local id = flashId
	frame.BackgroundTransparency = 1
	frame.Visible = true
	screen.Enabled = true
	TweenService:Create(frame, TweenInfo.new(rise), { BackgroundTransparency = 0 }):Play()
	task.delay(rise, function()
		if flashId ~= id then
			return
		end
		TweenService:Create(frame, TweenInfo.new(fall), { BackgroundTransparency = 1 }):Play()
		task.delay(fall, function()
			if flashId ~= id then
				return
			end
			frame.Visible = false
			if thenOff then
				screen.Enabled = false
			end
		end)
	end)
end

--- In flight: the luck multiplier so far and the zone the food is over.
function RevealUi.flight(luck: number, zoneName: string)
	write("Luck", string.format("x%.2f LUCK", luck))
	show("Luck", true)
	local ribbon = holders.Zone
	local label = labels.Zone
	if ribbon and label and (label.Text ~= zoneName or not ribbon.Visible) then
		-- a new zone (the food crossed a gate): the ribbon pops
		label.Text = zoneName
		ribbon.Visible = true
		pop(ribbon, 1.25)
	end
end

function RevealUi.endFlight()
	show("Luck", false)
	show("Zone", false)
end

--- The odds counter. Returns true when the text changed (so the caller can
--- pace the little pop that goes with each step).
function RevealUi.odds(oneInN: number, withPop: boolean): boolean
	local label = labels.Odds
	local text = Format.oneIn(oneInN)
	show("Odds", true)
	if not label or label.Text == text then
		return false
	end
	label.Text = text
	if withPop then
		pop(label, 1.16)
	end
	return true
end

--- The name line: underscores and the letters found so far, or the full name.
function RevealUi.name(text: string)
	write("Name", text)
	show("Name", true)
end

--- The hero's display name for a result.
function RevealUi.heroName(result: any): string
	local character = MAPS.character[result.id] or MAPS.premium[result.id]
	return if character then character.Name else tostring(result.id)
end

--- The final beat: stamp, variant, full name, rarity ribbon, income, and the
--- burst behind the odds in the rarity colour.
function RevealUi.final(result: any)
	local rarity = result.rarity or "Premium"
	local color = Theme.rarity(rarity)

	RevealUi.name(RevealUi.heroName(result))
	pop(holders.Name, 1.3)

	local stamp = if result.mut or result.size
		then "LUCKY!"
		elseif result.isBest then "NEW BEST!"
		elseif result.isNew then "NEW!"
		else nil
	if stamp then
		write("Stamp", stamp)
		show("Stamp", true)
		pop(holders.Stamp, 1.8)
	end

	local variant = {}
	if result.size then
		table.insert(variant, result.size:upper())
	end
	if result.mut then
		table.insert(variant, result.mut:upper())
	end
	if result.flavorMatch then
		table.insert(variant, "CRAVING!")
	end
	if #variant > 0 then
		write("Variant", table.concat(variant, "  "))
		show("Variant", true)
	end

	Screens.tint(holders.Ribbon, color)
	write("Ribbon", rarity:upper())
	show("Ribbon", true)
	pop(holders.Ribbon, 1.4)

	write("Income", `+{Format.short(result.income or 0)}/s`)
	show("Income", true)

	local sold = if result.action == "sold"
		then `sold for {Format.short(result.soldYen or 0)} yen`
		elseif result.action == "bench" then "sent to your bench"
		else nil
	if sold then
		write("Sold", sold)
		show("Sold", true)
	end

	if result.oneInN then
		RevealUi.odds(result.oneInN, false)
		local burst = holders.Burst
		if burst:IsA("ImageLabel") then
			burst.ImageColor3 = color
		end
		show("Burst", true)
		pop(burst, 0.4)
		pop(holders.Odds, 1.5)
	end
end

--- "tap to continue" under the final beat.
function RevealUi.skipHint(on: boolean)
	show("Skip", on)
end

return RevealUi
