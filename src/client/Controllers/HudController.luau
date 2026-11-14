--!strict
-- HudController - the always-on readouts: Yen, income, Power, luck, food, the
-- objective line, toasts, the catch reveal card, banners and event timers.
--
-- SECTION 2 TEST HUD. Built in code from Ui/Make so the loop is playable now;
-- section 3 replaces the instances with the roblox-ui screens from
-- design/ui.json. The METHODS here (Toast, Reveal, HideReveal, Flash,
-- SetObjective) are the contract the rest of the client uses and stay.

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
local Make = require(script.Parent.Parent.Ui.Make)

local MAPS = Lookup.of(Config)
local player = Players.LocalPlayer

local TOAST_COLORS: { [string]: Color3 } = { good = Make.GOOD, bad = Make.BAD, info = Make.INFO }

local HudController = Knit.CreateController({
	Name = "HudController",
	_labels = {} :: { [string]: TextLabel },
	_toasts = nil :: Frame?,
	_reveal = nil :: Frame?,
	_banner = nil :: TextLabel?,
	_objective = nil :: TextLabel?,
	_envLabel = nil :: TextLabel?,
	_flash = nil :: TextLabel?,
	_envAt = 0,
	_holdIncome = false,
})

--- The luck multiplier the player would throw with right now (equipped food,
--- no depth, not perfect), and its breakdown lines.
function HudController:CurrentLuck(): (number, { Luck.Line })
	local state = self._state.State
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

--- A short notice. kind: "good" | "bad" | "info".
function HudController:Toast(text: string, kind: string?)
	local holder = self._toasts
	if not holder then
		return
	end
	local toast = Make.label(holder, text, {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 0.15,
		BackgroundColor3 = TOAST_COLORS[kind or "info"] or Make.INFO,
	})
	Make.corner(toast, 8)
	task.delay(3.2, function()
		toast:Destroy()
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

--- The line at the top that says what to do next. "" hides it.
function HudController:SetObjective(text: string)
	local label = self._objective
	if label then
		label.Text = text
		label.Visible = text ~= ""
	end
end

--- "PERFECT!" / "LUCKY THROW!" at the moment the food lands.
function HudController:Flash(perfect: boolean, lucky: boolean)
	local label = self._flash
	if not label or not (perfect or lucky) then
		return
	end
	label.Text = if lucky then "LUCKY THROW!" elseif perfect then "PERFECT!" else ""
	label.TextTransparency = 0
	label.TextStrokeTransparency = 0
	label.Visible = true
	local tween = TweenService:Create(
		label,
		TweenInfo.new(0.9),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	)
	tween:Play()
end

--- Show the catch card for a throw result (or a granted hero).
function HudController:Reveal(result: any)
	local card = self._reveal
	if not card then
		return
	end
	local character = MAPS.character[result.id] or MAPS.premium[result.id]
	local rarity = result.rarity or "Premium"
	local rarityRow = Config.Rarities[rarity]
	local color = if rarityRow
		then Color3.fromHex(rarityRow.Color)
		else Color3.fromRGB(255, 79, 163)
	local tags = {}
	if result.size then
		table.insert(tags, result.size:upper())
	end
	if result.mut then
		table.insert(tags, result.mut:upper())
	end
	table.insert(tags, if character then character.Name else result.id)
	local stamps = {}
	if result.isNew then
		table.insert(stamps, "NEW!")
	end
	if result.isBest then
		table.insert(stamps, "NEW BEST!")
	end
	if result.flavorMatch then
		table.insert(stamps, "CRAVING!")
	end
	local where = if result.action == "sold"
		then `sold for {Format.short(result.soldYen or 0)} yen`
		elseif result.action == "bench" then "sent to your bench"
		else "joins your plot"

	self._labels.RevealRarity.Text = rarity:upper()
	self._labels.RevealRarity.TextColor3 = color
	self._labels.RevealName.Text = table.concat(tags, " ")
	self._labels.RevealIncome.Text = `{Format.short(result.income or 0)} yen/s  -  {where}`
	self._labels.RevealOdds.Text = if result.oneInN then Format.oneIn(result.oneInN) else ""
	self._labels.RevealStamps.Text = table.concat(stamps, "  ")
	card.Visible = true
end

function HudController:HideReveal()
	if self._reveal then
		self._reveal.Visible = false
	end
end

function HudController:_build()
	local gui = Make.screen("DevHud", 10)

	-- stats, bottom-left
	local stats = Make.frame(gui, {
		Name = "Stats",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(300, 196),
		BackgroundTransparency = 0.25,
	})
	Make.corner(stats, 12)
	Make.list(stats, Enum.FillDirection.Vertical, 2)
	local rows = {
		{ "YenCounter", Color3.fromRGB(140, 255, 150) },
		{ "IncomePerSecond", Color3.fromRGB(190, 255, 190) },
		{ "PowerCounter", Color3.fromRGB(120, 190, 255) },
		{ "LuckChip", Color3.fromRGB(150, 255, 120) },
		{ "FoodChip", Color3.fromRGB(255, 220, 150) },
		{ "TrainingBar", Color3.fromRGB(255, 255, 255) },
	}
	for i, row in rows do
		self._labels[row[1]] = Make.label(stats, "", {
			Name = row[1],
			Size = UDim2.new(1, -12, 0, 30),
			TextColor3 = row[2],
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = i,
		})
	end

	-- objective, events and banner, top-centre
	self._objective = Make.label(gui, "", {
		Name = "TutorialHint",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.new(0.6, 0, 0, 40),
		Visible = false,
	})
	self._envLabel = Make.label(gui, "", {
		Name = "ServerLuckBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 52),
		Size = UDim2.new(0.5, 0, 0, 26),
		TextColor3 = Color3.fromRGB(150, 255, 120),
	})
	self._banner = Make.label(gui, "", {
		Name = "Announcement",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 84),
		Size = UDim2.new(0.8, 0, 0, 44),
		Visible = false,
	})
	self._flash = Make.label(gui, "", {
		Name = "Flash",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.new(0.5, 0, 0, 70),
		TextColor3 = Make.BUY,
		Visible = false,
	})

	-- toasts, top-right under the Roblox buttons
	local toasts = Make.frame(gui, {
		Name = "Toasts",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 140),
		Size = UDim2.fromOffset(340, 300),
		BackgroundTransparency = 1,
	})
	Make.list(toasts, Enum.FillDirection.Vertical, 6)
	self._toasts = toasts

	-- reveal card, lower centre
	local card = Make.frame(gui, {
		Name = "Reveal",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 134),
		Size = UDim2.fromOffset(560, 210),
		BackgroundTransparency = 0.2,
		Visible = false,
	})
	Make.corner(card, 16)
	Make.stroke(card, 4, Color3.new(1, 1, 1))
	local lines = {
		{ "RevealRarity", 0, 44 },
		{ "RevealName", 46, 50 },
		{ "RevealIncome", 100, 30 },
		{ "RevealOdds", 132, 30 },
		{ "RevealStamps", 164, 28 },
	}
	for _, line in lines do
		self._labels[line[1]] = Make.label(card, "", {
			Name = line[1],
			Position = UDim2.fromOffset(10, line[2] + 4),
			Size = UDim2.new(1, -20, 0, line[3]),
		})
	end
	self._labels.RevealStamps.TextColor3 = Make.BUY
	Make.label(card, "tap to skip", {
		Name = "SkipHint",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -2),
		Size = UDim2.fromOffset(110, 16),
		TextTransparency = 0.4,
	})
	self._reveal = card

	gui.Parent = player:WaitForChild("PlayerGui")
end

function HudController:_refresh()
	local state = self._state.State
	if not state then
		return
	end
	local labels = self._labels
	local rank = Progress.rank(Config, state.power)
	local luck = self:CurrentLuck()
	local food = MAPS.food[state.food]
	labels.YenCounter.Text = `{Format.short(state.yen)} yen`
	if not self._holdIncome then
		labels.IncomePerSecond.Text = `+{Format.short(state.income or 0)} yen/s`
	end
	labels.PowerCounter.Text = `{Format.short(state.power)} PWR  [{rank.name}]`
	labels.LuckChip.Text = `Luck {Format.mult(luck)}`
	labels.FoodChip.Text = if food then `{food.Name} ({food.Flavor})` else ""
	if state.training then
		local gear = Config.Training.Equipment[state.gear]
		local toNext = if rank.nextPower then ` -> {Format.short(rank.nextPower)}` else ""
		labels.TrainingBar.Text = `TRAINING on {gear.Name}{toNext}`
	else
		labels.TrainingBar.Text = if state.mock then "(Studio: saving is OFF)" else ""
	end
end

function HudController:_refreshEnv()
	local env = self._state.Env
	local label = self._envLabel
	if not env or not label then
		return
	end
	local now = env.unixNow + (os.clock() - self._envAt)
	local parts = {}
	if env.luck > 1 then
		local left = math.max(0, env.luckUntil - now)
		table.insert(parts, `SERVER LUCK {Format.mult(env.luck)}  {Format.duration(left)}`)
	end
	if env.festival then
		local left = math.max(0, env.festivalEnds - now)
		table.insert(parts, `FESTIVAL HOUR  {Format.duration(left)}`)
	else
		table.insert(parts, `Festival in {Format.duration(math.max(0, env.festivalNext - now))}`)
	end
	label.Text = table.concat(parts, "    ")
end

function HudController:KnitStart()
	self._state = Knit.GetController("StateController")
	self:_build()

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
			local banner = self._banner
			if not banner or typeof(payload) ~= "table" then
				return
			end
			local row = if payload.rarity then Config.Rarities[payload.rarity] else nil
			banner.TextColor3 = if row then Color3.fromHex(row.Color) else Make.BUY
			banner.Text = tostring(payload.text)
			banner.Visible = true
			local shown = banner.Text
			task.delay(5, function()
				if banner.Text == shown then
					banner.Visible = false
				end
			end)
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
