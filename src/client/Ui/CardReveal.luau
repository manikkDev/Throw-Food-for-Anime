--!strict
-- CardReveal - the tap-to-reveal card of the purchase celebration (owner's review after section 6:
-- "like the Clash Royale card reveal"). Everything bought is a card the player opens by tapping:
--
--   1. the card floats in face down (CardBack art), trembling, "TAP!"
--   2. tap: it flips face up at the LOWEST tier of its ladder (Common), the hero only a silhouette
--   3. while the real tier is higher it keeps trembling, harder each tier; each tap CHARGES it (the
--      shake grows, the glow swells), then a flash and a burst UPGRADE it to the next tier: the frame,
--      the banner, the glow colour and the rays change (Common -> Uncommon -> ... -> Secret)
--   4. at its real tier the silhouette bursts into the full hero: a reveal that grows with the tier
--      (a pop for Common ... gold rays and showers for Legendary, a rainbow foil and a white-out for
--      Mythic, a void flash with a glitch for Secret), its name, NEW! on a first catch
--   5. tap: the card flies off and the next one comes in (a 10-pack is ten cards, then the summary)
-- Passes and products are a sealed card at their own tier: one tap charges and opens it.
-- SKIP (10-packs) reveals the rest at once. The art keys come from the Icons bank (CardBack,
-- CardFrame_<Tier>, CardBanner_<Tier>, CardFoil). It never errors: a missing piece is skipped.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Icons = require(ReplicatedStorage.Shared.Config.Icons)
local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local Viewports = require(script.Parent.Viewports)

local CardReveal = {}

CardReveal.LADDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }
local ORDER: { [string]: number } = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Mythic = 6,
	Secret = 7,
	Premium = 6,
}
-- the speed-line burst behind the hero, per tier (tools/ui/screens_v49.py PORTRAIT_TINT)
CardReveal.PORTRAIT_TINT = {
	Common = Color3.fromHex("B9C3D3"),
	Uncommon = Color3.fromHex("7EE8AE"),
	Rare = Color3.fromHex("7DBBFF"),
	Epic = Color3.fromHex("C69BFF"),
	Legendary = Color3.fromHex("FFCB6B"),
	Mythic = Color3.fromHex("FFB0F2"),
	Secret = Color3.fromHex("B0306A"),
	Premium = Color3.fromHex("FF9CC8"),
} :: { [string]: Color3 }
local STINGS: { [string]: string } = {
	Common = "reveal_common",
	Uncommon = "reveal_common",
	Rare = "reveal_rare",
	Epic = "reveal_epic",
	Legendary = "reveal_legendary",
	Mythic = "reveal_mythic",
	Secret = "reveal_mythic",
	Premium = "reveal_legendary",
}

export type Item = {
	tier: string, -- the real tier (a Rarity, or "Premium")
	hero: string?, -- a hero id: shown in 3D, a silhouette until the final tier
	icon: string?, -- else an icon key (passes, products)
	name: string,
	label: string?, -- the banner word at the final tier (default: the tier)
	isNew: boolean?,
	climb: boolean?, -- false: open straight at its tier (passes, products)
}

export type Env = {
	waitTap: () -> (), -- yields until the player taps (or skips)
	skipped: () -> boolean,
	alive: () -> boolean, -- false once the celebration is gone
	-- burstOnly: every piece flies out of the card at once (a tier step); else half burst, half rain
	confetti: (count: number, colours: { Color3 }?, burstOnly: boolean?) -> (),
	flash: (colour: Color3, peak: number) -> (),
	shake: (strength: number, seconds: number) -> (),
}

local function find(root: Instance, name: string): GuiObject?
	local found = root:FindFirstChild(name, true)
	return if found and found:IsA("GuiObject") then found else nil
end

local function ease(
	object: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
)
	local tween = TweenService:Create(
		object,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		goal
	)
	tween:Play()
	return tween
end

local function scaleOf(target: GuiObject, name: string): UIScale
	local found = target:FindFirstChild(name)
	if found and found:IsA("UIScale") then
		return found
	end
	local made = Instance.new("UIScale")
	made.Name = name
	made.Parent = target
	return made
end

local function setArt(image: GuiObject?, key: string)
	if image and image:IsA("ImageLabel") then
		Screens.setIcon(image, key)
	end
end

local function setText(label: GuiObject?, text: string)
	if label and (label:IsA("TextLabel") or label:IsA("TextButton")) then
		label.Text = text
	end
end

-- the tiers a card climbs through to `tier`
function CardReveal.ladderFor(item: Item): { string }
	if item.climb == false then
		return { item.tier }
	end
	local out = {}
	local target = ORDER[item.tier] or 1
	for i, tier in CardReveal.LADDER do
		if i > target or (item.tier == "Premium" and i > 5) then
			break
		end
		table.insert(out, tier)
	end
	if item.tier == "Premium" then
		table.insert(out, "Premium")
	end
	if #out == 0 then
		out = { item.tier }
	end
	return out
end

local function tierColour(tier: string): Color3
	return Theme.rarity(tier)
end

-- The art a tier needs. A swapped Image draws nothing until it has downloaded, and in a fresh join the
-- startup preload queues behind the whole map (found in play: the Uncommon frame appeared ~0.4 s after
-- its flash and confetti). So each card warms its own ladder the moment it arrives, and a tap's charge
-- waits for the next tier's art (capped) so the switch, the flash and the burst land together.
local ART = Icons :: { [string]: string }
local function tierArt(tier: string): { string }
	local out = {}
	for _, key in { "CardFrame_" .. tier, "CardBanner_" .. tier } do
		local id = ART[key]
		if id then
			table.insert(out, id)
		end
	end
	return out
end

local function warm(ids: { string })
	if #ids == 0 then
		return
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(ids)
		end)
	end)
end

local function loaded(ids: { string }): boolean
	for _, id in ids do
		local status = ContentProvider:GetAssetFetchStatus(id)
		if status == Enum.AssetFetchStatus.Loading or status == Enum.AssetFetchStatus.None then
			return false
		end
	end
	return true
end

--- Reveal `items` one card at a time on `canvas`'s RevealCard. Yields until the last one is open
--- (and tapped past). Returns when done or when the celebration goes away.
function CardReveal.run(canvas: Instance, items: { Item }, env: Env)
	local card = find(canvas, "RevealCard")
	if not card then
		return
	end
	local back = find(card, "RevealBack")
	local front = find(card, "RevealFront")
	local frameArt = find(card, "RevealFrameArt")
	local bannerArt = find(card, "RevealBannerArt")
	local tierText = find(card, "RevealTierText")
	local nameLabel = find(card, "RevealName")
	local foil = find(card, "RevealFoil")
	local newTag = find(card, "RevealNew")
	local viewportObject = card:FindFirstChild("RevealViewport", true)
	local viewport: ViewportFrame? = if viewportObject and viewportObject:IsA("ViewportFrame")
		then viewportObject
		else nil
	local icon = find(card, "RevealIcon")
	local glow = find(card, "RevealGlow")
	local portraitBg = find(card, "RevealPortraitBg")
	local rays = find(card, "RevealRays")
	local tapHint = find(canvas, "TapHint")
	local counter = find(canvas, "RevealCounter")
	-- SKIP sits in a `SkipButtonCell` wrapper (the pipeline's drop-shadow cell): the wrapper is what
	-- has to show (found in play: the button was set visible inside a hidden cell)
	local skipButton = find(canvas, "SkipButtonCell") or find(canvas, "SkipButton")
	local skipInner = find(canvas, "SkipButton")
	if skipInner then
		skipInner.Visible = true
	end

	-- the two faces flip about the card's vertical centre line
	local faces: { [GuiObject]: UDim2 } = {}
	for _, face in { back, front } do
		if face then
			face.AnchorPoint = Vector2.new(0.5, 0.5)
			face.Position = UDim2.fromScale(0.5, 0.5)
			faces[face] = face.Size
		end
	end
	-- the card's home survives a slide (Celebrate moves a single card aside for its details panel)
	local homeAttr = card:GetAttribute("Home")
	local home: UDim2 = if typeof(homeAttr) == "UDim2" then homeAttr else card.Position
	card:SetAttribute("Home", home)
	card.Position = home
	local sweep: UIGradient? = nil
	if foil and foil:IsA("ImageLabel") then
		local found = foil:FindFirstChild("FoilSweep")
		if found and found:IsA("UIGradient") then
			sweep = found
		else
			local made = Instance.new("UIGradient")
			made.Name = "FoilSweep"
			made.Rotation = 35
			made.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.38, 1),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(0.62, 1),
				NumberSequenceKeypoint.new(1, 1),
			})
			made.Parent = foil
			sweep = made
		end
	end
	local pop = scaleOf(card, "CardPop")
	local glowAlpha = if glow and glow:IsA("ImageLabel") then glow.ImageTransparency else 0.4
	local raysAlpha = if rays and rays:IsA("ImageLabel") then rays.ImageTransparency else 0.5

	-- the card's life, every frame: a calm float, a short wiggle now and then while more tiers wait,
	-- a tremble only while a tap charges it, the rays turning, the glow breathing, the foil sliding, a
	-- rainbow on Mythic, a glitch on Secret. Owner's review: a constant random jitter on the face-down
	-- card read as a nervous shake, so nothing jitters until the player taps.
	local state = {
		tremble = 0, -- px of random shake (the charge only)
		wiggle = 0, -- degrees of the periodic "there is more" wiggle
		rainbow = false,
		glitch = false,
		foil = false,
		colour = tierColour("Common"),
	}
	local t0 = os.clock()
	local loop = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local jitter = state.tremble
		card.Position = home
			+ UDim2.fromOffset(
				(math.random() - 0.5) * 2 * jitter,
				math.sin(t * 1.8) * 4 + (math.random() - 0.5) * 2 * jitter
			)
		-- the wiggle: every 1.5 s, three quick swings that die away (a card begging to be tapped)
		local beat = t % 1.5
		local wiggle = if beat < 0.36
			then math.sin(beat / 0.36 * math.pi * 3) * state.wiggle * (1 - beat / 0.36)
			else 0
		card.Rotation = math.sin(t * 1.2) * 1.2 + wiggle + (math.random() - 0.5) * jitter * 0.3
		local colour = if state.rainbow
			then Color3.fromHSV((t * 0.25) % 1, 0.55, 1)
			else state.colour
		if rays and rays:IsA("ImageLabel") then
			rays.Rotation = (t * (12 + jitter * 8)) % 360
			rays.ImageColor3 = colour
		end
		if glow and glow:IsA("ImageLabel") then
			glow.ImageColor3 = colour
			glow.ImageTransparency =
				math.clamp(glowAlpha - 0.15 * math.sin(t * 3) - jitter * 0.02, 0, 1)
		end
		-- the holo foil stays on the card: a bright band sweeps THROUGH it (a gradient mask), so
		-- the sheen can never leave the card's edges (found in play: a sliding foil image did)
		if sweep and state.foil then
			sweep.Offset = Vector2.new(((t * 0.5) % 2.2) - 1.1, 0)
		end
		if state.glitch and math.random() < 0.04 and front then
			front.Position = UDim2.new(0.5, math.random(-7, 7), 0.5, 0)
		elseif front then
			front.Position = UDim2.fromScale(0.5, 0.5)
		end
	end)

	local function hint(text: string?)
		if tapHint then
			tapHint.Visible = text ~= nil
			setText(tapHint, text or "")
			if text then
				Screens.pop(tapHint, 0.7)
			end
		end
	end

	local function setTier(tier: string, label: string?)
		setArt(frameArt, "CardFrame_" .. tier)
		setArt(bannerArt, "CardBanner_" .. tier)
		setText(tierText, (label or tier):upper())
		if portraitBg and portraitBg:IsA("ImageLabel") then
			portraitBg.ImageColor3 = CardReveal.PORTRAIT_TINT[tier] or Color3.new(1, 1, 1)
		end
		state.colour = tierColour(tier)
		state.rainbow = tier == "Mythic" or tier == "Secret"
		state.glitch = tier == "Secret"
		state.foil = (ORDER[tier] or 1) >= 5
		if foil and foil:IsA("ImageLabel") then
			foil.ImageTransparency = if state.foil then 0.05 else 1
		end
		if rays and rays:IsA("ImageLabel") then
			rays.ImageTransparency = math.clamp(raysAlpha - (ORDER[tier] or 1) * 0.06, 0, 1)
		end
	end

	-- flip: one face narrows to nothing, the other opens out
	local function flip(toFront: boolean)
		local from = if toFront then back else front
		local to = if toFront then front else back
		if from then
			local size = faces[from]
			ease(
				from,
				0.12,
				{ Size = UDim2.new(0, 0, size.Y.Scale, size.Y.Offset) },
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			)
		end
		task.wait(0.12)
		if from then
			from.Visible = false
			from.Size = faces[from]
		end
		if to then
			local size = faces[to]
			to.Size = UDim2.new(0, 0, size.Y.Scale, size.Y.Offset)
			to.Visible = true
			ease(to, 0.16, { Size = size }, Enum.EasingStyle.Back)
		end
		Screens.sound("reveal_tick")
	end

	-- charge (the shake builds, the glow swells), then the flash and the burst
	local function charge(strength: number, art: { string })
		local start = os.clock()
		state.wiggle = 0
		Screens.sound("suspense_riser")
		while env.alive() and not env.skipped() do
			local held = os.clock() - start
			if held >= 1.2 or (held >= 0.26 and loaded(art)) then
				break
			end
			state.tremble = strength * (0.3 + math.min(held, 0.5) / 0.26)
			task.wait()
		end
		state.tremble = 0
	end

	for index, item in items do
		if not env.alive() then
			break
		end
		local fast = env.skipped()
		local ladder = CardReveal.ladderFor(item)
		local ladderArt: { string } = {}
		for _, tier in ladder do
			for _, id in tierArt(tier) do
				table.insert(ladderArt, id)
			end
		end
		warm(ladderArt)
		-- the card comes in, face down
		card.Visible = true
		if back then
			back.Visible = true
			back.Size = faces[back]
		end
		if front then
			front.Visible = false
		end
		if newTag then
			newTag.Visible = false
		end
		setText(nameLabel, if item.hero then "???" else item.name)
		setTier(ladder[1], nil)
		state.rainbow, state.glitch, state.foil = false, false, false
		if viewport then
			Viewports.clear(viewport)
			Viewports.bright(viewport)
			viewport.Visible = item.hero ~= nil
		end
		if icon then
			icon.Visible = item.hero == nil and item.icon ~= nil
			if item.icon and icon:IsA("ImageLabel") then
				Screens.setIcon(icon, item.icon)
				icon.ImageColor3 = Color3.new(0, 0, 0) -- dark until it opens
			end
		end
		if counter then
			counter.Visible = #items > 1
			setText(counter, `{index} / {#items}`)
		end
		if skipButton then
			skipButton.Visible = #items > 2 and not fast
		end
		if not fast then
			pop.Scale = 0.2
			ease(pop, 0.38, { Scale = 1 }, Enum.EasingStyle.Back)
			Screens.sound("reward_whoosh")
			state.tremble, state.wiggle = 0, 0
			hint("TAP!")
			env.waitTap()
		end

		-- face up at the bottom of the ladder
		state.tremble, state.wiggle = 0, 0
		hint(nil)
		if not fast then
			flip(true)
		elseif back and front then
			back.Visible = false
			front.Visible = true
			front.Size = faces[front]
		end
		if viewport and item.hero then
			Viewports.hero(viewport, item.hero, true)
		end

		-- climb the ladder, one tap per tier
		for step = 2, #ladder do
			if env.skipped() or not env.alive() then
				break
			end
			state.wiggle = 2.5 + step * 0.5
			hint("TAP!")
			env.waitTap()
			hint(nil)
			local tier = ladder[step]
			charge(1.5 + step * 0.6, tierArt(tier))
			local colour = tierColour(tier)
			-- the switch, the flash and the confetti burst all land in this one frame (owner's review:
			-- the confetti came late; half of it was rain that started above the screen)
			setTier(tier, nil)
			env.flash(colour, 0.25 + step * 0.04)
			env.confetti(
				26 + step * 6,
				{ colour, colour:Lerp(Color3.new(1, 1, 1), 0.5), Color3.new(1, 1, 1) },
				true
			)
			env.shake(1 + step * 0.5, 0.2)
			pop.Scale = 1.28
			ease(pop, 0.32, { Scale = 1 }, Enum.EasingStyle.Back)
			Screens.sound("rarity_step")
			task.wait(0.15)
		end

		-- the real tier: the hero (or the item) bursts into colour
		local finalTier = ladder[#ladder]
		setTier(finalTier, item.label)
		local order = ORDER[finalTier] or 1
		if viewport and item.hero then
			Viewports.hero(viewport, item.hero, false)
		end
		if icon and icon:IsA("ImageLabel") then
			icon.ImageColor3 = Color3.new(1, 1, 1)
		end
		setText(nameLabel, item.name)
		if newTag then
			newTag.Visible = item.isNew == true
		end
		if not env.skipped() then
			local colour = tierColour(finalTier)
			env.flash(
				if order >= 6 then Color3.new(1, 1, 1) else colour,
				math.min(0.25 + order * 0.08, 0.85)
			)
			env.confetti(30 + order * 14, nil)
			if order >= 3 then
				env.shake(math.min(order * 1.3, 8), 0.3 + order * 0.04)
			end
			pop.Scale = 1.15 + order * 0.04
			ease(pop, 0.42, { Scale = 1 }, Enum.EasingStyle.Back)
			Screens.sound(STINGS[finalTier] or "reveal_common")
			if order >= 5 then
				task.delay(0.25, function()
					Screens.sound("odds_slam")
				end)
			end
			if nameLabel then
				Screens.pop(nameLabel, 0.6)
			end
			task.wait(0.5)
		end

		-- on to the next card (or out)
		-- a pack's last card waits too (its summary comes after): every reveal gets its moment
		if index == #items and #items > 1 and env.alive() and not env.skipped() then
			hint("TAP to continue")
			env.waitTap()
			hint(nil)
		end
		if index < #items and env.alive() then
			if not env.skipped() then
				hint("TAP for next")
				env.waitTap()
				hint(nil)
				-- it flies off to the side
				ease(
					card,
					0.22,
					{ Position = home + UDim2.fromOffset(520, -60), Rotation = 25 },
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.In
				)
				task.wait(0.22)
			end
			card.Position = home
			card.Rotation = 0
		end
	end
	hint(nil)
	if skipButton then
		skipButton.Visible = false
	end
	loop:Disconnect()
	card.Position = home
	card.Rotation = 0
end

--- Hide the card and clear its 3D view.
function CardReveal.hide(canvas: Instance)
	local card = find(canvas, "RevealCard")
	if card then
		card.Visible = false
		-- back to the centre (Celebrate slides a single card aside for its details panel)
		local home = card:GetAttribute("Home")
		if typeof(home) == "UDim2" then
			card.Position = home
		end
		local viewport = card:FindFirstChild("RevealViewport", true)
		if viewport and viewport:IsA("ViewportFrame") then
			Viewports.clear(viewport)
		end
	end
	local tapHint = find(canvas, "TapHint")
	if tapHint then
		tapHint.Visible = false
	end
	local counter = find(canvas, "RevealCounter")
	if counter then
		counter.Visible = false
	end
end

return CardReveal
