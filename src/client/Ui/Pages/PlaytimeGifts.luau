--!strict
-- PlaytimeGifts - six gifts that unlock as the session runs. Each button is
-- CLAIM!, a countdown, or CLAIMED.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Collection = require(ReplicatedStorage.Shared.Core.Collection)
local Screens = require(script.Parent.Parent.Screens)
local Types = require(script.Parent.Types)

local GIFTS = 6 -- GiftCell1..6 ship in the tree

local PlaytimeGifts = { name = "PlaytimeGifts" } :: Types.Page

local ctx: Types.Ctx
local gui: ScreenGui
local cells: { GuiObject } = {}

function PlaytimeGifts.render(state: any)
	local today = Collection.dayOf(ctx.now())
	local session = ctx.session()
	Screens.label(gui, "Timer").Text = `Played today: {Screens.clock(session)}`
	for index = 1, GIFTS do
		local minutes = Config.Rewards.PlaytimeMinutes[index]
		local cell = cells[index]
		cell.Visible = minutes ~= nil
		if minutes then
			local button = Screens.button(cell, "GiftButton")
			local label = Screens.label(button, "GiftState")
			local claimed = state.gifts.day == today
				and state.gifts.claimed[tostring(index)] == true
			if claimed then
				label.Text = "CLAIMED"
				Screens.setButtonState(button, "state")
			elseif Collection.giftClaimable(Config, state.gifts, today, session, index) then
				label.Text = "CLAIM!"
				Screens.setButtonState(button, "afford", nil, "IconGift")
			else
				label.Text = Screens.clock(minutes * 60 - session)
				Screens.setButtonState(button, "off", nil, "IconTimer")
			end
		end
	end
end

PlaytimeGifts.tick = PlaytimeGifts.render

function PlaytimeGifts.init(context: Types.Ctx)
	ctx = context
	gui = Screens.get("PlaytimeGifts")
	for index = 1, GIFTS do
		local cell = Screens.frame(gui, "GiftCell" .. index)
		-- The tree ships some cells with a flat CLAIMED pill where the button
		-- goes (they are the mockup's claimed gifts). Any gift can be in any
		-- state here, so such a cell is replaced by the template, which
		-- carries the real button.
		local shipped = cell:FindFirstChild("GiftButton", true)
		if not shipped or not shipped:IsA("GuiButton") then
			local fresh = Screens.template("GiftCellTemplate")
			fresh.Name = cell.Name
			fresh.LayoutOrder = cell.LayoutOrder
			fresh.Position = cell.Position
			fresh.Parent = cell.Parent
			cell:Destroy()
			cell = fresh
		end
		cells[index] = cell
		local minutes = Config.Rewards.PlaytimeMinutes[index]
		if minutes then
			Screens.label(cell, "GiftTitle").Text = `GIFT {index}`
			Screens.label(cell, "GiftWhen").Text = `after {minutes} min`
		end
		Screens.button(cell, "GiftButton").Activated:Connect(function()
			ctx.fire("RewardClaim", "gift", index)
		end)
	end
end

return PlaytimeGifts
