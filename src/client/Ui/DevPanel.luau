--!strict
-- DevPanel - the TEST commands: owner event controls, and in Studio the test
-- grants. It is not a player screen, so it is not in design/ui: a small
-- code-built panel, shown only when the server says this player is the owner
-- (state.admin) or the session is Studio (state.studio). The server refuses
-- every one of these commands for anyone else, whatever the client shows.
--
-- Opened with F2, or the small TEST button in the bottom-right corner.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Make = require(script.Parent.Make)

type Command = { text: string, command: string, arg: any }

local OWNER: { Command } = {
	{ text = "OWNER: start a 5 minute Festival Hour", command = "festival", arg = 5 },
	{ text = "OWNER: raise server luck one step", command = "luck", arg = nil },
	{ text = "OWNER: give everyone 3 Lucky Throws", command = "throws", arg = 3 },
}
local STUDIO: { Command } = {
	{ text = "DEV: +10K yen", command = "yen", arg = 1e4 },
	{ text = "DEV: +10M yen", command = "yen", arg = 1e7 },
	{ text = "DEV: +1T yen", command = "yen", arg = 1e12 },
	{ text = "DEV: +500 power", command = "power", arg = 500 },
	{ text = "DEV: +100K power", command = "power", arg = 1e5 },
	{ text = "DEV: +200M power", command = "power", arg = 2e8 },
	{
		text = "DEV: grant a Titan Galaxy Mythic",
		command = "hero",
		arg = { id = "sun_god_captain", mut = "Galaxy", size = "Titan" },
	},
	{ text = "DEV: pretend 3 hours away (rejoin to see it)", command = "away", arg = 10800 },
	{ text = "DEV: wipe my profile", command = "wipe", arg = nil },
}

local DevPanel = {}

local gui: ScreenGui? = nil
local panel: Frame? = nil

local function build(state: any, run: (command: string, arg: any) -> ())
	local screen = Make.screen("TestPanel", 40)
	screen.Enabled = true

	local opener = Make.button(screen, "TEST", Make.BAD, {
		Name = "TestButton",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -6, 1, -6),
		Size = UDim2.fromOffset(64, 26),
		BackgroundTransparency = 0.3,
	})
	local frame = Make.frame(screen, {
		Name = "Panel",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -6, 1, -40),
		Size = UDim2.fromOffset(430, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.05,
		Visible = false,
	})
	Make.corner(frame, 12)
	Make.stroke(frame, 3, Color3.new(1, 1, 1))
	Make.list(frame, Enum.FillDirection.Vertical, 4)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = frame
	Make.label(frame, if state.mock then "TEST  (saving is OFF)" else "TEST", {
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 26),
		TextColor3 = Make.BUY,
		LayoutOrder = 0,
	})

	local commands: { Command } = {}
	if state.admin then
		table.move(OWNER, 1, #OWNER, #commands + 1, commands)
	end
	if state.studio then
		table.move(STUDIO, 1, #STUDIO, #commands + 1, commands)
	end
	for index, command in commands do
		local button = Make.button(frame, command.text, Make.PANEL, {
			Name = "Command" .. index,
			Size = UDim2.new(1, 0, 0, 30),
			LayoutOrder = index,
		})
		button.Activated:Connect(function()
			run(command.command, command.arg)
		end)
	end

	opener.Activated:Connect(function()
		frame.Visible = not frame.Visible
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and input.KeyCode == Enum.KeyCode.F2 then
			frame.Visible = not frame.Visible
		end
	end)

	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = screen
	panel = frame
end

--- Build the panel the first time a snapshot says this player may use it.
--- `run(command, arg)` fires AdminCommand.
function DevPanel.update(state: any, run: (command: string, arg: any) -> ())
	local allowed = state.studio == true or state.admin == true
	if allowed and not gui then
		build(state, run)
	end
	if gui then
		gui.Enabled = allowed
	end
	if panel and not allowed then
		panel.Visible = false
	end
end

return DevPanel
