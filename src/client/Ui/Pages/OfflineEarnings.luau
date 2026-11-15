--!strict
-- OfflineEarnings - "welcome back": how long the player was away, what the
-- heroes earned, Claim or 2x. Opened once per session by MenuController when
-- state.offline exists; the Gifts button reaches it again until it is claimed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Format = require(ReplicatedStorage.Shared.Core.Format)
local Lookup = require(ReplicatedStorage.Shared.Core.Lookup)
local Screens = require(script.Parent.Parent.Screens)
local Types = require(script.Parent.Types)

local MAPS = Lookup.of(Config)

local OfflineEarnings = { name = "OfflineEarnings" } :: Types.Page

local ctx: Types.Ctx
local gui: ScreenGui

function OfflineEarnings.render(state: any)
	local offline = state.offline
	if not offline then
		-- claimed (or doubled and paid out): nothing left to show
		Screens.label(gui, "AwayTime").Text = ""
		Screens.label(gui, "EarnedAmount").Text = ""
		if Screens.isOpen("OfflineEarnings") then
			Screens.close()
		end
		return
	end
	Screens.label(gui, "AwayTime").Text = `You were away {Format.duration(offline.seconds)}`
	Screens.label(gui, "EarnedAmount").Text = `+{Format.short(offline.amount)}`
end

function OfflineEarnings.init(context: Types.Ctx)
	ctx = context
	gui = Screens.get("OfflineEarnings")
	local double = MAPS.product.OfflineDouble
	Screens.label(gui, "AwayTime").Text = ""
	Screens.label(gui, "EarnedAmount").Text = ""
	-- "2X" and the price. The tree gives this button one label for both (its
	-- samples read "2X  39"); if a separate label already says 2X, the price
	-- label carries the price alone.
	local doubleButton = Screens.button(gui, "DoubleButton")
	local price = Screens.label(doubleButton, "DoublePrice")
	local saysDouble = false
	for _, piece in doubleButton:GetDescendants() do
		if piece:IsA("TextLabel") and piece ~= price and piece.Text:upper():find("2X") then
			saysDouble = true
		end
	end
	price.Text = if not double
		then ""
		elseif saysDouble then tostring(double.Robux)
		else `2X  {double.Robux}`
	Screens.button(gui, "ClaimButton").Activated:Connect(function()
		ctx.fire("RewardClaim", "offline")
	end)
	Screens.button(gui, "DoubleButton").Activated:Connect(function()
		if double then
			ctx.prompt(double, false)
		end
	end)
end

return OfflineEarnings
