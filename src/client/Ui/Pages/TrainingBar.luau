--!strict
-- TrainingBar - shown while the player trains on the dojo pad: rank
-- progress, power per rep, Stop, and a "new gear" prompt once the next gear
-- can be afforded. A HUD overlay, not a page.
--
-- Every rep pops a "+N" over the character and bumps the power line; a new
-- rank pops its name and flashes "RANK UP!" across the HUD.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Progress = require(ReplicatedStorage.Shared.Core.Progress)
local Screens = require(script.Parent.Parent.Screens)
local Types = require(script.Parent.Types)

local TrainingBar = { name = "TrainingBar", overlay = true } :: Types.Page

local POWER_BLUE = Color3.fromHex("5CC8FF")
local RISE = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local ctx: Types.Ctx
local gui: ScreenGui
local lastPower: number? = nil
local lastRank: number? = nil

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
		if lastRank and rank > lastRank then
			local name = Config.Training.Ranks[rank].Name:upper()
			Screens.label(gui, "RankName").Text = name
			Screens.pop(Screens.label(gui, "RankName"), 1.25)
			ctx.banner(`RANK UP!  {name}`)
		end
	end
	lastPower = power
	lastRank = rank
end

function TrainingBar.render(state: any)
	local training = state.training == true
	if gui.Enabled ~= training then
		gui.Enabled = training
	end
	if not training then
		return
	end
	local rank = Progress.rank(Config, state.power)
	local gear = Config.Training.Equipment[state.gear]
	local nextRank = Config.Training.Ranks[rank.index + 1]
	local double = state.passes ~= nil and state.passes.DoubleTraining == true
	Screens.label(gui, "RankName").Text = rank.name:upper()
	Screens.label(gui, "GearName").Text = if gear then `on {gear.Name}` else ""
	Screens.fill(Screens.frame(Screens.frame(gui, "ProgressBar"), "Fill"), rank.progress)
	Screens.label(gui, "ProgressText").Text = if rank.nextPower and nextRank
		then `{Format.short(state.power)} / {Format.short(rank.nextPower)}  ->  {nextRank.Name:upper()}`
		else `{Format.short(state.power)}  -  TOP RANK`
	Screens.label(gui, "PowerPerRep").Text =
		`+{Format.short(Progress.powerPerRep(Config, state.gear, double))} power per rep`

	local cost = Progress.nextGearCost(Config, state.gear)
	local nextGear = Config.Training.Equipment[state.gear + 1]
	local prompt = Screens.button(gui, "UpgradePrompt")
	prompt.Visible = cost ~= nil and nextGear ~= nil and state.yen >= cost
	if cost and nextGear then
		Screens.label(prompt, "UpgradeText").Text = `NEW GEAR: {nextGear.Name} {Format.short(cost)}`
	end
end

-- power climbs every rep: follow it while training
TrainingBar.tick = TrainingBar.render

function TrainingBar.init(context: Types.Ctx)
	ctx = context
	gui = Screens.get("TrainingBar")
	gui.Enabled = false
	for _, name in { "RankName", "GearName", "ProgressText", "PowerPerRep", "UpgradeText" } do
		Screens.label(gui, name).Text = ""
	end
	Screens.button(gui, "UpgradePrompt").Activated:Connect(function()
		ctx.fire("ShopBuy", "gear")
	end)
	Screens.button(gui, "StopButton").Activated:Connect(function()
		ctx.fire("TrainSet", false)
	end)
	ctx.ticked(onTick)
end

return TrainingBar
