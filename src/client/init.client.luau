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

local Knit = require(ReplicatedStorage.Packages.Knit)

Knit.AddControllers(script.Controllers)

Knit.Start()
	:andThen(function()
		-- BUILD STAMP - see the note in the server boot.
		print("[Throw Food for Anime] Client started - BUILD s5-04")
	end)
	:catch(warn)
