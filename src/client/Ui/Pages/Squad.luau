--!strict
-- Squad - every hero the player owns, on the plot or on the bench: place,
-- bench, fuse, sell, Equip Best and the auto-sell toggles. One row per hero
-- uid, created once and updated in place.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Income = require(ReplicatedStorage.Shared.Core.Income)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local SquadRules = require(ReplicatedStorage.Shared.Core.Squad)
local Screens = require(script.Parent.Parent.Screens)
local Theme = require(script.Parent.Parent.Theme)
local Viewports = require(script.Parent.Parent.Viewports)
local Types = require(script.Parent.Types)

local MAPS = Lookup.of(Config)

local Squad = { name = "Squad" } :: Types.Page

local ctx: Types.Ctx
local gui: ScreenGui
local list: ScrollingFrame
local rows: Screens.RowSet
local showBench = false

local function incomeOf(state: any): (any) -> number
	local best = Income.best(Config, MAPS, state.heroes)
	return function(hero: any): number
		return Income.hero(Config, MAPS, hero, best)
	end
end

-- PLACE puts a bench hero on a free pedestal, or swaps it for the weakest
-- hero on the plot; BENCH takes a plot hero off. The server decides.
local function place(uid: string)
	local state = ctx.state()
	local hero = state and state.heroes[uid]
	if not hero then
		return
	end
	if hero.slot > 0 then
		ctx.fire("SquadAction", "bench", uid)
		return
	end
	local slot = SquadRules.freeSlot(state.heroes, state.slots)
	if not slot then
		local weakest = SquadRules.weakest(state.heroes, true, incomeOf(state))
		slot = if weakest then state.heroes[weakest].slot else 1
	end
	ctx.fire("SquadAction", "place", uid, slot)
end

local function setting(key: string)
	local state = ctx.state()
	if state then
		ctx.fire("SettingSet", key, state.settings[key] ~= true)
	end
end

function Squad.render(state: any)
	local income = incomeOf(state)
	local onPlot, onBench = SquadRules.counts(state.heroes)
	Screens.label(gui, "SlotCount").Text = `PLOT {onPlot}/{state.slots}`
	Screens.label(gui, "BenchCount").Text = `BENCH {onBench}/{state.benchSlots}`
	Screens.setButtonState(Screens.button(gui, "TabPlot"), if showBench then "idle" else "neutral")
	Screens.setButtonState(Screens.button(gui, "TabBench"), if showBench then "neutral" else "idle")
	local settings = state.settings
	Screens.setButtonState(
		Screens.button(gui, "AutoSellCommon"),
		if settings.autoSellCommon == true then "afford" else "idle"
	)
	Screens.setButtonState(
		Screens.button(gui, "AutoSellUncommon"),
		if settings.autoSellUncommon == true then "afford" else "idle"
	)

	local order = {}
	local earns: { [string]: number } = {}
	for uid, hero in state.heroes do
		earns[uid] = income(hero)
		table.insert(order, uid)
	end
	table.sort(order, function(a: string, b: string): boolean
		if earns[a] ~= earns[b] then
			return earns[a] > earns[b]
		end
		return a < b
	end)

	local plot = Config.Plot
	Screens.syncRows(rows, order, function(row: GuiObject, uid: string, _, isNew: boolean)
		local hero = state.heroes[uid]
		local character = MAPS.character[hero.id] or MAPS.premium[hero.id]
		local rarity = if character and character.Rarity then character.Rarity else "Premium"
		local placeButton = Screens.button(row, "PlaceButton")
		if isNew then
			placeButton.Activated:Connect(function()
				place(uid)
			end)
			Screens.button(row, "FuseButton").Activated:Connect(function()
				ctx.fire("SquadAction", "fuse", uid)
			end)
			Screens.button(row, "SellButton").Activated:Connect(function()
				ctx.fire("SquadAction", "sell", uid)
			end)
			Screens.label(row, "HeroName").Text = if character then character.Name else hero.id
			Screens.label(row, "RarityText").Text = rarity:upper()
			Screens.tint(Screens.frame(row, "RarityTag"), Theme.rarity(rarity))
			Screens.frame(row, "SizeTagCell").Visible = hero.size ~= nil
			Screens.label(row, "SizeText").Text = if hero.size then hero.size:upper() else ""
			Screens.frame(row, "MutationTagCell").Visible = hero.mut ~= nil
			Screens.label(row, "MutationText").Text = if hero.mut then hero.mut:upper() else ""
			Screens.tint(Screens.frame(row, "MutationTag"), Theme.mutation(hero.mut))
			Screens.tint(Screens.viewport(row, "Thumb"), Theme.rarity(rarity))
			Screens.tint(Screens.frame(row, "RarityStripe"), Theme.rarity(rarity))
		end
		local benched = hero.slot <= 0
		row.Visible = benched == showBench
		if row.Visible then
			-- the 3D thumb is only built for rows the player can see
			Viewports.hero(Screens.viewport(row, "Thumb"), hero.id)
		end
		for star = 1, 3 do
			Screens.image(row, "Star" .. star).Visible = star <= hero.stars
		end
		Screens.label(row, "IncomeText").Text = `+{Format.short(earns[uid])}/s`
		Screens.label(row, "LocationText").Text = if benched
			then "ON BENCH"
			else `ON PLOT {hero.slot}`
		Screens.label(placeButton, "PlaceText").Text = if benched then "PLACE" else "BENCH"
		Screens.setButtonState(
			placeButton,
			if benched then "afford" else "neutral",
			nil,
			if benched then "IconPlace" else "IconBench"
		)
		Screens.button(row, "FuseButton").Visible = SquadRules.fusePartners(
			state.heroes,
			uid,
			plot.FuseCount,
			plot.MaxStars
		) ~= nil
	end)
end

function Squad.init(context: Types.Ctx)
	ctx = context
	gui = Screens.get("Squad")
	list = Screens.scroller(gui, "HeroList")
	rows = Screens.rows(list, "HeroRowTemplate")

	local function tab(bench: boolean)
		showBench = bench
		list.CanvasPosition = Vector2.zero
		local state = ctx.state()
		if state then
			Squad.render(state)
		end
	end
	Screens.button(gui, "TabPlot").Activated:Connect(function()
		tab(false)
	end)
	Screens.button(gui, "TabBench").Activated:Connect(function()
		tab(true)
	end)
	Screens.button(gui, "AutoSellCommon").Activated:Connect(function()
		setting("autoSellCommon")
	end)
	Screens.button(gui, "AutoSellUncommon").Activated:Connect(function()
		setting("autoSellUncommon")
	end)
	Screens.button(gui, "EquipBest").Activated:Connect(function()
		ctx.fire("SquadAction", "equipBest")
	end)
end

return Squad
