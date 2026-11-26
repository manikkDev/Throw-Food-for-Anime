--!strict
-- HeroIndex - the collection: zone tabs with progress, a tile per hero with
-- its craving and the chance at the player's luck and food right now, and the
-- zone reward.
--
-- A hero not caught yet is an UNKNOWN tile: dark, named "???", showing the
-- hero's OWN pitch-black silhouette (its real model, ImageColor3 black) with a
-- "?" in its rarity colour on it; its rarity chip always shows. Every tile's
-- frame and flare follow its rarity (UiFx.styleCard).
-- Each zone tab is a picture card: the zone's painted landscape (ZoneBg_<id>)
-- behind its name and progress bar; the selected one wears a gold frame. A
-- zone the player cannot throw into yet carries a lock. The tabs live in a
-- scroller: the tree ships six, and a zone beyond that gets a copy of the last.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Collection = require(ReplicatedStorage.Shared.Core.Collection)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local Roll = require(ReplicatedStorage.Shared.Core.Roll)
local Throw = require(ReplicatedStorage.Shared.Core.Throw)
local FoodLook = require(script.Parent.Parent.FoodLook)
local Screens = require(script.Parent.Parent.Screens)
local Theme = require(script.Parent.Parent.Theme)
local UiFx = require(script.Parent.Parent.UiFx)
local Viewports = require(script.Parent.Parent.Viewports)
local Types = require(script.Parent.Types)

local MAPS = Lookup.of(Config)
local TAB_GOLD = Color3.fromHex("FFC93C")

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

	for index, tab in tabs do
		local zone = Config.Zones[index]
		tabCells[index].Visible = zone ~= nil
		if zone then
			local have, total = Collection.zoneProgress(state.index, MAPS.zoneCharacters[zone.Id])
			Screens.setButtonState(tab, if index == selected then "neutral" else "panel")
			-- the picture card: its zone's landscape, a gold frame and a lighter
			-- wash when selected
			local picked = index == selected
			local bg = Screens.image(tab, "ZoneBg")
			local key = "ZoneBg_" .. zone.Id
			if bg:GetAttribute("IconKey") ~= key then
				bg:SetAttribute("IconKey", key)
				bg.Image = Screens.icon(key)
			end
			bg.ImageColor3 = if picked then Color3.new(1, 1, 1) else Color3.fromRGB(205, 205, 225)
			Screens.frame(tab, "NameWash").BackgroundTransparency = if picked then 0.82 else 0.62
			local stroke = tab:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = if picked then TAB_GOLD else Color3.new(1, 1, 1)
				stroke.Thickness = if picked then 4 else 3
			end
			Screens.label(tab, "ZoneName").Text = zone.Name
			Screens.label(tab, "ZoneProgress").Text = `{have}/{total}`
			Screens.fill(Screens.frame(tab, "Fill"), if total > 0 then have / total else 0)
			-- locked: the throw cannot reach it (not enough Power, or its gate is sealed)
			Screens.image(tab, "LockIcon").Visible = index
				> Throw.reach(Config.Zones, state.power, state.rebirth or 0)
		end
	end

	local zone = Config.Zones[selected] or Config.Zones[1]
	local zoneCharacters = MAPS.zoneCharacters[zone.Id]
	local have, total = Collection.zoneProgress(state.index, zoneCharacters)
	local allHave, allTotal = Collection.total(Config, state.index)
	Screens.label(gui, "ZoneTitle").Text = if (zone.RebirthReq or 0) > (state.rebirth or 0)
		then `{zone.Name}  (REBIRTH {zone.RebirthReq})`
		else zone.Name
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
	-- the odds are for the food a throw into THIS zone would use, at its luck there
	local thrown = FoodLook.current(state, selected)
	local here = FoodLook.luck(state, selected)
	local now = FoodLook.luck(state)
	local zoneLuck = math.clamp(luck * here / math.max(now, 1e-6), 1, Config.Luck.Max)
	for _, weight in
		Roll.heroWeights(Config, zoneCharacters, zoneLuck, if thrown then thrown.Id else nil)
	do
		table.insert(keys, weight.id)
		chance[weight.id] = weight.chance
	end
	Screens.syncRows(tiles, keys, function(tile: GuiObject, id: string, _, isNew: boolean)
		local character = MAPS.character[id]
		local known = state.index[id] ~= nil
		local rarity = Theme.rarity(character.Rarity)
		local portrait = Screens.viewport(tile, "Portrait")
		local mark = Screens.label(tile, "UnknownMark")
		if isNew then
			Screens.setIcon(Screens.image(tile, "CraveIcon"), FoodLook.iconKey(character.Favourite))
			mark.TextColor3 = rarity
			-- the rarity is always shown, caught or not
			Screens.label(tile, "RarityText").Text = character.Rarity:upper()
			Screens.tint(Screens.frame(tile, "RarityTag"), rarity)
			UiFx.styleCard(tile, character.Rarity)
		end
		if tile:GetAttribute("Known") ~= known then
			tile:SetAttribute("Known", known)
			-- the whole card face is the rarity colour (v4: no separate stripe)
			Screens.tint(tile, if known then rarity else Theme.UNKNOWN_TILE)
			mark.Visible = not known
			Screens.label(tile, "HeroName").Text = if known then character.Name else "???"
			-- v4.3: the portrait sits on its rarity's texture once the hero is caught
			UiFx.stylePortrait(
				Screens.frame(tile, "PortraitWell"),
				if known then character.Rarity else nil
			)
		end
		Screens.label(tile, "ChanceText").Text = Format.percent(chance[id])
		-- a caught hero in colour; an unknown one as its own black silhouette
		Viewports.hero(portrait, id, not known)
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
