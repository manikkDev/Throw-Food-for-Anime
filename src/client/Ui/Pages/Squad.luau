--!strict
-- Squad - every hero the player owns, on the plot or on the bench: place,
-- bench, fuse, sell, Equip Best and the auto-sell toggles. One row per hero
-- uid, created once and updated in place.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Income = require(ReplicatedStorage.Shared.Core.Income)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local SquadRules = require(ReplicatedStorage.Shared.Core.Squad)
local Screens = require(script.Parent.Parent.Screens)
local Theme = require(script.Parent.Parent.Theme)
local UiFx = require(script.Parent.Parent.UiFx)
local Viewports = require(script.Parent.Parent.Viewports)
local Types = require(script.Parent.Types)

local MAPS = Lookup.of(Config)

local Squad = { name = "Squad" } :: Types.Page

local ctx: Types.Ctx
local gui: ScreenGui
local list: ScrollingFrame
local rows: Screens.RowSet
local showBench = false
-- what each row showed last: a rise in stars is a fuse that landed
local seenStars: { [string]: number } = {}
local seenEarn: { [string]: number } = {}

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

-- --------------------------------------------------------- the fuse moment --
-- A fuse that lands (the hero's stars went up in a snapshot) plays on its row,
-- about 1.5 s, never blocking: the card charges (a glow builds, a small
-- shake), bursts (flash, turning rays, the new star flies in and slams onto
-- the badge), sparkles, and a "+income" pops over the income line. The flying
-- pieces live on the ScreenGui itself in screen pixels, so they can leave the
-- row and its scroller.

local CHARGE = 0.55
local GOLD = Color3.fromHex("FFD45C")

local function overlay(className: string, at: Vector2, size: Vector2): GuiObject
	local made = Instance.new(className) :: GuiObject
	made.BackgroundTransparency = 1
	made.AnchorPoint = Vector2.new(0.5, 0.5)
	made.Position = UDim2.fromOffset(at.X, at.Y)
	made.Size = UDim2.fromOffset(size.X, size.Y)
	made.ZIndex = 50
	made.Parent = gui
	return made
end

local function centreOf(object: GuiObject): Vector2
	return object.AbsolutePosition + object.AbsoluteSize / 2
end

local function tween(
	object: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
)
	local t = TweenService:Create(
		object,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end

local function playFuse(row: GuiObject, stars: number, gained: number)
	local face = Screens.frame(row, "Face")
	local badge = Screens.frame(row, "FuseBadge")
	local star = Screens.image(badge, "Star")
	local income = Screens.label(row, "IncomeText")
	local burstImage = Screens.icon("FxSunburst")
	local starImage = Screens.icon("IconStar")
	Screens.sound("fuse_charge")

	-- charge: a gold glow fills the card and it trembles
	local glow = Instance.new("Frame")
	glow.Name = "FuseGlow"
	glow.BackgroundColor3 = GOLD
	glow.BackgroundTransparency = 1
	glow.BorderSizePixel = 0
	glow.Size = UDim2.fromScale(1, 1)
	glow.ZIndex = 30
	local corner = face:FindFirstChildOfClass("UICorner")
	if corner then
		corner:Clone().Parent = glow
	end
	glow.Parent = face
	tween(
		glow,
		CHARGE,
		{ BackgroundTransparency = 0.55 },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)
	local home = face.Position
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < CHARGE do
			local k = (os.clock() - t0) / CHARGE
			face.Position = home + UDim2.fromOffset(math.random(-2, 2) * k, math.random(-1, 1) * k)
			task.wait(0.03)
		end
		face.Position = home
	end)

	task.delay(CHARGE, function()
		if not row.Parent then
			glow:Destroy()
			return
		end
		Screens.sound("fuse_burst")
		-- flash, then fade
		glow.BackgroundColor3 = Color3.new(1, 1, 1)
		glow.BackgroundTransparency = 0.15
		tween(glow, 0.45, { BackgroundTransparency = 1 }).Completed:Once(function()
			glow:Destroy()
		end)
		Screens.pop(face, 1.04)
		-- rays turning out of the portrait
		local at = centreOf(badge)
		local rays = overlay(
			"ImageLabel",
			centreOf(Screens.frame(row, "PortraitTile")),
			Vector2.new(40, 40)
		) :: ImageLabel
		rays.Image = burstImage
		rays.ImageColor3 = GOLD
		tween(
			rays,
			0.7,
			{ Size = UDim2.fromOffset(260, 260), Rotation = 120, ImageTransparency = 1 }
		)
		Debris:AddItem(rays, 0.8)
		-- the new star flies in from the card's middle and slams onto the badge
		badge.Visible = true
		star.ImageTransparency = 1
		local side = math.max(star.AbsoluteSize.X, 28)
		local flyer =
			overlay("ImageLabel", centreOf(face), Vector2.new(side * 2.4, side * 2.4)) :: ImageLabel
		flyer.Image = starImage
		flyer.Rotation = -140
		tween(flyer, 0.32, {
			Position = UDim2.fromOffset(at.X, at.Y),
			Size = UDim2.fromOffset(side, side),
			Rotation = 0,
		}, Enum.EasingStyle.Back, Enum.EasingDirection.In).Completed:Once(function()
			flyer:Destroy()
			star.ImageTransparency = 0
			Screens.pop(badge, 1.7)
			-- sparkle: little stars burst out of the badge
			for i = 1, 7 do
				local a = (i / 7) * math.pi * 2 + math.random() * 0.4
				local bit = overlay("ImageLabel", at, Vector2.new(16, 16)) :: ImageLabel
				bit.Image = starImage
				local to = at + Vector2.new(math.cos(a), math.sin(a)) * math.random(40, 70)
				tween(bit, 0.55, {
					Position = UDim2.fromOffset(to.X, to.Y),
					Size = UDim2.fromOffset(6, 6),
					ImageTransparency = 1,
					Rotation = math.random(-180, 180),
				})
				Debris:AddItem(bit, 0.6)
			end
		end)
		-- "+income" rises from the income line
		if gained > 0 then
			local from = centreOf(income)
			local pop = overlay("TextLabel", from, Vector2.new(220, 34)) :: TextLabel
			pop.Text = `+{Format.short(gained)}/s`
			pop.FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
			pop.TextSize = 28
			pop.TextColor3 = Color3.fromHex("DDF25A")
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 2
			stroke.Color = Color3.fromHex("0D0F2B")
			stroke.Parent = pop
			local scale = Instance.new("UIScale")
			scale.Scale = 0.4
			scale.Parent = pop
			tween(scale, 0.3, { Scale = 1.15 }, Enum.EasingStyle.Back)
			tween(pop, 1, { Position = UDim2.fromOffset(from.X, from.Y - 46) })
			task.delay(0.55, function()
				tween(pop, 0.45, { TextTransparency = 1 })
				tween(stroke, 0.45, { Transparency = 1 })
			end)
			Debris:AddItem(pop, 1.1)
		end
		local _ = stars
	end)
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
			-- the portrait sits on a tile of its rarity colour (v4: replaces the thin rarity stripe)
			Screens.tint(Screens.frame(row, "PortraitTile"), Theme.rarity(rarity))
			-- v4.1: the card's frame and flares by rarity (gradient from Rare, turning from Epic)
			UiFx.styleCard(row, rarity)
			-- v4.3: the portrait tile carries the rarity's texture, shimmering
			UiFx.stylePortrait(Screens.frame(row, "PortraitTile"), rarity)
		end
		-- a fuse that landed: stars went up since this row last showed
		local before = seenStars[uid]
		if not isNew and before and hero.stars > before then
			playFuse(row, hero.stars, earns[uid] - (seenEarn[uid] or earns[uid]))
		end
		seenStars[uid] = hero.stars
		seenEarn[uid] = earns[uid]
		local benched = hero.slot <= 0
		row.Visible = benched == showBench
		if row.Visible then
			-- the 3D thumb is only built for rows the player can see
			Viewports.hero(Screens.viewport(row, "Thumb"), hero.id)
		end
		-- fused: one big gold star on the portrait corner, the fuse count on it from 2 up
		Screens.frame(row, "FuseBadge").Visible = hero.stars > 0
		local count = Screens.label(row, "FuseCount")
		count.Text = if hero.stars > 1 then tostring(hero.stars) else ""
		count.Visible = hero.stars > 1
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
