--!strict
-- TrainingBar - shown while the player trains at a station: rank, progress,
-- power per rep, the exit X. A HUD overlay, not a page. The station's own name
-- is NOT repeated here (the world shows it; TrainingController hides the
-- StationTitle and the station's world plate).
--
-- Every rep pops a "+N" over the character, slides the bar to its new fill,
-- flashes the bar's frame and pops the numbers; a new rank pops its name and
-- raises the top banner (ctx.levelUp). When the next gear tier is affordable a
-- pulsing gold UPGRADE READY chip says where to buy it (the gear stand, F),
-- with a chime the first time; a new piece of gear (bought anywhere) is an
-- unboxing reward (ctx.reward) with its model, never a banner or a toast.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Progress = require(ReplicatedStorage.Shared.Core.Progress)
local Screens = require(script.Parent.Parent.Screens)
local Types = require(script.Parent.Types)

local TrainingBar = { name = "TrainingBar", overlay = true } :: Types.Page

local POWER_BLUE = Color3.fromHex("5CC8FF")
local GEAR_GOLD = Color3.fromHex("FFC83D")
local RISE = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FILL = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local GLOW = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local ctx: Types.Ctx
local gui: ScreenGui
local lastPower: number? = nil
local lastRank: number? = nil
local lastGear: number? = nil
local fillTween: Tween? = nil
local barStroke: UIStroke? = nil
local barStrokeColor = Color3.new(1, 1, 1)
local barStrokeThick = 2
local readyFor: number? = nil -- the gear tier the UPGRADE READY chime last rang for
local pulse: Tween? = nil

-- the model template of gear tier `tier` (ReplicatedStorage.Assets.Gear.Equip_<name>)
local function gearModel(tier: number): Instance?
	local row = Config.Training.Equipment[tier]
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Gear")
	if not row or not folder then
		return nil
	end
	return folder:FindFirstChild("Equip_" .. string.gsub(string.lower(row.Name), "%s+", "_"))
end

-- the UPGRADE READY chip: shown pulsing, or hidden
local function showReady(on: boolean)
	local chip = Screens.frame(gui, "UpgradeReady")
	if chip.Visible == on then
		return
	end
	chip.Visible = on
	local scale = chip:FindFirstChild("Pulse")
	if not scale then
		local made = Instance.new("UIScale")
		made.Name = "Pulse"
		made.Parent = chip
		scale = made
	end
	if pulse then
		pulse:Cancel()
		pulse = nil
	end
	local uiScale = scale :: UIScale
	uiScale.Scale = 1
	if on then
		Screens.pop(Screens.image(chip, "ReadyIcon"), 1.4)
		local t = TweenService:Create(
			uiScale,
			TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Scale = 1.05 }
		)
		pulse = t
		t:Play()
	end
end
-- the bar slides to its new fill (Screens.fill's geometry, tweened)
local function slideFill(fraction: number)
	local fill = Screens.frame(Screens.frame(gui, "ProgressBar"), "Fill")
	local f = math.clamp(fraction, 0, 1)
	fill.Visible = f > 0.005
	if fillTween then
		fillTween:Cancel()
	end
	local goal = UDim2.new(f, -6 * f, 1, -6)
	if not gui.Enabled then
		fill.Size = goal
		return
	end
	local tween = TweenService:Create(fill, FILL, { Size = goal })
	fillTween = tween
	tween:Play()
end

-- the bar's white frame flashes power blue and settles back
local function glow()
	local stroke = barStroke
	if not stroke then
		return
	end
	stroke.Color = POWER_BLUE
	stroke.Thickness = barStrokeThick + 2
	TweenService:Create(stroke, GLOW, { Color = barStrokeColor, Thickness = barStrokeThick }):Play()
end

-- "+N" that rises from the character's head and fades. Built in code: it is
-- a moment in the world, not a screen (the authored effect comes in section 4).
local function popOver(text: string)
	local character = Players.LocalPlayer.Character
	local head = character and character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local board = Instance.new("BillboardGui")
	board.Name = "RepPop"
	board.Size = UDim2.fromScale(5, 1.5)
	board.StudsOffsetWorldSpace = Vector3.new(math.random(-10, 10) / 10, 2.2, 0)
	board.AlwaysOnTop = true
	board.Adornee = head
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = POWER_BLUE
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = board
	board.Parent = head
	TweenService:Create(board, RISE, {
		StudsOffsetWorldSpace = board.StudsOffsetWorldSpace + Vector3.new(0, 2.6, 0),
	}):Play()
	TweenService:Create(label, RISE, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(board, 0.9)
end

-- every server tick: a rep landed if power went up while training
local function onTick(_yen: number, power: number)
	local state = ctx.state()
	local rank = Progress.rank(Config, power).index
	if state and state.training == true and lastPower and power > lastPower then
		popOver(`+{Format.short(power - lastPower)}`)
		Screens.pop(Screens.label(gui, "PowerPerRep"), 1.12)
		Screens.pop(Screens.label(gui, "ProgressText"), 1.15)
		glow()
		if lastRank and rank > lastRank then
			local name = Config.Training.Ranks[rank].Name:upper()
			Screens.label(gui, "RankName").Text = name
			Screens.pop(Screens.label(gui, "RankName"), 1.35)
			ctx.levelUp("RANK UP!", name, POWER_BLUE)
		end
	end
	lastPower = power
	lastRank = rank
end

function TrainingBar.render(state: any)
	-- a new piece of gear (bought anywhere): the unboxing reward with its model
	if lastGear and state.gear > lastGear then
		local bought = Config.Training.Equipment[state.gear]
		if bought then
			ctx.reward({
				title = "NEW GEAR!",
				name = bought.Name,
				sub = `+{Format.short(bought.PowerPerRep)} Power per rep`,
				chips = {
					{
						text = `+{Format.short(bought.PowerPerRep)} Power per rep`,
						icon = "IconPower",
					},
					{
						text = `Tier {state.gear} of {#Config.Training.Equipment}`,
						icon = "IconTrain",
					},
				},
				model = gearModel(state.gear),
				image = "IconTrainBig",
				color = GEAR_GOLD,
			})
		end
	end
	lastGear = state.gear
	local training = state.training == true
	if gui.Enabled ~= training then
		gui.Enabled = training
	end
	if not training then
		return
	end
	local rank = Progress.rank(Config, state.power)
	local nextRank = Config.Training.Ranks[rank.index + 1]
	local double = state.passes ~= nil and state.passes.DoubleTraining == true
	Screens.label(gui, "RankName").Text = rank.name:upper()
	slideFill(rank.progress)
	Screens.label(gui, "ProgressText").Text = if rank.nextPower and nextRank
		then `{Format.short(state.power)} / {Format.short(rank.nextPower)}  ->  {nextRank.Name:upper()}`
		else `{Format.short(state.power)}  -  TOP RANK`
	Screens.label(gui, "PowerPerRep").Text =
		`+{Format.short(Progress.powerPerRep(Config, state.gear, double))} power per rep`

	local cost = Progress.nextGearCost(Config, state.gear)
	local ready = cost ~= nil and state.yen >= cost
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	Screens.label(gui, "UpgradeText").Text = if touch
		then "Leave training, tap the gear stand"
		else "Leave training, press F at the gear stand"
	showReady(ready)
	if ready and readyFor ~= state.gear then
		readyFor = state.gear
		Screens.sound("upgrade_ready")
	end
end

-- power climbs every rep: follow it while training
TrainingBar.tick = TrainingBar.render

function TrainingBar.init(context: Types.Ctx)
	ctx = context
	gui = Screens.get("TrainingBar")
	gui.Enabled = false
	for _, name in { "RankName", "ProgressText", "PowerPerRep", "UpgradeText" } do
		Screens.label(gui, name).Text = ""
	end
	-- the training mini-game HUD (UI v4): the station's controller fills these in;
	-- they start empty, and PERFECT! and the combo start hidden
	Screens.label(gui, "StationTitle").Text = ""
	Screens.label(gui, "RepPower").Text = ""
	Screens.label(gui, "Combo").Text = ""
	Screens.label(gui, "Combo").Visible = false
	Screens.label(gui, "PerfectLabel").Visible = false
	local bar = Screens.frame(gui, "ProgressBar")
	barStroke = bar:FindFirstChildOfClass("UIStroke")
	if barStroke then
		barStrokeColor = barStroke.Color
		barStrokeThick = barStroke.Thickness
	end
	Screens.frame(gui, "UpgradeReady").Visible = false
	-- the round red X leaves the station (UI v4: replaces the STOP button)
	Screens.button(gui, "ExitButton").Activated:Connect(function()
		ctx.fire("TrainSet", false)
	end)
	ctx.ticked(onTick)
end

return TrainingBar
