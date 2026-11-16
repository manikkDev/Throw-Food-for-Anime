--!strict
-- Moments - the three v4.2 moments HudController hands out (owner's review 3):
--
--   Moments.reward(info)    the unboxing popup at screen centre (HudFx.Reward):
--                           the model zooms in small -> big with a spin and an
--                           overshoot, keeps turning; rays, a glow and a halo in
--                           the item colour turn behind it (UI images: particles
--                           do not render in a ViewportFrame); the title plate
--                           on top, name and sub line under it, a sheen.
--                           reward_whoosh, then reward_pop. A tap / click or
--                           2.8 s dismisses it. Several queue.
--   Moments.statTicks(info) the rebirth's stats panel (HudFx.StatPanel), filled
--                           ONE ROW AT A TIME: each row slides in, its number
--                           counts (or flips) from `from` to `to` with stat_tick
--                           and a flash; it stays `hold` s, then eases out.
--   Moments.confirm(info)   the modal confirmation dialog (Confirm screen).
--
-- Every field of every info table is optional except where noted; a missing
-- one never errors (a moment with nothing to show simply shows less). All
-- three draw on screens above the Reveal screen and the cinematic fade, so
-- they show while HudController:SetCinematic has the HUD faded.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Screens = require(script.Parent.Screens)
local Theme = require(script.Parent.Theme)
local UiFx = require(script.Parent.UiFx)
local Viewports = require(script.Parent.Viewports)

local Moments = {}

local GREEN = Color3.fromHex("37D67A")
local REWARD_SECONDS = 4 -- owner's review 4: long enough to read; a tap still dismisses
local _player = Players.LocalPlayer

local function tween(
	object: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
): Tween
	local t = TweenService:Create(
		object,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		goal
	)
	t:Play()
	return t
end

local function scaleOf(object: GuiObject, name: string): UIScale
	local found = object:FindFirstChild(name)
	if found and found:IsA("UIScale") then
		return found
	end
	local made = Instance.new("UIScale")
	made.Name = name
	made.Parent = object
	return made
end

local function str(value: any): string?
	if value == nil then
		return nil
	end
	local s = tostring(value)
	return if s ~= "" then s else nil
end

--- An image for an icon key ("IconPower", "IconPlaceBig", "Food_ramen") or a
--- raw content id ("rbxassetid://123", a number). "" when unknown.
function Moments.imageFor(key: any): string
	if typeof(key) == "number" then
		return `rbxassetid://{key}`
	end
	if typeof(key) ~= "string" or key == "" then
		return ""
	end
	if key:find("://", 1, true) then
		return key
	end
	if key:match("^%d+$") then
		return "rbxassetid://" .. key
	end
	local found = Screens.icon(key)
	if found == "" then
		found = Screens.icon((key:gsub("Big$", "")))
	end
	return found
end

-- set an icon slot: a key through Screens.setIcon (Big when the slot is
-- big), a raw id as is; false when there was nothing to show
local function putIcon(image: ImageLabel, key: any): boolean
	if
		typeof(key) == "string"
		and key ~= ""
		and not key:find("://", 1, true)
		and not key:match("^%d+$")
	then
		Screens.setIcon(image, key)
		if image.Image == "" then
			image.Image = Moments.imageFor(key)
		end
	else
		image.Image = Moments.imageFor(key)
	end
	return image.Image ~= ""
end

local function sweepOver(face: GuiObject)
	local laidOut = face:FindFirstChildWhichIsA("UIGridStyleLayout") ~= nil
	if laidOut then
		return
	end
	UiFx.sweep(UiFx.makeShine(face, face, true), 0.8)
end

local function faceOf(control: GuiObject): GuiObject
	local face = control:FindFirstChild("Face")
	return if face and face:IsA("GuiObject") then face else control
end

local function lighter(color: Color3, k: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), k)
end

-- ================================================================ reward

export type RewardInfo = {
	title: string?,
	name: string?,
	sub: string?,
	model: Instance?,
	image: string?,
	color: Color3?,
	rarity: string?,
	-- v4.3: up to three detail chips under the name ({ text, icon?, color? });
	-- with none, `sub` shows as one line
	chips: { { text: string?, icon: string?, color: Color3? } }?,
}

local rewardQueue: { RewardInfo } = {}
local rewardRunning = false

local function easeOutBack(x: number): number
	local c1, c3 = 1.9, 2.9
	local u = x - 1
	return 1 + c3 * u * u * u + c1 * u * u
end

-- A soft fade of a whole moment: every text, image and painted frame under
-- `root` goes from fully clear to its shipped look (in) or back (out). The
-- shipped values are read once and kept, so repeated fades never drift.
local shipped: { [Instance]: { [string]: number } } = {}
local FADE_PROPS = {
	TextLabel = { "TextTransparency", "BackgroundTransparency" },
	ImageLabel = { "ImageTransparency", "BackgroundTransparency" },
	Frame = { "BackgroundTransparency" },
	UIStroke = { "Transparency" },
	ViewportFrame = { "ImageTransparency" },
}
local function fade(root: Instance, visible: boolean, seconds: number)
	local nodes = root:GetDescendants()
	table.insert(nodes, root)
	for _, node in nodes do
		local props = FADE_PROPS[node.ClassName]
		if props then
			local keep = shipped[node]
			if not keep then
				keep = {}
				for _, prop in props do
					keep[prop] = (node :: any)[prop]
				end
				shipped[node] = keep
				node.Destroying:Once(function()
					shipped[node] = nil
				end)
			end
			local goal = {}
			for prop, value in keep do
				goal[prop] = if visible then value else 1
			end
			if visible and seconds > 0 then
				for prop in keep do
					(node :: any)[prop] = 1
				end
			end
			if seconds > 0 then
				TweenService:Create(
					node,
					TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					goal
				):Play()
			else
				for prop, value in goal do
					(node :: any)[prop] = value
				end
			end
		end
	end
end

local function showReward(info: RewardInfo)
	local gui = Screens.get("HudFx")
	local holder = Screens.frame(gui, "Reward")
	local scrim = Screens.frame(gui, "Scrim")
	local stage = Screens.viewport(holder, "RewardStage")
	local icon = Screens.image(holder, "RewardIcon")
	local plate = Screens.frame(holder, "RewardTitlePlate")
	local color = if typeof(info.color) == "Color3" then info.color else GREEN

	Screens.label(holder, "RewardTitle").Text = str(info.title) or "NEW!"
	Screens.label(holder, "RewardName").Text = str(info.name) or ""
	local chips = if typeof(info.chips) == "table" then info.chips else {}
	for i = 1, 3 do
		local data = chips[i]
		local cell = Screens.frame(holder, `RewardChip{i}Cell`)
		cell.Visible = typeof(data) == "table" and str(data.text) ~= nil
		if cell.Visible then
			Screens.label(holder, `RewardChipText{i}`).Text = str(data.text) or ""
			local slot = Screens.image(holder, `RewardChip{i}Icon`)
			slot.Visible = putIcon(slot, data.icon or "IconStar")
			Screens.tint(
				Screens.frame(holder, `RewardChip{i}`),
				if typeof(data.color) == "Color3"
					then data.color
					else color:Lerp(Color3.new(0, 0, 0), 0.25)
			)
		end
	end
	local hasChips = #chips > 0
	Screens.frame(holder, "RewardChips").Visible = hasChips
	local sub = Screens.label(holder, "RewardSub")
	sub.Text = if hasChips then "" else str(info.sub) or ""
	sub.Visible = sub.Text ~= ""
	Screens.tint(plate, color)
	UiFx.setColour(holder, lighter(color, 0.35))
	UiFx.setRarity(holder, if typeof(info.rarity) == "string" then info.rarity else "Epic")

	-- the thing itself: the model in the stage, else the icon
	local shown = if typeof(info.model) == "Instance"
		then Viewports.model(stage, info.model, 1.0)
		else nil
	stage.Visible = shown ~= nil
	icon.Visible = shown == nil and putIcon(icon, info.image)

	local pop = scaleOf(holder, "PopScale")
	local iconPop = scaleOf(icon, "IconPop")
	-- in: a smooth fade with a gentle scale (owner's review 4: no pop-on / pop-off)
	pop.Scale = 0.88
	iconPop.Scale = 0.4
	scrim.BackgroundTransparency = 1
	scrim.Visible = true
	UiFx.level(holder) -- v4.5: a moment always comes in level
	holder.Visible = true
	UiFx.activate("reward", true)
	fade(holder, true, 0.35)
	tween(scrim, 0.35, { BackgroundTransparency = 0.5 })
	tween(pop, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(iconPop, 0.6, { Scale = 1 }, Enum.EasingStyle.Back)
	Screens.sound("reward_whoosh")
	task.delay(0.42, function()
		Screens.sound("reward_pop")
		sweepOver(plate)
	end)

	-- the model: in from small with a spin and an overshoot, then a slow turn
	local t0 = os.clock()
	local spin: RBXScriptConnection? = nil
	if shown then
		Viewports.pose(shown, -math.pi * 3, 6)
		spin = RunService.RenderStepped:Connect(function()
			local t = os.clock() - t0
			local k = math.clamp(t / 0.7, 0, 1)
			local grow = 0.12 + 0.88 * easeOutBack(k) -- the size on screen, overshooting 1
			local turn = (1 - (1 - k) ^ 3) * math.pi * 3
			Viewports.pose(shown, -math.pi * 3 + turn + t * 0.6, 1 / math.max(grow, 0.05))
		end)
	end

	-- dismissed by a tap / click (after a short grace) or by time
	local done = false
	local tap: RBXScriptConnection? = nil
	tap = UserInputService.InputBegan:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if
			os.clock() - t0 > 0.45
			and (
				kind == Enum.UserInputType.MouseButton1
				or kind == Enum.UserInputType.Touch
				or input.KeyCode == Enum.KeyCode.ButtonA
				or input.KeyCode == Enum.KeyCode.Space
				or input.KeyCode == Enum.KeyCode.Return
			)
		then
			done = true
		end
	end)
	while not done and os.clock() - t0 < REWARD_SECONDS do
		task.wait(0.05)
	end
	if tap then
		tap:Disconnect()
	end
	-- out: fade and settle a little, never a snap
	fade(holder, false, 0.4)
	tween(scrim, 0.4, { BackgroundTransparency = 1 })
	tween(pop, 0.4, { Scale = 0.94 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.wait(0.42)
	if spin then
		spin:Disconnect()
	end
	holder.Visible = false
	scrim.Visible = false
	pop.Scale = 1
	fade(holder, true, 0)
	Viewports.clear(stage)
	UiFx.activate("reward", false)
end

--- Queue an unboxing reward (see the top of this file). Never errors.
function Moments.reward(info: RewardInfo?)
	if typeof(info) ~= "table" then
		return
	end
	table.insert(rewardQueue, info)
	if rewardRunning then
		return
	end
	rewardRunning = true
	task.spawn(function()
		while #rewardQueue > 0 do
			local nextUp = table.remove(rewardQueue, 1)
			local ok, err = pcall(showReward, nextUp)
			if not ok then
				warn(`[Moments] reward failed inert: {err}`)
				local gui = Screens.get("HudFx")
				Screens.frame(gui, "Reward").Visible = false
				Screens.frame(gui, "Scrim").Visible = false
				UiFx.activate("reward", false)
			end
			task.wait(0.1)
		end
		rewardRunning = false
	end)
end

-- ============================================================ stat ticks

export type StatRow = { label: string?, from: string?, to: string?, icon: string? }
export type StatInfo = {
	title: string?,
	color: Color3?,
	rows: { StatRow }?,
	step: number?,
	hold: number?,
}
export type Handle = { Close: (self: Handle) -> () }

local MAX_STAT_ROWS = 6
local statStamp = 0

-- "x1.50" -> ("x", 1.5, "", 2); "+1.2K" -> ("+", 1.2, "K", 1); nil when not a number
local function parse(text: string): (string?, number?, string?, number?)
	local prefix, digits, suffix = text:match("^([^%d]-)([%d,]*%.?%d+)(.*)$")
	if not digits then
		return nil, nil, nil, nil
	end
	local clean = digits:gsub(",", "")
	local value = tonumber(clean)
	local decimals = if clean:find("%.") then #clean - (clean:find("%.") :: number) else 0
	return prefix, value, suffix, decimals
end

-- the number in `to` counts up from the number in `from` (same prefix and
-- suffix), else the text flips; ends exactly on `to`
local function countTo(label: TextLabel, from: string?, to: string, seconds: number, stamp: number)
	local p1, v1, s1
	if from then
		p1, v1, s1 = parse(from)
	end
	local p2, v2, s2, d2 = parse(to)
	if not (v1 and v2 and p1 == p2 and s1 == s2) then
		label.Text = to
		return
	end
	local a, b = v1 :: number, v2 :: number
	local fmt = `%.{d2 or 0}f`
	local t0 = os.clock()
	task.spawn(function()
		while statStamp == stamp do
			local k = math.clamp((os.clock() - t0) / seconds, 0, 1)
			local e = 1 - (1 - k) ^ 3
			label.Text = (p2 or "") .. string.format(fmt, a + (b - a) * e) .. (s2 or "")
			if k >= 1 then
				break
			end
			task.wait()
		end
		label.Text = to
	end)
end

local function closeStats(stamp: number)
	if statStamp ~= stamp then
		return
	end
	statStamp += 1
	local mine = statStamp
	local panel = Screens.frame(Screens.get("HudFx"), "StatPanel")
	local pop = scaleOf(panel, "PopScale")
	tween(pop, 0.25, { Scale = 0.85 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(
		panel,
		0.25,
		{ Position = panel:GetAttribute("HomePosition") :: UDim2 + UDim2.fromOffset(80, 0) },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	).Completed:Once(function()
		if statStamp == mine then
			panel.Visible = false
			panel.Position = panel:GetAttribute("HomePosition") :: UDim2
			pop.Scale = 1
			UiFx.activate("stats", false)
		end
	end)
end

--- The stats panel, filled one row at a time. Returns a handle with :Close().
function Moments.statTicks(info: StatInfo?): Handle
	statStamp += 1
	local stamp = statStamp
	local handle = {} :: any
	function handle.Close(_self: any)
		closeStats(stamp)
	end
	if typeof(info) ~= "table" then
		return handle
	end
	local gui = Screens.get("HudFx")
	local panel = Screens.frame(gui, "StatPanel")
	local home = panel:GetAttribute("HomePosition")
	if typeof(home) ~= "UDim2" then
		home = panel.Position
		panel:SetAttribute("HomePosition", home)
	end
	local at = home :: UDim2
	local color = if typeof(info.color) == "Color3" then info.color else Color3.fromHex("A35BFF")
	Screens.label(panel, "StatTitle").Text = str(info.title) or ""
	Screens.tint(Screens.frame(panel, "StatHeader"), color)
	UiFx.setColour(panel, lighter(color, 0.2))
	local rows = if typeof(info.rows) == "table" then info.rows else {}
	for i = 1, MAX_STAT_ROWS do
		Screens.frame(panel, "StatRow" .. i).Visible = false
	end
	local pop = scaleOf(panel, "PopScale")
	pop.Scale = 0.85
	panel.Position = at + UDim2.fromOffset(80, 0)
	UiFx.level(panel) -- v4.5: a moment always comes in level
	panel.Visible = true
	UiFx.activate("stats", true)
	tween(panel, 0.35, { Position = at }, Enum.EasingStyle.Back)
	tween(pop, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	Screens.sound("confirm_open")

	local step = if typeof(info.step) == "number" then math.max(info.step, 0.1) else 0.5
	local hold = if typeof(info.hold) == "number" then math.max(info.hold, 0) else 1.6
	task.spawn(function()
		task.wait(0.35)
		local count = math.min(#rows, MAX_STAT_ROWS)
		for i = 1, count do
			if statStamp ~= stamp then
				return
			end
			local data = rows[i]
			if typeof(data) == "table" then
				local row = Screens.frame(panel, "StatRow" .. i)
				local fromText = str(data.from)
				local toText = str(data.to) or ""
				Screens.label(row, "StatLabel").Text = str(data.label) or ""
				local fromLabel = Screens.label(row, "StatFrom")
				fromLabel.Text = fromText or ""
				fromLabel.Visible = fromText ~= nil
				Screens.image(row, "StatArrow").Visible = fromText ~= nil
				local iconSlot = Screens.image(row, "StatIcon")
				iconSlot.Visible = putIcon(iconSlot, data.icon or "IconStar")
				local toLabel = Screens.label(row, "StatTo")
				toLabel.Text = fromText or toText
				-- slides in from the right
				local face = faceOf(row)
				local rowPop = scaleOf(face, "RowPop")
				rowPop.Scale = 0.6
				face.Position = UDim2.fromOffset(60, face.Position.Y.Offset)
				row.Visible = true
				tween(face, 0.25, {
					Position = UDim2.fromOffset(
						if face ~= row then 3 else 0,
						face.Position.Y.Offset
					),
				}, Enum.EasingStyle.Back)
				tween(rowPop, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
				-- the number counts to its new value, with a flash
				task.delay(0.18, function()
					if statStamp ~= stamp then
						return
					end
					countTo(toLabel, fromText, toText, math.min(0.4, step * 0.8), stamp)
					local toPop = scaleOf(toLabel, "TickPop")
					toPop.Scale = 1.35
					tween(toPop, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
					local was = toLabel.TextColor3
					toLabel.TextColor3 = Color3.new(1, 1, 1)
					tween(toLabel, 0.35, { TextColor3 = was })
					local shell = faceOf(row)
					local glow = shell.BackgroundColor3
					shell.BackgroundColor3 = lighter(color, 0.3)
					tween(shell, 0.4, { BackgroundColor3 = glow })
					Screens.sound("stat_tick")
				end)
			end
			task.wait(step)
		end
		task.wait(hold)
		closeStats(stamp)
	end)
	return handle
end

-- ================================================================ confirm

export type ConfirmRow = { label: string?, from: string?, to: string?, icon: string? }
export type ConfirmInfo = {
	title: string?,
	name: string?,
	model: Instance?,
	image: string?,
	icon: string?,
	rows: { ConfirmRow }?,
	cost: number?,
	costKind: string?,
	canAfford: boolean?,
	confirmText: string?,
	color: Color3?,
	tag: string?, -- v4.3: a tier / rarity chip under the name ("TIER 6", "LEGENDARY")
	tagColor: Color3?,
	onConfirm: (() -> ())?,
	onCancel: (() -> ())?,
}

local MAX_CONFIRM_ROWS = 3
local confirmStamp = 0
local confirmClose: ((boolean) -> ())? = nil
local confirmBound = false
local yenColour: Color3? = nil

local function formatShort(n: number): string
	local ok, Format = pcall(function()
		return require(game:GetService("ReplicatedStorage").Shared.Core.Format) :: any
	end)
	if ok and Format and Format.short then
		return Format.short(n)
	end
	return tostring(math.floor(n))
end

local function bindConfirm(gui: ScreenGui)
	if confirmBound then
		return
	end
	confirmBound = true
	local function cancel()
		local close = confirmClose
		if close then
			Screens.sound("ui_click")
			close(false)
		end
	end
	Screens.button(gui, "ConfirmNo").Activated:Connect(cancel)
	Screens.button(gui, "ConfirmClose").Activated:Connect(cancel)
	Screens.button(gui, "ConfirmYes").Activated:Connect(function()
		local close = confirmClose
		local yes = Screens.button(gui, "ConfirmYes")
		if close and yes:GetAttribute("Allowed") == true then
			Screens.sound("confirm_yes")
			close(true)
		elseif close then
			Screens.sound("ui_error")
		end
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not gui.Enabled then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			cancel()
		elseif
			(input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.ButtonA)
			and not processed
		then
			local yes = Screens.button(gui, "ConfirmYes")
			if confirmClose and yes:GetAttribute("Allowed") == true then
				Screens.sound("confirm_yes")
				local close = confirmClose
				if close then
					close(true)
				end
			end
		end
	end)
end

--- The modal confirmation dialog. Returns a handle with :Close() (closes as a
--- cancel, without calling onCancel). A second dialog replaces the first.
function Moments.confirm(info: ConfirmInfo?): Handle
	local handle = {} :: any
	local data: ConfirmInfo = if typeof(info) == "table" then info else {}
	local gui = Screens.get("Confirm")
	bindConfirm(gui)
	local previous = confirmClose
	if previous then
		previous(false)
	end
	confirmStamp += 1
	local stamp = confirmStamp
	local window = Screens.frame(gui, "ConfirmWindow")
	local scrim = Screens.frame(gui, "Scrim")
	local color = if typeof(data.color) == "Color3" then data.color else Color3.fromHex("FFC83D")

	Screens.label(gui, "ConfirmTitle").Text = str(data.title) or "CONFIRM"
	Screens.label(gui, "ConfirmName").Text = str(data.name) or ""
	local tag = str(data.tag)
	Screens.frame(gui, "ConfirmTagCell").Visible = tag ~= nil
	Screens.label(gui, "ConfirmTagText").Text = if tag then tag:upper() else ""
	Screens.tint(
		Screens.frame(gui, "ConfirmTag"),
		if typeof(data.tagColor) == "Color3"
			then data.tagColor
			else color:Lerp(Color3.new(0, 0, 0), 0.35)
	)
	Screens.tint(Screens.frame(gui, "ConfirmHeader"), color)
	local well = Screens.frame(gui, "StageWell")
	UiFx.setColour(well, lighter(color, 0.2))

	-- the model turning on the left, else the image / icon
	local viewport = Screens.viewport(gui, "ConfirmViewport")
	local shown = if typeof(data.model) == "Instance"
		then Viewports.model(viewport, data.model, 1.05)
		else nil
	viewport.Visible = shown ~= nil
	local icon = Screens.image(gui, "ConfirmIcon")
	icon.Visible = shown == nil and putIcon(icon, data.image or data.icon or "IconStar")

	-- what changes
	local rows = if typeof(data.rows) == "table" then data.rows else {}
	for i = 1, MAX_CONFIRM_ROWS do
		local row = Screens.frame(gui, "ConfirmRow" .. i)
		local r = rows[i]
		row.Visible = typeof(r) == "table"
		if typeof(r) == "table" then
			local fromText = str(r.from)
			Screens.label(row, "RowLabel").Text = str(r.label) or ""
			local fromLabel = Screens.label(row, "RowFrom")
			fromLabel.Text = fromText or ""
			fromLabel.Visible = fromText ~= nil
			Screens.image(row, "RowArrow").Visible = fromText ~= nil
			Screens.label(row, "RowTo").Text = str(r.to) or ""
			local slot = Screens.image(row, "RowIcon")
			slot.Visible = putIcon(slot, r.icon or "IconStar")
		end
	end

	-- the price
	local cost = if typeof(data.cost) == "number" then data.cost else nil
	local afford = data.canAfford ~= false
	local robux = data.costKind == "robux"
	Screens.frame(gui, "CostWell").Visible = cost ~= nil
	local costText = Screens.label(gui, "CostText")
	if not yenColour then
		yenColour = costText.TextColor3
	end
	if cost then
		costText.Text = if robux then tostring(cost) else formatShort(cost)
		Screens.setIcon(Screens.image(gui, "CostIcon"), if robux then "IconRobux" else "IconYen")
		Screens.setIcon(
			Screens.image(gui, "CostBadgeIcon"),
			if robux then "IconRobux" else "IconYen"
		)
		costText.TextColor3 = if afford then yenColour :: Color3 else Theme.SOFT_RED
	end
	local yes = Screens.button(gui, "ConfirmYes")
	local yesText = Screens.label(yes, "YesText")
	yes:SetAttribute("Allowed", afford)
	if afford then
		Screens.setButtonState(
			yes,
			if robux then "robux" else "afford",
			(str(data.confirmText) or "CONFIRM"):upper(),
			if robux then "IconRobux" else "IconTick"
		)
	else
		Screens.setButtonState(
			yes,
			"cannot",
			if robux then "NOT ENOUGH" else "NEED MORE YEN",
			"IconYen"
		)
	end

	yesText.Visible = true
	-- open: dim the world, pop the window from the centre
	local pop = scaleOf(window, "PopScale")
	pop.Scale = 0.6
	scrim.BackgroundTransparency = 1
	UiFx.level(window) -- v4.5: a moment always comes in level
	gui.Enabled = true
	tween(scrim, 0.2, { BackgroundTransparency = 0.5 })
	tween(pop, 0.32, { Scale = 1 }, Enum.EasingStyle.Back)
	UiFx.activate("confirm", true)
	Screens.sound("confirm_open")

	local spin: RBXScriptConnection? = nil
	if shown then
		local t0 = os.clock()
		spin = RunService.RenderStepped:Connect(function()
			Viewports.pose(shown, math.rad(25) + (os.clock() - t0) * 0.7, 1)
		end)
	end

	local closed = false
	local function close(confirmed: boolean, quiet: boolean?)
		if closed then
			return
		end
		closed = true
		if confirmClose == close then
			confirmClose = nil
		end
		if spin then
			spin:Disconnect()
		end
		tween(scrim, 0.15, { BackgroundTransparency = 1 })
		tween(pop, 0.15, { Scale = 0.7 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.16, function()
			if confirmStamp == stamp then
				gui.Enabled = false
				Viewports.clear(viewport)
				UiFx.activate("confirm", false)
			end
		end)
		if quiet then
			return
		end
		local callback = if confirmed then data.onConfirm else data.onCancel
		if typeof(callback) == "function" then
			task.spawn(function()
				local ok, err = pcall(callback)
				if not ok then
					warn(`[Moments] confirm callback failed: {err}`)
				end
			end)
		end
	end
	confirmClose = function(confirmed: boolean)
		close(confirmed)
	end
	function handle.Close(_self: any)
		close(false, true)
	end
	return handle
end

--- True while a confirmation dialog is open.
function Moments.confirmOpen(): boolean
	return confirmClose ~= nil
end

return Moments
