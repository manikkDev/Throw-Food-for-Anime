--!strict
-- HudController - the always-on readouts: Yen, income, Power and rank, luck,
-- the equipped food, the slim objective line, the notice card, the
-- server-luck bar, the announcement banner and toasts.
--
-- The instances are the authored HUD screen (src/ui, reached through
-- Ui/Screens). The METHODS here (Toast, Notice, SetObjective, SetMode, Flash,
-- Banner, Reveal, HideReveal, HoldIncome, CurrentLuck, and since v4.1
-- ZoneCross, LevelUp, SetCinematic) are the contract the rest of the client
-- uses. The animated moments themselves are in Ui/HudMoments.
--
-- The HUD has three modes. "normal": everything. "throw" (standing on the
-- throw pad): the button columns and every notice step aside, the stats and
-- the hint line stay. "cinematic" (a throw sequence is playing): the whole
-- HUD is off, and toasts that arrive wait until it is back, so nothing ever
-- appears over the lane.
--
-- SetCinematic(reason, on) is the softer, reason-stacked version: every HUD
-- group (side buttons, stats, hint, notice, luck bar) fades out in 0.35 s and
-- back when the last reason clears, pages cannot open meanwhile, and toasts,
-- the announcement banner and the HudFx moments (ZoneCross, LevelUp, which
-- draw above the Reveal screen) keep showing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Net = require(ReplicatedStorage.Shared.Net)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local Luck = require(ReplicatedStorage.Shared.Core.Luck)
local Progress = require(ReplicatedStorage.Shared.Core.Progress)
local Vfx = require(script.Parent.Parent.Fx.Vfx)
local RevealUi = require(script.Parent.Parent.Ui.RevealUi)
local Screens = require(script.Parent.Parent.Ui.Screens)
local HudMoments = require(script.Parent.Parent.Ui.HudMoments)
local Moments = require(script.Parent.Parent.Ui.Moments)
local Theme = require(script.Parent.Parent.Ui.Theme)
local Viewports = require(script.Parent.Parent.Ui.Viewports)
local Sound = require(script.Parent.SoundController)

local MAPS = Lookup.of(Config)

local TOAST_SECONDS = 3.2
local TOAST_MAX = 3 -- on screen at once; an older one makes room
local ANNOUNCE_SECONDS = 5
local NOTICE_SECONDS = 12 -- a notice nobody answers steps aside by itself
local CINEMATIC_FADE = 0.35
-- the HUD groups a cinematic fades (never the toasts, the announcement or the
-- flash line)
local CINEMATIC_GROUPS = {
	"LeftColumn",
	"RightColumn",
	"BtnSettings",
	"FoodChip",
	"PowerCounter",
	"YenCounter",
	"LuckChip",
	"TutorialHint",
	"NoticeCard",
	"BuffTray",
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
	_buffCount = 0,
	_buffOpen = false,
	_buffPinned = false,
	_buffSeen = {} :: { [string]: boolean },
	_buffStamp = 0,
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
	_fx = nil :: ScreenGui?,
	_cinematic = {} :: { [string]: boolean },
	_cinHidden = false,
	_cinStamp = 0,
	_fade = HudMoments.newFade(),
	_announceQueue = {} :: { any },
	_announceRunning = false,
	_ownedFoods = nil :: { [string]: boolean }?,
	_slots = nil :: number?,
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

function HudController:_retire(toast: GuiObject, now: boolean?)
	local at = table.find(self._toastsLive, toast)
	if not at then
		return
	end
	table.remove(self._toastsLive, at)
	local function gone()
		toast.Visible = false
		if not table.find(self._toastsSpare, toast) then
			table.insert(self._toastsSpare, toast)
		end
	end
	if now then
		gone()
	else
		HudMoments.toastOut(toast, function()
			-- the same instance may have been taken again meanwhile
			if not table.find(self._toastsLive, toast) then
				gone()
			end
		end)
	end
end

--- A short notice. kind: "good" | "bad" | "info" (a "good" one that hands
--- something out is shown as a gold reward). Slides in with a pop, its icon
--- bounces, a shine crosses it; sound per kind (toast_good / toast_warn /
--- toast_pop); eases out after TOAST_SECONDS.
function HudController:Toast(text: string, kind: string?)
	local holder = self._toastHolder
	if not holder then
		return
	end
	if kind == "bad" then
		-- a refused action (not enough yen, bench full, bad code)
		Sound:Play("ui_error")
	end
	if self._mode == "cinematic" then
		-- nothing over the lane during a throw: it is shown when the HUD is back
		table.insert(self._pendingToasts, { text = text, kind = kind })
		while #self._pendingToasts > TOAST_MAX do
			table.remove(self._pendingToasts, 1)
		end
		return
	end
	-- the same words already on screen (the client and the server can both say "place your hero
	-- first"): that toast gets its time again and a pop, no second copy
	for _, live in self._toastsLive do
		if Screens.label(live, "Text").Text == text then
			self._toastCount += 1
			local again = self._toastCount
			live:SetAttribute("Stamp", again)
			Screens.pop(live, 1.12)
			task.delay(TOAST_SECONDS, function()
				if live:GetAttribute("Stamp") == again then
					self:_retire(live)
				end
			end)
			return
		end
	end
	while #self._toastsLive >= TOAST_MAX do
		self:_retire(self._toastsLive[1], true)
	end
	local toast = table.remove(self._toastsSpare)
	if not toast then
		toast = Screens.template("ToastTemplate")
		toast.Name = "Toast"
		toast.Parent = holder
	end
	self._toastCount += 1
	local stamp = self._toastCount
	toast:SetAttribute("Stamp", stamp)
	toast.LayoutOrder = stamp
	Screens.label(toast, "Text").Text = text
	toast.Visible = true
	table.insert(self._toastsLive, toast)
	HudMoments.toastIn(toast, HudMoments.toastKind(text, kind))
	task.delay(TOAST_SECONDS, function()
		-- the same instance may already be showing a newer toast
		if toast:GetAttribute("Stamp") == stamp then
			self:_retire(toast)
		end
	end)
end

-- Toasts draw above EVERY page and dialog (owner's review of section 5: "Sold for ..." came up
-- behind the Squad page, purchase notices behind the Store). The HUD sits under the pages
-- (DisplayOrder 1), so its Toasts stack moves into a top layer of its own whose canvas copies
-- the HUD canvas's size, position and scale as Screens fits them: every toast keeps the same
-- place on screen, only its draw order changes.
local TOAST_LAYER_ORDER = 40 -- pages 10-12, Confirm 14, HudFx 15; under the VFX overlay (50)
function HudController:_raiseToasts(hud: ScreenGui, holder: GuiObject)
	local canvas = hud:FindFirstChild("CanvasFrame")
	if not canvas or not canvas:IsA("GuiObject") then
		return
	end
	local layer = Instance.new("ScreenGui")
	layer.Name = "ToastLayer"
	layer.DisplayOrder = TOAST_LAYER_ORDER
	layer.IgnoreGuiInset = hud.IgnoreGuiInset
	layer.ScreenInsets = hud.ScreenInsets
	layer.ZIndexBehavior = hud.ZIndexBehavior
	layer.ResetOnSpawn = false
	local mirror = Instance.new("Frame")
	mirror.Name = "CanvasFrame"
	mirror.BackgroundTransparency = 1
	local scale = Instance.new("UIScale")
	scale.Name = "Scale"
	scale.Parent = mirror
	local source = canvas:FindFirstChild("Scale")
	local function sync()
		mirror.AnchorPoint = canvas.AnchorPoint
		mirror.Position = canvas.Position
		mirror.Size = canvas.Size
		if source and source:IsA("UIScale") then
			scale.Scale = source.Scale
		end
	end
	sync()
	for _, property in { "AnchorPoint", "Position", "Size" } do
		canvas:GetPropertyChangedSignal(property):Connect(sync)
	end
	if source and source:IsA("UIScale") then
		source:GetPropertyChangedSignal("Scale"):Connect(sync)
	end
	mirror.Parent = layer
	holder.Parent = mirror
	layer.Parent = hud.Parent
	self._toastLayer = layer
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
-- A top-level piece of the HUD by name. Looked up once, and quietly: a piece
-- the tree does not carry is nil. A piece in a `<Name>Cell` is its cell (the
-- cell also carries its shadow).
function HudController:_part(name: string): GuiObject?
	local hud = self._hud
	if not hud then
		return nil
	end
	local part = self._parts[name]
	if part == nil then
		local found = hud:FindFirstChild(name, true)
		local cell = found and found.Parent
		if cell and cell:IsA("GuiObject") and cell.Name == name .. "Cell" then
			found = cell
		end
		part = if found and found:IsA("GuiObject") then found else false
		self._parts[name] = part
	end
	return if typeof(part) == "Instance" then part else nil
end

-- Show or hide a top-level piece of the HUD by name.
function HudController:_setVisible(name: string, visible: boolean)
	local part = self:_part(name)
	if part and part.Visible ~= visible then
		part.Visible = visible
	end
end

-- who is on screen, given the mode and what there is to say
function HudController:_layout()
	local open = self._mode == "normal" and not self._cinHidden
	self:_setVisible("LeftColumn", open)
	self:_setVisible("BtnSettings", open)
	self:_setVisible("RightColumn", open)
	self:_setVisible("FoodChip", open)
	-- the counters go too in a soft cinematic (the throw pad, a rebirth): the owner asked for
	-- nothing on screen but the throw
	self:_setVisible("PowerCounter", not self._cinHidden)
	self:_setVisible("YenCounter", not self._cinHidden)
	self:_setVisible("LuckChip", not self._cinHidden)
	-- a notice never sits under a page: it steps aside while one is open and
	-- comes back, if it is still true, when the page closes
	self:_setVisible(
		"NoticeCard",
		open and self._notice ~= nil and not Screens.isOpen() and not self._announcing
	)
	-- the announcement keeps showing on the throw pad and in a soft cinematic
	self:_setVisible("Announcement", self._mode ~= "cinematic" and self._announcing)
	-- v4.7 (owner's review of section 5): every active boost lives in the BOOSTS tray in the
	-- top-right corner under the settings gear, folded to its header unless opened
	self:_setVisible("BuffTray", open and self._buffCount > 0)
	-- the hint belongs to the normal HUD: not in throw mode, not in a sequence
	self:_setVisible("TutorialHint", open and self._objective ~= "")
	self:_placeToasts()
end

-- the top-centre pieces (any order: the lowest visible one counts)
local TOP_STACK = { "TutorialHint", "Announcement", "NoticeCard" }
local TOAST_TOP = 12 -- the stack's top when nothing else is up there
local TOAST_CLEAR = 10 -- px between the lowest top-centre piece and the stack

-- v4.4: the toasts stack at the top centre, under whatever top-centre piece
-- is showing (the hint, the announcement bar, the luck bar, a notice), so a
-- toast never covers the banner
function HudController:_placeToasts()
	local holder = self._toastHolder
	if not holder then
		return
	end
	local bottom = TOAST_TOP - TOAST_CLEAR
	for _, name in TOP_STACK do
		local part = self:_part(name)
		if part and part.Visible then
			local saved = part:GetAttribute("HomePosition")
			local at = if typeof(saved) == "UDim2" then saved else part.Position
			local top = at.Y.Offset - part.AnchorPoint.Y * part.Size.Y.Offset
			bottom = math.max(bottom, top + part.Size.Y.Offset)
		end
	end
	local goal = UDim2.new(0.5, 0, 0, bottom + TOAST_CLEAR)
	-- a page is open: the stack drops to the bottom centre, under the window, so a toast never
	-- covers the page's title (owner's review of section 5) and stays in plain sight
	local layout = holder:FindFirstChildOfClass("UIListLayout")
	local atBottom = Screens.isOpen()
	local anchor = if atBottom then Vector2.new(0.5, 1) else Vector2.new(0.5, 0)
	if atBottom then
		goal = UDim2.new(0.5, 0, 1, -TOAST_CLEAR)
	end
	if holder.AnchorPoint ~= anchor then
		-- switching ends: jump, do not slide across the screen
		holder.AnchorPoint = anchor
		holder.Position = goal
		if layout then
			layout.VerticalAlignment = if atBottom
				then Enum.VerticalAlignment.Bottom
				else Enum.VerticalAlignment.Top
		end
	end
	if holder.Position ~= goal then
		TweenService:Create(holder, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Position = goal })
			:Play()
	end
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
	if self._mode ~= "normal" or next(self._cinematic) ~= nil then
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
	Sound:Play("toast_pop")
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

-- The sound and effect of a hero GIVEN outside a throw: a summon opens a
-- portal over the player, anything else (store, gift) is a purchase or a gift.
function HudController:_grantMoment(payload: any)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if payload.reason == "summon" then
		Sound:Play("summon_open")
		if root and root:IsA("BasePart") then
			Vfx.play("Summon_Portal", root.Position + Vector3.new(0, 4, 0))
		end
	elseif payload.reason == "gift" then
		Sound:Play("daily_claim")
	else
		Sound:Play("buy_success")
	end
	if payload.isNew then
		task.delay(0.5, function()
			Sound:Play("index_new")
		end)
	end
end

-- A banner for everyone: a rare catch, server luck, a festival, a rebirth.
-- One at a time (queued), never while the Reveal screen is up (it would sit
-- over the reveal's own top lines): it waits for the reveal to end.
function HudController:_announce(payload: any)
	-- the local player's own rebirth is told by its cinematic (one banner, never two)
	if payload.kind == "rebirth" then
		local me = Players.LocalPlayer
		local text = tostring(payload.text or "")
		if
			payload.userId == me.UserId
			or payload.player == me.Name
			or text:sub(1, #me.DisplayName + 1) == me.DisplayName .. " "
		then
			return
		end
	end
	table.insert(self._announceQueue, payload)
	while #self._announceQueue > 4 do
		table.remove(self._announceQueue, 1)
	end
	if self._announceRunning then
		return
	end
	self._announceRunning = true
	task.spawn(function()
		while #self._announceQueue > 0 do
			local waited = 0
			while (Screens.get("Reveal").Enabled or self._mode == "cinematic") and waited < 20 do
				task.wait(0.25)
				waited += 0.25
			end
			self:_showAnnouncement(table.remove(self._announceQueue, 1))
			task.wait(ANNOUNCE_SECONDS + 0.4)
		end
		self._announceRunning = false
	end)
end

function HudController:_showAnnouncement(payload: any)
	local labels = self._labels
	local text = tostring(payload.text)
	local player, hero, odds = "", text, ""
	local heroId: string? = nil
	if payload.kind == "catch" then
		-- "<name> caught <TAGS> <hero>  (1 in N)": the hero name is the big
		-- line, the size / mutation tags join the small "caught by" line
		local who, what, chance = text:match("^(.-) caught (.-)%s+%((.-)%)$")
		if who and what and chance then
			local tags = ""
			hero = ""
			-- the longest roster name the text ends with (a short name can end a longer one)
			for id, character in MAPS.character do
				local name = character.Name
				if #name > #hero and #what >= #name and what:sub(-#name) == name then
					heroId = id
					hero = name
					tags = what:sub(1, #what - #name):match("^%s*(.-)%s*$") or ""
				end
			end
			if heroId == nil then
				hero = what
			end
			player = `CAUGHT BY {who:upper()}` .. (if tags ~= "" then `  ·  {tags}` else "")
			odds = chance
		end
	else
		player = ANNOUNCE_HEADS[payload.kind] or ""
	end
	labels.AnnouncePlayer.Text = player
	labels.AnnounceHero.Text = hero
	labels.AnnounceOdds.Text = odds
	local rarity = if payload.rarity then tostring(payload.rarity) else nil
	labels.AnnounceRarity.Text = if rarity then rarity:upper() else ""
	local banner = Screens.frame(self._hud :: ScreenGui, "Announcement")
	local chip = Screens.frame(banner, "RarityChip")
	chip.Visible = rarity ~= nil
	if rarity then
		Screens.tint(chip, Theme.rarity(rarity))
	end
	HudMoments.dressAnnouncement(banner, tostring(payload.kind), rarity)
	-- the hero's portrait in the round well when the catch names one; the
	-- event icon otherwise
	local portrait = banner:FindFirstChild("AnnouncePortrait", true)
	if portrait and portrait:IsA("ViewportFrame") then
		Viewports.hero(portrait, heroId)
		Screens.image(banner, "AnnounceIcon").Visible = heroId == nil
	end

	self._announceId += 1
	local id = self._announceId
	self._announcing = true
	self:_layout()
	HudMoments.announceIn(banner)
	task.delay(ANNOUNCE_SECONDS, function()
		if self._announceId == id then
			HudMoments.announceOut(banner, function()
				if self._announceId == id then
					self._announcing = false
					self:_layout()
				end
			end)
		end
	end)
end

-- --------------------------------------------------------- v4.1 moments --

--- A thrown food crossed into zone `index` (1-based) named `name`: the region
--- banner at the TOP centre, under the letterbox bar and below the flight's
--- luck line: "ZONE n", then the name slams in with an echo, a glow and rays
--- in the zone colour, a sheen. Later zones hype harder ("zone_hype" from
--- zone 4). Shows during cinematics.
function HudController:ZoneCross(name: string, color: Color3, index: number)
	local fx = self._fx
	if fx then
		HudMoments.zoneCross(fx, name, color, index)
	end
end

--- THE celebratory banner (rank up, rebirth): one glossy plate at the top
--- centre with `title` small over `sub` big inside it (an empty `sub` puts
--- the title on the big line). `color` tints the plate (gold when nil). Shows
--- during cinematics, above the reveal. A moment that shows this never also
--- toasts.
function HudController:LevelUp(title: string, sub: string, color: Color3?)
	local fx = self._fx
	if fx then
		HudMoments.levelUp(fx, title, sub, color)
	end
end

--- An unboxing reward at screen centre (Ui/Moments): info = { title, name,
--- sub?, model? (a Model / BasePart template, cloned into a viewport), image?
--- (an icon key or a content id, used when there is no model), color?,
--- rarity? }. Queued; a tap or 2.8 s dismisses each. Never errors.
function HudController:Reward(info: any)
	Moments.reward(info)
end

--- The modal confirmation dialog (Ui/Moments): info = { title, name, model?,
--- image? / icon?, rows = { { label, from?, to, icon? } }, cost?, costKind?
--- ("yen" | "robux"), canAfford?, confirmText?, color?, onConfirm,
--- onCancel? }. Returns a handle with :Close(). Escape / B cancels.
function HudController:Confirm(info: any): any
	return Moments.confirm(info)
end

--- The stats panel the rebirth cinematic fills one row at a time (Ui/Moments):
--- info = { title, color?, rows = { { label, from?, to, icon? } }, step?
--- (0.5 s), hold? }. Shows over a cinematic. Returns a handle with :Close().
function HudController:StatTicks(info: any): any
	return Moments.statTicks(info)
end

-- Purchases told by the state itself (the server no longer toasts them): a
-- new food, a new plot slot. Gear is the TrainingBar's (Ui/Pages/TrainingBar).
-- The first snapshot only sets the baseline.
function HudController:_purchases(state: any)
	local foods = state.foods
	if typeof(foods) == "table" then
		local known = self._ownedFoods
		local now: { [string]: boolean } = {}
		for id, owned in foods do
			if owned then
				now[id] = true
			end
		end
		if known then
			for _, food in Config.Foods do
				if now[food.Id] and not known[food.Id] then
					local assets = ReplicatedStorage:FindFirstChild("Assets")
					local folder = assets and assets:FindFirstChild("Foods")
					self:Reward({
						title = "NEW FOOD!",
						name = food.Name,
						sub = `Luck {Format.mult(food.Luck)}   Power {Format.mult(food.PowerMult)}`,
						chips = {
							{ text = `Luck {Format.mult(food.Luck)}`, icon = "IconLuck" },
							{ text = `Power {Format.mult(food.PowerMult)}`, icon = "IconPower" },
							{
								text = tostring(food.Flavor):upper(),
								icon = "IconFlavor" .. tostring(food.Flavor),
								color = Theme.FLAVOR_TILE[food.Flavor],
							},
						},
						model = folder and folder:FindFirstChild("Food_" .. food.Id),
						image = "Food_" .. food.Id,
						color = Theme.FLAVOR_TILE[food.Flavor] or Theme.CONFIRM,
					})
				end
			end
		end
		self._ownedFoods = now
	end
	local slots = state.slots
	if typeof(slots) == "number" then
		local was = self._slots
		if was and slots == was + 1 then
			self:Reward({
				title = "NEW SLOT!",
				name = `Slot {slots}`,
				sub = "One more hero on your plot",
				chips = {
					{ text = `Slot {slots} of {Config.Plot.MaxSlots}`, icon = "IconPlace" },
					{ text = "+1 hero on your plot", icon = "IconStar" },
				},
				image = "IconPlaceBig",
				color = Color3.fromHex("37D67A"),
			})
		end
		self._slots = slots
	end
end

--- Fade the HUD out for `reason` (on) or let that reason go (off). Reasons
--- stack: the HUD comes back when the last one clears. While any reason
--- holds, every HUD group and side-button group is faded out (0.35 s) and
--- hidden, and pages cannot open; the ThrowMeter, TrainingBar, reveal,
--- toasts, announcements, ZoneCross and LevelUp are not touched.
function HudController:SetCinematic(reason: string, on: boolean)
	local was = next(self._cinematic) ~= nil
	self._cinematic[reason] = if on then true else nil
	local now = next(self._cinematic) ~= nil
	if was == now then
		return
	end
	Screens.setBlocked(now)
	self._cinStamp += 1
	local stamp = self._cinStamp
	local groups: { GuiObject } = {}
	for _, name in CINEMATIC_GROUPS do
		local part = self:_part(name)
		if part then
			table.insert(groups, part)
		end
	end
	if now then
		HudMoments.fadeOut(self._fade, groups, CINEMATIC_FADE, function()
			if self._cinStamp == stamp then
				self._cinHidden = true
				self:_layout()
				HudMoments.restore(self._fade)
			end
		end)
	else
		local hidden = self._cinHidden
		self._cinHidden = false
		if hidden then
			HudMoments.clear(self._fade, groups)
		end
		self:_layout()
		HudMoments.fadeIn(self._fade, groups, CINEMATIC_FADE)
	end
end

--- True while any SetCinematic reason holds.
function HudController:IsCinematic(): boolean
	return next(self._cinematic) ~= nil
end

function HudController:_bind()
	local hud = Screens.get("HUD")
	self._hud = hud
	self._fx = Screens.get("HudFx")
	-- every UI sound (hover, toasts, moments) goes through the SoundController
	Screens.setSound(function(role: string)
		Sound:Play(role)
	end)
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
	self:_raiseToasts(hud, self._toastHolder)

	-- the boosts tray: the header opens and closes it; it stays as the player left it
	Screens.button(hud, "BuffToggle").Activated:Connect(function()
		Screens.sound("ui_click")
		self._buffPinned = true
		self._buffOpen = not self._buffOpen
		self:_refreshBuffs()
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

-- The BOOSTS tray (v4.7): one row per active boost (server luck, Festival Hour, timed 2x Yen,
-- lucky throws), a count on the header. Folded it is only the header; a boost that was not there
-- before opens it for BUFF_PEEK seconds (unless the player has opened or closed it by hand).
local BUFF_PEEK = 5
-- each row: the row, its value label, its clock label (spelled out: the dead-label gate reads them)
local BUFF_ROWS = {
	{ "BuffServerLuck", "BuffServerLuckValue", "BuffServerLuckTime" },
	{ "BuffFestival", "BuffFestivalValue", "BuffFestivalTime" },
	{ "BuffDoubleYen", "BuffDoubleYenValue", "BuffDoubleYenTime" },
	{ "BuffLucky", "BuffLuckyValue", "BuffLuckyTime" },
}
function HudController:_refreshEnv()
	self:_refreshBuffs()
end

function HudController:_refreshBuffs()
	local hud = self._hud
	if not hud then
		return
	end
	local env = self._state.Env
	local state = self._state.State
	local now = if env then env.unixNow + (os.clock() - self._envAt) else os.time()
	local active: { [string]: { value: string, time: string } } = {}
	if env and env.luck > 1 then
		active.BuffServerLuck =
			{ value = `{Format.mult(env.luck)} LUCK`, time = Screens.clock(env.luckUntil - now) }
	end
	if env and env.festival == true then
		active.BuffFestival =
			{ value = "2x MUTATIONS", time = Screens.clock(env.festivalEnds - now) }
	end
	local passes = state and state.passes
	local yenUntil = if state then tonumber(state.doubleYenUntil) or 0 else 0
	if yenUntil > now and not (passes and passes.DoubleYen) then
		active.BuffDoubleYen = { value = "x2 INCOME", time = Screens.clock(yenUntil - now) }
	end
	local lucky = if state then tonumber(state.luckyThrows) or 0 else 0
	if lucky > 0 then
		active.BuffLucky = { value = `{lucky} LEFT`, time = "" }
	end

	local count = 0
	local fresh = false
	for key in active do
		count += 1
		if not self._buffSeen[key] then
			fresh = true
		end
	end
	for key in self._buffSeen do
		if not active[key] then
			self._buffSeen[key] = nil
		end
	end
	for key in active do
		self._buffSeen[key] = true
	end
	if fresh and not self._buffPinned then
		-- a new boost: show the rows for a moment, then fold them away again
		self._buffOpen = true
		self._buffStamp += 1
		local stamp = self._buffStamp
		task.delay(BUFF_PEEK, function()
			if self._buffStamp == stamp and not self._buffPinned then
				self._buffOpen = false
				self:_refreshBuffs()
			end
		end)
	end

	local changed = (count > 0) ~= (self._buffCount > 0)
	self._buffCount = count
	Screens.label(hud, "BuffCountText").Text = tostring(count)
	for _, names in BUFF_ROWS do
		local row = Screens.frame(hud, names[1])
		local data = active[names[1]]
		row.Visible = data ~= nil
		if data then
			Screens.label(row, names[2]).Text = data.value
			Screens.label(row, names[3]).Text = data.time
		end
	end
	local rows = Screens.frame(hud, "BuffRows")
	local open = self._buffOpen and count > 0
	if rows.Visible ~= open then
		rows.Visible = open
		if open then
			Screens.pop(rows, 0.9)
		end
	end
	local chevron = Screens.image(hud, "Chevron")
	-- IconArrow points up: down while folded, up while open
	chevron.Rotation = if open then 0 else 180
	if changed then
		self:_layout()
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

	self._state:Observe(function(state: any)
		self:_refresh()
		self:_refreshBuffs()
		if typeof(state) == "table" then
			local ok, err = pcall(self._purchases, self, state)
			if not ok then
				warn(`[HudController] purchase moment failed inert: {err}`)
			end
		end
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
				self:_grantMoment(nextUp)
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
