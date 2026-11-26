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
local FoodLook = require(script.Parent.FoodLook)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local UiFx = require(script.Parent.UiFx)

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
	Name = { holder = "NameLabel", text = "NameLabel" },
	-- v4.3: the final beat is ONE hero info card (HeroCard); the stamp and the
	-- sold line ride its edges
	Card = { holder = "HeroCard" },
	Stamp = { holder = "Stamp", text = "StampLabel" },
	Sold = { holder = "SoldTag", text = "SoldLabel" },
	Skip = { holder = "SkipHint" },
	-- v4.6: the final beat's odds, big at the top centre (the card no longer carries them)
	FinalOdds = { holder = "FinalOdds", text = "FinalOddsText" },
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
local finalOddsId = 0

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
	finalOddsId += 1
	for element in ELEMENTS do
		show(element, false)
	end
	RevealUi.oddsTension(0)
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
	UiFx.activate("revealCard", false)
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
	-- no name: the HUD's region banner (HudController:ZoneCross) is the zone label now
	if zoneName ~= "" and ribbon and label and (label.Text ~= zoneName or not ribbon.Visible) then
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

-- The odds counter's look as the suspense climbs: an outline and a gradient in the rarity the
-- escalation has reached, and a punch that grows with each rung.
local oddsDecor: { stroke: UIStroke?, gradient: UIGradient?, home: UDim2? } = {}
function RevealUi.oddsTier(color: Color3?, rung: number?)
	local label = labels.Odds
	if not label then
		return
	end
	if not oddsDecor.stroke or oddsDecor.stroke.Parent ~= label then
		local stroke = label:FindFirstChild("TierStroke") :: UIStroke?
		if not stroke then
			local made = Instance.new("UIStroke")
			made.Name = "TierStroke"
			made.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
			made.Parent = label
			stroke = made
		end
		local gradient = label:FindFirstChild("TierGradient") :: UIGradient?
		if not gradient then
			local made = Instance.new("UIGradient")
			made.Name = "TierGradient"
			made.Rotation = 90
			made.Parent = label
			gradient = made
		end
		oddsDecor.stroke, oddsDecor.gradient = stroke, gradient
	end
	local stroke = oddsDecor.stroke :: UIStroke
	local gradient = oddsDecor.gradient :: UIGradient
	if not color then
		stroke.Enabled = false
		gradient.Enabled = false
		return
	end
	stroke.Enabled = true
	stroke.Color = color:Lerp(Color3.new(0, 0, 0), 0.35)
	stroke.Thickness = 3 + (rung or 0) * 0.6
	gradient.Enabled = true
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), color:Lerp(Color3.new(1, 1, 1), 0.25))
	pop(label, 1.25 + 0.08 * (rung or 0))
end

--- The counter's tension while the odds run (owner's review 3: "the 1 in ... should build
--- suspense"): it trembles, more as `amount` (0..1) rises; 0 puts it back at rest.
function RevealUi.oddsTension(amount: number)
	local holder = holders.Odds
	if not holder then
		return
	end
	if not oddsDecor.home then
		oddsDecor.home = holder.Position
	end
	local home = oddsDecor.home :: UDim2
	if amount <= 0 then
		holder.Position = home
		holder.Rotation = 0
		return
	end
	local j = 5 * amount
	holder.Position = home + UDim2.fromOffset((math.random() - 0.5) * j, (math.random() - 0.5) * j)
	holder.Rotation = (math.random() - 0.5) * 3 * amount
end

-- A line of dialogue under the odds while the silhouette walks in: who speaks, typed out.
local sayFrame: Frame? = nil
local sayId = 0
function RevealUi.say(speaker: string?, text: string?, color: Color3?)
	sayId += 1
	local id = sayId
	local screen = gui
	if not text or not screen then
		if sayFrame then
			sayFrame.Visible = false
		end
		return
	end
	if not sayFrame then
		local frame = Instance.new("Frame")
		frame.Name = "DialogueLine"
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromScale(0.5, 0.7)
		frame.Size = UDim2.fromScale(0.46, 0.085)
		frame.BackgroundColor3 = Color3.fromRGB(14, 12, 28)
		frame.BackgroundTransparency = 0.18
		frame.ZIndex = 50
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.3, 0)
		corner.Parent = frame
		local stroke = Instance.new("UIStroke")
		stroke.Name = "Edge"
		stroke.Thickness = 3
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Parent = frame
		local who = Instance.new("TextLabel")
		who.Name = "Who"
		who.BackgroundTransparency = 1
		who.AnchorPoint = Vector2.new(0, 0.5)
		who.Position = UDim2.fromScale(0.03, 0)
		who.Size = UDim2.fromScale(0.3, 0.55)
		who.Font = Enum.Font.FredokaOne
		who.TextScaled = true
		who.TextXAlignment = Enum.TextXAlignment.Left
		who.TextColor3 = Color3.new(1, 1, 1)
		who.ZIndex = 52
		local whoStroke = Instance.new("UIStroke")
		whoStroke.Thickness = 2
		whoStroke.Parent = who
		who.Parent = frame
		local line = Instance.new("TextLabel")
		line.Name = "Line"
		line.BackgroundTransparency = 1
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.fromScale(0.5, 0.56)
		line.Size = UDim2.fromScale(0.92, 0.62)
		line.Font = Enum.Font.FredokaOne
		line.TextScaled = true
		line.TextColor3 = Color3.new(1, 1, 1)
		line.ZIndex = 52
		local lineSize = Instance.new("UITextSizeConstraint")
		lineSize.MaxTextSize = 30
		lineSize.Parent = line
		line.Parent = frame
		frame.Parent = screen
		sayFrame = frame
	end
	local frame = sayFrame :: Frame
	local who = frame:FindFirstChild("Who") :: TextLabel
	local line = frame:FindFirstChild("Line") :: TextLabel
	local edge = frame:FindFirstChild("Edge") :: UIStroke
	who.Text = speaker or ""
	who.TextColor3 = color or Color3.new(1, 1, 1)
	edge.Color = (color or Color3.new(1, 1, 1)):Lerp(Color3.new(1, 1, 1), 0.5)
	line.Text = `"{text}"`
	line.MaxVisibleGraphemes = 0
	frame.Visible = true
	pop(frame, 0.6)
	-- typed out, a soft blip every other letter
	local Sound = require(script.Parent.Parent.Controllers.SoundController) :: any
	task.spawn(function()
		local count = utf8.len(line.Text) or #line.Text
		for typed = 1, count do
			if sayId ~= id then
				return
			end
			line.MaxVisibleGraphemes = typed
			if typed % 2 == 0 then
				Sound:Play("dialogue_blip", nil, { pitchVary = 0.08 })
			end
			task.wait(0.028)
		end
	end)
end

--- The line a caught hero says in its reveal, or nil (below RevealLines.FromRarity).
function RevealUi.lineFor(result: any): string?
	local lines = (Config :: any).RevealLines
	local rarity = Config.Rarities[result.rarity]
	local from = lines and Config.Rarities[lines.FromRarity]
	if not lines or not rarity or not from or rarity.Order < from.Order then
		return nil
	end
	local character = MAPS.character[result.id] or MAPS.premium[result.id]
	local own = character and (character :: any).Line
	if typeof(own) == "string" and own ~= "" then
		return own
	end
	local pool = lines.ByRarity[result.rarity]
	return if pool and #pool > 0 then pool[math.random(1, #pool)] else nil
end

--- The name line: underscores and the letters found so far, or the full name.
function RevealUi.name(text: string)
	-- one line, scaled to the width: wrapped, the spaced-out "_ _ _ _" name broke onto two lines
	-- and shrank to unreadable (owner's review 6: "the name is not visible")
	local label = labels.Name
	if label then
		-- sized from its length (about 0.62 em a character in this font), never auto-scaled: in play
		-- the label came up with scaling off at TextSize 8, a speck under the silhouette
		label.TextWrapped = false
		label.TextScaled = false
		local width = label.Size.X.Offset > 0 and label.Size.X.Offset or 820
		label.TextSize = math.clamp(math.floor(width / (math.max(#text, 1) * 0.62)), 18, 46)
	end
	write("Name", text)
	show("Name", true)
end

--- The hero's display name for a result.
function RevealUi.heroName(result: any): string
	local character = MAPS.character[result.id] or MAPS.premium[result.id]
	return if character then character.Name else tostring(result.id)
end

--- The final beat (v4.3, owner's review 4): ONE hero info card at the bottom
--- centre that stays for the whole beat: the rarity ribbon on its top edge
--- (the word in the tier's moving colours from Rare up), the name big, the size /
--- mutation / craving tags in their colours and the fuse stars, the income big
--- with the yen icon, the odds, a NEW! / NEW BEST! / LUCKY! stamp on its corner
--- and the sold / bench line on its bottom edge. It slides up and scales in
--- with a shine; the card frame and glow take the rarity's tier look.
local function rarityWord(label: TextLabel, rarity: string)
	local gradient = label:FindFirstChild("TierText")
	local colours = UiFx.tierColours(rarity)
	if not colours then
		if gradient then
			gradient:Destroy()
		end
		return
	end
	local made: UIGradient
	if gradient and gradient:IsA("UIGradient") then
		made = gradient
	else
		made = Instance.new("UIGradient")
		made.Name = "TierText"
		made.Parent = label
		UiFx.spinGradient(made, 90)
	end
	local points = {}
	for i, c in colours do
		table.insert(
			points,
			ColorSequenceKeypoint.new((i - 1) / (#colours - 1), c:Lerp(Color3.new(1, 1, 1), 0.35))
		)
	end
	made.Color = ColorSequence.new(points)
end

function RevealUi.final(result: any)
	local rarity = result.rarity or "Premium"
	local color = Theme.rarity(rarity)
	local card = holders.Card
	local character = MAPS.character[result.id] or MAPS.premium[result.id]

	-- the card replaces the spelled name; the counter becomes the big final odds at the top
	show("Name", false)
	show("Odds", false)
	show("Burst", false)
	RevealUi.oddsTension(0)

	Screens.label(card, "CardName").Text = RevealUi.heroName(result)
	local word = Screens.label(card, "RarityText")
	word.Text = rarity:upper()
	rarityWord(word, rarity)
	Screens.tint(Screens.frame(card, "RarityRibbon"), color)
	local panel = Screens.frame(card, "CardPanel")
	UiFx.styleCard(panel, rarity)
	UiFx.setColour(card, color:Lerp(Color3.new(1, 1, 1), 0.3))

	-- tags: size, mutation (its colour), craving (its flavour), stars
	local size = if typeof(result.size) == "string" then result.size else nil
	local mut = if typeof(result.mut) == "string" then result.mut else nil
	Screens.frame(card, "SizeTagCell").Visible = size ~= nil
	Screens.label(card, "SizeText").Text = if size then size:upper() else ""
	Screens.frame(card, "MutationTagCell").Visible = mut ~= nil
	Screens.label(card, "MutationText").Text = if mut then mut:upper() else ""
	Screens.tint(Screens.frame(card, "MutationTag"), Theme.mutation(mut))
	-- the hero's favourite dish (plan 13): thrown = "FAVOURITE!", else which dish it loves
	local craves = character and (character :: any).Favourite
	local loved = if typeof(craves) == "string" then MAPS.food[craves] else nil
	local crave = Screens.frame(card, "CraveTagCell")
	crave.Visible = loved ~= nil
	if loved then
		Screens.label(card, "CraveText").Text = if result.flavorMatch
			then "FAVOURITE!"
			else `LOVES {loved.Name:upper()}`
		Screens.setIcon(Screens.image(card, "CraveTagIcon"), FoodLook.iconKey(loved.Id))
		Screens.tint(Screens.frame(card, "CraveTag"), FoodLook.tile(loved))
	end
	local stars = tonumber(result.stars) or 0
	for i = 1, 3 do
		Screens.image(card, "Star" .. i).Visible = i <= stars
	end
	Screens.frame(card, "Stars").Visible = stars > 0
	Screens.frame(card, "TagRow").Visible = size ~= nil
		or mut ~= nil
		or typeof(craves) == "string"
		or stars > 0

	-- the numbers
	Screens.label(card, "IncomeLabel").Text = `+{Format.short(result.income or 0)}/s`
	if typeof(result.oneInN) == "number" then
		RevealUi.finalOdds(result.oneInN, color, rarity)
	else
		show("FinalOdds", false)
	end

	-- the server's stamp follows the score (Roll.stamp: LUCKY from 1 in 100, SUPER LUCKY from
	-- 1 in 10,000, INSANE LUCK from 1 in a million, GODLY from 1 in 100 million). A big one
	-- outranks NEW; a plain LUCKY gives way to it.
	local earned = if typeof(result.stamp) == "string" then result.stamp else nil
	local stamp = if earned and earned ~= "LUCKY"
		then earned .. "!"
		elseif result.isBest then "NEW BEST!"
		elseif result.isNew then "NEW!"
		elseif earned or mut or size then "LUCKY!"
		else nil
	show("Stamp", stamp ~= nil)
	if stamp then
		write("Stamp", stamp)
		local cell = shown.Stamp
		cell.Rotation = 7
		task.delay(0.3, function()
			pop(cell, 1.8)
		end)
	end
	local sold = if result.action == "sold"
		then `sold for {Format.short(result.soldYen or 0)} yen`
		elseif result.action == "bench" then "sent to your bench"
		else nil
	show("Sold", sold ~= nil)
	if sold then
		write("Sold", sold)
	end

	-- in: slide up, scale in, then a shine across and the ribbon pops
	local home = card:GetAttribute("Home")
	if typeof(home) ~= "UDim2" then
		home = card.Position
		card:SetAttribute("Home", home)
	end
	card.Position = (home :: UDim2) + UDim2.fromOffset(0, 70)
	show("Card", true)
	pop(card, 0.82)
	TweenService:Create(
		card,
		TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = home }
	):Play()
	UiFx.activate("revealCard", true)
	task.delay(0.3, function()
		pop(Screens.frame(card, "RarityRibbon"), 1.4)
		local face = panel:FindFirstChild("Face")
		if face and face:IsA("GuiObject") then
			UiFx.sweep(UiFx.makeShine(face, face, true), 0.9)
		end
	end)
end

--- The final beat's "1 IN N" at the top edge (v4.7, owner's review of section 5: it sat on the
--- hero's head, and every rarity looked the same). How loud it is grows with the rarity
--- (ODDS_STYLE): its size, how hard it slams in (the scale it drops from) and shakes, the
--- outline, a gentle pulse while it holds, the sparkles, a flash in the rarity colour, and the
--- letters' colours: a white shine running through the rarity colour up to Epic, molten gold for
--- Legendary, the Mythic palette flowing through the letters, a full rainbow with a glitch for
--- Secret. The glow and the sunburst behind it turn and pulse at the rarity's own pace (UiFx).
type OddsStyle = {
	scale: number, -- resting size (the frame is anchored at its top: it grows downward)
	slam: number, -- the multiple of its size it slams in from
	shake: number, -- px of impact shake
	stroke: number,
	pulse: number, -- share of its size it breathes by while it holds
	sparkle: boolean,
	flash: number?, -- peak of a full-screen flash in the rarity colour (0..1)
	colours: { Color3 }?, -- flowing letter colours (else the white shine band)
	rainbow: boolean?,
	glitch: boolean?,
}
local GOLD_FLOW = {
	Color3.fromHex("FFF6C8"),
	Color3.fromHex("FFD045"),
	Color3.fromHex("FF9A1F"),
	Color3.fromHex("FFE58A"),
}
local MYTHIC_FLOW = {
	Color3.fromHex("FF4D6D"),
	Color3.fromHex("FFB020"),
	Color3.fromHex("FFE14D"),
	Color3.fromHex("4ADE80"),
	Color3.fromHex("38BDF8"),
	Color3.fromHex("A855F7"),
}
local GOLDEN: OddsStyle = {
	scale = 1.1,
	slam = 2.8,
	shake = 9,
	stroke = 5,
	pulse = 0.035,
	sparkle = true,
	flash = 0.32,
	colours = GOLD_FLOW,
}
local ODDS_STYLE: { [string]: OddsStyle } = {
	Common = { scale = 0.8, slam = 1.7, shake = 3, stroke = 3, pulse = 0, sparkle = false },
	Uncommon = { scale = 0.86, slam = 1.9, shake = 4, stroke = 3, pulse = 0, sparkle = false },
	Rare = { scale = 0.94, slam = 2.2, shake = 5, stroke = 4, pulse = 0.015, sparkle = true },
	Epic = {
		scale = 1.02,
		slam = 2.5,
		shake = 7,
		stroke = 4,
		pulse = 0.025,
		sparkle = true,
		flash = 0.18,
	},
	Legendary = GOLDEN,
	Mythic = {
		scale = 1.18,
		slam = 3.0,
		shake = 11,
		stroke = 5,
		pulse = 0.045,
		sparkle = true,
		flash = 0.45,
		colours = MYTHIC_FLOW,
	},
	Secret = {
		scale = 1.26,
		slam = 3.2,
		shake = 13,
		stroke = 6,
		pulse = 0.05,
		sparkle = true,
		flash = 0.6,
		rainbow = true,
		glitch = true,
	},
	Premium = GOLDEN,
}
local SHINE_BASE = 0.32 -- how far the rarity colour is lifted toward white at rest

-- a list of colours as a gradient that tiles: the list twice over 0..1, so sliding the Offset by
-- one period is seamless
local function flowSequence(colours: { Color3 }): ColorSequence
	local points = {}
	local n = #colours
	for i = 0, 2 * n do
		table.insert(points, ColorSequenceKeypoint.new(i / (2 * n), colours[(i % n) + 1]))
	end
	return ColorSequence.new(points)
end

-- a short full-screen flash in `color`, up to `peak` opacity (the white flash, tinted)
local function tintFlash(color: Color3, peak: number)
	local frame = flashFrame
	if not frame then
		return
	end
	flashId += 1
	local id = flashId
	frame.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.35)
	frame.BackgroundTransparency = 1
	frame.Visible = true
	TweenService:Create(frame, TweenInfo.new(0.06), { BackgroundTransparency = 1 - peak }):Play()
	task.delay(0.06, function()
		if flashId ~= id then
			return
		end
		TweenService
			:Create(
				frame,
				TweenInfo.new(0.5, Enum.EasingStyle.Quad),
				{ BackgroundTransparency = 1 }
			)
			:Play()
		task.delay(0.5, function()
			if flashId == id then
				frame.Visible = false
				frame.BackgroundColor3 = Color3.new(1, 1, 1)
			end
		end)
	end)
end

function RevealUi.finalOdds(oneInN: number, color: Color3, rarity: string?)
	local holder = holders.FinalOdds
	local label = labels.FinalOdds
	if not holder or not label then
		return
	end
	local style = ODDS_STYLE[rarity or ""] or ODDS_STYLE.Rare
	finalOddsId += 1
	local id = finalOddsId
	label.Text = Format.oneIn(oneInN):upper()
	label.TextColor3 = Color3.new(1, 1, 1)
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		stroke.Color = if style.rainbow
			then Color3.new(0, 0, 0)
			else color:Lerp(Color3.new(0, 0, 0), 0.6)
		stroke.Thickness = style.stroke
	end
	-- the letters' colours
	local gradient = label:FindFirstChild("OddsShine")
	if not gradient or not gradient:IsA("UIGradient") then
		for _, other in label:GetChildren() do
			if other:IsA("UIGradient") then
				other.Enabled = false
			end
		end
		local made = Instance.new("UIGradient")
		made.Name = "OddsShine"
		made.Parent = label
		gradient = made
	end
	local shine = gradient :: UIGradient
	local flowing: { Color3 }? = style.colours
	if style.rainbow then
		local hues = {}
		for i = 0, 6 do
			table.insert(hues, Color3.fromHSV(i / 7, 0.75, 1))
		end
		flowing = hues
	end
	if flowing then
		shine.Rotation = 0
		shine.Color = flowSequence(flowing)
		shine.Offset = Vector2.new(-0.5, 0)
	else
		local base = color:Lerp(Color3.new(1, 1, 1), SHINE_BASE)
		shine.Rotation = 18
		shine.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, base),
			ColorSequenceKeypoint.new(0.4, base),
			ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.6, base),
			ColorSequenceKeypoint.new(1, base),
		})
		shine.Offset = Vector2.new(-1, 0)
	end

	-- the glow and the sunburst: the rarity's colour and its own turn / pulse / gold / cycle
	UiFx.scan(holder)
	UiFx.setRarity(holder, rarity)
	UiFx.setColour(holder, color:Lerp(Color3.new(1, 1, 1), 0.2))
	for _, name in { "Twinkle1", "Twinkle2" } do
		local twinkle = holder:FindFirstChild(name)
		if twinkle and twinkle:IsA("GuiObject") then
			twinkle.Visible = style.sparkle
		end
	end
	local caption = Screens.frame(holder, "ChancePill")
	Screens.tint(caption, color:Lerp(Color3.new(0, 0, 0), 0.55))
	local captionCell = caption.Parent
	local captionWhole: GuiObject = if captionCell
			and captionCell:IsA("GuiObject")
			and captionCell.Name == "ChancePillCell"
		then captionCell
		else caption
	captionWhole.Visible = false

	-- the slam
	local home = holder:GetAttribute("Home")
	if typeof(home) ~= "UDim2" then
		home = holder.Position
		holder:SetAttribute("Home", home)
	end
	holder.Position = home :: UDim2
	show("FinalOdds", true)
	local scale = holder:FindFirstChild("SlamScale")
	if not scale or not scale:IsA("UIScale") then
		local made = Instance.new("UIScale")
		made.Name = "SlamScale"
		made.Parent = holder
		scale = made
	end
	local slam = scale :: UIScale
	slam.Scale = style.slam * style.scale
	TweenService:Create(
		slam,
		TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0),
		{ Scale = style.scale }
	):Play()
	task.delay(0.12, function()
		if finalOddsId ~= id then
			return
		end
		if style.flash then
			tintFlash(color, style.flash)
		end
		-- the impact: a shake, settling
		for i = 1, 7 do
			if finalOddsId ~= id then
				return
			end
			local j = style.shake * (1 - i / 8)
			holder.Position = (home :: UDim2)
				+ UDim2.fromOffset((math.random() - 0.5) * 2 * j, (math.random() - 0.5) * 2 * j)
			task.wait(0.03)
		end
		holder.Position = home :: UDim2
		if finalOddsId ~= id then
			return
		end
		captionWhole.Visible = true
		pop(captionWhole, 1.6)
	end)
	-- while the beat holds: the letters' colours move, it breathes, and a Secret glitches
	task.spawn(function()
		task.wait(0.45)
		local t0 = os.clock()
		local nextGlitch = t0 + 1.2
		local nextShine = 0
		while finalOddsId == id and holder.Visible do
			local now = os.clock()
			if style.pulse > 0 then
				slam.Scale = style.scale * (1 + style.pulse * math.sin((now - t0) * 3.2))
			end
			if flowing then
				-- one period of the tiled colours every 2.4 s, seamless
				shine.Offset = Vector2.new(((now - t0) / 2.4) % 1 - 1, 0)
			elseif now >= nextShine then
				nextShine = now + 2.4
				shine.Offset = Vector2.new(-1, 0)
				TweenService:Create(
					shine,
					TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
					{ Offset = Vector2.new(1, 0) }
				):Play()
			end
			if style.glitch and now >= nextGlitch then
				nextGlitch = now + 1.4 + math.random() * 1.2
				for _ = 1, 3 do
					if finalOddsId ~= id then
						return
					end
					holder.Position = (home :: UDim2)
						+ UDim2.fromOffset(math.random(-6, 6), math.random(-2, 2))
					if stroke then
						stroke.Color = Color3.fromHSV(math.random(), 0.9, 1)
					end
					task.wait(0.04)
				end
				holder.Position = home :: UDim2
				if stroke then
					stroke.Color = Color3.new(0, 0, 0)
				end
			end
			task.wait(1 / 30)
		end
	end)
end

--- "tap to continue" under the final beat.
function RevealUi.skipHint(on: boolean)
	show("Skip", on)
end

return RevealUi
