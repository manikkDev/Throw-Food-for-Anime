--!strict
-- Store - everything bought with Robux (UI v5.2, owner's review 6): a premium
-- shop in sections. Every store hero stands in a framed glass panel and
-- performs a sequence of clips (Viewports.heroSequence), never one idle on
-- repeat; nothing in the store pulses in size (StoreFx.shine instead).
--
--   left       SUMMON SCROLL: the rarest scroll hero on a 3D stage (its idle,
--              a slow camera dolly) inside the owner's own aura / flame /
--              lightning textures (Ui/StoreFx), its rarity chip shimmering,
--              its drop chance, what it earns, SEE ODDS, the pool size, and
--              three buy tiles: the count ABOVE each button, the Robux price
--              alone IN it, BEST VALUE on the x10 tile's edge
--   FEATURED   the starter pack and the limited hero as showcase cards (hero
--              animated, what is inside with icons, sticker, light-chase rim)
--   GAMEPASSES each pass with a short exact description of what it grants
--   LUCK & BOOSTS / YEN PACKS  each product with what it does
--
-- Every description is built from the config values the server applies
-- (StoreService, Luck, SquadService, TrainingService, ThrowController), so
-- nothing promises a perk the game does not grant. The odds are one press
-- away (SEE ODDS) before any scroll can be bought, and the scroll tiles are
-- not shown where paid random items are restricted (state.randomRestricted).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local Screens = require(script.Parent.Parent.Screens)
local StoreFx = require(script.Parent.Parent.StoreFx)
local StoreText = require(script.Parent.Parent.StoreText)
local Viewports = require(script.Parent.Parent.Viewports)
local Types = require(script.Parent.Types)

local MAPS = Lookup.of(Config)
local player = Players.LocalPlayer
local C: any = Config

-- where each product kind is sold
local SECTION_OF: { [string]: string } = {
	lucky = "boosts",
	serverluck = "boosts",
	train = "boosts",
	yen = "yen",
}
local SECTIONS: { [string]: { face: Color3, rim: Color3, bg: string } } = {
	boosts = { face = Color3.fromHex("2FC48A"), rim = Color3.fromHex("B9F5DD"), bg = "BgSakura" },
	yen = { face = Color3.fromHex("FFB52E"), rim = Color3.fromHex("FFEFB8"), bg = "BgClouds" },
}
local PASS_ICONS = StoreText.PASS_ICONS
local KIND_ICONS: { [string]: string } = {
	lucky = "IconLuckyThrow",
	serverluck = "IconLuck",
	yen = "IconYen",
	train = "IconTrain",
	character = "IconStar",
}
-- the scroll pool's tiers, commonest first (as SummonOdds shows them)
local TIERS = { "COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY", "MYTHIC" }
local TIER_COLOURS: { [string]: { Color3 } } = {
	MYTHIC = {
		Color3.fromHex("FF4D6D"),
		Color3.fromHex("FFB020"),
		Color3.fromHex("FFE14D"),
		Color3.fromHex("4ADE80"),
		Color3.fromHex("38BDF8"),
		Color3.fromHex("A855F7"),
		Color3.fromHex("FF4D6D"),
	},
	LEGENDARY = { Color3.fromHex("FFE14D"), Color3.fromHex("FF9F1A"), Color3.fromHex("FFE14D") },
}
-- the summon hero's name: light at the top of the gradient, the tier's hue
local NAME_COLOURS: { [string]: { Color3 } } = {
	MYTHIC = {
		Color3.fromHex("FFFFFF"),
		Color3.fromHex("F5C2FF"),
		Color3.fromHex("D59BFF"),
		Color3.fromHex("FFFFFF"),
	},
	LEGENDARY = {
		Color3.fromHex("FFFFFF"),
		Color3.fromHex("FFE58A"),
		Color3.fromHex("FFC24D"),
		Color3.fromHex("FFFFFF"),
	},
}
local GOLD = Color3.fromHex("FFC93C")
-- each store hero's showcase: a confident base idle, flourishes between,
-- never the same clip twice in a row (Animations.luau clip names)
local SEQUENCES: { [string]: { Viewports.Beat } } = {
	-- the Blood Fiend: power and menace
	starter = {
		{ clip = "IdlePower", hold = 5 },
		{ clip = "HeroMenace", once = true, push = 1.1 },
		{ clip = "IdleCool", hold = 4.5 },
		{ clip = "RebirthAwaken", once = true, push = 1.06 },
		{ clip = "IdlePower", hold = 4 },
		{ clip = "RevealLand", once = true, push = 1.08 },
	},
	-- the First Sun Swordsman: the blade, calm
	limited = {
		{ clip = "IdleBlade", hold = 5.5 },
		{ clip = "HeroMenace", once = true, push = 1.1 },
		{ clip = "IdleCool", hold = 4 },
		{ clip = "RevealLand", once = true, push = 1.08 },
		{ clip = "IdleBlade", hold = 4.5 },
		{ clip = "IdleNinja", hold = 3.5 },
	},
	-- the summon hero (Illusion Overlord): untouchable, floating, then menace
	summon = {
		{ clip = "IdleCool", hold = 5 },
		{ clip = "IdleFloat", hold = 5 },
		{ clip = "HeroMenace", once = true, push = 1.1 },
		{ clip = "IdlePower", hold = 4 },
		{ clip = "RebirthEvolve", once = true, push = 1.06 },
		{ clip = "IdleFloat", hold = 4.5 },
	},
}
-- the card titles in their theme's colours (a slow sliding gradient)
local BLOOD_TITLE = {
	Color3.fromHex("FFFFFF"),
	Color3.fromHex("FFB3BA"),
	Color3.fromHex("FF3B4E"),
	Color3.fromHex("FFB3BA"),
	Color3.fromHex("FFFFFF"),
}
local SUN_TITLE = {
	Color3.fromHex("FFF6D0"),
	Color3.fromHex("FFD27A"),
	Color3.fromHex("FF8A2E"),
	Color3.fromHex("FFD27A"),
	Color3.fromHex("FFF6D0"),
}

local Store = { name = "Store" } :: Types.Page

local ctx: Types.Ctx
local gui: ScreenGui
local passCards: Screens.RowSet
local sectionCards: { [string]: Screens.RowSet } = {}
local sectionKeys: { [string]: { string } } = { boosts = {}, yen = {} }
local passKeys: { string } = {}
local giftProducts: { [string]: any } = {} -- pass key -> its "gift" product
local stickers: { [string]: string } = {} -- product key -> "BEST VALUE" | "GOOD VALUE" | "LIMITED"
local giftTo: Player? = nil
local bestScrollIsTen = false
local limitedHero: any = nil -- the "character" product of a Limited hero
local featured: any = nil -- the rarest scroll hero
local shows: { Viewports.Showcase } = {}

local fmt = StoreText.fmt

local passName = StoreText.passName

local passDesc = StoreText.passDesc

local productName = StoreText.productName

local productDesc = StoreText.productDesc

local function units(product: any): number?
	if product.Kind == "lucky" or product.Kind == "summon" then
		return product.Amount
	elseif product.Kind == "yen" or product.Kind == "train" then
		return product.Minutes
	end
	return nil
end

-- Stickers say only what the config says: in a kind sold in more than one
-- size, BEST VALUE on the cheapest per unit and GOOD VALUE on the runner-up
-- (three sizes or more); LIMITED on a hero whose Source is "Limited".
local function deriveStickers()
	local byKind: { [string]: { { key: string, price: number } } } = {}
	for _, product in Config.Monetization.Products do
		local per = units(product)
		if per and per > 0 then
			local list = byKind[product.Kind] or {}
			byKind[product.Kind] = list
			table.insert(list, { key = product.Key, price = product.Robux / per })
		elseif product.Kind == "character" then
			local hero = MAPS.premium[product.Hero]
			if hero and hero.Source == "Limited" then
				stickers[product.Key] = "LIMITED"
			end
		end
	end
	for _, list in byKind do
		if #list > 1 then
			table.sort(list, function(a, b)
				return a.price < b.price
			end)
			stickers[list[1].key] = "BEST VALUE"
			if #list >= 3 then
				stickers[list[2].key] = "GOOD VALUE"
			end
		end
	end
end

local function buyPass(key: string)
	local state = ctx.state()
	if not state then
		return
	end
	local target = giftTo
	local gift = giftProducts[key]
	if target and target.Parent and gift then
		-- tell the server who the next gift purchase is for, then buy it; the
		-- grant itself only ever happens in the server's receipt handler
		ctx.fire("StoreGiftTarget", target.UserId, gift.Key)
		ctx.prompt(gift, false)
	elseif state.passes[key] ~= true then
		ctx.prompt(MAPS.pass[key], true)
	end
end

local function dressProduct(card: GuiObject, key: string, section: string)
	local product = MAPS.product[key]
	Screens.label(card, "ProductName").Text = productName(product)
	Screens.label(card, "ProductDesc").Text = productDesc(product)
	Screens.label(card, "ProductPrice").Text = tostring(product.Robux)
	Screens.setIcon(Screens.image(card, "CardIcon"), KIND_ICONS[product.Kind] or "IconStar")
	local sticker = stickers[key]
	Screens.frame(card, "StickerCell").Visible = sticker ~= nil
	Screens.label(card, "StickerText").Text = sticker or ""
	if sticker then
		StoreFx.shine(Screens.frame(card, "StickerCell"), 3.6)
	end
	local look = SECTIONS[section]
	if look then
		Screens.tint(card, look.face)
		local face = Screens.frame(card, "Face")
		local stroke = face:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = look.rim
		end
		Screens.image(card, "CardBg").Image = Screens.icon(look.bg)
	end
	local buy = Screens.button(card, "ProductBuyButton")
	Screens.setButtonState(buy, "afford", nil, "IconRobux")
	buy.Activated:Connect(function()
		ctx.prompt(product, false)
	end)
end

-- the three lines of a featured card
local function perks(card: Instance, prefix: string, lines: { string })
	for i = 1, 3 do
		local row = Screens.frame(card, `{prefix}Perk{i}`)
		row.Visible = lines[i] ~= nil
		Screens.label(row, "PerkText").Text = lines[i] or ""
	end
end

function Store.render(state: any)
	local target = giftTo
	if target and not target.Parent then
		target = nil
		giftTo = nil
	end
	Screens.label(gui, "GiftTargetText").Text = if target
		then `FOR: {target.DisplayName}`
		else "GIFT A FRIEND"

	-- no paid random item is offered where they are restricted; the odds stay
	Screens.frame(gui, "BuyRow").Visible = not state.randomRestricted
	Screens.frame(gui, "BestValueStickerCell").Visible = bestScrollIsTen
		and not state.randomRestricted

	-- the starter pack can be bought once
	local starter = MAPS.product.StarterPack
	local starterButton = Screens.button(gui, "StarterBuyButton")
	Screens.label(starterButton, "StarterPrice").Text = if state.starterPack
		then "OWNED"
		elseif starter then tostring(starter.Robux)
		else ""
	Screens.setButtonState(
		starterButton,
		if state.starterPack then "state" else "afford",
		nil,
		if state.starterPack then nil else "IconRobux"
	)
	Screens.frame(gui, "StarterStickerCell").Visible = not state.starterPack

	Screens.syncRows(passCards, passKeys, function(card: GuiObject, key: string, _, isNew: boolean)
		local pass = MAPS.pass[key]
		local buy = Screens.button(card, "PassBuyButton")
		if isNew then
			Screens.label(card, "PassName").Text = passName(key)
			Screens.label(card, "PassDesc").Text = passDesc(pass)
			Screens.setIcon(Screens.image(card, "CardIcon"), PASS_ICONS[key] or "IconStar")
			Screens.frame(card, "StickerCell").Visible = false
			buy.Activated:Connect(function()
				buyPass(key)
			end)
		end
		local gift = if target then giftProducts[key] else nil
		local owned = state.passes[key] == true
		local price = Screens.label(buy, "PassPrice")
		if gift then
			price.Text = `GIFT {gift.Robux}`
		elseif owned then
			price.Text = "OWNED"
		else
			price.Text = tostring(pass.Robux)
		end
		if owned and not gift then
			Screens.setButtonState(buy, "state")
		else
			Screens.setButtonState(buy, "afford", nil, "IconRobux")
		end
	end)

	for section, set in sectionCards do
		Screens.syncRows(
			set,
			sectionKeys[section],
			function(card: GuiObject, key: string, _, isNew: boolean)
				if isNew then
					dressProduct(card, key, section)
				end
			end
		)
	end
end

local function stopShows()
	StoreFx.stop()
	for _, show in shows do
		show.stop()
	end
	table.clear(shows)
end

local function showcase(
	name: string,
	id: string?,
	beats: { Viewports.Beat },
	fill: number,
	rounded: boolean
)
	local frame = Screens.viewport(gui, name)
	-- rounded like its glass frame (ClipsDescendants clips a rectangle);
	-- the summon hero has no frame (v5.3), so his viewport stays square
	if rounded and not frame:FindFirstChildOfClass("UICorner") then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 14)
		corner.Parent = frame
	end
	local show = Viewports.heroSequence(frame, id, beats, fill)
	if show then
		table.insert(shows, show)
		StoreFx.stage(frame, show.step)
	end
end

function Store.opened()
	stopShows()
	if featured then
		showcase("SummonViewport", featured.Id, SEQUENCES.summon, 0.84, false)
	end
	local starter = MAPS.product.StarterPack
	local starterHero = if starter then MAPS.premium[starter.Hero] else nil
	if starterHero then
		showcase("StarterViewport", starterHero.Id, SEQUENCES.starter, 0.84, true)
	end
	local limited = if limitedHero then MAPS.premium[limitedHero.Hero] else nil
	if limited then
		showcase("LimitedHeroViewport", limited.Id, SEQUENCES.limited, 0.84, true)
	end
	StoreFx.start()
end

function Store.closed()
	-- nothing animates while the store is shut
	stopShows()
end

-- the summon banner: the rarest scroll hero, its tier, chance and earnings
local function dressSummon()
	local pool = {}
	for _, hero in Config.PremiumCharacters do
		if hero.Source == "Summon" then
			table.insert(pool, hero)
		end
	end
	-- commonest first: the last is the rarest, and the tier follows SummonOdds
	table.sort(pool, function(a: any, b: any): boolean
		return a.OddsPercent > b.OddsPercent
	end)
	featured = pool[#pool]
	local tier = TIERS[math.clamp(#pool, 1, #TIERS)]
	Screens.label(gui, "SummonPoolText").Text = `{#pool} EXCLUSIVE HEROES`
	local rarity = Screens.label(gui, "SummonRarityText")
	rarity.Text = if featured then tier else ""
	StoreFx.shimmer(rarity, TIER_COLOURS[tier] or { Color3.new(1, 1, 1) }, 0.4)
	StoreFx.shine(
		Screens.frame(gui, "SummonRarityCell"),
		3.4,
		Screens.icon("FxGlow"),
		Color3.fromHex("C084FC")
	)
	Screens.label(gui, "SummonChanceText").Text = if featured
		then `{fmt(featured.OddsPercent)}%`
		else ""
	local heroName = Screens.label(gui, "SummonHeroName")
	heroName.Text = if featured then featured.Name:upper() else ""
	-- the name in its rarity's colours (white text under a slow gradient)
	heroName.TextColor3 = Color3.new(1, 1, 1)
	StoreFx.shimmer(heroName, NAME_COLOURS[tier] or { Color3.new(1, 1, 1) }, 0.12)
	Screens.label(gui, "SummonHeroPerk").Text = if featured
		then `EARNS {fmt(featured.BestIncomeMult)}x YOUR BEST`
		else ""

	local single = MAPS.product.SummonScroll1
	for _, amount in { 1, 3, 10 } do
		local product = MAPS.product["SummonScroll" .. amount]
		local tile = Screens.frame(gui, "ScrollTile" .. amount)
		local button = Screens.button(tile, "SummonBuy" .. amount)
		tile.Visible = product ~= nil
		if product then
			Screens.label(tile, "ScrollCount").Text = `x{product.Amount}`
			Screens.label(button, "Price").Text = tostring(product.Robux)
			Screens.setButtonState(button, "afford", nil, "IconRobux")
			local note = Screens.label(tile, "ScrollNote")
			local save = if single and product.Amount > 1
				then math.floor((1 - product.Robux / (product.Amount * single.Robux)) * 100 + 0.5)
				else 0
			note.Text = if save > 0 then `SAVE {save}%` else `{product.Robux} EACH`
		end
		button.Activated:Connect(function()
			local state = ctx.state()
			if product and state and not state.randomRestricted then
				ctx.prompt(product, false)
			end
		end)
	end
	bestScrollIsTen = stickers.SummonScroll10 == "BEST VALUE"
	StoreFx.border(Screens.frame(gui, "SummonBanner"), Color3.fromHex("C084FC"), 90)
	StoreFx.border(Screens.frame(gui, "ScrollTile10"), GOLD, 160)
	StoreFx.shine(Screens.frame(gui, "BestValueStickerCell"), 3.0, Screens.icon("FxGlow"), GOLD)
	-- v5.3 (owner's review 7): this hero stands on the stage with no glass
	-- frame round him (no rim chase, no glint)
end

local function dressFeatured()
	local starter = MAPS.product.StarterPack
	local banner = Screens.frame(gui, "StarterPackBanner")
	banner.Visible = starter ~= nil
	if starter then
		local hero = MAPS.premium[starter.Hero]
		local rewards = C.Rewards
		Screens.label(banner, "StarterTitle").Text = "STARTER PACK"
		perks(banner, "Starter", {
			if hero then `{hero.Name} hero` else "A hero",
			`{rewards.StarterPackLuckyThrows} Lucky Throws`,
			`{rewards.StarterPackDoubleYenMinutes} min 2x Yen`,
		})
		Screens.label(banner, "StarterStickerText").Text = "ONE-TIME OFFER"
		Screens.button(banner, "StarterBuyButton").Activated:Connect(function()
			local state = ctx.state()
			if state and not state.starterPack then
				ctx.prompt(starter, false)
			end
		end)
		StoreFx.border(banner, GOLD, 110)
		StoreFx.shine(
			Screens.frame(banner, "StarterStickerCell"),
			3.2,
			Screens.icon("FxGlow"),
			Color3.fromHex("FF3B4E")
		)
		-- blood flowing round the frame's rim, a glint across the glass
		local frame = Screens.frame(banner, "StarterFrame")
		StoreFx.border(frame, Color3.fromHex("FF2A40"), 55, Color3.fromHex("4A0008"))
		StoreFx.shine(frame, 5, nil, nil, UDim.new(0, 18), 9)
		StoreFx.shimmer(Screens.label(banner, "StarterTitle"), BLOOD_TITLE, 0.18)
	end

	local limited = Screens.frame(gui, "LimitedHeroBanner")
	limited.Visible = limitedHero ~= nil
	if limitedHero then
		local hero = MAPS.premium[limitedHero.Hero]
		Screens.label(limited, "LimitedHeroName").Text = productName(limitedHero):upper()
		perks(limited, "Limited", {
			if hero then `Earns {fmt(hero.BestIncomeMult)}x your best` else "Limited hero",
			"Store exclusive",
			"Not in any scroll",
		})
		Screens.label(limited, "LimitedStickerText").Text = if stickers[limitedHero.Key]
				== "LIMITED"
			then "LIMITED HERO"
			else "NEW HERO"
		local buy = Screens.button(limited, "LimitedHeroBuy")
		Screens.label(buy, "LimitedHeroPrice").Text = tostring(limitedHero.Robux)
		Screens.setButtonState(buy, "afford", nil, "IconRobux")
		buy.Activated:Connect(function()
			ctx.prompt(limitedHero, false)
		end)
		StoreFx.border(limited, Color3.fromHex("FF7A2E"), 130)
		StoreFx.shine(
			Screens.frame(limited, "LimitedStickerCell"),
			3.6,
			Screens.icon("FxGlow"),
			Color3.fromHex("FF9A2E")
		)
		-- fire running round the frame's rim, a glint across the glass
		local frame = Screens.frame(limited, "LimitedFrame")
		StoreFx.border(frame, Color3.fromHex("FFB347"), 90, Color3.fromHex("7A1E00"))
		StoreFx.shine(frame, 5.8, nil, nil, UDim.new(0, 18), 9)
		StoreFx.shimmer(Screens.label(limited, "LimitedHeroName"), SUN_TITLE, 0.18)
	end
end

function Store.init(context: Types.Ctx)
	ctx = context
	gui = Screens.get("Store")
	-- every grid grows inside StoreScroll, the one scroller of the page
	passCards = Screens.rows(Screens.frame(gui, "PassScroller"), "PassCardTemplate")
	sectionCards.boosts = Screens.rows(Screens.frame(gui, "ProductScroller"), "ProductCardTemplate")
	sectionCards.yen = Screens.rows(Screens.frame(gui, "YenScroller"), "ProductCardTemplate")
	for _, pass in Config.Monetization.Passes do
		table.insert(passKeys, pass.Key)
	end
	for _, product in Config.Monetization.Products do
		if product.Kind == "gift" then
			giftProducts[product.Pass] = product
		elseif product.Kind == "character" then
			local hero = MAPS.premium[product.Hero]
			if hero and hero.Source == "Limited" then
				limitedHero = product
			end
		else
			local section = SECTION_OF[product.Kind]
			if section then
				table.insert(sectionKeys[section], product.Key)
			end
		end
	end
	deriveStickers()
	-- the owner's VFX textures and flipbooks, one loop for all of them
	StoreFx.bind(gui, Screens.frame(gui, "StoreScroll"))
	dressSummon()
	dressFeatured()

	-- GIFT A FRIEND steps through the other players in this server
	Screens.button(gui, "GiftTarget").Activated:Connect(function()
		local others = {}
		for _, other in Players:GetPlayers() do
			if other ~= player then
				table.insert(others, other)
			end
		end
		table.sort(others, function(a: Player, b: Player): boolean
			return a.UserId < b.UserId
		end)
		local at = if giftTo then table.find(others, giftTo) or 0 else 0
		giftTo = others[at + 1]
		if #others == 0 then
			ctx.toast("Nobody else is here to gift to", "info")
		end
		local state = ctx.state()
		if state then
			Store.render(state)
		end
	end)
end

return Store
