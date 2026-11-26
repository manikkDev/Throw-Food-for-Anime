--!strict
-- Rebirth - the next tier: what it needs, what it gives, what is kept and
-- lost. The server decides.
--
-- Economy v2 (plan 12): a rebirth resets Power and Yen ONLY and opens the next
-- zones. The need is a THROW that reaches the sealed gate (Power x the food).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Progress = require(ReplicatedStorage.Shared.Core.Progress)
local Screens = require(script.Parent.Parent.Screens)
local Types = require(script.Parent.Types)

local Rebirth = { name = "Rebirth" } :: Types.Page

-- the two lists, written over the tree's (which still names the old wipe)
local KEEPS = { "Your heroes", "Gear and foods", "Plot slots", "Hero Index" }
local LOSES = { "Yen", "Power" }

local ctx: Types.Ctx
local gui: ScreenGui

local function writeList(panel: string, lines: { string })
	local list = Screens.frame(Screens.frame(gui, panel), "List")
	for i = 1, 4 do
		local item = list:FindFirstChild("Item" .. i)
		if item and item:IsA("GuiObject") then
			item.Visible = lines[i] ~= nil
			if lines[i] then
				Screens.label(item, "Text").Text = lines[i]
			end
		end
	end
end

local function percent(fraction: number): number
	return math.floor(fraction * 100 + 0.5)
end

function Rebirth.render(state: any)
	local tier = Progress.nextRebirth(Config, state.rebirth)
	local powerBar = Screens.frame(gui, "PowerBar")
	local yenBar = Screens.frame(gui, "YenBar")
	local confirm = Screens.button(gui, "ConfirmButton")
	local current = Screens.label(gui, "CurrentRebirth")
	current.Text = `You are at Rebirth {state.rebirth}`
	if not tier then
		Screens.label(gui, "NextTier").Text = "MAX REBIRTH"
		Screens.label(gui, "PowerReqText").Text = "MAX"
		Screens.label(gui, "YenReqText").Text = "MAX"
		Screens.label(gui, "RewardIncome").Text = "MAX REBIRTH"
		Screens.label(gui, "RewardLuck").Text = ""
		Screens.image(gui, "PowerDone").Visible = true
		Screens.image(gui, "YenDone").Visible = true
		Screens.fill(Screens.frame(powerBar, "Fill"), 1)
		Screens.fill(Screens.frame(yenBar, "Fill"), 1)
		Screens.setButtonState(confirm, "off")
		return
	end
	-- the throw that must reach the sealed gate: Power alone (food gives luck only)
	local reach = state.power
	Screens.label(gui, "NextTier").Text = `REBIRTH {tier.Tier}`
	-- what this rebirth opens, on the chip under the lists
	if #tier.Unseals > 0 then
		current.Text = `Opens {Config.Zones[tier.Unseals[1]].Name}`
	end
	Screens.label(gui, "PowerReqText").Text =
		`{Format.short(reach)} / {Format.short(tier.PowerReq)}`
	Screens.label(gui, "YenReqText").Text =
		`{Format.short(state.yen)} / {Format.short(tier.YenCost)}`
	Screens.fill(Screens.frame(powerBar, "Fill"), reach / tier.PowerReq)
	Screens.fill(Screens.frame(yenBar, "Fill"), state.yen / tier.YenCost)
	-- a tick by each requirement that is met
	Screens.image(gui, "PowerDone").Visible = reach >= tier.PowerReq
	Screens.image(gui, "YenDone").Visible = state.yen >= tier.YenCost
	Screens.label(gui, "RewardIncome").Text =
		`+{percent(tier.IncomeBonus)}% YEN  +{percent(tier.TrainBonus)}% TRAIN`
	Screens.label(gui, "RewardLuck").Text =
		`+{percent(tier.LuckBonus)}% LUCK  +{tier.LuckyThrows} THROWS`
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
	writeList("Keeps", KEEPS)
	writeList("Resets", LOSES)
	Screens.button(gui, "ConfirmButton").Activated:Connect(function()
		ctx.fire("ProgressAction", "rebirth")
	end)
end

return Rebirth
