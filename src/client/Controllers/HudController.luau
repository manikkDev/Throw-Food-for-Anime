--!strict
-- HudController - the always-on readouts: Yen, income, Power and rank, luck,
-- the equipped food, the slim objective line, the notice card, the
-- server-luck bar, the announcement banner and toasts.
--
-- The instances are the authored HUD screen (src/ui, reached through
-- Ui/Screens). The METHODS here (Toast, Notice, SetObjective, SetMode, Flash,
-- Banner, Reveal, HideReveal, HoldIncome, CurrentLuck) are the contract the
-- rest of the client uses.
--
-- The HUD has three modes. "normal": everything. "throw" (standing on the
-- throw pad): the button columns and every notice step aside, the stats and
-- the hint line stay. "cinematic" (a throw sequence is playing): the whole
-- HUD is off, and toasts that arrive wait until it is back, so nothing ever
-- appears over the lane.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local Luck = require(ReplicatedStorage.Shared.Core.Luck)
local Progress = require(ReplicatedStorage.Shared.Core.Progress)
local RevealUi = require(script.Parent.Parent.Ui.RevealUi)
local Screens = require(script.Parent.Parent.Ui.Screens)
local Theme = require(script.Parent.Parent.Ui.Theme)

local MAPS = Lookup.of(Config)

local TOAST_SECONDS = 3.2
local TOAST_MAX = 3 -- on screen at once; an older one makes room
local ANNOUNCE_SECONDS = 5
local NOTICE_SECONDS = 12 -- a notice nobody answers steps aside by itself
local TOAST_LOOK: { [string]: { color: Color3, icon: string } } = {
	good = { color = Theme.TOAST.good, icon = "IconTick" },
	bad = { color = Theme.TOAST.bad, icon = "IconClose" },
	info = { color = Theme.TOAST.info, icon = "IconInfo" },
}
-- headline over an announcement that is not a catch
local ANNOUNCE_HEADS: { [string]: string } = {
	luck = "SERVER LUCK",
	festival = "FESTIVAL HOUR",
	rebirth = "REBIRTH",
	say = "ANNOUNCEMENT",
}

local HudController = Knit.CreateController({
	Name = "HudController",
	_state = nil :: any,
	_hud = nil :: ScreenGui?,
	_mode = "normal",
	_parts = {} :: { [string]: GuiObject | boolean },
	_pendingToasts = {} :: { { text: string, kind: string? } },
	_notice = nil :: string?,
	_noticePage = nil :: string?,
	_noticeSeen = {} :: { [string]: boolean },
	_noticeStamp = 0,
	_envActive = false,
	_labels = {} :: { [string]: TextLabel },
	_toastHolder = nil :: GuiObject?,
	_toastsLive = {} :: { GuiObject },
	_toastsSpare = {} :: { GuiObject },
	_toastCount = 0,
	_objective = "",
	_announceId = 0,
	_announcing = false,
	_envAt = 0,
	_holdIncome = false,
})

--- The luck multiplier the player would throw with right now (equipped food,
--- no depth, not perfect), and its breakdown lines.
function HudController:CurrentLuck(): (number, { Luck.Line })
	local state = if self._state then self._state.State else nil
	if not state or not state.luck then
		return 1, {}
	end
	local sources = table.clone(state.luck)
	local food = MAPS.food[state.food]
	sources.foodLuck = if food then food.Luck else 1
	local env = self._state.Env
	if env then
		sources.serverMult = env.luck
	end
	return Luck.total(Config, sources), Luck.breakdown(Config, sources)
end

function HudController:_retire(toast: GuiObject)
	local at = table.find(self._toastsLive, toast)
	if at then
		table.remove(self._toastsLive, at)
		toast.Visible = false
		table.insert(self._toastsSpare, toast)
	end
end

--- A short notice. kind: "good" | "bad" | "info".
function HudController:Toast(text: string, kind: string?)
	local holder = self._toastHolder
	if not holder then
		return
	end
	if self._mode == "cinematic" then
		-- nothing over the lane during a throw: it is shown when the HUD is back
		table.insert(self._pendingToasts, { text = text, kind = kind })
		while #self._pendingToasts > TOAST_MAX do
			table.remove(self._pendingToasts, 1)
		end
		return
	end
	while #self._toastsLive >= TOAST_MAX do
		self:_retire(self._toastsLive[1])
	end
	local toast = table.remove(self._toastsSpare)
	if not toast then
		toast = Screens.template("ToastTemplate")
		toast.Name = "Toast"
		toast.Parent = holder
	end
	local look = TOAST_LOOK[kind or "info"] or TOAST_LOOK.info
	self._toastCount += 1
	local stamp = self._toastCount
	toast:SetAttribute("Stamp", stamp)
	toast.LayoutOrder = stamp
	Screens.tint(toast, look.color)
	Screens.setIcon(Screens.image(toast, "Icon"), look.icon)
	Screens.label(toast, "Text").Text = text
	toast.Visible = true
	table.insert(self._toastsLive, toast)
	task.delay(TOAST_SECONDS, function()
		-- the same instance may already be showing a newer toast
		if toast:GetAttribute("Stamp") == stamp then
			self:_retire(toast)
		end
	end)
end

--- While held, the income line does not move. The throw sequence holds it so
--- the number cannot give the catch away before the reveal.
function HudController:HoldIncome(hold: boolean)
	self._holdIncome = hold
	if not hold then
		self:_refresh()
	end
end

-- Show or hide a top-level piece of the HUD by name. Looked up once, and
-- quietly: a piece the tree does not carry is simply skipped.
function HudController:_setVisible(name: string, visible: boolean)
	local hud = self._hud
	if not hud then
		return
	end
	local part = self._parts[name]
	if part == nil then
		local found = hud:FindFirstChild(name, true)
		-- a piece that sits in a `<Name>Cell` is shown and hidden by the cell
		-- (the cell also carries its shadow)
		local cell = found and found.Parent
		if cell and cell:IsA("GuiObject") and cell.Name == name .. "Cell" then
			found = cell
		end
		part = if found and found:IsA("GuiObject") then found else false
		self._parts[name] = part
	end
	if typeof(part) == "Instance" and part.Visible ~= visible then
		part.Visible = visible
	end
end

-- who is on screen, given the mode and what there is to say
function HudController:_layout()
	local open = self._mode == "normal"
	self:_setVisible("LeftColumn", open)
	self:_setVisible("BtnSettings", open)
	self:_setVisible("RightColumn", open)
	self:_setVisible("FoodChip", open)
	-- a notice never sits under a page: it steps aside while one is open and
	-- comes back, if it is still true, when the page closes
	self:_setVisible("NoticeCard", open and self._notice ~= nil and not Screens.isOpen())
	self:_setVisible("Announcement", open and self._announcing)
	self:_setVisible("ServerLuckBar", open and self._envActive)
	-- the hint belongs to the normal HUD: not in throw mode, not in a sequence
	self:_setVisible("TutorialHint", open and self._objective ~= "" and not self._announcing)
end

-- a notice nobody answers steps aside by itself, NOTICE_SECONDS after it was
-- last put on screen
function HudController:_armNotice()
	local id = self._notice
	if not id then
		return
	end
	self._noticeStamp += 1
	local stamp = self._noticeStamp
	task.delay(NOTICE_SECONDS, function()
		if self._noticeStamp == stamp and self._notice == id then
			self:_closeNotice()
		end
	end)
end

--- "normal" | "throw" | "cinematic" (see the top of this file).
function HudController:SetMode(mode: string)
	if mode == self._mode then
		return
	end
	local was = self._mode
	self._mode = mode
	local hud = self._hud
	if not hud then
		return
	end
	hud.Enabled = mode ~= "cinematic"
	self:_layout()
	if was == "cinematic" then
		local pending = self._pendingToasts
		self._pendingToasts = {}
		for _, toast in pending do
			self:Toast(toast.text, toast.kind)
		end
	end
end

--- The mode the HUD is in now.
function HudController:Mode(): string
	return self._mode
end

function HudController:_closeNotice()
	self._notice = nil
	self._noticePage = nil
	self:_layout()
end

--- A compact card: an icon, a title, one line, and (with `page`) one button
--- that opens that page. Each `id` is shown once per session.
function HudController:Notice(
	id: string,
	spec: {
		icon: string?,
		title: string,
		body: string,
		button: string?,
		buttonIcon: string?,
		page: string?,
	}
)
	local hud = self._hud
	if not hud or self._noticeSeen[id] then
		return
	end
	if self._mode ~= "normal" then
		return -- it is raised again when the HUD is back
	end
	self._noticeSeen[id] = true
	self._notice = id
	self._noticePage = spec.page
	local card = Screens.frame(hud, "NoticeCard")
	Screens.label(card, "NoticeTitle").Text = spec.title
	Screens.label(card, "NoticeBody").Text = spec.body
	Screens.label(card, "NoticeButtonText").Text = spec.button or "OPEN"
	local button = Screens.button(card, "NoticeButton")
	local buttonCell = button.Parent
	if buttonCell and buttonCell:IsA("GuiObject") and buttonCell.Name == "NoticeButtonCell" then
		buttonCell.Visible = spec.page ~= nil
	else
		button.Visible = spec.page ~= nil
	end
	Screens.setIcon(Screens.image(button, "Icon"), spec.buttonIcon or "IconArrow")
	Screens.setIcon(Screens.image(card, "NoticeIcon"), spec.icon or "IconInfo")
	self:_layout()
	self:_armNotice()
end

--- Take a notice down because it is no longer true (the food was bought).
function HudController:ClearNotice(id: string)
	if self._notice == id then
		self:_closeNotice()
	end
end

--- The line at the top that says what to do next. "" hides it.
function HudController:SetObjective(text: string)
	if text == self._objective then
		return
	end
	self._objective = text
	local label = self._labels.ObjectiveLine
	if label then
		label.Text = text
	end
	self:_layout()
end

--- One big line that fades by itself ("RANK UP!  FIGHTER").
function HudController:Banner(text: string)
	local label = self._labels.FlashText
	if not label then
		return
	end
	label.Text = text
	label.Visible = true
	Screens.fadeText(label, 0, 1, 1.4)
end

--- "PERFECT!" / "LUCKY THROW!".
function HudController:Flash(perfect: boolean, lucky: boolean)
	if perfect or lucky then
		self:Banner(if lucky then "LUCKY THROW!" else "PERFECT!")
	end
end

--- Show a hero the player was GIVEN (store, gift): the final beat of the
--- reveal, without the throw. A thrown catch is Fx/ThrowSequence's.
function HudController:Reveal(result: any)
	RevealUi.enable(true)
	RevealUi.final(result)
end

function HudController:HideReveal()
	RevealUi.enable(false)
end

-- A banner for everyone: a rare catch, server luck, a festival, a rebirth.
function HudController:_announce(payload: any)
	local labels = self._labels
	local text = tostring(payload.text)
	local player, hero, odds = "", text, ""
	if payload.kind == "catch" then
		-- "<name> caught <tags and hero>  (1 in N)"
		local who, what, chance = text:match("^(.-) caught (.-)%s+%((.-)%)$")
		if who and what and chance then
			player, hero, odds = who .. " caught", what, chance
		end
	else
		player = ANNOUNCE_HEADS[payload.kind] or ""
	end
	labels.AnnouncePlayer.Text = player
	labels.AnnounceHero.Text = hero
	labels.AnnounceOdds.Text = odds
	labels.AnnounceRarity.Text = if payload.rarity then tostring(payload.rarity):upper() else ""
	local color = if payload.rarity then Theme.rarity(payload.rarity) else Theme.BUY
	labels.AnnounceRarity.TextColor3 = color
	labels.AnnounceOdds.TextColor3 = color

	self._announceId += 1
	local id = self._announceId
	self._announcing = true
	self:_layout()
	task.delay(ANNOUNCE_SECONDS, function()
		if self._announceId == id then
			self._announcing = false
			self:_layout()
		end
	end)
end

function HudController:_bind()
	local hud = Screens.get("HUD")
	self._hud = hud
	RevealUi.bind()

	local labels = self._labels
	for _, name in
		{
			"YenAmount",
			"IncomePerSecond",
			"PowerAmount",
			"RankName",
			"LuckAmount",
			"FoodName",
			"FoodFlavor",
			"ObjectiveLine",
			"Multiplier",
			"TimeLeft",
			"FlashText",
		}
	do
		labels[name] = Screens.label(hud, name)
	end
	local banner = Screens.frame(hud, "Announcement")
	labels.AnnouncePlayer = Screens.label(banner, "PlayerName")
	labels.AnnounceHero = Screens.label(banner, "HeroName")
	labels.AnnounceRarity = Screens.label(banner, "RarityText")
	labels.AnnounceOdds = Screens.label(banner, "OneInN")

	-- nothing shows its mockup placeholder: empty until there is real data
	for _, label in labels do
		label.Text = ""
	end
	labels.FlashText.Visible = false

	-- the notice card: one button that opens a page, and a close
	local card = Screens.frame(hud, "NoticeCard")
	for _, name in { "NoticeTitle", "NoticeBody", "NoticeButtonText" } do
		Screens.label(card, name).Text = ""
	end
	Screens.button(card, "NoticeButton").Activated:Connect(function()
		local page = self._noticePage
		self:_closeNotice()
		if page then
			Screens.open(page)
		end
	end)
	Screens.button(card, "NoticeClose").Activated:Connect(function()
		self:_closeNotice()
	end)

	-- live toasts are clones of ToastTemplate; the tree's own ToastSample rows
	-- are mockup data and Screens has already destroyed them
	self._toastHolder = Screens.frame(hud, "Toasts")

	Screens.button(hud, "BoostButton").Activated:Connect(function()
		Knit.GetController("MenuController"):Prompt(MAPS.product.ServerLuck, false)
	end)
	self:_layout()
end

function HudController:_refresh()
	local state = self._state.State
	local hud = self._hud
	if not state or not hud then
		return
	end
	local labels = self._labels
	local rank = Progress.rank(Config, state.power)
	local luck = self:CurrentLuck()
	local food = MAPS.food[state.food]
	labels.YenAmount.Text = Format.short(state.yen)
	if not self._holdIncome then
		labels.IncomePerSecond.Text = `+{Format.short(state.income or 0)}/s`
	end
	labels.PowerAmount.Text = Format.short(state.power)
	labels.RankName.Text = rank.name:upper()
	labels.LuckAmount.Text = Format.mult(luck)
	labels.FoodName.Text = if food then food.Name else ""
	labels.FoodFlavor.Text = if food then food.Flavor:upper() else ""
	if food and hud:GetAttribute("FoodShown") ~= food.Id then
		hud:SetAttribute("FoodShown", food.Id)
		local chip = Screens.button(hud, "FoodChip")
		Screens.setIcon(Screens.image(chip, "Icon"), "Food_" .. food.Id)
		Screens.setIcon(Screens.image(chip, "FlavorIcon"), "IconFlavor" .. food.Flavor)
	end
end

-- The bar under the objective: server luck while it is raised, the Festival
-- Hour while it runs. With both active it alternates every few seconds.
function HudController:_refreshEnv()
	local env = self._state.Env
	local hud = self._hud
	if not env or not hud then
		return
	end
	local now = env.unixNow + (os.clock() - self._envAt)
	local luckOn = env.luck > 1
	local festivalOn = env.festival == true
	if self._envActive ~= (luckOn or festivalOn) then
		self._envActive = luckOn or festivalOn
		self:_layout()
	end
	local labels = self._labels
	if festivalOn and (not luckOn or math.floor(now / 4) % 2 == 1) then
		labels.Multiplier.Text = "FESTIVAL!"
		labels.TimeLeft.Text = Screens.clock(env.festivalEnds - now)
	elseif luckOn then
		labels.Multiplier.Text = `SERVER {Format.mult(env.luck)}`
		labels.TimeLeft.Text = Screens.clock(env.luckUntil - now)
	end
end

function HudController:KnitInit()
	self._state = Knit.GetController("StateController")
end

function HudController:KnitStart()
	self:_bind()

	Screens.Opened:Connect(function()
		self:_layout()
	end)
	Screens.Closed:Connect(function()
		-- a notice that waited under the page gets its full time again
		if not Screens.isOpen() then
			self:_armNotice()
		end
		self:_layout()
	end)

	self._state:Observe(function()
		self:_refresh()
	end)
	self._state.Ticked:Connect(function()
		self:_refresh()
	end)
	self._state.EnvChanged:Connect(function()
		self._envAt = os.clock()
		self:_refreshEnv()
		self:_refresh()
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			self:_refreshEnv()
		end
	end)

	local toast = Net.client("Toast")
	if toast then
		toast.OnClientEvent:Connect(function(text: string, kind: string)
			self:Toast(text, kind)
		end)
	end
	local announce = Net.client("Announce")
	if announce then
		announce.OnClientEvent:Connect(function(payload: any)
			if typeof(payload) == "table" then
				self:_announce(payload)
			end
		end)
	end
	local granted = Net.client("HeroGranted")
	if granted then
		-- heroes from the store or a gift: a short card each, one after another
		local queue: { any } = {}
		local running = false
		granted.OnClientEvent:Connect(function(payload: any)
			table.insert(queue, payload)
			if running then
				return
			end
			running = true
			while #queue > 0 do
				-- never over a throw sequence: wait for it to finish
				while self._mode == "cinematic" do
					task.wait(0.2)
				end
				local nextUp = table.remove(queue, 1)
				self:Reveal(nextUp)
				task.wait(1.6)
				self:HideReveal()
				task.wait(0.15)
			end
			running = false
		end)
	end
end

return HudController
