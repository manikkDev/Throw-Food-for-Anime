--!strict
-- FoodShop - the foods, in ONE row that scrolls sideways (touch drag, or the
-- mouse wheel: Screens reads the row's WheelScrollsX attribute): buy with
-- Yen, pin, and how many heroes not yet caught love each dish. Cards are built
-- once and updated in place; opening the page brings the NEXT food into view.
--
-- Plan 13: three dishes per world (Snack, Meal, Signature). A card shows the
-- worlds the player has reached and the next one. The game throws the BEST
-- owned food for the aimed world by itself (IN USE); pressing an owned food
-- PINS it instead, pressing the pinned one again goes back to auto.
--
-- What a card says about itself (design/ui/CHANGES-v3.md):
--   * its art tile is tinted by the food's role
--   * the first food the player does not own is NEXT: a NEXT tag and a gold
--     keyline; the foods after it are dimmed
--   * its button is a state: EQUIPPED (a flat pill), EQUIP, the price when
--     the player can pay, the price in the cannot-afford look when not
--     (re-checked every second, as Yen moves)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local Foods = require(ReplicatedStorage.Shared.Core.Foods)
local Progress = require(ReplicatedStorage.Shared.Core.Progress)
local FoodLook = require(script.Parent.Parent.FoodLook)
local Screens = require(script.Parent.Parent.Screens)
local Theme = require(script.Parent.Parent.Theme)
local Viewports = require(script.Parent.Parent.Viewports)
local Types = require(script.Parent.Types)

local MAPS = Lookup.of(Config)
-- the four flavour filters of the old shop are hidden (flavours are gone): only All is left
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
	if not state then
		return
	end
	if state.foods[foodId] then
		-- owned: pin it; the pinned one again = back to auto-pick
		local pinned = state.autoFood == false and state.food == foodId
		ctx.fire("FoodEquip", if pinned then "auto" else foodId)
	else
		ctx.fire("ShopBuy", "food", foodId)
	end
end

function FoodShop.render(state: any)
	-- how many heroes not yet in the index love each dish
	local craving: { [string]: number } = {}
	for _, character in Config.Characters do
		if not state.index[character.Id] then
			craving[character.Favourite] = (craving[character.Favourite] or 0) + 1
		end
	end
	local best = state.bestZone or 1
	local inUse, target = FoodLook.current(state)
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
			Screens.label(card, "TierText").Text = `W{food.Zone}`
			Screens.label(card, "FoodName").Text = food.Name
			Screens.label(card, "PowerText").Text = food.Role:upper()
			Screens.image(card, "FlavorIcon").Visible = false
			Screens.image(card, "PowerIcon").Visible = false
			Screens.tint(Screens.frame(card, "ArtTile"), FoodLook.tile(food))
			Viewports.food(Screens.viewport(card, "Viewport"), foodId)
			if stroke and not keyline then
				keyline = stroke.Color
			end
			buy.Activated:Connect(function()
				press(foodId)
			end)
		end
		-- the worlds reached, and the next one as a teaser
		card.Visible = food.Zone <= best + 1
		-- its luck where the next throw goes: half past its own world
		local stale = Foods.isStale(food, target)
		Screens.label(card, "LuckText").Text = "LUCK "
			.. Format.mult(Foods.luckAt(Config, food, target))
			.. (if stale then " (HALF)" else "")

		local isNext = foodId == nextId
		Screens.frame(card, "NextTagCell").Visible = isNext
		if stroke then
			stroke.Color = if isNext then Theme.NEXT_GOLD else keyline or stroke.Color
		end
		Screens.tint(card, if pastNext then Theme.CARD_DIM else nil)
		if isNext then
			pastNext = true
		end

		local waiting = craving[food.Id] or 0
		Screens.frame(card, "CravePill").Visible = waiting > 0
		Screens.label(card, "CraveHint").Text = if waiting == 1
			then "+1 hero"
			else `+{waiting} heroes`

		local price = Screens.label(buy, "PriceText")
		if state.foods[foodId] and state.autoFood == false and state.food == foodId then
			price.Text = "PINNED"
			Screens.setButtonState(buy, "state")
		elseif state.foods[foodId] and inUse and inUse.Id == foodId then
			price.Text = "IN USE"
			Screens.setButtonState(buy, "state")
		elseif state.foods[foodId] then
			price.Text = "PIN"
			Screens.setButtonState(buy, "neutral", nil, "IconTick")
		else
			-- a food opens with its zone: until then the button names the zone
			local lock = Progress.lock(food, state.bestZone or 1, state.rebirth or 0)
			if lock and lock.zone then
				price.Text = `ZONE {lock.zone}`
				Screens.setButtonState(buy, "cannot", nil, "IconLock")
			else
				price.Text = Format.short(food.Cost)
				Screens.setButtonState(
					buy,
					if state.yen >= food.Cost then "afford" else "cannot",
					nil,
					"IconYen"
				)
			end
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
		-- the flavour filters went with the flavours (plan 13): the whole row is hidden
		local row = button.Parent and button.Parent.Parent
		if row and row:IsA("GuiObject") then
			row.Visible = false
		end
		if name ~= "All" then
			continue
		end
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
