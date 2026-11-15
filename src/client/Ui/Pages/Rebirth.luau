--!strict
-- Rebirth - the next tier: what it needs, what it gives, what is kept and
-- lost (those two lists are fixed text in the tree). The server decides.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Progress = require(ReplicatedStorage.Shared.Core.Progress)
local Screens = require(script.Parent.Parent.Screens)
local Types = require(script.Parent.Types)

local Rebirth = { name = "Rebirth" } :: Types.Page

local ctx: Types.Ctx
local gui: ScreenGui

local function percent(fraction: number): number
	return math.floor(fraction * 100 + 0.5)
end

function Rebirth.render(state: any)
	local tier = Progress.nextRebirth(Config, state.rebirth)
	local powerBar = Screens.frame(gui, "PowerBar")
	local yenBar = Screens.frame(gui, "YenBar")
	local confirm = Screens.button(gui, "ConfirmButton")
	Screens.label(gui, "CurrentRebirth").Text = `You are at Rebirth {state.rebirth}`
	if not tier then
		Screens.label(gui, "NextTier").Text = "MAX REBIRTH"
		Screens.label(gui, "PowerReqText").Text = "MAX"
		Screens.label(gui, "YenReqText").Text = "MAX"
		Screens.label(gui, "RewardIncome").Text = "This is the highest rebirth"
		Screens.label(gui, "RewardLuck").Text = ""
		Screens.fill(Screens.frame(powerBar, "Fill"), 1)
		Screens.fill(Screens.frame(yenBar, "Fill"), 1)
		Screens.setButtonState(confirm, "off")
		return
	end
	Screens.label(gui, "NextTier").Text = `REBIRTH {tier.Tier}`
	Screens.label(gui, "PowerReqText").Text =
		`{Format.short(state.power)} / {Format.short(tier.PowerReq)}`
	Screens.label(gui, "YenReqText").Text =
		`{Format.short(state.yen)} / {Format.short(tier.YenCost)}`
	Screens.fill(Screens.frame(powerBar, "Fill"), state.power / tier.PowerReq)
	Screens.fill(Screens.frame(yenBar, "Fill"), state.yen / tier.YenCost)
	Screens.label(gui, "RewardIncome").Text = `+{percent(tier.IncomeBonus)}% INCOME`
	Screens.label(gui, "RewardLuck").Text = `+{percent(tier.LuckBonus)}% LUCK`
	Screens.setButtonState(
		confirm,
		if Progress.canRebirth(Config, state.rebirth, state.power, state.yen)
			then "gold"
			else "cannot"
	)
end

-- Yen and power move every second: keep the bars honest while the page is up
Rebirth.tick = Rebirth.render

function Rebirth.init(context: Types.Ctx)
	ctx = context
	gui = Screens.get("Rebirth")
	Screens.button(gui, "ConfirmButton").Activated:Connect(function()
		ctx.fire("ProgressAction", "rebirth")
	end)
end

return Rebirth
