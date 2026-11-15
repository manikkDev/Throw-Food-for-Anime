--!strict
-- HeroIndex - the collection: zone tabs with progress, a tile per hero with
-- its craving and the chance at the player's luck and food right now, and the
-- zone reward.
--
-- A hero not caught yet is an UNKNOWN tile: dark, named "???", with a "?" in
-- its rarity colour where the portrait would be (no model is built for it).
-- A zone the player cannot throw into yet carries a lock on its tab. The
-- tabs live in a scroller: the tree ships six, and a zone beyond that gets a
-- copy of the last one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Collection = require(ReplicatedStorage.Shared.Core.Collection)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local Roll = require(ReplicatedStorage.Shared.Core.Roll)
local Throw = require(ReplicatedStorage.Shared.Core.Throw)
local Screens = require(script.Parent.Parent.Screens)
local Theme = require(script.Parent.Parent.Theme)
local Viewports = require(script.Parent.Parent.Viewports)
local Types = require(script.Parent.Types)

local MAPS = Lookup.of(Config)

local HeroIndex = { name = "HeroIndex" } :: Types.Page

local ctx: Types.Ctx
local gui: ScreenGui
local grid: ScrollingFrame
local tiles: Screens.RowSet
local tabs: { GuiButton } = {}
local tabCells: { GuiObject } = {}
local selected = 1

local function selectZone(index: number)
	if not Config.Zones[index] then
		return
	end
	selected = index
	grid.CanvasPosition = Vector2.zero
	local state = ctx.state()
	if state then
		HeroIndex.render(state)
	end
end

-- ZoneTab1.. as the tree ships them, then one copy of the last per extra zone
local function bindTabs()
	local index = 1
	while true do
		local found = gui:FindFirstChild("ZoneTab" .. index, true)
		if not found or not found:IsA("GuiButton") then
			break
		end
		tabs[index] = found
		local cell = found.Parent
		tabCells[index] = if cell
				and cell:IsA("GuiObject")
				and cell.Name == found.Name .. "Cell"
			then cell
			else found
		index += 1
	end
	local last = tabCells[#tabCells]
	while last and #tabs < #Config.Zones do
		local number = #tabs + 1
		local cell = last:Clone()
		local button = cell:FindFirstChildWhichIsA("GuiButton") or cell
		cell.Name = `ZoneTab{number}Cell`
		button.Name = "ZoneTab" .. number
		cell.LayoutOrder = last.LayoutOrder + (number - #tabCells)
		Screens.prepare(cell)
		cell.Parent = last.Parent
		tabCells[number] = cell
		tabs[number] = button :: GuiButton
	end
	for number, button in tabs do
		button.Activated:Connect(function()
			selectZone(number)
		end)
	end
end

function HeroIndex.render(state: any)
	local luck = ctx.luck()
	local food = MAPS.food[state.food]
	local flavor = if food then food.Flavor else nil
	local powerMult = if food then food.PowerMult else 1

	for index, tab in tabs do
		local zone = Config.Zones[index]
		tabCells[index].Visible = zone ~= nil
		if zone then
			local have, total = Collection.zoneProgress(state.index, MAPS.zoneCharacters[zone.Id])
			Screens.setButtonState(tab, if index == selected then "neutral" else "panel")
			Screens.label(tab, "ZoneName").Text = zone.Name
			Screens.label(tab, "ZoneProgress").Text = `{have}/{total}`
			Screens.fill(Screens.frame(tab, "Fill"), if total > 0 then have / total else 0)
			-- locked: a full-charge throw with the equipped food cannot reach it
			Screens.image(tab, "LockIcon").Visible = Throw.chargeForZone(
				Config.Throw,
				Config.Zones,
				state.power,
				powerMult,
				index
			) == nil
		end
	end

	local zone = Config.Zones[selected] or Config.Zones[1]
	local zoneCharacters = MAPS.zoneCharacters[zone.Id]
	local have, total = Collection.zoneProgress(state.index, zoneCharacters)
	local allHave, allTotal = Collection.total(Config, state.index)
	Screens.label(gui, "ZoneTitle").Text = zone.Name
	Screens.label(gui, "TotalText").Text = `TOTAL {allHave}/{allTotal}`
	Screens.label(gui, "LuckNote").Text = `Luck {Format.mult(luck)}`
	local claim = Screens.button(gui, "ZoneRewardClaim")
	local claimText = Screens.label(claim, "ClaimText")
	if state.zonesClaimed[zone.Id] then
		claimText.Text = "CLAIMED"
		Screens.setButtonState(claim, "state")
	elseif have == total then
		claimText.Text = "CLAIM!"
		Screens.setButtonState(claim, "afford")
	else
		claimText.Text = `{have}/{total} FOUND`
		Screens.setButtonState(claim, "off")
	end

	local keys: { string } = {}
	local chance: { [string]: number } = {}
	for _, weight in Roll.heroWeights(Config, zoneCharacters, luck, flavor) do
		table.insert(keys, weight.id)
		chance[weight.id] = weight.chance
	end
	Screens.syncRows(tiles, keys, function(tile: GuiObject, id: string, _, isNew: boolean)
		local character = MAPS.character[id]
		local known = state.index[id] ~= nil
		local rarity = Theme.rarity(character.Rarity)
		local portrait = Screens.viewport(tile, "Portrait")
		local mark = Screens.label(portrait, "UnknownMark")
		if isNew then
			Screens.setIcon(Screens.image(tile, "CraveIcon"), "IconFlavor" .. character.Craves)
			mark.TextColor3 = rarity
		end
		if tile:GetAttribute("Known") ~= known then
			tile:SetAttribute("Known", known)
			Screens.tint(tile, if known then rarity else Theme.UNKNOWN_TILE)
			Screens.tint(
				Screens.frame(tile, "RarityStripe"),
				if known then rarity else Theme.UNKNOWN_TILE
			)
			mark.Visible = not known
			Screens.label(tile, "HeroName").Text = if known then character.Name else "???"
		end
		Screens.label(tile, "ChanceText").Text = Format.percent(chance[id])
		-- only a caught hero has a portrait; an unknown one is just the "?"
		Viewports.hero(portrait, if known then id else nil)
	end, true)
end

function HeroIndex.init(context: Types.Ctx)
	ctx = context
	gui = Screens.get("HeroIndex")
	grid = Screens.scroller(gui, "HeroGrid")
	tiles = Screens.rows(grid, "HeroTileTemplate")
	bindTabs()
	Screens.button(gui, "ZoneRewardClaim").Activated:Connect(function()
		local state = ctx.state()
		local zone = Config.Zones[selected]
		if not state or not zone or state.zonesClaimed[zone.Id] then
			return
		end
		local have, total = Collection.zoneProgress(state.index, MAPS.zoneCharacters[zone.Id])
		if have == total then
			ctx.fire("ProgressAction", "claimZone", zone.Id)
		end
	end)
end

return HeroIndex
