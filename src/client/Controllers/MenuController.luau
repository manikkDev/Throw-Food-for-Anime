--!strict
-- MenuController - the menu buttons and one generic list panel that reaches
-- every server feature: foods, squad, index, store, rebirth, rewards, codes,
-- settings and (in Studio or for the owner) the test commands.
--
-- SECTION 2 TEST UI. Each "screen" is a function that turns the current state
-- into rows of text and buttons; section 3 replaces the rows with the designed
-- screens from design/ui.json and keeps the remotes each button fires.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Collection = require(ReplicatedStorage.Shared.Core.Collection)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Income = require(ReplicatedStorage.Shared.Core.Income)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local Progress = require(ReplicatedStorage.Shared.Core.Progress)
local Roll = require(ReplicatedStorage.Shared.Core.Roll)
local Squad = require(ReplicatedStorage.Shared.Core.Squad)
local Make = require(script.Parent.Parent.Ui.Make)

local MAPS = Lookup.of(Config)
local player = Players.LocalPlayer

type Button = { text: string, color: Color3, run: (() -> ())? }
type Row = {
	text: string,
	color: Color3?,
	buttons: { Button }?,
	input: { hint: string, submit: (string) -> () }?,
}
type Builder = (any) -> { Row }

local MenuController = Knit.CreateController({
	Name = "MenuController",
	_panel = nil :: Frame?,
	_list = nil :: ScrollingFrame?,
	_title = nil :: TextLabel?,
	_builder = nil :: Builder?,
	_remotes = {} :: { [string]: RemoteEvent },
	_stateAt = 0,
	_offlineShown = false,
	_buttons = {} :: { [string]: { button: TextButton, text: string } },
	_badgeAt = 0,
})

function MenuController:_fire(name: string, ...: any)
	local remote = self._remotes[name]
	if remote then
		remote:FireServer(...)
	end
end

local function rarityColor(rarity: string): Color3
	local row = Config.Rarities[rarity]
	return if row then Color3.fromHex(row.Color) else Color3.fromRGB(255, 79, 163)
end

-- ---------------------------------------------------------------- screens --

function MenuController:_foods(state: any): { Row }
	local rows: { Row } = {}
	for _, food in Config.Foods do
		local button: Button
		if state.food == food.Id then
			button = { text = "EQUIPPED", color = Make.PANEL }
		elseif state.foods[food.Id] then
			button = {
				text = "EQUIP",
				color = Make.GOOD,
				run = function()
					self:_fire("FoodEquip", food.Id)
				end,
			}
		else
			button = {
				text = Format.short(food.Cost) .. " yen",
				color = if state.yen >= food.Cost then Make.BUY else Make.BAD,
				run = function()
					self:_fire("ShopBuy", "food", food.Id)
				end,
			}
		end
		table.insert(rows, {
			text = `T{food.Tier} {food.Name} [{food.Flavor}]  power {Format.mult(food.PowerMult)}`
				.. `  luck {Format.mult(food.Luck)}`,
			buttons = { button },
		})
	end
	return rows
end

function MenuController:_squad(state: any): { Row }
	local best = Income.best(Config, MAPS, state.heroes)
	local function incomeOf(hero: any): number
		return Income.hero(Config, MAPS, hero, best)
	end
	local onPlot, onBench = Squad.counts(state.heroes)
	local rows: { Row } = {
		{
			text = `Plot {onPlot}/{state.slots}    Bench {onBench}/{state.benchSlots}`,
			buttons = {
				{
					text = "EQUIP BEST",
					color = Make.BUY,
					run = function()
						self:_fire("SquadAction", "equipBest")
					end,
				},
			},
		},
	}
	local order = {}
	for uid, hero in state.heroes do
		table.insert(order, { uid = uid, hero = hero, income = incomeOf(hero) })
	end
	table.sort(order, function(a, b)
		if a.income ~= b.income then
			return a.income > b.income
		end
		return a.uid < b.uid
	end)
	local plot = Config.Plot
	for _, item in order do
		local hero, uid = item.hero, item.uid
		local row = MAPS.character[hero.id] or MAPS.premium[hero.id]
		local tags = {}
		if hero.size then
			table.insert(tags, hero.size:upper())
		end
		if hero.mut then
			table.insert(tags, hero.mut:upper())
		end
		table.insert(tags, if row then row.Name else hero.id)
		if hero.stars > 0 then
			table.insert(tags, string.rep("*", hero.stars))
		end
		local buttons: { Button } = {}
		if hero.slot > 0 then
			table.insert(buttons, {
				text = "BENCH",
				color = Make.INFO,
				run = function()
					self:_fire("SquadAction", "bench", uid)
				end,
			})
		else
			table.insert(buttons, {
				text = "PLACE",
				color = Make.GOOD,
				run = function()
					local slot = Squad.freeSlot(state.heroes, state.slots)
					if not slot then
						local weakest = Squad.weakest(state.heroes, true, incomeOf)
						slot = if weakest then state.heroes[weakest].slot else 1
					end
					self:_fire("SquadAction", "place", uid, slot)
				end,
			})
		end
		if Squad.fusePartners(state.heroes, uid, plot.FuseCount, plot.MaxStars) then
			table.insert(buttons, {
				text = "FUSE",
				color = Make.BUY,
				run = function()
					self:_fire("SquadAction", "fuse", uid)
				end,
			})
		end
		table.insert(buttons, {
			text = "SELL",
			color = Make.BAD,
			run = function()
				self:_fire("SquadAction", "sell", uid)
			end,
		})
		table.insert(rows, {
			text = `{table.concat(tags, " ")}   {Format.short(item.income)}/s   `
				.. (if hero.slot > 0 then `slot {hero.slot}` else "bench"),
			color = if row and row.Rarity then rarityColor(row.Rarity) else rarityColor(""),
			buttons = buttons,
		})
	end
	return rows
end

function MenuController:_index(state: any): { Row }
	local hud = Knit.GetController("HudController")
	local luck = hud:CurrentLuck()
	local food = MAPS.food[state.food]
	local have, total = Collection.total(Config, state.index)
	local rows: { Row } = {
		{ text = `Unlocked {have}/{total}   (chances at your luck {Format.mult(luck)})` },
	}
	for _, zone in Config.Zones do
		local zoneCharacters = MAPS.zoneCharacters[zone.Id]
		local zHave, zTotal = Collection.zoneProgress(state.index, zoneCharacters)
		local button: Button? = nil
		if state.zonesClaimed[zone.Id] then
			button = { text = "CLAIMED", color = Make.PANEL }
		elseif zHave == zTotal then
			button = {
				text = "CLAIM",
				color = Make.GOOD,
				run = function()
					self:_fire("ProgressAction", "claimZone", zone.Id)
				end,
			}
		end
		table.insert(rows, {
			text = `== {zone.Name}  {zHave}/{zTotal}  (needs {Format.short(zone.PowerReq)} power) ==`,
			color = Make.BUY,
			buttons = if button then { button } else nil,
		})
		for _, weight in Roll.heroWeights(Config, zoneCharacters, luck, food.Flavor) do
			local character = MAPS.character[weight.id]
			local known = state.index[weight.id] ~= nil
			table.insert(rows, {
				text = `{if known then character.Name else "???"}  ({character.Rarity})`
					.. `  craves {character.Craves}  {Format.percent(weight.chance)}`,
				color = rarityColor(character.Rarity),
			})
		end
	end
	return rows
end

function MenuController:_prompt(item: any, isPass: boolean)
	local state = self._state.State
	if item.ProductId ~= 0 then
		if isPass then
			MarketplaceService:PromptGamePassPurchase(player, item.ProductId)
		else
			MarketplaceService:PromptProductPurchase(player, item.ProductId)
		end
	elseif state and state.studio then
		-- products are minted in section 5; in Studio the same grant runs directly
		self:_fire("AdminCommand", if isPass then "pass" else "product", item.Key)
	else
		Knit.GetController("HudController"):Toast("Not on sale yet", "info")
	end
end

function MenuController:_store(state: any): { Row }
	local rows: { Row } = { { text = "== PASSES ==", color = Make.BUY } }
	for _, pass in Config.Monetization.Passes do
		local owned = state.passes[pass.Key] == true
		table.insert(rows, {
			text = `{pass.Key}   {pass.Robux} R$`,
			buttons = {
				{
					text = if owned then "OWNED" else "BUY",
					color = if owned then Make.PANEL else Make.GOOD,
					run = if owned
						then nil
						else function()
							self:_prompt(pass, true)
						end,
				},
			},
		})
	end
	if not state.randomRestricted then
		table.insert(rows, { text = "== SUMMON SCROLL ODDS ==", color = Make.BUY })
		for _, hero in Config.PremiumCharacters do
			if hero.Source == "Summon" then
				table.insert(rows, {
					text = `{hero.Name}   {hero.OddsPercent}%   earns `
						.. `{Format.mult(hero.BestIncomeMult)} your best hero`,
				})
			end
		end
	end
	table.insert(rows, { text = "== ITEMS ==", color = Make.BUY })
	for _, product in Config.Monetization.Products do
		local hidden = product.Kind == "summon" and state.randomRestricted
		if not hidden and product.Kind ~= "gift" then
			table.insert(rows, {
				text = `{product.Key}   {product.Robux} R$`,
				buttons = {
					{
						text = "BUY",
						color = Make.GOOD,
						run = function()
							self:_prompt(product, false)
						end,
					},
				},
			})
		end
	end
	return rows
end

function MenuController:_rebirth(state: any): { Row }
	local nextTier = Progress.nextRebirth(Config, state.rebirth)
	local rows: { Row } = { { text = `You are at rebirth {state.rebirth}` } }
	if not nextTier then
		table.insert(rows, { text = "This is the highest rebirth" })
		return rows
	end
	table.insert(rows, {
		text = `Power  {Format.short(state.power)} / {Format.short(nextTier.PowerReq)}`,
		color = if state.power >= nextTier.PowerReq then Make.GOOD else Make.BAD,
	})
	table.insert(rows, {
		text = `Yen  {Format.short(state.yen)} / {Format.short(nextTier.YenCost)}`,
		color = if state.yen >= nextTier.YenCost then Make.GOOD else Make.BAD,
	})
	table.insert(rows, {
		text = `Reward: +{nextTier.IncomeBonus * 100}% income and `
			.. `+{nextTier.LuckBonus * 100}% luck, forever`,
	})
	table.insert(rows, { text = "Keeps: index, passes, premium heroes, lucky throws" })
	table.insert(rows, { text = "Resets: yen, power, foods, gear, slots, caught heroes" })
	table.insert(rows, {
		text = "",
		buttons = {
			{
				text = "REBIRTH",
				color = Make.BUY,
				run = function()
					self:_fire("ProgressAction", "rebirth")
				end,
			},
		},
	})
	return rows
end

function MenuController:_rewards(state: any): { Row }
	local now = state.unixNow + (os.clock() - self._stateAt)
	local today = Collection.dayOf(now)
	local daily = Collection.dailyState(state.daily, today)
	local reward = Collection.dailyReward(Config, daily.dayIndex)
	local rows: { Row } = {
		{
			text = `Daily day {daily.dayIndex}: {reward.yenMinutes} min of income`
				.. (if reward.luckyThrows > 0 then ` + {reward.luckyThrows} Lucky Throws` else ""),
			buttons = {
				{
					text = if daily.canClaim then "CLAIM" else "TOMORROW",
					color = if daily.canClaim then Make.GOOD else Make.PANEL,
					run = function()
						self:_fire("RewardClaim", "daily")
					end,
				},
			},
		},
	}
	local session = state.sessionSeconds + (os.clock() - self._stateAt)
	for i, minutes in Config.Rewards.PlaytimeMinutes do
		local claimed = state.gifts.day == today and state.gifts.claimed[tostring(i)]
		local ready = Collection.giftClaimable(Config, state.gifts, today, session, i)
		table.insert(rows, {
			text = `Gift {i}  ({minutes} min played)`,
			buttons = {
				{
					text = if claimed
						then "CLAIMED"
						elseif ready then "CLAIM"
						else Format.duration(minutes * 60 - session),
					color = if ready then Make.GOOD else Make.PANEL,
					run = function()
						self:_fire("RewardClaim", "gift", i)
					end,
				},
			},
		})
	end
	if state.offline then
		table.insert(rows, {
			text = `Away {Format.duration(state.offline.seconds)}: `
				.. `+{Format.short(state.offline.amount)} yen`,
			buttons = {
				{
					text = "CLAIM",
					color = Make.GOOD,
					run = function()
						self:_fire("RewardClaim", "offline")
					end,
				},
				{
					text = "2X",
					color = Make.BUY,
					run = function()
						self:_prompt(MAPS.product.OfflineDouble, false)
					end,
				},
			},
		})
	end
	table.insert(rows, {
		text = "Code:",
		input = {
			hint = "type a code",
			submit = function(text: string)
				self:_fire("RewardClaim", "code", text)
			end,
		},
	})
	return rows
end

function MenuController:_settings(state: any): { Row }
	local rows: { Row } = {}
	local toggles = {
		{ "fastReveal", "Fast reveal" },
		{ "lowDetail", "Low detail" },
		{ "hideOthers", "Hide other plots" },
		{ "autoSellCommon", "Auto-sell plain Commons when full" },
		{ "autoSellUncommon", "Auto-sell plain Uncommons when full" },
	}
	for _, toggle in toggles do
		local on = state.settings[toggle[1]] == true
		table.insert(rows, {
			text = toggle[2],
			buttons = {
				{
					text = if on then "ON" else "OFF",
					color = if on then Make.GOOD else Make.PANEL,
					run = function()
						self:_fire("SettingSet", toggle[1], not on)
					end,
				},
			},
		})
	end
	return rows
end

function MenuController:_admin(state: any): { Row }
	local rows: { Row } = {}
	local function add(text: string, command: string, arg: any)
		table.insert(rows, {
			text = text,
			buttons = {
				{
					text = "RUN",
					color = Make.INFO,
					run = function()
						self:_fire("AdminCommand", command, arg)
					end,
				},
			},
		})
	end
	if state.admin then
		add("OWNER: start a 5 minute Festival Hour", "festival", 5)
		add("OWNER: raise server luck one step", "luck", nil)
		add("OWNER: give everyone 3 Lucky Throws", "throws", 3)
	end
	if state.studio then
		add("DEV: +10K yen", "yen", 1e4)
		add("DEV: +10M yen", "yen", 1e7)
		add("DEV: +1T yen", "yen", 1e12)
		add("DEV: +500 power", "power", 500)
		add("DEV: +100K power", "power", 1e5)
		add("DEV: +200M power", "power", 2e8)
		add("DEV: grant a Titan Galaxy Mythic", "hero", {
			id = "sun_god_captain",
			mut = "Galaxy",
			size = "Titan",
		})
		add("DEV: pretend 3 hours away (rejoin to see it)", "away", 10800)
		add("DEV: wipe my profile", "wipe", nil)
	end
	return rows
end

-- ----------------------------------------------------------------- badges --

-- A "!" on a menu button when there is something worth opening it for: a food
-- you can afford, a reward ready to claim, a rebirth you qualify for. This is
-- the nudge back to the shop; it is a badge and never a popup, so it cannot
-- interrupt a throw.
function MenuController:_badges()
	local state = self._state.State
	if not state then
		return
	end
	local flags: { [string]: boolean } = {}
	for _, food in Config.Foods do
		if not state.foods[food.Id] then
			flags.BtnShop = state.yen >= food.Cost
			break
		end
	end
	flags.BtnRebirth = Progress.canRebirth(Config, state.rebirth, state.power, state.yen)
	local now = state.unixNow + (os.clock() - self._stateAt)
	local today = Collection.dayOf(now)
	local session = state.sessionSeconds + (os.clock() - self._stateAt)
	local ready = Collection.dailyState(state.daily, today).canClaim or state.offline ~= nil
	for i in Config.Rewards.PlaytimeMinutes do
		if Collection.giftClaimable(Config, state.gifts, today, session, i) then
			ready = true
		end
	end
	flags.BtnGift = ready
	for _, zone in Config.Zones do
		local have, total = Collection.zoneProgress(state.index, MAPS.zoneCharacters[zone.Id])
		if have == total and not state.zonesClaimed[zone.Id] then
			flags.BtnIndex = true
		end
	end
	for name, entry in self._buttons do
		entry.button.Text = if flags[name] then entry.text .. " !" else entry.text
	end
end

-- ------------------------------------------------------------------ panel --

function MenuController:_render()
	local list, builder, state = self._list, self._builder, self._state.State
	if not list or not builder or not state then
		return
	end
	-- a snapshot arrives after every throw: rebuilding now would wipe a
	-- half-typed code. The next snapshot after the box loses focus rebuilds it.
	local typing = UserInputService:GetFocusedTextBox()
	if typing and typing:IsDescendantOf(list) then
		return
	end
	local scroll = list.CanvasPosition
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for i, row in builder(state) do
		local frame = Make.frame(list, {
			Name = "Row" .. i,
			Size = UDim2.new(1, -8, 0, 40),
			BackgroundTransparency = if i % 2 == 0 then 0.6 else 0.8,
			BackgroundColor3 = Make.INK,
			LayoutOrder = i,
		})
		local buttons = row.buttons or {}
		local right = #buttons * 104 + (if row.input then 220 else 0)
		Make.label(frame, row.text, {
			Name = "Text",
			Size = UDim2.new(1, -right - 10, 1, -8),
			Position = UDim2.fromOffset(6, 4),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = row.color or Color3.new(1, 1, 1),
		})
		for b, spec in buttons do
			local button = Make.button(frame, spec.text, spec.color, {
				Name = "Button" .. b,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -(#buttons - b) * 104 - 4, 0.5, 0),
				Size = UDim2.fromOffset(98, 32),
			})
			if spec.run then
				button.Activated:Connect(spec.run)
			else
				button.AutoButtonColor = false
			end
		end
		if row.input then
			local box = Instance.new("TextBox")
			box.Name = "Input"
			box.AnchorPoint = Vector2.new(1, 0.5)
			box.Position = UDim2.new(1, -4, 0.5, 0)
			box.Size = UDim2.fromOffset(210, 32)
			box.Font = Enum.Font.FredokaOne
			box.TextScaled = true
			box.PlaceholderText = row.input.hint
			box.Text = ""
			box.ClearTextOnFocus = false
			box.Parent = frame
			local submit = row.input.submit
			box.FocusLost:Connect(function(enter: boolean)
				if enter and box.Text ~= "" then
					submit(box.Text)
					box.Text = ""
				end
			end)
		end
	end
	list.CanvasPosition = scroll
end

--- Open the panel on a screen. `builder(state)` returns its rows.
function MenuController:Open(title: string, builder: Builder)
	if not self._panel or not self._title then
		return
	end
	self._builder = builder
	self._title.Text = title
	self._panel.Visible = true
	self:_render()
end

function MenuController:Close()
	self._builder = nil
	if self._panel then
		self._panel.Visible = false
	end
end

function MenuController:_build()
	local gui = Make.screen("DevMenu", 30)

	local buttons = Make.frame(gui, {
		Name = "Buttons",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 40),
		Size = UDim2.fromOffset(112, 380),
		BackgroundTransparency = 1,
	})
	Make.list(buttons, Enum.FillDirection.Vertical, 6)
	local entries: { { any } } = {
		{ "BtnShop", "FOODS", Make.BUY, "Food Shop", self._foods },
		{ "BtnSquad", "SQUAD", Make.INFO, "My Squad", self._squad },
		{ "BtnIndex", "INDEX", Make.INFO, "Hero Index", self._index },
		{ "BtnStore", "STORE", Color3.fromRGB(255, 79, 163), "Store", self._store },
		{ "BtnRebirth", "REBIRTH", Make.BUY, "Rebirth", self._rebirth },
		{ "BtnGift", "REWARDS", Make.GOOD, "Rewards and Codes", self._rewards },
		{ "BtnSettings", "SETTINGS", Make.PANEL, "Settings", self._settings },
		{ "BtnAdmin", "TEST", Make.BAD, "Test commands", self._admin },
	}
	for i, entry in entries do
		local button = Make.button(buttons, entry[2], entry[3], {
			Name = entry[1],
			Size = UDim2.new(1, 0, 0, 40),
			LayoutOrder = i,
		})
		local title, method = entry[4], entry[5]
		button.Activated:Connect(function()
			if
				self._panel
				and self._panel.Visible
				and self._title
				and self._title.Text == title
			then
				self:Close()
			else
				self:Open(title, function(state: any): { Row }
					return method(self, state)
				end)
			end
		end)
		self._buttons[entry[1]] = { button = button, text = entry[2] }
		if entry[1] == "BtnAdmin" then
			self._adminButton = button
			button.Visible = false
		end
	end

	local panel = Make.frame(gui, {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(680, 440),
		BackgroundTransparency = 0.05,
		Visible = false,
	})
	Make.corner(panel, 16)
	Make.stroke(panel, 4, Color3.new(1, 1, 1))
	self._title = Make.label(panel, "", {
		Name = "Title",
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -90, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Make.BUY,
	})
	local close = Make.button(panel, "X", Make.BAD, {
		Name = "CloseButton",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(48, 40),
	})
	close.Activated:Connect(function()
		self:Close()
	end)
	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Position = UDim2.fromOffset(10, 56)
	list.Size = UDim2.new(1, -20, 1, -66)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 8
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	Make.list(list, Enum.FillDirection.Vertical, 4)
	self._list = list
	self._panel = panel

	gui.Parent = player:WaitForChild("PlayerGui")
end

function MenuController:KnitStart()
	self._state = Knit.GetController("StateController")
	local names: { Net.EventName } = {
		"ShopBuy",
		"FoodEquip",
		"SquadAction",
		"ProgressAction",
		"RewardClaim",
		"SettingSet",
		"AdminCommand",
	}
	for _, name in names do
		local remote = Net.client(name)
		if remote then
			self._remotes[name] = remote
		end
	end
	self:_build()

	self._state:Observe(function(state: any)
		self._stateAt = os.clock()
		if self._adminButton then
			self._adminButton.Visible = state.studio == true or state.admin == true
		end
		if state.offline and not self._offlineShown then
			-- welcome back: open the rewards screen on the offline row once
			self._offlineShown = true
			self:Open("Welcome back!", function(s: any): { Row }
				return self:_rewards(s)
			end)
		end
		self:_render()
		self:_badges()
	end)
	self._state.Ticked:Connect(function()
		-- Yen moves every second; re-check what it can now buy, once a second
		if os.clock() - self._badgeAt >= 1 then
			self._badgeAt = os.clock()
			self:_badges()
		end
	end)
end

return MenuController
