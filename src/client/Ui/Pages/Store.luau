--!strict
-- Store - everything bought with Robux: passes, items, the starter pack and
-- the Summon Scroll banner. The odds are one press away (SEE ODDS opens
-- SummonOdds) before any scroll can be bought, and the scroll buttons are not
-- shown at all where paid random items are restricted (state.randomRestricted).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local Screens = require(script.Parent.Parent.Screens)
local Viewports = require(script.Parent.Parent.Viewports)
local Types = require(script.Parent.Types)

local MAPS = Lookup.of(Config)
local player = Players.LocalPlayer

-- shown in their own places, not in the ITEMS strip
local NOT_AN_ITEM = { gift = true, summon = true, starter = true, offline2x = true }

local PASS_ICONS: { [string]: string } = {
	DoubleYen = "IconYen",
	DoubleTraining = "IconTrain",
	Vip = "IconCrown",
	AutoThrow = "IconAuto",
	LuckyAura = "IconLuck",
	BigBench = "IconBench",
}
local KIND_ICONS: { [string]: string } = {
	lucky = "IconLuckyThrow",
	serverluck = "IconLuck",
	yen = "IconYen",
	train = "IconTrain",
	character = "IconStar",
}

local Store = { name = "Store" } :: Types.Page

local ctx: Types.Ctx
local gui: ScreenGui
local passCards: Screens.RowSet
local productCards: Screens.RowSet
local passKeys: { string } = {}
local productKeys: { string } = {}
local giftProducts: { [string]: any } = {} -- pass key -> its "gift" product
local stickers: { [string]: string } = {} -- product key -> "BEST VALUE" | "LIMITED"
local giftTo: Player? = nil
local bestScrollIsTen = false

-- "DoubleYen" -> "2x Yen", "AutoThrow" -> "Auto Throw", "Vip" -> "VIP"
local function passName(key: string): string
	if key == "Vip" then
		return "VIP"
	end
	local spaced = key:gsub("(%l)(%u)", "%1 %2")
	return (spaced:gsub("^Double ", "2x "))
end

local function productName(product: any): string
	if product.Kind == "lucky" then
		return `{product.Amount} Lucky Throw{if product.Amount == 1 then "" else "s"}`
	elseif product.Kind == "serverluck" then
		return "Server Luck"
	elseif product.Kind == "yen" then
		local minutes = product.Minutes
		return if minutes >= 60 then `{minutes // 60} hour Yen` else `{minutes} min Yen`
	elseif product.Kind == "train" then
		return `{product.Minutes} min Training`
	elseif product.Kind == "character" then
		local hero = MAPS.premium[product.Hero]
		return if hero then hero.Name else product.Key
	end
	return (product.Key:gsub("(%l)(%u)", "%1 %2"))
end

-- What one unit of a product is, for comparing prices inside its kind.
local function units(product: any): number?
	if product.Kind == "lucky" or product.Kind == "summon" then
		return product.Amount
	elseif product.Kind == "yen" or product.Kind == "train" then
		return product.Minutes
	end
	return nil
end

-- Stickers say only what the config says: BEST VALUE on the cheapest-per-unit
-- product of a kind that is sold in more than one size, LIMITED on a hero
-- whose Source is "Limited". Everything else has no sticker.
local function deriveStickers()
	local best: { [string]: { key: string, price: number, count: number } } = {}
	for _, product in Config.Monetization.Products do
		local per = units(product)
		if per and per > 0 then
			local price = product.Robux / per
			local seen = best[product.Kind]
			if not seen then
				best[product.Kind] = { key = product.Key, price = price, count = 1 }
			else
				seen.count += 1
				if price < seen.price then
					seen.key = product.Key
					seen.price = price
				end
			end
		elseif product.Kind == "character" then
			local hero = MAPS.premium[product.Hero]
			if hero and hero.Source == "Limited" then
				stickers[product.Key] = "LIMITED"
			end
		end
	end
	for _, seen in best do
		if seen.count > 1 then
			stickers[seen.key] = "BEST VALUE"
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

	local starter = MAPS.product.StarterPack
	local starterButton = Screens.button(gui, "StarterBuyButton")
	Screens.label(starterButton, "StarterPrice").Text = if state.starterPack
		then "OWNED"
		elseif starter then tostring(starter.Robux)
		else ""
	Screens.setButtonState(starterButton, if state.starterPack then "state" else "robux")
	-- BEST VALUE sits on the x10 scroll button's border: on only when x10 IS
	-- the best price per scroll, and only where scrolls are sold at all
	Screens.frame(gui, "BestValueStickerCell").Visible = bestScrollIsTen
		and not state.randomRestricted
	-- the starter pack can be bought once: LIMITED until it has been
	Screens.frame(gui, "LimitedStickerCell").Visible = not state.starterPack

	Screens.syncRows(passCards, passKeys, function(card: GuiObject, key: string, _, isNew: boolean)
		local pass = MAPS.pass[key]
		local buy = Screens.button(card, "PassBuyButton")
		if isNew then
			Screens.label(card, "PassName").Text = passName(key)
			Screens.setIcon(Screens.image(card, "Icon"), PASS_ICONS[key] or "IconStar")
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
		-- an owned pass is a state (OWNED), unless it is being bought as a gift
		Screens.setButtonState(buy, if owned and not gift then "state" else "robux")
	end)

	Screens.syncRows(
		productCards,
		productKeys,
		function(card: GuiObject, key: string, _, isNew: boolean)
			if not isNew then
				return
			end
			local product = MAPS.product[key]
			Screens.label(card, "ProductName").Text = productName(product)
			Screens.label(card, "ProductPrice").Text = tostring(product.Robux)
			Screens.setIcon(Screens.image(card, "Icon"), KIND_ICONS[product.Kind] or "IconStar")
			local sticker = stickers[key]
			Screens.frame(card, "StickerCell").Visible = sticker ~= nil
			Screens.label(card, "StickerText").Text = sticker or ""
			Screens.button(card, "ProductBuyButton").Activated:Connect(function()
				ctx.prompt(product, false)
			end)
		end
	)
end

function Store.opened()
	-- the banner shows the rarest scroll hero that is in the place
	local rarest: any = nil
	for _, hero in Config.PremiumCharacters do
		if hero.Source == "Summon" and (not rarest or hero.OddsPercent < rarest.OddsPercent) then
			rarest = hero
		end
	end
	Viewports.hero(Screens.viewport(gui, "SummonViewport"), if rarest then rarest.Id else nil)
end

function Store.init(context: Types.Ctx)
	ctx = context
	gui = Screens.get("Store")
	-- both are grids that grow inside StoreScroll, the one scroller of the page
	passCards = Screens.rows(Screens.frame(gui, "PassScroller"), "PassCardTemplate")
	productCards = Screens.rows(Screens.frame(gui, "ProductScroller"), "ProductCardTemplate")
	for _, pass in Config.Monetization.Passes do
		table.insert(passKeys, pass.Key)
	end
	for _, product in Config.Monetization.Products do
		if product.Kind == "gift" then
			giftProducts[product.Pass] = product
		elseif not NOT_AN_ITEM[product.Kind] then
			table.insert(productKeys, product.Key)
		end
	end

	deriveStickers()
	-- nothing in the config marks the banner as new: its NEW! sticker stays off
	Screens.frame(gui, "NewStickerCell").Visible = false
	bestScrollIsTen = stickers.SummonScroll10 == "BEST VALUE"
	Screens.frame(gui, "BestValueStickerCell").Visible = false

	for _, amount in { 1, 3, 10 } do
		local product = MAPS.product["SummonScroll" .. amount]
		local button = Screens.button(gui, "SummonBuy" .. amount)
		if product then
			Screens.label(button, "Count").Text = `x{product.Amount}`
			Screens.label(button, "Price").Text = tostring(product.Robux)
		end
		button.Activated:Connect(function()
			local state = ctx.state()
			if product and state and not state.randomRestricted then
				ctx.prompt(product, false)
			end
		end)
	end
	Screens.button(gui, "StarterBuyButton").Activated:Connect(function()
		local state = ctx.state()
		local starter = MAPS.product.StarterPack
		if starter and state and not state.starterPack then
			ctx.prompt(starter, false)
		end
	end)
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
