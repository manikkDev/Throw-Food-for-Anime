--!strict
-- DevPanel - the TEST panel (v4.6, owner's review 7): a playtest tool. It is not
-- a player screen, so it is not in design/ui: a code-built window, shown only
-- when the server says this player is the owner (state.admin) or the session is
-- Studio (state.studio). The server refuses every command for anyone else,
-- whatever the client shows (AdminService), and an owner outside Studio only
-- gets the owner commands (the Events tab) plus the client-side helpers.
--
-- Opened with F2, or the TEST button in the bottom-right corner. The window is
-- docked at the right; drag it by its title bar, DOCK puts it back. Tabs down
-- the left, large buttons, choice chips and steppers where a value is needed,
-- and a status line with the last command sent.
--
-- Every AdminCommand has a control:
--   Throw & Reveal   nextrarity, nextmut, nextsize, luckythrows
--   Economy          yen, allfoods, slots, away
--   Heroes           hero {id, mut, size}, rarityhero, fuseset, clearcarry
--   Training         power, gear, rebirthready, then the real rebirth (ProgressAction)
--   Events           festival, luck, throws, say, announce, resetdaily
--   Store            product, pass
--   Danger           wipe (after a confirmation)
-- Client-only helpers (nothing is sent to the server): teleports (pad, plot,
-- hub), Fast reveal / Low detail through the normal SettingSet path, and local
-- previews of every HUD moment (toasts, reward, level up, zone cross, stat
-- ticks, confirm, announcement, the reveal's final beat).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Make = require(script.Parent.Make)
local Theme = require(script.Parent.Theme)

export type Tools = {
	-- fire any client remote (SettingSet, ProgressAction)
	fire: (remote: string, ...any) -> (),
	-- the HudController (Toast, Reward, LevelUp, ZoneCross, StatTicks, Confirm, Reveal, HideReveal)
	hud: any,
}

local WIN_W, WIN_H = 720, 500
local RAIL_W = 156
local BAR_H = 44
local STATUS_H = 30
local GAP = 10
local CONTENT_W = WIN_W - RAIL_W - 3 * GAP
local TEXT = 18

local DARK = Color3.fromRGB(18, 21, 54)
local SELECTED = Color3.fromRGB(255, 201, 60)

local DevPanel = {}

local gui: ScreenGui? = nil
local window: Frame? = nil
local latest: any = nil
-- labels and chips that follow the state (toggles, the pass marks)
local followers: { () -> () } = {}

-- ------------------------------------------------------------------ data --

local function sortedRarities(): { string }
	local list = {}
	for name in Config.Rarities do
		table.insert(list, name)
	end
	table.sort(list, function(a: string, b: string): boolean
		return (Config.Rarities :: any)[a].Order < (Config.Rarities :: any)[b].Order
	end)
	return list
end

local function names(rows: { any }, key: string): { string }
	local list = {}
	local sorted = table.clone(rows)
	table.sort(sorted, function(a: any, b: any): boolean
		return (a.Order or 0) < (b.Order or 0)
	end)
	for _, row in sorted do
		table.insert(list, row[key])
	end
	return list
end

local RARITIES = sortedRarities()
local MUTATIONS = names(Config.Mutations :: any, "Name")
local SIZES = names(Config.Sizes :: any, "Name")
-- a plausible "1 in N" per rarity for the local reveal preview only
local PREVIEW_ODDS: { [string]: number } = {
	Common = 2,
	Uncommon = 6,
	Rare = 40,
	Epic = 250,
	Legendary = 2500,
	Mythic = 48000,
	Secret = 1250000,
}

type Hero = { id: string, name: string, rarity: string }
local HEROES: { Hero } = {}
for _, row in Config.Characters :: any do
	table.insert(HEROES, { id = row.Id, name = row.Name, rarity = row.Rarity })
end
for _, row in (Config :: any).PremiumCharacters or {} do
	table.insert(HEROES, { id = row.Id, name = row.Name, rarity = "Premium" })
end

local function heroesOf(rarity: string): { Hero }
	local list = {}
	for _, hero in HEROES do
		if hero.rarity == rarity then
			table.insert(list, hero)
		end
	end
	return list
end

local function heroName(id: string): string
	for _, hero in HEROES do
		if hero.id == id then
			return hero.name
		end
	end
	return id
end

local function heroModel(id: string): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local chars = assets and assets:FindFirstChild("Characters")
	return chars and chars:FindFirstChild("Char_" .. id)
end

-- ------------------------------------------------------------ the parts --

local function text(parent: Instance, value: string, props: Make.Props?): TextLabel
	local label = Make.label(parent, value, {
		TextScaled = false,
		TextSize = TEXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 0.4,
	})
	if props then
		for key, v in props do
			(label :: any)[key] = v
		end
	end
	return label
end

local function button(
	parent: Instance,
	label: string,
	color: Color3,
	onClick: () -> (),
	props: Make.Props?
): TextButton
	-- fixed size, never AutomaticSize: an auto-sized button collapsed to a thin bar
	-- (its text measured as zero), so a click had nothing to hit. Width fits the text.
	local width = 150
	local ok, measured = pcall(function()
		return TextService:GetTextSize(label, TEXT, Enum.Font.FredokaOne, Vector2.new(1000, 40)).X
	end)
	if ok then
		width = math.max(96, math.ceil(measured) + 28)
	end
	local b = Make.button(parent, label, color, {
		TextScaled = false,
		TextSize = TEXT,
		Size = UDim2.fromOffset(width, 40),
		AutomaticSize = Enum.AutomaticSize.None,
	})
	if props then
		for key, v in props do
			(b :: any)[key] = v
		end
	end
	b.AutomaticSize = Enum.AutomaticSize.None
	b.Activated:Connect(onClick)
	return b
end

-- a wrapping row of controls
local function flow(parent: Instance, order: number): Frame
	local row = Make.frame(parent, {
		Name = "Row" .. order,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
	})
	local layout = Make.list(row, Enum.FillDirection.Horizontal, 8)
	layout.Wraps = true
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	return row
end

local function heading(parent: Instance, value: string, order: number, note: string?)
	local holder = Make.frame(parent, {
		Name = "Heading" .. order,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, if note then 44 else 26),
		LayoutOrder = order,
	})
	text(holder, value:upper(), {
		Size = UDim2.new(1, 0, 0, 24),
		TextColor3 = SELECTED,
		TextSize = 20,
	})
	if note then
		text(holder, note, {
			Position = UDim2.fromOffset(0, 24),
			Size = UDim2.new(1, 0, 0, 18),
			TextSize = 14,
			TextColor3 = Color3.fromRGB(201, 205, 245),
		})
	end
end

-- one choice out of `options`; each chip fires at once when `onPick` acts, or
-- just selects (the caller reads `get`)
local function chips(
	parent: Instance,
	order: number,
	options: { string },
	colorOf: ((string) -> Color3)?,
	onPick: ((string) -> ())?,
	initial: string?
): () -> string
	local row = flow(parent, order)
	local current = initial or options[1]
	local all: { [string]: TextButton } = {}
	local function paint()
		for value, chip in all do
			local stroke = chip:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = if value == current and not onPick then SELECTED else Make.INK
				stroke.Thickness = if value == current and not onPick then 4 else 3
			end
		end
	end
	for i, value in options do
		local color = if colorOf then colorOf(value) else Make.PANEL
		all[value] = button(row, value, color, function()
			current = value
			paint()
			if onPick then
				onPick(value)
			end
		end, { LayoutOrder = i }) -- width comes from the label: a fixed 96 cut "Uncommon" and "Legendary"
	end
	paint()
	return function(): string
		return current
	end
end

-- a value stepped through `values` with - and +, and a send button
local function stepper(
	parent: Instance,
	order: number,
	caption: string,
	values: { number },
	start: number,
	format: (number) -> string,
	action: string,
	onSend: (number) -> ()
)
	local row = flow(parent, order)
	text(row, caption, { Size = UDim2.fromOffset(150, 40), LayoutOrder = 1 })
	local index = math.max(table.find(values, start) or 1, 1)
	local shown: TextLabel
	local function refresh()
		shown.Text = format(values[index])
	end
	button(row, "-", Make.PANEL, function()
		index = math.max(1, index - 1)
		refresh()
	end, {
		LayoutOrder = 2,
		Size = UDim2.fromOffset(44, 40),
		AutomaticSize = Enum.AutomaticSize.None,
	})
	shown = text(row, "", {
		LayoutOrder = 3,
		Size = UDim2.fromOffset(110, 40),
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundTransparency = 0,
		BackgroundColor3 = DARK,
		TextSize = 20,
	})
	Make.corner(shown, 8)
	button(row, "+", Make.PANEL, function()
		index = math.min(#values, index + 1)
		refresh()
	end, {
		LayoutOrder = 4,
		Size = UDim2.fromOffset(44, 40),
		AutomaticSize = Enum.AutomaticSize.None,
	})
	button(row, action, Make.GOOD, function()
		onSend(values[index])
	end, { LayoutOrder = 5, Size = UDim2.fromOffset(110, 40) })
	refresh()
end

local function textBox(parent: Instance, placeholder: string, width: number, order: number): TextBox
	local box = Instance.new("TextBox")
	box.Name = "Input"
	box.LayoutOrder = order
	box.Size = UDim2.fromOffset(width, 40)
	box.BackgroundColor3 = DARK
	box.BorderSizePixel = 0
	box.Font = Enum.Font.FredokaOne
	box.TextSize = TEXT
	box.TextColor3 = Color3.new(1, 1, 1)
	box.PlaceholderText = placeholder
	box.PlaceholderColor3 = Color3.fromRGB(140, 146, 200)
	box.Text = ""
	box.ClearTextOnFocus = false
	box.TextXAlignment = Enum.TextXAlignment.Left
	Make.corner(box, 8)
	Make.stroke(box, 2, Color3.fromRGB(91, 99, 190))
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.Parent = box
	box.Parent = parent
	return box
end

local function short(n: number): string
	local units = { { 1e15, "Qa" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
	for _, u in units do
		if n >= u[1] then
			local v = n / u[1]
			return (if v == math.floor(v) then tostring(v) else string.format("%.1f", v)) .. u[2]
		end
	end
	return tostring(n)
end

local function rarityColor(name: string): Color3
	return if name == "none" then Make.PANEL else Theme.rarity(name):Lerp(Color3.new(0, 0, 0), 0.25)
end

local function mutationColor(name: string): Color3
	if name == "none" then
		return Make.PANEL
	end
	local ok, color = pcall(Theme.mutation, name)
	return if ok and typeof(color) == "Color3"
		then color:Lerp(Color3.new(0, 0, 0), 0.25)
		else Make.PANEL
end

local function withNone(list: { string }): { string }
	local out = { "none" }
	table.move(list, 1, #list, 2, out)
	return out
end

-- ------------------------------------------------------- client helpers --

local function myPlot(): Instance?
	local map = workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")
	local index = latest and latest.plot
	return if plots and index then plots:FindFirstChild("Plot" .. tostring(index)) else nil
end

local function placeOf(target: Instance): Vector3?
	if target:IsA("BasePart") then
		return target.Position + Vector3.new(0, target.Size.Y / 2, 0)
	elseif target:IsA("Model") then
		local cf, size = target:GetBoundingBox()
		return cf.Position + Vector3.new(0, size.Y / 2, 0)
	end
	return nil
end

-- pivot the local character onto `target` (dropped onto the ground under it)
local function teleport(target: Instance?, what: string): string
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not root:IsA("BasePart") then
		return "no character"
	end
	if not target then
		return `{what}: not found (not streamed in yet?)`
	end
	local at = placeOf(target)
	if not at then
		return `{what}: no position`
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hit = workspace:Raycast(at + Vector3.new(0, 40, 0), Vector3.new(0, -200, 0), params)
	local ground = if hit then hit.Position else at
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	local facing = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	local spot = ground + Vector3.new(0, 4, 0)
	character:PivotTo(CFrame.lookAt(spot, spot + facing))
	return `teleported to {what}`
end

local function hubTarget(): Instance?
	local map = workspace:FindFirstChild("Map")
	local hub = map and map:FindFirstChild("Hub")
	local spawnPoint = (hub and hub:FindFirstChildWhichIsA("SpawnLocation", true))
		or workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	return spawnPoint or hub
end

-- --------------------------------------------------------------- build --

local function build(state: any, run: (command: string, arg: any) -> (), tools: Tools?)
	local studio = state.studio == true
	local screen = Make.screen("TestPanel", 40)
	screen.Enabled = true
	local uiScale = screen:FindFirstChildOfClass("UIScale") :: UIScale

	local opener = Make.button(screen, "TEST", Make.BAD, {
		Name = "TestButton",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -6, 1, -6),
		Size = UDim2.fromOffset(72, 30),
		BackgroundTransparency = 0.2,
	})

	local DOCK = UDim2.new(1, -12, 0.5, 0)
	local frame = Make.frame(screen, {
		Name = "Panel",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = DOCK,
		Size = UDim2.fromOffset(WIN_W, WIN_H),
		BackgroundColor3 = Make.PANEL,
		BackgroundTransparency = 0.04,
		Visible = false,
		Active = true,
	})
	Make.corner(frame, 14)
	Make.stroke(frame, 3, Color3.new(1, 1, 1))

	-- the title bar: drag handle, mode badge, DOCK, close
	local bar = Make.frame(frame, {
		Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, BAR_H),
		BackgroundColor3 = Make.BAD,
		Active = true,
	})
	Make.corner(bar, 14)
	text(bar, "TEST PANEL", {
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(0, 160, 1, 0),
		TextSize = 22,
		TextStrokeTransparency = 0,
	})
	local mode = if studio then "STUDIO" else "OWNER"
	if state.mock then
		mode ..= "  -  saving is OFF"
	end
	text(bar, mode .. "  -  drag me", {
		Position = UDim2.fromOffset(170, 0),
		Size = UDim2.new(0, 300, 1, 0),
		TextSize = 15,
	})
	button(bar, "DOCK", Make.PANEL, function()
		frame.Position = DOCK
	end, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -58, 0.5, 0),
		Size = UDim2.fromOffset(76, 32),
		AutomaticSize = Enum.AutomaticSize.None,
	})
	button(bar, "X", Make.INK, function()
		frame.Visible = false
	end, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(40, 32),
		AutomaticSize = Enum.AutomaticSize.None,
	})
	local dragFrom: Vector2? = nil
	local dragStart = frame.Position
	bar.InputBegan:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			dragFrom = Vector2.new(input.Position.X, input.Position.Y)
			dragStart = frame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragFrom = nil
				end
			end)
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		local from = dragFrom
		local kind = input.UserInputType
		if
			from and (kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.Touch)
		then
			local d = (Vector2.new(input.Position.X, input.Position.Y) - from)
				/ math.max(uiScale.Scale, 0.1)
			frame.Position = dragStart + UDim2.fromOffset(d.X, d.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragFrom = nil
		end
	end)

	-- the status line
	local status = text(frame, "Ready. Server answers arrive as toasts.", {
		Name = "Status",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, GAP, 1, -4),
		Size = UDim2.new(1, -2 * GAP, 0, STATUS_H - 6),
		TextSize = 15,
		BackgroundTransparency = 0,
		BackgroundColor3 = DARK,
	})
	Make.corner(status, 6)
	local statusPad = Instance.new("UIPadding")
	statusPad.PaddingLeft = UDim.new(0, 8)
	statusPad.Parent = status
	local function say(line: string)
		status.Text = `{os.date("%H:%M:%S")}   {line}`
	end
	local function send(command: string, arg: any)
		run(command, arg)
		local shownArg = if typeof(arg) == "table"
			then `{arg.id} {arg.mut or "-"} {arg.size or "-"}`
			elseif arg == nil then ""
			else tostring(arg)
		say(`sent: {command} {shownArg}`)
	end
	local function fire(remote: string, ...: any)
		if tools then
			tools.fire(remote, ...)
			local parts = {}
			for _, v in { ... } do
				table.insert(parts, tostring(v))
			end
			say(`sent: {remote} {table.concat(parts, " ")}`)
		else
			say("not wired: no remote access")
		end
	end
	local hud = tools and tools.hud
	local function moment(label: string, call: () -> ())
		if not hud then
			say("not wired: no HudController")
			return
		end
		local ok, err = pcall(call)
		say(if ok then `preview: {label}` else `preview {label} failed: {err}`)
	end

	-- the rail and the pages
	local rail = Make.frame(frame, {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(GAP, BAR_H + GAP),
		Size = UDim2.new(0, RAIL_W, 1, -(BAR_H + STATUS_H + 2 * GAP)),
	})
	Make.list(rail, Enum.FillDirection.Vertical, 6)
	local pages: { [string]: ScrollingFrame } = {}
	local tabs: { [string]: TextButton } = {}
	local tabOrder: { string } = {}
	local function selectTab(name: string)
		for key, page in pages do
			page.Visible = key == name
			tabs[key].BackgroundColor3 = if key == name then SELECTED else DARK
			tabs[key].TextColor3 = if key == name then Make.INK else Color3.new(1, 1, 1)
			tabs[key].TextStrokeTransparency = if key == name then 1 else 0
		end
	end
	local function page(name: string): ScrollingFrame
		local scroll = Instance.new("ScrollingFrame")
		scroll.Name = "Page_" .. name:gsub("%W", "")
		scroll.BackgroundColor3 = DARK
		scroll.BackgroundTransparency = 0.35
		scroll.BorderSizePixel = 0
		scroll.Position = UDim2.fromOffset(RAIL_W + 2 * GAP, BAR_H + GAP)
		scroll.Size = UDim2.new(0, CONTENT_W, 1, -(BAR_H + STATUS_H + 2 * GAP))
		scroll.CanvasSize = UDim2.new()
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.ScrollBarThickness = 8
		scroll.ScrollingDirection = Enum.ScrollingDirection.Y
		scroll.Visible = false
		Make.corner(scroll, 10)
		Make.list(scroll, Enum.FillDirection.Vertical, 8)
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 10)
		pad.PaddingBottom = UDim.new(0, 12)
		pad.PaddingLeft = UDim.new(0, 12)
		pad.PaddingRight = UDim.new(0, 16)
		pad.Parent = scroll
		scroll.Parent = frame
		pages[name] = scroll
		table.insert(tabOrder, name)
		tabs[name] = button(rail, name, DARK, function()
			selectTab(name)
		end, {
			LayoutOrder = #tabOrder,
			Size = UDim2.new(1, 0, 0, 40),
			AutomaticSize = Enum.AutomaticSize.None,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = 17,
		})
		return scroll
	end

	-- a toggle that sends SettingSet and shows the state the next snapshot says
	local function settingToggle(parent: Instance, order: number, key: string, caption: string)
		local row = flow(parent, order)
		local b = button(row, caption, Make.PANEL, function()
			local settings = latest and latest.settings
			local now = settings ~= nil and settings[key] == true
			fire("SettingSet", key, not now)
		end, { Size = UDim2.fromOffset(240, 40), AutomaticSize = Enum.AutomaticSize.None })
		table.insert(followers, function()
			local settings = latest and latest.settings
			local on = settings ~= nil and settings[key] == true
			b.Text = `{caption}: {if on then "ON" else "OFF"}`
			b.BackgroundColor3 = if on then Make.GOOD else Make.PANEL
		end)
	end

	local selectedHero = HEROES[1] and HEROES[1].id or ""

	if studio then
		-- ---------------------------------------------- Throw & Reveal --
		local p = page("Throw & Reveal")
		heading(p, "Next throw: rarity", 1, "The next throw lands this rarity (one throw).")
		chips(p, 2, RARITIES, rarityColor, function(r: string)
			send("nextrarity", r)
		end)
		heading(p, "Next throw: mutation", 3)
		chips(p, 4, withNone(MUTATIONS), mutationColor, function(m: string)
			send("nextmut", m)
		end)
		heading(p, "Next throw: size", 5)
		chips(p, 6, withNone(SIZES), nil, function(s: string)
			send("nextsize", s)
		end)
		heading(p, "Lucky throws", 7)
		stepper(p, 8, "Add", { 1, 3, 5, 10, 25, 100 }, 5, tostring, "GIVE", function(n: number)
			send("luckythrows", n)
		end)
		heading(p, "Reveal settings", 9)
		settingToggle(p, 10, "fastReveal", "Fast reveal")

		-- ----------------------------------------------------- Economy --
		p = page("Economy")
		heading(p, "Yen", 1)
		local yenRow = flow(p, 2)
		for i, amount in { 1e4, 1e6, 1e9, 1e12, 1e15 } do
			button(yenRow, `+{short(amount)}`, Make.BUY, function()
				send("yen", amount)
			end, { LayoutOrder = i, Size = UDim2.fromOffset(84, 40) })
		end
		heading(p, "Foods", 3)
		local foodRow = flow(p, 4)
		button(foodRow, "Unlock every food", Make.GOOD, function()
			send("allfoods", nil)
		end)
		heading(p, "Plot slots", 5)
		local slots = {}
		for n = Config.Plot.StartSlots, Config.Plot.MaxSlots do
			table.insert(slots, n)
		end
		stepper(p, 6, "Slots", slots, Config.Plot.MaxSlots, tostring, "SET", function(n: number)
			send("slots", n)
		end)
		heading(p, "Offline earnings", 7, "Banks time away; rejoin to see Welcome Back.")
		stepper(
			p,
			8,
			"Away for",
			{ 600, 3600, 10800, 28800, 86400 },
			10800,
			function(s: number): string
				return if s < 3600 then `{s // 60} min` else `{s // 3600} h`
			end,
			"SEND",
			function(s: number)
				send("away", s)
			end
		)

		-- ------------------------------------------------------ Heroes --
		p = page("Heroes")
		heading(p, "Grant a hero", 1, "Pick a hero, a mutation and a size, then GRANT.")
		local searchRow = flow(p, 2)
		local search = textBox(searchRow, "search heroes...", 300, 1)
		local picked = text(
			searchRow,
			"",
			{ LayoutOrder = 2, Size = UDim2.fromOffset(160, 40), TextSize = 15 }
		)
		local list = Instance.new("ScrollingFrame")
		list.Name = "HeroList"
		list.LayoutOrder = 3
		list.Size = UDim2.new(1, 0, 0, 186)
		list.BackgroundColor3 = DARK
		list.BorderSizePixel = 0
		list.CanvasSize = UDim2.new()
		list.AutomaticCanvasSize = Enum.AutomaticSize.Y
		list.ScrollBarThickness = 8
		Make.corner(list, 8)
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.fromOffset(156, 34)
		grid.CellPadding = UDim2.fromOffset(6, 6)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = list
		local gridPad = Instance.new("UIPadding")
		gridPad.PaddingTop = UDim.new(0, 6)
		gridPad.PaddingLeft = UDim.new(0, 6)
		gridPad.Parent = list
		list.Parent = p
		local heroButtons: { [string]: TextButton } = {}
		local function paintHeroes()
			for id, b in heroButtons do
				local stroke = b:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Color = if id == selectedHero then SELECTED else Make.INK
					stroke.Thickness = if id == selectedHero then 4 else 2
				end
			end
			picked.Text = `picked: {heroName(selectedHero)}`
		end
		for i, hero in HEROES do
			local color = if hero.rarity == "Premium"
				then Theme.PREMIUM
				else Theme.rarity(hero.rarity)
			heroButtons[hero.id] = button(
				list,
				hero.name,
				color:Lerp(Color3.new(0, 0, 0), 0.35),
				function()
					selectedHero = hero.id
					paintHeroes()
				end,
				{ LayoutOrder = i, TextSize = 14, AutomaticSize = Enum.AutomaticSize.None }
			)
		end
		search:GetPropertyChangedSignal("Text"):Connect(function()
			local q = search.Text:lower()
			for _, hero in HEROES do
				heroButtons[hero.id].Visible = q == "" or hero.name:lower():find(q, 1, true) ~= nil
			end
		end)
		paintHeroes()
		heading(p, "Mutation", 4)
		local getMut = chips(p, 5, withNone(MUTATIONS), mutationColor)
		heading(p, "Size", 6)
		local getSize = chips(p, 7, withNone(SIZES))
		local grantRow = flow(p, 8)
		button(grantRow, "GRANT HERO", Make.GOOD, function()
			local mut, size = getMut(), getSize()
			send("hero", {
				id = selectedHero,
				mut = if mut ~= "none" then mut else nil,
				size = if size ~= "none" then size else nil,
			})
		end, { Size = UDim2.fromOffset(180, 44) })
		button(grantRow, "FUSE SET of picked", Make.INFO, function()
			send("fuseset", selectedHero)
		end, { Size = UDim2.fromOffset(200, 44) })
		heading(p, "A random hero of a rarity", 9)
		chips(p, 10, RARITIES, rarityColor, function(r: string)
			send("rarityhero", r)
		end)
		heading(p, "Carrying", 11)
		local carryRow = flow(p, 12)
		button(carryRow, "Clear my carried hero", Make.BAD, function()
			send("clearcarry", nil)
		end)

		-- ------------------------------------------ Training & Rebirth --
		p = page("Training & Rebirth")
		heading(p, "Power", 1)
		local powerRow = flow(p, 2)
		for i, amount in { 500, 1e5, 1e7, 2e8, 1e9, 1e12 } do
			button(powerRow, `+{short(amount)}`, Make.INFO, function()
				send("power", amount)
			end, { LayoutOrder = i, Size = UDim2.fromOffset(84, 40) })
		end
		heading(p, "Gear tier", 3)
		local tiers = {}
		for n = 1, #Config.Training.Equipment do
			table.insert(tiers, n)
		end
		stepper(p, 4, "Tier", tiers, 1, tostring, "SET", function(n: number)
			send("gear", n)
		end)
		heading(p, "Rebirth", 5, "READY gives the power and yen the next rebirth needs.")
		local rebirthRow = flow(p, 6)
		button(rebirthRow, "Make rebirth ready", Make.BUY, function()
			send("rebirthready", nil)
		end, { Size = UDim2.fromOffset(200, 44) })
		button(rebirthRow, "REBIRTH NOW", Color3.fromRGB(168, 85, 247), function()
			fire("ProgressAction", "rebirth")
		end, { Size = UDim2.fromOffset(180, 44) })
	end

	-- -------------------------------------------------------- Events --
	-- (the owner's commands: also available outside Studio)
	do
		local p = page("Events")
		heading(p, "Festival Hour", 1)
		stepper(
			p,
			2,
			"Minutes",
			{ 1, 2, 5, 10, 15, 30, 60, 120 },
			5,
			tostring,
			"START",
			function(n: number)
				send("festival", n)
			end
		)
		heading(p, "Server luck", 3)
		local luckRow = flow(p, 4)
		button(luckRow, "Raise server luck one step", Make.GOOD, function()
			send("luck", nil)
		end)
		heading(p, "Lucky throws for everyone", 5)
		stepper(p, 6, "Each", { 1, 3, 5, 10, 25, 100 }, 3, tostring, "GIVE ALL", function(n: number)
			send("throws", n)
		end)
		heading(p, "Server message", 7, "Filtered, then shown to everyone as an announcement.")
		local sayRow = flow(p, 8)
		local box = textBox(sayRow, "type a message...", 360, 1)
		button(sayRow, "SAY", Make.GOOD, function()
			if box.Text ~= "" then
				send("say", box.Text:sub(1, 120))
			end
		end, { LayoutOrder = 2, Size = UDim2.fromOffset(90, 40) })
		if studio then
			heading(p, "Test catch announcement", 9)
			chips(p, 10, RARITIES, rarityColor, function(r: string)
				send("announce", r)
			end)
			heading(p, "Daily", 11)
			local dailyRow = flow(p, 12)
			button(dailyRow, "Reset daily reward + gifts", Make.BUY, function()
				send("resetdaily", nil)
			end)
		end
	end

	if studio then
		-- -------------------------------------------------------- Store --
		local p = page("Store")
		heading(p, "Grant a product", 1, "Runs the real grant, as if bought.")
		local products = {}
		for _, row in (Config :: any).Monetization.Products do
			table.insert(products, row.Key)
		end
		local productRow = flow(p, 2)
		for i, key in products do
			button(productRow, key, Make.BUY, function()
				send("product", key)
			end, { LayoutOrder = i, TextSize = 15 })
		end
		heading(p, "Toggle a game pass", 3, "Green = granted for testing.")
		local passRow = flow(p, 4)
		for i, row in (Config :: any).Monetization.Passes do
			local key = row.Key
			local b = button(passRow, key, Make.PANEL, function()
				send("pass", key)
			end, { LayoutOrder = i, TextSize = 15 })
			table.insert(followers, function()
				local granted = latest and latest.grantedPasses
				local on = typeof(granted) == "table" and granted[key] == true
				b.BackgroundColor3 = if on then Make.GOOD else Make.PANEL
			end)
		end
	end

	-- ---------------------------------------------------- UI moments --
	do
		local p = page("UI moments")
		heading(p, "Toasts", 1, "Local previews: nothing is sent to the server.")
		local toastRow = flow(p, 2)
		for i, kind in { "info", "good", "bad", "reward" } do
			button(toastRow, kind, (Theme.TOAST :: any)[kind] or Make.PANEL, function()
				moment(`toast {kind}`, function()
					hud:Toast(`A {kind} toast, about this long.`, kind)
				end)
			end, { LayoutOrder = i, Size = UDim2.fromOffset(96, 40) })
		end
		heading(p, "Popups", 3)
		local popRow = flow(p, 4)
		local function pickedHero(): (string, any)
			local id = selectedHero
			for _, hero in HEROES do
				if hero.id == id then
					return id, hero
				end
			end
			return id, nil
		end
		button(popRow, "Reward: hero", Make.BUY, function()
			moment("reward hero", function()
				local id, hero = pickedHero()
				hud:Reward({
					title = "NEW HERO!",
					name = heroName(id),
					model = heroModel(id),
					rarity = hero and hero.rarity ~= "Premium" and hero.rarity or nil,
					chips = { { text = "TITAN" }, { text = "+1.2K/s", icon = "IconYen" } },
				})
			end)
		end)
		button(popRow, "Reward: item", Make.BUY, function()
			moment("reward item", function()
				hud:Reward({
					title = "DAILY REWARD",
					name = "+25K Yen",
					image = "IconYenBig",
					sub = "Day 3",
				})
			end)
		end)
		button(popRow, "Level up: rank", Make.GOOD, function()
			moment("level up", function()
				hud:LevelUp("RANK UP!", "Shinobi", nil)
			end)
		end)
		button(popRow, "Level up: rebirth", Color3.fromRGB(168, 85, 247), function()
			moment("rebirth banner", function()
				hud:LevelUp("REBIRTH 2", "You evolved!", Color3.fromRGB(168, 85, 247))
			end)
		end)
		button(popRow, "Stat ticks", Make.INFO, function()
			moment("stat ticks", function()
				hud:StatTicks({
					title = "REBIRTH 2",
					rows = {
						{ label = "Income", from = "+50%", to = "+100%", icon = "IconYenBig" },
						{ label = "Luck", from = "+10%", to = "+20%", icon = "IconLuckBig" },
						{ label = "Slots", from = "8", to = "10", icon = "IconPlaceBig" },
					},
				})
			end)
		end)
		button(popRow, "Confirm: yen", Make.GOOD, function()
			moment("confirm yen", function()
				hud:Confirm({
					title = "UPGRADE GEAR",
					name = "Iron Dumbbells",
					icon = "IconPowerBig",
					tag = "TIER 3",
					rows = {
						{ label = "Power per rep", from = "x2", to = "x3", icon = "IconPowerBig" },
					},
					cost = 125000,
					costKind = "yen",
					canAfford = true,
					confirmText = "BUY",
				})
			end)
		end)
		button(popRow, "Confirm: robux", Theme.PREMIUM, function()
			moment("confirm robux", function()
				hud:Confirm({
					title = "BUY SLOT",
					name = "Plot slot 9",
					icon = "IconPlaceBig",
					rows = { { label = "Hero slots", from = "8", to = "9", icon = "IconPlaceBig" } },
					cost = 49,
					costKind = "robux",
					canAfford = false,
					confirmText = "BUY",
				})
			end)
		end)
		heading(p, "Zone cross banner", 5)
		local zoneRow = flow(p, 6)
		for i, zone in (Config :: any).Zones do
			button(zoneRow, `{i}`, Make.PANEL, function()
				moment(`zone {zone.Name}`, function()
					hud:ZoneCross(
						zone.Name,
						Color3.fromHSV((i - 1) / #(Config :: any).Zones, 0.6, 1),
						i
					)
				end)
			end, {
				LayoutOrder = i,
				Size = UDim2.fromOffset(48, 40),
				AutomaticSize = Enum.AutomaticSize.None,
			})
		end
		heading(p, "Announcement bar", 7)
		local annRow = flow(p, 8)
		button(annRow, "Catch (picked hero)", Make.INFO, function()
			moment("announcement", function()
				local id, hero = pickedHero()
				local rarity = if hero and hero.rarity ~= "Premium"
					then hero.rarity
					else "Legendary"
				hud:_announce({
					kind = "catch",
					rarity = rarity,
					text = `{Players.LocalPlayer.DisplayName} caught TITAN GALAXY {heroName(id)}  (1 in 250,000)`,
				})
			end)
		end)
		button(annRow, "Festival", Make.BUY, function()
			moment("festival announcement", function()
				hud:_announce({
					kind = "festival",
					text = "Festival Hour! Luck is up for 5 minutes",
				})
			end)
		end)
		button(annRow, "Server luck", Make.GOOD, function()
			moment("luck announcement", function()
				hud:_announce({ kind = "luck", text = "Server luck x2 for 15 minutes" })
			end)
		end)
		heading(
			p,
			"Reveal final beat (card + top odds)",
			9,
			"A random hero of the rarity; closes after 5 s."
		)
		chips(p, 10, RARITIES, rarityColor, function(r: string)
			moment(`reveal {r}`, function()
				local pool = heroesOf(r)
				local hero = pool[math.random(1, math.max(#pool, 1))]
				if not hero then
					return
				end
				hud:Reveal({
					id = hero.id,
					rarity = r,
					income = 1234 * (PREVIEW_ODDS[r] or 1),
					oneInN = PREVIEW_ODDS[r] or 2500,
					mut = if math.random() < 0.5 then MUTATIONS[1] else nil,
					size = if math.random() < 0.5 then SIZES[1] else nil,
					isNew = true,
				})
				task.delay(5, function()
					hud:HideReveal()
				end)
			end)
		end)
	end

	-- --------------------------------------------------------- World --
	do
		local p = page("World")
		heading(p, "Teleport", 1, "Moves only your character (client side).")
		local tpRow = flow(p, 2)
		button(tpRow, "My throw pad", Make.INFO, function()
			local plot = myPlot()
			say(teleport(plot and plot:FindFirstChild("ThrowPad"), "my throw pad"))
		end, { Size = UDim2.fromOffset(160, 44) })
		button(tpRow, "My plot", Make.INFO, function()
			local plot = myPlot()
			say(teleport(plot and (plot:FindFirstChild("Pedestals") or plot), "my plot"))
		end, { Size = UDim2.fromOffset(140, 44) })
		button(tpRow, "The hub", Make.INFO, function()
			say(teleport(hubTarget(), "the hub"))
		end, { Size = UDim2.fromOffset(140, 44) })
		heading(p, "Settings", 3, "Sent through the normal SettingSet path.")
		settingToggle(p, 4, "fastReveal", "Fast reveal")
		settingToggle(p, 5, "lowDetail", "Low detail")
	end

	if studio then
		-- -------------------------------------------------------- Danger --
		local p = page("Danger")
		heading(p, "Wipe my profile", 1, "Resets everything on this profile. Asks first.")
		local wipeRow = flow(p, 2)
		local armed = 0
		local wipe: TextButton
		wipe = button(wipeRow, "WIPE MY PROFILE", Make.BAD, function()
			if hud then
				hud:Confirm({
					title = "WIPE PROFILE",
					name = "Everything resets",
					icon = "IconClose",
					rows = { { label = "Yen, power, heroes, slots", to = "gone" } },
					confirmText = "WIPE",
					canAfford = true,
					onConfirm = function()
						send("wipe", nil)
					end,
				})
				return
			end
			-- no HUD: two taps within 3 s
			if os.clock() - armed < 3 then
				armed = 0
				wipe.Text = "WIPE MY PROFILE"
				send("wipe", nil)
			else
				armed = os.clock()
				wipe.Text = "TAP AGAIN TO WIPE"
				task.delay(3, function()
					wipe.Text = "WIPE MY PROFILE"
				end)
			end
		end, { Size = UDim2.fromOffset(240, 48) })
	end

	selectTab(tabOrder[1])

	local function toggle()
		frame.Visible = not frame.Visible
	end
	opener.Activated:Connect(toggle)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and input.KeyCode == Enum.KeyCode.F2 then
			toggle()
		end
	end)

	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = screen
	window = frame
end

--- Build the panel the first time a snapshot says this player may use it,
--- and keep its toggles in step with each snapshot. `run(command, arg)` fires
--- AdminCommand; `tools` gives the client helpers their remotes and the HUD.
function DevPanel.update(state: any, run: (command: string, arg: any) -> (), tools: Tools?)
	latest = state
	local allowed = state.studio == true or state.admin == true
	if allowed and not gui then
		build(state, run, tools)
	end
	if gui then
		gui.Enabled = allowed
	end
	if window and not allowed then
		window.Visible = false
	end
	for _, follow in followers do
		follow()
	end
end

return DevPanel
