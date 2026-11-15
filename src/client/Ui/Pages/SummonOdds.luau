--!strict
-- SummonOdds - what a Summon Scroll can give and how likely each hero is,
-- straight from Config.PremiumCharacters. Reachable from the Store before any
-- purchase; its own buy buttons are hidden where paid random items are
-- restricted.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local Screens = require(script.Parent.Parent.Screens)
local Viewports = require(script.Parent.Parent.Viewports)
local Types = require(script.Parent.Types)

local MAPS = Lookup.of(Config)
local ROW_COUNT = 6 -- OddsRow1..6 ship in the tree

local SummonOdds = { name = "SummonOdds" } :: Types.Page

local ctx: Types.Ctx
local gui: ScreenGui
local heroes: { any } = {}

function SummonOdds.render(state: any)
	Screens.frame(gui, "BuyButtons").Visible = not state.randomRestricted
end

function SummonOdds.opened()
	for index, hero in heroes do
		if index <= ROW_COUNT then
			Viewports.hero(
				Screens.viewport(Screens.frame(gui, "OddsRow" .. index), "Portrait"),
				hero.Id
			)
		end
	end
end

function SummonOdds.init(context: Types.Ctx)
	ctx = context
	gui = Screens.get("SummonOdds")
	local total = 0
	for _, hero in Config.PremiumCharacters do
		if hero.Source == "Summon" then
			table.insert(heroes, hero)
			total += hero.OddsPercent
		end
	end
	for index = 1, ROW_COUNT do
		local row = Screens.frame(gui, "OddsRow" .. index)
		local hero = heroes[index]
		row.Visible = hero ~= nil
		if hero then
			Screens.label(row, "HeroName").Text = hero.Name
			Screens.label(row, "OddsEarn").Text =
				`{Format.mult(hero.BestIncomeMult):sub(2)}x your best`
			Screens.label(row, "OddsPercent").Text = `{hero.OddsPercent}%`
		end
	end
	Screens.label(gui, "Total").Text = `TOTAL: {total}%`

	for _, amount in { 1, 3, 10 } do
		local product = MAPS.product["SummonScroll" .. amount]
		local button = Screens.button(gui, "OddsBuy" .. amount)
		if product then
			Screens.label(button, "Label").Text = `x{product.Amount}  {product.Robux}`
		end
		button.Activated:Connect(function()
			local state = ctx.state()
			if product and state and not state.randomRestricted then
				ctx.prompt(product, false)
			end
		end)
	end
end

return SummonOdds
