--!strict
-- Throw Food for Anime - client entry point.
-- Boots Knit (Controllers). Keep this file to the boot only; logic lives in Controllers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

-- Roblox's player list is off: the game has its own boards, no leaderstats to list, and the
-- top-right corner belongs to the HUD (settings, boosts tray, the right column).
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)

-- Phones turn the screen, landscape only: every screen is a 16:9 canvas, and held upright the HUD
-- shrank to a strip of 15-pixel buttons (phase F playtest on an iPhone 17 Pro in portrait). The
-- place's StarterGui.ScreenOrientation says the same; this keeps it true whatever the place says.
pcall(function()
	local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
end)

local Knit = require(ReplicatedStorage.Packages.Knit)

Knit.AddControllers(script.Controllers)

Knit.Start()
	:andThen(function()
		-- BUILD STAMP - see the note in the server boot.
		print("[Throw Food for Anime] Client started - BUILD s6-04")
	end)
	:catch(warn)
