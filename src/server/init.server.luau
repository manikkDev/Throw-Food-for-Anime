--!strict
-- Throw Food for Anime - server entry point.
-- Boots Knit (Services). Keep this file to the boot only; logic lives in Services.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

-- Studio-only content never reaches a player: the aura showcase (tools/studio/aura_showcase.py)
-- floats outside the map for the owner to look at in edit mode
local showcase = workspace:FindFirstChild("AuraShowcase")
if showcase then
	showcase:Destroy()
end
for _, name in { "AuraPackBrowser", "ZoneLab" } do
	local dev = workspace:FindFirstChild(name)
	if dev then
		dev:Destroy()
	end
end

Knit.AddServices(script.Services)

Knit.Start()
	:andThen(function()
		-- BUILD STAMP. If this exact line is not in Output on Play, Studio is NOT
		-- running the code on disk. Check the Rojo plugin is actually CONNECTED
		-- and syncing before debugging anything else - an established connection
		-- is not the same as an accepted one.
		print("[Throw Food for Anime] Server started - BUILD s6-04")
	end)
	:catch(warn)
