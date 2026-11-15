--!strict
-- FoodShop - the foods, in ONE row that scrolls sideways (touch drag, or the
-- mouse wheel: Screens reads the row's WheelScrollsX attribute): buy with
-- Yen, equip, and how many heroes not yet caught crave each flavour. Cards
-- are built once and updated in place; opening the page brings the NEXT food
-- into view.
--
-- What a card says about itself (design/ui/CHANGES-v3.md):
--   * its art tile is tinted by the food's flavour
--   * the first food the player does not own is NEXT: a NEXT tag and a gold
--     keyline; the foods after it are dimmed
--   * its button is a state: EQUIPPED (a flat pill), EQUIP, the price when
--     the player can pay, the price in the cannot-afford look when not
--     (re-checked every second, as Yen moves)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local Screens = require(script.Parent.Parent.Screens)
local Theme = require(script.Parent.Parent.Theme)
local Viewports = require(script.Parent.Parent.Viewports)
local Types = require(script.Parent.Types)

local MAPS = Lookup.of(Config)
local FILTERS = { "All", "Savory", "Sweet", "Spicy", "Seafood" }

local FoodShop = { name = "FoodShop" } :: Types.Page

local ctx: Types.Ctx
local scroller: ScrollingFrame
local cards: Screens.RowSet
local filterButtons: { [string]: GuiButton } = {}
local filter = "All"
local keys: { string } = {}
local keyline: Color3? = nil -- the card border as the tree ships it
local nextId: string? = nil -- the first food the player does not own

local function press(foodId: string)
	local state = ctx.state()
	if not state or state.food == foodId then
		return
	end
	if state.foods[foodId] then
		ctx.fire("FoodEquip", foodId)
	else
		ctx.fire("ShopBuy", "food", foodId)
	end
end

function FoodShop.render(state: any)
	-- how many heroes not yet in the index crave each flavour
	local craving: { [string]: number } = {}
	for _, character in Config.Characters do
		if not state.index[character.Id] then
			craving[character.Craves] = (craving[character.Craves] or 0) + 1
		end
	end
	-- the first food the player does not own is the next one to buy
	nextId = nil
	for _, food in Config.Foods do
		if not state.foods[food.Id] then
			nextId = food.Id
			break
		end
	end
	for name, button in filterButtons do
		Screens.setButtonState(button, if name == filter then "neutral" else "idle")
	end

	local pastNext = false
	Screens.syncRows(cards, keys, function(card: GuiObject, foodId: string, _, isNew: boolean)
		local food = MAPS.food[foodId]
		local buy = Screens.button(card, "BuyButton")
		local face = Screens.frame(card, "Face")
		local stroke = face:FindFirstChildOfClass("UIStroke")
		if isNew then
			Screens.label(card, "TierText").Text = `T{food.Tier}`
			Screens.label(card, "FoodName").Text = food.Name
			Screens.label(card, "PowerText").Text = "POWER " .. Format.mult(food.PowerMult)
			Screens.label(card, "LuckText").Text = "LUCK " .. Format.mult(food.Luck)
			Screens.setIcon(Screens.image(card, "FlavorIcon"), "IconFlavor" .. food.Flavor)
			Screens.tint(
				Screens.frame(card, "ArtTile"),
				Theme.FLAVOR_TILE[food.Flavor] or Theme.WHITE
			)
			Viewports.food(Screens.viewport(card, "Viewport"), foodId)
			if stroke and not keyline then
				keyline = stroke.Color
			end
			buy.Activated:Connect(function()
				press(foodId)
			end)
		end
		card.Visible = filter == "All" or food.Flavor == filter

		local isNext = foodId == nextId
		Screens.frame(card, "NextTagCell").Visible = isNext
		if stroke then
			stroke.Color = if isNext then Theme.NEXT_GOLD else keyline or stroke.Color
		end
		Screens.tint(card, if pastNext then Theme.CARD_DIM else nil)
		if isNext then
			pastNext = true
		end

		local waiting = craving[food.Flavor] or 0
		Screens.frame(card, "CravePill").Visible = waiting > 0
		Screens.label(card, "CraveHint").Text = if waiting == 1
			then "+1 hero"
			else `+{waiting} heroes`

		local price = Screens.label(buy, "PriceText")
		if state.food == foodId then
			price.Text = "EQUIPPED"
			Screens.setButtonState(buy, "state")
		elseif state.foods[foodId] then
			price.Text = "EQUIP"
			Screens.setButtonState(buy, "neutral", nil, "IconTick")
		else
			price.Text = Format.short(food.Cost)
			Screens.setButtonState(
				buy,
				if state.yen >= food.Cost then "afford" else "cannot",
				nil,
				"IconYen"
			)
		end
	end, true)
end

FoodShop.tick = FoodShop.render

-- Bring the NEXT card (the first food not owned yet) into view, a little
-- left of the middle of the row. Measured on screen, so it does not care how
-- the row is laid out; run once the layout has settled.
local function seekNext()
	local card = nextId and cards.rows[nextId]
	local width = scroller.Size.X.Offset
	if not card or not card.Visible or width <= 0 or scroller.AbsoluteSize.X <= 0 then
		return
	end
	local scale = scroller.AbsoluteSize.X / width -- screen px per canvas unit
	local middle = card.AbsolutePosition.X + card.AbsoluteSize.X / 2
	local wanted = scroller.AbsolutePosition.X + 0.42 * scroller.AbsoluteSize.X
	scroller.CanvasPosition = Vector2.new(
		math.max(0, scroller.CanvasPosition.X + (middle - wanted) / scale),
		scroller.CanvasPosition.Y
	)
end

function FoodShop.opened()
	Viewports.spin(scroller)
	-- after this open's render and the layout pass that follows it
	task.spawn(function()
		task.wait()
		task.wait()
		if Screens.isOpen("FoodShop") then
			seekNext()
		end
	end)
end

function FoodShop.closed()
	Viewports.spin(nil)
end

function FoodShop.init(context: Types.Ctx)
	ctx = context
	local gui = Screens.get("FoodShop")
	scroller = Screens.scroller(gui, "FoodScroller")
	cards = Screens.rows(scroller, "FoodCardTemplate")
	for _, food in Config.Foods do
		table.insert(keys, food.Id)
	end
	for _, name in FILTERS do
		local button = Screens.button(gui, "Filter" .. name)
		filterButtons[name] = button
		button.Activated:Connect(function()
			filter = name
			scroller.CanvasPosition = Vector2.zero
			local state = ctx.state()
			if state then
				FoodShop.render(state)
			end
		end)
	end
end

return FoodShop
