--!strict
-- MenuController - the pages: food shop, squad, index, store, summon odds,
-- offline earnings, rebirth, daily rewards, playtime gifts, codes, settings,
-- and the training overlay.
--
-- This file is the thin part. Each screen is a module in Ui/Pages that turns
-- state into what its screen shows; this controller owns what they share:
-- the remotes, purchase prompts, which page is open, the once-a-second tick,
-- and the "!" badges on the HUD buttons.
--
-- Nothing opens by itself over a throw. The one exception is the welcome-back
-- page, once, when the player joins with offline earnings waiting.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Collection = require(ReplicatedStorage.Shared.Core.Collection)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local Progress = require(ReplicatedStorage.Shared.Core.Progress)
local Throw = require(ReplicatedStorage.Shared.Core.Throw)

local Ui = script.Parent.Parent.Ui
local DevPanel = require(Ui.DevPanel)
local FoodLook = require(Ui.FoodLook)
local Screens = require(Ui.Screens)
local Celebrate = require(script.Parent.Parent.Ui.Celebrate)
local Types = require(Ui.Pages.Types)

local MAPS = Lookup.of(Config)
local player = Players.LocalPlayer

local PAGES: { Types.Page } = {
	require(Ui.Pages.FoodShop),
	require(Ui.Pages.Squad),
	require(Ui.Pages.HeroIndex),
	require(Ui.Pages.Store),
	require(Ui.Pages.SummonOdds),
	require(Ui.Pages.ThrowOdds),
	require(Ui.Pages.OfflineEarnings),
	require(Ui.Pages.Rebirth),
	require(Ui.Pages.DailyRewards),
	require(Ui.Pages.PlaytimeGifts),
	require(Ui.Pages.Codes),
	require(Ui.Pages.Settings),
	require(Ui.Pages.TrainingBar),
}

-- number keys open the main pages (design/plan/05-ui-ux.md, input table)
local HOTKEYS: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.One] = "FoodShop",
	[Enum.KeyCode.Two] = "Squad",
	[Enum.KeyCode.Three] = "HeroIndex",
	[Enum.KeyCode.Four] = "Store",
	[Enum.KeyCode.Five] = "PlaytimeGifts",
	[Enum.KeyCode.Six] = "DailyRewards",
}

-- HUD buttons that can carry a "!" badge
local BADGED = { "BtnShop", "BtnRebirth", "BtnGift", "BtnDaily", "BtnIndex" }

-- ProximityPrompt `Action` attribute on a hub station -> the screen it opens
local STATIONS: { [string]: string } = {
	food = "FoodShop",
	daily = "DailyRewards",
	gift = "PlaytimeGifts",
	index = "HeroIndex",
	summon = "Store",
	squad = "Squad",
}

local MenuController = Knit.CreateController({
	Name = "MenuController",
	_remotes = {} :: { [string]: RemoteEvent },
	_pages = {} :: { [string]: Types.Page },
	_stateAt = 0,
	_offlineShown = false,
	_badges = {} :: { [string]: GuiObject },
	_giftTimer = nil :: TextLabel?,
	_giftTimerCell = nil :: GuiObject?,
	_giftCaption = nil :: GuiObject?,
})

function MenuController:_fire(name: string, ...: any)
	local remote = self._remotes[name]
	if remote then
		remote:FireServer(...)
	end
end

--- Start a Robux purchase for a pass or product row from Config.
function MenuController:Prompt(item: any, isPass: boolean)
	local state = self._state.State
	if not item then
		return
	end
	if item.ProductId ~= 0 then
		-- the purchase celebration waits for Roblox's dialog to close (Ui/Celebrate)
		Celebrate.promptOpened()
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

--- Open a page by its screen name ("FoodShop", "Squad", ...).
function MenuController:Open(name: string)
	Screens.open(name)
end

function MenuController:Close()
	Screens.close()
end

-- unix time and session seconds, advanced from the last snapshot
function MenuController:_now(): number
	local state = self._state.State
	return (if state then state.unixNow else os.time()) + (os.clock() - self._stateAt)
end

function MenuController:_session(): number
	local state = self._state.State
	return (if state then state.sessionSeconds else 0) + (os.clock() - self._stateAt)
end

-- The Gifts button leads to offline earnings while they wait, otherwise the playtime gifts.
-- The daily reward has its own DAILY button (owner's review of section 5: it had vanished
-- behind the Gifts button once claimed).
function MenuController:_route(name: string, from: string?): string
	local state = self._state.State
	if name ~= "PlaytimeGifts" or from ~= nil or not state then
		return name
	end
	if state.offline then
		return "OfflineEarnings"
	end
	return name
end

-- ----------------------------------------------------------------- badges --

-- A "!" on a HUD button when there is something worth opening it for: a food
-- you can afford, a reward ready to claim, a rebirth you qualify for. This is
-- the nudge back to the shop; it is a badge and never a popup, so it cannot
-- interrupt a throw.
function MenuController:_refreshBadges()
	local state = self._state.State
	if not state then
		return
	end
	local flags: { [string]: boolean } = {}
	-- The same two facts also raise a notice card, once each: a compact card
	-- at the top with one button to the right page. Not while a page is open.
	local hud = self._hud
	local quiet = Screens.isOpen()
	for _, food in Config.Foods do
		local notice = "food:" .. food.Id
		if not state.foods[food.Id] then
			flags.BtnShop = state.yen >= food.Cost
			if flags.BtnShop and not quiet then
				hud:Notice(notice, {
					icon = FoodLook.iconKey(food.Id),
					title = "NEW FOOD!",
					body = `You can buy {food.Name}`,
					button = "SHOP",
					buttonIcon = "IconShop",
					page = "FoodShop",
				})
			end
			break
		end
		hud:ClearNotice(notice)
	end
	flags.BtnRebirth = Progress.canRebirth(Config, state.rebirth, state.power, state.yen)
	local nextTier = Progress.nextRebirth(Config, state.rebirth)
	if flags.BtnRebirth and not quiet then
		hud:Notice("rebirth:" .. state.rebirth, {
			icon = "IconRebirth",
			title = "REBIRTH READY!",
			body = if nextTier and #nextTier.Unseals > 0
				then `Opens {Config.Zones[nextTier.Unseals[1]].Name}`
				else "A bonus that lasts forever",
			button = "GO",
			buttonIcon = "IconRebirth",
			page = "Rebirth",
		})
	elseif nextTier and not quiet and Throw.atSeal(Config.Zones, state.power, state.rebirth) then
		-- the throw reaches the sealed gate but the fee is short
		hud:Notice("seal:" .. state.rebirth, {
			icon = "IconRebirth",
			title = "SEALED GATE!",
			body = `Rebirth opens it: save {Format.short(nextTier.YenCost)} yen`,
			button = "SEE",
			buttonIcon = "IconRebirth",
			page = "Rebirth",
		})
	end
	local today = Collection.dayOf(self:_now())
	local session = self:_session()
	flags.BtnDaily = Collection.dailyState(state.daily, today).canClaim
	local ready = state.offline ~= nil
	local nextGift: number? = nil
	for i, minutes in Config.Rewards.PlaytimeMinutes do
		if Collection.giftClaimable(Config, state.gifts, today, session, i) then
			ready = true
		elseif not (state.gifts.day == today and state.gifts.claimed[tostring(i)]) then
			local left = minutes * 60 - session
			nextGift = if nextGift then math.min(nextGift, left) else left
		end
	end
	flags.BtnGift = ready
	for _, zone in Config.Zones do
		local have, total = Collection.zoneProgress(state.index, MAPS.zoneCharacters[zone.Id])
		if have == total and not state.zonesClaimed[zone.Id] then
			flags.BtnIndex = true
		end
	end
	for name, badge in self._badges do
		badge.Visible = flags[name] == true
	end
	-- the timer chip on the Gifts button: READY!, or the wait for the next gift
	local timer, cell = self._giftTimer, self._giftTimerCell
	if timer and cell then
		local showing = ready or nextGift ~= nil
		cell.Visible = showing
		timer.Text = if ready then "READY!" elseif nextGift then Screens.clock(nextGift) else ""
		-- the chip takes the place of the button's caption while it shows
		local caption = self._giftCaption
		if caption then
			caption.Visible = not showing
		end
	end
end

-- ------------------------------------------------------------------ pages --

function MenuController:_call(page: Types.Page, method: string, ...: any)
	local handler = (page :: any)[method]
	if not handler then
		return
	end
	local ok, err = pcall(handler, ...)
	if not ok then
		warn(`[MenuController] {page.name}.{method} failed inert: {err}`)
	end
end

-- Show `state` on whatever the player can see: the open page and the overlays.
function MenuController:_render(method: string)
	local state = self._state.State
	if not state then
		return
	end
	local open = Screens.current()
	for _, page in PAGES do
		if page.overlay or page.name == open then
			self:_call(page, method, state)
		end
	end
end

function MenuController:KnitStart()
	self._state = Knit.GetController("StateController")
	Screens.init()

	local names: { Net.EventName } = {
		"ShopBuy",
		"FoodEquip",
		"SquadAction",
		"ProgressAction",
		"RewardClaim",
		"SettingSet",
		"TrainSet",
		"StoreGiftTarget",
		"AdminCommand",
	}
	for _, name in names do
		local remote = Net.client(name)
		if remote then
			self._remotes[name] = remote
		end
	end

	local hud = Knit.GetController("HudController")
	self._hud = hud
	local ctx: Types.Ctx = {
		state = function(): any
			return self._state.State
		end,
		fire = function(name: string, ...: any)
			self:_fire(name, ...)
		end,
		prompt = function(item: any, isPass: boolean)
			self:Prompt(item, isPass)
		end,
		luck = function(): number
			return (hud:CurrentLuck())
		end,
		now = function(): number
			return self:_now()
		end,
		session = function(): number
			return self:_session()
		end,
		toast = function(text: string, kind: string?)
			hud:Toast(text, kind)
		end,
		banner = function(text: string)
			hud:Banner(text)
		end,
		levelUp = function(title: string, sub: string, color: Color3?)
			hud:LevelUp(title, sub, color)
		end,
		reward = function(info: any)
			hud:Reward(info)
		end,
		ticked = function(handler: (yen: number, power: number) -> ())
			self._state.Ticked:Connect(handler)
		end,
	}
	for _, page in PAGES do
		self._pages[page.name] = page
		self:_call(page, "init", ctx)
	end

	local hudGui = Screens.get("HUD")
	for _, name in BADGED do
		self._badges[name] = Screens.frame(Screens.button(hudGui, name), "BadgeCell")
	end
	-- UI v3.2: the caption band and the timer chip are both INSIDE the Gifts
	-- button, in the same rectangle: the chip takes the caption's place while
	-- a timer or READY shows. All three are found by name under the button.
	local giftButton = Screens.button(hudGui, "BtnGift")
	self._giftTimer = Screens.label(giftButton, "GiftTimer")
	self._giftTimerCell = Screens.frame(giftButton, "GiftTimerBadgeCell")
	local caption = giftButton:FindFirstChild("Caption", true)
	if caption and caption:IsA("GuiObject") then
		self._giftCaption = caption
	end
	self._giftTimer.Text = ""
	self._giftTimerCell.Visible = false

	Screens.setRouter(function(name: string, from: string?): string
		return self:_route(name, from)
	end)
	Screens.Opened:Connect(function(name: string)
		local page = self._pages[name]
		if page then
			self:_call(page, "opened")
			if self._state.State then
				self:_call(page, "render", self._state.State)
			end
		end
	end)
	Screens.Closed:Connect(function(name: string)
		local page = self._pages[name]
		if page then
			self:_call(page, "closed")
		end
	end)

	self._state:Observe(function(state: any)
		self._stateAt = os.clock()
		DevPanel.update(state, function(command: string, arg: any)
			self:_fire("AdminCommand", command, arg)
		end, {
			fire = function(remote: string, ...: any)
				self:_fire(remote, ...)
			end,
			hud = hud,
		})
		if state.offline and not self._offlineShown then
			-- welcome back: the offline earnings page, once per session
			self._offlineShown = true
			Screens.open("OfflineEarnings")
		end
		self:_render("render")
		self:_refreshBadges()
	end)

	-- Yen, power and the clocks move every second: once a second, re-check
	-- what the open page shows and what the badges say
	task.spawn(function()
		while true do
			task.wait(1)
			self:_render("tick")
			self:_refreshBadges()
		end
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		local page = HOTKEYS[input.KeyCode]
		-- never over a throw sequence
		if page and not processed and hud:Mode() ~= "cinematic" then
			Screens.switch(page)
		end
	end)

	-- The hub stations open their screen (the server does nothing for these
	-- actions: see InteractService). This is also the only way to reach the
	-- daily rewards page once today's reward is claimed.
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		local page = STATIONS[prompt:GetAttribute("Action")]
		if page then
			Screens.open(page)
		end
	end)
end

return MenuController
