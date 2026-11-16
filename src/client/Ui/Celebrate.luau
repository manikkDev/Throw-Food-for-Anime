--!strict
-- Celebrate - the purchase celebration (owner's review after section 6: "people are spending money:
-- make it cheerful, flashy and eye-catching, and present it properly"). The `Celebrate` screen
-- (DisplayOrder 60) sits above EVERY other screen, the Store page included.
--
-- One moment per purchase, queued, in this order:
--   1. the world behind blurs, the screen dims, a white flash in the item's colour
--   2. rays, sunburst, glow and halo bloom and turn (UiFx, at the rarity's pace)
--   3. the title ribbon SLAMS in (scale from 2.4, Back) with a short shake; fanfare
--   4. the item pops onto its stage: a pass / product icon that bobs, or the bought hero in 3D
--      performing a short showcase; its name and a rarity / kind chip
--   5. what was bought, line by line, each with a tick (what it gives, how much, for how long)
--   6. confetti bursts out of the centre and rains from the top, with star sparks
--   7. AWESOME! (or a tap anywhere, Enter, gamepad A) closes it; the next one in the queue plays
-- Summon scrolls show their 1 / 3 / 10 cards face down, then flip them one by one; the rarer the
-- hero, the bigger the flash and the louder the sting.
--
-- Everything shown comes from the "Purchased" event (StoreService) and the same words as the
-- Store page (Ui/StoreText). It never errors: a missing piece is skipped.

local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Icons = require(ReplicatedStorage.Shared.Config.Icons)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local CardReveal = require(script.Parent.CardReveal)
local Screens = require(script.Parent.Screens)
local StoreText = require(script.Parent.StoreText)
local Theme = require(script.Parent.Theme)
local UiFx = require(script.Parent.UiFx)
local Viewports = require(script.Parent.Viewports)

local MAPS = Lookup.of(Config)
local C: any = Config

local Celebrate = {}

local GOLD = Color3.fromHex("FFC93C")
local PINK = Color3.fromHex("FF4FA3")
local CONFETTI = {
	Color3.fromHex("FF4D6D"),
	Color3.fromHex("FFC93C"),
	Color3.fromHex("4ADE80"),
	Color3.fromHex("38BDF8"),
	Color3.fromHex("A855F7"),
	Color3.fromHex("FF8A2E"),
	Color3.fromHex("FFFFFF"),
}
local MAX_CARDS = 10
local MAX_PERKS = 3
local RARITY_ORDER =
	{ Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 7 }

type Card = {
	title: string,
	sub: string,
	name: string,
	chip: string,
	color: Color3,
	rarity: string?,
	icon: string?,
	hero: string?,
	perks: { string },
	heroes: { any }?,
}

local gui: ScreenGui? = nil
-- the card reveal waits for a tap: set while it waits
local tapWaiter: (() -> ())? = nil
local queue: { any } = {}
local running = false
-- Roblox's own purchase dialog ("Buy" -> "Purchase completed" -> OK) is open: the celebration waits
-- for it to close, then a short beat, so the player sees it pop up AFTER pressing OK (owner's review:
-- it played underneath the dialog and the OK click closed it)
local promptOpenAt: number? = nil
local promptClosedAt = 0
local AFTER_PROMPT = 0.45 -- seconds between the dialog closing and the celebration
local PROMPT_MAX_WAIT = 120 -- a dialog left open that long: celebrate anyway
local closing: (() -> ())? = nil
local token = 0

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

-- a UIScale on `target` (made once), for slams and pops that do not touch its layout
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

local function find(root: Instance, name: string): GuiObject?
	local found = root:FindFirstChild(name, true)
	return if found and found:IsA("GuiObject") then found else nil
end

-- a piece and the `<Name>Cell` wrapper the UI pipeline puts around chips and tags: the wrapper is
-- what has to be shown (it also carries the drop shadow)
local function whole(root: Instance, name: string): GuiObject?
	local cell = root:FindFirstChild(name .. "Cell", true)
	if cell and cell:IsA("GuiObject") then
		local inner = cell:FindFirstChild(name, true)
		if inner and inner:IsA("GuiObject") then
			inner.Visible = true
		end
		return cell
	end
	return find(root, name)
end

local function setText(root: Instance, name: string, text: string)
	local label = root:FindFirstChild(name, true)
	if label and (label:IsA("TextLabel") or label:IsA("TextButton")) then
		label.Text = text
	end
end

-- ------------------------------------------------------------- the words --

local function heroName(id: string): string
	local row = MAPS.character[id] or MAPS.premium[id]
	return if row then row.Name else id
end

-- a summon scroll hero's tier is its place in the scroll's odds, most likely first (as the odds
-- page labels them: Common .. Mythic)
local SCROLL_TIERS = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }
local scrollTier: { [string]: string } = {}
do
	local n = 0
	for _, hero in C.PremiumCharacters do
		if hero.Source == "Summon" then
			n += 1
			scrollTier[hero.Id] = SCROLL_TIERS[math.min(n, #SCROLL_TIERS)]
		end
	end
end

local function heroRarity(id: string): string
	if scrollTier[id] then
		return scrollTier[id]
	end
	local row = MAPS.character[id] or MAPS.premium[id]
	return if row and row.Rarity then row.Rarity else "Premium"
end

-- the moment for one purchase, from the server's facts
local function compose(p: any): Card?
	local key = tostring(p.key or "")
	if p.kind == "pass" or p.kind == "giftReceived" or p.kind == "gift" then
		local pass = MAPS.pass[key]
		if not pass then
			return nil
		end
		local name = StoreText.passName(key)
		local title, sub = "PASS UNLOCKED!", `{name} is yours, forever`
		if p.kind == "gift" then
			title, sub = "GIFT SENT!", `{name} for {tostring(p.to or "a friend")}`
		elseif p.kind == "giftReceived" then
			title, sub = "GIFT RECEIVED!", `{tostring(p.from or "A friend")} gifted you {name}`
		end
		return {
			title = title,
			sub = sub,
			name = name,
			chip = "GAME PASS",
			color = GOLD,
			rarity = "Legendary",
			icon = (StoreText.PASS_ICONS[key] or "IconStore") .. "Big",
			perks = {
				StoreText.passDesc(pass),
				"Active right now",
				"Yours on every server, forever",
			},
		}
	end
	local product = MAPS.product[key]
	if not product then
		return nil
	end
	local kind = product.Kind
	local card: Card = {
		title = "PURCHASE COMPLETE!",
		sub = "Thank you for supporting the game!",
		name = StoreText.productName(product),
		chip = "BOOST",
		color = Theme.CONFIRM,
		rarity = "Epic",
		icon = (StoreText.KIND_ICONS[kind] or "IconStore") .. "Big",
		perks = {},
	}
	if kind == "lucky" then
		card.color = Color3.fromHex("4ADE80")
		card.perks = {
			StoreText.productDesc(product),
			`You have {tonumber(p.total) or product.Amount} Lucky Throws`,
			"Switch LUCKY on at your throw pad",
		}
	elseif kind == "serverluck" then
		card.color = Color3.fromHex("4ADE80")
		card.chip = "SERVER BOOST"
		card.rarity = "Legendary"
		card.perks = {
			`Server luck is now {Format.mult(tonumber(p.luck) or 2)} for everyone`,
			`{C.Luck.ServerStepMinutes} more minutes`,
			"Everyone in the server sees your name",
		}
	elseif kind == "yen" or kind == "offline2x" then
		card.color = GOLD
		card.chip = "YEN"
		card.perks = {
			`+{Format.short(tonumber(p.yen) or 0)} yen`,
			if kind == "yen" then StoreText.productDesc(product) else "Your away earnings, doubled",
			"Paid into your yen right now",
		}
	elseif kind == "train" then
		card.color = Color3.fromHex("38BDF8")
		card.chip = "POWER"
		card.perks = {
			`+{Format.short(tonumber(p.power) or 0)} Power`,
			StoreText.productDesc(product),
			"Throw further, reach rarer zones",
		}
	elseif kind == "summon" then
		local heroes = if typeof(p.heroes) == "table" then p.heroes else {}
		for _, h in heroes do
			h.rarity = heroRarity(tostring(h.id))
		end
		card.title = "SUMMON!"
		card.sub = `{#heroes} hero{if #heroes == 1 then "" else "es"} joined your squad`
		card.chip = "SUMMON SCROLL"
		card.color = Color3.fromHex("A855F7")
		card.heroes = heroes
		card.icon = nil
		local best: any = nil
		for _, h in heroes do
			if not best or (RARITY_ORDER[h.rarity] or 0) > (RARITY_ORDER[best.rarity] or 0) then
				best = h
			end
		end
		card.rarity = if best then best.rarity else "Epic"
		card.name = if best then `Best: {heroName(best.id)}` else "Summon Scroll"
	elseif kind == "starter" or kind == "character" then
		local heroes = if typeof(p.heroes) == "table" then p.heroes else {}
		local first = heroes[1]
		local id = if first then first.id else product.Hero
		local rarity = heroRarity(id)
		card.hero = id
		card.icon = nil
		card.rarity = rarity
		card.color = Theme.rarity(rarity)
		card.name = heroName(id)
		card.chip = if kind == "starter" then "STARTER PACK" else "LIMITED HERO"
		local premium = MAPS.premium[id]
		local earns = premium and (premium :: any).BestIncomeMult
		if kind == "starter" then
			card.title = "STARTER PACK!"
			card.perks = {
				`{card.name} joined your squad`,
				`+{C.Rewards.StarterPackLuckyThrows} Lucky Throws`,
				`{C.Rewards.StarterPackDoubleYenMinutes} min of 2x Yen`,
			}
		else
			card.title = "NEW HERO!"
			card.perks = {
				if earns
					then `Earns {StoreText.fmt(earns)}x your best hero`
					else "A store exclusive hero",
				"Store exclusive: not in any scroll",
				"On your plot, earning now",
			}
		end
	end
	return card
end

-- ------------------------------------------------------------ the effects --

-- confetti: pieces burst out of the centre, then everything rains down, turning and swaying
local function confetti(
	layer: GuiObject,
	count: number,
	myToken: number,
	colours: { Color3 }?,
	burstOnly: boolean?
)
	local pieces: {
		{
			gui: GuiObject,
			x: number,
			y: number,
			vx: number,
			vy: number,
			spin: number,
			sway: number,
			phase: number,
		}
	} =
		{}
	-- the canvas is 1280 x 720 (scaled by its UIScale): positions are in canvas units
	local width = 1280
	for i = 1, count do
		local star = i % 6 == 0
		local piece = Screens.template(if star then "ConfettiStarTemplate" else "ConfettiTemplate")
		local palette = colours or CONFETTI
		local colour = palette[math.random(1, #palette)]
		if piece:IsA("ImageLabel") then
			piece.ImageColor3 = colour
		else
			piece.BackgroundColor3 = colour
		end
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		-- a tier step bursts out of the card all at once; the big moments add a rain from the top
		local fromCentre = burstOnly == true or i <= count * 0.55
		local x, y, vx, vy
		if fromCentre then
			local angle = math.random() * math.pi * 2
			local speed = 380 + math.random() * 520
			x, y = width / 2, 300
			vx, vy = math.cos(angle) * speed, math.sin(angle) * speed - 380
		else
			x, y = math.random() * width, -20 - math.random() * 260
			vx, vy = (math.random() - 0.5) * 60, 60 + math.random() * 120
		end
		piece.Position = UDim2.fromOffset(x, y)
		piece.Rotation = math.random(0, 359)
		piece.Visible = true
		piece.Parent = layer
		table.insert(pieces, {
			gui = piece,
			x = x,
			y = y,
			vx = vx,
			vy = vy,
			spin = (math.random() - 0.5) * 720,
			sway = 20 + math.random() * 40,
			phase = math.random() * 6,
		})
	end
	local started = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function(dt: number)
		local t = os.clock() - started
		if token ~= myToken or t > 5 then
			for _, p in pieces do
				p.gui:Destroy()
			end
			if connection then
				connection:Disconnect()
			end
			return
		end
		for _, p in pieces do
			p.vy += 620 * dt -- gravity
			p.vx *= 1 - 1.6 * dt -- air
			p.vy = math.min(p.vy, 260 + p.sway * 2) -- falling paper: terminal speed
			p.x += (p.vx + math.sin(t * 3 + p.phase) * p.sway) * dt
			p.y += p.vy * dt
			p.gui.Position = UDim2.fromOffset(p.x, p.y)
			p.gui.Rotation += p.spin * dt
			if t > 3.6 then
				local fade = (t - 3.6) / 1.4
				if p.gui:IsA("ImageLabel") then
					p.gui.ImageTransparency = fade
				else
					p.gui.BackgroundTransparency = fade
				end
			end
		end
	end)
end

local function blur(on: boolean)
	local effect = Lighting:FindFirstChild("CelebrateBlur")
	if not effect then
		local made = Instance.new("BlurEffect")
		made.Name = "CelebrateBlur"
		made.Size = 0
		made.Parent = Lighting
		effect = made
	end
	ease(effect :: Instance, 0.35, { Size = if on then 18 else 0 })
end

-- the slam: from big to its size with an overshoot, then a short shake
local function slam(target: GuiObject, from: number)
	local s = scaleOf(target, "SlamScale")
	s.Scale = from
	ease(s, 0.34, { Scale = 1 }, Enum.EasingStyle.Back)
	local home = target.Position
	task.delay(0.16, function()
		for i = 1, 5 do
			local j = 4 * (1 - i / 6)
			target.Position = home
				+ UDim2.fromOffset((math.random() - 0.5) * 2 * j, (math.random() - 0.5) * 2 * j)
			task.wait(0.03)
		end
		target.Position = home
	end)
end

-- a full-screen flash over everything (a tier upgrade, the final reveal): one Frame on the
-- ScreenGui, made once (the backdrop sits over the scrim, so the scrim cannot carry it)
local function flashLayer(screen: ScreenGui): Frame
	local found = screen:FindFirstChild("CardFlash")
	if found and found:IsA("Frame") then
		return found
	end
	local made = Instance.new("Frame")
	made.Name = "CardFlash"
	made.Size = UDim2.fromScale(1, 1)
	made.BorderSizePixel = 0
	made.BackgroundColor3 = Color3.new(1, 1, 1)
	made.BackgroundTransparency = 1
	made.ZIndex = 1000
	made.Parent = screen
	return made
end

-- the pack's summary: every card face up at once, rarest pulled to the eye
local function summaryGrid(root: Instance, heroes: { any })
	local grid = find(root, "SummonGrid")
	if not grid then
		return
	end
	grid.Visible = true
	for i = 1, MAX_CARDS do
		local slot = find(grid, "SummonCard" .. i)
		if slot then
			local hero = heroes[i]
			slot.Visible = hero ~= nil
			if hero then
				for _, wrapper in { "CardFrontCell", "CardRarityCell", "CardNewCell" } do
					local cell = slot:FindFirstChild(wrapper, true)
					if cell and cell:IsA("GuiObject") then
						cell.Visible = true
					end
				end
				local back = find(slot, "CardBack")
				local front = find(slot, "CardFront")
				if back then
					back.Visible = false
				end
				if front then
					front.Visible = true
					front.Size = UDim2.fromScale(1, 1)
				end
				local rarity = tostring(hero.rarity or "Common")
				local art = slot:FindFirstChild("CardFrameArt", true)
				if art and art:IsA("ImageLabel") then
					Screens.setIcon(art, "CardFrame_" .. rarity)
				end
				local portrait = slot:FindFirstChild("CardPortraitBg", true)
				if portrait and portrait:IsA("ImageLabel") then
					portrait.ImageColor3 = CardReveal.PORTRAIT_TINT[rarity] or Color3.new(1, 1, 1)
				end
				local banner = slot:FindFirstChild("CardBannerArt", true)
				if banner and banner:IsA("ImageLabel") then
					Screens.setIcon(banner, "CardBanner_" .. rarity)
				end
				setText(slot, "CardName", heroName(tostring(hero.id)))
				setText(slot, "CardRarityText", rarity:upper())
				local new = find(slot, "CardNew")
				if new then
					new.Visible = hero.isNew == true
				end
				local viewport = slot:FindFirstChild("CardViewport", true)
				if viewport and viewport:IsA("ViewportFrame") then
					Viewports.bright(viewport)
					Viewports.hero(viewport, tostring(hero.id))
				end
				local drop = scaleOf(slot, "DropScale")
				drop.Scale = 0
				task.delay(0.04 * i, function()
					ease(drop, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
				end)
			end
		end
	end
	Screens.sound("reward_pop")
end

-- ------------------------------------------------------------- one moment --

local function play(card: Card)
	local screen = gui
	if not screen then
		return
	end
	token += 1
	local myToken = token
	local canvas = screen:FindFirstChild("CanvasFrame") or screen
	local scrim = find(screen, "Scrim")
	local burst = find(canvas, "Burst")
	local ribbon = find(canvas, "TitleRibbon")
	local stage = canvas:FindFirstChild("ItemStage", true)
	local icon = canvas:FindFirstChild("ItemIcon", true)
	local disc = find(canvas, "StageDisc")
	local perkList = find(canvas, "PerkList")
	local grid = find(canvas, "SummonGrid")
	local button = canvas:FindFirstChild("CelebrateButton", true)
	local buttonWhole = whole(canvas, "CelebrateButton")
	local hint = find(canvas, "CelebrateHint")
	local layer = find(canvas, "ConfettiLayer")
	local rarityChip = whole(canvas, "RarityChip")
	local nameLabel = find(canvas, "ItemName")

	-- reset to the start of the moment (the light burst may have slid aside with a single card)
	local burstHome: UDim2 = UDim2.new()
	if burst then
		local saved = burst:GetAttribute("Home")
		burstHome = if typeof(saved) == "UDim2" then saved else burst.Position
		burst:SetAttribute("Home", burstHome)
		burst.Position = burstHome
	end
	local perkHome = if perkList then perkList:GetAttribute("Home") else nil
	if perkList and typeof(perkHome) == "UDim2" then
		perkList.Position = perkHome
	end
	CardReveal.hide(canvas)
	for _, piece in { stage, icon, disc, perkList, grid, rarityChip, nameLabel, hint } do
		if piece and piece:IsA("GuiObject") then
			piece.Visible = false
		end
	end
	if buttonWhole then
		buttonWhole.Visible = false
	end
	setText(canvas, "CelebrateTitle", card.title)
	setText(canvas, "CelebrateSub", card.sub)
	setText(canvas, "ItemName", card.name)
	setText(canvas, "RarityText", card.chip)
	local chipFace = find(canvas, "RarityChip")
	if chipFace then
		-- the chip beside the open card wears the card's own tier colour, so the two read as one item
		local chipColour = if card.rarity then Theme.rarity(card.rarity) else card.color
		Screens.tint(chipFace, chipColour:Lerp(Color3.new(0, 0, 0), 0.25))
	end

	screen.Enabled = true
	UiFx.activate("celebrate", true)
	blur(true)
	-- 1. dim, with a flash in the item's colour on the way
	if scrim then
		scrim.Visible = true
		scrim.BackgroundColor3 = card.color:Lerp(Color3.new(1, 1, 1), 0.55)
		scrim.BackgroundTransparency = 0.25
		ease(
			scrim,
			0.45,
			-- dark enough that the page underneath (the Store) steps back and the moment owns the screen
			{ BackgroundTransparency = 0.16, BackgroundColor3 = Color3.fromHex("0D0F2B") }
		)
	end
	-- 2. the light show behind, at the rarity's pace and in the item's colour
	if burst then
		burst.Visible = true
		UiFx.scan(burst)
		UiFx.setRarity(burst, card.rarity)
		UiFx.setColour(burst, card.color:Lerp(Color3.new(1, 1, 1), 0.25))
		local bloom = scaleOf(burst, "Bloom")
		bloom.Scale = 0.2
		ease(bloom, 0.55, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	-- 3. the title
	if ribbon then
		ribbon.Visible = true
		slam(ribbon, 2.4)
		local face = ribbon:FindFirstChild("Face") or ribbon
		if face:IsA("GuiObject") then
			task.delay(0.4, function()
				if token == myToken then
					UiFx.sweep(UiFx.makeShine(face, face, true), 0.8)
				end
			end)
		end
	end
	Screens.sound("level_up")
	task.delay(0.15, function()
		Screens.sound("buy_success")
	end)

	-- 4. the cards: everything bought is opened by tapping (Ui/CardReveal)
	local skip = false
	local alive = function(): boolean
		return token == myToken
	end
	local skipButton = canvas:FindFirstChild("SkipButton", true)
	local skipConnection: RBXScriptConnection? = nil
	if skipButton and skipButton:IsA("GuiButton") then
		skipConnection = skipButton.Activated:Connect(function()
			skip = true
			local waiter = tapWaiter
			if waiter then
				waiter()
			end
		end)
	end
	local canvasObject = canvas :: GuiObject
	local canvasHome = canvasObject.Position
	local env: CardReveal.Env = {
		waitTap = function()
			if skip then
				return
			end
			local tapped = Instance.new("BindableEvent")
			tapWaiter = function()
				tapWaiter = nil
				tapped:Fire()
			end
			tapped.Event:Wait()
			tapped:Destroy()
		end,
		skipped = function(): boolean
			return skip
		end,
		alive = alive,
		confetti = function(count: number, colours: { Color3 }?, burstOnly: boolean?)
			if layer then
				layer.Visible = true
				confetti(layer, count, myToken, colours, burstOnly)
			end
		end,
		flash = function(colour: Color3, peak: number)
			local flashFrame = flashLayer(screen)
			flashFrame.BackgroundColor3 = colour:Lerp(Color3.new(1, 1, 1), 0.45)
			flashFrame.BackgroundTransparency = 1 - peak * 0.85
			ease(flashFrame, 0.45, { BackgroundTransparency = 1 })
		end,
		shake = function(strength: number, seconds: number)
			task.spawn(function()
				local start = os.clock()
				while os.clock() - start < seconds and alive() do
					local k = strength * (1 - (os.clock() - start) / seconds)
					canvasObject.Position = canvasHome
						+ UDim2.fromOffset(
							(math.random() - 0.5) * 2 * k,
							(math.random() - 0.5) * 2 * k
						)
					task.wait()
				end
				canvasObject.Position = canvasHome
			end)
		end,
	}
	local items: { CardReveal.Item } = {}
	local summon = card.heroes ~= nil and #card.heroes > 0 and not card.hero
	if summon then
		for _, h in card.heroes :: { any } do
			table.insert(items, {
				tier = tostring(h.rarity or "Common"),
				hero = tostring(h.id),
				name = heroName(tostring(h.id)),
				isNew = h.isNew == true,
			})
		end
	elseif card.hero then
		table.insert(items, {
			tier = card.rarity or "Premium",
			hero = card.hero,
			name = card.name,
			label = card.chip,
		})
	else
		table.insert(items, {
			tier = card.rarity or "Epic",
			icon = card.icon,
			name = card.name,
			label = card.chip,
			climb = false,
		})
	end
	task.wait(0.35)
	CardReveal.run(canvas, items, env)
	if skipConnection then
		skipConnection:Disconnect()
	end
	tapWaiter = nil
	if not alive() then
		return
	end

	-- 5. after the cards: a pack shows everything it gave; one item shows what it gives
	if summon then
		CardReveal.hide(canvas)
		summaryGrid(canvas, card.heroes :: { any })
	else
		-- v5.0 (owner's review: the perk pills under the card were "not arranged and placed properly"):
		-- the open card slides LEFT and a details panel slides in beside it (name, type chip, what you get)
		local revealCard = find(canvas, "RevealCard")
		if perkList then
			local shift = perkList:GetAttribute("CardShift")
			local dx = if typeof(shift) == "number" then shift else -220
			if revealCard then
				local home = revealCard:GetAttribute("Home")
				local base = if typeof(home) == "UDim2" then home else revealCard.Position
				ease(
					revealCard,
					0.42,
					{ Position = base + UDim2.fromOffset(dx, 0) },
					Enum.EasingStyle.Quint
				)
			end
			if burst then
				ease(
					burst,
					0.42,
					{ Position = burstHome + UDim2.fromOffset(dx, 0) },
					Enum.EasingStyle.Quint
				)
			end
			local panelHome = perkList:GetAttribute("Home")
			local panelAt: UDim2 = if typeof(panelHome) == "UDim2"
				then panelHome
				else perkList.Position
			perkList:SetAttribute("Home", panelAt)
			perkList.Position = panelAt + UDim2.fromOffset(90, 0)
			perkList.Visible = true
			local slide = scaleOf(perkList, "PanelPop")
			slide.Scale = 0.85
			task.delay(0.12, function()
				if token == myToken then
					ease(perkList, 0.4, { Position = panelAt }, Enum.EasingStyle.Quint)
					ease(slide, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
					Screens.sound("reward_whoosh")
				end
			end)
			for _, piece in { nameLabel, rarityChip } do
				if piece then
					piece.Visible = true
				end
			end
			for i = 1, MAX_PERKS do
				local row = find(perkList, "Perk" .. i)
				if row then
					row.Visible = false
					local text = card.perks[i]
					if text then
						setText(row, "PerkText", text)
						task.delay(0.35 + 0.12 * i, function()
							if token == myToken then
								row.Visible = true
								Screens.pop(row, 0.8)
								Screens.sound("stat_tick")
							end
						end)
					end
				end
			end
		end
	end
	-- 6. the confetti rain
	if layer then
		layer.Visible = true
		confetti(layer, 60, myToken)
	end
	-- 7. the way out
	local done = false
	local bound: { RBXScriptConnection } = {}
	local finished = Instance.new("BindableEvent")
	local function close()
		if done then
			return
		end
		done = true
		closing = nil
		Screens.sound("ui_close")
		for _, c in bound do
			c:Disconnect()
		end
		finished:Fire()
	end
	task.delay(0.6, function()
		if token ~= myToken or done then
			return
		end
		if buttonWhole then
			buttonWhole.Visible = true
			Screens.pop(buttonWhole, 0.6)
		end
		if hint then
			hint.Visible = true
		end
		closing = close
		if button and button:IsA("GuiButton") then
			table.insert(bound, button.Activated:Connect(close))
		end
		if scrim and scrim:IsA("GuiButton") then
			table.insert(bound, scrim.Activated:Connect(close))
		end
	end)
	finished.Event:Wait()
	finished:Destroy()

	-- out
	token += 1
	blur(false)
	if scrim then
		ease(scrim, 0.2, { BackgroundTransparency = 1 })
	end
	local out = scaleOf(canvas :: GuiObject, "OutScale")
	ease(out, 0.18, { Scale = 0.92 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.wait(0.2)
	out.Scale = 1
	CardReveal.hide(canvas)
	if layer then
		for _, child in layer:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end
	if grid then
		for i = 1, MAX_CARDS do
			local viewport = grid:FindFirstChild("SummonCard" .. i, true)
			local vp = viewport and viewport:FindFirstChild("CardViewport", true)
			if vp and vp:IsA("ViewportFrame") then
				Viewports.clear(vp)
			end
		end
	end
	screen.Enabled = false
	UiFx.activate("celebrate", false)
end

--- Find the screen and listen for the keys. Safe to call more than once.
function Celebrate.bind()
	if gui then
		return
	end
	local screen = Screens.get("Celebrate")
	screen.Enabled = false
	gui = screen
	-- it stays until the player continues: once AWESOME! is up, the button, a tap or click on the
	-- screen, Enter, Space or gamepad A. A click something else already handled (Roblox's own dialog,
	-- another button) never counts. Nothing closes it on a timer.
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		local close = closing or tapWaiter
		if not close then
			return
		end
		local key = input.KeyCode == Enum.KeyCode.Return
			or input.KeyCode == Enum.KeyCode.ButtonA
			or input.KeyCode == Enum.KeyCode.Space
		local tap = input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		if key or (tap and not processed) then
			close()
		end
	end)
	-- every card frame, banner and the celebration art, downloaded now in the background: a tier
	-- upgrade swaps its art at once, and an image fetched only then shows blank for a moment
	-- (found in play: the Uncommon frame was empty right after the upgrade)
	task.spawn(function()
		local images: { Instance } = {}
		for key, id in Icons :: { [string]: string } do
			if id ~= "" and (key:sub(1, 4) == "Card" or key:sub(1, 9) == "Celebrate") then
				local image = Instance.new("ImageLabel")
				image.Image = id
				table.insert(images, image)
			end
		end
		pcall(function()
			ContentProvider:PreloadAsync(images)
		end)
		for _, image in images do
			image:Destroy()
		end
	end)
	-- the purchase dialog closing (bought or not) lets a waiting celebration play
	MarketplaceService.PromptProductPurchaseFinished:Connect(function()
		Celebrate.promptClosed()
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function()
		Celebrate.promptClosed()
	end)
end

--- Roblox's purchase dialog is about to open (MenuController:Prompt calls this): any celebration
--- waits until it closes.
function Celebrate.promptOpened()
	promptOpenAt = os.clock()
end

--- Roblox's purchase dialog closed.
function Celebrate.promptClosed()
	promptOpenAt = nil
	promptClosedAt = os.clock()
end

-- wait while the purchase dialog is up, then the short beat after it
local function waitForPrompt()
	while promptOpenAt and os.clock() - promptOpenAt < PROMPT_MAX_WAIT do
		task.wait(0.1)
	end
	local since = os.clock() - promptClosedAt
	if since < AFTER_PROMPT then
		task.wait(AFTER_PROMPT - since)
	end
end

--- Celebrate one purchase (the "Purchased" event's payload). Queued: one at a time.
function Celebrate.show(payload: any)
	Celebrate.bind()
	local ok, card = pcall(compose, payload)
	if not ok or not card then
		if not ok then
			warn(`[Celebrate] could not compose: {card}`)
		end
		return
	end
	table.insert(queue, card)
	if running then
		return
	end
	running = true
	task.spawn(function()
		while #queue > 0 do
			waitForPrompt()
			local nextUp = table.remove(queue, 1)
			local played, err = pcall(play, nextUp)
			if not played then
				warn(`[Celebrate] failed inert: {err}`)
				local screen = gui
				if screen then
					screen.Enabled = false
				end
				blur(false)
			end
			task.wait(0.15)
		end
		running = false
	end)
end

--- True while a celebration is on screen.
function Celebrate.isOpen(): boolean
	return running
end

Celebrate.PINK = PINK

return Celebrate
