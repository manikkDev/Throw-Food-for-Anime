--!strict
-- Codes - type a code, redeem it. The server answers a redeem with a Toast;
-- the answer to the code just sent is also written under the box, so the
-- player reads it where they are looking. Nothing here is rebuilt by a
-- snapshot, so a half-typed code is never lost.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Screens = require(script.Parent.Parent.Screens)
local Theme = require(script.Parent.Parent.Theme)
local Types = require(script.Parent.Types)

local ANSWER_WINDOW = 4 -- seconds a Toast counts as the answer to a redeem

local Codes = { name = "Codes" } :: Types.Page

local ctx: Types.Ctx
local box: TextBox
local result: TextLabel
local sentAt = -math.huge

local function redeem()
	local text = box.Text
	if text:gsub("%s", "") == "" then
		return
	end
	sentAt = os.clock()
	result.Text = ""
	ctx.fire("RewardClaim", "code", text)
	box.Text = ""
end

function Codes.render(_state: any) end

function Codes.opened()
	result.Text = ""
end

function Codes.init(context: Types.Ctx)
	ctx = context
	local gui = Screens.get("Codes")
	box = Screens.box(gui, "CodeBox")
	result = Screens.label(gui, "ResultLabel")
	result.Text = ""
	box.ClearTextOnFocus = false
	box.FocusLost:Connect(function(enter: boolean)
		if enter then
			redeem()
		end
	end)
	Screens.button(gui, "RedeemButton").Activated:Connect(redeem)

	task.spawn(function()
		local toast = Net.client("Toast")
		if not toast then
			return
		end
		toast.OnClientEvent:Connect(function(text: string, kind: string)
			if os.clock() - sentAt > ANSWER_WINDOW then
				return
			end
			sentAt = -math.huge
			result.Text = tostring(text)
			result.TextColor3 = if kind == "good"
				then Theme.CONFIRM
				elseif kind == "bad" then Theme.DANGER
				else Theme.WHITE
		end)
	end)
end

return Codes
